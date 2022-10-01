// Basic Mesh object: static single part (material) triangle-list mesh.
//
// Copyright (C) 2022 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Mesh;
interface
uses Apus.Types, Apus.VertexLayout, Apus.Engine.Types, Apus.Engine.Resources;

type
 // Simple mesh
 TMesh=class
  layout:TVertexLayout;
  vertices:pointer;
  indices:WordArray; // optional, can be empty
  vCount:integer; // number of vertices allocated
  constructor Create(vertexLayout:TVertexLayout;vertCount,indCount:integer);
  procedure SetVertices(data:pointer;sizeInBytes:integer);
  function AddVertex(var vertexData):integer; overload;
  function AddVertex(pos:TPoint3s;norm:TVector3s;uv:TPoint2s;color:cardinal):integer; overload;
  procedure AddTrg(v0,v1,v2:integer);
  procedure AddTriangle(p1,p2,p3:TPoint3s;color:cardinal=$FF808080);
  procedure AddMesh(mesh:TMesh);
  procedure AddCube(center:TPoint3s;size:TVector3s;color:cardinal=$FF808080);
  procedure AddCylinder(p0,p1:Tpoint3s;r0,r1:single;segments:integer;color:cardinal=$FF808080;addCaps:boolean=false);
  procedure Finish; // finalize write and fix current number of written vertices/indices
  procedure Draw(tex:TTexture=nil); // draw whole mesh
  destructor Destroy; override;
  function DumpVertex(n:cardinal):String8;
  function vPos:integer;
  procedure UseBuffers; // Create vertex index buffers and upload mesh data for faster rendering
 private
  vIdx:integer; // vertex to write
  idx:integer; // index write pointer
  // These buffer objects can be used instead of "vertices"/"indices"
  vb:TVertexBuffer;
  ib:TIndexBuffer;
  function AssertVertices(num:integer=1):integer; // returns index of the next available vertex
 end;

implementation
uses Apus.Common, Apus.Engine.API, Apus.Geom3D;

{ TMesh }

constructor TMesh.Create(vertexLayout:TVertexLayout;vertCount,indCount:integer);
 begin
  layout:=vertexLayout;
  vCount:=vertCount;
  if vCount>0 then GetMem(vertices,vCount*layout.stride);
  SetLength(indices,indCount);
  vIdx:=0;
  idx:=0;
 end;

destructor TMesh.Destroy;
 begin
  FreeMem(vertices);
  inherited;
 end;

procedure TMesh.AddTrg(v0,v1,v2:integer);
 begin
  if idx+3>length(indices) then SetLength(indices,idx+3);
  indices[idx]:=v0; inc(idx);
  indices[idx]:=v1; inc(idx);
  indices[idx]:=v2; inc(idx);
 end;

function TMesh.AssertVertices(num:integer):integer;
 begin
  result:=vIdx;
  if vIdx+num>vCount then begin
   vCount:=(vIdx+num)+16+vIdx div 4;
   ReallocMem(vertices,vCount*layout.stride);
  end;
 end;

function TMesh.AddVertex(pos:TPoint3s;norm:TVector3s;uv:TPoint2s;color:cardinal):integer;
 var
  vData:PByte;
 begin
  vData:=vertices; inc(vData,vIdx*layout.stride);
  result:=AssertVertices;
  layout.SetPos(vData^,pos);
  layout.SetNormal(vData^,norm);
  layout.SetUV(vData^,uv);
  layout.SetColor(vData^,color);
  inc(vIdx);
 end;

function TMesh.AddVertex(var vertexData):integer;
 var
  vData:PByte;
 begin
  result:=AssertVertices;
  vData:=vertices; inc(vData,vIdx*layout.stride);
  move(vertexData,vData^,layout.stride);
  inc(vIdx);
 end;

function TMesh.DumpVertex(n:cardinal):String8;
 var
  pb:PByte;
 begin
  ASSERT(n<vCount);
  pb:=vertices;
  inc(pb,n*layout.stride);
  result:=layout.DumpVertex(pb^);
 end;

procedure TMesh.Finish;
 begin
  vCount:=vIdx;
  ReallocMem(vertices,vCount*layout.stride);
  SetLength(indices,idx);
 end;

procedure TMesh.Draw(tex:TTexture=nil); // draw whole mesh
 begin
  if (vb<>nil) then begin // buffers are used
   Apus.Engine.API.draw.IndexedMesh(vb,ib,tex);
   exit;
  end;
  if length(indices)>0 then
   Apus.Engine.API.draw.IndexedMesh(vertices,layout,@indices[0],
     length(indices) div 3,vCount,tex)
  else
   Apus.Engine.API.draw.TrgList(vertices,layout,vCount div 3,tex)
 end;

procedure TMesh.SetVertices(data:pointer;sizeInBytes:integer);
 begin
  FreeMem(vertices);
  vertices:=data;
  vCount:=sizeInBytes div layout.stride;
  vIdx:=0;
 end;

procedure TMesh.UseBuffers;
 begin
  ASSERT((vb=nil) and (ib=nil),'Already buffered');
  vb:=gfx.resMan.AllocVertexBuffer(layout,vCount);
  vb.Upload(0,vCount,vertices);
  FreeMem(vertices);
  ib:=gfx.resMan.AllocIndexBuffer(length(indices));
  ib.Upload(0,length(indices),@indices[0]);
  SetLength(indices,0);
 end;

function TMesh.vPos:integer;
 begin
  result:=vIdx;
 end;

procedure TMesh.AddTriangle(p1,p2,p3:TPoint3s;color:cardinal);
 var
  norm:TVector3s;
  uv:TPoint2s;
  base:integer;
 begin
  base:=AssertVertices(3);
  norm:=CrossProduct(Vector3s(p1,p2),Vector3s(p1,p3));
  uv.Init(0,0);
  AddVertex(p1,norm,uv,color);
  AddVertex(p2,norm,uv,color);
  AddVertex(p3,norm,uv,color);
  AddTrg(base,base+1,base+2);
 end;

procedure TMesh.AddMesh(mesh:TMesh);
 var
  i,base,ii:integer;
  src:PByte;
  sameLayout:boolean;
 begin
  base:=AssertVertices(mesh.vCount);
  // Add vertices
  sameLayout:=layout.Equals(mesh.layout);
  src:=mesh.vertices;
  for i:=0 to mesh.vCount-1 do begin
   if sameLayout then
    AddVertex(src^)
   else
    AddVertex(mesh.layout.GetPos(src^),
              mesh.layout.GetNormal(src^),
              mesh.layout.GetUV(src^),
              mesh.layout.GetColor(src^));
   inc(src,mesh.layout.stride);
  end;
  // Add triangles
  if idx+length(mesh.indices)>length(indices) then
   SetLength(indices,idx+length(mesh.indices));
  for i:=0 to length(mesh.indices) div 3 do begin
   ii:=i*3;
   AddTrg(base+mesh.indices[ii],
          base+mesh.indices[ii+1],
          base+mesh.indices[ii+2]);
  end;
 end;

procedure TMesh.AddCube(center:TPoint3s;size:TVector3s;color:cardinal);
 const
  mm:array[0..3,0..1] of single=((-1,-1),(-1,1),(1,-1),(1,1));
 var
  n:TVector3s;
  uv:TPoint2s;
  i,base:integer;
 begin
  base:=AssertVertices(24);
  size.Multiply(0.5);
  uv.Init(0,0);
  for i:=0 to 3 do begin
   AddVertex(Point3s(center.x+size.x,center.y+size.y*mm[i,0],center.z+size.z*mm[i,1]),Vector3s(1,0,0),uv,color);
   AddVertex(Point3s(center.x-size.x,center.y-size.y*mm[i,0],center.z-size.z*mm[i,1]),Vector3s(-1,0,0),uv,color);
   AddVertex(Point3s(center.x+size.x*mm[i,0],center.y+size.y,center.z+size.z*mm[i,1]),Vector3s(0,1,0),uv,color);
   AddVertex(Point3s(center.x-size.x*mm[i,0],center.y-size.y,center.z-size.z*mm[i,1]),Vector3s(0,-1,0),uv,color);
   AddVertex(Point3s(center.x+size.x*mm[i,0],center.y+size.y*mm[i,1],center.z+size.z),Vector3s(0,0,1),uv,color);
   AddVertex(Point3s(center.x-size.x*mm[i,0],center.y-size.y*mm[i,1],center.z-size.z),Vector3s(0,0,-1),uv,color);
  end;
  for i:=0 to 5 do begin
   AddTrg(base+i,base+i+6,base+i+18);
   AddTrg(base+i,base+i+18,base+i+12);
  end;
 end;

procedure TMesh.AddCylinder(p0,p1:Tpoint3s;r0,r1:single;segments:integer;color:cardinal;addCaps:boolean);
 var
  i,base,vNum:integer;
  rX,rY,rZ,r,norm:TVector3s;
  v0,v1:TPoint3s;
  a:single;
  uv:TPoint2s;
 begin
  base:=AssertVertices(segments*2);
  rZ:=Vector3s(p0,p1);
  rZ.Normalize;
  if abs(rZ.z)>abs(rZ.y) then rX:=CrossProduct(rZ,Vector3s(0,1,0))
   else rX:=CrossProduct(rZ,Vector3s(0,0,1));
  rX.Normalize;
  rY:=CrossProduct(rZ,rX);
  uv.Init(0,0);
  // Create vertices
  for i:=0 to segments-1 do begin
   a:=2*Pi*i/segments;
   r.Init(rx,cos(a),ry,sin(a));
   v0:=PointAdd(p0,r,r0);
   v1:=PointAdd(p1,r,r1);
   norm:=CrossProduct(Vector3s(p0,p1),r);
   norm:=CrossProduct(norm,Vector3s(v0,v1));
   norm.Normalize;
   AddVertex(v0,norm,uv,color);
   AddVertex(v1,norm,uv,color);
  end;
  // Add surface
  vNum:=segments*2;
  for i:=0 to segments-1 do begin
   AddTrg(base+i*2,base+i*2+1,base+(i*2+3) mod vNum);
   AddTrg(base+i*2,base+(i*2+3) mod vNum,base+(i*2+2) mod vNum);
  end;
 end;

end.

