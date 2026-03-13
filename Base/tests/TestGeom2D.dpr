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
  pd0,pd1:TVec2d;
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

  d:=Sqrt(a.Distance2(b));
  Check(Abs(d-Sqrt(26))<0.0001,'Distance');
  d:=a.Distance2(b);
  Check(Abs(d-26)<0.0001,'Distance2');

  pd0:=Vec2d(1,2);
  pd1:=Vec2d(1+1E-13,2-1E-13);
  Check(TVec2d.IsEqual(pd0,pd1),'IsEqual vec2d');
  c:=Vec2(3,4);
  Check((Abs(c.x-3)<0.0001) and (Abs(c.y-4)<0.0001),'Vec2 factory');
  c:=Vec2(Vec2d(5,6));
  Check((Abs(c.x-5)<0.0001) and (Abs(c.y-6)<0.0001),'Vec2 from vec2d');
  pd0:=Vec2d(7,8);
  Check((Abs(pd0.x-7)<0.0001) and (Abs(pd0.y-8)<0.0001),'Vec2d factory');
  pd1:=Vec2d(TVec2.Init(9,10));
  Check((Abs(pd1.x-9)<0.0001) and (Abs(pd1.y-10)<0.0001),'Vec2d from vec2');
  Check(TVec2d.LexCompare(Vec2d(1,2),Vec2d(1,3))<0,'LexCompare y');
  Check(TVec2d.LexCompare(Vec2d(2,10),Vec2d(1,9))>0,'LexCompare x');
  EndTest;
end;

procedure TestVec2Ops;
var
  v,u:TVec2;
  vd:TVec2d;
  a:single;
  raised:boolean;
begin
  StartTest('Vec2 ops');
  v:=TVec2.Init(0,0);
  raised:=false;
  try
    v.Normalize;
  except
    on EInvalidOp do begin
      raised:=true;
    end;
  end;
  // Current implementation raises on zero vector; track this behavior explicitly.
  Check(raised or ((v.x=0) and (v.y=0)),'Normalize zero edge');

  v:=TVec2.Init(10,0);
  u:=TVec2.Init(0,10);
  a:=v.AngleTo(u);
  Check(Abs(a-Pi/2)<0.0001,'AngleBetween');
  Check(Abs(v.Direction)<0.0001,'TVec2.Direction');
  Check(Abs(TVec2d.AngleDiff(Pi,-Pi))<0.0001,'AngleDiff wrap');

  vd:=Vec2d(1.2,-0.3);
  vd.Wrap(1.0);
  Check((vd.x>=0) and (vd.x<1) and (vd.y>=0) and (vd.y<1),'TVec2d.Wrap');
  v:=TVec2.Init(1.2,-0.3);
  v.Wrap(1.0);
  Check((v.x>=0) and (v.x<1) and (v.y>=0) and (v.y<1),'TVec2.Wrap');
  EndTest;
end;

procedure TestRect2s;
var
  r:TRect2;
  c:TVec2;
begin
  StartTest('Rect2');
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
  p:TVec2d;
  st:TStatus;
  seg1,seg2:TSegment2;
  p2:TVec2d;
  t1,t2:double;
begin
  StartTest('Lines/segments');
  l1:=TLine2.Init(Vec2d(0,0),Vec2d(1,1));
  l2:=TLine2.Init(Vec2d(0,1),Vec2d(1,0));
  st:=TLine2.Intersect(l1,l2,p);
  Check((st=intPoint) and (Abs(p.x-0.5)<0.0001) and (Abs(p.y-0.5)<0.0001),'IntersectLines');

  seg1:=Segment2(0,0,10,0);
  seg2:=Segment2(5,-5,5,5);
  st:=TSegment2.Intersect(seg1,seg2,p2,t1,t2);
  Check((st=intPoint) and (Abs(p2.x-5)<0.0001) and (Abs(p2.y)<0.0001),'IntersectSegm');
  EndTest;
end;

procedure TestPolygonOps;
var
  a,b,c:TVec2d;
  p:TSegment2;
begin
  StartTest('Polygon ops');
  a:=Vec2d(0,0);
  b:=Vec2d(10,0);
  c:=Vec2d(0,10);
  p:=TSegment2.Init(2,2,0,0);
  Check(p.PointInTriangle(a,b,c)=1,'PointInTrg inside');
  p:=TSegment2.Init(10,10,0,0);
  Check(p.PointInTriangle(a,b,c)=-1,'PointInTrg outside');
  EndTest;
end;

procedure TestGeom2DUtility;
var
  v1,v2,v3:TVec2;
  m2,m2b,m2i:TMat2d;
  m32,m32b,m32i:TMat32d;
  m32s,m32si:TMat32;
  p:TVec2d;
  seg:TSegment2;
  t,dev:double;
  r:TRect;
  rs:TRect2;
  pt:TVec2;
  pt0:TVec2;
  poly:array[0..2] of TVec2d;
  poly4:array[0..3] of TVec2d;
  ln:TLine2;
  dv:TVec2d;
  b0,b1,b2,b3:TVec2d;
  i:integer;
begin
  StartTest('Geom2D utility');
  v1:=TVec2.Init(2,3);
  v2:=TVec2.Init(4,5);
  Check(Abs(v1.Dot(v2)-23)<0.0001,'Dot');
  Check(Abs(v1.Cross(v2)+2)<0.0001,'Cross');
  Check(Abs(v1.Length-Sqrt(13))<0.0001,'Length');
  Check(Abs(v1.Length2-13)<0.0001,'Length2');
  v1:=v1+v2;
  Check((Abs(v1.x-6)<0.0001) and (Abs(v1.y-8)<0.0001),'VectAdd');
  v1:=v1.Sub(v2);
  Check((Abs(v1.x-2)<0.0001) and (Abs(v1.y-3)<0.0001),'VectSub');
  v3:=v1*v2;
  Check((Abs(v3.x-8)<0.0001) and (Abs(v3.y-15)<0.0001),'CompMul');
  v3:=v2.DivBy(v1);
  Check((Abs(v3.x-2)<0.0001) and (Abs(v3.y-1.666666)<0.01),'DivBy');
  v3.Invert;
  Check((Abs(v3.x-0.5)<0.0001) and (Abs(v3.y-0.6)<0.01),'Invert');
  Check(Abs(Vec2d(1,0).ClockwiseAngleTo(Vec2d(0,1))-3*Pi/2)<0.0001,'ClockwiseAngleTo');
  Check(Abs(Vec2d(0,1).Direction-Pi/2)<0.0001,'TVec2d.Direction');
  dv:=Vec2d(2,3);
  dv:=dv.Turn90R;
  dv:=dv.Turn90L;
  Check((Abs(dv.x-2)<0.0001) and (Abs(dv.y-3)<0.0001),'Turn90R/L');
  dv.Turn(Pi/2);
  dv:=TVec2d.Lerp(Vec2d(0,0),Vec2d(2,4),0.25);
  Check((Abs(dv.x-0.5)<0.0001) and (Abs(dv.y-1)<0.0001),'Lerp vec2d');
  dv:=TVec2d.Between(Vec2d(1,1),Vec2d(4,6));
  Check((Abs(dv.x-3)<0.0001) and (Abs(dv.y-5)<0.0001),'Direction from-to');
  dv:=TVec2d.FromAngle(Pi/2);
  Check((Abs(dv.x)<0.0001) and (Abs(dv.y-1)<0.0001),'Direction from-angle');
  v3:=TVec2.Lerp(TVec2.Init(0,0),TVec2.Init(4,8),0.25);
  Check((Abs(v3.x-1)<0.0001) and (Abs(v3.y-2)<0.0001),'Lerp vec2');

  b0:=Vec2d(0,0);
  b1:=Vec2d(0,1);
  b2:=Vec2d(1,1);
  b3:=Vec2d(1,0);
  p:=TVec2d.Bezier(b0,b1,b2,b3,0.5);
  Check((p.x>0) and (p.y>0),'Bezier2D');
  seg:=Segment2(0,0,10,0);
  seg.ProjectPoint(Vec2d(3,2),t,dev);
  Check((Abs(t-0.3)<0.0001) and (Abs(Abs(dev)-2)<0.0001),'PointOnSegment');
  seg:=TSegment2.Init(1,2,3,4);
  Check((Abs(seg.x1-1)<0.0001) and (Abs(seg.y1-2)<0.0001) and (Abs(seg.x2-3)<0.0001) and (Abs(seg.y2-4)<0.0001),'TSegment2.Init int');
  Check(Segment2(0,0,0,0).IsDegenerate,'TSegment2.IsDegenerate');
  ln.a:=0; ln.b:=1; ln.c:=-2;
  Check(Abs(ln.Deviation(Vec2d(0,2)))<0.0001,'TLine2.Deviation');
  Check(TLine2.Intersect(TLine2.Init(Vec2d(0,0),Vec2d(1,0)),TLine2.Init(Vec2d(0,1),Vec2d(1,1)),p)=intNone,'TLine2.Intersect parallel');
  Check(TLine2.Intersect(TLine2.Init(Vec2d(0,0),Vec2d(1,0)),TLine2.Init(Vec2d(2,0),Vec2d(5,0)),p)=intLine,'TLine2.Intersect collinear');

  m2:=TMat2d.Rotation(Pi/4);
  m2b:=m2;
  m2b:=m2.Transposed;
  m2i:=m2.Inverted;
  m2b:=m2*m2i;
  Check(Abs(m2b[0,0]-1)<0.01,'Mult/Invert2');
  m32:=TMat32d.Translation(1,2);
  m32:=TMat32d.Scale(2,3);
  m32:=TMat32d.Rotation(Pi/6);
  m32i:=m32.Inverted;
  m32i:=m32.Transposed;
  m32:=TMat32d.Translation(3,-2);
  m32b:=TMat32d.Scale(2,4);
  m32:=m32*m32b;
  m32i:=m32.Inverted;
  ToSingle32(m32,m32s);
  ToSingle32(m32i,m32si);
  pt:=TVec2.Init(1,2);
  pt0:=pt;
  MultPnts(m32s,@pt,1,SizeOf(pt));
  MultPnts(m32si,@pt,1,SizeOf(pt));
  Check((Abs(pt.x-pt0.x)<0.01) and (Abs(pt.y-pt0.y)<0.01),'Mat32 inverse chain');

  r:=Rect(5,1,1,5);
  TRect2.OrderRect(r);
  Check((r.Left=1) and (r.Top=1) and (r.Right=5) and (r.Bottom=5),'OrderRect');
  TRect2.IntersectRect(Rect(0,0,10,10),Rect(5,5,20,20),r);
  Check((r.Left=5) and (r.Top=5),'IntersectRects');
  Check(TRect2.IntersectRect(Rect(0,0,10,10),Rect(2,2,8,8),r)=6,'IntersectRects contain');
  Check(TRect2.IntersectRect(Rect(0,0,2,2),Rect(3,3,4,4),r)=0,'IntersectRects disjoint');
  rs:=Rect2(0,0,5,5);
  rs:=rs.Transform(1,2,2,3);
  r:=rs.Rounded;
  Check(r.Left<=r.Right,'RoundRect');
  rs:=Rect2(1,1,3,5);
  rs:=rs.Transform(-1,2,-2,0.5);
  r:=rs.Rounded;
  Check(r.Left>r.Right,'RoundRect negative scale');

  pt:=TVec2.RandomInCircle(2);
  Check(pt.Length<=2.001,'RandomPointInCircle');

  poly[0]:=Vec2d(0,0);
  poly[1]:=Vec2d(10,0);
  poly[2]:=Vec2d(0,10);
  Triangulate(@poly[0],3);
  Check(Length(trgIndices)=3,'Triangulate triangle');
  poly4[0]:=Vec2d(0,0);
  poly4[1]:=Vec2d(10,0);
  poly4[2]:=Vec2d(10,10);
  poly4[3]:=Vec2d(0,10);
  Triangulate(@poly4[0],4);
  Check(Length(trgIndices)=6,'Triangulate quad size');
  for i:=0 to High(trgIndices) do begin
    Check((trgIndices[i]>=0) and (trgIndices[i]<=3),'Triangulate quad index range');
  end;
  EndTest;
end;

begin
  try
    TestVec2Core;
    TestVec2Ops;
    TestRect2s;
    TestLinesAndSegments;
    TestPolygonOps;
    TestGeom2DUtility;
    writeln;
    writeln('TOTAL: ',testsTotal,' checks, FAILED: ',testsFailed);
    if testsFailed>0 then
      ExitCode:=1
    else
      writeln('All OK');
  except
    on e:Exception do begin
      writeln;
      writeln('TEST FAILED! Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.


