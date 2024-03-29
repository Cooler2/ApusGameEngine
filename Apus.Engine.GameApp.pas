﻿// Game Framework launcher class
// Copyright (C) 2017 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.GameApp;
interface
 uses
  {$IFDEF ANDROID}jni,{$ENDIF}
  Apus.Engine.API;

 type
  // How window/screen area should be used
  TGameAppMode=(gamScaleWithAspectRatio,  // Scale W/H of the render area to output rect while keeping its aspect ratio (fixed design)
                gamScaleWithFixedHeight,  // Scale width of the render area to match the output rect (fixed height design)
                gamKeepAspectRatio,       // Modify W/H of the render area to fit the output rect keeping its aspect ratio (fixed design with flexible scale)
                gamUseFullWindow);        // Modify W/H of the render area to match the output rect (flexible design)

 var
   // Default global settings
   gameTitle:string='Apus Game Engine Template';
   configFileName:string8=''; // load this config file (can contain path, which is discarded after file is loaded)
   logFileName:string='game.log'; // default log file name

   usedAPI:TGraphicsAPI=gaAuto;
   usedPlatform:TSystemPlatform {$IFNDEF MSWINDOWS} = spSDL{$ENDIF};
   windowedMode:boolean=true;
   windowBorderless:boolean=false; // use borderless window for NON FULLSCREEN windows
   windowSizeable:boolean=false; // allow user to resize window
   windowWidth:integer=1024;
   windowHeight:integer=768;
   useRealDPI:boolean=true; // use real DPI on High DPI screens (Windows: set DPI awareness mode)
   scaleWindowSize:boolean=true; // enlarge window accordingly if DPI is higher than platform default (96 for desktop monitor)
   scaleScenes:boolean=true;  // set default scale for scenes according to DPI
   scaleFonts:boolean=true;   // enable font scaling according to DPI
   gameMode:TGameAppMode=gamUseFullWindow;

   deviceDPI:integer=96; // equals game.screenDPI
   deviceScale:single=1.0; // deviceDPI/96
   noVSync:boolean=false;
   directRenderOnly:boolean=true; // true -> for OpenGL: always render directly to the backbuffer, false -> allow frame render into texture
   useDepthTexture:boolean=false; // use depth texture instead of the regular depth buffer (not available with direct render)
   checkForSteam:boolean=false;  // Check if STEAM client is running and get AppID
   useSystemCursor:boolean=true; // true - system hardware cursor, false - system cursor is disabled, custom cursor must be drawn
   useCustomStyle:boolean=false; // init cuttom style?
   useConsoleScene:boolean=true;   // Create console scene [Win]+[~]
   useTweakerScene:boolean=false;  // Create Tweaker scene [Ctrl]+[~]
   useDefaultLoaderScene:boolean=true; // start with default scene with spinner
   configDir:string;
   instanceID:integer=0;
   gameLangCode:string='en';
   debugMode:boolean=false;

 type
  TGameApplication=class
   // Call these methods from external code to launch the game
   constructor Create;
   // Basic initialization (non-visual): logs, configs, settings
   procedure Prepare; virtual;
   // Creates game objects, window, starts render, create scenes and launch infinite main loop
   procedure Run; virtual;
   // Finalization (you can use Free to call this indirectly)
   destructor Destroy; override;

   // These methods provide default functionality. Override them to add extra functions
   procedure HandleParam(param:string); virtual;    // Handle each command line option
   procedure LoadOptions; virtual;   // Load settings (may add default values)
   procedure SaveOptions; virtual;   // Save settings
   procedure SetupGameSettings(var settings:TGameSettings); virtual;
   // Initialization routines: override with actual functionality
   procedure InitSound; virtual;
   procedure LoadFonts; virtual;   // Load font files (called once)
   procedure SelectFonts; virtual;  // Select font constants (may be called many times)
   procedure InitStyles; virtual; // Which styles to add?
   procedure CreateScenes; virtual; // Create and add game scenes
   procedure LoadScenes; virtual;
   procedure InitCursors; virtual;
   procedure SetupHighDPI; virtual;

   procedure FatalError(msg:string); virtual;

   procedure onResize; virtual;

   // Useful tools
   procedure ShowMessage(mes:String8;OkEvent:String8='';x:integer=0;y:integer=0); virtual;
   procedure Confirm(mes,OkEvent,CancelEvent:String8;x:integer=0;y:integer=0); virtual;
   procedure Ask(mes,YesEvent,NoEvent:String8;x:integer=0;y:integer=0); virtual;

{   // Borderless window
   function GetWindowAreaType(x,y:integer):}
  protected
   sysPlatform:ISystemPlatform;
   screenWidth,screenHeight:integer;
   realScreenWidth,realScreenHeight:integer;
  end;

 {$IFDEF ANDROID}
  // Binding functions (to be exported)
  procedure AppSurfaceChanged(env:PJNIEnv;this:jobject; width, height:jint);
  procedure AppInit(env:PJNIEnv;this:jobject; view:jobject; width,height,dpi:jint; assetManager:jobject; sdkVer:jint);
  procedure AppDrawFrame(env:PJNIEnv;this:jobject);
  procedure AppPause(env:PJNIEnv;this:jobject);
  procedure AppResume(env:PJNIEnv;this:jobject);
  function AppInput(env:PJNIEnv;this:jobject; action,i1,i2:jint; text:jstring):jstring;
  procedure AppTouch(env:PJNIEnv;this:jobject; x,y:jfloat; action:jint);
  procedure AppKey(env:PJNIEnv;this:jobject; keyCode,UChar:jint; event: jobject);
 {$ENDIF}

implementation
 uses
  {$IFDEF MSWINDOWS}Windows,Apus.Engine.WindowsPlatform,{$ENDIF}
  {$IFDEF SDL}Apus.Engine.SDLplatform,{$ENDIF}
  {$IFDEF ANDROID}Apus.Android,Apus.Engine.AndroidGame,{$ENDIF}
   SysUtils,Apus.Common,Apus.AnimatedValues,Apus.ControlFiles,Apus.Engine.UDict,
   Apus.FastGFX,Apus.EventMan,Apus.Publics,
   Apus.Engine.UI,Apus.Engine.Game,Apus.Engine.Tools,
   Apus.Engine.ConsoleScene,Apus.Engine.TweakScene,Apus.Engine.MessageScene,
   Apus.Engine.CustomStyle,Apus.Engine.BitmapStyle,
   Apus.Engine.Sound
  {$IFDEF DIRECTX},Apus.Engine.DXGame8{$ENDIF}
  {$IFDEF OPENGL},Apus.Engine.OpenGL{$ENDIF}
  {$IFDEF STEAM},Apus.Engine.SteamAPI{$ENDIF};

type
 // Default loading scene displaying spinner
 TLoadingScene=class(TGameScene)
  v:TAnimatedValue;
  tex:TTexture;
  constructor Create;
  procedure Render; override;
 end;

var
 app:TGameApplication;

{$IFDEF ANDROID}
{Android bindings}
var
  initialized:boolean;

procedure AppSurfaceChanged(env:PJNIEnv;this:jobject; width, height:jint);
 begin
  windowWidth:=width;
  windowHeight:=height;
  // Resize window
 end;

procedure AppInit(env:PJNIEnv;this:jobject; view:jobject; width,height,dpi:jint; assetManager:jobject; sdkVer:jint);
 begin
  if initialized then exit;
  try
   LogI(Format('AppInit: %d %d %d',[width,height,dpi]));
   InitAndroid(env,this,view);

   windowWidth:=width;
   windowHeight:=height;
   deviceDPI:=dpi;
   Signal('Engine\InitGame');
   if @initGame<>nil then InitGame;
   initialized:=true;
  except
   on e:exception do LogI('Error in AppInit: '+ExceptionMsg(e));
  end;
 end;

procedure AppDrawFrame(env:PJNIEnv;this:jobject);
 begin
  try
   //DebugMessage('DrawFrame!');
   Signal('Engine\onFrame');
  except
   on e:exception do LogI('Error in AppDrawFrame: '+ExceptionMsg(e));
  end;
 end;

procedure AppPause(env:PJNIEnv;this:jobject);
 begin
  try
   LogI('AppPause!');
   Signal('Engine\ActivateWnd',0);
   Signal('Sound\Pause');
   HideVirtualKeyboard;
  except
   on e:exception do LogI('Error in AppPause: '+ExceptionMsg(e));
  end;
 end;

procedure AppResume(env:PJNIEnv;this:jobject);
 begin
  try
   LogI('AppResume!');
   Signal('Engine\ActivateWnd',1);
   Signal('Sound\Resume');
  except
   on e:exception do LogI('Error in AppResume: '+ExceptionMsg(e));
  end;
 end;

function AppInput(env:PJNIEnv;this:jobject; action,i1,i2:jint; text:jstring):jstring;
 var
  wst:WideString;
  c:TUIControl;
  i:integer;
 begin
  try
   result:=nil;
   if appEnv=nil then appEnv:=env;
   wst:=DecodeUTF8(StringFromJavaString(text));
   c:=FocusedControl;
   LogMessage(Format('AppInput: %d %d %d %s',[action, i1, i2, wst]));
   if (c<>nil) and (c is TUIEditBox) then
    with c as TUIEditBox do begin
    case action of
     // Commit text or set selection
     1,2:begin
       if selCount>0 then begin
         // replace selection with given text
         delete(realtext,selstart,selcount);
         insert(wst,realText,selStart);
       end else begin
         // Insert text into cursor position and select it
         insert(wst,realText,cursorpos+1);
         selstart:=cursorpos+1;
       end;
       selcount:=length(wst);
       cursorpos:=selstart+selcount-1;
       if action=1 then begin
         // Commit
         selstart:=cursorPos+1;
         selCount:=0;
       end;
       LogMessage(Format('Input action=%d, sel=%d:%d, cursor=%d',[action,selstart,selcount,cursorpos]));
     end;
     // Get text before cursor
     3:begin
       if selCount>0 then wst:=copy(realText,1,selStart-1)
        else wst:=copy(realText,1,cursorPos);
       if length(wst)>i1 then delete(wst,1,length(wst)-i1);
       result:=JavaString(EncodeUTF8(wst));
       LogMessage(Format('res=%s (%s)',[PtrToStr(result),EncodeUTF8(wst)]));
     end;
     // Get text after cursor
     4:begin
       if selCount>0 then wst:=copy(realtext,selStart+selCount,i1)
        else wst:=copy(realText,cursorPos+1,i1);
       result:=JavaString(EncodeUTF8(wst));
       LogMessage(Format('res=%s (%s)',[PtrToStr(result),EncodeUTF8(wst)]));
     end;
     // Get selected text
     5:if selCount>0 then begin
       wst:=copy(realText,selStart,selCount);
       result:=JavaString(EncodeUTF8(wst));
     end;
     // Delete text
     6:begin
       // After selection
       if selCount>0 then i:=selStart+selCount
        else i:=cursorpos+1;
       delete(realText,i,i2);
       // Before selection
       if selCount>0 then i:=selStart-1
        else i:=cursorPos;
       while (i>0) and (i1>0) do begin
        delete(realText,i,1);
        dec(i); dec(i1);
        dec(selStart);
        dec(cursorpos);
       end;
     end;
     // Set selection/composing region
     7,8:begin
       selStart:=i1+1;
       selCount:=i2-i1+1;
       cursorpos:=i2;
     end;

     // Enter
     10:begin
      Signal('Kbd\Char',13);
      Signal('Kbd\UniChar',13);
     end;
    end;
   end;
  except
   on e:exception do LogI('Error in AppInput: '+ExceptionMsg(e));
  end;
 end;

const
  // UI event types
  ACTION_DOWN   = 0;
  ACTION_UP     = 1;
  ACTION_MOVE   = 2;
  ACTION_CANCEL = 3;

procedure AppTouch(env:PJNIEnv;this:jobject; x,y:jfloat; action:jint);
 var
  tag:integer;
 begin
  try
   tag:=smallint(round(x))+smallint(round(y)) shl 16;
   //LogI(Format('AppTouch: %d  x=%5.1f  y=%5.1f tag=%8x',[action,x,y,tag]));
   if action=ACTION_DOWN then Signal('Engine\SingleTouchStart',tag);
   if action=ACTION_UP then Signal('Engine\SingleTouchRelease',tag);
   if action=ACTION_MOVE then Signal('Engine\SingleTouchMove',tag);
  except
   on e:exception do LogI('Error in AppTouch: '+ExceptionMsg(e));
  end;
 end;

procedure AppKey(env:PJNIEnv;this:jobject; keyCode,UChar:jint; event: jobject);
 begin
  LogI(Format('AppKey: %d  %d',[keyCode,UChar]));
 end;
{$ENDIF}

{ TGameApplication }

constructor TGameApplication.Create;
 begin
  app:=self;
  {$IFDEF MSWINDOWS}
  if usedPlatform in [spWindows,spDefault] then sysPlatform:=TWindowsPlatform.Create;
  {$ELSE}
  if usedPlatform=spWindows then raise EFatalError.Create('Ooops! Windows platform on a non-windows system!');
  {$ENDIF}
  {$IFDEF UNIX}
  if usedPlatform=spDefault then usedPlatform:=spSDL;
  {$ENDIF}

  if usedPlatform=spSDL then begin
   {$IFDEF SDL}
   sysPlatform:=TSDLPlatform.Create;
   {$ELSE}
   raise EError.Create('Define SDL'); // Define SDL symbol to add SDL support
   {$ENDIF}
  end;
  if sysPlatform=nil then raise EFatalError.Create('No platform interface');
  sysPlatform.GetScreenSize(screenWidth,screenHeight);
  sysPlatform.GetRealScreenSize(realScreenWidth,realScreenHeight);
 end;

procedure TGameApplication.CreateScenes;
 begin
  Signal('GAMEAPP\CreateScenes');
 end;

procedure TGameApplication.LoadScenes;
 var
  scene:TGameScene;
 begin
  Signal('GAMEAPP\LoadScenes');
  TGameScene.LoadAllScenes;
 end;

destructor TGameApplication.Destroy;
 begin
  if game<>nil then game.Stop;
  DoneSoundSystem;
  inherited;
 end;

procedure TGameApplication.FatalError(msg: string);
 begin
  ErrorMessage(msg);
  halt;
 end;

procedure TGameApplication.Ask(mes, YesEvent, NoEvent: String8; x, y: integer);
 begin
  Apus.Engine.MessageScene.Ask(mes,YesEvent,NoEvent,x,y);
 end;

procedure TGameApplication.Confirm(mes, OkEvent, CancelEvent: String8; x,
  y: integer);
 begin
  Apus.Engine.MessageScene.Confirm(mes,OkEvent,CancelEvent,x,y);
 end;

procedure TGameApplication.ShowMessage(mes, OkEvent: String8; x, y: integer);
 begin
  Apus.Engine.MessageScene.ShowMessage(mes,OkEvent,x,y);
 end;

procedure TGameApplication.HandleParam(param: string);
 begin
  param:=UpperCase(param);
  if param='-WND' then windowedMode:=true;
  if param='-FULLSCREEN' then windowedMode:=false;
  if param='-NOVSYNC' then noVSync:=true;
  if param='-DEBUG' then begin
   debugMode:=true;
   debugCriticalSections:=true;
  end;
  if param='-NOSTEAM' then checkForSteam:=false;
 end;

procedure TGameApplication.InitCursors;
 begin
  game.ToggleCursor(CursorID.Default);
  game.ToggleCursor(CursorID.Wait);
  Signal('GAMEAPP\InitCursors');
 end;

procedure TGameApplication.InitStyles;
 begin
  if useCustomStyle then InitCustomStyle('Images\');
  Signal('GAMEAPP\InitStyles');
 end;

procedure TGameApplication.LoadFonts;
 begin
  LogMessage('Loading fonts');
  Signal('GAMEAPP\LoadFonts');
 end;

procedure TGameApplication.LoadOptions;
 var
  i:integer;
 begin
  try
   // InstanceID = random constant
   instanceID:=CtlGetInt(configFileName+':\InstanceID',0);
   if instanceID=0 then begin
    instanceID:=(1000*random(50000)+MyTickCount shl 8+round(now*1000)) mod 100000000;
    CtlSetInt(configFileName+':\InstanceID',instanceID);
   end;

   // Window or Fullscreen
   if ctlGetBool(configFileName+':\Options\FullScreen',false) then windowedMode:=false;

   // Window size
   i:=CtlGetInt(configFileName+':\Options\WindowWidth',-1);
   if i>0 then begin
    windowWidth:=i;
    windowHeight:=CtlGetInt(configFileName+':\Options\WindowHeight',windowHeight);
   end;
   scaleWindowSize:=ctlGetBool(configFileName+':\Options\scaleWindowSize',scaleWindowSize);

   Signal('GAMEAPP\OptionsLoaded');
  except
   on e:exception do ForceLogMessage('Options error: '+ExceptionMsg(e));
  end;
 end;


procedure TGameApplication.onResize;
 begin
  Signal('GAMEAPP\onResize');
  if game.running then SelectFonts;
 end;

{$IFDEF MSWINDOWS}
{$IF Declared(SetProcessDPIAware)} {$ELSE}
function SetProcessDPIAware:BOOL; external user32 name 'SetProcessDPIAware';
{$IFEND}
procedure SetDPIAwareness;
 begin
  SetProcessDPIAware;
 end;
{$ENDIF}

procedure TGameApplication.Prepare;
 var
  i:integer;
  st:string;
 begin
  try
   {$IFDEF MSWINDOWS}
   if useRealDPI then SetDPIAwareness;
   {$ENDIF}
   PublishVar(@gameLangCode,'gameLangCode',TVarTypeString);
   RegisterThread('ControlThread');
   //SetCurrentDir(ExtractFileDir(ParamStr(0)));
   Randomize;
   // Log rotation
   if DirectoryExists('Logs') then begin
    configDir:='Logs\';
    st:='Logs\'+logFileName;
   end else
    st:=logFileName;
   st:=FileName(st);
   if fileExists(st) then
     RenameFile(st,ChangeFileExt(st,'.old'));
   UseLogFile(st);
   LogCacheMode(true,false,true);
   SetLogMode(lmVerbose);

   if configFileName<>'' then begin
    configFileName:=FileName(configFileName);
    if not FileExists(configFileName) then
     FatalError('Config file not found: '+configFileName);
    UseControlFile(configFileName);
    configFileName:=ExtractFileName(configFileName);
    LoadOptions;
    SaveOptions; // Save modified settings (if default values were added)
   end;

   for i:=1 to paramCount do HandleParam(paramstr(i));

   {$IFDEF OPENGL}
   if directRenderOnly then disableDRT:=true;
   Apus.Engine.Game.useDepthTexture:=useDepthTexture;
   {$ENDIF}

   {$IFDEF STEAM}
   if checkForSteam then InitSteamAPI;
   if steamAvailable then
    // Выбор языка при установке из Стима
    if FileExists('SelectLang') and (steamID<>0) then begin
     st:=lowercase(steamGameLang);
     if st='russian' then langCode:='ru';
     if st='english' then langCode:='en';
     LogMessage('First time launch: Steam language is '+langCode);
     SaveOptions;
     DeleteFile('SelectLang');
    end;
   {$ENDIF}

  except
   on e:exception do begin
    ForceLogMessage('AppCreate error: '+ExceptionMsg(e));
    ErrorMessage('Fatal error: '#13#10+ExceptionMsg(e));
    halt;
   end;
  end;
 end;

procedure TGameApplication.InitSound;
var
 lib:TSoundLib;
begin
 Signal('GAMEAPP\InitSound');
 lib:=slDefault;
 {$IFDEF IMX}
 lib:=slIMixer;
 {$ENDIF}
 {$IFDEF SDLMIX}
 lib:=slSDL;
 {$ENDIF}
 try
  InitSoundSystem(lib,systemPlatform.GetWindowHandle);
 except
  on e:Exception do begin
   ForceLogMessage('Sound initialization failed. Continue without sound. '+e.message);
   ShowMessage('No sound available. See log for details.'#13#10'Press OK to continue without sound.','Sound system error');
  end;
 end;
end;

procedure EngineEventHandler(event:TEventStr;tag:TTag);
 begin
  if app=nil then exit;
  if event='ENGINE\BEFORERESIZE' then app.onResize;
 end;

procedure MouseEventHandler(event:TEventStr;tag:TTag);
 var
  x,y:integer;
 begin
  if app=nil then exit;
  if windowBorderless and windowSizeable then begin // manual window sizing implementation
   if event='MOUSE\MOVE' then begin
    x:=ExtractWord(tag,0);
    y:=ExtractWord(tag,1);
    LogMessage('',[x,y]);
   end;
  end;
 end;


procedure TGameApplication.Run;
 var
  settings:TGameSettings;
  loadingScene:TGameScene;
 begin
  // CREATE GAME OBJECT
  // ------------------------
  {$IFDEF MSWINDOWS}
   if usedAPI=gaAuto then begin
    {$IFDEF DIRECTX}
     usedAPI:=gaDirectX;
    {$ENDIF}
    {$IFDEF OPENGL}
     usedAPI:=gaOpenGL2
    {$ENDIF}
   end;
   {$ENDIF}

  game:=TGame.Create(sysPlatform,TOpenGL.Create);
  if game=nil then raise EError.Create('Game object not created!');

  // CONFIGURE GAME OBJECT
  // ------------------------
  SetupGameSettings(settings);
  game.SetSettings(settings);

  if settings.mode.displayMode<>TDisplayMode.dmSwitchResolution then
   ForceLogMessage('Running in cooperative mode')
  else
   ForceLogMessage('Running in exclusive mode');

  SetEventHandler('ENGINE',EngineEventHandler);
  SetEventHandler('MOUSE',MouseEventHandler);

  // LAUNCH GAME OBJECT
  // ------------------------
  try
   game.Run;
  except
   on e:exception do begin
     ErrorMessage('Failed to run the game: '+ExceptionMsg(e));
     halt;
   end;
  end;
  ForceLogMessage('RUN');

  SetupHighDPI;

  // LOADER SCENE
  // ------------------------
  if useDefaultLoaderScene then begin
   loadingScene:=TLoadingScene.Create;
   game.AddScene(loadingScene);
  end;

  // More initialization
  InitSound;
  InitCursors;
  LoadFonts;
  SelectFonts;
  InitStyles;
  InitMessageScene;
  if useConsoleScene then AddConsoleScene;
  if useTweakerScene then CreateTweakerScene(txt.GetFont('Default',6),txt.GetFont('Default',7));
  // Create scenes
  try
   CreateScenes;
  except
   on e:Exception do begin
    ErrorMessage('Fatal error in scene creation: '+ExceptionMsg(e));
    exit;
   end;
  end;
  // Load scene resources
  try
   LoadScenes;
  except
   on e:Exception do begin
    ErrorMessage('Fatal error in scene creation: '+ExceptionMsg(e));
    exit;
   end;
  end;

  game.ToggleCursor(CursorID.Wait,false);
  Signal('GAMEAPP\Initialized');
  // MAIN LOOP
  // ------------------------
  repeat
   try
    PingThread;
    CheckCritSections;
    Delay(5); // поддерживает сигналы тем самым давая возможность синхронно на них реагировать
    Signal('GAMEAPP\onIdle');
   except
    on e:exception do ForceLogMessage('Error in Control Thread: '+e.message);
   end;
  until game.terminated;
  Signal('GAMEAPP\Terminated');
  ForceLogMessage('Control thread exit');
 end;

procedure TGameApplication.SaveOptions;
 begin
  try
   SaveAllControlFiles;
  except
   on e:exception do ForceLogMessage('Error in options saving:'+ExceptionMsg(e));
  end;
 end;

procedure TGameApplication.SelectFonts;
 begin
  if msgMainFont=0 then msgMainFont:=txt.GetFont('Default',8.5);
  if msgTitleFont=0 then msgTitleFont:=txt.GetFont('Default',11);
  Signal('GAMEAPP\SelectFonts');
 end;

procedure TGameApplication.SetupGameSettings(var settings: TGameSettings);
var
 winDispMode:TDisplayMode;
begin
  with settings do begin
   title:=GameTitle;
   width:=windowWidth;
   height:=windowHeight;
   deviceDPI:=game.screenDPI;
   deviceScale:=deviceDPI/96;
   if scaleWindowSize then begin
    width:=round(width*deviceScale);
    height:=round(height*deviceScale);
   end;
   colorDepth:=32;
   refresh:=0;
   if windowSizeable then winDispMode:=TDisplayMode.dmWindow
    else winDispMode:=TDisplayMode.dmFixedWindow;
   if windowBorderless then winDispMode:=TDisplayMode.dmBorderless;
   case gameMode of
    // Для отрисовки используется вся область окна в масштабе реальных пикселей (1:1)
    gamUseFullWindow:begin
      if windowedMode then mode.displayMode:=winDispMode
       else mode.displayMode:=dmFullScreen;
      mode.displayFitMode:=dfmFullSize;
      mode.displayScaleMode:=dsmDontScale;
      if windowedMode then altMode.displayMode:=dmFullScreen
       else altMode.displayMode:=winDispMode;
      altMode.displayFitMode:=dfmFullSize;
      altMode.displayScaleMode:=dsmDontScale;
    end;
    // Для отрисовки используется часть окна в масштабе 1:1
    gamKeepAspectRatio:begin
      if windowedMode then mode.displayMode:=winDispMode
       else mode.displayMode:=dmFullScreen;
      mode.displayScaleMode:=dsmScale;
      mode.displayFitMode:=dfmKeepAspectRatio;
      if windowedMode then altMode.displayMode:=dmFullScreen
       else altMode.displayMode:=winDispMode;
      altMode.displayScaleMode:=dsmScale;
      altMode.displayFitMode:=dfmKeepAspectRatio;
     end;
    else
     raise EError.Create('Game Mode not yet implemented');
   end;

   showSystemCursor:=useSystemCursor;
   zbuffer:=16;
   stencil:=false;
   multisampling:=0;
   slowmotion:=false;
   if noVSync then begin
    VSync:=0;
    game.DebugFeature(dfShowFPS,true);
   end else
    VSync:=1;
  end;
  Signal('GAMEAPP\SetGameSettings');
end;

procedure TGameApplication.SetupHighDPI;
begin
  txt.SetScale(deviceScale);
  SetDefaultUIScale(deviceScale,deviceScale);
end;

{ TLoadingScene }

constructor TLoadingScene.Create;
begin
 inherited Create(true);
 v.Init;
 zOrder:=-1; // place it below others
 SetStatus(TSceneStatus.ssActive);
end;

procedure TLoadingScene.Render;
var
 i,l:integer;
 x,y,a:double;
 scene:TGameScene;
begin
 if tex=nil then begin
  v.Animate(0.6,1500,Spline1);
  tex:=AllocImage(16,8,pfTrueColorAlpha,0,'bar');
  tex.lock;
  SetRenderTarget(tex.data,tex.pitch,tex.width,tex.height);
  FillRect(0,0,tex.width-1,tex.height-1,0);
  FillRect(1,1,tex.width-2,tex.height-2,$FF808080);
  FillRect(2,2,tex.width-3,tex.height-3,$FFFFFFFF);
  tex.unlock;
 end;
 gfx.target.Clear($FF000000);
 for i:=0 to 12 do begin
  a:=i*3.1416/6.5;
  x:=game.renderWidth/2+32*cos(a);
  y:=game.renderHeight/2-32*sin(a);
  L:=50+round(-256*i/13-MyTickCount*0.3) and 255;
  L:=round(v.Value*L);
  draw.RotScaled(x,y,1,1,-a,tex,cardinal(L shl 24)+$FFFFFF);
 end;
 Signal('LOADINGSCENE\Render');
 // Turn scene off if it is not visible anymore
 scene:=game.TopmostVisibleScene(true);
 if (scene<>self) and (scene.effect=nil) then
  SetStatus(TSceneStatus.ssFrozen);
end;

end.

