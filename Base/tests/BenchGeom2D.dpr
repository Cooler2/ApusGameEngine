{$APPTYPE CONSOLE}
program BenchGeom2D;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Geom2D;

{$I test.inc}

const
  N_FAST = 5000000;

var
  sink:double=0;

// All TVec2/TVec2d operations are declared `inline`.
// These benchmarks measure whether the compiler actually inlines them
// and how fast the resulting code is. Good SSE targets would show
// significant gap between x64 and x86 results.

procedure BenchVec2_Length;
var i:integer; v:TVec2; r:single;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Length',N_FAST);
  for i:=1 to N_FAST do
    r:=v.Length;
  sink:=sink+r;
  EndBench;
end;

procedure BenchVec2_Length2;
var i:integer; v:TVec2; r:single;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Length2',N_FAST);
  for i:=1 to N_FAST do
    r:=v.Length2;
  sink:=sink+r;
  EndBench;
end;

procedure BenchVec2_Normalize;
var i:integer; v,u:TVec2;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Normalize',N_FAST);
  for i:=1 to N_FAST do begin
    u:=v;
    u.Normalize;
  end;
  sink:=sink+u.x;
  EndBench;
end;

procedure BenchVec2_Dot;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,2.0);
  b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Dot',N_FAST);
  for i:=1 to N_FAST do
    r:=a.Dot(b);
  sink:=sink+r;
  EndBench;
end;

procedure BenchVec2_Sub;
var i:integer; a,b,r:TVec2;
begin
  a:=TVec2.Init(1.0,2.0);
  b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Sub',N_FAST);
  for i:=1 to N_FAST do
    r:=a.Sub(b);
  sink:=sink+r.x;
  EndBench;
end;

procedure BenchVec2_Distance2;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,2.0);
  b:=TVec2.Init(4.0,6.0);
  StartBench('TVec2.Distance2',N_FAST);
  for i:=1 to N_FAST do
    r:=a.Distance2(b);
  sink:=sink+r;
  EndBench;
end;

procedure BenchVec2d_Length;
var i:integer; v:TVec2d; r:double;
begin
  v:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Length',N_FAST);
  for i:=1 to N_FAST do
    r:=v.Length;
  sink:=sink+r;
  EndBench;
end;

procedure BenchVec2d_Normalize;
var i:integer; v,u:TVec2d;
begin
  v:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Normalize',N_FAST);
  for i:=1 to N_FAST do begin
    u:=v;
    u.Normalize;
  end;
  sink:=sink+u.x;
  EndBench;
end;

procedure BenchVec2d_Dot;
var i:integer; a,b:TVec2d; r:double;
begin
  a:=TVec2d.Init(1.0,2.0);
  b:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Dot',N_FAST);
  for i:=1 to N_FAST do
    r:=a.Dot(b);
  sink:=sink+r;
  EndBench;
end;

begin
  try
    OpenBenchLog('geom2d',0);

    BenchWriteln('--- TVec2 (single) ---');
    BenchVec2_Length;
    BenchVec2_Length2;
    BenchVec2_Normalize;
    BenchVec2_Dot;
    BenchVec2_Sub;
    BenchVec2_Distance2;
    BenchWriteln;

    BenchWriteln('--- TVec2d (double) ---');
    BenchVec2d_Length;
    BenchVec2d_Normalize;
    BenchVec2d_Dot;
    BenchWriteln;

    CloseBenchLog;
    if sink=0 then writeln('(sink non-zero)');
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
