//based on "sdl_rwops" (2.0.14)

{**
 *  \file SDL_rwops.h
 *
 *  This file provides a general interface for SDL to read and write
 *  data streams.  It can easily be extended to files, memory, etc.
 *}

const
  {* RWops Types *}
  SDL_RWOPS_UNKNOWN	  = 0;	{* Unknown stream type *}
  SDL_RWOPS_WINFILE	  = 1;	{* Win32 file *}
  SDL_RWOPS_STDFILE	  = 2;	{* Stdio file *}
  SDL_RWOPS_JNIFILE	  = 3;	{* Android asset *}
  SDL_RWOPS_MEMORY        = 4;	{* Memory stream *}
  SDL_RWOPS_MEMORY_RO     = 5;	{* Read-Only memory stream *}

type
  PPSDL_RWops = ^PSDL_RWops;
  PSDL_RWops = ^TSDL_RWops;

  {**
   * This is the read/write operation structure -- very basic.
   *}

  {**
   *  Return the size of the file in this rwops, or -1 if unknown
   *}
  TSize = function(context: PSDL_RWops): cint64; {$IFNDEF GPC} cdecl; {$ENDIF}

  {**
   *  Seek to offset relative to whence, one of stdio's whence values:
   *  RW_SEEK_SET, RW_SEEK_CUR, RW_SEEK_END
   *
   *  the final offset in the data stream, or -1 on error.
   *}
  TSeek = function(context: PSDL_RWops; offset: cint64; whence: cint): cint64; {$IFNDEF GPC} cdecl; {$ENDIF}
                   
  {**
   *  Read up to maxnum objects each of size size from the data
   *  stream to the area pointed at by ptr.
   *
   *  the number of objects read, or 0 at error or end of file.
   *}
   TRead = function(context: PSDL_RWops; ptr: Pointer; size: csize_t; maxnum: csize_t): csize_t; {$IFNDEF GPC} cdecl; {$ENDIF}

  {**
   *  Write exactly num objects each of size size from the area
   *  pointed at by ptr to data stream.
   *  
   *  the number of objects written, or 0 at error or end of file.
   *}
   TWrite = function(context: PSDL_RWops; const ptr: Pointer; size: csize_t; num: csize_t): csize_t; {$IFNDEF GPC} cdecl; {$ENDIF}
	
  {**
   *  Close and free an allocated SDL_RWops structure.
   *  
   *  0 if successful or -1 on write error when flushing data.
   *}
  TClose =  function(context: PSDL_RWops): cint; {$IFNDEF GPC} cdecl; {$ENDIF}

  // (2.0.14) Outdated decl., kept commented just in case.
  {TAndroidIO = record
    fileNameRef: Pointer;
    inputStreamRef: Pointer;
    readableByteChannelRef: Pointer;
    readMethod: Pointer;
    assetFileDescriptorRef: Pointer;
    position: LongInt;
    size: LongInt;
    offset: LongInt;
    fd: cint32;
  end;}

  TAndroidIO = record
    asset: Pointer;
  end;

  TWindowsIOBuffer = record
    data: Pointer;
    size: csize_t;
    left: csize_t;
  end;

  TWindowsIO = record
    append: TSDL_Bool;
    h: Pointer;
    buffer: TWindowsIOBuffer;
  end;

  TStdio = record
    autoclose: TSDL_Bool;
    fp: file;               // Is this appropriate? C FILE --> Pascal file
  end;
  
  TMem = record
    base: pcuint8;
    here: pcuint8;
    stop: pcuint8;
  end;
  
  TUnknown = record
    data1: Pointer;
    data2: Pointer;
  end;

  TSDL_RWops = packed record
    size: TSize;
    seek: TSeek;
    read: TRead;
    write: TWrite;
    close: TClose;

    _type: cuint32;

    case hidden: cint of
      {$IFDEF ANDROID}
      0: (androidio: TAndroidIO);
      {$ENDIF}
      {$IFDEF WINDOWS}
      0: (windowsio: TWindowsIO);
      {$ENDIF}
      1: (stdio: TStdio);
      2: (mem: TMem);
      3: (unknown: TUnknown);
  end;

{**
 *  RWFrom functions
 *
 *  Functions to create SDL_RWops structures from various data streams.
 *}
function SDL_RWFromFile(const _file: PAnsiChar; const mode: PAnsiChar): PSDL_RWops; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWFromFile' {$ENDIF} {$ENDIF};

{function SDL_RWFromFP(fp: file; autoclose: TSDL_Bool): PSDL_RWops; cdecl;
   external SDL_LibName;} //don't know if this works

function SDL_RWFromFP(fp: Pointer; autoclose: TSDL_Bool): PSDL_RWops; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWFromFP' {$ENDIF} {$ENDIF};

function SDL_RWFromMem(mem: Pointer; size: cint): PSDL_RWops; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWFromMem' {$ENDIF} {$ENDIF};

function SDL_RWFromConstMem(const mem: Pointer; size: cint): PSDL_RWops; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWFromConstMem' {$ENDIF} {$ENDIF};

{*RWFrom functions*}
function SDL_AllocRW: PSDL_RWops; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_AllocRW' {$ENDIF} {$ENDIF};

procedure SDL_FreeRW(area: PSDL_RWops); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FreeRW' {$ENDIF} {$ENDIF};

const
  RW_SEEK_SET = 0;       {**< Seek from the beginning of data *}
  RW_SEEK_CUR = 1;       {**< Seek relative to current read point *}
  RW_SEEK_END = 2;       {**< Seek relative to the end of data *}

{**
 *  Return the size of the file in this rwops, or -1 if unknown
 *}
function SDL_RWsize(context: PSDL_RWops): cint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWsize' {$ENDIF} {$ENDIF};

{**
 *  Seek to \c offset relative to \c whence, one of stdio's whence values:
 *  RW_SEEK_SET, RW_SEEK_CUR, RW_SEEK_END
 *
 *  \return the final offset in the data stream, or -1 on error.
 *}
function SDL_RWseek(context: PSDL_RWops; offset: cint64; whence: cint): cint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_RWseek' {$ENDIF} {$ENDIF};

{**
 *  Return the current offset in the data stream, or -1 on error.
 *}
function SDL_RWtell(context: PSDL_RWops): cint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWtell' {$ENDIF} {$ENDIF};

{**
 *  Read up to \c maxnum objects each of size \c size from the data
 *  stream to the area pointed at by \c ptr.
 *
 *  \return the number of objects read, or 0 at error or end of file.
 *}
function SDL_RWread(context: PSDL_RWops; ptr: Pointer; size: csize_t; n: csize_t): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWread' {$ENDIF} {$ENDIF};

{**
 *  Write exactly \c num objects each of size \c size from the area
 *  pointed at by \c ptr to data stream.
 *
 *  \return the number of objects written, or 0 at error or end of file.
 *}
function SDL_RWwrite(context: PSDL_RWops; ptr: Pointer; size: csize_t; n: csize_t): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWwrite' {$ENDIF} {$ENDIF};

{**
 *  Close and free an allocated SDL_RWops structure.
 *
 *  \return 0 if successful or -1 on write error when flushing data.
 *}
function SDL_RWclose(context: PSDL_RWops): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RWclose' {$ENDIF} {$ENDIF};

{**
 *  Load all the data from an SDL data stream.
 *
 *  The data is allocated with a zero byte at the end (null terminated)
 *
 *  If \c datasize is not NULL, it is filled with the size of the data read.
 *
 *  If \c freesrc is non-zero, the stream will be closed after being read.
 *
 *  The data should be freed with SDL_free().
 *
 *  \return the data, or NULL if there was an error.
 *}
function SDL_LoadFile_RW(src: PSDL_RWops; datasize: pcsize_t; freesrc: cint): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LoadFile_RW' {$ENDIF} {$ENDIF};

{**
 *  Load an entire file.
 *
 *  The data is allocated with a zero byte at the end (null terminated)
 *
 *  If \c datasize is not NULL, it is filled with the size of the data read.
 *
 *  If \c freesrc is non-zero, the stream will be closed after being read.
 *
 *  The data should be freed with SDL_free().
 *
 *  \return the data, or NULL if there was an error.
 *}
function SDL_LoadFile(file_: PAnsiChar; datasize: pcsize_t): Pointer; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LoadFile' {$ENDIF} {$ENDIF};

{**
 *  Read endian functions
 *
 *  Read an item of the specified endianness and return in native format.
 *}
function SDL_ReadU8(src: PSDL_RWops): cuint8; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadU8' {$ENDIF} {$ENDIF};
function SDL_ReadLE16(src: PSDL_RWops): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadLE16' {$ENDIF} {$ENDIF};
function SDL_ReadBE16(src: PSDL_RWops): cuint16; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadBE16' {$ENDIF} {$ENDIF};
function SDL_ReadLE32(src: PSDL_RWops): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadLE32' {$ENDIF} {$ENDIF};
function SDL_ReadBE32(src: PSDL_RWops): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadBE32' {$ENDIF} {$ENDIF};
function SDL_ReadLE64(src: PSDL_RWops): cuint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadLE64' {$ENDIF} {$ENDIF};
function SDL_ReadBE64(src: PSDL_RWops): cuint64; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ReadBE64' {$ENDIF} {$ENDIF};
{ Read endian functions }

{**
 *  Write endian functions
 *
 *  Write an item of native format to the specified endianness.
 *}
function SDL_WriteU8(dst: PSDL_RWops; value: cuint8): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteU8' {$ENDIF} {$ENDIF};
function SDL_WriteLE16(dst: PSDL_RWops; value: cuint16): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteLE16' {$ENDIF} {$ENDIF};
function SDL_WriteBE16(dst: PSDL_RWops; value: cuint16): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteBE16' {$ENDIF} {$ENDIF};
function SDL_WriteLE32(dst: PSDL_RWops; value: cuint32): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteLE32' {$ENDIF} {$ENDIF};
function SDL_WriteBE32(dst: PSDL_RWops; value: cuint32): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteBE32' {$ENDIF} {$ENDIF};
function SDL_WriteLE64(dst: PSDL_RWops; value: cuint64): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteLE64' {$ENDIF} {$ENDIF};
function SDL_WriteBE64(dst: PSDL_RWops; value: cuint64): csize_t; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WriteBE64' {$ENDIF} {$ENDIF};
{ Write endian functions }
