# Apus.Engine.Sky

Optional clear-day sky renderer. Create one `TSky` per scene and call `Draw`
on the render thread, after setting a perspective projection and camera, before
drawing opaque geometry. The shader is created lazily; destroy the object while
the graphics context is still available.

```pascal
sky:=TSky.Create;
// TSkyParameters.ClearDay is assigned by the constructor.
sky.parameters.sunDirection:=Vec3(0.4,0.3,1);

// Each frame, after setting the target, viewport, projection and camera:
gfx.target.ClearDepth(1);
sky.Draw;
gfx.SetCullMode(TCullMode.DrawCCW);
// Set world lighting/materials, then draw the scene.
```

`TSkyParameters` exposes RGB zenith/horizon/sun colors, world up and direction
towards the sun, horizon gradient power, angular sun radius (radians) and halo
strength. Directions must be nonzero and are normalized for rendering. The
default world up is Z; the default solar diameter is about 0.53 degrees. Set
`sunRadius` to zero to hide the disk. This is an artistic daylight approximation,
not a physical atmosphere or a night-sky model. RGB values use the same output
color space as the rest of the scene; no separate exposure/gamma pass is applied.

The oversized screen triangle reconstructs world directions using inverse
projection/view matrices. Camera translation does not move the sky; asymmetric
perspective frusta and rendering into a texture use the same path. Below the
horizon, the gradient continues as the horizon color. The sun disk is hidden
when its center lies below the horizon.

`Draw` keeps the target, viewport, clipping, transformations, depth contents,
depth state and blending. It selects `DrawAll` culling and resets to the stock
shader on exit. Set the culling and materials required by subsequent geometry.
It does not clear the target. Clear depth before rendering a new scene.

For future environment capture, draw the sky and the scene using each capture
camera. A sky-only image lacks the terrain and object silhouettes required for
scene reflections. This module does not create reflection maps or modify world
lighting.

There are no textures, dome meshes, CPU update jobs, weather or cloud layers in
this version. Shader dialects are desktop GLSL 330 and GLSL ES 300.
