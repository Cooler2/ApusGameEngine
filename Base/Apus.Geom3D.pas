// -----------------------------------------------------
// 3D geometry common high-precision functions
// Author: Ivan Polyacov (C) 2003, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// ------------------------------------------------------
//
// Unlike OpenGL, this unit assume matrices are row-major.
// However, their in-memory layout is identical to what OpenGL or DirectX use.
// This means that:
// - vector transformation is v*M (not M*v)
// - multiple transformation is v*M1*M2*..*Mn, so combined transformation is M1*M2*..*Mn (not Mn*...*M1)
//   in particular, MVP matrix is Model*View*Projection
// Since OpenGL assume column-major matrices, only notional (imaginable) transpose occurs when matrix is
// uploaded, so no real transpose/data modification. The same binary data is just used differently in the GLSL shaders.
{$IFDEF FPC}{$PIC OFF}{$ENDIF}
{$EXCESSPRECISION OFF}
unit Apus.Geom3D;
interface
 uses Apus.Geom2D;
 type
  TVec3d=packed record
   x,y,z:double;
   constructor Init(X,Y,Z:double); overload;
   constructor Init(p0,p1:TVec3d;t:double); overload;
   procedure Normalize;
   function IsValid:boolean;
   function Length:double; inline;
   function Length2:double; inline;
   function Dot(const p:TVec3d):double; inline;
   function Cross(const p:TVec3d):TVec3d; inline;
   function Sub(const p:TVec3d):TVec3d; inline;
   function Distance2(const p:TVec3d):double; inline;
   function MaxDelta(const p:TVec3d):double; inline;
   procedure Add(const p:TVec3d);
   procedure Multiply(scalar:double);
  end;
  PVec3d=^TVec3d;
  TVec3=packed record
   constructor Init(X,Y,Z:single); overload;
   constructor Init(p:TVec3d); overload;
   constructor Init(p0,p1:TVec3;t:single); overload;
   constructor Init(p0:TVec3;weight0:single;p1:TVec3;weight1:single); overload;
   procedure Normalize;
   function IsValid:boolean;
   function Length:single;  // Vector length
   function Length2:single; // Square length
   function Dot(const p:TVec3):single; inline;
   function Cross(const p:TVec3):TVec3; inline;
   function Sub(const p:TVec3):TVec3; inline;
   function Distance2(const p:TVec3):single; inline;
   function MaxDelta(const p:TVec3):single; inline;
   procedure Add(const p:TVec3);
   procedure Multiply(scalar:single);
   case integer of
   0:( x,y,z:single; );
   1:( v:array[0..2] of single; );
   2:( xy:TVec2; t:single; );
  end;
  TVec3Array=array of TVec3;

  TQuatd=record
   constructor Init(x,y,z,w:double);
   procedure Add(const q:TQuatd); overload;
   procedure Add(const q:TQuatd;scale:double); overload;
   procedure Mul(scalar:double); overload;
   procedure Mul(const q:TQuatd); overload;
   function Dot(const q:TQuatd):double;
   function Length:double;
   function Length2:double;
   procedure Normalize;
   function IsValid:boolean;
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
    3:( xyz:TVec3d; t:double; );
  end;

  { TQuat }

  TQuat=record
   constructor Init(x,y,z,w:single); overload;
   constructor Init(vec3:TVec3); overload;
   constructor Init(q:TQuatd); overload;
   procedure Assign(const q:TQuat);
   procedure Add(const q:TQuat); overload;
   procedure Add(const q:TQuat;scale:single); overload;
   procedure Middle(const q:TQuat;weight:single);  // interpolate between current value and Q
   procedure Sub(const q:TQuat); overload;
   procedure Mul(scalar:single); overload;
   procedure Mul(const q:TQuat); overload;
   function Dot(const q:TQuat):single;
   function Length:single;
   function Length2:single; // Square length
   procedure Normalize;
   function IsValid:boolean;
   case integer of
    1:( x,y,z,w:single; );
    2:( v:array[0..3] of single; );
    3:( xyz:TVec3; t:single; );
  end;

  TVec4=TQuat;
  PVec4=^TVec4;

  // Infinite plane in space
  TPlane=packed record
   a,b,c,d:double;
   class function Init(const point,normal:TVec3d):TPlane; static;
   function DistanceTo(const pnt:TVec3d):double; overload; inline;
   function DistanceTo(const pnt:TVec3):single; overload; inline;
  end;
  PVec3=^TVec3;
  // Infinite oriented line in space
  TLine3=packed record
   origin:TVec3d;
   dir:TVec3d;
  end;

  // Transformation matrices
  PMatrix3=^TMat3d;
  TMat3d=array[0..2,0..2] of double; // Rotation/scale
  PMatrix43=^TMat34d;
  TMat34d=array[0..3,0..2] of double; // rotation/scale/translation
  PMatrix4=^TMat4d;
  TMat4d=array[0..3,0..3] of double; // rotation/scale/translation
  PMat4=^TMat4;
  TMat4=array[0..3,0..3] of single; // rotation/scale/translation
  // Synonims
  TMatrix3vd=array[0..2] of TVec3d;
  TMatrix43vd=array[0..3] of TVec3d;

  // Low precision matrices
  PMat3=^TMat3;
  TMat3=array[0..2,0..2] of single;
  PMat34=^TMat34;
  TMat34=array[0..3,0..2] of single;
  // Synonims
  TMatrix3v=array[0..2] of TVec3;
  TMatrix43v=array[0..3] of TVec3;

 const
  NaN=0.0/0.0;
  IdentMat3d:TMat3d=((1,0,0),(0,1,0),(0,0,1));
  IdentMat3:TMat3=((1,0,0),(0,1,0),(0,0,1));
  IdentMat34d:TMat34d=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMat34:TMat34=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMat4d:TMat4d=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));
  IdentMat4:TMat4=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));

  NullPoint:TVec3d=(x:0;y:0;z:0);
  NullVec3:TVec3=(x:0;y:0;z:0);
  InvalidPoint3:TVec3d=(x:NaN;y:NaN;z:NaN);
  InvalidVec3:TVec3=(x:NaN;y:NaN;z:NaN);

 function Point3(p:TVec3):TVec3d; overload; inline;
 function Direction3(from,target:TVec3d):TVec3d; overload; inline;
 function Vec4(vector:TVec3d):TQuatd; overload; inline;
 function Vec4(vector:TVec3):TVec4; overload; inline;
 // Matrix conversion
 function Matrix4(from:TMat34d):TMat4d; overload;
 function Matrix4(from:TMat4):TMat4d; overload;
 function ToMat4(from:TMat34):TMat4; overload;
 function ToMat4(from:TMat4d):TMat4; overload;
 function Matrix3(from:TMat4d):TMat3d; overload;
 function ToMat3(from:TMat3d):TMat3; overload;
 function ToMat3(from:TMat4d):TMat3; overload;
 function ToMat3(from:TMat4):TMat3; overload;

 // Extract matrix row/column
 function MatRow(const mat:TMat4; n:integer):TQuat; overload; inline;
 function MatRow(const mat:TMat4d;  n:integer):TQuatd;  overload; inline;
 function MatRow(const mat:TMat34;n:integer):TVec3; overload; inline;
 function MatRow(const mat:TMat3; n:integer):TVec3; overload; inline;
 function MatCol(const mat:TMat4; n:integer):TQuat; overload;
 function MatCol(const mat:TMat4d;  n:integer):TQuatd; overload;
 function MatCol(const mat:TMat34;n:integer):TVec3; overload;
 function MatCol(const mat:TMat3; n:integer):TVec3; overload;

 // Скалярное произведение векторов = произведение длин на косинус угла = проекция одного вектора на другой
 // Векторное произведение: модуль равен площади ромба
 // Compare with tolerance
 function IsZero(v:TVec3d):boolean; overload; inline;
 function IsZero(v:TVec3):boolean; overload; inline;
 function IsIdentity(v:TVec3):boolean; overload; inline;
 function IsIdentity(m:TMat34d):boolean; overload;
 function IsIdentity(m:TMat34):boolean; overload;

 function IsEqual(d1,d2:double):boolean; overload; inline;
 function IsEqual(s1,s2:single):boolean; overload; inline;

 function IsEqual(v1,v2:TVec3;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TVec4;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TVec3d;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TQuatd;precision:single=2.0):boolean; overload; inline;

 function IsEqual(m1,m2:TMat4d;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMat4;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMat34d;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMat3d;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMat3;precision:single=4.0):boolean; overload; inline;

 function CompareSingle(s1,s2:PSingle;count:integer;precision:single=1.0):boolean;
 function CompareDouble(s1,s2:PDouble;count:integer;precision:single=1.0):boolean;

 // Convert matrix to single precision
 procedure ToSingle43(sour:TMat34d;out dest:TMat34);

 function TranslationMat(x,y,z:double):TMat34d;
 function TranslationMat4d(x,y,z:double):TMat4d;
 function TranslationMat4(x,y,z:single):TMat4;
 function RotationXMat(angle:double):TMat34d;
 function RotationYMat(angle:double):TMat34d;
 function RotationZMat(angle:double):TMat34d;
 function RotationMat3X(angle:single):TMat3;
 function RotationMat3Y(angle:single):TMat3;
 function RotationMat3Z(angle:single):TMat3;
 function RotationMat4X(angle:single):TMat4;
 function RotationMat4Y(angle:single):TMat4;
 function RotationMat4Z(angle:single):TMat4;
 function ScaleMat(scaleX,scaleY,scaleZ:double):TMat34d;
 function ScaleMat4(scaleX,scaleY,scaleZ:single):TMat4;

 // Матрица поворота вокруг вектора единичной длины!
 function RotationAroundVector(v:TVec3d;angle:double):TMat3d; overload;
 function RotationAroundVector(v:TVec3;angle:single):TMat3; overload;

 // Build rotation matrix from a NORMALIZED quaternion
 procedure MatrixFromQuaternion(const q:TQuatd;out mat:TMat3d); overload;
 procedure MatrixFromQuaternion(const q:TQuat;out mat:TMat3); overload;
 procedure MatrixFromQuaternion(const q:TQuat;out mat:TMat4); overload;
 procedure QuaternionToMatrix(const q:TQuatd;out mat:TMat3d); overload; inline; // alias
 procedure QuaternionToMatrix(const q:TQuat;out mat:TMat3); overload; inline; // alias

 // Convert an ORTHOGONAL matrix to quaternion
 function MatrixToQuaternion(const mat:TMat3):TQuat; overload;
 function MatrixToQuaternion(const mat:TMat3d):TQuatd; overload;

 // Extract translation rotation and scale from transformation matrix
 procedure DecomposeMatrix(mat:TMat4;out translation,rotation,scale:TQuat); overload;
 procedure DecomposeMatrix(mat:TMat4d;out translation,rotation,scale:TQuatd); overload;

 // Quaternion operations
 function QuatLength(q:TQuatd):double; overload;
 function QuatLength(q:TQuat):single; overload;

 procedure QuatScale(var q:TQuatd;val:double); overload;
 procedure QuatScale(var q:TQuat;val:single); overload;

 procedure QuatNormalize(var q:TQuatd); overload;
 procedure QuatNormalize(var q:TQuat); overload;

 function QuatInvert(q:TQuatd):TQuatd; overload;
 function QuatInvert(q:TQuat):TQuat; overload;

 function QuatMultiply(q1,q2:TQuatd):TQuatd; overload;
 function QuatMultiply(q1,q2:TQuat):TQuat; overload;

 // SLERP (!??) linear interpolation from Q1 to Q2 with factor changing from 0 to 1 (factor=0 -> Q1; factor=1 -> Q2)
 function QuatSlerp(Q1,Q2:TQuat;factor:single):TQuat;


 // Используется правосторонняя СК, ось Z - вверх.
 // roll - поворот вокруг X
 // pitch - затем поворот вокруг Y
 // yaw - наконец, поворот вокруг Z
 procedure YRPToMatrix(out mat:TMat3d;yaw,roll,pitch:double); overload;
 procedure YRPToMatrix(out mat:TMat3;yaw,roll,pitch:double); overload;
 procedure YRPToMatrix(out mat:TMat4d;yaw,roll,pitch:double); overload;
 procedure YRPToMatrix(out mat:TMat4;yaw,roll,pitch:double); overload;
 procedure YRPToMatrix(out mat:TMat34d;yaw,roll,pitch:double); overload;
 procedure YRPToMatrix(out mat:TMat34;yaw,roll,pitch:double); overload;

 procedure MatrixToYRP(const mat:TMat34d; var yaw,roll,pitch:double);

 // Combined transformation M = M3*M2*M1 means do M1 then M2 and finally M3
 // target = M1*M2 (Смысл: перевести репер M1 из системы M2 в ту, где задана M2)
 // Другой смысл: суммарная трансформация: сперва M2, затем M1 (именно так!)
 // IMPORTANT! target MUST DIFFER from m1 and m2!
 procedure MultMat(const m1,m2:TMat3d;out target:TMat3d); overload;
 procedure MultMat(const m1,m2:TMat3;out target:TMat3); overload;
 procedure MultMat(const m1,m2:TMat34d;out target:TMat34d); overload;
 procedure MultMat(const m1,m2:TMat34;out target:TMat34); overload;
 procedure MultMat(const m1,m2:TMat4d;out target:TMat4d); overload;
 procedure MultMat(const m1,m2:TMat4;out target:TMat4); overload;
 function  MultMat(const m1,m2:TMat34d):TMat34d; overload;
 function  MultMat(const m1,m2:TMat4d):TMat4d; overload;
 function  MultMat(const m1,m2:TMat4):TMat4; overload;

 procedure MultPnt(const m:TMat4;v:PVec4;num,step:integer); overload;
 procedure MultPnt(const m:TMat34d;v:PVec3d;num,step:integer); overload;
 procedure MultPnt(const m:TMat34;v:PVec3;num,step:integer); overload;
 procedure MultPnt(const m:TMat3d;v:PVec3d;num,step:integer); overload;
 procedure MultPnt(const m:TMat3;v:PVec3;num,step:integer); overload;
 // Same as MultPnt, but ignores the translation part
 procedure MultNormal(const m:TMat4;v:PVec4;num,step:integer);

 // Complete 3D transformation (with normalization)
 function TransformPoint(const m:TMat4;v:PVec3):TVec3; overload;
 function TransformPoint(const m:TMat4d;v:PVec3d):TVec3d; overload;

 // Transpose (для ортонормированной матрицы - это будт обратная)
 procedure Transpose(const m:TMat3d;out dest:TMat3d); overload;
 procedure Transpose(const m:TMat3;out dest:TMat3); overload;
 procedure Transpose(const m:TMat34d;out dest:TMat34d); overload;
 procedure Transpose(const m:TMat34;out dest:TMat34); overload;
 procedure Transpose(const m:TMat4d;out dest:TMat4d); overload;
 procedure Transpose(var m:TMat4d); overload;
 procedure Transpose(var m:TMat4); overload;
 procedure Transpose(var m:TMat3d); overload;
 procedure Transpose(var m:TMat3); overload;

 // Calculate inverted matrix (for Orthogonal atrix only!)
 procedure Invert(const m:TMat3d;out dest:TMat3d); overload;
 procedure Invert(const m:TMat34d;out dest:TMat34d); overload;
 procedure Invert(const m:TMat34;out dest:TMat34); overload;
 // Complete inversion using Gauss method
 procedure InvertFull(const m:TMat4d;out dest:TMat4d); overload;
 procedure InvertFull(const m:TMat4;out dest:TMat4); overload;

 function Det(const m:TMat3d):double; overload;
 function Det(const m:TMat3):single; overload;
 function Det(const m:TMat4d):double; overload;
 function Det(const m:TMat4):single; overload;

 // Special
 // пересечение треугольника ABC с лучом OT
 // возвращает: pb,pc - выражение точки пересечения через вектора AB и AC (pb,pc>=0, pb+pc<=1)
 //             d - расстояние от точки пересечения до начала луча
 function IntersectTrgLine(A,B,C,O,T:PVec3;var pb,pc,d:double):boolean;

implementation
 uses Apus.Core, Apus.CPU, Apus.Types, SysUtils, Math;

 const
  vec0001s:TVec4=(x:0; y:0; z:0; w:1);

  // Compensation for stack frame allocation in x64 mode
  RSP_BIAS = {$IFDEF FPC} 0 {$ELSE} 8 {$ENDIF};

 function Point3(p:TVec3):TVec3d; overload; inline;
  begin
   result.x:=p.x;
   result.y:=p.y;
   result.z:=p.z;
  end;

 function Direction3(from,target:TVec3d):TVec3d; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vec4(vector:TVec3d):TQuatd; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Vec4(vector:TVec3):TVec4; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Matrix4(from:TMat34d):TMat4d;
  var
   i:integer;
  begin
   for i:=0 to 3 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
    result[i,3]:=0;
   end;
   result[3,3]:=1;
  end;

 function ToMat4(from:TMat34):TMat4;
  var
   i:integer;
  begin
   for i:=0 to 3 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
    result[i,3]:=0;
   end;
   result[3,3]:=1;
  end;

 function ToMat4(from:TMat4d):TMat4;
  var
   i:integer;
  begin
   for i:=0 to 3 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
    result[i,3]:=from[i,3];
   end;
  end;

 function Matrix4(from:TMat4):TMat4d;
  var
   i:integer;
  begin
   for i:=0 to 3 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
    result[i,3]:=from[i,3];
   end;
  end;

 function Matrix3(from:TMat4d):TMat3d; overload;
  begin
   move(from[0],result[0],sizeof(result[0]));
   move(from[1],result[1],sizeof(result[1]));
   move(from[2],result[2],sizeof(result[2]));
  end;

 function ToMat3(from:TMat4):TMat3; overload;
  begin
   move(from[0],result[0],sizeof(result[0]));
   move(from[1],result[1],sizeof(result[1]));
   move(from[2],result[2],sizeof(result[2]));
  end;

 function ToMat3(from:TMat3d):TMat3; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function ToMat3(from:TMat4d):TMat3; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function MatRow(const mat:TMat4; n:integer):TQuat;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMat4d; n:integer):TQuatd;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMat34;n:integer):TVec3;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMat3; n:integer):TVec3;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatCol(const mat:TMat4; n:integer):TQuat;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
   result.w:=mat[3,n];
  end;

 function MatCol(const mat:TMat4d; n:integer):TQuatd;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
   result.w:=mat[3,n];
  end;

 function MatCol(const mat:TMat34;n:integer):TVec3;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
  end;

 function MatCol(const mat:TMat3; n:integer):TVec3;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
  end;

 function IsZero(v:TVec3d):boolean; overload;
  begin
   result:=(abs(v.x)<=Epsilon) and (abs(v.y)<=Epsilon) and (abs(v.z)<=Epsilon);
  end;
 function IsZero(v:TVec3):boolean; overload;
  begin
   result:=(abs(v.x)<=EpsilonS) and (abs(v.y)<=EpsilonS) and (abs(v.z)<=EpsilonS);
  end;

 function IsIdentity(v:TVec3):boolean; inline;
  begin
   result:=((abs(v.x-1.0)<EpsilonS) and (abs(v.y-1.0)<EpsilonS) and (abs(v.z-1.0)<EpsilonS));
  end;

 function IsIdentity(m:TMat34d):boolean; overload;
  var
   i,j:integer;
  begin
   result:=true;
   for i:=0 to 3 do
    for j:=0 to 2 do
     if abs(m[i,j]-byte(i=j))>Epsilon then begin
      result:=false; exit;
     end;
  end;
 function IsIdentity(m:TMat34):boolean; overload;
  var
   i,j:integer;
  begin
   result:=true;
   for i:=0 to 3 do
    for j:=0 to 2 do
     if abs(m[i,j]-byte(i=j))>EpsilonS then begin
      result:=false; exit;
     end;
  end;

 function IsEqual(d1,d2:double):boolean; overload;
  begin
    result:=CompareDouble(@d1,@d2,1);
  end;

 function IsEqual(s1,s2:single):boolean; overload;
  begin
    result:=CompareSingle(@s1,@s2,1);
  end;

 function IsEqual(v1,v2:TVec3;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareSingle(@v1,@v2,3,precision);
  end;

 function IsEqual(v1,v2:TVec4;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareSingle(@v1,@v2,4,precision);
  end;

 function IsEqual(v1,v2:TVec3d;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareDouble(@v1,@v2,3,precision);
  end;

 function IsEqual(v1,v2:TQuatd;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareDouble(@v1,@v2,4,precision);
  end;

 function IsEqual(m1,m2:TMat4d;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,16,precision);
  end;

 function IsEqual(m1,m2:TMat4;precision:single=4.0):boolean; overload;
  begin
    result:=CompareSingle(@m1,@m2,16,precision);
  end;

 function IsEqual(m1,m2:TMat34d;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,12,precision);
  end;

 function IsEqual(m1,m2:TMat3d;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,9,precision);
  end;

 function IsEqual(m1,m2:TMat3;precision:single=4.0):boolean; overload;
  begin
    result:=CompareSingle(@m1,@m2,9,precision);
  end;

 function CompareSingle(s1,s2:PSingle;count:integer;precision:single):boolean;
  var
   threshold:single;
  begin
   result:=true;
   threshold:=EpsilonS*precision;
   repeat
    if abs(s1^-s2^)>threshold then exit(false);
    if count=1 then break;
    dec(count);
    inc(s1); inc(s2);
   until false
  end;

 function CompareDouble(s1,s2:PDouble;count:integer;precision:single):boolean;
  var
   threshold:double;
  begin
   result:=true;
   threshold:=Epsilon*precision;
   repeat
    if abs(s1^-s2^)>threshold then exit(false);
    if count=1 then break;
    dec(count);
    inc(s1); inc(s2);
   until false
  end;

 // Matrix routines
 procedure ToSingle43;
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 2 do
     dest[i,j]:=sour[i,j];
  end;

 procedure MultMat(const m1,m2:TMat3d;out target:TMat3d);
  begin
   target[0,0]:=m1[0,0]*m2[0,0] + m1[0,1]*m2[1,0] + m1[0,2]*m2[2,0];
   target[0,1]:=m1[0,0]*m2[0,1] + m1[0,1]*m2[1,1] + m1[0,2]*m2[2,1];
   target[0,2]:=m1[0,0]*m2[0,2] + m1[0,1]*m2[1,2] + m1[0,2]*m2[2,2];

   target[1,0]:=m1[1,0]*m2[0,0] + m1[1,1]*m2[1,0] + m1[1,2]*m2[2,0];
   target[1,1]:=m1[1,0]*m2[0,1] + m1[1,1]*m2[1,1] + m1[1,2]*m2[2,1];
   target[1,2]:=m1[1,0]*m2[0,2] + m1[1,1]*m2[1,2] + m1[1,2]*m2[2,2];

   target[2,0]:=m1[2,0]*m2[0,0] + m1[2,1]*m2[1,0] + m1[2,2]*m2[2,0];
   target[2,1]:=m1[2,0]*m2[0,1] + m1[2,1]*m2[1,1] + m1[2,2]*m2[2,1];
   target[2,2]:=m1[2,0]*m2[0,2] + m1[2,1]*m2[1,2] + m1[2,2]*m2[2,2];
  end;

 procedure MultMat(const m1,m2:TMat3;out target:TMat3);
  begin
   target[0,0]:=m1[0,0]*m2[0,0] + m1[0,1]*m2[1,0] + m1[0,2]*m2[2,0];
   target[0,1]:=m1[0,0]*m2[0,1] + m1[0,1]*m2[1,1] + m1[0,2]*m2[2,1];
   target[0,2]:=m1[0,0]*m2[0,2] + m1[0,1]*m2[1,2] + m1[0,2]*m2[2,2];

   target[1,0]:=m1[1,0]*m2[0,0] + m1[1,1]*m2[1,0] + m1[1,2]*m2[2,0];
   target[1,1]:=m1[1,0]*m2[0,1] + m1[1,1]*m2[1,1] + m1[1,2]*m2[2,1];
   target[1,2]:=m1[1,0]*m2[0,2] + m1[1,1]*m2[1,2] + m1[1,2]*m2[2,2];

   target[2,0]:=m1[2,0]*m2[0,0] + m1[2,1]*m2[1,0] + m1[2,2]*m2[2,0];
   target[2,1]:=m1[2,0]*m2[0,1] + m1[2,1]*m2[1,1] + m1[2,2]*m2[2,1];
   target[2,2]:=m1[2,0]*m2[0,2] + m1[2,1]*m2[1,2] + m1[2,2]*m2[2,2];
  end;

 procedure MultMat(const m1,m2:TMat34d;out target:TMat34d);
  var
   am1:TMat3d absolute m1;
   am2:TMat3d absolute m2;
   am3:TMat3d absolute target;
  begin
   MultMat(am1,am2,am3);
   target[3,0]:=m1[3,0]*m2[0,0] + m1[3,1]*m2[1,0] + m1[3,2]*m2[2,0] + m2[3,0];
   target[3,1]:=m1[3,0]*m2[0,1] + m1[3,1]*m2[1,1] + m1[3,2]*m2[2,1] + m2[3,1];
   target[3,2]:=m1[3,0]*m2[0,2] + m1[3,1]*m2[1,2] + m1[3,2]*m2[2,2] + m2[3,2];
  end;

 procedure MultMat(const m1,m2:TMat4d;out target:TMat4d);
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;

 procedure MultMat(const m1,m2:TMat4;out target:TMat4);
  {$IFDEF CPUx64}
  asm
   // save xmm6-7
   movdqa [rsp-$10-RSP_BIAS],xmm6
   movdqa [rsp-$20-RSP_BIAS],xmm7

   // Load matrix M2
   movaps xmm4,dqword [m2+$00]
   movaps xmm5,dqword [m2+$10]
   movaps xmm6,dqword [m2+$20]
   movaps xmm7,dqword [m2+$30]

   mov eax,4
@loop:
   movaps xmm0,dqword [m1]
   movaps xmm1,xmm0
   movaps xmm2,xmm0
   movaps xmm3,xmm0
   shufps xmm0,xmm0, $00  // a0
   shufps xmm1,xmm1, $55  // a1
   shufps xmm2,xmm2, $AA  // a2
   shufps xmm3,xmm3, $FF  // a3

   mulps xmm0,xmm4 // a0*X
   mulps xmm1,xmm5 // a1*Y
   mulps xmm2,xmm6 // a2*Z
   mulps xmm3,xmm7 // a3*T
   addps xmm0,xmm1
   addps xmm2,xmm3
   addps xmm0,xmm2
   movups dqword [target],xmm0

   add m1,$10
   add target,$10
   dec eax
   jnz @loop

   // restore xmm6-7
   movdqa xmm6,[rsp-$10-RSP_BIAS]
   movdqa xmm7,[rsp-$20-RSP_BIAS]
  end;
  {$ELSE}
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;
  {$ENDIF}

 function MultMat(const m1,m2:TMat34d):TMat34d; overload;
  begin
   MultMat(m1,m2,result);
  end;

 function MultMat(const m1,m2:TMat4d):TMat4d; overload;
  begin
   MultMat(m1,m2,result);
  end;

 function MultMat(const m1,m2:TMat4):TMat4; overload;
  begin
   MultMat(m1,m2,result);
  end;


 procedure MultMat(const m1,m2:TMat34;out target:TMat34);
  var
   am1:TMat3 absolute m1;
   am2:TMat3 absolute m2;
   am3:TMat3 absolute target;
  begin
   MultMat(am1,am2,am3);
   target[3,0]:=m1[3,0]*m2[0,0] + m1[3,1]*m2[1,0] + m1[3,2]*m2[2,0] + m2[3,0];
   target[3,1]:=m1[3,0]*m2[0,1] + m1[3,1]*m2[1,1] + m1[3,2]*m2[2,1] + m2[3,1];
   target[3,2]:=m1[3,0]*m2[0,2] + m1[3,1]*m2[1,2] + m1[3,2]*m2[2,2] + m2[3,2];
  end;

 procedure Transpose(const m:TMat3d;out dest:TMat3d);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transpose(const m:TMat3;out dest:TMat3);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transpose(const m:TMat34d;out dest:TMat34d);
  var
   m1:TMat3d absolute m;
   m2:TMat3d absolute dest;
   mv:TMatrix43vd absolute m;
  begin
   Transpose(m1,m2);
   dest[3,0]:=-mv[0].Dot(mv[3]);
   dest[3,1]:=-mv[1].Dot(mv[3]);
   dest[3,2]:=-mv[2].Dot(mv[3]);
  end;
 procedure Transpose(const m:TMat34;out dest:TMat34);
  var
   m1:TMat3 absolute m;
   m2:TMat3 absolute dest;
   mv:TMatrix43v absolute m;
  begin
   Transpose(m1,m2);
   dest[3,0]:=-mv[0].Dot(mv[3]);
   dest[3,1]:=-mv[1].Dot(mv[3]);
   dest[3,2]:=-mv[2].Dot(mv[3]);
  end;
 procedure Transpose(const m:TMat4d;out dest:TMat4d);
  var
   i:integer;
  begin
   for i:=0 to 3 do begin
    dest[i,0]:=m[0,i];
    dest[i,1]:=m[1,i];
    dest[i,2]:=m[2,i];
    dest[i,3]:=m[3,i];
   end;
  end;

 procedure Transpose(var m:TMat4d);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
   Swap(m[3,0],m[0,3]);
   Swap(m[3,1],m[1,3]);
   Swap(m[3,2],m[2,3]);
  end;

 procedure Transpose(var m:TMat4);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
   Swap(m[3,0],m[0,3]);
   Swap(m[3,1],m[1,3]);
   Swap(m[3,2],m[2,3]);
  end;

 procedure Transpose(var m:TMat3d);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
  end;

 procedure Transpose(var m:TMat3);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
  end;

 procedure Invert(const m:TMat3d;out dest:TMat3d);
  var
   la,lb,lc:double;
   mv:TMatrix3vd absolute m;
  begin
   la:=mv[0].Length2;
   lb:=mv[1].Length2;
   lc:=mv[2].Length2;
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transpose(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;
  end;

 procedure Invert(const m:TMat34d;out dest:TMat34d); overload;
  var
   la,lb,lc:double;
   mv:TMatrix43vd absolute m;
  begin
   la:=mv[0].Length2;
   lb:=mv[1].Length2;
   lc:=mv[2].Length2;
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transpose(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;   dest[3,0]:=dest[3,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;   dest[3,1]:=dest[3,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;   dest[3,2]:=dest[3,2]/lc;
  end;

 procedure Invert(const m:TMat34;out dest:TMat34); overload;
  var
   la,lb,lc:single;
   mv:TMatrix43v absolute m;
  begin
   la:=mv[0].Length2;
   lb:=mv[1].Length2;
   lc:=mv[2].Length2;
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transpose(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;   dest[3,0]:=dest[3,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;   dest[3,1]:=dest[3,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;   dest[3,2]:=dest[3,2]/lc;
  end;


 procedure InvertFull(const m:TMat4d;out dest:TMat4d);
  var
   mat:TMat4d;
   i,k:integer;
   v:double;
  procedure AddRow(src,target:integer;factor:double);
   var
    i:integer;
   begin
    for i:=0 to 3 do begin
     mat[target,i]:=mat[target,i]+factor*mat[src,i];
     dest[target,i]:=dest[target,i]+factor*dest[src,i];
    end;
   end;
  procedure MultRow(row:integer;factor:double);
   var
    i:integer;
   begin
    for i:=0 to 3 do begin
     mat[row,i]:=mat[row,i]*factor;
     dest[row,i]:=dest[row,i]*factor;
    end;
   end;
  begin
   mat:=m;
   dest:=IdentMat4d;
   for i:=0 to 3 do begin
     v:=mat[i,i];
     if abs(v)<EpsilonS then begin
      for k:=i+1 to 3 do
       if abs(mat[k,i])>EpsilonS then begin
        AddRow(k,i,1);
        break;
       end;
      v:=mat[i,i];
      if v=0 then raise Exception.Create('Cannot invert matrix!');
     end;
     MultRow(i,1/v);
     for k:=i+1 to 3 do
      AddRow(i,k,-mat[k,i]);
    end;
   for i:=3 downto 1 do
    for k:=i-1 downto 0 do
     AddRow(i,k,-mat[k,i]);
  end;

 procedure InvertFull(const m:TMat4;out dest:TMat4);
  var
   mat:TMat4;
   i,k:integer;
   v:single;
  begin
   mat:=m;
   dest:=IdentMat4;
   for i:=0 to 3 do begin
     v:=mat[i,i];
     if abs(v)<EpsilonS then begin // fix zero diagonal element
      for k:=i+1 to 3 do
       if abs(mat[k,i])>EpsilonS then begin
        TVec4(dest[i]).Add(TVec4(dest[k]),1);
        TVec4(mat[i]).Add(TVec4(mat[k]),1);
        break;
       end;
      v:=mat[i,i];
      if v=0 then raise Exception.Create('Cannot invert matrix!');
     end;
     v:=1/v;
     TVec4(mat[i]).Mul(v);
     TVec4(dest[i]).Mul(v);

     for k:=i+1 to 3 do begin
      v:=-mat[k,i];
      TVec4(dest[k]).Add(TVec4(dest[i]),v);
      TVec4(mat[k]).Add(TVec4(mat[i]),v);
     end;
    end;
   for i:=3 downto 1 do
    for k:=i-1 downto 0 do
     TVec4(dest[k]).Add(TVec4(dest[i]),-mat[k,i]);
  end;

 procedure MultPnt(const m:TMat4;v:PVec4;num,step:integer); overload;
  {$IFDEF CPUx64}
  asm
   // rcx=@matrix, rdx=@vector, r8=num, @r9=step
@loop:
   movups xmm0,[rdx]
   // multiply
   movaps xmm1,xmm0
   shufps xmm1,xmm1,$00 // (x,x,x,x)
   mulps xmm1,[rcx+$00]   // xmm1=x*col[0]
   movaps xmm2,xmm0
   shufps xmm2,xmm2,$55 // (y,y,y,y)
   mulps xmm2,[rcx+$10]   // xmm2=y*col[1]
   movaps xmm3,xmm0
   shufps xmm3,xmm3,$AA // (z,z,z,z)
   mulps xmm3,[rcx+$20]   // xmm3=z*col[2]
   movaps xmm4,xmm0
   shufps xmm4,xmm4,$FF // (t,t,t,t)
   mulps xmm4,[rcx+$30]   // xmm4=t*col[3]

   addps xmm1,xmm2
   addps xmm3,xmm4
   addps xmm1,xmm3
   movups [rdx],xmm1

   dec r8
   jz @exit
   add rdx,r9
   jmp @loop
@exit:
  end;
  {$ELSE}
  var
   i:integer;
   vec:TVec4;
  begin
   for i:=1 to num do begin
    vec.x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+v.w*m[3,0];
    vec.y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+v.w*m[3,1];
    vec.z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+v.w*m[3,2];
    vec.w:=v^.x*m[0,3]+v^.y*m[1,3]+v^.z*m[2,3]+v.w*m[3,3];

    v^:=vec;
    v:=PVec4(PtrUInt(v)+step);
   end;
  end;
  {$ENDIF}

 // Ignore translation part
 procedure MultNormal(const m:TMat4;v:PVec4;num,step:integer);
 {$IFDEF CPUx64}
  asm
   // rcx=@matrix, rdx=@vector, r8=num, @r9=step
@loop:
   movups xmm0,[rdx]
   // multiply
   movaps xmm1,xmm0
   shufps xmm1,xmm1,$00 // (x,x,x,x)
   mulps xmm1,[rcx+$00]   // xmm1=x*col[0]
   movaps xmm2,xmm0
   shufps xmm2,xmm2,$55 // (y,y,y,y)
   mulps xmm2,[rcx+$10]   // xmm2=y*col[1]
   movaps xmm3,xmm0
   shufps xmm3,xmm3,$AA // (z,z,z,z)
   mulps xmm3,[rcx+$20]   // xmm3=z*col[2]

   addps xmm1,xmm2
   addps xmm1,xmm3
   movups [rdx],xmm1

   dec r8
   jz @exit
   add rdx,r9
   jmp @loop
@exit:
  end;
  {$ELSE}
  var
   i:integer;
   vec:TVec4;
  begin
   for i:=1 to num do begin
    vec.x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    vec.y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    vec.z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    vec.w:=1.0;

    v^:=vec;
    v:=PVec4(PtrUInt(v)+step);
   end;
  end;
  {$ENDIF}


 procedure MultPnt(const m:TMat34d;v:PVec3d;num,step:integer);
  var
   i:integer;
   x,y,z:double;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+m[3,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+m[3,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+m[3,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PVec3d(PtrUInt(v)+step);
   end;
  end;

 procedure MultPnt(const m:TMat34;v:PVec3;num,step:integer);
  var
   i:integer;
   x,y,z:single;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+m[3,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+m[3,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+m[3,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PVec3(PtrUInt(v)+step);
   end;
  end;

 procedure MultPnt(const m:TMat3d;v:PVec3d;num,step:integer);
  var
   i:integer;
   x,y,z:double;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PVec3d(PtrUInt(v)+step);
   end;
  end;
 procedure MultPnt(const m:TMat3;v:PVec3;num,step:integer);
  var
   i:integer;
   x,y,z:single;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PVec3(PtrUInt(v)+step);
   end;
  end;

 function TransformPoint(const m:TMat4;v:PVec3):TVec3; overload;
  var
   t:single;
  begin
   result.x:=v.x*m[0,0]+v.y*m[1,0]+v.z*m[2,0]+m[3,0];
   result.y:=v.x*m[0,1]+v.y*m[1,1]+v.z*m[2,1]+m[3,1];
   result.z:=v.x*m[0,2]+v.y*m[1,2]+v.z*m[2,2]+m[3,2];
          t:=v.x*m[0,3]+v.y*m[1,3]+v.z*m[2,3]+m[3,3];
   if (t<>1) and (t>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
   end else
   if t<=0 then
    result:=InvalidVec3;
  end;

 function TransformPoint(const m:TMat4d;v:PVec3d):TVec3d; overload;
  var
   t:double;
  begin
   result.x:=v.x*m[0,0]+v.y*m[1,0]+v.z*m[2,0]+m[3,0];
   result.y:=v.x*m[0,1]+v.y*m[1,1]+v.z*m[2,1]+m[3,1];
   result.z:=v.x*m[0,2]+v.y*m[1,2]+v.z*m[2,2]+m[3,2];
          t:=v.x*m[0,3]+v.y*m[1,3]+v.z*m[2,3]+m[3,3];
   if (t<>1) and (t>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
   end else
   if t<=0 then
    result:=InvalidPoint3;
  end;

 function TranslationMat(x,y,z:double):TMat34d;
  begin
   result:=IdentMat34d;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function TranslationMat4d(x,y,z:double):TMat4d;
  begin
   result:=IdentMat4d;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationXMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat34d;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat34d;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat34d;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat(scaleX,scaleY,scaleZ:double):TMat34d;
  begin
   result:=IdentMat34d;
   result[0,0]:=scaleX;
   result[1,1]:=scaleY;
   result[2,2]:=scaleZ;
  end;

 function RotationMat3X(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat3;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationMat3Y(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat3;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationMat3Z(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat3;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;


 function TranslationMat4(x,y,z:single):TMat4;
  begin
   result:=IdentMat4;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationMat4X(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat4;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationMat4Y(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat4;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationMat4Z(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMat4;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat4(scaleX,scaleY,scaleZ:single):TMat4;
  begin
   result:=IdentMat4;
   result[0,0]:=scaleX;
   result[1,1]:=scaleY;
   result[2,2]:=scaleZ;
  end;

 function RotationAroundVector(v:TVec3d;angle:double):TMat3d;
  var
   l2,m2,n2,lm,ln,mn,co,si,nco:double;
  begin
   l2:=v.x*v.x;
   lm:=v.x*v.y;
   ln:=v.x*v.z;
   m2:=v.y*v.y;
   mn:=v.y*v.z;
   n2:=v.z*v.z;
   co:=cos(angle);
   si:=sin(angle);
   nco:=1-co;
   result[0,0]:=l2+(m2+n2)*co;  result[0,1]:=lm*nco-v.z*si; result[0,2]:=ln*nco+v.y*si;
   result[1,0]:=lm*nco+v.z*si; result[1,1]:=m2+(l2+n2)*co;  result[1,2]:=mn*nco-v.x*si;
   result[2,0]:=ln*nco-v.y*si; result[2,1]:=mn*nco+v.x*si; result[2,2]:=n2+(l2+m2)*co;
  end;

 function RotationAroundVector(v:TVec3;angle:single):TMat3;
  var
   x2,y2,z2:single;
   xy,xz,yz:single;
   co,si,nco:single;
  begin
   v.Normalize;
   x2:=sqr(v.x);
   y2:=sqr(v.y);
   z2:=sqr(v.z);
   xy:=v.x*v.y;
   xz:=v.x*v.z;
   yz:=v.y*v.z;
   co:=cos(angle);
   si:=sin(angle);
   nco:=1-co;

   result[0,0]:=co+nco*x2;      result[0,1]:=xy*nco+v.z*si;  result[0,2]:=xz*nco-v.y*si;
   result[1,0]:=xy*nco-v.z*si;  result[1,1]:=co+nco*y2;      result[1,2]:=yz*nco+v.x*si;
   result[2,0]:=xz*nco+v.y*si;  result[2,1]:=yz*nco-v.x*si;  result[2,2]:=co+nco*z2;
  end;

{ function RotationAroundVector(v:TVec3;angle:single):TMat3;
  var
   l2,m2,n2,lm,ln,mn,co,si,nco:single;
  begin
   Normalize(v);
   l2:=v.x*v.x;
   lm:=v.x*v.y;
   ln:=v.x*v.z;
   m2:=v.y*v.y;
   mn:=v.y*v.z;
   n2:=v.z*v.z;
   co:=cos(angle);
   si:=sin(angle);
   nco:=1-co;
   result[0,0]:=l2+(m2+n2)*co;  result[1,0]:=lm*nco-v.z*si;  result[2,0]:=ln*nco+v.y*si;
   result[0,1]:=lm*nco+v.z*si;  result[1,1]:=m2+(l2+n2)*co;  result[2,1]:=mn*nco-v.x*si;
   result[0,2]:=ln*nco-v.y*si;  result[1,2]:=mn*nco+v.x*si;  result[2,2]:=n2+(l2+m2)*co;
  end; }

 procedure MatrixFromQuaternion(const q:TQuatd;out mat:TMat3d); overload;
  var
   wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:double;
  begin
   x2:=q.x*2;
   y2:=q.y*2;
   z2:=q.z*2;
   xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
   yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
   wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;

   mat[0,0]:=1.0-(yy+zz);  mat[0,1]:=xy-wz;        mat[0,2]:=xz+wy;
   mat[1,0]:=xy+wz;        mat[1,1]:=1.0-(xx+zz);  mat[1,2]:=yz-wx;
   mat[2,0]:=xz-wy;        mat[2,1]:=yz+wx;        mat[2,2]:=1.0-(xx+yy);
  end;

 procedure MatrixFromQuaternion(const q:TQuat;out mat:TMat3); overload;
  var
   wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:single;
  begin
   x2:=q.x*2;
   y2:=q.y*2;
   z2:=q.z*2;
   xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
   yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
   wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;

   mat[0,0]:=1.0-(yy+zz);  mat[1,0]:=xy-wz;        mat[2,0]:=xz+wy;
   mat[0,1]:=xy+wz;        mat[1,1]:=1.0-(xx+zz);  mat[2,1]:=yz-wx;
   mat[0,2]:=xz-wy;        mat[1,2]:=yz+wx;        mat[2,2]:=1.0-(xx+yy);
  end;

 procedure MatrixFromQuaternion(const q:TQuat;out mat:TMat4); overload;
  var
   wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:single;
  begin
   x2:=q.x*2;
   y2:=q.y*2;
   z2:=q.z*2;
   xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
   yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
   wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;


   mat[0,0]:=1.0-(yy+zz);  mat[1,0]:=xy-wz;        mat[2,0]:=xz+wy;
   mat[0,1]:=xy+wz;        mat[1,1]:=1.0-(xx+zz);  mat[2,1]:=yz-wx;
   mat[0,2]:=xz-wy;        mat[1,2]:=yz+wx;        mat[2,2]:=1.0-(xx+yy);
   mat[0,3]:=0;            mat[1,3]:=0;            mat[2,3]:=0;
   TVec4(mat[3]):=vec0001s;
  end;

 procedure QuaternionToMatrix(const q:TQuatd;out mat:TMat3d); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;
 procedure QuaternionToMatrix(const q:TQuat;out mat:TMat3); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;

 // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
 function MatrixToQuaternion(const mat:TMat3):TQuat; overload;
  var
   t,k:single;
  begin
   t:=mat[0,0]+mat[1,1]+mat[2,2];
   if t>0 then begin
    k:=sqrt(1+t);
    result.w:=k*0.5;
    k:=0.5/k;
    result.x:=-(mat[2,1]-mat[1,2])*k;
    result.y:=-(mat[0,2]-mat[2,0])*k;
    result.z:=-(mat[1,0]-mat[0,1])*k;
   end else
   if (mat[0,0]>mat[1,1]) and (mat[0,0]>mat[2,2]) then begin
    k:=sqrt(1+mat[0,0]-mat[1,1]-mat[2,2]);
    result.x:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[1,2]-mat[2,1])*k;
    result.y:=(mat[0,1]+mat[1,0])*k;
    result.z:=(mat[0,2]+mat[2,0])*k;
   end else
   if mat[1,1]>mat[2,2] then begin
    k:=sqrt(1+mat[1,1]-mat[0,0]-mat[2,2]);
    result.y:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[2,0]-mat[0,2])*k;
    result.x:=(mat[0,1]+mat[1,0])*k;
    result.z:=(mat[1,2]+mat[2,1])*k;
   end else begin
    k:=sqrt(1+mat[2,2]-mat[0,0]-mat[1,1]);
    result.z:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[0,1]-mat[1,0])*k;
    result.x:=(mat[0,2]+mat[2,0])*k;
    result.y:=(mat[1,2]+mat[2,1])*k;
   end;
  end;

 function MatrixToQuaternion(const mat:TMat3d):TQuatd; overload;
  var
   t,k:double;
  begin
   t:=mat[0,0]+mat[1,1]+mat[2,2];
   if t>0 then begin
    k:=sqrt(1+t);
    result.w:=k*0.5;
    k:=0.5/k;
    result.x:=-(mat[2,1]-mat[1,2])*k;
    result.y:=-(mat[0,2]-mat[2,0])*k;
    result.z:=-(mat[1,0]-mat[0,1])*k;
   end else
   if (mat[0,0]>mat[1,1]) and (mat[0,0]>mat[2,2]) then begin
    k:=sqrt(1+mat[0,0]-mat[1,1]-mat[2,2]);
    result.x:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[1,2]-mat[2,1])*k;
    result.y:=(mat[0,1]+mat[1,0])*k;
    result.z:=(mat[0,2]+mat[2,0])*k;
   end else
   if mat[1,1]>mat[2,2] then begin
    k:=sqrt(1+mat[1,1]-mat[0,0]-mat[2,2]);
    result.y:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[2,0]-mat[0,2])*k;
    result.x:=(mat[0,1]+mat[1,0])*k;
    result.z:=(mat[1,2]+mat[2,1])*k;
   end else begin
    k:=sqrt(1+mat[2,2]-mat[0,0]-mat[1,1]);
    result.z:=k*0.5;
    k:=0.5/k;
    result.w:=(mat[0,1]-mat[1,0])*k;
    result.x:=(mat[0,2]+mat[2,0])*k;
    result.y:=(mat[1,2]+mat[2,1])*k;
   end;
  end;

 // If matrix is not orthogonal, the shear will be lost
 procedure DecomposeMatrix(mat:TMat4;out translation,rotation,scale:TQuat);
  var
   qX,qY,qZ:TQuat;
   mat3:TMat3;
   v:single;
  begin
   translation:=MatRow(mat,3);
   qX:=MatRow(mat,0);
   qY:=MatRow(mat,1);
   qZ:=MatRow(mat,2);
   // Scale part
   scale.x:=QuatLength(qX);
   scale.y:=QuatLength(qY);
   scale.z:=QuatLength(qZ);
   scale.w:=0;
   qX.Mul(1/scale.x);
   qY.Mul(1/scale.y);
   qZ.Mul(1/scale.z);
   // Make sure the rotation part is orthogonal
   v:=qY.Dot(qX);
   if abs(v)>EpsilonS then begin
    qY.Add(qX,-v);
    qY.Normalize;
   end;
   v:=qZ.Dot(qX);
   if abs(v)>EpsilonS then begin
    qZ.Add(qX,-v);
    qZ.Normalize;
   end;
   v:=qZ.Dot(qY);
   if abs(v)>EpsilonS then begin
    qZ.Add(qY,-v);
    qZ.Normalize;
   end;
   // Convert to quaternion
   move(qX,mat3[0],sizeof(qX));
   move(qY,mat3[1],sizeof(qy));
   move(qZ,mat3[2],sizeof(qZ));
   rotation:=MatrixToQuaternion(mat3);
  end;

 procedure DecomposeMatrix(mat:TMat4d;out translation,rotation,scale:TQuatd);
  var
   qX,qY,qZ:TQuatd;
   mat3:TMat3d;
   v:double;
  begin
   translation:=MatRow(mat,3);
   qX:=MatRow(mat,0);
   qY:=MatRow(mat,1);
   qZ:=MatRow(mat,2);
   // Scale part
   scale.x:=QuatLength(qX);
   scale.y:=QuatLength(qY);
   scale.z:=QuatLength(qZ);
   scale.w:=0;
   qX.Mul(1/scale.x);
   qY.Mul(1/scale.y);
   qZ.Mul(1/scale.z);
   // Make sure the rotation part is orthogonal
   v:=qY.Dot(qX);
   if abs(v)>EpsilonS then begin
    qY.Add(qX,-v);
    qY.Normalize;
   end;
   v:=qZ.Dot(qX);
   if abs(v)>EpsilonS then begin
    qZ.Add(qX,-v);
    qZ.Normalize;
   end;
   v:=qZ.Dot(qY);
   if abs(v)>EpsilonS then begin
    qZ.Add(qY,-v);
    qZ.Normalize;
   end;
   // Convert to quaternion
   move(qX,mat3[0],sizeof(qx));
   move(qY,mat3[1],sizeof(qy));
   move(qZ,mat3[2],sizeof(qz));
  rotation:=MatrixToQuaternion(mat3);
 end;

 function QuatLength(q:TQuatd):double; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 function QuatLength(q:TQuat):single; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 procedure QuatScale(var q:TQuatd;val:double); overload;
  begin
   q.w:=q.w*val;
   q.x:=q.x*val;
   q.y:=q.y*val;
   q.z:=q.z*val;
  end;
 procedure QuatScale(var q:TQuat;val:single); overload;
  begin
   q.w:=q.w*val;
   q.x:=q.x*val;
   q.y:=q.y*val;
   q.z:=q.z*val;
  end;

 procedure QuatNormalize(var q:TQuatd); overload;
  begin
   QuatScale(q,1/QuatLength(q));
  end;
 procedure QuatNormalize(var q:TQuat); overload;
  begin
   QuatScale(q,1/QuatLength(q));
  end;

 function QuatInvert(q:TQuatd):TQuatd; overload;
  begin
   result.w:=q.w;
   result.x:=-q.x;
   result.y:=-q.y;
   result.z:=-q.z;
   QuatNormalize(result);
  end;
 function QuatInvert(q:TQuat):TQuat; overload;
  begin
   result.w:=q.w;
   result.x:=-q.x;
   result.y:=-q.y;
   result.z:=-q.z;
   QuatNormalize(result);
  end;

 function QuatMultiply(q1,q2:TQuatd):TQuatd; overload;
  var
   a,b,c,d,e,f,g,h:double;
  begin
   A:=(q1.w+q1.x) * (q2.w+q2.x);
   B:=(q1.z-q1.y) * (q2.y-q2.z);
   C:=(q1.x-q1.w) * (q2.y+q2.z);
   D:=(q1.y+q1.z) * (q2.x-q2.w);
   E:=(q1.x+q1.z) * (q2.x+q2.y);
   F:=(q1.x-q1.z) * (q2.x-q2.y);
   G:=(q1.w+q1.y) * (q2.w-q2.z);
   H:=(q1.w-q1.y) * (q2.w+q2.z);
   result.w:= B+(-E-F+G+H)*0.5;
   result.x:= A-( E+F+G+H)*0.5;
   result.y:=-C+( E-F+G-H)*0.5;
   result.z:=-D+( E-F-G+H)*0.5;
  end;
 function QuatMultiply(q1,q2:TQuat):TQuat; overload;
  var
   a,b,c,d,e,f,g,h:single;
  begin
   A:=(q1.w+q1.x) * (q2.w+q2.x);
   B:=(q1.z-q1.y) * (q2.y-q2.z);
   C:=(q1.x-q1.w) * (q2.y+q2.z);
   D:=(q1.y+q1.z) * (q2.x-q2.w);
   E:=(q1.x+q1.z) * (q2.x+q2.y);
   F:=(q1.x-q1.z) * (q2.x-q2.y);
   G:=(q1.w+q1.y) * (q2.w-q2.z);
   H:=(q1.w-q1.y) * (q2.w+q2.z);
   result.w:= B+(-E-F+G+H)*0.5;
   result.x:= A-( E+F+G+H)*0.5;
   result.y:=-C+( E-F+G-H)*0.5;
   result.z:=-D+( E-F-G+H)*0.5;
  end;

 function QuatSlerp(q1,q2:TQuat;factor:single):TQuat;
  var
    cosOmega, sinOmega, scale0, scale1: Single;
  begin
    // Compute the cosine of the angle between the two vectors.
    cosOmega:=Q1.x*Q2.x + Q1.y*Q2.y + Q1.z*Q2.z + Q1.w*Q2.w;

    // if negative dot, use -q1. two quaternions q and -q represent the same rotation,
    // but may produce different slerp. we chose q or -q to rotate using the shortest path.
    if cosOmega < 0.0 then begin
     cosOmega:=-cosOmega;
     result.x:=-q1.x;
     result.y:=-q1.y;
     result.z:=-q1.z;
     result.w:=-q1.w;
    end else
     result:=q1;

    // Compute the scales for the linear interpolation
    if (1.0 - cosOmega) > 1E-6 then begin
     // Standard case (slerp)
     sinOmega:=Sqrt(1.0 - sqr(cosOmega));
     scale0:=Sin((1.0-factor) * ArcCos(cosOmega)) / sinOmega;
     scale1:=Sin(factor * ArcCos(cosOmega)) / sinOmega;
    end else begin
     // Q1 and Q2 are very close, so do a linear interpolation
     scale0:=1.0-factor;
     scale1:=factor;
    end;

    // Final calculation of the interpolated quaternion
    result.x:=scale0*result.x + scale1*q2.x;
    result.y:=scale0*result.y + scale1*q2.y;
    result.z:=scale0*result.z + scale1*q2.z;
    result.w:=scale0*result.w + scale1*q2.w;
  end;

class function TPlane.Init(const point,normal:TVec3d):TPlane;
  var
   len,invLen:double;
  begin
   len:=Sqrt(normal.x*normal.x+normal.y*normal.y+normal.z*normal.z);
   if len>Epsilon then begin
    invLen:=1/len;
   end else begin
    invLen:=0;
   end;
   result.a:=normal.x*invLen;
   result.b:=normal.y*invLen;
   result.c:=normal.z*invLen;
   result.d:=-(result.a*point.x+result.b*point.y+result.c*point.z);
  end;

 function TPlane.DistanceTo(const pnt:TVec3d):double;
  begin
   result:=pnt.x*a+pnt.y*b+pnt.z*c+d;
  end;

 function TPlane.DistanceTo(const pnt:TVec3):single;
  begin
   result:=pnt.x*a+pnt.y*b+pnt.z*c+d;
  end;

 function Det(const m:TMat3d):double;
  begin
   result:=m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
           m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
           m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]);
  end;
 function Det(const m:TMat3):single;
  begin
   result:=m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
           m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
           m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]);
  end;

 function Det(const m:TMat4d):double;
  begin
   result:=0;
   if m[3,3]<>0 then
    result:=result+(m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
                    m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
                    m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]))*m[3,3];
   if m[2,3]<>0 then
    result:=result-(m[0,0]*(m[1,1]*m[3,2]-m[1,2]*m[3,1])-
                    m[0,1]*(m[1,0]*m[3,2]-m[1,2]*m[3,0])+
                    m[0,2]*(m[1,0]*m[3,1]-m[1,1]*m[3,0]))*m[2,3];
   if m[1,3]<>0 then
    result:=result+(m[0,0]*(m[2,1]*m[3,2]-m[2,2]*m[3,1])-
                    m[0,1]*(m[2,0]*m[3,2]-m[2,2]*m[3,0])+
                    m[0,2]*(m[2,0]*m[3,1]-m[2,1]*m[3,0]))*m[1,3];
   if m[0,3]<>0 then
    result:=result-(m[1,0]*(m[2,1]*m[3,2]-m[2,2]*m[3,1])-
                    m[1,1]*(m[2,0]*m[3,2]-m[2,2]*m[3,0])+
                    m[1,2]*(m[2,0]*m[3,1]-m[2,1]*m[3,0]))*m[0,3];
  end;

 function Det(const m:TMat4):single;
  begin
   result:=0;
   if m[3,3]<>0 then
    result:=result+(m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
                    m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
                    m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]))*m[3,3];
   if m[2,3]<>0 then
    result:=result-(m[0,0]*(m[1,1]*m[3,2]-m[1,2]*m[3,1])-
                    m[0,1]*(m[1,0]*m[3,2]-m[1,2]*m[3,0])+
                    m[0,2]*(m[1,0]*m[3,1]-m[1,1]*m[3,0]))*m[2,3];
   if m[1,3]<>0 then
    result:=result+(m[0,0]*(m[2,1]*m[3,2]-m[2,2]*m[3,1])-
                    m[0,1]*(m[2,0]*m[3,2]-m[2,2]*m[3,0])+
                    m[0,2]*(m[2,0]*m[3,1]-m[2,1]*m[3,0]))*m[1,3];
   if m[0,3]<>0 then
    result:=result-(m[1,0]*(m[2,1]*m[3,2]-m[2,2]*m[3,1])-
                    m[1,1]*(m[2,0]*m[3,2]-m[2,2]*m[3,0])+
                    m[1,2]*(m[2,0]*m[3,1]-m[2,1]*m[3,0]))*m[0,3];
  end;


 function IntersectTrgLine(A,B,C,O,T:PVec3;var pb,pc,d:double):boolean;
  var
   m:TMat3d;
   mv:TMatrix3vd absolute m;
   l:TVec3d;
   dt:double;
  begin
   m[0,0]:=B.x-A.x; m[0,1]:=B.y-A.y; m[0,2]:=B.z-A.z;
   m[1,0]:=C.x-A.x; m[1,1]:=C.y-A.y; m[1,2]:=C.z-A.z;
   m[2,0]:=T.x-O.x; m[2,1]:=T.y-O.y; m[2,2]:=T.z-O.z;
   mv[2].Normalize;
   dt:=det(m);
   result:=false;
   if abs(dt)<0.0001 then exit;

   l.x:=O.x-A.x; l.y:=O.y-A.y; l.z:=O.z-A.z;
   // Метод Крамера
   pb:=(l.x*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
        l.y*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
        l.z*(m[1,0]*m[2,1]-m[1,1]*m[2,0]))/dt;
   if (pb<0) or (pb>1) then exit;
   pc:=-(l.x*(m[0,1]*m[2,2]-m[0,2]*m[2,1])-
         l.y*(m[0,0]*m[2,2]-m[0,2]*m[2,0])+
         l.z*(m[0,0]*m[2,1]-m[0,1]*m[2,0]))/dt;
   if (pc<0) or (pb+pc>1) then exit;
   d:=-(l.x*(m[0,1]*m[1,2]-m[0,2]*m[1,1])-
        l.y*(m[0,0]*m[1,2]-m[0,2]*m[1,0])+
        l.z*(m[0,0]*m[1,1]-m[0,1]*m[1,0]))/dt;
   if d<0 then exit;
   result:=true;
  end;

 procedure _YRPToMatrix(yaw,roll,pitch:double;m:PDouble;width:integer); inline;
  var
   ca,sa,cb,sb,cc,sc:double;
  begin
   ca:=cos(yaw); sa:=sin(yaw);
   cb:=cos(roll); sb:=sin(roll);
   cc:=cos(pitch); sc:=sin(pitch);
   // row 0
   m^:=ca*cb; inc(m);
   m^:=sa*cb; inc(m);
   m^:=-sb; inc(m,width-2);
   // row 1
   m^:=ca*sb*sc-sa*cc; inc(m);
   m^:=sa*sb*sc+ca*cc; inc(m);
   m^:=cb*sc; inc(m,width-2);
   // row 2
   m^:=ca*sb*cc+sa*sc; inc(m);
   m^:=sa*sb*cc-ca*sc; inc(m);
   m^:=cb*cc; inc(m,width-2);
  end;

 procedure _YRPToMatrixS(yaw,roll,pitch:single;m:PSingle;width:integer); inline;
  var
   ca,sa,cb,sb,cc,sc:double;
  begin
   ca:=cos(yaw); sa:=sin(yaw);
   cb:=cos(roll); sb:=sin(roll);
   cc:=cos(pitch); sc:=sin(pitch);
   // row 0
   m^:=ca*cb; inc(m);
   m^:=sa*cb; inc(m);
   m^:=-sb; inc(m,width-2);
   // row 1
   m^:=ca*sb*sc-sa*cc; inc(m);
   m^:=sa*sb*sc+ca*cc; inc(m);
   m^:=cb*sc; inc(m,width-2);
   // row 2
   m^:=ca*sb*cc+sa*sc; inc(m);
   m^:=sa*sb*cc-ca*sc; inc(m);
   m^:=cb*cc; inc(m,width-2);
  end;

 procedure YRPToMatrix(out mat:TMat3d;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrix(yaw,roll,pitch,@mat,3);
  end;

 procedure YRPToMatrix(out mat:TMat3;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrixS(yaw,roll,pitch,@mat,3);
  end;

 procedure YRPToMatrix(out mat:TMat4d;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrix(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure YRPToMatrix(out mat:TMat4;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrixS(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure YRPToMatrix(out mat:TMat34d;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrix(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure YRPToMatrix(out mat:TMat34;yaw,roll,pitch:double); overload;
  begin
   _YRPToMatrixS(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure MatrixToYRP(const mat:TMat34d; var yaw,roll,pitch:double);
  var
   v:TVec3d;
   skewA,skewB,skewC:double;
   m,m2:TMat34d;
   mv:TMatrix43vd absolute m;
  begin
   m:=mat;
   mv[0].Normalize;
   mv[1].Normalize;
   mv[2].Normalize;
   skewA:=mv[0].Dot(mv[1]);
   skewB:=mv[2].Dot(mv[0]); // !??
   skewC:=mv[2].Dot(mv[1]); // !??
   mv[1].x:=mv[1].x-mv[0].x*skewA;
   mv[1].y:=mv[1].y-mv[0].y*skewA;
   mv[1].z:=mv[1].z-mv[0].z*skewA;
   mv[1].Normalize;
   mv[2]:=mv[0].Cross(mv[1]);

   v:=mv[0]; v.z:=0;
   if v.Length2<0.000001 then Yaw:=0 else begin
    v.Normalize;
    if v.x<-0.999 then Yaw:=pi else begin
     Yaw:=arccos(v.x);
     if v.y<0 then Yaw:=-Yaw;
    end;
    MultMat(m,RotationZMat(-Yaw),m2);
    m:=m2;
   end;
   // roll (Y-rotation): mv[0].z = -sin(roll)
   if mv[0].x<-0.999 then roll:=pi else
    Roll:=-arcsin(mv[0].z);
   MultMat(m,RotationYMat(roll),m2);
   m:=m2;
   // pitch (X-rotation)
   if mv[1].y<-0.999 then pitch:=pi else begin
    Pitch:=arccos(mv[1].y);
    if mv[1].z<0 then pitch:=-pitch;
   end;
  end;

var
 fSet1,fset2:cardinal;
{ TVec3d }

constructor TVec3d.Init(X,Y,Z:double);
 begin
  self.x:=X; self.y:=Y; self.z:=Z;
 end;

constructor TVec3d.Init(p0,p1:TVec3d;t:double);
 var
  t1:double;
 begin
  t1:=1-t;
  x:=p0.x*t1+p1.x*t;
  y:=p0.y*t1+p1.y*t;
  z:=p0.z*t1+p1.z*t;
 end;

function TVec3d.IsValid: boolean;
 begin
  result:=x=x;
 end;

procedure TVec3d.Normalize;
 var
  l:double;
 begin
  l:=Length;
  ASSERT(l>Epsilon,'Normalize zero-length vector');
  l:=1/l;
  x:=x*l;
  y:=y*l;
  z:=z*l;
 end;

function TVec3d.Length:double;
 begin
  result:=sqrt(x*x+y*y+z*z);
 end;

function TVec3d.Length2:double;
 begin
  result:=x*x+y*y+z*z;
 end;

function TVec3d.Dot(const p:TVec3d):double;
 begin
  result:=x*p.x+y*p.y+z*p.z;
 end;

function TVec3d.Cross(const p:TVec3d):TVec3d;
 begin
  result.x:=y*p.z-z*p.y;
  result.y:=-(x*p.z-z*p.x);
  result.z:=x*p.y-y*p.x;
 end;

function TVec3d.Sub(const p:TVec3d):TVec3d;
 begin
  result.x:=x-p.x;
  result.y:=y-p.y;
  result.z:=z-p.z;
 end;

function TVec3d.Distance2(const p:TVec3d):double;
 begin
  result:=sqr(x-p.x)+sqr(y-p.y)+sqr(z-p.z);
 end;

function TVec3d.MaxDelta(const p:TVec3d):double;
 var
  d:double;
 begin
  result:=abs(x-p.x);
  d:=abs(y-p.y);
  if d>result then result:=d;
  d:=abs(z-p.z);
  if d>result then result:=d;
 end;

procedure TVec3d.Add(const p:TVec3d);
 begin
  x:=x+p.x;
  y:=y+p.y;
  z:=z+p.z;
 end;

procedure TVec3d.Multiply(scalar:double);
 begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
 end;

{ TVec3 }
constructor TVec3.Init(X,Y,Z:single);
 begin
  self.x:=x; self.y:=y; self.z:=z;
 end;

constructor TVec3.Init(p:TVec3d);
 begin
  self.x:=p.x;
  self.y:=p.y;
  self.z:=p.z;
 end;

procedure TVec3.Add(const p:TVec3);
 begin
  x:=x+p.x; y:=y+p.y; z:=z+p.z;
 end;

constructor TVec3.Init(p0,p1:TVec3;t:single);
var
 t1:single;
begin
 t1:=1-t;
 x:=p0.x*t1+p1.x*t;
 y:=p0.y*t1+p1.y*t;
 z:=p0.z*t1+p1.z*t;
end;

procedure TVec3.Normalize;
 var
  l:single;
 begin
  l:=Length;
  ASSERT(l>EpsilonS,'Normalize zero-length vector');
  l:=1/l;
  x:=x*l;
  y:=y*l;
  z:=z*l;
 end;

constructor TVec3.Init(p0:TVec3;weight0:single;p1:TVec3;weight1:single);
 begin
  x:=p0.x*weight0+p1.x*weight1;
  y:=p0.y*weight0+p1.y*weight1;
  z:=p0.z*weight0+p1.z*weight1;
 end;

function TVec3.IsValid: boolean;
 begin
  result:=x=x;
 end;

function TVec3.Length:single;
 begin
  result:=sqrt(x*x+y*y+z*z);
 end;

function TVec3.Length2:single;
 begin
  result:=x*x+y*y+z*z;
 end;

function TVec3.Dot(const p:TVec3):single;
 begin
  result:=x*p.x+y*p.y+z*p.z;
 end;

function TVec3.Cross(const p:TVec3):TVec3;
 begin
  result.x:=y*p.z-z*p.y;
  result.y:=z*p.x-x*p.z;
  result.z:=x*p.y-y*p.x;
 end;

function TVec3.Sub(const p:TVec3):TVec3;
 begin
  result.x:=x-p.x;
  result.y:=y-p.y;
  result.z:=z-p.z;
 end;

function TVec3.Distance2(const p:TVec3):single;
 var
  dx,dy,dz:single;
 begin
  dx:=x-p.x;
  dy:=y-p.y;
  dz:=z-p.z;
  result:=dx*dx+dy*dy+dz*dz;
 end;

function TVec3.MaxDelta(const p:TVec3):single;
 var
  d:single;
 begin
  result:=abs(x-p.x);
  d:=abs(y-p.y);
  if d>result then result:=d;
  d:=abs(z-p.z);
  if d>result then result:=d;
 end;

procedure TVec3.Multiply(scalar:single);
 begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
 end;

{ TQuatd }

constructor TQuatd.Init(x,y,z,w:double);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

function TQuatd.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TQuatd.Add(const q:TQuatd;scale:double);
 begin
  x:=x+q.x*scale;
  y:=y+q.y*scale;
  z:=z+q.z*scale;
  w:=w+q.w*scale;
 end;

procedure TQuatd.Add(const q:TQuatd);
 begin
  x:=x+q.x; y:=y+q.y; z:=z+q.z; w:=w+q.w;
 end;

function TQuatd.Dot(const q:TQuatd):double;
 begin
  result:=x*q.x+y*q.y+z*q.z+w*q.w;
 end;

function TQuatd.Length:double;
 begin
  result:=QuatLength(self);
 end;

function TQuatd.Length2:double;
 begin
  result:=w*w + x*x + y*y + z*z;
 end;

procedure TQuatd.Mul(scalar:double);
 begin
  QuatScale(self,scalar);
 end;

procedure TQuatd.Mul(const q:TQuatd);
 begin
  x:=x*q.x;
  y:=y*q.y;
  z:=z*q.z;
  w:=w*q.w;
 end;

procedure TQuatd.Normalize;
 begin
  QuatNormalize(self);
 end;

{ TQuat }

constructor TQuat.Init(x, y, z, w: single);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

constructor TQuat.Init(vec3:TVec3);
 begin
  x:=vec3.x; y:=vec3.y; z:=vec3.z; w:=0;
 end;

constructor TQuat.Init(q:TQuatd);
 begin
  x:=q.x; y:=q.y; z:=q.z; w:=q.w;
 end;

function TQuat.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TQuat.Assign(const q:TQuat);
 begin
  self:=q;
 end;

function TQuat.Length:single;
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  movups xmm0,[rcx]
  {$ENDIF}
  {$IFDEF UNIX}
  movups xmm0,[rdi]
  {$ENDIF}
  mulps xmm0,xmm0
  haddps xmm0,xmm0
  haddps xmm0,xmm0
  sqrtss xmm0,xmm0
 end;
 {$ENDIF}
 {$IFDEF CPU386}
 begin
  result:=QuatLength(self);
 end;
 {$ENDIF}

function TQuat.Length2:single;
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  movups xmm0,[rcx]
  {$ENDIF}
  {$IFDEF UNIX}
  movups xmm0,[rdi]
  {$ENDIF}
  mulps xmm0,xmm0
  haddps xmm0,xmm0
  haddps xmm0,xmm0
 end;
 {$ENDIF}
 {$IFDEF CPU386}
 begin
  result:=sqr(x)+sqr(y)+sqr(z)+sqr(w);
 end;
 {$ENDIF}


procedure TQuat.Normalize;
 {$IFDEF CPUx64}
 asm
  // rcx=@self
  {$IFDEF MSWINDOWS}
  movups xmm0,[rcx]
  {$ENDIF}
  {$IFDEF UNIX}
  movups xmm0,[rdi]
  {$ENDIF}
  movaps xmm1,xmm0
  mulps xmm0,xmm0
  haddps xmm0,xmm0
  haddps xmm0,xmm0
  rsqrtss xmm0,xmm0   // inverted length
  shufps xmm0,xmm0,0
  mulps xmm1,xmm0
  {$IFDEF MSWINDOWS}
  movups [rcx],xmm1
  {$ENDIF}
  {$IFDEF UNIX}
  movups [rdi],xmm1
  {$ENDIF}
 end;
 {$ENDIF}
 {$IFDEF CPU386}
 begin
  QuatNormalize(self);
 end;
 {$ENDIF}


procedure TQuat.Sub(const q:TQuat);
 {$IFDEF CPUx64}
 asm
  {$IFDEF UNIX}
  // rdi=@self, rsi=q
  movups xmm0,[rdi]
  subps xmm0,[rsi]
  movups [rdi],xmm0
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=q
  movups xmm0,[rcx]
  subps xmm0,[rdx]
  movups [rcx],xmm0
  {$ENDIF}
 end;
 {$ELSE}
 begin
  x:=x-q.x;
  y:=y-q.y;
  z:=z-q.z;
  w:=w-q.w;
 end;
 {$ENDIF}

procedure TQuat.Add(const q:TQuat);
 {$IFDEF CPUx64}
 asm
  {$IFDEF UNIX}
  // rdi=@self, rsi=q
  movups xmm0,[rdi]
  addps xmm0,[rsi]
  movups [rdi],xmm0
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=q
  movups xmm0,[rcx]
  addps xmm0,[rdx]
  movups [rcx],xmm0
  {$ENDIF}
 end;
 {$ELSE}
 begin
  x:=x+q.x;
  y:=y+q.y;
  z:=z+q.z;
  w:=w+q.w;
 end;
 {$ENDIF}

procedure TQuat.Add(const q:TQuat;scale:single);
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=@q, XMM2=scale
  shufps xmm2,xmm2,0
  movups xmm0,[rdx]
  mulps xmm0,xmm2
  addps xmm0,[rcx]
  movups [rcx],xmm0
  {$ENDIF}
  {$IFDEF UNIX}
  // rdi=@self, rsi=@q, XMM0=scale
  shufps xmm0,xmm0,0
  movups xmm2,[rsi]
  mulps xmm2,xmm0
  addps xmm2,[rdi]
  movups [rdi],xmm2
  {$ENDIF}
 end;
{$ELSE}
 begin
  x:=x+q.x*scale;
  y:=y+q.y*scale;
  z:=z+q.z*scale;
  w:=w+q.w*scale;
 end;
 {$ENDIF}

procedure TQuat.Middle(const q:TQuat;weight:single);
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=@q, XMM2=weight
  movups xmm0,[rcx]
  movups xmm1,[rdx]
  shufps xmm2,xmm2,0
  subps xmm1,xmm0 // xmm1=q-self
  mulps xmm1,xmm2
  addps xmm0,xmm1
  movups [rcx],xmm0
  {$ENDIF}
  {$IFDEF UNIX}
  // rdi=@self, rsi=@q, XMM0=weight
  movups xmm1,[rdi]
  movups xmm2,[rsi]
  shufps xmm0,xmm0,0
  subps xmm2,xmm1 // xmm2=q-self
  mulps xmm2,xmm0
  addps xmm1,xmm2
  movups [rdi],xmm1
  {$ENDIF}
 end;
 {$ELSE}
 var
  w:single;
 begin
  w:=1-weight;
  x:=x*w+q.x*weight;
  y:=y*w+q.y*weight;
  z:=z*w+q.z*weight;
  w:=w*w+q.w*weight;
 end;
 {$ENDIF}

function TQuat.Dot(const q:TQuat):single;
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=@q
  movups xmm0,[rcx]
  mulps xmm0,[rdx]
  haddps xmm0,xmm0
  haddps xmm0,xmm0
  {$ENDIF}
  {$IFDEF UNIX}
  // rdi=@self, rsi=@q
  movups xmm0,[rdi]
  mulps xmm0,[rsi]
  haddps xmm0,xmm0
  haddps xmm0,xmm0
  {$ENDIF}
 end;
 {$ELSE}
 begin
  result:=x*q.x+y*q.y+z*q.z+w*q.w;
 end;
 {$ENDIF}

procedure TQuat.Mul(const q:TQuat);
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=@q
  movups xmm0,[rcx]
  mulps xmm0,[rdx]
  movups [rcx],xmm0
  {$ENDIF}
  {$IFDEF UNIX}
  // rdi=@self, rsi=@q
  movups xmm0,[rdi] // load self
  mulps xmm0,[rsi]
  movups [rdi],xmm0 // save self
  {$ENDIF}
 end;
 {$ELSE}
 begin
  x:=x*q.x;
  y:=y*q.y;
  z:=z*q.z;
  w:=w*q.w;
 end;
 {$ENDIF}

procedure TQuat.Mul(scalar:single);
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, XMM1=scalar
  shufps xmm1,xmm1,0
  movups xmm0,[rcx]
  mulps xmm0,xmm1
  movups [rcx],xmm0
  {$ENDIF}
  {$IFDEF UNIX}
  // rdi=@self, XMM0=scalar
  shufps xmm0,xmm0,0
  movups xmm1,[rdi]
  mulps xmm1,xmm0
  movups [rdi],xmm1
  {$ENDIF}
 end;
 {$ELSE}
 begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
  w:=w*scalar;
 end;
 {$ENDIF}

initialization
// m:=RotationAroundVector(Vector3(0,1,0),1);

end.













