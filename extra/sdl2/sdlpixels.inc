// based on "sdl_pixels.h" (2.0.14, WIP)

{**
 *  \file SDL_pixels.h
 *
 *  Header for the enumerated pixel format definitions.
 *}

{**
 *  Transparency definitions
 *
 *  These define alpha as the opacity of a surface.
 *}

const
  SDL_ALPHA_OPAQUE = 255;
  SDL_ALPHA_TRANSPARENT = 0;

{** Pixel type. *}
type
  PPSDL_PixelType = ^PSDL_PixelType;
  PSDL_PixelType = ^TSDL_PixelType;
  TSDL_PixelType = type cuint;

const
  SDL_PIXELTYPE_UNKNOWN  = TSDL_PixelType(0);
  SDL_PIXELTYPE_INDEX1   = TSDL_PixelType(1);
  SDL_PIXELTYPE_INDEX4   = TSDL_PixelType(2);
  SDL_PIXELTYPE_INDEX8   = TSDL_PixelType(3);
  SDL_PIXELTYPE_PACKED8  = TSDL_PixelType(4);
  SDL_PIXELTYPE_PACKED16 = TSDL_PixelType(5);
  SDL_PIXELTYPE_PACKED32 = TSDL_PixelType(6);
  SDL_PIXELTYPE_ARRAYU8  = TSDL_PixelType(7);
  SDL_PIXELTYPE_ARRAYU16 = TSDL_PixelType(8);
  SDL_PIXELTYPE_ARRAYU32 = TSDL_PixelType(9);
  SDL_PIXELTYPE_ARRAYF16 = TSDL_PixelType(10);
  SDL_PIXELTYPE_ARRAYF32 = TSDL_PixelType(11);

{** Bitmap pixel order, high bit -> low bit. *}
type
  PPSDL_BitmapOrder = ^PSDL_BitmapOrder;
  PSDL_BitmapOrder = ^TSDL_BitmapOrder;
  TSDL_BitmapOrder = type cuint32;

const
  SDL_BITMAPORDER_NONE = TSDL_BitmapOrder(0);
  SDL_BITMAPORDER_4321 = TSDL_BitmapOrder(1);
  SDL_BITMAPORDER_1234 = TSDL_BitmapOrder(2);

{** Packed component order, high bit -> low bit. *}
type
  PPSDL_PackOrder = ^PSDL_PackOrder;
  PSDL_PackOrder = ^TSDL_PackOrder;
  TSDL_PackOrder = type cuint32;

const
  SDL_PACKEDORDER_NONE = TSDL_PackOrder(0);
  SDL_PACKEDORDER_XRGB = TSDL_PackOrder(1);
  SDL_PACKEDORDER_RGBX = TSDL_PackOrder(2);
  SDL_PACKEDORDER_ARGB = TSDL_PackOrder(3);
  SDL_PACKEDORDER_RGBA = TSDL_PackOrder(4);
  SDL_PACKEDORDER_XBGR = TSDL_PackOrder(5);
  SDL_PACKEDORDER_BGRX = TSDL_PackOrder(6);
  SDL_PACKEDORDER_ABGR = TSDL_PackOrder(7);
  SDL_PACKEDORDER_BGRA = TSDL_PackOrder(8);

{** Array component order, low byte -> high byte. *}
type
  PPSDL_ArrayOrder = ^PSDL_ArrayOrder;
  PSDL_ArrayOrder = ^TSDL_ArrayOrder;
  TSDL_ArrayOrder = type cuint32;

const
  SDL_ARRAYORDER_NONE = TSDL_ArrayOrder(0);
  SDL_ARRAYORDER_RGB  = TSDL_ArrayOrder(1);
  SDL_ARRAYORDER_RGBA = TSDL_ArrayOrder(2);
  SDL_ARRAYORDER_ARGB = TSDL_ArrayOrder(3);
  SDL_ARRAYORDER_BGR  = TSDL_ArrayOrder(4);
  SDL_ARRAYORDER_BGRA = TSDL_ArrayOrder(5);
  SDL_ARRAYORDER_ABGR = TSDL_ArrayOrder(6);

{** Packed component layout. *}
type
  PPSDL_PackedLayout = ^PSDL_PackedLayout;
  PSDL_PackedLayout = ^TSDL_PackedLayout;
  TSDL_PackedLayout = type cuint32;

const
  SDL_PACKEDLAYOUT_NONE    = TSDL_PackedLayout(0);
  SDL_PACKEDLAYOUT_332     = TSDL_PackedLayout(1);
  SDL_PACKEDLAYOUT_4444    = TSDL_PackedLayout(2);
  SDL_PACKEDLAYOUT_1555    = TSDL_PackedLayout(3);
  SDL_PACKEDLAYOUT_5551    = TSDL_PackedLayout(4);
  SDL_PACKEDLAYOUT_565     = TSDL_PackedLayout(5);
  SDL_PACKEDLAYOUT_8888    = TSDL_PackedLayout(6);
  SDL_PACKEDLAYOUT_2101010 = TSDL_PackedLayout(7);
  SDL_PACKEDLAYOUT_1010102 = TSDL_PackedLayout(8);

{
SDL2-for-Pascal: The SDL_DEFINE_PIXELFOURCC macro is replaced
                 by another macro, the SDL_FOURCC macro (in SDL_stdinc.h).

                 The original C SDL_FOURCC macro:
                 #define SDL_FOURCC(A, B, C, D) \
                     ((SDL_static_cast(Uint32, SDL_static_cast(Uint8, (A))) << 0) | \
                      (SDL_static_cast(Uint32, SDL_static_cast(Uint8, (B))) << 8) | \
                      (SDL_static_cast(Uint32, SDL_static_cast(Uint8, (C))) << 16) | \
                      (SDL_static_cast(Uint32, SDL_static_cast(Uint8, (D))) << 24))

                 In Pascal it is cleaner to implement this directly as a
                 constant instead of a function. So we do, e. g.:

                 SDL_PIXELFORMAT_YV12 =  (cuint32('Y')       ) or
                                         (cuint32('V') shl  8) or
                                         (cuint32('1') shl 16) or
                                         (cuint32('2') shl 24);

                 In the future it may be desirable to have a Pascal function.
                 The prototype could look like this:
                 function SDL_DEFINE_PIXELFOURCC(A,B,C,D: Variant): Variant;
}

{
SDL2-for-Pascal: The SDL_DEFINE_PIXELFORMAT macro returns the underlying
                 pixel format based on five arguments.

                 The original C macro:
                 #define SDL_DEFINE_PIXELFORMAT(type, order, layout, bits, bytes) \
                   ((1 << 28) | ((type) << 24) | ((order) << 20) | ((layout) << 16) | \
                   ((bits) << 8) | ((bytes) << 0))

                 This C implementation could be replaced by a Pascal function,
                 but from a performance stand point this will be slower.
                 Therefore we decided to keep it as it has been implemented
                 before by the original binding authors and translate
                 every pixel format constant by the very same expression:

                 SDL_PIXELFORMAT_[...] = (1 shl 28)                     or
                                         (SDL_PIXELTYPE_[...] shl 24)   or
                                         (SDL_BITMAPORDER_[...] shl 20) or
                                         ([...] shl 16)                 or
                                         ([...] shl 8)                  or
                                         ([...] shl 0);

                 In the future it may be desirable to have a Pascal function.
                 The prototype could look like this:
                 function SDL_DEFINE_PIXELFORMAT(type, order, layour, bit, bytes: cuint32): Result;
}

function SDL_PIXELFLAG(X: cuint32): cuint32;
function SDL_PIXELTYPE(X: cuint32): cuint32;
function SDL_PIXELORDER(X: cuint32): cuint32;
function SDL_PIXELLAYOUT(X: cuint32): cuint32;
function SDL_BITSPERPIXEL(X: cuint32): cuint32;

{
SDL2-for-Pascal: Is it worth translating these macros as they seem to be used
                 by SDL2 internally only?

#define SDL_BYTESPERPIXEL(X) \
    (SDL_ISPIXELFORMAT_FOURCC(X) ? \
        ((((X) == SDL_PIXELFORMAT_YUY2) || \
          ((X) == SDL_PIXELFORMAT_UYVY) || \
          ((X) == SDL_PIXELFORMAT_YVYU)) ? 2 : 1) : (((X) >> 0) & 0xFF))

#define SDL_ISPIXELFORMAT_INDEXED(format)   \
    (!SDL_ISPIXELFORMAT_FOURCC(format) && \
     ((SDL_PIXELTYPE(format) == SDL_PIXELTYPE_INDEX1) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_INDEX4) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_INDEX8)))

#define SDL_ISPIXELFORMAT_PACKED(format) \
    (!SDL_ISPIXELFORMAT_FOURCC(format) && \
     ((SDL_PIXELTYPE(format) == SDL_PIXELTYPE_PACKED8) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_PACKED16) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_PACKED32)))

#define SDL_ISPIXELFORMAT_ARRAY(format) \
    (!SDL_ISPIXELFORMAT_FOURCC(format) && \
     ((SDL_PIXELTYPE(format) == SDL_PIXELTYPE_ARRAYU8) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_ARRAYU16) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_ARRAYU32) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_ARRAYF16) || \
      (SDL_PIXELTYPE(format) == SDL_PIXELTYPE_ARRAYF32)))

#define SDL_ISPIXELFORMAT_ALPHA(format)   \
    ((SDL_ISPIXELFORMAT_PACKED(format) && \
     ((SDL_PIXELORDER(format) == SDL_PACKEDORDER_ARGB) || \
      (SDL_PIXELORDER(format) == SDL_PACKEDORDER_RGBA) || \
      (SDL_PIXELORDER(format) == SDL_PACKEDORDER_ABGR) || \
      (SDL_PIXELORDER(format) == SDL_PACKEDORDER_BGRA))) || \
    (SDL_ISPIXELFORMAT_ARRAY(format) && \
     ((SDL_PIXELORDER(format) == SDL_ARRAYORDER_ARGB) || \
      (SDL_PIXELORDER(format) == SDL_ARRAYORDER_RGBA) || \
      (SDL_PIXELORDER(format) == SDL_ARRAYORDER_ABGR) || \
      (SDL_PIXELORDER(format) == SDL_ARRAYORDER_BGRA))))
}

{* The flag is set to 1 because 0x1? is not in the printable ASCII range *}
function SDL_ISPIXELFORMAT_FOURCC(format: Variant): Boolean;

{* Note: If you modify this list, update SDL_GetPixelFormatName() *}
const
    SDL_PIXELFORMAT_UNKNOWN = 0;
    SDL_PIXELFORMAT_INDEX1LSB = (1 shl 28)                    or
                                (SDL_PIXELTYPE_INDEX1 shl 24) or
                                (SDL_BITMAPORDER_4321 shl 20) or
                                (0 shl 16)                    or
                                (1 shl 8)                     or
                                (0 shl 0);

    SDL_PIXELFORMAT_INDEX1MSB = (1 shl 28)                    or
                                (SDL_PIXELTYPE_INDEX1 shl 24) or
                                (SDL_BITMAPORDER_1234 shl 20) or
                                (0 shl 16)                    or
                                (1 shl 8)                     or
                                (0 shl 0);

    SDL_PIXELFORMAT_INDEX4LSB = (1 shl 28)                    or
                                (SDL_PIXELTYPE_INDEX4 shl 24) or
                                (SDL_BITMAPORDER_4321 shl 20) or
                                (0 shl 16)                    or
                                (4 shl 8)                     or
                                (0 shl 0);

    SDL_PIXELFORMAT_INDEX4MSB = (1 shl 28)                    or
                                (SDL_PIXELTYPE_INDEX4 shl 24) or
                                (SDL_BITMAPORDER_1234 shl 20) or
                                (0 shl 16)                    or
                                (4 shl 8)                     or
                                (0 shl 0);

    SDL_PIXELFORMAT_INDEX8 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED8 shl 24)  or
                                (0 shl 20)                      or
                                (0 shl 16)                      or
                                (8 shl 8)                       or
                                (1 shl 0);

    SDL_PIXELFORMAT_RGB332 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED8 shl 24)  or
                                (SDL_PACKEDORDER_XRGB shl 20)   or
                                (SDL_PACKEDLAYOUT_332 shl 16)   or
                                (8 shl 8)                       or
                                (1 shl 0);

    SDL_PIXELFORMAT_RGB444 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_XRGB shl 20)   or
                                (SDL_PACKEDLAYOUT_4444 shl 16)  or
                                (12 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_RGB555 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_XRGB shl 20)   or
                                (SDL_PACKEDLAYOUT_1555 shl 16)  or
                                (15 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_BGR555 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_XBGR shl 20)   or
                                (SDL_PACKEDLAYOUT_1555 shl 16)  or
                                (15 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_ARGB4444 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_ARGB shl 20)   or
                                (SDL_PACKEDLAYOUT_4444 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_RGBA4444 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_RGBA shl 20)   or
                                (SDL_PACKEDLAYOUT_4444 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_ABGR4444 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_ABGR shl 20)   or
                                (SDL_PACKEDLAYOUT_4444 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_BGRA4444 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_BGRA shl 20)   or
                                (SDL_PACKEDLAYOUT_4444 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_ARGB1555 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_ARGB shl 20)   or
                                (SDL_PACKEDLAYOUT_1555 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_RGBA5551 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_RGBA shl 20)   or
                                (SDL_PACKEDLAYOUT_5551 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_ABGR1555 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_ABGR shl 20)   or
                                (SDL_PACKEDLAYOUT_1555 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_BGRA5551 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_BGRA shl 20)   or
                                (SDL_PACKEDLAYOUT_5551 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_RGB565 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_XRGB shl 20)   or
                                (SDL_PACKEDLAYOUT_565 shl 16)   or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_BGR565 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED16 shl 24) or
                                (SDL_PACKEDORDER_XBGR shl 20)   or
                                (SDL_PACKEDLAYOUT_1555 shl 16)  or
                                (16 shl 8)                      or
                                (2 shl 0);

    SDL_PIXELFORMAT_RGB24 =     (1 shl 28)                      or
                                (SDL_PIXELTYPE_ARRAYU8 shl 24)  or
                                (SDL_ARRAYORDER_RGB shl 20)     or
                                (0 shl 16)                      or
                                (24 shl 8)                      or
                                (3 shl 0);

    SDL_PIXELFORMAT_BGR24 =     (1 shl 28)                      or
                                (SDL_PIXELTYPE_ARRAYU8 shl 24)  or
                                (SDL_ARRAYORDER_BGR shl 20)     or
                                (0 shl 16)                      or
                                (24 shl 8)                      or
                                (3 shl 0);

    SDL_PIXELFORMAT_RGB888 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_XRGB shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (24 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_RGBX8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_RGBX shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (24 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_BGR888 =    (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_XBGR shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (24 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_BGRX8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_BGRX shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (24 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_ARGB8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_ARGB shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (32 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_RGBA8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_RGBA shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (32 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_ABGR8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_ABGR shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (32 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_BGRA8888 =  (1 shl 28)                      or
                                (SDL_PIXELTYPE_PACKED32 shl 24) or
                                (SDL_PACKEDORDER_RGBX shl 20)   or
                                (SDL_PACKEDLAYOUT_8888 shl 16)  or
                                (32 shl 8)                      or
                                (4 shl 0);

    SDL_PIXELFORMAT_ARGB2101010 = (1 shl 28)                       or
                                  (SDL_PIXELTYPE_PACKED32 shl 24)  or
                                  (SDL_PACKEDORDER_ARGB shl 20)    or
                                  (SDL_PACKEDLAYOUT_2101010 shl 16)or
                                  (32 shl 8)                       or
                                  (4 shl 0);

    (* Aliases for RGBA byte arrays of color data, for the current platform *)
    {$IFDEF FPC}
      {$IF DEFINED(ENDIAN_LITTLE)}
        SDL_PIXELFORMAT_RGBA32 = SDL_PIXELFORMAT_ABGR8888;
        SDL_PIXELFORMAT_ARGB32 = SDL_PIXELFORMAT_BGRA8888;
        SDL_PIXELFORMAT_BGRA32 = SDL_PIXELFORMAT_ARGB8888;
        SDL_PIXELFORMAT_ABGR32 = SDL_PIXELFORMAT_RGBA8888;
      {$ELSEIF DEFINED(ENDIAN_BIG)}
        SDL_PIXELFORMAT_RGBA32 = SDL_PIXELFORMAT_RGBA8888;
        SDL_PIXELFORMAT_ARGB32 = SDL_PIXELFORMAT_ARGB8888;
        SDL_PIXELFORMAT_BGRA32 = SDL_PIXELFORMAT_BGRA8888;
        SDL_PIXELFORMAT_ABGR32 = SDL_PIXELFORMAT_ABGR8888;
      {$ELSE}
        {$FATAL Cannot determine endianness.}
      {$IFEND}
    {$ENDIF}

    {**< Planar mode: Y + V + U  (3 planes) *}
    SDL_PIXELFORMAT_YV12 = (cuint32('Y')       ) or
                           (cuint32('V') shl  8) or
                           (cuint32('1') shl 16) or
                           (cuint32('2') shl 24);
    {**< Planar mode: Y + U + V  (3 planes) *}
    SDL_PIXELFORMAT_IYUV = (cuint32('I')       ) or
                           (cuint32('Y') shl  8) or
                           (cuint32('U') shl 16) or
                           (cuint32('V') shl 24);
    {**< Packed mode: Y0+U0+Y1+V0 (1 plane) *}
    SDL_PIXELFORMAT_YUY2 = (cuint32('Y')       ) or
                           (cuint32('U') shl  8) or
                           (cuint32('Y') shl 16) or
                           (cuint32('2') shl 24);
    {**< Packed mode: U0+Y0+V0+Y1 (1 plane) *}
    SDL_PIXELFORMAT_UYVY = (cuint32('U')       ) or
                           (cuint32('Y') shl  8) or
                           (cuint32('V') shl 16) or
                           (cuint32('Y') shl 24);
    {**< Packed mode: Y0+V0+Y1+U0 (1 plane) *}
    SDL_PIXELFORMAT_YVYU = (cuint32('Y')       ) or
                           (cuint32('V') shl  8) or
                           (cuint32('Y') shl 16) or
                           (cuint32('U') shl 24);
    {**< Planar mode: Y + U/V interleaved  (2 planes) *}
    SDL_PIXELFORMAT_NV12 = (cuint32('N')       ) or
                           (cuint32('V') shl  8) or
                           (cuint32('1') shl 16) or
                           (cuint32('2') shl 24);
    {**< Planar mode: Y + V/U interleaved  (2 planes) *}
    SDL_PIXELFORMAT_NV21 = (cuint32('N')       ) or
                           (cuint32('V') shl  8) or
                           (cuint32('2') shl 16) or
                           (cuint32('1') shl 24);
    {**< Android video texture format *}
    SDL_PIXELFORMAT_EXTERMAL_OES
                         = (cuint32('O')       ) or
                           (cuint32('E') shl  8) or
                           (cuint32('S') shl 16) or
                           (cuint32(' ') shl 24);

type

  {**
   * The bits of this structure can be directly reinterpreted as an integer-packed
   * color which uses the SDL_PIXELFORMAT_RGBA32 format (SDL_PIXELFORMAT_ABGR8888
   * on little-endian systems and SDL_PIXELFORMAT_RGBA8888 on big-endian systems).
   *}
  PPSDL_Color = ^PSDL_Color;
  PSDL_Color = ^TSDL_Color;
  TSDL_Color = record
    r: cuint8;
    g: cuint8;
    b: cuint8;
    a: cuint8;
  end;

  PPSDL_Colour = ^PSDL_Colour;
  PSDL_Colour = ^TSDL_Colour;
  TSDL_Colour = TSDL_Color;

  PPSDL_Palette = ^PSDL_Palette;
  PSDL_Palette = ^TSDL_Palette;
  TSDL_Palette = record
    ncolors: cint;
    colors: PSDL_Color;
    version: cuint32;
    refcount: cint;
  end;

  {**
   *  Everything in the pixel format structure is read-only.
   *}
  PPSDL_PixelFormat = ^PSDL_PixelFormat;
  PSDL_PixelFormat = ^TSDL_PixelFormat;
  TSDL_PixelFormat = record
    format: cuint32;
    palette: PSDL_Palette;
    BitsPerPixel: cuint8;
    BytesPerPixel: cuint8;
    padding: array[0..1] of cuint8;
    Rmask: cuint32;
    Gmask: cuint32;
    Bmask: cuint32;
    Amask: cuint32;
    Rloss: cuint8;
    Gloss: cuint8;
    Bloss: cuint8;
    Aloss: cuint8;
    Rshift: cuint8;
    Gshift: cuint8;
    Bshift: cuint8;
    Ashift: cuint8;
    refcount: cint;
    next: PSDL_PixelFormat;
  end;

{**
 * Get the human readable name of a pixel format.
 *
 * \param format the pixel format to query
 * \returns the human readable name of the specified pixel format or
 *          `SDL_PIXELFORMAT_UNKNOWN` if the format isn't recognized.
 *
 * \since This function is available since SDL 2.0.0.
 *}
function SDL_GetPixelFormatName(format: cuint32): PAnsiChar; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetPixelFormatName' {$ENDIF} {$ENDIF};

{**
 * Convert one of the enumerated pixel formats to a bpp value and RGBA masks.
 *
 * \param format one of the SDL_PixelFormatEnum values
 * \param bpp a bits per pixel value; usually 15, 16, or 32
 * \param Rmask a pointer filled in with the red mask for the format
 * \param Gmask a pointer filled in with the green mask for the format
 * \param Bmask a pointer filled in with the blue mask for the format
 * \param Amask a pointer filled in with the alpha mask for the format
 * \returns SDL_TRUE on success or SDL_FALSE if the conversion wasn't
 *          possible; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_MasksToPixelFormatEnum
 *}
function SDL_PixelFormatEnumToMasks(format: cuint32; bpp: pcint;
  Rmask: pcuint32; Gmask: pcuint32; Bmask: pcuint32; Amask: pcuint32): TSDL_Bool; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_PixelFormatEnumToMasks' {$ENDIF} {$ENDIF};

{**
 * Convert a bpp value and RGBA masks to an enumerated pixel format.
 *
 * This will return `SDL_PIXELFORMAT_UNKNOWN` if the conversion wasn't
 * possible.
 *
 * \param bpp a bits per pixel value; usually 15, 16, or 32
 * \param Rmask the red mask for the format
 * \param Gmask the green mask for the format
 * \param Bmask the blue mask for the format
 * \param Amask the alpha mask for the format
 * \returns one of the SDL_PixelFormatEnum values
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_PixelFormatEnumToMasks
 *}
function SDL_MasksToPixelFormatEnum(bpp: cint; Rmask: cuint32; Gmask: cuint32; Bmask: cuint32; Amask: cuint32): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_MasksToPixelFormatEnum' {$ENDIF} {$ENDIF};

{**
 * Create an SDL_PixelFormat structure corresponding to a pixel format.
 *
 * Returned structure may come from a shared global cache (i.e. not newly
 * allocated), and hence should not be modified, especially the palette. Weird
 * errors such as `Blit combination not supported` may occur.
 *
 * \param pixel_format one of the SDL_PixelFormatEnum values
 * \returns the new SDL_PixelFormat structure or NULL on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_FreeFormat
 *}
function SDL_AllocFormat(pixel_format: cuint32): PSDL_PixelFormat; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_AllocFormat' {$ENDIF} {$ENDIF};

{**
 * Free an SDL_PixelFormat structure allocated by SDL_AllocFormat().
 *
 * \param format the SDL_PixelFormat structure to free
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AllocFormat
 *}
procedure SDL_FreeFormat(format: PSDL_PixelFormat); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FreeFormat' {$ENDIF} {$ENDIF};

{**
 * Create a palette structure with the specified number of color entries.
 *
 * The palette entries are initialized to white.
 *
 * \param ncolors represents the number of color entries in the color palette
 * \returns a new SDL_Palette structure on success or NULL on failure (e.g. if
 *          there wasn't enough memory); call SDL_GetError() for more
 *          information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_FreePalette
 *}
function SDL_AllocPalette(ncolors: cint): PSDL_Palette; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_AllocPalette' {$ENDIF} {$ENDIF};

{**
 * Set the palette for a pixel format structure.
 *
 * \param format the SDL_PixelFormat structure that will use the palette
 * \param palette the SDL_Palette structure that will be used
 * \returns 0 on success or a negative error code on failure; call
 *          SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AllocPalette
 * \sa SDL_FreePalette
 *}
function SDL_SetPixelFormatPalette(format: PSDL_PixelFormat; palette: PSDL_Palette): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetPixelFormatPalette' {$ENDIF} {$ENDIF};

{**
 * Set a range of colors in a palette.
 *
 * \param palette the SDL_Palette structure to modify
 * \param colors an array of SDL_Color structures to copy into the palette
 * \param firstcolor the index of the first palette entry to modify
 * \param ncolors the number of entries to modify
 * \returns 0 on success or a negative error code if not all of the colors
 *          could be set; call SDL_GetError() for more information.
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AllocPalette
 * \sa SDL_CreateRGBSurface
 *}
function SDL_SetPaletteColors(palette: PSDL_Palette; const colors: PSDL_Color; firstcolor: cint; ncolors: cint): cint; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetPaletteColors' {$ENDIF} {$ENDIF};

{**
 * Free a palette created with SDL_AllocPalette().
 *
 * \param palette the SDL_Palette structure to be freed
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_AllocPalette
 *}
procedure SDL_FreePalette(palette: PSDL_Palette); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FreePalette' {$ENDIF} {$ENDIF};

{**
 * Map an RGB triple to an opaque pixel value for a given pixel format.
 *
 * This function maps the RGB color value to the specified pixel format and
 * returns the pixel value best approximating the given RGB color value for
 * the given pixel format.
 *
 * If the format has a palette (8-bit) the index of the closest matching color
 * in the palette will be returned.
 *
 * If the specified pixel format has an alpha component it will be returned as
 * all 1 bits (fully opaque).
 *
 * If the pixel format bpp (color depth) is less than 32-bpp then the unused
 * upper bits of the return value can safely be ignored (e.g., with a 16-bpp
 * format the return value can be assigned to a Uint16, and similarly a Uint8
 * for an 8-bpp format).
 *
 * \param format an SDL_PixelFormat structure describing the pixel format
 * \param r the red component of the pixel in the range 0-255
 * \param g the green component of the pixel in the range 0-255
 * \param b the blue component of the pixel in the range 0-255
 * \returns a pixel value
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetRGB
 * \sa SDL_GetRGBA
 * \sa SDL_MapRGBA
 *}
function SDL_MapRGB(const format: PSDL_PixelFormat; r: cuint8; g: cuint8; b: cuint8): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_MapRGB' {$ENDIF} {$ENDIF};

{**
 * Map an RGBA quadruple to a pixel value for a given pixel format.
 *
 * This function maps the RGBA color value to the specified pixel format and
 * returns the pixel value best approximating the given RGBA color value for
 * the given pixel format.
 *
 * If the specified pixel format has no alpha component the alpha value will
 * be ignored (as it will be in formats with a palette).
 *
 * If the format has a palette (8-bit) the index of the closest matching color
 * in the palette will be returned.
 *
 * If the pixel format bpp (color depth) is less than 32-bpp then the unused
 * upper bits of the return value can safely be ignored (e.g., with a 16-bpp
 * format the return value can be assigned to a Uint16, and similarly a Uint8
 * for an 8-bpp format).
 *
 * \param format an SDL_PixelFormat structure describing the format of the
 *               pixel
 * \param r the red component of the pixel in the range 0-255
 * \param g the green component of the pixel in the range 0-255
 * \param b the blue component of the pixel in the range 0-255
 * \param a the alpha component of the pixel in the range 0-255
 * \returns a pixel value
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetRGB
 * \sa SDL_GetRGBA
 * \sa SDL_MapRGB
 *}
function SDL_MapRGBA(const format: PSDL_PixelFormat; r: cuint8; g: cuint8; b: cuint8; a: cuint8): cuint32; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_MapRGBA' {$ENDIF} {$ENDIF};

{**
 * Get RGB values from a pixel in the specified format.
 *
 * This function uses the entire 8-bit [0..255] range when converting color
 * components from pixel formats with less than 8-bits per RGB component
 * (e.g., a completely white pixel in 16-bit RGB565 format would return [0xff,
 * 0xff, 0xff] not [0xf8, 0xfc, 0xf8]).
 *
 * \param pixel a pixel value
 * \param format an SDL_PixelFormat structure describing the format of the
 *               pixel
 * \param r a pointer filled in with the red component
 * \param g a pointer filled in with the green component
 * \param b a pointer filled in with the blue component
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetRGBA
 * \sa SDL_MapRGB
 * \sa SDL_MapRGBA
 *}
procedure SDL_GetRGB(pixel: cuint32; const format: PSDL_PixelFormat; r: pcuint8; g: pcuint8; b: pcuint8); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetRGB' {$ENDIF} {$ENDIF};

{**
 * Get RGBA values from a pixel in the specified format.
 *
 * This function uses the entire 8-bit [0..255] range when converting color
 * components from pixel formats with less than 8-bits per RGB component
 * (e.g., a completely white pixel in 16-bit RGB565 format would return [0xff,
 * 0xff, 0xff] not [0xf8, 0xfc, 0xf8]).
 *
 * If the surface has no alpha component, the alpha will be returned as 0xff
 * (100% opaque).
 *
 * \param pixel a pixel value
 * \param format an SDL_PixelFormat structure describing the format of the
 *               pixel
 * \param r a pointer filled in with the red component
 * \param g a pointer filled in with the green component
 * \param b a pointer filled in with the blue component
 * \param a a pointer filled in with the alpha component
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_GetRGB
 * \sa SDL_MapRGB
 * \sa SDL_MapRGBA
 *}
procedure SDL_GetRGBA(pixel: cuint32; const format: PSDL_PixelFormat; r: pcuint8; g: pcuint8; b: pcuint8; a: pcuint8); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetRGBA' {$ENDIF} {$ENDIF};

{/**
 * Calculate a 256 entry gamma ramp for a gamma value.
 *
 * \param gamma a gamma value where 0.0 is black and 1.0 is identity
 * \param ramp an array of 256 values filled in with the gamma ramp
 *
 * \since This function is available since SDL 2.0.0.
 *
 * \sa SDL_SetWindowGammaRamp
 *}
procedure SDL_CalculateGammaRamp(gamma: cfloat; ramp: pcuint16); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CalculateGammaRamp' {$ENDIF} {$ENDIF};
