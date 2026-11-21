// -----------------------------------------------------
// Popup menu: a panel of command lines opened below an anchor element or at a point;
// a line may open a submenu
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
// ------------------------------------------------------

unit Apus.Engine.UIMenu;
interface
 uses Apus.Core, Apus.Lib, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIWidgets;

 // Terms used below:
 //   owner     - the element a menu belongs to: its parent at creation (for a submenu - its
 //               line). A closed menu lives hidden in its owner and returns there on close
 //   anchor    - the element a menu was opened from (OpenBelow); optional
 //   UI root   - the root element the open panels are attached to while shown
 //   root menu - the first panel of an open chain: the menu the application opened

 type
  TUIPopupMenu=class;

  // Menu line: a button that draws its caption on the left and the shortcut text on the right.
  // Not focusable: the root menu keeps the focus and tracks the current line.
  // A disabled line stays visible but never becomes current.
  // The command is any of the button handlers - onClick, onClickMethod, onClickAsync,
  // onClickEvent; all run after the menu is closed: Add('Save','Ctrl+S').onClickMethod:=Save
  // A submenu line (TUIPopupMenu.AddSubmenu) has no command: it opens its submenu.
  TUIMenuItem=class(TUIButton)
   shortcut:String8;      // display only (the key itself is registered elsewhere)
   constructor Create(menu:TUIPopupMenu;const caption,shortcut,name:String8);
   destructor Destroy; override;
   procedure onRemoved; override;
   function Menu:TUIPopupMenu;
   function IsHovered:boolean; override; // highlighted = the current line of the menu
   procedure onMouseMove; override;      // reports the pointer to the menu (TUIPopupMenu.LineHover)
   function ShortcutFontSize:single;     // 'shortcut-font-size', smaller than the caption by default
   function ShortcutFont:TFontHandle;
   function ArrowWidth:single;           // the submenu arrow column of the menu, 0 - none
  protected
   procedure DoClick; override;          // a command: close the menus, then call the handlers
  private
   fSubmenu:TUIPopupMenu;
   procedure Unlink;
  public
   property submenu:TUIPopupMenu read fSubmenu; // nil - a command line
  end;

  // A thin line between groups of menu lines
  TUIMenuSeparator=class(TUIElement)
   constructor Create(menu:TUIPopupMenu);
  end;

  // Popup menu: a panel that builds its lines and keeps the keyboard focus while open.
  // Created once, lives hidden in its owner; while open it is attached to the UI root.
  // A press outside the menu closes it and goes on to its target. The focus returns to
  // where it was before the menu opened.
  // Submenus: the open panels form a chain from the root menu. Only the root menu holds
  // the focus: it passes the keys to the deepest open panel. Keys: Up/Down/Home/End - the
  // current line, Right/Enter - open a submenu, Left/Esc - close one level (Esc at the root
  // menu - the whole chain), Enter/Space - run the current command.
  // Auto close: the pointer away from the whole chain (farther than autoCloseDistance,
  // longer than autoCloseDelay) closes the whole chain and restores the focus.
  TUIPopupMenu=class(TUIPopup)
   // Called before each panel is shown, a submenu included: may update the lines (enabled,
   // visible, captions) or rebuild them with Clear and Add
   onOpen:TObjProcedure;
   lineHeight:single;       // height of a line, 0 - by the font size
   autoCloseDistance:single; // margin around the menu in UI units: <0 - two line heights, 0 - no auto close
   autoCloseDelay:integer;  // ms, 0 - no auto close; both are read from the root menu
   constructor Create(owner:TUIElement;name:String8='');
   destructor Destroy; override;
   function ContainsElement(element:TUIElement):boolean; override; // + the open submenus
  protected
   procedure DismissPopup; override;
  public
   // A line without a command (set one on the result); name '' - '<prefix>\<caption>'
   // with "&" and a trailing "..." removed, other signs -> '_'; the prefix is the name of
   // the submenu line (ownerItem) or of a standalone menu
   function Add(const caption:String8;const shortcut:String8='';const name:String8=''):TUIMenuItem;
   // A submenu line and its hidden submenu; returns the submenu to fill. The line gets the
   // name (default as in Add), the submenu - '<name>_Menu'
   function AddSubmenu(const caption:String8;const name:String8=''):TUIPopupMenu;
   function AddSeparator:TUIMenuSeparator;
   procedure Clear;
   // Open with the top-left corner at (x,y) of the UI root (nil - the root of the owner)
   procedure OpenAt(x,y:single;root:TUIElement=nil);
   // Open below the anchor (above it if there is no room). A press on the anchor closes
   // the open menu, and the click that follows doesn't open it again
   procedure OpenBelow(anchor:TUIElement);
   // Close this panel with its open submenus; the root menu closes the whole chain
   procedure Close;
   function IsOpen:boolean; // this panel is shown
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onMouseMove; override;
   procedure onLostFocus; override; // the focus is taken away - close, the taker keeps it
   procedure onRemoved; override;
   procedure onTimer; override;     // submenu switch delay, auto close, safety checks
  private
   fCurrent:TUIMenuItem;
   fOpen:boolean;
   owner:TUIElement;     // see the terms above; nil once the menu is removed
   rootSize:TVec2;       // the size of the UI root when opened
   anchor:TUIElement;    // see the terms above; part of the auto close zone
   held:boolean;         // the root menu holds owner and anchor (Acquire) while open
   fChild:TUIPopupMenu;  // the open submenu
   openLeft:boolean;     // opened to the left of the parent panel: further levels try it first
   arrowW:single;        // width of the submenu arrow column, 0 - no submenu lines
   // Submenu switch after the hover delay: open switchTo's submenu, or close the open
   // submenu (switchTo=nil or a command line)
   switchPending:boolean;
   switchTo:TUIMenuItem;
   switchAt:int64;
   pointerArmed:boolean; // the pointer has moved since the menu opened
   armPos:TPoint;
   outsideSince:int64;   // the pointer has been out of the zone since then, 0 - inside
   procedure SetCurrent(item:TUIMenuItem);
   function GetOwnerItem:TUIButton;
   function ParentMenu:TUIPopupMenu;
   function IsChainChild:boolean;
   function ChainRoot:TUIPopupMenu;
   function Deepest:TUIPopupMenu;
   function DefaultLineHeight:single;
   procedure Open(root,anchor:TUIElement;x,y,upY:single);
   procedure DoClose(restoreFocus:boolean);
   procedure Unlink;
   procedure ReleaseHolds;
   procedure OpenChild(item:TUIMenuItem;keyboard:boolean);
   procedure PlaceSubmenu(sub:TUIPopupMenu;item:TUIMenuItem);
   procedure CloseChild(reattach:boolean=true);
   procedure LineHover(item:TUIMenuItem;over:boolean);
   procedure DelaySwitch(item:TUIMenuItem);
   procedure CancelSwitch;
   function CloseScheduled:boolean;
   procedure ApplySwitch;
   procedure PointerInside;
   function AutoClosed(now:int64):boolean;
   procedure Measure;
   procedure MoveCurrent(dir:integer);
  public
   property current:TUIMenuItem read fCurrent write SetCurrent; // an enabled line or nil
   property ownerItem:TUIButton read GetOwnerItem; // the submenu line, nil for a standalone menu
  end;

implementation
 uses Apus.Geom2D, Apus.Engine.Window, Apus.Engine.UIShapes;

 const
  SEPARATOR_HEIGHT=9;
  LINE_HEIGHT=2.6;     // default line height, in font sizes
  SHORTCUT_GAP=3;      // min space between the captions and the shortcuts, in font sizes
  SHORTCUT_SCALE=0.85; // default shortcut font size relative to the caption font
  ARROW_COLUMN=1.6;    // width of the submenu arrow column, in font sizes
  CHECK_INTERVAL=100;  // ms between the checks of an open menu (auto close, safety)
  SUBMENU_DELAY=200;   // ms of hover before a submenu opens or switches
  AUTO_CLOSE_DELAY=1000;

 function IsSelectable(e:TUIElement):boolean;
  begin
   result:=(e is TUIMenuItem) and e.flags.visible and e.flags.enabled;
  end;

 // Width of the caption or the shortcut in the units of the line
 function TextWidth(item:TUIMenuItem;shortcut:boolean):single;
  var
   text:String8;
   size:single;
   font:TFontHandle;
  begin
   if shortcut then text:=item.shortcut else text:=item.caption;
   if text='' then exit(0);
   if txt=nil then begin // no text drawer (headless): an estimate by the font size
    if shortcut then size:=item.ShortcutFontSize
     else size:=item.GetStyleNumber('font-size',9);
    exit(length(text)*size*0.6);
   end;
   if shortcut then font:=item.ShortcutFont else font:=item.StyleFont;
   result:=txt.Width(font,text)/item.globalScale;
  end;

 // The name must be a valid identifier (elements are published by name): spaces and other
 // ASCII signs become '_', non-ASCII letters are dropped, an empty result becomes 'ItemN'
 function DefaultItemName(menu:TUIPopupMenu;const caption:String8):String8;
  var
   i,n,last:integer;
   prefix:String8;
  begin
   if menu.ownerItem<>nil then prefix:=menu.ownerItem.name
    else prefix:=menu.name;
   if prefix='' then exit('');
   last:=length(caption);
   if (last>=3) and (copy(caption,last-2,3)='...') then dec(last,3);
   SetLength(result,last);
   n:=0;
   for i:=1 to last do
    if (caption[i]<>'&') and (caption[i]<#128) then begin
     inc(n);
     if caption[i] in ['A'..'Z','a'..'z','0'..'9','_'] then result[n]:=caption[i]
      else result[n]:='_';
    end;
   SetLength(result,n);
   if result='' then result:='Item'+Conv.ToStr(length(menu.children)+1);
   result:=prefix+'\'+result;
  end;

{ TUIMenuItem }

 constructor TUIMenuItem.Create(menu:TUIPopupMenu;const caption,shortcut,name:String8);
  begin
   inherited Create(10,10,menu,name);
   self.caption:=caption;
   self.shortcut:=shortcut;
   flags.canHaveFocus:=false;
   SetPaddings(12,0,12,0);
  end;

 // An open submenu lives at the UI root, out of the line's subtree: it goes with the line
 destructor TUIMenuItem.Destroy;
  begin
   Unlink; // a direct Free skips onRemoved
   if (fSubmenu<>nil) and (fSubmenu.parent<>self) and not fSubmenu.deleted then fSubmenu.Remove;
   inherited;
  end;

 procedure TUIMenuItem.onRemoved;
  begin
   Unlink;
   inherited;
  end;

 // The menu forgets the line: its open submenu is hidden in place (no tree changes - this
 // runs in onRemoved too), it is no longer current or scheduled
 procedure TUIMenuItem.Unlink;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   if m=nil then exit;
   if (fSubmenu<>nil) and (m.fChild=fSubmenu) then m.CloseChild(false);
   if m.fCurrent=self then m.fCurrent:=nil;
   if m.switchPending and (m.switchTo=self) then m.CancelSwitch;
  end;

 function TUIMenuItem.ShortcutFontSize:single;
  begin
   result:=GetStyleNumber('shortcut-font-size',GetStyleNumber('font-size',9)*SHORTCUT_SCALE);
  end;

 function TUIMenuItem.ShortcutFont:TFontHandle;
  begin
   if txt=nil then exit(0);
   result:=txt.GetFont(GetStyleValue('font','Default'),round(ShortcutFontSize*globalScale),fsIgnoreScale);
  end;

 function TUIMenuItem.ArrowWidth:single;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   if m<>nil then result:=m.arrowW
    else result:=0;
  end;

 function TUIMenuItem.Menu:TUIPopupMenu;
  begin
   if parent is TUIPopupMenu then result:=TUIPopupMenu(parent)
    else result:=nil;
  end;

 function TUIMenuItem.IsHovered:boolean;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   result:=(m<>nil) and (m.fCurrent=self);
  end;

 // Called on enter, move and leave - for a disabled line too (DispatchMouseMove)
 procedure TUIMenuItem.onMouseMove;
  var
   m:TUIPopupMenu;
  begin
   inherited;
   m:=Menu;
   if m<>nil then m.LineHover(self,underMouse=self);
  end;

 procedure TUIMenuItem.DoClick;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   if fSubmenu<>nil then begin // a submenu line has no command
    if m<>nil then m.OpenChild(self,false);
    exit;
   end;
   if m<>nil then m.ChainRoot.Close; // first: a command that opens a dialog sets its focus after the restore
   inherited;
  end;

{ TUIMenuSeparator }

 constructor TUIMenuSeparator.Create(menu:TUIPopupMenu);
  begin
   inherited Create(10,SEPARATOR_HEIGHT,menu,'');
  end;

{ TUIPopupMenu }

 constructor TUIPopupMenu.Create(owner:TUIElement;name:String8);
  begin
   inherited Create(100,10,owner,name);
   self.owner:=owner;
   shape:=shapeFull; // a press on the padding stays inside the menu
   SetPaddings(4,4,4,4);
   autoCloseDistance:=-1;
   autoCloseDelay:=AUTO_CLOSE_DELAY;
  end;

 destructor TUIPopupMenu.Destroy;
  begin
   Unlink; // a direct Free skips onRemoved; before inherited: it clears the focus (onLostFocus)
   inherited;
  end;

 function TUIPopupMenu.ContainsElement(element:TUIElement):boolean;
  begin
   result:=inherited ContainsElement(element) or
     ((fChild<>nil) and fChild.ContainsElement(element));
  end;

 function TUIPopupMenu.Add(const caption,shortcut,name:String8):TUIMenuItem;
  var
   n:String8;
  begin
   n:=name;
   if n='' then n:=DefaultItemName(self,caption);
   result:=TUIMenuItem.Create(self,caption,shortcut,n);
  end;

 function TUIPopupMenu.AddSubmenu(const caption,name:String8):TUIPopupMenu;
  var
   item:TUIMenuItem;
   n:String8;
  begin
   item:=Add(caption,'',name);
   n:=item.name;
   if n<>'' then n:=n+'_Menu';
   result:=TUIPopupMenu.Create(item,n);
   item.fSubmenu:=result;
  end;

 function TUIPopupMenu.AddSeparator:TUIMenuSeparator;
  begin
   result:=TUIMenuSeparator.Create(self);
  end;

 procedure TUIPopupMenu.Clear;
  begin
   CloseChild;
   CancelSwitch;
   fCurrent:=nil;
   DeleteChildren;
  end;

 function TUIPopupMenu.IsOpen:boolean;
  begin
   result:=fOpen;
  end;

 procedure TUIPopupMenu.SetCurrent(item:TUIMenuItem);
  begin
   if (item<>nil) and ((item.parent<>self) or not IsSelectable(item)) then item:=nil;
   fCurrent:=item;
  end;

 function TUIPopupMenu.GetOwnerItem:TUIButton;
  begin
   if (owner is TUIMenuItem) and (TUIMenuItem(owner).fSubmenu=self) then result:=TUIButton(owner)
    else result:=nil;
  end;

 function TUIPopupMenu.ParentMenu:TUIPopupMenu;
  begin
   if (owner is TUIMenuItem) and (TUIMenuItem(owner).fSubmenu=self) then result:=TUIMenuItem(owner).Menu
    else result:=nil;
  end;

 // Open as a submenu of the parent panel (not a standalone open of a submenu panel)
 function TUIPopupMenu.IsChainChild:boolean;
  var
   p:TUIPopupMenu;
  begin
   p:=ParentMenu;
   result:=(p<>nil) and (p.fChild=self);
  end;

 function TUIPopupMenu.ChainRoot:TUIPopupMenu;
  begin
   result:=self;
   while result.IsChainChild do result:=result.ParentMenu;
  end;

 function TUIPopupMenu.Deepest:TUIPopupMenu;
  begin
   result:=self;
   while result.fChild<>nil do result:=result.fChild;
  end;

 function TUIPopupMenu.DefaultLineHeight:single;
  begin
   if lineHeight>0 then result:=lineHeight
    else result:=round(GetStyleNumber('font-size',9)*LINE_HEIGHT);
  end;

 // Lines get the width of the widest one; called after the attach to the UI root:
 // the inherited font and scale depend on the parent
 procedure TUIPopupMenu.Measure;
  var
   c:TUIElement;
   item:TUIMenuItem;
   capW,cutW,padR,w,h,y,fontSize:single;
   hasCuts,hasArrows:boolean;
  begin
   capW:=0; cutW:=0; padR:=0;
   hasCuts:=false; hasArrows:=false;
   for c in children do
    if (c is TUIMenuItem) and c.flags.visible then begin
     item:=TUIMenuItem(c);
     capW:=Max(capW,item.padding.Left+TextWidth(item,false));
     if item.shortcut<>'' then begin
      hasCuts:=true;
      cutW:=Max(cutW,TextWidth(item,true));
     end;
     if item.fSubmenu<>nil then hasArrows:=true;
     padR:=Max(padR,item.padding.Right);
    end;
   w:=capW+cutW+padR;
   fontSize:=GetStyleNumber('font-size',9);
   if hasCuts then w:=w+fontSize*SHORTCUT_GAP;
   arrowW:=0;
   if hasArrows then begin
    arrowW:=fontSize*ARROW_COLUMN;
    w:=w+arrowW;
   end;
   y:=0;
   for c in children do begin
    if not c.flags.visible then continue;
    if c is TUIMenuSeparator then h:=SEPARATOR_HEIGHT
    else
    if lineHeight>0 then h:=lineHeight
    else
     h:=round(c.GetStyleNumber('font-size',9)*LINE_HEIGHT);
    c.pivot:=Vec2(0,0);
    c.position:=Vec2(0,y);
    c.size:=Vec2(w,h);
    y:=y+h;
   end;
   size:=Vec2(w+padding.Left+padding.Right,y+padding.Top+padding.Bottom);
  end;

 // Open as the root menu. (x,y) - the top-left corner in the UI root; upY - the bottom
 // edge if there is no room below
 procedure TUIPopupMenu.Open(root,anchor:TUIElement;x,y,upY:single);
  var
   wnd:TWindow;
  begin
   if fOpen then DoClose(true);
   if deleted or (owner=nil) then exit; // the close may remove a menu whose owner is gone
   if Assigned(onOpen) then onOpen;
   if deleted or (owner=nil) or owner.deleted or root.deleted then exit;
   if not RegisterPopup(root,anchor) then exit;
   AttachTo(root);
   Measure;
   PlacePopup(root,x,y,upY);
   rootSize:=Vec2(root.clientWidth,root.clientHeight);
   // owner and anchor are read by the timer: they must stay valid while the menu is open
   held:=owner.Acquire;
   if not held or ((anchor<>nil) and not anchor.Acquire) then anchor:=nil;
   self.anchor:=anchor;
   fCurrent:=nil;
   openLeft:=false;
   CancelSwitch;
   wnd:=root.GetWindow;
   pointerArmed:=false;
   outsideSince:=0;
   if wnd<>nil then armPos:=wnd.mousePos;
   flags.visible:=true;
   fOpen:=true;
   timer:=CHECK_INTERVAL;
   SavePopupFocus(wnd);
   SetFocus;
  end;

 procedure TUIPopupMenu.OpenAt(x,y:single;root:TUIElement);
  begin
   if root=nil then begin
    if owner=nil then exit;
    root:=owner.GetRoot;
   end;
   Open(root,nil,x,y,y);
  end;

 procedure TUIPopupMenu.OpenBelow(anchor:TUIElement);
  var
   root:TUIElement;
   r:TRect2;
  begin
   if TakeAnchorGuard(anchor) then exit;
   root:=anchor.GetRoot;
   r:=anchor.TransformTo(anchor.GetRect,root);
   Open(root,anchor,r.x1,r.y2,r.y1);
  end;

 procedure TUIPopupMenu.Close;
  begin
   if IsChainChild then ParentMenu.CloseChild
    else DoClose(true);
  end;

 procedure TUIPopupMenu.DismissPopup;
  begin
   Close;
  end;

 procedure TUIPopupMenu.ReleaseHolds;
  begin
   if not held then exit;
   held:=false;
   if anchor<>nil then anchor.Release;
   anchor:=nil;
   if owner<>nil then owner.Release;
  end;

 procedure TUIPopupMenu.DoClose(restoreFocus:boolean);
  begin
   if not fOpen then exit;
   if IsChainChild then begin
    ParentMenu.CloseChild;
    exit;
   end;
   CloseChild;
   fOpen:=false; // first: the focus change below calls onLostFocus
   timer:=0;
   fCurrent:=nil;
   CancelSwitch;
   flags.visible:=false;
   if restoreFocus then EndPopup(pfcRestore) else EndPopup(pfcLeave);
   if deleted then
    ReleaseHolds
   else
   if (owner<>nil) and not owner.deleted then begin
    AttachTo(owner);
    ReleaseHolds;
   end else begin
    ReleaseHolds;
    Remove; // the owner is gone: the menu can't return to it and goes too
   end;
  end;

 // The menu drops its links to the other panels and to its owner: from onRemoved (no tree
 // changes there: the open panels are hidden in place, the submenu lines remove the panels
 // left at the UI root when destroyed) and from Destroy (a direct Free). The second call
 // is a no-op: the owner may already be freed then
 procedure TUIPopupMenu.Unlink;
  begin
   CloseChild(false);
   if IsChainChild then ParentMenu.fChild:=nil;
   if (owner is TUIMenuItem) and (TUIMenuItem(owner).fSubmenu=self) then TUIMenuItem(owner).fSubmenu:=nil;
   if fOpen then begin
    fOpen:=false;
    flags.visible:=false;
    timer:=0;
    fCurrent:=nil;
    CancelSwitch;
   end;
   ReleaseHolds;
   owner:=nil;
  end;

 // The submenu of the item opens next to its line. It takes no focus: the root menu keeps it
 procedure TUIPopupMenu.OpenChild(item:TUIMenuItem;keyboard:boolean);
  var
   sub:TUIPopupMenu;
  begin
   CancelSwitch;
   if not fOpen or (item=nil) or item.deleted or (item.parent<>self) or not IsSelectable(item) then exit;
   sub:=item.fSubmenu;
   if (sub=nil) or sub.deleted then exit;
   fCurrent:=item;
   if fChild=sub then begin
    if keyboard and (sub.fCurrent=nil) then sub.MoveCurrent(1);
    exit;
   end;
   CloseChild;
   if Assigned(sub.onOpen) then begin
    sub.onOpen;
    // the callback may change the menus: open only if the request still stands
    if deleted or not fOpen or item.deleted or (item.parent<>self) or (item.fSubmenu<>sub) or
      sub.deleted or (fChild<>nil) or not IsSelectable(item) then exit;
   end;
   sub.AttachTo(parent); // an open panel is attached to the UI root
   sub.order:=order+1;
   sub.Measure;
   PlaceSubmenu(sub,item);
   sub.fCurrent:=nil;
   sub.CancelSwitch;
   sub.flags.visible:=true;
   sub.fOpen:=true;
   fChild:=sub;
   if keyboard then sub.MoveCurrent(1);
  end;

 // To the right of this panel, to the left if there is no room (a deeper level tries the
 // side of its parent first); the first line at the owner line; clamped to the UI root
 procedure TUIPopupMenu.PlaceSubmenu(sub:TUIPopupMenu;item:TUIMenuItem);
  var
   root:TUIElement;
   r,pr:TRect2;
   x,y,w,cw,ch:single;
   left,leftFits,rightFits,moreLeft:boolean;
  begin
   root:=parent;
   r:=item.TransformTo(item.GetRect,root);
   pr:=TransformTo(GetRect,root);
   w:=sub.size.x;
   cw:=root.clientWidth;
   ch:=root.clientHeight;
   rightFits:=pr.x2+w<=cw;
   leftFits:=pr.x1-w>=0;
   moreLeft:=pr.x1>cw-pr.x2;
   if openLeft then left:=leftFits or (not rightFits and moreLeft)
    else left:=not rightFits and (leftFits or moreLeft);
   if left then x:=pr.x1-w else x:=pr.x2;
   y:=r.y1-sub.padding.Top;
   sub.pivot:=Vec2(0,0);
   sub.position:=Vec2(Clamp(x,0,Max(0,cw-w)),Clamp(y,0,Max(0,ch-sub.size.y)));
   sub.openLeft:=left;
  end;

 // Close the open submenu with its own submenus. reattach=false - from Unlink: the
 // panels are hidden in place, no tree changes
 procedure TUIPopupMenu.CloseChild(reattach:boolean);
  var
   c:TUIPopupMenu;
  begin
   c:=fChild;
   if c=nil then exit;
   c.CloseChild(reattach);
   fChild:=nil;
   c.fOpen:=false;
   c.fCurrent:=nil;
   c.timer:=0;
   c.CancelSwitch;
   c.flags.visible:=false;
   if reattach and not c.deleted and (c.owner<>nil) and not c.owner.deleted then c.AttachTo(c.owner);
  end;

 // The pointer entered (over=true) or left a line of this panel.
 // Over a line: it becomes current; its submenu opens after the hover delay, a command
 // line closes the open submenu after the same delay; back on the line of the open
 // submenu - nothing changes. Over a disabled line: no current line, the open submenu
 // closes after the delay (an already scheduled close is not postponed).
 // Leaving a command line clears the current line; a submenu line stays current: on the
 // way to its submenu the pointer may cross the padding
 procedure TUIPopupMenu.LineHover(item:TUIMenuItem;over:boolean);
  begin
   if not fOpen then exit;
   if not over then begin
    if (fCurrent=item) and (item.fSubmenu=nil) then fCurrent:=nil;
    exit;
   end;
   PointerInside;
   if not IsSelectable(item) then begin
    fCurrent:=nil;
    if fChild=nil then CancelSwitch
    else
    if not CloseScheduled then DelaySwitch(nil);
    exit;
   end;
   if fCurrent=item then exit;
   fCurrent:=item;
   if (item.fSubmenu<>nil) and (fChild=item.fSubmenu) then CancelSwitch
   else
   if (item.fSubmenu<>nil) or (fChild<>nil) then DelaySwitch(item)
   else
    CancelSwitch;
  end;

 // item=nil - close the open submenu
 procedure TUIPopupMenu.DelaySwitch(item:TUIMenuItem);
  begin
   switchPending:=true;
   switchTo:=item;
   switchAt:=CoreTime.Ticks+SUBMENU_DELAY;
   if (timer=0) or (timer>SUBMENU_DELAY) then timer:=SUBMENU_DELAY;
  end;

 procedure TUIPopupMenu.CancelSwitch;
  begin
   switchPending:=false;
   switchTo:=nil;
  end;

 function TUIPopupMenu.CloseScheduled:boolean;
  begin
   result:=switchPending and (switchTo=nil);
  end;

 // The hover delay is over: a line must still be current to open its submenu
 procedure TUIPopupMenu.ApplySwitch;
  var
   item:TUIMenuItem;
  begin
   item:=switchTo;
   CancelSwitch;
   if not fOpen then exit;
   if item=nil then begin
    CloseChild;
    exit;
   end;
   if item.deleted or (item.parent<>self) or (item<>fCurrent) then exit;
   if item.fSubmenu<>nil then OpenChild(item,false)
    else CloseChild;
  end;

 // The pointer is in this panel: a switch pending in the parent panels is cancelled, their
 // lines that lead here stay current
 procedure TUIPopupMenu.PointerInside;
  var
   m,p:TUIPopupMenu;
  begin
   m:=self;
   while m.IsChainChild do begin
    p:=m.ParentMenu;
    p.CancelSwitch;
    p.fCurrent:=TUIMenuItem(m.owner);
    m:=p;
   end;
  end;

 // The zone: the open panels and the anchor, plus the margin. True if the menu has closed
 function TUIPopupMenu.AutoClosed(now:int64):boolean;
  var
   wnd:TWindow;
   root:TUIElement;
   margin:single;
   pt:TVec2;
   inside:boolean;
   m:TUIPopupMenu;
   function InZone(e:TUIElement):boolean;
    var
     r:TRect2;
    begin
     r:=e.TransformTo(e.GetRect,root);
     result:=(pt.x>=r.x1-margin) and (pt.x<=r.x2+margin) and
       (pt.y>=r.y1-margin) and (pt.y<=r.y2+margin);
    end;
  begin
   result:=false;
   if autoCloseDelay<=0 then exit;
   margin:=autoCloseDistance;
   if margin<0 then margin:=2*DefaultLineHeight;
   if margin=0 then exit;
   wnd:=GetWindow;
   root:=parent;
   if (wnd=nil) or (root=nil) then exit;
   if not pointerArmed then begin // opened from the keyboard: wait for the pointer to move
    if (wnd.mousePos.x=armPos.x) and (wnd.mousePos.y=armPos.y) then exit;
    pointerArmed:=true;
   end;
   if wnd.mouseButtons<>0 then begin // a held button pauses the count
    outsideSince:=0;
    exit;
   end;
   // off the canvas mousePos is the far sentinel (OFF_CANVAS): out of any zone
   inside:=false;
   pt:=root.TransformFromScreen(Vec2(wnd.mousePos.x,wnd.mousePos.y));
   m:=self;
   while (m<>nil) and not inside do begin
    inside:=InZone(m);
    m:=m.fChild;
   end;
   if not inside and (anchor<>nil) and not anchor.deleted then inside:=InZone(anchor);
   if inside then begin
    outsideSince:=0;
    exit;
   end;
   if outsideSince=0 then outsideSince:=now
   else
   if now-outsideSince>=autoCloseDelay then begin
    Close;
    result:=true;
   end;
  end;

 procedure TUIPopupMenu.MoveCurrent(dir:integer);
  var
   i,n,start:integer;
  begin
   CancelSwitch;
   n:=length(children);
   if n=0 then exit;
   start:=-1;
   for i:=0 to n-1 do
    if children[i]=fCurrent then start:=i;
   if start<0 then // from no line: the first step lands on the first (last) line
    if dir>0 then start:=n-1 else start:=0;
   i:=start;
   repeat
    i:=(i+dir+n) mod n;
    if IsSelectable(children[i]) then begin
     fCurrent:=TUIMenuItem(children[i]);
     exit;
    end;
   until i=start;
  end;

 // The root menu holds the focus: the keys go to the deepest open panel
 // A key held after its command has run auto-repeats into whatever got the focus back:
 // a long hold is intentional, it is not filtered
 function TUIPopupMenu.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  var
   d,p:TUIPopupMenu;
  begin
   if not pressed or not fOpen then exit(true); // releases go on: the scene may track held keys
   if not IsVisible then begin // the menu's scene is gone: let the keys through
    DoClose(false);
    exit(true);
   end;
   result:=false; // while open the menu takes every key: the hotkeys keep silent
   d:=Deepest;
   if d.IsChainChild then p:=d.ParentMenu else p:=nil;
   case TKey(keycode) of
    TKey.Up:d.MoveCurrent(-1);
    TKey.Down:d.MoveCurrent(1);
    TKey.Home:begin
     d.fCurrent:=nil;
     d.MoveCurrent(1);
    end;
    TKey.EndKey:begin
     d.fCurrent:=nil;
     d.MoveCurrent(-1);
    end;
    TKey.Right:
     if (d.fCurrent<>nil) and (d.fCurrent.fSubmenu<>nil) then d.OpenChild(d.fCurrent,true);
    TKey.Left:
     if p<>nil then p.CloseChild;
    TKey.Enter,TKey.Space:
     if d.fCurrent<>nil then
      if d.fCurrent.fSubmenu<>nil then d.OpenChild(d.fCurrent,true)
       else d.fCurrent.DoClick;
    TKey.Escape:
     if p<>nil then p.CloseChild
      else Close;
   end;
  end;

 // The pointer over the padding of a submenu keeps the way to it
 procedure TUIPopupMenu.onMouseMove;
  begin
   inherited;
   if fOpen and (underMouse=self) then PointerInside;
  end;

 procedure TUIPopupMenu.onLostFocus;
  begin
   inherited;
   DoClose(false);
  end;

 procedure TUIPopupMenu.onRemoved;
  begin
   Unlink;
   inherited;
  end;

 procedure TUIPopupMenu.onTimer;
  var
   now,next,d:int64;
  begin
   if not fOpen then exit;
   now:=CoreTime.Ticks;
   if switchPending and (now>=switchAt) then ApplySwitch;
   if not fOpen then exit;
   next:=0;
   if not IsChainChild then begin
    // the UI root resized, the owner or the anchor removed - close
    if (parent=nil) or (parent.clientWidth<>rootSize.x) or (parent.clientHeight<>rootSize.y) or
      (owner=nil) or owner.deleted or ((anchor<>nil) and anchor.deleted) then begin
     Close;
     exit;
    end;
    if AutoClosed(now) then exit;
    next:=CHECK_INTERVAL;
   end;
   if switchPending then begin
    d:=switchAt-now;
    if d<1 then d:=1;
    if (next=0) or (d<next) then next:=d;
   end;
   timer:=integer(next);
  end;

end.
