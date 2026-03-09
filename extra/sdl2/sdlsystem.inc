// from "SDL_system.h"

(* Platform specific functions for Windows *)
{$IF DEFINED(WIN32) OR DEFINED(WIN64)} 
type
  PPSDL_WindowsMessageHook = ^PSDL_WindowsMessageHook;
  PSDL_WindowsMessageHook = ^TSDL_WindowsMessageHook;
  TSDL_WindowsMessageHook = procedure(userdata, hWnd: Pointer; mesage: cuint; wParam: cuint64; lParam: cint64); cdecl;

{**
 * Set a callback for every Windows message, run before TranslateMessage().
 *
 * \param callback The SDL_WindowsMessageHook function to call.
 * \param userdata a pointer to pass to every iteration of `callback`
 *
 * \since This function is available since SDL 2.0.4.
 *}
procedure SDL_SetWindowsMessageHook(callback: TSDL_WindowsMessageHook; userdata: Pointer); cdecl;
  external SDL_LibName;

{**
 * Get the D3D9 adapter index that matches the specified display index.
 *
 * The returned adapter index can be passed to `IDirect3D9::CreateDevice` and
 * controls on which monitor a full screen application will appear.
 *
 * \param displayIndex the display index for which to get the D3D9 adapter
 *                     index
 * \returns the D3D9 adapter index on success or a negative error code on
 *          failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.1.
 *}
function SDL_Direct3D9GetAdapterIndex(displayIndex:cint):cint; cdecl;
  external SDL_LibName;

type
  PIDirect3DDevice9 = type Pointer;
  PID3D11Device = type Pointer;
  PID3D12Device = type Pointer;

{**
 * Get the D3D9 device associated with a renderer.
 *
 * Once you are done using the device, you should release it to avoid a
 * resource leak.
 *
 * \param renderer the renderer from which to get the associated D3D device
 * \returns the D3D9 device associated with given renderer or NIL if it is
 *          not a D3D9 renderer; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.1.
 *}
function SDL_RenderGetD3D9Device(renderer:PSDL_Renderer):PIDirect3DDevice9; cdecl;
  external SDL_LibName;

{**
 * Get the D3D11 device associated with a renderer.
 *
 * Once you are done using the device, you should release it to avoid a
 * resource leak.
 *
 * \param renderer the renderer from which to get the associated D3D11 device
 * \returns the D3D11 device associated with given renderer or NIL if it is
 *          not a D3D11 renderer; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.16.
 *}
function SDL_RenderGetD3D11Device(renderer:PSDL_Renderer):PID3D11Device; cdecl;
  external SDL_LibName;

{**
 * Get the D3D12 device associated with a renderer.
 *
 * Once you are done using the device, you should release it to avoid a
 * resource leak.
 *
 * \param renderer the renderer from which to get the associated D3D12 device
 * \returns the D3D12 device associated with given renderer or NIL if it is
 *          not a D3D12 renderer; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.24.0.
 *}
function SDL_RenderGetD3D12Device(renderer:PSDL_Renderer):PID3D12Device; cdecl;
  external SDL_LibName;

{**
 * Get the DXGI Adapter and Output indices for the specified display index.
 *
 * The DXGI Adapter and Output indices can be passed to `EnumAdapters` and
 * `EnumOutputs` respectively to get the objects required to create a DX10 or
 * DX11 device and swap chain.
 *
 * Before SDL 2.0.4 this function did not return a value.
 * Since SDL 2.0.4 it returns a TSDL_bool.
 *
 * \param displayIndex the display index for which to get both indices
 * \param adapterIndex a pointer to be filled in with the adapter index
 * \param outputIndex a pointer to be filled in with the output index
 * \returns SDL_TRUE on success or SDL_FALSE on failure; call SDL_GetError()
 *          for more information.
 *
 * \since This function is available since SDL 2.0.2.
 *}
function SDL_DXGIGetOutputInfo(displayIndex: cint; adapterIndex, outputIndex: pcint): TSDL_Bool;
  external SDL_LibName;
{$ENDIF WIN32 OR WIN64}


(* Platform specific functions for Linux *)
{$IFDEF LINUX}
{**
 * Sets the UNIX nice value for a thread.
 *
 * This uses setpriority() if possible, and RealtimeKit if available.
 *
 * \param threadID the Unix thread ID to change priority of.
 * \param priority The new, Unix-specific, priority value.
 * \returns 0 on success, or -1 on error.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_LinuxSetThreadPriority(threadID: cint64; priority: cint): cint; cdecl;
  external SDL_LibName;

{**
 * Sets the priority (not nice level) and scheduling policy for a thread.
 *
 * This uses setpriority() if possible, and RealtimeKit if available.
 *
 * \param threadID The Unix thread ID to change priority of.
 * \param sdlPriority The new TSDL_ThreadPriority value.
 * \param schedPolicy The new scheduling policy (SCHED_FIFO, SCHED_RR,
 *                    SCHED_OTHER, etc...)
 * \returns 0 on success, or -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *}
function SDL_LinuxSetThreadPriorityAndPolicy(threadID: cint64; sdlPriority, schedPolicy: cint): cint; cdecl;
  external SDL_LibName;
{$ENDIF LINUX}


(* Platform specific functions for iOS *)
{$IFDEF __IPHONEOS__}
type
  PPSDL_iPhoneAnimationCallback = ^PSDL_iPhoneAnimationCallback;
  PSDL_iPhoneAnimationCallback = ^TSDL_iPhoneAnimationCallback;
  TSDL_iPhoneAnimationCallback = procedure(callbackParam: Pointer); cdecl;

{**
 * Use this function to set the animation callback on Apple iOS.
 *
 * This function is only available on Apple iOS.
 *
 * For more information see:
 * https://github.com/libsdl-org/SDL/blob/main/docs/README-ios.md
 *
 * \param window the window for which the animation callback should be set
 * \param interval the number of frames after which **callback** will be
 *                 called
 * \param callback the function to call for every frame.
 * \param callbackParam a pointer that is passed to `callback`.
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_iPhoneSetEventPump
 *}
function SDL_iPhoneSetAnimationCallback(window: PSDL_Window; interval: cint; callback: TSDL_iPhoneAnimationCallback; callbackParam: Pointer); cdecl;
  external SDL_LibName;

{**
 * Use this function to enable or disable the SDL event pump on Apple iOS.
 *
 * This function is only available on Apple iOS.
 *
 * \param enabled SDL_TRUE to enable the event pump, SDL_FALSE to disable it
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_iPhoneSetAnimationCallback
 *}
procedure SDL_iPhoneSetEventPump(enabled: TSDL_Bool); cdecl;
  external SDL_LibName;
{$ENDIF __IPHONEOS__}


(* Platform specific functions for Android *)
{$IFDEF ANDROID}

{**
 * Get the Android Java Native Interface Environment of the current thread.
 *
 * This is the JNIEnv one needs to access the Java virtual machine from native
 * code, and is needed for many Android APIs to be usable from Pascal.
 *
 * The prototype of the function in SDL's code actually declare a Pointer return
 * type, even if the implementation returns a pointer to a JNIEnv. The
 * rationale being that the SDL units can avoid using the JNI unit.
 *
 * \returns a pointer to Java native interface object (JNIEnv) to which the
 *          current thread is attached, or NIL on error.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AndroidGetActivity
 *}
function SDL_AndroidGetJNIEnv(): Pointer; cdecl;
  external SDL_LibName;

(**
 * Retrieve the Java instance of the Android activity class.
 *
 * The prototype of the function in SDL's code actually declares a Pointer
 * return type, even if the implementation returns a JObject. The rationale
 * being that the SDL units can avoid using the JNI unit.
 *
 * The JObject returned by the function is a local reference and must be
 * released by the caller. See the PushLocalFrame() and PopLocalFrame() or
 * DeleteLocalRef() functions of the Java native interface:
 *
 * https://docs.oracle.com/javase/1.5.0/docs/guide/jni/spec/functions.html
 *
 * \returns the jobject representing the instance of the Activity class of the
 *          Android application, or NIL on error.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AndroidGetJNIEnv
 *)
function SDL_AndroidGetActivity(): Pointer; cdecl;
  external SDL_LibName;

{**
 * Query Android API level of the current device.
 *
 * - API level 34: Android 14
 * - API level 33: Android 13
 * - API level 32: Android 12L
 * - API level 31: Android 12
 * - API level 30: Android 11
 * - API level 29: Android 10
 * - API level 28: Android 9 "Pie"
 * - API level 27: Android 8.1 "Oreo"
 * - API level 26: Android 8.0 "Oreo"
 * - API level 25: Android 7.1 "Nougat"
 * - API level 24: Android 7.0 "Nougat"
 * - API level 23: Android 6.0 "Marshmallow"
 * - API level 22: Android 5.1 "Lollipop"
 * - API level 21: Android 5.0 "Lollipop"
 * - API level 20: Android 4.4W "KitKat"
 * - API level 19: Android 4.4  "KitKat"
 * - API level 18: Android 4.3 "Jelly Bean"
 * - API level 17: Android 4.2 "Jelly Bean"
 * - API level 16: Android 4.1 "Jelly Bean"
 * - API level 15: Android 4.0.3 "Ice Cream Sandwich"
 * - API level 14: Android 4.0   "Ice Cream Sandwich"
 * - API level 13: Android 3.2 "Honeycomb"
 * - API level 12: Android 3.1 "Honeycomb"
 * - API level 11: Android 3.0 "Honeycomb"
 * - API level 10: Android 2.3.3 "Gingerbread"
 *
 * \returns the Android API level.
 *
 * \since This function is available since SDL 2.0.12.
 *}
function SDL_GetAndroidSDKVersion(): cint; cdecl;
  external SDL_LibName;

{**
 * Query if the application is running on Android TV.
 *
 * \returns SDL_TRUE if this is Android TV, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.8.
 *}
function SDL_IsAndroidTV(): TSDL_Bool; cdecl;
  external SDL_LibName;

{**
 * Query if the application is running on a Chromebook.
 *
 * \returns SDL_TRUE if this is a Chromebook, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_IsChromebook(): TSDL_Bool; cdecl;
  external SDL_LibName;

{**
 * Query if the application is running on a Samsung DeX docking station.
 *
 * \returns SDL_TRUE if this is a DeX docking station, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_IsDeXMode(): TSDL_Bool; cdecl;
  external SDL_LibName;

{**
 * Trigger the Android system back button behavior.
 *
 * \since This function is available since SDL 2.0.9.
 *}
procedure SDL_AndroidBackButton(); cdecl;
  external SDL_LibName;

{**
   See the official Android developer guide for more information:
   http://developer.android.com/guide/topics/data/data-storage.html
*}
const
  SDL_ANDROID_EXTERNAL_STORAGE_READ  = $01;
  SDL_ANDROID_EXTERNAL_STORAGE_WRITE = $02;

{**
 * Get the path used for internal storage for this application.
 *
 * This path is unique to your application and cannot be written to by other
 * applications.
 *
 * Your internal storage path is typically:
 * `/data/data/your.app.package/files`.
 *
 * \returns the path used for internal storage or NIL on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AndroidGetExternalStorageState
 *}
function SDL_AndroidGetInternalStoragePath(): PAnsiChar; cdecl;
  external SDL_LibName;

{**
 * Get the current state of external storage.
 *
 * The current state of external storage, a bitmask of these values:
 * `SDL_ANDROID_EXTERNAL_STORAGE_READ`, `SDL_ANDROID_EXTERNAL_STORAGE_WRITE`.
 *
 * If external storage is currently unavailable, this will return 0.
 *
 * \returns the current state of external storage on success or 0 on failure;
 *          call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AndroidGetExternalStoragePath
 *}
function SDL_AndroidGetExternalStorageState(): cint; cdecl;
  external SDL_LibName;

{**
 * Get the path used for external storage for this application.
 *
 * This path is unique to your application, but is public and can be written
 * to by other applications.
 *
 * Your external storage path is typically:
 * `/storage/sdcard0/Android/data/your.app.package/files`.
 *
 * \returns the path used for external storage for this application on success
 *          or NIL on failure; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AndroidGetExternalStorageState
 *}
function SDL_AndroidGetExternalStoragePath(): PAnsiChar; cdecl;
  external SDL_LibName;

{**
 * Request permissions at runtime.
 *
 * This blocks the calling thread until the permission is granted or denied.
 *
 * For a full list of possible permission names, consult the Android docs:
 * https://developer.android.com/reference/android/Manifest.permission
 *
 * \param permission The permission to request.
 * \returns SDL_TRUE if the permission was granted, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.14.
 *}
function SDL_AndroidRequestPermission(const permission: PAnsiChar): TSDL_Bool; cdecl;
  external SDL_LibName;

{**
 * Shows an Android toast notification.
 *
 * Toasts are a sort of lightweight notification that are unique to Android.
 *
 * https://developer.android.com/guide/topics/ui/notifiers/toasts
 *
 * Shows toast in UI thread.
 *
 * For the `gravity` parameter, choose a value from here, or -1 if you don't
 * have a preference:
 *
 * https://developer.android.com/reference/android/view/Gravity
 *
 * \param message text message to be shown
 * \param duration 0=short, 1=long
 * \param gravity where the notification should appear on the screen.
 * \param xoffset set this parameter only when gravity >=0
 * \param yoffset set this parameter only when gravity >=0
 * \returns 0 if success, -1 if any error occurs.
 *
 * \since This function is available since SDL 2.0.16.
 *}
function SDL_AndroidShowToast(const message: PAnsiChar; duration, gravity, xoffset, yoffset: cint): cint; cdecl;
  external SDL_LibName;

{**
 * Send a user command to SDLActivity.
 *
 * Override "boolean onUnhandledMessage(Message msg)" to handle the message.
 *
 * \param command user command that must be greater or equal to 0x8000
 * \param param user parameter
 *
 * \since This function is available since SDL 2.0.22.
 *}
function SDL_AndroidSendMessage(command: cUint32; param: cint): cint; cdecl;
  external SDL_LibName;
{$ENDIF ANDROID}


(* Platform specific functions for WinRT *)
{$IFDEF __WINRT__}
Type
  {** WinRT / Windows Phone path types *}
  PPSDL_WinRT_Path = ^PSDL_WinRT_Path;
  PSDL_WinRT_Path = ^TSDL_WinRT_Path;
  TSDL_WinRT_Path = (
    {** The installed app's root directory.
        Files here are likely to be read-only. *}
    SDL_WINRT_PATH_INSTALLED_LOCATION = 0,
    {** The app's local data store.  Files may be written here *}
    SDL_WINRT_PATH_LOCAL_FOLDER = 1,
    {** The app's roaming data store.  Unsupported on Windows Phone.
        Files written here may be copied to other machines via a network
        connection.
    *}
    SDL_WINRT_PATH_ROAMING_FOLDER = 2,
    {** The app's temporary data store.  Unsupported on Windows Phone.
        Files written here may be deleted at any time. *}
    SDL_WINRT_PATH_TEMP_FOLDER = 3
  );

  TSDL_WinRT_DeviceFamily = (
    {** Unknown family  *}
    SDL_WINRT_DEVICEFAMILY_UNKNOWN,
    {** Desktop family *}
    SDL_WINRT_DEVICEFAMILY_DESKTOP,
    {** Mobile family (for example smartphone) *}
    SDL_WINRT_DEVICEFAMILY_MOBILE,
    {** XBox family *}
    SDL_WINRT_DEVICEFAMILY_XBOX
  );


  {**
   *  \brief Retrieves a WinRT defined path on the local file system
   *
   *  \note Documentation on most app-specific path types on WinRT
   *      can be found on MSDN, at the URL:
   *      http://msdn.microsoft.com/en-us/library/windows/apps/hh464917.aspx
   *
   *  \param pathType The type of path to retrieve.
   *  \ret A UCS-2 string (16-bit, wide-char) containing the path, or NULL
   *      if the path is not available for any reason.  Not all paths are
   *      available on all versions of Windows.  This is especially true on
   *      Windows Phone.  Check the documentation for the given
   *      SDL_WinRT_Path for more information on which path types are
   *      supported where.
   *}
function SDL_WinRTGetFSPathUNICODE(pathType :TSDL_WinRT_Path):PWideChar;
   cdecl; external SDL_LibName;


  {**
   *  \brief Retrieves a WinRT defined path on the local file system
   *
   *  \note Documentation on most app-specific path types on WinRT
   *      can be found on MSDN, at the URL:
   *      http://msdn.microsoft.com/en-us/library/windows/apps/hh464917.aspx
   *
   *  \param pathType The type of path to retrieve.
   *  \ret A UTF-8 string (8-bit, multi-byte) containing the path, or NULL
   *      if the path is not available for any reason.  Not all paths are
   *      available on all versions of Windows.  This is especially true on
   *      Windows Phone.  Check the documentation for the given
   *      SDL_WinRT_Path for more information on which path types are
   *      supported where.
   *}
function SDL_WinRTGetFSPathUTF8(pathType :TSDL_WinRT_Path):PChar;
   cdecl; external SDL_LibName;


{**
 * Detects the device family of WinRT platform at runtime.
 *
 * \returns a value from the SDL_WinRT_DeviceFamily enum.
 *
 * \since This function is available since SDL 2.0.8.
 *}
function SDL_WinRTGetDeviceFamily(): TSDL_WinRT_DeviceFamily;
  cdecl; external SDL_LibName;
{$ENDIF __WINRT__}


{**
 * Query if the current device is a tablet.
 *
 * If SDL can't determine this, it will return SDL_FALSE.
 *
 * \returns SDL_TRUE if the device is a tablet, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_IsTablet(): TSDL_Bool; cdecl;
  external SDL_LibName;


{ Functions used by iOS application delegates to notify SDL about state changes }
procedure SDL_OnApplicationWillTerminate(); cdecl; external SDL_LibName;
procedure SDL_OnApplicationDidReceiveMemoryWarning(); cdecl; external SDL_LibName;
procedure SDL_OnApplicationWillResignActive(); cdecl; external SDL_LibName;
procedure SDL_OnApplicationDidEnterBackground(); cdecl; external SDL_LibName;
procedure SDL_OnApplicationWillEnterForeground(); cdecl; external SDL_LibName;
procedure SDL_OnApplicationDidBecomeActive(); cdecl; external SDL_LibName;
{$IFDEF __IPHONEOS__}
procedure SDL_OnApplicationDidChangeStatusBarOrientation(); cdecl; external SDL_LibName;
{$ENDIF}
