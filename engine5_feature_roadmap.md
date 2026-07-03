# Engine5 Feature Roadmap
Last updated: 2026-06-27

Language policy: this roadmap is maintained in English.

This file captures what remains to be done. Completed stage notes live in Work/.

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
| R-05 | CSS-Like UI Style System | in-progress | ~80% | Token/theme foundation landed; remaining: migrate hardcoded widget colors into themed styles, distinct `selected` state, selective-inheritance fix, real-screen validation, visual regression tests |
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
| R-16 | Console Modernization | in-progress | ~90% | Scroll rework (sticky-bottom/ScrollToEnd), SDL editbox Enter |
| R-17 | 3D Game Architecture Probe | idea | 0% | Top-down 3D skeleton to expose architecture white spots |
| R-18 | Debug Draw Primitives (3D Gizmos) | planned | ~10% | `materialColor` tint uniform; solid/line sets; MeshLab showcase; NormalMap port |
| R-19 | Mesh Representation Unification & Rework | done | 100% | — |
| R-20 | Mesh Shape Generators (Procedural Primitives) | done | 100% | — |
| R-21 | Mesh Editing Operations (Stateful Wrapper) | idea | 0% | Design-now / build-on-demand; first heavy consumer gates implementation |
| R-22 | Toast Notifications (Implement + Extend `FireMessage`) | implemented | 100% | `Apus.Engine.Notifications` overlay; ShowToast/kinds/anchors/config, R-05-themed, SML, stacking+dissolve, hover-freeze; committed `d489ef8` on engine5 |
| R-23 | Keyboard Input Pipeline Unification (Callbacks over Signals) | done | 100% | Collapsed 2 parallel `KBD\` consumers into one ordered `PumpInput`→`DispatchKey` pipeline; key signals dropped; scene `RegisterHotKey`. Compiles x64+x86; demos ported. Committed (`f811e93`..`361bb9a`) on engine5 |
| R-24 | Android Platform Revival | idea | 0% | Restore Android/GLES build and runtime path on the current Engine5 platform/graphics/input/resource architecture |
| R-25 | Immediate Mode GUI API Wrapper | idea | 0% | ImGui-like frame API backed by existing `TUIScene`/`TUIElement` widgets; first target is developer/debug UI and runtime tuning panels |
| R-26 | Mouse/Pointer Input Pipeline Unification | done | 100% | Window-level mouse dispatch (single hit-test/frame), `TMoveKind`, capture-aware button delivery; mouse-side analogue of R-23 |
| R-27 | Networking Demo + Server-Side Code (Astral Heroes server as base) | planned | ~5% | Base a demo on the existing AH server; assess which server code to extract into the engine; give `HttpGameClient` a real counterpart + loopback integration tests |
| R-28 | Audio Subsystem Activation | planned | ~10% | Research done, decisions locked (miniaudio primary, 2-tier requirements, typed facade); next: implement per `Work/R-28_audio_activation.md` plan T1–T7 |
| R-29 | Apple Platform Support (macOS + iOS) | idea | 0% | Stage-0 recon (FPC arm64-darwin/iOS toolchain go/no-go, GL 4.1 ceiling, SDL iOS path); cheap win = macOS in `base-tests` CI; later split into Darwin-portability / macOS-SDL-runtime / iOS-shell / Apple-graphics-backend cards |

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
- [ ] E4. Restore Android as a supported mobile target
- [ ] E5. Add Apple (macOS desktop + iOS) as supported targets

### F. Core Runtime & Scenes
- [ ] F2. Safe scene transitions (including async loading)
- [ ] F3. Lifecycle diagnostics and error logging

### G. UI System
- [ ] G1. Core widgets with consistent behavior
- [ ] G2. Layout engine (adaptive behavior, alignment, spacing)
- [ ] G3. Testability of UI logic and events
- [ ] G4. Immediate-mode API wrapper for fast developer/debug UI on top of retained widgets

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
- Plan: `Work/R-02_multiwindow_plan.md`

### [R-03] Native AEM Pipeline + Blender Export
- Status: planned (~15%) | Priority: P1 | Area: Resources
- Value: Make AEM the native high-performance path for models/animations, with a Blender export plugin.
- Scope: finalize AEM model/animation capabilities; define compact encoding; implement Blender exporter.
- Out of scope: full DCC ecosystem beyond Blender in first iteration.
- Acceptance Criteria:
  - [ ] Runtime supports AEM model + animation for at least one production-like asset.
  - [ ] Ultra-compact encoding mode documented and loadable.
  - [ ] Blender plugin exports valid AEM without manual conversion.
- Notes: pipeline direction fixed — OBJ (baseline) + AEM (native); no FBX/DAE converter. `TModel`/`TModelInstance` design lives here (carved out of R-19). This is also the home of the **3D preview vertical slice** (work-ahead Do-Next #2) — and the **`demo/CharAnimation` revival is its showcase target**: CharAnimation currently runs on the legacy `TModel3D`+`IQMloader` path (IQM was dropped by R-19), so do NOT revive it on legacy IQM — bring it back on the new `TModel`/`TModelInstance`+animation-runtime path as the skeletal-animation showcase that closes the "Engine5 looks weaker than Engine4's skeletal/shadow demos" gap. Plan: `Work/R-03_aem_pipeline_notes.md`.

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
- Design: `Work/R-05_notes.md`

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
- Plan: `Work/R-06_normal_mapping_plan.md`

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
- Plan: `Work/R-07_geometry_library_plan.md`

### [R-08] UI Hit-Test for Out-of-Bounds Children
- Status: **done**
- Clip-threaded `FindElementAt` with `escapingOnly` mode for deep `noParentClip` descendants. Details: `Work/R-08_hittest_overlay_notes.md`.

### [R-09] GL Performance Modernization (Diagnose-First)
- Status: in-progress (~40%) | Priority: P1 | Area: Render
- Value: CPU/GPU efficiency improvements driven by measurement, not speculative batching.
- Key finding: no cheap 4.x wins remain standalone — real per-draw cost is `glBufferSubData` stream sync, which pays off only with R-12 (persistent ring-buffer) + Track C. **Next blocker: NSight baseline (author runs it).**
- Tracks:
  - **A — Telemetry** (done): per-frame draw/shader/texture/scissor counters in debug overlay.
  - **B — Cheap state wins** (done): redundant `glBindBuffer`/`glVertexAttribPointer`/`glUseProgram` eliminated.
  - **C — Opt-in batch API** (pending): `draw.Batching(on/off)` coalesces same-signature primitives; flushes on type/texture/state change. Target: tilemaps, sprite fields; integration seam for R-18 DebugDraw.
  - **D — GL 4.x research** (drafted): `Work/R-09_gl4x_research.md`.
- Remaining:
  - [ ] NSight baseline on a representative real scene; bottleneck documented.
  - [ ] Track C `draw.Batching` implemented if real use case warrants it.
- Journal: `Work/R-09_notes.md`

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
- Notes: gated on NSight baseline from R-09 Track A. Targets the 2D/text painter path (R-19 §15 COEXIST left it untouched). GL 4.4 persistent-mapped-buffer option tracked in `Work/R-09_gl4x_research.md`.
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
  - [x] Draw2D absorbs NinePatch and EngineTest cases — NinePatch (procedural stretch/tiled/animated) + clip/blend screens added (10 screens); compiles FPC x64; old `demo/NinePatch` removed. Remaining EngineTest 2D cases covered (mesh image-deform left for AdvancedGfx)
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
- Plan: `Work/R-16_console_modernization.md`

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
- Implementation plan (T1–T5): `Work/R-18_implementation_plan.md`. Design: `Work/R-18_debug_shapes.md`.

### [R-19] Mesh Representation Unification & Rework
- Status: **done** (geometry level, 2026-06-12)
- `TGpuLayout` + SoA `TMesh` + `TGpuMesh` + geometry-only OBJ loader. Headless gates pass; MeshLab author-validated. Design: `Work/R-19_mesh_design.md`.
- Moved OUT: `TModel`/AEM + GPU-skin/instancing → R-03; legacy migration (`Mesh3D`→`Mesh` rename, IQM drop) → deferred.

### [R-20] Mesh Shape Generators (Procedural Primitives)
- Status: **done** (2026-06-13)
- 5 generators (Box/Cylinder/Plane/Octasphere/UVSphere) + `TMesh.Append`. 59 tests pass Win32/Win64. Design: `Work/R-20_meshshapes_design.md`.
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
- Note: detailed design deferred to a `Work/R-21_*` doc when promoted to a real card. Background: discussed 2026-06-17 alongside R-06/R-19.

### [R-22] Toast Notifications (Implement + Extend `FireMessage`)
- Status: **done** (2026-06-20) | commits `d489ef8`, `eef94aa` on engine5
- `Apus.Engine.Notifications` overlay: `ShowToast`/kinds/4 anchors/`toastConfig`, R-05-themed, SML, stacking+dissolve via `TTweening`, hover-freeze, click-dismiss, thread-safe ingest. `FireMessage`→`ShowToast`. Design: `Work/R-22_notifications_design.md`.
- Deferred: cross-line SML spans, 9-patch/icon look, top/edge anchors, OS-native/tray, history, sound, in-toast buttons.

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
- Mouse-side analogue: see **R-26** (window-level mouse dispatch); same "callbacks/single dispatch over per-scene loops" direction.
- Design doc: `Work/scene_onkeydown_design.md`.

### [R-24] Android Platform Revival
- Status: idea | Priority: P1 | Area: Platform / Build / Mobile
- Value: Restore Android as a real supported Engine5 target instead of legacy code behind stale project metadata. A working Android path proves the platform layer, GLES renderer, resource loading, touch/input, and mobile audio abstractions are not desktop-only assumptions.
- Restoration spike, not a full mobile port. Five staged layers: bootstrap/lifecycle, window/GLES context, GLES renderer, input, resources/audio. Leaning SDL-first (Android as "just another SDL target") to reuse the existing platform/graphics/audio abstractions; native JNI bridge kept as a documented follow-up. `Apus.Engine.AndroidGame.pas` (blocked in `InitObjects`, references removed `PainterGL2`) is the explicit restoration seam.
- Out of scope for MVP: iOS revival, store packaging polish, push, background services, full gamepad coverage, Android UI skins.
- Acceptance Criteria:
  - [ ] A minimal Engine5 demo builds for Android64 from documented steps.
  - [ ] The demo starts, creates a GLES context, renders a textured/UI scene, and exits cleanly.
  - [ ] Assets load from APK/package resources and writable app storage is documented.
  - [ ] Touch input and text input reach the unified Engine5 input/UI path.
  - [ ] At least one baseline sound/media playback path is verified or explicitly deferred.
  - [ ] Android code paths compile without deprecated `PainterGL`/`PainterGL2`.
- Design / options / staging / build process: `Work/R-24_android_revival.md`.

### [R-25] Immediate Mode GUI API Wrapper
- Status: idea | Priority: P2 | Area: UI / Tooling
- Goal: add an ImGui-like API wrapper for quickly declaring developer-facing UI each frame, without replacing the existing retained UI system.
- Value: make debug panels, runtime tuning controls, demo knobs, lightweight inspectors, and future `TweakScene`-style tools cheap to write and easy to remove, while keeping the engine's current input, focus, style, DPI, Robot API, and widget rendering path.
- Direction: **hybrid immediate-over-retained**. User code calls `BeginFrame`/`BeginWindow`/`Button`/`SliderFloat`/`Checkbox` each frame; the implementation keeps a stable cache of `TUIElement`/`TUIButton`/`TUIEditBox`/`TUIWindow` instances keyed by immediate IDs and updates/hides them at `EndFrame`.
- First scope:
  - [ ] `Apus.Engine.ImUI` context with `BeginFrame(root)` / `EndFrame`.
  - [ ] window/panel stack, vertical cursor layout, stable ID stack (`PushID`/`PopID`).
  - [ ] MVP widgets: `Text`, `Button`, `Checkbox`, `SliderFloat`, `InputText`, separator/spacer.
  - [ ] optional overlay scene for debug tools, plus direct use over any `TUIScene`.
  - [ ] demo or UI Lab section showing a stats/tuning panel and at least one editable value.
- Out of scope for MVP: docking, tables, complex popups/menus, custom skin editor, a second independent hit-test/input/rendering system, replacing production retained UI screens.
- Acceptance Criteria:
  - [ ] A demo panel can be rebuilt every frame from immediate calls without leaking UI elements or losing stable interactive state.
  - [ ] Button click, checkbox toggle, float slider, and text edit round-trip through caller-owned variables.
  - [ ] Controls use existing `TUIScene` input/focus/style/rendering behavior and appear in Robot API UI tree diagnostics.
  - [ ] Duplicate labels can be disambiguated with `PushID` or explicit IDs.
  - [ ] The retained widget tree is pruned/hidden predictably when immediate calls disappear.
  - [ ] The first implementation compiles on Delphi/FPC and does not require new external libraries.
- Design note: `Work/R-25_immediate_mode_gui.md`.

### [R-26] Mouse/Pointer Input Pipeline Unification (Window-Level Dispatch)
- Status: **done** (2026-06-25) | Priority: P1 | Area: Core Runtime / Input
- Value: mouse input used to run a per-scene `NotifyScenesMouse*` loop — every active `TUIScene` re-ran the same hit-test, causing double-toggle when scenes overlapped, and button release could miss a capturing element. The mouse-side analogue of R-23 (keyboard): one ordered window-level dispatch instead of parallel per-scene consumers.
- Implemented (committed on `engine5`, `1083666f` + capture/drag fixes `e20e4f18`/`c3ceaa48`/`f87c8413`/`ac8e0385`):
  - `DispatchMouseMove/Button/Wheel` in `UIScene`: hit-test + UI delivery happen once per window per frame (fixes double-toggle on overlapping active scenes).
  - `TMoveKind` (`mkLeave/mkMove/mkEnter`) on move events so a gameplay scene distinguishes in-world motion from the cursor crossing onto/off a consuming UI element; dispatcher tracks prev-frame `overUI` on the window. Demos/tools moved from `underMouse.GetRoot` guards to `window.moveKind=mkMove`.
  - Capture-aware button delivery: while an element holds the mouse (`hooked`/`cmVirtual`), button events go to it so it can end the capture (fixes frozen subtree after a slider drag); `onMouseMove` reaches `cmVirtual`-captured elements during drag.
  - Wheel consumed by a real control; buttons still forwarded to all active scenes (TweakScene/StyleDemo right-click bind rely on it); disabled UI roots skipped so fading scenes stop receiving input.
- Out of scope: full pointer-occlusion/capture parity on SDL (tracked in `Work/engine_work_ahead.md` release-tail).

### [R-27] Networking Demo + Server-Side Code (Astral Heroes server as base)
- Status: planned (~5%) | Priority: P1 | Area: Networking / Tooling
- Value: `Apus.Engine.HttpGameClient` (former `Networking3`) is a client of an online game service (accounts/auth, long-poll + batched POST over HTTP) that currently has **no server to talk to** — it is effectively dead, untestable code. The original counterpart it was written against is the **Astral Heroes server** (author-owned, external to this repo). Base it on that instead of building a server from scratch.
- Direction: take the AH server as the reference/starting point; build a demo where the engine client talks to a running server; **assess which parts of the server code are generic enough to extract into the engine/Base** (candidate: an `Apus.HttpServer` over `Apus.Socket`/`Apus.TCP`, reusing `Apus.HttpRequests` parsing and/or `Apus.SCGI`) versus what stays game-specific demo code. The extraction scope is itself part of the task — decide, don't assume.
- Existing building blocks: `Apus.Socket` → `Apus.TCP` → `Apus.HttpRequests` (client-side parse), `Apus.SCGI` (server protocol). No HTTP server class yet.
- Scope:
  - Stand up the AH server (or a trimmed slice of it) as the demo backend.
  - A demo where `HttpGameClient` performs a real session against it (account/auth, message round-trip).
  - Extract reusable server pieces into the engine/Base where it clearly pays off; keep game-specific logic demo-local.
  - Add loopback integration tests for the networking stack (`Socket`→`TCP`→`HttpRequests`→`HttpGameClient`) runnable in CI.
- Out of scope: a general-purpose production web server; full AH server feature parity; replacing the existing AH backend.
- Open assessment (decide during the task): how much of the AH server is generic vs game-specific; whether `Apus.SCGI`/`Apus.TCP` already cover the listener/accept needs or a new `Apus.HttpServer` is warranted; licensing/dependency footprint of the server code.
- Acceptance Criteria:
  - [ ] A demo runs the engine client against the server over loopback (auth + message round-trip).
  - [ ] At least one networking integration test runs in CI (Win+Linux) on the loopback path.
  - [ ] A recorded decision on what (if anything) moves into the engine/Base, and where.

### [R-28] Audio Subsystem Activation
- Status: planned (~10%, research done, decisions locked) | Priority: P2 | Area: Audio
- Working doc (authoritative for detail): `Work/R-28_audio_activation.md` — code inventory, backend landscape, decisions, plan T0–T8.
- Value: Strategic direction J is entirely untouched — no validated audio path on Engine5. Key finding: audio is dead by build configuration (backends gated behind `IMX`/`SDLMIX` defines absent from the standard define set), not by runtime bugs.
- Decisions locked (2026-07-03):
  - Primary backend: **miniaudio** (public-domain, per-platform backends under one API, null device for headless CI; own Pascal binding + prebuilt `apusaudio` binaries committed to `bin*/`, sources in `extra/miniaudio/`). SDL2_mixer = temporary debug crutch only; BASS 2.4 = optional alternative (x64 fine; licensing cost for commercial use).
  - Two-tier requirements: level 1 (gate) = play samples+music as-is + volume control; level 2 (full R-28) = loops/loop points, fades/crossfades, pitch, panning.
  - MOD/tracker music: not required by default backend (optional backend path if ever needed).
  - Typed facade `Sound.Play(...):TChannelHandle` added; `SOUND\` signals remain as transport over it.
  - Legacy `SoundBass`/`SoundImx` removal = bonus stage, non-blocking.
- Out of scope (deferred): full backend unification (J1); spatial/3D audio; effects/DSP; BASS backend implementation; Android/AAudio validation (→ R-24).
- Acceptance Criteria (tiered; full list in working doc §8):
  - [ ] Level 1: one backend reliably plays samples and streams music on Win64+Linux; global/per-channel volume.
  - [ ] Level 2: loops incl. loop points; smooth `SlideChannel` (volume/pan/speed) on live channels; music crossfades in all modes.
  - [ ] GUI `SoundDemo` covers both tiers; headless CI test (null backend) covers at least level 1.
  - [ ] The backend/platform decision and its limits are documented.

### [R-29] Apple Platform Support (macOS + iOS)
- Status: idea | Priority: P2 | Area: Platform / Build / Mobile
- Value: bring Apple platforms back as real Engine5 targets — macOS arm64 as a working desktop platform (and a portability proof for Darwin/Apple-Silicon/native-libs), iOS arm64 as the primary Apple mobile target with its own lifecycle/view/input/graphics/packaging. The existing iOS code (`Apus.Engine.IOSgame.pas`, `EAGLViewU.pas`) is near-fully commented-out OpenGL ES 1.1 legacy — historical hints, not a backend.
- Umbrella card. This stays a single low-priority entry until **Stage-0 recon** produces a go/no-go; per the doc's step 5 it then splits into separate cards: Darwin portability, macOS SDL runtime, iOS platform shell, Apple graphics backend.
- Direction / open assessments (decide during recon, do NOT assume):
  - **SDL-first for BOTH macOS and iOS.** Unix already runs through `TSDLPlatform`; macOS-via-SDL2 is cheap. SDL2 also ships a maintained iOS UIKit backend (lifecycle/touch/orientation/safe-areas/GL-ES/Metal-view) — evaluate reusing it as option 0 **before** committing to a hand-written native iOS shell. Native Objective-Pascal (`objcclass`) shell stays a documented fallback.
  - **FPC toolchain viability is gate-zero.** Confirm FPC arm64-darwin (macOS) and especially the iOS device target produce a signable, Xcode-integrable binary — this is the riskiest, least-trodden part and must be settled before any hardware spend or hardware-purchase decision (the latter lives in the design doc, not here).
  - **macOS GL ceiling = 4.1** (deprecated, frozen): no compute/SSBO/DSA, and **no GL 4.4 persistent-mapped buffers** — this constrains R-12 (streaming buffers) and the R-09 Track D / `Work/R-09_gl4x_research.md` GL-4.x path. OpenGL is transitional on Apple only.
  - **Metal backend = long-term + an architecture probe.** A real Metal backend doubles as a stress-test of whether `IGraphicsSystem` is a true abstraction or GL-in-disguise (kin to R-17); likely its own large card, not a sub-bullet of an iOS MVP.
  - **SDL3 / `SDL_GPU` — evaluate, but parked to a major-version boundary (engine5.1 / engine6), NOT engine5.** Attractive because `SDL_GPU` (Vulkan/Metal/D3D12) could give a Metal path without hand-writing Metal, and SDL3 main-callbacks (`SDL_AppInit/AppIterate/AppEvent`) fit iOS/Web lifecycle where the loop is system-owned. Against, for now: SDL2→SDL3 is a migration (not drop-in) touching platform layer + shader pipeline + graphics abstraction at once; FPC SDL3 bindings are immature vs the settled `sdl2` unit; `SDL_GPU` needs precompiled shaders (SPIR-V/MSL via `SDL_shadercross`), breaking the current runtime-GLSL workflow in `ShadersGL.pas`. So Apple MVP stays SDL2/GL; SDL3 is a candidate for the renderer-decision recon and a future major version.
- Cheapest independent win (can start now, decoupled from mobile): add `macos-latest` to the `base-tests` CI matrix (FPC via Homebrew) — catches Darwin/case-sensitive-path/pointer-size issues and backs the cross-platform claim in CLAUDE.md.
- Out of scope (until recon unblocks): full Metal renderer, App Store/TestFlight packaging polish, Intel/universal binaries (add only if proven needed), Simulator-as-primary, hardware-purchase recommendation (stays in the design doc).
- Acceptance Criteria (umbrella — refined when split):
  - [ ] Stage-0 recon report with FPC macOS+iOS toolchain go/no-go and a chosen iOS renderer (revive GL ES for an arch probe vs. go straight to Metal).
  - [ ] Base builds and tests pass on macOS arm64 in CI.
  - [ ] Selected engine units/demos compile on macOS; SimpleDemo runs via SDL2/OpenGL with a Robot-API smoke.
  - [ ] A minimal scene launches and exits cleanly on a physical iPhone.
- Design / staging / infra / hardware notes: `Work/macos_ios_support_plan_ru.md`.
