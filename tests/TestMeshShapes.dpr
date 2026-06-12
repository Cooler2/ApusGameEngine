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

begin
  writeln('=== TestMeshShapes ===');
  TestBox;
  TestAppend;
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
