{*
 *  \file SDL_filesystem.h
 *
 *  \brief Include file for filesystem SDL API functions
  }

{*
 * Get the directory where the application was run from.
 *
 * This is not necessarily a fast call, so you should call this once near
 * startup and save the string if you need it.
 *
 * **Mac OS X and iOS Specific Functionality**: If the application is in a
 * ".app" bundle, this function returns the Resource directory (e.g.
 * MyApp.app/Contents/Resources/). This behaviour can be overridden by adding
 * a property to the Info.plist file. Adding a string key with the name
 * SDL_FILESYSTEM_BASE_DIR_TYPE with a supported value will change the
 * behaviour.
 *
 * Supported values for the SDL_FILESYSTEM_BASE_DIR_TYPE property (Given an
 * application in /Applications/SDLApp/MyApp.app):
 *
 * - `resource`: bundle resource directory (the default). For example:
 *   `/Applications/SDLApp/MyApp.app/Contents/Resources`
 * - `bundle`: the Bundle directory. For example:
 *   `/Applications/SDLApp/MyApp.app/`
 * - `parent`: the containing directory of the bundle. For example:
 *   `/Applications/SDLApp/`
 *
 * The returned path is guaranteed to end with a path separator ('\' on
 * Windows, '/' on most other platforms).
 *
 * The pointer returned is owned by the caller. Please call SDL_free() on the
 * pointer when done with it.
 *
 * \returns an absolute path in UTF-8 encoding to the application data
 *          directory. nil will be returned on error or when the platform
 *          doesn't implement this functionality, call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.1.
 *
 * \sa SDL_GetPrefPath
  }
function SDL_GetBasePath(): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetBasePath' {$ENDIF} {$ENDIF};

{*
 * Get the user-and-app-specific path where files can be written.
 *
 * Get the "pref dir". This is meant to be where users can write personal
 * files (preferences and save games, etc) that are specific to your
 * application. This directory is unique per user, per application.
 *
 * This function will decide the appropriate location in the native
 * filesystem, create the directory if necessary, and return a string of the
 * absolute path to the directory in UTF-8 encoding.
 *
 * On Windows, the string might look like:
 *
 * `C:\\Users\\bob\\AppData\\Roaming\\My Company\\My Program Name\\`
 *
 * On Linux, the string might look like:
 *
 * `/home/bob/.local/share/My Program Name/`
 *
 * On Mac OS X, the string might look like:
 *
 * `/Users/bob/Library/Application Support/My Program Name/`
 *
 * You should assume the path returned by this function is the only safe place
 * to write files (and that SDL_GetBasePath(), while it might be writable, or
 * even the parent of the returned path, isn't where you should be writing
 * things).
 *
 * Both the org and app strings may become part of a directory name, so please
 * follow these rules:
 *
 * - Try to use the same org string (_including case-sensitivity_) for all
 *   your applications that use this function.
 * - Always use a unique app string for each one, and make sure it never
 *   changes for an app once you've decided on it.
 * - Unicode characters are legal, as long as it's UTF-8 encoded, but...
 * - ...only use letters, numbers, and spaces. Avoid punctuation like "Game
 *   Name 2: Bad Guy's Revenge!" ... "Game Name 2" is sufficient.
 *
 * The returned path is guaranteed to end with a path separator ('\' on
 * Windows, '/' on most other platforms).
 *
 * The pointer returned is owned by the caller. Please call SDL_free() on the
 * pointer when done with it.
 *
 * \param org the name of your organization
 * \param app the name of your application
 * \returns a UTF-8 string of the user directory in platform-dependent
 *          notation. nil if there's a problem (creating directory failed,
 *          etc.).
 *
 * \since This function is available since SDL 2.0.1.
 *
 * \sa SDL_GetBasePath
  }
function SDL_GetPrefPath(org: PAnsiChar; app: PAnsiChar): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetPrefPath' {$ENDIF} {$ENDIF};

