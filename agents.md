# AGENTS.md

This file provides guidance to Claude Code when working on the Apus Game Engine refactoring.

## Overview

**Apus Game Engine** - cross-platform 2D/3D game engine in Delphi/Pascal by Ivan Polyacov. Used in Spectromancer, Astral Heroes, Astral Towers.

Structure: `Base/` (platform-independent utilities) + root (engine modules).

## Building

- Projects: `.dproj` (Delphi), `.lpi` (Lazarus/FPC)
- Defines: `DELPHI;OPENGL;LODEPNG;FREETYPE`
- Output: `bin\` (Win32), `bin64\` (Win64)
- Entry point: `TGameApplication.Create` в†’ `Prepare()` в†’ `Run()`

## Code Style

- 2 spaces indent, no tabs, use 2 spaces indent for functions declared in the interface section
- No spaces around operators: `a:=b+c`
- No space between colon and type name: `var x:integer`, `function Foo(a:string):integer`
- `begin` on same line after `then/do/else`, new line for procedures
- Classes: `TName`, Interfaces: `IName`, vars: `camelCase`
- Comments in English, translate Russian when modifying
- Preserve UTF-8 BOM

## Architecture

- Main target CPU is x64, but should also support x86 and ARM. `ASM` blocks must be inside conditional compilation directives and accompanied by a pure Pascal implementation.
- Code should be compatible with both Delphi 12+ and FPC 3.2+ compilers.
- We use GitHub actions to run tests on Windows and Linux.

### String Types

- **Primary**: `String8` (UTF-8) вЂ” main string type for all text
- **Alternative**: `String32` (UCS-4) вЂ” not used yet, but plan to support in future
- **Compatibility**: built-in `string` вЂ” use when String8 doesn't fit (e.g. RTL interop)
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
**Graphics**: Graphics, OpenGL, PainterGL2, ResManGL, ShadersGL, Draw, TextDraw
**Resources**: Resources, ImageTools, ImgLoadQueue, NinePatch
**Platform**: WindowsPlatform, SDLplatform, AndroidGame, IOSgame
**3D**: Model3D, Mesh, OBJLoader, IQMloader, AEMLoader
**Audio**: Sound, SoundBass, SoundSDL, SoundImx

### Key Patterns

- **Interfaces**: `ISystemPlatform`, `IGraphicsSystem`, `IDrawer` for abstraction
- **Signals**: `"UI\Element\Click"` via `Link()` and `Apus.EventMan`
- **Scene lifecycle**: `Load()` (async) в†’ `Initialize()` (fast) в†’ `Process()` в†’ `Render()`
- **Resources**: Reference counted, call `Free` when done
- **Singleton**: Global `game` object (NOT thread-safe, use `RunAsync`)

## Deprecated Code

**To remove/replace:**
- `Apus.Network.pas` в†’ use `Apus.Socket` (marked deprecated 2023)
- `PainterGL.pas` в†’ use `PainterGL2` (fixed-function legacy)
- `DxImages8.pas` в†’ Direct3D 8 legacy
- `Networking2.pas` в†’ use Networking3
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
- `Base/tests/test.bat <TestName>` вЂ” compile and run tests (default: TestCore)
- Output: `test_results_64.txt` and `test_results_32.txt` (old files deleted on each run)
- Running .bat from Claude Code: use `cmd //c "full\path\to\test.bat Args"` (double slash required in Git Bash). Single-slash `cmd /c` opens interactive session and doesn't execute.
- IMPORTANT: always verify result files are fresh after running tests вЂ” stale results from previous runs can be misleading

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

## Robot API + Demo Runtime Notes

- Protocol spec: `robot_api_protocol.md`.
- Files are always in the demo **current working directory**: `robot_in.txt` / `robot_out.txt`.
- Demo path nuance: executable may be in `bin64`, but runtime CWD can be switched to demo source folder (where `.dpr` lives). Always check `game.log` location/current behavior before sending robot requests.
- Request parsing starts only after `===` end marker is present in `robot_in.txt`.
- In DEBUG, Robot API is enabled by default; for explicit/reliable runs use `-ROBOT`.
- For UI commands (`ui.tree`, `ui.element`) wait until scenes are created, otherwise `element not found` is expected during early startup frames.
- `signal` command passes event path verbatim; use canonical engine paths like `Engine\Cmd\Exit`.

### Demo compile/run practicals

- When compiling demos with FPC, use the standard engine include paths:
  - `-dOPENGL -MDelphi -Sd -RIntel -Fu<repo> -Fu<repo>\extra -Fu<repo>\extra\sdl2 -Fu<repo>\Base -Fu<repo>\Base\extra`.
- Always specify explicit unit output path (`-FU`) for every FPC compile command to keep `.ppu/.o` out of source folders.
- If object-file write conflicts happen (e.g. `Can't create object file ... .o (error code: 5)`), compile with explicit unit output folder in the demo dir:
  - `-FU<demo>\_fpc`.
- When switching platform defines (for example enabling/disabling `-dSDL`), always do a full clean rebuild first (delete old `*.ppu`/`*.o`) to avoid stale-unit glitches and false errors.
- Safety rule remains: do not run `.exe` unless user explicitly asks.

## Refactoring Notes

**Workflow**: when creating new modules, wait for user to review the interface before writing tests.

**Module migration algorithm:**
1. Remove `Apus.Common`, `Apus.CrossPlatform`, and any old modules that depend on them from `uses`
2. Compile with FPC directly to get the full list of errors.
   - For Base-only modules, a minimal command like `fpc -MDelphi -Sd -Fu<base_path> <Module.pas>` is acceptable.
   - For standalone engine units, avoid `-dSDL` unless SDL-specific code is being checked: `fpc -dOPENGL -MDelphi -Sd -RIntel -Fu<repo> -Fu<repo>\extra -Fu<repo>\extra\sdl2 -Fu<repo>\Base -Fu<repo>\Base\extra <Module.pas>`
3. Fix each error: replace old calls with new API (from Apus.Core/Conv/Strings/Log/Threads), or extract missing functions to the appropriate new module

**Build tools:**
- Do NOT create `.lpi` files вЂ” project uses FPC via `test.bat` or Delphi `.dproj` (created manually)
- Compile individual module: `fpc -MDelphi -Sd -Fu.. -FU<out_dir> <Module.pas>` (run from `Base/tests/`)
- Compile standalone engine unit: `fpc -dOPENGL -MDelphi -Sd -RIntel -Fu<repo> -Fu<repo>\extra -Fu<repo>\extra\sdl2 -Fu<repo>\Base -Fu<repo>\Base\extra -FU<out_dir> <Module.pas>` (`-dSDL` only for SDL-specific checks)
- Run tests: `test.bat <TestName>` (e.g. `test.bat EventMan`)

### Assertions and Runtime Checks

- **`ASSERT`** — programmer error checks (invalid arguments, broken invariants). Controlled by `{$C+}/{$C-}`.
- **`if` + raise/exit** — critical checks that must always run, even when assertions are disabled.
- Do NOT use `{$IFOPT R+}` for custom checks — prefer `ASSERT` for centralized control.


- use `UIntPtr` for pointerв†”integer conversion
- add comments after `{$ELSE}` when far from condition
- short end-of-line comments start lowercase: `a:=1; // initialize`
- do not add unit finalization unless needed
- **FPC quirk**: `single(10)` is a reinterpret cast (wrong!), use `single(10.0)` for proper type conversion
- **FPC quirk**: `$FF00000000000000` is int64 (signed), use `uint64($FF00000000000000)` for unsigned comparison
- **FPC quirk**: if you hit `Fatal: Internal error ...`, do a clean rebuild first by deleting all `*.ppu` and `*.o` files from repo/demo output folders, then rebuild

## License

BSD-3 - see `license.txt`

## Session Rules (Persistent)

- Test execution policy: run only tests (if they exist) that cover the changed modules or modules depending on them; do not run unrelated test suites. Use script wrappers with build step (`base/tests/test.bat` and `base/tests/bench.bat`) for any test/bench run.
- If there is no relevant automated test coverage for the changes, explicitly state that no applicable tests were found instead of running unrelated tests.
- Safety policy: never run prebuilt executables (`*.exe`) unless the user gives an explicit direct instruction to do so.
- Result policy: after test run, read result logs from `base/tests/test_results_64.txt` and `base/tests/test_results_32.txt` (or benchmark logs for benches).
- Base Library docs policy: treat `base/engine5_changes.md` and `base/engine5_status.md` as mandatory reference docs.
- Base library docs update rule: when interfaces or APIs are changed, update `base/engine5_changes.md` and `base/engine5_status.md` in the same task (or explicitly note why no update is required).
- Use and maintain Engine5 work ahead log in `engine_work_ahead.md`
- Code quality escalation rule: if a change introduces or reveals sloppy/duplicated local code, stop and design a reusable solution first. Prefer extending base types (including operators/methods), or adding shared helpers in Base modules, instead of one-off local workarounds.
