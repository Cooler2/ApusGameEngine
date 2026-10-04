// TWindow cross-thread entry: Lock/Unlock (reentrancy, `window` context), QueueCall,
// Acquire/Release and the close protocol (BeginClose, WaitReleased). No native window:
// only the platform-independent part of TWindow is used.
{$APPTYPE CONSOLE}
program TestWindowLock;
uses
  SysUtils,
  Apus.Core,
  Apus.Threads,
  Apus.Engine.API,
  Apus.Engine.Window;

{$I ..\Base\tests\Test.inc}

type
  TCounter=class
    count:integer;
    procedure Increment;
  end;

var
  callCount:integer;
  queueTarget:TWindow; // window the re-queueing call adds to
  workerWnd:TWindow;
  workerState:integer;
  workerSawWindow,workerRestored,workerLockResult:boolean;

procedure TCounter.Increment;
 begin
  inc(count);
 end;

procedure CountCall(param:pointer);
 begin
  inc(PInteger(param)^);
 end;

procedure FailingCall(param:pointer);
 begin
  raise Exception.Create('expected test failure');
 end;

procedure RequeueCall(param:pointer);
 begin
  inc(callCount);
  queueTarget.QueueCall(CountCall,@callCount);
 end;

procedure ContextCall(param:pointer);
 begin
  PBoolean(param)^:=window=queueTarget;
 end;

function NewWindow(const name:String8):TWindow;
 begin
  {$WARN 4046 OFF} // constructing a class with abstract methods: they are never called here
  result:=TWindow.Create(name);
  {$WARN 4046 ON}
 end;

procedure TestLockContext;
 var
  w1,w2:TWindow;
 begin
  StartTest('Lock: reentrancy and window context');
  w1:=NewWindow('W1');
  w2:=NewWindow('W2');
  window:=nil;
  Check(w1.Lock,'first Lock succeeds');
  Check(window=w1,'Lock sets the window context');
  Check(w1.Lock,'nested Lock succeeds');
  w1.Unlock;
  Check(window=w1,'inner Unlock keeps the context');
  Check(w2.Lock,'Lock of another window succeeds');
  Check(window=w2,'context follows the innermost window');
  w2.Unlock;
  Check(window=w1,'Unlock restores the previous context');
  w1.Unlock;
  Check(window=nil,'last Unlock restores the original context');
  w1.Unlock; // tolerant: no matching Lock
  Check(window=nil,'extra Unlock does nothing');
  Check(w1.WaitReleased(0),'Lock reference is released');
  w2.Free;
  w1.Free;
  EndTest;
 end;

procedure TestQueueCall;
 var
  w:TWindow;
  counter:TCounter;
  n:integer;
  inContext:boolean;
 begin
  StartTest('QueueCall');
  w:=NewWindow('Calls');
  counter:=TCounter.Create;
  n:=0;
  Check(w.QueueCall(CountCall,@n),'procedure call is accepted');
  Check(w.QueueCall(counter.Increment),'method call is accepted');
  Check(w.QueueCall(FailingCall),'failing call is accepted');
  Check(w.QueueCall(CountCall,@n),'call after the failing one is accepted');
  Check(n=0,'nothing runs before RunQueuedCalls');
  w.RunQueuedCalls;
  Check(n=2,'procedure calls ran once each, failure did not stop the rest');
  Check(counter.count=1,'method call ran once');
  w.RunQueuedCalls;
  Check(n=2,'calls do not run twice');

  // a call queued while the queue runs belongs to the next run
  callCount:=0;
  queueTarget:=w;
  w.QueueCall(RequeueCall);
  w.RunQueuedCalls;
  Check(callCount=1,'call queued during the run is postponed');
  w.RunQueuedCalls;
  Check(callCount=2,'postponed call runs on the next run');

  // queued calls run in the window's context only when the runner is in it: the engine
  // runs them on the window's own thread; here it's the test thread with no context
  inContext:=true;
  window:=nil;
  w.QueueCall(ContextCall,@inContext);
  w.RunQueuedCalls;
  Check(not inContext,'RunQueuedCalls does not switch the context');

  counter.Free;
  w.Free;
  EndTest;
 end;

procedure TestClose;
 var
  w:TWindow;
  n:integer;
 begin
  StartTest('Close protocol');
  w:=NewWindow('Closing');
  n:=0;
  Check(w.Acquire,'Acquire before closing');
  Check(w.QueueCall(CountCall,@n),'call queued before closing');
  w.BeginClose;
  Check(w.closing,'closing is set');
  Check(not w.Acquire,'Acquire fails while closing');
  Check(not w.Lock,'Lock fails while closing');
  window:=nil;
  w.Unlock; // tolerant after a failed Lock
  Check(window=nil,'failed Lock leaves the context');
  Check(not w.QueueCall(CountCall,@n),'QueueCall fails while closing');
  w.RunQueuedCalls;
  Check(n=1,'call accepted before closing still runs');
  Check(not w.WaitReleased(20),'WaitReleased waits for Acquire references');
  w.Release;
  Check(w.WaitReleased(0),'released after Release');
  w.Free;
  EndTest;
 end;

procedure Worker;
 begin
  window:=nil;
  if workerWnd.Lock then begin
   workerSawWindow:=window=workerWnd;
   workerWnd.Unlock;
   workerRestored:=window=nil;
  end;
  Atomic.Exchange(workerState,1);
 end;

procedure BlockedWorker;
 begin
  Atomic.Exchange(workerState,1);
  workerLockResult:=workerWnd.Lock; // blocks: the test thread holds the state lock
  if workerLockResult then workerWnd.Unlock;
  Atomic.Exchange(workerState,2);
 end;

procedure TestWorkerThread;
 var
  th:IThread;
 begin
  StartTest('Lock from a worker thread');
  workerWnd:=NewWindow('Worker');
  workerState:=0;
  workerSawWindow:=false;
  workerRestored:=false;
  th:=Thread.Start('WndLockWorker',TThreadProc(@Worker));
  th.Wait(2000);
  Check(workerState=1,'worker finished');
  Check(workerSawWindow,'worker gets the window context');
  Check(workerRestored,'worker context restored');
  Check(workerWnd.WaitReleased(0),'worker released the window');

  // closing while a worker waits for the lock: Lock must fail and hold nothing
  workerState:=0;
  workerLockResult:=true;
  workerWnd.LockState;
  th:=Thread.Start('WndLockBlocked',TThreadProc(@BlockedWorker));
  while Atomic.CmpExchange(workerState,1,1)<>1 do Sleep(1);
  Sleep(50); // let it reach Lock
  workerWnd.BeginClose;
  workerWnd.UnlockState;
  th.Wait(2000);
  Check(workerState=2,'blocked worker finished');
  Check(not workerLockResult,'Lock fails when the window started closing meanwhile');
  Check(workerWnd.WaitReleased(0),'failed Lock holds no reference');
  workerWnd.Free;
  EndTest;
 end;

begin
  TestLockContext;
  TestQueueCall;
  TestClose;
  TestWorkerThread;
  if IsDebuggerPresent then readln;
end.
