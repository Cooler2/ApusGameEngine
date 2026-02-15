# Engine5 Refactoring — Function Rename Registry

This file tracks all functions extracted from `Apus.Common` into new modules.
Use it as the primary reference when updating old code.

## Apus.Core (low-level math, memory, bits, exceptions)

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `min2(a,b)` | `Min(a,b)` | overloads for integer/single/double |
| `max2(a,b)` | `Max(a,b)` | overloads for integer/single/double |
| `min2d(a,b)` | `Min(a,b:double)` | merged into Min overloads |
| `max2d(a,b)` | `Max(a,b:double)` | merged into Max overloads |
| `min2s(a,b)` | `Min(a,b:single)` | merged into Min overloads |
| `max2s(a,b)` | `Max(a,b:single)` | merged into Max overloads |
| `Clamp(v,min,max)` | `Clamp(v,min,max)` | same name, added single/double overloads |
| `Sat(v,0,255)` | `Sat(v)` | now clamps to 0..1 (single/double) |
| `Swap(a,b)` | `Swap(a,b)` | same name |
| `GetPow2(v)` | `GetPow2(v)` | same name |
| `Pow2(e)` | `Pow2(e)` | same name |
| `Log2i(v)` | `Log2i(v)` | same name |
| `HasFlag(v,flag)` | `Bits.HasAll(v,flag)` | |
| `SetFlag(v,flag)` | `Bits.SetFlag(v,flag)` | |
| `GetBit(data,idx)` | `Bits.Get(data,idx)` | |
| `SetBit(data,idx,val)` | `Bits.SetBit(data,idx,val)` | |
| `GetBits(data,idx,size)` | — | not yet moved |
| `SetBits(data,idx,size,val)` | — | not yet moved |
| `ZeroMem(data,size)` | `Mem.Clear(data,size)` | |
| `Toggle(b)` | `Toggle(b)` | same name |

### Stack trace support (new in engine5)

Namespace-style API for stack inspection:

| Method | Signature | Notes |
|---|---|---|
| `Stack.Caller` | `class function Caller: pointer` | Get immediate caller address using system API. For **fast caller** use intrinsics: `{$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF}` |
| `Stack.Trace` | `class function Trace(var frames: TCallStack; skip: integer = 0): integer` | Capture up to 4 call stack frames. Returns actual count. Used in exceptions/logging. |

Types:
- `TCallStack = array[0..3] of pointer` — fixed array for 4 stack frames

**Performance:** `Stack.Caller` is **~50-200 cycles** (system call). Intrinsic version is **~3-7 cycles** but requires inline usage.

Exception classes moved from `Apus.Classes` to `Apus.Core`:

| Old location (Classes) | New location (Core) | Notes |
|---|---|---|
| `TBaseException` | `TBaseException` | same name, base class with stack trace using `Stack.Trace` |
| `EWarning` | `EWarning` | same name |
| `EError` | `EError` | same name |
| `EFatalError` | `EFatalError` | same name |

**Note:** In engine5, `EBaseException` uses `Stack.Trace` to capture call stack on all platforms (previously only worked on x86 32-bit). Exception message format: `[addr1->addr2->addr3] Error message`

Exception helper functions moved from `Apus.Common` to `Apus.Core`:

| Old location (Common) | New location (Core) | Notes |
|---|---|---|
| `ExceptionMsg(e)` | `ExceptionMsg(e)` | Returns exception message with address and stack trace. For `EBaseException` uses already captured stack. |
| `NotImplemented(msg)` | `NotImplemented(msg)` | Raises `EError` with "Not implemented: msg". Inline. |
| `NotSupported(msg)` | `NotSupported(msg)` | Raises `EError` with "Not supported: msg". Inline. |

### Time scope (new in engine5)

High-precision time functions:

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `NowGMT` | `Time.UTC` | UTC time in TDateTime format (high-precision on Windows 8+) |
| — | `Time.Now` | Local time in TDateTime format (high-precision on Windows 8+) |
| `GetUTCTime` + formatting | `Time.Stamp` | Returns `HH:MM:SS.mmm` string for logs |
| `MyTickCount` | ~~removed~~ | Use standard `GetTickCount64` (available on all platforms) |

**Usage:**
```pascal
dt := Time.UTC;           // high-precision UTC
dt := Time.Now;           // high-precision local time
Log.Msg(Time.Stamp + ' Started');
```

## Apus.Conv (parsing and formatting)

| Old name (Common) | New name (Conv) | Notes |
|---|---|---|
| `ParseInt(st)` | `Conv.ToInt(st)` | |
| `ParseFloat(st)` | `Conv.ToFloat(st)` | |
| `ParseBool(st)` | `Conv.ToBool(st)` | |
| `HexToInt(st)` | `Conv.HexToInt(st)` | same name |
| `StrToIp(st)` | `Conv.ToIp(st)` | |
| `IpToStr(ip)` | `Conv.ToIp(ip)` | overload by argument type |
| `FormatHex(v,digits)` | `Conv.ToHex(v,digits)` | |
| `PtrToStr(p)` | `Conv.ToStr(p)` | |
| `BoolToAStr(b)` | `Conv.ToStr(b)` | |
| `FormatInt(v)` | `Conv.FormatInt(v)` | same name |
| `FormatMoney(v,digits)` | `Conv.FormatMoney(v,digits)` | same name |
| `SizeToStr(size)` | `Conv.FormatSize(size)` | |
| `FormatTime(timeMs)` | `Conv.TimeToStr(timeMs)` | |
| `EncodeHex(data,size)` | `Conv.EncodeHex(data,size)` | same name |
| `DecodeHex(hexStr)` | `Conv.DecodeHex(hexStr)` | same name |
| `HexDump(buf,size)` | `Conv.HexDump(buf,size)` | same name |
| `DecDump(buf,size)` | `Conv.DecDump(buf,size)` | same name |
| `EncodeB64(data,size)` | `Conv.ToBase64(data,size)` | |
| `DecodeB64(st,buf,size)` | `Conv.FromBase64(st,buf,size)` | |

## Apus.Strings (string helper methods)

String functions moved from free-standing functions to `String8Helper` record helper.
Call style changes from `Func(st, args)` to `st.Method(args)`.

| Old name (Common) | New name (Strings) | Notes |
|---|---|---|
| `PosFrom(substr,st)` | `st.IndexOf(substr)` | |
| `PosFrom(substr,st,minIdx)` | `st.IndexOf(substr,minIdx)` | |
| `LastPos(substr,st)` | `st.LastIndexOf(substr)` | |
| `Chop(st)` | `st.Trim` | |
| `SameText8(a,b)` | `a.EqualsText(b)` | |
| `UpperCase(st)` | `st.ToUpper` | |
| `LowerCase(st)` | `st.ToLower` | |
| `SplitA(delim,st)` | `st.Split(delim)` | **CAUTION**: Split treats each char as delimiter; SplitA uses whole string |
| `Join(arr,delim)` | `String8.Join(arr,delim)` | class function |
| `QuoteStr(st)` | `st.Quote` | |
| `UnQuoteStr(st)` | `st.Unquote` | |
| `URLEncodeUTF8(st)` | `st.UrlEncode` | |
| `ExtractStr(st,pre,suf)` | `st.Extract(pre,suf)` | |
| `ParseInt(st)` | `st.ToInt64` | also available via Conv.ToInt |
| `ParseFloat(st)` | `st.ToDouble` | also available via Conv.ToFloat |
| `ParseBool(st)` | `st.ToBoolean` | also available via Conv.ToBool |

## Apus.Files (file I/O and utilities)

File functions moved from free-standing functions to `Files` record with static class methods.
Call style changes from `Func(args)` to `Files.Method(args)`.

### File I/O

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `MyFileExists(fname)` | `Files.Exists(fname)` | |
| `GetFileSize(fname)` | `Files.GetFileInfo(fname,info)` | size via `info.size` field |
| `LoadFileAsBytes(fname)` | `Files.LoadAsBytes(fname)` | added `numBytes`, `startFrom` params |
| `LoadFileAsString(fname)` | `Files.LoadAsString(fname)` | added `numBytes`, `startFrom` params |
| `SaveFile(fname,buf,size)` | `Files.Save(fname,buf,size)` | also overloads for ByteArray, String8, TBuffer |
| `ReadFile(fname,buf,posit,size)` | `Files.ReadBlock(fname,buf,offset,size)` | |
| `WriteFile(fname,buf,posit,size)` | `Files.WriteBlock(fname,buf,offset,size)` | |

### File operations

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `CopyFile(sour,dest)` | `Files.CopyFile(sour,dest)` | same name |
| `MakeBakFile(fname)` | `Files.MakeBakFile(fname)` | same name |

### Directory operations (`Folder` record)

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `DirectoryExists(path)` | `Folder.Exists(path)` | new wrapper |
| `ForceDirectories(path)` | `Folder.Create(path)` | creates with parents |
| `ListFiles(path,mask,recursive)` | `Folder.ListFiles(path,mask,recursive)` | mask supports `;`-separated patterns |
| `FindFile(name,path)` | `Folder.Find(name,path)` | findDir=false by default |
| `FindDir(name,path)` | `Folder.Find(name,path,true)` | findDir=true |
| `CopyDir(sour,dest)` | `Folder.Copy(sour,dest)` | |
| `MoveDir(sour,dest)` | `Folder.Move(sour,dest)` | |
| `DeleteDir(path)` | `Folder.Delete(path)` | |

### Path utilities

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `SafeFileName(fname)` | `Files.SafeFileName(fname)` | same name |
| `FileName(fname)` | `Files.FileName(fname)` | same name |
| `AddFileNameRule(rule)` | `Files.AddFileNameRule(rule)` | same name |
| `IsPathRelative(fname)` | `Files.IsPathRelative(fname)` | same name |
| `WaitForFile(fname,delay,exists)` | `Files.WaitForFile(fname,delay,exists)` | same name |

### Not moved (stays in Common)

| Old name (Common) | Notes |
|---|---|
| `DumpDir(path)` | depends on ForceLogMessage (logging) |

## Apus.Log (unified logging interface)

Logging functions extracted from `Apus.Common` into new unified API.

### Basic logging

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `LogMessage(text)` | `Log.Msg(text)` or `Log.Info(text)` | default severity is Normal (was Normal in Common) |
| `LogMessage(text,group)` | `Log.Msg(text,group)` | category parameter |
| `LogMessage(text,params)` | `Log.Msg(text,params)` | Format overload |
| `ForceLogMessage(text)` | `Log.Force(text)` | forced (bypass cache, flush immediately) |
| `LogError(text)` | `Log.Error(text)` | error level + counter increment |
| `DebugMessage(text)` | `Log.Debug(text)` | debug level (lowest) |
| — | `Log.Warn(text)` | new: warning level |
| — | `Log.Fatal(text)` | new: fatal error level |

### Logger configuration

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `UseLogFile(name)` | `Logger.UseLogFile(name)` | same name, added `useThread` and `keepOpened` params |
| `SetLogMode(mode,groups)` | `Logger.SetVerbosity(minSeverity)` | simplified: only min severity filter |
| `FlushLog` | `Logger.Flush` | same functionality |
| `LogCacheMode(enable,enforce,runThread)` | `Logger.LogCacheMode(enable,bypassSeverity)` | redesigned params |
| `StopLogThread` | `Logger.StopLogThread` | same name |
| — | `Logger.SetCustomHandler(handler,disable)` | **NEW**: interceptor support for Apus.Logging refactor |
| — | `Logger.GetErrorCount` | **NEW**: returns error/fatal counter |

### Severity levels (TSeverity enum)

Replaces old TLogModes (lmSilent/lmForced/lmNormal/lmVerbose):

| Old (Common) | New (Log) | Value | Notes |
|---|---|---|---|
| — | `TSeverity.Debug` | 0 | auxiliary debug info |
| — | `TSeverity.Info` | 1 | minor event |
| LogMessage default | `TSeverity.Normal` | 2 | regular event |
| ForceLogMessage | `TSeverity.Forced` | 3 | important, flush buffer |
| — | `TSeverity.Warn` | 4 | warning |
| LogError | `TSeverity.Error` | 5 | error |
| — | `TSeverity.Fatal` | 6 | fatal error |

## Apus.Threads (thread synchronization and management)

Threading primitives and thread management utilities extracted from `Apus.Common`.

**Major changes in engine5:**
- **Type renamed**: TMyCriticalSection → TLock (modern, cross-platform)
- **Fields encapsulated**: TLock fields are now private
- **New scope**: `Thread` record for thread operations
- **New methods**: TLock.Init/Cleanup, IsLocked, GetOwner
- **New type**: TLightweightEvent (WaitOnAddress/futex-based)

### Critical section management

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `InitCritSect(cr,name,level)` | `InitCritSect(cr,name,level)` | same name |
| `DeleteCritSect(cr)` | `DeleteCritSect(cr)` | same name |
| `EnterCriticalSection(cr,caller)` | `EnterCriticalSection(cr,caller)` | same name |
| `LeaveCriticalSection(cr)` | `LeaveCriticalSection(cr)` | same name |
| `DumpCritSects` | `DumpCritSects` | same name |
| `CheckCritSections` | `CheckCritSections` | same name |
| `TMyCriticalSection.Enter` | `lock.Enter` | method restored, same syntax |
| `TMyCriticalSection.Leave` | `lock.Leave` | method restored, same syntax |

### Thread scope (modern API)

| Old function (Common) | New method (Threads) | Notes |
|---|---|---|
| `RegisterThread(name)` | `Thread.Register(name)` | static method, cleaner |
| `UnregisterThread` | `Thread.Unregister` | static method |
| `PingThread` | `Thread.Ping` | static method |
| `GetThreadName(threadID)` | `Thread.GetName(threadID)` | static method, 0=current |

**Note**: Old functions still available but deprecated for compatibility.

### TLock object methods (new in engine5)

| Method | Notes |
|---|---|
| `lock.Init(name, level)` | Initialize lock (replaces InitCritSect) |
| `lock.Cleanup` | Cleanup lock (replaces DeleteCritSect) |
| `lock.Enter` | Acquire lock |
| `lock.Leave` | Release lock |
| `lock.IsLocked` | Check if locked |
| `lock.GetOwner` | Get owning thread ID |

### Utilities

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `WaitFor(var p,maxTime)` | `WaitFor(var p,maxTime)` | same name |
| `debugCriticalSections` | `debugCriticalSections` | global var, same name |

### Types moved from Apus.Types

| Old type (Types/Common) | New type (Threads) | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | **RENAMED** and moved from Apus.Types to Apus.Threads |
| `PCriticalSection` | `PLock` | **RENAMED** pointer type |
| `TSRWLock` | `TSRWLock` | **MOVED** from Apus.Types to Apus.Threads (Windows Vista+) |

### New types in engine5

| Type | Description |
|---|---|
| `TLightweightEvent` | Lightweight event using WaitOnAddress (Win8+) or futex (Linux) |
| `TScopedLock` | RAII lock wrapper with automatic cleanup |
| `Thread` | Static record for thread operations |

### Backward compatibility aliases

| Old name | New name | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | type alias |
| `PCriticalSection` | `PLock` | type alias |
| `TCriticalSection` | `TLock` | type alias |
| `PCS` | `PLock` | type alias |
| `RegisterThread` | `Thread.Register` | old function deprecated |
| `UnregisterThread` | `Thread.Unregister` | old function deprecated |
| `PingThread` | `Thread.Ping` | old function deprecated |
| `GetThreadName` | `Thread.GetName` | old function deprecated |

## Not yet extracted (still only in Apus.Common)

| Function | Notes |
|---|---|
| `ParseDate(st)` | date/time parsing |
| `SplitA(divider,st)` | split by string (not char set) — Strings.Split has different semantics |
