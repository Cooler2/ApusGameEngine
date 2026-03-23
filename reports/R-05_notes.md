# R-05: Style System Rework Notes
Created: 2026-03-11
Updated: 2026-03-12

## Назначение
Рабочий документ для уточнения конкретики по задаче `R-05`:
- идеи;
- принятые решения;
- вопросы для обсуждения.

## Зафиксировано (из постановки)
1. Меняем модель стиля:
- `styleInfo` переименовывается в `style`;
- числовой `style` заменяется ссылкой на объект `Drawer`, который отвечает за отрисовку элемента;
- если `Drawer=nil`, используем Drawer предка;
- если по цепочке предков Drawer не найден, используется default style.

2. `style` становится полноценным свойством для текстового стиля:
- чтение/запись строкового описания стиля;
- операции уровня `AddStyle`, `RemoveStyle` и подобные;
- точный API фиксируем позже после анализа картины целиком.

3. Из `TUIElement` убираем визуальные поля `color/font`:
- в элементе не должно оставаться визуальных атрибутов;
- все атрибуты визуализации берутся из стиля.

4. Отдельный special case: render feedback:
- допустимы данные, которые нужны элементу для обработки ввода и зависят от рендера;
- пример: позиции символов в `EditBox`, чтобы корректно обрабатывать мышь/курсор.

5. Формат стиля текстовый, в духе CSS:
- пример: `font: Roboto; font-size: 12; color: $FF8090A0`;
- поддерживается наследование атрибутов от предка;
- поддерживаются относительные модификаторы, например `font-scale: 120%`.

6. Объект стиля:
- умеет резолвить итоговые значения атрибутов;
- умеет кэшировать резолвленные значения;
- смена стиля элемента инвалидирует кэш дочерних элементов.

7. Поддерживаются состояния стиля:
- например: `hover`, `pressed`, `disabled` и т.д.

8. Поддерживаются табличные (именованные) стили:
- ссылка вида `@button`;
- изменение табличного стиля должно автоматически влиять на все элементы, где он используется.

## Наблюдения по текущей архитектуре UI
1. Уже есть близкая базовая структура:
- в `TUIElement` есть `styleClass:byte` (выбор drawer по числу) и `styleInfo:String8` (строковые атрибуты);
- в `Apus.Engine.UIRender` есть глобальная регистрация `RegisterUIStyle(style:byte; drawer:TUIDrawer; ...)`.

2. Сейчас `font/color` живут в `TUIElement` и наследуются через `GetFont/GetColor`:
- это ровно та часть, которую нужно перенести в style-резолвер, не потеряв текущее поведение наследования.

3. В default style уже есть часть механики, на которую можно опереться:
- парсинг style-строки;
- кэш стилей;
- state-логика (`hover/active/disabled`) в `TContext`.

4. В виджетах много кода, который напрямую пишет `font/color`:
- конструкторы `TUILabel`, `TUIButton`, `TUIEditBox`, `TUIListBox` и др.;
- это означает, что понадобится миграционный слой, чтобы не ломать существующие вызовы сразу.

## Идеи и замечания (предварительно)
1. Ввести явные понятия:
- `Drawer` как стратегия рендера;
- `Style` как декларативный набор атрибутов;
- `ResolvedStyle` как вычисленный кэш с учетом наследования, состояний и ссылок `@name`.

2. Для инвалидации кэша использовать dirty-каскад:
- при изменении style/drawer/state у узла помечаем узел и потомков dirty;
- пересчёт резолва ленивый, по факту доступа при draw/hit-test.

3. Для `@button` и других ссылок нужен реестр + обратные зависимости:
- таблица именованных стилей `name -> style node`;
- индекс подписок `name -> list of elements/styles`, чтобы точечно инвалидировать кэш при обновлении.

4. Состояния стоит оставить открытым набором:
- элемент сам определяет и обновляет состояния;
- стиль/резолвер учитывает state-строку (или state-map), без жёстко зашитого списка состояний в ядре.

5. Render feedback лучше держать отдельно от style:
- например, отдельный `renderFeedback`-объект/интерфейс у элемента;
- это оставляет элемент "без визуальных атрибутов", но с нужными данными для input hit-testing.

6. Риск миграции:
- код, который сейчас опирается на `element.font/element.color`, нужно переводить целенаправленно и быстро;
- backward-compatibility слой не планируем, но фиксируем минимальный безопасный порядок перевода модулей.

## Вопросы для обсуждения
1. Финализировать grammar/syntax спецификацию (style text + patch-операции + refs + states).
2. Зафиксировать полные правила каскада и приоритетов (`@refs` -> local -> states -> transitions).
3. Определить список атрибутов v1 для default style и их метаданные (тип/наследуемость/анимируемость).
4. Спроектировать transitions-синтаксис и runtime-слой (`AnimatedValue` сейчас, `Tweenings` как расширение).
5. Зафиксировать API для style-операций из кода и из скриптов.

## Решения после обсуждения (2026-03-11)
1. `Drawer`:
- сейчас остаётся процедурой отрисовки элемента;
- если потребуется больше состояния/полиморфизма, целевая эволюция: class-based drawer (скорее класс, чем объект-экземпляр).

2. Ссылки на табличные стили:
- в одном стиле поддерживаются множественные ссылки;
- это аналог множественного наследования;
- приоритет определяется порядком записи (позже указанное перекрывает ранее указанное).

3. Работа со стилем:
- строка целиком поддерживается, но не является основным рабочим способом;
- нужен специальный patch-синтаксис для консоли/скриптов (пример: `+font-size: 16`);
- в коде основной путь: helper-методы (быстрее и удобнее).

4. Совместимость:
- backward-compatibility не требуется;
- перенос делаем прагматично: сохраняем только то, что реально полезно и рабочее.

5. Состояния:
- набор состояний не фиксирован;
- элемент сам задаёт/обновляет своё состояние (строкой, через API стиля, например `SetState`);
- drawer может получить уже резолвленные параметры, без ручной логики состояний внутри.

6. Инвалидация кэша:
- вместо версионирования используем dirty-флаги и каскадную пометку дочерних узлов.

7. Синтаксис:
- синтаксис стиля нужно отдельно спроектировать и задокументировать.

8. Transitions:
- обязательная часть системы;
- нужно спроектировать связку с существующим `AnimatedValue` и планируемым механизмом `Tweenings`.

## Решения после обсуждения (2026-03-12)
1. Переменные/константы:
- поддержка обязательна;
- по возможности использовать готовый механизм из `Apus.Publics`;
- переменные должны читаться/меняться из скриптов;
- это же становится базой для быстрого переключения тем.

2. Интерполяция:
- интерполяция чисел и цветов допускается как базовый режим;
- при этом оставляем флаг интерполируемости в метаданных атрибута, чтобы отключать её там, где это не имеет смысла.

3. Границы ответственности:
- позиционирование и сайзинг остаются в `layout`;
- стиль отвечает только за визуализацию.

4. Opacity:
- вводим осторожно, как опциональную возможность;
- не делаем обязательным поведением, которое влечёт double buffer для всех случаев.

5. Overflow/clipping/z-index:
- это свойства элемента, не style-системы.

6. Текстурная стилизация:
- нужна гибкая поддержка изображений и 9-patch;
- в `defaultStyle` оставляем базовый уровень image-поддержки;
- для rich bitmap UI предусматриваем отдельный drawer/style-профиль, совместимый с новой моделью style+state+resolver.

## Предложения по улучшению и реализации
1. Ввести двухуровневый API изменений стиля:
- low-level: `SetStyleText(...)`, `PatchStyle(...)`, `ClearStyle(...)`;
- high-level helpers: `SetAttr`, `UnsetAttr`, `AddRef`, `RemoveRef`, `SetState`, `ClearState`.

2. Предложение по patch-синтаксису (для консоли/скриптов):
- `+key:value` -> добавить/перезаписать атрибут;
- `-key` -> удалить атрибут;
- `+@name` -> добавить style-ref;
- `-@name` -> удалить style-ref;
- `!state:hover` / `!state:-hover` -> включить/выключить состояние;
- поддержка батча через `;`.

3. Разделить структуру style на слои при резолве:
- refs-layer (все `@...` по порядку);
- local-layer (атрибуты элемента);
- state-layer (overrides активных состояний);
- transition-layer (временные интерполированные значения).

4. Сделать отдельный runtime-объект `ResolvedStyle` на элемент:
- кеш итоговых атрибутов;
- dirty-обновление по запросу;
- хранение активных transition-каналов.

5. Точки инвалидации (минимальный набор):
- изменился `style` у элемента;
- изменился набор/значение `state`;
- изменился referenced table-style;
- изменился parent (Attach/Detach/Reparent), т.к. меняется наследование.

6. Transitions: предложенный минимальный дизайн
- синтаксис:
`transition: color 120ms ease-out, font-size 80ms linear;`
- optional state-transition:
`transition-hover: fill 100ms ease-out;`
- runtime:
при смене target-значения атрибута запускается канал анимации;
канал может быть реализован на `AnimatedValue` (быстрый старт), позже расширен на Tweenings;
drawer всегда читает только текущее вычисленное значение атрибута.

7. Типизация атрибутов:
- завести реестр метаданных атрибутов (тип, наследуемость, интерполируемость, значение по умолчанию);
- это снимет неоднозначности с `%`, цветами, размерами, enum-ами и поведением transition.

8. Практичный план внедрения без legacy-слоя:
- сначала внедрить новый parser/resolver/state/transition API;
- затем перевести default drawer и 3-4 базовых виджета;
- после этого удалить `font/color/styleClass/styleInfo` и старые пути обращения.

## Style Syntax Draft v0.1
Ниже рабочий черновик синтаксиса, ориентированный на:
- текстовые стили в коде/ресурсах;
- patch-операции для консоли и скриптов;
- каскад с `@refs`, состояниями, переменными и transitions.

1. Базовый style block
```text
font: Roboto;
font-size: 12;
color: $FF8090A0;
border-width: 1;
border-color: $FF404040;
```

2. Ссылки на табличные стили (множественные)
```text
@button;
@accent;
color: $FFFFFFFF;
```
Правило: более поздние refs имеют более высокий приоритет среди refs.

3. State overrides
```text
color: $FFE0E0E0;
:hover { color: $FFFFFFFF; }
:pressed { color: $FFB0B0B0; }
:disabled { color: $FF808080; }
```

4. Переменные/константы
```text
--btn-text: $FFE8E8E8;
--btn-bg: $FF406090;
color: $btn-text;
fill: $btn-bg;
```
Примечание: источник переменных может быть связан с `Apus.Publics`.
Нотация (черновик):
- основная: `$varName`;
- альтернативная (если потребуется): `%varName`.

5. Управление наследованием и reset-значениями
```text
font: inherit;
font-size: initial;
color: unset;
```
Семантика (черновик):
- `inherit` -> взять у предка;
- `initial` -> системное значение по умолчанию атрибута;
- `unset` -> inheritable-атрибуты ведут себя как `inherit`, non-inheritable как `initial`.

6. Transition syntax
```text
transition: color 120ms ease-out, fill 120ms ease-out, border-color 80ms linear;
```
Опционально для конкретного состояния:
```text
transition-hover: fill 100ms ease-out;
transition-pressed: color 60ms linear;
```

7. 9-patch / image-параметры (черновой набор)
```text
patch: "UI.Button.Primary";  // имя существующего TNamedObject
patch-scale: 1.0;
patch-mode: stretch;         // stretch|tile (если поддерживается drawer'ом)
content-padding: 8 10 8 10;
```
Уточнение:
- патч не создаётся в style-тексте;
- style хранит только ссылку по имени на уже существующий ресурс (`TNamedObject`);
- drawer уже умеет рисовать patch, ему нужны только `rect` и масштаб (доп. режимы опциональны).

8. Patch syntax (console/scripts)
```text
+font-size: 16;
-border-color;
+@danger;
-@accent;
!state:hover;
!state:-hover;
```
Допускается батч:
```text
+font-size:16; +color:$FFFFFFFF; -@oldTheme;
```

9. Формальные правила каскада (черновик)
1. Базовые значения атрибутов из metadata (`initial`).
2. Применение refs (`@...`) в порядке записи.
3. Применение локальных атрибутов элемента.
4. Применение активных state-blocks.
5. Применение transition-layer (интерполированное текущее значение).
6. Пост-обработка наследования для незаданных inheritable-атрибутов.

10. Типы значений атрибутов (v1)
- `color`
- `number` (single)
- `length` (`px`, `%`, возможно `em`)
- `bool`
- `enum`
- `string`
- `image-ref`

## Drawer vs Style Profile (архитектурный выбор)
Проблема сформулирована правильно: если все drawer'ы обязаны жить строго в одном и том же style-словаре/резолвере, то rich-image drawer быстро раздувает default-профиль и теряется смысл разделения.

Рекомендация: единый базовый интерфейс style + drawer-специфичные реализации style.

1. Предлагаемая модель
- `Drawer` отвечает за рендеринг.
- `Style` — интерфейсный объект базового типа (единый контракт для всех):
  - принимает строки style/patch;
  - возвращает строки/значения по базовому API;
  - поддерживает базовые операции (`Set`, `Patch`, `SetState`, `Resolve`, `MarkDirty`).
- Конкретный набор свойств и резолвер реализует специальный style-объект, связанный с drawer.
- В некоторых реализациях drawer и style могут быть одним и тем же объектом (если это упрощает профиль).
- При смене drawer элемент получает совместимую реализацию style с тем же базовым интерфейсом.

2. Что общее для всех профилей
- общий каркас API (`SetStyleText`, `PatchStyle`, `SetState`, `Resolve`, `MarkDirty`);
- общий runtime-контракт для получения параметров drawer'ом;
- общий доступ к переменным (`Apus.Publics`) и базовым типам значений.

3. Что может отличаться по профилям
- набор атрибутов и их значения по умолчанию;
- поддерживаемые функции/шорткаты;
- правила transition по атрибутам;
- image/9-patch расширения для bitmap-style.

4. Практичный компромисс для проекта
- `DefaultStyle`: лёгкая реализация базового style-интерфейса без перегруза bitmap-спецификой.
- `RichImageStyle`: расширенная реализация для UI со скинами/9-patch/сложными image-правилами.
- Обе реализации совместимы по базовому интерфейсу, поэтому код элементов не ветвится.

5. Эволюция профилей (если DefaultStyle разрастается)
- при росте сложности `DefaultStyle` выделяем из него минимальное ядро и ограничиваем scope;
- сложные визуальные и поведенческие фичи выносим в `AdvancedStyle`;
- итоговый набор целевых профилей:
  - `DefaultStyle`: прототипирование и простой UI;
  - `RichImageStyle`: основной игровой GUI (скины, 9-patch, визуальные эффекты);
  - `AdvancedStyle`: прикладной/программный GUI без heavy wow-графики.
- все профили обязаны оставаться совместимыми по базовому style-интерфейсу.

5. Почему это лучше, чем "один стиль на всех"
- не раздувает default style до монолита;
- снижает риск регрессий в базовом UI;
- даёт свободу rich-image системе развиваться независимо;
- сохраняет единый developer experience через общий API.

## Предлагаемый порядок внедрения
1. Ввести новые сущности style/drawer/resolver без удаления старых полей.
2. Перевести default drawer на чтение только из resolved style.
3. Добавить наследование drawer по предкам и fallback на default drawer.
4. Перевести ключевые виджеты (`Label/Button/EditBox/ListBox`) с `font/color` на style.
5. Удалить legacy-поля `font/color/styleClass/styleInfo` после закрытия совместимости.

## Решения после обсуждения (2026-03-14)
1. Шрифты в UI:
- UI-элементы НЕ хранят font handle — шрифт задаётся через style, является логическим;
- style resolver вычисляет font handle с учётом текущего scale иерархии;
- это полностью снимает проблему multi-window: каждое окно имеет свой scale, стиль ресолвит правильный handle.

2. Шрифты для прямой отрисовки (txt.Write и т.п.):
- хэндлы хранятся как **threadvar** (каждый поток окна имеет свой набор);
- `game.SelectFonts(scale)` вызывается из потока окна при смене масштаба;
- код рендера использует threadvar-хэндлы напрямую — никаких resolve/logical sizes;
- доступ из non-render потока к threadvar=0 → немедленная ошибка (fail-fast);
- для работы с текстом вне render-потока код обязан получать хэндлы самостоятельно.

3. `game.userScale` — глобальный (не per-window):
- `actualScale = dpiScale * userScale`;
- per-window userScale не нужен — нет реальных use cases.

## Статус реализации (2026-03-23)

### Фаза 1 — DONE: Базовая инфраструктура стилей

**Новые файлы:**
- `Apus.Engine.Style.pas` — TStyleBlock, TStyleTable, парсер, @refs, state-блоки, patch-синтаксис, ResolveBlockAttr

**Изменения в UITypes.pas (TUIElement):**
- Добавлено поле `styleBlock:TStyleBlock` (lazy)
- Методы: `SetStyleText`, `PatchStyleText`, `SetState`, `HasState`
- Методы: `GetStyleValue`, `GetStyleColor`, `GetStyleNumber`, `GetStyleInt`, `EnsureStyleBlock`
- `GetFont` теперь проверяет `styleBlock` для `font`/`font-size` атрибутов
- `GetColor` теперь проверяет `styleBlock` для `color` атрибута
- `SetStyleInfo` синхронизирует `fStyleInfo` с `styleBlock`
- Деструктор освобождает `styleBlock`

**Изменения в DefaultStyle.pas:**
- `TContext.Update` синхронизирует состояния `hover`/`pressed`/`disabled` с `element.SetState`
- Это позволяет CSS-like `:hover { }` блокам работать автоматически

**Изменения в UIWidgets.pas:**
- `TUIListBox.Create` использует `SetStyleText` для экспозиции цветов через style

### Фаза 2 — DONE: Миграция draw-процедур и styleClass

**Изменения в DefaultStyle.pas:**
- `DrawUIButton`, `DrawUICheckbox`, `DrawUIFrame` переведены с `eStyle.GetColor(...)` на `control.GetStyleColor(...)` — убраны параметры `eStyle:PElementStyle`
- `DrawCommonStyle` и `DrawUIScrollbar` пока НЕ переведены (используют AnimatedValue-based hover-переходы через `context.hover`)

**Изменения в UITypes.pas:**
- Добавлен тип `TUIDrawer = procedure(element:TUIElement)` (перемещён из UIRender)
- Добавлено поле `drawer:TUIDrawer` в TUIElement (приоритет над styleClass)

**Изменения в UIRender.pas:**
- Удалено определение TUIDrawer (теперь в UITypes)
- Добавлена функция `GetUIStyle(n:byte):TUIDrawer` для backward-compat numeric API
- `DrawUIElement` предпочитает `item.drawer` если задан, иначе fallback на `styleDrawers[styleClass]`

**Мигрированы callsites:**
- TweakScene: `styleClass:=3` → `drawer:=GetUIStyle(3)`
- CustomStyle: `item.styleClass:=customStyleID` → `item.drawer:=CustomStyleHandler`
- UIScene: `hint.styleClass:=defaultHintStyle` → `if defaultHintStyle<>0 then hint.drawer:=GetUIStyle(defaultHintStyle)`
- UIScript: `c.styleClass:=style` → `c.drawer:=GetUIStyle(style)`

**Не мигрированы (circular deps или backward-compat):**
- `UI.pas` SetupButton/SetupEditBox — `styleClass` stays (circular: UI→UIRender→UI→UIWidgets)
- `UIWidgets.pas` TUIFrame.Create — `styleClass:=style_` stays (same circular)

**Тесты:**
- `tests/TestStyle.dpr` — 38 unit tests для TStyleBlock; парсинг, state-блоки, @refs, patch, GetColor/GetNumber

### Следующие шаги:
- [ ] Демо-сцена: показать CSS `:hover { color }` для кнопок
- [ ] `DrawCommonStyle` — перевести на новую систему (нужны Tweenings для плавных переходов)
- [ ] Убрать `fFont`/`fColor` из TUIElement (после полного перехода всех виджетов)
- [ ] Transitions через Tweenings (когда будут готовы)
- [ ] Поддержка переменных через Apus.Publics (`$varName`)
- [ ] Visual regression tests через Robot API `pixel` + `ui.element`

### Подход к автотестированию

**A. Unit tests (headless, без GL)** — уже реализовано:
- `tests/TestStyle.dpr` — тестирует TStyleBlock логику: парсинг, state-блоки, @refs, цвета

**B. Element integration tests (без GL):**
- Создать TUIElement, установить `SetStyleText`, вызвать `GetStyleColor`/`GetStyleNumber`
- Тестирует весь pipeline кроме рисования
- Можно добавить в `tests/TestUIStyle.dpr` когда понадобится

**C. Visual regression (Robot API):**
- Тест-сцена с элементами на фиксированных позициях и известными цветами
- `ui.element name=X` → получить экранные координаты
- `pixel cx cy` → проверить цвет пикселя
- Нужна тест-сцена с фиксированным layout

### Квёрк: ParseStyleColor с 3-символьными строками
При разборе `#RGB` shorthand (расширение `x` → `xx`) нет валидации hex-символов.
`ParseStyleColor('xyz')` не вернёт 0 — будет интерпретировать как `#xxyyzz`.
Для теста: использовать заведомо невалидные строки ≥5 символов для проверки отказа.

## История изменений
- 2026-03-11: создан документ.
- 2026-03-11: зафиксированы требования по новой системе стилей и добавлены архитектурные замечания/риски по текущему UI.
- 2026-03-11: добавлены решения после обсуждения (drawer, multi-ref, state model, dirty invalidation, no backward-compat) и предложения по синтаксису/transition-дизайну.
- 2026-03-12: добавлены решения по переменным через Apus.Publics, роли layout/style, ограничениям opacity, а также по image/9-patch и rich bitmap UI профилю.
- 2026-03-14: добавлены решения по шрифтам (threadvar для прямой отрисовки, style resolver для UI) и game.userScale (глобальный).
