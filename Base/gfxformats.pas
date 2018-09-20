// Support for common graphic formats
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit gfxformats;
interface
 uses MyServis,{$IFDEF DELPHI}graphics,{$ENDIF}
     images;
 type
  TImageFormat=(ifUnknown,ifTGA,ifJPEG,ifPJPEG,ifBMP,ifPCX,ifTXT,ifDDS,ifPVR,ifPNG);
  TImageInfo=record
   width,height:integer;
   format:ImagePixelFormat;
   palformat:ImagePaletteFormat;
   miplevels:integer;
  end;

 var
  txtSmallFont,txtNormalFont:integer;
 threadvar
  ImgInfo:TImageInfo; // info about last checked image

 function CheckFileFormat(fname:string):TImageFormat;
 function CheckImageFormat(data:ByteArray):TImageFormat;

 // Load TGA image from data stream into, if image was created before, image conversion will be applied
 procedure LoadTGA(data:ByteArray;var image:TRawImage;allocate:boolean=false);
 // Write image in TGA format into buffer, return size of TGA data
 function SaveTGA(image:TRawImage):ByteArray;

 procedure LoadTXT(data:ByteArray;var image:TRawImage);
 procedure LoadDDS(data:ByteArray;var image:TRawImage;allocate:boolean=false);

 // Always allocates new image object
 procedure LoadPVR(data:ByteArray;var image:TRawImage;allocate:boolean=false);

 // JPEG format (different methodf for Delphi and FPC)
 procedure LoadJPEG(data:ByteArray;var image:TRawImage);
 procedure SaveJPEG(image:TRAWimage;filename:string;quality:integer);

 // PNG import using LodePNG (under Windows)
 procedure LoadPNG(data:ByteArray;var image:TRawImage);
 function SavePNG(image:TRawImage):ByteArray;

 {$IFNDEF FPC}
 {$IFNDEF DELPHI}
 For Delphi - define global symbol "DELPHI"!
 {$ENDIF}
 {$ENDIF}
 

implementation
 uses {$IFDEF DELPHI}jpeg,{$ENDIF}
     {$IFDEF FPC}fpimage,fpreadjpeg,fpreadpng,{$ENDIF}
     {$IFDEF CPU386}DirectText,{$ENDIF}
     classes,SysUtils,math,colors;

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
   image:=TBitmapImage.Create(imginfo.width,imginfo.height,imginfo.format,palNone,0);
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
  format:ImagePixelFormat;
  info:TImageInfo;
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
   image:=TBitmapImage.Create(width,height,format,palNone,0);
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
  format:ImagePixelFormat;
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
   image:=TBitmapImage.Create(head.imgwidth,head.imgheight,format,palformat,
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
    ipf8Bit,ipfA8:bpp:=1;
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

 procedure LoadTXT(data:ByteArray;var image:TRawImage);
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
      if line=1 then img:=TBitmapImage.Create(w,h);
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
    if (txtSmallFont=0) or (txtNormalFont=0) then
     raise EWarning.Create('TXT: undefined fonts');
    directtext.color:=text;
    SetBuffer(img.data,img.width,img.height,img.pitch,4);
    SetClipping(0,0,img.width-1,img.height-1);
    for i:=1 to lcnt do begin
     if pos('!',lines[i])=1 then begin
      delete(lines[i],1,1);
      curfont:=txtSmallFont;
     end else curfont:=txtNormalFont;
     WrtBest(lx[i]-GetStrLen2(lines[i]) div 2,ly[i],lines[i]);
    end;
    RestoreClipping;
   end;
   {$ENDIF}

   image:=img;
  end;

 function CheckFileFormat(fname:string):TImageFormat;
  var
   f:file;
   buf:array[1..50] of byte;
  begin
   result:=ifUnknown;
   assign(f,fname);
   reset(f,1);
   if filesize(f)>=30 then begin
    blockread(f,buf,30);
    result:=CheckImageFormat(@buf);
   end;
   close(f);
  end;

 function CheckImageFormat(data:ByteArray):TImageFormat;
  var
   pb:PByte;
   pc:^cardinal;
   dds:^DDSheader;
   tga:^TGAheader;
   pvr:^PVRheader;
   {$IFDEF DELPHI}
   jpeg:TJPEGimage;
   {$ENDIF}
   i,j:integer;
   fl:boolean;
  begin
   result:=ifUnknown;
   imginfo.miplevels:=1;
   // Check for PNG
   if (data[0]=$89) and (data[1]=$50) and (data[2]=$4E) and (data[3]=$47) then begin
    result:=ifPNG;
    imginfo.palformat:=palNone;
    imginfo.miplevels:=0;
    imginfo.format:=ipfARGB; // any PNG loads as ARGB
    for i:=4 to length(data)-20 do
     if data[i]=$49 then begin
      if (data[i+1]=$48) and (data[i+2]=$44) and (data[i+3]=$52) then begin
       imginfo.width:=data[i+7]+data[i+6]*256;
       imginfo.height:=data[i+11]+data[i+10]*256;
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
   for i:=1 to 5 do begin
    if not (pb^ in [$30..$39,32,10,13,8]) then fl:=false;
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
     // BGR to RGB conversion
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
 begin
  EError.Create('JPEG format not supported!');
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
    image:=TBitmapImage.Create(jpeg.Width,jpeg.Height,ipfRGB);

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

{ var
  reader:TFPReaderJPEG;
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

  // Load JPEG image
  reader:=TFPReaderJPEG.Create;
  img:=TMyFPImage.create(0,0);
  img.LoadFromStream(src,reader);
  src.Free;

  // Allocate dest image if needed
  if image=nil then
   image:=TBitmapImage.Create(img.Width,img.Height,ipfRGB);

  // Copy/convert bitmap data
  w:=min2(image.width,img.Width);
  h:=min2(image.height,img.Height);
  for i:=0 to h-1 do begin
   sp:=img.GetScanline(i);
   inc(sp);
   dp:=image.data;
   inc(dp,image.pitch*i);
   for j:=0 to w-1 do begin
    // BGR to RGB conversion
    c:=$FF00+sp^;
    inc(sp,2);
    c:=c shl 8+sp^;
    inc(sp,2);
    c:=c shl 8+sp^;
    inc(sp,4);
    PCardinal(dp)^:=c;
    inc(dp,4);
   end;
  end;
  img.Free;
 end;}
 {$ENDIF}

 {$IFDEF DELPHI}
 {$LINK lodepng.obj}
 function _lodepng_decode32(out image:pointer;out width,height:cardinal;source:pointer;sourSize:integer):cardinal; cdecl; external;

 procedure LoadPNG(data:ByteArray;var image:TRawImage);
  var
   buf:pointer;
   width,height:cardinal;
   err:cardinal;
   i,j:integer;
   sour,dest:PByte;
   c:cardinal;
  begin
   err:=_lodepng_decode32(buf,width,height,@data[0],length(data));
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));

   // Allocate dest image if needed
   if image=nil then
     image:=TBitmapImage.Create(width,height,ipfARGB);

   image.Lock;
   sour:=buf;
   for i:=0 to height-1 do begin
    ConvertLine(sour^,image.scanline(i)^,ipfABGR,image.PixelFormat,i,palNone,width);
    inc(sour,width*4);
   end;
   image.Unlock;

   freemem(buf);
  end;
 // C RTL stub
 function _fopen(fname:PChar;mode:PChar):integer; cdecl;
  begin
   result:=FileOpen(fName,fmOpenRead);
  end;
 procedure _fclose(f:integer); cdecl;
  begin
   FileClose(f);
  end;
 procedure _fseek(f:integer;pos,origin:integer); cdecl;
  begin
   FileSeek(f,pos,0);
  end;
 function _ftell(f:integer):integer; cdecl;
  begin
   result:=FileSeek(f,0,1);
  end;
 function _fread(data:pointer;size,count,f:integer):integer; cdecl;
  begin
   result:=FileWrite(f,data^,size*count) div size;
  end;
 function _fwrite(data:pointer;size,count,f:integer):integer; cdecl;
  begin
   result:=FileWrite(f,data^,size*count) div size;
  end;  
 function _malloc(size:integer):pointer; cdecl;
  begin
   GetMem(result,size);
  end;
 procedure _free(p:pointer); cdecl;
  begin
   FreeMem(p);
  end;
 function _realloc(p:pointer;size:integer):pointer; cdecl;
  begin
   ReallocMem(p,size);
   result:=p;
  end;
 function _memcpy(dest,sour:pointer;size:integer):pointer; cdecl;
  begin
   move(sour^,dest^,size);
   result:=dest;
  end;
 function _strlen(s:PChar):integer; cdecl;
  begin
   result:=StrLen(s);
  end;
 function _strcmp(s1,s2:PChar):integer; cdecl;
  begin
   result:=StrComp(s1,s2);
  end;
 function _memset(p:pointer;val,size:integer):pointer; cdecl;
  begin
   FillChar(p^,size,val);
   result:=p;
  end;
 function _abs(n:integer):integer; cdecl;
  begin
   result:=abs(n);
  end; 
 {$ELSE}
 procedure LoadPNG(data:ByteArray;var image:TRawImage);
  begin
   LoadImageUsingReader(TFPReaderPNG.Create,data,true,image);
  end;
 {$ENDIF}

 {$IFDEF DELPHI}
 function _lodepng_encode32(out image:pointer;out outsize:cardinal;source:pointer;width,height:cardinal):cardinal; cdecl; external;

 function SavePNG(image:TRawImage):ByteArray;
  var
   data:array of cardinal;
   err:cardinal;
   png:pointer;
   size:cardinal;
   y:integer;
  begin
   SetLength(data,image.width*image.height);
   // Convert to ABGR
   image.Lock;
   for y:=0 to image.height-1 do
    ConvertLine(image.scanline(y)^,data[y*image.width],image.PixelFormat,ipfABGR,y,palNone,image.width);
   image.Unlock;
   // Pack and save
   err:=_lodepng_encode32(png,size,data,image.width,image.height);
   if err<>0 then raise EWarning.Create('LodePNG error code '+inttostr(err));
   SetLength(result,size);
   move(png^,result[0],size);
   FreeMem(png);
  end;
 {$ELSE}
 function SavePNG(image:TRawImage):ByteArray;
  begin
   raise Exception.Create('Sorry, not yet implemented!');
  end;
 {$ENDIF}

end.
