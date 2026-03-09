// from sdl_syswm.h

{**
 *  \brief SDL_syswm.h
 *
 *  Your application has access to a special type of event ::SDL_SYSWMEVENT,
 *  which contains window-manager specific information and arrives whenever
 *  an unhandled window event occurs.  This event is ignored by default, but
 *  you can enable it with SDL_EventState().
 *}

{$IFDEF WINDOWS}
   {$DEFINE SDL_VIDEO_DRIVER_WINDOWS}
{$ENDIF}

{$IFDEF UNIX}
   {$IF NOT (DEFINED(DARWIN) OR DEFINED(ANDROID))}
      {$DEFINE SDL_VIDEO_DRIVER_X11}
   {$IFEND}
{$ENDIF}

(* 
 * Disabled because FPC does not ship a DirectFB unit.
 * If you have some working DirectFB bindings, feel welcome to enable this and check if it breaks anything.
 *)
{$UNDEF SDL_VIDEO_DRIVER_DIRECTFB}

{$IFDEF DARWIN}
   {$DEFINE SDL_VIDEO_DRIVER_COCOA}
{$ENDIF}

(*
 * Disabled because it's a Mac-specific video driver and we have no means of testing it.
 * If you own a Mac, feel welcome to enable this and check if it actually compiles and doesn't break anything.
 *)
{$UNDEF SDL_VIDEO_DRIVER_UIKIT}

(* 
 * Disabled because FPC does not ship a Wayland unit.
 * If you have some working Wayland bindings, feel welcome to enable this,
 * check if it actually compiles and doesn't break anything.
 *)
{$UNDEF SDL_VIDEO_DRIVER_WAYLAND}

(*
 * Disabled because FPC does not ship a Mir unit.
 * Also, support for Mir has been removed in SDL 2.0.10.
 *)
{$UNDEF SDL_VIDEO_DRIVER_MIR}

(*
 * Disabled because FPC does not support WinRT.
 *)
{$UNDEF SDL_VIDEO_DRIVER_WINRT}

{$IFDEF ANDROID}
   {$DEFINE SDL_VIDEO_DRIVER_ANDROID}
{$ENDIF}

(*
 * Disabled because this is an embedded platform and we have no means of testing this.
 * If you're actually working with Vivante, feel welcome to enable this
 * and check if it compiles and works properly.
 *)
{$UNDEF SDL_VIDEO_DRIVER_VIVANTE}

{$IFDEF OS2}
   {$DEFINE SDL_VIDEO_DRIVER_OS2}
{$ENDIF}

{ SDL2-for-Pascal: Disabled because there are no FPC/Delphi units available. }
{$UNDEF SDL_VIDEO_DRIVER_KMSDRM}

{$IFDEF HAIKU}
   {$DEFINE SDL_VIDEO_DRIVER_HAIKU}
{$ENDIF}


{**
 *  These are the various supported windowing subsystems
 *}
type
  TSDL_SYSWM_TYPE = type cint;

const
  SDL_SYSWM_UNKNOWN  = TSDL_SYSWM_TYPE(0);
  SDL_SYSWM_WINDOWS  = TSDL_SYSWM_TYPE(1);
  SDL_SYSWM_X11      = TSDL_SYSWM_TYPE(2);
  SDL_SYSWM_DIRECTFB = TSDL_SYSWM_TYPE(3);
  SDL_SYSWM_COCOA    = TSDL_SYSWM_TYPE(4);
  SDL_SYSWM_UIKIT    = TSDL_SYSWM_TYPE(5);
  SDL_SYSWM_WAYLAND  = TSDL_SYSWM_TYPE(6);
  SDL_SYSWM_MIR      = TSDL_SYSWM_TYPE(7);  // * no longer available, left for API/ABI compatibility. Remove in 2.1! *
  SDL_SYSWM_WINRT    = TSDL_SYSWM_TYPE(8);
  SDL_SYSWM_ANDROID  = TSDL_SYSWM_TYPE(9);
  SDL_SYSWM_VIVANTE  = TSDL_SYSWM_TYPE(10);
  SDL_SYSWM_OS2      = TSDL_SYSWM_TYPE(11);
  SDL_SYSWM_HAIKU    = TSDL_SYSWM_TYPE(12);
  SDL_SYSWM_KMSDRM   = TSDL_SYSWM_TYPE(13);
  SDL_SYSWM_RISCOS   = TSDL_SYSWM_TYPE(14);

/// sdl_syswm.h uses anonymous structs, declared right in SDL_SysWMmsg and SDL_SysWMinfo.
/// Since Pascal does not allow this, we workaround by introducing named types.
type
{$IFDEF SDL_VIDEO_DRIVER_WINDOWS}
   __SYSWM_WINDOWS = record
      hwnd:   HWND;   {**< The window for the message }
      msg:    UINT;   {**< The type of message *}
      wParam: WPARAM; {**< WORD message parameter *}
      lParam: LPARAM; {**< LONG message parameter *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_X11}
   __SYSWM_X11 = record
      event: {$IFDEF FPC} TXEvent {$ELSE} XEvent {$ENDIF};
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_DIRECTFB}
   __SYSWM_DIRECTFB = record
      event: DFBEvent;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_COCOA}
   __SYSWM_COCOA = record
      (* No Cocoa window events yet *)
      dummy: cint;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_UIKIT}
   __SYSWM_UIKIT = record
      (* No UIKit window events yet *)
      dummy: cint;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_VIVANTE}
   __SYSWM_VIVANTE = record
      (* No Vivante window events yet *)
      dummy: cint;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_OS2}
   __SYSWM_OS2 = record
      fFrame: Boolean; {**< TRUE if hwnd is a frame window *}
      hwnd: HWND;      {**< The window receiving the message *}
      msg: ULONG;      {**< The message identifier *}
      mp1: MPARAM;     {**< The first first message parameter *}
      mp2: MPARAM;     {**< The second first message parameter *}
   end;
{$ENDIF}

{**
 *  The custom window manager information structure.
 *
 *  When this structure is returned, it holds information about which
 *  low level system it is using, and will be one of SDL_SYSWM_TYPE.
 *}

{$IFDEF SDL_VIDEO_DRIVER_WINDOWS}
   __WMINFO_WINDOWS = record
      window:    HWND;  {**< The window handle *}
      hdc:       HDC;   {**< The window device context *}
      hinstance: HINST; {**< The instance handle *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_WINRT}
   __WMINFO_WINRT = record
      window: IInspectable;      {**< The WinRT CoreWindow *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_X11}
   __WMINFO_X11 = record
      display: PDisplay;  {**< The X11 display *}
      window:  TWindow;   {**< The X11 window *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_DIRECTFB}
   __WMINFO_DIRECTFB = record
      dfb:     IDirectFB;         {**< The directfb main interface *}
      window:  IDirectFBWindow;   {**< The directfb window handle *}
      surface: IDirectFBSurface;  {**< The directfb client surface *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_COCOA}
   __WMINFO_COCOA = record
      window: NSWindow; {* The Cocoa window *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_UIKIT}
   __WMINFO_UIKIT = record
      window: UIWindow;           {* The UIKit window *}
      framebuffer: GLuint;        {* The GL view's Framebuffer Object. It must be bound when rendering to the screen using GL. *}
      colorbuffer: GLuint;        {* The GL view's color Renderbuffer Object. It must be bound when SDL_GL_SwapWindow is called. *}
      resolveFramebuffer: GLuint; {* The Framebuffer Object which holds the resolve color Renderbuffer, when MSAA is used. *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_WAYLAND}
   __WMINFO_WAYLAND = record
      display: wl_display;             {**< Wayland display *}
      surface: wl_surface;             {**< Wayland surface *}
      shell_surface: Pointer;          {**< DEPRECATED Wayland shell_surface (window manager handle) *}
      egl_window: wl_egl_window;       {**< Wayland EGL window (native window) *}
      xdg_surface: xdg_surface;        {**< Wayland xdg surface (window manager handle) *}
      xdg_toplevel: xdg_toplevel;      {**< Wayland xdg toplevel role *}
      xdg_popup: xdg_popup;            {**< Wayland xdg popup role *}
      xdg_positioner: xdg_positioner;  {**< Wayland xdg positioner, for popup *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_MIR}     {* no longer available, left for API/ABI compatibility. Remove in 2.1! *}
   __WMINFO_MIR = record
      connection: PMirConnection; {**< Mir display server connection *}
      surface: PMirSurface;       {**< Mir surface *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_ANDROID}
   __WMINFO_ANDROID = record
      window:  Pointer;  // PANativeWindow;
      surface: Pointer;  // PEGLSurface;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_OS2}
   __WMINFO_OS2 = record
      hwnd: HWND;      {**< The window handle *}
      hwndFrame: HWND; {**< The frame window handle *}
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_VIVANTE}
   __WMINFO_VIVANTE = record
      display: EGLNativeDisplayType;
      window:  EGLNativeWindowType;
   end;
{$ENDIF}

{$IFDEF SDL_VIDEO_DRIVER_KMSDRM}
   __WMINFO_KMSDRM = record
      dev_index: cint;                   {**< Device index (ex: the X in /dev/dri/cardX) *}
      drm_fd: cint;                      {**< DRM FD (unavailable on Vulkan windows) *}
      gbm_device: Pointer;  // *gbm_dev  {**< GBM device (unavailable on Vulkan windows) *}
   end;
{$ENDIF}




{**
 *  The custom event structure.
 *}
   PPSDL_SysWMmsg = ^PSDL_SysWMmsg;
   PSDL_SysWMmsg = ^TSDL_SysWMmsg;
   TSDL_SysWMmsg = record
      version: TSDL_version;
      case subsystem: TSDL_SYSWM_TYPE of
         {$IFDEF SDL_VIDEO_DRIVER_WINDOWS}
            SDL_SYSWM_WINDOWS: (win: __SYSWM_WINDOWS);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_X11}
            SDL_SYSWM_X11: (x11: __SYSWM_X11);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_DIRECTFB}
            SDL_SYSWM_DIRECTFB: (dfb: __SYSWM_DIRECTFB);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_COCOA}
            SDL_SYSWM_COCOA: (cocoa: __SYSWM_COCOA);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_UIKIT}
            SDL_SYSWM_UIKIT: (uikit: __SYSWM_UIKIT);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_VIVANTE}
            SDL_SYSWM_VIVANTE: (vivante: __SYSWM_VIVANTE);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_OS2}
            SDL_SYSWM_OS2: (os2: __SYSWM_OS2);
         {$ENDIF}
         SDL_SYSWM_UNKNOWN: (dummy: integer);
   end;

{**
 *  The custom window manager information structure.
 *
 *  When this structure is returned, it holds information about which
 *  low level system it is using, and will be one of SDL_SYSWM_TYPE.
 *}
   PPSDL_SysWMinfo = ^PSDL_SysWMinfo;
   PSDL_SysWMinfo = ^TSDL_SysWMinfo;
   TSDL_SysWMinfo = record
      version: TSDL_version;
      case subsystem: TSDL_SYSWM_TYPE of
         {$IFDEF SDL_VIDEO_DRIVER_WINDOWS}
            SDL_SYSWM_WINDOWS: (win : __WMINFO_WINDOWS);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_WINRT}
            SDL_SYSWM_WINRT: (winrt : __WMINFO_WINRT);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_X11}
            SDL_SYSWM_X11: (x11 : __WMINFO_X11);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_DIRECTFB}
            SDL_SYSWM_DIRECTFB: (dfb : __WMINFO_DIRECTFB);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_COCOA}
            SDL_SYSWM_COCOA: (cocoa : __WMINFO_COCOA);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_UIKIT}
            SDL_SYSWM_UIKIT: (uikit : __WMINFO_UIKIT);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_WAYLAND}
            SDL_SYSWM_WAYLAND: (wl : __WMINFO_WAYLAND);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_MIR}
            SDL_SYSWM_MIR: (mir : __WMINFO_MIR);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_ANDROID}
            SDL_SYSWM_ANDROID: (android: __WMINFO_ANDROID);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_VIVANTE}
            SDL_SYSWM_VIVANTE: (vivante: __WMINFO_VIVANTE);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_OS2}
            SDL_SYSWM_OS2: (os2: __WMINFO_OS2);
         {$ENDIF}
         {$IFDEF SDL_VIDEO_DRIVER_KMSDRM}
            SDL_SYSWM_KMSDRM: (kmsdrm: __WMINFO_KMSDRM);
         {$ENDIF}
         (* Ensure this union is always 64 bytes (8 64-bit pointers) *)
            SDL_SYSWM_UNKNOWN: (dummy: array[0..63] of Byte);
   end;

(**
 * Get driver-specific information about a window.
 *
 * You must include SDL_syswm.h for the declaration of SDL_SysWMinfo.
 *
 * The caller must initialize the `info` structure's version by using
 * `SDL_VERSION(&info.version)`, and then this function will fill in the rest
 * of the structure with information about the given window.
 *
 * \param window the window about which information is being requested
 * \param info an SDL_SysWMinfo structure filled in with window information
 * \returns SDL_TRUE if the function is implemented and the `version` member
 *          of the `info` struct is valid, or SDL_FALSE if the information
 *          could not be retrieved; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *)
function SDL_GetWindowWMInfo(window: PSDL_Window; info: PSDL_SysWMinfo): TSDL_bool; cdecl;
   external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowWMInfo' {$ENDIF} {$ENDIF};
