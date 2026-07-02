{$APPTYPE CONSOLE}
program TestEventMan;
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Log,
  Apus.Threads,
  Apus.EventMan;

{$INCLUDE Test.inc}

const
  MTHandlerCount=8;

var
  eventReceived:string;
  tagReceived:TTag;
  eventCount:integer;
  mtHitMask:cardinal;
  mtHitCount:integer;
  mtStartRegistration:boolean;
  mtDuplicateCount:integer;
  mtQueuedReadyCount:integer;
  mtQueuedHandlerCalls:integer;
  mtQueuedStart:boolean;
  mtQueuedDoneCount:integer;
  mtThreadIDs:array[1..MTHandlerCount] of TThreadIdent;
  mtQueuedHitByThread:array[1..MTHandlerCount] of boolean;
  mtQueuedLock:TLock;
  danglingWarning:boolean;

procedure ResetCounters;
begin
  eventReceived:='';
  tagReceived:=0;
  eventCount:=0;
end;

procedure TestHandler(event:TEventStr;tag:TTag);
begin
  eventReceived:=event;
  tagReceived:=tag;
  inc(eventCount);
end;

procedure TestHandlerQueued(event:TEventStr;tag:TTag);
begin
  eventReceived:=event;
  tagReceived:=tag;
  inc(eventCount);
end;

procedure DanglingLogHandler(msg:String8;category:byte;level:TSeverity);
begin
  if (level=TSeverity.Warn) and
     (Pos('mt\dangling -> ',LowerCase(string(msg)))>0) then
    danglingWarning:=true;
end;

procedure RegisterDanglingWorker;
begin
  SetEventHandler('MT\Dangling',TestHandlerQueued,emQueued);
end;

procedure MTHandler1(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 1; end;
procedure MTHandler2(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 2; end;
procedure MTHandler3(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 4; end;
procedure MTHandler4(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 8; end;
procedure MTHandler5(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 16; end;
procedure MTHandler6(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 32; end;
procedure MTHandler7(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 64; end;
procedure MTHandler8(event:TEventStr;tag:TTag); begin inc(mtHitCount); mtHitMask:=mtHitMask or 128; end;
procedure MTDuplicateHandler(event:TEventStr;tag:TTag); begin inc(mtDuplicateCount); end;
procedure MTQueuedSharedHandler(event:TEventStr;tag:TTag);
var
  i:integer;
  id:TThreadIdent;
begin
  id:=GetCurrentThreadID;
  mtQueuedLock.Enter;
  try
    inc(mtQueuedHandlerCalls);
    for i:=1 to MTHandlerCount do
      if mtThreadIDs[i]=id then begin
        mtQueuedHitByThread[i]:=true;
        break;
      end;
  finally
    mtQueuedLock.Leave;
  end;
end;

function RegisterWorker(ctx:TThreadContext):UIntPtr;
var
  idx:NativeInt;
begin
  while not mtStartRegistration do
    CoreTime.Sleep(1);
  idx:=NativeInt(ctx.Parameter);
  case idx of
    1:SetEventHandler('MT\Signal',MTHandler1);
    2:SetEventHandler('MT\Signal',MTHandler2);
    3:SetEventHandler('MT\Signal',MTHandler3);
    4:SetEventHandler('MT\Signal',MTHandler4);
    5:SetEventHandler('MT\Signal',MTHandler5);
    6:SetEventHandler('MT\Signal',MTHandler6);
    7:SetEventHandler('MT\Signal',MTHandler7);
    8:SetEventHandler('MT\Signal',MTHandler8);
  end;
  result:=0;
end;

function RegisterSameWorker(ctx:TThreadContext):UIntPtr;
begin
  while not mtStartRegistration do
    CoreTime.Sleep(1);
  SetEventHandler('MT\Duplicate',MTDuplicateHandler);
  result:=0;
end;

function RegisterQueuedSameWorker(ctx:TThreadContext):UIntPtr;
var
  idx:NativeInt;
  k:integer;
begin
  idx:=NativeInt(ctx.Parameter);
  mtQueuedLock.Enter;
  try
    mtThreadIDs[idx]:=GetCurrentThreadID;
  finally
    mtQueuedLock.Leave;
  end;
  SetEventHandler('MT\QueuedPerThread',MTQueuedSharedHandler,emQueued);
  // mark ready only AFTER the handler is registered, otherwise the main thread
  // may Signal before this thread's queued handler exists (race), so the
  // event would never be enqueued for this thread
  mtQueuedLock.Enter;
  try
    inc(mtQueuedReadyCount);
  finally
    mtQueuedLock.Leave;
  end;
  while not mtQueuedStart do
    CoreTime.Sleep(1);
  for k:=1 to 300 do begin
    HandleSignals;
    mtQueuedLock.Enter;
    try
      if mtQueuedHitByThread[idx] then break;
    finally
      mtQueuedLock.Leave;
    end;
    CoreTime.Sleep(1);
  end;
  mtQueuedLock.Enter;
  try
    inc(mtQueuedDoneCount);
  finally
    mtQueuedLock.Leave;
  end;
  result:=0;
end;

procedure TestBasicSignal;
begin
  StartTest('Basic Signal');
  ResetCounters;
  SetEventHandler('Test\Event1',TestHandler);
  Signal('Test\Event1',123);
  Check(eventReceived='Test\Event1','event name');
  Check(tagReceived=123,'tag value');
  Check(eventCount=1,'event count');
  RemoveEventHandler(TestHandler);
  EndTest;
end;

procedure TestMultipleHandlers;
begin
  StartTest('Multiple handlers');
  ResetCounters;
  SetEventHandler('Test\Event2',TestHandler);
  SetEventHandler('Test',TestHandler); // parent event
  Signal('Test\Event2',456);
  Check(eventCount=2,'both handlers called'); // child + parent
  Check(tagReceived=456,'tag preserved');
  RemoveEventHandler(TestHandler);
  EndTest;
end;

procedure TestLink;
begin
  StartTest('Link events');
  ResetCounters;
  SetEventHandler('Linked\Target',TestHandler);
  Link('Test\Source','Linked\Target',789);
  Signal('Test\Source',0);
  Check(eventReceived='Linked\Target','linked event received');
  Check(tagReceived=789,'linked tag');
  Unlink('Test\Source','Linked\Target');
  RemoveEventHandler(TestHandler);
  EndTest;
end;

procedure TestQueuedEvents;
begin
  StartTest('Queued events');
  ResetCounters;
  SetEventHandler('Queue\Test',TestHandlerQueued,emQueued);
  Signal('Queue\Test',111);
  Check(eventCount=0,'not processed immediately');
  HandleSignals;
  Check(eventCount=1,'processed after HandleSignals');
  Check(eventReceived='Queue\Test','queued event name');
  Check(tagReceived=111,'queued tag');
  RemoveEventHandler(TestHandlerQueued);
  EndTest;
end;

procedure TestDelayedSignal;
begin
  StartTest('Delayed signal');
  ResetCounters;
  SetEventHandler('Delay\Test',TestHandler,emQueued);
  DelayedSignal('Delay\Test',50,222); // 50ms delay
  HandleSignals;
  Check(eventCount=0,'not processed immediately');
  CoreTime.Sleep(100); // wait for delay
  HandleSignals;
  Check(eventCount=1,'processed after delay');
  Check(tagReceived=222,'delayed tag');
  RemoveEventHandler(TestHandler);
  EndTest;
end;

procedure TestPackTag;
begin
  StartTest('PackTag/ByteFromTag');
  Check(PackTag(1,2,3,4)=67305985,'PackTag(1,2,3,4)');
  Check(ByteFromTag(67305985,0)=1,'ByteFromTag byte0');
  Check(ByteFromTag(67305985,1)=2,'ByteFromTag byte1');
  Check(ByteFromTag(67305985,2)=3,'ByteFromTag byte2');
  Check(ByteFromTag(67305985,3)=4,'ByteFromTag byte3');
  Check(PackTag(word($1234),word($5678))=$56781234,'PackTag words');
  Check(WordFromTag($56781234,0)=$1234,'WordFromTag word0');
  Check(WordFromTag($56781234,1)=$5678,'WordFromTag word1');
  EndTest;
end;

procedure TestEventOfClass;
var
  subEvent:TEventStr;
begin
  StartTest('EventOfClass');
  Check(EventOfClass('UI\Button\Click','UI',subEvent),'UI\Button\Click is UI event');
  Check(subEvent='Button\Click','subEvent extraction');
  Check(EventOfClass('UI\Button\Click','UI\Button',subEvent),'nested match');
  Check(subEvent='Click','nested subEvent');
  Check(not EventOfClass('UI\Button\Click','Game',subEvent),'non-matching class');
  EndTest;
end;

procedure TestConcurrentSetEventHandler;
var
  threads:array[1..MTHandlerCount] of IThread;
  i:integer;
begin
  StartTest('Concurrent SetEventHandler');
  mtHitMask:=0;
  mtHitCount:=0;
  mtStartRegistration:=false;
  for i:=1 to MTHandlerCount do
    threads[i]:=Thread.Start('EVReg#',@RegisterWorker,pointer(UIntPtr(i)));

  CoreTime.Sleep(10); // let all workers start waiting on shared flag
  mtStartRegistration:=true;
  for i:=1 to MTHandlerCount do
    threads[i].Wait(2000);

  Signal('MT\Signal',999);

  Check(mtHitCount=MTHandlerCount,'all concurrently registered handlers must be called');
  Check(mtHitMask=(1 shl MTHandlerCount)-1,'all unique handlers should fire exactly once');

  RemoveEventHandler(MTHandler1,'MT\SIGNAL');
  RemoveEventHandler(MTHandler2,'MT\SIGNAL');
  RemoveEventHandler(MTHandler3,'MT\SIGNAL');
  RemoveEventHandler(MTHandler4,'MT\SIGNAL');
  RemoveEventHandler(MTHandler5,'MT\SIGNAL');
  RemoveEventHandler(MTHandler6,'MT\SIGNAL');
  RemoveEventHandler(MTHandler7,'MT\SIGNAL');
  RemoveEventHandler(MTHandler8,'MT\SIGNAL');
  EndTest;
end;

procedure TestConcurrentDuplicateRegistration;
var
  threads:array[1..MTHandlerCount] of IThread;
  i:integer;
begin
  StartTest('Concurrent duplicate registration');
  mtDuplicateCount:=0;
  mtStartRegistration:=false;
  for i:=1 to MTHandlerCount do
    threads[i]:=Thread.Start('EVDup#',TThreadFunc(@RegisterSameWorker));

  CoreTime.Sleep(10);
  mtStartRegistration:=true;
  for i:=1 to MTHandlerCount do
    threads[i].Wait(2000);

  Signal('MT\Duplicate',777);
  Check(mtDuplicateCount=1,'same handler+event must be registered only once');

  RemoveEventHandler(MTDuplicateHandler,'MT\DUPLICATE');
  EndTest;
end;

procedure TestQueuedSameHandlerInManyThreads;
var
  threads:array[1..MTHandlerCount] of IThread;
  i:integer;
begin
  StartTest('Queued same handler in many threads');
  mtQueuedLock.Init('EventManQueuedTest',100);
  try
    mtQueuedReadyCount:=0;
    mtQueuedHandlerCalls:=0;
    mtQueuedDoneCount:=0;
    mtQueuedStart:=false;
    FillChar(mtQueuedHitByThread,SizeOf(mtQueuedHitByThread),0);
    FillChar(mtThreadIDs,SizeOf(mtThreadIDs),0);

    for i:=1 to MTHandlerCount do
      threads[i]:=Thread.Start('EVQ#',@RegisterQueuedSameWorker,pointer(UIntPtr(i)));

    for i:=1 to 400 do begin
      mtQueuedLock.Enter;
      try
        if mtQueuedReadyCount=MTHandlerCount then break;
      finally
        mtQueuedLock.Leave;
      end;
      CoreTime.Sleep(1);
    end;

    Signal('MT\QueuedPerThread',321);
    mtQueuedStart:=true;

    for i:=1 to MTHandlerCount do
      threads[i].Wait(3000);

    Check(mtQueuedHandlerCalls=MTHandlerCount,'queued shared handler should be called once per registered thread');
    for i:=1 to MTHandlerCount do
      Check(mtQueuedHitByThread[i],'each thread must process queued signal');

    RemoveEventHandler(MTQueuedSharedHandler,'MT\QUEUEDPERTHREAD');
  finally
    mtQueuedLock.Cleanup;
  end;
  EndTest;
end;

procedure TestDanglingHandlerCleanup;
var
  th:IThread;
begin
  StartTest('Dangling handler cleanup');
  danglingWarning:=false;
  Logger.SetCustomHandler(DanglingLogHandler);
  try
    th:=Thread.Start('EVDangling',TThreadProc(@RegisterDanglingWorker));
    th.Wait(2000);
    Check(danglingWarning,'thread exit should warn about dangling handlers');
  finally
    Logger.SetCustomHandler(nil);
  end;
  EndTest;
end;

begin
  writeln('=== EventMan Basic Tests ===');
  writeln;
  try
    TestBasicSignal;
    TestMultipleHandlers;
    TestLink;
    TestQueuedEvents;
    TestDelayedSignal;
    TestPackTag;
    TestEventOfClass;
    TestConcurrentSetEventHandler;
    TestConcurrentDuplicateRegistration;
    TestQueuedSameHandlerInManyThreads;
    TestDanglingHandlerCleanup;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
