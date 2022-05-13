// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit ScBillboards;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses SysUtils, Apus.CrossPlatform, Apus.EventMan, Apus.Colors, Apus.AnimatedValues,
   Apus.Geom3D, Apus.FastGFX,
   Apus.Engine.ImageTools, Apus.Engine.UI;

 const
  MAX_Z = 70;
  TEX_SCALE = 0.4;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure CreateUI;
   procedure Load; override;
   procedure Render; override;
   procedure onShow; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
  end;

 var
  sceneMain:TMainScene;
  baseDir:string;
  cameraAngle:single;
  cameraDist:TAnimatedValue;
  texFloor,texCeil:TTexture;
  baloon1,baloon2:TTexture;
  bb:array[0..1999] of TPoint3s;
  bbCount:integer;
  colors:array[0..255] of cardinal;

constructor TMainApp.Create;
 begin
  inherited;
  gameTitle:='Billboards Demo'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  if DirectoryExists('..\Demo\Billboards') then
   baseDir:='..\Demo\Billboards\';
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  sceneMain.CreateUI;
 end;

{ TMainScene }
procedure TMainScene.CreateUI;
 var
  font:cardinal;
  panel:TUIElement;
  btn:TUIButton;
 begin
  font:=txt.GetFont('Default',9);
  // Create a panel
  panel:=TUIElement.Create(250,220,UI,'Panel');
  panel.SetPos(UI.width-10,UI.height-10,pivotBottomRight);
  panel.styleInfo:='E0808890'; // background color
  panel.layout:=TRowLayout.CreateVertical(5);
  TUILabel.Create(200,30,'Panel\Label1','SETTINGS',clWhite,font,panel).align:=taCenter;

  TUIButton.CreateSwitch(200,32,'Panel\DrawMode1','No transformations',1,font,panel,true)
   .hint:='Use "draw.Billboard()" so they''re drawn as meshes in the world CS';
//  TUIButton.CreateSwitch(200,32,'MainScene\DrawMode2','Use transformations',1,font,panel)
  TUIButton.CreateSwitch(200,32,'Panel\DrawMode0','Don''t draw',1,font,panel)
   .hint:='Don''t draw billboards';

  TUIElement.Create(100,10,panel,'Panel\Spacer1');
  TUIButton.CreateCheckbox(200,32,'Panel\Scale','screen space',0,font,panel,true).
   hint:='';

  TUIElement.Create(100,10,panel,'Panel\Spacer2');

  // Create exit button
  TUIButton.Create(100,32,'Panel\Close','Exit',font,panel)
   .hint:='Press this button to exit';

  // Link the button click signal to the engine termination signal
  Link('UI\Panel\Close\Click','Engine\Cmd\Exit');
 end;

procedure TMainScene.Load;
 var
  x,y,i:integer;
 procedure AddObject(z:single);
  var
   xx,yy:integer;
  begin
   // randomize position
   xx:=x*32-random(5)+random(5);
   yy:=y*32-random(5)+random(5);
   // Draw object on current texture
   FillCircle(xx,yy,3.5,$FF008030);
   PutPixel(xx,yy,clBlack);
   // Store object position in the world CS to attach billboards
   bb[bbCount].Init((xx-512)*TEX_SCALE,(yy-512)*TEX_SCALE,z); // get world position from texture coordinates
   inc(bbCount);
  end;
 begin
  RandSeed:=98;
  bbCount:=0;
  // Create the floor texture
  texFloor:=AllocImage(1024,1024);
  EditImage(texFloor); // make it active render target for FastGFX operations
  ClearRenderTarget($FFA8B0A0); // fill the texture
  for x:=1 to 31 do
   for y:=1 to 31 do
    if random(10)<3 then AddObject(0);
  texFloor.Unlock;
  // Create the ceiling texture (similar to the floor)
  texCeil:=AllocImage(1024,1024);
  EditImage(texCeil);
  ClearRenderTarget($FFA0B0B0);
  for x:=1 to 31 do
   for y:=1 to 31 do
    if random(10)<3 then AddObject(MAX_Z);
  texCeil.Unlock;

  // Random colors
  for i:=0 to 255 do
   colors[i]:=MyColor(128+random(40)-random(40),128+random(40)-random(40),128+random(40)-random(40));

  // Load baloon image
  baloon1:=LoadImageFromFile(baseDir+'res\baloon');
  baloon2:=LoadImageFromFile(baseDir+'res\baloonTop');

  // Scene loaded - show it
  game.SwitchToScene('Main');
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  if underMouse<>UI then exit; // don't turn camera if mouse is over any UI
  // Turn camera around
  if game.mouseButtons and mbLeft>0 then
   cameraAngle:=cameraAngle-(x-game.oldMouseX)/(cameraDist.Value+30);
 end;

procedure TMainScene.onMouseWheel(delta: integer);
 begin
  inherited;
  // Adjust camera distance
  if (delta>0) and (cameraDist.FinalValue>40) then
   cameraDist.Animate(cameraDist.FinalValue/1.1-10,300,sfEaseInOut);
  if (delta<0) and (cameraDist.FinalValue<280) then
   cameraDist.Animate(cameraDist.FinalValue*1.1+10,300,sfEaseInOut);
 end;

procedure TMainScene.onShow;
 begin
  cameraDist.Init(160);
  inherited;
 end;

procedure SetupCamera;
 var
  dist:single;
 begin
  // Set 3D view
  transform.Perspective(1.2,1,1000);
  dist:=cameraDist.Value;
  transform.SetCamera(
    Point3(dist*cos(cameraAngle),dist*sin(cameraAngle),45),
    Point3(0,0,20),Point3(0,0,1000));
 end;

procedure DrawAxes;
 begin
  // X axis
  draw.Line(0,0,20,0,$FF000090);
  draw.Line(20,0,19,1,$FF000090);
  draw.Line(20,0,19,-1,$FF000090);
  // Y axis
  draw.Line(0,0,0,20,$FF007000);
  draw.Line(0,20,1,19,$FF007000);
  draw.Line(0,20,-1,19,$FF007000);
 end;

procedure DrawBillboards;
 var
  i:integer;
 begin
  gfx.target.UseDepthBuffer(dbPassLess); // enable depth buffer
  draw.Billboard(Point3s(0,0,0),0.1,baloon1,0.5,1.0);

  //exit;
  for i:=0 to bbCount-1 do
   if bb[i].z=0 then
    draw.Billboard(bb[i],0.1,baloon1,0.5,1.0,colors[i and 255]);

  for i:=0 to bbCount-1 do
   if bb[i].z=MAX_Z then
    draw.Billboard(bb[i],0.1,baloon2,0.5,0.0,colors[i and 255]);
 end;

procedure TMainScene.Render;
 var
  d:integer;
 begin
  gfx.target.Clear($304050,1);
  SetupCamera;

  gfx.target.UseDepthBuffer(dbPass);
  gfx.SetCullMode(cullNone);

  gfx.clip.Reject(false); // disable primitive culling (because we're in 3D mode)
  transform.SetObj(0,0,MAX_Z); // move current position to maxZ height to draw ceiling
  // Draw a ceiling texture (culling is disabled so it is double-sided and we'll see its back side
  d:=round(0.5*texFloor.width*TEX_SCALE);
  draw.TexturedRect(-d,-d,d,d,texCeil,0,0,1,0,1,1);
  transform.ResetObj; // return to the CS origin
  draw.TexturedRect(-d,-d,d,d,texFloor,0,0,1,0,1,1);

  DrawAxes;
  if not UIButton('Panel\DrawMode0').pressed then
   DrawBillboards;

  // Turn back to 2D view
  gfx.clip.Reject(true);
  transform.DefaultView;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer
  inherited;
 end;

end.
