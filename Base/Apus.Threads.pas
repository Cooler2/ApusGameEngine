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
   procedure Enter; inline;
   procedure Leave; inline;
   function IsLocked:boolean; inline;
   function GetOwner:TThreadID; inline;
  end;

  // Type aliases for backward compatibility
  TMyCriticalSection=TLock;
  PCriticalSection=PLock;
  TCriticalSection=TLock;
  PCS=PLock;

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

  // Lightweight event using WaitOnAddress (Win10+) or futex (Linux)
  TLightweightEvent=record
  private
   state:integer; // 0=reset, 1=set
  public
   procedure Init;
   procedure SetEvent;
   procedure ResetEvent;
   function WaitFor(timeoutMs:cardinal=INFINITE):boolean;
  end;

  // Thread management scope
  Thread=record
   class procedure Register(const name:string); static;
   class procedure Unregister; static;
   class procedure Ping; static;
   class function GetName(threadID:cardinal=0):string; static;
  end;

  // RAII lock
  TScopedLock = record
    FLock: PLock;
    class function Create(ALock: PLock): TScopedLock; static;
    // Magic of Delphi 10.4+ / FPC 3.2+
    class operator Initialize(out Dest: TScopedLock);
    class operator Finalize(var Dest: TScopedLock);
    class operator Assign(var Dest: TScopedLock; const [ref] Src: TScopedLock);
  end;

 var
  // Enable to check critical section levels to prevent potential deadlocks
  // This slows down critical sections - use carefully
  debugCriticalSections:boolean=false;

 // Critical section management
 // level - used only in debug mode to check for cycles in lock acquisition graph (to prevent deadlocks)
 // It's allowed to enter a section with HIGHER level while already in a section with LOWER level, but not vice versa.
 // Thus, the lower the code level, the HIGHER the level value should be in the section this code operates on
 procedure InitCritSect(var cr:TLock; name:String8; level:integer=100);
 procedure DeleteCritSect(var cr:TCriticalSection);
 procedure EnterCriticalSection(var cr:TLock; caller:pointer=nil);
 procedure LeaveCriticalSection(var cr:TCriticalSection);
 procedure DumpCritSects; // dump state of all critical sections to the log
 procedure CheckCritSections; // check critical sections for timeout

 // Legacy functions for compatibility (use Thread.Register/Unregister/Ping instead)
 procedure RegisterThread(const name:string); deprecated 'Use Thread.Register';
 procedure UnregisterThread; deprecated 'Use Thread.Unregister';
 procedure PingThread; deprecated 'Use Thread.Ping';
 function GetThreadName(threadID:cardinal=0):string; deprecated 'Use Thread.GetName';
 procedure DumpNamedThreads; // dump state of all named threads to the log

 // Utilities
 procedure WaitFor(var p; maxTime:integer=1000000); // wait up to maxTime ms until p<>nil

 // Configuration
implementation
 uses SysUtils, Apus.Conv, Apus.Log
      {$IFDEF UNIX}, unixtype, BaseUnix, Syscall{$ENDIF}
      {$IFDEF IOS}, iphoneAll{$ENDIF}
      {$IFDEF ANDROID}, Apus.Android{$ENDIF};

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
  TThreadInfo=record
   ID:TThreadID;
   name:string;
   pingCounter:integer; // how many times responded
   firstPing:integer;   // time of first response
   lastPing:integer;    // time of last response
   lastCS:PLock;          // last critical section acquired in this thread
   {$IFDEF UNIX}
   tid:cardinal;
   {$ENDIF}
   function GetStateInfo:string; // get thread state (call stack etc)
  end;

 var
  // Global critical section for protecting metadata
  crSection:TRTLCriticalSection;
  // Registry of all critical sections
  crSections:array[1..100] of PLock;
  crSectCount:integer=0;
  // Registry of all named threads
  threads:array of TThreadInfo;
  lastThreadReport:int64; // time of last thread delay report

 // Low-level wrappers for TRTLCriticalSection
 procedure MyEnterCriticalSection(var cr:TRTLCriticalSection); inline;
  begin
   {$IFDEF MSWINDOWS}
    Windows.EnterCriticalSection(cr);
   {$ELSE}
    System.EnterCriticalSection(cr);
   {$ENDIF}
  end;

 procedure MyLeaveCriticalSection(var cr:TRTLCriticalSection); inline;
  begin
   {$IFDEF MSWINDOWS}
    Windows.LeaveCriticalSection(cr);
   {$ELSE}
    System.LeaveCriticalSection(cr);
   {$ENDIF}
  end;

{ TLock }

procedure TLock.Init(const aName:String8; aLevel:integer=100);
 begin
  InitCritSect(self,aName,aLevel);
 end;

procedure TLock.Cleanup;
 begin
  DeleteCritSect(self);
 end;

procedure TLock.Enter;
 begin
  EnterCriticalSection(self);
 end;

procedure TLock.Leave;
 begin
  LeaveCriticalSection(self);
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
  InterlockedIncrement(lockRead);
  if caller=nil then
   lastLockedRead:=Stack.Caller
  else
   lastLockedRead:=caller;
 end;

procedure TSRWLock.LeaveRead;
 begin
  InterlockedDecrement(lockRead);
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
  InterlockedExchange(state,1);
  WakeByAddressSingle(@state);
  {$ELSE}
  InterlockedExchange(state,1);
  // Linux: futex wake - требует syscall, пока упрощенная версия
  {$ENDIF}
 end;

procedure TLightweightEvent.ResetEvent;
 begin
  InterlockedExchange(state,0);
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

class procedure Thread.Register(const name:string);
 begin
  RegisterThread(name);
 end;

class procedure Thread.Unregister;
 begin
  UnregisterThread;
 end;

class procedure Thread.Ping;
 begin
  PingThread;
 end;

class function Thread.GetName(threadID:cardinal=0):string;
 begin
  result:=GetThreadName(threadID);
 end;

// Critical section management

procedure InitCritSect(var cr:TLock; name:String8; level:integer=100);
 begin
  MyEnterCriticalSection(crSection);
  try
  {$IFDEF MSWINDOWS}
   InitializeCriticalSection(cr.crs);
  {$ELSE}
   InitCriticalSection(cr.crs);
  {$ENDIF}
   cr.name:=name;
   cr.caller:=0;
   cr.time:=0;
   cr.lockCount:=0;
   cr.level:=level;
   if crSectCount<length(crSections) then begin
    crSections[crSectCount+1]:=@cr;
    inc(crSectCount);
   end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure DeleteCritSect(var cr:TCriticalSection);
 var
  i:integer;
 begin
  MyEnterCriticalSection(crSection);
  try
   for i:=1 to crSectCount do
    if crSections[i]=@cr then begin
     crSections[i]:=crSections[crSectCount];
     dec(crSectCount);
    end;
   {$IFDEF MSWINDOWS}
   DeleteCriticalSection(cr.crs);
   {$ELSE}
   DoneCriticalSection(cr.crs);
   {$ENDIF}
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure EnterCriticalSection(var cr:TLock; caller:pointer=nil);
 var
  threadID:TThreadID;
  i,lastLevel,trIdx:integer;
  prevSection:PLock;
 begin
  {$IFDEF CPU386}
  if cr.caller=0 then
   if caller=nil then caller:=Stack.Caller;
  {$ENDIF}
  threadID:=GetCurrentThreadID;
  if cr.lockCount>0 then begin
   trIdx:=-1;
   if threadID<>cr.GetOwningThread then begin // from different thread?
    cr.tryingThread:=threadID;
    cr.caller:=PtrUInt(caller);
   end;
   if cr.time=0 then cr.time:=GetTickCount64+5000;
  end else // first attempt
  if debugCriticalSections then begin
   MyEnterCriticalSection(crSection);
   trIdx:=0; prevSection:=nil;
   for i:=0 to high(threads) do
    if threads[i].ID=threadID then begin
     trIdx:=i;
     prevSection:=threads[i].lastCS;
     if prevSection<>nil then lastLevel:=prevSection.level
      else lastLevel:=0;
     break;
    end;
   MyLeaveCriticalSection(crSection);
   if trIdx=0 then raise EFatalError.Create('Trying to enter CS '+cr.name+' from unregistered thread');
   if cr.level<=lastLevel then
    raise EFatalError.Create(Format('Trying to enter CS %s with level %d within section %s with level %d',
      [cr.name,cr.level,prevSection.name,lastLevel]));
  end;

  {$IFDEF MSWINDOWS}
  Windows.EnterCriticalSection(cr.crs);
  {$ELSE}
  System.EnterCriticalSection(cr.crs);
  {$ENDIF}
  {$IFNDEF MSWINDOWS}
  cr.owningThread:=threadID;
  {$ENDIF}
  cr.caller:=0;
  cr.tryingThread:=0;
  cr.time:=0;
  inc(cr.lockCount);
  if caller=nil then caller:=Stack.Caller;
  cr.owner:=UIntPtr(caller);
  if debugCriticalSections and (cr.lockCount=1) then begin
   MyEnterCriticalSection(crSection);
   for i:=0 to high(threads) do
    if threads[i].ID=threadID then begin
     cr.prevSection:=threads[i].lastCS;
     threads[i].lastCS:=@cr;
     break;
    end;
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure LeaveCriticalSection(var cr:TCriticalSection);
 var
  i:integer;
  threadID:TThreadID;
 begin
  ASSERT(cr.LockCount>0);
  cr.caller:=0;
  cr.owner:=0;
  dec(cr.lockCount);
  if debugCriticalSections and (cr.lockCount=0) then begin
   MyEnterCriticalSection(crSection);
   threadID:=GetCurrentThreadID;
   for i:=0 to high(threads) do
    if threads[i].ID=threadID then begin
     if threads[i].lastCS=nil then
      raise EError.Create('Leaving wrong CS: '+cr.name);
     if threads[i].lastCS<>@cr then
      raise EError.Create('Leaving wrong CS: '+cr.name+', should be '+threads[i].lastCS.name);
     threads[i].lastCS:=cr.prevSection;
     break;
    end;
   MyLeaveCriticalSection(crSection);
  end;
  {$IFDEF MSWINDOWS}
  Windows.LeaveCriticalSection(cr.crs);
  {$ELSE}
  System.LeaveCriticalSection(cr.crs);
  {$ENDIF}
 end;

function GetNameOfThread(id:TThreadID):string;
 var
  i:integer;
 begin
  for i:=0 to high(threads) do
   if threads[i].ID=id then begin
    result:=threads[i].name;
    exit;
   end;
  result:='unknown('+inttostr(cardinal(id))+')';
 end;

procedure DumpCritSects;
 var
  i:integer;
  st:string;
  lockedCount:integer;
 begin
  try
  lockedCount:=0;
  MyEnterCriticalSection(crSection);
  try
  st:='';
  for i:=1 to crSectCount do begin
   st:=st+#13#10#32+inttostr(i)+') '+crSections[i].name+' ';
   if crSections[i].lockCount=0 then
    st:=st+'FREE'
   else begin
    inc(lockedCount);
    {$IFDEF MSWINDOWS}
    st:=st+'LOCKED '+inttostr(crSections[i].crs.RecursionCount)+
     ' AT: '+Conv.ToHex(crSections[i].owner,8)+
     ' OWNED BY '+GetNameOfThread(crSections[i].crs.OwningThread);
    {$ELSE}
    st:=st+'LOCKED '+inttostr(crSections[i].lockCount)+
     ' AT: '+Conv.ToHex(crSections[i].owner,8)+
     ' OWNED BY '+GetNameOfThread(crSections[i].owningThread);
    {$ENDIF}
    if crSections[i].caller<>0 then
     st:=st+' PENDING FROM '+GetNameOfThread(crSections[i].tryingThread)+
      ' AT:'+Conv.ToHex(crSections[i].caller,8)+' time '+
      inttostr(GetTickCount64-crSections[i].time);
   end;
  end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
  if lockedCount>0 then
   Log.Force('CRITICAL SECTIONS:'+st);
  except
   on e:Exception do Log.Force('DCS: '+ExceptionMsg(e));
  end;
 end;

procedure CheckCritSections;
 var
  i,t:integer;
 begin
  {$IFDEF MSWINDOWS}
  if IsDebuggerPresent then exit; // prevent termination because of timeout during debug
  {$ENDIF}
  t:=GetTickCount64;
  for i:=1 to crSectCount do begin
   if (crSections[i].time>0) and (crSections[i].time<t) and (crSections[i].time>t-1000000) then begin
    Log.Force('Timeout for: '+crSections[i].name+' thread: '+GetThreadName);
    DumpCritSects;
    sleep(100);
    raise EFatalError.Create('Critical section timeout occured, see log');
   end;
  end;
 end;

// Thread management

procedure RegisterThread(name:string);
 var
  i:integer;
  threadID:TThreadID;
  extra:string;
 begin
  {$IFDEF DELPHI}
  {$IF Declared(TThread.NameThreadForDebugging)}
  TThread.NameThreadForDebugging(name);
  {$ENDIF}
  {$ELSE}
  TThread.NameThreadForDebugging(name);
  {$ENDIF}
  MyEnterCriticalSection(crSection);
  try
   threadID:=GetCurrentThreadId;
   for i:=0 to high(threads) do
    if cardinal(threads[i].ID)=threadID then exit; // already registered
   i:=length(threads);
   SetLength(threads,i+1);
   threads[i].ID:=threadID;
   threads[i].name:=name;
   threads[i].lastCS:=nil;
   {$IFDEF UNIX}
   threads[i].tid:=Do_syscall(syscall_nr_gettid);
   extra:='tid: '+IntToStr(threads[i].tid);
   {$ENDIF}
   Log.Msg('Thread ID: %d named %s %s',[threads[i].ID,name,extra]);
   {$IFDEF ANDROID}
   AndroidInitThread;
   {$ENDIF}
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure UnregisterThread;
 var
  i,n:integer;
  id:TThreadID;
 begin
  id:=GetCurrentThreadID;
  MyEnterCriticalSection(crSection);
  try
   n:=high(threads);
   for i:=0 to n do
    if threads[i].ID=id then begin
     Log.Msg('Thread '+threads[i].name+' unregistered');
     threads[i]:=threads[n];
     SetLength(threads,n);
     {$IFDEF ANDROID}
     AndroidDoneThread;
     {$ENDIF}
     break;
    end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure DumpNamedThreads;
 var
  i:integer;
  st:string;
 begin
  if IsDebuggerPresent then exit;
  try
   MyEnterCriticalSection(crSection);
   try
    for i:=0 to high(threads) do
     st:=st+#13#10'  '+threads[i].GetStateInfo;
   finally
    MyLeaveCriticalSection(crSection);
   end;
   Log.Force('THREADS:'+st);
  except
   on e:Exception do Log.Force('DNT: '+ExceptionMsg(e));
  end;
 end;

procedure PingThread;
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
  MyEnterCriticalSection(crSection);
  try
   for i:=0 to high(threads) do
    if threads[i].id=id then // current thread => update
     with threads[i] do begin
      inc(pingCounter);
      if pingCounter=1 then firstPing:=t;
      lastPing:=t;
     end
    else // other thread => report
    if t>lastThreadReport+1000 then
     with threads[i] do begin
      if pingCounter>0 then begin
       if (t-lastPing>300) then begin
        st:=st+#13#10+'  '+name+' for '+inttostr(t-lastPing);
        if (t-lastPing>1500) then begin
         needDump:=true;
        end;
       end;
      end;
     end;

   if st<>'' then begin
    Log.Force('Threads not responding: '+st);
    lastThreadReport:=t;
   end;
   if needDump then begin
    DumpCritSects;
    DumpNamedThreads;
   end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

function GetThreadName(threadID:cardinal=0):string;
 begin
  if threadID=0 then threadID:=GetCurrentThreadID;
  result:=GetNameOfThread(threadID);
 end;

// Utilities

procedure WaitFor(var p; maxTime:integer);
 var
  t:int64;
 begin
  t:=GetTickCount64+maxTime;
  while (pointer(p)=nil) and (GetTickCount64<t) do Sleep(1);
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
   result:=GetSystemError;
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
   result:=GetSystemError;
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

function TThreadInfo.GetStateInfo: string;
 var
  st:string;
 begin
  result:=Format('%s (%d)',[name,ID]);
  st:=GetThreadStateInfo(ID);
  if st<>'' then result:=result+' '+st;
  if lastCS<>nil then result:=result+Format(' lastCS=%s (%d)',[lastCS.name,lastCS.lockCount]);
 end;

initialization
 {$IFDEF MSWINDOWS}
 InitializeCriticalSection(crSection);
 {$ELSE}
 InitCriticalSection(crSection);
 {$ENDIF}

finalization
 {$IFDEF MSWINDOWS}
 DeleteCriticalSection(crSection);
 {$ELSE}
 DoneCriticalSection(crSection);
 {$ENDIF}
end.
