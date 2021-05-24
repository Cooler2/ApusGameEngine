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
unit Apus.Geom3D;
interface
 type
  PPoint3=^TPoint3;
  PVector3=^TVector3;
  TPoint3=packed record
   x,y,z:double;
   constructor Init(X,Y,Z:double);
   procedure Normalize;
  end;
  TVector3=TPoint3;

  PPoint3s=^TPoint3s;
  TPoint3s=packed record
   x,y,z:single;
   constructor Init(X,Y,Z:single);
   procedure Normalize;
  end;
  TVector3s=TPoint3s;

  TQuaternion=record
   constructor Init(x,y,z,w:double);
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
  end;

  TQuaternionS=record
   constructor Init(x,y,z,w:single);
   case integer of
    1:( x,y,z,w:single; );
    2:( v:array[0..3] of single; );
  end;

  TVector4=TQuaternion;
  TVector4s=TQuaternionS;

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
  IdentMatrix3:TMatrix3=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix3s:TMatrix3s=((1,0,0),(0,1,0),(0,0,1));
  IdentMatrix43:TMatrix43=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix43s:TMatrix43s=((1,0,0),(0,1,0),(0,0,1),(0,0,0));
  IdentMatrix4:TMatrix4=((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1));

 function Point3(x,y,z:double):TPoint3; overload; inline;
 function Point3s(x,y,z:single):TPoint3s; overload; inline;
 function Vector3(x,y,z:double):TVector3; overload; inline;
 function Vector3s(x,y,z:single):TVector3s; overload; inline;
 function Vector3(from,target:TPoint3):TVector3; overload; inline;
 function Vector3s(from,target:TPoint3s):TVector3s; overload; inline;
 function Vector3s(vector:TVector3):TVector3s; overload; inline;
 function Quaternion(x,y,z,w:double):TQuaternion; overload; inline;
 function Quaternion(x,y,z,w:single):TQuaternionS; overload; inline;
 // Matrix conversion
 function Matrix4(from:TMatrix43):TMatrix4;
 function Matrix4s(from:TMatrix4):TMatrix4s;
 function Matrix3(from:TMatrix4):TMatrix3; overload;
 function Matrix3s(from:TMatrix3):TMatrix3s; overload;
 function Matrix3s(from:TMatrix4):TMatrix3s; overload;
 function Matrix3s(from:TMatrix4s):TMatrix3s; overload;

 // Скалярное произведение векторов = произведение длин на косинус угла = проекция одного вектора на другой
 function DotProduct3(a,b:TVector3):double; overload;
 function DotProduct3(a,b:TVector3s):double; overload;
 // Векторное произведение: модуль равен площади ромба
 function CrossProduct3(a,b:TVector3):TVector3; overload;
 function CrossProduct3(a,b:TVector3s):TVector3s; overload;
 function GetLength3(v:TVector3):double; overload;
 function GetLength3(v:TVector3s):double; overload;
 function GetSqrLength3(v:TVector3):double; overload;
 function GetSqrLength3(v:TVector3s):single; overload;
 procedure Normalize3(var v:TVector3); overload;
 procedure Normalize3(var v:TVector3s); overload;
 procedure VectAdd3(var a:TVector3;b:TVector3); overload;
 procedure VectAdd3(var a:TVector3s;b:TVector3s); overload;
 procedure VectSub3(var a:TVector3;b:TVector3);
 procedure VectMult(var a:TVector3;k:double); overload;
 procedure VectMult(var a:TVector3s;k:double); overload;
 function Vect3Mult(a:TVector3;k:double):TVector3; overload;
 function Vect3Mult(a:TVector3s;k:double):TVector3s; overload;
 function PointAdd(p:TPoint3;v:TVector3;factor:double=1.0):TPoint3; inline;
 function Distance(p1,p2:TPoint3):double; overload;
 function Distance(p1,p2:TPoint3s):single; overload;
 function Distance2(p1,p2:TPoint3):double; overload;
 function Distance2(p1,p2:TPoint3s):single; overload;

 function IsNearS(a,b:TPoint3s):single;
 function IsNear(a,b:TPoint3):double;
 function IsZero(v:TPoint3):boolean; overload; inline;
 function IsZero(v:TPoint3s):boolean; overload; inline;
 function IsIdentity(v:TVector3s):boolean; overload; inline;
 function IsIdentity(m:TMatrix43):boolean; overload;
 function IsIdentity(m:TMatrix43s):boolean; overload;

 // Convert matrix to single precision
 procedure ToSingle43(sour:TMatrix43;out dest:TMatrix43s);

 function TranslationMat(x,y,z:double):TMatrix43;
 function TranslationMat4(x,y,z:double):TMatrix4;
 function RotationXMat(angle:double):TMatrix43;
 function RotationYMat(angle:double):TMatrix43;
 function RotationZMat(angle:double):TMatrix43;
 function ScaleMat(scaleX,scaleY,scaleZ:double):TMatrix43;

 // Матрица поворота вокруг вектора единичной длины!
 function RotationAroundVector(v:TVector3;angle:double):TMatrix3; overload;
 function RotationAroundVector(v:TVector3s;angle:single):TMatrix3s; overload;

 // Build rotation matrix from a NORMALIZED quaternion
 procedure MatrixFromQuaternion(q:TQuaternion;out mat:TMatrix3); overload;
 procedure MatrixFromQuaternion(q:TQuaternionS;out mat:TMatrix3s); overload;

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

 // SLERP interpolation from Q1 to Q2 with factor changing from 0 to 1
 function QInterpolate(q1,q2:TQuaternionS;factor:single):TQuaternionS;


 // Используется правосторонняя СК, ось Z - вверх.
 // roll - поворот вокруг X
 // pitch - затем поворот вокруг Y
 // yaw - наконец, поворот вокруг Z
 function MatrixFromYawRollPitch(yaw,roll,pitch:double):TMatrix3;
 function MatrixFromYawRollPitch43(yaw,roll,pitch:double):TMatrix43;
 function MatrixFromYawRollPitch4(yaw,roll,pitch:double):TMatrix4;
 procedure YawRollPitchFromMatrix(const mat:TMatrix43; var yaw,roll,pitch:double);

 // Combined transformation M = M3*M2*M1 means do M1 then M2 and finally M3
 // target = M1*M2 (Смысл: перевести репер M1 из системы M2 в ту, где задана M2)
 // Другой смысл: суммарная трансформация: сперва M2, затем M1 (именно так!)
 // IMPORTANT! target MUST DIFFER from m1 and m2!
 procedure MultMat3(const m1,m2:TMatrix3;out target:TMatrix3); overload;
 procedure MultMat3(const m1,m2:TMatrix3s;out target:TMatrix3s); overload;
 procedure MultMat4(const m1,m2:TMatrix43;out target:TMatrix43); overload;
 procedure MultMat4(const m1,m2:TMatrix43s;out target:TMatrix43s); overload;
 procedure MultMat4(const m1,m2:TMatrix4;out target:TMatrix4); overload;
 procedure MultMat4(const m1,m2:TMatrix4s;out target:TMatrix4s); overload;
 function  MultMat4(const m1,m2:TMatrix43):TMatrix43; overload;

 procedure MultPnt4(const m:TMatrix43;v:PPoint3;num,step:integer); overload;
 procedure MultPnt4(const m:TMatrix43s;v:Ppoint3s;num,step:integer); overload;
 procedure MultPnt3(const m:TMatrix3;v:PPoint3;num,step:integer); overload;
 procedure MultPnt3(const m:TMatrix3s;v:Ppoint3s;num,step:integer); overload;

 // Complete 3D transformation (with normalization)
 function TransformPoint(const m:TMatrix4s;v:PPoint3s):TPoint3s; overload;
 function TransformPoint(const m:TMatrix4;v:PPoint3):TPoint3; overload;

 // Transpose (для ортонормированной матрицы - это будт обратная)
 procedure Transp3(const m:TMatrix3;out dest:TMatrix3); overload;
 procedure Transp3(const m:TMatrix3s;out dest:TMatrix3s); overload;
 procedure Transp4(const m:TMatrix43;out dest:TMatrix43); overload;
 procedure Transp4(const m:TMatrix43s;out dest:TMatrix43s); overload;
 procedure Transp4(const m:TMatrix4;out dest:TMatrix4); overload;
 // Вычисление обратной матрицы (осторожно!)
 procedure Invert3(const m:TMatrix3;out dest:TMatrix3);
 procedure Invert4(const m:TMatrix43;out dest:TMatrix43); overload;
 procedure Invert4(const m:TMatrix43s;out dest:TMatrix43s); overload;
 // Complete inversion using Gauss method
 procedure Invert4Full(m:TMatrix4;out dest:TMatrix4);

 function Det(const m:TMatrix3):single;

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
 uses Apus.CrossPlatform,SysUtils,Math,Apus.Geom2D;

 var
  sse,sse2,sse3,ssse3,sse4:boolean;

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
 function Quaternion(x,y,z,w:double):TQuaternion; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;
 function Quaternion(x,y,z,w:single):TQuaternionS; overload; inline;
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

 function DotProduct3(a,b:TVector3):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;
 function DotProduct3(a,b:TVector3s):double;
  begin
   result:=a.x*b.x+a.y*b.y+a.z*b.z;
  end;
 function CrossProduct3(a,b:TVector3):TVector3;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;
 function CrossProduct3(a,b:TVector3s):TVector3s;
  begin
   result.x:=a.y*b.z-a.z*b.y;
   result.y:=-(a.x*b.z-a.z*b.x);
   result.z:=a.x*b.y-a.y*b.x;
  end;
 function GetLength3(v:TVector3):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;
 function GetLength3(v:TVector3s):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;
 function GetSqrLength3(v:TVector3):double;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;
 function GetSqrLength3(v:TVector3s):single;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;
 procedure Normalize3(var v:TVector3);
  var
   l:double;
  begin
   l:=GetLength3(v);
   ASSERT(l>Epsilon,'Normalize zero-length vector');
   v.x:=v.x/l;
   v.y:=v.y/l;
   v.z:=v.z/l;
  end;
 procedure Normalize3(var v:TVector3s);
  var
   l:double;
  begin
   l:=GetLength3(v);
   ASSERT(l>EpsilonS,'Normalize zero-length vector');
   v.x:=v.x/l;
   v.y:=v.y/l;
   v.z:=v.z/l;
  end;
 procedure VectAdd3(var a:TVector3;b:TVector3);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;
 procedure VectAdd3(var a:TVector3s;b:TVector3s);
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
   a.z:=b.z+a.z;
  end;

 procedure VectSub3(var a:TVector3;b:TVector3);
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
  function Vect3Mult(a:TVector3;k:double):TVector3;
  begin
   result.x:=a.x*k;
   result.y:=a.y*k;
   result.z:=a.z*k;
  end;
  function Vect3Mult(a:TVector3s;k:double):TVector3s;
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

 procedure MultMat3(const m1,m2:TMatrix3;out target:TMatrix3);
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

 procedure MultMat3(const m1,m2:TMatrix3s;out target:TMatrix3s);
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

 procedure MultMat4(const m1,m2:TMatrix43;out target:TMatrix43);
  var
   am1:TMatrix3 absolute m1;
   am2:TMatrix3 absolute m2;
   am3:TMatrix3 absolute target;
  begin
   MultMat3(am1,am2,am3);
   target[3,0]:=m1[3,0]*m2[0,0] + m1[3,1]*m2[1,0] + m1[3,2]*m2[2,0] + m2[3,0];
   target[3,1]:=m1[3,0]*m2[0,1] + m1[3,1]*m2[1,1] + m1[3,2]*m2[2,1] + m2[3,1];
   target[3,2]:=m1[3,0]*m2[0,2] + m1[3,1]*m2[1,2] + m1[3,2]*m2[2,2] + m2[3,2];
  end;

 procedure MultMat4(const m1,m2:TMatrix4;out target:TMatrix4);
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;

 procedure MultMat4(const m1,m2:TMatrix4s;out target:TMatrix4s);
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;

 function MultMat4(const m1,m2:TMatrix43):TMatrix43; overload;
  begin
   MultMat4(m1,m2,result);
  end;

 procedure MultMat4(const m1,m2:TMatrix43s;out target:TMatrix43s);
  var
   am1:TMatrix3s absolute m1;
   am2:TMatrix3s absolute m2;
   am3:TMatrix3s absolute target;
  begin
   MultMat3(am1,am2,am3);
   target[3,0]:=m1[3,0]*m2[0,0] + m1[3,1]*m2[1,0] + m1[3,2]*m2[2,0] + m2[3,0];
   target[3,1]:=m1[3,0]*m2[0,1] + m1[3,1]*m2[1,1] + m1[3,2]*m2[2,1] + m2[3,1];
   target[3,2]:=m1[3,0]*m2[0,2] + m1[3,1]*m2[1,2] + m1[3,2]*m2[2,2] + m2[3,2];
  end;

 procedure Transp3(const m:TMatrix3;out dest:TMatrix3);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transp3(const m:TMatrix3s;out dest:TMatrix3s);
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transp4(const m:TMatrix43;out dest:TMatrix43);
  var
   m1:TMatrix3 absolute m;
   m2:TMatrix3 absolute dest;
   mv:TMatrix43v absolute m;
  begin
   Transp3(m1,m2);
   dest[3,0]:=-DotProduct3(mv[0],mv[3]);
   dest[3,1]:=-DotProduct3(mv[1],mv[3]);
   dest[3,2]:=-DotProduct3(mv[2],mv[3]);
  end;
 procedure Transp4(const m:TMatrix43s;out dest:TMatrix43s);
  var
   m1:TMatrix3s absolute m;
   m2:TMatrix3s absolute dest;
   mv:TMatrix43vs absolute m;
  begin
   Transp3(m1,m2);
   dest[3,0]:=-DotProduct3(mv[0],mv[3]);
   dest[3,1]:=-DotProduct3(mv[1],mv[3]);
   dest[3,2]:=-DotProduct3(mv[2],mv[3]);
  end;
 procedure Transp4(const m:TMatrix4;out dest:TMatrix4);
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

 procedure Invert3;
  var
   la,lb,lc:double;
   mv:TMatrix3v absolute m;
  begin
   la:=GetSqrLength3(mv[0]);
   lb:=GetSqrLength3(mv[1]);
   lc:=GetSqrLength3(mv[2]);
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transp3(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;
  end;

 procedure Invert4(const m:TMatrix43;out dest:TMatrix43); overload;
  var
   la,lb,lc:double;
   mv:TMatrix43v absolute m;
  begin
   la:=GetSqrLength3(mv[0]);
   lb:=GetSqrLength3(mv[1]);
   lc:=GetSqrLength3(mv[2]);
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transp4(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;   dest[3,0]:=dest[3,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;   dest[3,1]:=dest[3,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;   dest[3,2]:=dest[3,2]/lc;
  end;

 procedure Invert4(const m:TMatrix43s;out dest:TMatrix43s); overload;
  var
   la,lb,lc:single;
   mv:TMatrix43vs absolute m;
  begin
   la:=GetSqrLength3(mv[0]);
   lb:=GetSqrLength3(mv[1]);
   lc:=GetSqrLength3(mv[2]);
   if (la=0) or (lb=0) or (lc=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transp4(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;   dest[2,0]:=dest[2,0]/la;   dest[3,0]:=dest[3,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;   dest[2,1]:=dest[2,1]/lb;   dest[3,1]:=dest[3,1]/lb;
   dest[0,2]:=dest[0,2]/lc;   dest[1,2]:=dest[1,2]/lc;   dest[2,2]:=dest[2,2]/lc;   dest[3,2]:=dest[3,2]/lc;
  end;

 procedure Invert4Full(m:TMatrix4;out dest:TMatrix4);
  var
   i,k:integer;
   v:double;
  procedure AddRow(src,target:integer;factor:double);
   var
    i:integer;
   begin
    for i:=0 to 3 do begin
     m[target,i]:=m[target,i]+factor*m[src,i];
     dest[target,i]:=dest[target,i]+factor*dest[src,i];
    end;
   end;
  procedure MultRow(row:integer;factor:double);
   var
    i:integer;
   begin
    for i:=0 to 3 do begin
     m[row,i]:=m[row,i]*factor;
     dest[row,i]:=dest[row,i]*factor;
    end;
   end;
  begin
   dest:=IdentMatrix4;
   for i:=0 to 3 do begin
     v:=m[i,i];
     if v=0 then begin
      for k:=i+1 to 3 do
       if m[k,i]<>0 then begin
        AddRow(k,i,1);
        break;
       end;
      v:=m[i,i];
      if v=0 then raise Exception.Create('Cannot invert matrix!');
     end;
     MultRow(i,1/v);
     for k:=i+1 to 3 do
      AddRow(i,k,-m[k,i]);
    end;
   for i:=3 downto 1 do
    for k:=i-1 downto 0 do
     AddRow(i,k,-m[k,i]);
  end;

 procedure MultPnt4(const m:TMatrix43;v:PPoint3;num,step:integer);
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

 procedure MultPnt4(const m:TMatrix43s;v:PPoint3s;num,step:integer);
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

 procedure MultPnt3(const m:TMatrix3;v:PPoint3;num,step:integer);
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
 procedure MultPnt3(const m:TMatrix3s;v:Ppoint3s;num,step:integer);
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
   if (t<>1) and (t<>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
   end;
  end;

 function TransformPoint(const m:TMatrix4;v:PPoint3):TPoint3; overload;
  var
   t:double;
  begin
   result.x:=v.x*m[0,0]+v.y*m[1,0]+v.z*m[2,0]+m[3,0];
   result.y:=v.x*m[0,1]+v.y*m[1,1]+v.z*m[2,1]+m[3,1];
   result.z:=v.x*m[0,2]+v.y*m[1,2]+v.z*m[2,2]+m[3,2];
          t:=v.x*m[0,3]+v.y*m[1,3]+v.z*m[2,3]+m[3,3];
   if (t<>1) and (t<>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
   end;
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
   l2,m2,n2,lm,ln,mn,co,si,nco:single;
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

 procedure MatrixFromQuaternion(q:TQuaternion;out mat:TMatrix3); overload;
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

 procedure MatrixFromQuaternion(q:TQuaternionS;out mat:TMatrix3s); overload;
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
   Normalize3(normal);
   p.a:=normal.x;
   p.b:=normal.y;
   p.c:=normal.z;
   p.d:=-(p.a*point.x+p.b*normal.y+p.c*normal.z);
  end;

 function GetPlaneOffset(p:TPlane;pnt:Tpoint3):double;
  begin
   result:=pnt.x*p.a+pnt.y*p.b+pnt.z*p.c+p.d;
  end;

 function Det(const m:TMatrix3):single;
  begin
   result:=m[0,0]*(m[1,1]*m[2,2]-m[1,2]*m[2,1])-
           m[0,1]*(m[1,0]*m[2,2]-m[1,2]*m[2,0])+
           m[0,2]*(m[1,0]*m[2,1]-m[1,1]*m[2,0]);
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
   Normalize3(mv[2]);
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



 procedure _MatrixFromYawRollPitch(yaw,roll,pitch:double;m:PDouble;width:integer);
  var
   ca,sa,cb,sb,cc,sc:double;
  begin
   ca:=cos(yaw); sa:=sin(yaw);
   cb:=cos(roll); sb:=sin(roll);
   cc:=cos(pitch); sc:=sin(pitch);
   // row 0
   m^:=ca*cb; inc(m);
   m^:=sa*cc-ca*sb*sc; inc(m);
   m^:=sa*sc+ca*sb*cc; inc(m,width-2);
   // row 1
   m^:=-sa*cb; inc(m);
   m^:=ca*cc+sa*sb*sc; inc(m);
   m^:=ca*sc-sa*sb*cc; inc(m,width-2);
   // row 2
   m^:=-sb; inc(m);
   m^:=-cb*sc; inc(m);
   m^:=cb*cc; inc(m,width-2);
  end;

 function MatrixFromYawRollPitch(yaw,roll,pitch:double):TMatrix3;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@result,3);
  end;

 function MatrixFromYawRollPitch43(yaw,roll,pitch:double):TMatrix43;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@result,3);
   result[3,0]:=0;  result[3,1]:=0;  result[3,2]:=0;
  end;

 function MatrixFromYawRollPitch4(yaw,roll,pitch:double):TMatrix4;
  begin
   _MatrixFromYawRollPitch(yaw,roll,pitch,@result,4);
   result[0,3]:=0;  result[1,3]:=0;  result[2,3]:=0;
   result[3,0]:=0;  result[3,1]:=0;  result[3,2]:=0; result[3,3]:=1;
  end;

 procedure YawRollPitchFromMatrix(const mat:TMatrix43; var yaw,roll,pitch:double);
  var
   v:TVector3;
   skewA,skewB,skewC:double;
   m,m2:TMatrix43;
   mv:TMatrix43v absolute m;
  begin
   m:=mat;
   Normalize3(mv[0]);
   Normalize3(mv[1]);
   Normalize3(mv[2]);
   skewA:=DotProduct3(mv[0],mv[1]);
   skewB:=DotProduct3(mv[2],mv[0]); // !??
   skewC:=DotProduct3(mv[2],mv[1]); // !??
   mv[1].x:=mv[1].x-mv[0].x*skewA;
   mv[1].y:=mv[1].y-mv[0].y*skewA;
   mv[1].z:=mv[1].z-mv[0].z*skewA;
   Normalize3(mv[1]);
   mv[2]:=CrossProduct3(mv[0],mv[1]);

   v:=mv[0]; v.z:=0;
   if GetSqrLength3(v)<0.000001 then Yaw:=0 else begin
    Normalize3(v);
    if v.x<-0.999 then Yaw:=pi else begin
     Yaw:=arccos(v.x);
     if v.y<0 then Yaw:=-Yaw;
    end;
    MultMat4(m,RotationZMat(-Yaw),m2);
    m:=m2;
   end;
   // pitch
   if mv[0].x<-0.999 then pitch:=pi else
    Pitch:=arcsin(mv[0].z);
   MultMat4(m,RotationYMat(-pitch),m2);
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

procedure TPoint3.Normalize;
 begin
  Normalize3(self);
 end;

{ TPoint3s }
constructor TPoint3s.Init(X,Y,Z:single);
 begin
  self.x:=x; self.y:=y; self.z:=z;
 end;

procedure TPoint3s.Normalize;
 begin
  Normalize3(self);
 end;

{ TQuaternion }

constructor TQuaternion.Init(x, y, z, w: double);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

constructor TQuaternionS.Init(x, y, z, w: single);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

initialization
 // Определение поддержки SSE
 {$IFDEF CPU386}
 asm
  pushad
  mov eax,1
  cpuid
  mov fSet1,edx
  mov fSet2,ecx
  popad
 end;
 sse:=fset1 and $2000000>0;
 sse2:=fset1 and $4000000>0;
 sse3:=fset2 and 1>0;
 ssse3:=fSet2 and $200>0;
 sse4:=fSet2 and $180000>0;
 {$ENDIF}
 {$IFDEF CPUx64}
 sse:=true;
 {$ENDIF}
// m:=RotationAroundVector(Vector3(0,1,0),1);

end.
