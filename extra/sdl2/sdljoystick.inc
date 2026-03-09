{**
 *  \file SDL_joystick.h
 *
 *  Include file for SDL joystick event handling
 *
 * The term "device_index" identifies currently plugged in joystick devices between 0 and SDL_NumJoysticks(), with the exact joystick
 *   behind a device_index changing as joysticks are plugged and unplugged.
 *
 * The term "instance_id" is the current instantiation of a joystick device in the system, if the joystick is removed and then re-inserted
 *   then it will get a new instance_id, instance_id's are monotonically increasing identifiers of a joystick plugged in.
 *
 * The term JoystickGUID is a stable 128-bit identifier for a joystick device that does not change over time, it identifies class of
 *   the device (a X360 wired controller for example). This identifier is platform dependent.
 *
 *
 *}

 {**
  *  \file SDL_joystick.h
  *
  *  In order to use these functions, SDL_Init() must have been called
  *  with the ::SDL_INIT_JOYSTICK flag.  This causes SDL to scan the system
  *  for joysticks, and load appropriate drivers.
  *
  *  If you would like to receive joystick updates while the application
  *  is in the background, you should set the following hint before calling
  *  SDL_Init(): SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS
  *}

type
  {* The joystick structure used to identify an SDL joystick *}
  PPSDL_Joystick = ^PSDL_Joystick;
  PSDL_Joystick = type Pointer;

  {* A structure that encodes the stable unique id for a joystick device *}
  PPSDL_JoystickGUID = ^PSDL_JoystickGUID;
  PSDL_JoystickGUID = ^TSDL_JoystickGUID;
  TSDL_JoystickGUID = type TSDL_GUID;

 {**
  * This is a unique ID for a joystick for the time it is connected to the system,
  * and is never reused for the lifetime of the application. If the joystick is
  * disconnected and reconnected, it will get a new ID.
  *
  * The ID value starts at 0 and increments from there. The value -1 is an invalid ID.
  *}
  PPSDL_JoystickID = ^PSDL_JoystickID;
  PSDL_JoystickID = ^TSDL_JoystickID;
  TSDL_JoystickID = type cint32;

type
  PPSDL_JoystickType = ^PSDL_JoystickType;
  PSDL_JoystickType = ^TSDL_JoystickType;
  TSDL_JoystickType = type Integer;

const
  SDL_JOYSTICK_TYPE_UNKNOWN        = TSDL_JoystickType(0);
  SDL_JOYSTICK_TYPE_GAMECONTROLLER = TSDL_JoystickType(1);
  SDL_JOYSTICK_TYPE_WHEEL          = TSDL_JoystickType(2);
  SDL_JOYSTICK_TYPE_ARCADE_STICK   = TSDL_JoystickType(3);
  SDL_JOYSTICK_TYPE_FLIGHT_STICK   = TSDL_JoystickType(4);
  SDL_JOYSTICK_TYPE_DANCE_PAD      = TSDL_JoystickType(5);
  SDL_JOYSTICK_TYPE_GUITAR         = TSDL_JoystickType(6);
  SDL_JOYSTICK_TYPE_DRUM_KIT       = TSDL_JoystickType(7);
  SDL_JOYSTICK_TYPE_ARCADE_PAD     = TSDL_JoystickType(8);
  SDL_JOYSTICK_TYPE_THROTTLE       = TSDL_JoystickType(9);

type
  PPSDL_JoystickPowerLevel = ^PSDL_JoystickPowerLevel;
  PSDL_JoystickPowerLevel = ^TSDL_JoystickPowerLevel;
  TSDL_JoystickPowerLevel = type Integer;

const
  SDL_JOYSTICK_POWER_UNKNOWN = TSDL_JoystickPowerLevel(-1);
  SDL_JOYSTICK_POWER_EMPTY   = TSDL_JoystickPowerLevel(0);  {* <= 5% *}
  SDL_JOYSTICK_POWER_LOW     = TSDL_JoystickPowerLevel(1);  {* <= 20% *}
  SDL_JOYSTICK_POWER_MEDIUM  = TSDL_JoystickPowerLevel(2);  {* <= 70% *}
  SDL_JOYSTICK_POWER_FULL    = TSDL_JoystickPowerLevel(3);  {* <= 100% *}
  SDL_JOYSTICK_POWER_WIRED   = TSDL_JoystickPowerLevel(4);
  SDL_JOYSTICK_POWER_MAX     = TSDL_JoystickPowerLevel(5);

  {* Set max recognized G-force from accelerometer
     See src/joystick/uikit/SDL_sysjoystick.m for notes on why this is needed
   *}
const
  SDL_IPHONE_MAX_GFORCE = 5.0;

{* Function prototypes *}

{**
 * Locking for multi-threaded access to the joystick API
 *
 * If you are using the joystick API or handling events from multiple threads
 * you should use these locking functions to protect access to the joysticks.
 *
 * In particular, you are guaranteed that the joystick list won't change, so
 * the API functions that take a joystick index will be valid, and joystick
 * and game controller events will not be delivered.
 *
 * As of SDL 2.26.0, you can take the joystick lock around reinitializing the
 * joystick subsystem, to prevent other threads from seeing joysticks in an
 * uninitialized state. However, all open joysticks will be closed and SDL
 * functions called with them will fail.
 *
 * \since This function is available since SDL 2.0.7.
 *}
procedure SDL_LockJoysticks(); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LockJoysticks' {$ENDIF} {$ENDIF};

{**
 * Unlocking for multi-threaded access to the joystick API
 *
 * If you are using the joystick API or handling events from multiple threads
 * you should use these locking functions to protect access to the joysticks.
 *
 * In particular, you are guaranteed that the joystick list won't change, so
 * the API functions that take a joystick index will be valid, and joystick
 * and game controller events will not be delivered.
 *
 * \since This function is available since SDL 2.0.7.
 *}
procedure SDL_UnlockJoysticks(); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UnlockJoysticks' {$ENDIF} {$ENDIF};

{**
 * Count the number of joysticks attached to the system.
 *
 * \returns the number of attached joysticks on success or a negative error
 *          code on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickName
 * \sa SDL_JoystickPath
 * \sa SDL_JoystickOpen
 *}
function SDL_NumJoysticks(): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_NumJoysticks' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent name of a joystick.
 *
 * This can be called before any joysticks are opened.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system)
 * \returns the name of the selected joystick. If no name can be found, this
 *          function returns NULL; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickName
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickNameForIndex(device_index: cint): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickNameForIndex' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent path of a joystick.
 *
 * This can be called before any joysticks are opened.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system)
 * \returns the path of the selected joystick. If no path can be found, this
 *          function returns NULL; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_JoystickPath
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickPathForIndex(device_index: cint): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickPathForIndex' {$ENDIF} {$ENDIF};

{**
 * Get the player index of a joystick, or -1 if it's not available This can be
 * called before any joysticks are opened.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_JoystickGetDevicePlayerIndex(device_index: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDevicePlayerIndex' {$ENDIF} {$ENDIF};

{**
 *  Return the GUID for the joystick at this index
 *  This can be called before any joysticks are opened.
 *}
function SDL_JoystickGetDeviceGUID(device_index: cint): TSDL_JoystickGUID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceGUID' {$ENDIF} {$ENDIF};

{**
 * Get the USB vendor ID of a joystick, if available.
 *
 * This can be called before any joysticks are opened. If the vendor ID isn't
 * available this function returns 0.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system
 * \returns the USB vendor ID of the selected joystick. If called on an
 *          invalid index, this function returns zero
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetDeviceVendor(device_index: cint): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceVendor' {$ENDIF} {$ENDIF};

{**
 * Get the USB product ID of a joystick, if available.
 *
 * This can be called before any joysticks are opened. If the product ID isn't
 * available this function returns 0.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system
 * \returns the USB product ID of the selected joystick. If called on an
 *          invalid index, this function returns zero
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetDeviceProduct(device_index: cint): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceProduct' {$ENDIF} {$ENDIF};

{**
 * Get the product version of a joystick, if available.
 *
 * This can be called before any joysticks are opened. If the product version
 * isn't available this function returns 0.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system
 * \returns the product version of the selected joystick. If called on an
 *          invalid index, this function returns zero
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetDeviceProductVersion(device_index: cint): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceProductVersion' {$ENDIF} {$ENDIF};

{**
 * Get the type of a joystick, if available.
 *
 * This can be called before any joysticks are opened.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system
 * \returns the SDL_JoystickType of the selected joystick. If called on an
 *          invalid index, this function returns `SDL_JOYSTICK_TYPE_UNKNOWN`
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetDeviceType(device_index: cint): TSDL_JoystickType; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceType' {$ENDIF} {$ENDIF};

{**
 * Get the instance ID of a joystick.
 *
 * This can be called before any joysticks are opened. If the index is out of
 * range, this function will return -1.
 *
 * \param device_index the index of the joystick to query (the N'th joystick
 *                     on the system
 * \returns the instance id of the selected joystick. If called on an invalid
 *          index, this function returns zero
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetDeviceInstanceID(device_index: cint): TSDL_JoystickID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetDeviceInstanceID' {$ENDIF} {$ENDIF};

{**
 * Open a joystick for use.
 *
 * The `device_index` argument refers to the N'th joystick presently
 * recognized by SDL on the system. It is **NOT** the same as the instance ID
 * used to identify the joystick in future events. See
 * SDL_JoystickInstanceID() for more details about instance IDs.
 *
 * The joystick subsystem must be initialized before a joystick can be opened
 * for use.
 *
 * \param device_index the index of the joystick to query
 * \returns a joystick identifier or NULL if an error occurred; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickClose
 * \sa SDL_JoystickInstanceID
 *}
function SDL_JoystickOpen(device_index: cint): PSDL_Joystick; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickOpen' {$ENDIF} {$ENDIF};

{**
 * Get the SDL_Joystick associated with an instance id.
 *
 * \param instance_id the instance id to get the SDL_Joystick for
 * \returns an SDL_Joystick on success or NULL on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.4.
 *}
function SDL_JoystickFromInstanceID(instance_id: TSDL_JoystickID): PSDL_Joystick; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickFromInstanceID' {$ENDIF} {$ENDIF};

{**
 * Get the SDL_Joystick associated with a player index.
 *
 * \param player_index the player index to get the SDL_Joystick for
 * \returns an SDL_Joystick on success or NULL on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.12.
 *}
function SDL_JoystickFromPlayerIndex(player_index: cint): PSDL_Joystick; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickFromPlayerIndex' {$ENDIF} {$ENDIF};

{**
 * Attach a new virtual joystick.
 *
 * \returns the joystick's device index, or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickAttachVirtual(type_: TSDL_JoystickType; naxes: cint; nbuttons: cint; nhats: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickAttachVirtual' {$ENDIF} {$ENDIF};

type
  {**
 * The structure that defines an extended virtual joystick description
 *
 * The caller must zero the structure and then initialize the version with `SDL_VIRTUAL_JOYSTICK_DESC_VERSION` before passing it to SDL_JoystickAttachVirtualEx()
 *  All other elements of this structure are optional and can be left 0.
 *
 * \sa SDL_JoystickAttachVirtualEx
 *}
  TUpdateProc = procedure(userdata: Pointer); cdecl;
  TSetPlayerIndexProc = procedure(userdata: Pointer; player_index: cint); cdecl;
  TRumbleFunc = function(userdata: Pointer; low_frequency_rumble: cuint16; high_frequency_rumble: cuint16): cint; cdecl;
  TRumbleTriggersFunc = function(userdata: Pointer; left_rumble: cuint16; right_rumble: cuint16): cint; cdecl;
  TSetLEDFunc = function(userdata: Pointer; red: cuint8; green: cuint8; blue: cuint8): cint; cdecl;
  TSendEffectFunc = function(userdata: Pointer; const data: Pointer; size: cint): cint; cdecl;

  PPSDL_VirtualJoystickDesc = ^PSDL_VirtualJoystickDesc;
  PSDL_VirtualJoystickDesc = ^TSDL_VirtualJoystickDesc;
  TSDL_VirtualJoystickDesc = record
    version: cuint16;     {**< `SDL_VIRTUAL_JOYSTICK_DESC_VERSION` *}
    type_: cuint16;       {**< `SDL_JoystickType` }
    naxes: cuint16;       {**< the number of axes on this joystick *}
    nbuttons: cuint16;    {**< the number of buttons on this joystick *}
    nhats: cuint16;       {**< the number of hats on this joystick *}
    vendor_id: cuint16;   {**< the USB vendor ID of this joystick *}
    product_id: cuint16;  {**< the USB product ID of this joystick *}
    padding: cuint16;     {**< unused *}
    button_mask: cuint16; {**< A mask of which buttons are valid for this controller
                             e.g. (1 << SDL_CONTROLLER_BUTTON_A) *}
    axis_mask: cuint32;   {**< A mask of which axes are valid for this controller
                             e.g. (1 << SDL_CONTROLLER_AXIS_LEFTX) *}
    name: PAnsiChar;      {**< the name of the joystick *}

    userdata: Pointer;    {**< User data pointer passed to callbacks *}
    Update: TUpdateProc;  {**< Called when the joystick state should be updated *}
    SetPlayerIndex: TSetPlayerIndexProc;     {**< Called when the player index is set *}
    Rumble: TRumbleFunc;                 {**< Implements SDL_JoystickRumble() *}
    RumbleTriggers: TRumbleTriggersFunc; {**< Implements SDL_JoystickRumbleTriggers() *}
    SetLED: TSetLEDFunc;                 {**< Implements SDL_JoystickSetLED() *}
    SendEffect: TSendEffectFunc;         {**< Implements SDL_JoystickSendEffect() *}
  end;

{**
 * \brief The current version of the SDL_VirtualJoystickDesc structure
 *}
const
  SDL_VIRTUAL_JOYSTICK_DESC_VERSION = 1;

{/**
 * Attach a new virtual joystick with extended properties.
 *
 * \returns the joystick's device index, or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.24.0.
 */}
function SDL_JoystickAttachVirtualEx(const desc: PSDL_VirtualJoystickDesc): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickAttachVirtualEx' {$ENDIF} {$ENDIF};

{**
 * Detach a virtual joystick.
 *
 * \param device_index a value previously returned from
 *                     SDL_JoystickAttachVirtual()
 * \returns 0 on success, or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickDetachVirtual(device_index: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickDetachVirtual' {$ENDIF} {$ENDIF};

{**
 * Query whether or not the joystick at a given device index is virtual.
 *
 * \param device_index a joystick device index.
 * \returns SDL_TRUE if the joystick is virtual, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickIsVirtual(device_index: cint): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickIsVirtual' {$ENDIF} {$ENDIF};

{**
 * Set values on an opened, virtual-joystick's axis.
 *
 * Please note that values set here will not be applied until the next call to
 * SDL_JoystickUpdate, which can either be called directly, or can be called
 * indirectly through various other SDL APIs, including, but not limited to
 * the following: SDL_PollEvent, SDL_PumpEvents, SDL_WaitEventTimeout,
 * SDL_WaitEvent.
 *
 * Note that when sending trigger axes, you should scale the value to the full
 * range of Sint16. For example, a trigger at rest would have the value of
 * `SDL_JOYSTICK_AXIS_MIN`.
 *
 * \param joystick the virtual joystick on which to set state.
 * \param axis the specific axis on the virtual joystick to set.
 * \param value the new value for the specified axis.
 * \returns 0 on success, -1 on error.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickSetVirtualAxis(joystick: PSDL_Joystick; axis: cint; value: cint16): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSetVirtualAxis' {$ENDIF} {$ENDIF};

{**
 * Set values on an opened, virtual-joystick's button.
 *
 * Please note that values set here will not be applied until the next call to
 * SDL_JoystickUpdate, which can either be called directly, or can be called
 * indirectly through various other SDL APIs, including, but not limited to
 * the following: SDL_PollEvent, SDL_PumpEvents, SDL_WaitEventTimeout,
 * SDL_WaitEvent.
 *
 * \param joystick the virtual joystick on which to set state.
 * \param button the specific button on the virtual joystick to set.
 * \param value the new value for the specified button.
 * \returns 0 on success, -1 on error.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickSetVirtualButton(joystick: PSDL_Joystick; button: cint; value: cuint8): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSetVirtualButton' {$ENDIF} {$ENDIF};

{**
 * Set values on an opened, virtual-joystick's hat.
 *
 * Please note that values set here will not be applied until the next call to
 * SDL_JoystickUpdate, which can either be called directly, or can be called
 * indirectly through various other SDL APIs, including, but not limited to
 * the following: SDL_PollEvent, SDL_PumpEvents, SDL_WaitEventTimeout,
 * SDL_WaitEvent.
 *
 * \param joystick the virtual joystick on which to set state.
 * \param hat the specific hat on the virtual joystick to set.
 * \param value the new value for the specified hat.
 * \returns 0 on success, -1 on error.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickSetVirtualHat(joystick: PSDL_Joystick; hat: cint; value: cuint8): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSetVirtualHat' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent name of a joystick.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the name of the selected joystick. If no name can be found, this
 *          function returns NULL; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickNameForIndex
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickName(joystick: PSDL_Joystick): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickName' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent path of a joystick.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the path of the selected joystick. If no path can be found, this
 *          function returns NULL; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_JoystickPathForIndex
 *}
function SDL_JoystickPath(joystick: PSDL_Joystick): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickPath' {$ENDIF} {$ENDIF};

{**
 * Get the player index of an opened joystick.
 *
 * For XInput controllers this returns the XInput user index. Many joysticks
 * will not be able to supply this information.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the player index, or -1 if it's not available.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_JoystickGetPlayerIndex(joystick: PSDL_Joystick): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetPlayerIndex' {$ENDIF} {$ENDIF};

{**
 * Set the player index of an opened joystick.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \param player_index Player index to assign to this joystick, or -1 to clear
 *                     the player index and turn off player LEDs.
 *
 * \since This function is available since SDL 2.0.12.
 *}
procedure SDL_JoystickSetPlayerIndex(joystick: PSDL_Joystick; player_index: cint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSetPlayerIndex' {$ENDIF} {$ENDIF};

{**
 * Get the implementation-dependent GUID for the joystick.
 *
 * This function requires an open joystick.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the GUID of the given joystick. If called on an invalid index,
 *          this function returns a zero GUID; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetDeviceGUID
 * \sa SDL_JoystickGetGUIDString
 *}
function SDL_JoystickGetGUID(joystick: PSDL_Joystick): TSDL_JoystickGUID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetGUID' {$ENDIF} {$ENDIF};

{**
 * Get the USB vendor ID of an opened joystick, if available.
 *
 * If the vendor ID isn't available this function returns 0.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the USB vendor ID of the selected joystick, or 0 if unavailable.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetVendor(joystick: PSDL_Joystick): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetVendor' {$ENDIF} {$ENDIF};

{**
 * Get the USB product ID of an opened joystick, if available.
 *
 * If the product ID isn't available this function returns 0.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the USB product ID of the selected joystick, or 0 if unavailable.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetProduct(joystick: PSDL_Joystick): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetProduct' {$ENDIF} {$ENDIF};

{**
 * Get the product version of an opened joystick, if available.
 *
 * If the product version isn't available this function returns 0.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the product version of the selected joystick, or 0 if unavailable.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetProductVersion(joystick: PSDL_Joystick): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetProductVersion' {$ENDIF} {$ENDIF};

{**
 * Get the firmware version of an opened joystick, if available.
 *
 * If the firmware version isn't available this function returns 0.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the firmware version of the selected joystick, or 0 if
 *          unavailable.
 *
 * \since This function is available since SDL 2.24.0.
 *}
function SDL_JoystickGetFirmwareVersion(joystick: PSDL_Joystick): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetFirmwareVersion' {$ENDIF} {$ENDIF};

{**
 * Get the serial number of an opened joystick, if available.
 *
 * Returns the serial number of the joystick, or NULL if it is not available.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the serial number of the selected joystick, or NULL if
 *          unavailable.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickGetSerial(joystick: PSDL_Joystick): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetSerial' {$ENDIF} {$ENDIF};

{**
 * Get the type of an opened joystick.
 *
 * \param joystick the SDL_Joystick obtained from SDL_JoystickOpen()
 * \returns the SDL_JoystickType of the selected joystick.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetType(joystick: PSDL_Joystick): TSDL_JoystickType; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetType' {$ENDIF} {$ENDIF};

{**
 * Get an ASCII string representation for a given SDL_JoystickGUID.
 *
 * You should supply at least 33 bytes for pszGUID.
 *
 * \param guid the SDL_JoystickGUID you wish to convert to string
 * \param pszGUID buffer in which to write the ASCII string
 * \param cbGUID the size of pszGUID
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetDeviceGUID
 * \sa SDL_JoystickGetGUID
 * \sa SDL_JoystickGetGUIDFromString
 *}
procedure SDL_JoystickGetGUIDString(guid: TSDL_JoystickGUID; pszGUID: PAnsiChar; cbGUID: cint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetGUIDString' {$ENDIF} {$ENDIF};

{**
 * Convert a GUID string into a SDL_JoystickGUID structure.
 *
 * Performs no error checking. If this function is given a string containing
 * an invalid GUID, the function will silently succeed, but the GUID generated
 * will not be useful.
 *
 * \param pchGUID string containing an ASCII representation of a GUID
 * \returns a SDL_JoystickGUID structure.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetGUIDString
 *}
function SDL_JoystickGetGUIDFromString(const pchGUID: PAnsiChar): TSDL_JoystickGUID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetGUIDFromString' {$ENDIF} {$ENDIF};

{**
 * Get the device information encoded in a SDL_JoystickGUID structure
 *
 * \param guid the SDL_JoystickGUID you wish to get info about
 * \param vendor A pointer filled in with the device VID, or 0 if not
 *               available
 * \param product A pointer filled in with the device PID, or 0 if not
 *                available
 * \param version A pointer filled in with the device version, or 0 if not
 *                available
 * \param crc16 A pointer filled in with a CRC used to distinguish different
 *              products with the same VID/PID, or 0 if not available
 *
 * \since This function is available since SDL 2.26.0.
 *
 * \sa SDL_JoystickGetDeviceGUID
 *}
procedure SDL_GetJoystickGUIDInfo(guid: TSDL_JoystickGUID; vendor: pcuint16; product: pcuint16; version: pcuint16; crc16: pcuint16); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetJoystickGUIDInfo' {$ENDIF} {$ENDIF};

{**
 * Get the status of a specified joystick.
 *
 * \param joystick the joystick to query
 * \returns SDL_TRUE if the joystick has been opened, SDL_FALSE if it has not;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickClose
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickGetAttached(joystick: PSDL_Joystick): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetAttached' {$ENDIF} {$ENDIF};

{**
 * Get the instance ID of an opened joystick.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \returns the instance ID of the specified joystick on success or a negative
 *          error code on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickInstanceID(joystick: PSDL_Joystick): TSDL_JoystickID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickInstanceID' {$ENDIF} {$ENDIF};

{**
 * Get the number of general axis controls on a joystick.
 *
 * Often, the directional pad on a game controller will either look like 4
 * separate buttons or a POV hat, and not axes, but all of this is up to the
 * device and platform.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \returns the number of axis controls/number of axes on success or a
 *          negative error code on failure; call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetAxis
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickNumAxes(joystick: PSDL_Joystick): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickNumAxes' {$ENDIF} {$ENDIF};

{**
 * Get the number of trackballs on a joystick.
 *
 * Joystick trackballs have only relative motion events associated with them
 * and their state cannot be polled.
 *
 * Most joysticks do not have trackballs.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \returns the number of trackballs on success or a negative error code on
 *          failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetBall
 *}
function SDL_JoystickNumBalls(joystick: PSDL_Joystick): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickNumBalls' {$ENDIF} {$ENDIF};

{**
 * Get the number of POV hats on a joystick.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \returns the number of POV hats on success or a negative error code on
 *          failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetHat
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickNumHats(joystick: PSDL_Joystick): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickNumHats' {$ENDIF} {$ENDIF};

{**
 * Get the number of buttons on a joystick.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \returns the number of buttons on success or a negative error code on
 *          failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickGetButton
 * \sa SDL_JoystickOpen
 *}
function SDL_JoystickNumButtons(joystick: PSDL_Joystick): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickNumButtons' {$ENDIF} {$ENDIF};

{**
 * Update the current state of the open joysticks.
 *
 * This is called automatically by the event loop if any joystick events are
 * enabled.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickEventState
 *}
procedure SDL_JoystickUpdate(); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickUpdate' {$ENDIF} {$ENDIF};

{**
 * Enable/disable joystick event polling.
 *
 * If joystick events are disabled, you must call SDL_JoystickUpdate()
 * yourself and manually check the state of the joystick when you want
 * joystick information.
 *
 * It is recommended that you leave joystick event handling enabled.
 *
 * **WARNING**: Calling this function may delete all events currently in SDL's
 * event queue.
 *
 * \param state can be one of `SDL_QUERY`, `SDL_IGNORE`, or `SDL_ENABLE`
 * \returns 1 if enabled, 0 if disabled, or a negative error code on failure;
 *          call SDL_GetError() for more information.
 *
 *          If `state` is `SDL_QUERY` then the current state is returned,
 *          otherwise the new processing state is returned.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GameControllerEventState
 *}
function SDL_JoystickEventState(state: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickEventState' {$ENDIF} {$ENDIF};

const
  SDL_JOYSTICK_AXIS_MAX = 32767;
  SDL_JOYSTICK_AXIS_MIN = -32768;

{**
 * Get the current state of an axis control on a joystick.
 *
 * SDL makes no promises about what part of the joystick any given axis refers
 * to. Your game should have some sort of configuration UI to let users
 * specify what each axis should be bound to. Alternately, SDL's higher-level
 * Game Controller API makes a great effort to apply order to this lower-level
 * interface, so you know that a specific axis is the "left thumb stick," etc.
 *
 * The value returned by SDL_JoystickGetAxis() is a signed integer (-32768 to
 * 32767) representing the current position of the axis. It may be necessary
 * to impose certain tolerances on these values to account for jitter.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \param axis the axis to query; the axis indices start at index 0
 * \returns a 16-bit signed integer representing the current position of the
 *          axis or 0 on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickNumAxes
 *}
function SDL_JoystickGetAxis(joystick: PSDL_Joystick; axis: cint): cint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetAxis' {$ENDIF} {$ENDIF};

{**
 * Get the initial state of an axis control on a joystick.
 *
 * The state is a value ranging from -32768 to 32767.
 *
 * The axis indices start at index 0.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \param axis the axis to query; the axis indices start at index 0
 * \param state Upon return, the initial value is supplied here.
 * \return SDL_TRUE if this axis has any initial value, or SDL_FALSE if not.
 *
 * \since This function is available since SDL 2.0.6.
 *}
function SDL_JoystickGetAxisInitialState(joystick: PSDL_Joystick; axis: cint; state: pcint16): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetAxisInitialState' {$ENDIF} {$ENDIF};

{**
 *  Hat positions
 *}
const
  SDL_HAT_CENTERED  = $00;
  SDL_HAT_UP        = $01;
  SDL_HAT_RIGHT     = $02;
  SDL_HAT_DOWN      = $04;
  SDL_HAT_LEFT      = $08;
  SDL_HAT_RIGHTUP   = SDL_HAT_RIGHT or SDL_HAT_UP;
  SDL_HAT_RIGHTDOWN = SDL_HAT_RIGHT or SDL_HAT_DOWN;
  SDL_HAT_LEFTUP    = SDL_HAT_LEFT or SDL_HAT_UP;
  SDL_HAT_LEFTDOWN  = SDL_HAT_LEFT or SDL_HAT_DOWN;

{**
 * Get the current state of a POV hat on a joystick.
 *
 * The returned value will be one of the following positions:
 *
 * - `SDL_HAT_CENTERED`
 * - `SDL_HAT_UP`
 * - `SDL_HAT_RIGHT`
 * - `SDL_HAT_DOWN`
 * - `SDL_HAT_LEFT`
 * - `SDL_HAT_RIGHTUP`
 * - `SDL_HAT_RIGHTDOWN`
 * - `SDL_HAT_LEFTUP`
 * - `SDL_HAT_LEFTDOWN`
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \param hat the hat index to get the state from; indices start at index 0
 * \returns the current hat position.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickNumHats
 *}
function SDL_JoystickGetHat(joystick: PSDL_Joystick; hat: cint): cuint8; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetHat' {$ENDIF} {$ENDIF};

{**
 * Get the ball axis change since the last poll.
 *
 * Trackballs can only return relative motion since the last call to
 * SDL_JoystickGetBall(), these motion deltas are placed into `dx` and `dy`.
 *
 * Most joysticks do not have trackballs.
 *
 * \param joystick the SDL_Joystick to query
 * \param ball the ball index to query; ball indices start at index 0
 * \param dx stores the difference in the x axis position since the last poll
 * \param dy stores the difference in the y axis position since the last poll
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickNumBalls
 *}
function SDL_JoystickGetBall(joystick: PSDL_Joystick; ball: cint; dx: pcint; dy: pcint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetBall' {$ENDIF} {$ENDIF};

{**
 * Get the current state of a button on a joystick.
 *
 * \param joystick an SDL_Joystick structure containing joystick information
 * \param button the button index to get the state from; indices start at
 *               index 0
 * \returns 1 if the specified button is pressed, 0 otherwise.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickNumButtons
 *}
function SDL_JoystickGetButton(joystick: PSDL_Joystick; button: cint): cuint8; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickGetButton' {$ENDIF} {$ENDIF};

{**
 * Start a rumble effect.
 *
 * Each call to this function cancels any previous rumble effect, and calling
 * it with 0 intensity stops any rumbling.
 *
 * \param joystick The joystick to vibrate
 * \param low_frequency_rumble The intensity of the low frequency (left)
 *                             rumble motor, from 0 to 0xFFFF
 * \param high_frequency_rumble The intensity of the high frequency (right)
 *                              rumble motor, from 0 to 0xFFFF
 * \param duration_ms The duration of the rumble effect, in milliseconds
 * \returns 0, or -1 if rumble isn't supported on this joystick
 *
 * \since This function is available since SDL 2.0.9.
 *
 * \sa SDL_JoystickHasRumble
 *}
function SDL_JoystickRumble(joystick: PSDL_Joystick; low_frequency_rumble: cuint16; high_frequency_rumble: cuint16; duration_ms: cuint32): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickRumble' {$ENDIF} {$ENDIF};

{**
 * Start a rumble effect in the joystick's triggers
 *
 * Each call to this function cancels any previous trigger rumble effect, and
 * calling it with 0 intensity stops any rumbling.
 *
 * Note that this is rumbling of the _triggers_ and not the game controller as
 * a whole. This is currently only supported on Xbox One controllers. If you
 * want the (more common) whole-controller rumble, use SDL_JoystickRumble()
 * instead.
 *
 * \param joystick The joystick to vibrate
 * \param left_rumble The intensity of the left trigger rumble motor, from 0
 *                    to 0xFFFF
 * \param right_rumble The intensity of the right trigger rumble motor, from 0
 *                     to 0xFFFF
 * \param duration_ms The duration of the rumble effect, in milliseconds
 * \returns 0, or -1 if trigger rumble isn't supported on this joystick
 *
 * \since This function is available since SDL 2.0.14.
 *
 * \sa SDL_JoystickHasRumbleTriggers
 *}
function SDL_JoystickRumbleTriggers(joystick: PSDL_Joystick; left_rumble: cuint16; right_rumble: cuint16; duration_ms: cuint32): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickRumbleTriggers' {$ENDIF} {$ENDIF};

{**
 * Query whether a joystick has an LED.
 *
 * An example of a joystick LED is the light on the back of a PlayStation 4's
 * DualShock 4 controller.
 *
 * \param joystick The joystick to query
 * \return SDL_TRUE if the joystick has a modifiable LED, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickHasLED(joystick: PSDL_Joystick): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickHasLED' {$ENDIF} {$ENDIF};

{**
 * Query whether a joystick has rumble support.
 *
 * \param joystick The joystick to query
 * \return SDL_TRUE if the joystick has rumble, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_JoystickRumble
 *}
function SDL_JoystickHasRumble(joystick: PSDL_Joystick): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickHasRumble' {$ENDIF} {$ENDIF};

{**
 * Query whether a joystick has rumble support on triggers.
 *
 * \param joystick The joystick to query
 * \return SDL_TRUE if the joystick has trigger rumble, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_JoystickRumbleTriggers
 *}
function SDL_JoystickHasRumbleTriggers(joystick: PSDL_Joystick): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickHasRumbleTriggers' {$ENDIF} {$ENDIF};


{**
 * Update a joystick's LED color.
 *
 * An example of a joystick LED is the light on the back of a PlayStation 4's
 * DualShock 4 controller.
 *
 * \param joystick The joystick to update
 * \param red The intensity of the red LED
 * \param green The intensity of the green LED
 * \param blue The intensity of the blue LED
 * \returns 0 on success, -1 if this joystick does not have a modifiable LED
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_JoystickSetLED(joystick: PSDL_Joystick; red: cuint8; green: cuint8; blue: cuint8): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSetLED' {$ENDIF} {$ENDIF};

{**
 * Send a joystick specific effect packet
 *
 * \param joystick The joystick to affect
 * \param data The data to send to the joystick
 * \param size The size of the data to send to the joystick
 * \returns 0, or -1 if this joystick or driver doesn't support effect packets
 *
 * \since This function is available since SDL 2.0.16.
 *}
function SDL_JoystickSendEffect(joystick: PSDL_Joystick; const data: Pointer; size: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickSendEffect' {$ENDIF} {$ENDIF};

{**
 * Close a joystick previously opened with SDL_JoystickOpen().
 *
 * \param joystick The joystick device to close
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_JoystickOpen
 *}
procedure SDL_JoystickClose(joystick: PSDL_Joystick); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickClose' {$ENDIF} {$ENDIF};

{**
 * Get the battery level of a joystick as SDL_JoystickPowerLevel.
 *
 * \param joystick the SDL_Joystick to query
 * \returns the current battery level as SDL_JoystickPowerLevel on success or
 *          `SDL_JOYSTICK_POWER_UNKNOWN` if it is unknown
 *
 * \since This function is available since SDL 2.0.4.
 *}
function SDL_JoystickCurrentPowerLevel(joystick: PSDL_Joystick): TSDL_JoystickPowerLevel; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_JoystickCurrentPowerLevel' {$ENDIF} {$ENDIF};
