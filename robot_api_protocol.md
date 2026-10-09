# Robot API Protocol Specification

File-based request/response protocol for external automation of the Apus Engine runtime.

## Files

- **Input:** `robot_in.txt` — **Output:** `robot_out.txt` (both in working directory)
- Output uses the current platform's native line terminator (CRLF on Windows,
  LF on Unix-like systems). Input accepts CRLF, LF, and CR line endings.

## Request Format

```
ID: <unique_id>
CMD: <command_name>
<PARAM>: <value>
---
ID: <unique_id>
CMD: <command_name>
===
```

- `ID` + `CMD` — mandatory. Requests separated by `---`, file ends with `===`.

## Response Format

```
ID: <id>
STATUS: OK|ERROR
MSG: <message>   (ERROR only)
<body>
===
```

Each response block ends with `===`. Multi-item output uses repeated key prefixes with indented sub-fields.

`robot_out.txt` is written once per batch, when every request of that batch has an
answer. A command may postpone itself (see `fps` with `METRICS`, and `screenshot` /
`pixel` right after a surface change), so a batch can span several frames; its
answers are still delivered together. Blocks are ordered by the moment each answer
became available, not by the request order — match them by `ID`.

Requests run in the order they are given. Most postponed commands do not hold the
others back, but **input commands do** (`mouse.*` waiting for their input, see
[Mouse input](#mouse-input-virtual-mouse)): the requests after such a command - in
this batch and in the batches that arrive meanwhile - run only once it is answered.
So `mouse.click` followed by `ui.element` in one batch reports the state after the
click, and the answers come in the request order.

## Activation

- DEBUG builds: on by default. Release: only with `-ROBOT` flag.
- Polling: ~500ms idle, ~100ms after first request, back to slow after 5s inactivity.
- `PollRobotAPI` runs after `PresentFrame` on the main thread.

## Commands

### `windows` — window/render dimensions, DPI, screenScale, displayRect.
- Returns for the main window (`WINDOW: 0`): `name` (accepted by the `WINDOW` parameter
  of `mouse.*`), `clientWidth`, `clientHeight`, `canvasWidth`, `canvasHeight`,
  `screenDPI`, `screenScale`, `displayRect`.

### `window.move` - move main window, optionally with resize in one call.
- Scope: main window only (RobotAPI is polled in the main-loop thread, so thread-local `window` points to `mainWindow`).
- Optional `WINDOW`: only `0`/`main` supported (other values return `STATUS: ERROR`).
- Required: `X`, `Y`.
- Optional: `W`, `H` (must be provided together).
- Returns: `x`, `y`, `windowWidth`, `windowHeight`, `renderWidth`, `renderHeight`.

### `window.resize` - resize main window.
- Scope: main window only (RobotAPI is polled in the main-loop thread, so thread-local `window` points to `mainWindow`).
- Optional `WINDOW`: only `0`/`main` supported (other values return `STATUS: ERROR`).
- Required: `W`, `H` (>0).
- Optional: `X`, `Y` (must be provided together; if omitted, current window position is used).
- Returns: `x`, `y`, `windowWidth`, `windowHeight`, `renderWidth`, `renderHeight`.

### `fps` — fps, smoothFPS, frameNum, frame-time history in milliseconds.
- Optional param: `N` (integer, `1..512`) — return last `N` frame times from ring buffer.
- Optional param: `METRICS` (`yes/no`, default `no`).
  - `METRICS:no` (or absent): immediate response.
  - `METRICS:yes` + `N`: delayed response mode for phase diagnostics:
    - command starts collecting metrics for next `N` frames;
    - final response is written only when `N` frames are collected.
- Returns:
  - `fps`, `smoothFPS`, `frameNum`
  - `frameTimeMs` — last frame time in milliseconds (`xx.xx`, high precision timer based)
  - when `METRICS:yes`: `msgMs`, `onFrameMs`, `renderMs`, `presentMs`, `sleepMs` for the last frame
  - if `N>0`:
    - `historyCount`
    - for `METRICS:no`: repeated `FRAME_MS: <milliseconds>` lines (oldest -> newest, `xx.xx`)
    - for `METRICS:yes`: repeated frame blocks:
      - `Frame: <number>`
      - `  MSG: <ms>`
      - `  ONFRAME: <ms>`
      - `  RENDER: <ms>`
      - `  PRESENT: <ms>`
      - `  SLEEP: <ms>`
      - `  Total: <ms>`

### `scenes` — list all scenes (name, status, zOrder, frequency, fullscreen, class).
- `ACTIVE_ONLY`: if present, only active scenes.

### `resources` — list GL textures (name, glName, width, height, realWidth, realHeight, format, hasFBO).

### `ui.tree` — UI element tree with indentation for hierarchy.
- `SCENE`: scene name (optional, default: all roots).
- `DEPTH`: max depth (optional, default: unlimited).
- Line format: `<indent>UI: <name> [<class>] <x>,<y> <w>x<h> visible|hidden enabled|disabled [caption="..."]`

### `ui.element` — detailed element info by name.
- `NAME`: element name (required).
- `HIERARCHY`: optional boolean (`1/true/yes/on/y`) to include element ancestors in output.
- Returns:
  - base fields: name, class, position, size, pivot, scale, globalRect
  - visibility/enabled states: `visible`, `visibleInternal`, `visibleEffective`, `enabled`, `enabledInternal`, `enabledEffective`
  - misc: parentClip, clipChildren, order, caption, hint, styleInfo, color, font, parent, childCount, focused, underMouse
  - extra geometry: `clientSize` (usable area after padding), `anchors` (left,top,right,bottom fractions)
  - for `TUIScrollBar`: scrollMin, scrollMax, scrollPageSize, scrollValue, scrollStep, scrollHorizontal, scrollSlider (start..end)
  - layout block (if present):
    - `layout:`
      - `class: <layouterClass>`
      - plus type-specific fields (for known layouters)
      - for `TGridLayout` with `allowResize`: computed `computedCols` and `computedItemWidth`
  - when `HIERARCHY` is enabled:
    - `hierarchyCount: N`
    - repeated `HIERARCHY: <index>` blocks with full element details for ancestors only (`1=parent`, then up to root)

### `ui.hittest` — find element at screen coordinates.
- `X`, `Y`: canvas coordinates (the same space as `ui.element` rects and `mouse.*`).
- Returns: hit element name/class, chain from root, enabled state, modal element.

### `cmd` — execute engine command via CmdProc.
- `TEXT`: command string (required).

### `signal` — send event signal.
- `EVENT`: event path (required), `TAG`: integer tag (optional, default 0).

### Coordinate spaces of the readback commands

`screenshot` and `pixel` read the frame as presented, which lives in real pixels of
the client area, while UI and input coordinates live in the canvas space. Both
commands therefore accept an optional `SPACE`:

- `SPACE: canvas` (default) — the draw/input space shared with `ui.tree`,
  `ui.element`, `ui.hittest` and mouse input. Coordinates are mapped to real pixels
  by the engine, so a crop matches what a UI element reports as its rect.
- `SPACE: client` — real pixels of the client area (the picture occupies
  `displayRect`, see the `windows` command).

A region outside the canvas (or outside the picture in `client` space) is reported as
`STATUS: ERROR` instead of being silently cropped.

Both commands read the frame as presented, so both wait for the frame to match the
current surface: sent in the same batch as `window.resize` (or while the user is
resizing the window), they are answered from the first frame presented at the new
size instead of returning the stale one.

### `screenshot` — capture the presented frame to a PNG file.
- `FILE`: output path (default: `screenshot.png`).
- `SPACE`: `canvas` (default) or `client`.
- `X`, `Y`, `W`, `H`: optional crop region in that space (the whole picture if omitted).
- Returns: file, width, height (real pixels of the saved image), space,
  pixelRect (`x,y,w,h` actually read from the frame).

### `pixel` — read a single pixel color from the presented frame.
- `SPACE`: `canvas` (default) or `client`.
- `X`, `Y`: coordinates in that space.
- Returns: x, y (as requested), space, pixel (`x,y` in real pixels), color (AARRGGBB hex).

## Mouse input (virtual mouse)

Simulated pointer input that does not touch the OS: the system cursor never moves,
no focus is taken, no `SendInput`/`XTest`-like API is used, so it works the same on
every platform. The input goes through the regular mouse routing of the engine -
hit-test, hover (`underMouse`, `onMouseOver`/`onMouseOut`), pressed state, modal
dialogs, disabled/hidden elements, mouse capture (drags), clicks, gameplay scenes'
`onMouseMove`/`onMouseBtn`, `window.mouseButtons`, `MOUSE\BTNDOWN`/`MOUSE\BTNUP`
signals; the wheel - `onMouseScroll` of the element under the pointer (gameplay scenes'
`onMouseWheel` if no control takes it), `MOUSE\SCROLL`. Nothing calls a click handler directly.

It does not replace a check of the real OS input path: keep small OS-input smoke tests
for that. Keyboard and touch are not simulated.

### Virtual mode

The virtual mouse belongs to a window and is an explicit mode of that window:

- `mouse.mode` with `MODE: virtual` switches it on. From then on the window ignores the
  physical pointer and buttons (polling and OS button/wheel events, touch included):
  they neither move the virtual pointer nor produce events in this window. A physical
  gesture in progress is cancelled (see reset); the virtual pointer starts outside the
  canvas with no buttons down.
- `mouse.mode` with `MODE: physical` cancels the virtual gesture (see reset) and gives
  the window back to the physical input. With the mode off, the physical input works
  exactly as before.
- `mouse.move`, `mouse.down`, `mouse.up`, `mouse.click`, `mouse.wheel` need the virtual mode (as
  requested so far - a `mouse.mode` earlier in the same batch counts); without it they
  return `STATUS: ERROR` and do nothing.

**Reset** (`mouse.reset`, also part of every mode switch) cancels the gesture without
activating anything: the mouse capture is dropped the way it is when the captor gets
hidden (the captor gets `onLostFocus`), the pointer leaves the canvas (hovered and
pressed elements reset, so a pressed button does not click), then the held buttons are
released - with nothing under the pointer, only gameplay scenes see the releases.

### Target window

Every `mouse.*` command takes an optional `WINDOW`: empty, `0` or `main` - the main
window (its name is `Main`); otherwise the window name (`TWindow.name`: the ASCII
identifier given to `AddWindow`, `Window1`, `Window2`... if none), case-insensitive. Each window has its own virtual pointer and mode:
input of one window never reaches another.

### Coordinates

`X`, `Y` are canvas coordinates by default (`SPACE: canvas`): the space of `ui.tree`,
`ui.element` (`globalRect`) and `ui.hittest`. A point outside the canvas puts the
pointer outside (nothing hovered) - unless a button is held: then it is clamped to the
canvas edge, so a drag keeps going, exactly like the OS pointer.

`SPACE: client` takes real pixels of the window client area (as `screenshot` /
`pixel`) and maps them with the surface the window has **when it applies the input**
(canvas size, DPI scaling, letterbox placement - `displayRect` of `windows`). A point
in the letterbox bars is outside the canvas.

### Execution order and timing

Commands queue operations for the window; the window's own thread applies them in
order, **one operation per frame**, at the input step of the frame (before scenes are
processed). `mouse.move` is one operation, `mouse.down` / `mouse.up` with `X`, `Y` are
two (a move, then the button), `mouse.wheel` with `X`, `Y` - a move, then the wheel;
`mouse.click` is a move (if `X`, `Y` are given), down and up: three frames, so the UI sees every transition and a click is never collapsed
into "button up". No command sleeps or blocks a frame.

By default (`WAIT: yes`) a command is answered once its last operation has been
applied, the UI has processed it and the hover is up to date: the next command can
query the UI state. Being an input command, it also holds back the requests after it
(see [Response Format](#response-format)). With `WAIT: no` the command is answered
right after queueing (`state: queued`); `mouse.wait` then waits for the queue.

A postponed request is re-checked every frame but its input is queued only once: the
operations of a request are applied exactly once whatever the number of checks.

### Commands

#### `mouse.mode` - switch the input mode of a window
- `MODE`: `virtual` or `physical` (required).
- `WINDOW`, `WAIT`: see above.

#### `mouse.move` - move the pointer
- `X`, `Y`: required; `SPACE`: `canvas` (default) or `client`.

#### `mouse.down` / `mouse.up` - press / release a button
- `BUTTON`: `left` (default), `right`, `middle`.
- `X`, `Y` (+ `SPACE`): optional - move there first.
- `mouse.down` of a button that is already down and `mouse.up` of a button that is not
  down are errors.

#### `mouse.click` - move (optional), press and release
- Same parameters as `mouse.down`. Whether it is a click is decided by the UI: a
  disabled, hidden or modal-blocked element does not click, a push button reacts to
  the left button only.

#### `mouse.wheel` - move (optional), turn the wheel
- `DELTA`: required, a non-zero integer in the units of the OS wheel on Windows: 120 per
  notch, positive - away from the user (scrolls up). `DELTA: -360` is three notches down,
  delivered as one event.
- `X`, `Y` (+ `SPACE`): optional - move there first; otherwise the wheel turns at the
  current position.

#### `mouse.reset` - cancel the gesture (see above)
- Does nothing (answers at once) in the physical mode.

#### `mouse.state` - current state of the virtual mouse, answered at once
#### `mouse.wait` - answered once every operation queued for the window is applied

### Answers

All `mouse.*` commands answer with the window's virtual mouse state:

```
window: main            (or the window name)
ticket: 12              (commands that queued input: the id of their last operation)
state: done             (done - applied; queued - WAIT: no)
mode: virtual           (or physical)
position: 150,115       (canvas; "outside" - outside the canvas)
buttons: left           (left,right,middle or none)
under: OkButton         (UI element under the pointer: name, "(none)" if nothing)
underClass: TUIButton   (absent when nothing is under the pointer)
queued: 0               (operations not applied yet)
frame: 1234             (window frame of the last applied operation)
```

The state is the one published by the window after its last applied operation (at
the time of the answer), so in a batch every answer may already show a later state.

`STATUS: ERROR` answers:
- bad or missing parameters (`MODE`, `X`/`Y`, `SPACE`, `BUTTON`, `DELTA`, `WAIT`);
- `window not found: <name>` - no such window, or it is closing;
- `virtual mouse is off: ...` - the command needs the virtual mode;
- `button is already down` / `button is not down`;
- `window closed before the input was applied` - the window closed while the command
  was waiting; its remaining operations were dropped.

### Lifetime

- **Window closed** with operations still queued (or a command waiting): the
  operations are dropped, waiting commands are answered with `STATUS: ERROR`; nothing
  waits forever. Pending requests keep no reference to the window itself, so a closed
  and freed window is never touched.
- **Robot API shut down** (`DoneRobotAPI`, e.g. on exit): pending requests are dropped
  unanswered (as for every command), queued operations are cancelled and every window
  the robot switched to the virtual mode goes back to the physical input with a reset -
  no button stays held, no capture stays.
- A client that stops talking leaves the window in the virtual mode: switch it back
  with `mouse.mode` (`MODE: physical`).

### Example

Click a button by its rect, drag a scrollbar slider beyond the bar, then go back to
the physical mouse:

```
ID: 1
CMD: mouse.mode
MODE: virtual
---
ID: 2
CMD: ui.element
NAME: OkButton
===
```
`globalRect: 440,318,584,354` -> its center is `512,336`:
```
ID: 3
CMD: mouse.click
X: 512
Y: 336
---
ID: 4
CMD: ui.element
NAME: OkButton
===
```
Hold and drag (the slider keeps the capture outside the bar), then cancel:
```
ID: 5
CMD: mouse.down
X: 105
Y: 205
---
ID: 6
CMD: mouse.move
X: 700
Y: 500
---
ID: 7
CMD: mouse.state
---
ID: 8
CMD: mouse.reset
---
ID: 9
CMD: mouse.mode
MODE: physical
===
```
(`mouse.up` instead of `mouse.reset` would end the drag normally.)

## Error Handling

Any command can return `STATUS: ERROR` with `MSG:` describing the problem.

## Custom Commands

Game code can register additional commands via `RegisterRobotCommand(name, @Handler)`.

A handler is called again every poll while it returns `PENDING_TOKEN` (or
`PENDING_ORDERED_TOKEN`, which also holds back the requests after it). Side effects
belong to the first call: `TRobotRequest.attempt` is 0 there, and `TRobotRequest.serial`
identifies the request for the state kept between the calls (`ID` is chosen by the
client and may repeat). State kept for postponed requests is released in a handler
registered with `RegisterRobotShutdownHandler`.

## Future Extensions

- `ui.type`, `ui.focus`, `ui.scroll` - more input simulation
- `var.get` / `var.set` — published variable access
- `log` — recent log messages
