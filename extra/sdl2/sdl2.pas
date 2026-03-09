unit sdl2;

{
                                SDL2-for-Pascal
                               =================
          Pascal units for SDL2 - Simple Direct MediaLayer, Version 2

  Copyright (C) 2020-2023 PGD Community
  Maintainers: M. J. Molski and suve
  Visit: https://github.com/PascalGameDevelopment/SDL2-for-Pascal

  Simple DirectMedia Layer
  Copyright (C) 1997-2023 Sam Lantinga <slouken@libsdl.org>
  Visit: http://libsdl.org

  SDL2-for-Pascal is based upon:

    Pascal-Header-Conversion
    Copyright (C) 2012-2020 Tim Blume aka End/EV1313

    JEDI-SDL : Pascal units for SDL
    Copyright (C) 2000 - 2004 Dominique Louis <Dominique@SavageSoftware.com.au>

  sdl2.pas is based on the C header files in the include folder
  of the original Simple DirectMedia Layer repository.
  See: https://github.com/libsdl-org/SDL

  OpenGL header files are not translated:
  "sdl_opengl.h",
  "sdl_opengles.h"
  "sdl_opengles2.h"

  There is a much better OpenGL-Header avaible at delphigl.com: dglopengl.pas
  See: https://github.com/SaschaWillems/dglOpenGL

  This software is provided 'as-is', without any express or implied
  warranty.  In no case will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Special Thanks to:

   - Tim Blume and everyone else contributing to the "Pascal-Header-Conversion"
   - DelphiGL.com - Community
   - Domenique Louis and everyone else from the JEDI-Team
   - Sam Latinga and everyone else from the SDL-Team
}

{$DEFINE SDL}

{$I jedi.inc}

interface

  {$IFDEF WINDOWS}
    uses
      {$IFDEF FPC}
      ctypes,
      {$ENDIF}
      Windows;
  {$ENDIF}

  {$IF DEFINED(UNIX) AND NOT DEFINED(ANDROID)}
    uses
      {$IFDEF FPC}
      ctypes,
      UnixType,
      {$ENDIF}
      {$IFDEF DARWIN}
      CocoaAll;
      {$ELSE}
      X,
      XLib;
      {$ENDIF}
  {$ENDIF}

  {$IF DEFINED(UNIX) AND DEFINED(ANDROID) AND DEFINED(FPC)}
    uses
      ctypes,
      UnixType;
  {$ENDIF}

const

  {$IFDEF WINDOWS}
    SDL_LibName = 'SDL2.dll';
  {$ENDIF}

  {$IFDEF UNIX}
    {$IFDEF DARWIN}
      SDL_LibName = 'libSDL2.dylib';
      {$IFDEF FPC}
        {$LINKLIB libSDL2}
      {$ENDIF}
    {$ELSE}
      {$IFDEF FPC}
        SDL_LibName = 'libSDL2.so';
      {$ELSE}
        SDL_LibName = 'libSDL2.so.0';
      {$ENDIF}
      {$MESSAGE HINT 'Known MESA bug may generate float-point exception in software graphics mode! See https://github.com/PascalGameDevelopment/SDL2-for-Pascal/issues/56 for reference.'}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF MACOS}
    SDL_LibName = 'SDL2';
    {$IFDEF FPC}
      {$linklib libSDL2}
    {$ENDIF}
  {$ENDIF}


{$DEFINE WANT_CWCHAR_T}
{$I ctypes.inc}                  // C data types

                                 {SDL2 version of the represented header file}
{$I sdlstdinc.inc}
{$I sdlversion.inc}              // 2.0.14
{$I sdlerror.inc}                // 2.0.14
{$I sdlplatform.inc}             // 2.0.14
{$I sdlpower.inc}                // 2.0.14
{$I sdlthread.inc}               // 2.30.2
{$I sdlatomic.inc}               // 2.0.20
{$I sdlmutex.inc}                // 2.26.5
{$I sdltimer.inc}                // 2.0.18
{$I sdlpixels.inc}               // 2.26.5
{$I sdlrect.inc}                 // 2.24.0
{$I sdlrwops.inc}                // 2.0.14
{$I sdlaudio.inc}                // 2.26.3
{$I sdlblendmode.inc}            // 2.0.14
{$I sdlsurface.inc}              // 2.0.14
{$I sdlvideo.inc}                // 2.28.0
{$I sdlshape.inc}                // 2.24.0
{$I sdlhints.inc}                // 2.26.0
{$I sdlloadso.inc}               // 2.24.1
{$I sdlmessagebox.inc}           // 2.0.14
{$I sdlrenderer.inc}             // 2.0.22
{$I sdlscancode.inc}             // 2.26.2
{$I sdlkeycode.inc}              // 2.26.2
{$I sdlkeyboard.inc}             // 2.24.1
{$I sdlmouse.inc}                // 2.0.24
{$I sdlguid.inc}                 // 2.24.0
{$I sdljoystick.inc}             // 2.24.0
{$I sdlsensor.inc}               // 2.26.0
{$I sdlgamecontroller.inc}       // 2.30.0
{$I sdlhaptic.inc}               // 2.26.2
{$I sdlhidapi.inc}               // 2.0.18
{$I sdltouch.inc}                // 2.24.0
{$I sdlgesture.inc}              // 2.26.2
{$I sdlsyswm.inc}                // 2.26.5
{$I sdlevents.inc}               // 2.24.0
{$I sdllocale.inc}               // 2.0.14
{$I sdlclipboard.inc}            // 2.24.1
{$I sdlcpuinfo.inc}              // 2.0.14
{$I sdlfilesystem.inc}           // 2.24.1
{$I sdllog.inc}                  // 2.0.14
{$I sdlmisc.inc}                 // 2.0.14
{$I sdlsystem.inc}               // 2.24.0
{$I sdl.inc}                     // 2.0.14

implementation

(*
 * We need an strlen() implementation for some operations on C-strings.
 * FPC ships one in the Strings unit; Delphi has one in the AnsiStrings unit.
 * Since FPC defines "DELPHI" when building in Delphi-compatibility mode,
 * check if "FPC" is defined to determine which compiler is used.
 *)
uses
	{$IFDEF FPC}
		Strings
	{$ELSE}
		AnsiStrings
	{$ENDIF}
	;

// Macros from "sdl_version.h"
procedure SDL_VERSION(out x: TSDL_Version);
begin
  x.major := SDL_MAJOR_VERSION;
  x.minor := SDL_MINOR_VERSION;
  x.patch := SDL_PATCHLEVEL;
end;

function SDL_VERSIONNUM(X,Y,Z: cuint8): Cardinal;
begin
  Result := X*1000 + Y*100 + Z;
end;

function SDL_COMPILEDVERSION: Cardinal;
begin
  Result := SDL_VERSIONNUM(SDL_MAJOR_VERSION,
                           SDL_MINOR_VERSION,
                           SDL_PATCHLEVEL);
end;

function SDL_VERSION_ATLEAST(X,Y,Z: cuint8): Boolean;
begin
  Result := SDL_COMPILEDVERSION >= SDL_VERSIONNUM(X,Y,Z);
end;

//Macros from "sdl_mouse.h"
function SDL_Button(X: cint): cint;
begin
  Result := 1 shl (X - 1);
end;

{$IFDEF WINDOWS}
//from "sdl_thread.h"

function SDL_CreateThread(fn: TSDL_ThreadFunction; name: PAnsiChar;
  data: Pointer): PSDL_Thread; overload;
begin
  Result := SDL_CreateThread(fn,name,data,nil,nil);
end;

function SDL_CreateThreadWithStackSize(fn: TSDL_ThreadFunction;
  name: PAnsiChar; const stacksize: csize_t; data: Pointer
  ): PSDL_Thread; overload;
begin
  Result := SDL_CreateThreadWithStackSize(
    fn,name,stacksize,data,nil,nil);
end;

{$ENDIF}

//from "sdl_rect.h"
function SDL_PointInRect(const p: PSDL_Point; const r: PSDL_Rect): Boolean;
begin
  Result :=
    (p^.x >= r^.x) and (p^.x < (r^.x + r^.w))
    and
    (p^.y >= r^.y) and (p^.y < (r^.y + r^.h))
end;

function SDL_RectEmpty(const r: PSDL_Rect): Boolean;
begin
  Result := (r = NIL) or (r^.w <= 0) or (r^.h <= 0);
end;

function SDL_RectEquals(const a, b: PSDL_Rect): Boolean;
begin
  Result := (a^.x = b^.x) and (a^.y = b^.y) and (a^.w = b^.w) and (a^.h = b^.h);
end;

function SDL_PointInFRect(const p: PSDL_FPoint; const r: PSDL_FRect): Boolean;
begin
  Result :=
    (p^.x >= r^.x) and (p^.x < (r^.x + r^.w))
    and
    (p^.y >= r^.y) and (p^.y < (r^.y + r^.h))
end;

function SDL_FRectEmpty(const r: PSDL_FRect): Boolean;
begin
  Result := (r = NIL) or (r^.w <= cfloat(0.0)) or (r^.h <= cfloat(0.0))
end;

function SDL_FRectEqualsEpsilon(const a, b: PSDL_FRect; const epsilon: cfloat): Boolean;
begin
  Result :=
    (a <> NIL) and
    (b <> NIL) and
    (
      (a = b)
      or
      (
        (SDL_fabsf(a^.x - b^.x) <= epsilon)
        and
        (SDL_fabsf(a^.y - b^.y) <= epsilon)
        and
        (SDL_fabsf(a^.w - b^.w) <= epsilon)
        and
        (SDL_fabsf(a^.h - b^.h) <= epsilon)
      )
    )
end;

function SDL_FRectEquals(const a, b: PSDL_FRect): Boolean; Inline;
begin
  Result := SDL_FRectEqualsEpsilon(a, b, SDL_FLT_EPSILON)
end;

//from "sdl_atomic.h"
function SDL_AtomicIncRef(atomic: PSDL_Atomic): cint;
begin
  Result := SDL_AtomicAdd(atomic, 1)
end;

function SDL_AtomicDecRef(atomic: PSDL_Atomic): Boolean;
begin
  Result := SDL_AtomicAdd(atomic, -1) = 1
end;

procedure SDL_CompilerBarrier();
{$IFDEF FPC}
begin
  ReadWriteBarrier()
{$ELSE}
var
  lock: TSDL_SpinLock;
begin
  lock := 0;
  SDL_AtomicLock(@lock);
  SDL_AtomicUnlock(@lock)
{$ENDIF}
end;

//from "sdl_audio.h"

function SDL_LoadWAV(file_: PAnsiChar; spec: PSDL_AudioSpec; audio_buf: ppcuint8; audio_len: pcuint32): PSDL_AudioSpec;
begin
  Result := SDL_LoadWAV_RW(SDL_RWFromFile(file_, 'rb'), 1, spec, audio_buf, audio_len);
end;
  
function SDL_AUDIO_BITSIZE(x: Cardinal): Cardinal;
begin
  Result := x and SDL_AUDIO_MASK_BITSIZE;
end;

function SDL_AUDIO_ISFLOAT(x: Cardinal): Cardinal;
begin
  Result := x and SDL_AUDIO_MASK_DATATYPE;
end;

function SDL_AUDIO_ISBIGENDIAN(x: Cardinal): Cardinal;
begin
  Result := x and SDL_AUDIO_MASK_ENDIAN;
end;

function SDL_AUDIO_ISSIGNED(x: Cardinal): Cardinal;
begin
  Result := x and SDL_AUDIO_MASK_SIGNED;
end;

function SDL_AUDIO_ISINT(x: Cardinal): Cardinal;
begin
  Result := not SDL_AUDIO_ISFLOAT(x);
end;

function SDL_AUDIO_ISLITTLEENDIAN(x: Cardinal): Cardinal;
begin
  Result := not SDL_AUDIO_ISBIGENDIAN(x);
end;

function SDL_AUDIO_ISUNSIGNED(x: Cardinal): Cardinal;
begin
  Result := not SDL_AUDIO_ISSIGNED(x);
end;

//from "sdl_pixels.h"

function SDL_PIXELFLAG(X: cuint32): cuint32;
begin
  Result := (X shr 28) and $0F;
end;

function SDL_PIXELTYPE(X: cuint32): cuint32;
begin
  Result := (X shr 24) and $0F;
end;

function SDL_PIXELORDER(X: cuint32): cuint32;
begin
  Result := (X shr 20) and $0F;
end;

function SDL_PIXELLAYOUT(X: cuint32): cuint32;
begin
  Result := (X shr 16) and $0F;
end;

function SDL_BITSPERPIXEL(X: cuint32): cuint32;
begin
  Result := (X shr 8) and $FF;
end;

function SDL_ISPIXELFORMAT_FOURCC(format: Variant): Boolean;
begin
  Result := (format and (SDL_PIXELFLAG(format) <> 1));
end;

// Macros from "sdl_surface.h"
function SDL_LoadBMP(_file: PAnsiChar): PSDL_Surface;
begin
  Result := SDL_LoadBMP_RW(SDL_RWFromFile(_file, 'rb'), 1);
end;

function SDL_SaveBMP(const surface: PSDL_Surface; const filename: AnsiString
  ): cint;
begin
   Result := SDL_SaveBMP_RW(surface, SDL_RWFromFile(PAnsiChar(filename), 'wb'), 1)
end;

{**
 *  Evaluates to true if the surface needs to be locked before access.
 *}
function SDL_MUSTLOCK(const S: PSDL_Surface): Boolean;
begin
  Result := ((S^.flags and SDL_RLEACCEL) <> 0)
end;

// Macros from "sdl_shape.h"
function SDL_SHAPEMODEALPHA(mode: TWindowShapeMode): Boolean;
begin
  Result := (mode = ShapeModeDefault) or (mode = ShapeModeBinarizeAlpha) or (mode = ShapeModeReverseBinarizeAlpha);
end;

// from "sdl_stdinc.h"

// Note: We're using FPC's Strings.strlen() here, not SDL_strlen().
function SDL_iconv_utf8_locale(Const str: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := SDL_iconv_string('', 'UTF-8', str, strlen(str)+1)
end;

function SDL_iconv_utf8_ucs2(Const str: PAnsiChar): pcUint16; cdecl;
begin
	Result := pcUint16(SDL_iconv_string('UCS-2-INTERNAL', 'UTF-8', str, strlen(str)+1))
end;

function SDL_iconv_utf8_ucs4(Const str: PAnsiChar): pcUint32; cdecl;
begin
	Result := pcUint32(SDL_iconv_string('UCS-4-INTERNAL', 'UTF-8', str, strlen(str)+1))
end;

//from "sdl_video.h"

function SDL_WINDOWPOS_UNDEFINED_DISPLAY(X: Variant): Variant;
begin
  Result := (SDL_WINDOWPOS_UNDEFINED_MASK or X);
end;

function SDL_WINDOWPOS_ISUNDEFINED(X: Variant): Variant;
begin
  Result := (X and $FFFF0000) = SDL_WINDOWPOS_UNDEFINED_MASK;
end;

function SDL_WINDOWPOS_CENTERED_DISPLAY(X: Variant): Variant;
begin
  Result := (SDL_WINDOWPOS_CENTERED_MASK or X);
end;

function SDL_WINDOWPOS_ISCENTERED(X: Variant): Variant;
begin
  Result := (X and $FFFF0000) = SDL_WINDOWPOS_CENTERED_MASK;
end;

//from "sdl_events.h"

function SDL_GetEventState(type_: TSDL_EventType): cuint8;
begin
  Result := SDL_EventState(type_, SDL_QUERY);
end;

// from "sdl_timer.h"
function SDL_TICKS_PASSED(const A, B: cint32): Boolean;
begin
  Result := ((B - A) <= 0);
end;

// from "sdl_gamecontroller.h"
  {**
   *  Load a set of mappings from a file, filtered by the current SDL_GetPlatform()
   *}
function SDL_GameControllerAddMappingsFromFile(const FilePath: PAnsiChar
  ): cint32;
begin
  Result := SDL_GameControllerAddMappingsFromRW(SDL_RWFromFile(FilePath, 'rb'), 1)
end;

end.
