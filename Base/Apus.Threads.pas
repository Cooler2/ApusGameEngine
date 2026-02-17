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
uses Apus.Core, SysUtils{$IFDEF MSWINDOWS}, Windows{$ENDIF};

type
  PLock=^TLock;

  // Enhanced critical section with debug support and deadlock detection
  // Use lock.Init/Cleanup to initialize/finalize
  // Use lock.Enter/Leave for locking
  TLock=record
  private
    crs:TRTLCriticalSection;
    caller:UIntPtr;     // address where lock was attempted
    owner:UIntPtr;      // address where lock was acquired
    {$IFNDEF MSWINDOWS}
    owningThread:TThreadID;
    {$ENDIF}
    tryingThread:TThreadID;  // thread trying to acquire the lock
    timeout:int64;         // tick to terminate
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

  {$SCOPEDENUMS ON}
  // Thread completion status (use as TThreadStatus.Running etc.)
  TThreadStatus=(Running, Finished, Error);

  // Thread context accessible from within thread procedure (NOT interface - simple record)
  // Use CurrentThread to access the context inside a thread procedure
  // TThreadData is internal - not exposed in interface
  TThreadContext=record
  private
    data:pointer; // PThreadData - internal type kept in implementation
  public
    function Terminating:boolean;
    function Paused:boolean;
    function Name:String8;
    function ID:TThreadID;
    // Status setters - call from within thread procedure to update status
    procedure SetProgress(p:single);             // progress 0..1
    procedure SetStatusText(const txt:String8);  // spinlock-protected
    procedure SetResult(const data:TBytes);      // single write only
    procedure SetObject(obj:TObject);            // set custom result object
    procedure SetError(const msg:String8);       // set error status + message
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
    // Status polling
    function GetStatus:TThreadStatus;
    function GetStatusText:String8;    // spinlock-protected
    function GetProgress:single;
    function GetResultData:TBytes;     // valid after status=Finished
    function TakeObject:TObject;       // take custom object (transfers ownership, clears internal ref)
    property Name:String8 read GetName;
    property ID:TThreadID read GetID;
    property Status:TThreadStatus read GetStatus;
    property StatusText:String8 read GetStatusText;
    property Progress:single read GetProgress;
    property ResultData:TBytes read GetResultData;
  end;

  // Thread management scope
  Thread=record
    class function Start(const name:String8; proc:TThreadProc; parameter:pointer=nil):IThread; static;
    class procedure Register(const name:string; handle:THandle=0); static;
    class procedure Unregister; static;
    class procedure Ping; static;
    class function GetName(threadID:TThreadID=0):string; static;
    class procedure DumpRegistered; static; // dump all registered threads to log
    class procedure DumpLocks; static; // dump all locks state to log
    class procedure CheckTimeouts; static; // check for lock timeouts
    class procedure WaitUntilNotNil(var p; maxTime:integer=1000000); static; // wait until p<>nil
    class procedure TerminateAll(timeout:integer=1000; forceKill:boolean=false); static; // terminate all threads
  end;

  {$IFDEF DELPHI}
  // RAII lock (Delphi 10.4+ only)
  TScopedLock = record
    lock: PLock;
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
uses Classes, Apus.Strings, Apus.Conv, Apus.Log
    {$IFDEF UNIX}, unixtype, BaseUnix, Syscall{$ENDIF}
    {$IFDEF IOS}, iphoneAll{$ENDIF}
    {$IFDEF ANDROID}, Apus.Android{$ENDIF};

const
  INFINITE = $FFFFFFFF; // timeout constant (same as Windows INFINITE)

{$IFDEF MSWINDOWS}
// WaitOnAddress API (Windows 8+)
function WaitOnAddress(Address:pointer; CompareAddress:pointer; AddressSize:NativeUInt; dwMilliseconds:DWORD):BOOL;
  stdcall; external 'API-MS-Win-Core-Synch-l1-2-0.dll' name 'WaitOnAddress';
  procedure WakeByAddressSingle(Address:pointer);
  stdcall; external 'API-MS-Win-Core-Synch-l1-2-0.dll' name 'WakeByAddressSingle';
{$ENDIF}

{$IFDEF UNIX}
// pthread_join for POSIX thread wait (TThreadID is pthread_t on POSIX)
function pthread_join(thread:TThreadID; value_ptr:Ppointer):longint; cdecl; external 'pthread';
{$ENDIF}

type
  // Internal thread registry entry (not exposed in interface section)
  PThreadData=^TThreadData;
  TThreadData=record
    ID:TThreadID;
    handle:THandle;     // thread handle for waiting
    uniqueName:String8; // resolved name (pattern stored in threadNameCounters)
    startTime:int64;    // CoreTime.Ticks when thread began executing
    lastPing:int64;     // CoreTime.Ticks of last Ping call (0 = never pinged)
    lastCS:PLock;       // last critical section acquired in this thread
    terminating:LongBool; // atomic termination flag
    paused:LongBool;      // atomic pause flag
    implPtr:pointer;      // TThreadImpl pointer for status updates (raw - avoids forward declaration)
    {$IFDEF UNIX}
    tid:cardinal;
    {$ENDIF}
    function GetStateInfo:String8; // get thread state (call stack etc)
  end;

  // Thread start wrapper data
  PThreadStartData=^TThreadStartData;
  TThreadStartData=record
    proc:TThreadProc;
    parameter:pointer;
    threadData:PThreadData; // pre-allocated, added to threads[] by Thread.Start
    impl:TObject;           // TThreadImpl (raw object ref - avoids premature free via interface)
    {$IFDEF DEBUG}
    startupTimer:int64;     // QPC value from Thread.Start, for startup latency measurement
    {$ENDIF}
  end;


  // Lightweight thread handle implementation
  TThreadImpl=class(TInterfacedObject,IThread)
  private
    threadID:TThreadID;
    handle:THandle;             // Windows handle or 0 for POSIX (uses threadID)
    name:String8;               // cached at creation, valid after thread exits
    status:TThreadStatus;       // written atomically (thread writes, creator reads)
    statusText:String8;         // spinlock-protected (may be written/read many times)
    statusTextLock:integer;     // 0=free, 1=locked
    progress:single;            // 4-byte aligned, safe without explicit lock
    resultData:TBytes;          // single write only (written before Finished)
    resultWritten:boolean;      // guard for single-write enforcement
    customObject:TObject;       // arbitrary result object (creator takes ownership via TakeObject)
    keepAlive:IThread;          // holds self alive while thread is running
  public
    constructor Create(const aName:String8);
    destructor Destroy; override;
    // IThread: control
    procedure Wait(timeout:cardinal=$FFFFFFFF);
    procedure Terminate;
    procedure Kill;
    procedure Pause;
    function GetName:String8;
    function GetID:TThreadID;
    function IsRunning:boolean;
    // IThread: status polling
    function GetStatus:TThreadStatus;
    function GetStatusText:String8;
    function GetProgress:single;
    function GetResultData:TBytes;
    function TakeObject:TObject;
    // Internal setters (called from TThreadContext methods)
    procedure IntSetProgress(p:single);
    procedure IntSetStatusText(const txt:String8);
    procedure IntSetResult(const data:TBytes);
    procedure IntSetObject(obj:TObject);
    procedure IntSetError(const msg:String8);
    procedure IntFinish; // mark Finished, release keepAlive
  end;

var
  // Registry of all critical sections (protected by globalSpinLock from Apus.Core)
  crSections:array[1..100] of PLock;
  crSectCount:integer=0;
  // Registry of all named threads (pointers for stability)
  threads:array of PThreadData;
  lastThreadReport:int64; // time of last thread delay report
  {$IFDEF DEBUG}
  // Startup latency stats: accumulated under SpinLock, for future diagnostics
  threadStartupTotalUs:int64=0; // total startup latency in microseconds
  threadStartupCount:integer=0; // number of Thread.Start threads measured
  {$ENDIF}
  // Auto-increment counters for thread name uniquification (pattern%)
  threadNameCounters:array of record
    pattern:String8;
    counter:integer;
  end;

// Platform-specific thread state info

{$IF Defined(MSWINDOWS)}
function OpenThread(DesiredAccess: DWORD; InheritHandle: BOOL; ThreadID: DWORD): THandle;
stdcall; external 'kernel32.dll' {$IFNDEF FPC}delayed{$ENDIF};

function GetThreadStateInfo(id:TThreadID):string8;
const
  THREAD_GET_CONTEXT       = 08;
  THREAD_SUSPEND_RESUME    = 02;
var
  handle:THandle;
  context:^TContext; // use dynamic variable to make sure it's 16-byte aligned (important!)
  susp:integer;
  _ip,_bp,sbp:NativeUInt;
  st:string8;
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
    result:=UTF8.Format('stack: %s ip=%x bp=%x',[st,_ip,sbp]);
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
function ptrace(__request:integer; PID:longint; Address:Pointer; Data:Longint):longint; cdecl; external 'c' name 'ptrace';

function GetThreadStateInfo(id:TThreadID):string;
var
  r1,r2,r3:longint;
  regs:array[0..199] of UInt64;
begin
  r1:=ptrace(PTRACE_ATTACH,id,nil,0);
  if r1=-1 then Log.Msg(Conv.ToStr(fpGetErrno));
  r2:=ptrace(PTRACE_GETREGS,id,nil,UIntPtr(@regs));
  if r2=-1 then Log.Msg(Conv.ToStr(fpGetErrno));
  r3:=ptrace(PTRACE_DETACH,id,nil,0);
  Log.Msg('REGS: %d %x %x %x',[id,r1,r2,r3]);
end;
{$ELSE}
function GetThreadStateInfo(id:TThreadID):string;
begin
end;
{$ENDIF}

function TThreadData.GetStateInfo: string8;
var
  st:string8;
begin
  result:=UTF8.Format('%s (%d)',[uniqueName,ID]);
  st:=GetThreadStateInfo(ID);
  if st<>'' then result:=result+' '+st;
  if lastCS<>nil then
    result:=result+UTF8.Format(' lastCS=%s (%d)',[lastCS.name,lastCS.lockCount]);
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
    timeout:=0;
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
    if timeout=0 then timeout:=Apus.Core.CoreTime.Ticks+5000;
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
      raise EError.Create('Trying to enter CS %s with level %d within section %s with level %d',
        [name,level,prevSection.name,lastLevel]);
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
  timeout:=0;
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
  startTime:=CoreTime.Ticks;
  while (state=0) and ((timeoutMs=INFINITE) or (CoreTime.Ticks-startTime<timeoutMs)) do
    CoreTime.Sleep(1);
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
    result:=pattern+Conv.ToStr(threadNameCounters[counter].counter);
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
        counter:=Conv.ToInt(Copy(threads[i]^.uniqueName,Length(pattern)+1,10),-1);
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
    result:=pattern+Conv.ToStr(minFree);
    exit;
  end;

  // no pattern - use as is
  result:=name;
end;

// Internal: add current thread to registry; name may contain pattern (resolved inside lock)
procedure RegisterThread(const name:String8; handle:THandle; implObj:pointer);
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
  data^.lastCS:=nil;
  data^.startTime:=CoreTime.Ticks; // for Register: called from within thread
  data^.lastPing:=0;
  data^.terminating:=false;
  data^.paused:=false;
  data^.handle:=handle;
  data^.implPtr:=implObj;
  {$IFDEF UNIX}
  data^.tid:=Do_syscall(syscall_nr_gettid); // syscall outside lock
  extra:='tid: '+Conv.ToStr(data^.tid);
  {$ENDIF}

  SpinLock;
  try
    // check if already registered
    for i:=0 to high(threads) do
      if cardinal(threads[i]^.ID)=threadID then begin
        Dispose(data); // cleanup allocated data
        exit;
      end;

    // resolve unique name
    uniqueName:=MakeUniqueName(name);
    data^.uniqueName:=uniqueName;

    // add to registry
    threads:=threads+[data];

    // initialize CurrentThread context
    CurrentThread.data:=data;
  finally
    SpinUnlock;
  end;

  // Log outside lock (logging can be slow)
  Log.Msg('Thread ID: %d named %s %s',[data^.ID,uniqueName,extra]);

  // set debugger name outside lock
  {$IFDEF DELPHI}
  {$IF Declared(TThread.NameThreadForDebugging)}
  TThread.NameThreadForDebugging(uniqueName);
  {$ENDIF}
  {$ELSE}
  TThread.NameThreadForDebugging(uniqueName);
  {$ENDIF}

  {$IFDEF ANDROID}
  AndroidInitThread;
  {$ENDIF}
end;

// Internal: remove current thread from registry, notify impl
procedure UnregisterThread;
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
    Log.Msg('Thread %s unregistered',[threadName]);
    {$IFDEF ANDROID}
    AndroidDoneThread;
    {$ENDIF}
    // notify impl: thread finished, release self-reference
    if data^.implPtr<>nil then
      TThreadImpl(data^.implPtr).IntFinish;
    Dispose(data);
  end;

  // clear current thread context
  CurrentThread.data:=nil;
end;

// Thread wrapper: called in context of new thread, fills in ID/tid, runs user proc
function ThreadStartWrapper(param:pointer):UIntPtr;
var
  startData:PThreadStartData;
  userProc:TThreadProc;
  userParam:pointer;
  data:PThreadData;
  {$IFDEF DEBUG}
  startupTimer:int64;
  startupUs:int64;
  {$ENDIF}
begin
  startData:=PThreadStartData(param);
  userProc:=startData^.proc;
  userParam:=startData^.parameter;
  data:=startData^.threadData;
  {$IFDEF DEBUG}
  startupTimer:=startData^.startupTimer; // save before Dispose
  {$ENDIF}
  Dispose(startData);

  // Fill in remaining fields from within thread context
  SpinLock;
  try
    if data^.ID=0 then
      data^.ID:=GetCurrentThreadID; // in case Thread.Start hasn't set it yet
    {$IFDEF UNIX}
    data^.tid:=Do_syscall(syscall_nr_gettid);
    {$ENDIF}
  finally
    SpinUnlock;
  end;

  // Set thread context (data is heap-allocated → pointer stable regardless of threads[] realloc)
  CurrentThread.data:=data;
  data^.startTime:=CoreTime.Ticks; // mark when thread actually began executing
  {$IFDEF DEBUG}
  startupUs:=round(TimerSec(startupTimer)*1e6);
  SpinLock;
  inc(threadStartupTotalUs,startupUs);
  inc(threadStartupCount);
  SpinUnlock;
  {$ENDIF}

  // Log and set debug name
  Log.Msg('Thread ID: %d named %s',[data^.ID,data^.uniqueName]);
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

  result:=0;
  try
    result:=userProc(userParam);
  finally
    UnregisterThread;
  end;
end;

class function Thread.Start(const name:String8; proc:TThreadProc; parameter:pointer):IThread;
var
  startData:PThreadStartData;
  impl:TThreadImpl;
  threadID:TThreadID;
  handle:THandle;
  uniqueName:String8;
  data:PThreadData;
begin
  // Allocate thread registry entry
  New(data);
  data^.lastCS:=nil;
  data^.startTime:=0; // set in ThreadStartWrapper when thread actually runs
  data^.lastPing:=0;
  data^.terminating:=false;
  data^.paused:=false;
  data^.ID:=0;     // filled after BeginThread
  data^.handle:=0; // filled after BeginThread
  data^.implPtr:=nil; // filled after BeginThread

  // Resolve name and add to registry (both under same lock to fix # pattern race)
  SpinLock;
  try
    uniqueName:=MakeUniqueName(name);
    data^.uniqueName:=uniqueName;
    threads:=threads+[data]; // visible immediately → next Thread.Start sees this name
  finally
    SpinUnlock;
  end;

  // Create impl with final resolved name (cached for IThread lifetime)
  impl:=TThreadImpl.Create(uniqueName);

  // Prepare wrapper data
  startData:=New(PThreadStartData);
  startData^.proc:=proc;
  startData^.parameter:=parameter;
  startData^.threadData:=data;
  startData^.impl:=impl;
  {$IFDEF DEBUG}
  StartTimer(startData^.startupTimer); // record QPC moment just before BeginThread
  {$ENDIF}

  // Start thread
  {$IFDEF FPC}
  threadID:=BeginThread(@ThreadStartWrapper,startData);
  {$IFDEF MSWINDOWS}
  handle:=threadID; // FPC on Windows: threadID is handle
  {$ELSE}
  handle:=0; // FPC on POSIX: threadID is pthread_t, use pthread_join
  {$ENDIF}
  {$ELSE}
  handle:=BeginThread(nil,0,@ThreadStartWrapper,startData,0,threadID);
  {$ENDIF}

  // Update registry entry with actual ID (wrapper also sets this, but we set it here too)
  SpinLock;
  try
    data^.ID:=threadID;
    data^.handle:=handle;
    data^.implPtr:=impl;
  finally
    SpinUnlock;
  end;

  impl.threadID:=threadID;
  impl.handle:=handle;

  result:=impl;
end;

// Public: register current (foreign) thread in the registry for monitoring
class procedure Thread.Register(const name:string; handle:THandle=0);
begin
  RegisterThread(name,handle,nil);
end;

// Public: unregister current (foreign) thread from the registry
class procedure Thread.Unregister;
begin
  UnregisterThread;
end;

class procedure Thread.Ping;
var
  i:integer;
  t:int64;
  d:PThreadData;
  needDump:boolean;
  st:String8;
begin
  t:=CoreTime.Ticks;
  // lock-free self-update: only this thread writes its own fields
  d:=PThreadData(CurrentThread.data);
  if d<>nil then
    d^.lastPing:=t;

  // throttled watchdog: check other threads ~once per second
  if t<lastThreadReport+1000 then exit;

  needDump:=false;
  st:='';
  SpinLock;
  try
    lastThreadReport:=t; // suppress concurrent watchdog invocations
    for i:=0 to high(threads) do
      if threads[i]<>d then // skip current thread (already updated above)
        with threads[i]^ do
          if (lastPing>0) and (t-lastPing>300) then begin
            st:=st+#13#10+'  '+uniqueName+' for '+Conv.tostr(t-lastPing);
            if t-lastPing>1500 then needDump:=true;
          end;
  finally
    SpinUnlock;
  end;

  // logging and dumps outside lock (can be slow, may re-enter SpinLock)
  if st<>'' then
    Log.Force('Threads not responding: '+st);
  if needDump then begin
    Thread.DumpLocks;
    Thread.DumpRegistered;
  end;
end;

class function Thread.GetName(threadID:TThreadID=0):string;
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
      if threads[i]^.ID=id then begin
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
  t:int64;
  st,stateInfo:String8;
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
  t:=CoreTime.Ticks;
  for i:=0 to n-1 do begin
    st:=UTF8.Format('%d. %s ID: %d',[i,snapshot[i].uniqueName,snapshot[i].ID]);
    {$IFDEF UNIX}
    st:=st+UTF8.Format(' TID: %d',[snapshot[i].tid]);
    {$ENDIF}
    if snapshot[i].startTime>0 then
      st:=st+UTF8.Format(' running %dms',[t-snapshot[i].startTime])
    else
      st:=st+' (starting)';
    if snapshot[i].lastPing>0 then
      st:=st+UTF8.Format(' ping %dms ago',[t-snapshot[i].lastPing])
    else
      st:=st+' (no ping)';
    stateInfo:=GetThreadStateInfo(snapshot[i].ID);
    if stateInfo<>'' then st:=st+'  State: '+stateInfo;
    Log.Force(st);
  end;
end;

class procedure Thread.DumpLocks;
type
  TLockSnap=record
    name:String8;
    lockCount:integer;
    ownerThread:TThreadID;
    ownerAddr:UIntPtr;
    callerAddr:UIntPtr;
    tryingThread:TThreadID;
    timeout:int64;
  end;
var
  i,n:integer;
  st:string8;
  snap:array of TLockSnap;
begin
  // copy data under lock to avoid calling GetName (which also uses SpinLock) inside SpinLock
  SpinLock;
  try
    n:=crSectCount;
    SetLength(snap,n);
    for i:=0 to n-1 do begin
      snap[i].name:=crSections[i+1].name;
      snap[i].lockCount:=crSections[i+1].lockCount;
      snap[i].ownerThread:=crSections[i+1].GetOwningThread;
      snap[i].ownerAddr:=crSections[i+1].owner;
      snap[i].callerAddr:=crSections[i+1].caller;
      snap[i].tryingThread:=crSections[i+1].tryingThread;
      snap[i].timeout:=crSections[i+1].timeout;
    end;
  finally
    SpinUnlock;
  end;

  for i:=0 to n-1 do begin
    st:=UTF8.Format('%d. %s',[i+1,snap[i].name]);
    if snap[i].lockCount>0 then
      st:=st+UTF8.Format(' LOCKED BY %s FROM:%s',
        [GetName(snap[i].ownerThread),Conv.ToHex(snap[i].ownerAddr,8)]);
    if snap[i].callerAddr<>0 then
      st:=st+UTF8.Format(' PENDING FROM %s AT:%s time %d',
        [GetName(snap[i].tryingThread),Conv.ToHex(snap[i].callerAddr,8),
         CoreTime.Ticks-snap[i].timeout+5000]);
    Log.Force(st);
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
  t:=CoreTime.Ticks;
  for i:=1 to crSectCount do begin
    if (crSections[i].timeout>0) and (crSections[i].timeout<t) and (crSections[i].timeout>t-1000000) then begin
      Log.Force(UTF8.Format('Timeout for: %s thread: %s',[crSections[i].name,Thread.GetName]));
      Thread.DumpLocks;
      raise EWarning.Create('Critical section timeout!');
    end;
  end;
end;

class procedure Thread.WaitUntilNotNil(var p; maxTime:integer);
var
  timeWait:int64;
begin
  timeWait:=CoreTime.Ticks+maxTime;
  while (pointer(p)=nil) and (CoreTime.Ticks<timeWait) do
    CoreTime.Sleep(1);
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
  startTime:=CoreTime.Ticks;
  repeat
    CoreTime.Sleep(10);
    SpinLock;
    try
      allDone:=Length(threads)=0;
    finally
      SpinUnlock;
    end;
    if allDone then exit;
  until CoreTime.Ticks-startTime>timeout;

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
var d:PThreadData;
begin
  d:=PThreadData(data);
  if d<>nil then
    result:=d^.terminating
  else
    result:=true; // thread not registered = should terminate
end;

function TThreadContext.Paused:boolean;
var d:PThreadData;
begin
  d:=PThreadData(data);
  if d<>nil then
    result:=d^.paused
  else
    result:=false;
end;

function TThreadContext.Name:String8;
var d:PThreadData;
begin
  d:=PThreadData(data);
  if d<>nil then
    result:=d^.uniqueName
  else
    result:='';
end;

function TThreadContext.ID:TThreadID;
var d:PThreadData;
begin
  d:=PThreadData(data);
  if d<>nil then
    result:=d^.ID
  else
    result:=0;
end;

procedure TThreadContext.SetProgress(p:single);
var d:PThreadData;
begin
  d:=PThreadData(data);
  if (d<>nil) and (d^.implPtr<>nil) then
    TThreadImpl(d^.implPtr).IntSetProgress(p);
end;

procedure TThreadContext.SetStatusText(const txt:String8);
var d:PThreadData;
begin
  d:=PThreadData(data);
  if (d<>nil) and (d^.implPtr<>nil) then
    TThreadImpl(d^.implPtr).IntSetStatusText(txt);
end;

procedure TThreadContext.SetResult(const data:TBytes);
var d:PThreadData;
begin
  d:=PThreadData(self.data);
  if (d<>nil) and (d^.implPtr<>nil) then
    TThreadImpl(d^.implPtr).IntSetResult(data);
end;

procedure TThreadContext.SetObject(obj:TObject);
var d:PThreadData;
begin
  d:=PThreadData(data);
  if (d<>nil) and (d^.implPtr<>nil) then
    TThreadImpl(d^.implPtr).IntSetObject(obj);
end;

procedure TThreadContext.SetError(const msg:String8);
var d:PThreadData;
begin
  d:=PThreadData(data);
  if (d<>nil) and (d^.implPtr<>nil) then
    TThreadImpl(d^.implPtr).IntSetError(msg);
end;

{ TThreadImpl }

constructor TThreadImpl.Create(const aName:String8);
begin
  inherited Create;
  name:=aName;
  status:=TThreadStatus.Running;
  statusTextLock:=0;
  progress:=0;
  resultWritten:=false;
  customObject:=nil;
  keepAlive:=self; // hold self alive while thread is running
end;

destructor TThreadImpl.Destroy;
begin
  customObject.Free; // free unclaimed object (if creator forgot to TakeObject)
  {$IFDEF MSWINDOWS}
  if handle<>0 then
    CloseHandle(handle);
  {$ENDIF}
  inherited;
end;

procedure TThreadImpl.Wait(timeout:cardinal);
begin
  {$IFDEF MSWINDOWS}
  if handle<>0 then
    WaitForSingleObject(handle,timeout);
  {$ELSE}
  // POSIX: use pthread_join (threadID is pthread_t)
  // Note: pthread_join doesn't support timeout, waits indefinitely
  pthread_join(threadID,nil);
  {$ENDIF}
end;

procedure TThreadImpl.Terminate;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(threadID);
    if data<>nil then
      data^.terminating:=true;
  finally
    SpinUnlock;
  end;
end;

procedure TThreadImpl.Kill;
begin
  {$IFDEF MSWINDOWS}
  if handle<>0 then
    TerminateThread(handle,0);
  {$ELSE}
  // POSIX: no safe way to force kill
  raise EError.Create('Kill not supported on this platform');
  {$ENDIF}
end;

procedure TThreadImpl.Pause;
var
  data:PThreadData;
begin
  SpinLock;
  try
    data:=FindThreadData(threadID);
    if data<>nil then
      data^.paused:=not data^.paused; // toggle
  finally
    SpinUnlock;
  end;
end;

function TThreadImpl.GetName:String8;
begin
  result:=name; // cached at creation, valid for entire lifetime
end;

function TThreadImpl.GetID:TThreadID;
begin
  result:=threadID;
end;

function TThreadImpl.IsRunning:boolean;
begin
  result:=status=TThreadStatus.Running;
end;

function TThreadImpl.GetStatus:TThreadStatus;
begin
  result:=status;
end;

function TThreadImpl.GetStatusText:String8;
begin
  while Atomic.CmpExchange(statusTextLock,1,0)<>0 do ; // spinlock acquire
  result:=statusText;
  Atomic.Exchange(statusTextLock,0); // spinlock release
end;

function TThreadImpl.GetProgress:single;
begin
  result:=progress; // 4-byte aligned read, safe without explicit lock
end;

function TThreadImpl.GetResultData:TBytes;
begin
  result:=resultData; // read after status=Finished per convention
end;

function TThreadImpl.TakeObject:TObject;
begin
  result:=customObject;
  customObject:=nil; // clear ref - caller now owns the object
end;

procedure TThreadImpl.IntSetProgress(p:single);
begin
  progress:=p;
end;

procedure TThreadImpl.IntSetStatusText(const txt:String8);
begin
  while Atomic.CmpExchange(statusTextLock,1,0)<>0 do ; // spinlock acquire
  statusText:=txt;
  Atomic.Exchange(statusTextLock,0); // spinlock release
end;

procedure TThreadImpl.IntSetResult(const data:TBytes);
begin
  if resultWritten then begin
    Log.Msg('WARNING: thread %s tried to write result twice',[name]);
    exit;
  end;
  resultData:=data;
  resultWritten:=true;
end;

procedure TThreadImpl.IntSetObject(obj:TObject);
begin
  customObject.Free; // free previous if any (shouldn't happen, but be safe)
  customObject:=obj;
end;

procedure TThreadImpl.IntSetError(const msg:String8);
begin
  IntSetStatusText(msg);
  status:=TThreadStatus.Error; // byte write is atomic on x86/x64
  keepAlive:=nil; // release self-reference
end;

procedure TThreadImpl.IntFinish;
begin
  // write status last: guarantees all prior writes (text, progress, result) are visible
  if status=TThreadStatus.Running then
    status:=TThreadStatus.Finished; // byte write is atomic on x86/x64
  keepAlive:=nil; // release self-reference (may trigger Destroy if creator dropped th1)
end;

{$IFDEF DELPHI}
{ TScopedLock }

class function TScopedLock.Create(ALock:PLock):TScopedLock;
begin
  result.lock:=ALock;
  if ALock<>nil then ALock^.Enter;
end;

class operator TScopedLock.Initialize(out Dest:TScopedLock);
begin
  Dest.lock:=nil;
end;

class operator TScopedLock.Finalize(var Dest:TScopedLock);
begin
  if Dest.lock<>nil then Dest.lock^.Leave;
end;

class operator TScopedLock.Assign(var Dest:TScopedLock; const [ref] Src:TScopedLock);
begin
  // TScopedLock should not be copied - use only as local variable
  raise EError.Create('TScopedLock cannot be assigned');
end;
{$ENDIF}

end.
