﻿// Project template for the Apus Game Engine framework

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
  baseDir:string;

implementation
 uses Apus.MyServis,SysUtils,Apus.EventMan,Apus.Geom3D,Apus.AnimatedValues,
   Apus.Engine.Tools,Apus.Engine.UIClasses,Apus.Engine.UIScene,Apus.Publics;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   cameraAngleX,cameraAngleY:single;
   cameraZoom:TAnimatedValue;
   objHoney:TMesh;
   time:single;
   shadowMap:TTexture;
   constructor Create;
   procedure Initialize; override;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;

   procedure DrawScene(mainPass:boolean);
  end;

 var
  sceneMain:TMainScene;

{ TSimpleDemoApp }

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  useTweakerScene:=true;

  gameTitle:='Simple 3D Demo'; // app window title
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  directRenderOnly:=true;
  //windowedMode:=false;
  if DirectoryExists('..\Demo\ShadowMap') then
   baseDir:='..\Demo\ShadowMap\';
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create;
  sceneMain.SetStatus(ssActive);
 end;

constructor TMainScene.Create;
 begin
  inherited Create;
  cameraZoom.Init(1);
  cameraAngleY:=0.5;
  // Load resources
  objHoney:=LoadMesh(baseDir+'res\honey.obj');
 end;

procedure TMainScene.Initialize;
 begin
  // No pixel format for the image buffer means that only depth buffer should be allocated
  shadowMap:=gfx.resman.AllocImage(1024,1024,TImagePixelFormat.ipfNone,
   aiRenderTarget+aiDepthBuffer,'ShadowMap');
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  // Turn camera around
  if game.mouseButtons and mbLeft>0 then begin
   cameraAngleX:=cameraAngleX-(x-game.oldMouseX)*0.01;
   cameraAngleY:=Clamp(cameraAngleY+(y-game.oldMouseY)*0.005,0.1,1.2);
  end;
 end;

procedure TMainScene.onMouseWheel(delta: integer);
 begin
  inherited;
  // Camera zoom
  if (delta<0) and (cameraZoom.FinalValue>0.7) then
   cameraZoom.Animate(cameraZoom.FinalValue/1.3,250,sfEaseInOut);
  if (delta>0) and (cameraZoom.FinalValue<2) then
   cameraZoom.Animate(cameraZoom.FinalValue*1.3,250,sfEaseInOut);
 end;

procedure TMainScene.DrawScene(mainPass: boolean);
 begin
  // 2D primitives are drawn on XY plane (z=0) so it's OK to draw floor like this :)
  draw.FillRect(-20,-20,20,20,$FF80A0B0);
  if mainPass then begin
   gfx.target.UseDepthBuffer(dbPass);
   // X axis
   draw.Line(0,0,10,0,$FF000090);
   draw.Line(10,0,9,1,$FF000090);
   draw.Line(10,0,9,-1,$FF000090);
   // Y axis
   draw.Line(0,0,0,10,$FF007000);
   draw.Line(0,10,1,9,$FF007000);
   draw.Line(0,10,-1,9,$FF007000);
  end;

  gfx.target.UseDepthBuffer(dbPassLess); // clip anything below the floor plane

  // Setup light and material
  shader.AmbientLight($303030);
  shader.DirectLight(Vector3(1,0.5,1),0.5,$FFFFFF);
  shader.Material($FF408090,0);

  // Draw objects
  transform.SetObj(0,0,3, 2, 0,time/2,time); // Set object position and scale
  objHoney.Draw;
 end;


procedure TMainScene.Render;
 var
  distance:single;
 begin
  time:=MyTickCount/1000;
  gfx.target.Clear(0,1);
  gfx.SetCullMode(cullNone);

  // Set 3D view
  transform.Perspective(1/cameraZoom.Value,0.1,100);
  distance:=30;
  transform.SetCamera(
    Point3(distance*cos(cameraAngleX)*cos(cameraAngleY),
           distance*sin(cameraAngleX)*cos(cameraAngleY),
           distance*sin(cameraAngleY)),
    Point3(0,0,3),Point3(0,0,1000));

  DrawScene(true);

  // Turn back to 2D view
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer

  txt.Write(0,10,20,$FFD0D0D0,'[Ctrl]+[~] - tweaker. Mouse - rotate/zoom.');
  inherited;
 end;

end.