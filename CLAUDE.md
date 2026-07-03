# CLAUDE.md

This file provides guidance to Claude Code when working on the Apus Game Engine refactoring.

## Overview

**Apus Game Engine** - cross-platform 2D/3D game engine in Delphi/Pascal by Ivan Polyacov. Used in Spectromancer, Astral Heroes, Astral Towers.

Structure: `Base/` (platform-independent utilities) + root (engine modules).

**`Game/` is NOT part of the engine project** — it is just an EXAMPLE of game code built on the engine (separate product). Do not migrate, refactor, or count it as a consumer during engine refactoring; it is not in the engine CI build and adapts downstream on its own.

## Building

- Projects: `.dproj` (Delphi), `.lpi` (Lazarus/FPC)
- Defines: `DELPHI;OPENGL;LODEPNG;FREETYPE`
- Output: `bin\` (Win32), `bin64\` (Win64)
- Entry point: `TGameApplication.Create` → `Prepare()` → `Run()`

## Code Style

- 2 spaces indent, no tabs, use 2 spaces indent for functions declared in the interface section
- No spaces around operators: `a:=b+c`
- No space between colon and type name: `var x:integer`, `function Foo(a:string):integer`
- `begin` on same line after `then/do/else`, new line for procedures
- Classes: `TName`, Interfaces: `IName`, vars: `camelCase`
- Comments in English, translate Russian when modifying
- Method directive order matters: `overload; static;` not `static; overload;` — wrong order is a compile error
- Preserve UTF-8 BOM

## Architecture

- Main target CPU is x64, but should also support x86 and ARM. `ASM` blocks must be inside conditional compilation directives and accompanied by a pure Pascal implementation.
- Code should be compatible with both Delphi 12+ and FPC 3.2+ compilers.
- We use GitHub actions to run tests on Windows and Linux.
- **GL version policy**: baseline = GL 3.3 core (desktop) ↔ GLES 3.0 (mobile) — the only mandatory render path; newer GL (4.x) features only as extension-gated opt-in fast paths with baseline fallback, gated by capability flags, never by context version. See "GL Version Policy" in `engine5_feature_roadmap.md`.

### Coordinate Conventions

- World space: **Z-up**, right-handed.
- Camera/view space: **forward = Z** (matches the depth buffer), X-right, Y-down.
- This is not enforced on user content - users may pick any "up" axis for their own
  scenes/models. But engine demos, samples and generator defaults must use Z-up.

### String Types

- **Primary**: `String8` (UTF-8) — main string type for all text
- **Alternative**: `String32` (UCS-4) — not used yet, but plan to support in future
- **Compatibility**: built-in `string` — use when String8 doesn't fit (e.g. RTL interop)
- Focus on String8 for new code

**Function overloads for string parameters:**
```pascal
// String8 is primary - always present (unconditional)
function Foo(const st:String8):...;
// UnicodeString for compatibility - only in Unicode mode
{$IFDEF UNICODE}
function Foo(const st:UnicodeString):...;
{$ENDIF}
```
This replaces the old `ADDANSI` pattern. Use `{$IFDEF UNICODE}` directly.

### Base Library (`Base/Apus.*.pas`) - 47 modules

**Dependency Hierarchy:**

```
Level 0 (no Apus dependencies):
  Types, EventMan, Colors, CPU, Crypto

Level 1:
  Classes, Common, Geom2D, FastGFX

Level 2:
  Structs, Geom3D, Images, Socket, CrossPlatform

Level 3:
  GfxFormats, Regions, AnimatedValues, TCP, HttpRequests

Level 4:
  UnicodeFont, TextUtils, Logging, Database, Translation, HtmlTree

Level 5:
  FreeTypeFont, GeoIP, Clipboard, Profiling, StackTrace
```

**Module Groups:**
- **Foundation**: Types, Classes, Common, EventMan
- **Geometry**: Geom2D, Geom3D, VertexLayout
- **Graphics**: Colors, FastGFX, Images, GfxFormats, GfxFilters, Regions
- **Text**: TextUtils, UnicodeFont, FreeTypeFont, GlyphCaches
- **Animation**: AnimatedValues, Tweenings
- **Network**: Socket, TCP, HttpRequests, GeoIP
- **Platform**: CrossPlatform, Android
- **Utilities**: Logging, Profiling, StackTrace, Clipboard, CPU
- **Specialized**: Crypto, RSA, Database, Translation, HtmlTree, ControlFiles
- **Auxiliary**: ProdCons, Huffman, ADPCM, LongMath, RegExpr, SCGI

### Engine (`Apus.Engine.*.pas`) - 57 modules

**Core**: GameApp, Game, API, Types
**Scenes**: Scene, SceneEffects, UIScene, ConsoleScene, TweakScene
**UI**: UITypes, UIWidgets, UI, UILayout, UIRender, UIScript, DefaultStyle
**Graphics**: Graphics, OpenGL, ResManGL, ShadersGL, Draw, TextDraw
**Resources**: Resources, ImageTools, ImgLoadQueue, NinePatch
**Platform**: WindowsPlatform, SDLplatform, AndroidGame, IOSgame
**3D**: Model3D, Mesh, OBJLoader, IQMloader, AEMLoader
**Audio**: Sound, SoundBass, SoundSDL, SoundImx

### Key Patterns

- **Interfaces**: `ISystemPlatform`, `IGraphicsSystem`, `IDrawer` for abstraction
- **Signals**: `"UI\Element\Click"` via `Link()` and `Apus.EventMan`
- **Scene lifecycle**: `Load()` (async) → `Initialize()` (fast) → `Process()` → `Render()`
- **Resources**: Reference counted, call `Free` when done
- **Singleton**: Global `game` object (NOT thread-safe, use `RunAsync`)

## Deprecated Code

**To remove/replace:**
- `Apus.Network.pas` → use `Apus.Socket` (marked deprecated 2023)
- `Apus.Engine.PainterGL.pas` / `Apus.Engine.PainterGL2.pas` - removed legacy painter backends
- `DxImages8.pas` → Direct3D 8 legacy
- `Apus.Engine.UdpTransport.pas` - symmetric UDP transport (legacy name: `Apus.Engine.Networking2`)
- `Apus.Engine.Networking3.pas` - renamed to `Apus.Engine.HttpGameClient`; no compatibility facade
- `deprecated/` folders in Base and root
- `bin/`, `bin64/` DLL files (moved/removed in git status)

## Test Coverage

**Existing tests:**
- `Base/tests/TestCore` - min/max, clamp, swap, alignment, memory, bits
- `Base/tests/TestMath` - matrices, quaternions, geometry
- `Base/tests/TestStructs` - hash tables, collections
- `Base/tests/TestGFX` - bilinear filtering, colors
- `Base/tests/TestMyServis` - string utils, conversions (45+ modules)
- `tests/OpenGL` - shader pipeline, textures
- `tests/PlatformTest` - window, events

**Missing coverage:**
- Scene lifecycle and transitions
- UI system (widgets, layouts, rendering)
- Audio playback
- 3D content (models, animation, mesh)
- Resource management (allocation/free cycles)
- Networking (TCP, HTTP)
- Input handling

**Running tests:**
- `Base/tests/test.bat <TestName>` — compile and run tests (default: TestCore)
- Output: `test_results_64.txt` and `test_results_32.txt` (old files deleted on each run)
- Running .bat from Claude Code: use `cmd //c "full\path\to\test.bat Args"` (double slash required in Git Bash). Single-slash `cmd /c` opens interactive session and doesn't execute.
- IMPORTANT: always verify result files are fresh after running tests — stale results from previous runs can be misleading

**Test conventions:**
- Output format: `Testing XXX... OK` or `Testing XXX... FAIL` on single line
- Use `ExitCode:=1` instead of `halt(1)` for test failures
- Include `test.inc` just after the uses clause for common code
- End console tests with `if IsDebuggerPresent then readln;`

## Key Demos

- `SimpleDemo` - minimal example
- `UI` - comprehensive UI showcase
- `Simple3D` - 3D basics
- `CharAnimation` - skeletal animation
- `ProjectTemplate` - starting point

## Refactoring Notes

**Workflow**: when creating new modules, wait for user to review the interface before writing tests.

**Module migration algorithm:**
1. Remove `Apus.Common`, `Apus.CrossPlatform`, and any old modules that depend on them from `uses`
2. Compile with FPC directly to get the full list of errors: `fpc -MDelphi -Sd -Fu<base_path> <Module.pas>`
3. Fix each error: replace old calls with new API (from Apus.Core/Conv/Strings/Log/Threads), or extract missing functions to the appropriate new module

**Build tools:**
- Tests: build and run ONLY via the ready scripts (`test.bat`, `test.sh`, `buildtest.sh`) — do NOT build tests through lazbuild or ad-hoc `.lpi` projects
- Demos: `.lpi` (Lazarus) projects are welcome alongside `.dproj` (Delphi) — both are useful for IDE build/run-under-debug. Canonical build for CI stays the FPC scripts; keep `.lpi` defines/paths in sync with them. Do not commit `.lps` session files.
- Compile individual module: `fpc -MDelphi -Sd -Fu.. <Module.pas>` (run from `Base/tests/`)
- Run tests: `test.bat <TestName>` (e.g. `test.bat EventMan`)

### Assertions and Runtime Checks

- **`ASSERT`** — programmer error checks (invalid arguments, broken invariants). Controlled by `{$C+}/{$C-}`, disabled in release builds. Use freely including in hot paths.
- **`if` + raise/exit** — critical checks that must always run, even in release. Use for cases where silent corruption is unacceptable.
- Do NOT use `{$IFOPT R+}` for custom checks — use `ASSERT` instead for centralized control.

- use `UIntPtr` for pointer↔integer conversion
- add comments after `{$ELSE}` when far from condition
- short end-of-line comments start lowercase: `a:=1; // initialize`
- do not add unit finalization unless needed
- **FPC quirk**: `single(10)` is a reinterpret cast (wrong!), use `single(10.0)` for proper type conversion
- **FPC quirk**: `$FF00000000000000` is int64 (signed), use `uint64($FF00000000000000)` for unsigned comparison

## License

BSD-3 - see `license.txt`
