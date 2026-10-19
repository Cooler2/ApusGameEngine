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
  Apus.Classes, Apus.Images, Apus.Engine.Resources, Apus.Engine.Keys;

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
 TWindowQueuedCalls=array of TWindowQueuedCall;

 {$SCOPEDENUMS ON}
 TWindowState=(Normal,Minimized,Maximized); // state of a window in the window modes
 {$SCOPEDENUMS OFF}
 // App-drawn frame: part of the window at a canvas point (see TWindow.frameHitTest)
 TWindowHitTest=function(x,y:integer):TWindowArea of object;
 // Limits of the client size the user can resize the window to, canvas units: 0 - no limit
 TWindowSizeLimits=procedure(out minSize,maxSize:TSize) of object;

 TFrameCapture=record
  singleFrame:boolean; // request frame capture
  // 0 - keep in data, 2 - save as JPEG, 3 - save as PNG
  target:integer;
  data:TObject;
  capturedName:string;
  capturedTime:int64;
  procedure Reset;
  // Requests: capture the next presented frame (under the window lock)
  procedure RequestScreenshot(saveAsJpeg:boolean); // save to Screenshots\ and copy to the clipboard
  procedure RequestFrame(obj:TObject); // obj<>nil: send the image with Engine\FrameCaptured
  // Serve the request: the window's thread, after the frame is presented
  procedure Capture(wnd:TWindow);
 end;

 // Per-frame diagnostic log: what the frame has done so far (saved on a crash)
 TFrameLog=record
  current:string;  // this frame
  previous:string; // the frame before
  procedure Add(const st:string);
  procedure NextFrame; // current becomes previous
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
  fps,smoothFps:single; // current and smoothed FPS (see UpdateFps)

  procedure Reset;
  procedure PushSample(deltaUs,msgUs,onFrameUs,renderUs,presentUs,sleepUs:integer);
  function MaxRecentFrameUs(sampleCount:integer):integer;
  function CalcTrimmedFrameMs(windowUs,minFrames,trimPermille:integer; out avgMs:double):boolean;
  procedure UpdateFps;
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

 // Surface rebuild requests: stored by any thread, taken by the window's own thread
 // (see TWindow.ApplyPendingSurface)
 TSurfacePending=record
  lock:TLock;   // a leaf lock: nothing is entered inside
  mask:integer; // see psmXXX constants
  client:TSize;
  dpi:integer;
  insets:TRect;
  procedure SetClient(const size:TSize);
  procedure SetDPI(value:integer);
  procedure SetInsets(const r:TRect);
  procedure Force; // full rebuild
  function IsEmpty:boolean;
  // Move the requested values into input and clear the requests; returns the mask taken
  function Take(var input:TSurfaceInput):integer;
 end;

 // Presentation render target of a window (see TWindow.EnableDefaultRT)
 TDefaultRT=record
  allowed:boolean;  // the RT may be created for this window
  zbuffer:byte;     // parameters remembered for a deferred/repeated creation
  depthTex:boolean;
  rt:TTexture;      // nil - rendering goes straight to the backbuffer
  depth:TTexture;   // depth buffer texture (with depthTex)
 end;

 // Calls queued for the window's thread (see TWindow.QueueCall)
 TWindowCallQueue=record
  lock:TLock;     // a leaf lock: nothing is entered inside
  items:TWindowQueuedCalls;
  count:integer;  // length of items, readable without the lock
  closed:boolean; // no calls are accepted any more
  function Add(const c:TWindowQueuedCall):boolean; // false once closed
  function TakeAll:TWindowQueuedCalls;
  procedure Close;
 end;

 // Input frame: the input published to one pass of TWindow.OnFrame. Button transitions
 // are gathered from the events between passes and published at the start of the next.
 TInputFrame=record
  pendingPressed,pendingReleased:byte; // button transitions since the last publication
  pressed,released:byte;  // button transitions of the published frame
  pos,prevPos:TPoint;     // pointer at this and the previous publication
  outside,prevOutside:boolean;
  num:int64;              // publications so far
  procedure AddTransition(bit:byte;down:boolean);
 end;

 // --- Virtual mouse (see TVirtualMouse) ---
 TVirtualMouseOpKind=(
  vmoMode,   // switch the input mode (enable)
  vmoReset,  // cancel the gesture: drop the capture, release the buttons without a click
  vmoMove,   // move the pointer (pos)
  vmoButton, // press or release a button (button, pressed) at the current position
  vmoWheel   // turn the wheel (delta) at the current position
 );
 TVirtualMouseOp=record
  kind:TVirtualMouseOpKind;
  enable:boolean;      // vmoMode: true - virtual input, false - back to the physical one
  pos:TPoint;          // vmoMove: target point
  clientSpace:boolean; // vmoMove: pos is in pixels of the client area, not in the canvas space
  button:byte;         // vmoButton: 1 - left, 2 - right, 3 - middle
  pressed:boolean;     // vmoButton: true - down, false - up
  delta:integer;       // vmoWheel: 120 per notch, positive - away from the user (as MOUSE\SCROLL)
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
  pending:TSurfacePending;
  defaultRT:TDefaultRT;
  // Per-frame timing: high-precision microseconds (ms values are derived)
  frameStartUsValue:int64;
  frameDeltaUsValue:int64;
  // Lifetime and cross-thread entry (see Acquire, Lock, QueueCall, BeginClose)
  ownerThread:TThreadIdent;
  usageCount:integer;   // references taken by Acquire
  closingValue:integer; // 1 once BeginClose was called
  callQueue:TWindowCallQueue;
  runtimeLock:TLock; // the window state lock (see LockState)
  input:TInputFrame;
  pointerOutside:boolean; // the pointer is not over the canvas (mousePos may be clamped to its edge)
  inFrame:boolean; // an OnFrame pass is running
  function GetClosing:boolean;
  function GetFrameStartMs:int64; inline;
  function GetFrameDeltaMs:int64; inline;
  procedure SetupViewport;   // apply the current surface to the graphics backend
  procedure EnsureDefaultRT; // create the default RT if the surface needs one
  procedure UpdateSurfaceRT; // keep the default RT in sync with surface.renderSize
  procedure UpdateScreenScale; // DPI -> uiScale ladder (main window only)
  procedure ApplyVirtualMouseOp(const op:TVirtualMouseOp);
  procedure CancelMouseGesture; // drop the capture, release the buttons without a click
  procedure DeliverMouseButton(btn:byte;pressed:boolean); // update mouseButtons + dispatch
  // Pointer at a canvas position; off the canvas it is outside: the off-canvas sentinel,
  // or clamped to the canvas edge while a button is held (a drag never sticks)
  procedure PlacePointer(const canvasPos:TPoint;onCanvas:boolean);
  procedure PublishInputFrame; // start of an OnFrame pass: publish the input gathered since the last one
  procedure NotifyScenesResize; // the surface changed: TGameScene.onResize of every scene
  procedure DeliverMouseWheel(delta:integer); // MOUSE\SCROLL + dispatch
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
  // UI-dispatch bookkeeping (kept next to mousePos as it's positional state):
  moveKind:TMoveKind; // set by the UI dispatcher before each gameplay onMouseMove call
  mouseOverUI:boolean; // true while the cursor sits over a consuming UI element (prev-frame state)
  mouseButtons:byte; // buttons held now (bit 0=left, 1=right, 2=middle), set by the button events
  // Virtual pointer input of this window (see TVirtualMouse). Never nil; owned by the
  // window (holders elsewhere AddRef it). While it is active the physical pointer and
  // buttons are ignored in this window.
  virtualMouse:TVirtualMouse;
  shiftState:byte; // shift keys: aggregate (sscBaseMask) + right-side bits (sscRightMask)
  // Keys by scancode (Scan.XXX): bit 0 - down now; bit 1 - went down, bit 2 - went up in
  // the published frame (a press shorter than a frame gives both); bits 3, 4 - the same
  // since the publication (internal). Changed by KeyTransition.
  keyState:array[0..Scan.Count-1] of byte;
  keyCodes:array[0..Scan.Count-1] of TKey; // TKey of the held keys
  // Files dropped onto the window from a file manager: the last drop, valid until the
  // next one. Set by the window's thread right before ENGINE\WINDOW\DROPFILES (tag = count).
  droppedFiles:Strings8;
  dropPos:TPoint; // drop point in canvas coordinates; (-1,-1) if the platform does not report it

  // Window state
  active:boolean; // true when window is visible and updated
  state:TWindowState; // set by the platform, changes send ENGINE\WINDOW\MINIMIZED/MAXIMIZED/RESTORED
  frame:TWindowFrame; // frame in effect, set by Configure: System in fullscreen
  // App-drawn frame (frame<>System): which part of the window is at a canvas point - caption
  // (drags the window), edges or client. nil - only the edges resize the window. Called on the
  // window's thread at the mouse polling rate: must be fast. It may take the state lock briefly
  // (TUIWindow does), so the lock must not be held while waiting for the window's thread.
  // Set under LockState (see TUIWindow.BindToWindow)
  frameHitTest:TWindowHitTest;
  // Client size limits for the window modes, asked when the OS needs them (on the window's
  // thread). nil - no limits. Set under LockState
  sizeLimits:TWindowSizeLimits;
  frameNum:integer; // increments every frame
  frameLog:TFrameLog; // per-frame diagnostic log (cleared every frame, saved on error)

 // Per-window data
  renderThread:IThread; // nil for main window, set by AddWindow for extra windows
  timings:TFrameTiming;
  stats:TRenderStats;
  capture:TFrameCapture;
  scenes:TSceneArray;
  topmostScene:TGameScene; // last topmost active scene for this window
  modal:TModalState; // modal dialog state for this window (see TModalStateHelper)
  hint:TWindowHintState; // hint state for this window (see TUIHint.Current)
  focus:TWindowFocusState; // keyboard focus in this window (see FocusedElement)
  deletedUI:array of TObject; // UI elements deleted in this window, freed at frame start (TUIElement.Remove)
  // Frame timing (per-window, read-only from outside): `*Ms` are derived from `*Us`
  property frameStartUs:int64 read frameStartUsValue;
  property frameDeltaUs:int64 read frameDeltaUsValue;
  property frameStartMs:int64 read GetFrameStartMs;
  property frameDeltaMs:int64 read GetFrameDeltaMs;

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

  // windowName - ASCII identifier: letters, digits, '_', '-', '.' (the main window is 'Main')
  constructor Create(const windowName:String8);
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
  // Called once per frame (after ProcessMessages) to update mouse position,
  // emit MOUSE\MOVE signal and notify scenes. Buttons are handled immediately.
  procedure FlushMouseInput;
  // Mouse input of the platform: a physical button/wheel event (window's thread). Samples
  // the pointer (unless the caller has set it: touch), updates mouseButtons, sends
  // MOUSE\BTNDOWN/BTNUP/SCROLL and dispatches the event; dropped while the virtual mouse
  // is active.
  procedure PlatformMouseButton(btn:byte;pressed:boolean;sample:boolean=true);
  procedure PlatformMouseWheel(delta:integer);
  // The platform lost the pointer (the OS capture taken away, focus lost, the window
  // hidden): a physical gesture in progress ends without a click, the held buttons are
  // released (Mouse.WasReleased). Ignored while the virtual mouse is active.
  procedure PlatformCancelGesture;
  // The platform lost the keyboard (focus lost, the window hidden): every held key is
  // released through the regular path (KBD\KEYUP), as if the user let it go
  procedure PlatformReleaseKeys;
  // A key event (window's thread): updates keyState. False for a release of a key that is
  // not down (pressed before the window got the focus): such a release is dropped, the
  // receivers get down/up pairs. Scancode 0 (unknown key) is not tracked.
  function KeyTransition(scanCode:integer;key:TKey;pressed:boolean):boolean;
  // Files dropped by the platform (window's thread): fills droppedFiles/dropPos and
  // sends ENGINE\WINDOW\DROPFILES
  procedure PlatformDropFiles(const files:Strings8;const clientPos:TPoint;hasPos:boolean);
  // Window state reported by the platform (window's thread): sends ENGINE\WINDOW\MINIMIZED,
  // MAXIMIZED or RESTORED (back to normal) when it changes
  procedure PlatformStateChanged(newState:TWindowState);
  // Pointer position from the platform (window's thread). SetPointer maps client pixels
  // to the canvas: outside the display rect the pointer is outside the canvas - the
  // off-canvas sentinel, or clamped to the canvas edge while a button is held, so a drag
  // started inside never sticks. SetPointerOutside - the pointer is not over this window.
  procedure SetPointer(const clientPos:TPoint);
  procedure SetPointerOutside;
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
  procedure Maximize; virtual; abstract;
  procedure Restore; virtual; abstract; // back to normal from the minimized or maximized state
  // The app draws the caption now: frame is Custom, or CustomWhenMaximized and the window is maximized
  function CustomFrameShown:boolean;
  procedure FlashWindow(count:integer); virtual; abstract;
  procedure ProcessMessages; virtual; abstract;
  // True when native close/quit was requested for this window (used to stop main loop gracefully).
  function IsTerminated:boolean; virtual; abstract;
  procedure ScreenToClient(var p:TPoint); virtual; abstract;
  procedure ClientToScreen(var p:TPoint); virtual; abstract;
  // Sample the OS pointer position for this window and update mousePos
  // in game coordinates. Called once per frame from FrameLoop before
  // FlushMouseInput. Does nothing while the virtual mouse is active.
  procedure SamplePointer;
  // Platform part of SamplePointer: reports the pointer through SetPointer/SetPointerOutside
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

  // Default render target
  // Allow a presentation RT for this window and create it if the surface needs one.
  // Without it rendering goes straight to the backbuffer.
  procedure EnableDefaultRT(zbuffer:byte;useDepthTex:boolean);
  procedure InitDefaultRenderTarget(width,height:integer; zbuffer:byte; useDepthTex:boolean);
  function GetDepthBufferTex:TTexture;
  // Blit default RT to backbuffer (called before platform PresentFrame)
  procedure BlitDefaultRT(tintColor:cardinal);
  // Full present cycle: blit the default RT + swap + update counters
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
 end;

 // Pointer of the current thread's window (the `window` threadvar), canvas space:
 // read-only helpers for game code. Re-exported by Apus.Engine.API.
 // A thread without a window is an error (asserted); in a release build its pointer is
 // outside the canvas and every query is false.
 Mouse=record
  class function Pos:TVec2; static; // outside the canvas - ($3FFF,$3FFF)
  class function X:single; static;
  class function Y:single; static;
  // Instant queries: the current state of the window, also inside the event handlers.
  // Position queries are false while the pointer is outside the canvas
  class function InRect(const r:TRect):boolean; overload; static; // right/bottom edges excluded
  class function InRect(const r:TRect2):boolean; overload; static;
  class function InCircle(x,y,radius:single):boolean; static;
  // The pointer is not over the canvas. Pos is then the off-canvas sentinel, or the canvas
  // edge while a button is held (a drag that left the canvas)
  class function Outside:boolean; static;
  // Any of the buttons (mbXXX mask) is held
  class function Down(buttons:byte=mbLeft):boolean; static;
  // Frame queries. A frame is one pass of the window's scene processing (TWindow.OnFrame):
  // the input that came since the previous pass is published at its start. Use them in
  // Process (frequency=0: one call per frame); Render may be skipped, a fixed-rate Process
  // runs 0..N times per frame - take the input from the events there.
  // Any of the buttons went down / up since the previous frame. A click shorter than a
  // frame gives both, with Down false.
  class function WasPressed(buttons:byte=mbLeft):boolean; static;
  class function WasReleased(buttons:byte=mbLeft):boolean; static;
  // The pointer was in the rect at the previous frame (false if it was outside the canvas)
  class function WasInRect(const r:TRect):boolean; overload; static;
  class function WasInRect(const r:TRect2):boolean; overload; static;
  // Over a UI element that takes the input (as of the last hover dispatch)
  class function OverUI:boolean; static;
  // The virtual mouse is in control (see TVirtualMouse)
  class function Simulated:boolean; static;
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
   {$IFDEF MSWINDOWS}Apus.Engine.Clipboard,{$ENDIF}
   Apus.Engine.API, Apus.Engine.UIScene,
   Apus.Engine.UITypes, Apus.Engine.TextDraw;

const
 // TSurfacePending.mask bits
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

function IsValidWindowName(const name:String8):boolean;
 var
  i:integer;
 begin
  result:=name<>'';
  for i:=1 to length(name) do
   if not (name[i] in ['A'..'Z','a'..'z','0'..'9','_','-','.']) then exit(false);
 end;

constructor TWindow.Create(const windowName:String8);
 begin
  inherited Create;
  ASSERT(IsValidWindowName(windowName),'Window name must be an ASCII identifier: '+windowName);
  name:=windowName;
  // levels (higher = inner): the window lock is the outermost engine runtime lock,
  // pending surface data and the game object are entered inside it
  runtimeLock.Init('Window',20);
  pending.lock.Init('WndSurface',25);
  callQueue.lock.Init('WndCalls',800);
  ownerThread:=GetCurrentThreadID; // windows are created by the thread that runs their frames
  config.Init;
  surfaceInput.Init(0,0,96);
  Mem.Clear(surface,sizeof(surface));
  ResetFrameTiming;
  virtualMouse:=TVirtualMouse.Create(self);
  mousePos:=Types.Point(OFF_CANVAS,OFF_CANVAS);
  oldMousePos:=mousePos;
  pointerOutside:=true;
  input.pos:=mousePos;
  input.prevPos:=mousePos;
  input.outside:=true;
  input.prevOutside:=true;
 end;

destructor TWindow.Destroy;
 begin
  DestroyQueuedElements(self); // elements still held by someone are leaked
  virtualMouse.Close;
  virtualMouse.Release;
  virtualMouse:=nil;
  if length(deletedUI)>0 then
   Log.Force('Window %s destroyed with %d held UI elements',[name,length(deletedUI)]);
  callQueue.lock.Cleanup;
  pending.lock.Cleanup;
  runtimeLock.Cleanup;
  inherited;
 end;

procedure TWindow.SetFrameTiming(startUs,deltaUs:int64);
 begin
  if startUs<0 then startUs:=0;
  if deltaUs<0 then deltaUs:=0;
  frameStartUsValue:=startUs;
  frameDeltaUsValue:=deltaUs;
 end;

function TWindow.GetFrameStartMs:int64;
 begin
  result:=frameStartUsValue div 1000;
 end;

function TWindow.GetFrameDeltaMs:int64;
 begin
  result:=frameDeltaUsValue div 1000;
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

{ TWindowCallQueue }

function TWindowCallQueue.Add(const c:TWindowQueuedCall):boolean;
 begin
  lock.Enter;
  try
   if closed then exit(false);
   SetLength(items,count+1);
   items[count]:=c;
   inc(count);
   result:=true;
  finally
   lock.Leave;
  end;
 end;

function TWindowCallQueue.TakeAll:TWindowQueuedCalls;
 begin
  lock.Enter;
  try
   result:=items;
   items:=nil;
   count:=0;
  finally
   lock.Leave;
  end;
 end;

procedure TWindowCallQueue.Close;
 begin
  lock.Enter;
  try
   closed:=true;
  finally
   lock.Leave;
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
  result:=callQueue.Add(c);
 end;

function TWindow.QueueCall(method:TWindowMethod):boolean;
 var
  c:TWindowQueuedCall;
 begin
  ASSERT(Assigned(method));
  c.call:=nil;
  c.method:=method;
  c.param:=nil;
  result:=callQueue.Add(c);
 end;

procedure TWindow.RunQueuedCalls;
 var
  calls:TWindowQueuedCalls;
  i:integer;
 begin
  if callQueue.count=0 then exit; // a call queued right now runs next time
  calls:=callQueue.TakeAll;
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
  Atomic.Exchange(closingValue,1);
  callQueue.Close; // so that no call is accepted after the final RunQueuedCalls
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

procedure TFrameTiming.UpdateFps;
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

procedure TWindow.FlushMouseInput;
 var
  changed:boolean;
 begin
  changed:=not mousePos.Equals(oldMousePos);
  if changed then begin
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

procedure TWindow.PlatformMouseButton(btn:byte;pressed:boolean;sample:boolean=true);
 begin
  if virtualMouse.IsActive then exit; // physical input must not interfere
  if sample then SamplePointer; // fresh coords for hit-test at click moment
  // a press of a button that is still held: its release was lost (the OS capture was
  // taken away) - drop the stale bit so the press is a transition again
  if pressed and (btn in [1..5]) then
   mouseButtons:=mouseButtons and not (1 shl (btn-1));
  DeliverMouseButton(btn,pressed);
 end;

procedure TWindow.PlatformCancelGesture;
 begin
  if virtualMouse.IsActive or (mouseButtons=0) then exit;
  LockState; // the UI capture and hover are dropped
  try
   CancelMouseGesture;
  finally
   UnlockState;
  end;
 end;

procedure TWindow.PlatformReleaseKeys;
 var
  i:integer;
 begin
  for i:=1 to high(keyState) do
   if keyState[i] and 1<>0 then
    Signal('KBD\KEYUP',ord(keyCodes[i])+i shl 16);
 end;

function TWindow.KeyTransition(scanCode:integer;key:TKey;pressed:boolean):boolean;
 begin
  result:=true;
  if (scanCode<=0) or (scanCode>high(keyState)) then exit;
  if pressed then begin
   if keyState[scanCode] and 1=0 then // an auto-repeat is not a new press
    keyState[scanCode]:=keyState[scanCode] or 1 or 8;
   keyCodes[scanCode]:=key;
  end else begin
   if keyState[scanCode] and 1=0 then exit(false);
   keyState[scanCode]:=keyState[scanCode] and $FE or 16;
  end;
 end;

procedure TWindow.PlatformMouseWheel(delta:integer);
 begin
  if virtualMouse.IsActive then exit;
  SamplePointer;
  DeliverMouseWheel(delta);
 end;

procedure TWindow.PlatformDropFiles(const files:Strings8;const clientPos:TPoint;hasPos:boolean);
 begin
  if length(files)=0 then exit;
  droppedFiles:=files;
  if hasPos then dropPos:=ClientToCanvas(clientPos)
   else dropPos:=Types.Point(-1,-1);
  Log.Msg('Window %s: %d file(s) dropped: %s',[name,length(files),files.Join('; ')]);
  Signal('ENGINE\WINDOW\DROPFILES',length(files));
 end;

function TWindow.CustomFrameShown:boolean;
 begin
  result:=(frame=TWindowFrame.Custom) or
   ((frame=TWindowFrame.CustomWhenMaximized) and (state=TWindowState.Maximized));
 end;

procedure TWindow.PlatformStateChanged(newState:TWindowState);
 begin
  if newState=state then exit;
  state:=newState;
  case newState of
   TWindowState.Normal:Signal('ENGINE\WINDOW\RESTORED');
   TWindowState.Minimized:Signal('ENGINE\WINDOW\MINIMIZED');
   TWindowState.Maximized:Signal('ENGINE\WINDOW\MAXIMIZED');
  end;
 end;

procedure TWindow.SetPointer(const clientPos:TPoint);
 var
  p:TPoint;
  onCanvas:boolean;
 begin
  onCanvas:=TryClientToCanvas(clientPos,p);
  PlacePointer(p,onCanvas);
 end;

procedure TWindow.SetPointerOutside;
 begin
  mousePos:=Types.Point(OFF_CANVAS,OFF_CANVAS);
  pointerOutside:=true;
 end;

procedure TWindow.PlacePointer(const canvasPos:TPoint;onCanvas:boolean);
 begin
  pointerOutside:=not onCanvas;
  if onCanvas then
   mousePos:=canvasPos
  else
  if mouseButtons=0 then
   mousePos:=Types.Point(OFF_CANVAS,OFF_CANVAS)
  else begin
   mousePos.x:=Clamp(canvasPos.x,0,Max(0,canvasWidth-1));
   mousePos.y:=Clamp(canvasPos.y,0,Max(0,canvasHeight-1));
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
      SetPointer(op.pos) // same mapping as the OS pointer
     else begin
      p:=op.pos;
      PlacePointer(p,(p.x>=0) and (p.y>=0) and (p.x<canvasWidth) and (p.y<canvasHeight));
     end;
    end;
   vmoButton:
    if virtualMouse.IsActive and (op.button in [1..5]) then
     DeliverMouseButton(op.button,op.pressed);
   vmoWheel:
    if virtualMouse.IsActive and (op.delta<>0) then
     DeliverMouseWheel(op.delta);
  end;
 end;

procedure TWindow.DeliverMouseButton(btn:byte;pressed:boolean);
 var
  bit:byte;
 begin
  // the state changes before anything is told: signal handlers may run immediately
  if btn in [1..5] then begin
   bit:=1 shl (btn-1);
   if pressed=((mouseButtons and bit)<>0) then exit; // no transition
   LockState;
   try
    if pressed then mouseButtons:=mouseButtons or bit
     else mouseButtons:=mouseButtons and not bit;
    input.AddTransition(bit,pressed);
   finally
    UnlockState;
   end;
  end;
  if pressed then Signal('MOUSE\BTNDOWN',btn)
   else Signal('MOUSE\BTNUP',btn);
  DispatchMouseButton(self,btn,pressed); // UI first, then gameplay scenes
 end;

procedure TWindow.DeliverMouseWheel(delta:integer);
 begin
  Signal('MOUSE\SCROLL',delta); // for external subscribers
  DispatchMouseWheel(self,delta);
 end;

procedure TWindow.CancelMouseGesture;
 var
  btn:byte;
 begin
  CancelMouseCapture(self); // the captor loses it as when it gets hidden
  SetPointerOutside;
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

{ TSurfacePending }

procedure TSurfacePending.SetClient(const size:TSize);
 begin
  lock.Enter;
  try
   client:=size;
   mask:=mask or psmClient;
  finally
   lock.Leave;
  end;
 end;

procedure TSurfacePending.SetDPI(value:integer);
 begin
  lock.Enter;
  try
   dpi:=value;
   mask:=mask or psmDPI;
  finally
   lock.Leave;
  end;
 end;

procedure TSurfacePending.SetInsets(const r:TRect);
 begin
  lock.Enter;
  try
   insets:=r;
   mask:=mask or psmInsets;
  finally
   lock.Leave;
  end;
 end;

procedure TSurfacePending.Force;
 begin
  lock.Enter;
  try
   mask:=mask or psmForce;
  finally
   lock.Leave;
  end;
 end;

function TSurfacePending.IsEmpty:boolean;
 begin
  lock.Enter;
  try
   result:=mask=0;
  finally
   lock.Leave;
  end;
 end;

function TSurfacePending.Take(var input:TSurfaceInput):integer;
 begin
  lock.Enter;
  try
   result:=mask;
   mask:=0;
   if result and psmClient<>0 then input.clientSize:=client;
   if result and psmDPI<>0 then input.dpi:=dpi;
   if result and psmInsets<>0 then input.safeInsets:=insets;
  finally
   lock.Leave;
  end;
 end;

procedure TWindow.RequestResize(const client:TSize);
 begin
  pending.SetClient(client);
 end;

procedure TWindow.RequestResize(width,height:integer);
 begin
  RequestResize(MakeSize(width,height));
 end;

procedure TWindow.RequestDPI(dpi:integer);
 begin
  if dpi<=0 then exit;
  pending.SetDPI(dpi);
 end;

procedure TWindow.SetNativeSafeArea(const insets:TRect);
 begin
  pending.SetInsets(insets);
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
  pending.Force;
 end;

function TWindow.SurfaceSettled:boolean;
 begin
  result:=pending.IsEmpty and (presentedGeneration=surface.generation);
 end;

procedure TWindow.ApplyPendingSurface;
 var
  mask:integer;
  cfg:TSurfaceConfig;
  newState:TSurfaceState;
  w,h:integer;
  oldWindow:TWindow;
 begin
  mask:=pending.Take(surfaceInput);
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
  // The uiScale ladder is only meaningful when the canvas follows the surface in display
  // pixels: over a fixed canvas the design already defines its own scale (R-31 8.3.3),
  // over a canvas with its own DPI the projection does the scaling.
  if not config.CanvasFlexible or (config.canvasDPI>0) then begin
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
 // a nested pass (a modal message pump inside a handler) is refused: the outer one owns the frame
 if inFrame then exit;
 inFrame:=true;
 // one segment: queued deletions, scene order, keyboard and Process all touch window state
 LockState;
 try
  PublishInputFrame; // before anything of the frame reads the input
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
  inFrame:=false;
 end;
end;

procedure TWindow.PublishInputFrame;
var
 i:integer;
begin
 ASSERT(IsOwnerThread,'Window '+name+': input frame published by another thread');
 input.prevPos:=input.pos;
 input.prevOutside:=input.outside;
 input.pos:=mousePos;
 input.outside:=pointerOutside;
 input.pressed:=input.pendingPressed;
 input.released:=input.pendingReleased;
 input.pendingPressed:=0;
 input.pendingReleased:=0;
 inc(input.num);
 // keyboard: the transitions since the last publication become the published ones
 for i:=0 to high(keyState) do
  keyState[i]:=keyState[i] and 1 or (keyState[i] and $18) shr 2;
end;

procedure TInputFrame.AddTransition(bit:byte;down:boolean);
begin
 if down then pendingPressed:=pendingPressed or bit
  else pendingReleased:=pendingReleased or bit;
end;

procedure TFrameLog.Add(const st:string);
begin
 current:=current+st+#13#10;
end;

procedure TFrameLog.NextFrame;
begin
 previous:=current;
 current:='';
end;

// Shadows (dimming layers) to draw under the scenes sc[0..n-1], sorted bottom to top.
// A scene draws only the part of its shadow not covered by the shadows above it: the area
// under scene i ends up dimmed by the strongest shadow among scenes i..n-1. A stack of modal
// scenes costs one full-screen fill instead of one per scene, and a shadow fading in or out
// above another one does not make the dimming jump.
procedure GetSceneShadows(const sc:array of TGameScene;n:integer;var shadows:array of cardinal);
var
 i:integer;
 a,top:single; // alpha of this scene's shadow; strongest alpha above it
begin
 top:=0;
 for i:=n-1 downto 0 do begin
  shadows[i]:=0;
  a:=(sc[i].shadowColor shr 24)/255;
  if a<=top then continue;
  shadows[i]:=(sc[i].shadowColor and $FFFFFF) or (cardinal(round(255*(a-top)/(1-top))) shl 24);
  top:=a;
 end;
end;

procedure TWindow.RenderFrame(const params:TGameSettings;
  drawCursor,drawOverlays:TRenderProc);
var
 i,j,n:integer;
 sc:array[1..50] of TGameScene;
 shadows:array[1..50] of cardinal;
 effect:TSceneEffect;
 deltaTime:integer;
 fl:boolean;
 z:single;
 s:integer;
begin
 if IsTerminated then exit;
 deltaTime:=integer(frameDeltaMs);
 frameLog.Add('RF1');

 LockState;
 try
  txt.ClearLink;
  try
   // check if any fullscreen scene covers the entire area
   fl:=true;
   for i:=low(scenes) to high(scenes) do
    if scenes[i].fullscreen and scenes[i].IsActive then fl:=false;
   frameLog.Add('Clear '+booltostr(fl));
   if fl then begin
    if params.zbuffer>0 then z:=1 else z:=-1;
    if params.stencil then s:=0 else s:=-1;
    gfx.target.Clear($FF000000,z,s);
   end;
  except
   on e:exception do CriticalError('RFrame1 '+ExceptionMsg(e));
  end;
  frameLog.Add('Eff');
  try
   // process effects on all scenes
   for i:=low(scenes) to high(scenes) do
    if scenes[i].effect<>nil then begin
     frameLog.Add('Eff on '+scenes[i].ClassName+' is '+scenes[i].effect.ClassName+' : '+
      inttostr(scenes[i].effect.timer)+','+booltostr(scenes[i].effect.done));
     effect:=scenes[i].effect;
     frameLog.Add('Eff ret');
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
 gfx.BeginPaint(defaultRT.rt);
 SetupViewport;
 LockState; // scene list and UI tree are read from here to the end of drawing
 try
  // sort active scenes by Z order
  frameLog.Add('Sorting');
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
  GetSceneShadows(sc,n,shadows);
  for i:=1 to n do try
   if shadows[i]<>0 then
    draw.FillRect(0,0,canvasWidth,canvasHeight,shadows[i]);

   if not sc[i].gfxInitialized then try
    sc[i].InitGfx;
    sc[i].gfxInitialized:=true;
   except
    on e:Exception do CriticalError('Scene '+sc[i].name+' InitGfx error: '+ExceptionMsg(e));
   end;

   if IsTerminated then exit;
   if sc[i].effect<>nil then begin
    frameLog.Add('Drawing eff on '+sc[i].name);
    sc[i].effect.Paint;
    frameLog.Add('Drawing ret');
   end else begin
    frameLog.Add('Drawing '+sc[i].ClassName);
    sc[i].Render;
    frameLog.Add('Drawing ret');
   end;
  except
   on e:exception do begin
    if sc[i] is TUIScene then CriticalError('SceneRender '+(sc[i] as TUIScene).name+' error '+ExceptionMsg(e)+' FLog: '+frameLog.current)
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
 frameLog.Add('RDone');
end;

procedure TWindow.RenderScenes(drawOverlays:TRenderProc);
var
 i,j,n:integer;
 sc:array[1..50] of TGameScene;
 shadows:array[1..50] of cardinal;
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
  GetSceneShadows(sc,n,shadows);
  for i:=1 to n do try
   if shadows[i]<>0 then
    draw.FillRect(0,0,canvasWidth,canvasHeight,shadows[i]);
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

{ Mouse }

// Window of the Mouse queries. A thread without a window is a programmer error;
// in a release build the pointer then counts as outside the canvas.
function MouseWindow:TWindow; inline;
begin
 result:=window;
 ASSERT(result<>nil,'Mouse: this thread has no window');
end;

// The window's pointer is over the canvas
function PointerOnCanvas(wnd:TWindow):boolean; inline;
begin
 result:=(wnd<>nil) and not wnd.pointerOutside;
end;

// The window's pointer was over the canvas at the previous frame
function PointerWasOnCanvas(wnd:TWindow):boolean; inline;
begin
 result:=(wnd<>nil) and not wnd.input.prevOutside;
end;

class function Mouse.Pos:TVec2;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 if wnd<>nil then result:=TVec2.Init(wnd.mousePos)
  else result:=TVec2.Init(OFF_CANVAS,OFF_CANVAS);
end;

class function Mouse.X:single;
begin
 result:=Pos.x;
end;

class function Mouse.Y:single;
begin
 result:=Pos.y;
end;

class function Mouse.InRect(const r:TRect):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=PointerOnCanvas(wnd) and PtInRect(r,wnd.mousePos);
end;

class function Mouse.InRect(const r:TRect2):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=PointerOnCanvas(wnd) and r.Contains(wnd.mousePos);
end;

class function Mouse.InCircle(x,y,radius:single):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=PointerOnCanvas(wnd) and wnd.mousePos.IsNear(x,y,radius);
end;

class function Mouse.Outside:boolean;
begin
 result:=not PointerOnCanvas(MouseWindow);
end;

class function Mouse.Down(buttons:byte=mbLeft):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=(wnd<>nil) and (wnd.mouseButtons and buttons<>0);
end;

class function Mouse.WasPressed(buttons:byte=mbLeft):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=(wnd<>nil) and (wnd.input.pressed and buttons<>0);
end;

class function Mouse.WasReleased(buttons:byte=mbLeft):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=(wnd<>nil) and (wnd.input.released and buttons<>0);
end;

class function Mouse.WasInRect(const r:TRect):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=PointerWasOnCanvas(wnd) and PtInRect(r,wnd.input.prevPos);
end;

class function Mouse.WasInRect(const r:TRect2):boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=PointerWasOnCanvas(wnd) and r.Contains(wnd.input.prevPos);
end;

class function Mouse.OverUI:boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=(wnd<>nil) and wnd.mouseOverUI;
end;

class function Mouse.Simulated:boolean;
var
 wnd:TWindow;
begin
 wnd:=MouseWindow;
 result:=(wnd<>nil) and wnd.virtualMouse.IsActive;
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

procedure TWindow.EnableDefaultRT(zbuffer:byte;useDepthTex:boolean);
begin
 defaultRT.allowed:=true;
 defaultRT.zbuffer:=zbuffer;
 defaultRT.depthTex:=useDepthTex;
 EnsureDefaultRT;
end;

// The presentation RT exists only while the surface needs one (fixed render size,
// render scale or a present shader). An RT that is no longer needed is kept: it
// still renders correctly, just with an extra blit.
procedure TWindow.EnsureDefaultRT;
begin
 if (defaultRT.rt<>nil) or not defaultRT.allowed or not surface.needRT then exit;
 if surface.generation=0 then exit;
 InitDefaultRenderTarget(surface.renderSize.cx,surface.renderSize.cy,defaultRT.zbuffer,defaultRT.depthTex);
end;

// Keep the default render target sized as the surface demands (renderSize).
procedure TWindow.UpdateSurfaceRT;
begin
 if defaultRT.rt=nil then exit;
 if (gfx=nil) or (gfx.resman=nil) then exit;
 if (defaultRT.rt.width=surface.renderSize.cx) and (defaultRT.rt.height=surface.renderSize.cy) then exit;
 Log.Msg('Resizing framebuffer: %d x %d',[surface.renderSize.cx,surface.renderSize.cy]);
 gfx.resman.ResizeImage(defaultRT.rt,surface.renderSize.cx,surface.renderSize.cy);
 if defaultRT.depth<>nil then
  gfx.resman.ResizeImage(defaultRT.depth,surface.renderSize.cx,surface.renderSize.cy);
end;

// Push the current surface into the graphics backend. Cheap and idempotent:
// called on every rebuild and once per frame (the backend state is shared between windows).
procedure TWindow.SetupViewport;
begin
 if (gfx=nil) or (gfx.target=nil) then exit;
 if surface.generation=0 then exit;
 gfx.target.Resized(surface.clientSize.cx,surface.clientSize.cy);
 if defaultRT.rt=nil then
  // rendering directly to the framebuffer
  gfx.target.Viewport(surface.displayRect.Left,surface.clientSize.cy-surface.displayRect.Bottom,
    surface.displayRect.Width,surface.displayRect.Height,surface.canvasSize.cx,surface.canvasSize.cy)
 else
  // rendering to a framebuffer texture
  gfx.target.Viewport(0,0,defaultRT.rt.width,defaultRT.rt.height,surface.canvasSize.cx,surface.canvasSize.cy);
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
  defaultRT.rt:=AllocImage(width,height,pfRenderTarget,flags,'DefaultRT');
  if useDepthTex then begin
   defaultRT.depth:=AllocImage(width,height,ipfDepth32f,aiDepthBuffer+aiRenderTarget,'DefaultDepth');
   gfx.resman.AttachDepthBuffer(defaultRT.rt,defaultRT.depth);
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
 result:=defaultRT.depth;
end;

procedure TWindow.BlitDefaultRT(tintColor:cardinal);
begin
 if defaultRT.rt=nil then exit;
 // blit render texture to window backbuffer
 gfx.target.Viewport(0,0,clientWidth,clientHeight,clientWidth,clientHeight);
 gfx.BeginPaint(nil);
 try
  // clear unused bars (not every frame to avoid performance hit)
  if not ((displayRect.Left=0) and (displayRect.Top=0) and
          (displayRect.Right=clientWidth) and (displayRect.Bottom=clientHeight)) and
     ((frameNum mod 5=0) or (frameNum<3)) then gfx.target.Clear($FF000000);
  with displayRect do
   draw.TexturedRect(Left,Top,right-1,bottom-1,defaultRT.rt,0,0,1,0,1,1,tintColor);
 finally
  gfx.EndPaint;
 end;
end;

procedure TWindow.PresentRenderedFrame(tintColor:cardinal);
begin
 BlitDefaultRT(tintColor);
 frameLog.Add('Present');
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
 if (src=TFrameSource.rendering) and (defaultRT.rt<>nil) then
  result:=Rect(0,0,defaultRT.rt.width,defaultRT.rt.height)
 else
  result:=surface.displayRect;
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
 gfx.CopyFromBackbuffer(pixRect.Left,pixRect.Top,image);
end;

procedure TFrameCapture.RequestScreenshot(saveAsJpeg:boolean);
begin
 if saveAsJPEG then target:=2
  else target:=3;
 singleFrame:=true;
end;

procedure TFrameCapture.RequestFrame(obj:TObject);
begin
 singleFrame:=true;
 target:=0;
 data:=obj;
end;

procedure TFrameCapture.Capture(wnd:TWindow);
var
 st:string;
 res:ByteArray;
 ext:string;
 img:TBitmapImage;
 r:TRect;
 saveAsJPG:boolean;
begin
 singleFrame:=false;

 r:=wnd.FrameRect; // the presented picture, in client pixels (may be offset by letterboxing)
 img:=TBitmapImage.Create(r.Width,r.Height,ipfXRGB);
 wnd.ReadFrameRect(r,img);
 if target=0 then begin
  // ownership of the image passes to the receiver of the signal
  if data<>nil then Signal('Engine\FrameCaptured',UIntPtr(img))
   else img.Free;
  exit;
 end;
 try
  case target of
   2,3:try
    {$IFDEF OPENGL}
    {$IFDEF MSWINDOWS}
    // overcome windows problem with OpenGL+PrintScreen in fullscreen mode
    Clipboard.SetImage(img);
    {$ENDIF}
    {$ENDIF}
    saveAsJPG:=target=2;
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
    capturedName:=st;
    capturedTime:=CoreTime.Ticks;
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
