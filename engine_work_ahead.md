# Engine Work Ahead Log
Last updated: 2026-02-26

This file is for active execution tracking only:
- small and medium changes;
- immediate next steps;
- current blockers and decisions.

Large feature planning is tracked separately in `engine5_feature_roadmap.md`.

## Done
- First wave of Base refactoring completed and committed.
- Foundation API stabilized (`Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Types`, `Apus.Threads`).
- Added case-insensitive search support in `Apus.Strings` and updated migration notes/TODO flow.
- Migrated `Apus.HtmlTree` to `String8` API.
- `Apus.Strings`: added `SplitLines` (auto-detects CR/LF/CRLF), restored `ignoreCase` param for `StartsWith`/`EndsWith`.
- Redesigned `Apus.Engine.Keys` to production quality:
  - `TKey` scoped enum with full key set (letters, digits, numpad, F-keys, OEM, locks), values = Windows VK_ codes.
  - `TKeyMod` / `TKeyMods` modifier bitmask with L/R distinction (LShift/RShift/Shift etc).
  - Type helpers: `TKey.Code`, `TKey.Name`, `TKey.From()`, `TKey.FromWindowsVK()`, `TKey.FromSDL()`.
  - `TKeyMods.Has()`, `ToLegacy`/`FromLegacy` for sscXxx interop.
  - `KeyIn(code, keys)` standalone function.
  - Removed old API: `KeyCodeSet`, `KeyIs()`, `KeyCodeValue()`, `KeyFromCode()`.
- Updated smoke test `tests/KeyEnumSmoke.pas` to cover new API.

## In Progress
- Move from Base-level refactoring to engine-level integration.
- Primary integration target selected: `demo/SimpleDemo`.
- Build strategy aligned: iterative FPC CLI cycle (`build -> first error -> fix -> repeat`).

## Next
- Bring `Apus.Lib` to a complete foundation re-export hub (without string helper re-export).
- Establish demo build automation via `.bat` scripts (single script or one per demo).
- Reach successful FPC build for `SimpleDemo`.
- Run manual Delphi build checks at milestones.
- After `SimpleDemo`, migrate/build one more demo to lock an engine-wide working baseline.
- Backlog: investigate Linux build failures in Base (currently 12 modules do not compile).
- Migrate `Apus.Engine.ImgLoadQueue` to use `Apus.Threads` (replace raw TThread with engine threading).
- Continue keyboard migration: integrate `Apus.Engine.Keys` into engine input/UI path and replace `VK_*` usages incrementally.

## Future TODO (low priority)
- `Apus.Engine.Keys`: add `TKey.FromName(s:string):TKey` — parse key name string back to TKey (for config files, key binding UI).
- `Apus.Engine.Keys`: add `THotkey` type (TKey + TKeyMods combo) with parsing/formatting support (e.g. `"Ctrl+Shift+A"`).
- `Apus.FreeTypeFont`: fix issues from code review report: [reports/review_apus_freetypefont_2026-02-27.md](/G:/apus/enginerev/reports/review_apus_freetypefont_2026-02-27.md).

## Rules / Decisions
- Documentation language policy: use English as the default language for both `engine_work_ahead.md` and `engine5_feature_roadmap.md`.
- `Base/engine5_changes.md` and `Base/engine5_status.md` are for Base-only changes.
- Engine-level migration/progress tracking is kept in files at repo root.
- No `lazbuild` dependency required; use `fpc` + `.bat` workflow.
- If a task forces Base API/interface changes, then update Base tracking files as needed.

### Apus.Lib / Types policy
- `Apus.Engine.Types` contains only engine-specific types (no re-export role).
- `Apus.Core` stays the mandatory base import.
- `Apus.Lib` is a convenience re-export for foundation-level types from `Apus.*` plus a small set of very common RTL types.
- `Apus.Lib` must not duplicate what already exists in `Apus.Core`.
- Typical module import pattern: `uses Apus.Core, Apus.Lib, ...` plus explicit modules for missing/specialized APIs.
- Record helpers (`String8Helper`, `String32Helper`) are not re-exported.
- Do not use `Apus.Lib` as a proxy replacement for `SysUtils`; import `SysUtils` explicitly when module-specific RTL functions are needed.
- Keep `Apus.Lib` free from heavy/specialized/platform-specific subsystems.
