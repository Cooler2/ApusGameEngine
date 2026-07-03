// Main runtime unit of the engine
//
// IMPORTANT: Nevertheless BasicGame is implemented as class, it is
//            NOT thread-safe itself i.e. does not allow multiple instances!
//            (at least between Run/Stop calls)
//            If you want to access private data (buffers, images) from other
//            threads, use your own synchronization methods
//
// Copyright (C) 2003-2013 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$IFDEF IOS}{$S-}{$ENDIF}
{$R-}
unit Apus.Engine.Game;
interface
uses Classes, Apus.Core, Apus.Threads, Apus.Engine.Types, Apus.Engine.Window, Apus.Engine.API,
  Apus.Engine.DebugOverlays;

var
 onFrameDelay:integer=0; // Sleep this time every frame
 disableDRT:boolean=false; // always render directly to the backbuffer - no
 useDepthTexture:boolean=false; // when default RT is used, allocate a depth buffer texture instead of regular depth buffer
 minRedrawIntervalMs:integer=100; // force frame redraw at least once per interval (0=disabled)

type
 { TGame }
 TGame=class(TGameBase)
  constructor Create(systemPlatform:ISystemPlatform;gfxSystem:IGraphicsSystem); // Создать экземпляр
  procedure Run; override; // запустить движок (создание окна, переключение режима и пр.)
  {$IFDEF DARWIN}
  procedure RunCurrentThread; // run window/event/render lifecycle on the calling OS thread
  procedure AllowMainThreadExit; // control lifecycle finished; graphics may be finalized
  {$ENDIF}
  procedure Stop; override; // остановить и освободить все ресурсы (требуется повторный запуск через Run)
  destructor Destroy; override; // автоматически останавливает, если это не было сделано

  procedure SwitchToAltSettings; override; // Alt+Enter

  // Events
  // Этот метод вызывается из главного цикла всякий раз перед попыткой рендеринга кадра, даже если программа неактивна или девайс потерян
  function OnFrame:boolean; override; // true означает что на экране что-то должно изменится поэтому экран нужно перерисовать. Иначе перерисовка выполнена не будет (движение мыши отслеживается отдельно)
  procedure RenderFrame; override; // этот метод должен отрисовать кадр в backbuffer

  // Scenes
  procedure SwitchToScene(name:string); override;
  procedure ShowWindowScene(name:string;modal:boolean=true); override;
  procedure HideWindowScene(name:string); override;

  // Cursors
  procedure RegisterCursor(CursorID,priority:integer;cursorHandle:THandle); override;
  function GetCursorForID(cursorID:integer):THandle; override;
  procedure ToggleCursor(CursorID:integer;state:boolean=true); override;
  procedure HideAllCursors; override;

  // Translate coordinates in window's client area
  procedure ClientToGame(var p:TPoint); override;
  procedure GameToClient(var p:TPoint); override;

  procedure FLog(st:string); override;
  function GetStatus(n:integer):string; override;
  procedure FireMessage(st:string8;severity:integer=msgInfo); override;
  procedure DebugFeature(feature:TDebugFeature;enable:boolean); override;
  procedure ToggleDebugFeature(feature:TDebugFeature);

  procedure Lock; override;
  procedure Unlock; override;

  // Устанавливает флаги о необходимости сделать скриншот (JPEG or PNG)
  procedure RequestScreenshot(saveAsJpeg:boolean=true); override;
  procedure RequestFrameCapture(obj:TObject=nil); override;
  procedure StartVideoCap(filename:string); override;
  procedure FinishVideoCap; override;

  // Utility functions
  function MouseInRect(r:TRect):boolean; overload; override;
  function MouseInRect(r:TRect2):boolean; overload; override;
  function MouseInRect(x,y,width,height:single):boolean; overload; override;
  function MouseIsNear(x,y,radius:single):boolean; overload; override;

  function MouseWasInRect(r:TRect):boolean; overload; override;
  function MouseWasInRect(r:TRect2):boolean; overload; override;

  procedure WaitFor(pb:PBoolean;msg:string=''); override;

  // Keyboard events utility functions
  procedure SuppressKbdEvent; override;

  function GetDepthBufferTex:TTexture; override;

  procedure Minimize; override;

  // Multi-window
  function AddWindow(settings:TGameSettings):TWindow; override;
  procedure RemoveWindow(wnd:TWindow); override;
  procedure RenderScenesForWindow(wnd:TWindow);
  procedure StopExtraWindows;

  procedure SetSettings(s:TGameSettings); override; // этот метод служит для изменения режима или его параметров
  function GetSettings:TGameSettings; override; // этот метод служит для изменения режима или его параметров

  procedure DPadCustomPoint(x,y:single); override;

 protected
  useMainThread:boolean; // true - launch "main" thread with main loop,
                         // false - no main thread, catch frame events
  canExitNow:boolean; // флаг того, что теперь можно начать деинициализацию
  mainLoopExitRequested:boolean;
  params,newParams:TGameSettings;
  aspectRatio:single;  // Initial aspect ratio (width/height)
  altWidth,altHeight:integer; // saved window size for Alt+Enter
  mainThread:IThread;
  mainThreadErrorMsg:string8;
  controlThreadId:TThreadIdent;
  cursors:array of TObject;
  crSect:TLock;

  curPrior:integer; // приоритет текущего отображаемого курсора
  wndCursor:THandle; // current system cursor
  suppressCharEvent:boolean; // suppress next keyboard event (to avoid duplicated handle of both CHAR and KEY events)

  avgTime,avgTime2:double;
  timerFrame:cardinal;

  customPoints,activeCustomPoints:array of TPoint; // custom navigation points

  // Debug utilities
  debug:TDebugState;

  procedure ApplyNewSettings; virtual; // apply newParams to params - must be called from main thread!
  procedure SetVSync(divider:integer);

  // вызов только из главного потока
  procedure InitGraph; virtual; // Инициализация графической части (переключить режим и все такое прочее)
  procedure InitDefaultResources; virtual;
  procedure AfterInitGraph; virtual; // Вызывается после инициализации графики
  // Set window size/style/position
  //procedure ConfigureMainWindow; virtual;
  // Настраивает отрисовку
  // Производит настройку подчинённых объектов/интерфейсов (Painter, UI и т.д)
  // Вызывается после инициализации а также при изменения размеров окна, области или режима отрисовки
  procedure SetupRenderArea; virtual;
  procedure InitMainLoop; virtual;

  procedure FrameLoop; virtual; // One iteration of the frame loop
  procedure RenderAndPresentFrame; virtual; // May be called from the message handlers
  procedure PresentFrame; virtual;  // Displays back buffer
  procedure DoneGraph; virtual; // Финализация графической части
  // Производит захват кадра и производит с ним необходимые действия
  procedure CaptureFrame; virtual;
  procedure DrawCursor; virtual;
  procedure DrawOverlays; virtual;

  // находит сцену, которая должна получать сигналы о клавиатурном вводе
  function TopmostSceneForKbd:TGameScene; virtual;

  // Events
  // Called when ENGINE\* event is fired
  procedure onEngineEvent(event:String8;tag:NativeInt); virtual;
  // Called when ENGINE\CMD\* event is fired
  procedure onCmdEvent(event:String8;tag:NativeInt); virtual;
  // Called when KBD\* event is fired
  procedure onKbdEvent(event:String8;tag:NativeInt); virtual;
  // Called when JOYSTICK\* event is fired
  procedure onJoystickEvent(event:String8;tag:NativeInt); virtual;
  // Called when GAMEPAD\* event is fired
  procedure onGamepadEvent(event:String8;tag:NativeInt); virtual;

  // Event processors
  procedure CharEntered(charCode,scanCode:integer); virtual;
  procedure KeyPressed(keyCode,scanCode:integer;pressed:boolean=true); virtual;
  procedure SizeChanged(newWidth,newHeight:integer); virtual;
  procedure Activate(activeState:boolean); virtual;

  // Utils
  procedure CreateDebugLogs; virtual;
  // Draw magnified part of the screen under mouse
  procedure DrawMagnifier; virtual;
  // Internal hotkeys such as PrintScreen, Alt+F1 etc
  procedure HandleInternalHotkeys(keyCode:integer;pressed:boolean); virtual;

  procedure HandleGamepadNavigation;
  procedure PrepareRun;
  procedure MainThreadLoop;
 end;

 // Для использования из главного потока
 procedure Delay(time:integer);

implementation
 uses Types, SysUtils, TypInfo, Apus.Engine.CmdProc, Apus.Images, Apus.FastGFX, Apus.Engine.ImageTools,
      Apus.Engine.Resources,
      {$IFDEF VIDEOCAPTURE}Apus.Engine.VideoCapture,{$ENDIF}
      Apus.EventMan, Apus.Engine.Scene, Apus.Engine.UI, Apus.Engine.UITypes, Apus.Engine.UIScene,
      Apus.Publics, Apus.GfxFormats, Apus.Clipboard, Apus.Engine.TextDraw,
      Apus.Engine.Controller,
  Apus.Colors,
  Apus.Engine.RobotAPI,
  Apus.Engine.Notifications,
  Apus.Files,
  Apus.Lib,
  Apus.Strings
  {$IFDEF MSWINDOWS},Windows{$ENDIF};

type

 TGameCursor=class
  ID:integer;
  priority:integer;
  handle:THandle;
  visible:boolean;
 end;

 TVarTypeGameClass=class(TVarTypeStruct)
  class function GetField(variable:pointer;fieldName:string8;out varClass:TVarClass):pointer; override;
  class function ListFields:string8; override;
 end;

 // Startup context for extra window render thread.
 // Ownership: lives in AddWindow stack frame while AddWindow synchronously waits for startup result.
 PExtraWindowContext=^TExtraWindowContext;
TExtraWindowContext=record
  settings:TGameSettings;
  callerReleasedMainContext:boolean; // true when AddWindow was called from main render thread
  resultWnd:TWindow; // set by thread when window is created
  startDone:boolean; // set by thread when startup is finished (success or failure)
  startFailed:boolean;
  errorMsg:string;
 end;

var
 gameEx:TGame;
 perfValues:array[1..16] of int64;
 perfMeasures:array[1..16] of double;
 extraWindowCount:integer=0; // number of active extra windows (secondary render threads)
 addWindowBusy:integer=0; // serialize AddWindow startup to avoid concurrent shared-context handshakes

{$IFDEF FREETYPE}
 // Default vector font is Open Sans
 {$I defaultFont.inc}
{$ELSE}
 // Default raster fonts (exact sizes are 6.0, 7.0 and 9.0)
 {$I defaultFont8.inc}
 {$I defaultFont10.inc}
 {$I defaultFont12.inc}
{$ENDIF}


// TODO: move to Apus.Utils/CmdLine once modern replacement API is finalized.
function HasParamLocal(const name:string):boolean;
var
 i:integer;
 s,n:string;
begin
 n:=LowerCase(name);
 for i:=1 to ParamCount do begin
  s:=LowerCase(ParamStr(i));
  if s=n then exit(true);
 end;
 result:=false;
end;

// TODO: move to Apus.Profiling when profiling API migration is complete.
procedure StartMeasure(id:integer); inline;
begin
 if (id<low(perfValues)) or (id>high(perfValues)) then exit;
 perfValues[id]:=CoreTime.Ticks;
end;

// TODO: move to Apus.Profiling when profiling API migration is complete.
function EndMeasure(id:integer):double; inline;
var
 d:int64;
begin
 if (id<low(perfValues)) or (id>high(perfValues)) then exit(0);
 d:=CoreTime.Ticks-perfValues[id];
 result:=d;
 perfMeasures[id]:=result;
end;

// TODO: move to Apus.Profiling when profiling API migration is complete.
function EndMeasure2(id:integer):double; inline;
var
 d:double;
begin
 if (id<low(perfValues)) or (id>high(perfValues)) then exit(0);
 d:=CoreTime.Ticks-perfValues[id];
 result:=d;
 perfMeasures[id]:=perfMeasures[id]*0.9+d*0.1;
end;

{ TGame }

procedure TGame.HandleGamepadNavigation;
var
 scene:TUIScene;
 procedure Traverse(e:TUIElement);
  var
   child:TUIElement;
   pnt:TPoint;
  begin
   if e=nil then exit;
   with e do begin
    if not (flags.enabled and flags.visible) then exit;
    pnt:=GetPosOnScreen.CenterPoint;
    if e is TUIButton then activeCustomPoints:=activeCustomPoints+[pnt];
    for child in children do Traverse(child);
   end;
  end;
begin
 if gamepadNavigationMode=gnmDisabled then exit;
 Lock;
 try
  activeCustomPoints:=customPoints;
  SetLength(customPoints,0);
  if gamepadNavigationMode=gnmAuto then begin
   // Add clickable UI objects
   if window.topmostScene is TUIScene then scene:=TUIScene(window.topmostScene)
    else exit;
   Traverse(scene.UI);
  end;
 finally
  Unlock;
 end;
end;

procedure TGame.HandleInternalHotkeys(keyCode:integer; pressed:boolean);
 procedure ToggleDebugOverlay(n:integer);
  begin
   if debug.overlay=n then debug.overlay:=0
    else debug.overlay:=n;
  end;
 function DebugOverlayHotkeyActive:boolean;
  begin
   result:=(debugHotkey<>0) and Bits.HasAll(window.shiftState,debugHotkey);
  end;
begin
  if pressed then begin
   // Alt+Enter - switch display settings
   if (TKey(keyCode and $FF)=TKey.Enter) and (window.shiftstate and sscAlt>0) then
      if (params.mode.displayMode<>params.altMode.displayMode) and
         (params.altMode.displayMode<>dmNone) then
       SwitchToAltSettings;

   // Alt+F11
   if (TKey(keyCode and $FF)=TKey.F11) and Bits.HasAll(window.shiftState,sscAlt) then begin
     SetVSync(params.VSync xor 1); // toggle vsync
     if params.VSync>0 then ShowToast('VSync: ON',TToastKind.Success)
      else ShowToast('VSync: OFF',TToastKind.Warning);
   end;

   // F12 or PrintScreen - screenshot (JPEG), Alt+F12 - (loseless)
   if (TKey(keyCode and $FF)=TKey.PrintScreen) or (TKey(keyCode and $FF)=TKey.F12) then
     RequestScreenshot(not Bits.HasAll(window.shiftState,sscAlt));

   if DebugOverlayHotkeyActive then begin
     if TKey(keyCode and $FF)=TKey.F1 then begin
       if debug.overlay=0 then begin
        debug.overlay:=1;
        DebugFeature(dfShowFPS,true);
       end else begin
        debug.overlay:=0;
        debug.features:=[];
       end;
     end else
     if TKey(keyCode and $FF)=TKey.F3 then
       ToggleDebugFeature(dfShowMagnifier);
   end;

   // [Alt]+[1] .. [Alt]+[9] - switch debug overlay when enabled
   if (debug.overlay>0) and (TKey(keyCode and $FF) in [TKey.D1..TKey.D9]) and Bits.HasAll(window.shiftState,sscAlt) then begin
    debug.overlay:=1+keyCode-byte(TKey.D1);
   end;

   // Shift+Alt+F1 - Create debug logs
   if (TKey(keyCode and $FF)=TKey.F1) and
      (window.shiftState and sscAlt>0) and
      (window.shiftState and sscShift>0) then CreateDebugLogs;
  end;
end;

procedure TGame.RequestScreenshot(saveAsJpeg:boolean=true);
begin
 window.RequestScreenshot(saveAsJpeg);
end;

procedure TGame.RequestFrameCapture(obj:TObject=nil);
begin
 window.RequestFrameCapture(obj);
end;

procedure TGame.ApplyNewSettings;
begin
 params:=newParams;
 if (params.mode.displayMode=dmFullScreen) and ((altWidth=0) or (altHeight=0)) then begin
  // save size for windowed mode
  altWidth:=params.width;
  altHeight:=params.height;
 end;

 if running then begin // смена параметров во время работы
  with params.mode do
   Log.Msg('Change mode to: %s,%s,%s %d x %d ',
    [displayMode.ToString, displayFitMode.ToString, displayScaleMode.ToString,
     params.width, params.height]);
  window.Configure(params);
  if gfx.target<>nil then gfx.target.Backbuffer;
  SetupRenderArea;
  window.NotifyScenesModeChanged;
 end;
end;

procedure TGame.SetVSync(divider: integer);
begin
 if (mainThread<>nil) and (mainThread.ID<>GetCurrentThreadID) then begin
  Signal('ENGINE\Cmd\SetSwapInterval',divider);
  exit;
 end;
 params.VSync:=divider;
 if gfx.config.SetVSyncDivider(divider) then exit;
 if window.SetVSync(divider) then exit;
 Log.Warn('Failed to set VSync: no method available');
end;

procedure TGame.SetSettings(s: TGameSettings);
begin
 if not systemPlatform.canChangeSettings then exit;
 newParams:=s;
 if useMainThread and (mainThread=nil) then begin
  ApplyNewSettings; exit;
 end;
 if (mainThread=nil) or (GetCurrentThreadID<>mainThread.ID) then
  Signal('Engine\CMD\ChangeSettings')
 else
  ApplyNewSettings;
end;

function TGame.MouseInRect(r:TRect):boolean;
begin
 result:=window.MouseInRect(r);
end;

function TGame.MouseInRect(r:TRect2):boolean;
begin
 result:=window.MouseInRect(r);
end;

function TGame.MouseInRect(x,y,width,height:single):boolean;
begin
 result:=window.MouseInRect(x,y,width,height);
end;

function TGame.MouseIsNear(x,y,radius:single):boolean;
begin
 result:=window.MouseIsNear(x,y,radius);
end;

procedure TGame.CharEntered(charCode,scanCode:integer);
var
 scene:TGameScene;
 key:cardinal;
 wst:WideString;
 ast:AnsiString;
begin
  if suppressCharEvent then begin
   suppressCharEvent:=false; exit;
  end;
  if window.shiftstate and sscBaseMask=sscCtrl then exit; // Ignore Ctrl+*

  // Send to active scene
  scene:=TopmostSceneForKbd;
  if scene<>nil then begin
   // TODO: lossy Unicode→ANSI conversion — non-ASCII chars may produce empty ast,
   // causing ast[1] access to read garbage. Rework to use charcode directly.
   wst:=WideChar(charcode);
   ast:=AnsiString(wst);
   if length(ast)=0 then exit;
   key:=byte(ast[1])+(scancode and $FF) shl 8+(charcode and $FFFF) shl 16;
   scene.WriteChar(key);
  end;
end;

procedure TGame.KeyPressed(keyCode,scanCode:integer;pressed:boolean=true);
var
 scene:TGameScene;
begin
  ASSERT(scancode in [0..255]);
  // Buffer the key event (down or up) into the kbd-topmost scene.
  // The engine drains it before Process via TGameScene.PumpInput → DispatchKey.
  scene:=TopmostSceneForKbd;
  if scene<>nil then
   scene.WriteKey(cardinal(keyCode and $FFFF) or (cardinal(scanCode and $FF) shl 16) or (cardinal(ord(pressed)) shl 24));
  HandleInternalHotkeys(keyCode,pressed);

  if pressed then
    window.keyState[scanCode]:=window.keyState[scanCode] or 1
  else
    window.keyState[scanCode]:=window.keyState[scanCode] and $FE;
end;

procedure TGame.SizeChanged(newWidth,newHeight:integer);
begin
 if (window.windowWidth<>newWidth) or (window.windowHeight<>newHeight) then begin
  window.windowWidth:=newWidth;
  window.windowHeight:=newHeight;
  Log.Msg('RESIZED: %d,%d',[window.windowWidth,window.windowHeight]);
  SetupRenderArea;
  window.screenChanged:=true;
 end;
end;

procedure TGame.Activate(activeState:boolean);
begin
 window.active:=activeState;
 if not window.active and (params.mode.displayMode=dmFullScreen) then Minimize;
 Log.Msg('ACTIVATE: %d',[byte(window.active)]);
 Signal('Engine\ActivateWnd',byte(window.active));
 if params.showSystemCursor then wndCursor:=0;
end;

function TGame.MouseWasInRect(r:TRect):boolean;
begin
 result:=window.MouseWasInRect(r);
end;

function TGame.MouseWasInRect(r:TRect2):boolean;
begin
 result:=window.MouseWasInRect(r);
end;

constructor TGame.Create(systemPlatform:ISystemPlatform;
  gfxSystem: IGraphicsSystem);
begin
 inherited Create(systemPlatform,gfxSystem);
 Log.Force('Creating '+self.ClassName);
 game:=self;

 running:=false;
 terminated:=false;
 canExitNow:=false;
 mainLoopExitRequested:=false;
 useMainThread:=true;
 controlThreadId:=GetCurrentThreadId;
 // TODO: window fields initialized here before window is created - move to post-CreateWindow init
 mainThread:=nil;
 params.VSync:=1;
 crSect.Init('MainGameObj',20);
 // Primary display
 systemPlatform.GetScreenSize(screenWidth,screenHeight);
 Log.Msg('Screen: %dx%d DPI=%d',[screenWidth,screenHeight,systemPlatform.GetScreenDPI]);

 // TODO: PublishVar for renderWidth/renderHeight/windowWidth/windowHeight
 // needs window to exist - move to post-CreateWindow init
 PublishVar(@game,'game',TVarTypeGameClass);
end;

function TGame.GetSettings:TGameSettings;
 begin
  result:=params;
 end;

function TGame.GetStatus(n:integer):string;
 begin
  result:='';
 end;

destructor TGame.Destroy;
 begin
  if running then Stop;
  crSect.Cleanup;
  inherited;
 end;

procedure TGame.DoneGraph;
 begin
  Log.Msg('DoneGraph Start');
  DoneRobotAPI;
  Signal('Engine\BeforeDoneGraph');
  gfx.Done;
  window.DoneGraph;

  window.Show(false);
  Signal('Engine\AfterDoneGraph');
  Log.Msg('DoneGraph End');
 end;

procedure TGame.DPadCustomPoint(x, y: single);
 begin
  Lock;
   try
    SetLength(customPoints,length(customPoints)+1);
    customPoints[high(customPoints)].x:=round(x);
    customPoints[high(customPoints)].y:=round(y);
   finally
    Unlock;
   end;
 end;

procedure TGame.DrawMagnifier;
begin
 DrawDebugMagnifier(debug);
end;

procedure TGame.FLog(st:string);
begin
 window.FLog(st);
end;

procedure TGame.Lock;
 var
  caller:pointer;
 begin
  caller:={$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF};
  crSect.Enter(caller);
 end;

procedure TGame.Unlock;
 begin
  crSect.Leave;
 end;

procedure TGame.InitDefaultResources;
var
 x,y:integer;
 size:single;
begin
 // Built-in fonts
 {$IFDEF FREETYPE}
 txt.LoadVectorFont(TBuffer.CreateFrom(@OpenSans_Regular,OpenSans_Regular_Size),'Default');
 {$ELSE}
 txt.LoadRasterFont(TBuffer.CreateFrom(@defaultFont8,length(defaultFont8)));
 txt.LoadRasterFont(TBuffer.CreateFrom(@defaultFont10,length(defaultFont10)));
 txt.LoadRasterFont(TBuffer.CreateFrom(@defaultFont12,length(defaultFont12)));
 {$ENDIF}
 size:=2+0.056*window.screenDPI;
 defaultFont:=txt.GetFont('Default',size);
 smallFont:=txt.GetFont('Default',size*0.8);
 largerFont:=txt.GetFont('Default',size*1.25);

 // Default checker texture
 defaultTexture:=AllocImage(32,32,ipfARGB,aiTexture+aiAutoMipMap,'defaultTex');
 DrawToTexture(defaultTexture);
 for y:=0 to defaultTexture.height-1 do
   for x:=0 to defaultTexture.width-1 do
    PutPixel(x,y,$FF606060+$404040*(((x div 8) xor (y div 8)) and 1));
  defaultTexture.Unlock;
 //defaultTexture.SetFilter(TTexFilter.fltNearest);

 // Mouse cursors
 if params.showSystemCursor then begin
  RegisterCursor(CursorID.Default,1,systemPlatform.GetSystemCursor(CursorID.Default));
  RegisterCursor(CursorID.Link,2,systemPlatform.GetSystemCursor(CursorID.Link));
  RegisterCursor(CursorID.Wait,9,systemPlatform.GetSystemCursor(CursorID.Wait));
  RegisterCursor(CursorID.Input,3,systemPlatform.GetSystemCursor(CursorID.Input));
  RegisterCursor(CursorID.Help,3,systemPlatform.GetSystemCursor(CursorID.Help));
  RegisterCursor(CursorID.ResizeH,5,systemPlatform.GetSystemCursor(CursorID.ResizeH));
  RegisterCursor(CursorID.ResizeW,5,systemPlatform.GetSystemCursor(CursorID.ResizeW));
  RegisterCursor(CursorID.ResizeHW,6,systemPlatform.GetSystemCursor(CursorID.ResizeHW));
  RegisterCursor(CursorID.Cross,6,systemPlatform.GetSystemCursor(CursorID.Cross));
  RegisterCursor(CursorID.None,99,0);
 end;
end;

procedure InitDefaultRT(wnd:TWindow; const params:TGameSettings);
begin
 if HasParamLocal('-nodrt') then begin
  Log.Msg('Default RT disabled by -noDRT switch');
  exit;
 end;
 if disableDRT then begin
  Log.Msg('Default RT disabled');
  exit;
 end;
 wnd.InitDefaultRenderTarget(params.width,params.height,params.zbuffer,useDepthTexture);
end;

procedure TGame.InitGraph;
var
 baseDPI:integer;
begin
 Log.Msg('InitGraph');
 Signal('Engine\BeforeInitGraph');
 aspectRatio:=params.width/params.height;

 window.Configure(params);
 // Some platforms report client size only after first message pump.
 window.ProcessMessages;
 window.GetSize(window.windowWidth,window.windowHeight);
 if window.windowWidth<=0 then window.windowWidth:=params.width;
 if window.windowHeight<=0 then window.windowHeight:=params.height;
 gfx.Init(window);
 // Choose pixel formats
 gfx.config.ChoosePixelFormats(pfTrueColor,pfTrueColorAlpha,pfRenderTarget,pfRenderTargetAlpha);
 Log.Msg('Selected pixel formats:');
 Log.Msg('      TrueColor: %s',[PixFmt2Str(pfTrueColor)]);
 Log.Msg(' TrueColorAlpha: %s',[PixFmt2Str(pfTrueColorAlpha)]);
 Log.Msg(' as render target:');
 Log.Msg('    Opaque: %s',[PixFmt2Str(pfRenderTarget)]);
 Log.Msg('     Alpha: %s',[PixFmt2Str(pfRenderTargetAlpha)]);

 SetVSync(params.VSync);

 //
 InitDefaultRT(window,params);
 SetupRenderArea;

 screenScale:=1.0;
 if params.mode.displayScaleMode=dsmDontScale then begin
   baseDPI:=96;
   {$IFDEF ANDROID}
    baseDPI:=192;
   {$ENDIF}
   {$IFDEF IOS}
    baseDPI:=192;
   {$ENDIF}
   if window.screenDPI>0.95*baseDPI*1.2 then screenScale:=1.2;
   if window.screenDPI>0.94*baseDPI*1.5 then screenScale:=1.5;
   if window.screenDPI>0.93*baseDPI*2.0 then screenScale:=2.0;
   if window.screenDPI>0.92*baseDPI*2.5 then screenScale:=2.5;
 end;

 InitDefaultResources;

 globalTintColor:=$FF808080;
 window.ProcessMessages;
 allowCriticalPopup:=params.mode.displayMode<>dmSwitchResolution;

 AfterInitGraph;
end;


procedure TGame.AfterInitGraph;
begin
 Signal('Engine\AfterInitGraph');
end;

// --- Robot API command handlers ---
const
 statusNames:array[TSceneStatus] of String8 = ('frozen','background','active');
  ROBOT_PENDING_TOKEN='@PENDING@';

var
  fpsMetricsPending:boolean=false;
  fpsMetricsReqId:String8='';
  fpsMetricsStartFrame:int64=0;
  fpsMetricsTargetFrames:integer=0;

// RobotAPI is polled from the main-loop thread, so `window` threadvar points to mainWindow here.
// For now window control commands intentionally support only the main window.
function ValidateMainWindowParam(const req:TRobotRequest; out error:String8):boolean;
 var wnd:String8;
 begin
  wnd:=req.Param('WINDOW').ToLower;
  if (wnd='') or (wnd='0') or (wnd='main') or (wnd='mainwnd') then begin
   result:=true;
   exit;
  end;
  error:='only main window is supported (WINDOW=0/main)';
  result:=false;
 end;

function RobotCmdWindows(const req:TRobotRequest; out body:String8):boolean;
begin
  if game=nil then begin body:='game not initialized'; exit(false) end;
  body:='WINDOW: 0'#13#10+
    '  windowWidth: '+Conv.ToStr(window.windowWidth)+#13#10+
    '  windowHeight: '+Conv.ToStr(window.windowHeight)+#13#10+
    '  renderWidth: '+Conv.ToStr(window.renderWidth)+#13#10+
    '  renderHeight: '+Conv.ToStr(window.renderHeight)+#13#10+
    '  screenDPI: '+Conv.ToStr(window.screenDPI)+#13#10+
    '  screenScale: '+Conv.ToStr(game.screenScale,2)+#13#10+
    '  displayRect: '+Conv.ToStr(window.displayRect.Left)+','+Conv.ToStr(window.displayRect.Top)+','+
      Conv.ToStr(window.displayRect.Right)+','+Conv.ToStr(window.displayRect.Bottom)+#13#10;
  result:=true;
end;

function RobotCmdWindowMove(const req:TRobotRequest; out body:String8):boolean;
 var
  g:TGame;
  x,y,w,h:integer;
  sx,sy:String8;
  p:TPoint;
 begin
  g:=game as TGame;
  if g=nil then begin body:='game not initialized'; exit(false) end;
  if not ValidateMainWindowParam(req,body) then exit(false);
  sx:=req.Param('X');
  sy:=req.Param('Y');
  if (sx='') or (sy='') then begin
   body:='X and Y parameters required';
   exit(false);
  end;
  x:=Conv.ToInt(sx);
  y:=Conv.ToInt(sy);
  w:=Conv.ToInt(req.Param('W'));
  h:=Conv.ToInt(req.Param('H'));
  if ((w>0) xor (h>0)) then begin
   body:='W and H should be both specified or both omitted';
   exit(false);
  end;
  window.MoveTo(x,y,w,h);
  window.ProcessMessages;
  window.GetSize(window.windowWidth,window.windowHeight);
  g.SetupRenderArea;
  p:=Types.Point(0,0);
  window.ClientToScreen(p);
  body:='x: '+Conv.ToStr(p.x)+#13#10+
    'y: '+Conv.ToStr(p.y)+#13#10+
    'windowWidth: '+Conv.ToStr(window.windowWidth)+#13#10+
    'windowHeight: '+Conv.ToStr(window.windowHeight)+#13#10+
    'renderWidth: '+Conv.ToStr(window.renderWidth)+#13#10+
    'renderHeight: '+Conv.ToStr(window.renderHeight)+#13#10;
  result:=true;
 end;

function RobotCmdWindowResize(const req:TRobotRequest; out body:String8):boolean;
 var
  g:TGame;
  x,y,w,h:integer;
  sx,sy:String8;
  p:TPoint;
 begin
  g:=game as TGame;
  if g=nil then begin body:='game not initialized'; exit(false) end;
  if not ValidateMainWindowParam(req,body) then exit(false);
  w:=Conv.ToInt(req.Param('W'));
  h:=Conv.ToInt(req.Param('H'));
  if (w<=0) or (h<=0) then begin
   body:='W and H parameters should be >0';
   exit(false);
  end;
  sx:=req.Param('X');
  sy:=req.Param('Y');
  if (sx='') and (sy='') then begin
   p:=Types.Point(0,0);
   window.ClientToScreen(p);
   x:=p.x;
   y:=p.y;
  end else begin
   if (sx='') or (sy='') then begin
    body:='X and Y should be both specified or both omitted';
    exit(false);
   end;
   x:=Conv.ToInt(sx);
   y:=Conv.ToInt(sy);
  end;
  window.MoveTo(x,y,w,h);
  window.ProcessMessages;
  window.GetSize(window.windowWidth,window.windowHeight);
  g.SetupRenderArea;
  p:=Types.Point(0,0);
  window.ClientToScreen(p);
  body:='x: '+Conv.ToStr(p.x)+#13#10+
    'y: '+Conv.ToStr(p.y)+#13#10+
    'windowWidth: '+Conv.ToStr(window.windowWidth)+#13#10+
    'windowHeight: '+Conv.ToStr(window.windowHeight)+#13#10+
    'renderWidth: '+Conv.ToStr(window.renderWidth)+#13#10+
    'renderHeight: '+Conv.ToStr(window.renderHeight)+#13#10;
  result:=true;
 end;

function RobotCmdFps(const req:TRobotRequest; out body:String8):boolean;
var
  g:TGame;
  n,i,idx,startFrameNum:integer;
  collectMetrics:boolean;
begin
  g:=game as TGame;
  if g=nil then begin body:='game not initialized'; exit(false) end;
  collectMetrics:=Conv.ToBool(req.Param('METRICS'));
  n:=Conv.ToInt(req.Param('N'));
  if collectMetrics and (n<=0) then n:=50;

  if collectMetrics then begin
    if (not fpsMetricsPending) or (fpsMetricsReqId<>req.id) then begin
      fpsMetricsPending:=true;
      fpsMetricsReqId:=req.id;
      fpsMetricsStartFrame:=window.frameNum;
      fpsMetricsTargetFrames:=n;
      window.timings.phaseMetrics:=true;
      body:=ROBOT_PENDING_TOKEN;
      exit(true);
    end;
    if window.frameNum-fpsMetricsStartFrame<fpsMetricsTargetFrames then begin
      body:=ROBOT_PENDING_TOKEN;
      exit(true);
    end;
    fpsMetricsPending:=false;
    fpsMetricsReqId:='';
    window.timings.phaseMetrics:=false;
    n:=fpsMetricsTargetFrames;
    if n<=0 then n:=50;
  end else
  if req.Param('METRICS')<>'' then
    window.timings.phaseMetrics:=false;

  body:='fps: '+Conv.ToStr(window.FPS,2)+#13#10+
    'smoothFPS: '+Conv.ToStr(window.smoothFPS,2)+#13#10+
    'frameNum: '+Conv.ToStr(window.frameNum)+#13#10+
    'frameTimeMs: '+Conv.ToStr(window.timings.lastFrameTimeUs*0.001,2)+#13#10;
  if collectMetrics then begin
    body:=body+
      'msgMs: '+Conv.ToStr(window.timings.lastMsgUs*0.001,2)+#13#10+
      'onFrameMs: '+Conv.ToStr(window.timings.lastOnFrameUs*0.001,2)+#13#10+
      'renderMs: '+Conv.ToStr(window.timings.lastRenderUs*0.001,2)+#13#10+
      'presentMs: '+Conv.ToStr(window.timings.lastPresentUs*0.001,2)+#13#10+
      'sleepMs: '+Conv.ToStr(window.timings.lastSleepUs*0.001,2)+#13#10;
  end;
  if n>0 then begin
    if n>window.timings.frameTimeRingCount then n:=window.timings.frameTimeRingCount;
    if n>FRAME_TIME_RING_SIZE then n:=FRAME_TIME_RING_SIZE;
    body:=body+'historyCount: '+Conv.ToStr(n)+#13#10;
    if n>0 then begin
      idx:=window.timings.frameTimeRingPos-n;
      if idx<0 then inc(idx,FRAME_TIME_RING_SIZE);
      startFrameNum:=integer(window.frameNum)-n+1;
      if startFrameNum<0 then startFrameNum:=0;
      for i:=0 to n-1 do begin
        if collectMetrics then begin
          body:=body+
            'Frame: '+Conv.ToStr(startFrameNum+i)+#13#10+
            '  MSG: '+Conv.ToStr(window.timings.phaseMsgRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10+
            '  ONFRAME: '+Conv.ToStr(window.timings.phaseOnFrameRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10+
            '  RENDER: '+Conv.ToStr(window.timings.phaseRenderRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10+
            '  PRESENT: '+Conv.ToStr(window.timings.phasePresentRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10+
            '  SLEEP: '+Conv.ToStr(window.timings.phaseSleepRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10+
            '  Total: '+Conv.ToStr(window.timings.frameTimeRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10;
        end else
          body:=body+'FRAME_MS: '+Conv.ToStr(window.timings.frameTimeRing[(idx+i) mod FRAME_TIME_RING_SIZE]*0.001,2)+#13#10;
        if collectMetrics then begin
          body:=body+#13#10;
        end;
      end;
    end;
  end;
  result:=true;
end;

function RobotCmdScenes(const req:TRobotRequest; out body:String8):boolean;
var
  s:TGameScene;
  activeOnly:boolean;
begin
  if game=nil then begin body:='game not initialized'; exit(false) end;
  activeOnly:=req.Param('ACTIVE_ONLY')<>'';
  body:='';
  window.Lock;
  try
    for s in window.scenes do begin
      if activeOnly and (s.status<>ssActive) then continue;
      body:=body+'SCENE: '+s.name+#13#10+
        '  status: '+statusNames[s.status]+#13#10+
        '  zOrder: '+Conv.ToStr(s.zOrder)+#13#10+
        '  frequency: '+Conv.ToStr(s.frequency)+#13#10+
        '  fullscreen: '+Conv.ToStr(s.fullscreen)+#13#10+
        '  class: '+String8(s.ClassName)+#13#10;
    end;
  finally
    window.Unlock;
  end;
  if body='' then begin body:='no scenes available'; exit(false) end;
  result:=true;
end;

function RobotCmdScreenshot(const req:TRobotRequest; out body:String8):boolean;
var
  fname:String8;
  x,y,w,h:integer;
  img:TBitmapImage;
  res:ByteArray;
begin
  if game=nil then begin body:='game not initialized'; exit(false) end;
  fname:=req.Param('FILE');
  if fname='' then fname:='screenshot.png';
  x:=Conv.ToInt(req.Param('X'));
  y:=Conv.ToInt(req.Param('Y'));
  w:=Conv.ToInt(req.Param('W'));
  h:=Conv.ToInt(req.Param('H'));
  if w<=0 then w:=window.renderWidth;
  if h<=0 then h:=window.renderHeight;
  img:=TBitmapImage.Create(w,h,ipfXRGB);
  try
    gfx.CopyFromBackbuffer(x,window.renderHeight-y-h,img);
    img.FlipVertical; // backbuffer is bottom-up in OpenGL
    res:=SavePNG(img);
    Files.WriteBlock(fname,@res[0],length(res),0);
    body:='file: '+fname+#13#10+
      'width: '+Conv.ToStr(w)+#13#10+
      'height: '+Conv.ToStr(h)+#13#10;
    result:=true;
  except
    on e:Exception do begin
      body:=String8(e.Message);
      result:=false;
    end;
  end;
  img.Free;
end;

function RobotCmdPixel(const req:TRobotRequest; out body:String8):boolean;
var
  x,y:integer;
  color:cardinal;
begin
  if game=nil then begin body:='game not initialized'; exit(false) end;
  x:=Conv.ToInt(req.Param('X'));
  y:=Conv.ToInt(req.Param('Y'));
  color:=gfx.GetPixelValue(x,y);
  body:='x: '+Conv.ToStr(x)+#13#10+
    'y: '+Conv.ToStr(y)+#13#10+
    'color: '+Conv.ToHex(color)+#13#10;
  result:=true;
end;

procedure RegisterGameRobotCommands;
begin
  RegisterRobotCommand('windows',@RobotCmdWindows);
  RegisterRobotCommand('window.move',@RobotCmdWindowMove);
  RegisterRobotCommand('window.resize',@RobotCmdWindowResize);
  RegisterRobotCommand('fps',@RobotCmdFps);
  RegisterRobotCommand('scenes',@RobotCmdScenes);
  RegisterRobotCommand('screenshot',@RobotCmdScreenshot);
  RegisterRobotCommand('pixel',@RobotCmdPixel);
end;

procedure TGame.InitMainLoop;
begin
 try
  Log.Msg('Init main loop');
  InitGraph;

  window.timings.Reset;
  window.capture.Reset;

  RegisterGameRobotCommands;
  InitRobotAPI;
  Signal('Engine\BeforeMainLoop');
  Log.Msg('Game is running...');
  running:=true;
  {$IFDEF ANDROID}
  window.active:=true; // window is initially active
  {$ENDIF}
  except
   on e:Exception do begin
    Log.Force('Error in InitMainLoop: %s',[ExceptionMsg(e)]);
    SystemMessage(ExceptionMsg(e));
    running:=false;
    Halt(254);
  end;
 end;
end;

procedure TGame.SuppressKbdEvent;
begin
 suppressCharEvent:=true;
end;

procedure TGame.CreateDebugLogs;
var
 i:integer;
 f:text;
 function SceneInfo(s:TGameScene):string;
  begin
   if s=nil then exit;
   result:=Format('  %-20s Z=%-10d  status=%-2d type=%-2d eff=%s',
     [s.name,s.zorder,ord(s.status),byte(s.fullscreen),Conv.ToStr(s.effect)]);
   if s is TUIScene then
    result:=result+Format(' UI=%s (%s)',[TUIScene(s).UI.name, Conv.ToStr(TUIScene(s).UI)]);
  end;
begin
  with game do begin
   Lock;
   try
     // Frame log
     assign(f,'framelog.log');
     SetTextCodePage(f,CP_UTF8);
     rewrite(f);
     writeln(f,'Previous:');
     write(f,window.prevFrameLog);
     writeln(f,'Current:');
     write(f,window.frameLog);
     close(f);
     // Scenes & UI log
     assign(f,'UIdata.log');
     SetTextCodePage(f,CP_UTF8);
     rewrite(f);
     writeln(f,'Scenes:');
     for i:=0 to high(window.scenes) do writeln(f,i:3,SceneInfo(window.scenes[i]));
     writeln(f,'Topmost scene = ',game.TopmostVisibleScene(false).name);
     writeln(f,'Topmost fullscreen scene = ',game.TopmostVisibleScene(true).name);
     writeln(f);
     writeln(f,DumpUI);
     close(f);

     gfx.resman.Dump('User request');
   finally
    Unlock;
   end;
 end;
end;

procedure EngineEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onEngineEvent(event,tag);
end;

procedure EngineCmdEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onCmdEvent(event,tag);
end;

procedure GameKbdEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onKbdEvent(event,tag);
end;

procedure GameJoystickEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onJoystickEvent(event,tag);
end;

procedure GameGamepadEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onGamepadEvent(event,tag);
end;

// Mirror generic debug/error signals to the log (was Apus.Engine.Console)
procedure DebugSignalEvent(event:TEventStr;tag:TTag);
begin
 Log.Msg('Evt: %s - %d',[event,tag]);
end;

procedure ErrorSignalEvent(event:TEventStr;tag:TTag);
begin
 Log.Error('Evt: %s - %d',[event,tag]);
end;


procedure TGame.PrepareRun;
var
 i:integer;
begin
 game:=self;
 gameEx:=self;
 mainThreadErrorMsg:='';
 SetEventHandler('KBD\',GameKbdEvent,emInstant);
 SetEventHandler('JOYSTICK\',GameJoystickEvent,emInstant);
 SetEventHandler('GAMEPAD\',GameGamepadEvent,emInstant);
 SetEventHandler('DEBUG',DebugSignalEvent,emInstant);
 SetEventHandler('ERROR',ErrorSignalEvent,emInstant);
end;

procedure TGame.Run;
var
 i:integer;
begin
 if running then exit;
 PrepareRun;

 if useMainThread then
  mainThread:=Thread.Start('MainThread',MainThreadLoop)
 else begin
  mainThread:=nil;
  SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);
  SetEventHandler('Engine\',EngineEvent,emInstant);
  Signal('Engine\MainLoopInit');
 end;

 for i:=1 to 400 do
  if not running then CoreTime.Sleep(50) else break;

  if not running then begin
   Log.Force('Main thread timeout');
  {$IFDEF MSWINDOWS}
   if mainThreadErrorMsg<>'' then SystemMessage(mainThreadErrorMsg);
  {$ENDIF}
   raise EFatalError.Create('Can''t run: see log for details.');
 end;
end;

{$IFDEF DARWIN}
procedure TGame.RunCurrentThread;
begin
 if running then exit;
 PrepareRun;
 mainThread:=nil;
 MainThreadLoop;
end;

procedure TGame.AllowMainThreadExit;
begin
 canExitNow:=true;
end;
{$ENDIF}

procedure TGame.StartVideoCap(filename:string);
begin
 window.StartVideoCap(filename);
end;

procedure TGame.FinishVideoCap;
begin
 window.FinishVideoCap;
end;

procedure TGame.Stop;
var
 i:integer;
 h:TThreadIdent;
begin
 Log.Force('GameStop');
 if not running then exit;
 if window<>nil then window.active:=false;

 if mainThread=nil then
  Signal('Engine\MainLoopDone')
 else begin
  mainThread.Terminate; // Для экономии времени
  canExitNow:=true;

  // Прибить главный поток (только в случае вызова из другого потока)
  h:=GetCurrentThreadId;
  if h<>mainThread.ID then begin
   // Ждем 2 секунды пока поток не завершится по-хорошему
   for i:=1 to 40 do
    if running then CoreTime.Sleep(50) else break;
   // Иначе прибиваем силой
   if running then begin
    Signal('Error\MainThreadHangs');
    Log.Force('Killing main thread');
    mainThread.Kill;
   end;
  end;
 end;

 if window<>nil then window.active:=false;
 Log.Force('Can exit now');
end;

procedure TGame.CaptureFrame;
begin
 window.CaptureFrame;
end;

// ENGINE\*
procedure TGame.onEngineEvent(event:String8;tag:NativeInt);
var
  t,fr:int64;
  p:TPoint;
procedure Timing;
 var
  t2:int64;
 begin
  t2:=CoreTime.Ticks;
  fr:=t2 div 1000;
  if timerFrame<>fr then begin
   avgTime2:=0;
   timerFrame:=fr;
  end;
  avgTime2:=avgTime2+(t2-t);
 end;
begin
 event:=Copy(event,8,200);
 if event.Same('ONFRAME') then begin
  try
   FrameLoop;
  except
   on e:Exception do CriticalError(Format('Error in main loop: %s',[ExceptionMsg(e)]));
  end;
  end else
 if event.Same('SETGLOBALTINTCOLOR') then globalTintColor:=tag
  else
 if event.Same('MAINLOOPINIT') then begin
   InitMainLoop;
  end else
 if event.Same('MAINLOOPDONE') then begin
   DoneGraph;
  end else
 if event.Same('SINGLETOUCHSTART') then begin
    t:=CoreTime.Ticks;
   p.x:=tag and $FFFF;
   p.y:=tag shr 16;
   ClientToGame(p);
   window.mousePos:=p;
   window.FlushMouseInput; // emits MOUSE\MOVE if position changed
   Signal('Mouse\BtnDown\Left',1);
   window.NotifyScenesMouseBtn(1,true);
   CoreTime.Sleep(0);
   Timing;
 end else
 if event.Same('SINGLETOUCHMOVE') then begin
   t:=CoreTime.Ticks;
   p.x:=tag and $FFFF;
   p.y:=tag shr 16;
   ClientToGame(p);
   window.mousePos:=p;
   window.FlushMouseInput;
   Timing;
 end else
 if event.Same('SINGLETOUCHRELEASE') then begin
   t:=CoreTime.Ticks;
   Signal('Mouse\BtnUp\Left',1);
   window.NotifyScenesMouseBtn(1,false);
   window.mousePos:=Types.Point(4095,4095);
   window.FlushMouseInput;
   Timing;
 end else
 if event.Same('REDRAW') then begin
  if game.running then
   RenderAndPresentFrame;
  end else
 if event.Same('RESIZE') then begin
  SizeChanged(Bits.GetWord(cardinal(tag),0),Bits.GetWord(cardinal(tag),1));
  end else
 if event.Same('SETACTIVE') then begin
  Activate(tag<>0);
  end else
 if event.Same('DPICHANGED') then begin
  // screenDPI already updated by TWindow.DPIChanged
  screenScale:=1.0;
  if params.mode.displayScaleMode=dsmDontScale then begin
   if window.screenDPI>0.95*96*1.2 then screenScale:=1.2;
   if window.screenDPI>0.94*96*1.5 then screenScale:=1.5;
   if window.screenDPI>0.93*96*2.0 then screenScale:=2.0;
   if window.screenDPI>0.92*96*2.5 then screenScale:=2.5;
  end;
  Signal('ENGINE\DPICHANGED\DONE',tag);
 end;
end;

// Обработка событий, являющихся командами движку
procedure TGame.onCmdEvent(event:String8;tag:NativeInt);
var
 rawEvent:String8;
 arg:String8;
begin
 rawEvent:=Copy(event,12,200);
 if rawEvent.Same('CHANGESETTINGS') then ApplyNewSettings
 else
 if rawEvent.Same('EXIT') then begin
  if mainThread<>nil then
   mainThread.Terminate
  else
   mainLoopExitRequested:=true;
 end
   else
 if EventOfClass(rawEvent,'SWITCHTOSCENE\',arg) then begin
   SwitchToScene(arg);
  end else
 if EventOfClass(rawEvent,'SHOWWINDOW\',arg) then begin
   ShowWindowScene(arg);
  end else
 if EventOfClass(rawEvent,'HIDEWINDOW\',arg) then begin
   HideWindowScene(arg);
  end else
 if rawEvent.Same('SETSWAPINTERVAL') then begin
  SetVSync(tag);
 end else
  // Update mouse position when it is obsolete
 if rawEvent.Same('UPDATEMOUSEPOS') then begin
   window.SamplePointer; // poll OS, set window.mousePos in game coords
   window.FlushMouseInput;
  end
  else
  // Make window flash to draw attention
 if rawEvent.Same('FLASH') then
  window.FlashWindow(tag);
end;

// Handle KBD\* event
procedure TGame.onKbdEvent(event:String8;tag:NativeInt);
begin
 event:=Copy(event,5,200);
 if event.Same('KEYDOWN') then begin
   KeyPressed(tag and $FFFF,tag shr 16,true);
  end else
 if event.Same('KEYUP') then begin
   KeyPressed(tag and $FFFF,tag shr 16,false);
  end else
 if event.Same('UNICHAR') then begin
   CharEntered(tag and $FFFF,tag shr 16);
  end;
end;

// Handle JOYSTICK\* event
procedure TGame.onJoystickEvent(event:String8;tag:NativeInt);
begin
end;

// Handle GAMEPAD\* event
procedure TGame.onGamepadEvent(event:String8;tag:NativeInt);
var
 evt:TEventStr;
 btn:TConButtonType;
 conId:integer;
 btnDown:boolean;
 procedure Navigate(dragMode:boolean;nx,ny:integer);
  var
   i,dx,dy,d,best:integer;
   bestPnt:TPoint;
  begin
    if dragMode then begin
      bestPnt.x:=window.mousePos.x+nx*20;
      bestPnt.y:=window.mousePos.y+ny*20;
      window.ClientToScreen(bestPnt);
      systemPlatform.SetMousePos(bestPnt.x,bestPnt.y);
      exit;
   end;
   Lock;
   try
    best:=100000;
    for i:=0 to high(activeCustomPoints) do
     with activeCustomPoints[i] do begin
      dx:=x-window.mousePos.x; dy:=y-window.mousePos.y;
      d:=dx*nx+dy*ny; // расстояние в направлении вектора (скалярное произведение)
      if d<=1 then continue;
      // расстояние в перпендикулярном направлении больше?
      if d<abs(dx*ny+dy*nx) then
        d:=5000+round(sqrt(dx*dx+dy*dy)) // тогда просто ближайшая точка но со штрафом
      else
        d:=d+abs(dx*ny+dy*nx);
      if d<best then begin
       best:=d; bestPnt:=activeCustomPoints[i];
      end;
     end;
   finally
    Unlock;
   end;
   if best<100000 then begin
    GameToClient(bestPnt);
    window.ClientToScreen(bestPnt);
    systemPlatform.SetMousePos(bestPnt.x,bestPnt.y);
   end;
  end;
begin
 if (gamepadNavigationMode<>gnmDisabled) then begin
  if (EventOfClass(event,'GAMEPAD\BTNDOWN',evt)) then begin
   btn:=TConButtonType(ByteFromTag(tag,0));
   conID:=ByteFromTag(tag,1);
   with controllers[conID] do
    btnDown:=GetButton(btButtonA) or GetButton(btButtonB);
   case btn of
     btButtonDPadUp:Navigate(btnDown,0,-1);
     btButtonDPadDown:Navigate(btnDown,0,1);
     btButtonDPadLeft:Navigate(btnDown,-1,0);
     btButtonDPadRight:Navigate(btnDown,1,0);
     btButtonA,btButtonB:Signal('MOUSE\BTNDOWN',1);
    else
   end;
  end else
  if (EventOfClass(event,'GAMEPAD\BTNUP',evt)) then begin
   btn:=TConButtonType(ByteFromTag(tag,0));
   if btn in [btButtonA,btButtonB] then Signal('MOUSE\BTNUP',1);
  end;
 end;
end;


procedure Delay(time:integer);
var
 t,delta:int64;
begin
 t:=CoreTime.Ticks+time;
 repeat
  HandleSignals;
  if (game<>nil) and (TGame(game).mainThread<>nil) and (GetCurrentThreadId=TGame(game).mainThread.ID) then
   window.ProcessMessages;
  CoreTime.Sleep(Clamp(t-CoreTime.Ticks,0,20));
 until CoreTime.Ticks>=t;
end;


function TGame.OnFrame:boolean;
begin
 result:=window.OnFrame;
end;

procedure TGame.PresentFrame;
begin
 window.PresentRenderedFrame(globalTintColor);
 HandleGamepadNavigation;
end;

procedure TGame.SetupRenderArea;
begin
 window.SetupRenderArea(params,aspectRatio);
end;

procedure TGame.DrawCursor;
var
 n,i,j:integer;
 c:cardinal;
begin
 Lock;
 try
  FLog('RCursor');
  n:=-1; j:=-10000;
  for i:=0 to high(cursors) do
   with cursors[i] as TGameCursor do
    if visible and (priority>j) then begin
     j:=priority; n:=i;
    end;

  if not params.showSystemCursor and (n>=0) then begin
   // check if cursor is visible
    /// TODO: draw custom cursor here
  end;

  if params.showSystemCursor then begin
   c:=wndCursor;
   if n<0 then wndCursor:=0
    else wndCursor:=TGameCursor(cursors[n]).handle;
   if wndCursor<>c then
    systemPlatform.SetCursor(wndCursor);
  end;
 curPrior:=j;
 finally
  Unlock;
 end;
end;

procedure TGame.DrawOverlays;
var
 i:integer;
begin
 FLog('RDebug');
 DrawDebugOverlays(debug);
 DrawNotifications; // product-facing toasts, share the same draw-last overlay slot
 // Navigation points (needs protected field)
 if dfShowNavigationPoints in debug.features then begin
  for i:=0 to high(activeCustomPoints) do
   with activeCustomPoints[i] do
    draw.FillRect(x-10,y-10,x+10,y+10,$70E00000);
 end;
end;


procedure TGame.RenderFrame;
begin
 window.RenderFrame(params,aspectRatio,DrawCursor,DrawOverlays);
end;

procedure TGame.WaitFor(pb:PBoolean; msg:string);
var
 i:integer;
begin
 i:=0;
 if msg='' then msg:=Conv.ToStr(Stack.Caller);
 while not pb^ do begin
  if i mod 10=0 then Log.Msg('WaitFor %s',[msg]);
  ToggleCursor(CursorID.Wait,true);
  CoreTime.Sleep(30);
  ToggleCursor(CursorID.Wait,false);
  inc(i);
 end;
end;

procedure TGame.Minimize;
 begin
  window.Minimize;
 end;

procedure TGame.FireMessage(st: string8;severity:integer);
 var
  kind:TToastKind;
 begin
  case severity of
   msgSuccess:kind:=TToastKind.Success;
   msgWarning:kind:=TToastKind.Warning;
   msgError:kind:=TToastKind.Error;
   else kind:=TToastKind.Info;
  end;
  ShowToast(st,kind); // engine-driven non-modal toast (auto duration)
 end;

procedure TGame.SwitchToAltSettings; // Alt+Enter
 begin
  Log.Msg('Alt+Enter: switch to alt settings');
  Swap(params.width,altWidth);
  Swap(params.height,altHeight);
  Swap(params.mode,params.altMode,sizeof(params.mode));
  SetSettings(params);
 end;

function WaitAndSwitch(ctx:TThreadContext):UIntPtr;
 var
  scene:TGameScene;
 begin
  scene:=TGameScene(ctx.Parameter);
  // TODO: add timeout-aware wait helper when shared WaitFor(var,maxTime) replacement is available.
  if scene<>nil then
   while not scene.loaded do
    CoreTime.Sleep(10);
  if scene<>nil then
   TSceneSwitcher.defaultSwitcher.SwitchToScene(scene.name);
  result:=0;
 end;

procedure TGame.SwitchToScene(name:string);
 var
  scene:TGameScene;
 begin
  scene:=TGameScene.FindByName(name) as TGameScene;
   if scene.loaded then
   TSceneSwitcher.defaultSwitcher.SwitchToScene(name)
  else
   Thread.Start('SwitchToScene',@WaitAndSwitch,pointer(scene));
 end;

procedure TGame.ShowWindowScene(name:string;modal:boolean);
 begin
  TSceneSwitcher.defaultSwitcher.ShowWindowScene(name,modal);
 end;

procedure TGame.HideWindowScene(name:string);
 begin
  TSceneSwitcher.defaultSwitcher.HideWindowScene(name);
 end;


procedure TGame.DebugFeature(feature: TDebugFeature; enable: boolean);
 begin
  if enable then Include(debug.features,feature)
   else Exclude(debug.features,feature);
 end;

procedure TGame.ToggleDebugFeature(feature:TDebugFeature);
 begin
  if feature in debug.features then Exclude(debug.features,feature)
   else Include(debug.features,feature);
 end;

procedure TGame.StopExtraWindows;
var
 i,j:integer;
 list:TWindowArray;
begin
 list:=ListWindows;

 for i:=0 to high(list) do
  if (list[i]<>nil) and (list[i]<>mainWindow) and (list[i].renderThread<>nil) then
   list[i].renderThread.Terminate;

 for i:=0 to high(list) do
  if (list[i]<>nil) and (list[i]<>mainWindow) and (list[i].renderThread<>nil) then begin
   j:=0;
   while list[i].renderThread.IsRunning and (j<4000) do begin
    CoreTime.Sleep(1);
    inc(j);
   end;
   if list[i].renderThread.IsRunning then
    Log.Msg('Warning: extra window thread did not stop in time: %s',[list[i].name]);
  end;
end;

procedure TGame.ClientToGame(var p:TPoint);
begin
 window.ClientToGame(p);
end;

procedure TGame.GameToClient(var p:TPoint);
begin
 window.GameToClient(p);
end;

function TGame.GetCursorForID(cursorID:integer):THandle;
var
 i:integer;
begin
 result:=0;
 Lock;
 try
  for i:=0 to high(cursors) do
   with TGameCursor(cursors[i]) do
   if ID=cursorID then begin
    result:=handle; exit;
   end;
 finally
  Unlock;
 end;
end;

function TGame.GetDepthBufferTex:TTexture;
begin
 result:=window.dRTdepth;
end;

procedure TGame.RegisterCursor(CursorID, priority: integer;
  cursorHandle: THandle);
var
 i,n:integer;
 cursor:TGameCursor;
begin
 crSect.Enter;
 try
 n:=-1;
 for i:=0 to high(cursors) do
  if TGameCursor(cursors[i]).ID=cursorID then begin
    n:=i; break;
  end;
 if n<0 then begin
  n:=length(cursors);
  SetLength(cursors,n+1);
  cursor:=TGameCursor.Create;
  cursors[n]:=cursor;
 end else
  cursor:=TGameCursor(cursors[n]);

 cursor.ID:=CursorID;
 cursor.priority:=priority;
 cursor.handle:=cursorHandle;
 if cursorID<>Apus.Engine.API.CursorID.Default then
  cursor.visible:=false;
 finally
  crSect.Leave;
 end;
end;

procedure TGame.HideAllCursors;
var
 i:integer;
begin
 crSect.Enter;
 try
 for i:=0 to high(cursors) do
  with cursors[i] as TGameCursor do
   visible:=false;
 finally
  crSect.Leave;
 end;
end;

procedure TGame.ToggleCursor(CursorID: integer; state: boolean);
var
 i:integer;
begin
 crSect.Enter;
 try
 for i:=0 to high(cursors) do
  with cursors[i] as TGameCursor do
   if ID=CursorID then visible:=state;
 if not params.showSystemCursor then window.screenChanged:=true;
 finally
  crSect.Leave;
 end;
end;

function TGame.TopmostSceneForKbd: TGameScene;
var
 i:integer;
 maxZ:integer;
 sc:TUIScene;
 modal:TUIElement;
begin
 window.Lock;
 try
  result:=nil;
  maxZ:=-10000000;
  modal:=window.modal.Root; // active modal in this window (blocks kbd in other scenes)
  for i:=low(window.scenes) to high(window.scenes) do
   if (window.scenes[i].IsActive) and
      not window.scenes[i].ignoreKeyboardEvents then begin
    // UI Scene?
    if window.scenes[i] is TUIScene then begin
     sc:=TUIScene(window.scenes[i]);
     if not sc.UI.flags.enabled then continue;
     if (modal<>nil) and not modal.HasParent(sc.UI) then continue;
    end;
    // Topmost?
    if window.scenes[i].zorder>maxZ then begin
     result:=window.scenes[i];
     maxZ:=window.scenes[i].zorder;
    end;
   end;
 finally
  window.Unlock;
 end;
end;

procedure TGame.FrameLoop;
 var
  i:integer;
  t:int64;
  phaseTimer:int64;
  mb:byte;
 begin
  t:=CoreTime.Ticks;
  Thread.Ping;
  // Обновление ввода с клавиатуры (и кнопок мыши)
  window.shiftState:=systemPlatform.GetShiftKeysState;
  window.timings.phaseMetrics:=fpsMetricsPending or
    ((dfShowFPS in debug.features) and Bits.HasAll(window.shiftState,sscShift));
  mb:=systemPlatform.GetMouseButtons;
  if mb<>window.mouseButtons then begin
    window.oldMouseButtons:=window.mouseButtons;
    window.mouseButtons:=mb;
  end;

  for i:=0 to High(window.keyState) do
   window.keyState[i]:=window.keyState[i] and 1+(window.keyState[i] and 1) shl 1;

  StartMeasure(14);
  if window.timings.phaseMetrics then Timer.Start(phaseTimer);
  window.ProcessMessages; // this stalls if window is moved/resized
  try
    HandleSignals;
  except
    on e:exception do Log.Force('Error in FrameLoop 1: %s',[ExceptionMsg(e)]);
  end;
  if window.timings.phaseMetrics then
    window.timings.pendingMsgUs:=round(Timer.Get(phaseTimer)*1000000)
  else
    window.timings.pendingMsgUs:=0;
  if not window.active then
    Delay(5); // limit speed in inactive state
  EndMeasure2(14);

  if useMainThread and CurrentThread.Terminating then exit;
  window.SamplePointer; // poll cursor once per frame (frame-synced mouse input)
  window.FlushMouseInput; // aggregate mouse move, notify scenes once per frame
  RenderAndPresentFrame;

  t:=CoreTime.Ticks-t;
  if t<500 then avgTime:=avgTime*0.9+t*0.1;
 end;

procedure TGame.RenderAndPresentFrame;
 var
  startUs:int64;
  i:integer;
  deltaUs:int64;
  sampleUs:integer;
  presented:boolean;
  phaseTimer:int64;
  onFrameUs,renderUs,presentUs,sleepUs:integer;
 begin
   // Never nest a frame: WM_PAINT renders synchronously to keep the window live during
   // the OS modal move/resize loop, and that loop may pump messages re-entrantly.
   if renderingFrame then exit;
   renderingFrame:=true;
  try
   onFrameUs:=0;
   renderUs:=0;
   presentUs:=0;
   sleepUs:=0;
   presented:=false;
   if window.timings.frameTimerReady then
    deltaUs:=round(Timer.Get(window.timings.frameTimer)*1000000)
   else
    deltaUs:=20000; // initial value
   sampleUs:=integer(Clamp(deltaUs,0,high(integer)));
   if window.timings.presentSampleAccUs<=high(integer)-sampleUs then
    inc(window.timings.presentSampleAccUs,sampleUs)
   else
    window.timings.presentSampleAccUs:=high(integer);
   if window.frameNum>0 then
    startUs:=window.frameStartUs+deltaUs
   else
    startUs:=0;
   window.SetFrameTiming(startUs,deltaUs);
   Timer.Start(window.timings.frameTimer);
   window.timings.frameTimerReady:=true;

   if window.frameDeltaUs>500000 then
    Log.Msg('Warning: main loop stall for %d ms',[window.frameDeltaMs]);

   // Обработка кадра
   if window.timings.phaseMetrics then Timer.Start(phaseTimer);
   StartMeasure(3);
   if OnFrame then window.screenChanged:=true; // это чтобы можно было и в других местах выставлять флаг!
   EndMeasure(3);
   if window.timings.phaseMetrics then onFrameUs:=round(Timer.Get(phaseTimer)*1000000);
  try
   HandleSignals;
  except
   on e:exception do Log.Force('Error in FrameLoop 2: %s',[ExceptionMsg(e)]);
  end;
  if window.IsTerminated then exit;

   if not window.screenChanged then begin
    if minRedrawIntervalMs>0 then begin
     inc(window.timings.idleRedrawAccUs,integer(Clamp(deltaUs,0,high(integer))));
     if window.timings.idleRedrawAccUs>=minRedrawIntervalMs*1000 then
      window.screenChanged:=true;
    end else
     window.timings.idleRedrawAccUs:=0;
   end else
    window.timings.idleRedrawAccUs:=0;

   if window.active or (params.mode.displayMode<>dmSwitchResolution) then begin
    // Если программа активна, то выполним отрисовку кадра
    if window.screenChanged then begin
     if window.timings.phaseMetrics then Timer.Start(phaseTimer);
     try
      window.prevFrameLog:=window.frameLog;
      window.frameLog:='';
      StartMeasure(2);
      RenderFrame;
      EndMeasure2(2);
     except
      on E:Exception do CriticalError(Format('Error in renderframe: %s framelog: %s',[ExceptionMsg(e),window.frameLog]));
     end;
     if window.timings.phaseMetrics then renderUs:=round(Timer.Get(phaseTimer)*1000000);
    end;
   end;

   // Здесь можно что-нибудь сделать
   if window.timings.phaseMetrics then Timer.Start(phaseTimer);
   CoreTime.Sleep(onFrameDelay);
   if window.timings.phaseMetrics then sleepUs:=round(Timer.Get(phaseTimer)*1000000);
   // Теперь нужно вывести кадр на экран
   if (window.active or (params.mode.displayMode<>dmSwitchResolution)) and
      window.screenChanged then begin
    if window.timings.phaseMetrics then Timer.Start(phaseTimer);
    PresentFrame;
    presented:=true;
    if window.timings.phaseMetrics then presentUs:=round(Timer.Get(phaseTimer)*1000000);
    if window.capture.singleFrame or window.capture.videoMode then
     CaptureFrame;
    PollRobotAPI; // after present: pixel/screenshot read valid backbuffer
   end else
    CoreTime.Sleep(5);

  if presented then begin
    window.timings.PushSample(window.timings.presentSampleAccUs,
      window.timings.pendingMsgUs,onFrameUs,renderUs,presentUs,sleepUs);
    window.timings.presentSampleAccUs:=0;
    // FPS / SmoothFPS based on presented frames.
    window.timings.UpdateFps(window.FPS,window.smoothFPS);
   end;

   game.Flog('LEnd');
  finally
   renderingFrame:=false;
  end;
 end;

procedure TGame.MainThreadLoop;
 var
  wnd:TWindow;
 begin
  // Инициализация
  mainThreadErrorMsg:='';
  mainLoopExitRequested:=false;
  try
   Log.Msg('%s Main thread started - %d',[CoreTime.Stamp,GetCurrentThreadID]);
   // TODO: restore detailed system info logging after GetSystemInfo replacement is finalized.
   Log.Msg('System info: TODO');
   SetEventHandler('Engine\',EngineEvent,emInstant);
   SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);

   window:=systemPlatform.CreateWindow(gameEx.params.title);
   mainWindow:=window;
   window.screenDPI:=systemPlatform.GetScreenDPI;
   window.frameNum:=0;
   window.ResetFrameTiming;
   PublishVar(@window.screenDPI,'ScreenDPI',TVarTypeInteger);
   gameEx.InitMainLoop; // вызывает InitGraph

   game.running:=true; // Это как-бы семафор для завершения функции Run
   Log.Msg('MainLoop started');
   // Главный цикл
   repeat
    try
     gameEx.FrameLoop;
    except
     on e:Exception do CriticalError(Format('Error in main loop: %s',[ExceptionMsg(e)]));
    end;
    if (window<>nil) and window.IsTerminated then
     break;
   until CurrentThread.Terminating or gameEx.mainLoopExitRequested;
   Log.Force('Main loop exit');
   gameEx.terminated:=true;
   Signal('Engine\AfterMainLoop');

   // Состояние ожидания команды остановки потока из безопасного места
   while not gameEx.canExitNow do CoreTime.Sleep(20);
   Log.Force('Finalization');

   // Финализация
   gameEx.StopExtraWindows;
   gameEx.DoneGraph;
   wnd:=window;
   if wnd<>nil then begin
    wnd.Close;
    FreeAndNil(window);
    if mainWindow=wnd then mainWindow:=nil;
   end;
  except
   on e:Exception do begin
     mainThreadErrorMsg:=ExceptionMsg(e);
     CriticalError(Format('Global error: %s',[ExceptionMsg(e)]));
    end;
  end;

  Log.Force('Main thread done');
  game.running:=false; // Эта строчка должна быть ПОСЛЕДНЕЙ!
 end;

// --- Extra window render thread ---

function ExtraWindowLoop(ctx:TThreadContext):UIntPtr;
 var
  ewCtx:PExtraWindowContext;
  settings:TGameSettings;
  callerReleasedMainContext:boolean;
  wnd:TWindow;
  registered:boolean;
  startUs:int64;
  deltaUs:int64;
  sampleUs:integer;
  presented:boolean;
 begin
  result:=0;
  ewCtx:=PExtraWindowContext(ctx.Parameter);
  settings:=ewCtx^.settings;
  callerReleasedMainContext:=ewCtx^.callerReleasedMainContext;
  registered:=false;
  wnd:=nil;
  Log.Msg('Extra window thread started: %s',[settings.title]);
  try
   // startup phase: must report success/failure back to AddWindow
   try
    wnd:=systemPlatform.CreateWindow(settings.title);
    window:=wnd; // set threadvar
    wnd.screenDPI:=systemPlatform.GetScreenDPI;
    // Shared context creation + handoff is coordinated inside platform backend.
    wnd.InitGraphShared(mainWindow,callerReleasedMainContext);
    wnd.Configure(settings);
    wnd.GetSize(wnd.windowWidth,wnd.windowHeight);
    if wnd.windowWidth<=0 then wnd.windowWidth:=settings.width;
    if wnd.windowHeight<=0 then wnd.windowHeight:=settings.height;
    wnd.renderWidth:=wnd.windowWidth;
    wnd.renderHeight:=wnd.windowHeight;
    // Explicit per-thread graphics bootstrap for this shared context.
    // Must run before startup "ready" signal, so first frame is deterministic.
    gfx.InitThreadContext(wnd);
    wnd.Show(true);
    wnd.ProcessMessages;
    wnd.active:=true;
    wnd.timings.Reset;
    wnd.capture.Reset;
    // signal caller that window is ready
    ewCtx^.resultWnd:=wnd;
    ewCtx^.startDone:=true;
    registered:=true;
    Log.Msg('Extra window ready: %s',[wnd.name]);
   except
    on e:Exception do begin
     ewCtx^.startFailed:=true;
     ewCtx^.errorMsg:=ExceptionMsg(e);
     ewCtx^.startDone:=true;
     ewCtx:=nil; // startup context is no longer valid after reporting result
      CriticalError(Format('Extra window startup error: %s',[ExceptionMsg(e)]));
     if wnd<>nil then begin
      try
       wnd.DoneGraph;
      except end;
      try
       wnd.Close;
      except end;
     end;
     exit;
    end;
   end;
   ewCtx:=nil; // startup context belongs to AddWindow stack and must not be used below

   // frame loop
   repeat
   Thread.Ping;
    presented:=false;
    if wnd.timings.frameTimerReady then
     deltaUs:=round(Timer.Get(wnd.timings.frameTimer)*1000000)
    else
     deltaUs:=20000;
    sampleUs:=integer(Clamp(deltaUs,0,high(integer)));
    if wnd.timings.presentSampleAccUs<=high(integer)-sampleUs then
     inc(wnd.timings.presentSampleAccUs,sampleUs)
    else
     wnd.timings.presentSampleAccUs:=high(integer);
    if wnd.frameNum>0 then
     startUs:=wnd.frameStartUs+deltaUs
    else
     startUs:=0;
    wnd.SetFrameTiming(startUs,deltaUs);
    Timer.Start(wnd.timings.frameTimer);
    wnd.timings.frameTimerReady:=true;

    wnd.ProcessMessages;
    if wnd.IsTerminated then break;

    if wnd.OnFrame then
     wnd.screenChanged:=true;

    if not wnd.screenChanged then begin
     if minRedrawIntervalMs>0 then begin
      inc(wnd.timings.idleRedrawAccUs,integer(Clamp(deltaUs,0,high(integer))));
      if wnd.timings.idleRedrawAccUs>=minRedrawIntervalMs*1000 then
       wnd.screenChanged:=true;
     end else
      wnd.timings.idleRedrawAccUs:=0;
    end else
     wnd.timings.idleRedrawAccUs:=0;

    // render
    if wnd.active and wnd.screenChanged then begin
     gfx.BeginPaint(nil);
     try
      wnd.Lock;
      try
       gameEx.RenderScenesForWindow(wnd);
      finally
       wnd.Unlock;
      end;
     finally
      gfx.EndPaint;
     end;
     wnd.PresentFrame;
     inc(wnd.frameNum);
     wnd.screenChanged:=false;
     wnd.timings.idleRedrawAccUs:=0;
     presented:=true;
    end else
     CoreTime.Sleep(5);

    if presented then begin
     wnd.timings.PushSample(wnd.timings.presentSampleAccUs,0,0,0,0,0);
     wnd.timings.presentSampleAccUs:=0;
     wnd.timings.UpdateFps(wnd.FPS,wnd.smoothFPS);
    end;
  until CurrentThread.Terminating;

   // cleanup
   Log.Msg('Extra window closing: %s',[wnd.name]);
   wnd.DoneGraph;
   wnd.Close;
  except
   on e:Exception do
    CriticalError(Format('Extra window error: %s',[ExceptionMsg(e)]));
  end;
  if registered and (extraWindowCount>0) then Atomic.Dec(extraWindowCount);
  multiWindowMode:=(extraWindowCount>0);
  Log.Force('Extra window thread done');
 end;

procedure TGame.RenderScenesForWindow(wnd:TWindow);
begin
 wnd.RenderScenes(DrawOverlays);
end;

function TGame.AddWindow(settings:TGameSettings):TWindow;
 var
  ewCtx:TExtraWindowContext;
  th:IThread;
  callerIsMainThread:boolean;
  mainContextReleased:boolean;
 begin
  // Serialize only AddWindow startup path; do not block the whole game state lock.
  // Serialize extra-window startup across all callers/threads.
  mainContextReleased:=false;
  while Atomic.CmpExchange(addWindowBusy,1,0)<>0 do
   CoreTime.Sleep(1);
  try
   // Blocking call: returns only after extra-window thread reports startup success or failure.
   ASSERT(mainWindow<>nil,'Main window must exist before AddWindow');
   callerIsMainThread:=(mainThread<>nil) and (GetCurrentThreadID=mainThread.ID);
   if callerIsMainThread then begin
    mainWindow.ReleaseGraphContext;
    mainContextReleased:=true;
   end;
   ewCtx.settings:=settings;
   ewCtx.callerReleasedMainContext:=callerIsMainThread;
   ewCtx.resultWnd:=nil;
   ewCtx.startDone:=false;
   ewCtx.startFailed:=false;
   ewCtx.errorMsg:='';
   th:=Thread.Start('WndThread',ExtraWindowLoop,@ewCtx);
   // wait until startup result is reported (or thread dies unexpectedly)
   while (not ewCtx.startDone) and th.IsRunning do
    CoreTime.Sleep(1);
   if ewCtx.startFailed then begin
    if ewCtx.errorMsg<>'' then
     raise EError.Create('Failed to create extra window: '+ewCtx.errorMsg)
    else
     raise EError.Create('Failed to create extra window');
   end;
   result:=ewCtx.resultWnd;
   if result=nil then
    raise EError.Create('Failed to create extra window: startup thread terminated before ready');
   result.renderThread:=th;
   Atomic.Inc(extraWindowCount);
   multiWindowMode:=(extraWindowCount>0); // enable texture RW-sync for shared mutable resources
  finally
   try
    if mainContextReleased then
     mainWindow.ActivateGraphContext;
   finally
    Atomic.Exchange(addWindowBusy,0);
   end;
  end;
 end;

procedure TGame.RemoveWindow(wnd:TWindow);
 begin
  if wnd=nil then exit;
  if wnd.renderThread<>nil then begin
   wnd.renderThread.Terminate;
   while wnd.renderThread.IsRunning do
    CoreTime.Sleep(1);
   wnd.renderThread:=nil;
  end;
  FreeAndNil(wnd);
 end;

{ TVarTypeGameClass }

class function TVarTypeGameClass.GetField(variable:pointer;fieldName:string8;
  out varClass:TVarClass):pointer;
 begin

 end;

class function TVarTypeGameClass.ListFields:string8;
 var
  i:integer;
  sa:Strings8;
 begin
  with TGame(game) do begin
    for i:=0 to high(window.scenes) do
     sa.Add(String8('scene-'+window.scenes[i].name));
  end;
  result:=String8.Join(sa,',');
 end;

initialization
  PublishVar(@onFrameDelay,'onFrameDelay',TVarTypeInteger);
end.




