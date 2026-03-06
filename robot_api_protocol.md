# Robot API Protocol Specification
Version: 0.1 (draft)

## Overview

File-based request/response protocol for external automation of the Apus Engine runtime.
Robot writes commands to an input file, engine processes them and writes responses to an output file.

## Files

- **Input:** `robot_in.txt` (working directory)
- **Output:** `robot_out.txt` (working directory)

## Request Format

```
ID: <unique_id>
CMD: <command_name>
<PARAM>: <value>
...
---
ID: <unique_id>
CMD: <command_name>
...
===
```

- Each request is a block of `KEY: VALUE` lines
- `ID` — mandatory, carried to response (string, assigned by caller)
- `CMD` — mandatory, command name
- Additional parameters depend on command
- Requests separated by `---`
- End-of-file marker: `===` (engine ignores file until this marker is present)

## Response Format

```
ID: <id>
STATUS: OK|ERROR
MSG: <error message>       (only when STATUS=ERROR)
<response fields>
===
ID: <id>
...
===
```

- Each response block ends with `===`
- Fields are `KEY: VALUE` (one per line)
- Multi-item responses use repeated prefixed lines (see commands below)
- Nested data uses indentation (2 spaces per level)

## Activation

- `{$IFDEF DEBUG}`: active by default
- Release: active only with `-ROBOT` command-line flag
- With `-ROBOT` flag: poll ~10 times/sec
- Without flag (debug default): poll every ~0.5s, switch to fast polling after first file detected

## Polling Strategy

- `PollRobotAPI` called every frame
- Internally tracks time since last file check
- Slow mode: check every ~500ms
- Fast mode (after first request or with `-ROBOT`): check every ~100ms
- After processing: return to slow mode after ~5s of inactivity

## Commands

### `windows` — Window Information
Request:
```
ID: 1
CMD: windows
```
Response:
```
ID: 1
STATUS: OK
WINDOW: 0
  windowWidth: 1024
  windowHeight: 768
  renderWidth: 1024
  renderHeight: 768
  screenDPI: 96
  displayRect: 0,0,1024,768
```

### `fps` — Performance Statistics
Request:
```
ID: 2
CMD: fps
```
Response:
```
ID: 2
STATUS: OK
fps: 60.2
smoothFPS: 59.8
frameNum: 12345
frameTime: 16
```

### `scenes` — List Scenes
Request:
```
ID: 3
CMD: scenes
```
Response:
```
ID: 3
STATUS: OK
SCENE: MainMenu
  status: active
  zOrder: 10
  frequency: 60
  fullscreen: true
  class: TUIScene
SCENE: Console
  status: frozen
  zOrder: 100
  frequency: 0
  fullscreen: false
  class: TUIScene
```

### `resources` — List Resources
Request:
```
ID: 4
CMD: resources
TYPE: textures
```
Parameters:
- `TYPE`: `textures` | `buffers` | `all` (default: `all`)

Response:
```
ID: 4
STATUS: OK
TEX: mySprite
  glName: 7
  width: 256
  height: 256
  realWidth: 256
  realHeight: 256
  format: ipfARGB
  hasFBO: false
```

### `ui.tree` — UI Element Tree
Request:
```
ID: 5
CMD: ui.tree
SCENE: MainMenu
```
Parameters:
- `SCENE`: scene name (optional; if omitted, dump all root elements)
- `DEPTH`: max depth to traverse (optional, default: unlimited)

Response (indentation = hierarchy):
```
ID: 5
STATUS: OK
UI: MainMenu [TUIElement] 0,0 1024x768 visible enabled
  UI: Panel1 [TUIElement] 10,10 200x400 visible enabled
    UI: Button1 [TUIButton] 5,5 180x40 visible enabled caption="Start"
    UI: Button2 [TUIButton] 5,55 180x40 visible disabled caption="Options"
  UI: Panel2 [TUIElement] 220,10 500x400 visible enabled
```

Each `UI:` line format: `<indent>UI: <name> [<class>] <x>,<y> <w>x<h> <flags> [extra]`
- Flags: `visible`/`hidden`, `enabled`/`disabled`
- Extra: `caption="text"` if non-empty

### `ui.element` — Detailed Element Info
Request:
```
ID: 6
CMD: ui.element
NAME: Button1
```
Response:
```
ID: 6
STATUS: OK
name: Button1
class: TUIButton
position: 5.0,5.0
size: 180.0,40.0
pivot: 0.0,0.0
scale: 1.0
globalRect: 15,15,195,55
visible: true
enabled: true
parentClip: true
clipChildren: true
order: 0
caption: Start
hint: Click to start
styleInfo: button
color: FFFFFFFF
font: 1
parent: Panel1
childCount: 0
focused: false
underMouse: false
```

### `ui.hittest` — Hit Test with Report
Request:
```
ID: 7
CMD: ui.hittest
X: 150
Y: 45
```
Response:
```
ID: 7
STATUS: OK
hit: Button1
hitClass: TUIButton
chain: MainMenu > Panel1 > Button1
enabled: true
modal: none
```

### `cmd` — Execute Script Command
Request:
```
ID: 8
CMD: cmd
TEXT: GameState=42
```
Response:
```
ID: 8
STATUS: OK
result: (command output if any)
```

### `signal` — Send Signal
Request:
```
ID: 9
CMD: signal
EVENT: UI\MainMenu\Click
TAG: 0
```
Response:
```
ID: 9
STATUS: OK
```

### `screenshot` — Capture Screenshot
Request:
```
ID: 10
CMD: screenshot
FILE: screenshot.png
X: 0
Y: 0
W: 512
H: 384
```
Parameters:
- `FILE`: output path (relative to working dir)
- `X`, `Y`, `W`, `H`: optional crop region (full screen if omitted)

Response:
```
ID: 10
STATUS: OK
file: screenshot.png
width: 512
height: 384
```

### `pixel` — Read Pixel Color
Request:
```
ID: 11
CMD: pixel
X: 100
Y: 200
```
Response:
```
ID: 11
STATUS: OK
color: FF2A5C90
```
Color format: AARRGGBB hex.

## Error Handling

Any command can return an error:
```
ID: 5
STATUS: ERROR
MSG: Scene not found: BadName
```

## Threading

All commands are processed on the main thread during `PollRobotAPI` (called from `FrameLoop`).
No concurrent access issues — all game state is safely accessible.

## Future Extensions

- `ui.click X Y` — simulate mouse click
- `ui.type TEXT` — simulate keyboard input
- `ui.focus NAME` — set focus to element
- `ui.scroll NAME DX DY` — scroll element
- `var.get NAME` / `var.set NAME VALUE` — published variable access
- `log` — retrieve recent log messages
- Binary protocol over TCP (if file-based becomes a bottleneck)
