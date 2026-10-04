// Steam client integration over the Steamworks flat API (SDK 1.65).
//
// The steam_api library is loaded at run time: a build with this unit runs without it,
// Steam is just not available then. Ship the library from the SDK's redistributable_bin
// next to the executable (steam_api64.dll / steam_api.dll / libsteam_api.so /
// libsteam_api.dylib); outside Steam put steam_appid.txt with the AppID there too.
//
// Callbacks are dispatched manually once per frame (on 'Engine\Frame\Begin') and turned
// into signals:
//   Steam\DlcInstalled                     tag = AppID of the DLC (the user gained it and it is installed)
//   Steam\MicroTxnAuthorization\<OrderID>  tag = 1 if the user authorized the transaction, 0 otherwise
//
// Copyright (C) 2011 Apus Software. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.Engine.SteamAPI;
interface
 uses Apus.Core;

 type
  TSteamAppID=cardinal;

  {$SCOPEDENUMS ON}
  // Outcome of Steam.Init
  TSteamInitResult=(NotInitialized, // Init was not called (or Shutdown was)
                    OK,
                    NoLibrary,      // steam_api library is absent or of another SDK version
                    NoClient,       // the Steam client is not running
                    ClientOutdated, // the Steam client is older than the SDK: the user should update Steam
                    Failed);        // any other failure, see initError
  {$SCOPEDENUMS OFF}

  // Steam client access. While Steam is not available every query returns false/empty.
  Steam=record
   class var available:boolean; // the library is loaded and connected to the running client
   class var userID:uint64;     // SteamID of the current user
   class var userName:String8;  // persona name of the current user
   class var gameLanguage:String8; // language the user chose for this game in Steam, like 'english', 'russian'
   class var initResult:TSteamInitResult; // why Steam is (not) available, e.g. to ask the user to update Steam
   class var initError:String8; // non-localized details of a failed Init, for the log or a support report
   // Load the library and connect to the running Steam client. Returns false when the
   // library is absent or the client is not available; initResult/initError tell why.
   class function Init:boolean; static;
   class procedure Shutdown; static;
   // Restart the game through Steam if it was not launched by it: call before Init, quit when true.
   // Returns false when the library is absent.
   class function RestartAppIfNecessary(appID:TSteamAppID):boolean; static;
   class function IsDlcInstalled(appID:TSteamAppID):boolean; static; // the user owns the DLC and it is installed
   class function IsSubscribedApp(appID:TSteamAppID):boolean; static; // the user owns the app
   // Achievement state of the user's account, e.g. to restore unlocked badges. Call it any
   // time after Init: since SDK 1.61 the Steam client synchronizes stats and achievements
   // before the game process starts, so there is no RequestCurrentStats and no callback to
   // wait for. Returns false (achieved=false) for a name unknown to the app or when Steam
   // is not available - then the local state should be kept as is.
   class function GetAchievement(const name:String8;out achieved:boolean):boolean; static;
   // Achievements change locally; StoreStats sends them to the server
   class function SetAchievement(const name:String8):boolean; static;
   class function ClearAchievement(const name:String8):boolean; static;
   class function StoreStats:boolean; static;
  end;

implementation
 uses
  {$IFDEF FPC}dynlibs,{$ELSE}{$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}{$ENDIF}
  SysUtils, Apus.Conv, Apus.Log, Apus.EventMan;

 const
  {$IFDEF MSWINDOWS}
   {$IFDEF CPU64}
   STEAM_LIB='steam_api64.dll';
   {$ELSE}
   STEAM_LIB='steam_api.dll';
   {$ENDIF}
  {$ELSE}
   {$IFDEF DARWIN}
   STEAM_LIB='libsteam_api.dylib';
   {$ELSE}
   STEAM_LIB='libsteam_api.so';
   {$ENDIF}
  {$ENDIF}

  STEAM_INIT_OK=0; // k_ESteamAPIInitResult_OK
  CB_MICROTXN_AUTHORIZATION=152; // k_iSteamUserCallbacks+52: MicroTxnAuthorizationResponse_t
  CB_DLC_INSTALLED=1005;         // k_iSteamAppsCallbacks+5: DlcInstalled_t

 type
  HSteamPipe=integer;
  HSteamUser=integer;
  TSteamErrMsg=array[0..1023] of AnsiChar;

 // Callback structures: Valve packs them by 8 on Windows and by 4 elsewhere
 {$IFDEF MSWINDOWS}{$A8}{$ELSE}{$A4}{$ENDIF}
 type
  TCallbackMsg=record // CallbackMsg_t
   hSteamUser:HSteamUser;
   callback:integer;
   param:pointer;
   paramSize:integer;
  end;
  TMicroTxnAuthorizationResponse=record // MicroTxnAuthorizationResponse_t
   appID:cardinal;
   orderID:uint64;
   authorized:byte;
  end;
  TDlcInstalled=record // DlcInstalled_t
   appID:TSteamAppID;
  end;
 {$A+}

 var
  lib:{$IFDEF FPC}TLibHandle{$ELSE}HMODULE{$ENDIF}=0;
  pipe:HSteamPipe;
  steamUser,steamFriends,steamApps,steamUserStats:pointer;

  // steam_api exports (all cdecl)
  SteamAPI_InitFlat:function(errMsg:pointer):integer; cdecl;
  SteamAPI_Shutdown:procedure; cdecl;
  SteamAPI_RestartAppIfNecessary:function(appID:cardinal):boolean; cdecl;
  SteamAPI_GetHSteamPipe:function:HSteamPipe; cdecl;
  SteamAPI_ManualDispatch_Init:procedure; cdecl;
  SteamAPI_ManualDispatch_RunFrame:procedure(pipe:HSteamPipe); cdecl;
  SteamAPI_ManualDispatch_GetNextCallback:function(pipe:HSteamPipe;var msg:TCallbackMsg):boolean; cdecl;
  SteamAPI_ManualDispatch_FreeLastCallback:procedure(pipe:HSteamPipe); cdecl;
  SteamAPI_SteamUser_v023:function:pointer; cdecl;
  SteamAPI_SteamFriends_v018:function:pointer; cdecl;
  SteamAPI_SteamApps_v009:function:pointer; cdecl;
  SteamAPI_SteamUserStats_v013:function:pointer; cdecl;
  SteamAPI_ISteamUser_GetSteamID:function(self:pointer):uint64; cdecl;
  SteamAPI_ISteamFriends_GetPersonaName:function(self:pointer):PAnsiChar; cdecl;
  SteamAPI_ISteamApps_GetCurrentGameLanguage:function(self:pointer):PAnsiChar; cdecl;
  SteamAPI_ISteamApps_BIsDlcInstalled:function(self:pointer;appID:TSteamAppID):boolean; cdecl;
  SteamAPI_ISteamApps_BIsSubscribedApp:function(self:pointer;appID:TSteamAppID):boolean; cdecl;
  SteamAPI_ISteamUserStats_GetAchievement:function(self:pointer;name:PAnsiChar;var achieved:boolean):boolean; cdecl;
  SteamAPI_ISteamUserStats_SetAchievement:function(self:pointer;name:PAnsiChar):boolean; cdecl;
  SteamAPI_ISteamUserStats_ClearAchievement:function(self:pointer;name:PAnsiChar):boolean; cdecl;
  SteamAPI_ISteamUserStats_StoreStats:function(self:pointer):boolean; cdecl;

 procedure UnloadLib;
  begin
   if lib=0 then exit;
   {$IFDEF FPC}UnloadLibrary(lib);{$ELSE}FreeLibrary(lib);{$ENDIF}
   lib:=0;
  end;

 function LoadLib:boolean;
  var
   missing:String8;
  procedure Bind(var proc;const name:String8);
   begin
    {$IFDEF FPC}
    pointer(proc):=GetProcedureAddress(lib,name);
    {$ELSE}
    pointer(proc):=GetProcAddress(lib,PAnsiChar(name));
    {$ENDIF}
    if pointer(proc)=nil then missing:=missing+' '+name;
   end;
  begin
   result:=lib<>0;
   if result then exit;
   {$IFNDEF MSWINDOWS}
   // dlopen does not look next to the executable by itself
   lib:=LoadLibrary(ExtractFilePath(ParamStr(0))+STEAM_LIB);
   if lib=0 then
   {$ENDIF}
   lib:=LoadLibrary(STEAM_LIB);
   if lib=0 then begin
    Steam.initResult:=TSteamInitResult.NoLibrary;
    Steam.initError:=STEAM_LIB+' not found';
    Log.Msg('Steam: '+Steam.initError);
    exit;
   end;
   missing:='';
   Bind(SteamAPI_InitFlat,'SteamAPI_InitFlat');
   Bind(SteamAPI_Shutdown,'SteamAPI_Shutdown');
   Bind(SteamAPI_RestartAppIfNecessary,'SteamAPI_RestartAppIfNecessary');
   Bind(SteamAPI_GetHSteamPipe,'SteamAPI_GetHSteamPipe');
   Bind(SteamAPI_ManualDispatch_Init,'SteamAPI_ManualDispatch_Init');
   Bind(SteamAPI_ManualDispatch_RunFrame,'SteamAPI_ManualDispatch_RunFrame');
   Bind(SteamAPI_ManualDispatch_GetNextCallback,'SteamAPI_ManualDispatch_GetNextCallback');
   Bind(SteamAPI_ManualDispatch_FreeLastCallback,'SteamAPI_ManualDispatch_FreeLastCallback');
   Bind(SteamAPI_SteamUser_v023,'SteamAPI_SteamUser_v023');
   Bind(SteamAPI_SteamFriends_v018,'SteamAPI_SteamFriends_v018');
   Bind(SteamAPI_SteamApps_v009,'SteamAPI_SteamApps_v009');
   Bind(SteamAPI_SteamUserStats_v013,'SteamAPI_SteamUserStats_v013');
   Bind(SteamAPI_ISteamUser_GetSteamID,'SteamAPI_ISteamUser_GetSteamID');
   Bind(SteamAPI_ISteamFriends_GetPersonaName,'SteamAPI_ISteamFriends_GetPersonaName');
   Bind(SteamAPI_ISteamApps_GetCurrentGameLanguage,'SteamAPI_ISteamApps_GetCurrentGameLanguage');
   Bind(SteamAPI_ISteamApps_BIsDlcInstalled,'SteamAPI_ISteamApps_BIsDlcInstalled');
   Bind(SteamAPI_ISteamApps_BIsSubscribedApp,'SteamAPI_ISteamApps_BIsSubscribedApp');
   Bind(SteamAPI_ISteamUserStats_GetAchievement,'SteamAPI_ISteamUserStats_GetAchievement');
   Bind(SteamAPI_ISteamUserStats_SetAchievement,'SteamAPI_ISteamUserStats_SetAchievement');
   Bind(SteamAPI_ISteamUserStats_ClearAchievement,'SteamAPI_ISteamUserStats_ClearAchievement');
   Bind(SteamAPI_ISteamUserStats_StoreStats,'SteamAPI_ISteamUserStats_StoreStats');
   if missing<>'' then begin
    // another SDK version: the versioned accessors differ
    Steam.initResult:=TSteamInitResult.NoLibrary;
    Steam.initError:=STEAM_LIB+' lacks'+missing;
    Log.Error('Steam: '+Steam.initError);
    UnloadLib;
    exit;
   end;
   result:=true;
  end;

 // Dispatch pending callbacks into signals
 procedure FrameEvent(event:TEventStr;tag:TTag);
  var
   msg:TCallbackMsg;
  begin
   if not Steam.available then exit;
   SteamAPI_ManualDispatch_RunFrame(pipe);
   while SteamAPI_ManualDispatch_GetNextCallback(pipe,msg) do
    try
     case msg.callback of
      CB_DLC_INSTALLED:
        with TDlcInstalled(msg.param^) do begin
         Log.Msg('Steam: DLC %d installed',[appID]);
         Signal('Steam\DlcInstalled',appID);
        end;
      CB_MICROTXN_AUTHORIZATION:
        with TMicroTxnAuthorizationResponse(msg.param^) do begin
         Log.Msg('Steam: transaction %s authorized=%d',[Conv.ToStr(orderID),authorized]);
         Signal('Steam\MicroTxnAuthorization\'+Conv.ToStr(orderID),authorized);
        end;
     end;
    finally
     SteamAPI_ManualDispatch_FreeLastCallback(pipe);
    end;
  end;

{ Steam }

class function Steam.Init:boolean;
 var
  errMsg:TSteamErrMsg;
  res:integer;
 begin
  result:=available;
  if result then exit;
  if not LoadLib then exit;
  fillchar(errMsg,sizeof(errMsg),0);
  res:=SteamAPI_InitFlat(@errMsg);
  if res<>STEAM_INIT_OK then begin
   case res of // ESteamAPIInitResult
    2:initResult:=TSteamInitResult.NoClient;
    3:initResult:=TSteamInitResult.ClientOutdated;
    else initResult:=TSteamInitResult.Failed;
   end;
   initError:=String8(PAnsiChar(@errMsg));
   Log.Msg('Steam: not available, code %d: %s',[res,initError]);
   UnloadLib;
   exit;
  end;
  initResult:=TSteamInitResult.OK;
  initError:='';
  SteamAPI_ManualDispatch_Init;
  pipe:=SteamAPI_GetHSteamPipe;
  steamUser:=SteamAPI_SteamUser_v023;
  steamFriends:=SteamAPI_SteamFriends_v018;
  steamApps:=SteamAPI_SteamApps_v009;
  steamUserStats:=SteamAPI_SteamUserStats_v013;
  userID:=SteamAPI_ISteamUser_GetSteamID(steamUser);
  userName:=String8(SteamAPI_ISteamFriends_GetPersonaName(steamFriends));
  gameLanguage:=String8(SteamAPI_ISteamApps_GetCurrentGameLanguage(steamApps));
  available:=true;
  SetEventHandler('Engine\Frame\Begin',FrameEvent,emInstant);
  Log.Msg('Steam: available, SteamID=%s, name="%s", language="%s"',[Conv.ToStr(userID),userName,gameLanguage]);
  result:=true;
 end;

class procedure Steam.Shutdown;
 begin
  if available then begin
   RemoveEventHandler(FrameEvent);
   available:=false;
   SteamAPI_Shutdown;
  end;
  UnloadLib;
  initResult:=TSteamInitResult.NotInitialized;
  initError:='';
 end;

class function Steam.RestartAppIfNecessary(appID:TSteamAppID):boolean;
 begin
  result:=LoadLib and SteamAPI_RestartAppIfNecessary(appID);
 end;

class function Steam.IsDlcInstalled(appID:TSteamAppID):boolean;
 begin
  result:=available and SteamAPI_ISteamApps_BIsDlcInstalled(steamApps,appID);
 end;

class function Steam.IsSubscribedApp(appID:TSteamAppID):boolean;
 begin
  result:=available and SteamAPI_ISteamApps_BIsSubscribedApp(steamApps,appID);
 end;

class function Steam.GetAchievement(const name:String8;out achieved:boolean):boolean;
 begin
  achieved:=false;
  result:=available and SteamAPI_ISteamUserStats_GetAchievement(steamUserStats,PAnsiChar(name),achieved);
 end;

class function Steam.SetAchievement(const name:String8):boolean;
 begin
  result:=available and SteamAPI_ISteamUserStats_SetAchievement(steamUserStats,PAnsiChar(name));
 end;

class function Steam.ClearAchievement(const name:String8):boolean;
 begin
  result:=available and SteamAPI_ISteamUserStats_ClearAchievement(steamUserStats,PAnsiChar(name));
 end;

class function Steam.StoreStats:boolean;
 begin
  result:=available and SteamAPI_ISteamUserStats_StoreStats(steamUserStats);
 end;

end.
