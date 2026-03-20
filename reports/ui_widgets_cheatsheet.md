# Apus Engine UI — Widget & Layouter Cheat Sheet

Описывает **целевое** API. Пометка `[⚙ не реализовано]` означает что в текущем коде
это ещё не так, но именно к этому нужно прийти. Код следует писать по этому документу —
несоответствие текущего кода документу = технический долг, который нужно устранять.

Все виджеты: `Apus.Engine.UI` (реэкспорт из UITypes + UIWidgets + UILayout).
Общий паттерн конструктора: `Create(width, height, parent, name='')`.
`width`/`height = -1` → `FILL_PARENT` (заполнить родителя).
Класс-дефолты: `TUIXxx.SetDefault('key', value)`.
Поиск по имени: `UIButton('name')`, `UILabel('name')`, etc.

---

## Виджеты

| Класс | Назначение | Конструктор | Ключевые свойства / методы |
|---|---|---|---|
| **TUIElement** | Базовый класс и универсальный контейнер | `Create(w,h,parent,name='')` | `position`, `size`, `pivot`, `scale`, `padding`, `scroll`, `anchors`, `layout`, `caption`, `hint`, `order`, `flags` |
| **TUIGroupBox** | Контейнер с отслеживанием активного ребёнка; родитель для radio-группы | `Create(w,h,parent,name='')` | `selectedChild:integer` (-1=нет) |
| **TUIScrollable** | Базовый класс для прокручиваемого контента | — (абстрактный) | `scrollerH`, `scrollerV:IScroller`; подключение: `TUIScrollBar.Link(elem)` |
| **TUISplitter** | Разделитель / спейсер между элементами | `CreateH(height,parent,color=0,name='')` `CreateV(width,parent,color=0,name='')` | `canResize:boolean`; `SetPaddings` задаёт поля вокруг линии; `color=0` → чистый спейсер |
| **TUIImage** | Статичное изображение или область с кастомным рендером | `Create(w,h,parent,name='',source='')` | `src:String8` (`'file:...'`, `'proc:...'`, `'event:...'`); `SetRenderProc(proc)`; `shape` по умолчанию `shapeEmpty` → мышь проходит насквозь |
| **TUIScrollArea** | Оверлей для тач-скролла поверх другого элемента | `Create(w,h,parent,name='')` | `Setup(fullW,fullH,dir)`; `direction:TUIScrollDirection`; перехватывает drag, пропускает клики |
| **TUILabel** | Текстовая метка (read-only) | `Create(w,h,parent,name='')` | `align`, `autoSize`, `verticalOffset`; fluent: `.Setup(text)`, `.Centered(text)`, `.Right(text)` |
| **TUIButton** | Кнопка (нажал → отпустил → клик) | `Create(w,h,parent,name='')` `.Setup(caption)` | `onClick`, `onClickAsync`, `pressed`, `default`, `pending`, `autoPendingTime`; `Click` — программный клик; `Sender` — кто кликнул |
| **TUIToggleButton** | Кнопка с фиксацией состояния | `Create(w,h,parent,name='')` `.Setup(caption,toggled=false)` | `toggled:boolean`, `linkedToggled:PBoolean`, `SetToggled(v)`; в TUIGroupBox-родителе — radio, иначе — независимый; `GetSwitchIndex(parent)` |
| **TUICheckBox** | Чекбокс (TUIToggleButton с другим рендером) | `Create(w,h,parent,name='')` `.Setup(caption,checked=false)` | `checked:boolean` (alias для `toggled`) |
| **TUIRadioButton** | Радиокнопка; помести в TUIGroupBox для radio-поведения | `Create(w,h,parent,name='')` `.Setup(caption,checked=false)` | Наследует логику TUICheckBox; radio-поведение — через TUIGroupBox-родителя |
| **TUIEditBox** | Однострочный ввод текста | `Create(w,h,parent,name='')` | `text:String8`, `defaultText` (placeholder), `completion`, `maxLength`, `password`, `selStart/Count`; сигнал `UI\name\Enter` |
| **TUIScrollBar** | Полоса прокрутки (H или V — по соотношению w/h) | `Create(w,h,parent,name='')` `Create(w,h,min,max,pageSize,value,parent,name='')` | `min`,`max`,`pageSize`,`step`,`value`,`autoHide`; `SetRange`, `Link(scrollable)`, `MoveTo(val,smooth)` |
| **TUIListBox** | Список текстовых строк с выбором | `Create(w,h,parent,name='',lHeight=0)` | `lines`, `selectedLine`, `hoverLine`, `lineHeight`, `autoSelectMode`; `SetLines([...])`, `AddLine`, `SelectLine(i)` |
| **TUIComboBox** | Выпадающий список (кнопка + popup) | `Create(w,h,parent,name='',list=nil)` | `items`, `curItem`, `curTag`, `text`, `defaultText`, `maxlines`; `AddItem`, `SetCurItem/ByText/ByTag` |
| **TUIFrame** | Декоративная рамка / бордюр | `Create(w,h,parent,depth=1)` | `borderWidth`; внутри используется TUIComboBox для popup-контейнера |
| **TUIWindow** | Перемещаемое/масштабируемое окно | `Create(innerW,innerH,sizeable,parent,name='',caption='')` | `header`, `moveable`, `resizeable`, `autoBringToFront`, `minW/H`, `maxW/H`; `GetAreaType` для нестандартных форм |
| **TUISkinnedWindow** | Окно с кастомным фоном, без стандартной рамки | `Create(parent,name='',caption='',canmove=true)` | `dragRegion:TUIShape`, `background:pointer`; padding=0; фон рисуется внешне |
| **TUIHint** | Всплывающая подсказка | `Create(x,y,text,parent)` | `simpleText`, `active`, `hiding`; хелпер: `ShowSimpleHint(msg,parent,x,y,time)` |

---

## Стилизация

Целевая модель (R-05): каждый элемент имеет одно свойство `style:String8` с CSS-подобным
синтаксисом. Стили каскадируются от предков, поддерживают состояния и transitions.

```pascal
// Целевой синтаксис (R-05):
element.style := 'fill:#2080FF; border:#000; radius=6; hover.fill:#40A0FF';
```

**Текущее состояние (временное, будет удалено):**

| Что есть сейчас | Целевое | Статус |
|---|---|---|
| `styleInfo:String8` | `style:String8` | `[⚙ не реализовано]` — переименование + новая семантика |
| `styleClass:byte` | ссылка на Drawer-объект через класс | `[⚙ не реализовано]` |
| `font:TFontHandle` на TUIElement | шрифт через style | `[⚙ не реализовано]` |
| `color:cardinal` на TUIElement | цвет через style | `[⚙ не реализовано]` |
| Цвета TUIListBox (`bgColor`, `textColor` и др.) | через style | `[⚙ не реализовано]` |

До реализации R-05 использовать `styleInfo` и `font`/`color` как есть, но не закладываться
на их семантику в новом коде — они временные.

---

## Layouters

Присваивается в `element.layout := TXxxLayout.Create(...)`.
Вызывается автоматически при изменении детей.

| Класс | Назначение | Конструкторы | Параметры |
|---|---|---|---|
| **TRowLayout** | Строка или колонка из дочерних элементов | `CreateHorizontal(space=0, resize=false, center=false)` `CreateVertical(space=0, resize=false, center=false)` | `spaceBetween` — отступ между элементами; `resizeToContent` — родитель сжимается по содержимому; `center` — центрирование по поперечной оси |
| **TFlexboxLayout** | Flexbox: элементы с весом растягиваются пропорционально | `Create(spaceBetween=0)` `CreateVertical(spaceBetween=0)` | `element.layoutData` — вес элемента (0 = фиксированный размер) |
| **TGridLayout** | Сетка с автоматическим переносом | `Create(spaceV,spaceH,paddingH,paddingV,center=false)` `CreateResizeable(spaceV,spaceH,paddingH,paddingV,desiredItemWidth)` | `desiredItemWidth` определяет число колонок; `CreateResizeable` — элементы растягиваются до ширины колонки |

---

## Контейнерные хелперы

```pascal
// Вертикальный контейнер — три перегрузки:
CreateVerticalContainer(width, height, parent, padding, spacing, centering, name='')
CreateVerticalContainer(width, parent, padding, spacing, centering, name='')  // авто-высота
CreateVerticalContainer(parent, padding, spacing, centering, name='')          // вся область родителя

// Горизонтальный контейнер:
CreateHorizontalContainer(height, parent, padding, spacing, name='')
```

---

## Размерные константы

| Константа | Значение | Контекст |
|---|---|---|
| `FILL_PARENT` / `USE_PARENT` | `-1` | `Create(w,h,...)` — заполнить клиентскую ширину или высоту родителя |
| `uiKeep` | `-1` | `Resize(w,h)` — не менять это измерение |
| `uiInherit` | `-999999` | `Resize(w,h)` — взять `clientWidth`/`clientHeight` родителя |

---

## Anchors

`SetAnchors(left,top,right,bottom)` — доля от delta-resize родителя, которую поглощает каждая сторона.
`0` = не привязана, `1` = полностью следует за стороной родителя, `0.5` = следует за центром.

| Константа | Поведение |
|---|---|
| `anchorAll` | Все 4 стороны: растягивается вместе с родителем |
| `anchorNone` | Ничего не привязано: остаётся в top-left |
| `anchorTop` | Полоса сверху (L+T+R) |
| `anchorBottom` | Полоса снизу (L+B+R) |
| `anchorLeft` | Полоса слева (L+T+B) |
| `anchorRight` | Полоса справа (R+T+B) |
| `anchorCenter` | Двигается с центром родителя (0.5 по всем) |
| `anchorTopRight` | Угол top-right |
| `anchorBottomLeft/Right` | Угловые привязки |
| `anchorTopCenter` / `anchorBottomCenter` | Центрированные полосы |

---

## Иерархия классов

```
TUIElement
├── TUIGroupBox          ← radio-контейнер, tab-панель
├── TUIScrollable
│   ├── TUIImage         ← изображение, кастом-рендер
│   │   ├── TUIHint
│   │   └── TUIWindow
│   │       └── TUISkinnedWindow
│   └── TUIListBox
├── TUISplitter
├── TUIScrollArea
├── TUILabel
├── TUIEditBox
├── TUIScrollBar
├── TUIFrame
└── TUIButton
    ├── TUIToggleButton
    │   ├── TUICheckBox
    │   │   └── TUIRadioButton
    └── TUIComboBox
```
