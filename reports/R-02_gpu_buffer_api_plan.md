# R-02: GPU Buffer API Implementation Plan (Practical, Game-Oriented)

Status: in progress (Phase A complete, Phase B/C partial)
Date: 2026-03-11

## Implementation checkpoint (2026-03-11)

Implemented now:
- buffer policy flags are in API/resources (`abThreadLocal`, `abReadOnly`, `abShared`);
- `TEngineBuffer` has policy helpers (`MakeImmutable`, `IsImmutable`, `IsThreadLocal`, owner-thread assert);
- policy-aware sync gates are active (`NeedSyncForBufferRead/Write`, compatibility wrapper kept);
- immutable write guards are active in GL VBO/IBO `Upload/Resize`;
- explicit publish/consume API is present (`PublishUpdate`, `WaitForPublish`, `ResetPublishState`) with internal GL fence storage only (no backend handle leak to public API);
- explicit thread bootstrap API added: `IGraphicsSystem.InitThreadContext(wnd)` and wired into secondary-window startup.

Applied hot-path policy use:
- draw/text per-thread buffers are allocated as `abThreadLocal`;
- static per-thread index buffers in draw/text are finalized as immutable after initial upload.

## 1. Why this plan exists

Current buffer API is usable, but too coarse for real game workloads in multi-window/multi-thread render mode.

What is already good:
- basic VBO/IBO allocation and upload flow exists;
- multi-window safety baseline exists (`RW-lock` on buffer operations when `multiWindowMode=true`);
- usage hints and debug labels exist.

What is still costly/uncomfortable in practice:
- synchronization policy for buffers is global, not per-resource;
- no explicit publish/consume API for cross-context update handoff;
- no immutable contract for buffers (unlike textures);
- no explicit thread bootstrap contract for render API state.

This plan converts the current baseline into a practical API for actual game scenarios.

## 2. Real-world requirements (games)

The API must serve these common paths:

1. Static content path
- mesh/index data uploaded once, used for many frames.

2. Per-frame transient path
- UI, particles, debug geometry, decals, immediate overlays.
- many small uploads each frame, low CPU overhead required.

3. Dynamic shared systems (rare but real)
- streaming world chunks / centralized geometry updates potentially consumed by several windows.

4. Multi-window safety without global slowdown
- thread-local resources must stay lock-free;
- shared mutable resources must be synchronized correctly;
- single-window mode must keep near-zero overhead.

## 3. Design principles

1. Policy-first resources
Buffer behavior must be explicit (`threadLocal`, `readOnly`, `sharedMutable`) instead of inferred from runtime mode only.

2. Fast-path by default
Most runtime buffers should be thread-local and avoid locks/fences.

3. Explicit cross-context handoff
When data written in context A is needed immediately in context B, API must expose publish/consume semantics.

4. Backward-compatible migration
Existing `AllocVertexBuffer/AllocIndexBuffer/Upload/Resize` should keep working.

## 4. Proposed API changes

## 4.1 New buffer flags and policy

Add new allocation flags for buffers:

```pascal
const
  abThreadLocal = $0001; // owned by one render thread/window
  abReadOnly    = $0002; // immutable after finalization
  abShared      = $0004; // explicit cross-thread usage intent (optional clarity flag)
```

New internal caps (engine-side):
- `bfThreadLocal`
- `bfReadOnly`
- `bfSharedMutable` (derived: not thread-local and not read-only)

Policy rules:
- `threadLocal`: no RW-lock; debug owner-thread assert.
- `readOnly`: no write operations after finalize; no lock on read path.
- `sharedMutable`: RW-lock for CPU-side access; optional fence handoff for immediate cross-context visibility.

## 4.2 Extend buffer base class

`TEngineBuffer` additions:

```pascal
type
  TEngineBuffer=class(TObjectEx)
  public
    procedure MakeImmutable; virtual;
    function IsImmutable:boolean; inline;
    function IsThreadLocal:boolean; inline;
    procedure AssertThreadOwner(const opName:string8); inline;
  protected
    ownerThread:TThreadID;
    caps:cardinal;
  end;
```

Required behavior:
- `MakeImmutable` rejects if buffer is currently being written.
- `Upload/Resize` must fail on immutable buffers.
- thread-local buffers store `ownerThread` at allocation.

## 4.3 Policy-aware sync gates

Replace coarse `NeedSyncForBuffer(buf)=multiWindowMode` with:

```pascal
function NeedSyncForBufferRead(buf:TEngineBuffer):boolean; inline;
function NeedSyncForBufferWrite(buf:TEngineBuffer):boolean; inline;
```

Semantics:
- false when `multiWindowMode=false`;
- false for thread-local;
- false for read-only read path;
- true for shared mutable read/write according to operation type.

## 4.4 Explicit publish/consume handoff for shared mutable buffers

Public API should not expose backend-specific fence handles.

Proposed public contract:

```pascal
type
  TEngineBuffer=class
  public
    procedure PublishUpdate; virtual;     // producer side
    procedure WaitForPublish; virtual;    // consumer side, waits for latest published update
    procedure ResetPublishState; virtual; // optional lifecycle helper
  end;
```

Backend behavior:
- OpenGL backend stores last `GLsync` internally in the buffer object.
- `PublishUpdate`: create/replace fence after upload commands, call `glFlush`.
- `WaitForPublish`: `glWaitSync`/`glClientWaitSync` as needed, then keep or clear stored sync by policy.

Advanced option (future, only if needed):
- introduce opaque `TBufferSyncToken` without public fields (`IsValid/Reset`) for cross-buffer orchestration.
- do not expose raw backend handles (`glSync`, Vulkan semaphore handles, etc.) in core API.

Important:
- this is not required for every update;
- use only for explicit immediate cross-context consumption.

## 4.5 Explicit thread bootstrap API

Add explicit render-thread init call (keep lazy fallback):

```pascal
type
  IGraphicsSystem=interface
    procedure InitThreadContext(wnd:TWindow); // new
  end;
```

What it should do:
- initialize per-thread states for shader/draw/text/target/clipping/renderDevice;
- allocate mandatory thread-local streaming buffers upfront;
- reset known default state.

## 5. Migration plan (incremental)

## Phase A: policy foundation (low risk)

1. Add buffer flags/caps and owner-thread field.
2. Implement `MakeImmutable` and write guards.
3. Introduce `NeedSyncForBufferRead/Write`.
4. Keep old behavior as fallback until all call sites are switched.

Deliverable:
- no behavior regressions;
- current API still compiles unchanged.

## Phase B: sync precision and safety

1. Move all buffer read/write lock calls to new policy-aware gates.
2. Add debug assertions for thread-local misuse.
3. Add optional publish/consume fence API in GL backend.

Deliverable:
- shared mutable buffers safe by contract;
- thread-local path lock-free.

## Phase C: explicit thread bootstrap

1. Add `InitThreadContext` and call it in each render thread startup after context activation.
2. Keep lazy init as fallback only.

Deliverable:
- deterministic startup;
- fewer first-frame surprises and race-prone lazy side effects.

## 6. Use-case mapping (how to choose buffer policy)

1. Static mesh/terrain chunk index data
- `shared read-only`
- immutable after initial upload.

2. UI quads / debug lines / particles in one window
- `thread-local mutable`
- regular dynamic buffer path (R-02 scope).

3. Rare centralized dynamic geometry consumed by multiple windows
- `shared mutable`
- RW-lock + explicit publish/consume where immediate visibility is needed.

Note:
- transient/ring allocator design (ownership, growth, overflow strategy) is intentionally out of R-02 scope;
- tracked under `[R-12] Graphics Subsystem Optimizations (Text + Streaming Buffers)` in `engine5_feature_roadmap.md`.

## 7. Risks and mitigations

Risk: API complexity growth
Mitigation: keep legacy methods; add policy defaults and helper constructors.

Risk: accidental immutable misuse
Mitigation: strict runtime guards with operation name in exception text.

Risk: over-synchronization still present in old paths
Mitigation: instrument lock counters/timings and migrate hottest paths first.

## 8. Acceptance criteria

1. Functional:
- no regressions in single-window mode;
- multi-window rendering stable under concurrent draws/uploads.

2. Performance:
- thread-local draw/text paths show reduced lock activity;
- no additional overhead introduced in single-window fast path.

3. API quality:
- policy is explicit at allocation;
- cross-context handoff has explicit API;
- thread bootstrap is explicit and documented.

## 9. Recommended immediate implementation order

1. Phase A (flags + immutable + policy-aware gates).
2. Phase C (explicit thread bootstrap call).
3. Phase B (publish/consume fence API).

This order gives fast safety wins first, then deterministic startup.
