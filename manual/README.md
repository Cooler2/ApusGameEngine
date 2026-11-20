# Engine5 manual

Writing an application on the engine? Start with [Using Apus Engine: start here](using_the_engine.md)
(draft) - where the documentation is, which units a typical task needs, conventions and known traps.

The engine5 manual is being written; only these chapters are published so far:

- [Chapter 18. Application Lifecycle](ch18_application_lifecycle.md) - threads, where
  state lives (application / window / thread) and which phases the engine calls on your code.
- [Chapter 21. Resource System: Images and Textures](ch21_resource_system.md) - how
  images are loaded, found, shared and released.
- [Static AEM assets](aem_static_assets.md) - Blender preparation, LOD collections,
  texture maps, and loading and drawing a model in a game.
- [Configuration files (CTL3)](config_files.md) - draft for review: the CTL3 syntax,
  typing rules, layers and the `Apus.Config` interface that replaces `Apus.ControlFiles`.
- [Gradient fills](gradient_fills.md) - draft for review: `TFill`, the drawing calls that
  take it, program switches, gradients in UI styles (`fill`, `fill-shade`, transitions)
  and the limitations.
- [Optional TextFX captions](ui_textfx_style.md) - button wrappers, caption children,
  shared content displacement and effect caching.
- [Color Picker](ui_color_picker.md) - first implementation for API review: color
  buttons, replaceable editors, preview/commit/cancel and shared recent colors.
- [Clear daylight sky](Sky.md) - first implementation for API review: gradient,
  sun halo/disk, current-camera rendering and environment-capture boundaries.
- [Text size, DPI, and font lifetime](text_and_dpi.md) - the scaling contract,
  automatic and explicit sizing, custom drawers, handle invalidation, and how to
  distinguish client mistakes from engine defects.
- [Engine signal inventory](engine_signal_inventory.md) - snapshot of the signals the
  engine sends and handles.

Until the rest is written, these are the best places to learn the engine:

- [`demo/`](../demo/) and [`demo/demo_inventory.md`](../demo/demo_inventory.md) - working
  demos with a short description of each; start with `SimpleDemo` and
  [`ProjectTemplate`](../demo/ProjectTemplate/README.md).
- [`engine_changes.md`](../engine_changes.md) and [`Base/engine5_changes.md`](../Base/engine5_changes.md) -
  what changed compared to engine4 in the engine and in the Base library (migration guides).
- [`robot_api_protocol.md`](../robot_api_protocol.md) - the Robot API for automated
  testing and tool integration.
- [`engine5_feature_roadmap.md`](../engine5_feature_roadmap.md) - feature status and plans.
