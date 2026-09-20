# Chapter 18. Application Lifecycle

This chapter describes how an Apus application starts, runs, reconfigures itself and
shuts down. More precisely, it describes three things that are easy to get wrong and
hard to debug afterwards:

- which **threads** exist and what each of them is allowed to do;
- where each piece of **state** lives — one per application, one per window, or one
  per thread;
- which **phases** the engine calls on your code, what triggers them, and in which
  thread they run.

Like Chapter 21, this chapter is both a user manual and the reference for the intended
behaviour: where the current code differs from what is written here, the text wins and
the code is the thing to fix. See "Implementation status" at the end for the exact
list.

Chapter 22 covers the scene lifecycle in detail and Chapter 31 covers multi-window and
multi-monitor specifics; both build on the model defined here.

**Why this matters.** With one window on one monitor, a derived value such as "the
current font scale" works wherever you put it — there is only one answer. With a
second window on a second monitor there are two answers, and code that stored the
value in the wrong place does not fail on the developer's machine. It fails on a user
configuration nobody tested. The ownership table in section 2 is the part of this
chapter to read first.

## 1) Threads and their roles

An Apus application runs three kinds of thread. They differ in what they own, not in
priority.

| Thread | Name | Created by | Owns / drives |
|---|---|---|---|
| Control thread | `ControlThread` | `TGameApplication.Run` (see the platform note) | Application-level setup, scene creation and loading, the idle loop |
| Window render thread | `MainThread` (main window), `WndThread` (every other window) | `TGame.Run` / `TGame.AddWindow` | One window: its message pump, its surface, its GL context, its scenes' `Process`/`Render` |
| Worker thread | task-specific (`UIClick:<name>`, image loader/unpacker, your own) | `Thread.Start` | Nothing of the engine's; borrowed CPU time |

**Control thread.** Runs `TGameApplication.ControlLoop`. It performs the application
setup phases (`InitSound`, `LoadFonts`, `InitStyles`, `CreateScenes`, `LoadScenes`),
then loops: pings the thread watchdog, pumps queued signals through `Delay(5)`, and
fires `GAMEAPP\onIdle`. It is the thread for logic that must not stall a frame, and
the thread from which a settings screen applies a setting.

The control thread must not issue drawing calls: it holds no GL context. It may build
UI elements, because UI construction touches no GPU resource — see the note on
`window` below.

**Window render thread.** Exactly one per window, for the whole life of that window.
It creates the window, owns its graphics context, pumps its OS messages, applies its
surface changes, and renders its scenes. Everything that touches the GPU happens here.
A window's thread never renders another window.

**Worker threads.** Anything else: the image loading queue (`StartLoadingThreads`
starts one loader plus N unpackers), asynchronous UI click handlers
(`onClickAsync` runs in a `UIClick:<element>` thread), your own background tasks. A
worker has no window context and no GL context. It may read shared immutable data and
send signals; it may not draw, and it may not write per-thread engine state expecting
a render thread to see it (section 2.3 explains why).

### 1.1 The platform note about "main"

Which OS thread ends up being which engine thread depends on the platform, and the
names are unfortunately overloaded:

- **Windows, Linux.** The thread that calls `Run` starts the main window thread
  (named `MainThread`) and then becomes the control thread by entering `ControlLoop`
  itself.
- **macOS.** AppKit requires the OS main thread to own the window and its event loop,
  so it is inverted: `Run` spawns a separate `ControlThread` and drives the main
  window loop on the calling thread. For that reason `Prepare` registers the calling
  thread under the name `MainThread` on Darwin and `ControlThread` everywhere else.
- **iOS.** UIKit owns the run loop, so `game.Run` sets everything up and returns
  without blocking; frames are driven from the display-link callback, and the control
  loop gets its own thread as on macOS. `TGame.FrameLoop` is a single-frame step for
  exactly this reason — it is the pump inversion these platforms need, and it already
  exists.

Two consequences worth remembering:

- "main thread" is ambiguous in this engine. `TGame.mainThread` is the **main
  window's render thread**, not the OS main thread and not the control thread. When a
  name has to distinguish them, spell it out: `mainWndThread` for the main window's
  render thread, `controlThread` for the control thread.
- `TGame.mainThread` is `nil` whenever the main window's loop runs on a thread the
  engine did not start — on macOS and on iOS, always. It is a handle for terminating
  and signalling that thread, not a way to identify it. Code asking "am I the main
  window's render thread?" compares `window=mainWindow` instead.
- To identify a thread, ask the thread: `CurrentThread.Name`, or `th.IsCurrent` for an
  `IThread` you hold. Never compare against the OS main thread.

## 2) State ownership

Every piece of runtime state has exactly one correct home. Choose it by asking **who
can legitimately have a different answer**, not by asking where it is convenient to
read.

| Can differ per... | Home | Declared as |
|---|---|---|
| nothing — one answer for the process | Application-global | ordinary global `var`, or a field of `game`/`app` |
| window | Window state | a field of `TWindow` |
| render thread | Thread-local | `threadvar` (or `class threadvar`) |

### 2.1 Application-global state

One value, valid everywhere, written rarely and usually by the control thread.

| Example | Where |
|---|---|
| `game`, `app`, `gfx`, `draw`, `txt` — subsystem singletons | `Apus.Engine.API` |
| `mainWindow` — the primary window | `Apus.Engine.API` |
| game settings, language code, debug feature flags | `game`, `Apus.Engine.API` |
| loaded font *faces* (the files, not the handles) | `TTextDrawer` |
| texture and resource registries | Chapter 21 |
| the user's UI scale preference ("large fonts") | application settings |

Note the last row: the *preference* is global — it is a property of the program, not
of the window whose settings button the user clicked. What it resolves to in a given
window is not global (section 2.2).

### 2.2 Window state — fields of `TWindow`

Everything that describes one window or the surface it draws into.

| Example | Field |
|---|---|
| resolved surface: client size, render size, canvas size, DPI, safe insets, generation | `surface` |
| DPI of one canvas unit — the value engine-side sizing must use | `canvasDPI` (derived) |
| surface configuration request and pending changes | `config`, pending mask |
| the window's scenes, and which one is topmost | `scenes`, `topmostScene` |
| modal state | `modal` |
| input snapshot: key state, mouse buttons, shift state | `keyState`, `mouseButtons`, `shiftState` |
| frame timing, FPS, frame counter, `screenChanged` | `timings`, `frameNum` |
| the thread that renders it | `renderThread` |

`canvasDPI` deserves a line of its own. It is `surface.dpi` scaled by
`canvasSize.cx / renderSize.cx`: the number of dots per inch of **one canvas unit**.
Over a flexible canvas it equals `surface.dpi`. Over a fixed canvas the canvas is
already stretched into the surface, so it already carries the DPI scaling — sizing
from `surface.dpi` there scales twice. Anything the engine measures in canvas units —
built-in fonts, debug overlays, the magnifier, `Dp()` — takes `window.canvasDPI`.

Window state may be written from any thread (the platform layer posts resize and DPI
requests from the OS message thread), but it is **applied** by the owning render
thread, at one defined point in the frame. See section 7.

### 2.3 Thread-local state — `threadvar`

A `threadvar` is per-render-thread context. Because a window has exactly one render
thread for its whole life, per-render-thread is *also* per-window — but only for state
that is **written by the same thread that renders that window**.

| Example | Where |
|---|---|
| `window` — the window this thread renders | `Apus.Engine.API` |
| clip stack, render target stack, viewport, blend/depth state | `Apus.Engine.Graphics` |
| transformation matrices (view, projection, object, MVP) | `TTransformationAPI` |
| glyph caches, text measurement results, text vertex buffers | `Apus.Engine.TextDraw` |
| `underMouse`, `hooked`, cursor coordinates | `Apus.Engine.UITypes` |
| font handles resolved for drawing | see section 8 |

**The trap.** A `threadvar` works as window state only under the "written by the
rendering thread" condition. State that application code sets from an arbitrary thread
breaks silently: the writer updates its own copy, the renderer keeps reading its own.
This is not hypothetical — `modalElement` was a `threadvar` written from
`onClickAsync` worker threads, so the render thread's copy stayed `nil`, modal
hit-test gating never engaged, and clicks passed through modal dialogs to the widgets
underneath. The fix was to move it to genuine window state (`TWindow.modal`).

So, before declaring a `threadvar`, answer: *is every writer the thread that renders
this window?* If not, it is window state, and it is resolved through an explicit
window reference rather than through the ambient one.

### 2.4 The scales, as an ownership example

Scale factors are where wrong homes concentrate, so they are worth listing explicitly.

| Value | What it means | Correct home |
|---|---|---|
| `window.surface.dpi` | physical DPI of the surface this window is on | window |
| `window.canvasDPI` | DPI of one canvas unit | window (derived) |
| `game.screenScale` | the UI-scale ladder step (1.0 / 1.2 / 1.5 / 2.0 / 2.5), forced to 1.0 over a fixed canvas | per window — a window on a 96-dpi monitor and a window on a 192-dpi monitor do not share it |
| the "large fonts" preference | a program-wide user setting | application-global |
| `element.globalScale` | product of the ancestor `scale` factors | UI element |

Two of these are in the wrong home today; section 11 says which, and
`Work/text_scale_design.md` has the analysis and the migration options.

### 2.5 The ambient `window` and the control thread

Scene and UI construction reads the ambient `window` threadvar to decide which window
a new scene belongs to. During startup the control thread therefore has `window` set to
`mainWindow` — a deliberate transitional arrangement, because scene setup still runs
there. Do not rely on it: a scene or widget that can belong to a non-main window takes
its window explicitly (`TUIScene.Create(name, fullscreen, wnd)`), and code that runs
from a worker thread must assume `window` is `nil`.

## 3) The phase model

A **phase** is a method the engine calls on your code at a defined point, in a defined
thread. The full set:

| Phase | Override in | Thread | When |
|---|---|---|---|
| `SetupApplication` | `TGameApplication` | control | once, from `Prepare`, before anything exists |
| `LoadOptions` / `SaveOptions` | `TGameApplication` | control | during `Prepare` / on request |
| `HandleParam` | `TGameApplication` | control | once per command-line option, during `Prepare`, after `LoadOptions` |
| `SetupGameSettings` | `TGameApplication` | control | once, from `Run`, before the window exists |
| `ConfigureSurface` | `TGameApplication` | the window's render thread | on **every** surface rebuild, for every window |
| `InitSound`, `InitCursors`, `LoadFonts`, `InitStyles` | `TGameApplication` | control | once, during startup |
| `InitRenderResources` (today: `SelectFonts`) | `TGameApplication` | every window render thread | at startup and whenever derived render resources are invalidated (section 8) |
| `CreateScenes` | `TGameApplication` | control | once, after the subsystems are up |
| `LoadScenes` | `TGameApplication` | control | once, after `CreateScenes` |
| `onResize` | `TGameApplication` | the window's render thread | after a surface rebuild |
| `TGameScene.Load` | scene | control (not a render thread) | once per scene, heavy resource loading |
| `TGameScene.InitGfx` | scene | the owning window's render thread | before the first `Render`, automatically; never call it manually |
| `TGameScene.Process` | scene | the owning window's render thread | at the scene's frequency |
| `TGameScene.Render` | scene | the owning window's render thread | every frame while active |
| `TGameScene.ModeChanged`, `onResize` | scene | the owning window's render thread | after a surface rebuild of its window |

Three rules follow from the table, and they are the whole point of it:

1. **A phase that touches the GPU runs in a render thread.** There is no exception;
   the control thread holds no context.
2. **A phase that runs in a render thread runs once per window.** If it produces a
   value, that value belongs to the window or to the thread — not to a global.
3. **A phase may run more than once.** `ConfigureSurface` and `InitRenderResources`
   are called repeatedly by design. Write them idempotent and cheap.

## 4) Startup

### 4.1 `Create` → `Prepare` → `Run`

```pascal
var app:TMyApplication;
begin
 app:=TMyApplication.Create; // fills engine defaults
 app.Prepare;                // non-visual init: config, logs, settings
 app.Run;                    // window, render, scenes, main loop
 app.Free;
end;
```

`Create` fills the engine defaults into the configuration records
(`appSetup`, `windowSetup`, `requestGL`, `renderSetup`, `startupScenes`). The project
overrides `SetupApplication` and sets its values there.

`Prepare` is non-visual and can be called only once. It makes the process DPI-aware
(per-monitor v2 on Windows — a precondition of the whole surface model), registers the
calling thread's name, calls `SetupApplication`, resolves the writable storage
directories, opens the log, loads the options, and then applies the command line
through `HandleParam` — in that order, so a switch overrides the config file. No
window, no graphics, no `game` object yet.

`Run` creates the `TGame` object with the requested platform and graphics backends,
asks the project for the settings (`SetupGameSettings`), installs the `ENGINE\` and
`MOUSE\` event handlers, installs the surface configuration hook, and starts the
threads. It returns only when the application is finished.

### 4.2 Main window bring-up (main window render thread)

`MainThreadLoop` performs, in order:

1. install the `Engine\` handlers (`emInstant`) and `Engine\Cmd` (`emQueued`);
2. create the OS window, publish it as `window` (threadvar) and `mainWindow` (global);
3. request the screen DPI;
4. `InitMainLoop` → `InitGraph`: create the graphics context, configure the window,
   resolve the first surface, create the default render target, initialise the default
   resources (built-in fonts, default texture, cursors), start the Robot API;
5. set `running` — the signal `Run` is waiting for;
6. enter the frame loop.

### 4.3 Application bring-up (control thread)

`ControlLoop` waits for `running`, then:

1. `SetupHighDPI` — apply the UI scale;
2. create the loader scene, if requested;
3. `InitSound`, `InitCursors`, `LoadFonts`, `SelectFonts`, `InitStyles`;
4. create the message scene, the notification layer, and the console/tweaker scenes if
   requested;
5. `CreateScenes` — the project builds its scenes;
6. `LoadScenes` — `TGameScene.LoadAllScenes` runs each scene's `Load` in turn;
7. signal `GAMEAPP\Initialized`;
8. enter the idle loop.

Scenes therefore become visible while their window is already rendering: the render
thread starts drawing as soon as a scene is active, and calls its `InitGfx` on the way
to the first `Render`.

## 5) The frame

**Main window** (`TGame.FrameLoop`, once per frame):

1. sample the keyboard shift state and mouse buttons; age the key state;
2. `window.ProcessMessages` — this stalls while the user drags or resizes the window;
3. `HandleSignals` — queued signals addressed to this thread;
4. `window.ApplyPendingSurface` — **before anything reads the surface**;
5. sample the pointer, flush aggregated mouse input to the scenes;
6. render and present: `OnFrame` (scene `Process` and input dispatch), then
   `RenderFrame` — for each active scene by Z order: `InitGfx` if it has not run,
   then `Render` — then the cursor and the overlays, then `PresentFrame`;
7. poll the Robot API.

**Extra window** (`ExtraWindowLoop`, once per frame): the same shape without the
application-wide parts — `ProcessMessages`, `ApplyPendingSurface`, `OnFrame`, and,
when the window is active and something changed, `RenderScenesForWindow` followed by
`PresentFrame`. `RenderScenes` sets the `window` threadvar to itself for the duration
of the render and re-asserts the viewport every frame, because backend state is shared
between windows.

A window that has nothing to redraw sleeps instead of spinning; `minRedrawIntervalMs`
forces an occasional refresh.

## 6) Adding a window

`TGame.AddWindow(settings)` is a blocking, serialized call: it starts a `WndThread`,
waits for that thread to report success or failure, and returns the `TWindow`. It may
be called from any thread; when the caller is the main window's render thread, the
main GL context is released for the duration of the shared-context handoff and
re-activated afterwards.

The new thread's startup sequence is the per-window subset of section 4.2: create the
OS window, publish it in its own `window` threadvar, request the DPI, apply the
surface configuration, create the shared graphics context, resolve the surface,
bootstrap the per-thread graphics state (`gfx.InitThreadContext`), show the window,
and only then report "ready" — so the first frame is deterministic.

Note what the new thread does **not** do: it does not run the application-level
startup phases. Anything the project needs per render thread must therefore be part of
a phase that every render thread runs (section 8), not part of `ControlLoop`.

`RemoveWindow` terminates the render thread, waits for it, and frees the window.

## 7) Surface changes

A "surface change" is any of: the window was resized, the DPI changed (the user
dragged the window to another monitor, or changed the system scale), the safe-area
insets changed, the render scale changed, or the surface configuration was replaced.

The rule is **request from anywhere, apply in the owning thread**:

1. Any thread — usually the platform layer handling an OS message — posts a request:
   `RequestResize`, `RequestDPI`, `SetNativeSafeArea`, `SetRenderScale`,
   `SetSurfaceConfig`, `InvalidateSurface`. These only record the request.
2. The owning render thread calls `ApplyPendingSurface` at a defined point in its
   frame. It resolves the request through `ConfigureSurface` (the project's hook, one
   call per rebuild per window), computes the new surface state and its diff against
   the previous one, bumps the surface generation, rebuilds the default render target
   and the viewport.
3. If something actually changed, it notifies: `UpdateScreenScale`,
   `NotifyScenesResize` (with `window` pointing at this window, so scene callbacks see
   their own), and finally `Signal('ENGINE\SURFACECHANGED', wnd)`.

`ENGINE\SURFACECHANGED` carries the window as its tag, and its handler is `emInstant`
— it runs **in that window's render thread**. Any handler must therefore be written as
per-window code: the tag says which window, and anything it computes belongs to that
window or to that thread.

On Windows the chain from the OS looks like this: the process is per-monitor-v2 aware,
so dragging a window between monitors produces `WM_DPICHANGED`; the platform layer
turns it into `RequestDPI`; the window thread applies it on the next frame and emits
one `ENGINE\SURFACECHANGED` with `TSurfaceChange.dpi` in the diff. This is the
cheapest way to test multi-DPI behaviour: two monitors at different scales and a
window dragged across — see `demo/MultiWindow`.

## 8) Settings changes and derived render resources

> This section describes the intended contract. Section 11 lists what the code does
> today.

### 8.1 One phase, two reasons to run it

Some resources are *derived*: font handles resolved for a given size and DPI, metrics
and colours taken from the theme, per-thread caches. They depend on inputs that can
change while the program runs — the DPI of the window they are drawn in, and the
program-wide UI scale preference.

There is no separate "settings changed" handler. Instead, **each render thread runs
again the same basic initialisation phase it runs at startup**. One phase, two reasons
to enter it: the thread just started, or its derived resources were invalidated.

At the scene level this contract already exists and is correct: `InitGfx` is run by
the owning window's render thread, lazily, between frames, before the first `Render`,
gated by `gfxInitialized`, and is never called manually.

### 8.2 The application-level phase

```pascal
// Rebuild derived render resources: font handles, theme-derived metrics and colours,
// per-thread caches. Called by EVERY window render thread — at startup and whenever
// the resources were invalidated. Must be idempotent and cheap.
// Runs with `window` set to the window being served; `window=mainWindow` tells the
// main window apart, for resources that only it has to rebuild.
procedure InitRenderResources; virtual;
```

The phase takes no parameters: like `Render`, it reads its context from `window`,
which a render thread always has. An implementation that keeps some resources
application-wide guards them with `window=mainWindow`:

```pascal
procedure TMyApp.InitRenderResources;
begin
 uiFont:=txt.GetFont('Default',10);      // thread-local: every window rebuilds it
 if window=mainWindow then
  RebuildSharedAtlas;                    // one window is enough
end;
```

**Do not use thread identity for this test.** `game.mainThread` looks like the right
question to ask and is not: it is `nil` on macOS and on iOS, because there the main
window's loop runs on a thread the engine did not create (section 1.1). A guarded
`(game.mainThread<>nil) and game.mainThread.IsCurrent` therefore answers *false* in
the main window's render thread on exactly those platforms — a silent failure on a
configuration the author never runs. `window=mainWindow` asks what is actually meant
— "am I drawing the main window?" — and is correct everywhere.

The guarantee this phase gives a project — and the reason it is worth the churn — is
that it runs **in the thread that will draw with the resources it creates**. Today no
such guarantee exists.

### 8.3 Invalidation

Invalidation is a generation counter, not a broadcast: `game.renderGen`, incremented
atomically by anything that invalidates derived resources (the UI scale preference, a
theme change, a DPI change). Every window render thread keeps its own `lastRenderGen`
and compares it at the same point in the frame where it already checks
`gfxInitialized`; if it is behind, it runs the phase — the application hook plus a
reset of `gfxInitialized` on its own scenes — and catches up.

A counter rather than an event because:

- no delivery is needed to threads that may not exist yet when the setting changes;
- a window created later starts at the current generation and does not run the phase a
  second time;
- there is no "the signal arrived mid-frame" race: the comparison happens at a point
  where re-initialisation is already legal.

### 8.4 Consequences

- **Font handles become thread-local.** If every render thread runs the phase, its
  results must be per-thread, otherwise the thread that ran it last overwrites the
  others' values. A single-window application sees no difference.
- **Scope.** Only cheap derived things belong in the phase. Heavy loading stays in
  `Load`, which runs outside the render threads.
- **Triggers stop calling the phase directly.** A settings change, `SetupHighDPI` and
  `onResize` bump the generation; they do not call the phase themselves.

## 9) Shutdown

1. Something requests termination (the window is closed, `game.Stop`, a fatal error).
2. The main window thread leaves its frame loop, sets `terminated`, and signals
   `Engine\AfterMainLoop`.
3. It then waits for permission to finish the teardown, so that the control thread is
   not cut off in the middle of its work.
4. Teardown, in the main window thread: stop the extra windows (each `WndThread`
   releases its own graphics resources and closes its own window), release the
   graphics system, close and free the main window.
5. The control thread leaves its idle loop on `terminated` and signals
   `GAMEAPP\Terminated`.
6. `TGameApplication.Destroy` stops the game and shuts the sound system down.

A scene must be frozen before it is destroyed; destroying an active scene raises.

## 10) Rules of thumb

- **Pick a home by asking who can differ, not by what is convenient to read.** One
  answer per process → global. One per window → `TWindow`. One per render thread →
  `threadvar`, and only if every writer is that render thread.
- **Do not compute a global from one window.** If the value depends on DPI, canvas or
  surface, it is per-window even when today's application has one window.
- **GPU work only in a render thread**, and only in the thread that owns that window.
- **Take the window explicitly** when the code can run outside a render thread. The
  ambient `window` is `nil` in worker threads and points at the main window in the
  control thread.
- **Assume repetition.** `ConfigureSurface`, `onResize` and the render-resource phase
  run many times; make them idempotent.
- **Never call `InitGfx` yourself.** The render loop owns it.
- **Test the multi-DPI path.** Two monitors at different scales, one window dragged
  between them, is a two-second test that covers most of what this chapter is about.

## 11) Implementation status

The following differ from the contract above and are the things to fix.

| # | What the code does | What it should do |
|---|---|---|
| 1 | `SelectFonts` is called from the control thread at startup and from a window render thread on `ENGINE\SURFACECHANGED` (and again from `onResize`), storing results in ordinary fields | one phase, `InitRenderResources`, run by every render thread, with thread-local results |
| 2 | Nothing invalidates `gfxInitialized`, so a scene's `InitGfx` runs once per scene lifetime | reset it when the generation advances |
| 3 | No generation counter exists; triggers call the phase directly | `game.renderGen` plus a per-thread `lastRenderGen` |
| 4 | `TTextDrawer.globalScale` is a `class threadvar` carrying both the per-window DPI scale and the program-wide preference | split the two roles; the preference is global, the DPI scale is per-window |
| 5 | `game.screenScale` is application-global but computed only from `mainWindow` (`UpdateScreenScale` returns early for any other window) | per-window UI scale |
| 6 | `TUIElement` keyboard focus (`fControl`) is a `threadvar` although it can be set from a worker thread | window state, like `TWindow.modal` |
| 7 | The control thread relies on `window` being set to `mainWindow` for scene and UI setup | pass the window explicitly |

Items 1, 3, 4 and 5 are one piece of work; the analysis, the options and the staged
plan are in `Work/text_scale_design.md`. Item 6 is the known remaining case of the
`threadvar`-as-window-state mistake described in section 2.3.
