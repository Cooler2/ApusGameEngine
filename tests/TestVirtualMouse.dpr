// Virtual mouse through the Robot API (mouse.* commands): the input goes through the
// regular routing of the engine - hit-test, hover, pressed state, capture, modal dialogs,
// clicks - and is checked by the state of real UI elements, not by handler calls.
// Also the keyboard routing around the focus and the popup menu (mouse and keys).
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
  Apus.Engine.UIMenu,
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
  itemNew.handler:=probe.DoNew;
  itemUndo:=testMenu.Add('Undo','Ctrl+Z');
  itemUndo.Disable;
  testMenu.AddSeparator;
  itemSave:=testMenu.Add('Save...','Ctrl+S');
  itemSave.handler:=probe.DoSave;
  itemQuit:=testMenu.Add('&Quit now');
  itemQuit.handler:=probe.DoQuit;
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
  form:=TUIScene.Create('Form',false,wndA); // never active: no part in the mouse tests
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
  TestInputFrame;
  TestEnable;
  TestMoveHover;
  TestClick;
  TestDownUp;
  TestBatch;
  TestWheel;
  TestRules;
  TestKeyboardTarget;
  TestEditKeys;
  TestFocusKeys;
  TestDrag;
  TestReset;
  TestPhysicalIgnored;
  TestKeyboard;
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
