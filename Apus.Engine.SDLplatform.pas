// Windows-specific functions used by Game object
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.SDLplatform;
interface
uses Apus.CrossPlatform, Apus.Engine.API;

type
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
  function MapScanCodeToVirtualKey(key:integer):integer;
  function GetShiftKeysState:cardinal;
  function GetMouseButtons:cardinal;

  procedure ScreenToClient(var p:TPoint);
  procedure ClientToScreen(var p:TPoint);

  procedure OGLSwapBuffers;
 end;

implementation
uses Types, Apus.MyServis, SysUtils, Apus.EventMan, Apus.Engine.Game, sdl2;

var
 window:PSDL_Window;
 terminated:boolean;

{ TSDLPlatform }

function TSDLPlatform.CanChangeSettings: boolean;
 begin
  result:=true;
 end;

procedure TSDLPlatform.ClientToScreen;
 begin
 end;

procedure TSDLPlatform.DestroyWindow;
 begin
  SDL_DestroyWindow(window);
 end;

procedure TSDLPlatform.FlashWindow(count: integer);
 begin
 end;

procedure TSDLPlatform.ScreenToClient;
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
  if SDL_GetDisplayDPI(0,@ddpi,nil,nil)<>0 then
   raise EWarning.Create('SDL: DPI query failed: '+SDL_GetError);
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
 begin
  result:=0;
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
  name:PChar;
 begin
  {case cursorID of
   crDefault:name:=IDC_ARROW;
   crLink:name:=IDC_HAND;
   crWait:name:=IDC_WAIT;
   crInput:name:=IDC_IBEAM;
   crHelp:name:=IDC_HELP;
   crResizeH:name:=IDC_SIZENS;
   crResizeW:name:=IDC_SIZEWE;
   crResizeHW:name:=IDC_SIZEALL;
   crCross:name:=IDC_CROSS;
  end;
  result:=LoadCursor(0,name); }
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

procedure TSDLPlatform.CreateWindow;
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

procedure TSDLPlatform.ProcessSystemMessages;
 var
  event:TSDL_Event;
 begin
  while SDL_PollEvent(@event)<>0 do begin
   if game=nil then continue;
   case event.type_ of
    SDL_MOUSEMOTION:begin

    end;
    SDL_MOUSEBUTTONDOWN:begin
     if not game.GetSettings.showSystemCursor then SetCursor(0);

     //if message=wm_LButtonDown then game.MouseButtonPressed(1,true) else
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

procedure TSDLPlatform.MoveWindowTo(x, y, width, height: integer);
 begin
  if (width>0) and (height>0) then
   SDL_SetWindowSize(window,width,height);
  SDL_SetWindowPosition(window,x,y);
 end;

procedure TSDLPlatform.OGLSwapBuffers;
 begin
  SDL_GL_SwapWindow(window);
 end;

procedure TSDLPlatform.SetupWindow(params:TGameSettings);
 var
  w,h,screenWidth,screenHeight,clientWidth,clientHeight:integer;
 begin
   LogMessage('Configure main window');

   //style:=ws_popup;
   //if params.mode.displayMode=dmWindow then inc(style,WS_SIZEBOX+WS_MAXIMIZEBOX);
   //if params.mode.displayMode in [dmWindow,dmFixedWindow] then
   // inc(style,ws_Caption+WS_MINIMIZEBOX+WS_SYSMENU);

   //SystemParametersInfo(SPI_GETWORKAREA,0,@r2,0);
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
