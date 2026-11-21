# Color Picker (first implementation, API under review)

`Apus.Engine.UIColorPicker` provides an ARGB color button, a replaceable popup
editor and a shared five-color recent history. Build `demo/UI` with `build.cmd UI`,
then open **Color Picker**. The page includes two standard buttons and an application
HEX editor supplied through a factory. Color Combo is a separate follow-up.

## Using the color button

```pascal
uses Apus.Engine.UIColorPicker;

// In a UI setup method; Changed/Preview/Cancelled are methods of this object.
button:=TUIColorButton.Create(48,24,parent,'MaterialColor');
button.color:=$FF40A0D0;
button.alphaEnabled:=false;    // optional: opaque RGB mode; alpha is enabled by default
button.onChange:=Changed;
button.onPreview:=Preview;      // optional live preview
button.onCancel:=Cancelled;    // discard that preview
```

All three handlers have this signature:

```pascal
procedure Changed(sender:TUIColorButton;oldColor,newColor:cardinal);
```

`color` contains straight (not premultiplied) `$AARRGGBB`, including zero alpha.
`alphaEnabled` defaults to true on the button and editor. Set it to false for RGB-only
applications: the alpha strip disappears, values are normalized to `$FFRRGGBB`, and
semi-transparent MRU entries are displayed/selected as opaque. Changing the setting
cancels an open session; turning it off makes the committed value opaque silently.
Enabling it again starts from that opaque value. Setting `color` cancels any open session and
changes the committed color without `onChange` or a history entry. During preview
the button retains its committed color; `onPreview` supplies the working value.
Use `oldColor` to build one undo operation in `onChange`, which fires only when
the accepted color differs. `onCancel` supplies the initial and last working values;
discard the preview rather than storing the working value.

The standard panel shows one compact read-only line in decimal A,R,G,B order,
followed by `#AARRGGBB`, for example `128,64,160,208 #8040A0D0`, at the base font size 7.5. This uses ARGB in
both modes; with alpha disabled, A is 255. The small label keeps the standard
picker mouse-only. Hue and alpha have large outlined pointer
triangles on both sides. A checkerboard under alpha and transparent swatches shows
transparency. Changing H/S/V keeps alpha; alpha changes keep the RGB channels.
Ordinary UI hints are ordered above popup siblings, so picker tooltips remain visible.

Enter, OK and an outside press accept the value. The outside press closes the
popup before ordinary mouse delivery: a Save button works with the first click.
Another press on the owner closes the popup without reopening it. Escape/Cancel
restore the initial value. Releasing a drag outside the popup only ends the drag.
`OpenPicker`, `Accept`, `Cancel` and `IsOpen` are also available to the application.

The popup cancels when its owner becomes hidden/disabled/removed, the root size or
scale changes, or focus leaves its subtree. Cancellation checks run on a short UI
timer. Application callbacks are suppressed for deleted owners and while removing
a whole UI subtree: release application preview state with that UI's lifecycle.
Cancel explicitly before removal when a live application needs its cancel callback.

## Shared recent colors

By default every button uses `DefaultColorHistory`, shared across the application's
window threads. Accepting a color moves it to the front, removes duplicates and
keeps at most five entries. Accepting an unchanged value updates MRU but generates
no `onChange`. Preview, cancel and programmatic color assignment leave MRU alone.
Clicking an MRU entry changes the working color; it does not close the popup.
History stores the complete ARGB value: equal RGB with different alpha are distinct
entries. RGB-only editors normalize an entry when it is selected, without changing
the stored original until the resulting opaque choice is confirmed.

`IUIColorHistory.GetColors` returns a newest-first independent snapshot and
`Remember` records an accepted color. `TUIColorHistory` is a synchronized in-memory
implementation. Set `button.history` to your own implementation for persistence or
document-specific history; a nil value selects the default. History implementations
used by several windows must synchronize their own data. The engine calls the
history from UI threads and holds no history lock while invoking color handlers.

## Customization

The button uses the active style for its border, radius and states; its color is
data and is not tinted by the theme. `popupStyle` replaces the popup's style text
for this button (empty selects the default). Content can set its own style and
preferred size, while the host scales the whole composition to fit a small root.

Assign an editor subclass to `button.editorClass`. The popup creates and owns the
editor and supplies the recent colors and OK/Cancel buttons. Changing the class
cancels the current session and discards the previous content. Assign `nil` to
restore the default editor.

Derive from `TUIColorPicker` to modify the standard composition through protected
`BuildContent`/`LayoutContent`, or derive from `TUIColorEditor` to replace it.
The content contract is:

- `SetColor` initializes/updates silently; `ChooseColor` publishes user preview.
- `originalColor` and `color` expose the current editing session.
- `alphaEnabled` carries the host's RGB/ARGB mode. Use `SetColor`/`ChooseColor` for
  normalization; a custom editor that writes `fColor` directly must honor the mode.
- `PreferredSize` supplies logical content dimensions; the base returns `size`.
- `Refresh` updates the editor's displayed values when its color or alpha mode changes.
- `CanAccept` validates input; `InitialFocus` optionally returns a child to focus.
- `Accept` and `Cancel` request completion from the popup.

The standard content is mouse-only, with one focus on the popup. A custom editor
can use focusable child controls: Tab wraps within the popup, Escape cancels and
Enter accepts. The host routes other keys to the child and consumes unhandled
application hotkeys. If `CanAccept=false`, Enter/OK leave the editor open, while
an outside press cancels the invalid session and continues to its target.

See `THexColorEditor` in `demo/UI/UIApp.pas` for a complete replacement example.
No new module-specific unit tests are included before API review; existing smoke
checks and the documented Robot API demo scenarios are separate validation.
