# Task 001 — Fix TestStrings compilation and failing tests

## Goal

Make `Base/tests/TestStrings.dpr` compile and pass all tests in both 32-bit and 64-bit modes.

## Context

`TestStrings.dpr` tests the `Apus.Strings` module (String8/String32 type helpers and UTF8 utilities). The test file was recently created and has 222 test checks. Last run showed 18 failures, but since then the code has been modified and currently does not compile.

## Steps

1. **Compile** `TestStrings.dpr` using `test.bat`:
   ```
   cd Base\tests
   test.bat Strings
   ```
2. **Read** the output files `test_results_64.txt` and `test_results_32.txt`.
3. **Fix compilation errors** if any — in `TestStrings.dpr` (test file) or `Apus.Strings.pas` (source).
4. **Fix failing tests** by determining whether the bug is in:
   - The **test** (wrong expected value) — fix the test
   - The **implementation** (wrong behavior) — fix `Apus.Strings.pas`
5. **Repeat** until all tests pass in both 32-bit and 64-bit modes.

## Rules

- Do NOT change function signatures in the `interface` section of `Apus.Strings.pas`.
- Do NOT change the test framework (`Test.inc`) or other test files.
- Do NOT add new test procedures — only fix existing ones.
- Do NOT remove any tests — fix them instead.
- When in doubt whether the test or the implementation is wrong, trust the **test name and description** as the specification. For example, if a test says `Check(s.IndexOf('o')=5, 'IndexOf(o)')` and the string is `'Hello'`, then the expected value 5 is correct (1-based for String8).

## Key facts

- `String8` uses **1-based** indexing (standard Pascal), returns `0` for "not found".
- `String32` (= UCS4String) uses **0-based** indexing (it's a dynamic array), returns `-1` for "not found".
- `UTF8.Decode` / `UTF8.Encode` convert between String8 (UTF-8) and String32 (UCS-4).
- The `IsValid` check for `#$C0#$80` should return `false` (it's an overlong encoding of U+0000).

## Files you may modify

- `Base/Apus.Strings.pas` — implementation fixes only (not interface)
- `Base/tests/TestStrings.dpr` — test fixes if expected values are wrong

## Completion

Write your report to `Base/cline/result001.md` following the format described in `guide.md`.
