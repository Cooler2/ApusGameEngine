// SDL 1.3 miniport
{$PASCALMAINNAME _SDL_main}
unit SDLmini;
interface
{$ALIGN 4}

type
  UInt8   = byte;
  UInt16  = word;
  UInt32  = cardinal;

const
    {$IFDEF MSWINDOWS}
    SDL_DLL = 'SDL.dll';
    {$ELSE}
    SDL_DLL = '';
    {$LINKLIB libSDL.a}
    {$ENDIF}

    SDL_INIT_TIMER = $00000001;
    SDL_INIT_AUDIO = $00000010;
    SDL_INIT_VIDEO = $00000020;
    SDL_INIT_JOYSTICK = $00000200;
    SDL_INIT_HAPTIC = $00001000;
  {*< Don't catch fatal signals  }
    SDL_INIT_NOPARACHUTE = $00100000;
    SDL_INIT_EVERYTHING = $0000FFFF;

    // Window flags
      SDL_WINDOW_FULLSCREEN = $00000001;
      SDL_WINDOW_OPENGL = $00000002;
      SDL_WINDOW_SHOWN = $00000004;
      SDL_WINDOW_HIDDEN = $00000008;
      SDL_WINDOW_BORDERLESS = $00000010;
      SDL_WINDOW_RESIZABLE = $00000020;
      SDL_WINDOW_MINIMIZED = $00000040;
      SDL_WINDOW_MAXIMIZED = $00000080;
      SDL_WINDOW_INPUT_GRABBED = $00000100;
      SDL_WINDOW_INPUT_FOCUS = $00000200;
      SDL_WINDOW_MOUSE_FOCUS = $00000400;
      SDL_WINDOW_FOREIGN = $00000800;

    SDL_SWSURFACE = $00000000;
    SDL_SRCALPHA = $00010000;
    SDL_SRCCOLORKEY = $00020000;
    SDL_ANYFORMAT = $00100000;
    SDL_HWPALETTE = $00200000;
    SDL_DOUBLEBUF = $00400000;
    SDL_FULLSCREEN = $00800000;
    SDL_RESIZABLE = $01000000;
    SDL_NOFRAME = $02000000;
    SDL_OPENGL = $04000000;
  {*< \note Not used  }
    SDL_HWSURFACE = $08000001;
  {*< \note Not used  }
    SDL_ASYNCBLIT = $08000000;
  {*< \note Not used  }
    SDL_RLEACCELOK = $08000000;
  {*< \note Not used  }
    SDL_HWACCEL = $08000000;
  {@ }  {Surface flags }
    SDL_APPMOUSEFOCUS = $01;
    SDL_APPINPUTFOCUS = $02;
    SDL_APPACTIVE = $04;
    SDL_LOGPAL = $01;
    SDL_PHYSPAL = $02;

    SDL_FIRSTEVENT     = 0;     //**< Unused (do not remove) */

    //* Application events */
    SDL_QUIT_          = $100; //**< User-requested quit */

    //* Window events */
    SDL_WINDOWEVENT    = $200; //**< Window state change */
    SDL_SYSWMEVENT     = $201;  //**< System specific event */

    //* Keyboard events */
    SDL_KEYDOWN        = $300; //**< Key pressed */
    SDL_KEYUP          = $301;  //**< Key released */
    SDL_TEXTEDITING    = $302;  //**< Keyboard text editing (composition) */
    SDL_TEXTINPUT      = $303;  //**< Keyboard text input */

    //* Mouse events */
    SDL_MOUSEMOTION    = $400; //**< Mouse moved */
    SDL_MOUSEBUTTONDOWN = $401; //**< Mouse button pressed */
    SDL_MOUSEBUTTONUP  = $402;  //**< Mouse button released */
    SDL_MOUSEWHEEL     = $403;  //**< Mouse wheel motion */

    //* Tablet or multiple mice input device events */
    SDL_INPUTMOTION    = $500; //**< Input moved */
    SDL_INPUTBUTTONDOWN = $501;//**< Input button pressed */
    SDL_INPUTBUTTONUP  = $502; //**< Input button released */
    SDL_INPUTWHEEL     = $503;  //**< Input wheel motion */
    SDL_INPUTPROXIMITYIN = $504;//**< Input pen entered proximity */
    SDL_INPUTPROXIMITYOUT= $505;//**< Input pen left proximity */

    //* Joystick events */
    SDL_JOYAXISMOTION  = $600; //**< Joystick axis motion */
    SDL_JOYBALLMOTION  = $601;  //**< Joystick trackball motion */
    SDL_JOYHATMOTION   = $602;  //**< Joystick hat position change */
    SDL_JOYBUTTONDOWN  = $603;  //**< Joystick button pressed */
    SDL_JOYBUTTONUP    = $604;  //**< Joystick button released */

    //* Touch events */
    SDL_FINGERDOWN      = $700;
    SDL_FINGERUP        = $701;
    SDL_FINGERMOTION    = $702;
    SDL_TOUCHBUTTONDOWN = $703;
    SDL_TOUCHBUTTONUP   = $704;

    //* Gesture events */
    SDL_DOLLARGESTURE   = $800;
    SDL_DOLLARRECORD    = $801;
    SDL_MULTIGESTURE    = $802;

    //* Clipboard events */

    SDL_CLIPBOARDUPDATE = $900; //**< The clipboard changed */


    //** Events ::SDL_USEREVENT through ::SDL_LASTEVENT are for your use,
    // *  and should be allocated with SDL_RegisterEvents()
    // */
    SDL_USEREVENT    = $8000;

    SDLK_RETURN = 13;
    SDLK_ESCAPE = 27;
    SDLK_BACKSPACE = 8;
    SDLK_TAB = 9;
    SDLK_SPACE = 32;

  // Window events
    SDL_WINDOWEVENT_NONE            = 0;
    SDL_WINDOWEVENT_SHOWN           = 1;
    SDL_WINDOWEVENT_HIDDEN          = 2;
    SDL_WINDOWEVENT_EXPOSED         = 3;
    SDL_WINDOWEVENT_MOVED           = 4;
    SDL_WINDOWEVENT_RESIZED         = 5;
    SDL_WINDOWEVENT_SIZE_CHANGED    = 6;
    SDL_WINDOWEVENT_MINIMIZED       = 7;
    SDL_WINDOWEVENT_MAXIMIZED       = 8;
    SDL_WINDOWEVENT_RESTORED        = 9;
    SDL_WINDOWEVENT_ENTER           = 10;
    SDL_WINDOWEVENT_LEAVE           = 11;
    SDL_WINDOWEVENT_FOCUS_GAINED    = 12;
    SDL_WINDOWEVENT_FOCUS_LOST      = 13;
    SDL_WINDOWEVENT_CLOSE           = 14;

    SDL_WINDOWPOS_CENTERED          = $2FFF0000;

    SDL_BUTTON_LEFT      =  1;
    SDL_BUTTON_MIDDLE    =  2;
    SDL_BUTTON_RIGHT     =  3;
    SDL_BUTTON_X1        =  4;
    SDL_BUTTON_X2        =  5;

    // USB keyboard scancodes
    SDL_SCANCODE_A = 4;
    SDL_SCANCODE_B = 5;
    SDL_SCANCODE_C = 6;
    SDL_SCANCODE_D = 7;
    SDL_SCANCODE_E = 8;
    SDL_SCANCODE_F = 9;
    SDL_SCANCODE_G = 10;
    SDL_SCANCODE_H = 11;
    SDL_SCANCODE_I = 12;
    SDL_SCANCODE_J = 13;
    SDL_SCANCODE_K = 14;
    SDL_SCANCODE_L = 15;
    SDL_SCANCODE_M = 16;
    SDL_SCANCODE_N = 17;
    SDL_SCANCODE_O = 18;
    SDL_SCANCODE_P = 19;
    SDL_SCANCODE_Q = 20;
    SDL_SCANCODE_R = 21;
    SDL_SCANCODE_S = 22;
    SDL_SCANCODE_T = 23;
    SDL_SCANCODE_U = 24;
    SDL_SCANCODE_V = 25;
    SDL_SCANCODE_W = 26;
    SDL_SCANCODE_X = 27;
    SDL_SCANCODE_Y = 28;
    SDL_SCANCODE_Z = 29;

    SDL_SCANCODE_1 = 30;
    SDL_SCANCODE_2 = 31;
    SDL_SCANCODE_3 = 32;
    SDL_SCANCODE_4 = 33;
    SDL_SCANCODE_5 = 34;
    SDL_SCANCODE_6 = 35;
    SDL_SCANCODE_7 = 36;
    SDL_SCANCODE_8 = 37;
    SDL_SCANCODE_9 = 38;
    SDL_SCANCODE_0 = 39;

    SDL_SCANCODE_RETURN = 40;
    SDL_SCANCODE_ESCAPE = 41;
    SDL_SCANCODE_BACKSPACE = 42;
    SDL_SCANCODE_TAB = 43;
    SDL_SCANCODE_SPACE = 44;

    SDL_SCANCODE_F1 = 58;
    SDL_SCANCODE_F2 = 59;
    SDL_SCANCODE_F3 = 60;
    SDL_SCANCODE_F4 = 61;
    SDL_SCANCODE_F5 = 62;
    SDL_SCANCODE_F6 = 63;
    SDL_SCANCODE_F7 = 64;
    SDL_SCANCODE_F8 = 65;
    SDL_SCANCODE_F9 = 66;
    SDL_SCANCODE_F10 = 67;
    SDL_SCANCODE_F11 = 68;
    SDL_SCANCODE_F12 = 69;

    SDL_SCANCODE_PRINTSCREEN = 70;
    SDL_SCANCODE_SCROLLLOCK = 71;
    SDL_SCANCODE_PAUSE = 72;

    SDL_SCANCODE_INSERT = 73;
    SDL_SCANCODE_HOME = 74;
    SDL_SCANCODE_PAGEUP = 75;
    SDL_SCANCODE_DELETE = 76;
    SDL_SCANCODE_END = 77;
    SDL_SCANCODE_PAGEDOWN = 78;
    SDL_SCANCODE_RIGHT = 79;
    SDL_SCANCODE_LEFT = 80;
    SDL_SCANCODE_DOWN = 81;
    SDL_SCANCODE_UP = 82;

    SDL_SCANCODE_LCTRL = 224;
    SDL_SCANCODE_LSHIFT = 225;
    SDL_SCANCODE_LALT = 226; //**< alt, option */
    SDL_SCANCODE_LGUI = 227; //**< windows, command (apple), meta */
    SDL_SCANCODE_RCTRL = 228;
    SDL_SCANCODE_RSHIFT = 229;
    SDL_SCANCODE_RALT = 230; //**< alt gr, option */
    SDL_SCANCODE_RGUI = 231; //**< windows, command (apple), meta */
    

type
    TSDL_DisplayMode = record
        format : Uint32;
        w : longint;
        h : longint;
        refresh_rate : longint;
        driverdata : pointer;
      end;

    TSDL_GLattr = (
      SDL_GL_RED_SIZE,
      SDL_GL_GREEN_SIZE,
      SDL_GL_BLUE_SIZE,
      SDL_GL_ALPHA_SIZE,
      SDL_GL_BUFFER_SIZE,
      SDL_GL_DOUBLEBUFFER,
      SDL_GL_DEPTH_SIZE,
      SDL_GL_STENCIL_SIZE,
      SDL_GL_ACCUM_RED_SIZE,
      SDL_GL_ACCUM_GREEN_SIZE,
      SDL_GL_ACCUM_BLUE_SIZE,
      SDL_GL_ACCUM_ALPHA_SIZE,
      SDL_GL_STEREO,
      SDL_GL_MULTISAMPLEBUFFERS,
      SDL_GL_MULTISAMPLESAMPLES,
      SDL_GL_ACCELERATED_VISUAL,
      SDL_GL_RETAINED_BACKING,
      SDL_GL_CONTEXT_MAJOR_VERSION,
      SDL_GL_CONTEXT_MINOR_VERSION
      );

  	PSDL_Rect = ^TSDL_Rect;
  	TSDL_Rect = record
   		x, y, w, h: integer;
		end;

	  TSDL_Point = record
	   X: Integer;
     Y: Integer;
	  end;

	 PSDL_PixelFormat = ^TSDL_PixelFormat;
	 TSDL_PixelFormat = record
		palette: Pointer;
		BitsPerPixel : Byte;
		BytesPerPixel: Byte;
		Rloss : Byte;
		Gloss : Byte;
		Bloss : Byte;
		Aloss : Byte;
		Rshift: Byte;
		Gshift: Byte;
		Bshift: Byte;
		Ashift: Byte;
		RMask : UInt32;
		GMask : UInt32;
		BMask : UInt32;
		AMask : UInt32;
		colorkey: UInt32;
		alpha : Byte;
   end;

   TSDL_Window=pointer;

   PSDL_Surface=^TSDL_Surface;
   TSDL_Surface=record
    flags:Uint32;               //**< Read-only */
    format:PSDL_PixelFormat;    //**< Read-only */
    w,h:integer;                   //**< Read-only */
    pitch:integer;                  //**< Read-only */
    pixels:pointer;               //**< Read-write */
    //** Application data associated with the surface */
    userdata:pointer;             //**< Read-write */
    //** information needed for surfaces requiring locks */
    locked:integer;                 //**< Read-only */
    lock_data:pointer;            //**< Read-only */
    //** clipping information */
    clip_rect:TSDL_Rect;         //**< Read-only */
    //** info for fast blit mapping to other surfaces */
    map:pointer;    //**< Private */
    //** Reference count -- used when freeing surface */
    refcount:integer;               //**< Read-mostly */
   end;

  TSDL_Keysym=record
    scancode:cardinal;      //**< SDL physical key code - see ::SDL_Scancode for details */
    sym:integer;            //**< SDL virtual key code - see ::SDL_Keycode for details */
    mod_:Uint16;                 //**< current key modifiers */
    unicode:Uint32;             //**< \deprecated use SDL_TextInputEvent instead */
  end;

  TSDL_WindowEvent=record
    windowID:Uint32;    //**< The associated window */
    event:Uint8;        //**< ::SDL_WindowEventID */
    padding1:Uint8;
    padding2:Uint8;
    padding3:Uint8;
    data1:integer;          //**< event dependent data */
    data2:integer;          //**< event dependent data */
  end;

  TSDL_KeyboardEvent=record
    windowID:Uint32;    //**< The window with keyboard focus, if any */
    state:Uint8;        //**< ::SDL_PRESSED or ::SDL_RELEASED */
    repeat_:Uint8;       //**< Non-zero if this is a key repeat */
    padding2:Uint8;
    padding3:Uint8;
    keysym:TSDL_Keysym;  //**< The key that was pressed or released */
  end;

  TSDL_MouseMotionEvent=record
    windowID:Uint32;    //**< The window with mouse focus, if any */
    state:Uint8;        //**< The current button state */
    padding1:Uint8;
    padding2:Uint8;
    padding3:Uint8;
    x:integer;              //**< X coordinate, relative to window */
    y:integer;              //**< Y coordinate, relative to window */
    xrel:integer;           //**< The relative motion in the X direction */
    yrel:integer;           //**< The relative motion in the Y direction */
  end;

  TSDL_MouseButtonEvent=record
    windowID:Uint32;    //**< The window with mouse focus, if any */
    button:Uint8;       //**< The mouse button index */
    state:Uint8;        //**< ::SDL_PRESSED or ::SDL_RELEASED */
    padding1:Uint8;
    padding2:Uint8;
    x:integer;              //**< X coordinate, relative to window */
    y:integer;              //**< Y coordinate, relative to window */
  end;

  TSDL_MouseWheelEvent=record
    windowID:Uint32;    //**< The window with mouse focus, if any */
    x:integer;              //**< The amount scrolled horizontally */
    y:integer;              //**< The amount scrolled vertically */
  end;

 PSDL_Event=^TSDL_Event;
 TSDL_Event=record
  case type_:UInt32 of
   SDL_WINDOWEVENT:(windowEvent:TSDL_WindowEvent);
   SDL_KEYDOWN,SDL_KEYUP:(key:TSDL_KeyboardEvent);
   SDL_MOUSEMOTION:(mouseMotion:TSDL_MouseMotionEvent);
   SDL_MOUSEBUTTONDOWN,SDL_MOUSEBUTTONUP:(mouseButton:TSDL_MouseButtonEvent);
   SDL_MOUSEWHEEL:(mouseWheel:TSDL_MouseWheelEvent);
   0:(spacing:array[0..59] of byte);
 end;

 TSDL_GLContext = pointer;

 // SDL subsystem
 function SDL_Init(flags:Uint32):integer; cdecl; external SDL_DLL;
 procedure SDL_Quit; cdecl; external SDL_DLL;
 function  SDL_GetError: PChar; cdecl; external SDL_DLL;
 procedure SDL_ClearError; cdecl; external SDL_DLL;

 // Cross-platform functions
 function SDL_GetTicks:cardinal; cdecl; external SDL_DLL;
 function SDL_GetPerformanceCounter:int64; cdecl; external SDL_DLL;
 function SDL_GetPerformanceFrequency:int64; cdecl; external SDL_DLL;

 // Video
 function SDL_SetVideoMode(width,height,bpp:integer;flags:Uint32):PSDL_Surface; cdecl; external SDL_DLL;

 // OpenGL
 function SDL_GL_CreateContext(window:TSDL_Window):TSDL_GLContext; cdecl; external SDL_DLL;
 procedure SDL_GL_DeleteContext(context:TSDL_GLContext); cdecl; external SDL_DLL;
 function SDL_GL_SetAttribute(attr:TSDL_GLattr;value:integer):integer; cdecl; external SDL_DLL;
 procedure SDL_GL_SwapBuffers; cdecl; external SDL_DLL;
 procedure SDL_GL_SwapWindow(window:TSDL_Window); cdecl; external SDL_DLL;
 function SDL_GL_MakeCurrent(window:TSDL_Window;context:TSDL_GLContext):integer; cdecl; external SDL_DLL;
 function SDL_GL_SetSwapInterval(interval:integer):integer; cdecl; external SDL_DLL;

 // Window management
 function SDL_CreateWindow(title:PChar;x,y,w,h:integer;flags:UInt32):TSDL_Window; cdecl; external SDL_DLL;
 procedure SDL_DestroyWindow(window:TSDL_Window); cdecl; external SDL_DLL;
 procedure SDL_SetWindowTitle(window:TSDL_Window;title:PChar); cdecl; external SDL_DLL;
 procedure SDL_ShowWindow(window:TSDL_Window); cdecl; external SDL_DLL;
 procedure SDL_HideWindow(window:TSDL_Window); cdecl; external SDL_DLL;
 procedure SDL_MinimizeWindow(window:TSDL_Window); cdecl; external SDL_DLL;
 procedure SDL_GetWindowPosition(window:TSDL_Window;out x,y:integer); cdecl; external SDL_DLL;
 procedure SDL_SetWindowPosition(window:TSDL_Window;x,y:integer); cdecl; external SDL_DLL;
 procedure SDL_GetWindowSize(window:TSDL_Window;out w,h:integer); cdecl; external SDL_DLL;
 procedure SDL_SetWindowSize(window:TSDL_Window;w,h:integer); cdecl; external SDL_DLL;

 // Events and execution
 procedure SDL_PumpEvents; cdecl; external SDL_DLL;
 function  SDL_PollEvent(out event: TSDL_Event):LongBool; cdecl; external SDL_DLL;
 function  SDL_WaitEvent(out event: TSDL_Event):LongBool; cdecl; external SDL_DLL;
 procedure SDL_Delay(msec: cardinal); cdecl; external SDL_DLL;

 // Keyboard
 function SDL_GetKeyboardState(out numkeys:integer):PByte; cdecl; external SDL_DLL;

 function ScanCodeFromUSBcode(USBcode:integer):integer;

implementation

 function ScanCodeFromUSBcode(USBcode:integer):integer;
  begin
   case USBcode of
    SDL_SCANCODE_A:result:=30;
    SDL_SCANCODE_B:result:=48;
    SDL_SCANCODE_C:result:=46;
    SDL_SCANCODE_D:result:=32;
    SDL_SCANCODE_E:result:=18;
    SDL_SCANCODE_F:result:=33;
    SDL_SCANCODE_G:result:=34;
    SDL_SCANCODE_H:result:=35;
    SDL_SCANCODE_I:result:=23;
    SDL_SCANCODE_J:result:=36;
    SDL_SCANCODE_K:result:=37;
    SDL_SCANCODE_L:result:=38;
    SDL_SCANCODE_M:result:=50;
    SDL_SCANCODE_N:result:=49;
    SDL_SCANCODE_O:result:=24;
    SDL_SCANCODE_P:result:=25;
    SDL_SCANCODE_Q:result:=16;
    SDL_SCANCODE_R:result:=19;
    SDL_SCANCODE_S:result:=31;
    SDL_SCANCODE_T:result:=20;
    SDL_SCANCODE_U:result:=22;
    SDL_SCANCODE_V:result:=47;
    SDL_SCANCODE_W:result:=17;
    SDL_SCANCODE_X:result:=45;
    SDL_SCANCODE_Y:result:=21;
    SDL_SCANCODE_Z:result:=44;

    SDL_SCANCODE_1..SDL_SCANCODE_0:result:=(USBcode-SDL_SCANCODE_1)+2;

    SDL_SCANCODE_RETURN:result:=28;
    SDL_SCANCODE_ESCAPE:result:=1;
    SDL_SCANCODE_BACKSPACE:result:=14;
    SDL_SCANCODE_TAB:result:=15;
    SDL_SCANCODE_SPACE:result:=57;

    SDL_SCANCODE_F1..SDL_SCANCODE_F10:result:=USBcode+1;
    SDL_SCANCODE_F11:result:=87;
    SDL_SCANCODE_F12:result:=88;

    SDL_SCANCODE_INSERT:result:=210;
    SDL_SCANCODE_HOME:result:=199;
    SDL_SCANCODE_PAGEUP:result:=201;
    SDL_SCANCODE_DELETE:result:=211;
    SDL_SCANCODE_END:result:=207;
    SDL_SCANCODE_PAGEDOWN:result:=209;
    SDL_SCANCODE_RIGHT:result:=205;
    SDL_SCANCODE_LEFT:result:=203;
    SDL_SCANCODE_DOWN:result:=208;
    SDL_SCANCODE_UP:result:=200;
   end;
  end;

end.