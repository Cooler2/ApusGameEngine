# Инвентаризация сигналов движка (текущее состояние)

> Это снимок **фактического состояния текущего кода**, а не целевая архитектура.  
> Документ может устаревать при любых изменениях `Signal(...)` / `DelayedSignal(...)`.

## Правила чтения этого документа
- Сигналы в `EventMan` **case-insensitive**. Ниже используется каноническая форма (обычно UPPERCASE префикс), а варианты регистра объединены в одну запись.
- `Тип`:
  - `команда` - сигнал отправляется, чтобы кто-то выполнил действие;
  - `нотификация` - сигнал сообщает, что событие уже произошло;
  - `хук` - точка расширения/встраивания поведения без правки исходного кода отправителя.
- `Кто посылает` указан как класс/подсистема, а не файл.

## ENGINE\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `ENGINE\CMD\EXIT` | команда | Платформенные окна (`TWinGLWindow`, `TSDLGLWindow`) | `0` | Запрос штатного завершения главного потока/приложения. Основной путь graceful shutdown. |
| `ENGINE\CMD\CHANGESETTINGS` | команда | `TGame` | `0` | Отложенное применение новых `TGameSettings` в контексте main thread. |
| `ENGINE\CMD\SETSWAPINTERVAL` | команда | `TGame` | `divider` | Запрос смены VSync/SwapInterval из не-main-thread. |
| `ENGINE\CMD\UPDATEMOUSEPOS` | команда | UI подсистема (`TUIScene`) | `0` | Принудительное обновление координат мыши через platform API, когда локальное состояние могло устареть. |
| `ENGINE\INITGAME` | команда | `TGameApplication` (platform bootstrap) | `0` | Старт инициализации движка/игры после готовности platform layer. |
| `ENGINE\ONFRAME` | команда | `TGameApplication` (platform draw callback) | `0` | Тик main loop: инициирует `FrameLoop`. |
| `ENGINE\ACTIVATEWND` | нотификация | `TGame`, `TGameApplication` | `0/1` | Сообщает о смене активности окна/приложения (foreground/background). |
| `ENGINE\SETACTIVE` | команда | Platform backend (`TWindowsPlatform`, `TSDLPlatform`) | `0/1` | Команда ядру применить active/inactive состояние окна (внутренний управляющий сигнал). |
| `ENGINE\RESIZE` | команда | Platform backend (`TWindowsPlatform`, `TSDLPlatform`) | packed `width,height` | Команда ядру пересчитать размеры/рендер-область. Источник - системные window events. |
| `ENGINE\BEFORERESIZE` | хук | `TWindow` | `0` | Pre-hook перед пересчетом viewport/UI layout. Удобно для адаптивной логики. |
| `ENGINE\RESIZED` | нотификация | `TWindow` | `0` | Post-notify после завершения resize pipeline. |
| `ENGINE\DPICHANGED` | нотификация | `TWindow` | `newDPI` | Сообщает факт изменения DPI окна. |
| `ENGINE\DPICHANGED\DONE` | нотификация | `TGame` | `dpi` | Сообщает завершение пересчета scale/параметров после DPI change. |
| `ENGINE\REDRAW` | команда | `TWindowsPlatform` | `0` | Запрос немедленной перерисовки (обычно из `WM_PAINT`). |
| `ENGINE\EFFECTDONE` | нотификация | `TWindow` (scene effects) | `UIntPtr(scene)` | Завершился эффект сцены; можно выполнять дальнейшие переходы/cleanup. |
| `ENGINE\FRAMECAPTURED` | нотификация | `TWindow` | `UIntPtr(TBitmapImage)` | Кадр захвачен и готов к обработке потребителем. |
| `ENGINE\BEFOREINITGRAPH` | хук | `TGame` | `0` | Точка расширения перед инициализацией графического backend. |
| `ENGINE\AFTERINITGRAPH` | хук | `TGame` | `0` | Точка расширения после инициализации графики. |
| `ENGINE\BEFOREDONEGRAPH` | хук | `TGame` | `0` | Хук перед деинициализацией графики. |
| `ENGINE\AFTERDONEGRAPH` | хук | `TGame` | `0` | Хук после деинициализации графики. |
| `ENGINE\BEFOREMAINLOOP` | хук | `TGame` | `0` | Точка расширения перед входом в main loop. |
| `ENGINE\MAINLOOPINIT` | команда | `TGame` | `0` | Внутренняя команда инициализации loop инфраструктуры. |
| `ENGINE\MAINLOOPDONE` | команда | `TGame` | `0` | Внутренняя команда завершения loop инфраструктуры. |
| `ENGINE\AFTERMAINLOOP` | нотификация | `TGame` | `0` | Главный цикл закончен; финальные пост-действия. |
| `ENGINE\WINDOW\HIDDEN/SHOWN/MINIMIZED/RESTORED/MAXIMIZED/CLOSE` | нотификация | `TSDLPlatform` | `0` | SDL-оконные события в виде сигналов для подписчиков. |
| `ENGINE\PRESENTFRAME` | нотификация | iOS GL view bridge (legacy path) | `0` | Сообщение о завершении презентации кадра (используется в мобильной ветке/legacy-коде). |

## GAMEAPP\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `GAMEAPP\CREATESCENES` | хук | `TGameApplication` | `0` | Внешнее встраивание логики создания сцен. |
| `GAMEAPP\LOADSCENES` | хук | `TGameApplication` | `0` | Внешний хук загрузки ресурсов сцен. |
| `GAMEAPP\INITCURSORS` | хук | `TGameApplication` | `0` | Инициализация курсоров и возможность расширений. |
| `GAMEAPP\INITSTYLES` | хук | `TGameApplication` | `0` | Точка настройки UI-стилей/тем. |
| `GAMEAPP\LOADFONTS` | хук | `TGameApplication` | `0` | Загрузка шрифтов. |
| `GAMEAPP\SELECTFONTS` | хук | `TGameApplication` | `0` | Перевыбор шрифтов (например, при DPI/resize). |
| `GAMEAPP\SETGAMESETTINGS` | хук | `TGameApplication` | `0` | Финальная правка `TGameSettings` перед запуском. |
| `GAMEAPP\OPTIONSLOADED` | нотификация | `TGameApplication` | `0` | Конфигурация загружена. |
| `GAMEAPP\ONRESIZE` | нотификация | `TGameApplication` | `0` | Приложение получило resize. |
| `GAMEAPP\INITSOUND` | хук | `TGameApplication` | `0` | Перед инициализацией звука. |
| `GAMEAPP\INITIALIZED` | нотификация | `TGameApplication` | `0` | Bootstrap приложения завершен. |
| `GAMEAPP\ONIDLE` | хук | `TGameApplication` (control-thread) | `0` | Регулярный idle hook для внешней логики. |
| `GAMEAPP\TERMINATED` | нотификация | `TGameApplication` | `0` | Control-thread завершен. |
| `LOADINGSCENE\RENDER` | нотификация | `TLoadingScene` | `0` | Кадр загрузочной сцены отрисован. |

## MOUSE\*, KBD\*, PEN\*, TOUCH/GAMEPAD/JOY

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `MOUSE\MOVE` | нотификация | Platform backend (`TWindowsPlatform`, `TSDLPlatform`), touch bridge (`TGame`) | packed `x,y` | **Сырой поток движения** (например, из `WM_MOUSEMOVE`/SDL motion), может приходить часто и пачками между кадрами. Используется для немедленной фиксации текущих координат. |
| `MOUSE\MOVED` | нотификация | `TWindow` | packed `x,y` | **Агрегированное движение**: публикуется в `FlushMouseInput` фактически 1 раз на кадр при изменении позиции. Это “полезные” данные для frame loop/сцен, уже синхронизированные с обработкой кадра. |
| `MOUSE\BTNDOWN` / `MOUSE\BTNUP` | нотификация | Platform backend + gamepad bridge (`TGame`) | `button` | Унифицированные mouse button events для сцены/UI. |
| `MOUSE\SCROLL` | нотификация | Platform backend | `wheelDelta` | Колесо мыши (скролл). |
| `MOUSE\UPDATEPOS` | команда | UI widgets (`TUIScrollBar`) | `0` | Просьба обновить позицию мыши после virtual drag/clip. |
| `KBD\KEYDOWN` / `KBD\KEYUP` | нотификация | Platform backend | `keyCode + scanCode<<16` | Низкоуровневые клавиатурные события. |
| `KBD\CHAR` | нотификация | `TWindowsPlatform` | `ansi + scan<<16` | ANSI-символ (legacy-совместимость). |
| `KBD\UNICHAR` | нотификация | Platform backend, Android bridge | unicode(+scan) | Unicode ввод. |
| `PEN\PRESSURE` / `PEN\ROTATION` | нотификация | `TWindowsPlatform` (Pointer API) | значение датчика | Телеметрия пера. |
| `ENGINE\SINGLETOUCHSTART/MOVE/RELEASE` | нотификация | Android/iOS bridge | packed `x,y` | Touch-события, далее трансформируются в mouse/UI pipeline. |
| `ENGINE\MULTITOUCH` | нотификация | iOS bridge | pointer на multitouch struct | Multi-touch payload для специфичной логики. |
| `JOY\BTNDOWN` / `JOY\BTNUP` | нотификация | `TSDLPlatform` | `PackTag(button,controller)` | Низкоуровневые кнопки джойстика. |
| `GAMEPAD\BTNDOWN\{Button}` / `GAMEPAD\BTNUP\{Button}` | нотификация | `TSDLPlatform` | `PackTag(conButton,controller)` | Кнопки геймпада (имя кнопки в пути). |
| `SCENE\{SceneName}\KEYDOWN/KEYUP` | нотификация | `TGame` | `uCode` | Доставка клавиш конкретной активной сцене. |

## UI\* и SCENES\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `SCENES\PROCESSSCENE\{Scene}` | хук | `TUIScene` | `0` | Хук на обработку UI-сцены в каждом тике. |
| `SCENES\{Scene}\BEFORERENDER` | хук | `TUIScene` | `0` | Pre-render hook сцены. |
| `SCENES\{Scene}\BEFOREUIRENDER` | хук | `TUIScene` | `0` | Хук перед DrawUI. |
| `SCENES\{Scene}\AFTERUIRENDER` | хук | `TUIScene` | `0` | Хук после DrawUI. |
| `UI\CURSOR\ON/OFF` | нотификация | `TUIScene` | `cursorId` | Изменение активного UI-курсора. |
| `UI\ONMOUSEOVER\{Class}\{Name}` / `UI\ONMOUSEOUT\{Class}\{Name}` | нотификация | `TUIScene` | `0` | Смена hover-элемента. |
| `UI\ONHINT\{Class}\{Name}` | нотификация | `TUIScene` | `0` | Показ подсказки для элемента. |
| `UI\{SceneName}\MOUSEWHEEL` | нотификация | `TUIScene` | `delta` | Колесо в контексте конкретной UI-сцены. |
| `UI\SETGLOBALSHADOW` | команда | `TShowWindowEffect` | packed: `low8=alpha`, `high=duration` | Управление глобальной modal-тенью для UI. |
| `UI\ONEFFECT\{Show/Hide/ShowModal}\{Scene}` | нотификация | `TShowWindowEffect` | `0` | Старт визуального эффекта сцены/окна. |
| `UI\ITEMCREATED/ITEMDESTROYED/ITEMRENAMED` | нотификация | `TUIElement` | `TTag(self)` | Жизненный цикл UI-элементов. |
| `UI\{name}\CHAR/UNICHAR/KEYDOWN` | нотификация | `TUIElement` | packed значения | Низкоуровневые input-события для конкретного элемента. |
| `UI\{name}\FOCUS` | нотификация | `TUIElement` | `0/1` | Потеря/получение фокуса. |
| `UI\{name}\MOUSEDOWN/MOUSEUP/MOUSEMOVE/MOUSESCROLL` | нотификация | `TUIElement` | button/value | Базовые мышиные события элемента. |
| `UI\{name}\ONCLICK` | нотификация | `TUIButton`, `TUIToggleButton` | `pressed/toggled` | Пользовательский клик по контролу. |
| `UI\BUTTON\CLICK\{name}` | нотификация | `TUIButton` | `TTag(self)` | Специализированный click-сигнал кнопки. |
| `UI\BUTTON\DOWN/UP\{name}` | нотификация | `TUIButton`, `TUIToggleButton` | `UIntPtr(self)` | Изменение pressed-состояния. |
| `UI\BUTTON\TOGGLE\{name}` | нотификация | `TUIToggleButton` | `UIntPtr(self)` | Изменение toggle-состояния. |
| `UI\{name}\TOGGLE` | нотификация | `TUIToggleButton` | `0` | Краткая нотификация toggle (без payload). |
| `UI\BUTTON\OVER/OUT\{name}` | нотификация | `TUIButton` | `0` | Hover enter/leave на кнопке. |
| `UI\{name}\CLICKDISABLED` | нотификация | `TUIButton`, `TUIToggleButton` | `button` | Клик по disabled контролу. |
| `UI\{name}\AUTOCOMPLETION` | нотификация | `TUIEditBox` | `0` | Применена автодополненная строка. |
| `UI\EDITBOX\AUTOCOMPLETION\{name}` | нотификация | `TUIEditBox` | `0` | То же, специализированный путь. |
| `UI\{name}\ENTER` / `UI\EDITBOX\ENTER\{name}` | нотификация | `TUIEditBox` | `0` | Нажат Enter в editbox. |
| `UI\{name}\ESCAPE` | нотификация | `TUIEditBox` | `0` | Нажат Escape в editbox. |
| `UI\{name}\CHANGED` | нотификация | `TUIEditBox`, `TUIScrollBar` | `0` или значение | Изменение текста (editbox) или значения (scrollbar). |
| `UI\{name}\CHANGING` | нотификация | `TUIScrollBar` | `round(value)` | Промежуточное изменение во время анимации/drag. |
| `UI\SCROLLBAR\CHANGED\{name}` | нотификация | `TUIScrollBar` | `UIntPtr(self)` | Специализированное событие scrollbar (changed). |
| `UI\SCROLLBAR\CHANGING\{name}` | нотификация | `TUIScrollBar` | `round(value)` | Специализированное событие scrollbar (changing). |
| `UI\{name}\SELECTED` | нотификация | `TUIListBox` | `selectedLine` | Изменен выбранный элемент listbox. |
| `UI\LISTBOX\ONSELECT\{name}` | нотификация | `TUIListBox` | `TTag(self)` | Событие выбора listbox как control-level callback. |
| `UI\COMBOBOX\ONDROP/ONHIDE/ONSELECT\{name}` | нотификация | `TUIComboBox` | `TTag(self)` | Показ/скрытие/выбор в popup combo. |
| `UI\{name}\ONSELECT` | нотификация | `TUIComboBox` | `index` | Выбор пункта combo по индексу. |
| `UI\COMBOBOX\DROPDOWN` | команда | `TUIComboBox` | `PtrUInt(self)` | Явная команда открыть/переключить drop-down. |
| `UI\CLICK\{name}` | команда | UI scene event endpoint (`onSimulateClick` в `TUIScene`) | `0` | Симуляция клика по элементу UI по имени. Используется как внешний управляющий канал (скрипты/автотесты/инструменты). |
| `UI\MESSAGE\NEXT` (`DelayedSignal`) | команда | Message subsystem (`TMessageScene`) | `0` | Отложенный переход к следующему сообщению в очереди message box. |

## SOUND\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `SOUND\PAUSE` / `SOUND\RESUME` | команда | `TGameApplication` | `0` | Команды audio subsystem при сворачивании/возврате приложения. |
| `SOUND\PLAY\{event}` | команда | Sound event endpoint (`EventHandler` в sound subsystem) | packed параметры воспроизведения | Команда воспроизведения звукового события/сэмпла. Канал является одним из основных внешних API звука. |
| `SOUND\PLAYMUSIC\{track}` | команда | Sound event endpoint (`EventHandler` в sound subsystem) | режим перехода/фейда | Команда запуска/переключения музыкального трека (включая сценарии fade/crossfade). |
| `SOUND\ANIMATEMUSICVOL` (`DelayedSignal`) | команда | `Sound subsystem` (`AnimateMusicVolume`) | `TTag(TMusicEntry)` | Шаговая анимация громкости музыки при отсутствии native slide. |
| `SOUND\SAMPLELOADING\{file}` | нотификация | BASS backend helper (`LoadSample`) | `0` | Начало загрузки sample. |
| `SOUND\SAMPLELOADED\{file}` | нотификация | BASS backend helper (`LoadSample`) | `0` | Конец загрузки sample. |
| `SOUND\*` (динамически через `DelayedSignal(event,...)`) | команда | Sound subsystem (Android path) | произвольный | Отложенная повторная отправка текущего sound-события. |

Примечание по `MUSIC\PLAY`: в текущем коде движка прямого обработчика `MUSIC\PLAY\...` не найдено; фактический входной канал - `SOUND\PLAYMUSIC\...`.  
Если `MUSIC\PLAY` используется в проектных скриптах/конфиге, это обычно внешний алиас (например, через `Link(...)`), а не отдельный engine endpoint.

## NET\* и HTTP_EVENT\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `NET\CONN\*` (NW2: `CONNECTED`, `CONNECTIONREJECTED`, `USERMSG`, `CONNECTIONCLOSED`, `CONNECTIONBROKEN`) | нотификация | Networking2 subsystem | connId/ptr | События legacy Networking2. |
| `NET\ERROR\{message}` (NW2) | нотификация | Networking2 subsystem | `0` | Ошибки legacy Networking2 (имя включает текст ошибки). |
| `NET\CONN3\CONNECTIONFAILED` | нотификация | Networking3 subsystem | `0` | Ошибка подключения/HTTP запроса. |
| `NET\CONN3\CONNECTIONREJECTED` | нотификация | Networking3 subsystem | `0` | Сервер отверг подключение/логин. |
| `NET\CONN3\CONNECTED` | нотификация | Networking3 subsystem | `0` | Подключение установлено. |
| `NET\CONN3\LOGGED` | нотификация | Networking3 subsystem | `userId` | Успешная авторизация. |
| `NET\CONN3\ACCESSDENIED` | нотификация | Networking3 subsystem | `0` | Авторизация отклонена с причиной в `NW3ErrorMessage`. |
| `NET\CONN3\DATARECEIVED` | нотификация | Networking3 subsystem | `msgTag` | Поступило входящее сообщение в очередь NW3. |
| `NET\CONN3\CONNECTIONBROKEN` | нотификация | Networking3 subsystem | `1/2/3` | Обрыв соединения с кодом причины (ветки отказа в NW3). |
| `NET\CONN3\ERROR` | нотификация | Networking3 subsystem | `0` | Фатальная ошибка net-thread. |
| `NET\CONN3\ACCOUNTCREATED` / `NET\CONN3\ACCOUNTFAILED` | нотификация | Networking3 subsystem | `0` | Результат регистрации аккаунта. |
| `HTTP_EVENT\RESENDPOST` (`DelayedSignal`) | команда | Networking3 subsystem | `0` | Повторная отправка POST через таймер retriable-delivery. |
| `HTTP requests[*].event` (динамически) | нотификация | HTTP subsystem (`THTTPThread`, iOS delegate) | `requestId` | Универсальный callback завершения HTTP-запроса для вызывающего кода. |

## GLIMAGES\* и STEAM\*

| Канонический сигнал | Тип | Кто посылает | `tag` | Назначение / детали |
|---|---|---|---|---|
| `GLIMAGES\UPLOAD` | команда | OpenGL resource manager (`TGLTexture`) | `TTag(texture)` | Маршалинг upload в поток с активным GL context. |
| `GLIMAGES\DELETETEXTURE` | команда | OpenGL resource manager (`TGLResourceManager`) | `TTag(texture)` | Маршалинг delete texture в GL поток. |
| `STEAM\MICROTXNAUTHORIZATION\{OrderId}` | нотификация | Steam integration callback | `authorized(0/1)` | Результат авторизации микротранзакции Steam. |

## Проксируемые/пользовательские динамические сигналы

| Шаблон | Тип | Кто посылает | `tag` | Назначение |
|---|---|---|---|---|
| `SIGNAL <event> [tag]` (консоль) | команда | Command processor (`SignalCmd`) | int/`0` | Ручная отправка любого сигнала из консоли/скриптов. |
| Robot API: `signal EVENT=... TAG=...` | команда | Robot API subsystem | int/`0` | Внешний инжект сигналов для автотестов/инструментов. |
| `event:<name>` в `TUIImage.src` | команда | UI style/render subsystem | `PtrUInt(control)` | Привязка отрисовки UI-элемента к мгновенному событию. |
| `onClickEvent` (настройка виджета) | команда | UI widgets | `TTag(self)` | Пользовательский callback-сигнал для кнопок/toggle. |
| `curMsg.event1/event2` | команда | Message subsystem | `0` | Сигналы Yes/No или Ok/Cancel для message box сценариев. |

## Список для последующей чистки (rename/remove)

### Кандидаты на переименование/нормализацию
- Нормализовать стиль `OnXxx` в именах событий (`ONIDLE`, `ONRESIZE`, `ONSELECT`, `ONEFFECT`, `ONHINT` и т.п.) и убрать смешение `ON...`/`on...`.
- Нормализовать семейство `EDITBOX`/`SCROLLBAR`/`COMBOBOX` в единый стиль написания сегментов.
- Зафиксировать канон для `MOUSE\MOVE` vs `MOUSE\MOVED` в кодстайле и документации:
  - `MOUSE\MOVE` = сырой высокочастотный входной поток;
  - `MOUSE\MOVED` = агрегированный сигнал “для кадра”.

### Кандидаты на удаление/сужение контракта
- Публичное использование legacy-семейства `NET\CONN\*` (Networking2) после окончательной миграции на Networking3.
- Свободные пользовательские динамические пути (`event:<name>`, универсальный `SIGNAL`) в production-контуре без валидации источника/имени.
