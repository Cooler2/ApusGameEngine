// -----------------------------------------------------
// User Interface classes
// This is independent brick.
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UITypes;
interface
uses Types, Apus.Core, Apus.Lib, Apus.Engine.Types, Apus.Engine.Keys, Apus.Engine.UIShapes,
  Apus.Engine.Scene, Apus.Engine.Window, Apus.Engine.Style;
{$WRITEABLECONST ON}
{$IFDEF CPUARM} {$R-} {$ENDIF}

const
 uiInherit = -999999; // in Resize: take parent's client size
 uiKeep    = -1;      // in Resize: keep this dimension unchanged (implicit: >-1 check)
 FILL_PARENT   = -1;      // in Create: fill parent's client size
 USE_PARENT    = -1;      // alias: use when intent is "match parent size" rather than "fill"

 // Predefined pivot point configuration
 pivotTopLeft:TVec2=(x:0; y:0);
 pivotTopRight:TVec2=(x:1; y:0);
 pivotBottomLeft:TVec2=(x:0; y:1);
 pivotBottomRight:TVec2=(x:1; y:1);
 pivotCenter:TVec2=(x:0.5; y:0.5);

type
 TUIRect=TRect2;
 TAnchorMode=TUIRect;

 // UI snapping modes
 TSnapMode=(smNone,
            smTop,     // width=parents clientwidth, top=0
            smRight,   // height=parents clientheight, left=0
            smBottom,
            smLeft,
            smParent); // area = parents client area

 // UI Verbosity modes
 TSendSignals=(ssNone, // No signals at all
      ssMajor,         // Normal mode: major signals only
      ssAll);          // Verbose mode: all signals

 // How mouse movement is limited between mouseDown and mouseUp
 TClipMouse=(cmNo,        // not limited
             cmVirtual,   // control see mouse as limited, while it is really not
             cmReal,      // mouse pointer is really limited inside the element
             cmLimited);  // mouse pointer is limited, but element may see its "out" to track real relative mouse movement


 TUIScrollDirection=(sdVertical,    // Vertical only
                     sdHorizontal,  // Horizontal only
                     sdBoth,        // Either vertical or horizontal
                     sdFree);       // Free directional

 // Behaviour: how element reacts on parent resize
 TUIPlacementMode=(pmAnchored,      // Anchors are used
                   pmProportional,  // Elements area (position/size) is changed proportionally
                   pmMoveProportional);  // Elements is moved proportionally, but size remains

 TGameScene=Apus.Engine.Scene.TGameScene;
 TWindow=Apus.Engine.Window.TWindow;
 TUIElement=class;
 TUIElements=array of TUIElement;

 // Element drawer procedure type
 TUIDrawer=procedure(element:TUIElement);


 // Base class for Layouters: objects that layout child elements or adjust elements considering its children
 TLayouter=class
  procedure Layout(item:TUIElement); virtual; abstract;
 protected
  function GetItems(parent:TUIElement):TUIElements; // get aaray of objects to layout
 end;

 // External scrollbar interface
 IScroller=interface
  function GetElement:TUIElement; // scrollbar element
  procedure SetRange(min,max:single);
  procedure SetValue(v:single);
  procedure SetStep(step:single);
  procedure SetPageSize(pageSize:single);
  procedure MoveRel(delta:single;smooth:boolean);
  function GetValue:single;
  function GetStep:single;
  function GetPageSize:single;
 end;

 TUIElementFlags = record
   enabled:boolean;          // can react on input (inheritable)
   visible:boolean;
   canHaveFocus:boolean;
   autoScroll:boolean;       // scroll automatically with mouse wheel
   manualDraw:boolean;       // ignored by regular DrawUI call, should be drawn manually
   noParentClip:boolean;     // do NOT clip this element by parent's client rect
   dontClipChildren:boolean; // do NOT clip children by self client rect
 end;

 // Base class of the UI element
 TUIElement=class(TNamedObject)
  // Outer geometry: position and size in PARENT space (unaffected by self scale)
  position:TVec2;  // root point position in parent's client rect
  size:TVec2;      // element dimensions
  pivot:TVec2;     // relative root point: (0,0)=top-left, (1,1)=bottom-right, (0.5,0.5)=center
  // Anchoring: how element reacts to parent resize
  anchors:TUIRect;                // how much each border absorbs from parent's resize delta
  placementMode:TUIPlacementMode; // algorithm used when parent resizes

  // Inner space: scaled by self.scale, affects children
  scale:single;    // scale factor for inner parts and all children
  padding:TUIRect; // client area definition (deducted from element area, in own scale)
  scroll:TVec2;    // offset applied when drawing children (subtract from child positions)
  shape:TUIShape;  // which part of the element reacts to mouse input (in own scaled CS)

  // Interaction & display
  flags:TUIElementFlags;    // important behavioral options
  // Clipping: clipped when BOTH: not parent.flags.dontClipChildren AND not self.flags.noParentClip
  cursor:NativeInt;         // cursor identifier (0 = default)
  order:integer;            // Z-order ($10000 = StayOnTop, <0 = out-of-order/special)
  hint:String8;             // tooltip text
  sendSignals:TSendSignals; // which signals are sent on interaction
  caption:String8;          // primary text associated with element
  timer:integer;            // ms until onTimer fires (0 = disabled); fires once, not earlier than next frame

  // Style (R-05 pipeline)
  style:TStyleBlock;        // parsed style data (created in constructor)
  drawer:TUIDrawer;         // direct drawer reference (nil = use default style drawer)
  styleInfoChanged:boolean; // set true whenever styleInfo changes
  styleContext:TObject;     // custom context object used by drawer

  // Custom data
  attributes:TNameValueList; // miscellaneous named attributes

  // Hierarchy
  ownerScene:TGameScene; // used for root element only
  parent:TUIElement;
  children:TUIElements;

  // Layout
  layout:TLayouter; // child layout manager
  layoutData:single; // custom data for layouter (e.g. weight in flow layout)

  // Cached state (may be outdated; use GetPosOnScreen for accurate position)
  globalRect:TRect;

  class threadvar sender:TUIElement; // sender element in callback handlers

  // --- Lifecycle ---
  constructor Create(width,height:single;parent_:TUIElement;name_:String8='');
  destructor Destroy; override;
  procedure SafeDestroy; // queue for destruction before next frame

  // --- Tree: navigation ---
  function GetNext:TUIElement; virtual;     // next sibling by order
  function GetPrev:TUIElement; virtual;     // previous sibling by order
  function GetRoot:TUIElement;              // topmost ancestor
  function GetScene:TGameScene;             // owning scene
  function GetWindow:TWindow;              // owning window
  function ChildIndex:integer;              // index in parent.children (-1 if no parent)
  function IsVisible:boolean;              // visible including all ancestors
  function IsEnabled:boolean;              // enabled including all ancestors
  function HasParent(c:TUIElement):boolean; // is self a strict descendant of c?
  function HasChild(c:TUIElement):boolean;  // is c a strict descendant of self?

  // --- Tree: modification ---
  procedure AttachTo(newParent:TUIElement;pos:integer=-1); // attach at position (or end if pos<0)
  procedure Detach(shouldAddToRootControls:boolean=true);
  procedure InsertAfter(element:TUIElement);
  procedure InsertBefore(element:TUIElement);
  procedure DeleteChildren(filter:String8=''); // filter: 'start:prefix', '!start:prefix', 'substr'

  // --- Geometry ---
  // Element's CS: (0,0)..(clientWidth,clientHeight), origin at top-left of client area
  function TransformTo(const p:TVec2;target:TUIElement):TVec2; overload; // to target CS (nil = screen)
  function TransformTo(const r:TRect2;target:TUIElement):TRect2; overload;
  function TransformToScreen(const p:TVec2):TVec2; overload;
  function TransformToScreen(const r:TRect2):TRect2; overload;
  function TransformFromScreen(const p:TVec2):TVec2; overload;
  function TransformFromScreen(const r:TRect2):TRect2; overload;
  function GetRect:TRect2;              // element area in own CS (relative to pivot)
  function GetRectInParentSpace:TRect2; // element area in parent's client CS
  function GetClientRect:TRect2;        // client area in own CS (0,0,clientWidth,clientHeight)
  function GetPosOnScreen:TRect;        // element area in screen pixels
  function GetClientPosOnScreen:TRect;  // client area in screen pixels

  // --- Layout & sizing ---
  function SetPos(x,y:single;pivotPoint:TVec2;autoSnap:boolean=false):TUIElement; overload;
  function SetPos(x,y:single;autoSnap:boolean=false):TUIElement; overload;
  procedure MoveBy(dx,dy:single);                            // move by screen pixels
  procedure Center(setAnchors:boolean=true);                 // center in parent
  procedure Snap(snapTo:TSnapMode;shrinkParent:boolean=true); // snap to parent edge
  function SetAnchors(left,top,right,bottom:single):TUIElement; overload;
  function SetAnchors(anchorMode:TAnchorMode):TUIElement; overload;
  function SetPadding(padding:single):TUIElement; overload;
  function SetPaddings(left,top,right,bottom:single):TUIElement; overload;
  function SetScale(newScale:single):TUIElement;
  procedure Resize(newWidth,newHeight:single); virtual;      // new size in parent space; -1 = keep
  procedure ResizeClient(newClientWidth,newClientHeight:single); virtual;
  procedure ScrollTo(newX,newY:integer); virtual;
  procedure SetupScrollers; virtual;

  // --- Focus ---
  procedure SetFocus; virtual;
  function HasFocus:boolean; virtual;
  procedure SetFocusToNext;
  procedure SetFocusToPrev;
  procedure CheckAndSetFocus; // take focus if focusable and no other element has it

  // --- Event handlers ---
  procedure onMouseMove; virtual;
  procedure onMouseScroll(value:integer); virtual;
  procedure onMouseButtons(button:byte;state:boolean); virtual;
  function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; virtual; // return false to suppress
  procedure onChar(ch:char;scancode:byte); virtual;
  procedure onUniChar(ch:Char32;scancode:byte); virtual;
  function onHotKey(keycode:byte;shiftstate:byte):boolean; virtual;
  procedure onTimer; virtual;
  procedure onLostFocus; virtual;

  // --- Search ---
  function FindElementAt(x,y:integer;out c:TUIElement):boolean; overload;    // true if found element is enabled
  function FindAnyElementAt(x,y:integer;out c:TUIElement):boolean;           // ignores transparency (any visible element)
  // Clip-threaded traversal shared by both public find methods (R-08).
  // clip = screen-space rect inside which this element is actually visible;
  // ignoreDisabled=true switches to "any visible" semantics (FindAnyElementAt);
  // escapingOnly=true means this whole subtree is out-of-clip — only noParentClip
  // descendants (which reset the clip) can still produce a hit; self is skipped.
  function FindElementAt(x,y:integer;const clip:TRect;ignoreDisabled,escapingOnly:boolean;out c:TUIElement):boolean; overload;
  function FindChildByName(const name:string8):TUIElement;

  // --- Queries ---
  function IsOpaque(x,y:single):boolean; virtual; // hit test in tmCustom mode (coords in 0..1 range)
  function IsOutOfOrder:boolean; virtual;          // out-of-order elements skip layouter and group ops
  class function IsWindow:boolean; virtual;        // windows track focused child
  function IsActiveWindow:boolean; virtual;

  // --- Helpers ---
  procedure Show;
  procedure Hide;
  procedure Toggle;        // toggle visibility
  procedure Enable;
  procedure Disable;
  procedure ToggleEnabled;
  procedure SetHotKey(vKeyCode:integer;shiftstate:byte=0);
  procedure RemoveHotKey(vKeyCode:integer;shiftstate:byte=0);
  class procedure SetDefault(name:String8;value:variant); // set class-level default attribute
  procedure SetStyle(name,value:string8); // 'name:value' or 'state.name:value' syntax

  // R-05: style system — use element.style.Assign/Add/SetState/GetColor etc. directly
  function HasState(const name:String8):boolean;  // shortcut for style.HasState
  procedure SetState(const name:String8; active:boolean);  // shortcut for style.SetState
  // Resolve style attribute value considering cascade (own block → parent chain)
  function GetStyleValue(const key:String8; const defVal:String8=''):String8;
  function GetStyleColor(const key:String8; defVal:cardinal=0):cardinal;
  function GetStyleNumber(const key:String8; defVal:single=0):single;
  function GetStyleInt(const key:String8; defVal:integer=0):integer;
  // Base value without state overrides — for transition blending
  function GetBaseStyleColor(const key:String8; defVal:cardinal=0):cardinal;
  function GetBaseStyleNumber(const key:String8; defVal:single=0):single;

 protected
  focusedChild:TUIElement; // child element which should get focus instead of self

  procedure DeleteHotkeys(vKeyCode:integer;shiftstate:byte=0);

 private
  fStyleInfo:String8; // additional style info string (see styleInfo property)
  fInitialSize:TVec2; // element's initial size (used for proportional resize)
  function GetClientWidth:single;
  function GetClientHeight:single;
  function GetGlobalScale:single;
  procedure SetName(n:String8); override;
  procedure SetStyleInfo(sInfo:String8);
  procedure ClientSizeChanged(dX,dY:single); // client area was resized because of size or scale change
  procedure ParentSizeChanged(dX,dY:single); // parent's client area was resized - adopt element position/size
  procedure InsertRel(element:TUIElement;rel:integer);

  class function ClassHash:pointer; override;
 public
  property width:single read size.x write size.x;
  property height:single read size.y write size.y;
  property clientWidth:single read GetClientWidth;
  property clientHeight:single read GetClientHeight;
  property globalScale:single read GetGlobalScale; // how many screen pixels are in an element with size=1.0
  property initialSize:TVec2 read fInitialSize; // size when created
  property styleInfo:String8 read fStyleInfo write SetStyleInfo;
 end;

 // General-purpose container that tracks one "active" child at a time.
 // Useful for tab panels, wizard steps, or any exclusive-visibility group.
 // selectedChild holds the index into children[] of the active child (-1 = none).
 TUIGroupBox=class(TUIElement)
  selectedChild:integer; // index of active child element (-1 if none)
  constructor Create(width,height:single;parent_:TUIElement;name_:String8='');
 end;

 // Element that can have linked visual scrollbars controlling its scroll position
 TUIScrollable=class(TUIElement)
  scrollerH,scrollerV:IScroller; // visual scrollbars linked to this element
  procedure SetupScrollers; override;
  procedure ScrollTo(newX,newY:integer); override;
  procedure onMouseScroll(value:integer); override;
 protected
  childrenBound:TRect2; // bounding rect of scrollable children
 end;


threadvar
  // These variables are per-window, thus declared as threadvar
  underMouse:TUIElement;     // element currently under mouse cursor
  modalElement:TUIElement;   // active modal element (only one at a time)
  hooked:TUIElement;         // if set, receives mouse events even without focus

  clipMouse:TClipMouse;   // mouse movement clipping mode
  clipMouseRect:TRect;    // allowed mouse movement area

  curMouseX,curMouseY,oldMouseX,oldMouseY:integer; // mouse cursor coordinates (valid during onMouseMove)

  lastGroupBox:TUIGroupBox; // last created TUIGroupBox (convenience reference for UI building)

function DescribeElement(c:TUIElement):String8;
function FocusedElement:TUIElement;
procedure SetFocusTo(control:TUIElement);

 // Keycode - virtual key
 procedure ProcessHotKey(keycode:integer;shiftstate:byte);
 // Destroy elements queued by SafeDestroy
 procedure DestroyQueuedElements;

implementation
 uses Classes, SysUtils, Apus.EventMan, Apus.Clipboard, Apus.Engine.API,
  Apus.Geom2D,
  Apus.Conv,
  Apus.Strings;

 type
  // Hotkey handler
  THotKey=record
   vKey:integer;
   shiftstate:byte;
   element:TUIElement;
  end;

 var
  // TUIElement class hash
  UIHash:TObjectHash;
  uiElementCounter:integer=0; // global counter for auto-generated element names
threadvar
  // Hotkeys
  hotKeys:array of THotKey;

  fControl:TUIElement;  // element with keyboard focus (set automatically or manually)
  activeWnd:TUIElement; // active window (set automatically when focus moves)

  toDelete:TObjectList; // List of elements marked for deletion

 procedure ProcessHotKey(keycode:integer;shiftstate:byte);
  var
   i:integer;
   c:TUIElement;
  begin
   for i:=0 to high(hotKeys) do
    if (hotKeys[i].vKey=keycode) then
      if (HotKeys[i].shiftstate=shiftstate) or
         ((HotKeys[i].shiftstate>0) and (HotKeys[i].shiftstate and ShiftState=HotKeys[i].shiftstate)) then
       begin
        c:=hotkeys[i].element;
        // Element should be visible and enabled
        if c.IsVisible and c.IsEnabled then
         // If there is a modal element - it should be parent
         if (modalElement=nil) or (c=modalElement) or (c.HasParent(modalElement)) then
          if c.onHotKey(keycode,shiftstate) then exit;
       end;
  end;

function DescribeElement(c:TUIElement):String8;
 begin
  if c=nil then begin
   result:='nil'; exit;
  end;
  result:=c.ClassName+'('+Conv.ToStr(c)+')='+c.name;
 end;

 function FocusedElement;
  begin
   result:=fControl;
  end;

 procedure SetFocusTo(control:TUIElement);
  begin
   try
    if control<>nil then control.SetFocus
     else begin
      if fControl<>nil then fControl.onLostFocus;
     end;
   finally
    fcontrol:=control;
   end;
  end;

 { TUIElement }

 // Transform point from element own CS to the target parent element's CS (nil - to the screen)
 // I.e. (0,0) is a top-left corner of the element's CLIENT area
 function TUIElement.TransformTo(const p:TVec2;target:TUIElement):TVec2;
  var
   parentScrollX,parentScrollY:single;
   c:TUIElement;
  begin
   c:=self;
   result:=p;
   if c=target then exit;
   repeat
    with c do begin
     if parent<>nil then begin
      parentScrollX:=parent.scroll.X;
      parentScrollY:=parent.scroll.Y;
     end else begin
      parentScrollX:=0;
      parentScrollY:=0;
     end;
     // Explanation of transformation:
     //  result.x:=(p.x+paddingLeft); // теперь относительно угла элемента
     //  result.x:=result.x-size.x*pivot.x; // теперь относительно pivot point
     //  result.x:=result.x*scale.x; // теперь в масштабе предка
     //  result.x:=position.x-parentScrollX+result.x; // теперь относительно верхнего левого угла клиентской области предка
     result.x:=position.x-parentScrollX-size.x*pivot.x+scale*(result.x+padding.Left);
     result.y:=position.y-parentScrollY-size.y*pivot.y+scale*(result.y+padding.Top);
    end;
    c:=c.parent;
   until (c=nil) or (c=target);
  end;

 function TUIElement.TransformTo(const r:TRect2;target:TUIElement):TRect2;
  var
   p1,p2:TVec2;
  begin
   p1:=TransformTo(Vec2(r.x1,r.y1),target);
   p2:=TransformTo(Vec2(r.x2,r.y2),target);
   result.Init(p1.x,p1.y, p2.x,p2.y);
  end;

 function TUIElement.TransformToScreen(const p:TVec2):TVec2;
  begin
   result:=TransformTo(p,nil);
  end;

 function TUIElement.TransformToScreen(const r:TRect2):TRect2;
  begin
   result:=TransformTo(r,nil);
  end;

 function TUIElement.TransformFromScreen(const p:TVec2):TVec2;
  var
   kx,ky,bx,by:single;
   c:TUIElement;
   sx:single;
  begin
   // Xscr = k*x+b, so test x=0 and x=1 to calculate K and B
   // This is probably not very efficient, but easier and safier
   with TransformToScreen(Vec2(0,0)) do begin
    bx:=x;
    by:=y;
   end;
   with TransformToScreen(Vec2(1,1)) do begin
    kx:=x-bx;
    ky:=y-by;
   end;
   ASSERT(abs(kx-ky)<0.001);
   // X = (Xscr-B)/K
   result.x:=(p.x-bx)/kx;
   result.y:=(p.y-by)/ky;
  end;

 function TUIElement.TransformFromScreen(const r:TRect2):TRect2;
  begin
   result.topLeft:=TransformFromScreen(r.topLeft);
   result.bottomRight:=TransformFromScreen(r.bottomRight);
  end;

 function TUIElement.GetPosOnScreen:TRect;
  begin
   globalRect:=TransformToScreen(GetRect).Rounded;
   result:=globalRect;
  end;

 function TUIElement.GetClientPosOnScreen:TRect;
  begin
   result:=TransformToScreen(GetClientRect).Rounded;
  end;

 function TUIElement.GetRect:TRect2; // Get element's area in own CS
  begin
   result.x1:=-padding.Left;
   result.y1:=-padding.Top;
   result.x2:=size.x/scale-padding.Left;
   result.y2:=size.y/scale-padding.Top;
  end;

 function TUIElement.GetClientRect:TRect2; // Get element's client area in own CS
  begin
   result.InitWH(0,0,clientWidth,clientHeight);
  end;

 function TUIElement.GetRectInParentSpace:TRect2; // Get element's area in parent client space)
  begin
   result.left:=position.x-size.x*pivot.x;
   result.top:=position.y-size.y*pivot.y;
   result.right:=position.x+size.x*(1-pivot.x);
   result.bottom:=position.y+size.y*(1-pivot.y);
  end;

 procedure TUIElement.Center(setAnchors:boolean=true);
  begin
   ASSERT(parent<>nil,'Cannot center a root UI element');
   SetPos(parent.clientWidth/2,parent.clientHeight/2,pivotCenter);
   if setAnchors then self.SetAnchors(0.5,0.5,0.5,0.5);
  end;

 procedure TUIElement.CheckAndSetFocus;
  begin
   if flags.canHaveFocus and (FocusedElement=nil) then
    SetFocus;
  end;

 class function TUIElement.ClassHash:pointer;
  begin
   result:=@UIHash;
  end;

procedure TUIElement.DeleteChildren(filter:String8='');
  var
   i,n:integer;
   wnd:TWindow;
   keep:TUIElements;
   items:Strings8;
   value:string8;
   mode:integer;
   function ShouldDelete(e:TUIElement):boolean;
    begin
     case mode of
      0:result:=pos(value,e.name)>0;
      1:result:=e.name.StartsWith(value,true);
      2:result:=not e.name.StartsWith(value,true);
     end;
    end;
  begin
   wnd:=GetWindow;
   if wnd<>nil then wnd.Lock;
   try
    if filter<>'' then begin
     SetLength(keep,length(children));
     items:=filter.split {TODO: use st.Split(char)}(':');
     value:=items[1];
     mode:=0;
     if SameText(items[0],'start') then mode:=1;
     if SameText(items[0],'!start') then mode:=2;
    end;
    n:=0;
    for i:=0 to high(children) do begin
     if (filter='') or ShouldDelete(children[i]) then
      FreeAndNil(children[i])
     else begin
      keep[n]:=children[i];
      inc(n);
     end;
    end;
    SetLength(children,0);
    if filter<>'' then begin
     SetLength(keep,n);
     children:=keep;
    end;
   finally
    if wnd<>nil then wnd.Unlock;
   end;
  end;

constructor TUIGroupBox.Create(width,height:single;parent_:TUIElement;name_:String8='');
  begin
   inherited Create(width,height,parent_,name_);
   selectedChild:=-1;
   lastGroupBox:=self;
  end;

constructor TUIElement.Create(width,height:single;parent_:TUIElement;name_:String8='');
  var
   n:integer;
   wnd:TWindow;
   defColor:cardinal;
  begin
   position:=Vec2(0,0);
   size:=Vec2(width,height);
   scale:=GetClassAttribute('defaultScale',1.0);
   pivot:=Vec2(0,0);
   SetPadding(GetClassAttribute('defaultPadding',0));
   padding.left:=GetClassAttribute('defaultPaddingLeft',padding.left);
   padding.right:=GetClassAttribute('defaultPaddingRight',padding.right);
   padding.top:=GetClassAttribute('defaultPaddingTop',padding.top);
   padding.bottom:=GetClassAttribute('defaultPaddingBottom',padding.bottom);
   shape:=shapeFull;
   timer:=0;
   parent:=parent_;
   if name_='' then
    name:=ClassName+'_'+IntToStr(Atomic.Inc(uiElementCounter))
   else
    name:=name_;
   hint:='';
   // No anchors: element's size doesn't change when parent is resized
   //anchors:=anchorNone;
   cursor:=int64(GetClassAttribute('defaultCursor',CursorID.Default));
   flags.enabled:=GetClassAttribute('defaultEnabled',true);
   flags.visible:=GetClassAttribute('defaultVisible',true);
   flags.canHaveFocus:=GetClassAttribute('defaultCanHaveFocus',false);
   flags.autoScroll:=false;
   flags.manualDraw:=false;
   flags.noParentClip:=not GetClassAttribute('defaultParentClip',true);
   flags.dontClipChildren:=not GetClassAttribute('defaultClipChildren',true);
   style:=TStyleBlock.Create;
   styleInfo:=GetClassAttribute('defaultStyleInfo','');
   defColor:=GetClassAttribute('defaultColor',clDefault);
   if defColor<>clDefault then style.SetAttr('color','$'+IntToHex(defColor,8));
   sendSignals:=ssNone;
   scroll:=Vec2(0,0);
   focusedChild:=nil;
   ownerScene:=nil;

   wnd:=GetWindow;
   if wnd<>nil then wnd.Lock;
   try
   if parent<>nil then begin // add to the parents children
    n:=length(parent.children);
    inc(n); order:=n;
    SetLength(parent.children,n);
    parent.children[n-1]:=self;
    if width=FILL_PARENT then begin
     size.x:=parent.clientWidth;
     anchors.left:=0; anchors.right:=1;
    end;
    if height=FILL_PARENT then begin
     size.y:=parent.clientHeight;
     anchors.top:=0; anchors.bottom:=1;
    end;
   end else begin
    order:=1;
   end;
   fInitialSize:=size;
   globalRect:=GetPosOnScreen;
   finally
   if wnd<>nil then wnd.Unlock;
   end;
   Signal('UI\ItemCreated',TTag(self));
  end;

destructor TUIElement.Destroy;
  var
   i,n:integer;
  begin
   try
    if fControl=self then begin
     onLostFocus;
     fControl:=nil;
    end;
    if underMouse=self then underMouse:=parent;
    if parent<>nil then
     Detach(false);
    DeleteChildren;
    if (shape<>nil) and not shape.persistent then FreeAndNil(shape);
    FreeAndNil(styleContext);
    FreeAndNil(style);
    DeleteHotkeys(0);
    Signal('UI\ItemDestroyed',TTag(self));
   except
    on e:Exception do raise EError.Create(Format('Destroy error for %s: %s',[name,ExceptionMsg(e)]));
   end;
   inherited;
  end;

 procedure TUIElement.Detach(shouldAddToRootControls:boolean=true);
  var
   i,pos,n:integer;
  begin
   if parent=nil then exit;
   n:=high(parent.children);
   pos:=-1;
   for i:=0 to n do
    if parent.children[i]=self then begin
     pos:=i; break;
    end;
   if pos>=0 then begin
    for i:=pos to n-1 do parent.children[i]:=parent.children[i+1];
    SetLength(parent.children,n);
   end;
   parent:=nil;
   if shouldAddToRootControls then
    raise EWarning.Create('Detached root UI elements are not supported; attach element to a scene root');
  end;

 procedure TUIElement.AttachTo(newParent:TUIElement;pos:integer=-1);
  var
   i,n:integer;
  begin
   ASSERT(newParent<>nil);
   if parent=newParent then exit;
   if parent<>nil then Detach(false);
   parent:=newParent;
   n:=length(parent.children);
   SetLength(parent.children,n+1);
   if pos<0 then pos:=n
    else
     for i:=n downto pos+1 do
      parent.children[i]:=parent.children[i-1];
   parent.children[pos]:=self;
  end;

 procedure TUIElement.InsertRel(element:TUIElement;rel:integer);
  var
   p:TUIElement;
   n:integer;
  begin
   p:=element.parent;
   ASSERT(p<>nil);
   //Detach(false);
   n:=element.ChildIndex;
   AttachTo(p,n+rel);
  end;

 procedure TUIElement.InsertAfter(element:TUIElement);
  begin
   InsertRel(element,1);
  end;

 procedure TUIElement.InsertBefore(element:TUIElement);
  begin
   InsertRel(element,0);
  end;

 function TUIElement.FindChildByName(const name:string8):TUIElement;
  var
   i:integer;
   c:TUIElement;
  begin
   if SameText(self.name,name) then begin
    result:=self; exit;
   end;
   for i:=0 to length(children)-1 do begin
    c:=children[i].FindChildByName(name);
    if c<>nil then begin
     result:=c; exit;
    end;
   end;
   result:=nil;
  end;

 // Sentinel "no clip" rect used to seed the recursion and to represent the
 // unclipped region a noParentClip child sees. Picked large enough to contain
 // any plausible screen coordinate without overflowing in TRect.Contains math.
 const
  UNCLIPPED_RECT:TRect=(Left:-1000000000;Top:-1000000000;Right:1000000000;Bottom:1000000000);

 function TUIElement.FindElementAt(x,y:integer;const clip:TRect;ignoreDisabled,escapingOnly:boolean;out c:TUIElement):boolean;
  var
   selfRect,clientRect,childClip,effChildClip:TRect;
   p:TPoint;
   i,j,cnt:integer;
   fl,en,childEscaping:boolean;
   c2:TUIElement;
   ca:array of TUIElement;
  begin
   // Mirrors DrawUITree's clip stack: a child is descended into normally when
   // the point lies inside its effective clip rect (clip ∩ parent client rect,
   // or the full screen for a noParentClip child). When the point is OUTSIDE
   // the effective clip, we still descend — but in "escapingOnly" mode — to
   // catch noParentClip descendants of deeper nesting (a clipping intermediate
   // would otherwise hide them from hit-test). See R-08_hittest_overlay_notes.
   result:=flags.enabled and flags.visible;
   c:=nil;
   if not flags.visible then exit; // an invisible element hits nothing
   p:=Point(x,y);
   selfRect:=GetPosOnScreen; // also refreshes globalRect
   // Compute clip passed down to non-escaping children (used only when we
   // ourselves are reachable, i.e. not escapingOnly)
   if escapingOnly or flags.dontClipChildren then
    childClip:=clip
   else begin
    clientRect:=GetClientPosOnScreen;
    childClip.Left  :=Apus.Core.Max(clip.Left  ,clientRect.Left);
    childClip.Top   :=Apus.Core.Max(clip.Top   ,clientRect.Top);
    childClip.Right :=Apus.Core.Min(clip.Right ,clientRect.Right);
    childClip.Bottom:=Apus.Core.Min(clip.Bottom,clientRect.Bottom);
   end;
   // Collect visible children
   cnt:=0;
   SetLength(ca,length(children));
   for i:=0 to length(children)-1 do
    if children[i].flags.visible then begin
     ca[cnt]:=children[i];
     inc(cnt);
    end;
   // Sort topmost first (order descending) — matches the reverse of DrawUITree
   if cnt>1 then
    for i:=0 to cnt-2 do
     for j:=cnt-1 downto i+1 do
      if ca[j-1].order<ca[j].order then begin
       c2:=ca[j]; ca[j]:=ca[j-1]; ca[j-1]:=c2;
      end;
   // Descend topmost-first; first hit wins
   fl:=false;
   for i:=0 to cnt-1 do begin
    if ca[i].flags.noParentClip then begin
     // The child resets clipping to the whole screen — descend normally.
     effChildClip:=UNCLIPPED_RECT;
     childEscaping:=false;
    end else if escapingOnly then begin
     // We are already in an out-of-clip walk; keep digging for escape boundaries.
     effChildClip:=clip; // unused inside the child; kept defined
     childEscaping:=true;
    end else begin
     effChildClip:=childClip;
     // If the point is outside the child's clipped region, the child itself is
     // not hittable here, but a deeper noParentClip descendant still might be.
     childEscaping:=not effChildClip.Contains(p);
    end;
    en:=ca[i].FindElementAt(x,y,effChildClip,ignoreDisabled,childEscaping,c2);
    if c2<>nil then begin
     c:=c2; result:=result and en;
     fl:=true; break;
    end;
   end;
   // Self is a candidate only when this subtree is itself reachable (not
   // escapingOnly), the point is inside the incoming clip and inside own rect.
   if not fl and not escapingOnly and clip.Contains(p) and selfRect.Contains(p) then begin
    if shape=shapeFull then c:=self
    else if shape=shapeEmpty then begin
     if ignoreDisabled then c:=self; // FindAnyElementAt: any visible element under point counts
    end else
     if IsOpaque((x-selfRect.Left)/selfRect.Width,(y-selfRect.Top)/selfRect.Height) then c:=self
     else if ignoreDisabled then c:=self;
   end;
   if c=nil then result:=false;
  end;

 function TUIElement.FindElementAt(x,y:integer; out c:TUIElement):boolean;
  begin
   result:=FindElementAt(x,y,UNCLIPPED_RECT,false,false,c);
  end;

 function TUIElement.FindAnyElementAt(x,y:integer; out c:TUIElement):boolean;
  begin
   result:=FindElementAt(x,y,UNCLIPPED_RECT,true,false,c);
  end;

 procedure TUIElement.SetName(n:String8);
  var
   oldName:String8;
  begin
   oldName:=name;
   inherited;
   if (oldName<>'') and (name<>oldName) then
     Signal('UI\ItemRenamed',TTag(self));
  end;

 procedure TUIElement.Snap(snapTo:TSnapMode;shrinkParent:boolean=true);
  var
   r:TUIRect;
  begin
   if parent=nil then exit;
   if snapTo=smNone then exit;
   if snapTo in [smTop,smBottom] then Resize(parent.clientWidth,-1);
   if snapTo in [smLeft,smRight] then Resize(-1,parent.clientHeight);
   if snapTo=smParent then Resize(parent.clientWidth,parent.clientHeight);
   case snapTo of
    smTop:SetAnchors(0,0,1,0).SetPos(0,0,pivotTopLeft);
    smLeft:SetAnchors(0,0,0,1).SetPos(0,0,pivotTopLeft);
    smRight:SetAnchors(1,0,1,1).SetPos(parent.clientWidth,0,pivotTopRight);
    smBottom:SetAnchors(0,1,1,1).SetPos(0,parent.clientHeight,pivotBottomLeft);
    smParent:SetAnchors(0,0,1,1).SetPos(0,0,pivotTopLeft);
   end;

{   if shrinkParent then begin
    r:=parent.padding;
    case snapTo of
     smTop:r.top:=r.top+
     smLeft:SetAnchors(0,0,0,1).SetPos(0,0,pivotTopLeft);
     smRight:SetAnchors(1,0,1,1).SetPos(parent.clientWidth,0,pivotTopRight);
     smBottom:SetAnchors(0,1,1,1).SetPos(0,parent.clientHeight,pivotBottomLeft);
     smParent:SetAnchors(0,0,1,1).SetPos(0,0,pivotTopLeft);
    end;
   end;}
  end;

 function TUIElement.ChildIndex:integer;
  var
   i:integer;
   p:TUIElement;
  begin
   result:=-1;
   p:=parent;
   if p=nil then exit;
   for i:=0 to high(p.children) do
    if p.children[i]=self then exit(i);
  end;

 function TUIElement.GetNext:TUIElement;
  var
   i:integer;
  begin
   if parent=nil then exit(self);
   i:=childIndex+1;
   if i>high(parent.children) then i:=0;
   result:=parent.children[i];
  end;

 function TUIElement.GetPrev:TUIElement;
  var
   i,n:integer;
  begin
   if parent=nil then exit(self);
   i:=childIndex-1;
   if i<0 then i:=high(parent.children);
   result:=parent.children[i];
  end;

function TUIElement.GetRoot:TUIElement;
  begin
   result:=self;
   if self=nil then exit;
   while result.parent<>nil do result:=result.parent;
  end;

function TUIElement.GetScene:TGameScene;
 var
  root:TUIElement;
 begin
  root:=GetRoot;
  if root=nil then exit(nil);
  result:=root.ownerScene;
 end;

function TUIElement.GetWindow:TWindow;
 var
  scene:TGameScene;
 begin
 scene:=GetScene;
  if (scene<>nil) and (scene.ownerWindow<>nil) then
   result:=TWindow(scene.ownerWindow)
  else
   result:=FindWindowForUIRoot(GetRoot);
 end;

procedure TUIElement.Show;
  begin
   flags.visible:=true;
  end;

 procedure TUIElement.Hide;
  begin
   flags.visible:=false;
  end;

 procedure TUIElement.Toggle;
  begin
   flags.visible:=not flags.visible;
  end;

 procedure TUIElement.Enable;
  begin
   flags.enabled:=true;
  end;

 procedure TUIElement.Disable;
  begin
   flags.enabled:=false;
  end;

 procedure TUIElement.ToggleEnabled;
  begin
   flags.enabled:=not flags.enabled;
  end;

 function TUIElement.IsVisible:boolean;
  var
   c:TUIElement;
  begin
   result:=false;
   if self=nil then exit;
   result:=flags.visible;
   c:=self;
   while c.parent<>nil do begin
    c:=c.parent;
    result:=result and c.flags.visible;
   end;
  end;

 class function TUIElement.IsWindow: boolean;
  begin
   result:=false;
  end;

function TUIElement.IsEnabled:boolean;
  var
   c:TUIElement;
  begin
   result:=false;
   if self=nil then exit;
   result:=flags.enabled;
   c:=self;
   while c.parent<>nil do begin
    c:=c.parent;
    result:=result and c.flags.enabled;
   end;
  end;

 function TUIElement.IsActiveWindow: boolean;
  begin
   result:=activeWnd=self;
  end;

 function TUIElement.HasFocus:boolean;
  var
   c:TUIElement;
  begin
   result:=false;
   c:=fControl;
   while c<>nil do begin
    if c=self then begin
      result:=true; exit;
    end;
    c:=c.parent;
   end;
  end;

 function TUIElement.HasParent(c:TUIElement):boolean;
  var
   con:TUIElement;
  begin
   result:=false;
   if c=nil then exit;
   con:=self.parent; // strict: self is not its own parent
   while con<>nil do begin
    if con=c then begin
     result:=true; exit;
    end;
    con:=con.parent;
   end;
  end;

 function TUIElement.HasChild(c:TUIElement):boolean;
  begin
   if c=nil then exit(false);
   result:=c.HasParent(self);
  end;

 function TUIElement.IsOpaque(x,y:single):boolean;
  begin
   result:=shape.IsOpaque(x,y);
  end;

 function TUIElement.IsOutOfOrder:boolean;
  begin
   result:=(order<0) or (order>=$10000) or flags.noParentClip;
  end;

 procedure TUIElement.onChar(ch:char; scancode:byte);
  begin
   if (sendSignals=ssAll) and (name<>'') then begin
    Signal('UI\'+name+'\Char',byte(ch)+scancode shl 8);
   end;
  end;

 procedure TUIElement.onUniChar(ch:Char32; scancode:byte);
  begin
   if (sendSignals=ssAll) and (name<>'') then begin
    Signal('UI\'+name+'\UniChar',word(ch)+scancode shl 16);
   end;
  end;

 function TUIElement.onHotKey(keycode,shiftstate:byte):boolean;
  begin
   result:=false;
  end;

 function TUIElement.onKey(keycode:byte; pressed:boolean;shiftstate:byte):boolean;
  begin
   if pressed and (TKey.From(keyCode)=TKey.Tab) then begin
    SetFocusToNext;
    result:=false;
    exit;
   end;
   if (sendSignals=ssAll) and (name<>'') then begin
    if pressed then
     Signal('UI\'+name+'\KeyDown',keycode+shiftstate shl 8);
   end;
   result:=true;
  end;

 procedure TUIElement.onLostFocus;
  begin
   if (sendSignals=ssAll) and (name<>'') then Signal('UI\'+name+'\Focus',0);
  end;

 procedure TUIElement.onTimer;
  begin
  end;

 procedure TUIElement.onMouseButtons(button:byte;state:boolean);
  begin
   if state then begin
    if flags.enabled and flags.canHaveFocus then SetFocus
     else begin
      // если элемент, владеющий фокусом, является потомком данного, то фокус с него не убирать!
  //    if not IsChild(FocusedControl) then SetFocusTo(nil);
  {    c:=self;
      while (c.parent<>nil) and not (c is TUIWindow) do c:=c.parent;
      c.SetFocus; // перевести фокус на корень/окно того эл-та, по которому нажали
  }
     end;
   end;
   if name<>'' then begin
    if state then Signal('UI\'+name+'\MouseDown',button)
     else Signal('UI\'+name+'\MouseUp',button);
   end;
  end;

 procedure TUIElement.onMouseMove;
  begin
   globalRect:=GetPosOnScreen;
   if (sendSignals=ssAll) and (name<>'') then
    Signal('UI\'+name+'\MouseMove',0);
  end;

 procedure TUIElement.onMouseScroll(value: integer);
  begin
   if (sendSignals=ssAll) and (name<>'') then
    Signal('UI\'+name+'\MouseScroll',value);
   if flags.autoScroll then begin // no scroller, but autoscroll is enabled
    onMouseMove;
    exit;
   end;
   if parent<>nil then
    parent.onMouseScroll(value);
  end;

 procedure TUIElement.RemoveHotKey(vKeyCode:integer;shiftstate:byte);
  begin
   DeleteHotKeys(vKeyCode,shiftState);
  end;

procedure TUIElement.DeleteHotKeys(vKeyCode:integer;shiftstate:byte);
  var
   i,max:integer;
   wnd:TWindow;
  begin
   wnd:=GetWindow;
   if wnd<>nil then wnd.Lock;
   try
   i:=0; max:=high(hotkeys);
   while i<=max do
    if (hotkeys[i].element=self) and
      ((vKeyCode=0) or
       ((hotkeys[i].vKey=vKeyCode) and
       (hotkeys[i].shiftstate=shiftstate))) then begin
     hotkeys[i]:=hotkeys[max];
     dec(max);
   end else
     inc(i);
    SetLength(hotkeys,max+1);
   finally
    if wnd<>nil then wnd.Unlock;
   end;
  end;

 procedure TUIElement.SetStyle(name,value:string8);
  var
   i,j:integer;
  begin
   i:=fStyleInfo.IndexOf(name,1,true);
   if i>0 then begin
    j:=fStyleInfo.IndexOf(';',i+1);
    if j=0 then j:=high(fStyleInfo);
    Delete(fStyleInfo,i,j-i);
   end;
   if value<>'' then name:=name+':'+value+';';
   fStyleInfo:=name+fStyleInfo
  end;

 function TUIElement.GetClientWidth:single;
  begin
   result:=size.x/scale-padding.left-padding.right;
  end;

function TUIElement.GetClientHeight:single;
  begin
   result:=size.y/scale-padding.Top-padding.Bottom;
  end;

  function TUIElement.GetGlobalScale:single;
  var
   c:TUIElement;
  begin
   result:=1.0;
   c:=parent;
   while c<>nil do begin
    result:=result*c.scale;
    c:=c.parent;
   end;
  end;

 function TUIElement.SetPos(x,y:single;pivotPoint:TVec2;autoSnap:boolean):TUIElement;
  var
   r:TRect2;
  begin
   position:=Vec2(x,y);
   pivot:=pivotPoint;
   globalRect:=GetPosOnScreen;
   if autoSnap and (parent<>nil) then begin // should snap?
    r:=GetRectInParentSpace;
    if (round(r.x1)=0) or (round(r.y1)=0) then begin // top-left corner
     anchors.left:=0; anchors.top:=0;
     if round(r.Width-parent.clientWidth)=0 then begin // snap to the top
      anchors.right:=1;
      if r.height>parent.clientHeight*0.8 then anchors.bottom:=1;
      if r.height<parent.clientHeight*0.2 then anchors.bottom:=0;
     end;
     if round(r.Height-parent.clientHeight)=0 then begin // snap to the left
      anchors.bottom:=1;
      if r.width>parent.clientWidth*0.8 then anchors.right:=1;
      if r.width<parent.clientWidth*0.2 then anchors.right:=0;
     end;
    end;
    if round(r.x2-parent.clientWidth)=0 then begin
     anchors.right:=1;
     if r.width<parent.clientWidth*0.6 then anchors.left:=1;
    end;
    if round(r.y2-parent.clientHeight)=0 then begin
     anchors.bottom:=1;
     if r.height<parent.clientHeight*0.6 then anchors.top:=1;
    end;
   end;
   result:=self;
  end;

 function TUIElement.SetPos(x,y:single;autoSnap:boolean):TUIElement;
  begin
   result:=SetPos(x,y,pivotTopLeft,autoSnap);
  end;

 procedure TUIElement.MoveBy(dx,dy:single);
  var
   s:single;
   delta:TVec2;
  begin
   s:=1/globalScale;
   dx:=dx*s; dy:=dy*s;
   position.Add(Vec2(dx,dy));
  end;

 function TUIElement.SetAnchors(left,top,right,bottom:single):TUIElement;
  begin
   anchors.Left:=left;
   anchors.Top:=top;
   anchors.Bottom:=bottom;
   anchors.Right:=right;
   result:=self;
  end;

 function TUIElement.SetPaddings(left,top,right,bottom:single):TUIElement;
  begin
   padding.Left:=left;
   padding.Top:=top;
   padding.Right:=right;
   padding.Bottom:=bottom;
   Resize(size.x,size.y);
   result:=self;
  end;

 function TUIElement.SetPadding(padding:single):TUIElement;
  begin
   result:=SetPaddings(padding,padding,padding,padding);
  end;

 function TUIElement.SetScale(newScale:single):TUIElement;
  var
   oldW,oldH:single;
  begin
   result:=self;
   if newScale<>scale then begin
    oldW:=clientWidth;
    oldH:=clientHeight;
    scale:=newScale;
    ClientSizeChanged(clientWidth-oldW,clientHeight-oldH); // update children
   end;
  end;

 procedure TUIElement.Resize(newWidth,newHeight:single);
  var
   oldW,oldH:single;
  begin
   oldW:=clientWidth;
   oldH:=clientHeight;
   if newWidth>-1 then size.x:=newWidth;
   if newHeight>-1 then size.y:=newHeight;
   if newWidth=uiInherit then size.x:=parent.clientWidth;
   if newHeight=uiInherit then size.y:=parent.clientHeight;
   ClientSizeChanged(clientWidth-oldW,clientHeight-oldH); // update children
  end;

 procedure TUIElement.ResizeClient(newClientWidth,newClientHeight:single);
  var
   dW,dH:single;
  begin
   dW:=newClientWidth-clientWidth;
   dH:=newClientHeight-clientHeight;
   if newClientWidth<0 then dW:=0;
   if newClientHeight<0 then dH:=0;
   size.x:=size.x+dW*scale;
   size.y:=size.y+dH*scale;
   ClientSizeChanged(dW,dH); // update children
  end;

 procedure TUIElement.ClientSizeChanged(dX,dY:single);
  var
   i:integer;
  begin
   for i:=0 to length(children)-1 do
    children[i].ParentSizeChanged(dX,dY);
   SetupScrollers;
  end;

 procedure TUIElement.ParentSizeChanged(dX,dY:single);
  var
   rect:TRect2;
   pW,pH,rX,rY:single;
  begin
   case placementMode of
    pmAnchored:begin // move/resize considering anchors
     Resize(size.x+dX*(anchors.Right-anchors.Left),size.y+dY*(anchors.Bottom-anchors.Top));
     rect:=GetRectInParentSpace;
     // adjust rect boundary according to anchors
     rect.x1:=rect.left+dX*anchors.Left;
     rect.y1:=rect.top+dY*anchors.Top;
     rect.x2:=rect.right+dX*anchors.Right;
     rect.y2:=rect.bottom+dY*anchors.Bottom;
     // set position to the calculated pivot point
     position.x:=rect.x1*(1-pivot.x)+rect.x2*pivot.x;
     position.y:=rect.y1*(1-pivot.y)+rect.y2*pivot.y;
    end;
    pmProportional,pmMoveProportional:begin // parent is "rubber", move proportionally
     pW:=parent.clientWidth;
     rX:=pW/(pW-dX);
     pH:=parent.clientHeight;
     rY:=pH/(pH-dY);
     if placementMode=pmProportional then
      Resize(size.x*rX,size.y*rY);
     position:=position*Vec2(rX,rY);
    end;
   end;
  end;

 procedure TUIElement.SetStyleInfo(sInfo:String8);
  begin
   if fStyleInfo<>sInfo then begin
    fStyleInfo:=sInfo;
    styleInfoChanged:=true;
    style.ParseText(sInfo);  // eager: style is always non-nil
   end;
  end;

 function TUIElement.HasState(const name:String8):boolean;
  begin
   result:=style.HasState(name);
  end;

 procedure TUIElement.SetState(const name:String8; active:boolean);
  begin
   style.SetState(name,active);
  end;

 // Resolve style value: own block (with refs) → parent chain for inheritable attrs
 function TUIElement.GetStyleValue(const key:String8; const defVal:String8):String8;
  var
   item:TUIElement;
  begin
   // own block first
   result:=ResolveBlockAttr(style,key,'');
   if result<>'' then exit;
   // walk parent chain for inheritable attributes
   item:=parent;
   while item<>nil do begin
    result:=ResolveBlockAttr(item.style,key,'');
    if result<>'' then exit;
    item:=item.parent;
   end;
   result:=defVal;
  end;

 function TUIElement.GetStyleColor(const key:String8; defVal:cardinal):cardinal;
  var
   s:String8;
  begin
   s:=GetStyleValue(key,'');
   if s='' then exit(defVal);
   result:=ParseStyleColor(s);
   if (result=0) and (s<>'0') then result:=defVal;
  end;

 function TUIElement.GetStyleNumber(const key:String8; defVal:single):single;
  var
   s:String8;
  begin
   s:=GetStyleValue(key,'');
   if s='' then exit(defVal);
   result:=Conv.ToFloat(s);
  end;

 function TUIElement.GetStyleInt(const key:String8; defVal:integer):integer;
  begin
   result:=round(GetStyleNumber(key,defVal));
  end;

 function TUIElement.GetBaseStyleColor(const key:String8; defVal:cardinal):cardinal;
  var
   s:String8;
   item:TUIElement;
  begin
   s:=ResolveBlockAttrBase(style,key,'');
   if s='' then begin
    item:=parent;
    while item<>nil do begin
     s:=ResolveBlockAttrBase(item.style,key,'');
     if s<>'' then break;
     item:=item.parent;
    end;
   end;
   if s='' then exit(defVal);
   result:=ParseStyleColor(s);
   if (result=0) and (s<>'0') then result:=defVal;
  end;

 function TUIElement.GetBaseStyleNumber(const key:String8; defVal:single):single;
  var
   s:String8;
   item:TUIElement;
  begin
   s:=ResolveBlockAttrBase(style,key,'');
   if s='' then begin
    item:=parent;
    while item<>nil do begin
     s:=ResolveBlockAttrBase(item.style,key,'');
     if s<>'' then break;
     item:=item.parent;
    end;
   end;
   if s='' then exit(defVal);
   result:=Conv.ToFloat(s);
  end;

 procedure TUIElement.SetupScrollers;
  begin
  end;

procedure TUIElement.SafeDestroy;
  begin
   toDelete.Add(self,true);
  end;

 procedure TUIElement.ScrollTo(newX,newY:integer);
  begin
   scroll.X:=newX; scroll.Y:=newY;
  end;

 procedure TUIScrollable.SetupScrollers;
  var
   i:integer;
  begin
   childrenBound.Init(0,0,0,0);
   for i:=0 to length(children)-1 do
    if children[i].flags.visible and not children[i].IsOutOfOrder then
     childrenBound.Include(children[i].GetRectInParentSpace);
   if scrollerV<>nil then begin
    scrollerV.SetRange(childrenBound.y1,childrenBound.y2);
    scrollerV.SetPageSize(clientHeight);
    scrollerV.SetStep(clientHeight/3);
   end;
   if scrollerH<>nil then begin
    scrollerH.SetRange(childrenBound.x1,childrenBound.x2);
    scrollerH.SetPageSize(clientWidth);
    scrollerH.SetStep(clientWidth/3);
   end;
  end;

 procedure TUIScrollable.ScrollTo(newX,newY:integer);
  begin
   scroll.X:=newX; scroll.Y:=newY;
   if scrollerH<>nil then scrollerH.SetValue(scroll.X);
   if scrollerV<>nil then scrollerV.SetValue(scroll.Y);
  end;

 procedure TUIScrollable.onMouseScroll(value:integer);
  begin
   if scrollerV<>nil then begin
    scrollerV.MoveRel(-scrollerV.GetStep*value/100,true);
    exit;
   end;
   inherited;
  end;

 function TUIElement.SetAnchors(anchorMode:TAnchorMode):TUIElement;
  begin
   anchors:=anchorMode;
   result:=self;
  end;

 class procedure TUIElement.SetDefault(name:String8;value:variant);
  begin
   if name[1] in ['a'..'z'] then name[1]:=UpCase(name[1]);
   SetClassAttribute('default'+name,value);
  end;

 procedure TUIElement.SetFocus;
  var
   c:TUIElement;
   i:integer;
  begin
   if not (flags.enabled and flags.visible) then exit;
   // Сигнал о потере фокуса
   if (fControl<>nil) and (fControl<>self) then with fControl do begin
    onLostFocus;
    if hooked<>nil then hooked.onLostFocus;
   end;
   // Первым делом нужно запомнить элемент, владеющий фокусом в окне (если он в окне)
   if FocusedElement<>nil then begin
    c:=FocusedElement;
    while (c.parent<>nil) and not c.IsWindow do c:=c.parent;
    c.focusedChild:=FocusedElement;
   end;
   fControl:=nil; // это для возможности рекурсивных вызовов

   // Если данный элемент вложен в окно - сделаем это окно активным
   c:=self;
   while (c.parent<>nil) and not c.IsWindow do c:=c.parent;
   if c.IsWindow then begin
    activeWND:=c;
    if self=c then begin // установка фокуса на окно
     if focusedChild<>nil then begin
      focusedChild.SetFocus; exit
     end else // установка фокуса на первый доступный элемент
      {$IFNDEF IOS}  // don't auto set focus for mobile devices
      for i:=0 to length(children)-1 do
       if children[i].flags.canHaveFocus then begin
        children[i].SetFocus;
        exit;
       end;
      {$ENDIF}
  //   fControl:=self;
     exit;
    end
     else fControl:=self;
   end else begin
    activeWND:=nil;
    fControl:=self;
   end;

   // Сигнал о получении фокуса
   if (sendSignals=ssAll) and (name<>'') then Signal('UI\'+name+'\Focus',1);
  end;

 procedure TUIElement.SetFocusToNext;
  var
   c:TUIElement;
   dir:boolean;
   i:integer;
   fl:boolean;
  begin
   c:=self;
   dir:=true;
   repeat
    // если есть вложенные и можно идти вперед - идем вперед
    if dir and (length(c.children)>0) then begin
     c:=c.children[0]; continue;
    end;
    // Если вперед идти нельзя или невозможно, можно ли пойти на тот же уровень?
    if (c.parent<>nil) and (length(c.parent.children)>1) then begin
     fl:=false;
     for i:=0 to length(c.parent.children)-2 do
      if (c.parent.children[i]=c) then begin
       c:=c.parent.children[i+1];
       dir:=true; // разрешить движение вперед
       fl:=true;
       break;
      end;
     if fl then continue;
    end;
    // Если ничего другого не остается кроме как возвращаться назад...
    if c.parent<>nil then begin
     dir:=false;
     c:=c.parent;
    end else
     dir:=true; // назад идти тоже нельзя
   until (c.flags.enabled and c.flags.visible and c.flags.canHaveFocus) or (c=self);
   if c.flags.canHaveFocus then c.SetFocus;
  end;

 procedure TUIElement.SetFocusToPrev;
  begin
   NotImplemented;
  end;

 procedure TUIElement.SetHotKey(vKeyCode:integer;shiftstate:byte);
  var
   i:integer;
  begin
   // Check for duplicate
   for i:=0 to high(hotKeys) do
    if (hotkeys[i].element=self) and (hotkeys[i].vKey=vKeyCode) and
       (hotkeys[i].shiftstate=shiftstate) then exit;
   i:=length(hotKeys);
   SetLength(hotkeys,i+1);
   hotkeys[i].vKey:=vKeyCode;
   hotkeys[i].shiftstate:=shiftstate;
   hotkeys[i].element:=self;
  end;

procedure DestroyQueuedElements;
 var
  wnd:TWindow;
  begin
    wnd:=window;
    if wnd<>nil then wnd.Lock;
    try
     toDelete.FreeAll;
    finally
     if wnd<>nil then wnd.Unlock;
    end;
  end;

{ TLayouter }

 function TLayouter.GetItems(parent:TUIElement):TUIElements;
  var
   i,n:integer;
   item:TUIElement;
  begin
   SetLength(result,length(parent.children));
   n:=0;
   for i:=0 to high(parent.children) do begin
    item:=parent.children[i];
    if not item.flags.visible or item.IsOutOfOrder then continue;
    result[n]:=item;
    inc(n);
   end;
   SetLength(result,n);
  end;

initialization
 UIHash.Init;
 TUIElement.SetClassAttribute('handleMouseIfDisabled',false);
finalization
end.

