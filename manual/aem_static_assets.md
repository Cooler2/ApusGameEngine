# Static AEM assets in Blender and games

The Blender add-on exports static models to experimental AEM 0.0. A model can contain several meshes and LODs, with a logical material name and optional texture paths per part. The same exported model can be placed many times in a game. [Binary format](../aem_format.md)

## Install the exporter

The add-on sources are in [tools/blender/io_export_aem](../tools/blender/io_export_aem). Blender 4.5.4 LTS was used for export and installation checks. To build an installable ZIP from the repository, run these commands from the engine root.

```sh
cd tools/blender
python -m zipfile -c io_export_aem.zip io_export_aem
```

In Blender, open **Edit → Preferences → Add-ons**, choose **Install from Disk**, and select the ZIP. Enable **Apus Engine Mesh (.aem)**. In Object Mode select the mesh objects, then use **File → Export → Apus Engine Mesh (.aem)**.

## Prepare meshes and LODs

1. Model in right-handed Z-up coordinates. Place the intended game pivot at the Blender scene origin. The exporter uses evaluated object transforms and modifiers, including mirrors, and keeps the resulting mesh placements relative to that origin.
2. Set the scene's unit scale and select **Game Units per Metre** at export. With Blender unit scale 1 and one game unit per metre, leave the export scale at 1.
3. Set the active UV layer to the one used by the base color and normal map. The first other UV layer supplies UV1. The active Point or Face Corner color attribute can supply vertex colors. The exporter triangulates the geometry. Add a Triangulate modifier before baking and exporting normal-mapped n-gons so Blender can compute tangents on the same triangles.
4. For a model with several LODs, create scene-root collections `LOD0`, `LOD1` and so on. Put the finest geometry in `LOD0` and align all levels to the same origin. Link a shared object into several collections to reuse the same mesh. Keep those collections in the active View Layer and enable **LOD Collections** in the export dialog. The export uses mesh objects within those collections and their child collections.
5. Set the numeric collection property `aem_min_screen_height` for a game-specific transition. Fractions must strictly descend, with zero for the coarsest level. For example, three levels can use `0.25`, `0.08` and `0.0`. Defaults are `0.5`, `0.25` and so on for all levels except the coarsest, which defaults to zero.

## Bake and package textures

The exporter uses the effective material assigned to each face, including object-level overrides. The Blender material name becomes the slot name. Set `aem_slot` to give several Blender materials the same game-facing name while retaining separate maps.

Add optional string properties to the material for the maps the game should resolve.

| Property | Contents |
| --- | --- |
| `aem_basecolor` | Relative path to the color map, for example `textures/seats.png` |
| `aem_normal` | Relative path to the linear tangent-space normal map |
| `aem_opacity` | Relative path to the linear cutout mask, sampled from red |

These properties are paths relative to the exported AEM directory. Use forward slashes. Ship the referenced files with the AEM and preserve that directory layout in your game's resources. The shader, cutoff, and texture objects belong to the game.

Prepare the color map as sRGB and normal and opacity maps as data. UV V is flipped during export. If the normal bake's green channel points along Blender's original increasing V, invert green in the game copy so the map follows the exported tangent basis. Preserve the original bake for editing. For the stock mesh shader, copy the opacity mask's red channel into the base color texture's alpha channel. A custom shader can sample the separate opacity texture.

For the Racing grandstand, put the volumetric seats in LOD0. The baked LOD1 and LOD2 meshes use the same `Seat_atlas` slot with separate bindings for their own atlases. Keep the binding-specific textures with each level so the lower-detail geometry samples its matching bake.

## Load and draw in a game

Use `TModelAsset.LoadAEM` in scene `Load`, and call `Upload` in `InitGfx` while the graphics context is current. Share the asset between placements and give each `TModelInstance` its own transform and LOD. Free the instances before the asset, on the graphics thread while the uploaded resources are still live. [Application lifecycle](ch18_application_lifecycle.md)

This scene fragment shows the engine API with a plain material. It assumes the application has created the scene and selected its camera and projection. The types are available through `Apus.Engine.API`. Use `Apus.Engine.Scene`, `Apus.Core` and `Apus.Geom3D` for the scene type, strings and transforms.

```pascal
type
  TPropScene=class(TGameScene)
  private
    fAsset:TModelAsset;
    fInstance:TModelInstance;
    function BindPart(const part:TModelDrawPart):boolean;
  public
    procedure Load; override;
    procedure InitGfx; override;
    procedure Render; override;
    procedure ReleaseModel;
  end;

procedure TPropScene.Load;
begin
  fAsset:=TModelAsset.LoadAEM(String8('models/grandstand.aem'));
  fInstance:=TModelInstance.Create(fAsset);
  fInstance.Transform:=TMat4.Translation(5,0,0);
  inherited;
end;

procedure TPropScene.InitGfx;
begin
  inherited;
  fAsset.Upload;
end;

function TPropScene.BindPart(const part:TModelDrawPart):boolean;
begin
  shader.NormalMapOff;
  shader.TexMode(0,tblDisable,tblDisable);
  if fAsset.MaterialSlotName(part.slotIndex)='Seat_atlas' then
    shader.Material($FFFFFFFF,0)
  else
    shader.Material($FFB0A59F,0);
  result:=true;
end;

procedure TPropScene.Render;
begin
  fInstance.Draw(BindPart);
end;

procedure TPropScene.ReleaseModel;
begin
  fInstance.Free;
  fInstance:=nil;
  fAsset.Free;
  fAsset:=nil;
end;
```

Call `ReleaseModel` from the game's graphics teardown before releasing the context. Assign `fInstance.LOD:=fAsset.SelectLOD(projectedHeightFraction)` if the game uses the authored thresholds, or set a level explicitly.

A `TModelMaterialBinder` receives a `TModelDrawPart`. Use `part.slotIndex` to choose material behavior and cache the images by `part.bindingIndex` per asset. Get a relative path with `fAsset.TextureHint(part.bindingIndex,'basecolor')` or `'normal'` and resolve it against the logical directory of `fAsset.SourcePath`. Bind the prepared color and alpha with `shader.TexMode(0,tblModulate,tblModulate)` and `shader.UseTexture`. Enable a loaded normal map with `shader.NormalMap` when the pass uses lighting. Set or clear shader and texture state for each part. Return false to skip it for the current pass. The model retains its placement while the binder runs and restores the caller's transforms after drawing. [Images and textures](ch21_resource_system.md)
