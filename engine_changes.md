# Engine changes

Changes of the engine (`Apus.Engine.*` modules in the repository root, platform layers, build
scripts) that affect code written for an earlier engine: renames, removed API, changed
behaviour. Newest first. The Base library (`Base/Apus.*`) has its own list:
[`Base/engine5_changes.md`](Base/engine5_changes.md); `tools/engine5.upgrade` rewrites the
mechanical renames of both.

## UI: edit box mouse selection follows a fast drag; `selectOnClick` (2026-11-05)

- A mouse selection in `TUIEditBox` ends at the last mouse position before the frame, also
  outside the box: the press captures the mouse (`hooked`) until the release. Before, a fast
  drag stopped at an early position (often one character), leaving the box ended it.
- The drawer turns mouse x into caret positions: `needPos` (the caret) and the new `needAnchor`
  (the press), then calls the new `MouseCaretPlaced(anchor,caret)` (-1 - not pending). A custom
  edit box drawer that set `cursorPos` from `needPos` itself must do the same, or the mouse
  selects nothing.
- New `TUIEditBox.selectOnClick` (default false): a click that gives the focus selects the whole
  text, a drag from it still selects a part; a click in the focused box places the caret. The
  focus from the keyboard selects all as before.

## 3D: FOV axis for `Perspective` (2026-11-04)

- `gfx.transform.Perspective(fovRad,axis,zMin,zMax)` with `TFovAxis` (`Apus.Engine.Types`):
  `larger` (what `Perspective(fovRad,zMin,zMax)` always did), `horizontal`, `vertical`,
  `diagonal` - corner to corner, the same angle keeps its meaning on a normal, ultrawide or
  tall target. `FovExtents(fovRad,aspect,axis,x,y)` gives the half extents at distance 1
  (the frustum the overload builds) for code that converts between the axes itself
  (Racing RQ-34).

## Text: the default `FitText` ellipsis is right in any caller (2026-11-04)

- `txt.FitText` without the `ellipsis` argument is now its own overload, and the ellipsis
  `…` (U+2026) is built inside the engine. The old non-ASCII default parameter value was
  converted by FPC in the caller's source codepage, so a caller unit without a UTF-8 BOM got
  6 mangled bytes ("â ¦") instead of `E2 80 A6`. Calls compile as before; a passed `'…'` is
  treated as the default one (`'...'` for a font without that glyph). Rule for engine API: no
  non-ASCII string literals as default parameter values (PaintRaw E-43).

## Window: the final frame output keeps the source pixels at an integer scale (2026-11-04)

- The default render target goes to the window through the new `BlitScaled(tex,dest,color)`
  (`Apus.Engine.Window`). Along an axis where the output is exactly k times the render target
  (integer k>=2, e.g. `SetupFixedCanvas(1024,768,TFixedCanvasRender.cheap)` in a 2048x1536
  window), every k-th output pixel is a source pixel as is and the pixels between are
  interpolated: a line profile `0,255,0` becomes `0,128,255,128,0` (was `0,64,191,191,64,0`).
  The picture moves by half an output pixel up and left relative to the old output; the last
  k-1 columns/rows repeat the last source pixel. Fractional scales and 1:1 are unchanged.
  Checks that pinned the old profile need the new values (SpectroDev B-53).
- The default render target clamps UV (`aiClampUV`): the output no longer mixes the opposite
  edge into the edge pixels of the frame, at any scale.

## Scenes: `onBeforeShow`/`onShow`; a show of a hiding window scene waits for the hide; effects of undrawn and extra windows (2026-11-04)

- `TShowWindowEffect` (also `ShowWindowScene`): a show requested while the scene still hides
  is no longer ignored ("SWE for active scene IGNORED!"): it starts when the hide ends. A hide
  requested before that calls it off. The scene state of such a show (activation, modal stack,
  focus) comes later, not at the call.
- A window that is not drawn (minimized; inactive in `dmSwitchResolution`) ends the effects at
  once instead of holding them until it is drawn: shows, hides and screen transitions apply
  their final state. An effect without one (`TBlurEffect`) keeps running. New
  `TSceneEffect.Finish`/`DoFinish` (override to apply the final state), `TWindow.ProcessEffects`.
- Extra windows (`AddWindow`) play the effects: before, their timers never advanced, so a show
  or hide in such a window never ended.
- `TGameScene.onShow` now comes after the scene became active: its UI is shown, a modal one
  is on the modal stack, the focus can be set (a show effect calls it after the modal push;
  a show that waits for a hide - when it starts). The old `onShow` (before the activation,
  the scene not active yet) is `onBeforeShow`: rename an override that relies on that.
- `SetStatus` is not virtual any more: a scene class overrides `ApplyStatus` (called by
  `SetStatus`, also without a change; call inherited). `TUIScene`, `TConsoleScene`,
  `TTweakerScene` did so. An override of `SetStatus` fails to compile.
- The default switcher (`ShowWindowScene`/`HideWindowScene`) fades the window in and out:
  its effect drew nothing for 250 ms. `TFileDialogScene` fades too (150/120 ms) instead of an
  instant show and hide; it sets the focus in `onShow`, and opening it again while it hides
  shows it after the hide.
- A window scene gets no input while its show or hide effect plays (as before): a Robot API
  click that comes right after the dialog appears and before the fade ends is lost. Wait for
  the end of the effect (`ui.hittest` finds the dialog) before clicking.
- `ENGINE\EffectDone` comes after the effect is freed and `scene.effect` is `nil` (was: before),
  so a handler may start a new effect of the scene.

## Robot API: a `-ROBOT=VIRTUAL` window stays under the active window (2026-11-04)

- On Windows a window driven by the robot is placed right under the active window of the user
  when it is shown and when its state changes (normal, maximized, minimized, mode changes),
  not on top: a maximized window no longer covers the terminal it was started from. The
  activation was already kept. Not for a topmost active window, the desktop or a window of
  the application itself. `screenshot` and `pixel` of a covered window are unaffected.
- Under `-SDL` the window is still shown on top.

## Text: `Advance`, `PenPositions`, tabular digits, `WrapText`, `FitText` (2026-11-03)

- `ITextDrawer` has the second metric of a text: `Advance`/`AdvanceW` - the pen advance (where
  a next text starts), additive up to the kerning at the junction. `Width` stays the visible
  text (ink), not additive.
- `PenPositions(font,st32,pos)` - the pen before each character and after the last one,
  relative to x of `Write`. The edit box takes its caret, hit-test and selection from it
  instead of a `toMeasure` pass: the caret at the end of the text now stands at the pen (was
  at the ink edge), the completion goes on from the pen. The selection highlight spans the
  font's line like the caret (was the whole box height, over the frame).
- Tabular digits: `fsTabularDigits` (`GetFont`) / `toTabularDigits` (`Write`). Digits take
  cells of the widest digit advance, centered; a digit at an edge counts by its cell, so a
  right-aligned or centered number doesn't move when its digits change (with Open Sans,
  whose digit advances are already equal, `Width('1:11')<>Width('8:88')` without the flag).
- `WrapText` (optionally with the width of each line) and `FitText` with
  `TTextCut.atEnd/atStart/atMiddle` (`Apus.Engine.Types`); the default ellipsis `'…'` falls
  back to `'...'` without that glyph. Punctuation right after a word is a part of it: when a
  word wider than the line is broken between characters, no line starts with such a mark (a
  letter goes with it). `Notifications` wraps toasts with `WrapText`: a word
  longer than the line is now broken between characters. Networking demo `FitWidth` ->
  `txt.FitText`.
- `TTextDrawer.HasGlyph`. The font objects got `Advance`, `InkRight`, `HasGlyph` (Base).
- Fixed: measuring without drawing (`toMeasure or toDontDraw`) gave per-character positions
  shifted by the bearing of the first glyph.
- `TTextDrawer` allocates its GPU buffers at the first flush: metrics and layout work
  without graphics (`tests/TestTextMetrics`).
- Showcase: TextDemo screen 10 (`Wrap & Fit`) - `WrapText` and `FitText` against a moving
  boundary; hovering a stand drives the width with the mouse.

## Scenes: exact `Process` frequency on `TStepClock` (2026-11-03)

- `TGameScene.accumTime` -> `clock:TStepClock`: a scene with `frequency>0` gets `Process`
  exactly `frequency` times per second. In `Render`, `clock.Alpha` is the share of the next
  step for interpolation. The first call comes at once after the scene is added or
  `frequency` changes.
- Fixed with it: the step was `1000 div frequency` ms (60 Hz gave 62.5 calls per second), the
  frame time was taken in whole ms (~13% lost at 144 FPS), and the time left after 6 calls in
  one frame was silently dropped (now: one long frame counts as at most 100 ms).
- `TWindow.ProcessScenes(deltaUs:int64)` - frame time in microseconds (was ms).

## Mesh: `Append` attribute set, `MeshOps.Transform`, `MeshOps.SetColor` (2026-11-03)

- `TMesh.Append`:
  - an empty mesh takes the attribute set of the first appended part (it kept only the
    positions: callers had to start from a copy of the first part);
  - a part without colors appended to a mesh with colors gets white (was 0, transparent black);
    any other attribute the target has and the part lacks is an `ASSERT` (zeros in release);
  - normals are transformed by the inverse transpose of the linear part (were rotated by the
    linear part itself: wrong under a non-uniform scale); a mirroring matrix flips the
    triangle winding and the tangent `w` of the appended part.
- `MeshOps.Transform(mesh,m)` - the same transform of a whole mesh in place.
- `MeshOps.SetColor(mesh,color)` - one vertex color for the whole mesh: white parts tinted
  with `shader.Material` give one GPU mesh drawn in many colors.

## UI: hotkeys set in any thread work in their window (2026-11-03)

- `TUIElement.SetHotKey` registered the hotkey in a threadvar list of the calling thread,
  `ProcessHotKey` looked only into the list of the window thread. A scene is built by the
  control thread, so every hotkey set in a scene constructor was silent: Enter/Escape of the
  `MessageScene` dialogs (`Ask`, `ShowMessage`, `Confirm`) never fired. An element freed in
  another thread left its entry behind.
- Now one list of all windows under a leaf lock; `ProcessHotKey(wnd,keycode,shiftstate)` takes
  the window and fires only the hotkeys of its elements.
- Game code: hotkeys may be set anywhere, including scene constructors; a workaround that sets
  them later from the window thread is no longer needed.

## UI: parts of an element, default tokens, PixelWidth (2026-11-02)

- Parts: a nested block in the style text, `header { fill: ...; :hover { ... } }`, is a style
  block of its own (keys, `@refs`, state blocks) in `TStyleBlock.parts` (`Part(name)`).
  `ResolvePartAttr(block,part,state,key)` looks in the part block, then in the parts of the
  `@refs` (the element's part wins by keys); the old prefixed keys (`header-fill`,
  `row-hover-fill`) are aliases. `TUIElement.GetPartStyleValue`, `GetBlendedPartColor/Number/Fill`
  (the drawer gives the part its states by weights) and the DefaultStyle overload
  `ResolveStyleBox(element,part,rect,weights,box)`. Box keys come from the part only; typography
  falls back to the element.
- Tokens have a default layer: `SetDefaultToken(name,value)` is used while neither the theme nor
  the application has the name, and survives `ApplyTheme`/`ClearTokens`. The file dialog sets its
  `file-dialog-*` tokens there: a theme swap no longer drops them (PaintRaw E-32).
- `TUIElement.PixelWidth(w)`: a line width in logical units -> canvas pixels landing on whole
  physical pixels (`gfx.target.pixelRatio`), at least one for `w>0`.

## UI: the style box of an element, blended values (2026-11-02)

- `TBlendedFill` (Apus.Engine.Types, the former private `TFillSlot` of DefaultStyle): a fill
  under state blending - the base mixed with every state fill `TFill.Mix` can mix, cross-fade
  layers for the others (`Layer(i)` gives one at its weight).
- `TUIElement.GetBlendedStyleColor/Number/Fill`: the value as it is drawn now, the base blended
  toward the states of `BlendStates` (built-in ones by their weights in priority order, then
  the active custom ones). Equal to `GetStyleColor/Number/Fill` when no transition runs; an
  inherited key follows the parent's blended value.
- DefaultStyle: `ResolveStyleBox(element,box)` gives the box as it is drawn now (`TStyleBox`:
  rect, radii, border width, fill, border, shade, shadow, background images, all in pixels;
  `ContentRect` - the box deflated by the widest border of all states, so content does not
  move on `:focused` with a thicker border); `DrawStyleBox(box,layers)` draws it, all of it or
  only the shadow, the background or the border; `DrawElementBox(element)` - both plus the
  inner block in one call, for a custom drawer. They use the style only: the default fill,
  shade and derived state colors of a plain button stay in the default drawer.
- `box-shadow` takes an optional fifth value, the spread.
- A fully transparent border is no border: it no longer cuts the fill.
- The resolver gives the state priority first: of two active states the later one wins,
  whether its block is local or comes from a `@ref` (a local `:hover` no longer beats a
  `:disabled` from a ref).
- The file dialog draws its buttons with `DrawElementBox`; its styles use state blocks
  (`:hover`, `:checked`, `:pressed`, `:disabled`) instead of `hover-fill`, `checked-fill`,
  `pressed-fill`, `checked-color`, `hover-color`; the accept button has its own style instead
  of the `default-` keys.

## UI: element states with a priority, `:checked` apart from `:pressed` (2026-11-01)

- Built-in states are `TElementState` (scoped: `Focused, Hover, Checked, Selected, Pressed,
  Disabled`), in priority order: a later state wins where both declare a key. An element
  reports them by `GetStates` (virtual: `TUIButton` adds `Pressed`, `TUIToggleButton`
  `Checked`); `DrawUIElement` calls `UpdateVisualState` before any drawer: the states go into
  `style.activeStates` in that order (custom `SetState` ones after them), so `GetStyleColor`
  and the blending drawers agree whatever order the states came in.
- Transitions live in `element.visualState` (`TUIVisualState`, created on the first draw);
  `element.StateWeight(TElementState.Hover)` gives the progress. The default drawer's
  `TContext` no longer has `hover/active/disabled` tweens. A drawer called directly (not by
  `DrawUIElement`) calls `UpdateVisualState` first, or the weights are 0/1 by `GetStates`.
- Transition times: `<state>-time`, `<state>-time-in`, `<state>-time-out` (ms) for any built-in
  state; `press-time`/`release-time`, `disable-time`/`enable-time` remain as aliases with a
  lower priority. Defaults: hover 50 in / 250 out (was 120/80), pressed and checked 120/80,
  the others instant. A reversed transition takes its part of the time.
- A toggled `TUIToggleButton` (a checkbox, a radio button) is `:checked`, not `:pressed`:
  style it with `:checked { ... }`. By default it looks as before (the derived darker fill,
  the pressed caption shift); `:pressed` now means the mouse is held on it.
- `TStyleBlock.SetState(name,false)` keeps the order of the other active states.

## UI: scroll bars over the rows of a table, a slider that widens under the mouse (2026-11-01)

- `TUITable.overlayScrollbars`: the scroll bars lie over the rows and take no room from them
  (`RowsWidth`, `RowsHeight`); the horizontal bar stops before the vertical one.
- The flat scroll bar: `track-width`, `slider-width` and `track-color` follow `:hover`
  smoothly, dragging keeps the hover values, so a narrow slider can widen under the mouse
  (`slider-width:0.4; :hover { slider-width:0.9 }`). The element keeps its size: only the
  drawing changes. `slider-align:end` puts a narrow slider and track at the far edge, where
  the widest slider ends.

## UI: Tab leaves elements with children, `:focused` boxes (2026-11-01)

- `SetFocusToNext` stopped on the element itself when it climbed back from its children: a
  focusable element with children (a `TUITable` with its scrollbars) kept the focus on every Tab.
  Returning to a parent is no longer a step.
- Tab and Shift+Tab skip elements whose ancestors are hidden or disabled (`IsVisible`,
  `IsEnabled`), not only those hidden or disabled themselves. The UI of an inactive scene is
  disabled, so Tab does not enter it.
- The `focused` state is synced by `DrawUIElement` before any drawer, custom drawers included
  (it was set only by the default drawer), so `GetStyleColor` sees `:focused` blocks everywhere.
- The common box path applies `:focused { fill; border-color; border-width; radius; fill-shade }`
  instantly, before hover, pressed and disabled. A focused edit box or table can now show a
  frame from its style.
- The common box path checks "nothing to draw" after the state blends: a box that exists only
  in a state block (`:focused { border-color }` on an element without a base frame, or a
  `:hover` fill) is drawn.

## UI: the completion of the edit box follows the text (2026-10-31)

- `TUIEditBox.completion`: any change of the text drops it (typing, deleting, undo, `text:=`
  with another value), `onChange` runs after that and sets a new one. `realText:=` doesn't
  drop it, but a completion that no longer fits is not drawn and not accepted.
- New `TUIEditBox.HasCompletion`: the completion continues the text (letter case aside), the
  caret is at the end, nothing is selected. Only then it is drawn and Enter takes it; in other
  cases Enter works as with no completion.

## 9-patch: cells with thin content are not lost (2026-10-31)

- `TCustomNinePatch` looks for visible pixels in the whole cell, not in every 4th pixel: a 1 px
  cell or a dot off that lattice made the cell "empty", and it was not drawn.
- Tiled patches: a resizeable range shorter than 16 px is scaled up and repeats with a step of
  16 px. A range of 1 px crashed with a division by zero, a short one gave a huge mesh.

## Robot API: `-ROBOT=VIRTUAL`, no modal boxes under the virtual input (2026-10-31)

- New command line parameter `-ROBOT=VIRTUAL`: the Robot API is on, windows are in the
  virtual input from their creation (`robotDriven` in `Apus.Engine.Window`) and on Windows
  never take the activation: showing, maximizing, restoring, minimizing and mode changes keep
  it. See "Run without a user" in `robot_api_protocol.md`.
- The engine counts the windows in the virtual input in `unattendedCount` (`Apus.Core`):
  `SystemMessage` shows no message box then, so a modal box no longer stops a robot run; `-ROBOT=VIRTUAL` adds one for
  the whole process. `InitSound` shows no message then either.

## Message dialogs: the queue waits for the closing effect (2026-10-31)

- `Apus.Engine.MessageScene`: the next queued message starts on `ENGINE\EffectDone` of the
  closing window instead of a 200 ms timer. With slow frames or a minimized window the
  effect took longer, and the message stayed in the queue until the next `ShowMessage`,
  `Ask` or `Confirm`. The `UI\Message\Next` signal is gone.

## UI: event methods of the button and the edit box (2026-10-30)

- `TUIButton.onClickMethod:TObjProcedure`, also in `TUIToggleButton`: `onClick` for a method,
  under the same conditions (`pending`, the double-click guard, `sendSignals`), after the
  other handlers.
- `TUIMenuItem.handler` -> `onClickMethod` of `TUIButton`.
- `TUIEditBox.onChange`: the user changed the text; assigning `text`/`realText` doesn't call
  it. `TUIEditBox.onEnter`: Enter with no modifiers; a handler consumes the key, and the
  Enter that accepts a completion doesn't call it.
- `TUIEditBox`: typing over a selection now sends `UI\<name>\changed` and keeps the text
  for undo.

## Window: Alt+Enter switch, return from fullscreen, window.state (2026-10-29)

- `windowSetup.altEnter` (`TWindowSetup`, default `true`) → `TGameSettings.altEnter`: `false`
  turns off the built-in [Alt]+[Enter], the app assigns its own keys and calls
  `game.SwitchToAltSettings`. Internal hotkeys that fired don't reach the scenes any more.
- Leaving fullscreen returns the window to the rect it had before (was: centered with the
  settings size), maximized as before; on SDL the window keeps the geometry SDL restores.
- Robot API: `window.state [STATE=normal|maximized|minimized|fullscreen|windowed]`, and the
  `state` field in `windows` (`robot_api_protocol.md`).

## Cursor handles are pointer-sized (2026-10-29)

- New `TCursorHandle=NativeUInt` (`Apus.Engine.API`): native cursor handles in
  `ISystemPlatform.GetSystemCursor/LoadCursor/SetCursor/FreeCursor` and
  `TGameBase.RegisterCursor/GetCursorForID` (were `THandle`). An SDL cursor is a pointer, and
  `THandle` on Unix is a 32-bit file descriptor, so the cursors broke on Linux x64.
- Game code: keep cursor handles in `TCursorHandle` variables, not `THandle`/`cardinal`.

## Non-ANSI paths: the application log (2026-10-28)

Paths under FPC on Windows lost characters outside the ANSI code page; the Base part of the
fix (`Env`, `Files` name parts, `Logger.UseLogFile`) is in `Base/engine5_changes.md`.

- `TAppSetup.logFile` (`appSetup.logFile` of `TGameApplication`) is `String8` (was `string`).
- `TGameApplication.Prepare`: the previous log is renamed to `.old` even when an old `.old`
  exists (on Windows the rename used to fail and the previous log was lost).

## UI: `TUITable` (2026-10-26)

- New module `Apus.Engine.UITable`: `TUITable`, rows of text cells under a header of columns
  (caption, width, alignment, sort mode; width 0 shares the room the fixed columns leave).
  A header click sorts by the column, the second click reverses. `tsText` compares texts
  case-insensitively with digit runs as numbers (`NaturalCompare`), `tsKey` - by the cell key
  (sizes, times). Rows keep their group first in either direction (folders above files),
  equal rows keep the order of adding, the selection follows the row.
- Single selection, the mouse wheel and the built-in vertical scrollbar; double click or
  Enter activates a row. Keys Up, Down, PgUp, PgDn, Home, End, Enter work with the focus on
  the table and, with `keyScope` set, with the focus anywhere inside that element (an edit box
  of the same dialog).
- Events `onSelect`, `onActivate` (methods) and signals `UI\<name>\Selected`,
  `UI\<name>\Activated` with the row tag.
- Drawn by the default style (`DrawUITable`): style keys `header-fill`, `header-hover-fill`,
  `header-color`, `line-color`, `row-alt-fill`, `row-hover-fill`, `selection-fill`,
  `selection-color`, defaults from the palette tokens. Page "Table" in `demo/UILab`: the
  current folder through `Folder.ListItems`.

## UI: `TUIToolButton`, button focus by class attribute (2026-10-26)

- New `TUIToolButton` (`Apus.Engine.UIWidgets`, alias in `Apus.Engine.UI`): a `TUIButton`
  that never takes the focus, for toolbars and menu owners. A click leaves the keys where they
  were: an edit box keeps typing, closing a menu returns the focus there.
- `TUIButton` keeps taking the focus on click, but now reads the default from the class
  attribute, like other elements: `TMyButton.SetDefault('canHaveFocus',false)` changes it for a
  class and its descendants (`TUIButton.SetDefault(...)` for all buttons of an app).
- Delphi only: class attribute defaults `false`, `0` and `''` (`SetDefault`) were dropped by
  `TVarHash` (Base); now they take effect, e.g. `TUIComboBox` no longer handles the mouse
  while disabled (as under FPC).

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

## Console publication of UI elements: the full field list (2026-10-26)

- `Apus.Engine.UIScript`: the published fields of an element are one table.
  `ListFieldsOf` gives every field the element has, its widget's fields included;
  `ListFields` gives the fields any element has. `?name` in the console prints all of
  them (it was 8 fields).
- `parent` and `children[i]` are element references: their value is `TClass('name')`
  (`nil` without a parent), their fields work as before (`btn.parent.width=120`),
  assigning to the reference itself is an error.
- Enumerated fields list their values (`TVarTypeEnum.ListValues`): `align`,
  `transpmode`, `signals`, `pivot`.

## UI inspector in debug builds (2026-10-26)

- New `Apus.Engine.UIInspector`: a separate window with the UI tree of another window
  and the published fields of the selected element, read and edited live. GameApp links
  it only with `DEBUG` defined (`-dDEBUG` for FPC); open it with Ctrl+Shift+I in the
  window to inspect, or with the console command `inspector`. Closing the inspector
  window hides it.
- `Apus.Engine.UIScript`: `TVarTypeUIElement`, `TVarTypeElementRef` and
  `TVarTypeElements` are in the interface section.

## Deprecated wrappers removed (2026-10-23)

- `Apus.Engine.UI`: `FindControl`, `FindControlAt`, `FindAnyControlAt` are gone;
  use `FindElement`, `FindElementAt`, `FindAnyElementAt`.
- `Apus.Engine.API`: `TGraphicsAPI.gaOpenGL` (fixed-function GL) is gone; the
  enum is `(gaAuto, gaOpenGL2)`.

## Image preload queue: workers on `Thread.Start` (2026-10-23)

- `Apus.Engine.ImgLoadQueue` launches its loading and unpacking workers through
  `Apus.Threads.Thread.Start` and tracks them as `IThread`; the `Classes.TThread`
  subclasses are gone. The public API (`StartLoadingThreads`, `QueueFileLoad`,
  `GetImageFromQueue`) is unchanged.
- The loading worker now checks for termination while waiting for an empty queue,
  so shutdown no longer hangs when threads were started but nothing was queued.

## Configs: the engine reads them through `Apus.Config` (2026-10-23)

The format and `TConfig` (`Apus.Config`) are in `Base/engine5_changes.md`.

- `Apus.Engine.GameApp`: the global `appConfig:TConfig` is the document of
  `appSetup.configFile`: `Prepare` opens it, `SaveOptions` saves it, it is freed with
  the application (nil without a config file). After `Prepare`, `appSetup.configFile`
  holds the path of the file used (the copy in `AppDataDir` when the shipped one must
  stay intact), no longer the bare name used as a control file key. The keys are
  unchanged and case-insensitive: `appConfig.Root.Int('Options.WindowWidth',1024)`.
- `Apus.Engine.GameApp`: a missing `appSetup.configFile` is no longer a `FatalError`: the
  defaults are used, a toast says so, and `SaveOptions` creates the file.
- `Apus.Engine.Sound`: an event may also be a section,
  `sampleQuiet = { file = "sample.ogg", vol = 30 }`; `PreloadSamples` may be an array
  of files; a missing `PreloadSamples` means `NONE` (it was a config loading error).
  A broken event is reported and skipped; a config error no longer fails the sound
  initialization.
- Migration of game code: `ctlGetInt(appSetup.configFile+':\Options\X',d)` →
  `appConfig.Root.Int('Options.X',d)`; other files: `cfg:=TConfig.Create(name)` and
  `cfg.Root.Str('A.B',...)`. The full table is section 13 of `manual/config_files.md`;
  upgrader TODO rules are in `tools/engine5.upgrade`. The demo configs use the CTL3
  syntax now.

## Window close request: the app may keep the window (2026-10-22)

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

## Music loop points (2026-10-19)

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

## Sound API: ISoundSystem, pitch, procedural sound (2026-10-19)

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

## Pixel grid of the 2D primitives on a scaled canvas (2026-10-18)

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

## Default fonts grow in proportion to the DPI (2026-10-18)

`game.defaultFont`, `smallFont` and `largerFont` grow in proportion to the canvas DPI
(`7.376*dpi/96`), like `Dp()` and a logical canvas. They used to grow slower
(`2+0.056*dpi`): the same size at 96 DPI, 14% smaller at 192 DPI, so layouts built
with `Dp()` had too much room for the text.

## Face culling is the same in render targets (2026-10-18)

The projection flips Y for the backbuffer but not for a texture target, which mirrors
the winding, while the GL front face was fixed at CCW: `TCullMode.DrawCCW` kept the back
faces in a render target (3D into an RT, a frame through the presentation RT, scene
transition effects). The GL backend now switches the front face with the target, so a
`TCullMode` keeps the same faces everywhere (`tests/TestCulling`). Code that compensated
for it (e.g. `DrawCW` for 3D into an RT) has to go back to the normal mode.

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

## Sharp text on a canvas scaled by the projection (2026-10-17)

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

## Logical canvas (2026-10-17)

- `TSurfaceConfig.canvasDPI` (flexible canvas only): DPI of the canvas grid. 0 (default)
  = one canvas unit per display pixel, as before; N>0 = a unit is 1/N inch, the canvas is
  the display rect divided by `dpi/N` and the projection scales it (`matrix`). Rejected
  with a fixed or half-fixed canvas.
- `TGameApplication.SetupLogicalCanvas(dpi=96)` - preset: the canvas follows the client
  area in logical pixels, so the same numbers give the same physical size on any display.
  `game.screenScale` stays 1 there (the projection does the scaling), like over a fixed
  canvas.

## Assertions are on in FPC builds (2026-10-17)

FPC compiles `ASSERT` out unless `-Sa` is given, and no engine build had it. `build.cfg`
and every test/smoke script now pass `-Sa`. A project that wants a build without
assertions adds `-Sa-` to its own options.

## Dead optional paths removed (2026-10-11)

- Video capture removed: `TGameBase/TGame/TWindow.StartVideoCap`/`FinishVideoCap`,
  `TFrameCapture.videoMode`/`videoPath` and the `VIDEOCAPTURE` define (its unit
  `Apus.Engine.VideoCapture` was gone long ago). Use an external recorder.
- `GLintptr`/`GLsizeiptr` in `extra/dglOpenGL.pas`/`dglOpenGLES.pas` are `NativeInt`
  (pointer-sized, as Khronos defines them; they were 32-bit). `PGLchar` in dglOpenGLES is
  `PAnsiChar` (the GLES renderer compiles with Delphi).

## Window frame drawn by the app (2026-10-10)

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

## Frame signals, Steam integration migrated (2026-10-04)

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

## Window lock, cross-thread entry into a window (2026-10-04)

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

## Image loading: WebP files (2026-09-26)

- The engine file loader and preloader accept `.webp`; extensionless file probing includes
  `.webp` only in `WEBP` builds. The decoder (`LoadWebP`, the `WEBP` define, the library to
  ship) is in `Base/engine5_changes.md`.

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

## TGameApplication: startup settings are instance fields (2026-09-14)

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

## Audio backends are opt-in (2026-08-31)

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

## R-31 working surface model, stage B (2026-08-25)

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

## Platform-native text line endings (2026-07-03)

- Robot API responses and the engine diagnostics used by Robot API handlers
  use `LineBreak` (`Apus.Core`, the native line terminator); wire protocols that
  require CRLF remain unchanged.

## Glyph cache diagnostics and bounds fixes (2026-06-29)

- `Apus.Engine.TextDraw` checks the fixed glyph-update rectangle list before
  writing a new entry, preventing a range-check exception in the diagnostic path.

## Depth state API (2026-06-19)

- `IRenderTarget.UseDepthBuffer(test;writeEnable:boolean)` → **`SetDepthMode(test:TDepthTest=Keep; write:TDepthWrite=Keep)`**. The misleading "buffer" name dropped; test and write mask are now independent axes, each with a keep-current sentinel.
- `TDepthBufferTest` → **`TDepthTest`** (scoped enum): `dbDisabled/dbPass/dbPassLess/dbPassLessEqual/dbPassGreater/dbNever` → `TDepthTest.Disabled/Pass/Less/LessEqual/Greater/Never` + new `TDepthTest.Keep`.
- New **`TDepthWrite`** scoped enum (`Keep/Off/On`) for the write mask (was a bare `boolean`). `,false`→`,TDepthWrite.Off`, `,true`→`,TDepthWrite.On`.
- New **`IRenderTarget.DepthMode:TDepthMode`** getter (record `{test;write}`) + tracked `curDepth` threadvar state — enables save/restore and keep-current. No state stack (deliberate).
- Fixed latent bug: write mask was skipped when test=`dbDisabled`; now `glDepthMask` always reflects tracked state.
- No compatibility alias. Upgrader rules added to `tools/engine5.upgrade`.

## Removed legacy OpenGL painters (2026-06-19)

- Removed `Apus.Engine.PainterGL.pas` and `Apus.Engine.PainterGL2.pas`.
- Current desktop rendering uses `Apus.Engine.OpenGL` with `IGraphicsSystem`, `IRenderTarget`, `IShader`, `IDrawer`, and `ITextDrawer`.
- The old Android backend still needs migration to the current graphics-system architecture before Android builds can be re-enabled.

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

### `TTexture` row pointers

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

### Linux runtime validation

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
