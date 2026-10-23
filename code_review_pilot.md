# Ревью качества кода — пилот (2 модуля)

Модули: `Apus.Engine.UIShapes.pas` (207 строк), `Base/Apus.Regions.pas` (212 строк).
Цель пилота — отладить критерии и формат отчёта до запуска на весь код (~91 тыс. строк, 55 модулей Base + 53 Engine).

## Критерии (категории находок)

| Код | Категория |
|-----|-----------|
| D | Дублирование (одинаковые блоки, копии между модулями или типами) |
| E | Развёрнутые конструкции, заменяемые существующими вызовами/идиомами |
| H | Трудно читаемые/легко ошибиться выражения |
| L | Длинные процедуры, неиспользуемые переменные/uses/поля, мёртвый код |
| F | Форматирование, нарушения CLAUDE.md (отступы, `begin`, пробелы, русские комментарии, пустые заглушки) |

Серьёзность: **A** — вероятная ошибка/поломка, **B** — заметное ухудшение поддержки, **C** — косметика.

## Находки

### Apus.Engine.UIShapes.pas

| # | Кат. | Сер. | Строки | Описание | Предложение |
|---|------|------|--------|----------|-------------|
| U1 | D | B | 79–155 | `TUIBitmapShape` (LoadFromBMP, CreateFromImage, IsOpaque) — построчная копия `TBitmapRegion` из Regions.pas (≈75 строк идентичного кода, включая локальную запись `TBitmapHeader`). | Оставить один класс (см. R1), второй удалить или сделать alias. |
| U2 | D | B | 159–188 | `TUIBasicShape` (Create, Invert) дублирует `TBasicRegion` из Regions.pas. | То же. |
| U3 | L | A | 172–175, 185–188 | `TUIBasicShape.CreateFrom` — заглушка `ASSERT(false,'Not implemented')`; `IsOpaque` всегда возвращает `false`. Класс экспортируется через `Apus.Engine.UI` (alias на стр. 74), но работать не может: данные в конструкторе заполняются, а тест точки не реализован. В релизе (ASSERT отключён) `CreateFrom` молча создаёт пустой объект. | Реализовать `IsOpaque` по формату (см. комментарий формата в Regions.pas) или убрать класс из публичного API. Для `CreateFrom` — `raise`, а не `ASSERT`. |
| U4 | L | C | 74–77 | `destructor Destroy; override; begin inherited; end;` — пустой, не нужен (то же в Regions.pas — там он вдобавок ломает цепочку, см. R3). | Удалить объявление и реализацию. |
| U5 | E | C | 154 | `if cond then result:=true;` после `result:=false`. | `result:=data[...] and ($80 shr bit)<>0;` (заодно `>0` для маски лучше заменить на `<>0`). |
| U6 | H | C | 123, 99 | Размер строки бит-маски `4*((w+31) div 32)` записан дважды разными формулами (через `bpp` и константу 1 бит). | Вынести в одну функцию `BitmapLineSize(width,bpp)` (в Apus.Images/GfxFormats, если уже нет такой). |
| U7 | H | C | 129, 134 | Арифметика указателей `inc(pc,y*downscale*(image.pitch div 4))` и сдвиг `pb` через `x and 7=7`; смысл (бит MSB-first, 1 строка = 1 бит/пиксель) нигде не описан. | Комментарий формата данных у объявления `data`; вычислять `pb` по индексу `x shr 3` вместо инкремента — проще проверить. |
| U8 | H | C | 150–153 | `round(x*(bmWidth-1))` при `x<1` — крайний пиксель достижим только при x≥ ~1−1/(2(w−1)); семантика «центр пикселя / край» не задокументирована. | Решить и записать в комментарии (или использовать `trunc(x*bmWidth)`). |
| U9 | F | C | весь файл | Отступ в 1 пробел внутри `begin..end` (код смещён на 1 вместо 2 пробелов в теле), `var` без отступа, смешанные стили: 192–200 используют 2-пробельный отступ, остальное — 1-пробельный. Пробелы в `class function ShapeEmpty: TUIShape`, `Setlength` / `setLength` — разный регистр. | Привести к стилю CLAUDE.md. |
| U10 | F | C | 48 | `uses Apus.Core, Apus.Conv, Apus.Files` — `Apus.Conv`, судя по коду, не используется. | Проверить компиляцией и убрать. |
| U11 | F | C | 163 | Два оператора в одной строке `width:=w; height:=h;`. | Разнести. |
| U12 | H | C | 192–200 | `class function TUIShape.ShapeEmpty` возвращает глобал через полное имя модуля `Apus.Engine.UIShapes.shapeEmpty`, потому что имя совпадает без учёта регистра. Два способа получить одно и то же (`shapeEmpty` и `TUIShape.shapeEmpty`) — путаница. | Оставить один способ. |
| U13 | F | C | 10–11 | В поле `persistent` публичного класса нет проверки/владельца: логика «не освобождать» живёт вне класса (в `TUIElement`). | Описать в комментарии где именно, либо перенести в `Free`-логику. |

### Base/Apus.Regions.pas

| # | Кат. | Сер. | Строки | Описание | Предложение |
|---|------|------|--------|----------|-------------|
| R1 | D | B | 42–52, 120–192 | См. U1: весь `TBitmapRegion` повторяет `TUIBitmapShape`. | Единая реализация. В модуле Base `TRegion` — более общая сущность; UI-слой может наследовать/оборачивать. |
| R2 | L | A | 71–118 | Модуль почти целиком состоит из заглушек: `TRectRegion.Create/IncludeRect/ExcludeRect` пустые; `TBasicRegion.TestPoint` без тела и без `result` (возвращает мусор); `TRectRegion` не реализует `Invert` и `TestPoint` (абстрактные) — вызов `TRectRegion.Create` создаст экземпляр абстрактного класса. | Если нужен — реализовать. Если нет — удалить (по поиску ссылок живых потребителей нет, см. ниже). |
| R3 | L | A | 122–125 | `destructor TBitmapRegion.Destroy; begin end;` не вызывает `inherited` — тело пустое, но это нарушение шаблона (при появлении ресурсов в базовом классе — утечка). | Удалить деструктор. |
| R4 | L | B | 84–105 | `CreateFrom` — заглушка с ASSERT и закомментированным черновиком (15 строк), неиспользуемые локальные `x,y,size,pos,v,pb` (предупреждения компилятора). | Убрать мёртвый код; черновик — в issue/TODO. |
| R5 | L | B | 71 | Реализация `TBasicRegion.Create` без параметров (`constructor TBasicRegion.Create;`) при объявлении `Create(w,h:integer)`; блок помечен `{ TRegion }` вместо `{ TBasicRegion }`. | Исправить заголовок и комментарий секции. |
| R6 | L | B | 115–118 | `function TBasicRegion.TestPoint(x, y: single): boolean; begin end;` — результат не определён. Компилируется только как warning; при вызове — случайный результат. | Реализовать или `raise ENotImplemented`. |
| R7 | L | B | 9 | `uses Apus.Images, Types` — `Types` (RTL) нужен только ради `TRect`; в реализации не используется `Apus.Conv`. | Проверить uses; для TRect использовать `Apus.Types`, если есть. |
| R8 | L | B | вся единица | Использование: единственный потребитель — `Base/tests/BuildTest.dpr` (compile-only). В `Apus.Engine.Tools.pas:224–250` `TTiledImage.GetRegion` ссылается на `TRegion` только в закомментированном коде. Т.е. модуль нигде не работает. | Предложить удалить `Apus.Regions` целиком; UIShapes остаётся единственным местом. |
| R9 | F | C | весь файл | Формат: 1-пробельный отступ, `var` в колонке 0; пробелы в сигнатурах `(x, y: single): boolean`; смесь `setLength`/`Setlength`; 2 пустые строки в конце файла. | Привести к стилю. |
| R10 | F | C | 1, 26–29 | Комментарии корректны (английские), но блок формата данных `{ Data format: ... }` описывает `TBasicRegion` и стоит между классами — читается как относящийся к `TRectRegion`. | Перенести к `TBasicRegion`. |

## Итог по пилоту

- Реальная проблема не стилистическая, а структурная: **два модуля дублируют друг друга, при этом оба наполовину не реализованы** (UIShapes: `TUIBasicShape`; Regions: почти всё). Приоритетное решение — удалить `Apus.Regions` и доработать/удалить `TUIBasicShape`.
- Для UIShapes реально «живой» код — `TUIShape`, `TUIFullShape`, `TUIEmptyShape`, `TUIBitmapShape` (~50 строк).
- В категориях D/L много находок «мёртвый код/заглушки», это надо учесть при запуске на весь код: отдельно помечать «используется / не используется» (по поиску ссылок во всём репозитории, включая demo, tests, tools).

## Предварительные автоматические срезы по всему коду (для калибровки, ещё не проверены вручную)

Эвристики, ложные срабатывания возможны.

- Дубли блоков ≥8 строк (66 пар). Самые заметные:
  - `SDLplatform` ↔ `WindowsPlatform`: объявление `TWindow` overrides (стр. 20–44 / 18–43), 11–25 строк.
  - `Geom3D`: `TMat3.ToQuaternion` ↔ `TMat3d.ToQuaternion` (24 строки, отличие только в типе); аналогичные пары Invert/Mul и т.д. (~20 пар single/double).
  - `OpenGL`: `DrawIndexed` ↔ `DrawInstanced` (24 строки) + в обеих мёртвая ветка `useStream:=false; if useStream then ...`.
  - `HttpGameClient` ↔ `UdpTransport`: блоки Winsock/`gethostbyname`/`CheckInternetConnection` (19, 15, 15, 10 строк); `ResolveAddress` и `GetInternetAddress`.
  - `Files.pas` 131–149 ↔ 175–191; `Conv.pas` 170–185 ↔ 207–222; `HashMaps` (3 копии по 10 строк); `Threads`, `TCP`, `HttpRequests`, `ResManGL` (2203 ↔ 2229).
- Очень длинные процедуры (≥100 строк): `TNetThread.Execute` (UdpTransport, ≈530), `WindowProc` (WindowsPlatform, ≈260), `TVarTypeUIElement.GetField` (≈180), `GetGLformat` (≈170), `TVarTypeCustomStyle.GetField` (≈155), `LoadFileImage` (≈145), `TShowWindowEffect.DrawScene` (≈130), `AllocRenderTarget` (≈115), `TWindow.RenderFrame` (≈110).
- Предположительно неиспользуемые локальные переменные (30+): `Draw.Band` (n), `Draw.Cover` (w,h), `Game.PrepareRun` (i), `Game.Timing` (несколько), `ResManGL` (error, aTex, level), `TweakScene` (i, fl), `Images.ConvertLine` (buf, sp), `TBitmapImage.Expand` (x,c), `Network.UDPSocket2.Receive`, `TCP.AcceptNewConnection` (i), `Threads.MakeUniqueName` (found).
- Комментарии на русском (по CLAUDE.md — переводить): ≈390 строк; больше всего в `FastGFX` (49), `Publics` (29), `ControlFiles` (27), `Translation` (26), `CustomStyle` (25), `EventMan` (24).
- Закомментированный код: ≈75 фрагментов; `TODO/FIXME`: ≈105; `with`: ≈150 (Draw 15, DefaultStyle 11, Game 10, NinePatch 10).
- Форматирование: 72 строки >160 символов (HtmlTree, API, Graphics, ShadersGL), `begin` на следующей строке после `then/do/else` (≈37, в основном `ControlFiles`, `Spatial`, `NinePatch`), пробелы вокруг `:=` (≈39, `ControlFiles`, `UITypes`), 2 строки с хвостовыми пробелами (`UIWidgets:282`, `Lib:117`).

## Предлагаемый порядок распространения на весь код

1. Согласовать критерии и серьёзности (эта таблица) — что добавить/убрать.
2. Для каждого модуля: полное чтение + автоматические срезы (дубли, длина, неиспользуемое, формат) + проверка ссылок на неиспользуемые публичные символы по репозиторию. Формат — как выше, по одному разделу на модуль.
3. Порядок: сначала Base (Foundation → Strings → Geometry → Graphics → прочее), затем Engine (Core/Window/Platform → Graphics/GL → UI → Scenes → Resources/Audio/Net).
4. Итоговый сводный список «главных проблем» сверху отчёта (дубли между модулями, мёртвые модули, длинные процедуры).
5. Правки кода — только после подтверждения; отчёт ничего не меняет.
