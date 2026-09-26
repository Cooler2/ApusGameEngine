# Engine signal inventory (current state)

> This is a snapshot of **what the current code actually does**, not the target architecture.
> The document may go out of date with any change to `Signal(...)` / `DelayedSignal(...)`.

## How to read this document
- Signals in `EventMan` are **case-insensitive**. The canonical form (usually an UPPERCASE prefix) is used below; spelling variants are merged into one entry.
- `Type`:
  - `command` - the signal is sent so that someone performs an action;
  - `notification` - the signal reports that something has already happened;
  - `hook` - an extension point to add behavior without editing the sender's source.
- `Sender` names a class/subsystem, not a file.

## ENGINE\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `ENGINE\CMD\EXIT` | command | Platform windows (`TWinGLWindow`, `TSDLGLWindow`) | `0` | Request a normal shutdown of the main thread/application. The main graceful-shutdown path. |
| `ENGINE\CMD\CHANGESETTINGS` | command | `TGame` | `0` | Deferred application of new `TGameSettings` in the main-thread context. |
| `ENGINE\CMD\SETSWAPINTERVAL` | command | `TGame` | `divider` | Request to change VSync/SwapInterval from a non-main thread. |
| `ENGINE\CMD\UPDATEMOUSEPOS` | command | UI subsystem (`TUIScene`) | `0` | Force a mouse position refresh through the platform API when the local state may be stale. |
| `ENGINE\INITGAME` | command | `TGameApplication` (platform bootstrap) | `0` | Start engine/game initialization once the platform layer is ready. |
| `ENGINE\ONFRAME` | command | `TGameApplication` (platform draw callback) | `0` | Main loop tick: triggers `FrameLoop`. |
| `ENGINE\ACTIVATEWND` | notification | `TGame`, `TGameApplication` | `0/1` | The window/application activity changed (foreground/background). |
| `ENGINE\SETACTIVE` | command | Platform backend (`TWindowsPlatform`, `TSDLPlatform`) | `0/1` | Tells the core to apply the active/inactive window state (internal control signal). |
| `ENGINE\RESIZE` | command | Platform backend (`TWindowsPlatform`, `TSDLPlatform`) | packed `width,height` | Tells the core to recalculate sizes/render area. Source: system window events. |
| `ENGINE\BEFORERESIZE` | hook | `TWindow` | `0` | Pre-hook before the viewport/UI layout is recalculated. Handy for adaptive logic. |
| `ENGINE\RESIZED` | notification | `TWindow` | `0` | Post-notification after the resize pipeline has finished. |
| `ENGINE\DPICHANGED` | notification | `TWindow` | `newDPI` | The window DPI changed. |
| `ENGINE\DPICHANGED\DONE` | notification | `TGame` | `dpi` | Scale/parameters have been recalculated after a DPI change. |
| `ENGINE\REDRAW` | command | `TWindowsPlatform` | `0` | Request an immediate redraw (usually from `WM_PAINT`). |
| `ENGINE\EFFECTDONE` | notification | `TWindow` (scene effects) | `UIntPtr(scene)` | A scene effect has finished; further transitions/cleanup can be done. |
| `ENGINE\FRAMECAPTURED` | notification | `TWindow` | `UIntPtr(TBitmapImage)` | A frame was captured and is ready for the consumer. |
| `ENGINE\BEFOREINITGRAPH` | hook | `TGame` | `0` | Extension point before the graphics backend is initialized. |
| `ENGINE\AFTERINITGRAPH` | hook | `TGame` | `0` | Extension point after graphics initialization. |
| `ENGINE\BEFOREDONEGRAPH` | hook | `TGame` | `0` | Hook before graphics deinitialization. |
| `ENGINE\AFTERDONEGRAPH` | hook | `TGame` | `0` | Hook after graphics deinitialization. |
| `ENGINE\BEFOREMAINLOOP` | hook | `TGame` | `0` | Extension point before entering the main loop. |
| `ENGINE\MAINLOOPINIT` | command | `TGame` | `0` | Internal command to initialize the loop infrastructure. |
| `ENGINE\MAINLOOPDONE` | command | `TGame` | `0` | Internal command to finalize the loop infrastructure. |
| `ENGINE\AFTERMAINLOOP` | notification | `TGame` | `0` | The main loop has ended; final post-actions. |
| `ENGINE\WINDOW\HIDDEN/SHOWN/MINIMIZED/RESTORED/MAXIMIZED/CLOSE` | notification | `TSDLPlatform` | `0` | SDL window events as signals for subscribers. |
| `ENGINE\PRESENTFRAME` | notification | iOS GL view bridge (legacy path) | `0` | A frame has been presented (used in the mobile branch/legacy code). |

## GAMEAPP\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `GAMEAPP\CREATESCENES` | hook | `TGameApplication` | `0` | Plug in external scene-creation logic. |
| `GAMEAPP\LOADSCENES` | hook | `TGameApplication` | `0` | External hook for loading scene resources. |
| `GAMEAPP\INITCURSORS` | hook | `TGameApplication` | `0` | Cursor initialization and a chance to extend it. |
| `GAMEAPP\INITSTYLES` | hook | `TGameApplication` | `0` | Point to set up UI styles/themes. |
| `GAMEAPP\LOADFONTS` | hook | `TGameApplication` | `0` | Font loading. |
| `GAMEAPP\SELECTFONTS` | hook | `TGameApplication` | `0` | Reselect fonts (e.g. on DPI change/resize). |
| `GAMEAPP\SETGAMESETTINGS` | hook | `TGameApplication` | `0` | Final adjustment of `TGameSettings` before launch. |
| `GAMEAPP\OPTIONSLOADED` | notification | `TGameApplication` | `0` | The configuration has been loaded. |
| `GAMEAPP\ONRESIZE` | notification | `TGameApplication` | `0` | The application received a resize. |
| `GAMEAPP\INITSOUND` | hook | `TGameApplication` | `0` | Before sound initialization. |
| `GAMEAPP\INITIALIZED` | notification | `TGameApplication` | `0` | Application bootstrap has finished. |
| `GAMEAPP\ONIDLE` | hook | `TGameApplication` (control thread) | `0` | Regular idle hook for external logic. |
| `GAMEAPP\TERMINATED` | notification | `TGameApplication` | `0` | The control thread has finished. |
| `LOADINGSCENE\RENDER` | notification | `TLoadingScene` | `0` | A frame of the loading scene has been drawn. |

## MOUSE\*, KBD\*, PEN\*, TOUCH/GAMEPAD/JOY

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `MOUSE\MOVE` | notification | Platform backend (`TWindowsPlatform`, `TSDLPlatform`), touch bridge (`TGame`) | packed `x,y` | **Raw motion stream** (e.g. from `WM_MOUSEMOVE`/SDL motion); may arrive often and in bursts between frames. Used to record the current coordinates immediately. |
| `MOUSE\MOVED` | notification | `TWindow` | packed `x,y` | **Aggregated motion**: published by `FlushMouseInput`, effectively once per frame when the position changed. This is the "useful" data for the frame loop/scenes, already in sync with frame processing. |
| `MOUSE\BTNDOWN` / `MOUSE\BTNUP` | notification | Platform backend + gamepad bridge (`TGame`) | `button` | Unified mouse button events for scenes/UI. |
| `MOUSE\SCROLL` | notification | Platform backend | `wheelDelta` | Mouse wheel (scroll). |
| `MOUSE\UPDATEPOS` | command | UI widgets (`TUIScrollBar`) | `0` | Request to update the mouse position after a virtual drag/clip. |
| `KBD\KEYDOWN` / `KBD\KEYUP` | notification | Platform backend | `keyCode + scanCode<<16` | Low-level keyboard events. |
| `KBD\CHAR` | notification | `TWindowsPlatform` | `ansi + scan<<16` | ANSI character (legacy compatibility). |
| `KBD\UNICHAR` | notification | Platform backend, Android bridge | unicode(+scan) | Unicode input. |
| `PEN\PRESSURE` / `PEN\ROTATION` | notification | `TWindowsPlatform` (Pointer API) | sensor value | Pen telemetry. |
| `ENGINE\SINGLETOUCHSTART/MOVE/RELEASE` | notification | Android/iOS bridge | packed `x,y` | Touch events, later transformed into the mouse/UI pipeline. |
| `ENGINE\MULTITOUCH` | notification | iOS bridge | pointer to a multitouch struct | Multi-touch payload for specific logic. |
| `JOY\BTNDOWN` / `JOY\BTNUP` | notification | `TSDLPlatform` | `PackTag(button,controller)` | Low-level joystick buttons. |
| `GAMEPAD\BTNDOWN\{Button}` / `GAMEPAD\BTNUP\{Button}` | notification | `TSDLPlatform` | `PackTag(conButton,controller)` | Gamepad buttons (the button name is in the path). |
| `SCENE\{SceneName}\KEYDOWN/KEYUP` | notification | `TGame` | `uCode` | Delivers keys to a specific active scene. |

## UI\* and SCENES\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `SCENES\PROCESSSCENE\{Scene}` | hook | `TUIScene` | `0` | Hook on UI scene processing every tick. |
| `SCENES\{Scene}\BEFORERENDER` | hook | `TUIScene` | `0` | Scene pre-render hook. |
| `SCENES\{Scene}\BEFOREUIRENDER` | hook | `TUIScene` | `0` | Hook before DrawUI. |
| `SCENES\{Scene}\AFTERUIRENDER` | hook | `TUIScene` | `0` | Hook after DrawUI. |
| `UI\CURSOR\ON/OFF` | notification | `TUIScene` | `cursorId` | The active UI cursor changed. |
| `UI\ONMOUSEOVER\{Class}\{Name}` / `UI\ONMOUSEOUT\{Class}\{Name}` | notification | `TUIScene` | `0` | The hovered element changed. |
| `UI\ONHINT\{Class}\{Name}` | notification | `TUIScene` | `0` | A hint is shown for an element. |
| `UI\{SceneName}\MOUSEWHEEL` | notification | `TUIScene` | `delta` | Wheel in the context of a specific UI scene. |
| `UI\SETGLOBALSHADOW` | command | `TShowWindowEffect` | packed: `low8=alpha`, `high=duration` | Controls the global modal shadow for the UI. |
| `UI\ONEFFECT\{Show/Hide/ShowModal}\{Scene}` | notification | `TShowWindowEffect` | `0` | A scene/window visual effect starts. |
| `UI\ITEMCREATED/ITEMDESTROYED/ITEMRENAMED` | notification | `TUIElement` | `TTag(self)` | UI element lifecycle. |
| `UI\{name}\CHAR/UNICHAR/KEYDOWN` | notification | `TUIElement` | packed values | Low-level input events for a specific element. |
| `UI\{name}\FOCUS` | notification | `TUIElement` | `0/1` | Focus lost/gained. |
| `UI\{name}\MOUSEDOWN/MOUSEUP/MOUSEMOVE/MOUSESCROLL` | notification | `TUIElement` | button/value | Basic mouse events of an element. |
| `UI\{name}\ONCLICK` | notification | `TUIButton`, `TUIToggleButton` | `pressed/toggled` | User click on a control. |
| `UI\BUTTON\CLICK\{name}` | notification | `TUIButton` | `TTag(self)` | Button-specific click signal. |
| `UI\BUTTON\DOWN/UP\{name}` | notification | `TUIButton`, `TUIToggleButton` | `UIntPtr(self)` | The pressed state changed. |
| `UI\BUTTON\TOGGLE\{name}` | notification | `TUIToggleButton` | `UIntPtr(self)` | The toggle state changed. |
| `UI\{name}\TOGGLE` | notification | `TUIToggleButton` | `0` | Short toggle notification (no payload). |
| `UI\BUTTON\OVER/OUT\{name}` | notification | `TUIButton` | `0` | Hover enter/leave on a button. |
| `UI\{name}\CLICKDISABLED` | notification | `TUIButton`, `TUIToggleButton` | `button` | Click on a disabled control. |
| `UI\{name}\AUTOCOMPLETION` | notification | `TUIEditBox` | `0` | An autocompleted string was applied. |
| `UI\EDITBOX\AUTOCOMPLETION\{name}` | notification | `TUIEditBox` | `0` | The same, specialized path. |
| `UI\{name}\ENTER` / `UI\EDITBOX\ENTER\{name}` | notification | `TUIEditBox` | `0` | Enter pressed in an edit box. |
| `UI\{name}\ESCAPE` | notification | `TUIEditBox` | `0` | Escape pressed in an edit box. |
| `UI\{name}\CHANGED` | notification | `TUIEditBox`, `TUIScrollBar` | `0` or value | Text (edit box) or value (scroll bar) changed. |
| `UI\{name}\CHANGING` | notification | `TUIScrollBar` | `round(value)` | Intermediate change during animation/drag. |
| `UI\SCROLLBAR\CHANGED\{name}` | notification | `TUIScrollBar` | `UIntPtr(self)` | Scroll bar specific event (changed). |
| `UI\SCROLLBAR\CHANGING\{name}` | notification | `TUIScrollBar` | `round(value)` | Scroll bar specific event (changing). |
| `UI\{name}\SELECTED` | notification | `TUIListBox` | `selectedLine` | The selected list box item changed. |
| `UI\LISTBOX\ONSELECT\{name}` | notification | `TUIListBox` | `TTag(self)` | List box selection event as a control-level callback. |
| `UI\COMBOBOX\ONDROP/ONHIDE/ONSELECT\{name}` | notification | `TUIComboBox` | `TTag(self)` | Show/hide/select in the combo popup. |
| `UI\{name}\ONSELECT` | notification | `TUIComboBox` | `index` | Combo item selected by index. |
| `UI\COMBOBOX\DROPDOWN` | command | `TUIComboBox` | `PtrUInt(self)` | Explicit command to open/toggle the drop-down. |
| `UI\CLICK\{name}` | command | UI scene event endpoint (`onSimulateClick` in `TUIScene`) | `0` | Simulates a click on a UI element by name. Used as an external control channel (scripts/autotests/tools). |
| `UI\MESSAGE\NEXT` (`DelayedSignal`) | command | Message subsystem (`TMessageScene`) | `0` | Deferred switch to the next message in the message box queue. |

## SOUND\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `SOUND\PAUSE` / `SOUND\RESUME` | command | `TGameApplication` | `0` | Audio subsystem commands when the application is minimized/restored. |
| `SOUND\PLAY\{event}` | command | Sound event endpoint (`EventHandler` in the sound subsystem) | packed playback parameters | Plays a sound event/sample. One of the main external sound APIs. |
| `SOUND\PLAYMUSIC\{track}` | command | Sound event endpoint (`EventHandler` in the sound subsystem) | transition/fade mode | Starts/switches a music track (including fade/crossfade scenarios). |
| `SOUND\ANIMATEMUSICVOL` (`DelayedSignal`) | command | Sound subsystem (`AnimateMusicVolume`) | `TTag(TMusicEntry)` | Step-by-step music volume animation when there is no native slide. |
| `SOUND\SAMPLELOADING\{file}` | notification | BASS backend helper (`LoadSample`; `legacy/`, not built) | `0` | Sample loading started. |
| `SOUND\SAMPLELOADED\{file}` | notification | BASS backend helper (`LoadSample`; `legacy/`, not built) | `0` | Sample loading finished. |
| `SOUND\*` (dynamic, via `DelayedSignal(event,...)`) | command | Sound subsystem (Android path) | any | Deferred re-send of the current sound event. |

Note on `MUSIC\PLAY`: the current engine code has no direct `MUSIC\PLAY\...` handler; the actual input channel is `SOUND\PLAYMUSIC\...`.
If `MUSIC\PLAY` is used in project scripts/configs, it is usually an external alias (e.g. via `Link(...)`), not a separate engine endpoint.

## NET\* and HTTP_EVENT\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `NET\CONN\*` (UdpTransport/NW2: `CONNECTED`, `CONNECTIONREJECTED`, `USERMSG`, `CONNECTIONCLOSED`, `CONNECTIONBROKEN`) | notification | UdpTransport subsystem | connId/ptr | UDP transport events. |
| `NET\ERROR\{message}` (UdpTransport/NW2) | notification | UdpTransport subsystem | `0` | UDP transport errors (the name includes the error text). |
| `NET\CONN3\CONNECTIONFAILED` | notification | HttpGameClient subsystem | `0` | Connection/HTTP request error. |
| `NET\CONN3\CONNECTIONREJECTED` | notification | HttpGameClient subsystem | `0` | The server rejected the connection/login. |
| `NET\CONN3\CONNECTED` | notification | HttpGameClient subsystem | `0` | Connection established. |
| `NET\CONN3\LOGGED` | notification | HttpGameClient subsystem | `userId` | Authorization succeeded. |
| `NET\CONN3\ACCESSDENIED` | notification | HttpGameClient subsystem | `0` | Authorization rejected; the reason is in `HGCErrorMessage`. |
| `NET\CONN3\DATARECEIVED` | notification | HttpGameClient subsystem | `msgTag` | An incoming message was queued. |
| `NET\CONN3\CONNECTIONBROKEN` | notification | HttpGameClient subsystem | `1/2/3` | Connection broken, with a reason code (the failure branches of the client). |
| `NET\CONN3\ERROR` | notification | HttpGameClient subsystem | `0` | Fatal error of the network thread. |
| `NET\CONN3\ACCOUNTCREATED` / `NET\CONN3\ACCOUNTFAILED` | notification | HttpGameClient subsystem | `0` | Account registration result. |
| `HTTP_EVENT\RESENDPOST` (`DelayedSignal`) | command | HttpGameClient subsystem | `0` | Re-sends a POST on the retriable-delivery timer. |
| `HTTP requests[*].event` (dynamic) | notification | HTTP subsystem (`THTTPThread`, iOS delegate) | `requestId` | Generic HTTP request completion callback for the calling code. |

## GLIMAGES\* and STEAM\*

| Canonical signal | Type | Sender | `tag` | Purpose / details |
|---|---|---|---|---|
| `GLIMAGES\UPLOAD` | command | OpenGL resource manager (`TGLTexture`) | `TTag(texture)` | Marshals an upload to the thread with the active GL context. |
| `GLIMAGES\DELETETEXTURE` | command | OpenGL resource manager (`TGLResourceManager`) | `TTag(texture)` | Marshals a texture deletion to the GL thread. |
| `STEAM\MICROTXNAUTHORIZATION\{OrderId}` | notification | Steam integration callback (`legacy/`, not built) | `authorized(0/1)` | Result of a Steam microtransaction authorization. |

## Proxied/user-defined dynamic signals

| Pattern | Type | Sender | `tag` | Purpose |
|---|---|---|---|---|
| `SIGNAL <event> [tag]` (console) | command | Command processor (`SignalCmd`) | int/`0` | Manually send any signal from the console/scripts. |
| Robot API: `signal EVENT=... TAG=...` | command | Robot API subsystem | int/`0` | External signal injection for autotests/tools. |
| `event:<name>` in `TUIImage.src` | command | UI style/render subsystem | `PtrUInt(control)` | Binds drawing of a UI element to an instant event. |
| `onClickEvent` (widget setting) | command | UI widgets | `TTag(self)` | User callback signal for buttons/toggles. |
| `curMsg.event1/event2` | command | Message subsystem | `0` | Yes/No or Ok/Cancel signals for message box scenarios. |

## Cleanup candidates (rename/remove)

### Candidates for renaming/normalization
- Normalize the `OnXxx` style in event names (`ONIDLE`, `ONRESIZE`, `ONSELECT`, `ONEFFECT`, `ONHINT` etc.) and stop mixing `ON...`/`on...`.
- Normalize the `EDITBOX`/`SCROLLBAR`/`COMBOBOX` family to a single segment spelling.
- Fix the canon for `MOUSE\MOVE` vs `MOUSE\MOVED` in the code style and documentation:
  - `MOUSE\MOVE` = raw high-frequency input stream;
  - `MOUSE\MOVED` = aggregated "per frame" signal.

### Candidates for removal/narrowing the contract
- Public use of the legacy `NET\CONN\*` family (UdpTransport/NW2) after the final migration to HttpGameClient.
- Free user-defined dynamic paths (`event:<name>`, generic `SIGNAL`) in production without validating the source/name.
