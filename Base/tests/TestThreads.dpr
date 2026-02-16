{$APPTYPE CONSOLE}
program TestThreads;
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  Apus.Core,
  Apus.Threads;

{$INCLUDE Test.inc}

// ============================================================================
// Worker thread procedures
// ============================================================================

var
  sharedLock:TLock;
  sharedCounter:integer;

function SimpleWorker(param:pointer):UIntPtr;
begin
  if param<>nil then
    PBoolean(param)^:=true;
  result:=0;
end;

function ContextWorker(param:pointer):UIntPtr;
begin
  Check(CurrentThread.Name<>'','CurrentThread.Name should work');
  Check(CurrentThread.ID<>0,'CurrentThread.ID should work');
  Check(not CurrentThread.Terminating,'CurrentThread.Terminating should be false initially');
  Check(not CurrentThread.Paused,'CurrentThread.Paused should be false initially');
  result:=0;
end;

function LongRunningWorker(param:pointer):UIntPtr;
var
  counter:integer;
begin
  counter:=0;
  while not CurrentThread.Terminating do begin
    Sleep(10);
    inc(counter);
    if counter>100 then break; // safety timeout
  end;
  result:=0;
end;

function IncrementWorker(param:pointer):UIntPtr;
var
  i:integer;
begin
  for i:=1 to 100 do begin
    sharedLock.Enter;
    try
      inc(sharedCounter);
    finally
      sharedLock.Leave;
    end;
    if i mod 10=0 then Sleep(1); // yield occasionally
  end;
  result:=0;
end;

// ============================================================================
// Tests
// ============================================================================

procedure TestLockBasic;
var
  lock:TLock;
begin
  StartTest('TLock basic operations');

  // Init
  lock.Init('TestLock',100);
  Check(not lock.IsLocked,'Lock should not be locked after Init');

  // Enter/Leave
  lock.Enter;
  Check(lock.IsLocked,'Lock should be locked after Enter');
  lock.Leave;
  Check(not lock.IsLocked,'Lock should not be locked after Leave');

  // Cleanup
  lock.Cleanup;

  EndTest;
end;

procedure TestLockRecursive;
var
  lock:TLock;
begin
  StartTest('TLock recursive locking');

  lock.Init('RecursiveLock',100);

  // Enter multiple times
  lock.Enter;
  Check(lock.IsLocked,'Lock should be locked (1st Enter)');
  lock.Enter;
  Check(lock.IsLocked,'Lock should be locked (2nd Enter)');
  lock.Enter;
  Check(lock.IsLocked,'Lock should be locked (3rd Enter)');

  // Leave the same number of times
  lock.Leave;
  Check(lock.IsLocked,'Lock still locked after 1st Leave');
  lock.Leave;
  Check(lock.IsLocked,'Lock still locked after 2nd Leave');
  lock.Leave;
  Check(not lock.IsLocked,'Lock unlocked after 3rd Leave');

  lock.Cleanup;

  EndTest;
end;

procedure TestLockOwner;
var
  lock:TLock;
  owner:TThreadID;
begin
  StartTest('TLock owner tracking');

  lock.Init('OwnerLock',100);

  lock.Enter;
  owner:=lock.GetOwner;
  Check(owner=GetCurrentThreadID,'Owner should be current thread');
  lock.Leave;

  lock.Cleanup;

  EndTest;
end;

procedure TestThreadRegistration;
var
  name:string;
begin
  StartTest('Thread registration');

  // Register main thread
  Thread.Register('MainThread');
  name:=Thread.GetName;
  Check(Pos('MainThread',name)>0,'Thread name should contain "MainThread"');

  // GetName by ID
  name:=Thread.GetName(GetCurrentThreadID);
  Check(Pos('MainThread',name)>0,'GetName by ID should work');

  // Unregister
  Thread.Unregister;

  EndTest;
end;

procedure TestWaitFor;
var
  p:pointer;
  startTime:int64;
begin
  StartTest('WaitFor utility');

  // Wait for already set pointer (should not wait)
  p:=pointer(1);
  startTime:=GetTickCount64;
  Thread.WaitUntilNotNil(p,100);
  Check(GetTickCount64-startTime<50,'WaitUntilNotNil should not wait if pointer is set');

  // Wait for nil pointer with timeout (should timeout and raise exception)
  p:=nil;
  startTime:=GetTickCount64;
  try
   Thread.WaitUntilNotNil(p,50);
   Check(false,'WaitUntilNotNil should raise exception on timeout');
  except
   // expected exception
  end;
  Check(GetTickCount64-startTime>=40,'WaitUntilNotNil should wait for timeout');

  EndTest;
end;

{$IF Declared(SRWLOCK)}
procedure TestSRWLock;
var
  lock:TSRWLock;
begin
  StartTest('TSRWLock (Windows)');

  lock.Init('TestSRW');

  // Read lock
  lock.EnterRead;
  lock.LeaveRead;

  // Write lock
  lock.EnterWrite;
  lock.LeaveWrite;

  // Multiple readers
  lock.EnterRead;
  lock.EnterRead;
  lock.LeaveRead;
  lock.LeaveRead;

  lock.Cleanup;

  EndTest;
end;
{$ENDIF}

procedure TestLightweightEvent;
var
  event:TLightweightEvent;
  startTime:int64;
begin
  StartTest('TLightweightEvent');

  event.Init;

  // Initially reset
  event.ResetEvent;
  startTime:=GetTickCount64;
  Check(not event.WaitFor(50),'WaitFor should timeout on reset event');
  Check(GetTickCount64-startTime>=40,'WaitFor should wait for timeout');

  // Set and wait
  event.SetEvent;
  startTime:=GetTickCount64;
  Check(event.WaitFor(100),'WaitFor should succeed on set event');
  Check(GetTickCount64-startTime<50,'WaitFor should not wait if event is set');

  EndTest;
end;

procedure TestCritSectFunctions;
var
  cs:TLock;
begin
  StartTest('TLock methods');

  // Init/Cleanup
  cs.Init('TestCS',100);
  Check(not cs.IsLocked,'CS should not be locked after Init');

  // Enter/Leave
  cs.Enter;
  Check(cs.IsLocked,'CS should be locked after Enter');
  cs.Leave;
  Check(not cs.IsLocked,'CS should not be locked after Leave');

  cs.Cleanup;

  EndTest;
end;

procedure TestThreadStart;
var
  th:IThread;
  executed:boolean;
  startTime:int64;
begin
  StartTest('Thread.Start and IThread.Wait');

  executed:=false;
  th:=Thread.Start('TestWorker',@SimpleWorker,@executed);
  Check(th<>nil,'Thread.Start should return IThread');

  // Wait should block until thread finishes
  startTime:=GetTickCount64;
  th.Wait(1000);
  Check(executed,'Thread should execute');
  Check(GetTickCount64-startTime<500,'Wait should complete quickly for simple thread');

  EndTest;
end;

procedure TestCurrentThreadContext;
var
  th:IThread;
begin
  StartTest('CurrentThread context');

  th:=Thread.Start('ContextTest',@ContextWorker,nil);
  th.Wait(1000);

  EndTest;
end;

procedure TestThreadTermination;
var
  th:IThread;
  startTime:int64;
begin
  StartTest('IThread.Terminate');

  th:=Thread.Start('TermTest',@LongRunningWorker,nil);
  Sleep(50); // let thread start

  startTime:=GetTickCount64;
  th.Terminate;
  th.Wait(1000);
  Check(GetTickCount64-startTime<500,'Thread should terminate quickly after Terminate call');

  EndTest;
end;

procedure TestMultithreadedLock;
var
  th1,th2,th3:IThread;
begin
  StartTest('TLock from multiple threads');

  sharedLock.Init('SharedLock',100);
  sharedCounter:=0;

  // Start 3 threads, each increments counter 100 times
  th1:=Thread.Start('Worker1',@IncrementWorker,nil);
  th2:=Thread.Start('Worker2',@IncrementWorker,nil);
  th3:=Thread.Start('Worker3',@IncrementWorker,nil);

  th1.Wait;
  th2.Wait;
  th3.Wait;

  Check(sharedCounter=300,'Counter should be 300 with proper locking');

  sharedLock.Cleanup;

  EndTest;
end;

procedure TestThreadNames;
var
  th1,th2,th3:IThread;
  name1,name2,name3:string;
begin
  StartTest('Thread name patterns');

  // Simple name
  th1:=Thread.Start('SimpleName',@SimpleWorker,nil);
  Sleep(10); // wait for thread registration
  name1:=th1.Name;
  Check(name1='SimpleName','Simple name should be preserved');

  // Pattern % - auto-increment
  th2:=Thread.Start('Worker%',@SimpleWorker,nil);
  Sleep(10);
  th3:=Thread.Start('Worker%',@SimpleWorker,nil);
  Sleep(10);
  name2:=th2.Name;
  name3:=th3.Name;
  Check(name2='Worker1','First % pattern should be Worker1');
  Check(name3='Worker2','Second % pattern should be Worker2');

  th1.Wait;
  th2.Wait;
  th3.Wait;

  EndTest;
end;

procedure TestThreadNamesReuse;
var
  th1,th2,th3:IThread;
  name1,name2,name3:string;
begin
  StartTest('Thread name # pattern (reuse)');

  // Pattern # - smallest free number
  th1:=Thread.Start('Task#',@SimpleWorker,nil);
  Sleep(10);
  th2:=Thread.Start('Task#',@SimpleWorker,nil);
  Sleep(10);
  name1:=th1.Name;
  name2:=th2.Name;
  Check(name1='Task1','First # pattern should be Task1');
  Check(name2='Task2','Second # pattern should be Task2');

  // Wait for first thread to finish
  th1.Wait;

  // Start new thread - should reuse Task1
  th3:=Thread.Start('Task#',@SimpleWorker,nil);
  Sleep(10);
  name3:=th3.Name;
  Check(name3='Task1','After Task1 finishes, name should be reused');

  th2.Wait;
  th3.Wait;

  EndTest;
end;

begin
  try
    writeln('=== Testing Apus.Threads ===');
    writeln;

    // Lock tests
    TestLockBasic;
    TestLockRecursive;
    TestLockOwner;
    TestCritSectFunctions;

    // Thread management tests
    TestThreadRegistration;
    TestThreadStart;
    TestCurrentThreadContext;
    TestThreadTermination;

    // Thread naming tests
    TestThreadNames;
    TestThreadNamesReuse;

    // Multithreading tests
    TestMultithreadedLock;

    // Platform-specific tests
    {$IF Declared(SRWLOCK)}
    TestSRWLock;
    {$ENDIF}
    TestLightweightEvent;

    // Utility tests
    TestWaitFor;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
