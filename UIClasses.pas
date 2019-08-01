// -----------------------------------------------------
// User Interface classes
// This is independent brick.
//
// Author: Ivan Polyacov (C) 2003, Apus Software
// Mail me: ivan@games4win.com or cooler@tut.by
// ------------------------------------------------------
unit UIClasses;
interface
 uses EngineAPI,contnrs,CrossPlatform,MyServis,AnimatedValues,types,regions;
{$IFDEF CPUARM} {$R-} {$ENDIF}

const
 // Стандартные курсоры интерфейса 
 crDefault        =  0;  // Курсор по умолчанию
 crLink           =  1;  // Курсор над ссылками (рука)
 crWait           =  2;  // Курсор в режиме ожидания (часы)
 crInput          =  3;  // Курсор для полей ввода текста
 crHelp           =  4;  // Курсор со знаком вопроса
 crResizeH        = 10;  // Курсор для изменения высоты
 crResizeW        = 11;  // Курсор для изменения ширины
 crResizeHW       = 12;  // Курсор для произвольного изменения размера
 crCross          = 13;  // Перекрестие
 crNone           = 99;

 // Константы окна (дефолтное поведение, можно менять)
 wcFrameBorder:integer=5;   // Ширина рамки окна
 wcTitleHeight:integer=24;  // Высота заголовка окна

 // Типы областей окна (флаги)
 wcLeftFrame   =  1;
 wcTopFrame    =  2;
 wcRightFrame  =  4;
 wcBottomFrame =  8;
 wcHeader      = 16; // область, за которую можно таскать окно
 wcClient      = 32; // клиентская часть окна (что отличает ее от прозрачных частей)

 // Биты нажатых клавиш сдвига
 sscShift = 1;
 sscCtrl  = 2;
 sscAlt   = 4;
 sscWin   = 8;

type
 // Способ размещения элемента
 TSnapMode=(smNone,
            smTop,     // ширина равна ширине предка, элемент приклеивается к верхней стороне предка
            smRight,   // высота равна высоте предка, приклеивается к правой стороне предка
            smBottom,
            smLeft,
            smParent); // приклеивается к клиентской части предка

 // Режимы "разговорчивости" элементов
 // ssNone - элемент вообще не посылает сигналы
 // ssMajor - элемент посылает только наиболее существенные, специфичные для него сигналы (например для кнопки - это нажатие)
 // ssAll - элемент посылает все сигналы
 TSendSignals=(ssNone,ssMajor,ssAll);

 // Режимы прозрачности эл-та (т.е. доступны ли элементы, расположенные под ним)
 TTranspMode=(tmTransparent, // элемент полностью прозрачный и не может мешать другим
              tmOpaque,      // элемент полностью непрозрачный, т.е. занимает весь прямоугольник
              tmCustom);     // прозрачность точек внутри прямоугольника определяется самим эл-том

 // Способ ограничения движения мыши
 TClipMouse=(cmNo,        // не ограничивать
             cmVirtual,   // с точки зрения контролов курсор ограничен, хотя на самом деле нет
             cmReal,      // курсор реально ограничен заданным прямоугольником
             cmLimited);  // курсор ограничен прямоугольником, но посылаются сообщения
                          // о "выпрыгивании" из него чтобы передать реальное поведение мыши

 TUIScrollBar=class;

 TUIScrollDirection=(sdVertical,    // Vertical only
                     sdHorizontal,  // Horizontal only
                     sdBoth,        // Either vertical or horizontal
                     sdFree);       // Free directional

 // Варианты реакции на изменение размеров контейнера
 TUIPlacementMode=(pmAnchored,      // края закреплены (опционально) якорями за края контейнера
                   pmProportional,  // элемент меняется пропорционально изменению контейнера
                   pmCenter);       // размер элемента не меняется, а его центр меняется пропорционально изменению контейнера

 // Базовый класс для элемента интерфейса, позволяет задать
 // иерархию вложенных элементов
 TUIControl=class
  fName:string;  // Имя - используется при посылке сигналов. Изначально отсутствует, что запрещает посылку сигналов
  x,y:integer;  // Положение в элементе-предке (если предка нет - положение на экране)
  width,height:integer; // Размеры элемента (могут быть больше экрана)
                        // DO NOT CHANGE AFTER BEING DISPLAYED! Use Resize() instead!
  ncLeft,ncTop,ncRight,ncBottom:integer; // рамка отсечения при отрисовке вложенных эл-тов (может также использоваться для других целей)
  transpmode:TTranspMode;  // Режим прозрачности для событий ввода
  region:TRegion;   // задает область непрозрачности в режиме tmCustom (поведение по умолчанию)
  scrollX,scrollY:integer; // смещение (используется для вложенных эл-тов!)
  scrollerH,scrollerV:TUIScrollBar;  // если для прокрутки используются скроллбары - здесь можно их определить
  placementMode:TUIPlacementMode;  // Реакция на изменение размеров предка
  AnchorRight,AnchorBottom:boolean; // "якоря" для привязки соответствующих краев к краям предка (при изменении размера предка)
  AnchorLeft,AnchorTop:boolean; // если эти якоря не установлены, то при изменении размера должны меняться x и y

  enabled:boolean; // Должен ли элемент реагировать на пользовательский ввод
  visible:boolean; // должен ли элемент рисоваться
  customDraw:boolean; // Указывает на то, что элемент рисуется специальным кодом, а DrawUI его игнорирует
  cursor:integer; // Идентификатор курсора (0 - default)
  order:integer; // Определяет порядок отрисовки ($10000 - база для StayOnTop-эл-тов), отрицательные значения - специальные
  // Define how the element should be displayed
  style:byte;    // Стиль для отрисовки (0 - использует отрисовщик по умолчанию)
  styleinfo:string; // дополнительные сведения для стиля

  canHaveFocus:boolean; // может ли элемент обладать фокусом ввода
  hint,hintIfDisabled:string; // текст всплывающей подсказки (отдельный вариант - для ситуации, когда элемент disabled, причем именно этот элемент, а не за счёт предков)
  hintDelay:integer; // время (в мс), через которое элемент должен показать hint (в режиме показа hint'ов это время значительно меньше)
  hintDuration:integer; // длительность (в мс) показа хинта
  sendSignals:TSendSignals; // режим сигнализирования (см. выше)
  parentClip:boolean; // отсекать ли элемент областью предка (default - yes!)

  timer:integer; // таймер - указывает время в мс через которое будет вызван onTimer() (но не раньше чем через кадр, 0 - не вызывать)

  tag:integer; // Произвольные данные (могут использоваться отрисовщиком)
  customPtr:pointer; // произвольные данные

  parent:TUIControl; // Ссылка на элемент-предок
  children:array of TUIControl; // Список вложенных элементов

  // эти параметры (вторичные св-ва) вычисляются первичными событиями,
  // поэтому пользоваться ими нужно аккуратно
  globalRect:TRect;  // положение элемента на экране (может быть устаревшим! для точного положения - GetPosOnScreen)

  class var
   handleMouseIfDisabled:boolean; // следует ли передавать события мыши элементу, если он отключен

  // Создает независимый элемент
  constructor Create(cx,cy,w,h:integer;parent_:TUIControl;name_:string='');
  // Удаляет элемент (а также все вложенные в него)
  destructor Destroy; override;
  // Поставить элемент в очередь на удаление
  procedure SafeDelete;

  function GetName:string;
  procedure SetName(n:string);

  property name:string read fName write SetName;

  // Найти следующий по порядку элемент того же уровня
  function GetNext:TUIControl; virtual;
  // Найти предыдущий по порядку элемент того же уровня
  function GetPrev:TUIControl; virtual;
  // Найти самого дальнего предка (корневой элемент)
  function GetParent:TUIControl;
  // Виден ли элемент (проверяет видимость всех предков)
  function IsVisible:boolean;
  // Доступен ли элемент (проверяет доступность всех предков)
  function IsEnabled:boolean;
  // Является ли указанный элемент потомком данного?
  function IsChild(c:TUIControl):boolean;
  // Вложен ли данный элемент в указанный (direct or indirect) (HasParent(self)=true)
  function HasParent(c:TUIControl):boolean;
  // Есть ли у данного элемента указанный потомок (direct or indirect) (HasChild(self)=true)
  function HasChild(c:TUIControl):boolean;

  // Attach to new parent
  procedure AttachTo(newParent:TUIControl);
  // Detach from parent
  procedure Detach;

  // Первичные события (вызываются извне)
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
  // Перевести фокус на следующий/предыдущий эл-ты      SetPriorityClass
  procedure SetFocusToNext;
  procedure SetFocusToPrev;
  // Корректное изменение размера (с правильной реакцией подчиненных эл-тов)
  // Значение -1 сохраняет предыдущее значение
  procedure Resize(newWidth,newHeight:integer); virtual;
  // разместить элемент по центру предка либо экрана (если предка нет)
  procedure Center;
  // Прикрепляет элемент к какой-либо части предка
  procedure Snap(snapTo:TSnapMode); 
  // Растягивает элемент включая все вложенные (без Resize)
  procedure Scale(sX,sY:single);
  // Скроллинг в указанную позицию (с обработкой подчиненных скроллбаров если они есть)
  procedure ScrollTo(newX,newY:integer); virtual;
  // получить экранные к-ты элемента
  function GetPosOnScreen:TRect;
  // Если данный элемент может обладать фокусом, но ни один другой не имеет фокуса - взять фокус на себя
  procedure CheckAndSetFocus;
  // Найти элемент в указанной точке (среди потомков текущего)
  // Возвращает true если все элементы начиная с текущего в цепочке вложенности enabled
  function FindItemAt(x,y:integer;out c:TUIControl):boolean;
  // Найти элемент по имени
  function FindByName(name:string):TUIControl;

  // Установить либо удалить "горячую клавишу" для данного эл-та
  procedure SetHotKey(keycode:byte;shiftstate:byte);
  procedure ReleaseHotKey(keycode:byte;shiftstate:byte);

  // Функция определения прозрачности точки в режиме tmCustom (к-ты задаются относительно начала эл-та)
  function IsTransparent(x,y:integer):boolean; virtual;
 protected
  focusedChild:TUIControl;
  rLeft,rTop,rRight,rBottom:single; // точное положение элемента в предке

 private
  procedure AddToRootControls;
  procedure RemoveFromRootControls;
 end;

 // Элемент с ограничениями размера
 TUIFlexControl=class(TUIControl)
  minWidth,minHeight:integer;
  maxWidth,maxHeight:integer;
 end;


 // Элемент "изображение". Содержит простое статическое изображение
 TUIImage=class(TUIControl)
  color:cardinal;  // drawing color (default is $FF808080)
  src:string; // здесь может быть имя файла или строка "event:xxx"
  constructor Create(cx,cy,w,h:integer;imgname:string;parent_:TUIControl);
 end;

 // Скроллер для тачскрина - размещается независимо либо поверх другого элемента, который он и скроллит
 TUIScrollArea=class(TUIControl)
  fullWidth,fullHeight:integer; // full content area
  direction:TUIScrollDirection;
  constructor Create(cx,cy,w,h,fullW,fullH:integer;dir:TUIScrollDirection;parent_:TUIControl);
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
  font:cardinal; // шрифт
  active:boolean; // если true - значит хинт активный, не кэшируется и содержит вложенные эл-ты
  created:int64; // момент создания (в мс.)
  adjusted:boolean; // отрисовщик может использовать это для корректировки параметров хинта

  constructor Create(cx,cy:integer;stext:string;act:boolean;parent_:TUIControl);
  destructor Destroy; override;
  procedure Hide;
  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure onTimer; override;
 end;

 TUILabel=class(TUIControl)
  caption:string;
  color:cardinal;
  align:TTextAlignment;
  font:cardinal;
  topOffset:integer; // сдвиг текста вверх
  constructor Create(cx,cy,w,h:integer;labelname,text:string;color_,bFont:cardinal;parent_:TUIControl);
 end;

 // Тип кнопок
 TButtonStyle=(bsNormal,   // обычная кнопка
               bsSwitch,   // кнопка-переключатель (фиксирующаяся в нажатом положении)
               bsCheckbox);    // кнопка-надпись (чекбокс)
 TUIButton=class(TUIImage)
  caption:string;
  default:boolean; // кнопка по умолчанию (влияет только на отрисовку, но не на поведение!!!)
  pressed:boolean; // кнопка вдавлена
  pending:boolean; // состояние временной недоступности (не реагирует на нажатия)
  autoPendingTime:integer; // время (в мс) на которое кнопка переводится в состояние pending при нажатии (0 - не переводится)

  btnStyle:TButtonStyle; // тип кнопки (влияет как на отрисовку, так и на поведение)
  group:integer;   // Группа
  font:cardinal;
  constructor Create(cx,cy,w,h:integer;btnName,btnCaption:string;btnFont:cardinal;parent_:TUIControl);

  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure onMouseMove; override;
  function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
  procedure onHotKey(keycode:byte;shiftstate:byte); override;
  procedure onTimer; override; // отжимает кнопку по таймеру
  procedure SetPressed(pr:boolean); virtual;
 protected
  procedure DoClick;
 private
  lastPressed,pendingUntil:int64;
  lastOver:boolean;
 end;

 // Рамка
 TUIFrame=class(TUIControl)
  constructor Create(cx,cy,w,h,depth,style_:integer;parent_:TUIControl);
  procedure SetBorderWidth(w:integer); virtual;
 protected
  borderWidth:integer; // ширина рамки
 end;

 TUIWindow=class(TUIImage)
  caption:string;
  font:cardinal;
  header:integer; // Высота заголовка
  autoBringToFront:boolean; // автоматически переносить окно на передний план при клике по нему или любому вложенному эл-ту
  moveable:boolean;    // окно можно перемещать
  resizeable:boolean;  // окно можно растягивать
  minW,minH,maxW,maxH:integer; // максимальные и минимальные размеры (для растягивающихся окон)

  constructor Create(cx,cy,w,h:integer;sizeable:boolean;wndName,wndCaption:string;wndFont:cardinal;parent_:TUIControl);

  // Возвращает флаги типа области в указанной точке (к-ты внутри окна!)
  // а также курсор, который нужно заюзать для этой области
  // Эту ф-цию нужно переопределить для создания окон специальной формы или поведения
  function GetAreaType(x,y:integer;out cur:integer):integer; virtual;

  procedure onMouseMove; override;
  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure onLostFocus; override;
  procedure SetFocus; override;
  procedure Resize(newWidth,newHeight:integer); override;
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
  constructor Create(wndName,wndCaption:string;wndFont:cardinal;parent_:TUIControl;canmove:boolean=true);
  destructor Destroy; override;
  function GetAreaType(x,y:integer;out cur:integer):integer; override;
 end;

 TUIEditBox=class(TUIControl)
  encoding:TTextEncoding; // в какой кодировке выдавать text?
  realText:WideString; // реальный текст (лучше использовать это поле, а не text)
  completion:WideString; // grayed background text, if it is not empty and enter is pressed, then it is set to realText
  defaultText:WideString; // grayed background text, displayed if realText is empty
  font:cardinal;        // Шрифт
  color,backgnd:cardinal;
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

  constructor Create(cx,cy,w,h:integer;boxName:string;boxFont:cardinal;color_:cardinal;parent_:TUIControl);
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
  function GetText:string;
  procedure SetText(s:string);
 public
  property text:string read GetText write SetText;         // Редактируемый текст (в заданной кодировке)
 end;

 // Полоса прокрутки
 TUIScrollBar=class(TUIControl)
 private
  rValue:TAnimatedValue;
  function GetValue:integer;
  procedure SetValue(v:integer);
  function GetAnimating:boolean;
 public
  min,max:integer; // границы диапазона
  pagesize,step:integer; // положение и размер ползунка (в пределах диапазона)
  color:cardinal;
  horizontal:boolean;
  over:boolean;
  constructor Create(cx,cy,w,h:integer;barName:string;min_,max_,value_:integer;parent_:TUIControl);
  // Переместить ползунок в указанную позицию
  procedure MoveTo(val:integer;smooth:boolean=false); virtual;
  procedure MoveRel(delta:integer;smooth:boolean=false); virtual;
  // Связать значение с внешней переменной
  procedure Link(ctl:TUIControl); virtual;
  // Сигналы от этих кнопок будут использоваться для перемещения ползунка
  procedure UseButtons(lessBtn,moreBtn:string);

  procedure onMouseMove; override;
  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure onLostFocus; override;
  property value:integer read GetValue write SetValue;
  property isAnimating:boolean read GetAnimating;
 protected
  linkedControl:TUIControl;
  delta:integer; // смещение точки курсора относительно точки начала ползунка (если hooked)
  needval:integer; // значение, к которому нужно плавно прийти
  moving:boolean;
 end;

 TUIListBox=class(TUIControl)
  lines:StringArr;
  tags:array of cardinal;
  hints:StringArr; // у каждого элемента может быть свой хинт (показываемый при наведении на него)
  lineHeight:integer;
  selectedLine,hoverLine:integer; // выделенная строка, строка под мышью (0..count-1), -1 == отсутствует
  autoSelectMode:boolean; // режим, при котором всегда выделяется строка под мышью (для попапов)
  font:cardinal;
  bgColor,bgHoverColor,bgSelColor,textColor,hoverTextColor,selTextColor:cardinal; // цвета отрисовки
  constructor Create(cx,cy,w,h,lHeight:integer;listName:string;font_:cardinal;parent:TUIControl);
  destructor Destroy; override;
  procedure AddLine(line:string;tag:cardinal=0;hint:string=''); virtual;
  procedure SetLine(index:integer;line:string;tag:cardinal=0;hint:string=''); virtual;
  procedure ClearLines;
  procedure SetLines(newLines:StringArr); virtual;
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
  constructor Create(x_,y_,width_,height_:integer;bFont:cardinal;list:WStringArr;parent_:TUIControl;name:string);
  procedure AddItem(item:WideString;tag:cardinal=0;hint:WideString=''); virtual;
  procedure SetItem(index:integer;item:WideString;tag:cardinal=0;hint:string=''); virtual;
  procedure ClearItems;
  procedure onDropDown; virtual;
  procedure onMouseButtons(button:byte;state:boolean); override;
  procedure onLostFocus; override;
  procedure onTimer; override; // трюк: используется для слежения за всплывающим списком, чтобы не заморачиваться с сигналами
  procedure SetCurItem(item:integer); virtual;
  procedure SetCurItemByTag(tag:integer); virtual;
  property curItem:integer read fCurItem write SetCurItem;
  property curTag:integer read fCurTag write SetCurItemByTag;
 end;


var
 underMouse:TUIControl;     // элемент под мышью
 activeWnd:TUIWindow;       // Активное окно (автоматически устанавливается при переводе фокуса)
 modalControl:TUIControl;   // Если есть модальный эл-т - он тут
 comboPop:TUIComboBox;      // если существует выпавший комбобокс - он тут 
 hooked:TUIControl;         // если установлен - теряет фокус даже если не обладал им

 defaultEncoding:TTextEncoding=teUnknown; // кодировка элементов ввода по умолчанию

 clipMouse:TClipMouse;   // Ограничивать ли движение мыши
 clipMouseRect:TRect;    // Область допустимого перемещения мыши

 curMouseX,curMouseY,oldMouseX,oldMouseY:integer; // координаты курсора мыши (для onMouseMove!)

 // Корневые элементы (не имеющие предка)
 // Список используется для передачи (обработки) первичных событий строго
 // по порядку, начиная с 1-го
 rootControls:array of TUIControl;

 // элементы для отложенного удаления. Нужно периодически их удалять
 toDelete:TObjectList;

 UICritSect:TMyCriticalSection; // для многопоточного доступа к глобальным переменным UI

 procedure SetDisplaySize(width,height:integer);
 function DescribeControl(c:TUIControl):string;
 function FocusedControl:TUIControl;
 procedure SetFocusTo(control:TUIControl);

 // обработать нажатие горячей клавиши (передать всем элементам с
 procedure ProcessHotKey(keycode:byte;shiftstate:byte);

 // Найти элемент по имени
 function FindControl(name:string;mustExist:boolean=true):TUIControl;
 // Найти элемент в заданной точке экрана (возвращает true если элемент найден и он
 // enabled - c учетом всех предков)
 function FindControlAt(x,y:integer;out c:TUIControl):boolean;

 // Controls setup
 procedure SetupButton(btn:TUIButton;style:byte;cursor:integer;btnType:TButtonStyle;
            group:integer;default,enabled,pressed:boolean;hotkey:integer);

 procedure SetupEditBox(edit:TUIEditBox;text:string;style:byte;cursor,maxlength:integer;
            enabled,password,noborder:boolean);

 // Установка свойст элемента по имени
 procedure SetControlState(name:string;visible:boolean;enabled:boolean=true);

 // Поиск элементов по имени. Если элемент не найден, то...
 // mustExists=true - исключение, false - будет создан (а в лог будет сообщение об этом)
 function UIButton(name:string;mustExist:boolean=false):TUIButton;
 function UIEditBox(name:string;mustExist:boolean=false):TUIEditBox;
 function UILabel(name:string;mustExist:boolean=false):TUILabel;
 function UIScrollBar(name:string;mustExist:boolean=false):TUIScrollBar;
 function UIComboBox(name:string;mustExist:boolean=false):TUIComboBox;
 function UIListBox(name:string;mustExist:boolean=false):TUIListBox;


implementation
 uses classes,SysUtils,EventMan,clipboard;

type
 // Горячая клавиша
 THotKey=record
  key,shiftstate:byte;
  control:TUIControl;
 end;

var
 HotKeys:array[0..1023] of THotKey;
 HotKeysCnt:integer;

 fControl:TUIControl; // элемент, имеющий фокус ввода (с клавиатуры)
                      // устанавливается автоматически либо вручную
 // Display area size (since this unit doesn't depend on other Engine units)
 rootWidth,rootHeight:integer;

procedure SetDisplaySize(width,height:integer);
begin
 rootWidth:=width;
 rootHeight:=height;
end;

function DescribeControl(c:TUIControl):string;
begin
 if c=nil then begin
  result:='nil'; exit;
 end;
 result:=c.ClassName+'('+PtrToStr(c)+')='+c.name;
end;

function FocusedControl;
begin
 result:=fControl;
end;

procedure SetFocusTo(control:TUIControl);
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

function FindControl(name:string;mustExist:boolean=true):TUIControl;
var
 i:integer;
begin
 result:=nil;
 for i:=0 to high(rootControls) do begin
  result:=rootControls[i].FindByName(name);
  if result<>nil then exit;
 end;
 if mustExist and (result=nil) then raise EWarning.Create('Control '+name+' not found');
end;

function FindControlAt(x,y:integer;out c:TUIControl):boolean;
var
 i,maxZ:integer;
 ct,c2:TUIControl;
 found,enabl:boolean;
begin
 c:=nil; maxZ:=-1;
 // Принцип простой: искать элемент на верхнем слое, если не нашлось - на следующем и т.д.
 for i:=0 to high(rootControls) do begin
  enabl:=rootControls[i].FindItemAt(x,y,ct);
  if ct<>nil then begin
   c2:=ct; // найдем корневого предка ct (вдруг это не rootControls[i]?)
   while c2.parent<>nil do c2:=c2.parent;
   if (modalcontrol<>nil) and (c2<>modalcontrol) then begin
    continue;
   end;
   // выбор элемента с максимальным уровнем Z
   if {found and }(c2.order>maxZ) then begin c:=ct; maxZ:=c2.order; end;
  end;
 end;
 result:=(c<>nil) and c.enabled;
end;

procedure SetControlState(name:string;visible:boolean;enabled:boolean=true);
var
 c:TUIControl;
begin
 c:=FindControl(name,false);
 if c=nil then exit;
 c.visible:=visible;
 c.enabled:=enabled;
end;

function UIButton(name:string;mustExist:boolean=false):TUIButton;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUIButton) then c:=nil;
 if c=nil then c:=TUIButton.Create(0,0,0,0,name,'',0,nil);
 result:=c as TUIButton;
end;

function UIEditBox(name:string;mustExist:boolean=false):TUIEditBox;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUIEditBox) then c:=nil;
 if c=nil then c:=TUIEditBox.Create(0,0,0,0,name,0,0,nil);
 result:=c as TUIEditBox;
end;

function UILabel(name:string;mustExist:boolean=false):TUILabel;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUILabel) then c:=nil;
 if c=nil then c:=TUILabel.Create(0,0,0,0,name,'',0,0,nil);
 result:=c as TUILabel;
end;

function UIScrollBar(name:string;mustExist:boolean=false):TUIScrollBar;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUIScrollBar) then c:=nil;
 if c=nil then c:=TUIScrollBar.Create(0,0,0,0,name,0,0,0,nil);
 result:=c as TUIScrollBar;
end;

function UIComboBox(name:string;mustExist:boolean=false):TUIComboBox;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUIComboBox) then c:=nil;
 if c=nil then c:=TUIComboBox.Create(0,0,0,0,0,nil,nil,name);
 result:=c as TUIComboBox;
end;

function UIListBox(name:string;mustExist:boolean=false):TUIListBox;
var
 c:TUIControl;
begin
 c:=FindControl(name,mustExist);
 if not (c is TUIListBox) then c:=nil;
 if c=nil then c:=TUIListBox.Create(0,0,0,0,0,name,0,nil);
 result:=c as TUIListBox;
end;


{ TUIControl }

procedure TUIControl.Center;
var
 pW,pH:integer;
begin
 if parent<>nil then begin
  pW:=parent.width;
  pH:=parent.height;
 end else begin
  pW:=rootWidth;
  pH:=rootHeight;
 end;
 x:=(pW-width) div 2;
 y:=(pH-height) div 2;
{ nx:=(r.Left+r.Right-width) div 2;
 ny:=(r.Top+r.Bottom-height) div 2;
 r2:=GetPosOnScreen;
 inc(x,nx-r2.Left);
 inc(y,ny-r2.Top);}
end;

procedure TUIControl.Scale(sX,sY:single);
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
end;

procedure TUIControl.CheckAndSetFocus;
begin
 if CanHaveFocus and (FocusedControl=nil) then
  SetFocus;
end;

constructor TUIControl.Create(cx, cy, w, h: integer; parent_:TUIControl;name_:string='');
var
 n:integer;
begin
 x:=cx; y:=cy; width:=w; height:=h;
 ncLeft:=0; ncRight:=0; ncTop:=0; ncBottom:=0;
 transpmode:=tmTransparent;
 timer:=0;
 parent:=parent_;
 parentClip:=true;
 fName:=name_;
 hint:=''; hintIfDisabled:=''; 
 hintDelay:=1000;
 hintDuration:=3000;
 // Верхний левый угол привязан к такому же углу предка
 AnchorLeft:=true;
 AnchorTop:=true;
 // А вот нижний правый угол не привязан
 AnchorRight:=false;
 AnchorBottom:=false;
 cursor:=crDefault;
 enabled:=true;
 visible:=true;
 customDraw:=false;
 if parent<>nil then begin
  n:=length(parent.children);
  inc(n); order:=n;
  SetLength(parent.children,n);
  parent.children[n-1]:=self;
 end else begin
  // Элемент без предка -> занести в список
  AddToRootControls;
  order:=1;
 end;
 style:=0;
 CanHaveFocus:=false;
 sendSignals:=ssNone;
 scrollX:=0; scrollY:=0; scrollerH:=nil; scrollerV:=nil;
 globalRect:=GetPosOnScreen;
 focusedChild:=nil;
 region:=nil;
 Signal('UI\ItemCreated',integer(self));
end;

destructor TUIControl.Destroy;
var
 i,n:integer;
begin
 if fControl=self then begin
  onLostFocus;
  fControl:=nil;
 end;
 if underMouse=self then underMouse:=parent;
 // Destroy all the children
 for i:=0 to length(children)-1 do
  children[i].Free;
 SetLength(children,0);
 // Remove from parent's children
 if parent<>nil then begin
  n:=Length(parent.children);
  for i:=1 to n do
   if parent.children[i-1]=self then begin
    parent.children[i-1]:=parent.children[n-1]; break;
   end;
  dec(n);
  SetLength(parent.children,n);
 end else begin
  // Элемент без предка -> удалить из списка корневых
  RemoveFromRootControls;
 end;
 region.free;
 inherited;
end;

procedure TUIControl.Detach;
var
 i,n:integer;
begin
 if parent=nil then exit;
 n:=Length(parent.children);
 for i:=1 to n do
  if parent.children[i-1]=self then begin
   parent.children[i-1]:=parent.children[n-1]; break;
  end;
 dec(n);
 SetLength(parent.children,n);
 AddToRootControls;
end;

procedure TUIControl.AttachTo(newParent: TUIControl);
var
 n:integer;
begin
 ASSERT(newParent<>nil);
 if parent=newParent then exit;
 if parent<>nil then Detach;
 RemoveFromRootControls;
 parent:=newParent;
 n:=length(parent.children);
 if n>=0 then order:=parent.children[n-1].order+1
  else order:=1;
 SetLength(parent.children,n+1);
 parent.children[n]:=self;
end;

function TUIControl.FindByName(name: string): TUIControl;
var
 i:integer;
 c:TUIControl;
begin
 name:=UpperCase(name);
 if UpperCase(self.name)=name then begin
  result:=self; exit;
 end;
 for i:=0 to length(children)-1 do begin
  c:=children[i].FindByName(name);
  if c<>nil then begin
   result:=c; exit;
  end;
 end;
 result:=nil;
end;

function TUIControl.FindItemAt(x, y: integer; out c: TUIControl): boolean;
var
 r,r2:Trect;
 p:TPoint;
 i,j:integer;
 fl,en:boolean;
 c2:TUIControl;
 ca:array[1..25] of TUIControl;
 cnt:byte;
begin
 // Тут нужно быть предельно внимательным!!!
 result:=enabled and visible;
 c:=nil;
 if not visible then exit; // если элемент невидим, то уж точно ничего не спасет!
 r:=GetPosOnScreen;
 p:=Point(x,y);
 if not PtInRect(r,p) then begin result:=false; exit; end; // за пределами эл-та
 if transpmode=tmOpaque then c:=self;

 // На данный момент известно, что точка в пределах текущего эл-та
 // Но возможно здесь есть кто-то из вложенных эл-тов! Нужно их проверить:
 // выполнить поиск по ним в порядке обратном отрисовке.
 // В невидимых и запредельных искать ессно не нужно, а вот в прозрачных - нужно!
 cnt:=0;
 for i:=0 to length(children)-1 do with children[i] do begin
  if not visible then continue;
  r2.Left:=r.left+self.ncLeft-self.scrollX+x;
  r2.top:=r.top+self.ncTop-self.scrollY+y;
  r2.Right:=r2.left+width;
  r2.Bottom:=r2.Top+height;
  if PtInRect(r2,p) then begin
   ASSERT(cnt<25);
   inc(cnt); ca[cnt]:=self.children[i];
  end;
 end;
 // Список создан, теперь его отсортируем
 if cnt>1 then
  for i:=1 to cnt-1 do
   for j:=cnt downto i+1 do
    if ca[j-1].order<ca[j].order then begin
     c2:=ca[j]; ca[j]:=ca[j-1]; ca[j-1]:=c2;
    end;
 // Теперь порядок правильный, нужно искать
 fl:=false;
 for i:=1 to cnt do begin
  en:=ca[i].FindItemAt(x,y,c2);
  if c2<>nil then begin
   c:=c2; result:=result and en;
   fl:=true; break;
  end;
 end;

 // Ни одного непрозрачного потомка в данной точке, но сам элемент может быть непрозрачен здесь!
 if not fl and (transpmode=tmCustom) then
  if IsTransparent(x-r.Left,y-r.Top) then c:=self;

 if c=nil then result:=false;
end;

function TUIControl.GetName: string;
begin
 if self<>nil then result:=name
  else result:='empty';
end;

procedure TUIControl.SetName(n:string);
begin
 if fName<>n then begin
  fName:=n;
  Signal('UI\ItemRenamed',integer(self));
 end;
end;

procedure TUIControl.Snap(snapTo: TSnapMode);
var
 clientW,clientH:integer;
begin
 if parent=nil then exit;
 if snapTo=smNone then exit;
 clientW:=parent.width-parent.ncLeft-parent.ncRight;
 clientH:=parent.height-parent.ncTop-parent.ncBottom;
 if snapTo in [smTop,smBottom] then Resize(clientW,-1);
 if snapTo in [smLeft,smRight] then Resize(-1,clientH);
 if snapTo=smParent then Resize(clientW,clientH);
 AnchorLeft:=snapTo<>smRight;
 AnchorRight:=snapTo<>smLeft;
 AnchorTop:=snapTo<>smBottom;
 AnchorBottom:=snapTo<>smTop;
end;

function TUIControl.GetNext: TUIControl;
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

function TUIControl.GetParent: TUIControl;
begin
 result:=self;
 if self=nil then exit;
 while result.parent<>nil do result:=result.parent;
end;

function TUIControl.IsVisible:boolean;
var
 c:TUIControl;
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

function TUIControl.IsEnabled:boolean;
var
 c:TUIControl;
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

function TUIControl.IsChild(c:TUIControl):boolean;
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

function TUIControl.GetPosOnScreen: TRect;
var
 c:TUIControl;
begin
 result:=Rect(x,y,x+width,y+height);
 c:=parent;
 while c<>nil do begin
  OffsetRect(result,c.x+c.ncLeft-c.scrollX,c.y+c.ncTop-c.scrollY);
  c:=c.parent;
 end;
end;

function TUIControl.GetPrev: TUIControl;
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

function TUIControl.HasFocus: boolean;
var
 c:TUIControl;
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

function TUIControl.HasParent(c: TUIControl): boolean;
var
 con:TUIControl;
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

function TUIControl.HasChild(c: TUIControl): boolean;
begin
 result:=c.HasParent(self);
end;

function TUIControl.IsTransparent(x, y: integer): boolean;
begin
 result:=false;
 if region<>nil then
  result:=region.TestPoint(x,y);
end;

procedure TUIControl.onChar(ch: char; scancode: byte);
begin
 if (sendSignals=ssAll) and (name<>'') then begin
  Signal('UI\'+name+'\Char',byte(ch)+scancode shl 8);
 end;
end;

procedure TUIControl.onUniChar(ch: WideChar; scancode: byte);
begin
 if (sendSignals=ssAll) and (name<>'') then begin
  Signal('UI\'+name+'\UniChar',word(ch)+scancode shl 16);
 end;
end;

procedure TUIControl.onHotKey(keycode, shiftstate: byte);
begin

end;

function TUIControl.onKey(keycode: byte; pressed: boolean;shiftstate:byte):boolean;
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

procedure TUIControl.onLostFocus;
begin
 if (sendSignals=ssAll) and (name<>'') then Signal('UI\'+name+'\Focus',0);
end;

procedure TUIControl.onTimer;
begin
end;

procedure TUIControl.onMouseButtons(button:byte;state:boolean);
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
 if (comboPop<>nil) and not (HasParent(comboPop) or HasParent(comboPop.frame)) then comboPop.onDropDown;
 if (sendSignals=ssAll) and (name<>'') then begin
  if state then Signal('UI\'+name+'\MsBtnDown',button)
   else Signal('UI\'+name+'\MsBtnUp',button);
 end;
end;

procedure TUIControl.onMouseMove;
begin
 globalRect:=GetPosOnScreen;
 if (sendSignals=ssAll) and (name<>'') then
  Signal('UI\'+name+'\MsMove',0);
end;

procedure TUIControl.onMouseScroll(value: integer);
begin
 if (sendSignals=ssAll) and (name<>'') then begin
  Signal('UI\'+name+'\MsScroll',value);
 end;
 // Если прикреплен вертикальный скроллбар - использовать его для прокрутки
 if scrollerV<>nil then begin
  scrollerV.MoveRel(-scrollerV.step*value div 100,true);
  onMouseMove;
  exit;
 end;
 if parent<>nil then
  parent.onMouseScroll(value);
end;

procedure TUIControl.ReleaseHotKey(keycode, shiftstate: byte);
var
 i:integer;
begin
 if hotkeyscnt<=0 then exit;
 for i:=0 to hotKeysCnt-1 do
  if (hotkeys[i].control=self) and
   ((keycode=0) or
    ((hotkeys[i].key=keycode) and
    (hotkeys[i].shiftstate=shiftstate))) then begin
   dec(hotKeysCnt);
   hotkeys[i]:=hotkeys[hotKeysCnt];
   exit;
  end;
end;

procedure TUIControl.AddToRootControls;
begin
 UICritSect.Enter;
 try
  SetLength(rootControls,length(rootControls)+1);
  rootControls[high(rootControls)]:=self;
 finally
  UICritSect.Leave;
 end;
end;

procedure TUIControl.RemoveFromRootControls;
var
 i:integer;
begin
 UICritSect.Enter;
 try
 for i:=0 to high(rootControls) do
  if rootControls[i]=self then begin
   rootControls[i]:=rootControls[high(rootControls)];
   SetLength(rootControls,length(rootControls)-1);
  end;
 finally
  UICritSect.Leave;
 end;
end;

procedure TUIControl.Resize(newWidth, newHeight: integer);
var
 i,dX,dY,cw,ch:integer;
begin
 if newWidth>-1 then dx:=newwidth-width else dx:=0;
 if newHeight>-1 then dy:=newHeight-height else dy:=0;
 inc(width,dx); inc(height,dy);
 for i:=0 to length(children)-1 do with children[i] do begin
  cw:=width; ch:=height;
  if not AnchorLeft then begin inc(x,dx); dec(cw,dx); end;
  if not AnchorTop then begin inc(y,dy); dec(ch,dy); end;
  if anchorRight then inc(cw,dx);
  if anchorBottom then inc(ch,dy);
  if cw<0 then cw:=0;
  if ch<0 then ch:=0;
  Resize(cw,ch);
 end;
 if anchorRight and not anchorLeft then dec(x,dx);
 if anchorBottom and not anchorTop then dec(y,dy);
 if scrollerH<>nil then scrollerH.pagesize:=width;
 if scrollerV<>nil then scrollerV.pagesize:=height;
end;

procedure TUIControl.SafeDelete;
begin
 if toDelete.IndexOf(self)<0 then
  toDelete.Add(self);
end;

procedure TUIControl.ScrollTo(newX, newY: integer);
begin
 scrollX:=newX; scrollY:=newY;
 if scrollerH<>nil then
  scrollerH.value:=scrollX;
 if scrollerV<>nil then
  scrollerV.value:=scrollY;
end;

procedure TUIControl.SetFocus;
var
 c:TUIControl;
 i:integer;
begin
 if not (enabled and visible) then exit;
 // Сигнал о потере фокуса
 if (fControl<>nil) and (fControl<>self) then with fControl do begin
  onLostFocus;
  if hooked<>nil then hooked.onLostFocus;
 end;
 // Первым делом нужно запомнить элемент, владеющий фокусом в окне (если он в окне)
 if focusedControl<>nil then begin
  c:=focusedControl;
  while (c.parent<>nil) and not (c is TUIWindow) do c:=c.parent;
  c.focusedChild:=focusedcontrol;
 end;
 fControl:=nil; // это для возможности рекурсивных вызовов

 // Если данный элемент вложен в окно - сделаем это окно активным
 c:=self;
 while (c.parent<>nil) and not (c is TUIWindow) do c:=c.parent;
 if c is TUIWindow then begin
  activeWND:=c as TUIWindow;
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

procedure TUIControl.SetFocusToNext;
var
 c:TUIControl;
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

procedure TUIControl.SetFocusToPrev;
begin
end;

procedure TUIControl.SetHotKey(keycode, shiftstate: byte);
var
 i:integer;
begin
 if hotKeysCnt>=1024 then exit;
 // Поиск, а не установлена ли уже эта клавиша
 for i:=0 to HotKeysCnt-1 do
  if (hotkeys[i].control=self) and (hotkeys[i].key=keycode) and
     (hotkeys[i].shiftstate=shiftstate) then exit;
 hotkeys[hotKeysCnt].key:=keycode;
 hotkeys[hotKeysCnt].shiftstate:=shiftstate;
 hotkeys[hotKeysCnt].control:=self;
 inc(HotKeysCnt);
end;

{ TUIimage }

constructor TUIimage.Create(cx,cy,w,h:integer;imgname:string;parent_: TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_,imgName);
 color:=$FF808080;
 src:='';
 transpmode:=tmTransparent;
end;


{ TUIButton }

constructor TUIButton.Create;
var
 i,n:integer;
begin
 inherited Create(cx,cy,w,h,btnName,parent_);
 transpmode:=tmOpaque;
 font:=BtnFont;
 btnStyle:=bsNormal;
 group:=0;
 caption:=BtnCaption;
 if parent.children<>nil then begin
  n:=length(parent.children);
  default:=true;
  for i:=0 to n-1 do
   if parent.children[i] is TUIButton then
    default:=false;
 end else begin
  default:=true;
 end;
 pressed:=false;
 pending:=false;
 autoPendingTime:=0; 
 CanHaveFocus:=false;
 color:=$FFC0D0D0;
 sendSignals:=ssMajor;
 //CheckAndSetFocus;
 lastPressed:=0;
end;

procedure TUIButton.DoClick;
var
 i:integer;
begin
 // Toggle switch button
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
    Signal('UI\onButtonDown\'+name,PtrUInt(self));
  end;
 end else begin
  if pending then exit;
  // Защита от двойных кликов
  if (sendSignals<>ssNone) and (MyTickCount>lastPressed+50) then begin
   Signal('UI\'+name+'\Click',byte(pressed));
   Signal('UI\onButtonClick\'+name,PtrUInt(self));
   lastPressed:=MyTickCount;
  end;
 end;
end;

procedure TUIButton.onHotKey(keycode, shiftstate: byte);
begin
 if btnStyle=bsNormal then begin
  SetPressed(true);
  DoClick;
  timer:=150;
 end else
  DoClick;
end;

function TUIButton.onKey(keycode: byte; pressed: boolean;shiftstate:byte): boolean;
begin
 result:=inherited onKey(keycode,pressed,shiftstate);
 if pressed and (keycode in [VK_RETURN,VK_SPACE]) then begin // Enter
  onHotKey(keycode,shiftstate);
  result:=false;
 end;
end;

procedure TUIButton.onMouseButtons(button: byte; state: boolean);
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

procedure TUIButton.SetPressed(pr: boolean);
begin
 pressed:=pr;
 if (sendSignals<>ssNone) then begin
  if btnStyle<>bsNormal then begin
   Signal('UI\onButtonSwitch\'+name)
  end else begin
   if pr then Signal('UI\onButtonDown\'+name)
     else     Signal('UI\onButtonUp\'+name);
  end;
 end;
end;

{ TUILabel }

constructor TUILabel.Create(cx,cy,w,h: integer;labelname,text:string;color_,bFont:cardinal;
  parent_: TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_,labelName);
 transpmode:=tmOpaque;
 color:=color_;
 align:=taLeft;
 sendSignals:=ssMajor;
 font:=bFont;
 topOffset:=0;
 caption:=text;
end;


{ TUIWindow }

{procedure TUIWindow.Center;
begin
 x:=(screenWidth-width) div 2;
 y:=(screenHeight-height) div 2;
end;}

constructor TUIWindow.Create(cx, cy, w, h: integer; sizeable:boolean; wndName,
  wndCaption: string; wndFont: cardinal; parent_: TUIControl);
var
 deltaX,deltaY:integer;
begin
 resizeable:=sizeable;
 if resizeable then begin
  deltaX:=wcFrameBorder; deltay:=wcFrameBorder;
 end else begin
  deltaX:=2; deltay:=2;
 end;
 inherited Create(cx,cy,w+deltaX*2,h+deltay+wcTitleHeight,wndName,parent_);
 ncLeft:=deltaX; ncTop:=wcTitleHeight;
 ncRight:=deltaX; ncBottom:=deltaY;

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

function TUIWindow.GetAreaType(x, y: integer; out cur: integer): integer;
var
 c:byte;
begin
 result:=0; cur:=crDefault;
 if (x<0) or (y<0) or (x>=width) or (y>=height) then exit;
 if resizeable then begin
  if x<wcFrameBorder then inc(result,wcLeftFrame);
  if y<wcFrameBorder then inc(result,wcTopFrame);
  if x+wcFrameBorder>=width then inc(result,wcRightFrame);
  if y+wcFrameBorder>=height then inc(result,wcBottomFrame);
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

procedure TUIWindow.onMouseButtons(button: byte; state: boolean);
begin
 inherited;
 if (button=1) and not (area in [0,wcClient]) then begin
  if not hooked and state then hooked:=true;
  if hooked and not state then begin
   hooked:=false;
   // Don't allow window center to be moved outside screen
   if x+width<width div 2 then x:=-width div 2;
   if y+height<height div 2 then y:=-height div 2;
   if x>rootWidth-width div 2 then x:=rootWidth-width div 2;
   if y>rootHeight-height div 2 then y:=rootHeight-height div 2;
  end;
 end;
end;

procedure TUIWindow.onMouseMove;
begin
 if hooked then begin
  if area=wcHeader then begin inc(x,curMouseX-oldMouseX); inc(y,curMouseY-oldMouseY); end;
  if area and wcRightFrame>0 then Resize(width+curMouseX-oldMouseX,-1);
  if area and wcBottomFrame>0 then Resize(-1,height+curMouseY-oldMouseY);
  if area and wcLeftFrame>0 then begin Resize(width+oldMouseX-curMouseX,-1); inc(x,curMouseX-oldMouseX); end;
  if area and wcTopFrame>0 then begin Resize(-1,height+oldMouseY-curMouseY); inc(y,curMouseY-oldMouseY); end;
 end;

 inherited;
 area:=GetAreaType(curMouseX-globalRect.Left,curMouseY-globalRect.Top,cursor);
 if area in [0,wcClient] then hooked:=false;
end;

procedure ProcessHotKey(keycode:byte;shiftstate:byte);
var
 i:integer;
 c,r:TUIControl;
begin
 r:=modalcontrol;
 for i:=0 to HotKeysCnt-1 do
  if (HotKeys[i].key=keycode) then
    if (HotKeys[i].shiftstate=shiftstate) or
       ((HotKeys[i].shiftstate>0) and (HotKeys[i].shiftstate and ShiftState=HotKeys[i].shiftstate)) then
     begin
      c:=hotkeys[i].control;
      while (c<>r) and (c.parent<>nil) and c.enabled and c.visible do c:=c.parent;
      if c=r then hotkeys[i].control.onHotKey(keycode,shiftstate);
     end;
end;

procedure TUIWindow.Resize(newWidth, newHeight: integer);
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

procedure TUIWindow.SetFocus;
begin
 inherited;
{ if length(children)>0 then
  SetFocusToNext;}
end;

{ TUIEditBox }

procedure TUIEditBox.AdjustState;
begin
 if cursorpos>length(realtext) then cursorpos:=length(realtext);
 if selstart>length(realtext) then selstart:=length(realtext);
 if selstart+selcount>length(realtext)+1 then selcount:=length(realtext)-selstart+1;
end;

constructor TUIEditBox.Create(cx,cy,w,h: integer; boxName: string;
  boxFont:cardinal;color_:cardinal;parent_:TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_,boxName);
 transpmode:=tmOpaque;
 cursor:=crInput;
 encoding:=defaultEncoding;
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

function TUIEditBox.GetText: string;
begin
 case encoding of
  teUTF8:Result:=UTF8Encode(realtext);
  teWin1251:result:=UTF8toWin1251(UTF8Encode(realtext));
  else result:=realtext;
 end;
end;

procedure TUIEditBox.SetText(s: string);
begin
 case encoding of
  teUTF8:realtext:=DecodeUTF8(s);
  teWin1251:realtext:=DecodeUTF8(Win1251toUTF8(s));
  else realtext:=s;
 end;
 if cursorpos>length(realtext) then cursorpos:=length(realtext);
end;

procedure TUIEditBox.onChar(ch: char; scancode: byte);
begin
 inherited;
end;

procedure TUIEditBox.onUniChar(ch: WideChar; scancode: byte);
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


function TUIEditBox.onKey(keycode: byte; pressed: boolean;shiftstate:byte): boolean;
 var
  str:string;
  step:integer;
  oldText:string;
 procedure ClipCopy(cut:boolean=false);
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
  Signal('UI\'+name+'\changed',0);
 end;
end;

procedure TUIEditBox.onMouseButtons(button: byte; state: boolean);
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
 if UnderMouse<>self then begin
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
 Signal('UI\EditBox\onSetFocus',cardinal(self));
 {$ENDIF}
end;

procedure TUIEditBox.onLostFocus;
begin
 inherited;
 {$IFDEF IOS}
 Signal('UI\EditBox\onLostFocus',cardinal(self));
 {$ENDIF}
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

{ TUIScrollBar }

constructor TUIScrollBar.Create(cx, cy, w, h: integer; barName: string; min_,
  max_, value_: integer; parent_: TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_,barName);
 transpmode:=tmOpaque;
 min:=min_; max:=max_; rValue.Init(value_); pagesize:=0;
 linkedControl:=nil; step:=1;
 color:=$FFB0B0B0;
 horizontal:=w>h;
// hooked:=false;
end;

function TUIScrollBar.GetValue: integer;
begin
 result:=rValue.IntValue;
 if result>max-pagesize then result:=max-pageSize;
 if result<min then result:=min;
end;

procedure TUIScrollBar.Link(ctl: TUIControl);
begin
 LinkedControl:=ctl;
end;

procedure TUIScrollBar.SetValue(v: integer);
begin
 rValue.Assign(v);
end;

function TUIScrollBar.GetAnimating;
begin
  result:=rValue.isAnimating;
end;

procedure TUIScrollBar.MoveRel(delta: integer;smooth:boolean=false);
begin
 MoveTo(round(rValue.FinalValue)+delta,smooth);
end;

procedure TUIScrollBar.MoveTo(val: integer;smooth:boolean=false);
begin
 if val<min then val:=min;
 if val+pagesize>max then val:=max-pagesize;
 if smooth then rValue.Animate(val,300,spline1)
  else rValue.Assign(val);
  
 Signal('UI\'+name+'\Changed',val);
 if linkedControl<>nil then begin
  if linkedcontrol.scrollerH=self then
   linkedControl.scrollX:=value;
  if linkedcontrol.scrollerV=self then
   linkedControl.scrollY:=value;
 end;
end;

procedure TUIScrollBar.onLostFocus;
begin
 if hooked=self then hooked:=nil;
 clipMouse:=cmNo;
end;

procedure TUIScrollBar.onMouseButtons(button: byte; state: boolean);
var
 p:single;
begin
 inherited;
 if state and (hooked=nil) and over then begin
  hooked:=self;
  delta:=-1;
  clipMouse:=cmVirtual;
  clipMouseRect:=globalrect;
 end;
 if (hooked=self) and not state then begin
  hooked:=nil;
  clipmouse:=cmNo;
  signal('Mouse\UpdatePos');
 end;
 if not (over or (hooked=self)) and state and PtInRect(globalrect,Point(curMouseX,curMouseY)) then begin
  if horizontal then
   p:=(curMouseX-globalrect.Left-5)/(width-10)
  else
   p:=(curMouseY-globalrect.Top-5)/(height-10);
  if p<0 then p:=0;
  if p>1 then p:=1;
  MoveTo(min+round((max-min-pagesize)*p));
  onMouseMove;
  onMouseButtons(button,true);
 end;
end;

procedure TUIScrollBar.onMouseMove;
var
 p1,p2:single;
 v:integer;
// posChanged:boolean;
begin
 inherited;
 if delta=-1 then begin
  p1:=(value-min)/(max-min);
  if p1<0 then p1:=0;
  if horizontal then delta:=curMouseX-globalrect.Left-round(p1*(width-10))
   else delta:=curMouseY-globalrect.top-round(p1*(height-10));
 end;

// posChanged:=false;
 if hooked=self then
  if horizontal then begin
   p1:=(curMouseX-delta-globalrect.Left)/(width-10);
   if p1<0 then p1:=0; if p1>1 then p1:=1;
   v:=round(min+(max-min)*p1);
   if v<>value then begin
    MoveTo(v);
//    posChanged:=true;
   end;
  end else begin
   p1:=(curMouseY-delta-globalrect.top)/(height-10);
   if p1<0 then p1:=0; if p1>1 then p1:=1;
   v:=round(min+(max-min)*p1);
   if v<>value then begin
    MoveTo(v);
//    posChanged:=true;
   end;
  end;
// else posChanged:=true;

 p1:=(value-min)/(max-min);
 p2:=(value+pagesize-min)/(max-min);
 if p1<0 then p1:=0;
 if p2>1 then p2:=1;
 if horizontal then begin
//  if posChanged then
  over:=(curMouseY>=globalrect.Top) and (curMouseY<globalrect.Bottom) and
        (curMouseX>=globalrect.Left+round(p1*(width-10))) and
        (curMouseX<globalrect.Left+10+round(p2*(width-10)));
 end else begin
//  if posChanged then
  over:=(curMouseX>=globalrect.Left) and (curMouseX<globalrect.Right) and
        (curMouseY>=globalrect.Top+round(p1*(height-10))) and
        (curMouseY<globalrect.top+10+round(p2*(height-10)));
 end;
end;

procedure TUIScrollBar.UseButtons(lessBtn, moreBtn: string);
begin

end;

{ TUISkinnedWindow }

constructor TUISkinnedWindow.Create(wndName, wndCaption: string;
  wndFont: cardinal; parent_: TUIControl;canmove:boolean=true);
begin
 inherited Create(0,0,100,100,false,wndName,wndCaption,wndFont,parent_);
 dragRegion:=nil;
 background:=nil;
 moveable:=canmove;
 ncTop:=0; ncLeft:=0;
 ncRight:=0; ncBottom:=0;
end;

destructor TUISkinnedWindow.Destroy;
begin
 dragRegion.Free;
 inherited;
end;

function TUISkinnedWindow.GetAreaType(x, y: integer; out cur: integer): integer;
begin
 result:=0; cur:=crDefault;
 if (x<0) or (y<0) or (x>=width) or (y>=height) then exit;
 if moveable then result:=wcHeader else result:=wcClient;
 if (dragRegion<>nil) and not dragRegion.TestPoint(x,y) then
  result:=wcClient;
end;

{ TUIHint }

constructor TUIHint.Create(cx,cy: integer; stext: string;
  act: boolean; parent_: TUIControl);
begin
 inherited Create(cx,cy,1,1,'hint',parent_);
 transpmode:=tmOpaque;
 font:=0;
 simpleText:=stext;
 active:=act;
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
 if transpmode<>tmTransparent then begin
  LogMessage('UIHint Hide');
  transpmode:=tmTransparent;
  created:=MyTickCount;
 end;
end;

procedure TUIHint.onMouseButtons(button: byte; state: boolean);
begin
 inherited;
 if state then hide;
end;

procedure TUIHint.onTimer;
begin
 hide;
end;

{ TUIScrollArea }

constructor TUIScrollArea.Create(cx, cy, w, h, fullW, fullH: integer;
  dir: TUIScrollDirection;parent_:TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_);
 transpmode:=tmOpaque;
 fullWidth:=fullW;
 fullHeight:=fullH;
 direction:=dir;
end;

procedure TUIScrollArea.onMouseButtons(button: byte; state: boolean);
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

procedure TUIListBox.AddLine(line: string;tag:cardinal=0;hint:string='');
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

constructor TUIListBox.Create(cx, cy, w, h, lHeight: integer; listName:string; font_:cardinal; parent: TUIControl);
begin
 inherited Create(cx,cy,w,h,parent,listName);
 transpmode:=tmOpaque;
 font:=font_;
 lineHeight:=lHeight;
 selectedLine:=-1;
 hoverLine:=-1;
 canHaveFocus:=true;
 sendSignals:=ssMajor;
 scrollerV:=TUIScrollBar.Create(w-19,0,19,h-2,'lbScroll',0,0,0,self);
 scrollerV.horizontal:=false; 
 scrollerV.AnchorLeft:=false;
 scrollerV.AnchorRight:=true;
 scrollerV.AnchorBottom:=true;
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

procedure TUIListBox.onMouseButtons(button: byte; state: boolean);
begin
 inherited;
 if (button=1) then begin
  if hoverLine>=0 then begin
   selectedLine:=hoverLine;
   if sendSignals<>ssNone then begin
    Signal('UI\'+name+'\SELECTED',selectedLine);
    Signal('UI\ListBox\onSelect\'+name,PtrUInt(self));
   end;
  end;
 end;
end;

procedure TUIListBox.onMouseMove;
var
 cx,cy,n:integer;
begin
 inherited;
 cx:=curMouseX-(globalRect.Left+1);
 cy:=curMouseY-(globalRect.Top+1);
 if (cx>=0) and (cy>=0) and (cx<width-1) and (cy<height-1) then begin
  n:=(cy+scrollerV.value) div lineHeight;
  if (n>=0) and (n<length(lines)) then hoverLine:=n
   else hoverLine:=-1;
 end;
 if autoSelectMode then selectedLine:=hoverLine;
 hint:='';
 if (hoverLine>=0) and (hoverLine<=high(hints)) then hint:=hints[hoverLine];
end;

procedure TUIListBox.SetLine(index: integer; line: string; tag: cardinal=0;hint:string='');
begin
 lines[index]:=line;
 tags[index]:=tag;
 hints[index]:=hint;
 UpdateScroller;
end;

procedure TUIListBox.SetLines(newLines: StringArr);
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
begin
 scrollerV.max:=length(lines)*lineHeight;
 scrollerV.step:=lineheight*(height div 2 div lineHeight);
 scrollerV.pagesize:=height;
 scrollerV.height:=height;
 scrollerV.visible:=scrollerV.max>height;
end;

{ TUIFrame }

constructor TUIFrame.Create(cx, cy, w, h, depth,style_: integer; parent_: TUIControl);
begin
 inherited Create(cx,cy,w,h,parent_,'UIFrame');
 transpmode:=tmOpaque;
 borderWidth:=depth;
 style:=style_;
 ncLeft:=depth; ncTop:=depth;
 ncRight:=depth; ncBottom:=depth;
end;

{ TUIConboBox }

procedure TUIComboBox.AddItem(item: WideString; tag: cardinal; hint: WideString);
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

constructor TUIComboBox.Create(x_,y_, width_,height_:integer; bFont:cardinal; list: WStringArr;
  parent_: TUIControl;name:string);
var
 btn:TUIButton;
 i,j:integer;
begin
 inherited Create(x_,y_,width_,height_,name,'',bFont,parent_);
 transpmode:=tmOpaque;
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
 frame:=TUIFrame.Create(0,0,width,2,1,0,nil);
 frame.visible:=false;
 popup:=TUIListBox.Create(0,0,width-2,0,20,'ComboBoxPopUp',font,frame);
 popUp.customPtr:=self;
// popup.autoSelectMode:=true;
 popup.bgColor:=$FFFFFFFF;
 popup.textColor:=$FF000000;
 popup.bgHoverColor:=$FF405090;
 popup.hoverTextColor:=$FFFFFFFF;
 popup.bgSelColor:=$FF405090;
 popUp.selTextColor:=$FFFFFFFF;
end;

procedure TUIComboBox.onDropDown;
var
 root:TUIControl;
 r:TRect;
 lCount,lHeight,i:integer;
 hint:WideString;
 tag:cardinal;
begin
 if not frame.visible then begin
  if comboPop<>nil then comboPop.onDropDown;
  root:=GetParent;
  r:=GetPosOnScreen;
  frame.x:=r.Left-root.x;
  frame.y:=r.Bottom+1-root.y;
  frame.width:=width;
  frame.AttachTo(root);
  lCount:=length(items);
  if lCount>=maxlines then lCount:=round(maxLines*0.75);
  // size and position
  lHeight:=popup.lineHeight;
  popup.height:=lHeight*lcount;
  popup.width:=frame.width-2*frame.borderWidth;
  frame.height:=popup.height+frame.borderWidth*2;
  if r.Bottom+frame.height>=rootHeight then
   frame.y:=r.Top-1-frame.height;
  // Content
  popUp.ClearLines;
  for i:=0 to high(items) do begin
   if i<=high(hints) then hint:=EncodeUTF8(hints[i])
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
  comboPop:=nil;
  i:=curItem;
  if popup.selectedLine>=0 then curItem:=popup.selectedLine;
  if curItem<>i then begin
   Signal('UI\'+name+'\ONSELECT',i);
   Signal('UI\COMBOBOX\ONSELECT\'+name,PtrUInt(self));
  end;
  frame.visible:=false;
  timer:=0;
 end;
end;

procedure TUIComboBox.onLostFocus;
begin
 inherited;
// if popup<>nil then onDropDown;
end;

procedure TUIComboBox.onMouseButtons(button: byte; state: boolean);
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
  if (popup.selectedLine>=0) or (focusedControl<>self) then onDropDown;
 end;
end;

procedure TUIComboBox.SetCurItem(item: integer);
begin
 fCurItem:=item;
 if (item>=0) and (item<=high(items)) then caption:=EncodeUTF8(Items[fCurItem])
  else caption:=EncodeUTF8(defaultText);
 if (item>=0) and (item<=high(tags)) then fCurTag:=tags[item]
  else fCurTag:=-1;
end;

procedure TUIComboBox.SetCurItemByTag(tag: integer);
begin
 SetCurItem(FindInteger(tags,tag));
end;

procedure TUIComboBox.SetItem(index: integer; item: WideString; tag: cardinal;
  hint: string);
begin
 items[index]:=item;
 tags[index]:=tag;
 hints[index]:=hint;
end;

procedure TUIFrame.SetBorderWidth(w: integer);
begin
 borderWidth:=w;
 ncLeft:=w; ncRight:=w; ncBottom:=w; ncTop:=w;
end;

initialization
 InitCritSect(UICritSect,'UI',30);
// InitializeCriticalSection(UICritSect);
 toDelete:=TObjectList.Create;

 TUIControl.handleMouseIfDisabled:=false;
 TUIButton.handleMouseIfDisabled:=true;
 TUIComboBox.handleMouseIfDisabled:=false;
finalization
 DeleteCritSect(UICritSect);
end.
