# Robot API — Implementation Plan

## Stage 1: Skeleton Module + File Polling
Create `Apus.Engine.RobotAPI.pas` with:
- `InitRobotAPI` / `PollRobotAPI` / `DoneRobotAPI`
- File existence check with adaptive polling (slow/fast mode)
- Request parser: split by `---`, parse `KEY: VALUE` pairs
- Response writer: write `robot_out.txt` with `===` delimiters
- Integrate call into `TGame.FrameLoop`
- Activation logic: `{$IFDEF DEBUG}` default on, `-ROBOT` flag

**Acceptance:** module compiles, integrates into game loop, parses a dummy request file and writes a response with STATUS: OK.

**Status: DONE**

## Stage 2: Info Commands (windows, fps, scenes)
Implement:
- `windows` — read `game.windowWidth/Height`, `renderWidth/Height`, `screenDPI`, `displayRect`
- `fps` — read `game.FPS`, `game.smoothFPS`, `game.frameNum`, `frameTimeDelta`
- `scenes` — iterate `scenes[]` array, output name/status/zOrder/frequency/class

**Acceptance:** all three commands return correct data from a running demo.

**Status: DONE**

## Stage 3: UI Tree + Element Detail
Implement:
- `ui.tree` — recursive traversal from scene's UI root (or all rootElements), output with indentation
- `ui.element` — find element by name, dump all key properties
- `ui.hittest` — call `FindElementAt`, report hit element + chain from root

**Acceptance:** `ui.tree` matches visual layout; `ui.element` returns full property set; `ui.hittest` correctly identifies elements.

**Status: DONE**

## Stage 4: Commands and Signals
Implement:
- `cmd` — call `ExecCmd(text)`, capture output
- `signal` — call `Signal(event, tag)`

**Acceptance:** can execute CmdProc commands and trigger events via robot file.

**Status: DONE**

## Stage 5: Screenshot + Pixel
Implement:
- `screenshot` — use `CopyFromBackbuffer` + save to file (support crop region)
- `pixel` — use `GetPixelValue(x,y)`, return hex ARGB

**Acceptance:** screenshot file is created and matches visible output; pixel color is correct.

**Status: DONE**

## Stage 6: Resources List
Implement:
- `resources` — enumerate textures (name, GL handle, dimensions, format, FBO flag), buffers (type, size, label)

**Acceptance:** resource list matches NSight/debugger view of allocated objects.

**Status: DONE** (textures only; buffers not tracked in a list — TEngineBuffer extends TObjectEx, not TNamedObject)

## Stage 7: Integration Testing
- Test with SimpleDemo: exercise all commands via robot_in.txt
- Test error handling: bad command names, missing params, invalid element names
- Test polling modes: verify slow→fast transition on first request
- Document usage examples for Claude Code automation

**Status: NOT STARTED**

## Implementation Notes

### Parsing
- Use `TNameValue` / `TNameValueList` from `Apus.Types` for key-value parsing.
  - `nv.InitFrom(line, ':')` splits by first `:`, trims both parts.
  - `nv.Named('KEY')` for case-insensitive name comparison.
  - `TNameValueList.Item[key]` for lookup by name.
  - Handles colons in values correctly (splits on first `:` only).

### Object Lookup
- Almost all engine objects inherit from `TNamedObject` (in `Apus.Classes`).
  - Use `TMyClass.FindByName(name)` for global lookup — no manual iteration needed.
  - Works for scenes (`TGameScene`), UI elements (`TUIElement`), textures, etc.
  - Returns `TObject`, cast to expected type; returns `nil` if not found.
- `FindElement(name, mustExist)` in `Apus.Engine.UI` wraps `TUIElement.FindByName`.
- `FindAnyElementAt(x,y,c)` / `FindElementAt(x,y,c)` for hit testing — locks `UICritSect` internally.

### Accessing Protected Fields
- Use `TGameHelper = class(TGame)` pattern to access protected `scenes[]` array.
  - Cast `game` via `TGameHelper(game)` — safe because `game` is always `TGame`.
  - Keep all scene iteration and locking inside helper methods.
  - Don't expose raw scene arrays outside the helper.

### Locking
- `game.EnterCritSect` / `game.LeaveCritSect` for scene list access.
- `UICritSect` (from `Apus.Engine.UITypes`) for `rootElements[]` and `children[]` traversal.
- `FindAnyElementAt` / `FindElementAt` lock `UICritSect` internally — don't double-lock.
- TLock is recursive (Windows CriticalSection), so double-lock is safe but wasteful.

### FPC Quirks Encountered
- `TArray<T>` from different units are incompatible in FPC 3.2 — use named array types (`TRequestArray = array of TRequest`).
- `result:=nil` doesn't compile for dynamic arrays of managed records — use `SetLength(result,0)`.
- `SysUtils` is not needed if `Apus.Core` is in uses — it re-exports `Exception`.

### Conv API for Responses
- `Conv.ToStr(integer)` / `Conv.ToStr(single, decimals)` / `Conv.ToStr(boolean)` for formatting.
- `Conv.ToHex(cardinal)` for ARGB color output.
- `Conv.ToInt(string)` for parsing integer params (returns 0 for empty/invalid).

## Future Improvements

### FPS command enhancement
- Add ring buffer of precise frame timestamps in the engine (not in RobotAPI)
- Output last N frame times (default=20) for jitter/stutter analysis
- Include VSync state in fps response

### Scenes command enhancement
- [x] Add optional `ACTIVE_ONLY` parameter to filter only active scenes

### Custom commands
- Allow registering custom robot commands from game code (callback-based)
- Pattern: `RegisterRobotCommand('mycommand', @MyHandler)` where handler takes TRequest and returns String8
- Useful for game-specific queries (inventory state, player position, etc.)

## Dependencies
- No external dependencies beyond existing engine modules
- Uses: `Apus.Engine.API`, `Apus.Engine.UITypes`, `Apus.Engine.UI`, `Apus.Engine.Scene`, `Apus.Engine.Game`, `Apus.Engine.CmdProc`, `Apus.EventMan`, `Apus.Engine.ResManGL`

## Integration Point
`TGame.FrameLoop` — call `PollRobotAPI` after `HandleSignals` (line ~2277 in Game.pas)
