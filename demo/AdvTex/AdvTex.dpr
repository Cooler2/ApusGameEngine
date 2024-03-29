// Advanced texturing features demo:
// - Texture Array
// - Manual Mip-Map levels
program AdvTex;
 uses Apus.Common, SysUtils, Types, Apus.Colors, Apus.EventMan, Apus.Engine.API,
   Apus.Engine.Types, Apus.Engine.GameApp, Apus.Engine.UIScene, Apus.Engine.UI,
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
   dirTex,dirFill:TTexture;
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
  SetStatus(TSceneStatus.ssActive);
 end;

procedure TMainScene.Initialize;
 var
  x,y,z:integer;
  data:array[0..63,0..63] of cardinal;
 begin
  inherited;
  mipTex:=AllocImage(128,128,TImagePixelFormat.ipfARGB,0,'mipTex');
  //mipTex:=gfx.resman.AllocImage(128,128,TImagePixelFormat.ipfARGB,aiAutoMipMap,'mipTex');
  // Fill base level
  DrawToTexture(mipTex,0);
  for y:=0 to 127 do
   for x:=0 to 127 do
    PutPixel(x,y,MyColor($C0*byte(y and 15<2),$A0*byte(x and 15<2),x*2));
  mipTex.Unlock;
  // Fill second level
  DrawToTexture(mipTex,1);
  for y:=0 to 63 do
   for x:=0 to 63 do
    PutPixel(x,y,MyColor($C0*byte(y and 7<1),$A0*byte(x and 7<1),0));
  mipTex.Unlock;
  // Fill third level
  DrawToTexture(mipTex,2);
  for y:=0 to 31 do
   for x:=0 to 31 do
    PutPixel(x,y,$FFC000C0);
  mipTex.Unlock;

  // 4 layers texture array
  arrTex:=resourceManagerGL.AllocArray(128,128,TImagePixelFormat.ipfARGB,4,aiAutoMipMap,'arrTex');
  //arrTex:=resourceManagerGL.AllocArray(512,512,TImagePixelFormat.ipfARGB,24,aiAutoMipMap,'arrTex');
  for z:=0 to 3 do begin
   arrTex.LockLayer(z);
   DrawToTexture(arrTex);
   //SetRenderTarget(arrTex.data,arrTex.pitch,arrTex.width,arrTex.height);
   for y:=0 to arrTex.height-1 do
    for x:=0 to arrTex.width-1 do
     PutPixel(x,y,MyColor(z*70,(x xor y)*2,(x xor y))); // same texture with different RED channel for each layer
   arrTex.Unlock;
  end;
  arrShader:=shader.Load('res\arrShader');

  // Direct access texture
  dirTex:=AllocImage(64,64);
  for y:=0 to 63 do
   for x:=0 to 63 do
    data[y,x]:=MyColor($FF,y*16 and $FF,x*16 and $FF,0);
  dirTex.Upload(@data,256,TImagePixelFormat.ipfARGB);

  // Direct texture fill
  dirFill:=AllocImage(64,64);
 end;

procedure TMainScene.Render;
 var
  i:integer;
  scale:single;
  data:array[0..31,0..15] of cardinal;
  v:TVector4s;
  c:cardinal;
 begin
  gfx.target.Clear($FF005000);
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
  txt.WriteW(game.defaultFont,860,420,$FFFFFFFF,'Array',taCenter);

  // Direct texture update
  FillDword(data,16*32,MyColor(255,0,0,game.frameNum*3));
  dirTex.UploadPart(0,16,16,32,16,@data,32*4,TImagePixelFormat.ipfARGB);
  draw.Image(840,480,dirTex);
  txt.WriteW(0,860,560,$FFFFFFFF,'Direct texture upload',taCenter);

  // Combining direct vs managed access - the worst case!
  dirFill.Clear($FFC0A000);
  DrawToTexture(dirFill);
  FillRect(40,10,45,60,$FF00A080);
  dirFill.Unlock;
  dirFill.ClearPart(0,16,14,32,8,$FF4040FF);
  DrawToTexture(dirFill);
  FillRect(20,10,25,60,$FF00A000);
  dirFill.Unlock;
  draw.Image(840,580,dirFill);
  txt.WriteW(0,860,660,$FFFFFFFF,'Direct texture fill',taCenter);

  // Automatic tests
  c:=gfx.GetPixelValue(847,587);
  ASSERT(ColorDiff(c,$FFC0A000)<0.1);
  c:=gfx.GetPixelValue(873,597);
  ASSERT(ColorDiff(c,$FF4040FF)<0.1);
  c:=gfx.GetPixelValue(862,621);
  ASSERT(ColorDiff(c,$FF00A000)<0.1);
  c:=gfx.GetPixelValue(882,623);
  ASSERT(ColorDiff(c,$FF00A080)<0.1);
 end;

begin
 usedAPI:=gaOpenGL2;
 useDefaultLoaderScene:=false;
 //usedPlatform:=spSDL;
 //directRenderOnly:=false;
 useRealDPI:=false;

 LinkProc('GameApp\CreateScenes',CreateScenes);
 application:=TGameApplication.Create;
 application.Prepare;
 if DirectoryExists('..\Demo\AdvTex') then
  SetCurrentDir('..\Demo\AdvTex');
 application.Run;
 application.Free;
end.
