# Engine Work Ahead Log
Last updated: 2026-03-11

This file tracks active execution only:
- immediate priorities;
- current blockers;
- follow-up queue for already completed features.

Large feature planning lives in `engine5_feature_roadmap.md`.

## Done (recent, high impact)
- R-02 secondary-window render milestone (2026-03-11):
  - rendering in secondary window is confirmed working in real runtime;
  - moved from "startup-only scaffold" to active two-window render baseline.
- R-02 GPU buffer API implementation slice (2026-03-11):
  - added buffer policy flags (`abThreadLocal`, `abReadOnly`, `abShared`);
  - added `TEngineBuffer` policy methods and ownership checks;
  - replaced coarse buffer sync gate with policy-aware `NeedSyncForBufferRead/Write` (compat wrapper preserved);
  - added backend-agnostic public publish/wait API with backend-internal GL fence storage;
  - added explicit `IGraphicsSystem.InitThreadContext(wnd)` and integrated it into secondary-thread startup;
  - hot-path draw/text per-thread buffers now allocate as thread-local, static per-thread index buffers are made immutable;
  - per-context secondary-window VAO is now destroyed in `DoneGraph` (lifecycle leak fixed);
  - text callbacks (`textColorFunc`, `textLinkStyleProc`) moved to thread-local ownership.
- R-02 GPU buffer API planning checkpoint (2026-03-11):
  - practical implementation plan prepared: `reports/R-02_gpu_buffer_api_plan.md`;
  - documented motivations, API gaps, and proposed policy-based buffer design (`thread-local/read-only/shared mutable`);
  - added incremental rollout phases with explicit acceptance criteria and recommended execution order.
- R-02 UI size-source cleanup finalized:
  - removed `rootWidth/rootHeight` and `SetDisplaySize` flow from `Apus.Engine.UIScene`;
  - UI root is now the source of truth for scene UI dimensions (`UI.width/height` and `clientWidth/clientHeight` semantics);
  - scene activation now requires an attached window (`ASSERT(window<>nil)`), dangling scenes are explicitly forbidden.
- R-02 locking/ownership checkpoint:
  - per-window lock flow is active in UI/scene operations (`window.Lock/window.Unlock`);
  - scene/window ownership resolution uses `scene.ownerWindow` + UI root `ownerScene` (fast path via `mainWindow`, fallback via window hash lookup).
- R-02 decision recorded:
  - no UI adapter layer for size/input abstraction at this stage;
  - keep global UI focus/hover/modal state (`underMouse`, `focusedElement`, `modalElement`, etc.) for now and revisit only if multi-window pressure requires it.
- Build status checkpoint (after R-02 UI changes):
  - repository-wide `rootWidth/rootHeight` references are fully removed;
  - full `SimpleDemo` build currently fails on unrelated pre-existing issues:
    - SDL profile: unresolved `dm*` identifiers in `Apus.Engine.SDLplatform`;
    - non-SDL profile: unresolved OpenGL context symbols in `Apus.Engine.GameApp`.
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
- Startup latency investigation (`SimpleDemo`, SDL):
  - apparent ~5s delay before first window was reproduced only under debugger;
  - normal standalone launch shows fast startup (`CreateMainWindow -> Init main loop` around ~55 ms in user log);
  - decision: treat long startup under debugger as measurement artifact, not engine regression.
- R-02 phase-1 API cleanup implemented (Windows path):
  - `TWindow` extracted as main window abstraction and normalized method names (`Configure`, `Show`, `GetHandle`, `MoveTo`, `SetCaption`, `Close`);
  - OpenGL-specific context types removed from `Apus.Engine.API`;
  - OpenGL request/actual context flow moved to `Apus.Engine.OpenGL` (`oglContextTemplate` / `oglContextInfo`);
  - `TWinGLWindow.InitGraph` now fills actual context info directly for `TOpenGL.Init`.
 - R-02 phase-1 stabilization closed (runtime state ownership):
   - window-owned runtime fields finalized in `TWindow` (input/frame/render/scenes);
   - legacy runtime proxies removed from `TGameBase`;
   - engine/demo active paths migrated to explicit `window.*`;
   - input snapshot policy documented: per-window input state is stored independently to keep frame processing stable under future multi-window threading.
- Scene lifecycle refactored (R-02 / F1):
  - lifecycle contracts documented: Create(window) в†’ Load в†’ InitGfx в†’ Process в†’ Render;
  - `Initialize` renamed to `InitGfx` (GPU-only, automatic, never call manually);
  - `TUIScene.Create` takes optional `wnd:TWindow` parameter (defaults to `mainWindow`), uses `wnd.renderWidth/Height` and `wnd.AddScene` directly;
  - `TGameScene` is created dangling (must be added to a window manually or via subclass constructor);
  - `MessageScene` chicken-and-egg bug fixed: UI created in constructor, no `initialized` gate in `CheckQueue`;
  - scene `Load` registration simplified: all scenes unconditionally added to `scenesToLoad` (removed method pointer comparison hack).
- R-02 AddWindow API scaffold (2026-03-11):
  - `RegisterClassW` made idempotent in `WindowsPlatform.CreateWindow` (flag guard).
  - `TWindow.InitGraphShared(primary:TWindow)` added as virtual abstract; `TWinGLWindow` implementation
    creates shared GL context via `wglCreateContextAttribsARB(DC, primaryContext, attribs)`.
  - `CreateOpenGLContext` gained `shareWith:UIntPtr` parameter (was hardcoded `0`).
  - `TGameBase.AddWindow(settings) / AddWindow(title,w,h) / RemoveWindow(wnd)` — public API in `Apus.Engine.API`.
  - `ExtraWindowLoop` — per-window render thread in `Apus.Engine.Game`: creates native window,
    configures it, creates shared GL context, runs frame loop (messages → scenes → render → present).
  - `TGame.RenderScenesForWindow(wnd)` — simplified scene render (Z-sort, InitGfx, Render).
  - `demo/MultiWindow` updated to use `game.AddWindow` + `TToolScene`.
  - All changed files compile cleanly under FPC (API.pas, Game.pas, WindowsPlatform.pas, Window.pas).
- R-02 AddWindow runtime stabilization (2026-03-10):
  - startup handshake for `AddWindow` is now explicit (`startup done/failed`, error propagation); blocking startup contract documented;
  - startup context switched to stack-lifetime with strict startup-only usage (`ewCtx:=nil` after startup phase);
  - `TWinGLWindow.terminated` is per-window; extra window close path no longer sends global exit on `WM_DESTROY`;
  - `WM_QUIT` in extra-window thread now terminates that window only (global exit remains main-window-only);
  - `TWinGLWindow.Close` no longer calls `UnregisterClassA`;
  - `RemoveWindow` has safe `renderThread<>nil` guard;
  - extra-context VAO is created in `InitGraphShared`; hot-path global VAO re-bind in `TRenderDevice.SetupAttributes` removed;
  - `RegisterClassW` now treats `ERROR_CLASS_ALREADY_EXISTS` as non-fatal.
- R-02 §3.7 kickoff (2026-03-10):
  - `TTransformationAPI` mutable runtime state moved to `class threadvar`
    (`view/proj/obj/inv/MVP`, projection params, dirty flags);
  - `TGLShadersAPI` mutable runtime state moved to `class threadvar` + per-thread lazy init (`EnsureThreadState`);
  - `TDrawer` mutable runtime/buffer state moved to `class threadvar` + per-thread lazy init;
  - `TTextDrawer` mutable runtime/buffer state moved to `class threadvar`; link/glyph-cache state is thread-local;
  - `TOpenGL.canPaint` and debug-group depth are thread-local.
- R-02 §3.7 tail closed (2026-03-10):
  - `TRenderTargetAPI` mutable runtime state moved to thread-local storage; per-thread lazy init added;
  - `TClippingAPI` clip stack/actual-clip/reject mode moved to thread-local storage; per-thread lazy init added;
  - `TRenderDevice` draw-state/stream-buffer tracking moved to thread-local storage; per-thread lazy init added;
  - `TGLRenderTargetAPI` backbuffer/scissor runtime state is thread-local with per-thread GL viewport bootstrap.
- R-02 multi-GPU policy fixed (2026-03-11):
  - in multi-GPU systems, one GPU is treated as primary and all rendering is executed on it;
  - multi-window path assumes shared context support, so resource duplication between windows is not required;
  - symmetrical multi-GPU collaborative rendering is explicitly out of native Engine5 scope.

## In Progress (active now)
- R-02 multi-window rendering safety (stress-validation and cleanup stage):
  - `TGameBase.AddWindow(settings) / AddWindow(title,w,h) / RemoveWindow(wnd)` declared in API.pas;
  - `ExtraWindowLoop` + startup handshake + close/termination behavior are stabilized for extra windows;
  - per-context VAO bootstrap exists in `InitGraphShared`;
  - `transform/shader/draw/txt/renderTarget/clipping/renderDevice` mutable runtime state migration is in place;
  - runtime baseline reached: secondary window renders successfully;
  - next focus: stress cycles (open/render/close/add/remove), cleanup, and race/regression checks.
  - **RESOLVED (2026-03-10): shared context creation failure (0xC00710DD):**
    - root cause: `AddWindow` was called from a non-main thread (`DelayedClick`), and `ReleaseGraphContext` (`wglMakeCurrent(0,0)`) only affects the calling thread — primary GL context remained current in main thread, blocking WGL sharing;
    - fix: atomic context release protocol (`glContextState`: 0→1→2→0) — `AddWindow` from any thread requests main thread to release GL context via `FrameLoop` check, waits for confirmation, proceeds with shared context creation, then signals main thread to reacquire;
    - shared context now creates successfully through regular `CreateOpenGLContext(...,shareWith)` flow.
- Render follow-up after core migration (lower priority now):
  - reduce NSight-reported useless `glBind*` churn in hot paths.

## Next (ordered)
1. R-02: multi-window stress validation pass (`demo/MultiWindow`):
   - repeated add/remove/open/close cycles under active rendering;
   - verify text path and shared-resource stability under stress;
   - verify cleanup/lifetime correctness after window teardown.
2. R-02: move DPI/scale fully to per-window flow (including runtime resize/re-layout triggers).
3. Migrate demo scenes from `Initialize` to new lifecycle (constructor + `InitGfx`) — 6 demos, low urgency.
4. Update Pascal SDL headers/bindings baseline (currently `2.0.4`) to reduce runtime/header drift with deployed SDL `2.32.10`.
5. Remove redundant bind churn:
   - avoid unnecessary bind-to-zero in hot paths;
   - strengthen lightweight state-cache checks before `glBind*`;
   - unify repetitive bind/draw/unbind patterns in `Apus.Engine.Draw`.
6. Runtime-wire shader variant selection based on actual context/profile info (`oglContextInfo`) where still compile-time split.
7. Define first concrete R-09 implementation slice:
   - capability-gated persistent mapped streaming path with safe fallback;
   - explicit batching entry point for high-frequency simple primitives (line-heavy cases).
8. Start R-10 (UI widget system refactor, P0):
   - document `TUIElement` decomposition variants and select implementation direction;
   - implement selected split and run focused widget-class reorganization review;
   - keep widget/layout expansion and widget/layout tests as explicit follow-ups after core refactor.

## R-02 Architecture Review Notes (2026-03-09)

Phase 1 complete: TWindow extracted, scenes/timings/capture moved to TWindow, platform decoupled from graphics.
Below are items to verify/address in later phases.

### DONE: per-window fields migration
Fields moved from TGameBase to TWindow, global `window:TWindow` added.
`preWindowScenes` eliminated вЂ” window is created together with game.

### Post-migration: UI modules and per-window correctness
- **UI modules audit**: `UIScene`, `UIRender`, `UITypes`, `UIWidgets`, `DefaultStyle`, `ConsoleScene`, `TweakScene`, `MessageScene` now use global `window.*` вЂ” verify they reference the correct window when multiple windows exist (e.g. tooltip positioning in DefaultStyle uses `window.renderWidth/Height` вЂ” must be the window that owns the tooltip).
- **DPI per window**: `screenDPI` and `screenScale` remain on TGameBase (global). For multi-monitor setups with different DPI, these must become per-window. Affects: font sizing, UI scaling, coordinate transforms. `DefaultStyle` uses `globalScale` which derives from DPI.
- **`game.screenDPI`** migration in active demo paths is complete (`window.screenDPI`); keep a quick grep check for stale references in non-critical demos/tests.
- **Input routing**: `IsMouseBtn`, `IsKeyDown`, `IsKeyPressed`, `IsKeyReleased` (API.pas) use global `window.*` вЂ” correct for single window, but multi-window needs to know which window has focus/received the event.
- **`underMouse` (UITypes)**: global variable, assumes single coordinate space. Multi-window = separate `underMouse` per window.
- **`focusedElement` (UITypes)**: also global вЂ” keyboard focus should be per-window.

### Phase 2: frame loop refactoring вЂ” PARTIALLY DONE
- Main window still uses `TGame.FrameLoop` / `TGame.RenderAndPresentFrame`.
- Extra windows use `ExtraWindowLoop` (standalone per-window render thread with own frame loop).
- **Remaining**: per-thread render state (В§3.7) so extra window can actually call `draw`/`txt`/`shader`/`transform` safely.

### Phase 2-3: gfx singleton and threadvar state вЂ” MAIN BLOCKER
- `gfx:IGraphicsSystem` is process-global, `TOpenGL.Init(window)` binds to one window.
- Global refs `draw`, `txt`, `shader`, `transform` need `class threadvar` render state per plan В§3.7.
- This is the main remaining architectural challenge for multi-window rendering.
- Without this, extra window thread shares mutable state with main thread (unsafe).

### Naming: PresentFrame at three levels
- `TGame.PresentFrame` = finalize frame (dRT blit + gfx.PresentFrame + frameNum++)
- `TOpenGL.PresentFrame` = call window swap
- `TWindow.PresentFrame` = platform SwapBuffers
- Consider renaming TWindow level to `SwapBuffers` for clarity.

### Thread safety: TWindow.scenes
- `window.scenes` is public, read directly by `TGameBase.TopmostVisibleScene`.
- CritSect in TGameBase does not protect the array in TWindow.
- For multi-window with per-window threads: make scenes private, access via methods only.

### Dependency direction: WindowsPlatform в†’ OpenGL
- `Apus.Engine.WindowsPlatform` uses `Apus.Engine.OpenGL` in interface (for `TOpenGLContextDesc`).
- Platform depending on graphics is inverted. Consider moving `TOpenGLContextDesc`/`TOpenGLContextProfile` to `Apus.Engine.Types`.

### TOpenGLContextDesc: dual-purpose record
- Same record holds request fields (`minMajor/minMinor`) and actual fields (`actualMajor/actualMinor`).
- `profile` and `debugContext` are overwritten from request to actual вЂ” original request is lost.
- Consider splitting back into request + actual, or at least preserving request fields unmodified.

### FPC compilation
- `ISystemPlatform.CreateWindow` now returns `TWindow` directly вЂ” verify this compiles without FPC Internal Error 200611031 (clean rebuild if needed).

## Follow-ups (completed features, non-blocking)
- Robot API reliability:
  - investigate edge-case shutdown flow (`signal Engine\Cmd\Exit`) in stalled/hung runtime states.
- Demo behavior notes:
  - `Win+\`` opening borderless PowerShell likely external hotkey interaction; keep as low-priority verification item.

## Backlog
- MultiWindow demo: investigate ~1 Hz freezes during window resize (likely `ProcessMessages` stall from modal resize loop).
- Secondary render thread logging: make logs context-rich and consistent (window name/thread id/startup vs frame-loop events).
- Scene load logging cleanup: avoid "Load" log spam for scenes that keep default/empty `Load` implementation.
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
- Startup/perf measurement policy:
  - measure and compare startup timings outside IDE/debugger;
  - debugger-attached startup delays should be logged as environment artifacts unless reproduced in standalone run.

## Apus.Lib / Types policy
- `Apus.Engine.Types` contains engine-specific types only.
- `Apus.Core` remains mandatory base import.
- `Apus.Lib` is a convenience re-export; keep it lightweight and non-duplicative with `Apus.Core`.
- Use explicit `SysUtils` when module-specific RTL APIs are needed.




