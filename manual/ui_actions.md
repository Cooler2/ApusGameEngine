# UI actions (first implementation, API under review)

An action (`TUIAction`, unit `Apus.Engine.Actions`) is one command with its state: caption,
shortcuts, hint, enabled, checked. Menu lines, buttons and keys share it: a menu line and a
toolbar button show the same state, the shortcut runs the same handler, a disabled command
is disabled everywhere at once. This is step 1 of R-36: actions belong to a scene. Scoped
bindings (focused subtree, element, window, application) come later.

Build `demo/UI` with `build.cmd UI` and open **Menu bar**: the menus, the toolbar below them
and the shortcuts are all actions (`TMainScene.CreateActions` and `UpdateActions` in
`demo/UI/UIApp.pas`). Undo becomes enabled after a command; View → Panels shows check lines
(F7/F8), View → Size shows radio lines.

## Creating actions

```pascal
uses Apus.Engine.Actions;

// in the scene constructor, onCreate, or Load (see "When to add them" below)
undo:=AddAction('edit.undo','&Undo',DoUndo,'Ctrl+Z');
redo:=AddAction('edit.redo','&Redo',DoRedo,'Ctrl+Y, Ctrl+Shift+Z');
save:=AddAction('file.save','&Save',DoSave,'Ctrl+S');
undo.hint:='Undo the last change';
```

`TGameScene.AddAction(id,caption,handler,shortcuts)`:
- `id` - stable and not translated (`'edit.undo'`), unique in the scene (ASSERT).
  `FindAction(id)` returns the action or nil.
- `caption` - with the mnemonic: `'&Undo'`. `MenuCaptionText(caption)` gives the plain text.
- `handler` - a plain procedure, a method of an object, or `nil` (the action only takes its
  key). Pass the method itself (`DoUndo`), never `@obj.Method` - that is a pointer without
  `self`, taken as a plain procedure. `SetHandler` changes the handler later.
- `shortcuts` - several are separated by commas. A shortcut is modifiers `Ctrl`, `Shift`,
  `Alt`, `Win` (any case) and a key: its `TKey.Name` (`Z`, `F5`, `1`, `Delete`, `PageUp`)
  or its `TKey` identifier (`D1`, `Equal`, `NumAdd`). The comma key is `Comma`. US layout
  has no `+` key: write `Ctrl+=` or `Ctrl+NumAdd`. A wrong shortcut is an error in the log
  and an ASSERT. The menu and the hints show the first shortcut as written.

The scene owns its actions and frees them in its destructor. Do not free them yourself and
do not keep them past the scene. If two actions of a scene take the same shortcut, the log
gets a warning and the first one added wins.

### When to add them

The window starts refreshing the actions of a scene (see below) as soon as its `loaded` is
true, and `TGameScene.Load` sets it at its very start. So in an overridden `Load` add the
actions **before** `inherited`, or make `UpdateActions` skip the actions not created yet.
The scene constructor and `onCreate` are always safe.

## Their state: one place

Override `UpdateActions` of the scene and set the state of all its actions there, from the
state of the application:

```pascal
procedure TEditorScene.UpdateActions;
 begin
  undo.enabled:=history.CanUndo;
  redo.enabled:=history.CanRedo;
  save.enabled:=document.modified;
  showGrid.checked:=settings.grid;
 end;
```

The engine calls it:
- each frame, for every active scene that has actions;
- before a menu panel with action lines is shown;
- inside `Execute`: before the handler (a stale enabled never runs a command) and after it
  (the lines and buttons show the result at once - Undo goes gray after the last undo).

Keep it cheap: plain field reads, no searching or allocation. The setters do nothing when the
value does not change. `enabled` is true by default.

`checked` is always set by the application: `Execute` does not flip it, and there are no
radio groups. Toggle your own field in the handler and copy it to `checked` here - one place
stores the state. An action may also have its own `onUpdate`, called after `UpdateActions`.

## Menus

```pascal
m:=bar.AddSubmenu('&Edit');
m.Add(undo);
m.Add(redo);
m.AddSeparator;
s:=m.AddSubmenu('&Size');
small.mark:=TActionMark.Radio;   // also Check; None by default
s.Add(small);
```

`TUIPopupMenu.Add(action)` makes a line that follows the action: caption, first shortcut,
enabled, and `checked` drawn as a check or a radio dot (`action.mark`) in a column before
the captions. A click closes the menu and runs the action. A new caption or shortcut while
the menu is open measures it again. Lines without an action can show a mark too: set
`mark` and `checked` of the `TUIMenuItem`.

## Buttons

```pascal
TUIToolButton.Create(70,28,tools,'Tools\Undo').Setup('Undo').action:=undo;
TUIToggleButton.Create(70,28,tools,'Tools\Grid').Setup('Grid').action:=showGrid;
```

`TUIButton.action` (and its descendants):
- a click runs the action (`Execute`). The button signals are sent as before, but the
  `onClick*` handlers must not be set together with an action (ASSERT);
- `enabled` follows the action;
- the caption stays the button's own;
- the hint is composed: the hint set on the button before the action, else the action hint,
  else the action caption without `&`; then the shortcut in brackets:
  `Undo the last change (Ctrl+Z)`. `action:=nil` restores the button's own hint;
- `TUIToggleButton` shows `checked` as `toggled`; a click runs the action and does not
  latch by itself.

For a toolbar use `TUIToolButton`: it never takes the focus, so the keys stay where they
were.

## Keys

The keyboard-topmost scene gets the key presses. A `TUIScene` routes a press:
1. the focused element (an edit box keeps the keys it handles: Ctrl+Z, letters...);
2. element hotkeys (`TUIElement.SetHotKey`);
3. the scene actions, then the scene hotkeys (`RegisterHotKey`);
4. `onKeyDown`.

An open popup menu or a menu bar session (F10, Alt) takes all the keys: no shortcut runs
until it closes.

The modifiers match exactly: `Ctrl+Z` does not fire on `Ctrl+Shift+Z`, so the order of the
actions does not matter. Either Ctrl key is Ctrl (the same for Shift, Alt, Win). A disabled
action still takes its key and runs nothing: Ctrl+Z never falls through to another command.

The same rule now applies to `RegisterHotKey` and `SetHotKey` (behaviour change, see
`engine_changes.md`): a binding that relied on extra modifiers needs its own entry.

## One handler, several actions

`TUIAction.executing` is the action whose handler runs now (in this thread), nil outside.
With `tag` it lets one handler serve several actions:

```pascal
small.tag:=1; medium.tag:=2; large.tag:=3;   // all three have the handler SelectSize

procedure TEditorScene.SelectSize;
 begin
  iconSize:=TUIAction.executing.tag;
 end;
```

## From code

`action.Execute` is the only way to run an action - keys, menu lines and buttons call it
too. It refreshes the state, runs the handler if the action is enabled and returns true;
a disabled action returns false and runs nothing. Do not call the handler directly: the
lines and buttons would not see the result until the next frame.

## Threads

Action state is UI state: change it in the window thread or under the window lock
(`TWindow.LockState`). The engine calls - `UpdateActions`, handlers run by keys, menu lines
and synchronous clicks - already are. An async handler (`onClickAsync`) locks the window
itself before it touches actions.

## Not there yet

- Only scene actions: no element, window or application scope; no `Bind` of extra keys.
- No `visible`, icons or radio groups on the action; hide a line or a button yourself.
- The Robot API does not list or run actions yet.

Report what is missing or awkward: this is a first implementation, and the API may change
with the next steps of R-36.
