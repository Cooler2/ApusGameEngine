unit sdl2_ttf;

{*
  SDL_ttf:  A companion library to SDL for working with TrueType (tm) fonts
  Copyright (C) 2001-2013 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgement in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*}

{*
 *  \file SDL_ttf.h
 *
 *  Header file for SDL_ttf library
 *
 *  This library is a wrapper around the excellent FreeType 2.0 library,
 *  available at: https://www.freetype.org/
 *
 *  Note: In many places, SDL_ttf will say "glyph" when it means "code point."
 *  Unicode is hard, we learn as we go, and we apologize for adding to the
 *  confusion.
 *
  }

interface

{$I jedi.inc}

uses
  {$IFDEF FPC}
  ctypes,
  {$ENDIF}
  SDL2;

{$I ctypes.inc}

const
  {$IFDEF WINDOWS}
    TTF_LibName = 'SDL2_ttf.dll';
  {$ENDIF}

  {$IFDEF UNIX}
    {$IFDEF DARWIN}
      TTF_LibName = 'libSDL2_tff.dylib';
    {$ELSE}
      {$IFDEF FPC}
        TTF_LibName = 'libSDL2_ttf.so';
      {$ELSE}
        TTF_LibName = 'libSDL2_ttf.so.0';
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF MACOS}
    TTF_LibName = 'SDL2_ttf';
    {$IFDEF FPC}
      {$linklib libSDL2_ttf}
    {$ENDIF}
  {$ENDIF}

{* Printable format: "%d.%d.%d", MAJOR, MINOR, PATCHLEVEL *}
const
  SDL_TTF_MAJOR_VERSION = 2;
  SDL_TTF_MINOR_VERSION = 24;
  SDL_TTF_PATCHLEVEL    = 0;

procedure SDL_TTF_VERSION(Out X: TSDL_Version);

{* Backwards compatibility *}
const
  TTF_MAJOR_VERSION = SDL_TTF_MAJOR_VERSION;
  TTF_MINOR_VERSION = SDL_TTF_MINOR_VERSION;
  TTF_PATCHLEVEL    = SDL_TTF_PATCHLEVEL;
procedure TTF_VERSION(Out X: TSDL_Version);

{**
 *  This is the version number macro for the current SDL_ttf version.
 *
 *  In versions higher than 2.9.0, the minor version overflows into
 *  the thousands digit: for example, 2.23.0 is encoded as 4300.
 *  This macro will not be available in SDL 3.x or SDL_ttf 3.x.
 *
 *  \deprecated, use SDL_TTF_VERSION_ATLEAST or SDL_TTF_VERSION instead.
 *}
 { SDL2-for-Pascal: This conditional and deprecated macro is not translated.
                    It could be done easily but nobody ever asked for it and
                    it is probably for little use. }
// function SDL_TTF_COMPILEDVERSION: Integer;

{**
 *  This macro will evaluate to true if compiled with SDL_ttf at least X.Y.Z.
 *}
function SDL_TTF_VERSION_ATLEAST(X, Y, Z: Integer): Boolean;

{*
 * Query the version of SDL_ttf that the program is linked against.
 *
 * This function gets the version of the dynamically linked SDL_ttf library.
 * This is separate from the SDL_TTF_VERSION() macro, which tells you what
 * version of the SDL_ttf headers you compiled against.
 *
 * This returns static internal data; do not free or modify it!
 *
 * \returns a pointer to the version information.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
(* Const before type ignored *)
function TTF_Linked_Version: PSDL_version; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_Linked_Version' {$ENDIF} {$ENDIF};

{*
 * Query the version of the FreeType library in use.
 *
 * TTF_Init() should be called before calling this function.
 *
 * \param major to be filled in with the major version number. Can be nil.
 * \param minor to be filled in with the minor version number. Can be nil.
 * \param patch to be filled in with the param version number. Can be nil.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_Init
  }
procedure TTF_GetFreeTypeVersion(major: pcint; minor: pcint; patch: pcint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFreeTypeVersion' {$ENDIF} {$ENDIF};

{*
 * Query the version of the HarfBuzz library in use.
 *
 * If HarfBuzz is not available, the version reported is 0.0.0.
 *
 * \param major to be filled in with the major version number. Can be nil.
 * \param minor to be filled in with the minor version number. Can be nil.
 * \param patch to be filled in with the param version number. Can be nil.
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
procedure TTF_GetHarfBuzzVersion(major: pcint; minor: pcint; patch: pcint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetHarfBuzzVersion' {$ENDIF} {$ENDIF};

{*
 * ZERO WIDTH NO-BREAKSPACE (Unicode byte order mark)
  }
const
  UNICODE_BOM_NATIVE  = $FEFF;
  UNICODE_BOM_SWAPPED = $FFFE;

{*
 * Tell SDL_ttf whether UNICODE text is generally byteswapped.
 *
 * A UNICODE BOM character in a string will override this setting for the
 * remainder of that string.
 *
 * \param swapped boolean to indicate whether text is byteswapped
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
procedure TTF_ByteSwappedUNICODE(swapped: TSDL_bool); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_ByteSwappedUNICODE' {$ENDIF} {$ENDIF};

{* The internal structure containing font information *}
type
  PPTTF_Font = ^PTTF_Font;
  PTTF_Font = type Pointer;

{*
 * Initialize SDL_ttf.
 *
 * You must successfully call this function before it is safe to call any
 * other function in this library, with one exception: a human-readable error
 * message can be retrieved from TTF_GetError() if this function fails.
 *
 * SDL must be initialized before calls to functions in this library, because
 * this library uses utility functions from the SDL library.
 *
 * It is safe to call this more than once; the library keeps a counter of init
 * calls, and decrements it on each call to TTF_Quit, so you must pair your
 * init and quit calls.
 *
 * \returns 0 on success, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_Quit
 * \sa TTF_WasInit
  }
function TTF_Init(): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_Init' {$ENDIF} {$ENDIF};

{*
 * Create a font from a file, using a specified point size.
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param file path to font file.
 * \param ptsize point size to use for the newly-opened font.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFont(file_: PAnsiChar; ptsize: cint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFont' {$ENDIF} {$ENDIF};

{*
 * Create a font from a file, using a specified face index.
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * Some fonts have multiple "faces" included. The index specifies which face
 * to use from the font file. Font files with only one face should specify
 * zero for the index.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param file path to font file.
 * \param ptsize point size to use for the newly-opened font.
 * \param index index of the face in the font file.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontIndex(file_: PAnsiChar; ptsize: cint; index: clong): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontIndex' {$ENDIF} {$ENDIF};

{*
 * Create a font from an SDL_RWops, using a specified point size.
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * If `freesrc` is non-zero, the RWops will be automatically closed once the
 * font is closed. Otherwise you should close the RWops yourself after closing
 * the font.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param src an SDL_RWops to provide a font file's data.
 * \param freesrc non-zero to close the RWops when the font is closed, zero to
 *                leave it open.
 * \param ptsize point size to use for the newly-opened font.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontRW(src: PSDL_RWops; freesrc: cint; ptsize: cint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontRW' {$ENDIF} {$ENDIF};

{*
 * Create a font from an SDL_RWops, using a specified face index.
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * If `freesrc` is non-zero, the RWops will be automatically closed once the
 * font is closed. Otherwise you should close the RWops yourself after closing
 * the font.
 *
 * Some fonts have multiple "faces" included. The index specifies which face
 * to use from the font file. Font files with only one face should specify
 * zero for the index.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param src an SDL_RWops to provide a font file's data.
 * \param freesrc non-zero to close the RWops when the font is closed, zero to
 *                leave it open.
 * \param ptsize point size to use for the newly-opened font.
 * \param index index of the face in the font file.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontIndexRW(src: PSDL_RWops; freesrc: cint; ptsize: cint; index: clong): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontIndexRW' {$ENDIF} {$ENDIF};

{*
 * Create a font from a file, using target resolutions (in DPI).
 *
 * DPI scaling only applies to scalable fonts (e.g. TrueType).
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param file path to font file.
 * \param ptsize point size to use for the newly-opened font.
 * \param hdpi the target horizontal DPI.
 * \param vdpi the target vertical DPI.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontDPI(file_: PAnsiChar; ptsize: cint; hdpi: cuint; vdpi: cuint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontDPI' {$ENDIF} {$ENDIF};

{*
 * Create a font from a file, using target resolutions (in DPI).
 *
 * DPI scaling only applies to scalable fonts (e.g. TrueType).
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * Some fonts have multiple "faces" included. The index specifies which face
 * to use from the font file. Font files with only one face should specify
 * zero for the index.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param file path to font file.
 * \param ptsize point size to use for the newly-opened font.
 * \param index index of the face in the font file.
 * \param hdpi the target horizontal DPI.
 * \param vdpi the target vertical DPI.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontIndexDPI(file_: PAnsiChar; ptsize: cint; index: clong; hdpi: cuint; vdpi: cuint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontIndexDPI' {$ENDIF} {$ENDIF};

{*
 * Opens a font from an SDL_RWops with target resolutions (in DPI).
 *
 * DPI scaling only applies to scalable fonts (e.g. TrueType).
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * If `freesrc` is non-zero, the RWops will be automatically closed once the
 * font is closed. Otherwise you should close the RWops yourself after closing
 * the font.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param src an SDL_RWops to provide a font file's data.
 * \param freesrc non-zero to close the RWops when the font is closed, zero to
 *                leave it open.
 * \param ptsize point size to use for the newly-opened font.
 * \param hdpi the target horizontal DPI.
 * \param vdpi the target vertical DPI.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontDPIRW(src: PSDL_RWops; freesrc: cint; ptsize: cint; hdpi: cuint; vdpi: cuint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontDPIRW' {$ENDIF} {$ENDIF};

{*
 * Opens a font from an SDL_RWops with target resolutions (in DPI).
 *
 * DPI scaling only applies to scalable fonts (e.g. TrueType).
 *
 * Some .fon fonts will have several sizes embedded in the file, so the point
 * size becomes the index of choosing which size. If the value is too high,
 * the last indexed size will be the default.
 *
 * If `freesrc` is non-zero, the RWops will be automatically closed once the
 * font is closed. Otherwise you should close the RWops yourself after closing
 * the font.
 *
 * Some fonts have multiple "faces" included. The index specifies which face
 * to use from the font file. Font files with only one face should specify
 * zero for the index.
 *
 * When done with the returned TTF_Font, use TTF_CloseFont() to dispose of it.
 *
 * \param src an SDL_RWops to provide a font file's data.
 * \param freesrc non-zero to close the RWops when the font is closed, zero to
 *                leave it open.
 * \param ptsize point size to use for the newly-opened font.
 * \param index index of the face in the font file.
 * \param hdpi the target horizontal DPI.
 * \param vdpi the target vertical DPI.
 * \returns a valid TTF_Font, or nil on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_CloseFont
  }
function TTF_OpenFontIndexDPIRW(src: PSDL_RWops; freesrc: cint; ptsize: cint; index: clong; hdpi: cuint; vdpi: cuint): PTTF_Font; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_OpenFontIndexDPIRW' {$ENDIF} {$ENDIF};

{*
 * Set a font's size dynamically.
 *
 * This clears already-generated glyphs, if any, from the cache.
 *
 * \param font the font to resize.
 * \param ptsize the new point size.
 * \returns 0 if successful, -1 on error
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
function TTF_SetFontSize(font: PTTF_Font; ptsize: cint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontSize' {$ENDIF} {$ENDIF};

{*
 * Set font size dynamically with target resolutions (in DPI).
 *
 * This clears already-generated glyphs, if any, from the cache.
 *
 * \param font the font to resize.
 * \param ptsize the new point size.
 * \param hdpi the target horizontal DPI.
 * \param vdpi the target vertical DPI.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
function TTF_SetFontSizeDPI(font: PTTF_Font; ptsize: cint; hdpi: cuint; vdpi: cuint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontSizeDPI' {$ENDIF} {$ENDIF};

{*
 * Font style flags
  }
const
  TTF_STYLE_NORMAL        = $00;
  TTF_STYLE_BOLD          = $01;
  TTF_STYLE_ITALIC        = $02;
  TTF_STYLE_UNDERLINE     = $04;
  TTF_STYLE_STRIKETHROUGH = $08;

{*
 * Query a font's current style.
 *
 * The font styles are a set of bit flags, OR'd together:
 *
 * - `TTF_STYLE_NORMAL` (is zero)
 * - `TTF_STYLE_BOLD`
 * - `TTF_STYLE_ITALIC`
 * - `TTF_STYLE_UNDERLINE`
 * - `TTF_STYLE_STRIKETHROUGH`
 *
 * \param font the font to query.
 * \returns the current font style, as a set of bit flags.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SetFontStyle
  }
function TTF_GetFontStyle(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontStyle' {$ENDIF} {$ENDIF};

{*
 * Set a font's current style.
 *
 * Setting the style clears already-generated glyphs, if any, from the cache.
 *
 * The font styles are a set of bit flags, OR'd together:
 *
 * - `TTF_STYLE_NORMAL` (is zero)
 * - `TTF_STYLE_BOLD`
 * - `TTF_STYLE_ITALIC`
 * - `TTF_STYLE_UNDERLINE`
 * - `TTF_STYLE_STRIKETHROUGH`
 *
 * \param font the font to set a new style on.
 * \param style the new style values to set, OR'd together.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GetFontStyle
  }
procedure TTF_SetFontStyle(font: PTTF_Font; style: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontStyle' {$ENDIF} {$ENDIF};

{*
 * Query a font's current outline.
 *
 * \param font the font to query.
 * \returns the font's current outline value.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SetFontOutline
  }
function TTF_GetFontOutline(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontOutline' {$ENDIF} {$ENDIF};

{*
 * Set a font's current outline.
 *
 * \param font the font to set a new outline on.
 * \param outline positive outline value, 0 to default.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GetFontOutline
  }
procedure TTF_SetFontOutline(font: PTTF_Font; outline: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontOutline' {$ENDIF} {$ENDIF};

{*
 * Hinting flags
  }
const
  TTF_HINTING_NORMAL         = 0;
  TTF_HINTING_LIGHT          = 1;
  TTF_HINTING_MONO           = 2;
  TTF_HINTING_NONE           = 3;
  TTF_HINTING_LIGHT_SUBPIXEL = 4;

{*
 * Query a font's current FreeType hinter setting.
 *
 * The hinter setting is a single value:
 *
 * - `TTF_HINTING_NORMAL`
 * - `TTF_HINTING_LIGHT`
 * - `TTF_HINTING_MONO`
 * - `TTF_HINTING_NONE`
 * - `TTF_HINTING_LIGHT_SUBPIXEL` (available in SDL_ttf 2.0.18 and later)
 *
 * \param font the font to query.
 * \returns the font's current hinter value.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SetFontHinting
  }
function TTF_GetFontHinting(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontHinting' {$ENDIF} {$ENDIF};

{*
 * Set a font's current hinter setting.
 *
 * Setting it clears already-generated glyphs, if any, from the cache.
 *
 * The hinter setting is a single value:
 *
 * - `TTF_HINTING_NORMAL`
 * - `TTF_HINTING_LIGHT`
 * - `TTF_HINTING_MONO`
 * - `TTF_HINTING_NONE`
 * - `TTF_HINTING_LIGHT_SUBPIXEL` (available in SDL_ttf 2.0.18 and later)
 *
 * \param font the font to set a new hinter setting on.
 * \param hinting the new hinter setting.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GetFontHinting
  }
procedure TTF_SetFontHinting(font: PTTF_Font; hinting: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontHinting' {$ENDIF} {$ENDIF};

{*
 * Special layout option for rendering wrapped text
  }
const
  TTF_WRAPPED_ALIGN_LEFT   = 0;
  TTF_WRAPPED_ALIGN_CENTER = 1;
  TTF_WRAPPED_ALIGN_RIGHT  = 2;

{*
 * Query a font's current wrap alignment option.
 *
 * The wrap alignment option can be one of the following:
 *
 * - `TTF_WRAPPED_ALIGN_LEFT`
 * - `TTF_WRAPPED_ALIGN_CENTER`
 * - `TTF_WRAPPED_ALIGN_RIGHT`
 *
 * \param font the font to query.
 * \returns the font's current wrap alignment option.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_SetFontWrappedAlign
  }
function TTF_GetFontWrappedAlign(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontWrappedAlign' {$ENDIF} {$ENDIF};

{*
 * Set a font's current wrap alignment option.
 *
 * The wrap alignment option can be one of the following:
 *
 * - `TTF_WRAPPED_ALIGN_LEFT`
 * - `TTF_WRAPPED_ALIGN_CENTER`
 * - `TTF_WRAPPED_ALIGN_RIGHT`
 *
 * \param font the font to set a new wrap alignment option on.
 * \param align the new wrap alignment option.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_GetFontWrappedAlign
  }
procedure TTF_SetFontWrappedAlign(font: PTTF_Font; align: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontWrappedAlign' {$ENDIF} {$ENDIF};

{*
 * Query the total height of a font.
 *
 * This is usually equal to point size.
 *
 * \param font the font to query.
 * \returns the font's height.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontHeight(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontHeight' {$ENDIF} {$ENDIF};

{*
 * Query the offset from the baseline to the top of a font.
 *
 * This is a positive value, relative to the baseline.
 *
 * \param font the font to query.
 * \returns the font's ascent.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontAscent(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontAscent' {$ENDIF} {$ENDIF};

{*
 * Query the offset from the baseline to the bottom of a font.
 *
 * This is a negative value, relative to the baseline.
 *
 * \param font the font to query.
 * \returns the font's descent.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontDescent(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontDescent' {$ENDIF} {$ENDIF};

{*
 * Query the spacing between lines of text for a font.
 *
 * \param font the font to query.
 * \returns the font's line spacing.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontLineSkip(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontLineSkip' {$ENDIF} {$ENDIF};

{**
 * Set the spacing between lines of text for a font.
 *
 * \param font the font to modify.
 * \param lineskip the new line spacing for the font.
 *
 * \since This function is available since SDL_ttf 2.22.0.
 *}
procedure TTF_SetFontLineSkip(font: PTTF_Font; lineskip: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontLineSkip' {$ENDIF} {$ENDIF};

{*
 * Query whether or not kerning is allowed for a font.
 *
 * \param font the font to query.
 * \returns non-zero if kerning is enabled, zero otherwise.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_GetFontKerning(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontKerning' {$ENDIF} {$ENDIF};

{*
 * Set if kerning is allowed for a font.
 *
 * Newly-opened fonts default to allowing kerning. This is generally a good
 * policy unless you have a strong reason to disable it, as it tends to
 * produce better rendering (with kerning disabled, some fonts might render
 * the word `kerning` as something that looks like `keming` for example).
 *
 * \param font the font to set kerning on.
 * \param allowed non-zero to allow kerning, zero to disallow.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
procedure TTF_SetFontKerning(font: PTTF_Font; allowed: cint); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontKerning' {$ENDIF} {$ENDIF};

{*
 * Query the number of faces of a font.
 *
 * \param font the font to query.
 * \returns the number of FreeType font faces.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontFaces(font: PTTF_Font): clong; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontFaces' {$ENDIF} {$ENDIF};

{*
 * Query whether a font is fixed-width.
 *
 * A "fixed-width" font means all glyphs are the same width across; a
 * lowercase 'i' will be the same size across as a capital 'W', for example.
 * This is common for terminals and text editors, and other apps that treat
 * text as a grid. Most other things (WYSIWYG word processors, web pages, etc)
 * are more likely to not be fixed-width in most cases.
 *
 * \param font the font to query.
 * \returns non-zero if fixed-width, zero if not.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontFaceIsFixedWidth(font: PTTF_Font): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontFaceIsFixedWidth' {$ENDIF} {$ENDIF};

{*
 * Query a font's family name.
 *
 * This string is dictated by the contents of the font file.
 *
 * Note that the returned string is to internal storage, and should not be
 * modifed or free'd by the caller. The string becomes invalid, with the rest
 * of the font, when `font` is handed to TTF_CloseFont().
 *
 * \param font the font to query.
 * \returns the font's family name.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontFaceFamilyName(font: PTTF_Font): PAnsiChar; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontFaceFamilyName' {$ENDIF} {$ENDIF};

{*
 * Query a font's style name.
 *
 * This string is dictated by the contents of the font file.
 *
 * Note that the returned string is to internal storage, and should not be
 * modifed or free'd by the caller. The string becomes invalid, with the rest
 * of the font, when `font` is handed to TTF_CloseFont().
 *
 * \param font the font to query.
 * \returns the font's style name.
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
function TTF_FontFaceStyleName(font: PTTF_Font): PAnsiChar; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_FontFaceStyleName' {$ENDIF} {$ENDIF};

{*
 * Check whether a glyph is provided by the font for a 16-bit codepoint.
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_GlyphIsProvided32() instead, which offers the same functionality
 * but takes a 32-bit codepoint instead.
 *
 * The only reason to use this function is that it was available since the
 * beginning of time, more or less.
 *
 * \param font the font to query.
 * \param ch the character code to check.
 * \returns non-zero if font provides a glyph for this character, zero if not.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GlyphIsProvided32
  }
function TTF_GlyphIsProvided(font: PTTF_Font; ch: cuint16): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GlyphIsProvided' {$ENDIF} {$ENDIF};

{*
 * Check whether a glyph is provided by the font for a 32-bit codepoint.
 *
 * This is the same as TTF_GlyphIsProvided(), but takes a 32-bit character
 * instead of 16-bit, and thus can query a larger range. If you are sure
 * you'll have an SDL_ttf that's version 2.0.18 or newer, there's no reason
 * not to use this function exclusively.
 *
 * \param font the font to query.
 * \param ch the character code to check.
 * \returns non-zero if font provides a glyph for this character, zero if not.
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
function TTF_GlyphIsProvided32(font: PTTF_Font; ch: cuint32): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GlyphIsProvided32' {$ENDIF} {$ENDIF};

{*
 * Query the metrics (dimensions) of a font's 16-bit glyph.
 *
 * To understand what these metrics mean, here is a useful link:
 *
 * https://freetype.sourceforge.net/freetype2/docs/tutorial/step2.html
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_GlyphMetrics32() instead, which offers the same functionality but
 * takes a 32-bit codepoint instead.
 *
 * The only reason to use this function is that it was available since the
 * beginning of time, more or less.
 *
 * \param font the font to query.
 * \param ch the character code to check.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GlyphMetrics32
  }
function TTF_GlyphMetrics(font: PTTF_Font; ch: cuint16; minx: pcint; maxx: pcint; miny: pcint; maxy: pcint; advance: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GlyphMetrics' {$ENDIF} {$ENDIF};

{*
 * Query the metrics (dimensions) of a font's 32-bit glyph.
 *
 * To understand what these metrics mean, here is a useful link:
 *
 * https://freetype.sourceforge.net/freetype2/docs/tutorial/step2.html
 *
 * This is the same as TTF_GlyphMetrics(), but takes a 32-bit character
 * instead of 16-bit, and thus can query a larger range. If you are sure
 * you'll have an SDL_ttf that's version 2.0.18 or newer, there's no reason
 * not to use this function exclusively.
 *
 * \param font the font to query.
 * \param ch the character code to check.
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
function TTF_GlyphMetrics32(font: PTTF_Font; ch: cuint32; minx: pcint; maxx: pcint; miny: pcint; maxy: pcint; advance: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GlyphMetrics32' {$ENDIF} {$ENDIF};

{*
 * Calculate the dimensions of a rendered string of Latin1 text.
 *
 * This will report the width and height, in pixels, of the space that the
 * specified string will take to fully render.
 *
 * This does not need to render the string to do this calculation.
 *
 * You almost certainly want TTF_SizeUTF8() unless you're sure you have a
 * 1-byte Latin1 encoding. US ASCII characters will work with either function,
 * but most other Unicode characters packed into a `const char *` will need
 * UTF-8.
 *
 * \param font the font to query.
 * \param text text to calculate, in Latin1 encoding.
 * \param w will be filled with width, in pixels, on return.
 * \param h will be filled with height, in pixels, on return.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SizeUTF8
 * \sa TTF_SizeUNICODE
  }
function TTF_SizeText(font: PTTF_Font; text: PAnsiChar; w: pcint; h: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SizeText' {$ENDIF} {$ENDIF};

{*
 * Calculate the dimensions of a rendered string of UTF-8 text.
 *
 * This will report the width and height, in pixels, of the space that the
 * specified string will take to fully render.
 *
 * This does not need to render the string to do this calculation.
 *
 * \param font the font to query.
 * \param text text to calculate, in UTF-8 encoding.
 * \param w will be filled with width, in pixels, on return.
 * \param h will be filled with height, in pixels, on return.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SizeUNICODE
  }
function TTF_SizeUTF8(font: PTTF_Font; text: PAnsiChar; w: pcint; h: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SizeUTF8' {$ENDIF} {$ENDIF};

{*
 * Calculate the dimensions of a rendered string of UCS-2 text.
 *
 * This will report the width and height, in pixels, of the space that the
 * specified string will take to fully render.
 *
 * This does not need to render the string to do this calculation.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * \param font the font to query.
 * \param text text to calculate, in UCS-2 encoding.
 * \param w will be filled with width, in pixels, on return.
 * \param h will be filled with height, in pixels, on return.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_SizeUTF8
  }
function TTF_SizeUNICODE(font: PTTF_Font; text: pcuint16; w: pcint; h: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SizeUNICODE' {$ENDIF} {$ENDIF};

{*
 * Calculate how much of a Latin1 string will fit in a given width.
 *
 * This reports the number of characters that can be rendered before reaching
 * `measure_width`.
 *
 * This does not need to render the string to do this calculation.
 *
 * You almost certainly want TTF_MeasureUTF8() unless you're sure you have a
 * 1-byte Latin1 encoding. US ASCII characters will work with either function,
 * but most other Unicode characters packed into a `const char *` will need
 * UTF-8.
 *
 * \param font the font to query.
 * \param text text to calculate, in Latin1 encoding.
 * \param measure_width maximum width, in pixels, available for the string.
 * \param extent on return, filled with latest calculated width.
 * \param count on return, filled with number of characters that can be
 *              rendered.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_MeasureText
 * \sa TTF_MeasureUTF8
 * \sa TTF_MeasureUNICODE
  }
function TTF_MeasureText(font: PTTF_Font; text: PAnsiChar; measure_width: cint; extent: pcint; count: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_MeasureText' {$ENDIF} {$ENDIF};

{*
 * Calculate how much of a UTF-8 string will fit in a given width.
 *
 * This reports the number of characters that can be rendered before reaching
 * `measure_width`.
 *
 * This does not need to render the string to do this calculation.
 *
 * \param font the font to query.
 * \param text text to calculate, in UTF-8 encoding.
 * \param measure_width maximum width, in pixels, available for the string.
 * \param extent on return, filled with latest calculated width.
 * \param count on return, filled with number of characters that can be
 *              rendered.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_MeasureText
 * \sa TTF_MeasureUTF8
 * \sa TTF_MeasureUNICODE
  }
function TTF_MeasureUTF8(font: PTTF_Font; text: PAnsiChar; measure_width: cint; extent: pcint; count: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_MeasureUTF8' {$ENDIF} {$ENDIF};

{*
 * Calculate how much of a UCS-2 string will fit in a given width.
 *
 * This reports the number of characters that can be rendered before reaching
 * `measure_width`.
 *
 * This does not need to render the string to do this calculation.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * \param font the font to query.
 * \param text text to calculate, in UCS-2 encoding.
 * \param measure_width maximum width, in pixels, available for the string.
 * \param extent on return, filled with latest calculated width.
 * \param count on return, filled with number of characters that can be
 *              rendered.
 * \returns 0 if successful, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_MeasureText
 * \sa TTF_MeasureUTF8
 * \sa TTF_MeasureUNICODE
  }
function TTF_MeasureUNICODE(font: PTTF_Font; text: pcuint16; measure_width: cint; extent: pcint; count: pcint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_MeasureUNICODE' {$ENDIF} {$ENDIF};

{*
 * Render Latin1 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderText_Solid_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Solid() unless you're sure you
 * have a 1-byte Latin1 encoding. US ASCII characters will work with either
 * function, but most other Unicode characters packed into a `const char *`
 * will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Shaded,
 * TTF_RenderText_Blended, and TTF_RenderText_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Solid
 * \sa TTF_RenderUNICODE_Solid
  }
function TTF_RenderText_Solid(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Solid' {$ENDIF} {$ENDIF};

{*
 * Render UTF-8 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUTF8_Solid_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Shaded,
 * TTF_RenderUTF8_Blended, and TTF_RenderUTF8_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Shaded
 * \sa TTF_RenderUTF8_Blended
 * \sa TTF_RenderUTF8_LCD
  }
function TTF_RenderUTF8_Solid(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Solid' {$ENDIF} {$ENDIF};

{*
 * Render UCS-2 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUNICODE_Solid_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with TTF_RenderUNICODE_Shaded,
 * TTF_RenderUNICODE_Blended, and TTF_RenderUNICODE_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Solid
  }
function TTF_RenderUNICODE_Solid(font: PTTF_Font; text: pcuint16; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Solid' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped Latin1 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Solid_Wrapped() unless you're sure
 * you have a 1-byte Latin1 encoding. US ASCII characters will work with
 * either function, but most other Unicode characters packed into a `const
 * char *` will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Shaded_Wrapped,
 * TTF_RenderText_Blended_Wrapped, and TTF_RenderText_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Solid_Wrapped
 * \sa TTF_RenderUNICODE_Solid_Wrapped
  }
function TTF_RenderText_Solid_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Solid_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UTF-8 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Shaded_Wrapped,
 * TTF_RenderUTF8_Blended_Wrapped, and TTF_RenderUTF8_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Shaded_Wrapped
 * \sa TTF_RenderUTF8_Blended_Wrapped
 * \sa TTF_RenderUTF8_LCD_Wrapped
  }
function TTF_RenderUTF8_Solid_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Solid_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UCS-2 text at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with
 * TTF_RenderUNICODE_Shaded_Wrapped, TTF_RenderUNICODE_Blended_Wrapped, and
 * TTF_RenderUNICODE_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Solid_Wrapped
  }
function TTF_RenderUNICODE_Solid_Wrapped(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Solid_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render a single 16-bit glyph at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_RenderGlyph32_Solid() instead, which offers the same functionality
 * but takes a 32-bit codepoint instead.
 *
 * The only reason to use this function is that it was available since the
 * beginning of time, more or less.
 *
 * You can render at other quality levels with TTF_RenderGlyph_Shaded,
 * TTF_RenderGlyph_Blended, and TTF_RenderGlyph_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderGlyph32_Solid
  }
function TTF_RenderGlyph_Solid(font: PTTF_Font; ch: cuint16; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph_Solid' {$ENDIF} {$ENDIF};

{*
 * Render a single 32-bit glyph at fast quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
 * will be set to the text color.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * This is the same as TTF_RenderGlyph_Solid(), but takes a 32-bit character
 * instead of 16-bit, and thus can render a larger range. If you are sure
 * you'll have an SDL_ttf that's version 2.0.18 or newer, there's no reason
 * not to use this function exclusively.
 *
 * You can render at other quality levels with TTF_RenderGlyph32_Shaded,
 * TTF_RenderGlyph32_Blended, and TTF_RenderGlyph32_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderGlyph32_Shaded
 * \sa TTF_RenderGlyph32_Blended
 * \sa TTF_RenderGlyph32_LCD
  }
function TTF_RenderGlyph32_Solid(font: PTTF_Font; ch: cuint32; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph32_Solid' {$ENDIF} {$ENDIF};

{*
 * Render Latin1 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderText_Shaded_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Shaded() unless you're sure you
 * have a 1-byte Latin1 encoding. US ASCII characters will work with either
 * function, but most other Unicode characters packed into a `const char *`
 * will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid,
 * TTF_RenderText_Blended, and TTF_RenderText_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Shaded
 * \sa TTF_RenderUNICODE_Shaded
  }
function TTF_RenderText_Shaded(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Shaded' {$ENDIF} {$ENDIF};

{*
 * Render UTF-8 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUTF8_Shaded_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid,
 * TTF_RenderUTF8_Blended, and TTF_RenderUTF8_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUNICODE_Shaded
  }
function TTF_RenderUTF8_Shaded(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Shaded' {$ENDIF} {$ENDIF};

{*
 * Render UCS-2 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUNICODE_Shaded_Wrapped() instead if you need to wrap the output
 * to multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with TTF_RenderUNICODE_Solid,
 * TTF_RenderUNICODE_Blended, and TTF_RenderUNICODE_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Shaded
  }
function TTF_RenderUNICODE_Shaded(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Shaded' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped Latin1 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Shaded_Wrapped() unless you're
 * sure you have a 1-byte Latin1 encoding. US ASCII characters will work with
 * either function, but most other Unicode characters packed into a `const
 * char *` will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid_Wrapped,
 * TTF_RenderText_Blended_Wrapped, and TTF_RenderText_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Shaded_Wrapped
 * \sa TTF_RenderUNICODE_Shaded_Wrapped
  }
function TTF_RenderText_Shaded_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Shaded_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UTF-8 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid_Wrapped,
 * TTF_RenderUTF8_Blended_Wrapped, and TTF_RenderUTF8_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Solid_Wrapped
 * \sa TTF_RenderUTF8_Blended_Wrapped
 * \sa TTF_RenderUTF8_LCD_Wrapped
  }
function TTF_RenderUTF8_Shaded_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Shaded_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UCS-2 text at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with
 * TTF_RenderUNICODE_Solid_Wrapped, TTF_RenderUNICODE_Blended_Wrapped, and
 * TTF_RenderUNICODE_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Shaded_Wrapped
  }
function TTF_RenderUNICODE_Shaded_Wrapped(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Shaded_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render a single 16-bit glyph at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_RenderGlyph32_Shaded() instead, which offers the same functionality
 * but takes a 32-bit codepoint instead.
 *
 * The only reason to use this function is that it was available since the
 * beginning of time, more or less.
 *
 * You can render at other quality levels with TTF_RenderGlyph_Solid,
 * TTF_RenderGlyph_Blended, and TTF_RenderGlyph_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderGlyph32_Shaded
  }
function TTF_RenderGlyph_Shaded(font: PTTF_Font; ch: cuint16; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph_Shaded' {$ENDIF} {$ENDIF};

{*
 * Render a single 32-bit glyph at high quality to a new 8-bit surface.
 *
 * This function will allocate a new 8-bit, palettized surface. The surface's
 * 0 pixel will be the specified background color, while other pixels have
 * varying degrees of the foreground color. This function returns the new
 * surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * This is the same as TTF_RenderGlyph_Shaded(), but takes a 32-bit character
 * instead of 16-bit, and thus can render a larger range. If you are sure
 * you'll have an SDL_ttf that's version 2.0.18 or newer, there's no reason
 * not to use this function exclusively.
 *
 * You can render at other quality levels with TTF_RenderGlyph32_Solid,
 * TTF_RenderGlyph32_Blended, and TTF_RenderGlyph32_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 8-bit, palettized surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderGlyph32_Solid
 * \sa TTF_RenderGlyph32_Blended
 * \sa TTF_RenderGlyph32_LCD
  }
function TTF_RenderGlyph32_Shaded(font: PTTF_Font; ch: cuint32; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph32_Shaded' {$ENDIF} {$ENDIF};

{*
 * Render Latin1 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderText_Blended_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Blended() unless you're sure you
 * have a 1-byte Latin1 encoding. US ASCII characters will work with either
 * function, but most other Unicode characters packed into a `const char *`
 * will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid,
 * TTF_RenderText_Blended, and TTF_RenderText_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Shaded
 * \sa TTF_RenderUNICODE_Shaded
  }
function TTF_RenderText_Blended(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Blended' {$ENDIF} {$ENDIF};

{*
 * Render UTF-8 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUTF8_Blended_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid,
 * TTF_RenderUTF8_Shaded, and TTF_RenderUTF8_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUNICODE_Blended
  }
function TTF_RenderUTF8_Blended(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Blended' {$ENDIF} {$ENDIF};

{*
 * Render UCS-2 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUNICODE_Blended_Wrapped() instead if you need to wrap the output
 * to multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with TTF_RenderUNICODE_Solid,
 * TTF_RenderUNICODE_Shaded, and TTF_RenderUNICODE_LCD.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderUTF8_Blended
  }
function TTF_RenderUNICODE_Blended(font: PTTF_Font; text: pcuint16; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Blended' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped Latin1 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_Blended_Wrapped() unless you're
 * sure you have a 1-byte Latin1 encoding. US ASCII characters will work with
 * either function, but most other Unicode characters packed into a `const
 * char *` will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid_Wrapped,
 * TTF_RenderText_Shaded_Wrapped, and TTF_RenderText_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \param wrapLength the text is wrapped to multiple lines on line endings and
 *                   on word boundaries if it extends beyond this value in
 *                   pixels.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Blended_Wrapped
 * \sa TTF_RenderUNICODE_Blended_Wrapped
  }
function TTF_RenderText_Blended_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_Blended_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UTF-8 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid_Wrapped,
 * TTF_RenderUTF8_Shaded_Wrapped, and TTF_RenderUTF8_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \param wrapLength the text is wrapped to multiple lines on line endings and
 *                   on word boundaries if it extends beyond this value in
 *                   pixels.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Solid_Wrapped
 * \sa TTF_RenderUTF8_Shaded_Wrapped
 * \sa TTF_RenderUTF8_LCD_Wrapped
  }
function TTF_RenderUTF8_Blended_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_Blended_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UCS-2 text at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with
 * TTF_RenderUNICODE_Solid_Wrapped, TTF_RenderUNICODE_Shaded_Wrapped, and
 * TTF_RenderUNICODE_LCD_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \param wrapLength the text is wrapped to multiple lines on line endings and
 *                   on word boundaries if it extends beyond this value in
 *                   pixels.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderUTF8_Blended_Wrapped
  }
function TTF_RenderUNICODE_Blended_Wrapped(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_Blended_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render a single 16-bit glyph at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_RenderGlyph32_Blended() instead, which offers the same
 * functionality but takes a 32-bit codepoint instead.
 *
 * The only reason to use this function is that it was available since the
 * beginning of time, more or less.
 *
 * You can render at other quality levels with TTF_RenderGlyph_Solid,
 * TTF_RenderGlyph_Shaded, and TTF_RenderGlyph_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_RenderGlyph32_Blended
  }
function TTF_RenderGlyph_Blended(font: PTTF_Font; ch: cuint16; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph_Blended' {$ENDIF} {$ENDIF};

{*
 * Render a single 32-bit glyph at high quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, using alpha
 * blending to dither the font with the given color. This function returns the
 * new surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * This is the same as TTF_RenderGlyph_Blended(), but takes a 32-bit character
 * instead of 16-bit, and thus can render a larger range. If you are sure
 * you'll have an SDL_ttf that's version 2.0.18 or newer, there's no reason
 * not to use this function exclusively.
 *
 * You can render at other quality levels with TTF_RenderGlyph32_Solid,
 * TTF_RenderGlyph32_Shaded, and TTF_RenderGlyph32_LCD.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_RenderGlyph32_Solid
 * \sa TTF_RenderGlyph32_Shaded
 * \sa TTF_RenderGlyph32_LCD
  }
function TTF_RenderGlyph32_Blended(font: PTTF_Font; ch: cuint32; fg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph32_Blended' {$ENDIF} {$ENDIF};

{*
 * Render Latin1 text at LCD subpixel quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderText_LCD_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_LCD() unless you're sure you have
 * a 1-byte Latin1 encoding. US ASCII characters will work with either
 * function, but most other Unicode characters packed into a `const char *`
 * will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid,
 * TTF_RenderText_Shaded, and TTF_RenderText_Blended.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUTF8_LCD
 * \sa TTF_RenderUNICODE_LCD
  }
function TTF_RenderText_LCD(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_LCD' {$ENDIF} {$ENDIF};

{*
 * Render UTF-8 text at LCD subpixel quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUTF8_LCD_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid,
 * TTF_RenderUTF8_Shaded, and TTF_RenderUTF8_Blended.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUNICODE_LCD
  }
function TTF_RenderUTF8_LCD(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_LCD' {$ENDIF} {$ENDIF};

{*
 * Render UCS-2 text at LCD subpixel quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * This will not word-wrap the string; you'll get a surface with a single line
 * of text, as long as the string requires. You can use
 * TTF_RenderUNICODE_LCD_Wrapped() instead if you need to wrap the output to
 * multiple lines.
 *
 * This will not wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with TTF_RenderUNICODE_Solid,
 * TTF_RenderUNICODE_Shaded, and TTF_RenderUNICODE_Blended.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUTF8_LCD
  }
function TTF_RenderUNICODE_LCD(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_LCD' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped Latin1 text at LCD subpixel quality to a new ARGB
 * surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You almost certainly want TTF_RenderUTF8_LCD_Wrapped() unless you're sure
 * you have a 1-byte Latin1 encoding. US ASCII characters will work with
 * either function, but most other Unicode characters packed into a `const
 * char *` will need UTF-8.
 *
 * You can render at other quality levels with TTF_RenderText_Solid_Wrapped,
 * TTF_RenderText_Shaded_Wrapped, and TTF_RenderText_Blended_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in Latin1 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUTF8_LCD_Wrapped
 * \sa TTF_RenderUNICODE_LCD_Wrapped
  }
function TTF_RenderText_LCD_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderText_LCD_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UTF-8 text at LCD subpixel quality to a new ARGB
 * surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * You can render at other quality levels with TTF_RenderUTF8_Solid_Wrapped,
 * TTF_RenderUTF8_Shaded_Wrapped, and TTF_RenderUTF8_Blended_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UTF-8 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUTF8_Solid_Wrapped
 * \sa TTF_RenderUTF8_Shaded_Wrapped
 * \sa TTF_RenderUTF8_Blended_Wrapped
  }
function TTF_RenderUTF8_LCD_Wrapped(font: PTTF_Font; text: PAnsiChar; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUTF8_LCD_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render word-wrapped UCS-2 text at LCD subpixel quality to a new ARGB
 * surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * Text is wrapped to multiple lines on line endings and on word boundaries if
 * it extends beyond `wrapLength` in pixels.
 *
 * If wrapLength is 0, this function will only wrap on newline characters.
 *
 * Please note that this function is named "Unicode" but currently expects
 * UCS-2 encoding (16 bits per codepoint). This does not give you access to
 * large Unicode values, such as emoji glyphs. These codepoints are accessible
 * through the UTF-8 version of this function.
 *
 * You can render at other quality levels with
 * TTF_RenderUNICODE_Solid_Wrapped, TTF_RenderUNICODE_Shaded_Wrapped, and
 * TTF_RenderUNICODE_Blended_Wrapped.
 *
 * \param font the font to render with.
 * \param text text to render, in UCS-2 encoding.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderUTF8_LCD_Wrapped
  }
function TTF_RenderUNICODE_LCD_Wrapped(font: PTTF_Font; text: pcuint16; fg: TSDL_Color; bg: TSDL_Color; wrapLength: cuint32): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderUNICODE_LCD_Wrapped' {$ENDIF} {$ENDIF};

{*
 * Render a single 16-bit glyph at LCD subpixel quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * Note that this version of the function takes a 16-bit character code, which
 * covers the Basic Multilingual Plane, but is insufficient to cover the
 * entire set of possible Unicode values, including emoji glyphs. You should
 * use TTF_RenderGlyph32_LCD() instead, which offers the same functionality
 * but takes a 32-bit codepoint instead.
 *
 * This function only exists for consistency with the existing API at the time
 * of its addition.
 *
 * You can render at other quality levels with TTF_RenderGlyph_Solid,
 * TTF_RenderGlyph_Shaded, and TTF_RenderGlyph_Blended.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderGlyph32_LCD
  }
function TTF_RenderGlyph_LCD(font: PTTF_Font; ch: cuint16; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph_LCD' {$ENDIF} {$ENDIF};

{*
 * Render a single 32-bit glyph at LCD subpixel quality to a new ARGB surface.
 *
 * This function will allocate a new 32-bit, ARGB surface, and render
 * alpha-blended text using FreeType's LCD subpixel rendering. This function
 * returns the new surface, or nil if there was an error.
 *
 * The glyph is rendered without any padding or centering in the X direction,
 * and aligned normally in the Y direction.
 *
 * This is the same as TTF_RenderGlyph_LCD(), but takes a 32-bit character
 * instead of 16-bit, and thus can render a larger range. Between the two, you
 * should always use this function.
 *
 * You can render at other quality levels with TTF_RenderGlyph32_Solid,
 * TTF_RenderGlyph32_Shaded, and TTF_RenderGlyph32_Blended.
 *
 * \param font the font to render with.
 * \param ch the character to render.
 * \param fg the foreground color for the text.
 * \param bg the background color for the text.
 * \returns a new 32-bit, ARGB surface, or nil if there was an error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
 *
 * \sa TTF_RenderGlyph32_Solid
 * \sa TTF_RenderGlyph32_Shaded
 * \sa TTF_RenderGlyph32_Blended
  }
function TTF_RenderGlyph32_LCD(font: PTTF_Font; ch: cuint32; fg: TSDL_Color; bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_RenderGlyph32_LCD' {$ENDIF} {$ENDIF};

{* For compatibility with previous versions, here are the old functions *}
function TTF_RenderText(font: PTTF_Font; text: PAnsiChar; fg, bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_TTF_RenderText_Shaded' {$ELSE} 'TTF_RenderText_Shaded' {$ENDIF};
function TTF_RenderUTF8(font: PTTF_Font; text: PAnsiChar; fg, bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_TTF_RenderUTF8_Shaded' {$ELSE} 'TTF_RenderUTF8_Shaded' {$ENDIF};
function TTF_RenderUNICODE(font: PTTF_Font; text: pcuint16; fg, bg: TSDL_Color): PSDL_Surface; cdecl;
  external TTF_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_TTF_RenderUNICODE_Shaded' {$ELSE} 'TTF_RenderUNICODE_Shaded' {$ENDIF};

{*
 * Dispose of a previously-created font.
 *
 * Call this when done with a font. This function will free any resources
 * associated with it. It is safe to call this function on nil, for example
 * on the result of a failed call to TTF_OpenFont().
 *
 * The font is not valid after being passed to this function. String pointers
 * from functions that return information on this font, such as
 * TTF_FontFaceFamilyName() and TTF_FontFaceStyleName(), are no longer valid
 * after this call, as well.
 *
 * \param font the font to dispose of.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_OpenFont
 * \sa TTF_OpenFontIndexDPIRW
 * \sa TTF_OpenFontRW
 * \sa TTF_OpenFontDPI
 * \sa TTF_OpenFontDPIRW
 * \sa TTF_OpenFontIndex
 * \sa TTF_OpenFontIndexDPI
 * \sa TTF_OpenFontIndexDPIRW
 * \sa TTF_OpenFontIndexRW
  }
procedure TTF_CloseFont(font: PTTF_Font); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_CloseFont' {$ENDIF} {$ENDIF};

{*
 * Deinitialize SDL_ttf.
 *
 * You must call this when done with the library, to free internal resources.
 * It is safe to call this when the library isn't initialized, as it will just
 * return immediately.
 *
 * Once you have as many quit calls as you have had successful calls to
 * TTF_Init, the library will actually deinitialize.
 *
 * Please note that this does not automatically close any fonts that are still
 * open at the time of deinitialization, and it is possibly not safe to close
 * them afterwards, as parts of the library will no longer be initialized to
 * deal with it. A well-written program should call TTF_CloseFont() on any
 * open fonts before calling this function!
 *
 * \since This function is available since SDL_ttf 2.0.12.
  }
procedure TTF_Quit(); cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_Quit' {$ENDIF} {$ENDIF};

{*
 * Check if SDL_ttf is initialized.
 *
 * This reports the number of times the library has been initialized by a call
 * to TTF_Init(), without a paired deinitialization request from TTF_Quit().
 *
 * In short: if it's greater than zero, the library is currently initialized
 * and ready to work. If zero, it is not initialized.
 *
 * Despite the return value being a signed integer, this function should not
 * return a negative number.
 *
 * \returns the current number of initialization calls, that need to
 *          eventually be paired with this many calls to TTF_Quit().
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_Init
 * \sa TTF_Quit
  }
function TTF_WasInit: cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_WasInit' {$ENDIF} {$ENDIF};

{*
 * Query the kerning size of two glyphs indices.
 *
 * \deprecated This function accidentally requires FreeType font indexes,
 *             not codepoints, which we don't expose through this API, so
 *             it could give wildly incorrect results, especially with
 *             non-ASCII values. Going forward, please use
 *             TTF_GetFontKerningSizeGlyphs() instead, which does what you
 *             probably expected this function to do.
 *
 * \param font the font to query.
 * \param prev_index the font index, NOT codepoint, of the previous character.
 * \param index the font index, NOT codepoint, of the current character.
 * \returns The kerning size between the two specified characters, in pixels, or -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.12.
 *
 * \sa TTF_GetFontKerningSizeGlyphs
  }
function TTF_GetFontKerningSize(font: PTTF_Font; prev_index: cint; index: cint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontKerningSize' {$ENDIF} {$ENDIF};
  deprecated 'This function requires FreeType font indexes, not glyphs. Use TTF_GetFontKerningSizeGlyphs() instead';

{*
 * Query the kerning size of two 16-bit glyphs.
 *
 * Note that this version of the function takes 16-bit character
 * codes, which covers the Basic Multilingual Plane, but is insufficient
 * to cover the entire set of possible Unicode values, including emoji
 * glyphs. You should use TTF_GetFontKerningSizeGlyphs32() instead, which
 * offers the same functionality but takes a 32-bit codepoints instead.
 *
 * The only reason to use this function is that it was available since
 * the beginning of time, more or less.
 *
 * \param font the font to query.
 * \param previous_ch the previous character's code, 16 bits.
 * \param ch the current character's code, 16 bits.
 * \returns The kerning size between the two specified characters, in pixels, or -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.14.
 *
 * \sa TTF_GetFontKerningSizeGlyphs32
  }
function TTF_GetFontKerningSizeGlyphs(font: PTTF_Font; previous_ch: cuint16; ch: cuint16): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontKerningSizeGlyphs' {$ENDIF} {$ENDIF};

{*
 * Query the kerning size of two 32-bit glyphs.
 *
 * This is the same as TTF_GetFontKerningSizeGlyphs(), but takes 32-bit
 * characters instead of 16-bit, and thus can manage a larger range. If
 * you are sure you'll have an SDL_ttf that's version 2.0.18 or newer,
 * there's no reason not to use this function exclusively.
 *
 * \param font the font to query.
 * \param previous_ch the previous character's code, 32 bits.
 * \param ch the current character's code, 32 bits.
 * \returns The kerning size between the two specified characters, in pixels, or -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
  }
function TTF_GetFontKerningSizeGlyphs32(font: PTTF_Font; previous_ch: cuint32; ch: cuint32): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontKerningSizeGlyphs32' {$ENDIF} {$ENDIF};

{*
 * Enable Signed Distance Field rendering for a font.
 *
 * This works with the Blended APIs. SDF is a technique that
 * helps fonts look sharp even when scaling and rotating.
 *
 * This clears already-generated glyphs, if any, from the cache.
 *
 * \param font the font to set SDF support on.
 * \param on_off SDL_TRUE to enable SDF, SDL_FALSE to disable.
 *
 * \returns 0 on success, -1 on error.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_GetFontSDF
  }
function TTF_SetFontSDF(font: PTTF_Font; on_off: TSDL_bool): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontSDF' {$ENDIF} {$ENDIF};

{*
 * Query whether Signed Distance Field rendering is enabled for a font.
 *
 * \param font the font to query
 *
 * \returns SDL_TRUE if enabled, SDL_FALSE otherwise.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_SetFontSDF
  }
(* Const before type ignored *)
function TTF_GetFontSDF(font: PTTF_Font): TSDL_bool; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_GetFontSDF' {$ENDIF} {$ENDIF};

{*
 * Report SDL_ttf errors
 *
 * \sa TTF_GetError
  }
function TTF_SetError(const fmt: PAnsiChar; args: array of const): cint; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_SetError' {$ELSE} 'SDL_SetError' {$ENDIF};

{*
 * Get last SDL_ttf error
 *
 * \sa TTF_SetError
  }
function TTF_GetError: PAnsiChar; cdecl;
  external SDL_LibName
  name {$IF DEFINED(DELPHI) AND DEFINED(MACOS)} '_SDL_GetError' {$ELSE} 'SDL_GetError' {$ENDIF};

{*
 * Direction flags
 *
 * \sa TTF_SetFontDirection
  }
type
  PPTTF_Direction = ^PTTF_Direction;
  PTTF_Direction = ^TTTF_Direction;
  TTTF_Direction =  type Integer;

const
  TTF_DIRECTION_LTR = TTTF_Direction(0);          { Left to Right  }
  TTF_DIRECTION_RTL = TTTF_Direction(1);          { Right to Left  }
  TTF_DIRECTION_TTB = TTTF_Direction(2);          { Top to Bottom  }
  TTF_DIRECTION_BTT = TTTF_Direction(3);          { Bottom to Top  }

{*
 * Set a global direction to be used for text shaping.
 *
 * \deprecated This function expects an hb_direction_t value, from HarfBuzz,
 *             cast to an int, and affects all fonts globally. Please use
 *             TTF_SetFontDirection() instead, which uses an enum supplied by
 *             SDL_ttf itself and operates on a per-font basis.
 *
 *             This is a global setting; fonts will favor a value set with
 *             TTF_SetFontDirection(), but if they have not had one explicitly
 *             set, they will use the value specified here.
 *
 *             The default value is `HB_DIRECTION_LTR` (left-to-right text
 *             flow).
 *
 * \param direction an hb_direction_t value.
 * \returns 0, or -1 if SDL_ttf is not compiled with HarfBuzz support.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_SetFontDirection
  }
function TTF_SetDirection(direction: cint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetDirection' {$ENDIF} {$ENDIF};
  deprecated; { hb_direction_t  }


{*
 * Set a global script to be used for text shaping.
 *
 * \deprecated This function expects an hb_script_t value, from HarfBuzz, cast
 *             to an int, and affects all fonts globally. Please use
 *             TTF_SetFontScriptName() instead, which accepts a string that is
 *             converted to an equivalent int internally, and operates on a
 *             per-font basis.
 *
 *             This is a global setting; fonts will favor a value set with
 *             TTF_SetFontScriptName(), but if they have not had one
 *             explicitly set, they will use the value specified here.
 *
 *             The default value is `HB_SCRIPT_UNKNOWN`.
 *
 * \returns 0, or -1 if SDL_ttf is not compiled with HarfBuzz support.
 *
 * \since This function is available since SDL_ttf 2.0.18.
 *
 * \sa TTF_SetFontScriptName
  }
function TTF_SetScript(script: cint): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetScript' {$ENDIF} {$ENDIF};
  deprecated; { hb_script_t  }

{*
 * Set direction to be used for text shaping by a font.
 *
 * Any value supplied here will override the global direction set with the
 * deprecated TTF_SetDirection().
 *
 * Possible direction values are:
 *
 * - `TTF_DIRECTION_LTR` (Left to Right)
 * - `TTF_DIRECTION_RTL` (Right to Left)
 * - `TTF_DIRECTION_TTB` (Top to Bottom)
 * - `TTF_DIRECTION_BTT` (Bottom to Top)
 *
 * If SDL_ttf was not built with HarfBuzz support, this function returns -1.
 *
 * \param font the font to specify a direction for.
 * \param direction the new direction for text to flow.
 * \returns 0 on success, or -1 on error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
  }
function TTF_SetFontDirection(font: PTTF_Font; direction: TTTF_Direction): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontDirection' {$ENDIF} {$ENDIF};

{*
 * Set script to be used for text shaping by a font.
 *
 * Any value supplied here will override the global script set with the
 * deprecated TTF_SetScript().
 *
 * The supplied script value must be a null-terminated string of exactly four
 * characters.
 *
 * If SDL_ttf was not built with HarfBuzz support, this function returns -1.
 *
 * \param font the font to specify a direction for.
 * \param script null-terminated string of exactly 4 characters.
 * \returns 0 on success, or -1 on error.
 *
 * \since This function is available since SDL_ttf 2.20.0.
  }
function TTF_SetFontScriptName(font: PTTF_Font; script: PAnsiChar): cint; cdecl;
  external TTF_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_TTF_SetFontScriptName' {$ENDIF} {$ENDIF};

implementation

procedure SDL_TTF_VERSION(out X: TSDL_Version);
begin
  x.major := SDL_TTF_MAJOR_VERSION;
  x.minor := SDL_TTF_MINOR_VERSION;
  x.patch := SDL_TTF_PATCHLEVEL;
end;

procedure TTF_VERSION(out X: TSDL_Version);
begin
  SDL_TTF_VERSION(X);
end;

function SDL_TTF_VERSION_ATLEAST(X, Y, Z: Integer): Boolean;
begin
  Result := (SDL_TTF_MAJOR_VERSION >= X) and
            ((SDL_TTF_MAJOR_VERSION > X) or (SDL_TTF_MINOR_VERSION >= Y)) and
            ((SDL_TTF_MAJOR_VERSION > X) or (SDL_TTF_MINOR_VERSION > Y) or (SDL_TTF_PATCHLEVEL >= Z));
end;

end.

