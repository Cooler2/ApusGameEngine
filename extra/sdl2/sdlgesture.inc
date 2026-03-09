//from "sdl_gesture.h"

type
  PPSDL_GestureID = ^PSDL_GestureID;
  PSDL_GestureID = ^TSDL_GestureID;
  TSDL_GestureID = type cint64;

  {* Function prototypes *}

  {/**
 * Begin recording a gesture on a specified touch device or all touch devices.
 *
 * If the parameter `touchId` is -1 (i.e., all devices), this function will
 * always return 1, regardless of whether there actually are any devices.
 *
 * \param touchId the touch device id, or -1 for all touch devices
 * \returns 1 on success or 0 if the specified device could not be found.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetTouchDevice
 *}
function SDL_RecordGesture(touchId: TSDL_TouchID): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RecordGesture' {$ENDIF} {$ENDIF};

  {**
 * Save all currently loaded Dollar Gesture templates.
 *
 * \param dst a SDL_RWops to save to
 * \returns the number of saved templates on success or 0 on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_LoadDollarTemplates
 * \sa SDL_SaveDollarTemplate
 *}
function SDL_SaveAllDollarTemplates(dst: PSDL_RWops): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SaveAllDollarTemplates' {$ENDIF} {$ENDIF};

  {**
 * Save a currently loaded Dollar Gesture template.
 *
 * \param gestureId a gesture id
 * \param dst a SDL_RWops to save to
 * \returns 1 on success or 0 on failure; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_LoadDollarTemplates
 * \sa SDL_SaveAllDollarTemplates
 *}
function SDL_SaveDollarTemplate(gestureId: TSDL_GestureID; dst: PSDL_RWops): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SaveDollarTemplate' {$ENDIF} {$ENDIF};


  {**
 * Load Dollar Gesture templates from a file.
 *
 * \param touchId a touch id
 * \param src a SDL_RWops to load from
 * \returns the number of loaded templates on success or a negative error code
 *          (or 0) on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_SaveAllDollarTemplates
 * \sa SDL_SaveDollarTemplate
 *}
function SDL_LoadDollarTemplates(touchId: TSDL_TouchID; src: PSDL_RWops): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LoadDollarTemplates' {$ENDIF} {$ENDIF};
