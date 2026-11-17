# Using Apus Engine: start here

For developers and coding agents who write an **application on top of the engine** (a game,
a tool, a test stand). Engine contributors read [`CLAUDE.md`](../CLAUDE.md) instead: it is
about refactoring the engine itself.

Read this page first, then follow the links for the task at hand. A consumer project can
pull it into its agent instructions with one line (see the end of the page).

> Draft 2026-11-17. Collected from the first-contact feedback of an application developer;
> sections marked *(temporary)* describe current defects and go away when they are fixed.

## 1. Where the documentation is

| What | Where |
|---|---|
| Published manual chapters | [`manual/README.md`](README.md) |
| Threads, phases, where state lives, `Create` → `Prepare` → `Run` | [`ch18_application_lifecycle.md`](ch18_application_lifecycle.md) |
| Images and textures: loading, sharing, `liffAllowChange`, freeing at run time, render-thread rules | [`ch21_resource_system.md`](ch21_resource_system.md) |
| Config files (CTL3, `Apus.Config`) | [`config_files.md`](config_files.md) |
| Fonts, text size, DPI, custom drawers | [`text_and_dpi.md`](text_and_dpi.md) |
| Which signals the engine sends (UI, combo, window...) | [`engine_signal_inventory.md`](engine_signal_inventory.md) |
| Robot API: automating and testing a running application | [`robot_api_protocol.md`](../robot_api_protocol.md) |
| Working demos with a one-line description each | [`demo/demo_inventory.md`](../demo/demo_inventory.md) |
| What changed since engine4 | [`engine_changes.md`](../engine_changes.md), [`Base/engine5_changes.md`](../Base/engine5_changes.md) |
| What is done, in progress, planned | [`engine5_feature_roadmap.md`](../engine5_feature_roadmap.md) |

Below that level, the documentation is the comment next to the declaration in the unit's
interface section. If a comment and the code disagree, or a contract you need is not
written anywhere, that is a defect of the engine: report it, do not just work around it.

## 2. Task → modules → example

| Task | Units | Look at |
|---|---|---|
| Application skeleton, scenes | `Apus.Engine.GameApp` (`TGameApplication`), `Apus.Engine.Scene`, `Apus.Engine.UIScene` | `demo/ProjectTemplate`, `demo/SimpleDemo`, `demo/01-Scenes` |
| Global drawing objects | `Apus.Engine.API`: `game`, `gfx`, `draw`, `txt`, `shader`, `transform` | ch18 |
| UI elements and widgets | `Apus.Engine.UITypes` (`TUIElement`), `Apus.Engine.UIWidgets` (button, combo, scrollbar, edit box...), `Apus.Engine.UILayout` | `demo/UILab`, `demo/UIScaleDPI`, `demo/StyleDemo` |
| A custom-drawn UI element in the stock look | `Apus.Engine.DefaultStyle`: `DrawElementBox`, `ResolveUITextStyle`, `WriteUIText`; text alignment `TTextAlignment` is in `Apus.Engine.Types` | `text_and_dpi.md` (custom drawers) |
| Messages to the user (result, refusal, error) | `Apus.Engine.Notifications`: `ShowToast(text, kind)` | |
| Text and fonts | `Apus.Engine.TextDraw` (`txt`) | `demo/TextDemo`, `text_and_dpi.md` |
| 2D primitives, gradients | `Apus.Engine.Draw` (`draw`) | `demo/Draw2D`, `gradient_fills.md` |
| Images, textures, sampling | `Apus.Engine.Resources` (`TTexture`, `LoadImage` flags) | `demo/AdvTex`, ch21 |
| Custom shaders | `shader` (`IShader.Build`, `UseCustom`), `Apus.Engine.ShadersGL` | `demo/NormalMap`, `demo/ShadowMap` |
| Meshes, procedural shapes, OBJ | `Apus.Engine.Mesh`, `Apus.Engine.GpuMesh`, `Apus.Engine.MeshShapes`, `Apus.Engine.OBJLoader` | `demo/MeshLab`, `demo/Simple3D` |
| Debug lines and gizmos in 3D | `Apus.Engine.DebugDraw` | `demo/MeshLab` |
| Sound (opt-in, `-dSDLMIX`) | `Apus.Engine.Sound`, `Apus.Engine.SoundSDL` | `demo/SoundDemo` |
| Config / experiment description | `Apus.Config` | `config_files.md` |
| Any file access | `Apus.Files`: `Files.Exists`, `Files.LoadAsBytes`, `Files.Save`... | |
| Application folders | `Apus.Core`: `BaseDir` (read-only resources; the `.app` Resources on macOS), `AppDataDir`, `LogDir`, `TempDir` | |
| Numbers in files, independent of the locale | `Apus.Conv`: `Conv.ToStr(v, maxDec, minDec, '.')`, `Conv.ToFloat` | |
| Command-line `name=value` parameters | `Apus.Utils`: `GetParam` | |
| Automated GUI tests | `Apus.Engine.RobotAPI` | `robot_api_protocol.md` |

## 3. Conventions you cannot guess

- **UI element names are identifiers.** Letters, digits, `_` and `\`; no spaces, no
  leading digit. Names live in a per-class registry: a second live element with the same
  name raises `Duplicate object name`. A name starting with `_` is neither registered nor
  published, so it need not be unique - use it for elements you create dynamically.
  Do not build names from captions ("View & Light" is not a valid name).
- **Who owns a UI subtree.** Freeing an element frees its children; free it in the
  window's thread, from other threads call `Remove`. If you keep a plain
  object that wraps a panel, its destructor must free the panel's root element, otherwise
  rebuilding the panel fails on the old names that are still in the tree.
- **Two opposite key-handler conventions.** `TUIElement.onKey` returns **false** when it
  consumed the key; `TGameScene.onKeyDown/onKeyUp` return **true** when they consumed it.
  Routing order: the focused element (after its ancestors' `onDescendantKey` filters) →
  UI hotkeys → scene hotkeys (`RegisterHotKey`) → `onKeyDown`. A key the focused element
  consumes never reaches the scene.
- **Widget events are signals**, not method callbacks: `UI\<name>\ONSELECT` and friends,
  listed in `engine_signal_inventory.md`. Setting `curItem`/`curTag` of a combo box from
  code does not send `ONSELECT`.
- **Threads.** GPU work only in the render thread of the window it belongs to. From a UI
  handler or another thread, post the work with `window.QueueCall`. The `window` variable
  is `nil` in worker threads. Details: ch18, section 10.
- **Files go through `Files`**, so packs and extra data roots see them. Third-party
  loaders get data as a memory buffer, not a path.
- **Resources are reference counted**: free what you loaded (`FreeImage`, `Free`).

## 4. When something goes wrong

- The log is `game.log` in `LogDir`. **Read it from the first error, not the last.**
  An exception inside an event handler is caught and logged (`Error in event handler`,
  `Error in handling event`) and execution continues; the visible failure (often an access
  violation in the frame, `Error in main loop`, repeated every frame) can come much later.
  Typical case: an invalid UI element name. The element is created and attached, but its
  name is rejected in the `UI\ItemCreated` handler (only in builds with assertions on), so
  code that looks the element up by name gets `nil` and crashes frames later.
- **Compiler errors:** a missing unit in `uses` makes FPC report a cascade of
  `Identifier not found`; fix the first one. Find the unit through the table in section 2;
  the less guessable homes are `Apus.Engine.DefaultStyle` (drawer helpers),
  `Apus.Engine.Types` (shared enums like `TTextAlignment`) and `Apus.Utils`.
- `IShader.Build` raises an exception whose message already lists the shader source lines
  around the error, with line numbers. Pass the shader file text as is, so the numbers
  match the file.
- Debug builds: `Ctrl+Shift+I` opens the UI inspector (element tree and live fields) for
  the window.
- The Robot API lets a test drive the running application and query UI elements; when the
  application stops answering robot requests, look at `game.log` first.

## 5. Known traps *(temporary)*

Ordered by how long they take to diagnose, most expensive first.

- **A custom shader and `TGpuMesh.Draw`**: `DrawRange` applies the mesh layout through
  `shader.ApplyMeshLayout`, which replaces the custom program: the mesh silently renders
  with the stock shader (Racing RQ-41). Until fixed: `shader.Apply(Default(TVertexLayout))`,
  bind `vertexBuffers[0]`/`indexBuffer` with `gfx.resMan.UseVertexBuffer`/`UseIndexBuffer`,
  call `renderDevice.DrawMesh(mesh.layout,...)` yourself, then unbind both buffers.
- **`TUIScrollBar` drag rounds the value to an integer**: a 0..1 range becomes on/off.
  Use an integer range and scale it, or override `onMouseMove`, until a fractional slider
  lands (R-14 / Racing RQ-20).
- **`TTexture.SetFilter(fltBilinear)` keeps mipmaps** (`GL_LINEAR_MIPMAP_NEAREST` when
  levels exist), contrary to the declaration comment.

## 6. Connecting this page to a consumer project

In the project's `CLAUDE.md` (agents that support includes):

```
@<engine checkout>/manual/using_the_engine.md
```

In `AGENTS.md` and for humans, a plain sentence: "Before using an engine API, read
`<engine checkout>/manual/using_the_engine.md`; the engine documentation it links to is
the reference, report contracts it does not cover."
