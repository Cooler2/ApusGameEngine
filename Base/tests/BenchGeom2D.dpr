{$APPTYPE CONSOLE}
program BenchGeom2D;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Geom2D;

{$I Test.inc}

const
  N_FAST  = 5000000;
  N_BATCH = 10000;
  BATCH_SIZE = 1024;

var
  sink:double=0;

// ============================================================================
// TVec2 (single) — all declared inline; benchmarks measure actual inlining
// ============================================================================

procedure BenchVec2_Length;
var i:integer; v:TVec2; r:single;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_Length2;
var i:integer; v:TVec2; r:single;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Length2',N_FAST);
  for i:=1 to N_FAST do r:=v.Length2;
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_Normalize;
var i:integer; v,u:TVec2;
begin
  v:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec2_Dot;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,2.0); b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_Cross;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,2.0); b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Cross',N_FAST);
  for i:=1 to N_FAST do r:=a.Cross(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_Sub;
var i:integer; a,b,r:TVec2;
begin
  a:=TVec2.Init(1.0,2.0); b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Sub',N_FAST);
  for i:=1 to N_FAST do r:=a.Sub(b);
  sink:=sink+r.x; EndBench;
end;

procedure BenchVec2_Add;
var i:integer; a,b,u:TVec2;
begin
  a:=TVec2.Init(1.0,2.0); b:=TVec2.Init(3.0,4.0);
  StartBench('TVec2.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec2_Multiply;
var i:integer; v,u:TVec2;
begin
  v:=TVec2.Init(1.0,2.0);
  StartBench('TVec2.Multiply',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Multiply(2.0); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec2_Distance2;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,2.0); b:=TVec2.Init(4.0,6.0);
  StartBench('TVec2.Distance2',N_FAST);
  for i:=1 to N_FAST do r:=a.Distance2(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_Turn90R;
var i:integer; v,u:TVec2;
begin
  v:=TVec2.Init(1.0,2.0);
  StartBench('TVec2.Turn90R',N_FAST);
  for i:=1 to N_FAST do u:=v.Turn90R;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec2_Direction;
var i:integer; v:TVec2; r:single;
begin
  v:=TVec2.Init(1.0,2.0);
  StartBench('TVec2.Direction',N_FAST);
  for i:=1 to N_FAST do r:=v.Direction;
  sink:=sink+r; EndBench;
end;

procedure BenchVec2_AngleTo;
var i:integer; a,b:TVec2; r:single;
begin
  a:=TVec2.Init(1.0,0.0); b:=TVec2.Init(0.0,1.0);
  StartBench('TVec2.AngleTo',N_FAST);
  for i:=1 to N_FAST do r:=a.AngleTo(b);
  sink:=sink+r; EndBench;
end;

// ============================================================================
// TVec2d (double) — all declared inline
// ============================================================================

procedure BenchVec2d_Length;
var i:integer; v:TVec2d; r:double;
begin
  v:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec2d_Length2;
var i:integer; v:TVec2d; r:double;
begin
  v:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Length2',N_FAST);
  for i:=1 to N_FAST do r:=v.Length2;
  sink:=sink+r; EndBench;
end;

procedure BenchVec2d_Normalize;
var i:integer; v,u:TVec2d;
begin
  v:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec2d_Dot;
var i:integer; a,b:TVec2d; r:double;
begin
  a:=TVec2d.Init(1.0,2.0); b:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec2d_Sub;
var i:integer; a,b,r:TVec2d;
begin
  a:=TVec2d.Init(1.0,2.0); b:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Sub',N_FAST);
  for i:=1 to N_FAST do r:=a.Sub(b);
  sink:=sink+r.x; EndBench;
end;

procedure BenchVec2d_Distance2;
var i:integer; a,b:TVec2d; r:double;
begin
  a:=TVec2d.Init(1.0,2.0); b:=TVec2d.Init(4.0,6.0);
  StartBench('TVec2d.Distance2',N_FAST);
  for i:=1 to N_FAST do r:=a.Distance2(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec2d_Add;
var i:integer; a,b,u:TVec2d;
begin
  a:=TVec2d.Init(1.0,2.0); b:=TVec2d.Init(3.0,4.0);
  StartBench('TVec2d.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

// ============================================================================
// MultPnts batch transform (TMat32)
// ============================================================================

procedure BenchMultPnts;
var i,j:integer; m:TMat32; pts:array[0..BATCH_SIZE-1] of TVec2;
begin
  m:=IdentMat32;
  for i:=0 to BATCH_SIZE-1 do pts[i]:=TVec2.Init(i*0.1,i*0.2);
  StartBench('MultPnts x'+IntToStr(BATCH_SIZE),N_BATCH);
  for j:=1 to N_BATCH do MultPnts(m,@pts[0],BATCH_SIZE,SizeOf(TVec2));
  sink:=sink+pts[0].x; EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('geom2d',0);

    BenchWriteln('--- TVec2 (single) ---');
    BenchVec2_Length;
    BenchVec2_Length2;
    BenchVec2_Normalize;
    BenchVec2_Dot;
    BenchVec2_Cross;
    BenchVec2_Sub;
    BenchVec2_Add;
    BenchVec2_Multiply;
    BenchVec2_Distance2;
    BenchVec2_Turn90R;
    BenchVec2_Direction;
    BenchVec2_AngleTo;
    BenchWriteln;

    BenchWriteln('--- TVec2d (double) ---');
    BenchVec2d_Length;
    BenchVec2d_Length2;
    BenchVec2d_Normalize;
    BenchVec2d_Dot;
    BenchVec2d_Sub;
    BenchVec2d_Distance2;
    BenchVec2d_Add;
    BenchWriteln;

    BenchWriteln('--- Batch transforms ---');
    BenchMultPnts;
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
