// CPU triangle mesh — SoA container (R-19).
//
// TMesh stores geometry as per-attribute typed arrays (Structure-of-Arrays):
// positions/normals/colors/uv0/uv1/tangents/joints/weights, plus int32 indices
// and geometric sections (index ranges, no material). An empty attribute array
// means the attribute is absent. Interleaving into GPU buffers is a concern of
// the upload step (TGpuMesh, stage B4), NOT of this container.
//
// TMesh is a triangle mesh only — there is no primitive-type field. Wireframe is
// a polygon-mode render-state over the same triangles; dynamic lines/points go
// through the R-18 drawer batch. Indices are optional (empty => glDrawArrays,
// non-empty => glDrawElements over GL_TRIANGLES).
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Mesh;
interface
uses Apus.Core, Apus.Classes, Apus.Geom2D, Apus.Geom3D;

{$SCOPEDENUMS ON}
type
 // Optional standard attributes a mesh may carry (position is always present).
 // Used by SetVertexCount to size the active attribute arrays for direct fill.
 TMeshAttribute=(Normal,Color,UV0,UV1,Tangent,Joints,Weights);
 TMeshAttributes=set of TMeshAttribute;
{$SCOPEDENUMS OFF}

type
 // 4 bone indices per vertex (CPU storage; encoded to UByte4 on upload).
 TJoints4=array[0..3] of word;
 // 4 bone weights per vertex (CPU storage; normalized + encoded on upload).
 TWeights4=array[0..3] of single;

 // A geometric section: a named range of indices. Carries NO material — the
 // material is assigned in the model/instance layer, indexed by section.
 TMeshSection=record
  name:String8;
  firstIndex:integer;
  indexCount:integer;
 end;

 TMesh=class(TNamedObject)
  // standard attributes (empty array = attribute absent)
  positions:TVec3Array;
  normals:TVec3Array;
  colors:array of cardinal;     // full-precision color storage
  uv0,uv1:TVec2Array;
  tangents:TVec4Array;          // xyz = tangent direction (along +U in UV space, world space after upload)
                                // w = handedness: B = cross(T,N)*w reconstructs the bitangent (+V direction)
  joints:array of TJoints4;     // 4 bone indices
  weights:array of TWeights4;   // 4 weights (normalized on upload)
  // topology
  indices:IntArray;             // always 32-bit on CPU; optional
  sections:array of TMeshSection;
  // spatial
  bounds:TBox3;
  boundsDirty:boolean;

  constructor Create(const aName:String8='');

  function VertexCount:integer; // = length(positions)
  function IndexCount:integer;  // = length(indices)
  function TriangleCount:integer;
  function MaxIndex:integer;    // O(n) scan, cached after Finish

  // --- build API (cursors are cheap; no separate heap builder) ---
  // Preallocate and size the standard attribute arrays for direct, index-based
  // fill (generators/loaders that know the vertex count upfront): positions plus
  // each requested attribute are set to n, every other attribute array is cleared.
  // Fill the public arrays by index, set indices, then call Finish. This keeps the
  // length(array)==count invariant — there is no hidden capacity model. Marks
  // bounds dirty. (For incremental/irregular build use AddVertex instead.)
  procedure SetVertexCount(n:integer;attrs:TMeshAttributes=[]);
  // position+normal+color, no texture coords (flat-shaded colored geometry)
  function AddVertex(const p,n:TVec3;color:cardinal):integer; overload;
  function AddVertex(const p,n:TVec3;const uv:TVec2;color:cardinal):integer; overload;
  function AddVertex(const p,n:TVec3;const tangent:TVec4;
    const uv:TVec2;color:cardinal):integer; overload;
  procedure AddTriangle(v0,v1,v2:integer);
  procedure BeginSection(const aName:String8);
  procedure EndSection;
  procedure AddSection(const aName:String8;firstIndex,indexCount:integer);

  // Append src into self under transform m: positions <- m*pos, normals/tangents
  // rotated by the linear part of m (re-normalized, xyz only), indices offset by
  // the current vertex count. Attributes present in self but absent in src are
  // left at their default value; attributes present in src but absent in self
  // are dropped (R-19 stage-A guarded semantics). Adds and returns a new
  // (unnamed) section covering the appended index range. Marks bounds dirty.
  function Append(const src:TMesh;const m:TMat4):TMeshSection;

  // Validate, compute MaxIndex/bounds, mark bounds clean. Call once after build.
  procedure Finish;
  procedure RecalculateBounds; // also clears boundsDirty

 private
  fMaxIndex:integer;
  fMaxIndexValid:boolean;
  openSection:integer; // index in sections[] of the section being built, or -1
 end;

// Mesh utility operations: standalone procedures that operate on TMesh
// without requiring structural state. Heavy ops (topology, BVH) → R-21 TMeshEditor.
type
 MeshOps = record
  // Fill mesh.normals with area-weighted smooth normals.
  // Winding convention: vertices CCW when viewed from outside (outward-facing side).
  // cross(e1,e2) then yields outward normals — same as OpenGL front-face default.
  // Requires positions + indices. Replaces any previous normals array.
  class procedure ComputeNormals(mesh:TMesh); static;
  // Fill mesh.tangents from UV space: xyz = tangent along +U (world), w = handedness ±1.
  // Handedness w encodes: bitangent B = cross(T,N)*w points along +V.
  // Requires positions, normals, uv0, indices (call ComputeNormals first if needed).
  // Replaces any previous tangents array.
  class procedure ComputeTangents(mesh:TMesh); static;
 end;

implementation

{ MeshOps }

class procedure MeshOps.ComputeNormals(mesh:TMesh);
var
 i,i0,i1,i2,n:integer;
 e1,e2,fn:TVec3;
begin
 n:=mesh.VertexCount;
 ASSERT(n>0,'MeshOps.ComputeNormals: empty mesh');
 ASSERT(length(mesh.indices)>0,'MeshOps.ComputeNormals: non-indexed mesh not supported');
 SetLength(mesh.normals,n);
 FillChar(mesh.normals[0],n*sizeof(TVec3),0);
 i:=0;
 while i+2<=high(mesh.indices) do begin
  i0:=mesh.indices[i]; i1:=mesh.indices[i+1]; i2:=mesh.indices[i+2];
  e1:=mesh.positions[i1]-mesh.positions[i0];
  e2:=mesh.positions[i2]-mesh.positions[i0];
  fn:=e1.Cross(e2); // area-weighted — not normalized before accumulation
  mesh.normals[i0]:=mesh.normals[i0]+fn;
  mesh.normals[i1]:=mesh.normals[i1]+fn;
  mesh.normals[i2]:=mesh.normals[i2]+fn;
  inc(i,3);
 end;
 for i:=0 to n-1 do mesh.normals[i].Normalize;
end;

class procedure MeshOps.ComputeTangents(mesh:TMesh);
var
 i,i0,i1,i2,n:integer;
 dp1,dp2,t,b,tn,tx:TVec3;
 du1x,du1y,du2x,du2y,det,r,d,w:single;
 tAcc,bAcc:TVec3Array;
begin
 n:=mesh.VertexCount;
 ASSERT(n>0,'MeshOps.ComputeTangents: empty mesh');
 ASSERT(length(mesh.normals)=n,'MeshOps.ComputeTangents: normals absent — call ComputeNormals first');
 ASSERT(length(mesh.uv0)=n,'MeshOps.ComputeTangents: uv0 absent');
 ASSERT(length(mesh.indices)>0,'MeshOps.ComputeTangents: non-indexed mesh not supported');
 SetLength(tAcc,n); FillChar(tAcc[0],n*sizeof(TVec3),0);
 SetLength(bAcc,n); FillChar(bAcc[0],n*sizeof(TVec3),0);
 i:=0;
 while i+2<=high(mesh.indices) do begin
  i0:=mesh.indices[i]; i1:=mesh.indices[i+1]; i2:=mesh.indices[i+2];
  dp1:=mesh.positions[i1]-mesh.positions[i0];
  dp2:=mesh.positions[i2]-mesh.positions[i0];
  du1x:=mesh.uv0[i1].x-mesh.uv0[i0].x; du1y:=mesh.uv0[i1].y-mesh.uv0[i0].y;
  du2x:=mesh.uv0[i2].x-mesh.uv0[i0].x; du2y:=mesh.uv0[i2].y-mesh.uv0[i0].y;
  det:=du1x*du2y-du1y*du2x;
  if abs(det)<1e-7 then begin inc(i,3); continue; end; // degenerate UV island
  r:=1.0/det;
  t:=(dp1*du2y-dp2*du1y)*r;
  b:=(dp2*du1x-dp1*du2x)*r;
  tAcc[i0]:=tAcc[i0]+t; tAcc[i1]:=tAcc[i1]+t; tAcc[i2]:=tAcc[i2]+t;
  bAcc[i0]:=bAcc[i0]+b; bAcc[i1]:=bAcc[i1]+b; bAcc[i2]:=bAcc[i2]+b;
  inc(i,3);
 end;
 SetLength(mesh.tangents,n);
 for i:=0 to n-1 do begin
  tn:=mesh.normals[i];
  tx:=tAcc[i];
  // Gram-Schmidt re-orthogonalize T against N
  d:=tn.Dot(tx);
  tx.x:=tx.x-tn.x*d; tx.y:=tx.y-tn.y*d; tx.z:=tx.z-tn.z*d;
  if tx.x*tx.x+tx.y*tx.y+tx.z*tx.z<1e-12 then begin
   // fallback: arbitrary perpendicular to N
   if abs(tn.x)<0.9 then tx:=Vec3(1,0,0)-tn*tn.x
    else tx:=Vec3(0,1,0)-tn*tn.y;
  end;
  tx.Normalize;
  // handedness: shader reconstructs B=cross(T,N)*w, so w=sign(cross(T,N)·bAcc)=-sign(cross(N,T)·bAcc)
  w:=-1.0;
  if tn.Cross(tx).Dot(bAcc[i])<0 then w:=1.0;
  mesh.tangents[i]:=Vec4(tx,w);
 end;
end;

{ TMesh }

constructor TMesh.Create(const aName:String8='');
 begin
  inherited Create;
  if aName<>'' then name:=aName;
  boundsDirty:=true;
  bounds.Reset;
  fMaxIndex:=-1;
  fMaxIndexValid:=false;
  openSection:=-1;
 end;

function TMesh.VertexCount:integer;
 begin
  result:=length(positions);
 end;

function TMesh.IndexCount:integer;
 begin
  result:=length(indices);
 end;

function TMesh.TriangleCount:integer;
 begin
  if length(indices)>0 then result:=length(indices) div 3
   else result:=length(positions) div 3;
 end;

function TMesh.MaxIndex:integer;
 var
  i:integer;
 begin
  if fMaxIndexValid then exit(fMaxIndex);
  result:=-1;
  for i:=0 to high(indices) do
   if indices[i]>result then result:=indices[i];
  fMaxIndex:=result;
  fMaxIndexValid:=true;
 end;

procedure TMesh.SetVertexCount(n:integer;attrs:TMeshAttributes=[]);
 begin
  SetLength(positions,n);
  if TMeshAttribute.Normal  in attrs then SetLength(normals,n)  else SetLength(normals,0);
  if TMeshAttribute.Color   in attrs then SetLength(colors,n)   else SetLength(colors,0);
  if TMeshAttribute.UV0     in attrs then SetLength(uv0,n)      else SetLength(uv0,0);
  if TMeshAttribute.UV1     in attrs then SetLength(uv1,n)      else SetLength(uv1,0);
  if TMeshAttribute.Tangent in attrs then SetLength(tangents,n) else SetLength(tangents,0);
  if TMeshAttribute.Joints  in attrs then SetLength(joints,n)   else SetLength(joints,0);
  if TMeshAttribute.Weights in attrs then SetLength(weights,n)  else SetLength(weights,0);
  boundsDirty:=true;
  fMaxIndexValid:=false;
 end;

function TMesh.AddVertex(const p,n:TVec3;color:cardinal):integer;
 var
  v:integer;
 begin
  v:=length(positions);
  SetLength(positions,v+1); positions[v]:=p;
  SetLength(normals,v+1);   normals[v]:=n;
  SetLength(colors,v+1);    colors[v]:=color;
  boundsDirty:=true;
  result:=v;
 end;

function TMesh.AddVertex(const p,n:TVec3;const uv:TVec2;color:cardinal):integer;
 var
  v:integer;
 begin
  v:=length(positions);
  SetLength(positions,v+1); positions[v]:=p;
  SetLength(normals,v+1);   normals[v]:=n;
  SetLength(uv0,v+1);       uv0[v]:=uv;
  SetLength(colors,v+1);    colors[v]:=color;
  boundsDirty:=true;
  result:=v;
 end;

function TMesh.AddVertex(const p,n:TVec3;const tangent:TVec4;
   const uv:TVec2;color:cardinal):integer;
 var
  v:integer;
 begin
  v:=AddVertex(p,n,uv,color);
  SetLength(tangents,v+1);
  tangents[v]:=tangent;
  result:=v;
 end;

procedure TMesh.AddTriangle(v0,v1,v2:integer);
 var
  i:integer;
 begin
  i:=length(indices);
  SetLength(indices,i+3);
  indices[i]:=v0;
  indices[i+1]:=v1;
  indices[i+2]:=v2;
  fMaxIndexValid:=false;
 end;

procedure TMesh.BeginSection(const aName:String8);
 var
  n:integer;
 begin
  ASSERT(openSection<0,'Section already open');
  n:=length(sections);
  SetLength(sections,n+1);
  sections[n].name:=aName;
  sections[n].firstIndex:=length(indices);
  sections[n].indexCount:=0;
  openSection:=n;
 end;

procedure TMesh.EndSection;
 begin
  ASSERT(openSection>=0,'No open section');
  sections[openSection].indexCount:=length(indices)-sections[openSection].firstIndex;
  openSection:=-1;
 end;

procedure TMesh.AddSection(const aName:String8;firstIndex,indexCount:integer);
 var
  n:integer;
 begin
  n:=length(sections);
  SetLength(sections,n+1);
  sections[n].name:=aName;
  sections[n].firstIndex:=firstIndex;
  sections[n].indexCount:=indexCount;
 end;

function TMesh.Append(const src:TMesh;const m:TMat4):TMeshSection;
 var
  baseVertex,baseIndex,n,i,s:integer;
  rot:TMat3;
  v:TVec3;
  t:TVec4;
 begin
  baseVertex:=VertexCount;
  baseIndex:=IndexCount;
  n:=src.VertexCount;
  rot:=TMat3.Init(m);

  SetLength(positions,baseVertex+n);
  for i:=0 to n-1 do positions[baseVertex+i]:=m.TransformPoint(src.positions[i]);

  if length(normals)>0 then begin
   SetLength(normals,baseVertex+n);
   if length(src.normals)>0 then
    for i:=0 to n-1 do begin
     v:=src.normals[i];
     rot.TransformPoints(@v,1,0);
     v.Normalize;
     normals[baseVertex+i]:=v;
    end;
  end;

  if length(colors)>0 then begin
   SetLength(colors,baseVertex+n);
   if length(src.colors)>0 then
    for i:=0 to n-1 do colors[baseVertex+i]:=src.colors[i];
  end;

  if length(uv0)>0 then begin
   SetLength(uv0,baseVertex+n);
   if length(src.uv0)>0 then
    for i:=0 to n-1 do uv0[baseVertex+i]:=src.uv0[i];
  end;

  if length(uv1)>0 then begin
   SetLength(uv1,baseVertex+n);
   if length(src.uv1)>0 then
    for i:=0 to n-1 do uv1[baseVertex+i]:=src.uv1[i];
  end;

  if length(tangents)>0 then begin
   SetLength(tangents,baseVertex+n);
   if length(src.tangents)>0 then
    for i:=0 to n-1 do begin
     t:=src.tangents[i];
     v:=t.xyz;
     rot.TransformPoints(@v,1,0);
     v.Normalize;
     tangents[baseVertex+i]:=Vec4(v,t.w);
    end;
  end;

  if length(joints)>0 then begin
   SetLength(joints,baseVertex+n);
   if length(src.joints)>0 then
    for i:=0 to n-1 do joints[baseVertex+i]:=src.joints[i];
  end;

  if length(weights)>0 then begin
   SetLength(weights,baseVertex+n);
   if length(src.weights)>0 then
    for i:=0 to n-1 do weights[baseVertex+i]:=src.weights[i];
  end;

  if length(src.indices)>0 then begin
   SetLength(indices,baseIndex+length(src.indices));
   for i:=0 to high(src.indices) do indices[baseIndex+i]:=src.indices[i]+baseVertex;
  end;

  result.name:='';
  result.firstIndex:=baseIndex;
  result.indexCount:=length(src.indices);
  s:=length(sections);
  SetLength(sections,s+1);
  sections[s]:=result;

  boundsDirty:=true;
  fMaxIndexValid:=false;
 end;

procedure TMesh.RecalculateBounds;
 var
  i:integer;
 begin
  bounds.Reset;
  for i:=0 to high(positions) do bounds.Include(positions[i]);
  boundsDirty:=false;
 end;

procedure TMesh.Finish;
 var
  vc,i:integer;
 begin
  ASSERT(openSection<0,'A section is still open');
  vc:=length(positions);
  // every present attribute array must align with the vertex count
  if (length(normals)>0) and (length(normals)<>vc) then
   raise EError.Create('Mesh: normals count mismatch');
  if (length(colors)>0) and (length(colors)<>vc) then
   raise EError.Create('Mesh: colors count mismatch');
  if (length(uv0)>0) and (length(uv0)<>vc) then
   raise EError.Create('Mesh: uv0 count mismatch');
  if (length(uv1)>0) and (length(uv1)<>vc) then
   raise EError.Create('Mesh: uv1 count mismatch');
  if (length(tangents)>0) and (length(tangents)<>vc) then
   raise EError.Create('Mesh: tangents count mismatch');
  if (length(joints)>0) and (length(joints)<>vc) then
   raise EError.Create('Mesh: joints count mismatch');
  if (length(weights)>0) and (length(weights)<>vc) then
   raise EError.Create('Mesh: weights count mismatch');
  // index range validation (only meaningful for an indexed mesh)
  if length(indices)>0 then begin
   if length(indices) mod 3<>0 then
    raise EError.Create('Mesh: index count is not a multiple of 3');
   for i:=0 to high(indices) do
    if (indices[i]<0) or (indices[i]>=vc) then
     raise EError.Create('Mesh: index out of range');
  end else
   if vc mod 3<>0 then
    raise EError.Create('Mesh: non-indexed vertex count is not a multiple of 3');
  // cache MaxIndex and recompute bounds
  fMaxIndexValid:=false;
  MaxIndex;
  RecalculateBounds;
 end;

end.
