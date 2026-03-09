# Engine5 Feature Roadmap
Last updated: 2026-03-09

Language policy: this roadmap is maintained in English.

This file follows top-down planning:
- capture the high-level idea first;
- break it down into sub-features;
- then add implementation details and acceptance criteria.

## 1) Vision
- [ ] Engine5 as a stable cross-platform foundation for 2D/3D projects.
- [ ] A unified, predictable API across UI/Scene/Resources/Audio/3D.
- [ ] A smooth path from demo/template to production build.

## 2) Strategic Directions

Current phase note:
- The first migration wave is effectively complete: almost all engine modules already use the new foundation API, and `demo/SimpleDemo` builds and works.
- Roadmap work now proceeds on top of that baseline rather than in parallel with broad compile-unblock work.

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
- [ ] F1. Formalize lifecycle: Load -> Initialize -> Process -> Render
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

## 3) Feature Cards (expand during discussion)
Card template:

```md
### [ID] Feature Name
- Status: idea | planned | in-progress | done | dropped
- Priority: P0 | P1 | P2
- Area: Platform | Core | UI | Render | Resources | Audio | Network | Tooling
- Value: why we are doing this (1-2 lines)
- Scope (MVP): what is included
- Out of scope: what is excluded
- Dependencies: modules/tools/platforms
- Risks: key technical risks
- Acceptance Criteria:
  - [ ] criterion 1
  - [ ] criterion 2
- Notes: links/sketches/decisions
```

## 4) Inbox (quick ideas without details yet)
Use this section for anything remembered on the fly.
- [x] [R-001] Core OpenGL pipeline modernization (drop compatibility profile, VBO/IBO everywhere, NSight-friendly debugging)
- [ ] [R-002] Multi-window + multi-monitor support with hot DPI-awareness
- [ ] [R-003] Native model/animation format (AEM) with ultra-compact data encodings + Blender export plugin
- [x] [R-004] Robot interaction layer (MCP server or file-dialog bridge)
- [ ] [R-005] CSS-like UI style system completion (text-defined inherited styles, from prototype to production-ready)
- [ ] [R-006] 3D material pipeline: normal mapping (optional parallax/occlusion extensions)
- [ ] [R-007] Geometric utility library for object culling and intersections (Geom3D extension)
- [ ] [R-008] UI input hit-test for out-of-bounds children without full-tree mouse-move traversal
- [ ] [R-009] OpenGL performance modernization (bindless/persistent mapping + explicit batching)
- [ ] [R-010] UI widget system refactor roadmap (TUIElement decomposition + widget-class review)
- [ ] [R-011] Headless/NOGFX backend for CI-driven UI automation without window/OpenGL context

## 5) Seed Feature Cards

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
  - [ ] Engine can create and manage more than one active window.
  - [ ] Window placement and fullscreen behavior work on multiple monitors.
  - [ ] Runtime DPI change triggers correct viewport/UI scaling without restart.
- Notes: hot DPI-awareness must be validated with monitor move and OS scale-change scenarios.
  - 2026-03-08: architecture draft and decisions v1 are documented in `reports/R-02_multiwindow_plan.md`.
  - 2026-03-08: phase-1 implementation started (Windows path): `TWindow` abstraction extracted, API naming normalized, OpenGL context flow moved out of `Engine.API` into `Engine.OpenGL`.
  - 2026-03-09: SDL `SimpleDemo` freeze investigation completed:
    - diagnostics confirmed stalls inside `SDL_PollEvent` cumulative time (not in engine event handlers/render path);
    - runtime SDL DLLs updated to `2.32.10` (`bin` and `bin64`);
    - user validation: freezes are gone, runtime is smooth;
    - follow-up: update Pascal SDL headers (currently `2.0.4`) to reduce version drift.

### [R-03] Native AEM Pipeline + Blender Export
- Status: idea
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
- Status: idea
- Priority: P1
- Area: UI
- Value: Make UI styling declarative, reusable, and maintainable via inherited text-defined styles.
- Scope (MVP): complete the current prototype into a usable CSS-like style layer with style inheritance, selector-like matching for core widgets, and deterministic conflict resolution.
- Out of scope: full web-CSS parity and advanced layout features not required by Engine5 UI.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UIScript`, widget/style binding points, serialization/parsing support.
- Risks: style precedence ambiguity; runtime overhead from style resolution; regressions in existing widget appearance.
- Acceptance Criteria:
  - [ ] UI elements can resolve effective style from inherited text-defined style rules.
  - [ ] Style priority/conflict behavior is documented and covered by baseline tests.
  - [ ] Existing core widgets can be restyled without code changes in representative demo screens.
- Notes: current implementation exists in initial state and needs completion to production baseline.

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

### [R-07] Geometric Library for Culling and Intersection (Geom3D Extension)
- Status: idea
- Priority: P1
- Area: Core
- Value: Provide a reliable and convenient geometry toolkit for visibility tests and spatial queries used across engine subsystems.
- Scope (MVP): add reusable primitives/tests for frustum culling and common intersections (ray/plane, ray/triangle, ray/AABB, sphere/AABB, AABB/frustum), with API shape consistent with `Geom3D`.
- Out of scope: full broadphase physics engine or BVH/scene-graph replacement.
- Dependencies: `Base/Apus.Geom3D.pas`, math types used by render/scene modules, test coverage in `Base/tests/TestMath`.
- Risks: numerical stability/precision edge cases; API duplication with existing helpers; performance pitfalls in naive implementations.
- Acceptance Criteria:
  - [ ] Core culling/intersection routines are implemented in `Geom3D` extension API.
  - [ ] Deterministic tests cover normal and edge cases for each routine.
  - [ ] At least one engine-side usage path adopts the new API for practical validation.
- Notes: keep API ergonomic for both gameplay queries and render-side visibility checks.

### [R-08] UI Hit-Test for Out-of-Bounds Children (Performance-Safe)
- Status: idea
- Priority: P1
- Area: UI
- Value: Fix a real UX/input bug where child UI elements intentionally rendered outside parent bounds may not receive mouse input, while preserving high mouse-move performance.
- Scope (MVP): make hit-testing respect intentional non-clipping behavior for out-of-bounds child elements, without falling back to full UI tree traversal on each mouse move.
- Out of scope: full UI picking architecture rewrite; broad changes to rendering order model.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UITypes`, `Apus.Engine.UIScene`, clipping semantics (`clipChildren` / `parentClip`), root element ordering.
- Risks: regressions in modal/focus behavior; hidden coupling with existing `FindElementAt` recursion and clipping assumptions; accidental perf degradation on deep UI trees.
- Acceptance Criteria:
  - [ ] A child element intentionally outside parent bounds and configured as non-clipped can receive hover/click input.
  - [ ] Mouse move processing does not degrade to full-tree scan for common frames.
  - [ ] Existing modal-window and z-order input behavior remains unchanged in representative UI demo flows.
  - [ ] Add at least one focused test or reproducible scenario covering this case.

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
- Notes: target an optimization strategy such as selective traversal only through potentially relevant overflow branches (or cached overflow-aware hit regions), not brute-force global traversal.

### [R-09] OpenGL Performance Modernization (Core-Profile Follow-Up)
- Status: idea
- Priority: P1
- Area: Render
- Value: improve CPU/GPU efficiency on core profile and reduce driver overhead in real scenes.
- Scope (MVP): reduce redundant state changes (`glBind*` churn), introduce practical batching for line-heavy immediate paths, and evaluate modern GL features behind capability gates (persistent mapped streaming, bindless resources where available).
- Out of scope: full renderer rewrite or hard requirement on latest GL-only GPUs.
- Dependencies: `Apus.Engine.OpenGL`, `Apus.Engine.Draw`, `Apus.Engine.ResManGL`, `Apus.Engine.ShadersGL`, runtime capability detection.
- Risks: synchronization bugs with persistent mapping; cross-driver behavior differences; complexity creep in draw API.
- Acceptance Criteria:
  - [ ] Redundant bind calls flagged as useless in NSight are reduced in representative captures.
  - [ ] Introduced one explicit batch path for high-frequency simple primitives (e.g. lines) with deferred flush on state/shader/texture changes.
  - [ ] Added capability-gated prototype for modern buffer update path (persistent mapping or equivalent) with fallback to current path.
  - [ ] Performance telemetry/comparison added for at least one representative demo scene.
- Notes: initial optimization candidates from NSight review:
  - collapse repetitive `UseVertexBuffer/UseIndexBuffer/Draw/Unbind` pattern via scoped helper;
  - avoid unconditional unbind-to-zero in upload paths when the same buffer remains active;
  - add lightweight state cache to skip redundant binds at API boundary.

### [R-10] UI Widget System Refactor (TUIElement Decomposition First)
- Status: planned
- Priority: P0
- Area: UI
- Value: reduce UI core complexity and improve maintainability/testability by restructuring `TUIElement` and clarifying responsibilities across widget classes.
- Scope (MVP): analyze decomposition options for `TUIElement`; pick and implement the best option; review existing widget classes and define/execute targeted reorganization where needed.
- Out of scope: broad new widget/layout expansion before core decomposition and class reorganization are complete.
- Dependencies: `Apus.Engine.UI`, `Apus.Engine.UIWidgets`, `Apus.Engine.UITypes`, scene/UI integration points.
- Risks: behavioral regressions in event flow/focus/layout; migration churn across many widget descendants; temporary API instability during split.
- Acceptance Criteria:
  - [ ] At least 2-3 decomposition variants for `TUIElement` are documented with trade-offs.
  - [ ] One selected decomposition approach is implemented in engine code with preserved baseline UI behavior on representative screens.
  - [ ] Widget class review is completed, with concrete reorganization actions implemented (or explicitly deferred with rationale).
  - [ ] Follow-up backlog for widget/layout expansion and test coverage is created and prioritized.
- Notes:
  - 2026-03-08: implementation stages and execution plan documented in `reports/R-10_ui_widget_refactor_plan.md`.
  - 2026-03-08: decomposition research report documented in `reports/R-10_tuielement_decomposition_report_2026-03-08.md`.
  - Main scope (this task):
    - decomposition options study for `TUIElement`;
    - select best option and implement it;
    - review widget classes and plan/implement reorganization.
  - Follow-ups (after main scope):
    - expand widget/layout set where gaps remain;
    - add focused tests for widgets and layouts.

## 6) Next Planning Session
Prepare for the next discussion:
- Select 3-5 priority items from Inbox.
- Create a Feature Card for each selected item (MVP + Acceptance Criteria).
- Mark explicitly which items require Base API changes.
