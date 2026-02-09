{$IFDEF FPC} {$MODE DELPHI}
  {$ELSE} {$DEFINE DELPHI} {$ENDIF}
{$IFDEF CPUX64} {$DEFINE CPU64} {$ENDIF}
var
  testsFailed:integer=0;
  testsTotal:integer=0;
  groupFailed:integer;
  groupName:string;

procedure StartTest(const name:string);
begin
  groupName:=name;
  groupFailed:=testsFailed;
  write('Testing ',name,'... ');
end;

procedure EndTest;
begin
  if testsFailed=groupFailed then
    writeln('OK')
  else
    writeln('FAIL');
end;

procedure Check(condition:boolean; const msg:string);
begin
  inc(testsTotal);
  if not condition then begin
    if testsFailed=groupFailed then writeln;
    writeln('  FAIL: ',msg);
    inc(testsFailed);
  end;
end;

// ============================================================================
// Benchmark support
// ============================================================================
var
  benchLog:Text;
  benchLogOpen:boolean=false;
  benchTimer:int64;
  benchIterations:integer=0;

procedure BenchWriteln(const s:string='');
begin
  writeln(s);
  if benchLogOpen then writeln(benchLog,s);
end;

procedure OpenBenchLog(const name:string; iterations:integer);
var
  fn:string;
begin
  benchIterations:=iterations;
  fn:='bench_'+name+'_'
    +{$IFDEF DELPHI}'D'{$ELSE}'F'{$ENDIF}
    +{$IFDEF CPU64}'64'{$ELSE}'32'{$ENDIF}
    +'.txt';
  Assign(benchLog,fn);
  Rewrite(benchLog);
  benchLogOpen:=true;
  BenchWriteln(fn);
end;

procedure CloseBenchLog;
begin
  if benchLogOpen then begin
    Close(benchLog);
    benchLogOpen:=false;
  end;
end;

procedure StartBench(const name:string; iterations:integer=0);
var
  s:string;
begin
  if iterations>0 then benchIterations:=iterations;
  s:=Format('%-30s ... ',[name]);
  write(s);
  if benchLogOpen then write(benchLog,s);
  StartTimer(benchTimer);
end;

procedure EndBench;
var
  nsPerOp:double;
  s:string;
begin
  nsPerOp:=TimerSec(benchTimer)*1e9/benchIterations;
  if nsPerOp>=1000 then
    s:=Format('%8.2f us/op',[nsPerOp/1000])
  else
    s:=Format('%8.2f ns/op',[nsPerOp]);
  writeln(s);
  if benchLogOpen then writeln(benchLog,s);
end;

// ============================================================================
// Debug helpers
// ============================================================================
{$IFDEF UNIX}
const
  PTRACE_TRACEME = 0;
  PTRACE_DETACH = 17;
function ptrace(__request:integer; PID: pid_t; Address: Pointer; Data: Longint): longint; cdecl; external libc name 'ptrace';
{$ENDIF}
{$IFDEF MSWINDOWS}
function WinAPI_IsDebuggerPresent:LongBool; external 'kernel32.dll' name 'IsDebuggerPresent';
{$ENDIF}

function IsDebuggerPresent:boolean;
begin
   {$IFDEF MSWINDOWS}
   result:=WinAPI_IsDebuggerPresent;
   {$ENDIF}
   {$IFDEF UNIX}
   if (ptrace(PTRACE_TRACEME, 0, nil, 0) < 0) then
    result:=true
   else begin
    ptrace(PTRACE_DETACH, 0, nil, 0);
    result:=false;
   end;
   {$ENDIF}
end;
