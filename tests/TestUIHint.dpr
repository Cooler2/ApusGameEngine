// Hint state is window state: TUIHint.Current(wnd) must not dangle when the hint is
// removed or destroyed through its parent (screen transitions destroy whole UI trees),
// hints of different windows are independent, ShowSimpleHint works from any thread.
// Also: an element enters the tree only after its whole constructor chain.
{$APPTYPE CONSOLE}
program TestUIHint;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Threads,
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Window,
  Apus.Engine.Scene,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UI;

{$I ..\Base\tests\Test.inc}

type
  // records whether it was in its parent's children while being constructed
  TPublishProbe=class(TUIElement)
    seenInParent:boolean;
    constructor Create(parent_:TUIElement);
  end;

var
  testScenes:array[1..2] of TGameScene;
  workerRoot:TUIElement;
  workerDone:integer;
  createdHintText:String8;

constructor TPublishProbe.Create(parent_:TUIElement);
 begin
  inherited Create(10,10,parent_,'PublishProbe');
  seenInParent:=ChildIndex>=0;
 end;

function NewWindow(const name:String8):TWindow;
 begin
  {$IFDEF FPC}{$WARN 4046 OFF}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT OFF}{$ENDIF} // constructing a class with abstract methods: they are never called here
  result:=TWindow.Create(name);
  {$IFDEF FPC}{$WARN 4046 ON}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT ON}{$ENDIF}
 end;

// UI root of a scene owned by the window (scene names are unique: one scene per slot)
function NewSceneRoot(w:TWindow;slot:integer;const name:String8):TUIElement;
 begin
  if testScenes[slot]=nil then begin
   testScenes[slot]:=TGameScene.Create(false);
   testScenes[slot].name:='TestScene'+IntToStr(slot);
  end;
  testScenes[slot].ownerWindow:=pointer(w);
  result:=TUIElement.Create(800,600,nil,name);
  result.ownerScene:=testScenes[slot];
 end;

procedure TestShowHint;
 var
  w:TWindow;
  root:TUIElement;
 begin
  StartTest('ShowSimpleHint');
  w:=NewWindow('HintWnd');
  root:=NewSceneRoot(w,1,'root');
  ShowSimpleHint('first',root,10,10,1000);
  Check(TUIHint.Current(w)<>nil,'hint is current in the window');
  Check(TUIHint.Current(w).parent=root,'hint is attached to the parent');
  ShowSimpleHint('second',root,20,20,1000);
  Check(length(root.children)=1,'previous hint left the tree');
  Check(TUIHint.Current(w).simpleText='second','new hint is current');
  TUIHint.Current(w).Remove;
  Check(TUIHint.Current(w)=nil,'removed hint is not current any more');
  DestroyQueuedElements(w);
  root.Free;
  w.Free;
  EndTest;
 end;

procedure TestParentDestroyed;
 var
  w:TWindow;
  root:TUIElement;
 begin
  StartTest('Hint parent destroyed');
  w:=NewWindow('HintWnd');
  root:=NewSceneRoot(w,1,'root');
  ShowSimpleHint('hint',root,10,10,1000);
  root.Free; // frees the hint as a child
  Check(TUIHint.Current(w)=nil,'no dangling current hint');
  root:=NewSceneRoot(w,1,'root2');
  ShowSimpleHint('next',root,10,10,1000); // used to free the dangling hint
  Check(TUIHint.Current(w).parent=root,'next hint works');
  root.Free;
  w.Free;
  EndTest;
 end;

procedure TestHintFreed;
 var
  w:TWindow;
  root:TUIElement;
 begin
  StartTest('Hint freed directly');
  w:=NewWindow('HintWnd');
  root:=NewSceneRoot(w,1,'root');
  ShowSimpleHint('hint',root,10,10,1000);
  TUIHint.Current(w).Free;
  Check(TUIHint.Current(w)=nil,'current hint is reset');
  Check(length(root.children)=0,'hint is detached');
  root.Free;
  w.Free;
  EndTest;
 end;

procedure TestNoWindow;
 var
  root:TUIElement;
 begin
  StartTest('Hint without a window');
  root:=TUIElement.Create(800,600,nil,'looseRoot');
  ShowSimpleHint('hint',root,10,10,1000);
  Check(length(root.children)=0,'no hint for a parent outside any window');
  root.Free;
  EndTest;
 end;

procedure TestTwoWindows;
 var
  w1,w2:TWindow;
  r1,r2:TUIElement;
  h2:TUIHint;
 begin
  StartTest('Hints of two windows');
  w1:=NewWindow('HintWnd1');
  w2:=NewWindow('HintWnd2');
  r1:=NewSceneRoot(w1,1,'root1');
  r2:=NewSceneRoot(w2,2,'root2');
  ShowSimpleHint('one',r1,10,10,1000);
  ShowSimpleHint('two',r2,10,10,1000);
  h2:=TUIHint.Current(w2);
  Check(TUIHint.Current(w1).simpleText='one','first window has its hint');
  Check((h2<>nil) and (h2.simpleText='two'),'second window has its hint');
  ShowSimpleHint('one again',r1,10,10,1000);
  Check(TUIHint.Current(w2)=h2,'a new hint in one window keeps the other window''s hint');
  Check(length(r2.children)=1,'other window''s hint stays in its tree');
  DestroyQueuedElements(w1);
  r1.Free;
  r2.Free;
  w1.Free;
  w2.Free;
  EndTest;
 end;

procedure HintWorker;
 begin
  ShowSimpleHint('from worker',workerRoot,10,10,1000);
  Atomic.Exchange(workerDone,1);
 end;

procedure TestWorkerThread;
 var
  w:TWindow;
  th:IThread;
 begin
  StartTest('Hint from a worker thread');
  w:=NewWindow('HintWnd');
  workerRoot:=NewSceneRoot(w,1,'workerRoot');
  workerDone:=0;
  th:=Thread.Start('HintWorker',TThreadProc(@HintWorker));
  th.Wait(2000);
  Check(workerDone=1,'worker finished');
  Check((TUIHint.Current(w)<>nil) and (TUIHint.Current(w).simpleText='from worker'),
    'hint shown by a worker is the window''s current hint');
  workerRoot.Free;
  w.Free;
  EndTest;
 end;

procedure OnItemCreated(event:TEventStr;tag:TTag);
 begin
  if TObject(tag) is TUIHint then createdHintText:=TUIHint(tag).simpleText;
 end;

procedure TestPublication;
 var
  root:TUIElement;
  probe:TPublishProbe;
 begin
  StartTest('Publication after construction');
  root:=TUIElement.Create(800,600,nil,'pubRoot');
  probe:=TPublishProbe.Create(root);
  Check(not probe.seenInParent,'element is not in the tree during its constructor');
  Check(probe.ChildIndex=0,'element is in the tree after construction');
  createdHintText:='';
  SetEventHandler('UI\ItemCreated',OnItemCreated,emInstant);
  TUIHint.Create(0,0,'built',root);
  Check(createdHintText='built','UI\ItemCreated sees fields set by the derived constructor');
  RemoveEventHandler(OnItemCreated,'UI\ItemCreated');
  root.Free;
  EndTest;
 end;

begin
  TestShowHint;
  TestParentDestroyed;
  TestHintFreed;
  TestNoWindow;
  TestTwoWindows;
  TestWorkerThread;
  TestPublication;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
