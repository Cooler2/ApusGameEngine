// Region class and it's functionality
//
// Copyright (C) Apus Software
// apussoftware@games4win.com
unit Regions;
interface
 uses Images,types;
type
 // область произвольной формы
 TRegion=class
  width,height:integer;
  procedure Invert; virtual; abstract;
  function TestPoint(x,y:integer):boolean; virtual; abstract;
 end;

 // регион, основанный на прямоугольниках
 TRectRegion=class(TRegion)
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
  data:array of word;
  // Create rectangular region
  constructor Create(w,h:integer);
  // Create region from image (if pixel and trMask=trColor then pixel is opaque)
  constructor CreateFrom(img:TRawImage;trColor,trMask:integer);
  procedure Invert; override;
  function TestPoint(x,y:integer):boolean; override;
 end;

 TBitmapRegion=class(TRegion)
  data:array of byte;
  linesize:integer;
  scale:byte;
  bmWidth,bmHeight:integer;
  constructor LoadFromBMP(fname:string;bmpscale:byte);
//  procedure CreateFrom
  function TestPoint(x,y:integer):boolean; override;
  destructor Destroy; override;
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

function TBasicRegion.TestPoint(x, y: integer): boolean;
begin

end;

{ TBitmapRegion }

destructor TBitmapRegion.Destroy;
begin

end;

constructor TBitmapRegion.LoadFromBMP(fname: string;bmpscale:byte);
var
 f:file;
 hdr:TBitmapHeader;
 size:integer;
begin
 scale:=bmpscale;
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
 width:=bmWidth*scale;
 height:=bmHeight*scale;
end;

function TBitmapRegion.TestPoint(x, y: integer): boolean;
var
 pos,bit:integer;
begin
 result:=false;
 dec(x); dec(y);
 if (x<0) or (y<0) or (x>=width) or (y>=height) then exit;
 if scale>1 then begin
  x:=x div scale;
  y:=y div scale;
 end;
 if (x>=bmWidth) or (y>=bmHeight) then exit;
 pos:=x div 8;
 bit:=x mod 8;
 y:=bmHeight-y-1;
 if data[linesize*y+pos] and ($80 shr bit)>0 then result:=true;
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

