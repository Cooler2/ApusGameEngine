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
  Apus.Classes, Apus.Images, Apus.Engine.Resources;

const
 FRAME_TIME_RING_SIZE=512;

type
 TWindow=class;
 TSceneArray=array of TGameScene;
 TWindowArray=array of TWindow;
 TRenderProc=procedure of object;

 // Deferred call run on a window's own thread (see TWindow.QueueCall)
 TWindowCall=procedure(param:pointer);
 TWindowMethod=procedure of object;
 TWindowQueuedCall=record
  call:TWindowCall;     // either call (with param)...
  method:TWindowMethod; // ...or method
  param:pointer;
 end;

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

 // Hint state of a window (typed access: TUIHint.Current, ShowSimpleHint)
 TWindowHintState=record
  element:TObject;  // hint (TUIHint) shown by the last ShowSimpleHint, nil if none
  area:TRect;       // leaving this area (canvas coordinates) hides the hint
  fastUntil:int64;  // until then element hints pop up faster (right after one was shown)
  showTime:int64;   // when the hint of the element under the mouse is due, 0 - none
  lastText:String8; // hint text of the element under the mouse in the previous frame
 end;

 // Keyboard focus of a window (typed access: FocusedElement, TUIElement.SetFocus/HasFocus)
 TWindowFocusState=record
  element:TObject;   // element with keyboard focus (TUIElement), nil if none
  activeWnd:TObject; // TUIWindow that holds the focus, nil if the focus is outside any
 end;

 // --- Virtual mouse (see TVirtualMouse) ---
 TVirtualMouseOpKind=(
  vmoMode,   // switch the input mode (enable)
  vmoReset,  // cancel the gesture: drop the capture, release the buttons without a click
  vmoMove,   // move the pointer (pos)
  vmoButton  // press or release a button (button, pressed) at the current position
 );
 TVirtualMouseOp=record
  kind:TVirtualMouseOpKind;
  enable:boolean;      // vmoMode: true - virtual input, false - back to the physical one
  pos:TPoint;          // vmoMove: target point
  clientSpace:boolean; // vmoMove: pos is in pixels of the client area, not in the canvas space
  button:byte;         // vmoButton: 1 - left, 2 - right, 3 - middle
  pressed:boolean;     // vmoButton: true - down, false - up
  ticket:int64;        // assigned by TVirtualMouse.Queue
 end;
 TVirtualMouseTicket=(vmtPending,vmtDone,vmtDropped);
 TVirtualMouseTicketRange=record
  lo,hi:int64;
 end;
 // Pointer state applied by the window's thread
 TVirtualMouseState=record
  active:boolean;      // virtual mode is on
  pos:TPoint;          // canvas space; ($3FFF,$3FFF) - outside the canvas
  buttons:byte;        // mbLeft, mbRight, mbMiddle
  under:String8;       // UI element under the pointer: name ('' - none or unnamed)...
  underClass:String8;  // ...and class ('' - none)
  frame:integer;       // window frame of the last applied operation
 end;

 // Virtual mouse of a window (TWindow.virtualMouse): pointer input that does not come from
 // the OS. Operations are queued from any thread; the window's own thread applies them
 // in order, one per frame, through the regular mouse routing (hit-test, hover, capture,
 // clicks), and while the virtual mode is on it ignores the physical pointer and buttons.
 // The object is reference counted and outlives its window: a holder (e.g. a pending
 // Robot API request) never touches the window, and once the window closes every
 // operation not applied yet is dropped and new ones are refused.
 TVirtualMouse=class
 private
  lock:TLock; // a leaf lock: nothing is entered inside
  refCount:integer;
  ownerPtr:pointer; // identity only: the window may be gone
  ownerName:String8;
  ops:array of TVirtualMouseOp;
  opCount:integer;
  issuedTicket:int64; // last ticket issued
  takenTicket:int64; // operation being applied by the window thread (0 - none)
  doneTicket:int64;  // every ticket <= doneTicket is done or dropped
  dropped:array of TVirtualMouseTicketRange; // tickets dropped unapplied
  reqActive:boolean;
  reqButtons:byte;
  activeValue:boolean;
  closedValue:boolean;
  applied:TVirtualMouseState;
  procedure DropQueued; // under lock
  procedure UpdateDone; // under lock
 public
  constructor Create(owner:TWindow);
  procedure AddRef;
  procedure Release; // the last reference frees the object
  // --- Producer side (any thread) ---
  // Returns the ticket of the operation (>0), 0 if the window is closed
  function Queue(op:TVirtualMouseOp):int64;
  function TicketState(ticket:int64):TVirtualMouseTicket;
  // Drop every queued operation not taken by the window yet (their tickets become dropped)
  procedure Cancel;
  // Mode and buttons as they will be once every queued operation is applied
  function RequestedActive:boolean;
  function RequestedButtons:byte;
  function QueuedCount:integer; // operations not completed yet
  function LastTicket:int64; // ticket of the last queued operation (0 - none yet)
  function State:TVirtualMouseState; // last state published by the window's thread
  function IsActive:boolean; inline; // virtual mode is on (as applied by the window)
  function IsClosed:boolean;
  function IsMainWindow:boolean;   // owned by mainWindow
  property windowName:String8 read ownerName;
  // --- Window side (the window's own thread) ---
  function TakeNext(out op:TVirtualMouseOp):boolean;
  procedure Complete(const ticket:int64;const st:TVirtualMouseState);
  procedure SetActive(enable:boolean);
  procedure Close; // the window closes: drop the queue, refuse new operations
 end;

 // Base class for engine windows.
 // Platform-specific subclasses implement abstract methods.
 // Created via ISystemPlatform.CreateWindow.
TWindow=class(TNamedObject)
protected
  class function ClassHash:pointer; override;
private
  // Working surface: accumulated resolver input and cross-thread rebuild requests.
  surfaceInput:TSurfaceInput; // client size, DPI, native insets, render scale
  pendingLock:TLock;   // guards the pending* fields (written by any thread)
  pendingMask:integer; // see psmXXX constants
  pendingClient:TSize;
  pendingDPI:integer;
  pendingInsets:TRect;
  dRTallowed:boolean;  // the default RT may be created for this window
  dRTzbuffer:byte;     // parameters remembered for a deferred/repeated creation
  dRTdepthTex:boolean;
  // Authoritative per-frame timing source: high-precision microseconds.
  frameStartUsValue:int64;
  frameDeltaUsValue:int64;
  // Compatibility projections for legacy code paths that consume ms/sec.
  frameStartMsValue:int64;
  frameDeltaMsValue:int64;
  frameStartSecValue:double;
  frameDeltaSecValue:double;
  // Lifetime and cross-thread entry (see Acquire, Lock, QueueCall, BeginClose)
  ownerThread:TThreadIdent;
  usageCount:integer;   // references taken by Acquire
  closingValue:integer; // 1 once BeginClose was called
  callLock:TLock;       // guards callQueue; a leaf lock: nothing is entered inside
  callQueue:array of TWindowQueuedCall;
  queuedCount:integer;  // length of callQueue, readable without callLock
  function GetClosing:boolean;
  function AddQueuedCall(const c:TWindowQueuedCall):boolean;
  procedure SetupViewport;   // apply the current surface to the graphics backend
  procedure EnsureDefaultRT; // create the default RT if the surface needs one
  procedure UpdateSurfaceRT; // keep the default RT in sync with surface.renderSize
  procedure UpdateScreenScale; // DPI -> uiScale ladder (main window only)
  function FrameSurfaceHeight(src:TFrameSource):integer; // physical height of the readback surface
  procedure ApplyVirtualMouseOp(const op:TVirtualMouseOp);
  procedure CancelMouseGesture; // drop the capture, release the buttons without a click
  procedure DeliverMouseButton(btn:byte;pressed:boolean); // update mouseButtons + dispatch
  function VirtualMouseSnapshot:TVirtualMouseState;
public
  // Working surface (R-31): declared axes + resolved snapshot.
  config:TSurfaceConfig; // runtime authority for this window (a copy of TGameSettings.surface)
  surface:TSurfaceState; // published snapshot; written only by this window's own thread between frames
  presentedGeneration:integer; // surface generation of the last presented frame (see SurfaceSettled)
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
  // Virtual pointer input of this window (see TVirtualMouse). Never nil; owned by the
  // window (holders elsewhere AddRef it). While it is active the physical pointer and
  // buttons are ignored in this window.
  virtualMouse:TVirtualMouse;
  shiftState:byte; // shift keys: aggregate (sscBaseMask) + right-side bits (sscRightMask)
  // bit 0 - pressed, bit 1 - was pressed last frame (01=just pressed, 10=just released)
  keyState:array[0..255] of byte; // indexed by scancode

  // Window state
  active:boolean; // true when window is visible and updated
  paused:boolean; // pause rendering regardless of active state
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
  hint:TWindowHintState; // hint state for this window (see TUIHint.Current)
  focus:TWindowFocusState; // keyboard focus in this window (see FocusedElement)
  deletedUI:array of TObject; // UI elements deleted in this window, freed at frame start (TUIElement.Remove)
  // Frame timing (per-window, read-only from outside):
  // - `*Us` is the single source of truth (high precision)
  // - `*Ms` / `*Sec` are derived values for API compatibility
  property frameStartUs:int64 read frameStartUsValue;
  property frameDeltaUs:int64 read frameDeltaUsValue;
  property frameStartMs:int64 read frameStartMsValue;
  property frameDeltaMs:int64 read frameDeltaMsValue;
  property frameStartSec:double read frameStartSecValue;
  property frameDeltaSec:double read frameDeltaSecValue;

  // Surface shortcuts (read the published snapshot)
  property canvasWidth:integer read surface.canvasSize.cx;   // draw/input space
  property canvasHeight:integer read surface.canvasSize.cy;
  property clientWidth:integer read surface.clientSize.cx;   // native client area
  property clientHeight:integer read surface.clientSize.cy;
  property displayRect:TRect read surface.displayRect;       // picture placement in the client area
  // One canvas unit is not one pixel: a fixed canvas is stretched into the render
  // surface, so it carries the DPI scaling by itself. Everything the engine sizes
  // in canvas units (fonts, overlays, Dp) must be measured with this DPI, not with
  // surface.dpi - otherwise the DPI factor is applied twice.
  function canvasDPI:single; // dots per inch of one canvas unit

  constructor Create(windowName:String8='MainWnd');
  destructor Destroy; override;
  procedure SetFrameTiming(startUs,deltaUs:int64);
  procedure ResetFrameTiming;

  // Window state lock (scene list, UI tree, window UI state): reentrant, no lifetime
  // guarantee, no context switch. Engine code; worker threads use Lock/Unlock.
  procedure LockState(caller:pointer=nil);
  procedure UnlockState;

  // Thread that runs this window's frames - the one that created it (main window too)
  property ownerThreadID:TThreadIdent read ownerThread;
  function IsOwnerThread:boolean;
  // Set once the window starts closing; never cleared. From then on Acquire, Lock and
  // QueueCall fail.
  property closing:boolean read GetClosing;
  // Keep a reference to the window across time or threads: false once it is closing.
  // A raw window pointer kept by another thread without Acquire is unsafe.
  function Acquire:boolean;
  procedure Release;
  // Worker entry: Acquire + LockState + this thread's `window` context. Returns false
  // (holding nothing) if the window is closing. Reentrant. Unlock restores the previous
  // context; an Unlock without a matching successful Lock in this thread does nothing.
  function Lock:boolean;
  procedure Unlock;
  // Run the call on this window's thread at the start of its next frame, under the
  // window lock. Any thread. False if the window is closing: the call will not run and
  // param stays with the caller. Every accepted call runs exactly once - at a frame
  // start or, at the latest, while the window closes (check `closing` there).
  function QueueCall(call:TWindowCall;param:pointer=nil):boolean; overload;
  function QueueCall(method:TWindowMethod):boolean; overload;
  // Engine side of the above
  procedure RunQueuedCalls; // window's thread at frame start; the closer after its thread stopped
  procedure BeginClose;     // first step of closing: refuse new Acquire/Lock/QueueCall
  function WaitReleased(timeoutMs:integer):boolean; // all Acquire references released?
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
  // Mouse input of the platform: a physical button/wheel event (window's thread). Sends
  // MOUSE\BTNDOWN/BTNUP/SCROLL, samples the pointer and dispatches the event; dropped
  // while the virtual mouse is active.
  procedure PlatformMouseButton(btn:byte;pressed:boolean);
  procedure PlatformMouseWheel(delta:integer);
  // Physical button state polled by the frame loop (ignored while the virtual mouse is active)
  procedure SetPolledMouseButtons(buttons:byte);
  // Mouse step of a frame, window's thread under the window lock. Virtual mode: applies
  // the next queued virtual mouse operation, otherwise samples the OS pointer (if
  // physicalPointer). Then dispatches the move (FlushMouseInput) - in the physical mode
  // only when the pointer was sampled.
  procedure FrameMouseInput(physicalPointer:boolean);
  function ProcessScenes(deltaTime:integer):boolean;

  // --- Working surface: rebuild requests (any thread; only stores the request) ---
  procedure RequestResize(const client:TSize); overload;
  procedure RequestResize(width,height:integer); overload;
  procedure RequestDPI(dpi:integer);
  procedure SetNativeSafeArea(const insets:TRect);
  procedure SetRenderScale(scale:single);
  procedure SetSurfaceConfig(const cfg:TSurfaceConfig); // validates, then requests a rebuild
  procedure InvalidateSurface; // force a full rebuild on the next ApplyPendingSurface
  // True when no surface change is waiting and a frame for the current surface
  // generation has already been presented. Frame readback (screenshot, pixel)
  // must wait for this: right after a resize the presented frame is still the old one.
  function SurfaceSettled:boolean;
  // Apply a pending request. Called by the window's OWN thread at frame start:
  // hook -> validate -> resolve -> RT/viewport -> publish snapshot -> notifications.
  procedure ApplyPendingSurface;

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
  // set to the off-screen sentinel ($3FFF,$3FFF). Does nothing while the
  // virtual mouse is active.
  procedure SamplePointer;
  // Platform part of SamplePointer
  procedure SampleOSPointer; virtual; abstract;
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

  // Frame processing and scene rendering. The window thread holds the window lock only on
  // the frame segments that touch window state: input dispatch, queued signals, OnFrame
  // (takes it itself), rendering (RenderFrame takes it around the scene parts, leaving
  // gfx.BeginPaint outside: with vsync the driver may block there; the caller of
  // RenderScenes holds it). Present, sleeping and the OS message pump run outside it.
  function OnFrame:boolean;
  procedure RenderFrame(const params:TGameSettings;
    drawCursor,drawOverlays:TRenderProc);
  procedure RenderScenes(drawOverlays:TRenderProc);

  // Coordinate transforms between client area and canvas (draw/input) space
  function ClientToCanvas(const p:TPoint):TPoint;
  function CanvasToClient(const p:TPoint):TPoint;
  // False when the point is outside displayRect (canvasP is still computed)
  function TryClientToCanvas(const p:TPoint;out canvasP:TPoint):boolean;
  // Pointer sampling contract: a position outside the display rect is dropped
  // (off-screen sentinel) unless a button is held - then it is clamped to the canvas,
  // so a drag started inside never sticks when it leaves the letterbox area.
  function MapPointerToCanvas(const clientPos:TPoint):TPoint;

  // Mouse position queries in game coordinates
  function MouseInRect(const r:TRect):boolean; overload;
  function MouseInRect(const r:TRect2):boolean; overload;
  function MouseInRect(x,y,width,height:single):boolean; overload;
  function MouseIsNear(x,y,radius:single):boolean;
  function MouseWasInRect(const r:TRect):boolean; overload;
  function MouseWasInRect(const r:TRect2):boolean; overload;

  // Default render target
  // Allow a presentation RT for this window and create it if the surface needs one.
  // Without it rendering goes straight to the backbuffer.
  procedure EnableDefaultRT(zbuffer:byte;useDepthTex:boolean);
  procedure InitDefaultRenderTarget(width,height:integer; zbuffer:byte; useDepthTex:boolean);
  function GetDepthBufferTex:TTexture;
  // Blit default RT to backbuffer (called before platform PresentFrame)
  procedure BlitDefaultRT(tintColor:cardinal);
  // Full present cycle: blit dRT + swap + update counters
  procedure PresentRenderedFrame(tintColor:cardinal);

  // Frame readback: canvas space <-> pixels of the surface holding the frame.
  // The backbuffer is read in physical pixels, so a canvas-space region must be
  // mapped first - canvasSize and clientSize differ whenever the canvas is fixed,
  // scaled or letterboxed.
  // Where the picture sits inside that surface, in its own pixels
  function FrameRect(src:TFrameSource=TFrameSource.presented):TRect;
  // Map a canvas-space rect/point into those pixels
  function CanvasToPixels(const r:TRect;src:TFrameSource=TFrameSource.presented):TRect; overload;
  function CanvasToPixels(const p:TPoint;src:TFrameSource=TFrameSource.presented):TPoint; overload;
  // Read a pixel region of the frame into image (its size must match the rect).
  // Rows come out top-down regardless of the source.
  procedure ReadFrameRect(const pixRect:TRect;image:TRawImage;src:TFrameSource=TFrameSource.presented);

  // Frame capture
  procedure RequestScreenshot(saveAsJpeg:boolean=true);
  procedure RequestFrameCapture(obj:TObject=nil);
  procedure CaptureFrame;
  procedure StartVideoCap(filename:string);
  procedure FinishVideoCap;
 end;

// Configuration hook: called on every rebuild, before the resolver.
// Set by TGameApplication (the engine core must not depend on it).
type
 TSurfaceConfigHook=procedure(wnd:TWindow;const input:TSurfaceInput;var config:TSurfaceConfig) of object;
var
 surfaceConfigHook:TSurfaceConfigHook;

function FindWindowByHandle(handle:THandle):TWindow;
function ListWindows:TWindowArray;
// Virtual mouse of an open window: '', '0' or 'main' - the main window, otherwise the
// window name (TWindow.name, case-insensitive). Any thread. The result is AddRef'ed -
// Release it; nil if there is no such window or it is closing.
function FindVirtualMouse(const windowName:String8):TVirtualMouse;

implementation
 uses Types, SysUtils, Apus.EventMan, Apus.Lib, Apus.GfxFormats, Apus.Files, Apus.Strings,
   {$IFDEF MSWINDOWS}Apus.Clipboard,{$ENDIF}
   {$IFDEF VIDEOCAPTURE}Apus.Engine.VideoCapture,{$ENDIF}
   Apus.Engine.API, Apus.Engine.UIScene,
   Apus.Engine.UITypes, Apus.Engine.TextDraw;

const
 // TWindow.pendingMask bits
 psmClient = 1; // client area size changed
 psmDPI    = 2; // system DPI changed
 psmInsets = 4; // native safe-area insets changed
 psmForce  = 8; // rebuild requested explicitly (config/scale change)

 OFF_CANVAS = $3FFF; // mousePos of a pointer outside the canvas

var
 windowHash:TObjectHash;
 // virtual mice of the open windows (see FindVirtualMouse)
 vmRegistry:array of TVirtualMouse;
 vmRegistryLock:TLock;

{ TVirtualMouse }

constructor TVirtualMouse.Create(owner:TWindow);
 var
  n:integer;
 begin
  lock.Init('VirtualMouse',810);
  refCount:=1; // the window's reference
  ownerPtr:=owner;
  ownerName:=owner.name;
  applied.pos:=Types.Point(OFF_CANVAS,OFF_CANVAS);
  vmRegistryLock.Enter;
  try
   n:=length(vmRegistry);
   SetLength(vmRegistry,n+1);
   vmRegistry[n]:=self;
  finally
   vmRegistryLock.Leave;
  end;
 end;

procedure TVirtualMouse.AddRef;
 begin
  Atomic.Inc(refCount);
 end;

procedure TVirtualMouse.Release;
 begin
  if Atomic.Dec(refCount)>0 then exit;
  lock.Cleanup;
  Free;
 end;

function TVirtualMouse.Queue(op:TVirtualMouseOp):int64;
 begin
  lock.Enter;
  try
   if closedValue then exit(0);
   inc(issuedTicket);
   op.ticket:=issuedTicket;
   if opCount>=length(ops) then SetLength(ops,opCount*2+8);
   ops[opCount]:=op;
   inc(opCount);
   UpdateDone;
   case op.kind of
    vmoMode:if op.enable<>reqActive then begin // a mode change ends the gesture
     reqActive:=op.enable;
     reqButtons:=0;
    end;
    vmoReset:reqButtons:=0;
    vmoButton:
     if op.pressed then reqButtons:=reqButtons or (1 shl (op.button-1))
      else reqButtons:=reqButtons and not (1 shl (op.button-1));
   end;
   result:=issuedTicket;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.TicketState(ticket:int64):TVirtualMouseTicket;
 var
  i:integer;
 begin
  lock.Enter;
  try
   if ticket>doneTicket then exit(vmtPending);
   for i:=0 to high(dropped) do
    if (ticket>=dropped[i].lo) and (ticket<=dropped[i].hi) then exit(vmtDropped);
   result:=vmtDone;
  finally
   lock.Leave;
  end;
 end;

// Tickets complete in order: the one being applied (if any), then the queued ones
procedure TVirtualMouse.UpdateDone;
 begin
  if takenTicket<>0 then doneTicket:=takenTicket-1
  else if opCount>0 then doneTicket:=ops[0].ticket-1
  else doneTicket:=issuedTicket;
 end;

procedure TVirtualMouse.DropQueued;
 var
  n:integer;
 begin
  if opCount=0 then exit;
  n:=length(dropped);
  SetLength(dropped,n+1);
  dropped[n].lo:=ops[0].ticket;
  dropped[n].hi:=ops[opCount-1].ticket;
  opCount:=0;
  UpdateDone;
  reqActive:=activeValue;
  reqButtons:=applied.buttons;
 end;

procedure TVirtualMouse.Cancel;
 begin
  lock.Enter;
  try
   DropQueued;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.RequestedActive:boolean;
 begin
  lock.Enter;
  try
   result:=reqActive;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.RequestedButtons:byte;
 begin
  lock.Enter;
  try
   result:=reqButtons;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.QueuedCount:integer;
 begin
  lock.Enter;
  try
   result:=opCount+byte(takenTicket<>0);
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.LastTicket:int64;
 begin
  lock.Enter;
  try
   result:=issuedTicket;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.State:TVirtualMouseState;
 begin
  lock.Enter;
  try
   result:=applied;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.IsActive:boolean;
 begin
  result:=activeValue;
 end;

function TVirtualMouse.IsClosed:boolean;
 begin
  lock.Enter;
  try
   result:=closedValue;
  finally
   lock.Leave;
  end;
 end;

function TVirtualMouse.IsMainWindow:boolean;
 begin
  result:=(ownerPtr<>nil) and (ownerPtr=pointer(mainWindow));
 end;

function TVirtualMouse.TakeNext(out op:TVirtualMouseOp):boolean;
 begin
  if opCount=0 then exit(false); // a racy read is fine: the next frame takes it
  lock.Enter;
  try
   result:=(opCount>0) and (takenTicket=0);
   if not result then exit;
   op:=ops[0];
   dec(opCount);
   if opCount>0 then Move(ops[1],ops[0],opCount*sizeof(ops[0]));
   takenTicket:=op.ticket;
   UpdateDone;
  finally
   lock.Leave;
  end;
 end;

procedure TVirtualMouse.Complete(const ticket:int64;const st:TVirtualMouseState);
 begin
  lock.Enter;
  try
   applied:=st;
   if (ticket=0) or (ticket<>takenTicket) then exit; // state refresh only
   takenTicket:=0;
   UpdateDone;
  finally
   lock.Leave;
  end;
 end;

procedure TVirtualMouse.SetActive(enable:boolean);
 begin
  activeValue:=enable;
 end;

procedure TVirtualMouse.Close;
 var
  i:integer;
 begin
  lock.Enter;
  try
   if closedValue then exit;
   closedValue:=true;
   DropQueued;
   if takenTicket<>0 then begin // the window stops in the middle of an operation
    i:=length(dropped);
    SetLength(dropped,i+1);
    dropped[i].lo:=takenTicket;
    dropped[i].hi:=takenTicket;
    takenTicket:=0;
   end;
   UpdateDone;
   reqActive:=false;
   reqButtons:=0;
   ownerPtr:=nil;
  finally
   lock.Leave;
  end;
  vmRegistryLock.Enter;
  try
   for i:=high(vmRegistry) downto 0 do
    if vmRegistry[i]=self then begin
     vmRegistry[i]:=vmRegistry[high(vmRegistry)];
     SetLength(vmRegistry,high(vmRegistry));
    end;
  finally
   vmRegistryLock.Leave;
  end;
 end;

function FindVirtualMouse(const windowName:String8):TVirtualMouse;
 var
  i:integer;
  main:boolean;
  name:String8;
 begin
  result:=nil;
  name:=windowName.ToLower;
  main:=(name='') or (name='0') or (name='main');
  vmRegistryLock.Enter;
  try
   for i:=0 to high(vmRegistry) do
    if main and vmRegistry[i].IsMainWindow or
       not main and vmRegistry[i].ownerName.Same(name) then begin
     result:=vmRegistry[i];
     result.AddRef;
     exit;
    end;
  finally
   vmRegistryLock.Leave;
  end;
 end;

constructor TWindow.Create(windowName:String8='MainWnd');
 begin
  inherited Create;
  name:=windowName;
  // levels (higher = inner): the window lock is the outermost engine runtime lock,
  // pending surface data and the game object are entered inside it
  runtimeLock.Init('Window',20);
  pendingLock.Init('WndSurface',25);
  callLock.Init('WndCalls',800);
  ownerThread:=GetCurrentThreadID; // windows are created by the thread that runs their frames
  config.Init;
  surfaceInput.Init(0,0,96);
  Mem.Clear(surface,sizeof(surface));
  ResetFrameTiming;
  virtualMouse:=TVirtualMouse.Create(self);
 end;

destructor TWindow.Destroy;
 begin
  DestroyQueuedElements(self); // elements still held by someone are leaked
  virtualMouse.Close;
  virtualMouse.Release;
  virtualMouse:=nil;
  if length(deletedUI)>0 then
   Log.Force('Window %s destroyed with %d held UI elements',[name,length(deletedUI)]);
  callLock.Cleanup;
  pendingLock.Cleanup;
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

procedure TWindow.LockState(caller:pointer=nil);
 begin
  if caller=nil then
   caller:={$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF};
  runtimeLock.Enter(caller);
 end;

procedure TWindow.UnlockState;
 begin
  runtimeLock.Leave;
 end;

threadvar
 // windows entered by this thread through TWindow.Lock (innermost last)
 enteredWindows:array[0..7] of record
  wnd:TWindow;
  depth:integer;
  prevWindow:TWindow; // `window` context to restore
 end;
 enteredCount:integer;

function TWindow.IsOwnerThread:boolean;
 begin
  result:=GetCurrentThreadID=ownerThread;
 end;

function TWindow.GetClosing:boolean;
 begin
  result:=closingValue<>0;
 end;

function TWindow.Acquire:boolean;
 begin
  Atomic.Inc(usageCount);
  // the closer sets the flag first and then waits for usageCount=0
  if closingValue<>0 then begin
   Atomic.Dec(usageCount);
   exit(false);
  end;
  result:=true;
 end;

procedure TWindow.Release;
 begin
  ASSERT(usageCount>0,'Window '+name+': Release without Acquire');
  Atomic.Dec(usageCount);
 end;

function TWindow.Lock:boolean;
 var
  i:integer;
 begin
  for i:=0 to enteredCount-1 do
   if enteredWindows[i].wnd=self then begin
    LockState({$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF});
    inc(enteredWindows[i].depth);
    exit(true);
   end;
  if not Acquire then exit(false);
  LockState({$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF});
  if closing then begin // started closing while we were waiting for the lock
   UnlockState;
   Release;
   exit(false);
  end;
  ASSERT(enteredCount<=high(enteredWindows),'Too many windows entered by one thread');
  with enteredWindows[enteredCount] do begin
   wnd:=self;
   depth:=1;
   prevWindow:=window;
  end;
  inc(enteredCount);
  window:=self;
  result:=true;
 end;

procedure TWindow.Unlock;
 var
  i,j:integer;
 begin
  for i:=enteredCount-1 downto 0 do
   if enteredWindows[i].wnd=self then begin
    UnlockState;
    dec(enteredWindows[i].depth);
    if enteredWindows[i].depth=0 then begin
     window:=enteredWindows[i].prevWindow;
     for j:=i to enteredCount-2 do enteredWindows[j]:=enteredWindows[j+1];
     dec(enteredCount);
     Release;
    end;
    exit;
   end;
  // no matching successful Lock in this thread (e.g. Lock failed while closing): nothing to undo
 end;

function TWindow.AddQueuedCall(const c:TWindowQueuedCall):boolean;
 var
  n:integer;
 begin
  callLock.Enter;
  try
   if closingValue<>0 then exit(false);
   n:=length(callQueue);
   SetLength(callQueue,n+1);
   callQueue[n]:=c;
   queuedCount:=n+1;
   result:=true;
  finally
   callLock.Leave;
  end;
 end;

function TWindow.QueueCall(call:TWindowCall;param:pointer=nil):boolean;
 var
  c:TWindowQueuedCall;
 begin
  ASSERT(Assigned(call));
  c.call:=call;
  c.method:=nil;
  c.param:=param;
  result:=AddQueuedCall(c);
 end;

function TWindow.QueueCall(method:TWindowMethod):boolean;
 var
  c:TWindowQueuedCall;
 begin
  ASSERT(Assigned(method));
  c.call:=nil;
  c.method:=method;
  c.param:=nil;
  result:=AddQueuedCall(c);
 end;

procedure TWindow.RunQueuedCalls;
 var
  calls:array of TWindowQueuedCall;
  i:integer;
 begin
  if queuedCount=0 then exit; // a call queued right now runs next time
  callLock.Enter;
  try
   calls:=callQueue;
   callQueue:=nil;
   queuedCount:=0;
  finally
   callLock.Leave;
  end;
  LockState;
  try
   for i:=0 to high(calls) do
    try
     if Assigned(calls[i].call) then
      calls[i].call(calls[i].param)
     else
      calls[i].method();
    except
     on e:Exception do Log.Error('Window %s: queued call failed: %s',[name,ExceptionMsg(e)]);
    end;
  finally
   UnlockState;
  end;
 end;

procedure TWindow.BeginClose;
 begin
  callLock.Enter; // so that no call is accepted after the final RunQueuedCalls
  try
   Atomic.Exchange(closingValue,1);
  finally
   callLock.Leave;
  end;
  virtualMouse.Close; // pending virtual input is dropped, its holders see that
 end;

function TWindow.WaitReleased(timeoutMs:integer):boolean;
 var
  t:int64;
 begin
  t:=CoreTime.Ticks+timeoutMs;
  while (usageCount>0) and (CoreTime.Ticks<t) do CoreTime.Sleep(1);
  result:=usageCount=0;
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
  LockState;
  try
   for i:=low(scenes) to high(scenes) do
    if scenes[i]=scene then
     raise EWarning.Create('Scene already added: '+scene.name);
   i:=length(scenes);
   SetLength(scenes,i+1);
   scenes[i]:=scene;
   scene.ownerWindow:=pointer(self);
  finally
   UnlockState;
  end;
 end;

function TWindow.RemoveScene(scene:TGameScene):boolean;
 var
  i,n:integer;
 begin
  result:=false;
  LockState;
  try
   for i:=low(scenes) to high(scenes) do
    if scenes[i]=scene then begin
     n:=length(scenes)-1;
     scenes[i]:=scenes[n];
     SetLength(scenes,n);
     if scene.ownerWindow=pointer(self) then scene.ownerWindow:=nil;
     exit(true);
    end;
  finally
   UnlockState;
  end;
 end;

function TWindow.TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
 var
  i:integer;
 begin
  result:=nil;
  LockState;
  try
   for i:=low(scenes) to high(scenes) do
    if scenes[i].IsActive then begin
     if fullScreenOnly and not scenes[i].fullscreen then continue;
     if result=nil then
      result:=scenes[i]
     else
      if scenes[i].zorder>result.zorder then result:=scenes[i];
    end;
  finally
   UnlockState;
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

procedure TWindow.SamplePointer;
 begin
  if not virtualMouse.IsActive then SampleOSPointer;
 end;

procedure TWindow.PlatformMouseButton(btn:byte;pressed:boolean);
 begin
  if virtualMouse.IsActive then exit; // physical input must not interfere
  if pressed then Signal('MOUSE\BTNDOWN',btn) // for external subscribers
   else Signal('MOUSE\BTNUP',btn);
  SamplePointer; // fresh coords for hit-test at click moment
  NotifyScenesMouseBtn(btn,pressed);
 end;

procedure TWindow.PlatformMouseWheel(delta:integer);
 begin
  if virtualMouse.IsActive then exit;
  Signal('MOUSE\SCROLL',delta); // for external subscribers
  SamplePointer;
  NotifyScenesMouseWheel(delta);
 end;

procedure TWindow.SetPolledMouseButtons(buttons:byte);
 begin
  if virtualMouse.IsActive then exit;
  if buttons<>mouseButtons then begin
   oldMouseButtons:=mouseButtons;
   mouseButtons:=buttons;
  end;
 end;

procedure TWindow.FrameMouseInput(physicalPointer:boolean);
 var
  op:TVirtualMouseOp;
  ticket:int64;
 begin
  ticket:=0;
  if virtualMouse.TakeNext(op) then begin
   ticket:=op.ticket;
   try
    ApplyVirtualMouseOp(op);
   except
    on e:Exception do Log.Error('Window %s: virtual mouse operation failed: %s',[name,ExceptionMsg(e)]);
   end;
  end;
  if virtualMouse.IsActive or (ticket<>0) then begin
   // the ticket completes after the move dispatch: the hover is up to date by then
   try
    FlushMouseInput;
   finally
    virtualMouse.Complete(ticket,VirtualMouseSnapshot);
   end;
  end else
  if physicalPointer then begin
   SamplePointer;
   FlushMouseInput;
  end;
 end;

procedure TWindow.ApplyVirtualMouseOp(const op:TVirtualMouseOp);
 var
  p:TPoint;
 begin
  case op.kind of
   vmoMode:
    if op.enable<>virtualMouse.IsActive then begin
     // entering: a physical gesture in progress ends without a click, the pointer
     // starts outside the canvas; leaving: the same for the virtual gesture
     if op.enable then virtualMouse.SetActive(true);
     CancelMouseGesture;
     if not op.enable then virtualMouse.SetActive(false);
    end;
   vmoReset:
    if virtualMouse.IsActive then CancelMouseGesture;
   vmoMove:
    if virtualMouse.IsActive then begin
     if op.clientSpace then
      p:=MapPointerToCanvas(op.pos) // same mapping as the OS pointer
     else begin
      p:=op.pos;
      // same contract as MapPointerToCanvas: off the canvas is "outside" unless a
      // button is held - then the pointer is clamped to the canvas edge
      if (p.x<0) or (p.y<0) or (p.x>=canvasWidth) or (p.y>=canvasHeight) then
       if mouseButtons=0 then
        p:=Types.Point(OFF_CANVAS,OFF_CANVAS)
       else begin
        p.x:=Clamp(p.x,0,Max(0,canvasWidth-1));
        p.y:=Clamp(p.y,0,Max(0,canvasHeight-1));
       end;
     end;
     mousePos:=p;
    end;
   vmoButton:
    if virtualMouse.IsActive and (op.button in [1..5]) then
     DeliverMouseButton(op.button,op.pressed);
  end;
 end;

procedure TWindow.DeliverMouseButton(btn:byte;pressed:boolean);
 var
  bit:byte;
 begin
  bit:=1 shl (btn-1);
  if pressed=((mouseButtons and bit)<>0) then exit; // no transition
  oldMouseButtons:=mouseButtons;
  if pressed then mouseButtons:=mouseButtons or bit
   else mouseButtons:=mouseButtons and not bit;
  if pressed then Signal('MOUSE\BTNDOWN',btn)
   else Signal('MOUSE\BTNUP',btn);
  NotifyScenesMouseBtn(btn,pressed);
 end;

procedure TWindow.CancelMouseGesture;
 var
  btn:byte;
 begin
  CancelMouseCapture(self); // the captor loses it as when it gets hidden
  mousePos:=Types.Point(OFF_CANVAS,OFF_CANVAS);
  FlushMouseInput; // the pointer leaves: hovered and pressed elements reset without a click
  // nothing in the UI is under the pointer now: the releases reach gameplay scenes only
  for btn:=1 to 5 do
   if (mouseButtons and (1 shl (btn-1)))<>0 then DeliverMouseButton(btn,false);
 end;

function TWindow.VirtualMouseSnapshot:TVirtualMouseState;
 var
  e:TUIElement;
 begin
  result.active:=virtualMouse.IsActive;
  result.pos:=mousePos;
  result.buttons:=mouseButtons;
  result.frame:=frameNum;
  e:=underMouse;
  if (e<>nil) and not e.deleted then begin
   result.under:=e.name;
   result.underClass:=String8(e.ClassName);
  end else begin
   result.under:='';
   result.underClass:='';
  end;
 end;

procedure TWindow.NotifyScenesResize;
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   scenes[i].onResize;
 end;

procedure TWindow.RequestResize(const client:TSize);
 begin
  pendingLock.Enter;
  try
   pendingClient:=client;
   pendingMask:=pendingMask or psmClient;
  finally
   pendingLock.Leave;
  end;
 end;

procedure TWindow.RequestResize(width,height:integer);
 begin
  RequestResize(MakeSize(width,height));
 end;

procedure TWindow.RequestDPI(dpi:integer);
 begin
  if dpi<=0 then exit;
  pendingLock.Enter;
  try
   pendingDPI:=dpi;
   pendingMask:=pendingMask or psmDPI;
  finally
   pendingLock.Leave;
  end;
 end;

procedure TWindow.SetNativeSafeArea(const insets:TRect);
 begin
  pendingLock.Enter;
  try
   pendingInsets:=insets;
   pendingMask:=pendingMask or psmInsets;
  finally
   pendingLock.Leave;
  end;
 end;

procedure TWindow.SetRenderScale(scale:single);
 begin
  ASSERT(scale>0,'Render scale must be positive');
  surfaceInput.renderScale:=scale;
  InvalidateSurface;
 end;

procedure TWindow.SetSurfaceConfig(const cfg:TSurfaceConfig);
 begin
  ValidateSurfaceConfig(cfg); // reject a broken declaration where it is made
  config:=cfg;
  InvalidateSurface;
 end;

procedure TWindow.InvalidateSurface;
 begin
  pendingLock.Enter;
  try
   pendingMask:=pendingMask or psmForce;
  finally
   pendingLock.Leave;
  end;
 end;

function TWindow.SurfaceSettled:boolean;
 begin
  pendingLock.Enter;
  try
   result:=pendingMask=0;
  finally
   pendingLock.Leave;
  end;
  result:=result and (presentedGeneration=surface.generation);
 end;

procedure TWindow.ApplyPendingSurface;
 var
  mask:integer;
  cfg:TSurfaceConfig;
  newState:TSurfaceState;
  w,h:integer;
  oldWindow:TWindow;
 begin
  pendingLock.Enter;
  try
   mask:=pendingMask;
   pendingMask:=0;
   if mask and psmClient<>0 then surfaceInput.clientSize:=pendingClient;
   if mask and psmDPI<>0 then surfaceInput.dpi:=pendingDPI;
   if mask and psmInsets<>0 then surfaceInput.safeInsets:=pendingInsets;
  finally
   pendingLock.Leave;
  end;
  if (mask=0) and (surface.generation>0) then exit;

  if (surfaceInput.clientSize.cx<=0) or (surfaceInput.clientSize.cy<=0) then begin
   GetSize(w,h); // some platforms report the client size only after the first message pump
   if (w<=0) or (h<=0) then exit; // nothing to resolve yet
   surfaceInput.clientSize:=MakeSize(w,h);
  end;
  if surfaceInput.dpi<=0 then surfaceInput.dpi:=96;
  if surfaceInput.renderScale<=0 then surfaceInput.renderScale:=1;
  surfaceInput.forceRT:=false; // presentation shader hook: stage E

  cfg:=config;
  if Assigned(surfaceConfigHook) then surfaceConfigHook(self,surfaceInput,cfg);
  ValidateSurfaceConfig(cfg);
  ResolveSurface(surfaceInput,cfg,newState);
  newState.generation:=surface.generation+1;
  newState.changes:=newState.Diff(surface);
  surface:=newState;

  EnsureDefaultRT;
  UpdateSurfaceRT;
  SetupViewport;
  if (surface.generation>1) and (surface.changes=[]) then exit; // forced pass, nothing really changed

  Log.Msg('Surface [%s]: %s',[name,surface.ToString]);
  UpdateScreenScale;
  oldWindow:=window;
  window:=self; // scene callbacks expect the threadvar to point at their own window
  try
   NotifyScenesResize;
  finally
   window:=oldWindow;
  end;
  Signal('ENGINE\SURFACECHANGED',UIntPtr(self));
  screenChanged:=true;
 end;

procedure TWindow.UpdateScreenScale;
 var
  baseDPI:integer;
  scale:single;
 begin
  if (game=nil) or (self<>mainWindow) then exit;
  // The uiScale ladder is only meaningful when the canvas follows the surface:
  // over a fixed canvas the design already defines its own scale (R-31 8.3.3).
  if not config.CanvasFlexible then begin
   game.screenScale:=1.0;
   exit;
  end;
  baseDPI:=96;
  {$IF DEFINED(ANDROID) OR DEFINED(IOS)}
  baseDPI:=192;
  {$ENDIF}
  scale:=1.0;
  if surface.dpi>0.95*baseDPI*1.2 then scale:=1.2;
  if surface.dpi>0.94*baseDPI*1.5 then scale:=1.5;
  if surface.dpi>0.93*baseDPI*2.0 then scale:=2.0;
  if surface.dpi>0.92*baseDPI*2.5 then scale:=2.5;
  game.screenScale:=scale;
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
 // one segment: queued deletions, scene order, keyboard and Process all touch window state
 LockState;
 try
  DestroyQueuedElements(self);
  // sort scenes by zOrder
  if high(scenes)>1 then
   for n:=1 to high(scenes) do
    for i:=0 to n-1 do
     if scenes[i+1].zorder>scenes[i].zorder then
      Swap(scenes[i],scenes[i+1],sizeof(scenes[i]));

  // sync UI root order with scene zOrder
  for i:=0 to high(scenes) do
   if (scenes[i] is TUIScene) then
    with scenes[i] as TUIScene do
     if (UI<>nil) then
      ui.order:=scenes[i].zorder;

  // Drain keyboard buffers and dispatch synchronously, before Process.
  // Only the kbd-topmost scene ever has buffered keys (see TGame.KeyPressed),
  // so iterating active scenes naturally respects single-scene keyboard routing.
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then
    scenes[i].PumpInput(shiftState);

  deltaTime:=integer(frameDeltaMs);
  result:=ProcessScenes(deltaTime);
 finally
  UnlockState;
 end;
end;

procedure TWindow.FLog(st:string);
begin
 frameLog:=frameLog+st+#13#10;
end;

procedure TWindow.RenderFrame(const params:TGameSettings;
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

 LockState;
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
 finally
  UnlockState;
 end;

 // outside the window lock: with vsync the driver may block here until a buffer is free
 gfx.BeginPaint(dRT);
 SetupViewport;
 LockState; // scene list and UI tree are read from here to the end of drawing
 try
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

  // draw all active scenes
  for i:=1 to n do try
   // draw shadow
   if sc[i].shadowColor<>0 then
    draw.FillRect(0,0,canvasWidth,canvasHeight,sc[i].shadowColor);

   if not sc[i].gfxInitialized then try
    sc[i].InitGfx;
    sc[i].gfxInitialized:=true;
   except
    on e:Exception do CriticalError('Scene '+sc[i].name+' InitGfx error: '+ExceptionMsg(e));
   end;

   if IsTerminated then exit;
   if sc[i].effect<>nil then begin
    FLog('Drawing eff on '+sc[i].name);
    sc[i].effect.Paint;
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
 finally
  UnlockState;
 end;

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
  SetupViewport; // backend state is shared between windows - re-assert ours every frame
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
    sc[i].effect.Paint
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

function TWindow.ClientToCanvas(const p:TPoint):TPoint;
begin
 if surface.generation=0 then exit(p); // surface not resolved yet
 result:=surface.ClientToCanvas(p);
end;

function TWindow.CanvasToClient(const p:TPoint):TPoint;
begin
 if surface.generation=0 then exit(p);
 result:=surface.CanvasToClient(p);
end;

function TWindow.TryClientToCanvas(const p:TPoint;out canvasP:TPoint):boolean;
begin
 if surface.generation=0 then begin
  canvasP:=p;
  exit(false);
 end;
 result:=surface.TryClientToCanvas(p,canvasP);
end;

function TWindow.MapPointerToCanvas(const clientPos:TPoint):TPoint;
var
 p:TPoint;
begin
 if not TryClientToCanvas(clientPos,p) then begin
  if mouseButtons=0 then exit(Types.Point($3FFF,$3FFF));
  p.x:=Clamp(p.x,0,Max(0,canvasWidth-1));
  p.y:=Clamp(p.y,0,Max(0,canvasHeight-1));
 end;
 result:=p;
end;

procedure TWindow.EnableDefaultRT(zbuffer:byte;useDepthTex:boolean);
begin
 dRTallowed:=true;
 dRTzbuffer:=zbuffer;
 dRTdepthTex:=useDepthTex;
 EnsureDefaultRT;
end;

// The presentation RT exists only while the surface needs one (fixed render size,
// render scale or a present shader). An RT that is no longer needed is kept: it
// still renders correctly, just with an extra blit.
procedure TWindow.EnsureDefaultRT;
begin
 if (dRT<>nil) or not dRTallowed or not surface.needRT then exit;
 if surface.generation=0 then exit;
 InitDefaultRenderTarget(surface.renderSize.cx,surface.renderSize.cy,dRTzbuffer,dRTdepthTex);
end;

// Keep the default render target sized as the surface demands (renderSize).
procedure TWindow.UpdateSurfaceRT;
begin
 if dRT=nil then exit;
 if (gfx=nil) or (gfx.resman=nil) then exit;
 if (dRT.width=surface.renderSize.cx) and (dRT.height=surface.renderSize.cy) then exit;
 Log.Msg('Resizing framebuffer: %d x %d',[surface.renderSize.cx,surface.renderSize.cy]);
 gfx.resman.ResizeImage(dRT,surface.renderSize.cx,surface.renderSize.cy);
 if dRTdepth<>nil then
  gfx.resman.ResizeImage(dRTdepth,surface.renderSize.cx,surface.renderSize.cy);
end;

// Push the current surface into the graphics backend. Cheap and idempotent:
// called on every rebuild and once per frame (the backend state is shared between windows).
procedure TWindow.SetupViewport;
begin
 if (gfx=nil) or (gfx.target=nil) then exit;
 if surface.generation=0 then exit;
 gfx.target.Resized(surface.clientSize.cx,surface.clientSize.cy);
 if dRT=nil then
  // rendering directly to the framebuffer
  gfx.target.Viewport(surface.displayRect.Left,surface.clientSize.cy-surface.displayRect.Bottom,
    surface.displayRect.Width,surface.displayRect.Height,surface.canvasSize.cx,surface.canvasSize.cy)
 else
  // rendering to a framebuffer texture
  gfx.target.Viewport(0,0,dRT.width,dRT.height,surface.canvasSize.cx,surface.canvasSize.cy);
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
 gfx.target.Viewport(0,0,clientWidth,clientHeight,clientWidth,clientHeight);
 gfx.BeginPaint(nil);
 try
  // clear unused bars (not every frame to avoid performance hit)
  if not ((displayRect.Left=0) and (displayRect.Top=0) and
          (displayRect.Right=clientWidth) and (displayRect.Bottom=clientHeight)) and
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
 presentedGeneration:=surface.generation; // the presented frame matches this surface
 screenChanged:=false;
 timings.idleRedrawAccUs:=0;
 stats.Reset;
end;

// One canvas unit covers renderSize/canvasSize real pixels, so it is that much
// "coarser" than a physical pixel and its own DPI is that much lower. Over a
// flexible canvas the ratio is 1 and this is plain surface.dpi.
function TWindow.canvasDPI:single;
begin
 result:=surface.dpi;
 if (surface.canvasSize.cx>0) and (surface.renderSize.cx>0) then
  result:=result*surface.canvasSize.cx/surface.renderSize.cx;
 if result<=0 then result:=96; // surface is not resolved yet
end;

function TWindow.FrameRect(src:TFrameSource=TFrameSource.presented):TRect;
begin
 // While rendering, the picture occupies the whole presentation RT (if there is one);
 // in the backbuffer it always sits in the display rect.
 if (src=TFrameSource.rendering) and (dRT<>nil) then
  result:=Rect(0,0,dRT.width,dRT.height)
 else
  result:=surface.displayRect;
end;

// Full height of the surface being read - glReadPixels counts rows from its bottom
function TWindow.FrameSurfaceHeight(src:TFrameSource):integer;
begin
 if (src=TFrameSource.rendering) and (dRT<>nil) then result:=dRT.height
  else result:=surface.clientSize.cy;
end;

function TWindow.CanvasToPixels(const r:TRect;src:TFrameSource=TFrameSource.presented):TRect;
var
 pic:TRect;
begin
 pic:=FrameRect(src);
 ASSERT((surface.canvasSize.cx>0) and (surface.canvasSize.cy>0),'Canvas is not resolved yet');
 result.Left:=pic.Left+round(r.Left*pic.Width/surface.canvasSize.cx);
 result.Right:=pic.Left+round(r.Right*pic.Width/surface.canvasSize.cx);
 result.Top:=pic.Top+round(r.Top*pic.Height/surface.canvasSize.cy);
 result.Bottom:=pic.Top+round(r.Bottom*pic.Height/surface.canvasSize.cy);
end;

function TWindow.CanvasToPixels(const p:TPoint;src:TFrameSource=TFrameSource.presented):TPoint;
var
 pic:TRect;
begin
 pic:=FrameRect(src);
 ASSERT((surface.canvasSize.cx>0) and (surface.canvasSize.cy>0),'Canvas is not resolved yet');
 result.x:=pic.Left+round(p.x*pic.Width/surface.canvasSize.cx);
 result.y:=pic.Top+round(p.y*pic.Height/surface.canvasSize.cy);
end;

procedure TWindow.ReadFrameRect(const pixRect:TRect;image:TRawImage;src:TFrameSource=TFrameSource.presented);
begin
 ASSERT((image.width=pixRect.Width) and (image.height=pixRect.Height),'Image size must match the rect');
 gfx.CopyFromBackbuffer(pixRect.Left,FrameSurfaceHeight(src)-pixRect.Bottom,image);
end;

procedure TWindow.RequestScreenshot(saveAsJpeg:boolean=true);
begin
 LockState;
 try
  if saveAsJPEG then capture.target:=2
   else capture.target:=3;
  capture.singleFrame:=true;
 finally
  UnlockState;
 end;
end;

procedure TWindow.RequestFrameCapture(obj:TObject=nil);
begin
 LockState;
 try
  capture.singleFrame:=true;
  capture.target:=0;
  capture.data:=obj;
 finally
  UnlockState;
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

 r:=FrameRect; // the presented picture, in client pixels (may be offset by letterboxing)
 img:=TBitmapImage.Create(r.Width,r.Height,ipfXRGB);
 ReadFrameRect(r,img);
 if capture.target=0 then begin
  // ownership of the image passes to the receiver of the signal
  if capture.data<>nil then Signal('Engine\FrameCaptured',UIntPtr(img))
   else img.Free;
  exit;
 end;
 try
  case capture.target of
   2,3:try
    {$IFDEF OPENGL}
    {$IFDEF MSWINDOWS}
    // overcome windows problem with OpenGL+PrintScreen in fullscreen mode
    PutImageToClipboard(img);
    {$ENDIF}
    {$ENDIF}
    saveAsJPG:=capture.target=2;
    if saveAsJpg then ext:='.jpg' else ext:='.png';
    // relative name: the file system decides where it lands, and creates the
    // directory there - checking for it here would test the wrong place
    st:='Screenshots'+PathSeparator+FormatDateTime('yymmdd_hhnnss',Now)+ext;
    if saveAsJpg then
     SaveJPEG(img,st,95)
    else begin
     res:=SavePNG(img);
     Files.Save(st,res);
    end;
    capture.capturedName:=st;
    capture.capturedTime:=CoreTime.Ticks;
    if game<>nil then game.FireMessage('{B}Screenshot taken{/B}:~'+st,msgSuccess); // green transient toast, bold title
   except
    on e:Exception do begin
     Log.Force('Error saving screenshot: '+ExceptionMsg(e));
     // a screenshot is a user action: it must report its own failure, not leave it in the log
     if game<>nil then game.FireMessage('{B}Screenshot failed{/B}:~'+String8(ExceptionMsg(e)),msgError);
    end;
   end;
  end;
 finally
  img.Free;
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

function FindWindowByHandle(handle:THandle):TWindow;
 var
  item:TWindow;
 begin
  for item in ListWindows do
   if item.GetHandle=handle then exit(item);
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
 vmRegistryLock.Init('VirtualMice',805);

finalization
 windowHash.Clear;

end.
