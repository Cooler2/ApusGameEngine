# Demo Inventory

Date: 2026-06-09

Relevance categories:
- `engine5` - active and maintained demo path for the current engine5 branch.
- `engine4` - working or partially working demo on the older stack.
- `legacy` - historical testbed, mainly useful as reference/archive.
- `scaffold` - project template or intentionally minimal skeleton.
- `blocked` - present in the tree, but missing required metadata or has a known build blocker.

## 1. Active Engine5 Demos

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `SimpleDemo` | Core end-to-end engine demo (App/Scene/UI/particles/config), frequent smoke/runtime testbed; target is replacement by `HelloEngine`. | `engine5` |
| `HelloEngine` | Compact onboarding demo: procedural texture/sprite, text rendering, UI button callback, and signal-linked exit button. | `engine5` |
| `01-Scenes` | Scene lifecycle and scene switching, transition effects, modal/window scenes, UI signals. | `engine5` |
| `Draw2D` | Full gallery of 2D primitive drawing (`Line/Polyline/Polygon/Rect/RRect/RoundRect/Fill*/Gradient/TexturedRect`) in a standalone modern demo. | `engine5` |
| `InputDemo` | Input diagnostics: overview, keyboard/mouse deep views, high-rate mouse trace, polling vs events, stress counters. | `engine5` |
| `TextDemo` | Text rendering showcase: bitmap/FreeType paths, Unicode, formatting, alignment, scaling, and predictable test text. | `engine5` |
| `StyleDemo` | R-05 style-system showcase: default/custom styles, named style refs, state blocks, and runtime style updates. | `engine5` |
| `UI` | UI widgets, layout, and interactions; still needs later R-10-oriented refresh. | `engine5` |
| `UIScaleDPI` | DPI-aware UI scaling (`actualScale=dpiScale*userZoom`), runtime DPI test vehicle. | `engine5` |
| `MultiWindow` | Multi-window support (R-02): main window + tool windows, `AddWindow`/window-scene flow. | `engine5` |
| `VertexBuffer` | Low-level mesh/vertex-buffer rendering, stress path for 3D draw pipeline. | `engine5` |
| `Simple3D` | Basic 3D pipeline: meshes (`OBJ`), camera, transforms, textures; target is `Scene3D`. | `engine5` |
| `NormalMap` | R-06 feature demo/prototype: tangent-space normal mapping, generated materials, orbit camera/light diagnostics; target is a standalone feature-tier demo once normal mapping is engine-level functionality. | `engine5` |
| `Tweenings` | Tweening API: click-to-move animation and basic interpolation/easing verification; target is `Animation`. | `engine5` |

## 2. Legacy Demos to Merge or Modernize

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `NinePatch` | Nine-patch rendering and stress checks for UI size/scaling behavior; target is merge into `Draw2D`. | `engine4` |
| `ControllerDemo` | Gamepad/joystick input, SDL platform path, UI navigation from controller; target is merge into `InputDemo`/`Input`. | `engine4` |
| `SoundDemo` | Console audio-system check (backend selection, music/samples, SOUND signals); target is GUI `Sound`. | `engine4` |
| `Borderless` | Borderless/resizable window mode plus basic UI; target is merge into `Platform`. | `engine4` |
| `Shaders` | Shader rendering checks, including custom shader snippets; target is modern `Shaders`. | `engine4` |
| `AdvTex` | Advanced texturing: texture array, manual mip levels, direct texture access, shader path; target is `AdvancedGfx`. | `engine4` |
| `ShadowMap` | 3D scene with shadow-map pass and custom shader files; target is `AdvancedGfx`. | `engine4` |
| `Particles` | Particle scenarios (basic/galaxy/soft), 2D/3D particles and effects; target is move-as-is performance demo. | `engine4` |
| `Billboards` | 3D billboards, camera/zoom behavior, sprite rendering in 3D space; target is move-as-is performance demo. | `engine4` |
| `CharAnimation` | Loading/rendering animated character (`IQM`), basic 3D character pipeline; target is modern `CharAnimation`. | `engine4` |

## 3. Scaffold and Historical Testbeds

| Demo | What it demonstrates / tests | Relevance |
|---|---|---|
| `ProjectTemplate` | Modern starter project skeleton (window + one scene + signal-linked Exit button); target is `1-start/ProjectTemplate`. | `scaffold` |
| `EngineTest` | Large old set of manual graphics/resource tests, many modes, and deprecated API paths; target is case-by-case distribution, then removal. | `legacy` |

## S00 Checks

- Current demo folders with `.dpr` files are all represented above.
- `StyleDemo` and `UIScaleDPI` previously lacked `.dproj` files; S01 covers their project metadata.
- Demos still using deprecated imports such as `Apus.Common` or `Apus.CrossPlatform`
  are kept as `engine4` unless they are already active engine5 validation vehicles.
- Target placement and action details live in `demo_plan.md` and `demo_execution_plan.md`.
