﻿// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit MainScene;
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
  baseDir:string;

implementation
 uses Apus.Common,SysUtils,Apus.EventMan,Apus.Geom3D,Apus.AnimatedValues,
   Apus.Engine.Tools,Apus.Engine.UI,Apus.Engine.UIScene,Apus.Publics,Apus.VertexLayout;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   cameraAngle:single;
   cameraZoom:TAnimatedValue;
   texCube,objCube,objGear:TMesh;
   cCubeMesh:TMesh;
   texture:TTexture;
   constructor Create;
   procedure Initialize; override;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
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
  scaleWindowSize:=true;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
  if DirectoryExists('..\Demo\Simple3D') then
   baseDir:='..\Demo\Simple3D\';
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create;
  sceneMain.SetStatus(TSceneStatus.ssActive);
 end;

constructor TMainScene.Create;
 begin
  inherited Create;
  cameraZoom.Init(1);
  // Load resources
  texCube:=LoadMesh(baseDir+'res\cubetex.obj');
  objCube:=LoadMesh(baseDir+'res\cube.obj');
  objGear:=LoadMesh(baseDir+'res\gear.obj');
  texture:=LoadImageFromFile(baseDir+'res\cubetex.png');
 end;

procedure TMainScene.Initialize;
 var
  st:string;
 begin
  cCubeMesh:=TMesh.Create(TVertexLayout.Create([vcPosition3d,vcNormal,vcColor]),0,0);
  cCubeMesh.AddCube(NullPointS,Vector3s(1,2,3),$FF20C040);
  cCubeMesh.AddCylinder(Point3s(0,0,3),Point3s(0,1,6),0.5,0.2,16,$FFC0A040);
  cCubeMesh.Finish;
  //st:=cCubeMesh.DumpVertex(0);
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  // Turn camera around
  if game.mouseButtons and mbLeft>0 then
   cameraAngle:=cameraAngle-0.5*(x-game.oldMouseX)/game.screenDPI;
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

procedure TMainScene.Render;
 var
  distance,time:single;
 begin
  time:=MyTickCount/1000;
  gfx.target.Clear(0,1);
  // Set 3D view
  transform.Perspective(1/cameraZoom.Value,1,1000);
  distance:=30;
  transform.SetCamera(
    Point3(distance*cos(cameraAngle),distance*sin(cameraAngle),distance*0.4),
    Point3(0,0,3),Point3(0,0,1000));

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

  gfx.target.UseDepthBuffer(dbPassLess); // clip anything below the floor plane

  // Setup light and material
  shader.AmbientLight($303030);
  shader.DirectLight(Vector3(1,0.5,1),1.0,$FFFFFF);
  shader.Material($FF408090,0); // has no effect

  // Draw objects
  transform.SetObj(5,5,2); // Set object position and scale
  cCubeMesh.Draw;

  transform.SetObj(0,0,1.5+1.3*sin(time), 2); // Set object position and scale
  //shader.TexMode(0,tblReplace,tblKeep);
  texCube.Draw(texture);
  transform.SetObj(0,-5,1.5+1.3*sin(time), 2); // Set object position and scale
  objGear.Draw;
  //objCube.Draw;

  transform.SetObj(-5,5,2); // Set object position and scale
  cCubeMesh.Draw;

  // Turn back to 2D view
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer

  txt.Write(0,10,20,$FFD0D0D0,'[Ctrl]+[~] - tweaker. Mouse - rotate/zoom.');
  inherited;
 end;

end.
