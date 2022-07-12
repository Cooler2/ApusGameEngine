// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit MainScene;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  // Let's override to have a custom app class
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
  end;

 var
  application:TMainApp;

implementation
 uses Apus.MyServis,Apus.EventMan,Apus.Colors,Apus.Geom3D,
   Apus.Engine.UI;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Initialize; override;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
  end;

 var
  sceneMain:TMainScene;
  tex:TTexture;
  cameraAngleX:single=0.8;
  cameraAngleY:single=0.7;
  cameraZoom:TAnimatedValue;

  particles:array of TParticle;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Particles demo - Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create('Main');
  // switch to the main scene using fade transition effect
  game.SwitchToScene('Main');
 end;

{ TMainScene }
procedure TMainScene.onMouseMove(x,y:integer);
 begin
  inherited;
  // Turn camera around
  if game.mouseButtons and mbLeft>0 then begin
   cameraAngleX:=cameraAngleX-(x-game.oldMouseX)*0.01;
   cameraAngleY:=Clamp(cameraAngleY+(y-game.oldMouseY)*0.005, 0.1,1.2);
  end;
 end;

procedure TMainScene.onMouseWheel(delta:integer);
 begin
  inherited;
  // Camera zoom
  if (delta<0) and (cameraZoom.FinalValue>0.7) then
   cameraZoom.Animate(cameraZoom.FinalValue/1.3,250,splines.easeInOut);
  if (delta>0) and (cameraZoom.FinalValue<3) then
   cameraZoom.Animate(cameraZoom.FinalValue*1.3,250,splines.easeInOut);
 end;

procedure TMainScene.Initialize;
 var
  i,x,y:integer;
  pixels:array[0..15,0..15] of cardinal;
  c:cardinal;
 begin
  inherited;
  cameraZoom.Init(1);
  // Particle image
  tex:=AllocImage(16,16);
  for y:=0 to 15 do
   for x:=0 to 15 do begin
    c:=MyColor(255,y*17,x*17,200);
    if (x=1) or (x=14) or (y=1) or (y=14) then c:=$FF000000;
    if (x=0) or (x=15) or (y=0) or (y=15) then c:=$808080;
    pixels[y,x]:=c;
   end;
  tex.Upload(@pixels,64,TImagePixelFormat.ipfARGB);
  // Particles
  RandSeed:=10;
  SetLength(particles,5);
  for i:=0 to high(particles) do
   with particles[i] do begin
    //x:=random(10)-random(10);
    //y:=random(10)-random(10);
    //z:=random(10);
    x:=i*2;
    y:=0;
    z:=2;
    color:=MyColor(255-i*30,128,128,128);
    scale:=1+i*0.2;
    angle:=i*0.2;
    index:=0;
   end;
 end;

procedure SetupCamera;
 var
  cameraPos:TPoint3s;
 begin
  transform.Perspective(1/cameraZoom.Value,1,1000);
  cameraPos.x:=30*cos(cameraAngleX)*cos(cameraAngleY);
  cameraPos.y:=30*sin(cameraAngleX)*cos(cameraAngleY);
  cameraPos.z:=30*sin(cameraAngleY);
  transform.SetCamera(cameraPos,Point3s(0,0,2),Point3s(0,0,100000));
 end;

procedure TMainScene.Render;
 begin
  gfx.target.Clear($406080,1);
  SetupCamera;

  gfx.target.UseDepthBuffer(dbPass);

  gfx.SetCullMode(cullNone);
  transform.Transform(Point3(0,0,0));
  gfx.clip.Nothing;
  // 2D primitives are drawn on XY plane (z=0) so it's OK to draw floor like this :)
  draw.TexturedRect(-20,-20,20,20,game.defaultTexture,-0.125,-0.125,10.125,-0.125,10.125,10.125,$FFFFFFFF);
  // X axis
  draw.Line(0,0,10,0,$FF000090);
  draw.Line(10,0,9,1,$FF000090);
  draw.Line(10,0,9,-1,$FF000090);
  // Y axis
  draw.Line(0,0,0,10,$FF007000);
  draw.Line(0,10,1,9,$FF007000);
  draw.Line(0,10,-1,9,$FF007000);

  gfx.clip.Restore;


  draw.Particles(@particles[0],length(particles),tex,16);
  transform.DefaultView;
  inherited;
 end;

end.
