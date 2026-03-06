# Engine Work Ahead Log
Last updated: 2026-03-06

This file tracks active execution only:
- immediate priorities;
- current blockers;
- follow-up queue for already completed features.

Large feature planning lives in `engine5_feature_roadmap.md`.

## Done (recent, high impact)
- R-01 core-profile migration completed (mandatory path):
  - `SimpleDemo` runs on core profile;
  - runtime context negotiation and fail-fast behavior implemented;
  - shader pipeline aligned for desktop core (`GLSL 330` path);
  - stream VBO/IBO fallback path in place for legacy pointer-fed draws.
- R-01 debug/NSight track completed:
  - GL debug callback wiring + readable diagnostics;
  - debug groups and object labels implemented;
  - NSight capture flow validated on `SimpleDemo`.
- Additional runtime confidence:
  - `demo/VertexBuffer` validated (mode switching + VSync toggle).
- Robot API MVP (R-04) is working and used in real debugging:
  - protocol stabilized (`robot_in.txt` / `robot_out.txt`);
  - `SimpleDemo` and `01-Scenes` validated;
  - `ui.element` upgraded (`HIERARCHY`, effective/internal states, live `globalRect`, optional layout dump).
- `01-Scenes` DPI/layout centering regression fixed:
  - root cause: positioning against `width/height` instead of `clientWidth/clientHeight` under UI scale;
  - demo source updated accordingly.

## In Progress (active now)
- SDL core-profile parity (high priority):
  - stabilize `Apus.Engine.SDLplatform` context creation/startup path to match Windows reliability.
- Render follow-up after core migration (high priority):
  - reduce NSight-reported useless `glBind*` churn in hot paths.

## Next (ordered)
1. Finish SDL-path stabilization and runtime validation on at least one SDL demo path.
2. Remove redundant bind churn:
   - avoid unnecessary bind-to-zero in hot paths;
   - strengthen lightweight state-cache checks before `glBind*`;
   - unify repetitive bind/draw/unbind patterns in `Apus.Engine.Draw`.
3. Runtime-wire shader variant selection based on actual context/profile info (`oglContextInfo`) where still compile-time split.
4. Define first concrete R-09 implementation slice:
   - capability-gated persistent mapped streaming path with safe fallback;
   - explicit batching entry point for high-frequency simple primitives (line-heavy cases).

## Follow-ups (completed features, non-blocking)
- Robot API reliability:
  - investigate edge-case shutdown flow (`signal Engine\Cmd\Exit`) in stalled/hung runtime states.
- OpenGL context API cleanup:
  - revisit global `oglContextRequest/oglContextInfo` and migrate to explicit runtime-owned flow when low risk.
- Demo behavior notes:
  - `Win+\`` opening borderless PowerShell likely external hotkey interaction; keep as low-priority verification item.

## Backlog
- Demo build automation via `.bat` wrappers.
- Manual Delphi milestone checks.
- Linux Base compile backlog (remaining failing modules).

## Rules / Decisions
- Documentation language policy: keep `engine_work_ahead.md` and `engine5_feature_roadmap.md` in English.
- `Base/engine5_changes.md` and `Base/engine5_status.md` are for Base-only changes.
- Engine progress tracking is kept at repo root.
- Standalone engine unit compile check default:
  - `-dOPENGL -MDelphi -Sd -RIntel`
  - `-Fu<repo> -Fu<repo>\extra -Fu<repo>\extra\sdl2 -Fu<repo>\Base -Fu<repo>\Base\extra`
  - add `-dSDL` only for SDL-specific verification.
- Feature closure policy:
  - close tasks when MVP works and core criteria are met;
  - keep further improvements as explicit follow-up items, not as open main tasks.
- Commit discipline policy:
  - do not commit every incidental change;
  - documentation changes are usually local and should be committed only by explicit request or as intentional backup.
- GL label naming convention:
  - prefer short code-aligned names (`meshVB`, `textIB`, etc.), keep labels concise.

## Apus.Lib / Types policy
- `Apus.Engine.Types` contains engine-specific types only.
- `Apus.Core` remains mandatory base import.
- `Apus.Lib` is a convenience re-export; keep it lightweight and non-duplicative with `Apus.Core`.
- Use explicit `SysUtils` when module-specific RTL APIs are needed.
