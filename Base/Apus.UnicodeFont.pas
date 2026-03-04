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
uses Apus.Core, Apus.Types;
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
  // get pixel opacity (0..15), coordinates are either relative to glyph top-left (y-down)
  // or relative to the output point (y-up)
  function GetPixel(glyphs:PByte;x,y:integer;glyphCoord:boolean=false):byte;
 end;

 TKernPair=record
  kernLeft,kernRight:cardinal; // 10 fields * 3 bit
 end;

 TUnicodeFont=class
  header:TFontHeader;
  chars:array of TCharDesc; // character descriptions
  advKerning:array of TKernPair; // advanced kerning pairs
  glyphs:array of byte; // glyph pixel data
  overPairs:array of cardinal; // character pairs (sorted, C1C1C2C2)
  overValues:array of byte;    // override values
  defaultCharIdx:integer;      // fallback glyph index for missing characters
  advancedKerning:boolean;
  maxY,minY:integer; // max and min lines occupied by any glyphs (+Y = top, -Y = bottom)
  constructor Create;
  constructor LoadFromMemory(const data:TBuffer;UseAdvKerning:boolean=false);
  constructor LoadFromFile(fname:string;UseAdvKerning:boolean=false);
  procedure InitDefaults; virtual;
  function IndexOfChar(ch:Char32):integer;
  function Interval(ch1,ch2:Char32):integer; // distance between start of ch1 and start of ch2
  procedure CalculateAdvKerning(index:integer);
  function GetTextWidth(st:String32):integer;
  function GetHeight:integer; // Height of characters like '0' or 'A'
  // Text/Glyph rendering  (no any clipping!)
  procedure RenderText(buf:pointer;pitch:integer;x,y:integer;st:String32;color:cardinal;scale:single=1);
  procedure DrawGlyph(buf:pointer;pitch:integer;x,y:integer;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  procedure DrawGlyphScaled(buf:pointer;pitch:integer;x1,y1,x2,y2:single;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
 private
  hash:array[0..4095] of word; // hash table for character index lookup
 end;

 function LoadFontFromFile(fname:string;UseAdvKerning:boolean=false):TUnicodeFont;
 function LoadFontFromMemory(const data:TBuffer;UseAdvKerning:boolean=false):TUnicodeFont;

implementation
 uses Apus.FastGFX, Apus.Files;

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

 // Alpha blending for glyph rendering
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
     // blending onto opaque background
     v1:=255-c2.a;
     result:=((c1.b*v1+c2.b*c2.a)*258 and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*258 and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*258 and $FF0000)+
             $FF000000;
   end else begin
     // blending onto semi-transparent background is more complex
     v1:=258*c1.a*(255-c2.a) shr 16;
     v:=65792 div (v1+c2.a);
     result:=((c1.b*v1+c2.b*c2.a)*v and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*v and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*v and $FF0000)+
             ($FF000000-(255-c1.a)*(255-c2.a)*66051 and $FF000000);
   end;
  end;

 // Draw glyph to ARGB buffer at original scale
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

 // Draw glyph with bilinear interpolation to ARGB buffer
 procedure TUnicodeFont.DrawGlyphScaled(buf:pointer;pitch:integer;x1,y1,x2,y2:single;
      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  var
   i:integer;
   gBuf:array of cardinal;
   gPitch:integer;
  begin
   ASSERT((glWidth>=0) and (glHeight>=0));
   // Clear temporary buffer
   gPitch:=(glWidth+2)*4;
   SetLength(gBuf,(glWidth+2)*(glHeight+2));
   for i:=0 to (glWidth+2)*(glHeight+2)-1 do
    gBuf[i]:=color and $FFFFFF;
   // Draw (extract) glyph image to the temporary ARGB buffer
   DrawGlyph(@gBuf[0],gPitch,1,1,glyphData,glWidth,glHeight,color);
   // Draw glyph from the temporary buffer to the target (with bilinear interpolation)
   StretchDraw2(@gBuf[0],gPitch,buf,pitch,x1,y1,x2,y2,1,1,glWidth+1,glHeight+1,blBlend);
  end;

 // Render text string to ARGB buffer
 procedure TUnicodeFont.RenderText(buf:pointer;pitch:integer;x,y:integer;st:String32;color:cardinal;scale:single=1);
  var
   i,idx:integer;
   px:single;
  begin
   if color and $FF000000=0 then exit;
   px:=x;
   for i:=0 to length(st)-1 do begin
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
     if i<length(st)-1 then px:=px+Interval(st[i],st[i+1])*scale;
   end;
  end;

 // TODO: lazy writes to advKerning are unsynchronized — if font instances are shared
 // across threads, this needs a lock or precomputation at load time
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
   data:=Files.LoadAsBytes(fname);
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
  Mem.Fill(hash,sizeof(hash),0);
  advancedKerning:=false;
  defaultCharIdx:=0;
 end;

constructor TUnicodeFont.LoadFromFile(fname:string;useAdvKerning:boolean);
 var
  data:ByteArray;
 begin
  data:=Files.LoadAsBytes(fname);
  LoadFromMemory(TBuffer.CreateFrom(data),UseAdvKerning);
 end;

constructor TUnicodeFont.LoadFromMemory(const data:TBuffer;useAdvKerning:boolean);
 var
  i,j,s,ofs,metadata,size:integer;
  ch:WideChar;
  found:boolean;
  w:word;
 begin
   InitDefaults;
   data.Read(header,sizeof(header));
   if header.id<>UnicodeFontSignature then
    raise EError.Create('Invalid font data!');
   // Skip metadata
   if header.flags and fMetadata>0 then begin
    metadata:=data.ReadInt;
    if metadata<4 then
     raise EError.Create('Invalid font metadata size');
    data.Skip(metadata-4);
   end else
    metadata:=0;
   // Load descriptions
   if header.charCount=0 then
    raise EError.Create('Invalid font data: no glyphs');
   setLength(chars,header.charCount);
   s:=0; minY:=0; maxY:=0;
   ofs:=sizeof(TFontHeader)+sizeof(TCharDesc)*header.charCount+metadata;
   size:=sizeof(TCharDesc)*header.charCount;
   if size>0 then
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
   if s<0 then
    raise EError.Create('Invalid font data: glyph block size');
   setLength(glyphs,s);
   if s>0 then
    data.Read(glyphs[0],s);
   // Validate glyph offsets
   for i:=0 to header.charCount-1 do
    with chars[i] do begin
     j:=((imageWidth+1) div 2)*imageHeight; // glyph data size in bytes
     if (offset<0) or (offset+j>s) then
      raise EError.Create('Invalid font data: glyph offset out of bounds (%d)',[i]);
    end;
   // Load overrides
   i:=header.overridesCount;
   SetLength(overPairs,i);
   SetLength(overValues,i);
   if i>0 then begin
    data.Read(overPairs[0],i*4);
    for j:=0 to i-1 do // swap 16-bit halves: file stores C2C2C1C1, we need C1C1C2C2
     overpairs[j]:=Bits.SwapWords(overpairs[j]);
    data.Read(overValues[0],i);
   end;

   found:=false;
   for i:=0 to high(chars) do
    if chars[i].charcode='#' then begin
     defaultCharIdx:=i;
     found:=true;
     break;
    end;
   if not found then
    for i:=0 to high(chars) do
     if chars[i].charcode='?' then begin
      defaultCharIdx:=i;
      break;
     end;
   if UseAdvKerning then begin
    advancedKerning:=true;
    SetLength(advkerning,length(chars));
    Mem.Fill(advKerning[0],length(chars)*sizeof(TKernPair),$FF);
   end;
 end;


function TUnicodeFont.GetHeight: integer;
 var
  i:integer;
 begin
  i:=IndexOfChar(Char32('0'));
  result:=chars[i].imageHeight;
 end;

function TUnicodeFont.GetTextWidth(st:String32):integer;
 var
  i,index:integer;
 begin
  result:=0;
  if length(st)=0 then exit;
  for i:=0 to length(st)-2 do begin
   inc(result,Interval(st[i],st[i+1]));
  end;
  index:=IndexOfChar(st[length(st)-1]);
  if st[length(st)-1]=ord(' ') then
   inc(result,chars[index].width)
  else
   inc(result,chars[index].imageWidth+chars[index].imageX);
 end;

function TUnicodeFont.IndexOfChar(ch:Char32):integer;
 var
  i,h:integer;
  wch:WideChar;
 begin
  if ch>$FFFF then begin
   result:=defaultCharIdx;
   exit;
  end;
  wch:=WideChar(ch);
  h:=ord(ch) and $FFF;
  result:=hash[h];
  if chars[result].charcode<>wch then begin
   for i:=0 to Length(chars)-1 do
    if chars[i].charcode=wch then begin
     hash[h]:=i;
     result:=i;
     exit;
    end;
   result:=defaultCharIdx;
  end;
 end;

function TUnicodeFont.Interval(ch1,ch2:Char32):integer;
var
 i1,i2,y,v,a,b:integer;
 c,k1,k2:cardinal;
begin
 if ch1=$FEFF then begin
  result:=0; exit;
 end;
 i1:=IndexOfChar(ch1);
 i2:=IndexOfChar(ch2);
 if (ch1<=$FFFF) and (ch2<=$FFFF) and (chars[i1].flags and gfOverrides>0) then begin
  // find override
  c:=cardinal(ch1 and $FFFF) shl 16+cardinal(ch2 and $FFFF);
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
   k2:=advKerning[i2].kernLeft;
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

end.
