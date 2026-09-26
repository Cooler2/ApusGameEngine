## Apus Game Engine

Cross-platform 2D/3D game engine written in Delphi/Pascal by Ivan Polyacov ([Apus Software](https://apus-software.com)). In active development since the early 2000s, used in several commercial titles.

**Engine 5 targets Windows, Linux and macOS** (up from Windows and Linux in Engine 4). **Android and iOS** builds run in emulators/simulators and are available to try out, but they are in preview state and not production-ready yet.

**Games made with this engine:**
* [Astral Masters](https://store.steampowered.com/app/1790630/Astral_Masters/) — Windows, iOS (Engine-2)
* [Spectromancer](https://store.steampowered.com/app/22500/Spectromancer/) — Windows, iOS (Engine-2.5 (late))
* [Astral Towers](https://store.steampowered.com/app/983450/Astral_Towers/) — Windows, Linux, iOS (Engine-3 / 4)
* [Astral Heroes](https://store.steampowered.com/app/488910/Astral_Heroes/) — Windows (Engine-3)

---

### 🚀 Getting started

**Requirements:** [FPC](https://www.freepascal.org/) 3.2.2+ or Delphi 12+. No other setup is needed: the engine is used from source.

**Windows** (FPC) - from the repository root:

```
demo\build_demo_fpc.cmd SimpleDemo
bin64\SimpleDemo.exe
```

The exe goes to `bin64\`, next to the DLLs it needs (SDL2, FreeType, SDL_mixer). With Delphi, open `demo\SimpleDemo\SimpleDemo.dproj`.

**Linux** (FPC) - install `libsdl2-dev libfreetype-dev` (plus `libsdl2-mixer-dev` for audio), then from the repository root:

```
mkdir -p demo/SimpleDemo/_fpc
fpc -dOPENGL -dFREETYPE -MDelphi -Sd -RIntel \
  -Fu. -Fuextra -Fuextra/sdl2 -FuBase -FuBase/extra \
  -Fudemo/SimpleDemo -FUdemo/SimpleDemo/_fpc demo/SimpleDemo/SimpleDemo.dpr
demo/SimpleDemo/SimpleDemo
```

**macOS** - see [`platform/`](platform/) and [`platform/BUILDING_BUNDLES.md`](platform/BUILDING_BUNDLES.md).

**Your own project:** copy [`demo/ProjectTemplate`](demo/ProjectTemplate/) - its [README](demo/ProjectTemplate/README.md) has the steps. Other demos are listed in [`demo/demo_inventory.md`](demo/demo_inventory.md).

Opt-in defines (see `defines.inc`): `SDLMIX` - audio via SDL_mixer; `WEBP` - `.webp` image loading; `SDL` - SDL platform layer on Windows (Linux and macOS always use it).

---

### 💡 Philosophy

The engine is written in standard Object Pascal and compiles with both **Delphi 12+** and **FPC 3.2+** from a single codebase, with no conditional forks for compiler-specific syntax. This is a deliberate design constraint: language features that work in one compiler but not the other are avoided. The goal is long-term portability — the same source should remain buildable regardless of which Pascal toolchain you use or what platform you target.

This means: no inline variables, no type inference, no attributes, no anonymous methods beyond what both compilers support. Compatibility is not a limitation to work around — it is part of the design.

---

### 📦 What's included

**Base library** (`Base/Apus.*.pas`) — platform-independent utilities that can be used without the engine:
- Math: vectors, matrices, quaternions, geometry (2D/3D), spatial primitives
- Strings: UTF-8 (`String8`) as the primary string type, with full helper API
- Collections: hash maps, arrays, containers, sorted structures
- Animation: tweening, animated values
- I/O: file handling, compression, image loading/saving, cryptography
- Network: TCP, HTTP requests
- Platform: threading, logging, profiling, clipboard, cross-platform time

**Engine** (`Apus.Engine.*.pas`) — the game engine itself:
- Scene system with defined lifecycle (Load → Init → Process → Render)
- UI system: widgets, layout, CSS-like style system, event signals
- OpenGL renderer (GL 3.3 core baseline, GLES 3.0 for mobile targets; newer GL features only as optional extension-gated fast paths): 2D/3D drawing, shaders, textures, nine-patch, text
- Resource management with reference counting
- Audio: SDL_mixer backend (opt-in, `-dSDLMIX`)
- Platform layer: Windows, Linux, macOS; Android and iOS in preview
- Multi-window and DPI-aware display support

---

### ✅ Engine 4 — stable

The current stable version is **engine4**. It is used in shipped games and is the recommended starting point if you want something that works today.

→ [Download engine4 releases](https://github.com/Cooler2/ApusGameEngine/releases)  
→ [Documentation / Tutorial](https://docs.google.com/document/d/1sl9x3FB-qI7e8DnW6dpUHevZSU8ddfsNHwwTk5ygYUs/edit?usp=sharing)

---

### 🚧 Engine 5 — in development

`engine5` is a major refactoring of the entire codebase. **APIs may still change.** Preview snapshots are published as [pre-releases](https://github.com/Cooler2/ApusGameEngine/releases); coming from engine4, see the migration guide [`Base/engine5_changes.md`](Base/engine5_changes.md).

What's being worked on is tracked in [engine5_feature_roadmap.md](engine5_feature_roadmap.md). Current highlights:

- New foundation library (`Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Log`, `Apus.Threads`, …) replacing the monolithic legacy `Apus.Common`
- OpenGL core profile pipeline with a GL 3.3 desktop baseline and a shared GLES 3.0 mobile path
- CSS-like style system for UI (declarative, inherited, state-aware)
- Geometry library overhaul: single-precision first, spatial primitives, intersection and culling tests
- Multi-window support with runtime DPI changes
- Robot API for automated testing and tooling integration (file-based protocol, UI introspection, screenshot/pixel commands)
- CI coverage on Windows, Linux and macOS arm64 (GitHub Actions)
- Modernized demo suite, including the touch-oriented `TouchDemo` used for mobile bring-up

Build notes and platform-specific tooling live under [`platform/`](platform/). The engine5 manual is being written - see [`manual/README.md`](manual/README.md) for the published chapters; detailed implementation status is in the [feature roadmap](engine5_feature_roadmap.md).

#### Known limitations

- Skeletal 3D models (`Model3D`, IQM/AEM loaders) are not migrated yet - see [`legacy/`](legacy/README.md). Static meshes and OBJ work.
- Steam integration is not migrated (`legacy/Apus.Engine.SteamAPI.pas`).
- Some old demos do not build yet - they are kept in [`demo/legacy/`](demo/legacy/README.md).
- The WebP decoder is not bundled for macOS and iOS.
- UI widget colors are only partly themeable (the style system is in progress).

---

License: BSD-3 — see `license.txt`; third-party components and their notices
are indexed in `THIRD-PARTY.md`  
VK group: https://vk.com/apusgameengine
