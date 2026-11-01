// GPU test for gradient fills of shapes (R-39).
// Needs a real GL context (a window is shown), so CI only compiles it.
// Each case draws into a render target over an opaque background and compares the
// result with a CPU reference: the shape by its signed distance (RoundRect) or by the
// geometry (FillRect, Polygon), the color by TFill evaluated on the CPU.
// Pixels of the antialiased bands (edge, border/fill boundary) are not compared.
// The rendered cases are saved to bin64/TestFillShapes/fill_shapes.png for a visual check.
{$APPTYPE CONSOLE}
program TestFillShapes;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Math,
  Apus.Core,
  Apus.Colors,
  Apus.Images,
  Apus.Files,
  Apus.GfxFormats,
  Apus.Geom2D,
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.GameApp,
  Apus.Engine.Scene;

{$I ..\Base\tests\Test.inc}

const
  W=640;
  H=200;
  BG=$FF283038;
  TOLERANCE=2; // max per-channel difference, 0..255
  AA_BAND=1.5; // pixels this close to an edge are not compared
  RAMP0=$FFFF4000;
  RAMP1=$FF0040FF;

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

  // where a pixel is: not compared, outside, in the border band, in the fill
  TRegion=(rgSkip,rgOutside,rgBorder,rgFill);
  TRegionFunc=function(px,py:integer;out d:single):TRegion;

var
  rt:TTexture;
  rampTex:TTexture;
  img,shot:TBitmapImage;
  // the shape under test
  box:TRect2;
  radii:TCornerRadii;
  borderW:single;
  poly:array[0..2] of TVec2;

function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^;
end;

// straight color over the opaque background
function Over(c:cardinal):cardinal;
var
  a:single;
  i:integer;
  cb,cf:cardinal;
begin
  a:=(c shr 24)/255;
  result:=$FF000000;
  for i:=0 to 2 do begin
    cb:=(BG shr (i*8)) and $FF;
    cf:=(c shr (i*8)) and $FF;
    result:=result or (cardinal(round(cb*(1-a)+cf*a)) shl (i*8));
  end;
end;

function SameRGB(c1,c2:cardinal):boolean;
var
  i:integer;
begin
  for i:=0 to 2 do
    if abs(integer((c1 shr (i*8)) and $FF)-integer((c2 shr (i*8)) and $FF))>TOLERANCE then exit(false);
  result:=true;
end;

function SDF(lx,ly,hw,hh:single;const r:TCornerRadii):single;
var
  rr,qx,qy:single;
begin
  if lx>0 then begin
    if ly>0 then rr:=r.bottomRight else rr:=r.topRight;
  end else begin
    if ly>0 then rr:=r.bottomLeft else rr:=r.topLeft;
  end;
  qx:=abs(lx)-hw+rr;
  qy:=abs(ly)-hh+rr;
  result:=sqrt(sqr(Max(qx,0))+sqr(Max(qy,0)))+Min(Max(qx,qy),0)-rr;
end;

function SpreadT(const f:TFill;t:single):single;
begin
  case f.spread of
    fsRepeat:t:=t-Floor(t);
    fsReflect:t:=1-abs(t-2*Floor(t*0.5)-1);
  end;
  result:=EnsureRange(t,0,1);
end;

// reference color of the fill at the pixel: d - signed distance to the shape edge
function RefColor(const f:TFill;px,py:integer;d,offset,edgeWidth:single):cardinal;
var
  t:single;
begin
  case f.kind of
    fkNone:exit(0);
    fkSolid:exit(f.stops[0].color);
    fkLinear:t:=f.ParamAt(px,py,box);
    fkEdge:begin
      if edgeWidth<=0 then edgeWidth:=f.p0.x;
      t:=-(d+offset)/edgeWidth;
    end;
    else t:=0;
  end;
  if f.ramp<>nil then
    result:=Color.Mix(RAMP0,RAMP1,SpreadT(f,t))
  else
    result:=f.ColorAtParam(t);
end;

function RoundRectRegion(px,py:integer;out d:single):TRegion;
begin
  d:=SDF(px-(box.x1+box.x2)*0.5,py-(box.y1+box.y2)*0.5,
    (box.x2-box.x1)*0.5,(box.y2-box.y1)*0.5,radii);
  if abs(d)<AA_BAND then exit(rgSkip);
  if d>0 then exit(rgOutside);
  if borderW>0 then begin
    if abs(d+borderW)<AA_BAND then exit(rgSkip);
    if d>-borderW then exit(rgBorder);
  end;
  result:=rgFill;
end;

function RectRegion(px,py:integer;out d:single):TRegion;
begin
  d:=0;
  if (px>box.x1) and (px<box.x2) and (py>box.y1) and (py<box.y2) then result:=rgFill
   else result:=rgOutside;
end;

// signed distance to the triangle edges (negative inside), counter-clockwise or not
function PolygonRegion(px,py:integer;out d:single):TRegion;
var
  i:integer;
  a,b:TVec2;
  e,l,s,sign:single;
begin
  sign:=(poly[1].x-poly[0].x)*(poly[2].y-poly[0].y)-(poly[1].y-poly[0].y)*(poly[2].x-poly[0].x);
  d:=-1E9;
  for i:=0 to 2 do begin
    a:=poly[i]; b:=poly[(i+1) mod 3];
    l:=sqrt(sqr(b.x-a.x)+sqr(b.y-a.y));
    e:=((b.x-a.x)*(py-a.y)-(b.y-a.y)*(px-a.x))/l;
    if sign>0 then s:=-e else s:=e;
    if s>d then d:=s;
  end;
  if abs(d)<AA_BAND then exit(rgSkip);
  if d>0 then result:=rgOutside else result:=rgFill;
end;

// Compares the render target with the reference; the case is drawn by the caller
procedure Compare(const name:string;region:TRegionFunc;const border,fill:TFill);
var
  px,py,bad:integer;
  d:single;
  exp,got:cardinal;
  first:string;
begin
  gfx.CopyFromBackbuffer(0,0,img);
  bad:=0; first:='';
  for py:=0 to H-1 do
    for px:=0 to W-1 do begin
      case region(px,py,d) of
        rgSkip:continue;
        rgOutside:exp:=BG;
        rgBorder:exp:=Over(RefColor(border,px,py,d,0,borderW));
        else exp:=Over(RefColor(fill,px,py,d,borderW,0));
      end;
      got:=Pixel(px,py);
      if not SameRGB(exp,got) then begin
        if bad=0 then first:=Format(' first at (%d,%d): expected %s got %s',[px,py,IntToHex(exp,8),IntToHex(got,8)]);
        inc(bad);
      end;
    end;
  Check(bad=0,Format('%s: %d pixels differ%s',[name,bad,first]));
end;

procedure BeginCase;
begin
  gfx.BeginPaint(rt);
  gfx.target.Clear(BG,-1,-1);
end;

// copies the case into the overview image at the slot
procedure EndCase(slot:integer);
var
  y:integer;
begin
  gfx.CopyFromBackbuffer(0,0,img);
  gfx.EndPaint;
  for y:=0 to H-1 do
    Move(img.ScanLine(y)^,PByte(UIntPtr(shot.ScanLine(slot*H+y)))^,W*4);
end;

procedure TestRoundRect(slot:integer;const name:string;x1,y1,x2,y2:integer;const r:TCornerRadii;bw:single;
  const border,fill:TFill);
begin
  StartTest('RoundRect: '+name);
  BeginCase;
  try
    box.Init(x1-0.5,y1-0.5,x2+0.5,y2+0.5);
    radii:=r;
    borderW:=bw;
    draw.RoundRect(x1,y1,x2,y2,r,bw,border,fill);
    Compare(name,RoundRectRegion,border,fill);
  finally
    EndCase(slot);
  end;
  EndTest;
end;

procedure TestRoundRects;
begin
  TestRoundRect(0,'solid border, linear fill',20,20,200,80,TCornerRadii.All(12),3,
    TFill.Solid($FFC8D4E8),TFill.Linear(180,$FF6F7F98,$FF435166));
  TestRoundRect(1,'corner radii, 3 stops at 45deg, no border',20,20,300,180,TCornerRadii.Init(0,40,12,70),0,
    TFill.None,TFill.Linear(45,$FFE06060,$FF50A0E0).AddStop(0.5,$FFF0F0A0));
  TestRoundRect(2,'frame: edge border, no fill',20,20,620,180,TCornerRadii.All(16),8,
    TFill.Edge(0,$FF5A6270,$FF3A4250).AddStop(0.4,$FFC8D0DC),TFill.None);
  TestRoundRect(3,'edge fill, translucent border',40,30,400,170,TCornerRadii.All(20),4,
    TFill.Solid($80FFFFFF),TFill.Edge(16,$FF203040,$FF80A0C0));
  TestRoundRect(4,'ramp fill, reflected',20,20,600,100,TCornerRadii.All(8),2,
    TFill.Solid($FFFFFFFF),TFill.Linear(TVec2.Init(0,0),TVec2.Init(0.25,0),0,0).WithRamp(rampTex).WithSpread(fsReflect));
  TestRoundRect(5,'fade to transparent',20,20,600,100,TCornerRadii.All(30),0,
    TFill.None,TFill.Linear(90,$FFFF2020,$00000000));
end;

procedure TestRect(slot:integer;const name:string;x1,y1,x2,y2:integer;const fill:TFill;expectSwitch:boolean);
var
  before:integer;
begin
  StartTest('FillRect: '+name);
  BeginCase;
  try
    box.Init(x1-0.5,y1-0.5,x2+0.5,y2+0.5);
    borderW:=0;
    draw.FillRect(0,0,1,1,BG); // the standard program is active
    before:=window.stats.shaderChanges;
    draw.FillRect(x1,y1,x2,y2,fill);
    Check((window.stats.shaderChanges>before)=expectSwitch,
      Format('program switch expected: %s, switches: %d',[BoolToStr(expectSwitch,true),window.stats.shaderChanges-before]));
    Compare(name,RectRegion,TFill.None,fill);
  finally
    EndCase(slot);
  end;
  EndTest;
end;

procedure TestRects;
begin
  TestRect(6,'2 colors: vertex colors',20,20,300,180,TFill.Linear(135,$FF000000,$FFFFFFFF),false);
  TestRect(7,'fade with equal RGB: vertex colors',20,20,600,180,TFill.Linear(90,$FFFF2020,$00FF2020),false);
  TestRect(8,'fade to transparent black: shader',20,20,600,180,TFill.Linear(90,$FFFF2020,$00000000),true);
  TestRect(9,'3 stops, repeat: shader',20,20,600,180,
    TFill.Linear(TVec2.Init(0,0),TVec2.Init(0.3,0.3),$FF73DCAA,$FF4B4EA9).AddStop(0.5,$FFE0E8F0).WithSpread(fsRepeat),true);
end;

procedure TestPolygons;
var
  fill:TFill;
begin
  StartTest('Polygon');
  poly[0]:=TVec2.Init(30,180);
  poly[1]:=TVec2.Init(320,15);
  poly[2]:=TVec2.Init(610,170);
  box.Init(30,15,610,180);
  borderW:=0;
  fill:=TFill.Linear(90,$FFE06060,$FF50A0E0).AddStop(0.3,$FFFFFFFF);
  BeginCase;
  try
    draw.Polygon(@poly[0],3,fill);
    Compare('3 stops',PolygonRegion,TFill.None,fill);
  finally
    EndCase(10);
  end;
  fill:=TFill.Linear(180,$FF40E040,$FF204080);
  BeginCase;
  try
    draw.Polygon(@poly[0],3,fill);
    Compare('2 stops',PolygonRegion,TFill.None,fill);
  finally
    EndCase(11);
  end;
  EndTest;
end;

procedure CreateRamp;
var
  i:integer;
  row:PCardinalRow;
begin
  rampTex:=AllocImage(256,1,ipfARGB,aiTexture+aiClampUV,'TestFillRamp');
  rampTex.Lock;
  row:=PCardinalRow(rampTex.ScanLine(0));
  for i:=0 to 255 do row^[i]:=Color.Mix(RAMP0,RAMP1,i/255);
  rampTex.Unlock;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestFillShapes';
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
    rt:=AllocImage(W,H,pfRenderTarget,aiTexture+aiRenderTarget+aiClampUV,'TestFillRT');
    img:=TBitmapImage.Create(W,H,ipfARGB);
    shot:=TBitmapImage.Create(W,H*12,ipfARGB);
    CreateRamp;
    try
      TestRoundRects;
      TestRects;
      TestPolygons;
      outDir:=String8(ExtractFilePath(ParamStr(0)))+'TestFillShapes/';
      Files.Save(outDir+'fill_shapes.png',SavePNG(shot));
      writeln('Image: '+outDir+'fill_shapes.png');
    finally
      FreeAndNil(img);
      FreeAndNil(shot);
      FreeImage(rampTex);
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
