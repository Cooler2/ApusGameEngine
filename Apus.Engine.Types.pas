// This is the lowest level unit of the Apus Game Engine.
// It should not use any other Engine's units.
//
unit Apus.Engine.Types;
interface
 uses Types, Apus.Core, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.VertexLayout;

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

 // Display mode
 TDisplayMode=(dmNone,             //< not specified
               dmSwitchResolution, //< Fullscreen: switch to desired display mode (change screen resolution)
               dmFullScreen,       //< Use current resolution with fullscreen window
               dmFixedWindow,      //< Use fixed-size window
               dmWindow,           //< Use resizeable window
               dmBorderless);      //< Use borderless window (non-fullscreen), app should manually resize it if needed

 // How the rendered image should appear in the output window (display)
 TDisplayFitMode=(dfmCenter,           //< image is centered in the output window rect (1:1) (DisplayScaleMode is ignored)
                  dfmFullSize,         //< image is stretched to fill the whole output window
                  dfmKeepAspectRatio); //< image is stretched to fill the output window while keeping it's original aspect ratio (black padding)

 // How rendering is processed if the backbuffer size doesn't match the output area
 TDisplayScaleMode=(dsmDontScale,   //< Backbuffer size is updated to match the output area
                    dsmStretch,     //< Stretch rendered image to the output rect
                    dsmScale);      //< Use scale transformation matrix to map render area to the output rect (scaled rendering)
                                    // Note that scaled rendering produces error in clipping due to rounding

 // Display settings
 TDisplaySettings=record
  displayMode:TDisplayMode;
  displayFitMode:TDisplayFitMode;
  displayScaleMode:TDisplayScaleMode;
 end;

 // Runtime display/window configuration.
 TGameSettings=record
  title:string;  // window/program title
  width,height:integer; // backbuffer size and desired output area
  colorDepth:integer; // requested backbuffer format (16/24/32)
  refresh:integer;   // display refresh rate (0 - default)
  vSync:integer;     // 0 - max FPS, N - FPS = refresh/N
  mode,altMode:TDisplaySettings; // primary and alternate display mode (Alt+Enter)
  showSystemCursor:boolean; // draw system cursor instead of engine cursor
  zbuffer:byte; // desired precision for a depth buffer (0 - don't use depth buffer)
  stencil:boolean; // request a stencil-buffer (at least 8-bit)
  multisampling:byte; // full-screen anti-aliasing samples (<2 - disabled)
  slowmotion:boolean; // hint: prefer redraw optimizations for low/unstable frame rates
 end;

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
  procedure Init; // full-window defaults: canvas(0,0), render native, fill
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

 TMonoGradient=record
  base,dx,dy:single;
  procedure Init(v1,v2,angle,scale:single);
  function ValueAt(x,y:single):single; inline;
 end;
 // Linear gradient
 TColorGradient=record
  red,green,blue,alpha:TMonoGradient;
  procedure Init(color1,color2:cardinal;angle,scale:single);
  function ColorAt(x,y:single):cardinal;
 end;

 PRoundRectExtParams=^TRoundRectExtParams;
 TRoundRectExtParams=record
  origin:TVec2; // normalized local coords: (0,0)=center, (-1,-1)..(1,1)=corners
  fillDx,fillDy:TColorVector; // signed color delta per normalized local axis
  constructor Init(const fillDx,fillDy:TColorVector;const origin:TVec2);
 end;

 TDisplayModeHelper = record helper for TDisplayMode
  function ToString:string;
 end;
 TDisplayFitModeHelper = record helper for TDisplayFitMode
  function ToString:string;
 end;
 TDisplayScaleModeHelper = record helper for TDisplayScaleMode
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
 //  - canvas fixed on both axes + render fixed with a different aspect needs allowAspectDistortion.
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
  if config.CanvasFixed then state.canvasSize:=config.canvasSize
  else
  if config.CanvasFlexible then state.canvasSize:=MakeSize(dispW,dispH)
  else
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
  if not config.allowAspectDistortion then begin
   if not SameAspect(SizeAspect(state.canvasSize),SizeAspect(MakeSize(dispW,dispH))) or
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

{ TGradient }
 const
  k255 = 1/255;
  minGradientScale = 1E-6;

function TDisplayModeHelper.ToString:string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayMode),ord(self));
 end;

function TDisplayFitModeHelper.ToString: string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayFitMode),ord(self));
 end;

function TDisplayScaleModeHelper.ToString: string;
 begin
  result:=GetEnumNameSafe(TypeInfo(TDisplayScaleMode),ord(self));
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

{ TRoundRectExtParams }
 constructor TRoundRectExtParams.Init(const fillDx,fillDy:TColorVector;const origin:TVec2);
  begin
   self.origin:=origin;
   self.fillDx:=fillDx;
   self.fillDy:=fillDy;
  end;

 function TColorGradient.ColorAt(x,y:single):cardinal;
  begin
   result:=Color.ARGBf(alpha.ValueAt(x,y),red.valueAt(x,y),green.ValueAt(x,y),blue.ValueAt(x,y));
  end;

 procedure TColorGradient.Init(color1,color2:cardinal;angle,scale:single);
  begin
   alpha.Init(PARGBColor(@color1).a*k255,PARGBColor(@color2).a*k255,angle,scale);
   red.Init(PARGBColor(@color1).r*k255,PARGBColor(@color2).r*k255,angle,scale);
   green.Init(PARGBColor(@color1).g*k255,PARGBColor(@color2).g*k255,angle,scale);
   blue.Init(PARGBColor(@color1).b*k255,PARGBColor(@color2).b*k255,angle,scale);
  end;

{ TMonoGradient }
 procedure TMonoGradient.Init(v1,v2,angle,scale:single);
  begin
   base:=(v1+v2)/2;
   if abs(scale)<=minGradientScale then begin
     dx:=0;
     dy:=0;
   end else begin
     dx:=(v2-v1)*cos(angle)/scale;
     dy:=(v2-v1)*sin(angle)/scale;
   end;
  end;

 function TMonoGradient.ValueAt(x,y:single):single;
  begin
   result:=Clamp(base+(x*2-1)*dx+(y*2-1)*dy,0,1);
  end;

end.
