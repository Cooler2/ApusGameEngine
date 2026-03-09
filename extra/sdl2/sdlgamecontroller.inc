//from sdl_gamecontroller.h

{**
 *   SDL_gamecontroller.h
 *
 *  In order to use these functions, SDL_Init() must have been called
 *  with the ::SDL_INIT_JOYSTICK flag.  This causes SDL to scan the system
 *  for game controllers, and load appropriate drivers.
 *
 *  If you would like to receive controller updates while the application
 *  is in the background, you should set the following hint before calling
 *  SDL_Init(): SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS
 *}

{* The gamecontroller structure used to identify an SDL game controller *}
type
  PPSDL_GameController = ^PSDL_GameController;
  PSDL_GameController = type Pointer;

  PPSDL_GameControllerType = ^PSDL_GameControllerType;
  PSDL_GameControllerType = ^TSDL_GameControllerType;
  TSDL_GameControllerType = type cint;
const
  SDL_CONTROLLER_TYPE_UNKNOWN                      = TSDL_GameControllerType(0);
  SDL_CONTROLLER_TYPE_XBOX360                      = TSDL_GameControllerType(1);
  SDL_CONTROLLER_TYPE_XBOXONE                      = TSDL_GameControllerType(2);
  SDL_CONTROLLER_TYPE_PS3                          = TSDL_GameControllerType(3);
  SDL_CONTROLLER_TYPE_PS4                          = TSDL_GameControllerType(4);
  SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO          = TSDL_GameControllerType(5);
  SDL_CONTROLLER_TYPE_VIRTUAL                      = TSDL_GameControllerType(6);
  SDL_CONTROLLER_TYPE_PS5                          = TSDL_GameControllerType(7);
  SDL_CONTROLLER_TYPE_AMAZON_LUNA                  = TSDL_GameControllerType(8);
  SDL_CONTROLLER_TYPE_GOOGLE_STADIA                = TSDL_GameControllerType(9);
  SDL_CONTROLLER_TYPE_NVIDIA_SHIELD                = TSDL_GameControllerType(10);
  SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_LEFT  = TSDL_GameControllerType(11);
  SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT = TSDL_GameControllerType(12);
  SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_PAIR  = TSDL_GameControllerType(13);

type
  PPSDL_GameControllerBindType = ^PSDL_GameControllerBindType;
  PSDL_GameControllerBindType = ^TSDL_GameControllerBindType;
  TSDL_GameControllerBindType = type cint;
const
  SDL_CONTROLLER_BINDTYPE_NONE   = TSDL_GameControllerBindType(0);
  SDL_CONTROLLER_BINDTYPE_BUTTON = TSDL_GameControllerBindType(1);
  SDL_CONTROLLER_BINDTYPE_AXIS   = TSDL_GameControllerBindType(2);
  SDL_CONTROLLER_BINDTYPE_HAT    = TSDL_GameControllerBindType(3);

  {**
   *  Get the SDL joystick layer binding for this controller button/axis mapping
   *}
type
  THat = record
    hat: cint;
    hat_mask: cint;
  end;

  PPSDL_GameControllerButtonBind = ^PSDL_GameControllerButtonBind;
  PSDL_GameControllerButtonBind = ^TSDL_GameControllerButtonBind;
  TSDL_GameControllerButtonBind = record
    bindType: TSDL_GameControllerBindType;
    case cint of
      0: ( button: cint; );
      1: ( axis: cint; );
      2: ( hat: THat; );
  end;

  {**
   *  To count the number of game controllers in the system for the following:
   *  int nJoysticks = SDL_NumJoysticks();
   *  int nGameControllers = 0;
   *  for ( int i = 0; i < nJoysticks; i++ ) [
   *      if ( SDL_IsGameController(i) ) [
   *          nGameControllers++;
   *
   *    !! Pascal Conv.: Changed curly to square brackets in above example code
                         to prevent opening comment blocks!
   *
   *  Using the SDL_HINT_GAMECONTROLLERCONFIG hint or the SDL_GameControllerAddMapping you can add support for controllers SDL is unaware of or cause an existing controller to have a different binding. The format is:
   *  guid,name,mappings
   *
   *  Where GUID is the string value from SDL_JoystickGetGUIDString(), name is the human readable string for the device and mappings are controller mappings to joystick ones.
   *  Under Windows there is a reserved GUID of "xinput" that covers any XInput devices.
   *  The mapping format for joystick is:
   *      bX - a joystick button, index X
   *      hX.Y - hat X with value Y
   *      aX - axis X of the joystick
   *  Buttons can be used as a controller axis and vice versa.
   *
   *  This string shows an example of a valid mapping for a controller
   *  "341a3608000000000000504944564944,Afterglow PS3 Controller,a:b1,b:b2,y:b3,x:b0,start:b9,guide:b12,back:b8,dpup:h0.1,dpleft:h0.8,dpdown:h0.4,dpright:h0.2,leftshoulder:b4,rightshoulder:b5,leftstick:b10,rightstick:b11,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b6,righttrigger:b7",
   *
   *}

  {**
   *  Add or update an existing mapping configuration
   *
   *  1 if mapping is added, 0 if updated, -1 on error
   *}
function SDL_GameControllerAddMapping( mappingString: PAnsiChar ): cint cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerAddMapping' {$ENDIF} {$ENDIF};

  {**
   *  Load a set of mappings from a seekable SDL data stream (memory or file), filtered by the current SDL_GetPlatform()
   *  A community sourced database of controllers is available at https://raw.github.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt
   *
   *  If freerw is non-zero, the stream will be closed after being read.
   * 
   *  Returns number of mappings added, -1 on error
   *}
function SDL_GameControllerAddMappingsFromRW(rw: PSDL_RWops; freerw: cint32):cint32;
   cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerAddMappingsFromRW' {$ENDIF} {$ENDIF};

{**
 * Get the number of mappings installed.
  *}
function SDL_GameControllerNumMappings():cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerNumMappings' {$ENDIF} {$ENDIF};

  {**
   *  Get a mapping string for a GUID
   *
   *   the mapping string.  Must be freed with SDL_free.  Returns NULL if no mapping is available
   *}
function SDL_GameControllerMappingForGUID( guid: TSDL_JoystickGUID ): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerMappingForGUID' {$ENDIF} {$ENDIF};

{**
 * Get the mapping at a particular index.
 *
 * Returns the mapping string. Must be freed with SDL_free().
 * Returns NIL if the index is out of range.
 *}
function SDL_GameControllerMappingForIndex(mapping_index: cint): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerMappingForIndex' {$ENDIF} {$ENDIF};

  {**
   *  Get a mapping string for an open GameController
   *
   *   the mapping string.  Must be freed with SDL_free.  Returns NULL if no mapping is available
   *}
function SDL_GameControllerMapping( gamecontroller: PSDL_GameController ): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerMapping' {$ENDIF} {$ENDIF};

  {**
   *  Is the joystick on this index supported by the game controller interface?
   *}
function SDL_IsGameController(joystick_index: cint): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_IsGameController' {$ENDIF} {$ENDIF};

  {**
   *  Get the implementation dependent name of a game controller.
   *  This can be called before any controllers are opened.
   *  If no name can be found, this function returns NULL.
   *}
function SDL_GameControllerNameForIndex(joystick_index: cint): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerNameForIndex' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent path for the game controller.
 *
 * This function can be called before any controllers are opened.
 *
 * `joystick_index` is the same as the `device_index` passed to
 * SDL_JoystickOpen().
 *
 * \param joystick_index the device_index of a device, from zero to
 *                       SDL_NumJoysticks()-1
 * \returns the implementation-dependent path for the game controller, or NIL
 *          if there is no path or the index is invalid.
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_GameControllerPath
 *}
function SDL_GameControllerPathForIndex(joystick_index: cint): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerPathForIndex' {$ENDIF} {$ENDIF};

{**
 * Get the type of a game controller.
 * This can be called before any controllers are opened.
 *}
function SDL_GameControllerTypeForIndex(joystick_index: cint): TSDL_GameControllerType; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerTypeForIndex' {$ENDIF} {$ENDIF};

{**
 * Get the mapping of a game controller.
 * This can be called before any controllers are opened.
 *
 * Returns the mapping string. Must be freed with SDL_free().
 * Returns NIL if no mapping is available.
 *}
function SDL_GameControllerMappingForDeviceIndex(joystick_index: cint): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerMappingForDeviceIndex' {$ENDIF} {$ENDIF};

  {**
   *  Open a game controller for use.
   *  The index passed as an argument refers to the N'th game controller on the system.
   *  This index is the value which will identify this controller in future controller
   *  events.
   *
   *   A controller identifier, or NULL if an error occurred.
   *}
function SDL_GameControllerOpen(joystick_index: cint): PSDL_GameController cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerOpen' {$ENDIF} {$ENDIF};

  {**
   * Return the SDL_GameController associated with an instance id.
   *}
function SDL_GameControllerFromInstanceID(joyid: TSDL_JoystickID): PSDL_GameController; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerFromInstanceID' {$ENDIF} {$ENDIF};

{**
 * Get the SDL_GameController associated with a player index.
 *
 * Please note that the player index is _not_ the device index, nor is it the
 * instance id!
 *
 *}
function SDL_GameControllerFromPlayerIndex(player_index: cint): PSDL_GameController; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerFromPlayerIndex' {$ENDIF} {$ENDIF};

  {**
   *  Return the name for this currently opened controller
   *}
function SDL_GameControllerName(gamecontroller: PSDL_GameController): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerName' {$ENDIF} {$ENDIF};

{**
 * Get the implementation-dependent path for an opened game controller.
 *
 * This is the same path as returned by SDL_GameControllerNameForIndex(), but
 * it takes a controller identifier instead of the (unstable) device index.
 *
 * \param gamecontroller a game controller identifier previously returned by
 *                       SDL_GameControllerOpen()
 * \returns the implementation dependent path for the game controller, or NIL
 *          if there is no path or the identifier passed is invalid.
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_GameControllerPathForIndex
 *}
function SDL_GameControllerPath(gamecontroller: PSDL_GameController): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerPath' {$ENDIF} {$ENDIF};

{**
 * Get the type of this currently opened controller
 *
 * This is the same name as returned by SDL_GameControllerTypeForIndex(), but
 * it takes a controller identifier instead of the (unstable) device index.
 *}
function SDL_GameControllerGetType(gamecontroller: PSDL_GameController): TSDL_GameControllerType; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetType' {$ENDIF} {$ENDIF};

{**
 * Get the player index of an opened game controller.
 * For XInput controllers this returns the XInput user index.
 *
 * Returns the player index for controller, or -1 if it's not available.
 *}
function SDL_GameControllerGetPlayerIndex(gamecontroller: PSDL_GameController): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetPlayerIndex' {$ENDIF} {$ENDIF};

{**
 * Set the player index of an opened game controller.
 *}
procedure SDL_GameControllerSetPlayerIndex(gamecontroller: PSDL_GameController; player_index: cint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerSetPlayerIndex' {$ENDIF} {$ENDIF};

{**
 * Get the USB vendor ID of an opened controller, if available.
 *
 * If the vendor ID isn't available this function returns 0.
 *
 * \param gamecontroller the game controller object to query.
 * \return the USB vendor ID, or zero if unavailable.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_GameControllerGetVendor(gamecontroller: PSDL_GameController): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetVendor' {$ENDIF} {$ENDIF};

{**
 * Get the USB product ID of an opened controller, if available.
 * If the product ID isn't available, this function returns 0.
 *}
function SDL_GameControllerGetProduct(gamecontroller: PSDL_GameController): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetProduct' {$ENDIF} {$ENDIF};

{**
 * Get the product version of an opened controller, if available.
 * If the product version isn't available, this function returns 0.
 *}
function SDL_GameControllerGetProductVersion(gamecontroller: PSDL_GameController): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetProductVersion' {$ENDIF} {$ENDIF};

{**
 * Get the firmware version of an opened controller, if available.
 *
 * If the firmware version isn't available this function returns 0.
 *
 * \param gamecontroller the game controller object to query.
 * \return the controller firmware version, or zero if unavailable.
 *
 * \since This function is available since SDL 2.24.0.
 *}
function SDL_GameControllerGetFirmwareVersion(gamecontroller: PSDL_GameController): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetFirmwareVersion' {$ENDIF} {$ENDIF};

{**
 * Get the serial number of an opened controller, if available.
 *
 * Returns a string containing the serial number of the controller,
 * or NIL if it is not available. Do _not_ free the string with SDL_free().
 *}
function SDL_GameControllerGetSerial(gamecontroller: PSDL_GameController): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetSerial' {$ENDIF} {$ENDIF};

{**
 * Get the Steam Input handle of an opened controller, if available.
 *
 * Returns an InputHandle_t for the controller that can be used with Steam Input API:
 * https://partner.steamgames.com/doc/api/ISteamInput
 *
 * \param gamecontroller the game controller object to query.
 * \returns the gamepad handle, or 0 if unavailable.
 *
 * \since This function is available since SDL 2.30.0.
 *}
function SDL_GameControllerGetSteamHandle(gamecontroller: PSDL_GameController): cuint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetSteamHandle' {$ENDIF} {$ENDIF};

  {**
   *  Returns SDL_TRUE if the controller has been opened and currently connected,
   *  or SDL_FALSE if it has not.
   *}
function SDL_GameControllerGetAttached(gamecontroller: PSDL_GameController): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetAttached' {$ENDIF} {$ENDIF};

  {**
   *  Get the underlying joystick object used by a controller
   *}
function SDL_GameControllerGetJoystick(gamecontroller: PSDL_GameController): PSDL_Joystick cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetJoystick' {$ENDIF} {$ENDIF};

  {**
   *  Enable/disable controller event polling.
   *
   *  If controller events are disabled, you must call SDL_GameControllerUpdate()
   *  yourself and check the state of the controller when you want controller
   *  information.
   *
   *  The state can be one of ::SDL_QUERY, ::SDL_ENABLE or ::SDL_IGNORE.
   *}
function SDL_GameControllerEventState(state: cint): cint cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerEventState' {$ENDIF} {$ENDIF};

  {**
   *  Update the current state of the open game controllers.
   *
   *  This is called automatically by the event loop if any game controller
   *  events are enabled.
   *}
procedure SDL_GameControllerUpdate() cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerUpdate' {$ENDIF} {$ENDIF};

  {**
   *  The list of axes available from a controller
   *}

type
  PPSDL_GameControllerAxis = ^PSDL_GameControllerAxis;
  PSDL_GameControllerAxis = ^TSDL_GameControllerAxis;
  TSDL_GameControllerAxis = type cint;
const
  SDL_CONTROLLER_AXIS_INVALID = TSDL_GameControllerAxis(-1);
  SDL_CONTROLLER_AXIS_LEFTX = TSDL_GameControllerAxis(0);
  SDL_CONTROLLER_AXIS_LEFTY = TSDL_GameControllerAxis(1);
  SDL_CONTROLLER_AXIS_RIGHTX = TSDL_GameControllerAxis(2);
  SDL_CONTROLLER_AXIS_RIGHTY = TSDL_GameControllerAxis(3);
  SDL_CONTROLLER_AXIS_TRIGGERLEFT = TSDL_GameControllerAxis(4);
  SDL_CONTROLLER_AXIS_TRIGGERRIGHT = TSDL_GameControllerAxis(5);
  SDL_CONTROLLER_AXIS_MAX = TSDL_GameControllerAxis(6);

  {**
   *  turn this string into a axis mapping
   *}
function SDL_GameControllerGetAxisFromString(pchString: PAnsiChar): TSDL_GameControllerAxis cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetAxisFromString' {$ENDIF} {$ENDIF};

  {**
   *  turn this axis enum into a string mapping
   *}
function SDL_GameControllerGetStringForAxis(axis: TSDL_GameControllerAxis): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetStringForAxis' {$ENDIF} {$ENDIF};

  {**
   *  Get the SDL joystick layer binding for this controller button mapping
   *}
function SDL_GameControllerGetBindForAxis(gamecontroller: PSDL_GameController; axis: TSDL_GameControllerAxis): TSDL_GameControllerButtonBind cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetBindForAxis' {$ENDIF} {$ENDIF};

{**
 * Query whether a game controller has a given axis.
 *
 * This merely reports whether the controller's mapping defined this axis,
 * as that is all the information SDL has about the physical device.
 *}
function SDL_GameControllerHasAxis(gamecontroller: PSDL_GameController; axis: TSDL_GameControllerAxis): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasAxis' {$ENDIF} {$ENDIF};

  {**
   *  Get the current state of an axis control on a game controller.
   *
   *  The state is a value ranging from -32768 to 32767.
   *
   *  The axis indices start at index 0.
   *}
function SDL_GameControllerGetAxis(gamecontroller: PSDL_GameController; axis: TSDL_GameControllerAxis): cint16 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetAxis' {$ENDIF} {$ENDIF};

  {**
   *  The list of buttons available from a controller
   *}
type
  PPSDL_GameControllerButton = ^PSDL_GameControllerButton;
  PSDL_GameControllerButton = ^TSDL_GameControllerButton;
  TSDL_GameControllerButton = type cint;
const
  SDL_CONTROLLER_BUTTON_INVALID       = TSDL_GameControllerButton(-1);
  SDL_CONTROLLER_BUTTON_A             = TSDL_GameControllerButton(0);
  SDL_CONTROLLER_BUTTON_B             = TSDL_GameControllerButton(1);
  SDL_CONTROLLER_BUTTON_X             = TSDL_GameControllerButton(2);
  SDL_CONTROLLER_BUTTON_Y             = TSDL_GameControllerButton(3);
  SDL_CONTROLLER_BUTTON_BACK          = TSDL_GameControllerButton(4);
  SDL_CONTROLLER_BUTTON_GUIDE         = TSDL_GameControllerButton(5);
  SDL_CONTROLLER_BUTTON_START         = TSDL_GameControllerButton(6);
  SDL_CONTROLLER_BUTTON_LEFTSTICK     = TSDL_GameControllerButton(7);
  SDL_CONTROLLER_BUTTON_RIGHTSTICK    = TSDL_GameControllerButton(8);
  SDL_CONTROLLER_BUTTON_LEFTSHOULDER  = TSDL_GameControllerButton(9);
  SDL_CONTROLLER_BUTTON_RIGHTSHOULDER = TSDL_GameControllerButton(10);
  SDL_CONTROLLER_BUTTON_DPAD_UP       = TSDL_GameControllerButton(11);
  SDL_CONTROLLER_BUTTON_DPAD_DOWN     = TSDL_GameControllerButton(12);
  SDL_CONTROLLER_BUTTON_DPAD_LEFT     = TSDL_GameControllerButton(13);
  SDL_CONTROLLER_BUTTON_DPAD_RIGHT    = TSDL_GameControllerButton(14);
  SDL_CONTROLLER_BUTTON_MISC1         = TSDL_GameControllerButton(15); {**< Xbox Series X share button, PS5 microphone button, Nintendo Switch Pro capture button, Amazon Luna microphone button *}
  SDL_CONTROLLER_BUTTON_PADDLE1       = TSDL_GameControllerButton(16); {**< Xbox Elite paddle P1 *}
  SDL_CONTROLLER_BUTTON_PADDLE2       = TSDL_GameControllerButton(17); {**< Xbox Elite paddle P3 *}
  SDL_CONTROLLER_BUTTON_PADDLE3       = TSDL_GameControllerButton(18); {**< Xbox Elite paddle P2 *}
  SDL_CONTROLLER_BUTTON_PADDLE4       = TSDL_GameControllerButton(19); {**< Xbox Elite paddle P4 *}
  SDL_CONTROLLER_BUTTON_TOUCHPAD      = TSDL_GameControllerButton(20); {**< PS4/PS5 touchpad button *}
  SDL_CONTROLLER_BUTTON_MAX           = TSDL_GameControllerButton(21);

  {**
   *  turn this string into a button mapping
   *}
function SDL_GameControllerGetButtonFromString(pchString: PAnsiChar): TSDL_GameControllerButton cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetButtonFromString' {$ENDIF} {$ENDIF};

  {**
   *  turn this button enum into a string mapping
   *}
function SDL_GameControllerGetStringForButton(button: TSDL_GameControllerButton): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetStringForButton' {$ENDIF} {$ENDIF};

{**
 *  Get the SDL joystick layer binding for this controller button mapping
 *}
function SDL_GameControllerGetBindForButton(gamecontroller: PSDL_GameController; button: TSDL_GameControllerButton): TSDL_GameControllerButtonBind cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetBindForButton' {$ENDIF} {$ENDIF};

{**
 * Query whether a game controller has a given button.
 *
 * This merely reports whether the controller's mapping defined this button,
 * as that is all the information SDL has about the physical device.
 *}
function SDL_GameControllerHasButton(gamecontroller: PSDL_GameController; button: TSDL_GameControllerButton): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasButton' {$ENDIF} {$ENDIF};

{**
 *  Get the current state of a button on a game controller.
 *
 *  The button indices start at index 0.
 *}
function SDL_GameControllerGetButton(gamecontroller: PSDL_GameController; button: TSDL_GameControllerButton): cuint8 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetButton' {$ENDIF} {$ENDIF};

{**
 * Get the number of touchpads on a game controller.
 *}
function SDL_GameControllerGetNumTouchpads(gamecontroller: PSDL_GameController): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetNumTouchpads' {$ENDIF} {$ENDIF};

{**
 * Get the number of supported simultaneous fingers on a touchpad on a game controller.
 *}
function SDL_GameControllerGetNumTouchpadFingers(gamecontroller: PSDL_GameController; touchpad: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetNumTouchpadFingers' {$ENDIF} {$ENDIF};

{**
 * Get the current state of a finger on a touchpad on a game controller.
 *}
function SDL_GameControllerGetTouchpadFinger(
  gamecontroller: PSDL_GameController;
  touchpad, finger: cint;
  state: pcuint8;
  x, y, pressure: pcfloat
): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetTouchpadFinger' {$ENDIF} {$ENDIF};

{**
 * Return whether a game controller has a particular sensor.
 *}
function SDL_GameControllerHasSensor(gamecontroller: PSDL_GameController; senstype: TSDL_SensorType): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasSensor' {$ENDIF} {$ENDIF};

{**
 * Set whether data reporting for a game controller sensor is enabled.
 *}
function SDL_GameControllerSetSensorEnabled(gamecontroller: PSDL_GameController; senstype: TSDL_SensorType; enabled: TSDL_bool): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerSetSensorEnabled' {$ENDIF} {$ENDIF};

{**
 * Query whether sensor data reporting is enabled for a game controller.
 *}
function SDL_GameControllerIsSensorEnabled(gamecontroller: PSDL_GameController; senstype: TSDL_SensorType): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerIsSensorEnabled' {$ENDIF} {$ENDIF};

{**
 * Get the data rate (number of events per second) of
 * a game controller sensor.
 *
 * Returns the data rate, or 0.0 if the data rate is not available.
 *}
function SDL_GameControllerGetSensorDataRate(gamecontroller: PSDL_GameController; senstype: TSDL_SensorType): cfloat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetSensorDataRate' {$ENDIF} {$ENDIF};

{**
 * Get the current state of a game controller sensor.
 *
 * The number of values and interpretation of the data is sensor dependent.
 * See sdlsensor.inc for the details for each type of sensor.
 *}
function SDL_GameControllerGetSensorData(gamecontroller: PSDL_GameController; senstype: TSDL_SensorType; data: pcfloat; num_values: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetSensorData' {$ENDIF} {$ENDIF};

{**
 * Get the current state of a game controller sensor with the timestamp of the
 * last update.
 *
 * The number of values and interpretation of the data is sensor dependent.
 * See SDL_sensor.h for the details for each type of sensor.
 *
 * \param gamecontroller The controller to query
 * \param type The type of sensor to query
 * \param timestamp A pointer filled with the timestamp in microseconds of the
 *                  current sensor reading if available, or 0 if not
 * \param data A pointer filled with the current sensor state
 * \param num_values The number of values to write to data
 * \return 0 or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.26.0.
 *}
function SDL_GameControllerGetSensorDataWithTimestamp(
  gamecontroller: PSDL_GameController;
  senstype: TSDL_SensorType;
  timestamp: pcuint64;
  data: pcfloat;
  num_values: cint
): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetSensorDataWithTimestamp' {$ENDIF} {$ENDIF};

{**
 * Query whether a game controller has rumble support.
 *}
function SDL_GameControllerHasRumble(gamecontroller: PSDL_GameController): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasRumble' {$ENDIF} {$ENDIF};

{**
 * Start a rumble effect on a game controller.
 *
 * Each call to this function cancels any previous rumble effect, and calling
 * it with 0 intensity stops any rumbling.
 *
 * Returns 0, or -1 if rumble isn't supported on this controller.
 *}
function SDL_GameControllerRumble(
  gamecontroller: PSDL_GameController;
  low_frequency_rumble, high_frequency_rumble: cuint16;
  duration_ms: cuint32
): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerRumble' {$ENDIF} {$ENDIF};

{**
 * Query whether a game controller has rumble support on triggers.
 *}
function SDL_GameControllerHasRumbleTriggers(gamecontroller: PSDL_GameController): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasRumbleTriggers' {$ENDIF} {$ENDIF};

{**
 * Start a rumble effect in the game controller's triggers.
 *
 * Each call to this function cancels any previous trigger rumble effect, and
 * calling it with 0 intensity stops any rumbling.
 *
 * Note that this is rumbling of the _triggers_ and not the game controller as
 * a whole. This is currently only supported on Xbox One controllers. If you
 * want the (more common) whole-controller rumble, use
 * SDL_GameControllerRumble() instead.
 *
 * Returns 0, or -1 if trigger rumble isn't supported on this controller
 *}
function SDL_GameControllerRumbleTriggers(
  gamecontroller: PSDL_GameController;
  left_rumble, right_rumble: cuint16;
  duration_ms: cuint32
): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerRumbleTriggers' {$ENDIF} {$ENDIF};

{**
 * Query whether a game controller has an LED.
 *}
function SDL_GameControllerHasLED(gamecontroller: PSDL_GameController): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerHasLED' {$ENDIF} {$ENDIF};

{**
 * Update a game controller's LED color.
 *
 * Returns 0, or -1 if this controller does not have a modifiable LED.
 *}
function SDL_GameControllerSetLED(gamecontroller: PSDL_GameController; red, green, blue: cuint8): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerSetLED' {$ENDIF} {$ENDIF};

{**
 * Send a controller-specific effect packet.
 *
 * Returns 0, or -1 if this controller or driver does not
 * support effect packets.
 *}
function SDL_GameControllerSendEffect(gamecontroller: PSDL_GameController; data: Pointer; size: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerSendEffect' {$ENDIF} {$ENDIF};

{**
 *  Close a controller previously opened with SDL_GameControllerOpen().
 *}
procedure SDL_GameControllerClose(gamecontroller: PSDL_GameController) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerClose' {$ENDIF} {$ENDIF};

{**
 * Return the sfSymbolsName for a given axis on a game controller
 * on Apple platforms.
 *
 * Returns the sfSymbolsName, or NIL if the name can't be found.
 * Do _not_ pass this string to SDL_free().
 *}
function SDL_GameControllerGetAppleSFSymbolsNameForAxis(gamecontroller: PSDL_GameController; axis: TSDL_GameControllerAxis): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetAppleSFSymbolsNameForAxis' {$ENDIF} {$ENDIF};

{**
 * Return the sfSymbolsName for a given button on a game controller
 * on Apple platforms.
 *
 * Returns the sfSymbolsName, or NIL if the name can't be found.
 * Do _not_ pass this string to SDL_free().
 *}
function SDL_GameControllerGetAppleSFSymbolsNameForButton(gamecontroller: PSDL_GameController; button: TSDL_GameControllerButton): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GameControllerGetAppleSFSymbolsNameForButton' {$ENDIF} {$ENDIF};


function SDL_GameControllerAddMappingsFromFile(Const FilePath:PAnsiChar):cint32;
