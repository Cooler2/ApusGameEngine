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
  PPoint3=^TPoint3;
  PVector3=^TVector3;
  TPoint3=packed record
   x,y,z:double;
   constructor Init(X,Y,Z:double);
   procedure Normalize;
   function IsValid:boolean;
  end;
  TVector3=TPoint3;

  PPoint3s=^TPoint3s;
  TPoint3s=packed record
   constructor Init(X,Y,Z:single); overload;
   constructor Init(p:TPoint3); overload;
   constructor Init(p0,p1:TPoint3s;t:single); overload;
   procedure Normalize;
   function IsValid:boolean;
   function Length:single;  // Vector length
   function Length2:single; // Square length
   procedure Multiply(scalar:single);
   case integer of
   0:( x,y,z:single; );
   1:( v:array[0..2] of single; );
   2:( xy:TPoint2s; t:single; );
  end;
  TVector3s=TPoint3s;

  TQuaternion=record
   constructor Init(x,y,z,w:double);
   procedure Add(var q:TQuaternion); overload;
   procedure Add(var q:TQuaternion;scale:double); overload;
   procedure Mul(scalar:double); overload;
   procedure Mul(var q:TQuaternion); overload;
   function DotProd(var q:TQuaternion):double;
   function Length:double;
   function Length2:double;
   procedure Normalize;
   function IsValid:boolean;
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
    3:( xyz:TPoint3; t:double; );
  end;

  { TQuaternionS }

  TQuaternionS=record
   constructor Init(x,y,z,w:single); overload;
   constructor Init(vec3:TVector3s); overload;
   constructor Init(q:TQuaternion); overload;
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
    3:( xyz:TPoint3s; t:single; );
  end;

  TVector4=TQuaternion;
  PVector4=^TVector4;
  TVector4s=TQuaternionS;
  PVector4s=^TVector4s;

  // Infinite plane in space
  TPlane=packed record
   a,b,c,d:double;
  end;

  // Infinite oriented line in space
  TLine3=packed record
   origin:TPoint3;
   dir:TVector3;
  end;

  // Bounding box with low precision
  TBBox3s=packed record
   minX,minY,minZ,
   maxX,maxY,maxZ:single;
   defined:boolean;
  end;

  // Transformation matrices
  PMatrix3=^TMatrix3;
  TMatrix3=array[0..2,0..2] of double; // Rotation/scale
  PMatrix43=^TMatrix43;
  TMatrix43=array[0..3,0..2] of double; // rotation/scale/translation
  PMatrix4=^TMatrix4;
  TMatrix4=array[0..3,0..3] of double; // rotation/scale/translation
  PMatrix4s=^TMatrix4s;
  TMatrix4s=array[0..3,0..3] of single; // rotation/scale/translation
  // Synonims
  TMatrix3v=array[0..2] of TVector3;
  TMatrix43v=array[0..3] of TVector3;

  // Low precision matrices
  PMatrix3s=^TMatrix3s;
  TMatrix3s=array[0..2,0..2] of single;
  PMatrix43s=^TMatrix43s;
  TMatrix43s=array[0..3,0..2] of single;
  // Synonims
  TMatrix3vs=array[0..2] of TVector3s;
  TMatrix43vs=array[0..3] of TVector3s;

 const
  NaN=0.0/0.0;
  IdentMatrix3:TMatrix3=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix3s:TMatrix3s=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix43:TMatrix43=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix43s:TMatrix43s=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix4:TMatrix4=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));
  IdentMatrix4s:TMatrix4s=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));

  InvalidPoint3:TPoint3=(x:NaN;y:NaN;z:NaN);
  InvalidPoint3s:TPoint3s=(x:NaN;y:NaN;z:NaN);

 function Point3(x,y,z:double):TPoint3; overload; inline;
 function Point3s(x,y,z:single):TPoint3s; overload; inline;
 function Point3(p:TPoint3s):TPoint3; overload; inline;
 function Point3s(p:TPoint3):TPoint3s; overload; inline;
 function Vector3(x,y,z:double):TVector3; overload; inline;
 function Vector3s(x,y,z:single):TVector3s; overload; inline;
 function Vector3(from,target:TPoint3):TVector3; overload; inline;
 function Vector3s(from,target:TPoint3s):TVector3s; overload; inline;
 function Vector3s(vector:TVector3):TVector3s; overload; inline;
 function Vector4(vector:TVector3):TVector4; overload; inline;
 function Vector4s(vector:TVector3s):TVector4s; overload; inline;
 function Quaternion(x,y,z,w:double):TQuaternion; overload; inline;
 function QuaternionS(x,y,z,w:single):TQuaternionS; overload; inline;
 // Matrix conversion
 function Matrix4(from:TMatrix43):TMatrix4; overload;
 function Matrix4(from:TMatrix4s):TMatrix4; overload;
 function Matrix4s(from:TMatrix43s):TMatrix4s; overload;
 function Matrix4s(from:TMatrix4):TMatrix4s; overload;
 function Matrix3(from:TMatrix4):TMatrix3; overload;
 function Matrix3s(from:TMatrix3):TMatrix3s; overload;
 function Matrix3s(from:TMatrix4):TMatrix3s; overload;
 function Matrix3s(from:TMatrix4s):TMatrix3s; overload;

 // Extract matrix row/column
 function MatRow(const mat:TMatrix4s; n:integer):TQuaternionS; overload; inline;
 function MatRow(const mat:TMatrix4;  n:integer):TQuaternion;  overload; inline;
 function MatRow(const mat:TMatrix43s;n:integer):TVector3s; overload; inline;
 function MatRow(const mat:TMatrix3s; n:integer):TVector3s; overload; inline;
 function MatCol(const mat:TMatrix4s; n:integer):TQuaternionS; overload;
 function MatCol(const mat:TMatrix4;  n:integer):TQuaternion; overload;
 function MatCol(const mat:TMatrix43s;n:integer):TVector3s; overload;
 function MatCol(const mat:TMatrix3s; n:integer):TVector3s; overload;

 // Скалярное произведение векторов = произведение длин на косинус угла = проекция одного вектора на другой
 function DotProduct(a,b:TVector3):double; overload;
 function DotProduct(a,b:TVector3s):double; overload;
 // Векторное произведение: модуль равен площади ромба
 function CrossProduct(a,b:TVector3):TVector3; overload;
 function CrossProduct(a,b:TVector3s):TVector3s; overload;
 function GetLength(v:TVector3):double; overload;
 function GetLength(v:TVector3s):double; overload;
 function GetSqrLength(v:TVector3):double; overload;
 function GetSqrLength(v:TVector3s):single; overload;
 procedure Normalize(var v:TVector3); overload;
 procedure Normalize(var v:TVector3s); overload;
 procedure VectAdd(var a:TVector3;b:TVector3); overload;
 procedure VectAdd(var a:TVector3s;b:TVector3s); overload;
 procedure VectSub(var a:TVector3;b:TVector3);
 procedure VectMult(var a:TVector3;k:double); overload;
 procedure VectMult(var a:TVector3s;k:double); overload;
 function VecMult(a:TVector3;k:double):TVector3; overload;
 function VecMult(a:TVector3s;k:double):TVector3s; overload;
 function PointAdd(p:TPoint3;v:TVector3;factor:double=1.0):TPoint3; overload; inline;
 function PointAdd(p:TPoint3s;v:TVector3s;factor:single=1.0):TPoint3s; overload; inline;
 function Distance(p1,p2:TPoint3):double; overload;
 function Distance(p1,p2:TPoint3s):single; overload;
 function Distance2(p1,p2:TPoint3):double; overload;
 function Distance2(p1,p2:TPoint3s):single; overload;

 procedure PointBetween(const p1,p2:TPoint3;t:double;out p:TPoint3); overload;
 procedure PointBetween(const p1,p2:TPoint3s;t:single;out p:TPoint3s); overload;

 function IsNearS(a,b:TPoint3s):single;
 function IsNear(a,b:TPoint3):double;

 // Compare with tolerance
 function IsZero(v:TPoint3):boolean; overload; inline;
 function IsZero(v:TPoint3s):boolean; overload; inline;
 function IsIdentity(v:TVector3s):boolean; overload; inline;
 function IsIdentity(m:TMatrix43):boolean; overload;
 function IsIdentity(m:TMatrix43s):boolean; overload;

 function IsEqual(d1,d2:double):boolean; overload; inline;
 function IsEqual(s1,s2:single):boolean; overload; inline;

 function IsEqual(v1,v2:TVector3s;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TVector4s;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TVector3;precision:single=2.0):boolean; overload; inline;
 function IsEqual(v1,v2:TVector4;precision:single=2.0):boolean; overload; inline;

 function IsEqual(m1,m2:TMatrix4;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMatrix4s;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMatrix43;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMatrix3;precision:single=4.0):boolean; overload; inline;
 function IsEqual(m1,m2:TMatrix3s;precision:single=4.0):boolean; overload; inline;

 function CompareSingle(s1,s2:PSingle;count:integer;precision:single=1.0):boolean;
 function CompareDouble(s1,s2:PDouble;count:integer;precision:single=1.0):boolean;

 // Convert matrix to single precision
 procedure ToSingle43(sour:TMatrix43;out dest:TMatrix43s);

 function TranslationMat(x,y,z:double):TMatrix43;
 function TranslationMat4(x,y,z:double):TMatrix4;
 function TranslationMat4s(x,y,z:single):TMatrix4s;
 function RotationXMat(angle:double):TMatrix43;
 function RotationYMat(angle:double):TMatrix43;
 function RotationZMat(angle:double):TMatrix43;
 function RotationXMat3s(angle:single):TMatrix3s;
 function RotationYMat3s(angle:single):TMatrix3s;
 function RotationZMat3s(angle:single):TMatrix3s;
 function RotationXMat4s(angle:single):TMatrix4s;
 function RotationYMat4s(angle:single):TMatrix4s;
 function RotationZMat4s(angle:single):TMatrix4s;
 function ScaleMat(scaleX,scaleY,scaleZ:double):TMatrix43;
 function ScaleMat4s(scaleX,scaleY,scaleZ:single):TMatrix4s;

 // Матрица поворота вокруг вектора единичной длины!
 function RotationAroundVector(v:TVector3;angle:double):TMatrix3; overload;
 function RotationAroundVector(v:TVector3s;angle:single):TMatrix3s; overload;

 // Build rotation matrix from a NORMALIZED quaternion
 procedure MatrixFromQuaternion(const q:TQuaternion;out mat:TMatrix3); overload;
 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMatrix3s); overload;
 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMatrix4s); overload;
 procedure QuaternionToMatrix(const q:TQuaternion;out mat:TMatrix3); overload; inline; // alias
 procedure QuaternionToMatrix(const q:TQuaternionS;out mat:TMatrix3s); overload; inline; // alias

 // Convert an ORTHOGONAL matrix to quaternion
 function MatrixToQuaternion(const mat:TMatrix3s):TQuaternionS; overload;
 function MatrixToQuaternion(const mat:TMatrix3):TQuaternion; overload;

 // Extract translation rotation and scale from transformation matrix
 procedure DecomposeMartix(mat:TMatrix4s;out translation,rotation,scale:TQuaternionS); overload;
 procedure DecomposeMartix(mat:TMatrix4;out translation,rotation,scale:TQuaternion); overload;

 // Quaternion operations
 function QLength(q:TQuaternion):double; overload;
 function QLength(q:TQuaternionS):single; overload;

 procedure QScale(var q:TQuaternion;val:double); overload;
 procedure QScale(var q:TQuaternionS;val:single); overload;

 procedure QNormalize(var q:TQuaternion); overload;
 procedure QNormalize(var q:TQuaternionS); overload;

 function QInvert(q:TQuaternion):TQuaternion; overload;
 function QInvert(q:TQuaternionS):TQuaternionS; overload;

 function QMult(q1,q2:TQuaternion):TQuaternion; overload;
 function QMult(q1,q2:TQuaternionS):TQuaternionS; overload;

 // SLERP (!??) linear interpolation from Q1 to Q2 with factor changing from 0 to 1
 function QInterpolate(q1,q2:TQuaternionS;factor:single):TQuaternionS;


 // Используется правосторонняя СК, ось Z - вверх.
 // roll - поворот вокруг X
 // pitch - затем поворот вокруг Y
 // yaw - наконец, поворот вокруг Z
 procedure MatrixFromYawRollPitch(out mat:TMatrix3;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMatrix3s;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMatrix4;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMatrix4s;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMatrix43;yaw,roll,pitch:double); overload;
 procedure MatrixFromYawRollPitch(out mat:TMatrix43s;yaw,roll,pitch:double); overload;

 procedure YawRollPitchFromMatrix(const mat:TMatrix43; var yaw,roll,pitch:double);

 // Combined transformation M = M3*M2*M1 means do M1 then M2 and finally M3
 // target = M1*M2 (Смысл: перевести репер M1 из системы M2 в ту, где задана M2)
 // Другой смысл: суммарная трансформация: сперва M2, затем M1 (именно так!)
 // IMPORTANT! target MUST DIFFER from m1 and m2!
 procedure MultMat(const m1,m2:TMatrix3;out target:TMatrix3); overload;
 procedure MultMat(const m1,m2:TMatrix3s;out target:TMatrix3s); overload;
 procedure MultMat(const m1,m2:TMatrix43;out target:TMatrix43); overload;
 procedure MultMat(const m1,m2:TMatrix43s;out target:TMatrix43s); overload;
 procedure MultMat(const m1,m2:TMatrix4;out target:TMatrix4); overload;
 procedure MultMat(const m1,m2:TMatrix4s;out target:TMatrix4s); overload;
 function  MultMat(const m1,m2:TMatrix43):TMatrix43; overload;
 function  MultMat(const m1,m2:TMatrix4):TMatrix4; overload;
 function  MultMat(const m1,m2:TMatrix4s):TMatrix4s; overload;

 procedure MultPnt(const m:TMatrix4s;v:PVector4s;num,step:integer); overload;
 procedure MultPnt(const m:TMatrix43;v:PPoint3;num,step:integer); overload;
 procedure MultPnt(const m:TMatrix43s;v:Ppoint3s;num,step:integer); overload;
 procedure MultPnt(const m:TMatrix3;v:PPoint3;num,step:integer); overload;
 procedure MultPnt(const m:TMatrix3s;v:Ppoint3s;num,step:integer); overload;
 // Same as MultPnt, but ignores the translation part
 procedure MultNormal(const m:TMatrix4s;v:PVector4s;num,step:integer);

 // Complete 3D transformation (with normalization)
 function TransformPoint(const m:TMatrix4s;v:PPoint3s):TPoint3s; overload;
 function TransformPoint(const m:TMatrix4;v:PPoint3):TPoint3; overload;

 // Transpose (для ортонормированной матрицы - это будт обратная)
 procedure Transpose(const m:TMatrix3;out dest:TMatrix3); overload;
 procedure Transpose(const m:TMatrix3s;out dest:TMatrix3s); overload;
 procedure Transpose(const m:TMatrix43;out dest:TMatrix43); overload;
 procedure Transpose(const m:TMatrix43s;out dest:TMatrix43s); overload;
 procedure Transpose(const m:TMatrix4;out dest:TMatrix4); overload;
 procedure Transpose(var m:TMatrix4); overload;
 procedure Transpose(var m:TMatrix4s); overload;
 procedure Transpose(var m:TMatrix3); overload;
 procedure Transpose(var m:TMatrix3s); overload;

 // Calculate inverted matrix (for Orthogonal atrix only!)
 procedure Invert(const m:TMatrix3;out dest:TMatrix3); overload;
 procedure Invert(const m:TMatrix43;out dest:TMatrix43); overload;
 procedure Invert(const m:TMatrix43s;out dest:TMatrix43s); overload;
 // Complete inversion using Gauss method
 procedure InvertFull(const m:TMatrix4;out dest:TMatrix4); overload;
 procedure InvertFull(const m:TMatrix4s;out dest:TMatrix4s); overload;

 function Det(const m:TMatrix3):double; overload;
 function Det(const m:TMatrix3s):single; overload;
 function Det(const m:TMatrix4):double; overload;
 function Det(const m:TMatrix4s):single; overload;

 // Bounding boxes
 procedure BBoxInclude(var b:TBBox3s;x,y,z:single);
 procedure BBoxIncludePnt(var b:TBBox3s;p:TPoint3);
 procedure BBoxIncludeBox(var b:TBBox3s;new:TBBox3s);
 procedure BBoxIntersect(var b:TBBox3s;new:TBBox3s);

 // Planes
 procedure InitPlane(point,normal:TVector3;var p:TPlane);
 function GetPlaneOffset(p:TPlane;pnt:Tpoint3):double;

 // Special
 // пересечение треугольника ABC с лучом OT
 // возвращает: pb,pc - выражение точки пересечения через вектора AB и AC (pb,pc>=0, pb+pc<=1)
 //             d - расстояние от точки пересечения до начала луча
 function IntersectTrgLine(A,B,C,O,T:PPoint3s;var pb,pc,d:double):boolean;

implementation
 uses Apus.CPU, Apus.Types, SysUtils, Math;

 const
  vec0001s:TVector4s=(x:0; y:0; z:0; w:1);

  // Compensation for stack frame allocation in x64 mode
  RSP_BIAS = {$IFDEF FPC} 0 {$ELSE} 8 {$ENDIF};


 procedure Swap(a,b:single); overload; inline;
  var
   t:single;
  begin
   t:=a; a:=b; b:=t;
  end;

 procedure Swap(a,b:double); overload; inline;
  var
   t:double;
  begin
   t:=a; a:=b; b:=t;
  end;

 function Point3(x,y,z:double):TPoint3; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Point3s(x,y,z:single):TPoint3s; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Point3(p:TPoint3s):TPoint3; overload; inline;
  begin
   result.x:=p.x;
   result.y:=p.y;
   result.z:=p.z;
  end;

 function Point3s(p:TPoint3):TPoint3s; overload; inline;
  begin
   result.x:=p.x;
   result.y:=p.y;
   result.z:=p.z;
  end;

 function Vector3(x,y,z:double):TVector3;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vector3s(x,y,z:single):TVector3s;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vector3(from,target:TPoint3):TVector3; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vector3s(from,target:TPoint3s):TVector3s; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vector3s(vector:TVector3):TVector3s; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
  end;

 function Vector4(vector:TVector3):TVector4; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Vector4s(vector:TVector3s):TVector4s; overload; inline;
  begin
   result.x:=vector.x;
   result.y:=vector.y;
   result.z:=vector.z;
   result.w:=1;
  end;

 function Quaternion(x,y,z,w:double):TQuaternion; overload; inline;
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

 function Matrix4(from:TMatrix43):TMatrix4;
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

 function Matrix4s(from:TMatrix43s):TMatrix4s;
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

 function Matrix4s(from:TMatrix4):TMatrix4s;
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

 function Matrix4(from:TMatrix4s):TMatrix4;
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

 function Matrix3(from:TMatrix4):TMatrix3; overload;
  begin
   move(from[0],result[0],sizeof(result[0]));
   move(from[1],result[1],sizeof(result[1]));
   move(from[2],result[2],sizeof(result[2]));
  end;

 function Matrix3s(from:TMatrix4s):TMatrix3s; overload;
  begin
   move(from[0],result[0],sizeof(result[0]));
   move(from[1],result[1],sizeof(result[1]));
   move(from[2],result[2],sizeof(result[2]));
  end;

 function Matrix3s(from:TMatrix3):TMatrix3s; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function Matrix3s(from:TMatrix4):TMatrix3s; overload;
  var
   i:integer;
  begin
   for i:=0 to 2 do begin
    result[i,0]:=from[i,0];
    result[i,1]:=from[i,1];
    result[i,2]:=from[i,2];
   end;
  end;

 function MatRow(const mat:TMatrix4s; n:integer):TQuaternionS;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMatrix4; n:integer):TQuaternion;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMatrix43s;n:integer):TVector3s;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatRow(const mat:TMatrix3s; n:integer):TVector3s;
  begin
   move(mat[n],result,sizeof(result));
  end;

 function MatCol(const mat:TMatrix4s; n:integer):TQuaternionS;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
   result.w:=mat[3,n];
  end;

 function MatCol(const mat:TMatrix4; n:integer):TQuaternion;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
   result.w:=mat[3,n];
  end;

 function MatCol(const mat:TMatrix43s;n:integer):TVector3s;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
  end;

 function MatCol(const mat:TMatrix3s; n:integer):TVector3s;
  begin
   result.x:=mat[0,n];
   result.y:=mat[1,n];
   result.z:=mat[2,n];
  end;

 function DotProduct(a,b:TVector3):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;

 function DotProduct(a,b:TVector3s):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;

 function CrossProduct(a,b:TVector3):TVector3;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;

 function CrossProduct(a,b:TVector3s):TVector3s;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;

 function GetLength(v:TVector3):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;

 function GetLength(v:TVector3s):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;

 function GetSqrLength(v:TVector3):double;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;

 function GetSqrLength(v:TVector3s):single;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;

 procedure Normalize(var v:TVector3);
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

 procedure Normalize(var v:TVector3s);
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

 procedure VectAdd(var a:TVector3;b:TVector3);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;

 procedure VectAdd(var a:TVector3s;b:TVector3s);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;

 procedure VectSub(var a:TVector3;b:TVector3);
  begin
   a.x:=a.x-b.x;
   a.y:=a.y-b.y;
   a.z:=a.z-b.z;
  end;

 procedure VectMult(var a:TVector3;k:double);
  begin
   a.x:=a.x*k;
   a.y:=a.y*k;
   a.z:=a.z*k;
  end;

 procedure VectMult(var a:TVector3s;k:double);
  begin
   a.x:=a.x*k;
   a.y:=a.y*k;
   a.z:=a.z*k;
  end;

  function VecMult(a:TVector3;k:double):TVector3;
  begin
   result.x:=a.x*k;
   result.y:=a.y*k;
   result.z:=a.z*k;
  end;

  function VecMult(a:TVector3s;k:double):TVector3s;
  begin
   result.x:=a.x*k;
   result.y:=a.y*k;
   result.z:=a.z*k;
  end;

 function PointAdd(p:TPoint3;v:TVector3;factor:double=1.0):TPoint3; inline;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
   result.z:=p.z+v.z*factor;
  end;
 function PointAdd(p:TPoint3s;v:TVector3s;factor:single=1.0):TPoint3s; overload; inline;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
   result.z:=p.z+v.z*factor;
  end;

 function Distance(p1,p2:TPoint3):double; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z));
  end;

 function Distance(p1,p2:TPoint3s):single; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z));
  end;

 function Distance2(p1,p2:TPoint3):double; overload;
  begin
   result:=sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z);
  end;

 function Distance2(p1,p2:TPoint3s):single; overload;
  begin
   result:=sqr(p2.x-p1.x)+sqr(p2.y-p1.y)+sqr(p2.z-p1.z);
  end;

 procedure PointBetween(const p1,p2:TPoint3;t:double;out p:TPoint3); overload;
  var
   nt:double;
  begin
   nt:=1-t;
   p.x:=p1.x*nt+p2.x*t;
   p.y:=p1.y*nt+p2.y*t;
   p.z:=p1.z*nt+p2.z*t;
  end;

 procedure PointBetween(const p1,p2:TPoint3s;t:single;out p:TPoint3s); overload;
  var
   nt:single;
  begin
   nt:=1-t;
   p.x:=p1.x*nt+p2.x*t;
   p.y:=p1.y*nt+p2.y*t;
   p.z:=p1.z*nt+p2.z*t;
  end;

 function IsNearS(a,b:TPoint3s):single;
  var
   d:single;
  begin
   result:=abs(a.x-b.x);
   d:=abs(a.y-b.y);
   if d>result then result:=d;
   d:=abs(a.z-b.z);
   if d>result then result:=d;
  end;

 function IsNear(a,b:TPoint3):double;
  var
   d:double;
  begin
   result:=abs(a.x-b.x);
   d:=abs(a.y-b.y);
   if d>result then result:=d;
   d:=abs(a.z-b.z);
   if d>result then result:=d;
  end;

 function IsZero(v:TPoint3):boolean; overload;
  begin
   result:=not ((abs(v.x)>Epsilon) and (abs(v.y)>Epsilon) and (abs(v.z)>Epsilon));
  end;
 function IsZero(v:TPoint3s):boolean; overload;
  begin
   result:=not ((abs(v.x)>EpsilonS) and (abs(v.y)>EpsilonS) and (abs(v.z)>EpsilonS));
  end;

 function IsIdentity(v:TVector3s):boolean; inline;
  begin
   result:=((abs(v.x-1.0)<EpsilonS) and (abs(v.y-1.0)<EpsilonS) and (abs(v.z-1.0)<EpsilonS));
  end;

 function IsIdentity(m:TMatrix43):boolean; overload;
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
 function IsIdentity(m:TMatrix43s):boolean; overload;
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

 function IsEqual(v1,v2:TVector3s;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareSingle(@v1,@v2,3,precision);
  end;

 function IsEqual(v1,v2:TVector4s;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareSingle(@v1,@v2,4,precision);
  end;

 function IsEqual(v1,v2:TVector3;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareDouble(@v1,@v2,3,precision);
  end;

 function IsEqual(v1,v2:TVector4;precision:single=2.0):boolean; overload; inline;
  begin
    result:=CompareDouble(@v1,@v2,4,precision);
  end;

 function IsEqual(m1,m2:TMatrix4;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,16,precision);
  end;

 function IsEqual(m1,m2:TMatrix4s;precision:single=4.0):boolean; overload;
  begin
    result:=CompareSingle(@m1,@m2,16,precision);
  end;

 function IsEqual(m1,m2:TMatrix43;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,12,precision);
  end;

 function IsEqual(m1,m2:TMatrix3;precision:single=4.0):boolean; overload;
  begin
    result:=CompareDouble(@m1,@m2,9,precision);
  end;

 function IsEqual(m1,m2:TMatrix3s;precision:single=4.0):boolean; overload;
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

 // Bounding box routines
 procedure BBoxInclude(var b:TBBox3s;x,y,z:single);
  begin
   if not b.defined then begin
    b.minx:=x; b.maxx:=x;
    b.miny:=y; b.maxy:=y;
    b.minz:=z; b.maxz:=z;
    b.defined:=true; exit;
   end;
   if x<b.minx then b.minx:=x;
   if y<b.miny then b.miny:=y;
   if z<b.minz then b.minz:=z;
   if x>b.maxx then b.maxx:=x;
   if y>b.maxy then b.maxy:=y;
   if z>b.maxz then b.maxz:=z;
  end;
 procedure BBoxIncludePnt(var b:TBBox3s;p:TPoint3);
  begin
   if not b.defined then begin
    b.minx:=p.x; b.maxx:=p.x;
    b.miny:=p.y; b.maxy:=p.y;
    b.minz:=p.z; b.maxz:=p.z;
    b.defined:=true; exit;
   end;
   if p.x<b.minx then b.minx:=p.x;
   if p.y<b.miny then b.miny:=p.y;
   if p.z<b.minz then b.minz:=p.z;
   if p.x>b.maxx then b.maxx:=p.x;
   if p.y>b.maxy then b.maxy:=p.y;
   if p.z>b.maxz then b.maxz:=p.z;
  end;
 procedure BBoxIncludeBox(var b:TBBox3s;new:TBBox3s);
  begin
   if not new.defined then exit;
   if not b.defined then b:=new;
   if new.minx<b.minx then b.minx:=new.minx;
   if new.miny<b.miny then b.miny:=new.miny;
   if new.minz<b.minz then b.minz:=new.minz;
   if new.maxx>b.maxx then b.maxx:=new.maxx;
   if new.maxy>b.maxy then b.maxy:=new.maxy;
   if new.maxz>b.maxz then b.maxz:=new.maxz;
  end;
 procedure BBoxIntersect(var b:TBBox3s;new:TBBox3s);
  begin
   if not new.defined then begin
    b.defined:=false; exit;
   end;
   if new.minx>b.minx then b.minx:=new.minx;
   if new.miny>b.miny then b.miny:=new.miny;
   if new.minz>b.minz then b.minz:=new.minz;
   if new.maxx<b.maxx then b.maxx:=new.maxx;
   if new.maxy<b.maxy then b.maxy:=new.maxy;
   if new.maxz<b.maxz then b.maxz:=new.maxz;
   if (b.minx>b.maxx) or (b.miny>b.maxY) or (b.minz>b.maxz) then
    b.defined:=false;
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

 procedure MultMat(const m1,m2:TMatrix3;out target:TMatrix3);
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

 procedure MultMat(const m1,m2:TMatrix3s;out target:TMatrix3s);
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

 procedure MultMat(const m1,m2:TMatrix43;out target:TMatrix43);
  var
   am1:TMatrix3 absolute m1;
   am2:TMatrix3 absolute m2;
   am3:TMatrix3 absolute target;
  begin
   MultMat(am1,am2,am3);
   target[3,0]:=m1[3,0]*m2[0,0] + m1[3,1]*m2[1,0] + m1[3,2]*m2[2,0] + m2[3,0];
   target[3,1]:=m1[3,0]*m2[0,1] + m1[3,1]*m2[1,1] + m1[3,2]*m2[2,1] + m2[3,1];
   target[3,2]:=m1[3,0]*m2[0,2] + m1[3,1]*m2[1,2] + m1[3,2]*m2[2,2] + m2[3,2];
  end;

 procedure MultMat(const m1,m2:TMatrix4;out target:TMatrix4);
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;

 procedure MultMat(const m1,m2:TMatrix4s;out target:TMatrix4s);
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

 function MultMat(const m1,m2:TMatrix43):TMatrix43; overload;
  begin
   MultMat(m1,m2,result);
  end;

 function MultMat(const m1,m2:TMatrix4):TMatrix4; overload;
  begin
   MultMat(m1,m2,result);
  end;

 function MultMat(const m1,m2:TMatrix4s):TMatrix4s; overload;
  begin
   MultMat(m1,m2,result);
  end;


 procedure MultMat(const m1,m2:TMatrix43s;out target:TMatrix43s);
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

 procedure Transpose(const m:TMatrix3;out dest:TMatrix3);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transpose(const m:TMatrix3s;out dest:TMatrix3s);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transpose(const m:TMatrix43;out dest:TMatrix43);
  var
   m1:TMatrix3 absolute m;
   m2:TMatrix3 absolute dest;
   mv:TMatrix43v absolute m;
  begin
   Transpose(m1,m2);
   dest[3,0]:=-DotProduct(mv[0],mv[3]);
   dest[3,1]:=-DotProduct(mv[1],mv[3]);
   dest[3,2]:=-DotProduct(mv[2],mv[3]);
  end;
 procedure Transpose(const m:TMatrix43s;out dest:TMatrix43s);
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
 procedure Transpose(const m:TMatrix4;out dest:TMatrix4);
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

 procedure Transpose(var m:TMatrix4);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
   Swap(m[3,1],m[1,3]);
   Swap(m[3,2],m[2,3]);
   Swap(m[3,3],m[3,3]);
  end;

 procedure Transpose(var m:TMatrix4s);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
   Swap(m[3,1],m[1,3]);
   Swap(m[3,2],m[2,3]);
   Swap(m[3,3],m[3,3]);
  end;

 procedure Transpose(var m:TMatrix3);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
  end;

 procedure Transpose(var m:TMatrix3s);
  begin
   Swap(m[1,0],m[0,1]);
   Swap(m[2,0],m[0,2]);
   Swap(m[2,1],m[1,2]);
  end;

 procedure Invert(const m:TMatrix3;out dest:TMatrix3);
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

 procedure Invert(const m:TMatrix43;out dest:TMatrix43); overload;
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

 procedure Invert(const m:TMatrix43s;out dest:TMatrix43s); overload;
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


 procedure InvertFull(const m:TMatrix4;out dest:TMatrix4);
  var
   mat:TMatrix4;
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

 procedure InvertFull(const m:TMatrix4s;out dest:TMatrix4s);
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

 procedure MultPnt(const m:TMatrix4s;v:PVector4s;num,step:integer); overload;
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
 procedure MultNormal(const m:TMatrix4s;v:PVector4s;num,step:integer);
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


 procedure MultPnt(const m:TMatrix43;v:PPoint3;num,step:integer);
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

 procedure MultPnt(const m:TMatrix43s;v:PPoint3s;num,step:integer);
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

 procedure MultPnt(const m:TMatrix3;v:PPoint3;num,step:integer);
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
 procedure MultPnt(const m:TMatrix3s;v:Ppoint3s;num,step:integer);
  var
   i:integer;
   x,y,z:single;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+v^.z*m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+v^.z*m[2,1];
    z:=v^.x*m[0,2]+v^.y*m[1,2]+v^.z*m[2,2];
    v^.x:=x; v^.y:=y; v^.z:=z;
    v:=PPoint3s(cardinal(v)+step);
   end;
  end;

 function TransformPoint(const m:TMatrix4s;v:PPoint3s):TPoint3s; overload;
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

 function TransformPoint(const m:TMatrix4;v:PPoint3):TPoint3; overload;
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

 function TranslationMat(x,y,z:double):TMatrix43;
  begin
   result:=IdentMatrix43;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function TranslationMat4(x,y,z:double):TMatrix4;
  begin
   result:=IdentMatrix4;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationXMat(angle:double):TMatrix43;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat(angle:double):TMatrix43;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat(angle:double):TMatrix43;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix43;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat(scaleX,scaleY,scaleZ:double):TMatrix43;
  begin
   result:=IdentMatrix43;
   result[0,0]:=scaleX;
   result[1,1]:=scaleY;
   result[2,2]:=scaleZ;
  end;

 function RotationXMat3s(angle:single):TMatrix3s;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat3s(angle:single):TMatrix3s;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[0,0]:=c; result[0,2]:=-s;
   result[2,0]:=s; result[2,2]:=c;
  end;

 function RotationZMat3s(angle:single):TMatrix3s;
  var
   c,s:single;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix3s;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;


 function TranslationMat4s(x,y,z:single):TMatrix4s;
  begin
   result:=IdentMatrix4s;
   result[3,0]:=x; result[3,1]:=y; result[3,2]:=z;
  end;

 function RotationXMat4s(angle:single):TMatrix4s;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[1,1]:=c; result[1,2]:=s;
   result[2,1]:=-s; result[2,2]:=c;
  end;

 function RotationYMat4s(angle:single):TMatrix4s;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[0,0]:=c; result[0,2]:=s;
   result[2,0]:=-s; result[2,2]:=c;
  end;

 function RotationZMat4s(angle:single):TMatrix4s;
  var
   c,s:double;
  begin
   c:=cos(angle); s:=sin(angle);
   result:=IdentMatrix4s;
   result[0,0]:=c; result[0,1]:=s;
   result[1,0]:=-s; result[1,1]:=c;
  end;

 function ScaleMat4s(scaleX,scaleY,scaleZ:single):TMatrix4s;
  begin
   result:=IdentMatrix4s;
   result[0,0]:=scaleX;
   result[1,1]:=scaleY;
   result[2,2]:=scaleZ;
  end;

 function RotationAroundVector(v:TVector3;angle:double):TMatrix3;
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

 function RotationAroundVector(v:TVector3s;angle:single):TMatrix3s;
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

{ function RotationAroundVector(v:TVector3s;angle:single):TMatrix3s;
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

 procedure MatrixFromQuaternion(const q:TQuaternion;out mat:TMatrix3); overload;
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

 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMatrix3s); overload;
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

 procedure MatrixFromQuaternion(const q:TQuaternionS;out mat:TMatrix4s); overload;
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

 procedure QuaternionToMatrix(const q:TQuaternion;out mat:TMatrix3); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;
 procedure QuaternionToMatrix(const q:TQuaternionS;out mat:TMatrix3s); overload;
  begin
   MatrixFromQuaternion(q,mat);
  end;

 // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
 function MatrixToQuaternion(const mat:TMatrix3s):TQuaternionS; overload;
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

 function MatrixToQuaternion(const mat:TMatrix3):TQuaternion; overload;
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
 procedure DecomposeMartix(mat:TMatrix4s;out translation,rotation,scale:TQuaternionS);
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

 procedure DecomposeMartix(mat:TMatrix4;out translation,rotation,scale:TQuaternion);
  var
   qX,qY,qZ:TQuaternion;
   mat3:TMatrix3;
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


 function QLength(q:TQuaternion):double; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 function QLength(q:TQuaternionS):single; overload;
  begin
   result:=Sqrt(q.w*q.w+q.x*q.x+q.y*q.y+q.z*q.z);
  end;

 procedure QScale(var q:TQuaternion;val:double); overload;
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

 procedure QNormalize(var q:TQuaternion); overload;
  begin
   QScale(q,1/QLength(q));
  end;
 procedure QNormalize(var q:TQuaternionS); overload;
  begin
   QScale(q,1/QLength(q));
  end;

 function QInvert(q:TQuaternion):TQuaternion; overload;
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

 function QMult(q1,q2:TQuaternion):TQuaternion; overload;
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
  begin
    // result = q1 + t*(q2-q1)
    result.x:=q1.x+(q2.x-q1.x)*factor;
    result.y:=q1.y+(q2.y-q1.y)*factor;
    result.z:=q1.z+(q2.z-q1.z)*factor;
    result.w:=q1.w+(q2.w-q1.w)*factor;
    QNormalize(result);
  end;

 procedure InitPlane(point,normal:TVector3;var p:TPlane);
  begin
   Normalize(normal);
   p.a:=normal.x;
   p.b:=normal.y;
   p.c:=normal.z;
   p.d:=-(p.a*point.x+p.b*normal.y+p.c*normal.z);
  end;

 function GetPlaneOffset(p:TPlane;pnt:Tpoint3):double;
  begin
   result:=pnt.x*p.a+pnt.y*p.b+pnt.z*p.c+p.d;
  end;

 function Det(const m:TMatrix3):double;
  begin
   result:=m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
           m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
           m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]);
  end;
 function Det(const m:TMatrix3s):single;
  begin
   result:=m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
           m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
           m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]);
  end;

 function Det(const m:TMatrix4):double;
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

 function Det(const m:TMatrix4s):single;
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
   m:TMatrix3;
   mv:TMatrix3v absolute m;
   l:TVector3;
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

 procedure MatrixFromYawRollPitch(out mat:TMatrix3;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,3);
  end;

 procedure MatrixFromYawRollPitch(out mat:TMatrix3s;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,3);
  end;

 procedure MatrixFromYawRollPitch(out mat:TMatrix4;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMatrix4s;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,4);
   mat[0,3]:=0; mat[1,3]:=0; mat[2,3]:=0;
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0; mat[3,3]:=1;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMatrix43;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure MatrixFromYawRollPitch(out mat:TMatrix43s;yaw,roll,pitch:double); overload;
  begin
   _MatrixFromYawRollPitchS(yaw,roll,pitch,@mat,3);
   mat[3,0]:=0; mat[3,1]:=0; mat[3,2]:=0;
  end;

 procedure YawRollPitchFromMatrix(const mat:TMatrix43; var yaw,roll,pitch:double);
  var
   v:TVector3;
   skewA,skewB,skewC:double;
   m,m2:TMatrix43;
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
   // pitch
   if mv[0].x<-0.999 then pitch:=pi else
    Pitch:=arcsin(mv[0].z);
   MultMat(m,RotationYMat(-pitch),m2);
   m:=m2;
   // roll
   if mv[1].y<-0.999 then roll:=pi else begin
    Roll:=arccos(mv[1].y);
    if mv[1].z<0 then roll:=-roll;
   end;
  end;

var
 fSet1,fset2:cardinal;
{ TPoint3 }

constructor TPoint3.Init(X,Y,Z:double);
 begin
  self.x:=X; self.y:=Y; self.z:=Z;
 end;

function TPoint3.IsValid: boolean;
 begin
  result:=x=x;
 end;

procedure TPoint3.Normalize;
 begin
  Apus.Geom3D.Normalize(self);
 end;

{ TPoint3s }
constructor TPoint3s.Init(X,Y,Z:single);
 begin
  self.x:=x; self.y:=y; self.z:=z;
 end;

constructor TPoint3s.Init(p:TPoint3);
 begin
  self.x:=p.x;
  self.y:=p.y;
  self.z:=p.z;
 end;

constructor TPoint3s.Init(p0,p1:TPoint3s;t:single);
 var
  t1:single;
 begin
  t1:=1-t;
  x:=p0.x*t1+p1.x*t;
  y:=p0.y*t1+p1.y*t;
  z:=p0.z*t1+p1.z*t;
 end;

procedure TPoint3s.Normalize;
 begin
  Apus.Geom3D.Normalize(self);
 end;

function TPoint3s.IsValid: boolean;
 begin
  result:=x=x;
 end;

function TPoint3s.Length:single;
 begin
  result:=sqrt(x*x+y*y+z*z);
 end;

function TPoint3s.Length2:single;
 begin
  result:=x*x+y*y+z*z;
 end;

procedure TPoint3s.Multiply(scalar:single);
 begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
 end;

{ TQuaternion }

constructor TQuaternion.Init(x,y,z,w:double);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

function TQuaternion.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TQuaternion.Add(var q:TQuaternion;scale:double);
 begin
  x:=x+q.x*scale;
  y:=y+q.y*scale;
  z:=z+q.z*scale;
  w:=w+q.w*scale;
 end;

procedure TQuaternion.Add(var q:TQuaternion);
 begin
  x:=x+q.x; y:=y+q.y; z:=z+q.z; w:=w+q.w;
 end;

function TQuaternion.DotProd(var q:TQuaternion):double;
 begin
  result:=x*q.x+y*q.y+z*q.z+w*q.w;
 end;

function TQuaternion.Length:double;
 begin
  result:=QLength(self);
 end;

function TQuaternion.Length2:double;
 begin
  result:=w*w + x*x + y*y + z*z;
 end;

procedure TQuaternion.Mul(scalar:double);
 begin
  QScale(self,scalar);
 end;

procedure TQuaternion.Mul(var q:TQuaternion);
 begin
  x:=x*q.x;
  y:=y*q.y;
  z:=z*q.z;
  w:=w*q.w;
 end;

procedure TQuaternion.Normalize;
 begin
  QNormalize(self);
 end;

{ TQuaternionS }

constructor TQuaternionS.Init(x, y, z, w: single);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

constructor TQuaternionS.Init(vec3:TVector3s);
 begin
  x:=vec3.x; y:=vec3.y; z:=vec3.z; w:=0;
 end;

constructor TQuaternionS.Init(q:TQuaternion);
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
