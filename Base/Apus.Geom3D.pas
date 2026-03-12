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
  PPoint3=^TVec3d;
  PVector3=^TVec3d;
  TVec3d=packed record
   x,y,z:double;
   constructor Init(X,Y,Z:double);
   procedure Normalize;
   function IsValid:boolean;
  end;
  TPoint3=TVec3d deprecated 'Use TVec3d';
  TVector3=TVec3d deprecated 'Use TVec3d';
  PVec3d=^TVec3d;

  PPoint3s=^TVec3;
  TVec3=packed record
   constructor Init(X,Y,Z:single); overload;
   constructor Init(p:TVec3d); overload;
   constructor Init(p0,p1:TVec3;t:single); overload;
   constructor Init(p0:TVec3;weight0:single;p1:TVec3;weight1:single); overload;
   constructor SetBetween(p0,p1:TVec3;t:single);
   procedure Normalize;
   function IsValid:boolean;
   function Length:single;  // Vector length
   function Length2:single; // Square length
   function Dot(const p:TVec3):single; inline;
   function Cross(const p:TVec3):TVec3; inline;
   function Sub(const p:TVec3):TVec3; inline;
   function Distance2(const p:TVec3):single; inline;
   procedure Add(p:TVec3);
   procedure Multiply(scalar:single);
   case integer of
   0:( x,y,z:single; );
   1:( v:array[0..2] of single; );
   2:( xy:TVec2; t:single; );
  end;
  TPoint3s=TVec3 deprecated 'Use TVec3';
  TVector3s=TVec3 deprecated 'Use TVec3';
  TPoints3s=array of TVec3;
  TVectors3s=TPoints3s;

  TQuatd=record
   constructor Init(x,y,z,w:double);
   procedure Add(var q:TQuatd); overload;
   procedure Add(var q:TQuatd;scale:double); overload;
   procedure Mul(scalar:double); overload;
   procedure Mul(var q:TQuatd); overload;
   function DotProd(var q:TQuatd):double;
   function Length:double;
   function Length2:double;
   procedure Normalize;
   function IsValid:boolean;
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
    3:( xyz:TVec3d; t:double; );
  end;

  { TQuaternionS }

  TQuaternionS=record
   constructor Init(x,y,z,w:single); overload;
   constructor Init(vec3:TVec3); overload;
   constructor Init(q:TQuatd); overload;
   procedure Test(var q:TQuaternionS);
   procedure Add(var q:TQuaternionS); overload;
   procedure Add(var q:TQuaternionS;scale:single); overload;
   procedure Middle(var q:TQuaternionS;weight:single);  // interpolate between current value and Q
   procedure Sub(var q:TQuaternionS); overload;
   procedure Mul(scalar:single); overload;
   procedure Mul(var q:TQuaternionS); overload;
   function DotProd(var q:TQuaternionS):single;
   function Length:single;
   function Length2:single; // Square length
   procedure Normalize;
   function IsValid:boolean;
   case integer of
    1:( x,y,z,w:single; );
    2:( v:array[0..3] of single; );
    3:( xyz:TVec3; t:single; );
  end;

  TVector4=TQuatd;
  PVector4=^TVector4;
  TVector4s=TQuaternionS;
  TVec4=TQuaternionS;
  PVector4s=^TVector4s;

  // Infinite plane in space
  TPlane=packed record
   a,b,c,d:double;
   class function Init(const point,normal:TVec3d):TPlane; static;
   function Offset(const pnt:TVec3d):double; inline;
  end;
  TQuaternion=TQuatd deprecated 'Use TQuatd';

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
  TMatrix3=TMat3d deprecated 'Use TMat3d';
  TMatrix43=TMat34d deprecated 'Use TMat34d';
  TMatrix4=TMat4d deprecated 'Use TMat4d';
  PMatrix4s=^TMatrix4s;
  TMatrix4s=array[0..3,0..3] of single; // rotation/scale/translation
  TMat4=TMatrix4s;
  // Synonims
  TMatrix3v=array[0..2] of TVec3d;
  TMatrix43v=array[0..3] of TVec3d;

  // Low precision matrices
  PMatrix3s=^TMatrix3s;
  TMatrix3s=array[0..2,0..2] of single;
  TMat3=TMatrix3s;
  PMatrix43s=^TMatrix43s;
  TMatrix43s=array[0..3,0..2] of single;
  TMat34=TMatrix43s;
  // Synonims
  TMatrix3vs=array[0..2] of TVec3;
  TMatrix43vs=array[0..3] of TVec3;

 const
  NaN=0.0/0.0;
  IdentMatrix3:TMat3d=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix3s:TMatrix3s=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix43:TMat34d=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix43s:TMatrix43s=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix4:TMat4d=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));
  IdentMatrix4s:TMatrix4s=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));

  NullPoint:TVec3d=(x:0;y:0;z:0);
  NullPointS:TVec3=(x:0;y:0;z:0);
  InvalidPoint3:TVec3d=(x:NaN;y:NaN;z:NaN);
  InvalidPoint3s:TVec3=(x:NaN;y:NaN;z:NaN);

 function Point3(x,y,z:double):TVec3d; overload; inline;
 function Point3s(x,y,z:single):TVec3; overload; inline;
 function Point3(p:TVec3):TVec3d; overload; inline;
 function Point3s(p:TVec3d):TVec3; overload; inline;
 function Vector3(x,y,z:double):TVec3d; overload; inline;
 function Vector3s(x,y,z:single):TVec3; overload; inline;
 function Vector3(from,target:TVec3d):TVec3d; overload; inline;
 function Vector3s(from,target:TVec3):TVec3; overload; inline;
 function Vector3s(vector:TVec3d):TVec3; overload; inline;
 function Vector4(vector:TVec3d):TVector4; overload; inline;
 function Vector4s(vector:TVec3):TVec4; overload; inline;
 function Quaternion(x,y,z,w:double):TQuatd; overload; inline;
 function QuaternionS(x,y,z,w:single):TQuaternionS; overload; inline;
 // Matrix conversion
 function Matrix4(from:TMat34d):TMat4d; overload;
 function Matrix4(from:TMat4):TMat4d; overload;
 function Matrix4s(from:TMat34):TMat4; overload;
 function Matrix4s(from:TMat4d):TMat4; overload;
 function Matrix3(from:TMat4d):TMat3d; overload;
 function Matrix3s(from:TMat3d):TMat3; overload;
 function Matrix3s(from:TMat4d):TMat3; overload;
 function Matrix3s(from:TMat4):TMat3; overload;

 // Extract matrix row/column
 function MatRow(const mat:TMat4; n:integer):TQuaternionS; overload; inline;
 function MatRow(const mat:TMat4d;  n:integer):TQuatd;  overload; inline;
 function MatRow(const mat:TMat34;n:integer):TVec3; overload; inline;
 function MatRow(const mat:TMat3; n:integer):TVec3; overload; inline;
 function MatCol(const mat:TMat4; n:integer):TQuaternionS; overload;
 function MatCol(const mat:TMat4d;  n:integer):TQuatd; overload;
 function MatCol(const mat:TMat34;n:integer):TVec3; overload;
 function MatCol(const mat:TMat3; n:integer):TVec3; overload;

 // Скалярное произведение векторов = произведение длин на косинус угла = проекция одного вектора на другой
 function DotProduct(a,b:TVec3d):double; overload;
 function DotProduct(a,b:TVec3):double; overload;
 // Векторное произведение: модуль равен площади ромба
 function CrossProduct(a,b:TVec3d):TVec3d; overload;
 function CrossProduct(a,b:TVec3):TVec3; overload;
 function GetLength(v:TVec3d):double; overload;
 function GetLength(v:TVec3):double; overload;
 function GetSqrLength(v:TVec3d):double; overload;
 function GetSqrLength(v:TVec3):single; overload;
 procedure Normalize(var v:TVec3d); overload;
 procedure Normalize(var v:TVec3); overload;
 procedure VectAdd(var a:TVec3d;b:TVec3d); overload;
 procedure VectAdd(var a:TVec3;b:TVec3); overload;
 procedure VectSub(var a:TVec3d;b:TVec3d);
 procedure VectMult(var a:TVec3d;k:double); overload;
 procedure VectMult(var a:TVec3;k:double); overload;
 function VecMult(a:TVec3d;k:double):TVec3d; overload;
 function VecMult(a:TVec3;k:double):TVec3; overload;
 function PointAdd(p:TVec3d;v:TVec3d;factor:double=1.0):TVec3d; overload; inline;
 function PointAdd(p:TVec3;v:TVec3;factor:single=1.0):TVec3; overload; inline;
 function Distance(p1,p2:TVec3d):double; overload;
 function Distance(p1,p2:TVec3):single; overload;
 function Distance2(p1,p2:TVec3d):double; overload;
 function Distance2(p1,p2:TVec3):single; overload;

 procedure PointBetween(const p1,p2:TVec3d;t:double;out p:TVec3d); overload;
 procedure PointBetween(const p1,p2:TVec3;t:single;out p:TVec3); overload;

 function IsNearS(a,b:TVec3):single;
 function IsNear(a,b:TVec3d):double;

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
 function IsEqual(v1,v2:TVector4;precision:single=2.0):boolean; overload; inline;

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
 function TranslationMat4(x,y,z:double):TMat4d;
 function TranslationMat4s(x,y,z:single):TMat4;
 function RotationXMat(angle:double):TMat34d;
 function RotationYMat(angle:double):TMat34d;
 function RotationZMat(angle:double):TMat34d;
 function RotationXMat3s(angle:single):TMat3;
 function RotationYMat3s(angle:single):TMat3;
 function RotationZMat3s(angle:single):TMat3;
 function RotationXMat4s(angle:single):TMat4;
 function RotationYMat4s(angle:single):TMat4;
 function RotationZMat4s(angle:single):TMat4;
 function ScaleMat(scaleX,scaleY,scaleZ:double):TMat34d;
 function ScaleMat4s(scaleX,scaleY,scaleZ:single):TMat4;

 // Матрица поворота вокруг вектора единичной длины!
 function RotationAroundVector(v:TVec3d;angle:double):TMat3d; overload;
 function RotationAroundVector(v:TVec3;angle:single):TMat3; overload;

 // Build rotation matrix from a NORMALIZED quaternion
 procedure MatrixFromQuaternion(const q:TQuatd;out mat:TMat3d); overload;
 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMat3); overload;
 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMat4); overload;
 procedure QuaternionToMatrix(const q:TQuatd;out mat:TMat3d); overload; inline; // alias
 procedure QuaternionToMatrix(const q:TQuaternionS;out mat:TMat3); overload; inline; // alias

 // Convert an ORTHOGONAL matrix to quaternion
 function MatrixToQuaternion(const mat:TMat3):TQuaternionS; overload;
 function MatrixToQuaternion(const mat:TMat3d):TQuatd; overload;

 // Extract translation rotation and scale from transformation matrix
 procedure DecomposeMatrix(mat:TMat4;out translation,rotation,scale:TQuaternionS); overload;
 procedure DecomposeMatrix(mat:TMat4d;out translation,rotation,scale:TQuatd); overload;
 procedure DecomposeMartix(mat:TMat4;out translation,rotation,scale:TQuaternionS); overload; deprecated 'Use DecomposeMatrix';
 procedure DecomposeMartix(mat:TMat4d;out translation,rotation,scale:TQuatd); overload; deprecated 'Use DecomposeMatrix';

 // Quaternion operations
 function QLength(q:TQuatd):double; overload;
 function QLength(q:TQuaternionS):single; overload;

 procedure QScale(var q:TQuatd;val:double); overload;
 procedure QScale(var q:TQuaternionS;val:single); overload;

 procedure QNormalize(var q:TQuatd); overload;
 procedure QNormalize(var q:TQuaternionS); overload;

 function QInvert(q:TQuatd):TQuatd; overload;
 function QInvert(q:TQuaternionS):TQuaternionS; overload;

 function QMult(q1,q2:TQuatd):TQuatd; overload;
 function QMult(q1,q2:TQuaternionS):TQuaternionS; overload;

 // SLERP (!??) linear interpolation from Q1 to Q2 with factor changing from 0 to 1 (factor=0 -> Q1; factor=1 -> Q2)
 function QInterpolate(Q1,Q2:TQuaternionS;factor:single):TQuaternionS;


 // Используется правосторонняя СК, ось Z - вверх.
 // roll - поворот вокруг X
 // pitch - затем поворот вокруг Y
 // yaw - наконец, поворот вокруг Z
 procedure MatrixFromYawRollPitch(out mat:TMat3d;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMat3;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMat4d;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMat4;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMat34d;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMat34;yaw,roll,pitch:double); overload;

 procedure YawRollPitchFromMatrix(const mat:TMat34d; var yaw,roll,pitch:double);

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

 procedure MultPnt(const m:TMat4;v:PVector4s;num,step:integer); overload;
 procedure MultPnt(const m:TMat34d;v:PPoint3;num,step:integer); overload;
 procedure MultPnt(const m:TMat34;v:Ppoint3s;num,step:integer); overload;
 procedure MultPnt(const m:TMat3d;v:PPoint3;num,step:integer); overload;
 procedure MultPnt(const m:TMat3;v:Ppoint3s;num,step:integer); overload;
 // Same as MultPnt, but ignores the translation part
 procedure MultNormal(const m:TMat4;v:PVector4s;num,step:integer);

 // Complete 3D transformation (with normalization)
 function TransformPoint(const m:TMat4;v:PPoint3s):TVec3; overload;
 function TransformPoint(const m:TMat4d;v:PPoint3):TVec3d; overload;

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

 // Planes
 procedure InitPlane(point,normal:TVec3d;var p:TPlane);
 function GetPlaneOffset(p:TPlane;pnt:TVec3d):double;

 // Special
 // пересечение треугольника ABC с лучом OT
 // возвращает: pb,pc - выражение точки пересечения через вектора AB и AC (pb,pc>=0, pb+pc<=1)
 //             d - расстояние от точки пересечения до начала луча
 function IntersectTrgLine(A,B,C,O,T:PPoint3s;var pb,pc,d:double):boolean;

implementation
 uses Apus.Core, Apus.CPU, Apus.Types, SysUtils, Math;

 const
  vec0001s:TVector4s=(x:0; y:0; z:0; w:1);

  // Compensation for stack frame allocation in x64 mode
  RSP_BIAS = {$IFDEF FPC} 0 {$ELSE} 8 {$ENDIF};

 function Point3(x,y,z:double):TVec3d; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Point3s(x,y,z:single):TVec3; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Point3(p:TVec3):TVec3d; overload; inline;
  begin
   result.x:=p.x;
   result.y:=p.y;
   result.z:=p.z;
  end;

 function Point3s(p:TVec3d):TVec3; overload; inline;
  begin
   result.x:=p.x;
   result.y:=p.y;
   result.z:=p.z;
  end;

 function Vector3(x,y,z:double):TVec3d;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vector3s(x,y,z:single):TVec3;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vector3(from,target:TVec3d):TVec3d; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vector3s(from,target:TVec3):TVec3; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vector3s(vector:TVec3d):TVec3; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
  end;

 function Vector4(vector:TVec3d):TVector4; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Vector4s(vector:TVec3):TVec4; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Quaternion(x,y,z,w:double):TQuatd; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;

 function QuaternionS(x,y,z,w:single):TQuaternionS; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
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

 function Matrix4s(from:TMat34):TMat4;
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

 function Matrix4s(from:TMat4d):TMat4;
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

 function Matrix3s(from:TMat4):TMat3; overload;
  begin
   move(from[0],result[0],sizeof(result[0]));
   move(from[1],result[1],sizeof(result[1]));
   move(from[2],result[2],sizeof(result[2]));
  end;

 function Matrix3s(from:TMat3d):TMat3; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function Matrix3s(from:TMat4d):TMat3; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function MatRow(const mat:TMat4; n:integer):TQuaternionS;
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

 function MatCol(const mat:TMat4; n:integer):TQuaternionS;
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

 function DotProduct(a,b:TVec3d):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;

 function DotProduct(a,b:TVec3):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;

 function CrossProduct(a,b:TVec3d):TVec3d;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;

 function CrossProduct(a,b:TVec3):TVec3;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;

 function GetLength(v:TVec3d):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;

 function GetLength(v:TVec3):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;

 function GetSqrLength(v:TVec3d):double;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;

 function GetSqrLength(v:TVec3):single;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;

 procedure Normalize(var v:TVec3d);
  var
   l:double;
  begin
   l:=GetLength(v);
   ASSERT(l>Epsilon,'Normalize zero-length vector');
   l:=1/l;
   v.x:=v.x*l;
   v.y:=v.y*l;
   v.z:=v.z*l;
  end;

 procedure Normalize(var v:TVec3);
  var
   l:single;
  begin
   l:=GetLength(v);
   ASSERT(l>EpsilonS,'Normalize zero-length vector');
   l:=1/l;
   v.x:=v.x*l;
   v.y:=v.y*l;
   v.z:=v.z*l;
  end;

 procedure VectAdd(var a:TVec3d;b:TVec3d);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;

 procedure VectAdd(var a:TVec3;b:TVec3);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;

 procedure VectSub(var a:TVec3d;b:TVec3d);
  begin
   a.x:=a.x-b.x;
   a.y:=a.y-b.y;
   a.z:=a.z-b.z;
  end;

 procedure VectMult(var a:TVec3d;k:double);
  begin
   a.x:=a.x*k;
   a.y:=a.y*k;
   a.z:=a.z*k;
  end;

 procedure VectMult(var a:TVec3;k:double);
  begin
   a.x:=a.x*k;
   a.y:=a.y*k;
   a.z:=a.z*k;
  end;

  function VecMult(a:TVec3d;k:double):TVec3d;
  begin
   result.x:=a.x*k;
   result.y:=a.y*k;
   result.z:=a.z*k;
  end;

  function VecMult(a:TVec3;k:double):TVec3;
  begin
   result.x:=a.x*k;
   result.y:=a.y*k;
   result.z:=a.z*k;
  end;

 function PointAdd(p:TVec3d;v:TVec3d;factor:double=1.0):TVec3d; inline;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
   result.z:=p.z+v.z*factor;
  end;
 function PointAdd(p:TVec3;v:TVec3;factor:single=1.0):TVec3; overload; inline;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
   result.z:=p.z+v.z*factor;
  end;

 function Distance(p1,p2:TVec3d):double; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z));
  end;

 function Distance(p1,p2:TVec3):single; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z));
  end;

 function Distance2(p1,p2:TVec3d):double; overload;
  begin
   result:=sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z);
  end;

 function Distance2(p1,p2:TVec3):single; overload;
  begin
   result:=sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z);
  end;

 procedure PointBetween(const p1,p2:TVec3d;t:double;out p:TVec3d); overload;
  var
   nt:double;
  begin
   nt:=1-t;
   p.x:=p1.x*nt+p2.x*t;
   p.y:=p1.y*nt+p2.y*t;
   p.z:=p1.z*nt+p2.z*t;
  end;

 procedure PointBetween(const p1,p2:TVec3;t:single;out p:TVec3); overload;
  var
   nt:single;
  begin
   nt:=1-t;
   p.x:=p1.x*nt+p2.x*t;
   p.y:=p1.y*nt+p2.y*t;
   p.z:=p1.z*nt+p2.z*t;
  end;

 function IsNearS(a,b:TVec3):single;
  var
   d:single;
  begin
   result:=abs(a.x-b.x);
   d:=abs(a.y-b.y);
   if d>result then result:=d;
   d:=abs(a.z-b.z);
   if d>result then result:=d;
  end;

 function IsNear(a,b:TVec3d):double;
  var
   d:double;
  begin
   result:=abs(a.x-b.x);
   d:=abs(a.y-b.y);
   if d>result then result:=d;
   d:=abs(a.z-b.z);
   if d>result then result:=d;
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

 function IsEqual(v1,v2:TVector4;precision:single=2.0):boolean; overload; inline;
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
   am1:TMatrix3s absolute m1;
   am2:TMatrix3s absolute m2;
   am3:TMatrix3s absolute target;
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
   mv:TMatrix43v absolute m;
  begin
   Transpose(m1,m2);
   dest[3,0]:=-DotProduct(mv[0],mv[3]);
   dest[3,1]:=-DotProduct(mv[1],mv[3]);
   dest[3,2]:=-DotProduct(mv[2],mv[3]);
  end;
 procedure Transpose(const m:TMat34;out dest:TMat34);
  var
   m1:TMatrix3s absolute m;
   m2:TMatrix3s absolute dest;
   mv:TMatrix43vs absolute m;
  begin
   Transpose(m1,m2);
   dest[3,0]:=-DotProduct(mv[0],mv[3]);
   dest[3,1]:=-DotProduct(mv[1],mv[3]);
   dest[3,2]:=-DotProduct(mv[2],mv[3]);
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
   mv:TMatrix3v absolute m;
  begin
   la:=GetSqrLength(mv[0]);
   lb:=GetSqrLength(mv[1]);
   lc:=GetSqrLength(mv[2]);
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
   mv:TMatrix43v absolute m;
  begin
   la:=GetSqrLength(mv[0]);
   lb:=GetSqrLength(mv[1]);
   lc:=GetSqrLength(mv[2]);
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
   mv:TMatrix43vs absolute m;
  begin
   la:=GetSqrLength(mv[0]);
   lb:=GetSqrLength(mv[1]);
   lc:=GetSqrLength(mv[2]);
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
   dest:=IdentMatrix4;
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
   mat:TMatrix4s;
   i,k:integer;
   v:single;
  begin
   mat:=m;
   dest:=IdentMatrix4s;
   for i:=0 to 3 do begin
     v:=mat[i,i];
     if abs(v)<EpsilonS then begin // fix zero diagonal element
      for k:=i+1 to 3 do
       if abs(mat[k,i])>EpsilonS then begin
        TVector4s(dest[i]).Add(TVector4s(dest[k]),1);
        TVector4s(mat[i]).Add(TVector4s(mat[k]),1);
        break;
       end;
      v:=mat[i,i];
      if v=0 then raise Exception.Create('Cannot invert matrix!');
     end;
     v:=1/v;
     TVector4s(mat[i]).Mul(v);
     TVector4s(dest[i]).Mul(v);

     for k:=i+1 to 3 do begin
      v:=-mat[k,i];
      TVector4s(dest[k]).Add(TVector4s(dest[i]),v);
      TVector4s(mat[k]).Add(TVector4s(mat[i]),v);
     end;
    end;
   for i:=3 downto 1 do
    for k:=i-1 downto 0 do
     TVector4s(dest[k]).Add(TVector4s(dest[i]),-mat[k,i]);
  end;

 procedure MultPnt(const m:TMat4;v:PVector4s;num,step:integer); overload;
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
   vec:TVector4s;
  begin
   for i:=1 to num do begin
    vec.x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+v.w*m[3,0];
    vec.y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+v.w*m[3,1];
    vec.z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+v.w*m[3,2];
    vec.w:=v^.x*m[0,3]+v^.y*m[1,3]+v^.z*m[2,3]+v.w*m[3,3];

    v^:=vec;
    v:=PVector4s(PtrUInt(v)+step);
   end;
  end;
  {$ENDIF}

 // Ignore translation part
 procedure MultNormal(const m:TMat4;v:PVector4s;num,step:integer);
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
   vec:TVector4s;
  begin
   for i:=1 to num do begin
    vec.x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    vec.y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    vec.z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    vec.w:=1.0;

    v^:=vec;
    v:=PVector4s(PtrUInt(v)+step);
   end;
  end;
  {$ENDIF}


 procedure MultPnt(const m:TMat34d;v:PPoint3;num,step:integer);
  var
   i:integer;
   x,y,z:double;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+m[3,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+m[3,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+m[3,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PPoint3(PtrUInt(v)+step);
   end;
  end;

 procedure MultPnt(const m:TMat34;v:PPoint3s;num,step:integer);
  var
   i:integer;
   x,y,z:single;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0]+m[3,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1]+m[3,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2]+m[3,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PPoint3s(PtrUInt(v)+step);
   end;
  end;

 procedure MultPnt(const m:TMat3d;v:PPoint3;num,step:integer);
  var
   i:integer;
   x,y,z:double;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PPoint3(PtrUInt(v)+step);
   end;
  end;
 procedure MultPnt(const m:TMat3;v:Ppoint3s;num,step:integer);
  var
   i:integer;
   x,y,z:single;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PPoint3s(PtrUInt(v)+step);
   end;
  end;

 function TransformPoint(const m:TMat4;v:PPoint3s):TVec3; overload;
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
    result:=InvalidPoint3s;
  end;

 function TransformPoint(const m:TMat4d;v:PPoint3):TVec3d; overload;
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
   result:=IdentMatrix43;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function TranslationMat4(x,y,z:double):TMat4d;
  begin
   result:=IdentMatrix4;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationXMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat(angle:double):TMat34d;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat(scaleX,scaleY,scaleZ:double):TMat34d;
  begin
   result:=IdentMatrix43;
   result[0,0]:=scaleX;
   result[1,1]:=scaleY;
   result[2,2]:=scaleZ;
  end;

 function RotationXMat3s(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat3s(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat3s(angle:single):TMat3;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;


 function TranslationMat4s(x,y,z:single):TMat4;
  begin
   result:=IdentMatrix4s;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationXMat4s(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat4s(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat4s(angle:single):TMat4;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat4s(scaleX,scaleY,scaleZ:single):TMat4;
  begin
   result:=IdentMatrix4s;
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
   Normalize(v);
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

{ function RotationAroundVector(v:TVec3;angle:single):TMatrix3s;
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

 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMat3); overload;
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

 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMat4); overload;
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
   TVector4s(mat[3]):=vec0001s;
  end;

 procedure QuaternionToMatrix(const q:TQuatd;out mat:TMat3d); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;
 procedure QuaternionToMatrix(const q:TQuaternionS;out mat:TMat3); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;

 // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
 function MatrixToQuaternion(const mat:TMat3):TQuaternionS; overload;
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
 procedure DecomposeMatrix(mat:TMat4;out translation,rotation,scale:TQuaternionS);
  var
   qX,qY,qZ:TQuaternionS;
   mat3:TMatrix3s;
   v:single;
  begin
   translation:=MatRow(mat,3);
   qX:=MatRow(mat,0);
   qY:=MatRow(mat,1);
   qZ:=MatRow(mat,2);
   // Scale part
   scale.x:=QLength(qX);
   scale.y:=QLength(qY);
   scale.z:=QLength(qZ);
   scale.w:=0;
   qX.Mul(1/scale.x);
   qY.Mul(1/scale.y);
   qZ.Mul(1/scale.z);
   // Make sure the rotation part is orthogonal
   v:=qY.DotProd(qX);
   if abs(v)>EpsilonS then begin
    qY.Add(qX,-v);
    qY.Normalize;
   end;
   v:=qZ.DotProd(qX);
   if abs(v)>EpsilonS then begin
    qZ.Add(qX,-v);
    qZ.Normalize;
   end;
   v:=qZ.DotProd(qY);
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
   scale.x:=QLength(qX);
   scale.y:=QLength(qY);
   scale.z:=QLength(qZ);
   scale.w:=0;
   qX.Mul(1/scale.x);
   qY.Mul(1/scale.y);
   qZ.Mul(1/scale.z);
   // Make sure the rotation part is orthogonal
   v:=qY.DotProd(qX);
   if abs(v)>EpsilonS then begin
    qY.Add(qX,-v);
    qY.Normalize;
   end;
   v:=qZ.DotProd(qX);
   if abs(v)>EpsilonS then begin
    qZ.Add(qX,-v);
    qZ.Normalize;
   end;
   v:=qZ.DotProd(qY);
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

 procedure DecomposeMartix(mat:TMat4;out translation,rotation,scale:TQuaternionS);
 begin
  DecomposeMatrix(mat,translation,rotation,scale);
 end;

 procedure DecomposeMartix(mat:TMat4d;out translation,rotation,scale:TQuatd);
 begin
  DecomposeMatrix(mat,translation,rotation,scale);
 end;


 function QLength(q:TQuatd):double; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 function QLength(q:TQuaternionS):single; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 procedure QScale(var q:TQuatd;val:double); overload;
  begin
   q.w:=q.w*val;
   q.x:=q.x*val;
   q.y:=q.y*val;
   q.z:=q.z*val;
  end;
 procedure QScale(var q:TQuaternionS;val:single); overload;
  begin
   q.w:=q.w*val;
   q.x:=q.x*val;
   q.y:=q.y*val;
   q.z:=q.z*val;
  end;

 procedure QNormalize(var q:TQuatd); overload;
  begin
   QScale(q,1/QLength(q));
  end;
 procedure QNormalize(var q:TQuaternionS); overload;
  begin
   QScale(q,1/QLength(q));
  end;

 function QInvert(q:TQuatd):TQuatd; overload;
  begin
   result.w:=q.w;
   result.x:=-q.x;
   result.y:=-q.y;
   result.z:=-q.z;
   QNormalize(result);
  end;
 function QInvert(q:TQuaternionS):TQuaternionS; overload;
  begin
   result.w:=q.w;
   result.x:=-q.x;
   result.y:=-q.y;
   result.z:=-q.z;
   QNormalize(result);
  end;

 function QMult(q1,q2:TQuatd):TQuatd; overload;
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
 function QMult(q1,q2:TQuaternionS):TQuaternionS; overload;
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

 function QInterpolate(q1,q2:TQuaternionS;factor:single):TQuaternionS;
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

 function TPlane.Offset(const pnt:TVec3d):double;
  begin
   result:=pnt.x*a+pnt.y*b+pnt.z*c+d;
  end;

 procedure InitPlane(point,normal:TVec3d;var p:TPlane);
  begin
   p:=TPlane.Init(point,normal);
  end;

 function GetPlaneOffset(p:TPlane;pnt:TVec3d):double;
  begin
   result:=p.Offset(pnt);
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


 function IntersectTrgLine(A,B,C,O,T:PPoint3s;var pb,pc,d:double):boolean;
  var
   m:TMat3d;
   mv:TMatrix3v absolute m;
   l:TVec3d;
   dt:double;
  begin
   m[0,0]:=B.x-A.x; m[0,1]:=B.y-A.y; m[0,2]:=B.z-A.z;
   m[1,0]:=C.x-A.x; m[1,1]:=C.y-A.y; m[1,2]:=C.z-A.z;
   m[2,0]:=T.x-O.x; m[2,1]:=T.y-O.y; m[2,2]:=T.z-O.z;
   Normalize(mv[2]);
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

 procedure _MatrixFromYawRollPitch(yaw,roll,pitch:double;m:PDouble;width:integer); inline;
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

 procedure _MatrixFromYawRollPitchS(yaw,roll,pitch:single;m:PSingle;width:integer); inline;
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

 procedure MatrixFromYawRollPitch(out mat:TMat3d;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,3);
  end;

 procedure MatrixFromYawRollPitch(out mat:TMat3;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,3);
  end;

 procedure MatrixFromYawRollPitch(out mat:TMat4d;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMat4;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMat34d;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMat34;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure YawRollPitchFromMatrix(const mat:TMat34d; var yaw,roll,pitch:double);
  var
   v:TVec3d;
   skewA,skewB,skewC:double;
   m,m2:TMat34d;
   mv:TMatrix43v absolute m;
  begin
   m:=mat;
   Normalize(mv[0]);
   Normalize(mv[1]);
   Normalize(mv[2]);
   skewA:=DotProduct(mv[0],mv[1]);
   skewB:=DotProduct(mv[2],mv[0]); // !??
   skewC:=DotProduct(mv[2],mv[1]); // !??
   mv[1].x:=mv[1].x-mv[0].x*skewA;
   mv[1].y:=mv[1].y-mv[0].y*skewA;
   mv[1].z:=mv[1].z-mv[0].z*skewA;
   Normalize(mv[1]);
   mv[2]:=CrossProduct(mv[0],mv[1]);

   v:=mv[0]; v.z:=0;
   if GetSqrLength(v)<0.000001 then Yaw:=0 else begin
    Normalize(v);
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

function TVec3d.IsValid: boolean;
 begin
  result:=x=x;
 end;

procedure TVec3d.Normalize;
 begin
  Apus.Geom3D.Normalize(self);
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

procedure TVec3.Add(p:TVec3);
 begin
  x:=x+p.x; y:=y+p.y; z:=z+p.z;
 end;

constructor TVec3.Init(p0,p1:TVec3;t:single);
 begin
  SetBetween(p0,p1,t);
 end;

procedure TVec3.Normalize;
 begin
  Apus.Geom3D.Normalize(self);
 end;

constructor TVec3.SetBetween(p0,p1:TVec3;t:single);
 var
  t1:single;
 begin
  t1:=1-t;
  x:=p0.x*t1+p1.x*t;
  y:=p0.y*t1+p1.y*t;
  z:=p0.z*t1+p1.z*t;
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

procedure TQuatd.Add(var q:TQuatd;scale:double);
 begin
  x:=x+q.x*scale;
  y:=y+q.y*scale;
  z:=z+q.z*scale;
  w:=w+q.w*scale;
 end;

procedure TQuatd.Add(var q:TQuatd);
 begin
  x:=x+q.x; y:=y+q.y; z:=z+q.z; w:=w+q.w;
 end;

function TQuatd.DotProd(var q:TQuatd):double;
 begin
  result:=x*q.x+y*q.y+z*q.z+w*q.w;
 end;

function TQuatd.Length:double;
 begin
  result:=QLength(self);
 end;

function TQuatd.Length2:double;
 begin
  result:=w*w + x*x + y*y + z*z;
 end;

procedure TQuatd.Mul(scalar:double);
 begin
  QScale(self,scalar);
 end;

procedure TQuatd.Mul(var q:TQuatd);
 begin
  x:=x*q.x;
  y:=y*q.y;
  z:=z*q.z;
  w:=w*q.w;
 end;

procedure TQuatd.Normalize;
 begin
  QNormalize(self);
 end;

{ TQuaternionS }

constructor TQuaternionS.Init(x, y, z, w: single);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

constructor TQuaternionS.Init(vec3:TVec3);
 begin
  x:=vec3.x; y:=vec3.y; z:=vec3.z; w:=0;
 end;

constructor TQuaternionS.Init(q:TQuatd);
 begin
  x:=q.x; y:=q.y; z:=q.z; w:=q.w;
 end;

function TQuaternionS.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TQuaternionS.Test;
 begin
  self:=q;
 end;

function TQuaternionS.Length:single;
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
  result:=QLength(self);
 end;
 {$ENDIF}

function TQuaternionS.Length2:single;
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


procedure TQuaternionS.Normalize;
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
  QNormalize(self);
 end;
 {$ENDIF}


procedure TQuaternionS.Sub(var q:TQuaternionS);
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

procedure TQuaternionS.Add(var q:TQuaternionS);
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

procedure TQuaternionS.Add(var q:TQuaternionS;scale:single);
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

procedure TQuaternionS.Middle(var q:TQuaternionS;weight:single);
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

function TQuaternionS.DotProd(var q:TQuaternionS):single;
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

procedure TQuaternionS.Mul(var q:TQuaternionS);
 {$IFDEF CPUx64}
 asm
  {$IFDEF MSWINDOWS}
  // rcx=@self, rdx=@q
  movups xmm0,[rcx]
  mulps xmm0,dqword [q]
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

procedure TQuaternionS.Mul(scalar:single);
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




