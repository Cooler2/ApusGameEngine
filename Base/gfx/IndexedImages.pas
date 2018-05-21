// Support for 8-bit indexed images: palette building, conversion, dithering etc...
//
// Copyright (C) 2015 Apus Software
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit IndexedImages;
interface
 type
  TPalette=array[0..255] of cardinal;

 // data, pitch, width, height - source 32bpp image (ARGB or XRGB)
 // transpMode can be a)color ($00RRGGBB) - treat this color as transparent,
 //    b) $AAxxxxxx - use alpha channel, any color with alpha<AA is transparent
 // usedColors - number of colors already stored in palette
 // maxColors - target palette size (must be >usedColors)
 // Returns: number of colors in palette (all colors has format $FFRRGGBB, except transparent - $00000000)
 function BuildSelectivePalette(data:pointer;pitch,width,height:integer;transpMode:cardinal;
     var pal:TPalette;usedColors,maxColors:integer):integer;

implementation

 function BuildSelectivePalette(data:pointer;pitch,width,height:integer;transpMode:cardinal;var pal:TPalette;usedColors,maxColors:integer):integer;
  var
   pc:PCardinal;
   c:cardinal;
   x,y,n,i:integer;
   cmap:array[0..4095] of byte;
  begin
   n:=width*height;
   if n>4000 then n:=4000;
   pitch:=pitch div 4;
   for i:=1 to n do begin
    x:=random(width); y:=random(height);
    pc:=data; inc(pc,x+y*pitch);
    c:=pc^;
   end;

  end;

end.
