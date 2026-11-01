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
