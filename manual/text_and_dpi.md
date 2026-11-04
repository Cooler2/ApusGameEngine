# Text size, DPI, and font lifetime

This guide answers five practical questions: how to load a font, obtain a font
handle, set the scale, draw text, and use a font in UI widgets. Each example says
where its code runs and what must happen when the window's DPI changes.

The examples define supported usage. If an application follows them and gets an
incorrect result, that is an engine defect. A request to change these rules is
an API/design request. Section 7 distinguishes existing bugs from behavior that
is intentionally still being redesigned.

The examples use `Apus.Engine.API` (`txt`, `TFontHandle`, font flags),
`Apus.Engine.GameApp` (application overrides), and `Apus.Engine.UI` /
`Apus.Engine.UIScene` (widgets, UI roots, and scale helpers). Methods named
`TMyApp` and `TMyScene` belong to your subclasses, not to engine units.

## 1. Where and how to load fonts

The engine already provides a font named `Default`. Use it without loading a file:

```pascal
font:=txt.GetFont('Default',9);
```

To provide another font, override `TGameApplication.LoadFonts`. The engine calls
this method once during startup, before `SelectFonts` and `CreateScenes`:

```pascal
procedure TMyApp.LoadFonts;
begin
 inherited;
 txt.LoadFont('Data/Fonts/Inter-Regular.ttf','Body');
 txt.LoadFont('Data/Fonts/Inter-Bold.ttf','Heading');
end;
```

Declare `procedure LoadFonts; override;` in your application class. Supply these
files with your application; the paths above are examples, not files bundled
with the engine. `LoadFont` reads through the engine's file-provider system.
The second argument assigns a name for later `GetFont` calls and UI styles.

Loading a font reads its data and registers it. It does **not** choose the size
of every caption that will use it. `Body` can be used at size 9 in one place and
size 14 in another. Do not load the same file again on every frame or DPI change.

For font data already in memory, use `txt.LoadVectorFont(buffer,name)` for a
vector font or `txt.LoadRasterFont(buffer,name)` for an engine raster font.

`Heading` in this example is already a bold face. Requesting `fsBold` on top
of it adds synthetic bold; use `Body` with `fsBold` only when that is intended.

**Trap:** loading a file in `Render` repeats file access and registration. Load
the data during startup; choose a size separately with `GetFont`.

## 2. Where and how to obtain font handles

`GetFont` returns a `TFontHandle`: a number describing a registered font, its
selected size, and flags. `Write`, `Width`, and `Height` accept that number.
It is not a font object on which the caller should call `Free`.

```pascal
var
 smallFont,largeFont:TFontHandle;
begin
 smallFont:=txt.GetFont('Body',9,fsIgnoreScale);
 largeFont:=txt.GetFont('Body',18,fsIgnoreScale);
 // Same loaded font data; two explicitly requested sizes.
end;
```

There are two useful places to obtain handles.

### Application fonts: override `SelectFonts`

For fonts shared by the screens of a **single-window** application, use the
application's `SelectFonts` method. For example, add a field
`titleFont:TFontHandle` and declare `procedure SelectFonts; override;`:

```pascal
procedure TMyApp.SelectFonts;
begin
 inherited; // also selects the engine's message-dialog fonts
 titleFont:=txt.GetFont('Heading',14);
end;
```

The engine calls this after `LoadFonts`, and calls it again when the window is
reconfigured. Your method must assign fresh handles on each call. Do not load
the font files here, and do not draw text here.

The size of `titleFont` should follow the application's automatic UI scale.
At scale 1 the request is size 14; at scale 2 it is size 28. The engine must
make the same rule work both at startup and after moving the window.

**Current limitation:** `SelectFonts` runs in different threads at startup and
after a resize. The resulting scaling bugs and the planned replacement for
this hook are described in section 7. The hook is usable, but its lifecycle
is not the final design. Do not share one `titleFont` field between windows
that need different font sizes.

### A scene or custom drawer: obtain the handle where it is used

It is also valid to call `GetFont` in the scene's `Render`, before drawing:

```pascal
procedure TMyScene.Render;
var
 font:TFontHandle;
begin
 font:=txt.GetFont('Default',9);
 txt.Write(font,20,40,$FFFFFFFF,'Hello world!');
 inherited; // for a TUIScene: draw its widgets too
end;
```

This example assumes `TMyScene` inherits `TUIScene`. The method runs in the
window's render thread, with `window` identifying that window. `GetFont` selects
a handle from already loaded data; it does not reload a file. Calling it each
frame is supported. Start with this simple form before adding a cache.

**Trap:** putting `GetFont` in `Load` can make the first screen look correct
with today's engine bug, because `Load` runs in another thread. It does not fix
the bug, and `Load` is not called again whenever the DPI changes.

## 3. Where and how to configure scales

### Default application: let the engine configure DPI

For a normal application, do not call `txt.SetScale` from every scene.
The engine's `SetupHighDPI` configures the automatic text factor and the default
scale of UI roots during startup and when DPI changes.

Use one of these two forms, according to who calculates the size:

```pascal
// The engine applies the automatic factor. Do not multiply by DPI here.
font:=txt.GetFont('Body',9);

// The caller has calculated the full size. Do not apply another factor.
font:=txt.GetFont('Body',9*element.globalScale,fsIgnoreScale);
```

Suppose the automatic factor and `element.globalScale` are both 2. Both calls
request size 18. This call is wrong:

```pascal
// Wrong: 9*2 is multiplied by the automatic factor 2 again: size 36.
font:=txt.GetFont('Body',9*element.globalScale);
```

`fsIgnoreScale` means "use the size I supplied without the automatic GetFont
multiplier". A size already multiplied by the UI scale still follows DPI when
this flag is present. The flag does not disable the canvas projection.

### What each scale API actually changes

| API | Where to use it | What it changes |
|---|---|---|
| `windowSetup.scaleForDPI` | `SetupApplication` | Whether the requested initial native window dimensions are enlarged for DPI. It is not a text-size setting |
| `txt.SetScale(s)` | The application's `SetupHighDPI` override, if a custom automatic factor is needed | The multiplier for subsequent `GetFont` calls without `fsIgnoreScale`. It does not change existing handles or UI geometry |
| `SetDefaultUIScale(fullScenes,windowedScenes)` | `SetupHighDPI` | The scale assigned to newly created fullscreen/windowed UI roots. It does not by itself update roots that already exist |
| `ApplyDefaultUIScale(wnd)` | When applying changed UI defaults to an existing window | Calls `UI.SetScale` on that window's existing UI scenes, using those defaults. The engine calls it after the DPI-change hook |
| `panel.SetScale(s)` or `scene.UI.SetScale(s)` | During UI construction, or in a callback running in the owning window | The scale of that UI subtree. Descendant widgets lay out and select style fonts using the changed scale |

`SetDefaultUIScale` is in `Apus.Engine.UI`; `ApplyDefaultUIScale` is in
`Apus.Engine.UIScene`. A fullscreen UI scene here means a scene covering the
window; it does not imply an exclusive fullscreen OS window.

For example, to enlarge only the contents of an existing panel, call this
during UI construction or from that panel's window-thread callback:

```pascal
panel.SetScale(1.25);
```

Its children now use a scale 1.25 times their previous ancestor scale; their
style font sizes need no edits. This does not change unrelated scenes or the
factor used by a plain `txt.GetFont('Body',9)` elsewhere in the application.

### Example: make a single-window application's UI 25% larger

Declare `procedure SetupHighDPI; override;` in your application class:

```pascal
procedure TMyApp.SetupHighDPI;
var
 scale:single;
begin
 inherited;
 scale:=game.screenScale*1.25;
 txt.SetScale(scale);
 SetDefaultUIScale(scale,scale);
end;
```

Here `game.screenScale` is the engine's default DPI factor: for example, 1 at
96 DPI and 2 at 192 DPI. The custom factor becomes 1.25 or 2.5 respectively.
Both direct automatic font requests and newly created UI roots use that factor.
Treat `game.screenScale` as an input; do not assign your preference into it.

This override is reapplied on a DPI change. For a UI-size preference changed
while the application is running, the application must also update existing UI
roots and replace its stored font handles. In a single-window application,
the following is the body of an application method called **in that window's
thread**, after updating the preference used by `SetupHighDPI`:

```pascal
SetupHighDPI;
ApplyDefaultUIScale(window);
SelectFonts;
```

The example override uses a constant 1.25; replace it with your application
setting if you expose such a preference. This is the current single-window
mechanism. There is not yet an implemented application-wide setter that safely
updates independent windows; do not invent an `InitRenderResources` override
or assume the proposed API in Chapter 18 already exists.

**Important current defect:** `txt.SetScale` is stored per thread despite
describing application/window scaling. A call during startup currently does
not reliably establish the render thread's factor. The code above expresses
supported usage; fixing that propagation is the engine's responsibility.

## 4. How to draw text directly

Call drawing methods from `Render`, after selecting a handle. For example,
using a field filled by `SelectFonts`:

```pascal
// Inside your scene's Render; myApp is your TMyApp instance.
txt.Write(myApp.titleFont,20,40,$FFFFFFFF,'Status');
```

The arguments are the handle, x, y, ARGB color, and text. Coordinates belong to
the active canvas. `Write` does not consult `SetScale` again to resize this
stored handle. To measure the same text, pass the same handle:

```pascal
textWidth:=txt.Width(myApp.titleFont,'Status');
capitalHeight:=txt.Height(myApp.titleFont);
```

`Height` returns the height of capital letters. It is not the numeric size
passed to `GetFont`, and it is not a full line height including descenders.
For a vector font, size 9 at factor 1 corresponds to an em box of about 16
canvas units; the visible capitals are smaller. This legacy size convention
is retained for compatibility. Do not pass 16 expecting a 16-pixel em box.

### A saved handle does not change when you change a scale

This explicit example needs no automatic DPI factor:

```pascal
font:=txt.GetFont('Body',9,fsIgnoreScale);
txt.Write(font,20,40,$FFFFFFFF,'Small');

// Assign a new handle to the same variable before drawing larger text.
font:=txt.GetFont('Body',18,fsIgnoreScale);
txt.Write(font,20,80,$FFFFFFFF,'Large');
```

Replacing a handle means assigning the new number returned by `GetFont`.
The registered font data stays loaded. No `LoadFont` or `Free` is needed.

The same assignment is needed after a DPI/UI-size change if you have stored
a size-dependent handle in a field. Calling `SetScale(2)` only affects later
automatic `GetFont` calls; drawing with an earlier saved handle keeps its old
selected size. `SelectFonts` above performs those assignments for application
fonts. A scene's private cached handles need their own update code.

**Canvas trap:** with an 800×600 design canvas displayed at 1600×1200, the
presentation already doubles the whole picture. Keep the caption's design
coordinates and sizes consistent with that canvas; do not additionally multiply
its font by the physical screen DPI. If you explicitly derive physical sizing
for canvas coordinates, use `window.canvasDPI`, not unconditionally
`window.surface.dpi`. Do not add a render-resolution multiplier yourself.

## 5. How to use fonts in UI

### Standard widgets: use their style

During UI construction, set the font name and the unscaled size in the widget's
style. Here `labelElement` is an existing `TUILabel`:

```pascal
labelElement.styleInfo:='font:Body; font-size:9';
```

The name `Body` is the alias registered in `LoadFonts`. The widget selects
the size for its UI scale when it is drawn. Do not store a `GetFont` result
in `font-size`; the style property is a size, not a handle. Do not multiply
the style's `9` by DPI: the UI font resolver already does that.

### Custom drawers: use `StyleFont`

Inside the drawer, with `element` referring to the widget being drawn:

```pascal
font:=element.StyleFont;
txt.Write(font,x,y,$FFFFFFFF,'Caption');
```

Here `x` and `y` are already calculated canvas coordinates for the caption.
`StyleFont` reads `font` and `font-size`, multiplies by `element.globalScale`,
and calls `GetFont` with `fsIgnoreScale`. A label under a UI root of scale 2
therefore uses size 18 for style size 9. On changing that root to scale 1,
the next `StyleFont` call selects size 9.

`element.globalScale` is the product of the **ancestor** scales in the current
API; it excludes the element's own `scale`. For an ordinary child widget this
includes the UI root scale. Do not use `scene.UI.globalScale` as the root's
own scale: a root has no parent, so that value is 1. Use `scene.UI.scale` when
you specifically need the root's own factor.

If a custom drawer deliberately fixes its own font and base size, use:

```pascal
font:=txt.GetFont('Body',7*element.globalScale,fsBold+fsIgnoreScale);
```

This selects a fixed caption rather than following the element's font style.
Use `StyleFont` when the application's styles should control the font.

### If you cache a custom drawer's handle

Usually `StyleFont` each time is enough. For a fixed `Body` font and base size
9, this complete helper shows which value must be checked before reusing a
saved handle. Store its record as a zero-initialized object field; if you use
a local record variable, set `cache.font:=0` before the first call:

```pascal
type
 TCaptionFontCache=record
  font:TFontHandle; // initialize to 0
  scaledSize:single;
 end;

function CaptionFont(element:TUIElement;var cache:TCaptionFontCache):TFontHandle;
var
 size:single;
begin
 size:=9*element.globalScale;
 if (cache.font=0) or (cache.scaledSize<>size) then begin
  cache.font:=txt.GetFont('Body',size,fsIgnoreScale);
  cache.scaledSize:=size;
 end;
 result:=cache.font;
end;
```

Keep the cache with the widget or its owning scene. When `element.globalScale`
changes from 1 to 2, the helper replaces the size-9 handle with a size-18 handle.
An ordinary resize that leaves the scale unchanged reuses the handle.
If your cache also allows changing the font name, base size, or flags, compare
those inputs too. This helper deliberately assumes they are constant.

## 6. Typical mistakes and how to check your code

- **Loading a file every frame.** Move `LoadFont` to `LoadFonts`; retain the
  alias for subsequent `GetFont` calls.
- **Scaling twice.** Replace `GetFont('Body',9*element.globalScale)` with
  `GetFont('Body',9*element.globalScale,fsIgnoreScale)`, or use `StyleFont`.
- **Ignoring scale accidentally.** `GetFont('Body',9,fsIgnoreScale)` stays
  size 9. To follow the widget, supply `9*element.globalScale` instead.
- **Expecting a field to update itself.** After a scale change, assign a new
  handle with `GetFont`; changing `SetScale` or `UI.SetScale` does not rewrite
  a previously saved handle.
- **Expecting `Load` or `InitGfx` to run on each DPI change.** They do not.
  Use `SelectFonts` for application fonts, obtain a handle during drawing,
  or explicitly update the scene's own cache when its inputs change.
- **Changing a scale from the wrong thread.** Draw and apply window-local
  rendering changes in the owning window. An arbitrary worker must not write
  its own thread-local text state expecting the window thread to see it.
- **Sharing one size-dependent field across windows.** Keep separate handles
  when the windows need different sizes. The last window to update a global
  handle must not resize the other window's captions.

Check startup on a high-DPI monitor, resizing without leaving that monitor,
and moving to another DPI and back. Include a standard widget, your directly
drawn caption, and the engine's confirmation dialog. When the original scale
returns, the original text sizes must return too.

## 7. What is stable, what is broken, and what will change

**Stable usage:** load font data once; obtain numeric handles with `GetFont`;
apply a size multiplier once; draw from `Render`; use logical style sizes and
`StyleFont` for UI. A handle describes a selected size and does not automatically
resize. These rules apply to clients and the engine's built-in dialogs alike.

**Known engine bugs at `f5ffbb54`, checked 2026-11-02:** the initial automatic
factor is set in the control thread but not consistently in the render thread;
a resize can then recreate the built-in message fonts with factor 1. Lazy text
state initialization also unconditionally assigns factor 1; that additional
reset is confirmed in source, not isolated by the runtime experiment below.

On a diagnostic subclass of SimpleDemo, Windows x64/FPC/native GL, the measured
capital-letter heights were:

| Action performed in the experiment | Hello world: automatic size 7 | Message text: automatic size 8.5 |
|---|---|---|
| Start on the 192-DPI monitor | 10 | 23 |
| Resize the window while staying at 192 DPI | 10 | 12 |
| Change DPI to 96 and back to 192 | 19 | 23 |

The ordinary `GetFont('Default',7)` in SimpleDemo's `Render` is valid. Its small
initial text is an engine bug. The shrinking message text is also an engine bug:
the engine itself replaces those handles in `SelectFonts`. Moving the window
must not be necessary to repair either caption. The explicit request
`GetFont('Default',7*2,fsIgnoreScale)` stayed at height 19 at 192 DPI.

PaintRaw's old custom drawers had a separate client error: they supplied
`size*element.globalScale` without `fsIgnoreScale`. Its `278b3de` correction
follows section 5. It does not repair the engine-owned confirmation fonts.
Other demos can hide the initial engine bug by choosing their handles in `Load`
and keeping them; this does not prove the render-thread automatic path works.

**Planned lifecycle changes, not implemented API:** `SelectFonts` is intended to
be replaced by a render-resource initialization phase in each window's render
thread. The automatic factor must belong to the appropriate window, while a
user's UI-size preference belongs to the application. Per-window derived font
handles must then be updated when that preference or the window's DPI changes.
The proposed `InitRenderResources` hook and invalidation generation in
[Chapter 18](ch18_application_lifecycle.md#8-settings-changes-and-derived-render-resources)
are not available methods today. The current single-window recipes in sections
2–3 will need a lifecycle update when that API is introduced.

Do not make one process-global DPI multiplier as a workaround: two windows can
be on different-DPI monitors. The current `game.screenScale`, shared UI defaults,
and thread-local `txt.SetScale` do not yet form a complete multi-window scaling
API. This limitation needs an engine change, not repeated client calls guessing
which thread should set a multiplier.

The experiment covered startup, size-only resize, a controlled DPI change,
and a real move between 96/192-DPI monitors. It did not validate Linux/macOS,
fixed-canvas rendering, or multi-window scaling at runtime.

