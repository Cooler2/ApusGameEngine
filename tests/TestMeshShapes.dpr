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

begin
  writeln('=== TestMeshShapes ===');
  TestBox;
  TestAppend;
  TestCylinder;
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
