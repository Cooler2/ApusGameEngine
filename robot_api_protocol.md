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

## Activation

- DEBUG builds: on by default. Release: only with `-ROBOT` flag.
- Polling: ~500ms idle, ~100ms after first request, back to slow after 5s inactivity.
- `PollRobotAPI` runs after `PresentFrame` on the main thread.

## Commands

### `windows` — window/render dimensions, DPI, screenScale, displayRect.
- Returns per window: `windowWidth`, `windowHeight`, `renderWidth`, `renderHeight`, `screenDPI`, `screenScale`, `displayRect`.

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
- `X`, `Y`: screen coordinates.
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

## Error Handling

Any command can return `STATUS: ERROR` with `MSG:` describing the problem.

## Custom Commands

Game code can register additional commands via `RegisterRobotCommand(name, @Handler)`.

## Future Extensions

- `ui.click`, `ui.type`, `ui.focus`, `ui.scroll` — input simulation
- `var.get` / `var.set` — published variable access
- `log` — recent log messages
