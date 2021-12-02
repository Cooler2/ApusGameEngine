// Base resource classes and types - extracted from Engine.API
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.Resources;
interface
 uses Apus.MyServis, Types, Apus.Classes, Apus.Images;

 const
  // Texture features flags
  tfCanBeLost      = 1;   // Texture data can be lost at any moment
  tfDirectAccess   = 2;   // CPU access allowed, texture can be locked
  tfNoRead         = 4;   // Reading of texture data is not allowed
  tfNoWrite        = 8;   // Writing to texture data is not allowed
  tfRenderTarget   = 16;  // Can be used as a target for GPU rendering
  tfAutoMipMap     = 32;  // MIPMAPs are generated automatically, don't need to fill manually
  tfNoLock         = 64;  // No need to lock the texture to access its data
  tfClamped        = 128; // By default texture coordinates are clamped (otherwise - not clamped)
  tfVidmemOnly     = 256; // Texture uses only VRAM (can't be accessed by CPU)
  tfSysmemOnly     = 512; // Texture uses only System RAM (can't be used by GPU)
  tfTexture        = 1024; // Texture corresponds to a texture object of the underlying API
  tfScaled         = 2048; // scale factors are used
  tfCloned         = 4096; // Texture object is cloned from another, so don't free any underlying resources
  tfPixelated      = 8192; // No interpolation allowed for sampling this texture

 type
  // –ежим интерпол€ции текстур
  TTexFilter=(fltUndefined,    // filter not defined
              fltNearest,      // Ѕез интерпол€ции
              fltBilinear,     // Ѕилинейна€ интерпол€ци€
              fltTrilinear,    // “рилинейна€ (только дл€ mip-map)
              fltAnisotropic); // јнизотропна€ (только дл€ mip-map)

  // Access mode for locked resources
  TLockMode=(lmReadOnly,       //< read-only (do not invalidate data when unlocked)
             lmReadWrite,      //< read+write (invalidate the whole area)
             lmCustomUpdate);  //< read+write, do not invalidate anything (AddDirtyRect is required, partial lock is not allowed in this case)

  // Ѕазовый абстрактный класс - текстура или ее часть
  TTexture=class(TNamedObject)
   src:String8; // file name if loaded from a file
   pixelFormat:TImagePixelFormat;
   width,height:integer; // dimension (in virtual pixels)
   left,top:integer; // position in the underlying resource
   mipmaps:byte; // кол-во уровней MIPMAP
   caps:cardinal; // возможности и флаги
   refCounter:integer; // number of child textures referencing this texture data
   parent:TTexture;    // reference to a parent texture
   // These properties are valid when texture is ONLINE (uploaded)
   u1,v1,u2,v2:single; // texture coordinates
   stepU,stepV:single; // halved texel step
   // These properties are valid when texture is LOCKED
   data:pointer;   // raw data
   pitch:integer;  // offset to next scanline

   // Create cloned image (separate object referencing the same image data). Original image can't be destroyed unless all its clones are destroyed
   procedure CloneFrom(src:TTexture); virtual;
   function Clone:TTexture; // Clone this texture and return the cloned instance
   function ClonePart(part:TRect):TTexture; // Create cloned instance for part of this texture
   procedure Clear(color:cardinal=$808080); // Clear and fill the texture with given color
   procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;rect:PRect=nil); virtual; abstract; // 0-й уровень - самый верхний
   function GetRawImage:TRawImage; virtual; abstract; // Create RAW image for the topmost MIP level (when locked)
   function IsLocked:boolean;
   procedure Unlock; virtual; abstract;
   procedure AddDirtyRect(rect:TRect); virtual; abstract; // mark area to update (when locked with mode=lmCustomUpdate)
   procedure GenerateMipMaps(count:byte); virtual; abstract; // —генерировать изображени€ mip-map'ов
   function HasFlag(flag:cardinal):boolean;
   // Limit texture filtering to the specified mode (i.e. bilinear mode disables mip-mapping)
   procedure SetFilter(filter:TTexFilter); virtual; abstract;
  protected
   locked:integer; // lock counter
   class function ClassHash:pointer; override;
  end;


implementation
 uses Apus.Structs;

 var
  textureHash:TObjectHash;

 procedure TTexture.CloneFrom(src:TTexture);
  begin
   PixelFormat:=src.PixelFormat;
   self.src:=src.src;
   left:=src.left;
   top:=src.top;
   width:=src.width;
   height:=src.height;
   u1:=src.u1; v1:=src.v1;
   u2:=src.u2; v2:=src.v2;
   stepU:=src.stepU; stepV:=src.stepV;
   mipmaps:=src.mipmaps;
   caps:=src.caps or tfCloned;
   name:=src.name;
   if src.parent<>nil then
    parent:=src.parent
   else
    parent:=src;
   inc(parent.refCounter);
  end;

function TTexture.HasFlag(flag: cardinal): boolean;
 begin
  result:=caps and flag>0;
 end;

function TTexture.IsLocked:boolean;
 begin
  result:=locked>0;
 end;

class function TTexture.ClassHash: pointer;
 begin
  result:=@textureHash;
 end;

procedure TTexture.Clear(color:cardinal);
 var
  pb:PByte;
  y:integer;
 begin
  Lock;
  pb:=data;
  for y:=0 to height-1 do begin
   FillDword(pb^,width,color);
   inc(pb,pitch);
  end;
  Unlock;
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


end.
