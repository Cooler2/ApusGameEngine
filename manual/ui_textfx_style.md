# Optional TextFX captions

Apus.Engine.TextFXStyle adds effect captions without changing the standard button
background, skin, focus ring or state transitions. Use it for game UI; ordinary
application controls can keep the default drawer. The module is opt-in.

## Button wrapper

```pascal
uses Apus.Engine.TextFXStyle;

button.style.Assign('color:#FFFFFF; text-glow-color:#000000; text-glow-blur:3;');
button.drawer:=@DrawTextFXStyle;
```

The wrapper calls DrawDefaultUI(button,false) before drawing the caption. It supports
ordinary TUIButton and TUIToggleButton, excluding TUICheckBox and TUIRadioButton.
Other specialized button subclasses need their own renderer.

## Caption child

```pascal
button.style.Assign('caption-display:none; color:#FFFFFF;');
captionImage:=TUIImage.Create(130,32,button);
captionImage.SetPos(34,0,pivotTopLeft);
captionImage.style.Assign(
  'caption-source:parent; text-glow-color:#000000; text-glow-blur:3;');
captionImage.drawer:=@DrawTextFXStyle;
```

The parent retains its caption for application code and UI inspection. Its ordinary
drawer skips the caption when caption-display:none is set. A TUIImage is mouse
transparent by default, so the button still receives hover and clicks. TUILabel
and plain TUIElement are also supported as caption views; set shape:=shapeEmpty when placing them inside a button. Caption views draw text only: fill, border and background-image are not drawn,
and a TUIImage src is ignored by this drawer. Each view clips text/effects to its
client rectangle; leave enough space inside the view for the glow. An image child can alternatively
use SetRenderProc with a caller-provided DrawTextFX procedure.

With caption-source:parent, text color, alignment, offsets and animated state follow
the parent. An unrelated parent drawer's private style context is preserved; its text state is read as an instantaneous
snapshot. The child may override font, font-size and effect parameters, and retains
its own geometry and scale. Without this key the view uses its own caption/style.
A standalone TUILabel uses its align field as the default for text-align and keeps
verticalOffset. Effect captions use left/center/right alignment; a justified
TUILabel falls back to ordinary text with its target width.

## Content and effect parameters

- content-press-offset: downward displacement of the button caption and all children
  in logical units (default 1). Set 0 to disable it. The default drawer sets scroll
  absolutely every frame from pressed/toggled progress; it resets to zero on release.
  Checkboxes and radio buttons are excluded. Explicit text-offset-x/y add an extra
  caption-only adjustment; they are independent of the group displacement.
- caption-display:none: skip the button's own caption, including a TextFX wrapper.
- text-glow-color: effect color (default black). Its alpha controls effect intensity.
- text-glow-blur and text-glow-spread: logical units, scaled to screen pixels and
  clamped to TextEffects limits. Both default to 0; with no effect, ordinary text is
  drawn using the shared default-style text path.

Call FlushTextFXCache on the render thread after a font option/reload or dictionary
change. The text key is the input string, so a dictionary switch otherwise leaves
the old translated shape cached.

An active glow replaces the separate default text shadow. TextFXStyle currently
provides a single glow layer; custom render procedures can use all TextEffects layers.
RegisterTextFXStyle(id) optionally makes the drawer available to numeric UI scripts
(the caller reserves an unused ID in 1..50); direct assignment needs no registration.

## Cache and opacity

DrawTextFXLayers draws cached effect layers without the glyph foreground. For opaque
text, TextFXStyle draws these layers followed by the current glyph color, so hover
color changes reuse the same effect texture. Layer-only and composite cache entries
are distinct; the cache remains bounded by the existing LRU limits.

For translucent text, TextFXStyle uses the original composite DrawTextFX path so
opacity is applied once to the composed image. A changing RGB color can rebake this
composite during a transition. This preserves blending at partially covered pixels.

## Showcase and validation

Build demo/StyleDemo/StyleDemo.dpr with build.cmd or build.sh. The first two buttons
show a wrapper and an icon plus caption child; the disabled sample uses the wrapper
as well. Inspect them with the Robot API or the physical mouse.

Existing TestStyle, TestTextEffects and TestVirtualMouse provide regression checks
for style parsing, composite/effect-only rendering against a CPU reference, and
virtual input. TestTextFXStyle checks wrapper equivalence, state/scale behavior,
caption suppression, child clipping and context ownership with a GL context. Runtime
screenshots and UI geometry verify the new showcase on this stand; they do not
establish Delphi or GLES acceptance.
