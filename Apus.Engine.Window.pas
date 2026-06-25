// Render window and backbuffer management.
//
// TWindow owns a backbuffer (size, format, clear color) and
// the scene stack rendered into it. Handles per-window frame
// timing, frame capture, and debug overlay state.
// Platform-level window creation is handled by ISystemPlatform;
// this unit operates above that layer.
//
// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$I defines.inc}
unit Apus.Engine.Window;
interface
uses Apus.Core, Apus.Geom2D, Apus.Engine.Types, Apus.Engine.Scene, Apus.Threads,
  Apus.Classes, Apus.Engine.Resources;

const
 FRAME_TIME_RING_SIZE=512;

type
 TWindow=class;
 TSceneArray=array of TGameScene;
 TWindowArray=array of TWindow;
 TRenderProc=procedure of object;

 TFrameCapture=record
  singleFrame:boolean; // request frame capture
  // 0 - keep in data, 2 - save as JPEG, 3 - save as PNG
  target:integer;
  data:TObject;
  videoMode:boolean;
  videoPath:string;
  capturedName:string;
  capturedTime:int64;
  procedure Reset;
 end;

 // Per-frame render call counters (reset each frame in PresentRenderedFrame).
 TRenderStats=record
  drawCalls:integer;
  shaderChanges:integer;
  texChanges:integer;
  clipChanges:integer;
  verticesDrawn:integer;
  procedure Reset;
 end;

 TFrameTiming=record
  // Robot diagnostics toggle.
  phaseMetrics:boolean;
  // Per-frame phase timings (microseconds).
  pendingMsgUs:integer;
  lastMsgUs:integer;
  lastOnFrameUs:integer;
  lastRenderUs:integer;
  lastPresentUs:integer;
  lastSleepUs:integer;
  // Frame duration ring and per-phase history.
  frameTimeRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseMsgRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseOnFrameRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseRenderRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phasePresentRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseSleepRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  frameTimeRingPos:integer;
  frameTimeRingCount:integer;
  lastFrameTimeUs:integer;
  // High-precision frame timer used by render loop.
  frameTimer:int64;
  frameTimerReady:boolean;
  // Cached update moments for throttled FPS refresh.
  lastFpsUpdate:int64;
  lastSmoothFpsUpdate:int64;
  // Accumulated frame time while redraw is skipped (for lazy redraw fallback).
  idleRedrawAccUs:integer;
  // Accumulated frame time since last presented frame (for FPS sampling).
  presentSampleAccUs:integer;

  procedure Reset;
  procedure PushSample(deltaUs,msgUs,onFrameUs,renderUs,presentUs,sleepUs:integer);
  function MaxRecentFrameUs(sampleCount:integer):integer;
  function CalcTrimmedFrameMs(windowUs,minFrames,trimPermille:integer; out avgMs:double):boolean;
  procedure UpdateFps(out fps,smoothFps:single);
 end;

 // Per-window modal dialog state: a stack of modal UI roots.
 // Fields are typed TObject because TWindow's interface section cannot see
 // TUIElement (Apus.Engine.UITypes uses this unit). Typed, behavior-rich
 // access is provided by TModalStateHelper (record helper) in Apus.Engine.UITypes.
 TModalState=record
  element:TObject;               // active modal UI root (TUIElement), nil if none
  stack:array[1..8] of TObject;  // suspended modal roots below the active one
  stackSize:integer;
 end;

 // Base class for engine windows.
 // Platform-specific subclasses implement abstract methods.
 // Created via ISystemPlatform.CreateWindow.
TWindow=class(TNamedObject)
protected
  class function ClassHash:pointer; override;
private
  // Authoritative per-frame timing source: high-precision microseconds.
  frameStartUsValue:int64;
  frameDeltaUsValue:int64;
  // Compatibility projections for legacy code paths that consume ms/sec.
  frameStartMsValue:int64;
  frameDeltaMsValue:int64;
  frameStartSecValue:double;
  frameDeltaSecValue:double;
public
  // Render area
  renderWidth,renderHeight:integer; // size of render area in virtual pixels
  displayRect:TRect; // render area inside window's client area, in screen pixels
  windowWidth,windowHeight:integer; // window client size in pixels
  screenChanged:boolean; // set to true to request frame rendering

  // Input state snapshot for this window: values are stored per-window (not global)
  // so they stay stable during frame processing even with multiple window threads.
  mousePos:TPoint; // mouse position in game coordinates
  oldMousePos:TPoint; // previous mouse position
  mouseMovedTime:int64; // when mouse position last changed
  // UI-dispatch bookkeeping (kept next to mousePos as it's positional state):
  moveKind:TMoveKind; // set by the UI dispatcher before each gameplay onMouseMove call
  mouseOverUI:boolean; // true while the cursor sits over a consuming UI element (prev-frame state)
  mouseButtons:byte; // button flags (bit 0=left, 1=right, 2=middle)
  oldMouseButtons:byte; // previous button state
  shiftState:byte; // shift keys: aggregate (sscBaseMask) + right-side bits (sscRightMask)
  // bit 0 - pressed, bit 1 - was pressed last frame (01=just pressed, 10=just released)
  keyState:array[0..255] of byte; // indexed by scancode

  // Window state
  active:boolean; // true when window is visible and updated
  paused:boolean; // pause rendering regardless of active state
  screenDPI:integer; // DPI according to system settings
  frameNum:integer; // increments every frame
  FPS,smoothFPS:single; // current and smoothed FPS
  // Text link (TODO: move out)
  textLink:cardinal;
  textLinkRect:TRect;

  // Per-frame diagnostic log (cleared every frame, saved on error)
  frameLog,prevFrameLog:string;

 // Per-window data
  renderThread:IThread; // nil for main window, set by AddWindow for extra windows
  runtimeLock:TLock; // protects scene list + UI access for this window
  timings:TFrameTiming;
  stats:TRenderStats;
  capture:TFrameCapture;
  dRT:TTexture; // default render target (can be nil)
  dRTdepth:TTexture; // depth buffer texture
  scenes:TSceneArray;
  topmostScene:TGameScene; // last topmost active scene for this window
  modal:TModalState; // modal dialog state for this window (see TModalStateHelper)
  // Frame timing (per-window, read-only from outside):
  // - `*Us` is the single source of truth (high precision)
  // - `*Ms` / `*Sec` are derived values for API compatibility
  property frameStartUs:int64 read frameStartUsValue;
  property frameDeltaUs:int64 read frameDeltaUsValue;
  property frameStartMs:int64 read frameStartMsValue;
  property frameDeltaMs:int64 read frameDeltaMsValue;
  property frameStartSec:double read frameStartSecValue;
  property frameDeltaSec:double read frameDeltaSecValue;

  constructor Create(windowName:String8='MainWnd');
  destructor Destroy; override;
  procedure SetFrameTiming(startUs,deltaUs:int64);
  procedure ResetFrameTiming;

  procedure Lock(caller:pointer=nil);
  procedure Unlock;
  procedure ResetSceneData;
  procedure AddScene(scene:TGameScene);
  function RemoveScene(scene:TGameScene):boolean;
  function TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
  procedure NotifyScenesModeChanged;
  procedure NotifyScenesMouseMove(mouseX,mouseY:integer);
  procedure NotifyScenesMouseBtn(c:byte;pressed:boolean);
  procedure NotifyScenesMouseWheel(value:integer);
  procedure NotifyScenesResize;
  // Called once per frame (after ProcessMessages) to update mouse position,
  // emit MOUSE\MOVE signal and notify scenes. Buttons are handled immediately.
  procedure FlushMouseInput;
  procedure DPIChanged(newDPI:integer);
  function ProcessScenes(deltaTime:integer):boolean;

  procedure Close; virtual; abstract;
  // Apply display/window settings (mode, size, style, position) to an existing native window.
  // Called on startup and on runtime display-mode changes (Alt+Enter etc). Should also trigger resize flow so engine can recompute render/display areas.
  procedure Configure(params:TGameSettings); virtual; abstract;
  procedure Show(show:boolean); virtual; abstract;
  function GetHandle:THandle; virtual; abstract;
  procedure GetSize(out width,height:integer); virtual; abstract;
  procedure MoveTo(x,y:integer;width:integer=0;height:integer=0); virtual; abstract;
  procedure SetCaption(text:string); virtual; abstract;
  procedure Minimize; virtual; abstract;
  procedure FlashWindow(count:integer); virtual; abstract;
  procedure ProcessMessages; virtual; abstract;
  // True when native close/quit was requested for this window (used to stop main loop gracefully).
  function IsTerminated:boolean; virtual; abstract;
  procedure ScreenToClient(var p:TPoint); virtual; abstract;
  procedure ClientToScreen(var p:TPoint); virtual; abstract;
  // Sample the OS pointer position for this window and update mousePos
  // in game coordinates. Called once per frame from FrameLoop before
  // FlushMouseInput. If pointer is outside the client area, mousePos is
  // set to the off-screen sentinel ($3FFF,$3FFF).
  procedure SamplePointer; virtual; abstract;
  // Graphics backend lifecycle for this window
  // Create/activate graphics context and initialize backend-facing window surface state.
  procedure InitGraph; virtual; abstract;
  // Create graphics context that shares resources (textures, buffers, shaders) with primary window.
  procedure InitGraphShared(primary:TWindow;mainContextReleased:boolean=false); virtual; abstract;
  // Release graphics context and backend-facing window surface resources.
  procedure DoneGraph; virtual; abstract;
  // Temporarily detach/attach current graphics context (used for shared-context startup sequencing).
  procedure ReleaseGraphContext; virtual;
  procedure ActivateGraphContext; virtual;
  procedure PresentFrame; virtual; abstract;
  function SetVSync(divider:integer):boolean; virtual; abstract;

  // Frame log
  procedure FLog(st:string);

  // Frame processing and scene rendering
  function OnFrame:boolean;
  procedure RenderFrame(var params:TGameSettings; aspectRatio:single;
    drawCursor,drawOverlays:TRenderProc);
  procedure RenderScenes(drawOverlays:TRenderProc);

  // Coordinate transforms between client area and game (render) space
  procedure ClientToGame(var p:TPoint);
  procedure GameToClient(var p:TPoint);

  // Mouse position queries in game coordinates
  function MouseInRect(const r:TRect):boolean; overload;
  function MouseInRect(const r:TRect2):boolean; overload;
  function MouseInRect(x,y,width,height:single):boolean; overload;
  function MouseIsNear(x,y,radius:single):boolean;
  function MouseWasInRect(const r:TRect):boolean; overload;
  function MouseWasInRect(const r:TRect2):boolean; overload;

  // Render area setup
  procedure SetupRenderArea(var params:TGameSettings; aspectRatio:single);

  // Default render target
  procedure InitDefaultRenderTarget(width,height:integer; zbuffer:byte; useDepthTex:boolean);
  function GetDepthBufferTex:TTexture;
  // Blit default RT to backbuffer (called before platform PresentFrame)
  procedure BlitDefaultRT(tintColor:cardinal);
  // Full present cycle: blit dRT + swap + update counters
  procedure PresentRenderedFrame(tintColor:cardinal);

  // Frame capture
  procedure RequestScreenshot(saveAsJpeg:boolean=true);
  procedure RequestFrameCapture(obj:TObject=nil);
  procedure CaptureFrame;
  procedure StartVideoCap(filename:string);
  procedure FinishVideoCap;
 end;

function FindWindowForScene(scene:TGameScene):TWindow;
function FindWindowForUIRoot(root:TObject):TWindow;
function ListWindows:TWindowArray;

implementation
 uses Types, SysUtils, Apus.EventMan, Apus.Lib, Apus.Images, Apus.GfxFormats, Apus.Files,
   {$IFDEF MSWINDOWS}Apus.Clipboard,{$ENDIF}
   {$IFDEF VIDEOCAPTURE}Apus.Engine.VideoCapture,{$ENDIF}
   Apus.Engine.API, Apus.Engine.UIScene,
   Apus.Engine.UITypes, Apus.Engine.TextDraw;

var
 windowHash:TObjectHash;

constructor TWindow.Create(windowName:String8='MainWnd');
 begin
  inherited Create;
  name:=windowName;
  runtimeLock.Init('Window',20);
  ResetFrameTiming;
 end;

destructor TWindow.Destroy;
 begin
  runtimeLock.Cleanup;
  inherited;
 end;

procedure TWindow.SetFrameTiming(startUs,deltaUs:int64);
 begin
  if startUs<0 then startUs:=0;
  if deltaUs<0 then deltaUs:=0;
  // Keep raw high-precision values and update all derived projections in one place.
  frameStartUsValue:=startUs;
  frameDeltaUsValue:=deltaUs;
  frameStartMsValue:=startUs div 1000;
  frameDeltaMsValue:=deltaUs div 1000;
  frameStartSecValue:=startUs*0.000001;
  frameDeltaSecValue:=deltaUs*0.000001;
 end;

procedure TWindow.ResetFrameTiming;
 begin
  SetFrameTiming(0,0);
 end;

class function TWindow.ClassHash:pointer;
 begin
  result:=@windowHash;
 end;

procedure TWindow.Lock(caller:pointer=nil);
 begin
  if caller=nil then
   caller:={$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF};
  runtimeLock.Enter(caller);
 end;

procedure TWindow.Unlock;
 begin
  runtimeLock.Leave;
 end;

procedure TWindow.ReleaseGraphContext;
 begin
 end;

procedure TWindow.ActivateGraphContext;
 begin
 end;

procedure TRenderStats.Reset;
begin
 drawCalls:=0;
 shaderChanges:=0;
 texChanges:=0;
 clipChanges:=0;
 verticesDrawn:=0;
end;

procedure TFrameCapture.Reset;
begin
 singleFrame:=false;
 target:=0;
 data:=nil;
 videoMode:=false;
 videoPath:='';
 capturedName:='';
 capturedTime:=0;
end;

procedure TFrameTiming.Reset;
begin
 frameTimeRingPos:=0;
 frameTimeRingCount:=0;
 lastFrameTimeUs:=0;
 Timer.Start(frameTimer);
 frameTimerReady:=false;
 lastFpsUpdate:=0;
 lastSmoothFpsUpdate:=0;
 idleRedrawAccUs:=0;
 presentSampleAccUs:=0;
 phaseMetrics:=false;
 pendingMsgUs:=0;
 lastMsgUs:=0;
 lastOnFrameUs:=0;
 lastRenderUs:=0;
 lastPresentUs:=0;
 lastSleepUs:=0;
end;

procedure TFrameTiming.PushSample(deltaUs,msgUs,onFrameUs,renderUs,presentUs,sleepUs:integer);
begin
 if deltaUs<0 then deltaUs:=0;
 if msgUs<0 then msgUs:=0;
 if onFrameUs<0 then onFrameUs:=0;
 if renderUs<0 then renderUs:=0;
 if presentUs<0 then presentUs:=0;
 if sleepUs<0 then sleepUs:=0;
 lastFrameTimeUs:=deltaUs;
 lastMsgUs:=msgUs;
 lastOnFrameUs:=onFrameUs;
 lastRenderUs:=renderUs;
 lastPresentUs:=presentUs;
 lastSleepUs:=sleepUs;
 frameTimeRing[frameTimeRingPos]:=deltaUs;
 phaseMsgRing[frameTimeRingPos]:=msgUs;
 phaseOnFrameRing[frameTimeRingPos]:=onFrameUs;
 phaseRenderRing[frameTimeRingPos]:=renderUs;
 phasePresentRing[frameTimeRingPos]:=presentUs;
 phaseSleepRing[frameTimeRingPos]:=sleepUs;
 inc(frameTimeRingPos);
 if frameTimeRingPos>=FRAME_TIME_RING_SIZE then frameTimeRingPos:=0;
 if frameTimeRingCount<FRAME_TIME_RING_SIZE then inc(frameTimeRingCount);
end;

function TFrameTiming.MaxRecentFrameUs(sampleCount:integer):integer;
var
 i,n,idx,v:integer;
begin
 result:=0;
 if frameTimeRingCount<=0 then exit;
 if sampleCount<=0 then sampleCount:=1;
 if sampleCount>frameTimeRingCount then sampleCount:=frameTimeRingCount;
 n:=sampleCount;
 idx:=frameTimeRingPos-1;
 if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 for i:=1 to n do begin
  v:=frameTimeRing[idx];
  if v>result then result:=v;
  dec(idx);
  if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 end;
end;

function TFrameTiming.CalcTrimmedFrameMs(windowUs,minFrames,trimPermille:integer; out avgMs:double):boolean;
var
 i,j,idx,count,trim,n:integer;
 totalUs:int64;
 sample,tmp:integer;
 values:array[0..FRAME_TIME_RING_SIZE-1] of integer;
begin
 result:=false;
 avgMs:=0;
 if frameTimeRingCount<=0 then exit;
 if minFrames<1 then minFrames:=1;
 if trimPermille<0 then trimPermille:=0;
 if trimPermille>450 then trimPermille:=450;

 idx:=frameTimeRingPos-1;
 if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 count:=0;
 totalUs:=0;
 while count<frameTimeRingCount do begin
  sample:=frameTimeRing[idx];
  values[count]:=sample;
  inc(totalUs,sample);
  inc(count);
  if (totalUs>=windowUs) and (count>=minFrames) then break;
  dec(idx);
  if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 end;
 if count<=0 then exit;

 // Insertion sort is enough here because sample count is small.
 for i:=1 to count-1 do begin
  tmp:=values[i];
  j:=i-1;
  while (j>=0) and (values[j]>tmp) do begin
   values[j+1]:=values[j];
   dec(j);
  end;
  values[j+1]:=tmp;
 end;

 trim:=(count*trimPermille) div 1000;
 if trim*2>=count then trim:=0;
 totalUs:=0;
 n:=0;
 for i:=trim to count-trim-1 do begin
  inc(totalUs,values[i]);
  inc(n);
 end;
 if n<=0 then exit;
 avgMs:=totalUs/n/1000.0;
 result:=true;
end;

procedure TFrameTiming.UpdateFps(out fps,smoothFps:single);
const
 FPS_WINDOW_US=200000;
 FPS_MIN_FRAMES=20;
 FPS_TRIM_PERMILLE=100;
 SMOOTH_WINDOW_US=3000000;
 SMOOTH_MIN_FRAMES=60;
 SMOOTH_TRIM_PERMILLE=100;
 FPS_UPDATE_INTERVAL_MS=100; // <=10 updates/sec
 SMOOTH_UPDATE_INTERVAL_MS=500; // <=2 updates/sec
var
 avgMs:double;
 nowTicks:int64;
begin
 nowTicks:=CoreTime.Ticks;
 if nowTicks>=lastFpsUpdate+FPS_UPDATE_INTERVAL_MS then begin
  if CalcTrimmedFrameMs(FPS_WINDOW_US,FPS_MIN_FRAMES,FPS_TRIM_PERMILLE,avgMs) then begin
   if avgMs>0.001 then fps:=1000.0/avgMs else fps:=0;
  end;
  lastFpsUpdate:=nowTicks;
 end;
 if nowTicks>=lastSmoothFpsUpdate+SMOOTH_UPDATE_INTERVAL_MS then begin
  if CalcTrimmedFrameMs(SMOOTH_WINDOW_US,SMOOTH_MIN_FRAMES,SMOOTH_TRIM_PERMILLE,avgMs) then begin
   if avgMs>0.001 then smoothFps:=1000.0/avgMs else smoothFps:=0;
  end else
   smoothFps:=fps;
  lastSmoothFpsUpdate:=nowTicks;
 end;
end;

procedure TWindow.ResetSceneData;
 begin
  SetLength(scenes,0);
  topmostScene:=nil;
 end;

procedure TWindow.AddScene(scene:TGameScene);
 var
  i:integer;
 begin
  if scene=nil then
   raise EError.Create('Cannot add nil scene');
  for i:=low(scenes) to high(scenes) do
   if scenes[i]=scene then
    raise EWarning.Create('Scene already added: '+scene.name);
  i:=length(scenes);
  SetLength(scenes,i+1);
  scenes[i]:=scene;
  scene.ownerWindow:=pointer(self);
 end;

function TWindow.RemoveScene(scene:TGameScene):boolean;
 var
  i,n:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i]=scene then begin
    n:=length(scenes)-1;
    scenes[i]:=scenes[n];
    SetLength(scenes,n);
    if scene.ownerWindow=pointer(self) then scene.ownerWindow:=nil;
    exit(true);
   end;
  result:=false;
 end;

function TWindow.TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
 var
  i:integer;
 begin
  result:=nil;
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then begin
    if fullScreenOnly and not scenes[i].fullscreen then continue;
    if result=nil then
     result:=scenes[i]
    else
     if scenes[i].zorder>result.zorder then result:=scenes[i];
   end;
 end;

procedure TWindow.NotifyScenesModeChanged;
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   scenes[i].ModeChanged;
 end;

procedure TWindow.NotifyScenesMouseMove(mouseX,mouseY:integer);
 begin
  // UI dispatch + gameplay forwarding happen once per window (not per scene)
  DispatchMouseMove(self);
 end;

procedure TWindow.NotifyScenesMouseBtn(c:byte;pressed:boolean);
 begin
  DispatchMouseButton(self,c,pressed);
 end;

procedure TWindow.NotifyScenesMouseWheel(value:integer);
 begin
  DispatchMouseWheel(self,value);
 end;

procedure TWindow.FlushMouseInput;
 var
  changed:boolean;
 begin
  changed:=not mousePos.Equals(oldMousePos);
  if changed then begin
   mouseMovedTime:=CoreTime.Ticks;
   Signal('MOUSE\MOVE',Bits.PackW(word(mousePos.x),word(mousePos.y)));
   screenChanged:=true; // needed if cursor is rendered manually
  end;
  // Run the UI move dispatch every frame, not only on cursor movement: this lets
  // hover transitions fire when UI geometry changes under a still cursor.
  // Must run BEFORE advancing oldMousePos — gameplay scenes read it for the delta.
  DispatchMouseMove(self);
  if changed then oldMousePos:=mousePos;
 end;

procedure TWindow.NotifyScenesResize;
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   scenes[i].onResize;
 end;

procedure TWindow.DPIChanged(newDPI:integer);
 begin
  screenDPI:=newDPI;
  Log.Msg('DPI changed: %d for window %s',[newDPI,name]);
  Signal('ENGINE\DPICHANGED',newDPI);
 end;

function TWindow.ProcessScenes(deltaTime:integer):boolean;
 var
  i,time,n:integer;
 begin
  result:=false;
  for i:=low(scenes) to high(scenes) do
   if scenes[i].status<>TSceneStatus.ssFrozen then begin
    if scenes[i].frequency>0 then begin
     time:=1000 div scenes[i].frequency;
     inc(scenes[i].accumTime,deltaTime);
     n:=0;
     while scenes[i].accumTime>0 do begin
      result:=scenes[i].Process or result;
      dec(scenes[i].accumTime,time);
      inc(n);
      if n>5 then begin
       scenes[i].accumTime:=0;
       break;
      end;
     end;
    end else
     result:=scenes[i].Process or result;
   end;
 end;

function TWindow.OnFrame:boolean;
var
 i,n:integer;
 deltaTime:integer;
begin
 result:=false;
 DestroyQueuedElements;

 Lock;
 try
  // sort scenes by zOrder
  if high(scenes)>1 then
   for n:=1 to high(scenes) do
    for i:=0 to n-1 do
     if scenes[i+1].zorder>scenes[i].zorder then
      Swap(scenes[i],scenes[i+1],sizeof(scenes[i]));
 finally
  Unlock;
 end;

 Lock;
 try
  // sync UI root order with scene zOrder
  for i:=0 to high(scenes) do
   if (scenes[i] is TUIScene) then
    with scenes[i] as TUIScene do
     if (UI<>nil) then
      ui.order:=scenes[i].zorder;
 finally
  Unlock;
 end;

 // Drain keyboard buffers and dispatch synchronously, before Process.
 // Only the kbd-topmost scene ever has buffered keys (see TGame.KeyPressed),
 // so iterating active scenes naturally respects single-scene keyboard routing.
 for i:=low(scenes) to high(scenes) do
  if scenes[i].IsActive then
   scenes[i].PumpInput(shiftState);

 deltaTime:=integer(frameDeltaMs);
 result:=ProcessScenes(deltaTime);
end;

procedure TWindow.FLog(st:string);
begin
 frameLog:=frameLog+st+#13#10;
end;

procedure TWindow.RenderFrame(var params:TGameSettings; aspectRatio:single;
  drawCursor,drawOverlays:TRenderProc);
var
 i,j,n:integer;
 sc:array[1..50] of TGameScene;
 effect:TSceneEffect;
 deltaTime:integer;
 fl:boolean;
 z:single;
 s:integer;
begin
 if IsTerminated then exit;
 deltaTime:=integer(frameDeltaMs);
 FLog('RF1');

 Lock;
 try
  txt.ClearLink;
  try
   // check if any fullscreen scene covers the entire area
   fl:=true;
   for i:=low(scenes) to high(scenes) do
    if scenes[i].fullscreen and scenes[i].IsActive then fl:=false;
   FLog('Clear '+booltostr(fl));
   if fl then begin
    if params.zbuffer>0 then z:=1 else z:=-1;
    if params.stencil then s:=0 else s:=-1;
    gfx.target.Clear($FF000000,z,s);
   end;
  except
   on e:exception do CriticalError('RFrame1 '+ExceptionMsg(e));
  end;
  FLog('Eff');
  try
   // process effects on all scenes
   for i:=low(scenes) to high(scenes) do
    if scenes[i].effect<>nil then begin
     FLog('Eff on '+scenes[i].ClassName+' is '+scenes[i].effect.ClassName+' : '+
      inttostr(scenes[i].effect.timer)+','+booltostr(scenes[i].effect.done));
     effect:=scenes[i].effect;
     FLog('Eff ret');
     inc(effect.timer,deltaTime);
     if effect.done then begin
      Signal('ENGINE\EffectDone',UIntPtr(scenes[i]));
      effect.Free;
      scenes[i].effect:=nil;
     end;
    end;
  except
   on e:exception do CriticalError('RFrame2 '+ExceptionMsg(e));
  end;

  // sort active scenes by Z order
  FLog('Sorting');
  n:=0;
  try
   for i:=low(scenes) to high(scenes) do
    if scenes[i].IsActive then begin
     ASSERT(n<high(sc),'Too many active scenes');
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
   on e:exception do CriticalError('RFrame3 '+ExceptionMsg(e));
  end;
  if n>0 then topmostScene:=sc[n]
   else topmostScene:=nil;
 finally
  Unlock;
 end;

 gfx.BeginPaint(dRT);
 SetupRenderArea(params,aspectRatio);
 // draw all active scenes
 for i:=1 to n do try
  // draw shadow
  if sc[i].shadowColor<>0 then
   draw.FillRect(0,0,renderWidth,renderHeight,sc[i].shadowColor);

  if not sc[i].gfxInitialized then try
   sc[i].InitGfx;
   sc[i].gfxInitialized:=true;
  except
   on e:Exception do CriticalError('Scene '+sc[i].name+' InitGfx error: '+ExceptionMsg(e));
  end;

  if IsTerminated then exit;
  if sc[i].effect<>nil then begin
   FLog('Drawing eff on '+sc[i].name);
   sc[i].effect.DrawScene;
   FLog('Drawing ret');
  end else begin
   FLog('Drawing '+sc[i].ClassName);
   sc[i].Render;
   FLog('Drawing ret');
  end;
 except
  on e:exception do begin
   if sc[i] is TUIScene then CriticalError('SceneRender '+(sc[i] as TUIScene).name+' error '+ExceptionMsg(e)+' FLog: '+frameLog)
    else CriticalError('SceneRender '+sc[i].ClassName+' error '+ExceptionMsg(e));
   halt;
  end;
 end;

 if Assigned(drawCursor) then drawCursor;
 if Assigned(drawOverlays) then drawOverlays;

 gfx.EndPaint;
 FLog('RDone');
end;

procedure TWindow.RenderScenes(drawOverlays:TRenderProc);
var
 i,j,n:integer;
 sc:array[1..50] of TGameScene;
 fl:boolean;
 oldWindow:TWindow;
begin
 oldWindow:=window;
 window:=self;
 try
  // sort active scenes by Z order
  n:=0;
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then begin
    ASSERT(n<high(sc),'Too many active scenes');
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
  if n>0 then topmostScene:=sc[n]
   else topmostScene:=nil;

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
    CriticalError('Window scene render error: '+ExceptionMsg(e));
  end;
  if Assigned(drawOverlays) then drawOverlays;
 finally
  window:=oldWindow;
 end;
end;

function TWindow.MouseInRect(const r:TRect):boolean;
begin
 result:=PtInRect(r,mousePos);
end;

function TWindow.MouseInRect(const r:TRect2):boolean;
begin
 result:=r.Contains(mousePos);
end;

function TWindow.MouseInRect(x,y,width,height:single):boolean;
begin
 result:=Rect2(x,y,x+width,y+height).Contains(mousePos);
end;

function TWindow.MouseIsNear(x,y,radius:single):boolean;
begin
 result:=mousePos.IsNear(x,y,radius);
end;

function TWindow.MouseWasInRect(const r:TRect):boolean;
begin
 result:=PtInRect(r,oldMousePos);
end;

function TWindow.MouseWasInRect(const r:TRect2):boolean;
begin
 result:=r.Contains(oldMousePos);
end;

procedure TWindow.ClientToGame(var p:TPoint);
begin
 p.X:=round((p.X-displayRect.Left)*renderWidth/(displayRect.Right-displayRect.Left));
 p.Y:=round((p.Y-displayRect.Top)*renderHeight/(displayRect.Bottom-displayRect.Top));
end;

procedure TWindow.GameToClient(var p:TPoint);
begin
 p.X:=round(displayRect.Left+p.X*(displayRect.Right-displayRect.Left)/renderWidth);
 p.Y:=round(displayRect.Top+p.Y*(displayRect.Bottom-displayRect.Top)/renderHeight);
end;

procedure TWindow.SetupRenderArea(var params:TGameSettings; aspectRatio:single);
var
 w,h:integer;
 oldDisplayRect:TRect;
 oldRW,oldRH:integer;
 gfxWasReady:boolean;
begin
 gfxWasReady:=(gfx<>nil) and (gfx.target<>nil);
 if (windowWidth<=0) or (windowHeight<=0) then begin
  GetSize(windowWidth,windowHeight);
  if windowWidth<=0 then windowWidth:=params.width;
  if windowHeight<=0 then windowHeight:=params.height;
 end;

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
 displayRect.Left:=0;
 displayRect.Top:=0;
 displayRect.Right:=w;
 displayRect.Bottom:=h;
 OffsetRect(displayRect,(windowWidth-w) div 2,(windowHeight-h) div 2);

 renderWidth:=params.width;
 renderHeight:=params.height;

 // nothing changed? skip only if gfx was already set up (avoids skipping the first proper
 // viewport setup when displayRect was pre-initialized to prevent ClientToGame div-by-zero).
 if (displayRect=oldDisplayRect) and
    (renderWidth=oldRW) and (renderHeight=oldRH) and gfxWasReady then exit;

 Log.Msg(Format('Set render area: (%d x %d) (%d,%d) -> (%d,%d)',
   [renderWidth,renderHeight,displayRect.Left,displayRect.Top,displayRect.Right,displayRect.Bottom]));
 Signal('ENGINE\BEFORERESIZE');
 NotifyScenesResize;
 Signal('ENGINE\RESIZED');

 if (gfx<>nil) and (gfx.target<>nil) then begin
  gfx.target.Resized(windowWidth,windowHeight);
  w:=displayRect.Width;
  h:=displayRect.Height;
  if dRT=nil then begin
   // rendering directly to the framebuffer
   gfx.target.Viewport(displayRect.Left,windowHeight-displayRect.Bottom,
     w,h,params.width,params.height);
  end else begin
   // rendering to a framebuffer texture
   with params.mode do
    if (displayFitMode in [dfmFullSize,dfmKeepAspectRatio]) and
       (displayScaleMode in [dsmDontScale,dsmScale]) and
       ((dRT.width<>w) or (dRT.height<>h)) then begin
     Log.Msg('Resizing framebuffer');
     gfx.resman.ResizeImage(dRT,w,h);
     if dRTdepth<>nil then
       gfx.resman.ResizeImage(dRTdepth,w,h);
    end;
   gfx.target.Viewport(0,0,dRT.width,dRT.height,params.width,params.height);
  end;
 end;
end;

procedure TWindow.InitDefaultRenderTarget(width,height:integer; zbuffer:byte; useDepthTex:boolean);
var
 flags:cardinal;
begin
 try
  Log.Msg('Default RT');
  if not gfx.config.ShouldUseTextureAsDefaultRT or
     (gfx.config.QueryMaxRTSize<width) then exit;
  Log.Msg('Switching to the modern rendering model');
  flags:=aiRenderTarget;
  if (zbuffer>0) and not useDepthTex then
   flags:=flags+aiDepthBuffer;
  dRT:=AllocImage(width,height,pfRenderTarget,flags,'DefaultRT');
  if useDepthTex then begin
   dRTdepth:=AllocImage(width,height,ipfDepth32f,aiDepthBuffer+aiRenderTarget,'DefaultDepth');
   gfx.resman.AttachDepthBuffer(dRT,dRTdepth);
  end;
 except
  on e:exception do begin
   Log.Force('Error in InitDefaultRenderTarget: '+ExceptionMsg(e));
   SystemMessage('Game engine failure (InitDefaultRenderTarget): '+ExceptionMsg(e));
   Halt;
  end;
 end;
end;

function TWindow.GetDepthBufferTex:TTexture;
begin
 result:=dRTdepth;
end;

procedure TWindow.BlitDefaultRT(tintColor:cardinal);
begin
 if dRT=nil then exit;
 // blit render texture to window backbuffer
 gfx.target.Viewport(0,0,windowWidth,windowHeight,windowWidth,windowHeight);
 gfx.BeginPaint(nil);
 try
  // clear unused bars (not every frame to avoid performance hit)
  if not ((displayRect.Left=0) and (displayRect.Top=0) and
          (displayRect.Right=windowWidth) and (displayRect.Bottom=windowHeight)) and
     ((frameNum mod 5=0) or (frameNum<3)) then gfx.target.Clear($FF000000);
  with displayRect do
   draw.TexturedRect(Left,Top,right-1,bottom-1,dRT,0,0,1,0,1,1,tintColor);
 finally
  gfx.EndPaint;
 end;
end;

procedure TWindow.PresentRenderedFrame(tintColor:cardinal);
begin
 BlitDefaultRT(tintColor);
 FLog('Present');
 gfx.PresentFrame;
 inc(frameNum);
 screenChanged:=false;
 timings.idleRedrawAccUs:=0;
 stats.Reset;
end;

procedure TWindow.RequestScreenshot(saveAsJpeg:boolean=true);
begin
 Lock;
 try
  if saveAsJPEG then capture.target:=2
   else capture.target:=3;
  capture.singleFrame:=true;
 finally
  Unlock;
 end;
end;

procedure TWindow.RequestFrameCapture(obj:TObject=nil);
begin
 Lock;
 try
  capture.singleFrame:=true;
  capture.target:=0;
  capture.data:=obj;
 finally
  Unlock;
 end;
end;

procedure TWindow.CaptureFrame;
var
 st:string;
 res:ByteArray;
 ext:string;
 img:TBitmapImage;
 r:TRect;
 saveAsJPG:boolean;
begin
 capture.singleFrame:=false;

 r:=displayRect;
 img:=TBitmapImage.Create(r.Width,r.Height,ipfXRGB);
 gfx.CopyFromBackbuffer(0,0,img);
 inc(PByte(img.data),img.width*4*(img.height-1)); // move pointer to the last line
 img.pitch:=-img.width*4; // invert pitch
 case capture.target of
  0:if capture.data<>nil then begin
   Signal('Engine\FrameCaptured',UIntPtr(img));
  end;
  2,3:try
   {$IFDEF OPENGL}
   {$IFDEF MSWINDOWS}
   // overcome windows problem with OpenGL+PrintScreen in fullscreen mode
   PutImageToClipboard(img);
   {$ENDIF}
   {$ENDIF}
   if not DirectoryExists('Screenshots') then
    CreateDir('Screenshots');
   saveAsJPG:=capture.target=2;
   if saveAsJpg then ext:='.jpg' else ext:='.png';
   st:='Screenshots'+PathSeparator+FormatDateTime('yymmdd_hhnnss',Now)+ext;
   if saveAsJpg then
    SaveJPEG(img,st,95)
   else begin
    res:=SavePNG(img);
    Files.WriteBlock(st,@res[0],length(res),0);
   end;
   capture.capturedName:=st;
   capture.capturedTime:=CoreTime.Ticks;
   if game<>nil then game.FireMessage('{B}Screenshot taken{/B}:~'+st,msgSuccess); // green transient toast, bold title
  except
   on e:Exception do Log.Force('Error saving screenshot: '+ExceptionMsg(e));
  end;
 end;
end;

procedure TWindow.StartVideoCap(filename:string);
begin
 {$IFDEF VIDEOCAPTURE}
 if capture.videoMode then exit;
 capture.videoMode:=true;
 if pos('\',filename)=0 then filename:=capture.videoPath+filename;
 StartVideoCapture(game,filename);
 {$ENDIF}
end;

procedure TWindow.FinishVideoCap;
begin
 {$IFDEF VIDEOCAPTURE}
 if capture.videoMode then FinishVideoCapture;
 capture.videoMode:=false;
 {$ENDIF}
end;

function FindWindowForScene(scene:TGameScene):TWindow;
 var
  i,j:integer;
  list:TNamedObjects;
  wnd:TWindow;
 begin
  if scene=nil then exit(nil);
  if scene.ownerWindow<>nil then
   exit(TWindow(scene.ownerWindow));
  if mainWindow<>nil then begin
   mainWindow.Lock;
   try
    for j:=0 to high(mainWindow.scenes) do
     if mainWindow.scenes[j]=scene then
      exit(mainWindow);
   finally
    mainWindow.Unlock;
   end;
  end;
  list:=windowHash.ListObjects;
  for i:=0 to high(list) do begin
   if not (list[i] is TWindow) then continue;
   wnd:=list[i] as TWindow;
   if wnd=mainWindow then continue;
   wnd.Lock;
   try
    for j:=0 to high(wnd.scenes) do
     if wnd.scenes[j]=scene then
      exit(wnd);
   finally
    wnd.Unlock;
   end;
  end;
  result:=nil;
 end;

function FindWindowForUIRoot(root:TObject):TWindow;
 var
  i,j:integer;
  list:TNamedObjects;
  wnd:TWindow;
  scene:TGameScene;
 begin
  if root=nil then exit(nil);
  if mainWindow<>nil then begin
   mainWindow.Lock;
   try
    for j:=0 to high(mainWindow.scenes) do begin
     scene:=mainWindow.scenes[j];
     if scene.GetUIRoot=root then
      exit(mainWindow);
    end;
   finally
    mainWindow.Unlock;
   end;
  end;
  list:=windowHash.ListObjects;
  for i:=0 to high(list) do begin
   if not (list[i] is TWindow) then continue;
   wnd:=list[i] as TWindow;
   if wnd=mainWindow then continue;
   wnd.Lock;
   try
    for j:=0 to high(wnd.scenes) do begin
     scene:=wnd.scenes[j];
     if scene.GetUIRoot=root then
      exit(wnd);
    end;
   finally
    wnd.Unlock;
   end;
  end;
  result:=nil;
 end;

function ListWindows:TWindowArray;
 var
  i,n:integer;
  list:TNamedObjects;
 begin
  SetLength(result,0);
  list:=windowHash.ListObjects;
  n:=0;
  SetLength(result,length(list));
  for i:=0 to high(list) do
   if list[i] is TWindow then begin
    result[n]:=list[i] as TWindow;
    inc(n);
   end;
  SetLength(result,n);
 end;

initialization
 windowHash.Init;

finalization
 windowHash.Clear;

end.
