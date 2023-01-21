// UI API unit with most UI-related declarations and utility functions
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------

unit Apus.Engine.UI;
interface
 uses Apus.Types, Apus.Engine.Types, Apus.Engine.UITypes, Apus.Engine.UILayout, Apus.Engine.UIWidgets;

 const
  // Predefined pivot point configuration
  pivotTopLeft:TPoint2s=(x:0; y:0);
  pivotTopCenter:TPoint2s=(x:0.5; y:0);
  pivotTopRight:TPoint2s=(x:1; y:0);
  pivotBottomLeft:TPoint2s=(x:0; y:1);
  pivotBottomCenter:TPoint2s=(x:0.5; y:1);
  pivotBottomRight:TPoint2s=(x:1; y:1);
  pivotCenter:TPoint2s=(x:0.5; y:0.5);
  pivotCenterLeft:TPoint2s=(x:0; y:0.5);
  pivotCenterRight:TPoint2s=(x:1; y:0.5);

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

  INHERIT = Apus.Engine.UITypes.INHERIT;

 type
  // Standard widgets
  TUIElement   = Apus.Engine.UITypes.TUIElement;
  TUISplitter  = Apus.Engine.UIWidgets.TUISplitter;
  TUIButton    = Apus.Engine.UIWidgets.TUIButton;
  TUICheckbox  = Apus.Engine.UIWidgets.TUICheckbox;
  TUIRadioButton = Apus.Engine.UIWidgets.TUIRadioButton;
  TUILabel     = Apus.Engine.UIWidgets.TUILabel;
  TUIImage     = Apus.Engine.UIWidgets.TUIImage;
  TUIEditBox   = Apus.Engine.UIWidgets.TUIEditBox;
  TUIScrollBar = Apus.Engine.UIWidgets.TUIScrollBar;
  TUIHint      = Apus.Engine.UIWidgets.TUIHint;
  TUIWindow    = Apus.Engine.UIWidgets.TUIWindow;
  TUIComboBox  = Apus.Engine.UIWidgets.TUIComboBox;
  TUIListBox   = Apus.Engine.UIWidgets.TUIListBox;

  // Layouters
  TLayouter  = Apus.Engine.UITypes.TLayouter;
  TRowLayout = Apus.Engine.UILayout.TRowLayout;
  TFlexboxLayout = Apus.Engine.UILayout.TFlexboxLayout;
  TGridLayout = Apus.Engine.UILayout.TGridLayout;

  // Other types
  TElementShape = Apus.Engine.UITypes.TElementShape;
  TSendSignals = Apus.Engine.UITypes.TSendSignals;
  TButtonStyle = Apus.Engine.UIWidgets.TButtonStyle;
  TSnapMode = Apus.Engine.UITypes.TSnapMode;

  procedure SetDefaultUIScale(fullScenesScale,windowedScenesScale:single);

  // Поиск элементов по имени. Если элемент не найден, то...
  // mustExists=true - исключение, false - будет создан (а в лог будет сообщение об этом)
  function UIElement(name:string;autoCreate:boolean=false):TUIElement;
  function UIButton(name:string;mustExist:boolean=false):TUIButton;
  function UIEditBox(name:string;mustExist:boolean=false):TUIEditBox;
  function UILabel(name:string;mustExist:boolean=false):TUILabel;
  function UIScrollBar(name:string;mustExist:boolean=false):TUIScrollBar;
  function UIComboBox(name:string;mustExist:boolean=false):TUIComboBox;
  function UIListBox(name:string;mustExist:boolean=false):TUIListBox;
  function UICheckBox(name:string;mustExist:boolean=false):TUICheckbox;
  function UIRadioButton(name:string;mustExist:boolean=false):TUIRadioButton;

  // Controls setup
  procedure SetupButton(btn:TUIButton;style:byte;cursor:integer;btnType:TButtonStyle;
             group:integer;default,enabled,pressed:boolean;hotkey:integer);

  procedure SetupEditBox(edit:TUIEditBox;text:string;style:byte;cursor,maxlength:integer;
             enabled,password,noborder:boolean);

  // Установка свойств элемента по имени
  procedure SetElementState(name:string;visible:boolean;enabled:boolean=true);
  procedure SetElementText(name:string;text:string);

  // UI helpers
  // ------------
  // Create vertical container with fixed height
  function CreateVerticalContainer(width,height:single;parent:TUIElement;padding,spacing:single;
    centering:boolean;name:string=''):TUIElement; overload;
  // Create vertical container with automatic height
  function CreateVerticalContainer(width:single;parent:TUIElement;padding,spacing:single;
    centering:boolean;name:string=''):TUIElement; overload;
  // Create vertical container for the whole parent's client area
  function CreateVerticalContainer(parent:TUIElement;padding,spacing:single;centering:boolean;name:string=''):TUIElement; overload;

  function CreateHorizontalContainer(height:single;parent:TUIElement;padding,spacing:single;name:string=''):TUIElement; overload;

  // Полезные функции общего применения
  // -------
  // Создать всплывающее окно, прицепить его к указанному предку
  procedure ShowSimpleHint(msg:string;parent:TUIElement;x,y,time:integer;font:cardinal=0);

  // Shortcut to the element under mouse
  function UnderMouse:TUIElement;
  function UnderMouseName:string;
  function FocusedElement:TUIElement;
  procedure SetFocusTo(e:TUIElement);
  function ModalElement:TUIElement;
  procedure SetModalElement(e:TUIElement);

  // Найти элемент по имени (через хэш - среди всех)
  function FindElement(name:String8;mustExist:boolean=true):TUIElement;
  function FindControl(name:String8;mustExist:boolean=true):TUIElement; deprecated 'Use FindElement';
  // Найти элемент в заданной точке экрана (возвращает true если элемент найден и он
  // enabled - c учетом всех предков), игнорирует "прозрачные" в данной точке элементы
  function FindElementAt(x,y:integer;out c:TUIElement):boolean;
  function FindControlAt(x,y:integer;out c:TUIElement):boolean; deprecated 'Use FindElementAt';
  // Поиск элемента в данной точке не игнорируя "прозрачные" (полезно для отладки)
  function FindAnyElementAt(x,y:integer;out c:TUIElement):boolean;
  function FindAnyControlAt(x,y:integer;out c:TUIElement):boolean; deprecated 'Use FindAnyElementAt';

  // Dump all important UI data
  function DumpUI:String8;

  // UI critical section (mostly for internal use)
  procedure LockUI(caller:pointer=nil);
  procedure UnlockUI;

implementation
 uses Apus.Common, SysUtils, Apus.Engine.UIScene, Apus.EventMan;

 procedure SetDefaultUIScale(fullScenesScale,windowedScenesScale:single);
  begin
   defaultScale:=fullScenesScale;
   windowScale:=windowedScenesScale;
  end;

 procedure ShowSimpleHint(msg:string;parent:TUIElement;x,y,time:integer;font:cardinal=0);
  begin
   Apus.Engine.UIScene.ShowSimpleHint(msg,parent,x,y,time,font);
  end;

 function CreateVerticalContainer(width:single;parent:TUIElement;padding,spacing:single;centering:boolean;name:string):TUIElement;
  begin
   result:=TUIElement.Create(width,0,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,true,centering);
   result.SetPadding(padding);
  end;

 function CreateVerticalContainer(width,height:single;parent:TUIElement;padding,spacing:single;centering:boolean;name:string):TUIElement;
  begin
   result:=TUIElement.Create(width,height,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,false,centering);
   result.SetPadding(padding);
  end;

 function CreateVerticalContainer(parent:TUIElement;padding,spacing:single;centering:boolean;name:string):TUIElement; overload;
  begin
   result:=TUIElement.Create(-1,-1,parent,name);
   result.layout:=TRowLayout.CreateVertical(spacing,false,centering);
   result.SetPadding(padding);
  end;

 function CreateHorizontalContainer(height:single;parent:TUIElement;padding,spacing:single;name:string):TUIElement; overload;
  begin
   result:=TUIElement.Create(0,height,parent,name);
   result.layout:=TRowLayout.CreateHorizontal(spacing,true);
   result.SetPadding(padding);
  end;

 procedure SetElementText(name:string;text:string);
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
    TUIEditBox(c).realText:=text;
  end;

 function UIElement(name:string;autoCreate:boolean=false):TUIElement;
  begin
   result:=FindElement(name,false);
   if (result=nil) and (autoCreate) then result:=TUIElement.Create(0,0,nil,name);
  end;

 function UIButton(name:string;mustExist:boolean=false):TUIButton;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIButton) then c:=nil;
   if c=nil then c:=TUIButton.Create(0,0,name,'',0,nil);
   result:=c as TUIButton;
  end;

 function UIEditBox(name:string;mustExist:boolean=false):TUIEditBox;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIEditBox) then c:=nil;
   if c=nil then c:=TUIEditBox.Create(0,0,name,0,0,nil);
   result:=c as TUIEditBox;
  end;

 function UILabel(name:string;mustExist:boolean=false):TUILabel;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUILabel) then c:=nil;
   if c=nil then c:=TUILabel.Create(0,0,name,'',0,0,nil);
   result:=c as TUILabel;
  end;

 function UIScrollBar(name:string;mustExist:boolean=false):TUIScrollBar;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIScrollBar) then c:=nil;
   if c=nil then c:=TUIScrollBar.Create(0,0,name,nil);
   result:=c as TUIScrollBar;
  end;

 function UIComboBox(name:string;mustExist:boolean=false):TUIComboBox;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIComboBox) then c:=nil;
   if c=nil then c:=TUIComboBox.Create(0,0,0,nil,nil,name);
   result:=c as TUIComboBox;
  end;

 function UIListBox(name:string;mustExist:boolean=false):TUIListBox;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIListBox) then c:=nil;
   if c=nil then c:=TUIListBox.Create(0,0,0,name,0,nil);
   result:=c as TUIListBox;
  end;

 function UICheckBox(name:string;mustExist:boolean=false):TUICheckbox;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUICheckbox) then c:=nil;
   if c=nil then c:=TUICheckbox.Create(0,0,name,'',nil);
   result:=c as TUICheckbox;
  end;

 function UIRadioButton(name:string;mustExist:boolean=false):TUIRadioButton;
  var
   c:TUIElement;
  begin
   c:=FindElement(name,mustExist);
   if not (c is TUIRadioButton) then c:=nil;
   if c=nil then c:=TUIRadioButton.Create(0,0,'','',nil);
   result:=c as TUIRadioButton;
  end;


  // Make sure root controls list is sorted
 procedure SortRootElements;
  var
   i,j:integer;
   c:TUIElement;
  begin
   for i:=1 to high(rootElements) do
    if rootElements[i].order>rootElements[i-1].order then begin
     j:=i;
     while (j>0) and (rootElements[j].order>rootElements[j-1].order) do begin
      c:=rootElements[j-1];
      rootElements[j-1]:=rootElements[j];
      rootElements[j]:=c;
      dec(j);
     end;
    end;
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
   ct,c2:TUIElement;
   found,enabl:boolean;
  begin
   c:=nil; maxZ:=-1;
   UICritSect.Enter;
   try
   SortRootElements;
   // Принцип простой: искать элемент на верхнем слое, если не нашлось - на следующем и т.д.
   for i:=0 to high(rootElements) do begin
    if any then enabl:=rootElements[i].FindAnyElementAt(x,y,ct)
     else enabl:=rootElements[i].FindElementAt(x,y,ct);
    if ct<>nil then begin
     c2:=ct; // найдем корневого предка ct (вдруг это не rootControls[i]?)
     while c2.parent<>nil do c2:=c2.parent;
     if (modalElement<>nil) and (c2<>modalElement) then begin
      continue;
     end;
     // выбор элемента с максимальным уровнем Z
     if c2.order>maxZ then begin c:=ct; maxZ:=c2.order; end;
    end;
   end;
   result:=(c<>nil) and c.enabled;
   finally
    UICritSect.Leave;
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

 function UnderMouseName:string;
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

 procedure SetElementState(name:string;visible:boolean;enabled:boolean=true);
  var
   c:TUIElement;
  begin
   c:=FindElement(name,false);
   if c=nil then exit;
   c.visible:=visible;
   c.enabled:=enabled;
  end;

 function DumpUITree(root:TUIElement):String8;
   function DumpElement(c:TUIElement;indent:String8):String8;
    var
     i:integer;
    begin
     result:=Join([
      indent+c.ClassName+':'+c.name+' = '+IntToHex(cardinal(c),8),
      indent+Format('%d En=%d Vis=%d trM=%d',[c.order,byte(c.enabled),byte(c.visible),ord(c.shape)]),
      indent+Format('x=%.1f, y=%.1f, w=%.1f, h=%.1f, left=%d, top=%d',
       [c.position.x,c.position.y,c.size.x,c.size.y,c.globalRect.Left,c.globalRect.Top]),
       ''],#13#10);
     for i:=0 to length(c.children)-1 do
      result:=result+DumpElement(c.children[i],indent+'+ ');
    end;
   begin
    result:=DumpElement(root,'');
   end;

 function DumpUI:String8;
  var
   i:integer;
  begin
    result:=Join([
     'Modal: '+PtrToStr(modalElement),
     'Focused: '+PtrToStr(FocusedElement),
     'Hooked: '+PtrToStr(hooked),
     ''],#13#10);
    for i:=0 to high(rootElements) do
      result:=result+DumpUITree(rootElements[i])+#13#10;
  end;

 procedure SetupButton(btn:TUIButton;style:byte;cursor:integer;btnType:TBUttonStyle;
              group:integer;default,enabled,pressed:boolean;hotkey:integer);
  begin
   btn.style:=style;
   btn.cursor:=cursor;
   btn.btnStyle:=btnType;
   btn.group:=group;
   btn.default:=default;
   btn.enabled:=enabled;
   btn.pressed:=pressed;
   if hotkey<>0 then
    btn.SetHotKey(hotkey and 255,hotkey shr 8);
  end;

 procedure SetupEditBox(edit:TUIEditBox;text:string;style:byte;cursor,maxlength:integer;
                 enabled,password,noborder:boolean);
  begin
   edit.text:=text;
   edit.style:=style;
   edit.cursor:=cursor;
   edit.maxlength:=maxlength;
   edit.enabled:=enabled;
   edit.password:=password;
   edit.noborder:=noborder;
  end;

 procedure LockUI(caller:pointer=nil);
  begin
   EnterCriticalSection(UICritSect,caller);
  end;

 procedure UnlockUI;
  begin
   LeaveCriticalSection(UICritSect);
  end;

 // UI-related commands: Command:elementName
 // where command can be
 // Enable, Disable, Show, Hide, Toggle, ToggleEnabled
 procedure UICommand(event:TEventStr;tag:TTag);
  var
   p:integer;
   value:string;
   e:TUIElement;
  begin
   event:=Copy(event,8,length(event));
   p:=pos(':',event);
   if p>0 then begin
     value:=copy(event,p+1,length(event));
     SetLength(event,p-1);
     e:=FindElement(value);
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
   end;
  end;


initialization
 SetEventHandler('UI\CMD',UICommand,emInstant);
end.
