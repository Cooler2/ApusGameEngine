// -----------------------------------------------------
// Popup menu: a panel of command lines opened below an owner element or at a point
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------

unit Apus.Engine.UIMenu;
interface
 uses Apus.Core, Apus.Lib, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIWidgets;

 type
  TUIPopupMenu=class;

  // Menu line: a button that draws its caption on the left and the shortcut text on the right.
  // Not focusable: the menu keeps the focus and tracks the current line.
  // A disabled line stays visible but never becomes current.
  TUIMenuItem=class(TUIButton)
   shortcut:String8;      // display only (the key itself is registered elsewhere)
   handler:TObjProcedure; // called after the menu is closed
   constructor Create(menu:TUIPopupMenu;const caption,shortcut,name:String8);
   function Menu:TUIPopupMenu;
   function IsHovered:boolean; override; // highlighted = the current line of the menu
   procedure onMouseMove; override;      // the mouse picks the current line
   function ShortcutFontSize:single;     // 'shortcut-font-size', smaller than the caption by default
   function ShortcutFont:TFontHandle;
  protected
   procedure DoClick; override;          // close the menu, then call the handler
  end;

  // A thin line between groups of menu lines
  TUIMenuSeparator=class(TUIElement)
   constructor Create(menu:TUIPopupMenu);
  end;

  // Popup menu: a panel that builds its lines and keeps the keyboard focus while open.
  // Created once, lives hidden in its parent; while open it is attached to the UI root.
  // A press outside the menu closes it and goes on to its target. The focus returns to
  // where it was before the menu opened.
  TUIPopupMenu=class(TUIElement)
   onOpen:TObjProcedure; // update the lines (enabled, visible, captions) before showing
   lineHeight:single;    // height of a line, 0 - by the font size
   constructor Create(parent:TUIElement;name:String8='');
   destructor Destroy; override;
   // A line; name '' - '<menu name>\<caption without "&" and "...">'
   function Add(const caption:String8;handler:TObjProcedure;const shortcut:String8='';
     const name:String8=''):TUIMenuItem;
   function AddSeparator:TUIMenuSeparator;
   procedure Clear;
   // Open with the top-left corner at (x,y) of root (nil - the root of the menu's parent)
   procedure OpenAt(x,y:single;root:TUIElement=nil);
   // Open below the anchor (above it if there is no room). The anchor owns the menu: its
   // press closes the open menu, and the click that follows doesn't open it again
   procedure OpenBelow(anchor:TUIElement);
   procedure Close;
   function IsOpen:boolean;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onLostFocus; override; // the focus is taken away - close, the taker keeps it
   procedure onTimer; override;     // safety net: the UI root is resized - close
  private
   fCurrent:TUIMenuItem;
   fOpen:boolean;
   owner:TUIElement;     // the parent to return to when closed
   anchor:TUIElement;    // the element the menu was opened from, or nil
   prevFocus:TUIElement; // the focus to restore (held by Acquire)
   rootSize:TVec2;       // the size of the root when opened
   procedure SetCurrent(item:TUIMenuItem);
   procedure Open(root,anchor:TUIElement;x,y,upY:single);
   procedure DoClose(restoreFocus:boolean);
   procedure Measure;
   procedure MoveCurrent(dir:integer);
  public
   property current:TUIMenuItem read fCurrent write SetCurrent; // an enabled line or nil
  end;

implementation
 uses Apus.EventMan, Apus.Geom2D, Apus.Engine.Window, Apus.Engine.UIShapes;

 const
  SEPARATOR_HEIGHT=9;
  LINE_HEIGHT=2.6;     // default line height, in font sizes
  SHORTCUT_GAP=3;      // min space between the captions and the shortcuts, in font sizes
  SHORTCUT_SCALE=0.85; // default shortcut font size relative to the caption font
  CHECK_INTERVAL=200;  // ms between the safety checks of an open menu

 var
  openMenu:TUIPopupMenu;  // one popup menu is open at a time
  reopenGuard:TUIElement; // the anchor whose press closed its menu: its click must not reopen it
  handlerSet:boolean;

 // Window thread, before the press reaches the UI (TWindow.DeliverMouseButton): a press
 // outside the open menu closes it and restores the focus, then goes on to its target
 procedure MouseDownHandler(event:TEventStr;tag:TTag);
  var
   e:TUIElement;
  begin
   reopenGuard:=nil;
   if openMenu=nil then exit;
   e:=underMouse;
   if (e<>nil) and ((e=openMenu) or e.HasParent(openMenu)) then exit; // a press inside the menu
   if (e<>nil) and (openMenu.anchor<>nil) and
      ((e=openMenu.anchor) or e.HasParent(openMenu.anchor)) then reopenGuard:=openMenu.anchor;
   openMenu.Close;
  end;

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
  begin
   if menu.name='' then exit('');
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
   result:=menu.name+'\'+result;
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

 function TUIMenuItem.ShortcutFontSize:single;
  begin
   result:=GetStyleNumber('shortcut-font-size',GetStyleNumber('font-size',9)*SHORTCUT_SCALE);
  end;

 function TUIMenuItem.ShortcutFont:TFontHandle;
  begin
   if txt=nil then exit(0);
   result:=txt.GetFont(GetStyleValue('font','Default'),round(ShortcutFontSize*globalScale),fsIgnoreScale);
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
   if (m=nil) or not m.fOpen then exit;
   if underMouse=self then begin
    if IsSelectable(self) then m.fCurrent:=self
     else m.fCurrent:=nil;
   end else
    if m.fCurrent=self then m.fCurrent:=nil;
  end;

 procedure TUIMenuItem.DoClick;
  var
   m:TUIPopupMenu;
   h:TObjProcedure;
  begin
   m:=Menu;
   h:=handler;
   if m<>nil then m.Close; // first: a command that opens a dialog sets its focus after the restore
   inherited;
   if Assigned(h) then h;
  end;

{ TUIMenuSeparator }

 constructor TUIMenuSeparator.Create(menu:TUIPopupMenu);
  begin
   inherited Create(10,SEPARATOR_HEIGHT,menu,'');
  end;

{ TUIPopupMenu }

 constructor TUIPopupMenu.Create(parent:TUIElement;name:String8);
  begin
   inherited Create(100,10,parent,name);
   owner:=parent;
   shape:=shapeFull; // a press on the padding stays inside the menu
   flags.visible:=false;
   flags.noParentClip:=true;
   order:=$10000; // above the siblings, out of the layout
   SetPaddings(4,4,4,4);
   if not handlerSet then begin
    handlerSet:=true;
    SetEventHandler('MOUSE\BTNDOWN',MouseDownHandler,emInstant);
   end;
  end;

 destructor TUIPopupMenu.Destroy;
  begin
   if openMenu=self then openMenu:=nil; // the window thread frees elements
   if prevFocus<>nil then prevFocus.Release;
   inherited;
  end;

 function TUIPopupMenu.Add(const caption:String8;handler:TObjProcedure;const shortcut:String8;
   const name:String8):TUIMenuItem;
  var
   n:String8;
  begin
   n:=name;
   if n='' then n:=DefaultItemName(self,caption);
   result:=TUIMenuItem.Create(self,caption,shortcut,n);
   result.handler:=handler;
  end;

 function TUIPopupMenu.AddSeparator:TUIMenuSeparator;
  begin
   result:=TUIMenuSeparator.Create(self);
  end;

 procedure TUIPopupMenu.Clear;
  begin
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

 // Lines get the width of the widest one; called after the attach to the root:
 // the inherited font and scale depend on the parent
 procedure TUIPopupMenu.Measure;
  var
   c:TUIElement;
   item:TUIMenuItem;
   capW,cutW,padR,w,h,y,fontSize:single;
   hasCuts:boolean;
  begin
   capW:=0; cutW:=0; padR:=0;
   hasCuts:=false;
   for c in children do
    if (c is TUIMenuItem) and c.flags.visible then begin
     item:=TUIMenuItem(c);
     capW:=Max(capW,item.padding.Left+TextWidth(item,false));
     if item.shortcut<>'' then begin
      hasCuts:=true;
      cutW:=Max(cutW,TextWidth(item,true));
     end;
     padR:=Max(padR,item.padding.Right);
    end;
   w:=capW+cutW+padR;
   if hasCuts then begin
    fontSize:=GetStyleNumber('font-size',9);
    w:=w+fontSize*SHORTCUT_GAP;
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

 // (x,y) - the top-left corner in root; upY - the bottom edge if there is no room below
 procedure TUIPopupMenu.Open(root,anchor:TUIElement;x,y,upY:single);
  var
   wnd:TWindow;
   f:TUIElement;
  begin
   if fOpen then DoClose(true);
   if openMenu<>nil then openMenu.Close; // one popup menu at a time
   if Assigned(onOpen) then onOpen;
   AttachTo(root);
   Measure;
   if y+size.y>root.clientHeight then y:=upY-size.y;
   x:=Clamp(x,0,Max(0,root.clientWidth-size.x));
   y:=Clamp(y,0,Max(0,root.clientHeight-size.y));
   pivot:=Vec2(0,0);
   position:=Vec2(x,y);
   rootSize:=Vec2(root.clientWidth,root.clientHeight);
   fCurrent:=nil;
   self.anchor:=anchor;
   flags.visible:=true;
   fOpen:=true;
   openMenu:=self;
   timer:=CHECK_INTERVAL;
   // keep the focus while open, give it back on close
   wnd:=root.GetWindow;
   if wnd=nil then exit;
   f:=TUIElement(wnd.focus.element);
   if (f<>nil) and (f<>self) and f.Acquire then prevFocus:=f;
   SetFocus;
  end;

 procedure TUIPopupMenu.OpenAt(x,y:single;root:TUIElement);
  begin
   if root=nil then root:=owner.GetRoot;
   Open(root,nil,x,y,y);
  end;

 procedure TUIPopupMenu.OpenBelow(anchor:TUIElement);
  var
   root:TUIElement;
   r:TRect2;
  begin
   if reopenGuard=anchor then begin // the click of the press that has just closed this menu
    reopenGuard:=nil;
    exit;
   end;
   root:=anchor.GetRoot;
   r:=anchor.TransformTo(anchor.GetRect,root);
   Open(root,anchor,r.x1,r.y2,r.y1);
  end;

 procedure TUIPopupMenu.Close;
  begin
   DoClose(true);
  end;

 procedure TUIPopupMenu.DoClose(restoreFocus:boolean);
  var
   wnd:TWindow;
   f:TUIElement;
  begin
   if not fOpen then exit;
   fOpen:=false; // first: the focus change below calls onLostFocus
   if openMenu=self then openMenu:=nil;
   timer:=0;
   fCurrent:=nil;
   anchor:=nil;
   flags.visible:=false;
   f:=prevFocus;
   prevFocus:=nil;
   wnd:=GetWindow;
   if restoreFocus and (wnd<>nil) and (wnd.focus.element=self) then begin
    // drop the focus first: SetFocus would record the hidden menu as the focused child
    // of its window, and a later focus of that window would land on it
    ClearFocus(wnd);
    if (f<>nil) and not f.deleted and f.IsVisible and f.IsEnabled then f.SetFocus;
   end;
   if f<>nil then f.Release;
   AttachTo(owner);
  end;

 procedure TUIPopupMenu.MoveCurrent(dir:integer);
  var
   i,n,start:integer;
  begin
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

 function TUIPopupMenu.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   if not pressed or not fOpen then exit(true); // releases go on: the scene may track held keys
   if not IsVisible then begin // the menu's scene is gone: let the keys through
    DoClose(false);
    exit(true);
   end;
   result:=false; // while open the menu takes every key: the hotkeys keep silent
   case TKey(keycode) of
    TKey.Up:MoveCurrent(-1);
    TKey.Down:MoveCurrent(1);
    TKey.Home:begin
     fCurrent:=nil;
     MoveCurrent(1);
    end;
    TKey.EndKey:begin
     fCurrent:=nil;
     MoveCurrent(-1);
    end;
    TKey.Enter,TKey.Space:
     if fCurrent<>nil then fCurrent.DoClick;
    TKey.Escape:Close;
   end;
  end;

 procedure TUIPopupMenu.onLostFocus;
  begin
   inherited;
   DoClose(false);
  end;

 procedure TUIPopupMenu.onTimer;
  begin
   if not fOpen then exit;
   if (parent=nil) or (parent.clientWidth<>rootSize.x) or (parent.clientHeight<>rootSize.y) then begin
    Close;
    exit;
   end;
   timer:=CHECK_INTERVAL;
  end;

end.
