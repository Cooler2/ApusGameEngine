// Procedural primitive mesh generators (R-20).
//
// Each generator is a pure fresh producer: it returns a new TMesh through the
// public fill-API (Apus.Engine.Mesh3D) with a sensible default attribute set.
// Generators do NOT take a target/transform - composition and merging is done
// via TMesh.Append. See Work/reports/R-20_meshshapes_design.md for the design.
//
// Conventions (apply to every generator):
//  - shapes are centered at origin (Box/sphere/cylinder centered; Plane on XZ)
//  - up axis = +Y; cylinder/cone axis = Y; Plane lies in XZ
//  - winding: CCW = front face (outward-facing)
//  - size params are full extents, not half
//  - tangent stored along +U, bitangent = cross(N,T) in shader
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.MeshShapes;
interface
uses Apus.Core, Apus.Geom2D, Apus.Geom3D, Apus.Engine.Mesh3D;

{$SCOPEDENUMS ON}
type
 // Octant-subset selection for partial Octasphere generation.
 TSpherePortion=(Full,Hemisphere,Quarter,Eighth);
{$SCOPEDENUMS OFF}

type
 // Height displacement callback for MeshShapes.Plane: y = heightFn(x,z).
 THeightFn=function(x,z:single):single;

 // Namespace record - all generators are static class functions.
 MeshShapes=record
  // Axis-aligned box centered at origin. 24 verts (4/face), 12 tris.
  // pos+normal+uv+tangent; per-face UV in [0,1], tangent along the face's +U.
  class function Box(const size:TVec3):TMesh; static; overload;
  // Cube variant: Box(Vec3(s,s,s)).
  class function Box(s:single):TMesh; static; overload;

  // Cylinder / cone / truncated cone / tube, axis = Y, centered at origin.
  // r1 = bottom radius, r2 = top radius (r2=0 -> cone; r1<>r2 -> truncated
  // cone), height = full extent along Y, segments = radial subdivisions.
  // caps adds flat end discs (normal +-Y). pos+normal+uv+tangent; side
  // normals smooth around the circumference (cone apex = ring of distinct
  // per-segment vertices, NOT a single shared apex); cap normals flat.
  class function Cylinder(r1,r2,height:single;segments:integer;caps:boolean=true):TMesh; static;
 end;

implementation

{ MeshShapes }

class function MeshShapes.Box(s:single):TMesh;
 begin
  result:=Box(Vec3(s,s,s));
 end;

class function MeshShapes.Box(const size:TVec3):TMesh;
 const
  // Per-face axes: N (outward normal), U (+U tangent direction), V (= cross(N,T)
  // bitangent direction). Chosen so N=Cross(U,V) -> CCW (0,0),(1,0),(1,1),(0,1)
  // winding is outward-facing and handedness w=+1 for every face.
  faceN:array[0..5] of TVec3=(
   (x:1; y:0; z:0),(x:-1;y:0; z:0),
   (x:0; y:1; z:0),(x:0; y:-1;z:0),
   (x:0; y:0; z:1),(x:0; y:0; z:-1));
  faceU:array[0..5] of TVec3=(
   (x:0; y:0; z:-1),(x:0;y:0; z:1),
   (x:1; y:0; z:0), (x:1;y:0; z:0),
   (x:1; y:0; z:0), (x:-1;y:0;z:0));
  faceV:array[0..5] of TVec3=(
   (x:0; y:1; z:0),(x:0;y:1; z:0),
   (x:0; y:0; z:-1),(x:0;y:0;z:1),
   (x:0; y:1; z:0),(x:0;y:1; z:0));
  cornerUV:array[0..3] of TVec2=((x:0;y:0),(x:1;y:0),(x:1;y:1),(x:0;y:1));
 var
  half:TVec3;
  f,i,vi:integer;
  n,u,v:TVec3;
  sizeU,sizeV,halfN:single;
 begin
  result:=TMesh.Create('box');
  result.SetVertexCount(24,[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  half:=size*0.5;
  for f:=0 to 5 do begin
   n:=faceN[f]; u:=faceU[f]; v:=faceV[f];
   sizeU:=abs(u.x)*size.x+abs(u.y)*size.y+abs(u.z)*size.z;
   sizeV:=abs(v.x)*size.x+abs(v.y)*size.y+abs(v.z)*size.z;
   halfN:=abs(n.x)*half.x+abs(n.y)*half.y+abs(n.z)*half.z;
   for i:=0 to 3 do begin
    vi:=f*4+i;
    result.positions[vi]:=n*halfN+u*((cornerUV[i].x-0.5)*sizeU)+v*((cornerUV[i].y-0.5)*sizeV);
    result.normals[vi]:=n;
    result.uv0[vi]:=cornerUV[i];
    result.tangents[vi]:=Vec4(u,1);
   end;
   result.AddTriangle(f*4+0,f*4+1,f*4+2);
   result.AddTriangle(f*4+0,f*4+2,f*4+3);
  end;
  result.Finish;
 end;

class function MeshShapes.Cylinder(r1,r2,height:single;segments:integer;caps:boolean=true):TMesh;
 var
  vcSide,vc,i,vi,bi0,ti0,bi1,ti1,capCenter,capRing:integer;
  halfH,angle,dAngle,cosA,sinA:single;
  nDir:TVec3;
 begin
  ASSERT(segments>=3,'Cylinder: segments must be >=3');
  halfH:=height*0.5;
  dAngle:=2*PI/segments;
  vcSide:=2*(segments+1);
  vc:=vcSide;
  if caps then inc(vc,2*(segments+1));
  result:=TMesh.Create('cylinder');
  result.SetVertexCount(vc,[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  // side: segments+1 columns (seam duplicated for UV wrap) x 2 rows (bottom,top)
  for i:=0 to segments do begin
   angle:=i*dAngle;
   cosA:=cos(angle); sinA:=sin(angle);
   nDir:=Vec3(height*cosA,r1-r2,height*sinA);
   nDir.Normalize;
   vi:=2*i;
   result.positions[vi]:=Vec3(r1*cosA,-halfH,r1*sinA);
   result.normals[vi]:=nDir;
   result.uv0[vi]:=Vec2(i/segments,0);
   result.tangents[vi]:=Vec4(-sinA,0,cosA,-1);
   vi:=2*i+1;
   result.positions[vi]:=Vec3(r2*cosA,halfH,r2*sinA);
   result.normals[vi]:=nDir;
   result.uv0[vi]:=Vec2(i/segments,1);
   result.tangents[vi]:=Vec4(-sinA,0,cosA,-1);
  end;
  for i:=0 to segments-1 do begin
   bi0:=2*i; ti0:=2*i+1; bi1:=2*(i+1); ti1:=2*(i+1)+1;
   result.AddTriangle(bi0,ti0,bi1);
   result.AddTriangle(bi1,ti0,ti1);
  end;
  if caps then begin
   // bottom cap (normal -Y): fan (center,ring_i,ring_i+1) is outward-CCW
   capCenter:=vcSide;
   capRing:=vcSide+1;
   result.positions[capCenter]:=Vec3(0,-halfH,0);
   result.normals[capCenter]:=Vec3(0,-1,0);
   result.uv0[capCenter]:=Vec2(0.5,0.5);
   result.tangents[capCenter]:=Vec4(1,0,0,1);
   for i:=0 to segments-1 do begin
    angle:=i*dAngle;
    cosA:=cos(angle); sinA:=sin(angle);
    vi:=capRing+i;
    result.positions[vi]:=Vec3(r1*cosA,-halfH,r1*sinA);
    result.normals[vi]:=Vec3(0,-1,0);
    result.uv0[vi]:=Vec2(0.5+0.5*cosA,0.5+0.5*sinA);
    result.tangents[vi]:=Vec4(1,0,0,1);
   end;
   for i:=0 to segments-1 do
    result.AddTriangle(capCenter,capRing+i,capRing+((i+1) mod segments));
   // top cap (normal +Y): fan (center,ring_i+1,ring_i) is outward-CCW
   capCenter:=vcSide+segments+1;
   capRing:=capCenter+1;
   result.positions[capCenter]:=Vec3(0,halfH,0);
   result.normals[capCenter]:=Vec3(0,1,0);
   result.uv0[capCenter]:=Vec2(0.5,0.5);
   result.tangents[capCenter]:=Vec4(1,0,0,1);
   for i:=0 to segments-1 do begin
    angle:=i*dAngle;
    cosA:=cos(angle); sinA:=sin(angle);
    vi:=capRing+i;
    result.positions[vi]:=Vec3(r2*cosA,halfH,r2*sinA);
    result.normals[vi]:=Vec3(0,1,0);
    result.uv0[vi]:=Vec2(0.5+0.5*cosA,0.5+0.5*sinA);
    result.tangents[vi]:=Vec4(1,0,0,1);
   end;
   for i:=0 to segments-1 do
    result.AddTriangle(capCenter,capRing+((i+1) mod segments),capRing+i);
  end;
  result.Finish;
 end;

end.
