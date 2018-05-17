
{$mode objfpc}
unit glext;
interface

uses
  gles11,ctypes;

type
 PGLEnum = ^GLenum;
{
  Automatically converted by H2Pas 1.0.0 from glext.h
  The following command line parameters were used:
    -C
    -P
    glext.h
}

{$IFDEF FPC}
{$PACKRECORDS C}
{$ENDIF}


  {
          Copyright:  (c) 2006-2008 by Apple Computer, Inc., all rights reserved.
   }
{$ifndef ES1_GLEXT_H_GUARD}
{$define ES1_GLEXT_H_GUARD}
//{$include <gl.h>}
  {#include <Availability.h> }
{ C++ extern C conditionnal removed }
  {
  ** License Applicability. Except to the extent portions of this file are
  ** made subject to an alternative license as permitted in the SGI Free
  ** Software License B, Version 1.0 (the "License"), the contents of this
  ** file are subject only to the provisions of the License. You may not use
  ** this file except in compliance with the License. You may obtain a copy
  ** of the License at Silicon Graphics, Inc., attn: Legal Services, 1600
  ** Amphitheatre Parkway, Mountain View, CA 94043-1351, or at:
  **
  ** http://oss.sgi.com/projects/FreeB
  **
  ** Note that, as provided in the License, the Software is distributed on an
  ** "AS IS" basis, with ALL EXPRESS AND IMPLIED WARRANTIES AND CONDITIONS
  ** DISCLAIMED, INCLUDING, WITHOUT LIMITATION, ANY IMPLIED WARRANTIES AND
  ** CONDITIONS OF MERCHANTABILITY, SATISFACTORY QUALITY, FITNESS FOR A
  ** PARTICULAR PURPOSE, AND NON-INFRINGEMENT.
  **
  ** Original Code. The Original Code is: OpenGL Sample Implementation,
  ** Version 1.2.1, released January 26, 2000, developed by Silicon Graphics,
  ** Inc. The Original Code is Copyright (c) 1991-2000 Silicon Graphics, Inc.
  ** Copyright in any portions created by third parties is as indicated
  ** elsewhere herein. All Rights Reserved.
  **
  ** Additional Notice Provisions: The application programming interfaces
  ** established by SGI in conjunction with the Original Code are The
  ** OpenGL(R) Graphics System: A Specification (Version 1.2.1), released
  ** April 1, 1999; The OpenGL(R) Graphics System Utility Library (Version
  ** 1.3), released November 4, 1998; and OpenGL(R) Graphics with the X
  ** Window System(R) (Version 1.3), released October 19, 1998. This software
  ** was created using the OpenGL(R) version 1.2.1 Sample Implementation
  ** published by SGI, but has not been independently verified as being
  ** compliant with the OpenGL(R) version 1.2.1 Specification.
   }

  const
    GL_APPLE_framebuffer_multisample = TRUE;
    GL_APPLE_texture_2D_limited_npot = TRUE;
    GL_APPLE_texture_format_BGRA8888 = TRUE;
    GL_APPLE_texture_max_level = TRUE;
    GL_EXT_blend_minmax = TRUE;
    GL_EXT_debug_label = TRUE;
    GL_EXT_debug_marker = TRUE;
    GL_EXT_discard_framebuffer = TRUE;
    GL_EXT_read_format_bgra = TRUE;
    GL_EXT_texture_filter_anisotropic = TRUE;
    GL_EXT_texture_lod_bias = TRUE;
    GL_IMG_read_format = TRUE;
    GL_IMG_texture_compression_pvrtc = TRUE;
    GL_OES_blend_equation_separate = TRUE;
    GL_OES_blend_func_separate = TRUE;
    GL_OES_blend_subtract = TRUE;
    GL_OES_depth24 = TRUE;
    GL_OES_element_index_uint = TRUE;
    GL_OES_fbo_render_mipmap = TRUE;
    GL_OES_framebuffer_object = TRUE;
    GL_OES_mapbuffer = TRUE;
    GL_OES_packed_depth_stencil = TRUE;
    GL_OES_rgb8_rgba8 = TRUE;
    GL_OES_stencil_wrap = TRUE;
    GL_OES_stencil8 = TRUE;
    GL_OES_texture_mirrored_repeat = TRUE;
    GL_OES_vertex_array_object = TRUE;
  {------------------------------------------------------------------------*
   * APPLE extension tokens
   *------------------------------------------------------------------------ }
{$if GL_APPLE_framebuffer_multisample}

  const
    GL_RENDERBUFFER_SAMPLES_APPLE = $8CAB;
    GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE_APPLE = $8D56;
    GL_MAX_SAMPLES_APPLE = $8D57;
    GL_READ_FRAMEBUFFER_APPLE = $8CA8;
    GL_DRAW_FRAMEBUFFER_APPLE = $8CA9;
    GL_DRAW_FRAMEBUFFER_BINDING_APPLE = $8CA6;
    GL_READ_FRAMEBUFFER_BINDING_APPLE = $8CAA;
{$endif}
{$if GL_APPLE_texture_format_BGRA8888}

  const
    GL_BGRA_EXT = $80E1;
{$endif}
{$if GL_APPLE_texture_format_BGRA8888 and GL_IMG_read_format}

  const
    GL_BGRA = $80E1;
{$endif}
{$if GL_APPLE_texture_max_level}

  const
    GL_TEXTURE_MAX_LEVEL_APPLE = $813D;
{$endif}
  {------------------------------------------------------------------------*
   * EXT extension tokens
   *------------------------------------------------------------------------ }
{$if GL_EXT_blend_minmax}

  const
    GL_MIN_EXT = $8007;
    GL_MAX_EXT = $8008;
{$endif}
{$if GL_EXT_debug_label}

  const
    GL_BUFFER_OBJECT_EXT = $9151;
    GL_VERTEX_ARRAY_OBJECT_EXT = $9154;
{$endif}
{$if GL_EXT_discard_framebuffer}

  const
    GL_COLOR_EXT = $1800;
    GL_DEPTH_EXT = $1801;
    GL_STENCIL_EXT = $1802;
{$endif}
{$if GL_EXT_read_format_bgra}

  const
    GL_UNSIGNED_SHORT_4_4_4_4_REV_EXT = $8365;
    GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT = $8366;
    GL_UNSIGNED_SHORT_1_5_5_5_REV = GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT;
{$endif}
{$if GL_EXT_read_format_bgra and GL_IMG_read_format}

  const
    GL_UNSIGNED_SHORT_4_4_4_4_REV = $8365;
{$endif}
{$if GL_EXT_texture_filter_anisotropic}

  const
    GL_TEXTURE_MAX_ANISOTROPY_EXT = $84FE;
    GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT = $84FF;
{$endif}
{$if GL_EXT_texture_lod_bias}

  const
    GL_MAX_TEXTURE_LOD_BIAS_EXT = $84FD;
    GL_TEXTURE_FILTER_CONTROL_EXT = $8500;
    GL_TEXTURE_LOD_BIAS_EXT = $8501;
{$endif}
  {------------------------------------------------------------------------*
   * IMG extension tokens
   *------------------------------------------------------------------------ }
{$if GL_IMG_read_format}

  const
    GL_BGRA_IMG = $80E1;
    GL_UNSIGNED_SHORT_4_4_4_4_REV_IMG = $8365;
{$endif}
{$if GL_IMG_texture_compression_pvrtc}

  const
    GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG = $8C00;
    GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG = $8C01;
    GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG = $8C02;
    GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG = $8C03;
{$endif}
  {------------------------------------------------------------------------*
   * OES extension tokens
   *------------------------------------------------------------------------ }
{$if GL_OES_blend_equation_separate}

  const
    GL_BLEND_EQUATION_RGB_OES = $8009;
    GL_BLEND_EQUATION_ALPHA_OES = $883D;
{$endif}
{$if GL_OES_blend_func_separate}

  const
    GL_BLEND_DST_RGB_OES = $80C8;
    GL_BLEND_SRC_RGB_OES = $80C9;
    GL_BLEND_DST_ALPHA_OES = $80CA;
    GL_BLEND_SRC_ALPHA_OES = $80CB;
{$endif}
{$if GL_OES_blend_subtract}

  const
    GL_BLEND_EQUATION_OES = $8009;
    GL_FUNC_ADD_OES = $8006;
    GL_FUNC_SUBTRACT_OES = $800A;
    GL_FUNC_REVERSE_SUBTRACT_OES = $800B;
{$endif}
{$if GL_OES_depth24}

  const
    GL_DEPTH_COMPONENT24_OES = $81A6;
{$endif}
{$if GL_OES_framebuffer_object}

  const
    GL_FRAMEBUFFER_OES = $8D40;
    GL_RENDERBUFFER_OES = $8D41;
    GL_RGBA4_OES = $8056;
    GL_RGB5_A1_OES = $8057;
    GL_RGB565_OES = $8D62;
    GL_DEPTH_COMPONENT16_OES = $81A5;
    GL_RENDERBUFFER_WIDTH_OES = $8D42;
    GL_RENDERBUFFER_HEIGHT_OES = $8D43;
    GL_RENDERBUFFER_INTERNAL_FORMAT_OES = $8D44;
    GL_RENDERBUFFER_RED_SIZE_OES = $8D50;
    GL_RENDERBUFFER_GREEN_SIZE_OES = $8D51;
    GL_RENDERBUFFER_BLUE_SIZE_OES = $8D52;
    GL_RENDERBUFFER_ALPHA_SIZE_OES = $8D53;
    GL_RENDERBUFFER_DEPTH_SIZE_OES = $8D54;
    GL_RENDERBUFFER_STENCIL_SIZE_OES = $8D55;
    GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE_OES = $8CD0;
    GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME_OES = $8CD1;
    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL_OES = $8CD2;
    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE_OES = $8CD3;
    GL_COLOR_ATTACHMENT0_OES = $8CE0;
    GL_DEPTH_ATTACHMENT_OES = $8D00;
    GL_STENCIL_ATTACHMENT_OES = $8D20;
    GL_FRAMEBUFFER_COMPLETE_OES = $8CD5;
    GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_OES = $8CD6;
    GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT_OES = $8CD7;
    GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_OES = $8CD9;
    GL_FRAMEBUFFER_INCOMPLETE_FORMATS_OES = $8CDA;
    GL_FRAMEBUFFER_UNSUPPORTED_OES = $8CDD;
    GL_FRAMEBUFFER_BINDING_OES = $8CA6;
    GL_RENDERBUFFER_BINDING_OES = $8CA7;
    GL_MAX_RENDERBUFFER_SIZE_OES = $84E8;
    GL_INVALID_FRAMEBUFFER_OPERATION_OES = $0506;
{$endif}
{$if GL_OES_mapbuffer}

  const
    GL_WRITE_ONLY_OES = $88B9;
    GL_BUFFER_ACCESS_OES = $88BB;
    GL_BUFFER_MAPPED_OES = $88BC;
    GL_BUFFER_MAP_POINTER_OES = $88BD;
{$endif}
{$if GL_OES_packed_depth_stencil}

  const
    GL_DEPTH_STENCIL_OES = $84F9;
    GL_UNSIGNED_INT_24_8_OES = $84FA;
    GL_DEPTH24_STENCIL8_OES = $88F0;
{$endif}
{$if GL_OES_rgb8_rgba8}

  const
    GL_RGB8_OES = $8051;
    GL_RGBA8_OES = $8058;
{$endif}
{$if GL_OES_stencil_wrap}

  const
    GL_INCR_WRAP_OES = $8507;
    GL_DECR_WRAP_OES = $8508;
{$endif}
{$if GL_OES_stencil8}

  const
    GL_STENCIL_INDEX8_OES = $8D48;
{$endif}
{$if GL_OES_texture_mirrored_repeat}

  const
    GL_MIRRORED_REPEAT_OES = $8370;
{$endif}
{$if GL_OES_vertex_array_object}

  const
    GL_VERTEX_ARRAY_BINDING_OES = $85B5;
{$endif}
{$if GL_OES_element_index_uint}

  const
    GL_UNSIGNED_INT_OES = $1405;
{$endif}
  {************************************************************************ }
  {------------------------------------------------------------------------*
   * APPLE extension functions
   *------------------------------------------------------------------------ }

var
{$if GL_APPLE_framebuffer_multisample}
 glRenderbufferStorageMultisampleAPPLE:procedure(target:GLenum;samples:GLsizei;
         internalformat:GLenum; width,height:GLsizei); cdecl;
 glResolveMultisampleFramebufferAPPLE:procedure; cdecl;
{$endif}

  {------------------------------------------------------------------------*
   * EXT extension functions
   *------------------------------------------------------------------------ }

   {$if GL_EXT_debug_marker}
 glInsertEventMarkerEXT:procedure(length:GLsizei; marker:PChar); cdecl;
 glPushGroupMarkerEXT:procedure(length:GLsizei; marker:PChar); cdecl;
 glPopGroupMarkerEXT:procedure; cdecl;
{$endif}

{$if GL_EXT_discard_framebuffer}
 glDiscardFramebufferEXT:procedure(target:GLenum; numAttachments:GLsizei; const attachments:PGLEnum); cdecl;
{$endif}
  {------------------------------------------------------------------------*
   * OES extension functions
   *------------------------------------------------------------------------ }
{$if GL_OES_blend_equation_separate}
 glBlendEquationSeparateOES :procedure(modeRGB,modeAlpha:GLenum); cdecl;
{$endif}
{$if GL_OES_blend_func_separate}
 glBlendFuncSeparateOES :procedure(srcRGB,dstRGB,srcAlpha,dstAlpha:GLenum); cdecl;
{$endif}
{$if GL_OES_blend_subtract}
 glBlendEquationOES :procedure(mode:GLenum); cdecl;
{$endif}
{$if GL_OES_framebuffer_object}
 glIsRenderbufferOES :function(renderbuffer:GLuint):GLboolean; cdecl;

 glBindRenderbufferOES:procedure(target:GLenum;renderbuffer:GLuint); cdecl;

 glDeleteRenderbuffersOES :procedure(n:GLsizei;renderbuffers:PGLuint); cdecl;
 glGenRenderbuffersOES :procedure(n:GLsizei;const renderbuffers:PGLuint); cdecl;
 glRenderbufferStorageOES :procedure(target,internalformat:GLenum;width,height:GLsizei); cdecl;
 glGetRenderbufferParameterivOES :procedure(target,pname:GLenum;out params:GLint); cdecl;
 glIsFramebufferOES :function(framebuffer:GLuint):GLboolean; cdecl;
 glBindFramebufferOES :procedure(target:GLenum;framebuffer:GLuint); cdecl;
 glDeleteFramebuffersOES :procedure(n:GLsizei;framebuffers:PGLuint); cdecl;
 glGenFramebuffersOES :procedure(n:GLsizei;const framebuffers:PGLuint); cdecl;
 glCheckFramebufferStatusOES :function(target:GLenum):GLenum; cdecl;
 glFramebufferRenderbufferOES :procedure(target,attachment,renderbuffertarget:GLenum;renderbuffer:GLuint); cdecl;
 glFramebufferTexture2DOES :procedure(target,attachment,textarget:GLenum;texture:GLuint;level:GLint); cdecl;
 glGetFramebufferAttachmentParameterivOES :procedure(target,attachment,pname:GLenum;out params:GLint); cdecl;
 glGenerateMipmapOES :procedure(target:GLenum); cdecl;
{$endif}
{$if GL_OES_mapbuffer}
 glGetBufferPointervOES :procedure(target,pname:GLenum;out params:PGLvoid); cdecl;
 glMapBufferOES :function(target,access:GLenum):pointer; cdecl;
 glUnmapBufferOES :function(target:GLenum):GLboolean; cdecl;
{$endif}
{$if GL_OES_vertex_array_object}
 glBindVertexArrayOES:procedure(array_:GLuint); cdecl;
 glDeleteVertexArraysOES:procedure(n:GLsizei;arrays:PGLuint); cdecl;
 glGenVertexArraysOES:procedure(n:GLsizei;out arrays:GLuint); cdecl;
 glIsVertexArrayOES:function(array_:GLuint):GLboolean; cdecl;
{$endif}
{ C++ end of extern C conditionnal removed }
{$endif}
  { ES1_GLEXT_H_GUARD  }

implementation

  uses
    SysUtils, dynlibs;

  var
    hlib : tlibhandle;


  procedure Freeglext;
    begin
      FreeLibrary(hlib);

      {$if GL_APPLE_framebuffer_multisample}
      glRenderbufferStorageMultisampleAPPLE:=nil;
      glResolveMultisampleFramebufferAPPLE:=nil;
      {$endif}

   {------------------------------------------------------------------------*
   * EXT extension functions
   *------------------------------------------------------------------------ }

        {$if GL_EXT_debug_marker}
        glInsertEventMarkerEXT:=nil;
        glPushGroupMarkerEXT:=nil;
        glPopGroupMarkerEXT:=nil;
        {$endif}

        {$if GL_EXT_discard_framebuffer}
        glDiscardFramebufferEXT:=nil;
        {$endif}
  {------------------------------------------------------------------------*
   * OES extension functions
   *------------------------------------------------------------------------ }
        {$if GL_OES_blend_equation_separate}
        glBlendEquationSeparateOES :=nil;
        {$endif}
        {$if GL_OES_blend_func_separate}
        glBlendFuncSeparateOES :=nil;
        {$endif}
        {$if GL_OES_blend_subtract}
        glBlendEquationOES :=nil;
        {$endif}
        {$if GL_OES_framebuffer_object}
        glIsRenderbufferOES :=nil;
        glBindRenderbufferOES :=nil;
        glDeleteRenderbuffersOES :=nil;
        glGenRenderbuffersOES :=nil;
        glRenderbufferStorageOES :=nil;
        glGetRenderbufferParameterivOES :=nil;
        glIsFramebufferOES :=nil;
        glBindFramebufferOES :=nil;
        glDeleteFramebuffersOES :=nil;
        glGenFramebuffersOES :=nil;
        glCheckFramebufferStatusOES :=nil;
        glFramebufferRenderbufferOES :=nil;
        glFramebufferTexture2DOES :=nil;
        glGetFramebufferAttachmentParameterivOES :=nil;
        glGenerateMipmapOES :=nil;
        {$endif}
        {$if GL_OES_mapbuffer}
        glGetBufferPointervOES :=nil;
        glMapBufferOES :=nil;
        glUnmapBufferOES :=nil;
        {$endif}
        {$if GL_OES_vertex_array_object}
        glBindVertexArrayOES:=nil;
        glDeleteVertexArraysOES:=nil;
        glGenVertexArraysOES:=nil;
        glIsVertexArrayOES:=nil;
        {$endif}
    end;


  procedure Loadglext(lib : pchar);
    begin
      Freeglext;
      hlib:=LoadLibrary(lib);
      if hlib=0 then
        raise Exception.Create(format('Could not load library: %s',[lib]));

      {$if GL_APPLE_framebuffer_multisample}
      pointer(glRenderbufferStorageMultisampleAPPLE):=GetProcAddress(hlib,'glRenderbufferStorageMultisampleAPPLE');
      pointer(glResolveMultisampleFramebufferAPPLE):=GetProcAddress(hlib,'glResolveMultisampleFramebufferAPPLE');
      {$endif}

   {------------------------------------------------------------------------*
   * EXT extension functions
   *------------------------------------------------------------------------ }

        {$if GL_EXT_debug_marker}
        pointer(glInsertEventMarkerEXT):=GetProcAddress(hlib,'glInsertEventMarkerEXT');
        pointer(glPushGroupMarkerEXT):=GetProcAddress(hlib,'glPushGroupMarkerEXT');
        pointer(glPopGroupMarkerEXT):=GetProcAddress(hlib,'glPopGroupMarkerEXT');
        {$endif}

        {$if GL_EXT_discard_framebuffer}
        pointer(glDiscardFramebufferEXT):=GetProcAddress(hlib,'glDiscardFramebufferEXT');
        {$endif}
  {------------------------------------------------------------------------*
   * OES extension functions
   *------------------------------------------------------------------------ }
        {$if GL_OES_blend_equation_separate}
        pointer(glBlendEquationSeparateOES) :=GetProcAddress(hlib,'glBlendEquationSeparateOES');
        {$endif}
        {$if GL_OES_blend_func_separate}
        pointer(glBlendFuncSeparateOES) :=GetProcAddress(hlib,'glBlendFuncSeparateOES');
        {$endif}
        {$if GL_OES_blend_subtract}
        pointer(glBlendEquationOES) :=GetProcAddress(hlib,'glBlendEquationOES');
        {$endif}
        {$if GL_OES_framebuffer_object}
        pointer(glIsRenderbufferOES) :=GetProcAddress(hlib,'glIsRenderbufferOES');
        pointer(glBindRenderbufferOES) :=GetProcAddress(hlib,'glBindRenderbufferOES');
        pointer(glDeleteRenderbuffersOES) :=GetProcAddress(hlib,'glDeleteRenderbuffersOES');
        pointer(glGenRenderbuffersOES) :=GetProcAddress(hlib,'glGenRenderbuffersOES');
        pointer(glRenderbufferStorageOES) :=GetProcAddress(hlib,'glRenderbufferStorageOES');
        pointer(glGetRenderbufferParameterivOES) :=GetProcAddress(hlib,'glGetRenderbufferParameterivOES');
        pointer(glIsFramebufferOES) :=GetProcAddress(hlib,'glIsFramebufferOES');
        pointer(glBindFramebufferOES) :=GetProcAddress(hlib,'glBindFramebufferOES');
        pointer(glDeleteFramebuffersOES) :=GetProcAddress(hlib,'glDeleteFramebuffersOES');
        pointer(glGenFramebuffersOES) :=GetProcAddress(hlib,'glGenFramebuffersOES');
        pointer(glCheckFramebufferStatusOES) :=GetProcAddress(hlib,'glCheckFramebufferStatusOES');
        pointer(glFramebufferRenderbufferOES) :=GetProcAddress(hlib,'glFramebufferRenderbufferOES');
        pointer(glFramebufferTexture2DOES) :=GetProcAddress(hlib,'glFramebufferTexture2DOES');
        pointer(glGetFramebufferAttachmentParameterivOES) :=GetProcAddress(hlib,'glGetFramebufferAttachmentParameterivOES');
        pointer(glGenerateMipmapOES) :=GetProcAddress(hlib,'glGenerateMipmapOES');
        {$endif}
        {$if GL_OES_mapbuffer}
        pointer(glGetBufferPointervOES) :=GetProcAddress(hlib,'glGetBufferPointervOES');
        pointer(glMapBufferOES) :=GetProcAddress(hlib,'glMapBufferOES');
        pointer(glUnmapBufferOES) :=GetProcAddress(hlib,'glUnmapBufferOES');
        {$endif}
        {$if GL_OES_vertex_array_object}
        pointer(glBindVertexArrayOES):=GetProcAddress(hlib,'glBindVertexArrayOES');
        pointer(glDeleteVertexArraysOES):=GetProcAddress(hlib,'glDeleteVertexArraysOES');
        pointer(glGenVertexArraysOES):=GetProcAddress(hlib,'glGenVertexArraysOES');
        pointer(glIsVertexArrayOES):=GetProcAddress(hlib,'glIsVertexArrayOES');
        {$endif}
    end;


initialization
//  Loadglext('glext');
{$ifdef darwin}
  Loadglext('/System/Library/Frameworks/OpenGLES.framework/OpenGLES');
{$endif}

finalization
  Freeglext;
end.
