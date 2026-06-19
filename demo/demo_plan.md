# Demo Plan (Target State)

Date: 2026-03-22

This document defines the target demo structure for Engine5.
For the current state of demos, see `demo_inventory.md`.

## Goals

Demos serve three purposes:
1. **New user onboarding** — progressive learning path from minimal to advanced.
2. **API reference** — each subsystem has exactly one demo showing its full API surface.
3. **Test base** — CI can build and run all demos; Robot API can validate via screenshot/pixel.

## Directory Structure

Flat within numbered category folders:

```
demo/
  1-start/
    ProjectTemplate/       — copy & go skeleton
    HelloEngine/           — first taste: sprite, text, button, sound in ~100 lines
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
    CharAnimation/         — skeletal animation, IQM/AEM, blend, bone hierarchy
    Animation/             — tweening, animated values (2D focus)
    Platform/              — multi-window, DPI scaling, borderless, fullscreen toggle
  3-advanced/
    AdvancedGfx/           — texture arrays, mip-maps, shadow maps, normal maps (R-06)
    Resources/             — async loading, queues, ref counting, hot reload
    Network/               — TCP client/server, HTTP requests, timeouts
    Particles/             — instanced rendering, GPU particles (performance demo)
    Billboards/            — billboard stress test (performance demo)
    VertexBuffer/          — procedural mesh generation (performance demo)
```

## Demo Descriptions

### 1-start: Quick Start

**ProjectTemplate** — minimal project skeleton. Copy this folder to start a new project.
One window, one scene, one exit button. No logic beyond setup.

**HelloEngine** — "what the engine can do in 100 lines". Draws a sprite, renders text,
plays a sound on button click, shows a particle effect. Covers the most common API
entry points so the user sees the breadth immediately.

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
shadow mapping, normal maps (R-06), advanced texture operations.
Source: current `AdvTex` + `ShadowMap` merged + R-06 content.

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
| EngineTest | — | Distribute cases to Draw2D/Text/etc, then remove |

## Dependencies on Roadmap Features

| Demo | Blocked by |
|---|---|
| Styles | R-05 (CSS-like style system) |
| Platform | R-02 (multi-window) |
| AdvancedGfx (normal maps) | R-06 (normal mapping) |
| Resources | Resource API stabilization |
| Network | Roadmap section K |
| HelloEngine | None (can be created now) |
| Text | None (can be created now) |

## Plan Evolution Ideas

These notes are candidate refinements for the R-15 demo plan. They do not
change the target structure or migration map above yet.

### Resource Lab / ResLab

Consider making the planned `Resources` demo a focused `ResLab`: a resource
lifecycle and diagnostics surface rather than a general "load some images"
showcase.

Possible coverage:
- `TTexture` creation, ownership, naming, lookup, reference/free patterns.
- `ImgLoadQueue` async loading with placeholder/completion/error states.
- Hot reload / reload-from-file if the stabilized resource API supports it.
- Direct texture operations: `Upload`, `UploadPart`, `Clear`, `ClearPart`,
  lock/unlock, and pixel updates.
- Resource diagnostics: loaded resources, dimensions, format, source, and
  reference state.
- Stress cases: many small textures, repeated load of the same name, free and
  recreate cycles.
- Robot-friendly fixed checks: deterministic texture-update areas whose pixels
  can be validated.

### AdvTex Decomposition

The current `AdvTex` mixes several useful but different concerns. Instead of
porting it as one demo, split its cases by purpose:

- Direct texture upload/fill/update belongs in `ResLab` because it tests
  resource mutation and lifecycle behavior.
- Manual mip levels and filter comparison belong in `AdvancedGfx` as rendering
  behavior.
- Texture arrays belong in `AdvancedGfx`, but only after deciding whether the
  public Engine5 API should expose them above the current OpenGL-specific
  `TGLTextureArray` surface.
- Shader sampling from texture arrays can be a higher-level `AdvancedGfx` case,
  not part of the basic shader introduction.

### Shaders vs AdvancedGfx

Keep `Shaders` as a lightweight feature demo / shader lab:

- custom shader snippets and file-loaded shaders;
- uniform editing and animation (`time`, colors, radius, border, UV offsets);
- small 2D examples such as rounded-rect SDF, color ramp, UV grid, image tint,
  and distortion;
- stable pixel-test zones for Robot API checks.

Keep `AdvancedGfx` for heavier rendering techniques:

- mipmaps and texture filtering;
- texture arrays;
- shadow maps;
- normal maps;
- advanced texture/render-pass interactions.

This split keeps `Shaders` useful as an API-reference entry point while leaving
`AdvancedGfx` free to become the deeper rendering-techniques demo.
