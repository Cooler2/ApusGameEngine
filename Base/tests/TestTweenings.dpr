{$APPTYPE CONSOLE}
{$R+}
{$Q+}
program TestTweenings;
uses
  SysUtils,
  Apus.Core,
  Apus.Utils,
  Apus.Tweenings;

{$INCLUDE Test.inc}

type
  TVec2s=packed record
    x,y:single;
  end;

var
  testNowUs:int64=0;

procedure InitTweening(out tw:TTweening);
begin
  FillChar(tw,SizeOf(tw),0);
end;

procedure ResetTestTime;
begin
  {$IFDEF TIME_OVERRIDE}
  testNowUs:=1000000; // start from non-zero to keep 0 as "override disabled" sentinel
  CoreTime.Override(testNowUs);
  {$ENDIF}
end;

procedure AdvanceTestTime(ms:integer);
begin
  {$IFDEF TIME_OVERRIDE}
  inc(testNowUs,int64(ms)*1000);
  CoreTime.Override(testNowUs);
  {$ELSE}
  CoreTime.Sleep(ms);
  {$ENDIF}
end;

procedure ClearTestTime;
begin
  {$IFDEF TIME_OVERRIDE}
  CoreTime.Override(0);
  {$ENDIF}
end;

procedure CheckNear(actual,expected,eps:single; const msg:string);
begin
  Check(abs(actual-expected)<=eps,msg+
    ' (actual='+FloatToStr(actual)+', expected='+FloatToStr(expected)+')');
end;

procedure TestAssignAndBasicAccess;
var
  tw:TTweening;
  p,cur:TVec2s;
begin
  StartTest('Assign + basic access');
  InitTweening(tw);

  tw.Assign(5.5);
  CheckNear(tw.Value,5.5,0.0001,'Assign(single) stores value');
  Check(not tw.IsAnimating,'Assign(single) clears animation');
  CheckNear(tw.FinalValue,5.5,0.0001,'FinalValue after assign');

  p.x:=10;
  p.y:=20;
  tw.Assign(p,2);
  tw.GetValue(cur,CoreTime.Ticks);
  CheckNear(cur.x,10,0.0001,'Assign(vector) x');
  CheckNear(cur.y,20,0.0001,'Assign(vector) y');
  Check(not tw.IsAnimating,'Assign(vector) clears animation');

  tw.Free;
  EndTest;
end;

procedure TestLinearAnimation;
var
  tw:TTweening;
  v:single;
begin
  StartTest('Linear animation');
  InitTweening(tw);
  ResetTestTime;
  try
    tw.Assign(0);
    tw.Animate(100,120,splines.linear);
    AdvanceTestTime(20);
    v:=tw.Value;
    Check((v>0) and (v<100),'Value moves during animation');
    Check(tw.IsAnimating,'IsAnimating during active tween');

    AdvanceTestTime(130);
    CheckNear(tw.Value,100,0.5,'Value reaches final');
    CheckNear(tw.FinalValue,100,0.0001,'FinalValue equals target');
    Check(not tw.IsAnimating,'IsAnimating false after end');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

procedure TestVectorAnimation;
var
  tw:TTweening;
  p1,p2,p:TVec2s;
begin
  StartTest('Vector animation');
  InitTweening(tw);
  ResetTestTime;
  try
    p1.x:=0; p1.y:=100;
    p2.x:=200; p2.y:=50;
    tw.Assign(p1,2);
    tw.AnimateVec(p2,100,splines.linear);

    AdvanceTestTime(30);
    tw.GetValue(p,CoreTime.Ticks);
    Check((p.x>0) and (p.x<200),'Vector x interpolates');
    Check((p.y<100) and (p.y>50),'Vector y interpolates');

    AdvanceTestTime(90);
    tw.GetValue(p,CoreTime.Ticks);
    CheckNear(p.x,200,0.5,'Vector x final');
    CheckNear(p.y,50,0.5,'Vector y final');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

procedure TestInterruptionAndZeroDurationDelay;
var
  tw:TTweening;
  beforeDelay,afterDelay:single;
begin
  StartTest('Interruption + zero-duration delay');
  InitTweening(tw);
  ResetTestTime;
  try
    tw.Assign(0);
    tw.Animate(100,200,splines.easeOut);
    AdvanceTestTime(30);
    // edge: old animation is active, new animation has duration=0 and delay>0
    // this must not crash and should apply at delayed start time.
    tw.Animate(50,0,splines.linear,60);

    beforeDelay:=tw.Value;
    Check((beforeDelay>=0) and (beforeDelay<=100),
      'Value is valid immediately after re-target');
    Check(tw.IsAnimating,'Delayed zero-duration tween is considered animating');

    AdvanceTestTime(80);
    afterDelay:=tw.Value;
    CheckNear(afterDelay,50,0.5,'Delayed zero-duration tween applies target');
    Check(not tw.IsAnimating,'No active tween after delayed instant set');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

procedure TestScalarAnimateFromUninitialized;
var
  tw:TTweening;
begin
  StartTest('Scalar animate from uninitialized');
  InitTweening(tw);

  tw.Animate(7,0,splines.linear,0);
  CheckNear(tw.Value,7,0.0001,'Animate(single) initializes count=1 path');
  Check(not tw.IsAnimating,'Instant animate leaves no active tween');

  tw.Free;
  EndTest;
end;

procedure TestDelayedStartBehavior;
var
  tw:TTweening;
  v:single;
begin
  StartTest('Delay before start');
  InitTweening(tw);
  ResetTestTime;
  try
    tw.Assign(10);
    tw.Animate(30,100,splines.linear,50);

    v:=tw.Value;
    CheckNear(v,10,0.0001,'Value unchanged immediately after delayed animate');

    AdvanceTestTime(40);
    v:=tw.Value;
    CheckNear(v,10,0.0001,'Value unchanged before delayed start');
    Check(tw.IsAnimating,'IsAnimating true before delayed start');

    AdvanceTestTime(20); // now 60ms from schedule point -> animation should have started
    v:=tw.Value;
    Check((v>10) and (v<30),'Value changes after delayed start');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

procedure TestInstantPath;
var
  tw:TTweening;
  p1,p2,p:TVec2s;
begin
  StartTest('Instant path duration=0');
  InitTweening(tw);
  ResetTestTime;
  try
    tw.Assign(1);
    tw.Animate(9,0,splines.linear,0);
    CheckNear(tw.Value,9,0.0001,'Scalar instant animate sets value');
    Check(not tw.IsAnimating,'Scalar instant animate has no active effect');

    p1.x:=2; p1.y:=3;
    p2.x:=7; p2.y:=11;
    tw.Assign(p1,2);
    tw.AnimateVec(p2,0,splines.easeOut,0);
    tw.GetValue(p,CoreTime.Ticks);
    CheckNear(p.x,7,0.0001,'Vector instant animate sets x');
    CheckNear(p.y,11,0.0001,'Vector instant animate sets y');
    Check(not tw.IsAnimating,'Vector instant animate has no active effect');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

procedure TestBoundaryTimes;
var
  tw:TTweening;
  t0:int64;
  v:single;
begin
  StartTest('Boundary times');
  InitTweening(tw);
  ResetTestTime;
  try
    tw.Assign(0);
    t0:=CoreTime.Ticks;
    tw.Animate(100,100,splines.linear,20); // start=t0+20, end=t0+120

    tw.GetValue(v,t0+20);
    CheckNear(v,0,0.0001,'Value at startTime equals startValue');

    tw.GetValue(v,t0+120);
    CheckNear(v,100,0.0001,'Value at endTime equals endValue');

    tw.GetValue(v,t0+121);
    CheckNear(v,100,0.0001,'Value after endTime remains endValue');
  finally
    tw.Free;
    ClearTestTime;
  end;
  EndTest;
end;

begin
  try
    TestAssignAndBasicAccess;
    TestLinearAnimation;
    TestVectorAnimation;
    TestInterruptionAndZeroDurationDelay;
    TestScalarAnimateFromUninitialized;
    TestDelayedStartBehavior;
    TestInstantPath;
    TestBoundaryTimes;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
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
