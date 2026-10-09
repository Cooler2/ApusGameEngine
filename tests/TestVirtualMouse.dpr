// Virtual mouse through the Robot API (mouse.* commands): the input goes through the
// regular routing of the engine - hit-test, hover, pressed state, capture, modal dialogs,
// clicks - and is checked by the state of real UI elements, not by handler calls.
// No native window: TTestWindow plays the platform (OS pointer, OS button events), the
// frames run the window-level steps of TGame.FrameLoop, the main window in this thread,
// the second one in its own thread like an extra window.
{$APPTYPE CONSOLE}
program TestVirtualMouse;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Apus.Core,
  Apus.Strings,
  Apus.Threads,
  Apus.Files,
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.Window,
  Apus.Engine.Scene,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UIShapes,
  Apus.Engine.UIScene,
  Apus.Engine.RobotAPI;

{$I ..\Base\tests\Test.inc}

const
  ROBOT_IN='robot_in.txt';
  ROBOT_OUT='robot_out.txt';
  OUTSIDE=$3FFF;

type
  TPhysEvent=record
    btn:byte;
    pressed:boolean;
  end;
  TPhysEvents=array of TPhysEvent;

  // Platform stand-in: the "OS" pointer and button events are set by the test
  TTestWindow=class(TWindow)
    physPos:TPoint;       // OS pointer, client pixels; x<0 - outside the window
    physButtons:byte;     // OS button state polled by the frame
    physEvents:TPhysEvents; // OS button events delivered by the next message pump
    procedure SampleOSPointer; override;
    procedure ProcessMessages; override;
    function IsTerminated:boolean; override;
    procedure GetSize(out width,height:integer); override;
    procedure PhysicalClick(x,y:integer);
  end;

  // records what the mouse routing delivered to it
  TProbeButton=class(TUIButton)
    downs,ups,clicks:integer;
    wheel:integer; // sum of the wheel deltas
    procedure onMouseButtons(button:byte;state:boolean); override;
    procedure onMouseScroll(value:integer); override;
    procedure DoClick; override;
  end;

var
  wndA:TTestWindow;
  sceneA,dialog:TUIScene;
  btn,btnOff,btnHidden,btnDlg:TProbeButton;
  bar:TUIScrollBar;
  framesRun:integer;
  // second window: runs in its own thread
  wndB:TTestWindow;
  btnB:TProbeButton;
  threadB:IThread;
  stateB:integer; // 0 - starting, 1 - running, 2 - stop asked, 3 - stopped
  pauseB:integer; // 1 - no frames
  framesB:integer;

{ TTestWindow }

procedure TTestWindow.SampleOSPointer;
 begin
  if physPos.x<0 then mousePos:=Types.Point(OUTSIDE,OUTSIDE)
   else mousePos:=MapPointerToCanvas(physPos);
 end;

procedure TTestWindow.ProcessMessages;
 var
  events:TPhysEvents;
  i:integer;
 begin
  events:=physEvents;
  physEvents:=nil;
  for i:=0 to high(events) do
   PlatformMouseButton(events[i].btn,events[i].pressed);
 end;

function TTestWindow.IsTerminated:boolean;
 begin
  result:=false;
 end;

procedure TTestWindow.GetSize(out width,height:integer);
 begin
  width:=clientWidth;
  height:=clientHeight;
 end;

procedure TTestWindow.PhysicalClick(x,y:integer);
 var
  n:integer;
 begin
  physPos:=Types.Point(x,y);
  n:=length(physEvents);
  SetLength(physEvents,n+2);
  physEvents[n].btn:=1;
  physEvents[n].pressed:=true;
  physEvents[n+1].btn:=1;
  physEvents[n+1].pressed:=false;
 end;

{ TProbeButton }

procedure TProbeButton.onMouseButtons(button:byte;state:boolean);
 begin
  if button=1 then
   if state then inc(downs) else inc(ups);
  inherited;
 end;

procedure TProbeButton.onMouseScroll(value:integer);
 begin
  inc(wheel,value);
  inherited;
 end;

procedure TProbeButton.DoClick;
 begin
  inc(clicks);
  inherited;
 end;

// Window-level part of TGame.FrameLoop + RenderAndPresentFrame (no rendering)
procedure RunFrame(w:TTestWindow);
 begin
  w.RunQueuedCalls;
  w.SetPolledMouseButtons(w.physButtons);
  w.ProcessMessages;
  w.LockState;
  try
   HandleSignals;
   w.ApplyPendingSurface;
   w.FrameMouseInput(true);
  finally
   w.UnlockState;
  end;
  w.OnFrame;
  w.LockState;
  try
   HandleSignals;
  finally
   w.UnlockState;
  end;
  inc(w.frameNum);
 end;

function NewWindow(const name:String8;width,height:integer):TTestWindow;
 begin
  {$IFDEF FPC}{$WARN 4046 OFF}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT OFF}{$ENDIF} // constructing a class with abstract methods: they are never called here
  result:=TTestWindow.Create(name);
  {$IFDEF FPC}{$WARN 4046 ON}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT ON}{$ENDIF}
  result.physPos:=Types.Point(-1,-1);
  result.RequestResize(width,height);
  result.RequestDPI(96);
  result.ApplyPendingSurface;
 end;

function NewButton(parent:TUIElement;const name:String8;x,y:integer):TProbeButton;
 begin
  result:=TProbeButton.Create(100,30,parent,name);
  result.SetPos(x,y,pivotTopLeft);
 end;

// --- Robot API client ---

// Send a batch (requests separated by '---') and run frames until it is answered.
// The limit is in time, not in frames: window B runs its frames in its own thread at
// the Sleep(1) granularity (~15 ms on Windows), window A here runs them back to back.
function Robot(const requests:String8;out frames:integer):String8; overload;
 var
  start:int64;
 begin
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
  Files.Save(ROBOT_IN,requests+LineBreak+'==='+LineBreak);
  frames:=0;
  result:='';
  start:=CoreTime.Ticks;
  repeat
   RunFrame(wndA);
   inc(frames);
   inc(framesRun);
   PollRobotAPI(true);
   if Files.Exists(ROBOT_OUT) then begin
    result:=Files.LoadAsString(ROBOT_OUT);
    Files.Delete(ROBOT_OUT);
    exit;
   end;
  until CoreTime.Ticks-start>5000;
 end;

function Robot(const requests:String8):String8; overload;
 var
  frames:integer;
 begin
  result:=Robot(requests,frames);
 end;

// Field of the answer block of a request ('' if absent)
function Field(const answer,id,key:String8):String8;
 var
  lines:Strings8;
  i:integer;
  inBlock:boolean;
 begin
  result:='';
  lines:=answer.SplitLines;
  inBlock:=false;
  for i:=0 to high(lines) do begin
   if lines[i].Trim='===' then begin
    if inBlock then exit;
    continue;
   end;
   if lines[i].StartsWith('ID: ') then inBlock:=lines[i].Substr(5,length(lines[i])).Trim=id
   else if inBlock and lines[i].StartsWith(key+': ') then
    exit(lines[i].Substr(length(key)+3,length(lines[i])).Trim);
  end;
 end;

function IsOk(const answer,id:String8):boolean;
 begin
  result:=Field(answer,id,'STATUS')='OK';
 end;

function Req(const id,cmd:String8;const params:String8=''):String8;
 begin
  result:='ID: '+id+LineBreak+'CMD: '+cmd+LineBreak;
  if params<>'' then result:=result+params.ReplaceAll(';',LineBreak)+LineBreak;
 end;

function Batch(const items:array of String8):String8;
 var
  i:integer;
 begin
  result:='';
  for i:=0 to high(items) do begin
   if i>0 then result:=result+'---'+LineBreak;
   result:=result+items[i];
  end;
 end;

function Click(x,y:integer;const extra:String8=''):String8;
 begin
  result:=Robot(Req('c','mouse.click','X: '+IntToStr(x)+';Y: '+IntToStr(y)+extra));
 end;

function Move(x,y:integer;const extra:String8=''):String8;
 begin
  result:=Robot(Req('m','mouse.move','X: '+IntToStr(x)+';Y: '+IntToStr(y)+extra));
 end;

// --- Tests ---

procedure TestModeErrors;
 var
  a:String8;
 begin
  StartTest('Commands need the virtual mode');
  a:=Click(10,10);
  Check(Field(a,'c','STATUS')='ERROR','click without the virtual mode is an error');
  Check(btn.clicks=0,'and does nothing');
  a:=Robot(Req('m','mouse.mode','MODE: sideways'));
  Check(Field(a,'m','STATUS')='ERROR','unknown mode');
  a:=Robot(Req('m','mouse.mode','MODE: virtual;WINDOW: nowhere'));
  Check(Field(a,'m','MSG').StartsWith('window not found'),'unknown window');
  EndTest;
 end;

procedure TestPhysicalBefore;
 begin
  StartTest('Physical input without the virtual mode');
  wndA.PhysicalClick(150,115);
  RunFrame(wndA);
  RunFrame(wndA);
  Check(btn.clicks=1,'an OS click reaches the button');
  Check(underMouse=btn,'the OS pointer hovers it');
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
  EndTest;
 end;

procedure TestEnable;
 var
  a:String8;
 begin
  StartTest('mouse.mode virtual');
  wndA.physPos:=Types.Point(150,115); // the OS pointer sits on the button
  RunFrame(wndA);
  Check(underMouse=btn,'physical hover before');
  a:=Robot(Req('m','mouse.mode','MODE: virtual'));
  Check(IsOk(a,'m'),'mode switched: '+a);
  Check(Field(a,'m','mode')='virtual','reported mode');
  Check(Field(a,'m','position')='outside','the virtual pointer starts outside the canvas');
  Check(wndA.virtualMouse.IsActive,'window is in the virtual mode');
  Check(underMouse=nil,'the physical hover is gone');
  EndTest;
 end;

procedure TestMoveHover;
 var
  a:String8;
 begin
  StartTest('mouse.move hover');
  a:=Move(150,115);
  Check(IsOk(a,'m'),'move answered: '+a);
  Check(Field(a,'m','state')='done','answered once applied');
  Check(Field(a,'m','position')='150,115','position reported');
  Check(Field(a,'m','under')='Btn','element under the pointer reported');
  Check(underMouse=btn,'button is hovered');
  Check(wndA.mousePos=Types.Point(150,115),'window pointer state');
  a:=Robot(Req('e','ui.element','NAME: Btn'));
  Check(Field(a,'e','underMouse')='true','ui.element sees the hover');
  a:=Robot(Req('h','ui.hittest','X: 150;Y: 115'));
  Check(Field(a,'h','hit')='Btn','ui.hittest agrees on the coordinates');
  a:=Move(5,5);
  Check(underMouse=btn.parent,'leaving the button: hover goes to the root');
  Check(btn.clicks=0,'no clicks from moves');
  EndTest;
 end;

procedure TestClick;
 var
  a:String8;
  frames:integer;
 begin
  StartTest('mouse.click');
  a:=Robot(Req('c','mouse.click','X: 150;Y: 115'),frames);
  Check(IsOk(a,'c'),'click answered: '+a);
  Check(btn.clicks=1,'exactly one click, got '+IntToStr(btn.clicks));
  Check((btn.downs=1) and (btn.ups=1),'one down and one up delivered');
  Check(not btn.pressed,'released after the click');
  Check(frames>=3,'move, down and up take a frame each, polled while pending: '+IntToStr(frames));
  Check(Field(a,'c','buttons')='none','no button left down');
  // the pending request was retried every frame: no extra clicks appear later
  RunFrame(wndA); PollRobotAPI(true);
  RunFrame(wndA); PollRobotAPI(true);
  Check(btn.clicks=1,'retries of the pending request do not queue it again');
  Check(not Files.Exists(ROBOT_OUT),'nothing answered twice');
  EndTest;
 end;

procedure TestDownUp;
 var
  a:String8;
 begin
  StartTest('mouse.down / mouse.up');
  btn.clicks:=0;
  a:=Robot(Req('d','mouse.down','X: 160;Y: 120'));
  Check(IsOk(a,'d'),'down: '+a);
  Check(btn.pressed,'button is pressed');
  Check(Field(a,'d','buttons')='left','left button is down');
  Check(wndA.mouseButtons=mbLeft,'window button state');
  a:=Robot(Req('d2','mouse.down',''));
  Check(Field(a,'d2','STATUS')='ERROR','second down of the same button is refused');
  a:=Robot(Req('u','mouse.up',''));
  Check(IsOk(a,'u'),'up: '+a);
  Check(not btn.pressed,'released');
  Check(btn.clicks=1,'down+up over the button is a click');
  a:=Robot(Req('u2','mouse.up',''));
  Check(Field(a,'u2','STATUS')='ERROR','up of a released button is refused');
  // press, leave, release: the regular rules say no click
  Robot(Req('d','mouse.down','X: 160;Y: 120'));
  Move(400,400);
  Check(not btn.pressed,'leaving the button releases its pressed state');
  Robot(Req('u','mouse.up',''));
  Check(btn.clicks=1,'no click after leaving the button');
  // right button: not a click of a push button
  a:=Robot(Req('r','mouse.click','X: 160;Y: 120;BUTTON: right'));
  Check(IsOk(a,'r'),'right click answered');
  Check(btn.clicks=1,'right button does not click');
  a:=Robot(Req('r','mouse.click','BUTTON: fourth'));
  Check(Field(a,'r','STATUS')='ERROR','unknown button');
  EndTest;
 end;

procedure TestBatch;
 var
  a:String8;
 begin
  StartTest('move/down/up in one batch');
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
  Move(400,400);
  a:=Robot(Batch([Req('1','mouse.move','X: 120;Y: 105'),Req('2','mouse.down'),
    Req('3','mouse.up'),Req('4','ui.element','NAME: Btn')]));
  Check(IsOk(a,'1') and IsOk(a,'2') and IsOk(a,'3') and IsOk(a,'4'),'all answered: '+a);
  Check((btn.downs=1) and (btn.ups=1),'both transitions delivered');
  Check(btn.clicks=1,'one click');
  Check(Field(a,'2','buttons')<>'','down answered with the state');
  Check(Field(a,'4','underMouse')='true','a command after the input sees its result');
  Check(a.IndexOf('ID: 3')<a.IndexOf('ID: 4'),'answers keep the order of the input');
  // WAIT: no - answered at once, the input still goes through
  btn.clicks:=0;
  a:=Robot(Batch([Req('1','mouse.click','X: 120;Y: 105;WAIT: no'),Req('2','mouse.wait')]));
  Check(Field(a,'1','state')='queued','WAIT: no answers before applying');
  Check(IsOk(a,'2') and (Field(a,'2','queued')='0'),'mouse.wait answers once the queue is empty');
  Check(btn.clicks=1,'queued click applied');
  EndTest;
 end;

procedure TestWheel;
 var
  a:String8;
 begin
  StartTest('mouse.wheel');
  btn.wheel:=0;
  a:=Robot(Req('w','mouse.wheel','DELTA: -240;X: 150;Y: 115'));
  Check(IsOk(a,'w'),'wheel answered: '+a);
  Check(Field(a,'w','under')='Btn','the pointer moved there first');
  Check(btn.wheel=-240,'the delta reaches the element under the pointer, got '+IntToStr(btn.wheel));
  a:=Robot(Req('w','mouse.wheel','DELTA: 120'));
  Check(btn.wheel=-120,'without X, Y - at the current position, got '+IntToStr(btn.wheel));
  a:=Robot(Req('w','mouse.wheel','DELTA: 0'));
  Check(Field(a,'w','STATUS')='ERROR','zero delta is refused');
  a:=Robot(Req('w','mouse.wheel'));
  Check(Field(a,'w','STATUS')='ERROR','DELTA is required');
  EndTest;
 end;

procedure TestRules;
 var
  a:String8;
 begin
  StartTest('Disabled, hidden, modal');
  btnOff.clicks:=0; btnHidden.clicks:=0; btn.clicks:=0;
  a:=Click(330,115);
  Check(IsOk(a,'c'),'click on the disabled button answered');
  // a disabled push button still hears the press (handleMouseIfDisabled), never clicks
  Check((btnOff.clicks=0) and not btnOff.pressed,'disabled button does not click');
  a:=Click(530,115);
  Check((btnHidden.clicks=0) and (btnHidden.downs=0),'hidden button gets nothing');
  Check(Field(a,'c','under')<>'Hidden','hidden button is not under the pointer');
  // modal dialog: the rest of the window is blocked
  dialog.SetStatus(ssActive);
  wndA.modal.Push(dialog.UI);
  try
   a:=Click(150,115);
   Check(btn.clicks=0,'button outside the modal dialog is blocked');
   a:=Click(330,315);
   Check(btnDlg.clicks=1,'button in the dialog clicks');
  finally
   wndA.modal.Pop(dialog.UI);
   dialog.SetStatus(ssFrozen);
  end;
  a:=Click(150,115);
  Check(btn.clicks=1,'after the dialog the button works again');
  EndTest;
 end;

procedure TestDrag;
 var
  a:String8;
  v:single;
 begin
  StartTest('Drag keeps the capture');
  Move(400,400);
  bar.value:=0;
  v:=bar.value;
  a:=Robot(Req('d','mouse.down','X: 105;Y: 205'));
  Check(IsOk(a,'d'),'down on the slider: '+a);
  Check(hooked=bar,'scrollbar captured the mouse');
  a:=Move(180,205);
  Check(bar.value>v,'slider follows the pointer');
  a:=Move(700,500); // far outside the bar
  Check(hooked=bar,'capture is kept outside the element');
  Check(underMouse=bar,'and the hover stays with the captor');
  Check(Field(a,'m','under')='Bar','reported under the pointer');
  Check(bar.value>=bar.max-bar.pagesize,'dragged to the end');
  a:=Robot(Req('u','mouse.up',''));
  Check(hooked=nil,'release ends the capture');
  Check(clipMouse=cmNo,'and the clipping');
  EndTest;
 end;

procedure TestReset;
 var
  a:String8;
 begin
  StartTest('mouse.reset');
  btn.clicks:=0;
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  Check(btn.pressed,'pressed before the reset');
  a:=Robot(Req('r','mouse.reset'));
  Check(IsOk(a,'r'),'reset: '+a);
  Check(not btn.pressed,'reset releases the pressed state');
  Check(btn.clicks=0,'without a click');
  Check(wndA.mouseButtons=0,'no button left down');
  Check(Field(a,'r','position')='outside','pointer moved outside');
  // a captured drag
  bar.value:=0;
  Robot(Req('d','mouse.down','X: 105;Y: 205'));
  Move(700,205);
  Check(hooked=bar,'captured before the reset');
  Robot(Req('r','mouse.reset'));
  Check(hooked=nil,'reset releases the capture');
  Check(clipMouse=cmNo,'and the clipping');
  Check(underMouse=nil,'nothing is hovered');
  a:=Click(150,115);
  Check(btn.clicks=1,'input works after the reset');
  EndTest;
 end;

procedure TestPhysicalIgnored;
 var
  a:String8;
 begin
  StartTest('Physical input ignored in the virtual mode');
  btn.clicks:=0; btnOff.clicks:=0;
  Move(400,400);
  wndA.PhysicalClick(150,115); // OS click on the button
  wndA.physButtons:=mbLeft;
  RunFrame(wndA);
  RunFrame(wndA);
  Check(btn.clicks=0,'OS click does not reach the button');
  Check(wndA.mousePos=Types.Point(400,400),'OS pointer does not move the virtual one');
  Check(wndA.mouseButtons=0,'OS button state is ignored');
  Check(underMouse=sceneA.UI,'hover follows the virtual pointer');
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  wndA.physButtons:=0;
  SetLength(wndA.physEvents,1);
  wndA.physEvents[0].btn:=1;
  wndA.physEvents[0].pressed:=false; // OS release while the virtual button is down
  RunFrame(wndA);
  Check(btn.pressed and (wndA.mouseButtons=mbLeft),'virtual press survives OS events');
  a:=Robot(Req('u','mouse.up'));
  Check(btn.clicks=1,'virtual click completes');
  wndA.physPos:=Types.Point(-1,-1);
  EndTest;
 end;

procedure TestClientSpace;
 var
  a:String8;
  cfg:TSurfaceConfig;
 begin
  StartTest('SPACE: client with DPI and viewport');
  // fixed canvas 800x600 on a 1600x1300 client at 192 DPI: scale 2, bars of 50 px
  cfg.Init;
  cfg.canvasSize:=MakeSize(800,600);
  cfg.fit:=TSurfaceFit.keepAspect;
  wndA.SetSurfaceConfig(cfg);
  wndA.RequestDPI(192);
  wndA.RequestResize(1600,1300);
  RunFrame(wndA);
  Check((wndA.canvasWidth=800) and (wndA.canvasHeight=600),'canvas is fixed');
  Check(wndA.displayRect=Types.Rect(0,50,1600,1250),'letterboxed: '+IntToStr(wndA.displayRect.Top));
  a:=Move(300,280,';SPACE: client');
  Check(Field(a,'m','position')='150,115','client 300,280 is canvas 150,115: '+Field(a,'m','position'));
  Check(underMouse=btn,'button hovered through client coordinates');
  a:=Move(300,20,';SPACE: client');
  Check(Field(a,'m','position')='outside','the bar above the picture is outside the canvas');
  btn.clicks:=0;
  a:=Click(300,280,';SPACE: client');
  Check(btn.clicks=1,'click through client coordinates');
  // the conversion uses the surface of the frame that applies the input
  a:=Robot(Batch([Req('1','mouse.move','X: 300;Y: 280;SPACE: client;WAIT: no')]));
  wndA.RequestResize(1000,600); // now: scale 1, picture at x=100..900
  a:=Robot(Req('w','mouse.wait'));
  Check(Field(a,'w','position')='200,280','mapped with the new surface: '+Field(a,'w','position'));
  a:=Move(150,115); // canvas coordinates are not affected by the surface
  Check(underMouse=btn,'canvas space is independent of the client size');
  cfg.Init;
  wndA.SetSurfaceConfig(cfg);
  wndA.RequestDPI(96);
  wndA.RequestResize(800,600);
  RunFrame(wndA);
  Check(wndA.canvasWidth=800,'surface restored');
  EndTest;
 end;

// --- Second window, its own thread ---

function WindowBThread(ctx:TThreadContext):UIntPtr;
 var
  scene:TUIScene;
 begin
  result:=0;
  wndB:=NewWindow('Second',800,600);
  window:=wndB;
  scene:=TUIScene.Create('SceneB',true,wndB);
  scene.SetStatus(ssActive);
  btnB:=NewButton(scene.UI,'BtnB',100,100);
  stateB:=1;
  while stateB=1 do begin
   if pauseB=0 then begin
    RunFrame(wndB);
    inc(framesB);
   end;
   CoreTime.Sleep(1);
  end;
  // close protocol of an extra window (see ExtraWindowLoop)
  wndB.BeginClose;
  wndB.RunQueuedCalls;
  stateB:=3;
 end;

procedure TestSecondWindow;
 var
  a:String8;
  i:integer;
 begin
  StartTest('Input of one window does not reach another');
  stateB:=0;
  threadB:=Thread.Start('WndB',WindowBThread,nil);
  i:=0;
  while (stateB=0) and (i<5000) do begin CoreTime.Sleep(1); inc(i); end;
  Check(stateB=1,'second window started');
  btn.clicks:=0;
  a:=Click(150,115); // window A: same coordinates as BtnB in window B
  Check(btn.clicks=1,'window A clicked');
  Check(btnB.clicks=0,'window B untouched');
  a:=Robot(Req('s','mouse.state','WINDOW: Second'));
  Check(Field(a,'s','mode')='physical','window B is still in the physical mode');
  a:=Robot(Req('m','mouse.mode','MODE: virtual;WINDOW: second'));
  Check(IsOk(a,'m') and (Field(a,'m','window')='Second'),'window B by name: '+a);
  a:=Robot(Req('c','mouse.click','X: 150;Y: 115;WINDOW: Second'));
  Check(IsOk(a,'c'),'click in window B: '+a);
  Check(Field(a,'c','under')='BtnB','under the pointer of window B');
  Check(btnB.clicks=1,'window B button clicked by its own thread');
  Check(btn.clicks=1,'window A untouched');
  Check(wndA.mousePos=Types.Point(150,115),'window A pointer untouched');
  EndTest;
 end;

procedure TestCloseWithPending;
 var
  a:String8;
  i,polls:integer;
 begin
  StartTest('Window closed with pending input');
  pauseB:=1; // window B stops running frames: its input stays queued
  CoreTime.Sleep(20);
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
  Files.Save(ROBOT_IN,Req('c','mouse.click','X: 150;Y: 115;WINDOW: Second')+'==='+LineBreak);
  for polls:=1 to 5 do begin
   RunFrame(wndA);
   PollRobotAPI(true);
  end;
  Check(not Files.Exists(ROBOT_OUT),'click is pending while window B does not run');
  stateB:=2; // close window B
  i:=0;
  while (stateB<>3) and (i<5000) do begin CoreTime.Sleep(1); inc(i); end;
  Check(stateB=3,'window B closed');
  a:='';
  for polls:=1 to 20 do begin
   RunFrame(wndA);
   PollRobotAPI(true);
   if Files.Exists(ROBOT_OUT) then begin
    a:=Files.LoadAsString(ROBOT_OUT);
    Files.Delete(ROBOT_OUT);
    break;
   end;
  end;
  Check(Field(a,'c','STATUS')='ERROR','pending click answered with an error: '+a);
  Check(Field(a,'c','MSG').StartsWith('window closed'),'reason: '+Field(a,'c','MSG'));
  Check(btnB.clicks=1,'the dropped click never happened');
  i:=0;
  while threadB.IsRunning and (i<5000) do begin CoreTime.Sleep(1); inc(i); end;
  Check(wndB.WaitReleased(1000),'nobody holds window B');
  FreeAndNil(wndB); // the robot keeps no window pointer
  a:=Robot(Req('s','mouse.state','WINDOW: Second'));
  Check(Field(a,'s','STATUS')='ERROR','closed window is not found');
  a:=Click(150,115);
  Check(IsOk(a,'c'),'window A keeps working');
  EndTest;
 end;

procedure TestPhysicalAgain;
 var
  a:String8;
 begin
  StartTest('mouse.mode physical');
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  btn.clicks:=0;
  a:=Robot(Req('m','mouse.mode','MODE: physical'));
  Check(IsOk(a,'m') and (Field(a,'m','mode')='physical'),'back to physical: '+a);
  Check(not btn.pressed and (btn.clicks=0),'held button released without a click');
  Check(wndA.mouseButtons=0,'no buttons down');
  a:=Click(150,115);
  Check(Field(a,'c','STATUS')='ERROR','virtual commands refused again');
  wndA.PhysicalClick(150,115);
  RunFrame(wndA);
  RunFrame(wndA);
  Check(btn.clicks=1,'OS input works again');
  Check(underMouse=btn,'OS pointer hovers again');
  wndA.physPos:=Types.Point(-1,-1);
  EndTest;
 end;

procedure TestShutdown;
 var
  a:String8;
 begin
  StartTest('Robot API shutdown');
  a:=Robot(Req('m','mouse.mode','MODE: virtual'));
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  Check(btn.pressed,'pressed by the robot');
  btn.clicks:=0;
  DoneRobotAPI;
  RunFrame(wndA);
  Check(not wndA.virtualMouse.IsActive,'window back to the physical mode');
  Check(not btn.pressed and (btn.clicks=0),'gesture cancelled without a click');
  EndTest;
 end;

procedure Setup;
 var
  dlgPanel:TUIElement;
 begin
  wndA:=NewWindow('MainWnd',800,600);
  mainWindow:=wndA;
  window:=wndA;
  sceneA:=TUIScene.Create('SceneA',true,wndA);
  sceneA.SetStatus(ssActive);
  btn:=NewButton(sceneA.UI,'Btn',100,100);         // 100..200 x 100..130
  btnOff:=NewButton(sceneA.UI,'Disabled',300,100);
  btnOff.Disable;
  btnHidden:=NewButton(sceneA.UI,'Hidden',500,100);
  btnHidden.Hide;
  bar:=TUIScrollBar.CreateH(300,20,sceneA.UI,'Bar'); // 100..400 x 200..220
  bar.SetPos(100,200,pivotTopLeft);
  bar.SetRange(0,1000,100);
  bar.value:=0;
  dialog:=TUIScene.Create('Dialog',false,wndA);
  dialog.zOrder:=100;
  dlgPanel:=TUIElement.Create(300,200,dialog.UI,'DlgPanel');
  dlgPanel.SetPos(250,250,pivotTopLeft);
  dlgPanel.shape:=shapeFull;
  btnDlg:=NewButton(dlgPanel,'DlgBtn',30,50); // 280..380 x 300..330
  RunFrame(wndA);
  robotAPIEnabled:=true;
  InitRobotAPI;
  if Files.Exists(ROBOT_IN) then Files.Delete(ROBOT_IN);
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
 end;

begin
  Setup;
  TestModeErrors;
  TestPhysicalBefore;
  TestEnable;
  TestMoveHover;
  TestClick;
  TestDownUp;
  TestBatch;
  TestWheel;
  TestRules;
  TestDrag;
  TestReset;
  TestPhysicalIgnored;
  TestClientSpace;
  TestSecondWindow;
  TestCloseWithPending;
  TestPhysicalAgain;
  TestShutdown;
  if Files.Exists(ROBOT_IN) then Files.Delete(ROBOT_IN);
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
  writeln;
  writeln(Format('Tests: %d, failed: %d',[testsTotal,testsFailed]));
  if testsFailed>0 then ExitCode:=1;
  if IsDebuggerPresent then readln;
end.
