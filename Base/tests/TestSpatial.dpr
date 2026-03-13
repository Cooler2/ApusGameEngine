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

procedure TestBBox;
var
  b1,b2:TBBox3;
  c,e:TVec3;
begin
  StartTest('BBox');
  b1.Clear;
  Check(b1.IsEmpty,'Init empty');
  b1.IncludePoint(TVec3.Init(1,2,3));
  b1.IncludePoint(TVec3.Init(5,6,7));
  Check(not b1.IsEmpty,'IncludePoint');
  c:=b1.Center;
  e:=b1.Extents;
  Check((Abs(c.x-3)<0.0001) and (Abs(c.y-4)<0.0001) and (Abs(c.z-5)<0.0001),'Center');
  Check((Abs(e.x-2)<0.0001) and (Abs(e.y-2)<0.0001) and (Abs(e.z-2)<0.0001),'Extents');
  Check(b1.ContainsPoint(TVec3.Init(2,3,4)),'ContainsPoint hit');
  Check(not b1.ContainsPoint(TVec3.Init(0,0,0)),'ContainsPoint miss');
  Check(b1.IntersectsSphere(TVec3.Init(7,4,5),2),'IntersectsSphere tangent');
  Check(not b1.IntersectsSphere(TVec3.Init(20,20,20),1),'IntersectsSphere miss');

  b2.Clear;
  b2.IncludePoint(TVec3.Init(4,5,6));
  b2.IncludePoint(TVec3.Init(9,9,9));
  Check(b1.IntersectsBox(b2),'IntersectsBox hit');
  b2.Clear;
  b2.IncludePoint(TVec3.Init(20,20,20));
  b2.IncludePoint(TVec3.Init(21,21,21));
  Check(not b1.IntersectsBox(b2),'IntersectsBox miss');
  EndTest;
end;

procedure TestGeom3DUtility2;
var
  d:double;
  a1,a2:array[0..2] of single;
  b1,b2:array[0..2] of double;
  bbA,bbB:TBBox3;
  pl:TPlane;
begin
  StartTest('Geom3D utility2');
  pl:=TPlane.Init(TVec3d.Init(0,2,0),TVec3d.Init(0,1,0));
  d:=pl.DistanceTo(TVec3d.Init(0,2,0));
  Check(Abs(d)<0.0001,'TPlane.DistanceTo');
  Check(Abs(pl.DistanceTo(TVec3d.Init(0,1,0))+1)<0.0001,'TPlane.DistanceTo signed');

  bbA.Clear;
  bbA.IncludePoint(TVec3.Init(1,2,3));
  bbA.IncludePoint(TVec3.Init(4,5,6));
  bbB.Clear;
  bbB.IncludePoint(TVec3.Init(3,4,5));
  bbB.IncludePoint(TVec3.Init(8,9,10));
  bbA.IncludeBox(bbB);
  Check(bbA.ContainsPoint(TVec3.Init(8,9,10)),'TBBox3.IncludeBox');
  Check(bbA.IntersectsBox(bbB),'TBBox3.IntersectsBox');

  a1[0]:=1; a1[1]:=2; a1[2]:=3;
  a2:=a1;
  Check(CompareSingle(@a1[0],@a2[0],3),'CompareSingle');
  a2[2]:=a2[2]+0.01;
  Check(not CompareSingle(@a1[0],@a2[0],3),'CompareSingle mismatch');
  b1[0]:=1; b1[1]:=2; b1[2]:=3;
  b2:=b1;
  Check(CompareDouble(@b1[0],@b2[0],3),'CompareDouble');
  b2[0]:=b2[0]+1E-6;
  Check(not CompareDouble(@b1[0],@b2[0],3),'CompareDouble mismatch');

  bbA.Clear;
  bbA.IncludePoint(TVec3.Init(1,2,3));
  bbA.IncludePoint(TVec3.Init(4,5,6));
  bbB.Clear;
  bbB.IncludePoint(TVec3.Init(3,4,5));
  bbB.IncludePoint(TVec3.Init(10,11,12));
  Check(bbA.IntersectsBox(bbB),'TBBox3 intersects check');
  EndTest;
end;

procedure TestGeom3DEdgeCases;
var
  m34,m34b:TMat34d;
  y0,r0,p0:double;
  y1,r1,p1:double;
  m3s,m3sRef:TMat3;
  a,b,c,o,tp:TVec3;
  ray:TRay;
  plane:TPlane;
  planeDist:single;
  pb,pc,d:single;
  dir:TVec3;
  hit:boolean;
begin
  StartTest('Geom3D edge cases');
  y0:=0.35;
  r0:=-0.2;
  p0:=0.5;
  m34:=TMat34d.FromYRP(y0,r0,p0);
  m34.ToYRP(y1,r1,p1);
  m34b:=TMat34d.FromYRP(y1,r1,p1);
  Check(m34.IsEqual(m34b,40),'Yaw/Roll/Pitch matrix roundtrip');

  m3s:=TMat3.RotationX(0.4);
  m3sRef:=TMat3.Init(TMat4d.Init(TMat34d.RotationX(0.4)));
  Check(m3s.IsEqual(m3sRef,20),'RotationMat3X consistency');
  m3s:=TMat3.RotationY(0.4);
  m3sRef:=TMat3.Init(TMat4d.Init(TMat34d.RotationY(0.4)));
  Check(m3s.IsEqual(m3sRef,20),'RotationMat3Y consistency');
  m3s:=TMat3.RotationZ(0.4);
  m3sRef:=TMat3.Init(TMat4d.Init(TMat34d.RotationZ(0.4)));
  Check(m3s.IsEqual(m3sRef,20),'RotationMat3Z consistency');

  a:=TVec3.Init(0,0,0);
  b:=TVec3.Init(1,0,0);
  c:=TVec3.Init(0,1,0);
  o:=TVec3.Init(0.25,0.25,1);
  tp:=TVec3.Init(0.25,0.25,0);
  dir:=TVec3.Init(tp.x-o.x,tp.y-o.y,tp.z-o.z);
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(hit and (d>0) and (pb>=0) and (pc>=0) and (pb+pc<=1),'TRay.IntersectsTriangle hit');

  o:=TVec3.Init(2,2,1);
  tp:=TVec3.Init(2,2,0);
  dir:=TVec3.Init(tp.x-o.x,tp.y-o.y,tp.z-o.z);
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(not hit,'TRay.IntersectsTriangle miss');

  o:=TVec3.Init(0.25,0.25,1);
  tp:=TVec3.Init(1.25,0.25,1);
  dir:=TVec3.Init(tp.x-o.x,tp.y-o.y,tp.z-o.z);
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(not hit,'TRay.IntersectsTriangle parallel');

  plane:=TPlane.Init(TVec3d.Init(0,0,0),TVec3d.Init(0,0,1));
  o:=TVec3.Init(0,0,2);
  dir:=TVec3.Init(-o.x,-o.y,-o.z);
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsPlane(plane,planeDist);
  Check(hit and (Abs(planeDist-2)<0.0001),'TRay.IntersectsPlane hit');

  ray:=TRay.Init(TVec3.Init(0,0,2),TVec3.Init(1,0,0));
  hit:=ray.IntersectsPlane(plane,planeDist);
  Check(not hit,'TRay.IntersectsPlane parallel');
  EndTest;
end;


procedure TestRaySphere;
var
  ray: TRay;
  sphere: TSphere;
  t: single;
begin
  StartTest('Ray-Sphere');
  ray:=TRay.Init(TVec3.Init(0, 0, 0), TVec3.Init(1, 0, 0));
  sphere:=TSphere.Init(TVec3.Init(5, 0, 0), 1);
  Check(ray.IntersectsSphere(sphere, t), 'hit case');
  Check(Abs(t - 4) < 0.001, 'hit distance');

  sphere:=TSphere.Init(TVec3.Init(5, 2, 0), 1);
  Check(not ray.IntersectsSphere(sphere, t), 'miss case');

  sphere:=TSphere.Init(TVec3.Init(5, 1, 0), 1);
  Check(ray.IntersectsSphere(sphere, t), 'tangent case');
  Check(Abs(t - 5) < 0.001, 'tangent distance');

  // Degenerate: zero direction should not crash.
  ray:=TRay.Init(TVec3.Init(0, 0, 0), TVec3.Init(0, 0, 0));
  sphere:=TSphere.Init(TVec3.Init(0, 0, 0), 1);
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

  ray:=TRay.Init(TVec3.Init(0, 2, 2), TVec3.Init(1, 0, 0));
  Check(ray.IntersectsBox(box, tMin, tMax), 'hit case');
  Check(Abs(tMin - 1) < 0.001, 'tMin');
  Check(Abs(tMax - 3) < 0.001, 'tMax');

  ray:=TRay.Init(TVec3.Init(0, 0, 0), TVec3.Init(0, 1, 0));
  Check(not ray.IntersectsBox(box, tMin, tMax), 'miss case');

  ray:=TRay.Init(TVec3.Init(2, 2, 2), TVec3.Init(1, 0, 0));
  Check(ray.IntersectsBox(box, tMin, tMax), 'inside start case');
  Check(tMax >= 0, 'inside distance');

  ray:=TRay.Init(TVec3.Init(0.5, 2, 2), TVec3.Init(1E-6, 1, 0));
  Check(not ray.IntersectsBox(box, tMin, tMax), 'near-parallel outside slab');
  ray:=TRay.Init(TVec3.Init(2, 0, 2), TVec3.Init(1E-6, 1, 0));
  Check(ray.IntersectsBox(box, tMin, tMax), 'near-parallel inside slab');
  EndTest;
end;

procedure TestRayTriangle;
var
  ray: TRay;
  a, b, c: TVec3;
  t, u, v: single;
begin
  StartTest('Ray-Triangle');
  a:=TVec3.Init(0, 0, 0);
  b:=TVec3.Init(1, 0, 0);
  c:=TVec3.Init(0, 1, 0);

  ray:=TRay.Init(TVec3.Init(0.25, 0.25, 1), TVec3.Init(0, 0, -1));
  Check(ray.IntersectsTriangle(a, b, c, t, u, v), 'hit case');
  Check(Abs(t - 1) < 0.001, 'hit distance');

  ray:=TRay.Init(TVec3.Init(2, 2, 1), TVec3.Init(0, 0, -1));
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'miss case');

  // Degenerate triangle.
  c:=TVec3.Init(2, 0, 0);
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'degenerate case');

  // Edge hit and behind-ray case.
  a:=TVec3.Init(0, 0, 0);
  b:=TVec3.Init(1, 0, 0);
  c:=TVec3.Init(0, 1, 0);
  ray:=TRay.Init(TVec3.Init(0.5, 0, 1), TVec3.Init(0, 0, -1));
  Check(ray.IntersectsTriangle(a, b, c, t, u, v), 'edge hit');
  ray:=TRay.Init(TVec3.Init(0, 0, 1), TVec3.Init(0, 0, -1));
  Check(ray.IntersectsTriangle(a, b, c, t, u, v), 'vertex hit');
  ray:=TRay.Init(TVec3.Init(-0.001, 0, 1), TVec3.Init(0, 0, -1));
  Check(not ray.IntersectsTriangle(a, b, c, t, u, v), 'near-edge outside');
  ray:=TRay.Init(TVec3.Init(0.25, 0.25, -1), TVec3.Init(0, 0, -1));
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
  plane:=TPlane.Init(TVec3d.Init(0,0,0),TVec3d.Init(0,0,1)); // z=0 plane

  ray:=TRay.Init(TVec3.Init(0, 0, 2), TVec3.Init(0, 0, -1));
  Check(ray.IntersectsPlane(plane, t), 'hit case');
  Check(Abs(t - 2) < 0.001, 'hit distance');

  ray:=TRay.Init(TVec3.Init(0, 0, 2), TVec3.Init(1, 0, 0));
  Check(not ray.IntersectsPlane(plane, t), 'parallel miss');
  ray:=TRay.Init(TVec3.Init(0, 0, 2), TVec3.Init(1, 0, 1E-6));
  Check(not ray.IntersectsPlane(plane, t), 'near-parallel miss');

  ray:=TRay.Init(TVec3.Init(0, 0, 0), TVec3.Init(1, 0, 0));
  Check(ray.IntersectsPlane(plane, t), 'origin on plane');
  Check(Abs(t) < 0.001, 'origin t');

  ray:=TRay.Init(TVec3.Init(0, 0, 2), TVec3.Init(0, 0, 1));
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

  sphere:=TSphere.Init(TVec3.Init(0, 0, 0), 0.5);
  Check(sphere.IntersectsBox(box), 'hit case');
  Check(sphere.ContainsPoint(TVec3.Init(0, 0, 0)), 'contains point');

  sphere:=TSphere.Init(TVec3.Init(3, 0, 0), 1);
  Check(not sphere.IntersectsBox(box), 'miss case');

  sphere:=TSphere.Init(TVec3.Init(2, 0, 0), 1);
  Check(sphere.IntersectsBox(box), 'tangent case');
  EndTest;
end;

procedure TestFrustum;
var
  fr: TFrustum;
  sphere: TSphere;
  box: TBBox3;
  degMVP:TMat4;
begin
  StartTest('Frustum');
  fr.InitFromMVP(IdentMat4, true);
  Check(fr.planeCount = 6, '6-plane mode');

  sphere:=TSphere.Init(TVec3.Init(0, 0, 0), 0.1);
  Check(fr.IntersectsSphere(sphere), 'sphere hit');
  sphere:=TSphere.Init(TVec3.Init(5, 0, 0), 0.1);
  Check(not fr.IntersectsSphere(sphere), 'sphere miss');
  sphere:=TSphere.Init(TVec3.Init(1.05, 0, 0), 0.05);
  Check(fr.IntersectsSphere(sphere), 'sphere tangent');
  sphere:=TSphere.Init(TVec3.Init(1.051, 0, 0), 0.05);
  Check(not fr.IntersectsSphere(sphere), 'sphere beyond tangent');

  box.minX:=-0.5; box.minY:=-0.5; box.minZ:=-0.5;
  box.maxX:=0.5; box.maxY:=0.5; box.maxZ:=0.5;
  Check(fr.IntersectsBox(box), 'box hit');

  box.minX:=3; box.minY:=3; box.minZ:=3;
  box.maxX:=4; box.maxY:=4; box.maxZ:=4;
  Check(not fr.IntersectsBox(box), 'box miss');
  box.minX:=1; box.minY:=-0.1; box.minZ:=-0.1;
  box.maxX:=1.2; box.maxY:=0.1; box.maxZ:=0.1;
  Check(fr.IntersectsBox(box), 'box tangent');
  box.minX:=1.001; box.minY:=-0.1; box.minZ:=-0.1;
  box.maxX:=1.2; box.maxY:=0.1; box.maxZ:=0.1;
  Check(not fr.IntersectsBox(box), 'box beyond tangent');

  fr.InitFromMVP(IdentMat4, false);
  Check(fr.planeCount = 4, '4-plane mode');

  FillChar(degMVP, SizeOf(degMVP), 0);
  fr.InitFromMVP(degMVP, true);
  sphere:=TSphere.Init(TVec3.Init(100, 0, 0), 1);
  Check(fr.IntersectsSphere(sphere), 'degenerate mvp sphere fallback');
  box.minX:=100; box.minY:=100; box.minZ:=100;
  box.maxX:=101; box.maxY:=101; box.maxZ:=101;
  Check(fr.IntersectsBox(box), 'degenerate mvp box fallback');
  EndTest;
end;

begin
  try
    TestBBox;
    TestGeom3DUtility2;
    TestGeom3DEdgeCases;
    TestRaySphere;
    TestRayBox;
    TestRayTriangle;
    TestRayPlane;
    TestSphereBox;
    TestFrustum;
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







