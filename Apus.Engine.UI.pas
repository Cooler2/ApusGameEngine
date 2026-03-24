// -----------------------------------------------------
// Apus.Engine.UI — aggregate UI API unit.
//
// Re-exports core UI types, widgets, shapes, and layouters
// from their individual modules. Provides pivot presets and
// high-level helper functions for building user interfaces.
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// -----------------------------------------------------

unit Apus.Engine.UI;
interface
uses Apus.Core, Apus.Engine.Types, Apus.Engine.UITypes, Apus.Engine.UIShapes,
  Apus.Engine.UILayout, Apus.Engine.UIWidgets;

const
  // Predefined pivot point configuration
  pivotTopLeft:TVec2=(x:0; y:0);
  pivotTopCenter:TVec2=(x:0.5; y:0);
  pivotTopRight:TVec2=(x:1; y:0);
  pivotBottomLeft:TVec2=(x:0; y:1);
  pivotBottomCenter:TVec2=(x:0.5; y:1);
  pivotBottomRight:TVec2=(x:1; y:1);
  pivotCenter:TVec2=(x:0.5; y:0.5);
  pivotCenterLeft:TVec2=(x:0; y:0.5);
  pivotCenterRight:TVec2=(x:1; y:0.5);

  // Predefined anchor modes
  anchorAll:TAnchorMode=    (left:0; top:0; right:1; bottom: 1);
  anchorNone:TAnchorMode=   (left:0; top:0; right:0; bottom: 0);
  anchorTop:TAnchorMode=    (left:0; top:0; right:1; bottom: 0);
  anchorLeft:TAnchorMode=   (left:0; top:0; right:0; bottom: 1);
  anchorBottom:TAnchorMode= (left:0; top:1; right:1; bottom: 1);
  anchorRight:TAnchorMode=  (left:1; top:0; right:1; bottom: 1);
  anchorTopRight:TAnchorMode=  (left:1; top:0; right:1; bottom: 0);
  anchorBottomLeft:TAnchorMode=  (left:0; top:1; right:0; bottom: 1);
  anchorBottomRight:TAnchorMode=  (left:1; top:1; right:1; bottom: 1);
  anchorCenter:TAnchorMode= (left:0.5; top:0.5; right:0.5; bottom: 0.5);
  anchorTopCenter:TAnchorMode=    (left:0.5; top:0; right:0.5; bottom: 0);
  anchorBottomCenter:TAnchorMode= (left:0.5; top:1; right:0.5; bottom: 1);

  uiInherit = Apus.Engine.UITypes.uiInherit;

type
  // Standard widgets
  TUIElement      = Apus.Engine.UITypes.TUIElement;
  TUIGroupBox     = Apus.Engine.UITypes.TUIGroupBox;
  TUIScrollable   = Apus.Engine.UITypes.TUIScrollable;
  TUISplitter     = Apus.Engine.UIWidgets.TUISplitter;
  TUIButton       = Apus.Engine.UIWidgets.TUIButton;
  TUIToggleButton = Apus.Engine.UIWidgets.TUIToggleButton;
  TUICheckbox     = Apus.Engine.UIWidgets.TUICheckbox;
  TUIRadioButton  = Apus.Engine.UIWidgets.TUIRadioButton;
  TUILabel        = Apus.Engine.UIWidgets.TUILabel;
  TUIImage        = Apus.Engine.UIWidgets.TUIImage;
  TUIEditBox      = Apus.Engine.UIWidgets.TUIEditBox;
  TUIScrollBar    = Apus.Engine.UIWidgets.TUIScrollBar;
  TUIHint         = Apus.Engine.UIWidgets.TUIHint;
  TUIWindow       = Apus.Engine.UIWidgets.TUIWindow;
  TUIComboBox     = Apus.Engine.UIWidgets.TUIComboBox;
  TUIListBox      = Apus.Engine.UIWidgets.TUIListBox;

  // Layouters
  TLayouter  = Apus.Engine.UITypes.TLayouter;
  TRowLayout = Apus.Engine.UILayout.TRowLayout;
  TFlexboxLayout = Apus.Engine.UILayout.TFlexboxLayout;
  TGridLayout = Apus.Engine.UILayout.TGridLayout;

  // Other types
  TUIShape = Apus.Engine.UIShapes.TUIShape;
  TUIBitmapShape = Apus.Engine.UIShapes.TUIBitmapShape;
  TUIBasicShape = Apus.Engine.UIShapes.TUIBasicShape;
  TSendSignals = Apus.Engine.UITypes.TSendSignals;
  TSnapMode = Apus.Engine.UITypes.TSnapMode;

  procedure SetDefaultUIScale(fullScenesScale,windowedScenesScale:single);

  // Поиск элементов по имени. Если элемент не найден, то...
  // mustExists=true - исключение, false - будет создан (а в лог будет сообщение об этом)
  function UIElement(name:string8;autoCreate:boolean=false):TUIElement;
  function UIButton(name:string8;mustExist:boolean=false):TUIButton;
  function UIEditBox(name:string8;mustExist:boolean=false):TUIEditBox;
  function UILabel(name:string8;mustExist:boolean=false):TUILabel;
  function UIScrollBar(name:string8;mustExist:boolean=false):TUIScrollBar;
  function UIComboBox(name:string8;mustExist:boolean=false):TUIComboBox;
  function UIListBox(name:string8;mustExist:boolean=false):TUIListBox;
  function UICheckBox(name:string8;mustExist:boolean=false):TUICheckbox;
  function UIRadioButton(name:string8;mustExist:boolean=false):TUIRadioButton;

  // Controls setup
  procedure SetupButton(btn:TUIButton;cursor:integer;
             group:integer;default,enabled,pressed:boolean;hotkey:integer);

  procedure SetupEditBox(edit:TUIEditBox;text:string8;cursor,maxlength:integer;
             enabled,password,noborder:boolean);

  // Установка свойств элемента по имени
  procedure SetElementState(name:string8;visible:boolean;enabled:boolean=true);
  procedure SetElementText(name:string8;text:string8);

  // UI helpers
  // ------------
  // Create vertical container with fixed height
  function CreateVerticalContainer(width,height:single;parent:TUIElement;padding,spacing:single;
    centering:boolean;name:string8=''):TUIElement; overload;
  // Create vertical container with automatic height
  function CreateVerticalContainer(width:single;parent:TUIElement;padding,spacing:single;
    centering:boolean;name:string8=''):TUIElement; overload;
  // Create vertical container for the whole parent's client area
  function CreateVerticalContainer(parent:TUIElement;padding,spacing:single;centering:boolean;name:string8=''):TUIElement; overload;

  function CreateHorizontalContainer(height:single;parent:TUIElement;padding,spacing:single;name:string8=''):TUIElement; overload;

  // Полезные функции общего применения
  // -------
  // Создать всплывающее окно, прицепить его к указанному предку
  procedure ShowSimpleHint(msg:string8;parent:TUIElement;x,y,time:integer;font:cardinal=0);

  // Shortcut to the element under mouse
  function UnderMouse:TUIElement;
  function UnderMouseName:string8;
  function FocusedElement:TUIElement;
  procedure SetFocusTo(e:TUIElement);
  function ModalElement:TUIElement;
  procedure SetModalElement(e:TUIElement);

  // Найти элемент по имени (через хэш - среди всех)
  function FindElement(name:string8;mustExist:boolean=true):TUIElement;
  function FindControl(name:string8;mustExist:boolean=true):TUIElement; deprecated 'Use FindElement';
  // Найти элемент в заданной точке экрана (возвращает true если элемент найден и он
  // enabled - c учетом всех предков), игнорирует "прозрачные" в данной точке элементы
  function FindElementAt(x,y:integer;out c:TUIElement):boolean;
  function FindControlAt(x,y:integer;out c:TUIElement):boolean; deprecated 'Use FindElementAt';
  // Поиск элемента в данной точке не игнорируя "прозрачные" (полезно для отладки)
  function FindAnyElementAt(x,y:integer;out c:TUIElement):boolean;
  function FindAnyControlAt(x,y:integer;out c:TUIElement):boolean; deprecated 'Use FindAnyElementAt';

  // Dump all important UI data
  function DumpUI:string8;

implementation
 uses SysUtils, Apus.Engine.API, Apus.Engine.UIScene, Apus.Engine.Window, Apus.EventMan,
  Apus.Conv,
  Apus.Strings,
  Apus.Threads;

 type
 TUIRootList=array of TUIElement;
 TIntArray=array of integer;

 procedure CollectUIRoots(out roots:TUIRootList;out zOrders:TIntArray;onlyVisible:boolean); forward;
 function GetDefaultUIRoot:TUIElement; forward;
 function RequireAutoCreateRoot(const kind,name:string8):TUIElement; forward;

 procedure SetDefaultUIScale(fullScenesScale,windowedScenesScale:single);
  begin
   defaultScale:=fullScenesScale;
   windowScale:=windowedScenesScale;
  end;

 procedure ShowSimpleHint(msg:string8;parent:TUIElement;x,y,time:integer;font:cardinal=0);
  begin
   Apus.Engine.UIScene.ShowSimpleHint(msg,parent,x,y,time,font);
  end;

 function CreateVerticalContainer(width:single;parent:TUIElement;padding,spacing:single;centering:boolean;name:string8):TUIElement;
  begin
   result:=TUIElement.Create(width,0,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,true,centering);
   result.SetPadding(padding);
  end;

 function CreateVerticalContainer(width,height:single;parent:TUIElement;padding,spacing:single;centering:boolean;name:string8):TUIElement;
  begin
   result:=TUIElement.Create(width,height,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,false,centering);
   result.SetPadding(padding);
  end;

 function CreateVerticalContainer(parent:TUIElement;padding,spacing:single;centering:boolean;name:string8):TUIElement; overload;
  begin
   result:=TUIElement.Create(-1,-1,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,false,centering);
   result.SetPadding(padding);
  end;

 function CreateHorizontalContainer(height:single;parent:TUIElement;padding,spacing:single;name:string8):TUIElement; overload;
  begin
   result:=TUIElement.Create(0,height,parent,name);
   result.layout:=TRowLayout.CreateHorizontal(spacing,true);
   result.SetPadding(padding);
  end;

 procedure SetElementText(name:string8;text:string8);
  var
   c:TUIElement;
  begin
   c:=FindElement(name,false);
   if c=nil then exit;
   if c is TUILabel then
    TUILabel(c).caption:=text
   else
   if c is TUIButton then
    TUIButton(c).caption:=text
   else
   if c is TUIEditBox then
    TUIEditBox(c).realText:=Str32(text);
  end;

 function UIElement(name:string8;autoCreate:boolean=false):TUIElement;
  var
   root:TUIElement;
  begin
   result:=FindElement(name,false);
   if (result=nil) and autoCreate then begin
    root:=RequireAutoCreateRoot('UI element',name);
    result:=TUIElement.Create(0,0,root,name);
   end;
  end;

 function UIButton(name:string8;mustExist:boolean=false):TUIButton;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIButton) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIButton',name);
    c:=TUIButton.Create(0,0,root,name);
   end;
   result:=c as TUIButton;
  end;

 function UIEditBox(name:string8;mustExist:boolean=false):TUIEditBox;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIEditBox) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIEditBox',name);
    c:=TUIEditBox.Create(0,0,root,name);
   end;
   result:=c as TUIEditBox;
  end;

 function UILabel(name:string8;mustExist:boolean=false):TUILabel;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUILabel) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UILabel',name);
    c:=TUILabel.Create(0,0,root,name);
   end;
   result:=c as TUILabel;
  end;

 function UIScrollBar(name:string8;mustExist:boolean=false):TUIScrollBar;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIScrollBar) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIScrollBar',name);
    c:=TUIScrollBar.Create(0,0,root,name);
   end;
   result:=c as TUIScrollBar;
  end;

 function UIComboBox(name:string8;mustExist:boolean=false):TUIComboBox;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIComboBox) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIComboBox',name);
    c:=TUIComboBox.Create(0,0,root,name);
   end;
   result:=c as TUIComboBox;
  end;

 function UIListBox(name:string8;mustExist:boolean=false):TUIListBox;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIListBox) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIListBox',name);
    c:=TUIListBox.Create(0,0,root,name);
   end;
   result:=c as TUIListBox;
  end;

 function UICheckBox(name:string8;mustExist:boolean=false):TUICheckbox;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUICheckbox) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UICheckBox',name);
    c:=TUICheckbox.Create(0,0,root,name);
   end;
   result:=c as TUICheckbox;
  end;

 function UIRadioButton(name:string8;mustExist:boolean=false):TUIRadioButton;
  var
   c,root:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIRadioButton) then c:=nil;
   if c=nil then begin
    root:=RequireAutoCreateRoot('UIRadioButton',name);
    c:=TUIRadioButton.Create(0,0,root,name);
   end;
   result:=c as TUIRadioButton;
  end;
 procedure CollectUIRoots(out roots:TUIRootList;out zOrders:TIntArray;onlyVisible:boolean);
  var
   i,n:integer;
   sc:TGameScene;
   s:TUIScene;
  begin
   SetLength(roots,0);
   SetLength(zOrders,0);
   if (window=nil) or (window.scenes=nil) then exit;
   n:=0;
   for i:=0 to high(window.scenes) do begin
    sc:=window.scenes[i];
    if not (sc is TUIScene) then continue;
    s:=TUIScene(sc);
    if s.UI=nil then continue;
    if onlyVisible and (not s.UI.flags.visible) then continue;
    SetLength(roots,n+1);
    SetLength(zOrders,n+1);
    roots[n]:=s.UI;
    zOrders[n]:=sc.zOrder;
    inc(n);
   end;
  end;

 function GetDefaultUIRoot:TUIElement;
  var
   roots:TUIRootList;
   zOrders:TIntArray;
   i,bestIdx,bestZ:integer;
  begin
   CollectUIRoots(roots,zOrders,true);
   bestIdx:=-1;
   bestZ:=Low(integer);
   for i:=0 to high(roots) do
    if zOrders[i]>=bestZ then begin
     bestZ:=zOrders[i];
     bestIdx:=i;
    end;
   if bestIdx>=0 then result:=roots[bestIdx]
    else result:=nil;
  end;

 function RequireAutoCreateRoot(const kind,name:string8):TUIElement;
  begin
   result:=GetDefaultUIRoot;
   if result=nil then
    raise EError.Create('Can''t auto-create '+kind+' "'+name+'": no active UI root');
  end;

 function FindElement(name:string8;mustExist:boolean=true):TUIElement;
  begin
   result:=TUIElement.FindByName(name) as TUIElement;
   if mustExist and (result=nil) then begin
    raise EWarning.Create('UI element '+name+' not found');
   end;
  end;

 function FindControl(name:string8;mustExist:boolean=true):TUIElement;
  begin
   result:=FindElement(name,mustExist);
  end;

 // any=false - ignore disabled elements
 function FindControlAtInternal(x,y:integer;any:boolean;out c:TUIElement):boolean;
  var
   i,maxZ:integer;
   roots:TUIRootList;
   zOrders:TIntArray;
   ct,c2:TUIElement;
   enabl:boolean;
  begin
   c:=nil; maxZ:=-1;
   window.Lock;
   try
   CollectUIRoots(roots,zOrders,true);
   // Принцип простой: искать элемент на верхнем слое, если не нашлось - на следующем и т.д.
   for i:=0 to high(roots) do begin
    if any then enabl:=roots[i].FindAnyElementAt(x,y,ct)
     else enabl:=roots[i].FindElementAt(x,y,ct);
    if ct<>nil then begin
     c2:=ct; // найдем корневого предка ct (вдруг это не rootControls[i]?)
     while c2.parent<>nil do c2:=c2.parent;
     if (modalElement<>nil) and (c2<>modalElement) then begin
      continue;
     end;
     // выбор элемента с максимальным уровнем Z
     if zOrders[i]>maxZ then begin c:=ct; maxZ:=zOrders[i]; end;
    end;
   end;
   result:=(c<>nil) and c.flags.enabled;
   finally
    window.Unlock;
   end;
  end;

 function FindElementAt(x,y:integer;out c:TUIElement):boolean;
  begin
   result:=FindControlAtInternal(x,y,false,c);
  end;

 function FindAnyElementAt(x,y:integer;out c:TUIElement):boolean;
  begin
   result:=FindControlAtInternal(x,y,true,c);
  end;

 function FindControlAt(x,y:integer;out c:TUIElement):boolean;
  begin
   result:=FindControlAtInternal(x,y,false,c);
  end;

 function FindAnyControlAt(x,y:integer;out c:TUIElement):boolean;
  begin
   result:=FindControlAtInternal(x,y,true,c);
  end;

 function ModalElement:TUIElement;
  begin
   result:=Apus.Engine.UITypes.ModalElement;
  end;

 function UnderMouse:TUIElement;
  begin
   result:=Apus.Engine.UITypes.underMouse;
  end;

 function UnderMouseName:string8;
  var
   el:TUIElement;
  begin
   el:=UnderMouse;
   if el<>nil then result:=el.name
    else result:='';
  end;

 function FocusedElement:TUIElement;
  begin
   result:=Apus.Engine.UITypes.FocusedElement;
  end;

 procedure SetFocusTo(e:TUIElement);
  begin
   Apus.Engine.UITypes.SetFocusTo(e);
  end;

 procedure SetModalElement(e:TUIElement);
  begin
   Apus.Engine.UITypes.ModalElement:=e;
  end;

 procedure SetElementState(name:string8;visible:boolean;enabled:boolean=true);
  var
   c:TUIElement;
  begin
   c:=FindElement(name,false);
   if c=nil then exit;
   c.flags.visible:=visible;
   c.flags.enabled:=enabled;
  end;

 function DumpUITree(root:TUIElement):string8;
   function DumpElement(c:TUIElement;indent:string8):string8;
    var
     i:integer;
     shapeStr:string8;
    begin
     if c.shape=shapeEmpty then shapeStr:='empty'
     else if c.shape=shapeFull then shapeStr:='full'
     else shapeStr:='custom';
     result:=string8.Join([
      indent+c.ClassName+':'+c.name+' = '+IntToHex(cardinal(c),8),
      indent+Format('%d En=%d Vis=%d shape=%s',[c.order,byte(c.flags.enabled),byte(c.flags.visible),shapeStr]),
      indent+Format('x=%.1f, y=%.1f, w=%.1f, h=%.1f, left=%d, top=%d',
       [c.position.x,c.position.y,c.size.x,c.size.y,c.globalRect.Left,c.globalRect.Top]),
       ''],#13#10);
     for i:=0 to length(c.children)-1 do
      result:=result+DumpElement(c.children[i],indent+'+ ');
    end;
   begin
    result:=DumpElement(root,'');
   end;

 function DumpUI:string8;
  var
   i:integer;
   roots:TUIRootList;
   zOrders:TIntArray;
  begin
    result:=string8.Join([
     'Modal: '+Conv.ToStr(modalElement),
     'Focused: '+Conv.ToStr(FocusedElement),
     'Hooked: '+Conv.ToStr(hooked),
     ''],#13#10);
    CollectUIRoots(roots,zOrders,false);
    for i:=0 to high(roots) do
      result:=result+DumpUITree(roots[i])+#13#10;
  end;

 procedure SetupButton(btn:TUIButton;cursor:integer;
              group:integer;default,enabled,pressed:boolean;hotkey:integer);
  begin
   btn.cursor:=cursor;
   btn.default:=default;
   btn.flags.enabled:=enabled;
   btn.pressed:=pressed;
   if hotkey<>0 then
    btn.SetHotKey(hotkey and 255,hotkey shr 8);
  end;

 procedure SetupEditBox(edit:TUIEditBox;text:string8;cursor,maxlength:integer;
                 enabled,password,noborder:boolean);
  begin
   edit.text:=text;
   edit.cursor:=cursor;
   edit.maxlength:=maxlength;
   edit.flags.enabled:=enabled;
   edit.password:=password;
   // noborder removed from TUIEditBox
  end;

 // UI-related commands: Command:elementName
 // where command can be
 // Enable, Disable, Show, Hide, Toggle, ToggleEnabled
 procedure UICommand(event:TEventStr;tag:TTag);
  var
   p:integer;
   value:string8;
   e:TUIElement;
   wnd:TWindow;
  begin
   event:=Copy(event,8,length(event));
   p:=pos(':',event);
   if p<=0 then exit;
   value:=copy(event,p+1,length(event));
   SetLength(event,p-1);
   e:=FindElement(value,false);
   if e=nil then exit;
   wnd:=e.GetWindow;
   if wnd=nil then
    raise EError.Create('Can''t resolve window for UI command target '+value);
   wnd.Lock;
   try
    if SameText(event,'toggle') then
      e.Toggle
    else
    if SameText(event,'ToggleEnabled') then
     e.ToggleEnabled
    else
    if SameText(event,'enable') then
     e.Enable
    else
    if SameText(event,'disable') then
     e.Disable
    else
    if SameText(event,'hide') then
     e.Hide
    else
    if SameText(event,'show') then
     e.Show;
   finally
    wnd.Unlock;
   end;
  end;


initialization
 SetEventHandler('UI\CMD',UICommand,emInstant);
end.
