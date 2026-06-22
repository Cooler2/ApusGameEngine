// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Simple3DApp;
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
 uses SysUtils,Apus.Core,Apus.Geom3D,Apus.AnimatedValues,
   Apus.Engine.UI,Apus.Engine.UIScene,
   Apus.Engine.Mesh,Apus.Engine.GpuMesh,Apus.Engine.MeshShapes,Apus.Engine.OBJLoader;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   cameraAngle:single;
   cameraZoom:TAnimatedValue;
   texCube,objCube,objGear:TGpuMesh;
   generatedMesh:TGpuMesh;
   texture:TTexture;
   constructor Create;
   destructor Destroy; override;
   procedure InitGfx; override;
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
  texture:=LoadImageFromFile(baseDir+'res\cubetex.png');
 end;

destructor TMainScene.Destroy;
 begin
  generatedMesh.Free;
  texCube.Free;
  objCube.Free;
  objGear.Free;
  texture.Free;
  inherited;
 end;

procedure TMainScene.InitGfx;
 var
  mesh,part:Apus.Engine.Mesh.TMesh;
 begin
  inherited;
  // R-20 procedural generators build the new SoA mesh; TGpuMesh owns the
  // retained GPU upload and uses the R-19 layout/binding path.
  mesh:=MeshShapes.Box(Vec3(1,2,3));
  part:=MeshShapes.Cylinder(0.5,0.2,3,16,true);
  mesh.Append(part,TMat4.Translation(0,0.5,4.5));
  part.Free;
  generatedMesh:=TGpuMesh.Create(mesh);
  generatedMesh.Upload([muDiscardCPUCopy]);

  texCube:=TGpuMesh.Create(LoadMeshOBJ(baseDir+'res\cubetex.obj'));
  texCube.Upload([muDiscardCPUCopy]);
  objCube:=TGpuMesh.Create(LoadMeshOBJ(baseDir+'res\cube.obj'));
  objCube.Upload([muDiscardCPUCopy]);
  objGear:=TGpuMesh.Create(LoadMeshOBJ(baseDir+'res\gear.obj'));
  objGear.Upload([muDiscardCPUCopy]);
 end;

procedure TMainScene.onMouseMove(x, y: integer);
 begin
  inherited;
  // Turn camera around
  if window.mouseButtons and mbLeft>0 then
   cameraAngle:=cameraAngle-0.5*(x-window.oldMousePos.x)/window.screenDPI;
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
  time:=CoreTime.Ticks/1000;
  gfx.target.Clear(0,1);
  // Set 3D view
  transform.Perspective(1/cameraZoom.Value,1,1000);
  distance:=30;
  transform.SetCamera(
    Vec3(distance*cos(cameraAngle),distance*sin(cameraAngle),distance*0.4),
    Vec3(0,0,3),Vec3(0,0,1000));

  gfx.target.SetDepthMode(TDepthTest.Pass);

  gfx.SetCullMode(TCullMode.DrawAll);
  transform.Transform(Vec3(0,0,0));
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

  gfx.target.SetDepthMode(TDepthTest.Less); // clip anything below the floor plane
  gfx.SetCullMode(TCullMode.DrawCCW);

  // Setup light and material
  shader.AmbientLight($303030);
  shader.DirectLight(Vec3(1,0.5,1),1.0,$FFFFFF);
  shader.Material($FF408090,0); // material tint applied by the mesh shader

  // Draw objects
  transform.SetObj(5,5,2); // Set object position and scale
  shader.TexMode(0,tblDisable,tblDisable);
  generatedMesh.Draw;

  transform.SetObj(0,0,1.5+1.3*sin(time), 2); // Set object position and scale
  shader.TexMode(0,tblModulate,tblModulate);
  texCube.Draw(texture);
  transform.SetObj(0,-5,1.5+1.3*sin(time), 2); // Set object position and scale
  shader.TexMode(0,tblDisable,tblDisable);
  objGear.Draw;
  //objCube.Draw;

  transform.SetObj(-5,5,2); // Set object position and scale
  generatedMesh.Draw;

  // Turn back to 2D view
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.SetDepthMode(TDepthTest.Disabled); // Disable depth buffer
  gfx.SetCullMode(TCullMode.DrawAll);

  txt.Write(0,10,20,$FFD0D0D0,'[Ctrl]+[~] - tweaker. Mouse - rotate/zoom.');
  inherited;
 end;

end.
