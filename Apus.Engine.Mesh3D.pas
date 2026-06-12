// CPU triangle mesh — SoA container (R-19, stage B2).
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
// NOTE (transitional): this unit hosts the new mesh during R-19 stages B/C while
// the legacy interleaved Apus.Engine.Mesh is still in use. In stage C, after its
// consumers (loaders/demos) are migrated, this becomes Apus.Engine.Mesh and the
// legacy unit is removed. No permanent alias is intended.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Mesh3D;
interface
uses Apus.Core, Apus.Classes, Apus.Geom2D, Apus.Geom3D;

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
  positions:array of TVec3;
  normals:array of TVec3;
  colors:array of cardinal;     // full-precision color storage
  uv0,uv1:array of TVec2;
  tangents:array of TVec4;      // xyz along +U, w = handedness sign
  joints:array of TJoints4;     // 4 bone indices
  weights:array of TWeights4;   // 4 weights (normalized on upload)
  // topology
  indices:array of integer;     // always 32-bit on CPU; optional
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
  function AddVertex(const p,n:TVec3;const uv:TVec2;color:cardinal):integer; overload;
  function AddVertex(const p,n:TVec3;const tangent:TVec4;
    const uv:TVec2;color:cardinal):integer; overload;
  procedure AddTriangle(v0,v1,v2:integer);
  procedure BeginSection(const aName:String8);
  procedure EndSection;
  procedure AddSection(const aName:String8;firstIndex,indexCount:integer);

  // Validate, compute MaxIndex/bounds, mark bounds clean. Call once after build.
  procedure Finish;
  procedure RecalculateBounds; // also clears boundsDirty

 private
  fMaxIndex:integer;
  fMaxIndexValid:boolean;
  openSection:integer; // index in sections[] of the section being built, or -1
 end;

implementation

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
