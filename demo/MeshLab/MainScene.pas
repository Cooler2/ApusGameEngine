// MeshLab — visual validation stand for R-19 (SoA TMesh/TGpuMesh) and R-20
// (MeshShapes procedural generators).
//
// All shapes are laid out on a grid on the ground (XZ... no, XY plane, Z-up):
// the R-20 generator gallery (Box/Cylinder/Cone/Tube/Plane/Octasphere/UVSphere
// + an Append-built Arrow) plus the original R-19 regression set (lit cube,
// textured quad, multi-section row), all drawn through TGpuMesh via the
// table-driven binding path (ApplyMeshLayout + renderDevice.DrawMesh). A big
// rippled grid (90k verts, uint32 IBO) underlays everything as a floor.
//
// Navigation: LMB drag rotates, wheel zooms. Tab/Escape toggles between an
// overview of the whole grid and a focused view of one cell; arrow keys move
// the selection between cells while focused.
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
  Apus.Core, Apus.Conv, Apus.Geom2D, Apus.Geom3D,
  Apus.EventMan, Apus.Engine.Keys,
  Apus.Engine.Resources, // TTexFilter
  Apus.Engine.UI, Apus.Engine.UIScene,
  // listed after API so the unqualified TMesh resolves to the new SoA mesh, not
  // the legacy Apus.Engine.Mesh.TMesh that Apus.Engine.API re-exports (until C2)
  Apus.Engine.Mesh3D, Apus.Engine.GpuMesh, Apus.Engine.MeshShapes;

const
  GRID_COLS=4;
  GRID_ROWS=3;
  CELL=3.2;

type
  TItemKind=(gikLit,gikLitTextured,gikUnlitTextured,gikMultiSection);

  TGalleryItem=record
    name:String8;
    mesh:TMesh;
    gpu:TGpuMesh;
    col,row:integer;
    kind:TItemKind;
  end;

  TMainScene=class(TUIScene)
    items:array of TGalleryItem;
    floorMesh:TMesh;
    floorGpu:TGpuMesh;
    spin:single;
    cameraYaw,cameraPitch:single;
    overviewDist,focusDist:single;
    overview:boolean;
    selCol,selRow:integer;
    camTargetCur,camTargetGoal:TVec3;
    camDistCur,camDistGoal:single;
    constructor Create;
    destructor Destroy; override;
    procedure InitGfx; override;
    procedure Render; override;
    procedure onMouseMove(x,y:integer); override;
    procedure onMouseWheel(delta:integer); override;
    procedure HandleKey(keyCode:integer);
    function GridPos(c,r:integer):TVec3;
    function FindItem(c,r:integer):integer;
    procedure AddItem(const name:String8;m:TMesh;kind:TItemKind;c,r:integer);
  end;

var
  sceneMain:TMainScene;

// Constant-curvature ripple for the Plane gallery item: amplitude 0.3,
// period ~pi -> visibly bumpy within a 2x2 patch.
function RippleFn(x,y:single):single;
 begin
  result:=0.3*sin(x*2)*cos(y*2);
 end;

procedure MeshLabKeyHandler(event:TEventStr;tag:TTag);
 var
  keyCode:integer;
 begin
  if sceneMain=nil then exit;
  keyCode:=WordFromTag(tag,0);
  sceneMain.HandleKey(keyCode);
 end;

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

// A small textured quad on the z=0 plane (UV present -> auto-layout adds TexCoord).
function BuildTexQuad:TMesh;
 var
  m:TMesh;
 begin
  m:=TMesh.Create('quad');
  m.AddVertex(Vec3(-1,-1,0),Vec3(0,0,1),Vec2(0,0),$FFFFFFFF);
  m.AddVertex(Vec3( 1,-1,0),Vec3(0,0,1),Vec2(2,0),$FFFFFFFF);
  m.AddVertex(Vec3( 1, 1,0),Vec3(0,0,1),Vec2(2,2),$FFFFFFFF);
  m.AddVertex(Vec3(-1, 1,0),Vec3(0,0,1),Vec2(0,2),$FFFFFFFF);
  m.AddTriangle(0,1,2);
  m.AddTriangle(0,2,3);
  m.Finish;
  result:=m;
 end;

// A row of 4 small colored boxes, each in its own section -> proves
// TMesh.sections carries correct index ranges and TGpuMesh.DrawSection works.
function BuildMultiSectionRow:TMesh;
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
  procedure Box(cx,cy,cz,sz:single;color:cardinal;sectionName:String8);
   var
    x0,x1,y0,y1,z0,z1:single;
   begin
    x0:=cx-sz; x1:=cx+sz;
    y0:=cy-sz; y1:=cy+sz;
    z0:=cz-sz; z1:=cz+sz;
    m.BeginSection(sectionName);
    Face(Vec3(x0,y0,z0),Vec3(x1,y0,z0),Vec3(x1,y1,z0),Vec3(x0,y1,z0),Vec3(0,0,-1),color); // -Z
    Face(Vec3(x0,y0,z1),Vec3(x0,y1,z1),Vec3(x1,y1,z1),Vec3(x1,y0,z1),Vec3(0,0, 1),color); // +Z
    Face(Vec3(x0,y0,z0),Vec3(x0,y0,z1),Vec3(x1,y0,z1),Vec3(x1,y0,z0),Vec3(0,-1,0),color); // -Y
    Face(Vec3(x0,y1,z0),Vec3(x1,y1,z0),Vec3(x1,y1,z1),Vec3(x0,y1,z1),Vec3(0, 1,0),color); // +Y
    Face(Vec3(x1,y0,z0),Vec3(x1,y0,z1),Vec3(x1,y1,z1),Vec3(x1,y1,z0),Vec3( 1,0,0),color); // +X
    Face(Vec3(x0,y0,z0),Vec3(x0,y1,z0),Vec3(x0,y1,z1),Vec3(x0,y0,z1),Vec3(-1,0,0),color); // -X
    m.EndSection;
   end;
 begin
  m:=TMesh.Create('multiSection');
  Box(-1.2,0,0,0.35,$FFE05545,'part0'); // red
  Box(-0.4,0,0,0.35,$FF45E055,'part1'); // green
  Box( 0.4,0,0,0.35,$FF4555E0,'part2'); // blue
  Box( 1.2,0,0,0.35,$FFE0C040,'part3'); // yellow
  m.Finish;
  result:=m;
 end;

// A large rippled grid plane with >65535 vertices -> TGpuMesh.Upload picks a
// 32-bit index buffer. Filled directly via SetVertexCount for efficiency.
function BuildBigGrid:TMesh;
 const
  N=300; // 300x300 = 90000 verts > 65535 -> forces uint32 IBO
  step=0.12;
 var
  m:TMesh;
  x,y,i,idx,b:integer;
  px,py,pz:single;
  col:cardinal;
 begin
  m:=TMesh.Create('bigGrid');
  m.SetVertexCount(N*N,[TMeshAttribute.Normal,TMeshAttribute.Color]);
  for y:=0 to N-1 do
   for x:=0 to N-1 do begin
    i:=y*N+x;
    px:=(x-N/2)*step;
    py:=(y-N/2)*step;
    pz:=0.25*sin(px*1.3)*cos(py*1.3);
    m.positions[i]:=Vec3(px,py,pz);
    m.normals[i]:=Vec3(0,0,1); // flat approximation, good enough for a wireframe-ish ripple
    col:=$FF208060+(x*97+y*53) and $1F1F1F; // subtle per-cell color variation
    m.colors[i]:=col;
   end;
  SetLength(m.indices,(N-1)*(N-1)*6);
  idx:=0;
  for y:=0 to N-2 do
   for x:=0 to N-2 do begin
    b:=y*N+x;
    m.indices[idx]:=b;         m.indices[idx+1]:=b+1;     m.indices[idx+2]:=b+N+1;
    m.indices[idx+3]:=b;       m.indices[idx+4]:=b+N+1;   m.indices[idx+5]:=b+N;
    inc(idx,6);
   end;
  m.Finish;
  result:=m;
 end;

{ TMainApp }

constructor TMainApp.Create;
 begin
  inherited;
  gameTitle:='Apus Engine: MeshLab (R-19 + R-20 shapes gallery)';
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
  overviewDist:=18;
  focusDist:=5;
  camDistCur:=overviewDist;
  overview:=true;
  SetEventHandler('SCENE\MAIN\KEYDOWN',MeshLabKeyHandler,emInstant);
 end;

destructor TMainScene.Destroy;
 var
  i:integer;
 begin
  RemoveEventHandler(MeshLabKeyHandler);
  floorGpu.Free;
  floorMesh.Free;
  for i:=0 to high(items) do begin
   items[i].gpu.Free;
   items[i].mesh.Free;
  end;
  inherited;
 end;

// World-space (X,Y) center of a grid cell, Z=0 (ground plane).
function TMainScene.GridPos(c,r:integer):TVec3;
 begin
  result:=Vec3((c-(GRID_COLS-1)/2)*CELL,(r-(GRID_ROWS-1)/2)*CELL,0);
 end;

function TMainScene.FindItem(c,r:integer):integer;
 var
  i:integer;
 begin
  result:=-1;
  for i:=0 to high(items) do
   if (items[i].col=c) and (items[i].row=r) then exit(i);
 end;

procedure TMainScene.AddItem(const name:String8;m:TMesh;kind:TItemKind;c,r:integer);
 var
  it:TGalleryItem;
 begin
  it.name:=name;
  it.mesh:=m;
  it.gpu:=TGpuMesh.Create(m);
  it.gpu.Upload;
  it.col:=c;
  it.row:=r;
  it.kind:=kind;
  SetLength(items,length(items)+1);
  items[high(items)]:=it;
 end;

procedure TMainScene.InitGfx;
 var
  shaft,head:TMesh;
 begin
  // R-20 generator gallery
  AddItem('Box',MeshShapes.Box(2),gikLit,0,0);
  AddItem('Cylinder',MeshShapes.Cylinder(1,1,2,16,true),gikLit,1,0);
  AddItem('Cone',MeshShapes.Cylinder(1,0,2,16,true),gikLit,2,0);
  AddItem('Tube (open)',MeshShapes.Cylinder(1,1,2,16,false),gikLit,3,0);
  AddItem('Plane (ripple)',MeshShapes.Plane(2,2,8,8,@RippleFn),gikLit,0,1);
  AddItem('Octasphere',MeshShapes.Octasphere(2),gikLit,1,1);
  AddItem('UVSphere',MeshShapes.UVSphere(16,8),gikLitTextured,2,1);
  AddItem('UVSphere (hemisphere)',MeshShapes.UVSphere(16,8,0,2*Pi,0,Pi/2,1,true),gikLitTextured,3,1);

  // R-19 regression set
  AddItem('R-19 cube',BuildLitCube,gikLit,0,2);
  AddItem('R-19 quad',BuildTexQuad,gikUnlitTextured,1,2);
  AddItem('R-19 multi-section',BuildMultiSectionRow,gikMultiSection,2,2);

  // Arrow built via TMesh.Append (shaft + cone head) - preview of R-18 Arrow3D
  shaft:=MeshShapes.Cylinder(0.25,0.25,1.4,12,true);
  head:=MeshShapes.Cylinder(0.5,0,0.7,12,true);
  shaft.Append(head,TMat4.Translation(0,0,1.05));
  head.Free;
  AddItem('Arrow (Append)',shaft,gikLit,3,2);

  floorMesh:=BuildBigGrid;
  floorGpu:=TGpuMesh.Create(floorMesh);
  floorGpu.Upload;
  game.defaultTexture.SetFilter(TTexFilter.fltNearest); // crisp checker (no bilinear blur)
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
  if overview then begin
   if delta>0 then overviewDist:=overviewDist/1.12;
   if delta<0 then overviewDist:=overviewDist*1.12;
   overviewDist:=Clamp(overviewDist,10,28);
  end else begin
   if delta>0 then focusDist:=focusDist/1.12;
   if delta<0 then focusDist:=focusDist*1.12;
   focusDist:=Clamp(focusDist,2.5,9);
  end;
 end;

procedure TMainScene.HandleKey(keyCode:integer);
 begin
  case keyCode of
   ord(TKey.Tab),ord(TKey.Escape):overview:=not overview;
   ord(TKey.Left):if not overview then selCol:=(selCol-1+GRID_COLS) mod GRID_COLS;
   ord(TKey.Right):if not overview then selCol:=(selCol+1) mod GRID_COLS;
   ord(TKey.Up):if not overview then selRow:=(selRow-1+GRID_ROWS) mod GRID_ROWS;
   ord(TKey.Down):if not overview then selRow:=(selRow+1) mod GRID_ROWS;
  end;
 end;

procedure TMainScene.Render;
 var
  eye,target,pos:TVec3;
  i,s,selIdx:integer;
  statusText,hintText:String8;
  titleH,lineH,y1,y2,y3,panelW:integer;
 begin
  spin:=spin+0.006; // slow auto-rotation for a livelier view

  // camera target/distance fly smoothly toward the overview or the focused cell
  if overview then begin
   camTargetGoal:=Vec3(0,0,0);
   camDistGoal:=overviewDist;
  end else begin
   camTargetGoal:=GridPos(selCol,selRow);
   camDistGoal:=focusDist;
  end;
  camTargetCur:=camTargetCur+(camTargetGoal-camTargetCur)*0.15;
  camDistCur:=camDistCur+(camDistGoal-camDistCur)*0.15;

  gfx.target.Clear($14181F,1);

  target:=camTargetCur+Vec3(0,0,1.0);
  eye:=Vec3(camTargetCur.x+camDistCur*cos(cameraPitch)*cos(cameraYaw),
            camTargetCur.y+camDistCur*cos(cameraPitch)*sin(cameraYaw),
            1.0+camDistCur*sin(cameraPitch));
  transform.Perspective(0.95,0.2,100);
  transform.SetCamera(eye,target,Vec3(0,0,1000));
  gfx.SetCullMode(cullNone);
  gfx.target.UseDepthBuffer(dbPassLess);

  shader.AmbientLight($303838);
  shader.DirectLight(Vec3(0.4,0.6,1.0),1.0,$FFFFFF);

  // floor - underlays the whole grid (no UV -> texturing disabled)
  shader.TexMode(0,tblDisable,tblDisable);
  transform.SetObj(0,0,-1.5,1.0,0,0,0);
  floorGpu.Draw;

  // gallery items, one per grid cell
  for i:=0 to high(items) do begin
   pos:=GridPos(items[i].col,items[i].row);
   transform.SetObj(pos.x,pos.y,0,1.0,spin,0,0);
   case items[i].kind of
    gikLit:begin
     // most generators carry UV+tangent but no texture is meant to be shown
     // here -> disable texturing, else a stale bound texture (e.g. the glyph
     // cache from the overlay text) would get sampled and modulated in.
     shader.TexMode(0,tblDisable,tblDisable);
     items[i].gpu.Draw;
    end;
    gikLitTextured:begin
     shader.TexMode(0,tblModulate,tblModulate);
     items[i].gpu.Draw(game.defaultTexture);
    end;
    gikUnlitTextured:begin
     shader.LightOff;
     shader.TexMode(0,tblModulate,tblModulate);
     items[i].gpu.Draw(game.defaultTexture);
     shader.AmbientLight($303838);
     shader.DirectLight(Vec3(0.4,0.6,1.0),1.0,$FFFFFF);
    end;
    gikMultiSection:begin
     shader.TexMode(0,tblDisable,tblDisable);
     for s:=0 to high(items[i].mesh.sections) do items[i].gpu.DrawSection(s);
    end;
   end;
  end;

  // overlay - title + status + hint, on a translucent panel for contrast
  transform.DefaultView;
  shader.LightOff;
  shader.DefaultTexMode;
  gfx.target.UseDepthBuffer(dbDisabled);
  if overview then
   statusText:=Conv.ToStr(length(items))+' shapes - press Tab/Esc to focus'
  else begin
   selIdx:=FindItem(selCol,selRow);
   if selIdx>=0 then statusText:='Selected: '+items[selIdx].name+' - arrows to move, Tab/Esc for overview'
    else statusText:='(empty cell) - arrows to move, Tab/Esc for overview';
  end;
  hintText:='LMB: rotate camera    Wheel: zoom';

  titleH:=txt.Height(game.largerFont);
  lineH:=txt.Height(game.defaultFont);
  y1:=14;
  y2:=y1+titleH+8;
  y3:=y2+lineH+4;
  panelW:=txt.Width(game.largerFont,'R-20 MeshLab gallery');
  if txt.Width(game.defaultFont,statusText)>panelW then panelW:=txt.Width(game.defaultFont,statusText);
  if txt.Width(game.defaultFont,hintText)>panelW then panelW:=txt.Width(game.defaultFont,hintText);
  draw.FillRect(8,8,28+panelW,y3+lineH+10,$C8141A24);
  txt.Write(game.largerFont,18,y1,$FFFFFFFF,'R-20 MeshLab gallery');
  txt.Write(game.defaultFont,18,y2,$FFE8C25A,statusText);
  txt.Write(game.defaultFont,18,y3,$FFA8B4C4,hintText);
  inherited;
 end;

end.
