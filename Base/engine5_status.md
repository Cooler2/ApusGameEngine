# Engine5 Refactoring — Module Status

Status of every module in `Base/Apus.*.pas`.
Categories: **NEW** | **CLEAN** | **MIGRATE** | **EXTRACT** | **REWORK** | **DEPRECATED**

## Summary (last updated: 2026-02-22)

**Progress:**
- ✅ 9 new modules created (Core, Conv, Strings, Files, HashMaps, Log, Threads, Utils, Lib)
- ✅ Threading and Logging blockers solved
- ✅ Classes + Structs migrated (Foundation Level 1 complete!)
- ✅ `UTF8.Format` added to Apus.Strings (native, no Unicode roundtrip)
- ✅ `Conv.ToStr(double)` implemented with auto/fixed/min-max decimal modes
- 🔧 EventMan partially migrated, needs completion
- 🚧 35 of 52 Base modules still use Common
- 🎯 **Next priorities:** Complete EventMan, Migrate ControlFiles, Deprecate CrossPlatform

**Recent wins (2026-02-18):** Added `Conv.ToStr(double)` — locale-independent float formatting via Pascal `Str()`, supports `maxDec`/`minDec`/`decSep` params, 20 tests added to TestConv.

**Recent wins (2026-02-17):** Migrated Apus.Classes and Apus.Structs together (cyclic dependency resolved). Added FastHash/StrHash/SameText8 to Strings, HasValue to Conv. Added `UTF8.Format(fmt, args)` — native String8 formatter, no SysUtils dependency.

**Recent wins (2026-02-19):** Fixed `Apus.Core` API defects in `Min/Max` overload return types (`cardinal/int64/uint64`, and 3-arg `single`). Removed lossy `trunc()` logic from `Min/Max(a,b,c:single)`.

**Recent wins (2026-02-22):** Added case-insensitive search support in `Apus.Strings` (`IndexOf/LastIndexOf/Contains` for `String8` and `String32` with optional `ignoreCase`), plus coverage in `TestStrings`.
**Recent wins (2026-02-22):** Migrated `Apus.HtmlTree` from `string` to `String8` API and switched local search helper to `String8.IndexOf(...,ignoreCase)`.

## NEW — created in engine5 refactoring

| Module | Lines | Tests | Notes |
|--------|-------|-------|-------|
| **Apus.Core** | 1330 | TestCore | Min/Max, Clamp, Swap, Bits, Mem, NextPow2 |
| **Apus.Conv** | ~750 | TestConv | Conv.ToInt/ToFloat/ToBool, Hex, Base64, Format, ToStr(double) with maxDec/minDec/decSep |
| **Apus.Strings** | ~1550 | TestStrings | String8Helper methods (IndexOf, Trim, Split, ToUpper...), case-insensitive search via optional `ignoreCase`, UTF8.Format (native formatter) |
| **Apus.Files** | 729 | TestFiles | Files.Exists/Load/Save, Folder.ListFiles/Find/Copy/Delete |
| **Apus.HashMaps** | 248 | TestHashMaps | Generic THashMap<T>, extracted from Structs |
| **Apus.Log** | 373 | — | Unified logging: Log.Msg/Debug/Info/Warn/Error/Fatal, Logger.UseLogFile/Flush. Replaces Common logging + base for Apus.Logging refactor. |
| **Apus.Threads** | 714 | — | Thread synchronization (TLock with Enter/Leave methods), thread management (RegisterThread/PingThread), utilities (WaitFor). Cross-platform (Windows/Linux). **Solves blocker #1**. |
| **Apus.Utils** | 280 | — | Misc utilities: ParseDate/ParseTime (date parsing), SplitA (string splitting with quotes), Chop (trim). Default place for functions that don't fit other modules' scope. |
| **Apus.Lib** | 58 | — | Re-export facade (type aliases for convenient `uses`) |

## CLEAN — old modules, no Common dependency, no changes needed

| Module | Lines | Notes |
|--------|-------|-------|
| **Apus.Types** | 760 | Foundation types, TBuffer. Level 0. TEMP: uses Common for ParseDate/SplitA (need extraction). |
| **Apus.CPU** | 157 | CPU detection, CPUID. Level 0. |
| **Apus.Crypto** | 430 | MD5, SHA, CRC32. Level 0. |
| **Apus.ADPCM** | 123 | Audio compression. Level 0. |
| **Apus.LongMath** | 1160 | Big integer math. Level 0. |
| **Apus.RegExpr** | 69 | Thin wrapper for RegExpr. Level 0. |
| **Apus.Geom3D** | 2759 | Matrices, quaternions, 3D math. Uses Types only. |
| **Apus.AnimatedValues** | 328 | Animated floats. Uses Tweenings only (but Tweenings uses Common!). |
| **Apus.Classes** | 163 | ✅ **Migrated 2026-02-17**: uses Strings (FastHash), Conv (ToHex, HasValue), Structs. Foundation module (Level 1). |
| **Apus.Structs** | 2612 | ✅ **Migrated 2026-02-17**: uses Strings (FastHash), Classes (TNamedObject). Old types (StringArray8→Strings8, AStringArr→Strings8) replaced directly. |

## MIGRATE — old modules that use Common, need API call replacement

These modules `uses Apus.Common` and call old API functions.
Migration = replace `uses Common` with appropriate new modules + rename function calls.

### Trivial (only type aliases or 1-2 calls)

| Module | Lines | What it uses from Common |
|--------|-------|--------------------------|
| **Apus.RSA** | 633 | Common only under `{$IFDEF SELF_TEST}`. Production code is clean. |
| **Apus.Huffman** | 130 | Type aliases only (ByteArray, WordArray, UIntArray) → replace with `uses Apus.Types` |
| **Apus.Tweenings** | 130 | Clamp only → replace with `uses Apus.Core` |
| **Apus.Regions** | 213 | FileName() call → replace with `Files.FileName()` |
| **Apus.Profiling** | 155 | EWarning only → replace with `uses Apus.Classes` |
| **Apus.GeoIP** | 159 | Minimal dependency |

### Light (a few old calls to replace)

| Module | Lines | What it uses from Common |
|--------|-------|--------------------------|
| **Apus.Colors** | 535 | min2d, max2d, Clamp → Core.Min/Max/Clamp |
| **Apus.FastGFX** | 2121 | min2, max2, Clamp → Core.Min/Max/Clamp |
| **Apus.Geom2D** | 1080 | min2, max2, min2d, max2d, min2s, max2s, Swap → all in Core |
| **Apus.Images** | 595 | min2, max2, Clamp + LogMessage, ForceLogMessage |
| **Apus.VertexLayout** | 387 | FormatHex → Conv.ToHex |
| **Apus.Clipboard** | 214 | EWarning, EError → Classes |
| **Apus.MemoryLeakUtils** | 176 | EError → Classes |
| **Apus.StackTrace** | 121 | FormatHex → Conv.ToHex. LogMessage in impl. |
| **Apus.TCP** | 539 | LogMessage, ForceLogMessage |
| **Apus.Socket** | 136 | LogMessage + InitCritSect/EnterCS/LeaveCS |
| **Apus.ProdCons** | 219 | Clamp, MyTickCount |

### Medium (multiple old API groups)

| Module | Lines | What it uses from Common |
|--------|-------|--------------------------|
| **Apus.GfxFormats** | 1337 | LoadFileAsBytes, SaveFile, min2, max2, SplitA, ParseInt |
| **Apus.GlyphCaches** | 671 | LogMessage, max2, PackBytes, PackWords, ExceptionMsg |
| **Apus.TextUtils** | 260 | ParseInt, PosFrom, LastPos, SplitA, string type aliases |
| **Apus.UnicodeFont** | 466 | LogMessage, ForceLogMessage, min2, max2, Clamp |
| **Apus.FreeTypeFont** | 363 | LogMessage, type aliases |
| **Apus.GfxFilters** | 1385 | Needs audit — large module |
| **Apus.Database** | 515 | String8, StringArr, MyTickCount, parsing |
| **Apus.Translation** | 416 | EncodeUTF8, DecodeUTF8 |
| **Apus.HtmlTree** | 665 | String8 API (Parse/Tree/Attributes), String8.IndexOf(ignoreCase) |

### Heavy (deep Common dependency, infrastructure modules)

| Module | Lines | What it uses from Common | Priority |
|--------|-------|--------------------------|----------|
| **Apus.EventMan** | 634 | **WIP** — Partially migrated to Log/Threads/Classes. Event system (Signal/Link). Core infrastructure. Needs completion + tests. | **HIGH** |
| **Apus.HttpRequests** | 1036 | LogMessage, ForceLogMessage, ExceptionMsg, UrlEncode, MyTickCount, InitCritSect, Enter/LeaveCS, Split | MEDIUM |
| **Apus.ControlFiles** | 1827 | Split, SplitA, Chop, QuoteStr, UnQuoteStr, InitCritSect, Enter/LeaveCS. **Blocked by Apus.Structs**. Uses TGenericTree, TStrHash. | LOW |
| **Apus.SCGI** | 1383 | Needs audit — large module | LOW |
| **Apus.Android** | 465 | ForceLogMessage, EncodeUTF8, AddString, SaveFile. Platform-specific. | LOW |
| **Apus.Publics** | 1184 | EncodeUTF8, DecodeUTF8, ParseInt, SplitA. Public variable system. | LOW |

## EXTRACT — code still trapped inside Common that belongs in these modules

| Target module | What to extract from Common | Est. lines |
|---------------|---------------------------|------------|
| **Apus.Log.Memory** (TBD) | Refactor old Apus.Logging into memory log handler that uses new Apus.Log via SetCustomHandler. Extract daily rotation, FetchLog, flood protection, SaveMessages functionality. | ~300 |
| **Apus.Core** (extend) | Math: FRound, PRound, SRound, FastFloor, Wrap, Ratio, Pike, FastInvSqrt. Bits: GetBits, SetBits. Pack: PackBytes, PackWords, ExtractByte, ExtractWord. Random: TRandom, PseudoRand, RandomInt, RandomStr. Checksum: CalcCheckSum, CheckSum64, FillRandom. | ~400 |
| **Apus.Conv** (extend) | Date/Time: HowLong, NowGMT→Time.UTC, GetUTCTime→Time.Stamp, MyTickCount→removed. Encoding: ConvertToWindows/FromWindows, Win1251↔UTF8, BinToStr/StrToBin. | ~200 |
| **Apus.Strings** (extend) | ✅ EncodeUTF8/DecodeUTF8 already as `UTF8.Encode`/`UTF8.Decode`. Still needed: Str8, Str16, SafeStrItem, LastChar, Unescape, DumpStr. | ~150 |
| **Apus.Structs** (extend) | Sorting: SortObjects, SortRecordsByDouble/Float/Int, SortStrings, IndexRecordsByFloat. Array helpers: AddString, RemoveString, FindString, AddInteger, RemoveInteger, AddFloat, RemoveFloat, ArrayToStr, StrToArray. | ~350 |
| **Apus.Core** (extend) | PackBytes/PackWords, PointerInRange | ~30 |
| **Apus.Utils** (extend) | Str8/Str16 conversions, HasParam/GetParam, SafeStrItem, AddString/RemoveString/FindString array helpers | ~150 |
| **Apus.Types** | TTextEncoding enum (used by Apus.Translation) | ~20 |
| ~~**Apus.Threads**~~ | **DONE** — Extracted to new module. **BLOCKER #1 SOLVED**. | 667 |
| ~~**Apus.Utils**~~ | **DONE** — Created new module. Default place for functions without clear home. Current: ParseDate/ParseTime, SplitA, Chop. Planned: EncodeUTF8/DecodeUTF8, AddString/RemoveString/FindString, HasParam/GetParam, SimpleEncrypt/Compress, ExecuteAndCapture (from CrossPlatform), MyTickCount(?). | 280+ |

## DEPRECATED — candidates for removal or refactoring

| Module | Lines | Notes |
|--------|-------|-------|
| **Apus.Network** | 439 | Deprecated since 2023. Replaced by Apus.Socket. Used by Engine.Networking2 only. |
| **Apus.CrossPlatform** | 670 | Platform abstraction layer, but most functions are RTL wrappers. Extract useful parts (ExecuteAndCapture?) to Apus.Utils, remove from uses everywhere. Still uses Common (LogMessage, MyTickCount, threading). |

## Key blockers

1. ~~**Threading**~~: **DONE** — Apus.Threads created.
2. ~~**Logging**~~: **DONE** — Apus.Log created.
3. ~~**EventMan**~~: **DONE** — migrated to Core/Log/Threads/Strings, compiles clean.
4. ~~**Classes+Structs**~~: **DONE** — migrated 2026-02-17.
5. **Apus.Images / Apus.FastGFX** — gateway modules: ~15 other modules depend on them (Clipboard, Regions, GlyphCaches, UnicodeFont, FreeTypeFont, GfxFilters, GfxFormats, etc.). Migrating Images+FastGFX would unblock the most modules at once. **HIGH PRIORITY.**
6. **EncodeUTF8/DecodeUTF8** — used by 5+ modules (Translation, Publics, HtmlTree, Android). Already in Apus.Strings as `UTF8.Encode`/`UTF8.Decode` — need to add upgrade rule + verify API matches.
7. **MyTickCount** — still used in some modules. Replace with `GetTickCount64` directly (no wrapper needed).
8. **CrossPlatform** — deprecated, extract ExecuteAndCapture to Utils, then remove from uses everywhere.

## Discovered dependency chains (buildtest 2026-02-17)

These modules compile cleanly themselves but are blocked transitively:
- **Clipboard, Regions** → Apus.Images → Apus.FastGFX → Common
- **AnimatedValues** → Apus.Tweenings → Common
- **GlyphCaches, UnicodeFont, FreeTypeFont** → Apus.Images → Common
- **GfxFormats, GfxFilters** → Apus.Images + Apus.FastGFX → Common
- **Socket** → Common (direct, needs LogMessage + InitCritSect)
- **ProdCons** → Common (direct, needs Clamp + MyTickCount)

## Migration order (current priorities)

### Completed ✅
1. ✅ Create Apus.Log, Apus.Threads, Apus.Utils, Apus.Files, Apus.HashMaps
2. ✅ Migrate Apus.Classes, Apus.Structs (Foundation Level 1)
3. ✅ Migrate Apus.EventMan
4. ✅ Migrate Apus.Geom2D, Apus.Colors, Apus.VertexLayout (2026-02-17)
5. ✅ Migrate Apus.Clipboard, Apus.Regions (own code clean; blocked by Images transitively)
6. ✅ Extend Apus.Core: Wrap, FRound/PRound/SRound, Bits.GetBits/SetBits (2026-02-17)

### Next (HIGH — unblocks most modules)
7. **Migrate Apus.FastGFX** — light-to-medium, min2/max2/Clamp only. Unblocks Images and ~10 downstream modules.
8. **Migrate Apus.Images** — medium, min2/max2/Clamp + LogMessage. Depends on FastGFX being clean first.
9. **Migrate Apus.Tweenings** — trivial (Clamp only → Core). Unblocks AnimatedValues.
10. **Migrate Apus.Socket** — light (LogMessage + InitCritSect/Enter/LeaveCS → Log + Threads).

### Medium priority
11. Migrate Apus.ProdCons (Clamp + MyTickCount → Core + GetTickCount64)
12. Extract EncodeUTF8/DecodeUTF8 into Apus.Strings → unblocks Translation, HtmlTree, Publics
13. Migrate Apus.TCP, Apus.HttpRequests (LogMessage, MyTickCount, threading)
14. Migrate Apus.GfxFormats, Apus.GfxFilters (after Images is clean)
15. Migrate Apus.GlyphCaches, Apus.UnicodeFont, Apus.FreeTypeFont (after Images)
16. Extract CrossPlatform → Utils, then remove from all uses

### Low priority
17. Migrate trivial: Huffman, Profiling, GeoIP, StackTrace, MemoryLeakUtils
18. Migrate medium: TextUtils, Database, Translation, HtmlTree
19. Common becomes a thin re-export facade or is removed

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
