﻿// -----------------------------------------------------
// User Interface classes
// This is independent brick.
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UITypes;
interface
uses Types, Apus.Classes, Apus.CrossPlatform, Apus.Engine.Types,
   Apus.MyServis, Apus.AnimatedValues, Apus.Regions, Apus.Geom2d;
{$WRITEABLECONST ON}
{$IFDEF CPUARM} {$R-} {$ENDIF}

const
 // Predefined pivot point configuration
 pivotTopLeft:TPoint2s=(x:0; y:0);
 pivotTopRight:TPoint2s=(x:1; y:0);
 pivotBottomLeft:TPoint2s=(x:0; y:1);
 pivotBottomRight:TPoint2s=(x:1; y:1);
 pivotCenter:TPoint2s=(x:0.5; y:0.5);

type
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

 // How element response for mouse/touch events
 TElementShape=(shapeEmpty, // whole element is transparent for mouse/touch events
                shapeFull,      // whole element is opaque for mouse/touch events
                shapeCustom);     // some pixels are transparent, some are not - it depends on the Region field

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
                   pmCenter);       // Elements center is moved proportionally, but size remains

 TUIElement=class;
 TRegion = Apus.Regions.TRegion;


 // Base class for Layouters: objects that layout child elements or adjust elements considering its children
 TLayouter=class
  procedure Layout(item:TUIElement); virtual; abstract;
 end;

 // Layout elements in a row/column
 // spaceBetween - spacing between elements
 // resizeToContent - make item size match
 // center - align elements to item's central line
 TRowLayout=class(TLayouter)
  constructor Create(horizontal:boolean=true; spaceBetween:single=0; resizeToContent:boolean=false; center:boolean=false);
  procedure Layout(item:TUIElement); override;
 private
  fHorizontal,fResize,fCenter:boolean;
  fSpaceBetween:single;
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

 // Base class of the UI element
 TUIElement=class(TNamedObject)
  position:TPoint2s;  // Положение root point in parent's client rect (если предка нет - положение на экране)
  pivot:TPoint2s; // relative location of the element's root point: 0,0 -> upper left corner, 1,1 - bottom right corner, 0.5,0.5 - center
  scale:TVector2s; // scale factor for this element (size) and all children elements
  size:TVector2s; // dimension of this element
  paddingLeft,paddingTop,paddingRight,paddingBottom:single; // рамка отсечения при отрисовке вложенных эл-тов (может также использоваться для других целей)
  shape:TElementShape;  // Режим прозрачности для событий ввода
  shapeRegion:TRegion;   // задает область непрозрачности в режиме tmCustom (поведение по умолчанию)
  scroll:TVector2s; // смещение (используется для вложенных эл-тов!) SUBTRACT from children pos
  scrollerH,scrollerV:IScroller;  // если для прокрутки используются скроллбары - здесь можно их определить
  placementMode:TUIPlacementMode;  // Реакция на изменение размеров предка
  anchorLeft,anchorTop:single; // если эти якоря не установлены, то при изменении размера должны меняться x и y
  anchorRight,anchorBottom:single; // "якоря" для привязки соответствующих краев к краям предка (при изменении размера предка)

  enabled:boolean; // Должен ли элемент реагировать на пользовательский ввод
  visible:boolean; // должен ли элемент рисоваться
  manualDraw:boolean; // Указывает на то, что элемент рисуется специальным кодом, а DrawUI его игнорирует
  cursor:integer; // Идентификатор курсора (0 - default)
  order:integer; // Определяет порядок отрисовки ($10000 - база для StayOnTop-эл-тов), отрицательные значения - специальные
  // Define how the element should be displayed
  style:byte;    // Стиль для отрисовки (0 - использует отрисовщик по умолчанию)
  styleInfoChanged:boolean; // set true whenever styleInfo changes

  canHaveFocus:boolean; // может ли элемент обладать фокусом ввода
  hint,hintIfDisabled:string; // текст всплывающей подсказки (отдельный вариант - для ситуации, когда элемент disabled, причем именно этот элемент, а не за счёт предков)
  hintDelay:integer; // время (в мс), через которое элемент должен показать hint (в режиме показа hint'ов это время значительно меньше)
  hintDuration:integer; // длительность (в мс) показа хинта
  sendSignals:TSendSignals; // режим сигнализирования (см. выше)
  // Clipping: use clipChildren to allow hovering, not parentClip
  parentClip:boolean; // clip this element by parents client rect? (default - yes!)
  clipChildren:boolean; // clip children elements by self client rect? (default - yes)

  timer:integer; // таймер - указывает время в мс через которое будет вызван onTimer() (но не раньше чем через кадр, 0 - не вызывать)

  tag:NativeInt; // custom data for manual use
  customPtr:pointer; // custom data for manual use

  parent:TUIElement; // Ссылка на элемент-предок
  children:array of TUIElement; // Список вложенных элементов
  layout:TLayouter; // layout child elements

  // Derived attributes. Эти параметры (вторичные св-ва) вычисляются первичными событиями,
  // поэтому пользоваться ими нужно аккуратно
  globalRect:TRect;  // положение элемента на экране (может быть устаревшим! для точного положения - GetPosOnScreen)

  // Создает элемент
  constructor Create(width,height:single;parent_:TUIElement;name_:string='');
  // Удаляет элемент (а также все вложенные в него)
  destructor Destroy; override;
  // Queue element to destroy somewhere later (before the next frame)
  procedure SafeDestroy;

  // Найти следующий по порядку элемент того же уровня
  function GetNext:TUIElement; virtual;
  // Найти предыдущий по порядку элемент того же уровня
  function GetPrev:TUIElement; virtual;
  // Найти самого дальнего предка (корневой элемент)
  function GetRoot:TUIElement;
  // Виден ли элемент (проверяет видимость всех предков)
  function IsVisible:boolean;
  // Доступен ли элемент (проверяет доступность всех предков)
  function IsEnabled:boolean;
  // Является ли указанный элемент потомком данного?
  function IsChild(c:TUIElement):boolean;
  // Вложен ли данный элемент в указанный (direct or indirect) (HasParent(self)=true)
  function HasParent(c:TUIElement):boolean;
  // Есть ли у данного элемента указанный потомок (direct or indirect) (HasChild(self)=true)
  function HasChild(c:TUIElement):boolean;
  // Delete all children elements
  procedure DeleteChildren;

  // Attach to a new parent
  procedure AttachTo(newParent:TUIElement);
  // Detach from parent
  procedure Detach(shouldAddToRootControls:boolean=true);

  // Transformations. Element's coordinate system is (0,0 - clientWidth,clinetHeight) where
  //   0,0 - is upper-left corner of the client area. This CS is for internal use.
  // Transform to given element's CS (nil - screen space)
  function TransformTo(const p:TPoint2s;target:TUIElement):TPoint2s; overload;
  function TransformTo(const r:TRect2s;target:TUIElement):TRect2s; overload;
  // Transform to the root element (screen space)
  function TransformToScreen(const p:TPoint2s):TPoint2s; overload;
  function TransformToScreen(const r:TRect2s):TRect2s; overload;
  function GetRect:TRect2s; // Get element's area in its own CS (i.e. relative to pivot point)
  function GetRectInParentSpace:TRect2s; // Get element's area in parent client space)
  function GetClientRect:TRect2s; // Get element's client area in its own CS

  // получить экранные к-ты элемента
  function GetPosOnScreen:TRect;
  function GetClientPosOnScreen:TRect;

  // Primary event handlers
  // Сцена (или другой клиент) вызывает эти методы у корневого эл-та, а он
  // перенаправляет их соответствующим элементам по принципу:
  // - движение мыши - по точке начала и конца двжения
  // - нажатие и скроллинг - элементу под мышью
  // - клавиатура - элементу, имеющему фокус
  procedure onMouseMove; virtual;
  procedure onMouseScroll(value:integer); virtual;
  procedure onMouseButtons(button:byte;state:boolean); virtual;
  function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; virtual; // Нужно вернуть false для запрета дальнейшей обработки клавиши
  procedure onChar(ch:char;scancode:byte); virtual;
  procedure onUniChar(ch:WideChar;scancode:byte); virtual;
  procedure onHotKey(keycode:byte;shiftstate:byte); virtual;
  procedure onTimer; virtual;
  procedure onLostFocus; virtual;

  // Переключить фокус на себя (с уведомлением других)
  procedure SetFocus; virtual;
  // Сам элемент или воженный в него владеет фокусом?
  function HasFocus:boolean; virtual;
  // Перевести фокус на следующий/предыдущий эл-ты
  procedure SetFocusToNext;
  procedure SetFocusToPrev;

  // Set element position using new pivot point
  function SetPos(x,y:single;pivotPoint:TPoint2s):TUIElement; overload;
  function SetPos(x,y:single):TUIElement; overload;
  // Move by given screen pixels
  procedure MoveBy(dx,dy:single);
  // Set element position using new pivot point
  function SetAnchors(left,top,right,bottom:single):TUIElement;
  // Set all padding and resize client area
  function SetPaddings(padding:single):TUIElement; overload;
  function SetPaddings(left,top,right,bottom:single):TUIElement; overload;
  // Set same value for X/Y scale
  function SetScale(newScale:single):TUIElement;
  // Change element size and adjust children elements !!! new size IN PARENTs space!
  // Pass -1 to keep current value
  procedure Resize(newWidth,newHeight:single); virtual;
  // разместить элемент по центру клиентской области предка либо экрана (если предка нет)
  procedure Center;
  // Прикрепляет элемент к какой-либо части предка
  procedure Snap(snapTo:TSnapMode);
  // Скроллинг в указанную позицию (с обработкой подчиненных скроллбаров если они есть)
  procedure ScrollTo(newX,newY:integer); virtual;
  // Если данный элемент может обладать фокусом, но ни один другой не имеет фокуса - взять фокус на себя
  procedure CheckAndSetFocus;

  // Find a descendant UI element at the given point (in screen coordinates)
  // Returns true if the found element (and all its parents) are enabled
  function FindElementAt(x,y:integer;out c:TUIElement):boolean;
  // Same as FindItemAt, but ignores elements transparency mode
  function FindAnyElementAt(x,y:integer;out c:TUIElement):boolean;
  // Find a descendant element by its name
  function FindElementByName(name:string8):TUIElement;

  // Установить либо удалить "горячую клавишу" для данного эл-та
  procedure SetHotKey(vKeyCode:byte;shiftstate:byte);
  procedure ReleaseHotKey(vKeyCode:byte;shiftstate:byte);

  // Check if point is opaque in tmCustom mode (relative coordinates in [0..1] range)
  function IsOpaque(x,y:single):boolean; virtual;

  // Whether element behave as window: track focused child
  class function IsWindow:boolean; virtual;
  function IsActiveWindow:boolean; virtual;

  // Static method => nil-safe
  function GetName:string8;
  function GetFont:TFontHandle; // returns own or inherited font handle

 protected
  focusedChild:TUIElement; // child element which should get focus instead of self
 private
  fStyleInfo:String8; // дополнительные сведения для стиля
  fFont:TFontHandle; // not used directly, can be inherited by children or used by custom draw routines
  fInitialSize:TVector2s;
  procedure AddToRootElements;
  procedure RemoveFromRootElements;
  function GetClientWidth:single;
  function GetClientHeight:single;
  function GetGlobalScale:TVector2s;
  procedure SetName(n:String8); override;
  procedure SetStyleInfo(sInfo:String8);
  class function ClassHash:pointer; override;
 public
  property width:single read size.x write size.x;
  property height:single read size.y write size.y;
  property clientWidth:single read GetClientWidth;
  property clientHeight:single read GetClientHeight;
  property globalScale:TVector2s read GetGlobalScale; // element scale in screen pixels
  property initialSize:TVector2s read fInitialSize; // Size when created
  property styleInfo:String8 read fStyleInfo write SetStyleInfo;
  property font:TFontHandle read GetFont write fFont;
 end;

var
 underMouse:TUIElement;     // элемент под мышью
 modalElement:TUIElement;   // Если есть модальный эл-т - он тут
 hooked:TUIElement;         // если установлен - теряет фокус даже если не обладал им

 defaultEncoding:TTextEncoding=teUnknown; // кодировка элементов ввода по умолчанию

 clipMouse:TClipMouse;   // Ограничивать ли движение мыши
 clipMouseRect:TRect;    // Область допустимого перемещения мыши

 curMouseX,curMouseY,oldMouseX,oldMouseY:integer; // координаты курсора мыши (для onMouseMove!)

 // Корневые элементы (не имеющие предка)
 // Список используется для передачи (обработки) первичных событий строго
 // по порядку, начиная с 1-го
 rootElements:array of TUIElement;

 UICritSect:TMyCriticalSection; // для многопоточного доступа к глобальным переменным UI

 function DescribeElement(c:TUIElement):string;
 function FocusedElement:TUIElement;
 procedure SetFocusTo(control:TUIElement);

 // Keycode - virtual key
 procedure ProcessHotKey(keycode:integer;shiftstate:byte);
 // Destroy elements queued by SafeDestroy
 procedure DestroyQueuedElements;

implementation
 uses Classes, SysUtils, Apus.EventMan, Apus.Clipboard, Apus.Structs, Apus.Engine.API;

 type
  // Горячая клавиша
  THotKey=record
   vKey,shiftstate:byte;
   element:TUIElement;
  end;

 var
  // TUIElement class hash
  UIHash:TObjectHash;
  // Hotkeys
  hotKeys:array[0..1023] of THotKey;
  hotKeysCnt:integer;

  fControl:TUIElement; // элемент, имеющий фокус ввода (с клавиатуры)
                      // устанавливается автоматически либо вручную
  activeWnd:TUIElement;  // Активное окно (автоматически устанавливается при переводе фокуса)

  toDelete:TObjectList; // List of elements marked for deletion

 procedure ProcessHotKey(keycode:integer;shiftstate:byte);
  var
   i:integer;
   c,r:TUIElement;
  begin
   r:=modalElement;
   for i:=0 to hotKeysCnt-1 do
    if (hotKeys[i].vKey=keycode) then
      if (HotKeys[i].shiftstate=shiftstate) or
         ((HotKeys[i].shiftstate>0) and (HotKeys[i].shiftstate and ShiftState=HotKeys[i].shiftstate)) then
       begin
        c:=hotkeys[i].element;
        while (c<>r) and (c.parent<>nil) and c.enabled and c.visible do c:=c.parent;
        if c=r then hotkeys[i].element.onHotKey(keycode,shiftstate);
       end;
  end;

 function DescribeElement(c:TUIElement):string;
  begin
   if c=nil then begin
    result:='nil'; exit;
   end;
   result:=c.ClassName+'('+PtrToStr(c)+')='+c.name;
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

 function TUIElement.TransformTo(const p:TPoint2s;target:TUIElement):TPoint2s;
  var
   parentScrollX,parentScrollY:single;
   c:TUIElement;
  begin
   c:=self;
   result:=p;
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
     result.x:=position.x-parentScrollX-scale.x*(size.x*pivot.x-(result.x+paddingLeft));
     result.y:=position.y-parentScrollY-scale.y*(size.y*pivot.y-(result.y+paddingTop));
    end;
    c:=c.parent;
   until (c=nil) or (c=target);

  end;

 function TUIElement.TransformTo(const r:TRect2s;target:TUIElement):TRect2s;
  var
   p1,p2:TPoint2s;
  begin
   p1:=TransformTo(Point2s(r.x1,r.y1),target);
   p2:=TransformTo(Point2s(r.x2,r.y2),target);
   result:=Rect2s(p1.x,p1.y, p2.x,p2.y);
  end;

 function TUIElement.GetRect:TRect2s; // Get element's area in own CS
  begin
   result.x1:=-paddingLeft;
   result.y1:=-paddingTop;
   result.x2:=size.x-paddingLeft;
   result.y2:=size.y-paddingTop;
  end;

 function TUIElement.GetClientRect:TRect2s; // Get element's client area in own CS
  begin
   result.x1:=0;
   result.y1:=0;
   result.x2:=size.x-paddingLeft-paddingRight;
   result.y2:=size.y-paddingTop-paddingBottom;
  end;

 function TUIElement.GetRectInParentSpace:TRect2s; // Get element's area in parent client space)
  begin
   result:=TransformTo(GetRect,parent);
  end;

 procedure TUIElement.Center;
  var
   r,rP:TRect2s;
   pW,pH,dx,dy:single;
  begin
   r:=GetRect;
   ASSERT(parent<>nil,'Cannot center a root UI element');
   pW:=parent.size.x;
   pH:=parent.size.y;
   r:=TransformTo(r,parent);
   rP:=parent.GetClientRect;
   dx:=-((r.x1-rP.x1)-(rP.x2-r.x2))/2;
   dy:=-((r.y1-rP.y1)-(rP.y2-r.y2))/2;
   position.x:=position.x+dx;
   position.y:=position.y+dy;
  end;

  {procedure TUIControl.Scale(sX,sY:single);
  var
   c:TUIControl;
  begin
   if (x>0) or (y>0) or
      (width<rootWidth) or (height<rootHeight) then begin
    x:=round(x*sX);
    y:=round(y*sY);
    width:=round(width*sX);
    height:=round(height*sY);
   end;
   for c in children do
    c.Scale(sx,sy);
  end;}

 procedure TUIElement.CheckAndSetFocus;
  begin
   if CanHaveFocus and (FocusedElement=nil) then
    SetFocus;
  end;

 class function TUIElement.ClassHash:pointer;
  begin
   result:=@UIHash;
  end;

 procedure TUIElement.DeleteChildren;
  var
   i:integer;
  begin
   UICritSect.Enter;
   try
    for i:=0 to high(children) do
     FreeAndNil(children[i]);
    SetLength(children,0);
   finally
    UICritSect.Leave;
   end;
  end;

 constructor TUIElement.Create(width,height:single;parent_:TUIElement;name_:string='');
  var
   n:integer;
  begin
   position:=Point2s(0,0);
   size:=Point2s(width,height);
   fInitialSize:=size;
   scale:=Point2s(1,1);
   pivot:=Point2s(0,0);
   paddingLeft:=0; paddingRight:=0; paddingTop:=0; paddingBottom:=0;
   shape:=shapeEmpty;
   timer:=0;
   parent:=parent_;
   parentClip:=true;
   clipChildren:=true;
   name:=name_;
   hint:=''; hintIfDisabled:='';
   hintDelay:=1000;
   hintDuration:=3000;
   // No anchors: element's size doesn't change when parent is resized
   anchorLeft:=0;
   anchorTop:=0;
   anchorRight:=0;
   anchorBottom:=0;
   cursor:=crDefault;
   enabled:=true;
   visible:=true;
   manualDraw:=false;
   if parent<>nil then begin
    n:=length(parent.children);
    inc(n); order:=n;
    SetLength(parent.children,n);
    parent.children[n-1]:=self;
   end else begin
    // Элемент без предка -> занести в список
    AddToRootElements;
    order:=1;
   end;
   style:=0;
   CanHaveFocus:=false;
   sendSignals:=ssNone;
   scroll:=Point2s(0,0);
   scrollerH:=nil; scrollerV:=nil;
   globalRect:=GetPosOnScreen;
   focusedChild:=nil;
   shapeRegion:=nil;
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
    if parent=nil then
     RemoveFromRootElements
    else
     Detach(false);
    DeleteChildren;
    FreeAndNil(shapeRegion);
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
   if shouldAddToRootControls then AddToRootElements;
  end;

 procedure TUIElement.AttachTo(newParent:TUIElement);
  var
   n:integer;
  begin
   ASSERT(newParent<>nil);
   if parent=newParent then exit;
   if parent<>nil then Detach(false)
    else RemoveFromRootElements;
   parent:=newParent;
   n:=length(parent.children);
   {if n>0 then order:=parent.children[n-1].order+1
    else order:=1;}
   SetLength(parent.children,n+1);
   parent.children[n]:=self;
  end;

 function TUIElement.FindElementByName(name:string8):TUIElement;
  var
   i:integer;
   c:TUIElement;
  begin
   name:=UpperCase(name);
   if UpperCase(self.name)=name then begin
    result:=self; exit;
   end;
   for i:=0 to length(children)-1 do begin
    c:=children[i].FindElementByName(name);
    if c<>nil then begin
     result:=c; exit;
    end;
   end;
   result:=nil;
  end;

 function TUIElement.FindElementAt(x,y:integer; out c:TUIElement):boolean;
  var
   r,r2:Trect;
   p:TPoint;
   i,j:integer;
   fl,en:boolean;
   c2:TUIElement;
   ca:array of TUIElement;
   cnt:byte;
  begin
   // Тут нужно быть предельно внимательным!!!
   result:=enabled and visible;
   c:=nil;
   if not visible then exit; // если элемент невидим, то уж точно ничего не спасет!
   r:=GetPosOnScreen;
   p:=Point(x,y);
   if not r.Contains(p) then begin result:=false; exit; end; // за пределами эл-та
   if shape=shapeFull then c:=self;

   // На данный момент известно, что точка в пределах текущего эл-та
   // Но возможно здесь есть кто-то из вложенных эл-тов! Нужно их проверить:
   // выполнить поиск по ним в порядке обратном отрисовке.
   // В невидимых и запредельных искать ессно не нужно, а вот в прозрачных - нужно!
   cnt:=0;
   SetLength(ca,length(children));
   for i:=0 to length(children)-1 do with children[i] do begin
    if not visible then continue;
    ca[cnt]:=self.children[i];
    inc(cnt);
   end;
   // Список создан, теперь его отсортируем
   if cnt>1 then
    for i:=0 to cnt-2 do
     for j:=cnt-1 downto i+1 do
      if ca[j-1].order<ca[j].order then begin
       c2:=ca[j]; ca[j]:=ca[j-1]; ca[j-1]:=c2;
      end;
   // Теперь порядок правильный, нужно искать
   fl:=false;
   for i:=0 to cnt-1 do begin
    en:=ca[i].FindElementAt(x,y,c2);
    if c2<>nil then begin
     c:=c2; result:=result and en;
     fl:=true; break;
    end;
   end;

   // Ни одного непрозрачного потомка в данной точке, но сам элемент может быть непрозрачен здесь!
   if not fl and (shape=shapeCustom) then
    if IsOpaque((x-r.Left)/r.Width,(y-r.Top)/r.Height) then c:=self;

   if c=nil then result:=false;
  end;

 function TUIElement.FindAnyElementAt(x,y:integer; out c:TUIElement):boolean;
  var
   r,r2:Trect;
   p:TPoint;
   i,j:integer;
   fl,en:boolean;
   c2:TUIElement;
   ca:array of TUIElement;
   cnt:byte;
  begin
   // Тут нужно быть предельно внимательным!!!
   result:=enabled and visible;
   c:=nil;
   if not visible then exit; // если элемент невидим, то уж точно ничего не спасет!
   r:=GetPosOnScreen;
   p:=Point(x,y);
   if not PtInRect(r,p) then begin result:=false; exit; end; // за пределами эл-та
   c:=self;

   // На данный момент известно, что точка в пределах текущего эл-та
   // Но возможно здесь есть кто-то из вложенных эл-тов! Нужно их проверить:
   // выполнить поиск по ним в порядке обратном отрисовке.
   // В невидимых и запредельных искать ессно не нужно, а вот в прозрачных - нужно!
   cnt:=0;
   SetLength(ca,length(children));
   for i:=0 to length(children)-1 do with children[i] do begin
    if not visible then continue;
    ca[cnt]:=self.children[i];
    inc(cnt);
   end;
   // Список создан, теперь его отсортируем
   if cnt>1 then
    for i:=0 to cnt-2 do
     for j:=cnt-1 downto i+1 do
      if ca[j-1].order<ca[j].order then begin
       c2:=ca[j]; ca[j]:=ca[j-1]; ca[j-1]:=c2;
      end;
   // Теперь порядок правильный, нужно искать
   fl:=false;
   for i:=0 to cnt-1 do begin
    en:=ca[i].FindElementAt(x,y,c2);
    if c2<>nil then begin
     c:=c2; result:=result and en;
     fl:=true; break;
    end;
   end;

   // Ни одного непрозрачного потомка в данной точке, но сам элемент может быть непрозрачен здесь!
   if not fl then c:=self;

   if c=nil then result:=false;
  end;

 function TUIElement.GetName:string8;
  begin
   if self<>nil then result:=name
    else result:='empty';
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

 procedure TUIElement.Snap(snapTo:TSnapMode);
  var
   clientW,clientH:single;
   r,parentRect:TRect2s;
   dx,dy:single;
   offset:TVector2s;
  begin
   if parent=nil then exit;
   if snapTo=smNone then exit;
   parentRect:=parent.GetClientRect;
   clientW:=parentRect.x2-parentRect.x1;
   clientH:=parentRect.y2-parentRect.y1;
   if snapTo in [smTop,smBottom] then Resize(clientW,-1);
   if snapTo in [smLeft,smRight] then Resize(-1,clientH);
   if snapTo=smParent then Resize(clientW,clientH);
   r:=TransformTo(GetRect,parent);
   case snapTo of
    smTop:begin
      anchorTop:=0; anchorLeft:=0; anchorRight:=1; anchorBottom:=0;
    end;
    smLeft:begin
      anchorTop:=0; anchorLeft:=0; anchorRight:=0; anchorBottom:=1;
    end;
    smRight:begin
      anchorTop:=0; anchorLeft:=1; anchorRight:=1; anchorBottom:=1;
    end;
    smBottom:begin
      anchorTop:=1; anchorLeft:=0; anchorRight:=1; anchorBottom:=1;
    end;
    smParent:begin
      anchorTop:=0; anchorLeft:=0; anchorRight:=1; anchorBottom:=1;
    end;
   end;
   if snapTo in [smTop,smLeft,smParent] then begin
    // Make upper-left corner match parent's same corner
    offset.x:=r.x1-parentRect.x1;
    offset.y:=r.y1-parentRect.y1;
   end else begin
    // Make bottom-right corner match parent's same corner
    offset.x:=parentRect.x2-r.x2;
    offset.y:=parentRect.y2-r.y2;
   end;
   VectAdd(position,offset);
  end;

 function TUIElement.GetNext:TUIElement;
  var
   i,n:integer;
  begin
   if parent=nil then begin result:=self; exit; end;
   result:=nil;
   n:=length(parent.children);
   for i:=0 to n-1 do
    if parent.children[i]=self then
     result:=parent.children[(i+1) mod n];
  end;

 function TUIElement.GetRoot:TUIElement;
  begin
   result:=self;
   if self=nil then exit;
   while result.parent<>nil do result:=result.parent;
  end;

 function TUIElement.IsVisible:boolean;
  var
   c:TUIElement;
  begin
   result:=false;
   if self=nil then exit;
   result:=visible;
   c:=self;
   while c.parent<>nil do begin
    c:=c.parent;
    result:=result and c.visible;
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
   result:=enabled;
   c:=self;
   while c.parent<>nil do begin
    c:=c.parent;
    result:=result and c.enabled;
   end;
  end;

 function TUIElement.IsActiveWindow: boolean;
  begin
   result:=activeWnd=self;
  end;

function TUIElement.IsChild(c:TUIElement):boolean;
  begin
   result:=false;
   if c=nil then exit;
   while c<>nil do begin
    c:=c.parent;
    if c=self then begin
     result:=true; exit;
    end;
   end;
  end;

 function TUIElement.TransformToScreen(const p:TPoint2s):TPoint2s;
  begin
   result:=TransformTo(p,nil);
  end;

 function TUIElement.TransformToScreen(const r:TRect2s):TRect2s;
  begin
   result:=TransformTo(r,nil);
  end;

 function TUIElement.GetPosOnScreen:TRect;
  begin
   globalRect:=RoundRect(TransformToScreen(GetRect));
   result:=globalRect;
  end;

 function TUIElement.GetClientPosOnScreen:TRect;
  begin
   result:=RoundRect(TransformToScreen(GetClientRect));
  end;

 function TUIElement.GetPrev:TUIElement;
  var
   i,n:integer;
  begin
   if parent=nil then begin result:=self; exit; end;
   result:=nil;
   n:=length(parent.children);
   for i:=0 to n-1 do
    if parent.children[i]=self then
     if i=0 then result:=parent.children[n-1]
      else result:=parent.children[i-1];
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
   con:=self;
   result:=false;
   while con<>nil do begin
    if con=c then begin
     result:=true; exit;
    end;
    con:=con.parent;
   end;
  end;

 function TUIElement.HasChild(c:TUIElement):boolean;
  begin
   result:=c.HasParent(self);
  end;

 function TUIElement.IsOpaque(x,y:single):boolean;
  begin
   result:=false;
   if shapeRegion<>nil then
    result:=shapeRegion.TestPoint(x,y);
  end;

 procedure TUIElement.onChar(ch:char; scancode:byte);
  begin
   if (sendSignals=ssAll) and (name<>'') then begin
    Signal('UI\'+name+'\Char',byte(ch)+scancode shl 8);
   end;
  end;

 procedure TUIElement.onUniChar(ch:WideChar; scancode:byte);
  begin
   if (sendSignals=ssAll) and (name<>'') then begin
    Signal('UI\'+name+'\UniChar',word(ch)+scancode shl 16);
   end;
  end;

 procedure TUIElement.onHotKey(keycode,shiftstate:byte);
  begin

  end;

 function TUIElement.onKey(keycode:byte; pressed:boolean;shiftstate:byte):boolean;
  begin
   if pressed and (keycode=VK_TAB) then begin
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
    if enabled and CanHaveFocus then SetFocus
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
   if (sendSignals=ssAll) and (name<>'') then begin
    Signal('UI\'+name+'\MouseScroll',value);
   end;
   // Если прикреплен вертикальный скроллбар - использовать его для прокрутки
   if scrollerV<>nil then begin
    scrollerV.MoveRel(-scrollerV.GetStep*value/100,true);
    onMouseMove;
    exit;
   end;
   if parent<>nil then
    parent.onMouseScroll(value);
  end;

 procedure TUIElement.ReleaseHotKey(vKeyCode, shiftstate: byte);
  var
   i:integer;
  begin
   if hotkeyscnt<=0 then exit;
   for i:=0 to hotKeysCnt-1 do
    if (hotkeys[i].element=self) and
     ((vKeyCode=0) or
      ((hotkeys[i].vKey=vKeyCode) and
      (hotkeys[i].shiftstate=shiftstate))) then begin
     dec(hotKeysCnt);
     hotkeys[i]:=hotkeys[hotKeysCnt];
     exit;
    end;
  end;

 procedure TUIElement.AddToRootElements;
  begin
   UICritSect.Enter;
   try
    SetLength(rootElements,length(rootElements)+1);
    rootElements[high(rootElements)]:=self;
   finally
    UICritSect.Leave;
   end;
  end;

 procedure TUIElement.RemoveFromRootElements;
  var
   i,pos:integer;
  begin
   UICritSect.Enter;
   try
   i:=0; pos:=-1;
   // Order should be kept!
   for i:=0 to high(rootElements) do
    if self=rootElements[i] then begin
     pos:=i; break;
    end;
   if pos<0 then exit;
   for i:=pos+1 to high(rootElements) do
    rootElements[i-1]:=rootElements[i];
   SetLength(rootElements,length(rootElements)-1);
   finally
    UICritSect.Leave;
   end;
  end;

 function TUIElement.GetClientWidth:single;
  begin
   result:=size.x-paddingLeft-paddingRight;
  end;

 function TUIElement.GetFont:TFontHandle;
  var
   item:TUIElement;
  begin
   if self=nil then exit(0);
   result:=fFont;
   item:=parent;
   while (result=0) and (item<>nil) do begin
    result:=item.fFont;
    item:=item.parent;
   end;
  end;

 function TUIElement.GetClientHeight:single;
  begin
   result:=size.y-paddingTop-paddingBottom;
  end;

 function TUIElement.GetGlobalScale:TVector2s;
  var
   c:TUIElement;
  begin
   result:=scale;
   c:=parent;
   while c<>nil do begin
    result.x:=result.x*c.scale.x;
    result.y:=result.y*c.scale.y;
    c:=c.parent;
   end;
  end;

 function TUIElement.SetPos(x,y:single;pivotPoint:TPoint2s):TUIElement;
  begin
   position:=Point2s(x,y);
   pivot:=pivotPoint;
   globalRect:=GetPosOnScreen;
   result:=self;
  end;

 function TUIElement.SetPos(x,y:single):TUIElement;
  begin
   result:=SetPos(x,y,pivotTopLeft);
  end;

 procedure TUIElement.MoveBy(dx,dy:single);
  var
   delta:TVector2s;
  begin
   delta:=globalScale;
   VectInv(delta);
   delta:=VectMult(Point2s(dx,dy),delta);
   VectAdd(position,delta);
  end;

 function TUIElement.SetAnchors(left,top,right,bottom:single):TUIElement;
  begin
   anchorLeft:=left;
   anchorTop:=top;
   anchorBottom:=bottom;
   anchorRight:=right;
   result:=self;
  end;

 function TUIElement.SetPaddings(left,top,right,bottom:single):TUIElement;
  begin
   paddingLeft:=left;
   paddingTop:=top;
   paddingRight:=right;
   paddingBottom:=bottom;
   Resize(size.x,size.y);
   result:=self;
  end;

 function TUIElement.SetPaddings(padding:single):TUIElement;
  begin
   result:=SetPaddings(padding,padding,padding,padding);
  end;

 function TUIElement.SetScale(newScale:single):TUIElement;
  begin
   scale.x:=newScale;
   scale.y:=newScale;
   result:=self;
  end;

 procedure TUIElement.SetStyleInfo(sInfo:String8);
  begin
   if fStyleInfo<>sInfo then begin
    fStyleInfo:=sInfo;
    styleInfoChanged:=true;
   end;
  end;

 procedure TUIElement.Resize(newWidth,newHeight:single);
  var
   i:integer;
   childRect:TRect2s;
   dW,dH:single;
  begin
   if newWidth>-1 then dW:=newwidth-size.x else dW:=0;
   if newHeight>-1 then dH:=newHeight-size.y else dH:=0;
   VectAdd(size,Point2s(dW,dH));
   for i:=0 to length(children)-1 do with children[i] do begin
    Resize(size.x+dW*(anchorRight-anchorLeft),size.y+dH*(anchorBottom-anchorTop));
    childRect:=TransformTo(GetRect(),parent);
    childRect.x1:=childRect.x1+dW*anchorLeft;
    childRect.y1:=childRect.y1+dH*anchorTop;
    childRect.x2:=childRect.x2+dW*anchorRight;
    childRect.y2:=childRect.y2+dH*anchorBottom;
    position.x:=childRect.x1*(1-pivot.x)+childRect.x2*pivot.x;
    position.y:=childRect.y1*(1-pivot.y)+childRect.y2*pivot.y;
   end;
   if scrollerH<>nil then scrollerH.SetPageSize(clientWidth);
   if scrollerV<>nil then scrollerV.SetPageSize(clientHeight);
  end;

 procedure TUIElement.SafeDestroy;
  begin
   toDelete.Add(self,true);
  end;

 procedure TUIElement.ScrollTo(newX,newY:integer);
  begin
   scroll.X:=newX; scroll.Y:=newY;
   if scrollerH<>nil then
    scrollerH.SetValue(scroll.X);
   if scrollerV<>nil then
    scrollerV.SetValue(scroll.Y);
  end;

 procedure TUIElement.SetFocus;
  var
   c:TUIElement;
   i:integer;
  begin
   if not (enabled and visible) then exit;
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
       if children[i].canHaveFocus then begin
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
   until (c.enabled and c.visible and c.canHaveFocus) or (c=self);
   if c.canHaveFocus then c.SetFocus;
  end;

 procedure TUIElement.SetFocusToPrev;
  begin
  end;

 procedure TUIElement.SetHotKey(vKeyCode,shiftstate:byte);
  var
   i:integer;
  begin
   if hotKeysCnt>=high(hotKeys) then exit;
   // Поиск, а не установлена ли уже эта клавиша
   for i:=0 to HotKeysCnt-1 do
    if (hotkeys[i].element=self) and (hotkeys[i].vKey=vKeyCode) and
       (hotkeys[i].shiftstate=shiftstate) then exit;
   hotkeys[hotKeysCnt].vKey:=vKeyCode;
   hotkeys[hotKeysCnt].shiftstate:=shiftstate;
   hotkeys[hotKeysCnt].element:=self;
   inc(HotKeysCnt);
  end;

 { TRowLayout }

 constructor TRowLayout.Create(horizontal:boolean;spaceBetween:single;
    resizeToContent,center:boolean);
  begin
   fHorizontal:=horizontal;
   fSpaceBetween:=spaceBetween;
   fResize:=resizeToContent;
   fCenter:=center;
  end;

 procedure TRowLayout.Layout(item:TUIElement);
  var
   i:integer;
   pos:single;
   r:TRect2s;
   delta:TVector2s;
   c:TUIElement;
  begin
   pos:=0;
   for i:=0 to high(item.children) do begin
    c:=item.children[i];
    if not c.visible then continue;
    r:=c.TransformTo(c.GetRect,item);
    if fHorizontal then begin
     delta.x:=pos-r.x1;
     pos:=pos+r.width+fSpaceBetween;
     if fCenter then delta.y:=((item.clientHeight-r.y2)-r.y1)/2
      else delta.y:=0;
    end else begin
     delta.y:=pos-r.y1;
     pos:=pos+r.height+fSpaceBetween;
     if fCenter then delta.x:=((item.clientWidth-r.x2)-r.x1)/2
      else delta.x:=0;
    end;
    VectAdd(c.position,delta);
   end;
   if fResize then begin
    if fHorizontal then item.size.x:=pos-fSpaceBetween+item.paddingLeft+item.paddingRight
     else item.size.y:=pos-fSpaceBetween+item.paddingTop+item.paddingBottom;
   end;
  end;

 procedure DestroyQueuedElements;
  begin
    UICritSect.Enter;
    try
     toDelete.FreeAll;
    finally
     UICritSect.Leave;
    end;
  end;

initialization
 InitCritSect(UICritSect,'UI',30);
 UIHash.Init;
 TUIElement.SetClassAttribute('handleMouseIfDisabled',false);

finalization
 DeleteCritSect(UICritSect);
end.