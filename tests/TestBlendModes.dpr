// GPU test for blending modes of the stock shaders.
// Needs a real GL context (a window is shown), so CI only compiles it.
// blMove must replace every pixel of the drawn rectangle, transparent ones included:
// the stock shader drops transparent fragments in other modes, which would leave
// the previous content of the target under them.
{$APPTYPE CONSOLE}
program TestBlendModes;
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
  W=64;
  H=32;
  TEX_SIZE=32;
  GRAY=$FF808080; // previous content of the target
  CLEAR_TEXEL=$00112233; // left half of the texture: fully transparent
  SOLID_TEXEL=$FF445566; // right half: opaque
  TOLERANCE=1; // max per-channel difference, 0..255

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
  rt,tex:TTexture;
  img:TBitmapImage;

function HalfTexel(tex:TTexture;x,y:integer):cardinal;
begin
  if x<TEX_SIZE div 2 then result:=CLEAR_TEXEL
    else result:=SOLID_TEXEL;
end;

// Read the whole render target into img (the same image is refilled every time)
procedure ReadTarget;
begin
  if img=nil then img:=TBitmapImage.Create(W,H,ipfARGB);
  gfx.CopyFromBackbuffer(0,0,img);
end;

// Pixel (x,y) of the render target, y from the top
function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^;
end;

function SameColor(a,b:cardinal):boolean;
var
  i:integer;
begin
  for i:=0 to 3 do
    if abs(integer((a shr (i*8)) and $FF)-integer((b shr (i*8)) and $FF))>TOLERANCE then exit(false);
  result:=true;
end;

// Number of pixels in [x1..x2,y1..y2] that differ from the expected color
function CountWrong(x1,y1,x2,y2:integer;expected:cardinal):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=y1 to y2 do
    for x:=x1 to x2 do
      if not SameColor(Pixel(x,y),expected) then inc(result);
end;

// Number of pixels of the texture drawn at (ox,0) that differ from the texture
function CountWrongTexels(ox:integer):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=0 to TEX_SIZE-1 do
    for x:=0 to TEX_SIZE-1 do
      if not SameColor(Pixel(ox+x,y),HalfTexel(tex,x,y)) then inc(result);
end;

procedure TestFillRect;
begin
  StartTest('blMove: FillRect with a transparent color');
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear(GRAY,-1,-1);
    gfx.target.BlendMode(blMove);
    draw.FillRect(0,0,W-1,H-1,$00000000);
    gfx.target.BlendMode(blAlpha);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
  Check(CountWrong(0,0,W-1,H-1,$00000000)=0,'transparent fill left the previous content');
  EndTest;
end;

procedure TestTexture;
begin
  StartTest('blMove: transparent texels replace the target');
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear(GRAY,-1,-1);
    gfx.target.BlendMode(blMove);
    draw.Image(0,0,tex);
    gfx.target.BlendMode(blAlpha);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
  Check(CountWrongTexels(0)=0,'texture copy differs from the texture');
  EndTest;
end;

// The same shader serves both modes: the switch must take effect in both directions
procedure TestModeSwitch;
begin
  StartTest('Mode switch with the same shader');
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear(GRAY,-1,-1);
    gfx.target.BlendMode(blMove);
    draw.Image(0,0,tex);
    gfx.target.BlendMode(blAlpha);
    draw.Image(TEX_SIZE,0,tex);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
  Check(CountWrong(TEX_SIZE,0,TEX_SIZE+TEX_SIZE div 2-1,TEX_SIZE-1,GRAY)=0,'blAlpha: transparent texels changed the target');
  Check(CountWrong(TEX_SIZE+TEX_SIZE div 2,0,W-1,TEX_SIZE-1,SOLID_TEXEL)=0,'blAlpha: opaque texels not drawn');

  gfx.BeginPaint(rt);
  try
    gfx.target.BlendMode(blMove);
    draw.Image(TEX_SIZE,0,tex);
    gfx.target.BlendMode(blAlpha);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
  Check(CountWrongTexels(TEX_SIZE)=0,'blMove after blAlpha: texture copy differs from the texture');
  EndTest;
end;

// Readback contract: rows top-down, srcX/srcY from the top-left corner, any image pitch
procedure TestReadback;
const
  BLUE=$FF0000FF;
var
  flipped:TBitmapImage;

  function FlippedPixel(y:integer):cardinal;
  begin
    result:=PCardinal(flipped.ScanLine(y))^;
  end;

begin
  StartTest('Readback orientation and image pitch');
  flipped:=TBitmapImage.Create(W,H div 2,ipfARGB);
  try
    flipped.FlipVertical; // pitch<0: data points to the last row
    gfx.BeginPaint(rt);
    try
      gfx.target.Clear(GRAY,-1,-1);
      draw.FillRect(0,0,W-1,H div 2-1,BLUE); // top half
      ReadTarget;
      gfx.CopyFromBackbuffer(0,2,flipped); // rows 2..H/2+1: H/2-2 blue rows, then gray
    finally
      gfx.EndPaint;
    end;
    Check(CountWrong(0,0,W-1,H div 2-1,BLUE)=0,'top half is not on top');
    Check(CountWrong(0,H div 2,W-1,H-1,GRAY)=0,'bottom half is not at the bottom');
    Check(SameColor(FlippedPixel(0),BLUE) and SameColor(FlippedPixel(H div 2-3),BLUE) and
      SameColor(FlippedPixel(H div 2-2),GRAY) and SameColor(FlippedPixel(H div 2-1),GRAY),
      'negative pitch or srcY from the top: wrong rows');
  finally
    flipped.Free;
  end;
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestBlendModes';
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
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(frame);
  if frame<>3 then exit; // let the engine settle first
  try
    rt:=AllocImage(W,H,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestBlendRT');
    tex:=AllocImage(TEX_SIZE,TEX_SIZE,ipfARGB,aiTexture+aiClampUV,'TestBlendTex');
    try
      tex.Fill(@HalfTexel);
      TestFillRect;
      TestTexture;
      TestModeSwitch;
      TestReadback;
    finally
      FreeAndNil(img);
      FreeImage(tex);
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
