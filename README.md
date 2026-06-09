## Apus Game Engine

Cross-platform 2D/3D game engine written in Delphi/Pascal by Ivan Polyacov ([Apus Software](https://apus-software.com)). In active development since the early 2000s, used in several commercial titles.

**Games made with this engine:**
* [Spectromancer](https://store.steampowered.com/app/22500/Spectromancer/) — Windows, iOS
* [Astral Heroes](https://store.steampowered.com/app/488910/Astral_Heroes/) — Windows
* [Astral Towers](https://store.steampowered.com/app/983450/Astral_Towers/) — Windows, Linux

---

### Philosophy

The engine is written in standard Object Pascal and compiles with both **Delphi 11+** and **FPC 3.2+** from a single codebase, with no conditional forks for compiler-specific syntax. This is a deliberate design constraint: language features that work in one compiler but not the other are avoided. The goal is long-term portability — the same source should remain buildable regardless of which Pascal toolchain you use or what platform you target.

This means: no inline variables, no type inference, no attributes, no anonymous methods beyond what both compilers support. Compatibility is not a limitation to work around — it is part of the design.

---

### What's included

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
- OpenGL renderer (core profile): 2D/3D drawing, shaders, textures, nine-patch, text
- Resource management with reference counting
- Audio (BASS, SDL, IMX backends)
- Platform layer: Windows (native WinAPI), Linux/macOS (SDL2), Android, iOS
- Multi-window and DPI-aware display support

---

### Engine 4 — stable

The current stable version is **engine4**. It is used in shipped games and is the recommended starting point if you want something that works today.

→ [Download engine4 releases](https://github.com/Cooler2/ApusGameEngine/releases)  
→ [Documentation / Tutorial](https://docs.google.com/document/d/1sl9x3FB-qI7e8DnW6dpUHevZSU8ddfsNHwwTk5ygYUs/edit?usp=sharing)

---

### Engine 5 — in development

`engine5` is a major refactoring of the entire codebase. **APIs change frequently. Nothing here is guaranteed stable.** It is not yet suitable for starting a new project.

What's being worked on is tracked in [engine5_feature_roadmap.md](engine5_feature_roadmap.md). Current highlights:

- New foundation library (`Apus.Core`, `Apus.Strings`, `Apus.Conv`, `Apus.Log`, `Apus.Threads`, …) replacing the monolithic legacy `Apus.Common`
- OpenGL core profile pipeline: VBO/IBO, debug instrumentation, NSight-compatible
- CSS-like style system for UI (declarative, inherited, state-aware)
- Geometry library overhaul: single-precision first, spatial primitives, intersection and culling tests
- Multi-window support with runtime DPI changes
- CI coverage on Windows and Linux (GitHub Actions)
- Modernized demo suite and console

Documentation for engine5 does not exist yet — it will appear as the codebase stabilizes.

---

License: BSD-3 — see `license.txt`  
VK group: https://vk.com/apusgameengine
