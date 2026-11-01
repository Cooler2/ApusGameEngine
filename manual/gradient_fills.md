# Gradient fills (draft)

Draft for review. Covers drawing with gradients (`TFill`) and using them in UI styles.
Introduced by R-39 (see `engine5_feature_roadmap.md`).

## The fill: `TFill`

A fill says what color each point of a shape gets. It is a plain record declared in
`Apus.Engine.Types` and re-exported by `Apus.Engine.API` (no managed fields: cheap to
copy, pass it as `const`). Every drawing call that accepts a fill takes it as an explicit
parameter - there is no "current fill" state to set and reset.

Kinds:

| Kind | Constructor | Meaning |
|---|---|---|
| `fkNone` | `TFill.None` | nothing is drawn |
| `fkSolid` | `TFill.Solid(color)` | one color |
| `fkLinear` | `TFill.Linear(angle,c1,c2)`, `TFill.Linear(p0,p1,c1,c2,units)` | gradient along a line |
| `fkEdge` | `TFill.Edge(width,cEdge,cInner)` | gradient by the distance from the shape edge, inward |

```pascal
uses Apus.Engine.API; // TFill, TCornerRadii; enum values (fsReflect, fkEdge...) need Apus.Engine.Types

var
  body,frame:TFill;
begin
  body:=TFill.Linear(180,$FFE2E7F0,$FF8C96A8);                        // top to bottom
  body:=TFill.Linear(90,$FF000000,$FFFFFFFF).AddStop(0.5,$FFFF0000);   // 3 stops
  frame:=TFill.Edge(4,$FF5A6270,$FF3A4250).AddStop(0.4,$FFC8D0DC);     // metal frame cross-section
  draw.RoundRect(x1,y1,x2,y2,6,4,frame,body);
end;
```

### Linear gradients

- `Linear(angle,...)` uses CSS angles: `0` - to top, `90` - to right, `180` - to bottom,
  `270` - to left. As in CSS, the gradient line is fitted to the shape so that the end
  colors land exactly in the corners at any aspect ratio (a 45-degree gradient goes from
  the bottom-left corner to the top-right one even in a wide button). The line is built
  when the shape is drawn, from its bounding box, so one fill value suits shapes of any
  size.
- `Linear(p0,p1,...,units)` sets the line explicitly:
  - `fuLocal` (default) - `p0`, `p1` are fractions of the shape bounding box (0..1);
  - `fuAbsolute` - drawing coordinates. Use it to continue one gradient over several
    shapes (rows of a list, segments of a bar).
- Outside 0..1 the gradient follows `spread`: `fsPad` (the end colors continue, default),
  `fsRepeat`, `fsReflect` - set with `WithSpread`.

### Edge gradients

`Edge(width,cEdge,cInner)` colors by the distance from the shape edge: `t=0` on the edge,
`t=1` at `width` pixels inside, then the inner color. This gives a bevel, an inner glow
or the cross-section of a frame (a "metal" profile with a highlight in the middle).

- In `RoundRect` the border and the fill measure the distance differently:
  - a border fill spans exactly the border thickness (the `width` of an edge fill used as
    a border is ignored; `TFill.Edge(0,...)` is fine there);
  - a fill measures from the inner edge of the border with its own `width`.
- Edge fills need the distance to the shape edge, which only `RoundRect` computes.
  `FillRect`, `FillRRect` and `Polygon` draw an edge fill as its inner (last) color.

### Stops

- Up to `MAX_FILL_STOPS` = 4 color stops. Constructors create two (at 0 and 1);
  `AddStop(pos,color)` inserts more in position order (a stop at an existing position
  goes after it, so two stops at one position make a hard edge).
- Colors are `$AARRGGBB`. Interpolation is premultiplied: a fade to transparent keeps
  the hue and does not darken (`$FFFF0000 -> $00000000` is red fading out, not red
  turning brown).

### Ramp textures

`WithRamp(tex)` takes the colors from an image instead of the stops: the middle row of
the texture, left to right (the texture may be a region of an atlas). The stops are
ignored then; the spread still applies. Use it for more than 4 colors or for a palette
painted by an artist. The fill does not own the texture: keep it alive while fills use it.
A ramp is a texture switch on top of the program switch (the border has its own unit).

### Other operations

| Function | Use |
|---|---|
| `IsVisible` | false for `fkNone` and for fully transparent colors |
| `ColorAt(x,y,box)`, `ParamAt`, `ColorAtParam`, `GetLine` | CPU evaluation: custom geometry, tests (edge fills give the inner color, ramps are ignored) |
| `Add(c)`, `Sub(c)`, `MixWith(c,t)` | `Color.Add/Sub/Mix` on every stop - derived state colors |
| `Faded(k)` | alpha of every stop multiplied by `k` (fades); a ramp is not faded |
| `TFill.Mix(a,b,t,r)` | interpolate two fills (see "Transitions"); false if they can't be |

`TCornerRadii` holds the radii of the four corners, clockwise from the top-left:
`TCornerRadii.All(r)`, `TCornerRadii.Init(tl,tr,br,bl)`.

## Drawing calls

| Call | Edges | Path |
|---|---|---|
| `RoundRect(x1,y1,x2,y2,radii,borderWidth,border,fill)` | antialiased | shape shader, always |
| `RoundRect(...,radius,borderWidth,border,fill)` | antialiased | shape shader, always |
| `RoundRect(...,radius,borderWidth,borderColor,fillColor)` | antialiased | solid shortcut; `fillColor=0` - no fill |
| `FillRect(x1,y1,x2,y2,fill)` | pixel edges | vertex colors when exact, the shape shader otherwise |
| `FillRRect(x1,y1,x2,y2,fill,r)` | geometry, no AA | as `FillRect` |
| `Polygon(points,cnt,fill)` | geometry, no AA | as `FillRect`; local units use the bbox of the points |
| `FillGradrect(...,color1,color2,vertical)` | pixel edges | a wrapper: `FillRect` with `Linear(180)` or `Linear(90)` |

Coordinates follow `FillRect`: `x1..x2`, `y1..y2` are the pixels included, the shape edge
lies half a pixel outside their centers.

`RoundRect` notes:

- The radius of each corner and the border width are limited to half the smaller side.
  `radius:=999` therefore makes semicircle ends (a pill shape) at any size. The geometry
  versions (`FillRRect`, `RRect`) are limited the same way.
- Any border width works on any corner, including sharp ones.
- The fill lies inside the border; the border is drawn over the fill area, not blended
  over it (a translucent border shows what is behind the shape, not the fill).
- Only the area that is drawn is rasterized: a frame without a visible fill covers just a
  band along its edge, so a large window frame costs about as much as a small button.
- Edges are antialiased over one physical pixel (`fwidth`), so they stay sharp at any
  `pixelRatio`.

## Performance: program switches

Most 2D drawing (images, text, `FillRect`, lines) uses the standard 2D program. The shape
shader is a separate program, so drawing a shape after standard drawing (and back) is a
program switch. On the reference machine (RTX 3060, GL 3.3) a switch costs about 6 us of
CPU - about as much as two draw calls; the GPU cost of the shapes themselves is small.

- Consecutive shape draws keep the program: no switch between them.
- `FillRect`/`FillRRect`/`Polygon` stay in the standard program (vertex colors) when that
  is exact: a solid fill, or a linear gradient with 2 stops that does not clamp inside
  the shape (no pad beyond the stops) and whose stops have either equal alphas or equal
  RGB. Anything else - 3+ stops, repeat/reflect, a ramp, a fade of a colored stop to
  `$00000000` - switches to the shape shader.
- `RoundRect` always uses the shape shader.
- The cost matters only with many elements. Where many shapes alternate with text or
  images (long lists, grids, inventories), draw all backgrounds first and all captions
  after - the switches drop from two per item to two per frame. For a few dozen buttons
  it is not worth the trouble.
- The shape parameters go in one uniform upload per draw (8 `vec4`, 14 with a border).
- `window.stats.shaderChanges` counts real program changes - check it in the debug
  overlay instead of guessing.

## Gradients in UI styles

The default drawer (`Apus.Engine.DefaultStyle`) reads fills from the style keys of the
element box.

### Keys

| Key | Value | Notes |
|---|---|---|
| `fill` | `<fill>` | background; `0` or `none` - no fill |
| `border-color` | `<fill>` | with `border-width` |
| `fill-shade` | `<fill>` | a layer over the fill, under the border; see below |
| `radius` | `<r>` or `<tl> <tr> <br> <bl>` | 2 values: tl+br, tr+bl; 3 values: tl, tr+bl, br (as in CSS) |
| `inner-fill`, `inner-border-color` | `<fill>` | the client-area block |
| `inner-radius` | as `radius` | the outer radii by default |

### `<fill>` syntax

```text
<fill>  := <color> | none
         | linear(<angle>, <stop>, <stop> [, <stop>...] [, repeat | reflect])
         | linear(<angle>, url(<image>))
         | edge(<width>, <stop>, <stop> [, <stop>...])
         | edge(<width>, url(<image>))
<angle> := <deg>deg | <deg> | to top | to right | to bottom | to left
<stop>  := <color> [<pos>]        -- <pos>: 40% or 0.4
<color> := $AARRGGBB | #RRGGBB | #AARRGGBB | #RGB | #ARGB | 0
```

```text
fill: linear(180deg, #6F7F98, #435166); border-color: #C8D4E8; border-width: 1; radius: 6
fill: linear(to right, #000, #F00, #0F0 75%, #FFF)
border-color: edge(4, #5A6270, #C8D0DC 40%, #3A4250); border-width: 4
radius: 6 6 0 0                                   // a tab
fill: linear(0deg, url(file:ui/ramp_gold.png))    // a ramp image, same sources as background-image
```

- Stops without a position are spread as in CSS: the first at 0, the last at 1, the
  missing inner ones evenly between their known neighbours; a position never goes back.
- More than 4 stops is an error (not a silent cut).
- `edge()` width is in logical units: the drawer multiplies it by the element scale.
- Tokens work as for colors, both for the whole value and inside its parts:

  ```text
  &shade-raised = linear(180deg, #30FFFFFF, #00FFFFFF 50%, #30000000)
  fill: &btn-color; fill-shade: &shade-raised         // the look from the theme, the color separately
  fill: linear(180deg, &accent, &accent-dark 80%)
  border-color: edge(3, &stop-light, &border-dark)    // a token may hold '<color> <pos>'
  ```

- An invalid value is reported to the log once, and the key's default is used.
- Parsed values are cached by their text; the cache is reset when a token or the theme
  changes (`stylesRevision`). Reading a gradient key costs about as much as reading a color.
- `url(...)` images are resolved by `StyleImageResolver`, which `DefaultStyle` installs:
  `file:` and `tex:` sources as in `background-image`. Ramp textures are kept until the
  program ends (they are small and shared). Without the resolver `url()` values are invalid.

Code access, next to the color getters:

```pascal
f:=element.GetStyleFill('fill',TFill.None);                  // with the active states
f:=element.GetBaseStyleFill('fill',TFill.Solid(defColor));   // without state overrides
f:=element.GetStateStyleFill('hover','fill',f);              // declared for one state
f:=ResolveBlockFill(block,'fill',TFill.None);                // a TStyleBlock without an element
if ParseStyleFill(text,f) then ...                           // Apus.Engine.Style
if ParseStyleRadii(text,radii) then ...
```

`edge()` widths come back in logical units: scale `p0.x` by the element scale before
drawing (the default drawer does it).

### `fill-shade`

A neutral, usually semi-transparent layer over the fill: the "look" (raised, flat,
pressed) separately from the color. A theme defines the look once as a token, and the
button color changes only through `fill` or a semantic color.

- Procedural buttons (`TUIButton`, `TUIToolButton`, toggle buttons except checkbox/radio)
  have a default shade: `linear(180deg, $30FFFFFF, $30000000)` - the classic light top and
  dark bottom. `fill-shade: none` removes it. A skinned button (`background-image`) has
  no default shade.
- Over a solid fill the shade is merged into one gradient (exact, no visual difference),
  so the default button is still one vertex-colored `FillRect` without a program switch.
- Over a gradient fill, or with state layers, the shade is a separate draw.

### Transitions

`hover`, `pressed` and `disabled` blend toward the state values over the transition
time, as colors did:

- Two fills interpolate when they have the same kind, units, spread, stop count and
  ramp: colors (premultiplied), stop positions and the line or angle blend, so
  `linear(90deg,...)` -> `linear(180deg,...)` turns smoothly. A solid color blends with any
  gradient without a ramp (it is treated as a gradient of one color); `none` blends as
  transparent.
- Fills that can't be interpolated (linear -> edge, 2 stops -> 3 stops, different spread)
  cross-fade: the state fill is drawn over the current one with the transition weight.
  For opaque fills the result is exactly the blend. During such a transition the box takes
  several draws instead of one.
- Ramp fills can't fade: in a cross-fade they switch at the middle of the transition.
- The derived state colors of procedural buttons (lighter on hover, darker when pressed,
  grayed when disabled) apply to every stop of a gradient.

### Which widgets use it

Fills apply to the common box path of the default drawer: element boxes, buttons, panels,
menus and popups, list boxes, the client-area block, and toasts (`Notifications`). Some
widgets still draw parts of themselves with colors or fixed code and ignore gradients
there:

- the window title bar and frame (`DrawUIWindow`): fixed colors derived from `fill`; with a
  gradient `fill` they fall back to the default gray;
- `TUIFrame` (`border-color` as a color), the checkbox outline, scrollbar parts (`color`,
  `track-color`), the combo box and the hint background (fixed gradients).

## Limitations

- Linear and edge gradients only; no radial or conic ones (not planned), no text
  gradients, no blurred shadows (`box-shadow` stays a geometric falloff).
- Up to 4 stops; use a ramp texture for more.
- Antialiased shapes: `RoundRect` only (per-corner radii, pill shapes). No ellipse yet.
  `FillRRect` and `Polygon` with a gradient have geometry edges without antialiasing.
- Edge gradients need `RoundRect`; other primitives draw them as the inner color.
- Ramp fills are not faded by `Faded` (and so not by style cross-fades and toast fades).
- A translucent border replaces the fill under it in a single `RoundRect`, but lies over
  the fill when the box is drawn in layers (cross-fade transitions, a shade over a
  gradient): during such a transition a translucent border looks slightly different.
- Each shape is its own draw call; the engine does not batch shapes yet.
- Verified on desktop GL (Windows, NVIDIA). The GLES variant of the shape shader is
  compiled by CI but not yet tested on a device.

## See also

- `demo/Draw2D` - gradients, per-corner radii and an edge-gradient frame (`-screen=2`, `-screen=3`).
- `tests/TestFill.dpr` (CPU), `tests/TestFillShapes.dpr`, `tests/TestStyleFill.dpr` (GL) -
  executable examples of every case above.
- `tests/BenchUIShapes.dpr` - the bench behind the performance notes.
