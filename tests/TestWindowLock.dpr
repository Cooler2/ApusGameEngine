// TWindow cross-thread entry: Lock/Unlock (reentrancy, `window` context), QueueCall,
// Acquire/Release, the close protocol (BeginClose, WaitReleased), the context of
// onClickAsync threads, deferred removal of UI elements (TUIElement.Remove), keyboard
// focus as window state, the window thread's mouse state of removed elements and
// a scene effect replaced from its own DrawScene.
// No native window: only the platform-independent part of TWindow.
{$APPTYPE CONSOLE}
program TestWindowLock;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Threads,
  Apus.Engine.API,
  Apus.Engine.Window,
  Apus.Engine.Scene,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets;

{$I ..\Base\tests\Test.inc}

type
  TCounter=class
    count:integer;
    procedure Increment;
  end;

  // counts destructions
  TProbe=class(TUIElement)
    hotKeyCalls:integer;
    removeOnHotKey:boolean;
    destructor Destroy; override;
    function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
  end;
  TProbeButton=class(TUIButton)
    destructor Destroy; override;
  end;

  // replaces itself from DrawScene, as a handler run by the scene's Process/Render may do
  TReplacingEffect=class(TSceneEffect)
    replaceInDraw:boolean;
    procedure DrawScene; override;
    destructor Destroy; override;
  end;

var
  callCount:integer;
  queueTarget:TWindow; // window the re-queueing call adds to
  workerWnd:TWindow;
  workerState:integer;
  workerSawWindow,workerRestored,workerLockResult:boolean;
  asyncState:integer; // 0 - not run, 1 - running, 2 - done
  asyncWindow:TWindow;
  asyncSender:TUIElement;
  freedCount:integer;
  asyncGate:integer; // the async handler waits while 0
  removeTarget:TUIElement;
  focusTarget:TUIElement;
  testScene:TGameScene;
  effectsFreed:integer;
  aliveAfterReplace:boolean; // DrawScene saw itself not freed after the replacement
  newEffect:TSceneEffect;

procedure TCounter.Increment;
 begin
  inc(count);
 end;

destructor TProbe.Destroy;
 begin
  Atomic.Inc(freedCount);
  inherited;
 end;

function TProbe.onHotKey(keycode:byte;shiftstate:byte):boolean;
 begin
  inc(hotKeyCalls);
  if removeOnHotKey then Remove;
  result:=false; // not consumed: the next hotkey with this key is tried
 end;

destructor TProbeButton.Destroy;
 begin
  Atomic.Inc(freedCount);
  inherited;
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
  {$IFDEF FPC}{$WARN 4046 OFF}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT OFF}{$ENDIF} // constructing a class with abstract methods: they are never called here
  result:=TWindow.Create(name);
  {$IFDEF FPC}{$WARN 4046 ON}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT ON}{$ENDIF}
 end;

procedure AsyncClick;
 begin
  asyncWindow:=window;
  asyncSender:=TUIElement.sender;
  Atomic.Exchange(asyncState,2);
 end;

// click the button and wait for its onClickAsync thread; false if it didn't run
function ClickAndWait(btn:TUIButton):boolean;
 var
  t:integer;
 begin
  asyncState:=0;
  asyncWindow:=nil;
  asyncSender:=nil;
  btn.Click;
  t:=0;
  while (Atomic.CmpExchange(asyncState,2,2)<>2) and (t<200) do begin
   Sleep(5); inc(t);
  end;
  result:=asyncState=2;
 end;

// a window with one scene whose UI root is returned
// (one scene for all tests: scene names are unique)
function NewSceneRoot(w:TWindow;const name:String8):TUIElement;
 begin
  if testScene=nil then begin
   testScene:=TGameScene.Create(false);
   testScene.name:='TestScene'; // scene names are unique
  end;
  testScene.ownerWindow:=pointer(w);
  result:=TUIElement.Create(400,300,nil,name);
  result.ownerScene:=testScene;
 end;

procedure TestAsyncClick;
 var
  w:TWindow;
  root:TUIElement;
  btn,detached:TUIButton;
 begin
  StartTest('onClickAsync: window and sender');
  w:=NewWindow('Async');
  root:=NewSceneRoot(w,'AsyncRoot');
  btn:=TUIButton.Create(50,20,root,'AsyncBtn');
  btn.onClickAsync:=AsyncClick;
  window:=nil;
  Check(ClickAndWait(btn),'async handler runs');
  Check(asyncWindow=w,'handler gets the button window as context');
  Check(asyncSender=btn,'handler gets the button as sender');
  Check(w.WaitReleased(1000),'window is released after the handler'); // waits for the thread

  detached:=TUIButton.Create(50,20,nil,'Detached');
  detached.onClickAsync:=AsyncClick;
  window:=w; // dispatcher's context must not leak into the handler
  Check(ClickAndWait(detached),'handler of a detached button runs');
  Check(asyncWindow=nil,'detached button gives no window context');
  window:=nil;

  w.BeginClose;
  Sleep(60); // DoClick ignores clicks within 50 ms of the previous one
  Check(not ClickAndWait(btn),'click of a closing window does not start the handler');
  Check(w.WaitReleased(0),'dropped click holds no reference');
  detached.Free;
  root.Free;
  w.Free;
  EndTest;
 end;

procedure TestRemove;
 var
  w:TWindow;
  root:TUIElement;
  a,b,child:TProbe;
 begin
  StartTest('Remove: detach now, free at frame start');
  w:=NewWindow('Remove');
  root:=NewSceneRoot(w,'RemoveRoot');
  freedCount:=0;
  a:=TProbe.Create(10,10,root,'A');
  child:=TProbe.Create(5,5,a,'AChild');
  a.Remove;
  Check(length(root.children)=0,'removed element leaves the tree at once');
  Check(a.deleted and child.deleted,'element and its subtree are marked deleted');
  Check(freedCount=0,'nothing is freed before the frame start');
  a.Remove; // again: nothing happens
  DestroyQueuedElements(w);
  Check(freedCount=2,'element and child are freed at the frame start');

  // "list -> remove all" with a parent and its child, in both orders
  freedCount:=0;
  a:=TProbe.Create(10,10,root,'P1');
  child:=TProbe.Create(5,5,a,'P1Child');
  child.Remove;
  a.Remove;
  b:=TProbe.Create(10,10,root,'P2');
  child:=TProbe.Create(5,5,b,'P2Child');
  b.Remove;
  child.Remove; // already deleted with its parent
  DestroyQueuedElements(w);
  Check(freedCount=4,'parent and child removed together are freed once each');

  // the name of a removed element is free at once (rebuild with the same names)
  a:=TProbe.Create(10,10,root,'SameName');
  a.Remove;
  Check(TUIElement.FindByName('SameName')=nil,'removed element is not found by name');
  b:=TProbe.Create(10,10,root,'SameName');
  Check(TUIElement.FindByName('SameName')=b,'the name is reused by a new element');
  DestroyQueuedElements(w);
  Check(TUIElement.FindByName('SameName')=b,'freeing the removed one keeps the new name');
  b.Remove;
  DestroyQueuedElements(w);

  // held elements wait
  freedCount:=0;
  a:=TProbe.Create(10,10,root,'Held');
  Check(a.Acquire,'Acquire of a live element');
  a.Remove;
  Check(not a.Acquire,'Acquire fails after Remove');
  DestroyQueuedElements(w);
  Check(freedCount=0,'held element is not freed');
  a.Release;
  DestroyQueuedElements(w);
  Check(freedCount=1,'freed after Release');

  // not in a window: freed at once, or on release when held
  freedCount:=0;
  a:=TProbe.Create(10,10,nil,'Loose');
  child:=TProbe.Create(5,5,a,'LooseChild');
  a.Remove;
  Check(freedCount=2,'element outside a window is freed at once');
  a:=TProbe.Create(10,10,nil,'LooseHeld');
  child:=TProbe.Create(5,5,a,'LooseHeldChild');
  Check(child.Acquire,'Acquire of a child outside a window');
  a.Remove;
  Check(freedCount=2,'held subtree outside a window is not freed');
  DestroyQueuedElements(w);
  Check(freedCount=2,'still held at the frame start');
  child.Release;
  DestroyQueuedElements(w);
  Check(freedCount=4,'freed by the next frame start after Release');

  root.Free;
  w.Free;
  EndTest;
 end;

procedure RemoveSender;
 begin
  TUIElement.sender.Remove;
 end;

procedure RemoveWorker;
 begin
  removeTarget.Remove;
  Atomic.Exchange(workerState,1);
 end;

procedure GatedAsyncClick;
 begin
  while Atomic.CmpExchange(asyncGate,0,0)=0 do Sleep(1);
  asyncSender:=TUIElement.sender;
  Atomic.Exchange(asyncState,2);
 end;

procedure TestRemoveInHandlers;
 var
  w:TWindow;
  root:TUIElement;
  btn:TProbeButton;
  a,b:TProbe;
  th:IThread;
  t:integer;
 begin
  StartTest('Remove from handlers and threads');
  w:=NewWindow('RemoveHandlers');
  root:=NewSceneRoot(w,'RemoveHandlersRoot');

  // a button removing itself in onClick: DoClick goes on with live memory
  freedCount:=0;
  btn:=TProbeButton.Create(50,20,root,'SelfRemove');
  btn.onClick:=RemoveSender;
  btn.Click;
  Check(btn.deleted and (length(root.children)=0),'button removed itself in onClick');
  Check(freedCount=0,'its memory lives until the frame start');
  DestroyQueuedElements(w);
  Check(freedCount=1,'freed at the frame start');

  // removed in onClick, the async handler still gets the held button
  freedCount:=0;
  asyncState:=0;
  asyncGate:=0;
  asyncSender:=nil;
  btn:=TProbeButton.Create(50,20,root,'RemoveAndAsync');
  btn.onClick:=RemoveSender;
  btn.onClickAsync:=GatedAsyncClick;
  btn.Click;
  DestroyQueuedElements(w);
  Check(freedCount=0,'button held by its async handler is not freed');
  Atomic.Exchange(asyncGate,1);
  t:=0;
  while (Atomic.CmpExchange(asyncState,2,2)<>2) and (t<400) do begin
   Sleep(5); inc(t);
  end;
  Check(asyncSender=btn,'async handler gets the removed button as sender');
  Check(w.WaitReleased(1000),'async handler released the window');
  t:=0;
  repeat // the handler releases the button right after the window... or before: poll
   DestroyQueuedElements(w);
   if freedCount=1 then break;
   Sleep(5); inc(t);
  until t>200;
  Check(freedCount=1,'freed once the async handler finished');

  // a hotkey handler removing its element: the scan goes on to the next hotkey
  a:=TProbe.Create(10,10,root,'HotA');
  b:=TProbe.Create(10,10,root,'HotB');
  a.SetHotKey(77);
  b.SetHotKey(77);
  a.removeOnHotKey:=true;
  ProcessHotKey(77,0);
  Check((a.hotKeyCalls=1) and (b.hotKeyCalls=1),'both hotkey handlers ran');
  ProcessHotKey(77,0);
  Check((a.hotKeyCalls=1) and (b.hotKeyCalls=2),'removed element lost its hotkey');
  DestroyQueuedElements(w);

  // removal from a worker thread
  freedCount:=0;
  removeTarget:=TProbe.Create(10,10,root,'WorkerTarget');
  workerState:=0;
  th:=Thread.Start('UIRemoveWorker',TThreadProc(@RemoveWorker));
  th.Wait(2000);
  Check(workerState=1,'worker finished');
  Check(removeTarget.deleted and (removeTarget.parent=nil),'worker removed the element from the tree');
  Check(freedCount=0,'not freed by the worker');
  DestroyQueuedElements(w);
  Check(freedCount=1,'freed by the window thread at the frame start');

  root.Free;
  w.Free;
  EndTest;
 end;

procedure FocusWorker;
 begin
  focusTarget.SetFocus;
  Atomic.Exchange(workerState,1);
 end;

procedure RunWorker(proc:TProcedure);
 var
  th:IThread;
 begin
  workerState:=0;
  th:=Thread.Start('UIFocusWorker',TThreadProc(proc));
  th.Wait(2000);
 end;

procedure TestFocus;
 var
  w1,w2:TWindow;
  scene2:TGameScene;
  root1,root2,e2,loose:TUIElement;
  e1,e3:TProbe;
 begin
  StartTest('Focus is window state');
  w1:=NewWindow('Focus1');
  w2:=NewWindow('Focus2');
  root1:=NewSceneRoot(w1,'FocusRoot1');
  scene2:=TGameScene.Create(false);
  scene2.name:='FocusScene2';
  scene2.ownerWindow:=pointer(w2);
  root2:=TUIElement.Create(400,300,nil,'FocusRoot2');
  root2.ownerScene:=scene2;
  e1:=TProbe.Create(10,10,root1,'Focus1A');
  e2:=TUIElement.Create(10,10,root2,'Focus2A');

  // focus set by another thread (startup scenes are built on the control thread)
  focusTarget:=e1;
  RunWorker(FocusWorker);
  Check(workerState=1,'worker finished');
  window:=w1;
  Check(FocusedElement=e1,'focus set by a worker is seen in the window');
  Check(e1.HasFocus and root1.HasFocus,'element and its ancestors have the focus');

  // windows keep their own focus
  e2.SetFocus;
  Check(FocusedElement=e1,'focusing in another window keeps this window''s focus');
  window:=w2;
  Check(FocusedElement=e2,'the other window has its own focus');
  SetFocusTo(nil);
  Check((w2.focus.element=nil) and (w1.focus.element=e1),'SetFocusTo(nil) clears the thread''s window only');

  // an element outside any window can't take the focus
  window:=w1;
  loose:=TUIElement.Create(10,10,nil,'FocusLoose');
  loose.SetFocus;
  Check(FocusedElement=e1,'detached element does not take the focus');
  loose.Free;

  // removal by a worker drops the focus at once
  removeTarget:=e1;
  RunWorker(RemoveWorker);
  Check(workerState=1,'remove worker finished');
  Check(w1.focus.element=nil,'focus of a removed element is dropped');
  DestroyQueuedElements(w1);

  // freeing the focused element drops the focus
  e3:=TProbe.Create(10,10,root1,'Focus1B');
  e3.SetFocus;
  Check(FocusedElement=e3,'focus moved');
  e3.Free;
  Check(w1.focus.element=nil,'focus of a freed element is dropped');
  window:=nil;

  root1.Free;
  root2.Free;
  scene2.Free;
  w1.Free;
  w2.Free;
  EndTest;
 end;

procedure TestRemovedMouseState;
 var
  w:TWindow;
  root:TUIElement;
  a:TProbe;
 begin
  StartTest('Mouse state of removed elements');
  w:=NewWindow('MouseState');
  root:=NewSceneRoot(w,'MouseStateRoot');
  window:=w;
  // this thread plays the window thread: it holds the mouse state
  a:=TProbe.Create(10,10,root,'Captor');
  hooked:=a;
  underMouse:=a;
  clipMouse:=cmVirtual;
  removeTarget:=a;
  RunWorker(RemoveWorker);
  Check(workerState=1,'remove worker finished');
  Check(hooked=a,'a worker can''t reach the window thread''s capture');
  DropRemovedMouseState;
  Check((hooked=nil) and (clipMouse=cmNo),'mouse dispatch drops the capture of a removed element');
  Check(underMouse=nil,'and its hover');
  DestroyQueuedElements(w);

  // freeing in the window thread clears the capture as well
  a:=TProbe.Create(10,10,root,'Captor2');
  hooked:=a;
  a.Free;
  Check(hooked=nil,'freed captor releases the mouse');
  window:=nil;
  root.Free;
  w.Free;
  EndTest;
 end;

procedure TReplacingEffect.DrawScene;
 begin
  if not replaceInDraw then exit;
  newEffect:=TReplacingEffect.Create(target,100);
  aliveAfterReplace:=effectsFreed=0;
 end;

destructor TReplacingEffect.Destroy;
 begin
  inc(effectsFreed);
  inherited;
 end;

procedure TestEffectReplace;
 var
  sc:TGameScene;
  old:TReplacingEffect;
 begin
  StartTest('Scene effect replaced from its own DrawScene');
  sc:=TGameScene.Create(false);
  sc.name:='EffectScene';
  effectsFreed:=0;
  old:=TReplacingEffect.Create(sc,100);
  old.replaceInDraw:=true;
  old.Paint;
  Check(aliveAfterReplace,'the running effect survives its replacement');
  Check(effectsFreed=1,'and is freed when DrawScene returns');
  Check(sc.effect=newEffect,'the new effect owns the scene');
  TReplacingEffect.Create(sc,100);
  Check(effectsFreed=2,'outside DrawScene the replaced effect is freed at once');
  sc.effect.Free;
  sc.effect:=nil;
  sc.Free;
  EndTest;
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
  TestAsyncClick;
  TestRemove;
  TestRemoveInHandlers;
  TestFocus;
  TestRemovedMouseState;
  TestEffectReplace;
  if IsDebuggerPresent then readln;
end.
