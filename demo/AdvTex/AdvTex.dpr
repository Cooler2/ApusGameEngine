// Advanced texturing features demo:
// - Texture Array
// - Manual Mip-Map levels
program AdvTex;
 uses Apus.MyServis, SysUtils, Types, Apus.Colors, Apus.EventMan, Apus.Engine.API,
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
    PutPixel(x,y,MyColor($C0*byte(y and 15<2),$A0*byte(x and 15<2),x*2));
  mipTex.Unlock;
  DrawToTexture(mipTex,1);
  for y:=0 to 63 do
   for x:=0 to 63 do
    PutPixel(x,y,MyColor($C0*byte(y and 7<1),$A0*byte(x and 7<1),0));
  mipTex.Unlock;

  // 4 layers texture array
  arrTex:=resourceManagerGL.AllocArray(128,128,TImagePixelFormat.ipfARGB,4,aiMipMapping,'arrTex');
  for z:=0 to 3 do begin
   arrTex.Lock(z);
   SetRenderTarget(arrTex.data,arrTex.pitch,128,128);
   for y:=0 to 127 do
    for x:=0 to 127 do
     PutPixel(x,y,MyColor(z*70,(x xor y)*2,(x xor y))); // same texture with different RED channel for each layer
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
  mipTex.SetFilter(TTexFilter.fltNearest);
  draw.Scaled(120,50,0.4,mipTex);
  draw.Scaled(120,150,1,mipTex);
  draw.Scaled(120,320,1.6,mipTex);
  draw.Scaled(120,550,scale,mipTex);
  txt.WriteW(game.defaultFont,120,720,$FFFFFFFF,'Nearest',taCenter);
  mipTex.SetFilter(TTexFilter.fltBilinear);
  draw.Scaled(340,50,0.4,mipTex);
  draw.Scaled(340,150,1,mipTex);
  draw.Scaled(340,320,1.6,mipTex);
  draw.Scaled(340,550,scale,mipTex);
  txt.WriteW(game.defaultFont,340,720,$FFFFFFFF,'Bilinear',taCenter);
  mipTex.SetFilter(TTexFilter.fltTrilinear);
  draw.Scaled(580,50,0.4,mipTex);
  draw.Scaled(580,150,1,mipTex);
  draw.Scaled(580,320,1.6,mipTex);
  draw.Scaled(580,550,scale,mipTex);
  txt.WriteW(game.defaultFont,580,720,$FFFFFFFF,'Trilinear',taCenter);


  // Texture array
  shader.UseCustom(arrShader);
  draw.Image(800,20,arrTex);
  draw.Scaled(860,220,0.6,arrTex);
  draw.Scaled(860,300,0.3,arrTex);
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
