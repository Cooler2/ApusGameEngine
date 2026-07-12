// iOS bootstrap for the Apus Game Engine.
//
// This is the narrow native<->engine boundary on iOS. iOS launches a Mach-O
// executable through main() (app/main.c), which calls the exported ApusIOSMain
// below. The engine and all Pascal units are linked in as a static archive
// whose Mach-O constructor runs their initialization before main() (see
// README "FPC static archive specifics"), so by the time ApusMain runs the
// engine is fully initialized.
//
// The engine drives frames from the 'Engine\onFrame' signal when
// useMainThread=false (forced on iOS in TGame.Create). UIKit owns the main
// run loop, so instead of a blocking loop we register a display-link callback
// (SDL_iPhoneSetAnimationCallback) that signals one engine frame per refresh.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

library shell;

uses
  // cthreads must come first on UNIX (iOS included): it installs the pthread
  // thread manager the engine relies on (Thread.Register, threadvars, spinlocks).
  {$IFDEF UNIX}cthreads,{$ENDIF}
  ctypes,
  sdl2,
  Apus.EventMan,
  Apus.Engine.API,
  TouchDemoApp;

var
  frameWindow:PSDL_Window;

// Display-link callback: UIKit calls this once per screen refresh, on the main
// thread. One signal renders exactly one engine frame - FrameLoop pumps SDL
// events (touch->mouse), samples input, renders and presents.
procedure ApusFrame(param:Pointer); cdecl;
begin
  Signal('Engine\onFrame');
end;

// SDL "main", invoked by SDL_UIKitRunApp on the main thread once UIKit is up.
// game.Run returns immediately (useMainThread=false on iOS), having created and
// shown the window; we then hand frame driving to the display-link callback and
// return so UIKit's run loop can take over.
function ApusMain(argc:cint; argv:PPAnsiChar):cint; cdecl;
begin
  application:=TTouchDemoApp.Create;
  application.Prepare;
  application.Run;
  if Apus.Engine.API.window<>nil then
    frameWindow:=SDL_GetWindowFromID(cuint32(Apus.Engine.API.window.GetHandle));
  if frameWindow=nil then exit(1);
  SDL_iPhoneSetAnimationCallback(frameWindow,1,@ApusFrame,nil);
  result:=0;
end;

// Native entry adapter (called from app/main.c). Hands control to SDL's UIKit
// application runner, which sets up the UIApplication and calls ApusMain.
function ApusIOSMain(argc:cint; argv:PPAnsiChar):cint; cdecl;
begin
  result:=SDL_UIKitRunApp(argc,argv,@ApusMain);
end;

exports
  ApusIOSMain name '_ApusIOSMain';

begin
end.
