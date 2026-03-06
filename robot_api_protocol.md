# Robot API Protocol Specification

File-based request/response protocol for external automation of the Apus Engine runtime.

## Files

- **Input:** `robot_in.txt` — **Output:** `robot_out.txt` (both in working directory)

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

## Activation

- DEBUG builds: on by default. Release: only with `-ROBOT` flag.
- Polling: ~500ms idle, ~100ms after first request, back to slow after 5s inactivity.
- `PollRobotAPI` runs after `PresentFrame` on the main thread.

## Commands

### `windows` — window/render dimensions, DPI, displayRect.

### `fps` — fps, smoothFPS, frameNum, frameTime.

### `scenes` — list all scenes (name, status, zOrder, frequency, fullscreen, class).
- `ACTIVE_ONLY`: if present, only active scenes.

### `resources` — list GL textures (name, glName, width, height, realWidth, realHeight, format, hasFBO).

### `ui.tree` — UI element tree with indentation for hierarchy.
- `SCENE`: scene name (optional, default: all roots).
- `DEPTH`: max depth (optional, default: unlimited).
- Line format: `<indent>UI: <name> [<class>] <x>,<y> <w>x<h> visible|hidden enabled|disabled [caption="..."]`

### `ui.element` — detailed element info by name.
- `NAME`: element name (required).
- Returns: name, class, position, size, pivot, scale, globalRect, visible, enabled, parentClip, clipChildren, order, caption, hint, styleInfo, color, font, parent, childCount, focused, underMouse.

### `ui.hittest` — find element at screen coordinates.
- `X`, `Y`: screen coordinates.
- Returns: hit element name/class, chain from root, enabled state, modal element.

### `cmd` — execute engine command via CmdProc.
- `TEXT`: command string (required).

### `signal` — send event signal.
- `EVENT`: event path (required), `TAG`: integer tag (optional, default 0).

### `screenshot` — capture backbuffer to PNG file.
- `FILE`: output path (default: `screenshot.png`).
- `X`, `Y`, `W`, `H`: optional crop region (full render area if omitted).
- Returns: file, width, height.

### `pixel` — read single pixel color from backbuffer.
- `X`, `Y`: coordinates.
- Returns: x, y, color (AARRGGBB hex).

## Error Handling

Any command can return `STATUS: ERROR` with `MSG:` describing the problem.

## Custom Commands

Game code can register additional commands via `RegisterRobotCommand(name, @Handler)`.

## Future Extensions

- `ui.click`, `ui.type`, `ui.focus`, `ui.scroll` — input simulation
- `var.get` / `var.set` — published variable access
- `log` — recent log messages
