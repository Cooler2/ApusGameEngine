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
  m1,m2,m3,mInv:TMat4;
  v:TVec4;
begin
  StartTest('Matrices');
  m1:=ScaleMat4(2,3,4);
  m2:=TranslationMat4(5,6,7);
  m3:=MultMat(m1,m2);
  Check(not IsEqual(m3,IdentMat4),'MultMat');
  InvertFull(m3,mInv);
  m3:=MultMat(m3,mInv);
  Check(IsEqual(m3,IdentMat4),'InvertFull');

  v:=TQuat.Init(1,2,3,1);
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
  q:=MatrixToQuaternion(m);
  QuaternionToMatrix(q,m2);
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
  m4d:TMat4d;
  m4:TMat4;
  m4dd:TMat4d;
  q:TVec4;
  tr,rot,sca:TQuat;
  trd,rotd,scad:TQuatd;
  qd,qdv:TQuatd;
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
  Check(IsIdentity(IdentMat34),'IsIdentity mat43s');
  m3b:=ToMat3(Matrix4(IdentMat4));
  Check(IsEqual(m3b,IdentMat3),'Matrix conversion');
  m4d:=Matrix4(m43); // keep conversion path in test
  Check(Abs(Det(IdentMat4)-1)<0.0001,'Det');

  q:=Quat(1,2,3,4);
  v:=MatRow(IdentMat4,0);
  v:=MatCol(IdentMat4,0);
  q:=TQuat.Init(p0);
  q:=Quat(0,0,0,1);
  Check(Abs(QuatLength(q)-1)<0.0001,'QuatLength');
  QuatNormalize(q);
  q:=QuatInvert(q);
  q:=QuatMultiply(q,Quat(0,0,0,1));
  q:=QuatSlerp(q,Quat(0,0,0,1),0.5);
  Check(q.IsValid,'Quaternion ops');
  Check(IsEqual(Vec3(q),TVec3.Init(q.x,q.y,q.z)),'Vec4->Vec3 factory');
  Check(IsEqual(q.ToVec3,TVec3.Init(q.x,q.y,q.z)),'TQuat.ToVec3');

  m4:=TranslationMat4(5,6,7);
  DecomposeMatrix(m4,tr,rot,sca);
  Check((Abs(tr.x-5)<0.0001) and (Abs(tr.y-6)<0.0001) and (Abs(tr.z-7)<0.0001),'DecomposeMatrix translation');
  Check((Abs(sca.x-1)<0.0001) and (Abs(sca.y-1)<0.0001) and (Abs(sca.z-1)<0.0001),'DecomposeMatrix scale');

  qd:=Quatd(0,0,0,1);
  Check(Abs(QuatLength(qd)-1)<0.0001,'QuatLength double');
  QuatScale(qd,2);
  Check(Abs(QuatLength(qd)-2)<0.0001,'QuatScale double');
  QuatNormalize(qd);
  qd:=QuatInvert(qd);
  qd:=QuatMultiply(qd,Quatd(0,0,0,1));
  Check(qd.IsValid,'Quaternion double ops');
  qdv:=TQuatd.Init(pd);
  Check(IsEqual(qdv,Quatd(1,2,3,1),2),'Vec4 double overload');
  Check(IsEqual(Vec3d(1,2,3),TVec3d.Init(1,2,3),2),'Vec3d factory');
  Check(IsEqual(Vec3d(qdv),TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'Vec4d->Vec3d factory');
  Check(IsEqual(qdv.ToVec3d,TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'TQuatd.ToVec3d');
  QuaternionToMatrix(qd,m3d);
  qd:=MatrixToQuaternion(m3d);
  Check(qd.IsValid,'QuaternionToMatrix double alias');
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
  pb,pc,d:double;
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
  hit:=IntersectTrgLine(@a,@b,@c,@o,@tp,pb,pc,d);
  Check(hit and (d>0) and (pb>=0) and (pc>=0) and (pb+pc<=1),'IntersectTrgLine hit');

  o:=TVec3.Init(2,2,1);
  tp:=TVec3.Init(2,2,0);
  hit:=IntersectTrgLine(@a,@b,@c,@o,@tp,pb,pc,d);
  Check(not hit,'IntersectTrgLine miss');

  o:=TVec3.Init(0.25,0.25,1);
  tp:=TVec3.Init(1.25,0.25,1);
  hit:=IntersectTrgLine(@a,@b,@c,@o,@tp,pb,pc,d);
  Check(not hit,'IntersectTrgLine parallel');
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








