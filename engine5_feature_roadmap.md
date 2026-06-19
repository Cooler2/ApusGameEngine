# Engine5 Feature Roadmap
Last updated: 2026-06-17

Language policy: this roadmap is maintained in English.

This file captures what remains to be done. Completed stage notes live in Work/reports/.

## 1) Vision
- [ ] Engine5 as a stable cross-platform foundation for 2D/3D projects.
- [ ] A unified, predictable API across UI/Scene/Resources/Audio/3D.
- [ ] A smooth path from demo/template to production build.

## Feature Status Overview

| ID | Feature | Status | Readiness | Remaining |
|----|---------|--------|-----------|-----------|
| R-01 | Core GL Pipeline Modernization | done | 100% | — |
| R-02 | Multi-Window / Multi-Monitor / DPI | in-progress | ~75% | Multi-monitor placement, per-window DPI flow, overlay refresh bug |
| R-03 | Native AEM Pipeline + Blender Export | planned | ~15% | AEM v1 spec, runtime loader alignment, Blender exporter MVP |
| R-04 | Robot Interaction Layer | done | 100% | — |
| R-05 | CSS-Like UI Style System | in-progress | ~75% | Real-screen validation, resolver perf/caching, $varName support, visual regression tests |
| R-06 | 3D Material: Normal Mapping | done | 100% | Shipped: ComputeTangents/Normals, stock-shader TBN, demo port, CI smoke; visual handedness sign-off passed |
| R-07 | Geometry Overhaul (Single-First + Spatial) | in-progress | ~88% | Linux validation, benchmark pass, SSE hot paths, remaining module migration |
| R-08 | UI Hit-Test for Out-of-Bounds Children | done | 100% | — |
| R-09 | GL Performance Modernization | in-progress | ~40% | NSight baseline (Track A); Track C opt-in batching on demand |
| R-10 | UI Widget System Refactor | done | 100% | — |
| R-11 | Headless/NOGFX CI Backend | idea | 0% | NoGfx platform stub, headless frame pump, CI integration |
| R-12 | Graphics: Text + Streaming Buffers | planned | ~5% | Ring-buffer streaming, persistent text cache, profiling |
| R-13 | Robot API Input Simulation | idea | 0% | `ui.click`/`ui.type`/`ui.focus` commands |
| R-14 | UI Widget Expansion | idea | 0% | New widget types, module split strategy |
| R-15 | Demo Suite Restructuring | in-progress | ~25% | Directory restructure, HelloEngine, Text demo, merged demos, EngineTest distribution |
| R-16 | Console Modernization | in-progress | ~70% | Scroll rework, SDL editbox Enter, build-GUI-mode fixes |
| R-17 | 3D Game Architecture Probe | idea | 0% | Top-down 3D skeleton to expose architecture white spots |
| R-18 | Debug Draw Primitives (3D Gizmos) | planned | ~10% | `materialColor` tint uniform; solid/line sets; MeshLab showcase; NormalMap port |
| R-19 | Mesh Representation Unification & Rework | done | 100% | — |
| R-20 | Mesh Shape Generators (Procedural Primitives) | done | 100% | — |
| R-21 | Mesh Editing Operations (Stateful Wrapper) | idea | 0% | Design-now / build-on-demand; first heavy consumer gates implementation |
| R-22 | Toast Notifications (Implement + Extend `FireMessage`) | implemented | 100% | `Apus.Engine.Notifications` overlay; ShowToast/kinds/anchors/config, R-05-themed, SML, stacking+dissolve, hover-freeze; committed `d489ef8` on engine5 |
| R-23 | Keyboard Input Pipeline Unification (Callbacks over Signals) | implemented | 95% | Collapsed 2 parallel `KBD\` consumers into one ordered `PumpInput`→`DispatchKey` pipeline; key signals dropped; scene `RegisterHotKey`. Compiles x64+x86; demos ported. Pending: runtime sign-off |

## 2) Strategic Directions

### A. Engine Module Refactoring
- [ ] A1. Refine engine modules to use the new foundation API more idiomatically
- [ ] A2. Remove temporary migration leftovers and compatibility-style code
- [ ] A3. Simplify and reduce engine-module dependencies

### B. Targeted Base Refactoring
- [ ] B1. Identify small Base API gaps discovered during engine migration
- [ ] B2. Apply focused Base refactors with immediate engine adoption
- [ ] B3. Keep Base tracking/docs aligned when interfaces change

### C. Base Performance Optimization
- [ ] C1. Benchmark representative Base modules and hot paths
- [ ] C2. Identify bottlenecks and weak implementation points
- [ ] C3. Optimize internals while preserving existing APIs and behavior

### D. Architecture Changes
- [ ] D1. Identify architecture areas now worth redesigning after migration
- [ ] D2. Implement changes incrementally with working-demo validation
- [ ] D3. Preserve compatibility where practical during transition

### E. Platform & Build
- [ ] E1. Unify build scripts for engine/demo/tests
- [ ] E2. CI smoke pipeline for key demos
- [ ] E3. Close known FPC/Linux compatibility gaps

### F. Core Runtime & Scenes
- [ ] F2. Safe scene transitions (including async loading)
- [ ] F3. Lifecycle diagnostics and error logging

### G. UI System
- [ ] G1. Core widgets with consistent behavior
- [ ] G2. Layout engine (adaptive behavior, alignment, spacing)
- [ ] G3. Testability of UI logic and events

### H. Graphics / Render
- [ ] H1. Shader pipeline stability and diagnostics
- [ ] H2. Reliable texture/shader/buffer resource lifecycle
- [ ] H3. Performance improvements on representative scenes

### I. Assets & Resource Management
- [ ] I1. Allocation/free cycle control
- [ ] I2. Loading queues and priorities
- [ ] I3. Unified resource ownership rules

### J. Audio
- [ ] J1. Backend behavior unification (BASS/SDL/IMX)
- [ ] J2. Playback/streaming diagnostics
- [ ] J3. Test scenarios for baseline audio use cases

### K. Networking
- [ ] K1. TCP/HTTP baseline scenarios
- [ ] K2. Error handling/timeouts/retry behavior
- [ ] K3. Minimal integration tests

### L. Tooling & Developer Experience
- [ ] L1. Engine5 project template
- [ ] L2. Migration-path documentation (Engine4 -> Engine5)
- [ ] L3. Pre-release check suite

## 3) Feature Cards

### [R-01] Core OpenGL Pipeline Modernization
- Status: **done**
- Core profile, VBO/IBO pipeline, NSight debugging complete.

### [R-02] Multi-Window, Multi-Monitor, and Hot DPI-Awareness
- Status: in-progress (~75%) | Priority: P0 | Area: Platform
- Value: Modern desktop app behavior across displays and DPI changes without restart.
- Scope: support multiple engine windows with shared GL context; map windows to monitors; react to runtime DPI changes and re-layout/re-scale correctly without restart. Per-window render threads, shared context, `AddWindow`/`RemoveWindow` API.
- Out of scope: per-platform native custom window chrome; multi-GPU collaborative rendering.
- Remaining:
  - [ ] Window placement and fullscreen behavior validated on multiple monitors.
  - [ ] Runtime DPI change triggers correct viewport/UI scaling without restart.
  - Known open bug: main-window debug overlay refresh incorrect in multi-window mode (secondary updates fine).
- Plan: `Work/reports/R-02_multiwindow_plan.md`

### [R-03] Native AEM Pipeline + Blender Export
- Status: planned (~15%) | Priority: P1 | Area: Resources
- Value: Make AEM the native high-performance path for models/animations, with a Blender export plugin.
- Scope: finalize AEM model/animation capabilities; define compact encoding; implement Blender exporter.
- Out of scope: full DCC ecosystem beyond Blender in first iteration.
- Acceptance Criteria:
  - [ ] Runtime supports AEM model + animation for at least one production-like asset.
  - [ ] Ultra-compact encoding mode documented and loadable.
  - [ ] Blender plugin exports valid AEM without manual conversion.
- Notes: pipeline direction fixed — OBJ (baseline) + AEM (native); no FBX/DAE converter. `TModel`/`TModelInstance` design lives here (carved out of R-19). Plan: `Work/reports/R-03_aem_pipeline_notes.md`.

### [R-04] Robot Interaction Layer
- Status: **done**
- File-based protocol, all commands, FPS telemetry, UI diagnostics. Protocol: `robot_api_protocol.md`.

### [R-05] CSS-Like UI Style System
- Status: in-progress (~75%) | Priority: P1 | Area: UI
- Value: Declarative, reusable UI styling via inherited text-defined styles.
- Scope: CSS-like text syntax for styles (`color: #fff; font: bold 14`), style inheritance from parent elements, `@ref` includes, state blocks (`hover:`, `pressed:`, `disabled:`), patch operations (`+key:val` / `-key`), named style catalog (`Styles['btn'] := '...'`), animated transitions via Tweenings. Drawer objects resolve styles instead of per-element draw procedures.
- Out of scope: full web-CSS parity; advanced layout features (→ R-14).
- Done: TStyleBlock, resolver, @refs, state blocks, patch, transitions, draw migration, StyleDemo, TStyleCatalog; font/color/styleClass removed from TUIElement.
- Remaining:
  - [ ] Style resolution validated on real project screens (not only StyleDemo).
  - [ ] Resolver performance profiled; caching added if needed.
  - [ ] Visual regression tests via Robot API `pixel` command.
  - Deferred: `$varName` substitution via `Apus.Publics`.
- Design: `Work/reports/R-05_notes.md`

### [R-06] 3D Material Pipeline: Normal Mapping
- Status: done | Priority: P1 | Area: Render
- Value: Per-pixel normal mapping in the stock mesh shader for static `TMesh`/`TGpuMesh` geometry.
- Implemented (committed on `engine5`, T1–T3): `MeshOps.ComputeNormals`/`ComputeTangents` co-located in `Apus.Engine.Mesh` (as a `MeshOps` class with static methods, not a bare proc — minor deviation from the locked design, but co-located in the unit as decided); normal-map branch in stock mesh shader (`LIGHT_NORMALMAP` flag, TBN reconstruction with Gram-Schmidt + `vTangent.w` handedness, `normalMap`/`normalStrength` uniforms, bound to unit 3); `shader.NormalMap(tex;strength)` / `NormalMapOff` state; `demo/NormalMap` ported onto `TMesh`+`MeshShapes.Box`+stock shader with computed/analytic toggle (key C); handedness fix (`35a79c5`/`33c698e`).
- Scope: see Implemented above.
- Out of scope: full PBR; `TMaterial` type (→ R-17/R-03); skinned-model tangents; procedural texture baking.
- Acceptance Criteria:
  - [x] `ComputeTangents(mesh)` in `Apus.Engine.Mesh` (`MeshOps.ComputeTangents`).
  - [x] Headless test: degenerate UV does not NaN; handedness sign correctness — `tests/TestMeshOps.dpr`, 9 checks, passes FPC x86+x64; no bugs found.
  - [x] Stock mesh shader does TBN normal mapping when normal map bound + mesh carries tangents; non-mapped draws unchanged.
  - [x] `demo/NormalMap` ported onto stock shader + ComputeTangents (TMesh SoA + MeshShapes.Box + MeshShapes.Torus).
  - [x] Tangent handedness validated on real surface — algebraically covered by TestMeshOps + guard test `TangentFrameMatchesShader`; visual sign-off passed (generated/computed paths identical, 2026-06-19).
  - [x] `TestMeshOps` wired into engine CI smoke (`tests/linux_smoke.sh` + `tests/windows_smoke.ps1`) — runs Win+Linux.
- Plan: `Work/reports/R-06_normal_mapping_plan.md`

### [R-07] Geometry Library Overhaul (Single-First + Spatial)
- Status: in-progress (~88%) | Priority: P1 | Area: Core
- Value: Single-precision default for game math; spatial primitives and intersection/culling tests at DirectXMath-level coverage.
- Scope: make `single` (32-bit) the default precision in `Apus.Geom2D`/`Apus.Geom3D` (double-precision kept as explicit overloads); TVec3=12B (storage-compatible), TVec4=16B (SSE-friendly); add spatial primitives (ray, AABB, frustum, plane) with intersection and culling tests; SSE optimization for hot paths with pure Pascal fallback.
- Out of scope: full broadphase physics; BVH/scene-graph; OBB and sweep tests (deferred follow-up).
- Done: baseline merged into `engine5`; TVec3=12B / TVec4=16B; spatial primitives.
- Remaining:
  - [ ] Linux behavior fixed and validated.
  - [ ] Benchmarks executed; baseline deltas recorded.
  - [ ] Highest-impact functions get SSE optimization (with pure Pascal fallback).
  - [ ] Remaining modules (including SDL paths) migrated to current foundation APIs.
- Plan: `Work/reports/R-07_geometry_library_plan.md`

### [R-08] UI Hit-Test for Out-of-Bounds Children
- Status: **done**
- Clip-threaded `FindElementAt` with `escapingOnly` mode for deep `noParentClip` descendants. Details: `Work/reports/R-08_hittest_overlay_notes.md`.

### [R-09] GL Performance Modernization (Diagnose-First)
- Status: in-progress (~40%) | Priority: P1 | Area: Render
- Value: CPU/GPU efficiency improvements driven by measurement, not speculative batching.
- Key finding: no cheap 4.x wins remain standalone — real per-draw cost is `glBufferSubData` stream sync, which pays off only with R-12 (persistent ring-buffer) + Track C. **Next blocker: NSight baseline (author runs it).**
- Tracks:
  - **A — Telemetry** (done): per-frame draw/shader/texture/scissor counters in debug overlay.
  - **B — Cheap state wins** (done): redundant `glBindBuffer`/`glVertexAttribPointer`/`glUseProgram` eliminated.
  - **C — Opt-in batch API** (pending): `draw.Batching(on/off)` coalesces same-signature primitives; flushes on type/texture/state change. Target: tilemaps, sprite fields; integration seam for R-18 DebugDraw.
  - **D — GL 4.x research** (drafted): `Work/reports/R-09_gl4x_research.md`.
- Remaining:
  - [ ] NSight baseline on a representative real scene; bottleneck documented.
  - [ ] Track C `draw.Batching` implemented if real use case warrants it.
- Journal: `Work/reports/R-09_notes.md`

### [R-10] UI Widget System Refactor
- Status: **done**
- TUIElement slimmed, widget decomposition complete, draw infrastructure migrated. Follow-ups: R-14 (new widgets), R-05 (style pipeline).

### [R-11] Headless/NOGFX Backend for CI
- Status: idea | Priority: P2 | Area: Platform
- Value: Run app/scene/UI tests on CI without native window or GPU.
- Scope: add a `NoGfx` platform backend + headless `IGraphicsSystem` stub that satisfies all engine interfaces with no-ops; controllable frame pump and time; synthetic input injection (`ui.click`/`ui.move`/`ui.type`); CI integration. Tests observe UI state/event outcomes without a display.
- Out of scope: full software rasterizer in MVP; pixel-perfect visual parity with hardware rendering.
- Acceptance Criteria:
  - [ ] Engine starts and executes frames in headless mode (no window/OpenGL context).
  - [ ] Tests inject synthetic input and observe deterministic UI state.
  - [ ] At least one GUI flow validated in CI via headless mode.
- Staged delivery: (1) NoGfx no-op backend + headless platform + frame pump; (2) test helpers (`click`/`move`/`type`/`advanceFrames`); (3) optional CPU offscreen rendering.

### [R-12] Graphics: Text + Streaming Buffers
- Status: planned (~5%) | Priority: P1 | Area: Render
- Value: Reduce CPU overhead in text-heavy UI and dynamic geometry updates.
- Scope: persistent text-draw cache (reuse vertex buffers for static labels); ring-buffer transient streaming path (`IRingBuffer`); deterministic invalidation on glyph atlas change.
- Out of scope: text layout/shaping rewrite; replacing glyph cache.
- Notes: gated on NSight baseline from R-09 Track A. Targets the 2D/text painter path (R-19 §15 COEXIST left it untouched). GL 4.4 persistent-mapped-buffer option tracked in `Work/reports/R-09_gl4x_research.md`.
- Acceptance Criteria:
  - [ ] Repeated persistent labels reuse geometry (no per-frame rebuild in steady state).
  - [ ] Glyph cache invalidation reliably invalidates dependent text buffers.
  - [ ] Public `IRingBuffer` interface implemented and used as transient streaming contract.
  - [ ] Ring-buffer overflow behavior is deterministic and documented.
  - [ ] Profiling on one representative scene shows measurable CPU reduction.

### [R-13] Robot API Input Simulation
- Status: idea | Priority: P2 | Area: Tooling
- Value: Enable automated UI interaction tests via Robot API without manual user input.
- Scope: extend the existing file-based Robot API (R-04) with input-simulation commands — `ui.click` (synthetic mouse click on element by name/path), `ui.type` (inject keyboard text into focused widget), `ui.focus` (set focus to element). Enables scripted test flows: open dialog → fill field → click button → verify state via `ui.element`.
- Remaining:
  - [ ] `ui.click` command (find element, synthesize mouse press/release)
  - [ ] `ui.type` command (inject key events into focused widget)
  - [ ] `ui.focus` command (programmatic focus set)

### [R-14] UI Widget Expansion
- Status: idea | Priority: P1 | Area: UI
- Value: Extend the UI toolkit with commonly needed widgets absent from the current set.
- New widgets (priority order):
  1. **TUIProgressBar** — display-only bar (value/min/max/fill direction)
  2. **TUISection** — collapsing/expanding section header with arrow indicator
  3. **TUINumericField** — Blender-style display+drag+edit for float/int
  4. **TUITabControl** — tab strip + content area
  5. **TUIMenu** — menu bar + popup/context menus with keyboard nav
  6. **TUISpinner** — numeric EditBox with ▲▼ step buttons
  7. **TUITreeView** — hierarchical list with expand/collapse
  8. **TUIColorPicker** — composite color control (own module)
  9. **TUIFileDialog** — modal open/save (own module, custom UI not OS-native)
- Label/button enhancements: icon support (texture region beside text), Ctrl+C text copy from focused static labels.
- Module split: `UIWidgets` (primitives) + `UIComposite` (composites that own child widgets) + `UIColorPicker` + `UIFileDialog`.
- Out of scope: animation on Section; TreeView drag-drop; alpha in ColorPicker MVP; OS-native file dialog.

### [R-15] Demo Suite Restructuring
- Status: in-progress (~25%) | Priority: P1 | Area: Tooling
- Value: Coherent, progressive demo suite for onboarding, API reference, and CI validation.
- Done: `InputDemo`, `Draw2D`, `TextDemo` created and integrated.
- Remaining:
  - [ ] Directory structure → `1-start/`, `2-features/`, `3-advanced/`
  - [ ] HelloEngine demo (replaces SimpleDemo)
  - [ ] Text demo with font/Unicode/formatting showcase
  - [ ] Draw2D absorbs NinePatch and EngineTest cases
  - [ ] Input demo merges keyboard/mouse + gamepad (ControllerDemo)
  - [ ] Platform demo merges multi-window/DPI/borderless
  - [ ] AdvancedGfx demo merges AdvTex + ShadowMap
  - [ ] SoundDemo rewritten as GUI app
  - [ ] EngineTest fully distributed and removed
  - [ ] All demos compile FPC+Delphi; CI builds all
- Plan: `demo/demo_plan.md`

### [R-16] Console Modernization
- Status: in-progress (~70%) | Priority: P1 | Area: Tooling
- Value: Replace the monolithic `Console.pas` (mixed buffer/render/command logic) with a layered, maintainable in-game console.
- Scope: dissolve `Console.pas` into separate concerns — log mirror feeds `ConsoleScene`'s buffer, `CmdProc` handles commands with an `OnOutput` sink, DEBUG/ERROR messages bridge to the log. UX improvements: two-tier log filter, timestamp toggle, `clear`/`loglevel` commands, Ctrl+C clipboard copy, DPI-scaled font, per-source color palette.
- Done: Console.pas dissolved; ConsoleScene owns log buffer; two-tier filter, timestamp toggle, `clear`/`loglevel`, Ctrl+C clipboard, DPI-scaled font, per-source colors. Merged to master.
- Remaining:
  - [ ] Scroll rework: sticky-bottom + `ScrollToEnd` unit fix
  - [ ] SDL: editbox Enter key
  - [ ] Build-GUI-mode: window title-bar DPI; editbox Enter
- Plan: `Work/reports/R-16_console_modernization.md`

### [R-17] 3D Game Architecture Probe (Skeleton-First)
- Status: idea | Priority: P1 | Area: Render/Core
- Value: No real 3D game has been built on this engine. Build a top-down integrated 3D skeleton to expose architecture white spots at subsystem seams — before committing to features like R-06 or a real game.
- Guiding rule: new abstractions only if they provably simplify calling code vs. inline. Entities are hypotheses, not a checklist. Scale matters — pain only appears at realistic multiplicity (many objects, several passes, several materials).
- Scope: render a scene with ≥2 passes + ≥2 materials; start fully inline; add abstractions only where inline actually hurts. Placeholder content is fine.
- Out of scope: real game; full PBR; committing to final public API.
- Seam audit (2026-06-05): no retained-mode 3D types exist — no `TCamera`, `TMaterial`, `TRenderPass`, `TSceneGraph`. Engine = 2D immediate-mode painter with 3D bolted onto global services.
- Acceptance Criteria:
  - [ ] Skeleton renders multi-pass 3D at realistic multiplicity, coexisting with UI.
  - [ ] Written fully inline first (measurable no-abstraction baseline).
  - [ ] Per-candidate entity: verdict recorded — adopted (with concrete call-site simplification) or rejected/deferred.
  - [ ] Findings report: each point of raw-GL/global-state/duplicate-logic → new card or "leave inline."

### [R-18] Debug Draw Primitives (3D Gizmos)
- Status: planned (~10%) | Priority: P2 | Area: Render/Tooling
- Value: Ready-made debug/visualization primitives (axes, arrows, grid, box, sphere, capsule) without hand-rolling gizmos in every demo.
- Scope:
  - **Solids** (primary): cached `TGpuMesh` from R-20 MeshShapes, lit by stock mesh shader, colour via `materialColor` tint uniform. Set: `Arrow3D`, `Axes`, `Box`, `Sphere`, `Capsule`.
  - **Lines** (exception): `Grid`, `Arrow2D`, `BoxWire`, `Line` — immediate `draw.Line3D`.
  - **Session model**: `SetupRender`/`Flush`; no retained queue. Batching deferred to R-09 Track C.
  - `materialColor` tint uniform: implements `shader.Material` colour in mesh-path only; painter untouched; default white = no-op.
  - Showcase folded into `demo/MeshLab` (no separate demo/DebugDraw).
- Out of scope: 3D line batching (→ R-09 Track C); retained draw queue with per-shape duration; oriented box `BoxM`; specular in `shader.Material`.
- Acceptance Criteria:
  - [ ] `Apus.Engine.DebugDraw` provides solid set + line set without modifying `IDrawer`/`TDrawer`.
  - [ ] Solid shapes rendered as cached `TGpuMesh` via stock mesh shader + `materialColor` tint.
  - [ ] `demo/NormalMap` `DrawGrid` ported onto `DebugDraw` with equivalent visuals.
  - [ ] `demo/MeshLab` showcases all primitives.
  - [ ] Compiles FPC+Delphi, Win/Linux.
- Implementation plan (T1–T5): `Work/reports/R-18_implementation_plan.md`. Design: `Work/reports/R-18_debug_shapes.md`.

### [R-19] Mesh Representation Unification & Rework
- Status: **done** (geometry level, 2026-06-12)
- `TGpuLayout` + SoA `TMesh` + `TGpuMesh` + geometry-only OBJ loader. Headless gates pass; MeshLab author-validated. Design: `Work/reports/R-19_mesh_design.md`.
- Moved OUT: `TModel`/AEM + GPU-skin/instancing → R-03; legacy migration (`Mesh3D`→`Mesh` rename, IQM drop) → deferred.

### [R-20] Mesh Shape Generators (Procedural Primitives)
- Status: **done** (2026-06-13)
- 5 generators (Box/Cylinder/Plane/Octasphere/UVSphere) + `TMesh.Append`. 59 tests pass Win32/Win64. Design: `Work/reports/R-20_meshshapes_design.md`.
- Note: Plane uses XY/+Z orientation (author decision; differs from design doc's XZ/+Y).

### [R-21] Mesh Editing Operations (Stateful Wrapper)
- Status: idea | Priority: P2 | Area: Render/Tooling
- Value: A home for topology-heavy mesh operations (smoothing, subdivision, decimation, boolean, bridge) that share expensive derived structures, without bloating the lean `TMesh` container.
- Disposition: **design now, build on demand.** No commitment to implement yet — the first real heavy consumer gates the build (otherwise we design adjacency/BVH against imaginary ops).
- Model — hybrid:
  - **One-pass, structure-free ops** (ComputeNormals/ComputeTangents/Weld/RecalculateBounds/Flip) stay as plain unit-level procedures in `Apus.Engine.Mesh` — no wrapper, no ceremony at the call site. (ComputeTangents lands here via R-06.)
  - **Heavy ops sharing a derived structure** get a stateful coordinator (`TMeshEditor`) that builds the structure once and dirty-tracks it across a chain of edits.
- Derived structures are **detachable first-class objects**, not private fields of the editor:
  - `TMeshAdjacency` (vertex→faces, vertex→vertex, edge→faces / half-edge)
  - `TMeshSpatial` (octree / BVH / hash — variant chosen per query: weld/raycast/boolean)
  - `TMeshTags` (per-vertex / face / edge marks)
  - Lifetime owned by the holder: can be passed into the editor (reuse), detached and kept after editing (e.g. an octree surviving as a runtime accelerator), or dropped. The editor coordinates + invalidates them while editing; once detached, a structure is a snapshot whose validity is the holder's contract.
- Orientation op: **bridge** — join two loops/polylines with a surface (the join itself only; boundary/loop *selection* is a separate subtask). Reveals that even one op splits across the hybrid: bridging two raw polylines is pure construction (one-pass/generator), bridging two boundary loops of a live mesh needs adjacency (editor).
- Out of scope (until a driver appears): concrete heavy ops, the editor's public API shape, structure internals (half-edge layout, BVH vs octree).
- Note: detailed design deferred to a `Work/reports/R-21_*` doc when promoted to a real card. Background: discussed 2026-06-17 alongside R-06/R-19.

### [R-22] Toast Notifications (Implement + Extend `FireMessage`)
- Status: **implemented** (2026-06-20, commit `d489ef8` on engine5) | Priority: P2 | Area: UI / Core Runtime
- GOT: `Apus.Engine.Notifications` as a scene-less overlay provider (sibling of debug overlays, NOT a scene — non-modal/transient fits the overlay slot, not MessageScene). `ShowToast` overloads + `TToastKind`/`TToastAnchor` (4: BottomRight default/BottomCenter/BottomLeft/Center) + `toastConfig` + `TToastOptions`. Auto duration `clamp(2,len/25,5)`. Themed via R-05 `Styles` (`toast.<kind>` blocks, translucent fill+border, opaque text, app-overridable). SML text + author breaks + plain word-wrap. Stacking with reflow lerp, dissolve in/out, hover-freezes countdown, click-dismiss; thread-safe ingest (`TLock`). `FireMessage`→`ShowToast`; `DrawOverlays`→`DrawNotifications`; screenshot save + Alt+F11 VSync toggle are the live callers. Design: `Work/reports/R-22_notifications_design.md`.
- Deferred (not built, "по мелочам"/future): cross-line SML spans in wrap, R-05 9-patch/icon look, top/edge anchors, OS-native/tray, history, sound, in-toast buttons. No headless test (render/timing-bound).
- TODO: replace manual lerp/alpha animation in `Notifications` with `TAnimatedValue` or `Tweenings` primitives — dissolve in/out and stack reflow are currently hand-rolled delta-time math; should use the engine animation layer for consistency and curve support.
- Value: A lightweight, non-blocking way to surface transient info to the user (screenshot saved, connected, error, achievement) — the toast/flyout pattern from Windows and Telegram. Distinct from a modal dialog that demands an answer.
- Existing baseline — **this is the surface to build on, not a new one**:
  - `IGame.FireMessage(st:String8)` (`Apus.Engine.API.pas:861`), commented *"Show message in engine-driven pop-up (3 sec)"* — the intended engine-driven toast entry point.
  - The implementation in `Apus.Engine.Game.pas:1538` is an **empty stub with a TODO**; it has been empty since the initial commit (a working version existed in engine4 but was never ported in this refactor). The screenshot hotkey (`RequestScreenshot`, F12/PrintScreen) is the canonical caller that should surface a "saved as …" toast.
  - NOT the same as `Apus.Engine.MessageScene` — that is the **modal** path (`ShowMessage`/`Ask`/`Confirm`, blocking, one-at-a-time queue, Ok/Yes/No, `sweShowModal`). Leave it untouched.
- Scope (implement the stub, then extend it):
  - **Implement `FireMessage`** as a real non-modal timed pop-up (the 3-sec default the comment promises), and wire the screenshot path to call it.
  - **Configuration:** position presets — a 9-anchor grid (center, 4 corners, 4 edge midpoints); default duration; max concurrent/stack count; default fade in/out timing.
  - **Stacking:** multiple toasts visible at once, stacked like OS/Telegram notifications — newest enters, others shift, auto-reflow when one dismisses. (`FireMessage` today is single-shot by contract; stacking is the main extension.)
  - **Auto-dismiss:** per-toast timeout (with sensible default), plus manual dismiss (click/close). Optional persist-until-clicked for important messages.
  - **Per-toast overrides:** duration, position, and optionally severity/icon — overriding the global config. May need a richer overload beyond the bare `FireMessage(st:String8)` signature.
- Open design questions (settle before building):
  - Where the implementation lives: directly in `TGame` vs. a dedicated overlay (new module `Apus.Engine.Notifications` / a non-modal scene) that `FireMessage` delegates to. Leaning toward a delegated overlay — the lifecycle (concurrent + timed) wants its own home.
  - Reuse `TUIScene` + `SceneEffects` for entry/exit animation and the toast container layout; reuse the style system (R-05) for appearance/severity.
  - Coexistence with the modal path: shared z-order discipline so toasts sit above content but below true modal `MessageScene` dialogs.
- Out of scope (until needed): OS-native notification integration (taskbar/tray), notification history/center, sound hooks, action buttons inside a toast.
- Note: discussed 2026-06-17 (author pointed to `FireMessage`/screenshot path as the real baseline). Detailed design deferred to a `Work/reports/R-22_*` doc when promoted to a real card.

### [R-23] Keyboard Input Pipeline Unification (Callbacks over Signals)
- Status: implemented (runtime sign-off + commit pending) | Priority: P1 | Area: Core Runtime / Input
- Value: keyboard input used to flow through **two independent `KBD\*` subscribers** — `TGame.onKbdEvent` (per-scene buffer + `SCENE\<name>\KeyDown` signal + internal hotkeys) and `TUIScene.KbdEventHandler` (focus / `ProcessHotKey`). Running in parallel, a gameplay hotkey (e.g. `[C]`) fired even while typing into a focused/modal field. The fix collapses both into one ordered pipeline, replacing key signals with synchronous callbacks (deterministic order, easier debug; async is now explicit via `Threads`/`Signal` inside a callback).
- **IMPLEMENTED 2026-06-19** (branch `engine5`, compiles x64+x86 on the full demo graph):
  - `KBD\*` is the single platform ingress, consumed only by `TGame`, which buffers into the kbd-topmost scene. `TWindow.OnFrame` drains every active scene via `PumpInput(shift)` before `ProcessScenes` (render-synced, not in `Process`).
  - `TGameScene` (Scene.pas): key buffer split into `keyBuffer` (down/up → dispatched) + `charBuffer` (text → `ReadKey`); `WriteKey` packs `keyCode|scancode<<16|pressed<<24` (key-up included), `WriteChar` feeds char buffer; `SetStatus` clears buffers on leaving active.
  - `DispatchKey(key;scancode;shift;pressed):boolean` = single routing dispatcher, owns the `RegisterHotKey` table (matched on press). `onKeyDown`/`onKeyUp` are final-receiver virtuals (symmetric with `onMouseDown/Up`) — table lives in the dispatcher so a receiver override can't bypass it. `TUIScene.DispatchKey` runs focus/`ProcessHotKey` first, falls to `inherited` (gameplay) only when no element holds focus — the gate that kills `[C]`-while-typing.
  - Removed: `SCENE\..\KeyDown/KeyUp` signal (Game.pas), `TUIScene`'s `SetEventHandler('Kbd',...)`. `ProcessHotKey` (UITypes.pas) now returns `boolean`. `MessageScene` Enter/Escape → button `SetHotKey`.
  - Demos: NormalMap (`RegisterHotKey` showcase), MeshLab (`onKeyDown` override), InputDemo (`onKeyDown`/`onKeyUp` + char via `ReadKey`) — all drop `SetEventHandler`/`WordFromTag`/`RemoveEventHandler`.
- Out of scope (deliberate): `ConsoleScene`/`TweakScene` stay on raw `KBD\KeyDown` (global debug overlays, like `HandleInternalHotkeys`); full hotkey-mechanism unification = architecture-review #6. `ReadKey`/`KeyPressed` polling kept (orthogonal channel); no separate `onChar` hook this pass.
- Pending: runtime/visual sign-off (input now deferred ~1 frame, frame-synced like mouse) + commit.
- Design doc: `Work/reports/scene_onkeydown_design.md`.
