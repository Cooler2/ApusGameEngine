# Engine Work Ahead Log
Last updated: 2026-03-05

This file is for active execution tracking only:
- small and medium changes;
- immediate next steps;
- current blockers and decisions.

Large feature planning is tracked separately in `engine5_feature_roadmap.md`.

## Done
- First wave of Base refactoring completed and committed.
- Foundation API stabilized (`Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Types`, `Apus.Threads`).
- Prepared phased migration plan for R-01 (OpenGL compatibility -> core context, NSight target): [core_context_migration_plan.md](/G:/apus/enginerev/core_context_migration_plan.md).
- Added case-insensitive search support in `Apus.Strings` and updated migration notes/TODO flow.
- Migrated `Apus.HtmlTree` to `String8` API.
- `Apus.Strings`: added `SplitLines` (auto-detects CR/LF/CRLF), restored `ignoreCase` param for `StartsWith`/`EndsWith`.
- Added `engine_module_refactor_checklist.md` as the standard checklist for future module-by-module engine analysis.
- Added `module_refactor_inventory.md` to track engine modules and selected Base modules for follow-up refactoring analysis.
- Redesigned `Apus.Engine.Keys` to production quality:
  - `TKey` scoped enum with full key set (letters, digits, numpad, F-keys, OEM, locks), values = Windows VK_ codes.
  - `TKeyMod` / `TKeyMods` modifier bitmask with L/R distinction (LShift/RShift/Shift etc).
  - Type helpers: `TKey.Code`, `TKey.Name`, `TKey.From()`, `TKey.FromWindowsVK()`, `TKey.FromSDL()`.
  - `TKeyMods.Has()`, `ToLegacy`/`FromLegacy` for sscXxx interop.
  - `KeyIn(code, keys)` standalone function.
  - Removed old API: `KeyCodeSet`, `KeyIs()`, `KeyCodeValue()`, `KeyFromCode()`.
- Updated smoke test `tests/KeyEnumSmoke.pas` to cover new API.
- Engine-level compile pass reached working baseline:
  - `Apus.Engine.ShadersGL` migrated away from legacy string helpers and old flag helpers.
  - `Apus.Engine.GameApp` migrated to current logging/bit/thread APIs.
  - `demo/SimpleDemo` now builds successfully with FPC and runs correctly.
- Standalone engine unit compile command clarified:
  - default check uses `-dOPENGL -MDelphi -Sd -RIntel`
  - add `-dSDL` only when SDL-specific code path is under test
  - required search paths: repo root, `extra`, `extra\sdl2`, `Base`, `Base\extra`
- `Apus.Threads` / `Base/tests/TestThreads` hardening completed (commit `4510526`):
  - fixed `IThread.Wait(timeout)` semantics and clarified timeout behavior comments;
  - added POSIX one-time thread resource reap (`pthread_join`) after completion wait;
  - expanded thread tests (callable overloads, finalization, error path, wait-timeout);
  - documented Delphi debugger timing caveat for unhandled-exception test case.
- R-01 core-context migration started (Stage 0-1, first implementation increment):
  - `Apus.Engine.API`: added `TOpenGLContextRequest` / `TOpenGLContextInfo` and extended `ISystemPlatform.CreateOpenGLContext(...)` signature.
  - `Apus.Engine.GameApp`: added app-level OpenGL context request settings (`glCoreContext`, debug/forward flags, min version, prefer-highest) and CLI toggles (`-GLCORE`, `-GLCOMPAT`, `-GLDEBUGCTX`, `-GLFORWARDCTX`).
  - `Apus.Engine.OpenGL`: wired request propagation + startup logging for requested vs actual context parameters.
  - `Apus.Engine.WindowsPlatform` and `Apus.Engine.SDLplatform`: switched to new context API contract with `actual` context reporting.

## In Progress
- First wave of engine migration is effectively complete:
  - almost all engine modules are already migrated to the new foundation API
  - `demo/SimpleDemo` builds and works as the first confirmed working baseline
- Current phase is no longer compile rescue; it is structured follow-up refactoring and development.

## Next
- Pick the next demo after `SimpleDemo` and use it as the next validation target.
- Run a second pass on already touched engine modules:
  - replace migration-style fixes with cleaner engine5-native usage
  - remove unnecessary dependencies
  - note any remaining suspicious runtime edge cases
- Maintain a short queue of targeted Base refactorings that directly improve engine code or unblock cleaner migrations.
- Start preparing the first architecture-level changes that are now practical on top of the migrated foundation.
- Convert the current high-level roadmap into a small set of concrete near-term implementation targets.
- Establish demo build automation via `.bat` scripts (single script or one per demo).
- Run manual Delphi build checks at milestones.
- Backlog: investigate Linux build failures in Base (currently 12 modules do not compile).
- R-01 design discussion item: remove global `oglContextRequest/oglContextInfo` after Stage 0-1 bootstrap and move context-request flow to explicit runtime-owned configuration.

## Future TODO (low priority)
- `Apus.Engine.Keys`: add `TKey.FromName(s:string):TKey` — parse key name string back to TKey (for config files, key binding UI).
- `Apus.Engine.Keys`: add `THotkey` type (TKey + TKeyMods combo) with parsing/formatting support (e.g. `"Ctrl+Shift+A"`).
- `Apus.FreeTypeFont`: fix issues from code review report: [reports/review_apus_freetypefont_2026-02-27.md](/G:/apus/enginerev/reports/review_apus_freetypefont_2026-02-27.md).
- Base performance optimization track:
  - benchmark key Base modules and representative hot paths
  - identify implementation bottlenecks and weak spots
  - optimize internals without changing public APIs

## Rules / Decisions
- Documentation language policy: use English as the default language for both `engine_work_ahead.md` and `engine5_feature_roadmap.md`.
- `Base/engine5_changes.md` and `Base/engine5_status.md` are for Base-only changes.
- Engine-level migration/progress tracking is kept in files at repo root.
- No `lazbuild` dependency required; use `fpc` + `.bat` workflow.
- Standalone engine unit compile checks should avoid `-dSDL` unless SDL-specific code is under test; default command is `-dOPENGL -MDelphi -Sd -RIntel` plus search paths `-Fu<repo> -Fu<repo>\extra -Fu<repo>\extra\sdl2 -Fu<repo>\Base -Fu<repo>\Base\extra`.
- If a task forces Base API/interface changes, then update Base tracking files as needed.
- Reaching "builds and works" for `SimpleDemo` marks the end of the first engine compile-rescue wave.
- After the first wave, work is expected to continue in four parallel directions:
  - engine-module refinement on top of the new foundation API
  - targeted Base refactoring with follow-up engine migrations
  - engine architecture improvements
  - roadmap-driven feature implementation

### Apus.Lib / Types policy
- `Apus.Engine.Types` contains only engine-specific types (no re-export role).
- `Apus.Core` stays the mandatory base import.
- `Apus.Lib` is a convenience re-export for foundation-level types from `Apus.*` plus a small set of very common RTL types.
- `Apus.Lib` must not duplicate what already exists in `Apus.Core`.
- Typical module import pattern: `uses Apus.Core, Apus.Lib, ...` plus explicit modules for missing/specialized APIs.
- Record helpers (`String8Helper`, `String32Helper`) are not re-exported.
- Do not use `Apus.Lib` as a proxy replacement for `SysUtils`; import `SysUtils` explicitly when module-specific RTL functions are needed.
- Keep `Apus.Lib` free from heavy/specialized/platform-specific subsystems.
