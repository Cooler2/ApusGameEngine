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
  function LoadCursor(filename:string):THandle;
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
uses Types, Apus.MyServis, SysUtils, Apus.EventMan, Apus.Engine.Game, sdl2;

var
 window:PSDL_Window;
 context:TSDL_GLContext;
 terminated:boolean;

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
{  if GetAsyncKeyState(VK_SHIFT)<0 then inc(result,sscShift);
  if GetAsyncKeyState(VK_CONTROL)<0 then inc(result,sscCtrl);
  if GetAsyncKeyState(VK_MENU)<0 then inc(result,sscAlt);
  if (GetAsyncKeyState(VK_LWIN)<0) or
     (GetAsyncKeyState(VK_RWIN)<0) then inc(result,sscWin);}
 end;

function TSDLPlatform.GetMouseButtons: cardinal;
 begin
  result:=0;
{  if GetAsyncKeyState(VK_LBUTTON)<0 then inc(result,mbLeft);
  if GetAsyncKeyState(VK_RBUTTON)<0 then inc(result,mbRight);
  if GetAsyncKeyState(VK_MBUTTON)<0 then inc(result,mbMiddle);}
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

function TSDLPlatform.LoadCursor(filename:string):THandle;
 begin

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

constructor TSDLPlatform.Create;
 var
  plName:AnsiString;
  ver:TSDL_Version;
 begin
  if SDL_Init(SDL_INIT_VIDEO+SDL_INIT_EVENTS)<>0 then
   raise EError.Create('SDL init error: '+SDL_GetError);
  plName:=SDL_GetPlatform;
  SDL_GetVersion(@ver);
  LogMessage('SDL Initialized. Platform: %s, version %d.%d',[plName,ver.major,ver.minor]);
 end;

procedure TSDLPlatform.CreateWindow(title: string);
 var
  ust:UTF8String;
 begin
   LogMessage('CreateMainWindow');
   ust:=title;
   window:=SDL_CreateWindow(PAnsiChar(ust),SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,100,100,
    SDL_WINDOW_OPENGL+SDL_WINDOW_HIDDEN+SDL_WINDOW_ALLOW_HIGHDPI);
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
 begin
  result:=sdl_keycode;
  case sdl_keycode of
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
  end;
 end;

procedure TSDLPlatform.ProcessSystemMessages;
 var
  event:TSDL_Event;
  ust:String8;
  wst:String16;
  i,len:integer;
 begin
  while SDL_PollEvent(@event)<>0 do begin
   if game=nil then continue;
   case event.type_ of
    SDL_WINDOWEVENT:begin
     case event.window.event of
      SDL_WINDOWEVENT_FOCUS_GAINED:Signal('ENGINE\SETACTIVE',1);
      SDL_WINDOWEVENT_FOCUS_LOST:Signal('ENGINE\SETACTIVE',0);
      SDL_WINDOWEVENT_SIZE_CHANGED:Signal('ENGINE\RESIZE',PackWords(event.window.data1,event.window.data2));
     end;
    end;

    SDL_MOUSEMOTION:Signal('MOUSE\CLIENTMOVE',PackWords(event.motion.x,event.motion.y));

    SDL_MOUSEBUTTONDOWN:begin
     if not game.GetSettings.showSystemCursor then SetCursor(0);
     Signal('MOUSE\BTNDOWN',GetMouseButtonNum(event.button.button));
    end;

    SDL_MOUSEBUTTONUP:begin
     if not game.GetSettings.showSystemCursor then SetCursor(0);
     Signal('MOUSE\BTNUP',GetMouseButtonNum(event.button.button));
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
      SDL_SetWindowSize(window,w,h);
      SDL_GetWindowSize(window,@w,@h);
      MoveWindowTo((screenWidth-w) div 2,(screenHeight-h) div 2, -1,-1);
      if params.mode.displayMode=dmWindow then
        SDL_SetWindowResizable(window,SDL_TRUE)
      else
        SDL_SetWindowResizable(window,SDL_FALSE);
    end;
    dmFullScreen:begin
      SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN_DESKTOP);
    end;
    dmSwitchResolution:begin
      SDL_SetWindowFullscreen(window,SDL_WINDOW_FULLSCREEN);
    end;
   end;

   SDL_ShowWindow(window);

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
