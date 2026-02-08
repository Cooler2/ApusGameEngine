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