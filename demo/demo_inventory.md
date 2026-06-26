# Demo Inventory

Date: 2026-03-20

Relevance categories:
- `engine5` - active and maintained demo path for the current engine5 branch.
- `engine4` - working demo on the older stack (partly using old modules/API).
- `legacy` - historical testbed, mainly useful as reference/archive.
- `scaffold` - incomplete demo or project template skeleton.

## 1. Core Validation Demos (highest priority)

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `SimpleDemo` | Core end-to-end engine demo (App/Scene/UI/particles/config), frequent smoke/runtime testbed. | `engine5` |
| `01-Scenes` | Scene lifecycle and scene switching, transition effects, modal/window scenes, UI signals. | `engine5` |
| `UIScaleDPI` | DPI-aware UI scaling (`actualScale=dpiScale*userZoom`), runtime DPI test vehicle. | `engine5` |
| `VertexBuffer` | Low-level mesh/vertex-buffer rendering, stress path for 3D draw pipeline. | `engine5` |
| `Simple3D` | Basic 3D pipeline: meshes (`OBJ`), camera, transforms, textures. | `engine5` |
| `NormalMap` | R-06 prototype: local tangent-space normal-map shader, generated materials, orbit camera/light diagnostics. | `engine5` |
| `Draw2D` | Full gallery of 2D primitive drawing (`Line/Polyline/Polygon/Rect/RRect/RoundRect/Fill*/Gradient/TexturedRect`) in a standalone modern demo. | `engine5` |
| `InputDemo` | Input diagnostics in low-level style: overview, keyboard/mouse deep views, high-rate mouse trace, polling vs events, stress counters. | `engine5` |

## 2. UI and Gameplay Framework Demos

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `UI` | UI widgets, layouts, and interactions; primary UI showcase on the old path. | `engine4` |
| `NinePatch` | Nine-patch rendering and stress checks for UI size/scaling behavior. | `engine4` |
| `Tweenings` | Tweening API: click-to-move animation, basic interpolation/easing verification. | `engine5` |
| `Borderless` | Borderless/resizable window mode plus basic UI (exit button). | `engine4` |

## 3. Graphics and Rendering Feature Demos

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `Particles` | Particle scenarios (basic/galaxy/soft), 2D/3D particles and effects. | `engine4` |
| `Shaders` | Shader rendering checks (including round-rect/custom shader snippets). | `engine4` |
| `AdvTex` | Advanced texturing: texture array, manual mip levels, direct texture access, shader path. | `engine4` |
| `Billboards` | 3D billboards, camera/zoom behavior, sprite rendering in 3D space. | `engine4` |
| `CharAnimation` | Loading/rendering animated character (`IQM`), basic 3D character pipeline. | `engine4` |
| `ShadowMap` | 3D scene with shadow map pass, custom shader files, and OBJ geometry loaded through the engine5 `TGpuMesh` path. | `engine5` |

## 4. Platform and Subsystem Demos (specialized)

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `ControllerDemo` | Gamepad/joystick input, SDL platform path, UI navigation from controller. | `engine4` |
| `SoundDemo` | Console audio-system check (backend selection, music/samples, SOUND signals). | `engine4` |

## 5. Incomplete / Transitional / Historical (lowest priority)

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `MultiWindow` | Multi-window support (R-02): main window + tool windows, `AddWindow`/window-scene flow. | `engine5` |
| `ProjectTemplate` | Minimal starter project skeleton (window + simple scene + Exit button). | `scaffold` |
| `EngineTest` | Large old set of manual graphics/resource tests (many modes, includes deprecated API paths). | `legacy` |

## Classification notes

- `engine5` status was assigned to demos explicitly tracked as active in `Work/engine_work_ahead.md` (for example `SimpleDemo`, `01-Scenes`, `VertexBuffer`, `MultiWindow`, `UIScaleDPI`) and/or used as current test vehicles.
- Most remaining demos still sit on older API layers (`Apus.Common`, `Apus.CrossPlatform`) and were marked `engine4`.
- `EngineTest` is marked `legacy` because it is a historical monolithic test program with deprecated branches.
- `ProjectTemplate` is marked `scaffold` due to its template/incomplete functional scope.
