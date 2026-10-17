// GPU test for the pixel grid of the 2D primitives, on a canvas that matches the target
// and on one scaled by the projection (Viewport with a smaller virtual size).
// A virtual pixel is a cell of pixelRatio real pixels: fills cover whole cells, frames
// (Rect, RRect) lie on the outer real pixels of their cells, hairlines are one real pixel.
// Needs a real GL context (a window is shown), so CI only compiles it.
{$APPTYPE CONSOLE}
program TestPixelGrid;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Apus.Core,
  Apus.Images,
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.GameApp,
  Apus.Engine.Scene;

{$I ..\Base\tests\Test.inc}

const
  W=96;
  H=96;
  GRAY=$FF808080; // background
  RED=$FFC02020;
  WHITE=$FFFFFFFF;
  LIGHT=$FFE0E0E0;
  DARK=$FF404040;

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

  TMask=array[0..H-1,0..W-1] of boolean;

var
  rt:TTexture;
  img:TBitmapImage;

// Start drawing into the target with the given virtual size (real size is W x H)
procedure BeginTarget(virtualW,virtualH:integer);
begin
  gfx.BeginPaint(rt);
  gfx.target.Viewport(0,0,W,H,virtualW,virtualH);
  gfx.target.Clear(GRAY,-1,-1);
end;

// Read the target back and finish drawing
procedure EndTarget;
begin
  if img=nil then img:=TBitmapImage.Create(W,H,ipfARGB);
  try
    gfx.CopyFromBackbuffer(0,0,img);
  finally
    gfx.EndPaint;
  end;
end;

// Real pixel (x,y) of the target, y from the top
function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^;
end;

// Number of real pixels in [x1..x2,y1..y2] that differ from the expected color
function CountWrong(x1,y1,x2,y2:integer;expected:cardinal):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=y1 to y2 do
    for x:=x1 to x2 do
      if Pixel(x,y)<>expected then inc(result);
end;

// Pixels that are not background
procedure ReadMask(out mask:TMask);
var
  x,y:integer;
begin
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      mask[y,x]:=Pixel(x,y)<>GRAY;
end;

// Pixels of a that are on its edge (a 4-neighbour is outside a)
function IsEdge(const a:TMask;x,y:integer):boolean;
begin
  result:=a[y,x] and ((x=0) or (y=0) or (x=W-1) or (y=H-1) or
    not a[y,x-1] or not a[y,x+1] or not a[y-1,x] or not a[y+1,x]);
end;

// Number of pixels of a outside b
function CountOutside(const a,b:TMask):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      if a[y,x] and not b[y,x] then inc(result);
end;

// Number of edge pixels of a not covered by b
function CountEdgeUncovered(const a,b:TMask):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      if IsEdge(a,x,y) and not b[y,x] then inc(result);
end;

// FillRect covers whole cells: virtual 4..11 at ratio k = real 4k..12k-1
procedure TestFill(k:integer);
begin
  StartTest('FillRect, ratio '+IntToStr(k));
  BeginTarget(W div k,H div k);
  draw.FillRect(4,4,11,11,RED);
  EndTarget;
  Check(CountWrong(4*k,4*k,12*k-1,12*k-1,RED)=0,'cells not filled');
  Check(CountWrong(4*k-1,4*k-1,12*k,4*k-1,GRAY)+CountWrong(4*k-1,12*k,12*k,12*k,GRAY)+
    CountWrong(4*k-1,4*k,4*k-1,12*k-1,GRAY)+CountWrong(12*k,4*k,12*k,12*k-1,GRAY)=0,'fill outside the cells');
  BeginTarget(W div k,H div k);
  draw.FillRect(0,0,W div k-1,H div k-1,RED);
  EndTarget;
  Check(CountWrong(0,0,W-1,H-1,RED)=0,'full-target fill leaves a gap');
  EndTest;
end;

// Rect frames FillRect with the same corners: on the outer real pixels of the cells
procedure TestFrame(k:integer);
var
  a,b:integer;
begin
  StartTest('Rect frames FillRect, ratio '+IntToStr(k));
  BeginTarget(W div k,H div k);
  draw.FillRect(4,4,11,11,RED);
  draw.Rect(4,4,11,11,WHITE);
  EndTarget;
  a:=4*k; b:=12*k-1; // outer real pixels of the cells
  Check(CountWrong(a,a,b,a,WHITE)+CountWrong(a,b,b,b,WHITE)=0,'top/bottom side off the fill edge');
  Check(CountWrong(a,a,a,b,WHITE)+CountWrong(b,a,b,b,WHITE)=0,'left/right side off the fill edge');
  Check(CountWrong(a+1,a+1,b-1,b-1,RED)=0,'frame inside the fill');
  Check(CountWrong(a-1,a-1,b+1,a-1,GRAY)+CountWrong(a-1,b+1,b+1,b+1,GRAY)+
    CountWrong(a-1,a,a-1,b,GRAY)+CountWrong(b+1,a,b+1,b,GRAY)=0,'frame outside the fill');
  EndTest;
end;

// A horizontal hairline is one real pixel: the first real row of its cells
procedure TestLine(k:integer);
begin
  StartTest('Line, ratio '+IntToStr(k));
  BeginTarget(W div k,H div k);
  draw.Line(2,20,10,20,WHITE);
  EndTarget;
  // the end pixels depend on the line rasterization rule: check the inner part
  Check(CountWrong(2*k+1,20*k,10*k-2,20*k,WHITE)=0,'line not on the first real row of the cells');
  Check(CountWrong(2*k,20*k-1,10*k-1,20*k-1,GRAY)+CountWrong(2*k,20*k+1,10*k-1,20*k+1,GRAY)=0,'line wider than a real pixel');
  EndTest;
end;

// ShadedRect: light top and left sides, dark right and bottom ones, top-right and
// bottom-left corners empty; one virtual pixel wide at any ratio
procedure TestShaded(k:integer);

  // virtual cells x1..x2, y1..y2 (inclusive) in real pixels
  function Wrong(x1,y1,x2,y2:integer;expected:cardinal):integer;
  begin
    result:=CountWrong(x1*k,y1*k,(x2+1)*k-1,(y2+1)*k-1,expected);
  end;

begin
  StartTest('ShadedRect, ratio '+IntToStr(k));
  BeginTarget(W div k,H div k);
  draw.ShadedRect(4,4,11,11,1,LIGHT,DARK);
  EndTarget;
  Check(Wrong(4,4,10,4,LIGHT)=0,'top side');
  Check(Wrong(4,5,4,10,LIGHT)=0,'left side');
  Check(Wrong(11,5,11,11,DARK)=0,'right side');
  Check(Wrong(5,11,10,11,DARK)=0,'bottom side');
  Check(Wrong(11,4,11,4,GRAY)+Wrong(4,11,4,11,GRAY)=0,'corners');
  Check(Wrong(5,5,10,10,GRAY)=0,'inside');
  Check(Wrong(3,3,12,3,GRAY)+Wrong(3,12,12,12,GRAY)+Wrong(3,4,3,11,GRAY)+Wrong(12,4,12,11,GRAY)=0,'outside');
  EndTest;
end;

// Frames over fills of the same shape at a ratio (virtual size = W*den/num):
// the frame covers the edge of the fill and stays inside it
procedure TestShapes(num,den:integer);
var
  fill,frame:TMask;
  vw,vh:integer;
begin
  StartTest('Frame vs fill, ratio '+IntToStr(num)+'/'+IntToStr(den));
  vw:=W*den div num; vh:=H*den div num;
  BeginTarget(vw,vh);
  draw.FillRRect(4,5,vw-6,vh-5,RED,6);
  EndTarget;
  ReadMask(fill);
  BeginTarget(vw,vh);
  draw.RRect(4,5,vw-6,vh-5,1,6,WHITE);
  EndTarget;
  ReadMask(frame);
  Check(CountOutside(frame,fill)=0,'RRect(width) goes outside FillRRect');
  Check(CountEdgeUncovered(fill,frame)=0,'RRect(width) misses the edge of FillRRect');

  BeginTarget(vw,vh);
  draw.FillRect(4,5,vw-6,vh-5,RED);
  EndTarget;
  ReadMask(fill);
  BeginTarget(vw,vh);
  draw.Rect(4,5,vw-6,vh-5,WHITE);
  EndTarget;
  ReadMask(frame);
  Check(CountOutside(frame,fill)=0,'Rect goes outside FillRect');
  Check(CountEdgeUncovered(fill,frame)=0,'Rect misses the edge of FillRect');
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestPixelGrid';
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
  k:integer;
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(frame);
  if frame<>3 then exit; // let the engine settle first
  try
    rt:=AllocImage(W,H,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestPixelGridRT');
    try
      for k:=1 to 2 do begin
        TestFill(k);
        TestFrame(k);
        TestLine(k);
        TestShaded(k);
      end;
      TestShapes(1,1);
      TestShapes(2,1);
      TestShapes(3,2);
      TestShapes(5,4);
    finally
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
