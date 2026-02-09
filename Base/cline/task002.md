# Task 002 — Move basic platform primitives from CrossPlatform to Core

## Objective

Move the most basic cross-platform utility functions from `Apus.CrossPlatform.pas` into `Apus.Core.pas`. These are low-level primitives that many modules need and should not require pulling in all of CrossPlatform.

## Background

`Apus.Core` currently has zero dependencies — only system units. `Apus.CrossPlatform` is a large module containing everything from `Sleep` to `LoadCursorFromFile`. We want to move the most fundamental functions into Core, keeping Core at Layer 0 (no Apus dependencies). System-unit dependencies (`Windows`, `SysUtils`, `BaseUnix`, etc.) in the `implementation` section are acceptable.

`Apus.Core` already has `SpinLock` which calls `Sleep(0)` — that's the immediate reason for this move. But the other functions listed below also belong in Core logically.

## Functions to move

Move the following from `Apus.CrossPlatform.pas` to `Apus.Core.pas`:

### 1. `Sleep(time:integer)`
- **Declaration**: `procedure Sleep(time:integer); inline;`
- **Windows impl**: `windows.Sleep(time);`
- **iOS impl**: `NSThread.sleepForTimeInterval(time/1000);`
- **Unix/Linux impl**: `SysUtils.Sleep(time);`

### 2. `GetTickCount:cardinal`
- **Declaration**: `function GetTickCount:cardinal; inline;`
- **Windows impl**: `result:=windows.GetTickCount;`
- **iOS impl**: Uses `NSDate` (see CrossPlatform lines 646-658)
- **Unix/Linux impl**: Uses `clock_gettime(CLOCK_MONOTONIC,...)` (see lines 698-704)

### 3. `GetCurrentThreadID:TThreadId`
- **Declaration**: `function GetCurrentThreadID:TThreadId; inline;`
- **Windows impl**: `result:=windows.GetCurrentThreadId;`
- **iOS/Unix impl**: `result:=system.getCurrentThreadID;`
- Note: `TThreadID` type — on Windows use `cardinal`, on Unix use `system.TThreadID`. Or use `{$IFDEF MSWINDOWS}` conditional for the type.

### 4. `IsDebuggerPresent:boolean`
- **Declaration**: `function IsDebuggerPresent:boolean; inline;`
- **Windows impl**: `result:=windows.IsDebuggerPresent;`
- **Unix impl**: Uses `ptrace(PTRACE_TRACEME,...)` — see CrossPlatform lines 366-387. Needs `const PTRACE_TRACEME=0; PTRACE_DETACH=17;` and external declaration of `ptrace` from libc.

### 5. `MemoryBarrier`
- **Declaration**: `procedure MemoryBarrier; inline;` — but only declare if not already declared: `{$IF not DECLARED(MemoryBarrier)}`
- **Impl**: `asm mfence end;`
- For ARM: needs appropriate barrier instruction or empty stub

### 6. `GetLastErrorCode:cardinal` and `GetLastErrorDesc:string`
- **GetLastErrorCode**: Windows: `GetLastError`, Unix: `fpGetErrno` — uses `{$IF declared(...)}` pattern (see CrossPlatform lines 264-273)
- **GetLastErrorDesc**: Uses `SysErrorMessage` if declared, else formats code (see lines 275-286). Note: uses `Format()` from SysUtils.

## Implementation plan

### In `Apus.Core.pas`:

1. **Add implementation `uses` section** (Core currently has none):
```pascal
implementation
uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
  {$IFDEF IOS}
  // iOS-specific units if needed
  {$ELSE}
  BaseUnix,
  {$IFDEF LINUX}Linux,{$ENDIF}
  {$ENDIF}
{$ENDIF}
  SysUtils;
```

2. **Add type declarations** in the interface section (before the functions):
```pascal
{$IFDEF MSWINDOWS}
  {$IF not Declared(TThreadID)}
  TThreadID = cardinal;
  {$IFEND}
{$ENDIF}
{$IFDEF UNIX}
  TThreadID = system.TThreadID;
{$ENDIF}
```

3. **Add function declarations** in the interface section, in a new section after SpinLock (add a comment header like `// Cross-platform primitives`).

4. **Add implementations** in the implementation section, using platform `{$IFDEF}` blocks.

5. **For Unix `IsDebuggerPresent`**: add the `ptrace` external declaration and constants in the implementation section, under `{$IFDEF UNIX}`.

6. **For iOS `GetTickCount`**: this needs `NSDate` — if including iOS support is too complex, leave a `// TODO: iOS GetTickCount` stub that returns 0 and add a note in the report. The priority is Windows and Linux.

### In `Apus.CrossPlatform.pas`:

1. **Add `Apus.Core` to the interface `uses`** clause (if not already there).
2. **Replace moved function declarations** with re-exports or simply remove them. The simplest approach: remove the declarations and implementations of the moved functions. Any module that used `Apus.CrossPlatform` for these functions will still work if it also uses `Apus.Core` (and most do).
3. **DO NOT remove** the declarations yet — instead, change each moved function into an inline wrapper that calls the Core version. This preserves backward compatibility:
```pascal
procedure Sleep(time:integer); inline;
// implementation:
procedure Sleep(time:integer);
begin
  Apus.Core.Sleep(time);
end;
```

Actually, **simpler approach**: just remove the moved functions from CrossPlatform entirely. Add a note in the report listing which functions were removed. Callers will need to add `Apus.Core` to their uses — but most already have it.

**Decision: remove the moved functions from CrossPlatform.** If any module fails to compile because it uses CrossPlatform for Sleep/GetTickCount/etc, that's expected — the fix is to add `Apus.Core` to its uses clause. Do NOT fix other modules — just note this in the report.

## Files you may modify

- `Base/Apus.Core.pas` — add platform primitives
- `Base/Apus.CrossPlatform.pas` — remove moved functions

## Files you must NOT modify

- Any other `.pas` files
- Test files (the existing `TestCore.dpr` tests don't test these functions)

## Verification

After making changes:
1. Run `test.bat Core` — existing Core tests must still pass
2. Check that the added functions have correct `{$IFDEF}` guards for all 3 platforms (Windows, Linux, iOS)
3. Run `git diff` to confirm only the 2 listed files were modified

## Report

Write your completion report to `Base/cline/result002.md`.
