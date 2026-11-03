// This is the lowest level unit of the Apus Game Engine.
// It should not use any other Engine's units.
//
// Copyright (C) 2026 Apus Software (https://github.com/Cooler2/ApusGameEngine)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
unit Apus.Engine.Types;
interface
 uses Types, Apus.Core, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.VertexLayout;

const
 // Mouse buttons (bit masks; re-exported by Apus.Engine.API)
 mbLeft   = 1;
 mbRight  = 2;
 mbMiddle = 4;

 MAX_FILL_STOPS = 4; // color stops in a TFill gradient

type
 // 2D geometry
 TVec2d = Apus.Geom2D.TVec2d;
 PVec2d = Apus.Geom2D.PVec2d;
 TVec2 = Apus.Geom2D.TVec2;
 PVec2 = Apus.Geom2D.PVec2;
 TVec2Array = Apus.Geom2D.TVec2Array;
 TRect2 = Apus.Geom2D.TRect2;
 PRect2 = Apus.Geom2D.PRect2;
 TMat2d = Apus.Geom2D.TMat2d;
 TMat32d = Apus.Geom2D.TMat32d;
 TMat32 = Apus.Geom2D.TMat32;
 // 3D geometry
 TVec3d = Apus.Geom3D.TVec3d;
 PVec3d = Apus.Geom3D.PVec3d;
 TVec3 = Apus.Geom3D.TVec3;
 PVec3 = Apus.Geom3D.PVec3;
 TVec3Array = Apus.Geom3D.TVec3Array;
 TVec4d = Apus.Geom3D.TVec4d;
 TVec4 = Apus.Geom3D.TVec4;
 PVec4 = Apus.Geom3D.PVec4;
 TQuatd = Apus.Geom3D.TQuatd;
 TQuat = Apus.Geom3D.TQuat;
 TMat3d = Apus.Geom3D.TMat3d;
 TMat3 = Apus.Geom3D.TMat3;
 PMat3 = Apus.Geom3D.PMat3;
 TMat34d = Apus.Geom3D.TMat34d;
 TMat34 = Apus.Geom3D.TMat34;
 PMat34 = Apus.Geom3D.PMat34;
 TMat4d = Apus.Geom3D.TMat4d;
 TMat4 = Apus.Geom3D.TMat4;
 PMat4 = Apus.Geom3D.PMat4;
 TPlane = Apus.Geom3D.TPlane;
 TBox3 = Apus.Geom3D.TBox3;
 PBox3 = Apus.Geom3D.PBox3;

 TAsyncProc = function(param:UIntPtr):integer;

 TVertexComponent = Apus.VertexLayout.TVertexComponent;
 TVertexLayout = Apus.VertexLayout.TVertexLayout;

 TIndices=WordArray;

 // Kind of a mouse-move event delivered to a gameplay scene, set by the UI dispatcher
 // before calling the scene handler (read it via window.moveKind):
 //  mkLeave - cursor just moved from the world onto a consuming UI element (act: stop/hide world cursor)
 //  mkMove  - cursor moved within the world (no UI consuming it) — the only kind that carries a real delta
 //  mkEnter - cursor just returned to the world from UI (no delta — don't apply movement)
 TMoveKind=(mkLeave,mkMove,mkEnter);

 TTextAlignment=(taLeft,      // normal output
                 taCenter,    // output point indicates the text center
                 taRight,     // output point indicates the right edge; use boundary-1 to keep ink before a guide/border line
                 taJustify);  // output point indicates the left edge, while spacing is the line width
                              // (falls back to left-aligned output when actual width is too small or the line ends with #10/#13)
 {$SCOPEDENUMS ON}
 // Where txt.FitText cuts a text that doesn't fit
 TTextCut=(atEnd,     // keep the start: "Long tex…"
           atStart,   // keep the end: "…ong text"
           atMiddle); // keep both ends: "Lon…text" (paths)
 {$SCOPEDENUMS OFF}

 // Display mode
 TDisplayMode=(dmNone,             //< not specified
               dmSwitchResolution, //< Fullscreen: switch to desired display mode (change screen resolution)
               dmFullScreen,       //< Use current resolution with fullscreen window
               dmFixedWindow,      //< Use fixed-size window
               dmWindow);          //< Use resizeable window

 {$SCOPEDENUMS ON}
 // Who draws the caption and the borders of a window in the window modes (no effect in fullscreen)
 TWindowFrame=(System,               //< OS frame and caption
               Custom,               //< no OS frame in any state: the app draws the caption (TWindow.frameHitTest),
                                     //< a resizeable window is resized by its edges
               CustomWhenMaximized); //< no OS frame while maximized (the client covers the work area of its
                                     //< monitor), OS frame otherwise
 // Part of a window under a point, reported for an app-drawn frame (TWindow.frameHitTest)
 TWindowArea=(Client,Caption,Left,Right,Top,Bottom,TopLeft,TopRight,BottomLeft,BottomRight);
 {$SCOPEDENUMS OFF}

 // ---------------------------------------------------------------------------
 // Working surface model (R-31): three author-facing axes (canvas / render / fit)
 // resolved into an immutable per-window state. Pure data + pure functions:
 // no window/graphics dependencies, so the resolver is table-testable.
 // Size convention for both size axes: 0 = "follows the surface".
 // ---------------------------------------------------------------------------
 {$SCOPEDENUMS ON}
 // Axis 3: how the picture is placed into the client area
 TSurfaceFit=(fill,          // whole client area; contentAspect = client aspect
              keepAspect,    // largest rect keeping contentAspect, centered (bars)
              center,        // 1:1 renderSize centered (requires render fixed)
              integerScale); // integer multiple of renderSize, centered (requires render fixed)

 // What the project declares (plus what the configuration hook may override per rebuild)
 TSurfaceConfig=record
  canvasSize:TSize; // axis 1: draw/input space; 0 on an axis = flexible axis
  renderSize:TSize; // axis 2: shaded pixels; (0,0) = native (display rect size); both axes 0 or both >0
  fit:TSurfaceFit;
  allowAspectDistortion:boolean; // default false; the only way to get a non-uniform stretch
  // Flexible canvas only: DPI of the canvas grid. 0 = one canvas unit per display pixel;
  // N>0 = a unit is 1/N inch (96: a "logical pixel"), the projection scales it to the display
  canvasDPI:integer;
  procedure Init; // full-window defaults: canvas(0,0), render native, fill, canvasDPI 0
  function CanvasFixed:boolean; inline;  // both canvas axes fixed
  function CanvasFlexible:boolean; inline; // both canvas axes flexible
  function RenderFixed:boolean; inline;
 end;

 // Everything the window knows about its surface at rebuild time (resolver + hook input)
 TSurfaceInput=record
  clientSize:TSize;   // physical pixels (DPI-aware process is a precondition)
  dpi:integer;
  safeInsets:TRect;   // native safe-area insets in client pixels (desktop: zeros)
  renderScale:single; // -RENDERSCALE dev knob x internal dynamic multiplier; 1.0 by default
  forceRT:boolean;    // a presentation shader is installed -> RT regardless of axes
  procedure Init(width,height:integer;dpi:integer=96);
 end;

 // What changed relative to the previous generation
 TSurfaceChange=(client,canvas,render,placement,safeArea,dpi);
 TSurfaceChanges=set of TSurfaceChange;

 // How canvas coordinates reach the client area (derived, read-only diagnostics)
 TSurfaceMechanism=(direct,  // canvas = render = display rect: no scaling anywhere
                    matrix,  // canvas differs from render: projection matrix scales
                    blit);   // presentation RT blitted into the display rect

 // Which surface holds the frame being read back (see TWindow.ReadFrameRect).
 // Canvas coordinates map differently into each of them, so a readback must say
 // which one it means.
 TFrameSource=(presented,  // default framebuffer: the frame as presented (valid after PresentFrame)
               rendering); // surface being rendered into right now (presentation RT or backbuffer)

 // Immutable surface snapshot; written by the window's own thread between frames.
 // generation/changes are filled by the owner (they describe the transition, not the state).
 TSurfaceState=record
  generation:integer;   // monotonic; first published state = 1
  clientSize:TSize;
  displayRect:TRect;    // picture placement inside the client area (may exceed it: crop)
  renderSize:TSize;     // actually shaded pixels (renderScale applied)
  canvasSize:TSize;     // draw/input space
  safeAreaRect:TRect;   // in canvas coordinates (desktop: whole canvas)
  dpi:integer;
  mechanism:TSurfaceMechanism;
  needRT:boolean;       // presentation RT exists (mechanism=blit)
  changes:TSurfaceChanges; // vs previous generation (first: everything)
  // Coordinate transforms client <-> canvas (raw, no clamping)
  function ClientToCanvas(const p:TPoint):TPoint;
  function CanvasToClient(const p:TPoint):TPoint;
  // False when p is outside displayRect (canvasP is still computed)
  function TryClientToCanvas(const p:TPoint;out canvasP:TPoint):boolean;
  // Change mask relative to a previous state
  function Diff(const prev:TSurfaceState):TSurfaceChanges;
  function ToString:string;
 end;
 {$SCOPEDENUMS OFF}

 // Runtime display/window configuration.
 TGameSettings=record
  title:string;  // window/program title
  width,height:integer; // backbuffer size and desired output area
  colorDepth:integer; // requested backbuffer format (16/24/32)
  refresh:integer;   // display refresh rate (0 - default)
  vSync:integer;     // 0 - max FPS, N - FPS = refresh/N
  mode,altMode:TDisplayMode; // primary and alternate display mode (Alt+Enter)
  altEnter:boolean; // [Alt]+[Enter] switches to altMode (TGame.SwitchToAltSettings does it anyway)
  frame:TWindowFrame; // frame of the window modes
  maximized:boolean; // create the window maximized (dmWindow only); width/height is then the normal size.
                     // Applied once at creation: a fullscreen start goes to the maximized window on [Alt]+[Enter]
  surface:TSurfaceConfig; // working surface axes requested for this window (R-31)
  showSystemCursor:boolean; // draw system cursor instead of engine cursor
  zbuffer:byte; // depth buffer: 0 - none, otherwise 24 bits (the value is not a precision request yet)
  stencil:boolean; // request a stencil-buffer (at least 8-bit)
  multisampling:byte; // full-screen anti-aliasing samples (<2 - disabled)
  slowmotion:boolean; // hint: prefer redraw optimizations for low/unstable frame rates
 end;

 // Packed ARGB color
 TARGBColor=Apus.Colors.TARGBColor;
 PARGBColor=Apus.Colors.PARGBColor;

 // Primitive types
 TPrimitiveType=(
   LINE_LIST,
   LINE_STRIP,
   TRG_FAN,
   TRG_STRIP,
   TRG_LIST);

 TFontHandle=cardinal;

 TColorVector=record
  red,green,blue,alpha:single;
  constructor Init(red,green,blue,alpha:single);
  class function FromColor(color:cardinal;scale:single=1):TColorVector; static;
  function ToQuat:TQuat; inline;
 end;

 TFillKind=(fkNone,    // nothing is drawn
            fkSolid,   // one color: stops[0]
            fkLinear,  // gradient along the line p0 (t=0) -> p1 (t=1)
            fkEdge);   // gradient by the distance from the shape edge
 TFillSpread=(fsPad,fsRepeat,fsReflect); // gradient outside 0..1: clamp, repeat, mirror
 TFillUnits=(fuLocal,     // p0,p1 - 0..1 over the shape bbox
             fuAbsolute,  // p0,p1 - drawing coordinates
             fuAngle);    // p0.x - CSS angle in degrees, the line is derived from the shape bbox

 TFillStop=packed record
  pos:single; // 0..1 along the gradient
  color:cardinal;
 end;

 // What color each point of a shape gets: a solid color or a gradient.
 // A plain value (no managed fields): cheap to copy, pass as const.
 // Gradient colors are interpolated premultiplied (a fade to transparent does not darken).
 TFill=record
  kind:TFillKind;
  spread:TFillSpread;
  units:TFillUnits;
  stopCount:byte;
  // fkLinear: the gradient line p0 (t=0) -> p1 (t=1), in units;
  // fkEdge: p0.x = band width inward from the edge (t=0 at the edge, t=1 at the band end)
  p0,p1:TVec2;
  // optional TTexture: colors from this ramp image (left->right) instead of stops; not owned.
  // Typed as TObject because textures are declared in a higher unit (Apus.Engine.Resources)
  ramp:TObject;
  stops:array[0..MAX_FILL_STOPS-1] of TFillStop;

  class function None:TFill; static;
  class function Solid(color:cardinal):TFill; static;
  // CSS angle: 0 - to top, 90 - to right, 180 - to bottom; the end colors land exactly
  // in the corners at any aspect ratio
  class function Linear(angle:single;c1,c2:cardinal):TFill; overload; static;
  class function Linear(const p0,p1:TVec2;c1,c2:cardinal;units:TFillUnits=fuLocal):TFill; overload; static;
  // color by the distance from the shape edge: bevel, inner glow, cross-section of a frame
  class function Edge(width:single;cEdge,cInner:cardinal):TFill; static;
  function AddStop(pos:single;color:cardinal):TFill; // fluent: TFill.Linear(180,a,b).AddStop(0.5,c)
  function WithRamp(tex:TObject):TFill; // tex: TTexture
  function WithSpread(spread:TFillSpread):TFill;

  function IsVisible:boolean; // not fkNone and some color has alpha>0 (or a ramp is set)
  // CPU evaluation: solid and linear exactly; fkEdge gives its inner (last) color; the ramp is ignored
  function ColorAt(x,y:single;const box:TRect2):cardinal;
  // fkLinear: the gradient line in drawing coordinates for the shape bbox
  procedure GetLine(const box:TRect2;out a,b:TVec2);
  // fkLinear: gradient parameter at the point, before the spread is applied
  function ParamAt(x,y:single;const box:TRect2):single;
  // color at the gradient parameter (spread applied)
  function ColorAtParam(t:single):cardinal;

  // color operations for derived state colors, as Color.Add/Sub/Mix on every stop
  function Add(color:cardinal):TFill;
  function Sub(color:cardinal):TFill;
  function MixWith(color:cardinal;t:single):TFill;
  // alpha of every stop multiplied by k (fades, cross-fade layers); a ramp is not faded
  function Faded(k:single):TFill;
  // style transitions: false if a and b can't be interpolated - the caller cross-fades two draws
  class function Mix(const a,b:TFill;t:single;out r:TFill):boolean; static;
 end;

 // A fill under state blending: the base fill, mixed with every state fill that TFill.Mix can
 // mix, plus cross-fade layers over it for the states it can't (other kind, stop count...)
 TBlendedFill=record
  fill:TFill;                  // the base
  layers:array[0..2] of TFill; // cross-fade layers over the base
  weights:array[0..2] of single;
  count:integer;
  procedure Init(const f:TFill);
  // Move toward target by w: (current look)*(1-w)+target*w
  procedure Blend(const target:TFill;w:single);
  // Layer i at its weight; a ramp can't fade: it appears at the middle of the transition
  function Layer(i:integer):TFill;
  function IsSingle:boolean;  // no layers: one TFill describes it
  function IsEmpty:boolean;   // nothing at all: no fill or a zero color, no layers
  function HasAlpha:boolean;  // may be translucent (a translucent color, a ramp or layers)
  function HasEdge:boolean;   // some part is an edge() fill
  procedure ScaleEdge(k:single); // edge() band widths multiplied by k (logical units -> pixels)
 end;

 // Corner radii, clockwise from the top-left
 TCornerRadii=record
  topLeft,topRight,bottomRight,bottomLeft:single;
  class function All(r:single):TCornerRadii; static;
  class function Init(tl,tr,br,bl:single):TCornerRadii; static;
  function MaxRadius:single;
 end;

 TDisplayModeHelper = record helper for TDisplayMode
  function ToString:string;
 end;
 TPointCompatHelper = record helper for TPoint
  function Equals(const p:TPoint):boolean; inline;
  function IsNear(x,y,radius:single):boolean; inline;
 end;

 function MakeSize(width,height:integer):TSize; inline;
 function SameSize(const a,b:TSize):boolean; inline;

 // --- Surface model: pure functions (see Work/R-31_api_design.md) ---
 // Rejects meaningless axis combinations with an EError (no silent degradation):
 //  - center/integerScale require a fixed renderSize;
 //  - renderSize axes must be both 0 or both >0; negative sizes are invalid;
 //  - canvas fixed on both axes + fill needs allowAspectDistortion
 //    (a fixed window whose client is derived from the canvas uses keepAspect);
 //  - canvas fixed on both axes + render fixed with a different aspect needs allowAspectDistortion;
 //  - canvasDPI must not be negative and needs a flexible canvas (both axes 0).
 procedure ValidateSurfaceConfig(const config:TSurfaceConfig);
 // Total function for a valid config: input + config -> state.
 // Order: contentAspect -> displayRect -> canvasSize -> renderSize -> aspect invariant -> safe area.
 // Raises EError if the aspect invariant is broken without allowAspectDistortion
 // (that's a configuration-hook bug: e.g. fill + fixed render of a non-client aspect).
 procedure ResolveSurface(const input:TSurfaceInput;const config:TSurfaceConfig;
   out state:TSurfaceState);
 // Hook helper: uniformly shrink the client size to fit a pixel budget (maxW x maxH),
 // keeping the aspect; returns (0,0) (= native) when the client already fits.
 function FitToBudget(const client:TSize;maxW,maxH:integer):TSize;

implementation
uses SysUtils, Apus.Utils;

const
 // Aspect ratios within this relative tolerance are treated as equal
 // (avoids 1px bars from integer rounding)
 SURFACE_ASPECT_TOLERANCE=0.01;

function MakeSize(width,height:integer):TSize;
 begin
  result.cx:=width;
  result.cy:=height;
 end;

function SameSize(const a,b:TSize):boolean;
 begin
  result:=(a.cx=b.cx) and (a.cy=b.cy);
 end;

function SameAspect(aspect1,aspect2:double):boolean;
 begin
  result:=abs(aspect1-aspect2)<=SURFACE_ASPECT_TOLERANCE*aspect2;
 end;

// value*num/den rounded down / up, exact in integers (value>=0, num>=0, den>0)
function ScaleFloor(value,num,den:integer):integer;
 begin
  result:=(int64(value)*num) div den;
 end;

function ScaleCeil(value,num,den:integer):integer;
 begin
  result:=(int64(value)*num+den-1) div den;
 end;

function SizeAspect(const s:TSize):double;
 begin
  if s.cy>0 then result:=s.cx/s.cy
   else result:=0;
 end;

{ TSurfaceConfig }

procedure TSurfaceConfig.Init;
 begin
  canvasSize:=MakeSize(0,0);
  renderSize:=MakeSize(0,0);
  fit:=TSurfaceFit.fill;
  allowAspectDistortion:=false;
  canvasDPI:=0;
 end;

function TSurfaceConfig.CanvasFixed:boolean;
 begin
  result:=(canvasSize.cx>0) and (canvasSize.cy>0);
 end;

function TSurfaceConfig.CanvasFlexible:boolean;
 begin
  result:=(canvasSize.cx=0) and (canvasSize.cy=0);
 end;

function TSurfaceConfig.RenderFixed:boolean;
 begin
  result:=renderSize.cx>0;
 end;

{ TSurfaceInput }

procedure TSurfaceInput.Init(width,height:integer;dpi:integer=96);
 begin
  clientSize:=MakeSize(width,height);
  self.dpi:=dpi;
  safeInsets:=Rect(0,0,0,0);
  renderScale:=1.0;
  forceRT:=false;
 end;

{ TSurfaceState }

function TSurfaceState.ClientToCanvas(const p:TPoint):TPoint;
 begin
  result.x:=round((p.x-displayRect.Left)*canvasSize.cx/(displayRect.Right-displayRect.Left));
  result.y:=round((p.y-displayRect.Top)*canvasSize.cy/(displayRect.Bottom-displayRect.Top));
 end;

function TSurfaceState.CanvasToClient(const p:TPoint):TPoint;
 begin
  result.x:=round(displayRect.Left+p.x*(displayRect.Right-displayRect.Left)/canvasSize.cx);
  result.y:=round(displayRect.Top+p.y*(displayRect.Bottom-displayRect.Top)/canvasSize.cy);
 end;

function TSurfaceState.TryClientToCanvas(const p:TPoint;out canvasP:TPoint):boolean;
 begin
  canvasP:=ClientToCanvas(p);
  result:=(p.x>=displayRect.Left) and (p.x<displayRect.Right) and
          (p.y>=displayRect.Top) and (p.y<displayRect.Bottom);
 end;

function TSurfaceState.Diff(const prev:TSurfaceState):TSurfaceChanges;
 begin
  result:=[];
  if not SameSize(clientSize,prev.clientSize) then include(result,TSurfaceChange.client);
  if not SameSize(canvasSize,prev.canvasSize) then include(result,TSurfaceChange.canvas);
  if not SameSize(renderSize,prev.renderSize) then include(result,TSurfaceChange.render);
  if displayRect<>prev.displayRect then include(result,TSurfaceChange.placement);
  if safeAreaRect<>prev.safeAreaRect then include(result,TSurfaceChange.safeArea);
  if dpi<>prev.dpi then include(result,TSurfaceChange.dpi);
 end;

function TSurfaceState.ToString:string;
 const
  mechNames:array[TSurfaceMechanism] of string=('direct','matrix','blit');
 begin
  result:=Format('gen=%d client=%dx%d display=(%d,%d)-(%d,%d) render=%dx%d canvas=%dx%d safe=(%d,%d)-(%d,%d) dpi=%d %s',
    [generation,clientSize.cx,clientSize.cy,
     displayRect.Left,displayRect.Top,displayRect.Right,displayRect.Bottom,
     renderSize.cx,renderSize.cy,canvasSize.cx,canvasSize.cy,
     safeAreaRect.Left,safeAreaRect.Top,safeAreaRect.Right,safeAreaRect.Bottom,
     dpi,mechNames[mechanism]]);
 end;

{ Surface resolver }

procedure ValidateSurfaceConfig(const config:TSurfaceConfig);
 begin
  if (config.canvasSize.cx<0) or (config.canvasSize.cy<0) or
     (config.renderSize.cx<0) or (config.renderSize.cy<0) then
   raise EError.Create('Surface config: negative size');
  if (config.renderSize.cx>0)<>(config.renderSize.cy>0) then
   raise EError.Create('Surface config: renderSize axes must be both 0 (native) or both >0');
  if (config.fit in [TSurfaceFit.center,TSurfaceFit.integerScale]) and not config.RenderFixed then
   raise EError.Create('Surface config: fit=center/integerScale requires a fixed renderSize');
  if config.canvasDPI<0 then
   raise EError.Create('Surface config: negative canvasDPI');
  if (config.canvasDPI>0) and not config.CanvasFlexible then
   raise EError.Create('Surface config: canvasDPI requires a flexible canvas (canvasSize 0x0)');
  if config.CanvasFixed and not config.allowAspectDistortion then begin
   if config.fit=TSurfaceFit.fill then
    raise EError.Create('Surface config: fixed canvas + fit=fill distorts the aspect (use keepAspect or allowAspectDistortion)');
   if config.RenderFixed and not SameAspect(SizeAspect(config.canvasSize),SizeAspect(config.renderSize)) then
    raise EError.Create('Surface config: fixed canvas and fixed renderSize have different aspects');
  end;
 end;

procedure ResolveSurface(const input:TSurfaceInput;const config:TSurfaceConfig;
  out state:TSurfaceState);
 var
  cw,ch,w,h,k:integer;
  contentAspect:double;
  dispW,dispH:integer;
  safeClient,safeDisp:TRect;
  unitSize:double;
 begin
  cw:=input.clientSize.cx;
  ch:=input.clientSize.cy;
  ASSERT((cw>0) and (ch>0),'ResolveSurface: empty client size');
  ASSERT(input.renderScale>0,'ResolveSurface: renderScale must be positive');
  Mem.Clear(state,sizeof(state));
  state.clientSize:=input.clientSize;
  state.dpi:=input.dpi;

  // 1. content aspect: fixed canvas > fixed render > client
  if config.CanvasFixed then contentAspect:=SizeAspect(config.canvasSize)
  else
  if config.RenderFixed then contentAspect:=SizeAspect(config.renderSize)
  else contentAspect:=cw/ch;

  // 2. display rect
  case config.fit of
   TSurfaceFit.fill:begin
    w:=cw; h:=ch;
   end;
   TSurfaceFit.keepAspect:begin
    w:=cw; h:=ch;
    if not SameAspect(cw/ch,contentAspect) then begin
     if cw/ch>contentAspect then w:=round(ch*contentAspect)
      else h:=round(cw/contentAspect);
    end;
   end;
   TSurfaceFit.center:begin
    w:=config.renderSize.cx; h:=config.renderSize.cy;
   end;
   TSurfaceFit.integerScale:begin
    k:=Min(cw div config.renderSize.cx,ch div config.renderSize.cy);
    if k<1 then k:=1; // client smaller than renderSize: 1:1 with crop
    w:=config.renderSize.cx*k; h:=config.renderSize.cy*k;
   end;
  end;
  state.displayRect:=Rect(0,0,w,h);
  OffsetRect(state.displayRect,(cw-w) div 2,(ch-h) div 2);
  dispW:=w; dispH:=h;

  // 3. canvas size: fixed axes as declared, flexible axes from the integer display rect
  // (in units of 1/canvasDPI inch, if set)
  if config.CanvasFixed then state.canvasSize:=config.canvasSize
  else
  if config.CanvasFlexible then begin
   state.canvasSize:=MakeSize(dispW,dispH);
   if (config.canvasDPI>0) and (input.dpi>0) and (input.dpi<>config.canvasDPI) then begin
    unitSize:=input.dpi/config.canvasDPI; // display pixels per canvas unit
    state.canvasSize:=MakeSize(Max(1,round(dispW/unitSize)),Max(1,round(dispH/unitSize)));
   end;
  end else
  if config.canvasSize.cx>0 then
   state.canvasSize:=MakeSize(config.canvasSize.cx,round(config.canvasSize.cx*dispH/dispW))
  else
   state.canvasSize:=MakeSize(round(config.canvasSize.cy*dispW/dispH),config.canvasSize.cy);

  // 4. render size (renderScale doesn't affect the display rect)
  if config.RenderFixed then state.renderSize:=config.renderSize
   else state.renderSize:=MakeSize(dispW,dispH);
  if input.renderScale<>1.0 then
   state.renderSize:=MakeSize(Max(1,round(state.renderSize.cx*input.renderScale)),
                              Max(1,round(state.renderSize.cy*input.renderScale)));

  // 5. aspect invariant: canvas = render = display rect
  // (a flexible canvas is derived from the display rect, its aspect differs by rounding only)
  if not config.allowAspectDistortion then begin
   if not config.CanvasFlexible and
      not SameAspect(SizeAspect(state.canvasSize),SizeAspect(MakeSize(dispW,dispH))) or
      not SameAspect(SizeAspect(state.renderSize),SizeAspect(MakeSize(dispW,dispH))) then
    raise EError.Create(Format('Surface aspect mismatch: canvas %dx%d, render %dx%d, display %dx%d (configuration hook must use keepAspect or allowAspectDistortion)',
      [state.canvasSize.cx,state.canvasSize.cy,state.renderSize.cx,state.renderSize.cy,dispW,dispH]));
  end;

  // 6. safe area: client insets -> intersect with display rect -> canvas (conservative inward rounding)
  safeClient:=Rect(input.safeInsets.Left,input.safeInsets.Top,cw-input.safeInsets.Right,ch-input.safeInsets.Bottom);
  if TRect2.IntersectRect(safeClient,state.displayRect,safeDisp)=0 then
   safeDisp:=state.displayRect; // no overlap - fall back to the whole canvas
  // exact integer scaling (a*canvas/disp): ceil for left/top, floor for right/bottom
  state.safeAreaRect.Left:=ScaleCeil(safeDisp.Left-state.displayRect.Left,state.canvasSize.cx,dispW);
  state.safeAreaRect.Top:=ScaleCeil(safeDisp.Top-state.displayRect.Top,state.canvasSize.cy,dispH);
  state.safeAreaRect.Right:=ScaleFloor(safeDisp.Right-state.displayRect.Left,state.canvasSize.cx,dispW);
  state.safeAreaRect.Bottom:=ScaleFloor(safeDisp.Bottom-state.displayRect.Top,state.canvasSize.cy,dispH);

  // 7. mechanism (derived)
  if config.RenderFixed or (input.renderScale<>1.0) or input.forceRT then state.mechanism:=TSurfaceMechanism.blit
  else
  if SameSize(state.canvasSize,state.renderSize) then state.mechanism:=TSurfaceMechanism.direct
  else state.mechanism:=TSurfaceMechanism.matrix;
  state.needRT:=state.mechanism=TSurfaceMechanism.blit;
 end;

function FitToBudget(const client:TSize;maxW,maxH:integer):TSize;
 var
  k:double;
 begin
  ASSERT((maxW>0) and (maxH>0),'FitToBudget: budget must be positive');
  if (client.cx<=maxW) and (client.cy<=maxH) then exit(MakeSize(0,0)); // fits: native
  k:=Min(maxW/client.cx,maxH/client.cy);
  result:=MakeSize(Min(maxW,round(client.cx*k)),Min(maxH,round(client.cy*k)));
 end;

 {$EXCESSPRECISION OFF}
 // TODO: trim this unit to engine-specific types only and move Base-type re-exports
 // to explicit imports or a dedicated facade, as documented in Work/engine_work_ahead.md.

 const
  k255 = 1/255;

function TDisplayModeHelper.ToString:string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayMode),ord(self));
 end;



function TPointCompatHelper.Equals(const p:TPoint):boolean;
 begin
  result:=(x=p.x) and (y=p.y);
 end;

function TPointCompatHelper.IsNear(x,y,radius:single):boolean;
 begin
  result:=Sqr(self.x-x)+Sqr(self.y-y)<=sqr(radius);
 end;

{ TColorVector }
 constructor TColorVector.Init(red,green,blue,alpha:single);
  begin
   self.red:=red;
   self.green:=green;
   self.blue:=blue;
   self.alpha:=alpha;
  end;

 class function TColorVector.FromColor(color:cardinal;scale:single):TColorVector;
  begin
   result.red:=PARGBColor(@color).r*k255*scale;
   result.green:=PARGBColor(@color).g*k255*scale;
   result.blue:=PARGBColor(@color).b*k255*scale;
   result.alpha:=PARGBColor(@color).a*k255*scale;
  end;

 function TColorVector.ToQuat:TQuat;
  begin
   result:=TQuat.Init(red,green,blue,alpha);
  end;

{ TFill }
 // premultiplied interpolation of two straight ARGB colors: a fade to transparent keeps the hue
 function MixPremul(c1,c2:cardinal;t:single):cardinal;
  var
   w1,w2,a:single;
  begin
   if t<=0 then exit(c1);
   if t>=1 then exit(c2);
   w1:=(c1 shr 24)*(1-t);
   w2:=(c2 shr 24)*t;
   a:=w1+w2;
   if a<=0 then exit(Color.Mix(c1,c2,t) and $FFFFFF);
   result:=cardinal(round(a)) shl 24+
     cardinal(round((byte(c1 shr 16)*w1+byte(c2 shr 16)*w2)/a)) shl 16+
     cardinal(round((byte(c1 shr 8)*w1+byte(c2 shr 8)*w2)/a)) shl 8+
     cardinal(round((byte(c1)*w1+byte(c2)*w2)/a));
  end;

 function FloorF(x:single):single; inline;
  begin
   result:=Int(x);
   if result>x then result:=result-1;
  end;

 class function TFill.None:TFill;
  begin
   result:=Default(TFill);
  end;

 class function TFill.Solid(color:cardinal):TFill;
  begin
   result:=Default(TFill);
   result.kind:=fkSolid;
   result.stopCount:=1;
   result.stops[0].color:=color;
  end;

 class function TFill.Linear(angle:single;c1,c2:cardinal):TFill;
  begin
   result:=Linear(TVec2.Init(angle,0),TVec2.Init(0,0),c1,c2,fuAngle);
  end;

 class function TFill.Linear(const p0,p1:TVec2;c1,c2:cardinal;units:TFillUnits=fuLocal):TFill;
  begin
   result:=Default(TFill);
   result.kind:=fkLinear;
   result.units:=units;
   result.p0:=p0;
   result.p1:=p1;
   result.stopCount:=2;
   result.stops[0].color:=c1;
   result.stops[1].pos:=1;
   result.stops[1].color:=c2;
  end;

 class function TFill.Edge(width:single;cEdge,cInner:cardinal):TFill;
  begin
   result:=Linear(TVec2.Init(width,0),TVec2.Init(0,0),cEdge,cInner,fuAbsolute);
   result.kind:=fkEdge;
  end;

 function TFill.AddStop(pos:single;color:cardinal):TFill;
  var
   i:integer;
  begin
   result:=self;
   ASSERT(kind in [fkLinear,fkEdge],'TFill.AddStop: not a gradient');
   ASSERT(stopCount<MAX_FILL_STOPS,'TFill.AddStop: too many stops');
   if stopCount>=MAX_FILL_STOPS then exit;
   // keep the stops sorted; an equal position goes after the existing one (hard edge)
   i:=stopCount;
   while (i>0) and (result.stops[i-1].pos>pos) do begin
    result.stops[i]:=result.stops[i-1];
    dec(i);
   end;
   result.stops[i].pos:=pos;
   result.stops[i].color:=color;
   inc(result.stopCount);
  end;

 function TFill.WithRamp(tex:TObject):TFill;
  begin
   result:=self;
   result.ramp:=tex;
  end;

 function TFill.WithSpread(spread:TFillSpread):TFill;
  begin
   result:=self;
   result.spread:=spread;
  end;

 function TFill.IsVisible:boolean;
  var
   i:integer;
  begin
   if kind=fkNone then exit(false);
   if ramp<>nil then exit(true);
   for i:=0 to stopCount-1 do
    if stops[i].color shr 24<>0 then exit(true);
   result:=false;
  end;

 procedure TFill.GetLine(const box:TRect2;out a,b:TVec2);
  var
   w,h,s,c,l,cx,cy:single;
  begin
   w:=box.x2-box.x1;
   h:=box.y2-box.y1;
   case units of
    fuLocal:begin
     a.x:=box.x1+p0.x*w; a.y:=box.y1+p0.y*h;
     b.x:=box.x1+p1.x*w; b.y:=box.y1+p1.y*h;
    end;
    fuAbsolute:begin
     a:=p0; b:=p1;
    end;
    fuAngle:begin
     // CSS: the line goes through the center, its length makes the ends pass the corners
     s:=sin(p0.x*(Pi/180));
     c:=cos(p0.x*(Pi/180));
     l:=(abs(w*s)+abs(h*c))*0.5;
     cx:=(box.x1+box.x2)*0.5;
     cy:=(box.y1+box.y2)*0.5;
     a.x:=cx-s*l; a.y:=cy+c*l; // direction (sin,-cos): Y axis goes down
     b.x:=cx+s*l; b.y:=cy-c*l;
    end;
   end;
  end;

 function TFill.ParamAt(x,y:single;const box:TRect2):single;
  var
   a,b:TVec2;
   dx,dy,len2:single;
  begin
   GetLine(box,a,b);
   dx:=b.x-a.x; dy:=b.y-a.y;
   len2:=dx*dx+dy*dy;
   if len2<1E-12 then exit(0);
   result:=((x-a.x)*dx+(y-a.y)*dy)/len2;
  end;

 function TFill.ColorAtParam(t:single):cardinal;
  var
   i:integer;
  begin
   if stopCount=0 then exit(0);
   case spread of
    fsRepeat:t:=t-FloorF(t);
    fsReflect:t:=1-abs(t-2*FloorF(t*0.5)-1);
   end;
   if t<=stops[0].pos then exit(stops[0].color);
   for i:=1 to stopCount-1 do
    if t<stops[i].pos then
     exit(MixPremul(stops[i-1].color,stops[i].color,(t-stops[i-1].pos)/(stops[i].pos-stops[i-1].pos)));
   result:=stops[stopCount-1].color;
  end;

 function TFill.ColorAt(x,y:single;const box:TRect2):cardinal;
  begin
   case kind of
    fkSolid:result:=stops[0].color;
    fkLinear:result:=ColorAtParam(ParamAt(x,y,box));
    fkEdge:if stopCount>0 then result:=stops[stopCount-1].color
            else result:=0;
    else result:=0;
   end;
  end;

 function TFill.Add(color:cardinal):TFill;
  var
   i:integer;
  begin
   result:=self;
   for i:=0 to stopCount-1 do
    result.stops[i].color:=Apus.Colors.Color.Add(stops[i].color,color);
  end;

 function TFill.Sub(color:cardinal):TFill;
  var
   i:integer;
  begin
   result:=self;
   for i:=0 to stopCount-1 do
    result.stops[i].color:=Apus.Colors.Color.Sub(stops[i].color,color);
  end;

 function TFill.MixWith(color:cardinal;t:single):TFill;
  var
   i:integer;
  begin
   result:=self;
   for i:=0 to stopCount-1 do
    result.stops[i].color:=Apus.Colors.Color.Mix(stops[i].color,color,t);
  end;

 function TFill.Faded(k:single):TFill;
  var
   i:integer;
   c:cardinal;
  begin
   result:=self;
   if k>=1 then exit;
   if k<0 then k:=0;
   for i:=0 to stopCount-1 do begin
    c:=stops[i].color;
    result.stops[i].color:=(c and $FFFFFF) or (cardinal(round((c shr 24)*k)) shl 24);
   end;
  end;

 function IsPlainFill(const f:TFill):boolean; inline;
  begin
   result:=f.kind in [fkNone,fkSolid];
  end;

 function PlainFillColor(const f:TFill):cardinal; inline;
  begin
   if f.kind=fkSolid then result:=f.stops[0].color
    else result:=0; // fkNone: transparent
  end;

 // a solid (or none) in the structure of the pattern: the same color in every stop
 function PromoteFill(const f,pattern:TFill):TFill;
  var
   i:integer;
  begin
   result:=pattern;
   result.ramp:=nil;
   for i:=0 to result.stopCount-1 do
    result.stops[i].color:=PlainFillColor(f);
  end;

 class function TFill.Mix(const a,b:TFill;t:single;out r:TFill):boolean;
  var
   x,y:TFill;
   i:integer;
  begin
   result:=true;
   if t<=0 then begin
    r:=a; exit;
   end;
   if t>=1 then begin
    r:=b; exit;
   end;
   if IsPlainFill(a) and IsPlainFill(b) then begin
    if (a.kind=fkNone) and (b.kind=fkNone) then r:=None
     else r:=Solid(MixPremul(PlainFillColor(a),PlainFillColor(b),t));
    exit;
   end;
   x:=a; y:=b;
   if IsPlainFill(x) then x:=PromoteFill(x,y)
    else if IsPlainFill(y) then y:=PromoteFill(y,x);
   if (x.kind<>y.kind) or (x.units<>y.units) or (x.spread<>y.spread) or
      (x.stopCount<>y.stopCount) or (x.ramp<>y.ramp) then begin
    r:=a;
    exit(false);
   end;
   r:=x;
   r.p0.x:=x.p0.x+(y.p0.x-x.p0.x)*t;
   r.p0.y:=x.p0.y+(y.p0.y-x.p0.y)*t;
   r.p1.x:=x.p1.x+(y.p1.x-x.p1.x)*t;
   r.p1.y:=x.p1.y+(y.p1.y-x.p1.y)*t;
   for i:=0 to x.stopCount-1 do begin
    r.stops[i].pos:=x.stops[i].pos+(y.stops[i].pos-x.stops[i].pos)*t;
    r.stops[i].color:=MixPremul(x.stops[i].color,y.stops[i].color,t);
   end;
  end;

{ TCornerRadii }
 { TBlendedFill }

 procedure TBlendedFill.Init(const f:TFill);
  begin
   fill:=f;
   count:=0;
  end;

 procedure TBlendedFill.Blend(const target:TFill;w:single);
  var
   r:array[0..3] of TFill;
   i:integer;
   ok:boolean;
  begin
   if w<=0 then exit;
   if w>=1 then begin
    Init(target); exit;
   end;
   ok:=TFill.Mix(fill,target,w,r[0]);
   for i:=0 to count-1 do
    ok:=ok and TFill.Mix(layers[i],target,w,r[i+1]);
   if ok then begin
    fill:=r[0];
    for i:=0 to count-1 do layers[i]:=r[i+1];
   end else
   if count<=high(layers) then begin
    layers[count]:=target;
    weights[count]:=w;
    inc(count);
   end else
   if w>=0.5 then Init(target);
  end;

 function TBlendedFill.Layer(i:integer):TFill;
  begin
   if layers[i].ramp=nil then result:=layers[i].Faded(weights[i])
   else if weights[i]>=0.5 then result:=layers[i]
   else result:=TFill.None;
  end;

 function TBlendedFill.IsSingle:boolean;
  begin
   result:=count=0;
  end;

 function TBlendedFill.IsEmpty:boolean;
  begin
   result:=(count=0) and ((fill.kind=fkNone) or
     ((fill.kind=fkSolid) and (fill.stops[0].color=0)));
  end;

 function TBlendedFill.HasAlpha:boolean;
  var
   i:integer;
  begin
   result:=(count>0) or (fill.ramp<>nil);
   if not result and (fill.kind<>fkNone) then
    for i:=0 to fill.stopCount-1 do
     if fill.stops[i].color shr 24<>$FF then exit(true);
  end;

 function TBlendedFill.HasEdge:boolean;
  var
   i:integer;
  begin
   result:=fill.kind=fkEdge;
   for i:=0 to count-1 do
    result:=result or (layers[i].kind=fkEdge);
  end;

 procedure TBlendedFill.ScaleEdge(k:single);
  var
   i:integer;
  begin
   if fill.kind=fkEdge then fill.p0.x:=fill.p0.x*k;
   for i:=0 to count-1 do
    if layers[i].kind=fkEdge then layers[i].p0.x:=layers[i].p0.x*k;
  end;

 class function TCornerRadii.All(r:single):TCornerRadii;
  begin
   result.topLeft:=r;
   result.topRight:=r;
   result.bottomRight:=r;
   result.bottomLeft:=r;
  end;

 class function TCornerRadii.Init(tl,tr,br,bl:single):TCornerRadii;
  begin
   result.topLeft:=tl;
   result.topRight:=tr;
   result.bottomRight:=br;
   result.bottomLeft:=bl;
  end;

 function TCornerRadii.MaxRadius:single;
  begin
   result:=topLeft;
   if topRight>result then result:=topRight;
   if bottomRight>result then result:=bottomRight;
   if bottomLeft>result then result:=bottomLeft;
  end;

end.
