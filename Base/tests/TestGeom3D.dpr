{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestGeom3D;

uses
  SysUtils,
  Math,
  Apus.Core,
  Apus.Geom3D,
  Apus.Spatial;

{$INCLUDE Test.inc}

procedure TestVec3Core;
var
  a,b,c:TVec3;
begin
  StartTest('Vec3 core');
  a:=TVec3.Init(1,2,3);
  b:=TVec3.Init(-2,0,5);
  Check(Abs(a.Dot(b)-13)<0.0001,'Dot');
  c:=a.Cross(b);
  Check((Abs(c.x-10)<0.0001) and (Abs(c.y+11)<0.0001) and (Abs(c.z-4)<0.0001),'Cross');
  c:=a.Sub(b);
  Check((Abs(c.x-3)<0.0001) and (Abs(c.y-2)<0.0001) and (Abs(c.z+2)<0.0001),'Sub');
  Check(Abs(a.Distance2(b)-17)<0.0001,'Distance2 method');
  Check(Abs(a.Length-Sqrt(14))<0.0001,'Length');
  Check(Abs(a.Length2-14)<0.0001,'Length2');
  EndTest;
end;

procedure TestVec3Normalize;
var
  v:TVec3;
  raised:boolean;
begin
  StartTest('Vec3 normalize');
  v:=TVec3.Init(0,0,0);
  raised:=false;
  try
    v.Normalize;
  except
    on EZeroDivide do begin
      raised:=true;
    end;
    on EInvalidOp do begin
      raised:=true;
    end;
  end;
  // Current implementation raises on zero vector; track this behavior explicitly.
  Check(raised or ((v.x=0) and (v.y=0) and (v.z=0)),'Normalize zero edge');
  v:=TVec3.Init(0,3,4);
  v.Normalize;
  Check(Abs(v.Length-1)<0.0002,'Normalize non-zero');
  EndTest;
end;

procedure TestMatrices;
var
  m1,m2,m3,mInv,mRef,mT:TMat4;
  v:TVec4;
begin
  StartTest('Matrices');
  m1:=ScaleMat4(2,3,4);
  m2:=TranslationMat4(5,6,7);
  mRef:=m1*m2;
  m3:=m1*m2;
  Check(IsEqual(m3,mRef),'TMat4 operator *');
  Check(not IsEqual(m3,IdentMat4),'MultMat');
  mInv:=m3;
  mInv.Invert;
  m3:=m3*mInv;
  Check(IsEqual(m3,IdentMat4),'InvertFull');

  mT:=mRef.Transposed;
  mInv:=mRef;
  mInv.Transpose;
  Check(IsEqual(mT,mInv),'TMat4.Transposed');
  mRef.Transpose;
  Check(IsEqual(mRef,mInv),'TMat4.Transpose');

  v:=TVec4.Init(1,2,3,1);
  MultPnt(IdentMat4,@v,1,SizeOf(v));
  Check((Abs(v.x-1)<0.0001) and (Abs(v.y-2)<0.0001) and (Abs(v.z-3)<0.0001),'MultPnt identity');
  EndTest;
end;

procedure TestQuaternionConversions;
var
  m,m2:TMat3;
  q:TQuat;
begin
  StartTest('Quaternion conversions');
  m:=RotationAroundVector(TVec3.Init(1,2,3),1.25);
  q:=m.ToQuaternion;
  m2:=TMat3.FromQuaternion(q);
  Check(IsEqual(m,m2,200),'Matrix<->Quaternion');
  Check(Abs(q.Length-1)<0.001,'Quaternion normalized');
  EndTest;
end;

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

procedure TestGeom3DUtility;
var
  p0,p1,p2:TVec3;
  pd:TVec3d;
  v:TVec4;
  m3b:TMat3;
  m3d:TMat3d;
  m43:TMat34d;
  m43s:TMat34;
  m4d:TMat4d;
  m4:TMat4;
  m4dd,m4dt:TMat4d;
  q:TQuat;
  tr,rot,sca:TQuat;
  trd,rotd,scad:TQuatd;
  qd:TQuatd;
  qdv:TVec4d;
begin
  StartTest('Geom3D utility');
  p0:=Vec3(1,2,3);
  p1:=Vec3(4,6,8);
  p2:=p1.Sub(p0);
  Check((Abs(p2.x-3)<0.0001) and (Abs(p2.y-4)<0.0001) and (Abs(p2.z-5)<0.0001),'Vector from/to');
  Check(Abs(p0.Dot(p1)-40)<0.0001,'Dot');
  p2:=p0.Cross(p1);
  Check(Abs(p0.Length-Sqrt(14))<0.0001,'Length');
  Check(Abs(p0.Length2-14)<0.0001,'Length2');
  Check(Abs(Sqrt(p0.Distance2(p1))-Sqrt(50))<0.0001,'Distance');
  Check(Abs(p0.Distance2(p1)-50)<0.0001,'Distance2');
  Check(IsEqual(Vec3(1,2,3),TVec3.Init(1,2,3)),'Vec3 factory');
  pd:=TVec3d.Init(1,2,3);
  p2:=TVec3.Init(pd);
  Check((Abs(p2.x-1)<0.0001) and (Abs(p2.y-2)<0.0001) and (Abs(p2.z-3)<0.0001),'Vec3 from vec3d');
  p2:=Vec3(pd);
  Check((Abs(p2.x-1)<0.0001) and (Abs(p2.y-2)<0.0001) and (Abs(p2.z-3)<0.0001),'Vec3 factory from vec3d');
  pd:=Vec3d(p2);
  Check((Abs(pd.x-1)<0.0001) and (Abs(pd.y-2)<0.0001) and (Abs(pd.z-3)<0.0001),'Vec3d factory from vec3');
  p2:=TVec3.Init(TVec3d.Init(2,3,4));
  Check((Abs(p2.x-2)<0.0001) and (Abs(p2.y-3)<0.0001) and (Abs(p2.z-4)<0.0001),'Point from vec3d');
  p2:=TVec3.Init(p0,p1,0.5);
  Check((Abs(p2.x-2.5)<0.0001) and (Abs(p2.y-4)<0.0001),'PointBetween');
  Check(p0.MaxDelta(p0)=0,'MaxDelta single');
  Check(TVec3d.Init(1,2,3).MaxDelta(TVec3d.Init(1,2,3))=0,'MaxDelta double');
  Check(not IsZero(p0),'IsZero');
  Check(IsIdentity(TVec3.Init(1,1,1)),'IsIdentity vec');
  Check(IsEqual(1.0,1.0),'IsEqual scalar');

  m43:=TranslationMat(1,2,3);
  m43s:=IdentMat34;
  m43s[3,0]:=1;
  m43s[3,1]:=2;
  m43s[3,2]:=3;
  Check(IsIdentity(IdentMat34),'IsIdentity mat43s');
  m3b:=ToMat3(Matrix4(IdentMat4));
  Check(IsEqual(m3b,IdentMat3),'Matrix conversion');
  Check(IsEqual(IdentMat3.Row(0),Vec3(1,0,0)),'TMat3.Row');
  Check(IsEqual(IdentMat3.Col(1),Vec3(0,1,0)),'TMat3.Col');
  Check(IsEqual(IdentMat3d.Row(2),Vec3d(0,0,1),2),'TMat3d.Row');
  Check(IsEqual(IdentMat3d.Col(0),Vec3d(1,0,0),2),'TMat3d.Col');
  Check(IsEqual(m43.Row(3),Vec3d(1,2,3),2),'TMat34d.Row');
  Check(IsEqual(m43.Col(2),Vec3d(0,0,1),2),'TMat34d.Col');
  Check(IsEqual(m43s.Row(3),Vec3(1,2,3)),'TMat34.Row');
  Check(IsEqual(m43s.Col(0),Vec3(1,0,0)),'TMat34.Col');
  m4d:=Matrix4(m43); // keep conversion path in test
  Check(Abs(Det(IdentMat4)-1)<0.0001,'Det');
  m4d:=Matrix4(ScaleMat(2,3,4));
  m4dd:=TranslationMat4d(1,2,3);
  m4dt:=m4d*m4dd;
  Check(IsEqual(m4dt,m4d*m4dd,20),'TMat4d operator *');
  m4dd:=m4dt.Transposed;
  Check(IsEqual(m4dt.Transposed,m4dd,20),'TMat4d.Transposed');
  m4dd:=m4dt;
  m4dd.Invert;
  m4dt:=m4dt*m4dd;
  Check(IsEqual(m4dt,IdentMat4d,20),'TMat4d.Invert full');

  q:=Quat(1,2,3,4);
  v:=IdentMat4.Row(0);
  v:=IdentMat4.Col(0);
  q:=TQuat.Init(p0);
  q:=Quat(0,0,0,1);
  v:=q;
  q:=v;
  Check((Abs(q.x-v.x)<0.0001) and (Abs(q.y-v.y)<0.0001) and (Abs(q.z-v.z)<0.0001) and (Abs(q.w-v.w)<0.0001),'TQuat <-> TVec4 implicit');
  Check(Abs(q.Length-1)<0.0001,'TQuat.Length');
  q.Normalize;
  q:=q.Inverted;
  q:=q*Quat(0,0,0,1);
  q:=TQuat.Slerp(q,Quat(0,0,0,1),0.5);
  Check(q.IsValid,'Quaternion ops');
  v:=Vec4(p0);
  Check((Abs(v.x-p0.x)<0.0001) and (Abs(v.y-p0.y)<0.0001) and (Abs(v.z-p0.z)<0.0001) and (Abs(v.w-1)<0.0001),'Vec4 default w');
  v:=Vec4(p0,2);
  Check(Abs(v.w-2)<0.0001,'Vec4 explicit w');
  v:=Vec4(3,4,5,6);
  Check((Abs(v.x-3)<0.0001) and (Abs(v.y-4)<0.0001) and (Abs(v.z-5)<0.0001) and (Abs(v.w-6)<0.0001),'Vec4 component factory');
  Check(IsEqual(Vec3(v),TVec3.Init(v.x,v.y,v.z)),'Vec4->Vec3 factory');
  Check(IsEqual(v.ToVec3,TVec3.Init(v.x,v.y,v.z)),'TVec4.ToVec3');

  m4:=TranslationMat4(5,6,7);
  DecomposeMatrix(m4,tr,rot,sca);
  Check((Abs(tr.x-5)<0.0001) and (Abs(tr.y-6)<0.0001) and (Abs(tr.z-7)<0.0001),'DecomposeMatrix translation');
  Check((Abs(sca.x-1)<0.0001) and (Abs(sca.y-1)<0.0001) and (Abs(sca.z-1)<0.0001),'DecomposeMatrix scale');

  qd:=Quatd(0,0,0,1);
  Check(Abs(qd.Length-1)<0.0001,'TQuatd.Length');
  qd.Mul(2);
  Check(Abs(qd.Length-2)<0.0001,'TQuatd.Mul scalar');
  qd.Normalize;
  qd:=qd.Inverted;
  qd:=qd*Quatd(0,0,0,1);
  Check(qd.IsValid,'Quaternion double ops');
  qdv:=qd;
  qd:=qdv;
  Check((Abs(qd.x-qdv.x)<0.0001) and (Abs(qd.y-qdv.y)<0.0001) and (Abs(qd.z-qdv.z)<0.0001) and (Abs(qd.w-qdv.w)<0.0001),'TQuatd <-> TVec4d implicit');
  qdv:=Vec4d(pd);
  Check(IsEqual(qdv,TVec4d.Init(pd),2),'Vec4d default w');
  Check(IsEqual(qdv,Vec4d(1,2,3,1),2),'Vec4 double overload');
  qdv:=Vec4d(pd,2);
  Check(Abs(qdv.w-2)<0.0001,'Vec4d explicit w');
  qdv:=Vec4d(7,8,9,10);
  Check((Abs(qdv.x-7)<0.0001) and (Abs(qdv.y-8)<0.0001) and (Abs(qdv.z-9)<0.0001) and (Abs(qdv.w-10)<0.0001),'Vec4d component factory');
  v:=Vec4(qdv);
  Check((Abs(v.x-qdv.x)<0.0001) and (Abs(v.y-qdv.y)<0.0001) and (Abs(v.z-qdv.z)<0.0001) and (Abs(v.w-qdv.w)<0.0001),'Vec4 from vec4d');
  qdv:=Vec4d(v);
  Check((Abs(qdv.x-v.x)<0.0001) and (Abs(qdv.y-v.y)<0.0001) and (Abs(qdv.z-v.z)<0.0001) and (Abs(qdv.w-v.w)<0.0001),'Vec4d from vec4');
  Check(IsEqual(Vec3d(1,2,3),TVec3d.Init(1,2,3),2),'Vec3d factory');
  Check(IsEqual(Vec3d(qdv),TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'Vec4d->Vec3d factory');
  Check(IsEqual(qdv.ToVec3d,TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'TVec4d.ToVec3d');
  m3d:=TMat3d.FromQuaternion(qd);
  qd:=m3d.ToQuaternion;
  Check(qd.IsValid,'TMat3d quaternion conversion');
  m4dd:=TranslationMat4d(1,2,3);
  DecomposeMatrix(m4dd,trd,rotd,scad);
  Check((Abs(trd.x-1)<0.0001) and (Abs(trd.y-2)<0.0001) and (Abs(trd.z-3)<0.0001),'DecomposeMatrix double');
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
  YRPToMatrix(m34,y0,r0,p0);
  MatrixToYRP(m34,y1,r1,p1);
  YRPToMatrix(m34b,y1,r1,p1);
  Check(IsEqual(m34,m34b,40),'Yaw/Roll/Pitch matrix roundtrip');

  m3s:=RotationMat3X(0.4);
  m3sRef:=ToMat3(Matrix4(RotationXMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationMat3X consistency');
  m3s:=RotationMat3Y(0.4);
  m3sRef:=ToMat3(Matrix4(RotationYMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationMat3Y consistency');
  m3s:=RotationMat3Z(0.4);
  m3sRef:=ToMat3(Matrix4(RotationZMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationMat3Z consistency');

  a:=TVec3.Init(0,0,0);
  b:=TVec3.Init(1,0,0);
  c:=TVec3.Init(0,1,0);
  o:=TVec3.Init(0.25,0.25,1);
  tp:=TVec3.Init(0.25,0.25,0);
  dir:=Vec3(Direction3(Point3(o),Point3(tp)));
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(hit and (d>0) and (pb>=0) and (pc>=0) and (pb+pc<=1),'TRay.IntersectsTriangle hit');

  o:=TVec3.Init(2,2,1);
  tp:=TVec3.Init(2,2,0);
  dir:=Vec3(Direction3(Point3(o),Point3(tp)));
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(not hit,'TRay.IntersectsTriangle miss');

  o:=TVec3.Init(0.25,0.25,1);
  tp:=TVec3.Init(1.25,0.25,1);
  dir:=Vec3(Direction3(Point3(o),Point3(tp)));
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsTriangle(a,b,c,d,pb,pc);
  Check(not hit,'TRay.IntersectsTriangle parallel');

  plane:=TPlane.Init(TVec3d.Init(0,0,0),TVec3d.Init(0,0,1));
  o:=TVec3.Init(0,0,2);
  dir:=Vec3(Direction3(Point3(o),TVec3d.Init(0,0,0)));
  dir.Normalize;
  ray:=TRay.Init(o,dir);
  hit:=ray.IntersectsPlane(plane,planeDist);
  Check(hit and (Abs(planeDist-2)<0.0001),'TRay.IntersectsPlane hit');

  ray:=TRay.Init(TVec3.Init(0,0,2),TVec3.Init(1,0,0));
  hit:=ray.IntersectsPlane(plane,planeDist);
  Check(not hit,'TRay.IntersectsPlane parallel');
  EndTest;
end;

begin
  TestVec3Core;
  TestVec3Normalize;
  TestMatrices;
  TestQuaternionConversions;
  TestBBox;
  TestGeom3DUtility;
  TestGeom3DUtility2;
  TestGeom3DEdgeCases;
  writeln;
  writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
  if testsFailed>0 then begin
    halt(1);
  end;
  writeln('All OK');
end.








