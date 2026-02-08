# Cline Guide — Apus Engine Base Library

You are working on the **Apus Game Engine** Base library — a set of platform-independent Pascal/Delphi utility modules in `Base/Apus.*.pas`.

## Your Role

You execute specific, well-defined tasks delegated to you. You do NOT make architectural decisions — those are made by the lead developer. Follow task instructions precisely.

## Project Structure

```
Base/
  Apus.*.pas          — library source modules
  tests/
    Test.inc           — shared test framework (include file)
    Test*.dpr           — test programs
    test.bat            — compile & run script (FPC 3.2.2)
    test_results_64.txt — 64-bit test output
    test_results_32.txt — 32-bit test output
  cline/
    guide.md            — this file
    task*.md             — task descriptions
    result*.md           — task completion reports
```

## Code Style (MANDATORY)

- **Indent**: 2 spaces, no tabs
- **Operators**: no spaces around `:=`, `+`, `-`, etc. → `a:=b+c`
- **`begin`**: same line after `then/do/else`, new line for procedures/functions
- **Naming**: classes `TName`, interfaces `IName`, variables `camelCase`
- **Comments**: English only. Short end-of-line comments start lowercase: `a:=1; // initialize`
- **No unit finalization** unless explicitly requested
- **Preserve UTF-8 BOM** in existing files
- **No extra whitespace** at end of lines

Example:
```pascal
procedure DoSomething(value:integer);
var
  result:integer;
begin
  result:=value*2;
  if result>100 then begin
    WriteLn('big');
  end else
    WriteLn('small');
end;
```

## Compiler Compatibility

Code must compile with both **Delphi 12+** and **FPC 3.2.2+**.

Key FPC quirks:
- `single(10)` is a reinterpret cast — use `single(10.0)` for type conversion
- `$FF00000000000000` is int64 (signed) — use `uint64($FF00000000000000)` for unsigned
- Use `UIntPtr` for pointer-to-integer conversion

## String Types

- `String8` = UTF-8 (1-based indexing) — primary string type
- `String32` = UCS4String (0-based indexing, array type) — secondary
- Built-in `string` — only when String8 doesn't fit (RTL interop)

## Writing Tests

Tests follow a specific pattern. Use existing tests as reference (e.g. `TestConv.dpr`).

### Test file template:
```pascal
{$APPTYPE CONSOLE}
program TestXxx;
uses
  SysUtils,
  Apus.ModuleName;

{$INCLUDE Test.inc}

procedure TestSomething;
begin
  StartTest('Module.Something');
  Check(condition, 'description of what failed');
  Check(condition2, 'another check');
  EndTest;
end;

begin
  try
    TestSomething;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Exception: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
```

### Test conventions:
- `StartTest('GroupName')` / `EndTest` wrap each test group
- `Check(condition, 'message')` for individual assertions
- Output format: `Testing GroupName... OK` or `Testing GroupName... FAIL`
- Use `ExitCode:=1` for failures, never `halt(1)`
- End with `if IsDebuggerPresent then readln;`
- `Test.inc` provides: `StartTest`, `EndTest`, `Check`, `IsDebuggerPresent`
- Test.inc also defines `DELPHI` and `CPU64` when appropriate

### Compilation:
```
test.bat TestXxx          — compiles and runs TestXxx.dpr
test.bat Xxx              — also works (auto-adds "Test" prefix)
```
Results go to `test_results_64.txt` and `test_results_32.txt`.

## Restrictions

- **DO NOT** change public API (type declarations, function signatures in interface sections) unless the task explicitly says to
- **DO NOT** delete existing code unless the task explicitly says to
- **DO NOT** add unit finalization sections
- **DO NOT** add unnecessary dependencies between modules
- **DO NOT** add features or "improvements" beyond what the task asks for
- **DO NOT** modify files not mentioned in the task
- **DO NOT** use `halt()` in tests — use `ExitCode:=1`

## Completing a Task

When you finish a task, create a report file `Base/cline/resultNNN.md` (where NNN matches the task number) with this structure:

```markdown
# Result: Task NNN — <brief title>

## Status: DONE / PARTIAL / BLOCKED

## What was done
- bullet list of changes made

## Files modified
- `path/to/file.pas` — what was changed

## Files created
- `path/to/new_file.pas` — what it contains

## Test results
- Compilation: OK/FAIL
- Tests passed: X of Y

## Notes
- any issues encountered, decisions made, or questions for review
```

If you cannot complete the task, set status to BLOCKED and explain why in Notes.

## Reference

- Main project docs: `CLAUDE.md` in repo root
- Module dependency hierarchy is documented in `CLAUDE.md`
- Test examples: `Base/tests/TestConv.dpr`, `Base/tests/TestCore.dpr`
