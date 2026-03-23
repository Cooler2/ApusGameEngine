{$APPTYPE CONSOLE}
program BenchAnimation;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Utils,
  Apus.Tweenings,
  Apus.AnimatedValues;

{$I test.inc}

type
  TVec2s=packed record
    x,y:single;
  end;

const
  N_READ    = 2000000;
  N_RETARGET= 100000;
  N_VECREAD = 1500000;

var
  sink:double=0;

procedure InitTweening(out tw:TTweening);
begin
  FillChar(tw,SizeOf(tw),0);
end;

procedure BenchReadLinear_Tweening;
var
  tw:TTweening;
  i:integer;
  t:int64;
  v:single;
  sum:double;
  base:int64;
begin
  InitTweening(tw);
  tw.Assign(0);
  tw.Animate(1000,1000000,splines.linear);
  base:=CoreTime.Ticks;
  sum:=0;
  StartBench('Tweening read linear',N_READ);
  for i:=1 to N_READ do begin
    t:=base+(i mod 100000);
    tw.GetValue(v,t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  tw.Free;
end;

procedure BenchReadLinear_AnimatedValue;
var
  av:TAnimatedValue;
  i:integer;
  t:int64;
  v:single;
  sum:double;
  base:int64;
begin
  av.Init(0);
  av.Animate(1000,1000000,splines.linear);
  base:=CoreTime.Ticks;
  sum:=0;
  StartBench('AnimatedValue read linear',N_READ);
  for i:=1 to N_READ do begin
    t:=base+(i mod 100000);
    v:=av.ValueAt(t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  av.Free;
end;

procedure BenchReadEaseOut_Tweening;
var
  tw:TTweening;
  i:integer;
  t:int64;
  v:single;
  sum:double;
  base:int64;
begin
  InitTweening(tw);
  tw.Assign(0);
  tw.Animate(1000,1000000,splines.easeOut);
  base:=CoreTime.Ticks;
  sum:=0;
  StartBench('Tweening read easeOut',N_READ);
  for i:=1 to N_READ do begin
    t:=base+(i mod 100000);
    tw.GetValue(v,t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  tw.Free;
end;

procedure BenchReadEaseOut_AnimatedValue;
var
  av:TAnimatedValue;
  i:integer;
  t:int64;
  v:single;
  sum:double;
  base:int64;
begin
  av.Init(0);
  av.Animate(1000,1000000,splines.easeOut);
  base:=CoreTime.Ticks;
  sum:=0;
  StartBench('AnimatedValue read easeOut',N_READ);
  for i:=1 to N_READ do begin
    t:=base+(i mod 100000);
    v:=av.ValueAt(t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  av.Free;
end;

procedure BenchRetarget_Tweening;
var
  tw:TTweening;
  i:integer;
  target,v:single;
  sum:double;
  t:int64;
begin
  InitTweening(tw);
  tw.Assign(0);
  sum:=0;
  StartBench('Tweening retarget + sample (<=3 overlap)',N_RETARGET);
  for i:=1 to N_RETARGET do begin
    if (i mod 3)=0 then
      tw.Assign(tw.Value); // keep overlap in realistic range (~2-3)
    target:=single(i and 1023);
    tw.Animate(target,250,splines.easeOut);
    t:=CoreTime.Ticks+16;
    tw.GetValue(v,t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  tw.Free;
end;

procedure BenchRetarget_AnimatedValue;
var
  av:TAnimatedValue;
  i:integer;
  target,v:single;
  sum:double;
  t:int64;
begin
  av.Init(0);
  sum:=0;
  StartBench('AnimatedValue retarget + sample (<=3 overlap)',N_RETARGET);
  for i:=1 to N_RETARGET do begin
    if (i mod 3)=0 then
      av.Assign(av.Value); // keep overlap in realistic range (~2-3)
    target:=single(i and 1023);
    av.Animate(target,250,splines.easeOut);
    t:=CoreTime.Ticks+16;
    v:=av.ValueAt(t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  av.Free;
end;

procedure BenchRetargetDelay_Tweening;
var
  tw:TTweening;
  i:integer;
  target,v:single;
  sum:double;
  t:int64;
begin
  InitTweening(tw);
  tw.Assign(0);
  sum:=0;
  StartBench('Tweening retarget(delay)+sample (<=3 overlap)',N_RETARGET);
  for i:=1 to N_RETARGET do begin
    if (i mod 3)=0 then
      tw.Assign(tw.Value); // keep overlap in realistic range (~2-3)
    target:=single(i and 1023);
    tw.Animate(target,250,splines.easeOut,20);
    t:=CoreTime.Ticks+10;
    tw.GetValue(v,t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  tw.Free;
end;

procedure BenchRetargetDelay_AnimatedValue;
var
  av:TAnimatedValue;
  i:integer;
  target,v:single;
  sum:double;
  t:int64;
begin
  av.Init(0);
  sum:=0;
  StartBench('AnimatedValue retarget(delay)+sample (<=3 overlap)',N_RETARGET);
  for i:=1 to N_RETARGET do begin
    if (i mod 3)=0 then
      av.Assign(av.Value); // keep overlap in realistic range (~2-3)
    target:=single(i and 1023);
    av.Animate(target,250,splines.easeOut,20);
    t:=CoreTime.Ticks+10;
    v:=av.ValueAt(t);
    sum:=sum+v;
  end;
  EndBench;
  sink:=sink+sum;
  av.Free;
end;

procedure BenchVectorRead_Tweening;
var
  tw:TTweening;
  i:integer;
  p1,p2,p:TVec2s;
  t:int64;
  sum:double;
  base:int64;
begin
  InitTweening(tw);
  p1.x:=0; p1.y:=100;
  p2.x:=500; p2.y:=250;
  tw.Assign(p1,2);
  tw.Animate(p2,1000000,splines.easeInOut);
  base:=CoreTime.Ticks;
  sum:=0;
  StartBench('Tweening vec2 read (no AV pair)',N_VECREAD);
  for i:=1 to N_VECREAD do begin
    t:=base+(i mod 100000);
    tw.GetValue(p,t);
    sum:=sum+p.x+p.y;
  end;
  EndBench;
  sink:=sink+sum;
  tw.Free;
end;

begin
  try
    OpenBenchLog('animation',N_READ);
    BenchWriteln;

    BenchWriteln('--- Read Path (active animation) ---');
    BenchReadLinear_Tweening;
    BenchReadLinear_AnimatedValue;
    BenchReadEaseOut_Tweening;
    BenchReadEaseOut_AnimatedValue;
    BenchWriteln;

    BenchWriteln('--- Retarget Path ---');
    BenchRetarget_Tweening;
    BenchRetarget_AnimatedValue;
    BenchRetargetDelay_Tweening;
    BenchRetargetDelay_AnimatedValue;
    BenchWriteln;

    BenchWriteln('--- Tweening-only (multi-component) ---');
    BenchVectorRead_Tweening;
    BenchWriteln;

    BenchWriteln('Sink='+FloatToStr(sink));
    CloseBenchLog;
    writeln('=== BENCHMARK DONE ===');
  except
    on e:Exception do begin
      writeln;
      writeln('BENCHMARK FAILED: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press ENTER to exit');
    readln;
  end;
end.
