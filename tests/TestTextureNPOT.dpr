// NPOT textures: mip-mapped loading without POT padding, explicit POT padding (liffPow2),
// mip levels of odd sizes. Requires a GL window: the smoke suites only compile it, run it locally.
{$APPTYPE CONSOLE}
program TestTextureNPOT;
uses
 {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
 SysUtils,Types,Apus.Core,Apus.Types,Apus.Images,Apus.Files,Apus.GfxFormats,Apus.EventMan,
 Apus.Engine.API,Apus.Engine.Types,Apus.Engine.Resources,Apus.Engine.ImageTools,Apus.Engine.GameApp,
 Apus.Engine.Scene,Apus.Engine.ResManGL;
{$I ..\Base\tests\Test.inc}
type
 TTestApp=class(TGameApplication)
  procedure SetupApplication;override;
  procedure CreateScenes;override;
 end;
 TTestScene=class(TGameScene)
  frame:integer;
  procedure Render;override;
  function GetArea:TRect;override;
 end;

const
 RT_SIZE=16;
 // an icon atlas as in PaintRaw E-18: three 64x64 cells with 8 px gaps, 208x64
 RED=$FFC81E0A;
 GREEN=$FF0AB432;
 BLUE=$FF1E3CC8;
var
 rt:TTexture;
 img:TBitmapImage;
 dir:String8;

procedure WriteAtlas(const name:String8);
var
 atlas:TBitmapImage;
 x,y:integer;
 c:cardinal;
begin
 atlas:=TBitmapImage.Create(208,64,ipfARGB);
 try
  for y:=0 to 63 do
   for x:=0 to 207 do begin
    case x of
     0..63:c:=RED;
     72..135:c:=GREEN;
     144..207:c:=BLUE;
    else
     c:=0; // transparent gap
    end;
    PCardinal(UIntPtr(atlas.ScanLine(y))+UIntPtr(x*4))^:=c;
   end;
  Files.Save(name,SavePNG(atlas));
 finally
  atlas.Free;
 end;
end;

// What the GPU samples: the texture stretched over the render target, the center pixel
function Drawn(tex:TTexture):cardinal;
begin
 gfx.BeginPaint(rt);
 try
  gfx.target.Clear($FF000000,-1,-1);
  draw.Scaled(0,0,RT_SIZE,RT_SIZE,tex);
  gfx.CopyFromBackbuffer(0,0,img);
  result:=PCardinal(UIntPtr(img.ScanLine(RT_SIZE div 2))+UIntPtr((RT_SIZE div 2)*4))^;
 finally
  gfx.EndPaint;
 end;
end;

function DrawnCell(tex:TTexture;cell:integer):cardinal;
var
 part:TTexture;
begin
 part:=tex.ClonePart(Rect(cell*72,0,cell*72+64,64));
 try
  result:=Drawn(part);
 finally
  FreeImage(part);
 end;
end;

procedure TestMipMapped;
var
 tex:TTexture;
begin
 StartTest('Mip-mapped NPOT image is not padded');
 tex:=LoadImageFromFile(dir+'atlas.png',liffMipMaps);
 try
  Check((TGLTexture(tex).realWidth=208) and (TGLTexture(tex).realHeight=64),'storage keeps the image size');
  Check((tex.u2=1) and (tex.v2=1),'the image covers the whole storage');
  Check(tex.HasFlag(tfAutoMipMap) and (tex.mipmaps=TGLTexture.MAX_LEVEL),'mip levels: '+IntToStr(tex.mipmaps));
  // 64 px cells drawn in 16 px: sampled from the mip levels
  Check(DrawnCell(tex,0)=RED,'cell 0');
  Check(DrawnCell(tex,1)=GREEN,'cell 1');
  Check(DrawnCell(tex,2)=BLUE,'cell 2');
 finally
  FreeImage(tex);
 end;
 EndTest;
end;

procedure TestPadded;
var
 tex:TTexture;
begin
 StartTest('Explicit POT padding (liffPow2)');
 tex:=LoadImageFromFile(dir+'atlas.png',liffPow2);
 try
  Check((TGLTexture(tex).realWidth=256) and (tex.width=208),'storage is padded');
  Check(DrawnCell(tex,0)=RED,'cell 0');
  Check(DrawnCell(tex,1)=GREEN,'cell 1');
  Check(DrawnCell(tex,2)=BLUE,'cell 2');
 finally
  FreeImage(tex);
 end;
 EndTest;
end;

// Reading back a padded texture: GL returns the whole storage level, the CPU copy keeps the image
procedure TestPaddedReadBack;
var
 tex:TTexture;
 buf:array of cardinal;
 x,y:integer;
 function At(x,y:integer):cardinal;
  begin
   result:=PCardinal(UIntPtr(tex.data)+UIntPtr(y*tex.pitch+x*4))^;
  end;
begin
 StartTest('Read back of a padded texture');
 tex:=AllocImage(208,64,ipfARGB,aiTexture+aiPow2,'PaddedReadBack');
 try
  gfx.resman.MakeOnline(tex);
  SetLength(buf,208*64);
  for y:=0 to 63 do
   for x:=0 to 207 do
    buf[x+y*208]:=$FF000000 or cardinal(x) or cardinal(y) shl 8;
  tex.UploadPart(0,0,0,208,64,@buf[0],208*4,ipfARGB);
  tex.Lock(0,lmReadOnly);
  try
   Check(tex.pitch=208*4,'pitch of the image');
   Check(At(0,0)=$FF000000,'first pixel');
   Check(At(5,3)=$FF000305,'row 3');
   Check(At(207,63)=$FF003FCF,'last pixel');
  finally
   tex.Unlock;
  end;
 finally
  FreeImage(tex);
 end;
 EndTest;
end;

// A mip level of an odd size: the full lock rect is the size of the level
procedure TestOddLevel;
var
 tex:TTexture;
 x,y:integer;
 ok:boolean;
begin
 StartTest('Mip levels of odd sizes');
 tex:=AllocImage(5,3,ipfARGB,aiTexture+aiAutoMipmap,'OddAuto');
 Check(tex.mipmaps=2,'5x3 has levels 0..2: '+IntToStr(tex.mipmaps));
 FreeImage(tex);
 tex:=AllocImage(101,51,1,ipfARGB,aiTexture,'OddLevel');
 try
  tex.Lock(1);
  try
   Check(tex.pitch=50*4,'level 1 is 50 wide');
   for y:=0 to 24 do
    for x:=0 to 49 do PCardinal(UIntPtr(tex.data)+UIntPtr(y*tex.pitch+x*4))^:=GREEN;
  finally
   tex.Unlock;
  end;
  ok:=true;
  try
   gfx.resman.MakeOnline(tex);
  except
   on e:Exception do begin
    ok:=false;
    writeln(e.Message);
   end;
  end;
  Check(ok,'level 1 uploaded');
 finally
  FreeImage(tex);
 end;
 EndTest;
end;

procedure TTestApp.SetupApplication;
begin
 inherited;appSetup.title:='TestTextureNPOT';requestBackend.graphicsAPI:=gaOpenGL2;
 windowSetup.size:=MakeSize(320,200);
end;
procedure TTestApp.CreateScenes;
begin
 inherited;TTestScene.Create('Test',true,window);game.SwitchToScene('Test');
end;
function TTestScene.GetArea:TRect;
begin result:=Rect(0,0,window.canvasWidth,window.canvasHeight);end;
procedure TTestScene.Render;
begin
 gfx.target.Clear($FF202020,-1,-1);inc(frame);if frame<>3 then exit;
 dir:=String8(ExtractFilePath(ParamStr(0)))+'../tests/_fpc/texture-npot-fixture/';
 ForceDirectories(string(dir));
 rt:=AllocImage(RT_SIZE,RT_SIZE,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestTextureNPOTRT');
 img:=TBitmapImage.Create(RT_SIZE,RT_SIZE,ipfARGB);
 try
  try
   WriteAtlas(dir+'atlas.png');
   TestMipMapped;
   TestPadded;
   TestPaddedReadBack;
   TestOddLevel;
  finally
   FreeImage(rt);img.Free;
  end;
 except on e:Exception do begin writeln('EXCEPTION: ',e.Message);inc(testsFailed);end;end;
 Signal('Engine\Cmd\Exit');
end;

var app:TTestApp;
begin
 app:=TTestApp.Create;
 try app.Prepare;app.Run;finally app.Free;end;
 if testsFailed=0 then writeln('All tests passed ('+IntToStr(testsTotal)+')')
 else begin writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));ExitCode:=1;end;
 if IsDebuggerPresent then readln;
end.
