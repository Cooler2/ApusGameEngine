# Foundation API Quick Reference (Apus Base)

Date: 2026-02-19
Scope: `Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Types`, `Apus.Threads`

## Fast module map

- `Apus.Core`: base types + low-level primitives (`Min/Max/Clamp`, `Mem`, `Bits`, `CoreTime`, atomics, spinlock, exceptions).
- `Apus.Strings`: helpers for `String8`/`String32`, UTF-8 tools, string conversions/hashes.
- `Apus.Conv`: parse/format primitive values (`ToInt/ToFloat/ToBool/ToStr`, hex/base64/IP, dumps).
- `Apus.Types`: lightweight data structures (`TArray<T>`, name-value pairs, read/write buffers, ranges).
- `Apus.Threads`: locks/events + thread lifecycle/registry (`IThread`, `Thread.Start`, diagnostics).

## Where to look first

- Numeric/memory/bit/time primitive: `Apus.Core`.
- String algorithms and UTF handling: `Apus.Strings`.
- String<->number formatting/parsing: `Apus.Conv`.
- Binary packet read/write and small containers: `Apus.Types`.
- Synchronization and worker threads: `Apus.Threads`.

## Apus.Core (key API)

- Types: `String8/String16/String32`, `ByteArray`, `TCPUFeatures`, `half`, `m128`.
- Global state: `cpuFeatures`, `globalSpinLock`.
- Math helpers: `Min/Max`, `Clamp`, `Sat`, `Lerp/LerpC`, `Wrap`, `FRound/PRound/SRound`.
- Utility: `Swap`, `GetPow2`, `Pow2`, `Log2i`, `AlignUp/Down`, `IsAligned`, `Toggle`, `IsNaN`, `HasValue`, `PtrInside`.
- Locks/barriers: `SpinLock/SpinUnlock`, `MemoryBarrier`.
- Time: `StartTimer/TimerSec`, `CoreTime.Now/UTC/Stamp/Ticks/Sleep`.
- Memory/bit scopes: `Mem.*`, `Bits.*`.
- Concurrency primitives: `Atomic.*`.
- Error/diagnostics: `EBaseException` + derived classes, `ExceptionMsg`, `Stack.Trace`, `GetLastError*`.

## Apus.Strings (key API)

- `String8Helper`: search/contains/start/end, trim/pad, insert/remove/replace, split/join, quote/escape/url/html helpers.
- Conversion helpers: `ToInteger/ToInt64/ToDouble/ToBoolean` (internally use `Conv`).
- `String32Helper`: analog API for `String32` plus implicit conversions (`Delphi`).
- `Strings8Helper` / `Strings32Helper`: dynamic array helpers (`Add/Insert/Delete/Join/Sort`).
- `UTF8` scope: `IsValid`, `CharCount`, `Decode/Encode`, `ToWide/FromWide`, case conversion, `Format`.
- Free functions: `Str8/Str16/Str32`, `FastHash`, `StrHash`.

## Apus.Conv (key API)

- Parse: `Conv.ToInt`, `Conv.HexToInt`, `Conv.ToFloat`, `Conv.ToBool`, `Conv.ToIp`.
- Format: `Conv.ToHex`, `Conv.ToStr(...)` overloads, `FormatInt`, `FormatMoney`, `FormatSize`, `TimeToStr`, `FormatIp`.
- Binary encoding: `EncodeHex/DecodeHex`, `HexDump/DecDump`.
- Base64-like helpers: `ToBase64/FromBase64` (non-standard alphabet/format).

## Apus.Types (key API)

- Ranges: `TIntRange`, `TFloatRange`.
- Generic container: `TArray<T>` with `Add/Insert/Remove/Find/Pop`.
- Name-value records: `TNameValue`, `TNameValueList` (`Init`, `Find`, indexed `Item[name]`).
- Binary read buffer: `TBuffer` (`Read*`, `ReadFlex`, `Slice`, `Seek`, `Skip`).
- Binary write buffer: `TWriteBuffer` (`Write*`, `WriteFlex`, `WriteStr`, `AsBuffer`).

## Apus.Threads (key API)

- Locking: `TLock` (`Init/Cleanup/Enter/Leave`) with deadlock-level checks.
- `TSRWLock` (when available).
- `TLightweightEvent` (`SetEvent/ResetEvent/WaitFor`).
- Thread runtime: `TThreadContext` (inside worker: status/progress/result/error updates).
- `IThread` (outside worker: `Wait/Terminate/Kill/Pause`, status polling).
- `Thread` static scope: `Start`, `Register/Unregister`, `Ping`, `GetName`, diagnostics (`DumpRegistered`, `DumpLocks`, `CheckTimeouts`), bulk stop (`TerminateAll`).
- Globals: `debugCriticalSections`, threadvar `CurrentThread`.

## Cross-module conventions and gotchas

- String policy: `String8` is UTF-8 default low-level string type across modules.
- Conversion split: keep parsing/formatting in `Conv`; avoid duplicating such logic in unrelated modules.
- Buffer ownership: `TBuffer` does not own memory; caller must guarantee lifetime.
- Thread status flow: worker should publish errors via `CurrentThread.SetError(...)` instead of raw exceptions when recoverable.
- Base64 note: `Conv.ToBase64/FromBase64` is not RFC 4648 compatible by design.

## Practical usage patterns

- Parse config value: `v := Conv.ToInt(item.Value, 0);`
- Serialize packet: `wb.WriteUInt(...); wb.WriteStr(...); buf := wb.AsBuffer;`
- Safe lock scope (Delphi): `var guard := TScopedLock.Create(@lock);`
- Thread start + poll: `th := Thread.Start('worker%', @Proc, param); ... if th.Status=TThreadStatus.Finished then ...`
