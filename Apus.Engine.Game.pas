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
uses Classes, Apus.Core, Apus.Threads, Apus.Engine.Types, Apus.Engine.Window, Apus.Engine.API;

var
 onFrameDelay:integer=0; // Sleep this time every frame
 disableDRT:boolean=false; // always render directly to the backbuffer - no
 useDepthTexture:boolean=false; // when default RT is used, allocate a depth buffer texture instead of regular depth buffer

type
 { TGame }
 TGame=class(TGameBase)
  constructor Create(systemPlatform:ISystemPlatform;gfxSystem:IGraphicsSystem); // Создать экземпляр
  procedure Run; override; // запустить движок (создание окна, переключение режима и пр.)
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
  procedure FireMessage(st:string8); override;
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

  procedure SetSettings(s:TGameSettings); override; // этот метод служит для изменения режима или его параметров
  function GetSettings:TGameSettings; override; // этот метод служит для изменения режима или его параметров

  procedure DPadCustomPoint(x,y:single); override;

 protected
  useMainThread:boolean; // true - launch "main" thread with main loop,
                         // false - no main thread, catch frame events
  canExitNow:boolean; // флаг того, что теперь можно начать деинициализацию
  params,newParams:TGameSettings;
  aspectRatio:single;  // Initial aspect ratio (width/height)
  altWidth,altHeight:integer; // saved window size for Alt+Enter
  mainThread:IThread;
  mainThreadErrorMsg:string;
  controlThreadId:TThreadID;
  cursors:array of TObject;
  crSect:TLock;
  LastOnFrameTime:int64; // момент последнего вызова обработки кадра
  LastRenderTime:int64; // Момент последней отрисовки кадра

  curPrior:integer; // приоритет текущего отображаемого курсора
  wndCursor:THandle; // current system cursor
  suppressCharEvent:boolean; // suppress next keyboard event (to avoid duplicated handle of both CHAR and KEY events)

  frameLog,prevFrameLog:string;
  avgTime,avgTime2:double;
  timerFrame:cardinal;

  customPoints,activeCustomPoints:array of TPoint; // custom navigation points

  // Debug utilities
  debugOverlay:integer; // индекс отладочного оверлея, включаемого клавишами Alt+Fn (0 - отсутствует)
  magnifierTex:TTexture;
  debugFeatures:set of TDebugFeature;

  dRT:TTexture; // default render target (can be nil)
  dRTdepth:TTexture; // depth buffer texture

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
  // Create default RT (if needed)
  procedure InitDefaultRenderTarget; virtual;
  procedure InitMainLoop; virtual;

  procedure FrameLoop; virtual; // One iteration of the frame loop
  procedure RenderAndPresentFrame; virtual; // May be called from the message handlers
  procedure PresentFrame; virtual;  // Displays back buffer
  procedure DoneGraph; virtual; // Финализация графической части
  // Производит захват кадра и производит с ним необходимые действия
  procedure CaptureFrame; virtual;
  procedure DrawCursor; virtual;
  procedure DrawOverlays; virtual;

  procedure NotifyScenesAboutMouseMove; virtual;
  procedure NotifyScenesAboutMouseBtn(c:byte;pressed:boolean); virtual;

  // находит сцену, которая должна получать сигналы о клавиатурном вводе
  function TopmostSceneForKbd:TGameScene; virtual;

  // Events
  // Called when ENGINE\* event is fired
  procedure onEngineEvent(event:string;tag:NativeInt); virtual;
  // Called when ENGINE\CMD\* event is fired
  procedure onCmdEvent(event:string;tag:NativeInt); virtual;
  // Called when KBD\* event is fired
  procedure onKbdEvent(event:string;tag:NativeInt); virtual;
  // Called when MOUSE\* event is fired
  procedure onMouseEvent(event:string;tag:NativeInt); virtual;
  // Called when JOYSTICK\* event is fired
  procedure onJoystickEvent(event:string;tag:NativeInt); virtual;
  // Called when GAMEPAD\* event is fired
  procedure onGamepadEvent(event:string;tag:NativeInt); virtual;

  // Event processors
  procedure MouseMovedTo(newX,newY:integer); virtual;
  procedure CharEntered(charCode,scanCode:integer); virtual;
  procedure KeyPressed(keyCode,scanCode:integer;pressed:boolean=true); virtual;
  procedure MouseButtonPressed(btn:integer;pressed:boolean=true); virtual;
  procedure MouseWheelMoved(value:integer); virtual;
  procedure SizeChanged(newWidth,newHeight:integer); virtual;
  procedure Activate(activeState:boolean); virtual;

  // Utils
  procedure CreateDebugLogs; virtual;
  // Draw magnified part of the screen under mouse
  procedure DrawMagnifier; virtual;
  // Internal hotkeys such as PrintScreen, Alt+F1 etc
  procedure HandleInternalHotkeys(keyCode:integer;pressed:boolean); virtual;

  procedure HandleGamepadNavigation;
  procedure MainThreadLoop;
 end;

 // Для использования из главного потока
 procedure Delay(time:integer);

implementation
 uses Types, SysUtils, TypInfo, Apus.Engine.CmdProc, Apus.Images, Apus.FastGFX, Apus.Engine.ImageTools,
      Apus.Engine.Resources,
      {$IFDEF VIDEOCAPTURE}Apus.Engine.VideoCapture,{$ENDIF}
      Apus.EventMan, Apus.Engine.Scene, Apus.Engine.UI, Apus.Engine.UITypes, Apus.Engine.UIScene,
      Apus.Engine.Console, Apus.Publics, Apus.GfxFormats, Apus.Clipboard, Apus.Engine.TextDraw,
      Apus.Engine.Controller,
  Apus.Engine.RobotAPI,
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
 i:integer;
 scene:TUIScene;
 procedure Traverse(e:TUIElement);
  var
   child:TUIElement;
   pnt:TPoint;
  begin
   if e=nil then exit;
   with e do begin
    if not (enabled and visible) then exit;
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
   if debugOverlay=n then debugOverlay:=0
    else debugOverlay:=n;
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
     if params.VSync=0 then Include(debugFeatures,dfShowFPS)
      else Exclude(debugFeatures,dfShowFPS);
   end;

   // F12 or PrintScreen - screenshot (JPEG), Alt+F12 - (loseless)
   if (TKey(keyCode and $FF)=TKey.PrintScreen) or (TKey(keyCode and $FF)=TKey.F12) then
     RequestScreenshot(not Bits.HasAll(window.shiftState,sscAlt));

   if Bits.HasAll(window.shiftState,sscAlt) then
    if (debugHotKey=dhAltFx) or (debugHotkey=dhCtrlAltFx) and Bits.HasAll(window.shiftState,sscCtrl) then begin
     if TKey(keyCode and $FF)=TKey.F1 then begin
       if debugOverlay=0 then begin
        debugOverlay:=1;
        DebugFeature(dfShowFPS,true);
       end else begin
        debugOverlay:=0;
        debugFeatures:=[];
       end;
     end else
     if TKey(keyCode and $FF)=TKey.F3 then
       ToggleDebugFeature(dfShowMagnifier);
    end;

   // [Alt]+[1] .. [Alt]+[9] - switch debug overlay when enabled
   if (debugOverlay>0) and (TKey(keyCode and $FF) in [TKey.D1..TKey.D9]) and Bits.HasAll(window.shiftState,sscAlt) then
    debugOverlay:=1+keyCode-byte(TKey.D1);

   // Shift+Alt+F1 - Create debug logs
   if (TKey(keyCode and $FF)=TKey.F1) and
      (window.shiftState and sscAlt>0) and
      (window.shiftState and sscShift>0) then CreateDebugLogs;
  end;
end;

procedure TGame.RequestScreenshot(saveAsJpeg:boolean=true);
begin
 Lock;
 try
  if saveAsJPEG then window.capture.target:=2
   else window.capture.target:=3;
  window.capture.singleFrame:=true;
 finally
  Unlock;
 end;
end;

procedure TGame.RequestFrameCapture(obj:TObject=nil);
begin
 Lock;
 try
  window.capture.singleFrame:=true;
  window.capture.target:=0;
  window.capture.data:=obj;
 finally
  Unlock;
 end;
end;

procedure TGame.ApplyNewSettings;
var
 resChanged,pfChanged:boolean;
begin
 resChanged:=(newParams.width<>params.width) or (newParams.height<>params.height);
 pfChanged:=newParams.colorDepth<>params.colorDepth;
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
 PutMsg('Failed to set VSync: no method available');
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
 result:=(window.mouseX>=r.Left) and (window.mouseY>=r.Top) and
         (window.mouseX<r.Right) and (window.mouseY<r.Bottom);
end;

function TGame.MouseInRect(r:TRect2):boolean;
begin
 result:=(window.mouseX>=r.x1) and (window.mouseY>=r.y1) and
         (window.mouseX<r.x2) and (window.mouseY<r.y2);
end;

function TGame.MouseInRect(x,y,width,height:single):boolean;
begin
 result:=(window.mouseX>=x) and (window.mouseY>=y) and
         (window.mouseX<x+width) and (window.mouseY<y+height);
end;

function TGame.MouseIsNear(x,y,radius:single):boolean;
begin
 result:=Sqr(window.mouseX-x)+Sqr(window.mouseY-y)<=sqr(radius);
end;

procedure TGame.MouseMovedTo(newX,newY:integer);
begin
  window.oldMouseX:=window.mouseX;
  window.oldMouseY:=window.mouseY;
  window.mouseX:=newX;
  window.mouseY:=newY;
  window.mouseMovedTime:=CoreTime.Ticks;
  Signal('MOUSE\MOVE',window.mouseX and $FFFF+(window.mouseY and $FFFF) shl 16);
  TGame(game).NotifyScenesAboutMouseMove;
  // Если курсор рисуется вручную, то нужно обновить экран
  if not params.showSystemCursor then window.screenChanged:=true;
end;

procedure TGame.CharEntered(charCode,scanCode:integer);
var
 i:integer;
 scene:TGameScene;
 key:cardinal;
 wst:WideString;
 ast:AnsiString;
begin
  if suppressCharEvent then begin
   suppressCharEvent:=false; exit;
  end;
  if window.shiftstate=sscCtrl then exit; // Ignore Ctrl+*

  // Send to active scene
  scene:=TopmostSceneForKbd;
  if scene<>nil then begin
   // TODO: lossy Unicode→ANSI conversion — non-ASCII chars may produce empty ast,
   // causing ast[1] access to read garbage. Rework to use charcode directly.
   wst:=WideChar(charcode);
   ast:=AnsiString(wst);
   if length(ast)=0 then exit;
   key:=byte(ast[1])+(scancode and $FF) shl 8+(charcode and $FFFF) shl 16;
   scene.WriteKey(key);
  end;
end;

procedure TGame.KeyPressed(keyCode,scanCode:integer;pressed:boolean=true);
var
 scene:TGameScene;
 code,uCode:cardinal;
begin
  ASSERT(scancode in [0..255]);
  code:=keyCode and $FFFF+window.shiftstate shl 16+scancode shl 24;
  uCode:=keyCode and $FFFF+scanCode shl 24;
  scene:=TopmostSceneForKbd;
  if pressed and (scene<>nil) then
   scene.WriteKey(scancode shl 8+keyCode);
  HandleInternalHotkeys(keyCode,pressed);

  if pressed then begin
    window.keyState[scanCode]:=window.keyState[scanCode] or 1;
    //Log.Msg('KeyDown %d, KS[%d]=%2x ',[lParam,scanCode,window.keystate[scanCode]]);
    if scene<>nil then Signal('SCENE\'+scene.name+'\KeyDown',uCode);
  end else begin
    window.keyState[scanCode]:=window.keyState[scanCode] and $FE;
    //Log.Msg('KeyUp %d, KS[$d]=%2x ',[lParam,scanCode,window.keystate[scanCode]]);
    if scene<>nil then Signal('SCENE\'+scene.name+'\KeyUp',uCode);
  end;
end;

procedure TGame.MouseButtonPressed(btn:integer;pressed:boolean=true);
begin
 NotifyScenesAboutMouseBtn(btn,pressed);
end;

procedure TGame.MouseWheelMoved(value:integer);
begin
  window.NotifyScenesMouseWheel(value);
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
 result:=(window.oldMouseX>=r.Left) and (window.oldmouseY>=r.Top) and
         (window.oldmouseX<r.Right) and (window.oldmouseY<r.Bottom);
end;

function TGame.MouseWasInRect(r:TRect2):boolean;
begin
 result:=(window.oldmouseX>=r.x1) and (window.oldmouseY>=r.y1) and
         (window.oldmouseX<r.x2) and (window.oldmouseY<r.y2);
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
 var
  width,height,left:integer;
  u,v,du,dv:single;
  cx,cy,zoom,ox,oy:integer;
  text:string;
  color:cardinal;
  rawImage:TRawImage;
  screenScale:single;
  mSize:integer;
 begin
  if magnifierTex=nil then begin
   magnifierTex:=AllocImage(128,128,ipfARGB,aiTexture,'Magnifier');
  end;
  cx:=window.mouseX-64;
  cy:=window.mouseY+64;
  EditImage(magnifierTex);
  Apus.FastGFX.FillRect(0,0,127,127,$FF000000);
  rawImage:=magnifierTex.GetRawImage;
  gfx.CopyFromBackbuffer(cx,window.renderHeight-cy,rawImage);
  rawImage.Free;
  color:=Apus.FastGFX.GetPixel(64,63);
  magnifierTex.Unlock;
  magnifierTex.SetFilter(TTexFilter.fltNearest);
  gfx.shader.UseTexture(magnifierTex);
  screenScale:=window.screenDPI/96;
  mSize:=round(512*screenScale);
  mSize:=mSize and $FFFFFFF0;
  width:=Min(mSize,round(window.renderWidth*0.4));
  height:=Min(mSize,window.renderHeight);
  if window.mouseX<window.renderWidth div 2 then left:=window.renderWidth-width
   else left:=0;
  zoom:=round(4*screenScale);
  if (window.shiftstate and sscShift)>0 then zoom:=zoom*2;
  du:=width/(256*zoom); dv:=-height/(256*zoom);
  u:=0.5; v:=0.5;
  draw.TexturedRect(left,0,left+width{-1},height{-1},magnifierTex,u-du,v-dv,u+du,v-dv,u+du,v+dv,$FF808080);
  draw.Rect(left,0,left+width,height,clWhite);
  // Color picker
  if zoom>6*screenScale then begin
   ox:=left+(width div 2);
   oy:=(height div 2);
   draw.Rect(ox,oy,ox+zoom,oy+zoom,$80FFFFFF);
   draw.Rect(ox-1,oy-1,ox+zoom+1,oy+zoom+1,$80000000);
   // Pixel color value (hex)
   draw.FillRect(ox-50*screenScale,height-30*screenScale,ox+50*screenScale,height-2*screenScale,$80000000);
   text:=Format('%2x %2x %2x',[(color shr 16) and $FF,(color shr 8) and $FF,color and $FF]);
   txt.WriteW(defaultFont,ox,height-17*screenScale,$FFFFFFFF,Str32(text),taCenter);
   // Pixel coordinates
   text:=Format('x: %d y: %d',[window.mousex,window.mouseY]);
   txt.WriteW(smallFont,ox,height-5*screenScale,$FFFFFFFF,Str32(text),taCenter);
  end;
 end;

procedure TGame.FLog(st: string);
 begin
  FrameLog:=FrameLog+st+#13#10;
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
 Log.Msg('      TrueColor: '+PixFmt2Str(pfTrueColor));
 Log.Msg(' TrueColorAlpha: '+PixFmt2Str(pfTrueColorAlpha));
 Log.Msg(' as render target:');
 Log.Msg('    Opaque: '+PixFmt2Str(pfRenderTarget));
 Log.Msg('     Alpha: '+PixFmt2Str(pfRenderTargetAlpha));

 SetVSync(params.VSync);

 //
 InitDefaultRenderTarget;
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
 consoleSettings.popupCriticalMessages:=params.mode.displayMode<>dmSwitchResolution;

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
  i:integer;
  s:TGameScene;
  activeOnly:boolean;
begin
  if game=nil then begin body:='game not initialized'; exit(false) end;
  activeOnly:=req.Param('ACTIVE_ONLY')<>'';
  body:='';
  window.Lock;
  try
    for i:=0 to high(window.scenes) do begin
      s:=window.scenes[i];
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

  LastOnFrameTime:=CoreTime.Ticks;
  LastRenderTime:=CoreTime.Ticks;
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
   Log.Force('Error in InitMainLoop: '+ExceptionMsg(e));
   SystemMessage(ExceptionMsg(e));
   running:=false;
   Halt(254);
  end;
 end;
end;

procedure TGame.InitDefaultRenderTarget;
var
 fl:boolean;
 flags:cardinal;
begin
 try
  Log.Msg('Default RT');
  fl:=HasParamLocal('-nodrt');
  if fl then Log.Msg('Modern rendering model disabled by -noDRT switsh');
  if disableDRT then begin
   fl:=true;
   Log.Msg('Default RT disabled');
  end;
  if not fl and
     gfx.config.ShouldUseTextureAsDefaultRT and
     (gfx.config.QueryMaxRTSize>=params.width) then begin
   Log.Msg('Switching to the modern rendering model');
   flags:=aiRenderTarget;
   if (params.zbuffer>0) and not useDepthTexture then
    flags:=flags+aiDepthBuffer;

   dRT:=AllocImage(params.width,params.height,pfRenderTarget,flags,'DefaultRT');
   if useDepthTexture then begin
    dRTdepth:=AllocImage(params.width,params.height,ipfDepth32f,aiDepthBuffer+aiRenderTarget,'DefaultDepth');
    gfx.resman.AttachDepthBuffer(dRT,dRTdepth);
   end;
  end;
 except
  on e:exception do begin
   Log.Force('Error in GLG:IO '+ExceptionMsg(e));
   SystemMessage('Game engine failure (GLG:IO): '+ExceptionMsg(e));
   Halt;
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
     write(f,prevFrameLog);
     writeln(f,'Current:');
     write(f,FrameLog);
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

procedure GameMouseEvent(event:TEventStr;tag:TTag);
begin
 if game=nil then exit;
 TGame(game).onMouseEvent(event,tag);
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


procedure TGame.Run;
var
 i:integer;
begin
 if running then exit;
 game:=self;
 gameEx:=self;
 mainThreadErrorMsg:='';

 if useMainThread then begin
  mainThread:=Thread.Start('MainThread',MainThreadLoop);
 end else begin
  mainThread:=nil;
  SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);
  SetEventHandler('Engine\',EngineEvent,emInstant);
  Signal('Engine\MainLoopInit');
 end;
 SetEventHandler('KBD\',GameKbdEvent,emInstant);
 SetEventHandler('MOUSE\',GameMouseEvent,emInstant);
 SetEventHandler('JOYSTICK\',GameJoystickEvent,emInstant);
 SetEventHandler('GAMEPAD\',GameGamepadEvent,emInstant);

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

procedure TGame.StartVideoCap(filename: string);
begin
 {$IFDEF VIDEOCAPTURE}
 if window.capture.videoMode then exit;
 window.capture.videoMode:=true;
 if pos('\',filename)=0 then filename:=window.capture.videoPath+filename;
 StartVideoCapture(game,filename);
 {$ENDIF}
end;

procedure TGame.FinishVideoCap;
begin
 {$IFDEF VIDEOCAPTURE}
 if window.capture.videoMode then FinishVideoCapture;
 window.capture.videoMode:=false;
 {$ENDIF}
end;

procedure TGame.Stop;
var
 i:integer;
 h:TThreadID;
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
var
 n:integer;
 st:string;
 res:ByteArray;
 ext:string;
 img:TBitmapImage;
 r:TRect;
 buf:PByte;
 saveAsJPG:boolean;
begin
 window.capture.singleFrame:=false;

 r:=window.displayRect;
 img:=TBitmapImage.Create(r.Width,r.Height,ipfXRGB);
 gfx.CopyFromBackbuffer(0,0,img);
 img.tag:=UIntPtr(buf); // save pointer
 inc(PByte(img.data),img.width*4*(img.height-1)); // move pointer to the last line
 img.pitch:=-img.width*4; // invert pitch
 (*
 {$IFDEF VIDEOCAPTURE}
 if window.capture.videoMode then begin
  // Передача данных потоку видеосжатия
  StoreFrame(img);
 end;
 {$ENDIF} *)
 case window.capture.target of
  0:if window.capture.data<>nil then begin
   Signal('Engine\FrameCaptured',UIntPtr(img));
  end;
  2,3:try
   {$IFDEF OPENGL}
   {$IFDEF MSWINDOWS}
   // overcome windows problem with OpenGL+PrintScreen in fullscreen mode
   PutImageToClipboard(img);
   {$ENDIF}
   {$ENDIF}
   n:=1;
   if not DirectoryExists('Screenshots') then
    CreateDir('Screenshots');
   saveAsJPG:=window.capture.target=2;
   if saveAsJpg then ext:='.jpg' else ext:='.png';
   st:='Screenshots'+PathSeparator+FormatDateTime('yymmdd_hhnnss',Now)+ext;
   if saveAsJpg then
    SaveJPEG(img,st,95)
   else begin
    res:=SavePNG(img);
    Files.WriteBlock(st,@res[0],length(res),0);
   end;
   window.capture.capturedName:=st;
   window.capture.capturedTime:=CoreTime.Ticks;
  except
   on e:Exception do Log.Force('Error saving screenshot: '+ExceptionMsg(e));
  end;
 end;
 (*
 if not window.capture.videoMode then
  ReleaseFrameData(screenshotDataRaw); *)
end;

procedure TGame.NotifyScenesAboutMouseMove;
begin
 window.NotifyScenesMouseMove(window.mouseX,window.mouseY);
end;

procedure TGame.NotifyScenesAboutMouseBtn(c:byte;pressed:boolean);
begin
 window.NotifyScenesMouseBtn(c,pressed);
end;

// ENGINE\*
procedure TGame.onEngineEvent(event:string;tag:NativeInt);
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
 if SameText(event,'ONFRAME') then begin
  try
   FrameLoop;
  except
   on e:Exception do CritMsg('Error in main loop: '+ExceptionMsg(e));
  end;
 end else
 if SameText(event,'SETGLOBALTINTCOLOR') then globalTintColor:=tag
 else
 if SameText(event,'MAINLOOPINIT') then begin
  InitMainLoop;
 end else
 if SameText(event,'MAINLOOPDONE') then begin
  DoneGraph;
 end else
 if event='SINGLETOUCHSTART' then begin
   t:=CoreTime.Ticks;
   window.OldMouseX:=window.mouseX;
   window.OldMouseY:=window.mouseY;
   p.x:=tag and $FFFF;
   p.y:=tag shr 16;
   ClientToGame(p);
   window.mouseX:=p.x;
   window.mouseY:=p.y;
   window.mouseMovedTime:=CoreTime.Ticks;
   Signal('Mouse\Move',(window.mouseX and $FFFF)+window.mouseY shl 16);
   NotifyScenesAboutMouseMove;
   Signal('Mouse\BtnDown\Left',1);
   NotifyScenesAboutMouseBtn(1,true);
   CoreTime.Sleep(0);
   Timing;
 end else
 if event='SINGLETOUCHMOVE' then begin
   t:=CoreTime.Ticks;
   window.OldMouseX:=window.mouseX;
   window.OldMouseY:=window.mouseY;
   p.x:=tag and $FFFF;
   p.y:=tag shr 16;
   ClientToGame(p);
   window.mouseX:=p.x;
   window.mouseY:=p.y;
   window.mouseMovedTime:=CoreTime.Ticks;
   Signal('Mouse\Move',(window.mouseX and $FFFF)+window.mouseY shl 16);
   NotifyScenesAboutMouseMove;
   Timing;
 end else
 if event='SINGLETOUCHRELEASE' then begin
   t:=CoreTime.Ticks;
   Signal('Mouse\BtnUp\Left',1);
   NotifyScenesAboutMouseBtn(1,false);
   window.OldMouseX:=window.mouseX;
   window.OldMouseY:=window.mouseY;
   window.mouseX:=4095; window.mouseY:=4095;
   window.mouseMovedTime:=CoreTime.Ticks;
   Signal('Mouse\Move',Bits.PackW(window.mouseX,window.mouseY));
   NotifyScenesAboutMouseMove;
   Timing;
 end else
 if SameText(event,'REDRAW') then begin
  if game.running then
   RenderAndPresentFrame;
 end else
 if SameText(event,'RESIZE') then begin
  SizeChanged(Bits.GetWord(cardinal(tag),0),Bits.GetWord(cardinal(tag),1));
 end else
 if SameText(event,'SETACTIVE') then begin
  Activate(tag<>0);
 end else
 if SameText(event,'DPICHANGED') then begin
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
procedure TGame.onCmdEvent(event:string;tag:NativeInt);
var
 pnt:TPoint;
begin
 event:=Copy(event,12,200);
 if SameText(event,'CHANGESETTINGS') then ApplyNewSettings
 else
 if SameText(event,'EXIT') then begin
  if mainThread<>nil then mainThread.Terminate;
 end
 else
 if event.StartsWith('SWITCHTOSCENE\',true) then begin
  SwitchToScene(Copy(event,15,100));
 end else
 if event.StartsWith('SHOWWINDOW\',true) then begin
  ShowWindowScene(Copy(event,15,100));
 end else
 if event.StartsWith('HIDEWINDOW\',true) then begin
  HideWindowScene(Copy(event,15,100));
 end else
 if SameText(event,'SETSWAPINTERVAL') then begin
  SetVSync(tag);
 end else
 // Update mouse position when it is obsolete
 if SameText(event,'UPDATEMOUSEPOS') then begin
   pnt:=systemPlatform.GetMousePos;
   ClientToGame(pnt);
   tag:=pnt.X+pnt.Y shl 16;
   Signal('MOUSE\MOVE',tag);
 end
 else
 // Make window flash to draw attention
 if SameText(event,'FLASH') then
  window.FlashWindow(tag);
end;

// Handle KBD\* event
procedure TGame.onKbdEvent(event:string;tag:NativeInt);
begin
 event:=Copy(event,5,200);
 if SameText(event,'KEYDOWN') then begin
   KeyPressed(tag and $FFFF,tag shr 16,true);
 end else
 if SameText(event,'KEYUP') then begin
   KeyPressed(tag and $FFFF,tag shr 16,false);
 end else
 if SameText(event,'UNICHAR') then begin
   CharEntered(tag and $FFFF,tag shr 16);
 end;
end;

// Handle MOUSE\* event
procedure TGame.onMouseEvent(event:string;tag:NativeInt);
var
 pnt:TPoint;
begin
 event:=Copy(event,7,200);
 /// TODO: if not params.showSystemCursor then SetCursor(0);
 // position changed in screen space
 if SameText(event,'CLIENTMOVE') then begin
   pnt.x:=SmallInt(tag);
   pnt.y:=SmallInt(tag shr 16);
   ClientToGame(pnt);
   MouseMovedTo(pnt.x,pnt.y); // process motion in game space
   if params.showSystemCursor then
    systemPlatform.SetCursor(wndCursor);
 end else
 if SameText(event,'GLOBALMOVE') then begin
   pnt.x:=SmallInt(tag);
   pnt.y:=SmallInt(tag shr 16);
   window.ScreenToClient(pnt);
   ClientToGame(pnt);
   MouseMovedTo(pnt.x,pnt.y); // process motion in game space
 end else
 if SameText(event,'BTNDOWN') then begin
   MouseButtonPressed(tag,true);
 end else
 if SameText(event,'BTNUP') then begin
   MouseButtonPressed(tag,false);
 end else
 if SameText(event,'SCROLL') then begin
   MouseWheelMoved(tag);
 end
end;

// Handle JOYSTICK\* event
procedure TGame.onJoystickEvent(event:string;tag:NativeInt);
begin
end;

// Handle GAMEPAD\* event
procedure TGame.onGamepadEvent(event:string;tag:NativeInt);
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
      bestPnt.x:=window.mouseX+nx*20;
      bestPnt.y:=window.mouseY+ny*20;
      window.ClientToScreen(bestPnt);
      systemPlatform.SetMousePos(bestPnt.x,bestPnt.y);
      exit;
   end;
   Lock;
   try
    best:=100000;
    for i:=0 to high(activeCustomPoints) do
     with activeCustomPoints[i] do begin
      dx:=x-window.mouseX; dy:=y-window.mouseY;
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
var
 i,j,v,n:integer;
 deltaTime:int64;
 p:pointer;
begin
 result:=false;
 DestroyQueuedElements; // delete queued UI elements

 window.Lock;
 try
 // TODO: scenes are sorted here AND again by insertion sort in RenderFrame — remove one
 if high(window.scenes)>1 then begin
  for n:=1 to high(window.scenes) do
   for i:=0 to n-1 do
    if window.scenes[i+1].zorder>window.scenes[i].zorder then begin
     Swap(window.scenes[i],window.scenes[i+1],sizeof(window.scenes[i]));
    end;
 end;
 finally
  window.Unlock;
 end;
  window.Lock;
 try
  // Перечисление корневых эл-тов UI в соответствии со сценами
  // (связь сцен и UI)
  for i:=0 to high(window.scenes) do begin
   if (window.scenes[i] is TUIScene) then
    with window.scenes[i] as TUIScene do
     if (UI<>nil) then begin
      ui.order:=window.scenes[i].zorder;
     end;
  end;
 finally
   window.Unlock;
 end;
 deltaTime:=CoreTime.Ticks-LastOnFrameTime;
 LastOnFrameTime:=CoreTime.Ticks;
 result:=window.ProcessScenes(deltaTime);
end;

procedure TGame.PresentFrame;
 begin
   if dRT<>nil then begin
    // Была отрисовка в текстуру - теперь нужно отрисовать её в RenderRect
    gfx.target.Viewport(0,0,window.windowWidth,window.windowHeight,window.windowWidth,window.windowHeight);
    gfx.BeginPaint(nil);
    try
    // Если есть неиспользуемые полосы - очистить их (но не каждый кадр, чтобы не тормозило)
    if not ((window.displayRect.Left=0) and (window.displayRect.Top=0) and
            (window.displayRect.Right=window.windowWidth) and (window.displayRect.Bottom=window.windowHeight)) and
       ((window.frameNum mod 5=0) or (window.frameNum<3)) then gfx.target.Clear($FF000000);

    with window.displayRect do begin
     draw.TexturedRect(Left,Top,right-1,bottom-1,DRT,0,0,1,0,1,1,globalTintColor);
    end;
    finally
     gfx.EndPaint;
    end;
   end;

  FLog('Present');
  StartMeasure(1);
  gfx.PresentFrame;
  EndMeasure(1);
  inc(window.frameNum);
  HandleGamepadNavigation;
 end;

procedure TGame.SetupRenderArea;
var
 i:integer;
 w,h:integer;
 scale:single;
 oldDisplayRect:TRect;
 oldRW,oldRH:integer;
begin
 if (window.windowWidth<=0) or (window.windowHeight<=0) then begin
  window.GetSize(window.windowWidth,window.windowHeight);
  if window.windowWidth<=0 then window.windowWidth:=params.width;
  if window.windowHeight<=0 then window.windowHeight:=params.height;
 end;

 oldRW:=window.renderWidth;
 oldRH:=window.renderHeight;
 oldDisplayRect:=window.displayRect;
 w:=0; h:=0;
 case params.mode.displayFitMode of
  dfmCenter:begin
   w:=params.width;
   h:=params.height;
  end;
  dfmFullSize:begin
   w:=window.windowWidth;
   h:=window.windowHeight;
   if params.mode.displayScaleMode=dsmDontScale then begin
    params.width:=w;
    params.height:=h;
   end;
  end;
  dfmKeepAspectRatio:begin
   w:=window.windowWidth;
   h:=window.windowHeight;
   if w>round(h*aspectRatio*1.01) then w:=round(h*aspectRatio);
   if h>round(w/aspectRatio*1.01) then h:=round(w/aspectRatio);
   if params.mode.displayScaleMode in [dsmDontScale] then begin
    params.width:=w;
    params.height:=h;
   end;
  end;
 end;
 window.displayRect.Left:=0;
 window.displayRect.Top:=0;
 window.displayRect.Right:=w;
 window.displayRect.Bottom:=h;
 OffsetRect(window.displayRect,(window.windowWidth-w) div 2,(window.windowHeight-h) div 2);

 window.renderWidth:=params.width;
 window.renderHeight:=params.height;

 // Nothing changed?
 if (window.displayRect=oldDisplayRect) and
    (window.renderWidth=oldRW) and (window.renderHeight=oldRH) then exit;

 Log.Msg(Format('Set render area: (%d x %d) (%d,%d) -> (%d,%d)',
   [window.renderWidth,window.renderHeight,window.displayRect.Left,window.displayRect.Top,window.displayRect.Right,window.displayRect.Bottom]));
 Signal('ENGINE\BEFORERESIZE');
 window.NotifyScenesResize;
 Signal('ENGINE\RESIZED');

 if (gfx<>nil) and (gfx.target<>nil) then begin
  gfx.target.Resized(window.windowWidth,window.windowHeight);
  w:=window.displayRect.Width;
  h:=window.displayRect.Height;
  if dRT=nil then begin
   // Rendering directly to the framebuffer
   gfx.target.Viewport(window.displayRect.Left,window.windowHeight-window.displayRect.Bottom,
     w,h,params.width,params.height);
  end else begin
   // Rendering to a framebuffer texture
   with params.mode do
    if (displayFitMode in [dfmFullSize,dfmKeepAspectRatio]) and
       (displayScaleMode in [dsmDontScale,dsmScale]) and
       ((dRT.width<>w) or (dRT.height<>h)) then begin
     Log.Msg('Resizing framebuffer');
     gfx.resman.ResizeImage(dRT,w,h);
     if dRTdepth<>nil then
       gfx.resman.ResizeImage(dRTdepth,w,h);
    end;
   gfx.target.Viewport(0,0,dRT.width,drt.height,params.width,params.height);
  end;
 end;
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
 i,x,y,w,h:integer;
 feature:TDebugFeature;

 procedure DrawHelp;
  const
   lines:array[1..12] of String8=(
    'Hotkeys:',
    '[Alt+F1] - show/hide debug overlays:',
    '  [Alt+1] this help page',
    '  [Alt+2] glyphs cache',
    '  [Alt+3] scenes',
    '',
    '[Shift+Alt+F1] - dump debug logs',
    '[Alt+F3] - toggle magnifier',
    '[Win+~] - show console',
    '[Alt+F11] - toggle VSync',
    '[F12] - take a screenshot (JPEG)',
    '[Alt+F12] - take a screenshot (PNG)');
  var
   i,y:integer;
  begin
   draw.FillRect(0,0,320*screenScale,(length(lines)+0.4)*18*screenScale,$80000000);
   txt.BeginBlock;
   y:=0;
   for i:=1 to high(lines) do begin
    inc(y,round(18*screenScale));
    txt.Write(defaultFont,5,y,$FFFFFFFF,lines[i],taLeft,toDontTranslate);
   end;
   txt.EndBlock;
  end;
 procedure ListScenes;
  var
   i,n,y:integer;
   c:cardinal;
   sList:array of TGameScene;
 begin
  Lock;
   try
    n:=length(window.scenes);
    SetLength(sList,n);
    for i:=0 to high(window.scenes) do sList[i]:=window.scenes[i];
   finally
    window.Unlock;
   end;
   y:=0;
   draw.FillRect(0,0,screenScale*360,(n+0.4)*screenScale*16,$80000000);
   txt.BeginBlock(toDontTranslate);
   for i:=0 to high(sList) do begin
    inc(y,round(16*screenScale));
    c:=$FFA0A0A0;
    if sList[i].IsActive then begin
     c:=$FFFFFFC0;
     txt.WriteW(smallFont,50*screenScale,y,c,Str32(IntToStr(sList[i].zOrder)),taRight);
    end else
    if sList[i].status=TSceneStatus.ssBackground then
     c:=$FFC0D0E0;
    txt.WriteW(smallFont,60*screenScale,y,c,Str32(sList[i].name));
    txt.WriteW(smallFont,200*screenScale,y,c,Str32(sList[i].ClassName));
    if sList[i].effect<>nil then
     txt.WriteW(smallFont,360*screenScale,y,c,Str32(sList[i].effect.ClassName));
   end;
   txt.EndBlock;
  end;
 procedure ListUI;
  begin

  end;
 begin
  Lock;
  try
  FLog('RDebug');
  case debugOverlay of
   1:DrawHelp;
   2:txt.WriteW(MAGIC_TEXTCACHE,1,1,$FFFFFFFF,Str32(''));
   3:ListScenes;
   4:ListUI;
  end;

  for feature in debugFeatures do
   case feature of
    dfShowFPS:begin
     w:=SRound(48*screenScale);
     h:=SRound(36*screenScale);
     x:=window.renderWidth-w; y:=1;
     draw.FillRect(x,y,x+w-2,y+h,$80000000);
     txt.WriteW(defaultFont,x+w-5,y+h*0.4,$FFFFFFFF,Str32(FloatToStrF(window.FPS,ffFixed,5,1)),taRight);
     txt.WriteW(defaultFont,x+w-5,y+h*0.9,$FFFFFFFF,Str32(FloatToStrF(window.smoothFPS,ffFixed,5,1)),taRight);
    end;

    dfShowMagnifier:DrawMagnifier;

    dfShowNavigationPoints:begin
      for i:=0 to high(activeCustomPoints) do
       with activeCustomPoints[i] do
        draw.FillRect(x-10,y-10,x+10,y+10,$70E00000);
    end;
   end;

  // Capture screenshot?
  if (window.capture.capturedTime>0) and (CoreTime.Ticks<window.capture.capturedTime+3000) and (gfx<>nil) then begin
    x:=params.width div 2;
    y:=params.height div 2;
    draw.FillRect(x-200*screenScale,y-40*screenScale,x+200*screenScale,y+40*screenScale,$60000000);
    draw.Rect(x-200*screenScale,y-40*screenScale,x+200*screenScale,y+40*screenScale,$A0FFFFFF);
    txt.Write(largerFont,x,y-16*screenScale,$FFFFFFFF,'Screen captured to:',taCenter);
    txt.Write(defaultFont,x,y+8*screenScale,$FFFFFFFF,window.capture.capturedName,taCenter);
  end;

 finally
  Unlock;
 end;
end;


procedure TGame.RenderFrame;
var
 i,j,n,x,y:integer;
 sc:array[1..50] of TGameScene;
 effect:TSceneEffect;
 DeltaTime:integer;
 fl:boolean;
 z:single;
 s:integer;
// c:cardinal;
 font:cardinal;
 {$IFDEF DELPHI}
 memState:TMemoryManagerState; // real-time memory manager state
 {$ENDIF}
begin
 if window.IsTerminated then exit;
 DeltaTime:=CoreTime.Ticks-LastRenderTime;
 LastRenderTime:=CoreTime.Ticks;
 FLog('RF1');

 // в полноэкранном режиме вывод по центру
 window.Lock;
 try
  txt.ClearLink;
  try
   // Очистим экран если нет ни одной background-сцены или они не покрывают всю область вывода
   fl:=true;
   for i:=low(window.scenes) to high(window.scenes) do
    if window.scenes[i].fullscreen and (window.scenes[i].IsActive)
     then fl:=false;
   FLog('Clear '+booltostr(fl));
   if fl then begin
    if params.zbuffer>0 then z:=1 else z:=-1;
    if params.stencil then s:=0 else s:=-1;
    gfx.target.Clear($FF000000,z,s);
   end;
  except
   on e:exception do CritMsg('RFrame1 '+ExceptionMsg(e));
  end;
  FLog('Eff');
  try
   // Обработка эффектов на ВСЕХ сценах
   for i:=low(window.scenes) to high(window.scenes) do
    if window.scenes[i].effect<>nil then begin
     FLog('Eff on '+window.scenes[i].ClassName+' is '+window.scenes[i].effect.ClassName+' : '+
      inttostr(window.scenes[i].effect.timer)+','+booltostr(window.scenes[i].effect.done));
     effect:=window.scenes[i].effect;
     FLog('Eff ret');
     inc(effect.timer,DeltaTime);
     if effect.done then begin // Эффект завершился
      Signal('ENGINE\EffectDone',UIntPtr(window.scenes[i])); // effect completed
      effect.Free;
      window.scenes[i].effect:=nil;
     end;
    end;
  except
   on e:exception do CritMsg('RFrame2 '+ExceptionMsg(e));
  end;

 // Sort active scenes by Z order
  FLog('Sorting');
  n:=0;
  try
   for i:=low(window.scenes) to high(window.scenes) do
    if window.scenes[i].IsActive then begin
     // Сортировка вставкой. Найдем положение для вставки и вставим туда
     ASSERT(n<high(sc),'Too many active scenes');
     if n=0 then begin
      sc[1]:=window.scenes[i]; inc(n); continue;
     end;
     fl:=true;
     for j:=n downto 1 do
      if sc[j].zorder>window.scenes[i].zorder then sc[j+1]:=sc[j]
       else begin sc[j+1]:=window.scenes[i]; fl:=false; break; end;
     if fl then sc[1]:=window.scenes[i];
     inc(n);
    end;
  except
   on e:exception do CritMsg('RFrame3 '+ExceptionMsg(e));
  end;
  if n>0 then window.topmostScene:=sc[n]
   else window.topmostScene:=nil;
 finally
  window.Unlock; // активные сцены вынесены в отдельный массив - их нельзя удалять в процессе отрисовки
 end;

 gfx.BeginPaint(dRT);
 SetupRenderArea;
 // Draw all active scenes
 for i:=1 to n do try
  StartMeasure(integer(i+4));
  // Draw shadow
  if sc[i].shadowColor<>0 then
   draw.FillRect(0,0,window.renderWidth,window.renderHeight,sc[i].shadowColor);

  if not sc[i].gfxInitialized then try
   sc[i].InitGfx;
   sc[i].gfxInitialized:=true;
  except
   on e:Exception do CritMsg('Scene '+sc[i].name+' InitGfx error: '+ExceptionMsg(e));
  end;

  if window.IsTerminated then exit;
  if sc[i].effect<>nil then begin
   FLog('Drawing eff on '+sc[i].name);
   sc[i].effect.DrawScene;
   FLog('Drawing ret');
  end else begin
   FLog('Drawing '+sc[i].ClassName);
   sc[i].Render;
   FLog('Drawing ret');
  end;
  EndMeasure2(i+4);
 except
  on e:exception do begin
   if sc[i] is TUIScene then CritMsg('SceneRender '+(sc[i] as TUIScene).name+' error '+ExceptionMsg(e)+' FLog: '+frameLog)
    else CritMsg('SceneRender '+sc[i].ClassName+' error '+ExceptionMsg(e));
   halt;
  end;
 end;

 DrawCursor;
 // Additional output
 DrawOverlays;

  //window.textLink:=curTextLink;
  //window.textLinkRect:=curTextLinkRect;

 {$IFDEF ANDROID}
 //Log.Force(framelog);
 {$ENDIF}

 gfx.EndPaint;
 FLog('RDone');
end;

procedure TGame.WaitFor(pb:PBoolean; msg:string);
var
 i:integer;
begin
 i:=0;
 if msg='' then msg:=Conv.ToStr(Stack.Caller);
 while not pb^ do begin
  if i mod 10=0 then Log.Msg('WaitFor '+msg);
  ToggleCursor(CursorID.Wait,true);
  CoreTime.Sleep(30);
  ToggleCursor(CursorID.Wait,false);
 end;
end;

procedure TGame.Minimize;
 begin
  window.Minimize;
 end;

procedure TGame.FireMessage(st: string8);
 begin
  // TODO: implement or remove this stub
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
   Thread.Start('SwitchToScene:'+scene.name,@WaitAndSwitch,pointer(scene));
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
  if enable then Include(debugFeatures,feature)
   else Exclude(debugFeatures,feature);
 end;

procedure TGame.ToggleDebugFeature(feature:TDebugFeature);
 begin
  if feature in debugFeatures then Exclude(debugFeatures,feature)
   else Include(debugFeatures,feature);
 end;

procedure TGame.ClientToGame(var p:TPoint);
 begin
  p.X:=round((p.X-window.displayRect.Left)*window.renderWidth/(window.displayRect.Right-window.displayRect.Left));
  p.Y:=round((p.Y-window.displayRect.top)*window.renderHeight/(window.displayRect.Bottom-window.displayRect.Top));
 end;

procedure TGame.GameToClient(var p:TPoint);
 begin
  p.X:=round(window.displayRect.Left+p.X*(window.displayRect.Right-window.displayRect.Left)/window.renderWidth);
  p.Y:=round(window.displayRect.top+p.Y*(window.displayRect.Bottom-window.displayRect.Top)/window.renderHeight);
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
 result:=dRTdepth;
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
begin
 window.Lock;
 try
  result:=nil;
  maxZ:=-10000000;
  for i:=low(window.scenes) to high(window.scenes) do
   if (window.scenes[i].IsActive) and
      not window.scenes[i].ignoreKeyboardEvents then begin
    // UI Scene?
    if window.scenes[i] is TUIScene then begin
     sc:=TUIScene(window.scenes[i]);
     if not sc.UI.enabled then continue;
     if (modalElement<>nil) and not modalElement.HasParent(sc.UI) then continue;
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
    on e:exception do Log.Force('Error in FrameLoop 1: '+ExceptionMsg(e));
  end;
  if window.timings.phaseMetrics then
    window.timings.pendingMsgUs:=round(Timer.Get(phaseTimer)*1000000)
  else
    window.timings.pendingMsgUs:=0;
  if not window.active then
    Delay(5); // limit speed in inactive state
  EndMeasure2(14);

  if useMainThread and CurrentThread.Terminating then exit;
  RenderAndPresentFrame;

  t:=CoreTime.Ticks-t;
  if t<500 then avgTime:=avgTime*0.9+t*0.1;
 end;

procedure TGame.RenderAndPresentFrame;
 var
  ticks:int64;
  i:integer;
  deltaUs:int64;
  phaseTimer:int64;
  onFrameUs,renderUs,presentUs,sleepUs:integer;
 begin
   onFrameUs:=0;
   renderUs:=0;
   presentUs:=0;
   sleepUs:=0;
   ticks:=CoreTime.Ticks;
   if window.frameStartTime>0 then window.frameTimeDelta:=ticks-window.frameStartTime
    else window.frameTimeDelta:=20; // initial value
   window.frameStartTime:=ticks;
   deltaUs:=window.frameTimeDelta*1000;
   if window.timings.frameTimerReady then
    deltaUs:=round(Timer.Get(window.timings.frameTimer)*1000000);
   Timer.Start(window.timings.frameTimer);
   window.timings.frameTimerReady:=true;

   if window.frameTimeDelta>500 then
    Log.Msg('Warning: main loop stall for '+inttostr(window.frameTimeDelta)+' ms');

   // Обработка кадра
   if window.timings.phaseMetrics then Timer.Start(phaseTimer);
   StartMeasure(3);
   if OnFrame then window.screenChanged:=true; // это чтобы можно было и в других местах выставлять флаг!
   EndMeasure(3);
   if window.timings.phaseMetrics then onFrameUs:=round(Timer.Get(phaseTimer)*1000000);
   try
    HandleSignals;
   except
    on e:exception do Log.Force('Error in FrameLoop 2: '+ExceptionMsg(e));
   end;
   if window.IsTerminated then exit;

   if window.active or (params.mode.displayMode<>dmSwitchResolution) then begin
    // Если программа активна, то выполним отрисовку кадра
    if window.screenChanged then begin
     if window.timings.phaseMetrics then Timer.Start(phaseTimer);
     try
      PrevFrameLog:=frameLog;
      frameLog:='';
      StartMeasure(2);
      RenderFrame;
      EndMeasure2(2);
     except
      on E:Exception do CritMsg('Error in renderframe: '+ExceptionMsg(e)+' framelog: '+framelog);
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
    if window.timings.phaseMetrics then presentUs:=round(Timer.Get(phaseTimer)*1000000);
    if window.capture.singleFrame or window.capture.videoMode then
     CaptureFrame;
    PollRobotAPI; // after present: pixel/screenshot read valid backbuffer
   end else
    CoreTime.Sleep(5);

   window.timings.PushSample(integer(Clamp(deltaUs,0,high(integer))),
     window.timings.pendingMsgUs,onFrameUs,renderUs,presentUs,sleepUs);
   // FPS / SmoothFPS based on trimmed mean of recent frame times.
   window.timings.UpdateFps(window.FPS,window.smoothFPS);

   game.Flog('LEnd');
 end;

procedure TGame.MainThreadLoop;
 var
  wnd:TWindow;
 begin
  // Инициализация
  mainThreadErrorMsg:='';
  try
   Log.Msg(CoreTime.Stamp+' Main thread started - '+inttostr(cardinal(GetCurrentThreadID)));
   // TODO: restore detailed system info logging after GetSystemInfo replacement is finalized.
   Log.Msg('System info: TODO');
   SetEventHandler('Engine\',EngineEvent,emInstant);
   SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);

   window:=systemPlatform.CreateWindow(gameEx.params.title);
   mainWindow:=window;
   window.screenDPI:=systemPlatform.GetScreenDPI;
   window.frameNum:=0;
   window.frameStartTime:=0;
   window.frameTimeDelta:=0;
   PublishVar(@window.screenDPI,'ScreenDPI',TVarTypeInteger);
   gameEx.InitMainLoop; // вызывает InitGraph

   game.running:=true; // Это как-бы семафор для завершения функции Run
   Log.Msg('MainLoop started');
   // Главный цикл
   repeat
    try
     gameEx.FrameLoop;
    except
     on e:Exception do CritMsg('Error in main loop: '+ExceptionMsg(e));
    end;
    if (window<>nil) and window.IsTerminated then
     break;
   until CurrentThread.Terminating;
   Log.Force('Main loop exit');
   gameEx.terminated:=true;
   Signal('Engine\AfterMainLoop');

   // Состояние ожидания команды остановки потока из безопасного места
   while not gameEx.canExitNow do CoreTime.Sleep(20);
   Log.Force('Finalization');

   // Финализация
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
    CritMsg('Global error: '+ExceptionMsg(e));
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
  t:int64;
  deltaUs:int64;
 begin
  result:=0;
  ewCtx:=PExtraWindowContext(ctx.Parameter);
  settings:=ewCtx^.settings;
  callerReleasedMainContext:=ewCtx^.callerReleasedMainContext;
  wnd:=nil;
  Log.Msg('Extra window thread started: '+settings.title);
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
    Log.Msg('Extra window ready: '+wnd.name);
   except
    on e:Exception do begin
     ewCtx^.startFailed:=true;
     ewCtx^.errorMsg:=ExceptionMsg(e);
     ewCtx^.startDone:=true;
     ewCtx:=nil; // startup context is no longer valid after reporting result
     CritMsg('Extra window startup error: '+ExceptionMsg(e));
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
    t:=CoreTime.Ticks;
    if wnd.frameStartTime>0 then wnd.frameTimeDelta:=t-wnd.frameStartTime
     else wnd.frameTimeDelta:=20;
    wnd.frameStartTime:=t;
    deltaUs:=wnd.frameTimeDelta*1000;
    if wnd.timings.frameTimerReady then
     deltaUs:=round(Timer.Get(wnd.timings.frameTimer)*1000000);
    Timer.Start(wnd.timings.frameTimer);
    wnd.timings.frameTimerReady:=true;

    wnd.ProcessMessages;
    if wnd.IsTerminated then break;

    // process scenes
    wnd.Lock;
    try
     wnd.ProcessScenes(integer(wnd.frameTimeDelta));
    finally
     wnd.Unlock;
    end;

    // render
    if wnd.active then begin
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
    end else
     CoreTime.Sleep(5);

    wnd.timings.PushSample(integer(Clamp(deltaUs,0,high(integer))),0,0,0,0,0);
    wnd.timings.UpdateFps(wnd.FPS,wnd.smoothFPS);
   until CurrentThread.Terminating;

   // cleanup
   Log.Msg('Extra window closing: '+wnd.name);
   wnd.DoneGraph;
   wnd.Close;
  except
   on e:Exception do
    CritMsg('Extra window error: '+ExceptionMsg(e));
  end;
  Log.Force('Extra window thread done');
 end;

procedure TGame.RenderScenesForWindow(wnd:TWindow);
 var
  i,j,n:integer;
  sc:array[1..50] of TGameScene;
  fl:boolean;
 begin
  // sort active scenes by Z order (under lock)
  n:=0;
  for i:=low(wnd.scenes) to high(wnd.scenes) do
   if wnd.scenes[i].IsActive then begin
    ASSERT(n<high(sc),'Too many active scenes');
    if n=0 then begin
     sc[1]:=wnd.scenes[i]; inc(n); continue;
    end;
    fl:=true;
    for j:=n downto 1 do
     if sc[j].zorder>wnd.scenes[i].zorder then sc[j+1]:=sc[j]
      else begin sc[j+1]:=wnd.scenes[i]; fl:=false; break; end;
    if fl then sc[1]:=wnd.scenes[i];
    inc(n);
   end;
  if n>0 then wnd.topmostScene:=sc[n]
   else wnd.topmostScene:=nil;

  // render scenes
  for i:=1 to n do try
   if not sc[i].gfxInitialized then begin
    sc[i].InitGfx;
    sc[i].gfxInitialized:=true;
   end;
   if sc[i].effect<>nil then
    sc[i].effect.DrawScene
   else
    sc[i].Render;
  except
   on e:Exception do
    CritMsg('Extra window scene render error: '+ExceptionMsg(e));
  end;
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
  callerIsMainThread:=false;
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
   th:=Thread.Start('WndThread_'+settings.title,ExtraWindowLoop,@ewCtx);
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
  Atomic.Dec(extraWindowCount);
  multiWindowMode:=(extraWindowCount>0);
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



