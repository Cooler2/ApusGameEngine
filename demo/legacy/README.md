# Legacy demos

These demos predate engine5 and do not compile yet. Each one waits for migration to the
engine5 foundation API; until then they are kept here as reference, not as working examples.

The blocker of each demo is listed in [`../demo_inventory.md`](../demo_inventory.md)
("Build status" section). Most of them still use the retired `Apus.Common` /
`Apus.CrossPlatform` units; `CharAnimation` is blocked by the engine itself (skeletal models,
see [`../../legacy/README.md`](../../legacy/README.md)).

| Demo | Topic |
|---|---|
| `Billboards` | 3D billboards, camera/zoom |
| `Borderless` | borderless/resizable window |
| `CharAnimation` | animated IQM character |
| `ControllerDemo` | gamepad/joystick input |
| `EngineTest` | large old set of manual graphics/resource tests |
| `NinePatch` | nine-patch rendering (covered by `demo/Draw2D` now) |
| `Particles` | 2D/3D and soft particles |
| `Shaders` | custom shader snippets |

When a demo is migrated and builds again, move it back to `demo/` and add it to the CI demo
lists (see `demo_inventory.md`).

For working examples use the demos in [`demo/`](../) - start with `SimpleDemo` or
[`ProjectTemplate`](../ProjectTemplate/README.md).
