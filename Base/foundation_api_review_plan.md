# Foundation API Review Plan

Date: 2026-02-19
Based on modules: `Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Types`, `Apus.Threads`

## Priority findings

1. `Apus.Core`: `Min/Max` overloads for `cardinal/int64/uint64` and 3-arg `single` return `integer`, which can truncate or overflow large values.
2. `Apus.Strings`: `String32Helper` indexing and not-found semantics are inconsistent with `String8Helper` and with module-level API messaging.
3. Sentinel mismatch: `String8.IndexOf` returns `0` if not found, while `String32.IndexOf` returns `-1`.
4. Responsibility overlap: conversion helpers exist both in `Apus.Strings` (`ToInteger/ToDouble/...`) and `Apus.Conv`.
5. Parameter order inconsistency: `Insert(element,index)` vs `Insert(index,value)` across modules.
6. Mixed return string types in `Apus.Conv`: both `string` and `String8`.
7. `IThread.Pause` is toggle semantics (without explicit `Resume`), which is not obvious by name.

## Immediate step (current task)

- Add explicit corner-case tests for findings #1 and #2 in `Base/tests`.
- Run tests via `Base/tests/test.bat` to get formal failing results.

## Proposed follow-up refactoring direction

- Fix #1 with safe API evolution:
- Add correctly typed overloads (or new names), keep old ones as deprecated wrappers.
- Update tests and call sites incrementally.
- Fix #2 semantics:
- Choose one indexing contract for `String32Helper` (preferably match `String8` at public helper level), or document explicit asymmetry and keep conversion helpers separate.
- Normalize not-found sentinel behavior (prefer one convention across helper families).
