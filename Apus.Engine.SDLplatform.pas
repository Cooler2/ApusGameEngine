// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.SDLplatform;
interface
uses Types, sdl2, Apus.Engine.API, Apus.Engine.OpenGL;

type
 
 { TSDLGLWindow }

 TSDLGLWindow=class(TWindow)
  constructor Create(aWnd:PSDL_Window;windowName:string='MainWnd');
  procedure Close; override;
  procedure Configure(params:TGameSettings); override;
  procedure Show(show:boolean); override;
  function GetHandle:THandle; override;
  procedure GetSize(out width,height:integer); override;
  procedure MoveTo(x,y:integer;width:integer=0;height:integer=0); override;
  procedure SetCaption(text:string); override;
  procedure Minimize; override;
  procedure FlashWindow(count:integer); override;
  procedure ProcessMessages; override;
  function IsTerminated:boolean; override;
  procedure ScreenToClient(var p:TPoint); override;
  procedure ClientToScreen(var p:TPoint); override;
  procedure InitGraph; override;
  procedure DoneGraph; override;
  procedure PresentFrame; override;
  function SetVSync(divider:integer):boolean; override;
 private
  wnd:PSDL_Window;
  ctx:TSDL_GLContext;
  graphInfo:TOpenGLContextDesc;
  function CreateOpenGLContext(var graph:TOpenGLContextDesc):UIntPtr;
 end;

 { TSDLPlatform }

 TSDLPlatform=class(TInterfacedObject,ISystemPlatform)
  constructor Create;
  function GetPlatformName:string;
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  procedure GetRealScreenSize(out width,height:integer);
  function GetScreenDPI:integer;

  function GetMousePos:TPoint; // Get mouse position on screen
  procedure SetMousePos(scrX,scrY:integer); // Move mouse cursor (screen coordinates)
  function GetSystemCursor(cursorId:integer):THandle;
  function LoadCursor(fname:string):THandle;
  procedure SetCursor(cur:THandle);
  procedure FreeCursor(cur:THandle);

  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;
  function CreateWindow(title:string):TWindow;
 end;

implementation
uses {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  SysUtils, Apus.Core, Apus.Log, Apus.Files, Apus.Strings, Apus.EventMan, Apus.Engine.Game, Apus.Images,
  Apus.GfxFormats, Apus.Engine.Controller;

type
 TSDLController=record
  joystick:PSDL_Joystick;
  controller:PSDL_GameController;
 end;
var
 terminated:boolean;
 mouseState:byte;
 savedLogHandler:TSDL_LogOutputFunction;
 SDLcontrollers:array[0..high(controllers)] of TSDLController;

procedure InitJoystick(idx:integer);
 begin
   ASSERT(idx in [0..high(controllers)]);
   if idx>high(controllers) then begin
    Log.Msg('SDL joystick %d not supported',[idx]);
    exit;
   end;
   Log.Msg('Init SDL joystick %d',[idx]);
   Mem.Clear(controllers[idx],sizeof(controllers[idx]));
   with SDLcontrollers[idx] do begin
    joystick:=SDL_JoystickOpen(idx);
    if joystick<>nil then with controllers[idx] do begin
      controllerType:=gcJoystick;
      numAxes:=SDL_JoystickNumAxes(joystick);
      numButtons:=SDL_JoystickNumButtons(joystick);
      name:=SDL_JoystickName(joystick);
      Log.Msg('SDL joystick: "%s" axes:%d, buttons:%d',[name,numAxes,numButtons]);
    end;
    if SDL_IsGameController(idx)=SDL_TRUE then begin
      Log.Msg('SDL: joystick %d is controller',[idx]);
      controller:=SDL_GameControllerOpen(idx);
      if controller<>nil then begin
        controllers[idx].controllerType:=gcGamepad;
      end;
    end;
   end;
   controllers[idx].index:=idx;
 end;

procedure InitControllers;
 var
  i,n:integer;
 begin
  n:=SDL_NumJoysticks;
  for i:=0 to Clamp(n-1,0,3) do begin
   InitJoystick(i);
  end;
 end;

{ TSDLGLWindow }

constructor TSDLGLWindow.Create(aWnd:PSDL_Window;windowName:string='MainWnd');
 begin
  inherited Create(windowName);
  wnd:=aWnd;
  ctx:=nil;
 end;

{ TSDLPlatform }

function TSDLPlatform.CanChangeSettings:boolean;
 begin
  result:=true;
 end;

procedure TSDLGLWindow.ClientToScreen(var p:TPoint);
 var
  x,y:integer;
 begin
  SDL_GetWindowPosition(wnd,@x,@y);
  inc(p.x,x);
  inc(p.y,y);
 end;

procedure TSDLGLWindow.ScreenToClient(var p:TPoint);
 begin

 end;

procedure TSDLGLWindow.Close;
 begin
  SDL_DestroyWindow(wnd);
  wnd:=nil;
 end;

procedure TSDLGLWindow.FlashWindow(count:integer);
 begin
 end;

function TSDLPlatform.GetMousePos:TPoint;
 begin
  SDL_GetMouseState(@result.X, @result.Y)
 end;

procedure TSDLPlatform.SetMousePos(scrX,scrY:integer);
 begin
  SDL_WarpMouseGlobal(scrX,scrY);
 end;

function TSDLPlatform.GetPlatformName:string;
 begin
  result:='SDL';
 end;

function TSDLPlatform.GetScreenDPI:integer;
 var
  ddpi:single;
 begin
  if SDL_GetDisplayDPI(0,@ddpi,nil,nil)<>0 then begin
   Log.Force('SDL: DPI query failed: '+SDL_GetError+' Assume 96 DPI');
   exit(96);
  end;
  result:=round(ddpi);
 end;

procedure TSDLPlatform.GetScreenSize(out width, height: integer);
 var
  mode:TSDL_DisplayMode;
 begin
  SDL_GetDesktopDisplayMode(0,@mode);
  width:=mode.w;
  height:=mode.h;
 end;

procedure TSDLPlatform.GetRealScreenSize(out width,height:integer);
 begin
  // not possible to query before window creation
  width:=0;
  height:=0;
 end;

function TSDLPlatform.GetShiftKeysState: cardinal;
 var
  keys:TSDL_KeyMod;
 begin
  result:=0;
  keys:=SDL_GetModState;
  if keys and KMOD_SHIFT>0 then inc(result,sscShift);
  if keys and KMOD_CTRL>0 then inc(result,sscCtrl);
  if keys and KMOD_ALT>0 then inc(result,sscAlt);
  if keys and KMOD_GUI>0 then inc(result,sscWin);
 end;

function TSDLPlatform.GetMouseButtons: cardinal;
 begin
  result:=mouseState;
 end;

function TSDLPlatform.GetSystemCursor(cursorId: integer): THandle;
 var
  cur:integer;  // not WORD because of Delphi calling convention issue
 begin
  case cursorID of
   Apus.Engine.API.CursorID.Default:cur:=SDL_SYSTEM_CURSOR_ARROW;
   Apus.Engine.API.CursorID.Link:cur:=SDL_SYSTEM_CURSOR_HAND;
   Apus.Engine.API.CursorID.Wait:cur:=SDL_SYSTEM_CURSOR_WAIT;
   Apus.Engine.API.CursorID.Input:cur:=SDL_SYSTEM_CURSOR_IBEAM;
   Apus.Engine.API.CursorID.Help:cur:=SDL_SYSTEM_CURSOR_WAITARROW;
   Apus.Engine.API.CursorID.ResizeH:cur:=SDL_SYSTEM_CURSOR_SIZENS;
   Apus.Engine.API.CursorID.ResizeW:cur:=SDL_SYSTEM_CURSOR_SIZEWE;
   Apus.Engine.API.CursorID.ResizeHW:cur:=SDL_SYSTEM_CURSOR_SIZEALL;
   Apus.Engine.API.CursorID.Cross:cur:=SDL_SYSTEM_CURSOR_CROSSHAIR;
  end;
  result:=THandle(SDL_CreateSystemCursor(cur));
  if result=0 then
   Log.Msg('Error - SDL_CSC failed: '+SDL_GetError);
 end;

function TSDLPlatform.LoadCursor(fname:string):THandle;
 var
  surface:PSDL_Surface;
  data:ByteArray;
  image:TRawImage;
  hotX,hotY:integer;
  cursor:PSDL_Cursor;
 begin
  try
   data:=Files.LoadAsBytes(Files.FixName(fname));
   image:=nil;
   LoadCUR(data,image,hotX,hotY);
   image.Lock;
   surface:=SDL_CreateRGBSurfaceFrom(image.data,image.width,image.height,32,image.pitch,
     $FF0000,$FF00,$FF,$FF000000);
   if surface=nil then raise EWarning.Create('Surface creation failed: '+SDL_GetError);
   cursor:=SDL_CreateColorCursor(surface,hotX,hotY);
   SDL_FreeSurface(surface);
   image.Unlock;
   result:=THandle(cursor);
  except
   on e:Exception do
    raise EWarning.Create('Failed to load cursor from %s: %s',[fname,ExceptionMsg(e)]);
  end;
 end;

procedure TSDLPlatform.SetCursor(cur:THandle);
 begin
  SDL_SetCursor(pointer(cur));
 end;

procedure TSDLPlatform.FreeCursor(cur:THandle);
 begin
  SDL_FreeCursor(pointer(cur));
 end;


function TSDLGLWindow.GetHandle:THandle;
 begin
  if wnd=nil then exit(0);
  result:=THandle(SDL_GetWindowID(wnd));
 end;

procedure TSDLGLWindow.GetSize(out width,height:integer);
 begin
  if wnd=nil then begin
   width:=0; height:=0;
  end else
   SDL_GetWindowSize(wnd,@width,@height);
 end;

procedure MyLogHandler(userdata: Pointer; category: TSDL_LogCategory; priority: TSDL_LogPriority; const msg: PAnsiChar); cdecl;
 begin
  if priority>=SDL_LOG_PRIORITY_ERROR then
   Log.Force('SDL: '+msg)
  else
   Log.Msg('SDL: '+msg);
  if Assigned(savedLogHandler) then
   savedLogHandler(userData,category,priority,msg);
 end;

constructor TSDLPlatform.Create;
 var
  plName:AnsiString;
  ver:TSDL_Version;
 begin
  {$IFDEF MSWINDOWS}
  SetEnvironmentVariable('SDL_AUDIODRIVER','winmm');
  {$ENDIF}
  if SDL_Init(SDL_INIT_EVERYTHING)<>0 then
   raise EError.Create('SDL init error: '+SDL_GetError);
  plName:=SDL_GetPlatform;
  SDL_GetVersion(@ver);
  SDL_LogGetOutputFunction(@savedLogHandler,nil);
  SDL_LogSetOutputFunction(MyLogHandler,nil);
  Log.Msg('SDL Platform Initialized. System: %s, runtime %d.%d.%d, headers %d.%d.%d',
    [plName,ver.major,ver.minor,ver.patch,SDL_MAJOR_VERSION,SDL_MINOR_VERSION,SDL_PATCHLEVEL]);
  InitControllers;
 end;

function TSDLPlatform.CreateWindow(title:string):TWindow;
 var
  ust:UTF8String;
  localWindow:PSDL_Window;
 begin
   Log.Msg('CreateMainWindow');
   ust:=title;
   localWindow:=SDL_CreateWindow(PAnsiChar(ust),SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,100,100,
    SDL_WINDOW_OPENGL+SDL_WINDOW_HIDDEN+SDL_WINDOW_ALLOW_HIGHDPI{+SDL_WINDOW_RESIZABLE});
   if localWindow=nil then
    raise EError.Create('SDL window creation failed');
   result:=TSDLGLWindow.Create(localWindow,title);
  end;

function PackWords(p1,p2:integer):TTag;
 begin
  result:=TTag((p1 and $FFFF)+(p2 and $FFFF) shl 16);
 end;

function GetMouseButtonNum(btn:integer):integer;
 begin
  case btn of
   SDL_BUTTON_LEFT:exit(1);
   SDL_BUTTON_RIGHT:exit(2);
   SDL_BUTTON_MIDDLE:exit(3);
  end;
  result:=0;
 end;

function GetScancode(sdl_scancode:integer):byte;
 begin
  result:=sdl_scancode;
  case sdl_scancode of
   SDL_SCANCODE_ESCAPE:result:=1;
   SDL_SCANCODE_RETURN:result:=$1C;
   SDL_SCANCODE_GRAVE:result:=$29;
   SDL_SCANCODE_LEFT:result:=$4B;
   SDL_SCANCODE_RIGHT:result:=$4D;
   SDL_SCANCODE_UP:result:=$48;
   SDL_SCANCODE_DOWN:result:=$50;
  end;
 end;

function GetKeyCode(sdl_keycode:integer):integer;
 var
  c:char;
 begin
  result:=sdl_keycode;
   case sdl_keycode of
    ord('a')..ord('z'):begin
     c:=UpCase(char(sdl_keycode));
     result:=ord(c);
    end;
    SDLK_F1:result:=integer(TKey.F1);
    SDLK_F2:result:=integer(TKey.F2);
    SDLK_F3:result:=integer(TKey.F3);
    SDLK_F4:result:=integer(TKey.F4);
    SDLK_F5:result:=integer(TKey.F5);
    SDLK_F6:result:=integer(TKey.F6);
    SDLK_F7:result:=integer(TKey.F7);
    SDLK_F8:result:=integer(TKey.F8);
    SDLK_F9:result:=integer(TKey.F9);
    SDLK_F10:result:=integer(TKey.F10);
    SDLK_F11:result:=integer(TKey.F11);
    SDLK_F12:result:=integer(TKey.F12);
    SDLK_PRINTSCREEN:result:=integer(TKey.PrintScreen);

    SDLK_TAB:result:=integer(TKey.Tab);
    SDLK_LEFT:result:=integer(TKey.Left);
    SDLK_RIGHT:result:=integer(TKey.Right);
    SDLK_UP:result:=integer(TKey.Up);
    SDLK_DOWN:result:=integer(TKey.Down);
    SDLK_HOME:result:=integer(TKey.Home);
    SDLK_END:result:=integer(TKey.EndKey);
    SDLK_PAGEUP:result:=integer(TKey.PageUp);
    SDLK_PAGEDOWN:result:=integer(TKey.PageDown);
    SDLK_INSERT:result:=integer(TKey.Insert);
    SDLK_DELETE:result:=integer(TKey.Delete);
    SDLK_BACKQUOTE:result:=integer(TKey.Tilde);
    SDLK_BACKSPACE:result:=integer(TKey.Backspace);
   end;
  end;

procedure ProcessControllerEvent(event:TSDL_Event);
 var
  n,axis,button:integer;
  cButton:TConButtonType;
  tag:TTag;
 function ValidN:boolean;
  begin
   result:=(n>=0) and (n<=high(controllers));
  end;
 begin
  case event.type_ of
   SDL_JOYDEVICEADDED:InitJoystick(event.jdevice.which);

   SDL_JOYDEVICEREMOVED:begin
    n:=event.jdevice.which;
    if not ValidN then exit;
    Log.Msg('SDL: delete controller %d',[n]);
    controllers[n].controllerType:=gcUnplugged;
    with SDLcontrollers[n] do begin
     if controller<>nil then begin
      SDL_GameControllerClose(controller);
      controller:=nil;
     end;
     if joystick<>nil then begin
      SDL_JoystickClose(joystick);
      joystick:=nil;
     end;
    end;
   end;

   SDL_JOYAXISMOTION:begin
    n:=event.jaxis.which;
    if not ValidN then exit;
    axis:=event.jaxis.axis;
    if axis in [0..7] then
     controllers[n].axes[TConAxisType(axis)]:=Clamp(event.jaxis.value/32767,-1,1);
   end;

   SDL_JOYBUTTONDOWN,SDL_JOYBUTTONUP:begin
    n:=event.jbutton.which;
    if not ValidN then exit;
    button:=event.jbutton.button;
    if button in [0..15] then begin
     tag:=PackTag(button,n,0,0);
     if event.type_=SDL_JOYBUTTONDOWN then begin
      Bits.SetBit(controllers[n].buttons,button,true);
      Signal('JOY\BTNDOWN',tag);
     end else begin
      Bits.SetBit(controllers[n].buttons,button,false);
      Signal('JOY\BTNUP',tag);
     end;
    end;
   end;

   SDL_CONTROLLERAXISMOTION:begin
    //event.caxis.which
   end;

   SDL_CONTROLLERBUTTONDOWN,SDL_CONTROLLERBUTTONUP:begin
    n:=event.cbutton.which;
    if not ValidN then exit;
    case event.cbutton.button of
     SDL_CONTROLLER_BUTTON_A: cButton:=btButtonA;
     SDL_CONTROLLER_BUTTON_B: cButton:=btButtonB;
     SDL_CONTROLLER_BUTTON_X: cButton:=btButtonX;
     SDL_CONTROLLER_BUTTON_Y: cButton:=btButtonY;
     SDL_CONTROLLER_BUTTON_BACK: cButton:=btButtonBack;
     SDL_CONTROLLER_BUTTON_GUIDE: cButton:=btButtonGuide;
     SDL_CONTROLLER_BUTTON_START: cButton:=btButtonStart;
     SDL_CONTROLLER_BUTTON_DPAD_UP: cButton:=btButtonDPadUp;
     SDL_CONTROLLER_BUTTON_DPAD_DOWN: cButton:=btButtonDPadDown;
     SDL_CONTROLLER_BUTTON_DPAD_LEFT: cButton:=btButtonDPadLeft;
     SDL_CONTROLLER_BUTTON_DPAD_RIGHT: cButton:=btButtonDPadRight;
     else cButton:=btButton0;
    end;
    if cButton<btButtonA then exit;
    // Tag: byte0 = button, byte1 = controller
    tag:=PackTag(ord(cButton),n,0,0);
    if event.type_=SDL_CONTROLLERBUTTONDOWN then begin
     Bits.SetBit(controllers[n].buttons,ord(cButton),true);
     Signal('GAMEPAD\BTNDOWN\'+Apus.Engine.Controller.GetButtonName(cButton),tag);
    end else begin
     Bits.SetBit(controllers[n].buttons,ord(cButton),false);
     Signal('GAMEPAD\BTNUP\'+Apus.Engine.Controller.GetButtonName(cButton),tag);
    end;
   end;
  end;
 end;

procedure TSDLGLWindow.ProcessMessages;
 var
  event:TSDL_Event;
  ust:String8;
  wst:String16;
  i,len:integer;
  mbtn:integer;
 begin
  while SDL_PollEvent(@event)<>0 do begin
   if game=nil then continue;
   case event.type_ of
    SDL_WINDOWEVENT:begin
     case event.window.event of
      SDL_WINDOWEVENT_FOCUS_GAINED:;
      SDL_WINDOWEVENT_FOCUS_LOST:;
      SDL_WINDOWEVENT_HIDDEN:begin
       Log.Msg('Window hidden');
       Signal('ENGINE\SETACTIVE',0);
       Signal('ENGINE\WINDOW\HIDDEN');
      end;
      SDL_WINDOWEVENT_SHOWN:begin
       Log.Msg('Window shown');
       Signal('ENGINE\SETACTIVE',1);
       Signal('ENGINE\WINDOW\SHOWN');
      end;
      SDL_WINDOWEVENT_MINIMIZED:begin
       Log.Msg('Window minimized');
       Signal('ENGINE\SETACTIVE',0);
       Signal('ENGINE\WINDOW\MINIMIZED');
      end;
      SDL_WINDOWEVENT_RESTORED:begin
       Log.Msg('Window restored');
       Signal('ENGINE\SETACTIVE',1);
       Signal('ENGINE\WINDOW\RESTORED');
      end;
      SDL_WINDOWEVENT_MAXIMIZED:begin
       Log.Msg('Window maximized');
       Signal('ENGINE\WINDOW\MAXIMIZED');
      end;
      SDL_WINDOWEVENT_CLOSE:begin
       Log.Msg('Window close');
       Signal('ENGINE\WINDOW\CLOSE');
      end;
      SDL_WINDOWEVENT_RESIZED:Signal('ENGINE\RESIZE',PackWords(event.window.data1,event.window.data2));
      {SDL_WINDOWEVENT_SIZE_CHANGED:begin
       LogMessage('SDL_SIZE_CHANGED: reported size - (%d x %d), render size - (%d,%d)',
         [event.window.data1,event.window.data2,w,h]);
       Signal('ENGINE\RESIZE',PackWords(event.window.data1,event.window.data2));
      end;}
     end;
    end;

    SDL_MOUSEMOTION:Signal('MOUSE\CLIENTMOVE',PackWords(event.motion.x,event.motion.y));

    SDL_MOUSEBUTTONDOWN:begin
     if not game.GetSettings.showSystemCursor then SetCursor(0);
     mbtn:=GetMouseButtonNum(event.button.button);
     if mBtn in [1..5] then
      mouseState:=mouseState or (1 shl (mbtn-1));
     Signal('MOUSE\BTNDOWN',mbtn);
    end;

    SDL_MOUSEBUTTONUP:begin
     if not game.GetSettings.showSystemCursor then SetCursor(0);
     mbtn:=GetMouseButtonNum(event.button.button);
     if mBtn in [1..5] then
      mouseState:=mouseState and not (1 shl (mbtn-1));
     Signal('MOUSE\BTNUP',mbtn);
    end;

    SDL_MOUSEWHEEL:begin
     Signal('MOUSE\SCROLL',event.wheel.y);
    end;

    SDL_KEYDOWN:begin
     Signal('KBD\KEYDOWN',GetKeyCode(event.key.keysym.sym) and $FFFF+
       GetScanCode(event.key.keysym.scancode) shl 16);
    end;

    SDL_KEYUP:begin
     Signal('KBD\KEYUP',GetKeyCode(event.key.keysym.sym) and $FFFF+
       GetScanCode(event.key.keysym.scancode) shl 16);
    end;

    SDL_TEXTINPUT:begin
     len:=StrLen(event.text.text);
     SetLength(ust,len);
     move(event.text.text,ust[1],len);
     wst:=UTF8.ToWide(ust);
     for i:=1 to length(wst) do
      Signal('KBD\UNICHAR',word(wst[i]));
    end;

    SDL_QUITEV:begin
     terminated:=true;
     Signal('Engine\Cmd\Exit',0);
    end;

    SDL_JOYAXISMOTION..SDL_JOYDEVICEREMOVED:ProcessControllerEvent(event);
    SDL_CONTROLLERAXISMOTION..SDL_CONTROLLERDEVICEREMAPPED:ProcessControllerEvent(event);

   end;
  end;
 end;

function TSDLGLWindow.IsTerminated:boolean;
 begin
  result:=terminated;
 end;

procedure TSDLGLWindow.Minimize;
 begin
  SDL_MinimizeWindow(wnd);
 end;

procedure TSDLGLWindow.MoveTo(x,y:integer;width:integer;
  height: integer);
 begin
  if (width>0) and (height>0) then
   SDL_SetWindowSize(wnd,width,height);
  SDL_SetWindowPosition(wnd,x,y);
 end;

function TSDLGLWindow.CreateOpenGLContext(var graph:TOpenGLContextDesc):UIntPtr;
 var
  major,minor,profile,flags,profileMask:integer;
  requestedProfile:TOpenGLContextProfile;
  requestedDebug,requestedForward:boolean;
 begin
  Log.Msg('Create GL Context');
  requestedProfile:=graph.profile;
  requestedDebug:=graph.debugContext;
  requestedForward:=graph.forwardCompatible;
  major:=graph.minMajor;
  minor:=graph.minMinor;
  if (major<3) or ((major=3) and (minor<2)) then begin
   major:=3;
   minor:=2;
  end;
  profileMask:=SDL_GL_CONTEXT_PROFILE_COMPATIBILITY;
  if requestedProfile=oglpCore then
   profileMask:=SDL_GL_CONTEXT_PROFILE_CORE;

  flags:=0;
  if requestedDebug then flags:=flags or SDL_GL_CONTEXT_DEBUG_FLAG;
  if requestedForward then flags:=flags or SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG;
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,major);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,minor);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,profileMask);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS,flags);
  ctx:=SDL_GL_CreateContext(wnd);
  result:=UIntPtr(ctx);

  graph.actualMajor:=0;
  graph.actualMinor:=0;
  graph.profile:=oglpAny;
  graph.debugContext:=false;
  graph.forwardCompatible:=false;
  graph.requestAccepted:=ctx<>nil;
  if ctx<>nil then begin
   SDL_GL_GetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,@major);
   SDL_GL_GetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,@minor);
   SDL_GL_GetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,@profile);
   SDL_GL_GetAttribute(SDL_GL_CONTEXT_FLAGS,@flags);
   graph.actualMajor:=major;
   graph.actualMinor:=minor;
   case profile of
    SDL_GL_CONTEXT_PROFILE_CORE:graph.profile:=oglpCore;
    SDL_GL_CONTEXT_PROFILE_COMPATIBILITY:graph.profile:=oglpCompatibility;
    else graph.profile:=oglpAny;
   end;
   graph.debugContext:=(flags and SDL_GL_CONTEXT_DEBUG_FLAG)<>0;
   graph.forwardCompatible:=(flags and SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG)<>0;
    graph.requestAccepted:=graph.requestAccepted and
     ((requestedProfile=oglpAny) or (graph.profile=requestedProfile)) and
     ((not requestedDebug) or graph.debugContext) and
     ((not requestedForward) or graph.forwardCompatible);
   end;
  end;

procedure TSDLGLWindow.InitGraph;
 begin
  graphInfo:=oglContextTemplate;
  graphInfo.actualMajor:=0;
  graphInfo.actualMinor:=0;
  graphInfo.requestAccepted:=false;
  if CreateOpenGLContext(graphInfo)=0 then
   raise EError.Create('Can''t create OpenGL context');
  oglContextInfo:=graphInfo;
 end;

procedure TSDLGLWindow.PresentFrame;
 begin
  SDL_GL_SwapWindow(wnd);
 end;

function TSDLGLWindow.SetVSync(divider:integer):boolean;
begin
  result:=SDL_GL_SetSwapInterval(divider)=0;
end;

procedure TSDLGLWindow.DoneGraph;
 begin
  if ctx<>nil then
   SDL_GL_DeleteContext(ctx);
  ctx:=nil;
 end;

procedure TSDLGLWindow.Configure(params:TGameSettings);
 var
  mode:TSDL_DisplayMode;
  w,h,screenWidth,screenHeight,clientWidth,clientHeight:integer;
 begin
   Log.Msg('Configure main window');

   SDL_GetDesktopDisplayMode(0,@mode);
   screenWidth:=mode.w;
   screenHeight:=mode.h;
   w:=params.width;
   h:=params.height;
   if params.mode.displayMode=dmBorderless then
    SDL_SetWindowBordered(wnd,SDL_FALSE);
   case params.mode.displayMode of
    dmWindow,dmFixedWindow,dmBorderless:begin
      SDL_SetWindowFullscreen(wnd,0);
      if params.mode.displayMode=dmWindow then
        SDL_SetWindowResizable(wnd,SDL_TRUE)
      else
        SDL_SetWindowResizable(wnd,SDL_FALSE);

      SDL_SetWindowSize(wnd,w,h);
      SDL_GetWindowSize(wnd,@w,@h);
      MoveTo((screenWidth-w) div 2,(screenHeight-h) div 2,-1,-1);
    end;
    dmFullScreen:begin
      SDL_SetWindowFullscreen(wnd,SDL_WINDOW_FULLSCREEN_DESKTOP);
    end;
    dmSwitchResolution:begin
      SDL_SetWindowFullscreen(wnd,SDL_WINDOW_FULLSCREEN);
    end;
   end;

   SDL_ShowWindow(wnd);
//   SDL_SetWindowSize();

   SDL_GL_GetDrawableSize(wnd,@clientWidth,@clientHeight);
   Log.Msg('Client size: %d %d',[clientWidth,clientHeight]);
   Signal('ENGINE\RESIZE',clientWidth+clientHeight shl 16);
 end;

procedure TSDLGLWindow.SetCaption(text:string);
 var
  ust:UTF8String;
 begin
  ust:=text;
  SDL_SetWindowTitle(wnd,PAnsiChar(ust));
 end;

procedure TSDLGLWindow.Show(show:boolean);
 begin
  if show then
   SDL_ShowWindow(wnd)
  else
   SDL_HideWindow(wnd);
 end;

function TSDLPlatform.MapScanCodeToVirtualKey(key:integer):integer;
 begin
  //result:=MapVirtualKey(key,MAPVK_VSC_TO_VK);
 end;


end.
