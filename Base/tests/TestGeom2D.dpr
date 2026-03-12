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

begin
  TestVec2Core;
  TestVec2Ops;
  TestRect2s;
  TestLinesAndSegments;
  TestPolygonOps;
  writeln;
  writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
  if testsFailed>0 then begin
    halt(1);
  end;
  writeln('All OK');
end.
