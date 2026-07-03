{ ============================================================================

       OpenGL 4.5 - Headertranslation
       Version 4.5

       Supported environments and targets :
        - (Linux) FreePascal (1.9.3 and up)

==============================================================================

       Copyright (C) DGL-OpenGL-Portteam
       All Rights Reserved

       Obtained through:
         - Delphi OpenGL Community(DGL)   - www.delphigl.com

       Converted and maintained by DGL's OpenGL-Portteam :
         - Bergmann89                     - http://www.bergmann89.de

==============================================================================

  You may retrieve the latest version of this file at the Delphi OpenGL
  Community home page, located at http://www.delphigl.com/

  The contents of this file are used with permission, subject to
  the Mozilla Public License Version 1.1 (the "License"); you may
  not use this file except in compliance with the License. You may
  obtain a copy of the License at
  http://www.mozilla.org/MPL/MPL-1.1.html

  Software distributed under the License is distributed on an
  "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
  implied. See the License for the specific language governing
  rights and limitations under the License.

==============================================================================

  Local origin note (Apus Game Engine, engine5 GLES cleanup, 2026-07-03):
  Vendored from the pristine upstream copy at Work/dglOpenGLES.upstream.pas
  (downloaded 2026-07-03 from the OpenGLCore project,
  https://git.bergmann89.de/opengl/OpenGLCore, MPL-1.1). Local modifications:
  platform library names for MSWINDOWS (ANGLE) and ANDROID (with a
  libGLESv3.so->libGLESv2.so fallback), Windows dynamic loading
  (LoadLibrary/GetProcAddress/FreeLibrary), and an external proc-address
  resolver hook so platform code can supply SDL_GL_GetProcAddress instead of
  the unit dlopen'ing the library itself. iOS is left as a TODO stub (static
  OpenGLES.framework linkage, R-30 work).

============================================================================== }

{ enable OpenGL ES 1.1 Core functions  }
{$DEFINE OPENGLES_CORE_1_1}

{ enable OpenGL ES 2.0 Core functions  }
{$DEFINE OPENGLES_CORE_2_0}

{ enable OpenGL ES 3.0 Core functions  }
{$DEFINE OPENGLES_CORE_3_0}

{ enable OpenGL ES 3.1 Core functions  }
{$DEFINE OPENGLES_CORE_3_1}

{ enable all OpenGL ES extensions }
{$DEFINE OPENGLES_EXTENSIONS}

unit dglOpenGLES;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

// detecting Linux (Android is Linux-based but handled separately below - different lib names)
{$IFDEF linux}
  {$IFNDEF ANDROID}
  {$DEFINE DGL_LINUX}
  {$ENDIF}
{$ENDIF}

{$IFDEF MSWINDOWS}
  {$DEFINE DGL_WINDOWS}
{$ENDIF}

//check if system is supported and set system dependent constants
uses
  sysutils
  {$IFDEF DGL_LINUX}
  , dl
  {$ENDIF}
  {$IFDEF ANDROID}
  , dl
  {$ENDIF}
  {$IFDEF DGL_WINDOWS}
  , Windows
  {$ENDIF}
  ;

{$IF DEFINED(DGL_LINUX)}
const
  LIBNAME_OPENGLES = 'libGLESv2.so';
  LIBNAME_EGL      = 'libEGL.so';

{$ELSEIF DEFINED(ANDROID)}
const
  // primary name; InitOpenGLES falls back to libGLESv2.so if this fails to load
  LIBNAME_OPENGLES = 'libGLESv3.so';
  LIBNAME_OPENGLES_FALLBACK = 'libGLESv2.so';
  LIBNAME_EGL      = 'libEGL.so';

{$ELSEIF DEFINED(DGL_WINDOWS)}
const
  // ANGLE layout (D3D-backed GLES on Windows)
  LIBNAME_OPENGLES = 'libGLESv2.dll';
  LIBNAME_EGL      = 'libEGL.dll';

{$ELSEIF DEFINED(IOS)}
const
  // TODO: iOS - static OpenGLES.framework, no dynamic library to load (R-30)
  LIBNAME_OPENGLES = '';
  LIBNAME_EGL      = '';

{$ELSE}
const
  LIBNAME_OPENGLES = '';
  LIBNAME_EGL      = '';
  {$WARNING 'unknown/unsupported system'}

{$ENDIF}

type
  { External proc-address resolver, e.g. SDL_GL_GetProcAddress. When assigned,
    dglGetProcAddress tries it first, before the built-in dlopen/GetProcAddress
    path. Lets platform code (Apus.Engine.SDLplatform) supply the resolver
    without this unit depending on the SDL headers. }
  TdglExternalProcAddress = function(const aProcName: PAnsiChar): Pointer; cdecl;

var
  dglExternalGetProcAddress: TdglExternalProcAddress = nil;

procedure SetExternalProcAddressResolver(aResolver: TdglExternalProcAddress);

{ ================================================== OpenGL ES ======================================================= }
type
  { Types }
  GLbyte      = Byte;
  GLclampf    = Single;
  GLfixed     = Integer;
  GLclampx    = Integer;
  GLshort     = ShortInt;
  GLubyte     = Byte;
  GLushort    = Word;
  GLvoid      = Pointer;
  GLint64     = Int64;
  GLuint64    = UInt64;
  GLenum      = Cardinal;
  GLuint      = Cardinal;
  GLchar      = AnsiChar;
  GLbitfield  = Cardinal;
  GLint       = Integer;
  GLintptr    = GLint;
  GLboolean   = ByteBool;
  GLsizei     = Integer;
  GLsizeiptr  = GLsizei;
  GLfloat     = Single;
  GLdouble    = Double;

  { Pointers }
  PGLbyte     = ^GLbyte;
  PGLclampf   = ^GLclampf;
  PGLfixed    = ^GLfixed;
  PGLshort    = ^GLshort;
  PGLubyte    = ^GLubyte;
  PGLushort   = ^GLushort;
  PGLvoid     = Pointer;
  PPGLvoid    = ^PGLvoid;
  PGLint64    = ^GLint64;
  PGLuint64   = ^GLuint64;
  PGLenum     = ^GLenum;
  PGLuint     = ^GLuint;
  PGLchar     = ^GLchar;
  PPGLchar    = ^PGLChar;
  PGLbitfield = ^GLbitfield;
  PGLint      = ^GLint;
  PGLboolean  = ^GLboolean;
  PGLsizei    = ^GLsizei;
  PGLfloat    = ^GLfloat;
  PGLdouble   = ^GLdouble;

  { Special }
  GLsync = Pointer;

  { Cutsom }
  TGLvectorub2 = array[0..1] of GLubyte;
  TGLvectorub3 = array[0..2] of GLubyte;
  TGLvectorub4 = array[0..3] of GLubyte;

  TGLvectori2 = array[0..1] of GLint;
  TGLvectori3 = array[0..2] of GLint;
  TGLvectori4 = array[0..3] of GLint;

  TGLvectorui2 = array[0..1] of GLuint;
  TGLvectorui3 = array[0..2] of GLuint;
  TGLvectorui4 = array[0..3] of GLuint;

  TGLvectorf2 = array[0..1] of GLfloat;
  TGLvectorf3 = array[0..2] of GLfloat;
  TGLvectorf4 = array[0..3] of GLfloat;

  TGLvectord2 = array[0..1] of GLdouble;
  TGLvectord3 = array[0..2] of GLdouble;
  TGLvectord4 = array[0..3] of GLdouble;

  TGLvectorp2 = array[0..1] of PGLvoid;
  TGLvectorp3 = array[0..2] of PGLvoid;
  TGLvectorp4 = array[0..3] of PGLvoid;

{$IFDEF OPENGLES_CORE_1_1}
const
{ ============================================== OpenGL ES 1.1 ======================================================= }
{ ClearBufferMask }
  GL_DEPTH_BUFFER_BIT                               = $00000100;
  GL_STENCIL_BUFFER_BIT                             = $00000400;
  GL_COLOR_BUFFER_BIT                               = $00004000;

{ Boolean }
  GL_FALSE                                          = 0;
  GL_TRUE                                           = 1;

{ BeginMode }
  GL_POINTS                                         = $0000;
  GL_LINES                                          = $0001;
  GL_LINE_LOOP                                      = $0002;
  GL_LINE_STRIP                                     = $0003;
  GL_TRIANGLES                                      = $0004;
  GL_TRIANGLE_STRIP                                 = $0005;
  GL_TRIANGLE_FAN                                   = $0006;

{ AlphaFunction }
  GL_NEVER                                          = $0200;
  GL_LESS                                           = $0201;
  GL_EQUAL                                          = $0202;
  GL_LEQUAL                                         = $0203;
  GL_GREATER                                        = $0204;
  GL_NOTEQUAL                                       = $0205;
  GL_GEQUAL                                         = $0206;
  GL_ALWAYS                                         = $0207;

{ BlendingFactorDest }
  GL_ZERO                                           = 0;
  GL_ONE                                            = 1;
  GL_SRC_COLOR                                      = $0300;
  GL_ONE_MINUS_SRC_COLOR                            = $0301;
  GL_SRC_ALPHA                                      = $0302;
  GL_ONE_MINUS_SRC_ALPHA                            = $0303;
  GL_DST_ALPHA                                      = $0304;
  GL_ONE_MINUS_DST_ALPHA                            = $0305;

{ BlendingFactorSrc }
{ GL_ZERO }
{ GL_ONE }
  GL_DST_COLOR                                      = $0306;
  GL_ONE_MINUS_DST_COLOR                            = $0307;
  GL_SRC_ALPHA_SATURATE                             = $0308;
{ GL_SRC_ALPHA }
{ GL_ONE_MINUS_SRC_ALPHA }
{ GL_DST_ALPHA }
{ GL_ONE_MINUS_DST_ALPHA }

{ ClipPlaneName }
  GL_CLIP_PLANE0                                    = $3000;
  GL_CLIP_PLANE1                                    = $3001;
  GL_CLIP_PLANE2                                    = $3002;
  GL_CLIP_PLANE3                                    = $3003;
  GL_CLIP_PLANE4                                    = $3004;
  GL_CLIP_PLANE5                                    = $3005;

{ ColorMaterialFace }
{ GL_FRONT_AND_BACK }

{ ColorMaterialParameter }
{ GL_AMBIENT_AND_DIFFUSE }

{ ColorPointerType }
{ GL_UNSIGNED_BYTE }
{ GL_FLOAT }
{ GL_FIXED }

{ CullFaceMode }
  GL_FRONT                                          = $0404;
  GL_BACK                                           = $0405;
  GL_FRONT_AND_BACK                                 = $0408;

{ DepthFunction }
{ GL_NEVER }
{ GL_LESS }
{ GL_EQUAL }
{ GL_LEQUAL }
{ GL_GREATER }
{ GL_NOTEQUAL }
{ GL_GEQUAL }
{ GL_ALWAYS }

{ EnableCap }
  GL_FOG                                            = $0B60;
  GL_LIGHTING                                       = $0B50;
  GL_TEXTURE_2D                                     = $0DE1;
  GL_CULL_FACE                                      = $0B44;
  GL_ALPHA_TEST                                     = $0BC0;
  GL_BLEND                                          = $0BE2;
  GL_COLOR_LOGIC_OP                                 = $0BF2;
  GL_DITHER                                         = $0BD0;
  GL_STENCIL_TEST                                   = $0B90;
  GL_DEPTH_TEST                                     = $0B71;
{ GL_LIGHT0 }
{ GL_LIGHT1 }
{ GL_LIGHT2 }
{ GL_LIGHT3 }
{ GL_LIGHT4 }
{ GL_LIGHT5 }
{ GL_LIGHT6 }
{ GL_LIGHT7 }
  GL_POINT_SMOOTH                                   = $0B10;
  GL_LINE_SMOOTH                                    = $0B20;
  GL_SCISSOR_TEST                                   = $0C11;
  GL_COLOR_MATERIAL                                 = $0B57;
  GL_NORMALIZE                                      = $0BA1;
  GL_RESCALE_NORMAL                                 = $803A;
  GL_POLYGON_OFFSET_FILL                            = $8037;
  GL_VERTEX_ARRAY                                   = $8074;
  GL_NORMAL_ARRAY                                   = $8075;
  GL_COLOR_ARRAY                                    = $8076;
  GL_TEXTURE_COORD_ARRAY                            = $8078;
  GL_MULTISAMPLE                                    = $809D;
  GL_SAMPLE_ALPHA_TO_COVERAGE                       = $809E;
  GL_SAMPLE_ALPHA_TO_ONE                            = $809F;
  GL_SAMPLE_COVERAGE                                = $80A0;

{ ErrorCode }
  GL_NO_ERROR                                       = 0;
  GL_INVALID_ENUM                                   = $0500;
  GL_INVALID_VALUE                                  = $0501;
  GL_INVALID_OPERATION                              = $0502;
  GL_STACK_OVERFLOW                                 = $0503;
  GL_STACK_UNDERFLOW                                = $0504;
  GL_OUT_OF_MEMORY                                  = $0505;

{ FogMode }
{ GL_LINEAR }
  GL_EXP                                            = $0800;
  GL_EXP2                                           = $0801;

{ FogParameter }
  GL_FOG_DENSITY                                    = $0B62;
  GL_FOG_START                                      = $0B63;
  GL_FOG_END                                        = $0B64;
  GL_FOG_MODE                                       = $0B65;
  GL_FOG_COLOR                                      = $0B66;

{ FrontFaceDirection }
  GL_CW                                             = $0900;
  GL_CCW                                            = $0901;

{ GetPName }
  GL_CURRENT_COLOR                                  = $0B00;
  GL_CURRENT_NORMAL                                 = $0B02;
  GL_CURRENT_TEXTURE_COORDS                         = $0B03;
  GL_POINT_SIZE                                     = $0B11;
  GL_POINT_SIZE_MIN                                 = $8126;
  GL_POINT_SIZE_MAX                                 = $8127;
  GL_POINT_FADE_THRESHOLD_SIZE                      = $8128;
  GL_POINT_DISTANCE_ATTENUATION                     = $8129;
  GL_SMOOTH_POINT_SIZE_RANGE                        = $0B12;
  GL_LINE_WIDTH                                     = $0B21;
  GL_SMOOTH_LINE_WIDTH_RANGE                        = $0B22;
  GL_ALIASED_POINT_SIZE_RANGE                       = $846D;
  GL_ALIASED_LINE_WIDTH_RANGE                       = $846E;
  GL_CULL_FACE_MODE                                 = $0B45;
  GL_FRONT_FACE                                     = $0B46;
  GL_SHADE_MODEL                                    = $0B54;
  GL_DEPTH_RANGE                                    = $0B70;
  GL_DEPTH_WRITEMASK                                = $0B72;
  GL_DEPTH_CLEAR_VALUE                              = $0B73;
  GL_DEPTH_FUNC                                     = $0B74;
  GL_STENCIL_CLEAR_VALUE                            = $0B91;
  GL_STENCIL_FUNC                                   = $0B92;
  GL_STENCIL_VALUE_MASK                             = $0B93;
  GL_STENCIL_FAIL                                   = $0B94;
  GL_STENCIL_PASS_DEPTH_FAIL                        = $0B95;
  GL_STENCIL_PASS_DEPTH_PASS                        = $0B96;
  GL_STENCIL_REF                                    = $0B97;
  GL_STENCIL_WRITEMASK                              = $0B98;
  GL_MATRIX_MODE                                    = $0BA0;
  GL_VIEWPORT                                       = $0BA2;
  GL_MODELVIEW_STACK_DEPTH                          = $0BA3;
  GL_PROJECTION_STACK_DEPTH                         = $0BA4;
  GL_TEXTURE_STACK_DEPTH                            = $0BA5;
  GL_MODELVIEW_MATRIX                               = $0BA6;
  GL_PROJECTION_MATRIX                              = $0BA7;
  GL_TEXTURE_MATRIX                                 = $0BA8;
  GL_ALPHA_TEST_FUNC                                = $0BC1;
  GL_ALPHA_TEST_REF                                 = $0BC2;
  GL_BLEND_DST                                      = $0BE0;
  GL_BLEND_SRC                                      = $0BE1;
  GL_LOGIC_OP_MODE                                  = $0BF0;
  GL_SCISSOR_BOX                                    = $0C10;
  GL_COLOR_CLEAR_VALUE                              = $0C22;
  GL_COLOR_WRITEMASK                                = $0C23;
  GL_UNPACK_ALIGNMENT                               = $0CF5;
  GL_PACK_ALIGNMENT                                 = $0D05;
  GL_MAX_LIGHTS                                     = $0D31;
  GL_MAX_CLIP_PLANES                                = $0D32;
  GL_MAX_TEXTURE_SIZE                               = $0D33;
  GL_MAX_MODELVIEW_STACK_DEPTH                      = $0D36;
  GL_MAX_PROJECTION_STACK_DEPTH                     = $0D38;
  GL_MAX_TEXTURE_STACK_DEPTH                        = $0D39;
  GL_MAX_VIEWPORT_DIMS                              = $0D3A;
  GL_MAX_TEXTURE_UNITS                              = $84E2;
  GL_SUBPIXEL_BITS                                  = $0D50;
  GL_RED_BITS                                       = $0D52;
  GL_GREEN_BITS                                     = $0D53;
  GL_BLUE_BITS                                      = $0D54;
  GL_ALPHA_BITS                                     = $0D55;
  GL_DEPTH_BITS                                     = $0D56;
  GL_STENCIL_BITS                                   = $0D57;
  GL_POLYGON_OFFSET_UNITS                           = $2A00;
  GL_POLYGON_OFFSET_FACTOR                          = $8038;
  GL_TEXTURE_BINDING_2D                             = $8069;
  GL_VERTEX_ARRAY_SIZE                              = $807A;
  GL_VERTEX_ARRAY_TYPE                              = $807B;
  GL_VERTEX_ARRAY_STRIDE                            = $807C;
  GL_NORMAL_ARRAY_TYPE                              = $807E;
  GL_NORMAL_ARRAY_STRIDE                            = $807F;
  GL_COLOR_ARRAY_SIZE                               = $8081;
  GL_COLOR_ARRAY_TYPE                               = $8082;
  GL_COLOR_ARRAY_STRIDE                             = $8083;
  GL_TEXTURE_COORD_ARRAY_SIZE                       = $8088;
  GL_TEXTURE_COORD_ARRAY_TYPE                       = $8089;
  GL_TEXTURE_COORD_ARRAY_STRIDE                     = $808A;
  GL_VERTEX_ARRAY_POINTER                           = $808E;
  GL_NORMAL_ARRAY_POINTER                           = $808F;
  GL_COLOR_ARRAY_POINTER                            = $8090;
  GL_TEXTURE_COORD_ARRAY_POINTER                    = $8092;
  GL_SAMPLE_BUFFERS                                 = $80A8;
  GL_SAMPLES                                        = $80A9;
  GL_SAMPLE_COVERAGE_VALUE                          = $80AA;
  GL_SAMPLE_COVERAGE_INVERT                         = $80AB;

{ GetTextureParameter }
{ GL_TEXTURE_MAG_FILTER }
{ GL_TEXTURE_MIN_FILTER }
{ GL_TEXTURE_WRAP_S }
{ GL_TEXTURE_WRAP_T }

  GL_NUM_COMPRESSED_TEXTURE_FORMATS                 = $86A2;
  GL_COMPRESSED_TEXTURE_FORMATS                     = $86A3;

{ HintMode }
  GL_DONT_CARE                                      = $1100;
  GL_FASTEST                                        = $1101;
  GL_NICEST                                         = $1102;

{ HintTarget }
  GL_PERSPECTIVE_CORRECTION_HINT                    = $0C50;
  GL_POINT_SMOOTH_HINT                              = $0C51;
  GL_LINE_SMOOTH_HINT                               = $0C52;
  GL_FOG_HINT                                       = $0C54;
  GL_GENERATE_MIPMAP_HINT                           = $8192;

{ LightModelParameter }
  GL_LIGHT_MODEL_AMBIENT                            = $0B53;
  GL_LIGHT_MODEL_TWO_SIDE                           = $0B52;

{ LightParameter }
  GL_AMBIENT                                        = $1200;
  GL_DIFFUSE                                        = $1201;
  GL_SPECULAR                                       = $1202;
  GL_POSITION                                       = $1203;
  GL_SPOT_DIRECTION                                 = $1204;
  GL_SPOT_EXPONENT                                  = $1205;
  GL_SPOT_CUTOFF                                    = $1206;
  GL_CONSTANT_ATTENUATION                           = $1207;
  GL_LINEAR_ATTENUATION                             = $1208;
  GL_QUADRATIC_ATTENUATION                          = $1209;

{ DataType }
  GL_BYTE                                           = $1400;
  GL_UNSIGNED_BYTE                                  = $1401;
  GL_SHORT                                          = $1402;
  GL_UNSIGNED_SHORT                                 = $1403;
  GL_FLOAT                                          = $1406;
  GL_FIXED                                          = $140C;

{ LogicOp }
  GL_CLEAR                                          = $1500;
  GL_AND                                            = $1501;
  GL_AND_REVERSE                                    = $1502;
  GL_COPY                                           = $1503;
  GL_AND_INVERTED                                   = $1504;
  GL_NOOP                                           = $1505;
  GL_XOR                                            = $1506;
  GL_OR                                             = $1507;
  GL_NOR                                            = $1508;
  GL_EQUIV                                          = $1509;
  GL_INVERT                                         = $150A;
  GL_OR_REVERSE                                     = $150B;
  GL_COPY_INVERTED                                  = $150C;
  GL_OR_INVERTED                                    = $150D;
  GL_NAND                                           = $150E;
  GL_SET                                            = $150F;

{ MaterialFace }
{ GL_FRONT_AND_BACK }

{ MaterialParameter }
  GL_EMISSION                                       = $1600;
  GL_SHININESS                                      = $1601;
  GL_AMBIENT_AND_DIFFUSE                            = $1602;
{ GL_AMBIENT }
{ GL_DIFFUSE }
{ GL_SPECULAR }

{ MatrixMode }
  GL_MODELVIEW                                      = $1700;
  GL_PROJECTION                                     = $1701;
  GL_TEXTURE                                        = $1702;

{ NormalPointerType }
{ GL_BYTE }
{ GL_SHORT }
{ GL_FLOAT }
{ GL_FIXED }

{ PixelFormat }
  GL_ALPHA                                          = $1906;
  GL_RGB                                            = $1907;
  GL_RGBA                                           = $1908;
  GL_LUMINANCE                                      = $1909;
  GL_LUMINANCE_ALPHA                                = $190A;

{ PixelType }
{ GL_UNSIGNED_BYTE }
  GL_UNSIGNED_SHORT_4_4_4_4                         = $8033;
  GL_UNSIGNED_SHORT_5_5_5_1                         = $8034;
  GL_UNSIGNED_SHORT_5_6_5                           = $8363;

{ ShadingModel }
  GL_FLAT                                           = $1D00;
  GL_SMOOTH                                         = $1D01;

{ StencilFunction }
{ GL_NEVER }
{ GL_LESS }
{ GL_EQUAL }
{ GL_LEQUAL }
{ GL_GREATER }
{ GL_NOTEQUAL }
{ GL_GEQUAL }
{ GL_ALWAYS }

{ StencilOp }
{ GL_ZERO }
  GL_KEEP                                           = $1E00;
  GL_REPLACE                                        = $1E01;
  GL_INCR                                           = $1E02;
  GL_DECR                                           = $1E03;
{ GL_INVERT }

{ StringName }
  GL_VENDOR                                         = $1F00;
  GL_RENDERER                                       = $1F01;
  GL_VERSION                                        = $1F02;
  GL_EXTENSIONS                                     = $1F03;

{ TexCoordPointerType }
{ GL_SHORT }
{ GL_FLOAT }
{ GL_FIXED }
{ GL_BYTE }

{ TextureEnvMode }
  GL_MODULATE                                       = $2100;
  GL_DECAL                                          = $2101;
{ GL_BLEND }
  GL_ADD                                            = $0104;
{ GL_REPLACE }

{ TextureEnvParameter }
  GL_TEXTURE_ENV_MODE                               = $2200;
  GL_TEXTURE_ENV_COLOR                              = $2201;

{ TextureEnvTarget }
  GL_TEXTURE_ENV                                    = $2300;

{ TextureMagFilter }
  GL_NEAREST                                        = $2600;
  GL_LINEAR                                         = $2601;

{ TextureMinFilter }
{ GL_NEAREST }
{ GL_LINEAR }
  GL_NEAREST_MIPMAP_NEAREST                         = $2700;
  GL_LINEAR_MIPMAP_NEAREST                          = $2701;
  GL_NEAREST_MIPMAP_LINEAR                          = $2702;
  GL_LINEAR_MIPMAP_LINEAR                           = $2703;

{ TextureParameterName }
  GL_TEXTURE_MAG_FILTER                             = $2800;
  GL_TEXTURE_MIN_FILTER                             = $2801;
  GL_TEXTURE_WRAP_S                                 = $2802;
  GL_TEXTURE_WRAP_T                                 = $2803;
  GL_GENERATE_MIPMAP                                = $8191;

{ TextureTarget }
{ GL_TEXTURE_2D }

{ TextureUnit }
  GL_TEXTURE0                                       = $84C0;
  GL_TEXTURE1                                       = $84C1;
  GL_TEXTURE2                                       = $84C2;
  GL_TEXTURE3                                       = $84C3;
  GL_TEXTURE4                                       = $84C4;
  GL_TEXTURE5                                       = $84C5;
  GL_TEXTURE6                                       = $84C6;
  GL_TEXTURE7                                       = $84C7;
  GL_TEXTURE8                                       = $84C8;
  GL_TEXTURE9                                       = $84C9;
  GL_TEXTURE10                                      = $84CA;
  GL_TEXTURE11                                      = $84CB;
  GL_TEXTURE12                                      = $84CC;
  GL_TEXTURE13                                      = $84CD;
  GL_TEXTURE14                                      = $84CE;
  GL_TEXTURE15                                      = $84CF;
  GL_TEXTURE16                                      = $84D0;
  GL_TEXTURE17                                      = $84D1;
  GL_TEXTURE18                                      = $84D2;
  GL_TEXTURE19                                      = $84D3;
  GL_TEXTURE20                                      = $84D4;
  GL_TEXTURE21                                      = $84D5;
  GL_TEXTURE22                                      = $84D6;
  GL_TEXTURE23                                      = $84D7;
  GL_TEXTURE24                                      = $84D8;
  GL_TEXTURE25                                      = $84D9;
  GL_TEXTURE26                                      = $84DA;
  GL_TEXTURE27                                      = $84DB;
  GL_TEXTURE28                                      = $84DC;
  GL_TEXTURE29                                      = $84DD;
  GL_TEXTURE30                                      = $84DE;
  GL_TEXTURE31                                      = $84DF;
  GL_ACTIVE_TEXTURE                                 = $84E0;
  GL_CLIENT_ACTIVE_TEXTURE                          = $84E1;

{ TextureWrapMode }
  GL_REPEAT                                         = $2901;
  GL_CLAMP_TO_EDGE                                  = $812F;

{ VertexPointerType }
{ GL_SHORT }
{ GL_FLOAT }
{ GL_FIXED }
{ GL_BYTE }

{ LightName }
  GL_LIGHT0                                         = $4000;
  GL_LIGHT1                                         = $4001;
  GL_LIGHT2                                         = $4002;
  GL_LIGHT3                                         = $4003;
  GL_LIGHT4                                         = $4004;
  GL_LIGHT5                                         = $4005;
  GL_LIGHT6                                         = $4006;
  GL_LIGHT7                                         = $4007;

{ Buffer Objects }
  GL_ARRAY_BUFFER                                   = $8892;
  GL_ELEMENT_ARRAY_BUFFER                           = $8893;

  GL_ARRAY_BUFFER_BINDING                           = $8894;
  GL_ELEMENT_ARRAY_BUFFER_BINDING                   = $8895;
  GL_VERTEX_ARRAY_BUFFER_BINDING                    = $8896;
  GL_NORMAL_ARRAY_BUFFER_BINDING                    = $8897;
  GL_COLOR_ARRAY_BUFFER_BINDING                     = $8898;
  GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING             = $889A;

  GL_STATIC_DRAW                                    = $88E4;
  GL_DYNAMIC_DRAW                                   = $88E8;

  GL_BUFFER_SIZE                                    = $8764;
  GL_BUFFER_USAGE                                   = $8765;

{ Texture combine + dot3 }
  GL_SUBTRACT                                       = $84E7;
  GL_COMBINE                                        = $8570;
  GL_COMBINE_RGB                                    = $8571;
  GL_COMBINE_ALPHA                                  = $8572;
  GL_RGB_SCALE                                      = $8573;
  GL_ADD_SIGNED                                     = $8574;
  GL_INTERPOLATE                                    = $8575;
  GL_CONSTANT                                       = $8576;
  GL_PRIMARY_COLOR                                  = $8577;
  GL_PREVIOUS                                       = $8578;
  GL_OPERAND0_RGB                                   = $8590;
  GL_OPERAND1_RGB                                   = $8591;
  GL_OPERAND2_RGB                                   = $8592;
  GL_OPERAND0_ALPHA                                 = $8598;
  GL_OPERAND1_ALPHA                                 = $8599;
  GL_OPERAND2_ALPHA                                 = $859A;

  GL_ALPHA_SCALE                                    = $0D1C;

  GL_SRC0_RGB                                       = $8580;
  GL_SRC1_RGB                                       = $8581;
  GL_SRC2_RGB                                       = $8582;
  GL_SRC0_ALPHA                                     = $8588;
  GL_SRC1_ALPHA                                     = $8589;
  GL_SRC2_ALPHA                                     = $858A;

  GL_DOT3_RGB                                       = $86AE;
  GL_DOT3_RGBA                                      = $86AF;
{$ENDIF}

{$IFDEF OPENGLES_CORE_2_0}
const
{ ============================================== OpenGL ES 2.0 ======================================================= }
{ BlendEquationSeparate }
  GL_FUNC_ADD                                       = $8006;
  GL_BLEND_EQUATION                                 = $8009;
  GL_BLEND_EQUATION_RGB                             = $8009;    // same as BLEND_EQUATION
  GL_BLEND_EQUATION_ALPHA                           = $883D;

{ BlendSubtract }
  GL_FUNC_SUBTRACT                                  = $800A;
  GL_FUNC_REVERSE_SUBTRACT                          = $800B;

{ Separate Blend Functions }
  GL_BLEND_DST_RGB                                  = $80C8;
  GL_BLEND_SRC_RGB                                  = $80C9;
  GL_BLEND_DST_ALPHA                                = $80CA;
  GL_BLEND_SRC_ALPHA                                = $80CB;
  GL_CONSTANT_COLOR                                 = $8001;
  GL_ONE_MINUS_CONSTANT_COLOR                       = $8002;
  GL_CONSTANT_ALPHA                                 = $8003;
  GL_ONE_MINUS_CONSTANT_ALPHA                       = $8004;
  GL_BLEND_COLOR                                    = $8005;

{ Buffer Objects }
  GL_STREAM_DRAW                                    = $88E0;
  GL_CURRENT_VERTEX_ATTRIB                          = $8626;

{ GetPName }
  GL_STENCIL_BACK_FUNC                              = $8800;
  GL_STENCIL_BACK_FAIL                              = $8801;
  GL_STENCIL_BACK_PASS_DEPTH_FAIL                   = $8802;
  GL_STENCIL_BACK_PASS_DEPTH_PASS                   = $8803;
  GL_STENCIL_BACK_REF                               = $8CA3;
  GL_STENCIL_BACK_VALUE_MASK                        = $8CA4;
  GL_STENCIL_BACK_WRITEMASK                         = $8CA5;

{ DataType }
  GL_INT                                            = $1404;
  GL_UNSIGNED_INT                                   = $1405;

{ PixelFormat }
  GL_DEPTH_COMPONENT                                = $1902;

{ Shaders }
  GL_FRAGMENT_SHADER                                = $8B30;
  GL_VERTEX_SHADER                                  = $8B31;
  GL_MAX_VERTEX_ATTRIBS                             = $8869;
  GL_MAX_VERTEX_UNIFORM_VECTORS                     = $8DFB;
  GL_MAX_VARYING_VECTORS                            = $8DFC;
  GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS               = $8B4D;
  GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS                 = $8B4C;
  GL_MAX_TEXTURE_IMAGE_UNITS                        = $8872;
  GL_MAX_FRAGMENT_UNIFORM_VECTORS                   = $8DFD;
  GL_SHADER_TYPE                                    = $8B4F;
  GL_DELETE_STATUS                                  = $8B80;
  GL_LINK_STATUS                                    = $8B82;
  GL_VALIDATE_STATUS                                = $8B83;
  GL_ATTACHED_SHADERS                               = $8B85;
  GL_ACTIVE_UNIFORMS                                = $8B86;
  GL_ACTIVE_UNIFORM_MAX_LENGTH                      = $8B87;
  GL_ACTIVE_ATTRIBUTES                              = $8B89;
  GL_ACTIVE_ATTRIBUTE_MAX_LENGTH                    = $8B8A;
  GL_SHADING_LANGUAGE_VERSION                       = $8B8C;
  GL_CURRENT_PROGRAM                                = $8B8D;

{ StencilOp }
  GL_INCR_WRAP                                      = $8507;
  GL_DECR_WRAP                                      = $8508;

{ TextureTarget }
  GL_TEXTURE_CUBE_MAP                               = $8513;
  GL_TEXTURE_BINDING_CUBE_MAP                       = $8514;
  GL_TEXTURE_CUBE_MAP_POSITIVE_X                    = $8515;
  GL_TEXTURE_CUBE_MAP_NEGATIVE_X                    = $8516;
  GL_TEXTURE_CUBE_MAP_POSITIVE_Y                    = $8517;
  GL_TEXTURE_CUBE_MAP_NEGATIVE_Y                    = $8518;
  GL_TEXTURE_CUBE_MAP_POSITIVE_Z                    = $8519;
  GL_TEXTURE_CUBE_MAP_NEGATIVE_Z                    = $851A;
  GL_MAX_CUBE_MAP_TEXTURE_SIZE                      = $851C;

{ TextureWrapMode }
  GL_MIRRORED_REPEAT                                = $8370;

{ Uniform Types }
  GL_FLOAT_VEC2                                     = $8B50;
  GL_FLOAT_VEC3                                     = $8B51;
  GL_FLOAT_VEC4                                     = $8B52;
  GL_INT_VEC2                                       = $8B53;
  GL_INT_VEC3                                       = $8B54;
  GL_INT_VEC4                                       = $8B55;
  GL_BOOL                                           = $8B56;
  GL_BOOL_VEC2                                      = $8B57;
  GL_BOOL_VEC3                                      = $8B58;
  GL_BOOL_VEC4                                      = $8B59;
  GL_FLOAT_MAT2                                     = $8B5A;
  GL_FLOAT_MAT3                                     = $8B5B;
  GL_FLOAT_MAT4                                     = $8B5C;
  GL_SAMPLER_2D                                     = $8B5E;
  GL_SAMPLER_CUBE                                   = $8B60;

{ Vertex Arrays }
  GL_VERTEX_ATTRIB_ARRAY_ENABLED                    = $8622;
  GL_VERTEX_ATTRIB_ARRAY_SIZE                       = $8623;
  GL_VERTEX_ATTRIB_ARRAY_STRIDE                     = $8624;
  GL_VERTEX_ATTRIB_ARRAY_TYPE                       = $8625;
  GL_VERTEX_ATTRIB_ARRAY_NORMALIZED                 = $886A;
  GL_VERTEX_ATTRIB_ARRAY_POINTER                    = $8645;
  GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING             = $889F;

{ Read Format }
  GL_IMPLEMENTATION_COLOR_READ_TYPE                 = $8B9A;
  GL_IMPLEMENTATION_COLOR_READ_FORMAT               = $8B9B;

{ Shader Source }
  GL_COMPILE_STATUS                                 = $8B81;
  GL_INFO_LOG_LENGTH                                = $8B84;
  GL_SHADER_SOURCE_LENGTH                           = $8B88;
  GL_SHADER_COMPILER                                = $8DFA;

{ Shader Binary }
  GL_SHADER_BINARY_FORMATS                          = $8DF8;
  GL_NUM_SHADER_BINARY_FORMATS                      = $8DF9;

{ Shader Precision-Specified Types }
  GL_LOW_FLOAT                                      = $8DF0;
  GL_MEDIUM_FLOAT                                   = $8DF1;
  GL_HIGH_FLOAT                                     = $8DF2;
  GL_LOW_INT                                        = $8DF3;
  GL_MEDIUM_INT                                     = $8DF4;
  GL_HIGH_INT                                       = $8DF5;

{ Framebuffer Object. }
  GL_FRAMEBUFFER                                    = $8D40;
  GL_RENDERBUFFER                                   = $8D41;

  GL_RGBA4                                          = $8056;
  GL_RGB5_A1                                        = $8057;
  GL_RGB565                                         = $8D62;
  GL_DEPTH_COMPONENT16                              = $81A5;
  GL_STENCIL_INDEX                                  = $1901;
  GL_STENCIL_INDEX8                                 = $8D48;

  GL_RENDERBUFFER_WIDTH                             = $8D42;
  GL_RENDERBUFFER_HEIGHT                            = $8D43;
  GL_RENDERBUFFER_INTERNAL_FORMAT                   = $8D44;
  GL_RENDERBUFFER_RED_SIZE                          = $8D50;
  GL_RENDERBUFFER_GREEN_SIZE                        = $8D51;
  GL_RENDERBUFFER_BLUE_SIZE                         = $8D52;
  GL_RENDERBUFFER_ALPHA_SIZE                        = $8D53;
  GL_RENDERBUFFER_DEPTH_SIZE                        = $8D54;
  GL_RENDERBUFFER_STENCIL_SIZE                      = $8D55;

  GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE             = $8CD0;
  GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME             = $8CD1;
  GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL           = $8CD2;
  GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE   = $8CD3;

  GL_COLOR_ATTACHMENT0                              = $8CE0;
  GL_DEPTH_ATTACHMENT                               = $8D00;
  GL_STENCIL_ATTACHMENT                             = $8D20;

  GL_NONE                                           = 0;

  GL_FRAMEBUFFER_COMPLETE                           = $8CD5;
  GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT              = $8CD6;
  GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT      = $8CD7;
  GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS              = $8CD9;
  GL_FRAMEBUFFER_UNSUPPORTED                        = $8CDD;

  GL_FRAMEBUFFER_BINDING                            = $8CA6;
  GL_RENDERBUFFER_BINDING                           = $8CA7;
  GL_MAX_RENDERBUFFER_SIZE                          = $84E8;

  GL_INVALID_FRAMEBUFFER_OPERATION                  = $0506;
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_0}
const
{ ============================================== OpenGL ES 3.0 ======================================================= }
  GL_READ_BUFFER                                    = $0C02;
  GL_UNPACK_ROW_LENGTH                              = $0CF2;
  GL_UNPACK_SKIP_ROWS                               = $0CF3;
  GL_UNPACK_SKIP_PIXELS                             = $0CF4;
  GL_PACK_ROW_LENGTH                                = $0D02;
  GL_PACK_SKIP_ROWS                                 = $0D03;
  GL_PACK_SKIP_PIXELS                               = $0D04;
  GL_COLOR                                          = $1800;
  GL_DEPTH                                          = $1801;
  GL_STENCIL                                        = $1802;
  GL_RED                                            = $1903;
  GL_RGB8                                           = $8051;
  GL_RGBA8                                          = $8058;
  GL_RGB10_A2                                       = $8059;
  GL_TEXTURE_BINDING_3D                             = $806A;
  GL_UNPACK_SKIP_IMAGES                             = $806D;
  GL_UNPACK_IMAGE_HEIGHT                            = $806E;
  GL_TEXTURE_3D                                     = $806F;
  GL_TEXTURE_WRAP_R                                 = $8072;
  GL_MAX_3D_TEXTURE_SIZE                            = $8073;
  GL_UNSIGNED_INT_2_10_10_10_REV                    = $8368;
  GL_MAX_ELEMENTS_VERTICES                          = $80E8;
  GL_MAX_ELEMENTS_INDICES                           = $80E9;
  GL_TEXTURE_MIN_LOD                                = $813A;
  GL_TEXTURE_MAX_LOD                                = $813B;
  GL_TEXTURE_BASE_LEVEL                             = $813C;
  GL_TEXTURE_MAX_LEVEL                              = $813D;
  GL_MIN                                            = $8007;
  GL_MAX                                            = $8008;
  GL_DEPTH_COMPONENT24                              = $81A6;
  GL_MAX_TEXTURE_LOD_BIAS                           = $84FD;
  GL_TEXTURE_COMPARE_MODE                           = $884C;
  GL_TEXTURE_COMPARE_FUNC                           = $884D;
  GL_CURRENT_QUERY                                  = $8865;
  GL_QUERY_RESULT                                   = $8866;
  GL_QUERY_RESULT_AVAILABLE                         = $8867;
  GL_BUFFER_MAPPED                                  = $88BC;
  GL_BUFFER_MAP_POINTER                             = $88BD;
  GL_STREAM_READ                                    = $88E1;
  GL_STREAM_COPY                                    = $88E2;
  GL_STATIC_READ                                    = $88E5;
  GL_STATIC_COPY                                    = $88E6;
  GL_DYNAMIC_READ                                   = $88E9;
  GL_DYNAMIC_COPY                                   = $88EA;
  GL_MAX_DRAW_BUFFERS                               = $8824;
  GL_DRAW_BUFFER0                                   = $8825;
  GL_DRAW_BUFFER1                                   = $8826;
  GL_DRAW_BUFFER2                                   = $8827;
  GL_DRAW_BUFFER3                                   = $8828;
  GL_DRAW_BUFFER4                                   = $8829;
  GL_DRAW_BUFFER5                                   = $882A;
  GL_DRAW_BUFFER6                                   = $882B;
  GL_DRAW_BUFFER7                                   = $882C;
  GL_DRAW_BUFFER8                                   = $882D;
  GL_DRAW_BUFFER9                                   = $882E;
  GL_DRAW_BUFFER10                                  = $882F;
  GL_DRAW_BUFFER11                                  = $8830;
  GL_DRAW_BUFFER12                                  = $8831;
  GL_DRAW_BUFFER13                                  = $8832;
  GL_DRAW_BUFFER14                                  = $8833;
  GL_DRAW_BUFFER15                                  = $8834;
  GL_MAX_FRAGMENT_UNIFORM_COMPONENTS                = $8B49;
  GL_MAX_VERTEX_UNIFORM_COMPONENTS                  = $8B4A;
  GL_SAMPLER_3D                                     = $8B5F;
  GL_SAMPLER_2D_SHADOW                              = $8B62;
  GL_FRAGMENT_SHADER_DERIVATIVE_HINT                = $8B8B;
  GL_PIXEL_PACK_BUFFER                              = $88EB;
  GL_PIXEL_UNPACK_BUFFER                            = $88EC;
  GL_PIXEL_PACK_BUFFER_BINDING                      = $88ED;
  GL_PIXEL_UNPACK_BUFFER_BINDING                    = $88EF;
  GL_FLOAT_MAT2x3                                   = $8B65;
  GL_FLOAT_MAT2x4                                   = $8B66;
  GL_FLOAT_MAT3x2                                   = $8B67;
  GL_FLOAT_MAT3x4                                   = $8B68;
  GL_FLOAT_MAT4x2                                   = $8B69;
  GL_FLOAT_MAT4x3                                   = $8B6A;
  GL_SRGB                                           = $8C40;
  GL_SRGB8                                          = $8C41;
  GL_SRGB8_ALPHA8                                   = $8C43;
  GL_COMPARE_REF_TO_TEXTURE                         = $884E;
  GL_MAJOR_VERSION                                  = $821B;
  GL_MINOR_VERSION                                  = $821C;
  GL_NUM_EXTENSIONS                                 = $821D;
  GL_RGBA32F                                        = $8814;
  GL_RGB32F                                         = $8815;
  GL_RGBA16F                                        = $881A;
  GL_RGB16F                                         = $881B;
  GL_VERTEX_ATTRIB_ARRAY_INTEGER                    = $88FD;
  GL_MAX_ARRAY_TEXTURE_LAYERS                       = $88FF;
  GL_MIN_PROGRAM_TEXEL_OFFSET                       = $8904;
  GL_MAX_PROGRAM_TEXEL_OFFSET                       = $8905;
  GL_MAX_VARYING_COMPONENTS                         = $8B4B;
  GL_TEXTURE_2D_ARRAY                               = $8C1A;
  GL_TEXTURE_BINDING_2D_ARRAY                       = $8C1D;
  GL_R11F_G11F_B10F                                 = $8C3A;
  GL_UNSIGNED_INT_10F_11F_11F_REV                   = $8C3B;
  GL_RGB9_E5                                        = $8C3D;
  GL_UNSIGNED_INT_5_9_9_9_REV                       = $8C3E;
  GL_TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH          = $8C76;
  GL_TRANSFORM_FEEDBACK_BUFFER_MODE                 = $8C7F;
  GL_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS     = $8C80;
  GL_TRANSFORM_FEEDBACK_VARYINGS                    = $8C83;
  GL_TRANSFORM_FEEDBACK_BUFFER_START                = $8C84;
  GL_TRANSFORM_FEEDBACK_BUFFER_SIZE                 = $8C85;
  GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN          = $8C88;
  GL_RASTERIZER_DISCARD                             = $8C89;
  GL_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS  = $8C8A;
  GL_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS        = $8C8B;
  GL_INTERLEAVED_ATTRIBS                            = $8C8C;
  GL_SEPARATE_ATTRIBS                               = $8C8D;
  GL_TRANSFORM_FEEDBACK_BUFFER                      = $8C8E;
  GL_TRANSFORM_FEEDBACK_BUFFER_BINDING              = $8C8F;
  GL_RGBA32UI                                       = $8D70;
  GL_RGB32UI                                        = $8D71;
  GL_RGBA16UI                                       = $8D76;
  GL_RGB16UI                                        = $8D77;
  GL_RGBA8UI                                        = $8D7C;
  GL_RGB8UI                                         = $8D7D;
  GL_RGBA32I                                        = $8D82;
  GL_RGB32I                                         = $8D83;
  GL_RGBA16I                                        = $8D88;
  GL_RGB16I                                         = $8D89;
  GL_RGBA8I                                         = $8D8E;
  GL_RGB8I                                          = $8D8F;
  GL_RED_INTEGER                                    = $8D94;
  GL_RGB_INTEGER                                    = $8D98;
  GL_RGBA_INTEGER                                   = $8D99;
  GL_SAMPLER_2D_ARRAY                               = $8DC1;
  GL_SAMPLER_2D_ARRAY_SHADOW                        = $8DC4;
  GL_SAMPLER_CUBE_SHADOW                            = $8DC5;
  GL_UNSIGNED_INT_VEC2                              = $8DC6;
  GL_UNSIGNED_INT_VEC3                              = $8DC7;
  GL_UNSIGNED_INT_VEC4                              = $8DC8;
  GL_INT_SAMPLER_2D                                 = $8DCA;
  GL_INT_SAMPLER_3D                                 = $8DCB;
  GL_INT_SAMPLER_CUBE                               = $8DCC;
  GL_INT_SAMPLER_2D_ARRAY                           = $8DCF;
  GL_UNSIGNED_INT_SAMPLER_2D                        = $8DD2;
  GL_UNSIGNED_INT_SAMPLER_3D                        = $8DD3;
  GL_UNSIGNED_INT_SAMPLER_CUBE                      = $8DD4;
  GL_UNSIGNED_INT_SAMPLER_2D_ARRAY                  = $8DD7;
  GL_BUFFER_ACCESS_FLAGS                            = $911F;
  GL_BUFFER_MAP_LENGTH                              = $9120;
  GL_BUFFER_MAP_OFFSET                              = $9121;
  GL_DEPTH_COMPONENT32F                             = $8CAC;
  GL_DEPTH32F_STENCIL8                              = $8CAD;
  GL_FLOAT_32_UNSIGNED_INT_24_8_REV                 = $8DAD;
  GL_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING          = $8210;
  GL_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE          = $8211;
  GL_FRAMEBUFFER_ATTACHMENT_RED_SIZE                = $8212;
  GL_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE              = $8213;
  GL_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE               = $8214;
  GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE              = $8215;
  GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE              = $8216;
  GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE            = $8217;
  GL_FRAMEBUFFER_DEFAULT                            = $8218;
  GL_FRAMEBUFFER_UNDEFINED                          = $8219;
  GL_DEPTH_STENCIL_ATTACHMENT                       = $821A;
  GL_DEPTH_STENCIL                                  = $84F9;
  GL_UNSIGNED_INT_24_8                              = $84FA;
  GL_DEPTH24_STENCIL8                               = $88F0;
  GL_UNSIGNED_NORMALIZED                            = $8C17;
  GL_DRAW_FRAMEBUFFER_BINDING                       = $8CA6;
  GL_READ_FRAMEBUFFER                               = $8CA8;
  GL_DRAW_FRAMEBUFFER                               = $8CA9;
  GL_READ_FRAMEBUFFER_BINDING                       = $8CAA;
  GL_RENDERBUFFER_SAMPLES                           = $8CAB;
  GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER           = $8CD4;
  GL_MAX_COLOR_ATTACHMENTS                          = $8CDF;
  GL_COLOR_ATTACHMENT1                              = $8CE1;
  GL_COLOR_ATTACHMENT2                              = $8CE2;
  GL_COLOR_ATTACHMENT3                              = $8CE3;
  GL_COLOR_ATTACHMENT4                              = $8CE4;
  GL_COLOR_ATTACHMENT5                              = $8CE5;
  GL_COLOR_ATTACHMENT6                              = $8CE6;
  GL_COLOR_ATTACHMENT7                              = $8CE7;
  GL_COLOR_ATTACHMENT8                              = $8CE8;
  GL_COLOR_ATTACHMENT9                              = $8CE9;
  GL_COLOR_ATTACHMENT10                             = $8CEA;
  GL_COLOR_ATTACHMENT11                             = $8CEB;
  GL_COLOR_ATTACHMENT12                             = $8CEC;
  GL_COLOR_ATTACHMENT13                             = $8CED;
  GL_COLOR_ATTACHMENT14                             = $8CEE;
  GL_COLOR_ATTACHMENT15                             = $8CEF;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE             = $8D56;
  GL_MAX_SAMPLES                                    = $8D57;
  GL_HALF_FLOAT                                     = $140B;
  GL_MAP_READ_BIT                                   = $0001;
  GL_MAP_WRITE_BIT                                  = $0002;
  GL_MAP_INVALIDATE_RANGE_BIT                       = $0004;
  GL_MAP_INVALIDATE_BUFFER_BIT                      = $0008;
  GL_MAP_FLUSH_EXPLICIT_BIT                         = $0010;
  GL_MAP_UNSYNCHRONIZED_BIT                         = $0020;
  GL_RG                                             = $8227;
  GL_RG_INTEGER                                     = $8228;
  GL_R8                                             = $8229;
  GL_RG8                                            = $822B;
  GL_R16F                                           = $822D;
  GL_R32F                                           = $822E;
  GL_RG16F                                          = $822F;
  GL_RG32F                                          = $8230;
  GL_R8I                                            = $8231;
  GL_R8UI                                           = $8232;
  GL_R16I                                           = $8233;
  GL_R16UI                                          = $8234;
  GL_R32I                                           = $8235;
  GL_R32UI                                          = $8236;
  GL_RG8I                                           = $8237;
  GL_RG8UI                                          = $8238;
  GL_RG16I                                          = $8239;
  GL_RG16UI                                         = $823A;
  GL_RG32I                                          = $823B;
  GL_RG32UI                                         = $823C;
  GL_VERTEX_ARRAY_BINDING                           = $85B5;
  GL_R8_SNORM                                       = $8F94;
  GL_RG8_SNORM                                      = $8F95;
  GL_RGB8_SNORM                                     = $8F96;
  GL_RGBA8_SNORM                                    = $8F97;
  GL_SIGNED_NORMALIZED                              = $8F9C;
  GL_PRIMITIVE_RESTART_FIXED_INDEX                  = $8D69;
  GL_COPY_READ_BUFFER                               = $8F36;
  GL_COPY_WRITE_BUFFER                              = $8F37;
  GL_COPY_READ_BUFFER_BINDING                       = $8F36;
  GL_COPY_WRITE_BUFFER_BINDING                      = $8F37;
  GL_UNIFORM_BUFFER                                 = $8A11;
  GL_UNIFORM_BUFFER_BINDING                         = $8A28;
  GL_UNIFORM_BUFFER_START                           = $8A29;
  GL_UNIFORM_BUFFER_SIZE                            = $8A2A;
  GL_MAX_VERTEX_UNIFORM_BLOCKS                      = $8A2B;
  GL_MAX_FRAGMENT_UNIFORM_BLOCKS                    = $8A2D;
  GL_MAX_COMBINED_UNIFORM_BLOCKS                    = $8A2E;
  GL_MAX_UNIFORM_BUFFER_BINDINGS                    = $8A2F;
  GL_MAX_UNIFORM_BLOCK_SIZE                         = $8A30;
  GL_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS         = $8A31;
  GL_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS       = $8A33;
  GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT                = $8A34;
  GL_ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH           = $8A35;
  GL_ACTIVE_UNIFORM_BLOCKS                          = $8A36;
  GL_UNIFORM_TYPE                                   = $8A37;
  GL_UNIFORM_SIZE                                   = $8A38;
  GL_UNIFORM_NAME_LENGTH                            = $8A39;
  GL_UNIFORM_BLOCK_INDEX                            = $8A3A;
  GL_UNIFORM_OFFSET                                 = $8A3B;
  GL_UNIFORM_ARRAY_STRIDE                           = $8A3C;
  GL_UNIFORM_MATRIX_STRIDE                          = $8A3D;
  GL_UNIFORM_IS_ROW_MAJOR                           = $8A3E;
  GL_UNIFORM_BLOCK_BINDING                          = $8A3F;
  GL_UNIFORM_BLOCK_DATA_SIZE                        = $8A40;
  GL_UNIFORM_BLOCK_NAME_LENGTH                      = $8A41;
  GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS                  = $8A42;
  GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES           = $8A43;
  GL_UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER      = $8A44;
  GL_UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER    = $8A46;
  GL_INVALID_INDEX                                  = $FFFFFFFF;
  GL_MAX_VERTEX_OUTPUT_COMPONENTS                   = $9122;
  GL_MAX_FRAGMENT_INPUT_COMPONENTS                  = $9125;
  GL_MAX_SERVER_WAIT_TIMEOUT                        = $9111;
  GL_OBJECT_TYPE                                    = $9112;
  GL_SYNC_CONDITION                                 = $9113;
  GL_SYNC_STATUS                                    = $9114;
  GL_SYNC_FLAGS                                     = $9115;
  GL_SYNC_FENCE                                     = $9116;
  GL_SYNC_GPU_COMMANDS_COMPLETE                     = $9117;
  GL_UNSIGNALED                                     = $9118;
  GL_SIGNALED                                       = $9119;
  GL_ALREADY_SIGNALED                               = $911A;
  GL_TIMEOUT_EXPIRED                                = $911B;
  GL_CONDITION_SATISFIED                            = $911C;
  GL_WAIT_FAILED                                    = $911D;
  GL_SYNC_FLUSH_COMMANDS_BIT                        = $00000001;
  GL_TIMEOUT_IGNORED                                = $FFFFFFFFFFFFFFFF;
  GL_VERTEX_ATTRIB_ARRAY_DIVISOR                    = $88FE;
  GL_ANY_SAMPLES_PASSED                             = $8C2F;
  GL_ANY_SAMPLES_PASSED_CONSERVATIVE                = $8D6A;
  GL_SAMPLER_BINDING                                = $8919;
  GL_RGB10_A2UI                                     = $906F;
  GL_TEXTURE_SWIZZLE_R                              = $8E42;
  GL_TEXTURE_SWIZZLE_G                              = $8E43;
  GL_TEXTURE_SWIZZLE_B                              = $8E44;
  GL_TEXTURE_SWIZZLE_A                              = $8E45;
  GL_GREEN                                          = $1904;
  GL_BLUE                                           = $1905;
  GL_INT_2_10_10_10_REV                             = $8D9F;
  GL_TRANSFORM_FEEDBACK                             = $8E22;
  GL_TRANSFORM_FEEDBACK_PAUSED                      = $8E23;
  GL_TRANSFORM_FEEDBACK_ACTIVE                      = $8E24;
  GL_TRANSFORM_FEEDBACK_BINDING                     = $8E25;
  GL_PROGRAM_BINARY_RETRIEVABLE_HINT                = $8257;
  GL_PROGRAM_BINARY_LENGTH                          = $8741;
  GL_NUM_PROGRAM_BINARY_FORMATS                     = $87FE;
  GL_PROGRAM_BINARY_FORMATS                         = $87FF;
  GL_COMPRESSED_R11_EAC                             = $9270;
  GL_COMPRESSED_SIGNED_R11_EAC                      = $9271;
  GL_COMPRESSED_RG11_EAC                            = $9272;
  GL_COMPRESSED_SIGNED_RG11_EAC                     = $9273;
  GL_COMPRESSED_RGB8_ETC2                           = $9274;
  GL_COMPRESSED_SRGB8_ETC2                          = $9275;
  GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2       = $9276;
  GL_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2      = $9277;
  GL_COMPRESSED_RGBA8_ETC2_EAC                      = $9278;
  GL_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC               = $9279;
  GL_TEXTURE_IMMUTABLE_FORMAT                       = $912F;
  GL_MAX_ELEMENT_INDEX                              = $8D6B;
  GL_NUM_SAMPLE_COUNTS                              = $9380;
  GL_TEXTURE_IMMUTABLE_LEVELS                       = $82DF;
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_1}
const
{ ============================================== OpenGL ES 3.1 ======================================================= }
  GL_COMPUTE_SHADER                                 = $91B9;
  GL_MAX_COMPUTE_UNIFORM_BLOCKS                     = $91BB;
  GL_MAX_COMPUTE_TEXTURE_IMAGE_UNITS                = $91BC;
  GL_MAX_COMPUTE_IMAGE_UNIFORMS                     = $91BD;
  GL_MAX_COMPUTE_SHARED_MEMORY_SIZE                 = $8262;
  GL_MAX_COMPUTE_UNIFORM_COMPONENTS                 = $8263;
  GL_MAX_COMPUTE_ATOMIC_COUNTER_BUFFERS             = $8264;
  GL_MAX_COMPUTE_ATOMIC_COUNTERS                    = $8265;
  GL_MAX_COMBINED_COMPUTE_UNIFORM_COMPONENTS        = $8266;
  GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS             = $90EB;
  GL_MAX_COMPUTE_WORK_GROUP_COUNT                   = $91BE;
  GL_MAX_COMPUTE_WORK_GROUP_SIZE                    = $91BF;
  GL_COMPUTE_WORK_GROUP_SIZE                        = $8267;
  GL_DISPATCH_INDIRECT_BUFFER                       = $90EE;
  GL_DISPATCH_INDIRECT_BUFFER_BINDING               = $90EF;
  GL_COMPUTE_SHADER_BIT                             = $00000020;
  GL_DRAW_INDIRECT_BUFFER                           = $8F3F;
  GL_DRAW_INDIRECT_BUFFER_BINDING                   = $8F43;
  GL_MAX_UNIFORM_LOCATIONS                          = $826E;
  GL_FRAMEBUFFER_DEFAULT_WIDTH                      = $9310;
  GL_FRAMEBUFFER_DEFAULT_HEIGHT                     = $9311;
  GL_FRAMEBUFFER_DEFAULT_SAMPLES                    = $9313;
  GL_FRAMEBUFFER_DEFAULT_FIXED_SAMPLE_LOCATIONS     = $9314;
  GL_MAX_FRAMEBUFFER_WIDTH                          = $9315;
  GL_MAX_FRAMEBUFFER_HEIGHT                         = $9316;
  GL_MAX_FRAMEBUFFER_SAMPLES                        = $9318;
  GL_UNIFORM                                        = $92E1;
  GL_UNIFORM_BLOCK                                  = $92E2;
  GL_PROGRAM_INPUT                                  = $92E3;
  GL_PROGRAM_OUTPUT                                 = $92E4;
  GL_BUFFER_VARIABLE                                = $92E5;
  GL_SHADER_STORAGE_BLOCK                           = $92E6;
  GL_ATOMIC_COUNTER_BUFFER                          = $92C0;
  GL_TRANSFORM_FEEDBACK_VARYING                     = $92F4;
  GL_ACTIVE_RESOURCES                               = $92F5;
  GL_MAX_NAME_LENGTH                                = $92F6;
  GL_MAX_NUM_ACTIVE_VARIABLES                       = $92F7;
  GL_NAME_LENGTH                                    = $92F9;
  GL_TYPE                                           = $92FA;
  GL_ARRAY_SIZE                                     = $92FB;
  GL_OFFSET                                         = $92FC;
  GL_BLOCK_INDEX                                    = $92FD;
  GL_ARRAY_STRIDE                                   = $92FE;
  GL_MATRIX_STRIDE                                  = $92FF;
  GL_IS_ROW_MAJOR                                   = $9300;
  GL_ATOMIC_COUNTER_BUFFER_INDEX                    = $9301;
  GL_BUFFER_BINDING                                 = $9302;
  GL_BUFFER_DATA_SIZE                               = $9303;
  GL_NUM_ACTIVE_VARIABLES                           = $9304;
  GL_ACTIVE_VARIABLES                               = $9305;
  GL_REFERENCED_BY_VERTEX_SHADER                    = $9306;
  GL_REFERENCED_BY_FRAGMENT_SHADER                  = $930A;
  GL_REFERENCED_BY_COMPUTE_SHADER                   = $930B;
  GL_TOP_LEVEL_ARRAY_SIZE                           = $930C;
  GL_TOP_LEVEL_ARRAY_STRIDE                         = $930D;
  GL_LOCATION                                       = $930E;
  GL_VERTEX_SHADER_BIT                              = $00000001;
  GL_FRAGMENT_SHADER_BIT                            = $00000002;
  GL_ALL_SHADER_BITS                                = $FFFFFFFF;
  GL_PROGRAM_SEPARABLE                              = $8258;
  GL_ACTIVE_PROGRAM                                 = $8259;
  GL_PROGRAM_PIPELINE_BINDING                       = $825A;
  GL_ATOMIC_COUNTER_BUFFER_BINDING                  = $92C1;
  GL_ATOMIC_COUNTER_BUFFER_START                    = $92C2;
  GL_ATOMIC_COUNTER_BUFFER_SIZE                     = $92C3;
  GL_MAX_VERTEX_ATOMIC_COUNTER_BUFFERS              = $92CC;
  GL_MAX_FRAGMENT_ATOMIC_COUNTER_BUFFERS            = $92D0;
  GL_MAX_COMBINED_ATOMIC_COUNTER_BUFFERS            = $92D1;
  GL_MAX_VERTEX_ATOMIC_COUNTERS                     = $92D2;
  GL_MAX_FRAGMENT_ATOMIC_COUNTERS                   = $92D6;
  GL_MAX_COMBINED_ATOMIC_COUNTERS                   = $92D7;
  GL_MAX_ATOMIC_COUNTER_BUFFER_SIZE                 = $92D8;
  GL_MAX_ATOMIC_COUNTER_BUFFER_BINDINGS             = $92DC;
  GL_ACTIVE_ATOMIC_COUNTER_BUFFERS                  = $92D9;
  GL_UNSIGNED_INT_ATOMIC_COUNTER                    = $92DB;
  GL_MAX_IMAGE_UNITS                                = $8F38;
  GL_MAX_VERTEX_IMAGE_UNIFORMS                      = $90CA;
  GL_MAX_FRAGMENT_IMAGE_UNIFORMS                    = $90CE;
  GL_MAX_COMBINED_IMAGE_UNIFORMS                    = $90CF;
  GL_IMAGE_BINDING_NAME                             = $8F3A;
  GL_IMAGE_BINDING_LEVEL                            = $8F3B;
  GL_IMAGE_BINDING_LAYERED                          = $8F3C;
  GL_IMAGE_BINDING_LAYER                            = $8F3D;
  GL_IMAGE_BINDING_ACCESS                           = $8F3E;
  GL_IMAGE_BINDING_FORMAT                           = $906E;
  GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT                = $00000001;
  GL_ELEMENT_ARRAY_BARRIER_BIT                      = $00000002;
  GL_UNIFORM_BARRIER_BIT                            = $00000004;
  GL_TEXTURE_FETCH_BARRIER_BIT                      = $00000008;
  GL_SHADER_IMAGE_ACCESS_BARRIER_BIT                = $00000020;
  GL_COMMAND_BARRIER_BIT                            = $00000040;
  GL_PIXEL_BUFFER_BARRIER_BIT                       = $00000080;
  GL_TEXTURE_UPDATE_BARRIER_BIT                     = $00000100;
  GL_BUFFER_UPDATE_BARRIER_BIT                      = $00000200;
  GL_FRAMEBUFFER_BARRIER_BIT                        = $00000400;
  GL_TRANSFORM_FEEDBACK_BARRIER_BIT                 = $00000800;
  GL_ATOMIC_COUNTER_BARRIER_BIT                     = $00001000;
  GL_ALL_BARRIER_BITS                               = $FFFFFFFF;
  GL_IMAGE_2D                                       = $904D;
  GL_IMAGE_3D                                       = $904E;
  GL_IMAGE_CUBE                                     = $9050;
  GL_IMAGE_2D_ARRAY                                 = $9053;
  GL_INT_IMAGE_2D                                   = $9058;
  GL_INT_IMAGE_3D                                   = $9059;
  GL_INT_IMAGE_CUBE                                 = $905B;
  GL_INT_IMAGE_2D_ARRAY                             = $905E;
  GL_UNSIGNED_INT_IMAGE_2D                          = $9063;
  GL_UNSIGNED_INT_IMAGE_3D                          = $9064;
  GL_UNSIGNED_INT_IMAGE_CUBE                        = $9066;
  GL_UNSIGNED_INT_IMAGE_2D_ARRAY                    = $9069;
  GL_IMAGE_FORMAT_COMPATIBILITY_TYPE                = $90C7;
  GL_IMAGE_FORMAT_COMPATIBILITY_BY_SIZE             = $90C8;
  GL_IMAGE_FORMAT_COMPATIBILITY_BY_CLASS            = $90C9;
  GL_READ_ONLY                                      = $88B8;
  GL_WRITE_ONLY                                     = $88B9;
  GL_READ_WRITE                                     = $88BA;
  GL_SHADER_STORAGE_BUFFER                          = $90D2;
  GL_SHADER_STORAGE_BUFFER_BINDING                  = $90D3;
  GL_SHADER_STORAGE_BUFFER_START                    = $90D4;
  GL_SHADER_STORAGE_BUFFER_SIZE                     = $90D5;
  GL_MAX_VERTEX_SHADER_STORAGE_BLOCKS               = $90D6;
  GL_MAX_FRAGMENT_SHADER_STORAGE_BLOCKS             = $90DA;
  GL_MAX_COMPUTE_SHADER_STORAGE_BLOCKS              = $90DB;
  GL_MAX_COMBINED_SHADER_STORAGE_BLOCKS             = $90DC;
  GL_MAX_SHADER_STORAGE_BUFFER_BINDINGS             = $90DD;
  GL_MAX_SHADER_STORAGE_BLOCK_SIZE                  = $90DE;
  GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT         = $90DF;
  GL_SHADER_STORAGE_BARRIER_BIT                     = $00002000;
  GL_MAX_COMBINED_SHADER_OUTPUT_RESOURCES           = $8F39;
  GL_DEPTH_STENCIL_TEXTURE_MODE                     = $90EA;
  GL_MIN_PROGRAM_TEXTURE_GATHER_OFFSET              = $8E5E;
  GL_MAX_PROGRAM_TEXTURE_GATHER_OFFSET              = $8E5F;
  GL_SAMPLE_POSITION                                = $8E50;
  GL_SAMPLE_MASK                                    = $8E51;
  GL_SAMPLE_MASK_VALUE                              = $8E52;
  GL_TEXTURE_2D_MULTISAMPLE                         = $9100;
  GL_MAX_SAMPLE_MASK_WORDS                          = $8E59;
  GL_MAX_COLOR_TEXTURE_SAMPLES                      = $910E;
  GL_MAX_DEPTH_TEXTURE_SAMPLES                      = $910F;
  GL_MAX_INTEGER_SAMPLES                            = $9110;
  GL_TEXTURE_BINDING_2D_MULTISAMPLE                 = $9104;
  GL_TEXTURE_SAMPLES                                = $9106;
  GL_TEXTURE_FIXED_SAMPLE_LOCATIONS                 = $9107;
  GL_TEXTURE_WIDTH                                  = $1000;
  GL_TEXTURE_HEIGHT                                 = $1001;
  GL_TEXTURE_DEPTH                                  = $8071;
  GL_TEXTURE_INTERNAL_FORMAT                        = $1003;
  GL_TEXTURE_RED_SIZE                               = $805C;
  GL_TEXTURE_GREEN_SIZE                             = $805D;
  GL_TEXTURE_BLUE_SIZE                              = $805E;
  GL_TEXTURE_ALPHA_SIZE                             = $805F;
  GL_TEXTURE_DEPTH_SIZE                             = $884A;
  GL_TEXTURE_STENCIL_SIZE                           = $88F1;
  GL_TEXTURE_SHARED_SIZE                            = $8C3F;
  GL_TEXTURE_RED_TYPE                               = $8C10;
  GL_TEXTURE_GREEN_TYPE                             = $8C11;
  GL_TEXTURE_BLUE_TYPE                              = $8C12;
  GL_TEXTURE_ALPHA_TYPE                             = $8C13;
  GL_TEXTURE_DEPTH_TYPE                             = $8C16;
  GL_TEXTURE_COMPRESSED                             = $86A1;
  GL_SAMPLER_2D_MULTISAMPLE                         = $9108;
  GL_INT_SAMPLER_2D_MULTISAMPLE                     = $9109;
  GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE            = $910A;
  GL_VERTEX_ATTRIB_BINDING                          = $82D4;
  GL_VERTEX_ATTRIB_RELATIVE_OFFSET                  = $82D5;
  GL_VERTEX_BINDING_DIVISOR                         = $82D6;
  GL_VERTEX_BINDING_OFFSET                          = $82D7;
  GL_VERTEX_BINDING_STRIDE                          = $82D8;
  GL_VERTEX_BINDING_BUFFER                          = $8F4F;
  GL_MAX_VERTEX_ATTRIB_RELATIVE_OFFSET              = $82D9;
  GL_MAX_VERTEX_ATTRIB_BINDINGS                     = $82DA;
  GL_MAX_VERTEX_ATTRIB_STRIDE                       = $82E5;
{$ENDIF}

{$IFDEF OPENGLES_CORE_1_1}
type
{ ============================================== OpenGL ES 1.1 ======================================================= }
{ Available only in Common profile }
  TglAlphaFunc                              = procedure(aFunc: GLenum; aRef: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearColor                             = procedure(aRed: GLclampf; aGreen: GLclampf; aBlue: GLclampf; aAlpha: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearDepthf                            = procedure(aDepth: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClipPlanef                             = procedure(aPlane: GLenum; const aEquation: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColor4f                                = procedure(aRed: GLfloat; aGreen: GLfloat; aBlue: GLfloat; aAlpha: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthRangef                            = procedure(aZNear: GLclampf; aZFar: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFogf                                   = procedure(aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFogfv                                  = procedure(aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFrustumf                               = procedure(aLeft: GLfloat; aRight: GLfloat; aBottom: GLfloat; aTop: GLfloat; aZNear: GLfloat; aZFar: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetClipPlanef                          = procedure(aPname: GLenum; aEquation: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFloatv                              = procedure(aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetLightfv                             = procedure(aLight: GLenum; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetMaterialfv                          = procedure(aFace: GLenum; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexEnvfv                            = procedure(aEnv: GLenum; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexParameterfv                      = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightModelf                            = procedure(aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightModelfv                           = procedure(aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightf                                 = procedure(aLight: GLenum; aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightfv                                = procedure(aLight: GLenum; aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLineWidth                              = procedure(aWidth: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLoadMatrixf                            = procedure(const aMatrix: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMaterialf                              = procedure(aFace: GLenum; aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMaterialfv                             = procedure(aFace: GLenum; aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultMatrixf                            = procedure(const aMatrix: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultiTexCoord4f                        = procedure(aTarget: GLenum; s: GLfloat; t: GLfloat; r: GLfloat; q: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglNormal3f                               = procedure(nx: GLfloat; ny: GLfloat; nz: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglOrthof                                 = procedure(aLeft: GLfloat; aRight: GLfloat; aBottom: GLfloat; aTop: GLfloat; aZNear: GLfloat; aZFar: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointParameterf                        = procedure(aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointParameterfv                       = procedure(aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointSize                              = procedure(aSize: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPolygonOffset                          = procedure(aFactor: GLfloat; aUnits: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglRotatef                                = procedure(aAngle: GLfloat; x: GLfloat; y: GLfloat; z: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScalef                                 = procedure(x: GLfloat; y: GLfloat; z: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnvf                                = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnvfv                               = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameterf                          = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameterfv                         = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTranslatef                             = procedure(x: GLfloat; y: GLfloat; z: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

{ Available in both Common and Common-Lite profiles }
  TglActiveTexture                          = procedure(aTexture: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglAlphaFuncx                             = procedure(aFunc: GLenum; aRef: GLclampx); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindBuffer                             = procedure(aTarget: GLenum; aBuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindTexture                            = procedure(aTarget: GLenum; aTexture: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendFunc                              = procedure(aSfactor: GLenum; aDfactor: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBufferData                             = procedure(aTarget: GLenum; aSize: GLsizeiptr; const aData: PGLvoid; aUsage: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBufferSubData                          = procedure(aTarget: GLenum; aOffset: GLintptr; aSize: GLsizeiptr; const aData: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClear                                  = procedure(aMask: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearColorx                            = procedure(aRed: GLclampx; aGreen: GLclampx; aBlue: GLclampx; aAlpha: GLclampx); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearDepthx                            = procedure(aDepth: GLclampx); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearStencil                           = procedure(aStencil: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClientActiveTexture                    = procedure(aTexture: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClipPlanex                             = procedure(aPlane: GLenum; const aEquation: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColor4ub                               = procedure(aRed: GLubyte; aGreen: GLubyte; aBlue: GLubyte; aAlpha: GLubyte); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColor4x                                = procedure(aRed: GLfixed; aGreen: GLfixed; aBlue: GLfixed; aAlpha: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColorMask                              = procedure(aRed: GLboolean; aGreen: GLboolean; aBlue: GLboolean; aAlpha: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColorPointer                           = procedure(aSize: GLint; aType: GLenum; aStride: GLsizei; const aPointer: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexImage2D                   = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aBorder: GLint; aImageSize: GLsizei; const aData: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexSubImage2D                = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aFormat: GLenum; aImageSize: GLsizei; const aData: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyTexImage2D                         = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLenum; x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei; aBorder: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyTexSubImage2D                      = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCullFace                               = procedure(aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteBuffers                          = procedure(n: GLsizei; const aBuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteTextures                         = procedure(n: GLsizei; const aTextures: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthFunc                              = procedure(aFunc: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthMask                              = procedure(aFlag: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthRangex                            = procedure(aZNear: GLclampx; aZFar: GLclampx); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisable                                = procedure(aCap: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisableClientState                     = procedure(aArray: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawArrays                             = procedure(aMode: GLenum; aFirst: GLint; aCount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElements                           = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEnable                                 = procedure(aCap: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEnableClientState                      = procedure(aArray: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFinish                                 = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFlush                                  = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFogx                                   = procedure(aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFogxv                                  = procedure(aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFrontFace                              = procedure(aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFrustumx                               = procedure(aLeft: GLfixed; aRight: GLfixed; aBottom: GLfixed; aTop: GLfixed; aZNear: GLfixed; aZFar: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBooleanv                            = procedure(aPname: GLenum; aParams: PGLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBufferParameteriv                   = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetClipPlanex                          = procedure(aPname: GLenum; aEquation: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenBuffers                             = procedure(n: GLsizei; aBuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenTextures                            = procedure(n: GLsizei; aTextures: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetError                               = function (): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFixedv                              = procedure(aPname: GLenum; aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetIntegerv                            = procedure(aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetLightxv                             = procedure(aLight: GLenum; aPname: GLenum; aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetMaterialxv                          = procedure(aFace: GLenum; aPname: GLenum; aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPointerv                            = procedure(aPname: GLenum; aParams: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetString                              = function (name: GLenum): PGLubyte; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexEnviv                            = procedure(aEnv: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexEnvxv                            = procedure(aEnv: GLenum; aPname: GLenum; aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexParameteriv                      = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexParameterxv                      = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglHint                                   = procedure(aTarget: GLenum; aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsBuffer                               = function (aBuffer: GLuint): GLboolean;                                                {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsEnabled                              = function (aCap: GLenum): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsTexture                              = function (aTexture: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightModelx                            = procedure(aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightModelxv                           = procedure(aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightx                                 = procedure(aLight: GLenum; aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLightxv                                = procedure(aLight: GLenum; aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLineWidthx                             = procedure(aWidth: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLoadIdentity                           = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLoadMatrix                             = procedure(const aMatrix: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLogicOp                                = procedure(aOpcode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMaterialx                              = procedure(aFace: GLenum; aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMaterialxv                             = procedure(aFace: GLenum; aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixMode                             = procedure(aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultMatrixx                            = procedure(const aMatrix: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultiTexCoord4x                        = procedure(aTarget: GLenum; s: GLfixed; t: GLfixed; r: GLfixed; q: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglNormal3x                               = procedure(nx: GLfixed; ny: GLfixed; nz: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglNormalPointer                          = procedure(aType: GLenum; aStride: GLsizei; const aPointer: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglOrthox                                 = procedure(aLeft: GLfixed; aRight: GLfixed; aBottom: GLfixed; aTop: GLfixed; aZNear: GLfixed; aZFar: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPixelStorei                            = procedure(aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointParameterx                        = procedure(aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointParameterxv                       = procedure(aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointSizex                             = procedure(aSize: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPolygonOffsetx                         = procedure(aFactor: GLfixed; aUnits: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPopMatrix                              = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPushMatrix                             = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglReadPixels                             = procedure(x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei; aFormat: GLenum; aType: GLenum; aPixels: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglRotatex                                = procedure(aAngle: GLfixed; x: GLfixed; y: GLfixed; z: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSampleCoverage                         = procedure(aValue: GLclampf; aInvert: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSampleCoveragex                        = procedure(aValue: GLclampx; aInvert: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScalex                                 = procedure(x: GLfixed; y: GLfixed; z: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScissor                                = procedure(x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglShadeModel                             = procedure(aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilFunc                            = procedure(aFunc: GLenum; aRef: GLint; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilMask                            = procedure(aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilOp                              = procedure(aFail: GLenum; aZfail: GLenum; aZpass: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexCoordPointer                        = procedure(aSize: GLint; aType: GLenum; aStride: GLsizei; const aPointer: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnvi                                = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnvx                                = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnviv                               = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexEnvxv                               = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexImage2D                             = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLint; aWidth: GLsizei; aHeight: GLsizei; aBorder: GLint; aFormat: GLenum; aType: GLenum; const aPixels: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameteri                          = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameterx                          = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameteriv                         = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameterxv                         = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexSubImage2D                          = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aFormat: GLenum; aType: GLenum; const aPixels: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTranslatex                             = procedure(x: GLfixed; y: GLfixed; z: GLfixed); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexPointer                          = procedure(aSize: GLint; aType: GLenum; aStride: GLsizei; const aPointer: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglViewport                               = procedure(x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
{$ENDIF}

{$IFDEF OPENGLES_CORE_2_0}
type
{ ============================================== OpenGL ES 2.0 ======================================================= }
  TglAttachShader                           = procedure(aProgram: GLuint; aShader: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindAttribLocation                     = procedure(aProgram: GLuint; aIndex: GLuint; const aName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindFramebuffer                        = procedure(aTarget: GLenum; aFramebuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindRenderbuffer                       = procedure(aTarget: GLenum; aRenderbuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendColor                             = procedure(aRed: GLclampf; aGreen: GLclampf; aBlue: GLclampf; aAlpha: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendEquation                          = procedure( mode : GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendEquationSeparate                  = procedure(aModeRGB: GLenum; aModeAlpha: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendFuncSeparate                      = procedure(aSrcRGB: GLenum; aDstRGB: GLenum; aSrcAlpha: GLenum; aDstAlpha: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCheckFramebufferStatus                 = function (aTarget: GLenum): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompileShader                          = procedure(aShader: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCreateProgram                          = function (): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCreateShader                           = function (aType: GLenum): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteFramebuffers                     = procedure(n: GLsizei; const aFramebuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteProgram                          = procedure(aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteRenderbuffers                    = procedure(n: GLsizei; const aRenderbuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteShader                           = procedure(aShader: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDetachShader                           = procedure(aProgram: GLuint; aShader: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisableVertexAttribArray               = procedure(aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEnableVertexAttribArray                = procedure(aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferRenderbuffer                = procedure(aTarget: GLenum; aAttachment: GLenum; aRenderbuffertarget: GLenum; aRenderbuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferTexture2D                   = procedure(aTarget: GLenum; aAttachment: GLenum; aTextarget: GLenum; aTexture: GLuint; aLevel: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenerateMipmap                         = procedure(aTarget: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenFramebuffers                        = procedure(n: GLsizei; aFramebuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenRenderbuffers                       = procedure(n: GLsizei; aRenderbuffers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetActiveAttrib                        = procedure(aProgram: GLuint; aIndex: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aSize: PGLint; aType: PGLenum; aName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetActiveUniform                       = procedure(aProgram: GLuint; aIndex: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aSize: PGLint; aType: PGLenum; aName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetAttachedShaders                     = procedure(aProgram: GLuint; aMaxcount: GLsizei; aCount: PGLsizei; aShaders: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetAttribLocation                      = function (aProgram: GLuint; const aName: PGLchar): Integer; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFramebufferAttachmentParameteriv    = procedure(aTarget: GLenum; aAttachment: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramiv                           = procedure(aProgram: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramInfoLog                      = procedure(aProgram: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aInfolog: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetRenderbufferParameteriv             = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetShaderiv                            = procedure(aShader: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetShaderInfoLog                       = procedure(aShader: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aInfolog: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetShaderPrecisionFormat               = procedure(aShadertype: GLenum; aPrecisiontype: GLenum; aRange: PGLint; aPrecision: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetShaderSource                        = procedure(aShader: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aSource: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformfv                           = procedure(aProgram: GLuint; aLocation: GLint; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformiv                           = procedure(aProgram: GLuint; aLocation: GLint; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformLocation                     = function (aProgram: GLuint; const aName: PGLchar): Integer; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetVertexAttribfv                      = procedure(aIndex: GLuint; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetVertexAttribiv                      = procedure(aIndex: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetVertexAttribPointerv                = procedure(aIndex: GLuint; aPname: GLenum; aPointer: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsFramebuffer                          = function (aFramebuffer: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsProgram                              = function (aProgram: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsRenderbuffer                         = function (aRenderbuffer: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsShader                               = function (aShader: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglLinkProgram                            = procedure(aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglReleaseShaderCompiler                  = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglRenderbufferStorage                    = procedure(aTarget: GLenum; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglShaderBinary                           = procedure(n: GLsizei; const aShaders: PGLuint; aBinaryformat: GLenum; const aBinary: PGLvoid; aLength: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglShaderSource                           = procedure(aShader: GLuint; aCount: GLsizei; const aString: PPGLchar; const aLength: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilFuncSeparate                    = procedure(aFace: GLenum; aFunc: GLenum; aRef: GLint; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilMaskSeparate                    = procedure(aFace: GLenum; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilOpSeparate                      = procedure(aFace: GLenum; aFail: GLenum; aZfail: GLenum; aZpass: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1f                              = procedure(aLocation: GLint; x: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1fv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1i                              = procedure(aLocation: GLint; x: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1iv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2f                              = procedure(aLocation: GLint; x: GLfloat; y: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2fv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2i                              = procedure(aLocation: GLint; x: GLint; y: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2iv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3f                              = procedure(aLocation: GLint; x: GLfloat; y: GLfloat; z: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3fv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3i                              = procedure(aLocation: GLint; x: GLint; y: GLint; z: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3iv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4f                              = procedure(aLocation: GLint; x: GLfloat; y: GLfloat; z: GLfloat; w: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4fv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4i                              = procedure(aLocation: GLint; x: GLint; y: GLint; z: GLint; w: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4iv                             = procedure(aLocation: GLint; aCount: GLsizei; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix2fv                       = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix3fv                       = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix4fv                       = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUseProgram                             = procedure(aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglValidateProgram                        = procedure(aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib1f                         = procedure(aIndex: GLuint; x: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib1fv                        = procedure(aIndex: GLuint; const aValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib2f                         = procedure(aIndex: GLuint; x: GLfloat; y: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib2fv                        = procedure(aIndex: GLuint; const aValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib3f                         = procedure(aIndex: GLuint; x: GLfloat; y: GLfloat; z: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib3fv                        = procedure(aIndex: GLuint; const aValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib4f                         = procedure(aIndex: GLuint; x: GLfloat; y: GLfloat; z: GLfloat; w: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttrib4fv                        = procedure(aIndex: GLuint; const aValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribPointer                    = procedure(aIndex: GLuint; aSize: GLint; aType: GLenum; aNormalized: GLboolean; aStride: GLsizei; const aPtr: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_0}
type
{ ============================================== OpenGL ES 3.0 ======================================================= }
  TglReadBuffer                             = procedure(aSrc: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawRangeElements                      = procedure(aMode: GLenum; aStart: GLuint; aEnd: GLuint; aCount: GLsizei; aType: GLenum; const aIndices: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexImage3D                             = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aBorder: GLint; aFormat: GLenum; aType: GLenum; const aPixels: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexSubImage3D                          = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFormat: GLenum; aType: GLenum; const aPixels: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyTexSubImage3D                      = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexImage3D                   = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aBorder: GLint; aImageSize: GLsizei; const aData: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexSubImage3D                = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFormat: GLenum; aImageSize: GLsizei; const aData: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenQueries                             = procedure(n: GLsizei; aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteQueries                          = procedure(n: GLsizei; const aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsQuery                                = function (aId: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBeginQuery                             = procedure(aTarget: GLenum; aId: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndQuery                               = procedure(aTarget: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryiv                             = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryObjectuiv                      = procedure(aId: GLuint; aPname: GLenum; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUnmapBuffer                            = function (aTarget: GLenum): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBufferPointerv                      = procedure(aTarget: GLenum; aPname: GLenum; aParams: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawBuffers                            = procedure(n: GLsizei; const aBuffers: PGLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix2x3fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix3x2fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix2x4fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix4x2fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix3x4fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix4x3fv                     = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlitFramebuffer                        = procedure(srcX0: GLint; srcY0: GLint; srcX1: GLint; srcY1: GLint; dstX0: GLint; dstY0: GLint; dstX1: GLint; dstY1: GLint; aMask: GLbitfield; aFilter: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglRenderbufferStorageMultisample         = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferTextureLayer                = procedure(aTarget: GLenum; aAttachment: GLenum; aTexture: GLuint; aLevel: GLint; aLayer: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMapBufferRange                         = function (aTarget: GLenum; aOffset: GLintptr; aLength: GLsizeiptr; aAccess: GLbitfield): PGLvoid; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFlushMappedBufferRange                 = procedure(aTarget: GLenum; aOffset: GLintptr; aLength: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindVertexArray                        = procedure(aArray: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteVertexArrays                     = procedure(n: GLsizei; const aArrays: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenVertexArrays                        = procedure(n: GLsizei; aArrays: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsVertexArray                          = function (aArray: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetIntegeriv                           = procedure(aTarget: GLenum; aIndex: GLuint; aData: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBeginTransformFeedback                 = procedure(aPrimitiveMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndTransformFeedback                   = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindBufferRange                        = procedure(aTarget: GLenum; aIndex: GLuint; aBuffer: GLuint; aOffset: GLintptr; aSize: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindBufferBase                         = procedure(aTarget: GLenum; aIndex: GLuint; aBuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTransformFeedbackVaryings              = procedure(aProgram: GLuint; aCount: GLsizei; const aVaryings: PPGLchar; aBufferMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTransformFeedbackVarying            = procedure(aProgram: GLuint; aIndex: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aSize: PGLsizei; aType: PGLenum; aName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribIPointer                   = procedure(aIndex: GLuint; aSize: GLint; aType: GLenum; aStride: GLsizei; const aPointer: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetVertexAttribIiv                     = procedure(aIndex: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetVertexAttribIuiv                    = procedure(aIndex: GLuint; aPname: GLenum; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribI4i                        = procedure(aIndex: GLuint; x: GLint; y: GLint; z: GLint; w: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribI4ui                       = procedure(aIndex: GLuint; x: GLuint; y: GLuint; z: GLuint; w: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribI4iv                       = procedure(aIndex: GLuint; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribI4uiv                      = procedure(aIndex: GLuint; const v: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformuiv                          = procedure(aProgram: GLuint; aLocation: GLint; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFragDataLocation                    = function (aProgram: GLuint; const aName: PGLchar): GLint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1ui                             = procedure(aLocation: GLint; v0: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2ui                             = procedure(aLocation: GLint; v0: GLuint; v1: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3ui                             = procedure(aLocation: GLint; v0: GLuint; v1: GLuint; v2: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4ui                             = procedure(aLocation: GLint; v0: GLuint; v1: GLuint; v2: GLuint; v3: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform1uiv                            = procedure(aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform2uiv                            = procedure(aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform3uiv                            = procedure(aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniform4uiv                            = procedure(aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearBufferiv                          = procedure(aBuffer: GLenum; aDrawbuffer: GLint; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearBufferuiv                         = procedure(aBuffer: GLenum; aDrawbuffer: GLint; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearBufferfv                          = procedure(aBuffer: GLenum; aDrawbuffer: GLint; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClearBufferfi                          = procedure(aBuffer: GLenum; aDrawbuffer: GLint; aDepth: GLfloat; aStencil: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetStringi                             = function (aName: GLenum; aIndex: GLuint): PGLubyte; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyBufferSubData                      = procedure(aReadTarget: GLenum; aWriteTarget: GLenum; aReadOffset: GLintptr; aWriteOffset: GLintptr; aSize: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformIndices                      = procedure(aProgram: GLuint; aUniformCount: GLsizei; const aUniformNames: PPGLchar; aUniformIndices: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetActiveUniformsiv                    = procedure(aProgram: GLuint; aUniformCount: GLsizei; const aUniformIndices: PGLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetUniformBlockIndex                   = function (aProgram: GLuint; const aUniformBlockName: PGLchar): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetActiveUniformBlockiv                = procedure(aProgram: GLuint; aUniformBlockIndex: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetActiveUniformBlockName              = procedure(aProgram: GLuint; aUniformBlockIndex: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aUniformBlockName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformBlockBinding                    = procedure(aProgram: GLuint; aUniformBlockIndex: GLuint; aUniformBlockBinding: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawArraysInstanced                    = procedure(aMode: GLenum; aFirst: GLint; aCount: GLsizei; aInstancecount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstanced                  = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: PGLvoid; aInstancecount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFenceSync                              = function (aCondition: GLenum; aFlags: GLbitfield): GLsync; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsSync                                 = function (aSync: GLsync): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteSync                             = procedure(aSync: GLsync); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClientWaitSync                         = function (aSync: GLsync; aFlags: GLbitfield; aTimeout: GLuint64): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglWaitSync                               = procedure(aSync: GLsync; aFlags: GLbitfield; aTimeout: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetInteger64v                          = procedure(aPname: GLenum; aData: PGLint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSynciv                              = procedure(aSync: GLsync; aPname: GLenum; aBufSize: GLsizei; aLength: PGLsizei; aValues: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetInteger64iv                         = procedure(aTarget: GLenum; aIndex: GLuint; aData: PGLint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBufferParameteri64v                 = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenSamplers                            = procedure(aCount: GLsizei; aSamplers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteSamplers                         = procedure(aCount: GLsizei; const aSamplers: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsSampler                              = function (aSampler: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindSampler                            = procedure(aUnit: GLuint; aSampler: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameteri                      = procedure(aSampler: GLuint; aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameteriv                     = procedure(aSampler: GLuint; aPname: GLenum; const aParam: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameterf                      = procedure(aSampler: GLuint; aPname: GLenum; aParam: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameterfv                     = procedure(aSampler: GLuint; aPname: GLenum; const aParam: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSamplerParameteriv                  = procedure(aSampler: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSamplerParameterfv                  = procedure(aSampler: GLuint; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribDivisor                    = procedure(aIndex: GLuint; aDivisor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindTransformFeedback                  = procedure(aTarget: GLenum; aId: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteTransformFeedbacks               = procedure(n: GLsizei; const aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenTransformFeedbacks                  = procedure(n: GLsizei; aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsTransformFeedback                    = function (aId: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPauseTransformFeedback                 = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglResumeTransformFeedback                = procedure(); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramBinary                       = procedure(aProgram: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aBinaryFormat: PGLenum; aBinary: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramBinary                          = procedure(aProgram: GLuint; aBinaryFormat: GLenum; const aBinary: PGLvoid; aLength: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramParameteri                      = procedure(aProgram: GLuint; aPname: GLenum; aValue: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglInvalidateFramebuffer                  = procedure(aTarget: GLenum; aNumAttachments: GLsizei; const aAttachments: PGLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglInvalidateSubFramebuffer               = procedure(aTarget: GLenum; aNumAttachments: GLsizei; const aAttachments: PGLenum; x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexStorage2D                           = procedure(aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexStorage3D                           = procedure(aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetInternalformativ                    = procedure(aTarget: GLenum; aInternalformat: GLenum; aPname: GLenum; aBufSize: GLsizei; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_1}
type
{ ============================================== OpenGL ES 3.1 ======================================================= }
  TglDispatchCompute                        = procedure(aNumGroupsX: GLuint; aNumGroupsY: GLuint; aNumGroupsZ: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDispatchComputeIndirect                = procedure(aIndirect: GLintptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawArraysIndirect                     = procedure(aMode: GLenum; const aIndirect: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsIndirect                   = procedure(aMode: GLenum; aType: GLenum; const aIndirect: PGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferParameteri                  = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFramebufferParameteriv              = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramInterfaceiv                  = procedure(aProgram: GLuint; aProgramInterface: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramResourceIndex                = function (aProgram: GLuint; aProgramInterface: GLenum; const aName: PGLchar): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramResourceName                 = procedure(aProgram: GLuint; aProgramInterface: GLenum; aIndex: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aName: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramResourceiv                   = procedure(aProgram: GLuint; aProgramInterface: GLenum; aIndex: GLuint; aPropCount: GLsizei; const aProps: PGLenum; aBufSize: GLsizei; aLength: PGLsizei; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramResourceLocation             = function (aProgram: GLuint; aProgramInterface: GLenum; const aName: PGLchar): GLint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUseProgramStages                       = procedure(aPipeline: GLuint; aStages: GLbitfield; aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglActiveShaderProgram                    = procedure(aPipeline: GLuint; aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCreateShaderProgramv                   = function (aType: GLenum; aCount: GLsizei; const aStrings: PPGLchar): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindProgramPipeline                    = procedure(aPipeline: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteProgramPipelines                 = procedure(n: GLsizei; const aPipelines: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenProgramPipelines                    = procedure(n: GLsizei; aPipelines: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsProgramPipeline                      = function (aPipeline: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramPipelineiv                   = procedure(aPipeline: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1i                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2i                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLint; v1: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3i                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLint; v1: GLint; v2: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4i                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLint; v1: GLint; v2: GLint; v3: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1ui                      = procedure(aProgram: GLuint; aLocation: GLint; v0: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2ui                      = procedure(aProgram: GLuint; aLocation: GLint; v0: GLuint; v1: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3ui                      = procedure(aProgram: GLuint; aLocation: GLint; v0: GLuint; v1: GLuint; v2: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4ui                      = procedure(aProgram: GLuint; aLocation: GLint; v0: GLuint; v1: GLuint; v2: GLuint; v3: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1f                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2f                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLfloat; v1: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3f                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLfloat; v1: GLfloat; v2: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4f                       = procedure(aProgram: GLuint; aLocation: GLint; v0: GLfloat; v1: GLfloat; v2: GLfloat; v3: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1iv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2iv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3iv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4iv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1uiv                     = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2uiv                     = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3uiv                     = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4uiv                     = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1fv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2fv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3fv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4fv                      = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2fv                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3fv                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4fv                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2x3fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3x2fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2x4fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4x2fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3x4fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4x3fv              = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglValidateProgramPipeline                = procedure(aPipeline: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramPipelineInfoLog              = procedure(aPipeline: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aInfoLog: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindImageTexture                       = procedure(aUnit: GLuint; aTexture: GLuint; aLevel: GLint; aLayered: GLboolean; aLayer: GLint; aAccess: GLenum; aFormat: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBooleaniv                           = procedure(aTarget: GLenum; aIndex: GLuint; aData: PGLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMemoryBarrier                          = procedure(aBarriers: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMemoryBarrierByRegion                  = procedure(aBarriers: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexStorage2DMultisample                = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aFixedsamplelocations: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetMultisamplefv                       = procedure(aPname: GLenum; aIndex: GLuint; aVal: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSampleMaski                            = procedure(aMaskNumber: GLuint; aMask: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexLevelParameteriv                 = procedure(aTarget: GLenum; aLevel: GLint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexLevelParameterfv                 = procedure(aTarget: GLenum; aLevel: GLint; aPname: GLenum; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindVertexBuffer                       = procedure(aBindingindex: GLuint; aBuffer: GLuint; aOffset: GLintptr; aStride: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribFormat                     = procedure(aAttribindex: GLuint; aSize: GLint; aType: GLenum; aNormalized: GLboolean; aRelativeoffset: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribIFormat                    = procedure(aAttribindex: GLuint; aSize: GLint; aType: GLenum; aRelativeoffset: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribBinding                    = procedure(aAttribindex: GLuint; aBindingindex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexBindingDivisor                   = procedure(aBindingindex: GLuint; aDivisor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
{$ENDIF}

{$IFDEF OPENGLES_CORE_1_1}
var
{ ============================================== OpenGL ES 1.1 ======================================================= }
{ Available only in Common profile }
  glAlphaFunc:                              TglAlphaFunc;
  glClearColor:                             TglClearColor;
  glClearDepthf:                            TglClearDepthf;
  glClipPlanef:                             TglClipPlanef;
  glColor4f:                                TglColor4f;
  glDepthRangef:                            TglDepthRangef;
  glFogf:                                   TglFogf;
  glFogfv:                                  TglFogfv;
  glFrustumf:                               TglFrustumf;
  glGetClipPlanef:                          TglGetClipPlanef;
  glGetFloatv:                              TglGetFloatv;
  glGetLightfv:                             TglGetLightfv;
  glGetMaterialfv:                          TglGetMaterialfv;
  glGetTexEnvfv:                            TglGetTexEnvfv;
  glGetTexParameterfv:                      TglGetTexParameterfv;
  glLightModelf:                            TglLightModelf;
  glLightModelfv:                           TglLightModelfv;
  glLightf:                                 TglLightf;
  glLightfv:                                TglLightfv;
  glLineWidth:                              TglLineWidth;
  glLoadMatrixf:                            TglLoadMatrixf;
  glMaterialf:                              TglMaterialf;
  glMaterialfv:                             TglMaterialfv;
  glMultMatrixf:                            TglMultMatrixf;
  glMultiTexCoord4f:                        TglMultiTexCoord4f;
  glNormal3f:                               TglNormal3f;
  glOrthof:                                 TglOrthof;
  glPointParameterf:                        TglPointParameterf;
  glPointParameterfv:                       TglPointParameterfv;
  glPointSize:                              TglPointSize;
  glPolygonOffset:                          TglPolygonOffset;
  glRotatef:                                TglRotatef;
  glScalef:                                 TglScalef;
  glTexEnvf:                                TglTexEnvf;
  glTexEnvfv:                               TglTexEnvfv;
  glTexParameterf:                          TglTexParameterf;
  glTexParameterfv:                         TglTexParameterfv;
  glTranslatef:                             TglTranslatef;

{ Available in both Common and Common-Lite profiles }
  glActiveTexture:                          TglActiveTexture;
  glAlphaFuncx:                             TglAlphaFuncx;
  glBindBuffer:                             TglBindBuffer;
  glBindTexture:                            TglBindTexture;
  glBlendFunc:                              TglBlendFunc;
  glBufferData:                             TglBufferData;
  glBufferSubData:                          TglBufferSubData;
  glClear:                                  TglClear;
  glClearColorx:                            TglClearColorx;
  glClearDepthx:                            TglClearDepthx;
  glClearStencil:                           TglClearStencil;
  glClientActiveTexture:                    TglClientActiveTexture;
  glClipPlanex:                             TglClipPlanex;
  glColor4ub:                               TglColor4ub;
  glColor4x:                                TglColor4x;
  glColorMask:                              TglColorMask;
  glColorPointer:                           TglColorPointer;
  glCompressedTexImage2D:                   TglCompressedTexImage2D;
  glCompressedTexSubImage2D:                TglCompressedTexSubImage2D;
  glCopyTexImage2D:                         TglCopyTexImage2D;
  glCopyTexSubImage2D:                      TglCopyTexSubImage2D;
  glCullFace:                               TglCullFace;
  glDeleteBuffers:                          TglDeleteBuffers;
  glDeleteTextures:                         TglDeleteTextures;
  glDepthFunc:                              TglDepthFunc;
  glDepthMask:                              TglDepthMask;
  glDepthRangex:                            TglDepthRangex;
  glDisable:                                TglDisable;
  glDisableClientState:                     TglDisableClientState;
  glDrawArrays:                             TglDrawArrays;
  glDrawElements:                           TglDrawElements;
  glEnable:                                 TglEnable;
  glEnableClientState:                      TglEnableClientState;
  glFinish:                                 TglFinish;
  glFlush:                                  TglFlush;
  glFogx:                                   TglFogx;
  glFogxv:                                  TglFogxv;
  glFrontFace:                              TglFrontFace;
  glFrustumx:                               TglFrustumx;
  glGetBooleanv:                            TglGetBooleanv;
  glGetBufferParameteriv:                   TglGetBufferParameteriv;
  glGetClipPlanex:                          TglGetClipPlanex;
  glGenBuffers:                             TglGenBuffers;
  glGenTextures:                            TglGenTextures;
  glGetError:                               TglGetError;
  glGetFixedv:                              TglGetFixedv;
  glGetIntegerv:                            TglGetIntegerv;
  glGetLightxv:                             TglGetLightxv;
  glGetMaterialxv:                          TglGetMaterialxv;
  glGetPointerv:                            TglGetPointerv;
  glGetString:                              TglGetString;
  glGetTexEnviv:                            TglGetTexEnviv;
  glGetTexEnvxv:                            TglGetTexEnvxv;
  glGetTexParameteriv:                      TglGetTexParameteriv;
  glGetTexParameterxv:                      TglGetTexParameterxv;
  glHint:                                   TglHint;
  glIsBuffer:                               TglIsBuffer;
  glIsEnabled:                              TglIsEnabled;
  glIsTexture:                              TglIsTexture;
  glLightModelx:                            TglLightModelx;
  glLightModelxv:                           TglLightModelxv;
  glLightx:                                 TglLightx;
  glLightxv:                                TglLightxv;
  glLineWidthx:                             TglLineWidthx;
  glLoadIdentity:                           TglLoadIdentity;
  glLoadMatrix:                             TglLoadMatrix;
  glLogicOp:                                TglLogicOp;
  glMaterialx:                              TglMaterialx;
  glMaterialxv:                             TglMaterialxv;
  glMatrixMode:                             TglMatrixMode;
  glMultMatrixx:                            TglMultMatrixx;
  glMultiTexCoord4x:                        TglMultiTexCoord4x;
  glNormal3x:                               TglNormal3x;
  glNormalPointer:                          TglNormalPointer;
  glOrthox:                                 TglOrthox;
  glPixelStorei:                            TglPixelStorei;
  glPointParameterx:                        TglPointParameterx;
  glPointParameterxv:                       TglPointParameterxv;
  glPointSizex:                             TglPointSizex;
  glPolygonOffsetx:                         TglPolygonOffsetx;
  glPopMatrix:                              TglPopMatrix;
  glPushMatrix:                             TglPushMatrix;
  glReadPixels:                             TglReadPixels;
  glRotatex:                                TglRotatex;
  glSampleCoverage:                         TglSampleCoverage;
  glSampleCoveragex:                        TglSampleCoveragex;
  glScalex:                                 TglScalex;
  glScissor:                                TglScissor;
  glShadeModel:                             TglShadeModel;
  glStencilFunc:                            TglStencilFunc;
  glStencilMask:                            TglStencilMask;
  glStencilOp:                              TglStencilOp;
  glTexCoordPointer:                        TglTexCoordPointer;
  glTexEnvi:                                TglTexEnvi;
  glTexEnvx:                                TglTexEnvx;
  glTexEnviv:                               TglTexEnviv;
  glTexEnvxv:                               TglTexEnvxv;
  glTexImage2D:                             TglTexImage2D;
  glTexParameteri:                          TglTexParameteri;
  glTexParameterx:                          TglTexParameterx;
  glTexParameteriv:                         TglTexParameteriv;
  glTexParameterxv:                         TglTexParameterxv;
  glTexSubImage2D:                          TglTexSubImage2D;
  glTranslatex:                             TglTranslatex;
  glVertexPointer:                          TglVertexPointer;
  glViewport:                               TglViewport;
{$ENDIF}

{$IFDEF OPENGLES_CORE_2_0}
var
{ ============================================== OpenGL ES 2.0 ======================================================= }
  glAttachShader:                           TglAttachShader;
  glBindAttribLocation:                     TglBindAttribLocation;
  glBindFramebuffer:                        TglBindFramebuffer;
  glBindRenderbuffer:                       TglBindRenderbuffer;
  glBlendColor:                             TglBlendColor;
  glBlendEquation:                          TglBlendEquation;
  glBlendEquationSeparate:                  TglBlendEquationSeparate;
  glBlendFuncSeparate:                      TglBlendFuncSeparate;
  glCheckFramebufferStatus:                 TglCheckFramebufferStatus;
  glCompileShader:                          TglCompileShader;
  glCreateProgram:                          TglCreateProgram;
  glCreateShader:                           TglCreateShader;
  glDeleteFramebuffers:                     TglDeleteFramebuffers;
  glDeleteProgram:                          TglDeleteProgram;
  glDeleteRenderbuffers:                    TglDeleteRenderbuffers;
  glDeleteShader:                           TglDeleteShader;
  glDetachShader:                           TglDetachShader;
  glDisableVertexAttribArray:               TglDisableVertexAttribArray;
  glEnableVertexAttribArray:                TglEnableVertexAttribArray;
  glFramebufferRenderbuffer:                TglFramebufferRenderbuffer;
  glFramebufferTexture2D:                   TglFramebufferTexture2D;
  glGenerateMipmap:                         TglGenerateMipmap;
  glGenFramebuffers:                        TglGenFramebuffers;
  glGenRenderbuffers:                       TglGenRenderbuffers;
  glGetActiveAttrib:                        TglGetActiveAttrib;
  glGetActiveUniform:                       TglGetActiveUniform;
  glGetAttachedShaders:                     TglGetAttachedShaders;
  glGetAttribLocation:                      TglGetAttribLocation;
  glGetFramebufferAttachmentParameteriv:    TglGetFramebufferAttachmentParameteriv;
  glGetProgramiv:                           TglGetProgramiv;
  glGetProgramInfoLog:                      TglGetProgramInfoLog;
  glGetRenderbufferParameteriv:             TglGetRenderbufferParameteriv;
  glGetShaderiv:                            TglGetShaderiv;
  glGetShaderInfoLog:                       TglGetShaderInfoLog;
  glGetShaderPrecisionFormat:               TglGetShaderPrecisionFormat;
  glGetShaderSource:                        TglGetShaderSource;
  glGetUniformfv:                           TglGetUniformfv;
  glGetUniformiv:                           TglGetUniformiv;
  glGetUniformLocation:                     TglGetUniformLocation;
  glGetVertexAttribfv:                      TglGetVertexAttribfv;
  glGetVertexAttribiv:                      TglGetVertexAttribiv;
  glGetVertexAttribPointerv:                TglGetVertexAttribPointerv;
  glIsFramebuffer:                          TglIsFramebuffer;
  glIsProgram:                              TglIsProgram;
  glIsRenderbuffer:                         TglIsRenderbuffer;
  glIsShader:                               TglIsShader;
  glLinkProgram:                            TglLinkProgram;
  glReleaseShaderCompiler:                  TglReleaseShaderCompiler;
  glRenderbufferStorage:                    TglRenderbufferStorage;
  glShaderBinary:                           TglShaderBinary;
  glShaderSource:                           TglShaderSource;
  glStencilFuncSeparate:                    TglStencilFuncSeparate;
  glStencilMaskSeparate:                    TglStencilMaskSeparate;
  glStencilOpSeparate:                      TglStencilOpSeparate;
  glUniform1f:                              TglUniform1f;
  glUniform1fv:                             TglUniform1fv;
  glUniform1i:                              TglUniform1i;
  glUniform1iv:                             TglUniform1iv;
  glUniform2f:                              TglUniform2f;
  glUniform2fv:                             TglUniform2fv;
  glUniform2i:                              TglUniform2i;
  glUniform2iv:                             TglUniform2iv;
  glUniform3f:                              TglUniform3f;
  glUniform3fv:                             TglUniform3fv;
  glUniform3i:                              TglUniform3i;
  glUniform3iv:                             TglUniform3iv;
  glUniform4f:                              TglUniform4f;
  glUniform4fv:                             TglUniform4fv;
  glUniform4i:                              TglUniform4i;
  glUniform4iv:                             TglUniform4iv;
  glUniformMatrix2fv:                       TglUniformMatrix2fv;
  glUniformMatrix3fv:                       TglUniformMatrix3fv;
  glUniformMatrix4fv:                       TglUniformMatrix4fv;
  glUseProgram:                             TglUseProgram;
  glValidateProgram:                        TglValidateProgram;
  glVertexAttrib1f:                         TglVertexAttrib1f;
  glVertexAttrib1fv:                        TglVertexAttrib1fv;
  glVertexAttrib2f:                         TglVertexAttrib2f;
  glVertexAttrib2fv:                        TglVertexAttrib2fv;
  glVertexAttrib3f:                         TglVertexAttrib3f;
  glVertexAttrib3fv:                        TglVertexAttrib3fv;
  glVertexAttrib4f:                         TglVertexAttrib4f;
  glVertexAttrib4fv:                        TglVertexAttrib4fv;
  glVertexAttribPointer:                    TglVertexAttribPointer;
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_0}
{ ============================================== OpenGL ES 3.0 ======================================================= }
var
  glReadBuffer:                             TglReadBuffer;
  glDrawRangeElements:                      TglDrawRangeElements;
  glTexImage3D:                             TglTexImage3D;
  glTexSubImage3D:                          TglTexSubImage3D;
  glCopyTexSubImage3D:                      TglCopyTexSubImage3D;
  glCompressedTexImage3D:                   TglCompressedTexImage3D;
  glCompressedTexSubImage3D:                TglCompressedTexSubImage3D;
  glGenQueries:                             TglGenQueries;
  glDeleteQueries:                          TglDeleteQueries;
  glIsQuery:                                TglIsQuery;
  glBeginQuery:                             TglBeginQuery;
  glEndQuery:                               TglEndQuery;
  glGetQueryiv:                             TglGetQueryiv;
  glGetQueryObjectuiv:                      TglGetQueryObjectuiv;
  glUnmapBuffer:                            TglUnmapBuffer;
  glGetBufferPointerv:                      TglGetBufferPointerv;
  glDrawBuffers:                            TglDrawBuffers;
  glUniformMatrix2x3fv:                     TglUniformMatrix2x3fv;
  glUniformMatrix3x2fv:                     TglUniformMatrix3x2fv;
  glUniformMatrix2x4fv:                     TglUniformMatrix2x4fv;
  glUniformMatrix4x2fv:                     TglUniformMatrix4x2fv;
  glUniformMatrix3x4fv:                     TglUniformMatrix3x4fv;
  glUniformMatrix4x3fv:                     TglUniformMatrix4x3fv;
  glBlitFramebuffer:                        TglBlitFramebuffer;
  glRenderbufferStorageMultisample:         TglRenderbufferStorageMultisample;
  glFramebufferTextureLayer:                TglFramebufferTextureLayer;
  glMapBufferRange:                         TglMapBufferRange;
  glFlushMappedBufferRange:                 TglFlushMappedBufferRange;
  glBindVertexArray:                        TglBindVertexArray;
  glDeleteVertexArrays:                     TglDeleteVertexArrays;
  glGenVertexArrays:                        TglGenVertexArrays;
  glIsVertexArray:                          TglIsVertexArray;
  glGetIntegeriv:                           TglGetIntegeriv;
  glBeginTransformFeedback:                 TglBeginTransformFeedback;
  glEndTransformFeedback:                   TglEndTransformFeedback;
  glBindBufferRange:                        TglBindBufferRange;
  glBindBufferBase:                         TglBindBufferBase;
  glTransformFeedbackVaryings:              TglTransformFeedbackVaryings;
  glGetTransformFeedbackVarying:            TglGetTransformFeedbackVarying;
  glVertexAttribIPointer:                   TglVertexAttribIPointer;
  glGetVertexAttribIiv:                     TglGetVertexAttribIiv;
  glGetVertexAttribIuiv:                    TglGetVertexAttribIuiv;
  glVertexAttribI4i:                        TglVertexAttribI4i;
  glVertexAttribI4ui:                       TglVertexAttribI4ui;
  glVertexAttribI4iv:                       TglVertexAttribI4iv;
  glVertexAttribI4uiv:                      TglVertexAttribI4uiv;
  glGetUniformuiv:                          TglGetUniformuiv;
  glGetFragDataLocation:                    TglGetFragDataLocation;
  glUniform1ui:                             TglUniform1ui;
  glUniform2ui:                             TglUniform2ui;
  glUniform3ui:                             TglUniform3ui;
  glUniform4ui:                             TglUniform4ui;
  glUniform1uiv:                            TglUniform1uiv;
  glUniform2uiv:                            TglUniform2uiv;
  glUniform3uiv:                            TglUniform3uiv;
  glUniform4uiv:                            TglUniform4uiv;
  glClearBufferiv:                          TglClearBufferiv;
  glClearBufferuiv:                         TglClearBufferuiv;
  glClearBufferfv:                          TglClearBufferfv;
  glClearBufferfi:                          TglClearBufferfi;
  glGetStringi:                             TglGetStringi;
  glCopyBufferSubData:                      TglCopyBufferSubData;
  glGetUniformIndices:                      TglGetUniformIndices;
  glGetActiveUniformsiv:                    TglGetActiveUniformsiv;
  glGetUniformBlockIndex:                   TglGetUniformBlockIndex;
  glGetActiveUniformBlockiv:                TglGetActiveUniformBlockiv;
  glGetActiveUniformBlockName:              TglGetActiveUniformBlockName;
  glUniformBlockBinding:                    TglUniformBlockBinding;
  glDrawArraysInstanced:                    TglDrawArraysInstanced;
  glDrawElementsInstanced:                  TglDrawElementsInstanced;
  glFenceSync:                              TglFenceSync;
  glIsSync:                                 TglIsSync;
  glDeleteSync:                             TglDeleteSync;
  glClientWaitSync:                         TglClientWaitSync;
  glWaitSync:                               TglWaitSync;
  glGetInteger64v:                          TglGetInteger64v;
  glGetSynciv:                              TglGetSynciv;
  glGetInteger64iv:                         TglGetInteger64iv;
  glGetBufferParameteri64v:                 TglGetBufferParameteri64v;
  glGenSamplers:                            TglGenSamplers;
  glDeleteSamplers:                         TglDeleteSamplers;
  glIsSampler:                              TglIsSampler;
  glBindSampler:                            TglBindSampler;
  glSamplerParameteri:                      TglSamplerParameteri;
  glSamplerParameteriv:                     TglSamplerParameteriv;
  glSamplerParameterf:                      TglSamplerParameterf;
  glSamplerParameterfv:                     TglSamplerParameterfv;
  glGetSamplerParameteriv:                  TglGetSamplerParameteriv;
  glGetSamplerParameterfv:                  TglGetSamplerParameterfv;
  glVertexAttribDivisor:                    TglVertexAttribDivisor;
  glBindTransformFeedback:                  TglBindTransformFeedback;
  glDeleteTransformFeedbacks:               TglDeleteTransformFeedbacks;
  glGenTransformFeedbacks:                  TglGenTransformFeedbacks;
  glIsTransformFeedback:                    TglIsTransformFeedback;
  glPauseTransformFeedback:                 TglPauseTransformFeedback;
  glResumeTransformFeedback:                TglResumeTransformFeedback;
  glGetProgramBinary:                       TglGetProgramBinary;
  glProgramBinary:                          TglProgramBinary;
  glProgramParameteri:                      TglProgramParameteri;
  glInvalidateFramebuffer:                  TglInvalidateFramebuffer;
  glInvalidateSubFramebuffer:               TglInvalidateSubFramebuffer;
  glTexStorage2D:                           TglTexStorage2D;
  glTexStorage3D:                           TglTexStorage3D;
  glGetInternalformativ:                    TglGetInternalformativ;
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_1}
{ ============================================== OpenGL ES 3.1 ======================================================= }
var
  glDispatchCompute:                        TglDispatchCompute;
  glDispatchComputeIndirect:                TglDispatchComputeIndirect;
  glDrawArraysIndirect:                     TglDrawArraysIndirect;
  glDrawElementsIndirect:                   TglDrawElementsIndirect;
  glFramebufferParameteri:                  TglFramebufferParameteri;
  glGetFramebufferParameteriv:              TglGetFramebufferParameteriv;
  glGetProgramInterfaceiv:                  TglGetProgramInterfaceiv;
  glGetProgramResourceIndex:                TglGetProgramResourceIndex;
  glGetProgramResourceName:                 TglGetProgramResourceName;
  glGetProgramResourceiv:                   TglGetProgramResourceiv;
  glGetProgramResourceLocation:             TglGetProgramResourceLocation;
  glUseProgramStages:                       TglUseProgramStages;
  glActiveShaderProgram:                    TglActiveShaderProgram;
  glCreateShaderProgramv:                   TglCreateShaderProgramv;
  glBindProgramPipeline:                    TglBindProgramPipeline;
  glDeleteProgramPipelines:                 TglDeleteProgramPipelines;
  glGenProgramPipelines:                    TglGenProgramPipelines;
  glIsProgramPipeline:                      TglIsProgramPipeline;
  glGetProgramPipelineiv:                   TglGetProgramPipelineiv;
  glProgramUniform1i:                       TglProgramUniform1i;
  glProgramUniform2i:                       TglProgramUniform2i;
  glProgramUniform3i:                       TglProgramUniform3i;
  glProgramUniform4i:                       TglProgramUniform4i;
  glProgramUniform1ui:                      TglProgramUniform1ui;
  glProgramUniform2ui:                      TglProgramUniform2ui;
  glProgramUniform3ui:                      TglProgramUniform3ui;
  glProgramUniform4ui:                      TglProgramUniform4ui;
  glProgramUniform1f:                       TglProgramUniform1f;
  glProgramUniform2f:                       TglProgramUniform2f;
  glProgramUniform3f:                       TglProgramUniform3f;
  glProgramUniform4f:                       TglProgramUniform4f;
  glProgramUniform1iv:                      TglProgramUniform1iv;
  glProgramUniform2iv:                      TglProgramUniform2iv;
  glProgramUniform3iv:                      TglProgramUniform3iv;
  glProgramUniform4iv:                      TglProgramUniform4iv;
  glProgramUniform1uiv:                     TglProgramUniform1uiv;
  glProgramUniform2uiv:                     TglProgramUniform2uiv;
  glProgramUniform3uiv:                     TglProgramUniform3uiv;
  glProgramUniform4uiv:                     TglProgramUniform4uiv;
  glProgramUniform1fv:                      TglProgramUniform1fv;
  glProgramUniform2fv:                      TglProgramUniform2fv;
  glProgramUniform3fv:                      TglProgramUniform3fv;
  glProgramUniform4fv:                      TglProgramUniform4fv;
  glProgramUniformMatrix2fv:                TglProgramUniformMatrix2fv;
  glProgramUniformMatrix3fv:                TglProgramUniformMatrix3fv;
  glProgramUniformMatrix4fv:                TglProgramUniformMatrix4fv;
  glProgramUniformMatrix2x3fv:              TglProgramUniformMatrix2x3fv;
  glProgramUniformMatrix3x2fv:              TglProgramUniformMatrix3x2fv;
  glProgramUniformMatrix2x4fv:              TglProgramUniformMatrix2x4fv;
  glProgramUniformMatrix4x2fv:              TglProgramUniformMatrix4x2fv;
  glProgramUniformMatrix3x4fv:              TglProgramUniformMatrix3x4fv;
  glProgramUniformMatrix4x3fv:              TglProgramUniformMatrix4x3fv;
  glValidateProgramPipeline:                TglValidateProgramPipeline;
  glGetProgramPipelineInfoLog:              TglGetProgramPipelineInfoLog;
  glBindImageTexture:                       TglBindImageTexture;
  glGetBooleaniv:                           TglGetBooleaniv;
  glMemoryBarrier:                          TglMemoryBarrier;
  glMemoryBarrierByRegion:                  TglMemoryBarrierByRegion;
  glTexStorage2DMultisample:                TglTexStorage2DMultisample;
  glGetMultisamplefv:                       TglGetMultisamplefv;
  glSampleMaski:                            TglSampleMaski;
  glGetTexLevelParameteriv:                 TglGetTexLevelParameteriv;
  glGetTexLevelParameterfv:                 TglGetTexLevelParameterfv;
  glBindVertexBuffer:                       TglBindVertexBuffer;
  glVertexAttribFormat:                     TglVertexAttribFormat;
  glVertexAttribIFormat:                    TglVertexAttribIFormat;
  glVertexAttribBinding:                    TglVertexAttribBinding;
  glVertexBindingDivisor:                   TglVertexBindingDivisor;
{$ENDIF}

{$IFDEF OPENGLES_EXTENSIONS}
{ =============================================== Extensions ========================================================= }
{ GL_KHR_blend_equation_advanced }
const
  GL_MULTIPLY_KHR                                         = $9294;
  GL_SCREEN_KHR                                           = $9295;
  GL_OVERLAY_KHR                                          = $9296;
  GL_DARKEN_KHR                                           = $9297;
  GL_LIGHTEN_KHR                                          = $9298;
  GL_COLORDODGE_KHR                                       = $9299;
  GL_COLORBURN_KHR                                        = $929A;
  GL_HARDLIGHT_KHR                                        = $929B;
  GL_SOFTLIGHT_KHR                                        = $929C;
  GL_DIFFERENCE_KHR                                       = $929E;
  GL_EXCLUSION_KHR                                        = $92A0;
  GL_HSL_HUE_KHR                                          = $92AD;
  GL_HSL_SATURATION_KHR                                   = $92AE;
  GL_HSL_COLOR_KHR                                        = $92AF;
  GL_HSL_LUMINOSITY_KHR                                   = $92B0;
type
  TglBlendBarrierKHR                                      = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBlendBarrierKHR:                                        TglBlendBarrierKHR;

{ GL_KHR_blend_equation_advanced_coherent }
const
  GL_BLEND_ADVANCED_COHERENT_KHR                          = $9285;

{ GL_KHR_context_flush_control }
const
  GL_CONTEXT_RELEASE_BEHAVIOR_KHR                         = $82FB;
  GL_CONTEXT_RELEASE_BEHAVIOR_FLUSH_KHR                   = $82FC;

{ GL_KHR_debug }
const
  GL_SAMPLER                                              = $82E6;
  GL_DEBUG_OUTPUT_SYNCHRONOUS_KHR                         = $8242;
  GL_DEBUG_NEXT_LOGGED_MESSAGE_LENGTH_KHR                 = $8243;
  GL_DEBUG_CALLBACK_FUNCTION_KHR                          = $8244;
  GL_DEBUG_CALLBACK_USER_PARAM_KHR                        = $8245;
  GL_DEBUG_SOURCE_API_KHR                                 = $8246;
  GL_DEBUG_SOURCE_WINDOW_SYSTEM_KHR                       = $8247;
  GL_DEBUG_SOURCE_SHADER_COMPILER_KHR                     = $8248;
  GL_DEBUG_SOURCE_THIRD_PARTY_KHR                         = $8249;
  GL_DEBUG_SOURCE_APPLICATION_KHR                         = $824A;
  GL_DEBUG_SOURCE_OTHER_KHR                               = $824B;
  GL_DEBUG_TYPE_ERROR_KHR                                 = $824C;
  GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR_KHR                   = $824D;
  GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR_KHR                    = $824E;
  GL_DEBUG_TYPE_PORTABILITY_KHR                           = $824F;
  GL_DEBUG_TYPE_PERFORMANCE_KHR                           = $8250;
  GL_DEBUG_TYPE_OTHER_KHR                                 = $8251;
  GL_DEBUG_TYPE_MARKER_KHR                                = $8268;
  GL_DEBUG_TYPE_PUSH_GROUP_KHR                            = $8269;
  GL_DEBUG_TYPE_POP_GROUP_KHR                             = $826A;
  GL_DEBUG_SEVERITY_NOTIFICATION_KHR                      = $826B;
  GL_MAX_DEBUG_GROUP_STACK_DEPTH_KHR                      = $826C;
  GL_DEBUG_GROUP_STACK_DEPTH_KHR                          = $826D;
  GL_BUFFER_KHR                                           = $82E0;
  GL_BUFFER                                               = $82E0; // Local addition: matches dglOpenGL's non-KHR-suffixed alias, used by engine's SetGLObjectLabel
  GL_SHADER_KHR                                           = $82E1;
  GL_PROGRAM_KHR                                          = $82E2;
  GL_PROGRAM                                              = $82E2; // Local addition: matches dglOpenGL's non-KHR-suffixed alias, used by engine's SetGLProgramLabel
  GL_VERTEX_ARRAY_KHR                                     = $8074;
  GL_QUERY_KHR                                            = $82E3;
  GL_SAMPLER_KHR                                          = $82E6;
  GL_MAX_LABEL_LENGTH_KHR                                 = $82E8;
  GL_MAX_DEBUG_MESSAGE_LENGTH_KHR                         = $9143;
  GL_MAX_DEBUG_LOGGED_MESSAGES_KHR                        = $9144;
  GL_DEBUG_LOGGED_MESSAGES_KHR                            = $9145;
  GL_DEBUG_SEVERITY_HIGH_KHR                              = $9146;
  GL_DEBUG_SEVERITY_MEDIUM_KHR                            = $9147;
  GL_DEBUG_SEVERITY_LOW_KHR                               = $9148;
  GL_DEBUG_OUTPUT_KHR                                     = $92E0;
  GL_CONTEXT_FLAG_DEBUG_BIT_KHR                           = $00000002;
  GL_STACK_OVERFLOW_KHR                                   = $0503;
  GL_STACK_UNDERFLOW_KHR                                  = $0504;

  // Local additions: non-KHR-suffixed aliases matching dglOpenGL's naming, so
  // engine code that logs GL_KHR_debug enum values compiles unchanged under GLES.
  GL_DEBUG_SOURCE_API                                     = $8246;
  GL_DEBUG_SOURCE_WINDOW_SYSTEM                           = $8247;
  GL_DEBUG_SOURCE_SHADER_COMPILER                         = $8248;
  GL_DEBUG_SOURCE_THIRD_PARTY                             = $8249;
  GL_DEBUG_SOURCE_APPLICATION                             = $824A;
  GL_DEBUG_SOURCE_OTHER                                   = $824B;
  GL_DEBUG_TYPE_ERROR                                     = $824C;
  GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR                       = $824D;
  GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR                        = $824E;
  GL_DEBUG_TYPE_PORTABILITY                               = $824F;
  GL_DEBUG_TYPE_PERFORMANCE                               = $8250;
  GL_DEBUG_TYPE_OTHER                                     = $8251;
  GL_DEBUG_TYPE_MARKER                                    = $8268;
  GL_DEBUG_SEVERITY_NOTIFICATION                          = $826B;
  GL_DEBUG_SEVERITY_HIGH                                  = $9146;
  GL_DEBUG_SEVERITY_MEDIUM                                = $9147;
  GL_DEBUG_SEVERITY_LOW                                   = $9148;
  GL_DEBUG_OUTPUT                                         = $92E0;
type
  TglDebugProcKHR                                         = procedure(aSource: GLenum; aType: GLenum; aId: GLuint; aSeverity: GLenum; aLength: GLsizei; const aMessage: PGLchar; const aUserParam: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDebugMessageControlKHR                               = procedure(aSource: GLenum; aType: GLenum; aSeverity: GLenum; aCount: GLsizei; const aIds: PGLuint; aEnabled: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDebugMessageInsertKHR                                = procedure(aSource: GLenum; aType: GLenum; aId: GLuint; aSeverity: GLenum; aLength: GLsizei; const aBuf: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDebugMessageCallbackKHR                              = procedure(aCallback: TglDebugProcKHR; const aUserParam: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetDebugMessageLogKHR                                = function (aCount: GLuint; aBufSize: GLsizei; aSources: PGLenum; aTypes: PGLenum; aIds: PGLuint; aSeverities: PGLenum; aLengths: PGLsizei; aMessageLog: PGLchar): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPushDebugGroupKHR                                    = procedure(aSource: GLenum; aId: GLuint; aLength: GLsizei; const aMessage: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPopDebugGroupKHR                                     = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglObjectLabelKHR                                       = procedure(aIdentifier: GLenum; aName: GLuint; aLength: GLsizei; const aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetObjectLabelKHR                                    = procedure(aIdentifier: GLenum; aName: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglObjectPtrLabelKHR                                    = procedure(const aPtr: Pointer; aLength: GLsizei; const aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetObjectPtrLabelKHR                                 = procedure(const aPtr: Pointer; aBufSize: GLsizei; aLength: PGLsizei; aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPointervKHR                                       = procedure(aPname: GLenum; aParams: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDebugMessageControlKHR:                                 TglDebugMessageControlKHR;
  glDebugMessageInsertKHR:                                  TglDebugMessageInsertKHR;
  glDebugMessageCallbackKHR:                                TglDebugMessageCallbackKHR;
  glGetDebugMessageLogKHR:                                  TglGetDebugMessageLogKHR;
  glPushDebugGroupKHR:                                      TglPushDebugGroupKHR;
  glPopDebugGroupKHR:                                       TglPopDebugGroupKHR;
  glObjectLabelKHR:                                         TglObjectLabelKHR;
  glGetObjectLabelKHR:                                      TglGetObjectLabelKHR;
  glObjectPtrLabelKHR:                                      TglObjectPtrLabelKHR;
  glGetObjectPtrLabelKHR:                                   TglGetObjectPtrLabelKHR;
  glGetPointervKHR:                                         TglGetPointervKHR;

{ GL_KHR_robust_buffer_access_behavior }
  // none

{ GL_KHR_robustness }
const
  GL_CONTEXT_ROBUST_ACCESS_KHR                            = $90F3;
  GL_LOSE_CONTEXT_ON_RESET_KHR                            = $8252;
  GL_GUILTY_CONTEXT_RESET_KHR                             = $8253;
  GL_INNOCENT_CONTEXT_RESET_KHR                           = $8254;
  GL_UNKNOWN_CONTEXT_RESET_KHR                            = $8255;
  GL_RESET_NOTIFICATION_STRATEGY_KHR                      = $8256;
  GL_NO_RESET_NOTIFICATION_KHR                            = $8261;
  GL_CONTEXT_LOST_KHR                                     = $0507;
type
  TglGetGraphicsResetStatusKHR                            = function : GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglReadnPixelsKHR                                       = procedure(x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei; aFormat: GLenum; aType: GLenum; aBufSize: GLsizei; aData: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetnUniformfvKHR                                     = procedure(aProgram: GLuint; aLocation: GLint; aBufSize: GLsizei; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetnUniformivKHR                                     = procedure(aProgram: GLuint; aLocation: GLint; aBufSize: GLsizei; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetnUniformuivKHR                                    = procedure(aProgram: GLuint; aLocation: GLint; aBufSize: GLsizei; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetGraphicsResetStatusKHR:                              TglGetGraphicsResetStatusKHR;
  glReadnPixelsKHR:                                         TglReadnPixelsKHR;
  glGetnUniformfvKHR:                                       TglGetnUniformfvKHR;
  glGetnUniformivKHR:                                       TglGetnUniformivKHR;
  glGetnUniformuivKHR:                                      TglGetnUniformuivKHR;

{ GL_KHR_texture_compression_astc_hdr }
const
  GL_COMPRESSED_RGBA_ASTC_4x4_KHR                         = $93B0;
  GL_COMPRESSED_RGBA_ASTC_5x4_KHR                         = $93B1;
  GL_COMPRESSED_RGBA_ASTC_5x5_KHR                         = $93B2;
  GL_COMPRESSED_RGBA_ASTC_6x5_KHR                         = $93B3;
  GL_COMPRESSED_RGBA_ASTC_6x6_KHR                         = $93B4;
  GL_COMPRESSED_RGBA_ASTC_8x5_KHR                         = $93B5;
  GL_COMPRESSED_RGBA_ASTC_8x6_KHR                         = $93B6;
  GL_COMPRESSED_RGBA_ASTC_8x8_KHR                         = $93B7;
  GL_COMPRESSED_RGBA_ASTC_10x5_KHR                        = $93B8;
  GL_COMPRESSED_RGBA_ASTC_10x6_KHR                        = $93B9;
  GL_COMPRESSED_RGBA_ASTC_10x8_KHR                        = $93BA;
  GL_COMPRESSED_RGBA_ASTC_10x10_KHR                       = $93BB;
  GL_COMPRESSED_RGBA_ASTC_12x10_KHR                       = $93BC;
  GL_COMPRESSED_RGBA_ASTC_12x12_KHR                       = $93BD;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR                 = $93D0;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR                 = $93D1;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR                 = $93D2;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR                 = $93D3;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR                 = $93D4;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR                 = $93D5;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR                 = $93D6;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR                 = $93D7;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR                = $93D8;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR                = $93D9;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR                = $93DA;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR               = $93DB;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR               = $93DC;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR               = $93DD;

{ GL_KHR_texture_compression_astc_ldr }
  // none

{ GL_OES_EGL_image }
type
  GLeglImageOES                                           = Pointer;
  TglEGLImageTargetTexture2DOES                           = procedure(aTarget: GLenum; aImage: GLeglImageOES); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEGLImageTargetRenderbufferStorageOES                 = procedure(aTarget: GLenum; aImage: GLeglImageOES); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glEGLImageTargetTexture2DOES:                             TglEGLImageTargetTexture2DOES;
  glEGLImageTargetRenderbufferStorageOES:                   TglEGLImageTargetRenderbufferStorageOES;

{ GL_OES_EGL_image_external }
const
  GL_TEXTURE_EXTERNAL_OES                                 = $8D65;
  GL_TEXTURE_BINDING_EXTERNAL_OES                         = $8D67;
  GL_REQUIRED_TEXTURE_IMAGE_UNITS_OES                     = $8D68;
  GL_SAMPLER_EXTERNAL_OES                                 = $8D66;

{ GL_OES_compressed_ETC1_RGB8_sub_texture }
  // none

{ GL_OES_compressed_ETC1_RGB8_texture }
const
  GL_ETC1_RGB8_OES                                        = $8D64;

{ GL_OES_compressed_paletted_texture }
const
  GL_PALETTE4_RGB8_OES                                    = $8B90;
  GL_PALETTE4_RGBA8_OES                                   = $8B91;
  GL_PALETTE4_R5_G6_B5_OES                                = $8B92;
  GL_PALETTE4_RGBA4_OES                                   = $8B93;
  GL_PALETTE4_RGB5_A1_OES                                 = $8B94;
  GL_PALETTE8_RGB8_OES                                    = $8B95;
  GL_PALETTE8_RGBA8_OES                                   = $8B96;
  GL_PALETTE8_R5_G6_B5_OES                                = $8B97;
  GL_PALETTE8_RGBA4_OES                                   = $8B98;
  GL_PALETTE8_RGB5_A1_OES                                 = $8B99;

{ GL_OES_depth24 }
const
  GL_DEPTH_COMPONENT24_OES                                = $81A6;

{ GL_OES_depth32 }
const
  GL_DEPTH_COMPONENT32_OES                                = $81A7;

{ GL_OES_depth_texture }
  // none

{ GL_OES_element_index_uint }
  // none

{ GL_OES_fbo_render_mipmap }
  // none

{ GL_OES_fragment_precision_high }
  // none

{ GL_OES_get_program_binary }
const
  GL_PROGRAM_BINARY_LENGTH_OES                            = $8741;
  GL_NUM_PROGRAM_BINARY_FORMATS_OES                       = $87FE;
  GL_PROGRAM_BINARY_FORMATS_OES                           = $87FF;
type
  TglGetProgramBinaryOES                                  = procedure(aProgram: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aBinaryFormat: PGLenum; aBinary: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramBinaryOES                                     = procedure(aProgram: GLuint; aBinaryFormat: GLenum; const aBinary: Pointer; aLength: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetProgramBinaryOES:                                    TglGetProgramBinaryOES;
  glProgramBinaryOES:                                       TglProgramBinaryOES;

{ GL_OES_mapbuffer }
const
  GL_WRITE_ONLY_OES                                       = $88B9;
  GL_BUFFER_ACCESS_OES                                    = $88BB;
  GL_BUFFER_MAPPED_OES                                    = $88BC;
  GL_BUFFER_MAP_POINTER_OES                               = $88BD;
type
  TglMapBufferOES                                         = function (aTarget: GLenum; aAccess: GLenum): Pointer; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUnmapBufferOES                                       = function (aTarget: GLenum): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetBufferPointervOES                                 = procedure(aTarget: GLenum; aPname: GLenum; aParams: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glMapBufferOES:                                           TglMapBufferOES;
  glUnmapBufferOES:                                         TglUnmapBufferOES;
  glGetBufferPointervOES:                                   TglGetBufferPointervOES;

{ GL_OES_packed_depth_stencil }
const
  GL_DEPTH_STENCIL_OES                                    = $84F9;
  GL_UNSIGNED_INT_24_8_OES                                = $84FA;
  GL_DEPTH24_STENCIL8_OES                                 = $88F0;

{ GL_OES_required_internalformat }
const
  GL_ALPHA8_OES                                           = $803C;
  GL_DEPTH_COMPONENT16_OES                                = $81A5;
  GL_LUMINANCE4_ALPHA4_OES                                = $8043;
  GL_LUMINANCE8_ALPHA8_OES                                = $8045;
  GL_LUMINANCE8_OES                                       = $8040;
  GL_RGBA4_OES                                            = $8056;
  GL_RGB5_A1_OES                                          = $8057;
  GL_RGB565_OES                                           = $8D62;
  GL_RGB8_OES                                             = $8051;
  GL_RGBA8_OES                                            = $8058;
  GL_RGB10_EXT                                            = $8052;
  GL_RGB10_A2_EXT                                         = $8059;

{ GL_OES_rgb8_rgba8 }
  // none

{ GL_OES_sample_shading }
const
  GL_SAMPLE_SHADING_OES                                   = $8C36;
  GL_MIN_SAMPLE_SHADING_VALUE_OES                         = $8C37;
type
  TglMinSampleShadingOES                                  = procedure(aValue: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glMinSampleShadingOES:                                    TglMinSampleShadingOES;

{ GL_OES_sample_
variables }
  // none

{ GL_OES_shader_image_atomic }
  // none

{ GL_OES_shader_multisample_interpolation }
const
  GL_MIN_FRAGMENT_INTERPOLATION_OFFSET_OES                = $8E5B;
  GL_MAX_FRAGMENT_INTERPOLATION_OFFSET_OES                = $8E5C;
  GL_FRAGMENT_INTERPOLATION_OFFSET_BITS_OES               = $8E5D;

{ GL_OES_standard_derivatives }
const
  GL_FRAGMENT_SHADER_DERIVATIVE_HINT_OES                  = $8B8B;

{ GL_OES_stencil1 }
const
  GL_STENCIL_INDEX1_OES                                   = $8D46;

{ GL_OES_stencil4 }
const
  GL_STENCIL_INDEX4_OES                                   = $8D47;

{ GL_OES_surfaceless_context }
const
  GL_FRAMEBUFFER_UNDEFINED_OES                            = $8219;

{ GL_OES_texture_3D }
const
  GL_TEXTURE_WRAP_R_OES                                   = $8072;
  GL_TEXTURE_3D_OES                                       = $806F;
  GL_TEXTURE_BINDING_3D_OES                               = $806A;
  GL_MAX_3D_TEXTURE_SIZE_OES                              = $8073;
  GL_SAMPLER_3D_OES                                       = $8B5F;
  GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_3D_ZOFFSET_OES        = $8CD4;
type
  TglTexImage3DOES                                        = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aBorder: GLint; aFormat: GLenum; aType: GLenum; const aPixels: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexSubImage3DOES                                     = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFormat: GLenum; aType: GLenum; const aPixels: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyTexSubImage3DOES                                 = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexImage3DOES                              = procedure(aTarget: GLenum; aLevel: GLint; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aBorder: GLint; aImageSize: GLsizei; const aData: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCompressedTexSubImage3DOES                           = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFormat: GLenum; aImageSize: GLsizei; const aData: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferTexture3DOES                              = procedure(aTarget: GLenum; aAttachment: GLenum; aTextarget: GLenum; aTexture: GLuint; aLevel: GLint; aZoffset: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTexImage3DOES:                                          TglTexImage3DOES;
  glTexSubImage3DOES:                                       TglTexSubImage3DOES;
  glCopyTexSubImage3DOES:                                   TglCopyTexSubImage3DOES;
  glCompressedTexImage3DOES:                                TglCompressedTexImage3DOES;
  glCompressedTexSubImage3DOES:                             TglCompressedTexSubImage3DOES;
  glFramebufferTexture3DOES:                                TglFramebufferTexture3DOES;

{ GL_OES_texture_compression_astc }
const
  GL_COMPRESSED_RGBA_ASTC_3x3x3_OES                       = $93C0;
  GL_COMPRESSED_RGBA_ASTC_4x3x3_OES                       = $93C1;
  GL_COMPRESSED_RGBA_ASTC_4x4x3_OES                       = $93C2;
  GL_COMPRESSED_RGBA_ASTC_4x4x4_OES                       = $93C3;
  GL_COMPRESSED_RGBA_ASTC_5x4x4_OES                       = $93C4;
  GL_COMPRESSED_RGBA_ASTC_5x5x4_OES                       = $93C5;
  GL_COMPRESSED_RGBA_ASTC_5x5x5_OES                       = $93C6;
  GL_COMPRESSED_RGBA_ASTC_6x5x5_OES                       = $93C7;
  GL_COMPRESSED_RGBA_ASTC_6x6x5_OES                       = $93C8;
  GL_COMPRESSED_RGBA_ASTC_6x6x6_OES                       = $93C9;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_3x3x3_OES               = $93E0;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x3x3_OES               = $93E1;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4x3_OES               = $93E2;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4x4_OES               = $93E3;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4x4_OES               = $93E4;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5x4_OES               = $93E5;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5x5_OES               = $93E6;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5x5_OES               = $93E7;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6x5_OES               = $93E8;
  GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6x6_OES               = $93E9;

{ GL_OES_texture_float }
  // none

{ GL_OES_texture_float_linear }
  // none

{ GL_OES_texture_half_float }
const
  GL_HALF_FLOAT_OES                                       = $8D61;

{ GL_OES_texture_half_float_linear }
  // none

{ GL_OES_texture_npot }
  // none

{ GL_OES_texture_stencil8 }
const
  GL_STENCIL_INDEX_OES                                    = $1901;
  GL_STENCIL_INDEX8_OES                                   = $8D48;

{ GL_OES_texture_storage_multisample_2d_array }
const
  GL_TEXTURE_2D_MULTISAMPLE_ARRAY_OES                     = $9102;
  GL_TEXTURE_BINDING_2D_MULTISAMPLE_ARRAY_OES             = $9105;
  GL_SAMPLER_2D_MULTISAMPLE_ARRAY_OES                     = $910B;
  GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY_OES                 = $910C;
  GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY_OES        = $910D;
type
  TglTexStorage3DMultisampleOES                           = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFixedsamplelocations: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTexStorage3DMultisampleOES:                             TglTexStorage3DMultisampleOES;

{ GL_OES_vertex_array_object }
const
  GL_VERTEX_ARRAY_BINDING_OES                             = $85B5;
type
  TglBindVertexArrayOES                                   = procedure(aArray: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteVertexArraysOES                                = procedure(n: GLsizei; const aArrays: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenVertexArraysOES                                   = procedure(n: GLsizei; aArrays: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsVertexArrayOES                                     = function (aArray: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBindVertexArrayOES:                                     TglBindVertexArrayOES;
  glDeleteVertexArraysOES:                                  TglDeleteVertexArraysOES;
  glGenVertexArraysOES:                                     TglGenVertexArraysOES;
  glIsVertexArrayOES:                                       TglIsVertexArrayOES;

{ GL_OES_vertex_half_float }
  // none                      {$IFDEF OPENGLES_EXTENSIONS}

{ GL_OES_vertex_type_10_10_10_2 }
const
  GL_UNSIGNED_INT_10_10_10_2_OES                          = $8DF6;
  GL_INT_10_10_10_2_OES                                   = $8DF7;

{ GL_AMD_compressed_3DC_texture }
const
  GL_3DC_X_AMD                                            = $87F9;
  GL_3DC_XY_AMD                                           = $87FA;

{ GL_AMD_compressed_ATC_texture }
const
  GL_ATC_RGB_AMD                                          = $8C92;
  GL_ATC_RGBA_EXPLICIT_ALPHA_AMD                          = $8C93;
  GL_ATC_RGBA_INTERPOLATED_ALPHA_AMD                      = $87EE;

{ GL_AMD_performance_monitor }
const
  GL_COUNTER_TYPE_AMD                                     = $8BC0;
  GL_COUNTER_RANGE_AMD                                    = $8BC1;
  GL_UNSIGNED_INT64_AMD                                   = $8BC2;
  GL_PERCENTAGE_AMD                                       = $8BC3;
  GL_PERFMON_RESULT_AVAILABLE_AMD                         = $8BC4;
  GL_PERFMON_RESULT_SIZE_AMD                              = $8BC5;
  GL_PERFMON_RESULT_AMD                                   = $8BC6;
type
  TglGetPerfMonitorGroupsAMD                              = procedure(aNumGroups: PGLint; aGroupsSize: GLsizei; aGroups: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfMonitorCountersAMD                            = procedure(aGroup: GLuint; aNumCounters: PGLint; aMaxActiveCounters: PGLint; aCounterSize: GLsizei; aCounters: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfMonitorGroupStringAMD                         = procedure(aGroup: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aGroupString: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfMonitorCounterStringAMD                       = procedure(aGroup: GLuint; aCounter: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aCounterString: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfMonitorCounterInfoAMD                         = procedure(aGroup: GLuint; aCounter: GLuint; aPname: GLenum; aData: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenPerfMonitorsAMD                                   = procedure(n: GLsizei; aMonitors: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeletePerfMonitorsAMD                                = procedure(n: GLsizei; aMonitors: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSelectPerfMonitorCountersAMD                         = procedure(aMonitor: GLuint; aEnable: GLboolean; aGroup: GLuint; aNumCounters: GLint; aCounterList: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBeginPerfMonitorAMD                                  = procedure(aMonitor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndPerfMonitorAMD                                    = procedure(aMonitor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfMonitorCounterDataAMD                         = procedure(aMonitor: GLuint; aPname: GLenum; aDataSize: GLsizei; aData: PGLuint; aBytesWritten: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetPerfMonitorGroupsAMD:                                TglGetPerfMonitorGroupsAMD;
  glGetPerfMonitorCountersAMD:                              TglGetPerfMonitorCountersAMD;
  glGetPerfMonitorGroupStringAMD:                           TglGetPerfMonitorGroupStringAMD;
  glGetPerfMonitorCounterStringAMD:                         TglGetPerfMonitorCounterStringAMD;
  glGetPerfMonitorCounterInfoAMD:                           TglGetPerfMonitorCounterInfoAMD;
  glGenPerfMonitorsAMD:                                     TglGenPerfMonitorsAMD;
  glDeletePerfMonitorsAMD:                                  TglDeletePerfMonitorsAMD;
  glSelectPerfMonitorCountersAMD:                           TglSelectPerfMonitorCountersAMD;
  glBeginPerfMonitorAMD:                                    TglBeginPerfMonitorAMD;
  glEndPerfMonitorAMD:                                      TglEndPerfMonitorAMD;
  glGetPerfMonitorCounterDataAMD:                           TglGetPerfMonitorCounterDataAMD;

{ GL_AMD_program_binary_Z400 }
const
  GL_Z400_BINARY_AMD                                      = $8740;

{ GL_ANDROID_extension_pack_es31a }
  // none

{ GL_ANGLE_depth_texture }
  // none

{ GL_ANGLE_framebuffer_blit }
const
  GL_READ_FRAMEBUFFER_ANGLE                               = $8CA8;
  GL_DRAW_FRAMEBUFFER_ANGLE                               = $8CA9;
  GL_DRAW_FRAMEBUFFER_BINDING_ANGLE                       = $8CA6;
  GL_READ_FRAMEBUFFER_BINDING_ANGLE                       = $8CAA;
type
  TglBlitFramebufferANGLE                                 = procedure(aSrcX0: GLint; aSrcY0: GLint; aSrcX1: GLint; aSrcY1: GLint; aDstX0: GLint; aDstY0: GLint; aDstX1: GLint; aDstY1: GLint; aMask: GLbitfield; aFilter: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBlitFramebufferANGLE:                                   TglBlitFramebufferANGLE;

{ GL_ANGLE_framebuffer_multisample }
const
  GL_RENDERBUFFER_SAMPLES_ANGLE                           = $8CAB;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_ANGLE             = $8D56;
  GL_MAX_SAMPLES_ANGLE                                    = $8D57;
type
  TglRenderbufferStorageMultisampleANGLE                  = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glRenderbufferStorageMultisampleANGLE:                    TglRenderbufferStorageMultisampleANGLE;

{ GL_ANGLE_instanced_arrays }
const
  GL_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE                    = $88FE;
type
  TglDrawArraysInstancedANGLE                             = procedure(aMode: GLenum; aFirst: GLint; aCount: GLsizei; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedANGLE                           = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglVertexAttribDivisorANGLE                             = procedure(aIndex: GLuint; aDivisor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawArraysInstancedANGLE:                               TglDrawArraysInstancedANGLE;
  glDrawElementsInstancedANGLE:                             TglDrawElementsInstancedANGLE;
  glVertexAttribDivisorANGLE:                               TglVertexAttribDivisorANGLE;

{ GL_ANGLE_pack_reverse_row_order }
const
  GL_PACK_REVERSE_ROW_ORDER_ANGLE                         = $93A4;

{ GL_ANGLE_program_binary }
const
  GL_PROGRAM_BINARY_ANGLE                                 = $93A6;

{ GL_ANGLE_texture_compression_dxt3 }
const
  GL_COMPRESSED_RGBA_S3TC_DXT3_ANGLE                      = $83F2;

{ GL_ANGLE_texture_compression_dxt5 }
const
  GL_COMPRESSED_RGBA_S3TC_DXT5_ANGLE                      = $83F3;

{ GL_ANGLE_texture_usage }
const
  GL_TEXTURE_USAGE_ANGLE                                  = $93A2;
  GL_FRAMEBUFFER_ATTACHMENT_ANGLE                         = $93A3;

{ GL_ANGLE_translated_shader_source }
const
  GL_TRANSLATED_SHADER_SOURCE_LENGTH_ANGLE                = $93A0;
type
  TglGetTranslatedShaderSourceANGLE                       = procedure(aShader: GLuint; aBufsize: GLsizei; aLength: PGLsizei; aSource: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetTranslatedShaderSourceANGLE:                         TglGetTranslatedShaderSourceANGLE;

{ GL_APPLE_clip_distance }
const
  GL_MAX_CLIP_DISTANCES_APPLE                             = $0D32;
  GL_CLIP_DISTANCE0_APPLE                                 = $3000;
  GL_CLIP_DISTANCE1_APPLE                                 = $3001;
  GL_CLIP_DISTANCE2_APPLE                                 = $3002;
  GL_CLIP_DISTANCE3_APPLE                                 = $3003;
  GL_CLIP_DISTANCE4_APPLE                                 = $3004;
  GL_CLIP_DISTANCE5_APPLE                                 = $3005;
  GL_CLIP_DISTANCE6_APPLE                                 = $3006;
  GL_CLIP_DISTANCE7_APPLE                                 = $3007;

{ GL_APPLE_color_buffer_packed_float }
  // none

{ GL_APPLE_copy_texture_levels }
type
  TglCopyTextureLevelsAPPLE                               = procedure(aDestinationTexture: GLuint; aSourceTexture: GLuint; aSourceBaseLevel: GLint; aSourceLevelCount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glCopyTextureLevelsAPPLE:                                 TglCopyTextureLevelsAPPLE;

{ GL_APPLE_framebuffer_multisample }
const
  GL_RENDERBUFFER_SAMPLES_APPLE                           = $8CAB;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_APPLE             = $8D56;
  GL_MAX_SAMPLES_APPLE                                    = $8D57;
  GL_READ_FRAMEBUFFER_APPLE                               = $8CA8;
  GL_DRAW_FRAMEBUFFER_APPLE                               = $8CA9;
  GL_DRAW_FRAMEBUFFER_BINDING_APPLE                       = $8CA6;
  GL_READ_FRAMEBUFFER_BINDING_APPLE                       = $8CAA;
type
  TglRenderbufferStorageMultisampleAPPLE                  = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglResolveMultisampleFramebufferAPPLE                   = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glRenderbufferStorageMultisampleAPPLE:                    TglRenderbufferStorageMultisampleAPPLE;
  glResolveMultisampleFramebufferAPPLE:                     TglResolveMultisampleFramebufferAPPLE;

{ GL_APPLE_rgb_422 }
const
  GL_RGB_422_APPLE                                        = $8A1F;
  GL_UNSIGNED_SHORT_8_8_APPLE                             = $85BA;
  GL_UNSIGNED_SHORT_8_8_REV_APPLE                         = $85BB;
  GL_RGB_RAW_422_APPLE                                    = $8A51;

{ GL_APPLE_sync }
const
  GL_SYNC_OBJECT_APPLE                                    = $8A53;
  GL_MAX_SERVER_WAIT_TIMEOUT_APPLE                        = $9111;
  GL_OBJECT_TYPE_APPLE                                    = $9112;
  GL_SYNC_CONDITION_APPLE                                 = $9113;
  GL_SYNC_STATUS_APPLE                                    = $9114;
  GL_SYNC_FLAGS_APPLE                                     = $9115;
  GL_SYNC_FENCE_APPLE                                     = $9116;
  GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE                     = $9117;
  GL_UNSIGNALED_APPLE                                     = $9118;
  GL_SIGNALED_APPLE                                       = $9119;
  GL_ALREADY_SIGNALED_APPLE                               = $911A;
  GL_TIMEOUT_EXPIRED_APPLE                                = $911B;
  GL_CONDITION_SATISFIED_APPLE                            = $911C;
  GL_WAIT_FAILED_APPLE                                    = $911D;
  GL_SYNC_FLUSH_COMMANDS_BIT_APPLE                        = $00000001;
  GL_TIMEOUT_IGNORED_APPLE                                = $FFFFFFFFFFFFFFFF;
type
  TglFenceSyncAPPLE                                       = function (aCondition: GLenum; aFlags: GLbitfield): GLsync; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsSyncAPPLE                                          = function (aSync: GLsync): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteSyncAPPLE                                      = procedure(aSync: GLsync); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglClientWaitSyncAPPLE                                  = function (aSync: GLsync; aFlags: GLbitfield; aTimeout: GLuint64): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglWaitSyncAPPLE                                        = procedure(aSync: GLsync; aFlags: GLbitfield; aTimeout: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetInteger64vAPPLE                                   = procedure(aPname: GLenum; aParams: PGLint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSyncivAPPLE                                       = procedure(aSync: GLsync; aPname: GLenum; aBufSize: GLsizei; aLength: PGLsizei; aValues: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glFenceSyncAPPLE:                                         TglFenceSyncAPPLE;
  glIsSyncAPPLE:                                            TglIsSyncAPPLE;
  glDeleteSyncAPPLE:                                        TglDeleteSyncAPPLE;
  glClientWaitSyncAPPLE:                                    TglClientWaitSyncAPPLE;
  glWaitSyncAPPLE:                                          TglWaitSyncAPPLE;
  glGetInteger64vAPPLE:                                     TglGetInteger64vAPPLE;
  glGetSyncivAPPLE:                                         TglGetSyncivAPPLE;

{ GL_APPLE_texture_format_BGRA8888 }
const
  GL_BGRA_EXT                                             = $80E1;
  GL_BGRA8_EXT                                            = $93A1;

{ GL_APPLE_texture_max_level }
const
  GL_TEXTURE_MAX_LEVEL_APPLE                              = $813D;

{ GL_APPLE_texture_packed_float }
const
  GL_UNSIGNED_INT_10F_11F_11F_REV_APPLE                   = $8C3B;
  GL_UNSIGNED_INT_5_9_9_9_REV_APPLE                       = $8C3E;
  GL_R11F_G11F_B10F_APPLE                                 = $8C3A;
  GL_RGB9_E5_APPLE                                        = $8C3D;

{ GL_ARM_mali_program_binary }
const
  GL_MALI_PROGRAM_BINARY_ARM                              = $8F61;

{ GL_ARM_mali_shader_binary }
const
  GL_MALI_SHADER_BINARY_ARM                               = $8F60;

{ GL_ARM_rgba8 }
  // none

{ GL_ARM_shader_framebuffer_fetch }
const
  GL_FETCH_PER_SAMPLE_ARM                                 = $8F65;
  GL_FRAGMENT_SHADER_FRAMEBUFFER_FETCH_MRT_ARM            = $8F66;

{ GL_ARM_shader_framebuffer_fetch_depth_stencil }

{ GL_DMP_program_binary }
const
  GL_SMAPHS30_PROGRAM_BINARY_DMP                          = $9251;
  GL_SMAPHS_PROGRAM_BINARY_DMP                            = $9252;
  GL_DMP_PROGRAM_BINARY_DMP                               = $9253;

{ GL_DMP_shader_binary }
const
  GL_SHADER_BINARY_DMP                                    = $9250;

{ GL_EXT_base_instance }
type
  TglDrawArraysInstancedBaseInstanceEXT                   = procedure(aMode: GLenum; aFirst: GLint; aCount: GLsizei; aInstancecount: GLsizei; aBaseinstance: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedBaseInstanceEXT                 = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aInstancecount: GLsizei; aBaseinstance: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedBaseVertexBaseInstanceEXT       = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aInstancecount: GLsizei; aBasevertex: GLint; aBaseinstance: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawArraysInstancedBaseInstanceEXT:                     TglDrawArraysInstancedBaseInstanceEXT;
  glDrawElementsInstancedBaseInstanceEXT:                   TglDrawElementsInstancedBaseInstanceEXT;
  glDrawElementsInstancedBaseVertexBaseInstanceEXT:         TglDrawElementsInstancedBaseVertexBaseInstanceEXT;

{ GL_EXT_blend_minmax }
const
  GL_MIN_EXT                                              = $8007;
  GL_MAX_EXT                                              = $8008;

{ GL_EXT_color_buffer_half_float }
const
  GL_RGBA16F_EXT                                          = $881A;
  GL_RGB16F_EXT                                           = $881B;
  GL_RG16F_EXT                                            = $822F;
  GL_R16F_EXT                                             = $822D;
  GL_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT            = $8211;
  GL_UNSIGNED_NORMALIZED_EXT                              = $8C17;

{ GL_EXT_copy_image }
type
  TglCopyImageSubDataEXT                                  = procedure(aSrcName: GLuint; aSrcTarget: GLenum; aSrcLevel: GLint; aSrcX: GLint; aSrcY: GLint; aSrcZ: GLint; aDstName: GLuint; aDstTarget: GLenum; aDstLevel: GLint; aDstX: GLint; aDstY: GLint; aDstZ: GLint; aSrcWidth: GLsizei; aSrcHeight: GLsizei; aSrcDepth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glCopyImageSubDataEXT:                                    TglCopyImageSubDataEXT;

{ GL_EXT_debug_label }
const
  GL_PROGRAM_PIPELINE_OBJECT_EXT                          = $8A4F;
  GL_PROGRAM_OBJECT_EXT                                   = $8B40;
  GL_SHADER_OBJECT_EXT                                    = $8B48;
  GL_BUFFER_OBJECT_EXT                                    = $9151;
  GL_QUERY_OBJECT_EXT                                     = $9153;
  GL_VERTEX_ARRAY_OBJECT_EXT                              = $9154;
  // GL_TRANSFORM_FEEDBACK                                = $8E22;
type
  TglLabelObjectEXT                                       = procedure(aType: GLenum; aObject: GLuint; aLength: GLsizei; const aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetObjectLabelEXT                                    = procedure(aType: GLenum; aObject: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aLabel: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glLabelObjectEXT:                                         TglLabelObjectEXT;
  glGetObjectLabelEXT:                                      TglGetObjectLabelEXT;

{ GL_EXT_debug_marker }
type
  TglInsertEventMarkerEXT                                 = procedure(aLength: GLsizei; const aMarker: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPushGroupMarkerEXT                                   = procedure(aLength: GLsizei; const aMarker: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPopGroupMarkerEXT                                    = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glInsertEventMarkerEXT:                                   TglInsertEventMarkerEXT;
  glPushGroupMarkerEXT:                                     TglPushGroupMarkerEXT;
  glPopGroupMarkerEXT:                                      TglPopGroupMarkerEXT;

{ GL_EXT_discard_framebuffer }
const
  GL_COLOR_EXT                                            = $1800;
  GL_DEPTH_EXT                                            = $1801;
  GL_STENCIL_EXT                                          = $1802;
type
  TglDiscardFramebufferEXT                                = procedure(aTarget: GLenum; aNumAttachments: GLsizei; const aAttachments: PGLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDiscardFramebufferEXT:                                  TglDiscardFramebufferEXT;

{ GL_EXT_disjoint_timer_query }
const
  GL_QUERY_COUNTER_BITS_EXT                               = $8864;
  GL_CURRENT_QUERY_EXT                                    = $8865;
  GL_QUERY_RESULT_EXT                                     = $8866;
  GL_QUERY_RESULT_AVAILABLE_EXT                           = $8867;
  GL_TIME_ELAPSED_EXT                                     = $88BF;
  GL_TIMESTAMP_EXT                                        = $8E28;
  GL_GPU_DISJOINT_EXT                                     = $8FBB;
type
  TglGenQueriesEXT                                        = procedure(n: GLsizei; aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteQueriesEXT                                     = procedure(n: GLsizei; const aIds: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsQueryEXT                                           = function (aId: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBeginQueryEXT                                        = procedure(aTarget: GLenum; aId: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndQueryEXT                                          = procedure(aTarget: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglQueryCounterEXT                                      = procedure(aId: GLuint; aTarget: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryivEXT                                        = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryObjectivEXT                                  = procedure(aId: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryObjectuivEXT                                 = procedure(aId: GLuint; aPname: GLenum; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryObjecti64vEXT                                = procedure(aId: GLuint; aPname: GLenum; aParams: PGLint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetQueryObjectui64vEXT                               = procedure(aId: GLuint; aPname: GLenum; aParams: PGLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGenQueriesEXT:                                          TglGenQueriesEXT;
  glDeleteQueriesEXT:                                       TglDeleteQueriesEXT;
  glIsQueryEXT:                                             TglIsQueryEXT;
  glBeginQueryEXT:                                          TglBeginQueryEXT;
  glEndQueryEXT:                                            TglEndQueryEXT;
  glQueryCounterEXT:                                        TglQueryCounterEXT;
  glGetQueryivEXT:                                          TglGetQueryivEXT;
  glGetQueryObjectivEXT:                                    TglGetQueryObjectivEXT;
  glGetQueryObjectuivEXT:                                   TglGetQueryObjectuivEXT;
  glGetQueryObjecti64vEXT:                                  TglGetQueryObjecti64vEXT;
  glGetQueryObjectui64vEXT:                                 TglGetQueryObjectui64vEXT;

{ GL_EXT_draw_buffers }
const
  GL_MAX_COLOR_ATTACHMENTS_EXT                            = $8CDF;
  GL_MAX_DRAW_BUFFERS_EXT                                 = $8824;
  GL_DRAW_BUFFER0_EXT                                     = $8825;
  GL_DRAW_BUFFER1_EXT                                     = $8826;
  GL_DRAW_BUFFER2_EXT                                     = $8827;
  GL_DRAW_BUFFER3_EXT                                     = $8828;
  GL_DRAW_BUFFER4_EXT                                     = $8829;
  GL_DRAW_BUFFER5_EXT                                     = $882A;
  GL_DRAW_BUFFER6_EXT                                     = $882B;
  GL_DRAW_BUFFER7_EXT                                     = $882C;
  GL_DRAW_BUFFER8_EXT                                     = $882D;
  GL_DRAW_BUFFER9_EXT                                     = $882E;
  GL_DRAW_BUFFER10_EXT                                    = $882F;
  GL_DRAW_BUFFER11_EXT                                    = $8830;
  GL_DRAW_BUFFER12_EXT                                    = $8831;
  GL_DRAW_BUFFER13_EXT                                    = $8832;
  GL_DRAW_BUFFER14_EXT                                    = $8833;
  GL_DRAW_BUFFER15_EXT                                    = $8834;
  GL_COLOR_ATTACHMENT0_EXT                                = $8CE0;
  GL_COLOR_ATTACHMENT1_EXT                                = $8CE1;
  GL_COLOR_ATTACHMENT2_EXT                                = $8CE2;
  GL_COLOR_ATTACHMENT3_EXT                                = $8CE3;
  GL_COLOR_ATTACHMENT4_EXT                                = $8CE4;
  GL_COLOR_ATTACHMENT5_EXT                                = $8CE5;
  GL_COLOR_ATTACHMENT6_EXT                                = $8CE6;
  GL_COLOR_ATTACHMENT7_EXT                                = $8CE7;
  GL_COLOR_ATTACHMENT8_EXT                                = $8CE8;
  GL_COLOR_ATTACHMENT9_EXT                                = $8CE9;
  GL_COLOR_ATTACHMENT10_EXT                               = $8CEA;
  GL_COLOR_ATTACHMENT11_EXT                               = $8CEB;
  GL_COLOR_ATTACHMENT12_EXT                               = $8CEC;
  GL_COLOR_ATTACHMENT13_EXT                               = $8CED;
  GL_COLOR_ATTACHMENT14_EXT                               = $8CEE;
  GL_COLOR_ATTACHMENT15_EXT                               = $8CEF;
type
  TglDrawBuffersEXT                                       = procedure(n: GLsizei; const aBufs: PGLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawBuffersEXT:                                         TglDrawBuffersEXT;

{ GL_EXT_draw_buffers_indexed }
  //GL_MIN                                                = $8007;
  //GL_MAX                                                = $8008;
type
  TglEnableiEXT                                           = procedure(aTarget: GLenum; aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisableiEXT                                          = procedure(aTarget: GLenum; aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendEquationiEXT                                    = procedure(aBuf: GLuint; aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendEquationSeparateiEXT                            = procedure(aBuf: GLuint; aModeRGB: GLenum; aModeAlpha: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendFunciEXT                                        = procedure(aBuf: GLuint; aSrc: GLenum; aDst: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendFuncSeparateiEXT                                = procedure(aBuf: GLuint; aSrcRGB: GLenum; aDstRGB: GLenum; aSrcAlpha: GLenum; aDstAlpha: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglColorMaskiEXT                                        = procedure(aIndex: GLuint; r: GLboolean; g: GLboolean; b: GLboolean; a: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsEnablediEXT                                        = function (aTarget: GLenum; aIndex: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glEnableiEXT:                                             TglEnableiEXT;
  glDisableiEXT:                                            TglDisableiEXT;
  glBlendEquationiEXT:                                      TglBlendEquationiEXT;
  glBlendEquationSeparateiEXT:                              TglBlendEquationSeparateiEXT;
  glBlendFunciEXT:                                          TglBlendFunciEXT;
  glBlendFuncSeparateiEXT:                                  TglBlendFuncSeparateiEXT;
  glColorMaskiEXT:                                          TglColorMaskiEXT;
  glIsEnablediEXT:                                          TglIsEnablediEXT;

{ GL_EXT_draw_elements_base_vertex }
type
  TglDrawElementsBaseVertexEXT                            = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aBasevertex: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawRangeElementsBaseVertexEXT                       = procedure(aMode: GLenum; aStart: GLuint; aEnd: GLuint; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aBasevertex: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedBaseVertexEXT                   = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aInstancecount: GLsizei; aBasevertex: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultiDrawElementsBaseVertexEXT                       = procedure(aMode: GLenum; const aCount: PGLsizei; aType: GLenum; const aConstPindices: Pointer; aPrimcount: GLsizei; const aBasevertex: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawElementsBaseVertexEXT:                              TglDrawElementsBaseVertexEXT;
  glDrawRangeElementsBaseVertexEXT:                         TglDrawRangeElementsBaseVertexEXT;
  glDrawElementsInstancedBaseVertexEXT:                     TglDrawElementsInstancedBaseVertexEXT;
  glMultiDrawElementsBaseVertexEXT:                         TglMultiDrawElementsBaseVertexEXT;

{ GL_EXT_draw_instanced }
type
  TglDrawArraysInstancedEXT                               = procedure(aMode: GLenum; aStart: GLint; aCount: GLsizei; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedEXT                             = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawArraysInstancedEXT:                                 TglDrawArraysInstancedEXT;
  glDrawElementsInstancedEXT:                               TglDrawElementsInstancedEXT;

{ GL_EXT_geometry_point_size }

{ GL_EXT_geometry_shader }
const
  GL_GEOMETRY_SHADER_EXT                                  = $8DD9;
  GL_GEOMETRY_SHADER_BIT_EXT                              = $00000004;
  GL_GEOMETRY_LINKED_VERTICES_OUT_EXT                     = $8916;
  GL_GEOMETRY_LINKED_INPUT_TYPE_EXT                       = $8917;
  GL_GEOMETRY_LINKED_OUTPUT_TYPE_EXT                      = $8918;
  GL_GEOMETRY_SHADER_INVOCATIONS_EXT                      = $887F;
  GL_LAYER_PROVOKING_VERTEX_EXT                           = $825E;
  GL_LINES_ADJACENCY_EXT                                  = $000A;
  GL_LINE_STRIP_ADJACENCY_EXT                             = $000B;
  GL_TRIANGLES_ADJACENCY_EXT                              = $000C;
  GL_TRIANGLE_STRIP_ADJACENCY_EXT                         = $000D;
  GL_MAX_GEOMETRY_UNIFORM_COMPONENTS_EXT                  = $8DDF;
  GL_MAX_GEOMETRY_UNIFORM_BLOCKS_EXT                      = $8A2C;
  GL_MAX_COMBINED_GEOMETRY_UNIFORM_COMPONENTS_EXT         = $8A32;
  GL_MAX_GEOMETRY_INPUT_COMPONENTS_EXT                    = $9123;
  GL_MAX_GEOMETRY_OUTPUT_COMPONENTS_EXT                   = $9124;
  GL_MAX_GEOMETRY_OUTPUT_VERTICES_EXT                     = $8DE0;
  GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS_EXT             = $8DE1;
  GL_MAX_GEOMETRY_SHADER_INVOCATIONS_EXT                  = $8E5A;
  GL_MAX_GEOMETRY_TEXTURE_IMAGE_UNITS_EXT                 = $8C29;
  GL_MAX_GEOMETRY_ATOMIC_COUNTER_BUFFERS_EXT              = $92CF;
  GL_MAX_GEOMETRY_ATOMIC_COUNTERS_EXT                     = $92D5;
  GL_MAX_GEOMETRY_IMAGE_UNIFORMS_EXT                      = $90CD;
  GL_MAX_GEOMETRY_SHADER_STORAGE_BLOCKS_EXT               = $90D7;
  GL_FIRST_VERTEX_CONVENTION_EXT                          = $8E4D;
  GL_LAST_VERTEX_CONVENTION_EXT                           = $8E4E;
  GL_UNDEFINED_VERTEX_EXT                                 = $8260;
  GL_PRIMITIVES_GENERATED_EXT                             = $8C87;
  GL_FRAMEBUFFER_DEFAULT_LAYERS_EXT                       = $9312;
  GL_MAX_FRAMEBUFFER_LAYERS_EXT                           = $9317;
  GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS_EXT             = $8DA8;
  GL_FRAMEBUFFER_ATTACHMENT_LAYERED_EXT                   = $8DA7;
  GL_REFERENCED_BY_GEOMETRY_SHADER_EXT                    = $9309;
type
  TglFramebufferTextureEXT                                = procedure(aTarget: GLenum; aAttachment: GLenum; aTexture: GLuint; aLevel: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glFramebufferTextureEXT:                                  TglFramebufferTextureEXT;

{ GL_EXT_gpu_shader5 }
  // none

{ GL_EXT_instanced_arrays }
const
  GL_VERTEX_ATTRIB_ARRAY_DIVISOR_EXT                      = $88FE;
type
  TglVertexAttribDivisorEXT                               = procedure(aIndex: GLuint; aDivisor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glVertexAttribDivisorEXT:                                 TglVertexAttribDivisorEXT;

{ GL_EXT_map_buffer_range }
const
  GL_MAP_READ_BIT_EXT                                     = $0001;
  GL_MAP_WRITE_BIT_EXT                                    = $0002;
  GL_MAP_INVALIDATE_RANGE_BIT_EXT                         = $0004;
  GL_MAP_INVALIDATE_BUFFER_BIT_EXT                        = $0008;
  GL_MAP_FLUSH_EXPLICIT_BIT_EXT                           = $0010;
  GL_MAP_UNSYNCHRONIZED_BIT_EXT                           = $0020;
type
  TglMapBufferRangeEXT                                    = function (aTarget: GLenum; aOffset: GLintptr; aLength: GLsizeiptr; aAccess: GLbitfield): Pointer; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFlushMappedBufferRangeEXT                            = procedure(aTarget: GLenum; aOffset: GLintptr; aLength: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glMapBufferRangeEXT:                                      TglMapBufferRangeEXT;
  glFlushMappedBufferRangeEXT:                              TglFlushMappedBufferRangeEXT;

{ GL_EXT_multi_draw_arrays }
type
  TglMultiDrawArraysEXT                                   = procedure(aMode: GLenum; const aFirst: PGLint; const aCount: PGLsizei; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultiDrawElementsEXT                                 = procedure(aMode: GLenum; const aCount: PGLsizei; aType: GLenum; const aConstPindices: Pointer; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glMultiDrawArraysEXT:                                     TglMultiDrawArraysEXT;
  glMultiDrawElementsEXT:                                   TglMultiDrawElementsEXT;

{ GL_EXT_multi_draw_indirect }
type
  TglMultiDrawArraysIndirectEXT                           = procedure(aMode: GLenum; const aIndirect: Pointer; aDrawcount: GLsizei; aStride: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMultiDrawElementsIndirectEXT                         = procedure(aMode: GLenum; aType: GLenum; const aIndirect: Pointer; aDrawcount: GLsizei; aStride: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glMultiDrawArraysIndirectEXT:                             TglMultiDrawArraysIndirectEXT;
  glMultiDrawElementsIndirectEXT:                           TglMultiDrawElementsIndirectEXT;

{ GL_EXT_multisampled_render_to_texture }
const
  GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_SAMPLES_EXT           = $8D6C;
  GL_RENDERBUFFER_SAMPLES_EXT                             = $8CAB;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_EXT               = $8D56;
  GL_MAX_SAMPLES_EXT                                      = $8D57;
type
  TglRenderbufferStorageMultisampleEXT                    = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferTexture2DMultisampleEXT                   = procedure(aTarget: GLenum; aAttachment: GLenum; aTextarget: GLenum; aTexture: GLuint; aLevel: GLint; aSamples: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glRenderbufferStorageMultisampleEXT:                      TglRenderbufferStorageMultisampleEXT;
  glFramebufferTexture2DMultisampleEXT:                     TglFramebufferTexture2DMultisampleEXT;

{ GL_EXT_multiview_draw_buffers }
const
  GL_COLOR_ATTACHMENT_EXT                                 = $90F0;
  GL_MULTIVIEW_EXT                                        = $90F1;
  GL_DRAW_BUFFER_EXT                                      = $0C01;
  GL_READ_BUFFER_EXT                                      = $0C02;
  GL_MAX_MULTIVIEW_BUFFERS_EXT                            = $90F2;
type
  TglReadBufferIndexedEXT                                 = procedure(aSrc: GLenum; aIndex: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawBuffersIndexedEXT                                = procedure(n: GLint; const aLocation: PGLenum; const aIndices: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetIntegeri_vEXT                                     = procedure(aTarget: GLenum; aIndex: GLuint; aData: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glReadBufferIndexedEXT:                                   TglReadBufferIndexedEXT;
  glDrawBuffersIndexedEXT:                                  TglDrawBuffersIndexedEXT;
  glGetIntegeri_vEXT:                                       TglGetIntegeri_vEXT;

{ GL_EXT_occlusion_query_boolean }
const
  GL_ANY_SAMPLES_PASSED_EXT                               = $8C2F;
  GL_ANY_SAMPLES_PASSED_CONSERVATIVE_EXT                  = $8D6A;

{ GL_EXT_primitive_bounding_box }
const
  GL_PRIMITIVE_BOUNDING_BOX_EXT                           = $92BE;
type
  TglPrimitiveBoundingBoxEXT                              = procedure(aMinX: GLfloat; aMinY: GLfloat; aMinZ: GLfloat; aMinW: GLfloat; aMaxX: GLfloat; aMaxY: GLfloat; aMaxZ: GLfloat; aMaxW: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glPrimitiveBoundingBoxEXT:                                TglPrimitiveBoundingBoxEXT;

{ GL_EXT_pvrtc_sRGB }
const
  GL_COMPRESSED_SRGB_PVRTC_2BPPV1_EXT                     = $8A54;
  GL_COMPRESSED_SRGB_PVRTC_4BPPV1_EXT                     = $8A55;
  GL_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV1_EXT               = $8A56;
  GL_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT               = $8A57;
  GL_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV2_IMG               = $93F0;
  GL_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV2_IMG               = $93F1;

{ GL_EXT_read_format_bgra }
const
  GL_UNSIGNED_SHORT_4_4_4_4_REV_EXT                       = $8365;
  GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT                       = $8366;

{ GL_EXT_render_snorm }
const
  //GL_R8_SNORM                                           = $8F94;
  //GL_RG8_SNORM                                          = $8F95;
  //GL_RGBA8_SNORM                                        = $8F97;
  GL_R16_SNORM_EXT                                        = $8F98;
  GL_RG16_SNORM_EXT                                       = $8F99;
  GL_RGBA16_SNORM_EXT                                     = $8F9B;

{ GL_EXT_robustness }
const
  GL_GUILTY_CONTEXT_RESET_EXT                             = $8253;
  GL_INNOCENT_CONTEXT_RESET_EXT                           = $8254;
  GL_UNKNOWN_CONTEXT_RESET_EXT                            = $8255;
  GL_CONTEXT_ROBUST_ACCESS_EXT                            = $90F3;
  GL_RESET_NOTIFICATION_STRATEGY_EXT                      = $8256;
  GL_LOSE_CONTEXT_ON_RESET_EXT                            = $8252;
  GL_NO_RESET_NOTIFICATION_EXT                            = $8261;
type
  TglGetGraphicsResetStatusEXT                            = function : GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglReadnPixelsEXT                                       = procedure(x: GLint; y: GLint; aWidth: GLsizei; aHeight: GLsizei; aFormat: GLenum; aType: GLenum; aBufSize: GLsizei; aData: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetnUniformfvEXT                                     = procedure(aProgram: GLuint; aLocation: GLint; aBufSize: GLsizei; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetnUniformivEXT                                     = procedure(aProgram: GLuint; aLocation: GLint; aBufSize: GLsizei; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetGraphicsResetStatusEXT:                              TglGetGraphicsResetStatusEXT;
  glReadnPixelsEXT:                                         TglReadnPixelsEXT;
  glGetnUniformfvEXT:                                       TglGetnUniformfvEXT;
  glGetnUniformivEXT:                                       TglGetnUniformivEXT;

{ GL_EXT_sRGB }
const
  GL_SRGB_EXT                                             = $8C40;
  GL_SRGB_ALPHA_EXT                                       = $8C42;
  GL_SRGB8_ALPHA8_EXT                                     = $8C43;
  GL_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT            = $8210;

{ GL_EXT_sRGB_write_control }
const
  GL_FRAMEBUFFER_SRGB_EXT                                 = $8DB9;

{ GL_EXT_separate_shader_objects }
const
  GL_ACTIVE_PROGRAM_EXT                                   = $8259;
  GL_VERTEX_SHADER_BIT_EXT                                = $00000001;
  GL_FRAGMENT_SHADER_BIT_EXT                              = $00000002;
  GL_ALL_SHADER_BITS_EXT                                  = $FFFFFFFF;
  GL_PROGRAM_SEPARABLE_EXT                                = $8258;
  GL_PROGRAM_PIPELINE_BINDING_EXT                         = $825A;
type
  TglActiveShaderProgramEXT                               = procedure(aPipeline: GLuint; aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBindProgramPipelineEXT                               = procedure(aPipeline: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCreateShaderProgramvEXT                              = function (aType: GLenum; aCount: GLsizei; const aStrings: PPGLchar): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeleteProgramPipelinesEXT                            = procedure(n: GLsizei; const aPipelines: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenProgramPipelinesEXT                               = procedure(n: GLsizei; aPipelines: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramPipelineInfoLogEXT                         = procedure(aPipeline: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aInfoLog: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramPipelineivEXT                              = procedure(aPipeline: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsProgramPipelineEXT                                 = function (aPipeline: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramParameteriEXT                                 = procedure(aProgram: GLuint; aPname: GLenum; aValue: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1fEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1fvEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1iEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1ivEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2fEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLfloat; aV1: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2fvEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2iEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLint; aV1: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2ivEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3fEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLfloat; aV1: GLfloat; aV2: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3fvEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3iEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLint; aV1: GLint; aV2: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3ivEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4fEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLfloat; aV1: GLfloat; aV2: GLfloat; aV3: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4fvEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4iEXT                                  = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLint; aV1: GLint; aV2: GLint; aV3: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4ivEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2fvEXT                           = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3fvEXT                           = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4fvEXT                           = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUseProgramStagesEXT                                  = procedure(aPipeline: GLuint; aStages: GLbitfield; aProgram: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglValidateProgramPipelineEXT                           = procedure(aPipeline: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1uiEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2uiEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLuint; aV1: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3uiEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLuint; aV1: GLuint; aV2: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4uiEXT                                 = procedure(aProgram: GLuint; aLocation: GLint; aV0: GLuint; aV1: GLuint; aV2: GLuint; aV3: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform1uivEXT                                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform2uivEXT                                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform3uivEXT                                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniform4uivEXT                                = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValue: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2x3fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3x2fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix2x4fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4x2fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix3x4fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformMatrix4x3fvEXT                         = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glActiveShaderProgramEXT:                                 TglActiveShaderProgramEXT;
  glBindProgramPipelineEXT:                                 TglBindProgramPipelineEXT;
  glCreateShaderProgramvEXT:                                TglCreateShaderProgramvEXT;
  glDeleteProgramPipelinesEXT:                              TglDeleteProgramPipelinesEXT;
  glGenProgramPipelinesEXT:                                 TglGenProgramPipelinesEXT;
  glGetProgramPipelineInfoLogEXT:                           TglGetProgramPipelineInfoLogEXT;
  glGetProgramPipelineivEXT:                                TglGetProgramPipelineivEXT;
  glIsProgramPipelineEXT:                                   TglIsProgramPipelineEXT;
  glProgramParameteriEXT:                                   TglProgramParameteriEXT;
  glProgramUniform1fEXT:                                    TglProgramUniform1fEXT;
  glProgramUniform1fvEXT:                                   TglProgramUniform1fvEXT;
  glProgramUniform1iEXT:                                    TglProgramUniform1iEXT;
  glProgramUniform1ivEXT:                                   TglProgramUniform1ivEXT;
  glProgramUniform2fEXT:                                    TglProgramUniform2fEXT;
  glProgramUniform2fvEXT:                                   TglProgramUniform2fvEXT;
  glProgramUniform2iEXT:                                    TglProgramUniform2iEXT;
  glProgramUniform2ivEXT:                                   TglProgramUniform2ivEXT;
  glProgramUniform3fEXT:                                    TglProgramUniform3fEXT;
  glProgramUniform3fvEXT:                                   TglProgramUniform3fvEXT;
  glProgramUniform3iEXT:                                    TglProgramUniform3iEXT;
  glProgramUniform3ivEXT:                                   TglProgramUniform3ivEXT;
  glProgramUniform4fEXT:                                    TglProgramUniform4fEXT;
  glProgramUniform4fvEXT:                                   TglProgramUniform4fvEXT;
  glProgramUniform4iEXT:                                    TglProgramUniform4iEXT;
  glProgramUniform4ivEXT:                                   TglProgramUniform4ivEXT;
  glProgramUniformMatrix2fvEXT:                             TglProgramUniformMatrix2fvEXT;
  glProgramUniformMatrix3fvEXT:                             TglProgramUniformMatrix3fvEXT;
  glProgramUniformMatrix4fvEXT:                             TglProgramUniformMatrix4fvEXT;
  glUseProgramStagesEXT:                                    TglUseProgramStagesEXT;
  glValidateProgramPipelineEXT:                             TglValidateProgramPipelineEXT;
  glProgramUniform1uiEXT:                                   TglProgramUniform1uiEXT;
  glProgramUniform2uiEXT:                                   TglProgramUniform2uiEXT;
  glProgramUniform3uiEXT:                                   TglProgramUniform3uiEXT;
  glProgramUniform4uiEXT:                                   TglProgramUniform4uiEXT;
  glProgramUniform1uivEXT:                                  TglProgramUniform1uivEXT;
  glProgramUniform2uivEXT:                                  TglProgramUniform2uivEXT;
  glProgramUniform3uivEXT:                                  TglProgramUniform3uivEXT;
  glProgramUniform4uivEXT:                                  TglProgramUniform4uivEXT;
  glProgramUniformMatrix2x3fvEXT:                           TglProgramUniformMatrix2x3fvEXT;
  glProgramUniformMatrix3x2fvEXT:                           TglProgramUniformMatrix3x2fvEXT;
  glProgramUniformMatrix2x4fvEXT:                           TglProgramUniformMatrix2x4fvEXT;
  glProgramUniformMatrix4x2fvEXT:                           TglProgramUniformMatrix4x2fvEXT;
  glProgramUniformMatrix3x4fvEXT:                           TglProgramUniformMatrix3x4fvEXT;
  glProgramUniformMatrix4x3fvEXT:                           TglProgramUniformMatrix4x3fvEXT;

{ GL_EXT_shader_framebuffer_fetch }
const
  GL_FRAGMENT_SHADER_DISCARDS_SAMPLES_EXT                 = $8A52;

{ GL_EXT_shader_implicit_conversions }
  // none

{ GL_EXT_shader_integer_mix }
  // none

{ GL_EXT_shader_io_blocks }
  // none

{ GL_EXT_shader_pixel_local_storage }
const
  GL_MAX_SHADER_PIXEL_LOCAL_STORAGE_FAST_SIZE_EXT         = $8F63;
  GL_MAX_SHADER_PIXEL_LOCAL_STORAGE_SIZE_EXT              = $8F67;
  GL_SHADER_PIXEL_LOCAL_STORAGE_EXT                       = $8F64;

{ GL_EXT_shader_texture_lod }

{ GL_EXT_shadow_samplers }
const
  GL_TEXTURE_COMPARE_MODE_EXT                             = $884C;
  GL_TEXTURE_COMPARE_FUNC_EXT                             = $884D;
  GL_COMPARE_REF_TO_TEXTURE_EXT                           = $884E;
  GL_SAMPLER_2D_SHADOW_EXT                                = $8B62;

{ GL_EXT_tessellation_point_size }
  // none

{ GL_EXT_tessellation_shader }
const
  GL_PATCHES_EXT                                          = $000E;
  GL_PATCH_VERTICES_EXT                                   = $8E72;
  GL_TESS_CONTROL_OUTPUT_VERTICES_EXT                     = $8E75;
  GL_TESS_GEN_MODE_EXT                                    = $8E76;
  GL_TESS_GEN_SPACING_EXT                                 = $8E77;
  GL_TESS_GEN_VERTEX_ORDER_EXT                            = $8E78;
  GL_TESS_GEN_POINT_MODE_EXT                              = $8E79;
  GL_ISOLINES_EXT                                         = $8E7A;
  GL_QUADS_EXT                                            = $0007;
  GL_FRACTIONAL_ODD_EXT                                   = $8E7B;
  GL_FRACTIONAL_EVEN_EXT                                  = $8E7C;
  GL_MAX_PATCH_VERTICES_EXT                               = $8E7D;
  GL_MAX_TESS_GEN_LEVEL_EXT                               = $8E7E;
  GL_MAX_TESS_CONTROL_UNIFORM_COMPONENTS_EXT              = $8E7F;
  GL_MAX_TESS_EVALUATION_UNIFORM_COMPONENTS_EXT           = $8E80;
  GL_MAX_TESS_CONTROL_TEXTURE_IMAGE_UNITS_EXT             = $8E81;
  GL_MAX_TESS_EVALUATION_TEXTURE_IMAGE_UNITS_EXT          = $8E82;
  GL_MAX_TESS_CONTROL_OUTPUT_COMPONENTS_EXT               = $8E83;
  GL_MAX_TESS_PATCH_COMPONENTS_EXT                        = $8E84;
  GL_MAX_TESS_CONTROL_TOTAL_OUTPUT_COMPONENTS_EXT         = $8E85;
  GL_MAX_TESS_EVALUATION_OUTPUT_COMPONENTS_EXT            = $8E86;
  GL_MAX_TESS_CONTROL_UNIFORM_BLOCKS_EXT                  = $8E89;
  GL_MAX_TESS_EVALUATION_UNIFORM_BLOCKS_EXT               = $8E8A;
  GL_MAX_TESS_CONTROL_INPUT_COMPONENTS_EXT                = $886C;
  GL_MAX_TESS_EVALUATION_INPUT_COMPONENTS_EXT             = $886D;
  GL_MAX_COMBINED_TESS_CONTROL_UNIFORM_COMPONENTS_EXT     = $8E1E;
  GL_MAX_COMBINED_TESS_EVALUATION_UNIFORM_COMPONENTS_EXT  = $8E1F;
  GL_MAX_TESS_CONTROL_ATOMIC_COUNTER_BUFFERS_EXT          = $92CD;
  GL_MAX_TESS_EVALUATION_ATOMIC_COUNTER_BUFFERS_EXT       = $92CE;
  GL_MAX_TESS_CONTROL_ATOMIC_COUNTERS_EXT                 = $92D3;
  GL_MAX_TESS_EVALUATION_ATOMIC_COUNTERS_EXT              = $92D4;
  GL_MAX_TESS_CONTROL_IMAGE_UNIFORMS_EXT                  = $90CB;
  GL_MAX_TESS_EVALUATION_IMAGE_UNIFORMS_EXT               = $90CC;
  GL_MAX_TESS_CONTROL_SHADER_STORAGE_BLOCKS_EXT           = $90D8;
  GL_MAX_TESS_EVALUATION_SHADER_STORAGE_BLOCKS_EXT        = $90D9;
  GL_PRIMITIVE_RESTART_FOR_PATCHES_SUPPORTED              = $8221;
  GL_IS_PER_PATCH_EXT                                     = $92E7;
  GL_REFERENCED_BY_TESS_CONTROL_SHADER_EXT                = $9307;
  GL_REFERENCED_BY_TESS_EVALUATION_SHADER_EXT             = $9308;
  GL_TESS_CONTROL_SHADER_EXT                              = $8E88;
  GL_TESS_EVALUATION_SHADER_EXT                           = $8E87;
  GL_TESS_CONTROL_SHADER_BIT_EXT                          = $00000008;
  GL_TESS_EVALUATION_SHADER_BIT_EXT                       = $00000010;
type
  TglPatchParameteriEXT                                   = procedure(aPname: GLenum; aValue: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glPatchParameteriEXT:                                     TglPatchParameteriEXT;

{ GL_EXT_texture_border_clamp }
const
  GL_TEXTURE_BORDER_COLOR_EXT                             = $1004;
  GL_CLAMP_TO_BORDER_EXT                                  = $812D;
type
  TglTexParameterIivEXT                                   = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexParameterIuivEXT                                  = procedure(aTarget: GLenum; aPname: GLenum; const aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexParameterIivEXT                                = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTexParameterIuivEXT                               = procedure(aTarget: GLenum; aPname: GLenum; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameterIivEXT                               = procedure(aSampler: GLuint; aPname: GLenum; const aParam: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSamplerParameterIuivEXT                              = procedure(aSampler: GLuint; aPname: GLenum; const aParam: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSamplerParameterIivEXT                            = procedure(aSampler: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetSamplerParameterIuivEXT                           = procedure(aSampler: GLuint; aPname: GLenum; aParams: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTexParameterIivEXT:                                     TglTexParameterIivEXT;
  glTexParameterIuivEXT:                                    TglTexParameterIuivEXT;
  glGetTexParameterIivEXT:                                  TglGetTexParameterIivEXT;
  glGetTexParameterIuivEXT:                                 TglGetTexParameterIuivEXT;
  glSamplerParameterIivEXT:                                 TglSamplerParameterIivEXT;
  glSamplerParameterIuivEXT:                                TglSamplerParameterIuivEXT;
  glGetSamplerParameterIivEXT:                              TglGetSamplerParameterIivEXT;
  glGetSamplerParameterIuivEXT:                             TglGetSamplerParameterIuivEXT;

{ GL_EXT_texture_buffer }
const
  GL_TEXTURE_BUFFER_EXT                                   = $8C2A;
  GL_TEXTURE_BUFFER_BINDING_EXT                           = $8C2A;
  GL_MAX_TEXTURE_BUFFER_SIZE_EXT                          = $8C2B;
  GL_TEXTURE_BINDING_BUFFER_EXT                           = $8C2C;
  GL_TEXTURE_BUFFER_DATA_STORE_BINDING_EXT                = $8C2D;
  GL_TEXTURE_BUFFER_OFFSET_ALIGNMENT_EXT                  = $919F;
  GL_SAMPLER_BUFFER_EXT                                   = $8DC2;
  GL_INT_SAMPLER_BUFFER_EXT                               = $8DD0;
  GL_UNSIGNED_INT_SAMPLER_BUFFER_EXT                      = $8DD8;
  GL_IMAGE_BUFFER_EXT                                     = $9051;
  GL_INT_IMAGE_BUFFER_EXT                                 = $905C;
  GL_UNSIGNED_INT_IMAGE_BUFFER_EXT                        = $9067;
  GL_TEXTURE_BUFFER_OFFSET_EXT                            = $919D;
  GL_TEXTURE_BUFFER_SIZE_EXT                              = $919E;
type
  TglTexBufferEXT                                         = procedure(aTarget: GLenum; aInternalformat: GLenum; aBuffer: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexBufferRangeEXT                                    = procedure(aTarget: GLenum; aInternalformat: GLenum; aBuffer: GLuint; aOffset: GLintptr; aSize: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTexBufferEXT:                                           TglTexBufferEXT;
  glTexBufferRangeEXT:                                      TglTexBufferRangeEXT;

{ GL_EXT_texture_compression_dxt1 }
const
  GL_COMPRESSED_RGB_S3TC_DXT1_EXT                         = $83F0;
  GL_COMPRESSED_RGBA_S3TC_DXT1_EXT                        = $83F1;

{ GL_EXT_texture_compression_s3tc }
const
  GL_COMPRESSED_RGBA_S3TC_DXT3_EXT                        = $83F2;
  GL_COMPRESSED_RGBA_S3TC_DXT5_EXT                        = $83F3;

{ GL_EXT_texture_cube_map_array }
const
  GL_TEXTURE_CUBE_MAP_ARRAY_EXT                           = $9009;
  GL_TEXTURE_BINDING_CUBE_MAP_ARRAY_EXT                   = $900A;
  GL_SAMPLER_CUBE_MAP_ARRAY_EXT                           = $900C;
  GL_SAMPLER_CUBE_MAP_ARRAY_SHADOW_EXT                    = $900D;
  GL_INT_SAMPLER_CUBE_MAP_ARRAY_EXT                       = $900E;
  GL_UNSIGNED_INT_SAMPLER_CUBE_MAP_ARRAY_EXT              = $900F;
  GL_IMAGE_CUBE_MAP_ARRAY_EXT                             = $9054;
  GL_INT_IMAGE_CUBE_MAP_ARRAY_EXT                         = $905F;
  GL_UNSIGNED_INT_IMAGE_CUBE_MAP_ARRAY_EXT                = $906A;

{ GL_EXT_texture_filter_anisotropic }
const
  GL_TEXTURE_MAX_ANISOTROPY_EXT                           = $84FE;
  GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT                       = $84FF;

{ GL_EXT_texture_format_BGRA8888 }

{ GL_EXT_texture_norm16 }
const
  GL_R16_EXT                                              = $822A;
  GL_RG16_EXT                                             = $822C;
  GL_RGBA16_EXT                                           = $805B;
  GL_RGB16_EXT                                            = $8054;
  GL_RGB16_SNORM_EXT                                      = $8F9A;

{ GL_EXT_texture_rg }
const
  GL_RED_EXT                                              = $1903;
  GL_RG_EXT                                               = $8227;
  GL_R8_EXT                                               = $8229;
  GL_RG8_EXT                                              = $822B;

{ GL_EXT_texture_sRGB_decode }
const
  GL_TEXTURE_SRGB_DECODE_EXT                              = $8A48;
  GL_DECODE_EXT                                           = $8A49;
  GL_SKIP_DECODE_EXT                                      = $8A4A;

{ GL_EXT_texture_storage }
const
  GL_TEXTURE_IMMUTABLE_FORMAT_EXT                         = $912F;
  GL_ALPHA8_EXT                                           = $803C;
  GL_LUMINANCE8_EXT                                       = $8040;
  GL_LUMINANCE8_ALPHA8_EXT                                = $8045;
  GL_RGBA32F_EXT                                          = $8814;
  GL_RGB32F_EXT                                           = $8815;
  GL_ALPHA32F_EXT                                         = $8816;
  GL_LUMINANCE32F_EXT                                     = $8818;
  GL_LUMINANCE_ALPHA32F_EXT                               = $8819;
  GL_ALPHA16F_EXT                                         = $881C;
  GL_LUMINANCE16F_EXT                                     = $881E;
  GL_LUMINANCE_ALPHA16F_EXT                               = $881F;
  GL_R32F_EXT                                             = $822E;
  GL_RG32F_EXT                                            = $8230;
type
  TglTexStorage1DEXT                                      = procedure(aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexStorage2DEXT                                      = procedure(aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTexStorage3DEXT                                      = procedure(aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTextureStorage1DEXT                                  = procedure(aTexture: GLuint; aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTextureStorage2DEXT                                  = procedure(aTexture: GLuint; aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTextureStorage3DEXT                                  = procedure(aTexture: GLuint; aTarget: GLenum; aLevels: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTexStorage1DEXT:                                        TglTexStorage1DEXT;
  glTexStorage2DEXT:                                        TglTexStorage2DEXT;
  glTexStorage3DEXT:                                        TglTexStorage3DEXT;
  glTextureStorage1DEXT:                                    TglTextureStorage1DEXT;
  glTextureStorage2DEXT:                                    TglTextureStorage2DEXT;
  glTextureStorage3DEXT:                                    TglTextureStorage3DEXT;

{ GL_EXT_texture_type_2_10_10_10_REV }
const
  GL_UNSIGNED_INT_2_10_10_10_REV_EXT                      = $8368;

{ GL_EXT_texture_view }
const
  GL_TEXTURE_VIEW_MIN_LEVEL_EXT                           = $82DB;
  GL_TEXTURE_VIEW_NUM_LEVELS_EXT                          = $82DC;
  GL_TEXTURE_VIEW_MIN_LAYER_EXT                           = $82DD;
  GL_TEXTURE_VIEW_NUM_LAYERS_EXT                          = $82DE;
  //GL_TEXTURE_IMMUTABLE_LEVELS                           = $82DF;
type
  TglTextureViewEXT                                       = procedure(aTexture: GLuint; aTarget: GLenum; aOrigtexture: GLuint; aInternalformat: GLenum; aMinlevel: GLuint; aNumlevels: GLuint; aMinlayer: GLuint; aNumlayers: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glTextureViewEXT:                                         TglTextureViewEXT;

{ GL_EXT_unpack_subimage }
const
  GL_UNPACK_ROW_LENGTH_EXT                                = $0CF2;
  GL_UNPACK_SKIP_ROWS_EXT                                 = $0CF3;
  GL_UNPACK_SKIP_PIXELS_EXT                               = $0CF4;

{ GL_FJ_shader_binary_GCCSO }
const
  GL_GCCSO_SHADER_BINARY_FJ                               = $9260;

{ GL_IMG_multisampled_render_to_texture }
const
  GL_RENDERBUFFER_SAMPLES_IMG                             = $9133;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_IMG               = $9134;
  GL_MAX_SAMPLES_IMG                                      = $9135;
  GL_TEXTURE_SAMPLES_IMG                                  = $9136;
type
  TglRenderbufferStorageMultisampleIMG                    = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFramebufferTexture2DMultisampleIMG                   = procedure(aTarget: GLenum; aAttachment: GLenum; aTextarget: GLenum; aTexture: GLuint; aLevel: GLint; aSamples: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glRenderbufferStorageMultisampleIMG:                      TglRenderbufferStorageMultisampleIMG;
  glFramebufferTexture2DMultisampleIMG:                     TglFramebufferTexture2DMultisampleIMG;

{ GL_IMG_program_binary }
const
  GL_SGX_PROGRAM_BINARY_IMG                               = $9130;

{ GL_IMG_read_format }
const
  GL_BGRA_IMG                                             = $80E1;
  GL_UNSIGNED_SHORT_4_4_4_4_REV_IMG                       = $8365;

{ GL_IMG_shader_binary }
const
  GL_SGX_BINARY_IMG                                       = $8C0A;

{ GL_IMG_texture_compression_pvrtc }
const
  GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG                      = $8C00;
  GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG                      = $8C01;
  GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG                     = $8C02;
  GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG                     = $8C03;

{ GL_IMG_texture_compression_pvrtc2 }
const
  GL_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG                     = $9137;
  GL_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG                     = $9138;

{ GL_INTEL_performance_query }
const
  GL_PERFQUERY_SINGLE_CONTEXT_INTEL                       = $00000000;
  GL_PERFQUERY_GLOBAL_CONTEXT_INTEL                       = $00000001;
  GL_PERFQUERY_WAIT_INTEL                                 = $83FB;
  GL_PERFQUERY_FLUSH_INTEL                                = $83FA;
  GL_PERFQUERY_DONOT_FLUSH_INTEL                          = $83F9;
  GL_PERFQUERY_COUNTER_EVENT_INTEL                        = $94F0;
  GL_PERFQUERY_COUNTER_DURATION_NORM_INTEL                = $94F1;
  GL_PERFQUERY_COUNTER_DURATION_RAW_INTEL                 = $94F2;
  GL_PERFQUERY_COUNTER_THROUGHPUT_INTEL                   = $94F3;
  GL_PERFQUERY_COUNTER_RAW_INTEL                          = $94F4;
  GL_PERFQUERY_COUNTER_TIMESTAMP_INTEL                    = $94F5;
  GL_PERFQUERY_COUNTER_DATA_UINT32_INTEL                  = $94F8;
  GL_PERFQUERY_COUNTER_DATA_UINT64_INTEL                  = $94F9;
  GL_PERFQUERY_COUNTER_DATA_FLOAT_INTEL                   = $94FA;
  GL_PERFQUERY_COUNTER_DATA_DOUBLE_INTEL                  = $94FB;
  GL_PERFQUERY_COUNTER_DATA_BOOL32_INTEL                  = $94FC;
  GL_PERFQUERY_QUERY_NAME_LENGTH_MAX_INTEL                = $94FD;
  GL_PERFQUERY_COUNTER_NAME_LENGTH_MAX_INTEL              = $94FE;
  GL_PERFQUERY_COUNTER_DESC_LENGTH_MAX_INTEL              = $94FF;
  GL_PERFQUERY_GPA_EXTENDED_COUNTERS_INTEL                = $9500;
type
  TglBeginPerfQueryINTEL                                  = procedure(aQueryHandle: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCreatePerfQueryINTEL                                 = procedure(aQueryId: GLuint; aQueryHandle: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeletePerfQueryINTEL                                 = procedure(aQueryHandle: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndPerfQueryINTEL                                    = procedure(aQueryHandle: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFirstPerfQueryIdINTEL                             = procedure(aQueryId: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetNextPerfQueryIdINTEL                              = procedure(aQueryId: GLuint; aNextQueryId: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfCounterInfoINTEL                              = procedure(aQueryId: GLuint; aCounterId: GLuint; aCounterNameLength: GLuint; aCounterName: PGLchar; aCounterDescLength: GLuint; aCounterDesc: PGLchar; aCounterOffset: PGLuint; aCounterDataSize: PGLuint; aCounterTypeEnum: PGLuint; aCounterDataTypeEnum: PGLuint; aRawCounterMaxValue: PGLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfQueryDataINTEL                                = procedure(aQueryHandle: GLuint; aFlags: GLuint; aDataSize: GLsizei; aData: PGLvoid; aBytesWritten: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfQueryIdByNameINTEL                            = procedure(aQueryName: PGLchar; aQueryId: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPerfQueryInfoINTEL                                = procedure(aQueryId: GLuint; aQueryNameLength: GLuint; aQueryName: PGLchar; aDataSize: PGLuint; aNoCounters: PGLuint; aNoInstances: PGLuint; aCapsMask: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBeginPerfQueryINTEL:                                    TglBeginPerfQueryINTEL;
  glCreatePerfQueryINTEL:                                   TglCreatePerfQueryINTEL;
  glDeletePerfQueryINTEL:                                   TglDeletePerfQueryINTEL;
  glEndPerfQueryINTEL:                                      TglEndPerfQueryINTEL;
  glGetFirstPerfQueryIdINTEL:                               TglGetFirstPerfQueryIdINTEL;
  glGetNextPerfQueryIdINTEL:                                TglGetNextPerfQueryIdINTEL;
  glGetPerfCounterInfoINTEL:                                TglGetPerfCounterInfoINTEL;
  glGetPerfQueryDataINTEL:                                  TglGetPerfQueryDataINTEL;
  glGetPerfQueryIdByNameINTEL:                              TglGetPerfQueryIdByNameINTEL;
  glGetPerfQueryInfoINTEL:                                  TglGetPerfQueryInfoINTEL;

{ GL_NV_bindless_texture }
type
  TglGetTextureHandleNV                                   = function (aTexture: GLuint): GLuint64; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetTextureSamplerHandleNV                            = function (aTexture: GLuint; aSampler: GLuint): GLuint64; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMakeTextureHandleResidentNV                          = procedure(aHandle: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMakeTextureHandleNonResidentNV                       = procedure(aHandle: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetImageHandleNV                                     = function (aTexture: GLuint; aLevel: GLint; aLayered: GLboolean; aLayer: GLint; aFormat: GLenum): GLuint64; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMakeImageHandleResidentNV                            = procedure(aHandle: GLuint64; aAccess: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMakeImageHandleNonResidentNV                         = procedure(aHandle: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformHandleui64NV                                  = procedure(aLocation: GLint; aValue: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformHandleui64vNV                                 = procedure(aLocation: GLint; aCount: GLsizei; const aValue: PGLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformHandleui64NV                           = procedure(aProgram: GLuint; aLocation: GLint; aValue: GLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramUniformHandleui64vNV                          = procedure(aProgram: GLuint; aLocation: GLint; aCount: GLsizei; const aValues: PGLuint64); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsTextureHandleResidentNV                            = function (aHandle: GLuint64): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsImageHandleResidentNV                              = function (aHandle: GLuint64): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetTextureHandleNV:                                     TglGetTextureHandleNV;
  glGetTextureSamplerHandleNV:                              TglGetTextureSamplerHandleNV;
  glMakeTextureHandleResidentNV:                            TglMakeTextureHandleResidentNV;
  glMakeTextureHandleNonResidentNV:                         TglMakeTextureHandleNonResidentNV;
  glGetImageHandleNV:                                       TglGetImageHandleNV;
  glMakeImageHandleResidentNV:                              TglMakeImageHandleResidentNV;
  glMakeImageHandleNonResidentNV:                           TglMakeImageHandleNonResidentNV;
  glUniformHandleui64NV:                                    TglUniformHandleui64NV;
  glUniformHandleui64vNV:                                   TglUniformHandleui64vNV;
  glProgramUniformHandleui64NV:                             TglProgramUniformHandleui64NV;
  glProgramUniformHandleui64vNV:                            TglProgramUniformHandleui64vNV;
  glIsTextureHandleResidentNV:                              TglIsTextureHandleResidentNV;
  glIsImageHandleResidentNV:                                TglIsImageHandleResidentNV;

{ GL_NV_blend_equation_advanced }
const
  GL_BLEND_OVERLAP_NV                                     = $9281;
  GL_BLEND_PREMULTIPLIED_SRC_NV                           = $9280;
  GL_BLUE_NV                                              = $1905;
  GL_COLORBURN_NV                                         = $929A;
  GL_COLORDODGE_NV                                        = $9299;
  GL_CONJOINT_NV                                          = $9284;
  GL_CONTRAST_NV                                          = $92A1;
  GL_DARKEN_NV                                            = $9297;
  GL_DIFFERENCE_NV                                        = $929E;
  GL_DISJOINT_NV                                          = $9283;
  GL_DST_ATOP_NV                                          = $928F;
  GL_DST_IN_NV                                            = $928B;
  GL_DST_NV                                               = $9287;
  GL_DST_OUT_NV                                           = $928D;
  GL_DST_OVER_NV                                          = $9289;
  GL_EXCLUSION_NV                                         = $92A0;
  GL_GREEN_NV                                             = $1904;
  GL_HARDLIGHT_NV                                         = $929B;
  GL_HARDMIX_NV                                           = $92A9;
  GL_HSL_COLOR_NV                                         = $92AF;
  GL_HSL_HUE_NV                                           = $92AD;
  GL_HSL_LUMINOSITY_NV                                    = $92B0;
  GL_HSL_SATURATION_NV                                    = $92AE;
  GL_INVERT_OVG_NV                                        = $92B4;
  GL_INVERT_RGB_NV                                        = $92A3;
  GL_LIGHTEN_NV                                           = $9298;
  GL_LINEARBURN_NV                                        = $92A5;
  GL_LINEARDODGE_NV                                       = $92A4;
  GL_LINEARLIGHT_NV                                       = $92A7;
  GL_MINUS_CLAMPED_NV                                     = $92B3;
  GL_MINUS_NV                                             = $929F;
  GL_MULTIPLY_NV                                          = $9294;
  GL_OVERLAY_NV                                           = $9296;
  GL_PINLIGHT_NV                                          = $92A8;
  GL_PLUS_CLAMPED_ALPHA_NV                                = $92B2;
  GL_PLUS_CLAMPED_NV                                      = $92B1;
  GL_PLUS_DARKER_NV                                       = $9292;
  GL_PLUS_NV                                              = $9291;
  GL_RED_NV                                               = $1903;
  GL_SCREEN_NV                                            = $9295;
  GL_SOFTLIGHT_NV                                         = $929C;
  GL_SRC_ATOP_NV                                          = $928E;
  GL_SRC_IN_NV                                            = $928A;
  GL_SRC_NV                                               = $9286;
  GL_SRC_OUT_NV                                           = $928C;
  GL_SRC_OVER_NV                                          = $9288;
  GL_UNCORRELATED_NV                                      = $9282;
  GL_VIVIDLIGHT_NV                                        = $92A6;
  GL_XOR_NV                                               = $1506;
type
  TglBlendParameteriNV                                    = procedure(aPname: GLenum; aValue: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglBlendBarrierNV                                       = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBlendParameteriNV:                                      TglBlendParameteriNV;
  glBlendBarrierNV:                                         TglBlendBarrierNV;

{ GL_NV_blend_equation_advanced_coherent }
const
  GL_BLEND_ADVANCED_COHERENT_NV                           = $9285;

{ GL_NV_conditional_render }
const
  GL_QUERY_WAIT_NV                                        = $8E13;
  GL_QUERY_NO_WAIT_NV                                     = $8E14;
  GL_QUERY_BY_REGION_WAIT_NV                              = $8E15;
  GL_QUERY_BY_REGION_NO_WAIT_NV                           = $8E16;
type
  TglBeginConditionalRenderNV                             = procedure(aId: GLuint; aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndConditionalRenderNV                               = procedure; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBeginConditionalRenderNV:                               TglBeginConditionalRenderNV;
  glEndConditionalRenderNV:                                 TglEndConditionalRenderNV;

{ GL_NV_copy_buffer }
const
  GL_COPY_READ_BUFFER_NV                                  = $8F36;
  GL_COPY_WRITE_BUFFER_NV                                 = $8F37;
type
  TglCopyBufferSubDataNV                                  = procedure(aReadTarget: GLenum; aWriteTarget: GLenum; aReadOffset: GLintptr; aWriteOffset: GLintptr; aSize: GLsizeiptr); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glCopyBufferSubDataNV:                                    TglCopyBufferSubDataNV;

{ GL_NV_coverage_sample }
const
  GL_COVERAGE_COMPONENT_NV                                = $8ED0;
  GL_COVERAGE_COMPONENT4_NV                               = $8ED1;
  GL_COVERAGE_ATTACHMENT_NV                               = $8ED2;
  GL_COVERAGE_BUFFERS_NV                                  = $8ED3;
  GL_COVERAGE_SAMPLES_NV                                  = $8ED4;
  GL_COVERAGE_ALL_FRAGMENTS_NV                            = $8ED5;
  GL_COVERAGE_EDGE_FRAGMENTS_NV                           = $8ED6;
  GL_COVERAGE_AUTOMATIC_NV                                = $8ED7;
  GL_COVERAGE_BUFFER_BIT_NV                               = $00008000;
type
  TglCoverageMaskNV                                       = procedure(aMask: GLboolean); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCoverageOperationNV                                  = procedure(aOperation: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glCoverageMaskNV:                                         TglCoverageMaskNV;
  glCoverageOperationNV:                                    TglCoverageOperationNV;

{ GL_NV_depth_nonlinear }
const
  GL_DEPTH_COMPONENT16_NONLINEAR_NV                       = $8E2C;

{ GL_NV_draw_buffers }
const
  GL_MAX_DRAW_BUFFERS_NV                                  = $8824;
  GL_DRAW_BUFFER0_NV                                      = $8825;
  GL_DRAW_BUFFER1_NV                                      = $8826;
  GL_DRAW_BUFFER2_NV                                      = $8827;
  GL_DRAW_BUFFER3_NV                                      = $8828;
  GL_DRAW_BUFFER4_NV                                      = $8829;
  GL_DRAW_BUFFER5_NV                                      = $882A;
  GL_DRAW_BUFFER6_NV                                      = $882B;
  GL_DRAW_BUFFER7_NV                                      = $882C;
  GL_DRAW_BUFFER8_NV                                      = $882D;
  GL_DRAW_BUFFER9_NV                                      = $882E;
  GL_DRAW_BUFFER10_NV                                     = $882F;
  GL_DRAW_BUFFER11_NV                                     = $8830;
  GL_DRAW_BUFFER12_NV                                     = $8831;
  GL_DRAW_BUFFER13_NV                                     = $8832;
  GL_DRAW_BUFFER14_NV                                     = $8833;
  GL_DRAW_BUFFER15_NV                                     = $8834;
  GL_COLOR_ATTACHMENT0_NV                                 = $8CE0;
  GL_COLOR_ATTACHMENT1_NV                                 = $8CE1;
  GL_COLOR_ATTACHMENT2_NV                                 = $8CE2;
  GL_COLOR_ATTACHMENT3_NV                                 = $8CE3;
  GL_COLOR_ATTACHMENT4_NV                                 = $8CE4;
  GL_COLOR_ATTACHMENT5_NV                                 = $8CE5;
  GL_COLOR_ATTACHMENT6_NV                                 = $8CE6;
  GL_COLOR_ATTACHMENT7_NV                                 = $8CE7;
  GL_COLOR_ATTACHMENT8_NV                                 = $8CE8;
  GL_COLOR_ATTACHMENT9_NV                                 = $8CE9;
  GL_COLOR_ATTACHMENT10_NV                                = $8CEA;
  GL_COLOR_ATTACHMENT11_NV                                = $8CEB;
  GL_COLOR_ATTACHMENT12_NV                                = $8CEC;
  GL_COLOR_ATTACHMENT13_NV                                = $8CED;
  GL_COLOR_ATTACHMENT14_NV                                = $8CEE;
  GL_COLOR_ATTACHMENT15_NV                                = $8CEF;
type
  TglDrawBuffersNV                                        = procedure(n: GLsizei; const aBufs: PGLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawBuffersNV:                                          TglDrawBuffersNV;

{ GL_NV_draw_instanced }
type
  TglDrawArraysInstancedNV                                = procedure(aMode: GLenum; aFirst: GLint; aCount: GLsizei; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDrawElementsInstancedNV                              = procedure(aMode: GLenum; aCount: GLsizei; aType: GLenum; const aIndices: Pointer; aPrimcount: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDrawArraysInstancedNV:                                  TglDrawArraysInstancedNV;
  glDrawElementsInstancedNV:                                TglDrawElementsInstancedNV;

{ GL_NV_explicit_attrib_location }
  // none

{ GL_NV_fbo_color_attachments }
const
  GL_MAX_COLOR_ATTACHMENTS_NV                             = $8CDF;

{ GL_NV_fence }
const
  GL_ALL_COMPLETED_NV                                     = $84F2;
  GL_FENCE_STATUS_NV                                      = $84F3;
  GL_FENCE_CONDITION_NV                                   = $84F4;
type
  TglDeleteFencesNV                                       = procedure(n: GLsizei; const aFences: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGenFencesNV                                          = procedure(n: GLsizei; aFences: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsFenceNV                                            = function (aFence: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTestFenceNV                                          = function (aFence: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFenceivNV                                         = procedure(aFence: GLuint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglFinishFenceNV                                        = procedure(aFence: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglSetFenceNV                                           = procedure(aFence: GLuint; aCondition: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glDeleteFencesNV:                                         TglDeleteFencesNV;
  glGenFencesNV:                                            TglGenFencesNV;
  glIsFenceNV:                                              TglIsFenceNV;
  glTestFenceNV:                                            TglTestFenceNV;
  glGetFenceivNV:                                           TglGetFenceivNV;
  glFinishFenceNV:                                          TglFinishFenceNV;
  glSetFenceNV:                                             TglSetFenceNV;

{ GL_NV_framebuffer_blit }
const
  GL_READ_FRAMEBUFFER_NV                                  = $8CA8;
  GL_DRAW_FRAMEBUFFER_NV                                  = $8CA9;
  GL_DRAW_FRAMEBUFFER_BINDING_NV                          = $8CA6;
  GL_READ_FRAMEBUFFER_BINDING_NV                          = $8CAA;
type
  TglBlitFramebufferNV                                    = procedure(aSrcX0: GLint; aSrcY0: GLint; aSrcX1: GLint; aSrcY1: GLint; aDstX0: GLint; aDstY0: GLint; aDstX1: GLint; aDstY1: GLint; aMask: GLbitfield; aFilter: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glBlitFramebufferNV:                                      TglBlitFramebufferNV;

{ GL_NV_framebuffer_multisample }
const
  GL_RENDERBUFFER_SAMPLES_NV                              = $8CAB;
  GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_NV                = $8D56;
  GL_MAX_SAMPLES_NV                                       = $8D57;
type
  TglRenderbufferStorageMultisampleNV                     = procedure(aTarget: GLenum; aSamples: GLsizei; aInternalformat: GLenum; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glRenderbufferStorageMultisampleNV:                       TglRenderbufferStorageMultisampleNV;

{ GL_NV_generate_mipmap_sRGB }
  // none

{ GL_NV_image_formats }
  // none

{ GL_NV_instanced_arrays }
const
  GL_VERTEX_ATTRIB_ARRAY_DIVISOR_NV                       = $88FE;
type
  TglVertexAttribDivisorNV                                = procedure(aIndex: GLuint; aDivisor: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glVertexAttribDivisorNV:                                  TglVertexAttribDivisorNV;

{ GL_NV_internalformat_sample_query }
const
  //GL_TEXTURE_2D_MULTISAMPLE                             = $9100;
  GL_TEXTURE_2D_MULTISAMPLE_ARRAY                         = $9102;
  GL_MULTISAMPLES_NV                                      = $9371;
  GL_SUPERSAMPLE_SCALE_X_NV                               = $9372;
  GL_SUPERSAMPLE_SCALE_Y_NV                               = $9373;
  GL_CONFORMANT_NV                                        = $9374;
type
  TglGetInternalformatSampleivNV                          = procedure(aTarget: GLenum; aInternalformat: GLenum; aSamples: GLsizei; aPname: GLenum; aBufSize: GLsizei; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetInternalformatSampleivNV:                            TglGetInternalformatSampleivNV;

{ GL_NV_non_square_matrices }
const
  GL_FLOAT_MAT2x3_NV                                      = $8B65;
  GL_FLOAT_MAT2x4_NV                                      = $8B66;
  GL_FLOAT_MAT3x2_NV                                      = $8B67;
  GL_FLOAT_MAT3x4_NV                                      = $8B68;
  GL_FLOAT_MAT4x2_NV                                      = $8B69;
  GL_FLOAT_MAT4x3_NV                                      = $8B6A;
type
  TglUniformMatrix2x3fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix3x2fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix2x4fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix4x2fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix3x4fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglUniformMatrix4x3fvNV                                 = procedure(aLocation: GLint; aCount: GLsizei; aTranspose: GLboolean; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glUniformMatrix2x3fvNV:                                   TglUniformMatrix2x3fvNV;
  glUniformMatrix3x2fvNV:                                   TglUniformMatrix3x2fvNV;
  glUniformMatrix2x4fvNV:                                   TglUniformMatrix2x4fvNV;
  glUniformMatrix4x2fvNV:                                   TglUniformMatrix4x2fvNV;
  glUniformMatrix3x4fvNV:                                   TglUniformMatrix3x4fvNV;
  glUniformMatrix4x3fvNV:                                   TglUniformMatrix4x3fvNV;

{ GL_NV_path_rendering }
const
  GL_PATH_FORMAT_SVG_NV                                   = $9070;
  GL_PATH_FORMAT_PS_NV                                    = $9071;
  GL_STANDARD_FONT_NAME_NV                                = $9072;
  GL_SYSTEM_FONT_NAME_NV                                  = $9073;
  GL_FILE_NAME_NV                                         = $9074;
  GL_PATH_STROKE_WIDTH_NV                                 = $9075;
  GL_PATH_END_CAPS_NV                                     = $9076;
  GL_PATH_INITIAL_END_CAP_NV                              = $9077;
  GL_PATH_TERMINAL_END_CAP_NV                             = $9078;
  GL_PATH_JOIN_STYLE_NV                                   = $9079;
  GL_PATH_MITER_LIMIT_NV                                  = $907A;
  GL_PATH_DASH_CAPS_NV                                    = $907B;
  GL_PATH_INITIAL_DASH_CAP_NV                             = $907C;
  GL_PATH_TERMINAL_DASH_CAP_NV                            = $907D;
  GL_PATH_DASH_OFFSET_NV                                  = $907E;
  GL_PATH_CLIENT_LENGTH_NV                                = $907F;
  GL_PATH_FILL_MODE_NV                                    = $9080;
  GL_PATH_FILL_MASK_NV                                    = $9081;
  GL_PATH_FILL_COVER_MODE_NV                              = $9082;
  GL_PATH_STROKE_COVER_MODE_NV                            = $9083;
  GL_PATH_STROKE_MASK_NV                                  = $9084;
  GL_COUNT_UP_NV                                          = $9088;
  GL_COUNT_DOWN_NV                                        = $9089;
  GL_PATH_OBJECT_BOUNDING_BOX_NV                          = $908A;
  GL_CONVEX_HULL_NV                                       = $908B;
  GL_BOUNDING_BOX_NV                                      = $908D;
  GL_TRANSLATE_X_NV                                       = $908E;
  GL_TRANSLATE_Y_NV                                       = $908F;
  GL_TRANSLATE_2D_NV                                      = $9090;
  GL_TRANSLATE_3D_NV                                      = $9091;
  GL_AFFINE_2D_NV                                         = $9092;
  GL_AFFINE_3D_NV                                         = $9094;
  GL_TRANSPOSE_AFFINE_2D_NV                               = $9096;
  GL_TRANSPOSE_AFFINE_3D_NV                               = $9098;
  GL_UTF8_NV                                              = $909A;
  GL_UTF16_NV                                             = $909B;
  GL_BOUNDING_BOX_OF_BOUNDING_BOXES_NV                    = $909C;
  GL_PATH_COMMAND_COUNT_NV                                = $909D;
  GL_PATH_COORD_COUNT_NV                                  = $909E;
  GL_PATH_DASH_ARRAY_COUNT_NV                             = $909F;
  GL_PATH_COMPUTED_LENGTH_NV                              = $90A0;
  GL_PATH_FILL_BOUNDING_BOX_NV                            = $90A1;
  GL_PATH_STROKE_BOUNDING_BOX_NV                          = $90A2;
  GL_SQUARE_NV                                            = $90A3;
  GL_ROUND_NV                                             = $90A4;
  GL_TRIANGULAR_NV                                        = $90A5;
  GL_BEVEL_NV                                             = $90A6;
  GL_MITER_REVERT_NV                                      = $90A7;
  GL_MITER_TRUNCATE_NV                                    = $90A8;
  GL_SKIP_MISSING_GLYPH_NV                                = $90A9;
  GL_USE_MISSING_GLYPH_NV                                 = $90AA;
  GL_PATH_ERROR_POSITION_NV                               = $90AB;
  GL_ACCUM_ADJACENT_PAIRS_NV                              = $90AD;
  GL_ADJACENT_PAIRS_NV                                    = $90AE;
  GL_FIRST_TO_REST_NV                                     = $90AF;
  GL_PATH_GEN_MODE_NV                                     = $90B0;
  GL_PATH_GEN_COEFF_NV                                    = $90B1;
  GL_PATH_GEN_COMPONENTS_NV                               = $90B3;
  GL_PATH_STENCIL_FUNC_NV                                 = $90B7;
  GL_PATH_STENCIL_REF_NV                                  = $90B8;
  GL_PATH_STENCIL_VALUE_MASK_NV                           = $90B9;
  GL_PATH_STENCIL_DEPTH_OFFSET_FACTOR_NV                  = $90BD;
  GL_PATH_STENCIL_DEPTH_OFFSET_UNITS_NV                   = $90BE;
  GL_PATH_COVER_DEPTH_FUNC_NV                             = $90BF;
  GL_PATH_DASH_OFFSET_RESET_NV                            = $90B4;
  GL_MOVE_TO_RESETS_NV                                    = $90B5;
  GL_MOVE_TO_CONTINUES_NV                                 = $90B6;
  GL_CLOSE_PATH_NV                                        = $00;
  GL_MOVE_TO_NV                                           = $02;
  GL_RELATIVE_MOVE_TO_NV                                  = $03;
  GL_LINE_TO_NV                                           = $04;
  GL_RELATIVE_LINE_TO_NV                                  = $05;
  GL_HORIZONTAL_LINE_TO_NV                                = $06;
  GL_RELATIVE_HORIZONTAL_LINE_TO_NV                       = $07;
  GL_VERTICAL_LINE_TO_NV                                  = $08;
  GL_RELATIVE_VERTICAL_LINE_TO_NV                         = $09;
  GL_QUADRATIC_CURVE_TO_NV                                = $0A;
  GL_RELATIVE_QUADRATIC_CURVE_TO_NV                       = $0B;
  GL_CUBIC_CURVE_TO_NV                                    = $0C;
  GL_RELATIVE_CUBIC_CURVE_TO_NV                           = $0D;
  GL_SMOOTH_QUADRATIC_CURVE_TO_NV                         = $0E;
  GL_RELATIVE_SMOOTH_QUADRATIC_CURVE_TO_NV                = $0F;
  GL_SMOOTH_CUBIC_CURVE_TO_NV                             = $10;
  GL_RELATIVE_SMOOTH_CUBIC_CURVE_TO_NV                    = $11;
  GL_SMALL_CCW_ARC_TO_NV                                  = $12;
  GL_RELATIVE_SMALL_CCW_ARC_TO_NV                         = $13;
  GL_SMALL_CW_ARC_TO_NV                                   = $14;
  GL_RELATIVE_SMALL_CW_ARC_TO_NV                          = $15;
  GL_LARGE_CCW_ARC_TO_NV                                  = $16;
  GL_RELATIVE_LARGE_CCW_ARC_TO_NV                         = $17;
  GL_LARGE_CW_ARC_TO_NV                                   = $18;
  GL_RELATIVE_LARGE_CW_ARC_TO_NV                          = $19;
  GL_RESTART_PATH_NV                                      = $F0;
  GL_DUP_FIRST_CUBIC_CURVE_TO_NV                          = $F2;
  GL_DUP_LAST_CUBIC_CURVE_TO_NV                           = $F4;
  GL_RECT_NV                                              = $F6;
  GL_CIRCULAR_CCW_ARC_TO_NV                               = $F8;
  GL_CIRCULAR_CW_ARC_TO_NV                                = $FA;
  GL_CIRCULAR_TANGENT_ARC_TO_NV                           = $FC;
  GL_ARC_TO_NV                                            = $FE;
  GL_RELATIVE_ARC_TO_NV                                   = $FF;
  GL_BOLD_BIT_NV                                          = $01;
  GL_ITALIC_BIT_NV                                        = $02;
  GL_GLYPH_WIDTH_BIT_NV                                   = $01;
  GL_GLYPH_HEIGHT_BIT_NV                                  = $02;
  GL_GLYPH_HORIZONTAL_BEARING_X_BIT_NV                    = $04;
  GL_GLYPH_HORIZONTAL_BEARING_Y_BIT_NV                    = $08;
  GL_GLYPH_HORIZONTAL_BEARING_ADVANCE_BIT_NV              = $10;
  GL_GLYPH_VERTICAL_BEARING_X_BIT_NV                      = $20;
  GL_GLYPH_VERTICAL_BEARING_Y_BIT_NV                      = $40;
  GL_GLYPH_VERTICAL_BEARING_ADVANCE_BIT_NV                = $80;
  GL_GLYPH_HAS_KERNING_BIT_NV                             = $100;
  GL_FONT_X_MIN_BOUNDS_BIT_NV                             = $00010000;
  GL_FONT_Y_MIN_BOUNDS_BIT_NV                             = $00020000;
  GL_FONT_X_MAX_BOUNDS_BIT_NV                             = $00040000;
  GL_FONT_Y_MAX_BOUNDS_BIT_NV                             = $00080000;
  GL_FONT_UNITS_PER_EM_BIT_NV                             = $00100000;
  GL_FONT_ASCENDER_BIT_NV                                 = $00200000;
  GL_FONT_DESCENDER_BIT_NV                                = $00400000;
  GL_FONT_HEIGHT_BIT_NV                                   = $00800000;
  GL_FONT_MAX_ADVANCE_WIDTH_BIT_NV                        = $01000000;
  GL_FONT_MAX_ADVANCE_HEIGHT_BIT_NV                       = $02000000;
  GL_FONT_UNDERLINE_POSITION_BIT_NV                       = $04000000;
  GL_FONT_UNDERLINE_THICKNESS_BIT_NV                      = $08000000;
  GL_FONT_HAS_KERNING_BIT_NV                              = $10000000;
  GL_ROUNDED_RECT_NV                                      = $E8;
  GL_RELATIVE_ROUNDED_RECT_NV                             = $E9;
  GL_ROUNDED_RECT2_NV                                     = $EA;
  GL_RELATIVE_ROUNDED_RECT2_NV                            = $EB;
  GL_ROUNDED_RECT4_NV                                     = $EC;
  GL_RELATIVE_ROUNDED_RECT4_NV                            = $ED;
  GL_ROUNDED_RECT8_NV                                     = $EE;
  GL_RELATIVE_ROUNDED_RECT8_NV                            = $EF;
  GL_RELATIVE_RECT_NV                                     = $F7;
  GL_FONT_GLYPHS_AVAILABLE_NV                             = $9368;
  GL_FONT_TARGET_UNAVAILABLE_NV                           = $9369;
  GL_FONT_UNAVAILABLE_NV                                  = $936A;
  GL_FONT_UNINTELLIGIBLE_NV                               = $936B;
  GL_CONIC_CURVE_TO_NV                                    = $1A;
  GL_RELATIVE_CONIC_CURVE_TO_NV                           = $1B;
  GL_FONT_NUM_GLYPH_INDICES_BIT_NV                        = $20000000;
  GL_STANDARD_FONT_FORMAT_NV                              = $936C;
  GL_PATH_PROJECTION_NV                                   = $1701;
  GL_PATH_MODELVIEW_NV                                    = $1700;
  GL_PATH_MODELVIEW_STACK_DEPTH_NV                        = $0BA3;
  GL_PATH_MODELVIEW_MATRIX_NV                             = $0BA6;
  GL_PATH_MAX_MODELVIEW_STACK_DEPTH_NV                    = $0D36;
  GL_PATH_TRANSPOSE_MODELVIEW_MATRIX_NV                   = $84E3;
  GL_PATH_PROJECTION_STACK_DEPTH_NV                       = $0BA4;
  GL_PATH_PROJECTION_MATRIX_NV                            = $0BA7;
  GL_PATH_MAX_PROJECTION_STACK_DEPTH_NV                   = $0D38;
  GL_PATH_TRANSPOSE_PROJECTION_MATRIX_NV                  = $84E4;
  GL_FRAGMENT_INPUT_NV                                    = $936D;
type
  TglGenPathsNV                                           = function (aRange: GLsizei): GLuint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDeletePathsNV                                        = procedure(aPath: GLuint; aRange: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsPathNV                                             = function (aPath: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathCommandsNV                                       = procedure(aPath: GLuint; aNumCommands: GLsizei; const aCommands: PGLubyte; aNumCoords: GLsizei; aCoordType: GLenum; const aCoords: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathCoordsNV                                         = procedure(aPath: GLuint; aNumCoords: GLsizei; aCoordType: GLenum; const aCoords: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathSubCommandsNV                                    = procedure(aPath: GLuint; aCommandStart: GLsizei; aCommandsToDelete: GLsizei; aNumCommands: GLsizei; const aCommands: PGLubyte; aNumCoords: GLsizei; aCoordType: GLenum; const aCoords: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathSubCoordsNV                                      = procedure(aPath: GLuint; aCoordStart: GLsizei; aNumCoords: GLsizei; aCoordType: GLenum; const aCoords: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathStringNV                                         = procedure(aPath: GLuint; aFormat: GLenum; aLength: GLsizei; const aPathString: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathGlyphsNV                                         = procedure(aFirstPathName: GLuint; aFontTarget: GLenum; const aFontName: Pointer; aFontStyle: GLbitfield; aNumGlyphs: GLsizei; aType: GLenum; const aCharcodes: Pointer; aHandleMissingGlyphs: GLenum; aPathParameterTemplate: GLuint; aEmScale: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathGlyphRangeNV                                     = procedure(aFirstPathName: GLuint; aFontTarget: GLenum; const aFontName: Pointer; aFontStyle: GLbitfield; aFirstGlyph: GLuint; aNumGlyphs: GLsizei; aHandleMissingGlyphs: GLenum; aPathParameterTemplate: GLuint; aEmScale: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglWeightPathsNV                                        = procedure(aResultPath: GLuint; aNumPaths: GLsizei; const aPaths: PGLuint; const aWeights: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCopyPathNV                                           = procedure(aResultPath: GLuint; aSrcPath: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglInterpolatePathsNV                                   = procedure(aResultPath: GLuint; aPathA: GLuint; aPathB: GLuint; aWeight: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglTransformPathNV                                      = procedure(aResultPath: GLuint; aSrcPath: GLuint; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathParameterivNV                                    = procedure(aPath: GLuint; aPname: GLenum; const aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathParameteriNV                                     = procedure(aPath: GLuint; aPname: GLenum; aValue: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathParameterfvNV                                    = procedure(aPath: GLuint; aPname: GLenum; const aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathParameterfNV                                     = procedure(aPath: GLuint; aPname: GLenum; aValue: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathDashArrayNV                                      = procedure(aPath: GLuint; aDashCount: GLsizei; const aDashArray: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathStencilFuncNV                                    = procedure(aFunc: GLenum; aRef: GLint; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathStencilDepthOffsetNV                             = procedure(aFactor: GLfloat; aUnits: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilFillPathNV                                    = procedure(aPath: GLuint; aFillMode: GLenum; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilStrokePathNV                                  = procedure(aPath: GLuint; aReference: GLint; aMask: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilFillPathInstancedNV                           = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aFillMode: GLenum; aMask: GLuint; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilStrokePathInstancedNV                         = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aReference: GLint; aMask: GLuint; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathCoverDepthFuncNV                                 = procedure(aFunc: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCoverFillPathNV                                      = procedure(aPath: GLuint; aCoverMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCoverStrokePathNV                                    = procedure(aPath: GLuint; aCoverMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCoverFillPathInstancedNV                             = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aCoverMode: GLenum; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglCoverStrokePathInstancedNV                           = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aCoverMode: GLenum; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathParameterivNV                                 = procedure(aPath: GLuint; aPname: GLenum; aValue: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathParameterfvNV                                 = procedure(aPath: GLuint; aPname: GLenum; aValue: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathCommandsNV                                    = procedure(aPath: GLuint; aCommands: PGLubyte); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathCoordsNV                                      = procedure(aPath: GLuint; aCoords: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathDashArrayNV                                   = procedure(aPath: GLuint; aDashArray: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathMetricsNV                                     = procedure(aMetricQueryMask: GLbitfield; aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aStride: GLsizei; aMetrics: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathMetricRangeNV                                 = procedure(aMetricQueryMask: GLbitfield; aFirstPathName: GLuint; aNumPaths: GLsizei; aStride: GLsizei; aMetrics: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathSpacingNV                                     = procedure(aPathListMode: GLenum; aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aAdvanceScale: GLfloat; aKerningScale: GLfloat; aTransformType: GLenum; aReturnedSpacing: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsPointInFillPathNV                                  = function (aPath: GLuint; aMask: GLuint; x: GLfloat; y: GLfloat): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsPointInStrokePathNV                                = function (aPath: GLuint; x: GLfloat; y: GLfloat): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetPathLengthNV                                      = function (aPath: GLuint; aStartSegment: GLsizei; aNumSegments: GLsizei): GLfloat; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPointAlongPathNV                                     = function (aPath: GLuint; aStartSegment: GLsizei; aNumSegments: GLsizei; aDistance: GLfloat; x: PGLfloat; y: PGLfloat; aTangentX: PGLfloat; aTangentY: PGLfloat): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixLoad3x2fNV                                     = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixLoad3x3fNV                                     = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixLoadTranspose3x3fNV                            = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixMult3x2fNV                                     = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixMult3x3fNV                                     = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglMatrixMultTranspose3x3fNV                            = procedure(aMatrixMode: GLenum; const m: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilThenCoverFillPathNV                           = procedure(aPath: GLuint; aFillMode: GLenum; aMask: GLuint; aCoverMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilThenCoverStrokePathNV                         = procedure(aPath: GLuint; aReference: GLint; aMask: GLuint; aCoverMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilThenCoverFillPathInstancedNV                  = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aFillMode: GLenum; aMask: GLuint; aCoverMode: GLenum; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglStencilThenCoverStrokePathInstancedNV                = procedure(aNumPaths: GLsizei; aPathNameType: GLenum; const aPaths: Pointer; aPathBase: GLuint; aReference: GLint; aMask: GLuint; aCoverMode: GLenum; aTransformType: GLenum; const aTransformValues: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathGlyphIndexRangeNV                                = function (aFontTarget: GLenum; const aFontName: Pointer; aFontStyle: GLbitfield; aPathParameterTemplate: GLuint; aEmScale: GLfloat; aBaseAndCount: PGLuint): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathGlyphIndexArrayNV                                = function (aFirstPathName: GLuint; aFontTarget: GLenum; const aFontName: Pointer; aFontStyle: GLbitfield; aFirstGlyphIndex: GLuint; aNumGlyphs: GLsizei; aPathParameterTemplate: GLuint; aEmScale: GLfloat): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglPathMemoryGlyphIndexArrayNV                          = function (aFirstPathName: GLuint; aFontTarget: GLenum; aFontSize: GLsizeiptr; const aFontData: Pointer; aFaceIndex: GLsizei; aFirstGlyphIndex: GLuint; aNumGlyphs: GLsizei; aPathParameterTemplate: GLuint; aEmScale: GLfloat): GLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglProgramPathFragmentInputGenNV                        = procedure(aProgram: GLuint; aLocation: GLint; aGenMode: GLenum; aComponents: GLint; const aCoeffs: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetProgramResourcefvNV                               = procedure(aProgram: GLuint; aProgramInterface: GLenum; aIndex: GLuint; aPropCount: GLsizei; const aProps: PGLenum; aBufSize: GLsizei; aLength: PGLsizei; aParams: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGenPathsNV:                                             TglGenPathsNV;
  glDeletePathsNV:                                          TglDeletePathsNV;
  glIsPathNV:                                               TglIsPathNV;
  glPathCommandsNV:                                         TglPathCommandsNV;
  glPathCoordsNV:                                           TglPathCoordsNV;
  glPathSubCommandsNV:                                      TglPathSubCommandsNV;
  glPathSubCoordsNV:                                        TglPathSubCoordsNV;
  glPathStringNV:                                           TglPathStringNV;
  glPathGlyphsNV:                                           TglPathGlyphsNV;
  glPathGlyphRangeNV:                                       TglPathGlyphRangeNV;
  glWeightPathsNV:                                          TglWeightPathsNV;
  glCopyPathNV:                                             TglCopyPathNV;
  glInterpolatePathsNV:                                     TglInterpolatePathsNV;
  glTransformPathNV:                                        TglTransformPathNV;
  glPathParameterivNV:                                      TglPathParameterivNV;
  glPathParameteriNV:                                       TglPathParameteriNV;
  glPathParameterfvNV:                                      TglPathParameterfvNV;
  glPathParameterfNV:                                       TglPathParameterfNV;
  glPathDashArrayNV:                                        TglPathDashArrayNV;
  glPathStencilFuncNV:                                      TglPathStencilFuncNV;
  glPathStencilDepthOffsetNV:                               TglPathStencilDepthOffsetNV;
  glStencilFillPathNV:                                      TglStencilFillPathNV;
  glStencilStrokePathNV:                                    TglStencilStrokePathNV;
  glStencilFillPathInstancedNV:                             TglStencilFillPathInstancedNV;
  glStencilStrokePathInstancedNV:                           TglStencilStrokePathInstancedNV;
  glPathCoverDepthFuncNV:                                   TglPathCoverDepthFuncNV;
  glCoverFillPathNV:                                        TglCoverFillPathNV;
  glCoverStrokePathNV:                                      TglCoverStrokePathNV;
  glCoverFillPathInstancedNV:                               TglCoverFillPathInstancedNV;
  glCoverStrokePathInstancedNV:                             TglCoverStrokePathInstancedNV;
  glGetPathParameterivNV:                                   TglGetPathParameterivNV;
  glGetPathParameterfvNV:                                   TglGetPathParameterfvNV;
  glGetPathCommandsNV:                                      TglGetPathCommandsNV;
  glGetPathCoordsNV:                                        TglGetPathCoordsNV;
  glGetPathDashArrayNV:                                     TglGetPathDashArrayNV;
  glGetPathMetricsNV:                                       TglGetPathMetricsNV;
  glGetPathMetricRangeNV:                                   TglGetPathMetricRangeNV;
  glGetPathSpacingNV:                                       TglGetPathSpacingNV;
  glIsPointInFillPathNV:                                    TglIsPointInFillPathNV;
  glIsPointInStrokePathNV:                                  TglIsPointInStrokePathNV;
  glGetPathLengthNV:                                        TglGetPathLengthNV;
  glPointAlongPathNV:                                       TglPointAlongPathNV;
  glMatrixLoad3x2fNV:                                       TglMatrixLoad3x2fNV;
  glMatrixLoad3x3fNV:                                       TglMatrixLoad3x3fNV;
  glMatrixLoadTranspose3x3fNV:                              TglMatrixLoadTranspose3x3fNV;
  glMatrixMult3x2fNV:                                       TglMatrixMult3x2fNV;
  glMatrixMult3x3fNV:                                       TglMatrixMult3x3fNV;
  glMatrixMultTranspose3x3fNV:                              TglMatrixMultTranspose3x3fNV;
  glStencilThenCoverFillPathNV:                             TglStencilThenCoverFillPathNV;
  glStencilThenCoverStrokePathNV:                           TglStencilThenCoverStrokePathNV;
  glStencilThenCoverFillPathInstancedNV:                    TglStencilThenCoverFillPathInstancedNV;
  glStencilThenCoverStrokePathInstancedNV:                  TglStencilThenCoverStrokePathInstancedNV;
  glPathGlyphIndexRangeNV:                                  TglPathGlyphIndexRangeNV;
  glPathGlyphIndexArrayNV:                                  TglPathGlyphIndexArrayNV;
  glPathMemoryGlyphIndexArrayNV:                            TglPathMemoryGlyphIndexArrayNV;
  glProgramPathFragmentInputGenNV:                          TglProgramPathFragmentInputGenNV;
  glGetProgramResourcefvNV:                                 TglGetProgramResourcefvNV;

{ GL_NV_read_buffer }
const
  GL_READ_BUFFER_NV                                       = $0C02;
type
  TglReadBufferNV                                         = procedure(aMode: GLenum); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glReadBufferNV:                                           TglReadBufferNV;

{ GL_NV_read_buffer_front }
  // none

{ GL_NV_read_depth }
  // none

{ GL_NV_read_depth_stencil }
  // none

{ GL_NV_read_stencil }
  // none

{ GL_NV_sRGB_formats }
const
  GL_SLUMINANCE_NV                                        = $8C46;
  GL_SLUMINANCE_ALPHA_NV                                  = $8C44;
  GL_SRGB8_NV                                             = $8C41;
  GL_SLUMINANCE8_NV                                       = $8C47;
  GL_SLUMINANCE8_ALPHA8_NV                                = $8C45;
  GL_COMPRESSED_SRGB_S3TC_DXT1_NV                         = $8C4C;
  GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_NV                   = $8C4D;
  GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_NV                   = $8C4E;
  GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_NV                   = $8C4F;
  GL_ETC1_SRGB8_NV                                        = $88EE;

{ GL_NV_shader_noperspective_interpolation }
  // none

{ GL_NV_shadow_samplers_array }
const
  GL_SAMPLER_2D_ARRAY_SHADOW_NV                           = $8DC4;

{ GL_NV_shadow_samplers_cube }
const
  GL_SAMPLER_CUBE_SHADOW_NV                               = $8DC5;

{ GL_NV_texture_border_clamp }
const
  GL_TEXTURE_BORDER_COLOR_NV                              = $1004;
  GL_CLAMP_TO_BORDER_NV                                   = $812D;

{ GL_NV_texture_compression_s3tc_update }
  // none

{ GL_NV_texture_npot_2D_mipmap }
  // none

{ GL_NV_viewport_array }
const
  GL_MAX_VIEWPORTS_NV                                     = $825B;
  GL_VIEWPORT_SUBPIXEL_BITS_NV                            = $825C;
  GL_VIEWPORT_BOUNDS_RANGE_NV                             = $825D;
  GL_VIEWPORT_INDEX_PROVOKING_VERTEX_NV                   = $825F;
type
  TglViewportArrayvNV                                     = procedure(aFirst: GLuint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglViewportIndexedfNV                                   = procedure(aIndex: GLuint; x: GLfloat; y: GLfloat; w: GLfloat; h: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglViewportIndexedfvNV                                  = procedure(aIndex: GLuint; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScissorArrayvNV                                      = procedure(aFirst: GLuint; aCount: GLsizei; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScissorIndexedNV                                     = procedure(aIndex: GLuint; aLeft: GLint; aBottom: GLint; aWidth: GLsizei; aHeight: GLsizei); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglScissorIndexedvNV                                    = procedure(aIndex: GLuint; const v: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthRangeArrayfvNV                                  = procedure(aFirst: GLuint; aCount: GLsizei; const v: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDepthRangeIndexedfNV                                 = procedure(aIndex: GLuint; n: GLfloat; f: GLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetFloati_vNV                                        = procedure(aTarget: GLenum; aIndex: GLuint; aData: PGLfloat); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEnableiNV                                            = procedure(aTarget: GLenum; aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisableiNV                                           = procedure(aTarget: GLenum; aIndex: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglIsEnablediNV                                         = function (aTarget: GLenum; aIndex: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glViewportArrayvNV:                                       TglViewportArrayvNV;
  glViewportIndexedfNV:                                     TglViewportIndexedfNV;
  glViewportIndexedfvNV:                                    TglViewportIndexedfvNV;
  glScissorArrayvNV:                                        TglScissorArrayvNV;
  glScissorIndexedNV:                                       TglScissorIndexedNV;
  glScissorIndexedvNV:                                      TglScissorIndexedvNV;
  glDepthRangeArrayfvNV:                                    TglDepthRangeArrayfvNV;
  glDepthRangeIndexedfNV:                                   TglDepthRangeIndexedfNV;
  glGetFloati_vNV:                                          TglGetFloati_vNV;
  glEnableiNV:                                              TglEnableiNV;
  glDisableiNV:                                             TglDisableiNV;
  glIsEnablediNV:                                           TglIsEnablediNV;

{ GL_QCOM_alpha_test }
const
  GL_ALPHA_TEST_QCOM                                      = $0BC0;
  GL_ALPHA_TEST_FUNC_QCOM                                 = $0BC1;
  GL_ALPHA_TEST_REF_QCOM                                  = $0BC2;
type
  TglAlphaFuncQCOM                                        = procedure(aFunc: GLenum; aRef: GLclampf); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glAlphaFuncQCOM:                                          TglAlphaFuncQCOM;

{ GL_QCOM_binning_control }
const
  GL_BINNING_CONTROL_HINT_QCOM                            = $8FB0;
  GL_CPU_OPTIMIZED_QCOM                                   = $8FB1;
  GL_GPU_OPTIMIZED_QCOM                                   = $8FB2;
  GL_RENDER_DIRECT_TO_FRAMEBUFFER_QCOM                    = $8FB3;

{ GL_QCOM_driver_control }
type
  TglGetDriverControlsQCOM                                = procedure(aNum: PGLint; aSize: GLsizei; aDriverControls: PGLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglGetDriverControlStringQCOM                           = procedure(aDriverControl: GLuint; aBufSize: GLsizei; aLength: PGLsizei; aDriverControlString: PGLchar); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEnableDriverControlQCOM                              = procedure(aDriverControl: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglDisableDriverControlQCOM                             = procedure(aDriverControl: GLuint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glGetDriverControlsQCOM:                                  TglGetDriverControlsQCOM;
  glGetDriverControlStringQCOM:                             TglGetDriverControlStringQCOM;
  glEnableDriverControlQCOM:                                TglEnableDriverControlQCOM;
  glDisableDriverControlQCOM:                               TglDisableDriverControlQCOM;

{ GL_QCOM_extended_get }
const
  GL_TEXTURE_WIDTH_QCOM                                   = $8BD2;
  GL_TEXTURE_HEIGHT_QCOM                                  = $8BD3;
  GL_TEXTURE_DEPTH_QCOM                                   = $8BD4;
  GL_TEXTURE_INTERNAL_FORMAT_QCOM                         = $8BD5;
  GL_TEXTURE_FORMAT_QCOM                                  = $8BD6;
  GL_TEXTURE_TYPE_QCOM                                    = $8BD7;
  GL_TEXTURE_IMAGE_VALID_QCOM                             = $8BD8;
  GL_TEXTURE_NUM_LEVELS_QCOM                              = $8BD9;
  GL_TEXTURE_TARGET_QCOM                                  = $8BDA;
  GL_TEXTURE_OBJECT_VALID_QCOM                            = $8BDB;
  GL_STATE_RESTORE                                        = $8BDC;
type
  TglExtGetTexturesQCOM                                   = procedure(aTextures: PGLuint; aMaxTextures: GLint; aNumTextures: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetBuffersQCOM                                    = procedure(aBuffers: PGLuint; aMaxBuffers: GLint; aNumBuffers: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetRenderbuffersQCOM                              = procedure(aRenderbuffers: PGLuint; aMaxRenderbuffers: GLint; aNumRenderbuffers: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetFramebuffersQCOM                               = procedure(aFramebuffers: PGLuint; aMaxFramebuffers: GLint; aNumFramebuffers: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetTexLevelParameterivQCOM                        = procedure(aTexture: GLuint; aFace: GLenum; aLevel: GLint; aPname: GLenum; aParams: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtTexObjectStateOverrideiQCOM                       = procedure(aTarget: GLenum; aPname: GLenum; aParam: GLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetTexSubImageQCOM                                = procedure(aTarget: GLenum; aLevel: GLint; aXoffset: GLint; aYoffset: GLint; aZoffset: GLint; aWidth: GLsizei; aHeight: GLsizei; aDepth: GLsizei; aFormat: GLenum; aType: GLenum; aTexels: Pointer); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetBufferPointervQCOM                             = procedure(aTarget: GLenum; aParams: PPGLvoid); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glExtGetTexturesQCOM:                                     TglExtGetTexturesQCOM;
  glExtGetBuffersQCOM:                                      TglExtGetBuffersQCOM;
  glExtGetRenderbuffersQCOM:                                TglExtGetRenderbuffersQCOM;
  glExtGetFramebuffersQCOM:                                 TglExtGetFramebuffersQCOM;
  glExtGetTexLevelParameterivQCOM:                          TglExtGetTexLevelParameterivQCOM;
  glExtTexObjectStateOverrideiQCOM:                         TglExtTexObjectStateOverrideiQCOM;
  glExtGetTexSubImageQCOM:                                  TglExtGetTexSubImageQCOM;
  glExtGetBufferPointervQCOM:                               TglExtGetBufferPointervQCOM;

{ GL_QCOM_extended_get2 }
type
  TglExtGetShadersQCOM                                    = procedure(aShaders: PGLuint; aMaxShaders: GLint; aNumShaders: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetProgramsQCOM                                   = procedure(aPrograms: PGLuint; aMaxPrograms: GLint; aNumPrograms: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtIsProgramBinaryQCOM                               = function (aProgram: GLuint): GLboolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglExtGetProgramBinarySourceQCOM                        = procedure(aProgram: GLuint; aShadertype: GLenum; aSource: PGLchar; aLength: PGLint); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glExtGetShadersQCOM:                                      TglExtGetShadersQCOM;
  glExtGetProgramsQCOM:                                     TglExtGetProgramsQCOM;
  glExtIsProgramBinaryQCOM:                                 TglExtIsProgramBinaryQCOM;
  glExtGetProgramBinarySourceQCOM:                          TglExtGetProgramBinarySourceQCOM;

{ GL_QCOM_perfmon_global_mode }
const
  GL_PERFMON_GLOBAL_MODE_QCOM                             = $8FA0;

{ GL_QCOM_tiled_rendering }
const
  GL_COLOR_BUFFER_BIT0_QCOM                               = $00000001;
  GL_COLOR_BUFFER_BIT1_QCOM                               = $00000002;
  GL_COLOR_BUFFER_BIT2_QCOM                               = $00000004;
  GL_COLOR_BUFFER_BIT3_QCOM                               = $00000008;
  GL_COLOR_BUFFER_BIT4_QCOM                               = $00000010;
  GL_COLOR_BUFFER_BIT5_QCOM                               = $00000020;
  GL_COLOR_BUFFER_BIT6_QCOM                               = $00000040;
  GL_COLOR_BUFFER_BIT7_QCOM                               = $00000080;
  GL_DEPTH_BUFFER_BIT0_QCOM                               = $00000100;
  GL_DEPTH_BUFFER_BIT1_QCOM                               = $00000200;
  GL_DEPTH_BUFFER_BIT2_QCOM                               = $00000400;
  GL_DEPTH_BUFFER_BIT3_QCOM                               = $00000800;
  GL_DEPTH_BUFFER_BIT4_QCOM                               = $00001000;
  GL_DEPTH_BUFFER_BIT5_QCOM                               = $00002000;
  GL_DEPTH_BUFFER_BIT6_QCOM                               = $00004000;
  GL_DEPTH_BUFFER_BIT7_QCOM                               = $00008000;
  GL_STENCIL_BUFFER_BIT0_QCOM                             = $00010000;
  GL_STENCIL_BUFFER_BIT1_QCOM                             = $00020000;
  GL_STENCIL_BUFFER_BIT2_QCOM                             = $00040000;
  GL_STENCIL_BUFFER_BIT3_QCOM                             = $00080000;
  GL_STENCIL_BUFFER_BIT4_QCOM                             = $00100000;
  GL_STENCIL_BUFFER_BIT5_QCOM                             = $00200000;
  GL_STENCIL_BUFFER_BIT6_QCOM                             = $00400000;
  GL_STENCIL_BUFFER_BIT7_QCOM                             = $00800000;
  GL_MULTISAMPLE_BUFFER_BIT0_QCOM                         = $01000000;
  GL_MULTISAMPLE_BUFFER_BIT1_QCOM                         = $02000000;
  GL_MULTISAMPLE_BUFFER_BIT2_QCOM                         = $04000000;
  GL_MULTISAMPLE_BUFFER_BIT3_QCOM                         = $08000000;
  GL_MULTISAMPLE_BUFFER_BIT4_QCOM                         = $10000000;
  GL_MULTISAMPLE_BUFFER_BIT5_QCOM                         = $20000000;
  GL_MULTISAMPLE_BUFFER_BIT6_QCOM                         = $40000000;
  GL_MULTISAMPLE_BUFFER_BIT7_QCOM                         = $80000000;
type
  TglStartTilingQCOM                                      = procedure(x: GLuint; y: GLuint; aWidth: GLuint; aHeight: GLuint; aPreserveMask: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TglEndTilingQCOM                                        = procedure(aPreserveMask: GLbitfield); {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
var
  glStartTilingQCOM:                                        TglStartTilingQCOM;
  glEndTilingQCOM:                                          TglEndTilingQCOM;

{ GL_QCOM_writeonly_rendering }
const
  GL_WRITEONLY_RENDERING_QCOM                             = $8823;

{ GL_VIV_shader_binary }
const
  GL_SHADER_BINARY_VIV                                    = $8FC4;
{$ENDIF}

{ ================================================== EGL ============================================================= }
type
  EGLint                = Integer;
  EGLboolean            = Cardinal;
  EGLenum               = Cardinal;
  EGLConfig             = Pointer;
  EGLContext            = Pointer;
  EGLDisplay            = Pointer;
  EGLSurface            = Pointer;
  EGLClientBuffer       = Pointer;
  EGLNativeDisplayType  = Pointer;
  EGLNativePixmapType   = Pointer;
  EGLNativeWindowType   = packed record
     element: Cardinal;
     width: Integer;
     height: Integer;
  end;

  PEGLint               = ^EGLint;
  PEGLboolean           = ^EGLboolean;
  PEGLenum              = ^EGLenum;
  PEGLConfig            = ^EGLConfig;
  PEGLContext           = ^EGLContext;
  PEGLDisplay           = ^EGLDisplay;
  PEGLSurface           = ^EGLSurface;
  PEGLClientBuffer      = ^EGLClientBuffer;
  PEGLNativeDisplayType = ^EGLNativeDisplayType;
  PEGLNativePixmapType  = ^EGLNativePixmapType;
  PEGLNativeWindowType  = ^EGLNativeWindowType;

const
  EGL_FALSE: EGLboolean = 0;
  EGL_TRUE:  EGLboolean = 1;

  EGL_DEFAULT_DISPLAY:  EGLNativeDisplayType  = nil;
  EGL_NO_CONTEXT:     	EGLContext           	= nil;
  EGL_NO_DISPLAY:			  EGLDisplay            = nil;
  EGL_NO_SURFACE:			  EGLSurface            = nil;

  EGL_DONT_CARE: EGLint = -1;

  EGL_SUCCESS                         = $3000;
  EGL_NOT_INITIALIZED                 = $3001;
  EGL_BAD_ACCESS                      = $3002;
  EGL_BAD_ALLOC                       = $3003;
  EGL_BAD_ATTRIBUTE                   = $3004;
  EGL_BAD_CONFIG                      = $3005;
  EGL_BAD_CONTEXT                     = $3006;
  EGL_BAD_CURRENT_SURFACE             = $3007;
  EGL_BAD_DISPLAY                     = $3008;
  EGL_BAD_MATCH                       = $3009;
  EGL_BAD_NATIVE_PIXMAP               = $300A;
  EGL_BAD_NATIVE_WINDOW               = $300B;
  EGL_BAD_PARAMETER                   = $300C;
  EGL_BAD_SURFACE                     = $300D;
  EGL_CONTEXT_LOST                    = $300E;

  EGL_BUFFER_SIZE                     = $3020;
  EGL_ALPHA_SIZE                      = $3021;
  EGL_BLUE_SIZE                       = $3022;
  EGL_GREEN_SIZE                      = $3023;
  EGL_RED_SIZE                        = $3024;
  EGL_DEPTH_SIZE                      = $3025;
  EGL_STENCIL_SIZE                    = $3026;
  EGL_CONFIG_CAVEAT                   = $3027;
  EGL_CONFIG_ID                       = $3028;
  EGL_LEVEL                           = $3029;
  EGL_MAX_PBUFFER_HEIGHT              = $302A;
  EGL_MAX_PBUFFER_PIXELS              = $302B;
  EGL_MAX_PBUFFER_WIDTH               = $302C;
  EGL_NATIVE_RENDERABLE               = $302D;
  EGL_NATIVE_VISUAL_ID                = $302E;
  EGL_NATIVE_VISUAL_TYPE              = $302F;
  EGL_SAMPLES                         = $3031;
  EGL_SAMPLE_BUFFERS                  = $3032;
  EGL_SURFACE_TYPE                    = $3033;
  EGL_TRANSPARENT_TYPE                = $3034;
  EGL_TRANSPARENT_BLUE_VALUE          = $3035;
  EGL_TRANSPARENT_GREEN_VALUE         = $3036;
  EGL_TRANSPARENT_RED_VALUE           = $3037;
  EGL_NONE                            = $3038;
  EGL_BIND_TO_TEXTURE_RGB             = $3039;
  EGL_BIND_TO_TEXTURE_RGBA            = $303A;
  EGL_MIN_SWAP_INTERVAL               = $303B;
  EGL_MAX_SWAP_INTERVAL               = $303C;
  EGL_LUMINANCE_SIZE                  = $303D;
  EGL_ALPHA_MASK_SIZE                 = $303E;
  EGL_COLOR_BUFFER_TYPE               = $303F;
  EGL_RENDERABLE_TYPE                 = $3040;
  EGL_MATCH_NATIVE_PIXMAP             = $3041;
  EGL_CONFORMANT                      = $3042;

  EGL_SLOW_CONFIG                     = $3050;
  EGL_NON_CONFORMANT_CONFIG           = $3051;
  EGL_TRANSPARENT_RGB                 = $3052;
  EGL_RGB_BUFFER                      = $308E;
  EGL_LUMINANCE_BUFFER                = $308F;

  EGL_NO_TEXTURE                      = $305C;
  EGL_TEXTURE_RGB                     = $305D;
  EGL_TEXTURE_RGBA                    = $305E;
  EGL_TEXTURE_2D                      = $305F;

  EGL_PBUFFER_BIT                     = $0001;
  EGL_PIXMAP_BIT                      = $0002;
  EGL_WINDOW_BIT                      = $0004;
  EGL_VG_COLORSPACE_LINEAR_BIT        = $0020;
  EGL_VG_ALPHA_FORMAT_PRE_BIT         = $0040;
  EGL_MULTISAMPLE_RESOLVE_BOX_BIT     = $0200;
  EGL_SWAP_BEHAVIOR_PRESERVED_BIT     = $0400;

  EGL_OPENGL_ES_BIT                   = $0001;
  EGL_OPENVG_BIT                      = $0002;
  EGL_OPENGL_ES2_BIT                  = $0004;
  EGL_OPENGL_BIT                      = $0008;

  EGL_VENDOR                          = $3053;
  EGL_VERSION                         = $3054;
  EGL_EXTENSIONS                      = $3055;
  EGL_CLIENT_APIS                     = $308D;

  EGL_HEIGHT                          = $3056;
  EGL_WIDTH                           = $3057;
  EGL_LARGEST_PBUFFER                 = $3058;
  EGL_TEXTURE_FORMAT                  = $3080;
  EGL_TEXTURE_TARGET                  = $3081;
  EGL_MIPMAP_TEXTURE                  = $3082;
  EGL_MIPMAP_LEVEL                    = $3083;
  EGL_RENDER_BUFFER                   = $3086;
  EGL_VG_COLORSPACE                   = $3087;
  EGL_VG_ALPHA_FORMAT                 = $3088;
  EGL_HORIZONTAL_RESOLUTION           = $3090;
  EGL_VERTICAL_RESOLUTION             = $3091;
  EGL_PIXEL_ASPECT_RATIO              = $3092;
  EGL_SWAP_BEHAVIOR                   = $3093;
  EGL_MULTISAMPLE_RESOLVE             = $3099;

  EGL_BACK_BUFFER                     = $3084;
  EGL_SINGLE_BUFFER                   = $3085;

  EGL_VG_COLORSPACE_sRGB              = $3089;
  EGL_VG_COLORSPACE_LINEAR            = $308A;

  EGL_VG_ALPHA_FORMAT_NONPRE          = $308B;
  EGL_VG_ALPHA_FORMAT_PRE             = $308C;

  EGL_DISPLAY_SCALING                 = 10000;

  EGL_UNKNOWN: EGLint                 = -1;

  EGL_BUFFER_PRESERVED                = $3094;
  EGL_BUFFER_DESTROYED                = $3095;

  EGL_OPENVG_IMAGE                    = $3096;

  EGL_CONTEXT_CLIENT_TYPE             = $3097;

  EGL_CONTEXT_CLIENT_VERSION          = $3098;

  EGL_MULTISAMPLE_RESOLVE_DEFAULT     = $309A;
  EGL_MULTISAMPLE_RESOLVE_BOX         = $309B;

  EGL_OPENGL_ES_API                   = $30A0;
  EGL_OPENVG_API                      = $30A1;
  EGL_OPENGL_API                      = $30A2;

  EGL_DRAW                            = $3059;
  EGL_READ                            = $305A;

  EGL_CORE_NATIVE_ENGINE              = $305B;

  EGL_COLORSPACE                      = EGL_VG_COLORSPACE;
  EGL_ALPHA_FORMAT                    = EGL_VG_ALPHA_FORMAT;
  EGL_COLORSPACE_sRGB                 = EGL_VG_COLORSPACE_sRGB;
  EGL_COLORSPACE_LINEAR               = EGL_VG_COLORSPACE_LINEAR;
  EGL_ALPHA_FORMAT_NONPRE             = EGL_VG_ALPHA_FORMAT_NONPRE;
  EGL_ALPHA_FORMAT_PRE                = EGL_VG_ALPHA_FORMAT_PRE;

type
  TeglGetError  = function: EGLint; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglGetDisplay  = function(aDisplayID: EGLNativeDisplayType): EGLDisplay; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglInitialize  = function(aDisplay: EGLDisplay; aMajor, aMinor: PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglTerminate   = function(aDisplay: EGLDisplay): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglQueryString = function(aDisplay: EGLDisplay; name: EGLint): PAnsiChar; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglGetConfigs      = function(aDisplay: EGLDisplay; aConfigs: PEGLConfig; aConfigSize: EGLint; numConfig: PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglChooseConfig    = function(aDisplay: EGLDisplay; const aAttribList: PEGLint; aConfigs: PEGLConfig; aConfigSize: EGLint; numConfig: PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglGetConfigAttrib = function(aDisplay: EGLDisplay; aConfig: EGLConfig; aAttribute: EGLint; aValue : PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglCreateWindowSurface   = function(aDisplay: EGLDisplay; aConfig: EGLConfig; aWinType: PEGLNativeWindowType; const aAttribList: PEGLint): EGLSurface; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglCreatePbufferSurface  = function(aDisplay: EGLDisplay; aConfig: EGLConfig; const aAttribList: PEGLint): EGLSurface; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglCreatePixmapSurface   = function(aDisplay: EGLDisplay; aConfig: EGLConfig; aPixmap: EGLNativePixmapType; const aAttribList: PEGLint): EGLSurface; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglDestroySurface        = function(aDisplay: EGLDisplay; aSurface: EGLSurface): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglQuerySurface          = function(aDisplay: EGLDisplay; aSurface: EGLSurface; aAttribute: EGLint; aValue: PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglBindAPI   = function(aApi: EGLenum): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglQueryAPI  = function: EGLenum; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglWaitClient = function: EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglReleaseThread = function: EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglCreatePbufferFromClientBuffer = function(aDisplay: EGLDisplay; aBufType: EGLenum; aBuffer: EGLClientBuffer; aConfig: EGLConfig; const aAttribList: PEGLint): EGLSurface; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglSurfaceAttrib   = function(aDisplay: EGLDisplay; aSurface: EGLSurface; aAttribute: EGLint; aValue: EGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglBindTexImage    = function(aDisplay: EGLDisplay; aSurface: EGLSurface; aBuffer: EGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglReleaseTexImage = function(aDisplay: EGLDisplay; aSurface: EGLSurface; aBuffer: EGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglSwapInterval = function(aDisplay: EGLDisplay; aInterval: EGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglCreateContext   = function(aDisplay: EGLDisplay; aConfig: EGLConfig; aShareContext: EGLContext; const aAttribList: PEGLint): EGLContext; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglDestroyContext  = function(aDisplay: EGLDisplay; aContext: EGLContext): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglMakeCurrent     = function(aDisplay: EGLDisplay; aDraw: EGLSurface; aRead: EGLSurface; aContext: EGLContext): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglGetCurrentContext = function: EGLContext; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglGetCurrentSurface = function(aReadDraw: EGLint): EGLSurface; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglGetCurrentDisplay = function: EGLDisplay; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglQueryContext      = function(aDisplay: EGLDisplay; aContext: EGLContext; aAttribute: EGLint; aValue: PEGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglWaitGL      = function: EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglWaitNative  = function(aEngine: EGLint): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglSwapBuffers = function(aDisplay: EGLDisplay; aSurface: EGLSurface): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
  TeglCopyBuffers = function(aDisplay: EGLDisplay; aSurface: EGLSurface; aTarget: EGLNativePixmapType): EGLBoolean; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

  TeglGetProcAddress = function(const aProcName: PAnsiChar): Pointer; {$IFDEF DGL_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}

var
  eglGetError: TeglGetError;

  eglGetDisplay:  TeglGetDisplay;
  eglInitialize:  TeglInitialize;
  eglTerminate:   TeglTerminate;

  eglQueryString: TeglQueryString;

  eglGetConfigs:      TeglGetConfigs;
  eglChooseConfig:    TeglChooseConfig;
  eglGetConfigAttrib: TeglGetConfigAttrib;

  eglCreateWindowSurface:   TeglCreateWindowSurface;
  eglCreatePbufferSurface:  TeglCreatePbufferSurface;
  eglCreatePixmapSurface:   TeglCreatePixmapSurface;
  eglDestroySurface:        TeglDestroySurface;
  eglQuerySurface:          TeglQuerySurface;

  eglBindAPI:   TeglBindAPI;
  eglQueryAPI:  TeglQueryAPI;

  eglWaitClient: TeglWaitClient;

  eglReleaseThread: TeglReleaseThread;

  eglCreatePbufferFromClientBuffer: TeglCreatePbufferFromClientBuffer;

  eglSurfaceAttrib:   TeglSurfaceAttrib;
  eglBindTexImage:    TeglBindTexImage;
  eglReleaseTexImage: TeglReleaseTexImage;

  eglSwapInterval: TeglSwapInterval;

  eglCreateContext:   TeglCreateContext;
  eglDestroyContext:  TeglDestroyContext;
  eglMakeCurrent:     TeglMakeCurrent;

  eglGetCurrentContext: TeglGetCurrentContext;
  eglGetCurrentSurface: TeglGetCurrentSurface;
  eglGetCurrentDisplay: TeglGetCurrentDisplay;
  eglQueryContext:      TeglQueryContext;

  eglWaitGL:      TeglWaitGL;
  eglWaitNative:  TeglWaitNative;
  eglSwapBuffers: TeglSwapBuffers;
  eglCopyBuffers: TeglCopyBuffers;

  eglGetProcAddress: TeglGetProcAddress;

{ =================================================== DelphiGL ======================================================= }
var
  GLmajor: Integer;
  GLminor: Integer;

  GL_VERSION_1_0,
  GL_VERSION_1_1,
  GL_VERSION_2_0,
  GL_VERSION_3_0,
  GL_VERSION_3_1
{$IFDEF OPENGLES_EXTENSIONS},
  GL_KHR_blend_equation_advanced,
  GL_KHR_blend_equation_advanced_coherent,
  GL_KHR_context_flush_control,
  GL_KHR_debug,
  GL_KHR_robust_buffer_access_behavior,
  GL_KHR_robustness,
  GL_KHR_texture_compression_astc_hdr,
  GL_KHR_texture_compression_astc_ldr,
  GL_OES_EGL_image,
  GL_OES_EGL_image_external,
  GL_OES_compressed_ETC1_RGB8_sub_texture,
  GL_OES_compressed_ETC1_RGB8_texture,
  GL_OES_compressed_paletted_texture,
  GL_OES_depth24,
  GL_OES_depth32,
  GL_OES_depth_texture,
  GL_OES_element_index_uint,
  GL_OES_fbo_render_mipmap,
  GL_OES_fragment_precision_high,
  GL_OES_get_program_binary,
  GL_OES_mapbuffer,
  GL_OES_packed_depth_stencil,
  GL_OES_required_internalformat,
  GL_OES_rgb8_rgba8,
  GL_OES_sample_shading,
  GL_OES_sample_variables,
  GL_OES_shader_image_atomic,
  GL_OES_shader_multisample_interpolation,
  GL_OES_standard_derivatives,
  GL_OES_stencil1,
  GL_OES_stencil4,
  GL_OES_surfaceless_context,
  GL_OES_texture_3D,
  GL_OES_texture_compression_astc,
  GL_OES_texture_float,
  GL_OES_texture_float_linear,
  GL_OES_texture_half_float,
  GL_OES_texture_half_float_linear,
  GL_OES_texture_npot,
  GL_OES_texture_stencil8,
  GL_OES_texture_storage_multisample_2d_array,
  GL_OES_vertex_array_object,
  GL_OES_vertex_half_float,
  GL_OES_vertex_type_10_10_10_2,
  GL_AMD_compressed_3DC_texture,
  GL_AMD_compressed_ATC_texture,
  GL_AMD_performance_monitor,
  GL_AMD_program_binary_Z400,
  GL_ANDROID_extension_pack_es31a,
  GL_ANGLE_depth_texture,
  GL_ANGLE_framebuffer_blit,
  GL_ANGLE_framebuffer_multisample,
  GL_ANGLE_instanced_arrays,
  GL_ANGLE_pack_reverse_row_order,
  GL_ANGLE_program_binary,
  GL_ANGLE_texture_compression_dxt3,
  GL_ANGLE_texture_compression_dxt5,
  GL_ANGLE_texture_usage,
  GL_ANGLE_translated_shader_source,
  GL_APPLE_clip_distance,
  GL_APPLE_color_buffer_packed_float,
  GL_APPLE_copy_texture_levels,
  GL_APPLE_framebuffer_multisample,
  GL_APPLE_rgb_422,
  GL_APPLE_sync,
  GL_APPLE_texture_format_BGRA8888,
  GL_APPLE_texture_max_level,
  GL_APPLE_texture_packed_float,
  GL_ARM_mali_program_binary,
  GL_ARM_mali_shader_binary,
  GL_ARM_rgba8,
  GL_ARM_shader_framebuffer_fetch,
  GL_ARM_shader_framebuffer_fetch_depth_stencil,
  GL_DMP_program_binary,
  GL_DMP_shader_binary,
  GL_EXT_base_instance,
  GL_EXT_blend_minmax,
  GL_EXT_color_buffer_half_float,
  GL_EXT_copy_image,
  GL_EXT_debug_label,
  GL_EXT_debug_marker,
  GL_EXT_discard_framebuffer,
  GL_EXT_disjoint_timer_query,
  GL_EXT_draw_buffers,
  GL_EXT_draw_buffers_indexed,
  GL_EXT_draw_elements_base_vertex,
  GL_EXT_draw_instanced,
  GL_EXT_geometry_point_size,
  GL_EXT_geometry_shader,
  GL_EXT_gpu_shader5,
  GL_EXT_instanced_arrays,
  GL_EXT_map_buffer_range,
  GL_EXT_multi_draw_arrays,
  GL_EXT_multi_draw_indirect,
  GL_EXT_multisampled_render_to_texture,
  GL_EXT_multiview_draw_buffers,
  GL_EXT_occlusion_query_boolean,
  GL_EXT_primitive_bounding_box,
  GL_EXT_pvrtc_sRGB,
  GL_EXT_read_format_bgra,
  GL_EXT_render_snorm,
  GL_EXT_robustness,
  GL_EXT_sRGB,
  GL_EXT_sRGB_write_control,
  GL_EXT_separate_shader_objects,
  GL_EXT_shader_framebuffer_fetch,
  GL_EXT_shader_implicit_conversions,
  GL_EXT_shader_integer_mix,
  GL_EXT_shader_io_blocks,
  GL_EXT_shader_pixel_local_storage,
  GL_EXT_shader_texture_lod,
  GL_EXT_shadow_samplers,
  GL_EXT_tessellation_point_size,
  GL_EXT_tessellation_shader,
  GL_EXT_texture_border_clamp,
  GL_EXT_texture_buffer,
  GL_EXT_texture_compression_dxt1,
  GL_EXT_texture_compression_s3tc,
  GL_EXT_texture_cube_map_array,
  GL_EXT_texture_filter_anisotropic,
  GL_EXT_texture_format_BGRA8888,
  GL_EXT_texture_norm16,
  GL_EXT_texture_rg,
  GL_EXT_texture_sRGB_decode,
  GL_EXT_texture_storage,
  GL_EXT_texture_type_2_10_10_10_REV,
  GL_EXT_texture_view,
  GL_EXT_unpack_subimage,
  GL_FJ_shader_binary_GCCSO,
  GL_IMG_multisampled_render_to_texture,
  GL_IMG_program_binary,
  GL_IMG_read_format,
  GL_IMG_shader_binary,
  GL_IMG_texture_compression_pvrtc,
  GL_IMG_texture_compression_pvrtc2,
  GL_INTEL_performance_query,
  GL_NV_bindless_texture,
  GL_NV_blend_equation_advanced,
  GL_NV_blend_equation_advanced_coherent,
  GL_NV_conditional_render,
  GL_NV_copy_buffer,
  GL_NV_coverage_sample,
  GL_NV_depth_nonlinear,
  GL_NV_draw_buffers,
  GL_NV_draw_instanced,
  GL_NV_explicit_attrib_location,
  GL_NV_fbo_color_attachments,
  GL_NV_fence,
  GL_NV_framebuffer_blit,
  GL_NV_framebuffer_multisample,
  GL_NV_generate_mipmap_sRGB,
  GL_NV_image_formats,
  GL_NV_instanced_arrays,
  GL_NV_internalformat_sample_query,
  GL_NV_non_square_matrices,
  GL_NV_path_rendering,
  GL_NV_read_buffer,
  GL_NV_read_buffer_front,
  GL_NV_read_depth,
  GL_NV_read_depth_stencil,
  GL_NV_read_stencil,
  GL_NV_sRGB_formats,
  GL_NV_shader_noperspective_interpolation,
  GL_NV_shadow_samplers_array,
  GL_NV_shadow_samplers_cube,
  GL_NV_texture_border_clamp,
  GL_NV_texture_compression_s3tc_update,
  GL_NV_texture_npot_2D_mipmap,
  GL_NV_viewport_array,
  GL_QCOM_alpha_test,
  GL_QCOM_binning_control,
  GL_QCOM_driver_control,
  GL_QCOM_extended_get,
  GL_QCOM_extended_get2,
  GL_QCOM_perfmon_global_mode,
  GL_QCOM_tiled_rendering,
  GL_QCOM_writeonly_rendering,
  GL_VIV_shader_binary
{$ENDIF}
    : Boolean;

type
  EdglOpenGLES = class(Exception);
  EeglError = class(EdglOpenGLES)
  public
    ErrorCode: EGLint;
    constructor Create(const msg: string; const aErrorCode: EGLint);
  end;

  TActivationFlag = (
    afReadOpenGLCore,
    afReadExtensions,
    afReadCoreVersion,
    afReadImplProp
  );
  TActivationFlags = set of TActivationFlag;

  TdglRenderContext = packed record
    Display: EGLDisplay;
    Surface: EGLSurface;
    Context: EGLContext;
  end;

function InitOpenGLES(const aOpenGLESLibName: String = LIBNAME_OPENGLES; aEGLLibName: String = LIBNAME_EGL): Boolean;

function CreateRenderingContext(const aDisplayType: EGLNativeDisplayType;
                                const aWindowType: PEGLNativeWindowType;
                                const aConfigAttribs: PEGLint;
                                const aContextAttribs: PEGLint): TdglRenderContext;
procedure DestroyRenderingContext(const aContext: TdglRenderContext);
function ActivateRenderingContext(const aContext: TdglRenderContext; const aFlags: TActivationFlags = [afReadOpenGLCore, afReadExtensions, afReadCoreVersion, afReadImplProp]): Boolean;
function DeactivateRenderingContext(const aContext: TdglRenderContext): Boolean;
procedure SwapBuffers(const aContext: TdglRenderContext);

procedure ReadOpenGLCore;
procedure ReadExtensions;
procedure ReadCoreVersion;
procedure ReadImplementationProperties;

{$IFDEF OPENGLES_EXTENSIONS}
procedure Read_GL_KHR_blend_equation_advanced;
procedure Read_GL_KHR_debug;
procedure Read_GL_KHR_robustness;
procedure Read_GL_OES_EGL_image;
procedure Read_GL_OES_get_program_binary;
procedure Read_GL_OES_mapbuffer;
procedure Read_GL_OES_sample_shading;
procedure Read_GL_OES_texture_3D;
procedure Read_GL_OES_texture_storage_multisample_2d_array;
procedure Read_GL_OES_vertex_array_object;
procedure Read_GL_AMD_performance_monitor;
procedure Read_GL_ANGLE_framebuffer_blit;
procedure Read_GL_ANGLE_framebuffer_multisample;
procedure Read_GL_ANGLE_instanced_arrays;
procedure Read_GL_ANGLE_translated_shader_source;
procedure Read_GL_APPLE_copy_texture_levels;
procedure Read_GL_APPLE_framebuffer_multisample;
procedure Read_GL_APPLE_sync;
procedure Read_GL_EXT_base_instance;
procedure Read_GL_EXT_copy_image;
procedure Read_GL_EXT_debug_label;
procedure Read_GL_EXT_debug_marker;
procedure Read_GL_EXT_discard_framebuffer;
procedure Read_GL_EXT_disjoint_timer_query;
procedure Read_GL_EXT_draw_buffers;
procedure Read_GL_EXT_draw_buffers_indexed;
procedure Read_GL_EXT_draw_elements_base_vertex;
procedure Read_GL_EXT_draw_instanced;
procedure Read_GL_EXT_geometry_shader;
procedure Read_GL_EXT_instanced_arrays;
procedure Read_GL_EXT_map_buffer_range;
procedure Read_GL_EXT_multi_draw_arrays;
procedure Read_GL_EXT_multi_draw_indirect;
procedure Read_GL_EXT_multisampled_render_to_texture;
procedure Read_GL_EXT_multiview_draw_buffers;
procedure Read_GL_EXT_primitive_bounding_box;
procedure Read_GL_EXT_robustness;
procedure Read_GL_EXT_separate_shader_objects;
procedure Read_GL_EXT_tessellation_shader;
procedure Read_GL_EXT_texture_border_clamp;
procedure Read_GL_EXT_texture_buffer;
procedure Read_GL_EXT_texture_storage;
procedure Read_GL_EXT_texture_view;
procedure Read_GL_IMG_multisampled_render_to_texture;
procedure Read_GL_INTEL_performance_query;
procedure Read_GL_NV_bindless_texture;
procedure Read_GL_NV_blend_equation_advanced;
procedure Read_GL_NV_conditional_render;
procedure Read_GL_NV_copy_buffer;
procedure Read_GL_NV_coverage_sample;
procedure Read_GL_NV_draw_buffers;
procedure Read_GL_NV_draw_instanced;
procedure Read_GL_NV_fence;
procedure Read_GL_NV_framebuffer_blit;
procedure Read_GL_NV_framebuffer_multisample;
procedure Read_GL_NV_instanced_arrays;
procedure Read_GL_NV_internalformat_sample_query;
procedure Read_GL_NV_non_square_matrices;
procedure Read_GL_NV_path_rendering;
procedure Read_GL_NV_read_buffer;
procedure Read_GL_NV_viewport_array;
procedure Read_GL_QCOM_alpha_test;
procedure Read_GL_QCOM_driver_control;
procedure Read_GL_QCOM_extended_get;
procedure Read_GL_QCOM_extended_get2;
procedure Read_GL_QCOM_tiled_rendering;
{$ENDIF}

implementation

var
  LibHandleOpenGLES: Pointer = nil;
  LibHandleEGL:      Pointer = nil;

procedure SetExternalProcAddressResolver(aResolver: TdglExternalProcAddress);
begin
  dglExternalGetProcAddress := aResolver;
end;

function dglLoadLibrary(const name: PChar): Pointer;
begin
  result := nil;
  {$IFDEF DGL_LINUX}
  result := dlopen(name, RTLD_LAZY);
  {$ENDIF}
  {$IFDEF ANDROID}
  result := dlopen(name, RTLD_LAZY);
  {$ENDIF}
  {$IFDEF DGL_WINDOWS}
  result := Pointer(LoadLibrary(PChar(name)));
  {$ENDIF}
end;

function dglGetProcAddress(const aProcName: PAnsiChar): Pointer;
begin
  result := nil;

  if Assigned(dglExternalGetProcAddress) then
    result := dglExternalGetProcAddress(aProcName);
  if Assigned(result) then exit;

  {$IF DEFINED(DGL_LINUX) OR DEFINED(ANDROID)}
  if Assigned(LibHandleOpenGLES) then
    result := dlsym(LibHandleOpenGLES, aProcName);

  if not Assigned(result) and Assigned(eglGetProcAddress) then
    result := eglGetProcAddress(aProcName);

  if not Assigned(result) and Assigned(LibHandleEGL) then
    result := dlsym(LibHandleEGL, aProcName);
  {$ENDIF}

  {$IFDEF DGL_WINDOWS}
  if Assigned(LibHandleOpenGLES) then
    result := GetProcAddress(HMODULE(LibHandleOpenGLES), aProcName);

  if not Assigned(result) and Assigned(eglGetProcAddress) then
    result := eglGetProcAddress(aProcName);

  if not Assigned(result) and Assigned(LibHandleEGL) then
    result := GetProcAddress(HMODULE(LibHandleEGL), aProcName);
  {$ENDIF}
end;

function dglFreeAndNilLibrary(var aLibHandle: Pointer): Boolean;
begin
  if Assigned(aLibHandle) then begin
    {$IF DEFINED(DGL_LINUX) OR DEFINED(ANDROID)}
    result := (dlclose(aLibHandle) = 0);
    {$ENDIF}
    {$IFDEF DGL_WINDOWS}
    result := FreeLibrary(HMODULE(aLibHandle));
    {$ENDIF}
    aLibHandle := nil;
  end else
    result := false;
end;

function InitOpenGLES(const aOpenGLESLibName: String; aEGLLibName: String): Boolean;
begin
  result := true;

  if Assigned(LibHandleOpenGLES) then
    dglFreeAndNilLibrary(LibHandleOpenGLES);

  if Assigned(LibHandleEGL) then
    dglFreeAndNilLibrary(LibHandleEGL);

  LibHandleOpenGLES := dglLoadLibrary(PChar(aOpenGLESLibName));
  {$IFDEF ANDROID}
  if not Assigned(LibHandleOpenGLES) then
    // ES 3.0 driver may only expose libGLESv2.so; ES 3.x entry points are still available through it
    LibHandleOpenGLES := dglLoadLibrary(PChar(LIBNAME_OPENGLES_FALLBACK));
  {$ENDIF}
  LibHandleEGL      := dglLoadLibrary(PChar(aEGLLibName));

  // load EGL procedures
  if Assigned(LibHandleEGL) then begin
    eglGetProcAddress                 := dglGetProcAddress('eglGetProcAddress');
    eglGetError                       := dglGetProcAddress('eglGetError');
    eglGetDisplay                     := dglGetProcAddress('eglGetDisplay');
    eglInitialize                     := dglGetProcAddress('eglInitialize');
    eglTerminate                      := dglGetProcAddress('eglTerminate');
    eglQueryString                    := dglGetProcAddress('eglQueryString');
    eglGetConfigs                     := dglGetProcAddress('eglGetConfigs');
    eglChooseConfig                   := dglGetProcAddress('eglChooseConfig');
    eglGetConfigAttrib                := dglGetProcAddress('eglGetConfigAttrib');
    eglCreateWindowSurface            := dglGetProcAddress('eglCreateWindowSurface');
    eglCreatePbufferSurface           := dglGetProcAddress('eglCreatePbufferSurface');
    eglCreatePixmapSurface            := dglGetProcAddress('eglCreatePixmapSurface');
    eglDestroySurface                 := dglGetProcAddress('eglDestroySurface');
    eglQuerySurface                   := dglGetProcAddress('eglQuerySurface');
    eglBindAPI                        := dglGetProcAddress('eglBindAPI');
    eglQueryAPI                       := dglGetProcAddress('eglQueryAPI');
    eglWaitClient                     := dglGetProcAddress('eglWaitClient');
    eglReleaseThread                  := dglGetProcAddress('eglReleaseThread');
    eglCreatePbufferFromClientBuffer  := dglGetProcAddress('eglCreatePbufferFromClientBuffer');
    eglSurfaceAttrib                  := dglGetProcAddress('eglSurfaceAttrib');
    eglBindTexImage                   := dglGetProcAddress('eglBindTexImage');
    eglReleaseTexImage                := dglGetProcAddress('eglReleaseTexImage');
    eglSwapInterval                   := dglGetProcAddress('eglSwapInterval');
    eglCreateContext                  := dglGetProcAddress('eglCreateContext');
    eglDestroyContext                 := dglGetProcAddress('eglDestroyContext');
    eglMakeCurrent                    := dglGetProcAddress('eglMakeCurrent');
    eglGetCurrentContext              := dglGetProcAddress('eglGetCurrentContext');
    eglGetCurrentSurface              := dglGetProcAddress('eglGetCurrentSurface');
    eglGetCurrentDisplay              := dglGetProcAddress('eglGetCurrentDisplay');
    eglQueryContext                   := dglGetProcAddress('eglQueryContext');
    eglWaitGL                         := dglGetProcAddress('eglWaitGL');
    eglWaitNative                     := dglGetProcAddress('eglWaitNative');
    eglSwapBuffers                    := dglGetProcAddress('eglSwapBuffers');
    eglCopyBuffers                    := dglGetProcAddress('eglCopyBuffers');
  end else
    result := false;
end;

procedure RaiseEglError(const aMsg: String);
var err: EGLint;
begin
  err := eglGetError();
  raise EeglError.Create(aMsg + ' ErrorCode: 0x' + IntToHex(err, 8), err);
end;

function CreateRenderingContext(const aDisplayType: EGLNativeDisplayType; const aWindowType: PEGLNativeWindowType;
  const aConfigAttribs: PEGLint; const aContextAttribs: PEGLint): TdglRenderContext;
var
  ConfigCount: EGLint;
  Config: EGLConfig;
begin
  if (not Assigned(LibHandleOpenGLES) or not Assigned(LibHandleEGL)) and
     not InitOpenGLES then
      raise EdglOpenGLES.Create('unable to initialize OpenGL library');

  result.Display := eglGetDisplay(aDisplayType);
  if (result.Display = EGL_NO_DISPLAY) then
    RaiseEglError('unable to get display.');

  if (eglInitialize(result.Display, nil, nil) <> EGL_TRUE) then
    RaiseEglError('unable to initialize egl.');

  if (eglChooseConfig(result.Display, aConfigAttribs, @Config, 1, @ConfigCount) <> EGL_TRUE) or
     (ConfigCount < 1) then
    RaiseEglError('unable to get suitable config.');

  if (eglBindAPI(EGL_OPENGL_ES_API) <> EGL_TRUE) then
    RaiseEglError('unable to get an appropriate EGL frame buffer configuration.');

  result.Surface := eglCreateWindowSurface(result.Display, Config, aWindowType, nil);
  if (result.Surface = EGL_NO_SURFACE) then
    RaiseEglError('unable to create window surface.');

  result.Context := eglCreateContext(result.Display, Config, EGL_NO_CONTEXT, aContextAttribs);
  if (result.Context = EGL_NO_CONTEXT) then begin
    eglDestroySurface(result.Display, result.Surface);
    RaiseEglError('unable to create context.');
  end;
end;

procedure DestroyRenderingContext(const aContext: TdglRenderContext);
begin
  if (eglGetCurrentContext = aContext.Context) and
     not DeactivateRenderingContext(aContext) then
    RaiseEglError('unable to unbind context.');

  if (eglDestroyContext(aContext.Display, aContext.Context) <> EGL_TRUE) then
    RaiseEglError('unable to destory context.');

  if (eglDestroySurface(aContext.Display, aContext.Surface) <> EGL_TRUE) then
    RaiseEglError('unable to destroy surface.');
end;

function ActivateRenderingContext(const aContext: TdglRenderContext; const aFlags: TActivationFlags): Boolean;
begin
  result := (eglMakeCurrent(aContext.Display, aContext.Surface, aContext.Surface, aContext.Context) = GL_TRUE);
  if (afReadOpenGLCore in aFlags) then
    ReadOpenGLCore;
  if (afReadExtensions in aFlags) then
    ReadExtensions;
  if (afReadCoreVersion in aFlags) then
    ReadCoreVersion;
  if (afReadImplProp in aFlags) then
    ReadImplementationProperties;
end;

function DeactivateRenderingContext(const aContext: TdglRenderContext): Boolean;
begin
  result := (eglMakeCurrent(aContext.Display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT) = EGL_TRUE);
end;

procedure SwapBuffers(const aContext: TdglRenderContext);
begin
  eglSwapBuffers(aContext.Display, aContext.Surface);
end;

procedure ReadOpenGLCore;
begin
{$IFDEF OPENGLES_CORE_1_1}
  { ============================================= OpenGL ES 1.1 ====================================================== }
  { Available only in Common profile }
  glAlphaFunc                              := dglGetProcAddress('glAlphaFunc');
  glClearColor                             := dglGetProcAddress('glClearColor');
  glClearDepthf                            := dglGetProcAddress('glClearDepthf');
  glClipPlanef                             := dglGetProcAddress('glClipPlanef');
  glColor4f                                := dglGetProcAddress('glColor4f');
  glDepthRangef                            := dglGetProcAddress('glDepthRangef');
  glFogf                                   := dglGetProcAddress('glFogf');
  glFogfv                                  := dglGetProcAddress('glFogfv');
  glFrustumf                               := dglGetProcAddress('glFrustumf');
  glGetClipPlanef                          := dglGetProcAddress('glGetClipPlanef');
  glGetFloatv                              := dglGetProcAddress('glGetFloatv');
  glGetLightfv                             := dglGetProcAddress('glGetLightfv');
  glGetMaterialfv                          := dglGetProcAddress('glGetMaterialfv');
  glGetTexEnvfv                            := dglGetProcAddress('glGetTexEnvfv');
  glGetTexParameterfv                      := dglGetProcAddress('glGetTexParameterfv');
  glLightModelf                            := dglGetProcAddress('glLightModelf');
  glLightModelfv                           := dglGetProcAddress('glLightModelfv');
  glLightf                                 := dglGetProcAddress('glLightf');
  glLightfv                                := dglGetProcAddress('glLightfv');
  glLineWidth                              := dglGetProcAddress('glLineWidth');
  glLoadMatrixf                            := dglGetProcAddress('glLoadMatrixf');
  glMaterialf                              := dglGetProcAddress('glMaterialf');
  glMaterialfv                             := dglGetProcAddress('glMaterialfv');
  glMultMatrixf                            := dglGetProcAddress('glMultMatrixf');
  glMultiTexCoord4f                        := dglGetProcAddress('glMultiTexCoord4f');
  glNormal3f                               := dglGetProcAddress('glNormal3f');
  glOrthof                                 := dglGetProcAddress('glOrthof');
  glPointParameterf                        := dglGetProcAddress('glPointParameterf');
  glPointParameterfv                       := dglGetProcAddress('glPointParameterfv');
  glPointSize                              := dglGetProcAddress('glPointSize');
  glPolygonOffset                          := dglGetProcAddress('glPolygonOffset');
  glRotatef                                := dglGetProcAddress('glRotatef');
  glScalef                                 := dglGetProcAddress('glScalef');
  glTexEnvf                                := dglGetProcAddress('glTexEnvf');
  glTexEnvfv                               := dglGetProcAddress('glTexEnvfv');
  glTexParameterf                          := dglGetProcAddress('glTexParameterf');
  glTexParameterfv                         := dglGetProcAddress('glTexParameterfv');
  glTranslatef                             := dglGetProcAddress('glTranslatef');

  { Available in both Common and Common-Lite profiles }
  glActiveTexture                          := dglGetProcAddress('glActiveTexture');
  glAlphaFuncx                             := dglGetProcAddress('glAlphaFuncx');
  glBindBuffer                             := dglGetProcAddress('glBindBuffer');
  glBindTexture                            := dglGetProcAddress('glBindTexture');
  glBlendFunc                              := dglGetProcAddress('glBlendFunc');
  glBufferData                             := dglGetProcAddress('glBufferData');
  glBufferSubData                          := dglGetProcAddress('glBufferSubData');
  glClear                                  := dglGetProcAddress('glClear');
  glClearColorx                            := dglGetProcAddress('glClearColorx');
  glClearDepthx                            := dglGetProcAddress('glClearDepthx');
  glClearStencil                           := dglGetProcAddress('glClearStencil');
  glClientActiveTexture                    := dglGetProcAddress('glClientActiveTexture');
  glClipPlanex                             := dglGetProcAddress('glClipPlanex');
  glColor4ub                               := dglGetProcAddress('glColor4ub');
  glColor4x                                := dglGetProcAddress('glColor4x');
  glColorMask                              := dglGetProcAddress('glColorMask');
  glColorPointer                           := dglGetProcAddress('glColorPointer');
  glCompressedTexImage2D                   := dglGetProcAddress('glCompressedTexImage2D');
  glCompressedTexSubImage2D                := dglGetProcAddress('glCompressedTexSubImage2D');
  glCopyTexImage2D                         := dglGetProcAddress('glCopyTexImage2D');
  glCopyTexSubImage2D                      := dglGetProcAddress('glCopyTexSubImage2D');
  glCullFace                               := dglGetProcAddress('glCullFace');
  glDeleteBuffers                          := dglGetProcAddress('glDeleteBuffers');
  glDeleteTextures                         := dglGetProcAddress('glDeleteTextures');
  glDepthFunc                              := dglGetProcAddress('glDepthFunc');
  glDepthMask                              := dglGetProcAddress('glDepthMask');
  glDepthRangex                            := dglGetProcAddress('glDepthRangex');
  glDisable                                := dglGetProcAddress('glDisable');
  glDisableClientState                     := dglGetProcAddress('glDisableClientState');
  glDrawArrays                             := dglGetProcAddress('glDrawArrays');
  glDrawElements                           := dglGetProcAddress('glDrawElements');
  glEnable                                 := dglGetProcAddress('glEnable');
  glEnableClientState                      := dglGetProcAddress('glEnableClientState');
  glFinish                                 := dglGetProcAddress('glFinish');
  glFlush                                  := dglGetProcAddress('glFlush');
  glFogx                                   := dglGetProcAddress('glFogx');
  glFogxv                                  := dglGetProcAddress('glFogxv');
  glFrontFace                              := dglGetProcAddress('glFrontFace');
  glFrustumx                               := dglGetProcAddress('glFrustumx');
  glGetBooleanv                            := dglGetProcAddress('glGetBooleanv');
  glGetBufferParameteriv                   := dglGetProcAddress('glGetBufferParameteriv');
  glGetClipPlanex                          := dglGetProcAddress('glGetClipPlanex');
  glGenBuffers                             := dglGetProcAddress('glGenBuffers');
  glGenTextures                            := dglGetProcAddress('glGenTextures');
  glGetError                               := dglGetProcAddress('glGetError');
  glGetFixedv                              := dglGetProcAddress('glGetFixedv');
  glGetIntegerv                            := dglGetProcAddress('glGetIntegerv');
  glGetLightxv                             := dglGetProcAddress('glGetLightxv');
  glGetMaterialxv                          := dglGetProcAddress('glGetMaterialxv');
  glGetPointerv                            := dglGetProcAddress('glGetPointerv');
  glGetString                              := dglGetProcAddress('glGetString');
  glGetTexEnviv                            := dglGetProcAddress('glGetTexEnviv');
  glGetTexEnvxv                            := dglGetProcAddress('glGetTexEnvxv');
  glGetTexParameteriv                      := dglGetProcAddress('glGetTexParameteriv');
  glGetTexParameterxv                      := dglGetProcAddress('glGetTexParameterxv');
  glHint                                   := dglGetProcAddress('glHint');
  glIsBuffer                               := dglGetProcAddress('glIsBuffer');
  glIsEnabled                              := dglGetProcAddress('glIsEnabled');
  glIsTexture                              := dglGetProcAddress('glIsTexture');
  glLightModelx                            := dglGetProcAddress('glLightModelx');
  glLightModelxv                           := dglGetProcAddress('glLightModelxv');
  glLightx                                 := dglGetProcAddress('glLightx');
  glLightxv                                := dglGetProcAddress('glLightxv');
  glLineWidthx                             := dglGetProcAddress('glLineWidthx');
  glLoadIdentity                           := dglGetProcAddress('glLoadIdentity');
  glLoadMatrix                             := dglGetProcAddress('glLoadMatrix');
  glLogicOp                                := dglGetProcAddress('glLogicOp');
  glMaterialx                              := dglGetProcAddress('glMaterialx');
  glMaterialxv                             := dglGetProcAddress('glMaterialxv');
  glMatrixMode                             := dglGetProcAddress('glMatrixMode');
  glMultMatrixx                            := dglGetProcAddress('glMultMatrixx');
  glMultiTexCoord4x                        := dglGetProcAddress('glMultiTexCoord4x');
  glNormal3x                               := dglGetProcAddress('glNormal3x');
  glNormalPointer                          := dglGetProcAddress('glNormalPointer');
  glOrthox                                 := dglGetProcAddress('glOrthox');
  glPixelStorei                            := dglGetProcAddress('glPixelStorei');
  glPointParameterx                        := dglGetProcAddress('glPointParameterx');
  glPointParameterxv                       := dglGetProcAddress('glPointParameterxv');
  glPointSizex                             := dglGetProcAddress('glPointSizex');
  glPolygonOffsetx                         := dglGetProcAddress('glPolygonOffsetx');
  glPopMatrix                              := dglGetProcAddress('glPopMatrix');
  glPushMatrix                             := dglGetProcAddress('glPushMatrix');
  glReadPixels                             := dglGetProcAddress('glReadPixels');
  glRotatex                                := dglGetProcAddress('glRotatex');
  glSampleCoverage                         := dglGetProcAddress('glSampleCoverage');
  glSampleCoveragex                        := dglGetProcAddress('glSampleCoveragex');
  glScalex                                 := dglGetProcAddress('glScalex');
  glScissor                                := dglGetProcAddress('glScissor');
  glShadeModel                             := dglGetProcAddress('glShadeModel');
  glStencilFunc                            := dglGetProcAddress('glStencilFunc');
  glStencilMask                            := dglGetProcAddress('glStencilMask');
  glStencilOp                              := dglGetProcAddress('glStencilOp');
  glTexCoordPointer                        := dglGetProcAddress('glTexCoordPointer');
  glTexEnvi                                := dglGetProcAddress('glTexEnvi');
  glTexEnvx                                := dglGetProcAddress('glTexEnvx');
  glTexEnviv                               := dglGetProcAddress('glTexEnviv');
  glTexEnvxv                               := dglGetProcAddress('glTexEnvxv');
  glTexImage2D                             := dglGetProcAddress('glTexImage2D');
  glTexParameteri                          := dglGetProcAddress('glTexParameteri');
  glTexParameterx                          := dglGetProcAddress('glTexParameterx');
  glTexParameteriv                         := dglGetProcAddress('glTexParameteriv');
  glTexParameterxv                         := dglGetProcAddress('glTexParameterxv');
  glTexSubImage2D                          := dglGetProcAddress('glTexSubImage2D');
  glTranslatex                             := dglGetProcAddress('glTranslatex');
  glVertexPointer                          := dglGetProcAddress('glVertexPointer');
  glViewport                               := dglGetProcAddress('glViewport');
{$ENDIF}

{$IFDEF OPENGLES_CORE_2_0}
  { ============================================= OpenGL ES 2.0 ====================================================== }
  glAttachShader                           := dglGetProcAddress('glAttachShader');
  glBindAttribLocation                     := dglGetProcAddress('glBindAttribLocation');
  glBindFramebuffer                        := dglGetProcAddress('glBindFramebuffer');
  glBindRenderbuffer                       := dglGetProcAddress('glBindRenderbuffer');
  glBlendColor                             := dglGetProcAddress('glBlendColor');
  glBlendEquation                          := dglGetProcAddress('glBlendEquation');
  glBlendEquationSeparate                  := dglGetProcAddress('glBlendEquationSeparate');
  glBlendFuncSeparate                      := dglGetProcAddress('glBlendFuncSeparate');
  glCheckFramebufferStatus                 := dglGetProcAddress('glCheckFramebufferStatus');
  glCompileShader                          := dglGetProcAddress('glCompileShader');
  glCreateProgram                          := dglGetProcAddress('glCreateProgram');
  glCreateShader                           := dglGetProcAddress('glCreateShader');
  glDeleteFramebuffers                     := dglGetProcAddress('glDeleteFramebuffers');
  glDeleteProgram                          := dglGetProcAddress('glDeleteProgram');
  glDeleteRenderbuffers                    := dglGetProcAddress('glDeleteRenderbuffers');
  glDeleteShader                           := dglGetProcAddress('glDeleteShader');
  glDetachShader                           := dglGetProcAddress('glDetachShader');
  glDisableVertexAttribArray               := dglGetProcAddress('glDisableVertexAttribArray');
  glEnableVertexAttribArray                := dglGetProcAddress('glEnableVertexAttribArray');
  glFramebufferRenderbuffer                := dglGetProcAddress('glFramebufferRenderbuffer');
  glFramebufferTexture2D                   := dglGetProcAddress('glFramebufferTexture2D');
  glGenerateMipmap                         := dglGetProcAddress('glGenerateMipmap');
  glGenFramebuffers                        := dglGetProcAddress('glGenFramebuffers');
  glGenRenderbuffers                       := dglGetProcAddress('glGenRenderbuffers');
  glGetActiveAttrib                        := dglGetProcAddress('glGetActiveAttrib');
  glGetActiveUniform                       := dglGetProcAddress('glGetActiveUniform');
  glGetAttachedShaders                     := dglGetProcAddress('glGetAttachedShaders');
  glGetAttribLocation                      := dglGetProcAddress('glGetAttribLocation');
  glGetFramebufferAttachmentParameteriv    := dglGetProcAddress('glGetFramebufferAttachmentParameteriv');
  glGetProgramiv                           := dglGetProcAddress('glGetProgramiv');
  glGetProgramInfoLog                      := dglGetProcAddress('glGetProgramInfoLog');
  glGetRenderbufferParameteriv             := dglGetProcAddress('glGetRenderbufferParameteriv');
  glGetShaderiv                            := dglGetProcAddress('glGetShaderiv');
  glGetShaderInfoLog                       := dglGetProcAddress('glGetShaderInfoLog');
  glGetShaderPrecisionFormat               := dglGetProcAddress('glGetShaderPrecisionFormat');
  glGetShaderSource                        := dglGetProcAddress('glGetShaderSource');
  glGetUniformfv                           := dglGetProcAddress('glGetUniformfv');
  glGetUniformiv                           := dglGetProcAddress('glGetUniformiv');
  glGetUniformLocation                     := dglGetProcAddress('glGetUniformLocation');
  glGetVertexAttribfv                      := dglGetProcAddress('glGetVertexAttribfv');
  glGetVertexAttribiv                      := dglGetProcAddress('glGetVertexAttribiv');
  glGetVertexAttribPointerv                := dglGetProcAddress('glGetVertexAttribPointerv');
  glIsFramebuffer                          := dglGetProcAddress('glIsFramebuffer');
  glIsProgram                              := dglGetProcAddress('glIsProgram');
  glIsRenderbuffer                         := dglGetProcAddress('glIsRenderbuffer');
  glIsShader                               := dglGetProcAddress('glIsShader');
  glLinkProgram                            := dglGetProcAddress('glLinkProgram');
  glReleaseShaderCompiler                  := dglGetProcAddress('glReleaseShaderCompiler');
  glRenderbufferStorage                    := dglGetProcAddress('glRenderbufferStorage');
  glShaderBinary                           := dglGetProcAddress('glShaderBinary');
  glShaderSource                           := dglGetProcAddress('glShaderSource');
  glStencilFuncSeparate                    := dglGetProcAddress('glStencilFuncSeparate');
  glStencilMaskSeparate                    := dglGetProcAddress('glStencilMaskSeparate');
  glStencilOpSeparate                      := dglGetProcAddress('glStencilOpSeparate');
  glUniform1f                              := dglGetProcAddress('glUniform1f');
  glUniform1fv                             := dglGetProcAddress('glUniform1fv');
  glUniform1i                              := dglGetProcAddress('glUniform1i');
  glUniform1iv                             := dglGetProcAddress('glUniform1iv');
  glUniform2f                              := dglGetProcAddress('glUniform2f');
  glUniform2fv                             := dglGetProcAddress('glUniform2fv');
  glUniform2i                              := dglGetProcAddress('glUniform2i');
  glUniform2iv                             := dglGetProcAddress('glUniform2iv');
  glUniform3f                              := dglGetProcAddress('glUniform3f');
  glUniform3fv                             := dglGetProcAddress('glUniform3fv');
  glUniform3i                              := dglGetProcAddress('glUniform3i');
  glUniform3iv                             := dglGetProcAddress('glUniform3iv');
  glUniform4f                              := dglGetProcAddress('glUniform4f');
  glUniform4fv                             := dglGetProcAddress('glUniform4fv');
  glUniform4i                              := dglGetProcAddress('glUniform4i');
  glUniform4iv                             := dglGetProcAddress('glUniform4iv');
  glUniformMatrix2fv                       := dglGetProcAddress('glUniformMatrix2fv');
  glUniformMatrix3fv                       := dglGetProcAddress('glUniformMatrix3fv');
  glUniformMatrix4fv                       := dglGetProcAddress('glUniformMatrix4fv');
  glUseProgram                             := dglGetProcAddress('glUseProgram');
  glValidateProgram                        := dglGetProcAddress('glValidateProgram');
  glVertexAttrib1f                         := dglGetProcAddress('glVertexAttrib1f');
  glVertexAttrib1fv                        := dglGetProcAddress('glVertexAttrib1fv');
  glVertexAttrib2f                         := dglGetProcAddress('glVertexAttrib2f');
  glVertexAttrib2fv                        := dglGetProcAddress('glVertexAttrib2fv');
  glVertexAttrib3f                         := dglGetProcAddress('glVertexAttrib3f');
  glVertexAttrib3fv                        := dglGetProcAddress('glVertexAttrib3fv');
  glVertexAttrib4f                         := dglGetProcAddress('glVertexAttrib4f');
  glVertexAttrib4fv                        := dglGetProcAddress('glVertexAttrib4fv');
  glVertexAttribPointer                    := dglGetProcAddress('glVertexAttribPointer');
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_0}
  { ============================================= OpenGL ES 3.0 ====================================================== }
  glReadBuffer                             := dglGetProcAddress('glReadBuffer');
  glDrawRangeElements                      := dglGetProcAddress('glDrawRangeElements');
  glTexImage3D                             := dglGetProcAddress('glTexImage3D');
  glTexSubImage3D                          := dglGetProcAddress('glTexSubImage3D');
  glCopyTexSubImage3D                      := dglGetProcAddress('glCopyTexSubImage3D');
  glCompressedTexImage3D                   := dglGetProcAddress('glCompressedTexImage3D');
  glCompressedTexSubImage3D                := dglGetProcAddress('glCompressedTexSubImage3D');
  glGenQueries                             := dglGetProcAddress('glGenQueries');
  glDeleteQueries                          := dglGetProcAddress('glDeleteQueries');
  glIsQuery                                := dglGetProcAddress('glIsQuery');
  glBeginQuery                             := dglGetProcAddress('glBeginQuery');
  glEndQuery                               := dglGetProcAddress('glEndQuery');
  glGetQueryiv                             := dglGetProcAddress('glGetQueryiv');
  glGetQueryObjectuiv                      := dglGetProcAddress('glGetQueryObjectuiv');
  glUnmapBuffer                            := dglGetProcAddress('glUnmapBuffer');
  glGetBufferPointerv                      := dglGetProcAddress('glGetBufferPointerv');
  glDrawBuffers                            := dglGetProcAddress('glDrawBuffers');
  glUniformMatrix2x3fv                     := dglGetProcAddress('glUniformMatrix2x3fv');
  glUniformMatrix3x2fv                     := dglGetProcAddress('glUniformMatrix3x2fv');
  glUniformMatrix2x4fv                     := dglGetProcAddress('glUniformMatrix2x4fv');
  glUniformMatrix4x2fv                     := dglGetProcAddress('glUniformMatrix4x2fv');
  glUniformMatrix3x4fv                     := dglGetProcAddress('glUniformMatrix3x4fv');
  glUniformMatrix4x3fv                     := dglGetProcAddress('glUniformMatrix4x3fv');
  glBlitFramebuffer                        := dglGetProcAddress('glBlitFramebuffer');
  glRenderbufferStorageMultisample         := dglGetProcAddress('glRenderbufferStorageMultisample');
  glFramebufferTextureLayer                := dglGetProcAddress('glFramebufferTextureLayer');
  glMapBufferRange                         := dglGetProcAddress('glMapBufferRange');
  glFlushMappedBufferRange                 := dglGetProcAddress('glFlushMappedBufferRange');
  glBindVertexArray                        := dglGetProcAddress('glBindVertexArray');
  glDeleteVertexArrays                     := dglGetProcAddress('glDeleteVertexArrays');
  glGenVertexArrays                        := dglGetProcAddress('glGenVertexArrays');
  glIsVertexArray                          := dglGetProcAddress('glIsVertexArray');
  glGetIntegeriv                           := dglGetProcAddress('glGetIntegeriv');
  glBeginTransformFeedback                 := dglGetProcAddress('glBeginTransformFeedback');
  glEndTransformFeedback                   := dglGetProcAddress('glEndTransformFeedback');
  glBindBufferRange                        := dglGetProcAddress('glBindBufferRange');
  glBindBufferBase                         := dglGetProcAddress('glBindBufferBase');
  glTransformFeedbackVaryings              := dglGetProcAddress('glTransformFeedbackVaryings');
  glGetTransformFeedbackVarying            := dglGetProcAddress('glGetTransformFeedbackVarying');
  glVertexAttribIPointer                   := dglGetProcAddress('glVertexAttribIPointer');
  glGetVertexAttribIiv                     := dglGetProcAddress('glGetVertexAttribIiv');
  glGetVertexAttribIuiv                    := dglGetProcAddress('glGetVertexAttribIuiv');
  glVertexAttribI4i                        := dglGetProcAddress('glVertexAttribI4i');
  glVertexAttribI4ui                       := dglGetProcAddress('glVertexAttribI4ui');
  glVertexAttribI4iv                       := dglGetProcAddress('glVertexAttribI4iv');
  glVertexAttribI4uiv                      := dglGetProcAddress('glVertexAttribI4uiv');
  glGetUniformuiv                          := dglGetProcAddress('glGetUniformuiv');
  glGetFragDataLocation                    := dglGetProcAddress('glGetFragDataLocation');
  glUniform1ui                             := dglGetProcAddress('glUniform1ui');
  glUniform2ui                             := dglGetProcAddress('glUniform2ui');
  glUniform3ui                             := dglGetProcAddress('glUniform3ui');
  glUniform4ui                             := dglGetProcAddress('glUniform4ui');
  glUniform1uiv                            := dglGetProcAddress('glUniform1uiv');
  glUniform2uiv                            := dglGetProcAddress('glUniform2uiv');
  glUniform3uiv                            := dglGetProcAddress('glUniform3uiv');
  glUniform4uiv                            := dglGetProcAddress('glUniform4uiv');
  glClearBufferiv                          := dglGetProcAddress('glClearBufferiv');
  glClearBufferuiv                         := dglGetProcAddress('glClearBufferuiv');
  glClearBufferfv                          := dglGetProcAddress('glClearBufferfv');
  glClearBufferfi                          := dglGetProcAddress('glClearBufferfi');
  glGetStringi                             := dglGetProcAddress('glGetStringi');
  glCopyBufferSubData                      := dglGetProcAddress('glCopyBufferSubData');
  glGetUniformIndices                      := dglGetProcAddress('glGetUniformIndices');
  glGetActiveUniformsiv                    := dglGetProcAddress('glGetActiveUniformsiv');
  glGetUniformBlockIndex                   := dglGetProcAddress('glGetUniformBlockIndex');
  glGetActiveUniformBlockiv                := dglGetProcAddress('glGetActiveUniformBlockiv');
  glGetActiveUniformBlockName              := dglGetProcAddress('glGetActiveUniformBlockName');
  glUniformBlockBinding                    := dglGetProcAddress('glUniformBlockBinding');
  glDrawArraysInstanced                    := dglGetProcAddress('glDrawArraysInstanced');
  glDrawElementsInstanced                  := dglGetProcAddress('glDrawElementsInstanced');
  glFenceSync                              := dglGetProcAddress('glFenceSync');
  glIsSync                                 := dglGetProcAddress('glIsSync');
  glDeleteSync                             := dglGetProcAddress('glDeleteSync');
  glClientWaitSync                         := dglGetProcAddress('glClientWaitSync');
  glWaitSync                               := dglGetProcAddress('glWaitSync');
  glGetInteger64v                          := dglGetProcAddress('glGetInteger64v');
  glGetSynciv                              := dglGetProcAddress('glGetSynciv');
  glGetInteger64iv                         := dglGetProcAddress('glGetInteger64iv');
  glGetBufferParameteri64v                 := dglGetProcAddress('glGetBufferParameteri64v');
  glGenSamplers                            := dglGetProcAddress('glGenSamplers');
  glDeleteSamplers                         := dglGetProcAddress('glDeleteSamplers');
  glIsSampler                              := dglGetProcAddress('glIsSampler');
  glBindSampler                            := dglGetProcAddress('glBindSampler');
  glSamplerParameteri                      := dglGetProcAddress('glSamplerParameteri');
  glSamplerParameteriv                     := dglGetProcAddress('glSamplerParameteriv');
  glSamplerParameterf                      := dglGetProcAddress('glSamplerParameterf');
  glSamplerParameterfv                     := dglGetProcAddress('glSamplerParameterfv');
  glGetSamplerParameteriv                  := dglGetProcAddress('glGetSamplerParameteriv');
  glGetSamplerParameterfv                  := dglGetProcAddress('glGetSamplerParameterfv');
  glVertexAttribDivisor                    := dglGetProcAddress('glVertexAttribDivisor');
  glBindTransformFeedback                  := dglGetProcAddress('glBindTransformFeedback');
  glDeleteTransformFeedbacks               := dglGetProcAddress('glDeleteTransformFeedbacks');
  glGenTransformFeedbacks                  := dglGetProcAddress('glGenTransformFeedbacks');
  glIsTransformFeedback                    := dglGetProcAddress('glIsTransformFeedback');
  glPauseTransformFeedback                 := dglGetProcAddress('glPauseTransformFeedback');
  glResumeTransformFeedback                := dglGetProcAddress('glResumeTransformFeedback');
  glGetProgramBinary                       := dglGetProcAddress('glGetProgramBinary');
  glProgramBinary                          := dglGetProcAddress('glProgramBinary');
  glProgramParameteri                      := dglGetProcAddress('glProgramParameteri');
  glInvalidateFramebuffer                  := dglGetProcAddress('glInvalidateFramebuffer');
  glInvalidateSubFramebuffer               := dglGetProcAddress('glInvalidateSubFramebuffer');
  glTexStorage2D                           := dglGetProcAddress('glTexStorage2D');
  glTexStorage3D                           := dglGetProcAddress('glTexStorage3D');
  glGetInternalformativ                    := dglGetProcAddress('glGetInternalformativ');
{$ENDIF}

{$IFDEF OPENGLES_CORE_3_1}
  { ============================================= OpenGL ES 3.1 ====================================================== }
  glDispatchCompute                        := dglGetProcAddress('glDispatchCompute');
  glDispatchComputeIndirect                := dglGetProcAddress('glDispatchComputeIndirect');
  glDrawArraysIndirect                     := dglGetProcAddress('glDrawArraysIndirect');
  glDrawElementsIndirect                   := dglGetProcAddress('glDrawElementsIndirect');
  glFramebufferParameteri                  := dglGetProcAddress('glFramebufferParameteri');
  glGetFramebufferParameteriv              := dglGetProcAddress('glGetFramebufferParameteriv');
  glGetProgramInterfaceiv                  := dglGetProcAddress('glGetProgramInterfaceiv');
  glGetProgramResourceIndex                := dglGetProcAddress('glGetProgramResourceIndex');
  glGetProgramResourceName                 := dglGetProcAddress('glGetProgramResourceName');
  glGetProgramResourceiv                   := dglGetProcAddress('glGetProgramResourceiv');
  glGetProgramResourceLocation             := dglGetProcAddress('glGetProgramResourceLocation');
  glUseProgramStages                       := dglGetProcAddress('glUseProgramStages');
  glActiveShaderProgram                    := dglGetProcAddress('glActiveShaderProgram');
  glCreateShaderProgramv                   := dglGetProcAddress('glCreateShaderProgramv');
  glBindProgramPipeline                    := dglGetProcAddress('glBindProgramPipeline');
  glDeleteProgramPipelines                 := dglGetProcAddress('glDeleteProgramPipelines');
  glGenProgramPipelines                    := dglGetProcAddress('glGenProgramPipelines');
  glIsProgramPipeline                      := dglGetProcAddress('glIsProgramPipeline');
  glGetProgramPipelineiv                   := dglGetProcAddress('glGetProgramPipelineiv');
  glProgramUniform1i                       := dglGetProcAddress('glProgramUniform1i');
  glProgramUniform2i                       := dglGetProcAddress('glProgramUniform2i');
  glProgramUniform3i                       := dglGetProcAddress('glProgramUniform3i');
  glProgramUniform4i                       := dglGetProcAddress('glProgramUniform4i');
  glProgramUniform1ui                      := dglGetProcAddress('glProgramUniform1ui');
  glProgramUniform2ui                      := dglGetProcAddress('glProgramUniform2ui');
  glProgramUniform3ui                      := dglGetProcAddress('glProgramUniform3ui');
  glProgramUniform4ui                      := dglGetProcAddress('glProgramUniform4ui');
  glProgramUniform1f                       := dglGetProcAddress('glProgramUniform1f');
  glProgramUniform2f                       := dglGetProcAddress('glProgramUniform2f');
  glProgramUniform3f                       := dglGetProcAddress('glProgramUniform3f');
  glProgramUniform4f                       := dglGetProcAddress('glProgramUniform4f');
  glProgramUniform1iv                      := dglGetProcAddress('glProgramUniform1iv');
  glProgramUniform2iv                      := dglGetProcAddress('glProgramUniform2iv');
  glProgramUniform3iv                      := dglGetProcAddress('glProgramUniform3iv');
  glProgramUniform4iv                      := dglGetProcAddress('glProgramUniform4iv');
  glProgramUniform1uiv                     := dglGetProcAddress('glProgramUniform1uiv');
  glProgramUniform2uiv                     := dglGetProcAddress('glProgramUniform2uiv');
  glProgramUniform3uiv                     := dglGetProcAddress('glProgramUniform3uiv');
  glProgramUniform4uiv                     := dglGetProcAddress('glProgramUniform4uiv');
  glProgramUniform1fv                      := dglGetProcAddress('glProgramUniform1fv');
  glProgramUniform2fv                      := dglGetProcAddress('glProgramUniform2fv');
  glProgramUniform3fv                      := dglGetProcAddress('glProgramUniform3fv');
  glProgramUniform4fv                      := dglGetProcAddress('glProgramUniform4fv');
  glProgramUniformMatrix2fv                := dglGetProcAddress('glProgramUniformMatrix2fv');
  glProgramUniformMatrix3fv                := dglGetProcAddress('glProgramUniformMatrix3fv');
  glProgramUniformMatrix4fv                := dglGetProcAddress('glProgramUniformMatrix4fv');
  glProgramUniformMatrix2x3fv              := dglGetProcAddress('glProgramUniformMatrix2x3fv');
  glProgramUniformMatrix3x2fv              := dglGetProcAddress('glProgramUniformMatrix3x2fv');
  glProgramUniformMatrix2x4fv              := dglGetProcAddress('glProgramUniformMatrix2x4fv');
  glProgramUniformMatrix4x2fv              := dglGetProcAddress('glProgramUniformMatrix4x2fv');
  glProgramUniformMatrix3x4fv              := dglGetProcAddress('glProgramUniformMatrix3x4fv');
  glProgramUniformMatrix4x3fv              := dglGetProcAddress('glProgramUniformMatrix4x3fv');
  glValidateProgramPipeline                := dglGetProcAddress('glValidateProgramPipeline');
  glGetProgramPipelineInfoLog              := dglGetProcAddress('glGetProgramPipelineInfoLog');
  glBindImageTexture                       := dglGetProcAddress('glBindImageTexture');
  glGetBooleaniv                           := dglGetProcAddress('glGetBooleaniv');
  glMemoryBarrier                          := dglGetProcAddress('glMemoryBarrier');
  glMemoryBarrierByRegion                  := dglGetProcAddress('glMemoryBarrierByRegion');
  glTexStorage2DMultisample                := dglGetProcAddress('glTexStorage2DMultisample');
  glGetMultisamplefv                       := dglGetProcAddress('glGetMultisamplefv');
  glSampleMaski                            := dglGetProcAddress('glSampleMaski');
  glGetTexLevelParameteriv                 := dglGetProcAddress('glGetTexLevelParameteriv');
  glGetTexLevelParameterfv                 := dglGetProcAddress('glGetTexLevelParameterfv');
  glBindVertexBuffer                       := dglGetProcAddress('glBindVertexBuffer');
  glVertexAttribFormat                     := dglGetProcAddress('glVertexAttribFormat');
  glVertexAttribIFormat                    := dglGetProcAddress('glVertexAttribIFormat');
  glVertexAttribBinding                    := dglGetProcAddress('glVertexAttribBinding');
  glVertexBindingDivisor                   := dglGetProcAddress('glVertexBindingDivisor');
{$ENDIF}
end;

procedure ReadExtensions;
begin
{$IFDEF OPENGLES_EXTENSIONS}
  Read_GL_KHR_blend_equation_advanced;
  Read_GL_KHR_debug;
  Read_GL_KHR_robustness;
  Read_GL_OES_EGL_image;
  Read_GL_OES_get_program_binary;
  Read_GL_OES_mapbuffer;
  Read_GL_OES_sample_shading;
  Read_GL_OES_texture_3D;
  Read_GL_OES_texture_storage_multisample_2d_array;
  Read_GL_OES_vertex_array_object;
  Read_GL_AMD_performance_monitor;
  Read_GL_ANGLE_framebuffer_blit;
  Read_GL_ANGLE_framebuffer_multisample;
  Read_GL_ANGLE_instanced_arrays;
  Read_GL_ANGLE_translated_shader_source;
  Read_GL_APPLE_copy_texture_levels;
  Read_GL_APPLE_framebuffer_multisample;
  Read_GL_APPLE_sync;
  Read_GL_EXT_base_instance;
  Read_GL_EXT_copy_image;
  Read_GL_EXT_debug_label;
  Read_GL_EXT_debug_marker;
  Read_GL_EXT_discard_framebuffer;
  Read_GL_EXT_disjoint_timer_query;
  Read_GL_EXT_draw_buffers;
  Read_GL_EXT_draw_buffers_indexed;
  Read_GL_EXT_draw_elements_base_vertex;
  Read_GL_EXT_draw_instanced;
  Read_GL_EXT_geometry_shader;
  Read_GL_EXT_instanced_arrays;
  Read_GL_EXT_map_buffer_range;
  Read_GL_EXT_multi_draw_arrays;
  Read_GL_EXT_multi_draw_indirect;
  Read_GL_EXT_multisampled_render_to_texture;
  Read_GL_EXT_multiview_draw_buffers;
  Read_GL_EXT_primitive_bounding_box;
  Read_GL_EXT_robustness;
  Read_GL_EXT_separate_shader_objects;
  Read_GL_EXT_tessellation_shader;
  Read_GL_EXT_texture_border_clamp;
  Read_GL_EXT_texture_buffer;
  Read_GL_EXT_texture_storage;
  Read_GL_EXT_texture_view;
  Read_GL_IMG_multisampled_render_to_texture;
  Read_GL_INTEL_performance_query;
  Read_GL_NV_bindless_texture;
  Read_GL_NV_blend_equation_advanced;
  Read_GL_NV_conditional_render;
  Read_GL_NV_copy_buffer;
  Read_GL_NV_coverage_sample;
  Read_GL_NV_draw_buffers;
  Read_GL_NV_draw_instanced;
  Read_GL_NV_fence;
  Read_GL_NV_framebuffer_blit;
  Read_GL_NV_framebuffer_multisample;
  Read_GL_NV_instanced_arrays;
  Read_GL_NV_internalformat_sample_query;
  Read_GL_NV_non_square_matrices;
  Read_GL_NV_path_rendering;
  Read_GL_NV_read_buffer;
  Read_GL_NV_viewport_array;
  Read_GL_QCOM_alpha_test;
  Read_GL_QCOM_driver_control;
  Read_GL_QCOM_extended_get;
  Read_GL_QCOM_extended_get2;
  Read_GL_QCOM_tiled_rendering;
{$ENDIF}
end;

procedure ReadCoreVersion;
var
  AnsiBuffer: AnsiString;
  Buffer: String;

  procedure TrimAndSplitVersionString(const aBuffer: String; out aMajor, aMinor: Integer);
  var
    p, s, e, len: Integer;
  begin
    aMajor := 0;
    aMinor := 0;
    try
      len := Length(aBuffer);
      p := Pos('.', aBuffer);
      if (p = 0) then
        exit;

      s := p;
      while (s > 1) and (aBuffer[s - 1] in ['0'..'9']) do
        dec(s);
      if (s = p) then
        exit;

      e := p;
      while (e < len) and (aBuffer[e + 1] in ['0'..'9']) do
        inc(e);
      if (s = p) then
        exit;

      aMajor := StrToInt(Copy(aBuffer, s - 1, p - s + 1));
      aMinor := StrToInt(Copy(aBuffer, p + 1, e - p + 1));
    except
      aMajor := 0;
      aMinor := 0;
    end;
  end;

begin
  if not Assigned(glGetString) then
    glGetString := dglGetProcAddress('glGetString');
  AnsiBuffer := PAnsiChar(glGetString(GL_VERSION));
  Buffer     := String(AnsiBuffer);

  TrimAndSplitVersionString(Buffer, GLmajor, GLminor);

  GL_VERSION_1_0 := true; // OpenGL ES is always supported
  GL_VERSION_1_1 := (GLmajor >= 1) and (GLminor >= 1);
  GL_VERSION_2_0 := (GLmajor >= 2) and (GLminor >= 0);
  GL_VERSION_3_0 := (GLmajor >= 3) and (GLminor >= 0);
  GL_VERSION_3_1 := (GLmajor >= 3) and (GLminor >= 1);
end;

{$IFDEF OPENGLES_EXTENSIONS}
procedure ReadImplementationProperties;

  function GetExtensions: String;
  var
    ExtCount, i: GLint;
  begin
    result := '';

    if not Assigned(glGetString) then
      glGetString := dglGetProcAddress('glGetString');
    if Assigned(glGetString) then
      result := String(PAnsiChar(glGetString(GL_EXTENSIONS)));

{$IFDEF OPENGLES_CORE_3_0}
    if (result = '') then begin
      if not Assigned(glGetIntegerv) then
        glGetIntegerv := dglGetProcAddress('glGetIntegerv');
      if not Assigned(glGetStringi) then
        glGetStringi := dglGetProcAddress('glGetStringi');
      if Assigned(glGetStringi) and Assigned(glGetIntegerv) then begin
        glGetIntegerv(GL_NUM_EXTENSIONS, @ExtCount);
        for i := 0 to ExtCount-1 do begin
          if (result <> '') then
            result := result + #$20;
          result := result + PAnsiChar(glGetStringi(GL_EXTENSIONS, i));
        end;
      end;
    end;
{$ENDIF}

    result := #$20 + result + #$20;
  end;

  function CheckEx(const aAllExt, aExt: String): Boolean;
  begin
    result := (Pos(#$20 + aExt + #$20, aAllExt) > 0);
  end;

var
  Buffer: String;
begin
  ReadCoreVersion;

  Buffer := GetExtensions;

  // KHR
  GL_KHR_blend_equation_advanced                := CheckEx(Buffer, 'GL_KHR_blend_equation_advanced');
  GL_KHR_blend_equation_advanced_coherent       := CheckEx(Buffer, 'GL_KHR_blend_equation_advanced_coherent');
  GL_KHR_context_flush_control                  := CheckEx(Buffer, 'GL_KHR_context_flush_control');
  GL_KHR_debug                                  := CheckEx(Buffer, 'GL_KHR_debug');
  GL_KHR_robust_buffer_access_behavior          := CheckEx(Buffer, 'GL_KHR_robust_buffer_access_behavior');
  GL_KHR_robustness                             := CheckEx(Buffer, 'GL_KHR_robustness');
  GL_KHR_texture_compression_astc_hdr           := CheckEx(Buffer, 'GL_KHR_texture_compression_astc_hdr');
  GL_KHR_texture_compression_astc_ldr           := CheckEx(Buffer, 'GL_KHR_texture_compression_astc_ldr');

  // OES
  GL_OES_EGL_image                              := CheckEx(Buffer, 'GL_OES_EGL_image');
  GL_OES_EGL_image_external                     := CheckEx(Buffer, 'GL_OES_EGL_image_external');
  GL_OES_compressed_ETC1_RGB8_sub_texture       := CheckEx(Buffer, 'GL_OES_compressed_ETC1_RGB8_sub_texture');
  GL_OES_compressed_ETC1_RGB8_texture           := CheckEx(Buffer, 'GL_OES_compressed_ETC1_RGB8_texture');
  GL_OES_compressed_paletted_texture            := CheckEx(Buffer, 'GL_OES_compressed_paletted_texture');
  GL_OES_depth24                                := CheckEx(Buffer, 'GL_OES_depth24');
  GL_OES_depth32                                := CheckEx(Buffer, 'GL_OES_depth32');
  GL_OES_depth_texture                          := CheckEx(Buffer, 'GL_OES_depth_texture');
  GL_OES_element_index_uint                     := CheckEx(Buffer, 'GL_OES_element_index_uint');
  GL_OES_fbo_render_mipmap                      := CheckEx(Buffer, 'GL_OES_fbo_render_mipmap');
  GL_OES_fragment_precision_high                := CheckEx(Buffer, 'GL_OES_fragment_precision_high');
  GL_OES_get_program_binary                     := CheckEx(Buffer, 'GL_OES_get_program_binary');
  GL_OES_mapbuffer                              := CheckEx(Buffer, 'GL_OES_mapbuffer');
  GL_OES_packed_depth_stencil                   := CheckEx(Buffer, 'GL_OES_packed_depth_stencil');
  GL_OES_required_internalformat                := CheckEx(Buffer, 'GL_OES_required_internalformat');
  GL_OES_rgb8_rgba8                             := CheckEx(Buffer, 'GL_OES_rgb8_rgba8');
  GL_OES_sample_shading                         := CheckEx(Buffer, 'GL_OES_sample_shading');
  GL_OES_sample_variables                       := CheckEx(Buffer, 'GL_OES_sample_variables');
  GL_OES_shader_image_atomic                    := CheckEx(Buffer, 'GL_OES_shader_image_atomic');
  GL_OES_shader_multisample_interpolation       := CheckEx(Buffer, 'GL_OES_shader_multisample_interpolation');
  GL_OES_standard_derivatives                   := CheckEx(Buffer, 'GL_OES_standard_derivatives');
  GL_OES_stencil1                               := CheckEx(Buffer, 'GL_OES_stencil1');
  GL_OES_stencil4                               := CheckEx(Buffer, 'GL_OES_stencil4');
  GL_OES_surfaceless_context                    := CheckEx(Buffer, 'GL_OES_surfaceless_context');
  GL_OES_texture_3D                             := CheckEx(Buffer, 'GL_OES_texture_3D');
  GL_OES_texture_compression_astc               := CheckEx(Buffer, 'GL_OES_texture_compression_astc');
  GL_OES_texture_float                          := CheckEx(Buffer, 'GL_OES_texture_float');
  GL_OES_texture_float_linear                   := CheckEx(Buffer, 'GL_OES_texture_float_linear');
  GL_OES_texture_half_float                     := CheckEx(Buffer, 'GL_OES_texture_half_float');
  GL_OES_texture_half_float_linear              := CheckEx(Buffer, 'GL_OES_texture_half_float_linear');
  GL_OES_texture_npot                           := CheckEx(Buffer, 'GL_OES_texture_npot');
  GL_OES_texture_stencil8                       := CheckEx(Buffer, 'GL_OES_texture_stencil8');
  GL_OES_texture_storage_multisample_2d_array   := CheckEx(Buffer, 'GL_OES_texture_storage_multisample_2d_array');
  GL_OES_vertex_array_object                    := CheckEx(Buffer, 'GL_OES_vertex_array_object');
  GL_OES_vertex_half_float                      := CheckEx(Buffer, 'GL_OES_vertex_half_float');
  GL_OES_vertex_type_10_10_10_2                 := CheckEx(Buffer, 'GL_OES_vertex_type_10_10_10_2');

  // AMD
  GL_AMD_compressed_3DC_texture                 := CheckEx(Buffer, 'GL_AMD_compressed_3DC_texture');
  GL_AMD_compressed_ATC_texture                 := CheckEx(Buffer, 'GL_AMD_compressed_ATC_texture');
  GL_AMD_performance_monitor                    := CheckEx(Buffer, 'GL_AMD_performance_monitor');
  GL_AMD_program_binary_Z400                    := CheckEx(Buffer, 'GL_AMD_program_binary_Z400');

  // ANDROID
  GL_ANDROID_extension_pack_es31a               := CheckEx(Buffer, 'GL_ANDROID_extension_pack_es31a');

  // ANGLE
  GL_ANGLE_depth_texture                        := CheckEx(Buffer, 'GL_ANGLE_depth_texture');
  GL_ANGLE_framebuffer_blit                     := CheckEx(Buffer, 'GL_ANGLE_framebuffer_blit');
  GL_ANGLE_framebuffer_multisample              := CheckEx(Buffer, 'GL_ANGLE_framebuffer_multisample');
  GL_ANGLE_instanced_arrays                     := CheckEx(Buffer, 'GL_ANGLE_instanced_arrays');
  GL_ANGLE_pack_reverse_row_order               := CheckEx(Buffer, 'GL_ANGLE_pack_reverse_row_order');
  GL_ANGLE_program_binary                       := CheckEx(Buffer, 'GL_ANGLE_program_binary');
  GL_ANGLE_texture_compression_dxt3             := CheckEx(Buffer, 'GL_ANGLE_texture_compression_dxt3');
  GL_ANGLE_texture_compression_dxt5             := CheckEx(Buffer, 'GL_ANGLE_texture_compression_dxt5');
  GL_ANGLE_texture_usage                        := CheckEx(Buffer, 'GL_ANGLE_texture_usage');
  GL_ANGLE_translated_shader_source             := CheckEx(Buffer, 'GL_ANGLE_translated_shader_source');

  // APPLE
  GL_APPLE_clip_distance                        := CheckEx(Buffer, 'GL_APPLE_clip_distance');
  GL_APPLE_color_buffer_packed_float            := CheckEx(Buffer, 'GL_APPLE_color_buffer_packed_float');
  GL_APPLE_copy_texture_levels                  := CheckEx(Buffer, 'GL_APPLE_copy_texture_levels');
  GL_APPLE_framebuffer_multisample              := CheckEx(Buffer, 'GL_APPLE_framebuffer_multisample');
  GL_APPLE_rgb_422                              := CheckEx(Buffer, 'GL_APPLE_rgb_422');
  GL_APPLE_sync                                 := CheckEx(Buffer, 'GL_APPLE_sync');
  GL_APPLE_texture_format_BGRA8888              := CheckEx(Buffer, 'GL_APPLE_texture_format_BGRA8888');
  GL_APPLE_texture_max_level                    := CheckEx(Buffer, 'GL_APPLE_texture_max_level');
  GL_APPLE_texture_packed_float                 := CheckEx(Buffer, 'GL_APPLE_texture_packed_float');

  // ARM
  GL_ARM_mali_program_binary                    := CheckEx(Buffer, 'GL_ARM_mali_program_binary');
  GL_ARM_mali_shader_binary                     := CheckEx(Buffer, 'GL_ARM_mali_shader_binary');
  GL_ARM_rgba8                                  := CheckEx(Buffer, 'GL_ARM_rgba8');
  GL_ARM_shader_framebuffer_fetch               := CheckEx(Buffer, 'GL_ARM_shader_framebuffer_fetch');
  GL_ARM_shader_framebuffer_fetch_depth_stencil := CheckEx(Buffer, 'GL_ARM_shader_framebuffer_fetch_depth_stencil');

  // DMP
  GL_DMP_program_binary                         := CheckEx(Buffer, 'GL_DMP_program_binary');
  GL_DMP_shader_binary                          := CheckEx(Buffer, 'GL_DMP_shader_binary');

  // EXT
  GL_EXT_base_instance                          := CheckEx(Buffer, 'GL_EXT_base_instance');
  GL_EXT_blend_minmax                           := CheckEx(Buffer, 'GL_EXT_blend_minmax');
  GL_EXT_color_buffer_half_float                := CheckEx(Buffer, 'GL_EXT_color_buffer_half_float');
  GL_EXT_copy_image                             := CheckEx(Buffer, 'GL_EXT_copy_image');
  GL_EXT_debug_label                            := CheckEx(Buffer, 'GL_EXT_debug_label');
  GL_EXT_debug_marker                           := CheckEx(Buffer, 'GL_EXT_debug_marker');
  GL_EXT_discard_framebuffer                    := CheckEx(Buffer, 'GL_EXT_discard_framebuffer');
  GL_EXT_disjoint_timer_query                   := CheckEx(Buffer, 'GL_EXT_disjoint_timer_query');
  GL_EXT_draw_buffers                           := CheckEx(Buffer, 'GL_EXT_draw_buffers');
  GL_EXT_draw_buffers_indexed                   := CheckEx(Buffer, 'GL_EXT_draw_buffers_indexed');
  GL_EXT_draw_elements_base_vertex              := CheckEx(Buffer, 'GL_EXT_draw_elements_base_vertex');
  GL_EXT_draw_instanced                         := CheckEx(Buffer, 'GL_EXT_draw_instanced');
  GL_EXT_geometry_point_size                    := CheckEx(Buffer, 'GL_EXT_geometry_point_size');
  GL_EXT_geometry_shader                        := CheckEx(Buffer, 'GL_EXT_geometry_shader');
  GL_EXT_gpu_shader5                            := CheckEx(Buffer, 'GL_EXT_gpu_shader5');
  GL_EXT_instanced_arrays                       := CheckEx(Buffer, 'GL_EXT_instanced_arrays');
  GL_EXT_map_buffer_range                       := CheckEx(Buffer, 'GL_EXT_map_buffer_range');
  GL_EXT_multi_draw_arrays                      := CheckEx(Buffer, 'GL_EXT_multi_draw_arrays');
  GL_EXT_multi_draw_indirect                    := CheckEx(Buffer, 'GL_EXT_multi_draw_indirect');
  GL_EXT_multisampled_render_to_texture         := CheckEx(Buffer, 'GL_EXT_multisampled_render_to_texture');
  GL_EXT_multiview_draw_buffers                 := CheckEx(Buffer, 'GL_EXT_multiview_draw_buffers');
  GL_EXT_occlusion_query_boolean                := CheckEx(Buffer, 'GL_EXT_occlusion_query_boolean');
  GL_EXT_primitive_bounding_box                 := CheckEx(Buffer, 'GL_EXT_primitive_bounding_box');
  GL_EXT_pvrtc_sRGB                             := CheckEx(Buffer, 'GL_EXT_pvrtc_sRGB');
  GL_EXT_read_format_bgra                       := CheckEx(Buffer, 'GL_EXT_read_format_bgra');
  GL_EXT_render_snorm                           := CheckEx(Buffer, 'GL_EXT_render_snorm');
  GL_EXT_robustness                             := CheckEx(Buffer, 'GL_EXT_robustness');
  GL_EXT_sRGB                                   := CheckEx(Buffer, 'GL_EXT_sRGB');
  GL_EXT_sRGB_write_control                     := CheckEx(Buffer, 'GL_EXT_sRGB_write_control');
  GL_EXT_separate_shader_objects                := CheckEx(Buffer, 'GL_EXT_separate_shader_objects');
  GL_EXT_shader_framebuffer_fetch               := CheckEx(Buffer, 'GL_EXT_shader_framebuffer_fetch');
  GL_EXT_shader_implicit_conversions            := CheckEx(Buffer, 'GL_EXT_shader_implicit_conversions');
  GL_EXT_shader_integer_mix                     := CheckEx(Buffer, 'GL_EXT_shader_integer_mix');
  GL_EXT_shader_io_blocks                       := CheckEx(Buffer, 'GL_EXT_shader_io_blocks');
  GL_EXT_shader_pixel_local_storage             := CheckEx(Buffer, 'GL_EXT_shader_pixel_local_storage');
  GL_EXT_shader_texture_lod                     := CheckEx(Buffer, 'GL_EXT_shader_texture_lod');
  GL_EXT_shadow_samplers                        := CheckEx(Buffer, 'GL_EXT_shadow_samplers');
  GL_EXT_tessellation_point_size                := CheckEx(Buffer, 'GL_EXT_tessellation_point_size');
  GL_EXT_tessellation_shader                    := CheckEx(Buffer, 'GL_EXT_tessellation_shader');
  GL_EXT_texture_border_clamp                   := CheckEx(Buffer, 'GL_EXT_texture_border_clamp');
  GL_EXT_texture_buffer                         := CheckEx(Buffer, 'GL_EXT_texture_buffer');
  GL_EXT_texture_compression_dxt1               := CheckEx(Buffer, 'GL_EXT_texture_compression_dxt1');
  GL_EXT_texture_compression_s3tc               := CheckEx(Buffer, 'GL_EXT_texture_compression_s3tc');
  GL_EXT_texture_cube_map_array                 := CheckEx(Buffer, 'GL_EXT_texture_cube_map_array');
  GL_EXT_texture_filter_anisotropic             := CheckEx(Buffer, 'GL_EXT_texture_filter_anisotropic');
  GL_EXT_texture_format_BGRA8888                := CheckEx(Buffer, 'GL_EXT_texture_format_BGRA8888');
  GL_EXT_texture_norm16                         := CheckEx(Buffer, 'GL_EXT_texture_norm16');
  GL_EXT_texture_rg                             := CheckEx(Buffer, 'GL_EXT_texture_rg');
  GL_EXT_texture_sRGB_decode                    := CheckEx(Buffer, 'GL_EXT_texture_sRGB_decode');
  GL_EXT_texture_storage                        := CheckEx(Buffer, 'GL_EXT_texture_storage');
  GL_EXT_texture_type_2_10_10_10_REV            := CheckEx(Buffer, 'GL_EXT_texture_type_2_10_10_10_REV');
  GL_EXT_texture_view                           := CheckEx(Buffer, 'GL_EXT_texture_view');
  GL_EXT_unpack_subimage                        := CheckEx(Buffer, 'GL_EXT_unpack_subimage');

  // FJ
  GL_FJ_shader_binary_GCCSO                     := CheckEx(Buffer, 'GL_FJ_shader_binary_GCCSO');

  // IMG
  GL_IMG_multisampled_render_to_texture         := CheckEx(Buffer, 'GL_IMG_multisampled_render_to_texture');
  GL_IMG_program_binary                         := CheckEx(Buffer, 'GL_IMG_program_binary');
  GL_IMG_read_format                            := CheckEx(Buffer, 'GL_IMG_read_format');
  GL_IMG_shader_binary                          := CheckEx(Buffer, 'GL_IMG_shader_binary');
  GL_IMG_texture_compression_pvrtc              := CheckEx(Buffer, 'GL_IMG_texture_compression_pvrtc');
  GL_IMG_texture_compression_pvrtc2             := CheckEx(Buffer, 'GL_IMG_texture_compression_pvrtc2');

  // INTEL
  GL_INTEL_performance_query                    := CheckEx(Buffer, 'GL_INTEL_performance_query');

  // NV
  GL_NV_bindless_texture                        := CheckEx(Buffer, 'GL_NV_bindless_texture');
  GL_NV_blend_equation_advanced                 := CheckEx(Buffer, 'GL_NV_blend_equation_advanced');
  GL_NV_blend_equation_advanced_coherent        := CheckEx(Buffer, 'GL_NV_blend_equation_advanced_coherent');
  GL_NV_conditional_render                      := CheckEx(Buffer, 'GL_NV_conditional_render');
  GL_NV_copy_buffer                             := CheckEx(Buffer, 'GL_NV_copy_buffer');
  GL_NV_coverage_sample                         := CheckEx(Buffer, 'GL_NV_coverage_sample');
  GL_NV_depth_nonlinear                         := CheckEx(Buffer, 'GL_NV_depth_nonlinear');
  GL_NV_draw_buffers                            := CheckEx(Buffer, 'GL_NV_draw_buffers');
  GL_NV_draw_instanced                          := CheckEx(Buffer, 'GL_NV_draw_instanced');
  GL_NV_explicit_attrib_location                := CheckEx(Buffer, 'GL_NV_explicit_attrib_location');
  GL_NV_fbo_color_attachments                   := CheckEx(Buffer, 'GL_NV_fbo_color_attachments');
  GL_NV_fence                                   := CheckEx(Buffer, 'GL_NV_fence');
  GL_NV_framebuffer_blit                        := CheckEx(Buffer, 'GL_NV_framebuffer_blit');
  GL_NV_framebuffer_multisample                 := CheckEx(Buffer, 'GL_NV_framebuffer_multisample');
  GL_NV_generate_mipmap_sRGB                    := CheckEx(Buffer, 'GL_NV_generate_mipmap_sRGB');
  GL_NV_image_formats                           := CheckEx(Buffer, 'GL_NV_image_formats');
  GL_NV_instanced_arrays                        := CheckEx(Buffer, 'GL_NV_instanced_arrays');
  GL_NV_internalformat_sample_query             := CheckEx(Buffer, 'GL_NV_internalformat_sample_query');
  GL_NV_non_square_matrices                     := CheckEx(Buffer, 'GL_NV_non_square_matrices');
  GL_NV_path_rendering                          := CheckEx(Buffer, 'GL_NV_path_rendering');
  GL_NV_read_buffer                             := CheckEx(Buffer, 'GL_NV_read_buffer');
  GL_NV_read_buffer_front                       := CheckEx(Buffer, 'GL_NV_read_buffer_front');
  GL_NV_read_depth                              := CheckEx(Buffer, 'GL_NV_read_depth');
  GL_NV_read_depth_stencil                      := CheckEx(Buffer, 'GL_NV_read_depth_stencil');
  GL_NV_read_stencil                            := CheckEx(Buffer, 'GL_NV_read_stencil');
  GL_NV_sRGB_formats                            := CheckEx(Buffer, 'GL_NV_sRGB_formats');
  GL_NV_shader_noperspective_interpolation      := CheckEx(Buffer, 'GL_NV_shader_noperspective_interpolation');
  GL_NV_shadow_samplers_array                   := CheckEx(Buffer, 'GL_NV_shadow_samplers_array');
  GL_NV_shadow_samplers_cube                    := CheckEx(Buffer, 'GL_NV_shadow_samplers_cube');
  GL_NV_texture_border_clamp                    := CheckEx(Buffer, 'GL_NV_texture_border_clamp');
  GL_NV_texture_compression_s3tc_update         := CheckEx(Buffer, 'GL_NV_texture_compression_s3tc_update');
  GL_NV_texture_npot_2D_mipmap                  := CheckEx(Buffer, 'GL_NV_texture_npot_2D_mipmap');
  GL_NV_viewport_array                          := CheckEx(Buffer, 'GL_NV_viewport_array');

  // QCOM
  GL_QCOM_alpha_test                            := CheckEx(Buffer, 'GL_QCOM_alpha_test');
  GL_QCOM_binning_control                       := CheckEx(Buffer, 'GL_QCOM_binning_control');
  GL_QCOM_driver_control                        := CheckEx(Buffer, 'GL_QCOM_driver_control');
  GL_QCOM_extended_get                          := CheckEx(Buffer, 'GL_QCOM_extended_get');
  GL_QCOM_extended_get2                         := CheckEx(Buffer, 'GL_QCOM_extended_get2');
  GL_QCOM_perfmon_global_mode                   := CheckEx(Buffer, 'GL_QCOM_perfmon_global_mode');
  GL_QCOM_tiled_rendering                       := CheckEx(Buffer, 'GL_QCOM_tiled_rendering');
  GL_QCOM_writeonly_rendering                   := CheckEx(Buffer, 'GL_QCOM_writeonly_rendering');

  // VIV
  GL_VIV_shader_binary                          := CheckEx(Buffer, 'GL_VIV_shader_binary');
end;
{$ELSE}
procedure ReadImplementationProperties;
begin
  // nothing to do here
end;
{$ENDIF}

{$IFDEF OPENGLES_EXTENSIONS}
procedure Read_GL_KHR_blend_equation_advanced;
begin
  glBlendBarrierKHR                                        := dglGetProcAddress('glBlendBarrierKHR');
end;

procedure Read_GL_KHR_debug;
begin
  glDebugMessageControlKHR                                 := dglGetProcAddress('glDebugMessageControlKHR');
  glDebugMessageInsertKHR                                  := dglGetProcAddress('glDebugMessageInsertKHR');
  glDebugMessageCallbackKHR                                := dglGetProcAddress('glDebugMessageCallbackKHR');
  glGetDebugMessageLogKHR                                  := dglGetProcAddress('glGetDebugMessageLogKHR');
  glPushDebugGroupKHR                                      := dglGetProcAddress('glPushDebugGroupKHR');
  glPopDebugGroupKHR                                       := dglGetProcAddress('glPopDebugGroupKHR');
  glObjectLabelKHR                                         := dglGetProcAddress('glObjectLabelKHR');
  glGetObjectLabelKHR                                      := dglGetProcAddress('glGetObjectLabelKHR');
  glObjectPtrLabelKHR                                      := dglGetProcAddress('glObjectPtrLabelKHR');
  glGetObjectPtrLabelKHR                                   := dglGetProcAddress('glGetObjectPtrLabelKHR');
  glGetPointervKHR                                         := dglGetProcAddress('glGetPointervKHR');
end;

procedure Read_GL_KHR_robustness;
begin
  glGetGraphicsResetStatusKHR                              := dglGetProcAddress('glGetGraphicsResetStatusKHR');
  glReadnPixelsKHR                                         := dglGetProcAddress('glReadnPixelsKHR');
  glGetnUniformfvKHR                                       := dglGetProcAddress('glGetnUniformfvKHR');
  glGetnUniformivKHR                                       := dglGetProcAddress('glGetnUniformivKHR');
  glGetnUniformuivKHR                                      := dglGetProcAddress('glGetnUniformuivKHR');
end;

procedure Read_GL_OES_EGL_image;
begin
  glEGLImageTargetTexture2DOES                             := dglGetProcAddress('glEGLImageTargetTexture2DOES');
  glEGLImageTargetRenderbufferStorageOES                   := dglGetProcAddress('glEGLImageTargetRenderbufferStorageOES');
end;

procedure Read_GL_OES_get_program_binary;
begin
  glGetProgramBinaryOES                                    := dglGetProcAddress('glGetProgramBinaryOES');
  glProgramBinaryOES                                       := dglGetProcAddress('glProgramBinaryOES');
end;

procedure Read_GL_OES_mapbuffer;
begin
  glMapBufferOES                                           := dglGetProcAddress('glMapBufferOES');
  glUnmapBufferOES                                         := dglGetProcAddress('glUnmapBufferOES');
  glGetBufferPointervOES                                   := dglGetProcAddress('glGetBufferPointervOES');
end;

procedure Read_GL_OES_sample_shading;
begin
  glMinSampleShadingOES                                    := dglGetProcAddress('glMinSampleShadingOES');
end;

procedure Read_GL_OES_texture_3D;
begin
  glTexImage3DOES                                          := dglGetProcAddress('glTexImage3DOES');
  glTexSubImage3DOES                                       := dglGetProcAddress('glTexSubImage3DOES');
  glCopyTexSubImage3DOES                                   := dglGetProcAddress('glCopyTexSubImage3DOES');
  glCompressedTexImage3DOES                                := dglGetProcAddress('glCompressedTexImage3DOES');
  glCompressedTexSubImage3DOES                             := dglGetProcAddress('glCompressedTexSubImage3DOES');
  glFramebufferTexture3DOES                                := dglGetProcAddress('glFramebufferTexture3DOES');
end;

procedure Read_GL_OES_texture_storage_multisample_2d_array;
begin
  glTexStorage3DMultisampleOES                             := dglGetProcAddress('glTexStorage3DMultisampleOES');
end;

procedure Read_GL_OES_vertex_array_object;
begin
  glBindVertexArrayOES                                     := dglGetProcAddress('glBindVertexArrayOES');
  glDeleteVertexArraysOES                                  := dglGetProcAddress('glDeleteVertexArraysOES');
  glGenVertexArraysOES                                     := dglGetProcAddress('glGenVertexArraysOES');
  glIsVertexArrayOES                                       := dglGetProcAddress('glIsVertexArrayOES');
end;

procedure Read_GL_AMD_performance_monitor;
begin
  glGetPerfMonitorGroupsAMD                                := dglGetProcAddress('glGetPerfMonitorGroupsAMD');
  glGetPerfMonitorCountersAMD                              := dglGetProcAddress('glGetPerfMonitorCountersAMD');
  glGetPerfMonitorGroupStringAMD                           := dglGetProcAddress('glGetPerfMonitorGroupStringAMD');
  glGetPerfMonitorCounterStringAMD                         := dglGetProcAddress('glGetPerfMonitorCounterStringAMD');
  glGetPerfMonitorCounterInfoAMD                           := dglGetProcAddress('glGetPerfMonitorCounterInfoAMD');
  glGenPerfMonitorsAMD                                     := dglGetProcAddress('glGenPerfMonitorsAMD');
  glDeletePerfMonitorsAMD                                  := dglGetProcAddress('glDeletePerfMonitorsAMD');
  glSelectPerfMonitorCountersAMD                           := dglGetProcAddress('glSelectPerfMonitorCountersAMD');
  glBeginPerfMonitorAMD                                    := dglGetProcAddress('glBeginPerfMonitorAMD');
  glEndPerfMonitorAMD                                      := dglGetProcAddress('glEndPerfMonitorAMD');
  glGetPerfMonitorCounterDataAMD                           := dglGetProcAddress('glGetPerfMonitorCounterDataAMD');
end;

procedure Read_GL_ANGLE_framebuffer_blit;
begin
  glBlitFramebufferANGLE                                   := dglGetProcAddress('glBlitFramebufferANGLE');
end;

procedure Read_GL_ANGLE_framebuffer_multisample;
begin
  glRenderbufferStorageMultisampleANGLE                    := dglGetProcAddress('glRenderbufferStorageMultisampleANGLE');
end;

procedure Read_GL_ANGLE_instanced_arrays;
begin
  glDrawArraysInstancedANGLE                               := dglGetProcAddress('glDrawArraysInstancedANGLE');
  glDrawElementsInstancedANGLE                             := dglGetProcAddress('glDrawElementsInstancedANGLE');
  glVertexAttribDivisorANGLE                               := dglGetProcAddress('glVertexAttribDivisorANGLE');
end;

procedure Read_GL_ANGLE_translated_shader_source;
begin
  glGetTranslatedShaderSourceANGLE                         := dglGetProcAddress('glGetTranslatedShaderSourceANGLE');
end;

procedure Read_GL_APPLE_copy_texture_levels;
begin
  glCopyTextureLevelsAPPLE                                 := dglGetProcAddress('glCopyTextureLevelsAPPLE');
end;

procedure Read_GL_APPLE_framebuffer_multisample;
begin
  glRenderbufferStorageMultisampleAPPLE                    := dglGetProcAddress('glRenderbufferStorageMultisampleAPPLE');
  glResolveMultisampleFramebufferAPPLE                     := dglGetProcAddress('glResolveMultisampleFramebufferAPPLE');
end;

procedure Read_GL_APPLE_sync;
begin
  glFenceSyncAPPLE                                         := dglGetProcAddress('glFenceSyncAPPLE');
  glIsSyncAPPLE                                            := dglGetProcAddress('glIsSyncAPPLE');
  glDeleteSyncAPPLE                                        := dglGetProcAddress('glDeleteSyncAPPLE');
  glClientWaitSyncAPPLE                                    := dglGetProcAddress('glClientWaitSyncAPPLE');
  glWaitSyncAPPLE                                          := dglGetProcAddress('glWaitSyncAPPLE');
  glGetInteger64vAPPLE                                     := dglGetProcAddress('glGetInteger64vAPPLE');
  glGetSyncivAPPLE                                         := dglGetProcAddress('glGetSyncivAPPLE');
end;

procedure Read_GL_EXT_base_instance;
begin
  glDrawArraysInstancedBaseInstanceEXT                     := dglGetProcAddress('glDrawArraysInstancedBaseInstanceEXT');
  glDrawElementsInstancedBaseInstanceEXT                   := dglGetProcAddress('glDrawElementsInstancedBaseInstanceEXT');
  glDrawElementsInstancedBaseVertexBaseInstanceEXT         := dglGetProcAddress('glDrawElementsInstancedBaseVertexBaseInstanceEXT');
end;

procedure Read_GL_EXT_copy_image;
begin
  glCopyImageSubDataEXT                                    := dglGetProcAddress('glCopyImageSubDataEXT');
end;

procedure Read_GL_EXT_debug_label;
begin
  glLabelObjectEXT                                         := dglGetProcAddress('glLabelObjectEXT');
  glGetObjectLabelEXT                                      := dglGetProcAddress('glGetObjectLabelEXT');
end;

procedure Read_GL_EXT_debug_marker;
begin
  glInsertEventMarkerEXT                                   := dglGetProcAddress('glInsertEventMarkerEXT');
  glPushGroupMarkerEXT                                     := dglGetProcAddress('glPushGroupMarkerEXT');
  glPopGroupMarkerEXT                                      := dglGetProcAddress('glPopGroupMarkerEXT');
end;

procedure Read_GL_EXT_discard_framebuffer;
begin
  glDiscardFramebufferEXT                                  := dglGetProcAddress('glDiscardFramebufferEXT');
end;

procedure Read_GL_EXT_disjoint_timer_query;
begin
  glGenQueriesEXT                                          := dglGetProcAddress('glGenQueriesEXT');
  glDeleteQueriesEXT                                       := dglGetProcAddress('glDeleteQueriesEXT');
  glIsQueryEXT                                             := dglGetProcAddress('glIsQueryEXT');
  glBeginQueryEXT                                          := dglGetProcAddress('glBeginQueryEXT');
  glEndQueryEXT                                            := dglGetProcAddress('glEndQueryEXT');
  glQueryCounterEXT                                        := dglGetProcAddress('glQueryCounterEXT');
  glGetQueryivEXT                                          := dglGetProcAddress('glGetQueryivEXT');
  glGetQueryObjectivEXT                                    := dglGetProcAddress('glGetQueryObjectivEXT');
  glGetQueryObjectuivEXT                                   := dglGetProcAddress('glGetQueryObjectuivEXT');
  glGetQueryObjecti64vEXT                                  := dglGetProcAddress('glGetQueryObjecti64vEXT');
  glGetQueryObjectui64vEXT                                 := dglGetProcAddress('glGetQueryObjectui64vEXT');
end;

procedure Read_GL_EXT_draw_buffers;
begin
  glDrawBuffersEXT                                         := dglGetProcAddress('glDrawBuffersEXT');
end;

procedure Read_GL_EXT_draw_buffers_indexed;
begin
  glEnableiEXT                                             := dglGetProcAddress('glEnableiEXT');
  glDisableiEXT                                            := dglGetProcAddress('glDisableiEXT');
  glBlendEquationiEXT                                      := dglGetProcAddress('glBlendEquationiEXT');
  glBlendEquationSeparateiEXT                              := dglGetProcAddress('glBlendEquationSeparateiEXT');
  glBlendFunciEXT                                          := dglGetProcAddress('glBlendFunciEXT');
  glBlendFuncSeparateiEXT                                  := dglGetProcAddress('glBlendFuncSeparateiEXT');
  glColorMaskiEXT                                          := dglGetProcAddress('glColorMaskiEXT');
  glIsEnablediEXT                                          := dglGetProcAddress('glIsEnablediEXT');
end;

procedure Read_GL_EXT_draw_elements_base_vertex;
begin
  glDrawElementsBaseVertexEXT                              := dglGetProcAddress('glDrawElementsBaseVertexEXT');
  glDrawRangeElementsBaseVertexEXT                         := dglGetProcAddress('glDrawRangeElementsBaseVertexEXT');
  glDrawElementsInstancedBaseVertexEXT                     := dglGetProcAddress('glDrawElementsInstancedBaseVertexEXT');
  glMultiDrawElementsBaseVertexEXT                         := dglGetProcAddress('glMultiDrawElementsBaseVertexEXT');
end;

procedure Read_GL_EXT_draw_instanced;
begin
  glDrawArraysInstancedEXT                                 := dglGetProcAddress('glDrawArraysInstancedEXT');
  glDrawElementsInstancedEXT                               := dglGetProcAddress('glDrawElementsInstancedEXT');
end;

procedure Read_GL_EXT_geometry_shader;
begin
  glFramebufferTextureEXT                                  := dglGetProcAddress('glFramebufferTextureEXT');
end;

procedure Read_GL_EXT_instanced_arrays;
begin
  glVertexAttribDivisorEXT                                 := dglGetProcAddress('glVertexAttribDivisorEXT');
end;

procedure Read_GL_EXT_map_buffer_range;
begin
  glMapBufferRangeEXT                                      := dglGetProcAddress('glMapBufferRangeEXT');
  glFlushMappedBufferRangeEXT                              := dglGetProcAddress('glFlushMappedBufferRangeEXT');
end;

procedure Read_GL_EXT_multi_draw_arrays;
begin
  glMultiDrawArraysEXT                                     := dglGetProcAddress('glMultiDrawArraysEXT');
  glMultiDrawElementsEXT                                   := dglGetProcAddress('glMultiDrawElementsEXT');
end;

procedure Read_GL_EXT_multi_draw_indirect;
begin
  glMultiDrawArraysIndirectEXT                             := dglGetProcAddress('glMultiDrawArraysIndirectEXT');
  glMultiDrawElementsIndirectEXT                           := dglGetProcAddress('glMultiDrawElementsIndirectEXT');
end;

procedure Read_GL_EXT_multisampled_render_to_texture;
begin
  glRenderbufferStorageMultisampleEXT                      := dglGetProcAddress('glRenderbufferStorageMultisampleEXT');
  glFramebufferTexture2DMultisampleEXT                     := dglGetProcAddress('glFramebufferTexture2DMultisampleEXT');
end;

procedure Read_GL_EXT_multiview_draw_buffers;
begin
  glReadBufferIndexedEXT                                   := dglGetProcAddress('glReadBufferIndexedEXT');
  glDrawBuffersIndexedEXT                                  := dglGetProcAddress('glDrawBuffersIndexedEXT');
  glGetIntegeri_vEXT                                       := dglGetProcAddress('glGetIntegeri_vEXT');
end;

procedure Read_GL_EXT_primitive_bounding_box;
begin
  glPrimitiveBoundingBoxEXT                                := dglGetProcAddress('glPrimitiveBoundingBoxEXT');
end;

procedure Read_GL_EXT_robustness;
begin
  glGetGraphicsResetStatusEXT                              := dglGetProcAddress('glGetGraphicsResetStatusEXT');
  glReadnPixelsEXT                                         := dglGetProcAddress('glReadnPixelsEXT');
  glGetnUniformfvEXT                                       := dglGetProcAddress('glGetnUniformfvEXT');
  glGetnUniformivEXT                                       := dglGetProcAddress('glGetnUniformivEXT');
end;

procedure Read_GL_EXT_separate_shader_objects;
begin
  glActiveShaderProgramEXT                                 := dglGetProcAddress('glActiveShaderProgramEXT');
  glBindProgramPipelineEXT                                 := dglGetProcAddress('glBindProgramPipelineEXT');
  glCreateShaderProgramvEXT                                := dglGetProcAddress('glCreateShaderProgramvEXT');
  glDeleteProgramPipelinesEXT                              := dglGetProcAddress('glDeleteProgramPipelinesEXT');
  glGenProgramPipelinesEXT                                 := dglGetProcAddress('glGenProgramPipelinesEXT');
  glGetProgramPipelineInfoLogEXT                           := dglGetProcAddress('glGetProgramPipelineInfoLogEXT');
  glGetProgramPipelineivEXT                                := dglGetProcAddress('glGetProgramPipelineivEXT');
  glIsProgramPipelineEXT                                   := dglGetProcAddress('glIsProgramPipelineEXT');
  glProgramParameteriEXT                                   := dglGetProcAddress('glProgramParameteriEXT');
  glProgramUniform1fEXT                                    := dglGetProcAddress('glProgramUniform1fEXT');
  glProgramUniform1fvEXT                                   := dglGetProcAddress('glProgramUniform1fvEXT');
  glProgramUniform1iEXT                                    := dglGetProcAddress('glProgramUniform1iEXT');
  glProgramUniform1ivEXT                                   := dglGetProcAddress('glProgramUniform1ivEXT');
  glProgramUniform2fEXT                                    := dglGetProcAddress('glProgramUniform2fEXT');
  glProgramUniform2fvEXT                                   := dglGetProcAddress('glProgramUniform2fvEXT');
  glProgramUniform2iEXT                                    := dglGetProcAddress('glProgramUniform2iEXT');
  glProgramUniform2ivEXT                                   := dglGetProcAddress('glProgramUniform2ivEXT');
  glProgramUniform3fEXT                                    := dglGetProcAddress('glProgramUniform3fEXT');
  glProgramUniform3fvEXT                                   := dglGetProcAddress('glProgramUniform3fvEXT');
  glProgramUniform3iEXT                                    := dglGetProcAddress('glProgramUniform3iEXT');
  glProgramUniform3ivEXT                                   := dglGetProcAddress('glProgramUniform3ivEXT');
  glProgramUniform4fEXT                                    := dglGetProcAddress('glProgramUniform4fEXT');
  glProgramUniform4fvEXT                                   := dglGetProcAddress('glProgramUniform4fvEXT');
  glProgramUniform4iEXT                                    := dglGetProcAddress('glProgramUniform4iEXT');
  glProgramUniform4ivEXT                                   := dglGetProcAddress('glProgramUniform4ivEXT');
  glProgramUniformMatrix2fvEXT                             := dglGetProcAddress('glProgramUniformMatrix2fvEXT');
  glProgramUniformMatrix3fvEXT                             := dglGetProcAddress('glProgramUniformMatrix3fvEXT');
  glProgramUniformMatrix4fvEXT                             := dglGetProcAddress('glProgramUniformMatrix4fvEXT');
  glUseProgramStagesEXT                                    := dglGetProcAddress('glUseProgramStagesEXT');
  glValidateProgramPipelineEXT                             := dglGetProcAddress('glValidateProgramPipelineEXT');
  glProgramUniform1uiEXT                                   := dglGetProcAddress('glProgramUniform1uiEXT');
  glProgramUniform2uiEXT                                   := dglGetProcAddress('glProgramUniform2uiEXT');
  glProgramUniform3uiEXT                                   := dglGetProcAddress('glProgramUniform3uiEXT');
  glProgramUniform4uiEXT                                   := dglGetProcAddress('glProgramUniform4uiEXT');
  glProgramUniform1uivEXT                                  := dglGetProcAddress('glProgramUniform1uivEXT');
  glProgramUniform2uivEXT                                  := dglGetProcAddress('glProgramUniform2uivEXT');
  glProgramUniform3uivEXT                                  := dglGetProcAddress('glProgramUniform3uivEXT');
  glProgramUniform4uivEXT                                  := dglGetProcAddress('glProgramUniform4uivEXT');
  glProgramUniformMatrix2x3fvEXT                           := dglGetProcAddress('glProgramUniformMatrix2x3fvEXT');
  glProgramUniformMatrix3x2fvEXT                           := dglGetProcAddress('glProgramUniformMatrix3x2fvEXT');
  glProgramUniformMatrix2x4fvEXT                           := dglGetProcAddress('glProgramUniformMatrix2x4fvEXT');
  glProgramUniformMatrix4x2fvEXT                           := dglGetProcAddress('glProgramUniformMatrix4x2fvEXT');
  glProgramUniformMatrix3x4fvEXT                           := dglGetProcAddress('glProgramUniformMatrix3x4fvEXT');
  glProgramUniformMatrix4x3fvEXT                           := dglGetProcAddress('glProgramUniformMatrix4x3fvEXT');
end;

procedure Read_GL_EXT_tessellation_shader;
begin
  glPatchParameteriEXT                                     := dglGetProcAddress('glPatchParameteriEXT');
end;

procedure Read_GL_EXT_texture_border_clamp;
begin
  glTexParameterIivEXT                                     := dglGetProcAddress('glTexParameterIivEXT');
  glTexParameterIuivEXT                                    := dglGetProcAddress('glTexParameterIuivEXT');
  glGetTexParameterIivEXT                                  := dglGetProcAddress('glGetTexParameterIivEXT');
  glGetTexParameterIuivEXT                                 := dglGetProcAddress('glGetTexParameterIuivEXT');
  glSamplerParameterIivEXT                                 := dglGetProcAddress('glSamplerParameterIivEXT');
  glSamplerParameterIuivEXT                                := dglGetProcAddress('glSamplerParameterIuivEXT');
  glGetSamplerParameterIivEXT                              := dglGetProcAddress('glGetSamplerParameterIivEXT');
  glGetSamplerParameterIuivEXT                             := dglGetProcAddress('glGetSamplerParameterIuivEXT');
end;

procedure Read_GL_EXT_texture_buffer;
begin
  glTexBufferEXT                                           := dglGetProcAddress('glTexBufferEXT');
  glTexBufferRangeEXT                                      := dglGetProcAddress('glTexBufferRangeEXT');
end;

procedure Read_GL_EXT_texture_storage;
begin
  glTexStorage1DEXT                                        := dglGetProcAddress('glTexStorage1DEXT');
  glTexStorage2DEXT                                        := dglGetProcAddress('glTexStorage2DEXT');
  glTexStorage3DEXT                                        := dglGetProcAddress('glTexStorage3DEXT');
  glTextureStorage1DEXT                                    := dglGetProcAddress('glTextureStorage1DEXT');
  glTextureStorage2DEXT                                    := dglGetProcAddress('glTextureStorage2DEXT');
  glTextureStorage3DEXT                                    := dglGetProcAddress('glTextureStorage3DEXT');
end;

procedure Read_GL_EXT_texture_view;
begin
  glTextureViewEXT                                         := dglGetProcAddress('glTextureViewEXT');
end;

procedure Read_GL_IMG_multisampled_render_to_texture;
begin
  glRenderbufferStorageMultisampleIMG                      := dglGetProcAddress('glRenderbufferStorageMultisampleIMG');
  glFramebufferTexture2DMultisampleIMG                     := dglGetProcAddress('glFramebufferTexture2DMultisampleIMG');
end;

procedure Read_GL_INTEL_performance_query;
begin
  glBeginPerfQueryINTEL                                    := dglGetProcAddress('glBeginPerfQueryINTEL');
  glCreatePerfQueryINTEL                                   := dglGetProcAddress('glCreatePerfQueryINTEL');
  glDeletePerfQueryINTEL                                   := dglGetProcAddress('glDeletePerfQueryINTEL');
  glEndPerfQueryINTEL                                      := dglGetProcAddress('glEndPerfQueryINTEL');
  glGetFirstPerfQueryIdINTEL                               := dglGetProcAddress('glGetFirstPerfQueryIdINTEL');
  glGetNextPerfQueryIdINTEL                                := dglGetProcAddress('glGetNextPerfQueryIdINTEL');
  glGetPerfCounterInfoINTEL                                := dglGetProcAddress('glGetPerfCounterInfoINTEL');
  glGetPerfQueryDataINTEL                                  := dglGetProcAddress('glGetPerfQueryDataINTEL');
  glGetPerfQueryIdByNameINTEL                              := dglGetProcAddress('glGetPerfQueryIdByNameINTEL');
  glGetPerfQueryInfoINTEL                                  := dglGetProcAddress('glGetPerfQueryInfoINTEL');
end;

procedure Read_GL_NV_bindless_texture;
begin
  glGetTextureHandleNV                                     := dglGetProcAddress('glGetTextureHandleNV');
  glGetTextureSamplerHandleNV                              := dglGetProcAddress('glGetTextureSamplerHandleNV');
  glMakeTextureHandleResidentNV                            := dglGetProcAddress('glMakeTextureHandleResidentNV');
  glMakeTextureHandleNonResidentNV                         := dglGetProcAddress('glMakeTextureHandleNonResidentNV');
  glGetImageHandleNV                                       := dglGetProcAddress('glGetImageHandleNV');
  glMakeImageHandleResidentNV                              := dglGetProcAddress('glMakeImageHandleResidentNV');
  glMakeImageHandleNonResidentNV                           := dglGetProcAddress('glMakeImageHandleNonResidentNV');
  glUniformHandleui64NV                                    := dglGetProcAddress('glUniformHandleui64NV');
  glUniformHandleui64vNV                                   := dglGetProcAddress('glUniformHandleui64vNV');
  glProgramUniformHandleui64NV                             := dglGetProcAddress('glProgramUniformHandleui64NV');
  glProgramUniformHandleui64vNV                            := dglGetProcAddress('glProgramUniformHandleui64vNV');
  glIsTextureHandleResidentNV                              := dglGetProcAddress('glIsTextureHandleResidentNV');
  glIsImageHandleResidentNV                                := dglGetProcAddress('glIsImageHandleResidentNV');
end;

procedure Read_GL_NV_blend_equation_advanced;
begin
  glBlendParameteriNV                                      := dglGetProcAddress('glBlendParameteriNV');
  glBlendBarrierNV                                         := dglGetProcAddress('glBlendBarrierNV');
end;

procedure Read_GL_NV_conditional_render;
begin
  glBeginConditionalRenderNV                               := dglGetProcAddress('glBeginConditionalRenderNV');
  glEndConditionalRenderNV                                 := dglGetProcAddress('glEndConditionalRenderNV');
end;

procedure Read_GL_NV_copy_buffer;
begin
  glCopyBufferSubDataNV                                    := dglGetProcAddress('glCopyBufferSubDataNV');
end;

procedure Read_GL_NV_coverage_sample;
begin
  glCoverageMaskNV                                         := dglGetProcAddress('glCoverageMaskNV');
  glCoverageOperationNV                                    := dglGetProcAddress('glCoverageOperationNV');
end;

procedure Read_GL_NV_draw_buffers;
begin
  glDrawBuffersNV                                          := dglGetProcAddress('glDrawBuffersNV');
end;

procedure Read_GL_NV_draw_instanced;
begin
  glDrawArraysInstancedNV                                  := dglGetProcAddress('glDrawArraysInstancedNV');
  glDrawElementsInstancedNV                                := dglGetProcAddress('glDrawElementsInstancedNV');
end;

procedure Read_GL_NV_fence;
begin
  glDeleteFencesNV                                         := dglGetProcAddress('glDeleteFencesNV');
  glGenFencesNV                                            := dglGetProcAddress('glGenFencesNV');
  glIsFenceNV                                              := dglGetProcAddress('glIsFenceNV');
  glTestFenceNV                                            := dglGetProcAddress('glTestFenceNV');
  glGetFenceivNV                                           := dglGetProcAddress('glGetFenceivNV');
  glFinishFenceNV                                          := dglGetProcAddress('glFinishFenceNV');
  glSetFenceNV                                             := dglGetProcAddress('glSetFenceNV');
end;

procedure Read_GL_NV_framebuffer_blit;
begin
  glBlitFramebufferNV                                      := dglGetProcAddress('glBlitFramebufferNV');
end;

procedure Read_GL_NV_framebuffer_multisample;
begin
  glRenderbufferStorageMultisampleNV                       := dglGetProcAddress('glRenderbufferStorageMultisampleNV');
end;

procedure Read_GL_NV_instanced_arrays;
begin
  glVertexAttribDivisorNV                                  := dglGetProcAddress('glVertexAttribDivisorNV');
end;

procedure Read_GL_NV_internalformat_sample_query;
begin
  glGetInternalformatSampleivNV                            := dglGetProcAddress('glGetInternalformatSampleivNV');
end;

procedure Read_GL_NV_non_square_matrices;
begin
  glUniformMatrix2x3fvNV                                   := dglGetProcAddress('glUniformMatrix2x3fvNV');
  glUniformMatrix3x2fvNV                                   := dglGetProcAddress('glUniformMatrix3x2fvNV');
  glUniformMatrix2x4fvNV                                   := dglGetProcAddress('glUniformMatrix2x4fvNV');
  glUniformMatrix4x2fvNV                                   := dglGetProcAddress('glUniformMatrix4x2fvNV');
  glUniformMatrix3x4fvNV                                   := dglGetProcAddress('glUniformMatrix3x4fvNV');
  glUniformMatrix4x3fvNV                                   := dglGetProcAddress('glUniformMatrix4x3fvNV');
end;

procedure Read_GL_NV_path_rendering;
begin
  glGenPathsNV                                             := dglGetProcAddress('glGenPathsNV');
  glDeletePathsNV                                          := dglGetProcAddress('glDeletePathsNV');
  glIsPathNV                                               := dglGetProcAddress('glIsPathNV');
  glPathCommandsNV                                         := dglGetProcAddress('glPathCommandsNV');
  glPathCoordsNV                                           := dglGetProcAddress('glPathCoordsNV');
  glPathSubCommandsNV                                      := dglGetProcAddress('glPathSubCommandsNV');
  glPathSubCoordsNV                                        := dglGetProcAddress('glPathSubCoordsNV');
  glPathStringNV                                           := dglGetProcAddress('glPathStringNV');
  glPathGlyphsNV                                           := dglGetProcAddress('glPathGlyphsNV');
  glPathGlyphRangeNV                                       := dglGetProcAddress('glPathGlyphRangeNV');
  glWeightPathsNV                                          := dglGetProcAddress('glWeightPathsNV');
  glCopyPathNV                                             := dglGetProcAddress('glCopyPathNV');
  glInterpolatePathsNV                                     := dglGetProcAddress('glInterpolatePathsNV');
  glTransformPathNV                                        := dglGetProcAddress('glTransformPathNV');
  glPathParameterivNV                                      := dglGetProcAddress('glPathParameterivNV');
  glPathParameteriNV                                       := dglGetProcAddress('glPathParameteriNV');
  glPathParameterfvNV                                      := dglGetProcAddress('glPathParameterfvNV');
  glPathParameterfNV                                       := dglGetProcAddress('glPathParameterfNV');
  glPathDashArrayNV                                        := dglGetProcAddress('glPathDashArrayNV');
  glPathStencilFuncNV                                      := dglGetProcAddress('glPathStencilFuncNV');
  glPathStencilDepthOffsetNV                               := dglGetProcAddress('glPathStencilDepthOffsetNV');
  glStencilFillPathNV                                      := dglGetProcAddress('glStencilFillPathNV');
  glStencilStrokePathNV                                    := dglGetProcAddress('glStencilStrokePathNV');
  glStencilFillPathInstancedNV                             := dglGetProcAddress('glStencilFillPathInstancedNV');
  glStencilStrokePathInstancedNV                           := dglGetProcAddress('glStencilStrokePathInstancedNV');
  glPathCoverDepthFuncNV                                   := dglGetProcAddress('glPathCoverDepthFuncNV');
  glCoverFillPathNV                                        := dglGetProcAddress('glCoverFillPathNV');
  glCoverStrokePathNV                                      := dglGetProcAddress('glCoverStrokePathNV');
  glCoverFillPathInstancedNV                               := dglGetProcAddress('glCoverFillPathInstancedNV');
  glCoverStrokePathInstancedNV                             := dglGetProcAddress('glCoverStrokePathInstancedNV');
  glGetPathParameterivNV                                   := dglGetProcAddress('glGetPathParameterivNV');
  glGetPathParameterfvNV                                   := dglGetProcAddress('glGetPathParameterfvNV');
  glGetPathCommandsNV                                      := dglGetProcAddress('glGetPathCommandsNV');
  glGetPathCoordsNV                                        := dglGetProcAddress('glGetPathCoordsNV');
  glGetPathDashArrayNV                                     := dglGetProcAddress('glGetPathDashArrayNV');
  glGetPathMetricsNV                                       := dglGetProcAddress('glGetPathMetricsNV');
  glGetPathMetricRangeNV                                   := dglGetProcAddress('glGetPathMetricRangeNV');
  glGetPathSpacingNV                                       := dglGetProcAddress('glGetPathSpacingNV');
  glIsPointInFillPathNV                                    := dglGetProcAddress('glIsPointInFillPathNV');
  glIsPointInStrokePathNV                                  := dglGetProcAddress('glIsPointInStrokePathNV');
  glGetPathLengthNV                                        := dglGetProcAddress('glGetPathLengthNV');
  glPointAlongPathNV                                       := dglGetProcAddress('glPointAlongPathNV');
  glMatrixLoad3x2fNV                                       := dglGetProcAddress('glMatrixLoad3x2fNV');
  glMatrixLoad3x3fNV                                       := dglGetProcAddress('glMatrixLoad3x3fNV');
  glMatrixLoadTranspose3x3fNV                              := dglGetProcAddress('glMatrixLoadTranspose3x3fNV');
  glMatrixMult3x2fNV                                       := dglGetProcAddress('glMatrixMult3x2fNV');
  glMatrixMult3x3fNV                                       := dglGetProcAddress('glMatrixMult3x3fNV');
  glMatrixMultTranspose3x3fNV                              := dglGetProcAddress('glMatrixMultTranspose3x3fNV');
  glStencilThenCoverFillPathNV                             := dglGetProcAddress('glStencilThenCoverFillPathNV');
  glStencilThenCoverStrokePathNV                           := dglGetProcAddress('glStencilThenCoverStrokePathNV');
  glStencilThenCoverFillPathInstancedNV                    := dglGetProcAddress('glStencilThenCoverFillPathInstancedNV');
  glStencilThenCoverStrokePathInstancedNV                  := dglGetProcAddress('glStencilThenCoverStrokePathInstancedNV');
  glPathGlyphIndexRangeNV                                  := dglGetProcAddress('glPathGlyphIndexRangeNV');
  glPathGlyphIndexArrayNV                                  := dglGetProcAddress('glPathGlyphIndexArrayNV');
  glPathMemoryGlyphIndexArrayNV                            := dglGetProcAddress('glPathMemoryGlyphIndexArrayNV');
  glProgramPathFragmentInputGenNV                          := dglGetProcAddress('glProgramPathFragmentInputGenNV');
  glGetProgramResourcefvNV                                 := dglGetProcAddress('glGetProgramResourcefvNV');
end;

procedure Read_GL_NV_read_buffer;
begin
  glReadBufferNV                                           := dglGetProcAddress('glReadBufferNV');
end;

procedure Read_GL_NV_viewport_array;
begin
  glViewportArrayvNV                                       := dglGetProcAddress('glViewportArrayvNV');
  glViewportIndexedfNV                                     := dglGetProcAddress('glViewportIndexedfNV');
  glViewportIndexedfvNV                                    := dglGetProcAddress('glViewportIndexedfvNV');
  glScissorArrayvNV                                        := dglGetProcAddress('glScissorArrayvNV');
  glScissorIndexedNV                                       := dglGetProcAddress('glScissorIndexedNV');
  glScissorIndexedvNV                                      := dglGetProcAddress('glScissorIndexedvNV');
  glDepthRangeArrayfvNV                                    := dglGetProcAddress('glDepthRangeArrayfvNV');
  glDepthRangeIndexedfNV                                   := dglGetProcAddress('glDepthRangeIndexedfNV');
  glGetFloati_vNV                                          := dglGetProcAddress('glGetFloati_vNV');
  glEnableiNV                                              := dglGetProcAddress('glEnableiNV');
  glDisableiNV                                             := dglGetProcAddress('glDisableiNV');
  glIsEnablediNV                                           := dglGetProcAddress('glIsEnablediNV');
end;

procedure Read_GL_QCOM_alpha_test;
begin
  glAlphaFuncQCOM                                          := dglGetProcAddress('glAlphaFuncQCOM');
end;

procedure Read_GL_QCOM_driver_control;
begin
  glGetDriverControlsQCOM                                  := dglGetProcAddress('glGetDriverControlsQCOM');
  glGetDriverControlStringQCOM                             := dglGetProcAddress('glGetDriverControlStringQCOM');
  glEnableDriverControlQCOM                                := dglGetProcAddress('glEnableDriverControlQCOM');
  glDisableDriverControlQCOM                               := dglGetProcAddress('glDisableDriverControlQCOM');
end;

procedure Read_GL_QCOM_extended_get;
begin
  glExtGetTexturesQCOM                                     := dglGetProcAddress('glExtGetTexturesQCOM');
  glExtGetBuffersQCOM                                      := dglGetProcAddress('glExtGetBuffersQCOM');
  glExtGetRenderbuffersQCOM                                := dglGetProcAddress('glExtGetRenderbuffersQCOM');
  glExtGetFramebuffersQCOM                                 := dglGetProcAddress('glExtGetFramebuffersQCOM');
  glExtGetTexLevelParameterivQCOM                          := dglGetProcAddress('glExtGetTexLevelParameterivQCOM');
  glExtTexObjectStateOverrideiQCOM                         := dglGetProcAddress('glExtTexObjectStateOverrideiQCOM');
  glExtGetTexSubImageQCOM                                  := dglGetProcAddress('glExtGetTexSubImageQCOM');
  glExtGetBufferPointervQCOM                               := dglGetProcAddress('glExtGetBufferPointervQCOM');
end;

procedure Read_GL_QCOM_extended_get2;
begin
  glExtGetShadersQCOM                                      := dglGetProcAddress('glExtGetShadersQCOM');
  glExtGetProgramsQCOM                                     := dglGetProcAddress('glExtGetProgramsQCOM');
  glExtIsProgramBinaryQCOM                                 := dglGetProcAddress('glExtIsProgramBinaryQCOM');
  glExtGetProgramBinarySourceQCOM                          := dglGetProcAddress('glExtGetProgramBinarySourceQCOM');
end;

procedure Read_GL_QCOM_tiled_rendering;
begin
  glStartTilingQCOM                                        := dglGetProcAddress('glStartTilingQCOM');
  glEndTilingQCOM                                          := dglGetProcAddress('glEndTilingQCOM');
end;
{$ENDIF}

constructor EeglError.Create(const msg: string; const aErrorCode: EGLint);
begin
  inherited Create(msg);
  ErrorCode := aErrorCode;
end;

end.
