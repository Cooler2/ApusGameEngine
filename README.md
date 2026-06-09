## Apus Game Engine

Cross-platform 2D/3D game engine written in Delphi/Pascal by Ivan Polyacov ([Apus Software](https://apus-software.com)). In active development since the early 2000s, used in several commercial titles.

**Games made with this engine:**
* [Spectromancer](https://store.steampowered.com/app/22500/Spectromancer/) — Windows, iOS
* [Astral Heroes](https://store.steampowered.com/app/488910/Astral_Heroes/) — Windows
* [Astral Towers](https://store.steampowered.com/app/983450/Astral_Towers/) — Windows, Linux

---

### What's included

**Base library** (`Base/`) — platform-independent utilities: math, geometry, strings, collections, compression, networking, cryptography, image loading, animation, font rendering, logging, threading, and more. Can be used independently of the engine.

**Engine** (`Apus.Engine.*`) — the game engine itself:
- Scene system with lifecycle management
- UI system: widgets, layout, CSS-like style system, event signals
- OpenGL renderer (core profile): 2D/3D drawing, shaders, textures, nine-patch, text rendering
- Resource management with reference counting
- Audio (BASS, SDL, IMX backends)
- Cross-platform platform layer: Windows (native), Linux/macOS (SDL), Android, iOS
- Robot API for automated testing and tooling integration
- Multi-window and DPI-aware display support

**Supported compilers:** Delphi 12+, FPC 3.2+  
**Platforms:** Windows (x86/x64), Linux (x64), macOS, Android, iOS

---

### Status

**Stable version:** [engine4 releases](https://github.com/Cooler2/ApusGameEngine/releases).

**Active development** is in the `engine5` branch — a major refactoring. APIs change frequently, nothing is guaranteed stable yet. What's currently being worked on is in [engine5_feature_roadmap.md](engine5_feature_roadmap.md).

Engine5 highlights in progress:
- New foundation library (Apus.Core/Strings/Conv/Log/Threads/…) replacing legacy Apus.Common
- OpenGL core profile pipeline with VBO/IBO and NSight-compatible instrumentation
- CSS-like style system for UI
- Geometry library overhaul (single-precision first, spatial primitives, intersection tests)
- Multi-window and DPI-awareness
- Modernized console and demo suite
- CI coverage on Windows and Linux (GitHub Actions)

Documentation for engine5 is not yet available; engine4 documentation is [here](https://docs.google.com/document/d/1sl9x3FB-qI7e8DnW6dpUHevZSU8ddfsNHwwTk5ygYUs/edit?usp=sharing).

---

License: BSD-3 — see `license.txt`  
VK group: https://vk.com/apusgameengine
