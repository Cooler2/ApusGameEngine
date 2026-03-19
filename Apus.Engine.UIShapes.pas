// UI element hit-test shape classes
//
// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.UIShapes;
interface
 uses Apus.Images;
type
 // Abstract base for UI element hit-test shapes.
 // If persistent=true, the owning TUIElement will NOT free this object.
 TUIShape=class
  persistent:boolean;
  function IsOpaque(x,y:single):boolean; virtual; abstract;
  class function ShapeEmpty:TUIShape; static;
  class function ShapeFull:TUIShape; static;
 end;

 // Bitmap-based shape: each pixel's opacity is determined by the alpha channel of a source image.
 // Coordinates passed to IsOpaque are normalized to [0..1] range.
 TUIBitmapShape=class(TUIShape)
  constructor LoadFromBMP(fname:string);
  constructor CreateFromImage(image:TRawImage; downscale:integer=1; threshold:byte=$80);
  function IsOpaque(x,y:single):boolean; override;
  destructor Destroy; override;
 private
  data:array of byte;
  linesize:integer;
  bmWidth,bmHeight:integer;
  flipY:boolean;
 end;

 // Row-based shape (compact RLE representation)
 TUIBasicShape=class(TUIShape)
  width,height:integer;
  data:array of word;
  constructor Create(w,h:integer);
  constructor CreateFrom(img:TRawImage; trColor,trMask:integer);
  procedure Invert;
  function IsOpaque(x,y:single):boolean; override;
 end;

var
 shapeEmpty:TUIShape; // persistent: always transparent (passes mouse events through)
 shapeFull:TUIShape;  // persistent: always opaque (captures all mouse events)

implementation
 uses Apus.Conv, Apus.Files;

type
 TUIFullShape=class(TUIShape)
  function IsOpaque(x,y:single):boolean; override;
 end;
 TUIEmptyShape=class(TUIShape)
  function IsOpaque(x,y:single):boolean; override;
 end;

{ TUIFullShape }

function TUIFullShape.IsOpaque(x,y:single):boolean;
 begin
  result:=true;
 end;

{ TUIEmptyShape }

function TUIEmptyShape.IsOpaque(x,y:single):boolean;
 begin
  result:=false;
 end;

{ TUIBitmapShape }

destructor TUIBitmapShape.Destroy;
 begin
  inherited;
 end;

constructor TUIBitmapShape.LoadFromBMP(fname:string);
type
 TBitmapHeader=packed record
  signature:word;
  filesize:cardinal;
  reserved:cardinal;
  dataOffset:cardinal;
  hdrsize:cardinal;
  width,height:integer;
  planes,bpp:word;
  compression:word;
 end;
var
 f:file;
 hdr:TBitmapHeader;
 size:integer;
 begin
  assign(f,Files.FixName(fname));
  reset(f,1);
  blockread(f,hdr,sizeof(hdr));
  linesize:=4*((hdr.width*hdr.bpp+31) div 32);
  seek(f,hdr.dataOffset);
  size:=linesize*hdr.height;
  setLength(data,size);
  blockread(f,data[0],size);
  close(f);
  bmWidth:=hdr.width;
  bmHeight:=hdr.height;
  flipY:=true;
 end;

constructor TUIBitmapShape.CreateFromImage(image:TRawImage; downscale:integer=1; threshold:byte=$80);
var
 x,y:integer;
 pc:PCardinal;
 pb:PByte;
 size:integer;
 value:byte;
 begin
  flipY:=false;
  ASSERT(image.pixelFormat in [ipfARGB,ipfABGR]);
  image.Lock;
  try
   bmWidth:=image.width div downscale;
   bmHeight:=image.height div downscale;
   linesize:=4*((bmWidth+31) div 32); // line size in bytes, 32-bit aligned
   size:=lineSize*bmHeight;
   Setlength(data,size);
   for y:=0 to bmHeight-1 do begin
    pb:=@data[y*lineSize];
    pc:=image.data;
    inc(pc,y*downscale*(image.pitch div 4));
    for x:=0 to bmWidth-1 do begin
     value:=pc^ shr 24;
     if value>threshold then pb^:=pb^ or ($80 shr (x and 7));
     inc(pc,downscale);
     if x and 7=7 then inc(pb);
    end;
   end;
  finally
   image.Unlock;
  end;
 end;

function TUIBitmapShape.IsOpaque(x,y:single):boolean;
var
 pos,bit:integer;
 ix,iy:integer;
 begin
  result:=false;
  if (x<0) or (y<0) or (x>=1) or (y>=1) then exit;
  if flipY then y:=1-y;
  ix:=round(x*(bmWidth-1));
  iy:=round(y*(bmHeight-1));
  pos:=ix shr 3;
  bit:=ix and 7;
  if data[linesize*iy+pos] and ($80 shr bit)>0 then result:=true;
 end;

{ TUIBasicShape }

constructor TUIBasicShape.Create(w,h:integer);
var
 i:integer;
 begin
  width:=w; height:=h;
  setlength(data,h*6);
  for i:=0 to h-1 do begin
   data[i*2]:=h*2+i;
   data[i*2+1]:=1;
   data[h*2+i]:=$8000+w;
  end;
 end;

constructor TUIBasicShape.CreateFrom(img:TRawImage; trColor,trMask:integer);
 begin
  ASSERT(false,'Not implemented');
 end;

procedure TUIBasicShape.Invert;
var
 i:integer;
 begin
  for i:=height*2 to length(data)-1 do
   data[i]:=data[i] xor $8000;
 end;

function TUIBasicShape.IsOpaque(x,y:single):boolean;
 begin
  result:=false;
 end;

{ TUIShape }

class function TUIShape.ShapeEmpty: TUIShape;
begin
  result:=Apus.Engine.UIShapes.shapeEmpty;
end;

class function TUIShape.ShapeFull: TUIShape;
begin
  result:=Apus.Engine.UIShapes.shapeFull;
end;

initialization
 shapeEmpty:=TUIEmptyShape.Create;
 shapeEmpty.persistent:=true;
 shapeFull:=TUIFullShape.Create;
 shapeFull.persistent:=true;
end.
