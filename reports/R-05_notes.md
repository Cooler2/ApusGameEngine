# R-05: Style System Rework Notes
Created: 2026-03-11
Updated: 2026-03-23

## Цель
Заменить `styleClass:byte` + `styleInfo:String8` в TUIElement на полноценную CSS-like style-систему:
- единый источник истины для визуальных атрибутов элемента;
- поддержка именованных стилей (`@ref`), состояний (`:hover {}`), patch-операций;
- drawer-agnostic: TStyleBlock не знает семантику ключей, семантику знает drawer;
- backward-compatibility не планируется — чистая замена.

---

## Текущий API

### TStyleBlock (`Apus.Engine.Style.pas`)

Парсинг и замена:
```pascal
block.ParseText('color: $FF1E3D6E; text-color: $FFCCE0FF;');
block.PatchText('+color: $FF223344; -border-width; +@accent;');
block.Clear;
```

Атрибуты:
```pascal
block.SetAttr('color', '$FF1E3D6E');
block.RemoveAttr('border-width');
block.HasAttr('color');      // local only
block.GetValue('color');     // local + active states, no refs
block.GetColor('color');
block.GetNumber('font-size');
block.GetInt('border-width');
block.GetScaledNumber('font-size', scale, defVal);
block.GetStateValue('hover', 'color'); // state-specific lookup
block.GetText;               // reconstruct style text (debug/serialization)
```

Ссылки:
```pascal
block.AddRef('accent');
block.RemoveRef('accent');
// block.refs — публичный массив Strings8
```

Состояния:
```pascal
block.SetState('hover', true);
block.HasState('hover');
// block.activeStates — comma-separated string
```

Глобальный реестр именованных стилей:
```pascal
RegisterNamedStyle('demo-btn', namedBlock);  // ownership переходит к реестру
found := FindNamedStyle('demo-btn');
ClearNamedStyles;
```

Резолв с учётом @refs:
```pascal
ResolveBlockAttr(block, 'color');
ResolveBlockColor(block, 'color', defVal);
ResolveBlockNumber(block, 'font-size', defVal);
```

Парсинг цвета:
```pascal
ParseStyleColor('$AARRGGBB');  // $AARRGGBB, $RRGGBB, #RRGGBB, #RGB, #ARGB
```

### TUIElement style access (`Apus.Engine.UITypes.pas`)

`element.style` — единая точка доступа, `TStyleBlock`, создаётся в конструкторе (eager):
```pascal
element.style.Assign('color: $FF1E3D6E; :hover { color: $FF2E5DA0; }');
element.style.Add('+border-width: 2;').Add('-@old;');  // chainable
s := element.style.Text;

element.style.SetState('hover', true);
element.style.HasState('hover');
```

Shortcuts на элементе (тонкие обёртки над `style`):
```pascal
element.SetState('hover', true);   // = element.style.SetState(...)
element.HasState('hover');         // = element.style.HasState(...)
```

Resolver (остаётся на элементе — учитывает cascade через parent chain):
```pascal
element.GetStyleValue('color');           // String8
element.GetStyleColor('color', defVal);   // cardinal
element.GetStyleNumber('font-size', defVal);
element.GetStyleInt('border-width', defVal);
```

Drawer:
```pascal
element.drawer := MyDrawProc;     // приоритет над styleClass
element.styleClass := 2;          // legacy numeric, deprecated
```

---

## Синтаксис стиля

### Базовый блок
```
color: $FF1E3D6E;
text-color: $FFCCE0FF;
border-width: 1;
border-color: $FF3060A0;
fill: $BF102030;
```

### Ссылки на именованные стили
```
@button;
@accent;
color: $FFFFFFFF;   // локальные атрибуты перекрывают refs
```
Приоритет: более поздние refs имеют более высокий приоритет среди refs.
Локальные атрибуты всегда перекрывают refs.

### State overrides
```
color: $FFE0E0E0;
:hover   { color: $FFFFFFFF; }
:pressed { color: $FFB0B0B0; }
:disabled { color: $FF808080; }
```
State-блоки имеют наивысший приоритет.
Набор состояний открытый — элемент сам задаёт свои состояния через `SetState`.

### Patch-операции (`PatchText`)
```
+color: $FF223344;   -- добавить/перезаписать атрибут
-border-color;       -- удалить атрибут
+@accent;            -- добавить ref
-@oldTheme;          -- удалить ref
!state:hover;        -- активировать состояние
!state:-hover;       -- деактивировать состояние
```
Несколько операций разделяются `;`.

### Цветовые форматы
- `$AARRGGBB` — основной формат движка
- `$RRGGBB` — без альфа (AA = FF)
- `#RRGGBB` / `#RGB` / `#ARGB` — CSS-совместимые

### Каскад приоритетов (от низшего к высшему)
1. `@refs` в порядке декларации (более поздние — выше)
2. Локальные атрибуты элемента
3. Активные state overrides

---

## Архитектурные решения

**Drawer-agnostic style.**
TStyleBlock не знает семантику ключей. Один блок хранит параметры любого drawer.
При смене drawer стиль не пересоздаётся — drawer читает только свои ключи.
Специфичные ключи рекомендуется пространствовать: `bmp.*`, `rich.*`, `custom.*`.

**Enum-параметры (stretch, fit и т.п.).**
Хранятся как строки. Валидация — на стороне drawer при чтении.
Drawer видит неизвестное значение → логирует предупреждение, использует default.

**Состояния.**
Открытый набор. Элемент сам управляет своими состояниями.
`TContext.Update` (DefaultStyle) автоматически синхронизирует `hover`/`pressed`/`disabled`
через `element.SetState` — CSS `:state {}` блоки работают без ручной логики в drawer.

**Именованные стили.**
`FindNamedStyle` при вызове ходит по реестру без кэша.
Изменение named style через `ParseText` сразу видно всем элементам с `@ref` — без дополнительных инвалидаций.

**Кэширование.**
Намеренно не проектируется заранее. Текущий подход (resolve на каждый вызов) корректен и достаточен.
Dirty-флаги и revision-based invalidation — задача следующих итераций, когда появится реальный профиль производительности.

**Transitions.**
State-changes сейчас мгновенные. Transitions будут реализованы через Tweenings (не AnimatedValue).
Tweenings пока не готовы — архитектура (`:state {}` блоки, `SetState`) уже правильная и не потребует переработки.

**Шрифты.**
UI-элементы не хранят font handle — шрифт задаётся через style как логический атрибут.
`GetFont` в TUIElement уже проверяет `styleBlock` для `font`/`font-size`.
Для прямой отрисовки (txt.Write) хэндлы хранятся как threadvar; `game.SelectFonts(scale)` вызывается из потока окна.

**Профили drawer.**
DefaultStyle — лёгкий базовый профиль.
RichImageStyle / AdvancedStyle — расширенные профили (future), совместимые по базовому API.
Все профили используют один TStyleBlock; drawer читает только свои ключи.

**Границы ответственности.**
Style отвечает только за визуализацию.
Позиционирование и сайзинг — в layout.
Overflow/clipping/z-index — свойства элемента, не style-системы.

---

## Статус реализации

### Фаза 1 — DONE: Базовая инфраструктура

- `Apus.Engine.Style.pas` — TStyleBlock, реестр named styles, парсер, @refs, state-блоки, patch, ResolveBlock*
- `Apus.Engine.UITypes.pas` — поле `styleBlock:TStyleBlock` (lazy), методы SetStyleText/PatchStyleText/SetState/HasState/GetStyle*
- `Apus.Engine.UITypes.pas` — поле `drawer:TUIDrawer` (приоритет над styleClass)
- `Apus.Engine.DefaultStyle.pas` — TContext.Update синхронизирует hover/pressed/disabled через element.SetState
- `tests/TestStyle.dpr` — 38 unit tests: парсинг, state-блоки, @refs, patch, GetColor/GetNumber

### Фаза 2 — DONE: Миграция draw-процедур

- `DrawUIButton`, `DrawUICheckbox`, `DrawUIFrame` — переведены с `eStyle.GetColor` на `control.GetStyleColor`
- `Apus.Engine.UIRender.pas` — `GetUIStyle(n:byte):TUIDrawer` для backward-compat numeric API
- `DrawUIElement` — предпочитает `item.drawer` если задан, иначе fallback на `styleDrawers[styleClass]`
- Мигрированы: TweakScene, CustomStyle, UIScene (hint), UIScript
- `DrawCommonStyle`, `DrawUIScrollbar` — **не мигрированы** (используют AnimatedValue hover-переходы, нужны Tweenings)

### Фаза 3 — DONE: Transitions (2026-03-24)

- `TContext` (DefaultStyle): `TAnimatedValue` → `TTweening` для hover/active/disabled; добавлен `Destroy`
- `DrawCommonStyle`: мигрирован на `element.style` (CSS `:hover {}` блоки + blend с `context.hover.Value`)
- `DrawUIButton`: smooth transitions hover/press/disabled через TTweening факторы
- `TStyleBlock`: добавлены `GetStateColor`, `GetStateNumber` (typed accessor для state-блоков)
- `TUIElement`: добавлены `GetBaseStyleColor`, `GetBaseStyleNumber` (cascade без state overrides)
- `ResolveBlockAttrBase`, `ResolveBlockColorBase` — resolve без активных состояний
- Исправлены дублирующие `{$MODE DELPHI}` в `Base/Apus.Containers.pas` и `Base/Apus.Images.pas`

### Демо — DONE

- `demo/StyleDemo/` — отдельный проект, 6 кнопок:
  - Btn1: default style (baseline)
  - Btn2: `style.Assign` с явным цветом
  - Btn3: `@demo-btn` (named ref)
  - Btn4: `:hover` / `:pressed` state blocks + smooth transitions
  - Btn5: disabled + `:disabled { text-color }` + smooth disabled transition
  - Btn6: Toggle @ref — меняет `@demo-btn`, Btn3 обновляется автоматически

---

## Следующие шаги

- [x] `DrawCommonStyle` — переведён на новую систему (2026-03-24)
- [x] Transitions через Tweenings (2026-03-24)
- [x] `DrawUIScrollbar` — мигрирован на `element.style`; `TElementStyle` удалён полностью (2026-03-24)
- [x] Убрать `fFont`/`fColor` из TUIElement — `font`/`color` property, GetFont/GetColor, Setup params удалены; rendering читает через `StyleFont()`/`GetStyleColor()`; UIScript GetValue обновлён (2026-03-24)
- [ ] Поддержка переменных через Apus.Publics (`$varName` в style text)
- [x] `element.style` как единая точка доступа: поле `style:TStyleBlock` создаётся в конструкторе (eager), `SetStyleText`/`PatchStyleText`/`EnsureStyleBlock` удалены — используется `style.Assign`/`style.Add` (2026-03-23)
- [x] TStyleCatalog с индексером `Styles['name'] := '...'` — `RegisterNamedStyle`/`FindNamedStyle`/`ClearNamedStyles` удалены из интерфейса; `Styles.Block('name')` для drawers (2026-03-24)
- [ ] Visual regression tests через Robot API `pixel` + `ui.element`

---

## Квёрки и известные ограничения

**ParseStyleColor с 3-символьными строками:**
`'xyz'` интерпретируется как `#xxyyzz` (нет валидации hex-символов).
Не критично — невалидные значения дадут неожиданный цвет, не crash.

**styleClass — deprecated, не удалён:**
`UI.pas` и `UIWidgets.TUIFrame.Create` по-прежнему пишут `styleClass` из-за circular dependency (UI→UIRender→UI→UIWidgets). Остаётся до решения circular deps.

**GetValue vs ResolveBlockAttr:**
`block.GetValue(key)` — только local + active states, **без** @refs.
`ResolveBlockAttr(block, key)` — local + states + @refs (рекурсивно).
`element.GetStyleColor(...)` использует ResolveBlockAttr — правильный путь для drawer.

---

## История изменений

- 2026-03-11: создан документ, зафиксированы требования и архитектурные решения.
- 2026-03-12: добавлены решения по переменным, layout/style boundary, image/9-patch.
- 2026-03-14: добавлены решения по шрифтам и game.userScale.
- 2026-03-23: реализованы фазы 1 и 2; создано StyleDemo; удалён legacy `[state]` синтаксис;
  документ переработан — убраны устаревшие предварительные разделы, добавлена секция текущего API.
