// GPU test for the final frame output (BlitScaled, used by TWindow.BlitDefaultRT): at an
// integer scale k every k-th pixel is a source pixel as is, the pixels between are
// interpolated, the last k-1 repeat the last source pixel; 1:1 copies the source.
// Needs a real GL context (a window is shown), so CI only compiles it; run it locally
// with -ROBOT=VIRTUAL to keep the window under the active one.
{$APPTYPE CONSOLE}
program TestBlitScaled;
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
  Apus.Engine.Scene,
  Apus.Engine.Window;

{$I ..\Base\tests\Test.inc}

const
  SW=8; // source size
  SH=8;
  DW=SW*3; // largest output
  DH=SH*3;
  TOLERANCE=2; // per channel: interpolation rounding

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
  src,dst:TTexture;
  img:TBitmapImage;
  srcPix:array[0..SH-1,0..SW-1] of cardinal;

// Source pattern: gray levels that differ along both axes and at the edges
function SourceColor(x,y:integer):cardinal;
var
  r,g:cardinal;
begin
  r:=(x*255) div (SW-1);
  if x=SW div 2 then r:=255-r; // a dip in the middle
  g:=(y*255) div (SH-1);
  result:=$FF000000+r shl 16+g shl 8+((x+y) and 1)*$C0;
end;

// Fill the source target pixel by pixel
procedure DrawSource;
var
  x,y:integer;
begin
  gfx.BeginPaint(src);
  try
    gfx.target.Viewport(0,0,SW,SH,SW,SH);
    gfx.target.Clear($FF000000,-1,-1);
    for y:=0 to SH-1 do
      for x:=0 to SW-1 do begin
        srcPix[y,x]:=SourceColor(x,y);
        draw.FillRect(x,y,x,y,srcPix[y,x]);
      end;
  finally
    gfx.EndPaint;
  end;
end;

// Output the source scaled to w x h into dst and read it back
procedure Output(w,h:integer);
begin
  gfx.BeginPaint(dst);
  try
    gfx.target.Viewport(0,0,DW,DH,DW,DH);
    gfx.target.Clear($FF000000,-1,-1);
    BlitScaled(src,Rect(0,0,w,h),$FF808080);
    gfx.CopyFromBackbuffer(0,0,img);
  finally
    gfx.EndPaint;
  end;
end;

function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.ScanLine(y))+UIntPtr(x*4))^;
end;

// Color at t of the way from a to b, per channel
function Mix(a,b:cardinal;t:double):cardinal;
var
  i:integer;
  ca,cb:integer;
begin
  result:=0;
  for i:=0 to 3 do begin
    ca:=(a shr (i*8)) and $FF;
    cb:=(b shr (i*8)) and $FF;
    result:=result or (cardinal(round(ca+(cb-ca)*t)) shl (i*8));
  end;
end;

function Close(a,b:cardinal):boolean;
var
  i:integer;
begin
  for i:=0 to 3 do
    if abs(integer((a shr (i*8)) and $FF)-integer((b shr (i*8)) and $FF))>TOLERANCE then exit(false);
  result:=true;
end;

// Expected output at (x,y) for the integer scale k: bilinear between the source centers on
// every k-th pixel, the source edge repeated past the last center
function Expected(x,y,k:integer):cardinal;
var
  sx,sy:integer;
  tx,ty:double;
begin
  sx:=x div k; tx:=(x mod k)/k;
  sy:=y div k; ty:=(y mod k)/k;
  if sx>=SW-1 then begin sx:=SW-2; tx:=1; end;
  if sy>=SH-1 then begin sy:=SH-2; ty:=1; end;
  result:=Mix(Mix(srcPix[sy,sx],srcPix[sy,sx+1],tx),Mix(srcPix[sy+1,sx],srcPix[sy+1,sx+1],tx),ty);
end;

// Number of output pixels in [x1..x2,y1..y2] that differ from Expected
function CountWrong(x1,y1,x2,y2,k:integer):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=y1 to y2 do
    for x:=x1 to x2 do
      if not Close(Pixel(x,y),Expected(x,y,k)) then inc(result);
end;

// Number of source pixels not kept as is on every k-th output pixel
function CountLostSamples(k:integer):integer;
var
  x,y:integer;
begin
  result:=0;
  for y:=0 to SH-1 do
    for x:=0 to SW-1 do
      if Pixel(x*k,y*k)<>srcPix[y,x] then inc(result);
end;

procedure TestCopy;
begin
  StartTest('Scale 1: a copy');
  Output(SW,SH);
  Check(CountLostSamples(1)=0,'the output differs from the source');
  EndTest;
end;

procedure TestScale(k:integer);
var
  w,h:integer;
begin
  StartTest('Scale '+IntToStr(k));
  w:=SW*k; h:=SH*k;
  Output(w,h);
  Check(CountLostSamples(k)=0,'source pixels are not kept on every '+IntToStr(k)+'-th pixel');
  Check(CountWrong(0,0,w-k,h-k,k)=0,'pixels between the source ones are not interpolated');
  Check(CountWrong(w-k+1,0,w-1,h-1,k)+CountWrong(0,h-k+1,w-k,h-1,k)=0,
    'the right/bottom edge does not repeat the last source pixel');
  EndTest;
end;

// A fractional scale keeps the old mapping: the texture edges on the output edges, so the
// corner pixels come from the corner source pixels and the opposite edge is not mixed in
procedure TestFractional;
begin
  StartTest('Scale 1.5: edges');
  Output(SW*3 div 2,SH*3 div 2);
  Check(Close(Pixel(0,0),srcPix[0,0]) and Close(Pixel(SW*3 div 2-1,SH*3 div 2-1),srcPix[SH-1,SW-1]),
    'corner pixels do not match the source corners');
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestBlitScaled';
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
    src:=AllocImage(SW,SH,pfRenderTarget,aiTexture+aiRenderTarget+aiClampUV,'TestBlitScaledSrc');
    dst:=AllocImage(DW,DH,pfRenderTarget,aiTexture+aiRenderTarget+aiClampUV,'TestBlitScaledDst');
    img:=TBitmapImage.Create(DW,DH,ipfARGB);
    try
      DrawSource;
      TestCopy;
      TestScale(2);
      TestScale(3);
      TestFractional;
    finally
      FreeAndNil(img);
      FreeImage(dst);
      FreeImage(src);
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
