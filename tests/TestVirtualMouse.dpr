// Virtual mouse through the Robot API (mouse.* commands): the input goes through the
// regular routing of the engine - hit-test, hover, pressed state, capture, modal dialogs,
// clicks - and is checked by the state of real UI elements, not by handler calls.
// Also the keyboard routing around the focus, the popup menu (mouse and keys), the event
// methods of widgets, the queue of message dialogs and the -ROBOT=VIRTUAL start.
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
  Apus.Geom2D,
  Apus.Engine.Types,
  Apus.Engine.Keys,
  Apus.Engine.API,
  Apus.Engine.Window,
  Apus.Engine.Scene,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UIShapes,
  Apus.Engine.UIScene,
  Apus.Engine.SceneEffects,
  Apus.Engine.UIMenu,
  Apus.Engine.UIColorPicker,
  Apus.Engine.TextDraw,
  Apus.Engine.MessageScene,
  Apus.Engine.Game,
  Apus.Engine.RobotAPI;

{$I ..\Base\tests\Test.inc}

const
  ROBOT_IN='robot_in.txt';
  ROBOT_OUT='robot_out.txt';

type
  TPhysEvent=record
    btn:byte;
    pressed:boolean;
  end;
  TPhysEvents=array of TPhysEvent;

  // Platform stand-in: the "OS" pointer and button events are set by the test
  TTestWindow=class(TWindow)
    physPos:TPoint;       // OS pointer, client pixels; x<0 - outside the window
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

  // the class attribute 'defaultCanHaveFocus' overrides the button default
  TNoFocusButton=class(TUIButton)
  end;

  TTestColorEditor=class(TUIColorEditor)
  end;

  // records what the Mouse queries give in Process
  TProbeScene=class(TGameScene)
    rect:TRect; // for InRect/WasInRect
    frames,pressed,released,down:integer; // Process calls; frames with WasPressed, WasReleased, Down
    inRect,wasInRect,outside:boolean; // the last frame
    nest:boolean; // run a nested OnFrame from the next Process
    procedure Reset;
    function Process:boolean; override;
  end;

  // records the keys dispatched to it (gameplay receivers)
  TKeyProbe=class(TGameScene)
    log:String8; // 'D:LCtrl U:S+ctrl ...': D/U, the key, the modifiers held
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function onKeyUp(key:TKey;scancode:integer;shift:byte):boolean; override;
    procedure AddEvent(const kind:String8;key:TKey;shift:byte);
  end;

  // a UI scene that records the keys reaching the scene: its hotkey and gameplay receivers
  TKeyForm=class(TUIScene)
    log:String8; // 'D:B U:Space ...'
    saves:integer; // Ctrl+S hotkey calls
    function onKeyDown(key:TKey;scancode:integer;shift:byte):boolean; override;
    function onKeyUp(key:TKey;scancode:integer;shift:byte):boolean; override;
    procedure SaveHotKey;
  end;

  // records the menu commands and the focus they find
  TMenuProbe=class
    news,saves,quits:integer;
    focusAtCall:TUIElement;
    procedure DoNew;
    procedure DoSave;
    procedure DoQuit;
  end;

  // receives the event methods of widgets
  TEventProbe=class
    clicks,changes,enters:integer;
    edit:TUIEditBox;
    procedure DoClick;
    procedure DoChange;
    procedure DoEnter;
    procedure DoComplete;
  end;

  // text sizes for the layouts that measure text: nothing is drawn here
  TStubText=class(TTextDrawer,ITextDrawer)
    constructor Create;
    destructor Destroy; override;
    function Width(font:TFontHandle;st:String8):integer;
  end;

  // opens the scene choice of TGame.KeyPressed/CharEntered
  TKbdGame=class(TGame)
    function KbdTarget:TGameScene;
  end;

var
  wndA:TTestWindow;
  keyProbe:TKeyProbe;
  kbdLog:String8; // KBD\ events reaching the TGame stand-in: 'D:A U:A C:72 
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
  if physPos.x<0 then SetPointerOutside
   else SetPointer(physPos);
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

{ TProbeScene }

procedure TProbeScene.Reset;
 begin
  frames:=0; pressed:=0; released:=0; down:=0;
 end;

function TProbeScene.Process:boolean;
 begin
  result:=inherited;
  inc(frames);
  if Mouse.WasPressed then inc(pressed);
  if Mouse.WasReleased then inc(released);
  if Mouse.Down then inc(down);
  inRect:=Mouse.InRect(rect);
  wasInRect:=Mouse.WasInRect(rect);
  outside:=Mouse.Outside;
  if nest then begin
   nest:=false;
   TWindow(window).OnFrame;
  end;
 end;

{ TKeyProbe }

procedure TKeyProbe.AddEvent(const kind:String8;key:TKey;shift:byte);
 begin
  log:=log+kind+':'+String8(key.Name);
  if shift and sscCtrl<>0 then log:=log+'+ctrl';
  if shift and sscShift<>0 then log:=log+'+shift';
  if shift and sscAlt<>0 then log:=log+'+alt';
  log:=log+' ';
 end;

function TKeyProbe.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
 begin
  AddEvent('D',key,shift);
  result:=true;
 end;

function TKeyProbe.onKeyUp(key:TKey;scancode:integer;shift:byte):boolean;
 begin
  AddEvent('U',key,shift);
  result:=true;
 end;

{ TKeyForm }

function TKeyForm.onKeyDown(key:TKey;scancode:integer;shift:byte):boolean;
 begin
  log:=log+'D:'+String8(key.Name)+' ';
  result:=true;
 end;

function TKeyForm.onKeyUp(key:TKey;scancode:integer;shift:byte):boolean;
 begin
  log:=log+'U:'+String8(key.Name)+' ';
  result:=true;
 end;

procedure TKeyForm.SaveHotKey;
 begin
  inc(saves);
 end;

{ TMenuProbe }

procedure TMenuProbe.DoNew;
 begin
  inc(news);
  focusAtCall:=FocusedElement;
 end;

procedure TMenuProbe.DoSave;
 begin
  inc(saves);
  focusAtCall:=FocusedElement;
 end;

procedure TMenuProbe.DoQuit;
 begin
  inc(quits);
 end;

{ TStubText }

// no inherited in both: the real drawer needs a graphics system
constructor TStubText.Create;
 begin
 end;

destructor TStubText.Destroy;
 begin
 end;

function TStubText.Width(font:TFontHandle;st:String8):integer;
 begin
  result:=100;
 end;

{ TEventProbe }

procedure TEventProbe.DoClick;
 begin
  inc(clicks);
 end;

procedure TEventProbe.DoChange;
 begin
  inc(changes);
 end;

procedure TEventProbe.DoEnter;
 begin
  inc(enters);
 end;

procedure TEventProbe.DoComplete;
 begin
  edit.completion:=UTF8.Decode('abcdef');
 end;

// plain menu commands: inline and async (the async one runs in its own thread)
var
  menuPlainCalls,menuAsyncCalls:integer;

procedure MenuPlainClick;
 begin
  inc(menuPlainCalls);
 end;

procedure MenuAsyncClick;
 begin
  Atomic.Inc(menuAsyncCalls);
 end;

{ TKbdGame }

function TKbdGame.KbdTarget:TGameScene;
 begin
  result:=TopmostSceneForKbd;
 end;

// TGame stand-in for the KBD\ events (the key part of TGame.KeyPressed/CharEntered):
// keys go to the key probe, characters to the UI scene
procedure KbdEvent(event:TEventStr;tag:TTag);
 var
  key:TKey;
  code:integer;
  pressed:boolean;
 begin
  event:=Copy(event,5,200);
  if event.Same('UNICHAR') then begin
   kbdLog:=kbdLog+'C:'+IntToStr(tag and $FFFF)+' ';
   sceneA.WriteChar(cardinal(tag and $FFFF) shl 16);
   exit;
  end;
  pressed:=event.Same('KEYDOWN');
  if not pressed and not event.Same('KEYUP') then exit;
  key:=TKey(tag and $FF);
  code:=(tag shr 16) and $FFFF;
  if pressed then kbdLog:=kbdLog+'D:'+String8(Scan.Name(code))+' '
   else kbdLog:=kbdLog+'U:'+String8(Scan.Name(code))+' ';
  if not TWindow(window).KeyTransition(code,key,pressed) then exit;
  if keyProbe<>nil then
   keyProbe.WriteKey(cardinal(ord(key)) or (cardinal(code) shl 8) or (cardinal(ord(pressed)) shl 24));
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
  w.SetFrameTiming(CoreTime.Ticks*1000,0);
  w.RunQueuedCalls;
  w.ProcessMessages;
  w.LockState;
  try
   HandleSignals;
   w.ApplyPendingSurface;
   w.FrameInput(true);
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
  a:=Robot(Req('m','input.mode','MODE: sideways'));
  Check(Field(a,'m','STATUS')='ERROR','unknown mode');
  a:=Robot(Req('m','input.mode','MODE: virtual;WINDOW: nowhere'));
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

var
  testMenu:TUIPopupMenu;
  menuBtn:TProbeButton;
  menuToolBtn:TUIToolButton;

procedure ShowTestMenu;
 begin
  testMenu.OpenBelow(menuBtn);
 end;

procedure ShowTestMenuFromTool;
 begin
  testMenu.OpenBelow(menuToolBtn);
 end;

function CenterOf(e:TUIElement):TPoint;
 var
  r:TRect;
 begin
  r:=e.GetPosOnScreen;
  result:=Types.Point((r.Left+r.Right) div 2,(r.Top+r.Bottom) div 2);
 end;

procedure PhysicalClickAt(const p:TPoint);
 begin
  wndA.PhysicalClick(p.x,p.y);
  RunFrame(wndA);
  RunFrame(wndA);
 end;

// Popup menu (R-14): opening, keys, current line, commands, a press outside, focus
procedure TestPopupMenu;
 var
  probe:TMenuProbe;
  edit,edit2:TUIEditBox;
  itemNew,itemUndo,itemSave,itemQuit:TUIMenuItem;
  noFocusBtn:TUIButton;
  t:integer;
 begin
  StartTest('Popup menu');
  probe:=TMenuProbe.Create;
  menuBtn:=NewButton(sceneA.UI,'MenuBtn',100,300); // 100..200 x 300..330
  menuBtn.onClick:=ShowTestMenu;
  edit:=TUIEditBox.Create(100,20,sceneA.UI,'MenuEdit');
  edit.SetPos(500,300,pivotTopLeft);
  testMenu:=TUIPopupMenu.Create(sceneA.UI,'TestMenu');
  itemNew:=testMenu.Add('New','Ctrl+N');
  itemNew.onClickMethod:=probe.DoNew;
  itemUndo:=testMenu.Add('Undo','Ctrl+Z');
  itemUndo.Disable;
  testMenu.AddSeparator;
  itemSave:=testMenu.Add('Save...','Ctrl+S');
  itemSave.onClickMethod:=probe.DoSave;
  itemQuit:=testMenu.Add('&Quit now');
  itemQuit.onClickMethod:=probe.DoQuit;
  Check((itemSave.name='TestMenu\Save') and (itemQuit.name='TestMenu\Quit_now'),'default line names: '+itemSave.name+', '+itemQuit.name);
  // the anchor opens the menu below itself; its next press closes the menu for good
  Sleep(60); // TUIButton drops clicks in the first 50 ms of the program (its double-click guard)
  PhysicalClickAt(CenterOf(menuBtn));
  Check(testMenu.IsOpen and (FocusedElement=testMenu),'a click on the anchor opens the menu, the menu takes the focus');
  Check(testMenu.GetPosOnScreen.Top>=330,'the menu is below the anchor');
  Sleep(60); // past the double-click guard of TUIButton.DoClick
  PhysicalClickAt(CenterOf(menuBtn));
  Check(not testMenu.IsOpen,'the press on the anchor closes the menu, its click does not reopen it');
  // a tool button anchor takes no focus: the menu returns it to the edit box
  menuToolBtn:=TUIToolButton.Create(100,30,sceneA.UI,'MenuToolBtn');
  menuToolBtn.SetPos(250,300,pivotTopLeft); // 250..350 x 300..330
  menuToolBtn.onClick:=ShowTestMenuFromTool;
  Check(not menuToolBtn.flags.canHaveFocus and menuBtn.flags.canHaveFocus,'a tool button has no focus, a button has');
  edit.SetFocus;
  PhysicalClickAt(CenterOf(menuToolBtn));
  Check(testMenu.IsOpen and (FocusedElement=testMenu),'a click on a tool button anchor opens the menu');
  Sleep(60); // past the double-click guard of TUIButton.DoClick
  PhysicalClickAt(CenterOf(menuToolBtn));
  Check(not testMenu.IsOpen and (FocusedElement=edit),'its next press closes the menu, the focus is back in the edit box');
  menuToolBtn.Remove;
  // the class attribute overrides the default of a button class
  TNoFocusButton.SetDefault('canHaveFocus',false);
  noFocusBtn:=TNoFocusButton.Create(10,10,sceneA.UI,'NoFocusBtn');
  Check(not noFocusBtn.flags.canHaveFocus,'SetDefault(''canHaveFocus'',false) removes the focus of a button class');
  noFocusBtn.Remove;
  // keys: the current line skips the disabled line and the separator, wraps around
  edit.SetFocus;
  testMenu.OpenBelow(menuBtn);
  Check(testMenu.current=nil,'no current line when opened');
  sceneA.DispatchKey(TKey.Down,0,0,true);
  Check(testMenu.current=itemNew,'Down: the first line');
  sceneA.DispatchKey(TKey.Down,0,0,true);
  Check(testMenu.current=itemSave,'Down skips the disabled line and the separator');
  sceneA.DispatchKey(TKey.Up,0,0,true);
  Check(testMenu.current=itemNew,'Up skips them too');
  sceneA.DispatchKey(TKey.EndKey,0,0,true);
  sceneA.DispatchKey(TKey.Down,0,0,true);
  Check(testMenu.current=itemNew,'End, then Down wraps to the first line');
  Check(itemNew.IsHovered and not itemSave.IsHovered,'the current line is drawn as hovered');
  Check(sceneA.DispatchKey(TKey.B,0,0,true) and testMenu.IsOpen,'other keys stop at the open menu');
  testMenu.current:=itemUndo;
  Check(testMenu.current=nil,'a disabled line can not be current');
  // Enter: close, restore the focus, then run the command
  testMenu.current:=itemSave;
  sceneA.DispatchKey(TKey.Enter,0,0,true);
  Check((probe.saves=1) and not testMenu.IsOpen,'Enter runs the current line and closes the menu');
  Check(probe.focusAtCall=edit,'the command finds the focus already restored');
  // the button handlers of a line run too: inline, async, then the method
  menuPlainCalls:=0; menuAsyncCalls:=0;
  itemQuit.onClick:=@MenuPlainClick;
  itemQuit.onClickAsync:=@MenuAsyncClick;
  testMenu.OpenBelow(menuBtn);
  testMenu.current:=itemQuit;
  sceneA.DispatchKey(TKey.Enter,0,0,true);
  Check((menuPlainCalls=1) and (probe.quits=1) and not testMenu.IsOpen,'a line runs its onClick and its method');
  t:=0;
  while (Atomic.CmpExchange(menuAsyncCalls,0,0)=0) and (t<200) do begin
   Sleep(5); inc(t);
  end;
  Check(menuAsyncCalls=1,'a line runs its onClickAsync');
  // Esc restores the focus, nil included
  testMenu.OpenBelow(menuBtn);
  sceneA.DispatchKey(TKey.Escape,0,0,true);
  Check(not testMenu.IsOpen and (FocusedElement=edit),'Esc closes the menu and restores the focus');
  ClearFocus(wndA);
  testMenu.OpenBelow(menuBtn);
  sceneA.DispatchKey(TKey.Escape,0,0,true);
  Check(FocusedElement=nil,'no focus before - no focus after');
  // the mouse picks the current line, a disabled line clears it
  testMenu.OpenBelow(menuBtn);
  wndA.physPos:=CenterOf(itemSave);
  RunFrame(wndA);
  Check(testMenu.current=itemSave,'the line under the mouse is current');
  wndA.physPos:=CenterOf(itemUndo);
  RunFrame(wndA);
  Check(testMenu.current=nil,'a disabled line under the mouse is not current');
  // a click on a line runs it, a click on a disabled line does nothing
  PhysicalClickAt(CenterOf(itemUndo));
  Check(testMenu.IsOpen,'a click on a disabled line keeps the menu open');
  PhysicalClickAt(CenterOf(itemNew));
  Check((probe.news=1) and not testMenu.IsOpen,'a click on a line runs it and closes the menu');
  // a press outside closes the menu and reaches its target
  btn.clicks:=0;
  testMenu.OpenBelow(menuBtn);
  PhysicalClickAt(Types.Point(150,115));
  Check(not testMenu.IsOpen and (btn.clicks=1),'a click outside closes the menu and reaches the button');
  // the focus taken away closes the menu and stays with the taker
  testMenu.OpenBelow(menuBtn);
  edit.SetFocus;
  Check(not testMenu.IsOpen and (FocusedElement=edit),'a focus change closes the menu');
  // the remembered focus is removed while the menu is open
  edit2:=TUIEditBox.Create(100,20,sceneA.UI,'MenuEdit2');
  edit2.SetPos(500,330,pivotTopLeft);
  edit2.SetFocus;
  testMenu.OpenBelow(menuBtn);
  edit2.Remove;
  sceneA.DispatchKey(TKey.Escape,0,0,true);
  Check(FocusedElement=nil,'a removed focus is not restored');
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  testMenu.Remove;
  menuBtn.Remove;
  edit.Remove;
  ClearFocus(wndA);
  RunFrame(wndA);
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
  probe.Free;
  EndTest;
 end;

// Wait for an element timer: real time passes, the frames run the timers
procedure WaitFrames(ms:integer);
 var
  t:int64;
 begin
  t:=CoreTime.Ticks+ms;
  repeat
   Sleep(10);
   RunFrame(wndA);
  until CoreTime.Ticks>=t;
 end;

// Submenu fixture: SubTest = New, Recent files > (File1, More > (Deep)), Quit;
// an edit box holds the focus, the pointer is off the canvas
var
  sub:record
   probe:TMenuProbe;
   edit:TUIEditBox;
   menu,recent,deep:TUIPopupMenu;
   itemNew,itemRecent,itemFile1,itemDeep,itemDeepCmd,itemQuit:TUIMenuItem;
  end;

procedure BuildSubmenus;
 begin
  with sub do begin
   probe:=TMenuProbe.Create;
   edit:=TUIEditBox.Create(100,20,sceneA.UI,'SubEdit');
   edit.SetPos(500,400,pivotTopLeft);
   menu:=TUIPopupMenu.Create(sceneA.UI,'SubTest');
   itemNew:=menu.Add('New');
   itemNew.onClickMethod:=probe.DoNew;
   recent:=menu.AddSubmenu('Recent files');
   itemRecent:=TUIMenuItem(recent.ownerItem);
   itemFile1:=recent.Add('File1');
   itemFile1.onClickMethod:=probe.DoSave;
   deep:=recent.AddSubmenu('More');
   itemDeep:=TUIMenuItem(deep.ownerItem);
   itemDeepCmd:=deep.Add('Deep');
   itemDeepCmd.onClickMethod:=probe.DoQuit;
   itemQuit:=menu.Add('Quit');
   edit.SetFocus;
  end;
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  Sleep(60); // past the double-click guard of TUIButton.DoClick (lines of a previous test)
 end;

procedure FreeSubmenus;
 begin
  with sub do begin
   if not menu.deleted then menu.Remove;
   edit.Remove;
   wndA.physPos:=Types.Point(-1,-1);
   ClearFocus(wndA);
   RunFrame(wndA);
   probe.Free;
  end;
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
 end;

// Names follow the clickable line; a closed submenu lives in its line
procedure TestSubmenuNames;
 begin
  StartTest('Submenu names and links');
  BuildSubmenus;
  with sub do begin
   Check((itemRecent.name='SubTest\Recent_files') and (recent.name='SubTest\Recent_files_Menu'),
     'submenu names: '+itemRecent.name+', '+recent.name);
   Check((itemFile1.name='SubTest\Recent_files\File1') and (itemDeep.name='SubTest\Recent_files\More') and
     (itemDeepCmd.name='SubTest\Recent_files\More\Deep'),'line names follow the submenu line: '+itemFile1.name);
   Check((itemRecent.submenu=recent) and (recent.ownerItem=itemRecent) and (menu.ownerItem=nil) and
     (itemNew.submenu=nil),'line <-> submenu links');
   Check(not recent.IsOpen and (recent.parent=itemRecent),'a closed submenu lives in its line');
  end;
  FreeSubmenus;
  EndTest;
 end;

// Right/Enter open with the first line, Left/Escape close one level, one focus for the chain
procedure TestSubmenuKeys;
 var
  r,rr:TRect;
 begin
  StartTest('Submenu keys');
  BuildSubmenus;
  with sub do begin
   menu.OpenAt(250,150);
   Check(menu.IsOpen and (FocusedElement=menu),'the root menu takes the focus');
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Down,0,0,true);
   Check(menu.current=itemRecent,'Down reaches the submenu line');
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(recent.IsOpen and (recent.current=itemFile1),'Right opens the submenu at its first line');
   Check((FocusedElement=menu) and (menu.current=itemRecent),'the focus stays at the root menu, the parent line stays current');
   r:=menu.GetPosOnScreen;
   rr:=recent.GetPosOnScreen;
   Check(rr.Left>=r.Right-1,'the submenu is to the right of its parent');
   Check(System.Abs(itemFile1.GetPosOnScreen.Top-itemRecent.GetPosOnScreen.Top)<=1,'its first line is at the owner line');
   Check(recent.order>menu.order,'a deeper panel is above');
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Enter,0,0,true);
   Check(deep.IsOpen and (deep.current=itemDeepCmd),'Enter on a submenu line opens it');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not deep.IsOpen and recent.IsOpen and (recent.current=itemDeep),'Escape closes the deepest level only');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(not recent.IsOpen and menu.IsOpen and (menu.current=itemRecent),'Left closes a level, the parent line stays current');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(menu.IsOpen,'Left at the root menu does nothing');
   sceneA.DispatchKey(TKey.Up,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(menu.IsOpen and (menu.current=itemNew),'Right on a command does nothing');
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Enter,0,0,true);
   Check((probe.quits=1) and not menu.IsOpen and not recent.IsOpen and not deep.IsOpen,
     'a command of the third level runs and closes the whole chain');
   Check(FocusedElement=edit,'the focus is restored');
   Check((recent.parent=itemRecent) and (deep.parent=itemDeep),'closed submenus return to their lines');
   menu.OpenAt(250,150);
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not menu.IsOpen and (FocusedElement=edit),'Escape at the root menu ends the session');
  end;
  FreeSubmenus;
  EndTest;
 end;

// The hover delay opens and switches submenus; clicks inside the chain and outside it
procedure TestSubmenuMouse;
 begin
  StartTest('Submenu mouse');
  BuildSubmenus;
  with sub do begin
   menu.OpenAt(250,150);
   wndA.physPos:=CenterOf(itemRecent);
   RunFrame(wndA);
   Check((menu.current=itemRecent) and not recent.IsOpen,'hover does not open a submenu at once');
   WaitFrames(260);
   Check(recent.IsOpen and (recent.current=nil),'it opens after the delay, without a current line');
   wndA.physPos:=CenterOf(itemFile1);
   RunFrame(wndA);
   Check((recent.current=itemFile1) and (menu.current=itemRecent),'in the submenu the parent line stays current');
   PhysicalClickAt(CenterOf(itemFile1));
   Check((probe.saves=1) and not menu.IsOpen and not recent.IsOpen,'a click in a submenu runs the line, the chain closes');
   Check(probe.focusAtCall=edit,'the command finds the focus restored');
   // a click on a submenu line opens it at once; a command line closes it after the delay
   menu.OpenAt(250,150);
   PhysicalClickAt(CenterOf(itemRecent));
   Check(menu.IsOpen and recent.IsOpen,'a click on a submenu line opens it at once');
   wndA.physPos:=CenterOf(itemQuit);
   RunFrame(wndA);
   Check(recent.IsOpen,'a command line under the pointer: the submenu stays for the delay');
   WaitFrames(260);
   Check(not recent.IsOpen and menu.IsOpen,'then it closes');
   // back to the line before the delay: the switch is cancelled
   PhysicalClickAt(CenterOf(itemRecent));
   wndA.physPos:=CenterOf(itemNew);
   RunFrame(wndA);
   wndA.physPos:=CenterOf(itemRecent);
   RunFrame(wndA);
   WaitFrames(260);
   Check(recent.IsOpen and (menu.current=itemRecent),'back on the line in time: the submenu stays');
   // a press outside closes the whole chain and reaches its target
   btn.clicks:=0;
   PhysicalClickAt(Types.Point(150,115));
   Check(not menu.IsOpen and not recent.IsOpen and (btn.clicks=1),'a click outside closes the chain and reaches the button');
   Check(FocusedElement=btn,'the target of the click takes the focus as usual');
  end;
  FreeSubmenus;
  EndTest;
 end;

// The pointer away from the menu for a while closes it
procedure TestMenuAutoClose;
 var
  r:TRect;
  t:int64;
 begin
  StartTest('Menu auto close');
  BuildSubmenus;
  with sub do begin
   menu.autoCloseDelay:=300;
   menu.OpenAt(250,150);
   wndA.physPos:=CenterOf(itemNew);
   RunFrame(wndA);
   r:=menu.GetPosOnScreen;
   wndA.physPos:=Types.Point(r.Right+10,r.Top+5); // inside the margin
   WaitFrames(500);
   Check(menu.IsOpen,'the pointer near the menu keeps it open');
   wndA.physPos:=Types.Point(750,550);
   RunFrame(wndA);
   WaitFrames(150);
   Check(menu.IsOpen,'not at once');
   t:=CoreTime.Ticks+1500;
   while menu.IsOpen and (CoreTime.Ticks<t) do WaitFrames(20);
   Check(not menu.IsOpen and (FocusedElement=edit),'the pointer away from the menu closes it, the focus is restored');
   // opened with the pointer far away (from the keyboard): it waits for the pointer to move
   menu.OpenAt(250,150);
   WaitFrames(500);
   Check(menu.IsOpen,'a still pointer far away does not close a menu opened from the keyboard');
   wndA.physPos:=Types.Point(740,540);
   RunFrame(wndA);
   t:=CoreTime.Ticks+1500;
   while menu.IsOpen and (CoreTime.Ticks<t) do WaitFrames(20);
   Check(not menu.IsOpen,'its count starts when the pointer moves');
  end;
  FreeSubmenus;
  EndTest;
 end;

// Removed and freed lines, panels, anchors and owners
procedure TestSubmenuRemoval;
 var
  tmp1,tmp2:TUIMenuItem;
  anchorBtn:TProbeButton;
  ownerPanel:TUIElement;
  owned:TUIPopupMenu;
 begin
  StartTest('Submenu removal');
  BuildSubmenus;
  with sub do begin
   // lines removed while current or scheduled: the menu forgets them
   tmp1:=menu.Add('Temp1');
   tmp2:=TUIMenuItem(menu.AddSubmenu('Temp2').ownerItem);
   tmp2.submenu.Add('Inner');
   menu.OpenAt(250,150);
   menu.current:=tmp1;
   tmp1.Remove;
   RunFrame(wndA);
   sceneA.DispatchKey(TKey.Enter,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(menu.IsOpen and (menu.current=nil),'the removed current line is forgotten');
   wndA.physPos:=CenterOf(tmp2);
   RunFrame(wndA);
   Check(menu.current=tmp2,'hover on a submenu line schedules its submenu');
   tmp2.Remove;
   RunFrame(wndA);
   WaitFrames(260);
   Check(menu.IsOpen and (menu.current=nil) and (TUIElement.FindByName('SubTest\Temp2_Menu')=nil),
     'a scheduled line removed: nothing opens');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   wndA.physPos:=Types.Point(-1,-1);
   RunFrame(wndA);
   // a line freed directly while current
   tmp1:=menu.Add('Temp3');
   menu.OpenAt(250,150);
   menu.current:=tmp1;
   tmp1.Free;
   sceneA.DispatchKey(TKey.Enter,0,0,true);
   Check(menu.IsOpen and (menu.current=nil),'a freed current line is forgotten');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   // the anchor removed while the menu is open: the menu closes
   anchorBtn:=NewButton(sceneA.UI,'SubAnchor',600,100);
   menu.OpenBelow(anchorBtn);
   Check(menu.IsOpen,'opened below an anchor');
   anchorBtn.Remove;
   WaitFrames(150);
   Check(not menu.IsOpen,'its anchor removed: the menu closes');
   // the owner removed, the menu closed at once (before its timer): the menu goes too
   ownerPanel:=TUIElement.Create(100,100,sceneA.UI,'SubOwner');
   owned:=TUIPopupMenu.Create(ownerPanel,'OwnedMenu');
   owned.Add('A');
   owned.OpenAt(250,150);
   ownerPanel.Remove;
   owned.Close;
   RunFrame(wndA);
   Check(TUIElement.FindByName('OwnedMenu')=nil,'a menu closed after its owner was removed is removed');
   owned:=TUIPopupMenu.Create(sceneA.UI,'OwnedMenu'); // the name is free again
   Check(owned.name='OwnedMenu','a new menu takes the name');
   owned.Remove;
   // an open submenu freed directly
   edit.SetFocus;
   menu.OpenAt(250,150);
   menu.current:=itemRecent;
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(recent.IsOpen,'submenu open');
   recent.Free;
   Check(itemRecent.submenu=nil,'a freed submenu leaves its line');
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(menu.IsOpen and (FocusedElement=menu),'keys go on in the root menu');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not menu.IsOpen and (FocusedElement=edit),'and it closes');
   // the line of an open submenu is removed: the branch closes, the panel goes with the line
   recent:=menu.AddSubmenu('Again');
   deep:=recent.AddSubmenu('Inner');
   deep.Add('X');
   menu.OpenAt(250,150);
   menu.current:=TUIMenuItem(recent.ownerItem);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(recent.IsOpen and deep.IsOpen,'two levels open');
   recent.ownerItem.Remove;
   Check(not recent.IsOpen and not recent.flags.visible and menu.IsOpen,'its line removed: the submenu is hidden');
   RunFrame(wndA);
   Check((TUIElement.FindByName('SubTest\Again_Menu')=nil) and (TUIElement.FindByName('SubTest\Again\Inner_Menu')=nil),
     'the submenus are removed with the line');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not menu.IsOpen and (FocusedElement=edit),'the root menu still closes');
   // a removed root menu takes its open chain along
   recent:=menu.AddSubmenu('Last');
   recent.Add('X');
   menu.OpenAt(250,150);
   menu.current:=TUIMenuItem(recent.ownerItem);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(recent.IsOpen,'another submenu open');
   menu.Remove;
   RunFrame(wndA);
   Check((TUIElement.FindByName('SubTest\Last_Menu')=nil) and (TUIPopup.Current(wndA)=nil),'a removed root menu takes its submenus');
  end;
  FreeSubmenus;
  EndTest;
 end;

// Menu bar fixture: MainBar = File (New, Recent > File1, Quit), Edit (Undo, Copy), View (disabled),
// Help (About); 500x24 at (20,200); an edit box holds the focus, the pointer is off the canvas
var
  mb:record
   probe:TMenuProbe;
   edit:TUIEditBox;
   bar:TUIMenuBar;
   fileM,recent,editM,viewM,helpM:TUIPopupMenu;
   hFile,hEdit,hView,hHelp:TUIMenuHeading;
   itemNew,itemRecent,itemFile1,itemUndo,itemAbout:TUIMenuItem;
  end;

procedure BuildMenuBar;
 begin
  with mb do begin
   probe:=TMenuProbe.Create;
   edit:=TUIEditBox.Create(100,20,sceneA.UI,'BarEdit');
   edit.SetPos(600,450,pivotTopLeft);
   bar:=TUIMenuBar.Create(sceneA.UI,'MainBar');
   bar.SetPos(20,200,pivotTopLeft);
   bar.size:=Vec2(500,24);
   fileM:=bar.AddSubmenu('File');
   hFile:=TUIMenuHeading(fileM.ownerItem);
   itemNew:=fileM.Add('New');
   itemNew.onClickMethod:=probe.DoNew;
   recent:=fileM.AddSubmenu('Recent');
   itemRecent:=TUIMenuItem(recent.ownerItem);
   itemFile1:=recent.Add('File1');
   itemFile1.onClickMethod:=probe.DoSave;
   fileM.Add('Quit').onClickMethod:=probe.DoQuit;
   editM:=bar.AddSubmenu('Edit');
   hEdit:=TUIMenuHeading(editM.ownerItem);
   itemUndo:=editM.Add('Undo');
   editM.Add('Copy');
   viewM:=bar.AddSubmenu('View');
   hView:=TUIMenuHeading(viewM.ownerItem);
   viewM.Add('Zoom');
   hView.Disable;
   helpM:=bar.AddSubmenu('Help');
   hHelp:=TUIMenuHeading(helpM.ownerItem);
   itemAbout:=helpM.Add('About');
   edit.SetFocus;
  end;
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
 end;

procedure FreeMenuBar;
 begin
  with mb do begin
   if not bar.deleted then bar.Remove;
   edit.Remove;
   wndA.physPos:=Types.Point(-1,-1);
   ClearFocus(wndA);
   RunFrame(wndA);
   probe.Free;
  end;
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
 end;

// Names, the row of headings, links
procedure TestMenuBarLayout;
 begin
  StartTest('Menu bar layout');
  BuildMenuBar;
  with mb do begin
   Check((hFile.name='MainBar\File') and (fileM.name='MainBar\File_Menu') and (itemNew.name='MainBar\File\New') and
     (itemRecent.name='MainBar\File\Recent') and (itemFile1.name='MainBar\File\Recent\File1'),
     'names follow the headings: '+hFile.name+', '+fileM.name+', '+itemFile1.name);
   Check((hFile.popup=fileM) and (fileM.ownerItem=hFile) and (hFile.Bar=bar) and (fileM.parent=hFile),
     'heading <-> menu links, a closed menu lives in its heading');
   Check((hFile.GetPosOnScreen.Left=20) and (hEdit.GetPosOnScreen.Left=hFile.GetPosOnScreen.Right) and
     (hHelp.GetPosOnScreen.Left=hView.GetPosOnScreen.Right),'the headings are in a row');
   Check((hFile.size.y=24) and (hFile.size.x>16) and (hFile.size.x=hEdit.size.x),'a heading takes the bar height and its caption width');
   Check(not hFile.flags.canHaveFocus and not bar.flags.canHaveFocus,'neither the bar nor the headings take the focus by a click');
   Check(not bar.IsOpen and (bar.current=nil),'closed');
  end;
  FreeMenuBar;
  EndTest;
 end;

// The mouse: a click opens, hover switches the open bar, a click on the open heading closes
procedure TestMenuBarMouse;
 var
  r:TRect;
  ctx:TUIPopupMenu;
 begin
  StartTest('Menu bar mouse');
  BuildMenuBar;
  with mb do begin
   wndA.physPos:=CenterOf(hEdit);
   RunFrame(wndA);
   Check(not bar.IsOpen,'hover over a closed bar opens nothing');
   PhysicalClickAt(CenterOf(hFile));
   Check(bar.IsOpen and fileM.IsOpen and (bar.current=hFile),'a click opens the menu of the heading');
   Check((FocusedElement=bar) and (fileM.current=nil),'the bar holds the focus, opened by the mouse - no current line');
   r:=hFile.GetPosOnScreen;
   Check((fileM.GetPosOnScreen.Top>=r.Bottom-1) and (System.Abs(fileM.GetPosOnScreen.Left-r.Left)<=1),
     'the menu is below its heading, left aligned');
   Check(TElementState.Selected in hFile.GetStates,'the open heading is selected');
   Check(TUIPopup.Current(wndA)=fileM,'the menu is the popup of the window');
   wndA.physPos:=CenterOf(hEdit);
   RunFrame(wndA);
   Check(editM.IsOpen and not fileM.IsOpen and (bar.current=hEdit) and (FocusedElement=bar),
     'hover over another heading switches at once, the bar keeps the focus');
   Check(fileM.parent=hFile,'the closed menu is back in its heading');
   wndA.physPos:=CenterOf(hView);
   RunFrame(wndA);
   Check(editM.IsOpen and (bar.current=hEdit),'a disabled heading does not switch');
   PhysicalClickAt(CenterOf(hEdit));
   Check(not bar.IsOpen and not editM.IsOpen and (FocusedElement=edit),'a click on the open heading closes, the focus is back');
   // a line of the menu: the command finds the focus restored
   PhysicalClickAt(CenterOf(hFile));
   PhysicalClickAt(CenterOf(itemNew));
   Check((probe.news=1) and not bar.IsOpen and (probe.focusAtCall=edit),'a click on a line runs it after the session ends');
   // a submenu by hover from the bar menu
   PhysicalClickAt(CenterOf(hFile));
   wndA.physPos:=CenterOf(itemRecent);
   RunFrame(wndA);
   WaitFrames(260);
   Check(recent.IsOpen,'a submenu opens by hover');
   PhysicalClickAt(CenterOf(itemFile1));
   Check((probe.saves=1) and not bar.IsOpen and not recent.IsOpen and (FocusedElement=edit),'its line runs, all closes');
   // a press outside closes and reaches its target
   PhysicalClickAt(CenterOf(hFile));
   btn.clicks:=0;
   PhysicalClickAt(Types.Point(150,115));
   Check(not bar.IsOpen and (btn.clicks=1),'a click outside closes the session and reaches the button');
   edit.SetFocus;
   // a press on the bar between the headings
   PhysicalClickAt(CenterOf(hFile));
   PhysicalClickAt(Types.Point(510,212));
   Check(not bar.IsOpen and (FocusedElement=edit),'a press on the empty bar closes');
   // the focus taken away
   PhysicalClickAt(CenterOf(hFile));
   edit.SetFocus;
   Check(not bar.IsOpen and not fileM.IsOpen and (FocusedElement=edit),'a focus change ends the session');
   // an open context menu closes when the bar opens, the focus returns to the edit box
   wndA.physPos:=Types.Point(-1,-1);
   RunFrame(wndA);
   ctx:=TUIPopupMenu.Create(sceneA.UI,'BarContext');
   ctx.Add('X');
   ctx.OpenAt(600,250);
   Check(FocusedElement=ctx,'context menu open');
   PhysicalClickAt(CenterOf(hFile));
   Check(not ctx.IsOpen and bar.IsOpen and (FocusedElement=bar),'a click on the bar closes the context menu and opens the bar');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not bar.IsOpen and (FocusedElement=edit),'the focus returns to where it was before both');
   ctx.Remove;
  end;
  FreeMenuBar;
  EndTest;
 end;

// Left/Right go round the headings, skip the disabled one; other keys go to the menus
procedure TestMenuBarKeys;
 begin
  StartTest('Menu bar keys');
  BuildMenuBar;
  with mb do begin
   bar.autoCloseDelay:=0; // no frames run between the keys, still: the pointer is off the canvas
   PhysicalClickAt(CenterOf(hFile));
   wndA.physPos:=Types.Point(-1,-1);
   RunFrame(wndA);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(editM.IsOpen and (editM.current=itemUndo) and (FocusedElement=bar),'Right without a current line: the next heading, its first line');
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(helpM.IsOpen and (bar.current=hHelp),'Right skips the disabled heading');
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(fileM.IsOpen and (fileM.current=itemNew),'Right wraps around');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(helpM.IsOpen and (helpM.current=itemAbout),'Left wraps back');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(fileM.IsOpen,'Left: Help -> Edit -> File');
   sceneA.DispatchKey(TKey.Down,0,0,true);
   Check(fileM.current=itemRecent,'Down goes to the menu');
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(recent.IsOpen and (recent.current=itemFile1) and fileM.IsOpen,'Right on a submenu line opens it');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(not recent.IsOpen and fileM.IsOpen,'Left in a submenu closes it');
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   Check(editM.IsOpen and not recent.IsOpen and not fileM.IsOpen,'Right on a command of a submenu: the next heading');
   Check(sceneA.DispatchKey(TKey.B,0,0,true) and bar.IsOpen,'other keys stop at the bar');
   sceneA.DispatchKey(TKey.Left,0,0,true);
   sceneA.DispatchKey(TKey.Down,0,0,true);
   sceneA.DispatchKey(TKey.Right,0,0,true);
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(fileM.IsOpen and not recent.IsOpen,'Escape in a submenu closes one level');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not bar.IsOpen and (FocusedElement=edit),'Escape at the top level ends the session, the focus is back');
   // Enter runs a command after the session ends
   bar.OpenItem(hFile,true);
   Check(fileM.IsOpen and (fileM.current=itemNew) and (FocusedElement=bar),'OpenItem from the keyboard: the first line');
   sceneA.DispatchKey(TKey.Enter,0,0,true);
   Check((probe.news=1) and not bar.IsOpen and (probe.focusAtCall=edit),'Enter runs the line, the focus is restored before');
   // current
   bar.current:=hEdit;
   Check(editM.IsOpen and (bar.current=hEdit),'current:= opens the heading');
   bar.current:=hView;
   Check(editM.IsOpen and (bar.current=hEdit),'a disabled heading can not be current');
   bar.current:=nil;
   Check(not bar.IsOpen and (FocusedElement=edit),'current:=nil closes');
  end;
  FreeMenuBar;
  EndTest;
 end;

// The onOpen of a menu opens another heading or closes the bar: the newer request wins
type
  TBarCallbacks=class
   procedure OpenEdit;
   procedure CloseBar;
  end;

procedure TBarCallbacks.OpenEdit;
 begin
  mb.bar.OpenItem(mb.hEdit);
 end;

procedure TBarCallbacks.CloseBar;
 begin
  mb.bar.Close;
 end;

procedure TestMenuBarCallbacks;
 var
  cb:TBarCallbacks;
 begin
  StartTest('Menu bar onOpen');
  BuildMenuBar;
  cb:=TBarCallbacks.Create;
  with mb do begin
   fileM.onOpen:=cb.OpenEdit;
   bar.OpenItem(hFile);
   Check(editM.IsOpen and not fileM.IsOpen and (bar.current=hEdit) and bar.IsOpen,
     'onOpen of File opens Edit: Edit stays open');
   Check((FocusedElement=bar) and (TUIPopup.Current(wndA)=editM),'the session goes on with Edit');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   Check(not bar.IsOpen and (FocusedElement=edit),'and ends as usual');
   fileM.onOpen:=cb.CloseBar;
   bar.OpenItem(hFile);
   Check(not bar.IsOpen and not fileM.IsOpen and (FocusedElement=edit) and (TUIPopup.Current(wndA)=nil),
     'onOpen closes the bar: nothing opens, the focus is back');
   fileM.onOpen:=nil;
  end;
  cb.Free;
  FreeMenuBar;
  EndTest;
 end;

// Auto close: the zone is the menus and the whole bar
procedure TestMenuBarAutoClose;
 var
  t:int64;
 begin
  StartTest('Menu bar auto close');
  BuildMenuBar;
  with mb do begin
   bar.autoCloseDelay:=300;
   PhysicalClickAt(CenterOf(hFile));
   wndA.physPos:=Types.Point(505,212); // the empty end of the bar
   RunFrame(wndA);
   WaitFrames(500);
   Check(bar.IsOpen,'the pointer over the bar keeps the menu open');
   wndA.physPos:=Types.Point(750,550);
   RunFrame(wndA);
   t:=CoreTime.Ticks+1500;
   while bar.IsOpen and (CoreTime.Ticks<t) do WaitFrames(20);
   Check(not bar.IsOpen and (FocusedElement=edit),'the pointer away closes the session, the focus is restored');
  end;
  FreeMenuBar;
  EndTest;
 end;

// Headings that don't fit scroll: the open one is shown
procedure TestMenuBarScroll;
 var
  r,rb:TRect;
 begin
  StartTest('Menu bar scroll');
  BuildMenuBar;
  with mb do begin
   bar.size:=Vec2(100,24); // narrower than the headings: 4 captions of 4 letters
   bar.Arrange;
   bar.OpenItem(hFile,true);
   sceneA.DispatchKey(TKey.Left,0,0,true);
   Check(helpM.IsOpen and (bar.scroll.X>0),'the open heading scrolls into view');
   r:=hHelp.GetPosOnScreen;
   rb:=bar.GetPosOnScreen;
   Check((r.Left>=rb.Left) and (r.Right<=rb.Right),'it is inside the bar');
   Check(System.Abs(helpM.GetPosOnScreen.Left-r.Left)<=1,'its menu is below it');
   sceneA.DispatchKey(TKey.Escape,0,0,true);
   bar.onMouseScroll(10000);
   Check(bar.scroll.X=0,'the wheel scrolls back to the start');
   bar.onMouseScroll(-10000);
   Check(System.Abs(bar.scroll.X-(hHelp.position.x+hHelp.size.x-100))<0.01,'and to the end, not past it');
  end;
  FreeMenuBar;
  EndTest;
 end;

// Removed headings and bars
procedure TestMenuBarRemoval;
 begin
  StartTest('Menu bar removal');
  BuildMenuBar;
  with mb do begin
   // the heading of the open menu is removed: the menu goes, the session ends
   bar.OpenItem(hEdit);
   hEdit.Remove;
   WaitFrames(300);
   Check(not bar.IsOpen and (TUIElement.FindByName('MainBar\Edit_Menu')=nil) and (TUIPopup.Current(wndA)=nil),
     'the open heading removed: its menu goes');
   Check(FocusedElement=edit,'the session ends, the focus is back');
   // Clear while open
   bar.OpenItem(hFile);
   bar.Clear;
   Check(not bar.IsOpen and (FocusedElement=edit) and (length(bar.children)=0),'Clear ends the session and removes the headings');
   RunFrame(wndA);
   Check(TUIElement.FindByName('MainBar\File_Menu')=nil,'the menus go with the headings');
   // the bar removed while open
   helpM:=bar.AddSubmenu('Help');
   helpM.Add('About');
   bar.OpenItem(TUIMenuHeading(helpM.ownerItem));
   Check(helpM.IsOpen,'a new heading opens');
   bar.Remove;
   WaitFrames(300);
   Check((TUIElement.FindByName('MainBar\Help_Menu')=nil) and (TUIPopup.Current(wndA)=nil),'a removed bar takes its open menu');
   bar:=TUIMenuBar.Create(sceneA.UI,'MainBar'); // for FreeMenuBar
  end;
  FreeMenuBar;
  EndTest;
 end;

procedure PhysicalButton(pressed:boolean);
 var
  n:integer;
 begin
  n:=length(wndA.physEvents);
  SetLength(wndA.physEvents,n+1);
  wndA.physEvents[n].btn:=1;
  wndA.physEvents[n].pressed:=pressed;
 end;

// The input frame: button events go to the mask at once, Process sees the transitions
// of its frame (also of a click shorter than a frame) exactly once
procedure TestInputFrame;
 var
  probe,probe2:TProbeScene;
  i:integer;
 begin
  StartTest('Physical buttons and the input frame');
  probe:=TProbeScene.Create('Probe',false,wndA);
  probe.rect:=Types.Rect(100,100,200,130); // the button
  probe.SetStatus(ssActive);
  probe2:=TProbeScene.Create('Probe2',false,wndA);
  probe2.SetStatus(ssActive);
  wndA.physPos:=Types.Point(150,115);
  RunFrame(wndA);
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
  probe.Reset; probe2.Reset;
  // a slow click: press, held, release
  PhysicalButton(true);
  RunFrame(wndA);
  Check(btn.downs=1,'the press reaches the button');
  Check(wndA.mouseButtons=mbLeft,'the event sets the mask');
  Check(probe.pressed=1,'Process sees WasPressed in the press frame');
  Check(probe.down=1,'and Down');
  Check(probe2.pressed=1,'another scene sees the same press');
  for i:=1 to 3 do RunFrame(wndA);
  Check(probe.pressed=1,'WasPressed only in the press frame');
  Check(probe.down=4,'Down while held');
  PhysicalButton(false);
  RunFrame(wndA);
  Check(wndA.mouseButtons=0,'the release clears the mask');
  Check(probe.released=1,'Process sees WasReleased in the release frame');
  Check(btn.clicks=1,'slow click done');
  RunFrame(wndA);
  Check(probe.released=1,'WasReleased only once');
  // a click shorter than a frame
  probe.Reset; btn.clicks:=0;
  wndA.PhysicalClick(150,115);
  RunFrame(wndA);
  Check(btn.clicks=1,'the fast click reaches the button');
  Check(probe.pressed=1,'fast click: WasPressed');
  Check(probe.released=1,'fast click: WasReleased');
  Check(probe.down=0,'fast click: not Down');
  RunFrame(wndA);
  Check(probe.pressed=1,'fast click edges last one frame');
  // a lost release (the OS capture taken away): the next press is still a press
  wndA.physPos:=Types.Point(700,500);
  RunFrame(wndA);
  probe.Reset;
  PhysicalButton(true);
  RunFrame(wndA);
  PhysicalButton(true);
  RunFrame(wndA);
  Check(probe.pressed=2,'a press after a lost release is a new press');
  PhysicalButton(false);
  RunFrame(wndA);
  Check(wndA.mouseButtons=0,'and its release clears the mask');
  // the pointer at this and the previous frame
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  Check(probe.outside and Mouse.Outside,'the pointer outside the window is Outside');
  wndA.physPos:=Types.Point(150,115);
  RunFrame(wndA);
  Check(probe.inRect,'InRect after entering');
  Check(not probe.wasInRect,'not WasInRect in the entering frame');
  RunFrame(wndA);
  Check(probe.wasInRect,'WasInRect a frame later');
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  Check(not probe.inRect,'not InRect after leaving');
  Check(probe.wasInRect,'WasInRect in the leaving frame');
  RunFrame(wndA);
  Check(not probe.wasInRect,'not WasInRect a frame later');
  // a drag leaving the canvas: the position is clamped to the edge, the pointer is Outside
  wndA.physPos:=Types.Point(700,500);
  RunFrame(wndA);
  PhysicalButton(true);
  RunFrame(wndA);
  wndA.physPos:=Types.Point(900,500);
  RunFrame(wndA);
  Check(Mouse.Pos.x=799,'drag outside: clamped to the edge');
  Check(Mouse.Outside,'drag outside: Outside');
  Check(not Mouse.InRect(Types.Rect(790,490,800,510)),'drag outside: not InRect at the edge');
  PhysicalButton(false);
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  // keyboard: the same frame boundary
  wndA.KeyTransition(Scan.A,TKey.A,true); // as TGame.KeyPressed
  RunFrame(wndA);
  Check(IsKeyPressed(Scan.A),'key: pressed in its frame');
  wndA.KeyTransition(Scan.A,TKey.A,true); // auto-repeat
  RunFrame(wndA);
  Check(not IsKeyPressed(Scan.A) and IsKeyDown(Scan.A),'key: then only down, auto-repeat included');
  wndA.KeyTransition(Scan.A,TKey.A,false);
  RunFrame(wndA);
  Check(IsKeyReleased(Scan.A),'key: released in its frame');
  RunFrame(wndA);
  Check(not IsKeyReleased(Scan.A),'key: released only once');
  // a press shorter than a frame is seen
  wndA.KeyTransition(Scan.Up,TKey.Up,true);
  wndA.KeyTransition(Scan.Up,TKey.Up,false);
  RunFrame(wndA);
  Check(IsKeyPressed(Scan.Up) and IsKeyReleased(Scan.Up) and not IsKeyDown(Scan.Up),'key: short press');
  Check(not wndA.KeyTransition(Scan.Up,TKey.Up,false),'key: a release of a key that is not down is dropped');
  // the platform lost the pointer mid-gesture: released without a click
  wndA.physPos:=Types.Point(150,115);
  RunFrame(wndA);
  probe.Reset; btn.clicks:=0;
  PhysicalButton(true);
  RunFrame(wndA);
  wndA.PlatformCancelGesture;
  RunFrame(wndA);
  Check(wndA.mouseButtons=0,'cancel: no buttons held');
  Check(probe.released=1,'cancel: WasReleased');
  Check(btn.clicks=0,'cancel: no click');
  Check(not btn.pressed,'cancel: the button is not pressed');
  wndA.physPos:=Types.Point(-1,-1);
  RunFrame(wndA);
  // a nested pass is refused
  probe.Reset;
  probe.nest:=true;
  RunFrame(wndA);
  Check(probe.frames=1,'a nested OnFrame does not process the scenes');
  probe.SetStatus(ssFrozen);
  probe2.SetStatus(ssFrozen);
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
  EndTest;
 end;

procedure TestEnable;
 var
  a:String8;
 begin
  StartTest('input.mode virtual');
  wndA.physPos:=Types.Point(150,115); // the OS pointer sits on the button
  RunFrame(wndA);
  Check(underMouse=btn,'physical hover before');
  a:=Robot(Req('m','input.mode','MODE: virtual'));
  Check(IsOk(a,'m'),'mode switched: '+a);
  Check(Field(a,'m','mode')='virtual','reported mode');
  Check(Field(a,'m','position')='outside','the virtual pointer starts outside the canvas');
  Check(wndA.virtualInput.IsActive,'window is in the virtual mode');
  Check(underMouse=nil,'the physical hover is gone');
  Check(Mouse.Simulated,'Mouse.Simulated sees the virtual mode');
  Check(not Mouse.InRect(Types.Rect(0,0,$10000,$10000)),'Mouse: no rect holds a pointer outside the canvas');
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
  Check((Mouse.X=150) and (Mouse.Y=115),'Mouse.X/Y read the window pointer');
  Check(Mouse.InRect(Types.Rect(150,115,151,116)),'Mouse.InRect(TRect): left/top edges included');
  Check(not Mouse.InRect(Types.Rect(140,110,150,115)),'Mouse.InRect(TRect): right/bottom edges excluded');
  Check(Mouse.InRect(Rect2(140,110,160,120)),'Mouse.InRect(TRect2)');
  Check(Mouse.InCircle(153,119,5),'Mouse.InCircle');
  a:=Robot(Req('e','ui.element','NAME: Btn'));
  Check(Field(a,'e','underMouse')='true','ui.element sees the hover');
  a:=Robot(Req('h','ui.hittest','X: 150;Y: 115'));
  Check(Field(a,'h','hit')='Btn','ui.hittest agrees on the coordinates');
  a:=Move(5,5);
  Check(underMouse=btn.parent,'leaving the button: hover goes to the root');
  Check(btn.clicks=0,'no clicks from moves');
  EndTest;
 end;

// Frames with the scene processing (hint timing) for ms milliseconds; the hint text shown
// in wndA at the end ('' - none)
function HintAfter(ms:integer):String8;
 var
  start:int64;
  h:TUIHint;
 begin
  start:=CoreTime.Ticks;
  repeat
   RunFrame(wndA);
   sceneA.Process;
   Sleep(5);
  until CoreTime.Ticks-start>ms;
  h:=TUIHint.Current(wndA);
  if (h<>nil) and h.flags.visible then result:=h.simpleText
   else result:='';
 end;

procedure DropHint;
 begin
  if TUIHint.Current(wndA)<>nil then TUIHint.Current(wndA).Remove;
 end;

// A hint planned for an element must not show once the element is hidden with its scene
// and the mouse did not move (PaintRaw E-30)
procedure TestHintHiddenScene;
 begin
  StartTest('Hint of an element hidden with its scene');
  btnDlg.hint:='DlgHint';
  btnDlg.attributes.Item['hintDelay']:='50';
  try
   dialog.SetStatus(ssActive);
   Move(5,5);
   Move(330,315);
   Check(HintAfter(150)='DlgHint','the hint shows for a visible element');
   DropHint;
   Move(5,5);
   Move(330,315);
   dialog.SetStatus(ssFrozen);
   Check(HintAfter(150)='','no hint after SetStatus(ssFrozen)');
   DropHint;
   dialog.SetStatus(ssActive);
   Move(5,5);
   Move(330,315);
   TShowWindowEffect.Create(dialog,120,sweHide,1);
   wndA.ProcessEffects(0,true);
   Check(HintAfter(150)='','no hint after a hide effect');
  finally
   DropHint;
   dialog.SetStatus(ssFrozen);
   btnDlg.hint:='';
   Move(5,5);
  end;
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
  Check(Mouse.Down,'Mouse.Down sees the left button');
  Check(not Mouse.Down(mbRight),'Mouse.Down(mbRight): the right one is up');
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
  a:=Robot(Batch([Req('1','mouse.click','X: 120;Y: 105;WAIT: no'),Req('2','input.wait')]));
  Check(Field(a,'1','state')='queued','WAIT: no answers before applying');
  Check(IsOk(a,'2') and (Field(a,'2','queued')='0'),'input.wait answers once the queue is empty');
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

// The scene that gets the keys: a modal scene pushes its own root (B-56)
procedure TestKeyboardTarget;
 var
  g:TKbdGame;
 begin
  StartTest('Keyboard target scene');
  // TopmostSceneForKbd reads only the current window: no constructor (it wants a platform)
  g:=TKbdGame(TKbdGame.NewInstance);
  try
   Check(g.KbdTarget=sceneA,'no modal: the topmost active scene');
   dialog.SetStatus(ssActive);
   wndA.modal.Push(dialog.UI);
   try
    Check(g.KbdTarget=dialog,'the modal scene gets the keys');
   finally
    wndA.modal.Pop(dialog.UI);
    dialog.SetStatus(ssFrozen);
   end;
  finally
   g.FreeInstance;
  end;
  EndTest;
 end;

// Edit box shortcuts with the right-side modifiers (B-57), Tab and Shift+Tab (B-58)
procedure TestEditKeys;
 var
  form:TUIScene;
  panel:TUIElement;
  e1,e2,e3:TUIEditBox;
 begin
  StartTest('Edit box keys');
  form:=TUIScene.Create('Form',false,wndA); // active only here: no part in the mouse tests
  form.SetStatus(ssActive); // an inactive scene has its UI disabled: Tab skips it
  panel:=TUIElement.Create(300,200,form.UI,'FormPanel');
  e1:=TUIEditBox.Create(100,20,panel,'Edit1');
  e2:=TUIEditBox.Create(100,20,panel,'Edit2');
  e3:=TUIEditBox.Create(100,20,panel,'Edit3');
  e1.text:='Login';
  e1.SetFocus;
  e1.selCount:=0;
  e1.onKey(ord('A'),true,sscCtrl or sscRCtrl);
  Check(e1.selCount=5,'right Ctrl+A selects all');
  e1.onKey(ord(TKey.Tab),true,0);
  Check(FocusedElement=e2,'Tab goes forward');
  e2.onKey(ord(TKey.Tab),true,sscShift);
  Check(FocusedElement=e1,'Shift+Tab goes back');
  e1.onKey(ord(TKey.Tab),true,sscShift or sscRShift);
  Check(FocusedElement=e3,'Shift+Tab from the first wraps to the last');
  ClearFocus(wndA);
  form.SetStatus(ssFrozen);
  EndTest;
 end;

// Methods as widget events: buttons, the edits of the user in an edit box, Enter
procedure TestEventMethods;
 var
  form:TUIScene;
  probe:TEventProbe;
  b:TUIButton;
  t:TUIToggleButton;
  e:TUIEditBox;
 begin
  StartTest('Event methods');
  probe:=TEventProbe.Create;
  form:=TUIScene.Create('EventForm',false,wndA); // never active: no part in the mouse tests
  b:=TUIButton.Create(100,20,form.UI,'EventBtn');
  b.onClickMethod:=probe.DoClick;
  b.pending:=true;
  b.onHotKey(0,0);
  Check(probe.clicks=0,'a pending button does not call the method');
  b.pending:=false;
  b.onHotKey(0,0);
  Check(probe.clicks=1,'a click calls the method');
  b.onHotKey(0,0);
  Check(probe.clicks=1,'the double-click guard covers the method');
  t:=TUIToggleButton.Create(100,20,form.UI,'EventToggle');
  t.onClickMethod:=probe.DoClick;
  t.onMouseButtons(1,true);
  Check(probe.clicks=2,'a toggle button calls the method');

  e:=TUIEditBox.Create(100,20,form.UI,'EventEdit');
  e.onChange:=probe.DoChange;
  e.onEnter:=probe.DoEnter;
  e.text:='abc';
  Check(probe.changes=0,'assigning the text is not an edit');
  e.cursorPos:=3;
  e.onUniChar(Char32('d'),0);
  Check((e.text='abcd') and (probe.changes=1),'typing calls onChange');
  e.SelectAll;
  e.onUniChar(Char32('x'),0);
  Check((e.text='x') and (probe.changes=2),'typing over a selection calls onChange');
  e.onKey(ord('Z'),true,sscCtrl);
  Check((e.text='abcd') and (probe.changes=3),'undo returns the text before the selection was replaced');
  e.onKey(ord(TKey.Left),true,0);
  Check(probe.changes=3,'moving the caret is not an edit');

  Check(not e.onKey(ord(TKey.Enter),true,0),'Enter is consumed by onEnter');
  Check(probe.enters=1,'Enter calls onEnter');
  Check(e.onKey(ord(TKey.Enter),true,sscCtrl),'Ctrl+Enter goes on');
  Check(probe.enters=1,'Ctrl+Enter does not call onEnter');
  e.onEnter:=nil;
  Check(e.onKey(ord(TKey.Enter),true,0),'with no onEnter the key goes on');
  e.onEnter:=probe.DoEnter;
  e.onKey(ord(TKey.EndKey),true,0);
  e.completion:=UTF8.Decode('abcdef');
  Check(not e.onKey(ord(TKey.Enter),true,0),'a completion takes Enter');
  Check((e.text='abcdef') and (probe.enters=1),'and onEnter is not called');
  Check(probe.changes=4,'the accepted completion is an edit');
  probe.Free;
  EndTest;
 end;

// The gray tail of an edit box continues the current text: a change of the text drops it,
// and it counts only while it fits the text and the caret is at the end
procedure TestCompletion;
 var
  form:TUIScene;
  probe:TEventProbe;
  e:TUIEditBox;
 begin
  StartTest('Completion');
  probe:=TEventProbe.Create;
  form:=TUIScene.Create('CompletionForm',false,wndA); // never active: no part in the mouse tests
  e:=TUIEditBox.Create(100,20,form.UI,'CompletionEdit');
  e.onEnter:=probe.DoEnter;

  e.completion:=UTF8.Decode('abcdef');
  Check(e.HasCompletion,'it continues an empty text');
  e.onUniChar(Char32('a'),0);
  Check(e.completion.IsEmpty,'typing drops it');
  e.completion:=UTF8.Decode('abcdef');
  Check(e.HasCompletion,'it continues the text');
  e.cursorPos:=0;
  Check(not e.HasCompletion,'the caret left the end');
  e.onKey(ord(TKey.Enter),true,0);
  Check((e.text='a') and (probe.enters=1),'Enter does not take it then');
  e.onKey(ord(TKey.EndKey),true,0);
  e.selStart:=0;
  e.selCount:=1;
  Check(not e.HasCompletion,'a selection hides it');
  e.selCount:=0;
  e.realText:=UTF8.Decode('abx');
  e.cursorPos:=3;
  Check(not e.HasCompletion,'text assigned to realText does not lead to it');
  e.onKey(ord(TKey.Enter),true,0);
  Check((e.text='abx') and (probe.enters=2),'Enter does not take a tail of another text');

  e.text:='aB';
  Check(e.completion.IsEmpty,'assigning another text drops it');
  e.completion:=UTF8.Decode('abcdef');
  e.text:='aB';
  Check(not e.completion.IsEmpty,'assigning the same text keeps it');
  e.cursorPos:=2;
  Check(e.HasCompletion,'letter case does not matter');
  e.completion:=UTF8.Decode('ab');
  Check(not e.HasCompletion,'nothing to add');
  e.realText:=[$41F];
  e.completion:=[$43F,$430];
  e.cursorPos:=1;
  Check(e.HasCompletion,'letter case does not matter beyond ASCII');

  e.text:='ab';
  e.cursorPos:=2;
  e.completion:=UTF8.Decode('abcdef');
  e.onKey(ord(TKey.Backspace),true,0);
  Check(e.completion.IsEmpty,'deleting drops it');
  e.sendSignals:=ssNone;
  e.completion:=UTF8.Decode('abcdef');
  e.onUniChar(Char32('b'),0);
  Check(e.completion.IsEmpty,'with no signals as well');
  e.sendSignals:=ssAll;

  probe.edit:=e;
  e.onChange:=probe.DoComplete;
  e.onUniChar(Char32('c'),0);
  Check(e.HasCompletion,'onChange gives a new one');
  Check(not e.onKey(ord(TKey.Enter),true,0),'Enter takes it');
  Check((e.text='abcdef') and (e.cursorPos=6),'the caret goes to the end of the accepted text');
  Check((probe.enters=2) and not e.HasCompletion,'taken once: nothing is left to add');
  probe.Free;
  EndTest;
 end;

var
  msgAnswers:String8; // the digits of the Test\Msg\N events, in order

procedure MsgAnswer(event:TEventStr;tag:TTag);
 begin
  msgAnswers:=msgAnswers+String8(event)[length(event)];
 end;

// The end of a scene effect as in TWindow.RenderFrame, which needs a graphics system.
// The effect does not play here (no render target format), its first Paint finishes it.
procedure FinishEffect(scene:TGameScene);
 begin
  scene.effect.Paint;
  Signal('ENGINE\EffectDone',UIntPtr(scene));
  scene.effect.Free;
  scene.effect:=nil;
 end;

// Messages go one by one: the next one waits for the closing effect of the previous one
// however long it takes (a minimized window draws nothing, so the effect stands still)
procedure TestMessageQueue;
 var
  scene:TGameScene;
 begin
  StartTest('Message queue');
  txt:=TStubText.Create;
  InitMessageScene;
  scene:=TGameScene.FindByName('MessageScene') as TGameScene;
  SetEventHandler('Test\Msg',MsgAnswer,emInstant);
  ShowMessage('First','Test\Msg\1');
  ShowMessage('Second','Test\Msg\2');
  Check(scene.IsActive,'the first message is shown at once');
  FinishEffect(scene);
  RunFrame(wndA);
  Signal('UI\Message\OK\OnClick');
  RunFrame(wndA);
  Check(msgAnswers='1','the first answer: '+msgAnswers);
  Check(scene.effect<>nil,'the window closes with an effect');
  Sleep(260); // longer than the effect: no frame is drawn, it does not end
  RunFrame(wndA);
  RunFrame(wndA);
  Check(scene.IsActive and (scene.effect<>nil),'the closing effect waits for frames');
  FinishEffect(scene);
  RunFrame(wndA);
  Check(scene.IsActive,'the next message comes after the closing effect');
  if scene.effect<>nil then FinishEffect(scene);
  RunFrame(wndA);
  Signal('UI\Message\OK\OnClick');
  RunFrame(wndA);
  Check(msgAnswers='12','the second answer: '+msgAnswers);
  if scene.effect<>nil then FinishEffect(scene);
  RunFrame(wndA);
  Check(not scene.IsActive,'the queue is empty: the window stays closed');
  Check(wndA.modal.Root=nil,'and the modal stack is empty');
  RemoveEventHandler(MsgAnswer);
  txt:=nil;
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

// The drawer step of DefaultStyle for 10 px wide characters and no text margin
procedure PlaceCaret(e:TUIEditBox);
 var
  a,c:integer;
 function At(x:integer):integer;
  begin
   result:=Min(length(e.realText),(x+5) div 10);
  end;
 begin
  a:=-1; c:=-1;
  if e.needAnchor>=0 then a:=At(e.needAnchor);
  if e.needPos>=0 then c:=At(e.needPos);
  e.needAnchor:=-1; e.needPos:=-1;
  e.MouseCaretPlaced(a,c);
 end;

// Mouse selection in an edit box: it ends where the drawer puts the caret for the last
// mouse position, the drag goes on outside the box. No frames are drawn here, so every
// drag is "fast": all its moves come before the drawer step
procedure TestEditMouse;
 var
  e:TUIEditBox;
  a:String8;
  side:integer;
  step:single;
 begin
  StartTest('Edit box mouse selection');
  e:=TUIEditBox.Create(100,20,sceneA.UI,'MouseEdit'); // 600..700 x 500..520
  e.SetPos(600,500,pivotTopLeft);
  e.cursor:=CursorID.Default; // no game object here to switch the cursor
  e.text:='12345';
  Move(601,510);
  a:=Robot(Req('d','mouse.down','X: 601;Y: 510'));
  Check(IsOk(a,'d') and (hooked=e),'the edit box captures the mouse: '+a);
  Move(640,510);
  Move(780,510); // past the right edge
  Check(underMouse=e,'the drag goes on outside the box');
  PlaceCaret(e);
  Check((e.selStart=0) and (e.selCount=5) and (e.cursorPos=5),
    'one drawer step selects up to the last position: '+IntToStr(e.selStart)+'+'+IntToStr(e.selCount));
  Robot(Req('u','mouse.up','X: 780;Y: 510'));
  Check((hooked=nil) and (e.selCount=5),'the release ends the capture and keeps the selection');
  Sleep(350); // not a double click
  Move(631,510);
  Robot(Req('d','mouse.down','X: 631;Y: 510'));
  Move(580,510); // past the left edge
  Robot(Req('u','mouse.up','X: 580;Y: 510'));
  PlaceCaret(e);
  Check((e.selStart=0) and (e.selCount=3),
    'released before the drawer step, left of the box: '+IntToStr(e.selStart)+'+'+IntToStr(e.selCount));
  // selectOnFocus (default)
  ClearFocus(wndA);
  Sleep(350);
  Click(621,510);
  PlaceCaret(e);
  Check((FocusedElement=e) and (e.selCount=5) and (e.cursorPos=5),'selectOnFocus: a click that gives the focus selects all');
  Sleep(350);
  Click(621,510);
  PlaceCaret(e);
  Check((e.selCount=0) and (e.cursorPos=2),'a click in the focused box places the caret');
  ClearFocus(wndA);
  Sleep(350);
  Move(621,510);
  Robot(Req('d','mouse.down','X: 621;Y: 510'));
  Move(641,510);
  Robot(Req('u','mouse.up','X: 641;Y: 510'));
  PlaceCaret(e);
  Check((e.selStart=2) and (e.selCount=2),'a drag that gives the focus selects a part: '+IntToStr(e.selStart)+'+'+IntToStr(e.selCount));
  // beyond a side the drawer scrolls the text every frame, also with the mouse at rest
  Sleep(350);
  Move(621,510);
  Robot(Req('d','mouse.down','X: 621;Y: 510'));
  Move(780,510);
  e.DragScroll(side); // the first frame out there only starts the clock
  Sleep(50);
  step:=e.DragScroll(side);
  Check((side=1) and (step>0) and (e.needPos<0),'beyond the right side the text scrolls to the end: '+FloatToStr(step));
  Move(580,510);
  Sleep(50);
  step:=e.DragScroll(side);
  Check((side=-1) and (step<0),'beyond the left side to the start: '+FloatToStr(step));
  Robot(Req('u','mouse.up','X: 580;Y: 510'));
  step:=e.DragScroll(side);
  Check((side=0) and (step=0),'the release stops the scroll');
  e.selectOnFocus:=false;
  ClearFocus(wndA);
  e.SetFocus;
  Check((e.selCount=0) and (e.cursorPos=5),'without selectOnFocus the focus puts the caret at the end');
  ClearFocus(wndA);
  Sleep(350);
  Click(621,510);
  PlaceCaret(e);
  Check((FocusedElement=e) and (e.selCount=0) and (e.cursorPos=2),'and a click that gives the focus places the caret');
  ClearFocus(wndA);
  e.Hide;
  EndTest;
 end;

procedure TestReset;
 var
  a:String8;
 begin
  StartTest('input.reset');
  btn.clicks:=0;
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  Check(btn.pressed,'pressed before the reset');
  a:=Robot(Req('r','input.reset'));
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
  Robot(Req('r','input.reset'));
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
  RunFrame(wndA);
  RunFrame(wndA);
  Check(btn.clicks=0,'OS click does not reach the button');
  Check(wndA.mousePos=Types.Point(400,400),'OS pointer does not move the virtual one');
  Check(wndA.mouseButtons=0,'OS button state is ignored');
  Check(underMouse=sceneA.UI,'hover follows the virtual pointer');
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
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

// A focused element stops only the keys it consumes, the rest reach the scene (R-14 step 0)
procedure TestFocusKeys;
 var
  form:TKeyForm;
  b:TProbeButton;
  e:TUIEditBox;
 begin
  StartTest('Focus and scene keys');
  form:=TKeyForm.Create('KeyForm',false,wndA); // the keys are dispatched directly, not by frames
  form.SetStatus(ssActive); // an inactive scene has its UI disabled: no focus routing at all
  form.RegisterHotKey(TKey.S,sscCtrl,form.SaveHotKey);
  b:=NewButton(form.UI,'FocusBtn',10,10);
  e:=TUIEditBox.Create(100,20,form.UI,'FocusEdit');
  // a focused button takes only Enter and Space
  b.SetFocus;
  form.DispatchKey(TKey.B,0,0,true);
  Check(form.log='D:B ','a focused button passes B on to the scene: '+form.log);
  form.log:='';
  form.DispatchKey(TKey.Space,0,0,true);
  Check((b.clicks=1) and (form.log=''),'Space presses the focused button and stops there: '+form.log);
  form.DispatchKey(TKey.Space,0,0,false);
  Check(form.log='U:Space ','the release goes on to the scene: '+form.log);
  // a focused edit box takes the keys that type text and the editing keys
  e.SetFocus;
  form.log:='';
  form.DispatchKey(TKey.B,0,0,true);
  form.DispatchKey(TKey.B,0,sscShift,true);
  form.DispatchKey(TKey.Q,0,sscCtrl+sscAlt,true); // AltGr
  form.DispatchKey(TKey.C,0,sscCtrl,true);
  form.DispatchKey(TKey.Left,0,0,true);
  Check(form.log='','the edit box consumes text, AltGr, editing and caret keys: '+form.log);
  form.DispatchKey(TKey.S,0,sscCtrl,true);
  Check((form.saves=1) and (form.log=''),'Ctrl+S in the edit box reaches the scene hotkey');
  form.DispatchKey(TKey.F5,0,0,true);
  form.DispatchKey(TKey.Escape,0,0,true);
  form.DispatchKey(TKey.B,0,0,false);
  Check(form.log='D:F5 D:Escape U:B ','F5, Esc and releases go on to the scene: '+form.log);
  ClearFocus(wndA);
  form.log:='';
  form.DispatchKey(TKey.B,0,0,true);
  Check(form.log='D:B ','no focus: the scene gets the key: '+form.log);
  form.SetStatus(ssFrozen);
  EndTest;
 end;

procedure TestTabOrder;
 var
  form:TKeyForm;
  first,last:TUIEditBox;
  list,hidden,off:TUIElement;
 begin
  StartTest('Tab order');
  form:=TKeyForm.Create('TabForm',false,wndA);
  form.SetStatus(ssActive);
  first:=TUIEditBox.Create(100,20,form.UI,'TabFirst');
  list:=TUIElement.Create(100,100,form.UI,'TabList'); // focusable, with a child: like a table with its scrollbar
  list.flags.canHaveFocus:=true;
  TUIElement.Create(10,100,list,'TabListBar');
  hidden:=TUIElement.Create(100,20,form.UI,'TabHidden');
  TUIEditBox.Create(100,20,hidden,'TabHiddenEdit');
  hidden.Hide;
  off:=TUIElement.Create(100,20,form.UI,'TabOff');
  TUIEditBox.Create(100,20,off,'TabOffEdit');
  off.Disable;
  last:=TUIEditBox.Create(100,20,form.UI,'TabLast');
  first.SetFocus;
  first.SetFocusToNext;
  Check(FocusedElement=list,'Tab: the next element');
  list.SetFocusToNext;
  Check(FocusedElement=last,'Tab leaves an element with children, skips a hidden and a disabled parent');
  last.SetFocusToNext;
  Check(FocusedElement=first,'Tab wraps around');
  first.SetFocusToPrev;
  Check(FocusedElement=last,'Shift+Tab wraps around');
  last.SetFocusToPrev;
  Check(FocusedElement=list,'Shift+Tab skips a hidden and a disabled parent');
  ClearFocus(wndA);
  form.SetStatus(ssFrozen);
  EndTest;
 end;

procedure TestKeyboard;
 var
  textHi:String8;
  a:String8;
  edit:TUIEditBox;
  t:int64;
 begin
  StartTest('key.* commands');
  textHi:=UTF8.Encode(WideString('Hi ')+WideChar(1046)); // + Cyrillic Zhe
  keyProbe:=TKeyProbe.Create('KeyProbe',false,wndA);
  keyProbe.SetStatus(ssActive);
  kbdLog:='';
  a:=Robot(Req('d','key.down','KEY: LShift'));
  Check(IsOk(a,'d') and (Field(a,'d','keys')='LShift'),'key.down: '+a);
  Check(kbdLog='D:LShift ','the platform event is sent: '+kbdLog);
  Check(IsKeyDown(Scan.LShift),'IsKeyDown sees the virtual key');
  Check(wndA.shiftState and sscShift<>0,'shiftState comes from the virtual keys');
  a:=Robot(Req('d','key.down','KEY: LShift'));
  Check(Field(a,'d','MSG').StartsWith('key is already down'),'key.down of a held key: '+a);
  a:=Robot(Req('t','key.tap','KEY: A'));
  Check(IsOk(a,'t') and (Field(a,'t','keys')='LShift'),'key.tap: '+a);
  a:=Robot(Req('u','key.up','KEY: lshift'));
  Check(IsOk(a,'u') and (Field(a,'u','keys')='none'),'key.up, names are case-insensitive: '+a);
  Check(wndA.shiftState=0,'no modifiers');
  Check(keyProbe.log='D:LShift+shift D:A+shift U:A+shift U:LShift ','receivers: '+keyProbe.log);
  a:=Robot(Req('u','key.up','KEY: LShift'));
  Check(Field(a,'u','MSG').StartsWith('key is not down'),'key.up of a key not down');
  a:=Robot(Req('u','key.up','KEY: Shift'));
  Check(Field(a,'u','MSG').StartsWith('unknown KEY'),'unknown key');
  a:=Robot(Req('u','key.up','KEY: A;SCAN: 4'));
  Check(Field(a,'u','STATUS')='ERROR','KEY and SCAN together');
  // modifiers frame the key: ctrl down, S down, S up, ctrl up
  keyProbe.log:='';
  a:=Robot(Req('t','key.tap','KEY: S;MODS: ctrl+shift'));
  Check(IsOk(a,'t') and (Field(a,'t','keys')='none'),'key.tap with MODS: '+a);
  Check(keyProbe.log='D:LCtrl+ctrl D:LShift+ctrl+shift D:S+ctrl+shift U:S+ctrl+shift U:LShift+ctrl U:LCtrl ',
   'MODS frame the key: '+keyProbe.log);
  a:=Robot(Req('t','key.tap','KEY: S;MODS: hyper'));
  Check(Field(a,'t','MSG').StartsWith('unknown modifier'),'unknown modifier');
  // a position: Scan.W (26) is TKey.W on the US layout
  keyProbe.log:='';
  a:=Robot(Req('t','key.tap','SCAN: 26'));
  Check(IsOk(a,'t') and (keyProbe.log='D:W U:W '),'key.tap by SCAN: '+keyProbe.log);
  // HOLD: the release comes not earlier than HOLD ms after the press
  t:=CoreTime.Ticks;
  a:=Robot(Req('t','key.tap','KEY: Up;HOLD: 150'));
  t:=CoreTime.Ticks-t;
  Check(IsOk(a,'t') and (t>=140),'HOLD keeps the key down: '+IntToStr(t)+' ms');
  a:=Robot(Req('t','key.tap','KEY: Up;HOLD: -1'));
  Check(Field(a,'t','STATUS')='ERROR','negative HOLD');
  // a press of one frame is seen by the polling
  a:=Robot(Batch([Req('d','key.down','KEY: Space'),Req('u','key.up','KEY: Space;WAIT: no')]));
  Check(IsKeyPressed(Scan.Space) or IsKeyDown(Scan.Space) or IsKeyReleased(Scan.Space),'polling sees the key');
  Robot(Req('w','input.wait'));
  // input.reset releases the held keys
  Robot(Req('d','key.down','KEY: D'));
  kbdLog:='';
  a:=Robot(Req('r','input.reset'));
  Check(IsOk(a,'r') and (Field(a,'r','keys')='none') and (kbdLog='U:D '),'input.reset releases the keys: '+kbdLog);
  // text goes to the focused element
  edit:=TUIEditBox.Create(200,24,sceneA.UI,'Edit');
  edit.SetPos(100,400,pivotTopLeft);
  edit.SetFocus;
  RunFrame(wndA);
  kbdLog:='';
  a:=Robot(Req('t','key.type','TEXT: '+textHi));
  Check(IsOk(a,'t') and (Field(a,'t','focus')='Edit') and (Field(a,'t','focusClass')='TUIEditBox'),'key.type, focus: '+a);
  Check(UTF8.Encode(edit.realText)=textHi,'text entered: '+UTF8.Encode(edit.realText));
  Check(kbdLog='C:72 C:105 C:32 C:1046 ','characters only, no key events: '+kbdLog);
  a:=Robot(Req('t','key.type','TEXT: '));
  Check(Field(a,'t','STATUS')='ERROR','empty TEXT');
  edit.Remove;
  // focus loss does not release the virtual keys: the robot owns them
  Robot(Req('d','key.down','KEY: Right'));
  wndA.PlatformReleaseKeys;
  Check(IsKeyDown(Scan.Right),'PlatformReleaseKeys ignored in the virtual mode');
  Robot(Req('u','key.up','KEY: Right'));
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
  a:=Robot(Req('w','input.wait'));
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

procedure OpenSecondWindowMenu(param:pointer);
var menu:TUIPopupMenu;
begin
  menu:=TUIPopupMenu.Create(btnB.parent,'MenuB');
  menu.Add('Other window');
  menu.OpenAt(320,240);
  Atomic.Inc(PInteger(param)^);
end;

procedure CloseSecondWindowMenu(param:pointer);
var popup:TUIPopup;
begin
  popup:=TUIPopup.Current(wndB);
  if popup is TUIPopupMenu then TUIPopupMenu(popup).Close;
  if popup<>nil then popup.Remove;
  Atomic.Inc(PInteger(param)^);
end;

procedure TestSecondWindow;
 var
  a:String8;
  i,completed:integer;
  picker:TUIColorButton;
  secondPopup:TUIPopup;
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
  a:=Robot(Req('s','input.state','WINDOW: Second'));
  Check(Field(a,'s','mode')='physical','window B is still in the physical mode');
  a:=Robot(Req('m','input.mode','MODE: virtual;WINDOW: second'));
  Check(IsOk(a,'m') and (Field(a,'m','window')='Second'),'window B by name: '+a);
  a:=Robot(Req('c','mouse.click','X: 150;Y: 115;WINDOW: Second'));
  Check(IsOk(a,'c'),'click in window B: '+a);
  Check(Field(a,'c','under')='BtnB','under the pointer of window B');
  Check(btnB.clicks=1,'window B button clicked by its own thread');
  Check(btn.clicks=1,'window A untouched');
  Check(wndA.mousePos=Types.Point(150,115),'window A pointer untouched');

  picker:=TUIColorButton.Create(34,24,sceneA.UI,'WindowAColor');
  picker.SetPos(220,220,pivotTopLeft);
  picker.OpenPicker;
  completed:=0;
  Check(wndB.QueueCall(OpenSecondWindowMenu,@completed),'queue popup in window B');
  i:=0;
  while (Atomic.CmpExchange(completed,0,0)<1) and (i<5000) do begin CoreTime.Sleep(1); inc(i); end;
  secondPopup:=TUIPopup.Current(wndB);
  Check((secondPopup is TUIPopupMenu) and picker.IsOpen,'both windows can own a popup');
  picker.Cancel;
  picker.Remove;
  Check(TUIPopup.Current(wndB)=secondPopup,'closing a popup in window A leaves window B alone');
  Check(wndB.QueueCall(CloseSecondWindowMenu,@completed),'queue popup cleanup in window B');
  while (Atomic.CmpExchange(completed,0,0)<2) and (i<5000) do begin CoreTime.Sleep(1); inc(i); end;
  Check(Atomic.CmpExchange(completed,0,0)=2,'window B disposed its popup');
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
  a:=Robot(Req('s','input.state','WINDOW: Second'));
  Check(Field(a,'s','STATUS')='ERROR','closed window is not found');
  a:=Click(150,115);
  Check(IsOk(a,'c'),'window A keeps working');
  EndTest;
 end;

procedure TestPhysicalAgain;
 var
  a:String8;
 begin
  StartTest('input.mode physical');
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  Robot(Req('k','key.down','KEY: Q'));
  kbdLog:='';
  btn.clicks:=0;
  a:=Robot(Req('m','input.mode','MODE: physical'));
  Check(IsOk(a,'m') and (Field(a,'m','mode')='physical'),'back to physical: '+a);
  Check(not btn.pressed and (btn.clicks=0),'held button released without a click');
  Check(wndA.mouseButtons=0,'no buttons down');
  Check((kbdLog='U:Q ') and not IsKeyDown(Scan.Q),'held key released: '+kbdLog);
  a:=Click(150,115);
  Check(Field(a,'c','STATUS')='ERROR','virtual commands refused again');
  a:=Robot(Req('k','key.tap','KEY: Q'));
  Check(Field(a,'k','MSG').StartsWith('virtual input is off'),'key commands refused: '+a);
  wndA.PhysicalClick(150,115);
  RunFrame(wndA);
  RunFrame(wndA);
  Check(btn.clicks=1,'OS input works again');
  Check(underMouse=btn,'OS pointer hovers again');
  wndA.physPos:=Types.Point(-1,-1);
  EndTest;
 end;

// While a window is in the virtual mode nobody answers a modal box: the windows are counted
// for SystemMessage. -ROBOT=VIRTUAL: a new window starts in this mode.
procedure TestRobotDriven;
 var
  op:TVirtualInputOp;
  wnd:TTestWindow;
  base:integer;
 begin
  StartTest('Robot driven window');
  base:=unattendedCount;
  FillChar(op,sizeof(op),0);
  op.kind:=vioMode;
  op.enable:=true;
  wndA.virtualInput.Queue(op);
  RunFrame(wndA);
  Check(unattendedCount=base+1,'the virtual mode is counted');
  op.enable:=false;
  wndA.virtualInput.Queue(op);
  RunFrame(wndA);
  Check(unattendedCount=base,'the physical mode is not');
  robotDriven:=true;
  wnd:=NewWindow('Driven',800,600);
  robotDriven:=false;
  Check(wnd.virtualInput.IsActive,'a new window is in the virtual mode');
  Check(wnd.virtualInput.RequestedActive,'mouse commands are accepted at once');
  Check(unattendedCount=base+1,'it is counted');
  wnd.PlatformMouseButton(1,true);
  Check(wnd.mouseButtons=0,'a physical button does not reach it');
  FreeAndNil(wnd);
  Check(unattendedCount=base,'a closed window is not counted');
  EndTest;
 end;

procedure TestShutdown;
 var
  a:String8;
 begin
  StartTest('Robot API shutdown');
  a:=Robot(Req('m','input.mode','MODE: virtual'));
  Robot(Req('d','mouse.down','X: 150;Y: 115'));
  Check(btn.pressed,'pressed by the robot');
  Robot(Req('k','key.down','KEY: E'));
  btn.clicks:=0;
  DoneRobotAPI;
  RunFrame(wndA);
  Check(not IsKeyDown(Scan.E),'held key released');
  Check(not wndA.virtualInput.IsActive,'window back to the physical mode');
  Check(not btn.pressed and (btn.clicks=0),'gesture cancelled without a click');
  EndTest;
 end;

procedure TestShortScrollRange;
begin
 StartTest('Scrollbar content smaller than page');
 bar.SetRange(0,52,618);
 Check(bar.value=0,'short content starts at zero');
 bar.value:=100;
 Check(bar.value=0,'positive assignment stays at zero');
 bar.value:=-100;
 Check(bar.value=0,'negative assignment stays at zero');
 bar.MoveRel(26);
 Check(bar.value=0,'relative movement cannot scroll short content');
 bar.MoveTo(100,true);
 Check(bar.value=0,'smooth movement starts at the valid minimum');
 bar.SetRange(0,0,618);
 bar.value:=0;
 Check(bar.value=0,'empty list stays at zero');
 bar.SetRange(10,62,618);
 bar.value:=0;
 Check(bar.value=10,'nonzero minimum is retained');
 bar.SetRange(0,1000,100);
 bar.value:=900;
 Check(bar.value=900,'large content still reaches its last page');
 bar.SetRange(0,52,618);
 Check(bar.value=0,'shrinking content removes the old scroll offset');
 bar.SetRange(0,1000,100);
 bar.value:=0;
 EndTest;
end;

procedure TestSharedPopup;
var
  combo:TUIComboBox;
  picker:TUIColorButton;
  menu:TUIPopupMenu;
  active:TUIPopup;
  editor:TUIColorEditor;
  oldColor,newColor:cardinal;
begin
  StartTest('One popup per window and widget-specific dismissal');
  combo:=TUIComboBox.Create(100,30,sceneA.UI,'PopupCombo',['One','Two']);
  combo.SetPos(40,220,pivotTopLeft);
  picker:=TUIColorButton.Create(34,24,sceneA.UI,'PopupColor');
  picker.SetPos(220,220,pivotTopLeft);
  oldColor:=$FF112233;
  newColor:=$FF778899;
  picker.color:=oldColor;
  menu:=TUIPopupMenu.Create(sceneA.UI,'PopupMenu');
  menu.Add('Menu item');
  combo.SetFocus;
  combo.OpenPopup;
  Check(TUIPopup.Current(wndA)=combo.frame,'combo registered as the active popup');
  picker.OpenPicker;
  Check(picker.IsOpen and not combo.frame.flags.visible,'picker replaces combo without choosing a line');
  active:=TUIPopup.Current(wndA);
  editor:=TUIColorEditor(active.children[0]);
  editor.ChooseColor(newColor);
  menu.OpenAt(380,220);
  Check(menu.IsOpen and not picker.IsOpen and (picker.color=oldColor),'menu replaces picker and cancels preview');
  picker.OpenPicker;
  Check(picker.IsOpen and not menu.IsOpen,'picker replaces menu');
  active:=TUIPopup.Current(wndA);
  editor:=TUIColorEditor(active.children[0]);
  editor.ChooseColor(newColor);
  RunFrame(wndA);
  PhysicalClickAt(Types.Point(150,115));
  Check(not picker.IsOpen and (picker.color=newColor),'outside press accepts a valid color');
  combo.SetFocus;
  combo.OpenPopup;
  RunFrame(wndA);
  PhysicalClickAt(CenterOf(combo));
  Check(TUIPopup.Current(wndA)=nil,'combo header press closes the combo');
  picker.OpenPicker;
  sceneA.DispatchKey(TKey.Escape,0,0,true);
  Check(not picker.IsOpen and (FocusedElement=combo),'Escape closes picker and restores focus');
  picker.editorClass:=TTestColorEditor;
  picker.OpenPicker;
  active:=TUIPopup.Current(wndA);
  Check(active.children[0] is TTestColorEditor,'custom class supplies popup content');
  Check(active.FindChildByName(active.name+'\Accept')<>nil,'popup supplies its accept button');
  Check(active.FindChildByName(active.name+'\Cancel')<>nil,'popup supplies its cancel button');
  editor:=TUIColorEditor(active.children[0]);
  editor.ChooseColor(oldColor);
  editor.Accept;
  Check(not picker.IsOpen and (picker.color=oldColor),'custom editor can accept through its host');
  combo.Remove;
  menu.Remove;
  picker.Remove;
  ClearFocus(wndA);
  RunFrame(wndA);
  btn.clicks:=0; btn.downs:=0; btn.ups:=0;
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
  SetEventHandler('KBD\',KbdEvent,emInstant);
  robotAPIEnabled:=true;
  InitRobotAPI;
  if Files.Exists(ROBOT_IN) then Files.Delete(ROBOT_IN);
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
 end;

begin
  Setup;
  TestShortScrollRange;
  TestModeErrors;
  TestPhysicalBefore;
  TestPopupMenu;
  TestSubmenuNames;
  TestSubmenuKeys;
  TestSubmenuMouse;
  TestMenuAutoClose;
  TestSubmenuRemoval;
  TestMenuBarLayout;
  TestMenuBarMouse;
  TestMenuBarKeys;
  TestMenuBarCallbacks;
  TestMenuBarAutoClose;
  TestMenuBarScroll;
  TestMenuBarRemoval;
  TestSharedPopup;
  TestInputFrame;
  TestEnable;
  TestMoveHover;
  TestClick;
  TestDownUp;
  TestBatch;
  TestHintHiddenScene;
  TestWheel;
  TestRules;
  TestKeyboardTarget;
  TestEditKeys;
  TestEventMethods;
  TestCompletion;
  TestMessageQueue;
  TestFocusKeys;
  TestTabOrder;
  TestDrag;
  TestEditMouse;
  TestReset;
  TestPhysicalIgnored;
  TestKeyboard;
  TestClientSpace;
  TestSecondWindow;
  TestCloseWithPending;
  TestPhysicalAgain;
  TestRobotDriven;
  TestShutdown;
  if Files.Exists(ROBOT_IN) then Files.Delete(ROBOT_IN);
  if Files.Exists(ROBOT_OUT) then Files.Delete(ROBOT_OUT);
  writeln;
  writeln(Format('Tests: %d, failed: %d',[testsTotal,testsFailed]));
  if testsFailed>0 then ExitCode:=1;
  if IsDebuggerPresent then readln;
end.
