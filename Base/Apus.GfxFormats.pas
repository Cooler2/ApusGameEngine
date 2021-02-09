﻿// Support for common image file formats
//
// Copyright (C) 2004 Apus Software
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.GfxFormats;
interface
 uses Apus.MyServis,
     {$IFDEF TXTIMAGES}Apus.UnicodeFont,{$ENDIF}
     Apus.Images;
 type
  TImageFileType=(ifUnknown,ifTGA,ifJPEG,ifPJPEG,ifBMP,ifPCX,ifTXT,ifDDS,ifPVR,ifPNG);
  TImageFileInfo=record
   width,height:integer;
   format:TImagePixelFormat;
   palformat:ImagePaletteFormat;
   miplevels:integer;
  end;

 threadvar
  imgInfo:TImageFileInfo; // info about last checked image

 // Guess image format and extract key image parameters into imgInfo without unpacking the whole image
 function CheckFileFormat(fname:string):TImageFileType;
 function CheckImageFormat(data:ByteArray):TImageFileType;

 // Load TGA image from data stream into, if image was created before, image conversion will be applied
 procedure LoadTGA(data:ByteArray;var image:TRawImage;allocate:boolean=false);
 // Write image in TGA format into buffer, return size of TGA data
 function SaveTGA(image:TRawImage):ByteArray;

 {$IFDEF TXTIMAGES}
 // TXT is a dummy image format for prototyping (specify text drawing func!)
 procedure LoadTXT(data:ByteArray;var image:TRawImage;txtSmallFont,txtNormalFont:TUnicodeFont);
 {$ENDIF}
 // DirectDrawSurface
 procedure LoadDDS(data:ByteArray;var image:TRawImage;allocate:boolean=false);

 // Always allocates new image object
 procedure LoadPVR(data:ByteArray;var image:TRawImage;allocate:boolean=false);

 // JPEG format (different methodf for Delphi and FPC)
 procedure LoadJPEG(data:ByteArray;var image:TRawImage);
 procedure SaveJPEG(image:TRAWimage;filename:string;quality:integer);

 // PNG import using LodePNG (lodePNG.dll under Windows)
 procedure LoadPNG(data:ByteArray;var image:TRawImage);
 function SavePNG(image:TRawImage):ByteArray;

 // ICO/CUR file format
 procedure LoadCUR(data:ByteArray;var image:TRawImage;out hotX,hotY:integer);

 {$IFNDEF FPC}
 {$IFNDEF DELPHI}
 For Delphi - define global symbol "DELPHI"!
 {$ENDIF}
 {$ENDIF}


implementation
 uses {$IFDEF DELPHI}
       {$IF CompilerVersion >= 20.0}VCL.Graphics,VCL.Imaging.jpeg,{$ELSE}Graphics,Jpeg,{$IFEND}
      {$ENDIF}
      {$IFDEF FPC}FPImage,FPReadJPEG,FPWriteJPEG,FPReadPNG,FPWritePNG,{$ENDIF}
      Classes,SysUtils,Math,Apus.Colors;

type
 TGAheader=packed record
  idsize:byte;
  paltype:byte;
  imgtype:byte;
  palstart:word;
  palsize:word;
  palentrysize:byte;
  imgx,imgy:smallint;
  imgwidth,imgheight:smallint;
  bpp:byte;
  descript:byte;
 end;

 // DDS Header is DDSURFACEDESC2
 DWORD=cardinal;
 TDDColorKey=record
  low,high:DWORD;
 end;
 TDDPixelFormat=record
  dwSize: DWORD;                 // size of structure
  dwFlags: DWORD;                // pixel format flags
  dwFourCC: DWORD;               // (FOURCC code)
  dwRGBBitCount : DWORD;  // how many bits per pixel
  dwRBitMask : DWORD;  // mask for red bit
  dwGBitMask : DWORD;  // mask for green bits
  dwBBitMask : DWORD;  // mask for blue bits
  dwRGBAlphaBitMask : DWORD; // mask for alpha channel
 end;
 DDSHeader=packed record
  dwSize: DWORD;                   // size of the TDDSurfaceDesc structure
  dwFlags: DWORD;                  // determines what fields are valid
  dwHeight: DWORD;                 // height of surface to be created
  dwWidth: DWORD;                  // width of input surface
  dwLinearSize : DWORD;            // Formless late-allocated optimized surface size
  dwBackBufferCount: DWORD;        // number of back buffers requested
  dwMipMapCount: DWORD;            // number of mip-map levels requested
  dwAlphaBitDepth: DWORD;          // depth of alpha buffer requested
  dwReserved: DWORD;               // reserved
  lpSurface: Pointer;              // pointer to the associated surface memory
  ddckCKDestOverlay: TDDColorKey;  // color key for destination overlay use
  ddckCKDestBlt: TDDColorKey;      // color key for destination blt use
  ddckCKSrcOverlay: TDDColorKey;   // color key for source overlay use
  ddckCKSrcBlt: TDDColorKey;       // color key for source blt use
  ddpfPixelFormat: TDDPixelFormat; // pixel format description of the surface
  ddsCaps,ddsCaps2,ddsCaps3,
  ddsCaps4: DWORD;                 // direct draw surface capabilities
  dwTextureStage: DWORD;           // stage in multitexture cascade
 end;

 PVRheader=packed record
  headerLength:cardinal;
  height,width,mipMaps:cardinal;
  flags,dataLength,bpp:cardinal;
  bitmaskRed,bitmaskGreen,bitmaskBlue,bitmaskAlpha:cardinal;
  pvrTag,numSurf:cardinal;
 end;

 {$IFDEF FPC}
 TMyFPImage=class(TFPMemoryImage)
  function GetScanline(y:integer):pointer;
 end;

 function TMyFPImage.GetScanline(y:integer):pointer;
  var
   l:integer;
  begin
   result:=@(FData^[y*Width*2]);
  end;
 {$ENDIF}

procedure LoadPVR(data:ByteArray;var image:TRawImage;allocate:boolean=false);
 var
  head:^PVRheader;
  pb:PByte;
  linesize,y:integer;
  sp,dp:PByte;
 begin
  CheckImageFormat(data);
  head:=@data[0];
  pb:=@data[0];
  inc(pb,head.headerLength);
  if allocate then begin
   // Allocate new image
   image:=Apus.Images.TBitmapImage.Create(imginfo.width,imginfo.height,imginfo.format,palNone,0);
   move(pb^,image.data^,imginfo.width*imginfo.height*PixelSize[imginfo.format] div 8);
  end else begin
   linesize:=pixelsize[imginfo.format]*imginfo.width div 8;
   // conversion may be required
   for y:=0 to imginfo.height-1 do begin
    sp:=pb;
    if head.flags and $10000=0 then inc(sp,y*imginfo.width*PixelSize[imginfo.format] div 8)
     else inc(sp,(imginfo.height-1-y)*imginfo.width*PixelSize[imginfo.format] div 8); // vertical flip

    dp:=image.data; inc(dp,y*image.pitch);
    if imginfo.format<>image.PixelFormat then begin
     // Copy data with format conversion
     ConvertLine(sp^,dp^,imginfo.format,image.PixelFormat,sp^,palNone,imginfo.width);
    end else // Just copy data
     move(sp^,dp^,linesize);
   end; // for
  end;
 end;

procedure LoadDDS(data:ByteArray;var image:TRawImage;allocate:boolean=false);
 var
  pc:^cardinal;
  head:^DDSheader;
  width,height:integer;
  format:TImagePixelFormat;
  info:TImageFileInfo;
  linesize,y:integer;
  sp,dp:PByte;
 begin
  pc:=@data[0];
  inc(pc);
  head:=pointer(pc);
  info:=ImgInfo;
  CheckImageFormat(data);
  width:=imgInfo.width;
  height:=imgInfo.height;
  format:=imgInfo.format;
  imgInfo:=info;
  if format in [ipfDXT1..ipfDXT5] then begin
   width:=(width+3) div 4;
   height:=(height+3) div 4;
  end;
  linesize:=pixelsize[format]*width div 8;

  if allocate then begin
   // Allocate new image
   image:=Apus.Images.TBitmapImage.Create(width,height,format,palNone,0);
   inc(pc,sizeof(DDSheader) div 4);
   /// TODO: MipMaps!
   move(pc^,image.data^,width*height*PixelSize[format] div 8);
  end else begin
   // conversion may be required
   inc(pc,sizeof(DDSheader) div 4);
   for y:=0 to height-1 do begin
    sp:=pointer(pc); inc(sp,y*width*PixelSize[format] div 8);
    dp:=image.data; inc(dp,y*image.pitch);
    if format<>image.PixelFormat then begin
     // Copy data with format conversion
     ConvertLine(sp^,dp^,format,image.PixelFormat,sp^,palNone,width);
    end else // Just copy data
     move(sp^,dp^,linesize);
   end; // for
  end;
 end;

procedure LoadTGA;
 var
  i,j,y:integer;
  col:cardinal;
  pb,pb2,sp,dp,pp,sourPal:PByte;
  rlebuf:pointer;
  head:^TGAheader;
  format:TImagePixelFormat;
  palformat:ImagePaletteFormat;
  x1,y1,x2,y2:integer; // position onto the target image
  width,height:integer; // dimensions of the target area
  conversion:boolean; // pixel format conversion needed?
  color:cardinal;
  pitch,linesize:integer;
 begin
  pb:=@data[0];
  head:=@data[0];
  // Check if data has proper type
  if not head.imgtype in [1,2,10] then
   raise EError.Create('Unsupported TGA image type - '+inttostr(head.imgtype));
  if (head.paltype=1) and (not head.palentrysize in [24,32]) then
   raise EError.Create('Unsupported TGA palette type - '+inttostr(head.paltype));
  if not head.bpp in [8,16,24,32] then
   raise EError.Create('Unsupported TGA bpp - '+inttostr(head.bpp));
  if (head.imgwidth>8192) or (head.imgheight>8192) then
   raise EError.Create('TGA image is too large');

  // Determine source formats
  palformat:=palNone;
  case head.bpp of
   8:begin
      format:=ipf8Bit;
      if head.paltype=1 then
       if head.palentrysize=24 then palformat:=palRGB else
        palformat:=palARGB;
     end;
   16:format:=ipf1555;
   24:format:=ipfRGB;
   32:format:=ipfARGB;
  end;

  if allocate then begin
   // Allocate new image
   image:=Apus.Images.TBitmapImage.Create(head.imgwidth,head.imgheight,format,palformat,
    head.palstart+head.palsize);
   x1:=0; y1:=0; x2:=head.imgwidth-1; y2:=head.imgheight-1;
   width:=head.imgwidth; height:=head.imgheight;
   conversion:=false;
  end else begin
   // check image for necessary conversions
   if (palformat<>palNone) and (image.palsize>0) and (image.palSize<head.palstart+head.palsize) then
    raise EWarning.Create('Too small palette!');
   if (image.paletteFormat<>palNone) and (palformat=palnone) then
    raise Ewarning.Create('No conversion to 8bit palette in loader!');
   x1:=0; y1:=0;
   x2:=min(head.imgwidth,image.width)-1;
   y2:=min(head.imgheight,image.height)-1;
   width:=x2-x1+1; height:=y2-y1+1;
   conversion:=format<>image.PixelFormat;
  end;

  pb:=@data[0];
  inc(pb,sizeof(TGAheader));
  inc(pb,head.idsize);
  sourPal:=pb;
  if head.paltype=1 then
   inc(pb,head.palsize*head.palentrysize div 8);


  // RLE decompression to temp buffer (if needed)
  {$IFDEF FPC} {$PUSH} {$ENDIF}
  {$R-}
  if head.imgtype=10 then begin
   i:=width*height;
   getmem(rlebuf,i*head.bpp div 8);
   dp:=rlebuf;
   while i>0 do begin
    j:=(pb^ and $7F)+1;
    if j>i then j:=i;
    dec(i,j);
    if pb^ and $80=0 then begin
     inc(pb);
     j:=j*head.bpp div 8;
     move(pb^,dp^,j);
     inc(pb,j);
     inc(dp,j);
    end else begin
     inc(pb);
     case head.bpp of
      32:begin col:=PInteger(pb)^;
       while j>0 do begin
        PInteger(dp)^:=col;
        inc(dp,4);
        dec(j);
       end;
       inc(pb,4);
      end;
      24:begin
       col:=pb^; inc(pb);
       col:=col+pb^ shl 8;  inc(pb);
       col:=col+pb^ shl 16; inc(pb);
       while j>0 do begin
        move(col,dp^,3);
        inc(dp,3);
        dec(j);
       end;
      end;
     end;
    end;
   end;
   pb:=rlebuf;
  end;

  // Write pallette if needed
  if image.paletteFormat<>palNone then begin
   pb2:=image.palette;
   inc(pb2,head.palstart*head.palentrysize div 8);
   pb:=@data[0];
   inc(pb,pb^+18);
   for i:=1 to head.palsize do begin
    color:=pb^; inc(pb);
    color:=color+pb^ shl 8; inc(pb);
    color:=color+pb^ shl 16; inc(pb);
    if palformat=palARGB then
     color:=color+pb^ shl 24; inc(pb);
    if image.paletteFormat=palARGB then begin
     move(color,pb2^,4); inc(pb2,4);
    end else begin
     move(color,pb2^,3); inc(pb2,3);
    end;
   end;
  end;

  if head.descript and $20=0 then begin
   // Down->up
   pb2:=image.data; inc(pb2,y2*image.pitch);
   pitch:=-image.pitch;
  end else begin
   // Up->down
   pb2:=image.data; pitch:=image.pitch;
  end;

  // Now fill image data itself
  linesize:=width*head.bpp div 8;
  for y:=0 to height-1 do begin
   if conversion then begin
    // Copy data with format conversion
    sp:=pb; dp:=pb2;
    ConvertLine(sp^,dp^,format,image.PixelFormat,sourPal^,palFormat,width);
   end else // Just copy data
     move(pb^,pb2^,linesize);

   inc(pb,head.imgwidth*head.bpp div 8);
   inc(pb2,pitch);
  end;
  {$IFDEF FPC} {$POP} {$ENDIF}

  // Free temp buffer (if used)
  if head.imgtype=10 then
   freemem(rlebuf);
 end;

 function SaveTGA(image:TRawImage):ByteArray;
  var
   pb,sp:PByte;
   head:TGAHeader;
   i,paldepth,bpp,y,size:integer;
  begin
   i:=image.width*image.height;
   case image.PixelFormat of
    ipfRGB:bpp:=3;
    ipfXRGB,ipfARGB:bpp:=4;
    ipf8Bit,ipfA8,ipfMono8:bpp:=1;
    else raise EError.Create('SaveTGA: invalid pixel format!');
   end;
   size:=i*bpp;
   if (image.PixelFormat=ipf8bit) and (image.paletteFormat<>palNone) then begin
    i:=image.palSize;
    case image.paletteFormat of
     palRGB:paldepth:=3;
     else paldepth:=4;
    end;
    i:=i*paldepth;
    inc(size,i);
   end;
   inc(size,sizeof(head));
   SetLength(result,size);

   fillchar(head,sizeof(head),0);
   if image.paletteFormat<>palNone then begin
    head.paltype:=1;
    head.palstart:=0;
    head.palsize:=image.palSize;
    head.palentrysize:=paldepth*8;
    head.imgtype:=1;
   end else begin
    head.paltype:=0;
    head.imgtype:=2;
    if bpp=1 then head.imgType:=3;
   end;
   head.imgwidth:=image.width;
   head.imgheight:=image.height;
   head.bpp:=bpp*8;
   head.descript:=$28;
   move(head,result[0],sizeof(head));
   pb:=@result[sizeof(head)];
   if head.paltype=1 then begin
    move(image.palette^,pb^,paldepth*head.palsize);
    inc(pb,paldepth*head.palsize);
   end;
   sp:=image.data;
   for y:=0 to image.height-1 do begin
    move(sp^,pb^,image.width*bpp);
    inc(sp,image.pitch);
    inc(pb,image.width*bpp);
   end;
  end;

 {$IFDEF TXTIMAGES}
 procedure LoadTXT(data:ByteArray;var image:TRawImage;txtSmallFont,txtNormalFont:TUnicodeFont);
  var
   size:integer;
   w,h,i,line,word,mode,r,g,b,x,y:integer;
   c:^char;
   st,str:string;
   bgnd,border,text:cardinal;
   img:TRawImage;
   lines:array[1..100] of string;
   lx,ly:array[1..100] of integer;
   lcnt:integer;
   pixel:PCardinal;
   curfont:TUnicodeFont;
  procedure HandleWord;
   begin
    if st='' then exit;
    // обработка накопленного слова
    if (line=1) and (word=1) then w:=StrToInt(st);
    if (line=1) and (word=2) then h:=StrToInt(st);
    if line in [2..4] then begin
     if word=1 then r:=StrToInt(st);
     if word=2 then g:=StrToInt(st);
     if word=3 then b:=StrToInt(st);
    end;
    if (line>4) and (line mod 2=1) then
     if word=1 then x:=StrToInt(st) else y:=StrToInt(st);
    st:='';
   end;
  begin
   size:=length(data);
   // парсинг текста
   r:=255; g:=255; b:=255;
   line:=1; word:=1; c:=@data[0]; st:='';
   mode:=1; // текст
   lcnt:=0; str:='';
   for i:=1 to size+1 do begin
    if (i>size) or (c^ in [' ',#8]) then begin
     // разделитель
     mode:=2;
     if i<=size then str:=str+c^;
     HandleWord;
     if i>size then begin
      if line=4 then text:=MyColor(r,g,b);
      if (line>4) and (line mod 2=0) and (lcnt<length(lines)) then begin
       inc(lcnt); lines[lcnt]:=str; lx[lcnt]:=x; ly[lcnt]:=y;
      end;
     end;
    end else
    if c^ in [#10,#13] then begin
     HandleWord;
     // разделитель строки
     if c^=#10 then begin
      if line=1 then img:=Apus.Images.TBitmapImage.Create(w,h);
      if line=2 then bgnd:=MyColor(r,g,b);
      if line=3 then border:=MyColor(r,g,b);
      if line=4 then text:=MyColor(r,g,b);
      if (line>4) and (line mod 2=0) and (lcnt<length(lines)) then begin
       inc(lcnt); lines[lcnt]:=str; lx[lcnt]:=x; ly[lcnt]:=y;
      end;
      inc(line); str:='';
     end;
     mode:=3;
    end else begin
     // просто символ
     if mode>2 then word:=0;
     if mode>1 then begin mode:=1; inc(word); end;
     st:=st+c^; str:=str+c^;
    end;
    inc(c);
   end;
   // Начинаем рисовать
   for y:=0 to h-1 do begin
    pixel:=img.data;
    inc(pixel,y*img.pitch div 4);
    for x:=0 to w-1 do begin
     if (y=0) or (x=0) or (y=h-1) or (x=w-1) then pixel^:=border else pixel^:=bgnd;
     inc(pixel);
    end;
   end;
   {$IFDEF CPU386}
   if lcnt>0 then begin
    if (txtSmallFont=nil) or (txtNormalFont=nil) then
     raise EWarning.Create('TXT: undefined fonts');

    //  TODO: IMPORTANT! Add clipping!
    for i:=1 to lcnt do begin
     if pos('!',lines[i])=1 then begin
      delete(lines[i],1,1);
      curfont:=txtSmallFont;
     end else curfont:=txtNormalFont;

     curFont.RenderText(img.data,img.pitch,
      lx[i]-curFont.GetTextWidth(lines[i]) div 2,ly[i],lines[i],text);
    end;
   end;
   {$ENDIF}

   image:=img;
  end;
 {$ENDIF}

 function CheckFileFormat(fname:string):TImageFileType;
  var
   f:file;
   buf:ByteArray;
   size:integer;
  begin
   result:=ifUnknown;
   Assign(f,fname);
   Reset(f,1);
   size:=filesize(f);
   if size>30 then begin
    SetLength(buf,size);
    BlockRead(f,buf[0],size);
    result:=CheckImageFormat(buf);
   end;
   Close(f);
  end;

 function CheckImageFormat(data:ByteArray):TImageFileType;
  var
   pb:PByte;
   pc:^cardinal;
   dds:^DDSheader;
   tga:^TGAheader;
   pvr:^PVRheader;
   i,j:integer;
   fl:boolean;
   bitdepth:byte;
  begin
   result:=ifUnknown;
   imginfo.miplevels:=1;
   // Check for PNG
   if (data[0]=$89) and (data[1]=$50) and (data[2]=$4E) and (data[3]=$47) then begin
    result:=ifPNG;
    imginfo.palformat:=palNone;
    imginfo.miplevels:=0;
    for i:=4 to length(data)-20 do
     if data[i]=$49 then begin
      if (data[i+1]=$48) and (data[i+2]=$44) and (data[i+3]=$52) then begin
       imginfo.width:=data[i+7]+data[i+6]*256;
       imginfo.height:=data[i+11]+data[i+10]*256;
       bitDepth:=data[i+12];
       if bitDepth=8 then
        case data[i+13] of
         0:imginfo.format:=ipfMono8;
         2:imginfo.format:=ipfXRGB;
         3:imginfo.format:=ipf8bit;
         4:imginfo.format:=ipfDuo8;
         6:imginfo.format:=ipfARGB;
        end
       else if bitDepth=16 then
        case data[i+13] of
         0:imginfo.format:=ipfMono16;
        end;
       break;
      end;
     end;
    exit;
   end;
   // check for PVR
   pvr:=@data[0];
   if (pvr.headerLength=52) and (pvr.pvrTag=$21525650) then begin
    result:=ifPVR;
    imginfo.width:=pvr.width;
    imginfo.height:=pvr.height;
    imginfo.miplevels:=pvr.mipMaps;
    case pvr.flags and $FF of
     0,$10:imgInfo.format:=ipf4444r;
     1,$11:imgInfo.format:=ipf1555;
     2,$13:imgInfo.format:=ipf565;
     3,$14 :imgInfo.format:=ipf555;
     $19,$D:imgInfo.format:=ipfPVRTC;
     else imgInfo.format:=ipfNone;
    end;
    exit;
   end;
   // Check for DDS
   pc:=@data[0];
   if pc^=$20534444 then begin
    result:=ifDDS;
    inc(pc); dds:=pointer(pc);
    fillchar(imginfo,sizeof(imginfo),0);
    imginfo.width:=dds.dwWidth;
    imginfo.height:=dds.dwheight;
    if dds.ddpfPixelFormat.dwFourCC=$31545844 then imginfo.format:=ipfDXT1 else
    if dds.ddpfPixelFormat.dwFourCC=$32545844 then imginfo.format:=ipfDXT2 else
    if dds.ddpfPixelFormat.dwFourCC=$33545844 then imginfo.format:=ipfDXT3 else
    if dds.ddpfPixelFormat.dwFourCC=$35545844 then imginfo.format:=ipfDXT5;
    imginfo.miplevels:=dds.dwMipMapCount;
    exit;
   end;
   // Check for jpeg
   if (data[0]=$ff) and (data[1]=$D8) then begin
    result:=ifJPEG;
    fillchar(imginfo,sizeof(imginfo),0);
    imgInfo.format:=ipfRGB;
    imgInfo.palformat:=palNone;
    imgInfo.miplevels:=0;
    i:=2;
    while i<length(data) do begin
     if data[i]=$FF then begin
      j:=data[i+2]*256+data[i+3];
      if data[i+1] in [$C0,$C2] then begin // SOF0 or SOF2
       imgInfo.height:=max2(imgInfo.height,data[i+5] shl 8+data[i+6]);
       imgInfo.width:=max2(imgInfo.width,data[i+7] shl 8+data[i+8]);
      end;
      inc(i,j+2);
     end else
      inc(i);
    end;
    exit;
   end;
   // check for tga
   tga:=@data[0];
   if (tga.imgtype in [1,2,3,9,10,11]) and (tga.bpp in [8,16,24,32]) and
      (tga.paltype<2) and (tga.palsize<=256) then begin
    result:=ifTGA;
    imginfo.width:=tga.imgwidth;
    imginfo.height:=tga.imgheight;
    case tga.bpp of
     8:imginfo.format:=ipf8Bit;
     16:imginfo.format:=ipf1555;
     24:imginfo.format:=ipfRGB;
     32:imginfo.format:=ipfARGB;
    end;
    if tga.paltype=0 then imginfo.palformat:=palNone else
     case tga.palentrysize of
      24:imginfo.palformat:=palRGB;
      32:imginfo.palformat:=palARGB;
     end;
    exit;
   end;
   // check for BMP

   // check for txt
   fl:=true;
   for i:=1 to min2(10,length(data)) do begin
    if not (data[i] in [$30..$39,32,10,13,8]) then fl:=false;
   end;
   if fl then result:=ifTXT;
  end;

 {$IFDEF FPC}
 procedure LoadImageUsingReader(reader:TFPCustomImageReader;data:ByteArray;hasAlpha:boolean;
    var image:TRawImage);
  var
   img:TMyFPImage;
   src:TMemoryStream;
   sp,dp:PByte;
   i,j,w,h:integer;
   c:cardinal;
  begin
   // Source data as TMemoryStream
   src:=TMemoryStream.Create;
   src.Write(data[0],length(data));
   src.Seek(0,soFromBeginning);

   // Load image
   img:=TMyFPImage.create(0,0);
   img.LoadFromStream(src,reader);
   src.Free;

   // Allocate dest image if needed
   if image=nil then
    if hasAlpha then
     image:=TBitmapImage.Create(img.Width,img.Height,ipfARGB)
    else
     image:=TBitmapImage.Create(img.Width,img.Height,ipfXRGB);

   // Copy/convert bitmap data
   w:=min2(image.width,img.Width);
   h:=min2(image.height,img.Height);
   for i:=0 to h-1 do begin
    sp:=img.GetScanline(i);
    inc(sp);
    dp:=image.data;
    inc(dp,image.pitch*i);
    for j:=0 to w-1 do begin
     // BGR16 to RGB8 conversion
     c:=sp^;
     inc(sp,2);
     c:=c shl 8+sp^;
     inc(sp,2);
     c:=c shl 8+sp^;
     if hasAlpha then begin
      inc(sp,2);
      PCardinal(dp)^:=(sp^ shl 24) or c;
      inc(sp,2);
     end else begin
      inc(sp,4);
      PCardinal(dp)^:=$FF000000 or c;
     end;
     inc(dp,4);
    end;
   end;
   img.Free;
   reader.Free;
  end;

 function SaveImageUsingWriter(writer:TFPCustomImageWriter;image:TRawImage):ByteArray;
  var
   x,y:integer;
   img:TMyFPImage;
   stream:TMemoryStream;
   sp:PByte;
   c:cardinal;
   d:UInt64;
   dp:^UInt64;
  begin
   img:=TMyFPImage.Create(image.width,image.height);
   image.Lock;
   for y:=0 to image.height-1 do begin
    sp:=image.data;
    inc(sp,image.pitch*y);
    dp:=img.GetScanline(y);
    for x:=0 to image.width-1 do begin
     c:=PCardinal(sp)^; inc(sp,4);
     d:=((c shr 8) and $FF00) or
        ((c shl 16) and $FF000000) or
        ((UInt64(c) shl 40) and $FF0000000000) or
        ((UInt64(c) shl 32) and $FF00000000000000);
     dp^:=d;
     inc(dp);
    end;
   end;
   image.Unlock;
   stream:=TMemoryStream.Create;
   img.SaveToStream(stream,writer);
   img.Free;
   SetLength(result,stream.size);
   move(stream.memory^,result[0],stream.size);
   writer.Free;
   stream.Free;
  end;

 {$ENDIF}

 procedure SaveJPEG(image:TRAWimage;filename:string;quality:integer);
 {$IFNDEF FPC}
  var
   jpg:TJpegImage;
   bmp:TBitMap;
   i,y:integer;
   pb:PByte;
  begin
   if not (image.PixelFormat in [ipfRGB,ipfARGB,ipfXRGB,ipf565,ipf555,ipf1555]) then
    raise EWarning.Create('Can''t save JPEG: wrong pixel format!');
   bmp:=TBitmap.Create;
   bmp.Width:=image.width;
   bmp.Height:=image.height;
   bmp.PixelFormat:=pf32bit;
   pb:=image.data;
   for y:=0 to image.height-1 do begin
    ConvertLine(pb^,bmp.scanline[y]^,image.PixelFormat,ipfXRGB,i,palNone,image.width);
    inc(pb,image.pitch);
   end;
   jpg:=TJpegImage.Create;
   jpg.Assign(bmp);
   jpg.CompressionQuality:=quality;
   jpg.Compress;
   jpg.SaveToFile(filename);
   jpg.Free;
   bmp.Free;
  end;
 {$ELSE}
 var
  data:ByteArray;
  writer:TFPWriterJPEG;
 begin
  writer:=TFPWriterJPEG.Create;
  writer.CompressionQuality:=Clamp(quality,1,100);
  data:=SaveImageUsingWriter(writer,image);
  SaveFile(filename,data);
 end;
 {$ENDIF}

 procedure LoadJPEG(data:ByteArray;var image:TRawImage);
 {$IFNDEF FPC}
 var
  jpeg:TJpegImage;
  st:string;
  src:TMemoryStream;
  bmp:TBitmap;
  i,w,h:integer;
  dp:PByte;
 begin
   src:=TMemoryStream.Create;
   src.Write(data[0],length(data));
   src.Seek(0,soFromBeginning);
   jpeg:=TJpegImage.Create;
   jpeg.LoadFromStream(src);
   src.Free;

   if image=nil then
    image:=Apus.Images.TBitmapImage.Create(jpeg.Width,jpeg.Height,ipfRGB);

   jpeg.DIBNeeded;
   bmp:=TBitmap.Create;
   bmp.Assign(jpeg);
   w:=min2(image.width,bmp.Width);
   h:=min2(image.height,bmp.Height);
   dp:=image.data;
   for i:=0 to h-1 do begin
    ConvertLine(bmp.scanline[i]^,dp^,ipfRGB,image.PixelFormat,dp^,palNone,w);
    inc(dp,image.pitch);
   end;
   bmp.Free;
   jpeg.Free;
 end;
 {$ELSE}
 begin
  LoadImageUsingReader(TFPReaderJPEG.Create,data,false,image);
 end;
 {$ENDIF}

 {$IFDEF LODEPNG}
 const
  // LodePNG color types
  LCT_GREY = 0; //*greyscale: 1,2,4,8,16 bit*/
  LCT_RGB = 2; //*RGB: 8,16 bit*/
  LCT_PALETTE = 3; //*palette: 1,2,4,8 bit*/
  LCT_GREY_ALPHA = 4; //*greyscale with alpha: 8,16 bit*/
  LCT_RGBA = 6; //*RGB with alpha: 8,16 bit*/

 {$IFDEF CPU386}
 const
  // LodePNG library name
  LodePngLib = 'LodePNG.dll';

  function lodepng_decode32(out image:pointer;out width,height:cardinal;source:pointer;
    sourSize:integer):cardinal; cdecl; external LodePngLib;
  function lodepng_decode_memory(out image:pointer;out width,height:cardinal;source:pointer;
    sourSize:integer;colortype,bitdepth:cardinal):cardinal; cdecl; external LodePngLib;

  function lodepng_encode32(out image:pointer;out outsize:cardinal;source:pointer;
    width,height:cardinal):cardinal; cdecl; external LodePngLib;
  function lodepng_encode_memory(out image:pointer;out outsize:cardinal;source:pointer;
    width,height,colortype,bitdepth:cardinal):cardinal; cdecl; external LodePngLib;

  procedure free_mem(buf:pointer); external LodePngLib;
 {$ENDIF}
 {$IFDEF CPUX64}
  const
   // LodePNG library name
   LodePngLib = 'LodePNG64.dll';

  function lodepng_decode32(out image:pointer;out width,height:cardinal;source:pointer;
    sourSize:integer):cardinal; cdecl; external LodePngLib;
  function lodepng_decode_memory(out image:pointer;out width,height:cardinal;source:pointer;
    sourSize:integer;colortype,bitdepth:cardinal):cardinal; cdecl; external LodePngLib;

  function lodepng_encode32(out image:pointer;out outsize:int64;source:pointer;
    width,height:cardinal):cardinal; cdecl; external LodePngLib;
  function lodepng_encode_memory(out image:pointer;out outsize:int64;source:pointer;
    width,height,colortype,bitdepth:cardinal):cardinal; cdecl; external LodePngLib;

  procedure free_mem(buf:pointer); external LodePngLib;
 {$ENDIF}

 procedure LoadPNG32(data:ByteArray;var image:TRawImage);
  var
   buf:pointer;
   width,height:cardinal;
   err:cardinal;
   i,j:integer;
   sour:PByte;
   pc,oldC:PCardinal;
  begin
   err:=lodepng_decode32(buf,width,height,@data[0],length(data));
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));

   // Allocate dest image if needed
   if image=nil then
     image:=Apus.Images.TBitmapImage.Create(width,height,ipfARGB);

   image.Lock;
   sour:=buf;
   // Defringe
   pc:=buf;
   for i:=0 to height-1 do begin
    oldC:=pc; inc(pc);
    for j:=1 to width-1 do begin
     if (oldC^=0) and (pc^ and $FF000000>0) then
      oldC^:=pc^ and $FFFFFF;
     if (oldC^ and $FF000000>0) and (pc^=0) then
      pc^:=oldC^ and $FFFFFF;
     inc(pc);
     inc(oldC);
    end;
   end;
   // vertical pass
   for i:=0 to width-1 do begin
    pc:=buf; inc(pc,i);
    oldC:=pc; inc(pc,width);
    for j:=1 to height-1 do begin
     if (oldC^=0) and (pc^ and $FF000000>0) then
      oldC^:=pc^ and $FFFFFF;
     if (oldC^ and $FF000000>0) and (pc^=0) then
      pc^:=oldC^ and $FFFFFF;
     inc(pc,width);
     inc(oldC,width);
    end;
   end;
   // Transfer to the target
   for i:=0 to height-1 do begin
    ConvertLine(sour^,image.scanline(i)^,ipfABGR,image.PixelFormat,sour,palNone,width);
    inc(sour,width*4);
   end;
   image.Unlock;
   free_mem(buf);
  end;

 procedure LoadPNG8(data:ByteArray;var image:TRawImage);
  var
   buf:pointer;
   width,height:cardinal;
   err:cardinal;
   i:integer;
   sour,dest:PByte;
  begin
   err:=lodepng_decode_memory(buf,width,height,@data[0],length(data),LCT_GREY,8);
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));

   // Allocate dest image if needed
   if image=nil then
     image:=Apus.Images.TBitmapImage.Create(width,height,ipfMono8);

   image.Lock;
   sour:=buf;
   dest:=image.data;
   for i:=0 to height-1 do begin
    move(sour^,dest^,width);
    inc(sour,width);
    inc(dest,image.pitch);
   end;
   image.Unlock;

   free_mem(buf);
  end;

 function SavePNG32(image:TRawImage):ByteArray;
  var
   data:array of cardinal;
   err:cardinal;
   png:pointer;
   size:{$IFDEF CPUX64}int64{$ELSE}cardinal{$ENDIF};
   y:integer;
  begin
   SetLength(data,image.width*image.height);
   // Convert to ABGR
   image.Lock;
   for y:=0 to image.height-1 do
    ConvertLine(image.scanline(y)^,data[y*image.width],image.PixelFormat,ipfABGR,err,palNone,image.width);
   image.Unlock;
   // Pack and save
   png:=nil;
   err:=lodepng_encode32(png,size,data,image.width,image.height);
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));
   SetLength(result,size);
   move(png^,result[0],size);
   free_mem(png);
  end;

 function SavePNG8(image:TRawImage):ByteArray;
  var
   err:cardinal;
   png:pointer;
   size:{$IFDEF CPUX64}int64{$ELSE}cardinal{$ENDIF};
   y:integer;
  begin
   // Pack and save
   png:=nil;
   image.Lock;
   err:=lodepng_encode_memory(png,size,image.data,image.width,image.height,LCT_GREY,8);
   image.Unlock;
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));
   SetLength(result,size);
   move(png^,result[0],size);
   free_mem(png);
  end;
 {$ELSE}

 procedure LoadPNG32(data:ByteArray;var image:TRawImage);
  begin
   NotImplemented('Use LODEPNG');
  end;

 procedure LoadPNG8(data:ByteArray;var image:TRawImage);
  begin
   NotImplemented('Use LODEPNG');
  end;

 function SavePNG32(image:TRawImage):ByteArray;
  begin
   NotImplemented('Use LODEPNG');
  end;

 function SavePNG8(image:TRawImage):ByteArray;
  begin
   NotImplemented('Use LODEPNG');
  end;

 {$ENDIF}

 procedure LoadPNG(data:ByteArray;var image:TRawImage);
  begin
   CheckImageFormat(data);
   {$IFDEF LODEPNG}
   // 2 modes supported: 8bpp for 1-channel images, 32bpp - for anything else
   if imgInfo.format in [ipfA8,ipfMono8] then
    LoadPNG8(data,image)
   else
    LoadPNG32(data,image);
   {$ELSE}
    {$IFDEF FPC}
    LoadImageUsingReader(TFPReaderPng.Create,data,true,image); // always ARGB
    {$ELSE}
    NotImplemented('No method to load PNG file format');
    {$ENDIF}
   {$ENDIF}
  end;

 function SavePNG(image:TRawImage):ByteArray;
 {$IFDEF LODEPNG}
  begin
   case image.PixelFormat of
    ipfA8,ipfMono8:result:=SavePNG8(image);
    ipfARGB,ipfXRGB,ipfRGB,ipf32bpp:result:=SavePNG32(image);
    else
     raise EError.Create('PNG: image pixel format not supported');
   end;
 {$ELSE}
 {$IFDEF FPC}
  var
   writer:TFPWriterPng;
  begin
    writer:=TFPWriterPng.Create;
    writer.WordSized:=false;
    if image.PixelFormat in [ipfA8,ipfMono8] then writer.grayscale:=true;
    result:=SaveImageUsingWriter(writer,image);
 {$ELSE}
  begin
     NotImplemented('No method to write PNG file format');
 {$ENDIF}
 {$ENDIF}
 end;

  type
   TIcoHeader=packed record
    res:word;
    imgType:word;
    imgCount:word;
   end;
  TIcoEntryHeader=packed record
   width,height:byte;
   colors,res:byte;
   hotX,hotY:smallint;
   dataSize:cardinal;
   dataPos:cardinal;
  end;
  TBitmapHeader=packed record // BITMAPINFOHEADER (40 bytes)
   size,width,height:integer;
   planes,bpp:word;
   compression,rawSize,hRes,vRes,colors,impColors:integer;
  end;

 procedure LoadCUR(data:ByteArray;var image:TRawImage;out hotX,hotY:integer);
  var
   icoHeader:^TIcoHeader;
   entry:^TIcoEntryHeader;
   bmp:^TBitmapHeader;
   p,y,lineSize:integer;
   srcFormat:TImagePixelFormat;
  begin
   ASSERT(length(data)>sizeof(icoHeader)+sizeof(entry));
   icoHeader:=@data[0];
   if (icoHeader.res<>0) or (icoHeader.imgType<>2) then raise EWarning.Create('Invalid file format');
   entry:=@data[sizeof(TIcoHeader)];
   p:=entry.dataPos; // position of bitmap
   ASSERT(entry.dataSize>=sizeof(TBitmapHeader));
   ASSERT(p+entry.dataSize<=length(data));
   bmp:=@data[p];
   inc(p,bmp.size);
   ASSERT(bmp.size=sizeof(TBitmapHeader));
   case bmp.bpp of
    32:srcFormat:=ipfARGB;
    24:srcFormat:=ipfRGB;
    else raise EWarning.Create('Bit depth not supported (%d)',[bmp.bpp]);
   end;
   hotX:=entry.hotX;
   hotY:=entry.hotY;
   if image<>nil then image.Free;
   image:=Apus.Images.TBitmapImage.Create(entry.width,entry.height,ipfARGB);

   lineSize:=bmp.width*bmp.bpp div 8;
   linesize:=(linesize+3) and (not 3); // align to 4

   for y:=image.height-1 downto 0 do begin
    ConvertLine(data[p],image.ScanLine(y)^,srcFormat,image.pixelFormat,image.width);
    inc(p,lineSize);
   end;

  end;

end.
