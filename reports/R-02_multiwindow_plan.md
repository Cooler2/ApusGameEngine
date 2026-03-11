# R-02: Multi-Window Runtime Plan (Code-Actual)

Status: in progress  
Last updated: 2026-03-11

This document is intentionally code-driven. It keeps only decisions and work items that are relevant to current implementation.

## 1. Scope and Baseline

R-02 target is one render thread per window with shared OpenGL resource group, while preserving single-window compatibility.

Current baseline:
- `TGame.AddWindow(...)` exists and starts an extra render thread.
- Extra window thread creates a shared GL context (`InitGraphShared(mainWindow)`).
- Global render API shortcuts remain (`gfx`, `shader`, `draw`, `txt`, `transform`), but mutable runtime state has been moved to thread-local storage in core subsystems.
- `multiWindowMode` is toggled by extra-window count and gates resource synchronization paths.

## 2. What Is Already Done

### 2.1 Runtime and Window Lifecycle

- `AddWindow` startup handshake is explicit (success/failure + error propagation), with bounded startup context lifetime.
- `RemoveWindow` has safe thread guards.
- Main-window-only global exit semantics are restored (`WM_DESTROY` on secondary windows does not terminate whole app).
- WGL class unregister is removed from per-window close path.
- Main-context release/reacquire handoff for shared-context creation is moved out of `AddWindow` business logic into platform-level context handoff helpers.

### 2.2 Shared Context and Per-Context Objects

- Secondary context is created shared with primary.
- Per-context VAO is created for secondary context during `InitGraphShared`.
- Per-context VAO is explicitly deleted in window `DoneGraph` (no secondary-context VAO leak).
- Debug output callback is configured per context.
- Runtime milestone: rendering in secondary window is confirmed working in real run.

### 2.3 Threadvar Migration in Render Stack

Implemented thread-local mutable state:
- `TTransformationAPI` matrices/projection/dirty flags.
- `TGLShadersAPI` active shader/modes/textures/light params/cache state.
- `TDrawer` streaming buffers and draw-time mutable state.
- `TTextDrawer` text batch buffers, text cache handle, per-thread link state.
- `TRenderTargetAPI` target/viewport/mask stack.
- `TClippingAPI` clip state and stack.
- `TRenderDevice` mutable bind/stream state.
- `TOpenGL.canPaint` and debug group depth.

### 2.4 Resource Sync Foundation

- Texture policy flags exist in core resource layer:
  - `tfThreadLocal`
  - `tfReadOnly`
- Buffer policy flags exist:
  - `abThreadLocal`
  - `abReadOnly`
  - `abShared`
- Sync gate helpers exist:
  - `NeedSyncForRead(tex)`
  - `NeedSyncForWrite(tex)`
  - `NeedSyncForBufferRead(buf)`
  - `NeedSyncForBufferWrite(buf)`
  - `NeedSyncForBuffer(buf)` (compatibility wrapper)
- Texture sync in GL backend uses per-resource RW-lock and policy gating.
- Vertex/index buffers use policy-aware RW-lock gating and immutable write guards.
- Explicit publish/consume methods exist on buffers (`PublishUpdate/WaitForPublish`) with backend-internal fence storage.
- Text styling callbacks are thread-local (`textColorFunc`, `textLinkStyleProc`) with per-thread default link style bootstrap.

## 3. Shareable Resource Policy

This section is normative for implementation.

### 3.1 Resource Classes

| Resource | Shared between contexts | Policy class | Notes |
|---|---|---|---|
| Texture objects (`TTexture` / GL texture) | Yes | `shared read-only`, `shared mutable`, `thread-local mutable` | Policy by flags (`tfReadOnly`, `tfThreadLocal`) |
| Vertex/index buffers (`TVertexBuffer`/`TIndexBuffer`) | Yes | `shared read-only`, `shared mutable`, `thread-local mutable` | Policy by `ab*` flags + `MakeImmutable` |
| Shader programs | Yes | shared read-mostly | Compile/link once per mode/layout per thread cache path |
| VAO | No | per-context | Must be created per context |
| FBO/RBO | No | per-context | Must be created per context |
| Render state bindings | No | per-thread/per-context | Viewport/blend/current bindings are local state |
| Sync objects (`GLsync`) | Yes | cross-context coordination tool | Use only for producer/consumer handoff when needed |

### 3.2 Texture Policy Matrix

Use exactly one of the following modes:

1. `thread-local mutable`  
Typical use:
- per-window text cache atlas
- scratch render helper textures
- per-window temporary RT

Required behavior:
- mark texture `aiThreadLocal` at allocation
- no RW-lock overhead
- owner-thread assert in debug paths

2. `shared read-only`  
Typical use:
- icons, sprite sheets, static UI images
- immutable mesh/material textures after upload

Required behavior:
- call `MakeImmutable` after final upload
- no RW-lock on read path
- no write APIs allowed

3. `shared mutable` (exception path, not default)  
Typical use:
- dynamic atlas intentionally shared between windows
- streaming texture updated in one thread and sampled in others

Required behavior:
- RW-lock for CPU-side race protection
- explicit producer/consumer publication protocol for cross-context update visibility when immediate use is required

### 3.3 Buffer Policy (Current and Target)

Current:
- all buffers are synchronized when `multiWindowMode=true` (`NeedSyncForBuffer`).
- no per-buffer policy flags.

Target:
- add explicit buffer policy classes:
  - `thread-local mutable` (recommended default for draw/text streaming buffers)
  - `shared read-only` (static meshes)
  - `shared mutable` (rare, explicit)

Rationale:
- current coarse gating is safe but can add avoidable lock overhead.
- texture policy is already granular; buffers should match that model.

## 4. Use-Case to Policy Mapping

### 4.1 Game Window + Debug Window

- world/content textures: `shared read-only`
- game dynamic draw buffers: `thread-local mutable`
- debug overlays: `thread-local mutable`
- no need for shared mutable buffers in normal path

### 4.2 Multi-Viewport Editor

- asset textures/meshes: `shared read-only`
- per-viewport UI/text caches: `thread-local mutable`
- optional shared mutable texture only if editor intentionally uses one global dynamic atlas

### 4.3 Panorama/Simulator

- shared world resources: `shared read-only`
- per-window camera and per-window render transient buffers: `thread-local mutable`
- shared mutable buffers only for explicitly centralized dynamic streaming systems

## 5. Global Interface Objects and Ownership

### 5.1 Public Globals (`Apus.Engine.API`)

| Global | Type | Owner | Lifetime | Thread model |
|---|---|---|---|---|
| `systemPlatform` | `ISystemPlatform` | game bootstrap | app lifetime | shared singleton |
| `gfx` | `IGraphicsSystem` | game bootstrap | init -> done | shared singleton |
| `shader` | `IShader` | assigned by `TOpenGL.Init/Done` | render init -> done | singleton object, thread-aware internal state |
| `draw` | `IDrawer` | assigned by `TOpenGL.Init/Done` | render init -> done | singleton object, thread-aware internal state |
| `txt` | `ITextDrawer` | assigned by `TOpenGL.Init/Done` | render init -> done | singleton object, thread-aware internal state |
| `transform` | `ITransformation` | assigned by `TOpenGL.Init/Done` | render init -> done | singleton object, thread-aware internal state |
| `mainWindow` | `TWindow` | game runtime | app/window lifetime | shared pointer to primary window |
| `window` | `threadvar TWindow` | window thread loop | per-thread runtime | thread-local current window |

### 5.2 Internal Singletons and API Implementations

| Object/global | Ownership | Init style now | Notes |
|---|---|---|---|
| `renderDevice` | `TOpenGL.Init/Done` | explicit create, lazy per-thread state | global interface + threadvar internals |
| `renderTargetAPI` | `TOpenGL.Init/Done` | explicit create + lazy thread state | per-thread viewport/stack state |
| `clippingAPI` | `TOpenGL.Init/Done` | explicit create + lazy thread state | per-thread clip stack |
| `transformationAPI` | `TOpenGL.Init/Done` | explicit create + threadvar matrix state | matrix state per thread |
| `shadersAPI` | `TOpenGL.Init/Done` | explicit create + lazy thread state/cache | shader cache is thread-local |
| `drawer` | `TOpenGL.Init/Done` | explicit create + lazy thread resources | owns neutral texture and particle shader |
| `textDrawer` | `TOpenGL.Init/Done` | explicit create + lazy thread resources | text cache is allocated thread-local |
| `resourceManagerGL` | `TOpenGL.Init/Done` | explicit create | shared resource manager singleton |

## 6. Lazy vs Explicit Init Policy

Current behavior:
- Many APIs use `EnsureThreadState` lazily on first use in each thread.
- Constructors initialize only the creating thread's state.

Desired policy for R-02:
- Keep lazy init as safety net.
- Add explicit per-thread bootstrap for API state after context activation in each render thread.

Recommended explicit bootstrap point:
- immediately after `window.InitGraph` / `window.InitGraphShared` and context activation.

Recommended bootstrap actions:
1. initialize/prime `renderTargetAPI`, `clippingAPI`, `transformationAPI`.
2. initialize `shadersAPI`, `drawer`, `textDrawer` thread-state.
3. set known default render state (viewport, blend, default shader mode).

Goal:
- reduce first-frame surprises and hidden lazy-init side effects.
- make thread startup deterministic and debuggable.

## 7. Remaining Work (Implementation-Relevant Only)

1. Continue per-context object lifetime audit  
- Secondary VAO leak is fixed.
- Keep auditing other per-window/per-context allocations and teardown order.

2. Runtime validation in `demo/MultiWindow`  
- Extend validation from "secondary window renders" to stress checks:
  open/render/close cycle, text rendering, resource cleanup, repeated add/remove windows.

## 8. Non-Goals for This Iteration

- Symmetric multi-GPU rendering across adapters.
- Detachable panel framework.
- Full UI architecture redesign beyond required thread/window isolation.

## 9. References

- `reports/opengl_multiwindow_guide.md`
- `reports/R-02_addwindow_review_and_threadvar_plan_2026-03-10.md`
