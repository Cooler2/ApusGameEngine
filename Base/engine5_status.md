# Engine5 Refactoring — Module Status

Status of every module in `Base/Apus.*.pas`.
Categories: **NEW** | **CLEAN** | **MIGRATE** | **EXTRACT** | **REWORK** | **DEPRECATED**

## Summary (last updated: 2026-09-26)

**Progress:**
- ✅ `Time.Ticks` uses the high-resolution monotonic platform counter with direct
  millisecond scaling; Windows granularity is no longer limited by `GetTickCount64`.
- ✅ 10 new modules created (Core, Conv, Strings, Files, HashMaps, Log, Threads, Utils, Lib, Spatial)
- ✅ Threading and Logging blockers solved
- ✅ Managed threads force-log unhandled callback exceptions before reporting `Error`
- ✅ EventMan removes and warns about dangling thread-affine handlers on thread exit
- ✅ `Apus.Socket` public declarations use portable `NativeUInt`/`UIntPtr` types in Delphi and FPC
- ✅ Glyph cache bounds failures are explicit; TextDraw no longer writes past its update-row list
- ✅ Platform-native `Apus.Core.LineBreak` is used by Robot API diagnostics and both active loggers
- ✅ Classes migrated and legacy Structs split completed (Foundation Level 1 complete!)
- ✅ `UTF8.Format` added to Apus.Strings (native, no Unicode roundtrip)
- ✅ `Conv.ToStr(double)` implemented with auto/fixed/min-max decimal modes
- ✅ R-07 reached working state and was merged into `engine5` (engine-level milestone)
- ✅ EventMan migrated to Core/Log/Threads/Strings and compiles clean
- ✅ Base library no longer depends on `Apus.Common`
- ✅ `Apus.Common` removed from the repository, including the old `Base/Deprecated` copy; remaining users live in `legacy/` folders (see below)
- ✅ Base migration is complete (100%); no global/blocking migration tasks remain
- 🔧 Post-merge priorities: Linux fixes + validation, benchmarks, SSE optimization of hot functions, bugfixes with test additions
- ✅ Linux/FPC engine smoke coverage added for SDL/OpenGL compile-only paths (`tests/PlatformTest.dpr`, `tests/OpenGL.dpr`)
- ✅ Linux/FPC Base build sweep includes `Apus.Compress`
- ✅ Linux/FPC style test and modern SDL/OpenGL demo compile coverage verified
- ✅ Android JNI initialization stores the VM pointer used to attach and detach
  engine worker threads
- ✅ Units, demos and tools still on `Apus.Common` moved to `legacy/`, `demo/legacy/`, `tools/legacy/` (preview preparation, 2026-09-26)
- 🎯 **Next priorities:** stabilization, test expansion, performance tuning, and migration of what is parked in the `legacy/` folders

**Recent wins (2026-02-18):** Added `Conv.ToStr(double)` — locale-independent float formatting via Pascal `Str()`, supports `maxDec`/`minDec`/`decSep` params, 20 tests added to TestConv.

**Recent wins (2026-02-17):** Migrated the Classes/Structs dependency knot as part of the foundation refactor. Added FastHash/StrHash to Strings, `Same`/`Compare` to String8Helper, HasValue to Conv. Added `UTF8.Format(fmt, args)` — native String8 formatter, no SysUtils dependency.

**Recent wins (2026-02-19):** Fixed `Apus.Core` API defects in `Min/Max` overload return types (`cardinal/int64/uint64`, and 3-arg `single`). Removed lossy `trunc()` logic from `Min/Max(a,b,c:single)`.

**Recent wins (2026-02-22):** Added case-insensitive search support in `Apus.Strings` (`IndexOf/LastIndexOf/Contains` for `String8` and `String32` with optional `ignoreCase`), plus coverage in `TestStrings`.
**Recent wins (2026-02-22):** Migrated `Apus.HtmlTree` from `string` to `String8` API and switched local search helper to `String8.IndexOf(...,ignoreCase)`.
**Recent wins (2026-02-26):** Added `IntArrayHelper` in `Apus.Core` (`IndexOf/Contains/Add/Remove`) and replaced legacy `FindInteger(... )` usage in UI code with `tags.IndexOf(tag)`.
**Recent wins (2026-02-26):** Restored optional caller override in `Apus.Threads.TLock.Enter(callerAddr:pointer=nil)` for wrapper-safe lock diagnostics.
**Recent wins (2026-02-27):** Migrated `Apus.FreeTypeFont` text API from `WideString/WideChar` to `String32/Char32`, and removed 16-bit codepoint truncation in FreeType calls.
**Recent wins (2026-02-27):** Added `String32Helper.TryAnsiChar/AnsiChar` in `Apus.Strings` and migrated `ParseSML`/`WriteW` indexing in `Apus.Engine.TextDraw` to 0-based `String32` semantics.
**Recent wins (2026-02-27):** Extracted `GetEnumNameSafe(typeInfo,value)` from deprecated `Apus.Common` into `Apus.Utils`, and switched `Apus.Engine.API` to explicit `uses Apus.Utils`.
**Recent wins (2026-02-27):** Added `String32Helper.Split(delimiters,quoteChar)` overload for delimiter-set splitting with quote-aware behavior (parity with `String8.Split`).
**Recent wins (2026-03-11):** Added new module Apus.Spatial with compile-ready spatial API skeleton (TVec2/TVec3/TVec4, TRay, TSphere, TFrustum), methods-first intersections, and TBBox3s helper extensions.
**Recent wins (2026-03-14):** Fixed `Apus.EventMan.SetEventHandler` deduplication to include thread affinity (`threadNum` + `mode`) so identical handlers can be registered from multiple queued/mixed threads; added multi-thread regression tests in `TestEventMan` (including same-handler-per-thread queued delivery).
**Recent wins (2026-03-18):** Finalized hash type policy in `Apus.HashMaps`: `THashMap<T>` remains preferred generic API; `THash`, `TSimpleHash`, `TObjectHash` are supported specialized types; `TVarHash` moved to deprecated/compat group.
**Recent wins (2026-03-18):** Split container API into new `Apus.Containers`; removed `Apus.Structs`; replaced `TestStructs` with `TestContainers`.
**Recent wins (2026-03-19):** Added `TestTypes` and fixed `Apus.Types` defects found by edge-case tests (`TBitStream` write/resize/bit-mask behavior and `TNameValueList.Init(st,...)` constructor delegation).
**Recent wins (2026-03-19):** Moved record sorting API from `Apus.Types` to `Apus.Core.Sort` (`Sort.ByInt/ByFloat/ByDouble/ByStr`) and moved sorting tests to `TestCore`.
**Recent wins (2026-03-19):** Restored `HasParam/GetParam` in `Apus.Utils` (migrated from deprecated `Apus.Common`) and switched `Apus.Engine.GameApp` command-line platform selection to these helpers (`-SDL`, `-WINDOWS`, `-PLATFORM=...`).
**Recent wins (2026-03-22):** Added `Time.TicksUs` and `Time.TicksSec` to `Apus.Core` as explicit high-precision monotonic APIs (QPC/clock_gettime based), while keeping `Time.Ticks` as compatibility millisecond API.
**Recent wins (2026-03-22):** Extended `Base/tests/BenchCore` with direct timing-cost comparison for `Time.Ticks`, `Time.TicksUs`, and `Time.TicksSec`.
**Recent wins (2026-03-23):** Extended `Apus.Geom2D.TRect2` with `Contains(const p:TPoint)` and `Contains(x,y:single)`; Engine window hit-testing switched to type-level methods instead of local helper functions.
**Recent wins (2026-03-23):** `Apus.Files.TFileHandle` now supports object-style I/O (`Read/Write/Seek/Close`) plus untyped buffer overloads (`Read(var buf,...)`, `Write(const buf,...)`); raw pointer access in object API is explicit as `ReadMem/WriteMem` to avoid pointer-overload ambiguity.
**Recent wins (2026-03-23):** Fixed `Apus.Tweenings` runtime defects: scalar `TTweening.Animate(newValue:single,...)` recursion (stack overflow) and division-by-zero in compensation path for `duration=0` with delayed re-targeting.
**Recent wins (2026-03-23):** Added dedicated `TestTweenings` coverage for `Apus.Tweenings` (basic interpolation, vector tweening, interruption flow, zero-duration edge cases with delay).
**Recent wins (2026-03-23):** Added optional test-time monotonic override API in `Apus.Core.Time` under `{$IFDEF TIME_OVERRIDE}` (`Override(timeUs:int64)`), applied consistently to `TicksUs/Ticks/TicksSec`, with zero runtime cost when define is off.
**Recent wins (2026-03-23):** Updated test runner scripts (`Base/tests/test.bat`, `Base/tests/test.sh`) to compile tests with `-dTIME_OVERRIDE` by default.
**Recent wins (2026-03-23):** Added `Base/tests/BenchAnimation.dpr` to compare `TTweening` vs `TAnimatedValue` in matched read/retarget scenarios (including realistic overlap cap).
**Recent wins (2026-03-24):** Standardized `Apus.Core.SRound` behavior across SSE and non-ASM paths to the same rule (`floor(v+0.5)`), and documented intended usage split (`SRound` for translation-invariant render math, `PRound` for symmetric nearest rounding).
**Recent wins (2026-05-29):** Linux/FPC engine compile sweep now reaches and passes SDL/OpenGL smoke tests after fixing `Apus.Engine.API` display aliases, SDL cursor dispatch, and old window/gfx lifecycle plus deprecated Base-unit usage in `tests/PlatformTest.dpr` and `tests/OpenGL.dpr`.
**Recent wins (2026-05-30):** Added `Apus.Compress` to the Linux/FPC Base build sweep.
**Recent wins (2026-05-30):** Fixed Linux case-sensitive include lookup in `tests/TestStyle.dpr`; the style regression test passes on Linux/FPC. Added `tests/linux_smoke.sh` for repeatable Linux/FPC checks of the style test, SDL/OpenGL smoke tests, and compatible modern demos.
**Recent wins (2026-05-30):** Updated `TestConv` to the current `Conv.FormatIp` and boolean formatting contracts; all `135` checks pass on Linux/FPC.
**Recent wins (2026-05-30):** Fixed Linux/FPC `Thread.Start` range-check failures by preserving the POSIX `pthread_t` return value without narrowing through `THandle`; all `65` `TestThreads` checks pass.
**Recent wins (2026-05-30):** Fixed `Apus.EventMan.Link` to preserve linked-event spelling for handlers while retaining case-insensitive matching; all `39` `TestEventMan` checks pass on Linux/FPC.
**Recent wins (2026-05-30):** Made zero-length `TVec2`/`TVec2d` normalization explicitly produce NaN without Linux/FPC floating-point traps; all `78` `TestGeom2D` checks pass.
**Recent wins (2026-05-30):** Disabled Win64-ABI-only `TMat4` SSE helpers on Linux x64 so System V builds use the existing Pascal fallback; all `80` `TestGeom3D` checks pass.
**Recent wins (2026-05-30):** Fixed Linux Base test-runner exit status propagation and added `Base/tests/test_all.sh` for the deterministic Linux-compatible regression set.
**Recent wins (2026-05-30):** Implemented the previously missing SDL shared OpenGL context lifecycle for secondary windows; Linux/WSL `MultiWindow` runtime verification created and closed a live `Tool 1` window successfully.
**Recent wins (2026-05-30):** Added the required FPC/Unix `cthreads` driver to maintained demo entrypoints so thread-backed engine applications can start on Linux.
**Recent wins (2026-05-30):** Implemented the missing SDL scan-code to virtual-key mapping and removed an uninitialized-result path.
**Recent wins (2026-05-30):** Fixed SDL startup to avoid probing joystick index `0` when no controllers are connected.
**Recent wins (2026-05-30):** Fixed SDL screen-coordinate helpers for window-relative conversion and global mouse position queries.
**Recent wins (2026-05-30):** Made SDL close handling multi-window aware: termination state is per-window and close events are routed by native SDL window ID. Linux/WSL runtime verification closed `Tool 1` while the main window continued running.
**Recent wins (2026-06-09):** Replaced ~25 global color functions in `Apus.Colors` with static methods on a new `Color` record type (`Color.RGB`, `Color.Blend`, `Color.Add`, etc.); `BilinearMixF` and pointer-based `BilinearMix(PCardinal)` kept as free functions; `Color`/`TARGBColor`/`InvalidColor` re-exported via `Apus.Lib`.
**Recent wins (2026-06-09):** Added shared typed row-pointer helpers in `Apus.Core` (`PByteRow`, `PWordRow`, `PIntRow`, `PCardinalRow`, `PSingleRow`) plus `TTexture.ScanLine(y)` and `TTexture.PixelPtr(x,y)` in `Apus.Engine.Resources`, so locked texture code can use explicit casts like `PCardinalRow(tex.ScanLine(y))` and direct pixel addressing without repeating raw `data+pitch` arithmetic.
**Recent wins (2026-06-19):** Renamed engine networking modules to descriptive names: `Apus.Engine.Networking3` is now `Apus.Engine.HttpGameClient`, and `Apus.Engine.Networking2` is now `Apus.Engine.UdpTransport`.
**Recent wins (2026-06-19):** Removed legacy `Apus.Engine.PainterGL` and `Apus.Engine.PainterGL2`; active rendering goes through `Apus.Engine.OpenGL` and the `IGraphicsSystem`/`IDrawer` stack.
**Recent wins (2026-09-06):** Unhandled `Thread.Start` exceptions now retain their class, raw exception address, available FPC stack frames, and message in both the forced log and `IThread.StatusText`; raw-`TThread` tests use the same `Apus.Core.ExceptionMsg` path.
**Recent wins (2026-09-26):** New `Apus.Engine.TextEffects` (R-33): `DrawTextFX` draws text with effect layers (glow, outline, shadow): each layer is color + offset + spread (round dilation) + gaussian blur, with `Glow`/`Outline`/`Shadow` constructors. The text is baked once on GPU through the regular `txt.Write` path (so SML, fallback fonts, multi-line and glyph positions match plain text) and cached as a sprite; alpha is applied at draw time. Showcase: TextDemo screen 9; `tests/TestTextEffects.dpr` checks it against a CPU reference within 2/255.

- 2026-09-26: R-32 adds static WebP decode and fixes FPC PNG grayscale target writes; Win64, Linux x64, and Android arm64 decoder binaries are bundled; Android runtime is not yet verified. See PNG_DECODERS.md for decoder comparison and deployment limits.

## Live module inventory (2026-09-26)

Generated from the 56 live `Base/Apus.*.pas` files. "Build sweep" is what
`Base/tests/buildtest.ps1` (Win) and `Base/tests/buildtest.sh` (Linux, macOS in CI)
compile; "not in sweep" means the module is live but only compiled through the
tests or the engine.

| Module | Build sweep | Focused tests/benches | Notes |
|---|---|---|---|
| `Apus.ADPCM` | Win/Linux/macOS | - |  |
| `Apus.Android` | not in sweep | - | Android-specific module. |
| `Apus.AnimatedValues` | Win/Linux/macOS | - | Covered indirectly by `BenchAnimation`. |
| `Apus.CPU` | Win/Linux/macOS | - |  |
| `Apus.Classes` | Win/Linux/macOS | - | Foundation module; uses `Apus.HashMaps` in implementation. |
| `Apus.Clipboard` | Win/Linux/macOS | - |  |
| `Apus.Colors` | Win/Linux/macOS | - | `Color` record static-method API (2026-06-09); no free functions except `BilinearMixF` and `BilinearMix(PCardinal)`. |
| `Apus.Compress` | Linux/macOS | TestCompress | Not in the Windows sweep (`buildtest.ps1`) yet. |
| `Apus.Containers` | Win/Linux/macOS | TestContainers, BenchContainers |  |
| `Apus.ControlFiles` | Win/Linux/macOS | - |  |
| `Apus.Conv` | Win/Linux/macOS | TestConv, BenchConv |  |
| `Apus.Core` | Win/Linux/macOS | TestCore, BenchCore, BenchMem |  |
| `Apus.Crypto` | Win/Linux/macOS | - |  |
| `Apus.Database` | Win/Linux/macOS | - |  |
| `Apus.EventMan` | Win/Linux/macOS | TestEventMan |  |
| `Apus.FastGFX` | Win/Linux/macOS | BenchFastGFX | Add focused regression tests if software-rendering changes are made. |
| `Apus.Files` | Win/Linux/macOS | TestFiles |  |
| `Apus.FreeTypeFont` | Win/Linux/macOS | - |  |
| `Apus.GeoIP` | Win/Linux/macOS | - |  |
| `Apus.Geom2D` | Win/Linux/macOS | TestGeom2D, BenchGeom2D |  |
| `Apus.Geom3D` | Win/Linux/macOS | TestGeom3D, BenchGeom3D |  |
| `Apus.GfxFilters` | Win/Linux/macOS | TestGfxFilters |  |
| `Apus.GfxFormats` | Win/Linux/macOS | TestGfxFormats, BenchR32PNG | Static WebP decode is opt-in with WEBP; PNG decoder comparison in PNG_DECODERS.md. |
| `Apus.GlyphCache` | Win/Linux/macOS | TestGlyphCache |  |
| `Apus.HashMaps` | Win/Linux/macOS | TestHashMaps, BenchHashMaps |  |
| `Apus.HtmlTree` | Win/Linux/macOS | - |  |
| `Apus.HttpRequests` | Win/Linux/macOS | - |  |
| `Apus.HttpServer` | not in sweep | TestHttpServer | Minimal HTTP/1.1 server over `Apus.TCP`; compiled through `TestHttpServer`. |
| `Apus.Huffman` | Win/Linux/macOS | - |  |
| `Apus.Images` | Win/Linux/macOS | - |  |
| `Apus.Lib` | Win/Linux/macOS | - |  |
| `Apus.Log` | Win/Linux/macOS | - |  |
| `Apus.Logging` | Win/Linux/macOS | - |  |
| `Apus.LongMath` | Win/Linux/macOS | - |  |
| `Apus.MemoryLeakUtils` | Win/Linux/macOS | - |  |
| `Apus.Network` | not in sweep | - | Deprecated (prefer `Apus.Socket`); kept only for `Apus.Engine.UdpTransport`, which `tests/TestUdpTransport` compiles. |
| `Apus.ProdCons` | Win/Linux/macOS | - |  |
| `Apus.Profiling` | Win | - | Not built on Linux/macOS: the implementation uses the `Windows` unit. |
| `Apus.Publics` | Win/Linux/macOS | - |  |
| `Apus.RSA` | Win/Linux/macOS | - |  |
| `Apus.RegExpr` | Win/Linux/macOS | - |  |
| `Apus.Regions` | Win/Linux/macOS | - |  |
| `Apus.SCGI` | Win/Linux/macOS | - |  |
| `Apus.Socket` | Win/Linux/macOS | - |  |
| `Apus.Spatial` | Win/Linux/macOS | TestSpatial |  |
| `Apus.StackTrace` | Win/Linux/macOS | - |  |
| `Apus.Strings` | Win/Linux/macOS | TestStrings, BenchStrings |  |
| `Apus.TCP` | Win/Linux/macOS | TestTCP |  |
| `Apus.TextUtils` | Win/Linux/macOS | - |  |
| `Apus.Threads` | Win/Linux/macOS | TestThreads |  |
| `Apus.Translation` | Win/Linux/macOS | - |  |
| `Apus.Tweenings` | Win/Linux/macOS | TestTweenings, BenchAnimation |  |
| `Apus.Types` | Win/Linux/macOS | TestTypes |  |
| `Apus.UnicodeFont` | Win/Linux/macOS | - |  |
| `Apus.Utils` | Win/Linux/macOS | - |  |
| `Apus.VertexLayout` | Win/Linux/macOS | - |  |

## Historical summary — created in engine5 refactoring

The live module inventory above is the authoritative full module list. The
tables below are a compact historical summary of major refactoring groups and
are not intended to enumerate every live `Base/Apus.*.pas` unit.

| Module | Lines | Tests | Notes |
|--------|-------|-------|-------|
| **Apus.Core** | 1330 | TestCore | Min/Max, Clamp, Swap, Bits, Mem, NextPow2 |
| **Apus.Conv** | ~750 | TestConv | Conv.ToInt/ToFloat/ToBool, Hex, Base64, Format, ToStr(double) with maxDec/minDec/decSep |
| **Apus.Strings** | ~1550 | TestStrings | String8Helper methods (IndexOf, Trim, Split, ToUpper...), case-insensitive search via optional `ignoreCase`, UTF8.Format (native formatter) |
| **Apus.Files** | 729 | TestFiles | Files.Exists/Load/Save, Folder.ListFiles/Find/Copy/Delete, BOM-aware text I/O (`LoadAsString` strips BOM, `Save(String8)` adds BOM by default) |
| **Apus.HashMaps** | 1590 | TestHashMaps | Generic `THashMap<T>` is the preferred API. Supported specialized hashes: `THash` (multi-value), `TSimpleHash` (int64->int64), `TObjectHash`. Deprecated/compat: `TStrHash`, `TSimpleHashS/AS/8`, `TVarHash`. |
| **Apus.Log** | 456 | — | Unified logging: Log.Msg/Debug/Info/Warn/Error/Fatal, Logger.UseLogFile/Flush; Android mirrors `Forced+` to logcat as `ApusEngine`. Replaces Common logging + base for Apus.Logging refactor. |
| **Apus.Threads** | 714 | — | Thread synchronization (TLock with Enter/Leave methods), thread management (RegisterThread/PingThread), utilities (WaitFor). Cross-platform (Windows/Linux). **Solves blocker #1**. |
| **Apus.Utils** | 280 | — | Misc utilities: ParseDate/ParseTime (date parsing), cmdline helpers (`HasParam/GetParam`), SplitA (string splitting with quotes), Chop (trim). Default place for functions that don't fit other modules' scope. |
| **Apus.Lib** | 58 | — | Re-export facade (type aliases for convenient `uses`) |
| **Apus.Spatial** | 434 | — | Spatial primitives and intersections; adds methods-first API and extends TBBox3s via record helper. |

## Historical summary — old modules already cleaned

| Module | Lines | Notes |
|--------|-------|-------|
| **Apus.Types** | 760 | Foundation types, `TBuffer`, `TBitStream`. Covered by `TestTypes` (x64/x86). Level 0. |
| **Apus.CPU** | 157 | CPU detection, CPUID. Level 0. |
| **Apus.Crypto** | 430 | MD5, SHA, CRC32. Level 0. |
| **Apus.ADPCM** | 123 | Audio compression. Level 0. |
| **Apus.LongMath** | 1160 | Big integer math. Level 0. |
| **Apus.RegExpr** | 69 | Thin wrapper for RegExpr. Level 0. |
| **Apus.Geom3D** | 2759 | Matrices, quaternions, 3D math. Uses Types only. |
| **Apus.Tweenings** | 302 | Tweening interpolation with smooth interruption compensation (`g(u)`), scalar and 1..4 component modes. Covered by `TestTweenings`. |
| **Apus.AnimatedValues** | 328 | Animated floats. Uses Tweenings only. |
| **Apus.Classes** | 163 | ✅ **Migrated 2026-02-17**: now uses Core/Types in the interface and HashMaps in implementation. Foundation module (Level 1). |
| **Apus.Containers** | 1051 | TestContainers | Trees, heaps, queues and object list containers split from old `Apus.Structs`. |

## Apus.Common Status (2026-09-26)

`Apus.Common` and `Apus.CrossPlatform` are gone from the repository (the
`Base/Deprecated` compatibility copy was removed as well). No live file references
them: every remaining user was either migrated or moved to a `legacy/` folder,
where it does not build until migrated:

- `legacy/` - engine units (skeletal models `Model3D`/`IQMloader`/`AEMLoader`,
  `SoundBass`, `SoundImx`, `SteamAPI`, `UDict`, `BitmapStyle`, `ComplexText`,
  `Objects`, `SpritePacker`) and `legacy/Base/` (old TCP demo, ListFonts);
  see `legacy/README.md`.
- `demo/legacy/` - 8 demos; see `demo/legacy/README.md` and `demo/demo_inventory.md`.
- `tools/legacy/` - 7 tools; see `tools/legacy/README.md`.

Checked with `grep -rlE "\bApus\.(Common|CrossPlatform)\b"` over `*.pas`, `*.dpr`,
`*.lpr`, `*.inc` outside the `legacy/` folders: no matches.

## Next priorities (updated)

1. Stabilize current Base APIs on Windows/Linux and close remaining edge cases.
2. Expand targeted automated tests and benchmarks for already-migrated modules.
3. Continue performance work (SSE hot paths, timing/profile-guided optimizations).
4. Migrate what is parked in `legacy/`, `demo/legacy/` and `tools/legacy/` when it is needed (skeletal models go with R-03), without treating it as a blocking track.

## TODO — important tasks

* **Vector math operations**: Add Clamp/Wrap/Lerp/Min/Max for vector types (TPoint2s, TPoint3s, TVector2, TVector3, TVector4). Currently scalar-only. Belongs in Apus.Geom2D/Geom3D helper methods or a dedicated Apus.VectorMath module.

## Would be nice to do (but not required)

* Optimize `UTF8.Format` performance in Delphi (currently significantly slower than `SysUtils.Format` in Delphi builds; FPC performance is comparable)
* Optimize Mem.FillW/FillQ/FillF with SSE (currently simple loops, only FillD is SSE-optimized)
* Optimize Mem.Copy with SSE for large blocks (currently uses RTL move())
* Optimize Mem.IsZero with SSE (currently manual loop with NativeUInt alignment)
* Audit Mem.Shift for overlapping regions (currently uses move() which may not handle all cases)
* Add utility to expand stack traces with code lines using MAP file (if exists)

## Consider during migration

* Convert RTL/System calls to new library calls when applicable during code migration (for example, use Bits.xxx for flags checking, Conv.xxx instead of SysUtils, etc.)
* Replace use of critical sections / TLock to lighter options when possible, for example use SpinLock to protect short access to global variables
* Replace String16 / WideString to String32, use String8 for everything, where direct character indexing is not required. Avoid use of String.
* Don't create any compatibility aliases. Old types should be changed to new types as well as function calls.
* Don't try to use or keep MyTickCount - use Time.Ticks instead. MyTickCount should not remain anywhere.
