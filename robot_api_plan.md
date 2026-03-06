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

**Status: NOT STARTED**

## Stage 3: UI Tree + Element Detail
Implement:
- `ui.tree` — recursive traversal from scene's UI root (or all rootElements), output with indentation
- `ui.element` — find element by name, dump all key properties
- `ui.hittest` — call `FindElementAt`, report hit element + chain from root

**Acceptance:** `ui.tree` matches visual layout; `ui.element` returns full property set; `ui.hittest` correctly identifies elements.

**Status: NOT STARTED**

## Stage 4: Commands and Signals
Implement:
- `cmd` — call `ExecCmd(text)`, capture output
- `signal` — call `Signal(event, tag)`

**Acceptance:** can execute CmdProc commands and trigger events via robot file.

**Status: NOT STARTED**

## Stage 5: Screenshot + Pixel
Implement:
- `screenshot` — use `CopyFromBackbuffer` + save to file (support crop region)
- `pixel` — use `GetPixelValue(x,y)`, return hex ARGB

**Acceptance:** screenshot file is created and matches visible output; pixel color is correct.

**Status: NOT STARTED**

## Stage 6: Resources List
Implement:
- `resources` — enumerate textures (name, GL handle, dimensions, format, FBO flag), buffers (type, size, label)

**Acceptance:** resource list matches NSight/debugger view of allocated objects.

**Status: NOT STARTED**

## Stage 7: Integration Testing
- Test with SimpleDemo: exercise all commands via robot_in.txt
- Test error handling: bad command names, missing params, invalid element names
- Test polling modes: verify slow→fast transition on first request
- Document usage examples for Claude Code automation

**Status: NOT STARTED**

## Dependencies
- No external dependencies beyond existing engine modules
- Uses: `Apus.Engine.API`, `Apus.Engine.UITypes`, `Apus.Engine.UI`, `Apus.Engine.Scene`, `Apus.Engine.Game`, `Apus.Engine.CmdProc`, `Apus.EventMan`, `Apus.Engine.ResManGL`

## Integration Point
`TGame.FrameLoop` — call `PollRobotAPI` after `HandleSignals` (line ~2277 in Game.pas)
