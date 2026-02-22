# Engine Work Ahead Log
Last updated: 2026-02-22

## Done
- First wave of Base refactoring completed and committed.
- Foundation API stabilized (`Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Types`, `Apus.Threads`).
- Added case-insensitive search support in `Apus.Strings` and updated migration notes/TODO flow.
- Migrated `Apus.HtmlTree` to `String8` API.

## In Progress
- Move from Base-level refactoring to engine-level integration.
- Primary integration target selected: `demo/SimpleDemo`.
- Build strategy aligned: iterative FPC CLI cycle (`build -> first error -> fix -> repeat`).

## Next
- Bring `Apus.Lib` to a complete foundation re-export hub (without string helper re-export).
- Establish demo build automation via `.bat` scripts (single script or one per demo).
- Reach successful FPC build for `SimpleDemo`.
- Run manual Delphi build checks at milestones.
- After `SimpleDemo`, migrate/build one more demo to lock engine-wide working baseline.

## Rules / Decisions
- `Base/engine5_changes.md` and `Base/engine5_status.md` are for **Base-only** changes.
- Engine-level migration/progress tracking is kept in files at repo root.
- No `lazbuild` dependency required; use `fpc` + `.bat` workflow.
- If a task forces Base API/interface changes, then update Base tracking files as needed.
