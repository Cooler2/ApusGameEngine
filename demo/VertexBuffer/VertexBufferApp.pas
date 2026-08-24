// Project template for the Apus Game Engine framework

// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit VertexBufferApp;
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
 uses
  SysUtils,
  Apus.Colors, Apus.Geom3D,
  Apus.Engine.UI, Apus.Engine.Mesh, Apus.Engine.GpuMesh;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   destructor Destroy; override;
   procedure Load; override;
   procedure InitGfx; override;
   procedure Render; override;
  end;

 const
  MESH_SEGMENTS = 100;
  MESH_SECTIONS = 240;

 var
 sceneMain:TMainScene;
  mesh:TMesh;
  gpuMesh:TGpuMesh;
  trgCount:integer;

constructor TMainApp.Create;
 begin
  inherited;
  // Alter some global settings
  gameTitle:='Apus Game Engine: Vertex buffer demo'; // app window title
  usedAPI:=gaOpenGL2; // use OpenGL 2.0+ with shaders
  usedPlatform:=spDefault;
  windowWidth:=1300;
  windowHeight:=850;
  //usedPlatform:=spSDL;
  //windowedMode:=false;
 end;

procedure TMainApp.CreateScenes;
 begin
  inherited;
  sceneMain:=TMainScene.Create('Main');
 end;

procedure BuildMesh;
 // Calculate surface point
 function CalcSurface(u,v:single):TVec3;
  var
   angle,r,h:single;
  begin
   h:=2*v-1;
   angle:=2*Pi*u;
   r:=cos(h*1.2)+0.05*sin(7*angle+30*h);
   result.x:=r*cos(angle);
   result.y:=r*sin(angle);
   result.z:=h*2;
  end;
 // Calculate surface normal
 function CalcNormal(u,v:single):TVec3;
  var
   v1,v2:TVec3;
  begin
   v1:=CalcSurface(u+0.001,v)-CalcSurface(u-0.001,v);
   v2:=CalcSurface(u,v+0.001)-CalcSurface(u,v-0.001);
   result:=v1.Cross(v2);
   result.Normalize;
  end;
 function GetVertex(u,v:integer):integer;
  begin
   result:=(u mod MESH_SEGMENTS)+v*MESH_SEGMENTS;
  end;
 var
  i,j:integer;
  u,v:single;
 begin
  // Create mesh
  trgCount:=MESH_SECTIONS*MESH_SEGMENTS*2;
  mesh:=TMesh.Create('surface');
  // Add vertices
  for i:=0 to MESH_SECTIONS do
   for j:=0 to MESH_SEGMENTS-1 do begin
    u:=j/MESH_SEGMENTS;
    v:=i/MESH_SECTIONS;
    mesh.AddVertex(CalcSurface(u,v),CalcNormal(u,v),$FF808080);
   end;
  // Add triangles
  for i:=0 to MESH_SECTIONS-1 do
   for j:=0 to MESH_SEGMENTS-1 do
    if i mod 2=0 then begin
     mesh.AddTriangle(GetVertex(j,i),GetVertex(j,i+1),GetVertex(j+1,i));
     mesh.AddTriangle(GetVertex(j,i+1),GetVertex(j+1,i+1),GetVertex(j+1,i));
    end else begin
     mesh.AddTriangle(GetVertex(j,i),GetVertex(j,i+1),GetVertex(j+1,i+1));
     mesh.AddTriangle(GetVertex(j,i),GetVertex(j+1,i+1),GetVertex(j+1,i));
    end;
  mesh.Finish;
 end;

{ TMainScene }
destructor TMainScene.Destroy;
 begin
  gpuMesh.Free;
  mesh.Free;
  inherited;
 end;

procedure TMainScene.Load;
 begin
  BuildMesh;
  loaded:=true;
  game.SwitchToScene('Main');
 end;

procedure TMainScene.InitGfx;
 begin
  inherited;
  if mesh=nil then exit;
  gpuMesh:=TGpuMesh.Create(mesh);
  gpuMesh.Upload;
 end;

procedure TMainScene.Render;
 var
  i,j:integer;
 begin
  gfx.target.Clear($204030,1);
  transform.Perspective(1,1,1000);
  transform.SetCamera(Vec3(0,30,10),Vec3(0,0,2),Vec3(0,0,1000));
  gfx.target.SetDepthMode(TDepthTest.Less);

  shader.AmbientLight($404030);
  shader.DirectLight(Vec3(1,1,1),2,$907060);
  transform.SetObj(0,3,3,3, 1, window.frameStartMs/1000,-0.6);
  if gpuMesh<>nil then gpuMesh.Draw;

  shader.AmbientLight($202020);
  shader.DirectLight(Vec3(1,1,1),1,$808090);
  for j:=0 to 3 do
   for i:=-2 to 2 do begin
    transform.SetObj(i*12,-20-j*10,j*6-12, 3, j, window.frameStartMs/1000,i);
    if gpuMesh<>nil then gpuMesh.Draw;
   end;

  shader.LightOff;
  transform.DefaultView;
  gfx.target.SetDepthMode(TDepthTest.Disabled);
  inherited;
  // Text overlays
  txt.Write(game.largerFont,Dp(10),Dp(20),clWhite,
    'Mesh triangles: '+IntToStr(trgCount div 1000)+'K'#10+
    'Total triangles: '+IntToStr(trgCount*21 div 1000)+'K');
  txt.Write(0,Dp(10),window.canvasHeight-Dp(30),clWhite,'[Alt]+[F11] - toggle VSync');
  txt.Write(0,Dp(10),window.canvasHeight-Dp(10),clWhite,'[Alt]+[Enter] - toggle Fullscreen');
 end;

end.
