// Base resource classes and types - extracted from Engine.API
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Resources;
interface
 uses Apus.Core, Apus.Classes, Apus.Images, Apus.Engine.Types, Apus.Threads;

 const
  // Buffer allocation policy flags
  abThreadLocal    = $0001; // buffer is owned by a single render thread/window
  abReadOnly       = $0002; // immutable after initial upload/finalize
  abShared         = $0004; // explicit shared-intent marker (diagnostic/policy hint)

  // Internal buffer capability flags
  bfThreadLocal    = $0001;
  bfReadOnly       = $0002;
  bfSharedHint     = $0004;

  // Texture features flags
  tfCanBeLost      = 1;    // Texture data can be lost at any moment
  tfDirectAccess   = 2;    // CPU access allowed, texture can be locked
  tfNoRead         = 4;    // Reading of texture data is not allowed
  tfNoWrite        = 8;    // Writing to texture data is not allowed
  tfRenderTarget   = 16;   // Can be used as a target for GPU rendering
  tfAutoMipMap     = 32;   // MIPMAPs are generated automatically, don't need to fill manually
  tfNoLock         = 64;   // No need to lock the texture to access its data
  tfClamped        = $80;  // By default texture coordinates are clamped (otherwise - not clamped)
  tfVidmemOnly     = $0100; // Texture uses only VRAM (download operation is required to access pixel data)
  tfSysmemOnly     = $0200; // Texture uses only System RAM (can't be used by GPU)
  tfTexture        = $0400; // Texture corresponds to a texture object of the underlying API
  tfScaled         = $0800; // scale factors are used
  tfCloned         = $1000; // Texture object is cloned from another, so don't free any underlying resources
  tfPixelated      = $2000; // No interpolation allowed for sampling this texture
  tfDirty          = $4000; // Texture is "dirty" - internal storage was modified
  tfThreadLocal    = $8000; // Texture is owned by a single thread/window, must not be shared
  tfReadOnly       = $10000; // Texture content is immutable after initial upload

 type
  // Texture filtering mode
  TTexFilter=(fltUndefined,    // filter not defined
              fltNearest,      // no interpolation
              fltBilinear,     // bilinear interpolation
              fltTrilinear,    // trilinear interpolation (mip-maps only)
              fltAnisotropic); // anisotropic filtering (mip-maps only)

  // Access mode for locked resources
  TLockMode=(lmReadOnly,       //< read-only (do not invalidate data when unlocked)
             lmReadWrite,      //< read+write (invalidate the whole area)
             lmWriteOnly,      //< write-only (don't download texture data into the internal storage)
             lmCustomUpdate);  //< read+write, do not invalidate anything (AddDirtyRect is required, partial lock is not allowed in this case)

  // Base abstract class: texture or texture region
  TTexture=class(TNamedObject)
   pixelFormat:TImagePixelFormat;
   width,height:integer; // dimension (in virtual pixels)
   left,top:integer; // position in the underlying resource
   mipmaps:byte; // highest available mip-map level
   caps:cardinal; // capability flags
   refCounter:integer; // number of child textures referencing this texture data
   parent:TTexture;    // reference to a parent texture
   // These properties are valid when texture is ONLINE (uploaded)
   u1,v1,u2,v2:single; // texture coordinates
   stepU,stepV:single; // halved texel step
   // These properties are valid when texture is LOCKED
   data:pointer;   // raw data
   pitch:integer;  // offset to next scanline

   // Create cloned image (separate object referencing the same image data). Original image can't be destroyed unless all its clones are destroyed
   procedure CloneFrom(from:TTexture); virtual;
   function Clone:TTexture; // Clone this texture and return the cloned instance
   function ClonePart(part:TRect):TTexture; // Create cloned instance for part of this texture
   procedure Clear(color:cardinal=$808080); virtual; abstract; // Clear and fill the texture with given color
   procedure ClearPart(mipLevel:byte;x,y,width,height:integer;color:cardinal=$808080); virtual; abstract; // clear part of texture
   // Define (upload) texture content directly from user defined storage
   procedure Upload(pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); overload; virtual; abstract;
   procedure Upload(mipLevel:byte;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); overload; virtual; abstract;
   procedure UploadPart(mipLevel:byte;x,y,width,height:integer;pixelData:pointer;pitch:integer;pixelFormat:TImagePixelFormat); virtual; abstract;
   // Access to the internal texture content
   procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;rect:PRect=nil); virtual; abstract; // mipLevel=0..mipMaps
   procedure LockLayer(layer:integer;miplevel:byte=0;mode:TLockMode=lmReadWrite;rect:PRect=nil); virtual; abstract; // lock layer of 3D texture or texture array
   function GetLayer(layer:integer):TTexture; virtual; abstract; // return 2D texture object of a texture array element or 3D texture layer
   function GetRawImage:TRawImage; virtual; abstract; // Create RAW image for the topmost MIP level (when locked)
   function IsLocked:boolean;
   procedure MakeImmutable; virtual; // mark texture immutable after initial upload
   procedure Unlock; virtual; abstract;
   procedure AddDirtyRect(rect:TRect;level:integer=0); virtual; abstract; // mark area to update (when locked with mode=lmCustomUpdate)
   // Utilities
   procedure GenerateMipMaps(count:byte); virtual; abstract; // generate mip-map images
   function HasFlag(flag:cardinal):boolean;
   function ScanLine(y:integer):pointer; inline;
   function PixelPtr(x,y:integer):pointer; inline;
   // Limit texture filtering to the specified mode (i.e. bilinear mode disables mip-mapping)
   procedure SetFilter(filter:TTexFilter); virtual; abstract;
   function Size:TSize; // (width,height)
   procedure Dump(filename:string8=''); virtual; abstract; // for debug purposes

   // File-name lookup is case-insensitive (hash map behavior). Keep resource
   // names normalized and avoid files that differ only by letter case.
   class function FindByFile(fileName:String8):TTexture; virtual;

  protected
   fSrc:string8; // storage for property src
   locked:integer; // lock counter
   class function ClassHash:pointer; override;
   procedure SetSource(filename:string8);
  public
   destructor Destroy; override;
   property src:String8 read fSrc write SetSource; // file name (if loaded from a file)
  end;

 // Base class for shader object
 TShader=class(TNamedObject)
  // Set uniform value
  procedure SetUniform(name:String8;value:integer); overload; virtual; abstract;
  procedure SetUniform(name:String8;value:single); overload; virtual; abstract;
  procedure SetUniform(name:String8;const value:TVec2); overload; virtual; abstract;
  procedure SetUniform(name:String8;const value:TVec3); overload; virtual; abstract;
  procedure SetUniform(name:String8;const value:TQuat); overload; virtual; abstract;
  procedure SetUniform(name:String8;const value:TMat4d); overload; virtual; abstract;
  procedure SetUniform(name:String8;const value:TMat4); overload; virtual; abstract;
  class function VectorFromColor3(color:cardinal):TVec3;
  class function VectorFromColor(color:cardinal):TQuat;
 protected
  class function ClassHash:pointer; override;
 end;

 TBufferUsage=(buStatic,   // filled once, used many times
               buDynamic,  // filled many times, used many times
               buTemporary);  // one-time buffer: filled once, used once

 TEngineBuffer=class(TObjectEx)
  sizeInBytes:integer;
  caps:cardinal;
  ownerThread:TThreadID;
  // Optional debug label for GPU object naming (NSight/RenderDoc/etc).
  // Filled by higher-level systems that know semantic ownership.
  debugName:String8;
  procedure MakeImmutable; virtual;
  function IsImmutable:boolean; inline;
  function IsThreadLocal:boolean; inline;
  procedure AssertThreadOwner(const opName:string8); inline;
  procedure PublishUpdate; virtual; // producer-side sync point for shared mutable buffers
  procedure WaitForPublish; virtual; // consumer-side wait for latest published update
  procedure ResetPublishState; virtual;
  // RW-lock protocol: acquire before accessing buffer data, release after.
  // Used in multi-window mode to prevent concurrent upload and render.
  procedure BeginRead; inline;  // shared read lock (concurrent renders allowed)
  procedure EndRead; inline;
  procedure BeginWrite; inline; // exclusive write lock (blocks until all readers done)
  procedure EndWrite; inline;
  constructor Create(flags:cardinal=0);
  destructor Destroy; override;
 protected
  rwLock:TRWLock;
  procedure EnsureWritable(const opName:string8); inline;
 end;

 TVertexBuffer=class(TEngineBuffer)
  count:integer;
  layout:TVertexLayout;
  constructor Create(layout:TVertexLayout;count:integer;flags:cardinal=0);
  procedure Upload(fromVertex,numVertices:integer;vertexData:pointer); virtual; abstract;
  procedure Resize(newCount:integer); virtual; abstract;
 end;

 TIndexBuffer=class(TEngineBuffer)
  count:integer;
  bytesPerIndex:integer; // 2 or 4
  constructor Create(count:integer;elementSize:integer;flags:cardinal=0);
  procedure Upload(fromIndex,numIndices:integer;indexData:pointer); virtual; abstract;
  procedure Resize(newCount:integer); virtual; abstract;
 end;

var
 // Set to true when multiple render windows/threads are active.
 // Enables RW-lock synchronization on shared mutable textures.
 // Single-window mode: false (default) — all sync is bypassed for zero overhead.
 multiWindowMode:boolean=false;

// Returns true when a write operation on tex must acquire RW-lock.
// False for: single-window mode, thread-local textures, immutable textures.
function NeedSyncForWrite(tex:TTexture):boolean; inline;

// Returns true when a metadata read on tex must acquire read-lock.
// Same conditions as NeedSyncForWrite: only shared mutable textures in multi-window mode.
function NeedSyncForRead(tex:TTexture):boolean; inline;

// Returns true when buffer upload/resize/use must hold RW-lock.
// Only meaningful in multi-window mode; single-window mode: always false.
function NeedSyncForBuffer(buf:TEngineBuffer):boolean; inline;
function NeedSyncForBufferRead(buf:TEngineBuffer):boolean; inline;
function NeedSyncForBufferWrite(buf:TEngineBuffer):boolean; inline;

implementation
 uses Apus.Lib;

 var
  texturesHash:TObjectHash;  // Search hash: name->texture
  texFileHash:TObjectMap;    // Search hash: filename->texture
  shadersHash:TObjectHash;   // Search hash: name->shader

function NeedSyncForWrite(tex:TTexture):boolean;
begin
 result:=multiWindowMode and
         not Bits.HasAny(tex.caps,tfThreadLocal or tfReadOnly);
end;

function NeedSyncForRead(tex:TTexture):boolean;
begin
 result:=multiWindowMode and
         not Bits.HasAny(tex.caps,tfThreadLocal or tfReadOnly);
end;

function NeedSyncForBuffer(buf:TEngineBuffer):boolean;
begin
 result:=NeedSyncForBufferRead(buf) or NeedSyncForBufferWrite(buf);
end;

function NeedSyncForBufferRead(buf:TEngineBuffer):boolean;
begin
 result:=multiWindowMode and (buf<>nil) and
   not buf.IsThreadLocal and
   not buf.IsImmutable;
end;

function NeedSyncForBufferWrite(buf:TEngineBuffer):boolean;
begin
 result:=multiWindowMode and (buf<>nil) and
   not buf.IsThreadLocal and
   not buf.IsImmutable;
end;

{ TEngineBuffer }

constructor TEngineBuffer.Create(flags:cardinal=0);
begin
 inherited Create;
 caps:=0;
 if Bits.HasAny(flags,abThreadLocal) then begin
  Bits.SetFlag(caps,bfThreadLocal);
  ownerThread:=GetCurrentThreadID;
 end else
  ownerThread:=0;
 if Bits.HasAny(flags,abReadOnly) then
  Bits.SetFlag(caps,bfReadOnly);
 if Bits.HasAny(flags,abShared) then
  Bits.SetFlag(caps,bfSharedHint);
 rwLock.Init;
end;

destructor TEngineBuffer.Destroy;
begin
 rwLock.Cleanup;
 inherited;
end;

procedure TEngineBuffer.BeginRead;
begin
 AssertThreadOwner('BeginRead');
 if NeedSyncForBufferRead(self) then rwLock.EnterRead;
end;

procedure TEngineBuffer.EndRead;
begin
 if NeedSyncForBufferRead(self) then rwLock.LeaveRead;
end;

procedure TEngineBuffer.BeginWrite;
begin
 AssertThreadOwner('BeginWrite');
 EnsureWritable('BeginWrite');
 if NeedSyncForBufferWrite(self) then rwLock.EnterWrite;
end;

procedure TEngineBuffer.EndWrite;
begin
 if NeedSyncForBufferWrite(self) then rwLock.LeaveWrite;
end;

procedure TEngineBuffer.EnsureWritable(const opName:string8);
begin
 if IsImmutable then
  raise EWarning.Create('Attempt to modify immutable buffer: '+debugName+' ('+opName+')');
end;

procedure TEngineBuffer.MakeImmutable;
begin
 Bits.SetFlag(caps,bfReadOnly);
end;

function TEngineBuffer.IsImmutable:boolean;
begin
 result:=Bits.HasAny(caps,bfReadOnly);
end;

function TEngineBuffer.IsThreadLocal:boolean;
begin
 result:=Bits.HasAny(caps,bfThreadLocal);
end;

procedure TEngineBuffer.AssertThreadOwner(const opName:string8);
begin
 if not IsThreadLocal then exit;
 ASSERT(ownerThread=GetCurrentThreadID,'Thread-local buffer ownership violation in '+opName);
end;

procedure TEngineBuffer.PublishUpdate;
begin
 // Backend-specific implementation is optional.
end;

procedure TEngineBuffer.WaitForPublish;
begin
 // Backend-specific implementation is optional.
end;

procedure TEngineBuffer.ResetPublishState;
begin
 // Backend-specific implementation is optional.
end;

 procedure TTexture.CloneFrom(from:TTexture);
  begin
   PixelFormat:=from.PixelFormat;
   left:=from.left;
   top:=from.top;
   width:=from.width;
   height:=from.height;
   u1:=from.u1; v1:=from.v1;
   u2:=from.u2; v2:=from.v2;
   stepU:=from.stepU; stepV:=from.stepV;
   mipmaps:=from.mipmaps;
   caps:=from.caps or tfCloned;
   name:=from.name+'_clone';
   if from.parent<>nil then
    parent:=from.parent
   else
    parent:=from;
   inc(parent.refCounter); // decremented in ResManGL.FreeImage when clone is freed
   fSrc:=from.src; // clones keep the source path, but must not override file lookup entries
  end;

function TTexture.HasFlag(flag:cardinal): boolean;
begin
 result:=caps and flag>0;
end;

function TTexture.ScanLine(y:integer):pointer;
begin
 result:=pointer(UIntPtr(data)+UIntPtr(y*pitch));
end;

function TTexture.PixelPtr(x,y:integer):pointer;
begin
 ASSERT((x>=0) and (y>=0) and (x<width) and (y<height));
 result:=pointer(UIntPtr(data)+UIntPtr(y*pitch+x*(pixelSize[pixelFormat] shr 3)));
end;

function TTexture.IsLocked:boolean;
begin
 result:=locked>0;
end;

procedure TTexture.MakeImmutable;
begin
 if IsLocked then
  raise EWarning.Create('Can''t make immutable while texture is locked: '+name);
 Bits.SetFlag(caps,tfReadOnly);
end;

destructor TTexture.Destroy;
 begin
  if (fSrc<>'') and (parent=nil) and not HasFlag(tfCloned) then
   texFileHash.Remove(fSrc);
  inherited;
 end;

procedure TTexture.SetSource(filename:string8);
 begin
  if (fSrc<>'') and (parent=nil) and not HasFlag(tfCloned) then
   texFileHash.Remove(fSrc);
  fSrc:=filename;
  if (fSrc<>'') and (parent=nil) and not HasFlag(tfCloned) then
   texFileHash.Put(fSrc,self);
 end;

function TTexture.Size:TSize;
 begin
  result.cx:=width;
  result.cy:=height;
 end;

class function TTexture.ClassHash: pointer;
 begin
  result:=@texturesHash;
 end;

function TTexture.Clone:TTexture;
 begin
  result:=ClassType.Create as TTexture;
  result.CloneFrom(self);
 end;

function TTexture.ClonePart(part:TRect): TTexture;
 begin
  result:=Clone;
  result.left:=left+part.Left;
  result.top:=top+part.Top;
  result.width:=part.Width;
  result.height:=part.Height;
  result.u1:=u1+part.left*stepU*2;
  result.u2:=u1+part.right*stepU*2;
  result.v1:=v1+part.top*stepV*2;
  result.v2:=v1+part.bottom*stepV*2;
 end;

class function TTexture.FindByFile(fileName:String8):TTexture;
var
 obj:TObject;
begin
 if texFileHash.Get(fileName,obj) then
  result:=obj as TTexture
 else
  result:=nil;
end;

{ TShader }
class function TShader.ClassHash: pointer;
 begin
  result:=@shadersHash;
 end;

class function TShader.VectorFromColor(color:cardinal):TQuat;
 var
  c:PARGBColor;
 begin
  c:=@color;
  result.x:=c.r/255;
  result.y:=c.g/255;
  result.z:=c.b/255;
  result.w:=c.a/255;
 end;

class function TShader.VectorFromColor3(color:cardinal): TVec3;
 var
  c:PARGBColor;
 begin
  c:=@color;
  result.x:=c.r/255;
  result.y:=c.g/255;
  result.z:=c.b/255;
 end;


{ TVertexBuffer }

constructor TVertexBuffer.Create(layout:TVertexLayout;count:integer;flags:cardinal=0);
 begin
  inherited Create(flags);
  self.layout:=layout;
  self.count:=count;
  sizeInBytes:=count*layout.stride;
 end;

{ TIndexBuffer }

constructor TIndexBuffer.Create(count,elementSize:integer;flags:cardinal=0);
 begin
  inherited Create(flags);
  self.count:=count;
  self.bytesPerIndex:=elementSize;
  sizeInBytes:=count*elementSize;
 end;

end.
