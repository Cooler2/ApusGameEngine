// -----------------------------------------------------
// 3D geometry common high-precision functions
// Author: Ivan Polyacov (C) 2003, Apus Software
// Mail me: ivan@games4win.com or cooler@tut.by
// ------------------------------------------------------
{$IFDEF FPC}{$PIC OFF}{$ENDIF}
unit geom3d;
interface
 //uses Geom2d;

 type
  PPoint3=^TPoint3;
  PVector3=^TVector3;
  TPoint3=packed record
   x,y,z:double;
  end;
  TVector3=TPoint3;

  PPoint3s=^TPoint3s;
  TPoint3s=packed record
   x,y,z:single;
  end;
  TVector3s=TPoint3s;

  // Infinite plane in space
  TPlane=packed record
   a,b,c,d:extended;
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
 function Matrix4(from:TMatrix43):TMatrix4;
 function Matrix4s(from:TMatrix4):TMatrix4s;

 // Скалярное произведение векторов = произведение длин на косинус угла = проекция одного вектора на другой 
 function DotProduct3(a,b:TVector3):extended; overload;
 function DotProduct3(a,b:TVector3s):double; overload;
 // Векторное произведение: модуль равен площади ромба  
 function CrossProduct3(a,b:TVector3):TVector3; overload;
 function CrossProduct3(a,b:TVector3s):TVector3s; overload;
 function GetLength3(v:TVector3):extended; overload;
 function GetLength3(v:TVector3s):double; overload;
 function GetSqrLength3(v:TVector3):extended; overload;
 function GetSqrLength3(v:TVector3s):single; overload;
 procedure Normalize3(var v:TVector3); overload;
 procedure Normalize3(var v:TVector3s); overload;
 procedure VectAdd3(var a:TVector3;b:TVector3);
 procedure VectSub3(var a:TVector3;b:TVector3);
 procedure VectMult(var a:TVector3;k:double);
 function Vect3Mult(a:TVector3;k:double):TVector3;
 function PointAdd(p:TPoint3;v:TVector3;factor:double=1.0):TPoint3; inline;
 function Distance(p1,p2:TPoint3):double; overload;
 function Distance(p1,p2:TPoint3s):single; overload;
 function Distance2(p1,p2:TPoint3):double; overload;
 function Distance2(p1,p2:TPoint3s):single; overload;

 function IsNearS(a,b:TPoint3s):single;
 function IsNear(a,b:TPoint3):double;

 // Convert matrix to single precision
 procedure ToSingle43(sour:TMatrix43;out dest:TMatrix43s);

 function TranslationMat(x,y,z:double):TMatrix43;
 function RotationXMat(angle:double):TMatrix43;
 function RotationYMat(angle:double):TMatrix43;
 function RotationZMat(angle:double):TMatrix43;

 // Матрица поворота вокруг вектора единичной длины!
 function RotationAroundVector(v:TVector3;angle:double):TMatrix3; overload;
 function RotationAroundVector(v:TVector3s;angle:single):TMatrix3s; overload;

 // Используется правосторонняя СК, ось Z - вверх.
 // roll - поворот вокруг X
 // pitch - затем поворот вокруг Y
 // yaw - наконец, поворот вокруг Z
 function MatrixFromYawRollPitch(yaw,roll,pitch:double):TMatrix43;
 procedure YawRollPitchFromMatrix(const mat:TMatrix43; var yaw,roll,pitch:double);

 // target = M1*M2 (Смысл: перевести репер M1 из системы M2 в ту, где задана M2)
 // Другой смысл: суммарная трансформация: сперва M2, затем M1
 procedure MultMat3(m1,m2:TMatrix3;out target:TMatrix3); overload;
 procedure MultMat3(m1,m2:TMatrix3s;out target:TMatrix3s); overload;
 procedure MultMat4(m1,m2:TMatrix43;out target:TMatrix43); overload;
 procedure MultMat4(m1,m2:TMatrix43s;out target:TMatrix43s); overload;
 procedure MultMat4(m1,m2:TMatrix4;out target:TMatrix4); overload;
 function MultMat4(m1,m2:TMatrix43):TMatrix43; overload;

 procedure MultPnt4(m:TMatrix43;v:PPoint3;num,step:integer); overload;
 procedure MultPnt4(m:TMatrix43s;v:Ppoint3s;num,step:integer); overload;
 procedure MultPnt3(m:TMatrix3;v:PPoint3;num,step:integer); overload;
 procedure MultPnt3(m:TMatrix3s;v:Ppoint3s;num,step:integer); overload;

 // Transpose (для ортонормированной матрицы - это будт обратная)
 procedure Transp3(m:TMatrix3;out dest:TMatrix3);
 procedure Transp4(m:TMatrix43;out dest:TMatrix43); overload;
 procedure Transp4(m:TMatrix4;out dest:TMatrix4); overload;
 // Вычисление обратной матрицы (осторожно!)
 procedure Invert3(m:TMatrix3;out dest:TMatrix3);
 procedure Invert4(m:TMatrix43;out dest:TMatrix43);

 function Det(m:TMatrix3):single;

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
 uses {$IFDEF DELPHI}CrossPlatform,{$ENDIF}
  SysUtils,Math,Geom2d;

 var
  sse:boolean;

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

 function DotProduct3(a,b:TVector3):extended;
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
 function GetLength3(v:TVector3):extended;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;
 function GetLength3(v:TVector3s):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
  end;
 function GetSqrLength3(v:TVector3):extended;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;
 function GetSqrLength3(v:TVector3s):single;
  begin
   result:=v.x*v.x+v.y*v.y+v.z*v.z;
  end;
 procedure Normalize3(var v:TVector3);
  var
   l:extended;
  begin
   l:=GetLength3(v);
   if l<Epsilon then exit;
   v.x:=v.x/l;
   v.y:=v.y/l;
   v.z:=v.z/l;
  end;
 procedure Normalize3(var v:TVector3s);
  var
   l:extended;
  begin
   l:=GetLength3(v);
   if l<EpsilonS then exit;
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
 function Vect3Mult(a:TVector3;k:double):TVector3;
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

 procedure MultMat3(m1,m2:TMatrix3;out target:TMatrix3);
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

 procedure MultMat3(m1,m2:TMatrix3s;out target:TMatrix3s);
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

 procedure MultMat4(m1,m2:TMatrix43;out target:TMatrix43);
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

 procedure MultMat4(m1,m2:TMatrix4;out target:TMatrix4);
  var
   i,j:integer;
  begin
   for i:=0 to 3 do
    for j:=0 to 3 do
     target[i,j]:=m1[i,0]*m2[0,j]+m1[i,1]*m2[1,j]+m1[i,2]*m2[2,j]+m1[i,3]*m2[3,j];
  end;


 function MultMat4(m1,m2:TMatrix43):TMatrix43; overload;
  begin
   MultMat4(m1,m2,result);
  end;  

 procedure MultMat4(m1,m2:TMatrix43s;out target:TMatrix43s);
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

 procedure Transp3;
  begin
   dest[0,0]:=m[0,0];   dest[0,1]:=m[1,0];   dest[0,2]:=m[2,0];
   dest[1,0]:=m[0,1];   dest[1,1]:=m[1,1];   dest[1,2]:=m[2,1];
   dest[2,0]:=m[0,2];   dest[2,1]:=m[1,2];   dest[2,2]:=m[2,2];
  end;

 procedure Transp4(m:TMatrix43;out dest:TMatrix43);
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

 procedure Transp4(m:TMatrix4;out dest:TMatrix4);
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
   la,lb,lc:extended;
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

 procedure Invert4;
  var
   la,lb,lc:extended;
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

 procedure MultPnt4(m:TMatrix43;v:PPoint3;num,step:integer);
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

 procedure MultPnt4(m:TMatrix43s;v:PPoint3s;num,step:integer);
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

 procedure MultPnt3(m:TMatrix3;v:PPoint3;num,step:integer);
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
 procedure MultPnt3(m:TMatrix3s;v:Ppoint3s;num,step:integer);
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

 function TranslationMat(x,y,z:double):TMatrix43;
  begin
   result:=IdentMatrix43;
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

 function Det(m:TMatrix3):single;
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

 function MatrixFromYawRollPitch(yaw,roll,pitch:double):TMatrix43;
  var
   m,m2:TMatrix43;
  begin
   m2:=IdentMatrix43;
   MultMat4(m2,RotationXMat(roll),m);
   MultMat4(m,RotationYMat(pitch),m2);
   MultMat4(m2,RotationZMat(Yaw),m);
   result:=m;
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

{var
 a,b,c,o,t:TPoint3s;
 pb,pc,d:double;
 m:TMatrix3;}

initialization
 // Определение поддержки SSE
 {$IFDEF CPU386}
 asm
  pushad
  mov eax,1
  cpuid
  test edx,2000000h
  jz @noSSE
  mov sse,1
@noSSE:
  popad
 end;
 {$ENDIF}
// m:=RotationAroundVector(Vector3(0,1,0),1);

end.
