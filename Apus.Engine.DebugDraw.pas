// Immediate-mode debug 3D drawing helpers (R-18): solid gizmos (Box/Sphere/
// Capsule/Arrow3D/Axes) and line primitives (Line/Grid/Arrow2D/BoxWire).
//
// Solid shapes are unit meshes from Apus.Engine.MeshShapes (R-20), uploaded
// once into cached TGpuMesh (R-19) and reused for every draw. Per-shape color
// is applied via the material-tint uniform (shader.Material); lighting is the
// stock mesh shader (shader.AmbientLight/DirectLight). No per-frame CPU vertex
// work for solids. Lines remain immediate draw.Line3D - meshes don't help for
// 1-3-segment shapes. SetupRender/Flush bracket a group of calls and are also
// the seam where R-09 batching will plug in later.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.DebugDraw;
interface
uses Apus.Geom3D;

{$SCOPEDENUMS ON}
type
  // Grid plane selector: the two listed axes vary, the third is held at 0.
  TGridPlane=(XY,XZ,YZ);
{$SCOPEDENUMS OFF}

type
  DebugDraw=record
    // --- session ---
    class procedure SetupRender(depthTest:boolean=true); static; // configure render state before shapes
    class procedure Flush; static;                               // close the session (pairs with SetupRender; seam for R-09 batching)
    class procedure SetLight(ambient:cardinal;const dir:TVec3;power:single;color:cardinal); static;
    // --- solid (GPU mesh, default mode) ---
    class procedure Arrow3D(const p0,p1:TVec3;color:cardinal;radius:single=0.0); static;
    class procedure Axes(const origin:TVec3;len:single=1.0); static;
    class procedure Box(const center,halfSize:TVec3;color:cardinal); static;
    class procedure Sphere(const center:TVec3;radius:single;color:cardinal;segments:integer=16); static;
    class procedure Capsule(const p0,p1:TVec3;radius:single;color:cardinal;segments:integer=16); static;
    // --- lines (exceptions, immediate) ---
    class procedure Grid(size:single;cells:integer;color:cardinal;plane:TGridPlane=TGridPlane.XY); static;
    class procedure Arrow2D(const p0,p1:TVec3;color:cardinal); static;
    class procedure BoxWire(const center,halfSize:TVec3;color:cardinal); static;
    class procedure Line(const p0,p1:TVec3;color:cardinal); static;
  end;

implementation
uses Apus.Core, Math, Apus.Engine.API, Apus.Engine.Mesh3D, Apus.Engine.MeshShapes, Apus.Engine.GpuMesh;

const
  CYL_SEGMENTS=16; // default radial tessellation for the cached unit cylinder/cone

var
  lightAmbient:cardinal=$303838;
  lightDir:TVec3=(x:0.4; y:0.6; z:1.0); // towards the light; normalized in SetLight/initialization
  lightPower:single=1.0;
  lightColor:cardinal=$FFFFFF;
  // lazy unit-shape caches (model space, white pos+normal meshes), built once.
  // Cylinder/hemisphere/sphere keep a single slot keyed on the last requested
  // segments and rebuild on change (cheap thrash if a frame mixes resolutions).
  unitCube:TGpuMesh=nil;       // extent 1 (half 0.5), centered at origin
  unitCone:TGpuMesh=nil;       // r 1->0, h=1 along Z, centered at origin
  unitCylinder:TGpuMesh=nil;   // r=1, h=1 along Z, centered at origin; rebuilt when segments change
  unitCylinderSeg:integer=0;
  unitHemi:TGpuMesh=nil;       // hemisphere r=1, dome toward +Z; rebuilt when segments change
  unitHemiSeg:integer=0;
  unitSphere:TGpuMesh=nil;     // r=1; rebuilt when segments change
  unitSphereSeg:integer=0;

// Model->world matrix mapping unit shapes (radius 1, +Z axis) onto the
// segment p0->dir, scaled to radiusXY in X/Y and lenZ along Z.
function AxisBasis(const p0,dir:TVec3;radiusXY,lenZ:single):TMat4;
var
  rot:TMat3;
  axis,d:TVec3;
  ang:single;
  m34:TMat34;
begin
  d:=dir; d.Normalize;
  axis:=Vec3(0,0,1).Cross(d);
  if axis.Length<1E-5 then begin
    if d.z>=0 then rot:=TMat3.RotationX(0)
    else rot:=TMat3.RotationX(PI); // 180-degree flip, +Z -> -Z
  end else begin
    axis.Normalize;
    ang:=ArcCos(Clamp(d.z,-1.0,1.0));
    rot:=TMat3.RotationAroundAxis(axis,ang);
  end;
  rot.rows[0]:=rot.rows[0]*radiusXY;
  rot.rows[1]:=rot.rows[1]*radiusXY;
  rot.rows[2]:=rot.rows[2]*lenZ;
  m34.rows[0]:=rot.rows[0];
  m34.rows[1]:=rot.rows[1];
  m34.rows[2]:=rot.rows[2];
  m34.rows[3]:=p0;
  result:=m34.ToMat4;
end;

// Strip uv0/uv1/tangents/colors (lit-white pos+normal layout) and upload as a
// static GPU mesh - the CPU copy is discarded, only Draw (no DrawSection) is used.
function MakeGpu(m:TMesh):TGpuMesh;
begin
  SetLength(m.uv0,0); SetLength(m.uv1,0); SetLength(m.tangents,0); SetLength(m.colors,0);
  result:=TGpuMesh.Create(m);
  result.Upload([muDiscardCPUCopy]);
end;

function GetCube:TGpuMesh;
begin
  if unitCube=nil then unitCube:=MakeGpu(MeshShapes.Box(Vec3(1,1,1)));
  result:=unitCube;
end;

function GetCylinder(segments:integer):TGpuMesh;
begin
  if (unitCylinder=nil) or (unitCylinderSeg<>segments) then begin
    if unitCylinder<>nil then unitCylinder.Free;
    unitCylinder:=MakeGpu(MeshShapes.Cylinder(1,1,1,segments));
    unitCylinderSeg:=segments;
  end;
  result:=unitCylinder;
end;

function GetCone:TGpuMesh;
begin
  if unitCone=nil then unitCone:=MakeGpu(MeshShapes.Cylinder(1,0,1,CYL_SEGMENTS));
  result:=unitCone;
end;

// Upper hemisphere (dome toward +Z) as a UVSphere patch so its radial segments
// match the cylinder's for a seamless capsule joint. lat 0=+Z pole..pi/2=equator.
function GetHemi(segments:integer):TGpuMesh;
begin
  if (unitHemi=nil) or (unitHemiSeg<>segments) then begin
    if unitHemi<>nil then unitHemi.Free;
    unitHemi:=MakeGpu(MeshShapes.UVSphere(segments,Max(segments div 4,2),0,2*PI,0,PI/2,1));
    unitHemiSeg:=segments;
  end;
  result:=unitHemi;
end;

function GetSphere(segments:integer):TGpuMesh;
begin
  if (unitSphere=nil) or (unitSphereSeg<>segments) then begin
    if unitSphere<>nil then unitSphere.Free;
    unitSphere:=MakeGpu(MeshShapes.UVSphere(segments,Max(segments div 2,3),1));
    unitSphereSeg:=segments;
  end;
  result:=unitSphere;
end;

// Draw a cached unit mesh under model->world matrix m, tinted by color.
procedure DrawUnit(g:TGpuMesh;const m:TMat4;color:cardinal);
begin
  shader.Material(color,0);
  transform.SetObj(m);
  g.Draw;
end;

// Emit one world-space line. Callers reset the object matrix to identity once
// per line group (solids leave their own matrix); the eventual push/pop
// replacement is in Work/reports/transform_api_relative_matrix_design.md.
procedure EmitLine(const p0,p1:TVec3;color:cardinal);
begin
  draw.Line3D(p0.x,p0.y,p0.z,p1.x,p1.y,p1.z,color);
end;

{ DebugDraw }

class procedure DebugDraw.SetupRender(depthTest:boolean=true);
begin
  shader.TexMode(0,tblDisable,tblDisable);
  shader.AmbientLight(lightAmbient);
  shader.DirectLight(lightDir,lightPower,lightColor);
  transform.ResetObj;
  draw.SetZ(0);
  if depthTest then gfx.target.UseDepthBuffer(dbPass)
   else gfx.target.UseDepthBuffer(dbDisabled);
end;

class procedure DebugDraw.Flush;
begin
  shader.Material($FFFFFF,0); // restore neutral tint so it doesn't leak into the next mesh render
  shader.LightOff;
  shader.DefaultTexMode;
  // seam: later draw.Batching(false) (R-09)
end;

class procedure DebugDraw.SetLight(ambient:cardinal;const dir:TVec3;power:single;color:cardinal);
begin
  lightAmbient:=ambient;
  lightDir:=dir;
  lightDir.Normalize;
  lightPower:=power;
  lightColor:=color;
end;

class procedure DebugDraw.Box(const center,halfSize:TVec3;color:cardinal);
var
  m:TMat4;
begin
  m:=TMat4.Scale(halfSize.x*2,halfSize.y*2,halfSize.z*2)*TMat4.Translation(center.x,center.y,center.z);
  DrawUnit(GetCube,m,color);
end;

class procedure DebugDraw.Sphere(const center:TVec3;radius:single;color:cardinal;segments:integer=16);
var
  m:TMat4;
begin
  m:=TMat4.Scale(radius,radius,radius)*TMat4.Translation(center.x,center.y,center.z);
  DrawUnit(GetSphere(segments),m,color);
end;

class procedure DebugDraw.Arrow3D(const p0,p1:TVec3;color:cardinal;radius:single=0.0);
const
  HEAD_FRACTION=0.2; // fraction of total length used by the cone head
var
  dir:TVec3;
  len,shaftLen,coneLen,shaftR,coneR:single;
  shaftCenter,coneCenter:TVec3;
begin
  dir:=Vec3(p0,p1);
  len:=dir.Length;
  if len<1E-6 then exit;
  dir.Normalize;
  if radius<=0 then radius:=len*0.03;
  shaftR:=radius;
  coneR:=radius*2;
  coneLen:=len*HEAD_FRACTION;
  shaftLen:=len-coneLen;
  shaftCenter:=p0+dir*(shaftLen*0.5);
  coneCenter:=p0+dir*(shaftLen+coneLen*0.5);
  DrawUnit(GetCylinder(CYL_SEGMENTS),AxisBasis(shaftCenter,dir,shaftR,shaftLen),color);
  DrawUnit(GetCone,AxisBasis(coneCenter,dir,coneR,coneLen),color);
end;

class procedure DebugDraw.Axes(const origin:TVec3;len:single=1.0);
begin
  Arrow3D(origin,origin+Vec3(len,0,0),$FFE03030); // X - red
  Arrow3D(origin,origin+Vec3(0,len,0),$FF30C050); // Y - green
  Arrow3D(origin,origin+Vec3(0,0,len),$FF3060FF); // Z - blue
end;

class procedure DebugDraw.Capsule(const p0,p1:TVec3;radius:single;color:cardinal;segments:integer=16);
var
  dir,mid:TVec3;
  len:single;
begin
  dir:=Vec3(p0,p1);
  len:=dir.Length;
  if len>1E-6 then dir.Normalize
  else dir:=Vec3(0,0,1);
  mid:=(p0+p1)*0.5;
  if len>1E-6 then
    DrawUnit(GetCylinder(segments),AxisBasis(mid,dir,radius,len),color);
  DrawUnit(GetHemi(segments),AxisBasis(p1,dir,radius,radius),color);
  DrawUnit(GetHemi(segments),AxisBasis(p0,dir*(-1.0),radius,radius),color);
end;

class procedure DebugDraw.Line(const p0,p1:TVec3;color:cardinal);
begin
  transform.ResetObj; // world-space; clear any object matrix left by a prior solid
  EmitLine(p0,p1,color);
end;

class procedure DebugDraw.Grid(size:single;cells:integer;color:cardinal;plane:TGridPlane=TGridPlane.XY);
var
  i,r,g,b,a:integer;
  t,half:single;
  centerColor:cardinal;
  p1,p2,q1,q2:TVec3;
begin
  transform.ResetObj; // world-space group; clear any object matrix left by a prior solid
  half:=size*0.5;
  a:=(color shr 24) and $FF;
  r:=Min(255,((color shr 16) and $FF)*2);
  g:=Min(255,((color shr 8) and $FF)*2);
  b:=Min(255,(color and $FF)*2);
  centerColor:=cardinal(a shl 24) or cardinal(r shl 16) or cardinal(g shl 8) or cardinal(b);
  for i:=0 to cells do begin
    t:=-half+i*(size/cells);
    case plane of
      TGridPlane.XY: begin
        p1:=Vec3(t,-half,0); p2:=Vec3(t,half,0);
        q1:=Vec3(-half,t,0); q2:=Vec3(half,t,0);
      end;
      TGridPlane.XZ: begin
        p1:=Vec3(t,0,-half); p2:=Vec3(t,0,half);
        q1:=Vec3(-half,0,t); q2:=Vec3(half,0,t);
      end;
      else begin // TGridPlane.YZ
        p1:=Vec3(0,t,-half); p2:=Vec3(0,t,half);
        q1:=Vec3(0,-half,t); q2:=Vec3(0,half,t);
      end;
    end;
    if abs(t)<1E-6 then begin
      EmitLine(p1,p2,centerColor);
      EmitLine(q1,q2,centerColor);
    end else begin
      EmitLine(p1,p2,color);
      EmitLine(q1,q2,color);
    end;
  end;
end;

class procedure DebugDraw.Arrow2D(const p0,p1:TVec3;color:cardinal);
var
  dir,perp,tip:TVec3;
  len:single;
begin
  dir:=Vec3(p0,p1);
  len:=dir.Length;
  if len<1E-6 then exit;
  transform.ResetObj; // world-space group; clear any object matrix left by a prior solid
  dir.Normalize;
  tip:=p1;
  perp:=dir.Cross(Vec3(0,0,1));
  if perp.Length<0.1 then perp:=dir.Cross(Vec3(1,0,0));
  perp.Normalize;
  perp:=perp*(len*0.1);
  EmitLine(p0,tip,color);
  EmitLine(tip,tip-dir*(len*0.15)+perp,color);
  EmitLine(tip,tip-dir*(len*0.15)-perp,color);
end;

class procedure DebugDraw.BoxWire(const center,halfSize:TVec3;color:cardinal);
const
  SIGNS:array[0..7,0..2] of single=(
    (-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
    (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1));
var
  c:array[0..7] of TVec3;
  i:integer;
begin
  transform.ResetObj; // world-space group; clear any object matrix left by a prior solid
  for i:=0 to 7 do
    c[i]:=Vec3(center.x+halfSize.x*SIGNS[i,0],center.y+halfSize.y*SIGNS[i,1],center.z+halfSize.z*SIGNS[i,2]);
  EmitLine(c[0],c[1],color); EmitLine(c[1],c[2],color); EmitLine(c[2],c[3],color); EmitLine(c[3],c[0],color);
  EmitLine(c[4],c[5],color); EmitLine(c[5],c[6],color); EmitLine(c[6],c[7],color); EmitLine(c[7],c[4],color);
  EmitLine(c[0],c[4],color); EmitLine(c[1],c[5],color); EmitLine(c[2],c[6],color); EmitLine(c[3],c[7],color);
end;

initialization
  lightDir.Normalize;
end.
