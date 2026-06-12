# Engine5 Feature Roadmap
Last updated: 2026-06-13

Language policy: this roadmap is maintained in English.

This file follows top-down planning:
- capture the high-level idea first;
- break it down into sub-features;
- then add implementation details and acceptance criteria.

## 1) Vision
- [ ] Engine5 as a stable cross-platform foundation for 2D/3D projects.
- [ ] A unified, predictable API across UI/Scene/Resources/Audio/3D.
- [ ] A smooth path from demo/template to production build.

## Feature Status Overview

| ID | Feature | Status | Readiness | Done | Remaining |
|----|---------|--------|-----------|------|-----------|
| R-01 | Core GL Pipeline Modernization | done | 100% | Core profile, VBO/IBO pipeline, NSight debugging validated | — |
| R-02 | Multi-Window / Multi-Monitor / DPI | in-progress | ~75% | Multi-window baseline works (AddWindow/shared context/secondary render), lifecycle refactor complete, runtime DPI flow improved | Multi-monitor placement validation, final per-window DPI/scale flow, close remaining multi-window overlay refresh issue |
| R-03 | Native AEM Pipeline + Blender Export | planned | ~15% | Direction fixed: OBJ + AEM only; no FBX/DAE converter; R-03 planning doc created | Freeze AEM v1 spec, align runtime loader, implement Blender exporter MVP |
| R-04 | Robot Interaction Layer | done | 100% | File-based protocol, all commands, FPS telemetry, UI diagnostics | — |
| R-05 | CSS-Like UI Style System | in-progress | ~75% | TStyleBlock, resolver, @refs, state blocks, patch, named catalog (TStyleCatalog), transitions (Tweenings), draw migration, StyleDemo, font/color/styleClass removed from TUIElement | Practical validation on real screens, resolver performance/caching, $varName support, visual regression tests |
| R-06 | 3D Material: Normal Mapping | idea | 0% | — | Shader path, tangent/bitangent handling, asset pipeline |
| R-07 | Geometry Overhaul (Single-First + Spatial) | in-progress | ~88% | Working state merged; support track active with recent bugfixes, test expansion, and new benchmarks | Linux fixes/validation, full baseline delta pass, SSE optimization of top hot paths, remaining module migration (including SDL paths) |
| R-08 | UI Hit-Test for Out-of-Bounds Children | done | 100% | Clip-threaded `FindElementAt` with `escapingOnly` mode for deep noParentClip descendants; `FindElementAt`/`FindAnyElementAt` unified as overloads. Verified on UI demo fixture (panel+popup and panel→mid→deep). Notes: `Work/reports/R-08_hittest_overlay_notes.md` | — |
| R-09 | GL Performance Modernization | in-progress | ~40% | Tracks A (telemetry overlay) + B (redundant state-change wins) done and merged; Track D research note drafted. Key finding: no cheap 4.x wins remain standalone — they pay off only as part of R-12 (persistent streaming) + Track C (array-texture batching) | NSight baseline on real scene (Track A); decide Track C scope from data |
| R-10 | UI Widget System Refactor | done | 100% | TUIElement slimmed, TUIShape unified, TUIToggleButton extracted, onClick/onClickAsync split, TUISkinnedWindow merged, ScrollBar orientation explicit, widget docs EN, dead code removed; ListBox color fields deferred (R-05 handles it via style pipeline) | — |
| R-11 | Headless/NOGFX CI Backend | idea | 0% | — | NoGfx platform stub, headless frame pump, CI integration |
| R-12 | Graphics: Text + Streaming Buffers | planned | ~5% | Detailed design complete (API contract, invalidation/LRU strategy) | Ring-buffer implementation, persistent text cache, profiling |
| R-13 | Robot API Input Simulation | idea | 0% | — | Implement `ui.click`/`ui.type`/`ui.focus` commands in Robot API |
| R-14 | UI Widget Expansion | idea | 0% | — | New widget types, module split strategy |
| R-15 | Demo Suite Restructuring | in-progress | ~25% | Planning baseline documented; standalone demos (`InputDemo`, `Draw2D`, `TextDemo`) are created and integrated into demo build flow | Continue tier restructuring, merge/move remaining demos, distribute EngineTest cases |
| R-16 | Console Modernization | in-progress | ~70% | Console.pas dissolved (deleted); ConsoleScene owns the buffer fed by a log mirror + CmdProc `OnOutput` sink; DEBUG/ERROR→log bridge moved to engine init; UX: two-tier filter, timestamp toggle, `clear`, `loglevel`, Ctrl+C clipboard, DPI-scaled font, per-source color palette. Merged to master. Plan: [Work/reports/R-16_console_modernization.md](Work/reports/R-16_console_modernization.md) | NOT closed — continues post-merge: scroll rework (sticky-bottom + ScrollToEnd unit fix), runtime polish. Related deferred-to-main bugs: build GUI mode, TUIWindow title-bar DPI, editbox Enter under SDL |
| R-17 | 3D Game Architecture Probe (skeleton-first) | idea | 0% | — | Build a top-down integrated 3D skeleton (scene graph + camera + multi-pass + post-process) to expose architectural "white spots"; audit done (no Camera/Material/RenderPass/SceneGraph types exist) |
| R-18 | Debug Draw Primitives (3D Gizmos) | planned | ~10% | Design settled: solid-primary set + line exceptions, module-baked lighting, batching deferred to R-09; task doc written | Build `Apus.Engine.DebugDraw` (plain `draw.*`), `demo/DebugDraw`, validate by porting NormalMap demo's `DrawGrid` |
| R-19 | Mesh Representation Unification & Rework | done | 100% | Geometry level complete & merged to `engine5`: `TGpuLayout`+semantic location table (B1), SoA `TMesh`+`TBox3` (B2), table-driven GL binding pair (B3), `TGpuMesh` upload/draw (B4), stage-C closeout (`SetVertexCount` fill-API, per-section draw, geometry-only OBJ→`TMesh` loader, MeshLab multi-section + 90k-vert grid). Headless gates pass; MeshLab author-validated. Scope re-bound 2026-06-12 to geometry level only | Moved OUT (not R-19): TModel/TModelInstance + AEM + GPU-skin/instancing → R-03; `Mesh3D`→`Mesh` rename + legacy-consumer migration + drop IQM + OBJ-loader consolidation → deferred migration |
| R-20 | Mesh Shape Generators (Procedural Primitives) | idea | 0% | — | Design discussion (MVP primitive set, fill pattern, tangents, conventions), then `Apus.Engine.MeshShapes` + headless test; unblocks R-18 solid shapes & R-06 demo |

## 2) Strategic Directions

### A. Engine Module Refactoring
Goal: improve quality of migrated engine code after the first compile-rescue wave.
- [ ] A1. Refine engine modules to use the new foundation API more idiomatically
- [ ] A2. Remove temporary migration leftovers and compatibility-style code
- [ ] A3. Simplify and reduce engine-module dependencies

### B. Targeted Base Refactoring
Goal: continue selective Base improvements where they unlock cleaner engine code or remove remaining migration friction.
- [ ] B1. Identify small Base API gaps discovered during engine migration
- [ ] B2. Apply focused Base refactors with immediate engine adoption
- [ ] B3. Keep Base tracking/docs aligned when interfaces change

### C. Base Performance Optimization
Goal: improve Base implementation performance without changing public APIs.
- [ ] C1. Benchmark representative Base modules and hot paths
- [ ] C2. Identify bottlenecks and weak implementation points
- [ ] C3. Optimize internals while preserving existing APIs and behavior

### D. Architecture Changes
Goal: use the new foundation as a base for larger engine-level improvements.
- [ ] D1. Identify architecture areas now worth redesigning after migration
- [ ] D2. Implement changes incrementally with working-demo validation
- [ ] D3. Preserve compatibility where practical during transition

### E. Platform & Build
Goal: simple, reproducible builds on Delphi + FPC, Windows + Linux.
- [ ] E1. Unify build scripts for engine/demo/tests
- [ ] E2. CI smoke pipeline for key demos
- [ ] E3. Close known FPC/Linux compatibility gaps

### F. Core Runtime & Scenes
Goal: predictable scene lifecycle and transitions.
- [ ] F2. Safe scene transitions (including async loading)
- [ ] F3. Lifecycle diagnostics and error logging

### G. UI System
Goal: a modern and stable UI subsystem.
- [ ] G1. Core widgets with consistent behavior
- [ ] G2. Layout engine (adaptive behavior, alignment, spacing)
- [ ] G3. Testability of UI logic and events

### H. Graphics / Render
Goal: a robust 2D/3D render pipeline.
- [ ] H1. Shader pipeline stability and diagnostics
- [ ] H2. Reliable texture/shader/buffer resource lifecycle
- [ ] H3. Performance improvements on representative scenes

### I. Assets & Resource Management
Goal: transparent loading/unloading without leaks.
- [ ] I1. Allocation/free cycle control
- [ ] I2. Loading queues and priorities
- [ ] I3. Unified resource ownership rules

### J. Audio
Goal: predictable playback and control.
- [ ] J1. Backend behavior unification (BASS/SDL/IMX)
- [ ] J2. Playback/streaming diagnostics
- [ ] J3. Test scenarios for baseline audio use cases

### K. Networking
Goal: stable baseline networking capabilities.
- [ ] K1. TCP/HTTP baseline scenarios
- [ ] K2. Error handling/timeouts/retry behavior
- [ ] K3. Minimal integration tests

### L. Tooling & Developer Experience
Goal: fast "change -> verify -> commit" workflow.
- [ ] L1. Engine5 project template
- [ ] L2. Migration-path documentation (Engine4 -> Engine5)
- [ ] L3. Pre-release check suite

## 3) Feature Cards

### [R-01] Core OpenGL Pipeline Modernization
- Status: done
- Priority: P0
- Area: Render
- Value: Move Engine5 to a modern, debuggable, and maintainable OpenGL pipeline.
- Scope (MVP): remove compatibility-profile-only paths; switch draw paths to vertex/index buffers instead of RAM-fed data; ensure NSight frame debugging works on core scenes.
- Out of scope: adding non-OpenGL backends.
- Dependencies: `Apus.Engine.OpenGL`, `Apus.Engine.PainterGL2`, mesh/render data flow, demo coverage.
- Risks: hidden reliance on legacy fixed-function assumptions; regressions in old scenes/shaders.
- Acceptance Criteria:
  - [x] Main render path does not require compatibility profile APIs.
  - [x] Geometry submission uses GPU-side vertex/index buffers in targeted paths.
  - [x] At least one representative demo can be inspected in NSight with meaningful draw-call/resource visibility.
- Notes: includes replacing RAM-side immediate/legacy feeding where still present.
  - 2026-03-05: Stage 0-1 implemented (context request/actual API, GameApp toggle surface, platform signature migration, requested-vs-actual startup logging).
  - 2026-03-05: Mandatory rollout milestone reached: `SimpleDemo` runs on core profile in current Windows path.
  - 2026-03-05: Stage 7/8 baseline delivered: OpenGL debug callback/groups + GL object labels + dedicated `NSight` build config for `SimpleDemo`.
  - 2026-03-05: NSight runtime validation passed on `SimpleDemo` (capture works, textures are labeled, shader sources visible/editable).
  - 2026-03-06: Additional runtime confidence milestone: `demo/VertexBuffer` works (render mode switching + VSync toggle validated).

### [R-02] Multi-Window, Multi-Monitor, and Hot DPI-Awareness
- Status: in-progress
- Priority: P0
- Area: Platform
- Value: Enable modern desktop app behavior across displays and DPI changes without restart.
- Scope (MVP): support multiple windows; map windows to monitors; react to runtime DPI changes and re-layout/re-scale correctly.
- Out of scope: full per-platform native custom window chrome features.
- Dependencies: `Apus.Engine.WindowsPlatform`, `Apus.Engine.SDLplatform`, UI/layout scaling logic.
- Risks: platform-specific behavior divergence; input coordinate and scaling mismatches.
- Acceptance Criteria:
  - [x] Engine can create and manage more than one active window.
  - [ ] Window placement and fullscreen behavior work on multiple monitors.
  - [ ] Runtime DPI change triggers correct viewport/UI scaling without restart.
- Notes: hot DPI-awareness must be validated with monitor move and OS scale-change scenarios.
  - 2026-03-08: architecture draft and decisions v1 are documented in `Work/reports/R-02_multiwindow_plan.md`.
  - 2026-03-08: phase-1 implementation started (Windows path): `TWindow` abstraction extracted, API naming normalized, OpenGL context flow moved out of `Engine.API` into `Engine.OpenGL`.
  - 2026-03-09: implementation sequence updated to target-first (no temporary single-thread multi-window stage): next architectural step is `TWindowRuntime` as `window+thread` pair while keeping `TGame -> windows[]:TWindow` / `mainWindow` as the primary public model.
  - 2026-03-09: phase-1 foundation closed:
    - window-owned runtime state finalized in `TWindow`;
    - legacy runtime `game.*` proxies removed from `TGameBase`;
    - engine/demo active paths migrated to `window.*`;
    - `SimpleDemo` compile/run validation passed.
  - 2026-03-09: SDL `SimpleDemo` freeze investigation completed:
    - diagnostics confirmed stalls inside `SDL_PollEvent` cumulative time (not in engine event handlers/render path);
    - runtime SDL DLLs updated to `2.32.10` (`bin` and `bin64`);
    - user validation: freezes are gone, runtime is smooth;
    - follow-up: update Pascal SDL headers (currently `2.0.10`) to reduce version drift.
  - 2026-03-10: scene lifecycle refactored:
    - `TUIScene.Create` takes optional `wnd:TWindow` parameter (defaults to `mainWindow`);
    - scene uses `wnd.renderWidth/Height` and `wnd.AddScene` directly (no more `game.AddScene`);
    - `Initialize` renamed to `InitGfx` (GPU-only, automatic, never call manually);
    - scene lifecycle contracts documented in `Apus.Engine.Scene.pas`;
    - `MessageScene` fixed: UI creation moved to constructor, chicken-and-egg init bug resolved;
    - scene Load registration simplified (removed method pointer comparison hack).
  - 2026-03-11: AddWindow API scaffold implemented:
    - `TGameBase.AddWindow(settings) / AddWindow(title,w,h) / RemoveWindow(wnd)` — public API;
    - per-window render thread (`ExtraWindowLoop`) with own frame loop;
    - shared GL context via `wglCreateContextAttribsARB(DC, mainContext, attribs)`;
    - `RegisterClassW` idempotent; `TWindow.InitGraphShared` virtual abstract;
    - `demo/MultiWindow` updated to use the new API;
    - FPC compilation validated for all changed modules;
    - initial next blocker at that stage was per-thread render state (§3.7) and per-window VAO.
  - 2026-03-11: secondary-window rendering confirmed working in real run.
  - 2026-03-11: follow-up implementation landed for buffer API and explicit per-thread bootstrap (`InitThreadContext`) to reduce startup race surface.
  - 2026-03-11: multi-GPU decisions fixed for R-02:
    - if multiple GPUs are present, one GPU is considered primary and all rendering is executed on it;
    - multi-window path assumes shared context support, therefore resource duplication between windows is not required;
    - symmetrical multi-GPU collaborative rendering is out of native Engine5 scope.
  - 2026-03-14: runtime DPI-change fixes (current branch):
    - added lock-protected UI scale refresh in `UIScene` for `ENGINE\DPICHANGED\DONE`;
    - `GameApp` now re-applies high-DPI setup and reselects message fonts on DPI change;
    - `MessageScene` now reacts to DPI change by relayout of active dialog;
    - modal behavior restored for message boxes (`sweShowModal`), preventing interaction with underlying UI during modal display.
  - 2026-03-14: explicit follow-up scope added:
    - ensure **all engine-owned service scenes** (not only `MessageScene`) are fully scale-compliant;
    - required compliance domains: runtime DPI change and user UI scale;
    - normalize scene UI metrics/layout to scale-driven behavior and remove fixed-pixel assumptions where needed.
  - 2026-03-14: font handle architecture decision:
    - font handles for direct drawing stored as **threadvar** (each window thread has own set);
    - `game.SelectFonts(scale)` called from window thread on scale change → recalculates threadvar handles;
    - cross-thread font access intentionally unsupported (fail-fast via zero threadvar);
    - UI elements will NOT store font handles — fonts resolved by style system (see R-05).
  - 2026-03-14: `game.userScale` is global (not per-window); `actualScale = dpiScale * userScale`.
  - 2026-03-22: multi-window stability checkpoint:
    - global overlay invalidation and forced redraw path added for debug overlays;
    - extra-window overlay rendering path wired; extra-window stop centralized before `DoneGraph` to avoid shutdown AV/hang;
    - remaining known issue: in multi-window mode debug overlay refresh is still incorrect in main window (secondary updates correctly), deferred as active R-02 follow-up.

### [R-03] Native AEM Pipeline + Blender Export
- Status: planned
- Priority: P1
- Area: Resources
- Value: Make AEM the native high-performance path for models/animations, including compact shipping formats.
- Scope (MVP): finalize AEM model/animation capabilities for runtime use; define compact/ultra-compact encoding modes; provide Blender export plugin for direct AEM export.
- Out of scope: full DCC ecosystem support beyond Blender in first iteration.
- Dependencies: `Apus.Engine.AEMLoader`, asset tools, Blender plugin implementation and version compatibility.
- Risks: toolchain drift between runtime and exporter; compatibility/versioning of binary format.
- Acceptance Criteria:
  - [ ] Runtime supports target AEM model + animation feature set for at least one production-like asset.
  - [ ] Ultra-compact encoding mode is documented and loadable by engine.
  - [ ] Blender plugin exports valid AEM consumed by Engine5 without manual conversion.
- Notes: define AEM versioning strategy early to avoid exporter/runtime mismatch.
  - 2026-03-12: R-03 planning document created: `Work/reports/R-03_aem_pipeline_notes.md`.
  - 2026-03-12: pipeline direction fixed - only two engine loaders (`OBJ` baseline + `AEM` native); FBX/DAE converter removed from R-03 scope; Blender direct exporter is the target content path.

### [R-04] Robot Interaction Layer (MCP or File-Based Bridge)
- Status: done
- Priority: P1
- Area: Tooling
- Value: Enable structured interaction between Engine5 workspace and automation/robot agents.
- Scope (MVP): provide one stable protocol endpoint (MCP server or file-based request/response dialog) for controlled read/write operations.
- Out of scope: unrestricted remote execution layer in first version.
- Dependencies: security model, command schema, logging/audit trail.
- Risks: accidental unsafe operations; protocol complexity and maintenance burden.
- Acceptance Criteria:
  - [x] A robot client can request and receive structured responses for approved operations.
  - [x] All robot actions are logged and traceable.
  - [x] MVP safety policy defined (file-based local workflow; no unrestricted remote execution).
- Notes: start with a minimal command surface and grow incrementally.
  - 2026-03-06: file-based Robot API protocol implemented and validated on `SimpleDemo` and `01-Scenes`.
  - 2026-03-06: `ui.element` diagnostics upgraded for layout/DPI debugging (`HIERARCHY`, internal/effective visibility+enabled, live `globalRect`, optional `layout` block).
  - 2026-03-06: post-MVP `fps` diagnostics delivered:
    - high-precision per-frame timing (`frameTimeUs`);
    - optional ring-buffer history request (`N`) with repeated `FRAME_US` output.
  - 2026-03-06: next follow-up is practical profiling of SDL slowdown using the new `fps` telemetry.
  - Post-MVP follow-ups (non-blocking): stronger command-level safety gates/policy hardening, plus reliability fixes for edge-case shutdown flows.

### [R-05] CSS-Like UI Style System Completion
- Status: in-progress
- Priority: P1
- Area: UI
- Value: Make UI styling declarative, reusable, and maintainable via inherited text-defined styles.
- Scope (MVP): complete the current prototype into a usable CSS-like style layer with style inheritance, selector-like matching for core widgets, and deterministic conflict resolution.
- Out of scope: full web-CSS parity and advanced layout features not required by Engine5 UI.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UIScript`, widget/style binding points, serialization/parsing support.
- Risks: style precedence ambiguity; runtime overhead from style resolution; regressions in existing widget appearance.
- Acceptance Criteria:
  - [x] UI elements can resolve effective style from inherited text-defined style rules.
  - [x] Style priority/conflict behavior is documented and covered by baseline tests.
  - [x] Existing core widgets can be restyled without code changes in representative demo screens.
  - [ ] Style resolution is validated on real project screens (not only StyleDemo).
  - [ ] Resolver performance is profiled; caching added if needed.
  - [ ] Visual regression tests via Robot API `pixel` command cover baseline widget colors.
- Notes:
  - 2026-03-12: design and scope decisions consolidated in `Work/reports/R-05_notes.md`.
  - 2026-03-23: Phase 1+2 done — `TStyleBlock`, resolver, @refs, state blocks, patch; draw procedure migration; `StyleDemo` with 6 interactive examples.
  - 2026-03-24: Phase 3 done — transitions via `TTweening` (hover/pressed/disabled); `DrawCommonStyle`/`DrawUIScrollbar` migrated.
  - 2026-03-24: `font`/`color` fields removed from `TUIElement`; rendering via `StyleFont()`/`GetStyleColor()`.
  - 2026-03-24: `styleClass:byte` removed from `TUIElement`; `TUIFrame.Create` resolves via `GetUIStyle()`; `RegisterUIStyle`/`GetUIStyle` remain for game-specific custom drawers.
  - 2026-03-24: `TStyleCatalog` added — `Styles['name'] := 'color: ...;'` replaces procedural `RegisterNamedStyle`/`FindNamedStyle`; `Styles.Block('name')` for drawers.
  - 38/38 style unit tests pass on x86 and x64.
  - Follow-ups (post-MVP, non-blocking): `$varName` substitution via `Apus.Publics`; visual regression tests via Robot API `pixel` command.

### [R-06] 3D Material Pipeline: Normal Mapping (+ Optional Parallax/Occlusion)
- Status: idea
- Priority: P1
- Area: Render
- Value: Improve 3D visual quality with modern per-pixel surface detail while preserving practical performance.
- Scope (MVP): support normal maps in core 3D shading path for supported model/material formats; define optional extension path for parallax mapping and ambient occlusion inputs.
- Out of scope: full physically based rendering overhaul in the first iteration.
- Dependencies: `Apus.Engine.ShadersGL`, `Apus.Engine.Model3D`, `Apus.Engine.Mesh`, material/texture loading path.
- Risks: tangent-space consistency issues; shader complexity/performance regressions on lower-end GPUs; asset pipeline mismatch.
- Acceptance Criteria:
  - [ ] Normal mapping is available for target 3D model path with documented material inputs.
  - [ ] Tangent/bitangent handling is validated on representative assets.
  - [ ] Optional parallax/occlusion hooks are clearly defined (enabled where supported, safely ignored otherwise).
- Notes: design should keep compatibility with existing assets and allow gradual adoption.

### [R-07] Geometry Library Overhaul (Single-First + Spatial Primitives)
- Status: in-progress
- Priority: P1
- Area: Core
- Value: Make single-precision the default for game math; add spatial primitives and intersection/culling tests (DirectXMath-level coverage).
- Scope (MVP):
  - Milestone A (done): geometry/spatial baseline brought to working state and merged into `engine5`.
  - Milestone B (post-merge hardening): Linux compatibility fixes and verification.
  - Milestone C (post-merge performance): benchmark pass + prioritized SSE optimization for highest-impact hot paths.
  - Milestone D (post-merge support): continuous bugfix + test expansion loop.
  - Milestone E (adjacent cleanup): continue migration of remaining not-yet-migrated modules, including SDL-related paths.
- Out of scope: full broadphase physics engine or BVH/scene-graph; OBB and sweep tests (deferred to follow-up).
- Dependencies: `Base/Apus.Geom2D.pas`, `Base/Apus.Geom3D.pas`, render/scene modules for adoption.
- Risks: TVec3 12B vs 16B layout decision; breaking existing vertex layouts if aliased wrong; FPC vs Delphi ASM differences.
- Acceptance Criteria:
  - [x] R-07 baseline is working and merged into `engine5`.
  - [ ] Linux behavior is fixed and validated in target paths.
  - [ ] Benchmarks are executed and baseline deltas are recorded.
  - [ ] Highest-impact functions receive SSE optimization (with pure Pascal fallback where required).
  - [x] New/updated tests are added for discovered bugs during support work.
  - [ ] Remaining not-yet-migrated modules (including SDL-related paths) are migrated to the current foundation APIs.
- Notes:
  - Detailed plan: `Work/reports/R-07_geometry_library_plan.md`
  - TVec3 = 12B (storage-compatible), TVec4 = 16B (SSE computation) — DirectXMath model.
  - Keep API ergonomic for both gameplay queries and render-side visibility checks.
  - 2026-03-11: implementation plan finalized in `Work/reports/R-07_geometry_library_plan.md` (stages, type-size constraints, methods-first API, `Apus.Spatial` extraction).
  - 2026-03-13: R-07 reached working state and was merged into `engine5`.
  - 2026-03-13: post-merge track defined:
    - Linux behavior fixes and verification;
    - benchmark runs and baseline updates;
    - SSE optimization for highest-impact functions (with pure Pascal fallback where needed);
    - bugfixes on discovery with immediate test additions;
    - continue migration of remaining not-yet-migrated modules (including SDL-related paths).
  - 2026-03-23: support-track progress reflected in Base execution loop:
    - fixed `Apus.Tweenings` runtime defects (scalar recursion stack overflow and `duration=0` delayed retarget divide-by-zero);
    - added focused `TestTweenings` automated coverage;
    - added `BenchAnimation` (`TTweening` vs `TAnimatedValue`) and expanded timing benchmark coverage.

### [R-08] UI Hit-Test for Out-of-Bounds Children (Performance-Safe)
- Status: done
- Priority: P1
- Area: UI
- Value: Fix a real UX/input bug where child UI elements intentionally rendered outside parent bounds may not receive mouse input, while preserving high mouse-move performance.
- Scope (MVP): make hit-testing respect intentional non-clipping behavior for out-of-bounds child elements, without falling back to full UI tree traversal on each mouse move.
- Out of scope: full UI picking architecture rewrite; broad changes to rendering order model.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UITypes`, `Apus.Engine.UIScene`, clipping semantics (`clipChildren` / `parentClip`), root element ordering.
- Risks: regressions in modal/focus behavior; hidden coupling with existing `FindElementAt` recursion and clipping assumptions; accidental perf degradation on deep UI trees.
- Acceptance Criteria:
  - [x] A child element intentionally outside parent bounds and configured as non-clipped can receive hover/click input.
  - [x] Mouse move processing does not degrade to full-tree scan for common frames.
  - [x] Existing modal-window and z-order input behavior remains unchanged in representative UI demo flows.
  - [x] Add at least one focused test or reproducible scenario covering this case.
- Notes: Clip-threaded `FindElementAt` overload with `escapingOnly` mode for deep noParentClip descendants; `FindElementAt`/`FindAnyElementAt` unified as overloads. Verified via Ctrl+Alt+Win hover. UI demo carries §7 fixture (panel+popup, panel→mid→deep). Details: `Work/reports/R-08_hittest_overlay_notes.md`.

### [R-11] Headless/NOGFX Backend for CI UI Automation
- Status: idea
- Priority: P2
- Area: Platform
- Value: Enable automated UI/scene tests on CI runners without creating a native window, OpenGL context, or real GPU render path.
- Scope (MVP): add a headless platform + NoGfx backend that can run app/frame lifecycle, process synthetic input events, and verify UI behavior/state transitions in tests.
- Out of scope: full software rasterizer in MVP; pixel-perfect visual parity with hardware rendering.
- Dependencies: `Apus.Engine.GameApp`, platform abstraction (`ISystemPlatform`), graphics abstraction (`IGraphicsSystem`, `IDrawer`), UI input/event path (`Apus.Engine.UI*`, `Apus.Engine.UIScene`), CI scripts.
- Risks: hidden coupling between logic and GL calls; initialization paths that currently assume real render context; flaky async/timing behavior in test mode.
- Acceptance Criteria:
  - [ ] Engine can start and execute frames in headless mode without native window/OpenGL context.
  - [ ] Tests can inject synthetic mouse/keyboard input and observe deterministic UI state/event outcomes.
  - [ ] At least one representative GUI flow is validated in CI using headless mode.
  - [ ] Runtime mode is explicit and isolated (no accidental behavior change in normal graphics backends).
- Notes:
  - Recommended staged delivery:
    - Stage 1: NoGfx no-op backend + headless platform + controllable frame pump/time.
    - Stage 2: test helpers (`click`, `move`, `type`, `advanceFrames`) + baseline UI automation scenarios.
    - Stage 3 (optional): simplified CPU offscreen rendering/capture for layout/snapshot-oriented checks.

### [R-09] OpenGL Performance Modernization (Diagnose-First)
- Status: planned
- Priority: P1
- Area: Render
- Value: improve CPU/GPU efficiency and reduce driver overhead in real scenes — driven by measurement, not by speculative batching.
- Framing decision (2026-06-05): the engine's 2D path issues one draw call per primitive (`Apus.Engine.Draw`), while text/lines/particles already batch. An automatic 2D/UI sprite-batcher was considered and **deliberately deprioritized**: in real UI the batch is broken not only by `glScissor` clip changes (which are already lazy — see `TClippingAPI.Prepare`) but mainly by per-widget texture changes (neutral fill + glyph atlas + icon), so a naive batcher would shine in synthetic tests and do almost nothing on real screens. Conclusion: start from practical scenarios, find where it actually hurts, and prefer cheap, safe wins. Work split into four independent tracks.
- Out of scope: full renderer rewrite; hard requirement on latest GL-only GPUs; automatic UI sprite-batching (revisit only if Track A shows real pain on UI).

- **Track A — Telemetry & diagnosis (do this first):**
  - per-frame counters: draw calls, shader switches, texture binds, scissor/clip changes, uploaded vertices.
  - surface them in the debug overlay (`Apus.Engine.DebugOverlays`, Alt+1..9).
  - author runs NSight on representative real scenes (UI, a 3D demo, a sprite-heavy case if available) to locate the actual bottleneck before any optimization.
  - benchmark scenes must model realistic clip patterns (scrollable/nested containers, texture interleaving), not a flat sheet of identical sprites — otherwise the numbers lie.

- **Track B — Cheap redundant-state-change wins (low risk, helps every scene):**
  - `UploadStreamVertices`/`UploadStreamIndices` currently re-`glBindBuffer` the stream VBO/IBO unconditionally per `Draw`, although `boundArrayBuffer`/`boundElementArrayBuffer` tracking already exists — bind only on change (explicit TODOs already in `OpenGL.pas`).
  - `SetupAttributes` re-issues `glVertexAttribPointer` for every attribute on every `Draw` even when layout+buffer are unchanged — cache and skip.
  - `shader.Apply` per `Draw` — ensure a "current program == wanted" guard avoids redundant `glUseProgram`.
  - compat-path `DrawIndexed` unconditional unbind-to-zero (`OpenGL.pas` ~`:883`,`:923`) when the same buffer stays active.
  - these reduce CPU/driver overhead even on scenes that "already fly", with no change to draw semantics.

- **Track C — Opt-in manual sprite-batch API (for sprite games, not auto-magic):**
  - explicit `Begin/Add/End`-style batch under one texture+mode; caller guarantees no texture/clip change inside; flush as a single `DrawIndexed`.
  - predictable, no scissor heuristics; can build on existing `TVertexBuffer`/`TIndexBuffer` + `DrawIndexed`.
  - target: tilemaps, sprite fields (Spectromancer/Astral profile).
  - **Candidate shape: an opt-in auto-batch mode `draw.Batching(on/off)`** (discussed 2026-06-10). While on, the drawer coalesces same-signature primitives into a buffer and auto-flushes on a signature change — primitive type (LINE_LIST vs TRG_LIST), texture, or render state — and on `Batching(false)`. Pros: transparent call-site (no per-type Begin/End), **draw order preserved** (flush-on-type-change), generalizes across primitive types. Caveat: the drawer only sees state it owns (its own `UseTexture`, primitive type) — externally-changed state (`transform`/`target`/custom shader, set outside the drawer) keeps the **same contract as manual batching**: caller must `Batching(off/on)` or flush before changing it. Cost: a cheap per-primitive signature compare while on; zero overhead while off. This subsumes the existing `BeginLines/EndLines` and should cover **3D `Line3D` + `Triangle`**, not just textured sprites.
  - **Consumer: R-18 (DebugDraw)** relies on this — its `Begin3D`/`Flush` are designed to wrap `Batching(true/false)` so gizmo draws batch transparently once this lands. R-18 ships without it (per-primitive draws); this Track makes it cheap. Debug gizmo sessions are the easy case (constant neutral texture + state ⇒ near-perfect coalescing).

- **Track D — GL 4.x capability research (investigation, capability-gated + fallback):**
  - core profile currently uses GL essentially as "3.3 + VBO"; 4.3–4.6 features may both simplify code and cut overhead.
  - candidates: DSA (4.5, `glNamedBufferSubData`/`glCreateBuffers`) to remove bind-to-edit and bind churn (overlaps Track B); separate attribute format (4.3, `glVertexAttribFormat`+`glBindVertexBuffer`) to kill per-draw `glVertexAttribPointer`; persistent mapped buffers (4.4, `glBufferStorage` + `PERSISTENT|COHERENT`) for the stream path (also R-12); array/bindless textures to remove the texture-change barrier (enables Track C without atlasing); MultiDraw indirect (4.3) as advanced batching later.
  - deliverable: research note `Work/reports/R-09_gl4x_research.md` on which features give (a) code simplification, (b) measurable overhead reduction, with fallback strategy for ES/ARM/older GPUs. **This note is Opus-authored** (design reasoning, not mechanical execution).

- Dependencies: `Apus.Engine.OpenGL`, `Apus.Engine.Draw`, `Apus.Engine.DebugOverlays`, `Apus.Engine.ResManGL`, `Apus.Engine.ShadersGL`, runtime capability detection.
- Risks: synchronization bugs with persistent mapping; cross-driver behavior differences; complexity creep in draw API; over-engineering a problem that may not exist on real scenes (Track A guards against this).
- Acceptance Criteria:
  - [ ] Draw-call / state-change counters visible in the debug overlay.
  - [ ] NSight baseline captured on at least one representative real scene; bottleneck (if any) identified and documented.
  - [ ] Cheap redundant-state-change wins (Track B) applied where measurement justifies them; redundant binds flagged by NSight reduced.
  - [ ] Opt-in manual batch API available for sprite-heavy use cases (Track C), if a real use case warrants it.
  - [x] GL 4.x research note (Track D) produced with concrete recommendations and fallback strategy. (draft v1, 2026-06-05 — awaiting NSight baseline to confirm priorities)
- Notes:
  - Working in a branch off `engine5` in the main directory (no worktree); A/B via a runtime toggle inside the bench demo.
  - Documentation: working journal `Work/reports/R-09_notes.md` (single persistent state across context resets, all tracks; any model continues from it) + Opus-authored research note `Work/reports/R-09_gl4x_research.md` (Track D) + this roadmap card as top-level status.
  - Model split: Opus does design/decisions/Track-D research/NSight interpretation/Track-C API design; Sonnet executes spec'd work (Track-A counters, mechanical Track-B). Opus writes "what & why" into the journal → Sonnet executes a section in a fresh context → result back into the journal.
  - Track order (dependencies, not strictly sequential): A first (telemetry baseline) → D early/parallel (its findings shape how B is done) → B after A+D → C on demand.
  - 2026-06-05: reframed from "auto-batcher" to "diagnose-first, four tracks" after design discussion; Track D (GL 4.x research) added by author.
  - 2026-06-05: Tracks A (telemetry) + B (cheap state-change wins) done and merged into `engine5`. Track D research note drafted. Key finding: no cheap 4.x wins remain standalone — B already removed redundant state churn and `SetupAttributes` is cached; real per-draw cost is `glBufferSubData` stream sync. 4.x pays off only as part of R-12 (persistent ring-buffer streaming) + Track C (array-texture batching). **Next blocker: NSight baseline — author runs it; everything else waits on that data.**

### [R-10] UI Widget System Refactor (TUIElement Decomposition First)
- Status: done
- Priority: P0
- Area: UI
- Value: reduce UI core complexity and improve maintainability/testability by restructuring `TUIElement` and clarifying responsibilities across widget classes.
- Scope (MVP): analyze decomposition options for `TUIElement`; pick and implement the best option; review existing widget classes and define/execute targeted reorganization where needed.
- Out of scope: broad new widget/layout expansion before core decomposition and class reorganization are complete.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UIWidgets`, `Apus.Engine.UITypes`, scene/UI integration points.
- Risks: behavioral regressions in event flow/focus/layout; migration churn across many widget descendants; temporary API instability during split.
- Acceptance Criteria:
  - [x] At least 2-3 decomposition variants for `TUIElement` are documented with trade-offs.
  - [x] One selected decomposition approach is implemented in engine code with preserved baseline UI behavior on representative screens.
  - [x] Widget class review is completed, with concrete reorganization actions implemented (or explicitly deferred with rationale).
  - [x] Follow-up backlog for widget/layout expansion and test coverage is created and prioritized.
- Notes:
  - 2026-03-08: implementation stages and execution plan documented in `Work/reports/R-10_ui_widget_refactor_plan.md`.
  - 2026-03-08: decomposition research report documented in `Work/reports/R-10_tuielement_decomposition_report_2026-03-08.md`.
  - 2026-03-10: styling/drawer direction agreed (kept out of R-02 scope, tracked under R-10):
    - replace per-element draw procedure idea with drawer object contract (`draw + style apply/parse`);
    - drawer resolution is inherited: current element -> parents -> root -> fallback to `DefaultDrawer`;
    - no resolver cache for now (keep path simple; reassess only if profiling shows real cost);
    - replace `styleInfo` with `style:String8` property;
    - `style` write path should call external style service (or drawer) to parse/update internal drawable state.
  - Open design question to close in R-10:
    - style syntax policy: fully shared grammar for all drawers vs shared base grammar + drawer-specific extensions.
  - 2026-03-14: widget construction pattern decided:
    - minimal constructor: `Create(width, height, parent, name)` — name stays mandatory;
    - widget-specific init via `.Setup(...)` method (returns concrete type, can have overloads);
    - then chainable base setters (SetPos, SetAnchors, etc.) from TUIElement;
    - example: `TUIComboBox.Create(80,24,toolbar,'ScaleCombo').Setup(font, items).SetAnchors(1,0,1,0).SetPos(100,6,pivotTopRight);`
    - old multi-param constructors: deprecate gradually, remove after migration.
  - 2026-03-19: TUIElement slimmed down (branch feature/r-05):
    - `hintIfDisabled`, `hintDelay`, `hintDuration` → `attributes.Item[]` (Conv.ToInt/ToStr);
    - `scrollerH`, `scrollerV`, `childrenBound` → new `TUIScrollable` subclass; `TUIImage`, `TUIListBox` inherit it;
    - `TUIScrollBar.Link` now takes `TUIScrollable` (explicit contract);
    - `tag`, `customPtr`, `linkedValue` removed; `TUIButton.linkedPressed:PBoolean` added (typed);
    - `placementMode` moved next to `anchors` (logical grouping);
    - methods split into 10 named sections; field comments translated to English;
    - `IsChild` removed (duplicate of `HasChild`); `HasParent`/`HasChild` made strict.
  - Widget class review in progress (2026-03-19):
    - `TUIFlexControl` — dead class, nobody inherits; to remove;
    - `TUIEditBox.noBorder` — deprecated field; to remove;
    - `onClick:TProcedure` vs `onClickEvent:String8` in TUIButton — design question open;
    - ListBox color fields (`bgColor` etc.) — R-05 target (style pipeline).
  - 2026-03-20: widget refactor wave 2 (branch feature/r-05):
    - `TUIShape` unified: `TElementShape` enum + `shapeRegion` field replaced by single `TUIShape` type;
    - `TUIFlexControl` removed (dead class, no descendants);
    - `onClick` threading hack replaced with explicit `onClick:TProcedure` (main thread) + `onClickAsync:TProcedure` (any thread);
    - `TUIToggleButton` extracted: toggle/switch/radio logic moved out of `TUIButton`; `TButtonStyle` enum and `group` field removed from `TUIButton`; `TUICheckBox`/`TUIRadioButton` now inherit from `TUIToggleButton`; plan in `Work/reports/R-10b_switch_button_plan.md`;
    - `TUISkinnedWindow` merged into `TUIWindow` (was empty subclass distinction);
    - `TScrollBar` orientation made explicit via constructor parameter (was implicit from size);
    - widget constructors standardized, UI constants renamed, dead code removed;
    - widget interface comments fully translated to English;
    - `BeginChildren`/`EndChildren` pattern analyzed and documented in `Work/reports/ui_building_patterns.md` (thread-local parent stack; zero-variable UI tree construction); implementation deferred.
  - Acceptance criteria status (2026-03-20):
    - follow-up backlog captured in R-14 card (added 2026-03-20) ✓
    - widget class review: substantially complete; open items deferred to R-05 (ListBox colors) or low-priority (`noBorder`).
  - 2026-03-24: R-05 done — all R-10 open widget visual items (ListBox color fields, font/color in TUIElement) resolved through the style pipeline. R-10 closed.
  - Main scope (this task):
    - decomposition options study for `TUIElement`;
    - select best option and implement it;
    - review widget classes and plan/implement reorganization.
  - Follow-ups (after main scope):
    - expand widget/layout set where gaps remain;
    - add focused tests for widgets and layouts.

### [R-12] Graphics Subsystem Optimizations (Text + Streaming Buffers)
- Status: planned
- Priority: P1
- Area: Render
- Value: reduce CPU overhead in graphics hot paths, especially text-heavy UI and transient dynamic geometry updates.
- Scope (MVP):
  - explicit text-draw policy where persistent strings can reuse cached vertex buffers and transient strings keep cheap one-shot behavior;
  - deterministic invalidation when glyph cache/font atlas changes;
  - ring-buffer based transient streaming path for high-frequency text/UI vertex updates;
  - public unified `IRingBuffer` interface with concrete methods for reuse by all engine subsystems that need transient geometry uploads.
- Out of scope: full text layout/shaping rewrite; replacing existing glyph cache implementation; renderer rewrite.
- Dependencies: text draw path (`txt.write` call chain), font/glyph cache internals, render buffer lifecycle in OpenGL backend, draw/transient buffer integration points.
- Risks: stale cached geometry after atlas rebuild; VRAM growth from many persistent labels; API ambiguity if policy is not obvious to caller; incorrect overflow behavior in transient streaming path.
- Acceptance Criteria:
  - [ ] Repeated persistent labels reuse previously built geometry (no per-frame full rebuild in steady state).
  - [ ] Transient labels remain supported without forcing long-lived cache allocations.
  - [ ] Glyph cache invalidation reliably invalidates dependent text vertex buffers.
  - [ ] Ring-buffer ownership/lifecycle is explicitly defined and implemented.
  - [ ] Public `IRingBuffer` interface is implemented and used as the common transient streaming contract (not ad-hoc per-module wrappers).
  - [ ] Ring-buffer overflow behavior is deterministic and documented.
  - [ ] Profiling on one representative UI/demo scene shows measurable CPU reduction in text rendering hot path.
- Notes:
  - Existing hint flag can remain as a compatibility bridge, but API clarity should improve by splitting intent at call site.
  - Candidate API direction:
    - keep `txt.write(...)` as transient/default path;
    - add explicit persistent path (for example `txt.writePersistent(...)`) that returns/uses a handle;
    - optional helper for one-frame batching (`txt.writeTransient(...)`) if we want fully explicit semantics.
  - Suggested cache-key dimensions for persistent geometry:
    - text content/hash;
    - font face/size/style + shader-relevant render params;
    - layout inputs (wrap width, alignment, spacing, scale, DPI domain).
  - Invalidation strategy:
    - maintain `glyphCacheRevision` (or equivalent generation counter);
    - each persistent text buffer stores the generation it was built against;
    - on mismatch, rebuild lazily on next draw and refresh generation.
  - Resource policy:
    - keep a bounded LRU pool for persistent text buffers;
    - allow explicit release for known-dead labels;
    - record lightweight telemetry (hits/misses/rebuilds/evictions) to tune thresholds.
  - Transient/ring buffer ownership and lifecycle (MVP):
    - allocator object is per render thread/context;
    - internal streaming buffers are allocated in `InitThreadContext` (fallback: deterministic first-use init if thread bootstrap was skipped);
    - allocator resets per frame and is destroyed on thread/context shutdown.
  - Ring-buffer capacity strategy (MVP):
    - define initial capacity per thread;
    - allow bounded growth up to configured max;
    - track high-water mark in telemetry.
  - Overflow strategy (MVP):
    - orphan-on-overflow for OpenGL path (`glBufferData(..., nil, usage)` + upload new chunk);
    - follow-up option: multi-segment ring allocator for extreme burst workloads.
  - Required public API contract (MVP):
```pascal
type
  IRingBuffer=interface
    // Frame lifecycle
    procedure BeginFrame(frameId:uint64);
    procedure EndFrame;
    procedure ResetFrame;

    // Allocation for transient geometry
    function AllocVertices(layout:TVertexLayout;vertexCount:integer;out baseVertex:integer):pointer;
    function AllocIndices(indexCount:integer;indexSize:integer;out baseIndex:integer):pointer;

    // Upload/sync boundary for current frame chunk(s)
    procedure Commit;

    // Diagnostics/capacity
    function CapacityBytes:integer;
    function UsedBytes:integer;
    function HighWatermarkBytes:integer;
  end;
```


### [R-14] UI Widget Expansion (New Components + Module Organization)
- Status: idea
- Priority: P1
- Area: UI
- Value: Extend the engine UI toolkit with commonly needed widgets that are absent or only available via ad-hoc custom code (e.g. TweakScene sliders), and establish a scalable module organization strategy for growing widget surface.
- Scope (MVP):
  - New widgets (priority order):
    1. **TUIProgressBar** — simple display-only bar (value, min, max, fill direction); no interaction
    2. **TUISection** — collapsing/expanding section header; click toggles children visibility; arrow indicator
    3. **TUINumericField** — Blender-style combined display+input: shows value as text, fill bar behind it shows relative position in range; LMB drag changes value, click enters keyboard edit mode
    4. **TUITabControl** — tab strip + content area; switching tabs shows/hides child panels
    5. **TUIMenu** — menu bar (top-level items) + popup/context menus (nested submenus, keyboard nav, auto-close on outside click)
    6. **TUISpinner** — numeric EditBox with ▲▼ step buttons (fallback when NumericField is not enough)
    7. **TUITreeView** — hierarchical list with expand/collapse nodes
    8. **TUIColorPicker** — composite color selection control (own module due to complexity)
    9. **TUIFileDialog** — modal dialog for file open/save (own module due to complexity)
  - Label/button enhancements:
    - **Icon support** — embed icons (texture region or glyph) alongside text in TUILabel, TUIButton, hints; layout: icon+text with configurable gap and alignment
    - **Clickable labels** — TUILabel with optional link-style click behavior (already partially implemented; needs standardization)
    - **Text copy** — Ctrl+C on a focused static label copies its text to clipboard; opt-in per element
  - Module organization strategy:
    - **UIWidgets.pas** — primitives that do not instantiate other widget types internally (Label, Button, Toggle, CheckBox, Radio, EditBox, ScrollBar, ProgressBar, NumericField, Splitter, Frame, Image)
    - **UIComposite.pas** — medium-complexity composite widgets that own internal child widgets (ListBox, ComboBox, Window, GroupBox, Section, TabControl, Spinner, TreeView, Menu)
    - **UIColorPicker.pas** — standalone module; complex, optional dependency
    - **UIFileDialog.pas** — standalone module; OS-tier complexity, optional dependency
    - `Apus.Engine.UI.pas` re-exports all three tiers so callers need no extra `uses`
- Out of scope: animation/transition effects for Section; TreeView drag-drop; ColorPicker alpha editing in MVP; full OS-native FileDialog wrapper (custom UI dialog only); rich-text label with mixed fonts/colors (separate task).
- Dependencies: `Apus.Engine.UIWidgets`, `Apus.Engine.UITypes`, `Apus.Engine.UILayout`, layout system (TGridLayout, TRowLayout), clipboard API, R-05 style pipeline for visual polish.
- Risks: TUINumericField drag behavior may conflict with scroll/pan on touch targets; TreeView virtual-scroll for large datasets is a non-trivial follow-up; module split may require moving ListBox/ComboBox out of UIWidgets.pas (existing code churn); popup menu z-order and focus stealing need careful design.
- Acceptance Criteria:
  - [ ] TUIProgressBar implemented and usable as a standalone display widget.
  - [ ] TUISection toggles child visibility with visual indicator.
  - [ ] TUINumericField supports drag-to-change and click-to-type for float/int values.
  - [ ] TUITabControl switches visible content panel via tab strip.
  - [ ] TUIMenu supports at least one level of popup submenu and keyboard navigation.
  - [ ] TUILabel and TUIButton accept an optional icon (texture region) rendered beside text.
  - [ ] Ctrl+C on an opt-in static label copies caption text to clipboard.
  - [ ] UIComposite.pas introduced as a second widget module; UIWidgets.pas split along primitive/composite boundary.
  - [ ] UIColorPicker.pas added as optional standalone module.
  - [ ] All new widgets follow the `Create(w,h,parent,name).Setup(...).SetPos(...).SetAnchors(...)` construction pattern.
  - [ ] At least one demo or TweakScene updated to use new widgets.
- Notes:
  - TUINumericField is the most strategically interesting widget: it would replace the custom sliders already in TweakScene and make parameter tweaking ergonomic without dedicated slider tracks.
  - TUIProgressBar priority raised above other widgets: simplest to implement, frequently needed (loading screens, health bars, progress indication).
  - Blender numeric field is the reference UX for TUINumericField: compact, precise, no wasted space.
  - TUIMenu popup must handle z-order correctly (render above all other UI) and auto-dismiss on Escape or outside click.
  - Icon support design question: icon as texture handle + source rect, or as glyph index from icon font? Both paths may be needed.
  - Text copy from labels: needs focus model adjustment (static labels are currently not focusable).
  - Module split criterion: a widget is "composite" if it internally calls `Create` on another widget class. Primitives compose only via TUIElement children set by caller.
  - 2026-03-20: card created; widget list and module strategy drafted in planning discussion.
  - 2026-03-20: added menus, icon support, clickable/copyable labels to scope.

### [R-15] Demo Suite Restructuring
- Status: in-progress
- Priority: P1
- Area: Tooling
- Value: Provide a coherent, progressive demo suite that serves as onboarding path, API reference, and test base for CI/Robot validation.
- Scope (MVP):
  - Reorganize demos into 3-tier structure: `1-start/`, `2-features/`, `3-advanced/`
  - Create new demos: HelloEngine, Text (highest priority — biggest current gap)
  - Merge redundant demos: Input (InputDemo+ControllerDemo), Platform (MultiWindow+UIScaleDPI+Borderless), AdvancedGfx (AdvTex+ShadowMap)
  - Absorb Draw2D cases from NinePatch and EngineTest; absorb text cases from EngineTest into Text demo
  - Rewrite SoundDemo as GUI application
  - Remove SimpleDemo (replaced by HelloEngine) and EngineTest (distributed) after migration
  - New demos created when dependencies are ready: Styles (R-05), Resources, Network (K)
- Out of scope: rewriting performance demos (Particles, Billboards, VertexBuffer) — move as-is.
- Dependencies: R-02 (for Platform demo), R-05 (for Styles demo), section K (for Network demo).
- Risks: EngineTest distribution requires careful case-by-case review to avoid losing coverage.
- Acceptance Criteria:
  - [x] New standalone diagnostic/showcase demos (`InputDemo`, `Draw2D`, `TextDemo`) are created and integrated into demo build flow.
  - [ ] Directory structure matches target layout (`1-start/`, `2-features/`, `3-advanced/`)
  - [ ] HelloEngine demo created and working
  - [ ] Text demo created with font/Unicode/formatting showcase
  - [ ] Draw2D absorbs NinePatch and relevant EngineTest cases
  - [ ] Input demo merges keyboard/mouse (InputDemo) and gamepad (ControllerDemo)
  - [ ] Platform demo merges multi-window, DPI, and borderless demos
  - [ ] AdvancedGfx demo merges AdvTex and ShadowMap
  - [ ] SoundDemo rewritten as GUI app
  - [ ] EngineTest fully distributed and removed
  - [ ] All demos compile with FPC and Delphi
  - [ ] CI can build all demos in the new structure
- Notes:
  - Full plan with migration map: `demo/demo_plan.md`
  - Current inventory: `demo/demo_inventory.md`
  - 2026-03-22: plan created and agreed.
  - 2026-03-20: created and integrated `demo/InputDemo` (input diagnostics focus).
  - 2026-03-20: created and integrated `demo/Draw2D` (modernized 2D primitive showcase).
  - Added and integrated `demo/TextDemo` (text rendering/formatting showcase).

### [R-17] 3D Game Architecture Probe (Skeleton-First)
- Status: idea
- Priority: P1
- Area: Render / Core (architecture)
- Value: No real 3D game has ever been built on this engine. All current 3D demos are bottom-up, per-subsystem showcases that each set global render state imperatively and never compose. The valuable architecture feedback lives in the *seams between subsystems* (multi-pass, camera management, materials, scene traversal, post-processing), which no isolated demo exercises. This card builds a top-down **integrated 3D skeleton** whose explicit purpose is to discover where the engine resists a typical 3D-game structure — the "white spots" — before committing to features like R-06 or a real game.
- Deliverable type: this is an **architecture probe / reference application**, not a user-facing showcase demo. It does not belong in R-15's per-subsystem demo suite. Output is (a) a working structural skeleton and (b) a findings report driving new API/architecture cards.
- Long-term (dual purpose): the same scaffold can grow into a visually polished engine showcase. **Two distinct kinds of "beauty" must not be confused:** (1) *architectural* beauty — adding an abstraction for tidiness — is rejected at all times (must earn its place at the call site); (2) *visual* beauty — pretty rendering — is a **showcase-phase** concern, not needed during the probe, where placeholder boxes suffice. Order: probe first → showcase later.
- Guiding principle (author, 2026-06-05): new entities must be introduced **only when they demonstrably simplify the calling code versus not having them**. The entities below are **hypotheses to test, not a checklist to implement**. The probe builds the skeleton the simplest way that works and lets abstractions earn their place by removing concrete pain.
- Scale caveat: with 3 objects and one pass, inline always wins. Pain only appears at realistic multiplicity (many objects, several passes, transparent sorting, several distinct materials). The probe must deliberately reach that scale — otherwise the comparison lies.
- Scope (MVP — a skeleton built simplest-first):
  - render a 3D scene with **realistic multiplicity**: enough objects, ≥2 passes (e.g. depth/shadow + opaque, ideally + transparent), and ≥2 distinct materials;
  - start fully inline (imperative `transform`/`shader`/`SetObj;Draw`), exactly as current demos do;
  - then, **only where the inline form actually hurts**, try the minimal abstraction — candidate hypotheses in rough likelihood order: renderable list, camera object, pass list, material bundle, post-process fullscreen pass;
  - keep an abstraction **only if the call site gets simpler**; otherwise leave inline;
  - placeholder content is fine (boxes/spheres); the point is structure pressure, not art.
- Candidate showcase features (for seam coverage, NOT a build-everything mandate): multiple light sources (material/shader pressure), water (reflection RT + second camera), terrain (LOD + frustum culling at scale), sky (background pass, draw order), rain/snow (3D particles, instancing), volumetric fog (post-process, screen-space). First two picks: **multiple lights + water** (hit material and multi-camera/RT — biggest white spots).
- Out of scope: a real game; full PBR; deferred/G-buffer rendering (MRT) beyond noting the gap; committing to final public API in this card; introducing any entity purely for architectural tidiness.
- Dependencies: `Apus.Engine.API` (`ITransformation`, `IShader`, `IRenderTarget`, `gfx.BeginPaint/EndPaint`), `Apus.Engine.Scene`, `Apus.Engine.Mesh`/`Model3D`, `Apus.Geom3D`, `Apus.Spatial` (R-07), `Apus.Engine.ShadersGL`. Informs: R-06, R-03, R-09/R-12.
- Risks: scope creep into actually building a renderer; probe may reveal subsystems needing new retained-mode concepts (that's the *point*, but report them as separate cards, don't implement here).
- Acceptance Criteria:
  - [ ] Skeleton renders a multi-pass 3D scene at realistic multiplicity (multiple objects, ≥2 passes, ≥2 materials, an offscreen target composited to backbuffer), coexisting with a UI scene on top.
  - [ ] Skeleton is first written fully inline, so the "no-abstraction" baseline is real and measurable.
  - [ ] For each candidate entity: a verdict recorded — **adopted** (with the concrete call-site simplification it bought) or **rejected/deferred** (inline stayed simpler), with reasoning.
  - [ ] Findings report enumerates each point where the engine forced a drop to raw GL, global-state juggling, or duplicated logic — each tagged as a new-abstraction card or "fine inline, leave it."
- Notes:
  - 2026-06-05: card created after design discussion. Seam audit performed:
    - **No retained-mode 3D types exist anywhere**: no `TCamera`, `TMaterial`, `TRenderPass`, `TFramebuffer`, `TSceneGraph`/`TSceneNode`, no post-process concept.
    - Camera = imperative `transform.SetCamera()`+`transform.Perspective()` overwriting single global state each frame (`ShadowMap` sets light "camera" then main camera sequentially).
    - Multi-pass = hand-coded inline in `Scene.Render`; objects branch on a `mainPass:boolean` flag.
    - Material = global mutable shader state (`shader.Material`+`AmbientLight`+`DirectLight`) set before each `Draw`; `shader.Material` is even commented "has no effect" in `demo/Simple3D`.
    - No scene graph / renderable list: objects drawn via imperative `transform.SetObj(...); mesh.Draw;` sequences.
    - Render-to-texture already works (`gfx.BeginPaint/EndPaint` + `IRenderTarget`, shadow map proves it); gaps: no MRT/named framebuffer, no ping-pong pair for post chains.
    - 3D currently lives inside a `TUIScene.Render`; render/cull/blend state is global imperative and must be manually restored — a real state-leak hazard.
  - Conclusion: engine is a 2D immediate-mode painter with 3D primitives bolted onto global services (`transform`, `shader`, `gfx.target`); no retained-mode 3D scene concepts exist. That is precisely the white-spot region this probe targets.

### [R-18] Debug Draw Primitives (3D Gizmos)
- Status: planned
- Priority: P2
- Area: Render / Tooling
- Value: Provide ready-made debug/visualization primitives (axes, arrows, grid, box, sphere, capsule) so debugging 3D code does not require hand-rolling line/triangle gizmos every time (as `demo/NormalMap` currently does in `DrawGrid`). A reusable, self-contained helper that does not depend on scene lighting or the app's shaders.
- Origin: split out of the R-06 follow-up plan (`Work/reports/R-06_followup_plan.md`, task 3). Explicitly **not** R-06 core — general-engine helper; R-06's NormalMap demo is just the first consumer. Matches the long-deferred idea in `memory/idea_debug_draw_helpers.md`.
- Scope (MVP):
  - New module `Apus.Engine.DebugDraw.pas` exposing a `DebugDraw` record-namespace ({$SCOPEDENUMS ON}); **`IDrawer`/`TDrawer` interface is not modified** — the module sits over `draw.*` + `Apus.Engine.API` globals.
  - **Solid is the primary mode** (filled triangles): `Arrow3D` (cylinder shaft + cone head), `Axes` (3 solid arrows, X=red/Y=green/Z=blue), `Box` (solid AABB), `Sphere` (UV-tessellated), `Capsule` (cylinder + 2 hemispheres).
  - **Line/wireframe is the exception**, only where solid is meaningless: `Grid`, `Arrow2D` (flat arrow), `BoxWire` (AABB outline, e.g. for bounding-box visualization), and a `Line` primitive.
  - **Immediate lifetime**: a `Begin3D`/`Flush` session draws in the current frame; no retained queue / no render-loop hook (a retained+duration mode is a possible later extension, not built now).
  - **No batching in this card — relies on R-09.** `DebugDraw` draws via plain `draw.Line3D`/`draw.Triangle` (one draw call per primitive — acceptable for debug, not a hot path). `Line3D`/`Triangle` are currently un-batched; efficient 3D line/triangle batching is a non-trivial drawer-level facility (texture/state-change detection, auto-flush, call-site contract) **deferred to R-09 (Track C / auto `Batching(on/off)`)**. `Begin3D`/`Flush` are the seam where R-09's `draw.Batching(true/false)` will later slot in **transparently** — shape code is already a stream of `draw.*` calls, so it needs no rewrite when batching lands. `TDrawer` is **not** modified by this card.
  - **Module-baked lighting** (decided): solid shapes are shaded by the module's own `ambient + directional` light (configurable via `SetLight`), baked into vertex color **at emit using the world-space normal** (so lighting stays world-stable under rotation); flat shading for Box/Arrow3D/Axes, smooth for Sphere/Capsule. Keeps the unlit `TVertex.layoutTex` path and `shader.LightOff` — no shader/GL changes. (Alternative: a lighting shader mode requiring normals in the vertex format — deferred, only if shapes ever go high-poly.)
  - **Showcase/test demo** `demo/DebugDraw`: a 3D scene exercising every primitive (axes, grid, arrows 2D/3D, box solid+wire, sphere, capsule) under a rotating camera, with toggles for the baked-light direction — doubles as the manual test surface and the visual reference. (Fits R-15's `2-features` tier; coordinate placement with R-15.)
- Out of scope: 3D line/triangle batching in `TDrawer` (deferred to R-09); retained debug-draw queue with per-shape duration; oriented (matrix) box `BoxM`; translucent/sorted solids; real shader-based lighting with normals in the vertex format; reusable cached GPU meshes (those are the primitive generators of R-20, not this card).
- Dependencies: `Apus.Engine.Draw` (`draw.Line3D`/`draw.Triangle`), `Apus.Engine.API` (`draw`/`shader`/`transform`/`gfx`), `Apus.Geom3D` (`TVec3` + basis from an axis). Independent of R-19 (mesh rework). Soft dependency on R-09 for batching (R-18 is functionally complete without it; R-09 only makes it cheaper).
- Risks: unlit solids looking flat without the baked-shade step (mitigated by the world-normal shade); per-frame CPU shading of cached sphere/capsule (trivial at debug vertex counts); per-primitive draw calls until R-09 batching lands (acceptable at debug frequency); keeping depth/overlay behavior matching the current `DrawGrid`.
- Acceptance Criteria:
  - [ ] `Apus.Engine.DebugDraw` provides the solid set (`Arrow3D`, `Axes`, `Box`, `Sphere`, `Capsule`) and the line set (`Grid`, `Arrow2D`, `BoxWire`, `Line`) without modifying `IDrawer`/`TDrawer`.
  - [ ] Solid shapes are readable in 3D via module-baked `ambient + directional` lighting (world-normal shade at emit), independent of scene lighting/shaders; light is configurable via `SetLight`.
  - [ ] `demo/NormalMap` `DrawGrid` is ported onto `DebugDraw` with equivalent visuals (visual-parity validation).
  - [ ] `demo/DebugDraw` showcases every primitive and is integrated into the demo build flow.
  - [ ] Module compiles under FPC (and Delphi) on Win/Linux.
- Notes:
  - Full task plan + decisions: `Work/reports/R-06_task_debug_shapes.md`.
  - Cross-link: batching of `draw.Line3D`/`draw.Triangle` belongs to **R-09 Track C** (auto `Batching(on/off)` facility). R-18 leaves `Begin3D`/`Flush` as the integration seam so it picks up batching transparently once R-09 ships it.
  - Staged plan: (1) module scaffold + session + light config/shade helper → (2) line primitives → (3) solid primitives (Sphere/Capsule with lazy unit-shape cache) → (4) `demo/DebugDraw` showcase + port NormalMap `DrawGrid` → (5) FPC smoke test.
  - 2026-06-10: card created; key decisions locked (solid-primary, immediate lifetime, module-baked lighting, batching deferred to R-09).

### [R-19] Mesh Representation Unification, Refactoring & Rework
- Status: done at the re-bound geometry-level scope (2026-06-12), merged to `engine5`. B1–B4 + stage-C geometry closeout all DONE, headless gates pass, `demo/MeshLab` author-validated. Remaining mesh work (TModel/AEM, GPU-skin/instancing, `Mesh3D`→`Mesh` rename + legacy-consumer migration, IQM drop, OBJ-loader consolidation) moved OUT to **R-03** / a deferred migration — see scope-lock note below. Generators carved out to **R-20**.
- Priority: P1
- Area: Render / 3D Core
- Value: Give the engine one solid mesh foundation that carries arbitrary vertex attributes (tangents, bone weights/indices, wind weights, morph data) instead of two unrelated representations. Today `TMesh` (interleaved, layout-based, no bones/parts) and `TModel3D` (fixed SoA, 2-bone skinning, multi-part, 64K cap) don't share code; tangents and custom attributes have nowhere to live in the animated path. This blocks the AEM loader (R-03) from having a durable base and forces demos to reinvent mesh code (`demo/NormalMap` carries its own `TVertexNM`/`TDemoMesh`).
- Origin: task 1 of the R-06 follow-up plan (`Work/reports/R-06_followup_plan.md`). General-engine/foundation work, not R-06 core; R-06's normal mapping is the first consumer (needs tangent write-API). Gates R-06 follow-up task 2 (`ComputeTangents`) and underpins R-03 (AEM).
- Design DECISION (LOCKED 2026-06-12, Claude+Codex+author consensus) — authoritative spec: `Work/reports/R-19_mesh_design.md` (read this first); discussion archive `Work/reports/R-19_mesh_workflow_brainstorm.md`. Decisions: CPU mesh = **SoA typed arrays** (pointer-free), interleaving is upload-only; **layout is GPU-only** (`TGpuLayout`, immutable, interned by content-hash, compared by id; locations derived from a stable semantic→location table, not stored). `TMesh` = CPU SoA **triangle-list only** (no primitiveType; wireframe = polygon-mode, lines/points = R-18 batch). `TGpuMesh` = explicit retained upload (gather+format-encode, per-stream VBO, uint16/uint32 IBO chosen at upload by maxIndex, `muDiscardCPUCopy`). Geometric `TMeshSection` (range+name) lives in mesh; material set lives in model/instance. CPU indices always `array of integer`. GPU-skin is target (joints/weights as attrs loc 6/7), CPU-skin = valid dynamic-stream fallback. Instancing first-class (attr loc 8–13 or buffer-based via gl_InstanceID). Generators/ops in separate modules (`MeshShapes`/`MeshOps`).
- Backend reality: attribute binding lives in `TRenderDevice.SetupAttributes`/`ProcessLayout` (`Apus.Engine.OpenGL.pas`), driven by the closed 28-bit layout (slots pos/normal/color/uv1/uv2/tangent; tangent already binds via slot-5 vec3 branch, `extra4` does not). Locations are compact/sequential (matches stock shader generator, fragile for hand-written fixed-location shaders). Core profile binds attribute offsets in one `ARRAY_BUFFER`. The 2D/UI fast path (`PainterGL2`, hardcoded locs 0/1/2) is separate and untouched. S3/L2 rework is localized to three points: `TVertexLayout`, `SetupAttributes/ProcessLayout`, `ShadersGL` location generator.
- Scope — staged:
  - **Etap A (LOCKED 2026-06-10, narrowed same day; no GL change) — DONE 2026-06-10:** `TMesh` tangent/extra **write-API only** (`SetTangent`/`SetExtra`/`GetTangent`/`GetExtra` by vertex index + `AddVertex(pos,norm,tangent,uv,color)` overload). **Primitive generators excluded** — `TMesh` stays a data container + basic fill-API; quad/torus/sphere and tangent-extension of cube/cylinder move to a separate shape-generator module (user decision: the mesh is already complex). Tangent convention: store `T` along `+U`, bitangent `= cross(T,N)` in shader, no handedness sign yet. Acceptance = demo port, deferred until the generator module exists.
  - **B1 (DONE 2026-06-12) — pure CPU:** `TGpuLayout` interned descriptor (`Apus.Engine.GpuLayout`) + stable semantic→location table (`MeshSemanticLocation`, single source of truth for binder & shader-gen). Headless gate `tests/TestGpuLayout.dpr` (26 checks).
  - **B2 (DONE 2026-06-12) — pure CPU:** SoA `TMesh` container (transitional unit `Apus.Engine.Mesh3D`, becomes `Apus.Engine.Mesh` in stage C) + build-API + sections + int32 indices + `TBox3` bounds (added to `Apus.Geom3D`). **Headless gate** `tests/TestMesh3D.dpr` (28 checks: round-trip, sections, MaxIndex, bounds, Finish validation) — de-risks B3.
  - **B3 — GL binding PAIR (obligatory together):** shader-gen reads `location` from the semantic table (not sequential `inc(ch)`) **and** the binder enables the specific locations from the descriptor (not contiguous prefix `0..n-1`). **§15 decision (2026-06-12): COEXIST** — add a SEPARATE table-driven binding path + `layout(location=N)` shader-gen for `TGpuMesh`; leave old `SetupAttributes(TVertexLayout)`/2D-painter untouched (hottest path, zero gain now). **Agreed future convergence:** migrate/retire the painter → single table-driven binder, delete packed-cardinal `TVertexLayout` (later deliberate step; don't let coexist ossify).
  - **B3 (DONE 2026-06-12) — GL binding pair (coexist):** table-driven mesh shaders (`ShadersGL`: `BuildVertexShader(...,useTable)` reads `location` from the semantic table; separate `meshShaderCache` keyed by `(layout.id,texMode)`; `ApplyMeshLayout`/`GetMeshShaderFor`/`CreateMeshShaderFor`/`ApplyShaderState`) + descriptor attribute binder (`OpenGL.pas`: `BindMeshLayout`/`UnbindMeshLayout`/`DrawMesh`, `MeshFormatToGL`, enables the exact locations from the descriptor, hands painter state back via `actualAttribArrays:=-1`). New interface methods: `IShader.ApplyMeshLayout`, `IRenderDevice.BindMeshLayout`/`UnbindMeshLayout`/`DrawMesh`. Legacy `SetupAttributes(TVertexLayout)`/2D painter untouched. Commit 792f7b0.
  - **B4 (DONE 2026-06-12):** `TGpuMesh` (`Apus.Engine.GpuMesh`) — `BuildAutoLayout` (single interleaved stream from present arrays), `Upload` (gather+encode via `EncodeStream`, IBO width uint16/uint32 chosen by maxIndex, `muDiscardCPUCopy`), `DrawRange`/`Draw`. Buffer seam decoupled from packed layout: `TVertexBuffer.strideBytes` + `IResourceManager.AllocRawVertexBuffer` (commit de75260). Commit 79fa3ba. `Apus.Engine.Mesh3D` gained uv-less `AddVertex(p,n,color)` overload for flat-shaded colored geometry. Visual validation pending: `demo/MeshLab` (lit colored cube + textured quad through the new path), by screenshot (Robot API).
  - **C (geometry closeout) — DONE 2026-06-12, re-bound by author (see scope-lock note):** finalize `TMesh` as the first-class client CPU geometry container. `TMesh.SetVertexCount(n,attrs)` direct-fill API for generators/loaders (keeps `length==count`, no hidden capacity model; cursor `AddVertex` retained) + `TGpuMesh.DrawSection(i)` per-section draw (commit 9f01d36). Geometry-only OBJ→`TMesh` loader `Apus.Engine.OBJMesh` (dedup, fan triangulation, sections per usemtl, materials bound manually; headless-testable, no gfx; commit 0672195). MeshLab multi-section row + 90k-vert grid proving sections + uint32 IBO (commit 091ae6f). 32-bit indices were already end-to-end (CPU int32 → upload width-select → `DrawMesh` GL_UNSIGNED_INT). Headless gates: `TestMesh3D` 32/32, `TestObjMesh` 6/6.
  - **C-deferred — moved OUT of R-19 by the 2026-06-12 scope lock:** `TModel`/`TModelInstance` (design + dev) and the AEM format/loader → **R-03** (AEM is TModel's internal representation); GPU skinning + instancing → ride with TModel in R-03; rename `Apus.Engine.Mesh3D`→`Apus.Engine.Mesh` + migrate legacy consumers + remove old interleaved unit + drop IQM + consolidate OBJ loaders → a separate follow-up migration (once the new path is content-proven).
  - Big S3/L2/unify decision is now TAKEN (see Design DECISION above); these stages implement it.
- Out of scope (this card): **primitive/shape generators** (quad/torus/sphere; tangent-extension of cube/cylinder) — a separate shape-generator module, `TMesh` is container-only; the standalone debug-draw helper (that is R-18, which does *not* depend on this rework); `TMaterial` + normal map in the stock shader (R-06 core); `NormalMapFromHeight` (R-06 follow-up task 4).
- Dependencies: `Apus.VertexLayout`, `Apus.Engine.Mesh`, `Apus.Engine.Model3D`, `Apus.Engine.OpenGL` (`SetupAttributes`), `Apus.Engine.ShadersGL` (location generator), `Apus.Geom3D`. Informs/unblocks: R-06 follow-up task 2 (`ComputeTangents`), R-03 (AEM).
- Risks: etap A is safe (write-API guarded by layout presence checks; tangent already on the GPU path); etap B/C touch the GL attribute-binding core and the closed layout encoding — the main risk surface, mitigated by the 1-stream-equals-today zero-regression target; CPU vs GPU skinning choice constrains layout slot design (decide before committing the encoding).
- Acceptance Criteria (etap A):
  - [x] `TMesh` writes tangent/extra per vertex (`SetTangent`/`SetExtra`/`GetTangent`/`GetExtra`, `AddVertex` overload), safe no-op when the layout lacks the slot. Compiles clean under FPC (51893 lines, 0 errors; unit path must include `Base/extra` for the engine's `freetypeh`).
  - [ ] `demo/NormalMap` drops `TVertexNM`/`TDemoMesh` and uses `TMesh`, with visually identical normal mapping (visual + Robot API parity) — gated on the generator module (cube/torus).
  - [ ] Builds under FPC (and Delphi) on Win/Linux.
- Notes:
  - **Final design spec: `Work/reports/R-19_mesh_design.md`** (clean target model + API sketches + location table + stages). Discussion archive: `Work/reports/R-19_mesh_workflow_brainstorm.md`.
  - Design exploration + axes + backend reality + etap A detailed plan: `Work/reports/R-06_mesh_architecture_options.md`.
  - 2026-06-10: card created from R-06 follow-up task 1; etap A scope locked, then **narrowed to write-API only** (generators → separate shape-generator module); write-API implemented same day.
  - 2026-06-12: A→B boundary decision taken — full design locked (see `R-19_mesh_design.md`). B1 (`TGpuLayout`+location table) and B2 (SoA `TMesh`+`TBox3`) implemented and committed on `feature/r-19-mesh`, both with passing headless tests; wired into `linux_smoke.sh`. New SoA mesh lives in transitional `Apus.Engine.Mesh3D` (new unit chosen over in-place replacement to keep B headless and not break the ~8 legacy `TMesh` consumers; migrated + renamed in C2). 
  - 2026-06-12: B3 (GL binding pair) + B4 (`TGpuMesh`) implemented on the §15 COEXIST basis (new table-driven path beside the untouched packed-layout painter), all touched units FPC-clean. Commits de75260 (buffer seam) / 792f7b0 (B3) / 79fa3ba (B4). MeshLab B3/B4 stand committed 0495be6 (author-validated).
  - **2026-06-12: SCOPE LOCK (author).** R-19 re-bound to the **geometry level only** (`TMesh`+`TGpuMesh`), narrower than the design §16 staging. Decisions: (1) `TMesh` is a first-class standalone CLIENT entity (universal CPU geometry currency: loaders/generators/ops produce it; static draw = TMesh→TGpuMesh→DrawRange/DrawSection), NOT an internal container for TModel — two client levels, TModel is a thin consumer on top. (2) `TModel`/`TModelInstance` design **and** development → **R-03**, together with the **AEM** format (AEM = TModel's internal representation); GPU-skin/instancing ride along. (3) **IQM** = legacy, drop it; **OBJ** = geometry-only (one loader → new `TMesh`, materials manual). (4) primitive **generators → R-18** (separate task), but R-19 must give TMesh a convenient fill interface. → stage C delivered as the geometry closeout above; everything else is R-03 or a follow-up migration. Detail in memory `project_r19_scope_lock.md`.
  - **OPEN (revisit later): tangent `vec4` vs `vec3`.** Design (§3/§8) stores tangent as `vec4` (xyz along +U, `w`=handedness). The `w` sign matters *only* for mirrored UVs: to support them you need either `w` or an explicit `vec3` bitangent — `vec3 tangent` + `B=cross(N,T)` cannot represent mirrored islands (inverted normals on the mirror seam). Author's lean (2026-06-12): `vec4` likely unnecessary for this engine since we own the asset pipeline and can avoid mirrored UVs. Note `glTF`/MikkTSpace mandate `vec4` for interop. **If we switch to `vec3`:** change `TMesh.tangents`→`array of TVec3`, the `AddVertex` tangent overload, `TestMesh3D`, default tangent format in layout (`Float4`→`Float3`), and update design §3/§8 + memory. Not blocking B3/B4 (tangent is not wired into the stock shader yet — that's R-06 core). Deferred; tangent left `vec4` until decided.

### [R-20] Mesh Shape Generators (Procedural Primitives)
- Status: idea (card created 2026-06-13; design pending — to be discussed before any implementation)
- Priority: P2
- Area: Render / 3D Core
- Value: Give the engine ready-made procedural primitive meshes (quad/plane, box, cylinder, cone, sphere, torus, …) that produce a `TMesh` through its public fill-API, so app/demo/tooling code stops hand-rolling vertex/triangle loops (as `demo/NormalMap` does for its cube and torus, and as R-18 solid gizmos would otherwise have to). Also the first real consumer that exercises and proves the new `TMesh` fill-API end-to-end — a precondition for the deferred mesh consolidation migration ("content-proven" gate from the R-19 scope lock).
- Origin: explicitly carved out of **R-19** (R-19 scope lock: *"primitive generators → separate task"* — `TMesh` stays a container + fill-API, generators do not live in it) and of the **R-06 follow-up plan** (`Work/reports/R-06_followup_plan.md`, task 1's generator sub-point). Reuses the long-standing `Apus.Engine.MeshShapes` module name from the R-19 design doc (`Work/reports/R-19_mesh_design.md`).
  - **Doc reconciliation:** the R-19 scope-lock note said "generators → R-18", but the **R-18 card's own Out-of-scope** already states the opposite (*"primitive generators of R-19, not this card"*). Resolved here: generators are **their own card (R-20)**, neither R-18 nor R-19; R-18 DebugDraw is a *consumer* of R-20 for its solid shapes. (Author agreed 2026-06-13: generators could plausibly fit R-18, but a separate card is cleaner/more consistent.) The "R-20" number for the modern-syntax sweep (branch `feature/r-20-modern-syntax`, `Work/reports/R-20_modern_syntax_plan.md`) was an accidental branch name, not a roadmap card — number reclaimed for this card.
- Scope (MVP — **to be finalized in design discussion**, draft):
  - New module `Apus.Engine.MeshShapes.pas` ({$SCOPEDENUMS ON}), a record-namespace of generator functions, each returning/filling a `TMesh` (`Apus.Engine.Mesh3D`). No GPU, no materials — pure CPU geometry.
  - Candidate primitives: `Quad`/`Plane` (subdivided), `Box`/`Cube`, `Cylinder`, `Cone`, `Sphere` (UV-tessellated), `Torus`. (`Capsule`, `Grid` TBD — may belong to R-18 line-mode instead.)
  - Each generator writes positions + normals + UVs; **tangents optional** (written only when the target layout has a tangent slot, via `SetTangent`) — ties into the open R-19 `vec3`/`vec4` tangent decision, so default-on-vs-on-demand is a design-discussion item, not pre-decided.
  - Consistent parameterization conventions across generators: segment/ring counts, origin/pivot, axis, winding (CCW front), and UV layout — to be nailed down in design.
- Out of scope: mesh editing/ops (subdivide, flip, weld, transform, merge) — a sibling `Apus.Engine.MeshOps` module, separate effort (may or may not ship alongside; decide in design); GPU upload (that is `TGpuMesh`); materials; the immediate-mode debug gizmos themselves (R-18, which *consumes* this); skeletal/animated content (R-03).
- Dependencies: `Apus.Engine.Mesh3D` (`TMesh` + fill-API: `SetVertexCount`/`AddVertex`/`SetTangent`), `Apus.Geom3D` (`TVec3`/`TVec2`). Independent of GL. **Unblocks:** R-18 (solid gizmo shapes), R-06 follow-up (tangent-bearing cube/torus → lets `demo/NormalMap` drop `TVertexNM`/`TDemoMesh`, closing R-19's last acceptance criterion).
- Risks: low — pure CPU math over a tested fill-API; main risk is API/convention churn if shapes are added piecemeal (mitigated by designing the convention set up front and not building all primitives at once — author preference 2026-06-13).
- Acceptance Criteria (draft — finalize in design):
  - [ ] `Apus.Engine.MeshShapes` produces the MVP primitive set as valid `TMesh` (correct winding, normals, UVs; headless round-trip / index-range checks).
  - [ ] At least one real consumer ported onto it (NormalMap cube/torus and/or a MeshLab/DebugDraw stand) — visual parity.
  - [ ] Tangent emission works when the layout carries a tangent slot, no-op otherwise.
  - [ ] Headless test (`tests/TestMeshShapes.dpr`) + compiles under FPC (and Delphi) on Win/Linux.
- Notes:
  - **Delegation:** the tessellation formulas (sphere/torus/cone rings, box faces, tangent derivation) are well-known and mechanical — once the module API + conventions are designed, individual generators are good candidates to spec out and delegate (Sonnet/Codex) per `memory/feedback_delegate_simple_tasks`. Design/API + convention decisions stay with the author/Claude.
  - 2026-06-13: card created (number R-20 reclaimed). Design discussion pending: MVP primitive set, fill pattern (`SetVertexCount` direct-fill vs cursor `AddVertex` vs bulk local-array+assign), tangents default-on vs on-demand, whether `MeshOps` is a sibling now or later, and shared parameterization conventions.
