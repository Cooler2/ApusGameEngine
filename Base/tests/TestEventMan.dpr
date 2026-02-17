{$APPTYPE CONSOLE}
program TestEventMan;
uses
  SysUtils,
  Apus.Core,
  Apus.EventMan;

{$INCLUDE Test.inc}

var
  eventReceived:string;
  tagReceived:TTag;
  eventCount:integer;

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
var
  linked:boolean;
begin
  StartTest('Link events');
  ResetCounters;
  linked:=false;
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
