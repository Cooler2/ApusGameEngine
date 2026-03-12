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
   class function AngleDiff(a1,a2:double):double; static;
   class function IsEqual(const a,b:TVec2d):boolean; static;
   class function LexCompare(const a,b:TVec2d):integer; static;
   class function Lerp(const p1,p2:TVec2d;factor:double):TVec2d; static;
   class function Bezier(const p0,p1,p2,p3:TVec2d;t:double):TVec2d; static;
   class function Between(const source,target:TVec2d):TVec2d; static;
   class function FromAngle(angle:double):TVec2d; static;
   function GetRound:TPoint;
   function IsValid:boolean; inline;
   procedure Wrap(max:double); inline;
   procedure Normalize; inline;
   function Dot(const p:TVec2d):double; inline;
   function Cross(const p:TVec2d):double; inline;
   function Direction:double; inline;
   function AngleTo(const p:TVec2d):double; inline;
   function ClockwiseAngleTo(const p:TVec2d):double; inline;
   function Length:double; inline;
   function Length2:double; inline;
   function Sub(const p:TVec2d):TVec2d; inline;
   function Distance2(const p:TVec2d):double; inline;
   procedure Turn(angle:double); inline;
   function Turn90R:TVec2d; inline;
   function Turn90L:TVec2d; inline;
   procedure Add(const p:TVec2d); inline;
   procedure Multiply(value:double); inline;
  end;
  PVec2d=^TVec2d;

  TVec2=packed record
   x,y:single;
   constructor Init(x,y:single); overload;
   constructor Init(pnt:TPoint); overload;
   class function Lerp(const p1,p2:TVec2;factor:single):TVec2; static;
   class function RandomInCircle(r:single):TVec2; static;
   function GetRound:TPoint;
   function IsValid:boolean; inline;
   procedure Normalize; inline;
   function Dot(const p:TVec2):single; inline;
   function Cross(const p:TVec2):single; inline;
   function Direction:single; inline;
   function AngleTo(const p:TVec2):single; inline;
   function Length:single; inline;
   function Length2:single; inline;
   function Sub(const p:TVec2):TVec2; inline;
   function Distance2(const p:TVec2):single; inline;
   function DivBy(const p:TVec2):TVec2; inline;
   procedure Invert; inline;
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
   class function Intersect(const l1,l2:TLine2;out p:TVec2d):TStatus; static;
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
   class function Init(x1,y1,x2,y2:integer):TSegment2; overload; static;
   class function Init(x1,y1,x2,y2:double):TSegment2; overload; static;
   procedure PointInfo(const pnt:TVec2d;out parameter,deviation:double);
   class function Intersect(const s1,s2:TSegment2;out p:TVec2d;out param1,param2:double):TStatus; static;
   function PointInTriangle(const a,b,c:TVec2d):integer;
   function IsDegenerate:boolean; inline;
  end;

  TMat2d=packed record
   private
    function GetItem(i,j:integer):double; inline;
    procedure SetItem(i,j:integer;value:double); inline;
   public
    class function Rotation(angle:double):TMat2d; static;
    class operator Multiply(const a,b:TMat2d):TMat2d;
    procedure Transpose;
    function Transposed:TMat2d;
    procedure Invert;
    function Inverted:TMat2d;
    function Determinant:double; inline;
    property Items[i,j:integer]:double read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..1,0..1] of double);
    1:(rows:array[0..1] of TVec2d);
  end;
  TMat32d=packed record
   private
    function GetItem(i,j:integer):double; inline;
    procedure SetItem(i,j:integer;value:double); inline;
   public
    class function Translation(x,y:double):TMat32d; static;
    class function Rotation(angle:double):TMat32d; static;
    class function Scale(scaleX,scaleY:double):TMat32d; static;
    class operator Multiply(const a,b:TMat32d):TMat32d;
    procedure Transpose;
    function Transposed:TMat32d;
    procedure Invert;
    function Inverted:TMat32d;
    property Items[i,j:integer]:double read GetItem write SetItem; default;
    case integer of
    0:(v:array[0..2,0..1] of double);
    1:(rows:array[0..2] of TVec2d);
  end;
  // Single precision version
  TMat2=array[0..1,0..1] of single;
  TMat32=array[0..2,0..1] of single;
  // Vector versions
  TMatrix2vd=array[0..1] of TVec2d;
  TMatrix32vd=array[0..2] of TVec2d;
  TMatrix32v=array[0..2] of TVec2;


 const
  NaN = 0.0/0.0;
  IdentMatrix2:TMat2d=(v:((1,0),(0,1)));
  IdentMatrix32:TMat32d=(v:((1,0),(0,1),(0,0)));
  IdentMat2:TMat2=((1,0),(0,1));
  IdentMat32:TMat32=((1,0),(0,1),(0,0));

  InvalidPoint2:TVec2d=(x:NaN;y:NaN);
  InvalidVec2:TVec2=(x:NaN;y:NaN);

 // Setup point
 function Vec2(x,y:single):TVec2; overload; inline;
 function Vec2(v:TVec2d):TVec2; overload; inline;
 function Vec2d(x,y:double):TVec2d; overload; inline;
 function Vec2d(v:TVec2):TVec2d; overload; inline;

 // Integer operations
 // Rect relation: 0 no intersection, 1 r1 inside r2, 2 r2 inside r1, 4 intersect
 // Works only for ordered rectangles.
 function IntersectRects(r1,r2:TRect;out r:TRect):integer;
 procedure OrderRect(var r:TRect); // Order coordinates in ascending direction

 procedure ToSingle32(sour:TMat32d;out dest:TMat32);

 procedure MultPnts(m:TMat32;v:PVec2;num,step:integer);

 // Rectangle
 function Rect2(x1,y1,x2,y2:single):TRect2; overload; inline;
 function TransformRect(const r:TRect2;dx,dy,sx,sy:single):TRect2;
 function RoundRect(const r:TRect2):TRect;

 var
  trgIndices:array of integer; // triangulation output indices
 // Triangulation of a closed polygon (builds n-2 triangles). Must be CLOCKWISE.
 procedure Triangulate(pnts:PVec2d;count:integer);

implementation
 uses Math, Apus.Types, Apus.Core, SysUtils;

function TVec2d.Direction:double;
begin
  result:=ArcTan2(y,x);
end;

function TVec2d.AngleTo(const p:TVec2d):double;
var
  n1,n2:TVec2d;
  c:double;
begin
  n1:=self;
  n2:=p;
  n1.Normalize;
  n2.Normalize;
  c:=n1.Dot(n2);
  if c>1 then begin
    c:=1;
  end;
  if c<-1 then begin
    c:=-1;
  end;
  result:=ArcCos(c);
end;

function TVec2d.ClockwiseAngleTo(const p:TVec2d):double;
begin
  result:=AngleTo(p);
  if Cross(p)>0 then begin
    result:=2*Pi-result;
  end;
end;

function TVec2.Direction:single;
begin
  result:=ArcTan2(y,x);
end;

function TVec2.AngleTo(const p:TVec2):single;
var
  n1,n2:TVec2;
  c:single;
begin
  n1:=self;
  n2:=p;
  n1.Normalize;
  n2.Normalize;
  c:=n1.Dot(n2);
  if c>1 then begin
    c:=1;
  end;
  if c<-1 then begin
    c:=-1;
  end;
  result:=ArcCos(c);
end;

 function AngleDiff(a1,a2:double):double;
  begin
   result:=a2-a1;
   while result>Pi do result:=result-2*Pi;
   while result<-Pi do result:=result+2*Pi;
{   if (result>pi) or (result<-pi) then
     result:=result-2*pi*int(result/(2*pi));}
  end;

 function IsEqual;
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
  v.Normalize;
  v:=v.Turn90R;
  result.a:=v.x;
  result.b:=v.y;
  result.c:=-(result.a*p1.x+result.b*p1.y);
 end;

function TLine2.Deviation(const point:TVec2d):double;
 begin
  result:=a*point.x+b*point.y+c;
 end;

 function Vec2(x,y:single):TVec2; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
  end;

 function Vec2(v:TVec2d):TVec2; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
  end;

 function Vec2d(x,y:double):TVec2d; overload; inline;
  begin
   result.x:=x;
   result.y:=y;
  end;

 function Vec2d(v:TVec2):TVec2d; overload; inline;
  begin
   result.x:=v.x;
   result.y:=v.y;
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
   n.Normalize;
   n:=n.Turn90R;
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
   l1:=TLine2.Init(Vec2d(s1.x1,s1.y1),Vec2d(s1.x2,s1.y2));
   l2:=TLine2.Init(Vec2d(s2.x1,s2.y1),Vec2d(s2.x2,s2.y2));
   result:=IntersectLines(l1,l2,p);
   if result=intLine then begin
    // maybe segment or nothing
    result:=intNone;
    PointOnSegment(s1,Vec2d(s2.x1,s2.y1),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s1,Vec2d(s2.x2,s2.y2),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s2,Vec2d(s1.x1,s1.y1),par,d);
    if (par>=0) and (par<=1) then begin result:=intSegment; exit; end;
    PointOnSegment(s2,Vec2d(s1.x2,s1.y2),par,d);
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

function TMat2d.GetItem(i,j:integer):double;
begin
  result:=v[i,j];
end;

procedure TMat2d.SetItem(i,j:integer;value:double);
begin
  v[i,j]:=value;
end;

class function TMat2d.Rotation(angle:double):TMat2d;
var
  c,s:double;
begin
  s:=sin(angle);
  c:=cos(angle);
  result[0,0]:=c;
  result[1,0]:=-s;
  result[0,1]:=s;
  result[1,1]:=c;
end;

class operator TMat2d.Multiply(const a,b:TMat2d):TMat2d;
begin
  result[0,0]:=a[0,0]*b[0,0]+a[0,1]*b[1,0];
  result[0,1]:=a[0,0]*b[0,1]+a[0,1]*b[1,1];
  result[1,0]:=a[1,0]*b[0,0]+a[1,1]*b[1,0];
  result[1,1]:=a[1,0]*b[0,1]+a[1,1]*b[1,1];
end;

procedure TMat2d.Transpose;
begin
  Swap(v[1,0],v[0,1]);
end;

function TMat2d.Transposed:TMat2d;
begin
  result:=self;
  result.Transpose;
end;

function TMat2d.Determinant:double;
begin
  result:=v[0,0]*v[1,1]-v[0,1]*v[1,0];
end;

function TMat2d.Inverted:TMat2d;
var
  la,lb:double;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  if (la=0) or (lb=0) then begin
    raise Exception.Create('Cannot invert matrix!');
  end;
  result:=Transposed;
  result[0,0]:=result[0,0]/la;
  result[1,0]:=result[1,0]/la;
  result[0,1]:=result[0,1]/lb;
  result[1,1]:=result[1,1]/lb;
end;

procedure TMat2d.Invert;
begin
  self:=Inverted;
end;

function TMat32d.GetItem(i,j:integer):double;
begin
  result:=v[i,j];
end;

procedure TMat32d.SetItem(i,j:integer;value:double);
begin
  v[i,j]:=value;
end;

class function TMat32d.Translation(x,y:double):TMat32d;
begin
  result:=IdentMatrix32;
  result[2,0]:=x;
  result[2,1]:=y;
end;

class function TMat32d.Rotation(angle:double):TMat32d;
var
  c,s:double;
begin
  s:=sin(angle);
  c:=cos(angle);
  result[0,0]:=c;
  result[1,0]:=-s;
  result[2,0]:=0;
  result[0,1]:=s;
  result[1,1]:=c;
  result[2,1]:=0;
end;

class function TMat32d.Scale(scaleX,scaleY:double):TMat32d;
begin
  result[0,0]:=scaleX;
  result[0,1]:=0;
  result[1,0]:=0;
  result[1,1]:=scaleY;
  result[2,0]:=0;
  result[2,1]:=0;
end;

class operator TMat32d.Multiply(const a,b:TMat32d):TMat32d;
begin
  result[0,0]:=a[0,0]*b[0,0]+a[0,1]*b[1,0];
  result[0,1]:=a[0,0]*b[0,1]+a[0,1]*b[1,1];
  result[1,0]:=a[1,0]*b[0,0]+a[1,1]*b[1,0];
  result[1,1]:=a[1,0]*b[0,1]+a[1,1]*b[1,1];
  result[2,0]:=b[2,0]+a[2,0]*b[0,0]+a[2,1]*b[1,0];
  result[2,1]:=b[2,1]+a[2,0]*b[0,1]+a[2,1]*b[1,1];
end;

procedure TMat32d.Transpose;
begin
  self:=Transposed;
end;

function TMat32d.Transposed:TMat32d;
begin
  result[0,0]:=v[0,0];
  result[1,0]:=v[0,1];
  result[2,0]:=-rows[0].Dot(rows[2]);
  result[0,1]:=v[1,0];
  result[1,1]:=v[1,1];
  result[2,1]:=-rows[1].Dot(rows[2]);
end;

function TMat32d.Inverted:TMat32d;
var
  la,lb:double;
begin
  la:=rows[0].Length2;
  lb:=rows[1].Length2;
  if (la=0) or (lb=0) then begin
    raise Exception.Create('Cannot invert matrix!');
  end;
  result:=Transposed;
  result[0,0]:=result[0,0]/la;
  result[1,0]:=result[1,0]/la;
  result[2,0]:=result[2,0]/la;
  result[0,1]:=result[0,1]/lb;
  result[1,1]:=result[1,1]/lb;
  result[2,1]:=result[2,1]/lb;
end;

procedure TMat32d.Invert;
begin
  self:=Inverted;
end;

 procedure ToSingle32(sour:TMat32d;out dest:TMat32);
  begin
   dest[0,0]:=sour[0,0];   dest[1,0]:=sour[1,0];   dest[2,0]:=sour[2,0];
   dest[0,1]:=sour[0,1];   dest[1,1]:=sour[1,1];   dest[2,1]:=sour[2,1];
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

function Bezier2D(var p0,p1,p2,p3:TVec2d;t:double):TVec2d;
  var
   b0,b1,b2,b3:double;
  begin
   // Minor micro-optimization
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
   v1:=b.Sub(a);
   v2:=c.Sub(a);
   v:=pnt.Sub(a);
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
   next,prev:array of integer; // for each vertex: links to next/previous vertex
   i,n,p,c,d:integer;
   v1,v2:TVec2d;
   vrts:^PA;
   fl:boolean;
  begin
   ASSERT(count>=3);
   setLength(trgIndices,(count-2)*3);
   if count=3 then begin
    // Already a triangle, nothing to clip
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
    // Continue clipping while ears remain
    v1:=vrts^[prev[p]].Sub(vrts^[p]);
    v2:=vrts^[p].Sub(vrts^[next[p]]);
    // Ear test: convex corner and no other vertex inside candidate triangle.
    fl:=v1.Cross(v2)>=0;
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

class function TVec2d.Lerp(const p1,p2:TVec2d;factor:double):TVec2d;
 begin
  result.x:=p1.x*(1-factor)+p2.x*factor;
  result.y:=p1.y*(1-factor)+p2.y*factor;
 end;

class function TVec2d.Between(const source,target:TVec2d):TVec2d;
 begin
  result.x:=target.x-source.x;
  result.y:=target.y-source.y;
 end;

class function TVec2d.FromAngle(angle:double):TVec2d;
 begin
  result.x:=cos(angle);
  result.y:=sin(angle);
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

procedure TVec2d.Normalize;
 var
  l:double;
 begin
  l:=Length;
  ASSERT(l>Epsilon,'Normalize zero-length vector');
  x:=x/l;
  y:=y/l;
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

procedure TVec2d.Turn(angle:double);
 var
  nx,ny:double;
 begin
  nx:=x*cos(angle)-y*sin(angle);
  ny:=x*sin(angle)+y*cos(angle);
  x:=nx;
  y:=ny;
 end;

function TVec2d.Turn90R:TVec2d;
 begin
  result.x:=y;
  result.y:=-x;
 end;

function TVec2d.Turn90L:TVec2d;
 begin
  result.x:=-y;
  result.y:=x;
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

class function TVec2.Lerp(const p1,p2:TVec2;factor:single):TVec2;
 begin
  result.x:=p1.x*(1-factor)+p2.x*factor;
  result.y:=p1.y*(1-factor)+p2.y*factor;
 end;

function TVec2.IsValid:boolean;
 begin
  result:=x=x;
 end;

procedure TVec2.Normalize;
 var
  l:single;
 begin
  l:=Length;
  ASSERT(l>EpsilonS,'Normalize zero-length vector');
  x:=x/l;
  y:=y/l;
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

function TVec2.Distance2(const p:TVec2):single;
 var
  dx,dy:single;
 begin
  dx:=x-p.x;
  dy:=y-p.y;
  result:=dx*dx+dy*dy;
 end;

function TVec2.DivBy(const p:TVec2):TVec2;
 begin
  result.x:=x/p.x;
  result.y:=y/p.y;
 end;

procedure TVec2.Invert;
 begin
  x:=1/x;
  y:=1/y;
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






