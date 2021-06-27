// Advanced texturing features demo:
// - Texture Array
// - Manual Mip-Map levels
program AdvTex;
 uses Apus.MyServis, SysUtils, Types, Apus.EventMan, Apus.Engine.API,
   Apus.Engine.GameApp, Apus.Engine.UIScene, Apus.Engine.UIClasses,
   Apus.FastGFX, Apus.Engine.ResManGL;

 type
  TMainScene=class(TUIScene)
   constructor Create;
   procedure Initialize; override;
   procedure Render; override;
  private
   mipTex:TTexture;
   arrTex:TGLTextureArray;
   arrShader:TShader;
  end;

 var
  application:TGameApplication;
  mainFont:cardinal;

procedure CreateScenes;
 begin
  mainFont:=txt.GetFont('Default',9);
  TMainScene.Create;
 end;

constructor TMainScene.Create;
 begin
  inherited Create('MainScene');
  SetStatus(ssActive);
 end;

procedure TMainScene.Initialize;
 var
  x,y,z:integer;
 begin
  inherited;
  mipTex:=gfx.resman.AllocImage(128,128,TImagePixelFormat.ipfARGB,0{aiMipMapping},'mipTex');
  DrawToTexture(mipTex,0);
  for y:=0 to 127 do
   for x:=0 to 127 do
    PutPixel(x,y,$FF203040+x+$C00000*byte(y and 15<2)+$A000*byte(x and 15<2));
  mipTex.Unlock;
  DrawToTexture(mipTex,1);
  for y:=0 to 63 do
   for x:=0 to 63 do
    PutPixel(x,y,$FF101010+y*2+$C00000*byte(y and 7<1)+$A000*byte(x and 7<1));
  mipTex.Unlock;

  arrTex:=resourceManagerGL.AllocArray(128,128,TImagePixelFormat.ipfARGB,4,0,'arrTex');
  for z:=0 to 3 do begin
   arrTex.Lock(z);
   SetRenderTarget(arrTex.data,arrTex.pitch,128,128);
   for y:=0 to 127 do
    for x:=0 to 127 do
     PutPixel(x,y,$FF203040+x*5+(y) shl 8+(z*70) shl 16);
   arrTex.Unlock;
  end;
  arrShader:=shader.Load('res\arrShader');
 end;

procedure TMainScene.Render;
 var
  i:integer;
  scale:single;
 begin
  gfx.target.Clear($FF000000);
  scale:=0.9+0.6*sin(MyTickCount/1000);
  mipTex.SetFilter(fltNearest);
  draw.RotScaled(120,50,0.4,0.4,0,mipTex);
  draw.RotScaled(120,150,1,1,0,mipTex);
  draw.RotScaled(120,320,1.6,1.6,0,mipTex);
  draw.RotScaled(120,550,scale,scale,0,mipTex);
  mipTex.SetFilter(fltBilinear);
  draw.RotScaled(340,50,0.4,0.4,0,mipTex);
  draw.RotScaled(340,150,1,1,0,mipTex);
  draw.RotScaled(340,320,1.6,1.6,0,mipTex);
  draw.RotScaled(340,550,scale,scale,0,mipTex);
  mipTex.SetFilter(fltTrilinear);
  draw.RotScaled(580,50,0.4,0.4,0,mipTex);
  draw.RotScaled(580,150,1,1,0,mipTex);
  draw.RotScaled(580,320,1.6,1.6,0,mipTex);
  draw.RotScaled(580,550,scale,scale,0,mipTex);

  // Texture array
  shader.UseCustom(arrShader);
  draw.Image(800,20,arrTex);
  shader.Reset;
 end;

begin
 usedAPI:=gaOpenGL2;
 useDefaultLoaderScene:=false;
 //usedPlatform:=spSDL;
 //directRenderOnly:=false;

 LinkProc('GameApp\CreateScenes',CreateScenes);
 application:=TGameApplication.Create;
 application.Prepare;
 if DirectoryExists('..\Demo\AdvTex') then
  SetCurrentDir('..\Demo\AdvTex');
 application.Run;
 application.Free;
end.
