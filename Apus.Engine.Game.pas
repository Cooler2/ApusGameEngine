﻿// Main runtime unit of the engine
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
 uses Classes, Apus.CrossPlatform, Apus.Common, Apus.Engine.Types, Types, Apus.Engine.API;

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
  procedure AddScene(scene:TGameScene); override;    // Добавить сцену в список сцен
  procedure RemoveScene(scene:TGameScene); override;  // Убрать сцену из списка сцен
  function TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene; override; // Find the topmost active scene
  function GetScene(name:string):TGameScene; override;
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

  function RunAsync(threadFunc:TAsyncProc;param:UIntPtr=0;ttl:single=0;name:string=''):THandle; override;
  function GetThreadResult(h:THandle):integer; override;

  procedure FLog(st:string); override;
  function GetStatus(n:integer):string; override;
  procedure FireMessage(st:string8); override;
  procedure DebugFeature(feature:TDebugFeature;enable:boolean); override;
  procedure ToggleDebugFeature(feature:TDebugFeature);

  procedure EnterCritSect; override;
  procedure LeaveCritSect; override;

  // Устанавливает флаги о необходимости сделать скриншот (JPEG or PNG)
  procedure RequestScreenshot(saveAsJpeg:boolean=true); override;
  procedure RequestFrameCapture(obj:TObject=nil); override;
  procedure StartVideoCap(filename:string); override;
  procedure FinishVideoCap; override;

  // Utility functions
  function MouseInRect(r:TRect):boolean; overload; override;
  function MouseInRect(r:TRect2s):boolean; overload; override;
  function MouseInRect(x,y,width,height:single):boolean; overload; override;
  function MouseIsNear(x,y,radius:single):boolean; overload; override;

  function MouseWasInRect(r:TRect):boolean; overload; override;
  function MouseWasInRect(r:TRect2s):boolean; overload; override;

  procedure WaitFor(pb:PBoolean;msg:string=''); override;

  // Keyboard events utility functions
  procedure SuppressKbdEvent; override;

  function GetDepthBufferTex:TTexture; override;

  procedure Minimize; override;
  procedure MoveWindowTo(x, y, width, height: integer); override;
  procedure SetWindowCaption(text: string); override;

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
  mainThread:TThread;
  controlThreadId:TThreadID;
  cursors:array of TObject;
  crSect:TMyCriticalSection;
  scenes:array of TGameScene;

  LastOnFrameTime:int64; // момент последнего вызова обработки кадра
  LastRenderTime:int64; // Момент последней отрисовки кадра
  capturedName:string;
  capturedTime:int64;

  // Screen capture
  captureSingleFrame:boolean; // request frame capture
  // что сделать с захваченным кадром
  // 0 - keep in frameCaptureData, 1 - save as BMP, 2 - save as JPEG, 3 - save as TGA
  frameCaptureTarget:integer;
  frameCaptureData:TObject;
  videoCaptureMode:boolean; // режим видеозахвата
  videoCapturePath:string; // путь для сохранения файлов видеозахвата (по умолчанию - тек. каталог)

  // FPS calc
  fpsAccumTime:integer;
  fpsAccumFrames:integer;

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
 end;

 // Для использования из главного потока
 procedure Delay(time:integer);

implementation
 uses SysUtils, TypInfo, Apus.Engine.CmdProc, Apus.Images, Apus.FastGFX, Apus.Engine.ImageTools
     {$IFDEF VIDEOCAPTURE},Apus.Engine.VideoCapture{$ENDIF},
     Apus.EventMan, Apus.Engine.Scene, Apus.Engine.UI, Apus.Engine.UITypes, Apus.Engine.UIScene,
     Apus.Engine.Console, Apus.Publics, Apus.GfxFormats, Apus.Clipboard, Apus.Engine.TextDraw,
     Apus.Engine.Controller;

type
 TMainThread=class(TThread)
  errorMsg:string;
  procedure Execute; override;
 end;

 TCustomThread=class(TThread)
  id:cardinal;
  TimeToKill:int64;
  running:boolean;
  func:TAsyncProc;
  FinishTime:int64;
  param:UIntPtr;
  name:string;
  procedure Execute; override;
 end;

 TGameCursor=class
  ID:integer;
  priority:integer;
  handle:THandle;
  visible:boolean;
 end;

 TVarTypeGameClass=class(TVarTypeStruct)
  class function GetField(variable:pointer;fieldName:string;out varClass:TVarClass):pointer; override;
  class function ListFields:string; override;
 end;

var
 lastThreadID:NativeInt;
 threads:array[1..16] of TCustomThread;
 RA_sect:TMyCriticalSection;
 gameEx:TGame;

{$IFDEF FREETYPE}
 // Default vector font is Open Sans
 {$I defaultFont.inc}
{$ELSE}
 // Default raster fonts (exact sizes are 6.0, 7.0 and 9.0)
 {$I defaultFont8.inc}
 {$I defaultFont10.inc}
 {$I defaultFont12.inc}
{$ENDIF}

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
 EnterCritSect;
 try
  activeCustomPoints:=customPoints;
  SetLength(customPoints,0);
  if gamepadNavigationMode=gnmAuto then begin
   // Add clickable UI objects
   if topmostScene is TUIScene then scene:=TUIScene(topmostScene)
    else exit;
   Traverse(scene.UI);
  end;
 finally
  LeaveCritSect;
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
  if (keyCode=VK_RETURN) and (shiftstate and sscAlt>0) then
     if (params.mode.displayMode<>params.altMode.displayMode) and
        (params.altMode.displayMode<>dmNone) then
       SwitchToAltSettings;

  // Alt+F11
  if (keyCode=VK_F11) and HasFlag(shiftState,sscAlt) then begin
    SetVSync(params.VSync xor 1); // toggle vsync
    if params.VSync=0 then Include(debugFeatures,dfShowFPS)
     else Exclude(debugFeatures,dfShowFPS);
  end;

  // F12 or PrintScreen - screenshot (JPEG), Alt+F12 - (loseless)
  if (keyCode=VK_SNAPSHOT) or (keyCode=VK_F12) then
    RequestScreenshot(not HasFlag(shiftState,sscAlt));

  if HasFlag(shiftState,sscAlt) then
   if (debugHotKey=dhAltFx) or (debugHotkey=dhCtrlAltFx) and HasFlag(shiftState,sscCtrl) then begin
    if keyCode=VK_F1 then begin
      if debugOverlay=0 then begin
       debugOverlay:=1;
       DebugFeature(dfShowFPS,true);
      end else begin
       debugOverlay:=0;
       debugFeatures:=[];
      end;
    end else
    if keyCode=VK_F3 then
      ToggleDebugFeature(dfShowMagnifier);
   end;

  // [Alt]+[1] .. [Alt]+[9] - switch debug overlay when enabled
  if (debugOverlay>0) and (keyCode in [ord('1')..ord('9')]) and HasFlag(shiftState,sscAlt) then
   debugOverlay:=1+keyCode-ord('1');

  // Shift+Alt+F1 - Create debug logs
  if (keyCode=VK_F1) and
     (shiftState and sscAlt>0) and
     (shiftState and sscShift>0) then CreateDebugLogs;
 end;
end;

procedure TGame.RequestScreenshot(saveAsJpeg:boolean=true);
begin
 EnterCritSect;
 try
  if saveAsJPEG then frameCaptureTarget:=2
   else frameCaptureTarget:=3;
  captureSingleFrame:=true;
 finally
  LeaveCritSect;
 end;
end;

procedure TGame.RequestFrameCapture(obj:TObject=nil);
begin
 EnterCritSect;
 try
  captureSingleFrame:=true;
  frameCaptureTarget:=0;
  frameCaptureData:=obj;
 finally
  LeaveCritSect;
 end;
end;

procedure TGame.ApplyNewSettings;
var
 resChanged,pfChanged:boolean;
 i:integer;
begin
 resChanged:=(newParams.width<>params.width) or (newParams.height<>params.height);
 pfChanged:=newParams.colorDepth<>params.colorDepth;
 params:=newParams;
 if (params.mode.displayMode=dmFullScreen) and (altWidth=0) or (altHeight=0) then begin
  // save size for windowed mode
  altWidth:=params.width;
  altHeight:=params.height;
 end;

 if running then begin // смена параметров во время работы
  with params.mode do
   LogMessage('Change mode to: %s,%s,%s %d x %d ',
    [displayMode.ToString, displayFitMode.ToString, displayScaleMode.ToString,
     params.width, params.height]);
  systemPlatform.SetupWindow(params);
  if gfx.target<>nil then gfx.target.Backbuffer;
  SetupRenderArea;
  for i:=low(scenes) to high(scenes) do
   scenes[i].ModeChanged;
 end;
end;

procedure TGame.SetVSync(divider: integer);
begin
 if (mainThread<>nil) and (mainThread.ThreadID<>GetCurrentThreadID) then begin
  Signal('ENGINE\Cmd\SetSwapInterval',divider);
  exit;
 end;
 params.VSync:=divider;
 if gfx.config.SetVSyncDivider(divider) then exit;
 if systemPlatform.SetSwapInterval(divider) then exit;
 PutMsg('Failed to set VSync: no method available');
end;

procedure TGame.SetSettings(s: TGameSettings);
begin
 if not systemPlatform.canChangeSettings then exit;
 newParams:=s;
 if useMainThread and (mainThread=nil) then begin
  ApplyNewSettings; exit;
 end;
 if (mainThread=nil) or (GetCurrentThreadID<>mainThread.ThreadID) then
  Signal('Engine\CMD\ChangeSettings')
 else
  ApplyNewSettings;
end;

function TGame.MouseInRect(r:TRect):boolean;
begin
 result:=(mouseX>=r.Left) and (mouseY>=r.Top) and
         (mouseX<r.Right) and (mouseY<r.Bottom);
end;

function TGame.MouseInRect(r:TRect2s):boolean;
begin
 result:=(mouseX>=r.x1) and (mouseY>=r.y1) and
         (mouseX<r.x2) and (mouseY<r.y2);
end;

function TGame.MouseInRect(x,y,width,height:single):boolean;
begin
 result:=(mouseX>=x) and (mouseY>=y) and
         (mouseX<x+width) and (mouseY<y+height);
end;

function TGame.MouseIsNear(x,y,radius:single):boolean;
begin
 result:=Sqr(mouseX-x)+Sqr(mouseY-y)<=sqr(radius);
end;

procedure TGame.MouseMovedTo(newX,newY:integer);
begin
  oldMouseX:=mouseX;
  oldMouseY:=MouseY;
  mouseX:=newX;
  mouseY:=newY;
  mouseMovedTime:=MyTickCount;
  Signal('MOUSE\MOVE',mouseX and $FFFF+(mouseY and $FFFF) shl 16);
  TGame(game).NotifyScenesAboutMouseMove;
  // Если курсор рисуется вручную, то нужно обновить экран
  if not params.showSystemCursor then screenChanged:=true;
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
  if shiftstate=sscCtrl then exit; // Ignore Ctrl+*

  // Send to active scene
  scene:=TopmostSceneForKbd;
  if scene<>nil then begin
   wst:=WideChar(charcode);
   ast:=AnsiString(wst); // convert to ANSI
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
  code:=keyCode and $FFFF+shiftstate shl 16+scancode shl 24;
  uCode:=keyCode and $FFFF+scanCode shl 24;
  scene:=TopmostSceneForKbd;
  if pressed and (scene<>nil) then
   scene.WriteKey(scancode shl 8+keyCode);
  HandleInternalHotkeys(keyCode,pressed);

  if pressed then begin
    keyState[scanCode]:=keyState[scanCode] or 1;
    //LogMessage('KeyDown %d, KS[%d]=%2x ',[lParam,scanCode,keystate[scanCode]]);
    if scene<>nil then Signal('SCENE\'+scene.name+'\KeyDown',uCode);
  end else begin
    keyState[scanCode]:=keyState[scanCode] and $FE;
    //LogMessage('KeyUp %d, KS[$d]=%2x ',[lParam,scanCode,keystate[scanCode]]);
    if scene<>nil then Signal('SCENE\'+scene.name+'\KeyUp',uCode);
  end;
end;

procedure TGame.MouseButtonPressed(btn:integer;pressed:boolean=true);
begin
 NotifyScenesAboutMouseBtn(btn,pressed);
end;

procedure TGame.MouseWheelMoved(value:integer);
var
 i:integer;
begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then
    scenes[i].onMouseWheel(value);
end;

procedure TGame.SizeChanged(newWidth,newHeight:integer);
begin
 if (windowWidth<>newWidth) or (windowHeight<>newHeight) then begin
  windowWidth:=newWidth;
  windowHeight:=newHeight;
  LogMessage('RESIZED: %d,%d',[windowWidth,windowHeight]);
  SetupRenderArea;
  screenChanged:=true;
 end;
end;

procedure TGame.Activate(activeState:boolean);
begin
 active:=activeState;
 if not active and (params.mode.displayMode=dmFullScreen) then Minimize;
 LogMessage('ACTIVATE: %d',[byte(active)]);
 Signal('Engine\ActivateWnd',byte(active));
 if params.showSystemCursor then wndCursor:=0;
end;

function TGame.MouseWasInRect(r:TRect):boolean;
begin
 result:=(oldMouseX>=r.Left) and (oldmouseY>=r.Top) and
         (oldmouseX<r.Right) and (oldmouseY<r.Bottom);
end;

function TGame.MouseWasInRect(r:TRect2s):boolean;
begin
 result:=(oldmouseX>=r.x1) and (oldmouseY>=r.y1) and
         (oldmouseX<r.x2) and (oldmouseY<r.y2);
end;

constructor TGame.Create(systemPlatform:ISystemPlatform;
  gfxSystem: IGraphicsSystem);
begin
 inherited Create(systemPlatform,gfxSystem);
 ForceLogMessage('Creating '+self.ClassName);
 game:=self;

 running:=false;
 terminated:=false;
 canExitNow:=false;
 useMainThread:=true;
 controlThreadId:=GetCurrentThreadId;
 active:=false;
 paused:=false;
 mainThread:=nil;
 FrameNum:=0;
 fps:=60;
 smoothFPS:=60;
 params.VSync:=1;
 fillchar(keystate,sizeof(keystate),0);
 InitCritSect(crSect,'MainGameObj',20);
 // Primary display
 systemPlatform.GetScreenSize(screenWidth,screenHeight);
 screenDPI:=systemPlatform.GetScreenDPI;
 LogMessage('Screen: %dx%d DPI=%d',[screenWidth,screenHeight,screenDPI]);

 SetLength(scenes,0);
 PublishVar(@renderWidth,'RenderWidth',TVarTypeInteger);
 PublishVar(@renderHeight,'RenderHeight',TVarTypeInteger);
 PublishVar(@windowWidth,'WindowWidth',TVarTypeInteger);
 PublishVar(@windowHeight,'WindowHeight',TVarTypeInteger);
 PublishVar(@screenDPI,'ScreenDPI',TVarTypeInteger);

 PublishVar(@game,'game',TVarTypeGameClass);
end;

function TGame.GetScene(name:string):TGameScene;
 begin
  EnterCritSect;
  try
   result:=TGameScene.FindByName(name) as TGameScene;
  finally
   LeaveCritSect;
  end;
  ASSERT(result<>nil,'Scene '+name+' not found!');
 end;

function TGame.GetSettings:TGameSettings;
 begin
  result:=params;
 end;

function TGame.GetStatus(n:integer):string;
 begin

 end;

destructor TGame.Destroy;
 begin
  if running then Stop;
  DeleteCritSect(crSect);
  inherited;
 end;

procedure TGame.DoneGraph;
 begin
  Signal('Engine\BeforeDoneGraph');
  gfx.Done;
  LogMessage('DoneGraph');

  systemPlatform.ShowWindow(false);
  Signal('Engine\AfterDoneGraph');
 end;

procedure TGame.DPadCustomPoint(x, y: single);
 begin
  EnterCritSect;
  try
   customPoints:=customPoints+[Point(round(x),round(y))];
  finally
   LeaveCritSect;
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
  cx:=mouseX-64;
  cy:=mouseY+64;
  EditImage(magnifierTex);
  FillRect(0,0,127,127,$FF000000);
  rawImage:=magnifierTex.GetRawImage;
  gfx.CopyFromBackbuffer(cx,renderHeight-cy,rawImage);
  rawImage.Free;
  color:=GetPixel(64,63);
  magnifierTex.Unlock;
  magnifierTex.SetFilter(TTexFilter.fltNearest);
  gfx.shader.UseTexture(magnifierTex);
  screenScale:=screenDPI/96;
  mSize:=round(512*screenScale);
  mSize:=mSize and $FFFFFFF0;
  width:=min2(mSize,round(renderWidth*0.4));
  height:=min2(mSize,renderHeight);
  if mouseX<renderWidth div 2 then left:=renderWidth-width
   else left:=0;
  zoom:=round(4*screenScale);
  if (shiftstate and sscShift)>0 then zoom:=zoom*2;
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
   txt.WriteW(defaultFont,ox,height-17*screenScale,$FFFFFFFF,Str16(text),taCenter);
   // Pixel coordinates
   text:=Format('x: %d y: %d',[mousex,mouseY]);
   txt.WriteW(smallFont,ox,height-5*screenScale,$FFFFFFFF,Str16(text),taCenter);
  end;
 end;

procedure TGame.FLog(st: string);
 begin
  FrameLog:=FrameLog+st+#13#10;
 end;

procedure TGame.EnterCritSect;
 begin
  EnterCriticalSection(crSect,GetCaller);
 end;

procedure TGame.LeaveCritSect;
 begin
  LeaveCriticalSection(crSect);
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
 size:=2+0.056*screenDPI;
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
 LogMessage('InitGraph');
 Signal('Engine\BeforeInitGraph');
 aspectRatio:=params.width/params.height;

 systemPlatform.SetupWindow(params);
 gfx.Init(systemPlatform);
 // Choose pixel formats
 gfx.config.ChoosePixelFormats(pfTrueColor,pfTrueColorAlpha,pfRenderTarget,pfRenderTargetAlpha);
 LogMessage('Selected pixel formats:');
 LogMessage('      TrueColor: '+PixFmt2Str(pfTrueColor));
 LogMessage(' TrueColorAlpha: '+PixFmt2Str(pfTrueColorAlpha));
 LogMessage(' as render target:');
 LogMessage('    Opaque: '+PixFmt2Str(pfRenderTarget));
 LogMessage('     Alpha: '+PixFmt2Str(pfRenderTargetAlpha));

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
   if screenDPI>0.95*baseDPI*1.2 then screenScale:=1.2;
   if screenDPI>0.94*baseDPI*1.5 then screenScale:=1.5;
   if screenDPI>0.93*baseDPI*2.0 then screenScale:=2.0;
   if screenDPI>0.92*baseDPI*2.5 then screenScale:=2.5;
 end;

 InitDefaultResources;

 globalTintColor:=$FF808080;
 systemPlatform.ProcessSystemMessages;
 consoleSettings.popupCriticalMessages:=params.mode.displayMode<>dmSwitchResolution;

 AfterInitGraph;
end;


procedure TGame.AfterInitGraph;
begin
 Signal('Engine\AfterInitGraph');
end;

procedure TGame.InitMainLoop;
begin
 try
  LogMessage('Init main loop');
  InitGraph;

  LastOnFrameTime:=MyTickCount;
  LastRenderTime:=MyTickCount;

  Signal('Engine\BeforeMainLoop');
  LogMessage('Game is running...');
  running:=true;
  {$IFDEF ANDROID}
  active:=true; // window is initially active
  {$ENDIF}
 except
  on e:Exception do begin
   ForceLogMessage('Error in InitMainLoop: '+ExceptionMsg(e));
   ErrorMessage(ExceptionMsg(e));
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
  LogMessage('Default RT');
  fl:=HasParam('-nodrt');
  if fl then LogMessage('Modern rendering model disabled by -noDRT switsh');
  if disableDRT then begin
   fl:=true;
   LogMessage('Default RT disabled');
  end;
  if not fl and
     gfx.config.ShouldUseTextureAsDefaultRT and
     (gfx.config.QueryMaxRTSize>=params.width) then begin
   LogMessage('Switching to the modern rendering model');
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
   ForceLogMessage('Error in GLG:IO '+ExceptionMsg(e));
   ErrorMessage('Game engine failure (GLG:IO): '+ExceptionMsg(e));
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
     [s.name,s.zorder,ord(s.status),byte(s.fullscreen),PtrToStr(s.effect)]);
   if s is TUIScene then
    result:=result+Format(' UI=%s (%s)',[TUIScene(s).UI.name, PtrToStr(TUIScene(s).UI)]);
  end;
begin
  with game do begin
   crSect.Enter;
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
     for i:=0 to high(scenes) do writeln(f,i:3,SceneInfo(scenes[i]));
     writeln(f,'Topmost scene = ',game.TopmostVisibleScene(false).name);
     writeln(f,'Topmost fullscreen scene = ',game.TopmostVisibleScene(true).name);
     writeln(f);
     writeln(f,DumpUI);
     close(f);

     gfx.resman.Dump('User request');
   finally
    crSect.Leave;
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
 res:boolean;
begin
 if running then exit;
 game:=self;
 gameEx:=self;

 if useMainThread then begin
  mainThread:=TMainThread.Create(false);
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
  if not running then sleep(50) else break;

 if not running then begin
  ForceLogMessage('Main thread timeout');
  {$IFDEF MSWINDOWS}
   if TMainThread(mainThread).errormsg>'' then ErrorMessage(TMainThread(mainThread).errormsg);
  {$ENDIF}
   raise EFatalError.Create('Can''t run: see log for details.');
 end;
end;

procedure TGame.StartVideoCap(filename: string);
begin
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then exit;
 videoCaptureMode:=true;
 if pos('\',filename)=0 then filename:=videoCapturePath+filename;
 StartVideoCapture(game,filename);
 {$ENDIF}
end;

procedure TGame.FinishVideoCap;
begin
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then FinishVideoCapture;
 videoCaptureMode:=false;
 {$ENDIF}
end;

procedure TGame.Stop;
var
 i,j:integer;
 h:TThreadID;
 fl:boolean;
begin
 ForceLogMessage('GameStop');
 if not running then exit;
 active:=false;

 // Остановить все потоки
 for i:=1 to 16 do
  if (threads[i]<>nil) and (threads[i].running) then
   threads[i].Terminate;

 // подождем...
 for i:=1 to 10 do begin
  fl:=false;
  for j:=1 to 16 do
   if (threads[j]<>nil) and (threads[j].running) then fl:=true;
  if not fl then break;
  LogMessage('Waiting for threads...');
  sleep(50);
 end;

 // Кто не завершился - я не виноват!
 {$IFDEF MSWINDOWS}
 if fl then
  for i:=1 to 16 do
   if (threads[i]<>nil) and (threads[i].running) then begin
    ForceLogMessage('Killing thread: '+PtrToStr(@threads[i].func));
    TerminateThread(threads[i].Handle,0);
   end;
 {$ENDIF}

 if mainThread=nil then
  Signal('Engine\MainLoopDone')
 else begin
  mainThread.Terminate; // Для экономии времени
  canExitNow:=true;

  // Прибить главный поток (только в случае вызова из другого потока)
  h:=GetCurrentThreadId;
  if h<>mainThread.ThreadID then begin
   // Ждем 2 секунды пока поток не завершится по-хорошему
   for i:=1 to 40 do
    if running then sleep(50) else break;
   // Иначе прибиваем силой
   if running then begin
    Signal('Error\MainThreadHangs');
    ForceLogMessage('Killing main thread');
    TerminateThread(mainThread.Handle,0);
   end;
  end;
 end;

 active:=false;
 ForceLogMessage('Can exit now');
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
 captureSingleFrame:=false;

 r:=displayRect;
 img:=TBitmapImage.Create(r.Width,r.Height,ipfXRGB);
 gfx.CopyFromBackbuffer(0,0,img);
 img.tag:=UIntPtr(buf); // save pointer
 inc(PByte(img.data),img.width*4*(img.height-1)); // move pointer to the last line
 img.pitch:=-img.width*4; // invert pitch
 (*
 {$IFDEF VIDEOCAPTURE}
 if videoCaptureMode then begin
  // Передача данных потоку видеосжатия
  StoreFrame(img);
 end;
 {$ENDIF} *)
 case frameCaptureTarget of
  0:if frameCaptureData<>nil then begin
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
   saveAsJPG:=frameCaptureTarget=2;
   if saveAsJpg then ext:='.jpg' else ext:='.png';
   st:='Screenshots'+PathSeparator+FormatDateTime('yymmdd_hhnnss',Now)+ext;
   if saveAsJpg then
    SaveJPEG(img,st,95)
   else begin
    res:=SavePNG(img);
    WriteFile(st,@res[0],0,length(res));
   end;
   capturedName:=st;
   capturedTime:=MyTickCount;
  except
   on e:Exception do ForceLogMessage('Error saving screenshot: '+ExceptionMsg(e));
  end;
 end;
 (*
 if not videoCaptureMode then
  ReleaseFrameData(screenshotDataRaw); *)
end;

procedure TGame.NotifyScenesAboutMouseMove;
var
  i:integer;
begin
 for i:=low(scenes) to High(scenes) do
  if scenes[i].IsActive then
   scenes[i].onMouseMove(mouseX,mouseY);
end;

procedure TGame.NotifyScenesAboutMouseBtn(c:byte;pressed:boolean);
var
  i:integer;
begin
 for i:=low(scenes) to high(scenes) do
  if scenes[i].IsActive then
   scenes[i].onMouseBtn(c,pressed);
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
  t2:=MyTickCount;
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
   t:=MyTickCount;
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   p:=Point(tag and $FFFF,tag shr 16);
   ClientToGame(p);
   MouseX:=p.x;
   MouseY:=p.y;
   mouseMovedTime:=MyTickCount;
   Signal('Mouse\Move',mouseX+mouseY shl 16);
   NotifyScenesAboutMouseMove;
   Signal('Mouse\BtnDown\Left',1);
   NotifyScenesAboutMouseBtn(1,true);
   sleep(0);
   Timing;
 end else
 if event='SINGLETOUCHMOVE' then with game do begin
   t:=MyTickCount;
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   p:=Point(tag and $FFFF,tag shr 16);
   ClientToGame(p);
   MouseX:=p.x;
   MouseY:=p.y;
   mouseMovedTime:=MyTickCount;
   Signal('Mouse\Move',mouseX+mouseY shl 16);
   NotifyScenesAboutMouseMove;
   Timing;
 end else
 if event='SINGLETOUCHRELEASE' then with game do begin
   t:=MyTickCount;
   Signal('Mouse\BtnUp\Left',1);
   NotifyScenesAboutMouseBtn(1,false);
   OldMouseX:=mouseX;
   OldMouseY:=MouseY;
   mouseX:=4095; mouseY:=4095;
   mouseMovedTime:=MyTickCount;
   Signal('Mouse\Move',PackWords(mouseX,mouseY));
   NotifyScenesAboutMouseMove;
   Timing;
 end else
 if SameText(event,'REDRAW') then begin
  if game.running then
   RenderAndPresentFrame;
 end else
 if SameText(event,'RESIZE') then begin
  SizeChanged(ExtractWord(tag,0),ExtractWord(tag,1));
 end else
 if SameText(event,'SETACTIVE') then begin
  Activate(tag<>0);
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
 if HasPrefix(event,'SWITCHTOSCENE\') then begin
  SwitchToScene(Copy(event,15,100));
 end else
 if HasPrefix(event,'SHOWWINDOW\') then begin
  ShowWindowScene(Copy(event,15,100));
 end else
 if HasPrefix(event,'HIDEWINDOW\') then begin
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
  systemPlatform.FlashWindow(tag);
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
   pnt:=Point(SmallInt(tag),SmallInt(tag shr 16));
   ClientToGame(pnt);
   MouseMovedTo(pnt.x,pnt.y); // process motion in game space
   if params.showSystemCursor then
    systemPlatform.SetCursor(wndCursor);
 end else
 if SameText(event,'GLOBALMOVE') then begin
   pnt:=Point(SmallInt(tag),SmallInt(tag shr 16));
   systemPlatform.ScreenToClient(pnt);
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
     bestPnt:=Point(mouseX+nx*20,mouseY+ny*20);
     systemPlatform.ClientToScreen(bestPnt);
     systemPlatform.SetMousePos(bestPnt.x,bestPnt.y);
     exit;
   end;
   EnterCritSect;
   try
    best:=100000;
    for i:=0 to high(activeCustomPoints) do
     with activeCustomPoints[i] do begin
      dx:=x-mouseX; dy:=y-mouseY;
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
    LeaveCritSect;
   end;
   if best<100000 then begin
    GameToClient(bestPnt);
    systemPlatform.ClientToScreen(bestPnt);
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
 t:=MyTickCount+time;
 repeat
  HandleSignals;
  if (game<>nil) and (GetCurrentThreadId=TGame(game).mainThread.ThreadID) then
   systemPlatform.ProcessSystemMessages;
  Sleep(Clamp(t-myTickCount,0,20));
 until MyTickCount>=t;
end;


function TGame.OnFrame:boolean;
var
 i,j,v,n:integer;
 deltaTime,time:int64;
 p:pointer;
begin
 result:=false;
 DestroyQueuedElements; // delete queued UI elements

 EnterCriticalSection(crSect);
 try
 // Сортировка сцен
 if high(scenes)>1 then begin
  for n:=1 to high(scenes) do
   for i:=0 to n-1 do
    if scenes[i+1].zorder>scenes[i].zorder then begin
     Swap(scenes[i],scenes[i+1],sizeof(scenes[i]));
    end;
 end;
 finally
  LeaveCriticalSection(crSect);
 end;
 EnterCriticalSection(UICritSect);
 try
  // Перечисление корневых эл-тов UI в соответствии со сценами
  // (связь сцен и UI)
  for i:=0 to high(scenes) do begin
   if (scenes[i] is TUIScene) then
    with scenes[i] as TUIScene do
     if (UI<>nil) then begin
      ui.order:=scenes[i].zorder;
     end;
  end;
 finally
  LeaveCriticalSection(UICritSect);
 end;
 deltaTime:=MyTickCount-LastOnFrameTime;
 LastOnFrameTime:=MyTickCount;
 // Обработка всех активных сцен
 for i:=low(scenes) to high(scenes) do
  if scenes[i].status<>TSceneStatus.ssFrozen then begin
   // Обработка сцены
   if scenes[i].frequency>0 then begin // Сцена обрабатывается с заданной частотой
    time:=1000 div scenes[i].frequency;
    inc(scenes[i].accumTime,DeltaTime);
    n:=0;
    while scenes[i].accumTime>0 do begin
     result:=scenes[i].Process or result;
     dec(scenes[i].accumTime,time);
     inc(n);
     if n>5 then begin
      scenes[i].accumTime:=0;
      break; // запрет слишком высокой частоты обработки
     end;
    end;
   end else begin
    result:=scenes[i].Process or result;  // обрабатывать каждый раз
   end;
  end;
end;

procedure TGame.PresentFrame;
 begin
   if dRT<>nil then begin
    // Была отрисовка в текстуру - теперь нужно отрисовать её в RenderRect
    gfx.target.Viewport(0,0,windowWidth,windowHeight,windowWidth,windowHeight);
    gfx.BeginPaint(nil);
    try
    // Если есть неиспользуемые полосы - очистить их (но не каждый кадр, чтобы не тормозило)
    if not types.EqualRect(displayRect,types.Rect(0,0,windowWidth,windowHeight)) and
       ((frameNum mod 5=0) or (frameNum<3)) then gfx.target.Clear($FF000000);

    with displayRect do begin
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
  inc(FrameNum);
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
 oldRW:=renderWidth;
 oldRH:=renderHeight;
 oldDisplayRect:=displayRect;
 w:=0; h:=0;
 case params.mode.displayFitMode of
  dfmCenter:begin
   w:=params.width;
   h:=params.height;
  end;
  dfmFullSize:begin
   w:=windowWidth;
   h:=windowHeight;
   if params.mode.displayScaleMode=dsmDontScale then begin
    params.width:=w;
    params.height:=h;
   end;
  end;
  dfmKeepAspectRatio:begin
   w:=windowWidth;
   h:=windowHeight;
   if w>round(h*aspectRatio*1.01) then w:=round(h*aspectRatio);
   if h>round(w/aspectRatio*1.01) then h:=round(w/aspectRatio);
   if params.mode.displayScaleMode in [dsmDontScale] then begin
    params.width:=w;
    params.height:=h;
   end;
  end;
 end;
 displayRect:=rect(0,0,w,h);
 types.OffsetRect(displayRect,(windowWidth-w) div 2,(windowHeight-h) div 2);

 renderWidth:=params.width;
 renderHeight:=params.height;

 // Nothing changed?
 if (displayRect=oldDisplayRect) and
    (renderWidth=oldRW) and (renderHeight=oldRH) then exit;

 LogMessage(Format('Set render area: (%d x %d) (%d,%d) -> (%d,%d)',
   [renderWidth,renderHeight,displayRect.Left,displayRect.Top,displayRect.Right,displayRect.Bottom]));
 SetDisplaySize(renderWidth,renderHeight); // UI display size
 Signal('ENGINE\BEFORERESIZE');
 for i:=low(scenes) to High(scenes) do
  scenes[i].onResize;
 Signal('ENGINE\RESIZED');

 if (gfx<>nil) and (gfx.target<>nil) then begin
  gfx.target.Resized(windowWidth,windowHeight);
  w:=displayRect.Width;
  h:=displayRect.Height;
  if dRT=nil then begin
   // Rendering directly to the framebuffer
   gfx.target.Viewport(displayRect.Left,windowHeight-displayRect.Bottom,
     w,h,params.width,params.height);
  end else begin
   // Rendering to a framebuffer texture
   with params.mode do
    if (displayFitMode in [dfmFullSize,dfmKeepAspectRatio]) and
       (displayScaleMode in [dsmDontScale,dsmScale]) and
       ((dRT.width<>w) or (dRT.height<>h)) then begin
     LogMessage('Resizing framebuffer');
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
 EnterCriticalSection(crSect);
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
  LeaveCriticalSection(crSect);
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
   EnterCritSect;
   try
    n:=length(scenes);
    SetLength(sList,n);
    for i:=0 to high(scenes) do sList[i]:=scenes[i];
   finally
    LeaveCritSect;
   end;
   y:=0;
   draw.FillRect(0,0,screenScale*360,(n+0.4)*screenScale*16,$80000000);
   txt.BeginBlock(toDontTranslate);
   for i:=0 to high(sList) do begin
    inc(y,round(16*screenScale));
    c:=$FFA0A0A0;
    if sList[i].IsActive then begin
     c:=$FFFFFFC0;
     txt.WriteW(smallFont,50*screenScale,y,c,Str16(IntToStr(sList[i].zOrder)),taRight);
    end else
    if sList[i].status=TSceneStatus.ssBackground then
     c:=$FFC0D0E0;
    txt.WriteW(smallFont,60*screenScale,y,c,Str16(sList[i].name));
    txt.WriteW(smallFont,200*screenScale,y,c,Str16(sList[i].ClassName));
    if sList[i].effect<>nil then
     txt.WriteW(smallFont,360*screenScale,y,c,Str16(sList[i].effect.ClassName));
   end;
   txt.EndBlock;
  end;
 procedure ListUI;
  begin

  end;
begin
 EnterCriticalSection(crSect);
 try
  FLog('RDebug');
  case debugOverlay of
   1:DrawHelp;
   2:txt.WriteW(MAGIC_TEXTCACHE,1,1,$FFFFFFFF,'');
   3:ListScenes;
   4:ListUI;
  end;

  for feature in debugFeatures do
   case feature of
    dfShowFPS:begin
     w:=SRound(48*screenScale);
     h:=SRound(36*screenScale);
     x:=renderWidth-w; y:=1;
     draw.FillRect(x,y,x+w-2,y+h,$80000000);
     txt.WriteW(defaultFont,x+w-5,y+h*0.4,$FFFFFFFF,FloatToStrF(FPS,ffFixed,5,1),taRight);
     txt.WriteW(defaultFont,x+w-5,y+h*0.9,$FFFFFFFF,FloatToStrF(SmoothFPS,ffFixed,5,1),taRight);
    end;

    dfShowMagnifier:DrawMagnifier;

    dfShowNavigationPoints:begin
      for i:=0 to high(activeCustomPoints) do
       with activeCustomPoints[i] do
        draw.FillRect(x-10,y-10,x+10,y+10,$70E00000);
    end;
   end;

  // Capture screenshot?
  if (capturedTime>0) and (MyTickCount<CapturedTime+3000) and (gfx<>nil) then begin
    x:=params.width div 2;
    y:=params.height div 2;
    draw.FillRect(x-200*screenScale,y-40*screenScale,x+200*screenScale,y+40*screenScale,$60000000);
    draw.Rect(x-200*screenScale,y-40*screenScale,x+200*screenScale,y+40*screenScale,$A0FFFFFF);
    txt.Write(largerFont,x,y-16*screenScale,$FFFFFFFF,'Screen captured to:',taCenter);
    txt.Write(defaultFont,x,y+8*screenScale,$FFFFFFFF,capturedName,taCenter);
  end;

 finally
  LeaveCriticalSection(crSect);
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
 if systemPlatform.IsTerminated then exit;
 DeltaTime:=MyTickCount-LastRenderTime;
 LastRenderTime:=MyTickCOunt;
 FLog('RF1');

 // в полноэкранном режиме вывод по центру
 EnterCriticalSection(crSect);
 try
  txt.ClearLink;
  try
   // Очистим экран если нет ни одной background-сцены или они не покрывают всю область вывода
   fl:=true;
   for i:=low(scenes) to high(scenes) do
    if scenes[i].fullscreen and (scenes[i].IsActive)
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
   for i:=low(scenes) to high(scenes) do
    if scenes[i].effect<>nil then begin
     FLog('Eff on '+scenes[i].ClassName+' is '+scenes[i].effect.ClassName+' : '+
      inttostr(scenes[i].effect.timer)+','+booltostr(scenes[i].effect.done));
     effect:=scenes[i].effect;
     FLog('Eff ret');
     inc(effect.timer,DeltaTime);
     if effect.done then begin // Эффект завершился
      Signal('ENGINE\EffectDone',cardinal(scenes[i])); // Посылаем сообщение о завершении эффекта
      effect.Free;
      scenes[i].effect:=nil;
     end;
    end;
  except
   on e:exception do CritMsg('RFrame2 '+ExceptionMsg(e));
  end;

 // Sort active scenes by Z order
  FLog('Sorting');
  n:=0;
  try
   for i:=low(scenes) to high(scenes) do
    if scenes[i].IsActive then begin
     // Сортировка вставкой. Найдем положение для вставки и вставим туда
     if n=0 then begin
      sc[1]:=scenes[i]; inc(n); continue;
     end;
     fl:=true;
     for j:=n downto 1 do
      if sc[j].zorder>scenes[i].zorder then sc[j+1]:=sc[j]
       else begin sc[j+1]:=scenes[i]; fl:=false; break; end;
     if fl then sc[1]:=scenes[i];
     inc(n);
    end;
  except
   on e:exception do CritMsg('RFrame3 '+ExceptionMsg(e));
  end;
  if n>0 then topmostScene:=sc[n];
 finally
  LeaveCriticalSection(crSect); // активные сцены вынесены в отдельный массив - их нельзя удалять в процессе отрисовки
 end;

 gfx.BeginPaint(dRT);
 SetupRenderArea;
 // Draw all active scenes
 for i:=1 to n do try
  StartMeasure(integer(i+4));
  // Draw shadow
  if sc[i].shadowColor<>0 then
   draw.FillRect(0,0,renderWidth,renderHeight,sc[i].shadowColor);

  if not sc[i].initialized then try
   sc[i].Initialize;
   sc[i].initialized:=true;
  except
   on e:Exception do CritMsg('Scene '+sc[i].name+' initialization error: '+ExceptionMsg(e));
  end;

  if systemPlatform.IsTerminated then exit;
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

  //textLink:=curTextLink;
  //textLinkRect:=curTextLinkRect;

 {$IFDEF ANDROID}
 //DebugMessage(framelog);
 {$ENDIF}

 gfx.EndPaint;
 FLog('RDone');
end;

procedure TGame.AddScene(scene: TGameScene);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
  // Already added?
  for i:=low(scenes) to high(scenes) do
   if scenes[i]=scene then
    raise EWarning.Create('Scene already added: '+scene.name);
  // Add
  LogMessage('Adding scene: '+scene.name);
  scene.accumTime:=0;
  i:=length(scenes);
  SetLength(scenes,i+1);
  scenes[i]:=scene;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TGame.RemoveScene(scene: TGameScene);
var
 i,n:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=low(scenes) to high(scenes) do
  if scenes[i]=scene then begin
   n:=length(scenes)-1;
   scenes[i]:=scenes[n];
   SetLength(scenes,n);
   LogMessage('Scene removed: '+scene.name);
   exit;
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TGame.TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 result:=nil;
 for i:=low(scenes) to high(scenes) do
  if scenes[i].IsActive then begin
   if fullscreenOnly and not scenes[i].fullscreen then continue;
   if result=nil then
    result:=scenes[i]
   else
    if scenes[i].zorder>result.zorder then result:=scenes[i];
  end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TGame.WaitFor(pb:PBoolean; msg:string);
var
 i:integer;
begin
 i:=0;
 if msg='' then msg:=PtrToStr(GetCaller);
 while not pb^ do begin
  if i mod 10=0 then LogMessage('WaitFor '+msg);
  ToggleCursor(CursorID.Wait,true);
  sleep(30);
  ToggleCursor(CursorID.Wait,false);
 end;
end;

procedure TGame.MoveWindowTo(x,y,width,height:integer);
 begin
  systemPlatform.MoveWindowTo(x,y,width,height);
 end;

procedure TGame.Minimize;
 begin
  systemPlatform.Minimize;
 end;

procedure TGame.FireMessage(st: string8);
 begin

 end;

procedure TGame.SwitchToAltSettings; // Alt+Enter
 begin
  LogMessage('Alt+Enter: switch to alt settings');
  Swap(params.width,altWidth);
  Swap(params.height,altHeight);
  Swap(params.mode,params.altMode,sizeof(params.mode));
  SetSettings(params);
 end;

function WaitAndSwitch(sPtr:UIntPtr):integer;
 var
  scene:TGameScene;
 begin
  scene:=pointer(sPtr);
  WaitFor(scene.loaded,10000); // 10 sec wait for scene to load
  TSceneSwitcher.defaultSwitcher.SwitchToScene(scene.name);
 end;

procedure TGame.SwitchToScene(name:string);
 var
  scene:TGameScene;
 begin
  scene:=TGameScene.FindByName(name) as TGameScene;
  if scene.loaded then
   TSceneSwitcher.defaultSwitcher.SwitchToScene(name)
  else
   game.RunAsync(WaitAndSwitch,UIntPtr(scene),0,'SwitchToScene:'+scene.name);
 end;

procedure TGame.ShowWindowScene(name:string;modal:boolean);
 begin
  TSceneSwitcher.defaultSwitcher.ShowWindowScene(name,modal);
 end;

procedure TGame.HideWindowScene(name:string);
 begin
  TSceneSwitcher.defaultSwitcher.HideWindowScene(name);
 end;

procedure TGame.SetWindowCaption(text: string);
begin
 systemPlatform.SetWindowCaption(text);
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
  p.X:=round((p.X-displayRect.Left)*renderWidth/(displayRect.Right-displayRect.Left));
  p.Y:=round((p.Y-displayRect.top)*renderHeight/(displayRect.Bottom-displayRect.Top));
 end;

procedure TGame.GameToClient(var p:TPoint);
 begin
  p.X:=round(displayRect.Left+p.X*(displayRect.Right-displayRect.Left)/renderWidth);
  p.Y:=round(displayRect.top+p.Y*(displayRect.Bottom-displayRect.Top)/renderHeight);
 end;

function TGame.GetCursorForID(cursorID:integer):THandle;
var
 i:integer;
begin
 result:=0;
 EnterCriticalSection(crSect);
 try
  for i:=0 to high(cursors) do
   with TGameCursor(cursors[i]) do
   if ID=cursorID then begin
    result:=handle; exit;
   end;
 finally
  LeaveCriticalSection(crSect);
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
 EnterCriticalSection(crSect);
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
  cursor:=TGameCursor(cursors[i]);

 cursor.ID:=CursorID;
 cursor.priority:=priority;
 cursor.handle:=cursorHandle;
 if cursorID<>Apus.Engine.API.CursorID.Default then
  cursor.visible:=false;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TGame.HideAllCursors;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=0 to high(cursors) do
  with cursors[i] as TGameCursor do
   visible:=false;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TGame.ToggleCursor(CursorID: integer; state: boolean);
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 for i:=0 to high(cursors) do
  with cursors[i] as TGameCursor do
   if ID=CursorID then visible:=state;
 if not params.showSystemCursor then screenChanged:=true;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TGame.TopmostSceneForKbd: TGameScene;
var
 i:integer;
 maxZ:integer;
 sc:TUIScene;
begin
 EnterCriticalSection(crSect);
 try
  result:=nil;
  maxZ:=-10000000;
  for i:=low(scenes) to high(scenes) do
   if (scenes[i].IsActive) and
      not scenes[i].ignoreKeyboardEvents then begin
    // UI Scene?
    if scenes[i] is TUIScene then begin
     sc:=TUIScene(scenes[i]);
     if not sc.UI.enabled then exit;
     if (modalElement<>nil) and not modalElement.HasParent(sc.UI) then exit;
    end;
    // Topmost?
    if scenes[i].zorder>maxZ then begin
     result:=scenes[i];
     maxZ:=scenes[i].zorder;
    end;
   end;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

function TGame.GetThreadResult(h: THandle): integer;
var
 i:integer;
begin
 result:=-1; // not found
 EnterCriticalSection(RA_sect);
 try
 for i:=1 to high(threads) do
  if (threads[i]<>nil) and (threads[i].id=h) then begin
   if threads[i].running then result:=0  // еще выполняется
    else result:=threads[i].ReturnValue;
   exit;
  end;
 finally
  LeaveCriticalSection(RA_sect);
 end;
end;

function TGame.RunAsync(threadFunc:TAsyncProc;param:UIntPtr;ttl:single;name:string):THandle;
var
 i,best:integer;
 t:int64;
begin
 result:=0;
 best:=0; t:=mytickcount;
 EnterCriticalSection(RA_Sect);
 try
 for i:=1 to high(threads) do
  if threads[i]=nil then begin best:=i; break; end
   else
    if (not threads[i].running) and (threads[i].FinishTime<t) then
     begin t:=threads[i].FinishTime; best:=i; end;

 if best=0 then raise EError.Create('Can''t start new thread - no free handles!');
 if threads[best]<>nil then threads[best].Free;
 threads[best]:=TCustomThread.Create(true);
 if ttl>0 then threads[best].timetokill:=Mytickcount+round(ttl*1000)
  else threads[best].TimeToKill:=$FFFFFFFF;
 threads[best].running:=true;
 threads[best].func:=threadFunc;
 threads[best].param:=param;
 if name='' then name:=PtrToStr(@threadFunc);
 threads[best].name:='RA_'+name;
 inc(LastThreadID);
 threads[best].id:=lastThreadID;
 threads[best].Resume;
 result:=lastThreadID;
 finally
  LeaveCriticalSection(RA_Sect);
 end;
 LogMessage('[RA] thread launched, pos='+inttostr(best)+', id='+inttostr(result)+
   ', func='+PtrToStr(@threadFunc)+', time: '+inttostr(threads[best].TimeToKill),8);
end;

procedure TGame.FrameLoop;
 var
  i:integer;
  t:int64;
  mb:byte;
 begin
  t:=MyTickCount;
  PingThread;
  // Обновление ввода с клавиатуры (и кнопок мыши)
  shiftState:=systemPlatform.GetShiftKeysState;
  mb:=systemPlatform.GetMouseButtons;
  if mb<>mouseButtons then begin
    oldMouseButtons:=mouseButtons;
    mouseButtons:=mb;
  end;

  for i:=0 to High(keyState) do
   keyState[i]:=keyState[i] and 1+(keyState[i] and 1) shl 1;

  StartMeasure(14);
  systemPlatform.ProcessSystemMessages; // this stalls if window is moved/resized
  try
    HandleSignals;
  except
    on e:exception do ForceLogMessage('Error in FrameLoop 1: '+ExceptionMsg(e));
  end;
  if not active then
    Delay(5); // limit speed in inactive state
  EndMeasure2(14);

  if mainThread.CheckTerminated then exit;
  RenderAndPresentFrame;

  t:=MyTickCount-t;
  if t<500 then avgTime:=avgTime*0.9+t*0.1;
 end;

procedure TGame.RenderAndPresentFrame;
 var
  ticks:int64;
  i:integer;
 begin
   ticks:=MyTickCount;
   if frameStartTime>0 then frameTimeDelta:=ticks-frameStartTime
    else frameTimeDelta:=20; // initial value
   frameStartTime:=ticks;

   // FPS
   inc(fpsAccumTime,frameTimeDelta);
   inc(fpsAccumFrames);
   if (fpsAccumTime>250) then begin
    FPS:=1000*fpsAccumFrames/fpsAccumTime;
    SmoothFPS:=SmoothFPS*0.8+FPS*0.2;
    fpsAccumFrames:=0;
    fpsAccumTime:=0;
   end;

   if frameTimeDelta>500 then
    LogMessage('Warning: main loop stall for '+inttostr(frameTimeDelta)+' ms');

   // Обработка кадра
   StartMeasure(3);
   if OnFrame then screenChanged:=true; // это чтобы можно было и в других местах выставлять флаг!
   EndMeasure(3);
   try
    HandleSignals;
   except
    on e:exception do ForceLogMessage('Error in FrameLoop 2: '+ExceptionMsg(e));
   end;
   if SystemPlatform.IsTerminated then exit;

   if active or (params.mode.displayMode<>dmSwitchResolution) then begin
    // Если программа активна, то выполним отрисовку кадра
    if screenChanged then begin
     try
      PrevFrameLog:=frameLog;
      frameLog:='';
      StartMeasure(2);
      RenderFrame;
      EndMeasure2(2);
     except
      on E:Exception do CritMsg('Error in renderframe: '+ExceptionMsg(e)+' framelog: '+framelog);
     end;
    end;
   end;

   // Здесь можно что-нибудь сделать
   Sleep(onFrameDelay);
   // Обработка thread'ов
   EnterCriticalSection(RA_sect);
   try
    for i:=1 to 16 do
     if threads[i]<>nil then with threads[i] do
      if threads[i].running and (timetokill<MyTickCount) then begin
       ForceLogMessage(timestamp+' ALERT: thread terminated by timeout, '+PtrToStr(@func)+
        ', curtime: '+inttostr(MyTickCount));
       {$IFNDEF IOS}
       TerminateThread(Handle,0);
       {$ENDIF}
       ReturnValue:=-1;
       Signal('Engine\thread\done\'+PtrToStr(@func),-1);
       Signal('Error\Thread TimeOut',0);
       threads[i].running:=false;
     end;
   finally
    LeaveCriticalSection(RA_sect);
   end;

   // Теперь нужно вывести кадр на экран
   if (active or (params.mode.displayMode<>dmSwitchResolution)) and
      screenChanged then begin
    PresentFrame;
    if captureSingleFrame or videoCaptureMode then
     CaptureFrame;
   end else
    sleep(5);
   game.Flog('LEnd');
 end;

{ TCustomThread }
procedure TCustomThread.Execute;
 begin
  LogMessage('CustomThread '+name+' started!');
  RegisterThread(name);
  running:=true;
  try
   ReturnValue:=func(param);
   LogMessage('CustomThread done');
  except
   on e:exception do ForceLogMessage('RunAsync: failure - '+ExceptionMsg(e));
  end;
  FinishTime:=MyTickCount;
  running:=false;
  Signal('engine\thread\done\'+PtrToStr(@func),ReturnValue);
  UnregisterThread;
 end;

{ TMainThread }
procedure TMainThread.Execute;
 begin
  // Инициализация
  errorMsg:='';
  try
   LogMessage(TimeStamp+' Main thread started - '+inttostr(cardinal(GetCurrentThreadID)));
   RegisterThread('MainThread');
   LogMessage(GetSystemInfo);
   SetEventHandler('Engine\',EngineEvent,emInstant);
   SetEventHandler('Engine\Cmd',EngineCmdEvent,emQueued);

   systemPlatform.CreateWindow(gameEx.params.title);
   gameEx.InitMainLoop; // вызывает InitGraph

   game.running:=true; // Это как-бы семафор для завершения функции Run
   LogMessage('MainLoop started');
   // Главный цикл
   repeat
    try
     gameEx.FrameLoop;
    except
     on e:Exception do CritMsg('Error in main loop: '+ExceptionMsg(e));
    end;
   until terminated;
   ForceLogMessage('Main loop exit');
   gameEx.terminated:=true;
   Signal('Engine\AfterMainLoop');

   // Состояние ожидания команды остановки потока из безопасного места
   while not gameEx.canExitNow do sleep(20);
   ForceLogMessage('Finalization');

   // Финализация
   gameEx.DoneGraph;
   systemPlatform.DestroyWindow;
  except
   on e:Exception do begin
    errorMsg:=ExceptionMsg(e);
    CritMsg('Global error: '+ExceptionMsg(e));
   end;
  end;

  UnregisterThread;
  ForceLogMessage('Main thread done');
  game.running:=false; // Эта строчка должна быть ПОСЛЕДНЕЙ!
 end;

{ TVarTypeGameClass }

class function TVarTypeGameClass.GetField(variable:pointer;fieldName:string;
  out varClass:TVarClass):pointer;
 begin

 end;

class function TVarTypeGameClass.ListFields:string;
 var
  i:integer;
  sa:StringArray8;
 begin
  with TGame(game) do begin
   for i:=0 to high(scenes) do
    AddString(sa,String8('scene-'+scenes[i].name));
  end;
  result:=join(sa,',');
 end;

initialization
 InitCritSect(RA_sect,'Game_RA',110);
 PublishVar(@onFrameDelay,'onFrameDelay',TVarTypeInteger);
end.
