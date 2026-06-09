# Demo Plan (Target State)

Date: 2026-03-22

This document defines the target demo structure for Engine5.
For the current state of demos, see `demo_inventory.md`.
For ordered implementation steps, see `demo_execution_plan.md`.

## Goals

Demos serve these purposes:
1. **New user onboarding** — progressive learning path from minimal to advanced.
2. **API reference** — each subsystem has exactly one demo showing its full API surface.
3. **Test base** — CI can build and run all demos; Robot API can validate via screenshot/pixel.
4. **Complex showcases** — integrated scenes that combine multiple systems and expose architecture gaps.

## Directory Structure

Flat within numbered category folders:

```
demo/
  1-start/
    ProjectTemplate/       — copy & go skeleton
    HelloEngine/           — first taste: sprite, text, button, tiny effect
  2-features/
    Scenes/                — lifecycle, transitions, effects, modal, async Load
    Draw2D/                — 2D primitives, gradients, blend, nine-patch, texturing
    Text/                  — fonts (bitmap, FreeType), Unicode, formatting, scaling
    UI/                    — widgets, layout, events, scrolling
    Styles/                — CSS-like themes, cascade, transitions, customization (R-05)
    Input/                 — keyboard, mouse, gamepad, touch
    Sound/                 — playback, streaming, backends (GUI, not console)
    Shaders/               — custom shaders, uniforms, post-effects
    Scene3D/               — mesh loading, camera, lighting, materials
    NormalMap/             — tangent-space normal mapping, material diagnostics
    CharAnimation/         — skeletal animation, IQM/AEM, blend, bone hierarchy
    Animation/             — tweening, animated values (2D focus)
    Platform/              — multi-window, DPI scaling, borderless, fullscreen toggle
  3-advanced/
    AdvancedGfx/           — texture arrays, mip-maps, shadow maps, advanced texture operations
    Resources/             — async loading, queues, ref counting, hot reload
    Network/               — TCP client/server, HTTP requests, timeouts
    Particles/             — instanced rendering, GPU particles (performance demo)
    Billboards/            — billboard stress test (performance demo)
    VertexBuffer/          — procedural mesh generation (performance demo)
  4-complex/
    Game3DShowcase/        — R-017 integrated 3D scene: camera, materials, passes, post-process
```

## Demo Descriptions

### 1-start: Quick Start

**ProjectTemplate** — minimal project skeleton. Copy this folder to start a new project.
One window, one scene, one exit button. No logic beyond setup.

**HelloEngine** — first taste of the engine in one compact scene. Draws a sprite,
renders text, handles a UI button callback, links an exit button through signals,
and shows a tiny click-triggered effect. Covers common API entry points so the
user sees the breadth immediately.

### 2-features: Feature Showcases

Each demo focuses on one subsystem and shows it comprehensively.

**Scenes** — scene lifecycle (Create → Load → InitGfx → Process → Render),
scene switching with fade/blur effects, windowed/modal scenes, signal-driven transitions.
Source: current `01-Scenes`, expanded.

**Draw2D** — full gallery of 2D drawing: lines, polylines, polygons, rects, rounded rects,
fills, gradients, textured quads, triangles, nine-patch, blend modes, CPU particles.
Absorbs relevant test cases from `EngineTest`. Source: current `Draw2D` + `NinePatch` + EngineTest cases.

**Text** — font rendering showcase: bitmap fonts, FreeType fonts, Unicode text,
formatted/rich text, alignment options, text scaling, DPI-aware text.
Absorbs text-related test cases from `EngineTest`. Source: **new** + EngineTest text cases.

**UI** — all standard widgets (buttons, labels, checkboxes, dropdowns, edit boxes,
list boxes, scroll bars, windows), layout system, event handling, focus/tab navigation.
Source: current `UI`, updated for R-10 widget changes.

**Styles** — CSS-like style system (R-05): defining styles in text, inheritance/cascade,
selector matching, theme switching, transitions, runtime style changes.
Source: **new**, created when R-05 reaches usable state.

**Input** — unified input demo: keyboard events and state, mouse tracking and buttons,
mouse wheel, gamepad/joystick axes and buttons, touch input.
Source: current `InputDemo` + `ControllerDemo` merged.

**Sound** — audio playback with GUI (not console): music streaming, sound effects,
volume/pan control, multiple backend selection (BASS/SDL/IMX), 3D positional audio.
Source: current `SoundDemo` rewritten as graphical app.

**Shaders** — custom shader programming: writing fragment/vertex shaders, passing uniforms,
texture sampling in shaders, full-screen post-processing effects.
Source: current `Shaders`, expanded.

**Scene3D** — 3D basics: loading meshes (OBJ/AEM), camera setup and control,
lighting (directional, point), textures and materials, basic transforms.
Source: current `Simple3D`, expanded.

**NormalMap** — tangent-space normal mapping as a regular material/rendering feature:
normal map generation/loading, tangent basis diagnostics, camera/light controls,
and side-by-side material comparison. Source: current `NormalMap`, expanded once
R-06 functionality moves from local demo shader code into the engine material path.

**CharAnimation** — skeletal animation: loading animated models (IQM/AEM format),
skeleton visualization, animation playback, blending between animations,
bone attachment points. Source: current `CharAnimation`, expanded.

**Animation** — 2D animation and motion: tweening between values, easing functions,
animated values API, chained/sequenced animations, UI transition effects.
Source: current `Tweenings`, expanded.

**Platform** — platform features: creating multiple windows (R-02), DPI-aware scaling,
borderless window mode, fullscreen toggle, window events.
Source: current `MultiWindow` + `UIScaleDPI` + `Borderless` merged.

### 3-advanced: Advanced & Performance

**AdvancedGfx** — advanced graphics techniques: texture arrays, manual mip-map control,
shadow mapping, and advanced texture operations.
Source: current `AdvTex` + `ShadowMap` merged.

**Resources** — resource management patterns: async loading with queues and priorities,
reference counting, resource lifecycle, hot reload during development.
Source: **new**, created when resource API is stabilized.

**Network** — networking: TCP client/server communication, HTTP requests,
timeouts and error handling, retry patterns.
Source: **new**, created when roadmap section K is done.

**Particles** — instanced rendering / GPU particle system: galaxy simulation,
large particle counts, GPU-side computation. Performance/stress test.
Source: current `Particles` (unchanged scope).

**Billboards** — billboard rendering at scale: camera-facing sprites in 3D,
batched rendering, depth sorting. Performance/stress test.
Source: current `Billboards` (unchanged scope).

**VertexBuffer** — procedural mesh generation: complex surface topology,
vertex/index buffer management, normal calculation. Performance/stress test.
Source: current `VertexBuffer` (unchanged scope).

### 4-complex: Integrated Showcases

Complex demos are not subsystem reference demos. They combine several engine systems
in one realistic scene and are allowed to reveal architecture gaps before the final
engine abstractions exist.

**Game3DShowcase** — R-017 skeleton-first integrated 3D showcase: scene organization,
camera model, material path, normal-mapped objects, multi-pass rendering,
post-processing, and debug/diagnostic controls. Source: **new**, created from R-017.

## Migration Map

What happens to each current demo:

| Current Demo | Target | Action |
|---|---|---|
| ProjectTemplate | 1-start/ProjectTemplate | Move as-is |
| SimpleDemo | 1-start/HelloEngine | Rewrite into HelloEngine, then remove |
| 01-Scenes | 2-features/Scenes | Move + expand |
| Draw2D | 2-features/Draw2D | Move + absorb NinePatch + EngineTest 2D cases |
| NinePatch | 2-features/Draw2D | Merge into Draw2D, then remove |
| — | 2-features/Text | **New** (absorb EngineTest text cases) |
| UI | 2-features/UI | Move + update for R-10 |
| — | 2-features/Styles | **New** (when R-05 ready) |
| InputDemo | 2-features/Input | Move + merge ControllerDemo |
| ControllerDemo | 2-features/Input | Merge into Input, then remove |
| SoundDemo | 2-features/Sound | Rewrite as GUI app |
| Shaders | 2-features/Shaders | Move + expand |
| Simple3D | 2-features/Scene3D | Rename + expand |
| NormalMap | 2-features/NormalMap | Move + expand when R-06 becomes engine-level functionality |
| CharAnimation | 2-features/CharAnimation | Move + expand |
| Tweenings | 2-features/Animation | Rename + expand |
| MultiWindow | 2-features/Platform | Merge with UIScaleDPI + Borderless |
| UIScaleDPI | 2-features/Platform | Merge into Platform, then remove |
| Borderless | 2-features/Platform | Merge into Platform, then remove |
| AdvTex | 3-advanced/AdvancedGfx | Merge with ShadowMap |
| ShadowMap | 3-advanced/AdvancedGfx | Merge into AdvancedGfx, then remove |
| — | 3-advanced/Resources | **New** |
| — | 3-advanced/Network | **New** (when K ready) |
| Particles | 3-advanced/Particles | Move as-is |
| Billboards | 3-advanced/Billboards | Move as-is |
| VertexBuffer | 3-advanced/VertexBuffer | Move as-is |
| — | 4-complex/Game3DShowcase | **New** (R-017 integrated 3D architecture showcase) |
| EngineTest | — | Distribute cases to Draw2D/Text/etc, then remove |

## Dependencies on Roadmap Features

| Demo | Blocked by |
|---|---|
| Styles | R-05 (CSS-like style system) |
| Platform | R-02 (multi-window) |
| NormalMap | R-06 (normal mapping) |
| Resources | Resource API stabilization |
| Network | Roadmap section K |
| Game3DShowcase | R-017 (3D game architecture probe) |
| HelloEngine | None (can be created now) |
| Text | None (can be created now) |
