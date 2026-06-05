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
  c:=a+b;
  Check((Abs(c.x+1)<0.0001) and (Abs(c.y-2)<0.0001) and (Abs(c.z-8)<0.0001),'Add operator');
  c:=a-b;
  Check((Abs(c.x-3)<0.0001) and (Abs(c.y-2)<0.0001) and (Abs(c.z+2)<0.0001),'Subtract operator');
  c:=a*2;
  Check((Abs(c.x-2)<0.0001) and (Abs(c.y-4)<0.0001) and (Abs(c.z-6)<0.0001),'Mul scalar');
  c:=2*a;
  Check((Abs(c.x-2)<0.0001) and (Abs(c.y-4)<0.0001) and (Abs(c.z-6)<0.0001),'Mul scalar (left)');
  Check(Abs(a.Distance2(b)-17)<0.0001,'Distance2 method');
  Check(Abs(a.Length-Sqrt(14))<0.0001,'Length');
  Check(Abs(a.Length2-14)<0.0001,'Length2');
  EndTest;
end;

procedure TestVec3Normalize;
var
  v:TVec3;
  raisedOnZero:boolean;
begin
  StartTest('Vec3 normalize');
  raisedOnZero:=false;
  v:=TVec3.Init(0,0,0);
  try
    v.Normalize;
  except
    raisedOnZero:=true;
  end;
  Check(raisedOnZero or (not v.IsValid),'Normalize zero');
  v:=TVec3.Init(0,3,4);
  v.Normalize;
  Check(Abs(v.Length-1)<0.0002,'Normalize non-zero');
  v:=TVec3.Init(0,0,-2);
  v.Normalize;
  Check(Abs(v.z+1)<0.0001,'Normalize precision');
  v:=TVec3.Init(0,0,-2);
  v.NormalizeFast;
  Check(Abs(v.Length-1)<0.001,'NormalizeFast approximate length');
  EndTest;
end;

procedure TestMatrices;
var
  m1,m2,m3,mInv,mRef,mT:TMat4;
  v:TVec4;
begin
  StartTest('Matrices');
  m1:=TMat4.Scale(2,3,4);
  m2:=TMat4.Translation(5,6,7);
  mRef:=m1*m2;
  m3:=m1*m2;
  Check(m3.IsEqual(mRef),'TMat4 operator *');
  Check(not m3.IsEqual(IdentMat4),'MultMat');
  mInv:=m3;
  mInv.Invert;
  m3:=m3*mInv;
  Check(m3.IsEqual(IdentMat4),'InvertFull');

  mT:=mRef.Transposed;
  mInv:=mRef;
  mInv.Transpose;
  Check(mT.IsEqual(mInv),'TMat4.Transposed');
  mRef.Transpose;
  Check(mRef.IsEqual(mInv),'TMat4.Transpose');

  v:=TVec4.Init(1,2,3,1);
  IdentMat4.TransformPoints(@v,1,SizeOf(v));
  Check((Abs(v.x-1)<0.0001) and (Abs(v.y-2)<0.0001) and (Abs(v.z-3)<0.0001),'MultPnt identity');
  EndTest;
end;

procedure TestQuaternionConversions;
var
  m,m2:TMat3;
  q:TQuat;
begin
  StartTest('Quaternion conversions');
  m:=TMat3.RotationAroundAxis(TVec3.Init(1,2,3),1.25);
  q:=m.ToQuaternion;
  m2:=TMat3.FromQuaternion(q);
  Check(m.IsEqual(m2,200),'Matrix<->Quaternion');
  Check(Abs(q.Length-1)<0.001,'Quaternion normalized');
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
  Check(Vec3(1,2,3).IsEqual(TVec3.Init(1,2,3)),'Vec3 factory');
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
  pd:=TVec3d.Init(1,2,3)+TVec3d.Init(4,5,6);
  Check((Abs(pd.x-5)<0.0001) and (Abs(pd.y-7)<0.0001) and (Abs(pd.z-9)<0.0001),'TVec3d Add operator');
  pd:=pd-TVec3d.Init(1,1,1);
  Check((Abs(pd.x-4)<0.0001) and (Abs(pd.y-6)<0.0001) and (Abs(pd.z-8)<0.0001),'TVec3d Subtract operator');
  pd:=pd*0.5;
  Check((Abs(pd.x-2)<0.0001) and (Abs(pd.y-3)<0.0001) and (Abs(pd.z-4)<0.0001),'TVec3d Mul scalar');
  pd:=2.0*pd;
  Check((Abs(pd.x-4)<0.0001) and (Abs(pd.y-6)<0.0001) and (Abs(pd.z-8)<0.0001),'TVec3d Mul scalar (left)');
  Check(not p0.IsZero,'IsZero');
  Check(TVec3.Init(1,1,1).IsIdentity,'IsIdentity vec');
  Check(IsEqual(1.0,1.0),'IsEqual scalar');

  m43:=TMat34d.Translation(1,2,3);
  m43s:=IdentMat34;
  m43s[3,0]:=1;
  m43s[3,1]:=2;
  m43s[3,2]:=3;
  Check(IdentMat34.IsIdentity,'IsIdentity mat43s');
  m3b:=TMat3.Init(IdentMat4);
  Check(m3b.IsEqual(IdentMat3),'Matrix conversion');
  Check(IdentMat3.Row(0).IsEqual(Vec3(1,0,0)),'TMat3.Row');
  Check(IdentMat3.Col(1).IsEqual(Vec3(0,1,0)),'TMat3.Col');
  Check(IdentMat3d.Row(2).IsEqual(Vec3d(0,0,1),2),'TMat3d.Row');
  Check(IdentMat3d.Col(0).IsEqual(Vec3d(1,0,0),2),'TMat3d.Col');
  Check(m43.Row(3).IsEqual(Vec3d(1,2,3),2),'TMat34d.Row');
  Check(m43.Col(2).IsEqual(Vec3d(0,0,1),2),'TMat34d.Col');
  Check(m43s.Row(3).IsEqual(Vec3(1,2,3)),'TMat34.Row');
  Check(m43s.Col(0).IsEqual(Vec3(1,0,0)),'TMat34.Col');
  m4d:=TMat4d.Init(m43);
  Check(Abs(IdentMat4.Determinant-1)<0.0001,'Det');
  m4d:=TMat4d.Init(TMat34d.Scale(2,3,4));
  m4dd:=TMat4d.Translation(1,2,3);
  m4dt:=m4d*m4dd;
  Check(m4dt.IsEqual(m4d*m4dd,20),'TMat4d operator *');
  m4dd:=m4dt.Transposed;
  Check(m4dt.Transposed.IsEqual(m4dd,20),'TMat4d.Transposed');
  m4dd:=m4dt;
  m4dd.Invert;
  m4dt:=m4dt*m4dd;
  Check(m4dt.IsEqual(IdentMat4d,20),'TMat4d.Invert full');

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
  Check(Abs(v.Dot(Vec4(1,2,3,4))-50)<0.0001,'TVec4.Dot');
  Check(Abs(Vec4(1,2,2,0).Length-3)<0.0001,'TVec4.Length');
  Check(Vec3(v).IsEqual(TVec3.Init(v.x,v.y,v.z)),'Vec4->Vec3 factory');
  Check(v.ToVec3.IsEqual(TVec3.Init(v.x,v.y,v.z)),'TVec4.ToVec3');

  m4:=TMat4.Translation(5,6,7);
  m4.Decompose(tr,rot,sca);
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
  pd:=TVec3d.Init(1,2,3);
  qdv:=Vec4d(pd);
  Check(qdv.IsEqual(TVec4d.Init(pd),2),'Vec4d default w');
  Check(qdv.IsEqual(Vec4d(1,2,3,1),2),'Vec4 double overload');
  qdv:=Vec4d(pd,2);
  Check(Abs(qdv.w-2)<0.0001,'Vec4d explicit w');
  qdv:=Vec4d(7,8,9,10);
  Check((Abs(qdv.x-7)<0.0001) and (Abs(qdv.y-8)<0.0001) and (Abs(qdv.z-9)<0.0001) and (Abs(qdv.w-10)<0.0001),'Vec4d component factory');
  v:=Vec4(qdv);
  Check((Abs(v.x-qdv.x)<0.0001) and (Abs(v.y-qdv.y)<0.0001) and (Abs(v.z-qdv.z)<0.0001) and (Abs(v.w-qdv.w)<0.0001),'Vec4 from vec4d');
  qdv:=Vec4d(v);
  Check((Abs(qdv.x-v.x)<0.0001) and (Abs(qdv.y-v.y)<0.0001) and (Abs(qdv.z-v.z)<0.0001) and (Abs(qdv.w-v.w)<0.0001),'Vec4d from vec4');
  Check(Vec3d(1,2,3).IsEqual(TVec3d.Init(1,2,3),2),'Vec3d factory');
  Check(Vec3d(qdv).IsEqual(TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'Vec4d->Vec3d factory');
  Check(qdv.ToVec3d.IsEqual(TVec3d.Init(qdv.x,qdv.y,qdv.z),2),'TVec4d.ToVec3d');
  m3d:=TMat3d.FromQuaternion(qd);
  qd:=m3d.ToQuaternion;
  Check(qd.IsValid,'TMat3d quaternion conversion');
  m4dd:=TMat4d.Translation(1,2,3);
  m4dd.Decompose(trd,rotd,scad);
  Check((Abs(trd.x-1)<0.0001) and (Abs(trd.y-2)<0.0001) and (Abs(trd.z-3)<0.0001),'DecomposeMatrix double');
  EndTest;
end;

begin
  try
    TestVec3Core;
    TestVec3Normalize;
    TestMatrices;
    TestQuaternionConversions;
    TestGeom3DUtility;
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








