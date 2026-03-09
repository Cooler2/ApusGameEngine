# Engine Work Ahead Log
Last updated: 2026-03-09

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
  - `fps` command upgraded with high-precision frame-time diagnostics:
    - `frameTimeMs` / `FRAME_MS` (high-precision source, ms format);
    - delayed metrics collection mode (`METRICS:YES`, collect for `N` frames before response);
    - per-frame phase telemetry for diagnostics (`MSG`, `ONFRAME`, `RENDER`, `PRESENT`, `SLEEP`, `Total`).
- `01-Scenes` DPI/layout centering regression fixed:
  - root cause: positioning against `width/height` instead of `clientWidth/clientHeight` under UI scale;
  - demo source updated accordingly.
- SDL startup path unblocked for `SimpleDemo`:
  - `Apus.Engine.SDLplatform` migrated away from deprecated `Apus.CrossPlatform/Apus.Common` usage;
  - SDL input/platform code aligned with current core API (`Bits.SetBit`, UTF8 conversion, key mapping compatibility);
  - `SimpleDemo` SDL build path validated (`-dSDL`), runtime launch confirmed when DLL set is available.
- SDL freeze investigation closed (`SimpleDemo`, Windows+SDL):
  - root cause localized in SDL event pump path (`SDL_PollEvent`), not in engine message handlers/render;
  - diagnostics added (`POLL total/max/calls`) showed long cumulative poll time with high-frequency mouse events;
  - runtime SDL binaries updated from `2.0.12/2.0.14` to `2.32.10` (`bin`/`bin64`);
  - result: stalls/freeze bursts disappeared in user validation run.
- R-02 phase-1 API cleanup implemented (Windows path):
  - `TWindow` extracted as main window abstraction and normalized method names (`Configure`, `Show`, `GetHandle`, `MoveTo`, `SetCaption`, `Close`);
  - OpenGL-specific context types removed from `Apus.Engine.API`;
  - OpenGL request/actual context flow moved to `Apus.Engine.OpenGL` (`oglContextTemplate` / `oglContextInfo`);
  - `TWinGLWindow.InitGraph` now fills actual context info directly for `TOpenGL.Init`.

## In Progress (active now)
- SDL core-profile parity (high priority):
  - stabilize SDL runtime quality to match Windows path (current status: startup works; major `SDL_PollEvent` freeze issue fixed by SDL runtime upgrade).
- Render follow-up after core migration (high priority):
  - reduce NSight-reported useless `glBind*` churn in hot paths.

## Next (ordered)
1. Finish SDL-path stabilization and runtime validation on at least one SDL demo path.
2. Update Pascal SDL headers/bindings baseline (currently `2.0.4`) to reduce runtime/header drift with deployed SDL `2.32.10`.
3. Keep the new Robot API `fps` + message diagnostics for future regressions, but treat the current SDL freeze investigation as resolved.
4. Remove redundant bind churn:
   - avoid unnecessary bind-to-zero in hot paths;
   - strengthen lightweight state-cache checks before `glBind*`;
   - unify repetitive bind/draw/unbind patterns in `Apus.Engine.Draw`.
5. Runtime-wire shader variant selection based on actual context/profile info (`oglContextInfo`) where still compile-time split.
6. Define first concrete R-09 implementation slice:
   - capability-gated persistent mapped streaming path with safe fallback;
   - explicit batching entry point for high-frequency simple primitives (line-heavy cases).
7. Start R-10 (UI widget system refactor, P0):
   - document `TUIElement` decomposition variants and select implementation direction;
   - implement selected split and run focused widget-class reorganization review;
   - keep widget/layout expansion and widget/layout tests as explicit follow-ups after core refactor.

## Follow-ups (completed features, non-blocking)
- Robot API reliability:
  - investigate edge-case shutdown flow (`signal Engine\Cmd\Exit`) in stalled/hung runtime states.
- Demo behavior notes:
  - `Win+\`` opening borderless PowerShell likely external hotkey interaction; keep as low-priority verification item.

## Backlog
- Demo build automation via `.bat` wrappers.
- Manual Delphi milestone checks.
- Linux Base compile backlog (remaining failing modules).
- R-11 (P2) headless/NOGFX backend for CI UI automation:
  - headless run without window/OpenGL context;
  - synthetic input-driven UI behavior tests;
  - optional later stage: CPU offscreen capture path.

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
