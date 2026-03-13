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
{$INCLUDE defines.inc}
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
   function IsZero:boolean; inline;
   function IsEqual(const p:TVec3d;precision:single=2.0):boolean; inline;
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
   function IsZero:boolean; inline;
   function IsIdentity:boolean; inline; // all components = 1
   function IsEqual(const p:TVec3;precision:single=2.0):boolean; inline;
   function Length:single;
   function Length2:single;
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
  PVec3=^TVec3;
  TVec3Array=array of TVec3;

  TVec4d=record
   constructor Init(x,y,z,w:double); overload;
   constructor Init(vec3:TVec3d); overload;
   function ToVec3d:TVec3d; inline;
   procedure Add(const p:TVec4d); overload;
   procedure Add(const p:TVec4d;scale:double); overload;
   procedure Mul(scalar:double);
   procedure Normalize;
   function Dot(const p:TVec4d):double;
   function Length:double; inline;
   function Length2:double; inline;
   function IsValid:boolean;
   function IsEqual(const p:TVec4d;precision:single=2.0):boolean; inline;
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
    3:( xyz:TVec3d; t:double; );
  end;

  TVec4=record
   constructor Init(x,y,z,w:single); overload;
   constructor Init(vec3:TVec3); overload;
   constructor Init(v:TVec4d); overload; // double to single
   function ToVec3:TVec3; inline;
   procedure Add(const p:TVec4); overload;
   procedure Add(const p:TVec4;scale:single); overload;
   procedure Mul(scalar:single);
   procedure Normalize;
   function Dot(const p:TVec4):single;
   function Length:single; inline;
   function Length2:single; inline;
   function IsValid:boolean;
   function IsEqual(const p:TVec4;precision:single=2.0):boolean; inline;
   case integer of
    1:( x,y,z,w:single; );
    2:( v:array[0..3] of single; );
    3:( xyz:TVec3; t:single; );
  end;

  TQuatd=record
   constructor Init(x,y,z,w:double); overload;
   constructor Init(vec3:TVec3d); overload;
   function ToVec3d:TVec3d; inline;
   class operator Implicit(a:TQuatd):TVec4d;
   class operator Implicit(a:TVec4d):TQuatd;
   procedure Add(const q:TQuatd); overload;
   procedure Add(const q:TQuatd;scale:double); overload;
   procedure Mul(scalar:double); overload;
   procedure Mul(const q:TQuatd); overload;
   procedure Invert;
   function Inverted:TQuatd;
   class operator Multiply(const a,b:TQuatd):TQuatd;
   function Dot(const q:TQuatd):double;
   function Length:double;
   function Length2:double;
   procedure Normalize;
   function IsValid:boolean;
   function IsEqual(const q:TQuatd;precision:single=2.0):boolean; inline;
   case integer of
    1:( x,y,z,w:double; );
    2:( v:array[0..3] of double; );
    3:( xyz:TVec3d; t:double; );
  end;

  TQuat=record
   constructor Init(x,y,z,w:single); overload;
   constructor Init(vec3:TVec3); overload;
   constructor Init(q:TQuatd); overload; // double to single
   function ToVec3:TVec3; inline;
   function ToQuatd:TQuatd; // single to double
   class operator Implicit(a:TQuat):TVec4;
   class operator Implicit(a:TVec4):TQuat;
   procedure Assign(const q:TQuat);
   procedure Add(const q:TQuat); overload;
   procedure Add(const q:TQuat;scale:single); overload;
   procedure Middle(const q:TQuat;weight:single); // interpolate between self and q
   procedure Sub(const q:TQuat);
   procedure Mul(scalar:single); overload;
   procedure Mul(const q:TQuat); overload;
   procedure Invert;
   function Inverted:TQuat;
   class operator Multiply(const a,b:TQuat):TQuat;
   class function Slerp(const q1,q2:TQuat;factor:single):TQuat; static;
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

  PVec4=^TVec4;

  // Infinite plane in 3D space
  TPlane=packed record
   a,b,c,d:double;
   class function Init(const point,normal:TVec3d):TPlane; static;
   function DistanceTo(const pnt:TVec3d):double; overload; inline;
   function DistanceTo(const pnt:TVec3):single; overload; inline;
  end;

  // --- Transformation matrices ---

  // 3x3 rotation/scale (double)
  TMat3d=record
   private
    function GetItem(i,j:integer):double; inline;
    procedure SetItem(i,j:integer;value:double); inline;
   public
    function Row(n:integer):TVec3d; inline;
    function Col(n:integer):TVec3d; inline;
    class function RotationAroundAxis(const v:TVec3d;angle:double):TMat3d; static;
    function Determinant:double;
    procedure TransformPoints(v:PVec3d;num,step:integer);
    class operator Multiply(const a,b:TMat3d):TMat3d;
    class function FromQuaternion(const q:TQuatd):TMat3d; static;
    function ToQuaternion:TQuatd;
    procedure Transpose;
    function Transposed:TMat3d;
    procedure Invert;
    function IsEqual(const m:TMat3d;precision:single=4.0):boolean;
    property Items[i,j:integer]:double read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..2,0..2] of double);
    1:(rows:array[0..2] of TVec3d);
  end;

  // 4x3 rotation/scale/translation (double)
  TMat34d=record
   private
    function GetItem(i,j:integer):double; inline;
    procedure SetItem(i,j:integer;value:double); inline;
   public
    function Row(n:integer):TVec3d; inline;
    function Col(n:integer):TVec3d; inline;
    class function Translation(x,y,z:double):TMat34d; static;
    class function RotationX(angle:double):TMat34d; static;
    class function RotationY(angle:double):TMat34d; static;
    class function RotationZ(angle:double):TMat34d; static;
    class function Scale(scaleX,scaleY,scaleZ:double):TMat34d; static;
    class function FromYRP(yaw,roll,pitch:double):TMat34d; static;
    procedure ToYRP(out yaw,roll,pitch:double);
    procedure TransformPoints(v:PVec3d;num,step:integer);
    class operator Multiply(const a,b:TMat34d):TMat34d;
    procedure Transpose;
    function Transposed:TMat34d;
    procedure Invert;
    function IsIdentity:boolean;
    function IsEqual(const m:TMat34d;precision:single=4.0):boolean;
    property Items[i,j:integer]:double read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..3,0..2] of double);
    1:(rows:array[0..3] of TVec3d);
  end;

  // 4x4 full transform (double)
  TMat4d=record
   private
    function GetItem(i,j:integer):double; inline;
    procedure SetItem(i,j:integer;value:double); inline;
   public
    class function From(const m:TMat34d):TMat4d; static;
    function ToMat3:TMat3d;
    function Row(n:integer):TVec4d; inline;
    function Col(n:integer):TVec4d; inline;
    class function Translation(x,y,z:double):TMat4d; static;
    function Determinant:double;
    procedure Decompose(out translation,rotation,scale:TQuatd);
    function TransformPoint(const v:TVec3d):TVec3d;
    class operator Multiply(const a,b:TMat4d):TMat4d;
    procedure Transpose;
    function Transposed:TMat4d;
    procedure Invert;
    function Inverted:TMat4d;
    function IsEqual(const m:TMat4d;precision:single=4.0):boolean;
    property Items[i,j:integer]:double read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..3,0..3] of double);
    1:(rows:array[0..3] of TVec4d);
  end;

  // Single-precision matrices
  PMat4=^TMat4;

  // 4x4 full transform (single)
  TMat4=record
   private
    function GetItem(i,j:integer):single; inline;
    procedure SetItem(i,j:integer;value:single); inline;
   public
    class function From(const m:TMat4d):TMat4; overload; static;
    function ToMat4d:TMat4d;
    function Row(n:integer):TVec4; inline;
    function Col(n:integer):TVec4; inline;
    class function Translation(x,y,z:single):TMat4; static;
    class function RotationX(angle:single):TMat4; static;
    class function RotationY(angle:single):TMat4; static;
    class function RotationZ(angle:single):TMat4; static;
    class function Scale(scaleX,scaleY,scaleZ:single):TMat4; static;
    class function FromYRP(yaw,roll,pitch:double):TMat4; static;
    function Determinant:single;
    procedure Decompose(out translation,rotation,scale:TQuat);
    procedure Transform(var v:TVec4);
    procedure TransformPoints(v:PVec4;num,step:integer);
    procedure TransformNormals(v:PVec4;num,step:integer);
    function TransformPoint(const v:TVec3):TVec3;
    class operator Multiply(const a,b:TMat4):TMat4;
    class function FromQuaternion(const q:TQuat):TMat4; static;
    procedure Transpose;
    function Transposed:TMat4;
    procedure Invert;
    function Inverted:TMat4;
    function IsEqual(const m:TMat4;precision:single=4.0):boolean;
    property Items[i,j:integer]:single read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..3,0..3] of single);
    1:(rows:array[0..3] of TVec4);
  end;

  // Single-precision matrices
  PMat3=^TMat3;
  TMat3=packed record
   private
    function GetItem(i,j:integer):single; inline;
    procedure SetItem(i,j:integer;value:single); inline;
   public
    class function From(const m:TMat3d):TMat3; overload; static; // double to single
    class function From(const m:TMat4d):TMat3; overload; static; // extract 3x3
    class function From(const m:TMat4):TMat3; overload; static; // extract 3x3
    function ToMat3d:TMat3d; // single to double
    function Row(n:integer):TVec3; inline;
    function Col(n:integer):TVec3; inline;
    class function RotationX(angle:single):TMat3; static;
    class function RotationY(angle:single):TMat3; static;
    class function RotationZ(angle:single):TMat3; static;
    class function RotationAroundAxis(const v:TVec3;angle:single):TMat3; static;
    function Determinant:single;
    procedure TransformPoints(v:PVec3;num,step:integer);
    class operator Multiply(const a,b:TMat3):TMat3;
    class function FromQuaternion(const q:TQuat):TMat3; static;
    function ToQuaternion:TQuat;
    procedure Transpose;
    function Transposed:TMat3;
    procedure Invert;
    function IsEqual(const m:TMat3;precision:single=4.0):boolean;
    property Items[i,j:integer]:single read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..2,0..2] of single);
    1:(rows:array[0..2] of TVec3);
  end;

  PMat34=^TMat34;

  // 4x3 rotation/scale/translation (single)
  TMat34=packed record
   private
    function GetItem(i,j:integer):single; inline;
    procedure SetItem(i,j:integer;value:single); inline;
   public
    class function From(const m:TMat34d):TMat34; static; // double to single
    function Row(n:integer):TVec3; inline;
    function Col(n:integer):TVec3; inline;
    class function FromYRP(yaw,roll,pitch:double):TMat34; static;
    procedure TransformPoints(v:PVec3;num,step:integer);
    class operator Multiply(const a,b:TMat34):TMat34;
    procedure Transpose;
    function Transposed:TMat34;
    procedure Invert;
    function ToMat4:TMat4;
    function IsIdentity:boolean;
    function IsEqual(const m:TMat34;precision:single=4.0):boolean;
    property Items[i,j:integer]:single read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..3,0..2] of single);
    1:(rows:array[0..3] of TVec3);
  end;

const
  {$IFDEF DELPHI}[Align(16)] {$ENDIF}
  identMat4:TMat4     = (v:((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1)));
  identMat4d:TMat4d   = (v:((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1)));
  identMat3d:TMat3d   = (v:((1,0,0),(0,1,0),(0,0,1)));
  identMat3:TMat3     = (v:((1,0,0),(0,1,0),(0,0,1)));
  identMat34d:TMat34d = (v:((1,0,0),(0,1,0),(0,0,1),(0,0,0)));
  identMat34:TMat34   = (v:((1,0,0),(0,1,0),(0,0,1),(0,0,0)));

  NaN=0.0/0.0;

  // Invalid (NaN) vectors
  invalidVec3d:TVec3d = (x:NaN;y:NaN;z:NaN);
  invalidVec3:TVec3   = (x:NaN;y:NaN;z:NaN);

 // --- Vector/quaternion factories ---
 function Vec3(x,y,z:single):TVec3; overload; inline;
 function Vec3(v:TVec3d):TVec3; overload; inline; // double to single
 function Vec3(v:TVec4):TVec3; overload; inline; // extract xyz
 function Vec3(const from,target:TVec3):TVec3; overload; inline; // direction vector (target-from)
 function Vec3Unit(const from,target:TVec3):TVec3; inline; // normalized direction
 function Vec3d(x,y,z:double):TVec3d; overload; inline;
 function Vec3d(v:TVec3):TVec3d; overload; inline; // single to double
 function Vec3d(v:TQuatd):TVec3d; overload; inline; // extract xyz
 function Vec3d(v:TVec4d):TVec3d; overload; inline; // extract xyz
 function Vec4(x,y,z,w:single):TVec4; overload; inline;
 function Vec4(v:TVec3;w:single=1):TVec4; overload; inline;
 function Vec4(v:TVec4d):TVec4; overload; inline;
 function Vec4d(x,y,z,w:double):TVec4d; overload; inline;
 function Vec4d(v:TVec3d;w:double=1):TVec4d; overload; inline;
 function Vec4d(v:TVec4):TVec4d; overload; inline;
 function Quat(x,y,z,w:single):TQuat; overload; inline;
 function Quatd(x,y,z,w:double):TQuatd; overload; inline;
 // --- Scalar comparison ---
 function IsEqual(d1,d2:double):boolean; overload; inline;
 function IsEqual(s1,s2:single):boolean; overload; inline;
 // Low-level array comparison (used internally by IsEqual methods)
 function CompareSingle(s1,s2:PSingle;count:integer;precision:single=1.0):boolean;
 function CompareDouble(s1,s2:PDouble;count:integer;precision:single=1.0):boolean;


implementation
uses Apus.Core, Apus.CPU, Apus.Types, SysUtils, Math;

type
  // Internal aliases for absolute overlays in matrix decomposition
  TMatrix3vd=array[0..2] of TVec3d;
  TMatrix43vd=array[0..3] of TVec3d;
  TMatrix3v=array[0..2] of TVec3;
  TMatrix43v=array[0..3] of TVec3;

procedure _YRPToMatrix(yaw,roll,pitch:double;m:PDouble;width:integer); forward;
procedure _YRPToMatrixS(yaw,roll,pitch:single;m:PSingle;width:integer); forward;
procedure _MatrixToYRPCore(const mat:TMat34d; var yaw,roll,pitch:double); forward;
procedure _TransformVec4PointsByMat4(const m:TMat4;v:PVec4;num,step:integer); overload; forward;
procedure _TransformVec4NormalsByMat4(const m:TMat4;v:PVec4;num,step:integer); forward;
procedure _TransformVec3dPointsByMat34d(const m:TMat34d;v:PVec3d;num,step:integer); overload; forward;
procedure _TransformVec3PointsByMat34(const m:TMat34;v:PVec3;num,step:integer); overload; forward;
procedure _TransformVec3dPointsByMat3d(const m:TMat3d;v:PVec3d;num,step:integer); overload; forward;
procedure _TransformVec3PointsByMat3(const m:TMat3;v:PVec3;num,step:integer); overload; forward;

 const
  vec0001s:TVec4=(x:0; y:0; z:0; w:1);

  // Stack-bias correction used by inline x64 ASM when saving/restoring XMM registers.
  //
  // Why needed:
  // - Delphi x64 and FPC x64 generate different prologue/stack layouts for inline asm.
  // - The same [rsp-..] displacement may address different memory without this correction.
  //
  // Value:
  // - FPC:  0  (no extra bias needed for current prologue shape)
  // - Delphi: 8 (stack layout is shifted by 8 bytes for these slots)
  //
  // How to use:
  // - Include RSP_BIAS in every hardcoded spill/load offset around RSP.
  // - Example:
  //     movdqa [rsp-$10-RSP_BIAS], xmm6
  //     ...
  //     movdqa xmm6, [rsp-$10-RSP_BIAS]
  //   This keeps the save/restore slot identical across compilers.
  RSP_BIAS = {$IFDEF FPC} 0 {$ELSE} 8 {$ENDIF};

 function Vec3(x,y,z:single):TVec3; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vec3(v:TVec3d):TVec3; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
  end;

 function Vec3(v:TVec4):TVec3; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
  end;

 function Vec3(const from,target:TVec3):TVec3; overload; inline;
  begin
   result.x:=target.x-from.x;
   result.y:=target.y-from.y;
   result.z:=target.z-from.z;
  end;

 function Vec3Unit(const from,target:TVec3):TVec3; inline;
  begin
   result:=Vec3(from,target);
   result.Normalize;
  end;

 function Vec3d(x,y,z:double):TVec3d; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
  end;

 function Vec3d(v:TVec3):TVec3d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
  end;

function Vec3d(v:TQuatd):TVec3d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
  end;

 function Vec3d(v:TVec4d):TVec3d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
  end;

 function Vec4(v:TVec3;w:single):TVec4; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
   result.w:=w;
  end;

 function Vec4(x,y,z,w:single):TVec4; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;

 function Vec4(v:TVec4d):TVec4; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
   result.w:=v.w;
  end;

 function Vec4d(v:TVec3d;w:double):TVec4d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
   result.w:=w;
  end;

 function Vec4d(x,y,z,w:double):TVec4d; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;

 function Vec4d(v:TVec4):TVec4d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
   result.z:=v.z;
   result.w:=v.w;
  end;

 function Quat(x,y,z,w:single):TQuat; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;

 function Quatd(x,y,z,w:double):TQuatd; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
   result.z:=z;
   result.w:=w;
  end;

function TMat4d.ToMat3:TMat3d;
begin
  move(v[0],result.v[0],sizeof(result.v[0]));
  move(v[1],result.v[1],sizeof(result.v[1]));
  move(v[2],result.v[2],sizeof(result.v[2]));
end;

class function TMat4d.From(const m:TMat34d):TMat4d;
var
  i:integer;
begin
  for i:=0 to 3 do begin
    result[i,0]:=m[i,0];
    result[i,1]:=m[i,1];
    result[i,2]:=m[i,2];
    result[i,3]:=0;
  end;
  result[3,3]:=1;
end;

function TMat34.ToMat4:TMat4;
var
  i:integer;
begin
  for i:=0 to 3 do begin
    result[i,0]:=v[i,0];
    result[i,1]:=v[i,1];
    result[i,2]:=v[i,2];
    result[i,3]:=0;
  end;
  result[3,3]:=1;
end;

class function TMat4.From(const m:TMat4d):TMat4;
var
  i:integer;
begin
  for i:=0 to 3 do begin
    result[i,0]:=m[i,0];
    result[i,1]:=m[i,1];
    result[i,2]:=m[i,2];
    result[i,3]:=m[i,3];
  end;
end;

function TMat4.ToMat4d:TMat4d;
var
  i:integer;
begin
  for i:=0 to 3 do begin
    result[i,0]:=v[i,0];
    result[i,1]:=v[i,1];
    result[i,2]:=v[i,2];
    result[i,3]:=v[i,3];
  end;
end;

class function TMat3.From(const m:TMat3d):TMat3;
var
  i:integer;
begin
  for i:=0 to 2 do begin
    result[i,0]:=m[i,0];
    result[i,1]:=m[i,1];
    result[i,2]:=m[i,2];
  end;
end;

class function TMat3.From(const m:TMat4d):TMat3;
var
  i:integer;
begin
  for i:=0 to 2 do begin
    result[i,0]:=m[i,0];
    result[i,1]:=m[i,1];
    result[i,2]:=m[i,2];
  end;
end;

class function TMat3.From(const m:TMat4):TMat3;
begin
  move(m.v[0],result.v[0],sizeof(result.v[0]));
  move(m.v[1],result.v[1],sizeof(result.v[1]));
  move(m.v[2],result.v[2],sizeof(result.v[2]));
end;

function TMat3.ToMat3d:TMat3d;
var
  i:integer;
begin
  for i:=0 to 2 do begin
    result[i,0]:=v[i,0];
    result[i,1]:=v[i,1];
    result[i,2]:=v[i,2];
  end;
end;

function Matrix4(from:TMat34d):TMat4d; overload;
begin
  result:=TMat4d.From(from);
end;

function ToMat4(from:TMat34):TMat4; overload;
begin
  result:=from.ToMat4;
end;

function ToMat4(from:TMat4d):TMat4; overload;
begin
  result:=TMat4.From(from);
end;

function Matrix4(from:TMat4):TMat4d; overload;
begin
  result:=from.ToMat4d;
end;

function Matrix3(from:TMat4d):TMat3d; overload;
begin
  result:=from.ToMat3;
end;

function ToMat3(from:TMat4):TMat3; overload;
begin
  result:=TMat3.From(from);
end;

 function ToMat3(from:TMat3d):TMat3; overload;
begin
  result:=TMat3.From(from);
end;

 function ToMat3(from:TMat4d):TMat3; overload;
begin
  result:=TMat3.From(from);
end;

class function TMat3d.RotationAroundAxis(const v:TVec3d;angle:double):TMat3d;
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
  result[0,0]:=l2+(m2+n2)*co; result[0,1]:=lm*nco-v.z*si; result[0,2]:=ln*nco+v.y*si;
  result[1,0]:=lm*nco+v.z*si; result[1,1]:=m2+(l2+n2)*co; result[1,2]:=mn*nco-v.x*si;
  result[2,0]:=ln*nco-v.y*si; result[2,1]:=mn*nco+v.x*si; result[2,2]:=n2+(l2+m2)*co;
end;

function TMat3d.Determinant:double;
begin
  result:=v[0,0]*(v[1,1]*v[2,2]-v[1,2]*v[2,1])-
          v[0,1]*(v[1,0]*v[2,2]-v[1,2]*v[2,0])+
          v[0,2]*(v[1,0]*v[2,1]-v[1,1]*v[2,0]);
end;

class function TMat34d.Translation(x,y,z:double):TMat34d;
begin
  result:=IdentMat34d;
  result[3,0]:=x;
  result[3,1]:=y;
  result[3,2]:=z;
end;

class function TMat34d.RotationX(angle:double):TMat34d;
var
  c,s:double;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat34d;
  result[1,1]:=c;
  result[1,2]:=s;
  result[2,1]:=-s;
  result[2,2]:=c;
end;

class function TMat34d.RotationY(angle:double):TMat34d;
var
  c,s:double;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat34d;
  result[0,0]:=c;
  result[0,2]:=s;
  result[2,0]:=-s;
  result[2,2]:=c;
end;

class function TMat34d.RotationZ(angle:double):TMat34d;
var
  c,s:double;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat34d;
  result[0,0]:=c;
  result[0,1]:=s;
  result[1,0]:=-s;
  result[1,1]:=c;
end;

class function TMat34d.Scale(scaleX,scaleY,scaleZ:double):TMat34d;
begin
  result:=IdentMat34d;
  result[0,0]:=scaleX;
  result[1,1]:=scaleY;
  result[2,2]:=scaleZ;
end;

class function TMat34d.FromYRP(yaw,roll,pitch:double):TMat34d;
begin
  _YRPToMatrix(yaw,roll,pitch,@result,3);
  result[3,0]:=0;
  result[3,1]:=0;
  result[3,2]:=0;
end;

procedure TMat34d.ToYRP(out yaw,roll,pitch:double);
begin
  _MatrixToYRPCore(self,yaw,roll,pitch);
end;

class function TMat4d.Translation(x,y,z:double):TMat4d;
begin
  result:=IdentMat4d;
  result[3,0]:=x;
  result[3,1]:=y;
  result[3,2]:=z;
end;

function TMat4d.Determinant:double;
begin
  result:=0;
  if v[3,3]<>0 then begin
    result:=result+(v[0,0]*(v[1,1]*v[2,2]-v[1,2]*v[2,1])-
                    v[0,1]*(v[1,0]*v[2,2]-v[1,2]*v[2,0])+
                    v[0,2]*(v[1,0]*v[2,1]-v[1,1]*v[2,0]))*v[3,3];
  end;
  if v[2,3]<>0 then begin
    result:=result-(v[0,0]*(v[1,1]*v[3,2]-v[1,2]*v[3,1])-
                    v[0,1]*(v[1,0]*v[3,2]-v[1,2]*v[3,0])+
                    v[0,2]*(v[1,0]*v[3,1]-v[1,1]*v[3,0]))*v[2,3];
  end;
  if v[1,3]<>0 then begin
    result:=result+(v[0,0]*(v[2,1]*v[3,2]-v[2,2]*v[3,1])-
                    v[0,1]*(v[2,0]*v[3,2]-v[2,2]*v[3,0])+
                    v[0,2]*(v[2,0]*v[3,1]-v[2,1]*v[3,0]))*v[1,3];
  end;
  if v[0,3]<>0 then begin
    result:=result-(v[1,0]*(v[2,1]*v[3,2]-v[2,2]*v[3,1])-
                    v[1,1]*(v[2,0]*v[3,2]-v[2,2]*v[3,0])+
                    v[1,2]*(v[2,0]*v[3,1]-v[2,1]*v[3,0]))*v[0,3];
  end;
end;

procedure TMat4d.Decompose(out translation,rotation,scale:TQuatd);
var
  qX,qY,qZ:TVec4d;
  tr:TVec4d;
  mat3:TMat3d;
  v:double;
begin
  tr:=self.Row(3);
  translation:=TQuatd.Init(tr.x,tr.y,tr.z,tr.w);
  qX:=self.Row(0);
  qY:=self.Row(1);
  qZ:=self.Row(2);
  scale.x:=qX.Length;
  scale.y:=qY.Length;
  scale.z:=qZ.Length;
  scale.w:=0;
  qX.Mul(1/scale.x);
  qY.Mul(1/scale.y);
  qZ.Mul(1/scale.z);
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
  move(qX,mat3.rows[0],sizeof(qX));
  move(qY,mat3.rows[1],sizeof(qY));
  move(qZ,mat3.rows[2],sizeof(qZ));
  rotation:=mat3.ToQuaternion;
end;

class function TMat4.Translation(x,y,z:single):TMat4;
begin
  result:=IdentMat4;
  result[3,0]:=x;
  result[3,1]:=y;
  result[3,2]:=z;
end;

class function TMat4.RotationX(angle:single):TMat4;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat4;
  result[1,1]:=c;
  result[1,2]:=s;
  result[2,1]:=-s;
  result[2,2]:=c;
end;

class function TMat4.RotationY(angle:single):TMat4;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat4;
  result[0,0]:=c;
  result[0,2]:=s;
  result[2,0]:=-s;
  result[2,2]:=c;
end;

class function TMat4.RotationZ(angle:single):TMat4;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat4;
  result[0,0]:=c;
  result[0,1]:=s;
  result[1,0]:=-s;
  result[1,1]:=c;
end;

class function TMat4.Scale(scaleX,scaleY,scaleZ:single):TMat4;
begin
  result:=IdentMat4;
  result[0,0]:=scaleX;
  result[1,1]:=scaleY;
  result[2,2]:=scaleZ;
end;

class function TMat4.FromYRP(yaw,roll,pitch:double):TMat4;
begin
  result:=IdentMat4;
  _YRPToMatrixS(yaw,roll,pitch,@result,4);
end;

function TMat4.Determinant:single;
begin
  result:=0;
  if v[3,3]<>0 then begin
    result:=result+(v[0,0]*(v[1,1]*v[2,2]-v[1,2]*v[2,1])-
                    v[0,1]*(v[1,0]*v[2,2]-v[1,2]*v[2,0])+
                    v[0,2]*(v[1,0]*v[2,1]-v[1,1]*v[2,0]))*v[3,3];
  end;
  if v[2,3]<>0 then begin
    result:=result-(v[0,0]*(v[1,1]*v[3,2]-v[1,2]*v[3,1])-
                    v[0,1]*(v[1,0]*v[3,2]-v[1,2]*v[3,0])+
                    v[0,2]*(v[1,0]*v[3,1]-v[1,1]*v[3,0]))*v[2,3];
  end;
  if v[1,3]<>0 then begin
    result:=result+(v[0,0]*(v[2,1]*v[3,2]-v[2,2]*v[3,1])-
                    v[0,1]*(v[2,0]*v[3,2]-v[2,2]*v[3,0])+
                    v[0,2]*(v[2,0]*v[3,1]-v[2,1]*v[3,0]))*v[1,3];
  end;
  if v[0,3]<>0 then begin
    result:=result-(v[1,0]*(v[2,1]*v[3,2]-v[2,2]*v[3,1])-
                    v[1,1]*(v[2,0]*v[3,2]-v[2,2]*v[3,0])+
                    v[1,2]*(v[2,0]*v[3,1]-v[2,1]*v[3,0]))*v[0,3];
  end;
end;

procedure TMat4.Decompose(out translation,rotation,scale:TQuat);
var
  qX,qY,qZ:TVec4;
  tr:TVec4;
  mat3:TMat3;
  v:single;
begin
  tr:=self.Row(3);
  translation:=TQuat.Init(tr.x,tr.y,tr.z,tr.w);
  qX:=self.Row(0);
  qY:=self.Row(1);
  qZ:=self.Row(2);
  scale.x:=qX.Length;
  scale.y:=qY.Length;
  scale.z:=qZ.Length;
  scale.w:=0;
  qX.Mul(1/scale.x);
  qY.Mul(1/scale.y);
  qZ.Mul(1/scale.z);
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
  move(qX,mat3.rows[0],sizeof(qX));
  move(qY,mat3.rows[1],sizeof(qY));
  move(qZ,mat3.rows[2],sizeof(qZ));
  rotation:=mat3.ToQuaternion;
end;

class function TMat3.RotationX(angle:single):TMat3;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat3;
  result[1,1]:=c;
  result[1,2]:=s;
  result[2,1]:=-s;
  result[2,2]:=c;
end;

class function TMat3.RotationY(angle:single):TMat3;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat3;
  result[0,0]:=c;
  result[0,2]:=s;
  result[2,0]:=-s;
  result[2,2]:=c;
end;

class function TMat3.RotationZ(angle:single):TMat3;
var
  c,s:single;
begin
  c:=cos(angle);
  s:=sin(angle);
  result:=IdentMat3;
  result[0,0]:=c;
  result[0,1]:=s;
  result[1,0]:=-s;
  result[1,1]:=c;
end;

class function TMat3.RotationAroundAxis(const v:TVec3;angle:single):TMat3;
var
  vv:TVec3;
  x2,y2,z2:single;
  xy,xz,yz:single;
  co,si,nco:single;
begin
  vv:=v;
  vv.Normalize;
  x2:=sqr(vv.x);
  y2:=sqr(vv.y);
  z2:=sqr(vv.z);
  xy:=vv.x*vv.y;
  xz:=vv.x*vv.z;
  yz:=vv.y*vv.z;
  co:=cos(angle);
  si:=sin(angle);
  nco:=1-co;
  result[0,0]:=co+nco*x2; result[0,1]:=xy*nco+vv.z*si; result[0,2]:=xz*nco-vv.y*si;
  result[1,0]:=xy*nco-vv.z*si; result[1,1]:=co+nco*y2; result[1,2]:=yz*nco+vv.x*si;
  result[2,0]:=xz*nco+vv.y*si; result[2,1]:=yz*nco-vv.x*si; result[2,2]:=co+nco*z2;
end;

function TMat3.Determinant:single;
begin
  result:=v[0,0]*(v[1,1]*v[2,2]-v[1,2]*v[2,1])-
          v[0,1]*(v[1,0]*v[2,2]-v[1,2]*v[2,0])+
          v[0,2]*(v[1,0]*v[2,1]-v[1,1]*v[2,0]);
end;

class function TMat34.FromYRP(yaw,roll,pitch:double):TMat34;
begin
  _YRPToMatrixS(yaw,roll,pitch,@result,3);
  result[3,0]:=0;
  result[3,1]:=0;
  result[3,2]:=0;
end;

procedure TMat3d.TransformPoints(v:PVec3d;num,step:integer);
var
  i:integer;
  x,y,z:double;
begin
  for i:=1 to num do begin
    x:=v^.x*self[0,0]+v^.y*self[1,0]+v^.z*self[2,0];
    y:=v^.x*self[0,1]+v^.y*self[1,1]+v^.z*self[2,1];
    z:=v^.x*self[0,2]+v^.y*self[1,2]+v^.z*self[2,2];
    v^.x:=x;
    v^.y:=y;
    v^.z:=z;
    v:=PVec3d(PtrUInt(v)+step);
  end;
end;

procedure TMat34d.TransformPoints(v:PVec3d;num,step:integer);
var
  i:integer;
  x,y,z:double;
begin
  for i:=1 to num do begin
    x:=v^.x*self[0,0]+v^.y*self[1,0]+v^.z*self[2,0]+self[3,0];
    y:=v^.x*self[0,1]+v^.y*self[1,1]+v^.z*self[2,1]+self[3,1];
    z:=v^.x*self[0,2]+v^.y*self[1,2]+v^.z*self[2,2]+self[3,2];
    v^.x:=x;
    v^.y:=y;
    v^.z:=z;
    v:=PVec3d(PtrUInt(v)+step);
  end;
end;

function TMat4d.TransformPoint(const v:TVec3d):TVec3d;
var
  t:double;
begin
  result.x:=v.x*self[0,0]+v.y*self[1,0]+v.z*self[2,0]+self[3,0];
  result.y:=v.x*self[0,1]+v.y*self[1,1]+v.z*self[2,1]+self[3,1];
  result.z:=v.x*self[0,2]+v.y*self[1,2]+v.z*self[2,2]+self[3,2];
  t:=v.x*self[0,3]+v.y*self[1,3]+v.z*self[2,3]+self[3,3];
  if (t<>1) and (t>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
  end else
  if t<=0 then begin
    result:=InvalidVec3d;
  end;
end;

procedure TMat4.Transform(var v:TVec4);
begin
  _TransformVec4PointsByMat4(self,@v,1,SizeOf(v));
end;

procedure TMat4.TransformPoints(v:PVec4;num,step:integer);
begin
  _TransformVec4PointsByMat4(self,v,num,step);
end;

procedure TMat4.TransformNormals(v:PVec4;num,step:integer);
begin
  _TransformVec4NormalsByMat4(self,v,num,step);
end;

function TMat4.TransformPoint(const v:TVec3):TVec3;
var
  t:single;
begin
  result.x:=v.x*self[0,0]+v.y*self[1,0]+v.z*self[2,0]+self[3,0];
  result.y:=v.x*self[0,1]+v.y*self[1,1]+v.z*self[2,1]+self[3,1];
  result.z:=v.x*self[0,2]+v.y*self[1,2]+v.z*self[2,2]+self[3,2];
  t:=v.x*self[0,3]+v.y*self[1,3]+v.z*self[2,3]+self[3,3];
  if (t<>1) and (t>0) then begin
    result.x:=result.x/t;
    result.y:=result.y/t;
    result.z:=result.z/t;
  end else
  if t<=0 then begin
    result:=InvalidVec3;
  end;
end;

procedure TMat3.TransformPoints(v:PVec3;num,step:integer);
var
  i:integer;
  x,y,z:single;
begin
  for i:=1 to num do begin
    x:=v^.x*self[0,0]+v^.y*self[1,0]+v^.z*self[2,0];
    y:=v^.x*self[0,1]+v^.y*self[1,1]+v^.z*self[2,1];
    z:=v^.x*self[0,2]+v^.y*self[1,2]+v^.z*self[2,2];
    v^.x:=x;
    v^.y:=y;
    v^.z:=z;
    v:=PVec3(PtrUInt(v)+step);
  end;
end;

procedure TMat34.TransformPoints(v:PVec3;num,step:integer);
var
  i:integer;
  x,y,z:single;
begin
  for i:=1 to num do begin
    x:=v^.x*self[0,0]+v^.y*self[1,0]+v^.z*self[2,0]+self[3,0];
    y:=v^.x*self[0,1]+v^.y*self[1,1]+v^.z*self[2,1]+self[3,1];
    z:=v^.x*self[0,2]+v^.y*self[1,2]+v^.z*self[2,2]+self[3,2];
    v^.x:=x;
    v^.y:=y;
    v^.z:=z;
    v:=PVec3(PtrUInt(v)+step);
  end;
end;

function TMat3d.GetItem(i,j:integer):double;
begin
  result:=v[i,j];
end;

procedure TMat3d.SetItem(i,j:integer;value:double);
begin
  v[i,j]:=value;
end;

function TMat3d.Row(n:integer):TVec3d;
begin
  result:=rows[n];
end;

function TMat3d.Col(n:integer):TVec3d;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
end;

function TMat34d.GetItem(i,j:integer):double;
begin
  result:=v[i,j];
end;

procedure TMat34d.SetItem(i,j:integer;value:double);
begin
  v[i,j]:=value;
end;

function TMat34d.Row(n:integer):TVec3d;
begin
  result:=rows[n];
end;

function TMat34d.Col(n:integer):TVec3d;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
end;

function TMat3.GetItem(i,j:integer):single;
begin
  result:=v[i,j];
end;

procedure TMat3.SetItem(i,j:integer;value:single);
begin
  v[i,j]:=value;
end;

function TMat3.Row(n:integer):TVec3;
begin
  result:=rows[n];
end;

function TMat3.Col(n:integer):TVec3;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
end;

function TMat34.GetItem(i,j:integer):single;
begin
  result:=v[i,j];
end;

procedure TMat34.SetItem(i,j:integer;value:single);
begin
  v[i,j]:=value;
end;

function TMat34.Row(n:integer):TVec3;
begin
  result:=rows[n];
end;

function TMat34.Col(n:integer):TVec3;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
end;

class operator TMat3d.Multiply(const a,b:TMat3d):TMat3d;
begin
  result[0,0]:=a[0,0]*b[0,0] + a[0,1]*b[1,0] + a[0,2]*b[2,0];
  result[0,1]:=a[0,0]*b[0,1] + a[0,1]*b[1,1] + a[0,2]*b[2,1];
  result[0,2]:=a[0,0]*b[0,2] + a[0,1]*b[1,2] + a[0,2]*b[2,2];
  result[1,0]:=a[1,0]*b[0,0] + a[1,1]*b[1,0] + a[1,2]*b[2,0];
  result[1,1]:=a[1,0]*b[0,1] + a[1,1]*b[1,1] + a[1,2]*b[2,1];
  result[1,2]:=a[1,0]*b[0,2] + a[1,1]*b[1,2] + a[1,2]*b[2,2];
  result[2,0]:=a[2,0]*b[0,0] + a[2,1]*b[1,0] + a[2,2]*b[2,0];
  result[2,1]:=a[2,0]*b[0,1] + a[2,1]*b[1,1] + a[2,2]*b[2,1];
  result[2,2]:=a[2,0]*b[0,2] + a[2,1]*b[1,2] + a[2,2]*b[2,2];
end;

procedure TMat3d.Transpose;
begin
  Swap(v[1,0],v[0,1]);
  Swap(v[2,0],v[0,2]);
  Swap(v[2,1],v[1,2]);
end;

function TMat3d.Transposed:TMat3d;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat3d.Invert;
var
  la,lb,lc:double;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  lc:=rows[2].Length2;
  if (la=0) or (lb=0) or (lc=0) then
   raise Exception.Create('Cannot invert matrix!');
  Transpose;
  v[0,0]:=v[0,0]/la; v[1,0]:=v[1,0]/la; v[2,0]:=v[2,0]/la;
  v[0,1]:=v[0,1]/lb; v[1,1]:=v[1,1]/lb; v[2,1]:=v[2,1]/lb;
  v[0,2]:=v[0,2]/lc; v[1,2]:=v[1,2]/lc; v[2,2]:=v[2,2]/lc;
end;

class operator TMat3.Multiply(const a,b:TMat3):TMat3;
begin
  result[0,0]:=a[0,0]*b[0,0] + a[0,1]*b[1,0] + a[0,2]*b[2,0];
  result[0,1]:=a[0,0]*b[0,1] + a[0,1]*b[1,1] + a[0,2]*b[2,1];
  result[0,2]:=a[0,0]*b[0,2] + a[0,1]*b[1,2] + a[0,2]*b[2,2];
  result[1,0]:=a[1,0]*b[0,0] + a[1,1]*b[1,0] + a[1,2]*b[2,0];
  result[1,1]:=a[1,0]*b[0,1] + a[1,1]*b[1,1] + a[1,2]*b[2,1];
  result[1,2]:=a[1,0]*b[0,2] + a[1,1]*b[1,2] + a[1,2]*b[2,2];
  result[2,0]:=a[2,0]*b[0,0] + a[2,1]*b[1,0] + a[2,2]*b[2,0];
  result[2,1]:=a[2,0]*b[0,1] + a[2,1]*b[1,1] + a[2,2]*b[2,1];
  result[2,2]:=a[2,0]*b[0,2] + a[2,1]*b[1,2] + a[2,2]*b[2,2];
end;

procedure TMat3.Transpose;
begin
  Swap(v[1,0],v[0,1]);
  Swap(v[2,0],v[0,2]);
  Swap(v[2,1],v[1,2]);
end;

function TMat3.Transposed:TMat3;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat3.Invert;
var
  la,lb,lc:single;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  lc:=rows[2].Length2;
  if (la=0) or (lb=0) or (lc=0) then
   raise Exception.Create('Cannot invert matrix!');
  Transpose;
  v[0,0]:=v[0,0]/la; v[1,0]:=v[1,0]/la; v[2,0]:=v[2,0]/la;
  v[0,1]:=v[0,1]/lb; v[1,1]:=v[1,1]/lb; v[2,1]:=v[2,1]/lb;
  v[0,2]:=v[0,2]/lc; v[1,2]:=v[1,2]/lc; v[2,2]:=v[2,2]/lc;
end;

class operator TMat34d.Multiply(const a,b:TMat34d):TMat34d;
begin
  result[0,0]:=a[0,0]*b[0,0] + a[0,1]*b[1,0] + a[0,2]*b[2,0];
  result[0,1]:=a[0,0]*b[0,1] + a[0,1]*b[1,1] + a[0,2]*b[2,1];
  result[0,2]:=a[0,0]*b[0,2] + a[0,1]*b[1,2] + a[0,2]*b[2,2];
  result[1,0]:=a[1,0]*b[0,0] + a[1,1]*b[1,0] + a[1,2]*b[2,0];
  result[1,1]:=a[1,0]*b[0,1] + a[1,1]*b[1,1] + a[1,2]*b[2,1];
  result[1,2]:=a[1,0]*b[0,2] + a[1,1]*b[1,2] + a[1,2]*b[2,2];
  result[2,0]:=a[2,0]*b[0,0] + a[2,1]*b[1,0] + a[2,2]*b[2,0];
  result[2,1]:=a[2,0]*b[0,1] + a[2,1]*b[1,1] + a[2,2]*b[2,1];
  result[2,2]:=a[2,0]*b[0,2] + a[2,1]*b[1,2] + a[2,2]*b[2,2];
  result[3,0]:=a[3,0]*b[0,0] + a[3,1]*b[1,0] + a[3,2]*b[2,0] + b[3,0];
  result[3,1]:=a[3,0]*b[0,1] + a[3,1]*b[1,1] + a[3,2]*b[2,1] + b[3,1];
  result[3,2]:=a[3,0]*b[0,2] + a[3,1]*b[1,2] + a[3,2]*b[2,2] + b[3,2];
end;

procedure TMat34d.Transpose;
var
  rot:TMat3d;
  tr:TVec3d;
begin
  move(v[0],rot.v[0],sizeof(rot.v));
  rot.Transpose;
  move(rot.v[0],v[0],sizeof(rot.v));
  tr:=rows[3];
  v[3,0]:=-rows[0].Dot(tr);
  v[3,1]:=-rows[1].Dot(tr);
  v[3,2]:=-rows[2].Dot(tr);
end;

function TMat34d.Transposed:TMat34d;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat34d.Invert;
var
  la,lb,lc:double;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  lc:=rows[2].Length2;
  if (la=0) or (lb=0) or (lc=0) then
   raise Exception.Create('Cannot invert matrix!');
  Transpose;
  v[0,0]:=v[0,0]/la; v[1,0]:=v[1,0]/la; v[2,0]:=v[2,0]/la; v[3,0]:=v[3,0]/la;
  v[0,1]:=v[0,1]/lb; v[1,1]:=v[1,1]/lb; v[2,1]:=v[2,1]/lb; v[3,1]:=v[3,1]/lb;
  v[0,2]:=v[0,2]/lc; v[1,2]:=v[1,2]/lc; v[2,2]:=v[2,2]/lc; v[3,2]:=v[3,2]/lc;
end;

class operator TMat34.Multiply(const a,b:TMat34):TMat34;
begin
  result[0,0]:=a[0,0]*b[0,0] + a[0,1]*b[1,0] + a[0,2]*b[2,0];
  result[0,1]:=a[0,0]*b[0,1] + a[0,1]*b[1,1] + a[0,2]*b[2,1];
  result[0,2]:=a[0,0]*b[0,2] + a[0,1]*b[1,2] + a[0,2]*b[2,2];
  result[1,0]:=a[1,0]*b[0,0] + a[1,1]*b[1,0] + a[1,2]*b[2,0];
  result[1,1]:=a[1,0]*b[0,1] + a[1,1]*b[1,1] + a[1,2]*b[2,1];
  result[1,2]:=a[1,0]*b[0,2] + a[1,1]*b[1,2] + a[1,2]*b[2,2];
  result[2,0]:=a[2,0]*b[0,0] + a[2,1]*b[1,0] + a[2,2]*b[2,0];
  result[2,1]:=a[2,0]*b[0,1] + a[2,1]*b[1,1] + a[2,2]*b[2,1];
  result[2,2]:=a[2,0]*b[0,2] + a[2,1]*b[1,2] + a[2,2]*b[2,2];
  result[3,0]:=a[3,0]*b[0,0] + a[3,1]*b[1,0] + a[3,2]*b[2,0] + b[3,0];
  result[3,1]:=a[3,0]*b[0,1] + a[3,1]*b[1,1] + a[3,2]*b[2,1] + b[3,1];
  result[3,2]:=a[3,0]*b[0,2] + a[3,1]*b[1,2] + a[3,2]*b[2,2] + b[3,2];
end;

procedure TMat34.Transpose;
var
  rot:TMat3;
  tr:TVec3;
begin
  move(v[0],rot.v[0],sizeof(rot.v));
  rot.Transpose;
  move(rot.v[0],v[0],sizeof(rot.v));
  tr:=rows[3];
  v[3,0]:=-rows[0].Dot(tr);
  v[3,1]:=-rows[1].Dot(tr);
  v[3,2]:=-rows[2].Dot(tr);
end;

function TMat34.Transposed:TMat34;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat34.Invert;
var
  la,lb,lc:single;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  lc:=rows[2].Length2;
  if (la=0) or (lb=0) or (lc=0) then
   raise Exception.Create('Cannot invert matrix!');
  Transpose;
  v[0,0]:=v[0,0]/la; v[1,0]:=v[1,0]/la; v[2,0]:=v[2,0]/la; v[3,0]:=v[3,0]/la;
  v[0,1]:=v[0,1]/lb; v[1,1]:=v[1,1]/lb; v[2,1]:=v[2,1]/lb; v[3,1]:=v[3,1]/lb;
  v[0,2]:=v[0,2]/lc; v[1,2]:=v[1,2]/lc; v[2,2]:=v[2,2]/lc; v[3,2]:=v[3,2]/lc;
end;

function TMat4d.GetItem(i,j:integer):double;
begin
  result:=v[i,j];
end;

procedure TMat4d.SetItem(i,j:integer;value:double);
begin
  v[i,j]:=value;
end;

function TMat4d.Row(n:integer):TVec4d;
begin
  result:=rows[n];
end;

function TMat4d.Col(n:integer):TVec4d;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
  result.w:=v[3,n];
end;

class operator TMat4d.Multiply(const a,b:TMat4d):TMat4d;
var
  i,j:integer;
begin
  for i:=0 to 3 do
   for j:=0 to 3 do
    result[i,j]:=a[i,0]*b[0,j]+a[i,1]*b[1,j]+a[i,2]*b[2,j]+a[i,3]*b[3,j];
end;

procedure TMat4d.Transpose;
begin
  Swap(v[1,0],v[0,1]);
  Swap(v[2,0],v[0,2]);
  Swap(v[2,1],v[1,2]);
  Swap(v[3,0],v[0,3]);
  Swap(v[3,1],v[1,3]);
  Swap(v[3,2],v[2,3]);
end;

function TMat4d.Transposed:TMat4d;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat4d.Invert;
begin
  self:=Inverted;
end;

function TMat4d.Inverted:TMat4d;
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
   result[target,i]:=result[target,i]+factor*result[src,i];
  end;
 end;
 procedure MultRow(row:integer;factor:double);
  var
   i:integer;
 begin
  for i:=0 to 3 do begin
   mat[row,i]:=mat[row,i]*factor;
   result[row,i]:=result[row,i]*factor;
  end;
 end;
begin
  mat:=self;
  result:=IdentMat4d;
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

function TMat4.GetItem(i,j:integer):single;
begin
  result:=v[i,j];
end;

procedure TMat4.SetItem(i,j:integer;value:single);
begin
  v[i,j]:=value;
end;

function TMat4.Row(n:integer):TVec4;
begin
  result:=rows[n];
end;

function TMat4.Col(n:integer):TVec4;
begin
  result.x:=v[0,n];
  result.y:=v[1,n];
  result.z:=v[2,n];
  result.w:=v[3,n];
end;

// TODO(R-07): temporary ABI-safe workaround.
// Current operator* routes through this helper because legacy ASM was written for
// (const m1,m2; out target) calling convention. Rework operator* to native ASM.
 procedure TMat4MultiplySSE(const m1,m2:TMat4;out target:TMat4);
  {$IFDEF CPUx64}
  asm
   // x64 calling convention reminder:
   // - Win64 (Microsoft ABI): m1=RCX, m2=RDX, target=R8
   // - Linux x64 (System V ABI): m1=RDI, m2=RSI, target=RDX
   // This routine currently uses the Win64 register layout.
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
  for i:=0 to 3 do begin
   for j:=0 to 3 do begin
    target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
   end;
  end;
end;
 {$ENDIF}

class operator TMat4.Multiply(const a,b:TMat4):TMat4;
var
  i,j:integer;
begin
 {$IFDEF CPUx64}
  TMat4MultiplySSE(a,b,result);
 {$ELSE}
  for i:=0 to 3 do begin
   for j:=0 to 3 do begin
    result[i,j]:=a[i,0]*b[0,j]+a[i,1]*b[1,j]+a[i,2]*b[2,j]+a[i,3]*b[3,j];
   end;
  end;
 {$ENDIF}
end;

procedure TMat4.Transpose;
begin
  Swap(v[1,0],v[0,1]);
  Swap(v[2,0],v[0,2]);
  Swap(v[2,1],v[1,2]);
  Swap(v[3,0],v[0,3]);
  Swap(v[3,1],v[1,3]);
  Swap(v[3,2],v[2,3]);
end;

function TMat4.Transposed:TMat4;
begin
  result:=self;
  result.Transpose;
end;

procedure TMat4.Invert;
begin
  self:=Inverted;
end;

function TMat4.Inverted:TMat4;
var
  mat:TMat4;
  i,k:integer;
  v:single;
begin
  mat:=self;
  result:=IdentMat4;
  for i:=0 to 3 do begin
   v:=mat[i,i];
   if abs(v)<EpsilonS then begin
    for k:=i+1 to 3 do
     if abs(mat[k,i])>EpsilonS then begin
      result.rows[i].Add(result.rows[k],1);
      mat.rows[i].Add(mat.rows[k],1);
      break;
     end;
    v:=mat[i,i];
    if v=0 then raise Exception.Create('Cannot invert matrix!');
   end;
   v:=1/v;
   mat.rows[i].Mul(v);
   result.rows[i].Mul(v);
   for k:=i+1 to 3 do begin
    v:=-mat[k,i];
    result.rows[k].Add(result.rows[i],v);
    mat.rows[k].Add(mat.rows[i],v);
   end;
  end;
  for i:=3 downto 1 do
   for k:=i-1 downto 0 do
    result.rows[k].Add(result.rows[i],-mat[k,i]);
end;

 function IsZero(v:TVec3d):boolean; overload;
  begin
   result:=(abs(v.x)<=Epsilon) and (abs(v.y)<=Epsilon) and (abs(v.z)<=Epsilon);
  end;
 function IsZero(v:TVec3):boolean; overload;
  begin
   result:=(abs(v.x)<=EpsilonS) and (abs(v.y)<=EpsilonS) and (abs(v.z)<=EpsilonS);
  end;

 function IsEqual(d1,d2:double):boolean; overload;
  begin
    result:=CompareDouble(@d1,@d2,1);
  end;

 function IsEqual(s1,s2:single):boolean; overload;
  begin
    result:=CompareSingle(@s1,@s2,1);
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

 class function TMat34.From(const m:TMat34d):TMat34;
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 2 do
     result[i,j]:=m[i,j];
  end;


 // Transform an array of homogeneous 4D points by a 4x4 matrix in-place.
  procedure _TransformVec4PointsByMat4(const m:TMat4;v:PVec4;num,step:integer); overload;
  {$IFDEF CPUx64}
  asm
   // x64 calling conventions for parameters:
   // - Win64: m=RCX, v=RDX, num=R8, step=R9
   // - Linux x64 (System V): m=RDI, v=RSI, num=RDX, step=RCX
   // This block is written for the Win64 register mapping.
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
 // Transform an array of homogeneous 4D normals by a 4x4 matrix, ignoring translation.
  procedure _TransformVec4NormalsByMat4(const m:TMat4;v:PVec4;num,step:integer);
 {$IFDEF CPUx64}
  asm
   // x64 calling conventions for parameters:
   // - Win64: m=RCX, v=RDX, num=R8, step=R9
   // - Linux x64 (System V): m=RDI, v=RSI, num=RDX, step=RCX
   // This block is written for the Win64 register mapping.
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


 // Transform an array of 3D double-precision points by a 4x3 affine matrix in-place.
 procedure _TransformVec3dPointsByMat34d(const m:TMat34d;v:PVec3d;num,step:integer); overload;
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

 // Transform an array of 3D single-precision points by a 4x3 affine matrix in-place.
 procedure _TransformVec3PointsByMat34(const m:TMat34;v:PVec3;num,step:integer); overload;
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

 // Transform an array of 3D double-precision vectors by a 3x3 matrix in-place.
 procedure _TransformVec3dPointsByMat3d(const m:TMat3d;v:PVec3d;num,step:integer); overload;
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
 // Transform an array of 3D single-precision vectors by a 3x3 matrix in-place.
 procedure _TransformVec3PointsByMat3(const m:TMat3;v:PVec3;num,step:integer); overload;
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
    result:=InvalidVec3d;
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
class function TMat3d.FromQuaternion(const q:TQuatd):TMat3d;
 var
  wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:double;
 begin
  x2:=q.x*2;
  y2:=q.y*2;
  z2:=q.z*2;
  xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
  yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
  wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;

  result[0,0]:=1.0-(yy+zz);  result[0,1]:=xy-wz;        result[0,2]:=xz+wy;
  result[1,0]:=xy+wz;        result[1,1]:=1.0-(xx+zz);  result[1,2]:=yz-wx;
  result[2,0]:=xz-wy;        result[2,1]:=yz+wx;        result[2,2]:=1.0-(xx+yy);
 end;

class function TMat3.FromQuaternion(const q:TQuat):TMat3;
 var
  wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:single;
 begin
  x2:=q.x*2;
  y2:=q.y*2;
  z2:=q.z*2;
  xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
  yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
  wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;

  result[0,0]:=1.0-(yy+zz);  result[1,0]:=xy-wz;        result[2,0]:=xz+wy;
  result[0,1]:=xy+wz;        result[1,1]:=1.0-(xx+zz);  result[2,1]:=yz-wx;
  result[0,2]:=xz-wy;        result[1,2]:=yz+wx;        result[2,2]:=1.0-(xx+yy);
 end;

class function TMat4.FromQuaternion(const q:TQuat):TMat4;
 var
  wx,wy,wz,xx,yy,yz,xy,xz,zz,x2,y2,z2:single;
 begin
  x2:=q.x*2;
  y2:=q.y*2;
  z2:=q.z*2;
  xx:=q.x*x2;   xy:=q.x*y2;   xz:=q.x*z2;
  yy:=q.y*y2;   yz:=q.y*z2;   zz:=q.z*z2;
  wx:=q.w*x2;   wy:=q.w*y2;   wz:=q.w*z2;

  result[0,0]:=1.0-(yy+zz);  result[1,0]:=xy-wz;        result[2,0]:=xz+wy;
  result[0,1]:=xy+wz;        result[1,1]:=1.0-(xx+zz);  result[2,1]:=yz-wx;
  result[0,2]:=xz-wy;        result[1,2]:=yz+wx;        result[2,2]:=1.0-(xx+yy);
  result[0,3]:=0;            result[1,3]:=0;            result[2,3]:=0;
  result.rows[3]:=vec0001s;
 end;

// https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
function TMat3.ToQuaternion:TQuat;
 var
  t,k:single;
 begin
  t:=self[0,0]+self[1,1]+self[2,2];
  if t>0 then begin
   k:=sqrt(1+t);
   result.w:=k*0.5;
   k:=0.5/k;
   result.x:=-(self[2,1]-self[1,2])*k;
   result.y:=-(self[0,2]-self[2,0])*k;
   result.z:=-(self[1,0]-self[0,1])*k;
  end else
  if (self[0,0]>self[1,1]) and (self[0,0]>self[2,2]) then begin
   k:=sqrt(1+self[0,0]-self[1,1]-self[2,2]);
   result.x:=k*0.5;
   k:=0.5/k;
   result.w:=(self[1,2]-self[2,1])*k;
   result.y:=(self[0,1]+self[1,0])*k;
   result.z:=(self[0,2]+self[2,0])*k;
  end else
  if self[1,1]>self[2,2] then begin
   k:=sqrt(1+self[1,1]-self[0,0]-self[2,2]);
   result.y:=k*0.5;
   k:=0.5/k;
   result.w:=(self[2,0]-self[0,2])*k;
   result.x:=(self[0,1]+self[1,0])*k;
   result.z:=(self[1,2]+self[2,1])*k;
  end else begin
   k:=sqrt(1+self[2,2]-self[0,0]-self[1,1]);
   result.z:=k*0.5;
   k:=0.5/k;
   result.w:=(self[0,1]-self[1,0])*k;
   result.x:=(self[0,2]+self[2,0])*k;
   result.y:=(self[1,2]+self[2,1])*k;
  end;
 end;

function TMat3d.ToQuaternion:TQuatd;
 var
  t,k:double;
 begin
  t:=self[0,0]+self[1,1]+self[2,2];
  if t>0 then begin
   k:=sqrt(1+t);
   result.w:=k*0.5;
   k:=0.5/k;
   result.x:=-(self[2,1]-self[1,2])*k;
   result.y:=-(self[0,2]-self[2,0])*k;
   result.z:=-(self[1,0]-self[0,1])*k;
  end else
  if (self[0,0]>self[1,1]) and (self[0,0]>self[2,2]) then begin
   k:=sqrt(1+self[0,0]-self[1,1]-self[2,2]);
   result.x:=k*0.5;
   k:=0.5/k;
   result.w:=(self[1,2]-self[2,1])*k;
   result.y:=(self[0,1]+self[1,0])*k;
   result.z:=(self[0,2]+self[2,0])*k;
  end else
  if self[1,1]>self[2,2] then begin
   k:=sqrt(1+self[1,1]-self[0,0]-self[2,2]);
   result.y:=k*0.5;
   k:=0.5/k;
   result.w:=(self[2,0]-self[0,2])*k;
   result.x:=(self[0,1]+self[1,0])*k;
   result.z:=(self[1,2]+self[2,1])*k;
  end else begin
   k:=sqrt(1+self[2,2]-self[0,0]-self[1,1]);
   result.z:=k*0.5;
   k:=0.5/k;
   result.w:=(self[0,1]-self[1,0])*k;
   result.x:=(self[0,2]+self[2,0])*k;
   result.y:=(self[1,2]+self[2,1])*k;
  end;
 end;

 // If matrix is not orthogonal, the shear will be lost
procedure DecomposeMatrix(mat:TMat4;out translation,rotation,scale:TQuat); overload;
  var
   qX,qY,qZ:TVec4;
   tr:TVec4;
   mat3:TMat3;
   v:single;
  begin
   tr:=mat.Row(3);
   translation:=TQuat.Init(tr.x,tr.y,tr.z,tr.w);
   qX:=mat.Row(0);
   qY:=mat.Row(1);
   qZ:=mat.Row(2);
   // Scale part
   scale.x:=qX.Length;
   scale.y:=qY.Length;
   scale.z:=qZ.Length;
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
   move(qX,mat3.rows[0],sizeof(qX));
   move(qY,mat3.rows[1],sizeof(qy));
   move(qZ,mat3.rows[2],sizeof(qZ));
   rotation:=mat3.ToQuaternion;
  end;

procedure DecomposeMatrix(mat:TMat4d;out translation,rotation,scale:TQuatd); overload;
  var
   qX,qY,qZ:TVec4d;
   tr:TVec4d;
   mat3:TMat3d;
   v:double;
  begin
   tr:=mat.Row(3);
   translation:=TQuatd.Init(tr.x,tr.y,tr.z,tr.w);
   qX:=mat.Row(0);
   qY:=mat.Row(1);
   qZ:=mat.Row(2);
   // Scale part
   scale.x:=qX.Length;
   scale.y:=qY.Length;
   scale.z:=qZ.Length;
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
   move(qX,mat3.rows[0],sizeof(qx));
   move(qY,mat3.rows[1],sizeof(qy));
   move(qZ,mat3.rows[2],sizeof(qz));
  rotation:=mat3.ToQuaternion;
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
procedure _MatrixToYRPCore(const mat:TMat34d; var yaw,roll,pitch:double);
  var
   v:TVec3d;
   skewA:double;
   m:TMat34d;
   mv:TMatrix43vd absolute m;
  begin
   m:=mat;
   mv[0].Normalize;
   mv[1].Normalize;
   mv[2].Normalize;
   skewA:=mv[0].Dot(mv[1]);
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
    m:=m*TMat34d.RotationZ(-Yaw);
   end;
   // roll (Y-rotation): mv[0].z = -sin(roll)
   if mv[0].x<-0.999 then roll:=pi else
    Roll:=-arcsin(mv[0].z);
   m:=m*TMat34d.RotationY(roll);
   // pitch (X-rotation)
   if mv[1].y<-0.999 then pitch:=pi else begin
    Pitch:=arccos(mv[1].y);
    if mv[1].z<0 then pitch:=-pitch;
   end;
  end;{ TVec3d }

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
  l:=1/Length;
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
  l:=1/Length;
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

{ TVec4d }

constructor TVec4d.Init(x,y,z,w:double);
begin
  self.x:=x;
  self.y:=y;
  self.z:=z;
  self.w:=w;
end;

constructor TVec4d.Init(vec3:TVec3d);
begin
  x:=vec3.x;
  y:=vec3.y;
  z:=vec3.z;
  w:=1;
end;

function TVec4d.ToVec3d:TVec3d;
begin
  result.x:=x;
  result.y:=y;
  result.z:=z;
end;

procedure TVec4d.Add(const p:TVec4d;scale:double);
begin
  x:=x+p.x*scale;
  y:=y+p.y*scale;
  z:=z+p.z*scale;
  w:=w+p.w*scale;
end;

procedure TVec4d.Add(const p:TVec4d);
begin
  Add(p,1);
end;

procedure TVec4d.Mul(scalar:double);
begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
  w:=w*scalar;
end;

procedure TVec4d.Normalize;
var
  len:double;
begin
  len:=Length;
  if len<>0 then begin
    Mul(1/len);
  end;
end;

function TVec4d.Dot(const p:TVec4d):double;
begin
  result:=x*p.x+y*p.y+z*p.z+w*p.w;
end;

function TVec4d.Length:double;
begin
  result:=Sqrt(Dot(self));
end;

function TVec4d.Length2:double;
begin
  result:=Dot(self);
end;

function TVec4d.IsValid:boolean;
begin
  result:=(x=x) and (y=y) and (z=z) and (w=w);
end;

{ TVec4 }

constructor TVec4.Init(x,y,z,w:single);
begin
  self.x:=x;
  self.y:=y;
  self.z:=z;
  self.w:=w;
end;

constructor TVec4.Init(vec3:TVec3);
begin
  x:=vec3.x;
  y:=vec3.y;
  z:=vec3.z;
  w:=1;
end;

constructor TVec4.Init(v:TVec4d);
begin
  x:=v.x;
  y:=v.y;
  z:=v.z;
  w:=v.w;
end;

function TVec4.ToVec3:TVec3;
begin
  result.x:=x;
  result.y:=y;
  result.z:=z;
end;

procedure TVec4.Add(const p:TVec4;scale:single);
begin
  x:=x+p.x*scale;
  y:=y+p.y*scale;
  z:=z+p.z*scale;
  w:=w+p.w*scale;
end;

procedure TVec4.Add(const p:TVec4);
begin
  Add(p,1);
end;

procedure TVec4.Mul(scalar:single);
begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
  w:=w*scalar;
end;

procedure TVec4.Normalize;
var
  len:single;
begin
  len:=Length;
  if len<>0 then begin
    Mul(1/len);
  end;
end;

function TVec4.Dot(const p:TVec4):single;
begin
  result:=x*p.x+y*p.y+z*p.z+w*p.w;
end;

function TVec4.Length:single;
begin
  result:=Sqrt(Dot(self));
end;

function TVec4.Length2:single;
begin
  result:=Dot(self);
end;

function TVec4.IsValid:boolean;
begin
  result:=(x=x) and (y=y) and (z=z) and (w=w);
end;

{ TQuatd }

constructor TQuatd.Init(x,y,z,w:double);
 begin
  self.x:=x; self.y:=y; self.z:=z; self.w:=w;
 end;

constructor TQuatd.Init(vec3:TVec3d);
 begin
  self.x:=vec3.x;
  self.y:=vec3.y;
  self.z:=vec3.z;
  self.w:=1;
 end;

function TQuatd.ToVec3d:TVec3d;
 begin
  result.x:=x;
  result.y:=y;
  result.z:=z;
 end;

class operator TQuatd.Implicit(a:TQuatd):TVec4d;
 begin
  result.x:=a.x;
  result.y:=a.y;
  result.z:=a.z;
  result.w:=a.w;
 end;

class operator TQuatd.Implicit(a:TVec4d):TQuatd;
 begin
  result.x:=a.x;
  result.y:=a.y;
  result.z:=a.z;
  result.w:=a.w;
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
  result:=Sqrt(w*w+x*x+y*y+z*z);
 end;

function TQuatd.Length2:double;
 begin
  result:=w*w + x*x + y*y + z*z;
 end;

procedure TQuatd.Mul(scalar:double);
 begin
  x:=x*scalar;
  y:=y*scalar;
  z:=z*scalar;
  w:=w*scalar;
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
  Mul(1/Length);
 end;

procedure TQuatd.Invert;
 begin
  self:=Inverted;
 end;

function TQuatd.Inverted:TQuatd;
 begin
  result.w:=w;
  result.x:=-x;
  result.y:=-y;
  result.z:=-z;
  result.Normalize;
 end;

class operator TQuatd.Multiply(const a,b:TQuatd):TQuatd;
 var
  aa,bb,cc,dd,ee,ff,gg,hh:double;
 begin
  aa:=(a.w+a.x) * (b.w+b.x);
  bb:=(a.z-a.y) * (b.y-b.z);
  cc:=(a.x-a.w) * (b.y+b.z);
  dd:=(a.y+a.z) * (b.x-b.w);
  ee:=(a.x+a.z) * (b.x+b.y);
  ff:=(a.x-a.z) * (b.x-b.y);
  gg:=(a.w+a.y) * (b.w-b.z);
  hh:=(a.w-a.y) * (b.w+b.z);
  result.w:=bb+(-ee-ff+gg+hh)*0.5;
  result.x:=aa-(ee+ff+gg+hh)*0.5;
  result.y:=-cc+(ee-ff+gg-hh)*0.5;
  result.z:=-dd+(ee-ff-gg+hh)*0.5;
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

class operator TQuat.Implicit(a:TQuat):TVec4;
 begin
  result.x:=a.x;
  result.y:=a.y;
  result.z:=a.z;
  result.w:=a.w;
 end;

class operator TQuat.Implicit(a:TVec4):TQuat;
 begin
  result.x:=a.x;
  result.y:=a.y;
  result.z:=a.z;
  result.w:=a.w;
 end;

function TQuat.ToVec3:TVec3;
 begin
  result.x:=x;
  result.y:=y;
  result.z:=z;
 end;

function TQuat.ToQuatd:TQuatd;
 begin
  result.x:=x;
  result.y:=y;
  result.z:=z;
  result.w:=w;
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
  // x64 calling conventions for "self":
  // - Win64: RCX = @self
  // - Linux x64 (System V): RDI = @self
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
  result:=Sqrt(w*w+x*x+y*y+z*z);
end;
 {$ENDIF}

function TQuat.Length2:single;
 {$IFDEF CPUx64}
 asm
  // x64 calling conventions for "self":
  // - Win64: RCX = @self
  // - Linux x64 (System V): RDI = @self
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
  // x64 calling conventions for "self":
  // - Win64: RCX = @self
  // - Linux x64 (System V): RDI = @self
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
  Mul(1/Length);
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

procedure TQuat.Invert;
 begin
  self:=Inverted;
 end;

function TQuat.Inverted:TQuat;
 begin
  result.w:=w;
  result.x:=-x;
  result.y:=-y;
  result.z:=-z;
  result.Normalize;
 end;

class operator TQuat.Multiply(const a,b:TQuat):TQuat;
 var
  aa,bb,cc,dd,ee,ff,gg,hh:single;
 begin
  aa:=(a.w+a.x) * (b.w+b.x);
  bb:=(a.z-a.y) * (b.y-b.z);
  cc:=(a.x-a.w) * (b.y+b.z);
  dd:=(a.y+a.z) * (b.x-b.w);
  ee:=(a.x+a.z) * (b.x+b.y);
  ff:=(a.x-a.z) * (b.x-b.y);
  gg:=(a.w+a.y) * (b.w-b.z);
  hh:=(a.w-a.y) * (b.w+b.z);
  result.w:=bb+(-ee-ff+gg+hh)*0.5;
  result.x:=aa-(ee+ff+gg+hh)*0.5;
  result.y:=-cc+(ee-ff+gg-hh)*0.5;
  result.z:=-dd+(ee-ff-gg+hh)*0.5;
 end;

class function TQuat.Slerp(const q1,q2:TQuat;factor:single):TQuat;
 var
  cosOmega,sinOmega,scale0,scale1:single;
 begin
  cosOmega:=q1.x*q2.x+q1.y*q2.y+q1.z*q2.z+q1.w*q2.w;
  if cosOmega<0.0 then begin
   cosOmega:=-cosOmega;
   result.x:=-q1.x;
   result.y:=-q1.y;
   result.z:=-q1.z;
   result.w:=-q1.w;
  end else begin
   result:=q1;
  end;
  if (1.0-cosOmega)>1E-6 then begin
   sinOmega:=Sqrt(1.0-sqr(cosOmega));
   scale0:=Sin((1.0-factor) * ArcCos(cosOmega))/sinOmega;
   scale1:=Sin(factor * ArcCos(cosOmega))/sinOmega;
  end else begin
   scale0:=1.0-factor;
   scale1:=factor;
  end;
  result.x:=scale0*result.x+scale1*q2.x;
  result.y:=scale0*result.y+scale1*q2.y;
  result.z:=scale0*result.z+scale1*q2.z;
  result.w:=scale0*result.w+scale1*q2.w;
 end;

function TVec3d.IsZero:boolean;
begin
  result:=(abs(x)<=Epsilon) and (abs(y)<=Epsilon) and (abs(z)<=Epsilon);
end;

function TVec3d.IsEqual(const p:TVec3d;precision:single):boolean;
begin
  result:=CompareDouble(@self,@p,3,precision);
end;

function TVec3.IsZero:boolean;
begin
  result:=(abs(x)<=EpsilonS) and (abs(y)<=EpsilonS) and (abs(z)<=EpsilonS);
end;

function TVec3.IsIdentity:boolean;
begin
  result:=(abs(x-1)<=EpsilonS) and (abs(y-1)<=EpsilonS) and (abs(z-1)<=EpsilonS);
end;

function TVec3.IsEqual(const p:TVec3;precision:single):boolean;
begin
  result:=CompareSingle(@self,@p,3,precision);
end;

function TVec4d.IsEqual(const p:TVec4d;precision:single):boolean;
begin
  result:=CompareDouble(@self,@p,4,precision);
end;

function TVec4.IsEqual(const p:TVec4;precision:single):boolean;
begin
  result:=CompareSingle(@self,@p,4,precision);
end;

function TQuatd.IsEqual(const q:TQuatd;precision:single):boolean;
begin
  result:=CompareDouble(@self,@q,4,precision);
end;

function TMat3d.IsEqual(const m:TMat3d;precision:single):boolean;
begin
  result:=CompareDouble(@self,@m,9,precision);
end;

function TMat34d.IsIdentity:boolean;
begin
  result:=CompareDouble(@self,@IdentMat34d,12,1);
end;

function TMat34d.IsEqual(const m:TMat34d;precision:single):boolean;
begin
  result:=CompareDouble(@self,@m,12,precision);
end;

function TMat4d.IsEqual(const m:TMat4d;precision:single):boolean;
begin
  result:=CompareDouble(@self,@m,16,precision);
end;

function TMat4.IsEqual(const m:TMat4;precision:single):boolean;
begin
  result:=CompareSingle(@self,@m,16,precision);
end;

function TMat3.IsEqual(const m:TMat3;precision:single):boolean;
begin
  result:=CompareSingle(@self,@m,9,precision);
end;

function TMat34.IsIdentity:boolean;
begin
  result:=CompareSingle(@self,@IdentMat34,12,1);
end;

function TMat34.IsEqual(const m:TMat34;precision:single):boolean;
begin
  result:=CompareSingle(@self,@m,12,precision);
end;

initialization
  ASSERT(UIntPtr(@IdentMat4) and $F = 0, 'Matrix constant unaligned');
end.




