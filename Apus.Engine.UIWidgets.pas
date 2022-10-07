// -----------------------------------------------------
// Standard widget classes
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------
unit Apus.Engine.UIWidgets;
interface
 uses Types, Apus.Common, Apus.AnimatedValues,
   Apus.Engine.API, Apus.Engine.UITypes;

 {$WRITEABLECONST ON}
 {$IFDEF CPUARM} {$R-} {$ENDIF}

 const
  // Константы окна (дефолтное поведение, можно менять)
  wcFrameBorder:integer=5;   // Ширина рамки окна
  wcTitleHeight:integer=24;  // Высота заголовка окна

  // Window area flags
  wcLeftFrame   =  1;
  wcTopFrame    =  2;
  wcRightFrame  =  4;
  wcBottomFrame =  8;
  wcHeader      = 16; // area that can be used to drag and move the window
  wcClient      = 32; // client part of the window

 type
  // Элемент с ограничениями размера
  TUIFlexControl=class(TUIElement)
   minWidth,minHeight:integer;
   maxWidth,maxHeight:integer;
  end;

  TUISplitter=class(TUIElement)
   canResize:boolean; // true - allow resizing neighbour elements
   constructor CreateH(height:single;parent:TUIElement;color:cardinal=0); overload;
   constructor CreateH(innerHeight,marginH,marginV:single;parent:TUIElement;color:cardinal=0); overload;
   constructor CreateV(width:single;parent:TUIElement;color:cardinal=0); overload;
   constructor CreateV(innerWidth,marginH,marginV:single;parent:TUIElement;color:cardinal=0); overload;
  end;

  // Элемент "изображение". Содержит простое статическое изображение
  TUIImage=class(TUIElement)
   src:string; // здесь может быть имя файла или строка "event:xxx", "proc:XXXXXXXX" etc...
   constructor Create(width,height:single;imgname:string;parent_:TUIElement;source:string='');
   procedure SetRenderProc(proc:pointer); // sugar for use "proc:XXX" src for the default style
  end;

  // Скроллер для тачскрина - размещается независимо либо поверх другого элемента, который он и скроллит
  // It captures mouse drag events, but passes clicks through
  TUIScrollArea=class(TUIElement)
   fullWidth,fullHeight:single; // full content area
   direction:TUIScrollDirection;
   constructor Create(width,height,fullW,fullH:single;dir:TUIScrollDirection;parent_:TUIElement);
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  protected
   speedX,speedY:single;
   lastTime:cardinal;
   isHooked:boolean;
  end;

  // Окошко хинта
  // обычно создается незаполненным или неполностью заполненным,
  // создающий код либо отрисовщик могут дополнить или использовать значения по умолчанию
  TUIHint=class(TUIImage)
   simpleText:string; // текст надписи
   active:boolean; // если true - значит хинт активный, не кэшируется и содержит вложенные эл-ты
   created:int64; // момент создания (в мс.)
   adjusted:boolean; // отрисовщик может использовать это для корректировки параметров хинта
   hiding:boolean; // hint is currently hiding

   constructor Create(x,y:single;text:string;parent_:TUIElement);
   destructor Destroy; override;
   procedure Hide;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override;
  end;

  TUILabel=class(TUIElement)
   caption:string; // text to draw inside the client area
   align:TTextAlignment;
   autoSize:boolean; // render should adjust element size to match caption
   verticalOffset:integer; // сдвиг текста вверх
   constructor Create(width,height:single;labelname,text:string;color_:cardinal;bFont:TFontHandle;parent_:TUIElement); overload;
   constructor Create(width,height:single;labelname,text:string;parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault); overload;
   constructor CreateCentered(width,height:single;labelname,text:string;parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault);
   constructor CreateRight(width,height:single;labelname,text:string;parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault);
   procedure CaptionWidthIs(width:single);
  end;

  // Тип кнопок
  TButtonStyle=(bsNormal,   // обычная кнопка
                bsSwitch,   // кнопка-переключатель (фиксирующаяся в нажатом положении)
                bsCheckbox);    // кнопка-надпись (чекбокс)
  TUIButton=class(TUIImage)
   caption:string; // button's label
   default:boolean; // кнопка по умолчанию (влияет только на отрисовку, но не на поведение!!!)
   pressed:boolean; // кнопка вдавлена
   pending:boolean; // состояние временной недоступности (не реагирует на нажатия)
   autoPendingTime:integer; // время (в мс) на которое кнопка переводится в состояние pending при нажатии (0 - не переводится)

   btnStyle:TButtonStyle; // тип кнопки (влияет как на отрисовку, так и на поведение)
   group:integer;   // Группа переключателей
   onClick:TProcedure;
   constructor Create(width,height:single;btnName,btnCaption:string;btnFont:TFontHandle;parent_:TUIElement); overload;
   constructor Create(width,height:single;btnName,btnCaption:string;parent_:TUIElement); overload;
   constructor CreateSwitch(width,height:single;btnName,btnCaption:string;group:integer;
     btnFont:TFontHandle;parent_:TUIElement;pressed:boolean=false); overload;
   constructor CreateSwitch(width,height:single;btnName,btnCaption:string;
     parent_:TUIElement;pressed:boolean=false); overload;

   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure onTimer; override; // отжимает кнопку по таймеру
   procedure SetPressed(pr:boolean); virtual;
   procedure MakeSwitches(sameGroup:boolean=true;clickHandler:TProcedure=nil); // make all sibling buttons with the same size - switches
   procedure Click; virtual; // simulate click
   class var active:TUIButton; // link to the active button (can be used in click handlers)
  protected
   procedure DoClick;
  private
   lastPressed,pendingUntil:int64;
   lastOver:boolean; // was under mouse when onMouseMove was called last time
  end;

  TUICheckBox=class(TUIButton)
   checked:boolean;
   constructor Create(width,height:single;btnName,caption:string;parent_:TUIElement;
    checked:boolean=false;btnFont:TFontHandle=0); overload;
  end;

  TUIRadioButton=class(TUICheckbox)
   constructor Create(width,height:single;btnName,caption:string;
     parent_:TUIElement;checked:boolean=false;btnFont:TFontHandle=0); overload;
  end;

  // Рамка
  TUIFrame=class(TUIElement)
   constructor Create(width,height:single;depth,style_:integer;parent_:TUIElement);
   procedure SetBorderWidth(w:integer); virtual;
  protected
   borderWidth:integer; // ширина рамки
  end;

  // Basic window
  TUIWindow=class(TUIImage)
   caption:string;
   header:integer; // Высота заголовка
   autoBringToFront:boolean; // автоматически переносить окно на передний план при клике по нему или любому вложенному эл-ту
   moveable:boolean;    // окно можно перемещать
   resizeable:boolean;  // окно можно растягивать
   minW,minH,maxW,maxH:integer; // максимальные и минимальные размеры (для растягивающихся окон)

   constructor Create(innerWidth,innerHeight:single;sizeable:boolean;wndName,wndCaption:string;wndFont:TFontHandle;parent_:TUIElement);

   // Возвращает флаги типа области в указанной точке (к-ты экранные (в пикселях)
   // а также курсор, который нужно заюзать для этой области
   // Эту ф-цию нужно переопределить для создания окон специальной формы или поведения
   function GetAreaType(x,y:integer;out cur:NativeInt):integer; virtual;

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   procedure Resize(newWidth,newHeight:single); override;
   class function IsWindow:boolean; override;
  private
   hooked:boolean;
   area:integer;   // тип области под курсором
  end;

  // Разновидность окна: окно со скином
  // ключевые особенности: имеет фиксированный размер и зачастую непрямоугольную форму,
  // а также фон в виде картинки
  // такое окно создается с дефолтными параметрами и должно далее настраиваться извне
  TUISkinnedWindow=class(TUIWindow)
   dragRegion:TRegion; // область, за которую можно таскать окно (если не задана - то за любую точку)
   background:pointer; // некий указатель на фон окна (т.к. вопросы отрисовки в этом модуле не затрагиваются)
   constructor Create(wndName,wndCaption:string;wndFont:TFontHandle;parent_:TUIElement;canmove:boolean=true);
   destructor Destroy; override;
   function GetAreaType(x,y:integer;out cur:NativeInt):integer; override; // x,y - screen space coordinates
  end;

  TUIEditBox=class(TUIElement)
   realText:WideString; // реальный текст (лучше использовать это поле, а не text)
   completion:WideString; // grayed background text, if it is not empty and enter is pressed, then it is set to realText
   defaultText:WideString; // grayed background text, displayed if realText is empty
   backgnd:cardinal;  // deprecated, use styles instead
   cursorpos:integer;      // Положение курсора (номер символа, после которого находится курсор)
   maxlength:integer;      // максимальная длина редактируемой строки
   password:boolean;    // поле для ввода пароля
   noborder:boolean;    // рисовать ли рамку или только редактируемый текст (для встраивания в другие эл-ты)
   selstart,selcount:integer; // выделенный фрагмент текста
   cursortimer:int64;    // Начальный таймер для отрисовки курсора
   needpos:integer;    // желаемое положение курсора в пикселях (для отрисовщика)
   msselect:boolean;  // Выделение мышью
   protection:byte;   // xor всех символов с этим числом
   offset:integer; // сдвиг вправо содержимого на столько пикселей

   constructor Create(width,height:single;boxName:string;boxFont:TFontHandle;color_:cardinal;parent_:TUIElement);
   procedure onChar(ch:char;scancode:byte); override;
   procedure onUniChar(ch:WideChar;scancode:byte); override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onMouseMove; override;

   procedure SetFocus; override;
   procedure onLostFocus; override;
   procedure SelectAll; virtual;
  private
   savedText:WideString;
   lastClickTime:int64;
   msSelStart:integer; // после символа с этим номером находится точка начала выделения мышью
   procedure AdjustState;
   function GetText:String8;
   procedure SetText(s:String8);
  public
   property text:String8 read GetText write SetText;         // Редактируемый текст (в заданной кодировке)
  end;

  // Полоса прокрутки
  TUIScrollBar=class(TUIElement)
  private
   rValue:TAnimatedValue;
   sliderRect:TRect;
   function GetValue:single;
   procedure SetValue(v:single);
   function GetAnimating:boolean;
   procedure SetPageSize(pageSize:single);
   function GetStep:single;
  public
   horizontal:boolean; // orientation
   isInteger:boolean; // should value be always integer
   min,max:single; // range
   pagesize:single; // slider size (within range)
   step:single; // add/subtract this amount with mouse scroll or similar events
   minSliderSize:integer; // minimal slider size in pixels
   sliderUnder:boolean; // mouse is over slider
   sliderStart,sliderEnd:single; // relative position of slider (in 0..size.x/y range)
   constructor Create(width,height:single;barName:string;parent_:TUIElement);
   function GetScroller:IScroller;
   function SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
   // Переместить ползунок в указанную позицию
   procedure MoveTo(val:single;smooth:boolean=false); virtual;
   procedure MoveRel(delta:single;smooth:boolean=false); virtual;
   // Связать значение с внешней переменной
   procedure Link(elem:TUIElement); virtual;
   // Сигналы от этих кнопок будут использоваться для перемещения ползунка
   procedure UseButtons(lessBtn,moreBtn:string);
   procedure CalcSliderPos;

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   property value:single read GetValue write SetValue;
   property isAnimating:boolean read GetAnimating;
  protected
   linkedControl:TUIElement;
   delta:integer; // смещение точки курсора относительно точки начала ползунка (если hooked)
   moving:boolean;
   scroller:TObject;
  end;

  TUIListBox=class(TUIElement)
   lines:StringArr;
   tags:array of cardinal;
   hints:StringArr; // у каждого элемента может быть свой хинт (показываемый при наведении на него)
   lineHeight:single; // in self CS
   selectedLine,hoverLine:integer; // выделенная строка, строка под мышью (0..count-1), -1 == отсутствует
   autoSelectMode:boolean; // режим, при котором всегда выделяется строка под мышью (для попапов)
   bgColor,bgHoverColor,bgSelColor,textColor,hoverTextColor,selTextColor:cardinal; // цвета отрисовки
   constructor Create(width,height:single;lHeight:single;listName:string;font_:TFontHandle;parent:TUIElement);
   destructor Destroy; override;
   procedure AddLine(line:string;tag:cardinal=0;hint:string=''); virtual;
   procedure SetLine(index:integer;line:string;tag:cardinal=0;hint:string=''); virtual;
   procedure ClearLines;
   procedure SetLines(newLines:StringArr); virtual;
   procedure SelectLine(line:integer); virtual;
   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure UpdateScroller;
  end;

  // Выпадающий список
  TUIComboBox=class(TUIButton)
   items,hints:WStringArr;
   tags:IntArray;
   defaultText:WideString;
   fCurItem,fCurTag:integer;
   // pop up elements
   frame:TUIFrame;
   popup:TUIListBox;
   maxlines:integer; // max lines to show without scrolling
   constructor Create(width,height:single;bFont:TFontHandle;list:WStringArr;parent_:TUIElement;name:string);
   procedure AddItem(item:WideString;tag:cardinal=0;hint:WideString=''); virtual;
   procedure SetItem(index:integer;item:WideString;tag:cardinal=0;hint:string=''); virtual;
   procedure ClearItems;
   procedure onDropDown; virtual;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onTimer; override; // трюк: используется для слежения за всплывающим списком, чтобы не заморачиваться с сигналами
   procedure SetCurItem(item:integer); virtual;
   procedure SetCurItemByTag(tag:integer); virtual;
   property curItem:integer read fCurItem write SetCurItem;
   property curTag:integer read fCurTag write SetCurItemByTag;
  end;

implementation
 uses SysUtils, Apus.Types, Apus.CrossPlatform, Apus.EventMan, Apus.Geom2D, Apus.Clipboard;

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

 constructor TUISplitter.CreateH(innerHeight,marginH,marginV:single;parent:TUIElement;color:cardinal);
  begin
   inherited Create(-1,innerHeight+marginV*2,parent);
   SetPaddings(marginH,marginV,marginH,marginV);
   if color<>0 then
    styleInfo:='inner-fill:#'+IntToHex(color,8);
  end;

 constructor TUISplitter.CreateH(height:single;parent:TUIElement;color:cardinal);
  begin
   CreateH(height,0,0,parent,color);
  end;

 constructor TUISplitter.CreateV(innerWidth,marginH,marginV:single;parent:TUIElement;color:cardinal);
  begin
   inherited Create(innerWidth+marginH*2,-1,parent);
   SetPaddings(marginH,marginV,marginH,marginV);
   if color<>0 then
    styleInfo:='inner-fill:#'+IntToHex(color,8);
  end;

 constructor TUISplitter.CreateV(width:single;parent:TUIElement;color:cardinal);
  begin
   CreateV(width,0,0,parent,color);
  end;

 { TUIimage }

 constructor TUIimage.Create(width,height:single;imgname:string;parent_:TUIElement;source:string='');
  begin
   inherited Create(width,height,parent_,imgName);
   src:=source;
   shape:=shapeEmpty;
  end;

 procedure TUIImage.SetRenderProc(proc:pointer);
  begin
   style:=0;
   src:='proc:'+FormatHex(UIntPtr(proc));
  end;

 { TUIButton }

 procedure TUIButton.Click;
  begin
   onMouseButtons(1,true);
   onMouseButtons(1,false);
  end;

 constructor TUIButton.Create(width,height:single;btnName,btnCaption:string;btnFont:TFontHandle;parent_:TUIElement);
  var
   i:integer;
  begin
   inherited Create(width,height,btnName,parent_);
   shape:=shapeFull;
   font:=BtnFont;
   btnStyle:=bsNormal;
   group:=0;
   caption:=BtnCaption;
   default:=true; // make it default unless there is another sibling button
   if parent<>nil then
    if parent.children<>nil then
     for i:=0 to high(parent.children) do
      if parent.children[i] is TUIButton then
       default:=false;
   pressed:=false;
   pending:=false;
   autoPendingTime:=0;
   CanHaveFocus:=false;
   sendSignals:=ssMajor;
   //CheckAndSetFocus;
   lastPressed:=0;
  end;

 // Without font
 constructor TUIButton.Create(width,height:single;btnName,btnCaption:string; parent_:TUIElement);
  begin
   Create(width,height,btnName,btnCaption,0,parent_);
  end;

 constructor TUIButton.CreateSwitch(width,height:single;btnName,btnCaption:string;
    group:integer;btnFont:TFontHandle;parent_:TUIElement;pressed:boolean=false);
  begin
   Create(width,height,btnName,btnCaption,btnFont,parent_);
   btnStyle:=bsSwitch;
   self.group:=group;
   self.pressed:=pressed;
  end;

 constructor TUIButton.CreateSwitch(width,height:single;btnName,btnCaption:string;
    parent_:TUIElement;pressed:boolean=false);
  begin
   Create(width,height,btnName,btnCaption,0,parent_);
   btnStyle:=bsSwitch;
   self.pressed:=pressed;
  end;

procedure TUIButton.DoClick;
  var
   i:integer;
  begin
   // Toggle switch button
   active:=self;
   if btnStyle<>bsNormal then begin
    if group=0 then SetPressed(not pressed)
     else begin
      ASSERT(parent<>nil);
      for i:=0 to length(parent.children)-1 do
       if (parent.children[i] is TUIButton) and ((parent.children[i] as TUIButton).group=group) then
        (parent.children[i] as TUIButton).SetPressed(false);
      SetPressed(true);
     end;
    if (sendSignals<>ssNone) and
       (pressed or (btnStyle=bsCheckbox)) then begin
      Signal('UI\'+name+'\Click',byte(pressed));
      Signal('UI\onButtonDown\'+name,TTag(self));
      if Assigned(onClick) then onClick;
    end;
   end else begin
    if pending then exit;
    // Защита от двойных кликов
    if (sendSignals<>ssNone) and (MyTickCount>lastPressed+50) then begin
     Signal('UI\'+name+'\Click',byte(pressed));
     Signal('UI\onButtonClick\'+name,TTag(self));
     if Assigned(onClick) then game.RunAsync(@onClick);
     lastPressed:=MyTickCount;
    end;
   end;
  end;

 function TUIButton.onHotKey(keycode,shiftstate:byte):boolean;
  var
   i:integer;
  begin
   result:=false;
   if btnStyle=bsNormal then begin
    SetPressed(true);
    DoClick;
    timer:=150;
    result:=true;
   end else begin
    // don't click on button if it has no effect: i.e. it is pressed and there are other group buttons
    if pressed and (parent<>nil) and (group<>0) then
      for i:=0 to high(parent.children) do
       if (parent.children[i]<>self) and (parent.children[i] is TUIButton) and
          ((parent.children[i] as TUIButton).group=group) then exit;
     DoClick;
     result:=true;
   end;
  end;

 function TUIButton.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed and (keycode in [VK_RETURN,VK_SPACE]) then begin // Enter
    onHotKey(keycode,shiftstate);
    result:=false;
   end;
  end;

 procedure TUIButton.onMouseButtons(button:byte;state:boolean);
  begin
   if not enabled then begin
    Signal('UI\'+name+'\ClickDisabled',button);
    exit;
   end;
   // Regular button
   if (button=1) and (btnStyle=bsNormal) then begin
    if not pressed and state then SetPressed(true); // нажать
    if pressed and not state then begin // отпустить и среагировать
     DoClick;
     SetPressed(false);
    end;
   end;
   // Special button
   if (button=1) and (btnStyle<>bsNormal) and state then DoClick;
   inherited;
  end;

 procedure TUIButton.onMouseMove;
  begin
   inherited;
   if not lastover and (undermouse=self) then
    Signal('UI\onButtonOver\'+name);
   if lastover and (undermouse<>self) then
    Signal('UI\onButtonOut\'+name);
   if btnStyle=bsNormal then begin
    if pressed and (underMouse<>self) then
     SetPressed(false);
   end;
   lastover:=undermouse=self;
  end;

 procedure TUIButton.onTimer;
  begin
   if btnStyle=bsNormal then begin
    SetPressed(false);
   end;
  end;

 procedure TUIButton.SetPressed(pr: boolean);
  begin
   pressed:=pr;
   if linkedValue<>nil then
    PBoolean(linkedValue)^:=pressed;
   if (sendSignals<>ssNone) then begin
    if btnStyle<>bsNormal then begin
     Signal('UI\onButtonSwitch\'+name);
     Signal('UI\'+name+'\Toggle');
    end else begin
     if pr then Signal('UI\onButtonDown\'+name)
       else     Signal('UI\onButtonUp\'+name);
    end;
   end;
  end;

 procedure TUIButton.MakeSwitches(sameGroup:boolean=true;clickHandler:Apus.Types.TProcedure=nil); // make all sibling buttons with the same size - switches
  var
   i:integer;
   b:TUIButton;
   first:boolean;
  begin
   if parent=nil then exit;
   first:=true;
   for i:=0 to high(parent.children) do begin
    if not (parent.children[i] is TUIButton) then continue;
    b:=TUIButton(parent.children[i]);
    if not b.visible then continue;
    if abs(b.size.x-size.x)+abs(b.size.y-size.y)>=1 then continue;
    b.btnStyle:=bsSwitch;
    if @clickHandler<>nil then b.onClick:=@clickHandler;
    if sameGroup then begin
     b.group:=1;
     if first then begin
      b.pressed:=true;
      first:=false;
     end;
    end else
     b.group:=i+1;
   end;
  end;


{ TUICheckBox }

constructor TUICheckBox.Create(width,height:single;btnName,caption:string;
   parent_:TUIElement;checked:boolean;btnFont:TFontHandle);
 begin
  inherited Create(width,height,btnName,caption,parent_);
  btnStyle:=bsCheckbox;
  self.checked:=checked;
  if btnFont>0 then font:=btnFont;
 end;

{ TUIRadioBox }

constructor TUIRadioButton.Create(width,height:single;btnName,caption:string;
  parent_:TUIElement;checked:boolean;btnFont:TFontHandle);
 var
  i:integer;
 begin
  inherited Create(width,height,btnName,caption,parent_);
  btnStyle:=bsCheckbox;
  group:=1;
  if btnFont>0 then font:=btnFont;
  checked:=true;
  for i:=0 to high(parent.children) do
   if parent.children[i] is TUIRadioButton then
    if TUIRadioButton(parent.children[i]).checked and
       (TUIRadioButton(parent.children[i]).group=group) then checked:=false;
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

constructor TUILabel.Create(width,height:single;labelname,text:string;color_,bFont:TFontHandle;
    parent_: TUIElement);
  begin
   inherited Create(width,height,parent_,labelName);
   shape:=shapeFull;
   if color=clDefault then color:=color_;
   if font=0 then font:=bFont;
   align:=taLeft;
   sendSignals:=ssMajor;
   verticalOffset:=0;
   caption:=text;
  end;

constructor TUILabel.CreateCentered(width,height:single;labelname,text:string;
   parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault);
  begin
   Create(width,height,labelName,text,color_,font,parent_);
   align:=taCenter;
  end;

 constructor TUILabel.Create(width,height:single;labelname,text:string;
   parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault);
  begin
   Create(width,height,labelName,text,color_,font,parent_);
   align:=taLeft;
  end;

 constructor TUILabel.CreateRight(width,height:single;labelname,text:string;
   parent_:TUIElement;font:TFontHandle=0;color_:cardinal=clDefault);
  begin
   Create(width,height,labelName,text,color_,font,parent_);
   align:=taRight;
  end;

{ TUIWindow }

 constructor TUIWindow.Create(innerWidth,innerHeight:single;sizeable:boolean;wndName,
    wndCaption:string;wndFont:TFontHandle;parent_:TUIElement);
  var
   deltaX,deltaY:integer;
  begin
   resizeable:=sizeable;
   if resizeable then begin
    deltaX:=wcFrameBorder; deltay:=wcFrameBorder;
   end else begin
    deltaX:=2; deltay:=2;
   end;
   inherited Create(innerWidth+deltaX*2,innerHeight+deltay+wcTitleHeight,wndName,parent_);
   padding.Left:=deltaX; padding.Top:=wcTitleHeight;
   padding.Right:=deltaX; padding.Bottom:=deltaY;

   shape:=shapeFull;
   caption:=wndCaption;
   font:=wndFont;
   header:=wcTitleHeight;
   autoBringToFront:=true;
   canhavefocus:=false;
   moveable:=true;
   minW:=32; minH:=32;
   maxW:=1600; maxH:=1200;
   color:=$FFBCB8B0;
   area:=0;
   order:=100; // выше чем прочие элементы.
  end;

 function TUIWindow.GetAreaType(x,y:integer;out cur:NativeInt):integer;
  var
   c:byte;
   r:TRect;
  begin
   result:=0; cur:=crDefault;
   r:=GetPosOnScreen;
   if (x<r.left) or (y<r.top) or (x>=r.Right) or (y>=r.Bottom) then exit;
   dec(x,r.Left);
   dec(y,r.Top);
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
    1:cur:=crResizeW;
    2:cur:=crResizeH;
    3:cur:=crResizeHW;
   end;
  end;

 procedure TUIWindow.onLostFocus;
  begin
   hooked:=false;
  end;

 procedure TUIWindow.onMouseButtons(button:byte;state:boolean);
  var
   pnt:TPoint;
  begin
   inherited;
   if (button=1) and not (area in [0,wcClient]) then begin
    if not hooked and state then hooked:=true;
    if hooked and not state then begin
     hooked:=false;
     // Don't allow window center to be moved outside screen
     pnt:=GetPosOnScreen.CenterPoint;
     /// TODO: implement action
    end;
   end;
  end;

 procedure TUIWindow.onMouseMove;
  var
   iScale:single;
   dx,dy:single;
  begin
   if hooked then begin
    iScale:=scale/globalScale; // pixels to parent's space scale
    dx:=(curMouseX-oldMouseX)*iScale;
    dy:=(curMouseY-oldMouseY)*iScale;
    // Drag
    if area=wcHeader then begin
     position:=PointAdd(position, Point2s(dx,dy));
    end;
    // Resize
    if area and wcRightFrame>0 then Resize(size.x+dx,-1);
    if area and wcBottomFrame>0 then Resize(-1,size.y+dy);
    if area and wcLeftFrame>0 then begin Resize(size.x-dx,-1); position.x:=position.x-dx; end;
    if area and wcTopFrame>0 then begin Resize(-1,size.y-dy); position.y:=position.y-dy; end;
   end;

   inherited;
   area:=GetAreaType(curMouseX,curMouseY,cursor);
   if area in [0,wcClient] then hooked:=false;
  end;

 procedure TUIWindow.Resize(newWidth,newHeight:single);
  begin
   if newwidth<>-1 then begin
    if newwidth<minW then newwidth:=minW;
    if newwidth>maxW then newwidth:=maxW;
   end;
   if newheight<>-1 then begin
    if newheight<minH then newheight:=minH;
    if newheight>maxH then newheight:=maxH;
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
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
   if selstart>length(realtext) then selstart:=length(realtext);
   if selstart+selcount>length(realtext)+1 then selcount:=length(realtext)-selstart+1;
  end;

 constructor TUIEditBox.Create(width,height:single;boxName:string;
    boxFont:TFontHandle;color_:cardinal;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,boxName);
   shape:=shapeFull;
   cursor:=crInput;
   realtext:='';
   selstart:=0;
   selcount:=0;
   cursorpos:=0;
   font:=boxFont;
   maxlength:=240;
   password:=false;
   backgnd:=0;
   color:=color_;
   protection:=0;
   needPos:=-1;
   offset:=0;
   // Свойства предка
   canhavefocus:=true; //CheckAndSetFocus;
   sendSignals:=ssAll;
   completion:='';
   defaultText:='';
   lastClickTime:=0;
  end;

 function TUIEditBox.GetText:String8;
  begin
   result:=Str8(realtext);
  end;

 procedure TUIEditBox.SetText(s:String8);
  begin
   realtext:=DecodeUTF8(s);
   if cursorpos>length(realtext) then cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.onChar(ch:char;scancode:byte);
  begin
   inherited;
  end;

 procedure TUIEditBox.onUniChar(ch:WideChar;scancode:byte);
  var
   oldText:WideString;
  begin
   oldText:=realText;
   AdjustState;
   cursortimer:=mytickcount;
   if (ch=#13) and (sendSignals<>ssNone) then begin
    if (completion<>'') and (realText<>completion) then begin
     realText:=completion;
     completion:='';
     cursorpos:=length(realtext);
     selcount:=0;
     Signal('UI\'+name+'\AutoCompletion',0);
    end else
     Signal('UI\'+name+'\Enter',0);
   end;
   if (ch=#27) and (sendSignals<>ssNone) then Signal('UI\'+name+'\Escape',0);
   if (ch>=#32) and (selcount>0) then begin
    delete(realtext,selstart,selcount);
    insert(ch,realtext,selstart);
    selcount:=0;
    cursorpos:=selstart;
    exit;
   end;
   if (length(realtext)<maxlength) and (ch>=#32) then begin
    inc(cursorpos);
    insert(ch,realtext,cursorpos);
   end;
   if (sendSignals=ssAll) and (oldText<>realText) then begin
    savedText:=oldText;
    Signal('UI\'+name+'\changed',0);
   end;
  end;

 function TUIEditBox.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
   procedure ClipCopy(cut:boolean=false);
    var
     str:string;
    begin
     if password or (protection<>0) then exit;
     str:=copy(realtext,selstart,selcount);
     CopyStrToClipboard(str);
     if cut then begin
      delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1;
     end;
    end;
   procedure ClipPaste;
    var
     str:string;
     wst:WideString;
    begin
     wst:=PasteStrFromClipboardW;
     if wst<>'' then begin
      if selcount>0 then begin
       delete(realtext,selstart,selcount);
       cursorpos:=selstart-1;
      end else
       selstart:=cursorpos+1;
      insert(wst,realtext,cursorpos+1);
      selcount:=length(str);
      if length(realtext)>maxlength then setLength(realtext,maxlength);
      if selstart+selcount-1>length(realtext) then selcount:=length(realtext)-selstart+1;
      cursorpos:=selstart+selcount-1;
     end;
    end;
  var
   step:integer;
   oldText:string;
  begin
   oldText:=realText;
   AdjustState;
   result:=inherited onKey(keycode,pressed,shiftstate);
   if pressed then begin
    cursortimer:=mytickcount;

    if (keycode=VK_LEFT) then begin // Left
     step:=1;
     if shiftstate and sscCtrl>0 then begin // Сдвиг более чем на 1 символ
      while (cursorpos-step>0) and (realtext[cursorpos-step]>='A') do inc(step);
     end;

     if shiftstate and sscShift>0 then begin
      if (selcount>0) and (cursorpos>=selstart) then dec(selcount,step)
      else
      if (selcount>0) and (cursorpos>0) and (cursorpos<selstart) then
       begin dec(selstart,step); inc(selcount,step); end
      else
      if (selcount=0) and (cursorpos>0) then
       begin selstart:=cursorpos; selcount:=1; end;
     end else selcount:=0;
     if (cursorpos>0) then dec(cursorpos,step);
     if cursorpos<0 then cursorpos:=0;
    end;

    if (keycode=VK_RIGHT) and (cursorpos<length(realtext)) then begin // Right
     step:=1;
     if shiftstate and sscCtrl>0 then begin // Сдвиг более чем на 1 символ
      while (cursorpos+step<length(realtext)) and not ((realtext[cursorpos+step+1]>='A')
       and not (realtext[cursorpos+step]>='A')) do inc(step);
     end;

     if shiftstate and sscShift>0 then begin
      if (selcount>0) and (cursorpos<length(realtext)) and (cursorpos>=selstart) then inc(selcount,step)
      else
      if (selcount>0) and (cursorpos<selstart) then
       begin inc(selstart,step); dec(selcount,step); end
      else
      if (selcount=0) and (cursorpos<length(realtext)) then
       begin selstart:=cursorpos+1; selcount:=1; end;
     end else selcount:=0;
     if (cursorpos<length(realtext)) then inc(cursorpos,step);
     if cursorpos>length(realtext) then cursorpos:=length(realtext);
    end;

    if keycode=VK_HOME then begin  // Home
     if shiftstate and sscShift>0 then begin
      inc(selcount,cursorpos); selstart:=1;
     end else selcount:=0;
     cursorpos:=0;
    end;
    if keycode=VK_END then begin // End
     if shiftstate and sscShift>0 then begin
      if selcount=0 then selstart:=cursorpos+1;
      inc(selcount,length(realtext)-cursorpos);
     end else selcount:=0;
     cursorpos:=length(realtext);
    end;

    if (keycode=VK_BACK) and (shiftState and sscAlt=0) then begin // backspace
     if selcount>0 then
      begin delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1; end
     else begin
      if cursorpos>0 then begin delete(realtext,cursorpos,1); dec(cursorpos); end;
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
       ((keycode=VK_BACK) and (shiftState=sscAlt)) then begin
     realText:=savedText;
    end;

    if keycode=VK_INSERT then begin // ins
     if (selcount>0) and (shiftstate=sscCtrl) then clipCopy;
     if shiftstate and sscShift>0 then clipPaste;
    end;
    if keycode=VK_DELETE then begin // del
     if selcount>0 then begin
      if shiftstate and sscShift>0 then ClipCopy(true) // Cut
       else begin
        delete(realtext,selstart,selcount); selcount:=0; cursorpos:=selstart-1;
       end;
     end else begin
      if (cursorpos<length(realtext)) then begin
       delete(realtext,cursorpos+1,1);
      end;
     end;
    end;
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
    if MyTickCount<lastClickTime+300 then doubleClick:=true;
    lastClickTime:=MyTickCount;
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
    msSelStart:=0;
   end;
   if doubleclick then begin
    selStart:=1; selCount:=length(realText);
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
    if (msSelStart=0) then msSelStart:=cursorpos;
    if (msSelStart>0) and (cursorpos<>msSelStart) then begin
      if cursorpos<msSelStart then begin
       selstart:=cursorPos+1;
       selcount:=msSelStart-cursorpos;
      end else begin
       selStart:=msSelStart+1;
       selcount:=cursorPos-msSelStart;
      end;
    end;
    needpos:=curMouseX-globalrect.Left-offset;
   end;
  end;

 procedure TUIEditBox.SelectAll;
  begin
   selStart:=1;
   selCount:=length(realText);
   cursorpos:=length(realtext);
  end;

 procedure TUIEditBox.SetFocus;
  begin
   AdjustState;
   inherited;
   SelectAll;
   {$IFDEF IOS}
   Signal('UI\EditBox\onSetFocus',TTag(self));
   {$ENDIF}
  end;

 procedure TUIEditBox.onLostFocus;
  begin
   inherited;
   {$IFDEF IOS}
   Signal('UI\EditBox\onLostFocus',TTag(self));
   {$ENDIF}
  end;

 { TUIScrollBar }

 constructor TUIScrollBar.Create(width,height:single;barName:string;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,barName);
   shape:=shapeFull;
   min:=0; max:=100; rValue.Init(0); pagesize:=0;
   linkedControl:=nil; step:=1;
   color:=$FFB0B0B0;
   horizontal:=size.x>size.y;
   // hooked:=false;
   scroller:=TScrollBarInterface.Create(self);
  end;

 procedure TUIScrollBar.SetPageSize(pageSize:single);
  begin
   self.pagesize:=pagesize;
  end;

function TUIScrollBar.SetRange(newMin,newMax,newPageSize:single):TUIScrollBar;
  var
   pSize:single;
  begin
   min:=newMin; max:=newMax; pageSize:=newPageSize;
   pSize:=Clamp(pageSize,0,max-min);
   rValue.Assign(Clamp(rValue.FinalValue,min,max-pSize));
  end;

 function TUIScrollBar.GetValue:single;
  begin
   result:=rValue.value;
   if isInteger then result:=round(result);
   Clamp(result,min,max-pageSize);
  end;

 procedure TUIScrollBar.Link(elem:TUIElement);
  begin
   linkedControl:=elem;
  end;

 procedure TUIScrollBar.SetValue(v:single);
  begin
   v:=Clamp(v,min,max-pageSize);
   rValue.Assign(v);
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

procedure TUIScrollBar.CalcSliderPos;
 var
  minSliderSize,fullSize,v,pSize:single;
 begin
  if horizontal then begin
   minSliderSize:=size.y*0.75;
   fullSize:=size.x;
  end else begin
   minSliderSize:=size.x*0.75;
   fullSize:=size.y;
  end;
  pSize:=pageSize;
  if pSize>max-min then pSize:=max-min;
  v:=rValue.Value;
  v:=Clamp(v,min,max-pSize);
  sliderStart:=fullSize*(v-min)/(max-min);
  if sliderStart<0 then sliderStart:=0;
  sliderEnd:=fullSize*(v+pSize-min)/(max-min);
  if sliderEnd>fullSize then sliderEnd:=fullSize;
  if sliderEnd-sliderStart<minSliderSize then begin
   // slider is too small - treat it as a point
   fullSize:=fullSize-minSliderSize;
   sliderStart:=fullSize*(v-min)/(max-min);
   sliderEnd:=sliderStart+minSliderSize;
  end;
  sliderRect:=globalRect;
  if horizontal then begin
   sliderRect.left:=globalRect.left+round(globalRect.Width*(sliderStart/size.x));
   sliderRect.right:=globalRect.left+round(globalRect.Width*(sliderEnd/size.x));
  end else begin
   sliderRect.Top:=globalRect.top+round(globalRect.Height*(sliderStart/size.y));
   sliderRect.Bottom:=globalRect.top+round(globalRect.Height*(sliderEnd/size.y));
  end;
  sliderUnder:=PtInRect(sliderRect,Point(curMouseX,curMouseY));
 end;

procedure TUIScrollBar.MoveRel(delta:single;smooth:boolean=false);
  begin
   MoveTo(round(rValue.FinalValue)+delta,smooth);
  end;

 procedure TUIScrollBar.MoveTo(val:single;smooth:boolean=false);
  begin
   if val<min then val:=min;
   if val+pagesize>max then val:=max-pagesize;
   if smooth then rValue.Animate(val,300,spline1)
    else rValue.Assign(val);

   Signal('UI\'+name+'\Changed',round(val));
   if linkedControl<>nil then begin
    if linkedcontrol.scrollerH.GetElement=self then
     linkedControl.scroll.X:=value;
    if linkedcontrol.scrollerV.GetElement=self then
     linkedControl.scroll.Y:=value;
   end;
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
    MoveTo(min+round((max-min-pagesize)*p));
    onMouseMove;
    //onMouseButtons(button,true);
   end;
  end;

 procedure TUIScrollBar.onMouseMove;
  var
   p1,p2:single;
   v:integer;
  begin
   inherited;
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

 procedure TUIScrollBar.UseButtons(lessBtn,moreBtn:string);
  begin

  end;

  { TUISkinnedWindow }

 constructor TUISkinnedWindow.Create(wndName,wndCaption:string;
    wndFont:TFontHandle;parent_:TUIElement;canmove:boolean=true);
  begin
   inherited Create(100,100,false,wndName,wndCaption,wndFont,parent_);
   dragRegion:=nil;
   background:=nil;
   moveable:=canmove;
   padding.Top:=0; padding.Left:=0;
   padding.Right:=0; padding.Bottom:=0;
  end;

 destructor TUISkinnedWindow.Destroy;
  begin
   dragRegion.Free;
   inherited;
  end;

 function TUISkinnedWindow.GetAreaType(x,y:integer;out cur:NativeInt):integer;
  begin
   result:=0; cur:=crDefault;
   dec(x,globalrect.Left);
   dec(y,globalrect.Right);
   if (x<0) or (y<0) or (x>=globalrect.width) or (y>=globalrect.height) then exit;
   if moveable then result:=wcHeader else result:=wcClient;
   if (dragRegion<>nil) and not dragRegion.TestPoint(x,y) then
    result:=wcClient;
  end;

 { TUIHint }

 constructor TUIHint.Create(x,y:single;text:string;parent_:TUIElement);
  begin
   inherited Create(1,1,'hint',parent_);
   SetPos(x,y,pivotTopLeft);
   shape:=shapeEmpty;
   font:=0;
   simpleText:=text;
   active:=false;
   adjusted:=false;
   created:=MyTickCount;
   parentClip:=false;
  end;

 destructor TUIHint.Destroy;
  begin
   inherited;
  end;

 procedure TUIHint.Hide;
  begin
   if not hiding then begin
    LogMessage('UIHint Hide');
    hiding:=true;
    created:=MyTickCount;
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

 constructor TUIScrollArea.Create(width,height,fullW,fullH:single;
    dir:TUIScrollDirection;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_);
   shape:=shapeFull;
   fullWidth:=fullW;
   fullHeight:=fullH;
   direction:=dir;
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

 procedure TUIListBox.AddLine(line:string;tag:cardinal=0;hint:string='');
  var
   n:integer;
  begin
   n:=length(lines)+1;
   SetLength(lines,n);
   SetLength(tags,n);
   SetLength(hints,n);
   lines[n-1]:=line;
   tags[n-1]:=tag;
   hints[n-1]:=hint;
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

 constructor TUIListBox.Create(width,height:single;lHeight:single;listName:string;
   font_:TFontHandle;parent:TUIElement);
  var
   scrollbar:TUIScrollbar;
  begin
   inherited Create(width,height,parent,listName);
   shape:=shapeFull;
   font:=font_;
   lineHeight:=lHeight;
   selectedLine:=-1;
   hoverLine:=-1;
   canHaveFocus:=true;
   sendSignals:=ssMajor;

   scrollBar:=TUIScrollBar.Create(19,height-2,listName+'_scroll',self);
   scrollBar.SetPos(width,1,pivotTopLeft).SetAnchors(1,0,1,1);
   scrollBar.horizontal:=false;
   scrollerV:=scrollBar.GetScroller;
   bgColor:=0;
   textColor:=$E0D0D0D0;
   bgHoverColor:=0;
   hoverTextColor:=$FFD8D8D8;
   bgSelColor:=$90406070;
   selTextColor:=$FFF0F0F0;
   autoSelectMode:=false;
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
  begin
   inherited;
   cx:=curMouseX-(globalRect.Left+1);
   cy:=curMouseY-(globalRect.Top+1);
   if (cx>=0) and (cy>=0) and (cx<globalRect.width-1) and (cy<globalRect.height-1) then begin
    n:=trunc((cy+scrollerV.GetValue)/(lineHeight*globalScale));
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

procedure TUIListBox.SetLine(index:integer;line:string;tag:cardinal=0;hint:string='');
  begin
   lines[index]:=line;
   tags[index]:=tag;
   hints[index]:=hint;
   UpdateScroller;
  end;

 procedure TUIListBox.SetLines(newLines:StringArr);
  var
   i:integer;
  begin
   SetLength(lines,length(newLines));
   SetLength(tags,length(newLines));
   SetLength(hints,length(newLines));
   for i:=0 to length(lines)-1 do begin
    lines[i]:=newLines[i];
    tags[i]:=0;
    hints[i]:='';
   end;
   if selectedLine>=length(lines) then selectedLine:=length(lines)-1;
   UpdateScroller;
  end;

 procedure TUIListBox.UpdateScroller;
  var
   max:single;
  begin
   max:=length(lines)*lineHeight;
   scrollerV.SetRange(0,max);
   scrollerV.SetStep(lineHeight*(round(clientHeight/2) div round(lineHeight)));
   scrollerV.SetPageSize(globalRect.height);
   scrollerV.GetElement.size.y:=clientHeight;
   scrollerV.GetElement.visible:=max>clientHeight;
  end;

  { TUIFrame }

 constructor TUIFrame.Create(width,height:single;depth,style_:integer;parent_:TUIElement);
  begin
   inherited Create(width,height,parent_,'UIFrame');
   shape:=shapeFull;
   borderWidth:=depth;
   style:=style_;
   padding.Left:=depth;  padding.Top:=depth;
   padding.Right:=depth; padding.Bottom:=depth;
  end;

 { TUIComboBox }

 procedure TUIComboBox.AddItem(item:WideString;tag:cardinal;hint:WideString);
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
  begin
   if HasPrefix(event,'MOUSE\BTNDOWN',true) then begin
    // if clicked on an element which is not child of the active combobox - hide it
    e:=underMouse;
    if (comboPop<>nil) and (e<>nil) and
      not (e.HasParent(comboPop) or e.HasParent(comboPop.frame)) then comboPop.onDropDown;
   end;
  end;

 constructor TUIComboBox.Create(width,height:single;bFont:TFontHandle;list:WStringArr;
    parent_:TUIElement;name:string);
  var
   btn:TUIButton;
   i,j:integer;
  begin
   inherited Create(width,height,name,'',bFont,parent_);
   shape:=shapeFull;
   font:=bFont;
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
   curItem:=-1;
   style:=0;
   canHaveFocus:=true;
   maxlines:=15;

   // Default properties for child controls
   frame:=TUIFrame.Create(size.x,2,1,0,self);
   frame.visible:=false;
   frame.parentClip:=false;
   frame.order:=1000;
   popup:=TUIListBox.Create(size.x-2,0,20,'ComboBoxPopUp',font,frame);
   popUp.customPtr:=self;
  // popup.autoSelectMode:=true;
   popup.bgColor:=$FFFFFFFF;
   popup.textColor:=$FF000000;
   popup.bgHoverColor:=$FF405090;
   popup.hoverTextColor:=$FFFFFFFF;
   popup.bgSelColor:=$FF405090;
   popUp.selTextColor:=$FFFFFFFF;

   SetEventHandler('MOUSE\BTNDOWN',ComboEventHandler,emInstant);
  end;

 procedure TUIComboBox.onDropDown;
  var
   r:TRect2s;
   lCount,lHeight,i:integer;
   hint:WideString;
   tag:cardinal;
   root:TUIElement;
  begin
   if not frame.visible then begin
    // Show combo pop
    Signal('UI\COMBOBOX\ONDROP\'+name,TTag(self));
    if comboPop<>nil then comboPop.onDropDown;
    // Attach drop-down list to the root element
    root:=GetRoot;
  {  r:=GetRect;
    r.MoveBy(0,r.y2);}
    r:=TransformTo(GetRect,root);
    frame.position:=Point2s(r.x1, r.y2+1);
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
     frame.position.y:=r.y1-1;
    // Content
    popUp.ClearLines;
    for i:=0 to high(items) do begin
     if i<=high(hints) then hint:=hints[i]   // !!!
      else hint:='';
     if i<=high(tags) then tag:=tags[i]
      else tag:=i;
     popUp.AddLine(EncodeUTF8(items[i]),tag,hint);
    end;
    frame.visible:=true;
    popup.hoverLine:=curItem;
    timer:=1;
    comboPop:=self;
   end else begin
    // Hide combo pop
    Signal('UI\COMBOBOX\ONHIDE\'+name,TTag(self));
    comboPop:=nil;
    i:=curItem;
    if popup.selectedLine>=0 then curItem:=popup.selectedLine;
    if curItem<>i then begin
     Signal('UI\'+name+'\ONSELECT',i);
     Signal('UI\COMBOBOX\ONSELECT\'+name,TTag(self));
    end;
    frame.visible:=false;
    frame.AttachTo(self);
    timer:=0;
   end;
  end;

 procedure TUIComboBox.onMouseButtons(button:byte;state:boolean);
  begin
   inherited;
   if (button=1) and state then begin
    Signal('UI\ComboBox\DropDown',PtrUInt(self));
    onDropDown;
   end;
  end;

 procedure TUIComboBox.onTimer;
  begin
   // не вызывать inherited, т.к. там поведение другое
   if frame.visible then begin
    timer:=1;
    if (popup.selectedLine>=0) or (FocusedElement<>self) then onDropDown;
   end;
  end;

 procedure TUIComboBox.SetCurItem(item:integer);
  begin
   fCurItem:=item;
   if (item>=0) and (item<=high(items)) then caption:=EncodeUTF8(Items[fCurItem])
    else caption:=EncodeUTF8(defaultText);
   if (item>=0) and (item<=high(tags)) then fCurTag:=tags[item]
    else fCurTag:=-1;
  end;

 procedure TUIComboBox.SetCurItemByTag(tag:integer);
  begin
   SetCurItem(FindInteger(tags,tag));
  end;

 procedure TUIComboBox.SetItem(index:integer;item:WideString;tag:cardinal;
    hint:string);
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
   owner.pagesize:=pageSize;
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
 TUIButton.SetClassAttribute('defaultColor',$FFC0D0D0);
 TUIImage.SetClassAttribute('defaultColor',$FF808080);
 TUIComboBox.SetClassAttribute('handleMouseIfDisabled',false);
end.
