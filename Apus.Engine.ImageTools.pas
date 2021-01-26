// Image loading functions implementation (extracted from EngineTools)
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.ImageTools;
interface
 uses Apus.Images, Apus.Engine.API;

 var
  defaultImagesDir:string='Images\'; // default folder to load images from

 // Загрузить картинку из файла в текстуру (в оптимальный формат, если не указан явно)
 // Если sysmem=true, то загружается в поверхность в системной памяти
 // function LoadImageFromFile(fname:string;mtwidth:integer=0;mtheight:integer=0;sysmem:boolean=false;
 //           ForceFormat:TImagePixelFormat=ipfNone):TTexture;
 function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:TImagePixelFormat=ipfNone):TTexture;

 // (Re)load texture from an image file. defaultImagesDir is used if path is relative
 // Default flags can be used from defaultLoadImageFlags
 procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);

 // Сохраняет изображение в файл (mostly for debug purposes)
 procedure SaveImage(img:TTexture;fName:string);

 // Создать новую текстуру из куска данной (copy pixel data). Новая текстура размещается в доступной для
 // рендеринга памяти, тогда как источник может быть где угодно
 function CreateSubImage(source:TTexture;x,y,width,height:integer;flags:integer=0):TTexture;

 // Частный случай - копия изображения целиком (данные копируются)
 function CreateImageCopy(source:TTexture):TTexture;

 // Обёртка для CopyRect
 procedure CopyImageRect(source,dest:TTexture;sx,sy,width,height,targetX,targetY:integer);

 // загрузить текстуру с мип-мапами из файла (сперва ищется DDS, затем другие)
 // размер текстуры должен быть степенями 2
 // если мип-мапы в файле отсутствуют - будут созданы
 // если формат загружаемой картинки не соответствует финальному - будет сохранен DDS в нужном формате
 function LoadTexture(fname:string;downscale:single;format:TImagePixelFormat=ipfNone;saveDDS:boolean=true):TTexture;

 // Загрузить текстурный атлас
 // Далее при загрузке изображений, которые уже есть в атласе, вместо загрузки из файла будут
 // создаваться текстурные объекты, ссылающиеся на атлас
 // Not thread-safe! Don't load atlases in one thread and create images in other thread
 procedure LoadAtlas(fname:string;scale:single=1.0);

 // Set image as render target for FastGFX drawing operations (lock if not locked) Don't forget to unlock!
 procedure EditImage(tex:TTexture);

 // Change image size while keeping its texture space (resolution change)
// procedure ScaleImage(image:TTexture;scaleX,scaleY:single);

 // Обрезать изображение в указанных пределах (текстура не меняется,
 // меняется лишь область отрисовки
 procedure CropImage(image:TTexture;x1,y1,x2,y2:integer);

 // Уменьшает xRGB изображение за счет вырезания из него:
 //   вертикальных полос x1..x2-1, x3..x4-1
 //   горизонтальных полос y1..y2-1, y3..y4-1
 // При этом производится наложение (методом dissolve) частей на глубину overlap точек
 // Полосы могут быть нулевой ширины (x1=x2), однако все координаты должны быть упорядочены (0 < x1 <= x2 < x3 <= x4 < width)
 function ShrinkImage(image:TTexture;x1,x2,x3,x4,y1,y2,y3,y4:integer;overlap:integer):TTexture;

 // Expands image this way: where y1..y2 = 456 band, and x1..x2 is 258 band (can also be used for shrinking)
 //  123      1223
 //  456  =>  4556
 //  789      4556
 //           7889
 function ExpandImage(image:TTexture;x1,x2,y1,y2:integer;overlap:integer):TTexture;

 // Создает растянутую/сжатую копию изображения (все в ARGB)
 function ResampleImage(image:TTexture;newWidth,newHeight:integer;sysMem:boolean=false):TTexture;

 // strength: 0..256 (ARGB and xRGB only!)
 procedure SharpenImage(image:TTexture;strength:integer);

 // brightness: -1..1 (0 - no change), contrast: 0..1.., saturation 0..1.. (1 - no change)
 procedure AdjustImage(image:TTexture;brightness,contrast,saturation:single);

 procedure ImageHueSaturation(image:TTexture;hue,saturation:single);

 function MTFlags(mtWidth,mtHeight:integer):cardinal; // build liffMxxx flags for given width/height values


implementation
uses Apus.MyServis, SysUtils, Apus.Structs, Types, Apus.GfxFormats,
   Apus.Engine.ImgLoadQueue, Apus.FastGFX, Apus.Geom3D, Apus.Colors, Apus.GfxFilters;

const
  max_subimages = 5000;

var
  atlases:array[1..50] of TTexture;
  aCount:integer;
  // Atlas subimages
  aImages:array[1..max_subimages] of TTexture;
  aFiles:array[1..max_subimages] of string; // uppercase, no extention
  aHash:array[1..max_subimages] of cardinal;
  aSubCount:integer;

  // "имя файла" -> cardinal(TJpegImage) - для предзагрузки jpeg'ов
  jpegImageHash:THash;

var
 {$IFDEF TXTIMAGES}
 txtFontNormal,txtFontSmall:TUnicodeFont;
 {$ENDIF}

 loadingTime:integer; // суммарное время загрузки изображений в мс
 loadingJPEGTime:integer; // суммарное время загрузки JPEG в мс

var
 defaultLoadImageFlags:cardinal=0;

{procedure AddJPEGImage(filename:string;obj:TObject);
begin
 EnterCriticalSection(cSect);
 try
  jpegImageHash.Put(filename,cardinal(obj),true);
  LogMessage('JPEG image added for '+filename);
 finally
  LeaveCriticalSection(cSect);
 end;
end;

function GetJPEGImage(filename:string):TObject;
var
 c:cardinal;
begin
 result:=nil;
 EnterCriticalSection(cSect);
 try
  c:=jpegImageHash.Get(filename);
  if c>0 then begin
   result:=TObject(c);
   LogMessage('Preloaded JPEG image found in hash');
  end;
 finally
  LeaveCriticalSection(cSect);
 end;
end;}


// подогнать формат пикселя под поддерживаемый системой
procedure AdjustFormat(var ForceFormat:TImagePixelFormat);
var
 i:integer;
begin
 i:=0;
 {$IFDEF DIRECTX}
 if painter.texman.InheritsFrom(TDxTextureMan) then begin
  // 1-я итерация - проверка альтернативных форматов
  case ForceFormat of
   ipfRGB:if supportRGB then exit else ForceFormat:=ipfXRGB;
   ipfXRGB:if supportXRGB then exit else ForceFormat:=ipfRGB;
   ipf565:if support565 then exit else ForceFormat:=ipf555;
   ipf555:if support555 then exit else ForceFormat:=ipf565;
  end;
  repeat
   // Проверка поддерживается ли формат (последовательная замена пока не найдется подходящий поддерживаемый)
   case ForceFormat of
    ipfDXT5:if supportDXT5 then break else ForceFormat:=ipfARGB;
    ipfDXT3:if supportDXT3 then break else ForceFormat:=ipfARGB;
    ipfDXT2:if supportDXT2 then break else ForceFormat:=ipfARGB;
    ipfARGB:if supportARGB then break else ForceFormat:=ipf4444;
    ipfXRGB:if supportXRGB then break else ForceFormat:=ipfRGB;
    ipfDXT1:if supportDXT1 then break else ForceFormat:=ipf565;
    ipf4444:if support4444 then break else ForceFormat:=ipfARGB;
    ipf565:if support565 then break else ForceFormat:=ipf555;
    ipf1555:if support1555 then break else ForceFormat:=ipf4444;
    ipf8Bit:if support8bit then break else ForceFormat:=ipfARGB;
    ipfRGB:if supportRGB then break else ForceFormat:=ipf565;
    ipf555:if support555 then break else ForceFormat:=ipfXRGB;
   end;
   inc(i);
   if i>=4 then raise EError.Create('Failed to choose valid pixel format!');
  until false;
 end;
 {$ENDIF}
 {$IFDEF OPENGL}
  case ForceFormat of
   ipfXRGB,ipfRGB:forceFormat:=ipfARGB;
   ipfARGB,ipf4444,ipf4444r,ipf565,ipf1555,ipf555,ipfDXT1,ipfDXT3,ipfDXT5,ipfPVRTC:exit;
   ipf8bit:forceFormat:=ipfARGB;
   ipfA8,ipfMono8:; // keep as-is
   else
    raise EError.Create('Failed to choose valid pixel format for '+PixFmt2Str(ForceFormat));
  end;
 {$ENDIF}
end;


procedure NormalizeFName(var fname:string);
var
 ext:string[20];
begin
 fname:=UpperCase(fname);
 ext:=ExtractFileExt(fname);
 if ext<>'' then fname:=StringReplace(fname,ext,'',[]);
 {$IFDEF IOS}
 fname:=StringReplace(fname,'\','/',[rfReplaceAll]);
 {$ENDIF}
end;

procedure LoadAtlas(fname:string;scale:single=1.0);
var
  f:text;
  x,y,w,h,aw,ah:integer;
  img,atlas:TTexture;
  st,path:string;
begin
 try
  path:=ExtractFilePath(fname);
  assign(f,FileName(fname+'.atl'));
  reset(f);
  readln(f,aw,ah,st);
  st:=chop(st);
  inc(aCount);
  atlas:=LoadImageFromFile(fname);
  atlases[aCount]:=atlas;
  while not eof(f) do begin
   readln(f,x,y,w,h,st);
   st:=chop(st);
   if (st='') or (w=0) or (h=0) then continue;
   inc(aSubCount);
   img:=atlas.ClonePart(Rect(x,y,x+w,y+h));
   aImages[aSubCount]:=img;
   st:=path+st;
   NormalizeFName(st);
   aFiles[aSubCount]:=st;
   aHash[aSubCount]:=strHash(st);
   if length(st)>15 then st:=copy(st,length(st)-14,15);
   img.name:=st;
//   if scale<>1.0 then ScaleImage(img,scale,scale);
  end;
  close(f);
 except
  on e:Exception do raise EError.Create('Failed to load atlas '+fname+': '+ExceptionMsg(e));
 end;
end;

function LoadTexture(fname:string;downscale:single;format:TImagePixelFormat=ipfNone;saveDDS:boolean=true):TTexture;
var
 i,j:integer;
 tex:TTexture;
 f:file;
 buf:ByteArray;
 size:integer;
 conversion:boolean;
 srcformat:TImageFileType;
 width,height:integer;
 levels:array[0..12] of TRawImage; // уровни в формате приемника
 sp,dp:PByte;
 ftype:integer;
begin
 fname:=UpperCase(fname);
 ftype:=0;
 if pos('.DDS',fname)>0 then ftype:=1;
 if pos('.',fname)=0 then begin
  if fileexists(fname+'.dds') then begin
   fname:=fname+'.dds'; ftype:=1;
  end;
 end;
 if ftype=0 then raise EError.Create('Unsupported texture type: '+fname);
 // этап 1 - загрузка исходного файла и его параметров в буфер
 if ftype=1 then begin
  // загружаем DDS
  buf:=LoadFileAsBytes(fname);
  CheckImageFormat(buf);
  srcformat:=ifDDS;
  if format=ipfNone then format:=imgInfo.format;
  AdjustFormat(format);
  conversion:=(format<>imginfo.format) or (imgInfo.miplevels<3);
  if not conversion then begin
   width:=imgInfo.width;
   height:=imgInfo.height;
   if format in [ipfDXT1..ipfDXT3] then begin
    width:=width div 4;
    height:=height div 4;
   end;
   sp:=@buf[0]; inc(sp,128);
   for i:=0 to imginfo.miplevels-1 do begin
    if width=0 then width:=1;
    if height=0 then height:=1;
    levels[i]:=Apus.Images.TRawImage.Create;
    levels[i].width:=width;
    levels[i].height:=height;
    levels[i].data:=sp;
    levels[i].pitch:=width*pixelSize[format] div 8;
    inc(sp,levels[i].pitch*height);
    width:=width div 2; height:=height div 2;
   end;
  end; // conversion
 end else
 /// TODO: load other file types
 ;
 // этап 2 - создание текстуры
 tex:=painter.texman.AllocImage(imginfo.width,imginfo.height,format,
   aiTexture+aiMipmapping+aiPow2,fname) as TTexture;

 // этап 3 - Загрузка данных в текстуру
 for i:=0 to tex.mipmaps-1 do begin
  // загрузка i-го уровня
  tex.Lock(i);
  // копируем содержимое levels[i]
  sp:=levels[i].data;
  dp:=tex.data;
  for j:=0 to levels[i].height-1 do begin
   move(sp^,dp^,levels[i].pitch);
   inc(sp,levels[i].pitch);
   inc(dp,tex.pitch);
  end;
  tex.Unlock;
 end;
 result:=tex;
end;

function MTFlags(mtWidth,mtHeight:integer):cardinal;
begin
 if mtWidth<128 then mtWidth:=128;
 if mtHeight<128 then mtHeight:=128;
 result:=(GetPow2(mtWidth)-7) shl 16+(GetPow2(mtHeight)-7) shl 20;
end;

function FindFileInAtlas(fname:string):integer;
var
  i:integer;
  h:cardinal;
  ext:string[20];
begin
  result:=0;
  NormalizeFName(fname);
  h:=strHash(fname);
  for i:=1 to aSubCount do
   if aHash[i]=h then
    if fname=aFiles[i] then begin
     result:=i; exit;
    end;
end;

function FindProperFile(fname:string):string;
 var
  maxAge,age:integer;
  st,st2:string;
 begin
  {$IFDEF ANDROID}
  if MyFileExists(fname+'.tga') then result:=fname+'.tga' else
  if MyFileExists(fname+'.jpg') then result:=fname+'.jpg' else
  if MyFileExists(fname+'.png') then result:=fname+'.png' else
  if MyFileExists(fname+'.txt') then result:=fname+'.txt';
  {$ELSE}
  maxAge:=-1; st2:='';
  st:=fname+'.dds';
  age:=FileAge(st);
  if age>maxAge then begin
   maxAge:=age; st2:=st;
  end;
  st:=fname+'.tga';
  age:=FileAge(st);
  if age>maxAge then begin
   maxAge:=age; st2:=st;
  end;
  st:=fname+'.png';
  age:=FileAge(st);
  if age>maxAge then begin
   maxAge:=age; st2:=st;
  end;
  st:=fname+'.jpg';
  age:=FileAge(st);
  if age>maxAge then begin
   maxAge:=age; st2:=st;
  end;
  st:=fname+'.txt';
  age:=FileAge(st);
  if age>maxAge then begin
   st2:=st;
  end;
  if st2='' then raise EWarning.Create(fname+' not found');
  result:=st2;
  {$ENDIF}
 end;

//function LoadImageFromFile(fname:string;mtwidth:integer=0;mtheight:integer=0;sysmem:boolean=false;ForceFormat:TImagePixelFormat=ipfNone):TTexture;
function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:TImagePixelFormat=ipfNone):TTexture;
var
 i,j,k:integer;
 tex:TTexture;
 img,txtImage,preloaded:TRawImage;
 aFlags,mtWidth,mtHeight:integer;
 f:file;
 data,rawData:ByteArray;
 size2:integer;
 format:TImageFileType;
 sp,dp:PByte;
 time,timeJ:int64;
 linebuf:pointer;
 doScale:boolean;
 st:string;
begin
 if painter.texman=nil then
  raise EError.Create(fname+' - Loading failed: texture manager doesn''t exist!');

 try
  // 1. ADJUST FILE NAME AND CHECK ATLAS
  fname:=FileName(fname);
  // Search atlases first
  i:=FindFileInAtlas(fname);
  if i>0 then begin
   result:=aImages[i].Clone;
   exit;
  end;
  {$IFNDEF MSWINDOWS} // Use root dir
  //if (defaultImagesDir<>'') and (fname[1]<>'/') then fname:=defaultImagesDir+fname;
  {$ENDIF}
  {$IFDEF IOS}
  if not FileExists(fname) then
   if FileExists(fname+'.tga') then fname:=fname+'.tga'
    else if FileExists(fname+'.pvr') then fname:=fname+'.pvr'
     else raise EError.Create(fname+' not found');
  {$ELSE}
  if ExtractFileExt(fname)='' then begin // find file
   fName:=FindProperFile(fName);
  end;
  {$ENDIF}

  time:=MyTickCount;
  LogMessage('Loading '+fname);
  preloaded:=GetImageFromQueue(fname);
  if preloaded<>nil then begin
   imgInfo.format:=preloaded.PixelFormat;
   imgInfo.width:=preloaded.width;
   imgInfo.height:=preloaded.height;
  end else begin
   // 2. LOAD DATA FILE AND CHECK IT'S FORMAT
   data:=LoadFileAsBytes(fname);
   if length(data)<30 then raise EError.Create('Bad image file: '+fname);

   format:=CheckImageFormat(data);
   if not (format in [ifTGA,ifJPEG,ifPNG,ifTXT,ifDDS,ifPVR]) then
    raise EError.Create('image format not supported');

   // Загрузка TXT
   {$IFDEF TXTIMAGES}
   if format=ifTXT then begin
    LoadTXT(data,txtImage,txtFontSmall,txtFontNormal);
    imgInfo.width:=txtImage.width;
    imgInfo.height:=txtImage.height;
    imgInfo.format:=ipfARGB;
    imgInfo.palformat:=palNone;
   end;
   {$ENDIF}

   // 2.5 FOR JPEG: LOAD SEPARATE ALPHA CHANNEL (IF EXISTS)
   if format=ifJPEG then begin
    timeJ:=MyTickCount;
    st:=StringReplace(fname,ExtractFileExt(fname),'.raw',[]);
    DebugMessage('Checking '+st);
    if MyFileExists(st) then begin
     DebugMessage('Loading RAW alpha ');
     rawData:=LoadFileAsBytes(st);
     if CheckRLEHeader(@rawdata[0],length(rawData))>0 then
       rawData:=UnpackRLE(@rawdata[0],length(rawData));
     forceFormat:=ipfARGB;
    end;
   end;
  end;

  // 3. ADJUST IMAGE FORMAT
  if ForceFormat=ipfNone then ForceFormat:=ImgInfo.format;
  if ForceFormat=ipf32bpp then
   if ImgInfo.format in [ipfXRGB,ipfRGB,ipf555,ipf565] then ForceFormat:=ipfXRGB
    else ForceFormat:=ipfARGB;
  AdjustFormat(ForceFormat);

  // 4. ALLOCATE TEXTURE AND LOCK ITS DATA
  if flags and liffSysMem>0 then aflags:=aiSysMem else aFlags:=0;
  if flags and liffTexture>0 then aflags:=aflags or aiTexture
    else aFlags:=aFlags or aiClampUV;
  if flags and liffPow2>0 then aflags:=aflags or aiTexture or aiPow2;
  if flags and liffMipMaps>0 then aflags:=aflags or aiTexture or aiPow2 or aiMipMapping;
  if imgInfo.miplevels>1 then flags:=flags or aiMipMapping;
  aFlags:=aFlags or (flags and $FF0000);
  tex:=painter.texman.AllocImage(ImgInfo.width,ImgInfo.height,ForceFormat,aFlags,copy(fname,pos('\',fname)+1,16)) as TTexture;
  tex.Lock(0);
  img:=tex.GetRawImage; // получить объект типа RAW Image для доступа к данным текстуры

  if preloaded<>nil then begin
   img.CopyPixelDataFrom(preloaded); // don't free preloaded as it is kept in the queue
   LogMessage('Copied from preloaded: '+fname);
  end else begin
   // 5. LOAD SOURCE IMAGE FORMAT INTO TEXTURE MEMORY
   if format=ifTGA then LoadTGA(data,img) else
   if format=ifJPEG then LoadJPEG(data,img) else
   if format=ifPNG then LoadPNG(data,img) else
   if format=ifPVR then LoadPVR(data,img) else
   if format=ifDDS then LoadDDS(data,img) else
   if format=ifTXT then begin
    // скопировать загруженное изображение из SRC в IMG
    img.CopyPixelDataFrom(txtImage);
    txtImage.Free;
   end;

   // 6. ADD ALPHA CHANNEL FROM A SEPARATE RLE/RAW IMAGE IF EXISTS (JPEG-ONLY)
   if (length(rawData)>0) and (tex.PixelFormat=ipfARGB) then begin
    DebugMessage('Adding separate alpha');
    k:=0;
    for i:=0 to tex.height-1 do begin
     dp:=tex.data; inc(dp,i*tex.pitch+3);
     for j:=0 to tex.width-1 do begin
      dp^:=rawData[k];
      inc(dp,4);
      inc(k);
     end;
    end;
   end;
  end;

  // 7. FINISH TEXTURE
  tex.unlock;
  if flags and liffAllowChange=0 then tex.caps:=tex.caps or tfNoWrite; // Forbid further changes

 except
  on e:Exception do begin
   raise EWarning.Create(fname+' - Loading failed: '+ExceptionMsg(e));
  end;
 end;

 // 8. TIME CALCULATIONS
 time:=MyTickCount-time+random(2);
 if (time>0) and (time<50000) then inc(loadingTime,time);
 if time>30 then LogMessage('Slow image loading: '+inttostr(time)+' - '+fname);
 result:=tex;
end;

function CreateSubImage(source:TTexture;x,y,width,height,flags:integer):TTexture;
var
 tex:TTexture;
 i,PixSize:integer;
 sp,dp:PByte;
begin
 ASSERT((x>=0) and (y>=0) and (x+width<=source.width) and (y+height<=source.height));
 tex:=painter.texman.AllocImage(width,height,source.PixelFormat,flags,'p_'+source.name) as TTexture;
 tex.Lock;
 source.Lock(0,lmReadOnly);
 sp:=source.data;
 dp:=tex.data;
 PixSize:=PixelSize[source.pixelFormat] div 8;
 inc(sp,source.pitch*y+x*PixSize);
 for i:=1 to height do begin
  move(sp^,dp^,width*PixSize);
  inc(sp,source.pitch);
  inc(dp,tex.pitch);
 end;
 source.Unlock;
 tex.unlock;
 result:=tex;
end;

function CreateImageCopy(source:TTexture):TTexture;
begin
 result:=CreateSubImage(source,0,0,source.width,source.height,aiMW1024+aiMH1024);
end;

procedure CopyImageRect(source,dest:TTexture;sx,sy,width,height,targetX,targetY:integer);
begin
 source.Lock(0,lmReadOnly);
 dest.Lock(0);
 try
  CopyRect(source.data,source.pitch,dest.data,dest.pitch,
   sx,sy,width,height,targetX,targetY);
 finally
  dest.Unlock;
  source.Unlock;
 end;
end;

procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);
 begin
   if flags=liffDefault then flags:=defaultLoadImageFlags;
   if img<>nil then painter.texman.FreeImage(TTexture(img));

   if IsPathRelative(fName) then fName:=defaultImagesDir+fName;
   img:=LoadImageFromFile(fName,flags,ipf32bpp);
 end;

procedure SaveImage(img:TTexture;fName:string);
 var
   buf:ByteArray;
 begin
   fname:=FileName(fname);
   img.Lock(0,lmReadOnly);
   try
    buf:=SaveTGA(img.GetRawImage);
    WriteFile(fname,@buf[0],0,length(buf));
   finally
    img.Unlock;
   end;
 end;

procedure EditImage(tex:TTexture);
 begin
  if not tex.IsLocked then tex.lock(0);
  SetRenderTarget(tex.data,tex.pitch,tex.width,tex.height);
 end;

procedure CropImage(image:TTexture;x1,y1,x2,y2:integer);
 begin
  image.left:=image.left+x1;
  image.top:=image.top+y1;
  image.width:=x2-x1+1;
  image.height:=y2-y1+1;
 end;

{procedure ScaleImage(image:TTexture;scaleX,scaleY:single);
 begin
  image.width:=round(image.width/scaleX);
  image.height:=round(image.height/scaleY);
  image.scaleX:=scaleX;
  image.scaleY:=scaleY;
  image.stepU:=image.stepU*scaleX;
  image.stepV:=image.stepV*scaleY;
  image.caps:=image.caps or tfScaled;
 end;}

 function ShrinkImage(image:TTexture;x1,x2,x3,x4,y1,y2,y3,y4:integer;overlap:integer):TTexture;
  var
   w,h,imgW,imgH:integer;
  begin
   w:=image.width-(x2-x1)-(x4-x3);
   h:=image.height-(y2-y1)-(y4-y3);
   result:=painter.texman.AllocImage(w,h,image.PixelFormat,0,image.name+'_shr') as TTexture;
   imgW:=image.width;
   imgH:=image.height;
   image.Lock(0,lmReadOnly);
   result.Lock;
   try
    // Top band
    CopyRect(image.data,image.pitch,result.data,result.pitch, 0,0, x1,     y1,   0,  0);
    CopyRect(image.data,image.pitch,result.data,result.pitch,x2,0, x3-x2,  y1,   x1, 0);
    CopyRect(image.data,image.pitch,result.data,result.pitch,x4,0, imgW-x4,y1,   x1+(x3-x2),0);
    // Middle band
    CopyRect(image.data,image.pitch,result.data,result.pitch, 0,y2, x1,     y3-y2,  0, y1);
    CopyRect(image.data,image.pitch,result.data,result.pitch,x2,y2, x3-x2,  y3-y2,  x1,y1);
    CopyRect(image.data,image.pitch,result.data,result.pitch,x4,y2, imgW-x4,y3-y2,  x1+(x3-x2),y1);
    // Bottom band
    CopyRect(image.data,image.pitch,result.data,result.pitch, 0,y4, x1,     imgH-y4,  0, y1+(y3-y2));
    CopyRect(image.data,image.pitch,result.data,result.pitch,x2,y4, x3-x2,  imgH-y4,  x1,y1+(y3-y2));
    CopyRect(image.data,image.pitch,result.data,result.pitch,x4,y4, imgW-x4,imgH-y4,  x1+(x3-x2),y1+(y3-y2));
   finally
    image.unlock;
    result.unlock;
   end;
  end;

 function ExpandImage(image:TTexture;x1,x2,y1,y2:integer;overlap:integer):TTexture;
  var
   w,h,imgW,img,dw,dh,i,j,sx,sy,dx,dy,bw,bh:integer;
  begin
   dw:=x2-x1;
   dh:=y2-y1;
   w:=image.width+dw;
   h:=image.height+dh;
   result:=painter.texman.AllocImage(w,h,image.PixelFormat,0,image.name+'_expd') as TTexture;
   image.Lock(0,lmReadOnly);
   result.Lock;
   try
    for i:=0 to 3 do
     for j:=0 to 3 do begin
      case j of
       0:begin sx:=0; dx:=0; bw:=x1+1; end;
       1,2:begin sx:=x1+1; dx:=sx+(j-1)*dw; bw:=dw; end;
       3:begin sx:=x2+1; dx:=sx+dw; bw:=image.width-x2; end;
      end;
      case i of
       0:begin sy:=0; dy:=0; bh:=y1+1; end;
       1,2:begin sy:=y1+1; dy:=sy+(i-1)*dh; bh:=dh; end;
       3:begin sy:=y2+1; dy:=sy+dh; bh:=image.height-y2; end;
      end;
      if (bw>0) and (bh>0) then
        CopyRect(image.data,image.pitch,result.data,result.pitch,
          sx,sy,bw,bh,dx,dy);
     end;
   finally
    image.unlock;
    result.unlock;
   end;
  end;

 function ResampleImage(image:TTexture;newWidth,newHeight:integer;sysMem:boolean=false):TTexture;
  var
   tmp:array of cardinal;
   w,h:integer;
   flipX,flipY:boolean;
   u1,v1,u2,v2:single;
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   ASSERT((newWidth<>0) and (newHeight<>0));
   if (newWidth=image.width) and (newHeight=image.height) then begin
    result:=CreateImageCopy(image); exit;
   end;
   if newWidth<0 then begin
    flipX:=true; newWidth:=-newWidth;
   end else
    flipX:=false;
   if newHeight<0 then begin
    flipY:=true; newHeight:=-newHeight;
   end else
    flipY:=false;

   result:=painter.texman.AllocImage(newWidth,newHeight,ipfARGB,
       aiSysMem*byte(sysMem),'_'+image.name) as TTexture;
   result.Lock;
   if (newWidth>image.width) or (newHeight>image.height) then begin
    // При растяжении изображений на верхней и нижней линии вероятны артефакты,
    // поэтому создадим временную картинку расширив исходную на бордюр в 1px
    w:=image.width+2; h:=image.height+2;
    SetLength(tmp,w*h);
//   fillchar(tmp[0],w*h*4,0);
    image.Lock(0,lmReadOnly);
    CopyRect(image.data,image.pitch,@tmp[0],w*4,0,0,w-2,h-2,1,1); // Основная часть
    image.Unlock;
    CopyRect(@tmp[0],w*4,@tmp[0],w*4, 1,1,   w-2,1,  1,0); // Верхняя линия
    CopyRect(@tmp[0],w*4,@tmp[0],w*4, 1,h-2, w-2,1,  1,h-1); // нижняя линия
    CopyRect(@tmp[0],w*4,@tmp[0],w*4, 1,0,   1,h,    0,0); // левая линия
    CopyRect(@tmp[0],w*4,@tmp[0],w*4, w-2,0, 1,h,    w-1,0); // правая линия

    FillRect(result.data,result.pitch,0,0,newWidth-1,newHeight-1,$0);
    StretchDraw(@tmp[w+1],w*4,result.data,result.pitch,
      0,0,newWidth-1,newHeight-1,
      0,0,w-2,h-2,blCopy);
   end else begin
    // При уменьшении всё гораздо проще
    image.Lock(0,lmReadOnly);
    u1:=0; u2:=image.width;
    v1:=0; v2:=image.height;
    if flipX then Swap(u1,u2);
    if flipY then Swap(v1,v2);
    StretchDraw(image.data,image.pitch,result.data,result.pitch,
      0,0,newWidth-1,newHeight-1,
      u1,v1,u2,v2,blCopy);
    image.Unlock;
   end;
   result.Unlock;
  end;

 procedure SharpenImage(image:TTexture;strength:integer);
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    Sharpen(image.data,image.pitch,image.width,image.height,strength);
   finally
    image.unlock;
   end;
  end;

 procedure AdjustImage(image:TTexture;brightness,contrast,saturation:single);
  var
   mat:TMatrix43s;
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    MultMat4(Apus.GfxFilters.Saturation(saturation),BrightnessContrast(brightness,contrast),mat);
    MixRGB(image.data,image.pitch,image.width,image.height,mat);
   finally
    image.unlock;
   end;
  end;

 procedure ImageHueSaturation(image:TTexture;hue,saturation:single);
  var
   mat:TMatrix43s;
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    MultMat4(Apus.GfxFilters.Saturation(saturation),Apus.GfxFilters.Hue(hue),mat);
    MixRGB(image.data,image.pitch,image.width,image.height,mat);
   finally
    image.unlock;
   end;
  end;


initialization
 jpegImageHash.Init(false);
end.
