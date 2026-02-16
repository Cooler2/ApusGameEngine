# Engine5 Refactoring — Module Status

Status of every module in `Base/Apus.*.pas`.
Categories: **NEW** | **CLEAN** | **MIGRATE** | **EXTRACT** | **REWORK** | **DEPRECATED**

## NEW — created in engine5 refactoring

| Module | Lines | Tests | Notes |
|--------|-------|-------|-------|
| **Apus.Core** | 1330 | TestCore | Min/Max, Clamp, Swap, Bits, Mem, GetPow2 |
| **Apus.Conv** | 667 | TestConv | Conv.ToInt/ToFloat/ToBool, Hex, Base64, Format |
| **Apus.Strings** | 1225 | TestStrings | String8Helper methods (IndexOf, Trim, Split, ToUpper...) |
| **Apus.Files** | 729 | TestFiles | Files.Exists/Load/Save, Folder.ListFiles/Find/Copy/Delete |
| **Apus.HashMaps** | 248 | TestHashMaps | Generic THashMap<T>, extracted from Structs |
| **Apus.Log** | 373 | — | Unified logging: Log.Msg/Debug/Info/Warn/Error/Fatal, Logger.UseLogFile/Flush. Replaces Common logging + base for Apus.Logging refactor. |
| **Apus.Threads** | 714 | — | Thread synchronization (TLock with Enter/Leave methods), thread management (RegisterThread/PingThread), utilities (WaitFor). Cross-platform (Windows/Linux). **Solves blocker #1**. |
| **Apus.Lib** | 58 | — | Re-export facade (type aliases for convenient `uses`) |

## CLEAN — old modules, no Common dependency, no changes needed

| Module | Lines | Notes |
|--------|-------|-------|
| **Apus.Types** | 760 | Foundation types, TBuffer, TMyCriticalSection. Level 0. |
| **Apus.CPU** | 157 | CPU detection, CPUID. Level 0. |
| **Apus.Crypto** | 430 | MD5, SHA, CRC32. Level 0. |
| **Apus.ADPCM** | 123 | Audio compression. Level 0. |
| **Apus.LongMath** | 1160 | Big integer math. Level 0. |
| **Apus.RegExpr** | 69 | Thin wrapper for RegExpr. Level 0. |
| **Apus.Geom3D** | 2759 | Matrices, quaternions, 3D math. Uses Types only. |
| **Apus.Structs** | 2612 | Collections, hash tables. Uses Core, Types, Classes. |
| **Apus.AnimatedValues** | 328 | Animated floats. Uses Tweenings only (but Tweenings uses Common!). |

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
| **Apus.HtmlTree** | 665 | String8, StringArr, PosFrom |

### Heavy (deep Common dependency)

| Module | Lines | What it uses from Common |
|--------|-------|--------------------------|
| **Apus.Classes** | 163 | InitCritSect, DeleteCritSect, Enter/LeaveCriticalSection. Circular concern: Classes is Level 1 but needs threading from Common. |
| **Apus.EventMan** | 634 | LogMessage, ForceLogMessage, InitCritSect, Enter/LeaveCS, MyTickCount. Core infrastructure module. |
| **Apus.CrossPlatform** | 670 | LogMessage, ForceLogMessage, MyTickCount, InitCritSect, Enter/LeaveCS. Platform abstraction layer. |
| **Apus.HttpRequests** | 1036 | LogMessage, ForceLogMessage, ExceptionMsg, UrlEncode, MyTickCount, InitCritSect, Enter/LeaveCS, Split |
| **Apus.ControlFiles** | 1827 | Split, SplitA, Chop, QuoteStr, UnQuoteStr, InitCritSect, Enter/LeaveCS. Heavy string + threading. |
| **Apus.SCGI** | 1383 | Needs audit — large module |
| **Apus.Android** | 465 | ForceLogMessage, EncodeUTF8, AddString, SaveFile. Platform-specific. |
| **Apus.Publics** | 1184 | EncodeUTF8, DecodeUTF8, ParseInt, SplitA. Public variable system. |

## EXTRACT — code still trapped inside Common that belongs in these modules

| Target module | What to extract from Common | Est. lines |
|---------------|---------------------------|------------|
| **Apus.Log.Memory** (TBD) | Refactor old Apus.Logging into memory log handler that uses new Apus.Log via SetCustomHandler. Extract daily rotation, FetchLog, flood protection, SaveMessages functionality. | ~300 |
| **Apus.Core** (extend) | Math: FRound, PRound, SRound, FastFloor, Wrap, Ratio, Pike, FastInvSqrt. Bits: GetBits, SetBits. Pack: PackBytes, PackWords, ExtractByte, ExtractWord. Random: TRandom, PseudoRand, RandomInt, RandomStr. Checksum: CalcCheckSum, CheckSum64, FillRandom. | ~400 |
| **Apus.Conv** (extend) | Date/Time: ParseDate, ParseTime, HowLong, NowGMT, GetUTCTime, MyTickCount, TimeStamp. Encoding: ConvertToWindows/FromWindows, Win1251↔UTF8, BinToStr/StrToBin. | ~300 |
| **Apus.Strings** (extend) | UTF: EncodeUTF8, DecodeUTF8, Str8, Str16, UStr, WStr, IsUTF8, DecodeUTF8A. String ops still in Common: Split (with quotes), Combine, SplitA, SameChar8/16, SameText16, SafeStrItem, DumpStr. | ~350 |
| **Apus.Structs** (extend) | Sorting: SortObjects, SortRecordsByDouble/Float/Int, SortStrings, IndexRecordsByFloat. Array helpers: AddString, RemoveString, FindString, AddInteger, RemoveInteger, AddFloat, RemoveFloat, ArrayToStr, StrToArray. | ~350 |
| ~~**Apus.Threading**~~ | **DONE** — extracted to new module. Threading: InitCritSect, DeleteCritSect, Enter/LeaveCriticalSection, DumpCritSects, RegisterThread, UnregisterThread, PingThread, CheckCritSections, WaitFor. **BLOCKER #1 SOLVED**. | 667 |
| **??? (new or Common)** | Misc that doesn't fit elsewhere: SimpleEncrypt/2, SimpleCompress/Decompress, PackRLE/UnpackRLE, CreateBackupPatch/ApplyBackupPatch, FillSingleNaN/FillDoubleNaN, Spline functions, ShowMessage/AskYesNo/ErrorMessage, ExceptionMsg, GetCallStack, GetCaller, HasParam/GetParam, GetMemoryState, TestSystemPerformance, performance measurement (StartMeasure/EndMeasure/RunTimer), VarToStr, ParseIntList, etc. | ~500 |

## DEPRECATED — candidates for removal

| Module | Lines | Notes |
|--------|-------|-------|
| **Apus.Network** | 439 | Deprecated since 2023. Replaced by Apus.Socket. Used by Engine.Networking2 only. |

## Key blockers

1. ~~**Threading**~~: **DONE** — Apus.Threads created. 12+ Base modules can now migrate from Common to Threads.
2. ~~**Logging**~~: **DONE** — Apus.Log created with unified API. Old Common logging code can now be deprecated. Apus.Logging refactor into interceptor is next.
3. **MyTickCount** is used by 8+ modules for timing. Needs a home (Conv? Core? CrossPlatform?).
4. **EncodeUTF8/DecodeUTF8** used by 5+ modules. Natural fit for Strings but adds bulk.

## Migration order (suggested)

1. **DONE** — Create Apus.Log with unified logging API (extracted from Common)
2. **DONE** — Extract Threading from Common → Apus.Threading → unblocks Classes, EventMan, CrossPlatform, ControlFiles, HttpRequests, Socket
3. Refactor Apus.Logging into interceptor (Apus.Log.Memory?) using new Log API
4. Migrate modules to use new Log API (~20 modules call old LogMessage/ForceLogMessage)
5. Extract remaining Math/Bits/Pack into Core → unblocks Colors, Geom2D, FastGFX, Images
6. Extract UTF/string ops into Strings → unblocks Translation, Publics, HtmlTree
7. Extract Date/Time + encoding into Conv → unblocks Database, ProdCons
8. Extract Sorting/Array helpers into Structs → unblocks TextUtils, ControlFiles
9. Migrate all remaining modules (trivial + light group)
10. Common becomes a thin re-export facade (like Lib) or is removed

## TODO — important tasks

* **TScopedLock in FPC**: Investigate if RAII (Initialize/Finalize operators) can work in FPC. If not possible, remove TScopedLock entirely — engine should only include features that work with both compilers (Delphi + FPC).

## Would be nice to do (but not required)

* Add EBaseException stack trace in x64 mode (currently works for x86 only)
* Optimize Mem.FillW/FillQ/FillF with SSE (currently simple loops, only FillD is SSE-optimized)
* Optimize Mem.Copy with SSE for large blocks (currently uses RTL move())
* Optimize Mem.IsZero with SSE (currently manual loop with NativeUInt alignment)
* Audit Mem.Shift for overlapping regions (currently uses move() which may not handle all cases)
