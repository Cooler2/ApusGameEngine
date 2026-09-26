# Legacy tools

These tools predate engine5 and do not compile yet: they use the retired
`Apus.Common` (or the even older `MyServis`), and `TreeGen` needs the skeletal
`Apus.Engine.Model3D` from [`legacy/`](../../legacy/README.md). They are kept as
reference until they are migrated or replaced.

| Tool | What it does | Blocker |
|---|---|---|
| `Convert3d` | 3D model converter | `Apus.Common` |
| `ConvertStr` | image comparison/conversion helper | `Apus.Common` |
| `MakeAtlas`, `MakeAtlas2` | texture atlas builders | `MyServis` |
| `SliceImg` | image slicer | `Apus.Common` |
| `upgrade` (+ `engine4.upgrade`) | engine3 -> engine4 source upgrader | `Apus.Common` |
| `TreeGen` | procedural tree generator | `Apus.Engine.Model3D` (legacy) |

When a tool builds again, move it back to `tools/`. The engine4 -> engine5 source
upgrader, `tools/upgrade5.dpr`, is current.
