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
  baseDir:string;

implementation
 uses Apus.MyServis,SysUtils,Apus.EventMan,Apus.Geom3D,Apus.AnimatedValues,
   Apus.Engine.Tools,Apus.Engine.UI,Apus.Engine.UIScene,Apus.Publics,
   dglOpenGL;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   cameraAngleX,cameraAngleY:single;
   cameraZoom:TAnimatedValue;
   objHoney:TMesh;
   time:single;
   shadowMap:TTexture;
   lightDir:TVector3;
   lightMatrix:T3DMatrix;
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
  //noVSync:=true;
  gameTitle:='Shadow Map Demo'; // app window title
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
  sceneMain.SetStatus(TSceneStatus.ssActive);
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
   aiRenderTarget+aiDepthBuffer+aiClampUV,'ShadowMap');
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  // If element under mouse doesn't belong to this scene - ignore movement!
  if underMouse.GetRoot<>UI then exit;
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
   cameraZoom.Animate(cameraZoom.FinalValue/1.2,250,sfEaseInOut);
  if (delta>0) and (cameraZoom.FinalValue<1.5) then
   cameraZoom.Animate(cameraZoom.FinalValue*1.2,250,sfEaseInOut);
 end;

procedure TMainScene.DrawScene(mainPass: boolean);
 var
  i:integer;
 begin
  gfx.target.UseDepthBuffer(dbPass);
  // 2D primitives are drawn on XY plane (z=0) so it's OK to draw floor like this :)
  draw.FillRect(-20,-20,20,20,$FF80A0B0);
  if mainPass then begin
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

  if mainPass then begin
   // Setup light and material
   SetGlobals('GC0=$505050;GF0=0.7','Ambient Light');

   shader.AmbientLight(GC0);
   shader.DirectLight(lightDir, gF0,$FFFFFF);
   shader.Material($FF408090,0);
  end;

  // Draw objects
  transform.SetObj(0,0,3, 2, 0,time/2,time); // Set object position, scale and rotation
  objHoney.Draw;
  // Benchmark
{  for i:=1 to 100 do begin
   transform.SetObj((i mod 10)*5-25+i div 10,(i div 10)*5-25-i mod 10,10, 2, 0,time/2,time); // Set object position, scale and rotation
   objHoney.Draw;
  end;}
  //if mainPass then glFlush; // This is just a breakpoint for gDebugger. It does nothing meaningful.

 end;


procedure TMainScene.Render;
 var
  distance,zBias:single;
  frustum,tmp:T3DMatrix;
 begin
  // setup
  time:=MyTickCount/1000;
  // This allows to adjust the light direction at runtime via the Tweaker
  SetGlobals('GF0=1;GF1=0.5;GF2=1','LightDir');
  lightDir:=Vector3(gF0, gF1, gF2);

  gfx.SetCullMode(cullCW); // this is a trick! Draw back faces only into the shadowmap (cullNone will work too, but not cullCCW)
  // 1-st pass: build shadowmap
  gfx.BeginPaint(shadowMap);
  gfx.target.Clear(0,1);
  shader.Shadow(shadowDepthPass);
  // Set ortho view from the light source
  transform.SetCamera(VecMult(lightDir,20), Point3(0,0,0), Point3(0,0,1000));
  // Scale 25 should be enough to cover all scene even at minimal zoom level.
  // If scene is too large, this method won't work: you need either
  // cascaded shadow maps or (better) compressed (non-linear) shadow maps
  // It's reasonable to change scale with zoom to keep the shade fidelity, but I'm using fixed scale.
  transform.Orthographic(25, 1,100); // Z range: 0..100

  DrawScene(false);
  gfx.EndPaint;

  shader.Shadow(shadowMainPass,shadowMap);
  // 2-nd pass: render scene with shadows
  gfx.target.Clear($20,1);
  gfx.SetCullMode(cullCCW); // cull back faces (!! don't forget to restore, as engine used the opposite face direction)

  // Set 3D view
  distance:=30/cameraZoom.value;
  transform.Perspective(1/cameraZoom.Value,1,1000);
  transform.SetCamera(
    Point3(distance*cos(cameraAngleX)*cos(cameraAngleY),
           distance*sin(cameraAngleX)*cos(cameraAngleY),
           distance*sin(cameraAngleY)),
    Point3(0,0,3),Point3(0,0,1000));

{ // Uncomment to view from the light position
  transform.SetCamera(Vect3Mult(lightDir,20), Point3(0,0,0), Point3(0,0,1000));
  transform.Orthographic(25, 1,100); // Z range: 0..100}

  //transform.Transform(Point3(0,0,0));

  DrawScene(true);

  shader.Shadow(shadowDisabled);

  // Turn back to 2D view and everything
  shader.LightOff;
  shader.DefaultTexMode;
  transform.DefaultView;
  gfx.target.UseDepthBuffer(dbDisabled); // Disable depth buffer
  gfx.SetCullMode(cullNone);

  //glFlush;
  txt.Write(0,10,20,$FFD0D0D0,'[Ctrl]+[~] - tweaker. Mouse - rotate/zoom.');
  inherited;
 end;

end.
