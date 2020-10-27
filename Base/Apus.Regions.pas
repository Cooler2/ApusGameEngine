// Region class and it's functionality
//
// Copyright (C) Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Regions;
interface
 uses Apus.Images, Types;
type
 // область произвольной формы
 TRegion=class
  procedure Invert; virtual; abstract;
  function TestPoint(x,y:single):boolean; virtual; abstract;
 end;

 // регион, основанный на прямоугольниках
 TRectRegion=class(TRegion)
  width,height:integer;
  r1,r2:array of TRect;
  constructor Create(w,h:integer);
  procedure IncludeRect(r:TRect);
  procedure ExcludeRect(r:TRect);
 end;

 { Data format:
   1. array[0..height-1] of records (offset in words,count:word)
   2. actual data (high order bit means opacity)
 }

 TBasicRegion=class(TRegion)
  width,height:integer;
  data:array of word;
  // Create rectangular region
  constructor Create(w,h:integer);
  // Create region from image (if pixel and trMask=trColor then pixel is opaque)
  constructor CreateFrom(img:TRawImage;trColor,trMask:integer);
  procedure Invert; override;
  function TestPoint(x,y:single):boolean; override;
 end;

 TBitmapRegion=class(TRegion)
  constructor LoadFromBMP(fname:string);
  constructor CreateFromImage(image:TRawImage;downscale:integer=1;threshold:byte=$80);
  function TestPoint(x,y:single):boolean; override;
  destructor Destroy; override;
 private
  data:array of byte;
  linesize:integer;
  bmWidth,bmHeight:integer;
  flipY:boolean;
 end;

implementation

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

{ TRegion }

constructor TBasicRegion.Create;
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

constructor TBasicRegion.CreateFrom(img: TRawImage; trColor, trMask: integer);
var
 x,y:integer;
 size,pos,v:integer;
 pb:PByte;
begin
 width:=img.width;
 height:=img.height;
 size:=10000;
 setLength(data,size);
 img.Lock;
 pos:=height*2;
 for y:=0 to height-1 do begin
  v:=0; pb:=img.data;
  inc(pb,y*img.pitch);
  for x:=0 to width-1 do begin

  end;
 end;
 img.Unlock;
end;

procedure TBasicRegion.Invert;
var
 i:integer;
begin
 for i:=height*2 to length(data)-1 do
  data[i]:=data[i] xor $8000;
end;

function TBasicRegion.TestPoint(x, y: single): boolean;
begin

end;

{ TBitmapRegion }

destructor TBitmapRegion.Destroy;
begin

end;

constructor TBitmapRegion.LoadFromBMP(fname: string);
var
 f:file;
 hdr:TBitmapHeader;
 size:integer;
begin
 assign(f,fname);
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

constructor TBitmapRegion.CreateFromImage(image:TRawImage;downscale:integer=1;threshold:byte=$80);
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

function TBitmapRegion.TestPoint(x, y: single): boolean;
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

{ TRectRegion }

constructor TRectRegion.Create(w, h: integer);
begin

end;

procedure TRectRegion.ExcludeRect(r: TRect);
begin

end;

procedure TRectRegion.IncludeRect(r: TRect);
begin

end;

end.

