// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.SDLplatform;
interface
uses Apus.CrossPlatform, Apus.Engine.API;

type
 
 { TSDLPlatform }

 TSDLPlatform=class(TInterfacedObject,ISystemPlatform)
  constructor Create;
  function GetPlatformName:string;
  function CanChangeSettings:boolean;
  procedure GetScreenSize(out width,height:integer);
  function GetScreenDPI:integer;

  procedure CreateWindow(title:string);
  procedure SetupWindow(params:TGameSettings);
  function GetWindowHandle:THandle;
  procedure GetWindowSize(out width,height:integer);
  procedure DestroyWindow;

  procedure ShowWindow(show:boolean);
  procedure MoveWindowTo(x,y:integer;width:integer=0;height:integer=0);
  procedure SetWindowCaption(text:string);
  procedure Minimize;
  procedure FlashWindow(count:integer);

  procedure ProcessSystemMessages;
  function IsTerminated:boolean;

  function GetMousePos:TPoint; // Get mouse position on screen
  function GetSystemCursor(cursorId:integer):THandle;
  function LoadCursor(fname:string):THandle;
  procedure SetCursor(cur:THandle);
  procedure FreeCursor(cur:THandle);

  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;

  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  function CreateOpenGLContext:UIntPtr;
  procedure OGLSwapBuffers;
  function SetSwapInterval(divider:integer):boolean;
  procedure DeleteOpenGLContext;
 end;

implementation
uses Types, Apus.MyServis, SysUtils, Apus.EventMan, Apus.Engine.Game, Apus.Images,
  Apus.GfxFormats, sdl2, Apus.Engine.Controller;

type
 TSDLController=record
  joystick:PSDL_Joystick;
  controller:TSDL_GameController;
 end;
var
 window:PSDL_Window;
 context:TSDL_GLContext;
 terminated:boolean;
 mouseState:byte;
 savedLogHandler:TSDL_LogOutputFunction;
 SDLcontrollers:array[0..high(controllers)] of TSDLController;

procedure InitJoystick(idx:integer);
 begin
   ASSERT(idx in [0..high(controllers)]);
   if idx>high(controllers) then begin
    LogMessage('SDL joystick %d not supported',[idx]);
    exit;
   end;
   LogMessage('Init SDL joystick %d',[idx]);
   ZeroMem(controllers[idx],sizeof(controllers[idx]));
   with SDLcontrollers[idx] do begin
    joystick:=SDL_JoystickOpen(idx);
    if joystick<>nil then with controllers[idx] do begin
      controllerType:=gcJoystick;
      numAxes:=SDL_JoystickNumAxes(joystick);
      numButtons:=SDL_JoystickNumButtons(joystick);
      name:=SDL_JoystickName(joystick);
      LogMessage('SDL joystick: "%s" axes:%d, buttons:%d',[name,numAxes,numButtons]);
    end;
    if SDL_IsGameController(idx)=SDL_TRUE then begin
      LogMessage('SDL: joystick %d is controller',[idx]);
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

{ TSDLPlatform }

function TSDLPlatform.CanChangeSettings: boolean;
 begin
  result:=true;
 end;

procedure TSDLPlatform.ClientToScreen(var p: TPoint);
 begin
 end;

procedure TSDLPlatform.DestroyWindow;
 begin
  SDL_DestroyWindow(window);
 end;

procedure TSDLPlatform.FlashWindow(count: integer);
 begin
 end;

procedure TSDLPlatform.ScreenToClient(var p: TPoint);
 begin
 end;

function TSDLPlatform.GetMousePos: TPoint;
 begin
  SDL_GetMouseState(@result.X, @result.Y)
 end;

function TSDLPlatform.GetPlatformName: string;
 begin
  result:='SDL';
 end;

function TSDLPlatform.GetScreenDPI: integer;
 var
  ddpi:single;
 begin
  if SDL_GetDisplayDPI(0,@ddpi,nil,nil)<>0 then begin
   ForceLogMessage('SDL: DPI query failed: '+SDL_GetError+' Assume 96 DPI');
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
   crDefault:cur:=SDL_SYSTEM_CURSOR_ARROW;
   crLink:cur:=SDL_SYSTEM_CURSOR_HAND;
   crWait:cur:=SDL_SYSTEM_CURSOR_WAIT;
   crInput:cur:=SDL_SYSTEM_CURSOR_IBEAM;
   crHelp:cur:=SDL_SYSTEM_CURSOR_WAITARROW;
   crResizeH:cur:=SDL_SYSTEM_CURSOR_SIZENS;
   crResizeW:cur:=SDL_SYSTEM_CURSOR_SIZEWE;
   crResizeHW:cur:=SDL_SYSTEM_CURSOR_SIZEALL;
   crCross:cur:=SDL_SYSTEM_CURSOR_CROSSHAIR;
  end;
  result:=THandle(SDL_CreateSystemCursor(cur));
  if result=0 then
   LogMessage('Error - SDL_CSC failed: '+SDL_GetError);
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
   data:=LoadFileAsBytes(filename(fname));
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


function TSDLPlatform.GetWindowHandle: THandle;
 begin
  result:=window.id;
 end;

procedure TSDLPlatform.GetWindowSize(out width, height: integer);
 begin
  width:=window.w;
  height:=window.h;
 end;

procedure MyLogHandler(userdata: Pointer; category: Integer; priority: TSDL_LogPriority; const msg: PAnsiChar);
 begin
  if priority>=SDL_LOG_PRIORITY_ERROR then
   ForceLogMessage('SDL: '+msg)
  else
   LogMessage('SDL: '+msg);
  if @savedLogHandler<>nil then savedLogHandler(userData,category,priority,msg);
 end;

constructor TSDLPlatform.Create;
 var
  plName:AnsiString;
  ver:TSDL_Version;
 begin
  if SDL_Init(SDL_INIT_EVERYTHING)<>0 then
   raise EError.Create('SDL init error: '+SDL_GetError);
  plName:=SDL_GetPlatform;
  SDL_GetVersion(@ver);
  SDL_LogGetOutputFunction(@savedLogHandler,nil);
  SDL_LogSetOutputFunction(MyLogHandler,nil);
  LogMessage('SDL Initialized. Platform: %s, version %d.%d',[plName,ver.major,ver.minor]);
  InitControllers;
 end;

procedure TSDLPlatform.CreateWindow(title: string);
 var
  ust:UTF8String;
 begin
   LogMessage('CreateMainWindow');
   ust:=title;
   window:=SDL_CreateWindow(PAnsiChar(ust),SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,100,100,
    SDL_WINDOW_OPENGL+SDL_WINDOW_HIDDEN+SDL_WINDOW_ALLOW_HIGHDPI{+SDL_WINDOW_RESIZABLE});
   if window=nil then
    raise EError.Create('SDL window creation failed');
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
   SDLK_F1:result:=VK_F1;
   SDLK_F2:result:=VK_F2;
   SDLK_F3:result:=VK_F3;
   SDLK_F4:result:=VK_F4;
   SDLK_F5:result:=VK_F5;
   SDLK_F6:result:=VK_F6;
   SDLK_F7:result:=VK_F7;
   SDLK_F8:result:=VK_F8;
   SDLK_F9:result:=VK_F9;
   SDLK_F10:result:=VK_F10;
   SDLK_F11:result:=VK_F11;
   SDLK_F12:result:=VK_F12;
   SDLK_PRINTSCREEN:result:=VK_SNAPSHOT;

   SDLK_TAB:result:=VK_TAB;
   SDLK_LEFT:result:=VK_LEFT;
   SDLK_RIGHT:result:=VK_RIGHT;
   SDLK_UP:result:=VK_UP;
   SDLK_DOWN:result:=VK_DOWN;
   SDLK_HOME:result:=VK_HOME;
   SDLK_END:result:=VK_END;
   SDLK_PAGEUP:result:=VK_PAGEUP;
   SDLK_PAGEDOWN:result:=VK_PAGEDOWN;
   SDLK_INSERT:result:=VK_INSERT;
   SDLK_DELETE:result:=VK_DELETE;
   SDLK_BACKQUOTE:result:=$C0; //VK_OEM3
   SDLK_BACKSPACE:result:=VK_BACK;
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
    LogMessage('SDL: delete controller %d',[n]);
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
     tag:=PackTag(button,n);
     if event.type_=SDL_JOYBUTTONDOWN then begin
      SetBit(controllers[n].buttons,button);
      Signal('JOY\BTNDOWN',tag);
     end else begin
      ClearBit(controllers[n].buttons,button);
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
    tag:=PackTag(ord(cButton),n);
    if event.type_=SDL_CONTROLLERBUTTONDOWN then begin
     SetBit(controllers[n].buttons,ord(cButton));
     Signal('GAMEPAD\BTNDOWN\'+Apus.Engine.Controller.GetButtonName(cButton),tag);
    end else begin
     ClearBit(controllers[n].buttons,ord(cButton));
     Signal('GAMEPAD\BTNUP\'+Apus.Engine.Controller.GetButtonName(cButton),tag);
    end;
   end;
  end;
 end;

procedure TSDLPlatform.ProcessSystemMessages;
 var
  event:TSDL_Event;
  ust:String8;
  wst:String16;
  i,len:integer;
  mbtn:integer;
  w,h:integer;
  r:TRect;
  info:TSDL_SysWMinfo;
 begin
  while SDL_PollEvent(@event)<>0 do begin
   if game=nil then continue;
   case event.type_ of
    SDL_WINDOWEVENT:begin
     case event.window.event of
      SDL_WINDOWEVENT_FOCUS_GAINED:Signal('ENGINE\SETACTIVE',1);
      SDL_WINDOWEVENT_FOCUS_LOST:Signal('ENGINE\SETACTIVE',0);
      //SDL_WINDOWEVENT_RESIZED:Signal('ENGINE\RESIZE',PackWords(event.window.data1,event.window.data2));
      SDL_WINDOWEVENT_SIZE_CHANGED:begin
{       LogMessage('SDL_SIZE_CHANGED: reported size - (%d x %d), render size - (%d,%d)',
         [event.window.data1,event.window.data2,w,h]);}
       Signal('ENGINE\RESIZE',PackWords(event.window.data1,event.window.data2));
      end;
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
     wst:=DecodeUTF8(ust);
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

function TSDLPlatform.IsTerminated:boolean;
 begin
  result:=terminated;
 end;

procedure TSDLPlatform.Minimize;
 begin
  SDL_MinimizeWindow(window);
 end;

procedure TSDLPlatform.MoveWindowTo(x, y: integer; width: integer;
  height: integer);
 begin
  if (width>0) and (height>0) then
   SDL_SetWindowSize(window,width,height);
  SDL_SetWindowPosition(window,x,y);
 end;

function TSDLPlatform.CreateOpenGLContext:UIntPtr;
 begin
  LogMessage('Create GL Context');
  context:=SDL_GL_CreateContext(window);
 end;

procedure TSDLPlatform.OGLSwapBuffers;
 begin
  SDL_GL_SwapWindow(window);
 end;

function TSDLPlatform.SetSwapInterval(divider: integer):boolean;
begin
  result:=SDL_GL_SetSwapInterval(divider)=0;
end;

procedure TSDLPlatform.DeleteOpenGLContext;
 begin
  SDL_GL_DeleteContext(context);
 end;

procedure TSDLPlatform.SetupWindow(params:TGameSettings);
 var
  w,h,screenWidth,screenHeight,clientWidth,clientHeight:integer;
 begin
   LogMessage('Configure main window');

   GetScreenSize(screenWidth,screenHeight);
   w:=params.width;
   h:=params.height;
   case params.mode.displayMode of
    dmWindow,dmFixedWindow:begin
      SDL_SetWindowFullscreen(window,0);
      if params.mode.displayMode=dmWindow then
        SDL_SetWindowResizable(window,SDL_TRUE)
      else
        SDL_SetWindowResizable(window,SDL_FALSE);

      SDL_SetWindowSize(window,w,h);
      SDL_GetWindowSize(window,@w,@h);
      MoveWindowTo((screenWidth-w) div 2,(screenHeight-h) div 2, -1,-1);
    end;
    dmFullScreen:begin
      SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN_DESKTOP);
    end;
    dmSwitchResolution:begin
      SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN);
    end;
   end;

   SDL_ShowWindow(window);
//   SDL_SetWindowSize();

   SDL_GL_GetDrawableSize(window,@clientWidth,@clientHeight);
   LogMessage('Client size: %d %d',[clientWidth,clientHeight]);
   Signal('ENGINE\RESIZE',clientWidth+clientHeight shl 16);
 end;

procedure TSDLPlatform.SetWindowCaption(text: string);
 var
  ust:UTF8String;
 begin
  ust:=text;
  SDL_SetWindowTitle(window,PAnsiChar(ust));
 end;

procedure TSDLPlatform.ShowWindow(show: boolean);
 begin
  if show then
   SDL_ShowWindow(window)
  else
   SDL_HideWindow(window);
 end;

function TSDLPlatform.MapScanCodeToVirtualKey(key:integer):integer;
 begin
  //result:=MapVirtualKey(key,MAPVK_VSC_TO_VK);
 end;


end.
