//from sdl_stdinc.h

{**
 *  Free memory returned by functions like SDL_GetBasePath(), SDL_GetPrefPath(), etc.
 *}
Procedure SDL_free(mem: Pointer); cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_free' {$ENDIF} {$ENDIF};
