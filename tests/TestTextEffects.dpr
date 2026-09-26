// GPU test for text effect layers (R-33).
// Needs a real GL context (a window is shown), so CI only compiles it.
// Each case draws text with DrawTextFX over an opaque background in a render
// target and compares the result with a CPU reference of the Engine 2 layer
// semantics built from the text mask (the same glyphs drawn by txt.Write):
// shift (bilinear) -> soft 3x3 -> box X -> box Y -> power -> layer color,
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

function Layer(blur:single;fastblurX,fastblurY:integer;color:cardinal;power:single;
  dx:single=0;dy:single=0):TTextEffectLayer;
begin
  result:=Default(TTextEffectLayer);
  result.enabled:=true;
  result.blur:=blur;
  result.fastblurX:=fastblurX;
  result.fastblurY:=fastblurY;
  result.color:=color;
  result.power:=power;
  result.dx:=dx;
  result.dy:=dy;
end;

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

// Layer alpha (before the layer color) from the text mask
function LayerAlpha(const mask:TPlane;const l:TTextEffectLayer):TPlane;
var
  shifted,soft,boxX:TPlane;
  x,y,cx,cy,i:integer;
  wt,sum,s,u:single;
  weights:array[-1..1,-1..1] of single;
begin
  SetLength(shifted,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do
      shifted[x+y*W]:=SampleBilinear(mask,x-l.dx,y-l.dy);
  // soft 3x3: weight 1/(0.01+blur+cx^2+cy^2), normalized
  sum:=0;
  for cy:=-1 to 1 do
    for cx:=-1 to 1 do begin
      if l.blur>0.01 then wt:=1/(0.01+l.blur+cx*cx+cy*cy)
        else if (cx=0) and (cy=0) then wt:=1
        else wt:=0;
      weights[cx,cy]:=wt;
      sum:=sum+wt;
    end;
  SetLength(soft,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      s:=0;
      for cy:=-1 to 1 do
        for cx:=-1 to 1 do
          s:=s+weights[cx,cy]*Sample(shifted,x+cx,y+cy);
      soft[x+y*W]:=s/sum;
    end;
  SetLength(boxX,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      s:=0;
      for i:=-l.fastblurX to l.fastblurX do s:=s+Sample(soft,x+i,y);
      boxX[x+y*W]:=s/(2*l.fastblurX+1);
    end;
  result:=nil;
  SetLength(result,W*H);
  for y:=0 to H-1 do
    for x:=0 to W-1 do begin
      s:=0;
      for i:=-l.fastblurY to l.fastblurY do s:=s+Sample(boxX,x,y+i);
      s:=s/(2*l.fastblurY+1);
      u:=Min(s*(1+l.power),1);
      result[x+y*W]:=u*(1-s)+s*s;
    end;
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
  glow:=Layer(10,10,10,$BBFFFFFF,1);
  outline:=Layer(2,2,2,$FF000000,0.8);
  shadow:=Layer(1,3,3,$C0000000,0.5,4,3);
  CheckCase('glow','Version 1.2.3',taLeft,$FF303840,$FF000000,[glow]);
  CheckCase('outline','12345',taLeft,$FF808080,$FFFFE080,[outline]);
  CheckCase('shadow','Shadow',taLeft,$FFC8BCA4,$FF402010,[shadow]);
  CheckCase('two layers','Glow + outline',taLeft,$FF203040,$FFFFFFFF,[glow,outline]);
  CheckCase('fractional shift','Offset',taLeft,$FFE0E0E0,$FF000000,[Layer(0,1,1,$FF2040C0,0.4,1.5,-2.5)]);
  EndTest;

  StartTest('Anchor matches txt.Write');
  invisible:=Layer(0,0,0,$00000000,0); // bakes a sprite with the text only
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
  glow:=Layer(2,4,4,$FFFFFF00,0.6);
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
