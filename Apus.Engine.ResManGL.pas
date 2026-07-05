// OpenGL-based texture classes and texture manager
//
// Copyright (C) 2011 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$I defines.inc}
unit Apus.Engine.ResManGL;
interface
 uses Apus.Engine.API, Apus.Images, Apus.Core, Types, Apus.Engine.Resources, Apus.Threads, SyncObjs;
type
 // OpenGL texture object with CPU-side storage and upload/sync helpers.
 // Managed by TGLResourceManager, can also represent RT/depth/array layers.
 // Текстура OpenGL
 TGLTexture=class(TTexture)
 const
  MAX_LEVEL = 5;  // maximal number of supported mip level [0..MAX_LEVEL]
 var
  texname:cardinal;
  realWidth,realHeight:integer; // real dimensions of underlying texture object (can be larger than requested)
  filter:TTexFilter;
  constructor Create;
  procedure Clear(color:cardinal=$808080); override;
  destructor Destroy; override;
  procedure ClearPart(mipLevel:byte;x,y,width,height:integer;color:cardinal); override;
  procedure CloneFrom(src:TTexture); override;
  procedure MakeImmutable; override;
  procedure SetAsRenderTarget; virtual;
  procedure Lock(miplevel:byte=0;mode:TlockMode=lmReadWrite;r:PRect=nil); override; // 0-й уровень - самый верхний
  procedure AddDirtyRect(rect:TRect;level:integer); override;
  procedure Unlock; override;
  function GetRawImage:TRawImage; override; // Создать RAW image и назначить его на верхний уровень текстуры (только когда текстура залочна!!!)
  function Describe:string;
  procedure SetFilter(filter:TTexFilter); override;
  procedure Dump(filename:string8=''); override;
  function GetLayer(layer:integer):TTexture; override;
  procedure LockLayer(index:integer;miplevel:byte=0;mode:TLockMode=lmReadWrite;r:PRect=nil); override;
  // Direct upload - destroys internal storage
  procedure Upload(pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); override;
  procedure Upload(mipLevel:byte;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); override;
  procedure UploadPart(mipLevel:byte;x,y,width,height:integer;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); override;

 protected
 type
  TUploadRequest=record
   data:pointer;
   pitch:integer;
   mipLevel:integer;
   pf:TImagePixelFormat;
   x,y,width,height:integer;
  end;
 var
  cs:TCriticalSection;
  // RW-lock for multi-window access to shared mutable textures.
  // OS-assisted (SRWLock on Windows, pthread_rwlock_t on Linux) — no busy-wait.
  // Only used when NeedSyncForRead/Write returns true (multiWindowMode=true).
  rwLock:TRWLock;
  ownerThread:TThreadIdent; // for tfThreadLocal: thread that owns this texture (debug checks)
  online:boolean; // true when image data is uploaded and ready to use (uv's are valid), false when local image data was modified and should be uploaded
  realData:array[0..MAX_LEVEL] of ByteArray; // internal storage of texture data
  fbo:cardinal; // framebuffer object (for a render target texture)
  rbo:cardinal; // renderbuffer object - for a render target texture with a depth buffer attached (but not for depth buffer textures)
  // Define area of the internal storage which is recently updated and need to be uploaded
  dirty:array[0..MAX_LEVEL,0..15] of TRect;
  dCount:array[0..MAX_LEVEL] of integer; // per each mip level
  // Which levels of internal storage are obsolete
  realDataObsolete:array[0..MAX_LEVEL] of boolean;
  // upload request
  uploadRequest:TUploadRequest;
  // RW-lock protocol: acquire before modifying texture data, release after
  procedure BeginRead; // shared read lock (many concurrent readers allowed)
  procedure EndRead;
  procedure BeginWrite; // exclusive write lock (blocks until all readers done)
  procedure EndWrite;
  procedure SetLabel; // submit name as label for OpenGL
  procedure UpdateFilter;
  procedure InitStorage; virtual; // allocate GL texture object (if needed)
  procedure UploadInternalData; virtual; // upload modified internal storage data (using dirty rects)
  procedure FreeData; virtual;
  procedure Bind; virtual;
  function IsBound(stage:integer):boolean; virtual;
  function GetTextureTarget:integer; virtual;
  procedure InvalidateInternalLevel(mipLevel:integer); virtual;
  // Download texture data into the internal storage
  procedure DownloadLevel(mipLevel:integer); virtual;
  procedure ProcessUploadRequest; virtual;
  procedure EnsureWritable(opName:string8); inline;
 end;

 // OpenGL-backed vertex buffer wrapper.
 // Created/freed by TGLResourceManager and used by renderDevice.
 TVertexBufferGL=class(TVertexBuffer)
  procedure Upload(fromVertex,numVertices:integer;vertexData:pointer); override;
  destructor Destroy; override;
  procedure Resize(newCount:integer); override;
  procedure PublishUpdate; override;
  procedure WaitForPublish; override;
  procedure ResetPublishState; override;
 protected
  buffer:cardinal;
  usage:cardinal;
  publishedSync:pointer;
 end;

 // OpenGL-backed index buffer wrapper.
 // Created/freed by TGLResourceManager and used by renderDevice.
 TIndexBufferGL=class(TIndexBuffer)
  procedure Upload(fromIndex,numIndices:integer;indexData:pointer); override;
  destructor Destroy; override;
  procedure Resize(newCount:integer); override;
  procedure PublishUpdate; override;
  procedure WaitForPublish; override;
  procedure ResetPublishState; override;
 protected
  buffer:cardinal;
  usage:cardinal;
  publishedSync:pointer;
 end;

 // Texture array/3D-texture adapter over TGLTexture.
 // Exposes per-layer lock/upload while sharing one GL object.
 // Used for both 2D texture arrays and 3D textures
 TGLTextureArray=class(TGLTexture)
  constructor Create(numLayers:integer);
  procedure MakeImmutable; override;
  function GetLayer(layer:integer):TTexture; override;
  procedure LockLayer(index:integer;miplevel:byte=0;mode:TLockMode=lmReadWrite;r:PRect=nil); override;
  procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;r:PRect=nil); overload; override; // treat mip level as array index for convenience
  procedure AddDirtyRect(index:integer;rect:TRect); overload; virtual;
  procedure Unlock; override;
  procedure Dump(filename:string8=''); override;
 protected
  layers:array of TGLTexture; // fake texture objects used to
  lockedLayer:integer;
  procedure FreeData; override;
  procedure UploadInternalData; override;
  function GetTextureTarget:integer; override;
 end;

 // Central OpenGL resource owner: textures, buffers, RT attachments.
 // Implements IResourceManager and owns most GL objects (textures, FBO/RBO, VBO/IBO).
 // Must be shut down while GL context is still current.
 TGLResourceManager=class(TInterfacedObject,IResourceManager)
  maxTextureSize,maxRTsize,maxRBsize:integer;

  constructor Create;
  destructor Destroy; override;

  function AllocImage(width,height:integer;PixFmt:TImagePixelFormat;
                flags:cardinal;name:String8):TTexture; overload;
  function AllocImage(width,height,mipLevels:integer;PixFmt:TImagePixelFormat;
     flags:cardinal;name:String8):TTexture; overload;
  procedure ResizeImage(var img:TTexture;newWidth,newHeight:integer);
  function Clone(img:TTexture):TTexture;
  function Copy(img:TTexture):TTexture;
  procedure AttachDepthBuffer(tex:TTexture;dBuf:TTexture);
  procedure FreeImage(var image:TTexture);


  // Allocate texture array
  function AllocArray(width,height:integer;PixFmt:TImagePixelFormat;
                arraySize:integer;flags:cardinal;name:String8):TGLTextureArray;

  procedure MakeOnline(img:TTexture;stage:integer=0);
  procedure SetTexFilter(img:TTexture;filter:TTexFilter);

  function QueryParams(width,height:integer;format:TImagePixelFormat;usage:integer):boolean;

  // Вспомогательные функции (для отладки/получения инфы)
  function GetStatus(line:byte):string; // Формирует строки статуса

  // Создает дамп использования и распределения видеопамяти
  procedure Dump(st:string='');

  // Data buffers
  function AllocVertexBuffer(layout:TVertexLayout;numVertices:integer;
    usage:TBufferUsage=buStatic;flags:cardinal=0):TVertexBuffer;
  function AllocRawVertexBuffer(strideBytes,numVertices:integer;
    usage:TBufferUsage=buStatic;flags:cardinal=0):TVertexBuffer;
  procedure UseVertexBuffer(vb:TVertexBuffer);
  function AllocIndexBuffer(indCount:integer;elementSize:integer=2;
    usage:TBufferUsage=buStatic;flags:cardinal=0):TIndexBuffer;
  procedure UseIndexBuffer(ib:TIndexBuffer);
  procedure FreeBuffer(buf:TEngineBuffer);

 protected
  //CurTag:integer;
  //data:TObject;
  //texFilters:array[0..15] of TTexFilter;
  procedure FreeVidMem; // Освободить некоторое кол-во видеопамяти
  procedure FreeMetaTexSpace(n:integer); // Освободить некоторое пространство в указанной метатекстуре
  procedure AllocRenderTarget(tex:TGLTexture;flags:cardinal);
 end;

 var
  resourceManagerGL:TGLResourceManager;

 // Load image from file (TGA or JPG), result is expected in given pixel format or source pixel format
// function LoadFromFile(filename:string;format:TImagePixelFormat=ipfNone):TDxManagedTexture;

 {$IFDEF GLES}
 // GLES has no reliable BGRA texture/readback format: swap R/B on CPU instead.
 // Shared with Apus.Engine.OpenGL (backbuffer readback).
 procedure SwapRedBlue8888(data:pointer;pixelCount:integer);
 {$ENDIF}

implementation
 uses Apus.EventMan, Apus.Lib, SysUtils, TypInfo, Apus.GfxFormats,
   {$IFDEF DGL}dglOpenGL{$ENDIF}
   {$IFDEF GLES}dglOpenGLES{$ENDIF}
   ,
  Apus.Classes,
  Apus.Conv,
  Apus.Engine.RobotAPI,
  Apus.Files,
  Apus.Engine.Graphics,
  Apus.Log;

{ Принцип работы: по возможности текстуры создаются как обычные
  буферы данных в памяти. По вызову MakeOnline данные перебрасываются
  в текстуры GL. Обычно это происходит непосредственно перед отрисовкой
  (и в потоке отрисовки), т.о. избегаем проблем многопоточности.
}

const
 MAX_TEX_SIZE = 2048;

var
 mainThreadId:TThreadIdent;
 cSect:TLock; // TODO: зачем? Нет глобальных данных, нуждающихся в защите
 lastErrorTime:int64;
 errorTr:integer;

 activeTex:integer; // currently active texture unit
 boundTex2D:array[0..15] of TTexture; // current texture bound
 boundTex3D:array[0..15] of TTexture;
 boundTex2D_Arr:array[0..15] of TTexture;

{$REGION UTILS}
function InMainThread:boolean; inline;
begin
 result:=GetCurrentThreadID=mainThreadID;
end;

procedure TrackArrayBufferBinding(buffer:cardinal); inline;
 var
  tracker:IRenderDeviceBindTracking;
 begin
  if (renderDevice<>nil) and Supports(renderDevice,IRenderDeviceBindTracking,tracker) then
   tracker.TrackArrayBufferBinding(buffer);
 end;

procedure TrackElementBufferBinding(buffer:cardinal); inline;
 var
  tracker:IRenderDeviceBindTracking;
 begin
  if (renderDevice<>nil) and Supports(renderDevice,IRenderDeviceBindTracking,tracker) then
   tracker.TrackElementBufferBinding(buffer);
 end;

procedure SetGLObjectLabel(identifier,name:cardinal;const labelText:String8); inline;
begin
 // Stage 7: labeling is best-effort, never required for rendering correctness.
 {$IFDEF GLES}
 // Core glObjectLabel doesn't exist in ES 3.0; only the GL_KHR_debug extension form does.
 if (name<>0) and (labelText<>'') and (@glObjectLabelKHR<>nil) then
  glObjectLabelKHR(identifier,name,length(labelText),@labelText[1]);
 {$ELSE}
 if (name<>0) and (labelText<>'') and (@glObjectLabel<>nil) then
  glObjectLabel(identifier,name,length(labelText),@labelText[1]);
 {$ENDIF}
end;

function ShortGLLabel(const preferred,prefix:String8;id:cardinal;maxLen:integer=12):String8; inline;
 begin
  if preferred<>'' then
   result:=preferred
  else
   result:=prefix+IntToStr(id);
  if length(result)>maxLen then
   result:=copy(result,1,maxLen);
 end;

function BuildVBLabel(vb:TVertexBufferGL):String8; inline;
 begin
  result:=ShortGLLabel(vb.debugName,'vb',vb.buffer,12);
 end;

function BuildIBLabel(ib:TIndexBufferGL):String8; inline;
 begin
  result:=ShortGLLabel(ib.debugName,'ib',ib.buffer,12);
 end;


procedure ActiveTextureUnit(u:integer);
 begin
  ASSERT((u>=0) and (u<16));
  glActiveTexture(GL_TEXTURE0+u);
  activeTex:=u;
 end;

procedure UnbindTex(tex:TTexture);
 var
  i:integer;
 begin
  for i:=0 to high(boundTex2D) do
   if boundTex2D[i]=tex then boundTex2D[i]:=nil;
  for i:=0 to high(boundTex3D) do
   if boundTex3D[i]=tex then boundTex3D[i]:=nil;
  for i:=0 to high(boundTex2D_Arr) do
   if boundTex2D_Arr[i]=tex then boundTex2D_Arr[i]:=nil;
 end;

var
 saveActiveTex:GLInt=-1;
procedure SaveActiveTexture;
 begin
  ASSERT(saveActiveTex=-1);
  glGetIntegerv(GL_ACTIVE_TEXTURE,@saveActiveTex);
  if saveActiveTex<>GL_TEXTURE0+9 then ActiveTextureUnit(9);
 end;

procedure RestoreActiveTexture;
 begin
  ASSERT(saveActiveTex<>-1);
  if saveActiveTex<>GL_TEXTURE0+9 then ActiveTextureUnit(saveActiveTex-GL_TEXTURE0);
  saveActiveTex:=-1;
 end;

procedure CheckForGLError(msg:string); //inline;
var
 error:cardinal;
 t:int64;
begin
 error:=glGetError;
 if error<>GL_NO_ERROR then {try
  t:=CoreTime.Ticks;
  if t<lastErrorTime+1000 then inc(errorTr)
   else errorTr:=0;
  if errorTr<5 then begin
   lastErrorTime:=t;
   Log.Force('GLI Error ('+msg+') '+inttostr(error)+' '+GetCallStack);
  end else}
   raise EError.Create('GLI Error ('+msg+') '+inttostr(error));
{ except
 end;}
end;

{$IFDEF GLES}
// glGetTexImage doesn't exist in GLES: read back through a scratch FBO instead.
// Unoptimized (allocates/frees an FBO per call) - only used by Dump/DownloadLevel debug paths.
procedure GLESReadTexImage(target:cardinal;texName:cardinal;level:integer;width,height:integer;
   format,dataType:cardinal;dest:pointer;layer:integer=0);
 var
  fbo:cardinal;
  prevFBO:integer;
 begin
  glGetIntegerv(GL_FRAMEBUFFER_BINDING,@prevFBO); // don't disturb the render-target state tracking
  glGenFramebuffers(1,@fbo);
  glBindFramebuffer(GL_FRAMEBUFFER,fbo);
  if (target=GL_TEXTURE_2D_ARRAY) or (target=GL_TEXTURE_3D) then
   glFramebufferTextureLayer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,texName,level,layer)
  else
   glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,target,texName,level);
  glReadPixels(0,0,width,height,format,dataType,dest);
  glBindFramebuffer(GL_FRAMEBUFFER,cardinal(prevFBO));
  glDeleteFramebuffers(1,@fbo);
 end;

// GLES has no reliable BGRA readback format: read as RGBA then swap R/B on CPU.
procedure SwapRedBlue8888(data:pointer;pixelCount:integer);
 var
  p:PByteArray;
  i:integer;
  b:byte;
 begin
  p:=data;
  for i:=0 to pixelCount-1 do begin
   b:=p[i*4];
   p[i*4]:=p[i*4+2];
   p[i*4+2]:=b;
  end;
 end;

// ipfARGB/ipfXRGB source data is B,G,R,A in memory but uploaded as GL_RGBA under
// GLES (no BGRA texture format there): swap into a scratch copy before upload.
// TODO: swizzle - use GL_TEXTURE_SWIZZLE_* instead of a per-upload CPU copy where supported.
function BGRAToRGBACopy(src:pointer;pixelCount:integer):pointer;
 begin
  GetMem(result,pixelCount*4);
  Move(src^,result^,pixelCount*4);
  SwapRedBlue8888(result,pixelCount);
 end;
{$ENDIF}

procedure GetGLformat(ipf:TImagePixelFormat;out format,dataType,internalFormat:cardinal);
begin
 case ipf of
  {$IFNDEF GLES}
  ipf8Bit:begin
   internalFormat:=4;
   format:=GL_COLOR_INDEX;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfRGB:begin
   internalFormat:=GL_RGB8;
   format:=GL_BGR;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfARGB:begin
   internalFormat:=GL_RGBA8;
   format:=GL_BGRA;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfXRGB:begin
   internalFormat:=GL_RGB8;
   format:=GL_BGRA;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfMono8:begin
   internalFormat:=GL_R8;
   format:=GL_RED;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfMono8u:begin
   internalFormat:=GL_R8UI;
   format:=GL_RED_INTEGER;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfMono16:begin
   internalFormat:=GL_R16;
   format:=GL_RED;
   dataType:=GL_UNSIGNED_SHORT;
  end;
  ipfMono16s:begin
   internalFormat:=GL_R16_SNORM;
   format:=GL_RED;
   dataType:=GL_SHORT;
  end;
  ipfMono16i:begin
   internalFormat:=GL_R16I;
   format:=GL_RED_INTEGER;
   dataType:=GL_SHORT;
  end;
  ipfMono32f:begin
   internalFormat:=GL_R32F;
   format:=GL_RED;
   dataType:=GL_FLOAT;
  end;
  ipfDuo32f:begin
   internalFormat:=GL_RG32F;
   format:=GL_RG;
   dataType:=GL_FLOAT;
  end;
  ipfQuad32f:begin
   internalFormat:=GL_RGBA32F;
   format:=GL_RGBA;
   dataType:=GL_FLOAT;
  end;
  ipfDuo8:begin
   internalFormat:=GL_RG8;
   format:=GL_RG;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipf565:begin
   internalFormat:=GL_RGB5;
   format:=GL_RGB;
   dataType:=GL_UNSIGNED_SHORT_5_6_5;
  end;
  ipf1555:begin
   internalFormat:=GL_RGB5_A1;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_SHORT_5_5_5_1;
  end;
  ipf4444:begin
   internalFormat:=GL_RGBA4;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_SHORT_4_4_4_4_REV;
  end;
  ipf4444r:begin
   internalFormat:=GL_RGBA4;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_SHORT_4_4_4_4;
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
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfL4A4:begin
   internalFormat:=GL_LUMINANCE4_ALPHA4;
   format:=GL_LUMINANCE_ALPHA;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfA8:begin
   internalFormat:=GL_ALPHA8;
   format:=GL_ALPHA;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfDepth32f:begin
   internalFormat:=GL_DEPTH_COMPONENT;
   format:=GL_DEPTH_COMPONENT;
   dataType:=GL_FLOAT;
  end;
  {$ENDIF}
  {$IFDEF GLES}
  // BGRA/ARGB pixel data is converted to RGBA on the CPU at upload/readback
  // (see UploadPixelData/ReadPixelData) - GLES has no reliable BGRA texture
  // format, so internalFormat/format here are always plain sized RGBA.
  // TODO: swizzle - use a texture swizzle mask instead of a CPU copy where the driver supports it.
  ipfARGB,ipfXRGB:begin
   internalFormat:=GL_RGBA8;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipfRGB:begin
   internalFormat:=GL_RGB8;
   format:=GL_RGB;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  ipf565:begin
   internalFormat:=GL_RGB565;
   format:=GL_RGB;
   dataType:=GL_UNSIGNED_SHORT_5_6_5;
  end;
  ipf1555:begin
   internalFormat:=GL_RGB5_A1;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_SHORT_5_5_5_1;
  end;
  ipf4444,ipf4444r:begin
   internalFormat:=GL_RGBA4;
   format:=GL_RGBA;
   dataType:=GL_UNSIGNED_SHORT_4_4_4_4;
  end;
  ipfPVRTC:begin
   internalFormat:=GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
   format:=GL_COMPRESSED_TEXTURE_FORMATS;
  end;
  ipfA8:begin
   internalFormat:=GL_R8;
   format:=GL_RED;
   dataType:=GL_UNSIGNED_BYTE;
  end;
  {$ENDIF}
  else
   raise EError.Create('Unsupported pixel format: '+PixFmt2Str(ipf));
 end;
end;
{$ENDREGION}

{ TGLTextureArray }
{$REGION TextureArray}
procedure TGLTextureArray.AddDirtyRect(index:integer;rect:TRect);
begin
 NotImplemented;
end;

constructor TGLTextureArray.Create(numLayers: integer);
var
 i:integer;
begin
 inherited Create;
 SetLength(layers,numLayers);
 for i:=0 to numLayers-1 do
  layers[i]:=TGLTexture.Create;
end;

procedure TGLTextureArray.MakeImmutable;
var
 i:integer;
begin
 for i:=0 to high(layers) do
  if layers[i]<>nil then
   layers[i].MakeImmutable;
 inherited;
end;


procedure TGLTextureArray.Dump(filename:string8);
var
 layer,itemSize:integer;
 texData,data:ByteArray;
 image:TRawImage;
begin
 if filename='' then filename:='tex_'+name+'_';
 if texname=0 then begin
   Files.Save(filename+'.tex','Not allocated');
   exit;
  end;
 Bind;
 itemSize:=width*height*4;
 SetLength(texData,itemSize*length(layers));
 {$IFDEF GLES}
 // One scratch FBO alloc/free per array layer - debug-dump-only path, unoptimized is fine here.
 for layer:=0 to high(layers) do
  GLESReadTexImage(GetTextureTarget,texname,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,@texData[itemSize*layer],layer);
 SwapRedBlue8888(@texData[0],width*height*length(layers));
 {$ELSE}
 glGetTexImage(GetTextureTarget,0,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8_REV,@texData[0]);
 {$ENDIF}
 image:=TBitmapImage.Create(width,height,ipfARGB);
 for layer:=0 to high(layers) do begin
  image.data:=@texData[itemSize*layer];
  image.data:=@(layers[layer].realData[0,0]);
  data:=SavePNG(image);
  Files.Save(filename+inttostr(layer)+'.png',data);
 end;
 image.Free;
end;

procedure TGLTextureArray.FreeData;
begin
 inherited;
end;

function TGLTextureArray.GetLayer(layer:integer):TTexture;
begin
 ASSERT((layer>=0) and (layer<=high(layers)));
 result:=layers[layer];
end;

function TGLTextureArray.GetTextureTarget:integer;
begin
 if HasFlag(tfTexture) then
  result:=GL_TEXTURE_3D
 else
  result:=GL_TEXTURE_2D_ARRAY;
end;

procedure TGLTextureArray.LockLayer(index:integer; miplevel:byte; mode:TlockMode; r:PRect);
begin
 inc(locked);
 layers[index].Lock(mipLevel,mode,r);
 data:=layers[index].data;
 pitch:=layers[index].pitch;
 lockedLayer:=index;
 online:=false;
 Bits.SetFlag(caps,tfDirty);
end;

procedure TGLTextureArray.Lock(miplevel:byte=0;mode:TlockMode=lmReadWrite;r:PRect=nil);
begin
 raise EError.Create('Use LockLayer instead');
end;

procedure TGLTextureArray.Unlock;
begin
 layers[lockedLayer].Unlock;
 dec(locked);
end;

procedure TGLTextureArray.UploadInternalData;
var
 needInit:boolean;
 format,subformat,internalFormat,error:cardinal;
 i,bpp,z,depth,level:integer;
 glTarget:integer;
begin
  needInit:=false;
  if locked>0 then raise EWarning.Create('MO for a locked texture: '+name);

  if texname=0 then begin // allocate texture name
   glGenTextures(1,@texname);
   CheckForGLError('11');
   Bind;
   SetLabel;
   CheckForGLError('12');
   needInit:=true;
  end;

  // Upload texture data
  glTarget:=GetTextureTarget;
  GetGLFormat(PixelFormat,format,subFormat,internalFormat);
  depth:=length(layers);
  if format=GL_COMPRESSED_TEXTURE_FORMATS then begin
   for z:=0 to depth-1 do
    for level:=0 to MAX_LEVEL do
     if length(realData[level])>0 then
      glCompressedTexImage3D(glTarget,level,internalFormat,realwidth,realheight,depth,0,
       length(layers[z].realData[level]),@realData[level,0]);
  end else begin
   if needInit then begin  // Specify texture size and pixel format
    glTexImage3D(glTarget,0,internalFormat,realwidth,realheight,depth,0,
      format,subFormat,nil);
    CheckForGLError('13');
    UpdateFilter;
   end;
    // Upload texture data. ES 3.0 supports GL_UNPACK_ROW_LENGTH same as desktop GL.
    glPixelStorei(GL_UNPACK_ROW_LENGTH,realWidth);
    CheckForGLError('14');
    bpp:=pixelSize[pixelFormat] div 8;
    for z:=0 to depth-1 do
     with layers[z] do
      for level:=0 to MAX_LEVEL do begin
       for i:=0 to dCount[level]-1 do
        with dirty[level,i] do
         glTexSubImage3D(glTarget,level,Left,Top,z,right-left+1,bottom-top+1,1,
            format,subFormat,@realData[level,(left+top*realWidth)*bpp]);
       dCount[level]:=0;
      end;
    CheckForGLError('15');
   {$IFDEF GLES}
   if HasFlag(tfAutoMipMap) then begin // core in ES 3.0
   {$ELSE}
   if HasFlag(tfAutoMipMap) and (GL_VERSION_3_0 or GL_ARB_framebuffer_object) then begin
   {$ENDIF}
    glGenerateMipmap(glTarget);
   end;

   if HasFlag(tfClamped) then begin
    glTexParameteri(glTarget,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
    glTexParameteri(glTarget,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
   end else begin
    glTexParameteri(glTarget,GL_TEXTURE_WRAP_S,GL_REPEAT);
    glTexParameteri(glTarget,GL_TEXTURE_WRAP_T,GL_REPEAT);
   end;
   CheckForGLError('17');
  end;
  online:=true;
  Bits.Clear(caps,tfDirty);
end;
{$ENDREGION}

{ TGLTexture }
{$REGION Texture}
procedure TGLTexture.Bind;
var
 target:integer;
begin
 target:=GetTextureTarget;
 glBindTexture(target,texname);
 CheckForGLError('211');
 case target of
  GL_TEXTURE_2D:boundTex2D[activeTex]:=self;
  GL_TEXTURE_3D:boundTex3D[activeTex]:=self;
  GL_TEXTURE_2D_ARRAY:boundTex2D_Arr[activeTex]:=self;
 end;
end;

procedure TGLTexture.Clear(color:cardinal);
 var
  level:integer;
 begin
  EnsureWritable('Clear');
  // glClearTexImage is GL 4.4+, not available under GLES - CPU fill fallback below.
  {$IFNDEF GLES}
  if InMainThread and (@glClearTexImage<>nil) then begin
   cs.Enter;
   try
    InitStorage;
    // Clear directly
    for level:=0 to mipmaps do
     glClearTexImage(texName,level,GL_BGRA,GL_UNSIGNED_BYTE,@color);
    CheckForGLError('191');
    InvalidateInternalLevel(0);
   finally
     cs.Leave;
   end;
  end else
  {$ENDIF}
  begin
   // Clear in the internal storage
   Lock;
   Mem.FillD(realData[0][0],length(realData[0]) div 4,color);
   Unlock;
  end;
 end;

procedure TGLTexture.ClearPart(mipLevel:byte;x,y,width,height:integer;color:cardinal);
var
 yy:integer;
 pb:PByte;
 r:TRect;
begin
  EnsureWritable('ClearPart');
  // glClearTexSubImage is GL 4.4+, not available under GLES - CPU fill fallback below.
  {$IFNDEF GLES}
  if (texName<>0) and InMainThread and (@glClearTexSubImage<>nil) then begin
  // Upload remaining data if needed
  UploadInternalData;
  cs.Enter;
  try
   // Clear directly
   glClearTexSubImage(texName,mipLevel,x,y,0,width,height,1,GL_BGRA,GL_UNSIGNED_BYTE,@color);
   CheckForGLError('221');
   InvalidateInternalLevel(mipLevel);
  finally
   cs.Leave;
  end;
 end else
 {$ENDIF}
 begin
  // Clear in the internal storage
  r:=Rect(x,y,x+width-1,y+width-1);
  Lock(mipLevel,lmReadWrite,@r);
  pb:=data;
  inc(pb,y*pitch+x*4);
  for yy:=y to y+height-1 do begin
   Mem.FillD(pb^,width,color);
   inc(pb,pitch);
  end;
  Unlock;
 end;
end;

procedure TGLTexture.CloneFrom(src:TTexture);
begin
 inherited;
end;

constructor TGLTexture.Create;
begin
 inherited;
 cs:=TCriticalSection.Create;
 rwLock.Init;
end;

destructor TGLTexture.Destroy;
var
 t:TTexture;
begin
 if texName<>0 then begin
  t:=self;
  resourceManagerGL.FreeImage(t);
 end else begin
  if uploadrequest.data<>nil then begin
   uploadrequest.data:=nil;
   CoreTime.Sleep(10);
  end;
  rwLock.Cleanup;
  FreeAndNil(cs);
  inherited;
 end;
end;

function TGLTexture.Describe: string;
begin
 if self is TGLTexture then
  result:=Format('GLTexture(%8x):%s w=%d h=%d m=%d c=%x l=%d o=%d tn=%d fbo=%d dC=%d',
    [cardinal(self),name,width,height,mipmaps,caps,byte(locked),byte(online),texname,fbo,dCount[0]])
 else
  result:='Not a GL Texture at: '+inttohex(cardinal(self),8);
end;

procedure TGLTexture.DownloadLevel(mipLevel:integer);
var
 format,dataType,internal:cardinal;
begin
  Bind;
  GetGLformat(pixelFormat,format,dataType,internal);
  {$IFDEF GLES}
  GLESReadTexImage(GetTextureTarget,texname,mipLevel,width shr mipLevel,height shr mipLevel,format,dataType,realData[mipLevel]);
  {$ELSE}
  glGetTexImage(GetTextureTarget,mipLevel,format,dataType,realData[mipLevel]);
  {$ENDIF}
  CheckForGLError('DownL');
  realDataObsolete[mipLevel]:=false;
  dCount[mipLevel]:=0;
end;

procedure TGLTexture.Dump(filename:string8);
var
 data:ByteArray;
 image:TRawImage;
begin
 if filename='' then filename:='tex'+name+'.png';
 if texname=0 then begin
  Files.Save(filename,'Not allocated');
  exit;
 end;
 image:=TBitmapImage.Create(width,height,ipfARGB);
 Bind;
 {$IFDEF GLES}
 GLESReadTexImage(GetTextureTarget,texname,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,image.data);
 SwapRedBlue8888(image.data,width*height);
 {$ELSE}
 glGetTexImage(GetTextureTarget,0,GL_BGRA,GL_UNSIGNED_INT_8_8_8_8,image.data);
 {$ENDIF}
 data:=SavePNG(image);
 image.Free;
 Files.Save(filename,data);
end;

procedure TGLTexture.FreeData;
begin

end;

function TGLTexture.GetLayer(layer:integer):TTexture;
begin
 result:=self;
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

function TGLTexture.GetTextureTarget: integer;
begin
 result:=GL_TEXTURE_2D;
end;

procedure TGLTexture.BeginRead;
begin
 if NeedSyncForRead(self) then rwLock.EnterRead;
end;

procedure TGLTexture.EndRead;
begin
 if NeedSyncForRead(self) then rwLock.LeaveRead;
end;

procedure TGLTexture.BeginWrite;
begin
 if NeedSyncForWrite(self) then rwLock.EnterWrite;
end;

procedure TGLTexture.EndWrite;
begin
 if NeedSyncForWrite(self) then rwLock.LeaveWrite;
end;

procedure TGLTexture.EnsureWritable(opName:string8);
begin
 if HasFlag(tfReadOnly) then
  raise EWarning.Create(opName+' not allowed for immutable texture: '+name);
end;

procedure TGLTexture.MakeImmutable;
begin
 if IsLocked then
  raise EWarning.Create('Can''t make immutable while texture is locked: '+name);
 cs.Enter;
 try
  if uploadRequest.data<>nil then
   raise EWarning.Create('Can''t make immutable while upload request is pending: '+name);
  inherited MakeImmutable;
 finally
  cs.Leave;
 end;
end;

procedure TGLTexture.Lock(miplevel:byte=0;mode:TlockMode=lmReadWrite;r:PRect=nil);
var
 size:integer;
 lockRect:TRect;
 writeMode:boolean;
begin
  ASSERT(mipLevel<=MAX_LEVEL);
  if HasFlag(tfNoRead) then
    raise EWarning.Create('Can''t lock texture '+name+' for reading');
  writeMode:=mode<>lmReadOnly;
  if HasFlag(tfNoWrite) and writeMode then
    raise EWarning.Create('Can''t lock texture '+name+' for writing');
  if writeMode then
   EnsureWritable('Lock');
  {$IFDEF DEBUG}
  if HasFlag(tfThreadLocal) and (ownerThread<>0) then
   ASSERT(ownerThread=GetCurrentThreadID,
    'Thread-local texture locked from wrong thread: '+name);
  {$ENDIF}
  if locked=0 then BeginWrite; // outer lock: acquire exclusive sync (no-op in single-window mode)
  cs.Enter;
  try
   if r=nil then lockRect:=Rect(0,0,(width-1) shr mipLevel,(height-1) shr mipLevel) // full rect
    else lockRect:=r^;
   if (mode=lmCustomUpdate) and (r<>nil) then
    raise EWarning.Create('GLTex: for custom update must lock full surface');

   mipmaps:=Max(mipmaps,mipLevel);
   if length(realdata[mipLevel])=0 then begin // alloc internal storage
    size:=Max(width shr mipLevel,1)*Max(height shr mipLevel,1); // number of texels
    size:=size*pixelSize[pixelFormat] div 8;
    SetLength(realdata[mipLevel],size);
    if realDataObsolete[mipLevel] and (mode<>lmWriteOnly) then begin
     ASSERT(InMainThread,'Trying to read modified texture data outside the main thread');
     DownloadLevel(mipLevel);
    end;
   end;
   pitch:=Max(width shr mipLevel,1)*pixelSize[pixelFormat] shr 3;
   if r=nil then data:=@realData[mipLevel,0]
    else data:=@realData[mipLevel,lockRect.left*PixelSize[pixelFormat] shr 3+lockRect.Top*pitch];
   inc(locked);
   if mode=lmReadWrite then begin
    online:=false;
    Bits.SetFlag(caps,tfDirty);
    AddDirtyRect(lockRect,mipLevel);
   end;
  except
   cs.Leave;
   if locked=0 then EndWrite;
   raise;
  end;
end;

procedure TGLTexture.Unlock;
begin
 ASSERT(locked>0,'Texture not locked: '+name);
 dec(locked);
 cs.Leave;
 if locked=0 then EndWrite; // outer unlock: release exclusive sync
end;

procedure TGLTexture.LockLayer(index:integer;miplevel:byte;mode:TLockMode;r:PRect);
begin
 Lock(mipLevel,mode,r);
end;

procedure TGLTexture.ProcessUploadRequest;
begin
 cs.Enter;
 try
  if uploadrequest.data=nil then exit;
  Upload(uploadRequest.mipLevel,uploadRequest.data,uploadrequest.pitch,uploadRequest.pf);
  Mem.Clear(uploadRequest,sizeof(uploadRequest));
 finally
  cs.Leave;
 end;
end;

procedure TGLTexture.AddDirtyRect(rect:TRect;level:integer);
var
 n:integer;
begin
 if HasFlag(tfReadOnly) then
  raise EWarning.Create('AddDirtyRect not allowed for immutable texture: '+name);
 online:=false; Bits.SetFlag(caps,tfDirty);
 n:=dCount[level];
 if n<0 then exit;
 if n<high(dirty[level]) then begin
  dirty[level,n]:=rect;
  inc(dCount[level]);
 end else begin
  // Too many rects - invalidate all
  dCount[level]:=-1; // forbid any more rects
  dirty[level,0]:=Types.Rect(0,0,width-1,height-1);
 end;
end;


procedure TGLTexture.SetAsRenderTarget;
begin
 Assert(HasFlag(tfRenderTarget));
 {$IFDEF GLES}
 glBindFramebuffer(GL_FRAMEBUFFER,fbo); // core in ES 3.0
 {$ELSE}
 if GL_VERSION_3_0 or GL_ARB_framebuffer_object then
  glBindFramebuffer(GL_FRAMEBUFFER,fbo)
 else if GL_EXT_framebuffer_object then
  glBindFramebufferEXT(GL_FRAMEBUFFER,fbo)
 else
  raise EError.Create('SART: Render target not supported');
 {$ENDIF}
 CheckForGLError('SART:'+Describe);
end;

procedure TGLTexture.SetFilter(filter:TTexFilter);
 begin
  self.filter:=filter;
  if texname<>0 then UpdateFilter;
 end;

procedure TGLTexture.SetLabel;
begin
 if name<>'' then begin
  SetGLObjectLabel(GL_TEXTURE,texname,name);
  CheckForGLError('L01');
 end;
end;

procedure TGLTexture.UpdateFilter;
var
 fMin,fMax:integer;
 target,aTex:GLInt;
begin
 if texname=0 then exit;
 case filter of
  fltUndefined:exit;
  fltNearest:begin
   fMin:=GL_NEAREST;
   fMax:=GL_NEAREST;
  end;
  fltBilinear:begin
   if mipmaps>0 then begin
    fMin:=GL_LINEAR_MIPMAP_NEAREST;
    //fMin:=GL_LINEAR;
    fMax:=GL_LINEAR;
   end else begin
    fMin:=GL_LINEAR;
    fMax:=GL_LINEAR;
   end;
  end;
  fltTrilinear:begin
   if mipmaps>0 then begin
    fMin:=GL_LINEAR_MIPMAP_LINEAR;
    fMax:=GL_LINEAR;
   end else begin
    fMin:=GL_LINEAR;
    fMax:=GL_LINEAR;
   end;
  end;
 end;
 {$IFNDEF GLES}
 if @glTextureParameteri<>nil then begin
  // GL 4.5 mode
  glTextureParameteri(texname,GL_TEXTURE_MIN_FILTER,fMin);
  glTextureParameteri(texname,GL_TEXTURE_MAG_FILTER,fMax);
 end else
 if @glTextureParameteriEXT<>nil then begin
  // EXT_direct_state_access mode
  target:=GetTextureTarget;
  glTextureParameteriEXT(texname,target,GL_TEXTURE_MIN_FILTER,fMin);
  glTextureParameteriEXT(texname,target,GL_TEXTURE_MAG_FILTER,fMax);
 end else
 {$ENDIF}
 begin
  // 4.4-/GLES compatibility mode (no DSA)
  target:=GetTextureTarget;
  SaveActiveTexture;
  Bind;
  glTexParameteri(target,GL_TEXTURE_MIN_FILTER,fMin);
  glTexParameteri(target,GL_TEXTURE_MAG_FILTER,fMax);
  CheckForGLError('16');
  RestoreActiveTexture;
 end;
end;

procedure TGLTexture.Upload(pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat);
 begin
  Upload(0,pixelData,pitch,pixelFormat);
 end;

procedure TGLTexture.Upload(mipLevel:byte;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat);
 var
  format,subformat,internalFormat,error:cardinal;
  bpp,y,lineSize:integer;
  sp,dp:PByte;
  {$IFDEF GLES}
  uploadBuf:pointer;
  {$ENDIF}
 begin
  EnsureWritable('Upload');
  if not InMainThread then begin // upload request from non-main thread: sync
   ASSERT(self.pixelFormat=pixelFormat);
   repeat
    cs.Enter;
    if uploadRequest.data=nil then break;
    cs.Leave;
    CoreTime.Sleep(0);
   until false;
   uploadRequest.pitch:=pitch;
   uploadRequest.mipLevel:=mipLevel;
   uploadRequest.pf:=pixelFormat;
   uploadRequest.x:=0;
   uploadRequest.y:=0;
   uploadRequest.width:=0;
   uploadRequest.height:=0;
   uploadRequest.data:=pixelData;
   cs.Leave;
   Signal('GLImages\Upload',TTag(self));
   // wait until request is complete
   while uploadRequest.data<>nil do CoreTime.Sleep(0);
   exit;
  end;
  // Direct upload
  ASSERT(mipLevel<=MAX_LEVEL);
  cs.Enter;
  try
   if mipLevel>mipmaps then mipMaps:=mipLevel;
   if texName=0 then InitStorage;
   Bind;
   GetGLFormat(PixelFormat,format,subFormat,internalFormat);
   bpp:=pixelSize[pixelFormat] div 8;
   glPixelStorei(GL_UNPACK_ROW_LENGTH,pitch div bpp);
   {$IFDEF GLES}
   if pixelFormat in [ipfARGB,ipfXRGB] then begin
    uploadBuf:=BGRAToRGBACopy(pixelData,(pitch div bpp)*Max(realheight shr mipLevel,1));
    glTexImage2D(GL_TEXTURE_2D,mipLevel,internalFormat,
      Max(realwidth shr mipLevel,1),Max(realheight shr mipLevel,1),0,format,subFormat,uploadBuf);
    FreeMem(uploadBuf);
   end else
   {$ENDIF}
   glTexImage2D(GL_TEXTURE_2D,mipLevel,internalFormat,
     Max(realwidth shr mipLevel,1),Max(realheight shr mipLevel,1),0,format,subFormat,pixelData);
   CheckForGLError('231');
   online:=true; Bits.Clear(caps,tfDirty);
   InvalidateInternalLevel(mipLevel);
  finally
   cs.Leave;
  end;
 end;

procedure TGLTexture.UploadPart(mipLevel:byte;x,y,width,height:integer;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat);
 var
  format,subformat,internalFormat,error:cardinal;
  bpp:integer;
  {$IFDEF GLES}
  uploadBuf:pointer;
  {$ENDIF}
 begin
  EnsureWritable('UploadPart');
  ASSERT(InMainThread,'Direct upload is available in the main thread only');
  cs.Enter;
  try
   ASSERT(texName<>0,'Texture '+name+' must be initialized before partial update');
   Bind;
   GetGLFormat(PixelFormat,format,subFormat,internalFormat);
   bpp:=pixelSize[pixelFormat] div 8;
   glPixelStorei(GL_UNPACK_ROW_LENGTH,pitch div bpp);
   {$IFDEF GLES}
   if pixelFormat in [ipfARGB,ipfXRGB] then begin
    uploadBuf:=BGRAToRGBACopy(pixelData,(pitch div bpp)*height);
    glTexSubImage2D(GL_TEXTURE_2D,mipLevel,x,y,width,height,format,subFormat,uploadBuf);
    FreeMem(uploadBuf);
   end else
   {$ENDIF}
   glTexSubImage2D(GL_TEXTURE_2D,mipLevel,x,y,width,height,format,subFormat,pixelData);
   CheckForGLError('241');
   InvalidateInternalLevel(mipLevel);
  finally
   cs.Leave;
  end;
 end;

procedure TGLTexture.InitStorage;
 var
  format,subformat,internalFormat,error:cardinal;
  mipLevel:integer;
 begin
  if texName<>0 then exit;
  glGenTextures(1,@texname);
  CheckForGLError('S11');
  SaveActiveTexture;
  Bind;
  if HasFlag(tfClamped) then begin
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
  end else begin
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
  end;
  CheckForGLError('S13');
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,mipmaps);
  CheckForGLError('S14');
  // Allocate texture storage
  GetGLFormat(PixelFormat,format,subFormat,internalFormat);
  CheckForGLError('S15');
  for mipLevel:=0 to mipMaps do begin
   glTexImage2D(GetTextureTarget,mipLevel,internalFormat,
     Max(realwidth shr mipLevel,1),Max(realheight shr mipLevel,1),0,format,subFormat,nil);
   CheckForGLError('S17');
  end;
  RestoreActiveTexture;
  SetLabel;
  UpdateFilter;
 end;

procedure TGLTexture.InvalidateInternalLevel(mipLevel: integer);
 begin
  SetLength(realData[0],0); // destroy internal storage
  realDataObsolete[0]:=true;
 end;

function TGLTexture.IsBound(stage:integer):boolean;
 var
  target:integer;
 begin
  target:=GetTextureTarget;
  case target of
   GL_TEXTURE_2D:result:=boundTex2D[stage]=self;
   GL_TEXTURE_3D:result:=boundTex3D[stage]=self;
   GL_TEXTURE_2D_ARRAY:result:=boundTex2D_Arr[stage]=self;
  end;
 end;

procedure TGLTexture.UploadInternalData;
 var
  needInit:boolean;
  format,subformat,internalFormat,error:cardinal;
  i,bpp,level:integer;
 begin
  needInit:=false;
  cs.Enter;
  try
  InitStorage;

  Bind;
  GetGLFormat(PixelFormat,format,subFormat,internalFormat);
  // ES 3.0 supports GL_UNPACK_ROW_LENGTH same as desktop GL, so the dirty-rect
  // upload path is shared; only the BGRA->RGBA byte swap below is GLES-specific.
  {$IFDEF GLES}
  if pixelFormat in [ipfARGB,ipfXRGB] then
   for level:=0 to mipmaps do
    if length(realData[level])>0 then
     SwapRedBlue8888(@realData[level,0],length(realData[level]) div 4); // buffer size, not shr dims: `w shr level` hits 0 on tail mips
  {$ENDIF}
  for level:=0 to mipmaps do
    if dCount[level]<>0 then begin
     // Upload texture data
     glPixelStorei(GL_UNPACK_ROW_LENGTH,realWidth shr level);
     CheckForGLError('14');
     bpp:=pixelSize[pixelFormat] div 8;
     if dCount[level]<0 then dCount[level]:=1;
     for i:=0 to dCount[level]-1 do
      with dirty[level,i] do
       glTexSubImage2D(GL_TEXTURE_2D,level,Left,Top,right-left+1,bottom-top+1,
          format,subFormat,@realData[level,(left+top*realWidth)*bpp]);
     CheckForGLError('15');
     dCount[level]:=0;
    end;
  {$IFDEF GLES}
  // swap back: realData keeps its original BGRA-family in-memory layout for other consumers
  if pixelFormat in [ipfARGB,ipfXRGB] then
   for level:=0 to mipmaps do
    if length(realData[level])>0 then
     SwapRedBlue8888(@realData[level,0],length(realData[level]) div 4); // buffer size, not shr dims: `w shr level` hits 0 on tail mips
  {$ENDIF}
  // Set level limit - otherwise texture sampler will produce black
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,mipmaps);
  {$IFDEF GLES}
  if HasFlag(tfAutoMipMap) then begin // core in ES 3.0
  {$ELSE}
  if HasFlag(tfAutoMipMap) and (GL_VERSION_3_0 or GL_ARB_framebuffer_object) then begin
  {$ENDIF}
   glGenerateMipmap(GL_TEXTURE_2D);
  end;
  online:=true; Bits.Clear(caps,tfDirty);
  finally
   cs.Leave;
  end;
 end;

{$ENDREGION}

procedure EventHandler(event:TEventStr;tag:TTag);
var
 tex:TTexture;
 tg:TGlTexture;
begin
 if SameText(event,'GLImages\DeleteTexture') then begin
  tex:=TTexture(UIntPtr(tag));
  resourceManagerGL.FreeImage(tex);
 end else
 if SameText(event,'GLImages\Upload') then begin
  tg:=TGLTexture(UIntPtr(tag));
  tg.ProcessUploadRequest;
 end;
end;

{ TGLResourceManager }
{$REGION ResourceManager}
procedure TGLResourceManager.AllocRenderTarget(tex:TGLTexture;flags:cardinal);
var
 format,SubFormat,internalFormat:cardinal;
 status:cardinal;
 prevFramebuffer:GLint;
 renderBuffer:GLUint;
 lab:String8;
begin
 begin
   if tex.name='UI_HintImage' then
    Log.Debug(sysUtils.Format('AllocImage RT %dx%d %d (%s)',[tex.width,tex.height,flags,tex.name]))
   else
    Log.Msg(sysUtils.Format('AllocImage RT %dx%d %d (%s)',[tex.width,tex.height,flags,tex.name]));
  if Max(tex.width,tex.height)>maxRTsize then raise EWarning.Create('AI: RT texture too large');
  {$IFDEF GLES}
  // Rewritten from scratch during the ES 3.0 cleanup (2026-07-03): the previous GLES11
  // branch here referenced an undeclared `zTex` and bare `width`/`height` locals that
  // don't exist in this signature - it never actually compiled for any real target.
  // This path mirrors the desktop branch below but is UNTESTED on real GLES hardware/ANGLE
  // (only compile-checked, per the GLES cleanup task's code-only scope). Needs runtime
  // sign-off once R-24/R-30 bring up an actual mobile/ANGLE target.
  glGenFramebuffers(1,@tex.fbo);
  glBindFramebuffer(GL_FRAMEBUFFER,tex.fbo);
  lab:='FBO:'+tex.name;
  if lab='FBO:' then lab:='FBO#'+IntToStr(tex.fbo);
  SetGLObjectLabel(GL_FRAMEBUFFER,tex.fbo,lab);
  glGenTextures(1,@tex.texname);
  ActiveTextureUnit(9);
  tex.Bind;
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  tex.filter:=fltBilinear;
  if Bits.HasAll(flags,aiClampUV) then begin
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
   Bits.SetFlag(tex.caps,tfClamped);
  end;
  GetGLFormat(tex.pixelFormat,format,subFormat,internalFormat);
  glTexImage2D(GL_TEXTURE_2D,0,internalFormat,tex.width,tex.height,0,format,subFormat,nil);
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex.texname,0);
  if Bits.HasAll(flags,aiDepthBuffer) then begin
   glGenRenderbuffers(1,@renderBuffer);
   glBindRenderbuffer(GL_RENDERBUFFER,renderBuffer);
   glRenderbufferStorage(GL_RENDERBUFFER,GL_DEPTH_COMPONENT16,tex.width,tex.height);
   glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,renderBuffer);
   tex.rbo:=renderBuffer;
  end;
  status:=glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if status<>GL_FRAMEBUFFER_COMPLETE then
   raise EError.Create('FBO status: '+inttostr(status));
  {$ENDIF GLES}

  {$IFNDEF GLES}
  // Standard way: use FBO
  glGenFramebuffers(1,@tex.fbo);
  CheckForGLError('1'); // validate FBO creation itself
  // Save current framebuffer
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,@prevFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER,tex.fbo);
  lab:='FBO:'+tex.name;
  // Keep useful label even for unnamed temporary render targets.
  if lab='FBO:' then lab:='FBO#'+IntToStr(tex.fbo);
  SetGLObjectLabel(GL_FRAMEBUFFER,tex.fbo,lab);
  CheckForGLError('2');
  glGenTextures(1,@tex.texname);
  ActiveTextureUnit(9);
  tex.Bind;
  CheckForGLError('3');
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  tex.filter:=fltBilinear;
  if Bits.HasAll(flags,aiClampUV) then begin
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
   Bits.SetFlag(tex.caps,tfClamped);
  end;
  if (tex.pixelFormat in [ipfNone,ipfDepth32f]) and Bits.HasAll(flags,aiDepthBuffer) then begin
   // No pixel format, but need depth buffer: allocate depth buffer only
   if tex.pixelFormat=ipfNone then begin
    // No need to access depth values - allocate renderbuffer storage
    glGenRenderbuffers(1,@renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, tex.width, tex.height);
    glFramebufferRenderBuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer);
    tex.rbo:=renderBuffer;
   end else begin
    // Allocate texture storage
    glTexImage2D(GL_TEXTURE_2D,0,GL_DEPTH_COMPONENT,tex.width,tex.height,0,GL_DEPTH_COMPONENT,GL_FLOAT,nil);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_COMPARE_MODE,GL_COMPARE_REF_TO_TEXTURE); // enable comparison mode
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_COMPARE_FUNC,GL_LESS); // enable comparison mode

    glFramebufferTexture(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,tex.texname,0);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
   end;
  end else begin
   GetGLFormat(tex.pixelFormat,format,subFormat,internalFormat);
   glTexImage2D(GL_TEXTURE_2D,0,internalFormat,tex.width,tex.height,0,format,subFormat,nil);
   CheckForGLError('4');
   glFramebufferTexture(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,tex.texname,0);

   if Bits.HasAll(flags,aiDepthBuffer) then begin
    glGenRenderbuffers(1,@renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, tex.width, tex.height);
    glFramebufferRenderBuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer);
    tex.rbo:=renderBuffer;
   end;
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
  end;

  status:=glCheckFramebufferStatus(GL_FRAMEBUFFER);
  // Restore previous framebuffer binding
  glBindFramebuffer(GL_FRAMEBUFFER,prevFramebuffer);

  if status<>GL_FRAMEBUFFER_COMPLETE then
   raise EError.Create('FBO status: '+inttostr(status));

  {$ENDIF}
  Bits.SetFlag(tex.caps,tfRenderTarget+tfNoRead+tfNoWrite);
  tex.online:=true; Bits.Clear(tex.caps,tfDirty);
 end;
end;

function TGLResourceManager.AllocImage(width,height:integer; PixFmt:TImagePixelFormat; flags:cardinal;
  name:String8):TTexture;
begin
 result:=AllocImage(width,height,0,pixFmt,flags,name);
end;

function TGLResourceManager.AllocImage(width,height,mipLevels:integer; PixFmt:TImagePixelFormat; flags:cardinal;
  name:String8):TTexture;
var
 tex:TGlTexture;
 dataSize:integer;
begin
 ASSERT((width>0) AND (height>0),'Zero width or height: '+name);
 ASSERT((pixFmt<>ipfNone) or Bits.HasAll(flags,aiDepthBuffer),'Invalid pixel format for '+name);
 if not Bits.HasAll(flags,aiSysMem) and ((width>maxTextureSize) or (height>maxTextureSize)) then
  raise EWarning.Create('AI: Texture too large');
 try
 cSect.Enter;
 try
 tex:=TGLTexture.Create;
 result:=tex;
 tex.width:=width;
 tex.height:=height;
 // NPOT textures (incl. render targets) are a hard requirement of the engine
 // baseline (GL 3.3 core / GLES 3.0), so dimensions are never rounded up
 // automatically — only when aiPow2 is explicitly requested (mip-mapped or tiled
 // textures). The old auto-fallback keyed off GL_ARB_texture_non_power_of_two,
 // which core profiles don't advertise (macOS = GL 4.1 core via Metal), so it
 // silently pow2-rounded every RT and corrupted its UVs.
 if Bits.HasAll(flags,aiPow2) then begin
  width:=NextPow2(width);
  height:=NextPow2(height);
 end;
 tex.realwidth:=width;
 tex.realHeight:=height;
 if Bits.HasAll(flags,aiThreadLocal) then begin
  Bits.SetFlag(tex.caps,tfThreadLocal);
  tex.ownerThread:=GetCurrentThreadID; // caller's thread owns this texture
  if (name<>'') and (name[1]<>'_') then
   tex.name:='_'+name // non-unique prefix: skips global name registry
  else
   tex.name:=name;
 end else
  tex.name:=name;
 tex.PixelFormat:=PixFmt;
 tex.online:=false;
 Bits.SetFlag(tex.caps,tfDirty);
 if Bits.HasAll(flags,aiPixelated) then
  tex.filter:=fltNearest
 else
  tex.filter:=fltTrilinear;

 if flags and aiRenderTarget>0 then begin
  AllocRenderTarget(tex,flags);
 end else begin
  {// Not render target -> NO ANY GL* CALLS TO ALLOW MULTITHREADED ALLOCATION
  tex.pitch:=width*pixelSize[pixFmt] div 8;
  datasize:=tex.pitch*height;
  if pixFMT in [ipfDXT1,ipfDXT3,ipfDXT5] then begin
   tex.pitch:=tex.pitch div 4;
   datasize:=datasize div 16;
  end;
  SetLength(tex.realData[0],datasize);}

  Bits.SetFlag(tex.caps,tfDirectAccess); // Can be locked
  if Bits.HasAll(flags,aiClampUV) then
   Bits.SetFlag(tex.caps,tfClamped);
  // Mip-maps -> enable automatic generation
  if Bits.HasAll(flags,aiAutoMipmap) then begin
   Bits.SetFlag(tex.caps,tfAutoMipMap);
   tex.mipmaps:=Clamp(Log2i(Max(width,height)),0,tex.MAX_LEVEL);
  end else
   tex.mipmaps:=mipLevels;
 end;

 // Image can use the texture partialy
 tex.u1:=0; tex.u2:=tex.width/width;
 tex.v1:=0; tex.v2:=tex.height/height;
 tex.stepU:=0.5*(tex.u2-tex.u1)/tex.width;
 tex.stepV:=0.5*(tex.v2-tex.v1)/tex.height;
 finally cSect.Leave;
 end;
 except
  on e:Exception do begin
   if tex<>nil then tex.Free;
   result:=nil;
   Log.Msg('AllocImage error: '+ExceptionMsg(e));
   raise;
  end;
 end;
end;

function TGLResourceManager.AllocArray(width,height:integer;PixFmt:TImagePixelFormat;
                arraySize:integer;flags:cardinal;name:String8):TGLTextureArray;
var
 tex:TGlTextureArray;
 dataSize,z:integer;
begin
 ASSERT((width>0) AND (height>0),'Zero width or height: '+name);
 ASSERT((pixFmt<>ipfNone) or Bits.HasAll(flags,aiDepthBuffer),'Invalid pixel format for '+name);
 if (flags and aiSysMem=0) and ((width>maxTextureSize) or (height>maxTextureSize)) then
  raise EWarning.Create('AI: Texture too large');
 try
 cSect.Enter;
 try
 tex:=TGLTextureArray.Create(arraySize);
 result:=tex;
 tex.width:=width;
 tex.height:=height;
 if (flags and aiPow2>0) then begin // explicit opt-in only; NPOT is baseline (see AllocImage above)
  width:=NextPow2(width);
  height:=NextPow2(height);
 end;
 tex.realwidth:=width;
 tex.realHeight:=height;
 tex.name:=name;
 tex.pixelFormat:=pixFmt;
 tex.online:=false;
 Bits.SetFlag(tex.caps,tfDirty);
 if Bits.HasAll(flags,aiPixelated) then
  tex.filter:=fltNearest
 else
  tex.filter:=fltTrilinear;

 if Bits.HasAll(flags,aiTexture3D) then Bits.SetFlag(tex.caps,tfTexture);

 tex.pitch:=width*pixelSize[pixFmt] div 8;
 datasize:=tex.pitch*height;
 if pixFMT in [ipfDXT1,ipfDXT3,ipfDXT5] then begin
  tex.pitch:=tex.pitch div 4;
  datasize:=datasize div 16;
 end;
 for z:=0 to high(tex.layers) do begin
  tex.layers[z]:=AllocImage(width,height,pixFmt,0,name+'_lay'+inttostr(z)) as TGLTexture;
{  tex.layers[z].width:=width;
  tex.layers[z].height:=height;
  tex.layers[z].pixelFormat:=tex.pixelFormat;
  tex.layers[z].realwidth:=width;
  tex.layers[z].realheight:=height;
  SetLength(tex.layers[z].realData[0],datasize);}
 end;

 Bits.SetFlag(tex.caps,tfDirectAccess); // Can be locked
 if Bits.HasAll(flags,aiClampUV) then
  Bits.SetFlag(tex.caps,tfClamped);
  // Mip-maps
 if Bits.HasAll(flags,aiAutoMipmap) then begin
  Bits.SetFlag(tex.caps,tfAutoMipMap);
  tex.mipmaps:=Log2i(Max(width,height));
 end;

 tex.u1:=0; tex.u2:=tex.width/width;
 tex.v1:=0; tex.v2:=tex.height/height;
 tex.stepU:=0.5*(tex.u2-tex.u1)/tex.width;
 tex.stepV:=0.5*(tex.v2-tex.v1)/tex.height;
 finally cSect.Leave;
 end;
 except
  on e:Exception do begin
   if tex<>nil then tex.Free;
   result:=nil;
   Log.Msg('AllocImage error: '+ExceptionMsg(e));
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

function TGLResourceManager.Copy(img:TTexture):TTexture;
begin

end;

constructor TGLResourceManager.Create;
begin
 try
  resourceManagerGL:=self;

  glPixelStorei(GL_UNPACK_ALIGNMENT,1);
  mainThreadID:=GetCurrentThreadId;
  resourceManagerGL:=self;
  SetEventHandler('GLImages',EventHandler,emMixed);
  {$IFDEF GLES}
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @maxTextureSize);
  maxRBsize:=maxTextureSize;
  {$ELSE}
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @maxTextureSize);
  glGetIntegerv(GL_MAX_RENDERBUFFER_SIZE, @maxRBsize);
  {$ENDIF}
  maxRTsize:=Min(maxTextureSize,maxRBsize);
  Log.Msg(Format('Maximal sizes: TEX: %d / RT: %d / RB: %d',[maxTextureSize,maxRTsize,maxRBsize]));
 except
  on e:Exception do begin
   Log.Force('Error in GLTexMan constructor: '+ExceptionMsg(e));
   raise EFatalError.Create('GLTextMan: '+ExceptionMsg(e));
  end;
 end;
 CheckForGLError('ResMan.Create');
end;

destructor TGLResourceManager.Destroy;
var
 hash:PObjectHash;
 list:TNamedObjects;
 i,leftoverCnt:integer;
begin
 // Requires a valid GL context because FreeImage deletes GL objects.
 // If some textures are still alive here, we log and force cleanup.
 DebugMsg('[LIFECYCLE] Destroy %s',[ClassName]);
 Log.Msg('[LIFECYCLE] Destroy '+ClassName);
 // Free all remaining textures
 hash:=TGLTexture.ClassHash;
 if hash<>nil then begin
  list:=hash.ListObjects;
  leftoverCnt:=length(list);
  if leftoverCnt>0 then begin
   Log.Warn('GLResourceManager.Destroy: %d textures are still alive, forcing cleanup',[leftoverCnt]);
  end;
  for i:=0 to high(list) do
   FreeImage(TTexture(list[i]));
 end;
 resourceManagerGL:=nil;
 inherited;
end;

procedure TGLResourceManager.Dump(st:string);
begin

end;

procedure TGLResourceManager.FreeImage(var image:TTexture);
var
 tex:TGLTexture;
 level:integer;
begin
 // Must run on render thread with active GL context for actual GPU deletion.
 // Non-main thread requests are marshalled via GLImages\DeleteTexture signal.
 if image=nil then exit;
 // Wrong thread?
 if not InMainThread then begin
  if not (image is TGLTexture) then raise EError.Create('Not a GLTexture! '+IntToHEx(cardinal(image),8));
  Signal('GLIMAGES\DeleteTexture',TTag(image));
  image:=nil;
  exit;
 end;
 cSect.Enter;
 try
 dec(image.refCounter);
 if image.refCounter>=0 then begin
  image:=nil;
  exit; // prevent object deletion
 end;

 if image.parent<>nil then FreeImage(image.parent);

 if image is TGLTexture then begin
  tex:=image as TGLTexture;
  if tex.fbo<>0 then begin // free framebuffer
   {$IFDEF GLES}
   glDeleteFramebuffers(1,@tex.fbo); // core in ES 3.0
   {$ELSE}
   if GL_VERSION_3_0 or GL_ARB_framebuffer_object then
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
  UnbindTex(tex);
  tex.Free;
  image:=nil;
 end else
  raise EWarning.Create('FI: not a GL texture');
 finally
  cSect.Leave;
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
begin
 TGLTexture(img).filter:=filter;
 TGLTexture(img).UpdateFilter;
end;

procedure TGLResourceManager.MakeOnline(img:TTexture;stage:integer=0);
var
 tex:TGLTexture;
begin
 if img=nil then begin
  //curTextures[stage]:=nil;
  exit;
 end;
 ASSERT(img is TGLTexture);
 tex:=TGLTexture(img);
 if tex.IsBound(stage) and tex.online then exit;
 if boundTex2D[stage]<>tex then begin
  ActiveTextureUnit(stage);
  tex.Bind;
 end;
 if not tex.online then tex.UploadInternalData;
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
 // GL_PROXY_TEXTURE_2D doesn't exist in GLES: the MAX_TEX_SIZE/GL_MAX_TEXTURE_SIZE
 // comparison above is the whole check there, no format-capability probe.
 {$IFNDEF GLES}
 GetGLFormat(format,glFormat,subFormat,internalFormat);
 glTexImage2D(GL_PROXY_TEXTURE_2D,0,internalFormat,width,height,0,glFormat,subFormat,nil);
 glGetTexLevelParameteriv(GL_PROXY_TEXTURE_2D,0,GL_TEXTURE_INTERNAL_FORMAT,@res);
 CheckForGLError('18');
 if res=0 then result:=false;
 {$ENDIF}
end;

procedure TGLResourceManager.ResizeImage(var img:TTexture;newWidth,newHeight:integer);
var
 glFormat,subFormat,internalFormat:cardinal;
 old:TTexture;
begin
 // Render target -> resize
 if img.HasFlag(tfRenderTarget) then
  with img as TGLTexture do begin
   width:=newWidth;
   height:=newHeight;
   if texName<>0 then begin /// TODO: check carefuly
    Bind;
    GetGLFormat(img.PixelFormat,glFormat,subFormat,internalFormat);
    glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,glFormat,subFormat,nil);
   end;
   CheckForGLError('19');
   if rbo<>0 then begin
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    // ES 3.0 requires a sized internal format for renderbuffer storage
    glRenderbufferStorage(GL_RENDERBUFFER, {$IFDEF GLES}GL_DEPTH_COMPONENT16{$ELSE}GL_DEPTH_COMPONENT{$ENDIF}, width, height);
   end;
   exit;
  end;
 // Regular texture -> re-allocate
 old:=img;
 img:=AllocImage(newWidth,newHeight,img.PixelFormat,img.caps,img.name);
 FreeImage(old);
end;

procedure TGLResourceManager.AttachDepthBuffer(tex,dBuf:TTexture);
var
 target,depth:TGLTexture;
 prevFrameBuffer:glint;
begin
 ASSERT(tex.HasFlag(tfRenderTarget));
 ASSERT(dBuf.HasFlag(tfRenderTarget));
 target:=tex as TGLTexture;
 depth:=dBuf as TGLTexture;
 // Save framebuffer binding
 glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,@prevFramebuffer);
 glBindFramebuffer(GL_FRAMEBUFFER,target.fbo);
 if depth.rbo<>0 then
  glFramebufferRenderBuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,depth.rbo)
 else
  {$IFDEF GLES}
  // glFramebufferTexture (no target dimension) is GL 3.2+/ES 3.2, not core in ES 3.0.
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_TEXTURE_2D,depth.texname,0);
  {$ELSE}
  glFramebufferTexture(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,depth.texname,0);
  {$ENDIF}

 // Restore framebuffer binding
 glBindFramebuffer(GL_FRAMEBUFFER,prevFrameBuffer);
end;
{$ENDREGION}

// ---- Data buffers ----
{$REGION BUFFERS}
function TGLResourceManager.AllocVertexBuffer(layout:TVertexLayout;numVertices:integer;
  usage:TBufferUsage;flags:cardinal):TVertexBuffer;
var
 vb:TVertexBufferGL;
begin
 vb:=TVertexBufferGL.Create(layout,numVertices,flags);
 vb.publishedSync:=nil;
 glGenBuffers(1,@vb.buffer);
 ASSERT(vb.buffer<>0);
 glBindBuffer(GL_ARRAY_BUFFER,vb.buffer);
 TrackArrayBufferBinding(vb.buffer);
 case usage of
  buStatic:    vb.usage:=GL_STATIC_DRAW;
  buDynamic:   vb.usage:=GL_DYNAMIC_DRAW;
  buTemporary: vb.usage:=GL_STREAM_DRAW;
 end;
 glBufferData(GL_ARRAY_BUFFER,vb.strideBytes*numVertices,nil,vb.usage);
 CheckForGLError('AllocVB'); // validate real allocation call
 // Stage 7: semantic label is taken from vb.debugName when provided by caller.
 SetGLObjectLabel(GL_BUFFER,vb.buffer,BuildVBLabel(vb));
 result:=vb;
end;

// Layout-less vertex buffer with an explicit byte stride (R-19 TGpuMesh path).
// The caller binds attributes via renderDevice.BindMeshLayout(TGpuLayout), so the
// packed TVertexLayout is not involved.
function TGLResourceManager.AllocRawVertexBuffer(strideBytes,numVertices:integer;
  usage:TBufferUsage;flags:cardinal):TVertexBuffer;
var
 vb:TVertexBufferGL;
begin
 vb:=TVertexBufferGL.Create(strideBytes,numVertices,flags);
 vb.publishedSync:=nil;
 glGenBuffers(1,@vb.buffer);
 ASSERT(vb.buffer<>0);
 glBindBuffer(GL_ARRAY_BUFFER,vb.buffer);
 TrackArrayBufferBinding(vb.buffer);
 case usage of
  buStatic:    vb.usage:=GL_STATIC_DRAW;
  buDynamic:   vb.usage:=GL_DYNAMIC_DRAW;
  buTemporary: vb.usage:=GL_STREAM_DRAW;
 end;
 glBufferData(GL_ARRAY_BUFFER,vb.strideBytes*numVertices,nil,vb.usage);
 CheckForGLError('AllocRawVB');
 SetGLObjectLabel(GL_BUFFER,vb.buffer,BuildVBLabel(vb));
 result:=vb;
end;

function TGLResourceManager.AllocIndexBuffer(indCount:integer;elementSize:integer;
  usage:TBufferUsage;flags:cardinal):TIndexBuffer;
var
 ib:TIndexBufferGL;
begin
 ASSERT(elementSize in [2,4]);
 ib:=TIndexBufferGL.Create(indCount,elementSize,flags);
 ib.publishedSync:=nil;
 glGenBuffers(1,@ib.buffer);
 ASSERT(ib.buffer<>0);
 glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,ib.buffer);
 TrackElementBufferBinding(ib.buffer);
 case usage of
  buStatic:    ib.usage:=GL_STATIC_DRAW;
  buDynamic:   ib.usage:=GL_DYNAMIC_DRAW;
  buTemporary: ib.usage:=GL_STREAM_DRAW;
 end;
 glBufferData(GL_ELEMENT_ARRAY_BUFFER,indCount*elementSize,nil,ib.usage);
 CheckForGLError('AllocIB'); // validate real allocation call
 // Stage 7: semantic label is taken from ib.debugName when provided by caller.
 SetGLObjectLabel(GL_BUFFER,ib.buffer,BuildIBLabel(ib));
 result:=ib;
end;

procedure TGLResourceManager.UseVertexBuffer(vb:TVertexBuffer);
begin
 if vb<>nil then vb.BeginRead;
 if vb<>nil then
  glBindBuffer(GL_ARRAY_BUFFER,TVertexBufferGL(vb).buffer)
 else
  glBindBuffer(GL_ARRAY_BUFFER,0);
 if vb<>nil then
  TrackArrayBufferBinding(TVertexBufferGL(vb).buffer)
 else
  TrackArrayBufferBinding(0);
 if vb<>nil then vb.EndRead;
end;

procedure TGLResourceManager.UseIndexBuffer(ib:TIndexBuffer);
begin
 if ib<>nil then ib.BeginRead;
 if ib<>nil then
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,TIndexBufferGL(ib).buffer)
 else
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0);
 if ib<>nil then
  TrackElementBufferBinding(TIndexBufferGL(ib).buffer)
 else
  TrackElementBufferBinding(0);
 if ib<>nil then ib.EndRead;
end;

procedure TGLResourceManager.FreeBuffer(buf:TEngineBuffer);
begin
 if buf<>nil then buf.Free;
end;

{ TVertexBufferGL }

destructor TVertexBufferGL.Destroy;
begin
 ResetPublishState;
 if buffer<>0 then glDeleteBuffers(1,@buffer);
 inherited;
end;

destructor TIndexBufferGL.Destroy;
begin
 ResetPublishState;
 if buffer<>0 then glDeleteBuffers(1,@buffer);
 inherited;
end;

procedure TVertexBufferGL.Resize(newCount:integer);
begin
 EnsureWritable('Resize');
 BeginWrite;
 count:=newCount;
 sizeInBytes:=count*strideBytes;
 glBindBuffer(GL_ARRAY_BUFFER,buffer);
 TrackArrayBufferBinding(buffer);
 glBufferData(GL_ARRAY_BUFFER,sizeInBytes,nil,usage);
 glBindBuffer(GL_ARRAY_BUFFER,0);
 TrackArrayBufferBinding(0);
 EndWrite;
end;

procedure TVertexBufferGL.Upload(fromVertex,numVertices:integer;vertexData:pointer);
begin
 EnsureWritable('Upload');
 BeginWrite;
 glBindBuffer(GL_ARRAY_BUFFER,buffer);
 TrackArrayBufferBinding(buffer);
 glBufferSubData(GL_ARRAY_BUFFER,fromVertex*strideBytes,numVertices*strideBytes,vertexData);
 glBindBuffer(GL_ARRAY_BUFFER,0);
 TrackArrayBufferBinding(0);
 EndWrite;
end;

procedure TIndexBufferGL.Resize(newCount:integer);
begin
 EnsureWritable('Resize');
 BeginWrite;
 count:=newCount;
 sizeInBytes:=count*bytesPerIndex;
 glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,buffer);
 TrackElementBufferBinding(buffer);
 glBufferData(GL_ELEMENT_ARRAY_BUFFER,sizeInBytes,nil,usage);
 glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0);
 TrackElementBufferBinding(0);
 EndWrite;
end;

procedure TIndexBufferGL.Upload(fromIndex,numIndices:integer;indexData:pointer);
begin
 EnsureWritable('Upload');
 BeginWrite;
 glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,buffer);
 TrackElementBufferBinding(buffer);
 glBufferSubData(GL_ELEMENT_ARRAY_BUFFER,fromIndex*bytesPerIndex,numIndices*bytesPerIndex,indexData);
 glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,0);
 TrackElementBufferBinding(0);
 EndWrite;
end;

procedure TVertexBufferGL.PublishUpdate;
begin
 if IsThreadLocal then exit;
 if @glFenceSync=nil then exit;
 ResetPublishState;
 publishedSync:=pointer(glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE,0));
 if @glFlush<>nil then glFlush;
end;

procedure TVertexBufferGL.WaitForPublish;
begin
 if publishedSync=nil then exit;
 if @glWaitSync<>nil then
  glWaitSync(GLsync(publishedSync),0,high(uint64))
 else
 if @glClientWaitSync<>nil then
  glClientWaitSync(GLsync(publishedSync),GL_SYNC_FLUSH_COMMANDS_BIT,high(uint64));
 ResetPublishState;
end;

procedure TVertexBufferGL.ResetPublishState;
begin
 if publishedSync=nil then exit;
 if @glDeleteSync<>nil then
  glDeleteSync(GLsync(publishedSync));
 publishedSync:=nil;
end;

procedure TIndexBufferGL.PublishUpdate;
begin
 if IsThreadLocal then exit;
 if @glFenceSync=nil then exit;
 ResetPublishState;
 publishedSync:=pointer(glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE,0));
 if @glFlush<>nil then glFlush;
end;

procedure TIndexBufferGL.WaitForPublish;
begin
 if publishedSync=nil then exit;
 if @glWaitSync<>nil then
  glWaitSync(GLsync(publishedSync),0,high(uint64))
 else
 if @glClientWaitSync<>nil then
  glClientWaitSync(GLsync(publishedSync),GL_SYNC_FLUSH_COMMANDS_BIT,high(uint64));
 ResetPublishState;
end;

procedure TIndexBufferGL.ResetPublishState;
begin
 if publishedSync=nil then exit;
 if @glDeleteSync<>nil then
  glDeleteSync(GLsync(publishedSync));
 publishedSync:=nil;
end;
{$ENDREGION}

// --- Robot API command handler ---

type
  TTextureAccess=class(TTexture)
    class function ListAll:TNamedObjects;
  end;

class function TTextureAccess.ListAll:TNamedObjects;
var
  hash:PObjectHash;
begin
  hash:=ClassHash;
  if hash<>nil then result:=hash^.ListObjects
  else SetLength(result,0);
end;

function RobotCmdResources(const req:TRobotRequest; out body:String8):boolean;
var
  objects:TNamedObjects;
  i:integer;
  t:TGLTexture;
begin
  body:='';
  objects:=TTextureAccess.ListAll;
  for i:=0 to high(objects) do begin
    if not (objects[i] is TGLTexture) then continue;
    t:=TGLTexture(objects[i]);
    body:=body+'TEX: '+t.name+LineBreak+
      '  glName: '+Conv.ToStr(integer(t.texname))+LineBreak+
      '  width: '+Conv.ToStr(t.width)+LineBreak+
      '  height: '+Conv.ToStr(t.height)+LineBreak+
      '  realWidth: '+Conv.ToStr(t.realWidth)+LineBreak+
      '  realHeight: '+Conv.ToStr(t.realHeight)+LineBreak+
      '  format: '+GetEnumName(TypeInfo(TImagePixelFormat),ord(t.pixelFormat))+LineBreak+
      '  hasFBO: '+Conv.ToStr(t.fbo<>0)+LineBreak;
  end;
  result:=true;
end;

initialization
  RegisterRobotCommand('resources',@RobotCmdResources);
  cSect.Init('GLTexMan',160);
finalization
  cSect.Cleanup;
end.
