// OpenGL-based texture classes and texture manager
//
// Copyright (C) 2011 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.ResManGL;
interface
 uses Apus.Engine.API, Apus.Images, Apus.MyServis, Types;
{$IFDEF IOS} {$DEFINE GLES} {$DEFINE GLES11} {$DEFINE OPENGL} {$ENDIF}
{$IFDEF ANDROID} {$DEFINE GLES} {$DEFINE GLES20} {$DEFINE OPENGL} {$ENDIF}
type
 // Текстура OpenGL
 TGLTexture=class(TTexture)
  texname:cardinal;
  realWidth,realHeight:integer; // real dimensions of underlying texture object (can be larger than requested)
  filter:TTexFilter;
  procedure CloneFrom(src:TTexture); override;
  procedure SetAsRenderTarget; virtual;
  procedure Lock(miplevel:byte=0;mode:TlockMode=lmReadWrite;r:PRect=nil); override; // 0-й уровень - самый верхний
  procedure AddDirtyRect(rect:TRect); override;
  function GetRawImage:TRawImage; override; // Создать RAW image и назначить его на верхний уровень текстуры (только когда текстура залочна!!!)
  procedure Unlock; override;
  destructor Destroy; override;
  function Describe:string;
  procedure SetFilter(allowInterpolation:boolean); override;
 protected
  online:boolean;
  realData:array of byte; // sysmem instance of texture data
  fbo:cardinal;
  rbo:cardinal;
  dirty:array[0..15] of TRect;
  dCount:integer;
  procedure SetLabel; // submit name as label for OpenGL
 end;

 TGLResourceManager=class(TInterfacedObject,IResourceManager)
  maxTextureSize,maxRTsize,maxRBsize:integer;

  constructor Create;
  destructor Destroy; override;

  function AllocImage(width,height:integer;PixFmt:TImagePixelFormat;
                flags:cardinal;name:TTextureName):TTexture;
  procedure ResizeTexture(var img:TTexture;newWidth,newHeight:integer);
  function Clone(img:TTexture):TTexture;
  procedure FreeImage(var image:TTexture);
  procedure MakeOnline(img:TTexture;stage:integer=0);
  procedure SetTexFilter(img:TTexture;filter:TTexFilter);

  function QueryParams(width,height:integer;format:TImagePixelFormat;usage:integer):boolean;

  // Вспомогательные функции (для отладки/получения инфы)
  function GetStatus(line:byte):string; // Формирует строки статуса

  // Создает дамп использования и распределения видеопамяти
  procedure Dump(st:string='');

 protected
  //CurTag:integer;
  //data:TObject;
  texNames:array[0..3] of cardinal;
  texFilters:array[0..3] of TTexFilter;
  procedure FreeVidMem; // Освободить некоторое кол-во видеопамяти
  procedure FreeMetaTexSpace(n:integer); // Освободить некоторое пространство в указанной метатекстуре
 end;

 var
  resourceManagerGL:TGLResourceManager;

 // Load image from file (TGA or JPG), result is expected in given pixel format or source pixel format
// function LoadFromFile(filename:string;format:TImagePixelFormat=ipfNone):TDxManagedTexture;

implementation
 uses Apus.CrossPlatform, Apus.EventMan, SysUtils, Apus.GfxFormats,
   {$IFDEF MSWINDOWS}dglOpenGl{$ENDIF}
   {$IFDEF LINUX}dglOpenGL{$ENDIF}
   {$IFDEF IOS}gles11,glext{$ENDIF}
   {$IFDEF ANDROID}gles20{$ENDIF}
   ;

{ Принцип работы: по возможности текстуры создаются как обычные
  буферы данных в памяти. По вызову MakeOnline данные перебрасываются
  в текстуры GL. Обычно это происходит непосредственно перед отрисовкой
  (и в потоке отрисовки), т.о. избегаем проблем многопоточности.
}

const
 {$IFDEF GLES11}
 MAX_TEX_SIZE = 1024;
 {$ELSE}
 MAX_TEX_SIZE = 2048;
 {$ENDIF}

var
 mainThreadId:TThreadID;
 cSect:TMyCriticalSection;
 lastErrorTime:int64;
 errorTr:integer;

procedure CheckForGLError(msg:string); inline;
var
 error:cardinal;
 t:int64;
begin
 error:=glGetError;
 if error<>GL_NO_ERROR then try
  t:=MyTickCount;
  if t<lastErrorTime+1000 then inc(errorTr)
   else errorTr:=0;
  if errorTr<5 then begin
   lastErrorTime:=t;
   ForceLogMessage('GLI Error ('+msg+') '+inttostr(error)+' '+GetCallStack);
  end;
 except
 end;
end;

procedure GetGLformat(ipf:TImagePixelFormat;out format,subFormat,internalFormat:cardinal);
begin
 case ipf of
  {$IFNDEF GLES}
  ipf8Bit:begin
   internalFormat:=4;
   format:=GL_COLOR_INDEX;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfRGB:begin
   internalFormat:=GL_RGB;
   format:=GL_BGR;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfARGB:begin
   internalFormat:=GL_RGBA;
   format:=GL_BGRA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfXRGB:begin
   internalFormat:=GL_RGB;
   format:=GL_BGRA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfMono8:begin
   internalFormat:=GL_R8;
   format:=GL_RED;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfMono16:begin
   internalFormat:=GL_R16;
   format:=GL_RED;
   subFormat:=GL_UNSIGNED_SHORT;
  end;
  ipfDuo8:begin
   internalFormat:=GL_RG8;
   format:=GL_RG;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipf565:begin
   internalFormat:=GL_RGB5;
   format:=GL_RGB;
   subFormat:=GL_UNSIGNED_SHORT_5_6_5;
  end;
  ipf1555:begin
   internalFormat:=GL_RGB5;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_5_5_5_1;
  end;
  ipf4444:begin
   internalFormat:=GL_RGBA4;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_4_4_4_4_REV;
  end;
  ipf4444r:begin
   internalFormat:=GL_RGBA4;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_4_4_4_4;
  end;
  ipfDXT1:begin
   internalFormat:=GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
   format:=GL_COMPRESSED_TEXTURE_FORMATS;
  end;
  ipfDXT3:begin
   internalFormat:=GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
   format:=GL_COMPRESSED_TEXTURE_FORMATS;
  end;
  ipfDXT5:begin
   internalFormat:=GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
   format:=GL_COMPRESSED_TEXTURE_FORMATS;
  end;
  ipfA4:begin
   internalFormat:=GL_ALPHA4;
   format:=GL_ALPHA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfL4A4:begin
   internalFormat:=GL_LUMINANCE4_ALPHA4;
   format:=GL_LUMINANCE_ALPHA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfA8:begin
   internalFormat:=GL_ALPHA8;
   format:=GL_ALPHA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  {$ENDIF}
  {$IFDEF GLES}
  ipfARGB:begin
   if pos('TEXTURE_FORMAT_BGRA8888',GLES_Extensions)>0 then begin
    internalFormat:=GL_BGRA;
    format:=GL_BGRA;
   end else begin
    internalFormat:=GL_RGBA;
    format:=GL_RGBA;
   end;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipfRGB:begin
   internalFormat:=GL_RGB;
   format:=GL_RGB;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  ipf565:begin
   internalFormat:=GL_RGB;
   format:=GL_RGB;
   subFormat:=GL_UNSIGNED_SHORT_5_6_5;
  end;
  ipf1555:begin
   internalFormat:=GL_RGBA;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_5_5_5_1;
  end;
  {$IFDEF IOS}
  ipf4444:begin
   internalFormat:=GL_RGBA;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_4_4_4_4_REV;
  end;
  {$ENDIF}
  ipf4444r:begin
   internalFormat:=GL_RGBA;
   format:=GL_RGBA;
   subFormat:=GL_UNSIGNED_SHORT_4_4_4_4;
  end;
  ipfPVRTC:begin
   internalFormat:=GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
   format:=GL_COMPRESSED_TEXTURE_FORMATS;
  end;
  ipfA8:begin
   internalFormat:=GL_ALPHA;
   format:=GL_ALPHA;
   subFormat:=GL_UNSIGNED_BYTE;
  end;
  {$ENDIF}
  else
   raise EError.Create('Unsupported pixel format: '+PixFmt2Str(ipf));
 end;
end;

{ TGLTexture }

procedure TGLTexture.CloneFrom(src: TTexture);
begin
 inherited;
end;

function TGLTexture.Describe: string;
begin
 if self is TGLTexture then
  result:=Format('GLTexture(%8x):%s w=%d h=%d c=%x l=%d o=%d tn=%d fbo=%d dC=%d',
    [cardinal(self),name,width,height,caps,byte(locked),byte(online),texname,fbo,dCount])
 else
  result:='Not a GL Texture at: '+inttohex(cardinal(self),8);
end;

destructor TGLTexture.Destroy;
var
 t:TTexture;
begin
 if texName<>0 then begin
  t:=self;
  resourceManagerGL.FreeImage(t);
 end else
  inherited;
end;

function TGLTexture.GetRawImage: TRawImage;
begin
 result:=TRawImage.Create;
 result.width:=width;
 result.height:=height;
 result.PixelFormat:=PixelFormat;
 result.data:=data;
 result.pitch:=pitch;
 result.paletteFormat:=palNone;
 result.palette:=nil;
 result.palSize:=0;
end;

procedure TGLTexture.Lock(miplevel: byte=0;mode:TlockMode=lmReadWrite;r:PRect=nil);
var
 size:integer;
 lockRect:TRect;
begin
 if (caps and tfNoRead>0) then
   raise EWarning.Create('Can''t lock texture '+name+' for reading');
 if (caps and tfNoWrite>0) and (mode<>lmReadOnly) then
   raise EWarning.Create('Can''t lock texture '+name+' for writing');
 if r=nil then lockRect:=Rect(0,0,(width-1) shr mipLevel,(height-1) shr mipLevel)
  else lockRect:=r^;
 if (mode=lmCustomUpdate) and (r<>nil) then
  raise EWarning.Create('GLI: partial lock with custom update');
 EnterCriticalSection(cSect);
 try
  ASSERT(length(realdata)>0);
  if r=nil then data:=realData
   else data:=@realData[lockRect.left*PixelSize[pixelFormat] shr 3+lockRect.Top*pitch];
  inc(locked);

  if mode=lmReadWrite then begin
   online:=false;
   AddDirtyRect(lockRect);
  end;
 finally
  LeaveCriticalSection(cSect);
 end;
end;

procedure TGLTexture.AddDirtyRect(rect: TRect);
begin
 online:=false;
 if dCount<high(dirty) then begin
  dirty[dCount]:=rect;
  inc(dCount);
 end else begin
  dCount:=1;
  dirty[0]:=Types.Rect(0,0,width-1,height-1);
 end;
end;


procedure TGLTexture.SetAsRenderTarget;
begin
 assert(caps and tfRenderTarget>0);
 {$IFDEF GLES11}
 glBindFramebufferOES(GL_FRAMEBUFFER_OES,fbo);
 {$ENDIF}
 {$IFDEF GLES20}
 glBindFramebuffer(GL_FRAMEBUFFER,fbo);
 {$ENDIF}
 {$IFNDEF GLES}
 if GL_ARB_framebuffer_object then
  glBindFramebuffer(GL_FRAMEBUFFER,fbo)
 else if GL_EXT_framebuffer_object then
  glBindFramebufferEXT(GL_FRAMEBUFFER,fbo)
 else
  raise EError.Create('SART: Render target not supported');
 {$ENDIF}
 CheckForGLError('SART:'+Describe);
end;

procedure TGLTexture.SetFilter(allowInterpolation: boolean);
 begin
  if texname=0 then exit;
  if allowInterpolation then begin
   if HasFlag(tfPixelated) then exit;
   caps:=caps or tfPixelated;
   glActiveTexture(GL_TEXTURE0+9);
   glBindTexture(GL_TEXTURE_2D,texname);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
  end else begin
   if not HasFlag(tfPixelated) then exit;
   caps:=caps and not tfPixelated;
   glActiveTexture(GL_TEXTURE0+9);
   glBindTexture(GL_TEXTURE_2D,texname);
   if mipmaps>0 then
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR)
   else
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  end;
 end;

procedure TGLTexture.SetLabel;
var
 lab:String8;
begin
 if @glObjectLabel<>nil then begin
  lab:=name;
  glObjectLabel(GL_TEXTURE,texname,length(lab),@lab[1]);
 end;
end;

procedure TGLTexture.Unlock;
begin
 EnterCriticalSection(cSect);
 try
  ASSERT(locked>0,'Texture not locked: '+name);
  dec(locked);
 finally
  LeaveCriticalSection(cSect);
 end;
end;

procedure EventHandler(event:TEventStr;tag:TTag);
var
 tex:TTexture;
begin
 if SameText(event,'GLImages\DeleteTexture') then begin
  tex:=TTexture(UIntPtr(tag));
  resourceManagerGL.FreeImage(tex);
 end;
end;

{ TGLResourceManager }

function TGLResourceManager.AllocImage(width, height: integer; PixFmt: TImagePixelFormat; Flags: cardinal;
  name: TTextureName): TTexture;
var
 tex:TGlTexture;
 status:cardinal;
 format,SubFormat,internalFormat:cardinal;
 dataSize:integer;
 renderBuffer:GLUint;
 drawBuffers:GLenum;
 prevFramebuffer:GLint;
begin
 ASSERT((width>0) AND (height>0),'Zero width or height: '+name);
 ASSERT((pixFmt<>ipfNone) or HasFlag(flags,aiDepthBuffer),'Invalid pixel format for '+name);
 if (flags and aiSysMem=0) and ((width>maxTextureSize) or (height>maxTextureSize)) then raise EWarning.Create('AI: Texture too large');
 try
 EnterCriticalSection(cSect);
 try
 tex:=TGLTexture.Create;
 result:=tex;
 tex.rbo:=0;
 tex.fbo:=0;
 tex.left:=0;
 tex.top:=0;
 tex.width:=width;
 tex.height:=height;
 if (flags and aiPow2>0) {$IFNDEF GLES} or
     not GL_ARB_texture_non_power_of_two {$ENDIF} then begin
  width:=GetPow2(width);
  height:=GetPow2(height);
 end;
 tex.realwidth:=width;
 tex.realHeight:=height;
 tex.name:=name;
 tex.PixelFormat:=PixFmt;
 tex.caps:=0;
 tex.online:=false;
 tex.texname:=0;
 tex.filter:=fltUndefined;
// sx:=1; sy:=1;
// if flags and aiWriteOnly>0 then

 if flags and aiRenderTarget>0 then begin
  LogMessage(sysUtils.Format('AllocImage RT %dx%d %d (%s)',[width,height,flags,name]));
  if max2(width,height)>maxRTsize then raise EWarning.Create('AI: RT texture too large');
  {$IFDEF GLES}
  {$IFDEF GLES11}
  width:=GetPow2(width);
  height:=GetPow2(height);
  glGenFramebuffersOES(1,@tex.fbo);
  glBindFramebufferOES(GL_FRAMEBUFFER_OES,tex.fbo);
  {$ELSE}
  glGenFramebuffers(1,@tex.fbo);
  glBindFramebuffer(GL_FRAMEBUFFER,tex.fbo);
  {$ENDIF}
  glGenTextures(1,@tex.texname);
  glBindTexture(GL_TEXTURE_2D,tex.texname);
  tex.SetLabel;
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  tex.filter:=fltBilinear;
  GetGLFormat(PixFmt,format,subFormat,internalFormat);
  glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,format,subFormat,nil);
  {$IFDEF GLES11}
  glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES,GL_COLOR_ATTACHMENT0_OES,GL_TEXTURE_2D,tex.texname,0);
  status:=glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
  if status<>GL_FRAMEBUFFER_COMPLETE_OES then
   raise EError.Create('FBO status: '+inttostr(status));
  {$ELSE}
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,zTex.texname,0);
  status:=glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if status<>GL_FRAMEBUFFER_COMPLETE then
   raise EError.Create('FBO status: '+inttostr(status));
  {$ENDIF}

  {$ENDIF GLES}

  {$IFNDEF GLES}
  // Standard way: use FBO
  glGenFramebuffers(1,@tex.fbo);
  CheckForGLError('1');
  // Save current framebuffer
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,@prevFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER,tex.fbo);
  CheckForGLError('2');
  glGenTextures(1,@tex.texname);
  glBindTexture(GL_TEXTURE_2D,tex.texname);
  CheckForGLError('3');
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  tex.filter:=fltBilinear;
  if HasFlag(flags,aiClampUV) then begin
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
   tex.caps:=tex.caps or tfClamped;
  end;
  if (pixFmt=ipfNone) and HasFlag(flags,aiDepthBuffer) then begin
   // No pixel format, but need depth buffer: allocate depth texture only
   glTexImage2D(GL_TEXTURE_2D,0,GL_DEPTH_COMPONENT,width,height,0,GL_DEPTH_COMPONENT,GL_FLOAT,nil);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_COMPARE_MODE,GL_COMPARE_REF_TO_TEXTURE); // enable comparison mode
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_COMPARE_FUNC,GL_LESS); // enable comparison mode

   glFramebufferTexture2D(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_TEXTURE_2D,tex.texname,0);
   glDrawBuffer(GL_NONE);
   glReadBuffer(GL_NONE);
  end else begin
   GetGLFormat(PixFmt,format,subFormat,internalFormat);
   glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,format,subFormat,nil);
   CheckForGLError('4');
   glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex.texname,0);

   if HasFlag(flags,aiDepthBuffer) then begin
    glGenRenderbuffers(1,@renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, width, height);
    glFramebufferRenderBuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer);
    tex.rbo:=renderBuffer;
   end;
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
  end;

  status:=glCheckFramebufferStatus(GL_FRAMEBUFFER);
  // Restore previous framebuffer
  glBindFramebuffer(GL_FRAMEBUFFER,prevFramebuffer);

  if status<>GL_FRAMEBUFFER_COMPLETE then
   raise EError.Create('FBO status: '+inttostr(status));

  {$ENDIF}
  tex.caps:=tex.caps or (tfRenderTarget+tfNoRead+tfNoWrite);
  tex.online:=true;
 end else begin
  // Not render target -> NO ANY GL* CALLS TO ALLOW MULTITHREADED ALLOCATION
  tex.pitch:=width*pixelSize[pixFmt] div 8;
  datasize:=tex.pitch*height;
  if pixFMT in [ipfDXT1,ipfDXT3,ipfDXT5] then begin
   tex.pitch:=tex.pitch div 4;
   datasize:=datasize div 16;
  end;
  SetLength(tex.realData,datasize);

  tex.caps:=tex.caps or tfDirectAccess; // Can be locked
  if flags and aiClampUV>0 then
   tex.caps:=tex.caps or tfClamped;
  // Mip-maps
  if flags and aiMipMapping>0 then
   tex.caps:=tex.caps or tfAutoMipMap;
 end;

 tex.u1:=0; tex.u2:=tex.width/width;
 tex.v1:=0; tex.v2:=tex.height/height;
 tex.stepU:=0.5*(tex.u2-tex.u1)/tex.width;
 tex.stepV:=0.5*(tex.v2-tex.v1)/tex.height;
 finally LeaveCriticalSection(cSect);
 end;
 except
  on e:Exception do begin
   if tex<>nil then tex.Free;
   result:=nil;
   LogMessage('AllocImage error: '+ExceptionMsg(e));
   raise;
  end;
 end;
end;

function TGLResourceManager.Clone(img:TTexture):TTexture;
var
 res,src:TGLTexture;
begin
 ASSERT(img is TGLTexture);
 src:=TGLTexture(img);

 res:=TGLTexture.Create;
 res.CloneFrom(img);
 res.texname:=src.texname;
 res.realWidth:=src.realWidth;
 res.realHeight:=src.realHeight;
 res.filter:=src.filter;
 res.online:=src.online;
 // Мда... И как тут сделать ссылку на данные!?
 result:=res;
end;

constructor TGLResourceManager.Create;
var
 maxFBwidth,maxFBheight:integer;
begin
 try
  resourceManagerGL:=self;
  _AddRef;

  glPixelStorei(GL_UNPACK_ALIGNMENT,1);
  ZeroMem(texNames,sizeof(texnames));
  mainThreadID:=GetCurrentThreadId;
  resourceManagerGL:=self;
  SetEventHandler('GLImages',EventHandler,emMixed);
  {$IFDEF GLES}
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @maxTextureSize);
  maxFBWidth:=maxTextureSize;
  maxFBheight:=maxTextureSize;
  maxRBsize:=maxTextureSize;
  {$ELSE}
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @maxTextureSize);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_WIDTH, @maxFBwidth);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_HEIGHT, @maxFBheight);
  glGetIntegerv(GL_MAX_RENDERBUFFER_SIZE, @maxRBsize);
  {$ENDIF}
  maxRTsize:=min2(maxFBwidth,maxFBheight);
  LogMessage(Format('Maximal sizes: TEX: %d / FB: %d x %d / RB: %d',[maxTextureSize,maxFBwidth,maxFBheight,maxRBsize]));
  if maxFBwidth=0 then maxFBwidth:=Max2(maxRBsize,1024);
  if maxFBheight=0 then maxFBheight:=Max2(maxRBsize,1024);
 except
  on e:Exception do begin
   ForceLogMessage('Error in GLTexMan constructor: '+ExceptionMsg(e));
   raise EFatalError.Create('GLTextMan: '+ExceptionMsg(e));
  end;
 end;
end;

destructor TGLResourceManager.Destroy;
begin
 resourceManagerGL:=nil;
 inherited;
end;

procedure TGLResourceManager.Dump(st: string);
begin

end;

procedure TGLResourceManager.FreeImage(var image: TTexture);
var
 tex:TGLTexture;
begin
 if image=nil then exit;
 // Wrong thread?
 if GetCurrentThreadID<>mainThreadID then begin
  if not (image is TGLTexture) then raise EError.Create('Not a GLTexture! '+IntToHEx(cardinal(image),8));
  Signal('GLIMAGES\DeleteTexture',cardinal(image));
  image:=nil;
  exit;
 end;
 EnterCriticalSection(cSect);
 try

 dec(image.refCounter);
 if image.refCounter>=0 then begin
  image:=nil;
  exit; // prevent deletion
 end;

 if image.parent<>nil then FreeImage(image.parent);

 if image is TGLTexture then begin
  tex:=image as TGLTexture;
  if tex.fbo<>0 then begin // free framebuffer
   {$IFDEF GLES11}
   glDeleteFramebuffersOES(1,@tex.fbo);
   {$ENDIF}
   {$IFDEF GLES20}
   glDeleteFramebuffers(1,@tex.fbo)
   {$ENDIF}
   {$IFNDEF GLES}
   if GL_ARB_framebuffer_object then
    glDeleteFramebuffers(1,@tex.fbo)
   else
   if GL_EXT_framebuffer_object then
    glDeleteFramebuffersExt(1,@tex.fbo)
   else
    raise EError.Create('TexMan FI: framebuffers not supported!');
   {$ENDIF}
  end;
  if tex.rbo<>0 then glDeleteRenderbuffers(1,@tex.rbo);
  tex.rbo:=0;
  if tex.texname<>0 then glDeleteTextures(1,@tex.texname);
  tex.texname:=0;
  if Length(tex.realData)>0 then SetLength(tex.realData,0);
  tex.Free;
  image:=nil;
 end else
  raise EWarning.Create('FI: not a GL texture');
 finally
  LeaveCriticalSection(cSect);
 end;
end;

procedure TGLResourceManager.FreeMetaTexSpace(n: integer);
begin

end;

procedure TGLResourceManager.FreeVidMem;
begin

end;

function TGLResourceManager.GetStatus(line: byte): string;
begin

end;

procedure TGLResourceManager.SetTexFilter(img:TTexture;filter:TTexFilter);
var
  flt:cardinal;
begin
 case filter of
  fltNearest:flt:=GL_NEAREST;
  fltBilinear:flt:=GL_LINEAR;
  fltTrilinear:flt:=GL_LINEAR_MIPMAP_LINEAR;
  fltAnisotropic:flt:=GL_LINEAR_MIPMAP_LINEAR;
  fltUndefined:flt:=GL_NEAREST;
 end;
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,flt);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,flt);
 TGlTexture(img).filter:=filter;
end;

procedure TGLResourceManager.MakeOnline(img: TTexture;stage:integer=0);
var
 format,subformat,internalFormat,error:cardinal;
 needInit:boolean;
 i,bpp:integer;

 procedure ConvertColors32(buf:PCardinal;count:integer);
  var
   c:cardinal;
  begin
   while count>0 do begin
    c:=buf^;
    buf^:=c and $FF00FF00+(c and $FF) shl 16+(c and $FF0000) shr 16;
    inc(buf);
    dec(count);
   end;
  end;

 procedure ConvertColors24(buf:PByte;count:integer);
  var
   pb:PByte;
   b:byte;
  begin
   pb:=buf; inc(pb,2);
   while count>0 do begin
    b:=pb^;
    pb^:=buf^;
    buf^:=b;
    inc(buf,3);
    inc(pb,3);
    dec(count);
   end;
  end;

begin
 EnterCriticalSection(cSect);
 try
 if img=nil then begin
  texNames[stage]:=0;
  exit;
 end;
 glActiveTexture(GL_TEXTURE0+stage);
 needInit:=false;
 with img as TGLTexture do begin
  if locked>0 then raise EWarning.Create('MO for a locked texture: '+img.name);
  if texname=0 then begin // allocate texture name
   glGenTextures(1,@texname);
   CheckForGLError('11');
   glBindTexture(GL_TEXTURE_2D, texname);
   SetLabel;
   CheckForGLError('12');
   texNames[stage]:=texname;
   needInit:=true;
  end else
   if texNames[stage]<>texname then begin
    glBindTexture(GL_TEXTURE_2D, texname);
    texNames[stage]:=texname;
   end;
  if online then exit; // already online

  // Upload texture data
  GetGLFormat(PixelFormat,format,subFormat,internalFormat);

  if format=GL_COMPRESSED_TEXTURE_FORMATS then
   glCompressedTexImage2D(GL_TEXTURE_2D,0,internalFormat,realwidth,realheight,0,length(realData),realData)
  else begin
   {$IFNDEF GLES}
   if needInit then begin // Specify texture size and pixel format
    glTexImage2D(GL_TEXTURE_2D,0,internalFormat,realwidth,realheight,0,format,subFormat,nil);
    if HasFlag(tfPixelated) then begin
     glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
     glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
    end else begin
     glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
     glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    end;
   end;
   CheckForGLError('13');
    // Upload texture data
   glPixelStorei(GL_UNPACK_ROW_LENGTH,realWidth);
   CheckForGLError('14');
   bpp:=pixelSize[pixelFormat] div 8;
   for i:=0 to dCount-1 do
    with dirty[i] do
     glTexSubImage2D(GL_TEXTURE_2D,0,Left,Top,right-left+1,bottom-top+1,
        format,subFormat,@realData[(left+top*realWidth)*bpp]);
   CheckForGLError('15');
   {$ELSE}
   // GLES doesn't support UNPACK_ROW_LENGTH so it's not possible to upload just a portion of
   // the source texture data
   if format=GL_RGBA then ConvertColors32(data,realwidth*realheight);
   if format=GL_RGB then ConvertColors24(data,realwidth*realheight);
//   ForceLogMessage(SysUtils.Format('TexImage2D %d %d %d %d %d',[internalFormat,realwidth,realheight,format,subformat]));
   glTexImage2D(GL_TEXTURE_2D,0,internalFormat,realwidth,realheight,0,format,subFormat,data);
   CheckForGLError('16');
   {$ENDIF}
   if HasFlag(tfAutoMipMap) and (GL_VERSION_3_0 or GL_ARB_framebuffer_object) then begin
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
   end;

   if caps and tfClamped>0 then begin
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
   end else begin
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
   end;
   CheckForGLError('17');
   dCount:=0;
  end;
  online:=true;
 end;
 finally
  LeaveCriticalSection(cSect);
 end;
end;

function TGLResourceManager.QueryParams(width, height: integer;
  format: TImagePixelFormat; usage: integer): boolean;
var
 res:integer;
 glFormat,subFormat,InternalFormat:cardinal;
begin
 result:=true;
 if not (format in [ipfARGB,ipfRGB,ipf1555,ipf4444,ipf565]) then begin
  result:=false;
  exit;
 end;
 if (width>MAX_TEX_SIZE) or (height>MAX_TEX_SIZE) then begin
  result:=false;
  exit;
 end;
 {$IFNDEF GLES}
 GetGLFormat(format,glFormat,subFormat,internalFormat);
 glTexImage2D(GL_PROXY_TEXTURE_2D,0,internalFormat,width,height,0,glFormat,subFormat,nil);
 glGetTexLevelParameteriv(GL_PROXY_TEXTURE_2D,0,GL_TEXTURE_INTERNAL_FORMAT,@res);
 CheckForGLError('18');
 if res=0 then result:=false;
 {$ENDIF}
end;

procedure TGLResourceManager.ResizeTexture(var img: TTexture; newWidth,
  newHeight: integer);
var
 glFormat,subFormat,internalFormat:cardinal;
 old:TTexture;
begin
 if img.caps and tfRenderTarget>0 then
  with img as TGLTexture do begin
   glBindTexture(GL_TEXTURE_2D, texname);
   GetGLFormat(img.PixelFormat,glFormat,subFormat,internalFormat);
   width:=newWidth;
   height:=newHeight;
   glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,glFormat,subFormat,nil);
   CheckForGLError('19');
   if rbo<>0 then begin
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, width, height);
   end;
   exit;
  end;
  // Delete and allocate again
  old:=img;
  img:=AllocImage(newWidth,newHeight,img.PixelFormat,img.caps,img.name);
  FreeImage(old);
end;

begin
 InitCritSect(cSect,'GLTexMan',160);
end.
