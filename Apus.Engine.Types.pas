// This is the lowest level unit of the Apus Game Engine.
// It should not use any other Engine's units.
//
unit Apus.Engine.Types;
interface
 uses Apus.Core, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.VertexLayout;

type
 // 2D points
 TPoint2 = Apus.Geom2D.TPoint2;
 PPoint2 = Apus.Geom2D.PPoint2;
 TPoint2s = Apus.Geom2D.TPoint2s;
 TVector2s = Apus.Geom2D.TVector2s;
 PPoint2s = ^TPoint2s;
 // 3D Points
 TPoint3 = Apus.Geom3D.TPoint3;
 TVector3 = TPoint3;
 PPoint3 = ^TPoint3;
 TPoint3s = Apus.Geom3D.TPoint3s;
 PPoint3s = ^TPoint3s;
 TVector3s = Apus.Geom3D.TVector3s;
 TVector4 = TQuaternion;
 TVector4s = TQuaternionS;
 TQuaternionS = Apus.Geom3D.TQuaternionS;
 // Matrices
 T3DMatrix = TMatrix4;
 T3DMatrixS = TMatrix4s;
 T2DMatrix = TMatrix32s;

 TRect2s = Apus.Geom2D.TRect2s;

 TAsyncProc = function(param:UIntPtr):integer;

 TVertexComponent = Apus.VertexLayout.TVertexComponent;
 TVertexLayout = Apus.VertexLayout.TVertexLayout;

 TIndices=WordArray;

 TTextAlignment=(taLeft,      // normal output
                 taCenter,    // output point indicates the text center
                 taRight,     // output point indicates the right edge
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

 TDisplayModeHelper = record helper for TDisplayMode
  function ToString:string;
 end;
 TDisplayFitModeHelper = record helper for TDisplayFitMode
  function ToString:string;
 end;
 TDisplayScaleModeHelper = record helper for TDisplayScaleMode
  function ToString:string;
 end;

implementation
uses Apus.Utils;

 {$EXCESSPRECISION OFF}
 // TODO: trim this unit to engine-specific types only and move Base-type re-exports
 // to explicit imports or a dedicated facade, as documented in engine_work_ahead.md.

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


 function TColorGradient.ColorAt(x,y:single):cardinal;
  begin
   result:=MyColorF(alpha.ValueAt(x,y),red.valueAt(x,y),green.ValueAt(x,y),blue.ValueAt(x,y));
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
