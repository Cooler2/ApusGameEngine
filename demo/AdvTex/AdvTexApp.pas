// Advanced texturing demo - how the engine handles texture assets:
//  * manual mip-map levels, compared under the three filtering modes
//  * texture array (4 layers) sampled by a custom shader
//  * compressed texture loaded from a DDS file (S3TC/DXT5)
//  * direct texture access: whole/partial upload and partial clear
//
// Copyright (C) 2017 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit AdvTexApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses SysUtils, Types, Apus.Core, Apus.Colors, Apus.Images, Apus.FastGFX, Apus.Log,
   Apus.Engine.Types, Apus.Engine.UIScene, Apus.Engine.ImageTools,
   Apus.Engine.ResManGL;

 const
  CANVAS_W = 1280;   // the demo declares a fixed canvas: the layout below is hand-made
  CANVAS_H = 780;
  MIP_SIZE = 128;    // size of the manually built mip-mapped texture
  DIR_SIZE = 64;     // size of the directly accessed textures
  CAPTION_COLOR = $FFE8EDF5;
  SUBTEXT_COLOR = $FFA8B4C4;
  // right-hand panels
  ARR_X = 700;
  DDS_X = 1000;
  PANEL_Y = 60;
  DIRTEX_X = 700;
  DIRFILL_X = 1000;
  DIR_Y = 560;

 type
  TMainScene=class(TUIScene)
   mipTex:TTexture;
   arrTex:TGLTextureArray;
   arrShader:TShader;
   dirTex,dirFill:TTexture;
   ddsTex:TTexture;
   ddsError:String8;
   selfTestDone:boolean;
   constructor Create;
   destructor Destroy; override;
   procedure InitGfx; override;
   procedure Render; override;
  private
   procedure BuildMipTexture;
   procedure BuildTextureArray;
   procedure LoadCompressedTexture;
   procedure BuildDirectTextures;
   procedure DrawMipColumn(x:integer;filter:TTexFilter;const title:String8);
   procedure DrawTextureArray;
   procedure DrawCompressed;
   procedure DrawDirectAccess;
   procedure SelfTest;
  end;

 var
  mainScene:TMainScene;

{ TMainApp }

constructor TMainApp.Create;
 begin
  inherited;
  gameTitle:='Apus Engine: Advanced Texturing';
  appName:='AdvTex'; // window caption is for the user, this one names the storage folders
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  windowWidth:=CANVAS_W;
  windowHeight:=CANVAS_H;
  windowSizeable:=true;
  // the panels are laid out by hand, so the demo declares its own canvas space
  // instead of following the client area (which is DPI-dependent)
  SetupFixedCanvas(CANVAS_W,CANVAS_H);
  useDefaultLoaderScene:=false;
  useTweakerScene:=false;
  SetCurrentDir(BaseDir);
  // when running straight from the repo, assets live in the source tree
  if DirectoryExists('../demo/AdvTex') then
   SetCurrentDir('../demo/AdvTex');
 end;

procedure TMainApp.CreateScenes;
 begin
  inherited;
  mainScene:=TMainScene.Create;
  mainScene.SetStatus(TSceneStatus.ssActive);
 end;

{ TMainScene }

constructor TMainScene.Create;
 begin
  inherited Create('MainScene');
 end;

destructor TMainScene.Destroy;
 begin
  FreeImage(mipTex);
  FreeImage(dirTex);
  FreeImage(dirFill);
  if ddsTex<>nil then FreeImage(ddsTex);
  arrTex.Free;
  inherited;
 end;

procedure TMainScene.InitGfx;
 begin
  inherited;
  BuildMipTexture;
  BuildTextureArray;
  LoadCompressedTexture;
  BuildDirectTextures;
 end;

// Every mip level gets its own pattern, so the level actually used for sampling
// is directly visible (the engine never generates these - they are drawn by hand)
procedure TMainScene.BuildMipTexture;
 var
  x,y:integer;
 begin
  mipTex:=AllocImage(MIP_SIZE,MIP_SIZE,TImagePixelFormat.ipfARGB,0,'mipTex');
  DrawToTexture(mipTex,0);
  for y:=0 to MIP_SIZE-1 do
   for x:=0 to MIP_SIZE-1 do
    PutPixel(x,y,Color.RGB($C0*byte(y and 15<2),$A0*byte(x and 15<2),x*2));
  mipTex.Unlock;

  DrawToTexture(mipTex,1);
  for y:=0 to MIP_SIZE div 2-1 do
   for x:=0 to MIP_SIZE div 2-1 do
    PutPixel(x,y,Color.RGB($C0*byte(y and 7<1),$A0*byte(x and 7<1),0));
  mipTex.Unlock;

  DrawToTexture(mipTex,2);
  for y:=0 to MIP_SIZE div 4-1 do
   for x:=0 to MIP_SIZE div 4-1 do
    PutPixel(x,y,$FFC000C0);
  mipTex.Unlock;
 end;

// 4 layers of the same pattern with a different red level; the custom shader
// picks the layer from the texture coordinates
procedure TMainScene.BuildTextureArray;
 var
  x,y,z:integer;
 begin
  arrTex:=resourceManagerGL.AllocArray(MIP_SIZE,MIP_SIZE,TImagePixelFormat.ipfARGB,4,
    aiAutoMipMap,'arrTex');
  for z:=0 to 3 do begin
   arrTex.LockLayer(z);
   DrawToTexture(arrTex);
   for y:=0 to arrTex.height-1 do
    for x:=0 to arrTex.width-1 do
     PutPixel(x,y,Color.RGB(z*70,(x xor y)*2,(x xor y)));
   arrTex.Unlock;
  end;
  arrShader:=shader.Load('res/arrShader');
 end;

// Block-compressed data goes to the GPU as is - the engine never decompresses it,
// so the texture keeps its DXT pixel format all the way through
procedure TMainScene.LoadCompressedTexture;
 begin
  try
   ddsTex:=LoadImageFromFile('res/logo.dds');
  except
   on e:Exception do begin
    ddsTex:=nil;
    ddsError:=ExceptionMsg(e); // S3TC is an extension: report instead of dying
   end;
  end;
 end;

// dirTex is filled with a whole-surface upload (this is also what creates its GPU
// storage - a partial upload needs an initialized texture), dirFill is left empty:
// its content is produced every frame in DrawDirectAccess
procedure TMainScene.BuildDirectTextures;
 var
  x,y:integer;
  data:array[0..DIR_SIZE-1,0..DIR_SIZE-1] of cardinal;
 begin
  dirTex:=AllocImage(DIR_SIZE,DIR_SIZE);
  for y:=0 to DIR_SIZE-1 do
   for x:=0 to DIR_SIZE-1 do
    data[y,x]:=Color.ARGB($FF,y*16 and $FF,x*16 and $FF,0);
  dirTex.Upload(@data,DIR_SIZE*4,TImagePixelFormat.ipfARGB);
  dirFill:=AllocImage(DIR_SIZE,DIR_SIZE);
 end;

procedure TMainScene.DrawMipColumn(x:integer;filter:TTexFilter;const title:String8);
 var
  scale:single;
 begin
  scale:=0.9+0.6*sin(CoreTime.Ticks/1000);
  mipTex.SetFilter(filter);
  draw.Scaled(x,50,0.25,mipTex);
  draw.Scaled(x,150,1,mipTex);
  draw.Scaled(x,320,1.6,mipTex);
  draw.Scaled(x,550,scale,mipTex);
  txt.Write(0,x,690,CAPTION_COLOR,title,TTextAlignment.taCenter);
 end;

procedure TMainScene.DrawTextureArray;
 begin
  shader.UseCustom(arrShader);
  draw.Image(ARR_X,PANEL_Y,arrTex);
  draw.Scaled(ARR_X+64,PANEL_Y+240,0.6,arrTex);
  draw.Scaled(ARR_X+64,PANEL_Y+330,0.3,arrTex);
  shader.Reset;
  txt.Write(0,ARR_X+64,PANEL_Y+390,CAPTION_COLOR,'Texture array (4 layers)',TTextAlignment.taCenter);
 end;

procedure TMainScene.DrawCompressed;
 begin
  if ddsTex=nil then begin
   txt.Write(0,DDS_X+64,PANEL_Y+60,CAPTION_COLOR,'DDS not loaded:',TTextAlignment.taCenter);
   txt.Write(0,DDS_X+64,PANEL_Y+82,SUBTEXT_COLOR,ddsError,TTextAlignment.taCenter);
   exit;
  end;
  draw.Image(DDS_X,PANEL_Y,ddsTex);
  draw.Scaled(DDS_X+64,PANEL_Y+300,1.5,ddsTex);
  txt.Write(0,DDS_X+64,PANEL_Y+390,CAPTION_COLOR,'Compressed (DDS)',TTextAlignment.taCenter);
  txt.Write(0,DDS_X+64,PANEL_Y+412,SUBTEXT_COLOR,
    Format('%s  %dx%d',[PixFmt2Str(ddsTex.PixelFormat),ddsTex.width,ddsTex.height]),
    TTextAlignment.taCenter);
 end;

procedure TMainScene.DrawDirectAccess;
 var
  data:array[0..31,0..15] of cardinal;
 begin
  // partial upload of externally prepared pixels
  Mem.FillD(data,16*32,Color.ARGB(255,255,0,window.frameNum*3 and $FF));
  dirTex.UploadPart(0,16,16,32,16,@data,32*4,TImagePixelFormat.ipfARGB);
  draw.Image(DIRTEX_X,DIR_Y,dirTex);
  txt.Write(0,DIRTEX_X+32,DIR_Y+90,CAPTION_COLOR,'Partial upload',TTextAlignment.taCenter);

  // mixing direct GPU-side fills with locked CPU-side drawing - the worst case
  dirFill.Clear($FFC0A000);
  DrawToTexture(dirFill);
  FillRect(40,10,45,60,$FF00A080);
  dirFill.Unlock;
  dirFill.ClearPart(0,16,14,32,8,$FF4040FF);
  DrawToTexture(dirFill);
  FillRect(20,10,25,60,$FF00A000);
  dirFill.Unlock;
  draw.Image(DIRFILL_X,DIR_Y,dirFill);
  txt.Write(0,DIRFILL_X+32,DIR_Y+90,CAPTION_COLOR,'Direct fill + lock',TTextAlignment.taCenter);
 end;

// Read back the direct-fill panel: every operation above must be visible in the
// final frame, in the right order
procedure TMainScene.SelfTest;
 var
  failed:integer;
  procedure Check(x,y:integer;col:cardinal);
   var
    p:TPoint;
   begin
    p:=window.CanvasToPixels(Point(DIRFILL_X+x,DIR_Y+y)); // readback works in real pixels
    if Color.Diff(gfx.GetPixelValue(p.x,p.y),col)>0.1 then inc(failed);
   end;
 begin
  selfTestDone:=true;
  failed:=0;
  Check(7,7,$FFC0A000);   // Clear
  Check(33,17,$FF4040FF); // ClearPart
  Check(22,41,$FF00A000); // FillRect after ClearPart
  Check(42,43,$FF00A080); // FillRect before ClearPart
  if failed>0 then
   Log.Warn(Format('AdvTex self-test: %d of 4 checks failed',[failed]))
  else
   Log.Info('AdvTex self-test: OK');
 end;

procedure TMainScene.Render;
 begin
  gfx.target.Clear($FF303840);
  txt.Write(0,18,22,CAPTION_COLOR,'Advanced texturing: mip levels, filtering, texture array, compressed and direct access');
  DrawMipColumn(120,TTexFilter.fltNearest,'Nearest');
  DrawMipColumn(340,TTexFilter.fltBilinear,'Bilinear');
  DrawMipColumn(560,TTexFilter.fltTrilinear,'Trilinear');
  DrawTextureArray;
  DrawCompressed;
  DrawDirectAccess;
  if not selfTestDone and (window.frameNum>30) then SelfTest;
 end;

end.
