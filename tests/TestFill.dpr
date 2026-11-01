// Tests for TFill (R-39): constructors, CSS angles, stops, spread, premultiplied
// interpolation, Mix rules for style transitions. CPU only, no GL.
{$APPTYPE CONSOLE}
program TestFill;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Colors,
  Apus.Geom2D,
  Apus.Engine.Types;

{$I ..\Base\tests\Test.inc}

var
  box:TRect2;

function Near(a,b:single;eps:single=1E-4):boolean;
begin
  result:=abs(a-b)<=eps;
end;

// colors equal within d per channel
function SameColor(c1,c2:cardinal;d:integer=1):boolean;
var
  i:integer;
begin
  for i:=0 to 3 do
    if abs(integer((c1 shr (i*8)) and $FF)-integer((c2 shr (i*8)) and $FF))>d then exit(false);
  result:=true;
end;

procedure TestSolid;
var
  f:TFill;
begin
  StartTest('Solid and none');
  f:=TFill.Solid($FF102030);
  Check(f.kind=fkSolid,'kind');
  Check(f.ColorAt(5,5,box)=$FF102030,'solid color');
  Check(f.IsVisible,'solid visible');
  Check(not TFill.Solid($00FFFFFF).IsVisible,'transparent solid is invisible');
  Check(not TFill.None.IsVisible,'none is invisible');
  Check(TFill.None.ColorAt(1,1,box)=0,'none color');
  EndTest;
end;

procedure TestAngles;
var
  f:TFill;
begin
  StartTest('CSS angles');
  // box 100x50
  f:=TFill.Linear(180,$FF000000,$FFFFFFFF); // to bottom
  Check(Near(f.ParamAt(50,0,box),0) and Near(f.ParamAt(50,50,box),1),'180: top to bottom');
  Check(Near(f.ParamAt(0,25,box),0.5) and Near(f.ParamAt(100,25,box),0.5),'180: middle row');
  f:=TFill.Linear(0,$FF000000,$FFFFFFFF); // to top
  Check(Near(f.ParamAt(50,50,box),0) and Near(f.ParamAt(50,0,box),1),'0: bottom to top');
  f:=TFill.Linear(90,$FF000000,$FFFFFFFF); // to right
  Check(Near(f.ParamAt(0,10,box),0) and Near(f.ParamAt(100,10,box),1),'90: left to right');
  // diagonal: the end colors land exactly in the corners at any aspect ratio
  f:=TFill.Linear(45,$FF000000,$FFFFFFFF);
  Check(Near(f.ParamAt(0,50,box),0) and Near(f.ParamAt(100,0,box),1),'45: corner to corner');
  Check(Near(f.ParamAt(0,0,box)+f.ParamAt(100,50,box),1),'45: the other corners are symmetric');
  Check(f.ColorAt(0,50,box)=$FF000000,'45: start color');
  Check(f.ColorAt(100,0,box)=$FFFFFFFF,'45: end color');
  // local units
  f:=TFill.Linear(TVec2.Init(0.5,0),TVec2.Init(1,0),$FF000000,$FFFFFFFF);
  Check(Near(f.ParamAt(50,7,box),0) and Near(f.ParamAt(75,7,box),0.5),'local units');
  Check(f.ColorAt(10,7,box)=$FF000000,'pad before the start');
  // absolute units
  f:=TFill.Linear(TVec2.Init(10,0),TVec2.Init(30,0),$FF000000,$FFFFFFFF,fuAbsolute);
  Check(Near(f.ParamAt(20,0,box),0.5),'absolute units');
  EndTest;
end;

procedure TestStops;
var
  f:TFill;
begin
  StartTest('Stops and spread');
  f:=TFill.Linear(90,$FF000000,$FFFFFFFF).AddStop(0.5,$FFFF0000);
  Check(f.stopCount=3,'stop count');
  Check(Near(f.stops[1].pos,0.5) and (f.stops[1].color=$FFFF0000),'stop inserted in the middle');
  Check(f.ColorAtParam(0.5)=$FFFF0000,'middle stop color');
  Check(SameColor(f.ColorAtParam(0.25),$FF800000),'between the first two stops');
  // a hard edge: two stops at one position
  f:=TFill.Linear(90,$FF000000,$FFFFFFFF).AddStop(0.5,$FFFF0000).AddStop(0.5,$FF00FF00);
  Check((f.stops[1].color=$FFFF0000) and (f.stops[2].color=$FF00FF00),'equal position goes after');
  Check(SameColor(f.ColorAtParam(0.49),Color.Mix($FF000000,$FFFF0000,0.98)),'before the edge');
  Check(SameColor(f.ColorAtParam(0.51),Color.Mix($FF00FF00,$FFFFFFFF,0.02)),'after the edge');
  // spread
  f:=TFill.Linear(90,$FF000000,$FFFFFFFF);
  Check(f.ColorAtParam(1.25)=$FFFFFFFF,'pad');
  Check(SameColor(f.WithSpread(fsRepeat).ColorAtParam(1.25),$FF404040),'repeat');
  Check(SameColor(f.WithSpread(fsReflect).ColorAtParam(1.25),$FFBFBFBF),'reflect');
  Check(SameColor(f.WithSpread(fsReflect).ColorAtParam(-0.25),$FF404040),'reflect, negative');
  Check(SameColor(f.WithSpread(fsRepeat).ColorAtParam(-0.25),$FFBFBFBF),'repeat, negative');
  EndTest;
end;

procedure TestPremultiplied;
var
  f:TFill;
  c:cardinal;
begin
  StartTest('Premultiplied interpolation');
  f:=TFill.Linear(90,$FFFF0000,$00000000);
  c:=f.ColorAtParam(0.5);
  Check(c and $FFFFFF=$FF0000,'fade to transparent keeps the hue: '+IntToHex(c,8));
  Check(abs(integer(c shr 24)-128)<=1,'half alpha');
  c:=f.ColorAtParam(1);
  Check(c shr 24=0,'transparent end');
  EndTest;
end;

procedure TestEdge;
var
  f:TFill;
begin
  StartTest('Edge');
  f:=TFill.Edge(4,$FF000000,$FFFFFFFF).AddStop(0.5,$FFFF0000);
  Check((f.kind=fkEdge) and (f.stopCount=3),'kind and stops');
  Check(Near(f.p0.x,4),'band width');
  Check(f.ColorAt(50,25,box)=$FFFFFFFF,'CPU color is the inner one');
  EndTest;
end;

procedure TestColorOps;
var
  f:TFill;
begin
  StartTest('Color operations');
  f:=TFill.Linear(180,$FF101010,$FF202020).Add($00101010);
  Check((f.stops[0].color=$FF202020) and (f.stops[1].color=$FF303030),'Add');
  f:=f.Sub($00101010);
  Check((f.stops[0].color=$FF101010) and (f.stops[1].color=$FF202020),'Sub');
  f:=TFill.Solid($FF000000).MixWith($FFFFFFFF,0.5);
  Check(SameColor(f.stops[0].color,$FF808080),'MixWith');
  f:=TFill.Linear(180,$FF102030,$80405060).Faded(0.5);
  Check((f.stops[0].color=$80102030) and (f.stops[1].color=$40405060),'Faded');
  Check(Near(TCornerRadii.Init(1,5,3,2).MaxRadius,5),'MaxRadius');
  EndTest;
end;

procedure TestMix;
var
  a,b,r:TFill;
begin
  StartTest('Mix');
  Check(TFill.Mix(TFill.Solid($FF000000),TFill.Solid($FFFFFFFF),0.5,r) and (r.kind=fkSolid) and
    SameColor(r.stops[0].color,$FF808080),'solid + solid');
  Check(TFill.Mix(TFill.None,TFill.Solid($FFFF0000),0.5,r) and (r.kind=fkSolid) and
    (r.stops[0].color and $FFFFFF=$FF0000) and (abs(integer(r.stops[0].color shr 24)-128)<=1),
    'none + solid: alpha fades, hue kept');
  Check(TFill.Mix(TFill.None,TFill.None,0.5,r) and (r.kind=fkNone),'none + none');
  // solid + linear: the solid takes the gradient structure
  b:=TFill.Linear(180,$FFFFFFFF,$FF000000);
  Check(TFill.Mix(TFill.Solid($FF000000),b,0.5,r) and (r.kind=fkLinear) and (r.stopCount=2),'solid + linear');
  Check(SameColor(r.stops[0].color,$FF808080) and (r.stops[1].color=$FF000000),'solid + linear colors');
  Check(Near(r.p0.x,180) and (r.units=fuAngle),'solid + linear keeps the line');
  // linear + linear: angles and stops interpolate
  a:=TFill.Linear(90,$FF000000,$FFFFFFFF);
  Check(TFill.Mix(a,b,0.5,r) and Near(r.p0.x,135),'angle interpolates');
  // not interpolable
  Check(not TFill.Mix(a,b.AddStop(0.5,$FFFF0000),0.5,r),'different stop counts');
  Check(not TFill.Mix(a,TFill.Edge(4,$FF000000,$FFFFFFFF),0.5,r),'linear + edge');
  Check(not TFill.Mix(a,a.WithSpread(fsRepeat),0.5,r),'different spread');
  // the ends return the operands as they are
  Check(TFill.Mix(a,TFill.Edge(4,0,0),0,r) and (r.kind=fkLinear),'t=0 gives a');
  Check(TFill.Mix(a,TFill.Edge(4,0,0),1,r) and (r.kind=fkEdge),'t=1 gives b');
  EndTest;
end;

begin
  box.Init(0,0,100,50);
  TestSolid;
  TestAngles;
  TestStops;
  TestPremultiplied;
  TestEdge;
  TestColorOps;
  TestMix;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then readln;
end.
