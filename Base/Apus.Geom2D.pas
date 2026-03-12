// -----------------------------------------------------
// 2D geometry common high-precision functions
// Author: Ivan Polyacov (C) 2002, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// ------------------------------------------------------
{$EXCESSPRECISION OFF}
unit Apus.Geom2D;

interface
 uses Types;

 const
  Epsilon:extended    = 1E-12;  // for double and extended
  EpsilonS:single     = 0.00001; // for single
  pi                  = 3.1415926536;
  pi2                 = pi/2;
 type
  // Intersection status
  TStatus=(intNone,intPoint,intSegment,intLine);

  // Point on plane
  TVec2d=packed record
   x,y:double;
   constructor Init(x,y:double); overload;
   constructor Init(pnt:TPoint); overload;
   function GetRound:TPoint;
   function IsValid:boolean; inline;
   procedure Wrap(max:double); inline;
   function Dot(const p:TVec2d):double; inline;
   function Cross(const p:TVec2d):double; inline;
   function Length:double; inline;
   function Length2:double; inline;
   function Sub(const p:TVec2d):TVec2d; inline;
   function Distance2(const p:TVec2d):double; inline;
   procedure Add(const p:TVec2d); inline;
   procedure Multiply(value:double); inline;
  end;
  PVec2d=^TVec2d;

  TVec2=packed record
   x,y:single;
   constructor Init(x,y:single); overload;
   constructor Init(pnt:TPoint); overload;
   function GetRound:TPoint;
   function IsValid:boolean; inline;
   function Dot(const p:TVec2):single; inline;
   function Cross(const p:TVec2):single; inline;
   function Length:single; inline;
   function Length2:single; inline;
   function Sub(const p:TVec2):TVec2; inline;
   procedure Wrap(max:single); inline;
   class operator Implicit(a:TPointF):TVec2;
   class operator Implicit(a:TPoint):TVec2;
   class operator Implicit(a:TVec2d):TVec2;
   class operator Implicit(a:TVec2):TVec2d;
   class operator Equal(a,b:TVec2):boolean;
   class operator Negative(a:TVec2):TVec2;
   class operator Add(a,b:TVec2):TVec2;
   class operator Multiply(a:TVec2;v:single):TVec2;
   class operator Multiply(a,b:TVec2):TVec2;
  end;
  PVec2=^TVec2;
  TVec2Array=array of TVec2;

  // Infinite line on plane
  TLine2=packed record
   a,b,c:double;
   class function Init(const p1,p2:TVec2d):TLine2; static;
   function Deviation(const point:TVec2d):double; inline;
  end;

  PRect2=^TRect2;
  TRect2=packed record
   function Width:single;
   function Height:single;
   procedure Init; overload; inline; // init empty
   procedure Init(x1,y1,x2,y2:single); overload; inline;
   procedure InitWH(x,y,width,height:single); overload; inline;
   procedure MoveBy(dx,dy:single); overload; inline;
   procedure MoveBy(delta:TVec2); overload; inline;
   procedure Include(x,y:single); overload; inline;
   procedure Include(r:TRect2); overload; inline;
   procedure Round;
   function IsEmpty:boolean; inline;
   function Center:TVec2; inline;
   function GetIntRect:TRect;
   case integer of
    0:( x1,y1,x2,y2:single; );
    1:( left,top,right,bottom:single; );
    2:( topLeft,bottomRight:TVec2; );
  end;

  TSegment2=packed record
   x1,y1,x2,y2:double;
   function IsDegenerate:boolean; inline;
  end;

  TMat2d=array[0..1,0..1] of double;
  TMat32d=array[0..2,0..1] of double;
  // Single precision version
  TMat2=array[0..1,0..1] of single;
  TMat32=array[0..2,0..1] of single;
  // Vector versions
  TMatrix2v=array[0..1] of TVec2d;
  TMatrix32v=array[0..2] of TVec2d;
  TMatrix32sv=array[0..2] of TVec2;


 const
  NaN = 0.0/0.0;
  IdentMatrix2:TMat2d=((1,0),(0,1));
  IdentMatrix32:TMat32d=((1,0),(0,1),(0,0));
  IdentMat2:TMat2=((1,0),(0,1));
  IdentMat32:TMat32=((1,0),(0,1),(0,0));

  InvalidPoint2:TVec2d=(x:NaN;y:NaN);
  InvalidPoint2s:TVec2=(x:NaN;y:NaN);

 // Vector functions
 function DotProduct(const a,b:TVec2d):double; overload; inline;
 function CrossProduct(const a,b:TVec2d):double; overload; inline;
 function DotProduct(const a,b:TVec2):single; overload; inline;
 function CrossProduct(const a,b:TVec2):single; overload; inline;
 function GetLength(v:TVec2d):double; overload; inline;
 function GetLength(v:TVec2):double; overload; inline;
 function Distance(p1,p2:TVec2d):double; overload;
 function Distance(p1,p2:TVec2):single; overload;
 function Distance2(p1,p2:TVec2d):double; overload;
 function Distance2(p1,p2:TVec2):single; overload;
 function GetSqrLength(v:TVec2d):double; overload; inline;
 procedure Normalize(var v:TVec2d); overload; inline;
 procedure Normalize(var v:TVec2); overload; inline;
 function PointAdd(p:TVec2d;v:TVec2d;factor:double=1.0):TVec2d; inline; overload;
 function PointAdd(p:TVec2;v:TVec2;factor:double=1.0):TVec2; inline; overload;
 procedure VectAdd(var a:TVec2d;const b:TVec2d); overload; inline;
 procedure VectSub(var a:TVec2d;const b:TVec2d); overload; inline;
 procedure VectAdd(var a:TVec2;const b:TVec2); inline; overload;
 procedure VectSub(var a:TVec2;const b:TVec2); inline; overload;
 function VectMult(v:TVec2d;value:double):TVec2d; inline; overload;
 function VectMult(a,b:TVec2):TVec2; inline; overload;
 function VectDiv(a,b:TVec2):TVec2; inline;
 procedure VectInv(var v:TVec2); inline;
 // Turn counterclockwise (angle in radians)
 procedure VectTurn(var v:TVec2d;angle:double); inline;
 procedure Turn90Right(var v:TVec2d);  inline;
 function Turn90R(v:TVec2d):TVec2d; inline;
 procedure Turn90Left(var v:TVec2d); inline;
 function Turn90L(v:TVec2d):TVec2d; inline;
 // Angle between vectors (radians)
 function VectAngle(v1,v2:TVec2d):double; overload;
 function VectAngle(v1,v2:TVec2):single; overload;
 // Angle between vector and X axis (CCW direction if Y is up), -Pi..Pi
 function VectAngle(v:TVec2d):double; overload; inline;
 function VectAngle(v:TVec2):single; overload; inline;
 // how much vector v1 must be rotated in clockwise direction to obtain v2 direction
 function VectAngleClockwise(v1,v2:TVec2d):double; inline;
 // Difference between 2 directions (angle) (result is signed: from -Pi to +Pi)!
 function AngleDiff(a1,a2:double):double; inline;

 // Comparison
 function AboutEqual(a,b:TVec2d):boolean; inline;
 // Lexicographical compare (-1 if a<b, 0 if a=b, 1 if a>b)
 function LexCompare(a,b:TVec2d):integer; inline;

 // Setup point
 function Point2(x,y:double):TVec2d; overload; inline;
 function Point2(pnt:TVec2):TVec2d; overload; inline;
 function PointBlend(p1,p2:TVec2d;factor:double):TVec2d; overload;
 function PointBlend(p1,p2:TVec2;factor:single):TVec2; overload;
 // Setup vector (from source to target)
 function Vector2(source,target:TVec2d):TVec2d; inline;
 // Unit vector with given direction (CCW from X-axis)
 function Direction(angle:double):TVec2d; inline;
 function IntersectLines(l1,l2:TLine2;out p:TVec2d):TStatus;

 // Is point inside trg? (1 - inside, 0 - on border, -1 - outside)
 function PointInTrg(a,b,c,pnt:TVec2d):integer;

 // Returns random point in a circle (0,0,R)
 function RandomPointInCircle(r:single):TVec2;

 // Setup segment by points
 function Segment2(x1,y1,x2,y2:integer):TSegment2; overload;
 function Segment2(x1,y1,x2,y2:double):TSegment2; overload;
 // Segment operations
 // Locate point at segment (parameter: 0..1, deviation is absolute)
 procedure PointOnSegment(segm:TSegment2;pnt:TVec2d;
             out parameter,deviation:double);
 function IntersectSegm(s1,s2:Tsegment2;
            out p:TVec2d;out param1,param2:double):TStatus;
 // Calculate Bezier curve from p0 to p3 with control points p1 and p2 (t = 0..1)
 function Bezier2D(var p0,p1,p2,p3:TVec2d;t:double):TVec2d;

 // Integer operations
 // РІР·Р°РёРјРЅРѕРµ СЂР°СЃРїРѕР»РѕР¶РµРЅРёРµ РїСЂ-РєРѕРІ: 0 - РЅРµ РїРµСЂРµСЃРµРєР°СЋС‚СЃСЏ, 1 - r1 РІРЅСѓС‚СЂРё r2, 2 - r2 РІРЅСѓС‚СЂРё r1, 4 - РїРµСЂРµСЃРµРєР°СЋС‚СЃСЏ
 // С‚РѕР»СЊРєРѕ РґР»СЏ СѓРїРѕСЂСЏРґРѕС‡РµРЅРЅС‹С… РїСЂ-РєРѕРІ!
 function IntersectRects(r1,r2:TRect;out r:TRect):integer;
 procedure OrderRect(var r:TRect); // СѓРїРѕСЂСЏРґРѕС‡РёС‚СЊ Рє-С‚С‹ РїРѕ РІРѕР·СЂР°СЃС‚Р°РЅРёСЋ

 procedure ToSingle32(sour:TMat32d;out dest:TMat32);

 function TranslationMat(x,y:double):TMat32d;
 function RotationMat(angle:double):TMat32d;
 function RotationMat2(angle:double):TMat2d;
 function ScaleMat(scaleX,scaleY:double):TMat32d;

 // target = M1*M2
 procedure MultMat(m1,m2:TMat2d;out target:TMat2d); overload;
 procedure MultMat(m1,m2:TMat32d;out target:TMat32d); overload;

 procedure MultPnts(m:TMat32;v:PVec2;num,step:integer);

 // РўСЂР°РЅСЃРїРѕРЅРёСЂРѕРІР°РЅРёРµ (РґР»СЏ РѕСЂС‚РѕРЅРѕСЂРјРёСЂРѕРІР°РЅРЅРѕР№ РјР°С‚СЂРёС†С‹ - СЌС‚Рѕ Р±СѓРґС‚ РѕР±СЂР°С‚РЅР°СЏ)
 procedure Transp2(m:TMat2d;out dest:TMat2d);
 procedure Transp(m:TMat32d;out dest:TMat32d);
 // Р’С‹С‡РёСЃР»РµРЅРёРµ РѕР±СЂР°С‚РЅРѕР№ РјР°С‚СЂРёС†С‹
 procedure Invert2(m:TMat2d;out dest:TMat2d);
 procedure Invert(m:TMat32d;out dest:TMat32d);

 // Rectangle
 function Rect2(x1,y1,x2,y2:single):TRect2; overload; inline;
 function TransformRect(const r:TRect2;dx,dy,sx,sy:single):TRect2;
 function RoundRect(const r:TRect2):TRect;

 var
  trgIndices:array of integer; // СЂРµР·СѓР»СЊС‚Р°С‚ С‚СЂРёР°РЅРіСѓР»СЏС†РёРё
 // С‚СЂРёР°РЅРіСѓР»СЏС†РёСЏ Р·Р°РјРєРЅСѓС‚РѕРіРѕ РјРЅРѕРіРѕСѓРіРѕР»СЊРЅРёРєР° (СЃС‚СЂРѕРёС‚ n-2 С‚СЂРі). !!! CLOCKWISE!
 procedure Triangulate(pnts:PVec2d;count:integer);

implementation
 uses Math, Apus.Types, Apus.Core, SysUtils;

 function DotProduct(const a,b:TVec2d):double;
  begin
   result:=a.Dot(b);
  end;

 function CrossProduct(const a,b:TVec2d):double;
  begin
   result:=a.Cross(b);
  end;

 function DotProduct(const a,b:TVec2):single;
  begin
   result:=a.x*b.x+a.y*b.y;
  end;

 function CrossProduct(const a,b:TVec2):single;
  begin
   result:=a.x*b.y-a.y*b.x;
  end;

 function GetLength(v:TVec2d):double;
  begin
   result:=v.Length;
  end;

 function GetLength(v:TVec2):double;
  begin
   result:=sqrt(v.x*v.x+v.y*v.y);
  end;


 function Distance(p1,p2:TVec2d):double; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y));
  end;
 function Distance(p1,p2:TVec2):single; overload;
  begin
   result:=sqrt(sqr(p2.x-p1.x)+sqr(p2.y-p1.y));
  end;

 function Distance2(p1,p2:TVec2d):double; overload;
  begin
   result:=p1.Distance2(p2);
  end;
 function Distance2(p1,p2:TVec2):single; overload;
  begin
   result:=sqr(p2.x-p1.x)+sqr(p2.y-p1.y);
  end;


 function GetSqrLength(v:TVec2d):double;
  begin
   result:=v.Length2;
  end;

 procedure Normalize(var v:TVec2d);
  var
   l:double;
  begin
   l:=GetLength(v);
   ASSERT(l>Epsilon,'Normalize zero-length vector');
   v.x:=v.x/l;
   v.y:=v.y/l;
  end;

 procedure Normalize(var v:TVec2);
  var
   l:double;
  begin
   l:=GetLength(v);
   ASSERT(l>EpsilonS,'Normalize zero-length vector');
   v.x:=v.x/l;
   v.y:=v.y/l;
  end;


 procedure VectAdd(var a:TVec2d;const b:TVec2d); inline;
  begin
   a.Add(b);
  end;

 procedure VectSub(var a:TVec2d;const b:TVec2d);
  begin
   a:=a.Sub(b);
  end;

 procedure VectAdd(var a:TVec2;const b:TVec2); inline;
  begin
   a.x:=b.x+a.x;
   a.y:=b.y+a.y;
  end;

 procedure VectSub(var a:TVec2;const b:TVec2);
  begin
   a.x:=a.x-b.x;
   a.y:=a.y-b.y;
  end;

 function VectMult(v:TVec2d;value:double):TVec2d;
  begin
   result:=v;
   result.Multiply(value);
  end;

 function VectMult(a,b:TVec2):TVec2; inline; overload;
  begin
   result.x:=a.x*b.x;
   result.y:=a.y*b.y;
  end;

 function VectDiv(a,b:TVec2):TVec2; inline;
  begin
   result.x:=a.x/b.x;
   result.y:=a.y/b.y;
  end;

 procedure VectInv(var v:TVec2);
  begin
   v.x:=1/v.x;
   v.y:=1/v.y;
  end;

 function PointAdd(p:TVec2d;v:TVec2d;factor:double=1.0):TVec2d;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
  end;

 function PointAdd(p:TVec2;v:TVec2;factor:double=1.0):TVec2; inline;
  begin
   result.x:=p.x+v.x*factor;
   result.y:=p.y+v.y*factor;
  end;

 procedure VectTurn(var v:TVec2d;angle:double);
  var
   nx,ny:double;
  begin
   nx:=v.x*cos(angle)-v.y*sin(angle);
   ny:=v.x*sin(angle)+v.y*cos(angle);
   v.x:=nx; v.y:=ny;
  end;

 procedure Turn90Right(var v:TVec2d);
  var
   nx,ny:double;
  begin
   nx:=v.y;
   ny:=-v.x;
   v.x:=nx;
   v.y:=ny;
  end;

 function Turn90R(v:TVec2d):TVec2d;
  begin
   result.x:=v.y;
   result.y:=-v.x;
  end;

 procedure Turn90Left(var v:TVec2d);
  var
   nx,ny:double;
  begin
   nx:=-v.y;
   ny:=v.x;
   v.x:=nx;
   v.y:=ny;
  end;

 function Turn90L(v:TVec2d):TVec2d;
  begin
   result.x:=-v.y;
   result.y:=v.x;
  end;

 function VectAngle(v1,v2:TVec2d):double;
  var
   p:double;
  begin
   Normalize(v1);
   Normalize(v2);
   p:=DotProduct(v1,v2);
   if p>1 then p:=1;
   if p<-1 then p:=-1;
   result:=ArcCos(p);
  end;

 function VectAngle(v:TVec2d):double;
  begin
   result:=ArcTan2(v.y,v.x);
  end;

 function VectAngle(v1,v2:TVec2):single;
  var
   p:single;
  begin
   Normalize(v1);
   Normalize(v2);
   p:=DotProduct(v1,v2);
   if p>1 then p:=1;
   if p<-1 then p:=-1;
   result:=ArcCos(p);
  end;

 function VectAngle(v:TVec2):single;
  begin
   result:=ArcTan2(v.y,v.x);
  end;

 function VectAngleClockwise(v1,v2:TVec2d):double;
  var
   a:double;
  begin
   a:=VectAngle(v1,v2);
   if CrossProduct(v1,v2)>0 then
    a:=2*pi-a;
   result:=a;
  end;

 function AngleDiff(a1,a2:double):double;
  begin
   result:=a2-a1;
   while result>Pi do result:=result-2*Pi;
   while result<-Pi do result:=result+2*Pi;
{   if (result>pi) or (result<-pi) then
     result:=result-2*pi*int(result/(2*pi));}
  end;

 function AboutEqual;
  begin
   result:=(abs(a.x-b.x)<=Epsilon) and
           (abs(a.y-b.y)<=Epsilon);
  end;

 function LexCompare;
  begin
   result:=-1;
   if a.y<b.y then exit;
   if a.x<b.x then exit;
   result:=1;
   if (a.x<>b.x) or (a.y<>b.y) then exit;
   result:=0;
  end;

class function TLine2.Init(const p1,p2:TVec2d):TLine2;
 var
  v:TVec2d;
 begin
  v:=p2.Sub(p1);
  Normalize(v);
  Turn90Right(v);
  result.a:=v.x;
  result.b:=v.y;
  result.c:=-(result.a*p1.x+result.b*p1.y);
 end;

function TLine2.Deviation(const point:TVec2d):double;
 begin
  result:=a*point.x+b*point.y+c;
 end;

 function Point2(x,y:double):TVec2d;
  begin
   result.x:=x;
   result.y:=y;
  end;

 function Point2(pnt:TVec2):TVec2d; overload; inline;
  begin
   result.x:=pnt.x;
   result.y:=pnt.y;
  end;


 function PointBlend(p1,p2:TVec2d;factor:double):TVec2d;
  begin
   result.x:=p1.x*(1-factor)+p2.x*factor;
   result.y:=p1.y*(1-factor)+p2.y*factor;
  end;

 function PointBlend(p1,p2:TVec2;factor:single):TVec2;
  begin
   result.x:=p1.x*(1-factor)+p2.x*factor;
   result.y:=p1.y*(1-factor)+p2.y*factor;
  end;

 function Vector2(source,target:TVec2d):TVec2d;
  begin
   result.x:=target.x-source.x;
   result.y:=target.y-source.y;
  end;

 function Direction(angle:double):TVec2d;
  begin
   result.x:=cos(angle);
   result.y:=sin(angle);
  end;

 function Segment2(x1,y1,x2,y2:double):TSegment2;
  begin
   result.x1:=x1;
   result.x2:=x2;
   result.y1:=y1;
   result.y2:=y2;
  end;

 function Segment2(x1,y1,x2,y2:integer):TSegment2;
  begin
   result.x1:=x1;
   result.x2:=x2;
   result.y1:=y1;
   result.y2:=y2;
  end;

 procedure PointOnSegment;
  var
   v,n,d:TVec2d;
  begin
   v.x:=segm.x2-segm.x1;
   v.y:=segm.y2-segm.y1;
   n:=v;
   Normalize(n);
   Turn90Right(n);
   d.x:=pnt.x-segm.x1;
   d.y:=pnt.y-segm.y1;
   deviation:=n.x*d.x+n.y*d.y;
   parameter:=(v.x*d.x+v.y*d.y)/(v.x*v.x+v.y*v.y);
  end;

 function IntersectLines;
  var
   d:double;
  begin
   d:=l1.b*l2.a-l1.a*l2.b;
   if abs(d)<Epsilon then begin
    if abs(l1.c-l2.c)<Epsilon then result:=intLine
     else result:=intNone;
    exit;
   end;
   result:=intPoint;
   p.x:=(l1.c*l2.b-l2.c*l1.b)/d;
   p.y:=(l2.c*l1.a-l1.c*l2.a)/d;
  end;

 function IntersectSegm;
  var
   l1,l2:Tline2;
   d,par:double;
  begin
   l1:=TLine2.Init(Point2(s1.x1,s1.y1),Point2(s1.x2,s1.y2));
   l2:=TLine2.Init(Point2(s2.x1,s2.y1),Point2(s2.x2,s2.y2));
   result:=IntersectLines(l1,l2,p);
   if result=intLine then begin
    // maybe segment or nothing
    result:=intNone;
    PointOnSegment(s1,Point2(s2.x1,s2.y1),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s1,Point2(s2.x2,s2.y2),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s2,Point2(s1.x1,s1.y1),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s2,Point2(s1.x2,s1.y2),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
   end;
   if result=intPoint then begin
    // explicit point or nothing
    PointOnSegment(s1,p,param1,d);
    PointOnSegment(s2,p,param2,d);
    if (param1<0) or (param1>1) or (param2<0) or (param2>1) then
     result:=intNone;
   end;
  end;

 function IntersectRects;
  begin
   r.left:=Apus.Core.Max(r1.left,r2.left);
   r.right:=Apus.Core.Min(r1.right,r2.right);
   r.top:=Apus.Core.Max(r1.top,r2.top);
   r.bottom:=Apus.Core.Min(r1.bottom,r2.bottom);
   result:=byte((r1.Left>=r2.left) and (r1.right<=r2.right) and
                (r1.top>=r2.top) and (r1.bottom<=r2.bottom))+
           byte((r2.Left>=r1.left) and (r2.right<=r1.right) and
                (r2.top>=r1.top) and (r2.bottom<=r1.bottom))*2+
            byte((r2.Left<=r1.Right) and (r2.right>=r1.left) and
                (r2.top<=r1.bottom) and (r2.bottom>=r1.top))*4;
  end;

 procedure OrderRect;
  var
   r2:TRect;
  begin
   r2.Left:=Apus.Core.Min(r.left,r.Right);
   r2.Right:=Apus.Core.Max(r.left,r.Right);
   r2.Top:=Apus.Core.Min(r.top,r.Bottom);
   r2.Bottom:=Apus.Core.Max(r.top,r.Bottom);
   r:=r2;
  end;

 function TranslationMat(x,y:double):TMat32d;
  begin
   result[0,0]:=1;   result[1,0]:=0;   result[2,0]:=x;
   result[0,1]:=0;   result[1,1]:=1;   result[2,1]:=y;
  end;

 function RotationMat(angle:double):TMat32d;
  var
   c,s:single;
  begin
   s:=sin(angle); c:=cos(angle);
   result[0,0]:=c;   result[1,0]:=-s;   result[2,0]:=0;
   result[0,1]:=s;   result[1,1]:=c;   result[2,1]:=0;
  end;

 function RotationMat2(angle:double):TMat2d;
  var
   c,s:single;
  begin
   s:=sin(angle); c:=cos(angle);
   result[0,0]:=c;   result[1,0]:=-s;
   result[0,1]:=s;   result[1,1]:=c;
  end;

 function ScaleMat(scaleX,scaleY:double):TMat32d;
  begin
   result[0,0]:=scaleX;   result[0,1]:=0;
   result[1,0]:=0;   result[1,1]:=scaleY;
   result[2,0]:=0;        result[2,1]:=0;
  end;

 procedure ToSingle32(sour:TMat32d;out dest:TMat32);
  begin
   dest[0,0]:=sour[0,0];   dest[1,0]:=sour[1,0];   dest[2,0]:=sour[2,0];
   dest[0,1]:=sour[0,1];   dest[1,1]:=sour[1,1];   dest[2,1]:=sour[2,1];
  end;

 // target = M1*M2
 procedure MultMat(m1,m2:TMat2d;out target:TMat2d);
  begin
   target[0,0]:=m1[0,0]*m2[0,0]+m1[0,1]*m2[1,0];
   target[0,1]:=m1[0,0]*m2[0,1]+m1[0,1]*m2[1,1];
   target[1,0]:=m1[1,0]*m2[0,0]+m1[1,1]*m2[1,0];
   target[1,1]:=m1[1,0]*m2[0,1]+m1[1,1]*m2[1,1];
  end;

 procedure MultMat(m1,m2:TMat32d;out target:TMat32d);
  begin
   target[0,0]:=m1[0,0]*m2[0,0]+m1[0,1]*m2[1,0];
   target[0,1]:=m1[0,0]*m2[0,1]+m1[0,1]*m2[1,1];
   target[1,0]:=m1[1,0]*m2[0,0]+m1[1,1]*m2[1,0];
   target[1,1]:=m1[1,0]*m2[0,1]+m1[1,1]*m2[1,1];
   // РЎРґРІРёРіРѕРІР°СЏ С‡Р°СЃС‚СЊ
   target[2,0]:=m2[2,0]+m1[2,0]*m2[0,0]+m1[2,1]*m2[1,0];
   target[2,1]:=m2[2,1]+m1[2,0]*m2[0,1]+m1[2,1]*m2[1,1];
  end;

procedure MultPnts(m:TMat32;v:PVec2;num,step:integer);
  var
   x,y:single;
   i:integer;
  begin
   for i:=1 to num do begin
    x:=v^.x*m[0,0]+v^.y*m[1,0]+m[2,0];
    y:=v^.x*m[0,1]+v^.y*m[1,1]+m[2,1];
    v^.x:=x; v^.y:=y;
    v:=PVec2(PtrUInt(v)+step);
   end;
  end;

 // РўСЂР°РЅСЃРїРѕРЅРёСЂРѕРІР°РЅРёРµ (РґР»СЏ РѕСЂС‚РѕРЅРѕСЂРјРёСЂРѕРІР°РЅРЅРѕР№ РјР°С‚СЂРёС†С‹ - СЌС‚Рѕ Р±СѓРґС‚ РѕР±СЂР°С‚РЅР°СЏ)
 procedure Transp2(m:TMat2d;out dest:TMat2d);
  begin
   dest[0,0]:=m[0,0]; dest[1,0]:=m[0,1];
   dest[0,1]:=m[1,0]; dest[1,1]:=m[1,1];
  end;
 procedure Transp(m:TMat32d;out dest:TMat32d);
  var
   mv:TMatrix32v absolute m;
  begin
   dest[0,0]:=m[0,0]; dest[1,0]:=m[0,1]; dest[2,0]:=-DotProduct(mv[0],mv[2]);
   dest[0,1]:=m[1,0]; dest[1,1]:=m[1,1]; dest[2,1]:=-DotProduct(mv[1],mv[2]);
  end;
 // Р’С‹С‡РёСЃР»РµРЅРёРµ РѕР±СЂР°С‚РЅРѕР№ РјР°С‚СЂРёС†С‹
 procedure Invert2(m:TMat2d;out dest:TMat2d);
  var
   la,lb:double;
   mv:TMatrix2v absolute m;
  begin
   la:=GetSqrLength(mv[0]);
   lb:=GetSqrLength(mv[1]);
   if (la=0) or (lb=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transp2(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;
  end;
 procedure Invert(m:TMat32d;out dest:TMat32d);
  var
   la,lb:double;
   mv:TMatrix2v absolute m;
  begin
   la:=GetSqrLength(mv[0]);
   lb:=GetSqrLength(mv[1]);
   if (la=0) or (lb=0) then
    raise Exception.Create('Cannot invert matrix!');
   Transp(m,dest);
   dest[0,0]:=dest[0,0]/la;   dest[1,0]:=dest[1,0]/la;  dest[2,0]:=dest[2,0]/la;
   dest[0,1]:=dest[0,1]/lb;   dest[1,1]:=dest[1,1]/lb;  dest[2,1]:=dest[2,1]/lb;
  end;

 function Bezier2D(var p0,p1,p2,p3:TVec2d;t:double):TVec2d;
  var
   b0,b1,b2,b3:double;
  begin
   // РІСЂРѕРґРµ РєР°Рє РѕРїС‚РёРјРёР·Р°С†РёСЏ
   b0:=(1-t);
   b2:=t*t;
   b3:=b2*t;    // t^3
   b2:=b2*3*b0; // 3*t^2^*(1-t)
   b1:=b0*b0;
   b0:=b0*b1;  // (1-t)^3
   b1:=b1*3*t; // 3*(1-t)^2
   result.x:=p0.x*b0+p1.x*b1+p2.x*b2+p3.x*b3;
   result.y:=p0.y*b0+p1.y*b1+p2.y*b2+p3.y*b3;
  end;

 function RandomPointInCircle(r:single):TVec2;
  var
   r2:single;
  begin
   r2:=r*r;
   repeat
    result.x:=2*r*(random-0.5);
    result.y:=2*r*(random-0.5);
   until sqr(result.x)+sqr(result.y)<=r2;
  end;

 function PointInTrg(a,b,c,pnt:TVec2d):integer;
  var
   v1,v2,v:TVec2d;
   d,d1,d2:double;
  begin
   v1:=b; VectSub(v1,a);
   v2:=c; VectSub(v2,a);
   v:=pnt; VectSub(v,a);
   d:=v1.x*v2.y-v1.y*v2.x;
   if d<=epsilon then begin
    result:=-1; exit;
   end;
   d1:=(v.x*v2.y-v.y*v2.x)/d;
   d2:=(v1.x*v.y-v1.y*v.x)/d;
   if (d1>=0) and (d2>=0) and (d1+d2<=1) then result:=1 else result:=-1;
  end;

 procedure Triangulate(pnts:PVec2d;count:integer);
  type
   pa=array[0..5] of TVec2d;
  var
   next,prev:array of integer; // РґР»СЏ РєР°Р¶РґРѕР№ РІРµСЂС€РёРЅС‹ - СѓРєР°Р·Р°С‚РµР»СЊ РЅР° СЃР»РµРґСѓСЋС‰СѓСЋ
   i,n,p,c,d:integer;
   v1,v2:TVec2d;
   vrts:^PA;
   fl:boolean;
  begin
   ASSERT(count>=3);
   setLength(trgIndices,(count-2)*3);
   if count=3 then begin
    // С‚СЂРµСѓРіРѕР»СЊРЅРёРє - РЅРёС‡РµРіРѕ РґРµР»Р°С‚СЊ РЅРµ РЅСѓР¶РЅРѕ
    trgIndices[0]:=0;
    trgIndices[1]:=1;
    trgIndices[2]:=2;
    exit;
   end;
   vrts:=pointer(pnts);
   setLength(next,count);
   setLength(prev,count);
   for i:=0 to count-1 do begin
    next[i]:=(i+1) mod count;
    prev[i]:=(i+count-1) mod count;
   end;
   n:=count;
   p:=0; c:=0;
   while n>=3 do begin
    // РїРѕРєР° РµСЃС‚СЊ С‡С‚Рѕ РѕС‚СЃРµРєР°С‚СЊ...
    v1:=vrts^[prev[p]]; VectSub(v1,vrts^[p]);
    v2:=vrts^[p]; VectSub(v2,vrts^[next[p]]);
    // РќСѓР¶РЅРѕ РґРІР° СѓСЃР»РѕРІРёСЏ: 1) СѓРіРѕР» РјРµР¶РґСѓ РІРµРєС‚РѕСЂР°РјРё РІ РЅСѓР¶РЅСѓСЋ СЃС‚РѕСЂРѕРЅСѓ Рё 2) РЅРё РѕРґРЅР° РІРµСЂС€РёРЅР° РЅРµ Р»РµР¶РёС‚ РІРЅСѓС‚СЂРё РѕС‚СЃРµРєР°РµРјРѕРіРѕ С‚СЂ-РєР°.
    fl:=crossProduct(v1,v2)>=0;
    if fl and (n>3) then begin
     d:=next[next[p]];
     while d<>prev[p] do begin
      if PointInTrg(vrts^[prev[p]],vrts^[p],vrts^[next[p]],vrts^[d])>0 then begin
       fl:=false; break;
      end;
      d:=next[d];
     end;
    end;

    if fl then begin
     trgIndices[c]:=prev[p];  inc(c);
     trgIndices[c]:=p;  inc(c);
     trgIndices[c]:=next[p];  inc(c);
     next[prev[p]]:=next[p];
     prev[next[p]]:=prev[p];
     p:=next[p];
     dec(n);
    end else
     if n=3 then exit else p:=next[p];
   end;
  end;

 function Rect2(x1,y1,x2,y2:single):TRect2; overload;
  begin
   result.x1:=x1;
   result.y1:=y1;
   result.x2:=x2;
   result.y2:=y2;
  end;

 function TransformRect(const r:TRect2;dx,dy,sx,sy:single):TRect2;
  begin
   result.x1:=r.x1*Sx+dx;
   result.y1:=r.y1*Sy+dy;
   result.x2:=r.x2*Sx+dx;
   result.y2:=r.y2*Sy+dy;
  end;

 function RoundRect(const r:TRect2):TRect;
  begin
   result.Left:=SRound(r.x1);
   result.Top:=SRound(r.y1);
   result.Right:=SRound(r.x2);
   result.Bottom:=SRound(r.y2);
  end;

{ TRect2 }

 procedure TRect2.InitWH(x,y,width,height:single);
  begin
   x1:=x; y1:=y;
   x2:=x+width;
   y2:=y+height;
  end;

 procedure TRect2.Init(x1,y1,x2,y2:single);
  begin
   self.x1:=x1; self.y1:=y1;
   self.x2:=x2; self.y2:=y2;
  end;

function TRect2.IsEmpty:boolean;
  begin
   result:=(y2<y1);
  end;

 procedure TRect2.MoveBy(dx,dy:single);
  begin
   x1:=x1+dx; x2:=x2+dx;
   y1:=y1+dy; y2:=y2+dy;
  end;

 procedure TRect2.MoveBy(delta:TVec2);
  begin
   MoveBy(delta.x,delta.y);
  end;

 procedure TRect2.Round;
  begin
   x1:=FRound(x1);
   y1:=FRound(y1);
   x2:=FRound(x2);
   y2:=FRound(y2);
  end;

function TRect2.Center: TVec2;
  begin
   result.x:=(x1+x2)/2;
   result.y:=(y1+y2)/2;
  end;

function TRect2.GetIntRect:TRect;
 begin
  result:=Rect(Floor(x1),Floor(y1),Floor(x2)+1,Floor(y2)+1);
 end;

function TRect2.Height:single;
  begin
   result:=y2-y1;
  end;

function TRect2.Width:single;
  begin
   result:=x2-x1;
  end;

 procedure TRect2.Init;
  begin
   x1:=0; y1:=0;
   x2:=-1; y2:=-1;
  end;

 procedure TRect2.Include(x,y:single);
  begin
   if IsEmpty then begin
    x1:=x; x2:=x;
    y1:=y; y2:=y;
   end else begin
    if x<x1 then x1:=x;
    if y<y1 then y1:=y;
    if x>x2 then x2:=x;
    if y>y2 then y2:=y;
   end;
  end;

 procedure TRect2.Include(r:TRect2);
  begin
   Include(r.x1,r.y1);
   Include(r.x2,r.y2);
  end;

{ TVec2d }

constructor TVec2d.Init(x,y:double);
 begin
  self.x:=x; self.y:=y;
 end;

constructor TVec2d.Init(pnt:TPoint);
 begin
  x:=pnt.x;
  y:=pnt.y;
 end;

function TVec2d.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TVec2d.Wrap(max:double);
 begin
  x:=Apus.Core.Wrap(x,max);
  y:=Apus.Core.Wrap(y,max);
 end;

function TVec2d.GetRound:TPoint;
 begin
  result.x:=round(x);
  result.y:=round(y);
 end;

function TVec2d.Dot(const p:TVec2d):double;
 begin
  result:=x*p.x+y*p.y;
 end;

function TVec2d.Cross(const p:TVec2d):double;
 begin
  result:=x*p.y-y*p.x;
 end;

function TVec2d.Length:double;
 begin
  result:=sqrt(x*x+y*y);
 end;

function TVec2d.Length2:double;
 begin
  result:=x*x+y*y;
 end;

function TVec2d.Sub(const p:TVec2d):TVec2d;
 begin
  result.x:=x-p.x;
  result.y:=y-p.y;
 end;

function TVec2d.Distance2(const p:TVec2d):double;
 begin
  result:=sqr(x-p.x)+sqr(y-p.y);
 end;

procedure TVec2d.Add(const p:TVec2d);
 begin
  x:=x+p.x;
  y:=y+p.y;
 end;

procedure TVec2d.Multiply(value:double);
 begin
  x:=x*value;
  y:=y*value;
 end;

{ TVec2 }

class operator TVec2.Implicit(a:TPoint):TVec2;
 begin
  result.x:=a.X; result.y:=a.Y;
 end;

class operator TVec2.Implicit(a:TVec2d):TVec2;
 begin
  result.x:=a.X; result.y:=a.Y;
 end;

class operator TVec2.Implicit(a:TPointF):TVec2;
 begin
  result.x:=a.X; result.y:=a.Y;
 end;

class operator TVec2.Implicit(a:TVec2):TVec2d;
begin
 result.x:=a.x; result.y:=a.y;
end;

constructor TVec2.Init(pnt:TPoint);
 begin
  x:=pnt.x;
  y:=pnt.y;
 end;

constructor TVec2.Init(x,y:single);
 begin
  self.x:=x; self.y:=y;
 end;

function TVec2.IsValid:boolean;
 begin
  result:=x=x;
 end;

function TVec2.Dot(const p:TVec2):single;
 begin
  result:=x*p.x+y*p.y;
 end;

function TVec2.Cross(const p:TVec2):single;
 begin
  result:=x*p.y-y*p.x;
 end;

function TVec2.Length:single;
 begin
  result:=sqrt(x*x+y*y);
 end;

function TVec2.Length2:single;
 begin
  result:=x*x+y*y;
 end;

function TVec2.Sub(const p:TVec2):TVec2;
 begin
  result.x:=x-p.x;
  result.y:=y-p.y;
 end;

class operator TVec2.Multiply(a,b:TVec2):TVec2;
 begin
  result.x:=a.x*b.x; result.y:=a.y*b.y;
 end;

class operator TVec2.Multiply(a:TVec2; v:single):TVec2;
 begin
  result.x:=a.x*v; result.y:=a.y*v;
 end;

class operator TVec2.Add(a,b:TVec2):TVec2;
 begin
  result.x:=a.x+b.x;
  result.y:=a.y+b.y;
 end;

class operator TVec2.Equal(a,b:TVec2):boolean;
 begin
  result:=(abs(a.x-b.x)<EpsilonS) and (abs(a.y-b.y)<EpsilonS);
 end;

class operator TVec2.Negative(a:TVec2):TVec2;
 begin
  result.x:=-a.x; result.y:=-a.y;
 end;

function TVec2.GetRound:TPoint;
 begin
  result.x:=round(x);
  result.y:=round(y);
 end;

procedure TVec2.Wrap(max:single);
 begin
  x:=Apus.Core.Wrap(x,max);
  y:=Apus.Core.Wrap(y,max);
 end;

{ TSegment2 }

function TSegment2.IsDegenerate:boolean;
 begin
  result:=(abs(x2-x1)<Epsilon) and (abs(y2-y1)<Epsilon);
 end;

end.





