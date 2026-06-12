// Headless unit test for procedural mesh shape generators (R-20).
// Covers: TMesh.Append (merge under transform) and MeshShapes.Box.
{$APPTYPE CONSOLE}
program TestMeshShapes;
uses
  SysUtils,
  Apus.Core,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.Engine.Mesh3D,
  Apus.Engine.MeshShapes;

{$I ..\Base\tests\Test.inc}

function AllNormalsUnitAxisAligned(m:TMesh):boolean;
 var
  i:integer;
  n:TVec3;
  axisCount:integer;
 begin
  result:=true;
  for i:=0 to high(m.normals) do begin
   n:=m.normals[i];
   if abs(n.Length-1)>0.001 then exit(false);
   axisCount:=0;
   if abs(abs(n.x)-1)<0.001 then inc(axisCount);
   if abs(abs(n.y)-1)<0.001 then inc(axisCount);
   if abs(abs(n.z)-1)<0.001 then inc(axisCount);
   if axisCount<>1 then exit(false);
  end;
 end;

function AllUVInRange(m:TMesh):boolean;
 var
  i:integer;
 begin
  result:=true;
  for i:=0 to high(m.uv0) do
   if (m.uv0[i].x<0) or (m.uv0[i].x>1) or (m.uv0[i].y<0) or (m.uv0[i].y>1) then exit(false);
 end;

procedure TestBox;
 var
  m:TMesh;
 begin
  StartTest('MeshShapes.Box');
  m:=MeshShapes.Box(Vec3(2,4,6));
  Check(m.VertexCount=24,'24 vertices');
  Check(m.IndexCount=36,'36 indices');
  Check(m.TriangleCount=12,'12 triangles');
  Check(length(m.normals)=24,'normals present');
  Check(length(m.uv0)=24,'uv0 present');
  Check(length(m.tangents)=24,'tangents present');
  Check(AllNormalsUnitAxisAligned(m),'all normals unit & axis-aligned');
  Check(AllUVInRange(m),'all uv in [0,1]');
  Check((m.bounds.Size.x=2) and (m.bounds.Size.y=4) and (m.bounds.Size.z=6),'bounds = size');
  m.Free;
  // scalar overload
  m:=MeshShapes.Box(2);
  Check((m.bounds.Size.x=2) and (m.bounds.Size.y=2) and (m.bounds.Size.z=2),'scalar Box = cube');
  m.Free;
  EndTest;
 end;

procedure TestAppend;
 var
  a,b:TMesh;
  sec:TMeshSection;
 begin
  StartTest('TMesh.Append');
  a:=MeshShapes.Box(2); // half-extent 1, x in [-1,1]
  b:=MeshShapes.Box(1); // half-extent 0.5
  sec:=a.Append(b,TMat4.Translation(10,0,0));
  Check(a.VertexCount=48,'vertex counts add up');
  Check(a.IndexCount=72,'index counts add up');
  Check(length(a.sections)=1,'one section added');
  Check((sec.firstIndex=36) and (sec.indexCount=36),'section covers appended range');
  a.RecalculateBounds;
  Check((a.bounds.min.x=-1) and (a.bounds.max.x=10.5),'translated box extends bounds');
  b.Free;
  a.Free;
  EndTest;
 end;

// All side vertices (indices 0..2*(segments+1)-1) sit on the expected radius:
// even index = bottom ring (r1), odd index = top ring (r2).
function SideVertsAtRadius(m:TMesh;segments:integer;r1,r2:single):boolean;
 var
  i:integer;
  p:TVec3;
  rad:single;
 begin
  result:=true;
  for i:=0 to 2*(segments+1)-1 do begin
   p:=m.positions[i];
   rad:=sqrt(p.x*p.x+p.z*p.z);
   if i mod 2=0 then begin
    if abs(rad-r1)>0.001 then exit(false);
   end else
    if abs(rad-r2)>0.001 then exit(false);
  end;
 end;

// Top-ring side vertices collapse to the apex (0,height/2,0) when r2=0.
function ConeApexCollapsed(m:TMesh;segments:integer;halfH:single):boolean;
 var
  i:integer;
  p:TVec3;
 begin
  result:=true;
  for i:=0 to segments do begin
   p:=m.positions[2*i+1];
   if (abs(p.x)>0.001) or (abs(p.y-halfH)>0.001) or (abs(p.z)>0.001) then exit(false);
  end;
 end;

procedure TestCylinder;
 var
  m:TMesh;
  segments:integer;
 begin
  StartTest('MeshShapes.Cylinder');
  segments:=8;
  // plain cylinder with caps
  m:=MeshShapes.Cylinder(1,1,2,segments,true);
  Check(m.VertexCount=4*(segments+1),'cylinder vertex count');
  Check(m.IndexCount=12*segments,'cylinder index count');
  Check(SideVertsAtRadius(m,segments,1,1),'cylinder side verts at radius 1');
  m.Free;
  // cone (r2=0): same counts, top ring collapses to apex
  m:=MeshShapes.Cylinder(1,0,2,segments,true);
  Check(m.VertexCount=4*(segments+1),'cone vertex count');
  Check(SideVertsAtRadius(m,segments,1,0),'cone side verts at radii 1/0');
  Check(ConeApexCollapsed(m,segments,1),'cone apex ring collapsed to apex point');
  m.Free;
  // open tube (no caps): fewer verts/indices
  m:=MeshShapes.Cylinder(1,1,2,segments,false);
  Check(m.VertexCount=2*(segments+1),'tube vertex count (no caps)');
  Check(m.IndexCount=6*segments,'tube index count (no caps)');
  m.Free;
  EndTest;
 end;

function AllNormalsEqual(m:TMesh;const expected:TVec3;eps:single=0.001):boolean;
 var
  i:integer;
  d:TVec3;
 begin
  result:=true;
  for i:=0 to high(m.normals) do begin
   d:=m.normals[i]-expected;
   if (abs(d.x)>eps) or (abs(d.y)>eps) or (abs(d.z)>eps) then exit(false);
  end;
 end;

function AllTangentsEqual(m:TMesh;const expected:TVec4;eps:single=0.001):boolean;
 var
  i:integer;
  t:TVec4;
 begin
  result:=true;
  for i:=0 to high(m.tangents) do begin
   t:=m.tangents[i];
   if (abs(t.x-expected.x)>eps) or (abs(t.y-expected.y)>eps) or
      (abs(t.z-expected.z)>eps) or (abs(t.w-expected.w)>eps) then exit(false);
  end;
 end;

// z = x -> constant slope, gradient-derived normal = (-1,0,1)/sqrt(2) everywhere
function TiltHeightFn(x,y:single):single;
 begin
  result:=x;
 end;

procedure TestPlane;
 var
  m:TMesh;
 begin
  StartTest('MeshShapes.Plane');
  // flat plane
  m:=MeshShapes.Plane(2,2,2,2);
  Check(m.VertexCount=9,'flat plane vertex count');
  Check(m.IndexCount=24,'flat plane index count');
  Check(m.TriangleCount=8,'flat plane triangle count');
  Check(AllNormalsEqual(m,Vec3(0,0,1)),'flat plane normals = +Z');
  Check(AllTangentsEqual(m,Vec4(1,0,0,1)),'flat plane tangents along +X, w=1');
  m.Free;
  // deformed plane: constant-slope heightFn -> constant tilted normal everywhere
  m:=MeshShapes.Plane(2,2,1,1,@TiltHeightFn);
  Check(m.VertexCount=4,'deformed plane (1x1) vertex count');
  Check(m.IndexCount=6,'deformed plane (1x1) index count');
  Check(AllNormalsEqual(m,Vec3(-0.7071068,0,0.7071068),0.001),'deformed plane normals follow heightFn slope');
  m.Free;
  EndTest;
 end;

function AllVertsAtRadius(m:TMesh;r:single;eps:single=0.001):boolean;
 var
  i:integer;
 begin
  result:=true;
  for i:=0 to high(m.positions) do
   if abs(m.positions[i].Length-r)>eps then exit(false);
 end;

procedure TestOctasphere;
 var
  m:TMesh;
 begin
  StartTest('MeshShapes.Octasphere');
  // level 0 = octahedron: 8 tris, 6 verts (Euler: V=4^(level+1)+2)
  m:=MeshShapes.Octasphere(0);
  Check(m.TriangleCount=8,'level 0 triangle count = 8');
  Check(m.VertexCount=6,'level 0 vertex count = 6');
  Check(length(m.normals)=6,'normals present, no uv/tangent');
  Check(length(m.uv0)=0,'no uv0');
  Check(length(m.tangents)=0,'no tangents');
  Check(AllVertsAtRadius(m,1),'level 0 verts at radius 1');
  m.Free;
  // level 1: each of 8 base tris -> 4 sub-tris; shared edges dedup verts
  m:=MeshShapes.Octasphere(1);
  Check(m.TriangleCount=32,'level 1 triangle count = 8*4');
  Check(m.VertexCount=18,'level 1 vertex count = 4^2+2');
  Check(AllVertsAtRadius(m,1),'level 1 verts at radius 1');
  m.Free;
  // radius scaling
  m:=MeshShapes.Octasphere(0,TSpherePortion.Full,2);
  Check(AllVertsAtRadius(m,2),'radius=2 scales all verts');
  m.Free;
  // partial: hemisphere = 4 of 8 octants
  m:=MeshShapes.Octasphere(0,TSpherePortion.Hemisphere);
  Check(m.TriangleCount=4,'hemisphere = 4 octants');
  m.Free;
  // partial: quarter = 2 of 8 octants
  m:=MeshShapes.Octasphere(0,TSpherePortion.Quarter);
  Check(m.TriangleCount=2,'quarter = 2 octants');
  m.Free;
  // partial: eighth = 1 of 8 octants, open boundary (no extra cap verts)
  m:=MeshShapes.Octasphere(0,TSpherePortion.Eighth);
  Check(m.TriangleCount=1,'eighth = 1 octant');
  Check(m.VertexCount=3,'eighth has only its own 3 verts (no cap)');
  m.Free;
  EndTest;
 end;

begin
  writeln('=== TestMeshShapes ===');
  TestBox;
  TestAppend;
  TestCylinder;
  TestPlane;
  TestOctasphere;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
