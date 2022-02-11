{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestMath;
uses
  Apus.MyServis,
  SysUtils,
  Math,
  Apus.Geom2D,
  Apus.Geom3D;

 var
  time:int64;

 procedure TestMatrices;
  var
   m3:TMatrix3s;
   m4:TMAtrix4s;
   v:single;
  begin
   MatrixFromYawRollPitch(m3,1,-1,0.5);
   v:=Det(m3);
   ASSERT(IsEqual(v,1));
   writeln('Matrices OK');
  end;

 procedure TestRotationMat;
  var
   i:integer;
   m1,m2,m3:TMatrix3s;
   angle:single;
   vec:TVector3s;
  begin
   time:=MyTickCount;
{   for i:=1 to 1000000 do
    m2:=RotationAroundVector(Vector3s(0,0,1),angle);
   writeln(MyTickCount-time);}

   for i:=-20 to 30 do begin
    angle:=i/3;
    // Z
    MatrixFromYawRollPitch(m1,angle,0,0);
    m2:=RotationAroundVector(Vector3s(0,0,1),angle);
    m3:=RotationZMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
    // Y
    MatrixFromYawRollPitch(m1,0,angle,0);
    m2:=RotationAroundVector(Vector3s(0,1,0),angle);
    m3:=RotationYMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
    // X
    MatrixFromYawRollPitch(m1,0,0,angle);
    m2:=RotationAroundVector(Vector3s(1,0,0),angle);
    m3:=RotationXMat3s(angle);
    ASSERT(IsEqual(m1,m2));
    ASSERT(IsEqual(m1,m3));
   end;

   m1:=RotationAroundVector(Vector3s(1,1,1),1);
   m2:=RotationAroundVector(Vector3s(1,1,1),-1);
   MultMat(m1,m2,m3);
   ASSERT(IsEqual(m3,IdentMatrix3s));

   for i:=1 to 100 do begin
    vec:=Vector3s(random-random,random-random,random-random);
    m1:=RotationAroundVector(vec,2*Pi);
    ASSERT(IsEqual(m1,IdentMatrix3s));
    m1:=RotationAroundVector(vec,-2*Pi);
    ASSERT(IsEqual(m1,IdentMatrix3s));
   end;

   writeln('RotationMat OK');
  end;

 procedure TestQuaternions;
  begin
  end;

 procedure TestQuaternionConversions;
  var
   q,q1,q2,q3:TQuaternionS;
   mat:TMatrix4s;
   m3,mm3,m:TMatrix3s;
   i:integer;
   vec:TVector3s;
   a:single;
  begin
   m3:=RotationZMat3s(0.1);
   q:=MatrixToQuaternion(m3);
   ASSERT(IsEqual(q.Length,1));

   // Single test
   vec:=Vector3s(0.26242, -0.36225, 0.62695);
   a:=2.8916;
   m3:=RotationAroundVector(vec,a);
   q:=MatrixToQuaternion(m3);
   ASSERT(IsEqual(q.Length,1));
   QuaternionToMatrix(q,mm3);
   ASSERT(IsEqual(m3,mm3,150),Format('Fail: vec=(%.6f,%.6f,%.6f) angle=%.6f',[vec.x,vec.y,vec.z,a]));

   // Repeat
   for i:=1 to 1000 do begin
    vec:=Vector3s(random-random,random-random,random-random);
    a:=5*(random-random);
    m3:=RotationAroundVector(vec,a);
    q:=MatrixToQuaternion(m3);
    ASSERT(IsEqual(q.Length,1));
    QuaternionToMatrix(q,mm3);
    if not IsEqual(m3,mm3,150) then
     IsEqual(m3,mm3,150);
    ASSERT(IsEqual(m3,mm3,150),Format('Fail: vec=(%.7f,%.7f,%.7f) angle=%.7f',[vec.x,vec.y,vec.z,a]));
   end;

   mat:=ScaleMat4s(1.5, 1.7, 1.9);
   mat:=MultMat(mat,RotationZMat4s(0.1));
   mat:=MultMat(mat,TranslationMat4s(2,2.5,3));
   DecomposeMartix(mat,q1,q2,q3);
   ASSERT(IsEqual(q1.xyz,Vector3s(2,2.5,3)));
   ASSERT(IsEqual(q3.xyz,Vector3s(1.5, 1.7, 1.9)));
   ASSERT(IsEqual(q2,QuaternionS(0,0,0.04998,0.99875)));
   ASSERT(IsEqual(q2.Length,1));

   writeln('Quaternion conversions OK');
  end;

begin
 try
  TestMatrices;
  TestRotationMat;
  TestQuaternions;
  TestQuaternionConversions;
  writeln('All OK');
 except
  on e:Exception do begin
   writeln('Error: ',ExceptionMsg(e));
   halt(255);
  end;
 end;
 if HasParam('wait') then readln;
end.
