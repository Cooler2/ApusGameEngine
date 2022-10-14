// Class hierarchy for image objects
//
// Copyright (C) 2003 Apus Software
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Images;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface
 uses Apus.FastGFX;

type
 // Форматы представления изображения
 TImagePixelFormat=(ipfNone,    // Default format or no image data
                   ipf1Bit,     // 1bpp (2 colors) - monochrome
                   ipf4Bit,     // 4bpp (16 colors, indexed)
                   ipf8Bit,     // 8bpp (256 colors, indexed)
                   ipf555,      // 16bpp (5-5-5 format)
                   ipf1555,     // 16bpp (5-5-5 format with 1-bit alpha)
                   ipf565,      // 16bpp (5-6-5 format)
                   ipf4444,     // 16bpp (4-4-4 format with 4-bit alpha)
                   ipfRGB,      // 24bpp
                   ipfBGR,      // 24bpp
                   ipfXRGB,     // 32bpp (last byte is not used)
                   ipfARGB,     // 32bpp (last byte is alpha channel)
                   ipfDXT1,     // DXT1
                   ipfDXT2,     // DXT2 (premultiplied colors, explicit alpha)
                   ipfDXT3,     // DXT3 (explicit alpha)
                   ipfDXT5,     // DXT5 (interpolated alpha)
                   ipfPVRTC,    // PVR TC (compressed 4bpp texture)
                   ipfA4,       // 4bpp (alpha)
                   ipfA8,       // 8bpp (альфаканал)
                   ipfL4A4,     // 8bpp (luminance+alpha)
                   ipf4444r,    // 16bpp 4-4-4-4 format with $BGRA structure
                   ipfABGR,     // 32bpp
                   ipfXBGR,     // 32bpp
                   ipfMono8,    // 1-channel 8 bit image (grayscale or red) - unsigned normalized
                   ipfMono8u,   // 1-channel 8 bit image - unsigned non-normalized integer
                   ipfDuo8,     // 2-channels 8 bit image (for example, red-green)
                   ipfMono16,   // 1-channel 16 bit image (grayscale or red) - unsigned normalized
                   ipfMono16s,  // 1-channel 16 bit image (grayscale or red) - signed normalized
                   ipfMono16i,  // 1-channel 16 bit image (grayscale or red) - signed non-normalized integer
                   ipfMono32f,  // 1-channel 32 bit floating point image
                   ipfDuo32f,   // 2-channel 32 bit floating point image
                   ipfQuad32f,  // 4-channel 32 bit floating point vectors
                   ipfDepth32f, // 32bit float depth
                   ipf32bpp);   // generic 32bpp: XRGB or ARGB

 // Форматы представления палитры
 ImagePaletteFormat=(palNone,   // Палитры нет
                     palRGB,    // Палитра из триад
                     palXRGB,   // Палитра с 4-байтными эл-тами, последний байт не используется
                     palARGB);  // Палитра с 4-байтными эл-ми, 4-й байт содержит альфа

type
 TPaletteEntry=record
 case boolean of
  true:(color:cardinal);
  false:(b,g,r,a:byte);
 end;
 TPalette=array[0..255] of TPaletteEntry;

 TRawImage=class; // предопределение типа


 // Это базовый класс для описания изображений различных типов
 // Изображения могут иметь различное представление, быть упакованными и
 // т.п.
 // Общие свойства всех изображений: размер и метод рисования по умолчанию
 TBaseImage=class
  width,height:integer;
  tag:UIntPtr;
 end;

 // Абстрактный класс, определяющий анимированное изображение
 // Основными методами являются NextFrame/ChangePos и Draw, конкретные
 // форматы могут иметь свои, более оптимальные способы рисования
 TAnimatedImage=class(TBaseImage)
  // true если формат поддерживает случайный доступ к кадрам
  class function RandomAccess:boolean; virtual; abstract;
  // true если можно переходить по кадрам как вперед, так и назад
  class function RevDirection:boolean; virtual; abstract;

  // Перейти к указанной позиции относительно начала анимации
  procedure SetPos(time:single); virtual; abstract;
  // Переместить позицию относительно текущего момента
  procedure ChangePos(delta:single); virtual; abstract;
  // Перейти к следующему/предыдущему кадрам
  procedure NextFrame; virtual; abstract;
  procedure PrevFrame; virtual; abstract;

  // Управление нелинейной анимацией (зависит от формата):
  // --------------------------------
  // установить положение указанной развилки: развилка - это триггер на кадре,
  // который указывает на следующий кадр
  // Существует две развилки по умолчанию:
  // 0 - на 1-м кадре (по умолчанию указывает на 2-й кадр)
  // 1 - на последнем (по умолчанию указывает на 1-й кадр)
  // Значения развилки - это не номера кадров, а номера возможных вариантов:
  // 0 - оставаться на месте, -1 - двигаться в обратном направлении, 1..n - ветви
  procedure SetFork(fork,value:byte); virtual; abstract;
 end;

 // RawImage - это статическое изображение, имеющее линейную неупакованную структуру
 // Основная особенность таких изображений - на них можно рисовать (в.т.ч. используя
 // прямой доступ к памяти и формат пикселя)
 // Это тоже абстрактный класс, который не определяет конкретного способа создания
 // и хранения изображения
 // This object doesn't own data
 TRawImage=class(TBaseImage)
  pixelFormat:TImagePixelFormat;
  paletteFormat:ImagePaletteFormat;

  // Следующие данные не обязательно всегда доступны, это зависит от типа изображения
  data:pointer;  // Указатель на данные (пиксель 0,0)
  pitch:integer; // смещение к очередной строке
  dataSize:integer; // size of data (in bytes)
  palette:pointer; // указатель на палитру, nil если ее нет
  palSize:integer; // размер палитры (число эл-тов)

  constructor Copy(src:TRawImage);
  class function NeedLock:boolean; virtual;  // true - если нужно лочить для доступа к данным
  procedure Lock; virtual;  // заполняет поля действующими значениями
  procedure Unlock; virtual;
  procedure Clear(color:cardinal); virtual;
  procedure Expand(paddingLeft,paddingTop,paddingRight,paddingBottom:integer;color:cardinal=0); virtual; abstract;
  function GetPixel(x,y:integer):cardinal; virtual; // get raw value of pixel
  function GetPixelARGB(x,y:integer):cardinal; virtual; // get ARGB value of pixel
  procedure SetPixel(x,y:integer;value:cardinal); virtual;
  function GetPixelAddress(x,y:integer):pointer;
  function ScanLine(y:integer):pointer;
  procedure CopyPixelDataFrom(src:TRawImage); // copy from another image with pixel format conversion (if needed)
  procedure SetAsRenderTarget;
 end;

 // TBitmapImage - это уже конкретный вид изображения: bitmap, хранящийся в памяти
 TBitmapImage=class(TRawImage)

  constructor Create(w,h:integer;pf:TImagePixelFormat=ipfARGB;
                     pal:ImagePaletteFormat=palNone;pSize:integer=256);
  constructor Assign(w,h:integer;_data:pointer;_pitch:integer;_pf:TImagePixelFormat);
  destructor Destroy; override;

  class function NeedLock:boolean; override; // true - если нужно лочить для доступа к данным
  procedure Expand(paddingLeft,paddingTop,paddingRight,paddingBottom:integer;color:cardinal); override;
 end;

 var
  // Преобразование цвета из RGBA в заданный формат
  colorTo:array[TImagePixelFormat] of TColorConv;
  colorFrom:array[TImagePixelFormat] of TColorConv;

 const
  // Размер пикселя в битах
  pixelSize:array[TImagePixelFormat] of byte=(0,1,4,8,16,16,16,16,24,24,32,32,64,128,128,128,4,4,8,8,16,32,32,8,8,16,16,16,16,32,64,128,32,32);
  palEntrySize:array[ImagePaletteFormat] of byte=(0,24,32,32);

 procedure ConvertLine(var sour,dest;sourformat,destformat:TImagePixelFormat;count:integer;
                 palette:pointer=nil;palformat:ImagePaletteFormat=palNone); overload;
 procedure ConvertLine(var sour,dest;sourformat,destformat:TImagePixelFormat;
                 var palette;palformat:ImagePaletteFormat;count:integer); overload; deprecated;

 // Swap red<->blue channels for xRGB<->xBGR conversion
 procedure SwapRB(var data;count:integer);

 function PixFmt2Str(ipf:TImagePixelFormat):string;

implementation
 uses SysUtils, Apus.Types, Apus.Common;

function PixFmt2Str(ipf:TImagePixelFormat):string;
 begin
  result:='unknown';
  case ipf of
   ipfARGB:result:='ARGB';
   ipfXRGB:result:='XRGB';
   ipfRGB:result:='RGB';
   ipf1555:result:='1555';
   ipf4444:result:='4444';
   ipf565:result:='565';
   ipf555:result:='555';
   ipf8bit:result:='8bit';
   ipfDXT1:result:='DXT1';
   ipfDXT2:result:='DXT2';
   ipfDXT3:result:='DXT3';
   ipfPVRTC:result:='PVRTC';
   ipfABGR:result:='ABGR';
   ipfXBGR:result:='xBGR';
   ipf4444r:result:='4444r';
   ipf32bpp:result:='32bpp';
   ipfA4:result:='A4';
   ipfA8:result:='A8';
   ipfMono8:result:='Mono8';
   ipfMono8u:result:='Mono8u';
   ipfMono16:result:='Mono16';
   ipfMono16i:result:='Mono16i';
   ipfMono16s:result:='Mono16s';
   ipfMono32f:result:='Mono32f';
   ipfDuo32f:result:='Duo32f';
   ipfL4A4:result:='L4A4';
  else
   result:='other('+IntToStr(ord(ipf))+')';
  end;
 end;

procedure SwapRB(var data;count:integer);
 var
  pc:PCardinal;
 begin
  pc:=@data;
  while count>0 do begin
   pc^:=pc^ and $FF00FF00 or (pc^ and $FF shl 16) or (pc^ and $FF0000 shr 16);
   inc(pc);
   dec(count);
  end;
 end;

procedure ConvertLine(var sour,dest;sourformat,destformat:TImagePixelFormat;
                var palette;palformat:ImagePaletteFormat;count:integer); overload;
 begin
  ConvertLine(sour,dest,sourformat,destformat,count,@palette,palformat);
 end;

procedure ConvertLine(var sour,dest;sourformat,destformat:TImagePixelFormat;count:integer;
                palette:pointer=nil;palformat:ImagePaletteFormat=palNone); overload;
 var
  buf:array[0..2047] of cardinal;
  sp,dp:PByte;
  n:integer;
 begin
  // А нужна ли вообще конверсия?
  if (sourformat=destformat) or
     (pixelSize[sourFormat]=32) and (pixelSize[destFormat]=32) then begin
   move(sour,dest,count*PixelSize[sourformat] div 8);

   if sourFormat<>destFormat then begin
    // Add constant alpha?
    if (destFormat in [ipfARGB,ipfABGR]) and (sourformat in [ipfXRGB,ipfXBGR]) then begin
     dp:=@dest;
     for n:=0 to count-1 do begin
      PCardinal(dp)^:=PCardinal(dp)^ or $FF000000;
      inc(dp,4);
     end;
    end;
    // RGB<->BGR?
    if (sourFormat in [ipfARGB,ipfXRGB]) and (destFormat in [ipfABGR,ipfXBGR]) or
       (destFormat in [ipfARGB,ipfXRGB]) and (sourFormat in [ipfABGR,ipfXBGR]) then
      SwapRB(dest,count);
   end;
   exit;
  end;

  // По возможности используем оптимизированные процедуры блиттинга
  if sourformat in [ipfARGB,ipfXRGB] then begin
   if destFormat=ipfRGB then begin
    PixelsTo24(sour,dest,count); exit;
   end;
   if destformat=ipf565 then begin
    PixelsTo16(sour,dest,count); exit;
   end;
   if destformat=ipf555 then begin
    PixelsTo15(sour,dest,count); exit;
   end;
  end;
  // Если ничего не подошло, конвертируем через промежуточный 32-битный формат
  sp:=@sour; dp:=@dest;
  while count>0 do begin
   n:=count;
   if n>2048 then n:=2048;
   if destformat in [ipfARGB,ipfXRGB,ipfABGR,ipfXBGR] then begin
    // Можно конвертировать сразу в приемник
    case sourformat of
     ipf555:PixelsFrom15(sp^,dp^,n);
     ipf1555:PixelsFrom15A(sp^,dp^,n);
     ipf565:PixelsFrom16(sp^,dp^,n);
     ipf4444:PixelsFrom12(sp^,dp^,n);
     ipfRGB:PixelsFrom24(sp^,dp^,n);
     ipfBGR:PixelsFrom24R(sp^,dp^,n);
     ipf8Bit:if PalFormat=palRGB then
       PixelsFrom8P24(sp^,dp^,palette^,n) else
       PixelsFrom8P(sp^,dp^,palette^,n);
    end;
    if destFormat in [ipfABGR,ipfXBGR] then SwapRB(dp^,n);
   end else
   if sourformat in [ipfARGB,ipfXRGB] then begin
    // Можно конвертировать прямо из источника
    case destformat of
     ipf555:PixelsTo15(sp^,dp^,n);
     ipf1555:PixelsTo15A(sp^,dp^,n);
     ipf565:PixelsTo16(sp^,dp^,n);
     ipf4444:PixelsTo12(sp^,dp^,n);
     ipfRGB:PixelsTo24(sp^,dp^,n);
     ipfBGR:PixelsTo24R(sp^,dp^,n);
    end;
   end else begin
    case sourformat of
     ipf555:PixelsFrom15(sp^,buf,n);
     ipf1555:PixelsFrom15A(sp^,buf,n);
     ipf565:PixelsFrom16(sp^,buf,n);
     ipf4444:PixelsFrom12(sp^,buf,n);
     ipfRGB:PixelsFrom24(sp^,buf,n);
     ipf8Bit:if PalFormat=palRGB then
       PixelsFrom8P24(sp^,buf,palette^,n) else
       PixelsFrom8P(sp^,buf,palette^,n);
    end;
    case destformat of
     ipf555:PixelsTo15(buf,dp^,n);
     ipf1555:PixelsTo15A(buf,dp^,n);
     ipf565:PixelsTo16(buf,dp^,n);
     ipf4444:PixelsTo12(buf,dp^,n);
     ipfRGB:PixelsTo24(buf,dp^,n);
    end;
   end;
   if count<=2048 then exit;
   dec(count,2048);
   inc(sp,2048*PixelSize[sourformat] div 8);
   inc(dp,2048*PixelSize[destformat] div 8);
  end;
 end;

{ TBitmapImage }

constructor TBitmapImage.Assign(w,h:integer;_data:pointer;_pitch:integer;_pf:TImagePixelFormat);
begin
 width:=w; height:=h;
 data:=_data;
 pitch:=_pitch;
 PixelFormat:=_pf;
end;

constructor TBitmapImage.Create(w,h:integer;pf:TImagePixelFormat;pal:ImagePaletteFormat;pSize:integer);
var
 palElSize:integer;
begin
 if (w<=0) or (h<=0) or (psize<0) then
  raise EError.Create('Images: Invalid parameters in TBMI.Create');
 case pf of
  ipf1bit: pitch:=(1+(w-1) div 32)*4;  // Выравнивание по 32бита
  ipf4bit: pitch:=(1+(w-1) div 8)*4;
  ipf8bit,ipfA8,ipfMono8: pitch:=(1+(w-1) div 8)*8;   // Выравнивание по 64 бита
  ipf555,ipf1555,ipf565,ipf4444: pitch:=(1+(w-1) div 4)*8;
  ipfRGB: pitch:=(1+(w-1) div 4)*12;
  ipfXRGB,ipfARGB,ipfXBGR,ipfABGR: pitch:=(1+(w-1) div 2)*8;
  ipfDXT1: pitch:=w*8;
  ipfDXT2,ipfDXT3: pitch:=w*16;
  else
   ASSERT(false,'Not implemented');
 end;
 PixelFormat:=pf;
 PaletteFormat:=pal;
 dataSize:=pitch*h;
 data:=AllocMem(dataSize);
 //fillchar(data^,dataSize,0);

 if pal<>palNone then begin
  case pal of
   palRGB: palElSize:=3;
   palARGB,palxRGB: palElSize:=4;
  end;
  palSize:=psize;
  GetMem(palette,psize*PalElSize);
 end else palette:=nil;

 width:=w;
 height:=h;
end;

destructor TBitmapImage.Destroy;
begin
  FreeMem(data);
  if palette<>nil then FreeMem(palette);
  inherited;
end;

procedure TBitmapImage.Expand(paddingLeft,paddingTop,paddingRight,paddingBottom:integer;color:cardinal);
var
 x,y,ps:integer;
 newData:pointer;
 newWidth,newHeight:integer;
 pb:PByte;
 c:cardinal;
begin
 newWidth:=width+paddingLeft+paddingRight;
 newHeight:=height+paddingTop+paddingBottom;
 ps:=pixelSize[pixelFormat] div 8;
 GetMem(newData,newWidth*newHeight*ps);
 pb:=newData;
 // Top part
 if ps=4 then
  FillDword(pb^,paddingTop*newWidth,color)
 else
  FillChar(pb^,paddingTop*newWidth*ps,color);
 inc(pb,paddingTop*newWidth*ps);
 // Main part
 for y:=0 to height-1 do begin
  if ps=4 then FillDword(pb^,paddingLeft,color)
   else FillChar(pb^,paddingLeft*ps,color);
  inc(pb,paddingLeft*ps);
  move(ScanLine(y)^,pb^,width*ps);
  inc(pb,width*ps);
  if ps=4 then FillDword(pb^,paddingRight,color)
   else FillChar(pb^,paddingRight*ps,color);
  inc(pb,paddingRight*ps);
 end;
 // Bottom part
 if ps=4 then
  FillDword(pb^,paddingBottom*newWidth,color)
 else
  FillChar(pb^,paddingBottom*newWidth*ps,color);

 // Assign new bitmap
 Freemem(data);
 data:=newData;
 width:=newWidth;
 height:=newHeight;
 pitch:=newWidth*ps;

 // Defringe transparent border pixels
 if (pixelFormat=ipfARGB) and (color shr 24=0) then begin
  for x:=0 to width-1 do begin
   c:=GetPixel(x,0);          /// TODO!
   c:=GetPixel(x,height-1);
  end;
 end;
end;

class function TBitmapImage.NeedLock: boolean;
begin
 result:=false;
end;

{ TRawImage }
procedure TRawImage.Clear(color: cardinal);
var
 x,y:integer;
 p1:PByte;
 p2:PCardinal;
begin
 p1:=data;
 for y:=0 to height-1 do begin
  if PixelSize[pixelFormat]=32 then begin // 32 bit image
   p2:=PCardinal(p1);
   for x:=0 to width-1 do begin
    p2^:=color; inc(p2);
   end;
  end else begin
   // conversion required
   // ...
  end;
  inc(p1,pitch);
 end;
end;

constructor TRawImage.Copy(src: TRawImage);
begin
 width:=src.width;
 height:=src.height;
 tag:=src.tag;
 pixelFormat:=src.PixelFormat;
 paletteFormat:=src.paletteFormat;
 data:=src.data;
 pitch:=src.pitch;
 palette:=src.palette;
 palSize:=src.palSize;
end;

procedure TRawImage.CopyPixelDataFrom(src: TRawImage);
var
 sp,dp:PByte;
 i:integer;
begin
 ASSERT((src.width>=width) and (src.height>=height));
 src.Lock;
 Lock;
 try
  sp:=src.data;
  dp:=data;
  for i:=0 to height-1 do begin
   ConvertLine(sp^,dp^,src.PixelFormat,pixelFormat,width);
   inc(sp,src.pitch);
   inc(dp,pitch);
  end;
 finally
  Unlock;
  src.Unlock;
 end;
end;

function TRawImage.GetPixel(x,y:integer):cardinal;
var
 pb:PByte;
 size:integer;
begin
 result:=0;
 if (x<0) or (y<0) or (x>=width) or (y>=height) then exit;
 pb:=data;
 size:=pixelSize[PixelFormat] shr 3;
 inc(pb,y*pitch+x*size);
 move(pb^,result,size);
end;

function TRawImage.GetPixelAddress(x,y:integer):pointer;
var
 pb:PByte;
begin
 ASSERT((x>=0) and (y>=0) and (x<width) and (y<height));
 pb:=data;
 inc(pb,y*pitch+x*(pixelSize[PixelFormat] shr 3));
 result:=pb;
end;

function TRawImage.GetPixelARGB(x,y:integer):cardinal;
begin
 result:=GetPixel(x,y);
 ASSERT(@colorFrom[pixelFormat]<>nil,'Unsupported pixel format');
 result:=colorFrom[pixelFormat](result);
end;

procedure TRawImage.SetAsRenderTarget;
begin
 SetRenderTarget(data,pitch,width,height);
end;

procedure TRawImage.SetPixel(x,y:integer;value:cardinal);
var
 pb:PByte;
 size:integer;
begin
 if (x<0) or (y<0) or (x>=width) or (y>=height) then exit;
 pb:=data;
 size:=pixelSize[PixelFormat] shr 3;
 inc(pb,y*pitch+x*size);
 move(value,pb^,size);
end;

procedure TRawImage.Lock;
begin
end;

class function TRawImage.NeedLock: boolean;
begin
 result:=false;
end;

function TRawImage.ScanLine(y: integer): pointer;
begin
 result:=pointer(PtrUInt(data)+y*pitch);
end;

procedure TRawImage.Unlock;
begin
end;

initialization
 ColorTo[ipfARGB]:=ColorTo32;
 ColorTo[ipfXRGB]:=ColorTo32;
 ColorTo[ipfRGB]:=ColorTo24;
 ColorTo[ipf4444]:=ColorTo12;
 ColorTo[ipf565]:=ColorTo16;
 ColorTo[ipf1555]:=ColorTo15A;
 ColorTo[ipf555]:=ColorTo15;

 colorFrom[ipfARGB]:=ColorFrom32;
 colorFrom[ipfXRGB]:=ColorFrom24;
 colorFrom[ipfRGB]:=ColorFrom24;
end.
