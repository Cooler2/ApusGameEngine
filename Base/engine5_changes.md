# Engine5 Refactoring — Function Rename Registry

This file tracks all functions extracted from `Apus.Common` into new modules.
Use it as the primary reference when updating old code.

## Non-ANSI paths and command line under FPC on Windows (2026-10-28)

Under FPC on Windows the RTL `string` is ANSI: `ParamStr`, `FindFirst` names, `ExpandFileName`,
`ChangeFileExt` and any `string(String8)` cast lose characters outside the ANSI code page
(a folder named `Ω` or `日本` became `?`, and `FileAge(ParamStr(0))` crashed the logger).

- New `Env` record (`Apus.Core`): `Env.ExeName`, `Env.ParamCount`, `Env.ParamStr(i)`,
  `Env.GetVar(name)` - all `String8`, read through the wide Windows API (on Unix the RTL is
  used as is). `ParamStr(0)` = `ExeName`; an index out of range gives `''`. Use them instead
  of `ParamStr`/`ParamCount`/`GetEnvironmentVariable` wherever the value may be a path.
- `Files`/`Folder` (`Apus.Files`) pass names to the OS losslessly; `ListFiles`/`Find` return
  UTF-8 names, `Find` compares with Unicode case folding.
- New name parts in `Files` (`Apus.Files`), byte operations on `String8`: `GetPath` (with the
  trailing delimiter), `GetDir` (without it, a root keeps it), `GetName`, `GetExt` (`.ext`; a
  leading dot is not one), `ChangeExt`. Use them instead of `ExtractFilePath`/`ExtractFileDir`/
  `ExtractFileName`/`ExtractFileExt`/`ChangeFileExt`: separators are `/` and `\` everywhere
  (plus `:` on Windows) under both compilers, and no ANSI conversion happens.
- `Logger.UseLogFile(const name:String8; ...)` (was `name:string`). The header no longer fails
  on such a path; if the date of the executable can't be read it says so instead.
- `HasParam(const name:String8)`, `GetParam(const name:String8):String8` (`Apus.Utils`, were
  `string`), read through `Env`.
- `TAppSetup.logFile` (`appSetup.logFile` of `TGameApplication`) is `String8` (was `string`).
- `TGameApplication.Prepare`: the previous log is renamed to `.old` even when an old `.old`
  exists (on Windows the rename used to fail and the previous log was lost).
- Game code: don't cast a `String8` path to `string` for an RTL file function under FPC; pass
  it as is (the RawByteString overloads keep UTF-8) or use `Files`/`Folder`.

## UI: `TUIToolButton`, button focus by class attribute (2026-10-26)

- New `TUIToolButton` (`Apus.Engine.UIWidgets`, alias in `Apus.Engine.UI`): a `TUIButton`
  that never takes the focus, for toolbars and menu owners. A click leaves the keys where they
  were: an edit box keeps typing, closing a menu returns the focus there.
- `TUIButton` keeps taking the focus on click, but now reads the default from the class
  attribute, like other elements: `TMyButton.SetDefault('canHaveFocus',false)` changes it for a
  class and its descendants (`TUIButton.SetDefault(...)` for all buttons of an app).
- Delphi only: `TVarHash` (class attributes, `SetDefault`) silently dropped `false`, `0` and
  `''`, since Delphi compares them as equal to `Unassigned`. Such defaults now take effect, e.g.
  `TUIComboBox` no longer handles the mouse while disabled (as under FPC).

## Styles: `box-shadow`, compound values with tokens (2026-10-26)

- New box key `box-shadow: <color> [dx dy [blur]]` or `none` (logical units), drawn by the
  common box path under the element. The popup menu uses `box-shadow:&shadow 2 3 4`.
- New palette token `shadow` in both built-in themes.
- A value that starts with a token and has more parts (`&shadow 2 3`) used to be taken as
  one unknown token name and resolved to ''. Now it passes as is and the drawer expands the
  parts: `ExpandToken` is exported from `Apus.Engine.Style`; `text-shadow` accepts a token
  as its color too.

## Keyboard: a focused element stops only the keys it consumes (2026-10-26)

- `TUIScene.DispatchKey`: a key press or release the focused element does not consume goes on
  to the UI hotkeys and then to the scene (`RegisterHotKey`, `onKeyDown`/`onKeyUp`). It used to
  stop at any focus: one click on a focusable button silenced all scene hotkeys.
- `TUIElement.onKey` returns false exactly for the keys the element handled. `TUIEditBox`
  consumes the keys that type text (alone, with Shift or AltGr), the editing and caret keys and
  Ctrl+C/X/V/A/Z; Enter (unless it accepts a completion), Esc, F-keys and other shortcuts go
  on. `TUIButton` consumes Enter/Space, `TUIComboBox` its navigation keys.
- Game code: a custom text field must consume its keys in `onKey`, otherwise typing reaches
  the scene; `onKeyUp` may get a release without a press seen by the scene.
- New `TKey.IsText` (`Apus.Engine.Keys`): the key types a character alone or with Shift.

## Deprecated wrappers removed (2026-10-23)

- `Apus.Engine.UI`: `FindControl`, `FindControlAt`, `FindAnyControlAt` are gone;
  use `FindElement`, `FindElementAt`, `FindAnyElementAt`.
- `Apus.Geom2D`: `IdentMatrix2`, `IdentMatrix32` are gone; use `IdentMat2d`,
  `IdentMat32d`.
- `Apus.Engine.API`: `TGraphicsAPI.gaOpenGL` (fixed-function GL) is gone; the
  enum is `(gaAuto, gaOpenGL2)`.
- `Apus.Images`: the `ConvertLine(sour,dest,sf,df,palette,palFormat,count)`
  overload is gone; use `ConvertLine(sour,dest,sf,df,count,@palette,palFormat)`
  (palette and format may be omitted when there is no palette).
- `Apus.HashMaps`: `TSimpleHashAS` and `TSimpleHash8` are gone; use
  `THashMap<int64>`. The other legacy hashes (`TStrHash`, `TSimpleHashS`,
  `TVarHash`) stay for now.

## Image preload queue: workers on `Thread.Start` (2026-10-23)

- `Apus.Engine.ImgLoadQueue` launches its loading and unpacking workers through
  `Apus.Threads.Thread.Start` and tracks them as `IThread`; the `Classes.TThread`
  subclasses are gone. The public API (`StartLoadingThreads`, `QueueFileLoad`,
  `GetImageFromQueue`) is unchanged.
- The loading worker now checks for termination while waiting for an empty queue,
  so shutdown no longer hangs when threads were started but nothing was queued.

## NPOT textures: mip-maps without POT padding (2026-10-20)

- `liffMipMaps` no longer implies `aiPow2`: an image loaded with mip-maps keeps its own size
  (NPOT mip chains are baseline in GL 3.3 / GLES 3.0), `u2`/`v2` are 1. Padding happens only
  with an explicit `liffPow2`/`aiPow2`.
- POT-padded textures (`aiPow2` with an NPOT image) drew garbage (horizontal stripes): the CPU
  copy of a level is packed by the image width, the upload read it with the storage width.
  Reading such a texture back (`Lock` after `Upload`/`UploadPart`/`ClearPart`) failed or
  overran the buffer. Both fixed.
- `mipmaps` of an auto-mip-mapped texture is floor(log2) of the larger side (the last level of
  an NPOT chain), still capped by `MAX_LEVEL`; a full `Lock` of a level of an odd size covers
  exactly that level.

## Robot API: virtual keyboard, `mouse.mode` -> `input.mode` (2026-10-20)

- Robot API commands renamed: `mouse.mode`/`mouse.reset`/`mouse.state`/`mouse.wait` ->
  `input.mode`/`input.reset`/`input.state`/`input.wait`. The virtual mode covers the mouse and
  the keyboard together; `mouse.move/down/up/click/wheel` keep their names.
- New commands `key.down`, `key.up`, `key.tap` (`MODS`, `HOLD` in ms), `key.type` (text as
  `KBD\UNICHAR`). Keys by `KEY` (`TKey` name) or `SCAN` (`Scan.XXX`); the answers gain `keys`
  and `focus`/`focusClass`. In the virtual mode the physical keyboard is ignored too. See
  `robot_api_protocol.md`, "Virtual input".
- `Apus.Engine.Window`: `TVirtualMouse*` -> `TVirtualInput*` (`vmo*` -> `vio*`, `vmt*` ->
  `vit*`), `window.virtualMouse` -> `window.virtualInput`, `FindVirtualMouse` ->
  `FindVirtualInput`, `FrameMouseInput` -> `FrameInput`.
- New `TKey.FromName(name)` (`Apus.Engine.Keys`): `TKey.Name` or an identifier alias (`D1`,
  `Semicolon`...), case-insensitive.
- `window.shiftState` is updated by `TWindow.UpdateShiftState` once per frame for every
  window (extra windows used to keep it at 0); in the virtual mode it comes from the virtual
  keys held.

## Keyboard: scancodes are USB HID usage ids on every platform (2026-10-20)

- The scancode of `KBD\KEYDOWN`/`KBD\KEYUP`/`KBD\CHAR`/`KBD\UNICHAR`, of
  `TGameScene.onKeyDown`/`onKeyUp`/`DispatchKey` and of `IsKeyDown`/`IsKeyPressed`/
  `IsKeyReleased` is the USB HID usage id (= `SDL_Scancode`), the position of the key, the
  same on every platform and layout. It used to be the platform's own code: Windows scan
  set 1 (extended keys `or $80`) or, under SDL, a mix of SDL codes and a few set 1 values.
  - New namespace `Scan` (record with constants, `Apus.Engine.Keys`, re-exported by
    `Apus.Engine.API`): `Scan.A`, `Scan.D1`, `Scan.Up`, `Scan.LShift`, `Scan.Num5`... named
    after the US layout; `Scan.Count` (512) - every scancode is below. `Scan.ToKey(code)` /
    `Scan.FromKey(key)` - `TKey` at a position on the US layout and back; `Scan.Name(code)`.
  - Numeric scancodes in game code must be replaced: `IsKeyPressed(2)` (set 1 key `1`) ->
    `IsKeyPressed(Scan.D1)`, `$C8` (Up) -> `Scan.Up`, `$1C` (Enter) -> `Scan.Enter`.
  - `window.keyState` is `array[0..Scan.Count-1]`, the bits changed: bit 0 - down now, bit 1
    - went down in the frame, bit 2 - went up in the frame. Change it only through
    `TWindow.KeyTransition`. `IsKeyPressed`/`IsKeyReleased` now see a press shorter than a
    frame (both true); an auto-repeat is not a new press. A scancode out of range gives false.
  - A release of a key that is not down is dropped (`TGame.KeyPressed`): the receivers get
    down/up pairs.
  - New `TWindow.PlatformReleaseKeys`: on focus loss (Windows `WM_ACTIVATE`, SDL focus
    lost/hidden/minimized) every held key gets `KBD\KEYUP` - a held key no longer sticks.
  - Scene key buffer packing (`WriteKey`): `keyCode|scancode<<8|pressed<<24`.
  - `GetKeyEventScanCode(tag)` reads the scancode where the platforms put it (`tag shr 16`).
- `TKey`: new `Pause`, `LWin`, `RWin`, `Menu`, `LShift`, `RShift`, `LCtrl`, `RCtrl`, `LAlt`,
  `RAlt` (Windows already sent these codes). `TKey.FromSDL` removed. Under SDL the `TKey` of
  a key event comes from its position except letters and digits (which follow the layout,
  as Windows VK codes do): punctuation, keypad and modifiers no longer get wrong codes
  (`'` used to arrive as `Right`, `Num1` as `Y`).
- `ISystemPlatform.MapScanCodeToVirtualKey` removed (unused).

## TWindow: unused members removed, frame diagnostics and capture moved to records (2026-10-17)

- Removed (nothing read them): `TWindow.textLink`, `textLinkRect` (the current text link is
  `txt.Link`/`txt.LinkRect` in `Apus.Engine.TextDraw`), `frameStartSec`, `frameDeltaSec`
  (use `frameStartUs`/`frameDeltaUs` or the `*Ms` ones), `paused`, `mouseMovedTime`.
- Private now: `dRT`, `dRTdepth` (the depth texture is `window.GetDepthBufferTex`),
  `runtimeLock` (use `LockState`/`UnlockState`).
- `window.FPS`/`smoothFPS` -> `window.timings.fps`/`smoothFps`.
- Frame log: `window.FLog(st)` -> `window.frameLog.Add(st)` (`game.FLog` stays);
  `window.frameLog`/`prevFrameLog` (strings) -> `window.frameLog.current`/`previous`.
- Frame capture moved into `TFrameCapture` (`window.capture`): `window.RequestScreenshot` ->
  `capture.RequestScreenshot`, `window.RequestFrameCapture` -> `capture.RequestFrame`,
  `window.CaptureFrame` -> `capture.Capture(window)`. They don't take the window lock: use
  `game.RequestScreenshot`/`RequestFrameCapture`, which do. `TGame.CaptureFrame` removed.
- Mouse helpers: `MouseInRect`, `MouseIsNear`, `MouseWasInRect` removed from `TWindow`,
  `TGameBase` and `TGame`. New namespace `Mouse` (record with class functions, declared in
  `Apus.Engine.Window`, re-exported by `Apus.Engine.API`) reads the pointer of the current
  thread's window: `Mouse.Pos` (`TVec2`), `X`, `Y`, `InRect(TRect/TRect2)`,
  `InCircle(x,y,radius)`, `Down(buttons=mbLeft)` (any of the buttons is held), `OverUI`,
  `Simulated` (the virtual mouse is in control). Position queries are false while the pointer
  is outside the canvas.
  - `MouseInRect(x,y,width,height)` has no replacement overload: it was easy to call with
    corners. Use `Mouse.InRect(Rect2(x,y,x+width,y+height))`.
  - `MouseIsNear` -> `Mouse.InCircle`.
  - `MouseWasInRect` -> `Mouse.WasInRect` (see the input frame below; the old one matched the
    current position outside `onMouseMove`).
- `mbLeft`/`mbRight`/`mbMiddle` are declared in `Apus.Engine.Types` (still available from
  `Apus.Engine.API`).
- Input frame: the input is published once per pass of `TWindow.OnFrame`, at its start (all
  paths: the main loop, `WM_PAINT`, extra windows). New frame queries `Mouse.WasPressed`,
  `WasReleased` (any of the buttons went down/up since the previous frame; a click shorter
  than a frame gives both) and `WasInRect(TRect/TRect2)` (the pointer at the previous frame);
  new `Mouse.Outside` (the pointer is not over the canvas, also while a drag clamps it to the
  edge; position queries are false then).
  - `mouseButtons` follows the button events at once (physical, virtual, touch); it used to
    come from a poll before the message pump - a frame late, and a click between two polls
    never reached it. The poll is gone (`TWindow.SetPolledMouseButtons` removed).
  - `window.oldMouseButtons` removed: it changed only on a button change, so the usual
    `mouseButtons and not oldMouseButtons` was true in every frame the button was held.
    Use `Mouse.WasPressed`/`WasReleased`.
  - `TWindow.MapPointerToCanvas` removed: platforms report the pointer with
    `SetPointer(clientPos)` / `SetPointerOutside` (same mapping and clamping).
  - `PlatformMouseButton(btn,pressed,sample=true)`: touch passes `sample=false`. Touch no
    longer sends `Mouse\BtnDown\Left` / `Mouse\BtnUp\Left`: it sends `MOUSE\BTNDOWN` /
    `MOUSE\BTNUP` with tag 1, like the mouse.
  - The keyboard frame (`IsKeyPressed`/`IsKeyReleased`) moved to the same boundary and now
    works in every window (it was shifted by the main loop for the main window only).
  - A nested `OnFrame` (a modal message pump inside a handler) is refused.
  - `ISystemPlatform.GetMouseButtons` removed (nothing polls the buttons now).
  - New `TWindow.PlatformCancelGesture`: the platform lost the pointer - a physical gesture
    ends without a click, the buttons are released. Windows calls it on deactivation,
    `WM_CANCELMODE` and a capture taken by another window, and releases its capture only
    after the last button release is delivered; SDL calls it on focus loss, hide, minimize.

- Scene notifications: `TWindow.NotifyScenesMouseMove` (nothing called it),
  `NotifyScenesMouseBtn`, `NotifyScenesMouseWheel` (one-line forwards to the UI dispatcher)
  removed; `NotifyScenesResize` is private. `TGameScene.ModeChanged` and
  `TWindow.NotifyScenesModeChanged` removed: nothing overrode the hook, and a display mode
  change already reaches the scenes as `onResize` (and `ENGINE\SURFACECHANGED`).
- `TGameBase` proxies to the current window removed: `game.ClientToCanvas`/`CanvasToClient`/
  `GetDepthBufferTex`/`Minimize` -> the same methods of `window`; `game.CanvasSize` ->
  `window.surface.canvasSize`. Scene methods (`AddScene`, `GetScene`, `TopmostVisibleScene`...)
  stay: they work on the main window.

## Texture units: fixed layout, MakeOnline only uploads (2026-10-17)

- `IResourceManager.MakeOnline(img,stage)` -> `MakeOnline(img)`: uploads pending data and
  binds nothing. Binding for drawing is `IShader.UseTexture(tex,stage)`.
- `IShader.UseTexture` takes stages 0..15. Units 16..30 belong to the engine (shadow map 16,
  normal map 20), unit 31 is the scratch unit for uploads and readback (`Apus.Engine.ResManGL`
  constants `TEX_*`). The normal map moved from unit 3, the shadow map from unit 9.
- New `TGLContextRequest.baseline` / command line `-GLBASELINE`: no GL features above
  3.3 / ES 3.0 (`TGLFeatures` in `Apus.Engine.ResManGL`: DSA, clear texture), to check the
  baseline paths on a newer GPU. The `EXT_direct_state_access` path is gone.

## Resource manager: Clone and Copy removed (2026-10-17)

`IResourceManager.Clone(img)` -> `img.Clone` (`TTexture` method; `ClonePart` for a part).
The manager clone shared the GL texture name, so freeing it deleted the parent's texture.
`IResourceManager.Copy` was a stub that always raised; removed with no replacement.

## Window name is an identifier, not the title (2026-10-09)

`TWindow.name` was the window title (any Unicode text; two extra windows with the same title
failed with "Duplicate object name"). Now it is an ASCII identifier (letters, digits, `_`,
`-`, `.`; checked by ASSERT), the title stays a separate caption:

- `ISystemPlatform.CreateWindow(title)` -> `CreateWindow(name,title)`
- `game.AddWindow(settings)` / `AddWindow(title,w,h)` take an optional last `name`; empty -
  `Window1`, `Window2`...
- the main window is named `Main` (was its title); platform window constructors have no
  `'MainWnd'` default
- Robot API `WINDOW` parameter of `mouse.*` addresses windows by this name

## Clipboard moved from Base to the engine (2026-10-09)

`Base/Apus.Clipboard` is replaced by `Apus.Engine.Clipboard`: the clipboard is a platform
service (on Linux/Wayland it needs the window connection), and all callers are engine modules.
The functions became the `Clipboard` record namespace:

- `CopyStrToClipboard(UTF8String|WideString)` -> `Clipboard.SetText(String8)` (written as
  `CF_UNICODETEXT`; the old UTF-8 overload wrote the bytes as ANSI `CF_TEXT`)
- `PasteStrFromClipboard`, `PasteStrFromClipboardW` -> `Clipboard.GetText:String8`
  (no 1250-character limit of the old fixed buffer)
- `PutImageToClipboard(TObject)` -> `Clipboard.SetImage(TRawImage)`
- new: `Clipboard.HasText`, `Clipboard.HasImage`, `Clipboard.GetImage:TBitmapImage`
  (PNG, then 24/32 bpp `CF_DIB`; caller frees)

Windows uses WinAPI with either platform layer. Other platforms: text via SDL, no images.

## Image loading: WebP and PNG fallback (2026-09-26)

- TImageFileType now includes ifWebP. CheckImageFormat recognizes static
  RIFF/WEBP VP8, VP8L, and VP8X headers and reports dimensions and ARGB output.
  Animated WebP is rejected.
- LoadWebP(data,image) decodes a static WebP to a new or caller-provided image.
  Define WEBP to link libwebpdecoder; without it the API raises NotImplemented.
  The engine file loader and preloader accept .webp. Save/encode is not added.
  An opt-in build must ship the decoder under the binding name:
  libwebpdecoder.dll on Windows, libapuswebpdecoder.so on Linux/Android, or
  libwebpdecoder.dylib on macOS. Windows x64 and Linux x64 binaries are built
  from pinned libwebp source and bundled in bin64/ and redist/linux/.
  Android arm64-v8a is bundled in redist/android/; macOS and iOS are deferred.
  Extensionless file probing includes .webp only in WEBP builds.
- The shared FPC image reader now respects the target pixel format and row pitch,
  including Mono8 and A8 targets, for PNG and JPEG. Previously it wrote four
  bytes per pixel even into one-byte grayscale PNG targets.
- PNG decoder measurements, limits, and the compile-time selection decision are
  documented in [PNG_DECODERS.md](PNG_DECODERS.md). LODEPNG behavior is unchanged.

## Text effects: `TTextEffectLayer` moved and redesigned (2026-09-26)

`TTextEffectLayer` moved from `Apus.Engine.API` to the new module `Apus.Engine.TextEffects`
(R-33): add it to `uses`. Layers are passed explicitly to `DrawTextFX`; there is no
`textEffects[]` state in the text drawer (Engine 2 `WriteEx` has no direct counterpart).

The fields changed, there is no mechanical mapping - re-tune the values by eye:

| Engine 2 field | Engine 5 |
|---|---|
| `enabled` | removed: pass only the layers you want |
| `blur` (soft 3x3), `fastblurX/Y` (box), `power` | `blur` (gaussian, visible radius) + `spread` (round dilation) |
| `emboss`, `embossX/Y` | removed |
| `color`, `dx`, `dy` | unchanged |

Typical layers: `TTextEffectLayer.Glow(color,blur,spread)`, `.Outline(color,width)`,
`.Shadow(color,dx,dy,blur)`.

## Image loading: shared textures, source keys (2026-09-16)

Loading the same image file twice used to create a second texture and, since the name
registry became strict, failed with `Duplicate object name`. The loader now shares:

- `LoadImage`/`LoadImageFromFile` look the file up in the source registry first. A hit on
  an immutable texture with the same storage settings returns the **same object** and
  increments its reference counter; `FreeImage` releases one holder. A mutable or
  differently configured texture is not shared: a private copy is loaded and a warning
  logged.
- Loaded textures are **immutable by default** (`MakeImmutable`); pass `liffAllowChange`
  to get a mutable private copy. Writing to a loaded texture without the flag raises, as
  it already did through `tfNoWrite`.
- `TTexture.AddRef` takes one more strong reference to an existing texture (returns
  `self`, nil-safe); release it with `FreeImage`. `TTexture.FindByName` stays a weak
  lookup: the creator keeps a named texture alive. Do not recreate a named texture while
  strong references to the previous one exist (unique names).
- `TTexture.SourceKey(ref)` is the canonical key of a file reference: separators fixed,
  `defaultImagesDir`/exe dir stripped, extension and case kept; lookup is
  case-insensitive. A loaded texture is indexed under its file key (`src`, with the
  extension of the file actually read) and its image key (without extension).
  `TTexture.FindByFile(ref)`: a reference with extension finds that file, one without
  finds the image loaded from any of its files. `foo.tga` and `foo.dds` are different
  textures.
- `defaultImagesDir` moved from `Apus.Engine.ImageTools` to `Apus.Engine.Resources`.
- File textures are named `_<file key>` (non-unique label). Code that looked them up by name
  must use `FindByFile` or give the texture a name explicitly.
- `CropImage(image,x1,y1,x2,y2)` is now a **function** returning a `ClonePart` view; the
  source handle is not modified. Free the result like any texture.
- Clones (`Clone`/`ClonePart`, atlas parts) get `_`-prefixed non-unique names.

Design and rules: `manual/ch21_resource_system.md`.

## Immutable resource flags renamed (2026-09-16)

`tfReadOnly`, `abReadOnly` and `bfReadOnly` were easy to confuse with `tfNoWrite`, which
only forbids CPU writes through `Lock` (render targets carry it while the GPU keeps
changing them). The flags set by `MakeImmutable` mean "content is frozen" and are now
named after the method:

| old | new | where |
|---|---|---|
| `tfReadOnly` | `tfImmutable` | texture caps (`Apus.Engine.Resources`) |
| `abReadOnly` | `abImmutable` | buffer allocation flags (`Apus.Engine.Resources`, re-exported by `Apus.Engine.API`) |
| `bfReadOnly` | `bfImmutable` | buffer caps (`Apus.Engine.Resources`) |

`tfNoWrite` is unchanged. Design context: `manual/ch21_resource_system.md`.

## UI text styling + state blocks inside named styles (2026-09-05)

**Content keys.** Drawers resolve the text part of a widget through one helper
(`ResolveTextStyle` in `Apus.Engine.DefaultStyle`), so these keys now work on labels,
buttons, checkboxes, containers, windows and combo boxes:

| key | meaning |
|---|---|
| `text-align` | `left`/`center`/`right`/`justify`; overrides `TUILabel.align` |
| `text-shadow` | `<color> [dx dy]` or `none`; dx,dy in logical units (1 1 by default) |
| `text-decoration` | `underline` or `none` |
| `text-offset-x/y` | caption shift in logical units, blended per state |

- The button's hardcoded 1px caption nudge while pressed became the default of
  `:pressed { text-offset-y }` — a style can change or remove it. Being a logical
  unit, it is now 2 real pixels at scale 2 (it used to stay 1 pixel).
- `color` (content color), text offsets and the caption color blend through the state
  tweenings; align, decoration and shadow switch instantly.
- `ParseStyleNumber` is exported from `Apus.Engine.Style` (compound values like
  `text-shadow` are parsed by the drawer).

**State blocks inside named styles now apply (defect fix).** A `:hover { ... }` block
written inside `Styles['name']` was silently ignored: state lookups only ever saw the
element's own block, and never expanded `&tokens`. Both are fixed, so
`Styles['button']:='fill:&control; :hover { fill:&accent; }'` works as written.

- New cascade order (states beat plain values at every level):
  local `:state` > `@ref` `:state` > local plain > `@ref` plain.
  A named style therefore keeps its hover/pressed behaviour even for an element that
  overrides the same key without a state; to keep local colors in every state, declare
  local `:state` blocks (they win).
- New API: `ResolveBlockStateAttr/Color/Number` (Style) and
  `TUIElement.GetStateStyleValue/Color/Number` — use these instead of
  `element.style.GetStateColor/GetStateNumber`, which see neither refs nor tokens.
- `TStyleBlock.GetStatesValue(states,key)` evaluates a comma-separated state list.
- Visible effect: widgets whose `@ref` declares states (StyleDemo's `@demo-button`,
  any theme-provided style) start animating between state colors.

## UI skins through the box path (2026-09-05)

A widget box can now be a texture: `background-image: tex:<name>` / `file:<name>`,
with `background-tint`, `background-size: auto|stretch` and `background-offset-x/y`.
The common box path (`DrawCommonStyle` in `Apus.Engine.DefaultStyle`) reads them for
every element and cross-fades per state (`:hover { background-image: ... }`), so a
4-state bitmap button or a skinned window needs no custom drawer. `auto` = native size
in logical units (scaled by `globalScale`, like `font-size`), centered in the box.

- Buttons (plain and toggle) went back onto the common box path: `fill` and its
  hover/pressed/disabled blends are drawn there, the button drawer adds only the bevel,
  focus ring and caption. A skinned button gets no bevel/focus ring.
- All box keys blend for `pressed` and `disabled` too (previously only `hover`).
- `focused` is now a synced state (`:focused { ... }` works for any element).
- Window: `background-image` turns a window into a skinned one — the drawer paints
  only the image (no fill/header/frame/caption); hit-testing uses `dragRegion`
  (nil = whole window is the drag area). `TUIWindow.IsSkinned` tells.
- Removed: `TUIWindow.background:pointer` (the skin is a style value now) and
  `SetupWindow(wnd,TTiledImage)` (nothing ever drew it).
- `SetupSkinnedWindow(wnd,img)` now sets `background-image: tex:<img.name>` (naming the
  texture `skin:<wnd.name>` if it has no name) and the window size; the old implicit
  `$FF808080` tint is the default anyway. Add state variants through `wnd.style`.
- `Apus.Engine.CustomStyle` no longer draws windows (they render through the box path).
- New helper in DefaultStyle: `ResolveStyleImage(src)` — shared by `TUIImage.src` and the
  box path; textures are memoized per element in the drawer context.

## UI style keys: canonical vocabulary + selective inheritance (2026-09-02)

Style attribute names are now canonical (kebab-case, CSS names where CSS has the
concept); the full list lives in the header of `Apus.Engine.Style.pas`. Drawers read
only canonical keys — the old spellings are silently ignored (no aliases).

- `color` is the **content (text/glyph) color everywhere** and inherits down the
  element tree. It is never a box color.
- Box chrome keys (`fill`, `border-*`, `radius`, `inner-*`) never inherit. Only
  `font`, `font-size`, `color`, `text-align`, `text-shadow`, `text-decoration` cascade
  from parents (`IsInheritedStyleKey`); previously every key cascaded.
- Style keys are string literals, so `engine5.upgrade` cannot rewrite them — update
  style text by hand:

| widget | old key | new key |
|---|---|---|
| button | `color` (box) | `fill` |
| button | `text-color` | `color` |
| checkbox/radio | `col` (box outline) | `border-color` |
| checkbox/radio | `text-color` | `color` |
| checkbox/radio | `tick-col` | `tick-color` |
| frame | `color`, `color-dark` | `border-color`, `border-dark` |
| image | `color` (tint) | `tint` |
| window | `color` / `col` | `fill` |
| editbox | `col` | `color` |
| editbox class default | `borderWidth`, `borderColor` | `border-width`, `border-color` (the old spelling was never read, so edit boxes now get their default border) |
| scrollbar | `col`, `track-col`, `active-col` | `color`, `track-color`, `active-color` |
| scrollbar | `style: flat` | `variant: flat` |
| any | `inner-border` | `inner-border-color` |
| any | `border` (never read) | `border-color` |
| listbox (style, not yet read) | `sel-bg`, `sel-text-color` | `:selected { fill; color }` |
| transitions | `hoverTime`, `hoverTimeUp`, `hoverTimeDown` | `hover-time`, `hover-time-in`, `hover-time-out` |
| transitions | `pressTime`, `releaseTime`, `disableTime`, `enableTime` | `press-time`, `release-time`, `disable-time`, `enable-time` |
| any | `hover: parent` | `hover-target: parent` |

- Buttons (plain and toggle) temporarily left the common box path (`DrawCommonStyle`);
  they are back on it since 2026-09-05 (see above).
- Removed: `TUIElement.SetStyle` (edited the style text without reparsing, so it never
  took effect). Use `element.style.SetAttr(key,value)`.
- Legacy numeric `styleInfo` strings (`'60404040'`, `'FFB0C0C4 80000000'`) were never
  parsed by the R-05 parser; write `fill:$60404040` instead.
- `TUIEditBox.SetDefault('style',...)` / `SetDefault('styleInfo',...)`: only
  `styleInfo` is a real class attribute; `style` was never read.

## High-resolution `Time.Ticks` (2026-09-01)

- `Time.Ticks` now uses the same high-resolution monotonic source as
  `Time.TicksUs` (QPC on Windows, `clock_gettime` on Unix-like systems).
- Milliseconds are calculated directly with a cached `1000/frequency` scale;
  the runtime path does not call `TicksUs` or divide its result by 1000.
- This removes the 10-16ms Windows granularity of `GetTickCount64` while keeping
  `Time.Ticks` no slower than `Time.TicksUs`.
- `TestCore` checks for an observed timer step of at most 5ms. `BenchCore`
  compares the raw platform counter with `Time.Ticks` and `Time.TicksUs`, using
  ABBA ordering for the two scaled APIs to reduce warm-up/frequency bias.

## Android JNI VM state (2026-07-10)

- `jni.curVM` is now mutable. Android initialization stores the `PJavaVM`
  supplied by JNI so `Apus.Android` can attach and detach engine worker threads.

## Platform-native text line endings (2026-07-03)

- `Apus.Core.LineBreak` provides the current platform's native text line
  terminator: CRLF on Windows and LF on Unix-like systems.
- Robot API responses and the engine diagnostics used by Robot API handlers now
  use `LineBreak`; wire protocols that require CRLF remain unchanged.
- `Apus.Log` and `Apus.Logging` write native line endings to their log files and
  caches instead of forcing Windows CRLF on every platform.

## Glyph cache diagnostics and bounds fixes (2026-06-29)

- `Apus.GlyphCache` now rejects items that cannot fit the concrete atlas region
  before entering the band allocator. Packed glyph metadata supports dimensions
  up to 255x255; the older 63x63 comment was stale.
- Generic `DGC: cache overflow` errors now distinguish atlas-space exhaustion
  from exhaustion of internal band descriptors and include the requested band,
  atlas dimensions, and allocator state.
- `Apus.Engine.TextDraw` checks the fixed glyph-update rectangle list before
  writing a new entry, preventing a range-check exception in the diagnostic path.

## Socket API compatibility fixes (2026-06-28)

- `Apus.Socket.recv` and `send` now use the Delphi/FPC-compatible
  `NativeUInt` type for buffer length instead of the FPC-specific `SizeUInt`.
- `Apus.Socket.WSAAccept` uses `UIntPtr` for its callback data instead of the
  FPC-specific `PtrUInt` spelling.

## Thread lifecycle changes (2026-06-27)

- `Apus.HttpRequests` now launches request workers through
  `Apus.Threads.Thread.Start` and tracks them as `IThread`; the legacy
  `Classes.TThread` subclass and `Resume` lifecycle are gone.
- Unhandled exceptions escaping a `Thread.Start` callback are now written with
  `Log.Force`, including the thread name, exception class, raw exception address,
  available FPC stack-frame addresses, and message. The same diagnostic is kept
  in `IThread.StatusText` before the thread enters the error state.
- `Apus.Threads` now notifies `Apus.EventMan` when a thread exits. Any queued or
  mixed handlers still owned by that thread are removed, its pending events are
  discarded, and a warning lists each dangling event registration together with
  its handler address.

## Status note (2026-03-22)

- R-07 is confirmed working and merged into `engine5`.
- Base migration track is complete (100%): no active `Apus.Common` dependencies remain in live `Base/*.pas` modules.
- `Base/Apus.Common.pas` was removed; compatibility unit is kept only in `Base/Deprecated/Apus.Common.pas`.
- No global/blocking migration tasks remain in Base; current focus is support/development:
  - Linux fixes and verification;
  - benchmark runs and baseline tracking;
  - SSE optimization for highest-impact functions;
  - ongoing bugfixes with test coverage expansion.

## Recent API fixes (2026-05-29)

### Engine networking module names

- Renamed `Apus.Engine.Networking2` to `Apus.Engine.UdpTransport`.
- The module is the symmetric UDP transport layer: packets/sessions/ping/LAN discovery with `Connect` and `Accept`.
- Updated EngineTest project references and signal inventory docs to use the new name.
- 2026-10-07, lifecycle contract (porting old Networking2 code):
  - `NetInit(port)` binds the socket synchronously and strictly: a busy port raises `EError`
    (no silent move to `port+100`); on return the transport is ready. LAN tools that ran two
    instances on one host must use `NetInit(0)` for the second one.
  - `NetDone` joins the network thread and closes the socket before returning; a call without
    `NetInit` is ignored; connections are left disconnected (no notifications).
  - `TConnection.Create/Connect/Accept/SendData` raise `EError` before `NetInit`: create
    connections after it.
  - Session IDs no longer use `System.Random`, and the unit no longer calls `Randomize`.
  - 2026-10-08: the unit's generator is a `TRandom` from `Apus.Core` (`InitUnique`).

### Apus.Core typed row-pointer helpers

- Added shared zero-based row-pointer helper types in `Apus.Core` for typed raw-buffer indexing:
  - `TByteRow` / `PByteRow`
  - `TWordRow` / `PWordRow`
  - `TIntRow` / `PIntRow`
  - `TCardinalRow` / `PCardinalRow`
  - `TSingleRow` / `PSingleRow`
- Motivation: make Delphi/FPC-safe row casts explicit and reusable in image/buffer code, for example `PCardinalRow(data)^[i]`. Row types use a large upper bound so indexed access also works with range checking enabled.
- Added `TTexture.ScanLine(y):pointer` and `TTexture.PixelPtr(x,y):pointer` in `Apus.Engine.Resources` so locked texture code can use `PCardinalRow(tex.ScanLine(y))` or address a concrete pixel without repeating raw `data+pitch` arithmetic.

### Engine Linux SDL/OpenGL compile sweep

- Fixed `Apus.Engine.API` display-mode exports for API-only users:
  - `TDisplayScaleMode` now aliases `Apus.Engine.Types.TDisplayScaleMode`.
- Fixed Linux SDL mouse-button cursor handling to call `systemPlatform.SetCursor`.
- Updated `tests/PlatformTest.dpr` and `tests/OpenGL.dpr` to the current `TWindow`/`IGraphicsSystem` lifecycle and modern Base units instead of deprecated `Apus.Common`.
- Fixed case-sensitive include lookup in `tests/TestStyle.dpr` (`Test.inc`).
- Linux/FPC compile-only checks now pass for:
  - `tests/PlatformTest.dpr`
  - `tests/OpenGL.dpr`
  - `demo/SimpleDemo/SimpleDemo.dpr`
  - `demo/StyleDemo/StyleDemo.dpr`
  - `demo/MultiWindow/MultiWindow.dpr`
  - `demo/Draw2D/Draw2D.dpr`
  - `demo/InputDemo/InputDemo.dpr`
  - `demo/UI/UI.dpr`
  - `demo/TextDemo/TextDemo.dpr`
  - `demo/Tweenings/Tweenings.dpr`
- Linux/FPC runtime check now passes for:
  - `tests/TestStyle.dpr`
- Added `tests/linux_smoke.sh` to run these Linux/FPC checks without leaving build artifacts in the repository.

### Base Linux socket compatibility

- Extended `Apus.Socket` into the shared socket compatibility layer for the WinSock-style calls still used by legacy Base network modules.
- `Apus.TCP` and `Apus.SCGI` now depend on `Apus.Socket` instead of importing platform socket units directly.
- Unix-only resolver bindings are kept behind `{$IFDEF UNIX}` inside `Apus.Socket`.
- Linux/FPC compile sweep now includes:
  - `Apus.Socket`
  - `Apus.TCP`
  - `Apus.SCGI`
  - `Apus.Compress`
- `Apus.Profiling` remains Windows-only because its implementation directly uses the Windows unit.

### Base Linux runtime validation

- Updated `Base/tests/TestConv.dpr` to the current `Conv` API:
  - IP formatting uses `Conv.FormatIp(cardinal)`.
  - `Conv.ToStr(boolean)` expectations match the documented `short=false` default.
- `TestConv` now compiles and passes on Linux/FPC (`135` checks).
- Fixed Linux/FPC thread startup: POSIX `BeginThread` returns a `pthread_t`, which
  must not be assigned through the narrower `THandle` type before being stored as
  `TThreadID`.
- `TestThreads` now passes on Linux/FPC (`65` checks); `TestEventMan` concurrent
  thread scenarios also run without range-check exceptions.
- Fixed `Apus.EventMan.Link` to preserve the linked event name casing passed by
  the caller. Matching remains case-insensitive, while handlers now receive the
  same spelling behavior as direct `Signal` calls.
- `TestEventMan` now passes on Linux/FPC (`39` checks).
- Fixed zero-length `TVec2.Normalize` and `TVec2d.Normalize` to produce explicit
  NaN coordinates without executing runtime `0/0`. `IsValid` now uses `IsNan`
  for the first coordinate instead of a trap-prone NaN self-comparison.
- `TestGeom2D` now passes on Linux/FPC (`78` checks).
- Disabled Win64-ABI-only `TMat4` SSE helpers on Linux x64 so System V builds
  use the existing Pascal fallback for matrix multiplication and Vec4 point/normal transforms.
- `TestGeom3D` now passes on Linux/FPC (`80` checks).
- Fixed `Base/tests/test.sh` to return compilation and runtime failures to its
  caller. Added `Base/tests/test_all.sh` for the deterministic Linux-compatible
  Base regression set.
- Implemented SDL shared OpenGL context lifecycle for secondary windows,
  including cross-thread handoff, context sharing, reactivation, and
  per-context VAO setup for core profiles. Verified `MultiWindow` secondary
  startup and shutdown on Linux/WSL with a live `Tool 1` window.
- Added `cthreads` as the first unit for FPC/Unix builds of maintained demo
  entrypoints so engine applications can start thread-backed game loops on Linux.
- Implemented SDL scan-code to virtual-key mapping instead of returning an
  uninitialized value from `TSDLPlatform.MapScanCodeToVirtualKey`.
- Fixed SDL controller initialization to skip `InitJoystick(0)` when no
  joysticks are connected.
- Fixed SDL screen-coordinate helpers: `ScreenToClient` now subtracts the
  native window position, and `GetMousePos` uses `SDL_GetGlobalMouseState`.
- Made SDL window termination state per-window and routed close events by SDL
  window ID, so closing a secondary window does not terminate every window.
  Verified on Linux/WSL by closing a live `Tool 1` window while the main loop
  continued running.

## Recent API fixes (2026-03-22)

### Apus.Geom2D TRect2 point containment API

- Extended `TRect2` with point-containment methods:
  - `Contains(const p:TPoint):boolean`
  - `Contains(x,y:single):boolean`
- Motivation: remove duplicated inline point-in-rect checks in Engine code and standardize containment logic in the geometry type itself.
- Engine usage updated to call type methods directly (`TWindow.MouseInRect/MouseWasInRect`), avoiding unit-local helper functions.

### Apus.Core.Time high-precision monotonic ticks

- Added explicit high-precision monotonic time API in `Apus.Core.Time`:
  - `Time.TicksUs:int64` — microseconds since program start (QPC/clock_gettime based)
  - `Time.TicksSec:double` — seconds since program start (QPC/clock_gettime based)
- All three functions use a high-resolution monotonic source. Choose the unit
  needed by the caller: milliseconds, microseconds, or seconds.
- Added benchmark coverage in `Base/tests/BenchCore.dpr`:
  - `Time.Ticks`
  - `Time.TicksUs`
  - `Time.TicksSec`

## Recent API fixes (2026-03-23)

### Apus.Core.Time test-time override hook

- Added optional monotonic time override hook in `Apus.Core` for deterministic time-based tests.
- API is available only under `{$IFDEF TIME_OVERRIDE}`:
  - `Time.Override(timeUs:int64)` where `timeUs` is microseconds since program start.
- Time behavior under `TIME_OVERRIDE`:
  - if override value is non-zero, `Time.TicksUs` returns it directly;
  - `Time.Ticks` is derived from override as `timeUs div 1000`;
  - `Time.TicksSec` is derived from override as `timeUs * 1e-6`;
  - if override is zero, normal platform clock path is used.
- With `TIME_OVERRIDE` undefined, override code is not compiled and has zero runtime overhead.
- Test harness integration:
  - `Base/tests/test.bat` and `Base/tests/test.sh` now compile tests with `-dTIME_OVERRIDE` by default.
  - `Base/tests/TestCore.dpr` includes explicit `Time override` coverage.
  - `Base/tests/TestTweenings.dpr` uses virtual time path under `TIME_OVERRIDE` (with fallback to `Sleep` when define is off).

### Animation benchmark coverage

- Added `Base/tests/BenchAnimation.dpr` as a unified benchmark comparing `TTweening` and `TAnimatedValue` on matched scenarios:
  - active-animation read path (linear/easeOut);
  - retarget path with realistic overlap cap (<=3).
- Added `Animation` to available benchmark list in `Base/tests/README.md`.

## Recent API fixes (2026-03-24)

### Apus.Core stable SRound semantics across code paths

- Clarified and documented rounding helper intent in `Apus.Core`:
  - `PRound` is symmetric nearest (away from zero on `.5`);
  - `SRound` is rendering-stable nearest defined as `floor(v+0.5)`.
- Updated non-ASM `SRound` fallback to match SSE behavior exactly (`floor(v+0.5)`), replacing old `trunc(v+0.5)` fallback.
- Motivation:
  - keep identical rounding behavior across CPU/compiler paths;
  - preserve translation invariance used by rendering math: `SRound(x+1)=SRound(x)+1`.

### Apus.Files object-style TFileHandle I/O

- `TFileHandle` in `Apus.Files` is now an opaque record with object-style methods:
  - `Read(buf,size):integer`
  - `Write(buf,size):integer`
  - `Seek(offset,origin):int64`
  - `Close`
- These methods are thin wrappers over existing `Files.Read/Write/Seek/Close` and keep provider-chain behavior unchanged.
- Existing static handle API in `Files` remains available for compatibility.
- Added ergonomic untyped-buffer overloads:
  - `Read(var buf; size:integer)`
  - `Write(const buf; size:integer)`
  in `TFileHandle`.
- Safety tweak: raw-pointer access in `TFileHandle` is explicit (`ReadMem/WriteMem`) to avoid overload ambiguity with pointer-value serialization (`Write(ptr,sizeof(ptr))` writes pointer value via `const buf` overload).

## Recent API fixes (2026-03-14)

### Apus.EventMan thread-aware handler deduplication

- Fixed `SetEventHandler` deduplication identity for concurrent registrations:
  - before: duplicate check used only `(event,handler)`;
  - now: duplicate check uses `(event,handler,threadNum,mode)`.
- Effect: the same handler can be registered for the same event in multiple threads when using `emQueued/emMixed`, and each thread receives its own queued callback.
- Added regression coverage in `Base/tests/TestEventMan.dpr`:
  - concurrent unique-handler registration;
  - concurrent duplicate registration (same thread identity semantics);
  - queued same-handler registration in many threads (one callback per thread).

## Recent API fixes (2026-03-19)

### Apus.Utils command-line helpers restored

- Restored legacy command-line helpers in `Apus.Utils`:
  - `HasParam(const name:string):boolean`
  - `GetParam(const name:string):string`
- Source parity note: implementation moved from deprecated `Apus.Common` (`SameText` search across `ParamStr`).
- Engine integration:
  - `Apus.Engine.GameApp.Prepare` now uses `HasParam/GetParam` for platform selection (`-SDL`, `-WINDOWS`, `-PLATFORM=...`).

## Recent API fixes (2026-03-11)

### Apus.Spatial module skeleton

- Added new base module: `Base/Apus.Spatial.pas`.
- Introduced engine5-first geometry names and spatial primitives:
  - `TVec2`, `TVec3` (12 bytes), `TVec4`
  - `TMat2`, `TMat3`, `TMat34`, `TMat4`
  - `TRay`, `TSphere`, `TFrustum`
- Added methods-first intersection API:
  - `TRay.IntersectsSphere/IntersectsBox/IntersectsTriangle`
  - `TSphere.ContainsPoint/IntersectsSphere/IntersectsBox`
  - `TFrustum.InitFromMVP/IntersectsSphere/IntersectsBox`
  - `TFrustum.InitFromMVP(...;includeNearFar:boolean=true)` supports 4-plane mode for parallel/orthographic projection culling.
- Extended existing box type via helper:
  - `TBBox3sHelper.IncludePoint/IncludeBox/Center/Extents/ContainsPoint/IntersectsBox/IntersectsSphere`
- Added scoped static helpers in `TSpatial` (`Dot3`, `Cross3`, `Distance2`) to avoid global function sprawl.
- Compilation check: `Apus.Spatial.pas` builds with FPC in Delphi mode.

## Recent API fixes (2026-02-26)

### Apus.Files BOM-aware text I/O

- `Files.LoadAsString(fname,...)` now strips UTF-8 BOM when reading from file start (`startFrom=0`).
- `Files.Save(fname,data:String8)` now writes UTF-8 BOM by default.
- Added overload: `Files.Save(fname,data:String8;addBOM:boolean)` for explicit control.
  - Use `addBOM=false` for raw text/binary-like writes where byte-exact layout matters.

### Apus.Utils enum helper extraction

- Added `GetEnumNameSafe(typeInfo:pointer;value:integer):string` to `Apus.Utils`.
- Behavior matches legacy `Apus.Common`:
  - returns `GetEnumName(PTypeInfo(typeInfo),value)` when `typeInfo<>nil`
  - returns fallback string `ENUM_<value>` when `typeInfo=nil`
- Migration note: replace legacy implicit access via `Apus.Common` with explicit `uses Apus.Utils`.

### Apus.FreeTypeFont String32 migration

- `Apus.FreeTypeFont` public text API migrated from UTF-16 (`WideString`/`WideChar`) to UCS-4 (`String32`/`Char32`):
  - `RenderText(...;st:String32;...)`
  - `GetTextWidth(st:String32;...)`
  - `Interval(ch1,ch2:Char32;...)`
  - `CharPadding(ch:Char32;...)`
  - `RenderGlyph(ch:Char32;...)`
- Internal hash records now store `Char32` and `integer` metric fields to avoid truncation.
- FreeType calls now pass full codepoints (`cardinal(ch)`) instead of 16-bit truncation.

### Apus.Strings String32Helper ASCII accessors

- Added `String32Helper.TryAnsiChar(index:integer;out ch:AnsiChar):boolean` (0-based).
- Added `String32Helper.AnsiChar(index:integer;defaultChar:AnsiChar=#0):AnsiChar` (0-based).
- Purpose: simplify migration of parser code that operates on ASCII tags while input is `String32`.

### Apus.Strings String32 split overload parity

- Added `String32Helper.Split(const delimiters:String32;quoteChar:UCS4Char=0):Strings32`.
- Behavior mirrors `String8.Split(const delimiters:String8;quoteChar:AnsiChar=#0)`:
  - split by any delimiter char from the set
  - ignore delimiters while inside quoted fragments
  - keep quote characters in resulting tokens

### Apus.Core IntArray helper

- Added `IntArrayHelper` in `Apus.Core` with methods:
  - `IndexOf(value:integer):integer`
  - `Contains(value:integer):boolean`
  - `Add(value:integer)`
  - `Remove(value:integer):boolean`
- Migration note: replace legacy `FindInteger(arr,v)` with `arr.IndexOf(v)`.

### Apus.Threads TLock.Enter caller override

- `TLock.Enter` now accepts optional parameter: `procedure Enter(callerAddr:pointer=nil);`
- Use this in wrapper helpers to pass caller from higher stack frame, so lock diagnostics store meaningful owner/trying addresses.

## Recent API fixes (2026-02-22)

### Apus.Strings search API (case-insensitive support)

- `IndexOf/LastIndexOf/Contains` for `String8` and `String32` now support optional `ignoreCase`.
- Migration note: `PosFrom(..., ignoreCase=true)` must be rewritten manually to `st.IndexOf(..., true)` (tool marks TODO).

### Apus.HtmlTree UTF-8 API migration

- `Apus.HtmlTree` public API is now `String8`-based (`ParseHTML`, `DecodeHTMLString`, node text/tag/attributes helpers).
- Local `PosFrom` helper removed; module uses `String8.IndexOf(...,ignoreCase)` from `Apus.Strings`.

## Recent API fixes (2026-02-19)

### Apus.Core `Min/Max` return type corrections

Fixed incorrect return types that could truncate values:

| Old signature | New signature |
|---|---|
| `Min(a,b:cardinal):integer` | `Min(a,b:cardinal):cardinal` |
| `Min(a,b:int64):integer` | `Min(a,b:int64):int64` |
| `Min(a,b:uint64):integer` | `Min(a,b:uint64):uint64` |
| `Max(a,b:cardinal):integer` | `Max(a,b:cardinal):cardinal` |
| `Max(a,b:int64):integer` | `Max(a,b:int64):int64` |
| `Max(a,b:uint64):integer` | `Max(a,b:uint64):uint64` |
| `Min(a,b,c:single):integer` | `Min(a,b,c:single):single` |
| `Max(a,b,c:single):integer` | `Max(a,b,c:single):single` |

Implementation of `Min/Max(a,b,c:single)` was also fixed to compare `single` values directly (no `trunc()`).

## Apus.Colors (2026-06-09)

Global free functions replaced with static methods on `type Color = record`.
`BilinearMixF` (scalar) and `BilinearMix(values:PCardinal,u,v)` (SSE pointer overload) remain free functions.
`Color`, `TARGBColor`, `InvalidColor` are re-exported from `Apus.Lib`.

**Gotcha:** Pascal is case-insensitive — a local var named `color:cardinal` shadows the `Color` type.
Rename any such local to `col` or a more specific name before calling `Color.XXX()`.

| Old name | New name (Color record) | Notes |
|---|---|---|
| `MyColor(r,g,b)` | `Color.RGB(r,g,b)` | |
| `MyColor(a,r,g,b)` | `Color.ARGB(a,r,g,b)` | |
| `MyColorF(a,r,g,b)` | `Color.ARGBf(a,r,g,b)` | |
| `GrayColor(gray)` | `Color.Gray(gray)` | |
| `GrayAlpha(alpha)` | `Color.GrayAlpha(alpha)` | |
| `GetAlpha(color)` | `Color.Alpha(color)` | |
| `IsSemiTransparent(color)` | `Color.HasAlpha(color)` | |
| `SwapColor(color)` | `Color.Swap(color)` | |
| `ColorAdd(c1,c2)` | `Color.Add(c1,c2)` | |
| `ColorSub(c1,c2)` | `Color.Sub(c1,c2)` | |
| `ColorMult2(c1,c2)` | `Color.Mult(c1,c2)` | |
| `ColorAlpha(color,alpha)` | `Color.Scale(color,alpha)` | multiplies alpha channel |
| `ReplaceAlpha(color,alpha)` | `Color.SetAlpha(color,alpha)` | replaces alpha channel |
| `ColorMix(c1,c2,value:integer)` | `Color.Mix(c1,c2,value:integer)` | |
| `ColorMixF(c1,c2,t:single)` | `Color.Mix(c1,c2,t:single)` | |
| `ColorBlend(c1,c2,value:integer)` | `Color.Blend(c1,c2,value:integer)` | |
| `ColorBlendF(c1,c2,value:single)` | `Color.Blend(c1,c2,value:single)` | |
| `Blend(background,foreground)` | `Color.Blend(background,foreground)` | alpha-blend overload |
| `BilinearMix(c0,c1,c2,c3,u,v)` | `Color.BilinearMix(c0,c1,c2,c3,u,v)` | 4-arg cardinal overload |
| `BilinearBlend(c0,c1,c2,c3,v1,v2)` | `Color.BilinearBlend(c0,c1,c2,c3,v1,v2)` | |
| `Lightness(color)` | `Color.Lightness(color)` | |
| `ColorDiff(c1,c2)` | `Color.Diff(c1,c2)` | |
| `SimpleColorDiff(c1,c2)` | `Color.SimpleDiff(c1,c2)` | |
| `Brightness(c,value)` | `Color.Brighten(c,value)` | renamed |
| `Contrast(c,value)` | `Color.Contrast(c,value)` | same name |
| `BilinearMixF(v0,v1,v2,v3,u,v)` | `BilinearMixF(...)` | **stays free function** |
| `BilinearMix(values:PCardinal,u,v)` | `BilinearMix(values:PCardinal,u,v)` | **stays free function** (SSE) |

## Apus.Core (low-level math, memory, bits, time, exceptions)

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `min2(a,b)` | `Min(a,b)` | overloads for integer/single/double |
| `max2(a,b)` | `Max(a,b)` | overloads for integer/single/double |
| `min2d(a,b)` | `Min(a,b:double)` | merged into Min overloads |
| `max2d(a,b)` | `Max(a,b:double)` | merged into Max overloads |
| `min2s(a,b)` | `Min(a,b:single)` | merged into Min overloads |
| `max2s(a,b)` | `Max(a,b:single)` | merged into Max overloads |
| `Clamp(v,min,max)` | `Clamp(v,min,max)` | same name, added single/double overloads |
| `Sat(v,0,255)` | `Sat(v)` | now clamps to 0..1 (single/double) |
| `Swap(a,b)` | `Swap(a,b)` | same name |
| `GetPow2(v)` | `NextPow2(v)` | renamed for clarity (next power of two) |
| `Pow2(e)` | `Pow2(e)` | same name |
| `Log2i(v)` | `Log2i(v)` | same name |
| `HasFlag(v,flag)` | `Bits.HasAll(v,flag)` | |
| `SetFlag(v,flag)` | `Bits.SetFlag(v,flag)` | |
| `GetBit(data,idx)` | `Bits.Get(data,idx)` | |
| `SetBit(data,idx,val)` | `Bits.SetBit(data,idx,val)` | |
| `GetBits(data,idx,size)` | `Bits.GetBits(data,idx,size)` | overload for cardinal |
| `SetBits(data,idx,size,val)` | `Bits.SetBits(data,idx,size,val)` | overloads for byte/word/cardinal/uint64 |
| `ZeroMem(data,size)` | `Mem.Clear(data,size)` | |
| `Toggle(b)` | `Toggle(b)` | same name |
| `Wrap(v,max:single)` | `Wrap(v,max:single)` | same name; with fast path for in-range values |
| `Wrap(v,max:double)` | `Wrap(v,max:double)` | same name |
| `FRound(v:double)` | `FRound(v:double)` | same name; fast round (biased +epsilon) |
| `PRound(v:double)` | `PRound(v:double)` | same name; precise round |
| `SRound(v:single)` | `SRound(v:single)` | same name; SSE-accelerated, Pascal fallback for ARM |
| `HasValue(v)` | `HasValue(v)` | moved from Apus.Conv to Apus.Core; checks if variant is not unassigned |

### Stack trace support (new in engine5)

Namespace-style API for stack inspection:

| Method | Signature | Notes |
|---|---|---|
| `Stack.Caller` | `class function Caller: pointer` | Get immediate caller address using system API. For **fast caller** use intrinsics: `{$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF}` |
| `Stack.Trace` | `class function Trace(var frames: TCallStack; skip: integer = 0): integer` | Capture up to 4 call stack frames. Returns actual count. Used in exceptions/logging. |

Types:
- `TCallStack = array[0..3] of pointer` — fixed array for 4 stack frames

**Performance:** `Stack.Caller` is **~50-200 cycles** (system call). Intrinsic version is **~3-7 cycles** but requires inline usage.

Exception classes moved from `Apus.Classes` to `Apus.Core`:

| Old location (Classes) | New location (Core) | Notes |
|---|---|---|
| `TBaseException` | `TBaseException` | same name, base class with stack trace using `Stack.Trace` |
| `EWarning` | `EWarning` | same name |
| `EError` | `EError` | same name |
| `EFatalError` | `EFatalError` | same name |

**Note:** In engine5, `EBaseException` uses `Stack.Trace` to capture call stack on all platforms (previously only worked on x86 32-bit). Exception message format: `[addr1->addr2->addr3] Error message`

### Time scope (new in engine5)

Unified time API replacing fragmented functions:

| Old name | New name (Time) | Notes |
|---|---|---|
| `GetTickCount` (32-bit) | `Time.Ticks` | **REMOVED** — old 32-bit version (overflow every 49 days) |
| `GetTickCount64` | `Time.Ticks` | 64-bit monotonic time in ms, cross-platform |
| `MyTickCount` | `Time.Ticks` | better replacement with no overflow |
| `Sleep(ms)` | `Time.Sleep(ms)` | moved to Time scope |
| `Time.Now` | `Time.Now` | same — high-precision local datetime |
| `Time.UTC` | `Time.UTC` | same — high-precision UTC datetime |
| `Time.Stamp` | `Time.Stamp` | same — HH:MM:SS.mmm for logs |

**High-resolution timer** (`Timer` scope in Apus.Core):
- `Timer.Start(out t)` / `Timer.Get(t):double` — explicit timer, returns seconds
- `Timer.Start` / `Timer.Get` — implicit internal timer (parameterless)

Exception helper functions moved from `Apus.Common` to `Apus.Core`:

| Old location (Common) | New location (Core) | Notes |
|---|---|---|
| `ExceptionMsg(e)` | `ExceptionMsg(e)` | Returns the message with a raw address chain safe to capture inside any worker thread. For `EBaseException` uses its already captured stack; for regular FPC exceptions includes `ExceptAddr` and available `ExceptFrames`. |
| `NotImplemented(msg)` | `NotImplemented(msg)` | Raises `EError` with "Not implemented: msg". Inline. |
| `NotSupported(msg)` | `NotSupported(msg)` | Raises `EError` with "Not supported: msg". Inline. |

### Time scope (new in engine5)

High-precision time functions:

| Old name (Common) | New name (Core) | Notes |
|---|---|---|
| `NowGMT` | `Time.UTC` | UTC time in TDateTime format (high-precision on Windows 8+) |
| — | `Time.Now` | Local time in TDateTime format (high-precision on Windows 8+) |
| `GetUTCTime` + formatting | `Time.Stamp` | Returns `HH:MM:SS.mmm` string for logs |
| `MyTickCount` | `Time.Ticks` | high-resolution monotonic milliseconds, cross-platform |

**Usage:**
```pascal
dt := Time.UTC;           // high-precision UTC
dt := Time.Now;           // high-precision local time
Log.Msg(Time.Stamp + ' Started');
```

Use `CoreTime.Ticks` when `SysUtils.Time` creates a name conflict in a unit.

## Apus.Conv (parsing and formatting)

| Old name (Common) | New name (Conv) | Notes |
|---|---|---|
| `ParseInt(st)` | `Conv.ToInt(st)` | |
| `ParseFloat(st)` | `Conv.ToFloat(st)` | |
| `ParseBool(st)` | `Conv.ToBool(st)` | |
| `HexToInt(st)` | `Conv.HexToInt(st)` | same name |
| `StrToIp(st)` | `Conv.ToIp(st)` | |
| `IpToStr(ip)` | `Conv.FormatIp(ip)` | renamed from Conv.ToIp(cardinal) to Conv.FormatIp |
| `FormatHex(v,digits)` | `Conv.ToHex(v,digits)` | |
| `PtrToStr(p)` | `Conv.ToStr(p)` | |
| `BoolToAStr(b)` | `Conv.ToStr(b)` | |
| `FormatInt(v)` | `Conv.FormatInt(v)` | same name |
| `FormatMoney(v,digits)` | `Conv.FormatMoney(v,digits)` | same name |
| `SizeToStr(size)` | `Conv.FormatSize(size)` | |
| `FormatTime(timeMs)` | `Conv.TimeToStr(timeMs)` | |
| `EncodeHex(data,size)` | `Conv.EncodeHex(data,size)` | same name |
| `DecodeHex(hexStr)` | `Conv.DecodeHex(hexStr)` | same name |
| `HexDump(buf,size)` | `Conv.HexDump(buf,size)` | same name |
| `DecDump(buf,size)` | `Conv.DecDump(buf,size)` | same name |
| `EncodeB64(data,size)` | `Conv.ToBase64(data,size)` | |
| `DecodeB64(st,buf,size)` | `Conv.FromBase64(st,buf,size)` | |

## Apus.Strings (string helper methods)

String functions moved from free-standing functions to `String8Helper` record helper.
Call style changes from `Func(st, args)` to `st.Method(args)`.

| Old name (Common) | New name (Strings) | Notes |
|---|---|---|
| `PosFrom(substr,st)` | `st.IndexOf(substr)` | For `ignoreCase=true`, use manual rewrite to `st.IndexOf(substr,1,true)` |
| `PosFrom(substr,st,minIdx)` | `st.IndexOf(substr,minIdx)` | For `ignoreCase=true`, use manual rewrite to `st.IndexOf(substr,minIdx,true)` |
| `LastPos(substr,st)` | `st.LastIndexOf(substr)` | |
| `Chop(st)` | `st.Trim` | |
| `SameText8(a,b)` | `a.Same(b)` | case-insensitive |
| `UpperCase(st)` | `st.ToUpper` | |
| `LowerCase(st)` | `st.ToLower` | |
| `SplitA(delim,st)` | `st.Split(delim)` | **CAUTION**: Split treats each char as delimiter; SplitA uses whole string |
| `Join(arr,delim)` | `String8.Join(arr,delim)` | class function |
| `QuoteStr(st)` | `st.Quote` | |
| `UnQuoteStr(st)` | `st.Unquote` | |
| `URLEncodeUTF8(st)` | `st.UrlEncode` | |
| `ExtractStr(st,pre,suf)` | `st.Extract(pre,suf)` | |
| `ParseInt(st)` | `st.ToInt64` | also available via Conv.ToInt |
| `ParseFloat(st)` | `st.ToDouble` | also available via Conv.ToFloat |
| `ParseBool(st)` | `st.ToBoolean` | also available via Conv.ToBool |
| `FastHash(st)` | `FastHash(st)` | same name, simple fast hash (case-insensitive) |
| `StrHash(st)` | `StrHash(st)` | same name, string hash (case-sensitive) |
| `SameText8(a,b)` | `a.Same(b)` | case-insensitive comparison |
| `Format(fmt,args)` | `UTF8.Format(fmt,args)` | native String8 format, no Unicode roundtrip. Specs: %d %u %x %X %f %g %s %p %%, flags: - 0 +, width, .precision |

### String type conversion (new in engine5)

| Old name (Common) | New name (Strings) | Notes |
|---|---|---|
| `Str8(st)` | `Str8(st)` | same name; overloads for UnicodeString, WideString, UTF8String (+AnsiString in UNICODE mode) |
| `Str16(st)` | `Str16(st)` | same name; overloads for UnicodeString, WideString, UTF8String (+AnsiString in UNICODE mode) |
| — | `Str32(st)` | **NEW**: convert String8/WideString/UnicodeString to String32 (UCS-4) |

### UTF-8 encoding (moved from Apus.Conv to Apus.Strings)

| Old name (Common/Conv) | New name (Strings) | Notes |
|---|---|---|
| `EncodeUTF8(ws)` | `UTF8.Encode(ws)` | WideString → String8; also accepts addBOM parameter |
| `DecodeUTF8(s)` | `UTF8.ToWide(s)` | String8 → WideString; strips BOM if present |
| `IsUTF8(s)` | `UTF8.HasBOM(s)` | check for UTF-8 BOM |
| `UTF8.FromWide(ws)` | `UTF8.FromWide(ws)` | alias for UTF8.Encode (inline) |

### Encoding conversion (moved from Apus.Conv to Apus.Utils)

| Old name (Common/Conv) | New name (Utils) | Notes |
|---|---|---|
| `UnicodeTo(ws,enc)` | `UnicodeTo(ws,enc)` | WideString → String8 with arbitrary encoding (UTF-8/Win1251/ANSI) |
| `UnicodeFrom(s,enc)` | `UnicodeFrom(s,enc)` | String8 → WideString with arbitrary encoding |

## Apus.Files (file I/O and utilities)

File functions moved from free-standing functions to `Files` record with static class methods.
Call style changes from `Func(args)` to `Files.Method(args)`.

### File I/O

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `MyFileExists(fname)` | `Files.Exists(fname)` | |
| `GetFileSize(fname)` | `Files.GetFileInfo(fname,info)` | size via `info.size` field |
| `LoadFileAsBytes(fname)` | `Files.LoadAsBytes(fname)` | added `numBytes`, `startFrom` params |
| `LoadFileAsString(fname)` | `Files.LoadAsString(fname)` | added `numBytes`, `startFrom` params |
| `SaveFile(fname,buf,size)` | `Files.Save(fname,buf,size)` | also overloads for ByteArray, String8, TBuffer |
| `ReadFile(fname,buf,posit,size)` | `Files.ReadBlock(fname,buf,offset,size)` | |
| `WriteFile(fname,buf,posit,size)` | `Files.WriteBlock(fname,buf,offset,size)` | |

### File operations

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `CopyFile(sour,dest)` | `Files.CopyFile(sour,dest)` | same name |
| `MakeBakFile(fname)` | `Files.MakeBakFile(fname)` | same name |

### Directory operations (`Folder` record)

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `DirectoryExists(path)` | `Folder.Exists(path)` | new wrapper |
| `ForceDirectories(path)` | `Folder.Create(path)` | creates with parents |
| `ListFiles(path,mask,recursive)` | `Folder.ListFiles(path,mask,recursive)` | mask supports `;`-separated patterns |
| `FindFile(name,path)` | `Folder.Find(name,path)` | findDir=false by default |
| `FindDir(name,path)` | `Folder.Find(name,path,true)` | findDir=true |
| `CopyDir(sour,dest)` | `Folder.Copy(sour,dest)` | |
| `MoveDir(sour,dest)` | `Folder.Move(sour,dest)` | |
| `DeleteDir(path)` | `Folder.Delete(path)` | |

### Path utilities

| Old name (Common) | New name (Files) | Notes |
|---|---|---|
| `SafeFileName(fname)` | `Files.SafeFileName(fname)` | same name |
| `FileName(fname)` | `Files.FileName(fname)` | same name |
| `AddFileNameRule(rule)` | `Files.AddFileNameRule(rule)` | same name |
| `IsPathRelative(fname)` | `Files.IsPathRelative(fname)` | same name |
| `WaitForFile(fname,delay,exists)` | `Files.WaitForFile(fname,delay,exists)` | same name |

### Not moved (stays in Common)

| Old name (Common) | Notes |
|---|---|
| `DumpDir(path)` | depends on ForceLogMessage (logging) |

## Apus.Log (unified logging interface)

Logging functions extracted from `Apus.Common` into new unified API.

### Basic logging

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `LogMessage(text)` | `Log.Msg(text)` or `Log.Info(text)` | default severity is Normal (was Normal in Common) |
| `LogMessage(text,group)` | `Log.Msg(text,group)` | category parameter |
| `LogMessage(text,params)` | `Log.Msg(text,params)` | Format overload |
| `ForceLogMessage(text)` | `Log.Force(text)` | forced (bypass cache, flush immediately) |
| `LogError(text)` | `Log.Error(text)` | error level + counter increment |
| `DebugMessage(text)` | `Log.Debug(text)` | debug level (lowest) |
| — | `Log.Warn(text)` | new: warning level |
| — | `Log.Fatal(text)` | new: fatal error level |

### Logger configuration

| Old name (Common) | New name (Log) | Notes |
|---|---|---|
| `UseLogFile(name)` | `Logger.UseLogFile(name)` | same name, added `useThread` and `keepOpened` params |
| `SetLogMode(mode,groups)` | `Logger.SetVerbosity(minSeverity)` | simplified: only min severity filter |
| `FlushLog` | `Logger.Flush` | same functionality |
| `LogCacheMode(enable,enforce,runThread)` | `Logger.LogCacheMode(enable,bypassSeverity)` | redesigned params |
| `StopLogThread` | `Logger.StopLogThread` | same name |
| — | `Logger.SetCustomHandler(handler,disable)` | **NEW**: interceptor support for Apus.Logging refactor |
| — | `Logger.GetErrorCount` | **NEW**: returns error/fatal counter |
| — | `Logger.GetTail(maxSize)` | **NEW**: last bytes of the active log file, cached messages included; the caller needs no path (2026-10-28) |

### Severity levels (TSeverity enum)

Replaces old TLogModes (lmSilent/lmForced/lmNormal/lmVerbose):

| Old (Common) | New (Log) | Value | Notes |
|---|---|---|---|
| — | `TSeverity.Debug` | 0 | auxiliary debug info |
| — | `TSeverity.Info` | 1 | minor event |
| LogMessage default | `TSeverity.Normal` | 2 | regular event |
| ForceLogMessage | `TSeverity.Forced` | 3 | important, flush buffer |
| — | `TSeverity.Warn` | 4 | warning |
| LogError | `TSeverity.Error` | 5 | error |
| — | `TSeverity.Fatal` | 6 | fatal error |

## Apus.Threads (thread synchronization and management)

Threading primitives and thread management utilities extracted from `Apus.Common`.

**Major changes in engine5:**
- **Type renamed**: TMyCriticalSection → TLock (modern, cross-platform)
- **Fields encapsulated**: TLock fields are now private
- **New scope**: `Thread` record for thread operations
- **New methods**: TLock.Init/Cleanup, IsLocked, GetOwner
- **New type**: TLightweightEvent (WaitOnAddress/futex-based)

### Critical section management

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `InitCritSect(cr,name,level)` | `InitCritSect(cr,name,level)` | same name |
| `DeleteCritSect(cr)` | `DeleteCritSect(cr)` | same name |
| `EnterCriticalSection(cr,caller)` | `EnterCriticalSection(cr,caller)` | same name |
| `LeaveCriticalSection(cr)` | `LeaveCriticalSection(cr)` | same name |
| `DumpCritSects` | `DumpCritSects` | same name |
| `CheckCritSections` | `CheckCritSections` | same name |
| `TMyCriticalSection.Enter` | `lock.Enter` | method restored, same syntax |
| `TMyCriticalSection.Leave` | `lock.Leave` | method restored, same syntax |

### Thread scope (modern API)

| Old function (Common) | New method (Threads) | Notes |
|---|---|---|
| `RegisterThread(name)` | `Thread.Register(name)` | static method, cleaner |
| `UnregisterThread` | `Thread.Unregister` | static method |
| `PingThread` | `Thread.Ping` | static method |
| `GetThreadName(threadID)` | `Thread.GetName(threadID)` | static method, 0=current |

**Note**: Old functions still available but deprecated for compatibility.

### TLock object methods (new in engine5)

| Method | Notes |
|---|---|
| `lock.Init(name, level)` | Initialize lock (replaces InitCritSect) |
| `lock.Cleanup` | Cleanup lock (replaces DeleteCritSect) |
| `lock.Enter` | Acquire lock |
| `lock.Leave` | Release lock |
| `lock.IsLocked` | Check if locked |
| `lock.GetOwner` | Get owning thread ID |

### Utilities

| Old name (Common) | New name (Threading) | Notes |
|---|---|---|
| `WaitFor(var p,maxTime)` | `WaitFor(var p,maxTime)` | same name |
| `debugCriticalSections` | `debugCriticalSections` | global var, same name |

### Types moved from Apus.Types

| Old type (Types/Common) | New type (Threads) | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | **RENAMED** and moved from Apus.Types to Apus.Threads |
| `PCriticalSection` | `PLock` | **RENAMED** pointer type |
| `TSRWLock` | `TSRWLock` | **MOVED** from Apus.Types to Apus.Threads (Windows Vista+) |

### New types in engine5

| Type | Description |
|---|---|
| `TLightweightEvent` | Lightweight event using WaitOnAddress (Win8+) or futex (Linux) |
| `TScopedLock` | Delphi-only RAII lock wrapper with automatic cleanup (`{$IFDEF DELPHI}`) |
| `Thread` | Static record for thread operations |

### Backward compatibility aliases

| Old name | New name | Notes |
|---|---|---|
| `TMyCriticalSection` | `TLock` | type alias |
| `PCriticalSection` | `PLock` | type alias |
| `TCriticalSection` | `TLock` | type alias |
| `PCS` | `PLock` | type alias |
| `RegisterThread` | `Thread.Register` | old function deprecated |
| `UnregisterThread` | `Thread.Unregister` | old function deprecated |
| `PingThread` | `Thread.Ping` | old function deprecated |
| `GetThreadName` | `Thread.GetName` | old function deprecated |

## Apus.Utils (miscellaneous utilities)

Functions that don't fit scope of core/conv/strings/files modules.

| Old name (Common) | New name (Utils) | Notes |
|---|---|---|
| `ParseDate(st,default)` | `ParseDate(st,default)` | same name - parses DD.MM.YYYY HH:MM:SS and variants |
| `ParseTime(st,default)` | `ParseTime(st,default)` | same name - parses HH:MM:SS |
| `GetDateFromStr(st)` | `GetDateFromStr(st)` | alias for ParseDate |
| `SplitA(divider,st)` | `SplitA(divider,st)` | same name - splits by string divider (whole string, not charset) |
| `SplitA(divider,st,quotes)` | `SplitA(divider,st,quotes)` | same name - with quote handling |
| `Chop(st)` | `Chop(st)` or `st.Trim` | both available - trim whitespace |

**Note**: Utils is the default place for functions that don't fit other modules. More functions will be added here (EncodeUTF8/DecodeUTF8, AddString/RemoveString, HasParam/GetParam, etc).

## Apus.Compress (compression and patching)

Compression/decompression and binary patching utilities extracted from `Apus.Common`.

### RLE compression

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `PackRLE(buf,size,addHeader)` | `RLE.Pack(buf,size,addHeader)` | |
| `UnpackRLE(buf,size)` | `RLE.Unpack(buf,size)` | |
| `CheckRLEHeader(buf,size)` | `RLE.CheckHeader(buf,size)` | returns unpacked size or -1 |

### LZ compression

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `SimpleCompress(data)` | `LZ.Compress(data)` | |
| `SimpleDecompress(data)` | `LZ.Decompress(data)` | |

### Binary patching

| Old name (Common) | New name (Compress) | Notes |
|---|---|---|
| `CreateBackupPatch(orig,mod,size)` | `Patch.Create(orig,mod,size)` | |
| `ApplyBackupPatch(data,size,patch,patchSize)` | `Patch.Apply(data,size,patchBuf,patchSize)` | |

## Remaining legacy Common surface

This section tracks old `Apus.Common` helpers that still matter for migration.
Do not treat it as a list of functions to reintroduce under the old names.

### Resolved replacements

| Old name | Replacement | Notes |
|---|---|---|
| `EncodeUTF8(st)` / `DecodeUTF8(st)` | `UTF8.Encode`, `UTF8.ToWide`, `UTF8.FromWide`, `Str8`, `Str16` in **Apus.Strings** | Prefer explicit UTF-8 helpers and string conversion helpers, not standalone Common names. |
| `UnicodeFrom(st,enc)` / `UnicodeTo(st,enc)` | **Apus.Utils** | `TTextEncoding` and the encoding conversion helpers live together in `Apus.Utils`. |
| `Str8(s)` / `Str16(s)` | **Apus.Strings** | Cast/convert to `String8` / `String16`. |
| `SortRecordsByInt/Double/Float` | **Apus.Core.Sort** | Implemented as `Sort.ByInt/ByFloat/ByDouble(var items; itemSize,itemCount,offset:integer; asc:boolean)`. |
| `HasParam/GetParam` | **Apus.Utils** | Command-line argument access. |
| `TTextEncoding/teUnknown` | **Apus.Utils** | Defined as `TTextEncoding=(teUnknown,teANSI,teWin1251,teUTF8)`. |
| `ErrorMessage(msg)` | **Apus.Core** `SystemMessage(msg)` | Configurable critical message output (log/stderr/msgbox/raise). |
| `LastChar(st)` | **Apus.Strings** | Available as string helper methods. |
| `Unescape(st)` | **Apus.Strings** | Available as `String8Helper.Unescape`. |
| `ExtractFilePath/FileName/ExpandFileName` | **SysUtils** | RTL functions; add `SysUtils` to `uses`. |
| `TrimLeft/TrimRight` standalone | **SysUtils** or `st.TrimLeft/TrimRight` | Also available as `String8` helper methods. |
| `TRandom` | **Apus.Core** `TRandom` | Same idea, finished as a real PCG32: `Init(seed[,stream])`, new `InitUnique` (clock+PID+thread ID+stack address+counter; old `Init(0)` seeded from `Now` and gave equal sequences to processes started together), `Next` is the PCG32 output, `Float` never returns 1.0, `Normal` keeps the second Box-Muller value. Added `Range`, `Chance`, `Round`. |
| `RandomInt(v)` | **Apus.Core** `TRandom.Round(v)` | Needs a generator instance; now a proper floor for negative values. |

### Still unresolved or intentionally absent

| Old name | Current status | Notes |
|---|---|---|
| `IsUTF8(st)` | Not reintroduced as a Common-compatible helper | Old behavior checked for UTF-8 BOM. Prefer explicit BOM handling or `UTF8.IsValid`, depending on intent. |
| `SafeStrItem(arr,i)` | Still only in deprecated Common | Add a small helper only when a live migration needs this exact behavior. |
| `PackBytes(b1..b4)` / `PackWords(w1,w2)` | Still only in deprecated Common | Candidate for `Apus.Core` if live users need it. |
| `PointerInRange(p,base,size)` | Still only in deprecated Common | Candidate for `Apus.Core` if live pointer-range checks need it. |
| `AddString/RemoveString/FindString` | Still only in deprecated Common under the old names | Prefer typed dynamic-array helpers or capacity-aware builders for new code. `Base/Apus.Android.pas` still has legacy-name users behind Android-specific code paths. |
| `RandomStr(l)` | Not reintroduced | Add to `TRandom` when a live migration needs it. |
| `PseudoRand` / `FillRandom` | Not reintroduced | Deterministic hash-like fillers, not random generators. |

## 2026-03-18 — Hash Maps Consolidation

### Moved from `Apus.Structs` to `Apus.HashMaps`

- `THashItem`, `TCell`
- `TStrHash`
- `THash`
- `TSimpleHash`, `TSimpleHashS`, `TSimpleHashAS`, `TSimpleHash8`
- `TObjectHash`, `PObjectHash`
- `TVarHash`, `PVarHash`
- `TErrorState`

### Final `Apus.Structs` state

- `Apus.Structs` is removed from live Base.
- No compatibility aliases are kept in `Apus.Structs`; update old units to use
  `Apus.HashMaps` or `Apus.Containers` explicitly.
- Hash implementations live in `Apus.HashMaps`.
- Non-hash algorithmic containers live in `Apus.Containers`.

### Deprecation policy

- Preferred generic API for new code: `THashMap<T>`.
- Supported specialized hashes:
  - `THash` (DB-oriented multi-value mode: `String8 -> variant(s)`)
  - `TSimpleHash` (`int64 -> int64`)
  - `TObjectHash` (`String8 -> TNamedObject`)
- Legacy/compat hashes marked `deprecated`:
  - `TStrHash`
  - `TSimpleHashS`
  - `TSimpleHashAS`
  - `TSimpleHash8`
  - `TVarHash`

## 2026-03-18 — Containers split

- Added new module `Apus.Containers` for non-hash algorithmic containers.
- Removed `Apus.Structs` unit and moved container API surface to `Apus.Containers`.
- Removed legacy `TestStructs`; added `TestContainers` in modern test format.
- `TBitStream` is now in `Apus.Types`.

## 2026-03-19 — Sort API moved to Apus.Core

- Added `Sort` scope in `Apus.Core`:
  - `Sort.ByInt`
  - `Sort.ByFloat`
  - `Sort.ByDouble`
  - `Sort.ByStr` (`String8` field)
- Removed legacy `SortRecordsByInt/Float/Double` API from `Apus.Types` (no wrappers left).
- Moved sorting coverage from `TestTypes` to `TestCore`.

## 2026-03-19 — Apus.Types validation and fixes

- Added new test suite: `Base/tests/TestTypes.dpr` (modern console test template).
- Expanded edge-case coverage for:
  - `TIntRange` / `TFloatRange`
  - `TArray<T>`
  - `TNameValue` / `TNameValueList`
  - `TBuffer` / `TWriteBuffer`
  - `TBitStream`
- Fixed defects found by tests:
  - `TBitStream`: proper buffer zeroing size, safe bit mask for bit 31 under range/overflow checks, correct resize rounding, correct bit-write path in `Put(var buf;...)`.
  - `TNameValueList.Init(st,...)`: constructor now assigns delegated constructor result to `self`.

## 2026-06-19 — Depth state API (Apus.Engine.API)

- `IRenderTarget.UseDepthBuffer(test;writeEnable:boolean)` → **`SetDepthMode(test:TDepthTest=Keep; write:TDepthWrite=Keep)`**. The misleading "buffer" name dropped; test and write mask are now independent axes, each with a keep-current sentinel.
- `TDepthBufferTest` → **`TDepthTest`** (scoped enum): `dbDisabled/dbPass/dbPassLess/dbPassLessEqual/dbPassGreater/dbNever` → `TDepthTest.Disabled/Pass/Less/LessEqual/Greater/Never` + new `TDepthTest.Keep`.
- New **`TDepthWrite`** scoped enum (`Keep/Off/On`) for the write mask (was a bare `boolean`). `,false`→`,TDepthWrite.Off`, `,true`→`,TDepthWrite.On`.
- New **`IRenderTarget.DepthMode:TDepthMode`** getter (record `{test;write}`) + tracked `curDepth` threadvar state — enables save/restore and keep-current. No state stack (deliberate).
- Fixed latent bug: write mask was skipped when test=`dbDisabled`; now `glDepthMask` always reflects tracked state.
- No compatibility alias. Upgrader rules added to `tools/engine5.upgrade`.

## 2026-06-19 — Removed legacy OpenGL painters

- Removed `Apus.Engine.PainterGL.pas` and `Apus.Engine.PainterGL2.pas`.
- Current desktop rendering uses `Apus.Engine.OpenGL` with `IGraphicsSystem`, `IRenderTarget`, `IShader`, `IDrawer`, and `ITextDrawer`.
- The old Android backend still needs migration to the current graphics-system architecture before Android builds can be re-enabled.

## 2026-07-12 — Android system-log mirror

- `Apus.Log` now mirrors important Android messages (`Forced` and above) to
  logcat under the `ApusEngine` tag.
- Severity maps to Android's Info/Warn/Error/Fatal priorities. Lower-volume
  `Debug`, `Info`, and `Normal` messages remain in the regular Engine5 log.
- No public logging API changed.

## 2026-08-25 — R-31 working surface model (stage B)

Window geometry is now a resolved snapshot instead of a set of loose fields.
Design: `Work/R-31_api_design.md`.

- `TWindow` gained `config:TSurfaceConfig` (the axes requested for this window)
  and `surface:TSurfaceState` (the resolved snapshot: client/display/render/canvas
  sizes, safe area, DPI, mechanism). The snapshot is written only by the window's
  own thread, between frames.
- Renamed: `TWindow.renderWidth/renderHeight` → **`canvasWidth/canvasHeight`**,
  `windowWidth/windowHeight` → **`clientWidth/clientHeight`**, `screenDPI` →
  **`surface.dpi`**. `displayRect` is now a read-only property.
- `ClientToGame`/`GameToClient` (procedures with a `var` argument) →
  **`ClientToCanvas`/`CanvasToClient`** functions, plus `TryClientToCanvas`
  (false outside the display rect) and `MapPointerToCanvas` (pointer contract:
  outside the picture the position is dropped unless a button is held).
  `TGameBase.RenderSize` → **`CanvasSize`**.
- Resize/DPI flow inverted: the platform layer only posts a request
  (`RequestResize`, `RequestDPI`, `SetNativeSafeArea`), and the window's own
  thread applies it at frame start via **`ApplyPendingSurface`**. A tool window
  resize no longer rebuilds the main window. `TGame.SetupRenderArea`,
  `TGame.SizeChanged` and the `ENGINE\RESIZE` signal are gone.
- Events `ENGINE\BEFORERESIZE`, `ENGINE\RESIZED`, `ENGINE\DPICHANGED` and
  `ENGINE\DPICHANGED\DONE` are replaced by a single **`ENGINE\SURFACECHANGED`**
  (`tag=UIntPtr(wnd)`), sent after the rebuild; what changed is in
  `wnd.surface.changes`.
- `TGameSettings`: `mode,altMode` are plain `TDisplayMode` now; the axes come as
  `surface:TSurfaceConfig`. Removed: `TDisplaySettings`, `TDisplayFitMode`
  (`dfm*`), `TDisplayScaleMode` (`dsm*`).
- `TGameApplication`: removed `TGameAppMode`/`gameMode`, `directRenderOnly` and
  `useRealDPI` (the process is DPI-aware unconditionally). Added `orientation`,
  `surfaceConfig`, presets `SetupFullWindow` / `SetupFixedCanvas` /
  `SetupMobilePortrait` / `SetupMobileLandscape` / `SetupPixelArt`, and the
  `ConfigureSurface` hook called before every resolve.
- The default render target is no longer a global switch: it is created only when
  the resolved surface needs one (`surface.needRT`), so the full-window default
  still renders straight to the backbuffer.
- Migration: `gamUseFullWindow` → the default, `gamKeepAspectRatio` →
  `SetupFixedCanvas(w,h)`. Upgrader rules added to `tools/engine5.upgrade`.

## 2026-08-31 — Audio backends are opt-in

- `defines.inc` no longer enables any audio backend on its own. Nothing is
  linked unless the project builds with `-dSDLMIX` (SDL2_mixer) or `-dIMX`
  (legacy Win32 IMixerPro). The `NOAUDIO` opt-out is gone with it.
- Rationale: a backend binding is a load-time import, so linking one makes the
  executable depend on `SDL2_mixer.dll` / `libSDL2_mixer` even when the project
  never plays a sound.
- With no backend compiled in, `InitSoundSystem(slDefault,...)` logs one line
  and returns instead of raising. An explicit backend request (`slSDL`,
  `slIMixer`) still raises, as before.
- Builds that need sound: put `-dSDLMIX` in the project's `build.cfg` (as
  `demo/SoundDemo/build.cfg` does) or pass it to `build.cmd`/`build.sh`.

## 2026-08-31 — Files: the open mode is part of the function name

- `Files.Open(fname,readOnly)` is replaced by four functions, in `IFileProvider`
  as well: `OpenRead` (read-only, must exist), `Open` (read+write from position
  0, created if missing), `OpenNew` (previous content discarded), `OpenAppend`
  (read+write at the end, created if missing). Migration: `Open(f,true)` →
  `OpenRead(f)`; `Open(f,false)` → `Open(f)` to keep the content, or `OpenNew(f)`
  to replace it. A read-only provider only has to serve `OpenRead`.
- Rationale: the boolean carried two different intentions for writers — "rewrite
  this file" and "write into the existing one" — and the rewriting callers had
  to remember to truncate afterwards. `Files.Save(String8)` with the default BOM
  and `Files.CopyFile` didn't, so writing shorter content left a tail of the
  previous one in the file. Both are fixed by opening with `OpenNew`, and the
  compensating `SetSize` is gone from `Files.Save`.
- `Files.WriteBlock` keeps its "write at an offset" meaning and no longer doubles
  as a whole-file save: the three engine callers (robot `screenshot`,
  `TWindow.CaptureFrame`, `ImageTools.SaveImage`) now use `Files.Save`, which
  truncates. Saving a PNG over a longer one used to leave bytes past `IEND`.

## 2026-09-14 — TGameApplication: startup settings are instance fields

The startup globals of `Apus.Engine.GameApp` became protected fields of
`TGameApplication`, grouped by meaning, and the project sets them in one place:
the new `SetupApplication` hook. Design: `Work/gameapp_settings_namespaces.md`.

- New protected virtual `SetupApplication`. `Prepare` calls it once, before the
  log, config and platform are set up. Override it, call `inherited` first, then
  assign the fields and the surface preset (`SetupFixedCanvas` etc). `Create`
  only sets the defaults, so the order of `inherited` and the assignments no
  longer matters for them. A second `Prepare` call raises `EError`.
- Field groups (records with `Init`):
  - `appSetup`: `gameTitle` → `title`, `appName` → `storageName`,
    `configFileName` → `configFile`, `logFileName` → `logFile`;
  - `requestBackend`: `usedPlatform` → `platform`, `usedAPI` → `graphicsAPI`.
    The request is no longer overwritten by the resolved backend;
  - `windowSetup`: `windowWidth/windowHeight` → `size:TSize`,
    `windowedMode` → `fullscreen` (**inverted**, default false),
    `windowBorderless` → `borderless`, `windowSizeable` → `resizable`,
    `scaleWindowSize` → `scaleForDPI`, `useSystemCursor` → `systemCursor`;
  - `requestGL`: `glCoreContext` → `coreContext`, `glDebugContext` →
    `debugContext`, `glForwardCompatible` → `forwardCompatible`,
    `glPreferHighest` → `preferHighest`, `glMinVersionMajor/Minor` →
    `minMajor/minMinor`;
  - `renderSetup`: `noVSync` → `vSync` (**inverted**, default true),
    `useDepthTexture` → `depthTexture`;
  - `startupScenes`: `useConsoleScene` → `console`, `useTweakerScene` →
    `tweaker`, `useDefaultLoaderScene` → `loader`.
- `debugMode` and `checkForSteam` are plain protected fields now.
- Removed: `scaleScenes`, `scaleFonts` and `configDir` (never read),
  `useCustomStyle` (led to `NotImplemented`).
- Still global: `deviceDPI`, `deviceScale`, `instanceID`, `gameLangCode`.
- `appSetup.configFile` keeps the old `configFileName` behaviour: after
  `Prepare` it holds the bare file name used as the control file key.
  (Changed on 2026-10-23: it holds the path of the file used, see "Configs: Apus.Config".)
- Config keys (`Options\FullScreen`, `Options\scaleWindowSize`, ...) and command
  line options are unchanged.
- Migration: move the assignments from the constructor (or from the program,
  before `Create`) into `SetupApplication`. A program that runs a bare
  `TGameApplication` needs a small descendant (see `demo/01-Scenes`). Example:
  `windowWidth:=1280; windowHeight:=720;` → `windowSetup.size:=MakeSize(1280,720);`
  (`MakeSize` is in `Apus.Engine.Types`). Upgrader TODO rules added to
  `tools/engine5.upgrade`.

## 2026-10-04 — Frame signals, Steam integration migrated

- `Engine\onFrame` (the command that runs one frame where the platform owns the main
  loop: Android, iOS) is renamed to `Engine\RunFrame`.
- New notifications from the main window's frame: `Engine\Frame\Begin`,
  `Engine\Frame\BeforeRender` (only for a rendered frame), `Engine\Frame\End`;
  the tag is `window.frameNum`.
- `Apus.Engine.SteamAPI` is back from `legacy/`, rewritten for Steamworks SDK 1.65.
  The library is loaded at run time (no link-time dependency, the game runs without
  it), callbacks are dispatched manually on `Engine\Frame\Begin`. API is the `Steam`
  record: `InitSteamAPI` → `Steam.Init`, `DoneSteamAPI` → `Steam.Shutdown` (called by
  `TGameApplication`), `steamAvailable` → `Steam.available`, `steamID` →
  `Steam.userID`, `steamUserName` → `Steam.userName`, `steamGameLang` →
  `Steam.gameLanguage`, `SetSteamAchievement(name,enable)` →
  `Steam.SetAchievement`/`Steam.ClearAchievement` + `Steam.StoreStats`. New:
  `Steam.GetAchievement` (account state, available right after Init), `Steam.IsDlcInstalled`, `Steam.IsSubscribedApp`, `Steam.RestartAppIfNecessary`,
  signal `Steam\DlcInstalled`, `Steam.initResult`/`Steam.initError` (why Init
  failed: no library, no client, client outdated). Removed: `GetSteamAuthTicket` (SDK 1.57+ requires
  the asynchronous `GetAuthTicketForWebApi` for Web API checks - add it when a
  server needs it) and the raw `SteamAPI_*` imports.

## 2026-10-04 — Window lock, cross-thread entry into a window

- The window lock is the outermost engine runtime lock (level 20; window surface data
  25, the game object 30). The scene list is guarded by it: `TGameBase.AddScene`,
  `RemoveScene` and `TopmostVisibleScene` no longer take the game lock.
- The internal reentrant lock `TWindow.Lock(caller)`/`Unlock` is renamed to
  **`LockState`/`UnlockState`**. It still gives no lifetime guarantee and does not
  switch the `window` context.
- New cross-thread API of `TWindow`:
  - `Lock:boolean`/`Unlock` - worker entry: keeps the window alive, takes its lock
    and sets the thread's `window` context; false if the window is closing. Reentrant;
    `Unlock` restores the previous context and does nothing without a matching `Lock`.
  - `QueueCall(proc,param)`/`QueueCall(method)` - run a call on the window's thread at
    the start of its next frame, under the window lock. Every accepted call runs
    exactly once (at the latest while the window closes); false if closing.
  - `Acquire`/`Release` - keep a reference to the window across threads.
  - `closing`, `ownerThreadID`, `IsOwnerThread`; engine side: `BeginClose`,
    `RunQueuedCalls`, `WaitReleased`.
- The window thread holds the window lock on the frame segments that touch window state:
  queued signals, input, `OnFrame`/`Process`, scene and UI drawing. Subscribers of
  `Engine\Frame\Begin` and `Engine\Frame\BeforeRender` run under it; `Engine\Frame\End`
  (after Present) runs outside it. Present, `gfx.BeginPaint` and sleeping are outside, so
  a worker's `Lock` waits at most about one segment.
- `onClickAsync` threads (`TUIButton`, `TUIToggleButton`) start with `window` set to the
  clicked element's window (it was nil) and `TUIElement.sender` set to the element (it was
  not set). The window is kept alive until the handler returns, its lock is not held. A
  click on an element of a closing window does not start the handler.
- **`TUIElement.SafeDestroy` -> `Remove`** with new semantics: the element and its subtree
  leave the tree at once (marked `deleted`), the window's focus, mouse capture, modal and
  hotkey references into the subtree are dropped, and the memory is freed by the window's
  thread at the start of the next frame (right away if the element is not in a window).
  Callable from any thread; an element may remove itself in its own handler. Removing
  again does nothing; attaching a removed element is an ASSERT. Direct `Free` stays for
  the window's own thread outside handlers (ASSERT from another thread).
  `TUIElement.Acquire`/`Release` keep an element from being freed across threads (a held
  removed element waits); `onClickAsync` holds its button, so `onClick` may remove it.
  `DeleteChildren` now removes the children this way. `DestroyQueuedElements` takes the
  window. `Detach` builds a new `children` array, so loops over a snapshot
  (`list:=children`) survive removals made by the handlers they call.
- Hint state is window state (`TWindow.hint`): **`TUIHint.Current` -> `TUIHint.Current(wnd)`**;
  `UI.CurrentHint` reads the thread's window. `ShowSimpleHint` works from any thread under
  the window lock of the parent's window (no parent: the thread's window); a parent outside
  any window shows nothing. The cursor position comes from the window, not from the
  calling thread. Each window has its own hint; the hint element is named `_hint` (not a
  unique name).
- Keyboard focus is window state (`TWindow.focus`, it was a threadvar of
  `Apus.Engine.UITypes`): `SetFocus`, `HasFocus` and `IsActiveWindow` use the element's
  window, `FocusedElement` and `SetFocusTo(nil)` the thread's window. Focus set from any
  thread (the control thread at startup, a worker) is seen by the window. An element
  outside any window doesn't take the focus. New `ClearFocus(wnd)`.
- `underMouse`, `hooked`, `clipMouse`, `clipMouseRect` and the cursor coordinates stay
  threadvars: mouse dispatch state of the window's thread, valid in that thread only. A
  mouse captor removed from another thread is dropped by the window's dispatch
  (`DropRemovedMouseState`). The open combo box drop-down is tracked per window thread (it
  was one global).
- Each `TUIScene` keeps its own clock for element timers: a clock shared by all UI scenes
  of a thread stalled the timers of every scene processed after the first.
- A UI element enters its parent's `children` in `AfterConstruction`, after the whole
  constructor chain (it was inserted by the base constructor, before the derived fields
  were set); `UI\ItemCreated` is sent at that point too. A derived constructor still has
  `parent` set but does not find itself in `parent.children`.
- Scene effects: the engine draws an effect through `TSceneEffect.Paint` (it called
  `DrawScene` directly). A new effect created from inside the running effect's
  `DrawScene` (a handler run by the scene's `Process`/`Render`) no longer frees it
  mid-draw: the replaced effect is freed when `DrawScene` returns. An effect that changes
  scene state hands it back in `Replace` (protected, virtual), not only in its destructor,
  so the new effect starts from the restored state; `TShowWindowEffect` does this and
  skips the rest of its `DrawScene` once `replaced` is set.
- Scene shadows (`TGameScene.shadowColor`): a scene draws only the part of its shadow not
  covered by the shadows of the scenes above it, so a stack of modal scenes with equal
  shadows dims the screen with one fill (the top one) instead of one per scene; the area
  under a scene is dimmed by the strongest shadow among it and the scenes above. Scenes of
  extra windows draw their shadows too (they were skipped).
- `gfx.CopyFromBackbuffer(srcX,srcY,image)`: srcY now counts from the TOP of the surface
  (it counted from the bottom); a bound render target comes out top-down like the
  backbuffer (it came out bottom-up). The image is no longer flipped by moving `data` and
  negating `pitch`: an image can be read into repeatedly, and any pitch works.
  `TWindow.ReadFrameRect` is unchanged for callers; with `TFrameSource.rendering` and a
  presentation RT it now reads the right rows.
- Removed: the unused global "under modal" shadow - `modalShadowColor` (UIScene) and the
  `UI\SetGlobalShadow` signal.
- Removed: `FindWindowForScene` (use `scene.ownerWindow`) and `FindWindowForUIRoot`
  (use `element.GetWindow`, which resolves the window through the scene only).
- Migration: calls of the old `window.Lock`/`Unlock` in engine-level code become
  `LockState`/`UnlockState`; a worker thread that changes UI uses `Lock`/`Unlock` and
  checks the result. No upgrader rule: `Lock`/`Unlock` are too common to rename blindly.

## 2026-10-10 — Window frame drawn by the app

- `TDisplayMode.dmBorderless` removed (it was an unfinished app-drawn frame: a WS_POPUP
  window, the manual resize in `GameApp` was never implemented). The frame is a separate
  property now: `TGameSettings.frame:TWindowFrame` (`System`, `Custom`,
  `CustomWhenMaximized`), set at startup by `windowSetup.frame` (replaces
  `windowSetup.borderless`). A borderless window = `dmWindow`/`dmFixedWindow` +
  `TWindowFrame.Custom`.
- With an app-drawn frame the window keeps the standard OS style: maximizing to the work
  area of its monitor, Win+arrows, snap and the system menu keep working. The app tells
  which part of the window is the caption through `TWindow.frameHitTest`
  (`TWindowArea`: client, caption, edges); edges of a resizeable window resize it.
- `TWindow.state:TWindowState` (normal/minimized/maximized), `TWindow.Maximize`,
  `TWindow.Restore`. `ENGINE\WINDOW\MINIMIZED/MAXIMIZED/RESTORED` are sent on every
  platform (they were SDL-only), on a state change only.
- Windows: a window is centered on the work area of its own monitor (it was the primary
  one), a window maximized before switching to fullscreen is maximized again on return.
- SDL: the window is made borderless (`SDL_SetWindowBordered`, also on maximize/restore for
  `CustomWhenMaximized`), the caption and edges come through `SDL_SetWindowHitTest`, size
  limits through `SDL_SetWindowMinimumSize`/`MaximumSize`.
- `TUIWindow.BindToWindow` makes a UI window the frame of its OS window: it fills the scene,
  its own area in the top `header` units is the caption (opaque children there stay
  clickable, transparent ones let the caption through), `minW..maxH` limit the OS window
  (through `TWindow.sizeLimits`). The drawer paints only the body: the caption row is up
  to the app.

## 2026-10-11 — Dead optional paths removed

- Video capture removed: `TGameBase/TGame/TWindow.StartVideoCap`/`FinishVideoCap`,
  `TFrameCapture.videoMode`/`videoPath` and the `VIDEOCAPTURE` define (its unit
  `Apus.Engine.VideoCapture` was gone long ago). Use an external recorder.
- TXT images removed: `LoadTXT`, `TImageFileType.ifTXT` and the `TXTIMAGES` define (the
  path didn't compile and its fonts were never created). `CheckImageFormat` no longer
  reports text data as an image.
- `GLintptr`/`GLsizeiptr` in `extra/dglOpenGL.pas`/`dglOpenGLES.pas` are `NativeInt`
  (pointer-sized, as Khronos defines them; they were 32-bit). `PGLchar` in dglOpenGLES is
  `PAnsiChar` (the GLES renderer compiles with Delphi).

## 2026-10-17 — Sharp text on a canvas scaled by the projection

When the canvas is smaller than the render surface (fixed canvas in the `sharp` mode, the
`matrix` mechanism), the projection scales every 2D call up. Text used to be rasterized
in canvas pixels and stretched; now it is laid out and rasterized in real pixels.
Nothing changes when the canvas matches the surface (the ratio is 1).

- `IRenderTarget.pixelRatio` - real pixels per virtual pixel of the current target.
- `txt.Write*`, `Width`, `Height`, `Measure`, `MeasuredRect`, `LinkRect` keep working in
  canvas units; the font is rasterized at its size times the ratio.
- `DrawTextFX`: layer sizes (`dx`, `dy`, `spread`, `blur`) are in virtual pixels of the
  target, like the text coordinates (they used to be real pixels, which is the same at
  ratio 1). A scaled canvas bakes the sprite in real pixels.

## 2026-10-17 — Logical canvas

- `TSurfaceConfig.canvasDPI` (flexible canvas only): DPI of the canvas grid. 0 (default)
  = one canvas unit per display pixel, as before; N>0 = a unit is 1/N inch, the canvas is
  the display rect divided by `dpi/N` and the projection scales it (`matrix`). Rejected
  with a fixed or half-fixed canvas.
- `TGameApplication.SetupLogicalCanvas(dpi=96)` - preset: the canvas follows the client
  area in logical pixels, so the same numbers give the same physical size on any display.
  `game.screenScale` stays 1 there (the projection does the scaling), like over a fixed
  canvas.

## 2026-10-17 — Assertions are on in FPC builds

FPC compiles `ASSERT` out unless `-Sa` is given, and no engine build had it. `build.cfg`
and every test/smoke script now pass `-Sa`. A project that wants a build without
assertions adds `-Sa-` to its own options.

## 2026-10-18 — Pixel grid of the 2D primitives on a scaled canvas

When the projection scales the canvas (`pixelRatio`>1), a virtual pixel is a cell of real
pixels. Fills and images cover whole cells; what is thinner than a cell places itself on
real pixels. Nothing changes at ratio 1 (checked by `tests/TestPixelGrid`).

- `draw.Line`: a hairline at coordinate c lies on the first real pixel of the cell.
- `draw.Rect`: the frame lies on the outer real pixels of its cells, so it matches
  `FillRect` with the same corners. Drawn as one-pixel strips instead of a line loop (not
  between `BeginLines`/`EndLines`).
- `draw.RRect` without width: moved outwards the same way. `draw.RRect` with width: its
  outer edge is the edge of `FillRRect` with the same arguments (the radius was 0.4 larger
  and the arc had fewer segments, so the fill showed outside the frame at the corners).
- Rounded corners: the default number of arc segments follows the radius in real pixels;
  an explicit `steps` is clamped to 1..16 (a larger one used to overrun a stack buffer).
- `draw.ShadedRect`: each depth step is one virtual pixel wide at any ratio (drawn with
  bands instead of lines); the same pixels at ratio 1.

## 2026-10-18 — Default fonts grow in proportion to the DPI

`game.defaultFont`, `smallFont` and `largerFont` grow in proportion to the canvas DPI
(`7.376*dpi/96`), like `Dp()` and a logical canvas. They used to grow slower
(`2+0.056*dpi`): the same size at 96 DPI, 14% smaller at 192 DPI, so layouts built
with `Dp()` had too much room for the text.

## 2026-10-18 — Face culling is the same in render targets

The projection flips Y for the backbuffer but not for a texture target, which mirrors
the winding, while the GL front face was fixed at CCW: `TCullMode.DrawCCW` kept the back
faces in a render target (3D into an RT, a frame through the presentation RT, scene
transition effects). The GL backend now switches the front face with the target, so a
`TCullMode` keeps the same faces everywhere (`tests/TestCulling`). Code that compensated
for it (e.g. `DrawCW` for 3D into an RT) has to go back to the normal mode.

## 2026-10-19 — Music loop points

- `TPlaySettings.loopStart/loopEnd` are `double` seconds of the media file,
  `loopEnd=0` = the end of the file (were `single` with no stated unit and
  ignored by the SDL backend). Seconds stay valid when a file is resampled;
  double keeps a sample position exact.
- Music entries of the sound config take the loop start in one of two keys:
  `loopTime` in seconds, or `loopPos` in samples of the file - the unit of the
  original Engine 2/IMX configs, which therefore work unchanged (verified on
  Spectromancer tracks: the audio before `loopPos` matches the end of the track
  at offset 0). `loopTime` wins when both are given.
- SDL backend: a looped track with a loop region is decoded whole once and played
  on a reserved mixing channel (the loop is sample-exact); other music still
  streams through `Mix_Music`. One music stream at a time as before.

## 2026-10-19 — Sound API: ISoundSystem, pitch, procedural sound

- The game-side sound API is the `ISoundSystem` interface, the global `sound`
  (always assigned: without a backend or before `Init` the calls do nothing):
  `InitSoundSystem`/`DoneSoundSystem`/`IsMusicPlaying` -> `sound.Init`/`Done`/
  `IsMusicPlaying`. Besides them it has direct calls for what the `Sound\...`
  events do (`Play`, `PlayMusic`/`StopMusic`, `PlayFile`/`StopFile`/`StopGroup`/
  `SetGroup`, `ClearCache`, `SetVolume`, `Pause`), procedural sound (`PlayStream`)
  and control of a playback by its handle: `SetChannelVolume/Pan/Speed` (with an
  optional slide time), `StopChannel`, `IsPlaying`. The events stay as they were.
- Calls from any thread return at once: they are queued to the sound thread, and
  a playback handle is given out before the playback starts.
- `TSoundStreamProc` generates a procedural sound in the audio thread (float
  samples, the rate is passed in); the contract is in its comment.
- SDL backend: samples, streams and looped music play through the backend's own
  mixing (a channel effect over a silent carrier), so samples get pitch: the
  `speed`/`freq` of the config and of `Sound\Play`, which were ignored by the SDL
  backend before, now apply - data with `speed`<>1 sounds the way it did in Engine 2.
  At speed 1 a sample plays bit-exact as before.
- `PlayMusic` transitions are three times in seconds (fade-out, start delay,
  fade-in); the tag presets 0..6 of `Sound\PlayMusic` map onto them. The start
  position (`fromPos`, the high bits of the tag, `Sound\MusicPos`) was stored but
  never used - now the track starts from it. `PlayMusic\None` (or a missing
  track) also cancels a track that waits for its start.
- `Sound\Change\...` (a stub that did nothing) is removed.

## 2026-10-23 — Configs: Apus.Config

- New `Apus.Config` (`manual/config_files.md`): documents in the CTL3 syntax (braced
  sections, arrays, inline comments); CTL2 files and a JSON subset are read by the
  same parser. The engine reads its configs through it; `Apus.ControlFiles` is still
  in Base, but nothing in the engine opens files with it any more.
- `Apus.Engine.GameApp`: the global `appConfig:TConfig` is the document of
  `appSetup.configFile`: `Prepare` opens it, `SaveOptions` saves it, it is freed with
  the application (nil without a config file). After `Prepare`, `appSetup.configFile`
  holds the path of the file used (the copy in `AppDataDir` when the shipped one must
  stay intact), no longer the bare name used as a control file key. The keys are
  unchanged and case-insensitive: `appConfig.Root.Int('Options.WindowWidth',1024)`.
- Config problems are not fatal, but noticeable. `TConfig.Create` never raises on the
  file: a missing or broken file gives an empty document (the defaults), `LoadError` and a
  report; such a file is not overwritten by `Save` and is picked up by `ReloadIfChanged`
  once fixed. Every problem (a failed load, reload or save, a value that does not
  convert, a write the content does not allow) is logged and passed to `onConfigProblem`;
  GameApp shows it as a toast. `Reload` and `Save` are functions returning success.
- `SetFloat(path,value,digits=5)` writes 5 significant digits by default; `digits=0`
  gives the shortest form that reads back exactly.
- `Apus.Engine.GameApp`: a missing `appSetup.configFile` is no longer a `FatalError`: the
  defaults are used, a toast says so, and `SaveOptions` creates the file.
- `Apus.Engine.Sound`: an event may also be a section,
  `sampleQuiet = { file = "sample.ogg", vol = 30 }`; `PreloadSamples` may be an array
  of files; a missing `PreloadSamples` means `NONE` (it was a config loading error).
  A broken event is reported and skipped; a config error no longer fails the sound
  initialization.
- `Apus.SCGI`: reads `config.ctl` through `Apus.Config`; the file is unchanged.
- Data files: CTL2 files keep working. A CTL2 file that the program saves is written
  in the CTL3 syntax. Duplicate keys in a file are an error now (CTL2 silently kept
  the last one); `$Include` merges the file into the including section (in CTL2 the
  included file was a separate namespace).
- Migration of game code: `ctlGetInt(appSetup.configFile+':\Options\X',d)` →
  `appConfig.Root.Int('Options.X',d)`; other files: `cfg:=TConfig.Create(name)` and
  `cfg.Root.Str('A.B',...)`. The full table is section 13 of the manual chapter;
  upgrader TODO rules are in `tools/engine5.upgrade`. The demo configs use the CTL3
  syntax now.

## 2026-10-22 — Window close request: the app may keep the window

- The OS close button, Alt+F4 and the OS quit command (SDL `SDL_QUIT`, e.g. Cmd+Q)
  no longer close the window at once: they call `TWindow.RequestClose`, which sends
  `ENGINE\WINDOW\CLOSEREQUEST`. A handler that wants to ask the user calls
  `window.ClosePending` right away (instant handler, window's thread) and the window
  stays; the app later closes it with `window.Terminate` (main window: as
  `Engine\Cmd\Exit`). Without `ClosePending` the window closes as before.
- The app's own close button should call `window.RequestClose` too, so it asks the
  same way; `Terminate`/`Engine\Cmd\Exit` close without asking.
- `ENGINE\WINDOW\CLOSE` (SDL only, sent when the window was already closing) is
  removed: use `ENGINE\WINDOW\CLOSEREQUEST`.

## 2026-10-26 — Console publication of UI elements: the full field list

- `Apus.Publics`: `TVarTypeStruct.ListFieldsOf(variable)` returns the fields of this
  particular variable (by default `ListFields`); `TVarTypeStruct.GetValue` lists them.
- `Apus.Engine.UIScript`: the published fields of an element are one table.
  `ListFieldsOf` gives every field the element has, its widget's fields included;
  `ListFields` gives the fields any element has. `?name` in the console prints all of
  them (it was 8 fields).
- `parent` and `children[i]` are element references: their value is `TClass('name')`
  (`nil` without a parent), their fields work as before (`btn.parent.width=120`),
  assigning to the reference itself is an error.
- Enumerated fields list their values (`TVarTypeEnum.ListValues`): `align`,
  `transpmode`, `signals`, `pivot`.

## 2026-10-26 — UI inspector (debug builds)

- New `Apus.Engine.UIInspector`: a separate window with the UI tree of another window
  and the published fields of the selected element, read and edited live. GameApp links
  it only with `DEBUG` defined (`-dDEBUG` for FPC); open it with Ctrl+Shift+I in the
  window to inspect, or with the console command `inspector`. Closing the inspector
  window hides it.
- `Apus.Engine.UIScript`: `TVarTypeUIElement`, `TVarTypeElementRef` and
  `TVarTypeElements` are in the interface section.
