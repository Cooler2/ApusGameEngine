# Apus.Common Refactoring Plan

This file lists all functions/types from Apus.Common interface, categorized with proposed destinations.

Legend:
- **Core** = Apus.Core (Layer 0, no dependencies)
- **Conv** = new Apus.Conv (conversion functions)
- **Strings** = new Apus.Strings (string manipulation)
- **Keep** = stays in Apus.Common
- **?** = needs discussion

---

## 1. Constants (lines 30-39)

| Item | Current | Proposed |
|------|---------|----------|
| `PathSeparator` | Common | CrossPlatform |
| `MAX_FLOAT`, `MIN_FLOAT` | Common | Core |
| `MAX_INT64`, `MAX_UINT64` | Common | Core |

---

## 2. Type Aliases (lines 41-93)

Re-exports from Apus.Types, Apus.Classes. **Keep** for compatibility.

---

## 3. TSplines record (lines 95-104)

| Item | Proposed |
|------|----------|
| `TSplines` | Keep or Apus.Splines |
| `splines` global var | Keep or Apus.Splines |

---

## 4. TSortableObject (lines 106-113)

| Item | Proposed |
|------|----------|
| `TSortableObject` class | Apus.Classes? or Keep |

---

## 5. TRandom record (lines 116-126)

| Item | Proposed |
|------|----------|
| `TRandom` | Core? or Keep |

Has methods: Init, Int, Float, Sum, Normal, Exp

---

## 6. Logging types & vars (lines 128-145)

| Item | Proposed |
|------|----------|
| `TLogModes` | Apus.Logging |
| `logGroups`, `logStartDate`, etc | Apus.Logging |

---

## 7. Exception & Debug (lines 147-157)

| Item | Proposed |
|------|----------|
| `ExceptionMsg` | Keep (uses Exception) |
| `NotImplemented`, `NotSupported` | Keep |
| `GetCallStack`, `GetCaller` | Apus.StackTrace |
| `IsDebuggerPresent` | CrossPlatform (already there) |

---

## 8. System (lines 159-167)

| Item | Proposed |
|------|----------|
| `GetSystemErrorCode`, `GetSystemError` | CrossPlatform |
| `HasParam`, `GetParam` | CrossPlatform or Keep |

---

## 9. MessageBox (lines 169-173)

| Item | Proposed |
|------|----------|
| `ShowMessage`, `AskYesNo`, `ErrorMessage` | CrossPlatform |

---

## 10. Log functions (lines 175-189)

| Item | Proposed |
|------|----------|
| `UseLogFile`, `SetLogMode` | Apus.Logging |
| `LogMessage`, `LogError`, `ForceLogMessage` | Apus.Logging |
| `LogPhrase`, `DebugMessage` | Apus.Logging |
| `LogCacheMode`, `FlushLog`, `StopLogThread` | Apus.Logging |
| `SystemLogMessage` | Apus.Logging |

---

## 11. File System (lines 191-225)

| Item | Proposed |
|------|----------|
| `FindFile`, `FindDir` | Apus.Files |
| `CopyFile`, `CopyDir`, `MoveDir`, `DeleteDir` | Apus.Files |
| `DumpDir`, `ListFiles` | Apus.Files |
| `SafeFileName`, `FileName`, `AddFileNameRule` | Apus.Files |
| `GetFileSize`, `WaitForFile`, `MyFileExists` | Apus.Files |
| `MakeBakFile`, `IsPathRelative` | Apus.Files |
| `LoadFileAsString`, `LoadFileAsBytes` | Apus.Files |
| `SaveFile`, `ReadFile`, `WriteFile` | Apus.Files |

---

## 12. Performance Measurement (lines 227-248)

| Item | Proposed |
|------|----------|
| `StartMeasure`, `EndMeasure`, `EndMeasure2` | Apus.Profiling |
| `GetTaskPerformance`, `RunTimer`, `GetTimer` | Apus.Profiling |
| `GetMemoryState`, `GetMemoryAllocated` | Apus.Profiling |

---

## 13. Misc (line 251)

| Item | Proposed |
|------|----------|
| `GetEnumNameSafe` | Keep |

---

## 14. Array Functions (lines 253-284)

| Item | Proposed |
|------|----------|
| `ShiftArray` | Core.Mem? |
| `AddString`, `RemoveString`, `FindString` | Strings |
| `FindInteger`, `AddInteger`, `RemoveInteger` | Keep or Arrays |
| `AddFloat`, `RemoveFloat` | Keep or Arrays |
| `ArrayToStr`, `StrToArray` | Conv |

---

## 15. String Functions (lines 286-401)

| Item | Proposed |
|------|----------|
| `Split`, `SplitA`, `SplitW` | Strings |
| `Combine`, `Join` | Strings |
| `HasPrefix`, `HasSuffix` | Strings |
| `PosFrom`, `PosFromTo`, `LastPos` | Strings |
| `ExtractStr` | Strings |
| `UpperCase8`, `LowerCase8` | Strings |
| `SameChar8`, `SameChar16`, `SameText8`, `SameText16` | Strings |
| `SafeStrItem` | Strings |
| `QuoteStr`, `UnQuoteStr` | Strings |
| `Unescape`, `Escape` | Strings |
| `Chop` | Strings |
| `LastChar`, `CharAt`, `WCharAt` | Strings |
| `HTMLString` | Strings |
| `UrlEncode`, `UrlDecode`, `URLEncodeUTF8` | Strings |
| `EncodeB64`, `DecodeB64` | Conv |
| `PrintableStr` | Strings |
| `EncodeHex`, `DecodeHex` | Conv |
| `DumpStr` | Conv or Debug |

---

## 16. Memory (lines 403-415)

| Item | Proposed |
|------|----------|
| `ZeroMem`, `IsZeroMem` | Core.Mem (already there) |
| `FillDword`, `FillSingle` | Core.Mem |
| `FillSingleNaN`, `FillDoubleNaN` | Core.Mem |
| `IsNaN` | Core (already there) |
| `PointerInRange` | Core (PtrInside already there) |

---

## 17. Encryption/Compression (lines 417-435)

| Item | Proposed |
|------|----------|
| `SimpleEncrypt`, `SimpleEncrypt2` | Keep or Apus.Crypto |
| `SimpleCompress`, `SimpleDecompress` | Keep |
| `PackRLE`, `UnpackRLE`, `CheckRLEHeader` | Keep |
| `CreateBackupPatch`, `ApplyBackupPatch` | Keep |

---

## 18. Date/Time Parsing (lines 437-443)

| Item | Proposed |
|------|----------|
| `ParseDate`, `GetDateFromStr` | Conv |
| `ParseTime` | Conv |
| `HowLong` | Conv or Keep |

---

## 19. UTF8/Unicode (lines 445-473)

| Item | Proposed |
|------|----------|
| `IsUTF8` | Strings |
| `EncodeUTF8`, `DecodeUTF8` | Strings |
| `UStr`, `WStr` | Strings |
| `Str16`, `Str8` | Strings |
| `DecodeUTF8A` | Strings |
| `UTF8toWin1251`, `Win1251toUTF8` | Strings |
| `UpperCaseUtf8`, `LowerCaseUtf8` | Strings |
| `UnicodeTo`, `UnicodeFrom` | Strings |

---

## 20. Math Functions (lines 476-516)

| Item | Proposed |
|------|----------|
| `Clamp` (int, double) | Core (already there) |
| `Sat`, `SatD` (deprecated) | Remove |
| `LinearMix` | Core |
| `FRound`, `PRound`, `SRound`, `FastFloor` | Core |
| `GetPow2`, `Pow2`, `Log2i` | Core (already there) |
| `Ratio`, `FastInvSqrt` | Core |
| `Wrap` | Core |
| `Pike`, `PikeS`, `PikeD` | Keep or Splines |

---

## 21. Bit Manipulation (lines 518-554)

| Item | Proposed |
|------|----------|
| `HasFlag`, `NoFlag`, `SetFlag`, `ClearFlag` | Core.Bits (already there) |
| `Toggle` | Core (already there) |
| `GetBit`, `SetBit`, `ClearBit` | Core.Bits (already there) |
| `GetBits`, `SetBits` | Core.Bits |
| `PackBytes`, `PackWords` | Core.Bits |
| `ExtractByte`, `ExtractWord` | Core.Bits |

---

## 22. Spline Functions (lines 566-592)

| Item | Proposed |
|------|----------|
| `SatSpline`, `SatSpline3` | Keep or Splines |
| `Spline` | Keep or Splines |
| `Spline0..Spline4a` | Keep or Splines |

---

## 23. Min/Max (lines 594-602)

| Item | Proposed |
|------|----------|
| `Min2`, `Max2`, `Min2d`, `Max2d`, `Min2s`, `Max2s` | Core (already there as Min/Max) |
| `Min3d`, `Max3d` | Core |

---

## 24. Swap (lines 604-615)

| Item | Proposed |
|------|----------|
| All `Swap` overloads | Core (already there) |

---

## 25. Random (lines 617-622)

| Item | Proposed |
|------|----------|
| `PseudoRand` | Core |
| `RandomInt`, `RandomStr` | Keep (uses System.Random) |

---

## 26. Binary/String (lines 624-627)

| Item | Proposed |
|------|----------|
| `BinToStr`, `StrToBin` | Conv |

---

## 27. Charset Conversion (lines 629-636)

| Item | Proposed |
|------|----------|
| `ConvertToWindows`, `ConvertFromWindows` | Strings or Conv |
| `ConvertWindowsToUnicode`, `ConvertUnicodeToWindows` | Strings or Conv |

---

## 28. Type Conversion (lines 638-666)

| Item | Proposed |
|------|----------|
| `HexToInt` | **Conv** |
| `FormatHex` | **Conv** |
| `SizeToStr` | **Conv** |
| `FormatTime` | **Conv** |
| `FormatInt` | **Conv** |
| `FormatMoney` | **Conv** |
| `PtrToStr` | **Conv** |
| `IpToStr`, `StrToIp` | **Conv** |
| `VarToStr`, `VarToAStr` | **Conv** |
| `ParseInt` | **Conv** |
| `ParseFloat` | **Conv** |
| `ParseIntList` | **Conv** |
| `ParseBool` | **Conv** |
| `BoolToAStr` | **Conv** |
| `ListIntegers` | **Conv** |
| `HasValue` | Keep |

---

## 29. Sorting (lines 669-681)

| Item | Proposed |
|------|----------|
| `SortObjects` | Keep or Apus.Sort |
| `SortRecordsByDouble/Float/Int` | Keep or Apus.Sort |
| `IndexRecordsByFloat` | Keep or Apus.Sort |
| `SortStrings` | Strings or Sort |

---

## 30. Dump (lines 683-688)

| Item | Proposed |
|------|----------|
| `HexDump`, `DecDump` | Conv |

---

## 31. System Performance (line 690)

| Item | Proposed |
|------|----------|
| `TestSystemPerformance` | Keep or Profiling |

---

## 32. Checksum/Hash (lines 692-703)

| Item | Proposed |
|------|----------|
| `CalcCheckSum`, `CheckSum64` | Keep or Apus.Hash |
| `FillRandom` | Keep |
| `StrHash`, `FastHash` | Keep or Apus.Hash |

---

## 33. DateTime (lines 705-710)

| Item | Proposed |
|------|----------|
| `NowGMT`, `GetUTCTime` | CrossPlatform |
| `MyTickCount`, `TimeStamp` | CrossPlatform |

---

## 34. Threading (lines 712-736)

| Item | Proposed |
|------|----------|
| `SpinLock` | Apus.System |
| `InitCritSect`, `DeleteCritSect` | Apus.System |
| `EnterCriticalSection`, `LeaveCriticalSection` | Apus.System |
| `DumpCritSects` | Apus.System |
| `RegisterThread`, `UnregisterThread`, `PingThread` | Apus.System |
| `GetThreadName`, `DumpNamedThreads` | Apus.System |
| `CheckCritSections` | Apus.System |
| `WaitFor` | Apus.System |
| `DisableDEP` | CrossPlatform |

---

## Priority Order for Refactoring

1. **Conv** - conversion functions (no dependencies, clean extraction)
2. **Core additions** - FRound, LinearMix, PseudoRand, etc.
3. **Strings** - string manipulation (large, but self-contained)
4. **Files** - file operations
5. **Logging** - already partially exists
6. **System** - threading primitives

---

## Notes

- Keep type aliases in Common for backward compatibility
- Deprecate old function names (Min2 → Min, Sat → Clamp, etc.)
- Some functions have overlapping implementations with Core - need to consolidate
