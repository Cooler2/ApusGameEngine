{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestGeom3D;

uses
  SysUtils,
  Math,
  Apus.Core,
  Apus.Geom3D;

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
    Normalize(v);
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
  Normalize(v);
  Check(Abs(v.Length-1)<0.0002,'Normalize non-zero');
  EndTest;
end;

procedure TestMatrices;
var
  m1,m2,m3,mInv:TMat4;
  v:TVec4;
begin
  StartTest('Matrices');
  m1:=ScaleMat4s(2,3,4);
  m2:=TranslationMat4s(5,6,7);
  m3:=MultMat(m1,m2);
  Check(not IsEqual(m3,IdentMatrix4s),'MultMat');
  InvertFull(m3,mInv);
  m3:=MultMat(m3,mInv);
  Check(IsEqual(m3,IdentMatrix4s),'InvertFull');

  v:=QuaternionS(1,2,3,1);
  MultPnt(IdentMatrix4s,@v,1,SizeOf(v));
  Check((Abs(v.x-1)<0.0001) and (Abs(v.y-2)<0.0001) and (Abs(v.z-3)<0.0001),'MultPnt identity');
  EndTest;
end;

procedure TestQuaternionConversions;
var
  m,m2:TMatrix3s;
  q:TQuaternionS;
begin
  StartTest('Quaternion conversions');
  m:=RotationAroundVector(Vector3s(1,2,3),1.25);
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
  b1.Init;
  Check(b1.IsEmpty,'Init empty');
  b1.IncludePoint(Point3s(1,2,3));
  b1.IncludePoint(Point3s(5,6,7));
  Check(not b1.IsEmpty,'IncludePoint');
  c:=b1.Center;
  e:=b1.Extents;
  Check((Abs(c.x-3)<0.0001) and (Abs(c.y-4)<0.0001) and (Abs(c.z-5)<0.0001),'Center');
  Check((Abs(e.x-2)<0.0001) and (Abs(e.y-2)<0.0001) and (Abs(e.z-2)<0.0001),'Extents');
  Check(b1.ContainsPoint(Point3s(2,3,4)),'ContainsPoint hit');
  Check(not b1.ContainsPoint(Point3s(0,0,0)),'ContainsPoint miss');
  Check(b1.IntersectsSphere(Point3s(7,4,5),2),'IntersectsSphere tangent');
  Check(not b1.IntersectsSphere(Point3s(20,20,20),1),'IntersectsSphere miss');

  b2.Init;
  b2.IncludePoint(Point3s(4,5,6));
  b2.IncludePoint(Point3s(9,9,9));
  Check(b1.IntersectsBox(b2),'IntersectsBox hit');
  b2.Init;
  b2.IncludePoint(Point3s(20,20,20));
  b2.IncludePoint(Point3s(21,21,21));
  Check(not b1.IntersectsBox(b2),'IntersectsBox miss');
  EndTest;
end;

procedure TestGeom3DUtility;
var
  p0,p1,p2:TVec3;
  v:TVec4;
  m3b:TMat3;
  m43:TMat34d;
  m4d:TMat4d;
  q:TVec4;
  m4:TMat4;
  tr,rot,sca:TQuaternionS;
begin
  StartTest('Geom3D utility');
  p0:=Point3s(1,2,3);
  p1:=Point3s(4,6,8);
  p2:=Vector3s(p0,p1);
  Check((Abs(p2.x-3)<0.0001) and (Abs(p2.y-4)<0.0001) and (Abs(p2.z-5)<0.0001),'Vector3s from/to');
  Check(Abs(DotProduct(p0,p1)-40)<0.0001,'DotProduct');
  p2:=CrossProduct(p0,p1);
  Check(Abs(GetLength(p0)-Sqrt(14))<0.0001,'GetLength');
  Check(Abs(GetSqrLength(p0)-14)<0.0001,'GetSqrLength');
  Check(Abs(Distance(p0,p1)-Sqrt(50))<0.0001,'Distance');
  Check(Abs(Distance2(p0,p1)-50)<0.0001,'Distance2');
  PointBetween(p0,p1,0.5,p2);
  Check((Abs(p2.x-2.5)<0.0001) and (Abs(p2.y-4)<0.0001),'PointBetween');
  Check(IsNearS(p0,p0)=0,'IsNearS');
  Check(IsNear(Point3(1,2,3),Point3(1,2,3))=0,'IsNear');
  Check(not IsZero(p0),'IsZero');
  Check(IsIdentity(Vector3s(1,1,1)),'IsIdentity vec');
  Check(IsEqual(1.0,1.0),'IsEqual scalar');

  m43:=TranslationMat(1,2,3);
  Check(IsIdentity(IdentMatrix43s),'IsIdentity mat43s');
  m3b:=Matrix3s(Matrix4(IdentMatrix4s));
  Check(IsEqual(m3b,IdentMatrix3s),'Matrix conversion');
  m4d:=Matrix4(m43); // keep conversion path in test
  Check(Abs(Det(IdentMatrix4s)-1)<0.0001,'Det');

  q:=QuaternionS(1,2,3,4);
  v:=MatRow(IdentMatrix4s,0);
  v:=MatCol(IdentMatrix4s,0);
  q:=Vector4s(p0);
  q:=QuaternionS(0,0,0,1);
  Check(Abs(QLength(q)-1)<0.0001,'QLength');
  QNormalize(q);
  q:=QInvert(q);
  q:=QMult(q,QuaternionS(0,0,0,1));
  Check(q.IsValid,'Quaternion ops');

  m4:=TranslationMat4s(5,6,7);
  DecomposeMatrix(m4,tr,rot,sca);
  Check((Abs(tr.x-5)<0.0001) and (Abs(tr.y-6)<0.0001) and (Abs(tr.z-7)<0.0001),'DecomposeMatrix translation');
  Check((Abs(sca.x-1)<0.0001) and (Abs(sca.y-1)<0.0001) and (Abs(sca.z-1)<0.0001),'DecomposeMatrix scale');
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
  pl:=TPlane.Init(Vector3(0,2,0),Vector3(0,1,0));
  d:=pl.Offset(Point3(0,2,0));
  Check(Abs(d)<0.0001,'TPlane.Offset');
  Check(Abs(pl.Offset(Point3(0,1,0))+1)<0.0001,'TPlane.Offset signed');

  bbA.Init;
  bbA.IncludePoint(Point3s(1,2,3));
  bbA.IncludePoint(Point3s(4,5,6));
  bbB.Init;
  bbB.IncludePoint(Point3s(3,4,5));
  bbB.IncludePoint(Point3s(8,9,10));
  bbA.IncludeBox(bbB);
  Check(bbA.ContainsPoint(Point3s(8,9,10)),'TBBox3.IncludeBox');
  Check(bbA.IntersectsBox(bbB),'TBBox3.IntersectsBox');

  // Compatibility wrappers kept while engine migration is in progress.
  d:=GetPlaneOffset(pl,Point3(0,2,0));
  Check(Abs(d)<0.0001,'GetPlaneOffset wrapper');
  InitPlane(Vector3(0,2,0),Vector3(0,1,0),pl);
  Check(Abs(GetPlaneOffset(pl,Point3(0,2,0)))<0.001,'InitPlane wrapper');

  a1[0]:=1; a1[1]:=2; a1[2]:=3;
  a2:=a1;
  Check(CompareSingle(@a1[0],@a2[0],3),'CompareSingle');
  b1[0]:=1; b1[1]:=2; b1[2]:=3;
  b2:=b1;
  Check(CompareDouble(@b1[0],@b2[0],3),'CompareDouble');

  bbA.Init;
  BBoxInclude(bbA,1,2,3);
  BBoxIncludePnt(bbA,Point3s(4,5,6));
  bbB.Init;
  BBoxInclude(bbB,3,4,5);
  BBoxIncludeBox(bbA,bbB);
  BBoxIntersect(bbA,bbB);
  Check(not bbA.IsEmpty,'BBox wrapper routines');
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
  MatrixFromYawRollPitch(m34,y0,r0,p0);
  YawRollPitchFromMatrix(m34,y1,r1,p1);
  MatrixFromYawRollPitch(m34b,y1,r1,p1);
  Check(IsEqual(m34,m34b,40),'Yaw/Roll/Pitch matrix roundtrip');

  m3s:=RotationXMat3s(0.4);
  m3sRef:=Matrix3s(Matrix4(RotationXMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationXMat3s consistency');
  m3s:=RotationYMat3s(0.4);
  m3sRef:=Matrix3s(Matrix4(RotationYMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationYMat3s consistency');
  m3s:=RotationZMat3s(0.4);
  m3sRef:=Matrix3s(Matrix4(RotationZMat(0.4)));
  Check(IsEqual(m3s,m3sRef,20),'RotationZMat3s consistency');

  a:=Point3s(0,0,0);
  b:=Point3s(1,0,0);
  c:=Point3s(0,1,0);
  o:=Point3s(0.25,0.25,1);
  tp:=Point3s(0.25,0.25,0);
  hit:=IntersectTrgLine(@a,@b,@c,@o,@tp,pb,pc,d);
  Check(hit and (d>0) and (pb>=0) and (pc>=0) and (pb+pc<=1),'IntersectTrgLine hit');

  o:=Point3s(2,2,1);
  tp:=Point3s(2,2,0);
  hit:=IntersectTrgLine(@a,@b,@c,@o,@tp,pb,pc,d);
  Check(not hit,'IntersectTrgLine miss');

  o:=Point3s(0.25,0.25,1);
  tp:=Point3s(1.25,0.25,1);
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
