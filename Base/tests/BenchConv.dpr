{$APPTYPE CONSOLE}
program BenchConv;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv,
  Apus.CrossPlatform;

const
  ITERATIONS = 10000000;

var
  i:integer;
  t1,t2:int64;
  s:string;
  s8:string8;

procedure QueryPerformanceCounter(out v:int64); {$IFDEF MSWINDOWS}stdcall; external 'kernel32';{$ENDIF}
procedure QueryPerformanceFrequency(out v:int64); {$IFDEF MSWINDOWS}stdcall; external 'kernel32';{$ENDIF}

var
  freq:int64;

function TimeMs:double;
var
  t:int64;
begin
  QueryPerformanceCounter(t);
  result:=t*1000/freq;
end;

begin
  QueryPerformanceFrequency(freq);
  writeln('Benchmark: Conv.ToStr vs SysUtils.IntToStr');
  writeln('Iterations: ',ITERATIONS);
  writeln;

  // warm up
  for i:=1 to 1000 do begin
    s:=SysUtils.IntToStr(i);
    s8:=Conv.ToStr(i);
  end;

  // SysUtils.IntToStr
  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s:=SysUtils.IntToStr(i);
  t2:=round(TimeMs);
  writeln('SysUtils.IntToStr: ',t2-t1,' ms');

  // Conv.ToStr(integer)
  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s8:=Conv.ToStr(i);
  t2:=round(TimeMs);
  writeln('Conv.ToStr:        ',t2-t1,' ms');

  // negative values
  writeln;
  writeln('Negative values:');

  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s:=SysUtils.IntToStr(-i);
  t2:=round(TimeMs);
  writeln('SysUtils.IntToStr: ',t2-t1,' ms');

  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s8:=Conv.ToStr(-i);
  t2:=round(TimeMs);
  writeln('Conv.ToStr:        ',t2-t1,' ms');

  // large values
  writeln;
  writeln('Large values (i*100000):');

  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s:=SysUtils.IntToStr(i*100000);
  t2:=round(TimeMs);
  writeln('SysUtils.IntToStr: ',t2-t1,' ms');

  t1:=round(TimeMs);
  for i:=1 to ITERATIONS do
    s8:=Conv.ToStr(i*100000);
  t2:=round(TimeMs);
  writeln('Conv.ToStr:        ',t2-t1,' ms');

  writeln;
  if IsDebuggerPresent then readln;
end.
