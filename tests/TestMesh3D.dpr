// Headless unit test for the R-19 SoA CPU mesh (stage B2).
// Covers: TBox3 basics, build-API round-trip, indices/triangles, sections,
// MaxIndex caching, bounds, and Finish validation.
{$APPTYPE CONSOLE}
program TestMesh3D;
uses
  SysUtils,
  Apus.Core,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.Engine.Mesh3D;

{$I ..\Base\tests\Test.inc}

// Build a unit quad in the XY plane (4 verts, 2 triangles) with tangents.
function MakeQuad:TMesh;
var
  v0,v1,v2,v3:integer;
  t:TVec4;
begin
  t:=Vec4(1,0,0,1);
  result:=TMesh.Create('quad');
  result.BeginSection('quad');
  v0:=result.AddVertex(Vec3(-1,-1,0),Vec3(0,0,1),t,Vec2(0,0),$FFFFFFFF);
  v1:=result.AddVertex(Vec3( 1,-1,0),Vec3(0,0,1),t,Vec2(1,0),$FFFFFFFF);
  v2:=result.AddVertex(Vec3( 1, 1,0),Vec3(0,0,1),t,Vec2(1,1),$FFFFFFFF);
  v3:=result.AddVertex(Vec3(-1, 1,0),Vec3(0,0,1),t,Vec2(0,1),$FFFFFFFF);
  result.AddTriangle(v0,v1,v2);
  result.AddTriangle(v0,v2,v3);
  result.EndSection;
  result.Finish;
end;

procedure TestBox3;
var
  b:TBox3;
begin
  StartTest('TBox3');
  b.Reset;
  Check(b.IsEmpty,'reset box is empty');
  b.Include(Vec3(-1,-2,-3));
  b.Include(Vec3(3,2,1));
  Check(not b.IsEmpty,'box not empty after include');
  Check((b.min.x=-1) and (b.min.y=-2) and (b.min.z=-3),'min corner');
  Check((b.max.x=3) and (b.max.y=2) and (b.max.z=1),'max corner');
  Check((b.Center.x=1) and (b.Center.y=0) and (b.Center.z=-1),'center');
  Check((b.Size.x=4) and (b.Size.y=4) and (b.Size.z=4),'size');
  EndTest;
end;

procedure TestBuild;
var
  m:TMesh;
begin
  StartTest('mesh build counts');
  m:=MakeQuad;
  Check(m.VertexCount=4,'vertex count');
  Check(m.IndexCount=6,'index count');
  Check(m.TriangleCount=2,'triangle count');
  Check(length(m.tangents)=4,'tangents populated by overload');
  Check(length(m.joints)=0,'absent attribute stays empty');
  Check(m.name='quad','name set');
  m.Free;
  EndTest;
end;

function PositionsRoundTrip(m:TMesh):boolean;
begin
  result:=
    (m.positions[0].x=-1) and (m.positions[0].y=-1) and
    (m.positions[2].x=1) and (m.positions[2].y=1) and
    (m.uv0[1].x=1) and (m.uv0[1].y=0) and
    (m.colors[3]=$FFFFFFFF) and
    (m.normals[0].z=1);
end;

procedure TestRoundTrip;
var
  m:TMesh;
begin
  StartTest('mesh SoA round-trip');
  m:=MakeQuad;
  Check(PositionsRoundTrip(m),'attribute arrays round-trip');
  m.Free;
  EndTest;
end;

procedure TestSections;
var
  m:TMesh;
begin
  StartTest('mesh sections');
  m:=MakeQuad;
  Check(length(m.sections)=1,'one section');
  Check(m.sections[0].name='quad','section name');
  Check(m.sections[0].firstIndex=0,'section firstIndex');
  Check(m.sections[0].indexCount=6,'section indexCount');
  m.Free;
  // two explicit sections over a 4-triangle strip
  m:=TMesh.Create;
  m.AddSection('a',0,3);
  m.AddSection('b',3,3);
  Check(length(m.sections)=2,'two sections');
  Check(m.sections[1].firstIndex=3,'second section offset');
  m.Free;
  EndTest;
end;

procedure TestMaxIndex;
var
  m:TMesh;
begin
  StartTest('mesh MaxIndex');
  m:=MakeQuad;
  Check(m.MaxIndex=3,'max index = 3');
  // adding a triangle invalidates the cache
  m.AddVertex(Vec3(0,0,5),Vec3(0,0,1),Vec2(0,0),$FF000000);
  m.AddTriangle(0,1,4);
  Check(m.MaxIndex=4,'max index recomputed after add');
  m.Free;
  EndTest;
end;

procedure TestBounds;
var
  m:TMesh;
begin
  StartTest('mesh bounds');
  m:=MakeQuad;
  Check(not m.boundsDirty,'bounds clean after Finish');
  Check((m.bounds.Center.x=0) and (m.bounds.Center.y=0),'bounds center');
  Check((m.bounds.Size.x=2) and (m.bounds.Size.y=2) and (m.bounds.Size.z=0),'bounds size');
  m.AddVertex(Vec3(0,0,0),Vec3(0,0,1),Vec2(0,0),$FF000000);
  Check(m.boundsDirty,'add marks bounds dirty');
  m.Free;
  EndTest;
end;

// Build the same quad via the direct index-fill path (SetVertexCount + public arrays).
function DirectFillSizing(m:TMesh):boolean;
begin
  result:=
    (m.VertexCount=4) and
    (length(m.normals)=4) and (length(m.uv0)=4) and (length(m.colors)=4) and
    (length(m.tangents)=0) and (length(m.joints)=0) and (length(m.weights)=0) and
    (length(m.uv1)=0);
end;

procedure TestDirectFill;
var
  m:TMesh;
  i:integer;
begin
  StartTest('mesh direct fill (SetVertexCount)');
  m:=TMesh.Create('grid');
  m.SetVertexCount(4,[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Color]);
  Check(DirectFillSizing(m),'active attrs sized, others cleared');
  // fill by index through the public SoA arrays
  m.positions[0]:=Vec3(-1,-1,0); m.positions[1]:=Vec3(1,-1,0);
  m.positions[2]:=Vec3(1,1,0);   m.positions[3]:=Vec3(-1,1,0);
  for i:=0 to 3 do begin m.normals[i]:=Vec3(0,0,1); m.colors[i]:=$FFFFFFFF; end;
  m.uv0[0]:=Vec2(0,0); m.uv0[1]:=Vec2(1,0); m.uv0[2]:=Vec2(1,1); m.uv0[3]:=Vec2(0,1);
  SetLength(m.indices,6);
  m.indices[0]:=0; m.indices[1]:=1; m.indices[2]:=2;
  m.indices[3]:=0; m.indices[4]:=2; m.indices[5]:=3;
  m.Finish;
  Check((m.IndexCount=6) and (m.MaxIndex=3) and not m.boundsDirty,'finish ok after direct fill');
  Check((m.bounds.Size.x=2) and (m.bounds.Size.y=2) and (m.bounds.Size.z=0),'bounds from direct fill');
  // resizing clears non-requested attributes (color dropped here)
  m.SetVertexCount(2,[TMeshAttribute.Normal]);
  Check((m.VertexCount=2) and (length(m.normals)=2) and (length(m.colors)=0) and (length(m.uv0)=0),
    'resize re-sizes active, clears dropped');
  m.Free;
  EndTest;
end;

function FinishRaises(m:TMesh):boolean;
begin
  result:=false;
  try
    m.Finish;
  except
    on EError do result:=true;
  end;
end;

procedure TestValidation;
var
  m:TMesh;
begin
  StartTest('mesh Finish validation');
  // index out of range
  m:=TMesh.Create;
  m.AddVertex(Vec3(0,0,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddVertex(Vec3(1,0,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddVertex(Vec3(0,1,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddTriangle(0,1,9); // 9 is out of range
  Check(FinishRaises(m),'out-of-range index raises');
  m.Free;
  // non-indexed mesh: vertex count must be a multiple of 3
  m:=TMesh.Create;
  m.AddVertex(Vec3(0,0,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddVertex(Vec3(1,0,0),Vec3(0,0,1),Vec2(0,0),0);
  Check(FinishRaises(m),'non-indexed non-multiple-of-3 raises');
  m.Free;
  // valid non-indexed mesh passes
  m:=TMesh.Create;
  m.AddVertex(Vec3(0,0,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddVertex(Vec3(1,0,0),Vec3(0,0,1),Vec2(0,0),0);
  m.AddVertex(Vec3(0,1,0),Vec3(0,0,1),Vec2(0,0),0);
  Check(not FinishRaises(m),'valid non-indexed mesh passes');
  m.Free;
  EndTest;
end;

begin
  writeln('=== TestMesh3D ===');
  TestBox3;
  TestBuild;
  TestRoundTrip;
  TestSections;
  TestMaxIndex;
  TestBounds;
  TestDirectFill;
  TestValidation;
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
