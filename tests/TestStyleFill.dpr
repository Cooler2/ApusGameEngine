// GPU test for style fills (R-39): 'fill' / 'border-color' / 'fill-shade' as <fill>,
// per-corner 'radius', state transitions. Needs a real GL context (a window is shown),
// so CI only compiles it. Elements are drawn by the default drawer into a render target,
// then chosen pixels are checked. The result is saved to bin64/TestStyleFill/style_fill.png.
{$APPTYPE CONSOLE}
program TestStyleFill;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils, Types,
  Apus.Core, Apus.Colors, Apus.Images, Apus.Files, Apus.GfxFormats, Apus.Geom2D, Apus.EventMan,
  Apus.Engine.Types, Apus.Engine.API, Apus.Engine.GameApp, Apus.Engine.Scene,
  Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIRender,
  Apus.Engine.DefaultStyle, Apus.Engine.Style;

{$I ..\Base\tests\Test.inc}

const
  W=640;
  H=160;
  BG=$FF283038;
  TOLERANCE=3; // per channel, 0..255
  NO_ANIM='caption-display:none; hover-time:0; press-time:0; release-time:0; disable-time:0; enable-time:0; ';

type
  TTestApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure CreateScenes; override;
  end;

  TTestScene=class(TGameScene)
    frame:integer;
    procedure Render; override;
    function GetArea:TRect; override;
  end;

var
  rt:TTexture;
  img:TBitmapImage;
  root:TUIElement;

function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^;
end;

function Channel(c:cardinal;shift:integer):integer;
begin
  result:=(c shr shift) and $FF;
end;

function SameRGB(a,b:cardinal;tol:integer=TOLERANCE):boolean;
begin
  result:=(abs(Channel(a,16)-Channel(b,16))<=tol) and (abs(Channel(a,8)-Channel(b,8))<=tol) and
    (abs(Channel(a,0)-Channel(b,0))<=tol);
end;

procedure CheckPixel(x,y:integer;expected:cardinal;const what:string);
var
  got:cardinal;
begin
  got:=Pixel(x,y);
  Check(SameRGB(got,expected),Format('%s at (%d,%d): expected %s got %s',
    [what,x,y,IntToHex(expected and $FFFFFF,6),IntToHex(got and $FFFFFF,6)]));
end;

// The element's box in shape coordinates (pixel edges)
function BoxOf(e:TUIElement):TRect2;
begin
  with e.globalRect do
    result.Init(Left-0.5,Top-0.5,Right-0.5,Bottom-0.5);
end;

procedure DrawElement(e:TUIElement);
begin
  e.globalRect:=e.GetPosOnScreen;
  e.UpdateVisualState(CoreTime.Ticks); // as DrawUIElement does (no frame loop here)
  DrawDefaultUI(e);
end;

function NewElement(x,y,w,h:single;const style:String8;parent:TUIElement=nil):TUIElement;
begin
  if parent=nil then parent:=root;
  result:=TUIElement.Create(w,h,parent);
  result.SetPos(x,y,pivotTopLeft);
  result.style.Assign(NO_ANIM+style);
end;

// The procedural button keeps its look: the default shade is composited into the fill
// (one gradient), drawn with vertex colors - no shader program switch
procedure TestDefaultButton;
var
  b:TUIButton;
  before:integer;
  box:TRect2;
  shade:TFill;
  xc,y:integer;
begin
  StartTest('Default button: shade folded into the fill');
  b:=TUIButton.Create(140,40,root).Setup('');
  b.SetPos(10,10,pivotTopLeft);
  b.style.Assign(NO_ANIM);
  draw.FillRect(0,0,1,1,BG); // a shape draw before resets the program lazily: settle it
  before:=window.stats.shaderChanges;
  DrawElement(b);
  Check(window.stats.shaderChanges=before,'no program switch for the default button');
  gfx.CopyFromBackbuffer(0,0,img);
  box:=BoxOf(b);
  shade:=TFill.Linear(180,$30FFFFFF,$30000000);
  xc:=b.globalRect.CenterPoint.X;
  y:=b.globalRect.Top+4;
  CheckPixel(xc,y,Color.Blend(defaultBtnColor,shade.ColorAt(xc,y,box)),'top');
  y:=b.globalRect.Bottom-5;
  CheckPixel(xc,y,Color.Blend(defaultBtnColor,shade.ColorAt(xc,y,box)),'bottom');
  EndTest;
end;

// A gradient fill with a border and rounded corners
procedure TestGradientBox;
var
  e:TUIElement;
  f:TFill;
  box:TRect2;
  xc:integer;
begin
  StartTest('Gradient fill, border, radius');
  e:=NewElement(170,10,140,40,'fill: linear(180deg, #FF0000, #0000FF); radius: 6; border-color: #FFFFFF; border-width: 2;');
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  box:=BoxOf(e);
  f:=TFill.Linear(180,$FFFF0000,$FF0000FF);
  xc:=e.globalRect.CenterPoint.X;
  with e.globalRect do begin
    CheckPixel(Left,Top,BG,'rounded corner');
    CheckPixel(xc,Top,$FFFFFFFF,'border');
    CheckPixel(xc,Top+5,f.ColorAt(xc,Top+5,box),'fill top');
    CheckPixel(xc,Bottom-6,f.ColorAt(xc,Bottom-6,box),'fill bottom');
  end;
  EndTest;
end;

// 'radius: tl tr br bl'
procedure TestCornerRadii;
var
  e:TUIElement;
begin
  StartTest('Per-corner radius');
  e:=NewElement(330,10,140,40,'fill: #40C080; radius: 14 0 14 0;');
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  with e.globalRect do begin
    CheckPixel(Left,Top,BG,'top-left rounded');
    CheckPixel(Right-1,Top,$FF40C080,'top-right sharp');
    CheckPixel(Right-1,Bottom-1,BG,'bottom-right rounded');
    CheckPixel(Left,Bottom-1,$FF40C080,'bottom-left sharp');
  end;
  EndTest;
end;

// A radius larger than the box is clamped to half the smaller side: semicircle ends
// (a pill), not two arcs meeting at a sharp point
procedure TestHugeRadius;
var
  e:TUIElement;
  yc:integer;
begin
  StartTest('Huge radius gives semicircle ends');
  e:=NewElement(330,90,140,40,'fill: #E0A030; radius: 999;');
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  yc:=e.globalRect.CenterPoint.Y;
  with e.globalRect do begin
    CheckPixel(Left,Top,BG,'corner');
    CheckPixel(Left+1,yc,$FFE0A030,'the end touches the box at mid-height');
    // (-16,10) from the end center: inside the semicircle of radius 20, outside a sharp lens
    CheckPixel(Left+4,yc+10,$FFE0A030,'round end, not a point');
    CheckPixel(Left+4,yc-10,$FFE0A030,'round end, not a point (top)');
    CheckPixel(Left+30,Top,$FFE0A030,'straight top edge');
  end;
  // the geometry version (a fan, no AA) is clamped the same way
  draw.FillRRect(490,90,629,129,$FF30A0E0,999);
  gfx.CopyFromBackbuffer(0,0,img);
  CheckPixel(490,90,BG,'FillRRect: corner');
  CheckPixel(491,110,$FF30A0E0,'FillRRect: the end at mid-height');
  CheckPixel(494,120,$FF30A0E0,'FillRRect: round end, not a point');
  CheckPixel(494,100,$FF30A0E0,'FillRRect: round end, not a point (top)');
  CheckPixel(520,90,$FF30A0E0,'FillRRect: straight top edge');
  EndTest;
end;

// edge() width is in logical units: twice as wide at scale 2
procedure TestEdgeScale;
var
  holder,e:TUIElement;
  y,x:integer;
begin
  StartTest('Edge fill follows the UI scale');
  holder:=NewElement(490,10,70,40,'');
  holder.scale:=2;
  e:=NewElement(0,0,70,20,'fill: edge(4, #FF0000, #0000FF);',holder);
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  y:=e.globalRect.CenterPoint.Y;
  x:=e.globalRect.Left+5; // 5.5 px from the edge: t=0.69 at the band of 8 px (1.0 at 4 px)
  Check(Channel(Pixel(x,y),16)>40,'the band is 8 px wide: red='+IntToStr(Channel(Pixel(x,y),16)));
  CheckPixel(e.globalRect.Left+12,y,$FF0000FF,'inner color');
  EndTest;
end;

// fill-shade over a rounded box with a border: drawn in layers
procedure TestShadeLayer;
var
  e:TUIElement;
  box:TRect2;
  shade:TFill;
  xc,y:integer;
begin
  StartTest('fill-shade with a border');
  e:=NewElement(10,90,140,50,'fill: #3060C0; fill-shade: linear(180deg, #60FFFFFF, #00FFFFFF 50%, #40000000); '+
    'border-color: #101820; border-width: 1; radius: 8;');
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  box:=BoxOf(e);
  shade:=TFill.Linear(180,$60FFFFFF,$40000000).AddStop(0.5,$00FFFFFF);
  xc:=e.globalRect.CenterPoint.X;
  y:=e.globalRect.Top+4;
  CheckPixel(xc,y,Color.Blend($FF3060C0,shade.ColorAt(xc,y,box)),'shade top');
  y:=e.globalRect.Bottom-5;
  CheckPixel(xc,y,Color.Blend($FF3060C0,shade.ColorAt(xc,y,box)),'shade bottom');
  CheckPixel(xc,e.globalRect.Top,$FF101820,'border over the shade');
  EndTest;
end;

// A state whose fill can't be interpolated with the base one cross-fades two layers
procedure TestCrossFade;
var
  e:TUIElement;
  c:cardinal;
  xc,yc:integer;
begin
  StartTest('Cross-fade of non-interpolable fills');
  e:=NewElement(170,90,140,50,'fill: linear(180deg, #000000, #FFFFFF); radius: 4; '+
    ':disabled { fill: edge(6, #FF0000, #0000FF); }');
  e.style.Add('+disable-time:1000');
  DrawElement(e); // the context exists: now start the transition
  e.flags.enabled:=false;
  DrawElement(e);
  Sleep(500);
  gfx.target.Clear(BG,-1,-1);
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  xc:=e.globalRect.CenterPoint.X;
  yc:=e.globalRect.CenterPoint.Y;
  c:=Pixel(xc,yc);
  // the base gives gray 128, the state gives pure blue
  Check((Channel(c,0)>Channel(c,16)+30) and (Channel(c,16)>20),'a mix of gray and blue: '+IntToHex(c and $FFFFFF,6));
  // the end of the transition: the state fill only
  e.style.Add('+disable-time:0');
  e.flags.enabled:=true;
  DrawElement(e);
  e.flags.enabled:=false;
  gfx.target.Clear(BG,-1,-1);
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  CheckPixel(xc,yc,$FF0000FF,'state fill');
  Check(Channel(Pixel(e.globalRect.Left+1,yc),16)>150,'state edge color');
  EndTest;
end;

// A box that exists only in a state block: ':focused' draws a frame on an element without one
procedure TestStateOnlyBox;
var
  e:TUIElement;
  xc:integer;
begin
  StartTest('Box from a state block only');
  e:=NewElement(10,56,60,28,':focused { border-color: #FFFFFF; border-width: 2; }');
  DrawElement(e);
  gfx.CopyFromBackbuffer(0,0,img);
  xc:=e.globalRect.CenterPoint.X;
  CheckPixel(xc,e.globalRect.Top,BG,'not focused: nothing');
  window.focus.element:=e; // the test root is outside any scene: SetFocus can't reach a window
  try
    DrawElement(e);
  finally
    window.focus.element:=nil;
  end;
  gfx.CopyFromBackbuffer(0,0,img);
  CheckPixel(xc,e.globalRect.Top,$FFFFFFFF,'focused: the frame');
  CheckPixel(xc,e.globalRect.CenterPoint.Y,BG,'focused: no fill');
  EndTest;
end;

// Built-in states go into style.activeStates in priority order, custom ones after them:
// the plain resolver gives the priority whatever the order the states came in
procedure TestStateOrder;
var
  e:TUIElement;
begin
  StartTest('State order');
  e:=TUIElement.Create(10,10,root);
  e.style.Assign(':hover { color: #111111; } :disabled { color: #222222; }');
  e.SetState('error',true);
  e.flags.enabled:=false;
  e.UpdateVisualState(1000);
  Check(e.style.activeStates='disabled,error','disabled: '+e.style.activeStates);
  underMouse:=e;
  e.UpdateVisualState(1001);
  Check(e.style.activeStates='hover,disabled,error','hover after disabled: '+e.style.activeStates);
  Check(e.GetStyleColor('color')=$FF222222,'disabled wins over hover');
  e.SetState('error',false);
  e.SetState('warn',true);
  Check(e.style.activeStates='hover,disabled,warn','custom state removed in place: '+e.style.activeStates);
  underMouse:=nil;
  e.flags.enabled:=true;
  e.UpdateVisualState(1002);
  Check(e.style.activeStates='warn','only custom: '+e.style.activeStates);
  e.Free;
  EndTest;
end;

// Transition weights: default hover 50/250 ms, a reversed transition takes its part of the
// time, old key names work as aliases under the new ones
procedure TestStateTransitions;
var
  e:TUIElement;
  b:TUIButton;
  procedure CheckW(el:TUIElement;s:TElementState;time:int64;w:single;const msg:String8);
   begin
    el.UpdateVisualState(time);
    Check(abs(el.StateWeight(s)-w)<0.01,msg+': '+FloatToStrF(el.StateWeight(s),ffFixed,6,3));
   end;
begin
  StartTest('State transitions');
  e:=TUIElement.Create(10,10,root);
  CheckW(e,TElementState.Hover,1000,0,'initial');
  underMouse:=e;
  CheckW(e,TElementState.Hover,2000,0,'hover start');
  Check(e.visualState.Animating and e.visualState.Animating(TElementState.Hover),'animating');
  CheckW(e,TElementState.Hover,2025,0.5,'hover in, half of 50 ms');
  CheckW(e,TElementState.Hover,2050,1,'hover in done');
  Check(not e.visualState.Animating,'not animating');
  underMouse:=nil;
  CheckW(e,TElementState.Hover,3000,1,'hover out start');
  CheckW(e,TElementState.Hover,3125,0.5,'hover out, half of 250 ms');
  underMouse:=e;
  CheckW(e,TElementState.Hover,3125,0.5,'reversed');
  CheckW(e,TElementState.Hover,3150,1,'reversed: half of 50 ms');
  underMouse:=nil;
  e.Free;

  b:=TUIButton.Create(10,10,root).Setup('');
  b.style.Assign('press-time:200; release-time:40; pressed-time-out:100');
  CheckW(b,TElementState.Pressed,5000,0,'not pressed');
  b.pressed:=true;
  CheckW(b,TElementState.Pressed,6000,0,'press start');
  CheckW(b,TElementState.Pressed,6100,0.5,'press-time alias');
  CheckW(b,TElementState.Pressed,6200,1,'pressed');
  b.pressed:=false;
  CheckW(b,TElementState.Pressed,7000,1,'release start');
  CheckW(b,TElementState.Pressed,7050,0.5,'pressed-time-out over release-time');
  b.Free;
  EndTest;
end;

// A toggled button is checked, not pressed: ':pressed' does not apply, the derived checked
// color is the one of the pressed button
procedure TestCheckedLook;
var
  t:TUIToggleButton;
  b:TUIButton;
  c1,c2:cardinal;
begin
  StartTest('Checked apart from pressed');
  t:=TUIToggleButton.Create(60,26,root).Setup('',true);
  t.SetPos(490,100,pivotTopLeft);
  t.style.Assign(NO_ANIM+':pressed { fill: #FF0000; }');
  Check(t.GetStates*[TElementState.Checked,TElementState.Pressed]=[TElementState.Checked],'checked only');
  b:=TUIButton.Create(60,26,root).Setup('');
  b.SetPos(565,100,pivotTopLeft);
  b.style.Assign(NO_ANIM);
  b.pressed:=true;
  DrawElement(t);
  DrawElement(b);
  gfx.CopyFromBackbuffer(0,0,img);
  c1:=Pixel(t.globalRect.CenterPoint.X,t.globalRect.CenterPoint.Y);
  c2:=Pixel(b.globalRect.CenterPoint.X,b.globalRect.CenterPoint.Y);
  Check(c1=c2,'checked = pressed look: '+IntToHex(c1,8)+' '+IntToHex(c2,8));
  Check(Channel(c1,16)<200,'no red of :pressed');
  EndTest;
end;

// Blended values: halfway through a transition they are between the base and the state;
// when no transition runs they equal the plain resolution
procedure TestBlendedValues;
var
  e,child:TUIElement;
  f:TBlendedFill;
  c:cardinal;
begin
  StartTest('Blended values');
  Styles['blend-ref']:=':disabled { color: #0000FF; }';
  e:=TUIElement.Create(10,10,root);
  e.style.Assign('@blend-ref; color: #000000; border-width: 1; fill: linear(180deg, #000000, #FFFFFF); '+
    ':hover { color: #FFFFFF; border-width: 3; fill: edge(6, #FF0000, #0000FF); } hover-time: 100;');
  child:=TUIElement.Create(5,5,e);
  e.UpdateVisualState(1000);
  Check(e.GetBlendedStyleColor('color')=e.GetStyleColor('color'),'base color');
  Check(e.GetBlendedStyleNumber('border-width')=1,'base number');
  underMouse:=e;
  e.UpdateVisualState(2000);
  e.UpdateVisualState(2050);
  c:=e.GetBlendedStyleColor('color');
  Check((Channel(c,16)>110) and (Channel(c,16)<145),'color halfway: '+IntToHex(c,8));
  Check(abs(e.GetBlendedStyleNumber('border-width')-2)<0.01,'number halfway');
  f:=e.GetBlendedStyleFill('fill',TFill.None);
  Check((f.count=1) and (abs(f.weights[0]-0.5)<0.01),'linear -> edge: a cross-fade layer');
  Check(child.GetBlendedStyleColor('color')=c,'inherited color follows the parent blend');
  e.UpdateVisualState(2100);
  Check(e.GetBlendedStyleColor('color')=e.GetStyleColor('color'),'hover done = plain');
  Check(e.GetBlendedStyleNumber('border-width')=e.GetStyleNumber('border-width'),'number done = plain');
  f:=e.GetBlendedStyleFill('fill',TFill.None);
  Check(f.IsSingle and (f.fill.kind=fkEdge),'fill done = plain');
  // a disabled state from the ref wins over the local hover
  e.flags.enabled:=false;
  e.style.Add('+disabled-time:0');
  e.UpdateVisualState(2200);
  Check(e.GetStyleColor('color')=$FF0000FF,'plain: disabled from the ref');
  Check(e.GetBlendedStyleColor('color')=$FF0000FF,'blended: disabled from the ref');
  // a custom state applies at once
  e.flags.enabled:=true;
  e.UpdateVisualState(5000);
  e.style.Add(':error { color: #00FF00; }');
  e.SetState('error',true);
  Check(e.GetBlendedStyleColor('color')=e.GetStyleColor('color'),'custom state');
  underMouse:=nil;
  e.Free;
  Styles.Remove('blend-ref');
  EndTest;
end;

// DrawElementBox draws what the default drawer draws; the content rect keeps its place when
// a state has a thicker border; a box can be drawn by layers
procedure TestElementBox;
var
  a,b:TUIElement;
  box:TStyleBox;
  r1,r2:TRect;
  y:integer;
const
  ST='fill: #3060C0; border-color: #FFFFFF; border-width: 1; radius: 3; :focused { border-width: 3; }';
begin
  StartTest('Element box');
  a:=NewElement(10,143,60,14,ST);
  b:=NewElement(80,143,60,14,ST);
  DrawElement(a);
  b.globalRect:=b.GetPosOnScreen;
  b.UpdateVisualState(CoreTime.Ticks);
  r1:=DrawElementBox(b);
  gfx.CopyFromBackbuffer(0,0,img);
  y:=a.globalRect.CenterPoint.Y;
  CheckPixel(b.globalRect.CenterPoint.X,y,Pixel(a.globalRect.CenterPoint.X,y),'same center');
  CheckPixel(b.globalRect.Left,y,Pixel(a.globalRect.Left,y),'same border');
  Check(r1.Left=b.globalRect.Left+3,'content inset by the widest border');
  window.focus.element:=b;
  b.UpdateVisualState(CoreTime.Ticks);
  ResolveStyleBox(b,box);
  r2:=box.ContentRect;
  Check(abs(box.borderWidth-3)<0.01,'focused border');
  Check((r1.Left=r2.Left) and (r1.Top=r2.Top) and (r1.Right=r2.Right),'content rect stable');
  window.focus.element:=nil;
  // the border layer only
  a:=NewElement(150,143,60,14,ST);
  a.globalRect:=a.GetPosOnScreen;
  a.UpdateVisualState(CoreTime.Ticks);
  ResolveStyleBox(a,box);
  DrawStyleBox(box,[TStyleBoxLayer.Border]);
  gfx.CopyFromBackbuffer(0,0,img);
  CheckPixel(a.globalRect.CenterPoint.X,a.globalRect.CenterPoint.Y,BG,'no background');
  CheckPixel(a.globalRect.CenterPoint.X,a.globalRect.Top,$FFFFFFFF,'border');
  EndTest;
end;

// A part: box keys from its block blended by the weights the drawer gives, typography from the
// element; its box drawn in a rect
procedure TestPartBox;
var
  e:TUIElement;
  w:TElementStateWeights;
  f:TBlendedFill;
  box:TStyleBox;
  r:TRect;
  c:cardinal;
begin
  StartTest('Part box');
  e:=NewElement(220,143,60,14,'color: #FFFFFF; header { fill: #000000; border-width: 1; '+
    ':hover { fill: #FFFFFF; border-width: 3; } }');
  e.globalRect:=e.GetPosOnScreen;
  e.UpdateVisualState(CoreTime.Ticks);
  FillChar(w,sizeof(w),0);
  f:=e.GetBlendedPartFill('header','fill',w,TFill.None);
  Check(f.IsSingle and (f.fill.stops[0].color=$FF000000),'base part fill');
  Check(e.GetBlendedPartColor('header','color',w)=$FFFFFFFF,'color from the element');
  Check(e.GetPartStyleValue('header','fill')='#000000','plain part value');
  w[TElementState.Hover]:=0.5;
  f:=e.GetBlendedPartFill('header','fill',w,TFill.None);
  c:=f.fill.stops[0].color;
  Check(f.IsSingle and (Channel(c,16)>110) and (Channel(c,16)<145),'part fill halfway: '+IntToHex(c,8));
  Check(abs(e.GetBlendedPartNumber('header','border-width',w)-2)<0.01,'part number halfway');
  FillChar(w,sizeof(w),0);
  r:=e.globalRect;
  ResolveStyleBox(e,'header',r,w,box);
  Check(abs(box.reserve-3)<0.01,'part reserve: the widest state border');
  DrawStyleBox(box);
  gfx.CopyFromBackbuffer(0,0,img);
  CheckPixel(r.CenterPoint.X,r.CenterPoint.Y,$FF000000,'part fill drawn');
  Check(e.PixelWidth(0)=0,'PixelWidth(0)');
  Check(e.PixelWidth(0.2)>0,'PixelWidth of a thin line');
  Check(abs(e.PixelWidth(2)-2)<0.01,'PixelWidth(2) at scale 1');
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestStyleFill';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,200);
end;

procedure TTestApp.CreateScenes;
begin
  inherited;
  TTestScene.Create('Test',true,window);
  game.SwitchToScene('Test');
end;

{ TTestScene }

function TTestScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.canvasWidth,window.canvasHeight);
end;

procedure TTestScene.Render;
var
  outDir:String8;
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(frame);
  if frame<>3 then exit; // let the engine settle first
  try
    rt:=AllocImage(W,H,pfRenderTarget,aiTexture+aiRenderTarget+aiClampUV,'TestStyleFillRT');
    img:=TBitmapImage.Create(W,H,ipfARGB);
    root:=TUIElement.Create(W,H,nil);
    gfx.BeginPaint(rt);
    try
      gfx.target.Clear(BG,-1,-1);
      gfx.target.BlendMode(blAlpha);
      // the cross-fade test clears the target: it goes first
      TestCrossFade;
      TestDefaultButton;
      TestGradientBox;
      TestCornerRadii;
      TestEdgeScale;
      TestShadeLayer;
      TestHugeRadius;
      TestStateOnlyBox;
      TestStateOrder;
      TestStateTransitions;
      TestCheckedLook;
      TestBlendedValues;
      TestElementBox;
      TestPartBox;
      gfx.CopyFromBackbuffer(0,0,img);
      outDir:=String8(ExtractFilePath(ParamStr(0)))+'TestStyleFill/';
      Files.Save(outDir+'style_fill.png',SavePNG(img));
      writeln('Image: '+outDir+'style_fill.png');
    finally
      gfx.EndPaint;
      root.Free;
      FreeAndNil(img);
      FreeImage(rt);
    end;
  except
    on e:Exception do begin
      writeln('EXCEPTION: ',e.Message);
      inc(testsFailed);
    end;
  end;
  Signal('Engine\Cmd\Exit');
end;

var
  app:TTestApp;
begin
  app:=TTestApp.Create;
  app.Prepare;
  app.Run;
  app.Free;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
