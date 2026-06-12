// MeshLab — visual validation stand for R-19 stages B3/B4.
//
// It builds two CPU meshes with the new SoA TMesh (Apus.Engine.Mesh3D), uploads
// them as TGpuMesh (Apus.Engine.GpuMesh) and draws them through the new
// table-driven binding path (ApplyMeshLayout + renderDevice.DrawMesh) — NOT the
// legacy TVertexLayout painter. If both objects render correctly this proves the
// descriptor binder, the stable semantic->location table and the auto-generated
// mesh shaders (lit + textured variants) all agree.
//
//   * a lit, vertex-coloured cube (Position+Normal+Color, no UV, indexed) — checks
//     position/normal/color locations, per-fragment lighting and the uint16 IBO;
//   * a textured quad (Position+Normal+Color+TexCoord, indexed) — checks the
//     TexCoord location and texture sampling on the same path.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit MainScene;
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
uses
  Apus.Core, Apus.Geom2D, Apus.Geom3D,
  Apus.Engine.Resources, // TTexFilter
  Apus.Engine.UI, Apus.Engine.UIScene,
  // listed after API so the unqualified TMesh resolves to the new SoA mesh, not
  // the legacy Apus.Engine.Mesh.TMesh that Apus.Engine.API re-exports (until C2)
  Apus.Engine.Mesh3D, Apus.Engine.GpuMesh;

type
  TMainScene=class(TUIScene)
    cube,quad:TMesh;
    gpuCube,gpuQuad:TGpuMesh;
    spin:single;
    cameraYaw,cameraPitch,cameraDist:single;
    constructor Create;
    destructor Destroy; override;
    procedure InitGfx; override;
    procedure Render; override;
    procedure onMouseMove(x,y:integer); override;
    procedure onMouseWheel(delta:integer); override;
  end;

var
  sceneMain:TMainScene;

// A flat-shaded, vertex-coloured cube: 24 verts (4 per face, per-face normal),
// 36 indices. No texture coords -> auto-layout omits TexCoord.
function BuildLitCube:TMesh;
 var
  m:TMesh;
  procedure Face(const p0,p1,p2,p3,n:TVec3;color:cardinal);
   var
    b:integer;
   begin
    b:=m.AddVertex(p0,n,color);
    m.AddVertex(p1,n,color);
    m.AddVertex(p2,n,color);
    m.AddVertex(p3,n,color);
    m.AddTriangle(b,b+1,b+2);
    m.AddTriangle(b,b+2,b+3);
   end;
 begin
  m:=TMesh.Create('cube');
  Face(Vec3(-1,-1,-1),Vec3( 1,-1,-1),Vec3( 1, 1,-1),Vec3(-1, 1,-1),Vec3(0,0,-1),$FFE05545); // -Z red
  Face(Vec3(-1,-1, 1),Vec3(-1, 1, 1),Vec3( 1, 1, 1),Vec3( 1,-1, 1),Vec3(0,0, 1),$FF45E055); // +Z green
  Face(Vec3(-1,-1,-1),Vec3(-1,-1, 1),Vec3( 1,-1, 1),Vec3( 1,-1,-1),Vec3(0,-1,0),$FF4555E0); // -Y blue
  Face(Vec3(-1, 1,-1),Vec3( 1, 1,-1),Vec3( 1, 1, 1),Vec3(-1, 1, 1),Vec3(0, 1,0),$FFE0C040); // +Y yellow
  Face(Vec3( 1,-1,-1),Vec3( 1,-1, 1),Vec3( 1, 1, 1),Vec3( 1, 1,-1),Vec3( 1,0,0),$FFE040C0); // +X magenta
  Face(Vec3(-1,-1,-1),Vec3(-1, 1,-1),Vec3(-1, 1, 1),Vec3(-1,-1, 1),Vec3(-1,0,0),$FF40C0E0); // -X cyan
  m.Finish;
  result:=m;
 end;

// A textured ground quad on the z=0 plane (UV present -> auto-layout adds TexCoord).
function BuildTexQuad:TMesh;
 var
  m:TMesh;
 begin
  m:=TMesh.Create('quad');
  m.AddVertex(Vec3(-4,-4,0),Vec3(0,0,1),Vec2(0,0),$FFFFFFFF);
  m.AddVertex(Vec3( 4,-4,0),Vec3(0,0,1),Vec2(4,0),$FFFFFFFF);
  m.AddVertex(Vec3( 4, 4,0),Vec3(0,0,1),Vec2(4,4),$FFFFFFFF);
  m.AddVertex(Vec3(-4, 4,0),Vec3(0,0,1),Vec2(0,4),$FFFFFFFF);
  m.AddTriangle(0,1,2);
  m.AddTriangle(0,2,3);
  m.Finish;
  result:=m;
 end;

{ TMainApp }

constructor TMainApp.Create;
 begin
  inherited;
  gameTitle:='Apus Engine: MeshLab (R-19 B3/B4)';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=false;
  windowWidth:=1280;
  windowHeight:=800;
  windowSizeable:=true;
  useTweakerScene:=false;
 end;

procedure TMainApp.CreateScenes;
 begin
  inherited;
  sceneMain:=TMainScene.Create;
  sceneMain.SetStatus(TSceneStatus.ssActive);
 end;

{ TMainScene }

constructor TMainScene.Create;
 begin
  inherited Create('Main');
  cameraYaw:=0.8;
  cameraPitch:=0.5;
  cameraDist:=11;
 end;

destructor TMainScene.Destroy;
 begin
  gpuCube.Free;
  gpuQuad.Free;
  // gpu meshes discard their source on upload? No (we don't pass muDiscardCPUCopy),
  // so the CPU meshes are still owned here.
  cube.Free;
  quad.Free;
  inherited;
 end;

procedure TMainScene.InitGfx;
 begin
  cube:=BuildLitCube;
  quad:=BuildTexQuad;
  gpuCube:=TGpuMesh.Create(cube);
  gpuCube.Upload;
  gpuQuad:=TGpuMesh.Create(quad);
  gpuQuad.Upload;
  game.defaultTexture.SetFilter(TTexFilter.fltNearest); // crisp checker floor (no bilinear blur)
 end;

procedure TMainScene.onMouseMove(x,y:integer);
 var
  dx,dy:single;
 begin
  inherited;
  if (window.mouseButtons and mbLeft)>0 then begin
   dx:=x-window.oldMousePos.x;
   dy:=y-window.oldMousePos.y;
   cameraYaw:=cameraYaw-dx*0.008;
   cameraPitch:=Clamp(cameraPitch+dy*0.01,-1.2,1.2);
  end;
 end;

procedure TMainScene.onMouseWheel(delta:integer);
 begin
  inherited;
  if delta>0 then cameraDist:=cameraDist/1.12;
  if delta<0 then cameraDist:=cameraDist*1.12;
  cameraDist:=Clamp(cameraDist,4,24);
 end;

procedure TMainScene.Render;
 var
  eye,target:TVec3;
 begin
  spin:=spin+0.006; // slow auto-rotation for a livelier screenshot
  gfx.target.Clear($14181F,1);

  target:=Vec3(0,0,1.0);
  eye:=Vec3(cameraDist*cos(cameraPitch)*cos(cameraYaw),
            cameraDist*cos(cameraPitch)*sin(cameraYaw),
            1.0+cameraDist*sin(cameraPitch));
  transform.Perspective(0.95,0.2,100);
  transform.SetCamera(eye,target,Vec3(0,0,1000));
  gfx.SetCullMode(cullNone);
  gfx.target.UseDepthBuffer(dbPassLess);

  // textured ground quad (unlit) — checks TexCoord location + texture sampling
  shader.LightOff;
  shader.TexMode(0,tblModulate,tblModulate);
  transform.SetObj(0,0,0);
  gpuQuad.Draw(game.defaultTexture);

  // lit, vertex-coloured cube — checks position/normal/color + per-fragment light
  shader.AmbientLight($303838);
  shader.DirectLight(Vec3(0.4,0.6,1.0),1.0,$FFFFFF);
  transform.SetObj(0,0,2.0,1.0,spin,0,0); // yaw spin around the vertical axis
  gpuCube.Draw;

  // overlay
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled);
  txt.Write(0,18,24,$FFE8EDF5,'R-19 MeshLab - new SoA TMesh + TGpuMesh through the table-driven path (B3/B4)');
  txt.Write(0,18,46,$FFC8D2DF,'Lit vertex-colored cube (no UV) + textured quad (UV). LMB rotate, wheel zoom.');
  inherited;
 end;

end.
