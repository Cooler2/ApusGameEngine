{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestMeshOps;

uses
  SysUtils,
  Math,
  Apus.Core,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.Engine.Mesh;

{$I ..\Base\tests\Test.inc}

// ============================================================================
// Helper functions — aggregate checks (policy: 1 assertion = 1 Check call,
// never Check inside a loop)
// ============================================================================

// Returns true if every tangent component is a finite number (no NaN, no Inf).
function AllTangentsFinite(mesh:TMesh):boolean;
var
  i:integer;
  t:TVec4;
begin
  result:=true;
  for i:=0 to high(mesh.tangents) do begin
    t:=mesh.tangents[i];
    if IsNaN(t.x) or IsNaN(t.y) or IsNaN(t.z) or IsNaN(t.w) then begin result:=false; exit; end;
    if IsInfinite(t.x) or IsInfinite(t.y) or IsInfinite(t.z) or IsInfinite(t.w) then begin result:=false; exit; end;
  end;
end;

// Returns true if every tangent.xyz is approximately unit-length.
function AllTangentsUnit(mesh:TMesh;eps:single):boolean;
var
  i:integer;
  len:single;
begin
  result:=true;
  for i:=0 to high(mesh.tangents) do begin
    len:=mesh.tangents[i].xyz.Length;
    if abs(len-1.0)>eps then begin result:=false; exit; end;
  end;
end;

// Returns true if every tangent.xyz is perpendicular to its normal (|dot|<eps).
function AllTangentsOrthoToNormal(mesh:TMesh;eps:single):boolean;
var
  i:integer;
  d:single;
begin
  result:=true;
  for i:=0 to high(mesh.tangents) do begin
    d:=mesh.tangents[i].xyz.Dot(mesh.normals[i]);
    if abs(d)>eps then begin result:=false; exit; end;
  end;
end;

// Returns true if every tangent.w is exactly +1 or -1.
function AllHandednessPlusMinusOne(mesh:TMesh):boolean;
var
  i:integer;
  w:single;
begin
  result:=true;
  for i:=0 to high(mesh.tangents) do begin
    w:=mesh.tangents[i].w;
    if (abs(w-1.0)>1e-5) and (abs(w+1.0)>1e-5) then begin result:=false; exit; end;
  end;
end;

// For each vertex, reconstruct B = cross(T,N)*w and compute the UV +V world
// gradient from the triangle that references this vertex, then check dot(B, Vdir)>0.
// Uses only the first triangle that references each vertex for the gradient.
// Returns true if all tested vertices have correct handedness.
function HandednessMatchesUVGradient(mesh:TMesh):boolean;
var
  i,i0,i1,i2,vi:integer;
  dp1,dp2,t,b,n:TVec3;
  du1y,du2y,du1x,du2x,det,r:single;
  tested:array of boolean;
begin
  result:=true;
  SetLength(tested, mesh.VertexCount);
  FillChar(tested[0], mesh.VertexCount, 0);
  i:=0;
  while i+2<=high(mesh.indices) do begin
    i0:=mesh.indices[i]; i1:=mesh.indices[i+1]; i2:=mesh.indices[i+2];
    // compute world-space +V gradient direction from this triangle
    dp1:=mesh.positions[i1]-mesh.positions[i0];
    dp2:=mesh.positions[i2]-mesh.positions[i0];
    du1x:=mesh.uv0[i1].x-mesh.uv0[i0].x; du1y:=mesh.uv0[i1].y-mesh.uv0[i0].y;
    du2x:=mesh.uv0[i2].x-mesh.uv0[i0].x; du2y:=mesh.uv0[i2].y-mesh.uv0[i0].y;
    det:=du1x*du2y-du1y*du2x;
    if abs(det)<1e-6 then begin inc(i,3); continue; end; // skip degenerate UV
    r:=1.0/det;
    // bitangent world direction (towards +V): b = (dp2*du1x - dp1*du2x)*r
    b.x:=(dp2.x*du1x-dp1.x*du2x)*r;
    b.y:=(dp2.y*du1x-dp1.y*du2x)*r;
    b.z:=(dp2.z*du1x-dp1.z*du2x)*r;
    // check each vertex of this triangle (first occurrence)
    for vi:=i to i+2 do begin
      if not tested[mesh.indices[vi]] then begin
        tested[mesh.indices[vi]]:=true;
        t:=mesh.tangents[mesh.indices[vi]].xyz;
        n:=mesh.normals[mesh.indices[vi]];
        // reconstructed bitangent: cross(T,N)*w
        // Note: cross(T,N) = -(cross(N,T)), shader: B = cross(T,N)*w
        // cross(T,N).x = t.y*n.z - t.z*n.y, etc.
        b.x:=(t.y*n.z-t.z*n.y)*mesh.tangents[mesh.indices[vi]].w;
        b.y:=(t.z*n.x-t.x*n.z)*mesh.tangents[mesh.indices[vi]].w;
        b.z:=(t.x*n.y-t.y*n.x)*mesh.tangents[mesh.indices[vi]].w;
        // recompute Vdir for this triangle
        dp1:=mesh.positions[i1]-mesh.positions[i0];
        dp2:=mesh.positions[i2]-mesh.positions[i0];
        du1x:=mesh.uv0[i1].x-mesh.uv0[i0].x; du1y:=mesh.uv0[i1].y-mesh.uv0[i0].y;
        du2x:=mesh.uv0[i2].x-mesh.uv0[i0].x; du2y:=mesh.uv0[i2].y-mesh.uv0[i0].y;
        det:=du1x*du2y-du1y*du2x;
        if abs(det)<1e-6 then continue;
        r:=1.0/det;
        // b_world = (dp2*du1x - dp1*du2x)*r  (world-space +V gradient)
        // We reuse local b variable name here, so rename the check differently:
        // check dot(reconstructed_bitangent, vdir)>0
        if b.x*((dp2.x*du1x-dp1.x*du2x)*r)
          +b.y*((dp2.y*du1x-dp1.y*du2x)*r)
          +b.z*((dp2.z*du1x-dp1.z*du2x)*r) <= 0 then begin
          result:=false; exit;
        end;
      end;
    end;
    inc(i,3);
  end;
end;

// Returns true if vertex idx has a unit tangent and it is perpendicular to its normal.
function SingleVertexTangentOK(mesh:TMesh;idx:integer;eps:single):boolean;
var
  t:TVec3;
  d:single;
begin
  t:=mesh.tangents[idx].xyz;
  if abs(t.Length-1.0)>eps then begin result:=false; exit; end;
  d:=t.Dot(mesh.normals[idx]);
  result:=abs(d)<=eps;
end;

// Returns true if both signs of w appear somewhere across combined meshes.
function BothHandednessSignsPresent(m1,m2:TMesh):boolean;
var
  i:integer;
  hasPos,hasNeg:boolean;
begin
  hasPos:=false; hasNeg:=false;
  for i:=0 to high(m1.tangents) do begin
    if m1.tangents[i].w>0 then hasPos:=true
    else hasNeg:=true;
  end;
  for i:=0 to high(m2.tangents) do begin
    if m2.tangents[i].w>0 then hasPos:=true
    else hasNeg:=true;
  end;
  result:=hasPos and hasNeg;
end;

// ============================================================================
// Mesh builders
// ============================================================================

// Planar quad in XY plane, z=0.
// Vertices: (0,0,0),(1,0,0),(1,1,0),(0,1,0)
// UV:       (0,0),  (1,0),  (1,1),  (0,1)
// Two CCW triangles (viewed from +Z): 0-1-2, 0-2-3
function BuildPlanarQuad:TMesh;
begin
  result:=TMesh.Create('quad');
  result.SetVertexCount(4,[TMeshAttribute.UV0]);
  result.positions[0]:=Vec3(0,0,0); result.uv0[0]:=Vec2(0,0);
  result.positions[1]:=Vec3(1,0,0); result.uv0[1]:=Vec2(1,0);
  result.positions[2]:=Vec3(1,1,0); result.uv0[2]:=Vec2(1,1);
  result.positions[3]:=Vec3(0,1,0); result.uv0[3]:=Vec2(0,1);
  result.AddTriangle(0,1,2);
  result.AddTriangle(0,2,3);
end;

// Mesh with a degenerate-UV triangle AND a normal triangle sharing vertices 0,1,2.
// Vertex 0,1,2: normal triangle (good UVs, uv0 forms a non-degenerate patch).
// Vertex 3: ONLY belongs to the degenerate triangle (all three verts have same UV).
// Vertex 4: second vertex of degenerate triangle (same UV as 3).
// Degenerate tri: 3-4-2 with all having UV=(0.5,0.5).
// To ensure vertex 3 is "fallback-only" it must have unique UV that is collinear
// with the other degenerate UVs.
function BuildDegenerateUVMesh:TMesh;
begin
  result:=TMesh.Create('degen');
  result.SetVertexCount(5,[TMeshAttribute.UV0]);
  // non-degenerate triangle 0-1-2
  result.positions[0]:=Vec3(0,0,0); result.uv0[0]:=Vec2(0,0);
  result.positions[1]:=Vec3(2,0,0); result.uv0[1]:=Vec2(1,0);
  result.positions[2]:=Vec3(1,2,0); result.uv0[2]:=Vec2(0.5,1);
  // vertex 3 and 4 only used in degenerate triangle — identical UVs (det=0)
  result.positions[3]:=Vec3(3,0,0); result.uv0[3]:=Vec2(0.5,0.5);
  result.positions[4]:=Vec3(4,0,0); result.uv0[4]:=Vec2(0.5,0.5);
  // good triangle
  result.AddTriangle(0,1,2);
  // degenerate UV triangle: det=0 because all 3 UV identical => skipped by op
  result.AddTriangle(3,4,2);
end;

// Mirrored-UV quad: same geometry as planar quad, but UV is mirrored in U
// (u goes 1->0 instead of 0->1), which flips handedness.
function BuildMirroredQuad:TMesh;
begin
  result:=TMesh.Create('mirrored');
  result.SetVertexCount(4,[TMeshAttribute.UV0]);
  result.positions[0]:=Vec3(0,0,0); result.uv0[0]:=Vec2(1,0); // mirrored
  result.positions[1]:=Vec3(1,0,0); result.uv0[1]:=Vec2(0,0); // mirrored
  result.positions[2]:=Vec3(1,1,0); result.uv0[2]:=Vec2(0,1); // mirrored
  result.positions[3]:=Vec3(0,1,0); result.uv0[3]:=Vec2(1,1); // mirrored
  result.AddTriangle(0,1,2);
  result.AddTriangle(0,2,3);
end;

// ============================================================================
// Test cases
// ============================================================================

procedure TestPlanarQuad;
var
  mesh:TMesh;
begin
  StartTest('MeshOps: planar quad tangents');
  mesh:=BuildPlanarQuad;
  try
    MeshOps.ComputeNormals(mesh);
    MeshOps.ComputeTangents(mesh);
    Check(AllTangentsFinite(mesh),'all tangents finite');
    Check(AllTangentsUnit(mesh,1e-4),'all |tangent.xyz|=1');
    Check(AllTangentsOrthoToNormal(mesh,1e-4),'all tangent.xyz perp normal');
    Check(AllHandednessPlusMinusOne(mesh),'all w = +/-1');
    Check(HandednessMatchesUVGradient(mesh),'reconstructed B aligns with +V gradient');
  finally
    mesh.Free;
  end;
  EndTest;
end;

procedure TestDegenerateUV;
var
  mesh:TMesh;
  fallbackOK:boolean;
begin
  StartTest('MeshOps: degenerate UV (no NaN)');
  mesh:=BuildDegenerateUVMesh;
  try
    MeshOps.ComputeNormals(mesh);
    MeshOps.ComputeTangents(mesh);
    Check(AllTangentsFinite(mesh),'no NaN/Inf in tangents');
    // vertices 3 and 4 only appear in the degenerate triangle — fallback branch
    fallbackOK:=SingleVertexTangentOK(mesh,3,1e-4) and SingleVertexTangentOK(mesh,4,1e-4);
    Check(fallbackOK,'fallback-only vertices have unit tangent perp normal');
  finally
    mesh.Free;
  end;
  EndTest;
end;

procedure TestMirroredHandedness;
var
  quad:TMesh;
  mirrored:TMesh;
begin
  StartTest('MeshOps: mirrored UV gives opposite handedness');
  quad:=BuildPlanarQuad;
  mirrored:=BuildMirroredQuad;
  try
    MeshOps.ComputeNormals(quad);
    MeshOps.ComputeTangents(quad);
    MeshOps.ComputeNormals(mirrored);
    MeshOps.ComputeTangents(mirrored);
    Check(AllTangentsFinite(mirrored),'mirrored: all tangents finite');
    Check(BothHandednessSignsPresent(quad,mirrored),'both w signs present across fixtures');
  finally
    quad.Free;
    mirrored.Free;
  end;
  EndTest;
end;

// ============================================================================
// Main
// ============================================================================
begin
  try
    TestPlanarQuad;
    TestDegenerateUV;
    TestMirroredHandedness;
    writeln;
    writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
    if testsFailed>0 then
      ExitCode:=1
    else
      writeln('All OK');
  except
    on e:Exception do begin
      writeln;
      writeln('TEST FAILED! Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
