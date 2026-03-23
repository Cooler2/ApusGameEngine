# Engine5 Refactoring — Module Status

Status of every module in `Base/Apus.*.pas`.
Categories: **NEW** | **CLEAN** | **MIGRATE** | **EXTRACT** | **REWORK** | **DEPRECATED**

## Summary (last updated: 2026-03-22)

**Progress:**
- ✅ 10 new modules created (Core, Conv, Strings, Files, HashMaps, Log, Threads, Utils, Lib, Spatial)
- ✅ Threading and Logging blockers solved
- ✅ Classes + Structs migrated (Foundation Level 1 complete!)
- ✅ `UTF8.Format` added to Apus.Strings (native, no Unicode roundtrip)
- ✅ `Conv.ToStr(double)` implemented with auto/fixed/min-max decimal modes
- ✅ R-07 reached working state and was merged into `engine5` (engine-level milestone)
- ✅ EventMan migrated to Core/Log/Threads/Strings and compiles clean
- ✅ Base library no longer depends on `Apus.Common` (outside `Base/Deprecated`)
- ✅ `Base/Apus.Common.pas` removed; compatibility copy kept in `Base/Deprecated/Apus.Common.pas`
- ✅ Base migration is complete (100%); no global/blocking migration tasks remain
- 🔧 Post-merge priorities: Linux fixes + validation, benchmarks, SSE optimization of hot functions, bugfixes with test additions
- 🎯 **Next priorities:** stabilization, test expansion, performance tuning, and incremental cleanup of legacy Engine/Demo/Tools references

**Recent wins (2026-02-18):** Added `Conv.ToStr(double)` — locale-independent float formatting via Pascal `Str()`, supports `maxDec`/`minDec`/`decSep` params, 20 tests added to TestConv.

**Recent wins (2026-02-17):** Migrated Apus.Classes and Apus.Structs together (cyclic dependency resolved). Added FastHash/StrHash to Strings, `Same`/`Compare` to String8Helper, HasValue to Conv. Added `UTF8.Format(fmt, args)` — native String8 formatter, no SysUtils dependency.

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

## NEW — created in engine5 refactoring

| Module | Lines | Tests | Notes |
|--------|-------|-------|-------|
| **Apus.Core** | 1330 | TestCore | Min/Max, Clamp, Swap, Bits, Mem, NextPow2 |
| **Apus.Conv** | ~750 | TestConv | Conv.ToInt/ToFloat/ToBool, Hex, Base64, Format, ToStr(double) with maxDec/minDec/decSep |
| **Apus.Strings** | ~1550 | TestStrings | String8Helper methods (IndexOf, Trim, Split, ToUpper...), case-insensitive search via optional `ignoreCase`, UTF8.Format (native formatter) |
| **Apus.Files** | 729 | TestFiles | Files.Exists/Load/Save, Folder.ListFiles/Find/Copy/Delete, BOM-aware text I/O (`LoadAsString` strips BOM, `Save(String8)` adds BOM by default) |
| **Apus.HashMaps** | 1590 | TestHashMaps | Generic `THashMap<T>` is the preferred API. Supported specialized hashes: `THash` (multi-value), `TSimpleHash` (int64->int64), `TObjectHash`. Deprecated/compat: `TStrHash`, `TSimpleHashS/AS/8`, `TVarHash`. |
| **Apus.Log** | 373 | — | Unified logging: Log.Msg/Debug/Info/Warn/Error/Fatal, Logger.UseLogFile/Flush. Replaces Common logging + base for Apus.Logging refactor. |
| **Apus.Threads** | 714 | — | Thread synchronization (TLock with Enter/Leave methods), thread management (RegisterThread/PingThread), utilities (WaitFor). Cross-platform (Windows/Linux). **Solves blocker #1**. |
| **Apus.Utils** | 280 | — | Misc utilities: ParseDate/ParseTime (date parsing), cmdline helpers (`HasParam/GetParam`), SplitA (string splitting with quotes), Chop (trim). Default place for functions that don't fit other modules' scope. |
| **Apus.Lib** | 58 | — | Re-export facade (type aliases for convenient `uses`) |
| **Apus.Spatial** | 434 | — | Spatial primitives and intersections; adds methods-first API and extends TBBox3s via record helper. |

## CLEAN — old modules, no Common dependency, no changes needed

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
| **Apus.Classes** | 163 | ✅ **Migrated 2026-02-17**: uses Strings (FastHash), Conv (ToHex, HasValue), Structs. Foundation module (Level 1). |
| **Apus.Containers** | 1051 | TestContainers | Trees, heaps, queues and object list containers split from old `Apus.Structs`. |

## Apus.Common Status (2026-03-22)

- `Base/*.pas` has **no** `Apus.Common` dependency outside `Base/Deprecated`.
- Active compatibility unit is only `Base/Deprecated/Apus.Common.pas`.
- Remaining non-deprecated references are outside Base:
  - **Engine:** 20 files
  - **Demo:** 6 files
  - **Tools:** 2 files

### Remaining `Apus.Common` references (live files)

`Apus.Engine.AndroidGame.pas`, `Apus.Engine.AEMLoader.pas`, `Apus.Engine.BitmapStyle.pas`, `Apus.Engine.ComplexText.pas`, `Apus.Engine.DxImages8.pas`, `Apus.Engine.IOSgame.pas`, `Apus.Engine.IQMloader.pas`, `Apus.Engine.Model3D.pas`, `Apus.Engine.Networking2.pas`, `Apus.Engine.Networking3.pas`, `Apus.Engine.Objects.pas`, `Apus.Engine.OBJLoader.pas`, `Apus.Engine.PainterGL.pas`, `Apus.Engine.PainterGL2.pas`, `Apus.Engine.SoundBass.pas`, `Apus.Engine.SoundImx.pas`, `Apus.Engine.SoundSDL.pas`, `Apus.Engine.SpritePacker.pas`, `Apus.Engine.SteamAPI.pas`, `Apus.Engine.UDict.pas`, `demo/CharAnimation/MainScene.pas`, `demo/ControllerDemo/MainScene.pas`, `demo/NinePatch/MainScene.pas`, `demo/Particles/MainScene.pas`, `demo/ShadowMap/MainScene.pas`, `demo/Simple3D/MainScene.pas`, `tools/TreeGen/MainScene.pas`, `tools/TreeGen/Trees.pas`.

## Next priorities (updated)

1. Stabilize current Base APIs on Windows/Linux and close remaining edge cases.
2. Expand targeted automated tests and benchmarks for already-migrated modules.
3. Continue performance work (SSE hot paths, timing/profile-guided optimizations).
4. Do incremental cleanup of legacy `Apus.Common` references in Engine/Demo/Tools without treating it as a blocking track.

## TODO — important tasks

* **TScopedLock in FPC**: Investigate if RAII (Initialize/Finalize operators) can work in FPC. If not possible, remove TScopedLock entirely — engine should only include features that work with both compilers (Delphi + FPC).
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
* Don't try to use or keep MyTickCount - use GetTickCount64 instead. MyTickCount should not remain anywhere.
