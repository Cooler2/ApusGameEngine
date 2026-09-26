# Legacy engine units

Engine units that predate engine5 and **do not compile** in the current tree. They are kept
for reference and future migration, but no active project, demo or test uses them.

## Why they do not build

All of them depend on `Apus.Common` (and `Model3D` also on `Apus.CrossPlatform`) - the old
monolithic foundation units that engine5 split into `Apus.Core`, `Apus.Conv`, `Apus.Strings`,
`Apus.Log`, `Apus.Threads`, `Apus.Files` and others. The retired units are no longer in the
repository. The migration algorithm is described in `CLAUDE.md` ("Refactoring Notes"); the list
of API changes is in [`Base/engine5_changes.md`](../Base/engine5_changes.md).

## Contents

| Unit | What it is | Replacement / status |
|---|---|---|
| `Apus.Engine.Model3D` | skeletal 3D model (`TModel3D`): meshes, bones, animations | waits for roadmap card **R-03** (native AEM pipeline, new `TModel`/`TModelInstance`) |
| `Apus.Engine.IQMloader` | IQM model loader for `TModel3D` | IQM is dropped; skeletal models wait for R-03 |
| `Apus.Engine.AEMLoader` | AEM model loader for `TModel3D` | will be reworked in R-03 |
| `AEM specification.txt` | AEM file format description | input for R-03 |
| `Apus.Engine.SoundBass` | BASS audio backend (declarations only) | use `Apus.Engine.SoundSDL` (`-dSDLMIX`) |
| `Apus.Engine.SoundImx` | IMixerPro audio backend (Win32 only, `-dIMX`) | use `Apus.Engine.SoundSDL` (`-dSDLMIX`) |
| `Apus.Engine.SteamAPI` | Steam client integration (`-dSTEAM`) | not migrated; `STEAM` builds are unsupported until it is |
| `Apus.Engine.UDict` | old UI localization dictionary | `Base/Apus.Translation` |
| `Apus.Engine.BitmapStyle` | old image-based UI style | no replacement yet (see `Apus.Engine.DefaultStyle` / `CustomStyle`) |
| `Apus.Engine.ComplexText` | helpers for complex (marked-up) text strings | markup is handled by `Apus.Engine.TextDraw` (`toComplexText`) |
| `Apus.Engine.Objects` | old animated game-object helpers | no replacement |
| `Apus.Engine.SpritePacker` | rectangle packer for sprite atlases | no replacement yet |

For geometry and static 3D content use the engine5 units `Apus.Engine.Mesh`,
`Apus.Engine.GpuMesh`, `Apus.Engine.MeshShapes` and `Apus.Engine.OBJLoader` (see
`demo/Simple3D`, `demo/ShadowMap`, `demo/MeshLab`). For networking use `Base/Apus.Socket` and
`Apus.Engine.HttpGameClient` / `HttpGameServer` (see `demo/Networking`).

## Base

- `Base/demo/tcp/TestTCP.dpr` -> `legacy/Base/demo/tcp/`: an old TCP demo on
  `Apus.Common`; `Base/tests/TestTCP.dpr` covers `Apus.TCP` now.
- `Base/tools/ListFonts` -> `legacy/Base/tools/ListFonts/`: font listing tool on the
  pre-engine4 `MyServis` unit.

## Remaining references

- `Apus.Engine.GameApp` uses `SteamAPI` under `{$IFDEF STEAM}` - kept as is.
- `Apus.Engine.Sound` uses `SoundImx` under `{$IFDEF IMX}` - kept as is.
- `tools/legacy/TreeGen` uses `Model3D` and does not build until it is migrated
  (the other non-building tools are in `tools/legacy/` too).
- `demo/legacy/CharAnimation` and `demo/legacy/EngineTest` use the 3D units.
