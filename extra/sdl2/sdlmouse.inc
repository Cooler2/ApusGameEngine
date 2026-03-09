//from "sdl_mouse.h"

type
  PPSDL_Cursor = ^PSDL_Cursor;
  PSDL_Cursor = type Pointer;  {**< Implementation dependent *}

{**
*  Cursor types for SDL_CreateSystemCursor.
*}
type
  PPSDL_SystemCursor = ^PSDL_SystemCursor;
  PSDL_SystemCursor = ^TSDL_SystemCursor;
  TSDL_SystemCursor = type Integer;

const
  SDL_SYSTEM_CURSOR_ARROW = TSDL_SystemCursor(0);      // Arrow
  SDL_SYSTEM_CURSOR_IBEAM = TSDL_SystemCursor(1);      // I-beam
  SDL_SYSTEM_CURSOR_WAIT = TSDL_SystemCursor(2);       // Wait
  SDL_SYSTEM_CURSOR_CROSSHAIR = TSDL_SystemCursor(3);  // Crosshair
  SDL_SYSTEM_CURSOR_WAITARROW = TSDL_SystemCursor(4);  // Small wait cursor (or Wait if not available)
  SDL_SYSTEM_CURSOR_SIZENWSE = TSDL_SystemCursor(5);   // Double arrow pointing northwest and southeast
  SDL_SYSTEM_CURSOR_SIZENESW = TSDL_SystemCursor(6);   // Double arrow pointing northeast and southwest
  SDL_SYSTEM_CURSOR_SIZEWE = TSDL_SystemCursor(7);     // Double arrow pointing west and east
  SDL_SYSTEM_CURSOR_SIZENS = TSDL_SystemCursor(8);     // Double arrow pointing north and south
  SDL_SYSTEM_CURSOR_SIZEALL = TSDL_SystemCursor(9);    // Four pointed arrow pointing north, south, east, and west
  SDL_SYSTEM_CURSOR_NO = TSDL_SystemCursor(10);        // Slashed circle or crossbones
  SDL_SYSTEM_CURSOR_HAND = TSDL_SystemCursor(11);      // Hand
  SDL_NUM_SYSTEM_CURSORS = TSDL_SystemCursor(12);

type
  PPSDL_MouseWheelDirection = ^PSDL_MouseWheelDirection;
  PSDL_MouseWheelDirection = ^TSDL_MouseWheelDirection;
  TSDL_MouseWheelDirection = type Integer;

const
  SDL_MOUSEWHEEL_NORMAL   = TSDL_MouseWheelDirection(0);   {**< The scroll direction is normal *}
  SDL_MOUSEWHEEL_FLIPPED  = TSDL_MouseWheelDirection(1);   {**< The scroll direction is flipped / natural *}

  {* Function prototypes *}

  {**
 * Get the window which currently has mouse focus.
 *
 * \returns the window with mouse focus.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_GetMouseFocus: PSDL_Window; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetMouseFocus' {$ENDIF}{$ENDIF};

  {**
 * Retrieve the current state of the mouse.
 *
 * The current button state is returned as a button bitmask, which can be
 * tested using the `SDL_BUTTON(X)` macros (where `X` is generally 1 for the
 * left, 2 for middle, 3 for the right button), and `x` and `y` are set to the
 * mouse cursor position relative to the focus window. You can pass NULL for
 * either `x` or `y`.
 *
 * \param x the x coordinate of the mouse cursor position relative to the
 *          focus window
 * \param y the y coordinate of the mouse cursor position relative to the
 *          focus window
 * \returns a 32-bit button bitmask of the current button state.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetGlobalMouseState
 * \sa SDL_GetRelativeMouseState
 * \sa SDL_PumpEvents
 *}
function SDL_GetMouseState(x: pcint; y: pcint): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetMouseState' {$ENDIF}{$ENDIF};


  {**
 * Get the current state of the mouse in relation to the desktop.
 *
 * This works similarly to SDL_GetMouseState(), but the coordinates will be
 * reported relative to the top-left of the desktop. This can be useful if you
 * need to track the mouse outside of a specific window and SDL_CaptureMouse()
 * doesn't fit your needs. For example, it could be useful if you need to
 * track the mouse while dragging a window, where coordinates relative to a
 * window might not be in sync at all times.
 *
 * Note: SDL_GetMouseState() returns the mouse position as SDL understands it
 * from the last pump of the event queue. This function, however, queries the
 * OS for the current mouse position, and as such, might be a slightly less
 * efficient function. Unless you know what you're doing and have a good
 * reason to use this function, you probably want SDL_GetMouseState() instead.
 *
 * \param x filled in with the current X coord relative to the desktop; can be
 *          NULL
 * \param y filled in with the current Y coord relative to the desktop; can be
 *          NULL
 * \returns the current button state as a bitmask which can be tested using
 *          the SDL_BUTTON(X) macros.
 *
 * \since This function is available since SDL 2.0.4.
 *
 * \sa SDL_CaptureMouse
 *}
function SDL_GetGlobalMouseState(x, y: pcint32): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetGlobalMouseState' {$ENDIF}{$ENDIF};

  {**
 * Retrieve the relative state of the mouse.
 *
 * The current button state is returned as a button bitmask, which can be
 * tested using the `SDL_BUTTON(X)` macros (where `X` is generally 1 for the
 * left, 2 for middle, 3 for the right button), and `x` and `y` are set to the
 * mouse deltas since the last call to SDL_GetRelativeMouseState() or since
 * event initialization. You can pass NULL for either `x` or `y`.
 *
 * \param x a pointer filled with the last recorded x coordinate of the mouse
 * \param y a pointer filled with the last recorded y coordinate of the mouse
 * \returns a 32-bit button bitmask of the relative button state.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetMouseState
 *}
function SDL_GetRelativeMouseState(x: pcint; y: pcint): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetRelativeMouseState' {$ENDIF}{$ENDIF};

  {**
 * Move the mouse cursor to the given position within the window.
 *
 * This function generates a mouse motion event if relative mode is not
 * enabled. If relative mode is enabled, you can force mouse events for the
 * warp by setting the SDL_HINT_MOUSE_RELATIVE_WARP_MOTION hint.
 *
 * Note that this function will appear to succeed, but not actually move the
 * mouse when used over Microsoft Remote Desktop.
 *
 * \param window the window to move the mouse into, or NULL for the current
 *               mouse focus
 * \param x the x coordinate within the window
 * \param y the y coordinate within the window
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_WarpMouseGlobal
 *}
procedure SDL_WarpMouseInWindow(window: PSDL_Window; x: cint; y: cint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WarpMouseInWindow' {$ENDIF}{$ENDIF};

  {**
 * Move the mouse to the given position in global screen space.
 *
 * This function generates a mouse motion event.
 *
 * A failure of this function usually means that it is unsupported by a
 * platform.
 *
 * Note that this function will appear to succeed, but not actually move the
 * mouse when used over Microsoft Remote Desktop.
 *
 * \param x the x coordinate
 * \param y the y coordinate
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.4.
 *
 * \sa SDL_WarpMouseInWindow
 *}
function SDL_WarpMouseGlobal(x, y: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WarpMouseGlobal' {$ENDIF}{$ENDIF};

  {**
 * Set relative mouse mode.
 *
 * While the mouse is in relative mode, the cursor is hidden, and the driver
 * will try to report continuous motion in the current window. Only relative
 * motion events will be delivered, the mouse position will not change.
 *
 * Note that this function will not be able to provide continuous relative
 * motion when used over Microsoft Remote Desktop, instead motion is limited
 * to the bounds of the screen.
 *
 * This function will flush any pending mouse motion.
 *
 * \param enabled SDL_TRUE to enable relative mode, SDL_FALSE to disable.
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 *          If relative mode is not supported, this returns -1.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetRelativeMouseMode
 *}
function SDL_SetRelativeMouseMode(enabled: TSDL_Bool): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetRelativeMouseMode' {$ENDIF}{$ENDIF};

  {**
 * Capture the mouse and to track input outside an SDL window.
 *
 * Capturing enables your app to obtain mouse events globally, instead of just
 * within your window. Not all video targets support this function. When
 * capturing is enabled, the current window will get all mouse events, but
 * unlike relative mode, no change is made to the cursor and it is not
 * restrained to your window.
 *
 * This function may also deny mouse input to other windows--both those in
 * your application and others on the system--so you should use this function
 * sparingly, and in small bursts. For example, you might want to track the
 * mouse while the user is dragging something, until the user releases a mouse
 * button. It is not recommended that you capture the mouse for long periods
 * of time, such as the entire time your app is running. For that, you should
 * probably use SDL_SetRelativeMouseMode() or SDL_SetWindowGrab(), depending
 * on your goals.
 *
 * While captured, mouse events still report coordinates relative to the
 * current (foreground) window, but those coordinates may be outside the
 * bounds of the window (including negative values). Capturing is only allowed
 * for the foreground window. If the window loses focus while capturing, the
 * capture will be disabled automatically.
 *
 * While capturing is enabled, the current window will have the
 * `SDL_WINDOW_MOUSE_CAPTURE` flag set.
 *
 * Please note that as of SDL 2.0.22, SDL will attempt to "auto capture" the
 * mouse while the user is pressing a button; this is to try and make mouse
 * behavior more consistent between platforms, and deal with the common case
 * of a user dragging the mouse outside of the window. This means that if you
 * are calling SDL_CaptureMouse() only to deal with this situation, you no
 * longer have to (although it is safe to do so). If this causes problems for
 * your app, you can disable auto capture by setting the
 * `SDL_HINT_MOUSE_AUTO_CAPTURE` hint to zero.
 *
 * \param enabled SDL_TRUE to enable capturing, SDL_FALSE to disable.
 * \returns 0 on success or -1 if not supported; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.4.
 *
 * \sa SDL_GetGlobalMouseState
 *}
 function SDL_CaptureMouse(enabled: TSDL_Bool): cint; cdecl;
   external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CaptureMouse' {$ENDIF}{$ENDIF};

  {**
 * Query whether relative mouse mode is enabled.
 *
 * \returns SDL_TRUE if relative mode is enabled or SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_SetRelativeMouseMode
 *}
function SDL_GetRelativeMouseMode: TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetRelativeMouseMode' {$ENDIF}{$ENDIF};

  {**
 * Create a cursor using the specified bitmap data and mask (in MSB format).
 *
 * `mask` has to be in MSB (Most Significant Bit) format.
 *
 * The cursor width (`w`) must be a multiple of 8 bits.
 *
 * The cursor is created in black and white according to the following:
 *
 * - data=0, mask=1: white
 * - data=1, mask=1: black
 * - data=0, mask=0: transparent
 * - data=1, mask=0: inverted color if possible, black if not.
 *
 * Cursors created with this function must be freed with SDL_FreeCursor().
 *
 * If you want to have a color cursor, or create your cursor from an
 * SDL_Surface, you should use SDL_CreateColorCursor(). Alternately, you can
 * hide the cursor and draw your own as part of your game's rendering, but it
 * will be bound to the framerate.
 *
 * Also, since SDL 2.0.0, SDL_CreateSystemCursor() is available, which
 * provides twelve readily available system cursors to pick from.
 *
 * \param data the color value for each pixel of the cursor
 * \param mask the mask value for each pixel of the cursor
 * \param w the width of the cursor
 * \param h the height of the cursor
 * \param hot_x the X-axis location of the upper left corner of the cursor
 *              relative to the actual mouse position
 * \param hot_y the Y-axis location of the upper left corner of the cursor
 *              relative to the actual mouse position
 * \returns a new cursor with the specified parameters on success or NULL on
 *          failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_FreeCursor
 * \sa SDL_SetCursor
 * \sa SDL_ShowCursor
 *}
function SDL_CreateCursor(
  const data: pcuint8;
  const mask: pcuint8;
  w: cint; h: cint;
  hot_x: cint; hot_y: cint): PSDL_Cursor; cdecl;
    external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateCursor' {$ENDIF}{$ENDIF};

  {**
 * Create a color cursor.
 *
 * \param surface an SDL_Surface structure representing the cursor image
 * \param hot_x the x position of the cursor hot spot
 * \param hot_y the y position of the cursor hot spot
 * \returns the new cursor on success or NULL on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateCursor
 * \sa SDL_FreeCursor
 *}
function SDL_CreateColorCursor(
  surface: PSDL_Surface;
  hot_x: cint;
  hot_y: cint): PSDL_Cursor; cdecl;
    external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateColorCursor' {$ENDIF}{$ENDIF};

  {**
 * Create a system cursor.
 *
 * \param id an SDL_SystemCursor enum value
 * \returns a cursor on success or NULL on failure; call SDL_GetError() for
 *          more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_FreeCursor
 *}
function SDL_CreateSystemCursor(id: TSDL_SystemCursor): PSDL_Cursor; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateSystemCursor' {$ENDIF}{$ENDIF};

  {**
 * Set the active cursor.
 *
 * This function sets the currently active cursor to the specified one. If the
 * cursor is currently visible, the change will be immediately represented on
 * the display. SDL_SetCursor(NULL) can be used to force cursor redraw, if
 * this is desired for any reason.
 *
 * \param cursor a cursor to make active
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateCursor
 * \sa SDL_GetCursor
 * \sa SDL_ShowCursor
 *}
procedure SDL_SetCursor(cursor: PSDL_Cursor); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetCursor' {$ENDIF}{$ENDIF};

  {**
 * Get the active cursor.
 *
 * This function returns a pointer to the current cursor which is owned by the
 * library. It is not necessary to free the cursor with SDL_FreeCursor().
 *
 * \returns the active cursor or NULL if there is no mouse.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_SetCursor
 *}
function SDL_GetCursor: PSDL_Cursor; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetCursor' {$ENDIF}{$ENDIF};
  
  {**
 * Get the default cursor.
 *
 * \returns the default cursor on success or NULL on failure.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateSystemCursor
 *}
function SDL_GetDefaultCursor: PSDL_Cursor; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDefaultCursor' {$ENDIF}{$ENDIF};

  {**
 * Free a previously-created cursor.
 *
 * Use this function to free cursor resources created with SDL_CreateCursor(),
 * SDL_CreateColorCursor() or SDL_CreateSystemCursor().
 *
 * \param cursor the cursor to free
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateColorCursor
 * \sa SDL_CreateCursor
 * \sa SDL_CreateSystemCursor
 *}
procedure SDL_FreeCursor(cursor: PSDL_Cursor); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FreeCursor' {$ENDIF}{$ENDIF};

  {**
 * Toggle whether or not the cursor is shown.
 *
 * The cursor starts off displayed but can be turned off. Passing `SDL_ENABLE`
 * displays the cursor and passing `SDL_DISABLE` hides it.
 *
 * The current state of the mouse cursor can be queried by passing
 * `SDL_QUERY`; either `SDL_DISABLE` or `SDL_ENABLE` will be returned.
 *
 * \param toggle `SDL_ENABLE` to show the cursor, `SDL_DISABLE` to hide it,
 *               `SDL_QUERY` to query the current state without changing it.
 * \returns `SDL_ENABLE` if the cursor is shown, or `SDL_DISABLE` if the
 *          cursor is hidden, or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_CreateCursor
 * \sa SDL_SetCursor
 *}
function SDL_ShowCursor(toggle: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ShowCursor' {$ENDIF}{$ENDIF};

{**
 *  Used as a mask when testing buttons in buttonstate.
 *   - Button 1:  Left mouse button
 *   - Button 2:  Middle mouse button
 *   - Button 3:  Right mouse button
 *}
function SDL_Button(X: cint): cint; {$IFNDEF DELPHI} inline; {$ELSE} {$IFDEF DELPHI10UP} inline; {$ENDIF} {$ENDIF}
const
  SDL_BUTTON_LEFT   = 1;
  SDL_BUTTON_MIDDLE = 2;
  SDL_BUTTON_RIGHT  = 3;
  SDL_BUTTON_X1	    = 4;
  SDL_BUTTON_X2	    = 5;
  { Pascal Conv.: For better performance instead of using the
                  SDL_Button(X) macro, the following defines are
                  implemented directly. }
  SDL_BUTTON_LMASK  = 1 shl ((SDL_BUTTON_LEFT) - 1);
  SDL_BUTTON_MMASK  = 1 shl ((SDL_BUTTON_MIDDLE) - 1);
  SDL_BUTTON_RMASK  = 1 shl ((SDL_BUTTON_RIGHT) - 1);
  SDL_BUTTON_X1MASK = 1 shl ((SDL_BUTTON_X1) - 1);
  SDL_BUTTON_X2MASK = 1 shl ((SDL_BUTTON_X2) - 1);
