// Project template for the Apus Game Engine framework

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

implementation
 uses SysUtils,Apus.CrossPlatform,Apus.MyServis,Apus.AnimatedValues,
   Apus.EventMan,Apus.Geom3D,Apus.Colors,
   Apus.Engine.SceneEffects,Apus.Engine.Tools,Apus.Engine.UIScene,
   Apus.Engine.Model3D,Apus.Engine.IQMloader;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   cameraAngle:single;
   cameraZoom:TAnimatedValue;
   model:TModel3D;
   mainChar:TModelInstance;
   tex1,tex2:TTexture;

   constructor Create;
   procedure Render; override;
   procedure onMouseMove(x,y:integer); override;
   procedure onMouseWheel(delta:integer); override;
  end;

 var
  sceneMain:TMainScene;
  baseDir:string;

{ TSimpleDemoApp }

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine'; // app window title
  //configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  //usedPlatform:=spSDL;
  //directRenderOnly:=true;
  //windowedMode:=false;
  if DirectoryExists('..\Demo\CharAnimation') then
   baseDir:='..\Demo\CharAnimation\';
 end;

// Most app initialization is here. Default spinner is running
procedure TMainApp.CreateScenes;
 begin
  inherited;
  // initialize our main scene
  sceneMain:=TMainScene.Create;
  // switch to the main scene using fade transition effect
  sceneMain.SetStatus(TSceneStatus.ssActive);
 end;

{ TMainScene }

constructor TMainScene.Create;
 begin
  inherited Create;
  cameraZoom.Init(1);
  // Load resources
  tex1:=LoadImageFromFile(baseDir+'res\material1_diffuse',liffTexture);
  tex2:=LoadImageFromFile(baseDir+'res\material2_diffuse',liffTexture);
  model:=Load3DModelIQM(baseDir+'res\character.iqm');
  //model.animations[0].smooth:=false;  // speed up
  mainChar:=model.CreateInstance;
  mainChar.PlayAnimation;
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  // Turn camera around
  if game.mouseButtons and mbLeft>0 then
   cameraAngle:=cameraAngle-(x-game.oldMouseX)*0.01;
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
    Point3(0,0,4),Point3(0,0,1000));

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
  shader.DirectLight(Vector3(1,0.5,1),0.5,$FFFFFF);
  shader.Material($FF408090,0);

  // Draw objects
  transform.SetObj(0,0,0, 5, Pi/2); // Set object position and scale

  mainChar.Update;
  mainChar.Draw(tex1);

  // Turn back to 2D view
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer

  txt.Write(0,10,20,$FFD0D0D0,'Mouse - rotate/zoom.');
  txt.Write(0,10,40,$FFD0D0D0,IntToStr(globalDirty));

  inherited;
 end;


end.
