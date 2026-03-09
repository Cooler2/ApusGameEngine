//from sdl_loadso.h

{*
 *  \file SDL_loadso.h
 *
 *  System dependent library loading routines
 *
 *  Some things to keep in mind:
 *  \li These functions only work on C function names.  Other languages may
 *      have name mangling and intrinsic language support that varies from
 *      compiler to compiler.
 *  \li Make sure you declare your function pointers with the same calling
 *      convention as the actual library function.  Your code will crash
 *      mysteriously if you do not do this.
 *  \li Avoid namespace collisions.  If you load a symbol from the library,
 *      it is not defined whether or not it goes into the global symbol
 *      namespace for the application.  If it does and it conflicts with
 *      symbols in your code or other shared libraries, you will not get
 *      the results you expect.:)
  }

{*
 * Dynamically load a shared object.
 *
 * \param sofile a system-dependent name of the object file
 * \returns an opaque pointer to the object handle or nil if there was an
 *          error; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_LoadFunction
 * \sa SDL_UnloadObject
  }
function SDL_LoadObject(sofile: PAnsiChar): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LoadObject' {$ENDIF} {$ENDIF};

{*
 * Look up the address of the named function in a shared object.
 *
 * This function pointer is no longer valid after calling SDL_UnloadObject().
 *
 * This function can only look up C function names. Other languages may have
 * name mangling and intrinsic language support that varies from compiler to
 * compiler.
 *
 * Make sure you declare your function pointers with the same calling
 * convention as the actual library function. Your code will crash
 * mysteriously if you do not do this.
 *
 * If the requested function doesn't exist, nil is returned.
 *
 * \param handle a valid shared object handle returned by SDL_LoadObject()
 * \param name the name of the function to look up
 * \returns a pointer to the function or nil if there was an error; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_LoadObject
 * \sa SDL_UnloadObject
  }
function SDL_LoadFunction(handle: Pointer; name: PAnsiChar): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LoadFunction' {$ENDIF} {$ENDIF};

{*
 * Unload a shared object from memory.
 *
 * \param handle a valid shared object handle returned by SDL_LoadObject()
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_LoadFunction
 * \sa SDL_LoadObject
  }
procedure SDL_UnloadObject(handle: Pointer); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UnloadObject' {$ENDIF} {$ENDIF};
