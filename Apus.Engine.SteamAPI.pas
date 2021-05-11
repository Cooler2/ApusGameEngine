// Translated from STEAM SDK headers

// Copyright (C) 2011 Apus Software. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$IFDEF CPUX64} {$DEFINE CPU64} {$ENDIF}
unit Apus.Engine.SteamAPI;
interface
 const
  {$IFDEF MSWINDOWS}
   {$IFDEF CPU64}
   steamLibName = 'steam_api64.dll';
   {$ELSE}
   steamLibName = 'steam_api.dll';
   {$ENDIF}
  {$ENDIF}
  {$IFDEF LINUX}
   //{$LINKLIB steam_api}
   steamLibName = 'libsteam_api.so';
  {$ENDIF}
 var
  steamAvailable:boolean=false;   // Is API available?
  steamID:int64;
  steamUserName:PAnsiChar;
  steamGameLang:PAnsiChar;

 type
  int32=integer;
  Pint32=^int32;
  uint32=cardinal;
  float=single;
  SteamAPICall_t=int64;
  SteamLeaderboard_t=int64;
  SteamLeaderboardEntries_t=int64;
  UGCHandle_t=int64;
  HAuthTicket=uint32;
  HSteamuser=integer;
  HSteamPipe=integer;

  // Own functions
  procedure InitSteamAPI;
  procedure DoneSteamAPI;
  //function VerifyOwnership:boolean;

  // �������� ����� ��� �������� ��� ������� (HEX-������)
  function GetSteamAuthTicket:string;

  // Imported SteamAPI functions

  function SteamAPI_Init():boolean; cdecl; external steamLibName;
  procedure SteamAPI_Shutdown(); cdecl; external steamLibName;
  procedure SetSteamAchievement(name:string;enable:boolean=true);

  function SteamInternal_CreateInterface(ver:PAnsiChar):pointer; cdecl; external steamLibName;
  function SteamAPI_GetHSteamUser:HSteamUser;  cdecl; external steamLibName;
  function SteamAPI_GetHSteamPipe:HSteamPipe;  cdecl; external steamLibName;
  function SteamAPI_ISteamClient_GetISteamUser(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PAnsiChar):pointer;  cdecl; external steamLibName;
  function SteamAPI_ISteamClient_GetISteamApps(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PAnsiChar):pointer; cdecl; external steamLibName;
  function SteamAPI_ISteamClient_GetISteamUserStats(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PAnsiChar):pointer; cdecl; external steamLibName;
  function SteamAPI_ISteamClient_GetISteamFriends(steamClient:pointer;hSteamUser:HSteamUser;
    hSteamPipe:HSteamPipe;const pchVersion:PAnsiChar):pointer; cdecl; external steamLibName;

  function SteamAPI_ISteamUser_GetAuthSessionTicket(steamUser:pointer;pTicket:pointer;cbMaxTicket:integer;
    out pcbTicket:Cardinal):HAuthTicket; cdecl; external steamLibName;

  function SteamAPI_ISteamUser_GetSteamID(steamUser:pointer):int64; cdecl; external steamLibName;
  function SteamAPI_ISteamApps_GetCurrentGameLanguage(steamApps:pointer):PAnsiChar; cdecl; external steamLibName;

  procedure SteamAPI_RunCallbacks; cdecl; external steamLibName;
  procedure SteamAPI_RegisterCallback(callbackbase:pointer;iCallback:integer); cdecl; external steamLibName;

  function SteamAPI_ISteamUserStats_SetAchievement(steamUserStats:pointer;const pchName:PAnsiChar):boolean; cdecl; external steamLibName;
  function SteamAPI_ISteamUserStats_ClearAchievement(steamUserStats:pointer;const pchName:PAnsiChar):boolean; cdecl; external steamLibName;
  function SteamAPI_ISteamUserStats_IndicateAchievementProgress(steamUserStats:pointer;const pchName:PAnsiChar;
    nCurProgress,nMaxProgress:cardinal):boolean; cdecl; external steamLibName;

  function SteamAPI_ISteamFriends_GetPersonaName(self:pointer):PAnsiChar; cdecl external steamLibName;

implementation
 uses SysUtils, Apus.MyServis, Apus.EventMan;
 type
  PMicroTxnAuthorizationResponse_t=^MicroTxnAuthorizationResponse_t;
  MicroTxnAuthorizationResponse_t=record
    m_unAppID:integer;        // AppID for this microtransaction
    m_ulOrderID:int64;        // OrderID provided for the microtransaction
    m_bAuthorized:byte;    // if user authorized transaction
  end;

 const
  STEAMCLIENT_VERSION='SteamClient017';
  STEAMUSER_VERSION='SteamUser019';
  STEAMAPPS_VERSION='STEAMAPPS_INTERFACE_VERSION008';
  STEAMUSERSTAT_VERSION='STEAMUSERSTATS_INTERFACE_VERSION011';
  STEAMFRIENDS_VERSION='SteamFriends017';

  k_iSteamUserCallbacks = 100;

 var
  steamClient,steamUser,steamApps,steamUserStats,steamFriends:pointer;
  callbackVMT:array[0..5] of pointer;
  callbackObj:array[0..5] of pointer;

 // Callback function
 {$W+}
 procedure OnMicroTxnAuthorization(param:PMicroTxnAuthorizationResponse_t); stdcall;
  begin
   LogMessage('Transaction: '+IntToStr(param.m_ulOrderID)+' code:'+IntToStr(param.m_bAuthorized));
   Signal('STEAM\MicroTxnAuthorization\'+IntToStr(param.m_ulOrderID),param.m_bAuthorized);
  end;

 procedure SetSteamAchievement(name:string;enable:boolean=true);
  var
   aName:PAnsiChar;
   res:boolean;
  begin
   if not steamAvailable or (steamUserStats=nil) then begin
    LogMessage('Steam not available');
    exit;
   end;
   LogMessage('SSA: '+name);
   aName:=PAnsiChar(AnsiString(name));
   if enable then
    res:=SteamAPI_ISteamUserStats_SetAchievement(steamUserStats,aName)
   else
    res:=SteamAPI_ISteamUserStats_ClearAchievement(steamUserStats,aName);
   if not res then LogMessage('SSA failed');
  end;

 function GetSteamAuthTicket:string;
  var
   ticket:array[0..1023] of byte;
   size:cardinal;
  begin
   result:='';
   ASSERT(steamAvailable);
   SteamAPI_ISteamUser_GetAuthSessionTicket(steamUser,@ticket,sizeof(ticket),size);
   result:=EncodeHex(@ticket,size);
  end;

 procedure InitSteamAPI;
  var
   pipe,user:integer;
   p:MicroTxnAuthorizationResponse_t;
  begin
   steamAvailable:=SteamAPI_Init;
   if not steamAvailable then begin
    LogMessage('STEAM not available');
    exit;
   end;
   LogMessage('STEAM API available');
   user:=SteamAPI_GetHSteamUser;
   pipe:=SteamAPI_GetHSteamPipe;
   steamClient:=SteamInternal_CreateInterface(STEAMCLIENT_VERSION);
   steamUser:=SteamAPI_ISteamClient_GetISteamUser(steamClient,user,pipe,STEAMUSER_VERSION);
   steamApps:=SteamAPI_ISteamClient_GetISteamApps(steamClient,user,pipe,STEAMAPPS_VERSION);
   steamFriends:=SteamAPI_ISteamClient_GetISteamFriends(steamClient,user,pipe,STEAMFRIENDS_VERSION);
   steamUserStats:=SteamAPI_ISteamClient_GetISteamUserStats(steamClient,user,pipe,STEAMUSERSTAT_VERSION);
//   ForceLogMessage(Format('steamClient=%x steamUser=%x, user=%d pipe=%d',[cardinal(steamClient),cardinal(steamUser),user,pipe]));
   steamID:=SteamAPI_ISteamUser_GetSteamID(steamUser);
   steamGameLang:=SteamAPI_ISteamApps_GetCurrentGameLanguage(steamApps);
   steamUserName:=SteamAPI_ISteamFriends_GetPersonaName(steamFriends);
   LogMessage('SteamID=%d, name="%s", lang="%s"',[steamID,AnsiString(steamUserName),AnsiString(steamGameLang)]);
   //LogMessage('SteamID='+IntToStr(steamID)+' GameLang='+string(steamGameLang));

   // Register callbacks
{   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 1);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 2);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 3);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 17);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 43);
   SteamAPI_RegisterCallback(@callback,k_iSteamUserCallbacks + 54);}

   callbackVMT[1]:=@OnMicroTxnAuthorization;
   callbackObj[0]:=@callbackVMT;
   SteamAPI_RegisterCallback(@callbackObj,k_iSteamUserCallbacks + 52);
  end;

 procedure DoneSteamAPI;
  begin
   if steamAvailable then SteamAPI_Shutdown;
  end;

{ function VerifyOwnership:boolean;
  var
   ticket:string;
  begin
   ticket:=GetSteamAuthTicket;
  end;}

initialization
end.
