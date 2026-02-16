// Thread synchronization and management - locks, events, and thread utilities for concurrent code
//
// SCOPE: Building blocks for multithreaded applications - critical sections, reader-writer locks,
// events, thread registry with deadlock detection. Used by applications and libraries that need
// thread-safe operations or manage worker threads.
//
// ADD HERE: Synchronization primitives (locks, semaphores, barriers), thread management,
// deadlock detection, thread-local storage.
// DON'T ADD: High-level concurrency (thread pools, async/await), parallel algorithms,
// application-specific threading logic.
//
// Contains: TLock (critical section with debug), TSRWLock (reader-writer, Windows), TLightweightEvent,
// Thread scope (Register/Unregister/Ping/GetName), WaitFor utility, deadlock detection via level checking.
//
// Copyright (C) 2004-2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Threads;
interface
uses Apus.Core{$IFDEF MSWINDOWS}, Windows{$ENDIF};

type
  PLock=^TLock;

  // Enhanced critical section with debug support and deadlock detection
  // Use lock.Init/Cleanup to initialize/finalize
  // Use lock.Enter/Leave for locking
  TLock=packed record
  private
    crs:TRTLCriticalSection;
    caller:UIntPtr;     // address where lock was attempted
    owner:UIntPtr;      // address where lock was acquired
    {$IFNDEF MSWINDOWS}
    owningThread:TThreadID;
    {$ENDIF}
    tryingThread:TThreadID;  // thread trying to acquire the lock
    time:int64;         // timeout timestamp
    lockCount:integer;  // recursion counter
    level:integer;      // level for deadlock prevention (higher = lower-level code)
    prevSection:PLock;
    function GetSysLockCount:integer; inline;
    function GetSysOwner:TThreadID; inline;
    function GetOwningThread:TThreadID; inline;
  public
    name:String8;       // section name
    procedure Init(const aName:String8; aLevel:integer=100);
    procedure Cleanup;
    procedure Enter;
    procedure Leave;
    function IsLocked:boolean; inline;
    function GetOwner:TThreadID; inline;
  end;

  // Type aliases for backward compatibility
  TMyCriticalSection=TLock;
  PCriticalSection=PLock;
  TCriticalSection=TLock;
  PCS=PLock;

  {$IF Declared(SRWLOCK)}
  // Slim Reader/Writer lock (Windows Vista+)
  TSRWLock=packed record
  private
    lock:SRWLock;
    lockedEx:boolean;
    lastLockedEx:pointer;
    lockRead:integer;
    lastLockedRead:pointer;
  public
    name:String8;
    procedure Init(const aName:String8);
    procedure Cleanup;
    procedure EnterRead(caller:pointer=nil);
    procedure LeaveRead;
    procedure EnterWrite(caller:pointer=nil);
    procedure LeaveWrite;
  end;
  {$ENDIF}

  // Lightweight event using WaitOnAddress (Win10+) or futex (Linux)
  TLightweightEvent=record
  private
    state:integer; // 0=reset, 1=set
  public
    procedure Init;
    procedure SetEvent;
    procedure ResetEvent;
    function WaitFor(timeoutMs:cardinal=$FFFFFFFF):boolean;
  end;

  // Thread function type
  TThreadProc=function(parameter:pointer):UIntPtr;

  // Forward declarations
  PThreadData=^TThreadData;

  // Global thread data stored in threads[] array
  TThreadData=record
    ID:TThreadID;
    handle:THandle; // thread handle for waiting
    name:string8; // original name
    uniqueName:string8; // name with auto-generated suffix if needed
    pingCounter:integer; // how many times responded
    firstPing:integer; // time of first response
    lastPing:integer; // time of last response
    lastCS:PLock; // last critical section acquired in this thread
    terminating:LongBool; // atomic termination flag
    paused:LongBool; // atomic pause flag
    {$IFDEF UNIX}
    tid:cardinal;
    {$ENDIF}
    function GetStateInfo:string; // get thread state (call stack etc)
  end;

  // Thread context accessible from within thread procedure (NOT interface - simple record)
  TThreadContext=record
  private
    FData:PThreadData; // direct pointer to thread data
  public
    function Terminating:boolean; inline;
    function Paused:boolean; inline;
    function Name:String8; inline;
    function ID:TThreadID; inline;
  end;

  // Thread control interface for thread creator
  IThread=interface ['{B8E5C8A0-1234-4567-89AB-123456789ABC}']
    procedure Wait(timeout:cardinal=$FFFFFFFF);
    procedure Terminate; // signal termination via flag
    procedure Kill; // force terminate (dangerous!)
    procedure Pause; // toggle paused flag
    function GetName:String8;
    function GetID:TThreadID;
    function IsRunning:boolean;
    property Name:String8 read GetName;
    property ID:TThreadID read GetID;
  end;

  // Thread management scope
  Thread=record
    class function Start(const name:String8; proc:TThreadProc; parameter:pointer=nil):IThread; static;
    class procedure Register(const name:string); static;
    class procedure Unregister; static;
    class procedure Ping; static;
    class function GetName(threadID:cardinal=0):string; static;
    class procedure DumpRegistered; static; // dump all registered threads to log
    class procedure DumpLocks; static; // dump all locks state to log
    class procedure CheckTimeouts; static; // check for lock timeouts
    class procedure WaitUntilNotNil(var p; maxTime:integer=1000000); static; // wait until p<>nil
    class procedure TerminateAll(timeout:integer=1000; forceKill:boolean=false); static; // terminate all threads
  end;

  {$IFDEF DELPHI}
  // RAII lock (Delphi 10.4+ only)
  TScopedLock = record
    FLock: PLock;
    class function Create(ALock: PLock): TScopedLock; static;
    class operator Initialize(out Dest: TScopedLock);
    class operator Finalize(var Dest: TScopedLock);
    class operator Assign(var Dest: TScopedLock; const [ref] Src: TScopedLock);
  end;
  {$ENDIF}

var
  // Enable to check critical section levels to prevent potential deadlocks
  // This slows down critical sections - use carefully
  debugCriticalSections:boolean=false;

threadvar
  // Current thread context (accessible from within thread procedure)
  CurrentThread:TThreadContext;

// Configuration
implementation
uses SysUtils, Classes, Apus.Conv, Apus.Log
    {$IFDEF UNIX}, unixtype, BaseUnix, Syscall{$ENDIF}
    {$IFDEF IOS}, iphoneAll{$ENDIF}
    {$IFDEF ANDROID}, Apus.Android{$ENDIF};

const
  INFINITE = $FFFFFFFF; // timeout constant (same as Windows INFINITE)

type
// Thread start wrapper data
PThreadStartData=^TThreadStartData;
TThreadStartData=record
  proc:TThreadProc;
  parameter:pointer;
  name:String8;
end;

{$IFDEF MSWINDOWS}
// WaitOnAddress API (Windows 8+)
function WaitOnAddress(Address:pointer; CompareAddress:pointer; AddressSize:NativeUInt; dwMilliseconds:DWORD):BOOL;
  stdcall; external 'API-MS-Win-Core-Synch-l1-2-0.dll' name 'WaitOnAddress';
  procedure WakeByAddressSingle(Address:pointer);
  stdcall; external 'API-MS-Win-Core-Synch-l1-2-0.dll' name 'WakeByAddressSingle';
{$ENDIF}

// Local helper functions (to avoid dependency on Apus.Common)

function ExceptionMsg(const e:Exception):string;
begin
  result:=e.ClassName+': '+e.Message;
  // note: full implementation with stack trace is in Apus.Common
end;

{$IFDEF MSWINDOWS}
function IsDebuggerPresent:boolean;
begin
  result:=Windows.IsDebuggerPresent;
end;
{$ELSE}
function IsDebuggerPresent:boolean;
begin
  result:=false;
end;
{$ENDIF}

type
  // Lightweight thread handle implementation
  TThreadImpl=class(TInterfacedObject,IThread)
  private
    FThreadID:TThreadID;
  public
    constructor Create(threadID:TThreadID);
    // IThread implementation
    procedure Wait(timeout:cardinal=$FFFFFFFF);
    procedure Terminate;
    procedure Kill;
    procedure Pause;
    function GetName:String8;
    function GetID:TThreadID;
    function IsRunning:boolean;
  end;

var
  // Registry of all critical sections (protected by globalSpinLock from Apus.Core)
  crSections:array[1..100] of PLock;
  crSectCount:integer=0;
  // Registry of all named threads (pointers for stability)
  threads:array of PThreadData;
  lastThreadReport:int64; // time of last thread delay report
  // Auto-increment counters for thread name uniquification (pattern%)
  threadNameCounters:array of record
    pattern:String8;
    counter:integer;
  end;

// Platform-specific thread state info

{$IF Defined(MSWINDOWS)}
function OpenThread(DesiredAccess: DWORD; InheritHandle: BOOL; ThreadID: DWORD): THandle;
stdcall; external 'kernel32.dll' {$IFNDEF FPC}delayed{$ENDIF};

function GetThreadStateInfo(id:TThreadID):string;
const
  THREAD_GET_CONTEXT       = 08;
  THREAD_SUSPEND_RESUME    = 02;
var
  handle:THandle;
  context:^TContext; // use dynamic variable to make sure it's 16-byte aligned (important!)
  susp:integer;
  _ip,_bp,sbp:NativeUInt;
  st:string;
  i:integer;
  p:pointer;
begin
  handle:=OpenThread(THREAD_SUSPEND_RESUME+THREAD_GET_CONTEXT,false,id);
  susp:=SuspendThread(handle);
  if susp<0 then
    result:=GetLastErrorDesc;
  New(context);
  context.ContextFlags:=$00010007;
  if GetThreadContext(handle,context^) then begin
  {$IFDEF CPUX64}
  _ip:=context.Rip;
  _bp:=context.Rbp;
  sbp:=_bp;
  p:=pointer(PUInt64(_bp-8)^);
  st:=Conv.ToStr(p)+'<-';
  for i:=1 to 2 do begin
    inc(_bp,$20);
    p:=pointer(_bp+8);
    p:=pointer(PUInt64(p)^);
    if p=nil then break;
    st:=st+Conv.ToStr(p)+'<-';
    _bp:=PUInt64(_bp)^;
    if (_bp>sbp+$1000) or (_bp<sbp) then break;
  end;
  {$ENDIF}
  {$IFDEF CPU386}
  _ip:=context.Eip;
  _bp:=context.Ebp;
  for i:=1 to 3 do begin
    p:=pointer(_bp+4);
    if p=nil then break;
    p:=pointer(PCardinal(p)^);
    if p=nil then break;
    st:=st+Conv.ToStr(p)+'<-';
    _bp:=PCardinal(_bp)^;
  end;
  {$ENDIF}
  result:=Format('stack: %s ip=%x bp=%x',[st,_ip,sbp]);
  end else
    result:=GetLastErrorDesc;
  Dispose(context);
  ResumeThread(handle);
  CloseHandle(handle);
end;
{$ELSEIF Defined(UNIX) AND Defined(CPUAMD64)}
const
PTRACE_GETREGS = 12;
PTRACE_ATTACH = 16;
PTRACE_DETACH = 17;
function ptrace(__request:integer; PID: pid_t; Address: Pointer; Data: Longint): longint; cdecl; external libc name 'ptrace';

function GetThreadStateInfo(id:TThreadID):string;
var
  r1,r2,r3:longint;
  regs:array[0..199] of UInt64;
begin
  r1:=ptrace(PTRACE_ATTACH,id,nil,0);
  if r1=-1 then Log.Msg(IntToStr(fpGetErrno));
  r2:=ptrace(PTRACE_GETREGS,id,nil,UIntPtr(@regs));
  if r2=-1 then Log.Msg(GetSystemError);
  r3:=ptrace(PTRACE_DETACH,id,nil,0);
  Log.Msg('REGS: %d %x %x %x',[id,r1,r2,r3]);
end;
{$ELSE}
function GetThreadStateInfo(id:TThreadID):string;
begin
end;
{$ENDIF}

function TThreadData.GetStateInfo: string;
var
  st:string;
begin
  result:=Format('%s (%d)',[uniqueName,ID]);
  st:=GetThreadStateInfo(ID);
  if st<>'' then result:=result+' '+st;
  if lastCS<>nil then result:=result+Format(' lastCS=%s (%d)',[lastCS.name,lastCS.lockCount]);
end;


{ TLock }

procedure TLock.Init(const aName:String8; aLevel:integer=100);
begin
  SpinLock;
  try
    {$IFDEF MSWINDOWS}
    InitializeCriticalSection(crs);
    {$ELSE}
    InitCriticalSection(crs);
    {$ENDIF}
    name:=aName;
    caller:=0;
    time:=0;
    lockCount:=0;
    level:=aLevel;
    if crSectCount<length(crSections) then begin
      crSections[crSectCount+1]:=@self;
      inc(crSectCount);
    end;
  finally
    SpinUnlock;
  end;
end;

procedure TLock.Cleanup;
var
  i:integer;
begin
  SpinLock;
  try
    for i:=1 to crSectCount do
      if crSections[i]=@self then begin
        crSections[i]:=crSections[crSectCount];
        dec(crSectCount);
      end;
    {$IFDEF MSWINDOWS}
    DeleteCriticalSection(crs);
    {$ELSE}
    DoneCriticalSection(crs);
    {$ENDIF}
  finally
    SpinUnlock;
  end;
end;

procedure TLock.Enter;
var
  threadID:TThreadID;
  i,lastLevel,trIdx:integer;
  prevSection:PLock;
  callerAddr:pointer;
begin
  callerAddr:=nil;
  {$IFDEF CPU386}
  if caller=0 then
    callerAddr:=Stack.Caller;
  {$ENDIF}
  threadID:=GetCurrentThreadID;
  if lockCount>0 then begin
    trIdx:=-1;
    if threadID<>GetOwningThread then begin // from different thread? 
      tryingThread:=threadID;
      caller:=PtrUInt(callerAddr);
    end;
    if time=0 then time:=GetTickCount64+5000;
  end else // first attempt
  if debugCriticalSections then begin
    SpinLock;
    trIdx:=0; prevSection:=nil;
    for i:=0 to high(threads) do
      if threads[i]^.ID=threadID then begin
        trIdx:=i;
        prevSection:=threads[i]^.lastCS;
        if prevSection<>nil then lastLevel:=prevSection.level
        else lastLevel:=0;
        break;
      end;
    SpinUnlock;
    if trIdx=0 then raise EError.Create('Trying to enter CS '+name+' from unregistered thread');
    if level<=lastLevel then
      raise EError.Create(Format('Trying to enter CS %s with level %d within section %s with level %d',
        [name,level,prevSection.name,lastLevel]));
  end;

  {$IFDEF MSWINDOWS}
  Windows.EnterCriticalSection(crs);
  {$ELSE}
  System.EnterCriticalSection(crs);
  {$ENDIF}
  {$IFNDEF MSWINDOWS}
  owningThread:=threadID;
  {$ENDIF}
  caller:=0;
  tryingThread:=0;
  time:=0;
  inc(lockCount);
  if callerAddr=nil then callerAddr:=Stack.Caller;
  owner:=UIntPtr(callerAddr);
  if debugCriticalSections and (lockCount=1) then begin
    SpinLock;
    for i:=0 to high(threads) do
      if threads[i]^.ID=threadID then begin
        prevSection:=threads[i]^.lastCS;
        threads[i]^.lastCS:=@self;
        break;
      end;
    SpinUnlock;
  end;
end;

procedure TLock.Leave;
var
  i:integer;
  threadID:TThreadID;
begin
  ASSERT(lockCount>0);
  caller:=0;
  owner:=0;
  dec(lockCount);
  if debugCriticalSections and (lockCount=0) then begin
    SpinLock;
    threadID:=GetCurrentThreadID;
    for i:=0 to high(threads) do
      if threads[i]^.ID=threadID then begin
        if threads[i]^.lastCS=nil then
          raise EError.Create('Leaving wrong CS: '+name);
        if threads[i]^.lastCS<>@self then
          raise EError.Create('Leaving wrong CS: '+name+', should be '+threads[i]^.lastCS.name);
        threads[i]^.lastCS:=prevSection;
        break;
      end;
    SpinUnlock;
  end;
  {$IFDEF MSWINDOWS}
  Windows.LeaveCriticalSection(crs);
  {$ELSE}
  System.LeaveCriticalSection(crs);
  {$ENDIF}
end;

function TLock.IsLocked:boolean;
begin
  result:=lockCount>0;
end;

function TLock.GetOwner:TThreadID;
begin
  {$IFDEF MSWINDOWS}
  result:=crs.OwningThread;
  {$ELSE}
  result:=owningThread;
  {$ENDIF}
end;

function TLock.GetSysLockCount:integer;
begin
  {$IFDEF MSWINDOWS}
  result:=crs.RecursionCount;
  {$ELSE}
  result:=lockCount;
  {$ENDIF}
end;

function TLock.GetSysOwner:TThreadID;
begin
  {$IFDEF MSWINDOWS}
  result:=crs.OwningThread;
  {$ELSE}
  result:=owningThread;
  {$ENDIF}
end;

function TLock.GetOwningThread:TThreadID;
begin
  {$IFDEF MSWINDOWS}
  result:=crs.OwningThread;
  {$ELSE}
  result:=owningThread;
  {$ENDIF}
end;

{$IF Declared(SRWLOCK)}
{ TSRWLock }

procedure TSRWLock.Init(const aName:String8);
begin
  self.name:=aName;
  lockedEx:=false;
  lockRead:=0;
  InitializeSrwLock(lock);
end;

procedure TSRWLock.Cleanup;
begin
  // SRW locks don't need explicit cleanup
end;

procedure TSRWLock.EnterRead(caller:pointer);
begin
  AcquireSRWLockShared(lock);
  Atomic.Add(lockRead,1);
  if caller=nil then
    lastLockedRead:=Stack.Caller
  else
    lastLockedRead:=caller;
end;

procedure TSRWLock.LeaveRead;
begin
  Atomic.Sub(lockRead,1);
  ReleaseSRWLockShared(lock);
end;

procedure TSRWLock.EnterWrite(caller:pointer);
begin
  AcquireSRWLockExclusive(lock);
  lockedEx:=true;
  if caller=nil then
    lastLockedEx:=Stack.Caller
  else
    lastLockedEx:=caller;
end;

procedure TSRWLock.LeaveWrite;
begin
  lockedEx:=false;
  ReleaseSRWLockExclusive(lock);
end;
{$ENDIF}

{ TLightweightEvent }

procedure TLightweightEvent.Init;
begin
  state:=0;
end;

procedure TLightweightEvent.SetEvent;
begin
  {$IFDEF MSWINDOWS}
  Atomic.Exchange(state,1);
  WakeByAddressSingle(@state);
  {$ELSE}
  Atomic.Exchange(state,1);
  // Linux: futex wake - требует syscall, пока упрощенная версия
  {$ENDIF}
end;

procedure TLightweightEvent.ResetEvent;
begin
  Atomic.Exchange(state,0);
end;

function TLightweightEvent.WaitFor(timeoutMs:cardinal=INFINITE):boolean;
var
  expected:integer;
  startTime:int64;
begin
  expected:=0;
  {$IFDEF MSWINDOWS}
  if state=1 then exit(true);
  result:=WaitOnAddress(@state,@expected,sizeof(integer),timeoutMs);
  {$ELSE}
  // Linux: futex wait - требует syscall, пока простая реализация
  startTime:=GetTickCount64;
  while (state=0) and ((timeoutMs=INFINITE) or (GetTickCount64-startTime<timeoutMs)) do
    Sleep(1);
  result:=state=1;
  {$ENDIF}
end;

{ Thread }

// Generate unique thread name based on pattern
// Pattern "Name%" - auto-increment (Name-1, Name-2, ...)
// Pattern "Name#" - smallest free number (Name-1, Name-3 if Name-2 freed)
// No pattern - use as is (duplicates allowed)
function MakeUniqueName(const name:String8):String8;
var
  idx,i,counter,minFree:integer;
  pattern:String8;
  used:array of boolean;
  found:boolean;
begin
  // check for % pattern (auto-increment)
  idx:=Pos('%',name);
  if idx>0 then begin
    pattern:=Copy(name,1,idx-1);
    // find counter for this pattern
    counter:=-1;
    for i:=0 to high(threadNameCounters) do
      if threadNameCounters[i].pattern=pattern then begin
        counter:=i;
        break;
      end;
    // create new counter if not found
    if counter<0 then begin
      counter:=Length(threadNameCounters);
      SetLength(threadNameCounters,counter+1);
      threadNameCounters[counter].pattern:=pattern;
      threadNameCounters[counter].counter:=0;
    end;
    inc(threadNameCounters[counter].counter);
    result:=pattern+IntToStr(threadNameCounters[counter].counter);
    exit;
  end;

  // check for # pattern (smallest free)
  idx:=Pos('#',name);
  if idx>0 then begin
    pattern:=Copy(name,1,idx-1);
    // find all used numbers for this pattern
    SetLength(used,100); // reasonable limit
    for i:=0 to high(threads) do
      if Copy(threads[i]^.uniqueName,1,Length(pattern))=pattern then begin
        counter:=StrToIntDef(Copy(threads[i]^.uniqueName,Length(pattern)+1,10),-1);
        if (counter>=1) and (counter<Length(used)) then
          used[counter]:=true;
      end;
    // find smallest free number
    minFree:=1;
    for i:=1 to high(used) do
      if not used[i] then begin
        minFree:=i;
        break;
      end;
    result:=pattern+IntToStr(minFree);
    exit;
  end;

  // no pattern - use as is
  result:=name;
end;

// Thread wrapper for automatic registration/unregistration
function ThreadStartWrapper(param:pointer):UIntPtr;
var
  data:PThreadStartData;
  userProc:TThreadProc;
  userParam:pointer;
begin
  data:=PThreadStartData(param);
  userProc:=data^.proc;
  userParam:=data^.parameter;

  Thread.Register(data^.name);
  Dispose(data);

  try
    result:=userProc(userParam);
  finally
    Thread.Unregister;
  end;
end;

class function Thread.Start(const name:String8; proc:TThreadProc; parameter:pointer):IThread;
var
  data:PThreadStartData;
  threadID:TThreadID;
  handle:THandle;
begin
  // create wrapper data
  data:=New(PThreadStartData);
  data^.proc:=proc;
  data^.parameter:=parameter;
  data^.name:=name;

  // start thread with wrapper
  {$IFDEF FPC}
  threadID:=BeginThread(@ThreadStartWrapper,data);
  handle:=0; // FPC doesn't return handle, will be set in Register
  {$ELSE}
  handle:=BeginThread(nil,0,@ThreadStartWrapper,data,0,threadID);
  {$ENDIF}

  // create and return interface
  result:=TThreadImpl.Create(threadID);
end;

class procedure Thread.Register(const name:string);
var
  i:integer;
  threadID:TThreadID;
  extra:string;
  data:PThreadData;
  uniqueName:String8;
begin
  extra:='';
  threadID:=GetCurrentThreadId;

  // Allocate data outside lock (fast allocation without contention)
  New(data);
  data^.ID:=threadID;
  data^.name:=name;
  data^.lastCS:=nil;
  data^.pingCounter:=0;
  data^.firstPing:=0;
  data^.lastPing:=0;
  data^.terminating:=false;
  data^.paused:=false;
  data^.handle:=0;
  {$IFDEF UNIX}
  data^.tid:=Do_syscall(syscall_nr_gettid); // syscall outside lock
  extra:='tid: '+IntToStr(data^.tid);
  {$ENDIF}

  SpinLock;
  try
    // check if already registered
    for i:=0 to high(threads) do
      if cardinal(threads[i]^.ID)=threadID then begin
        Dispose(data); // cleanup allocated data
        exit;
      end;

    // generate unique name (needs access to threads[] and threadNameCounters[])
    uniqueName:=MakeUniqueName(name);
    data^.uniqueName:=uniqueName;

    // add to array
    i:=length(threads);
    SetLength(threads,i+1);
    threads[i]:=data;

    // initialize CurrentThread context
    CurrentThread.FData:=data;
  finally
    SpinUnlock;
  end;

  // Log outside lock (logging can be slow)
  Log.Msg('Thread ID: %d named %s %s',[data^.ID,uniqueName,extra]);

  // set debugger name outside lock
  {$IFDEF DELPHI}
  {$IF Declared(TThread.NameThreadForDebugging)}
  TThread.NameThreadForDebugging(data^.uniqueName);
  {$ENDIF}
  {$ELSE}
  TThread.NameThreadForDebugging(data^.uniqueName);
  {$ENDIF}

  {$IFDEF ANDROID}
  AndroidInitThread;
  {$ENDIF}
end;

class procedure Thread.Unregister;
var
  i,n:integer;
  id:TThreadID;
  data:PThreadData;
  threadName:String8;
begin
  id:=GetCurrentThreadID;
  data:=nil;

  SpinLock;
  try
    n:=high(threads);
    for i:=0 to n do
      if threads[i]^.ID=id then begin
        data:=threads[i];
        threadName:=data^.uniqueName;
        // remove from array
        threads[i]:=threads[n];
        SetLength(threads,n);
        break;
      end;
  finally
    SpinUnlock;
  end;

  // Cleanup outside lock (Dispose + Log can be slow)
  if data<>nil then begin
    Log.Msg('Thread '+threadName+' unregistered');
    {$IFDEF ANDROID}
    AndroidDoneThread;
    {$ENDIF}
    Dispose(data);
  end;

  // clear current thread context
  CurrentThread.FData:=nil;
end;

class procedure Thread.Ping;
var
  i:integer;
  t:int64;
  id:TThreadID;
  needDump:boolean;
  st:string;
begin
  t:=GetTickCount64;
  id:=GetCurrentThreadID;
  needDump:=false;
  SpinLock;
  try
    for i:=0 to high(threads) do
      if threads[i]^.id=id then // current thread => update
        with threads[i]^ do begin
          inc(pingCounter);
          if pingCounter=1 then firstPing:=t;
          lastPing:=t;
        end
      else // other thread => report
        if t>lastThreadReport+1000 then
          with threads[i]^ do
            if pingCounter>0 then
              if (t-lastPing>300) then begin
                st:=st+#13#10+'  '+uniqueName+' for '+inttostr(t-lastPing);
                if (t-lastPing>1500) then needDump:=true;
              end;

    if st<>'' then begin
      Log.Force('Threads not responding: '+st);
      lastThreadReport:=t;
    end;
  finally
    SpinUnlock;
  end;

  // Dump outside lock to avoid recursive SpinLock (deadlock!)
  if needDump then begin
    Thread.DumpLocks;
    Thread.DumpRegistered;
  end;
end;

class function Thread.GetName(threadID:cardinal=0):string;
var
  id:TThreadID;
  i:integer;
begin
  if threadID=0 then
    id:=GetCurrentThreadId
  else
    id:=threadID;
  SpinLock;
  try
    for i:=0 to high(threads) do
      if cardinal(threads[i]^.ID)=id then begin
        result:=threads[i]^.uniqueName;
        exit;
      end;
    result:='';
  finally
    SpinUnlock;
  end;
end;

class procedure Thread.DumpRegistered;
var
  i,n:integer;
  st,stateInfo:string;
  snapshot:array of TThreadData; // copy data to avoid long lock
begin
  // Copy thread data inside lock (fast)
  SpinLock;
  try
    n:=Length(threads);
    SetLength(snapshot,n);
    for i:=0 to n-1 do
      snapshot[i]:=threads[i]^;
  finally
    SpinUnlock;
  end;

  // Dump outside lock (slow - calls GetThreadStateInfo with SuspendThread)
  for i:=0 to n-1 do begin
    st:=IntToStr(i)+'. '+snapshot[i].uniqueName+' ID: '+IntToStr(snapshot[i].ID);
    {$IFDEF UNIX}
    st:=st+' TID: '+inttostr(snapshot[i].tid);
    {$ENDIF}
    stateInfo:=GetThreadStateInfo(snapshot[i].ID);
    if stateInfo<>'' then st:=st+'  State: '+stateInfo;
    Log.Force(st);
  end;
end;

class procedure Thread.DumpLocks;
var
  i:integer;
  st:string;
begin
  SpinLock;
  try
    for i:=1 to crSectCount do begin
      st:=IntToStr(i)+'. '+crSections[i].name;
      if crSections[i].caller<>0 then
        st:=st+' LOCKED BY '+ GetName(crSections[i].GetOwningThread)+
        ' FROM:'+Conv.ToHex(crSections[i].owner,8)+
        ' AT:'+Conv.ToHex(crSections[i].caller,8)+
        ' time '+IntToStr(GetTickCount64-crSections[i].time);
      if crSections[i].caller<>0 then
        st:=st+' PENDING FROM '+GetName(crSections[i].tryingThread)+
        ' AT:'+Conv.ToHex(crSections[i].caller,8)+' time '+
        IntToStr(GetTickCount64-crSections[i].time);
    end;
  finally
    SpinUnlock;
  end;
end;

class procedure Thread.CheckTimeouts;
var
  i:integer;
  t:int64;
begin
  {$IFDEF MSWINDOWS}
  if IsDebuggerPresent then exit; // prevent termination because of timeout during debug
  {$ENDIF}
  t:=GetTickCount64;
  for i:=1 to crSectCount do begin
    if (crSections[i].time>0) and (crSections[i].time<t) and (crSections[i].time>t-1000000) then begin
      Log.Force('Timeout for: '+crSections[i].name+' thread: '+Thread.GetName);
      Thread.DumpLocks;
      raise EWarning.Create('Critical section timeout!');
    end;
  end;
end;

class procedure Thread.WaitUntilNotNil(var p; maxTime:integer);
var
  time:int64;
begin
  time:=GetTickCount64+maxTime;
  while (pointer(p)=nil) and (GetTickCount64<time) do
    sleep(1);
  if pointer(p)=nil then
    raise EError.Create('WaitUntilNotNil timeout');
end;

class procedure Thread.TerminateAll(timeout:integer; forceKill:boolean);
var
  i:integer;
  startTime:int64;
  allDone:boolean;
begin
  // signal termination to all threads
  SpinLock;
  try
    for i:=0 to high(threads) do
      threads[i]^.terminating:=true;
  finally
    SpinUnlock;
  end;

  // wait for all threads with timeout
  startTime:=GetTickCount64;
  repeat
    Sleep(10);
    SpinLock;
    try
      allDone:=Length(threads)=0;
    finally
      SpinUnlock;
    end;
    if allDone then exit;
  until GetTickCount64-startTime>timeout;

  // force kill if requested and timeout expired
  if forceKill then begin
    SpinLock;
    try
      for i:=0 to high(threads) do begin
        if threads[i]^.handle<>0 then begin
          {$IFDEF MSWINDOWS}
          TerminateThread(threads[i]^.handle,0);
          {$ELSE}
          // POSIX: no safe way to force kill, just log warning
          Log.Msg('Cannot force kill thread: '+threads[i]^.uniqueName);
          {$ENDIF}
        end;
      end;
    finally
      SpinUnlock;
    end;
  end;
end;

// Internal helper functions

// Find thread data by ID, returns nil if not found
function FindThreadData(id:TThreadID):PThreadData;
var
  i:integer;
begin
  for i:=0 to high(threads) do
    if threads[i]^.ID=id then exit(threads[i]);
  result:=nil;
end;

{ TThreadContext }

function TThreadContext.Terminating:boolean;
begin
  if FData<>nil then
    result:=FData^.terminating
  else
    result:=true; // thread not registered = should terminate
end;

function TThreadContext.Paused:boolean;
begin
  if FData<>nil then
    result:=FData^.paused
  else
    result:=false;
end;

function TThreadContext.Name:String8;
begin
  if FData<>nil then
    result:=FData^.uniqueName
  else
    result:='';
end;

function TThreadContext.ID:TThreadID;
begin
  if FData<>nil then
    result:=FData^.ID
  else
    result:=0;
end;

{ TThreadImpl }

constructor TThreadImpl.Create(threadID:TThreadID);
begin
  inherited Create;
  FThreadID:=threadID;
end;

procedure TThreadImpl.Wait(timeout:cardinal);
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(FThreadID);
    if data=nil then exit; // thread already finished
  finally
    SpinUnlock;
  end;

  {$IFDEF MSWINDOWS}
  if data^.handle<>0 then
    WaitForSingleObject(data^.handle,timeout);
  {$ELSE}
  // POSIX: no direct way to wait by TThreadID, use polling
  // TThread.WaitFor would work if we stored TThread reference
  // For now, simple polling
  while FindThreadData(FThreadID)<>nil do
    Sleep(10);
  {$ENDIF}
end;

procedure TThreadImpl.Terminate;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(FThreadID);
    if data<>nil then
      data^.terminating:=true;
  finally
    SpinUnlock;
  end;
end;

procedure TThreadImpl.Kill;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(FThreadID);
    if (data<>nil) and (data^.handle<>0) then begin
      {$IFDEF MSWINDOWS}
      TerminateThread(data^.handle,0);
      {$ELSE}
      // POSIX: no safe way to force kill
      raise EError.Create('Kill not supported on this platform');
      {$ENDIF}
    end;
  finally
    SpinUnlock;
  end;
end;

procedure TThreadImpl.Pause;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(FThreadID);
    if data<>nil then
      data^.paused:=not data^.paused; // toggle
  finally
    SpinUnlock;
  end;
end;

function TThreadImpl.GetName:String8;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(FThreadID);
    if data<>nil then
      result:=data^.uniqueName
    else
      result:='';
  finally
    SpinUnlock;
  end;
end;

function TThreadImpl.GetID:TThreadID;
begin
  result:=FThreadID;
end;

function TThreadImpl.IsRunning:boolean;
begin
  SpinLock;
  try
    result:=FindThreadData(FThreadID)<>nil;
  finally
    SpinUnlock;
  end;
end;

{$IFDEF DELPHI}
{ TScopedLock }

class function TScopedLock.Create(ALock:PLock):TScopedLock;
begin
  result.FLock:=ALock;
  if ALock<>nil then ALock^.Enter;
end;

class operator TScopedLock.Initialize(out Dest:TScopedLock);
begin
  Dest.FLock:=nil;
end;

class operator TScopedLock.Finalize(var Dest:TScopedLock);
begin
  if Dest.FLock<>nil then Dest.FLock^.Leave;
end;

class operator TScopedLock.Assign(var Dest:TScopedLock; const [ref] Src:TScopedLock);
begin
  // TScopedLock should not be copied - use only as local variable
  raise EError.Create('TScopedLock cannot be assigned');
end;
{$ENDIF}

end.
