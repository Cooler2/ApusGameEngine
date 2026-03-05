# Core OpenGL Context Migration Plan (SimpleDemo -> NSight-ready)
Last updated: 2026-03-05

Goal: migrate Engine5 rendering from compatibility-style OpenGL usage to a true core-profile pipeline, so `demo/SimpleDemo` can be debugged in NVIDIA NSight with meaningful draw/resource visibility.

## Scope and Target
- In scope: Windows + SDL OpenGL context creation, render-device submission path, shader syntax alignment, debug markers/labels, SimpleDemo debug profile.
- Out of scope: non-OpenGL backends, full renderer rewrite, unrelated demo migration.
- Primary target: Win64 + Delphi build of `SimpleDemo` with core context + debug context.

## Context Version Policy (agreed)
- Minimum required OpenGL version remains `3.0` (may be raised to `3.2/3.3` if migration requires it).
- By default, engine should request the highest available core context supported by driver/platform (example: `4.5`), not a fixed low version.
- Context creation should use descending version negotiation (high -> lower) until success, with clear logs of requested/actual version.
- Runtime should continue using highest-version features when available via existing version checks/extensions (this is existing behavior and is preserved).

## Stage 0: Baseline and Toggle
Goal: introduce safe migration toggle and baseline logs before behavior changes.

Changes:
- [Apus.Engine.API.pas](/G:/apus/enginerev/Apus.Engine.API.pas): add OpenGL context request record (profile/version/debug/forward-compatible flags).
- [Apus.Engine.GameApp.pas](/G:/apus/enginerev/Apus.Engine.GameApp.pas): add app-level setting to request core context explicitly (default off for first step).
- [Apus.Engine.OpenGL.pas](/G:/apus/enginerev/Apus.Engine.OpenGL.pas): log requested vs actual profile/version/flags.

Exit criteria:
- Engine can run with old path unchanged.
- Log clearly shows requested and actual context parameters.

## Stage 1: Platform Context API Extension
Goal: make context creation explicit and profile-aware on all platforms.

Changes:
- [Apus.Engine.API.pas](/G:/apus/enginerev/Apus.Engine.API.pas): change `ISystemPlatform.CreateOpenGLContext` signature to accept context request and return actual info.
- [Apus.Engine.WindowsPlatform.pas](/G:/apus/enginerev/Apus.Engine.WindowsPlatform.pas): implement new signature.
- [Apus.Engine.SDLplatform.pas](/G:/apus/enginerev/Apus.Engine.SDLplatform.pas): implement new signature.
- [Apus.Engine.OpenGL.pas](/G:/apus/enginerev/Apus.Engine.OpenGL.pas): pass request from renderer init.

Exit criteria:
- Both platform backends compile.
- No functional behavior change yet when compatibility mode is requested.
- Version negotiation API supports "prefer highest available" + explicit minimum.

## Stage 2: Windows Core Context Creation (WGL)
Goal: create true core profile context on Windows.

Changes:
- [Apus.Engine.WindowsPlatform.pas](/G:/apus/enginerev/Apus.Engine.WindowsPlatform.pas):
  - create temporary legacy context only to load WGL extensions;
  - use `wglCreateContextAttribsARB` for final context with requested major/minor/profile/flags;
  - implement descending version attempts (for example 4.6..3.x with configured minimum);
  - keep controlled fallback path (compatibility request only, no silent fallback when core requested).
- [extra/dglOpenGL.pas](/G:/apus/enginerev/extra/dglOpenGL.pas): verify required WGL symbols are available; add missing declarations if needed.

Exit criteria:
- On Windows, log reports core profile when requested.
- Context creation fails loudly (with clear log) if driver cannot provide requested core profile.
- Successful context normally matches highest supported version on target machine.

## Stage 3: SDL Core Context Request Cleanup
Goal: stop forcing compatibility profile on SDL path.

Changes:
- [Apus.Engine.SDLplatform.pas](/G:/apus/enginerev/Apus.Engine.SDLplatform.pas):
  - replace `SDL_GL_CONTEXT_PROFILE_COMPATIBILITY` with request-driven profile (`CORE` for migration target);
  - apply version negotiation strategy consistent with Windows path;
  - set debug/forward-compatible flags from request.

Exit criteria:
- SDL backend creates core profile when requested.
- No hardcoded compatibility profile remains.

## Stage 4: Core-Profile Compliance in RenderDevice
Goal: remove client-memory vertex submission dependency and enforce VAO/VBO-ready path.

Changes:
- [Apus.Engine.OpenGL.pas](/G:/apus/enginerev/Apus.Engine.OpenGL.pas):
  - add and bind a default VAO for core profile;
  - refactor `TRenderDevice.SetupAttributes` so attribute pointers are bound against `GL_ARRAY_BUFFER` data, not raw CPU pointers;
  - add explicit path for buffer-backed draws and isolate temporary staging fallback.
- [Apus.Engine.Graphics.pas](/G:/apus/enginerev/Apus.Engine.Graphics.pas): extend `IRenderDevice` contract for buffer-based draw calls (or dedicated bind phase).
- [Apus.Engine.ResManGL.pas](/G:/apus/enginerev/Apus.Engine.ResManGL.pas): ensure VBO/IBO bind helpers are used by draw path, not just by callers.

Exit criteria:
- Main draw path does not rely on client-side vertex arrays.
- Core profile draw calls execute without `GL_INVALID_OPERATION`.

Ordering note:
- This stage should be completed before enabling core profile as default in platform context creation (Stages 2-3 rollout switch).

## Stage 5: Migrate High-Usage Immediate Paths to Buffers
Goal: eliminate remaining RAM-fed hotspots used by SimpleDemo and core scenes.

Changes:
- [Apus.Engine.Draw.pas](/G:/apus/enginerev/Apus.Engine.Draw.pas):
  - move particles/bands/common quads to dynamic VBO/IBO ring buffers;
  - keep API shape, change backend submission.
- [Apus.Engine.TextDraw.pas](/G:/apus/enginerev/Apus.Engine.TextDraw.pas): migrate glyph quad batching to VBO path.
- [Apus.Engine.Mesh.pas](/G:/apus/enginerev/Apus.Engine.Mesh.pas): verify mesh path always uses index/vertex buffers.

Exit criteria:
- `SimpleDemo` render passes (UI, lines, particles, text) use GPU buffers.
- No frequent per-draw CPU pointer feed in profiler/logs for these paths.

## Stage 6: Shader Syntax/Core Alignment
Goal: remove compatibility-era GLSL assumptions from active path.

Changes:
- [Apus.Engine.PainterGL2.pas](/G:/apus/enginerev/Apus.Engine.PainterGL2.pas):
  - update old shader strings (`attribute/varying/gl_FragColor/texture2D`) to core-compatible syntax, or route 2D path through `ShadersGL`.
- [Apus.Engine.ShadersGL.pas](/G:/apus/enginerev/Apus.Engine.ShadersGL.pas): keep unified `#version 330` style and explicit `in/out`.

Exit criteria:
- Active shaders compile under core profile without compatibility features.
- No runtime fallback to compatibility GLSL syntax.

## Stage 7: NSight Instrumentation and Resource Visibility
Goal: make frame debugging useful in NSight.

Changes:
- [Apus.Engine.OpenGL.pas](/G:/apus/enginerev/Apus.Engine.OpenGL.pas):
  - enable `glDebugMessageCallback`/filtering in debug context;
  - add debug groups around frame/scene/UI/particles passes.
- [Apus.Engine.ResManGL.pas](/G:/apus/enginerev/Apus.Engine.ResManGL.pas):
  - label textures, buffers, FBOs via `glObjectLabel` from engine resource names.
- [Apus.Engine.Draw.pas](/G:/apus/enginerev/Apus.Engine.Draw.pas): add targeted markers for major batches.

Exit criteria:
- NSight capture shows named resources and meaningful event grouping.
- GL debug output surfaces real API mistakes during development builds.

## Stage 8: SimpleDemo NSight Profile
Goal: guarantee reproducible NSight-friendly launch configuration.

Changes:
- [demo/SimpleDemo/SimpleDemoApp.pas](/G:/apus/enginerev/demo/SimpleDemo/SimpleDemoApp.pas): request core+debug context in demo settings (dev build path).
- [demo/SimpleDemo/SimpleDemo.dproj](/G:/apus/enginerev/demo/SimpleDemo/SimpleDemo.dproj):
  - add/adjust a dedicated `NSight` config (Win64, debug info enabled, optimizations disabled).
- [demo/SimpleDemo/SimpleDemo.lpi](/G:/apus/enginerev/demo/SimpleDemo/SimpleDemo.lpi): optional matching FPC profile if needed for parity checks.

Exit criteria:
- `SimpleDemo` starts with core debug context in Win64 config.
- NSight can attach/capture with symbols and stable frame structure.

## Stage 9: Validation and Rollout
Goal: lock migration result and remove temporary fallback paths.

Changes:
- [engine5_feature_roadmap.md](/G:/apus/enginerev/engine5_feature_roadmap.md): update R-01 status and acceptance checklist.
- [engine_work_ahead.md](/G:/apus/enginerev/engine_work_ahead.md): log completed migration steps and remaining blockers.
- Optional cleanup: remove compatibility-only code paths that are no longer used.

Exit criteria:
- R-01 acceptance criteria reached:
  - main render path does not require compatibility profile;
  - targeted geometry submission uses VBO/IBO;
  - `SimpleDemo` is inspectable in NSight with useful draw/resource visibility.

## Risks and Mitigations
- Risk: hidden client-array usage in old utility paths.
  - Mitigation: add runtime asserts in core mode when `GL_ARRAY_BUFFER=0` during attribute setup.
- Risk: shader regressions on older drivers.
  - Mitigation: keep explicit core-version requirement and clear startup diagnostics.
- Risk: performance regressions due to naive dynamic buffer updates.
  - Mitigation: use ring-buffer strategy and batch size telemetry.

## Suggested Execution Order
1. Stages 0-1 (API/toggle + negotiation contract, no default behavior break).
2. Stages 4-5 (remove client-array dependence and migrate SimpleDemo-critical draw paths to VBO/IBO).
3. Stage 6 (core-compatible shader path cleanup).
4. Stages 2-3 (enable core-context creation path and make it default after validation).
5. Stages 7-8 (NSight instrumentation/profile).
6. Stage 9 (cleanup and roadmap status updates).

## Implementation Progress
- [x] Stage 0: baseline request/actual logging + app-level request toggles added.
- [x] Stage 1: `ISystemPlatform.CreateOpenGLContext` extended to request/actual contract; Windows + SDL backends migrated to new signature.
- [~] Stage 4: core-profile safety baseline added in `TRenderDevice`:
  - default VAO creation/bind in core profile;
  - runtime assert for missing `GL_ARRAY_BUFFER` during attribute setup in core mode;
  - automatic stream VBO/IBO fallback for RAM-fed draw calls.
- [x] Stage 5: high-usage immediate paths now pass through stream/buffer-backed submission, reducing direct client-array dependency for `SimpleDemo`-critical draw/text paths.
  - `Apus.Engine.TextDraw`: `FlushTextCache` now uploads to explicit dynamic VB + static IB and renders via bound buffers.
  - `Apus.Engine.Draw`: 2D `Particles(...)` and `Band(...)` paths now upload to dynamic VB/IB and render via buffer-backed indexed draws.
  - `Apus.Engine.Draw`: pointer-based `IndexedMesh(...)` overloads now use dynamic scratch VB/IB upload + bound-buffer indexed draw (used by `Mesh`/`Model3D` immediate paths).
  - `Apus.Engine.OpenGL.TRenderDevice`: stream VBO/IBO fallback now covers pointer-fed draws in compatibility mode as well (when `GL_ARRAY_BUFFER` is not pre-bound), while preserving explicit client-pointer fallback safety for mixed states.
  - Validation note: `SimpleDemo` build/runtime confirms text/particles/spinner paths; mesh-path runtime validation is pending a mesh-using demo target.
- [~] Stage 6: shader syntax/core alignment started.
  - `Apus.Engine.PainterGL2`: desktop shader strings switched to GLSL core-style (`#version 330`, `in/out`, `texture`, explicit fragment output), while preserving existing GLES shader path under `{$IFDEF GLES}`.
  - review follow-up: removed GL state queries from draw hot path (`TRenderDevice` now uses tracked array/element buffer bindings).
  - review follow-up: removed per-draw `MaxIndexInBuffer` scan from hot path; RAM-backed indexed stream upload is constrained to ranged overload with explicit `vrtCount`.
