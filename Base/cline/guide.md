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

### Compiling and running tests:

1. Open a terminal in `Base/tests/` directory
2. Run: `test.bat <name>` — where `<name>` is the test name without "Test" prefix. Examples:
   ```
   test.bat Strings        — compiles and runs TestStrings.dpr
   test.bat Conv           — compiles and runs TestConv.dpr
   test.bat Core           — compiles and runs TestCore.dpr
   ```
3. The batch file compiles with FPC for both 64-bit and 32-bit, then runs the resulting executables.
4. Results are written to files in the same `Base/tests/` directory:
   - `test_results_64.txt` — 64-bit compilation log and test output
   - `test_results_32.txt` — 32-bit compilation log and test output
5. Old result files are deleted automatically before each run.
6. After running, **read both result files** to check for:
   - `COMPILE FAILED` — means the code didn't compile
   - `FAIL` lines — individual test failures with descriptions
   - `All N tests passed!` — success
   - `X of Y tests FAILED` — summary of failures

## Refactoring Context

We are refactoring the Base library. The old monolithic module `Apus.Common.pas` is being split into smaller, focused modules:

| New module | Purpose | Status |
|---|---|---|
| `Apus.Core` | Foundational types, Min/Max/Clamp/Swap, memory, bit ops | Done |
| `Apus.Conv` | Type conversions (int/float/hex/base64/IP) | Done |
| `Apus.Strings` | String8/String32 type helpers, UTF8 utilities | In progress |

**Critical rule:** `Apus.Common.pas` is the **old donor module**. Code is being extracted FROM it into new modules. Do NOT fix, modify, or "improve" `Apus.Common.pas` — it is being phased out. If you see compilation errors related to `Apus.Common`, that's expected — the new modules (`Apus.Core`, `Apus.Conv`, `Apus.Strings`) replace its functionality.

**Module dependency chain** (new modules):
```
Apus.Core       — no Apus dependencies (Level 0)
Apus.Conv       — uses Apus.Core
Apus.Strings    — uses Apus.Types (which uses Apus.Core)
```

Tests for new modules should only depend on the new modules, NOT on `Apus.Common`.

## Task Scope Principles

Tasks are designed to be **concrete and limited**. You should NOT need to make architectural decisions or chase dependency chains across multiple modules.

**Good tasks** (you should be able to complete):
- "Write function X with this signature and behavior" — one file, clear spec
- "Move these 3 functions from file A to file B" — two files, mechanical work
- "Write tests for module X following TestConv as example" — one new file
- "Fix tests X, Y, Z — the expected values should be ... because ..." — specific fixes with reasoning provided

**Research tasks** (investigate and report, do NOT modify code):
- "Find out why test X fails" — read code, trace logic, write findings to report
- "What modules depend on Apus.Common?" — search and list results
- These tasks produce a report only, no code changes

**Bad tasks** (should be escalated back):
- "Fix compilation" — too open-ended, may require architectural decisions
- "Make it work" — no clear scope
- Any task where the fix path is unclear and might touch many files

If a task feels open-ended or you find yourself modifying files not listed in the task, **STOP and write a report** explaining what you found. Do not try to fix things outside the task scope. The lead developer will adjust the task or handle it directly.

## Restrictions

**FILE SCOPE IS STRICT.** Each task lists "Files you may modify". You MUST NOT modify any other files. If you believe a fix requires changing an unlisted file, STOP and report this in your result file — do not make the change.

- **DO NOT** modify files not listed in the task's "Files you may modify" section
- **DO NOT** change public API (type declarations, function signatures in interface sections) unless the task explicitly says to
- **DO NOT** add type aliases, re-exports, or `uses` clauses to fix compilation errors in other modules — that's an architectural decision
- **DO NOT** modify `Apus.Common.pas`, `Apus.Types.pas`, `Apus.Classes.pas`, or any module not listed in the task
- **DO NOT** add unnecessary dependencies between modules (adding a unit to a `uses` clause changes the dependency graph)
- **DO NOT** delete existing code unless the task explicitly says to
- **DO NOT** add unit finalization sections
- **DO NOT** add features or "improvements" beyond what the task asks for
- **DO NOT** use `halt()` in tests — use `ExitCode:=1`

## Completing a Task

**MANDATORY:** When you finish a task, you MUST create a report file `Base/cline/resultNNN.md` (where NNN matches the task number). The task is NOT complete until this file exists.

Use this exact structure:

```markdown
# Result: Task NNN — <brief title>

## Status: DONE / PARTIAL / BLOCKED

## What was done
- bullet list of specific changes made (not vague summaries)

## Files modified
- `path/to/file.pas` — what was changed and why

## Files NOT modified (and why)
- if you wanted to change an unlisted file but didn't, explain here

## Test results
- Compilation 64-bit: OK/FAIL
- Compilation 32-bit: OK/FAIL
- Tests passed (64-bit): X of Y
- Tests passed (32-bit): X of Y
- List any remaining failures with test names

## Notes
- any issues encountered, decisions made, or questions for review
```

If you cannot complete the task, set status to BLOCKED and explain why in Notes.

**Before writing the report**, run `git diff` to verify you only modified files listed in the task.

## Reference

- `CLAUDE.md` (repo root) — project overview, architecture, dependency hierarchy, code style
- `PLAN.md` (repo root) — overall refactoring plan and progress checklist
- `Base/COMMON_REFACTORING.md` — detailed map of every function in Apus.Common and its planned destination
- Test examples: `Base/tests/TestConv.dpr`, `Base/tests/TestCore.dpr`

## Using Git

This is a git repository on branch `engine5`. After completing a task, you can use `git diff` to review your changes before writing the report. If something goes wrong, the lead developer can revert using git.
