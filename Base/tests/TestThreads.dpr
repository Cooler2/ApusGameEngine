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
// Worker thread procedures for TThreadFunc overload (function(ctx):UIntPtr)
// ============================================================================

var
  sharedLock:TLock;
  sharedCounter:integer;

// Minimal worker: optionally sets a boolean flag via ctx.Parameter
function SimpleWorker(ctx:TThreadContext):UIntPtr;
begin
  if ctx.Parameter<>nil then
    PBoolean(ctx.Parameter)^:=true;
  result:=0;
end;

// Validates that CurrentThread context is properly initialized inside the thread
function ContextWorker(ctx:TThreadContext):UIntPtr;
begin
  Check(CurrentThread.Name<>'','CurrentThread.Name should work');
  Check(CurrentThread.ID<>0,'CurrentThread.ID should work');
  Check(not CurrentThread.Terminating,'CurrentThread.Terminating should be false initially');
  Check(not CurrentThread.Paused,'CurrentThread.Paused should be false initially');
  result:=0;
end;

// Validates Parameter and Tag fields — both via ctx argument and CurrentThread
function ParamTagWorker(ctx:TThreadContext):UIntPtr;
begin
  Check(ctx.Parameter=pointer(42),'ctx.Parameter should be 42');
  Check(ctx.Tag='hello','ctx.Tag should be "hello"');
  Check(CurrentThread.Parameter=pointer(42),'CurrentThread.Parameter should match');
  Check(CurrentThread.Tag='hello','CurrentThread.Tag should match');
  result:=0;
end;

// Loops until Terminating flag is set; has safety counter to prevent hang
function LongRunningWorker(ctx:TThreadContext):UIntPtr;
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

// Sleeps longer than short Wait timeout to validate timeout behavior.
function SlowWorker(ctx:TThreadContext):UIntPtr;
begin
  Sleep(300);
  result:=0;
end;

// Increments shared counter under lock; used to verify TLock from multiple threads
function IncrementWorker(ctx:TThreadContext):UIntPtr;
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
// Worker for TThreadProc overload (simple procedure, no params)
// ============================================================================
var
  simpleProcExecuted:boolean;

procedure SimpleProcWorker;
begin
  simpleProcExecuted:=true;
end;

// ============================================================================
// Worker for TThreadMethod overload (method of object)
// ============================================================================
type
  TTestObj=class
    executed:boolean;
    procedure Run;
  end;

procedure TTestObj.Run;
begin
  executed:=true;
end;

// ============================================================================
// Worker that reports an error — tests that SetError + finalization works.
// Calls SetError directly (no raise) so the debugger doesn't interfere.
// ============================================================================
procedure ErrorWorker;
begin
  CurrentThread.SetError('deliberate test error');
end;

// Worker with unhandled exception — tests that finally block in ThreadStartWrapper
// still runs (UnregisterThread + IntFinish) even when user code raises.
// Note: with Delphi debugger "break on exception" enabled, execution pauses here.
// If you continue slowly, th.Wait(2000) in TestThreadException may timeout while
// thread is paused, so Status can still be Running and the check may fail.
// If you continue quickly, wrapper catches exception and sets Status=Error as expected.
procedure RaisingWorker;
begin
  raise Exception.Create('deliberate unhandled exception');
end;

// ============================================================================
// Tests
// ============================================================================

// Basic Init/Enter/Leave/Cleanup cycle on a single thread.
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

// TLock supports recursive locking: must Leave the same number of times as Enter.
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

// GetOwner returns the thread ID that holds the lock.
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

// Register/Unregister for external (non-Thread.Start) threads, e.g. main thread.
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

// WaitUntilNotNil: returns immediately if pointer is set, raises on timeout.
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

// Same as TestLockBasic but using a differently-named lock (redundant, kept for coverage).
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

// TThreadFunc overload: pass pointer parameter, verify thread executes and Wait returns.
procedure TestThreadStart;
var
  th:IThread;
  executed:boolean;
  startTime:int64;
begin
  StartTest('Thread.Start(TThreadFunc) and IThread.Wait');

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

// Verify CurrentThread threadvar is properly set inside the thread procedure.
// Checks Name, ID, Terminating, Paused — all should have valid initial values.
procedure TestCurrentThreadContext;
var
  th:IThread;
begin
  StartTest('CurrentThread context');

  th:=Thread.Start('ContextTest',TThreadFunc(@ContextWorker));
  th.Wait(1000);

  EndTest;
end;

// Verify Parameter (pointer) and Tag (string) are delivered to TThreadContext.
// Both ctx argument and CurrentThread threadvar must see the same values.
procedure TestParamAndTag;
var
  th:IThread;
begin
  StartTest('Thread.Start parameter and tag');

  th:=Thread.Start('ParamTag',@ParamTagWorker,pointer(42),'hello');
  th.Wait(1000);

  EndTest;
end;

// TThreadProc overload: simple procedure with no parameters.
// Needs explicit TThreadProc(@...) cast because FPC can't disambiguate @proc alone.
procedure TestStartProc;
var
  th:IThread;
begin
  StartTest('Thread.Start(TThreadProc)');

  simpleProcExecuted:=false;
  th:=Thread.Start('ProcWorker',TThreadProc(@SimpleProcWorker));
  th.Wait(1000);
  Check(simpleProcExecuted,'Simple procedure should execute');

  EndTest;
end;

// TThreadMethod overload: pass an object method directly (no @ needed).
// Object must outlive the thread — here we Wait before Free.
procedure TestStartMethod;
var
  th:IThread;
  obj:TTestObj;
begin
  StartTest('Thread.Start(TThreadMethod)');

  obj:=TTestObj.Create;
  try
    th:=Thread.Start('MethodWorker',obj.Run);
    th.Wait(1000);
    Check(obj.executed,'Object method should execute');
  finally
    obj.Free;
  end;

  EndTest;
end;

// Terminate sets a flag that the thread polls via CurrentThread.Terminating.
// Thread should exit promptly (within one Sleep cycle).
procedure TestThreadTermination;
var
  th:IThread;
  startTime:int64;
begin
  StartTest('IThread.Terminate');

  th:=Thread.Start('TermTest',TThreadFunc(@LongRunningWorker));
  Sleep(50); // let thread start

  startTime:=GetTickCount64;
  th.Terminate;
  th.Wait(1000);
  Check(GetTickCount64-startTime<500,'Thread should terminate quickly after Terminate call');

  EndTest;
end;

// Wait(timeout) should return on timeout without forcing completion.
// A later full wait must observe normal Finished status.
procedure TestThreadWaitTimeout;
var
  th:IThread;
  startTime,elapsed:int64;
begin
  StartTest('IThread.Wait timeout');

  th:=Thread.Start('WaitTimeout',TThreadFunc(@SlowWorker));
  startTime:=GetTickCount64;
  th.Wait(20); // intentionally short timeout
  elapsed:=GetTickCount64-startTime;
  Check(elapsed<200,'Wait(timeout) should return near timeout, not block until completion');
  Check(th.Status=TThreadStatus.Running,'Thread should still be running after short timeout');

  th.Wait(2000);
  Check(th.Status=TThreadStatus.Finished,'Thread should finish after full wait');

  EndTest;
end;

// 3 threads increment shared counter 100 times each under a TLock.
// Final counter must be exactly 300 — any miss means lock is broken.
procedure TestMultithreadedLock;
var
  th1,th2,th3:IThread;
begin
  StartTest('TLock from multiple threads');

  sharedLock.Init('SharedLock',100);
  sharedCounter:=0;

  // Start 3 threads, each increments counter 100 times
  th1:=Thread.Start('Worker1',TThreadFunc(@IncrementWorker));
  th2:=Thread.Start('Worker2',TThreadFunc(@IncrementWorker));
  th3:=Thread.Start('Worker3',TThreadFunc(@IncrementWorker));

  th1.Wait;
  th2.Wait;
  th3.Wait;

  Check(sharedCounter=300,'Counter should be 300 with proper locking');

  sharedLock.Cleanup;

  EndTest;
end;

// Name patterns: plain name preserved as-is, % pattern auto-increments (Worker1, Worker2...).
procedure TestThreadNames;
var
  th1,th2,th3:IThread;
  name1,name2,name3:string;
begin
  StartTest('Thread name patterns');

  // Simple name
  th1:=Thread.Start('SimpleName',TThreadFunc(@SimpleWorker));
  Sleep(10); // wait for thread registration
  name1:=th1.Name;
  Check(name1='SimpleName','Simple name should be preserved');

  // Pattern % - auto-increment
  th2:=Thread.Start('Worker%',TThreadFunc(@SimpleWorker));
  th3:=Thread.Start('Worker%',TThreadFunc(@SimpleWorker));
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

// Test # pattern: name numbers are reused after thread finishes and unregisters.
// Both th1 and th2 must be fully finished (Wait) before starting th3,
// otherwise their names are still in the registry and won't be reused.
procedure TestThreadNamesReuse;
var
  th1,th2,th3:IThread;
  name1,name2,name3:string;
  i:integer;
begin
  StartTest('Thread name # pattern (reuse)');

  // start two threads — get Task1 and Task2
  th1:=Thread.Start('Task#',TThreadFunc(@SimpleWorker));
  th2:=Thread.Start('Task#',TThreadFunc(@SimpleWorker));
  Sleep(10);
  name1:=th1.Name;
  name2:=th2.Name;
  Check(name1='Task1','First # pattern should be Task1');
  Check(name2='Task2','Second # pattern should be Task2');

  // Wait for BOTH threads to fully finish and unregister
  th1.Wait(2000);
  th2.Wait(2000);

  // start new thread — should reuse Task1 (smallest free)
  th3:=Thread.Start('Task#',TThreadFunc(@SimpleWorker));
  Sleep(10);
  name3:=th3.Name;
  Check(name3='Task1','After both finish, Task1 should be reused');

  th3.Wait;

  EndTest;
end;

// Verify that thread status transitions to Finished after Wait.
// This is a fundamental invariant: if Wait returns, the thread must be done.
// Tests all callable overloads to ensure none leaves status stuck at Running.
procedure TestThreadFinalization;
var
  th:IThread;
  executed:boolean;
  obj:TTestObj;
begin
  StartTest('Thread finalization');

  // TThreadFunc overload
  executed:=false;
  th:=Thread.Start('FinFunc',@SimpleWorker,@executed);
  th.Wait(2000);
  Check(executed,'TThreadFunc: should have executed');
  Check(th.Status=TThreadStatus.Finished,'TThreadFunc: status should be Finished');

  // TThreadProc overload
  simpleProcExecuted:=false;
  th:=Thread.Start('FinProc',TThreadProc(@SimpleProcWorker));
  th.Wait(2000);
  Check(simpleProcExecuted,'TThreadProc: should have executed');
  Check(th.Status=TThreadStatus.Finished,'TThreadProc: status should be Finished');

  // TThreadMethod overload
  obj:=TTestObj.Create;
  try
    th:=Thread.Start('FinMethod',obj.Run);
    th.Wait(2000);
    Check(obj.executed,'TThreadMethod: should have executed');
    Check(th.Status=TThreadStatus.Finished,'TThreadMethod: status should be Finished');
  finally
    obj.Free;
  end;

  EndTest;
end;

// Verify that SetError inside a thread sets Error status and thread still finalizes.
// Pattern: catch exception in worker, call CurrentThread.SetError, let thread exit.
// After Wait, creator sees Status=Error (not Running or Finished).
procedure TestThreadException;
var
  th:IThread;
  st:TThreadStatus;
begin
  StartTest('Thread exception handling');

  th:=Thread.Start('ErrorTest',TThreadProc(@ErrorWorker));
  th.Wait(2000);
  st:=th.Status;
  Check(st<>TThreadStatus.Running,'SetError: should not be running after Wait');
  Check(st=TThreadStatus.Error,'SetError: status should be Error');

  // Unhandled exception: wrapper catches it and calls SetError automatically
  // Under Delphi IDE with break-on-exception, debugger pause time affects this:
  // long pause can make Wait(5000) timeout before thread resumes and sets Error.
  th:=Thread.Start('RaiseTest',TThreadProc(@RaisingWorker));
  th.Wait(5000);
  st:=th.Status;
  Check(st=TThreadStatus.Error,'Unhandled raise: status should be Error');

  EndTest;
end;

begin
  try
    writeln('=== Testing Apus.Threads ===');
    writeln;

    // Thread finalization (run first to catch fundamental issues)
    TestThreadFinalization;
    TestThreadException;

    // Lock tests
    TestLockBasic;
    TestLockRecursive;
    TestLockOwner;
    TestCritSectFunctions;

    // Thread management tests
    TestThreadRegistration;
    TestThreadStart;
    TestCurrentThreadContext;
    TestParamAndTag;
    TestStartProc;
    TestStartMethod;
    TestThreadTermination;
    TestThreadWaitTimeout;

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
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
