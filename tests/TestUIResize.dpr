// Mouse resize of UI elements: a resizable edge of an element (TUIElement.SetResizable), a
// splitter (TUISplitter.canResize) and the navigation column of the file dialog. The mouse goes
// straight into the window's dispatch (DispatchMouseMove/DispatchMouseButton), no rendering:
// layouters run by hand.
{$APPTYPE CONSOLE}
program TestUIResize;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Apus.Core,
  Apus.Geom2D,
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Window,
  Apus.Engine.Scene,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UIShapes,
  Apus.Engine.UILayout,
  Apus.Engine.UIFileDialog,
  Apus.Engine.UIScene;

{$I ..\Base\tests\Test.inc}

type
  // Platform stand-in: no OS input
  TTestWindow=class(TWindow)
    procedure SampleOSPointer; override;
    procedure ProcessMessages; override;
    function IsTerminated:boolean; override;
    procedure GetSize(out width,height:integer); override;
  end;

  // records the buttons the mouse routing delivered to it
  TProbe=class(TUIElement)
    downs:integer;
    procedure onMouseButtons(button:byte;state:boolean); override;
  end;

  // an absolute layouter of its own: every child at the right side
  TPinRight=class(TLayouter)
    procedure Layout(item:TUIElement); override;
  end;

  // the navigation column of the file dialog is protected
  TTestDialog=class(TUIFileDialog)
    function NavRect:TRect2;
  end;

var
  wnd:TTestWindow;
  scene:TUIScene;
  signals:String8; // tags of 'UI\Panel\Resize': 0 - changed, 1 - released

procedure TTestWindow.SampleOSPointer;
 begin
 end;

procedure TTestWindow.ProcessMessages;
 begin
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

procedure TProbe.onMouseButtons(button:byte;state:boolean);
 begin
  if state then inc(downs);
  inherited;
 end;

function TTestDialog.NavRect:TRect2;
 begin
  result:=navigationPanel.GetRectInParentSpace;
 end;

procedure ResizeSignal(event:TEventStr;tag:TTag);
 begin
  signals:=signals+IntToStr(tag);
 end;

// --- mouse ---

procedure MoveTo(x,y:integer);
 begin
  wnd.mousePos:=Point(x,y);
  DispatchMouseMove(wnd);
 end;

procedure Down(x,y:integer);
 begin
  MoveTo(x,y);
  DispatchMouseButton(wnd,1,true);
 end;

procedure Up;
 begin
  DispatchMouseButton(wnd,1,false);
 end;

procedure Drag(x1,y1,x2,y2:integer);
 begin
  Down(x1,y1);
  MoveTo(x2,y2);
  Up;
 end;

function NewPanel(parent:TUIElement;const name:String8;x,y,w,h:single):TProbe;
 begin
  result:=TProbe.Create(w,h,parent,name);
  result.SetPos(x,y,pivotTopLeft);
  result.shape:=shapeFull;
 end;

// a container for one test: the whole client area of the scene, cleared afterwards
function NewArea:TUIElement;
 begin
  result:=TUIElement.Create(800,600,scene.UI,'Area');
  result.SetPos(0,0,pivotTopLeft);
  result.shape:=shapeEmpty;
 end;

procedure FreeArea(area:TUIElement);
 begin
  area.Remove;
  MoveTo(799,599);
  DestroyQueuedElements(wnd);
 end;

function Near(a,b:single):boolean;
 begin
  result:=Abs(a-b)<0.01;
 end;

// --- tests ---

procedure TestEdges;
 var
  area:TUIElement;
  p,q:TProbe;
 begin
  StartTest('Automatic edges');
  area:=NewArea;
  p:=NewPanel(area,'Left',8,8,200,584); // a left column with margins
  p.SetResizable;
  Down(205,300);
  Check(hooked=p,'the right edge: the side facing more room');
  Up;
  Down(10,300);
  Check((hooked=nil) and (p.downs=1),'not the left one');
  Up;
  Down(201,300);
  Check((hooked=nil) and (p.downs=2),'off the zone');
  Up;
  q:=NewPanel(area,'Strip',0,80,100,500); // touches the left side, more room above than below
  q.SetResizable;
  Drag(50,82,50,62);
  Check(Near(q.size.y,520) and Near(q.position.y,60),'the top edge, the bottom side stays');
  q.SetResizable(0);
  Down(97,300);
  Check(hooked=nil,'zone 0 - off');
  Up;
  FreeArea(area);
  EndTest;
 end;

procedure TestNoLayout;
 var
  area:TUIElement;
  p:TProbe;
 begin
  StartTest('Edge without a layouter');
  area:=NewArea;
  p:=NewPanel(area,'Panel',100,100,200,150);
  p.SetResizable;
  p.minSize:=Vec2(80,0);
  p.maxSize:=Vec2(400,0);
  signals:='';
  Down(297,150);
  Check(hooked=p,'press in the zone starts the gesture');
  Check(p.downs=0,'the element doesn''t get the press');
  MoveTo(347,170);
  Check(Near(p.size.x,250) and Near(p.size.y,150),'width follows the mouse');
  MoveTo(0,150);
  Check(Near(p.size.x,80),'stops at minSize');
  MoveTo(797,150);
  Check(Near(p.size.x,400),'stops at maxSize');
  MoveTo(327,150);
  Up;
  Check(hooked=nil,'release ends the gesture');
  Check(Near(p.size.x,230) and Near(p.position.x,100),'left side stays');
  Check(signals='00001','signal tags: '+signals);
  Down(150,150);
  Check(p.downs=1,'a press off the zone reaches the element');
  Up;
  // the release comes with a position the move dispatch hasn't seen yet
  Down(327,150);
  wnd.mousePos:=Point(357,150);
  Up;
  Check(Near(p.size.x,260),'the release applies the last position');
  p.Resize(50,-1);
  Check(Near(p.size.x,50),'the limits are for the mouse only: a layout may go below');
  FreeArea(area);
  EndTest;
 end;

procedure TestLeftEdge;
 var
  area,p:TUIElement;
 begin
  StartTest('Left edge, centered pivot');
  area:=NewArea;
  p:=NewPanel(area,'Right',600,300,200,100);
  p.SetPos(700,300,pivotCenter); // touches the right side of the area
  p.SetResizable;
  Drag(602,300,572,300);
  Check(Near(p.size.x,230),'wider by the drag');
  Check(Near(p.GetRectInParentSpace.x2,800),'right side stays');
  Check(Near(p.GetRectInParentSpace.x1,570),'left side follows');
  FreeArea(area);
  EndTest;
 end;

procedure TestChildCovers;
 var
  area,p:TUIElement;
  c:TProbe;
 begin
  StartTest('A child over the edge keeps the mouse');
  area:=NewArea;
  p:=NewPanel(area,'Panel',100,100,200,150);
  p.SetResizable;
  c:=NewPanel(p,'Child',150,0,50,150); // covers the right edge
  Down(297,150);
  Check(hooked=nil,'no gesture');
  Check(c.downs=1,'the child got the press');
  Up;
  Check(Near(p.size.x,200),'size unchanged');
  FreeArea(area);
  EndTest;
 end;

procedure TestCaptureLoss;
 var
  area,p:TUIElement;
 begin
  StartTest('A lost capture ends the gesture');
  area:=NewArea;
  p:=NewPanel(area,'Panel',100,100,200,150);
  p.SetResizable;
  Down(297,150);
  MoveTo(397,150);
  Check(Near(p.size.x,300),'resized while dragging');
  CancelMouseCapture(wnd);
  Check(hooked=nil,'capture dropped');
  MoveTo(450,150);
  Up;
  Check(Near(p.size.x,300),'the size stays, the rest of the drag does nothing');
  Down(397,150);
  MoveTo(350,150);
  p.Remove;
  Check(hooked=nil,'removing the element ends the gesture');
  MoveTo(300,150);
  Up;
  FreeArea(area);
  EndTest;
 end;

procedure TestRowLayout;
 var
  area,row,a,b,c:TUIElement;
 begin
  StartTest('TRowLayout moves the next ones');
  area:=NewArea;
  row:=NewPanel(area,'Row',0,0,300,100);
  row.layout:=TRowLayout.CreateHorizontal;
  a:=NewPanel(row,'A',0,0,100,100);
  b:=NewPanel(row,'B',100,0,100,100);
  c:=NewPanel(row,'C',200,0,100,100);
  a.SetResizable;
  c.SetResizable;
  Drag(97,50,137,50);
  row.layout.Layout(row);
  Check(Near(a.size.x,140) and Near(b.position.x,140) and Near(b.size.x,100),'B moved, same width');
  Down(242,50); // C touches the right side: a left edge would grow it to the right
  Check((hooked=nil) and (TProbe(c).downs=1),'no left edge under TRowLayout');
  Up;
  row.layout.Free;
  FreeArea(area);
  EndTest;
 end;

procedure TestFlexLayout;
 var
  area,flex,a,b:TUIElement;
 begin
  StartTest('TFlexboxLayout gives the rest to the weighted one');
  area:=NewArea;
  flex:=NewPanel(area,'Flex',0,0,400,100);
  flex.layout:=TFlexboxLayout.Create;
  a:=NewPanel(flex,'A',0,0,100,100);
  b:=NewPanel(flex,'B',100,0,300,100);
  b.layoutData:=1;
  a.SetResizable;
  Drag(97,50,147,50);
  flex.layout.Layout(flex);
  Check(Near(a.size.x,150) and Near(b.position.x,150) and Near(b.size.x,250),'B took the rest');
  flex.layout.Free;
  FreeArea(area);
  EndTest;

  StartTest('TFlexboxLayout: a fixed strip on the right');
  area:=NewArea;
  flex:=NewPanel(area,'Flex',0,0,400,100);
  flex.layout:=TFlexboxLayout.Create;
  a:=NewPanel(flex,'A',0,0,300,100);
  a.layoutData:=1;
  b:=NewPanel(flex,'B',300,0,100,100);
  b.SetResizable;
  Drag(302,50,252,50);
  flex.layout.Layout(flex);
  Check(Near(b.size.x,150) and Near(b.position.x,250) and Near(a.size.x,250),'the left edge: A gave the room');
  flex.layout.Free;
  FreeArea(area);
  EndTest;
 end;

procedure TPinRight.Layout(item:TUIElement);
 var
  i:integer;
  list:TUIElements;
 begin
  list:=GetItems(item);
  for i:=0 to high(list) do
   list[i].SetPos(item.clientWidth-list[i].size.x,list[i].position.y,pivotTopLeft);
 end;

procedure TestCustomLayout;
 var
  area,box,p:TUIElement;
 begin
  StartTest('A custom layouter pins a strip to the right');
  area:=NewArea;
  box:=NewPanel(area,'Box',0,0,800,600);
  box.layout:=TPinRight.Create;
  p:=NewPanel(box,'Strip',600,0,200,600);
  p.SetResizable;
  Drag(602,300,552,300);
  box.layout.Layout(box);
  Check(Near(p.size.x,250) and Near(p.position.x,550),'the left edge works');
  box.layout.Free;
  FreeArea(area);
  EndTest;
 end;

procedure TestSplitter;
 var
  area,a,b,box:TUIElement;
  s:TUISplitter;
 begin
  StartTest('Splitter without a layouter: nothing');
  area:=NewArea;
  box:=NewPanel(area,'Box',0,0,400,100);
  a:=NewPanel(box,'A',0,0,100,100);
  s:=TUISplitter.CreateV(6,box);
  s.SetPos(100,0,pivotTopLeft);
  s.shape:=shapeFull;
  s.canResize:=true;
  NewPanel(box,'B',106,0,200,100);
  Drag(103,50,153,50);
  Check(Near(a.size.x,100),'A unchanged');
  FreeArea(area);
  EndTest;

  StartTest('Splitter with TRowLayout');
  area:=NewArea;
  box:=NewPanel(area,'Box',0,0,800,100);
  box.layout:=TRowLayout.CreateHorizontal;
  a:=NewPanel(box,'A',0,0,100,100);
  a.maxSize:=Vec2(180,0);
  s:=TUISplitter.CreateV(6,box);
  s.shape:=shapeFull;
  b:=NewPanel(box,'B',0,0,200,100);
  box.layout.Layout(box);
  Drag(103,50,153,50);
  Check(Near(a.size.x,100),'canResize off: nothing');
  s.canResize:=true;
  Down(103,50);
  Check(hooked=s,'the splitter takes the mouse');
  MoveTo(153,50);
  Up;
  box.layout.Layout(box);
  Check(Near(a.size.x,150) and Near(s.position.x,150) and Near(b.position.x,156) and Near(b.size.x,200),'the row moved');
  Drag(153,50,353,50);
  Check(Near(a.size.x,180),'stops at maxSize of the neighbour');
  box.layout.Free;
  FreeArea(area);
  EndTest;

  StartTest('Splitter with TFlexboxLayout');
  area:=NewArea;
  box:=NewPanel(area,'Box',0,0,400,100);
  box.layout:=TFlexboxLayout.Create;
  a:=NewPanel(box,'A',0,0,100,100);
  s:=TUISplitter.CreateV(6,box);
  s.shape:=shapeFull;
  s.canResize:=true;
  b:=NewPanel(box,'B',0,0,294,100);
  b.layoutData:=1;
  box.layout.Layout(box);
  Drag(103,50,153,50);
  box.layout.Layout(box);
  Check(Near(a.size.x,150) and Near(s.position.x,150) and Near(b.position.x,156) and Near(b.size.x,244),'the weighted one gave the room');
  box.layout.Free;
  FreeArea(area);
  EndTest;
 end;

procedure TestFileDialog;
 var
  area:TUIElement;
  d:TTestDialog;
  r:TRect2;
  w0,x:single;
 begin
  StartTest('File dialog: the navigation column');
  area:=NewArea;
  d:=TTestDialog.Create(900,560,area,'FD'); // the default column: 340, whole pixels
  d.SetPos(10,10,pivotTopLeft);
  r:=d.NavRect;
  w0:=r.width;
  x:=10+r.x2+8; // the middle of the gap, screen
  Drag(round(x),300,round(x)+60,300);
  Check(Near(d.NavRect.width,w0+60),'wider by the drag: '+FloatToStr(d.NavRect.width));
  Drag(round(x)+60,300,round(x)+2000,300);
  Check(d.NavRect.width<=d.clientWidth-16-16-300+0.01,'the table side keeps its room');
  Down(round(10+d.NavRect.x2+8),300);
  wnd.mousePos:=Point(round(x)+60,300); // the release brings a position not seen yet
  Up;
  Check(Near(d.NavRect.width,w0+60),'back');
  d.Resize(400,560); // narrower than the column wants
  Check(d.NavRect.width<w0+60,'trimmed in a narrow dialog');
  d.Resize(900,560);
  Check(Near(d.NavRect.width,w0+60),'restored when the dialog is wide again');
  // a click in a narrow dialog must not keep the trimmed width
  d.Resize(400,560);
  x:=10+d.NavRect.x2+8;
  Down(round(x),300);
  Up;
  d.Resize(900,560);
  Check(Near(d.NavRect.width,w0+60),'a click keeps the preferred width');
  FreeArea(area);
  EndTest;
 end;

procedure Setup;
 begin
  {$IFDEF FPC}{$WARN 4046 OFF}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT OFF}{$ENDIF} // constructing a class with abstract methods: they are never called here
  wnd:=TTestWindow.Create('MainWnd');
  {$IFDEF FPC}{$WARN 4046 ON}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT ON}{$ENDIF}
  wnd.RequestResize(800,600);
  wnd.RequestDPI(96);
  wnd.ApplyPendingSurface;
  mainWindow:=wnd;
  window:=wnd;
  scene:=TUIScene.Create('Scene',true,wnd);
  scene.SetStatus(ssActive);
  SetEventHandler('UI\Panel\Resize',ResizeSignal,emInstant);
 end;

begin
  Setup;
  TestEdges;
  TestNoLayout;
  TestLeftEdge;
  TestChildCovers;
  TestCaptureLoss;
  TestRowLayout;
  TestFlexLayout;
  TestCustomLayout;
  TestSplitter;
  TestFileDialog;
  writeln;
  writeln(Format('Tests: %d, failed: %d',[testsTotal,testsFailed]));
  if testsFailed>0 then ExitCode:=1;
  if IsDebuggerPresent then readln;
end.
