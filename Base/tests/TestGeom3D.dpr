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
  b1,b2:TBBox3s;
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

begin
  TestVec3Core;
  TestVec3Normalize;
  TestMatrices;
  TestQuaternionConversions;
  TestBBox;
  writeln;
  writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
  if testsFailed>0 then begin
    halt(1);
  end;
  writeln('All OK');
end.
