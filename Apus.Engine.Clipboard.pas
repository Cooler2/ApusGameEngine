// System clipboard: text and images
//
// Copyright (C) 2011-2026 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

// Windows: WinAPI for text and images (with any platform layer, native or SDL).
// Other platforms: text via SDL; no images (HasImage=false, GetImage=nil).
// Threads: on Windows any thread; with SDL - the window thread (where UI input is handled).
{$I defines.inc}
unit Apus.Engine.Clipboard;
interface
uses Apus.Core, Apus.Images;

type
  Clipboard=record
    // Text, UTF-8
    // Has* is a hint and may be slow on some platforms (X11): don't poll it every frame
    class function HasText:boolean; static;
    class function GetText:String8; static; // '' if the clipboard holds no text
    class procedure SetText(const st:String8); overload; static;
    {$IFDEF UNICODE}
    class procedure SetText(const st:UnicodeString); overload; static;
    {$ENDIF}
    // Image
    class function HasImage:boolean; static; // format check only, no decoding
    class function GetImage:TBitmapImage; static; // new ARGB image (caller frees), nil if none
    class procedure SetImage(image:TRawImage); static; // the image is copied, the caller keeps it
  end;

implementation
uses Apus.Strings
  {$IFDEF MSWINDOWS},Windows,SysUtils,Apus.GfxFormats{$ELSE}{$IFDEF SDL},SysUtils,sdl2{$ENDIF}{$ENDIF};

{$IFDEF UNICODE}
class procedure Clipboard.SetText(const st:UnicodeString);
 begin
  SetText(UTF8.FromWide(st));
 end;
{$ENDIF}

{$IFDEF MSWINDOWS}
procedure Open;
 var
  counter:integer;
 begin
  for counter:=1 to 20 do
   if OpenClipboard(0) then exit
    else sleep(10);
  raise EWarning.Create('Failed to open Clipboard');
 end;

procedure SetBuffer(format:word; var buffer; size:integer);
 var
  dataPtr:pointer;
  data:THandle;
 begin
  Open;
  data:=GlobalAlloc(GMEM_MOVEABLE,size);
  try
   dataPtr:=GlobalLock(data);
   try
    Move(buffer,dataPtr^,size);
    if SetClipboardData(format,data)=0 then
     raise EWarning.Create('Failed to set clipboard data');
   finally
    GlobalUnlock(data);
   end;
  except
   GlobalFree(data);
  end;
  CloseClipboard;
 end;

function GetTextBufW:WideString;
 var
  data:THandle;
  p:pointer;
  size:integer;
 begin
  Open;
  data:=GetClipboardData(CF_UNICODETEXT);
  if data=0 then
   result:=''
  else begin
   p:=GlobalLock(data);
   size:=GlobalSize(data);
   SetLength(result,size div 2);
   Move(p^,result[1],size);
   GlobalUnlock(data);
  end;
  CloseClipboard;
  // the text ends with #0 - remove it
  if (length(result)>0) and (result[length(result)]=#0) then
   SetLength(result,length(result)-1);
 end;

// Registered "PNG" format: browsers and image editors put images with alpha in it
function PNGFormat:cardinal;
 begin
  result:=RegisterClipboardFormat('PNG');
 end;

// Clipboard must be open
function PastePNG(format:cardinal):TBitmapImage;
 var
  h:THandle;
  p:pointer;
  data:ByteArray;
  img:TRawImage;
 begin
  result:=nil;
  h:=GetClipboardData(format);
  if h=0 then exit;
  p:=GlobalLock(h);
  if p=nil then exit;
  try
   SetLength(data,GlobalSize(h));
   move(p^,data[0],length(data));
  finally
   GlobalUnlock(h);
  end;
  if CheckImageFormat(data)<>ifPNG then exit;
  img:=TBitmapImage.Create(imgInfo.width,imgInfo.height,ipfARGB);
  try
   LoadPNG(data,img);
   result:=TBitmapImage(img);
  except
   img.Free;
  end;
 end;

// Clipboard must be open. 24 or 32 bpp uncompressed DIB
function PasteDIB:TBitmapImage;
 var
  h:THandle;
  hdr:PBitmapInfoHeader;
  bits,src:PByte;
  dst:PCardinal;
  w,hgt,x,y,bpp,pitch:integer;
  anyAlpha:boolean;
 begin
  result:=nil;
  h:=GetClipboardData(CF_DIB);
  if h=0 then exit;
  hdr:=GlobalLock(h);
  if hdr=nil then exit;
  try
   bpp:=hdr.biBitCount;
   if not (bpp in [24,32]) or not (hdr.biCompression in [BI_RGB,BI_BITFIELDS]) then exit;
   w:=hdr.biWidth;
   hgt:=abs(hdr.biHeight);
   bits:=PByte(hdr)+hdr.biSize+hdr.biClrUsed*4;
   if (hdr.biCompression=BI_BITFIELDS) and (hdr.biSize=SizeOf(TBitmapInfoHeader)) then
    inc(bits,12); // color masks follow the header
   pitch:=((w*bpp+31) div 32)*4;
   result:=TBitmapImage.Create(w,hgt,ipfARGB);
   anyAlpha:=false;
   for y:=0 to hgt-1 do begin
    if hdr.biHeight>0 then src:=bits+(hgt-1-y)*pitch // bottom-up
     else src:=bits+y*pitch;
    dst:=result.ScanLine(y);
    for x:=0 to w-1 do begin
     if bpp=32 then begin
      dst^:=PCardinal(src)^;
      if dst^ shr 24<>0 then anyAlpha:=true;
      inc(src,4);
     end else begin
      dst^:=$FF000000 or src[0] or (src[1] shl 8) or (src[2] shl 16);
      inc(src,3);
     end;
     inc(dst);
    end;
   end;
   // most programs leave the alpha byte of a 32 bpp DIB zero: treat such an image as opaque
   if (bpp=32) and not anyAlpha then
    for y:=0 to hgt-1 do begin
     dst:=result.ScanLine(y);
     for x:=0 to w-1 do begin
      dst^:=dst^ or $FF000000;
      inc(dst);
     end;
    end;
  finally
   GlobalUnlock(h);
  end;
 end;

class function Clipboard.HasText:boolean;
 begin
  result:=IsClipboardFormatAvailable(CF_UNICODETEXT);
 end;

class function Clipboard.GetText:String8;
 begin
  result:=UTF8.FromWide(GetTextBufW);
 end;

class procedure Clipboard.SetText(const st:String8);
 var
  wst:WideString;
 begin
  wst:=UTF8.ToWide(st);
  SetBuffer(CF_UNICODETEXT,PWideChar(wst)^,2*length(wst)+2); // additional 2 bytes for #0 terminator
 end;

class function Clipboard.HasImage:boolean;
 begin
  result:=IsClipboardFormatAvailable(PNGFormat) or IsClipboardFormatAvailable(CF_DIB);
 end;

class function Clipboard.GetImage:TBitmapImage;
 var
  png:cardinal;
 begin
  result:=nil;
  Open;
  try
   png:=PNGFormat;
   if IsClipboardFormatAvailable(png) then result:=PastePNG(png);
   if (result=nil) and IsClipboardFormatAvailable(CF_DIB) then result:=PasteDIB;
  finally
   CloseClipboard;
  end;
 end;

class procedure Clipboard.SetImage(image:TRawImage);
 const
  masks:array[0..2] of cardinal=($FF,$FF00,$FF0000);
 var
  header:TBitmapInfoHeader;
  cbData:ByteArray;
  size,i,pos:integer;
  pb:PByte;
 begin
  with image do begin
   ZeroMemory(@header,sizeof(header));

   header.biSize:=sizeof(header);
   header.biWidth:=width;
   header.biHeight:=height;
   header.biPlanes:=1;
   header.biBitCount:=pixelSize[PixelFormat];
   header.biCompression:=BI_RGB; // BI_BITFIELDS; //
   size:=width*height*pixelSize[PixelFormat] div 8;
   //header.biSizeImage:=size;
   header.biXPelsPerMeter:=2835; // 72 DPI
   header.biYPelsPerMeter:=2835; // 72 DPI

   SetLength(cbData,sizeof(header)+size);
   move(header,cbData[0],sizeof(header));
   pb:=data;
   pos:=sizeof(header);
   if header.biCompression=BI_BITFIELDS then begin
    move(masks,cbData[pos],sizeof(masks));
    inc(pos,sizeof(masks));
   end;
   size:=size div height; // scanline size
   inc(pb,pitch*(height-1)); // flip vertical
   for i:=0 to height-1 do begin
    move(pb^,cbData[pos],size);
    dec(pb,pitch);
    inc(pos,size);
   end;
   SetBuffer(CF_DIB,cbData[0],Length(cbData));
  end;
 end;

{$ELSE}{$IFDEF SDL}

class function Clipboard.HasText:boolean;
 begin
  result:=SDL_HasClipboardText=SDL_TRUE;
 end;

class function Clipboard.GetText:String8;
 var
  p:PAnsiChar;
 begin
  result:='';
  p:=SDL_GetClipboardText;
  if p=nil then exit;
  SetLength(result,StrLen(p)); // raw copy: SDL text is UTF-8, no codepage conversion
  if result<>'' then move(p^,result[1],length(result));
  SDL_free(p);
 end;

class procedure Clipboard.SetText(const st:String8);
 begin
  SDL_SetClipboardText(PAnsiChar(st));
 end;

class function Clipboard.HasImage:boolean;
 begin
  result:=false;
 end;

class function Clipboard.GetImage:TBitmapImage;
 begin
  result:=nil;
 end;

class procedure Clipboard.SetImage(image:TRawImage);
 begin
 end;

{$ELSE} // no platform clipboard

class function Clipboard.HasText:boolean;
 begin
  result:=false;
 end;

class function Clipboard.GetText:String8;
 begin
  result:='';
 end;

class procedure Clipboard.SetText(const st:String8);
 begin
 end;

class function Clipboard.HasImage:boolean;
 begin
  result:=false;
 end;

class function Clipboard.GetImage:TBitmapImage;
 begin
  result:=nil;
 end;

class procedure Clipboard.SetImage(image:TRawImage);
 begin
 end;

{$ENDIF}{$ENDIF}

end.
