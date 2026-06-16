// Headless unit test for the R-19 OBJ -> SoA TMesh geometry loader.
// Covers: vertex dedup, fan triangulation, sections per usemtl, attribute
// presence (normals/uv), and the engine OBJ coordinate convention.
{$APPTYPE CONSOLE}
program TestObjMesh;
uses
  SysUtils,
  Apus.Core,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.Engine.Mesh3D,
  Apus.Engine.OBJMesh;

{$I ..\Base\tests\Test.inc}

const
  // a unit quad: 4 verts, 4 uv, 1 normal, two materials (one triangle each).
  // shared corners (1/1/1 and 3/3/1) must dedup to a single vertex each.
  QUAD_OBJ=
    '# test quad'#10+
    'v -1 -1 0'#10+
    'v 1 -1 0'#10+
    'v 1 1 0'#10+
    'v -1 1 0'#10+
    'vt 0 0'#10+
    'vt 1 0'#10+
    'vt 1 1'#10+
    'vt 0 1'#10+
    'vn 0 0 1'#10+
    'usemtl red'#10+
    'f 1/1/1 2/2/1 3/3/1'#10+
    'usemtl blue'#10+
    'f 1/1/1 3/3/1 4/4/1'#10;
  // positions only, single triangle, no materials -> normals/uv absent, one '' section
  TRI_OBJ=
    'v 0 0 0'#10+
    'v 2 0 0'#10+
    'v 0 2 0'#10+
    'f 1 2 3'#10;

function QuadCounts(m:TMesh):boolean;
begin
  result:=
    (m.VertexCount=4) and        // 6 corners, 2 shared -> 4 unique
    (m.IndexCount=6) and
    (length(m.normals)=4) and (length(m.uv0)=4) and
    (length(m.sections)=2);
end;

function QuadSections(m:TMesh):boolean;
begin
  result:=
    (m.sections[0].name='red')  and (m.sections[0].firstIndex=0) and (m.sections[0].indexCount=3) and
    (m.sections[1].name='blue') and (m.sections[1].firstIndex=3) and (m.sections[1].indexCount=3);
end;

function QuadConvention(m:TMesh):boolean;
begin
  // v1 "-1 -1 0" -> (-X,-Z,Y) = (1,0,-1); vt1 "0 0" -> (0,1-0)=(0,1); vn "0 0 1" -> (0,-1,0)
  result:=
    (m.positions[0].x=1) and (m.positions[0].y=0) and (m.positions[0].z=-1) and
    (m.uv0[0].x=0) and (m.uv0[0].y=1) and
    (m.normals[0].x=0) and (m.normals[0].y=-1) and (m.normals[0].z=0);
end;

function QuadWinding(m:TMesh):boolean;
var
  a,b,c,n:TVec3;
begin
  // (-X,-Z,Y) flips handedness, so the loader must reverse face winding.
  result:=(m.indices[0]=0) and (m.indices[1]=2) and (m.indices[2]=1);
  if not result then exit;
  a:=m.positions[m.indices[0]];
  b:=m.positions[m.indices[1]];
  c:=m.positions[m.indices[2]];
  n:=(b-a).Cross(c-a);
  result:=n.Dot(m.normals[m.indices[0]])>0;
end;

procedure TestQuad;
var
  m:TMesh;
begin
  StartTest('OBJ quad (dedup, sections, convention)');
  m:=ParseMeshOBJ(QUAD_OBJ,'quad');
  Check(QuadCounts(m),'counts: 4 verts / 6 idx / 2 sections, attrs present');
  Check(QuadSections(m),'sections per usemtl with correct ranges');
  Check(QuadConvention(m),'coordinate/uv/normal convention');
  Check(QuadWinding(m),'winding matches remapped normals');
  m.Free;
  EndTest;
end;

procedure TestPositionsOnly;
var
  m:TMesh;
begin
  StartTest('OBJ positions-only triangle');
  m:=ParseMeshOBJ(TRI_OBJ);
  Check((m.VertexCount=3) and (m.IndexCount=3),'3 verts, 3 indices');
  Check((length(m.normals)=0) and (length(m.uv0)=0),'normals/uv absent when file has none');
  Check((length(m.sections)=1) and (m.sections[0].name=''),'single unnamed section');
  m.Free;
  EndTest;
end;

begin
  writeln('=== TestObjMesh ===');
  TestQuad;
  TestPositionsOnly;
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
