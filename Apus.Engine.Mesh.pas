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
  procedure AddCube(center:TPoint3s;size:TVector3s;color:cardinal);
  procedure AddCylinder(p0,p1:Tpoint3s;r0,r1:single;segments,color:cardinal;addCaps:boolean=false);
  procedure Finish; // finalize write and fix current number of written vertices/indices
  procedure Draw(tex:TTexture=nil); // draw whole mesh
  destructor Destroy; override;
  function DumpVertex(n:cardinal):String8;
  function vPos:integer; // Returns number of vertices stored via AddVertex (current write position)
  procedure UseBuffers; // Create vertex index buffers and upload mesh data for faster rendering
 private
  vData:PByte; // vertex data write pointer
  idx:integer; // index write pointer
  // These buffer objects can be used instead of "vertices"/"indices"
  vb:TVertexBuffer;
  ib:TIndexBuffer;
  function AssertVertices(num:integer=1):integer; // returns index of the next available vertex
 end;

implementation
uses Apus.MyServis, Apus.Engine.API, Apus.Geom3D;

{ TMesh }

constructor TMesh.Create(vertexLayout:TVertexLayout;vertCount,indCount:integer);
 begin
  layout:=vertexLayout;
  vCount:=vertCount;
  if vCount>0 then GetMem(vertices,vCount*layout.stride);
  SetLength(indices,indCount);
  vData:=vertices;
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
 var
  cnt:integer;
 begin
  cnt:=(UIntPtr(vData)-UIntPtr(vertices)) div layout.stride;
  if cnt+num>vCount then begin
   vCount:=(cnt+num)+cnt div 4;
   ReallocMem(vertices,vCount*layout.stride);
   if vData=nil then vData:=vertices;
  end;
  result:=cnt;
 end;

function TMesh.AddVertex(pos:TPoint3s;norm:TVector3s;uv:TPoint2s;color:cardinal):integer;
 begin
  result:=AssertVertices;
  layout.SetPos(vData^,pos);
  layout.SetNormal(vData^,norm);
  layout.SetUV(vData^,uv);
  layout.SetColor(vData^,color);
  inc(vData,layout.stride);
 end;

function TMesh.AddVertex(var vertexData):integer;
 begin
  result:=AssertVertices;
  //ASSERT(PointerInRange(vData,vertices,vCount*layout.stride));

  move(vertexData,vData^,layout.stride);
  inc(vData,layout.stride);
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
  vCount:=(UIntPtr(vData)-UIntPtr(vertices)) div layout.stride;
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
  vData:=vertices;
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
  result:=(UIntPtr(vData)-UIntPtr(vertices)) div layout.stride;
 end;

procedure TMesh.AddCube(center:TPoint3s;size:TVector3s;color:cardinal);
 const
  mm:array[0..3,0..1] of single=((-1,-1),(-1,1),(1,-1),(1,1));
 var
  n:TVector3s;
  uv:TPoint2s;
  i:integer;
 begin
  AssertVertices(24);
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
   AddTrg(i,i+6,i+18);
   AddTrg(i,i+18,i+12);
  end;
 end;

procedure TMesh.AddCylinder(p0,p1:Tpoint3s;r0,r1:single;segments,color:cardinal;addCaps:boolean);
 var
  i:integer;
  rX,rY,rZ,r,n:TVector3s;
  a:single;
 begin
  rZ:=Vector3s(p0,p1);
  rZ.Normalize;
  if abs(rZ.z)>abs(rZ.y) then rX:=CrossProduct(rZ,Vector3s(0,1,0))
   else rX:=CrossProduct(rZ,Vector3s(0,0,1));
  rX.Normalize;
  rY:=CrossProduct(rZ,rX);
  for i:=0 to segments-1 do begin
   a:=2*Pi*i/segments;
   r.Init(rx,cos(a),ry,sin(a));
   //AddVertex();
  end;
 end;

end.

