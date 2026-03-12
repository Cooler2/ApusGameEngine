{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestSpatial;

uses
  SysUtils,
  Math,
  Apus.Core,
  Apus.Geom3D,
  Apus.Spatial;

{$INCLUDE Test.inc}

procedure TestRaySphere;
var
  ray: TRay;
  sphere: TSphere;
  t: single;
begin
  StartTest('Ray-Sphere');
  ray:=TRay.Init(Point3s(0, 0, 0), Vector3s(1, 0, 0));
  sphere:=TSphere.Init(Point3s(5, 0, 0), 1);
  Check(ray.IntersectsSphere(sphere, t), 'hit case');
  Check(Abs(t - 4) < 0.001, 'hit distance');

  sphere:=TSphere.Init(Point3s(5, 2, 0), 1);
  Check(not ray.IntersectsSphere(sphere, t), 'miss case');

  sphere:=TSphere.Init(Point3s(5, 1, 0), 1);
  Check(ray.IntersectsSphere(sphere, t), 'tangent case');
  Check(Abs(t - 5) < 0.001, 'tangent distance');

  // Degenerate: zero direction should not crash.
  ray:=TRay.Init(Point3s(0, 0, 0), Point3s(0, 0, 0));
  sphere:=TSphere.Init(Point3s(0, 0, 0), 1);
  ray.IntersectsSphere(sphere, t);
  Check(true, 'degenerate direction');
  EndTest;
end;

procedure TestRayBox;
var
  ray: TRay;
  box: TBBox3;
  tMin, tMax: single;
begin
  StartTest('Ray-Box');
  box.minX:=1; box.minY:=1; box.minZ:=1;
  box.maxX:=3; box.maxY:=3; box.maxZ:=3;

  ray:=TRay.Init(Point3s(0, 2, 2), Vector3s(1, 0, 0));
  Check(ray.IntersectsBox(box, tMin, tMax), 'hit case');
  Check(Abs(tMin - 1) < 0.001, 'tMin');
  Check(Abs(tMax - 3) < 0.001, 'tMax');

  ray:=TRay.Init(Point3s(0, 0, 0), Vector3s(0, 1, 0));
  Check(not ray.IntersectsBox(box, tMin, tMax), 'miss case');

  ray:=TRay.Init(Point3s(2, 2, 2), Vector3s(1, 0, 0));
  Check(ray.IntersectsBox(box, tMin, tMax), 'inside start case');
  Check(tMax >= 0, 'inside distance');
  EndTest;
end;

procedure TestRayTriangle;
var
  ray: TRay;
  a, b, c: TVec3;
  t, u, v: single;
begin
  StartTest('Ray-Triangle');
  a:=Point3s(0, 0, 0);
  b:=Point3s(1, 0, 0);
  c:=Point3s(0, 1, 0);

  ray:=TRay.Init(Point3s(0.25, 0.25, 1), Vector3s(0, 0, -1));
  Check(ray.IntersectsTriangle(a, b, c, t, u, v), 'hit case');
  Check(Abs(t - 1) < 0.001, 'hit distance');

  ray:=TRay.Init(Point3s(2, 2, 1), Vector3s(0, 0, -1));
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'miss case');

  // Degenerate triangle.
  c:=Point3s(2, 0, 0);
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'degenerate case');

  // Edge hit and behind-ray case.
  a:=Point3s(0, 0, 0);
  b:=Point3s(1, 0, 0);
  c:=Point3s(0, 1, 0);
  ray:=TRay.Init(Point3s(0.5, 0, 1), Vector3s(0, 0, -1));
  Check(ray.IntersectsTriangle(a, b, c, t, u, v), 'edge hit');
  ray:=TRay.Init(Point3s(0.25, 0.25, -1), Vector3s(0, 0, -1));
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'behind case');
  EndTest;
end;

procedure TestRayPlane;
var
  ray: TRay;
  plane: TPlane;
  t: single;
begin
  StartTest('Ray-Plane');
  plane:=TPlane.Init(Vector3(0, 0, 0), Vector3(0, 0, 1)); // z=0 plane

  ray:=TRay.Init(Point3s(0, 0, 2), Vector3s(0, 0, -1));
  Check(ray.IntersectsPlane(plane, t), 'hit case');
  Check(Abs(t - 2) < 0.001, 'hit distance');

  ray:=TRay.Init(Point3s(0, 0, 2), Vector3s(1, 0, 0));
  Check(not ray.IntersectsPlane(plane, t), 'parallel miss');

  ray:=TRay.Init(Point3s(0, 0, 0), Vector3s(1, 0, 0));
  Check(ray.IntersectsPlane(plane, t), 'origin on plane');
  Check(Abs(t) < 0.001, 'origin t');

  ray:=TRay.Init(Point3s(0, 0, 2), Vector3s(0, 0, 1));
  Check(not ray.IntersectsPlane(plane, t), 'behind ray');
  EndTest;
end;

procedure TestSphereBox;
var
  sphere: TSphere;
  box: TBBox3;
begin
  StartTest('Sphere-Box');
  box.minX:=-1; box.minY:=-1; box.minZ:=-1;
  box.maxX:=1; box.maxY:=1; box.maxZ:=1;

  sphere:=TSphere.Init(Point3s(0, 0, 0), 0.5);
  Check(sphere.IntersectsBox(box), 'hit case');
  Check(sphere.ContainsPoint(Point3s(0, 0, 0)), 'contains point');

  sphere:=TSphere.Init(Point3s(3, 0, 0), 1);
  Check(not sphere.IntersectsBox(box), 'miss case');

  sphere:=TSphere.Init(Point3s(2, 0, 0), 1);
  Check(sphere.IntersectsBox(box), 'tangent case');
  EndTest;
end;

procedure TestFrustum;
var
  fr: TFrustum;
  sphere: TSphere;
  box: TBBox3;
begin
  StartTest('Frustum');
  fr.InitFromMVP(IdentMatrix4s, true);
  Check(fr.planeCount = 6, '6-plane mode');

  sphere:=TSphere.Init(Point3s(0, 0, 0), 0.1);
  Check(fr.IntersectsSphere(sphere), 'sphere hit');
  sphere:=TSphere.Init(Point3s(5, 0, 0), 0.1);
  Check(not fr.IntersectsSphere(sphere), 'sphere miss');

  box.minX:=-0.5; box.minY:=-0.5; box.minZ:=-0.5;
  box.maxX:=0.5; box.maxY:=0.5; box.maxZ:=0.5;
  Check(fr.IntersectsBox(box), 'box hit');

  box.minX:=3; box.minY:=3; box.minZ:=3;
  box.maxX:=4; box.maxY:=4; box.maxZ:=4;
  Check(not fr.IntersectsBox(box), 'box miss');

  fr.InitFromMVP(IdentMatrix4s, false);
  Check(fr.planeCount = 4, '4-plane mode');
  EndTest;
end;

begin
  TestRaySphere;
  TestRayBox;
  TestRayTriangle;
  TestRayPlane;
  TestSphereBox;
  TestFrustum;
  writeln;
  writeln('TOTAL: ', testsTotal, ' checks, FAILED: ', testsFailed);
  if testsFailed > 0 then begin
    halt(1);
  end;
  writeln('All OK');
end.

