// based on "sdl_platform.h" (2.0.14)

{**
 *  \file SDL_platform.h
 *
 *  Try to get a standard set of platform defines.
 *}

{**
 *  Gets the name of the platform.
 *}
function SDL_GetPlatform: PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetPlatform' {$ENDIF} {$ENDIF};
