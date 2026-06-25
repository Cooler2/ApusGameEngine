// -----------------------------------------------------
// Standard widget classes
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------

unit Apus.Engine.UIWidgets;
interface
 uses Apus.Core, Apus.Lib, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIShapes;

 {$WRITEABLECONST ON}
 {$IFDEF CPUARM} {$R-} {$ENDIF}

 const
  // Window defaults (writable constants, can be changed)
  wcFrameBorder:integer=5;   // window frame border width
  wcTitleHeight:integer=24;  // window title bar height

  // Window area flags
  wcLeftFrame   =  1;
  wcTopFrame    =  2;
  wcRightFrame  =  4;
  wcBottomFrame =  8;
  wcHeader      = 16; // area that can be used to drag and move the window
  wcClient      = 32; // client part of the window

 // TODO: size constraints (minWidth/maxWidth etc.) to be added to TUIElement directly
 type
  // Horizontal or vertical separator bar that spans the full parent width (CreateH)
  // or height (CreateV). The element has two visual zones:
  //   outer — transparent area defined by padding (marginH, marginV);
  //   inner — colored client area, color set via style key 'inner-fill'.
  // Pass color=0 to leave the inner area transparent (spacer mode).
  // canResize: intended for drag-to-resize neighboring elements (not yet implemented).
  TUISplitter=class(TUIElement)
   canResize:boolean; // true - allow resizing neighbour elements
   // Horizontal bar: spans full parent width, height is the only meaningful dimension.
   // Use .SetPaddings(marginH,marginV,marginH,marginV) for spacing around inner area.
   constructor CreateH(height:single;parent:TUIElement;color:cardinal=0;name:String8='');
   // Vertical bar: spans full parent height, width is the only meaningful dimension.
   constructor CreateV(width:single;parent:TUIElement;color:cardinal=0;name:String8='');
  end;

  // Static image or custom-rendered area. src defines what to draw:
  //   'file:name'       — load from file
  //   'event:name'      — fire event to let external code draw
  //   'proc:XXXXXXXX'   — call render procedure by pointer (see SetRenderProc)
  //   ''                — nothing drawn (use as transparent container)
  // shape defaults to shapeEmpty so mouse events pass through by default.
  // Note: file/event src variants will likely move to R-05 style attributes;
  //       the proc variant (SetRenderProc) is the unique feature of this class.
  // Also serves as base class for TUIHint and TUIWindow.
  TUIImage=class(TUIScrollable)
   src:String8;
   constructor Create(width,height:single;parent:TUIElement;name:String8='';source:String8='');
   procedure SetRenderProc(proc:pointer); // shorthand for src:='proc:...'
  end;

  // Touch-screen scroll overlay: placed over another element to capture drag events and scroll it.
  // Captures mouse drag events, but passes clicks through.
  TUIScrollArea=class(TUIElement)
   fullWidth,fullHeight:single; // full content area dimensions
   direction:TUIScrollDirection;
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(fullW,fullH:single;dir:TUIScrollDirection):TUIScrollArea;
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  protected
   speedX,speedY:single;
   lastTime:cardinal;
   isHooked:boolean;
  end;

  // Tooltip popup. Usually created partially filled; creator or drawer may complete it.
  TUIHint=class(TUIImage)
   simpleText:String8; // plain caption text
   active:boolean;     // active hint: not cached, may contain child elements
   created:int64;      // creation timestamp in ms
   adjusted:boolean;   // drawer may set this after adjusting hint parameters
   hiding:boolean;     // hint is currently hiding

   constructor Create(x,y:single;text:String8;parent_:TUIElement);
   destructor Destroy; override;
   procedure Hide;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  end;

  // Read-only text element with configurable alignment.
  // autoSize lets the drawer shrink/grow the element to fit the caption text.
  TUILabel=class(TUIElement)
   align:TTextAlignment;
   autoSize:boolean; // render should adjust element size to match caption
   verticalOffset:integer; // vertical text shift (positive = up)
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(text:String8):TUILabel;    // left-aligned
   function Centered(text:String8):TUILabel; // centered
   function Right(text:String8):TUILabel;    // right-aligned
   procedure CaptionWidthIs(width:single);
  end;

  // Push button: fires onClick/onClickAsync once on click (not latching).
  // Use onClick for inline UI updates (runs on render thread).
  // Use onClickAsync for slow work (runs in a new thread).
  TUIButton=class(TUIElement)
   default:boolean;          // default button (affects rendering only)
   pressed:boolean;          // transient: true while mouse is held down
   pending:boolean;          // temporarily unavailable (ignores input)
   autoPendingTime:integer;  // ms to stay pending after click (0 = disabled)
   onClick:TProcedure;       // called inline on render thread (use for UI updates)
   onClickAsync:TProcedure;  // called in a new thread (use for slow work)
   onClickEvent:String8;
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(caption:String8):TUIButton;
   destructor Destroy; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure onTimer; override;
   procedure SetPressed(pr:boolean); virtual;
   procedure Click; virtual; // simulate click
   class function Sender:TUIButton;
  protected
   procedure DoClick; virtual;
  private
   lastPressed,pendingUntil:int64;
   lastOver:boolean; // was under mouse when onMouseMove was called last time
  end;

  // Toggle button: latches in toggled state on click.
  // Radio-group behavior: if parent is TUIGroupBox, clicking untoggles
  // all sibling TUIToggleButtons (only one active at a time).
  // If parent is not TUIGroupBox, toggles independently.
  // Renders like TUIButton by default; appearance can differ per style (e.g. iOS switch).
  TUIToggleButton=class(TUIButton)
   toggled:boolean;          // persistent latch state (true = on)
   linkedToggled:PBoolean;   // optional external bool synced with toggled
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(caption:String8;toggled:boolean=false):TUIToggleButton;
   procedure SetToggled(v:boolean); virtual;
   class function GetSwitchIndex(parent:TUIElement):integer;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure SetPressed(pr:boolean); override;
  protected
   procedure DoClick; override;
  end;

  // Checkbox: a TUIToggleButton with checkbox visual rendering.
  // checked is an alias for toggled.
  TUICheckBox=class(TUIToggleButton)
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(caption:String8;checked:boolean=false):TUICheckBox;
  private
   function GetChecked:boolean;
   procedure SetChecked(v:boolean);
  public
   property checked:boolean read GetChecked write SetChecked;
  end;

  // Radio button: checkbox in a group (group=1); exactly one sibling is checked at a time.
  TUIRadioButton=class(TUICheckBox)
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function Setup(caption:String8;checked:boolean=false):TUIRadioButton;
  end;

  // Decorative frame / panel border
  TUIFrame=class(TUIElement)
   constructor Create(width,height:single;parent_:TUIElement;depth:integer=1;style_:integer=0);
   procedure SetBorderWidth(w:integer); virtual;
  protected
   borderWidth:integer; // frame border width in pixels
  end;

  // Basic window: moveable and optionally resizeable.
  // When background<>nil the window operates in "skinned" mode:
  //   - dragRegion defines the moveable area (nil = entire window)
  //   - GetAreaType uses dragRegion for hit-testing instead of standard frame logic
  //   - rendering of background is handled externally (e.g. by CustomStyle)
  TUIWindow=class(TUIImage)
   header:integer;          // title bar height
   autoBringToFront:boolean; // bring to front on click (self or any child)
   moveable:boolean;        // user can drag to move
   resizeable:boolean;      // user can drag edges to resize
   minW,minH,maxW,maxH:integer; // size constraints for resizeable windows
   dragRegion:TUIShape;     // skinned mode: drag area shape (nil = whole window)
   background:pointer;      // skinned mode: opaque ptr to background image

   constructor Create(innerWidth,innerHeight:single;sizeable:boolean;parent_:TUIElement;wndName:String8='';wndCaption:String8='');
   destructor Destroy; override;

   // Returns area flags (wcXxx) and cursor for the given screen point.
   function GetAreaType(x,y:integer;out cur:NativeInt):integer; virtual;

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   procedure Resize(newWidth,newHeight:single); override;
   class function IsWindow:boolean; override;
  private
   hooked:boolean;
   area:integer;   // area type under cursor (wcXxx flags)
  end;

  // Single-line text input. Supports Unicode, mouse selection, password masking,
  // auto-complete (completion), placeholder (defaultText), and horizontal scroll.
  TUIEditBox=class(TUIElement)
   realText:String32; // real text value of the edit box
   completion:String32; // grayed background text, if it is not empty and enter is pressed, then it is set to realText
   defaultText:String32; // grayed background text, displayed if realText is empty
   cursorPos:integer;     // caret position in String32 (0..length, 0-based)
   maxLength:integer;      // max allowed length
   password:boolean;    // if true, all characters are displayed as '*'
   selStart,selCount:integer; //
   cursorTimer:int64;  // time offset for cursor blinking
   needPos:integer;    // pixel position feedback from the drawer
   msSelect:boolean;   // mouse selection mode is ON
   protection:byte;    // xor all characters with this value
   offset:integer;     // shift text right by this number of pixels

   constructor Create(width,height:single;parent_:TUIElement;name:String8='');
   procedure onChar(ch:char;scancode:byte); override;
   procedure onUniChar(ch:Char32;scancode:byte); override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;

   procedure SetFocus; override;
   procedure onLostFocus; override;
   procedure SelectAll; virtual;
  private
   savedText:String32;
   lastClickTime:int64;
   msSelStart:integer; // mouse selection anchor (0-based), -1 if not set
   procedure AdjustState;
   function GetText:String8;
   procedure SetText(s:String8);
  public
   property text:String8 read GetText write SetText;  // Current value in UTF-8 encoding
  end;

  // Horizontal or vertical scrollbar with configurable range, page size, and step.
  // Link to a TUIScrollable element via Link() to control its scroll position.
  // Supports smooth animation and optional auto-hide when content fits.
  TUIScrollBar=class(TUIElement)
  private
   rValue:TAnimatedValue;
   sliderRect:TRect;
   function GetValue:single;
   procedure SetValue(v:single);
   function GetAnimating:boolean;
   procedure SetPageSize(pageSize:single);
   function GetStep:single;
   procedure CheckAutoHide; 
  public
   horizontal:boolean; // orientation
   isInteger:boolean; // should value be always integer
   min,max:single; // range
   pagesize:single; // slider size (within range)
   step:single; // add/subtract this amount with mouse scroll or similar events
   sliderUnder:boolean; // mouse is over slider
   sliderStart,sliderEnd:single; // relative position of slider (in 0..1 range)
   autoHide:boolean; // hide if pagesize>=range
   constructor Create(width,height:single;parent_:TUIElement;barName:String8=''); overload; // orientation from size ratio (fragile, prefer CreateH/CreateV)
   constructor CreateH(width,height:single;parent_:TUIElement;barName:String8=''); // explicit horizontal
   constructor CreateV(width,height:single;parent_:TUIElement;barName:String8=''); // explicit vertical
   function GetScroller:IScroller;
   function SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
   procedure MoveTo(val:single;smooth:boolean=false); virtual;
   procedure MoveRel(delta:single;smooth:boolean=false); virtual;
   procedure Link(elem:TUIScrollable); virtual; // link to a scrollable element
   procedure UseButtons(lessBtn,moreBtn:String8); // use button signals to move the scrollbar
   procedure CalcSliderPos(minSize:single=0.5); // minimal slider size (relative to width)
   procedure onTimer; override;

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseScroll(value:integer); override;
   procedure onLostFocus; override;
   property value:single read GetValue write SetValue;
   property isAnimating:boolean read GetAnimating;
  protected
   linkedControl:TUIScrollable;
   delta:integer; // cursor offset from slider start (when hooked)
   moving:boolean;
   scroller:TObject;
  end;

  // Scrollable list of text items with single selection.
  // Each item may carry a tag (cardinal) and a per-item hint string.
  // Supports hover highlight and optional auto-select on hover.
  TUIListBox=class(TUIScrollable)
   lines:Strings8;
   tags:array of cardinal;
   hints:Strings8; // each element may have its own hint
   lineHeight:single; // in self CS
   selectedLine:integer; // index of selected line (or -1)
   hoverLine:integer; // index of line under mouse (or -1)
   autoSelectMode:boolean; // when true, hover line is automatically selected
   bgColor,bgHoverColor,bgSelColor,textColor,hoverTextColor,selTextColor:cardinal; // rendering colors (R-05: move to style)
   constructor Create(width,height:single;parent:TUIElement;listName:String8='';lHeight:single=0);
   destructor Destroy; override;
   procedure AddLine(line:String8;tag:cardinal=0;hint:String8=''); virtual;
   procedure SetLine(index:integer;line:String8;tag:cardinal=0;hint:String8=''); virtual;
   procedure ClearLines;
   procedure SetLines(newLines:Strings8); virtual;
   procedure SelectLine(line:integer); virtual;
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure SetupScrollers; override; // recompute range from line count, not children bound
   procedure UpdateScroller;
  end;

  // Drop-down selector: visually a button, opens a popup TUIListBox on click.
  // Tracks current item by index (curItem), tag (curTag), and text (text property).
  TUIComboBox=class(TUIButton)
   items,hints:Strings8;
   tags:IntArray;
   defaultText:String8;
   fCurItem,fCurTag:integer;
   // pop up elements
   frame:TUIFrame;
   popup:TUIListBox;
   maxlines:integer; // max lines to show without scrolling
   constructor Create(width,height:single;parent_:TUIElement;name:String8='';list:Strings8=nil);
   procedure AddItem(item:String8;tag:cardinal=0;hint:String8=''); virtual;
   procedure SetItem(index:integer;item:String8;tag:cardinal=0;hint:String8=''); virtual;
   procedure ClearItems;
   procedure onDropDown; virtual; // toggle: open if closed, close (no commit) if open
   procedure OpenPopup; virtual;
   procedure ClosePopup(commit:boolean); virtual; // commit=true applies the hovered/selected line
   procedure onMouseButtons(button:byte;state:boolean); override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onTimer; override; // safety net: close when focus leaves the combo+popup
   procedure SetCurItem(item:integer); virtual;
   procedure SetCurItemByText(value:String8); virtual;
   procedure SetCurItemByTag(tag:integer); virtual;
  protected
   function GetText:String8;
   procedure NotifySelect; // emit ONSELECT signals for the current item
   procedure EnsureHoverVisible; // scroll the open popup so hoverLine is visible
  public
   property curItem:integer read fCurItem write SetCurItem;
   property curTag:integer read fCurTag write SetCurItemByTag;
   property text:String8 read GetText;
  end;

implementation
 uses SysUtils, Types, Apus.Types, Apus.Utils, Apus.EventMan, Apus.Geom2D, Apus.Clipboard,
  Apus.Strings, Apus.Threads, Apus.Engine.UIRender;

 type
  TScrollBarInterface=class(TInterfacedObject, IScroller)
   owner:TUIScrollBar;
   constructor Create(owner:TUIScrollbar);
   function GetElement:TUIElement;
   procedure SetRange(min,max:single);
   procedure SetValue(v:single);
   procedure SetStep(step:single);
   procedure SetPageSize(pageSize:single);
   procedure MoveRel(delta:single;smooth:boolean);
   function GetValue:single;
   function GetStep:single;
   function GetPageSize:single;
  end;

 var
  comboPop:TUIComboBox;      // если существует выпавший комбобокс (а он может быть только один) - он тут

{ TUISpacer }

 constructor TUISplitter.CreateH(height:single;parent:TUIElement;color:cardinal;name:String8);
  begin
   inherited Create(FILL_PARENT,height,parent,name);
   if color<>0 then
    SetStyle('inner-fill',IntToHex(color,8));
  end;

 constructor TUISplitter.CreateV(width:single;parent:TUIElement;color:cardinal;name:String8);
  begin
   inherited Create(width,FILL_PARENT,parent,name);
   if color<>0 then
    SetStyle('inner-fill',IntToHex(color,8));
  end;

 { TUIimage }

 constructor TUIImage.Create(width,height:single;parent:TUIElement;name:String8;source:String8);
  begin
   inherited Create(width,height,parent,name);
   src:=source;
   shape:=shapeEmpty;
  end;

 procedure TUIImage.SetRenderProc(proc:pointer);
  begin
   src:='proc:'+Conv.ToHex(UIntPtr(proc));
  end;

 { TUIButton }

 procedure TUIButton.Click;
  begin
   onMouseButtons(1,true);
   onMouseButtons(1,false);
  end;

 constructor TUIButton.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
   shape:=shapeFull;
   flags.canHaveFocus:=true;
   sendSignals:=ssMajor;
  end;

 function TUIButton.Setup(caption:String8):TUIButton;
  begin
   self.caption:=caption;
   result:=self;
  end;

 destructor TUIButton.Destroy;
  begin
   inherited;
  end;

 procedure TUIButton.DoClick;
  begin
   TUIElement.sender:=self;
   if pending then exit;
   if (sendSignals<>ssNone) and (CoreTime.Ticks>lastPressed+50) then begin
    Signal('UI\'+name+'\OnClick',byte(pressed));
    Signal('UI\Button\Click\'+name,TTag(self));
    if Assigned(onClick) then onClick;
    if Assigned(onClickAsync) then Thread.Start('UIClick:'+String8(name),TThreadProc(onClickAsync));
    if onClickEvent<>'' then Signal(onClickEvent,TTag(self));
    lastPressed:=CoreTime.Ticks;
   end;
  end;

 function TUIButton.onHotKey(keycode,shiftstate:byte):boolean;
  begin
   result:=false;
   if not flags.enabled then exit;
   SetPressed(true);
   DoClick;
   SetPressed(false);
   timer:=150;
   result:=true;
  end;

 function TUIButton.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed and (TKey(keycode) in [TKey.Enter,TKey.Space]) then begin // Enter
    onHotKey(keycode,shiftstate);
    result:=false;
   end;
  end;

 procedure TUIButton.onMouseButtons(button:byte;state:boolean);
  begin
   if not flags.enabled then begin
    Signal('UI\'+name+'\ClickDisabled',button);
    exit;
   end;
   if button=1 then begin
    if not pressed and state then SetPressed(true);
    if pressed and not state then begin
     DoClick;
     SetPressed(false);
    end;
   end;
   inherited;
  end;

 procedure TUIButton.onMouseMove;
  begin
   inherited;
   if not lastover and (undermouse=self) then
    Signal('UI\Button\Over\'+name);
   if lastover and (undermouse<>self) then
    Signal('UI\Button\Out\'+name);
   if pressed and (underMouse<>self) then
    SetPressed(false);
   lastover:=undermouse=self;
  end;

 procedure TUIButton.onTimer;
  begin
   SetPressed(false);
  end;

 class function TUIButton.Sender:TUIButton;
  begin
   result:=TUIElement.sender as TUIButton;
  end;

 procedure TUIButton.SetPressed(pr:boolean);
  begin
   pressed:=pr;
   if sendSignals<>ssNone then begin
    if pr then Signal('UI\Button\Down\'+name,UIntPtr(self))
          else Signal('UI\Button\Up\'+name,UIntPtr(self));
   end;
  end;

{ TUIToggleButton }

 constructor TUIToggleButton.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
  end;

 function TUIToggleButton.Setup(caption:String8;toggled:boolean):TUIToggleButton;
  begin
   self.caption:=caption;
   SetToggled(toggled);
   result:=self;
  end;

 procedure TUIToggleButton.SetToggled(v:boolean);
  begin
   toggled:=v;
   // NB: do NOT mirror into `pressed` — rendering reads `toggled`/`checked`
   // (DrawUICheckbox, TContext), and TUIButton.onMouseMove clears `pressed` on
   // mouse-out, which would silently untoggle this element (via SetPressed override).
   if linkedToggled<>nil then linkedToggled^:=toggled;
   if sendSignals<>ssNone then begin
    Signal('UI\Button\Toggle\'+name,UIntPtr(self));
    Signal('UI\'+name+'\Toggle');
   end;
  end;

 procedure TUIToggleButton.SetPressed(pr:boolean);
  begin
   SetToggled(pr);
  end;

 procedure TUIToggleButton.DoClick;
  var
   i:integer;
  begin
   TUIElement.sender:=self;
   if parent is TUIGroupBox then begin
    // radio group: untoggle all siblings, activate self
    for i:=0 to length(parent.children)-1 do
     if (parent.children[i] is TUIToggleButton) and (parent.children[i]<>self) then
      TUIToggleButton(parent.children[i]).SetToggled(false);
    SetToggled(true);
   end else
    SetToggled(not toggled);
   if sendSignals<>ssNone then begin
    Signal('UI\'+name+'\OnClick',byte(toggled));
    Signal('UI\Button\Down\'+name,TTag(self));
    if Assigned(onClick) then onClick;
    if Assigned(onClickAsync) then Thread.Start('UIClick:'+String8(name),TThreadProc(onClickAsync));
    if onClickEvent<>'' then Signal(onClickEvent,TTag(self));
   end;
  end;

 procedure TUIToggleButton.onMouseButtons(button:byte;state:boolean);
  begin
   if not flags.enabled then begin
    Signal('UI\'+name+'\ClickDisabled',button);
    exit;
   end;
   if (button=1) and state then DoClick; // fire on mouse DOWN
   // don't call TUIButton.onMouseButtons (push logic)
  end;

 procedure TUIToggleButton.onMouseMove;
  begin
   inherited;
  end;

 function TUIToggleButton.onHotKey(keycode,shiftstate:byte):boolean;
  begin
   result:=false;
   if not flags.enabled then exit;
   // in a group box, don't click if already toggled (would have no effect)
   if toggled and (parent is TUIGroupBox) then exit;
   DoClick;
   result:=true;
  end;

 class function TUIToggleButton.GetSwitchIndex(parent:TUIElement):integer;
  var
   e:TUIElement;
  begin
   result:=-1;
   for e in parent.children do
    if e is TUIToggleButton then begin
     inc(result);
     if TUIToggleButton(e).toggled then exit;
    end;
   result:=-1;
  end;

{ TUICheckBox }

 constructor TUICheckBox.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
  end;

 function TUICheckBox.Setup(caption:String8;checked:boolean):TUICheckBox;
  begin
   self.caption:=caption;
   SetToggled(checked);
   result:=self;
  end;

 function TUICheckBox.GetChecked:boolean;
  begin
   result:=toggled;
  end;

 procedure TUICheckBox.SetChecked(v:boolean);
  begin
   SetToggled(v);
  end;

{ TUIRadioButton }

 constructor TUIRadioButton.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
   // radio behavior is implicit when parent is TUIGroupBox
  end;

 function TUIRadioButton.Setup(caption:String8;checked:boolean):TUIRadioButton;
  begin
   self.caption:=caption;
   if checked then SetToggled(true);
   result:=self;
  end;

{ TUILabel }

 procedure TUILabel.CaptionWidthIs(width:single);
  var
   oldW,dW:single;
  begin
   width:=width/globalScale;
   oldW:=size.x;
   ResizeClient(width,clientHeight);
   dW:=size.x-oldW;
   case align of
    taCenter: position.x:=position.x+dW/2;
    taRight: position.x:=position.x+dW;
   end;
  end;

constructor TUILabel.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
   shape:=shapeFull;
   align:=taLeft;
   sendSignals:=ssMajor;
   verticalOffset:=0;
  end;

function TUILabel.Setup(text:String8):TUILabel;
  begin
   caption:=text;
   align:=taLeft;
   result:=self;
  end;

function TUILabel.Centered(text:String8):TUILabel;
  begin
   caption:=text;
   align:=taCenter;
   result:=self;
  end;

function TUILabel.Right(text:String8):TUILabel;
  begin
   caption:=text;
   align:=taRight;
   result:=self;
  end;


{ TUIWindow }

 constructor TUIWindow.Create(innerWidth,innerHeight:single;sizeable:boolean;parent_:TUIElement;wndName:String8='';wndCaption:String8='');
  var
   deltaX,deltaY:integer;
  begin
   resizeable:=sizeable;
   if resizeable then begin
    deltaX:=wcFrameBorder; deltay:=wcFrameBorder;
   end else begin
    deltaX:=2; deltay:=2;
   end;
   inherited Create(innerWidth+deltaX*2,innerHeight+deltay+wcTitleHeight,parent_,wndName);
   padding.Left:=deltaX; padding.Top:=wcTitleHeight;
   padding.Right:=deltaX; padding.Bottom:=deltaY;

   shape:=shapeFull;
   caption:=wndCaption;
   header:=wcTitleHeight;
   autoBringToFront:=true;
   flags.canhavefocus:=false;
   moveable:=true;
   minW:=32; minH:=32;
   maxW:=1600; maxH:=1200;
   style.SetAttr('color','$FFBCB8B0');
   area:=0;
   order:=100; // выше чем прочие элементы.
  end;

 destructor TUIWindow.Destroy;
  begin
   if (dragRegion<>nil) and not dragRegion.persistent then dragRegion.Free;
   inherited;
  end;

 function TUIWindow.GetAreaType(x,y:integer;out cur:NativeInt):integer;
  var
   c:byte;
   r:TRect;
  begin
   result:=0; cur:=CursorID.Default;
   r:=GetPosOnScreen;
   if (x<r.left) or (y<r.top) or (x>=r.Right) or (y>=r.Bottom) then exit;
   dec(x,r.Left);
   dec(y,r.Top);
   // skinned mode: use dragRegion for hit-testing
   if background<>nil then begin
    if moveable then result:=wcHeader else result:=wcClient;
    if (dragRegion<>nil) and not dragRegion.IsOpaque(x/r.Width,y/r.Height) then
     result:=wcClient;
    exit;
   end;
   if resizeable then begin
    if x<wcFrameBorder then inc(result,wcLeftFrame);
    if y<wcFrameBorder then inc(result,wcTopFrame);
    if x+wcFrameBorder>=r.Width then inc(result,wcRightFrame);
    if y+wcFrameBorder>=r.Height then inc(result,wcBottomFrame);
    if (result=0) and (y<header) then inc(result,wcHeader);
   end else begin
    if y<header then inc(result,wcHeader);
   end;
   if result=0 then inc(result,wcClient);

   c:=0;
   if result and (wcLeftFrame+wcRightFrame)>0 then inc(c);
   if result and (wcTopFrame+wcBottomFrame)>0 then inc(c,2);
   case c of
    1:cur:=CursorID.ResizeW;
    2:cur:=CursorID.ResizeH;
    3:cur:=CursorID.ResizeHW;
   end;
  end;

 procedure TUIWindow.onLostFocus;
  begin
   if Apus.Engine.UITypes.hooked=self then Apus.Engine.UITypes.hooked:=nil;
   hooked:=false;
  end;

 procedure TUIWindow.onMouseButtons(button:byte;state:boolean);
  var
   pnt:TPoint;
  begin
   inherited;
   if (button=1) and state and not hooked then
    area:=GetAreaType(curMouseX,curMouseY,cursor);
   if (button=1) and not (area in [0,wcClient]) then begin
    if not hooked and state then begin
     hooked:=true;
     Apus.Engine.UITypes.hooked:=self;
    end;
    if hooked and not state then begin
     hooked:=false;
     if Apus.Engine.UITypes.hooked=self then Apus.Engine.UITypes.hooked:=nil;
     // Don't allow window center to be moved outside screen
     pnt:=GetPosOnScreen.CenterPoint;
     /// TODO: implement action
    end;
   end;
  end;

 procedure TUIWindow.onMouseMove;
  var
   iScale:single;
   dx,dy,oldSize:single;
  begin
   if hooked then begin
    iScale:=scale/globalScale; // pixels to parent's space scale
    dx:=(curMouseX-oldMouseX)*iScale;
    dy:=(curMouseY-oldMouseY)*iScale;
    // Drag
    if area=wcHeader then begin
     position.Add(Vec2(dx,dy));
    end;
    // Resize
    if area and wcRightFrame>0 then Resize(size.x+dx,-1);
    if area and wcBottomFrame>0 then Resize(-1,size.y+dy);
    if area and wcLeftFrame>0 then begin
     oldSize:=size.x;
     Resize(size.x-dx,-1);
     position.x:=position.x+oldSize-size.x;
    end;
    if area and wcTopFrame>0 then begin
     oldSize:=size.y;
     Resize(-1,size.y-dy);
     position.y:=position.y+oldSize-size.y;
    end;
    inherited;
    exit;
   end;

   inherited;
   area:=GetAreaType(curMouseX,curMouseY,cursor);
   if area in [0,wcClient] then hooked:=false;
  end;

 procedure TUIWindow.Resize(newWidth,newHeight:single);
  begin
   if newwidth<>-1 then begin
    if newwidth<minW then newwidth:=minW;
    if (newwidth>maxW) and (maxW>0) then newwidth:=maxW;
   end;
   if newheight<>-1 then begin
    if newheight<minH then newheight:=minH;
    if (newheight>maxH) and (maxH>0) then newheight:=maxH;
   end;
   inherited;
  end;

 class function TUIWindow.IsWindow:boolean;
  begin
   result:=true;
  end;


 { TUIEditBox }

 procedure TUIEditBox.AdjustState;
  begin
   if cursorpos<0 then cursorpos:=0;
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
   if selstart<0 then selstart:=0;
   if selstart>length(realtext) then selstart:=length(realtext);
   if selcount<0 then selcount:=0;
   if selstart+selcount>length(realtext) then selcount:=length(realtext)-selstart;
  end;

 constructor TUIEditBox.Create(width,height:single;parent_:TUIElement;name:String8='');
  begin
   inherited Create(width,height,parent_,name);
   shape:=shapeFull;
   cursor:=CursorID.Input;
   selstart:=0;
   selcount:=0;
   cursorpos:=0;
   maxlength:=240;
   password:=false;
   protection:=0;
   needPos:=-1;
   offset:=0;
   flags.canhavefocus:=true;
   sendSignals:=ssAll;
   lastClickTime:=0;
   msSelStart:=-1;
  end;


function TUIEditBox.GetText:String8;
  begin
   result:=UTF8.Encode(realText);
  end;

 procedure TUIEditBox.SetText(s:String8);
  begin
   realtext:=UTF8.Decode(s);
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.onChar(ch:char;scancode:byte);
  begin
   inherited;
  end;

 procedure TUIEditBox.onUniChar(ch:Char32;scancode:byte);
  var
   oldText:String32;
  begin
   oldText:=realText;
   AdjustState;
   cursortimer:=CoreTime.Ticks;
   TUIElement.sender:=self;
   // Enter/Escape are handled in onKey (control chars aren't delivered via SDL text input)
   if (ch>=32) and (selcount>0) then begin
    delete(realtext,selstart,selcount);
    insert(ch,realtext,selstart);
    selcount:=0;
    cursorpos:=selstart+1;
    exit;
   end;
   if (length(realtext)<maxlength) and (ch>=32) then begin
    insert(ch,realtext,cursorpos);
    inc(cursorpos);
   end;
   if (sendSignals=ssAll) and (oldText<>realText) then begin
    savedText:=oldText;
    Signal('UI\'+name+'\changed',0);
   end;
  end;

 function TUIEditBox.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
   procedure ClipCopy(cut:boolean=false);
    var
     str:String32;
    begin
     if password or (protection<>0) then exit;
     str:=copy(realtext,selstart,selcount);
     CopyStrToClipboard(Str16(UTF8.Encode(str)));
     if cut then begin
      delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart;
     end;
    end;
   procedure ClipPaste;
    var
     wst:String32;
    begin
     wst:=Str32(PasteStrFromClipboardW);
     if not wst.IsEmpty then begin
     if selcount>0 then begin
      delete(realtext,selstart,selcount);
      cursorpos:=selstart;
      end else
       selstart:=cursorpos;
      insert(wst,realtext,cursorpos);
      selcount:=length(wst);
      if length(realtext)>maxlength then setLength(realtext,maxlength);
      if selstart+selcount>length(realtext) then selcount:=length(realtext)-selstart;
     cursorpos:=selstart+selcount;
     end;
    end;
   function IsWordSeparator(ch:Char32):boolean;
    begin
     result:=(ch<=32) or (ch=Char32('.')) or (ch=Char32(',')) or (ch=Char32(';')) or
      (ch=Char32(':')) or (ch=Char32('!')) or (ch=Char32('?')) or (ch=Char32('"')) or
      (ch=Char32('''')) or (ch=Char32('(')) or (ch=Char32(')')) or (ch=Char32('[')) or
      (ch=Char32(']')) or (ch=Char32('{')) or (ch=Char32('}')) or (ch=Char32('/')) or
      (ch=Char32('\')) or (ch=Char32('|')) or (ch=Char32('+')) or (ch=Char32('-')) or
      (ch=Char32('*')) or (ch=Char32('=')) or (ch=Char32('<')) or (ch=Char32('>'));
    end;
   function PrevWordPos(pos:integer):integer;
    begin
     result:=pos;
     while (result>0) and IsWordSeparator(realText[result-1]) do dec(result); // skip separators
     while (result>0) and not IsWordSeparator(realText[result-1]) do dec(result); // go to word start
    end;
   function NextWordPos(pos:integer):integer;
    var
     txtLen:integer;
    begin
     txtLen:=length(realText);
     result:=pos;
     while (result<txtLen) and IsWordSeparator(realText[result]) do inc(result); // skip separators
     while (result<txtLen) and not IsWordSeparator(realText[result]) do inc(result); // go to word end
    end;
   procedure MoveCaret(newPos:integer;extendSelection:boolean);
    var
     anchor,oldCursor:integer;
    begin
     oldCursor:=cursorPos;
     if newPos<0 then newPos:=0;
     if newPos>length(realText) then newPos:=length(realText);
     if not extendSelection then begin
      cursorPos:=newPos;
      selStart:=0;
      selCount:=0;
      exit;
     end;

     // Keep the fixed edge of selection as anchor and move the caret edge.
     if selCount=0 then anchor:=oldCursor
      else
       if oldCursor=selStart then anchor:=selStart+selCount
        else anchor:=selStart;

     cursorPos:=newPos;
     if cursorPos=anchor then begin
      selStart:=cursorPos;
      selCount:=0;
     end else
      if cursorPos<anchor then begin
       selStart:=cursorPos;
       selCount:=anchor-cursorPos;
      end else begin
       selStart:=anchor;
       selCount:=cursorPos-anchor;
      end;
    end;
  var
   newPos,txtLen:integer;
   useCtrl,useShift:boolean;
   oldText:String32;
  begin
   oldText:=realText;
   AdjustState;
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed then begin
    cursortimer:=CoreTime.Ticks;
    txtLen:=length(realText);
    useCtrl:=(shiftstate and sscCtrl)>0;
    useShift:=(shiftstate and sscShift)>0;

    // [Enter]: accept autocompletion if present, otherwise emit Enter signal
    if (TKey(keycode)=TKey.Enter) and (sendSignals<>ssNone) then begin
     TUIElement.sender:=self;
     if (not completion.IsEmpty) and (not realText.Same(completion)) then begin
      realText:=completion;
      completion:=[];
      cursorpos:=length(realtext);
      selcount:=0;
      Signal('UI\'+name+'\AutoCompletion',0);
      Signal('UI\Editbox\AutoCompletion\'+name,0);
     end else begin
      Signal('UI\'+name+'\Enter',0);
      Signal('UI\Editbox\Enter\'+name,0);
     end;
    end;
    if (TKey(keycode)=TKey.Escape) and (sendSignals<>ssNone) then begin
     TUIElement.sender:=self;
     Signal('UI\'+name+'\Escape',0);
    end;

    // Arrow navigation:
    // - no Shift: move caret and clear selection
    // - with Shift: extend/shrink selection from fixed anchor point
    // - with Ctrl: jump by words
    if (TKey(keycode)=TKey.Left) then begin
     if not useShift and (selCount>0) then newPos:=selStart
      else
       if useCtrl then newPos:=PrevWordPos(cursorPos)
        else newPos:=cursorPos-1;
     MoveCaret(newPos,useShift);
    end;

    if (TKey(keycode)=TKey.Right) then begin
     if not useShift and (selCount>0) then newPos:=selStart+selCount
      else
       if useCtrl then newPos:=NextWordPos(cursorPos)
        else newPos:=cursorPos+1;
     MoveCaret(newPos,useShift);
    end;

    // [Home], [End] navigation with optional selection extension.
    if TKey(keycode)=TKey.HOME then begin
     MoveCaret(0,useShift);
    end;
    if TKey(keycode)=TKey.EndKey then begin
     MoveCaret(txtLen,useShift);
    end;

    if (TKey(keycode)=TKey.Backspace) and (shiftState and sscAlt=0) then begin // backspace
     if selcount>0 then
      begin delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart; end
     else begin
      if cursorpos>0 then begin delete(realtext,cursorpos-1,1); dec(cursorpos); end;
     end;
    end;

    // Ctrl+C = Copy
    if (keycode=ord('C')) and (shiftState=sscCtrl) and (selcount>0) then clipCopy;
    // Ctrl+X = Cut
    if (keycode=ord('X')) and (shiftState=sscCtrl) and (selcount>0) then clipCopy(true);
    // Ctrl+V = Paste
    if (keycode=ord('V')) and (shiftState=sscCtrl) then
     clipPaste;
    // Ctrl+A: Select all
    if (keycode=ord('A')) and (shiftState=sscCtrl) then
     SelectAll;

    // Ctrl+Z or Alt+BkSp - undo
    if ((keycode=ord('Z')) and (shiftState=sscCtrl)) or
       ((TKey(keycode)=TKey.Backspace) and (shiftState=sscAlt)) then begin
     realText:=savedText;
    end;

    if TKey(keycode)=TKey.Insert then begin // ins
     if (selcount>0) and (shiftstate=sscCtrl) then clipCopy;
     if shiftstate and sscShift>0 then clipPaste;
    end;
    if TKey(keycode)=TKey.Delete then begin // del
     if selcount>0 then begin
      if shiftstate and sscShift>0 then ClipCopy(true) // Cut
       else begin
        delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart;
       end;
     end else begin
      if (cursorpos<length(realtext)) then begin
       delete(realtext,cursorpos,1);
      end;
     end;
    end;
    AdjustState;
   end;
   if (sendSignals=ssAll) and (oldText<>realText) then begin
    savedText:=oldText;
    Signal('UI\'+name+'\changed');
   end;
  end;

 procedure TUIEditBox.onMouseButtons(button:byte;state:boolean);
  var
   doubleClick:boolean;
  begin
   doubleClick:=false;
   if (button=1) and (state) then begin
    if CoreTime.Ticks<lastClickTime+300 then doubleClick:=true;
    lastClickTime:=CoreTime.Ticks;
   end;
   AdjustState;
   inherited;
   needpos:=curMouseX-globalrect.Left-offset;
   if (selcount>0) and (button=1) and state then begin
    selcount:=0; selStart:=0;
   end;
  if (button=1) and state then
    msselect:=true
   else begin
    msselect:=false;
    msSelStart:=-1;
   end;
  if doubleclick then begin
    selStart:=0; selCount:=length(realText);
   end;
  end;

 procedure TUIEditBox.onMouseMove;
  begin
   AdjustState;
   inherited;
   if underMouse<>self then begin
    msselect:=false;
    exit;
   end;
  if msselect and (needpos=-1) then begin
    if (msSelStart<0) then msSelStart:=cursorpos;
    if (msSelStart>=0) and (cursorpos<>msSelStart) then begin
      if cursorpos<msSelStart then begin
       selstart:=cursorPos;
       selcount:=msSelStart-cursorpos;
      end else begin
       selStart:=msSelStart;
       selcount:=cursorPos-msSelStart;
      end;
    end;
    needpos:=curMouseX-globalrect.Left-offset;
   end;
  end;

 procedure TUIEditBox.SelectAll;
  begin
   selStart:=0;
   selCount:=length(realText);
   cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.SetFocus;
  begin
   AdjustState;
   inherited;
   SelectAll;
   {$IFDEF IOS}
   Signal('UI\EditBox\SetFocus',TTag(self));
   {$ENDIF}
  end;

 procedure TUIEditBox.onLostFocus;
  begin
   inherited;
   {$IFDEF IOS}
   Signal('UI\EditBox\LostFocus',TTag(self));
   {$ENDIF}
  end;

 { TUIScrollBar }

 constructor TUIScrollBar.Create(width,height:single;parent_:TUIElement;barName:String8='');
  begin
   inherited Create(width,height,parent_,barName);
   shape:=shapeFull;
   min:=0; max:=100; rValue.Init(0); pagesize:=0;
   linkedControl:=nil; step:=1;
   //color:=$FFB0B0B0;
   horizontal:=size.x>size.y;
   // hooked:=false;
   scroller:=TScrollBarInterface.Create(self);
  end;

 procedure TUIScrollBar.SetPageSize(pageSize:single);
  begin
   SetRange(min,max,pageSize);
   CheckAutoHide;
  end;

function TUIScrollBar.SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
  var
   realMax:single;
   v:single;
  begin
   min:=newMin; max:=newMax; pageSize:=newPageSize;
   realMax:=Clamp(max-pageSize,min,max);
   v:=rValue.Value;
  if (v<min) or (v>realMax) then begin
   rValue.Assign(Clamp(rValue.FinalValue,min,realMax));
   onTimer;
  end;
  CheckAutoHide;
  result:=self;
 end;

 function TUIScrollBar.GetValue:single;
  begin
   result:=rValue.value;
   if isInteger then result:=round(result);
   Clamp(result,min,max-pageSize);
  end;

 procedure TUIScrollBar.Link(elem:TUIScrollable);
  begin
   linkedControl:=elem;
   if horizontal then linkedControl.scrollerH:=GetScroller
    else linkedControl.scrollerV:=GetScroller;
   if HasParent(elem) then flags.noParentClip:=true;
   elem.SetupScrollers;
   CheckAutoHide;
  end;

 procedure TUIScrollBar.SetValue(v:single);
  begin
   v:=Clamp(v,min,max-pageSize);
   rValue.Assign(v);
   onTimer;
   CheckAutoHide;
  end;

 procedure TUIScrollBar.CheckAutoHide;
  begin
   if autoHide then
    flags.visible:=max-min>pageSize;
  end;

constructor TUIScrollBar.CreateH(width,height:single;parent_:TUIElement;barName:String8='');
  begin
   Create(width,height,parent_,barName);
   horizontal:=true;
  end;

 constructor TUIScrollBar.CreateV(width,height:single;parent_:TUIElement;barName:String8='');
  begin
   Create(width,height,parent_,barName);
   horizontal:=false;
  end;

function TUIScrollBar.GetAnimating;
  begin
   result:=rValue.isAnimating;
  end;

 function TUIScrollBar.GetScroller:IScroller;
  begin
   result:=scroller as TScrollBarInterface;
  end;

function TUIScrollBar.GetStep:single;
  begin
   result:=step;
  end;

// This calculate sliderStart, cliderEnd and sliderUnder fields
procedure TUIScrollBar.CalcSliderPos(minSize:single);
 var
  minSliderSize,sliderSize,fullSize,v,addSpace:single;
 begin
  if max<=min then begin
   sliderStart:=0;
   sliderEnd:=1;
   sliderUnder:=false;
   exit;
  end;

  if horizontal then begin
   if minSize<2 then // relative to width?
    minSliderSize:=size.y*minSize;
   fullSize:=size.x;
  end else begin
   if minSize<2 then
    minSliderSize:=size.x*minSize;
   fullSize:=size.y;
  end;
  v:=rValue.Value;
  v:=Clamp(v,min,max-pageSize);

  sliderStart:=(v-min)/(max-min);
  sliderStart:=Clamp(sliderStart,0,1);
  sliderEnd:=(v+pageSize-min)/(max-min);
  sliderEnd:=Clamp(sliderEnd,sliderStart,1);

  sliderSize:=fullSize*(sliderEnd-sliderStart);
  if sliderSize<minSliderSize then begin // expand slider to meet the minimal size requirement
   addSpace:=(minSliderSize-sliderSize)/fullSize; // relative value to expand
   sliderStart:=sliderStart-addSpace*(v-min)/(max-min);
   sliderEnd:=sliderEnd+addSpace*(1-(v-min)/(max-min));
  end;

  if hooked=self then begin
   sliderUnder:=true;
   exit;
  end;
  sliderRect:=globalRect;
  if horizontal then begin
   sliderRect.left:=round(Lerp(globalRect.left,globalRect.Right,sliderStart));
   sliderRect.right:=round(Lerp(globalRect.left,globalRect.Right,sliderEnd));
  end else begin
   sliderRect.Top:=round(Lerp(globalRect.Top,globalRect.Bottom,sliderStart));
   sliderRect.Bottom:=round(Lerp(globalRect.Top,globalRect.Bottom,sliderEnd));
  end;
  sliderUnder:=PtInRect(sliderRect,Point(curMouseX,curMouseY));
 end;

procedure TUIScrollBar.MoveRel(delta:single;smooth:boolean=false);
  begin
   MoveTo(round(rValue.FinalValue)+delta,smooth);
  end;

 procedure TUIScrollBar.MoveTo(val:single;smooth:boolean=false);
  var
   time:integer;
  begin
   TUIElement.sender:=self;
   if val<min then val:=min;
   if val+pagesize>max then val:=max-pagesize;
   if smooth then begin
    time:=Round(500*abs(val-rValue.Value)/pagesize);
    time:=Clamp(time,60,350);
    rValue.Animate(val,time,spline1);
    timer:=1;
   end
    else SetValue(val);

   Signal('UI\'+name+'\Changed',round(val));
   Signal('UI\ScrollBar\Changed\'+name,UIntPtr(self));
  end;

 procedure TUIScrollBar.onLostFocus;
  begin
   if hooked=self then hooked:=nil;
   clipMouse:=cmNo;
  end;

 procedure TUIScrollBar.onMouseButtons(button:byte;state:boolean);
  var
   p:single;
  begin
   inherited;
   globalRect:=GetPosOnScreen;
   CalcSliderPos;
   if max<=min then exit; // empty range: bar is not interactive
   // Mouse pressed over the slider - hook it!
   if state and (hooked=nil) and sliderUnder then begin
    hooked:=self;
    delta:=-1;
    clipMouse:=cmVirtual;
    clipMouseRect:=globalrect;
   end;
   // Mouse released when slider is hooked - release it
   if (hooked=self) and not state then begin
    hooked:=nil;
    clipmouse:=cmNo;
    Signal('Mouse\UpdatePos');
   end;
   // Slider not hooked, pressed outside slider
   if not (sliderUnder or (hooked=self)) and state and
      globalrect.Contains(Point(curMouseX,curMouseY)) then begin
    if horizontal then
     p:=(curMouseX-globalRect.Left)/(globalRect.Width)
    else
     p:=(curMouseY-globalRect.Top)/(globalRect.Height);

    Clamp(p,0,1);
    MoveTo(min+ (max-min-pagesize)*p {round((max-min-pagesize)*p)});
    // jumped the slider to the click — now grab it for dragging.
    // (was: recursive onMouseButtons, which span forever if the slider never
    //  ended up under the cursor — degenerate geometry → stack overflow)
    hooked:=self;
    delta:=-1;
    clipMouse:=cmVirtual;
    clipMouseRect:=globalrect;
    onMouseMove;
   end;
  end;

 procedure TUIScrollBar.onMouseMove;
  var
   p1,p2:single;
   v:integer;
  begin
   inherited;
   if max<=min then begin // empty range: nothing to scroll, slider fills the track
    sliderUnder:=false;
    exit;
   end;
   if delta=-1 then begin
    p1:=(value-min)/(max-min);
    if p1<0 then p1:=0;
    if horizontal then delta:=curMouseX-globalrect.Left-round(p1*(globalRect.width-8))
     else delta:=curMouseY-globalrect.top-round(p1*(globalRect.height-8));
   end;

   if hooked=self then
    if horizontal then begin
     p1:=(curMouseX-delta-globalrect.Left)/(globalRect.width-8);
     if p1<0 then p1:=0; if p1>1 then p1:=1;
     v:=round(min+(max-min)*p1);
     if v<>value then begin
      MoveTo(v);
     end;
    end else begin
     p1:=(curMouseY-delta-globalrect.top)/(globalRect.Height-8);
     if p1<0 then p1:=0; if p1>1 then p1:=1;
     v:=round(min+(max-min)*p1);
     if v<>value then begin
      MoveTo(v);
     end;
    end;

   p1:=(value-min)/(max-min);
   p2:=(value+pagesize-min)/(max-min);
   if p1<0 then p1:=0;
   if p2>1 then p2:=1;
   if horizontal then begin
    sliderUnder:=(curMouseY>=globalrect.Top) and (curMouseY<globalrect.Bottom) and
          (curMouseX>=globalrect.Left+round(p1*(globalRect.width-8))) and
          (curMouseX<globalrect.Left+8+round(p2*(globalrect.width-8)));
   end else begin
    sliderUnder:=(curMouseX>=globalrect.Left) and (curMouseX<globalrect.Right) and
          (curMouseY>=globalrect.Top+round(p1*(globalrect.height-8))) and
          (curMouseY<globalrect.top+8+round(p2*(globalrect.height-8)));
   end;
  end;

 procedure TUIScrollBar.onMouseScroll(value:integer);
  begin
   inherited;
   if linkedControl<>nil then
    linkedControl.onMouseScroll(value)
   else
    MoveRel(-step*value/100,true); // free scrollbar: same wheel scaling as TUIScrollable (value~100/notch)
  end;

procedure TUIScrollBar.onTimer;
  var
   val:single;
  begin
   val:=GetValue;
   if linkedControl<>nil then begin
    if linkedcontrol.scrollerH<>nil then
     if linkedcontrol.scrollerH.GetElement=self then
      linkedControl.scroll.X:=val;
    if linkedcontrol.scrollerV<>nil then
     if linkedcontrol.scrollerV.GetElement=self then
      linkedControl.scroll.Y:=val;
   end;
   Signal('UI\'+name+'\Changing',round(val));
   Signal('UI\Scrollbar\Changing\'+name,round(val));
   if isAnimating then timer:=1;
  end;

procedure TUIScrollBar.UseButtons(lessBtn,moreBtn:String8);
  begin

  end;


 { TUIHint }

 constructor TUIHint.Create(x,y:single;text:String8;parent_:TUIElement);
  begin
   inherited Create(1,1,parent_,'hint');
   SetPos(x,y,pivotTopLeft);
   shape:=shapeEmpty;
   simpleText:=text;
   active:=false;
   adjusted:=false;
   created:=CoreTime.Ticks;
   flags.noParentClip:=true;
  end;

 destructor TUIHint.Destroy;
  begin
   inherited;
  end;

 procedure TUIHint.Hide;
  begin
   if not hiding then begin
    Log.Debug('UIHint Hide');
    hiding:=true;
    created:=CoreTime.Ticks;
   end;
  end;

 procedure TUIHint.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if state then Hide;
  end;

 procedure TUIHint.onTimer;
  begin
   Hide;
  end;

 { TUIScrollArea }

 constructor TUIScrollArea.Create(width,height:single;parent:TUIElement;name:String8);
  begin
   inherited Create(width,height,parent,name);
   shape:=shapeFull;
  end;

 function TUIScrollArea.Setup(fullW,fullH:single;dir:TUIScrollDirection):TUIScrollArea;
  begin
   fullWidth:=fullW;
   fullHeight:=fullH;
   direction:=dir;
   result:=self;
  end;

 procedure TUIScrollArea.onMouseButtons(button:byte;state:boolean);
  begin
   if parent<>nil then parent.onMouseButtons(button,state);
  end;

 procedure TUIScrollArea.onMouseMove;
  begin
   if parent<>nil then parent.onMouseMove;
  end;

 procedure TUIScrollArea.onTimer;
  begin

  end;

 { TUIListBox }

 procedure TUIListBox.AddLine(line:String8;tag:cardinal=0;hint:String8='');
  begin
   lines:=lines+[line];
   tags:=tags+[tag];
   hints:=hints+[hint];
   UpdateScroller;
  end;

 procedure TUIListBox.ClearLines;
  begin
   SetLength(lines,0);
   SetLength(tags,0);
   SetLength(hints,0);
   SelectedLine:=-1;
   UpdateScroller;
  end;

 constructor TUIListBox.Create(width,height:single;parent:TUIElement;listName:String8='';lHeight:single=0);
  var
   scrollbar:TUIScrollbar;
  begin
   inherited Create(width,height,parent,listName);
   shape:=shapeFull;
   lineHeight:=lHeight;
   selectedLine:=-1;
   hoverLine:=-1;
   flags.canHaveFocus:=true;
   sendSignals:=ssMajor;

   scrollBar:=TUIScrollBar.CreateV(8,clientHeight,self,listName+'_scroll');
   scrollBar.SetPos(clientWidth,0,pivotTopRight).SetAnchors(1,0,1,1);
   scrollBar.horizontal:=false;
   scrollBar.flags.noParentClip:=true;
   scrollerV:=scrollBar.GetScroller;
   bgColor:=0;
   textColor:=$E0D0D0D0;
   bgHoverColor:=0;
   hoverTextColor:=$FFD8D8D8;
   bgSelColor:=$90406070;
   selTextColor:=$FFF0F0F0;
   autoSelectMode:=false;
   // R-05: expose list colors via style for theming (drawers still use the direct fields above)
   style.Assign('text-color:$E0D0D0D0; :hover { text-color:$FFD8D8D8; } sel-text-color:$FFF0F0F0; sel-bg:$90406070');
   UpdateScroller;
  end;

 destructor TUIListBox.Destroy;
  begin
   SetLength(lines,0);
   SetLength(tags,0);
   SetLength(hints,0);
   inherited;
  end;

 procedure TUIListBox.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if (button=1) then begin
    if hoverLine>=0 then
     SelectLine(hoverLine);
   end;
  end;

 procedure TUIListBox.onMouseMove;
  var
   cx,cy,n:integer;
   gScale:single;
  begin
   inherited;
   cx:=curMouseX-globalRect.Left;
   cy:=curMouseY-globalRect.Top;
   if (cx>=0) and (cy>=0) and (cx<globalRect.width) and (cy<globalRect.height) then begin
    gScale:=globalScale;
    n:=trunc((cy+scrollerV.GetValue*gScale)/(lineHeight*gScale));
    if (n>=0) and (n<length(lines)) then hoverLine:=n
     else hoverLine:=-1;
   end;
   if autoSelectMode then selectedLine:=hoverLine;
   hint:='';
   if (hoverLine>=0) and (hoverLine<=high(hints)) then hint:=hints[hoverLine];
  end;

 procedure TUIListBox.SelectLine(line:integer);
  begin
   if (line>=0) and (line<=high(lines)) then begin
    if selectedLine<>line then begin
     selectedLine:=line;
     if sendSignals<>ssNone then begin
      Signal('UI\'+name+'\SELECTED',selectedLine);
      Signal('UI\ListBox\onSelect\'+name,TTag(self));
     end;
    end;
   end else
    selectedLine:=-1;
  end;

procedure TUIListBox.SetLine(index:integer;line:String8;tag:cardinal=0;hint:String8='');
  begin
   ASSERT((index>=0) and (index<length(lines)));
   lines[index]:=line;
   tags[index]:=tag;
   hints[index]:=hint;
   UpdateScroller;
  end;

 procedure TUIListBox.SetLines(newLines:Strings8);
  var
   i,count:integer;
  begin
   count:=length(newLines);
   SetLength(lines,count);
   SetLength(tags,count);
   SetLength(hints,count);
   for i:=0 to count-1 do begin
    lines[i]:=newLines[i];
    tags[i]:=0;
    hints[i]:='';
   end;
   if selectedLine>=length(lines) then selectedLine:=length(lines)-1;
   UpdateScroller;
  end;

 procedure TUIListBox.SetupScrollers;
  begin
   // A listbox draws its lines directly (they are not child elements), so the
   // generic children-bound range from TUIScrollable would be wrong. Recompute
   // from the line count instead — this also runs when a layout resizes us.
   // Guard against the early call during construction (before scrollerV exists).
   if scrollerV<>nil then UpdateScroller;
  end;

  procedure TUIListBox.UpdateScroller;
   var
    max:single;
   begin
    max:=length(lines)*lineHeight;
    scrollerV.SetRange(0,max);
    scrollerV.SetStep(lineHeight*(round(clientHeight/2) div round(lineHeight)));
    scrollerV.SetPageSize(clientHeight);
    scrollerV.GetElement.SetPos(clientWidth,0,pivotTopRight);
    scrollerV.GetElement.size.y:=clientHeight;
    scrollerV.GetElement.flags.visible:=max>clientHeight;
   end;

  { TUIFrame }

 constructor TUIFrame.Create(width,height:single;parent_:TUIElement;depth:integer=1;style_:integer=0);
  begin
   inherited Create(width,height,parent_,'_UIFrame');
   shape:=shapeFull;
   borderWidth:=depth;
   if style_<>0 then drawer:=GetUIStyle(style_);
   padding.Left:=depth;  padding.Top:=depth;
   padding.Right:=depth; padding.Bottom:=depth;
  end;

 { TUIComboBox }

 procedure TUIComboBox.AddItem(item:String8;tag:cardinal;hint:String8);
  var
   n:integer;
  begin
   n:=length(items)+1;
   SetLength(items,n);
   SetLength(tags,n);
   SetLength(hints,n);
   items[n-1]:=item;
   tags[n-1]:=tag;
   hints[n-1]:=hint;
  end;

 procedure TUIComboBox.ClearItems;
  begin
   SetLength(items,0);
   SetLength(tags,0);
   SetLength(hints,0);
  end;

 procedure ComboEventHandler(event:TEventStr;tag:TTag);
  var
   e:TUIElement;
   onHeader,onFrame:boolean;
  begin
   if comboPop=nil then exit;
   if event.StartsWith('UI\LISTBOX\ONSELECT\',true) then begin
    comboPop.ClosePopup(true); // a popup line was clicked -> commit and close
    exit;
   end;
   if event.StartsWith('MOUSE\BTNDOWN',true) then begin
    e:=underMouse;
    onHeader:=(e=comboPop) or ((e<>nil) and e.HasParent(comboPop));
    onFrame:=(e=comboPop.frame) or ((e<>nil) and e.HasParent(comboPop.frame));
    // header click is toggled by its own onMouseButtons; popup click selects a
    // line; anything else (including empty space, underMouse=nil) closes w/o commit
    if not onHeader and not onFrame then comboPop.ClosePopup(false);
   end;
  end;

 function TUIComboBox.GetText:String8;
  begin
   if fCurItem>=0 then result:=items[fCurItem]
    else result:='';
  end;

constructor TUIComboBox.Create(width,height:single;parent_:TUIElement;name:String8='';list:Strings8=nil);
  var
   btn:TUIButton;
   i,j:integer;
  begin
   inherited Create(width,height,parent_,name);
   shape:=shapeFull;
   items:=Copy(list);
   SetLength(tags,length(items));
   // Исходные строки могут быть в формате "tag|text|hint" либо "tag|text" либо "text"
   for i:=0 to high(items) do begin
    j:=pos('|',items[i]);
    if (j>1) and (items[i][1] in ['0'..'9']) then begin
     tags[i]:=StrToIntDef(copy(items[i],1,j-1),0);
     delete(items[i],1,j);
     j:=pos('|',items[i]);
     if j>0 then begin
      if length(items)<>length(hints) then SetLength(hints,length(items));
      hints[i]:=copy(items[i],j+1,length(items[i]));
      SetLength(items[i],j-1);
     end;
    end;
   end;
   flags.canHaveFocus:=true;
   maxlines:=15;
   if defaultText='' then defaultText:=GetClassAttribute('defaultText');
   curItem:=-1; // after defaultText so the empty caption shows the placeholder

   // Default properties for child controls
   frame:=TUIFrame.Create(size.x,2,self,1,0);
   frame.flags.visible:=false;
   frame.flags.noParentClip:=true;
   frame.order:=1000;
   popup:=TUIListBox.Create(size.x-2,0,frame,'_ComboBoxPopUp',20);
  // popup.autoSelectMode:=true;
   popup.bgColor:=$FFFFFFFF;
   popup.textColor:=$FF000000;
   popup.bgHoverColor:=$FF405090;
   popup.hoverTextColor:=$FFFFFFFF;
   popup.bgSelColor:=$FF405090;
   popUp.selTextColor:=$FFFFFFFF;

   SetEventHandler('MOUSE\BTNDOWN',ComboEventHandler,emInstant);
   SetEventHandler('UI\ListBox\onSelect\_ComboBoxPopUp',ComboEventHandler,emInstant); // commit on line click
  end;

 procedure TUIComboBox.onDropDown;
  begin
   if frame.flags.visible then ClosePopup(false) // header click while open -> just close
    else OpenPopup;
  end;

 procedure TUIComboBox.OpenPopup;
  var
   r:TRect2;
   lCount,lHeight,i:integer;
   hint:String8;
   tag:cardinal;
   root:TUIElement;
  begin
   if frame.flags.visible then exit;
   Signal('UI\COMBOBOX\ONDROP\'+name,TTag(self));
   if (comboPop<>nil) and (comboPop<>self) then comboPop.ClosePopup(false); // only one combo open at a time
   // Attach drop-down list to the root element
   root:=GetRoot;
   r:=TransformTo(GetRect,root);
   frame.position:=Vec2(r.x1, r.y2+1);
   frame.size.x:=size.x;
   frame.AttachTo(root);

   lCount:=length(items);
   if lCount>=maxlines then lCount:=round(maxLines*0.75);
   // size and position
   /// TODO: simplify and rework this
   lHeight:=round(popup.lineHeight);
   popup.size.y:=lHeight*lcount;
   popup.size.x:=frame.size.x-2*frame.borderWidth;
   frame.size.y:=popup.size.y+frame.borderWidth*2;
   if frame.GetPosOnScreen.bottom>=root.height then
    frame.position.y:=r.y1-1-frame.height;
   // Content
   popUp.ClearLines;
   for i:=0 to high(items) do begin
    if i<=high(hints) then hint:=hints[i]
     else hint:='';
    if i<=high(tags) then tag:=tags[i]
     else tag:=i;
    popUp.AddLine(items[i],tag,hint);
   end;
   frame.flags.visible:=true;
   popup.hoverLine:=curItem;
   popup.selectedLine:=-1; // fresh: a selection only happens by an explicit click
   timer:=1;
   comboPop:=self;
  end;

 procedure TUIComboBox.ClosePopup(commit:boolean);
  var
   oldItem:integer;
  begin
   if not frame.flags.visible then exit;
   Signal('UI\COMBOBOX\ONHIDE\'+name,TTag(self));
   oldItem:=curItem;
   if commit and (popup.selectedLine>=0) then curItem:=popup.selectedLine; // updates caption via setter
   frame.flags.visible:=false;
   frame.AttachTo(self);
   timer:=0;
   if comboPop=self then comboPop:=nil;
   if curItem<>oldItem then NotifySelect;
  end;

 procedure TUIComboBox.NotifySelect;
  begin
   Signal('UI\'+name+'\ONSELECT',curItem);
   Signal('UI\COMBOBOX\ONSELECT\'+name,TTag(self));
  end;

 procedure TUIComboBox.EnsureHoverVisible;
  var
   top,bottom,v,ph:single;
  begin
   if (popup.scrollerV=nil) or (popup.hoverLine<0) then exit;
   top:=popup.hoverLine*popup.lineHeight;
   bottom:=top+popup.lineHeight;
   v:=popup.scrollerV.GetValue;
   ph:=popup.clientHeight;
   if top<v then popup.scrollerV.SetValue(top)
    else if bottom>v+ph then popup.scrollerV.SetValue(bottom-ph);
  end;

 procedure TUIComboBox.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if (button=1) and state then begin
    Signal('UI\ComboBox\DropDown',PtrUInt(self));
    onDropDown;
   end;
  end;

 function TUIComboBox.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  var
   n:integer;
  begin
   if pressed then
    case TKey(keycode) of
     TKey.Up,TKey.Down:begin
      if frame.flags.visible then begin
       // open popup: move the highlighted line
       n:=popup.hoverLine;
       if n<0 then n:=curItem;
       if TKey(keycode)=TKey.Up then dec(n) else inc(n);
       if n<0 then n:=0;
       if n>high(items) then n:=high(items);
       if (n>=0) and (n<=high(items)) then begin
        popup.hoverLine:=n;
        EnsureHoverVisible;
       end;
      end else begin
       // closed popup: change the current item directly (Windows-style)
       n:=curItem;
       if TKey(keycode)=TKey.Up then dec(n) else inc(n);
       if n<0 then n:=0;
       if n>high(items) then n:=high(items);
       if (n<>curItem) and (n>=0) and (n<=high(items)) then begin
        curItem:=n; // updates caption via setter
        NotifySelect;
       end;
      end;
      exit(false);
     end;
     TKey.Enter,TKey.Space:begin
      if frame.flags.visible then begin
       if popup.hoverLine>=0 then popup.selectedLine:=popup.hoverLine;
       ClosePopup(true);
      end else
       OpenPopup;
      exit(false);
     end;
     TKey.Escape:
      if frame.flags.visible then begin
       ClosePopup(false);
       exit(false);
      end;
    end;
   result:=inherited onKey(keycode,pressed,shiftstate);
  end;

 procedure TUIComboBox.onTimer;
  var
   f:TUIElement;
  begin
   // Selection commits via the popup's SELECTED signal and click-outside closes
   // via the global MOUSE\BTNDOWN handler. The timer is only a safety net that
   // closes the popup once focus leaves the combo and its drop-down subtree.
   if not frame.flags.visible then exit;
   timer:=1;
   f:=FocusedElement;
   if (f=self) or (f=frame) or ((f<>nil) and (f.HasParent(self) or f.HasParent(frame))) then exit;
   ClosePopup(false);
  end;

 procedure TUIComboBox.SetCurItem(item:integer);
  begin
   fCurItem:=item;
   if (item>=0) and (item<=high(items)) then caption:=Items[fCurItem]
    else caption:=defaultText;
   if (item>=0) and (item<=high(tags)) then fCurTag:=tags[item]
    else fCurTag:=-1;
  end;

 procedure TUIComboBox.SetCurItemByText(value:String8);
  var
   i:integer;
  begin
   for i:=0 to high(items) do
    if items[i]=value then begin
      SetCurItem(i);
      exit;
    end;
  end;

 procedure TUIComboBox.SetCurItemByTag(tag:integer);
  begin
   SetCurItem(tags.IndexOf(tag));
  end;

 procedure TUIComboBox.SetItem(index:integer;item:String8;tag:cardinal;
    hint:String8);
  begin
   items[index]:=item;
   tags[index]:=tag;
   hints[index]:=hint;
  end;

 procedure TUIFrame.SetBorderWidth(w:integer);
  begin
   borderWidth:=w;
   padding.Left:=w; padding.Right:=w; padding.Bottom:=w; padding.Top:=w;
  end;

 { TScrollBarInterface }

 constructor TScrollBarInterface.Create(owner:TUIScrollbar);
  begin
   inherited Create;
   self.owner:=owner;
  end;

function TScrollBarInterface.GetElement:TUIElement;
  begin
   result:=owner;
  end;

 function TScrollBarInterface.GetPageSize:single;
  begin
   result:=owner.pagesize;
  end;

 function TScrollBarInterface.GetStep:single;
  begin
   result:=owner.step;
  end;

 function TScrollBarInterface.GetValue:single;
  begin
   result:=owner.value;
  end;

 procedure TScrollBarInterface.MoveRel(delta:single;smooth:boolean);
  begin
   owner.MoveRel(delta,smooth);
  end;

 procedure TScrollBarInterface.SetPageSize(pageSize:single);
  begin
   owner.SetPageSize(pageSize);
  end;

 procedure TScrollBarInterface.SetRange(min,max:single);
  begin
   owner.SetRange(min,max,owner.pageSize);
  end;

 procedure TScrollBarInterface.SetStep(step:single);
  begin
   owner.step:=step;
  end;

 procedure TScrollBarInterface.SetValue(v:single);
  begin
   owner.value:=v;
  end;

initialization
 TUIButton.SetClassAttribute('handleMouseIfDisabled',true);
 //TUIButton.SetClassAttribute('defaultColor',$FFC0D0D0);
 //TUIImage.SetClassAttribute('defaultColor',$FF808080);
 TUIComboBox.SetClassAttribute('handleMouseIfDisabled',false);
end.
