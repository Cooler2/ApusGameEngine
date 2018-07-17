// This universal unit is intended to performing different
// filters onto custom bitmap images (low-level operations)
// Copyright (C) 2002 Apus Software (www.games4win.com, ivan@apus-software.com)

{$R-}

unit filters;
interface
 uses geom3d;

type
 BlurType=(Light,Normal,Fast);

// ------------
// BLUR FILTERS
// Common parameters: buf - pointer to upper left buffer pixel, lPitch - offset to next scanline (can be negative)

// Perform 4/8 blur of the rectangle on 32-bit image
procedure LightBlur32(buf:pointer;x1,y1,x2,y2,lPitch:integer);

// Perform 0/4 blur of the rectangle on 32-bit image
function Blur32(buf:pointer;pitch,width,height:integer;target:pointer=nil;tPitch:integer=0):pointer;

// -4/8 sharpen filter (strength = 0-256)
function Sharpen(buf:pointer;pitch,width,height,strength:integer;inplace:boolean=true):pointer;

// Perform draft blur of the rectangle in horizontal direction (dist is the blur distance)
procedure DraftBlur32X(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);

// Perform draft blur of the rectangle in vertical direction (dist is the blur distance)
procedure DraftBlur32Y(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);

// ------------------------------------------------
// The same procedures for 8-bit (grayscale/alpha) images

// Perform 4/8 blur of the rectangle on 8-bit image
function LightBlur8(buf:pointer;pitch,width,height:integer;inplace:boolean=true):pointer;

// Perform 0/4 blur of the rectangle on 8-bit image (если target=nil - запишет результат в исходный буфер)
function Blur8(buf:pointer;pitch,width,height:integer;target:pointer=nil;tPitch:integer=0):pointer;
//procedure Blur8(buf:pointer;x1,y1,x2,y2,lPitch:integer);

// Perform draft blur of the rectangle in horizontal direction (dist is the blur distance)
procedure DraftBlur8X(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);

// Perform draft blur of the rectangle in vertical direction (dist is the blur distance)
procedure DraftBlur8Y(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);

// -4/8 sharpen filter (strength = 0-16)
function Sharpen8(buf:pointer;pitch,width,height,strength:integer;inplace:boolean=true):pointer;


// ---------------------
// Color transformation
procedure MixRGB(buf:pointer;pitch,width,height:integer;mat:TMatrix43s);

// Saturation (0..100)
procedure Saturate(buf:pointer;pitch,width,height,saturationValue:integer);
// Standard color effects
function Saturation(value:single):TMatrix43s;
// brightness: -1..1 (0 - no change), contrast: 0..1
function BrightnessContrast(brightness,contrast:single):TMatrix43s;
// Value: -3..3 (or more)
function Hue(value:single):TMatrix43s;

// ---------------------------------
// EXTENDED FILTERS FOR 8-BIT IMAGES

// Perform minimum filter of brush size [sizeX*2+1,sizeY*2+1] on 8-bit image
procedure Minimum8(buf:pointer;x1,y1,x2,y2,lPitch,sizeX,sizeY:integer);

// Perform maximum filter of brush size [sizeX*2+1,sizeY*2+1] on 8-bit image
procedure Maximum8(buf:pointer;x1,y1,x2,y2,lPitch,sizeX,sizeY:integer);

// Additional filters
// -------------------

// Выделяет 8-битный буфер размером (width+padding*2)*(height*padding*2) и заполняет его значением альфаканала из источника
function ExtractAlpha(buf:pointer;pitch:integer;width,height:integer;padding:integer=0):pointer;

// --------------
// EMBOSS FILTERS

// Draw Inner Emboss on the image,
// image - pointer to first (top left) pixel of the area,
// alpha - pointer to top left pixel of the area in alpha-channel
// width, height - area dimensions
// ImagePitch, AlphaPitch - offsets (in bytes) to next scanline
// AlphaStep - offset (in bytes) to the next pixel in Alpha Channel (useful if alpha-channel is combined with image (RGBA format))
// Inner/outer - strength of inner/outer bevel (-127..127, 0 if none)
// IMPORTANT!!! If outer bevel is enabled, image and alpha MUST point to area that
// have border of at least BlurDepth pixels
procedure Emboss32(image,alpha:pointer;width,height,ImagePitch,AlphaPitch,AlphaStep:integer;
                   Blur:BlurType;BlurDepth:byte;dirX,dirY:shortint;Inner,Outer:shortint);


// ---------------------------
// COMMON OPTIMIZED PROCEDURES

// Perform saturated add on array of bytes
procedure paddsb(var src; var dst; count:integer); pascal;


implementation
uses FastGfx,Colors;

type
 ByteArray=array[0..1000] of byte;
 PByteArray=^ByteArray;
 ARGBArray=array[0..1000] of cardinal;
 PARGBArray=^ARGBArray;
// PByte=^byte;
 PInt=^Integer;
// PWord=^word;

// Perform 4/8 blur of the rectangle on 32-bit image
procedure LightBlur32(buf:pointer;x1,y1,x2,y2,lPitch:integer);
 var
  o,v:cardinal;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
  x,y:integer;
  pc1,pc2,pc3,pc4:PCardinal;
 begin
  o:=cardinal(buf)+(x1+1)*4+(y1+1)*lPitch;
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey*4);
  lPitch2:=sizex*4;
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,o
   mov edi,buf2
   mov edx,sizey
   sub edx,2
@y:mov ecx,sizex
   push edi
   dec ecx
   push esi
   dec ecx
@x:mov eax,[esi]
   shr eax,1
   and eax,7F7F7Fh
   mov ebx,eax
   mov eax,[esi-4]
   shr eax,3
   and eax,1F1F1Fh
   add ebx,eax
   mov eax,[esi+4]
   shr eax,3
   and eax,1F1F1Fh
   sub esi,lPitch
   add ebx,eax
   mov eax,[esi]
   shr eax,3
   add esi,lPitch
   and eax,1F1F1Fh
   add esi,lPitch
   add ebx,eax
   mov eax,[esi]
   shr eax,3
   sub esi,lPitch
   and eax,1F1F1Fh
   add ebx,eax
   mov [edi],ebx
   add esi,4
   add edi,4
   dec ecx
   jnz @x
   pop esi
   pop edi
   add esi,lPitch
   add edi,lPitch2
   dec edx
   jnz @y
   // move
   mov edi,o
   mov esi,buf2
   mov edx,sizey
   sub edx,2
@y2:
   push esi
   push edi
   mov ecx,sizex
   sub ecx,2
   rep movsd
   pop edi
   pop esi
   add edi,lPitch
   add esi,lPitch2
   dec edx
   jnz @y2
   popad
  end;
  {$ELSE}
 { pc4:=buf;
  for y:=y1+1 to y2-1 do begin
   pc1:=pointer(o);
   pc2:=pc1; pc3:=pc1;
   dec(pc1,lPitch shr 2);
   inc(pc3,lPitch shr 2);
   for x:=x1+1 to x2-1 do begin
    pc4:=pc2;
    v:=(pc2^ shr 1) and $7F7F7F7F;
    dec(pc2);
    v:=v+(pc2^ shr 3) and $1F1F1F1F;
    inc(pc2,2);
    v:=v+(pc2^ shr 3) and $1F1F1F1F;
    v:=v+(pc1^ shr 3) and $1F1F1F1F;
    pc4^:=v+(pc3^ shr 3) and $1F1F1F1F;
    inc(pc1); inc(pc3);
   end;
   inc(o,lPitch);
  end;      }
  {$ENDIF}
  freemem(buf2,sizex*sizey*4);
 end;

function Avg32(v1,v2,v3,v4:cardinal):cardinal;  inline;
 begin
  result:=(v1 and $FF+
           v2 and $FF+
           v3 and $FF+
           v4 and $FF) shr 2;
  result:=result+
         ((v1 and $FF00+
           v2 and $FF00+
           v3 and $FF00+
           v4 and $FF00) shr 2) and $FF00;
  result:=result+
         ((v1 and $FF0000+
           v2 and $FF0000+
           v3 and $FF0000+
           v4 and $FF0000) shr 2) and $FF0000;
  result:=result+
         ((v1 shr 24+
           v2 shr 24+
           v3 shr 24+
           v4 shr 24) shr 2) shl 24;
 end;

// Perform 0/4 blur of the rectangle
function Blur32(buf:pointer;pitch,width,height:integer;target:pointer=nil;tPitch:integer=0):pointer;
 var
  pc:PCardinal;
  o:cardinal;
  sour:PARGBArray;
  x,y:integer; 
 begin
  if target=nil then begin
   GetMem(pc,width*height*4);
   tPitch:=width;
  end else begin
   pc:=target;
   tPitch:=tPitch div 4;
  end;
  pitch:=pitch div 4;
  result:=pc;

  sour:=buf;
  // Основная (центральная) часть буфера
  inc(pc,tPitch+1);
  for y:=1 to height-2 do begin
   o:=y*pitch+1;
   for x:=1 to width-2 do begin
    pc^:=Avg32(sour[o-1],sour[o+1],sour[o-pitch],sour[o+pitch]);
    inc(pc); inc(o);
   end;
   inc(pc,2+(tPitch-width));
  end;
  // Крайние пиксели (сверху)
  pc:=result; inc(pc); o:=1;
  for x:=1 to width-2 do begin
   pc^:=Avg32(sour[o],sour[o-1],sour[o+1],sour[o+pitch]);
   inc(pc); inc(o);
  end;
  // снизу
  pc:=result; inc(pc,tPitch*(height-1)+1); o:=(height-1)*pitch+1;
  for x:=1 to width-2 do begin
   pc^:=Avg32(sour[o],sour[o-1],sour[o+1],sour[o-pitch]);
   inc(pc); inc(o);
  end;
  // левый край
  pc:=result; inc(pc,width); o:=pitch;
  for y:=1 to height-2 do begin
   pc^:=Avg32(sour[o],sour[o+1],sour[o-pitch],sour[o+pitch]);
   inc(pc,tPitch); inc(o,pitch);
  end;
  // правый край
  pc:=result; inc(pc,width+width-1); o:=pitch+width-1;
  for y:=1 to height-2 do begin
   pc^:=Avg32(sour[o],sour[o-1],sour[o-pitch],sour[o+pitch]);
   inc(pc,tPitch); inc(o,pitch);
  end;
  // Угловые пиксели
  pc:=result; o:=0;
  pc^:=Avg32(sour[o],sour[o],sour[o+1],sour[o+pitch]);
  pc:=result; inc(pc,width-1); o:=width-1;
  pc^:=Avg32(sour[o],sour[o],sour[o-1],sour[o+pitch]);
  pc:=result; inc(pc,width*(height-1)); o:=pitch*(height-1);
  pc^:=Avg32(sour[o],sour[o],sour[o+1],sour[o-pitch]);
  pc:=result; inc(pc,width*height-1); o:=pitch*(height-1)+width-1;
  pc^:=Avg32(sour[o],sour[o],sour[o-1],sour[o-pitch]);
 end;

function Sharpen(buf:pointer;pitch,width,height,strength:integer;inplace:boolean=true):pointer;
 var
  pc:PCardinal;
  sour:PARGBArray;
  x,y,v,i,o:integer;
  b:integer;
  c0,c1,c2,c3,c4:integer; // это важно!
 begin
  GetMem(pc,width*height*4);
  result:=pc;
  sour:=buf;
  // Основная (центральная) часть буфера
  inc(pc,width+1);
  pitch:=pitch div 4;
  for y:=1 to height-2 do begin
   o:=y*pitch+1;
   for x:=1 to width-2 do begin
    c0:=sour[o]; c1:=sour[o-1]; c2:=sour[o+1]; c3:=sour[o-pitch]; c4:=sour[o+pitch];
    b:=((c0 and 255) shl 3-(c1 and 255)-(c2 and 255)-(c3 and 255)-(c4 and 255)) div 4;
    if b<0 then b:=0; if b>255 then b:=255;
    v:=b+c0 and $FF000000;
    b:=((c0 and $FF00) shl 3-(c1 and $FF00)-(c2 and $FF00)-(c3 and $FF00)-(c4 and $FF00)) div $400;
    if b<0 then b:=0; if b>255 then b:=255;
    v:=v+(b shl 8);
    b:=((c0 and $FF0000) shl 3-(c1 and $FF0000)-(c2 and $FF0000)-(c3 and $FF0000)-(c4 and $FF0000)) div $40000;
    if b<0 then b:=0; if b>255 then b:=255;
    v:=v+(b shl 16);
    pc^:=ColorMix(v,c0,strength);
    inc(pc); inc(o);
   end;
   inc(pc,2);
  end;
  if inplace then begin
   CopyRect(result,width*4, buf,pitch*4, 1,1,width-2,height-2, 1,1);
   Freemem(result);
   result:=buf;
  end;
 end;

function Sharpen8(buf:pointer;pitch,width,height,strength:integer;inplace:boolean=true):pointer;
 var
  pc:PByte;
  sour:PByteArray;
  x,y,v,i,o,s:integer;
  b:integer;
  c0,c1,c2,c3,c4:byte;
 begin
  GetMem(pc,width*height);
  result:=pc;
  sour:=buf;
  s:=256-strength;
  // Основная (центральная) часть буфера
  inc(pc,width+1);
  for y:=1 to height-2 do begin
   o:=y*pitch+1;
   for x:=1 to width-2 do begin
    c0:=sour[o]; c1:=sour[o-1]; c2:=sour[o+1]; c3:=sour[o-pitch]; c4:=sour[o+pitch];
    b:=((c0 and 255)*8-(c1 and 255)-(c2 and 255)-(c3 and 255)-(c4 and 255)) div 4;
    if b<0 then b:=0; if b>255 then b:=255;
    pc^:=(b*strength+c0*s) shr 8;
    inc(pc); inc(o);
   end;
   inc(pc,2);
  end;
  if inplace then begin
   CopyRect8(result,width, buf,pitch, 0,0,width,height, 0,0);
   Freemem(result);
   result:=buf;
  end;
 end;

// Perform draft blur of the rectangle in horizontal direction
procedure DraftBlur32X(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);
 var
  o,o2:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
  r,g,b,mult,v:integer;
  x,y,xc:integer;
 begin
  o:=integer(buf)+x1*4+y1*lPitch;
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey*4);
  lPitch2:=sizex*4;
  mult:=65536 div (dist*2+1);
  o2:=cardinal(buf2);
  for y:=y1 to y2 do begin
   r:=0; g:=0; b:=0;
   for x:=-dist to dist do begin
    xc:=x;
    if x<0 then xc:=0;
    if x>=sizex then xc:=sizex-1;
    v:=PInt(o+xc*4)^;
    inc(b,(v and 255));
    inc(g,(v shr 8) and 255);
    inc(r,(v shr 16) and 255);
   end;
   for x:=0 to sizex-1 do begin
    v:=(r*mult and $FF0000)+(g*mult shr 8) and $FF00+(b*mult shr 16);
    PInt(o2)^:=v;
    xc:=x-dist;
    if xc<0 then xc:=0;
    v:=PInt(o+xc*4)^;
    dec(b,(v and 255));
    dec(g,(v shr 8) and 255);
    dec(r,(v shr 16) and 255);
    xc:=x+dist+1;
    if xc>=sizex then xc:=sizex-1;
    v:=PInt(o+xc*4)^;
    inc(b,(v and 255));
    inc(g,(v shr 8) and 255);
    inc(r,(v shr 16) and 255);
    inc(o2,4);
   end;
   o:=o+lPitch;
  end;
  o2:=integer(buf2);
  o:=integer(buf)+x1*4+y1*lPitch;
  for y:=y1 to y2 do begin
   move(PInt(o2)^,PInt(o)^,sizex*4);
   o:=o+lPitch;
   o2:=o2+lPitch2;
  end;
  freemem(buf2,sizex*sizey*4);
 end;

// Perform draft blur of the rectangle in vertical direction
procedure DraftBlur32Y(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);
 var
  o,o2:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
  r,g,b,mult,v:integer;
  x,y,yc:integer;
 begin
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey*4);
  lPitch2:=sizex*4;
  mult:=65536 div (dist*2+1);
  for x:=x1 to x2 do begin
   r:=0; g:=0; b:=0;
   o:=integer(buf)+x*4+y1*lPitch;
   o2:=integer(buf2)+4*(x-x1);
   for y:=-dist to dist do begin
    yc:=y;
    if y<0 then yc:=0;
    if y>=sizey then yc:=sizey-1;
    v:=PInt(o+yc*lPitch)^;
    inc(b,(v and 255));
    inc(g,(v shr 8) and 255);
    inc(r,(v shr 16) and 255);
   end;
   for y:=0 to sizey-1 do begin
    v:=(r*mult and $FF0000)+(g*mult shr 8) and $FF00+(b*mult shr 16);
    PInt(o2)^:=v;
    yc:=y-dist;
    if yc<0 then yc:=0;
    v:=PInt(o+yc*lPitch)^;
    dec(b,(v and 255));
    dec(g,(v shr 8) and 255);
    dec(r,(v shr 16) and 255);
    yc:=y+dist+1;
    if yc>=sizey then yc:=sizey-1;
    v:=PInt(o+yc*lPitch)^;
    inc(b,(v and 255));
    inc(g,(v shr 8) and 255);
    inc(r,(v shr 16) and 255);
    inc(o2,lPitch2);
   end;
  end;
  o2:=integer(buf2);
  o:=integer(buf)+x1*4+y1*lPitch;
  for y:=y1 to y2 do begin
   move(PInt(o2)^,PInt(o)^,sizex*4);
   o:=o+lPitch;
   o2:=o2+lPitch2;
  end;
  freemem(buf2,sizex*sizey*4);
 end;

// Perform 4/8 blur of the rectangle
function LightBlur8(buf:pointer;pitch,width,height:integer;inplace:boolean=true):pointer;
 var
  pb:PByte;
  sour:PByteArray;
  x,y,v,i,o:integer;
 begin
  GetMem(pb,width*height);
  result:=pb;
  sour:=buf;
  // Основная (центральная) часть буфера
  inc(pb,width+1);
  for y:=1 to height-2 do begin
   o:=y*pitch+1;
   for x:=1 to width-2 do begin
    pb^:=(sour[o] shl 2+sour[o-1]+sour[o+1]+sour[o-pitch]+sour[o+pitch]) shr 3;
    inc(pb); inc(o);
   end;
   inc(pb,2);
  end;
  // Крайние пиксели (сверху)
  pb:=result; inc(pb); o:=1;
  for x:=1 to width-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o+1]+sour[o+pitch]) shr 2;
   inc(pb); inc(o);
  end;
  // снизу
  pb:=result; inc(pb,width*(height-1)+1); o:=(height-1)*pitch+1;
  for x:=1 to width-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o+1]+sour[o-pitch]) shr 2;
   inc(pb); inc(o);
  end;
  // левый край
  pb:=result; inc(pb,width); o:=pitch;
  for y:=1 to height-2 do begin
   pb^:=(sour[o]+sour[o+1]+sour[o-pitch]+sour[o+pitch]) shr 2;
   inc(pb,width); inc(o,pitch);
  end;
  // правый край
  pb:=result; inc(pb,width+width-1); o:=pitch+width-1;
  for y:=1 to height-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o-pitch]+sour[o+pitch]) shr 2;
   inc(pb,width); inc(o,pitch);
  end;
  // Угловые пиксели
  pb:=result; o:=0;
  pb^:=(sour[o]*2+sour[o+1]+sour[o+pitch]) shr 2;
  pb:=result; inc(pb,width-1); o:=width-1;
  pb^:=(sour[o]*2+sour[o-1]+sour[o+pitch]) shr 2;
  pb:=result; inc(pb,width*(height-1)); o:=pitch*(height-1);
  pb^:=(sour[o]*2+sour[o+1]+sour[o-pitch]) shr 2;
  pb:=result; inc(pb,width*height-1); o:=pitch*(height-1)+width-1;
  pb^:=(sour[o]*2+sour[o-1]+sour[o-pitch]) shr 2;
  if inplace then begin
   CopyRect8(result,width,buf,pitch,0,0,width,height,0,0);
   Freemem(result);
   result:=buf;
  end;
 end;

// Perform 0/4 blur of the rectangle
function Blur8(buf:pointer;pitch,width,height:integer;target:pointer=nil;tPitch:integer=0):pointer;
 var
  pb:PByte;
  sour:PByteArray;
  x,y,v,i,o:integer;
 begin
  if target=nil then begin
   GetMem(pb,width*height);
   tPitch:=width;
  end else
   pb:=target;
  result:=pb;
  sour:=buf;
  // Основная (центральная) часть буфера
  inc(pb,tPitch+1);
  for y:=1 to height-2 do begin
   o:=y*pitch+1;
   for x:=1 to width-2 do begin
    pb^:=(sour[o-1]+sour[o+1]+sour[o-pitch]+sour[o+pitch]) shr 2;
    inc(pb); inc(o);
   end;
   inc(pb,2+(tPitch-width));
  end;
  // Крайние пиксели (сверху)
  pb:=result; inc(pb); o:=1;
  for x:=1 to width-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o+1]+sour[o+pitch]) shr 2;
   inc(pb); inc(o);
  end;
  // снизу
  pb:=result; inc(pb,tPitch*(height-1)+1); o:=(height-1)*pitch+1;
  for x:=1 to width-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o+1]+sour[o-pitch]) shr 2;
   inc(pb); inc(o);
  end;
  // левый край
  pb:=result; inc(pb,width); o:=pitch;
  for y:=1 to height-2 do begin
   pb^:=(sour[o]+sour[o+1]+sour[o-pitch]+sour[o+pitch]) shr 2;
   inc(pb,tPitch); inc(o,pitch);
  end;
  // правый край
  pb:=result; inc(pb,width+width-1); o:=pitch+width-1;
  for y:=1 to height-2 do begin
   pb^:=(sour[o]+sour[o-1]+sour[o-pitch]+sour[o+pitch]) shr 2;
   inc(pb,tPitch); inc(o,pitch);
  end;
  // Угловые пиксели
  pb:=result; o:=0;
  pb^:=(sour[o]*2+sour[o+1]+sour[o+pitch]) shr 2;
  pb:=result; inc(pb,width-1); o:=width-1;
  pb^:=(sour[o]*2+sour[o-1]+sour[o+pitch]) shr 2;
  pb:=result; inc(pb,width*(height-1)); o:=pitch*(height-1);
  pb^:=(sour[o]*2+sour[o+1]+sour[o-pitch]) shr 2;
  pb:=result; inc(pb,width*height-1); o:=pitch*(height-1)+width-1;
  pb^:=(sour[o]*2+sour[o-1]+sour[o-pitch]) shr 2;
  if target=nil then begin  // !!! копирование в исходный буфер
   CopyRect8(result,width,buf,pitch,0,0,width,height,0,0);
   Freemem(result);
   result:=buf;
  end;
 end;


(*procedure LightBlur8(buf:pointer;x1,y1,x2,y2,lPitch:integer);
 var
  o:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
 begin
  o:=integer(buf)+(x1+1)+(y1+1)*lPitch;
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey);
  lPitch2:=sizex;
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,o
   mov edi,buf2
   mov edx,sizey
   sub edx,2
@y:mov ecx,sizex
   push edi
   dec ecx
   push esi
   dec ecx
@x:mov al,[esi]
   shr al,1
   and al,7Fh
   mov bl,al
   mov al,[esi-1]
   shr al,3
   and al,1Fh
   add bl,al
   mov al,[esi+1]
   shr al,3
   and al,1Fh
   sub esi,lPitch
   add bl,al
   mov al,[esi]
   shr al,3
   add esi,lPitch
   and al,1Fh
   add esi,lPitch
   add bl,al
   mov al,[esi]
   shr al,3
   sub esi,lPitch
   and al,1Fh
   add bl,al
   mov [edi],bl
   inc esi
   inc edi
   dec ecx
   jnz @x
   pop esi
   pop edi
   add esi,lPitch
   add edi,lPitch2
   dec edx
   jnz @y
   // move
   mov edi,o
   mov esi,buf2
   mov edx,sizey
   sub edx,2
@y2:
   push esi
   push edi
   mov ecx,sizex
   sub ecx,2
   rep movsb
   pop edi
   pop esi
   add edi,lPitch
   add esi,lPitch2
   dec edx
   jnz @y2
   popad
  end;
  {$ENDIF}
  freemem(buf2,sizex*sizey*4);
 end; *)

// Perform 0/4 blur of the rectangle
(*procedure Blur8(buf:pointer;x1,y1,x2,y2,lPitch:integer);
 var
  o:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
 begin
  o:=integer(buf)+(x1+1)+(y1+1)*lPitch;
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey);
  lPitch2:=sizex;
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,o
   mov edi,buf2
   mov edx,sizey
   sub edx,2
@y:mov ecx,sizex
   push edi
   dec ecx
   push esi
   dec ecx
@x:
   mov al,[esi-1]
   shr al,2
   and al,3Fh
   mov bl,al
   mov al,[esi+1]
   shr al,2
   and al,3Fh
   sub esi,lPitch
   add bl,al
   mov al,[esi]
   shr al,2
   add esi,lPitch
   and al,3Fh
   add esi,lPitch
   add bl,al
   mov al,[esi]
   shr al,2
   sub esi,lPitch
   and al,3Fh
   add bl,al
   mov [edi],bl
   inc esi
   inc edi
   dec ecx
   jnz @x
   pop esi
   pop edi
   add esi,lPitch
   add edi,lPitch2
   dec edx
   jnz @y
   // move
   mov edi,o
   mov esi,buf2
   mov edx,sizey
   sub edx,2
@y2:
   push esi
   push edi
   mov ecx,sizex
   sub ecx,2
   rep movsb
   pop edi
   pop esi
   add edi,lPitch
   add esi,lPitch2
   dec edx
   jnz @y2
   popad
  end;
  {$ENDIF}
  freemem(buf2,sizex*sizey*4);
 end; *)

// Perform draft blur of the rectangle in horizontal direction
procedure DraftBlur8X(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);
 var
  o,o2:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
  a,mult,v:integer;
  x,y,xc:integer;
 begin
  o:=integer(buf)+x1+y1*lPitch;
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey);
  lPitch2:=sizex;
  mult:=65536 div (dist*2+1);
  o2:=cardinal(buf2);
  for y:=y1 to y2 do begin
   a:=0;
   for x:=-dist to dist do begin
    xc:=x;
    if x<0 then xc:=0;
    if x>=sizex then xc:=sizex-1;
    v:=PByte(o+xc)^;
    inc(a,v);
   end;
   for x:=0 to sizex-1 do begin
    v:=(a*mult shr 16);
    PByte(o2)^:=v;
    xc:=x-dist;
    if xc<0 then xc:=0;
    v:=PByte(o+xc)^;
    dec(a,v);
    xc:=x+dist+1;
    if xc>=sizex then xc:=sizex-1;
    v:=PByte(o+xc)^;
    inc(a,v);
    inc(o2);
   end;
   o:=o+lPitch;
  end;
  o2:=integer(buf2);
  o:=integer(buf)+x1+y1*lPitch;
  for y:=y1 to y2 do begin
   move(Pbyte(o2)^,PByte(o)^,sizex);
   o:=o+lPitch;
   o2:=o2+lPitch2;
  end;
  freemem(buf2,sizex*sizey);
 end;

// Perform draft blur of the rectangle in vertical direction
procedure DraftBlur8Y(buf:pointer;x1,y1,x2,y2,lPitch,dist:integer);
 var
  o,o2:integer;
  sizex,sizey,lPitch2:integer;
  buf2:pointer;
  a,mult,v:integer;
  x,y,yc:integer;
 begin
  sizex:=x2-x1+1;
  sizey:=y2-y1+1;
  getmem(buf2,sizex*sizey);
  lPitch2:=sizex;
  mult:=65536 div (dist*2+1);
  for x:=x1 to x2 do begin
   a:=0;
   o:=integer(buf)+x+y1*lPitch;
   o2:=integer(buf2)+(x-x1);
   for y:=-dist to dist do begin
    yc:=y;
    if y<0 then yc:=0;
    if y>=sizey then yc:=sizey-1;
    v:=PByte(o+yc*lPitch)^;
    inc(a,v);
   end;
   for y:=0 to sizey-1 do begin
    v:=(a*mult shr 16);
    PByte(o2)^:=v;
    yc:=y-dist;
    if yc<0 then yc:=0;
    v:=PByte(o+yc*lPitch)^;
    dec(a,v);
    yc:=y+dist+1;
    if yc>=sizey then yc:=sizey-1;
    v:=PByte(o+yc*lPitch)^;
    inc(a,v);
    inc(o2,lPitch2);
   end;
  end;
  o2:=integer(buf2);
  o:=integer(buf)+x1+y1*lPitch;
  for y:=y1 to y2 do begin
   move(PByte(o2)^,PByte(o)^,sizex);
   o:=o+lPitch;
   o2:=o2+lPitch2;
  end;
  freemem(buf2,sizex*sizey);
 end;

procedure Maximum8;
 var
  buf2:pointer;
  o,o2,ol,ot:pByte;
  width,height:integer;
  x,y,i,j:integer;
  opt:integer;
 begin
  width:=x2-x1+1;
  height:=y2-y1+1;
  getmem(buf2,width*height);
  // First iteration - for horisontal direction
  o2:=buf2;
  for y:=y1 to y2 do begin
   o:=buf; inc(o,lPitch*y+x1);
   ol:=o;
   opt:=o^;
   for i:=1 to sizex do begin // Previewing
    inc(o);
    if o^>opt then opt:=o^;
   end;
   for i:=1 to sizex do begin // first lap
    o2^:=opt;
    inc(o);
    inc(o2);
    if pByte(o)^>opt then opt:=pByte(o)^;
   end;
   for i:=1 to width-sizex*2-1 do begin // second (main) lap
    o2^:=opt;
    inc(o);
    inc(o2);
    if o^>opt then begin
     opt:=o^;
     inc(ol);
    end else
      if ol^=opt then begin
       opt:=0; inc(ol); ot:=ol;
       for j:=-sizeX to sizeX do begin
        if ot^>opt then opt:=ot^;
        inc(ot);
       end;
      end else inc(ol);
   end;
   for i:=1 to sizex do begin // last lap
    o2^:=opt;
    inc(o2);
    if ol^=opt then begin
     opt:=0;
     inc(ol); ot:=ol;
     for j:=-sizeX to sizeX-i do begin
      if ot^>opt then opt:=ot^;
      inc(ot);
     end;
    end else inc(ol);
   end;
   o2^:=opt;
   inc(o2);
  end;

  o:=buf; buf:=buf2; buf2:=o; // swap buffers
  // Second iteration - for vertical direction
  for x:=x1 to x2 do begin
   o:=buf; inc(o,x-x1);
   o2:=buf2; inc(o2,y1*lPitch+x);
   ol:=o;
   opt:=o^;
   for i:=1 to sizey do begin // Previewing
    inc(o,width);
    if o^>opt then opt:=o^;
   end;
   for i:=1 to sizey do begin // first lap
    pByte(o2)^:=opt;
    inc(o,width);
    inc(o2,lPitch);
    if pByte(o)^>opt then opt:=pByte(o)^;
   end;
   for i:=1 to height-sizey*2-1 do begin // second (main) lap
    o2^:=opt;
    inc(o,width);
    inc(o2,lPitch);
    if o^>opt then begin
     opt:=o^;
     inc(ol,width);
    end else
      if ol^=opt then begin
       opt:=0; inc(ol,width); ot:=ol;
       for j:=-sizeY to sizeY do begin
        if ot^>opt then opt:=ot^;
        inc(ot,width);
       end;
      end else inc(ol,width);
   end;
   for i:=1 to sizeY do begin // last lap
    o2^:=opt;
    inc(o2,lPitch);
    if ol^=opt then begin
     opt:=0;
     inc(ol,width); ot:=ol;
     for j:=-sizeY to sizeY-i do begin
      if ot^>opt then opt:=ot^;
      inc(ot,width);
     end;
    end else inc(ol,width);
   end;
   o2^:=opt;
  end;
  freemem(buf,width*height);
 end;

procedure Minimum8;
 var
  buf2:pointer;
  o,o2,ol,ot:pByte;
  width,height:integer;
  x,y,i,j:integer;
  opt:integer;
 begin
  width:=x2-x1+1;
  height:=y2-y1+1;
  getmem(buf2,width*height);
  // First iteration - for horisontal direction
  o2:=buf2;
  for y:=y1 to y2 do begin
   o:=buf; inc(o,lPitch*y+x1);
   ol:=o;
   opt:=o^;
   for i:=1 to sizex do begin // Previewing
    inc(o);
    if o^<opt then opt:=o^;
   end;
   for i:=1 to sizex do begin // first lap
    o2^:=opt;
    inc(o);
    inc(o2);
    if pByte(o)^<opt then opt:=pByte(o)^;
   end;
   for i:=1 to width-sizex*2-1 do begin // second (main) lap
    o2^:=opt;
    inc(o);
    inc(o2);
    if o^<opt then begin
     opt:=o^;
     inc(ol);
    end else
      if ol^=opt then begin
       opt:=255; inc(ol); ot:=ol;
       for j:=-sizeX to sizeX do begin
        if ot^<opt then opt:=ot^;
        inc(ot);
       end;
      end else inc(ol);
   end;
   for i:=1 to sizex do begin // last lap
    o2^:=opt;
    inc(o2);
    if ol^=opt then begin
     opt:=255;
     inc(ol); ot:=ol;
     for j:=-sizeX to sizeX-i do begin
      if ot^<opt then opt:=ot^;
      inc(ot);
     end;
    end else inc(ol);
   end;
   o2^:=opt;
   inc(o2);
  end;

  o:=buf; buf:=buf2; buf2:=o; // swap buffers
  // Second iteration - for vertical direction
  for x:=x1 to x2 do begin
   o:=buf; inc(o,x-x1);
   o2:=buf2; inc(o2,y1*lPitch+x);
   ol:=o;
   opt:=o^;
   for i:=1 to sizey do begin // Previewing
    inc(o,width);
    if o^<opt then opt:=o^;
   end;
   for i:=1 to sizey do begin // first lap
    pByte(o2)^:=opt;
    inc(o,width);
    inc(o2,lPitch);
    if pByte(o)^<opt then opt:=pByte(o)^;
   end;
   for i:=1 to height-sizey*2-1 do begin // second (main) lap
    o2^:=opt;
    inc(o,width);
    inc(o2,lPitch);
    if o^<opt then begin
     opt:=o^;
     inc(ol,width);
    end else
      if ol^=opt then begin
       opt:=255; inc(ol,width); ot:=ol;
       for j:=-sizeY to sizeY do begin
        if ot^<opt then opt:=ot^;
        inc(ot,width);
       end;
      end else inc(ol,width);
   end;
   for i:=1 to sizeY do begin // last lap
    o2^:=opt;
    inc(o2,lPitch);
    if ol^=opt then begin
     opt:=255;
     inc(ol,width); ot:=ol;
     for j:=-sizeY to sizeY-i do begin
      if ot^<opt then opt:=ot^;
      inc(ot,width);
     end;
    end else inc(ol,width);
   end;
   o2^:=opt;
  end;
  freemem(buf,width*height);
 end;

function ExtractAlpha(buf:pointer;pitch:integer;width,height:integer;padding:integer=0):pointer;
 var
  ps,pb:PByte;
  x,y,size,dpitch:integer;
 begin
  size:=(width+padding*2)*(height+padding*2);
  GetMem(pb,size);
  result:=pb;
  dPitch:=width+padding*2;
  inc(pb,padding*(dPitch+1));
  // Copy alpha channel
  for y:=0 to height-1 do begin
   ps:=buf; inc(ps,pitch*y+3);
   for x:=0 to width-1 do begin
    pb^:=ps^;
    inc(ps,4); inc(pb);
   end;
  end;
  // ZeroFill padding
  pb:=result;
  fillchar(pb^,(padding+1)*dPitch,0);
  inc(pb,(padding+1)*dPitch+width);
  for y:=0 to height-2 do begin
   fillchar(pb^,padding*2,0);
   inc(pb,padding*2);
  end;
  fillchar(pb^,(padding+1)*dPitch,0);
 end;

     { TODO 1 -oCooler : Finish paddsb procedure }
procedure paddsb;
 const
  startmask:array[0..7] of int64=($FFFFFFFFFFFFFFFF,
                                  $00FFFFFFFFFFFFFF,
                                  $0000FFFFFFFFFFFF,
                                  $000000FFFFFFFFFF,
                                  $00000000FFFFFFFF,
                                  $0000000000FFFFFF,
                                  $000000000000FFFF,
                                  $00000000000000FF);
 var
  sp,dp:PShortInt;
  i,v:integer;
 begin
(*  {$IFDEF CPU386}
  asm
   pushad
   mov esi,src
   mov edx,esi
   add edx,count
   mov edi,dst
   mov eax,esi
   and eax,7
   mov ebx,offset startmask
   db $0F,$6F,$04,$C3       /// movq mm0,[ebx+eax*8]
   popad
   db $0F,$77               /// emms
  end;
  {$ELSE}   *)
  sp:=@src; dp:=@dst;
  for i:=1 to count do begin
   v:=sp^+dp^;
   if v<-128 then v:=-128;
   if v>127 then v:=127;
   dp^:=v;
   inc(sp); inc(dp);
  end;
 end;

procedure Emboss32;
 type
  TPixel=record
   case boolean of
    true:(c:cardinal);
    false:(b,g,r,a:byte);
  end;
 var
  pixel:^cardinal;
  alp:PByte;
  a2:^shortint;
  awidth,aheight:integer;
  abuf:pointer;
  i,j,d,v:integer;
  px:TPixel;
 begin
  inc(blurDepth);
  awidth:=width+BlurDepth*2+DirX*2;
  aheight:=height+BlurDepth*2+DirY*2;
  GetMem(abuf,aheight*awidth);
  try
   // copy alpha channel
   a2:=abuf;
   for i:=0 to aheight-1 do begin
    alp:=alpha;
    inc(alp,AlphaPitch*(i-DirY*2-BlurDepth));
    if (i<BlurDepth+DirY*2) or (i>=aHeight-BlurDepth) then begin
     fillchar(a2^,awidth,0);
     inc(a2,awidth);
    end else begin
     fillchar(a2^,BlurDepth+dirX*2,0); inc(a2,BlurDepth+DirX*2);
     for j:=0 to width-1 do begin
      a2^:=alp^ div 2;
      inc(a2);
      inc(alp,alphastep);
     end;
     fillchar(a2^,BlurDepth,0); inc(a2,BlurDepth);
    end;
   end;
   // Blurring
   case Blur of
{    Light:for i:=2 to BlurDepth do
           LightBlur8(abuf,DirX*2,DirY*2,awidth-1,aheight-1,awidth);}
{    Normal:for i:=2 to BlurDepth do
            Blur8(abuf,DirX*2,DirY*2,awidth-1,aheight-1,awidth);}
    Fast:begin
          DraftBlur8X(abuf,DirX*2,DirY*2,awidth-1,aheight-1,awidth,BlurDepth-1);
          DraftBlur8Y(abuf,DirX*2,DirY*2,awidth-1,aheight-1,awidth,BlurDepth-1);
         end;
   end;
   // Emboss alpha channel
   d:=awidth*DirY*2+DirX*2;
   for i:=0 to aheight-DirY*2-1 do begin
    a2:=abuf; inc(a2,awidth*i);
    for j:=0 to awidth-DirX*2-1 do begin
     v:=PByte(integer(a2)+d)^-PByte(integer(a2))^;
     v:=v div 2;
     a2^:=v;
     inc(a2);
    end;
   end;
   // apply result to image
   if (outer=0) and (inner<>0) then begin // no outer bevel - work only with area
    a2:=abuf; inc(a2,(BlurDepth+DirY)*awidth+blurDepth+DirX);
    for i:=0 to height-1 do begin
     pixel:=image; inc(pixel,i*ImagePitch div 4);
     alp:=alpha; inc(alp,i*AlphaPitch);
     for j:=0 to width-1 do begin
      px.c:=pixel^;
      if (alp^>0) then begin // skip totally transparent pixels
       v:=256+inner*a2^*alp^ div 4096;
       if v<0 then v:=0;
       d:=px.b*v div 256;
       if d>255 then px.b:=255 else px.b:=d;
       d:=px.g*v div 256;
       if d>255 then px.g:=255 else px.g:=d;
       d:=px.r*v div 256;
       if d>255 then px.r:=255 else px.r:=d;
      end;
      inc(a2);
      inc(alp,alphastep);
      pixel^:=px.c;
      inc(pixel);
     end;
     inc(a2,(DirX+BlurDepth)*2);
    end;
   end else
   if (outer<>0) and (inner=0) then begin // no inner bevel - work outside
    a2:=abuf; inc(a2,DirY*awidth+DirX);
    for i:=0 to height+BlurDepth*2-1 do begin
     pixel:=image; inc(pixel,(i-BlurDepth)*ImagePitch div 4-BlurDepth);
     alp:=alpha; inc(alp,(i-BlurDepth)*AlphaPitch-BlurDepth);
     for j:=0 to width+BlurDepth*2-1 do begin
      px.c:=pixel^;
      v:=256+outer*a2^*(255-alp^) div 4096;
      if v<0 then v:=0;
      d:=px.b*v div 256;
      if d>255 then px.b:=255 else px.b:=d;
      inc(alp,alphastep);
      d:=px.g*v div 256;
      if d>255 then px.g:=255 else px.g:=d;
      inc(a2);
      d:=px.r*v div 256;
      if d>255 then px.r:=255 else px.r:=d;
      pixel^:=px.c;
      inc(pixel);
     end;
     inc(a2,DirX*2);
    end;
   end else
   if (outer<>0) and (inner<>0) then begin // both bevels - work outside and inside
    a2:=abuf; inc(a2,DirY*awidth+DirX);
    for i:=0 to height+BlurDepth*2-1 do begin
     pixel:=image; inc(pixel,(i-BlurDepth)*ImagePitch div 4-BlurDepth);
     alp:=alpha; inc(alp,(i-BlurDepth)*AlphaPitch-BlurDepth);
     for j:=0 to width+BlurDepth*2-1 do begin
      px.c:=pixel^;
      v:=inner*a2^ div 64;
      d:=outer*a2^ div 64;
      v:=256+(v*alp^+d*(256-alp^)) div 64;
      if v<0 then v:=0;
      d:=px.b*v div 256;
      if d>255 then px.b:=255 else px.b:=d;
      inc(alp,alphastep);
      d:=px.g*v div 256;
      if d>255 then px.g:=255 else px.g:=d;
      inc(a2);
      d:=px.r*v div 256;
      if d>255 then px.r:=255 else px.r:=d;
      pixel^:=px.c;
      inc(pixel);
     end;
     inc(a2,DirX*2);
    end;
   end;

  finally
   freemem(abuf,aheight*awidth);
  end;
 end;

procedure MixRGB(buf:pointer;pitch,width,height:integer;mat:TMatrix43s);
 var
  pc,p:PCardinal;
  x,y,r,g,b,nr,ng,nb:integer;
  v:cardinal;
 begin
  pc:=buf;
  for x:=0 to 2 do mat[3,x]:=round(mat[3,x]*256);
  for y:=0 to height-1 do begin
   p:=pc;
   for x:=0 to width-1 do begin
    v:=p^;
    b:=v and $FF; v:=v shr 8;
    g:=v and $FF; v:=v shr 8;
    r:=v and $FF;
    nb:=round(mat[0,0]*b+mat[1,0]*g+mat[2,0]*r+mat[3,0]);
    ng:=round(mat[0,1]*b+mat[1,1]*g+mat[2,1]*r+mat[3,1]);
    nr:=round(mat[0,2]*b+mat[1,2]*g+mat[2,2]*r+mat[3,2]);
    if nb<0 then nb:=0;
    if nb>255 then nb:=255;
    if ng<0 then ng:=0;
    if ng>255 then ng:=255;
    if nr<0 then nr:=0;
    if nr>255 then nr:=255;
    p^:=(p^ and $FF000000) or nb or (ng shl 8) or (nr shl 16);
    inc(p);
   end;
   inc(pc,pitch shr 2);
  end;
 end;

// Saturation (0..100)
procedure Saturate(buf:pointer;pitch,width,height,saturationValue:integer);
 var
  mat:TMatrix43s;
 begin
  MixRGB(buf,pitch,width,height,Saturation(saturationValue/100));
 end;

function Saturation(value:single):TMatrix43s;
 var
  i:integer;
  v1,v2:single;
 begin
  v1:=value;
  v2:=1-v1;
  for i:=0 to 2 do begin
   result[0,i]:=0.12*v2+byte(i=0)*v1;
   result[1,i]:=0.58*v2+byte(i=1)*v1;
   result[2,i]:=0.3*v2+byte(i=2)*v1;
   result[3,i]:=0;
  end;
 end;

function BrightnessContrast(brightness,contrast:single):TMatrix43s;
 var
  i:integer;
 begin
  fillchar(result,sizeof(result),0);
  for i:=0 to 2 do begin
   result[i,i]:=contrast;
   result[3,i]:=brightness+(1-contrast)/2;
  end;
 end;

function Hue(value:single):TMatrix43s;
 var
  i,j:integer;
 function F(value:single):single;
  begin
   while value>=2 do value:=value-3;
   while value<-2 do value:=value+3;
   result:=1-abs(value);
   if result<0 then result:=0;
  end;
 begin
  while value<0 do value:=value+3;
  while value>3 do value:=value-3;
  fillchar(result,sizeof(result),0);
  for i:=0 to 2 do
   for j:=0 to 2 do
    result[i,j]:=F(value+i-j);
 end;

end.