//from "sdl_messagebox.h"

{**
 *  SDL_MessageBox flags. If supported will display warning icon, etc.
 *}
type
  PPSDL_MessageBoxFlags = ^PSDL_MessageBoxFlags;
  PSDL_MessageBoxFlags = ^TSDL_MessageBoxFlags;
  TSDL_MessageBoxFlags = type cuint32;

const
  SDL_MESSAGEBOX_ERROR                 = TSDL_MessageBoxFlags($00000010);   {**< error dialog *}
  SDL_MESSAGEBOX_WARNING               = TSDL_MessageBoxFlags($00000020);   {**< warning dialog *}
  SDL_MESSAGEBOX_INFORMATION           = TSDL_MessageBoxFlags($00000040);   {**< informational dialog *}
  SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT = TSDL_MessageBoxFlags($00000080);   {/**< buttons placed left to right */}
  SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT = TSDL_MessageBoxFlags($00000100);   {/**< buttons placed right to left */}

{**
 *  Flags for SDL_MessageBoxButtonData.
 *}
type
  PPSDL_MessageBoxButtonFlags = ^PSDL_MessageBoxButtonFlags;
  PSDL_MessageBoxButtonFlags = ^TSDL_MessageBoxButtonFlags;
  TSDL_MessageBoxButtonFlags = type cuint32;

const
  SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT = TSDL_MessageBoxButtonFlags($00000001);  {**< Marks the default button when return is hit *}
  SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT = TSDL_MessageBoxButtonFlags($00000002);  {**< Marks the default button when escape is hit *}


{**
 *   Individual button data.
 *}
type
  PPSDL_MessageBoxButtonData = ^PSDL_MessageBoxButtonData;
  PSDL_MessageBoxButtonData = ^TSDL_MessageBoxButtonData;
  TSDL_MessageBoxButtonData = record
    flags: TSDL_MessageBoxButtonFlags;  {**< ::SDL_MessageBoxButtonFlags *}
    buttonid: cint;                     {**< User defined button id (value returned via SDL_ShowMessageBox) *}
    text: PAnsiChar;                    {**< The UTF-8 button text *}
  end;

{**
 *  RGB value used in a message box color scheme
 *}
type
  PPSDL_MessageBoxColor = ^PSDL_MessageBoxColor;
  PSDL_MessageBoxColor = ^TSDL_MessageBoxColor;
  TSDL_MessageBoxColor = record
    r, g, b: cuint8;
  end;

  PPSDL_MessageBoxColorType = ^PSDL_MessageBoxColorType;
  PSDL_MessageBoxColorType = ^TSDL_MessageBoxColorType;
  TSDL_MessageBoxColorType = type Word;

const
  SDL_MESSAGEBOX_COLOR_BACKGROUND        = TSDL_MessageBoxColorType(0);
  SDL_MESSAGEBOX_COLOR_TEXT              = TSDL_MessageBoxColorType(1);
  SDL_MESSAGEBOX_COLOR_BUTTON_BORDER     = TSDL_MessageBoxColorType(2);
  SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND = TSDL_MessageBoxColorType(3);
  SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED   = TSDL_MessageBoxColorType(4);
  SDL_MESSAGEBOX_COLOR_MAX               = TSDL_MessageBoxColorType(5);

  {**
   *  A set of colors to use for message box dialogs
   *}
type
  PPSDL_MessageBoxColorScheme = ^PSDL_MessageBoxColorScheme;
  PSDL_MessageBoxColorScheme = ^TSDL_MessageBoxColorScheme;
  TSDL_MessageBoxColorScheme = record
    colors: array[0..SDL_MESSAGEBOX_COLOR_MAX-1] of TSDL_MessageBoxColor;
  end;

  {**
   *   MessageBox structure containing title, text, window, etc.
   *}
type
  PPSDL_MessageBoxData = ^PSDL_MessageBoxData;
  PSDL_MessageBoxData = ^TSDL_MessageBoxData;
  TSDL_MessageBoxData = record
    flags: TSDL_MessageBoxFlags;             {**< SDL_MessageBoxFlags *}
    window: PSDL_Window;                     {**< Parent window, can be NULL *}
    title: PAnsiChar;                        {**< UTF-8 title *}
    _message: PAnsiChar;                     {**< UTF-8 message text *}

    numbuttons: cint;
    buttons: PSDL_MessageBoxButtonData;

    colorScheme: PSDL_MessageBoxColorScheme;   {**< SDL_MessageBoxColorScheme, can be NULL to use system settings *}
  end;

{**
 *   Create a modal message box.
 *
 *   messageboxdata The SDL_MessageBoxData structure with title, text, etc.
 *   buttonid The pointer to which user id of hit button should be copied.
 *
 *   -1 on error, otherwise 0 and buttonid contains user id of button
 *   hit or -1 if dialog was closed.
 *
 *   This function should be called on the thread that created the parent
 *   window, or on the main thread if the messagebox has no parent.  It will
 *   block execution of that thread until the user clicks a button or
 *   closes the messagebox.
 *}
function SDL_ShowMessageBox(messageboxdata: PSDL_MessageBoxData; buttonid: pcint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ShowMessageBox' {$ENDIF} {$ENDIF};

{**
 *   Create a simple modal message box
 *
 *   flags    SDL_MessageBoxFlags
 *   title    UTF-8 title text
 *   message  UTF-8 message text
 *   window   The parent window, or NULL for no parent
 *
 *   0 on success, -1 on error
 *
 *   SDL_ShowMessageBox
 *}
function SDL_ShowSimpleMessageBox(flags: TSDL_MessageBoxFlags; title: PAnsiChar; _message: PAnsiChar; window: PSDL_Window): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ShowSimpleMessageBox' {$ENDIF} {$ENDIF};

