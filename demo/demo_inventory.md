# Demo Inventory

Date: 2026-03-20 (last revised 2026-08-31)

Relevance categories:
- `engine5` - active and maintained demo path for the current engine5 branch.
- `engine4` - working demo on the older stack (partly using old modules/API).
- `legacy` - historical testbed, mainly useful as reference/archive.
- `scaffold` - incomplete demo or project template skeleton.

## Build status (FPC 3.2.2, Win64, 2026-08-31)

Checked with `demo\build_demo_fpc.cmd <Name>` for every demo whose project file
matches its folder name, plus `01-Scenes` and `EngineTest` by hand. Relevance
above says how current a demo is *meant* to be; this table says whether it
compiles today.

Builds (20): `01-Scenes`, `Draw2D`, `InputDemo`, `MeshLab`, `MultiWindow`,
`Networking`, `NormalMap`, `ProjectTemplate`, `ShadowMap`, `Simple3D`,
`SimpleDemo`, `SoundDemo`, `StyleDemo`, `TextDemo`, `TouchDemo`, `Tweenings`,
`UI`, `UIScaleDPI`, `UILab`, `VertexBuffer`.

Broken (9) - all of them still sit on the retired foundation modules:

| Demo | Blocker |
|---|---|
| `AdvTex` | uses the retired `Apus.Common` |
| `Billboards` | uses the retired `Apus.CrossPlatform` |
| `Borderless` | uses the retired `Apus.CrossPlatform` |
| `CharAnimation` | blocked by the engine, not the demo: `Apus.Engine.Model3D` still uses `Apus.Common` |
| `ControllerDemo` | uses the retired `Apus.Common` |
| `EngineTest` | uses the retired `Apus.Common` (legacy demo) |
| `NinePatch` | uses the retired `Apus.Common` |
| `Particles` | uses the retired `Apus.Common` |
| `Shaders` | uses the retired `Apus.CrossPlatform` |

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
| `Networking` | R-27 chat demo: `HttpGameClient` against an in-process `HttpGameServer` over loopback. Advanced login, batched POST send, long-poll comet receive; typed lines round-trip client→server→broadcast→client. | `engine5` |

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
| `SoundDemo` | Console audio-system check (backend selection, music/samples, SOUND signals). Migrated to the foundation API in R-28; script mode runs headless in CI. Audio backends are opt-in, so it builds with `-dSDLMIX`. | `engine5` |

## 5. Incomplete / Transitional / Historical (lowest priority)

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `MultiWindow` | Multi-window support (R-02): main window + tool windows, `AddWindow`/window-scene flow. | `engine5` |
| `ProjectTemplate` | Minimal starter project skeleton (window + simple scene + Exit button). Updated 2026-08-31: current API, R-31 surface presets, Lazarus project added. | `engine5` |
| `EngineTest` | Large old set of manual graphics/resource tests (many modes, includes deprecated API paths). | `legacy` |

## Classification notes

- `engine5` status was assigned to demos explicitly tracked as active in `Work/engine_work_ahead.md` (for example `SimpleDemo`, `01-Scenes`, `VertexBuffer`, `MultiWindow`, `UIScaleDPI`) and/or used as current test vehicles.
- Most remaining demos still sit on older API layers (`Apus.Common`, `Apus.CrossPlatform`) and were marked `engine4`.
- `EngineTest` is marked `legacy` because it is a historical monolithic test program with deprecated branches.
- `ProjectTemplate` is deliberately minimal (a copy-and-go skeleton, not a feature showcase), but it is kept on the current API and must compile at all times - it is the first thing a new project is copied from.
