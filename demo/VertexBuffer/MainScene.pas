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
 uses SysUtils, Apus.Types, Apus.Colors, Apus.Engine.UI, Apus.Geom3D;

 type
  // This will be our single scene
  TMainScene=class(TUIScene)
   procedure Load; override;
   procedure Render; override;
  end;

 const
  MESH_SEGMENTS = 100;
  MESH_SECTIONS = 240;

 var
  sceneMain:TMainScene;
  mesh:TMesh;
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
 end;

procedure BuildMesh;
 // Calculate surface point
 function CalcSurface(u,v:single):TPoint3s;
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
 function CalcNormal(u,v:single):TVector3s;
  var
   v1,v2:TVector3s;
  begin
   v1:=Vector3s(CalcSurface(u-0.001,v),CalcSurface(u+0.001,v));
   v2:=Vector3s(CalcSurface(u,v-0.001),CalcSurface(u,v+0.001));
   result:=CrossProduct(v1,v2);
   Normalize(result);
  end;
 function GetVertex(u,v:integer):integer;
  begin
   result:=(u mod MESH_SEGMENTS)+v*MESH_SEGMENTS;
  end;
 var
  i,j:integer;
  u,v:single;
  vertex:TVertex3D;
 begin
  // Create mesh
  trgCount:=MESH_SECTIONS*MESH_SEGMENTS*2;
  mesh:=TMesh.Create(TVertex3D.Layout(false),MESH_SEGMENTS*(MESH_SECTIONS+1),trgCount*3);
  for i:=0 to MESH_SECTIONS do
   for j:=0 to MESH_SEGMENTS-1 do begin
    u:=j/MESH_SEGMENTS;
    v:=i/MESH_SECTIONS;
    vertex.SetPos(CalcSurface(u,v));
    vertex.SetNormal(CalcNormal(u,v));
    vertex.color:=$FF808080;
    mesh.AddVertex(vertex);
   end;

  for i:=0 to MESH_SECTIONS-1 do
   for j:=0 to MESH_SEGMENTS-1 do
    if i mod 2=0 then begin
     mesh.AddTrg(GetVertex(j,i),GetVertex(j,i+1),GetVertex(j+1,i));
     mesh.AddTrg(GetVertex(j,i+1),GetVertex(j+1,i+1),GetVertex(j+1,i));
    end else begin
     mesh.AddTrg(GetVertex(j,i),GetVertex(j,i+1),GetVertex(j+1,i+1));
     mesh.AddTrg(GetVertex(j,i),GetVertex(j+1,i+1),GetVertex(j+1,i));
    end;

 end;

{ TMainScene }
procedure TMainScene.Load;
 begin
  BuildMesh;
  game.SwitchToScene('Main');
 end;


procedure TMainScene.Render;
 var
  i,j:integer;
 begin
  gfx.target.Clear($204030,1);
  transform.Perspective(1,1,1000);
  transform.SetCamera(Point3s(0,30,10),Point3s(0,0,2),Point3s(0,0,1000));

  shader.AmbientLight($404030);
  shader.DirectLight(Vector3(1,1,1),2,$907060);
  gfx.target.UseDepthBuffer(dbPassLess);

  transform.SetObj(0,3,3,3, 1, game.frameStartTime/1000,-0.6);
  mesh.Draw;

  shader.AmbientLight($202020);
  shader.DirectLight(Vector3(1,1,1),1,$808090);
  for j:=0 to 3 do
   for i:=-2 to 2 do begin
    transform.SetObj(i*12,-20-j*10,j*6-12, 3, j, game.frameStartTime/1000,i);
    mesh.Draw;
   end;

  shader.LightOff;
  transform.DefaultView;
  gfx.target.UseDepthBuffer(dbDisabled);
  inherited;
  txt.WriteW(0,10,20,clWhite,'Mesh triangles: '+IntToStr(trgCount div 1000)+'K');
  txt.WriteW(0,10,40,clWhite,'Total triangles: '+IntToStr(trgCount*21 div 1000)+'K');
 end;

end.
