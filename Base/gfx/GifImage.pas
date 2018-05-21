// Support for GIF image format
//
// Copyright (C) 2015 Apus Software
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit GifImage;
interface
 uses SysUtils,types;

 // Pack 32 bpp image to GIF format
 function RAWtoGif(data:pointer;pitch,width,height:integer):TByteDynArray;

implementation
 type
  TPalette=array[0..255] of cardinal;

 //
 procedure BuildPalette(data:pointer;pitch,width,height:integer;out pal:TPalette;out colors:integer);
  var
   pc:PCardinal;
   x,y:integer;
  begin
   for y:=0 to height-1 do begin
    pc:=data; inc(pc,pitch*y);
    for x:=0 to width-1 do begin
     inc(pc);
    end;
   end;
  end;

 function ConvertRGBtoIndexed(data:pointer;pitch,width,height:integer;var pal:TPalette;var colors:integer):pointer;
  var
   pc:PCardinal;
   x,y:integer;
  begin
   GetMem(result,width*height);

  end;

 function RAWtoGif(data:pointer;pitch,width,height:integer):TByteDynArray;
  begin

  end;

end.
