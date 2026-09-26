// GPU test for text effect layers (R-33).
// Needs a real GL context (a window is shown), so CI only compiles it.
// Each case draws text with DrawTextFX over an opaque background in a render
// target and compares the result with a CPU reference of the Engine 2 layer
// semantics built from the text mask (the same glyphs drawn by txt.Write):
// shift (bilinear) -> round dilation (spread) -> gaussian X -> gaussian Y -> layer color,
// layers stacked in order, text on top, the whole composite modulated by alpha.
{$APPTYPE CONSOLE}
program TestTextEffects;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Math,
  Apus.Core,
  Apus.Images,
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.GameApp,
  Apus.Engine.Scene,
  Apus.Engine.TextEffects;

{$I ..\Base\tests\Test.inc}

const
  W=512;
  H=128;
  TOLERANCE=2; // max per-channel difference, 0..255
  TEXT_X=60;
  TEXT_Y=80; // baseline

type
  TPlane=array of single; // W*H values

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
  font:TFontHandle;

// Read the whole render target into img. A fresh image every time: the readback
// flips it in place (data then points to the last row), so it can't be refilled
procedure ReadTarget;
begin
  FreeAndNil(img);
  img:=TBitmapImage.Create(W,H,ipfARGB);
  gfx.CopyFromBackbuffer(0,0,img);
end;

// Pixel (x,y) of the render target, y from the top. The readback of a render
// target comes out bottom-up (render targets are drawn flipped), so rows are mirrored
function Pixel(x,y:integer):cardinal;
begin
  result:=PCardinal(UIntPtr(img.data)+UIntPtr((H-1-y)*img.pitch+x*4))^;
end;

// Text mask: glyph coverage of txt.Write at the test anchor
function ReadMask(const st:String8;align:TTextAlignment):TPlane;
var
  x,y:integer;
begin
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear(0,-1,-1);
    gfx.target.BlendMode(blAlpha);
    txt.Write(font,TEXT_X,TEXT_Y,$FFFFFFFF,st,align);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
  result:=nil;
  SetLength(result,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      result[x+y*W]:=(Pixel(x,y) shr 24)/255;
end;

// Actual result: DrawTextFX over an opaque background
procedure DrawFX(bg,color:cardinal;const st:String8;align:TTextAlignment;
  const layers:array of TTextEffectLayer);
begin
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear(bg,-1,-1);
    gfx.target.BlendMode(blAlpha);
    DrawTextFX(font,TEXT_X,TEXT_Y,color,st,align,layers);
    ReadTarget;
  finally
    gfx.EndPaint;
  end;
end;

function Sample(const p:TPlane;x,y:integer):single; inline;
begin
  if (x<0) or (y<0) or (x>=W) or (y>=H) then result:=0
    else result:=p[x+y*W];
end;

// Bilinear sample at a fractional pixel position (pixel centers at integers)
function SampleBilinear(const p:TPlane;fx,fy:single):single;
var
  x0,y0:integer;
  ax,ay:single;
begin
  x0:=Floor(fx); y0:=Floor(fy);
  ax:=fx-x0; ay:=fy-y0;
  result:=(Sample(p,x0,y0)*(1-ax)+Sample(p,x0+1,y0)*ax)*(1-ay)+
          (Sample(p,x0,y0+1)*(1-ax)+Sample(p,x0+1,y0+1)*ax)*ay;
end;

// Gaussian blur along one axis (sigma = blur/3, kernel radius = ceil(3*sigma))
function Gauss(const src:TPlane;blur:single;dirX,dirY:integer):TPlane;
var
  x,y,i,r:integer;
  sigma,sum,s:single;
  weights:array of single;
begin
  sigma:=blur/3;
  r:=Ceil(3*sigma);
  weights:=nil;
  SetLength(weights,2*r+1);
  sum:=0;
  for i:=-r to r do begin
    weights[i+r]:=Exp(-i*i/(2*sigma*sigma+1e-6));
    sum:=sum+weights[i+r];
  end;
  result:=nil;
  SetLength(result,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      s:=0;
      for i:=-r to r do s:=s+weights[i+r]*Sample(src,x+i*dirX,y+i*dirY);
      result[x+y*W]:=s/sum;
    end;
end;

// Layer alpha (before the layer color) from the text mask
function LayerAlpha(const mask:TPlane;const l:TTextEffectLayer):TPlane;
var
  shifted,grown:TPlane;
  x,y,i,j,r:integer;
  wt,s:single;
begin
  shifted:=nil;
  SetLength(shifted,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      shifted[x+y*W]:=SampleBilinear(mask,x-l.dx,y-l.dy);
  // round dilation with an antialiased edge: max of w*a, w = clamp(spread+0.5-dist)
  r:=Ceil(l.spread);
  grown:=nil;
  SetLength(grown,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      s:=shifted[x+y*W];
      for j:=-r to r do
        for i:=-r to r do begin
          wt:=EnsureRange(l.spread+0.5-Sqrt(i*i+j*j),0,1);
          if wt>0 then s:=Max(s,wt*Sample(shifted,x+i,y+j));
        end;
      grown[x+y*W]:=s;
    end;
  result:=Gauss(Gauss(grown,l.blur,1,0),l.blur,0,1);
end;

function Channel(c:cardinal;shift:integer):single; inline;
begin
  result:=((c shr shift) and $FF)/255;
end;

// Compare img with the CPU reference; returns the max channel difference
function CompareWithReference(const mask:TPlane;bg,color:cardinal;
  const layers:array of TTextEffectLayer):integer;
var
  alphas:array of TPlane;
  i,x,y,ch,d,idx:integer;
  pr,pa,la,k:single;
  p:array[0..2] of single;
  actual:cardinal;
begin
  SetLength(alphas,length(layers));
  for i:=0 to high(layers) do
    alphas[i]:=LayerAlpha(mask,layers[i]);
  k:=Channel(color,24);
  result:=0;
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      idx:=x+y*W;
      // premultiplied accumulator
      pa:=0;
      for ch:=0 to 2 do p[ch]:=0;
      for i:=0 to high(layers) do begin
        la:=Channel(layers[i].color,24)*alphas[i][idx];
        for ch:=0 to 2 do p[ch]:=Channel(layers[i].color,ch*8)*la+p[ch]*(1-la);
        pa:=la+pa*(1-la);
      end;
      la:=mask[idx];
      for ch:=0 to 2 do p[ch]:=Channel(color,ch*8)*la+p[ch]*(1-la);
      pa:=la+pa*(1-la);
      // over the opaque background with the draw-time alpha
      actual:=Pixel(x,y);
      for ch:=0 to 2 do begin
        pr:=Channel(bg,ch*8)*(1-pa*k)+p[ch]*k;
        d:=abs(round(pr*255)-integer((actual shr (ch*8)) and $FF));
        if d>result then result:=d;
      end;
    end;
end;

function RunCase(const st:String8;align:TTextAlignment;bg,color:cardinal;
  const layers:array of TTextEffectLayer):integer;
var
  mask:TPlane;
begin
  mask:=ReadMask(st,align);
  DrawFX(bg,color,st,align,layers);
  result:=CompareWithReference(mask,bg,color,layers);
end;

procedure CheckCase(const name:String8;const st:String8;align:TTextAlignment;bg,color:cardinal;
  const layers:array of TTextEffectLayer);
var
  diff:integer;
begin
  diff:=RunCase(st,align,bg,color,layers);
  Check(diff<=TOLERANCE,Format('%s: max difference %d > %d',[name,diff,TOLERANCE]));
end;

procedure TestSemantics;
var
  glow,outline,shadow,invisible:TTextEffectLayer;
begin
  StartTest('Layer semantics vs CPU reference');
  glow:=TTextEffectLayer.Glow($BBFFFFFF,10,1);
  outline:=TTextEffectLayer.Outline($FF000000,2);
  shadow:=TTextEffectLayer.Shadow($C0000000,4,3,3);
  CheckCase('glow','Version 1.2.3',taLeft,$FF303840,$FF000000,[glow]);
  CheckCase('outline','12345',taLeft,$FF808080,$FFFFE080,[outline]);
  CheckCase('shadow','Shadow',taLeft,$FFC8BCA4,$FF402010,[shadow]);
  CheckCase('fractional spread','Spread',taLeft,$FF808080,$FFFFFFFF,[TTextEffectLayer.Outline($FF000000,1.6,0)]);
  CheckCase('large blur','Blur',taLeft,$FF101010,$FFFFFFFF,[TTextEffectLayer.Glow($FF40A0FF,24,2)]);
  CheckCase('two layers','Glow + outline',taLeft,$FF203040,$FFFFFFFF,[glow,outline]);
  CheckCase('fractional shift','Offset',taLeft,$FFE0E0E0,$FF000000,[TTextEffectLayer.Shadow($FF2040C0,1.5,-2.5,1.5)]);
  EndTest;

  StartTest('Anchor matches txt.Write');
  invisible:=TTextEffectLayer.Glow($00000000,0); // bakes a sprite with the text only
  CheckCase('left','Anchor',taLeft,$FF303030,$FFFFFFFF,[invisible]);
  CheckCase('center','Anchor',taCenter,$FF303030,$FFFFFFFF,[invisible]);
  CheckCase('right','Anchor',taRight,$FF303030,$FFFFFFFF,[invisible]);
  EndTest;
end;

procedure TestCache;
var
  glow:TTextEffectLayer;
  i:integer;
begin
  glow:=TTextEffectLayer.Glow($FFFFFF00,6,1);
  StartTest('Cache: alpha outside the key');
  CheckCase('opaque','Fade',taLeft,$FF404040,$FF80C0FF,[glow]);
  CheckCase('alpha 0.5','Fade',taLeft,$FF404040,$8080C0FF,[glow]); // same sprite, modulated
  CheckCase('alpha 0.2','Fade',taLeft,$FF404040,$3380C0FF,[glow]);
  EndTest;

  StartTest('Cache: eviction and re-bake');
  gfx.BeginPaint(rt);
  try
    for i:=1 to 80 do // more than the cache holds
      DrawTextFX(font,TEXT_X,TEXT_Y,$FFFFFFFF,'Item '+IntToStr(i),taLeft,[glow]);
  finally
    gfx.EndPaint;
  end;
  CheckCase('evicted entry','Item 1',taLeft,$FF404040,$FFFFFFFF,[glow]);
  CheckCase('recent entry','Item 80',taLeft,$FF404040,$FFFFFFFF,[glow]);
  FlushTextFXCache;
  CheckCase('after flush','Item 80',taLeft,$FF404040,$FFFFFFFF,[glow]);
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestTextEffects';
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
    font:=game.defaultFont;
    rt:=AllocImage(W,H,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestTextFX');
    try
      TestSemantics;
      TestCache;
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
