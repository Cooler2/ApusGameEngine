{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestGeom2D;

uses
  SysUtils,
  Math,
  Types,
  Apus.Core,
  Apus.Geom2D;

{$INCLUDE Test.inc}

procedure TestVec2Core;
var
  a,b,c:TVec2;
  d:single;
begin
  StartTest('Vec2 core');
  a:=TVec2.Init(3,4);
  b:=TVec2.Init(-2,5);
  Check(Abs(a.Length-5)<0.0001,'Length');
  Check(Abs(a.Length2-25)<0.0001,'Length2');
  Check(Abs(a.Dot(b)-14)<0.0001,'Dot');
  Check(Abs(a.Cross(b)-23)<0.0001,'Cross');
  c:=a.Sub(b);
  Check((Abs(c.x-5)<0.0001) and (Abs(c.y+1)<0.0001),'Sub');
  c:=a+b;
  Check((Abs(c.x-1)<0.0001) and (Abs(c.y-9)<0.0001),'Add');
  c:=a*2;
  Check((Abs(c.x-6)<0.0001) and (Abs(c.y-8)<0.0001),'Mul scalar');
  c:=-a;
  Check((Abs(c.x+3)<0.0001) and (Abs(c.y+4)<0.0001),'Neg');

  d:=Distance(a,b);
  Check(Abs(d-Sqrt(26))<0.0001,'Distance');
  d:=Distance2(a,b);
  Check(Abs(d-26)<0.0001,'Distance2');
  EndTest;
end;

procedure TestVec2Ops;
var
  v,u:TVec2;
  a:single;
  raised:boolean;
begin
  StartTest('Vec2 ops');
  v:=TVec2.Init(0,0);
  raised:=false;
  try
    Normalize(v);
  except
    on EInvalidOp do begin
      raised:=true;
    end;
  end;
  // Current implementation raises on zero vector; track this behavior explicitly.
  Check(raised or ((v.x=0) and (v.y=0)),'Normalize zero edge');

  v:=TVec2.Init(10,0);
  u:=TVec2.Init(0,10);
  a:=VectAngle(v,u);
  Check(Abs(a-Pi/2)<0.0001,'VectAngle');
  Check(Abs(AngleDiff(Pi,-Pi))<0.0001,'AngleDiff wrap');
  EndTest;
end;

procedure TestRect2s;
var
  r:TRect2s;
  c:TVec2;
begin
  StartTest('Rect2s');
  r.Init;
  Check(r.IsEmpty,'Init empty');
  r.Include(1,2);
  r.Include(3,6);
  Check((Abs(r.Width-2)<0.0001) and (Abs(r.Height-4)<0.0001),'Width/Height');
  c:=r.Center;
  Check((Abs(c.x-2)<0.0001) and (Abs(c.y-4)<0.0001),'Center');
  r.MoveBy(1,-1);
  Check((Abs(r.left-2)<0.0001) and (Abs(r.top-1)<0.0001),'MoveBy');
  EndTest;
end;

procedure TestLinesAndSegments;
var
  l1,l2:TLine2;
  p:TPoint2;
  st:TStatus;
  seg1,seg2:TSegment2;
  p2:TPoint2;
  t1,t2:double;
begin
  StartTest('Lines/segments');
  SetLine(Point2(0,0),Point2(1,1),l1);
  SetLine(Point2(0,1),Point2(1,0),l2);
  st:=IntersectLines(l1,l2,p);
  Check((st=intPoint) and (Abs(p.x-0.5)<0.0001) and (Abs(p.y-0.5)<0.0001),'IntersectLines');

  seg1:=Segment2(0,0,10,0);
  seg2:=Segment2(5,-5,5,5);
  st:=IntersectSegm(seg1,seg2,p2,t1,t2);
  Check((st=intPoint) and (Abs(p2.x-5)<0.0001) and (Abs(p2.y)<0.0001),'IntersectSegm');
  EndTest;
end;

procedure TestPolygonOps;
var
  a,b,c,p:TPoint2;
begin
  StartTest('Polygon ops');
  a:=Point2(0,0);
  b:=Point2(10,0);
  c:=Point2(0,10);
  p:=Point2(2,2);
  Check(PointInTrg(a,b,c,p)=1,'PointInTrg inside');
  p:=Point2(10,10);
  Check(PointInTrg(a,b,c,p)=-1,'PointInTrg outside');
  EndTest;
end;

procedure TestGeom2DUtility;
var
  v1,v2,v3:TVec2;
  m2,m2b,m2i:TMatrix2;
  m32,m32i:TMatrix32;
  p:TPoint2;
  seg:TSegment2;
  t,dev:double;
  r:TRect;
  rs:TRect2s;
  pt:TVec2;
  poly:array[0..2] of TPoint2;
  ln:TLine2;
  dv:TPoint2;
  b0,b1,b2,b3:TPoint2;
begin
  StartTest('Geom2D utility');
  v1:=TVec2.Init(2,3);
  v2:=TVec2.Init(4,5);
  Check(Abs(DotProduct(v1,v2)-23)<0.0001,'DotProduct fn');
  Check(Abs(CrossProduct(v1,v2)+2)<0.0001,'CrossProduct fn');
  Check(Abs(GetLength(v1)-Sqrt(13))<0.0001,'GetLength');
  Check(Abs(GetSqrLength(v1)-13)<0.0001,'GetSqrLength');
  VectAdd(v1,v2);
  Check((Abs(v1.x-6)<0.0001) and (Abs(v1.y-8)<0.0001),'VectAdd');
  VectSub(v1,v2);
  Check((Abs(v1.x-2)<0.0001) and (Abs(v1.y-3)<0.0001),'VectSub');
  v3:=VectMult(v1,v2);
  Check((Abs(v3.x-8)<0.0001) and (Abs(v3.y-15)<0.0001),'VectMult vec');
  v3:=VectDiv(v2,v1);
  Check((Abs(v3.x-2)<0.0001) and (Abs(v3.y-1.666666)<0.01),'VectDiv');
  VectInv(v3);
  Check((Abs(v3.x-0.5)<0.0001) and (Abs(v3.y-0.6)<0.01),'VectInv');
  Check(Abs(VectAngleClockwise(Point2(1,0),Point2(0,1))-3*Pi/2)<0.0001,'VectAngleClockwise');
  dv:=Point2(2,3);
  Turn90Right(dv);
  Turn90Left(dv);
  dv:=Turn90R(dv);
  dv:=Turn90L(dv);
  VectTurn(dv,Pi/2);

  b0:=Point2(0,0);
  b1:=Point2(0,1);
  b2:=Point2(1,1);
  b3:=Point2(1,0);
  p:=Bezier2D(b0,b1,b2,b3,0.5);
  Check((p.x>0) and (p.y>0),'Bezier2D');
  seg:=Segment2(0,0,10,0);
  PointOnSegment(seg,Point2(3,2),t,dev);
  Check((Abs(t-0.3)<0.0001) and (Abs(Abs(dev)-2)<0.0001),'PointOnSegment');
  Check(SegmAboutZero(Segment2(0,0,0,0)),'SegmAboutZero');
  ln.a:=0; ln.b:=1; ln.c:=-2;
  Check(Abs(PointDev2(ln,Point2(0,2)))<0.0001,'PointDev2');

  m2:=RotationMat2(Pi/4);
  m2b:=m2;
  Transp2(m2,m2b);
  Invert2(m2,m2i);
  MultMat(m2,m2i,m2b);
  Check(Abs(m2b[0,0]-1)<0.01,'Mult/Invert2');
  m32:=TranslationMat(1,2);
  m32:=ScaleMat(2,3);
  m32:=RotationMat(Pi/6);
  Invert(m32,m32i);
  Transp(m32,m32i);

  r:=Rect(5,1,1,5);
  OrderRect(r);
  Check((r.Left=1) and (r.Top=1) and (r.Right=5) and (r.Bottom=5),'OrderRect');
  IntersectRects(Rect(0,0,10,10),Rect(5,5,20,20),r);
  Check((r.Left=5) and (r.Top=5),'IntersectRects');
  rs:=Rect2s(0,0,5,5);
  rs:=TransformRect(rs,1,2,2,3);
  r:=RoundRect(rs);
  Check(r.Left<=r.Right,'RoundRect');

  pt:=RandomPointInCircle(2);
  Check(pt.Length<=2.001,'RandomPointInCircle');

  poly[0]:=Point2(0,0);
  poly[1]:=Point2(10,0);
  poly[2]:=Point2(0,10);
  Triangulate(@poly[0],3);
  Check(Length(trgIndices)>=3,'Triangulate');
  EndTest;
end;

begin
  TestVec2Core;
  TestVec2Ops;
  TestRect2s;
  TestLinesAndSegments;
  TestPolygonOps;
  TestGeom2DUtility;
  writeln;
  writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
  if testsFailed>0 then begin
    halt(1);
  end;
  writeln('All OK');
end.
