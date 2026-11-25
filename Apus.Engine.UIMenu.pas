// -----------------------------------------------------
// Popup menu: a panel of command lines opened below an anchor element or at a point;
// a line may open a submenu. Menu bar: a row of headings, each opens its menu
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
// ------------------------------------------------------

unit Apus.Engine.UIMenu;
interface
 uses Apus.Core, Apus.Lib, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIWidgets, Apus.Engine.Actions;

 // Terms used below:
 //   owner     - the element a menu belongs to: its parent at creation (for a submenu - its
 //               line). A closed menu lives hidden in its owner and returns there on close
 //   anchor    - the element a menu was opened from (OpenBelow); optional
 //   UI root   - the root element the open panels are attached to while shown
 //   root menu - the first panel of an open chain: the menu the application opened
 //               or a menu of a menu bar
 // Mnemonics: '&' in a caption marks the next character ('&&' - the sign itself): '&File',
 // 'Save &As'. In an open menu the character selects the line: one match opens its submenu or
 // runs it, several matches take turns as the current line (Enter runs it). The marks are
 // underlined while the menu is used from the keyboard; the bar headings - also while Alt is held.

 // The caption to draw: MenuCaptionText in Apus.Engine.Actions
 // The marked character in lower case, '' - none
 function MenuMnemonic(const caption:String8):String8;
 // A text shown as is (a file name, a title from the data): each '&' doubled
 function MenuEscapeCaption(const text:String8):String8;

 type
  TUIPopupMenu=class;
  TUIMenuBar=class;

  // Menu line: a button that draws its caption on the left and the shortcut text on the right.
  // Not focusable: the root menu keeps the focus and tracks the current line.
  // A disabled line stays visible but never becomes current.
  // The command is any of the button handlers - onClick, onClickMethod, onClickAsync,
  // onClickEvent; all run after the menu is closed: Add('Save','Ctrl+S').onClickMethod:=Save
  // A submenu line (TUIPopupMenu.AddSubmenu) has no command: it opens its submenu.
  // A line of an action (Add(action)) shows its caption, shortcut, enabled and checked state
  // and runs it (TUIAction.Execute).
  TUIMenuItem=class(TUIButton)
   shortcut:String8;      // display only (the key itself is registered elsewhere)
   mark:TActionMark;      // the mark column: a check or a radio dot while checked
   checked:boolean;
   constructor Create(menu:TUIPopupMenu;const caption,shortcut,name:String8);
   destructor Destroy; override;
   procedure onRemoved; override;
   function Menu:TUIPopupMenu;
   function IsHovered:boolean; override; // highlighted = the current line of the menu
   procedure onMouseMove; override;      // reports the pointer to the menu (TUIPopupMenu.LineHover)
   function ShortcutFontSize:single;     // 'shortcut-font-size', smaller than the caption by default
   function ShortcutFont:TFontHandle;
   function ArrowWidth:single;           // the submenu arrow column of the menu, 0 - none
   function MarkWidth:single;            // the mark column of the menu (left), 0 - none
   function ShowsMnemonic:boolean;       // underline the mnemonic: the menu is used from the keyboard
   function GetStates:TElementStates; override; // + checked
   procedure ActionChanged; override;    // caption, shortcut, enabled, mark, checked
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
  // Mnemonics (see above): the typed character, or Alt+letter for a Latin letter or a digit.
  // A menu of a menu bar takes no focus (the bar holds it) and opens only from the bar.
  TUIPopupMenu=class(TUIPopup)
   // Called before each panel is shown, a submenu included: may update the lines (enabled,
   // visible, captions) or rebuild them with Clear and Add
   onOpen:TObjProcedure;
   lineHeight:single;       // height of a line, 0 - by the font size
   autoCloseDistance:single; // margin around the menu in UI units: <0 - two line heights, 0 - no auto close
   autoCloseDelay:integer;  // ms, 0 - no auto close; both are read from the root menu
   constructor Create(owner:TUIElement;name:String8='');
   destructor Destroy; override;
   function ContainsElement(element:TUIElement):boolean; override; // + the open submenus, the menu bar
   function AllowsHint(element:TUIElement):boolean; override; // + the open submenus
  protected
   procedure DismissPopup; override;
  public
   // A line without a command (set one on the result); name '' - '<prefix>\<caption>'
   // with "&" and a trailing "..." removed, other signs -> '_'; the prefix is the name of
   // the submenu line (ownerItem) or of a standalone menu
   function Add(const caption:String8;const shortcut:String8='';const name:String8=''):TUIMenuItem; overload;
   // A line of an action: follows its state, a click runs it. Before a panel is shown, the
   // scenes of its actions refresh their state (TGameScene.UpdateActions)
   function Add(action:TUIAction;const name:String8=''):TUIMenuItem; overload;
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
   procedure onUniChar(ch:Char32;scancode:byte); override; // mnemonics
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
   markW:single;         // width of the mark column, 0 - no line with a mark
   // Submenu switch after the hover delay: open switchTo's submenu, or close the open
   // submenu (switchTo=nil or a command line)
   switchPending:boolean;
   switchTo:TUIMenuItem;
   switchAt:int64;
   pointerArmed:boolean; // the pointer has moved since the menu opened
   armPos:TPoint;
   outsideSince:int64;   // the pointer has been out of the zone since then, 0 - inside
   cues:boolean;         // the root menu was used from the keyboard: underline the mnemonics
   procedure SetCurrent(item:TUIMenuItem);
   function GetOwnerItem:TUIButton;
   function MenuBar:TUIMenuBar; // the bar of its heading, nil - not a menu of a bar
   function ParentMenu:TUIPopupMenu;
   function IsChainChild:boolean;
   function ChainRoot:TUIPopupMenu;
   function Deepest:TUIPopupMenu;
   function DefaultLineHeight:single;
   procedure Open(root,anchor:TUIElement;x,y,upY:single;keyboard:boolean=false);
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
   procedure UpdateActions;
   procedure MoveCurrent(dir:integer);
   function SelectMnemonic(const ch:String8):boolean;
   function KeyboardCues:boolean;
  public
   property current:TUIMenuItem read fCurrent write SetCurrent; // an enabled line or nil
   property ownerItem:TUIButton read GetOwnerItem; // the submenu line or the bar heading, nil for a standalone menu
  end;

  // Heading of a menu bar (TUIMenuBar.AddSubmenu): opens its menu, has no command.
  // Never takes the focus; drawn selected while its menu is open
  TUIMenuHeading=class(TUIToolButton)
   constructor Create(bar:TUIMenuBar;const caption,name:String8);
   destructor Destroy; override;
   procedure onRemoved; override;
   function Bar:TUIMenuBar;
   function ShowsMnemonic:boolean;       // underline the mnemonic: the bar is used from the keyboard or Alt is held
   function GetStates:TElementStates; override; // + selected: the current heading of a session
   procedure onMouseMove; override;      // over another heading of an open bar: switch to it
  protected
   procedure DoClick; override;          // open its menu, close the open one
  private
   fBar:TUIMenuBar;
   fPopup:TUIPopupMenu;
   procedure Unlink;
  public
   property popup:TUIPopupMenu read fPopup;
  end;

  // Menu bar: headings in a row, each opens its menu below itself. The application sets the
  // position and the size of the bar; the headings take the width of their captions and the
  // height of the bar. Headings that don't fit are scrolled: the wheel, and opening a heading
  // scrolls it into view (its left part if it is wider than the bar).
  // A menu opens at its heading, but its anchor is the whole bar: a press anywhere on the bar
  // is not outside the menu (the bar decides: switch or close), and the auto close zone
  // includes the whole bar.
  // Session: from the first open to the close the bar holds the focus and passes the keys to
  // the open menus; switching the menus (hover over another heading, Left/Right at the top
  // level, Right on a command) keeps the session. It ends with Escape at the top level, a
  // command, a press outside the menus, auto close (the zone includes the whole bar) or a
  // click on the open heading; the focus returns to where it was.
  // Keyboard (keyboardActivation, one bar per scene root, allowed by the modal element):
  //   F10 or a single Alt (pressed and released alone; not AltGr, not Alt+click) - a session
  //     with the first heading selected and no menu open; again - the session ends;
  //   there: Left/Right/Home/End - select a heading, Down/Enter/Space - open its menu at the
  //     first line, Up - at the last one, a mnemonic character - its heading, Escape - end;
  //   Alt+letter - the heading with this mnemonic (Latin letters and digits: the key itself
  //     gives no character with Alt; any mnemonic works once the session is on).
  TUIMenuBar=class(TUIElement)
   autoCloseDistance:single; // passed to the menus when opened, see TUIPopupMenu
   autoCloseDelay:integer;
   keyboardActivation:boolean; // F10, a single Alt and Alt+letter; default: on desktop systems
   constructor Create(parent:TUIElement;name:String8='');
   destructor Destroy; override;
   // A heading and its hidden menu; returns the menu to fill. The heading gets the name
   // (default as in TUIPopupMenu.Add, with the bar name as the prefix), the menu - '<name>_Menu'
   function AddSubmenu(const caption:String8;const name:String8=''):TUIPopupMenu;
   procedure Clear;        // end the session, remove the headings
   // Open the menu of the heading: starts the session or switches it to this heading;
   // keyboard - with the first line current
   procedure OpenItem(item:TUIMenuHeading;keyboard:boolean=false);
   procedure Close;        // end the session, restore the focus
   procedure Activate;     // a keyboard session: the first heading selected, no menu open (F10)
   function IsOpen:boolean; // a menu of the bar is open
   procedure Arrange;      // place the headings in a row (also before each draw)
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onUniChar(ch:Char32;scancode:byte); override; // mnemonics
   procedure onMouseButtons(button:byte;state:boolean); override; // a press between the headings ends the session
   procedure onMouseScroll(value:integer); override;
   procedure onLostFocus; override; // the focus is taken away - end the session, the taker keeps it
   procedure onRemoved; override;
   procedure onTimer; override;
  private
   fCurrent:TUIMenuHeading;
   fMenu:TUIPopupMenu;     // the open menu or the one being opened: the root of the open chain
   session:boolean;        // the bar holds the focus
   request:cardinal;       // counts the open requests: a newer one replaces the running one
   switching:boolean;      // one menu closes for another: the session goes on
   previousFocus:TUIElement;
   contentWidth:single;    // of the headings row
   cues:boolean;           // the session is used from the keyboard: underline the mnemonics
   procedure SetCurrent(item:TUIMenuHeading);
   function BeginSession:boolean;
   procedure Toggle;
   procedure SelectHeading(item:TUIMenuHeading);
   function HeadingMnemonic(const ch:String8):boolean;
   function Expects(menu:TUIPopupMenu):boolean;
   procedure MenuClosed(menu:TUIPopupMenu;restoreFocus:boolean);
   procedure EndSession(restoreFocus:boolean);
   procedure MoveHeading(dir:integer);
   procedure ScrollIntoView(item:TUIMenuHeading);
   procedure Unlink;
  public
   property current:TUIMenuHeading read fCurrent write SetCurrent; // the selected (open) heading; set - open it, nil - end the session
  end;

implementation
 uses Apus.Geom2D, Apus.Strings, Apus.Threads, Apus.EventMan, Apus.Engine.Window, Apus.Engine.UIShapes;

 const
  SEPARATOR_HEIGHT=9;
  LINE_HEIGHT=2.6;     // default line height, in font sizes
  SHORTCUT_GAP=3;      // min space between the captions and the shortcuts, in font sizes
  SHORTCUT_SCALE=0.85; // default shortcut font size relative to the caption font
  MARK_COLUMN=2.0;     // the mark column before the captions, in font sizes
  ARROW_COLUMN=0.8;    // extra width for the submenu arrows, in font sizes (the arrow sits in the right padding)
  SUBMENU_OVERLAP=4;   // a submenu covers the edge of its parent panel by this much
  SUBMENU_SHIFT=2;     // and is lower than the owner line by this much
  CHECK_INTERVAL=100;  // ms between the checks of an open menu (auto close, safety)
  SUBMENU_DELAY=200;   // ms of hover before a submenu opens or switches
  AUTO_CLOSE_DELAY=500;

 type
  // Places the headings of a menu bar before each draw
  TMenuBarLayout=class(TLayouter)
   procedure Layout(item:TUIElement); override;
  end;

 var
  // All live bars: the key preview and the mouse handler look up the bar of a window and root
  bars:array of TUIMenuBar;
  barLock:TLock; // a leaf lock
  // Keyboard activation state (one keyboard): the window where a single Alt is pressed (nil -
  // none or used in a combination); Alt and F10 are held (their auto-repeat changes nothing)
  altWnd:TWindow;
  altHeld,f10Held:boolean;
  // Counts the other key events of the platform (KBD\KEYDOWN/KEYUP, not Alt), the internal
  // engine hotkeys included (they don't reach the scenes); altSeq - its value at the Alt press
  keySeq,altSeq:cardinal;
  // The window where Alt is held (not with Ctrl or Win: AltGr): its bar shows the mnemonics
  altCueWnd:TWindow;

 function FindBar(wnd:TWindow;root:TUIElement):TUIMenuBar; forward;

 function MenuMnemonic(const caption:String8):String8;
  var
   text:String8;
   pos,len:integer;
  begin
   text:=MenuCaptionText(caption,pos,len);
   if len=0 then exit('');
   result:=UTF8.ToLower(copy(text,pos,len));
  end;

 function MenuEscapeCaption(const text:String8):String8;
  var
   i,n:integer;
  begin
   n:=length(text);
   for i:=1 to length(text) do
    if text[i]='&' then inc(n);
   if n=length(text) then exit(text);
   SetLength(result,n);
   n:=0;
   for i:=1 to length(text) do begin
    inc(n);
    result[n]:=text[i];
    if text[i]='&' then begin
     inc(n);
     result[n]:='&';
    end;
   end;
  end;

 function CharToUtf8(ch:Char32):String8;
  begin
   case ch of
    0..$7F:result:=AnsiChar(ch);
    $80..$7FF:result:=AnsiChar($C0 or (ch shr 6))+AnsiChar($80 or (ch and $3F));
    $800..$FFFF:result:=AnsiChar($E0 or (ch shr 12))+AnsiChar($80 or ((ch shr 6) and $3F))+
      AnsiChar($80 or (ch and $3F));
   else
    result:=AnsiChar($F0 or (ch shr 18))+AnsiChar($80 or ((ch shr 12) and $3F))+
      AnsiChar($80 or ((ch shr 6) and $3F))+AnsiChar($80 or (ch and $3F));
   end;
  end;

 // The mnemonic of Alt+key: a Latin letter or a digit (with Alt the key gives no character)
 function KeyMnemonic(keycode:integer;out ch:String8):boolean;
  begin
   result:=true;
   case keycode of
    ord('A')..ord('Z'):ch:=AnsiChar(keycode+32);
    ord('0')..ord('9'):ch:=AnsiChar(keycode);
   else
    result:=false;
   end;
  end;

 // Alt+key: Alt without Ctrl and Win (AltGr comes with Ctrl); Shift doesn't matter
 function AltCombination(shift:byte):boolean;
  begin
   result:=(shift and (sscCtrl or sscAlt or sscWin))=sscAlt;
  end;

 // A character typed with Alt held (without Ctrl: AltGr characters are text) is not a mnemonic:
 // Alt+letter acts by the key
 function TypedWithAlt(e:TUIElement):boolean;
  var
   wnd:TWindow;
  begin
   wnd:=e.GetWindow;
   result:=(wnd<>nil) and (wnd.shiftState and (sscAlt or sscCtrl)=sscAlt);
  end;

 function IsSelectable(e:TUIElement):boolean;
  begin
   result:=(e is TUIMenuItem) and e.flags.visible and e.flags.enabled;
  end;

 function IsHeadingSelectable(e:TUIElement):boolean;
  begin
   result:=(e is TUIMenuHeading) and not e.deleted and e.flags.visible and e.flags.enabled and
     (TUIMenuHeading(e).fPopup<>nil) and not TUIMenuHeading(e).fPopup.deleted;
  end;

 // Width of a text of the element in its units: measured with the font, or estimated by the
 // font size without a text drawer (headless; the font is not used then and may be 0)
 function MeasureText(e:TUIElement;const text:String8;font:TFontHandle;size:single):single;
  begin
   if text='' then exit(0);
   if txt=nil then exit(length(text)*size*0.6);
   result:=txt.Width(font,text)/e.globalScale;
  end;

 // Width of the caption or the shortcut in the units of the line
 function TextWidth(item:TUIMenuItem;shortcut:boolean):single;
  var
   font:TFontHandle;
  begin
   font:=0;
   if shortcut then begin
    if txt<>nil then font:=item.ShortcutFont;
    result:=MeasureText(item,item.shortcut,font,item.ShortcutFontSize);
   end else begin
    if txt<>nil then font:=item.StyleFont;
    result:=MeasureText(item,MenuCaptionText(item.caption),font,item.GetStyleNumber('font-size',9));
   end;
  end;

 // The name must be a valid identifier (elements are published by name): spaces and other
 // ASCII signs become '_', non-ASCII letters are dropped, an empty result becomes 'ItemN'
 // (index - the position of the new element)
 function DefaultItemName(const prefix,caption:String8;index:integer):String8;
  var
   i,n,last:integer;
  begin
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
   if result='' then result:='Item'+Conv.ToStr(index);
   result:=prefix+'\'+result;
  end;

 // Lines are named after the submenu line or the bar heading, else after the menu
 function MenuItemName(menu:TUIPopupMenu;const caption:String8):String8;
  begin
   if menu.ownerItem<>nil then result:=DefaultItemName(menu.ownerItem.name,caption,length(menu.children)+1)
    else result:=DefaultItemName(menu.name,caption,length(menu.children)+1);
  end;

 procedure TMenuBarLayout.Layout(item:TUIElement);
  begin
   if item is TUIMenuBar then TUIMenuBar(item).Arrange;
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

 function TUIMenuItem.MarkWidth:single;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   if m<>nil then result:=m.markW
    else result:=0;
  end;

 function TUIMenuItem.GetStates:TElementStates;
  begin
   result:=inherited;
   if checked then include(result,TElementState.Checked);
  end;

 procedure TUIMenuItem.ActionChanged;
  var
   a:TUIAction;
   m:TUIPopupMenu;
   cut:String8;
   relayout:boolean;
  begin
   a:=action;
   if a=nil then exit;
   cut:=a.ShortcutText;
   relayout:=(caption<>a.caption) or (shortcut<>cut) or (mark<>a.mark);
   caption:=a.caption;
   shortcut:=cut;
   mark:=a.mark;
   checked:=a.checked;
   flags.enabled:=a.enabled;
   m:=Menu;
   if relayout and (m<>nil) and m.fOpen then m.Measure;
  end;

 function TUIMenuItem.ShowsMnemonic:boolean;
  var
   m:TUIPopupMenu;
  begin
   m:=Menu;
   result:=(m<>nil) and m.KeyboardCues;
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

 // A press on the bar of the open menu is not outside: the bar decides (switch or close);
 // the focus at the bar is the menu's own
 function TUIPopupMenu.ContainsElement(element:TUIElement):boolean;
  var
   bar:TUIMenuBar;
  begin
   result:=inherited ContainsElement(element) or
     ((fChild<>nil) and fChild.ContainsElement(element));
   if result or (element=nil) then exit;
   bar:=MenuBar;
   result:=(bar<>nil) and ((element=bar) or element.HasParent(bar));
  end;

 function TUIPopupMenu.AllowsHint(element:TUIElement):boolean;
  begin
   result:=inherited AllowsHint(element) or
     ((fChild<>nil) and fChild.AllowsHint(element));
  end;

 function TUIPopupMenu.Add(const caption,shortcut,name:String8):TUIMenuItem;
  var
   n:String8;
  begin
   n:=name;
   if n='' then n:=MenuItemName(self,caption);
   result:=TUIMenuItem.Create(self,caption,shortcut,n);
  end;

 function TUIPopupMenu.Add(action:TUIAction;const name:String8):TUIMenuItem;
  begin
   ASSERT(action<>nil);
   result:=Add(action.caption,action.ShortcutText,name);
   result.action:=action;
  end;

 // The lines of actions follow the app: each scene of them refreshes its actions once
 procedure TUIPopupMenu.UpdateActions;
  var
   c:TUIElement;
   a:TUIAction;
   last,m:TMethod;
  begin
   last.Code:=nil; last.Data:=nil;
   for c in children do
    if c is TUIMenuItem then begin
     a:=TUIMenuItem(c).action;
     if a=nil then continue;
     if Assigned(a.updater) then begin
      m:=TMethod(a.updater);
      if (m.Code<>last.Code) or (m.Data<>last.Data) then begin
       a.updater;
       last:=m;
      end;
     end;
     if Assigned(a.onUpdate) then a.onUpdate;
    end;
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
   if ((owner is TUIMenuItem) and (TUIMenuItem(owner).fSubmenu=self)) or
      ((owner is TUIMenuHeading) and (TUIMenuHeading(owner).fPopup=self)) then result:=TUIButton(owner)
    else result:=nil;
  end;

 function TUIPopupMenu.MenuBar:TUIMenuBar;
  begin
   if (owner is TUIMenuHeading) and (TUIMenuHeading(owner).fPopup=self) then result:=TUIMenuHeading(owner).fBar
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
   hasCuts,hasArrows,hasMarks:boolean;
  begin
   capW:=0; cutW:=0; padR:=0;
   hasCuts:=false; hasArrows:=false; hasMarks:=false;
   for c in children do
    if (c is TUIMenuItem) and c.flags.visible then begin
     item:=TUIMenuItem(c);
     if item.mark<>TActionMark.None then hasMarks:=true;
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
   markW:=0;
   if hasMarks then begin
    markW:=fontSize*MARK_COLUMN;
    w:=w+markW;
   end;
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
 // edge if there is no room below. A menu of a bar opens only when the bar asks for it
 procedure TUIPopupMenu.Open(root,anchor:TUIElement;x,y,upY:single;keyboard:boolean);
  var
   wnd:TWindow;
   bar:TUIMenuBar;
  begin
   if fOpen then DoClose(true);
   if deleted or (owner=nil) then exit; // the close may remove a menu whose owner is gone
   bar:=MenuBar;
   if (bar<>nil) and not bar.Expects(self) then exit;
   UpdateActions;
   if Assigned(onOpen) then onOpen;
   if deleted or (owner=nil) or owner.deleted or root.deleted then exit;
   bar:=MenuBar;
   if (bar<>nil) and not bar.Expects(self) then exit; // the callback changed the bar session
   if not RegisterPopup(root,anchor) then exit;
   if (bar<>nil) and not bar.Expects(self) then begin // closing another popup ended the session
    EndPopup(pfcLeave);
    exit;
   end;
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
   cues:=false;
   CancelSwitch;
   wnd:=root.GetWindow;
   pointerArmed:=false;
   outsideSince:=0;
   if wnd<>nil then armPos:=wnd.mousePos;
   flags.visible:=true;
   fOpen:=true;
   timer:=CHECK_INTERVAL;
   if bar=nil then begin // a bar keeps the focus itself
    SavePopupFocus(wnd);
    SetFocus;
   end;
   if keyboard then MoveCurrent(1);
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
  var
   bar:TUIMenuBar;
  begin
   if not fOpen then exit;
   if IsChainChild then begin
    ParentMenu.CloseChild;
    exit;
   end;
   bar:=MenuBar;
   CloseChild;
   fOpen:=false; // first: the focus change below calls onLostFocus
   timer:=0;
   fCurrent:=nil;
   CancelSwitch;
   flags.visible:=false;
   if restoreFocus and (bar=nil) then EndPopup(pfcRestore) // a bar restores the focus itself
    else EndPopup(pfcLeave);
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
   if bar<>nil then bar.MenuClosed(self,restoreFocus);
  end;

 // The menu drops its links to the other panels and to its owner: from onRemoved (no tree
 // changes there: the open panels are hidden in place, the submenu lines remove the panels
 // left at the UI root when destroyed) and from Destroy (a direct Free). The second call
 // is a no-op: the owner may already be freed then
 procedure TUIPopupMenu.Unlink;
  var
   bar:TUIMenuBar;
  begin
   CloseChild(false);
   if IsChainChild then ParentMenu.fChild:=nil;
   bar:=MenuBar;
   if (bar<>nil) and (bar.fMenu=self) then bar.fMenu:=nil; // the bar ends its session on the next check
   if (owner is TUIMenuItem) and (TUIMenuItem(owner).fSubmenu=self) then TUIMenuItem(owner).fSubmenu:=nil;
   if (owner is TUIMenuHeading) and (TUIMenuHeading(owner).fPopup=self) then TUIMenuHeading(owner).fPopup:=nil;
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
   sub.UpdateActions;
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
   TUIHint.Drop(GetWindow); // the hint of the line must not cover the submenu
   if keyboard then sub.MoveCurrent(1);
  end;

 // To the right of this panel, to the left if there is no room (a deeper level tries the
 // side of its parent first), over its edge a little; the first line a bit lower than the
 // owner line; clamped to the UI root
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
   rightFits:=pr.x2-SUBMENU_OVERLAP+w<=cw;
   leftFits:=pr.x1+SUBMENU_OVERLAP-w>=0;
   moreLeft:=pr.x1>cw-pr.x2;
   if openLeft then left:=leftFits or (not rightFits and moreLeft)
    else left:=not rightFits and (leftFits or moreLeft);
   if left then x:=pr.x1+SUBMENU_OVERLAP-w else x:=pr.x2-SUBMENU_OVERLAP;
   y:=r.y1-sub.padding.Top+SUBMENU_SHIFT;
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
   ch:String8;
  begin
   if not pressed or not fOpen then exit(true); // releases go on: the scene may track held keys
   if not IsVisible then begin // the menu's scene is gone: let the keys through
    DoClose(false);
    exit(true);
   end;
   result:=false; // while open the menu takes every key: the hotkeys keep silent
   cues:=true;
   d:=Deepest;
   if AltCombination(shiftstate) and KeyMnemonic(keycode,ch) then begin
    d.SelectMnemonic(ch);
    exit;
   end;
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

 // The focus holder gets the typed characters: a mnemonic of the deepest panel
 procedure TUIPopupMenu.onUniChar(ch:Char32;scancode:byte);
  begin
   if not fOpen or IsChainChild or (ch<32) or TypedWithAlt(self) then exit;
   cues:=true;
   Deepest.SelectMnemonic(CharToUtf8(ch));
  end;

 // The lines with this mnemonic (any case): one - open its submenu or run it (the chain
 // closes first); several - the next one after the current line becomes current. False - none
 function TUIPopupMenu.SelectMnemonic(const ch:String8):boolean;
  var
   i,start,count:integer;
   first,next:TUIMenuItem;
   c:String8;
  begin
   c:=UTF8.ToLower(ch);
   count:=0; first:=nil; next:=nil;
   start:=-1;
   for i:=0 to high(children) do
    if children[i]=fCurrent then start:=i;
   for i:=0 to high(children) do
    if IsSelectable(children[i]) and (MenuMnemonic(children[i].caption)=c) then begin
     inc(count);
     if first=nil then first:=TUIMenuItem(children[i]);
     if (next=nil) and (i>start) then next:=TUIMenuItem(children[i]);
    end;
   result:=count>0;
   if count=0 then exit;
   if count>1 then begin
    if next=nil then next:=first;
    CancelSwitch;
    if (fChild<>nil) and (fChild<>next.fSubmenu) then CloseChild;
    fCurrent:=next;
    exit;
   end;
   if first.fSubmenu<>nil then OpenChild(first,true)
    else first.DoClick;
  end;

 // Underline the mnemonics: the session of the root menu (or its bar) is used from the keyboard
 function TUIPopupMenu.KeyboardCues:boolean;
  var
   r:TUIPopupMenu;
   bar:TUIMenuBar;
  begin
   r:=ChainRoot;
   bar:=r.MenuBar;
   if bar<>nil then result:=bar.session and bar.cues
    else result:=r.fOpen and r.cues;
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

{ TUIMenuHeading }

 constructor TUIMenuHeading.Create(bar:TUIMenuBar;const caption,name:String8);
  begin
   inherited Create(10,10,bar,name);
   fBar:=bar;
   self.caption:=caption;
   SetPaddings(14,0,14,0);
  end;

 // An open menu lives at the UI root, out of the heading's subtree: it goes with the heading
 destructor TUIMenuHeading.Destroy;
  begin
   Unlink; // a direct Free skips onRemoved
   if (fPopup<>nil) and (fPopup.parent<>self) and not fPopup.deleted then fPopup.Remove;
   inherited;
  end;

 procedure TUIMenuHeading.onRemoved;
  begin
   Unlink;
   inherited;
  end;

 // The bar forgets the heading (no tree changes - this runs in onRemoved too). Its open
 // menu closes by its own check (the owner is gone), the bar ends the session by its own
 procedure TUIMenuHeading.Unlink;
  var
   b:TUIMenuBar;
  begin
   b:=fBar;
   if b=nil then exit;
   fBar:=nil;
   if b.fCurrent=self then b.fCurrent:=nil;
   if (fPopup<>nil) and (b.fMenu=fPopup) then b.fMenu:=nil;
  end;

 function TUIMenuHeading.Bar:TUIMenuBar;
  begin
   result:=fBar;
  end;

 // In a session used from the keyboard, or while Alt is held over a bar that takes it
 function TUIMenuHeading.ShowsMnemonic:boolean;
  var
   b:TUIMenuBar;
  begin
   b:=fBar;
   if b=nil then exit(false);
   if b.session then exit(b.cues);
   result:=(altCueWnd<>nil) and b.keyboardActivation and (altCueWnd=b.GetWindow) and
     (FindBar(altCueWnd,b.GetRoot)=b);
  end;

 function TUIMenuHeading.GetStates:TElementStates;
  begin
   result:=inherited;
   if (fBar<>nil) and fBar.session and (fBar.fCurrent=self) then include(result,TElementState.Selected);
  end;

 // Hover switches the open menus; a selected heading without a menu (F10) stays as it is
 procedure TUIMenuHeading.onMouseMove;
  var
   b:TUIMenuBar;
  begin
   inherited;
   b:=fBar;
   if (b<>nil) and b.IsOpen and (underMouse=self) and (b.fCurrent<>self) then b.OpenItem(self,false);
  end;

 procedure TUIMenuHeading.DoClick;
  var
   b:TUIMenuBar;
  begin
   b:=fBar;
   if b=nil then exit;
   if b.IsOpen and (b.fCurrent=self) then b.Close
    else b.OpenItem(self,false);
  end;

{ TUIMenuBar }

 constructor TUIMenuBar.Create(parent:TUIElement;name:String8);
  var
   w:single;
  begin
   if parent<>nil then w:=parent.clientWidth else w:=100;
   inherited Create(w,10,parent,name);
   size:=Vec2(w,round(GetStyleNumber('font-size',9)*LINE_HEIGHT));
   shape:=shapeFull; // a press between the headings is the bar's
   flags.canHaveFocus:=false; // the bar takes the focus only for a session
   layout:=TMenuBarLayout.Create;
   autoCloseDistance:=-1;
   autoCloseDelay:=AUTO_CLOSE_DELAY;
   keyboardActivation:={$IF Defined(ANDROID) or Defined(IOS)}false{$ELSE}true{$ENDIF};
   barLock.Enter;
   try
    SetLength(bars,length(bars)+1);
    bars[high(bars)]:=self;
   finally
    barLock.Leave;
   end;
  end;

 destructor TUIMenuBar.Destroy;
  begin
   Unlink; // a direct Free skips onRemoved; before inherited: it clears the focus (onLostFocus)
   layout.Free;
   layout:=nil;
   inherited;
  end;

 function TUIMenuBar.AddSubmenu(const caption,name:String8):TUIPopupMenu;
  var
   h:TUIMenuHeading;
   n:String8;
  begin
   n:=name;
   if n='' then n:=DefaultItemName(self.name,caption,length(children)+1);
   h:=TUIMenuHeading.Create(self,caption,n);
   n:=h.name;
   if n<>'' then n:=n+'_Menu';
   result:=TUIPopupMenu.Create(h,n);
   h.fPopup:=result;
   Arrange;
  end;

 procedure TUIMenuBar.Clear;
  begin
   EndSession(true);
   DeleteChildren;
   contentWidth:=0;
   scroll.X:=0;
  end;

 function TUIMenuBar.IsOpen:boolean;
  begin
   result:=session and (fMenu<>nil) and fMenu.fOpen;
  end;

 procedure TUIMenuBar.Close;
  begin
   EndSession(true);
  end;

 procedure TUIMenuBar.SetCurrent(item:TUIMenuHeading);
  begin
   if item=nil then Close
    else OpenItem(item,false);
  end;

 function TUIMenuBar.Expects(menu:TUIPopupMenu):boolean;
  begin
   result:=session and (fMenu=menu);
  end;

 procedure TUIMenuBar.Arrange;
  var
   c:TUIElement;
   h:TUIMenuHeading;
   x,w,ht:single;
   font:TFontHandle;
  begin
   x:=0;
   ht:=clientHeight;
   for c in children do begin
    if not (c is TUIMenuHeading) or c.deleted or not c.flags.visible then continue;
    h:=TUIMenuHeading(c);
    font:=0;
    if txt<>nil then font:=h.StyleFont;
    w:=round(h.padding.Left+h.padding.Right+
      MeasureText(h,MenuCaptionText(h.caption),font,h.GetStyleNumber('font-size',9)));
    h.pivot:=Vec2(0,0);
    h.position:=Vec2(x,0);
    h.size:=Vec2(w,ht);
    x:=x+w;
   end;
   contentWidth:=x;
   scroll.X:=Clamp(scroll.X,0,Max(0,contentWidth-clientWidth));
  end;

 // Scroll the heading into view; a heading wider than the bar shows its left part
 procedure TUIMenuBar.ScrollIntoView(item:TUIMenuHeading);
  var
   x1,x2:single;
  begin
   x1:=item.position.x;
   x2:=x1+item.size.x;
   if x2>scroll.X+clientWidth then scroll.X:=x2-clientWidth;
   if x1<scroll.X then scroll.X:=x1;
   scroll.X:=Clamp(scroll.X,0,Max(0,contentWidth-clientWidth));
  end;

 // The session starts: the bar remembers the focus and takes it (an open popup that holds
 // the focus closes). False - the focus can't be taken, no session
 function TUIMenuBar.BeginSession:boolean;
  var
   wnd:TWindow;
   focus:TUIElement;
  begin
   if session then exit(true);
   result:=false;
   if deleted or not IsVisible or not IsEnabled then exit;
   wnd:=GetWindow;
   if wnd=nil then exit;
   focus:=TUIElement(wnd.focus.element);
   if (focus<>nil) and (focus<>self) and focus.Acquire then previousFocus:=focus;
   session:=true;
   cues:=false;
   SetFocus;
   if not session or (TUIElement(wnd.focus.element)<>self) then begin
    EndSession(false);
    exit;
   end;
   timer:=CHECK_INTERVAL;
   result:=true;
  end;

 // Open the menu of the heading: starts the session or switches it to this heading. Another
 // open menu closes, the session goes on.
 // The menu callbacks (onOpen) may open another heading or close the bar: the bar decides
 // the outcome - the request replaced by a newer one is left to it; a request still current
 // that failed to open (the callback removed the menu, a popup refused) ends the session
 procedure TUIMenuBar.OpenItem(item:TUIMenuHeading;keyboard:boolean);
  var
   m:TUIPopupMenu;
   root:TUIElement;
   r:TRect2;
   my:cardinal;
  begin
   if not IsHeadingSelectable(item) or (item.fBar<>self) or deleted or not IsVisible or not IsEnabled then exit;
   m:=item.fPopup;
   if session and (fMenu=m) and m.fOpen then begin
    if keyboard and (m.fCurrent=nil) then m.MoveCurrent(1);
    exit;
   end;
   if not BeginSession then exit;
   if keyboard then cues:=true;
   if fMenu<>nil then begin
    switching:=true;
    try
     fMenu.DoClose(false);
    finally
     switching:=false;
    end;
    fMenu:=nil;
   end;
   inc(request);
   my:=request;
   SelectHeading(item);
   root:=GetRoot;
   r:=item.TransformTo(item.GetRect,root);
   m.autoCloseDistance:=autoCloseDistance;
   m.autoCloseDelay:=autoCloseDelay;
   fMenu:=m;
   // placed at the heading; the anchor is the whole bar (see the class comment). The menu
   // asks Expects before each step: it stops if the request is no longer current
   m.Open(root,self,r.x1,r.y2,r.y1,keyboard);
   if request<>my then exit; // replaced by another request (from onOpen): that one decides
   if session and not m.fOpen then begin
    fMenu:=nil;
    EndSession(true);
   end;
  end;

 // A keyboard session without an open menu: the first heading selected
 procedure TUIMenuBar.Activate;
  begin
   if not BeginSession then exit;
   cues:=true;
   if fMenu<>nil then begin // a menu is open: close it, its heading stays selected
    switching:=true;
    try
     fMenu.DoClose(false);
    finally
     switching:=false;
    end;
    fMenu:=nil;
    exit;
   end;
   fCurrent:=nil;
   MoveHeading(1);
   if fCurrent=nil then EndSession(true); // nothing to select
  end;

 // F10, a single Alt: start a keyboard session or end the running one
 procedure TUIMenuBar.Toggle;
  begin
   if session then EndSession(true)
    else Activate;
  end;

 procedure TUIMenuBar.SelectHeading(item:TUIMenuHeading);
  begin
   fCurrent:=item;
   Arrange;
   ScrollIntoView(item);
  end;

 // The headings with this mnemonic (any case): one - open its menu at the first line;
 // several - the next one after the current heading (its menu opens if a menu is open, the
 // heading is just selected otherwise). False - none
 function TUIMenuBar.HeadingMnemonic(const ch:String8):boolean;
  var
   i,start,count:integer;
   first,next:TUIMenuHeading;
   c:String8;
  begin
   c:=UTF8.ToLower(ch);
   count:=0; first:=nil; next:=nil;
   start:=-1;
   for i:=0 to high(children) do
    if children[i]=fCurrent then start:=i;
   for i:=0 to high(children) do
    if IsHeadingSelectable(children[i]) and (MenuMnemonic(children[i].caption)=c) then begin
     inc(count);
     if first=nil then first:=TUIMenuHeading(children[i]);
     if (next=nil) and (i>start) then next:=TUIMenuHeading(children[i]);
    end;
   result:=count>0;
   if count=0 then exit;
   if count=1 then begin
    OpenItem(first,true);
    exit;
   end;
   if next=nil then next:=first;
   if IsOpen then OpenItem(next,true)
   else if BeginSession then begin
    cues:=true;
    SelectHeading(next);
   end;
  end;

 // An open menu of the bar has closed: by itself (Escape, a command, a press outside, auto
 // close) - the session ends; for another menu - it goes on
 procedure TUIMenuBar.MenuClosed(menu:TUIPopupMenu;restoreFocus:boolean);
  begin
   if fMenu=menu then fMenu:=nil;
   if session and not switching and (fMenu=nil) then EndSession(restoreFocus);
  end;

 procedure TUIMenuBar.EndSession(restoreFocus:boolean);
  var
   m:TUIPopupMenu;
   focus:TUIElement;
   wnd:TWindow;
   was:boolean;
  begin
   was:=session;
   session:=false; // first: the menu close and the focus change below call back
   cues:=false;
   timer:=0;
   fCurrent:=nil;
   m:=fMenu;
   fMenu:=nil;
   if (m<>nil) and m.fOpen then m.DoClose(false);
   focus:=previousFocus;
   previousFocus:=nil;
   wnd:=GetWindow;
   try
    if was and (wnd<>nil) and (TUIElement(wnd.focus.element)=self) then begin
     ClearFocus(wnd);
     if restoreFocus and (focus<>nil) and not focus.deleted and focus.IsVisible and focus.IsEnabled then
      focus.SetFocus;
    end;
   finally
    if focus<>nil then focus.Release;
   end;
  end;

 // The neighbour enabled heading, round the row: with an open menu its menu opens at the
 // first line, without - it is just selected
 procedure TUIMenuBar.MoveHeading(dir:integer);
  var
   i,n,start:integer;
   h:TUIMenuHeading;
  begin
   n:=length(children);
   if n=0 then exit;
   start:=-1;
   for i:=0 to n-1 do
    if children[i]=fCurrent then start:=i;
   if start<0 then
    if dir>0 then start:=n-1 else start:=0;
   i:=start;
   repeat
    i:=(i+dir+n) mod n;
    if IsHeadingSelectable(children[i]) then begin
     h:=TUIMenuHeading(children[i]);
     if h<>fCurrent then
      if fMenu<>nil then OpenItem(h,true)
       else SelectHeading(h);
     exit;
    end;
   until i=start;
  end;

 // The bar holds the focus during a session. Without an open menu (F10) it moves the
 // selection and opens the menus; with one - Left at the top level and Right on a line
 // without a submenu move to the neighbour heading, other keys go to the open menus
 function TUIMenuBar.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  var
   d:TUIPopupMenu;
   h:TUIMenuHeading;
   ch:String8;
  begin
   if not pressed or not session then exit(true); // releases go on: the scene may track held keys
   if not IsVisible then begin // the bar's scene is gone: let the keys through
    EndSession(false);
    exit(true);
   end;
   if fMenu=nil then begin // no menu open: a heading is selected
    h:=fCurrent;
    if not IsHeadingSelectable(h) then begin // its heading is gone
     EndSession(true);
     exit(true);
    end;
    result:=false;
    cues:=true;
    if AltCombination(shiftstate) and KeyMnemonic(keycode,ch) then begin
     HeadingMnemonic(ch);
     exit;
    end;
    case TKey(keycode) of
     TKey.Left:MoveHeading(-1);
     TKey.Right:MoveHeading(1);
     TKey.Home:begin
      fCurrent:=nil;
      MoveHeading(1);
      if fCurrent=nil then SelectHeading(h);
     end;
     TKey.EndKey:begin
      fCurrent:=nil;
      MoveHeading(-1);
      if fCurrent=nil then SelectHeading(h);
     end;
     TKey.Down,TKey.Enter,TKey.Space:OpenItem(h,true);
     TKey.Up:begin
      OpenItem(h,false);
      if IsOpen and (fCurrent=h) then begin
       cues:=true;
       fMenu.fCurrent:=nil;
       fMenu.MoveCurrent(-1);
      end;
     end;
     TKey.Escape:EndSession(true);
    end;
    exit;
   end;
   if not fMenu.fOpen then begin // its heading is gone
    EndSession(true);
    exit(true);
   end;
   result:=false; // while open the menus take every key: the hotkeys keep silent
   cues:=true;
   d:=fMenu.Deepest;
   case TKey(keycode) of
    TKey.Left:
     if not d.IsChainChild then begin
      MoveHeading(-1);
      exit;
     end;
    TKey.Right:
     if (d.fCurrent=nil) or (d.fCurrent.fSubmenu=nil) then begin
      MoveHeading(1);
      exit;
     end;
   end;
   result:=fMenu.onKey(keycode,pressed,shiftstate);
  end;

 // The focus holder gets the typed characters: a mnemonic of the open menu or of a heading
 procedure TUIMenuBar.onUniChar(ch:Char32;scancode:byte);
  var
   s:String8;
  begin
   if not session or (ch<32) or TypedWithAlt(self) then exit;
   cues:=true;
   s:=CharToUtf8(ch);
   if IsOpen then fMenu.Deepest.SelectMnemonic(s)
    else HeadingMnemonic(s);
  end;

 procedure TUIMenuBar.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if state and session then Close;
  end;

 // Headings that don't fit scroll; an open menu stays at its heading: no scroll then
 procedure TUIMenuBar.onMouseScroll(value:integer);
  begin
   if session then exit;
   if contentWidth<=clientWidth then begin
    inherited;
    exit;
   end;
   scroll.X:=Clamp(scroll.X-value/100*GetStyleNumber('font-size',9)*3,0,contentWidth-clientWidth);
  end;

 procedure TUIMenuBar.onLostFocus;
  begin
   inherited;
   EndSession(false);
  end;

 procedure TUIMenuBar.onRemoved;
  begin
   Unlink;
   inherited;
  end;

 // The removed bar ends its session without tree or focus changes (the open menu closes by
 // its own check: its anchor is gone) and leaves the list of bars. The second call is a no-op
 procedure TUIMenuBar.Unlink;
  var
   i:integer;
  begin
   session:=false;
   switching:=false;
   cues:=false;
   timer:=0;
   fMenu:=nil;
   fCurrent:=nil;
   if previousFocus<>nil then previousFocus.Release;
   previousFocus:=nil;
   barLock.Enter;
   try
    for i:=high(bars) downto 0 do
     if bars[i]=self then begin
      bars[i]:=bars[high(bars)];
      SetLength(bars,length(bars)-1);
     end;
   finally
    barLock.Leave;
   end;
  end;

 // Safety check: the open menu (or the selected heading) has gone without telling
 procedure TUIMenuBar.onTimer;
  begin
   if not session then exit;
   if (fMenu=nil) and not IsHeadingSelectable(fCurrent) or (fMenu<>nil) and not fMenu.fOpen then begin
    EndSession(true);
    exit;
   end;
   timer:=CHECK_INTERVAL;
  end;

{ Keyboard activation }

 // The bar of the window and the UI root that takes the keyboard activation: visible, enabled,
 // allowed by the modal element. None while a standalone popup holds the focus (it takes the keys)
 function FindBar(wnd:TWindow;root:TUIElement):TUIMenuBar;
  var
   i:integer;
   b:TUIMenuBar;
   modal,focus:TUIElement;
  begin
   result:=nil;
   if (wnd=nil) or (root=nil) then exit;
   focus:=TUIElement(wnd.focus.element);
   if focus is TUIPopup then exit;
   modal:=wnd.modal.Root;
   barLock.Enter;
   try
    for i:=0 to high(bars) do begin
     b:=bars[i];
     if not b.keyboardActivation or b.deleted then continue;
     if (b.GetRoot<>root) or (b.GetWindow<>wnd) then continue;
     if not b.IsVisible or not b.IsEnabled then continue;
     if (modal<>nil) and (b<>modal) and not b.HasParent(modal) then continue;
     exit(b);
    end;
   finally
    barLock.Leave;
   end;
  end;

 // UIKeyPreview: F10 (no modifiers) - toggle the session; a single Alt - toggle on its
 // release; Alt+letter - the heading with this mnemonic (outside a session: inside it the bar
 // takes the key itself). Other keys and unmatched letters go on
 function MenuKeyPreview(wnd:TWindow;root:TUIElement;keycode:integer;shift:byte;pressed:boolean):boolean;
  var
   key:TKey;
   b:TUIMenuBar;
   ch:String8;
  begin
   result:=false;
   key:=TKey(keycode and $FF);
   if not pressed then begin
    if key=TKey.F10 then f10Held:=false;
    if key in [TKey.LAlt,TKey.RAlt] then begin
     altHeld:=false;
     altCueWnd:=nil;
     if (altWnd<>wnd) or (keySeq<>altSeq) then begin // another key in between
      altWnd:=nil;
      exit;
     end;
     altWnd:=nil;
     b:=FindBar(wnd,root);
     if b<>nil then begin
      b.Toggle;
      result:=true;
     end;
    end;
    exit;
   end;
   if key in [TKey.LAlt,TKey.RAlt] then begin // pressed alone - a candidate (auto-repeat changes nothing)
    if altHeld then exit;
    altHeld:=true;
    altSeq:=keySeq;
    if (shift and (sscShift or sscCtrl or sscWin))=0 then altWnd:=wnd
     else altWnd:=nil;
    if (shift and (sscCtrl or sscWin))=0 then altCueWnd:=wnd
     else altCueWnd:=nil;
    exit;
   end;
   altWnd:=nil; // any other key spoils the single Alt
   if key=TKey.F10 then begin
    if (shift and sscBaseMask)<>0 then begin
     f10Held:=false;
     exit;
    end;
    b:=FindBar(wnd,root);
    if b=nil then exit;
    result:=true;
    if not f10Held then b.Toggle;
    f10Held:=true;
    exit;
   end;
   if AltCombination(shift) and KeyMnemonic(keycode and $FF,ch) then begin
    b:=FindBar(wnd,root);
    if (b=nil) or b.session then exit;
    result:=b.HeadingMnemonic(ch);
   end;
  end;

 // A mouse press spoils the single Alt (Alt+click) and ends a session without an open menu
 // when it lands outside the area of the bar
 procedure MenuMouseDown(event:TEventStr;tag:TTag);
  var
   i:integer;
   b:TUIMenuBar;
   r:TRect;
   x,y:integer;
   list:array of TUIMenuBar;
  begin
   altWnd:=nil;
   if window=nil then exit;
   barLock.Enter;
   try
    list:=nil;
    for i:=0 to high(bars) do
     if bars[i].session and (bars[i].fMenu=nil) then begin
      SetLength(list,length(list)+1);
      list[high(list)]:=bars[i];
     end;
   finally
    barLock.Leave;
   end;
   if list=nil then exit;
   x:=window.mousePos.x;
   y:=window.mousePos.y;
   for b in list do begin
    if not b.session or (b.fMenu<>nil) or (b.GetWindow<>window) then continue;
    r:=b.GetPosOnScreen;
    if (x<r.Left) or (x>=r.Right) or (y<r.Top) or (y>=r.Bottom) then b.Close;
   end;
  end;

 // The window lost the activation: the keys pressed there are forgotten
 procedure MenuActivateWnd(event:TEventStr;tag:TTag);
  begin
   if tag=0 then begin
    altWnd:=nil;
    altCueWnd:=nil;
    altHeld:=false;
    f10Held:=false;
   end;
  end;

 // Any key but Alt spoils the single Alt, also a key taken before the scenes (an internal
 // hotkey: Alt+Enter, Alt+F11) or a release only (PrintScreen on Windows)
 procedure MenuKbdSignal(event:TEventStr;tag:TTag);
  var
   key:TKey;
  begin
   key:=TKey(tag and $FF);
   if not (key in [TKey.LAlt,TKey.RAlt]) then inc(keySeq);
  end;

initialization
 barLock.Init('UIMenuBars',810);
 UIKeyPreview:=MenuKeyPreview;
 SetEventHandler('MOUSE\BTNDOWN',MenuMouseDown,emInstant);
 SetEventHandler('Engine\ActivateWnd',MenuActivateWnd,emInstant);
 SetEventHandler('KBD\KEYDOWN',MenuKbdSignal,emInstant);
 SetEventHandler('KBD\KEYUP',MenuKbdSignal,emInstant);
end.
