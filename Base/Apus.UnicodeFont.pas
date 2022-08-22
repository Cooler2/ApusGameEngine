// Support for in-house raster font file format

// Copyright (C) Apus Software, 2011. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

// Font File format:
// - Header (TFontHeader structure, 32 bytes)
// - Metadata (if ffMetadata is in header flags)
// - Array of char descriptions (charCount*TCharDesc)
// - Glyph data
// - Overrides (overridesCount*5 bytes)
//
// Metadata format:
// - Total metadata size (including this field, 4 byte)
// - Blocks:
//   - Block type (2 bytes)
//   - Block data size (2 bytes)
unit Apus.UnicodeFont;
interface
uses Apus.Types;
const
 UnicodeFontSignature=$F75001C1;
 // Font flags
 fBold=1;
 fItalic=2;
 fExtendedKerning=64; // 32-bit kerning from metadata should be used
 fMetadata=128; // Metadata follows header

 // Glyph flags
 gfCustomKerning = 1; // Kerning was set manually (don't recalculate automatically)
 gfOverrides     = 2; // There are interval overrides for this char


 // Metadata types
 fmdCreationSettings = 1; // Font creation settings in textual format

 autoKernParameter:integer=4;
type
 str15=string[15];

 TFontHeader=packed record
  id:cardinal;            // Signature
  FontName:str15;         // Font family
  Height:byte;            // Height of characters like A..Z (in pixels)
  width:byte;             // Average font width (in 0.2 px units)
  flags:byte;             // Global flags
  baseline:byte;          // Distance from the topmost used pixel
  reserved:integer;
  charCount:word;         // number of glyphs
  overridesCount:word;    // number of override char distance values
 end;

 // Description of a char
 TCharDesc=packed record
  charcode:WideChar;       // unicode character
  imageWidth,imageHeight:byte; // size of glyph
  imageX,imageY:shortint;  // position of top-left glyph corner relative to output position
  width,flags:byte;        // width of a character (px)
  kernLeft,kernRight:word; // kerning mask (3 bits * 5 fields, from top to bottom)
  offset:integer;          // position of glyph data in file (or in glyphs array in memory)
  // get pixel opacity (0..15) (координаты либо относительно верхнего-левого угла глифа (y-вниз), либо
  // относительно точки вывода символа (y-вверх)
  function GetPixel(glyphs:PByte;x,y:integer;glyphCoord:boolean=false):byte;
 end;

 TKernPair=record
  kernLeft,kernRight:cardinal; // 10 fields * 3 bit
 end;

 TUnicodeFont=class
  header:TFontHeader;
  chars:array of TCharDesc; // описания символов
  advKerning:array of TKernPair; // расширенный кернинг
  glyphs:array of byte; // данные глифов
  overPairs:array of cardinal; // character pairs (sorted, C1C1C2C2)
  overValues:array of byte;    // override values
  defaultCharIdx:integer;      // индекс символа, заменяющего отсутствующие в шрифте символы
  advancedKerning:boolean;
  maxY,minY:integer; // max and min lines occupied by any glyphs (+Y = top, -Y = bottom)
  constructor Create;
  constructor LoadFromMemory(const data:TBuffer;UseAdvKerning:boolean=false);
  constructor LoadFromFile(fname:string;UseAdvKerning:boolean=false);
  procedure InitDefaults; virtual;
  function IndexOfChar(ch:WideChar):integer;
  function Interval(ch1,ch2:WideChar):integer; // интервал между точкой начала символа ch1 и следующего за ним ch2
  procedure CalculateAdvKerning(index:integer);
  function GetTextWidth(st:WideString):integer;
  function GetHeight:integer; // Height of characters like '0' or 'A'
  // Text/Glyph rendering  (no any clipping!)
  procedure RenderText(buf:pointer;pitch:integer;x,y:integer;st:WideString;color:cardinal;scale:single=1);
  procedure DrawGlyph(buf:pointer;pitch:integer;x,y:integer;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  procedure DrawGlyphScaled(buf:pointer;pitch:integer;x1,y1,x2,y2:single;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
 private
  hash:array[0..4095] of word; // хэш для поиска индекса символа
 end;

 function LoadFontFromFile(fname:string;UseAdvKerning:boolean=false):TUnicodeFont;
 function LoadFontFromMemory(const data:TBuffer;UseAdvKerning:boolean=false):TUnicodeFont;

implementation
 uses Apus.MyServis, Apus.FastGFX;

 function TCharDesc.GetPixel(glyphs:PByte;x,y:integer;glyphCoord:boolean=false):byte;
  begin
   if not glyphCoord then begin
     x:=x-imageX;
     y:=imageY-y;
   end;
   result:=0;
   if (x<0) or (y<0) or (x>=imageWidth) or (y>=imageHeight) then exit;
   inc(glyphs,offset+y*((imageWidth+1) shr 1)+x shr 1);
   if x and 1=0 then
     result:=glyphs^ and $F
   else
     result:=glyphs^ shr 4;
  end;

 type
  TARGBcolor=packed record
   b,g,r,a:byte;
  end;

 var
  gammaTab:array[0..8,0..15] of byte;

 // Специальный альфа-блендинг
 function Blend(background,foreground:cardinal;alpha:byte):cardinal;
  var
   v1,v2:byte;
   c1:TARGBColor absolute background;
   c2:TARGBColor absolute foreground;
   v:cardinal;
  begin
   c2.a:=(c2.a*alpha*17) shr 8;
   if c2.a>=254 then begin
    result:=foreground; exit;
   end;
   if c1.a=255 then begin
     // блендинг на непрозрачную основу
     v1:=255-c2.a;
     result:=((c1.b*v1+c2.b*c2.a)*258 and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*258 and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*258 and $FF0000)+
             $FF000000;
   end else begin
     // блендинг на полупрозрачную основу несколько сложнее
     v1:=258*c1.a*(255-c2.a) shr 16;
     v:=65792 div (v1+c2.a);
     result:=((c1.b*v1+c2.b*c2.a)*v and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*v and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*v and $FF0000)+
             ($FF000000-(255-c1.a)*(255-c2.a)*66051 and $FF000000);
   end;
  end;

 // Отрисовка глифа в ARGB-буфер в оригинальном масштабе
 procedure TUnicodeFont.DrawGlyph(buf:pointer;pitch:integer;x,y:integer;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  var
   pb:PByte;
   pc:PCardinal;
   cx,cy:integer;
   v:byte;
  begin
   pitch:=pitch shr 2;
   for cy:=0 to glHeight-1 do begin
     pc:=buf; inc(pc,pitch*(y+cy)+x);
     pb:=glyphData; inc(pb,cy*((glWidth+1) shr 1));
     for cx:=0 to glWidth-1 do begin
       if cx and 1=0 then
         v:=pb^ and $F
       else begin
         v:=pb^ shr 4; inc(pb);
       end;
       if v>0 then
         pc^:=Blend(pc^,color,v);
       inc(pc);
     end;
   end;
  end;

 // Отрисовка глифа с интерполяцией в заданный ARGB-буфер
 procedure TUnicodeFont.DrawGlyphScaled(buf:pointer;pitch:integer;x1,y1,x2,y2:single;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  var
   i:integer;
   gBuf:array[0..1600] of cardinal;
   gPitch:integer;
  begin
   // Clear temporary buffer
   gPitch:=(glWidth+2)*4;
   for i:=0 to (glWidth+2)*(glHeight+2)-1 do
    gBuf[i]:=color and $FFFFFF;
   // Draw (extract) glyph image to the temporary ARGB buffer
   DrawGlyph(@gBuf,gPitch,1,1,glyphData,glWidth,glHeight,color);
   // Draw glyph from the temporary buffer to the target (with bilinear interpolation)
   StretchDraw2(@gBuf,gPitch,buf,pitch,x1,y1,x2,y2,1,1,glWidth+1,glHeight+1,blBlend);
  end;

 // Отрисовка текста в заданный ARGB-буфер
 procedure TUnicodeFont.RenderText(buf:pointer;pitch:integer;x,y:integer;st:WideString;color:cardinal;scale:single=1);
  var
   i,idx:integer;
   px:single;
  begin
   if color and $FF000000=0 then exit;
   px:=x;
   for i:=1 to length(st) do begin
     idx:=IndexOfChar(st[i]);
     with chars[idx] do
       if imageWidth>0 then begin // non-empty glyph
         if scale=1 then
           DrawGlyph(buf,pitch,round(px)+imageX,y-imageY,
                     @glyphs[offset],imageWidth,imageHeight,color)
         else
           DrawGlyphScaled(buf,pitch,
                           round(px)+imageX*scale,
                           y-imageY*scale,
                           round(px)+(imageX+imageWidth)*scale,
                           y-(imageY-imageHeight)*scale,
                           @glyphs[offset],imageWidth,imageHeight,color);
     end;
     if i<length(st) then px:=px+Interval(st[i],st[i+1])*scale;
   end;
  end;

 procedure TUnicodeFont.CalculateAdvKerning(index:integer);
  var
   i,y,y1,y2,x:integer;
   l,r:integer;
   step:single;
  begin
   advKerning[index].kernLeft:=0;
   advKerning[index].kernRight:=0;
   if chars[index].imageWidth=0 then exit;
   step:=(maxY-minY)/10;
   for i:=0 to 9 do
    with chars[index] do begin // 10 horizontal bands
     y1:=round(maxY-i*step);
     y2:=round(maxY-(i+1)*step);
     x:=(imageWidth+1) div 3;
     if x>7 then x:=7;
     l:=x; r:=x;
     for y:=y2 to y1 do // for each row in a band
      if (y<=imageY) and (y>imageY-imageHeight) then begin
       for x:=0 to l-1 do
        if GetPixel(@glyphs[0],x,imageY-y,true)>autoKernPArameter then begin
         l:=x; break;
        end;
       for x:=0 to r-1 do
        if GetPixel(@glyphs[0],imageWidth-x-1,imageY-y,true)>autoKernPArameter then begin
         r:=x; break;
        end;
      end;
     inc(advKerning[index].kernLeft,cardinal(l) shl (i*3));
     inc(advKerning[index].kernRight,cardinal(r) shl (i*3));
    end;
  end;

 function LoadFontFromFile(fname:string;UseAdvKerning:boolean=false):TUnicodeFont;
  var
   data:ByteArray;
  begin
   data:=LoadFileAsBytes(fname);
   result:=LoadFontFromMemory(TBuffer.CreateFrom(data),useAdvKerning);
  end;

 function LoadFontFromMemory(const data:TBuffer;UseAdvKerning:boolean=false):TUnicodeFont;
  begin
   result:=TUnicodeFont.LoadFromMemory(data,UseAdvKerning);
  end;

{ TUnicodeFont }

constructor TUnicodeFont.Create;
 begin
  InitDefaults;
 end;

procedure TUnicodeFont.InitDefaults;
 begin
  fillchar(hash,sizeof(hash),0);
  advancedKerning:=false;
 end;

constructor TUnicodeFont.LoadFromFile(fname:string;useAdvKerning:boolean);
 var
  data:ByteArray;
 begin
  data:=LoadFileAsBytes(fname);
  LoadFromMemory(TBuffer.CreateFrom(data),UseAdvKerning);
 end;

constructor TUnicodeFont.LoadFromMemory(const data:TBuffer;useAdvKerning:boolean);
 var
  i,j,s,ofs,metadata,size:integer;
  ch:WideChar;
  w:word;
 begin
   InitDefaults;
   data.Read(header,sizeof(header));
   if header.id<>UnicodeFontSignature then
    raise EError.Create('Invalid font data!');
   // Skip metadata
   if header.flags and fMetadata>0 then begin
    metadata:=data.ReadInt;
   end else
    metadata:=0;
   data.Skip(metadata-4);
   // Load descriptions
   setLength(chars,header.charCount);
   s:=0; minY:=0; maxY:=0;
   ofs:=sizeof(TFontHeader)+sizeof(TCharDesc)*header.charCount+metadata;
   size:=sizeof(TCharDesc)*header.charCount;
   data.Read(chars[0],size);
   for i:=0 to header.charCount-1 do begin
    inc(s,((chars[i].imageWidth+1) div 2)*chars[i].imageHeight);
    dec(chars[i].offset,ofs);
    ch:=chars[i].charcode;
    hash[ord(ch) and 4095]:=i;
    with chars[i] do begin
     if imageY>maxY then maxY:=imageY;
     if imageY-imageHeight<minY then minY:=imageY-imageHeight;
    end;
   end;
   // Load glyph data
   s:=data.size-sizeof(header)-metadata-
      header.charCount*sizeof(TCharDesc)-header.overridesCount*5;
   setLength(glyphs,s);
   data.Read(glyphs[0],s);
   // Load overrides
   i:=header.overridesCount;
   SetLength(overPairs,i);
   SetLength(overValues,i);
   if i>0 then data.Read(overPairs[0],i*4);
   for i:=0 to length(overpairs)-1 do
    overpairs[i]:=overpairs[i] and $FFFF shl 16+overpairs[i] shr 16;
   if i>0 then data.Read(overValues[0],i);

   defaultCharIdx:=IndexOfChar('#');
   if UseAdvKerning then begin
    advancedKerning:=true;
    SetLength(advkerning,length(chars));
    fillchar(advKerning[0],length(chars)*sizeof(TKernPair),$FF);
   end;
 end;


function TUnicodeFont.GetHeight: integer;
 var
  i:integer;
 begin
  i:=IndexOfChar('0');
  result:=chars[i].imageHeight;
 end;

function TUnicodeFont.GetTextWidth(st: WideString): integer;
 var
  i,index:integer;
 begin
  result:=0;
  if length(st)=0 then exit;
  for i:=1 to length(st)-1 do begin
   inc(result,Interval(st[i],st[i+1]));
  end;
  index:=IndexOfChar(st[length(st)]);
  if st[length(st)]=' ' then
   inc(result,chars[index].width)
  else
   inc(result,chars[index].imageWidth+chars[index].imageX);
 end;

function TUnicodeFont.IndexOfChar(ch: WideChar): integer;
 var
  i,h:integer;
 begin
  h:=ord(ch) and $FFF;
  result:=hash[h];
  if chars[result].charcode<>ch then begin
   for i:=0 to Length(chars)-1 do
    if chars[i].charcode=ch then begin
     hash[h]:=i;
     result:=i;
     exit;
    end;
   result:=defaultCharIdx;
  end;
 end;

function TUnicodeFont.Interval(ch1: WideChar; ch2: WideChar):integer;
var
 i1,i2,y,v,a,b:integer;
 c,k1,k2:cardinal;
begin
 if ch1=#$FEFF then begin
  result:=0; exit;
 end;
 i1:=IndexOfChar(ch1);
 i2:=IndexOfChar(ch2);
 if chars[i1].flags and gfOverrides>0 then begin
  // find override
  c:=ord(ch1) shl 16+ord(ch2);
  a:=0; b:=length(overPairs)-1;
  if b>=0 then begin
   while a<>b do begin
    if overPairs[(a+b) div 2]<c then a:=(a+b) div 2+1
     else b:=(a+b) div 2;
   end;
   if overPairs[a]=c then begin
    result:=overValues[a];
    exit;
   end;
  end; // else - font internal error: gfOverride is wrong
 end;
 // kerning
 if advancedKerning then begin
  result:=10;
  k1:=advKerning[i1].kernRight;
  if k1=$FFFFFFFF then begin
   CalculateAdvKerning(i1);
   k1:=advKerning[i1].kernRight;
  end;
  k2:=advKerning[i2].kernLeft;
  if k2=$FFFFFFFF then begin
   CalculateAdvKerning(i2);
   k2:=advKerning[i2].kernRight;
  end;
  for y:=0 to 9 do begin
   v:=(k1 and 7)+(k2 and 7);
   if v<result then result:=v;
   k1:=k1 shr 3;
   k2:=k2 shr 3;
  end;
  result:=chars[i1].width+1-result;
 end else begin
  result:=10;
  k1:=chars[i1].kernRight;
  k2:=chars[i2].kernLeft;
  for y:=0 to 4 do begin
   v:=(k1 and 7)+(k2 and 7);
   if v<result then result:=v;
   k1:=k1 shr 3;
   k2:=k2 shr 3;
  end;
  result:=chars[i1].width-result;
 end;
end;

var
 i,j:integer;
 v,e:single;
initialization
 // Gamma table calculation
 for i:=0 to 8 do begin
  gammaTab[i,0]:=0;
  for j:=1 to 15 do begin
   e:=(i+6)/10;
   v:=j/15;
   v:=exp(ln(v)*e);
   gammaTab[i,j]:=round(128*v);
  end;
 end;
end.
