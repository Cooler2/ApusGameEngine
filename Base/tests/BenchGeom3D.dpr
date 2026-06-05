{$APPTYPE CONSOLE}
program BenchGeom3D;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Geom3D;

{$I Test.inc}

const
  N_FAST  = 5000000;
  N_BATCH = 10000;
  BATCH_SIZE = 1024;

var
  sink:double=0;

// ============================================================================
// TVec3 (single)
// ============================================================================

procedure BenchVec3_Length;
var i:integer; v:TVec3; r:single;
begin
  v:=TVec3.Init(1.0,2.0,3.0);
  StartBench('TVec3.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec3_Length2;
var i:integer; v:TVec3; r:single;
begin
  v:=TVec3.Init(1.0,2.0,3.0);
  StartBench('TVec3.Length2',N_FAST);
  for i:=1 to N_FAST do r:=v.Length2;
  sink:=sink+r; EndBench;
end;

procedure BenchVec3_Normalize;
var i:integer; v,u:TVec3;
begin
  v:=TVec3.Init(1.0,2.0,3.0);
  StartBench('TVec3.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3_NormalizeFast;
var i:integer; v,u:TVec3;
begin
  v:=TVec3.Init(1.0,2.0,3.0);
  StartBench('TVec3.NormalizeFast',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.NormalizeFast; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3_Dot;
var i:integer; a,b:TVec3; r:single;
begin
  a:=TVec3.Init(1.0,2.0,3.0); b:=TVec3.Init(4.0,5.0,6.0);
  StartBench('TVec3.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec3_Cross;
var i:integer; a,b,r:TVec3;
begin
  a:=TVec3.Init(1.0,2.0,3.0); b:=TVec3.Init(4.0,5.0,6.0);
  StartBench('TVec3.Cross',N_FAST);
  for i:=1 to N_FAST do r:=a.Cross(b);
  sink:=sink+r.x; EndBench;
end;

procedure BenchVec3_Add;
var i:integer; a,b,u:TVec3;
begin
  a:=TVec3.Init(1.0,2.0,3.0); b:=TVec3.Init(4.0,5.0,6.0);
  StartBench('TVec3.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3_Sub;
var i:integer; a,b,r:TVec3;
begin
  a:=TVec3.Init(1.0,2.0,3.0); b:=TVec3.Init(4.0,5.0,6.0);
  StartBench('TVec3.Sub',N_FAST);
  for i:=1 to N_FAST do r:=a.Sub(b);
  sink:=sink+r.x; EndBench;
end;

procedure BenchVec3_Multiply;
var i:integer; v,u:TVec3;
begin
  v:=TVec3.Init(1.0,2.0,3.0);
  StartBench('TVec3.Multiply',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Multiply(2.0); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3_Distance2;
var i:integer; a,b:TVec3; r:single;
begin
  a:=TVec3.Init(1.0,2.0,3.0); b:=TVec3.Init(4.0,5.0,6.0);
  StartBench('TVec3.Distance2',N_FAST);
  for i:=1 to N_FAST do r:=a.Distance2(b);
  sink:=sink+r; EndBench;
end;

// ============================================================================
// TVec3d (double)
// ============================================================================

procedure BenchVec3d_Length;
var i:integer; v:TVec3d; r:double;
begin
  v:=TVec3d.Init(1.0,2.0,3.0);
  StartBench('TVec3d.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec3d_Normalize;
var i:integer; v,u:TVec3d;
begin
  v:=TVec3d.Init(1.0,2.0,3.0);
  StartBench('TVec3d.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3d_Dot;
var i:integer; a,b:TVec3d; r:double;
begin
  a:=TVec3d.Init(1.0,2.0,3.0); b:=TVec3d.Init(4.0,5.0,6.0);
  StartBench('TVec3d.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec3d_Cross;
var i:integer; a,b,r:TVec3d;
begin
  a:=TVec3d.Init(1.0,2.0,3.0); b:=TVec3d.Init(4.0,5.0,6.0);
  StartBench('TVec3d.Cross',N_FAST);
  for i:=1 to N_FAST do r:=a.Cross(b);
  sink:=sink+r.x; EndBench;
end;

procedure BenchVec3d_Add;
var i:integer; a,b,u:TVec3d;
begin
  a:=TVec3d.Init(1.0,2.0,3.0); b:=TVec3d.Init(4.0,5.0,6.0);
  StartBench('TVec3d.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec3d_Sub;
var i:integer; a,b,r:TVec3d;
begin
  a:=TVec3d.Init(1.0,2.0,3.0); b:=TVec3d.Init(4.0,5.0,6.0);
  StartBench('TVec3d.Sub',N_FAST);
  for i:=1 to N_FAST do r:=a.Sub(b);
  sink:=sink+r.x; EndBench;
end;

// ============================================================================
// TVec4 (single)
// ============================================================================

procedure BenchVec4_Dot;
var i:integer; a,b:TVec4; r:single;
begin
  a:=TVec4.Init(1.0,2.0,3.0,1.0); b:=TVec4.Init(4.0,5.0,6.0,1.0);
  StartBench('TVec4.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec4_Length;
var i:integer; v:TVec4; r:single;
begin
  v:=TVec4.Init(1.0,2.0,3.0,1.0);
  StartBench('TVec4.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec4_Normalize;
var i:integer; v,u:TVec4;
begin
  v:=TVec4.Init(1.0,2.0,3.0,1.0);
  StartBench('TVec4.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec4_Add;
var i:integer; a,b,u:TVec4;
begin
  a:=TVec4.Init(1.0,2.0,3.0,1.0); b:=TVec4.Init(4.0,5.0,6.0,1.0);
  StartBench('TVec4.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchVec4_Mul;
var i:integer; v,u:TVec4;
begin
  v:=TVec4.Init(1.0,2.0,3.0,1.0);
  StartBench('TVec4.Mul(scalar)',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Mul(2.0); end;
  sink:=sink+u.x; EndBench;
end;

// ============================================================================
// TVec4d (double)
// ============================================================================

procedure BenchVec4d_Dot;
var i:integer; a,b:TVec4d; r:double;
begin
  a:=TVec4d.Init(1.0,2.0,3.0,1.0); b:=TVec4d.Init(4.0,5.0,6.0,1.0);
  StartBench('TVec4d.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchVec4d_Length;
var i:integer; v:TVec4d; r:double;
begin
  v:=TVec4d.Init(1.0,2.0,3.0,1.0);
  StartBench('TVec4d.Length',N_FAST);
  for i:=1 to N_FAST do r:=v.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchVec4d_Normalize;
var i:integer; v,u:TVec4d;
begin
  v:=TVec4d.Init(1.0,2.0,3.0,1.0);
  StartBench('TVec4d.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=v; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

// ============================================================================
// TQuat (single, SSE)
// ============================================================================

procedure BenchQuat_Length;
var i:integer; q:TQuat; r:single;
begin
  q:=TQuat.Init(0.1,0.2,0.3,0.9);
  StartBench('TQuat.Length',N_FAST);
  for i:=1 to N_FAST do r:=q.Length;
  sink:=sink+r; EndBench;
end;

procedure BenchQuat_Normalize;
var i:integer; q,u:TQuat;
begin
  q:=TQuat.Init(0.1,0.2,0.3,0.9);
  StartBench('TQuat.Normalize',N_FAST);
  for i:=1 to N_FAST do begin u:=q; u.Normalize; end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_Dot;
var i:integer; a,b:TQuat; r:single;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Dot',N_FAST);
  for i:=1 to N_FAST do r:=a.Dot(b);
  sink:=sink+r; EndBench;
end;

procedure BenchQuat_Mul;
var i:integer; a,b,u:TQuat;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Mul(TQuat)',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Mul(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_MulScalar;
var i:integer; q,u:TQuat;
begin
  q:=TQuat.Init(0.1,0.2,0.3,0.9);
  StartBench('TQuat.Mul(scalar)',N_FAST);
  for i:=1 to N_FAST do begin u:=q; u.Mul(1.0001); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_Add;
var i:integer; a,b,u:TQuat;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Add',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_AddScale;
var i:integer; a,b,u:TQuat;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Add(scale)',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Add(b,0.5); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_Sub;
var i:integer; a,b,u:TQuat;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Sub',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Sub(b); end;
  sink:=sink+u.x; EndBench;
end;

procedure BenchQuat_Middle;
var i:integer; a,b,u:TQuat;
begin
  a:=TQuat.Init(0.1,0.2,0.3,0.9); b:=TQuat.Init(0.4,0.5,0.6,0.7);
  StartBench('TQuat.Middle',N_FAST);
  for i:=1 to N_FAST do begin u:=a; u.Middle(b,0.5); end;
  sink:=sink+u.x; EndBench;
end;

// ============================================================================
// Batch transforms
// ============================================================================

procedure BenchMat34_TransformPoints;
var i,j:integer; m:TMat34; pts:array[0..BATCH_SIZE-1] of TVec3;
begin
  m:=identMat34; m[3,0]:=1.0; m[3,1]:=2.0; m[3,2]:=3.0;
  for i:=0 to BATCH_SIZE-1 do pts[i]:=TVec3.Init(i*0.1,i*0.2,i*0.3);
  StartBench('TMat34.TransformPoints x'+IntToStr(BATCH_SIZE),N_BATCH);
  for j:=1 to N_BATCH do m.TransformPoints(@pts[0],BATCH_SIZE,SizeOf(TVec3));
  sink:=sink+pts[0].x; EndBench;
end;

procedure BenchMat3_TransformPoints;
var i,j:integer; m:TMat3; pts:array[0..BATCH_SIZE-1] of TVec3;
begin
  m:=identMat3;
  for i:=0 to BATCH_SIZE-1 do pts[i]:=TVec3.Init(i*0.1,i*0.2,i*0.3);
  StartBench('TMat3.TransformPoints x'+IntToStr(BATCH_SIZE),N_BATCH);
  for j:=1 to N_BATCH do m.TransformPoints(@pts[0],BATCH_SIZE,SizeOf(TVec3));
  sink:=sink+pts[0].x; EndBench;
end;

procedure BenchMat4_TransformPoints;
var i,j:integer; m:TMat4; pts:array[0..BATCH_SIZE-1] of TVec4;
begin
  m:=identMat4;
  for i:=0 to BATCH_SIZE-1 do pts[i]:=TVec4.Init(i*0.1,i*0.2,i*0.3,1.0);
  StartBench('TMat4.TransformPoints x'+IntToStr(BATCH_SIZE)+' (SSE)',N_BATCH);
  for j:=1 to N_BATCH do m.TransformPoints(@pts[0],BATCH_SIZE,SizeOf(TVec4));
  sink:=sink+pts[0].x; EndBench;
end;

procedure BenchMat4_Multiply;
var i:integer; a,b,r:TMat4;
begin
  a:=identMat4; b:=identMat4; a[0,1]:=1.0; b[1,2]:=2.0;
  StartBench('TMat4 * TMat4 (SSE)',N_FAST);
  for i:=1 to N_FAST do r:=a*b;
  sink:=sink+r[0,0]; EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('geom3d',N_BATCH);

    BenchWriteln('--- TVec3 (single) ---');
    BenchVec3_Length;
    BenchVec3_Length2;
    BenchVec3_Normalize;
    BenchVec3_NormalizeFast;
    BenchVec3_Dot;
    BenchVec3_Cross;
    BenchVec3_Add;
    BenchVec3_Sub;
    BenchVec3_Multiply;
    BenchVec3_Distance2;
    BenchWriteln;

    BenchWriteln('--- TVec3d (double) ---');
    BenchVec3d_Length;
    BenchVec3d_Normalize;
    BenchVec3d_Dot;
    BenchVec3d_Cross;
    BenchVec3d_Add;
    BenchVec3d_Sub;
    BenchWriteln;

    BenchWriteln('--- TVec4 (single) ---');
    BenchVec4_Dot;
    BenchVec4_Length;
    BenchVec4_Normalize;
    BenchVec4_Add;
    BenchVec4_Mul;
    BenchWriteln;

    BenchWriteln('--- TVec4d (double) ---');
    BenchVec4d_Dot;
    BenchVec4d_Length;
    BenchVec4d_Normalize;
    BenchWriteln;

    BenchWriteln('--- TQuat (single, SSE) ---');
    BenchQuat_Length;
    BenchQuat_Normalize;
    BenchQuat_Dot;
    BenchQuat_Mul;
    BenchQuat_MulScalar;
    BenchQuat_Add;
    BenchQuat_AddScale;
    BenchQuat_Sub;
    BenchQuat_Middle;
    BenchWriteln;

    BenchWriteln('--- Batch transforms ---');
    BenchMat34_TransformPoints;
    BenchMat3_TransformPoints;
    BenchMat4_TransformPoints;
    BenchMat4_Multiply;
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
