// Common purpose routines for engine and global variables/constants
// Many other engine units depend on this unit!
//
// Copyright (C) 2003-2004 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit engineTools;
{$IFDEF IOS} {$DEFINE GLES} {$DEFINE OPENGL} {$ENDIF}
{$IFDEF ANDROID} {$DEFINE GLES} {$DEFINE OPENGL} {$ENDIF}
interface
 uses {$IFDEF MSWINDOWS}windows,{$ENDIF}EngineAPI,images,UIClasses,regions,MyServis,
    UnicodeFont,CrossPlatform,BasicGame;

var
 rootDir:string='';

type
 // Большое изображение, состоящее из нескольких текстур
 TLargeImage=class
  images:array[0..15,0..15] of TTextureImage; // первый индекс - по X, второй - по Y
  width,height:integer;
  stepx,stepy:integer;
  cntX,cntY:integer;

  // Загрузить большое изображение в набор текстур
  // указывается размер ячеек для разбиения, размер ячеек, куда будут складываться неполные куски
  // и доля для закачки в видеопамять (от 0 до 1)
  constructor Create(fname:string;ForceFormat:ImagePixelFormat;
                cellsize:integer;flags:integer=0;precache:single=0);
  destructor Destroy; override;
  procedure Draw(x,y:integer;color:cardinal); virtual;
  procedure Precache(part:single); virtual;
  // получить регион, определяющий непрозрачную часть (прозрачность <50%)
  function GetRegion:TRegion; virtual;
 end;

 // Изображение, состоящее из нескольких кусков цельной текстуры
 TPatchedImage=class(TLargeImage)
  points:array[1..8] of TPoint;
  rects:array[1..8] of TRect;
  xMin,xMax,yMin,yMax:integer;
  count:integer;
  tex:TTextureImage;
  constructor Create(fname:string);
  destructor Destroy; override;
  procedure AddRect(xStart,yStart,Rwidth,Rheight:integer;posX,posY:integer); virtual;
  procedure Draw(x,y:integer;color:cardinal); override;
  procedure Precache(part:single); override;
  function GetRegion:TRegion; override;
 end;

 TVertexHandler=procedure(var vertex:TScrPoint);

var
 // основные объекты движка
 game:TBasicGame;
 texman:TTextureMan;
 painter:TPainter;

 {$IFDEF TXTIMAGES}
 txtFontNormal,txtFontSmall:TUnicodeFont;
 {$ENDIF}

 // Используемые форматы пикселя (в какие форматы грузить графику)
 // Они определяются исходя из доступного объема видеопамяти и кол-ва графики в игре
 pfIndexedAlpha:ImagePixelFormat; // формат для 8-битных картинок с прозрачностью
 pfIndexed:ImagePixelFormat; // Формат для 8-битных картинок без прозрачности или с одним прозрачным цветом
 pfTrueColorAlpha:ImagePixelFormat; // Формат для загрузки true-color изображений с прозрачностью
 pfTrueColor:ImagePixelFormat; // то же самое, но без прозрачности
 pfTrueColorAlphaLow:ImagePixelFormat; // То же самое, но для картинок, качеством которых можно пожертвовать
 pfTrueColorLow:ImagePixelFormat; // То же самое, но для картинок, качеством которых можно пожертвовать
 // форматы для отрисовки в текстуру
 pfRTLow:ImagePixelFormat;        // требований к качеству нет
 pfRTNorm:ImagePixelFormat;       // обычное изображение
 pfRTHigh:ImagePixelFormat;       // повышенные требования к качеству
 pfRTAlphaLow:ImagePixelFormat;   // вариант с альфаканалом
 pfRTAlphaNorm:ImagePixelFormat;  // вариант с альфаканалом
 pfRTAlphaHigh:ImagePixelFormat;  // вариант с альфаканалом

 loadingTime:integer; // суммарное время загрузки изображений в мс
 loadingJPEGTime:integer; // суммарное время загрузки JPEG в мс

const
 // Флаги для LoadImageFromFile
 liffSysMem  = aiSysMem; // Image will be allocated in system memory only and can't be used for accelerated rendering!
 liffTexture = aiTexture; // Image will be allocated as a whole texture (wrap UV enabled, otherwise - disabled!)
 liffPow2    = aiPow2; // Image dimensions will be increased to the nearest pow2
 liffMipMaps = aiMipMapping; // Image will be loaded with mip-maps (auto-generated if no mips in the file)
 liffAllowChange = $100;
 liffDefault = $FFFFFFFF;   // Use defaultLoadImageFlags for default flag values

 // width and height of meta-texture
 liffMW256   = aiMW256;
 liffMW512   = aiMW512;
 liffMW1024  = aiMW1024;
 liffMW2048  = aiMW2048;
 liffMW4096  = aiMW4096;

 liffMH256   = aiMH256;
 liffMH512   = aiMH512;
 liffMH1024  = aiMH1024;
 liffMH2048  = aiMH2048;
 liffMH4096  = aiMH4096;

var
 defaultLoadImageFlags:cardinal=0;

 function MTFlags(mtWidth,mtHeight:integer):cardinal; // build liffMxxx flags for given width/height values

 // Common purpose routines

 procedure MainLoop; // Infinite loop with event handling

 // Загрузить картинку из файла в текстуру (в оптимальный формат, если не указан явно)
 // Если sysmem=true, то загружается в поверхность в системной памяти
// function LoadImageFromFile(fname:string;mtwidth:integer=0;mtheight:integer=0;sysmem:boolean=false;
//           ForceFormat:ImagePixelFormat=ipfNone):TTexture;

 function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:ImagePixelFormat=ipfNone):TTexture;

 // (пере)загружает картинку из файла, т.е. освобождает если она была ранее загружена
 procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);

 // Сохраняет изображение в файл (mostly for debug purposes)
 procedure SaveImage(img:TTextureImage;fName:string);

 // Создать новую текстуру из куска данной (copy pixel data). Новая текстура размещается в доступной для
 // рендеринга памяти, тогда как источник может быть где угодно
 function CreateSubImage(source:TTextureImage;x,y,width,height:integer;flags:integer=0):TTextureImage;

 // Частный случай - копия изображения целиком (данные копируются)
 function CreateImageCopy(source:TTextureImage):TTextureImage;

 // Обёртка для CopyRect
 procedure CopyImageRect(source,dest:TTextureImage;sx,sy,width,height,targetX,targetY:integer);

 // загрузить текстуру с мип-мапами из файла (сперва ищется DDS, затем другие)
 // размер текстуры должен быть степенями 2
 // если мип-мапы в файле отсутствуют - будут созданы
 // если формат загружаемой картинки не соответствует финальному - будет сохранен DDS в нужном формате
 function LoadTexture(fname:string;downscale:single;format:ImagePixelFormat=ipfNone;saveDDS:boolean=true):TTextureImage;

 // Загрузить текстурный атлас
 // Далее при загрузке изображений, которые уже есть в атласе, вместо загрузки из файла будут
 // создаваться текстурные объекты, ссылающиеся на атлас
 // Not thread-safe! Don't load atlases in one thread and create images in other thread
 procedure LoadAtlas(fname:string;scale:single=1.0);

 // Set image as render target for FastGFX drawing operations (lock if not locked) Don't forget to unlock!
 procedure EditImage(tex:TTextureImage);

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
 function ShrinkImage(image:TTextureImage;x1,x2,x3,x4,y1,y2,y3,y4:integer;overlap:integer):TTextureImage;

 // Expands image this way: where y1..y2 = 456 band, and x1..x2 is 258 band (can also be used for shrinking)
 //  123      1223
 //  456  =>  4556
 //  789      4556
 //           7889
 function ExpandImage(image:TTextureImage;x1,x2,y1,y2:integer;overlap:integer):TTextureImage;

 // Создает растянутую/сжатую копию изображения (все в ARGB)
 function ResampleImage(image:TTextureImage;newWidth,newHeight:integer;sysMem:boolean=false):TTextureImage;

 // strength: 0..256 (ARGB and xRGB only!)
 procedure SharpenImage(image:TTextureImage;strength:integer);

 // brightness: -1..1 (0 - no change), contrast: 0..1.., saturation 0..1.. (1 - no change)
 procedure AdjustImage(image:TTextureImage;brightness,contrast,saturation:single);

 procedure ImageHueSaturation(image:TTextureImage;hue,saturation:single);

 // установить заданное изображение в качестве фона данного окна
 procedure SetupSkinnedWindow(wnd:TUISkinnedWindow;img:TTexture); overload;

 // Open URL in a browser window (or smth)
 procedure ShellOpen(url:string);

 // Рисует текст с эффектом glow/shadow в заданную текстуру
 // x,y - точка, где будет центр надписи (насколько возможно)
 procedure DrawTextWithGlow(img:TTextureImage;font:cardinal;x,y:integer;st:WideString;
     textColor,glowColor,glowDepth,glowBlur:cardinal;glowOfsX,glowOfsY:integer);

 // Создает текстуру с заданной надписью на прозрачном фоне, текст с эффектом glow/shadow
 function BuildTextWithGlow(font:cardinal;st:WideString;
    textColor,glowColor,glowDepth,glowBlur:cardinal;
    glowOfsX,glowOfsY:integer):TTextureImage;

 // Возвращает хэндл шрифта с измененным размером
 // Например, если scale = 1.2, то вернет шрифт такой же, но на 20% крупнее
 function ScaleFont(fontHandle:cardinal;scale:single):cardinal;

 // Camera transformations
 procedure Set2DTransform(originX,originY,scaleX,scaleY:double);
 procedure Reset2DTransform;

 // Meshes
 function LoadMesh(fname:string):TMesh;
 function BuildMeshForImage(img:TTexture;splitX,splitY:integer):TMesh;
 function TransformVertices(vertices:TVertices;shader:TVertexHandler):TVertices;
 procedure DrawIndexedMesh(vertices:TVertices;indices:TIndices;tex:TTexture);
 procedure DrawMesh(vertices:TVertices;tex:TTexture);
 procedure AddVertex(var vertices:TVertices;x,y,z,u,v:single;color:cardinal);

// procedure BuildNPatchMesh(img:TTexture;splitU,splitV,weightU,weightW:SingleArray;var vertices:TVertices;var indices:TIndices);

 // Shapes
 // Draw circle using band particles (
 procedure DrawCircle(x,y,r,width:single;n:integer;color:cardinal;tex:TTexture;rec:TRect;idx:integer);

 // добавляет в хэш предварительно загруженный JPEG объект
 procedure AddJPEGImage(filename:string;obj:TObject);

 // Формирует значение, содержащее координаты курсора для передачи в painter.TextOut
 function EncodeMousePos:cardinal;


 // FOR INTERNAL USE ----------------------------------------------------------

implementation
 uses SysUtils,{$IFDEF DIRECTX}DirectXGraphics,d3d8,DxImages8,{$ENDIF}
    {$IFDEF DELPHI}graphics,jpeg,{$ENDIF}
    {$IFDEF OPENGL}GLImages,{$ENDIF}
    {$IFDEF MSWINDOWS}ShellAPI,{$ENDIF}
    {$IFDEF ANDROID}Android,{$ENDIF}
    gfxformats,classes,structs,geom3d,FastGFX,Filters,UDict,ImgLoadQueue,GfxFormats3D;

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

  serial:cardinal;

  cSect:TMyCriticalSection;
  // "имя файла" -> cardinal(TJpegImage) - для предзагрузки jpeg'ов
  jpegImageHash:THash;

function EncodeMousePos:cardinal;
begin
  result:=word(game.mouseX) and $FFFF+word(game.mouseY) shl 16;
end;

procedure AddJPEGImage(filename:string;obj:TObject);
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
end;

function strHash(st:string):cardinal; inline;
var
 i:integer;
begin
 result:=0;
 for i:=1 to length(st) do inc(result,byte(st[i]) shl (i and 20));
end;

function ScaleFont(fontHandle:cardinal;scale:single):cardinal;
var
 v:cardinal;
begin
 v:=(fontHandle shr 16) and $FF;
 v:=round(v*scale);
 if v>255 then v:=255;
 result:=fontHandle and $FF00FFFF+v shl 16;
end;

{type
 TLaunchThread=class(TThread)
  url:string;
  constructor Create(LaunchUrl:string);
  procedure Execute; override;
 end;

constructor TLaunchThread.Create(launchUrl:string);
 begin
  url:=LaunchUrl;
  inherited Create(false);
 end;

procedure TLaunchThread.Execute;
begin
 ShellExecute(0,'open',PChar(url),'','',0);
end;}

procedure ShellOpen(url:string);
var
// thread:TLaunchThread;
 s:Pchar;
 ss:string;
 f:text;
 q:integer;
begin
 {$IFDEF MSWINDOWS}
 if uppercase(copy(url,length(url)-3,4))='.URL' then
 begin
  // Попытка найти адрес http
  assign(f,url);
  reset(f);
  repeat
   readln(f,ss);
   q:=pos('http',ss);
   if q=0 then
    q:=pos('HTTP',ss);
  until (q>0) or eof(f);
  if q=0 then begin
   LogMessage('ShellExecute: '+url);
   ShellExecute(0,'open',PChar(url),'','',SW_SHOW);
   exit;
  end;
  ss:=copy(ss,q,1024);
  close(f);
  LogMessage('ShellOpen: '+ss);
  ShellOpen(ss);
 end else
 begin
  s:=StrAlloc(1024);
  assign(f,'temp312.htm');
  rewrite(f);
  close(f);
  FindExecutable('temp312.htm','',s);
  Deletefile('temp312.htm');
  LogMessage('ShellExecute2: '+url);
  ShellExecute(0,'open',s,PChar(url), nil,SW_SHOW);
 end;
 {$ENDIF}
// thread:=TLaunchThread.Create(url);
end;

// подогнать формат пикселя под поддерживаемый системой
procedure AdjustFormat(var ForceFormat:ImagePixelFormat);
var
 i:integer;
begin
 i:=0;
 {$IFDEF DIRECTX}
 if texman.InheritsFrom(TDxTextureMan) then begin
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
 if texman.InheritsFrom(TGLTextureMan) then begin
  case ForceFormat of
   ipfXRGB,ipfRGB:forceFormat:=ipfARGB;
   ipfARGB,ipf4444,ipf4444r,ipf565,ipf1555,ipf555,ipfDXT1,ipfDXT3,ipfDXT5,ipfPVRTC:exit;
   ipf8bit:forceFormat:=ipfARGB;
   ipfA8,ipfMono8:; // keep as-is
   else
    raise EError.Create('Failed to choose valid pixel format for '+PixFmt2Str(ForceFormat));
  end;
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
  stepU,stepV:single;
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
  stepU:=0.5/aw;
  stepV:=0.5/ah;
  while not eof(f) do begin
   readln(f,x,y,w,h,st);
   st:=chop(st);
   if (st='') or (w=0) or (h=0) then continue;
   inc(aSubCount);
   img:=TTexture.Create;
   img.left:=x;
   img.top:=y;
   img.width:=w;
   img.height:=h;
   img.stepU:=stepU;
   img.stepV:=stepV;
   img.u1:=x*stepU*2;
   img.v1:=y*stepV*2;
   img.u2:=(x+w)*stepU*2;
   img.v2:=(y+h)*stepV*2;
   img.pixelFormat:=atlas.pixelFormat;
   img.atlas:=atlas;
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

function LoadTexture(fname:string;downscale:single;format:ImagePixelFormat=ipfNone;saveDDS:boolean=true):TTextureImage;
var
 i,j:integer;
 tex:TTextureImage;
 f:file;
 buf:ByteArray;
 size:integer;
 conversion:boolean;
 srcformat:TImageFormat;
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
    levels[i]:=images.TRawImage.Create;
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
 tex:=texman.AllocImage(imginfo.width,imginfo.height,format,
   aiTexture+aiMipmapping+aiPow2,fname) as TTextureImage;

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

//function LoadImageFromFile(fname:string;mtwidth:integer=0;mtheight:integer=0;sysmem:boolean=false;ForceFormat:ImagePixelFormat=ipfNone):TTexture;
function LoadImageFromFile(fname:string;flags:cardinal=0;ForceFormat:ImagePixelFormat=ipfNone):TTexture;
var
 i,j,k:integer;
 tex:TTextureImage;
 img,txtImage,preloaded:TRawImage;
 aFlags,mtWidth,mtHeight:integer;
 f:file;
 data,rawData:ByteArray;
 size2:integer;
 format:TImageFormat;
 sp,dp:PByte;
 time,timeJ:cardinal;
 linebuf:pointer;
 doScale:boolean;
 st:string;
 {$IFDEF DELPHI}
 jpeg:TJpegImage;
 bmp:TBitmap;
 {$ENDIF}
begin
 if texman=nil then
  raise EError.Create(fname+' - Loading failed: texture manager doesn''t exist!');

 try
  time:=MyTickCount;
  // 1. ADJUST FILE NAME AND CHECK ATLAS
  fname:=FileName(fname);
  // Search atlases first
  i:=FindFileInAtlas(fname);
  if i>0 then begin
   result:=TTexture.Clone(aImages[i]);
   exit;
  end;
  {$IFNDEF MSWINDOWS} // Use root dir
  if (rootDir<>'') and (fname[1]<>'/') then fname:=rootDir+fname;
  {$ENDIF}
  {$IFDEF IOS}
  if not FileExists(fname) then
   if FileExists(fname+'.tga') then fname:=fname+'.tga'
    else if FileExists(fname+'.pvr') then fname:=fname+'.pvr'
     else raise EError.Create(fname+' not found');
  {$ELSE}
  if pos('.',fname)<length(fname)-3 then begin // find file
   fName:=FindProperFile(fName);
  end;
  {$ENDIF}

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
  tex:=texman.AllocImage(ImgInfo.width,ImgInfo.height,ForceFormat,aFlags,copy(fname,pos('\',fname)+1,16)) as TTextureImage;
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
 if (time>0) and (time<50000) then inc(LoadingTime,time);
 if time>30 then LogMessage('Slow image loading: '+inttostr(time)+' - '+fname);
 result:=tex;
end;

function CreateSubImage(source:TTextureImage;x,y,width,height,flags:integer):TTextureImage;
var
 tex:TTextureImage;
 i,PixSize:integer;
 sp,dp:PByte;
begin
 tex:=texman.AllocImage(width,height,source.PixelFormat,flags,'p_'+source.name) as TTextureImage;
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

function CreateImageCopy(source:TTextureImage):TTextureImage;
begin
 result:=CreateSubImage(source,0,0,source.width,source.height,aiMW1024+aiMH1024);
end;

procedure CopyImageRect(source,dest:TTextureImage;sx,sy,width,height,targetX,targetY:integer);
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

{ TLargeImage }

constructor TLargeImage.Create(fname: string;
  ForceFormat: ImagePixelFormat; cellsize, flags: integer; precache: single);
 var
  i,j,x,y,w,h:integer;
  tex:TTextureImage;
  tname:string[40];
 begin
  tex:=LoadImageFromFile(fname,liffSysMem,forceFormat) as TTextureImage;
  width:=tex.width;
  height:=tex.height;
  tname:=fname;
  if length(tname)>12 then
   delete(tname,1,length(tname)-12);
  try
   cntX:=(tex.width-1) div cellsize +1;
   cntY:=(tex.height-1) div cellsize +1;
   stepx:=cellSize;
   stepy:=cellsize;
   for j:=0 to cntY-1 do
    for i:=0 to cntX-1 do begin
     x:=i*cellsize;
     y:=j*cellsize;
     if x+cellsize>tex.width then w:=tex.width-x else w:=cellsize;
     if y+cellsize>tex.height then h:=tex.height-y else h:=cellsize;
     if (w<cellsize) or (h<cellsize) then
      images[i,j]:=CreateSubImage(tex,x,y,w,h,flags)
     else
      images[i,j]:=CreateSubImage(tex,x,y,cellsize,cellsize,aiTexture);
     images[i,j].name:=inttohex(i,1)+inttohex(j,1)+'_'+tname;
    end;
  finally
   if tex<>nil then texman.FreeImage(TTexture(tex));
  end;
  self.Precache(precache);
 end;

destructor TLargeImage.Destroy;
 var
  i,j:integer;
 begin
  ASSERT(texman<>nil);
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do
    texman.FreeImage(TTexture(images[i,j]));
  inherited;  
 end;

procedure TLargeImage.Draw(x, y: integer; color: cardinal);
 var
  i,j:integer;
 begin
  ASSERT(painter<>nil);
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do
    painter.DrawImage(x+i*stepX,y+j*stepY,images[i,j],color);
 end;

function TLargeImage.GetRegion: TRegion;
{var
 r:TRegion;
 rs:array[0..7,0..7] of TRegion;
 i,j,size,pos:integer;
 img:TRawImage;
 color,mask:cardinal;}
begin
 result:=nil;
{ if images[0,0]=nil then exit;
 case images[0,0].PixelFormat of
  ipf1555,ipf4444:begin color:=$8000; mask:=$8000; end;
  ipfARGB:begin color:=$80000000; mask:=$80000000; end;
  else raise EError.Create('GetRegion: pixel format is not supported');
 end;
 r:=TRegion.Create(0,0);
 for i:=0 to cntx-1 do
  for j:=0 to cnty-1 do begin
   images[i,j].Lock;
   img:=images[i,j].GetRawImage;
   rs[i,j]:=TRegion.CreateFrom(img,color,mask);
   img.free;
   images[i,j].Unlock;
  end;

 result:=r;}
end;

procedure TLargeImage.Precache(part: single);
 var
  i,j,n:integer;
 begin
  ASSERT(texman<>nil);
  n:=round(cntX*cntY*part);
  if n<=0 then exit;
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do begin
    texman.MakeOnline(images[i,j] as TTexture);
    dec(n);
    if n=0 then exit;
   end;
 end;

procedure SetupWindow(wnd:TUISkinnedWindow;img:TLargeImage);
 begin
  wnd.background:=img;
  wnd.size.x:=img.width;
  wnd.size.y:=img.height;
  wnd.color:=$FF808080;
  wnd.visible:=false;
//  wnd.transpmode:=tmCustom;
//  wnd.region:=TRegion.CreateFrom(img);
 end;

procedure SetupSkinnedWindow(wnd:TUISkinnedWindow;img:TTexture);
 begin
  wnd.background:=img;
  wnd.size.x:=img.width;
  wnd.size.y:=img.height;
  wnd.color:=$FF808080;
  wnd.visible:=false;
 end;


{ TPatchedImage }

procedure TPatchedImage.AddRect(xStart, yStart, rwidth, rheight, posX,
  posY: integer);
begin
 if count=8 then exit;
 inc(count);
 rects[count].Left:=xStart;
 rects[count].Top:=yStart;
 rects[count].Right:=xStart+rwidth;
 rects[count].Bottom:=yStart+rheight;
 points[count].X:=posX;
 points[count].Y:=posY;
 if posX<xMin then xMin:=posX;
 if posX+rwidth>xMax then xMax:=posX+rwidth;
 if posY<yMin then yMin:=posY;
 if posY+rheight>yMax then yMax:=posY+rheight;
 width:=xMax-xMin;
 height:=yMax-yMin;
end;

constructor TPatchedImage.Create(fname: string);
begin
 count:=0; width:=0; height:=0;
 tex:=LoadImageFromFile(fname,liffTexture) as TTextureImage;
end;

destructor TPatchedImage.Destroy;
begin
 TexMan.FreeImage(TTexture(tex));
 inherited;
end;

procedure TPatchedImage.Draw(x, y: integer; color: cardinal);
var
 i:integer;
begin
 for i:=1 to count do
  painter.DrawImagePart(x+points[i].x,y+points[i].Y,tex,color,rects[i]);
end;

function TPatchedImage.GetRegion: TRegion;
begin

end;

procedure TPatchedImage.Precache(part: single);
begin
end;

procedure EditImage(tex:TTextureImage);
 begin
  if tex.locked=0 then tex.lock(0);
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

 function ShrinkImage(image:TTextureImage;x1,x2,x3,x4,y1,y2,y3,y4:integer;overlap:integer):TTextureImage;
  var
   w,h,imgW,imgH:integer;
  begin
   w:=image.width-(x2-x1)-(x4-x3);
   h:=image.height-(y2-y1)-(y4-y3);
   result:=texman.AllocImage(w,h,image.PixelFormat,0,image.name+'_shr') as TTextureImage;
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

 function ExpandImage(image:TTextureImage;x1,x2,y1,y2:integer;overlap:integer):TTextureImage;
  var
   w,h,imgW,img,dw,dh,i,j,sx,sy,dx,dy,bw,bh:integer;
  begin
   dw:=x2-x1;
   dh:=y2-y1;
   w:=image.width+dw;
   h:=image.height+dh;
   result:=texman.AllocImage(w,h,image.PixelFormat,0,image.name+'_expd') as TTextureImage;
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

 procedure LoadImage(var img:TTexture;fName:string;flags:cardinal=liffDefault);
  begin
   if flags=liffDefault then flags:=defaultLoadImageFlags;
   if img<>nil then texman.FreeImage(TTexture(img));
   img:=LoadImageFromFile(FileName('Images\'+fName),flags,ipf32bpp);
  end;

 procedure SaveImage(img:TTextureImage;fName:string);
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

 procedure DrawTextWithGlow(img:TTextureImage;font:cardinal;x,y:integer;st:WideString;
     textColor,glowColor,glowDepth,glowBlur:cardinal;glowOfsX,glowOfsY:integer);
  var
   w,h,d,i:integer;
   alpha:pointer;
   pb:PByte;
   tmp:PByte;
  begin
   img.Lock;
   try
   st:=Translate(st);
   d:=GlowDepth+glowBlur;
   w:=painter.TextWidthW(font,st)+4+2*d; h:=round(3*d+painter.FontHeight(font)*1.5);
   GetMem(tmp,w*h*4);
   fillchar(tmp^,w*h*4,0);
   painter.SetTextTarget(tmp,w*4);
   painter.TextOutW(font,w div 2,round(h*0.77)-d,textColor,st,EngineAPI.taCenter,toDrawToBitmap);
   dec(x,round(w/2));
   dec(y,round(h/2));
   if glowColor>$FFFFFF then begin
    alpha:=ExtractAlpha(tmp,w*4,w,h);
    Maximum8(alpha,0,0,w-1,h-1,w,glowDepth,glowDepth);
//   for i:=1 to glowBlur do
    while glowBlur>1 do begin
     Blur8(alpha,w,w,h);
     dec(glowBlur,2);
    end;
    if glowBlur>0 then
     LightBlur8(alpha,w,w,h);
    pb:=GetPixelAddr(img.data,img.pitch,x+glowOfsX,y+glowOfsY);
    BlendUsingAlpha(pb,img.pitch,alpha,w,w,h,glowColor,blBlend);
    FreeMem(alpha);
   end;
   SimpleDraw(tmp,w*4,img.data,img.pitch,x,y,w,h,blBlend);
   FreeMem(tmp);
   finally
    img.Unlock;
   end;
  end;

 function BuildTextWithGlow(font:cardinal;st:WideString;
    textColor,glowColor,glowDepth,glowBlur:cardinal;
    glowOfsX,glowOfsY:integer):TTextureImage;
  var
   img:TTextureImage;
   w,h,d:integer;
  begin
   d:=GlowDepth+glowBlur;
   st:=Translate(st);
   w:=painter.TextWidthW(font,st)+6+2*d; h:=round(3*d+painter.FontHeight(font)*1.5);
//   if w mod 2=0 then inc(w);
   img:=texman.AllocImage(w,h,pfTrueColorAlpha,aiClampUV,'BTWG'+inttostr(serial)) as TTextureImage;
   inc(serial);
   img.Lock;
   FillRect(img.data,img.pitch,0,0,w-1,h-1,$00808080);
//   FillRect(img.data,img.pitch,0,0,w-1,h-1,$501010C0);
   DrawTextWithGlow(img,font,round(w*0.5),round(h*0.5),st,textColor,
     glowColor,glowDepth,glowBlur,glowOfsX,glowOfsY);
   img.Unlock;
   result:=img;
  end;

 function ResampleImage(image:TTextureImage;newWidth,newHeight:integer;sysMem:boolean=false):TTextureImage;
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

   result:=texman.AllocImage(newWidth,newHeight,ipfARGB,
       aiSysMem*byte(sysMem),'_'+image.name) as TTextureImage;
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

 procedure SharpenImage(image:TTextureImage;strength:integer);
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    Sharpen(image.data,image.pitch,image.width,image.height,strength);
   finally
    image.unlock;
   end;
  end;

 procedure AdjustImage(image:TTextureImage;brightness,contrast,saturation:single);
  var
   mat:TMatrix43s;
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    MultMat4(filters.Saturation(saturation),BrightnessContrast(brightness,contrast),mat);
    MixRGB(image.data,image.pitch,image.width,image.height,mat);
   finally
    image.unlock;
   end;
  end;

 procedure ImageHueSaturation(image:TTextureImage;hue,saturation:single);
  var
   mat:TMatrix43s;
  begin
   ASSERT(image.PixelFormat in [ipfARGB,ipfxRGB]);
   image.lock;
   try
    MultMat4(filters.Saturation(saturation),filters.Hue(hue),mat);
    MixRGB(image.data,image.pitch,image.width,image.height,mat);
   finally
    image.unlock;
   end;
  end;

 procedure Set2DTransform(originX,originY,scaleX,scaleY:double);
  var
   mat:TMatrix4;
  begin
   fillchar(mat,sizeof(mat),0);
   mat[0,0]:=scaleX;
   mat[1,1]:=scaleY;
   mat[2,2]:=1;
   mat[3,0]:=originX;
   mat[3,1]:=originY;
   mat[3,3]:=1;
   painter.Set3DTransform(mat);
  end;

 procedure Reset2DTransform;
  begin
   Set2DTransform(0,0,1,1);
  end;

 function LoadMesh(fname:string):TMesh;
  var
   ext:string;
  begin
   fname:=FileName(fName);
   ext:=lowerCase(ExtractFileExt(fname));
   if ext='.obj' then result:=LoadOBJ(fName);
  end;

 function BuildMeshForImage(img:TTexture;splitX,splitY:integer):TMesh;
  var
   i,j,n,v:integer;
   du,dv,dx,dy:single;
  begin
   result:=TMesh.Create;
   texman.MakeOnline(img);
   // Fill vertices
   with result do begin
   SetLength(vertices,(splitX+1)*(splitY+1));
   du:=(img.u2-img.u1)/splitX;
   dv:=(img.v2-img.v1)/splitY;
   dx:=img.width/splitX;
   dy:=img.height/splitY;
   n:=0;
   for i:=0 to splitY do
    for j:=0 to splitX do begin
     with vertices[n] do begin
      x:=j*dx-0.5; y:=i*dy-0.5; z:=0; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
      diffuse:=$FF808080;
      u:=img.u1+du*j;
      v:=img.v1+dv*i;
     end;
     inc(n);
    end;
   // Fill indices
   SetLength(indices,splitX*splitY*2*3);
   n:=0;
   for i:=0 to splitY-1 do
    for j:=0 to splitX-1 do begin
     v:=i*(splitX+1)+j;
     indices[n]:=v; inc(v);
     indices[n+1]:=v; inc(v,splitX+1);
     indices[n+2]:=v;
     inc(n,3);
     indices[n]:=v; dec(v);
     indices[n+1]:=v; dec(v,splitX+1);
     indices[n+2]:=v;
     inc(n,3);
    end;
   end;
  end;

 procedure DrawIndexedMesh(vertices:TVertices;indices:TIndices;tex:TTexture);
  begin
   painter.DrawIndexedMesh(@vertices[0],@indices[0],length(indices) div 3,length(vertices),tex);
  end;

 procedure DrawMesh(vertices:TVertices;tex:TTexture);
  begin
   painter.DrawTrgListTex(@vertices[0],length(vertices) div 3,tex);
  end;

 procedure AddVertex(var vertices:TVertices;x,y,z,u,v:single;color:cardinal);
  var
   n:integer;
  begin
   n:=length(vertices);
   SetLength(vertices,n+1);
   vertices[n].x:=x;
   vertices[n].y:=y;
   vertices[n].z:=z;
   vertices[n].u:=u;
   vertices[n].v:=v;
   vertices[n].diffuse:=color;
  end;

 function TransformVertices(vertices:TVertices;shader:TVertexHandler):TVertices;
  var
   i:integer;
  begin
   SetLength(result,length(vertices));
   for i:=0 to length(vertices)-1 do begin
    result[i]:=vertices[i];
    Shader(result[i]);
   end;
  end;

 procedure DrawCircle(x,y,r,width:single;n:integer;color:cardinal;tex:TTexture;rec:TRect;idx:integer);
  var
   i:integer;
   parts:array of TParticle;
   a,step:single;
  begin
   SetLength(parts,n);
   a:=0; step:=2*pi/n;
   for i:=0 to n-1 do begin
    parts[i].x:=x+cos(a)*r;
    parts[i].y:=y-sin(a)*r;
    parts[i].z:=0;
    parts[i].color:=color;
    parts[i].scale:=width;
    parts[i].index:=idx;
    a:=a+step;
   end;
   inc(parts[n-1].index,partLoop);
   painter.DrawBand(0,0,@parts[0],n,tex,rec);
  end;

procedure MainLoop;
begin
 repeat
  try
   PingThread;
   CheckCritSections;
   Delay(5); // Handling signals is inside 
   ProcessMessages;
  except
   on e:exception do ForceLogMessage('Error in MainLoop: '+ExceptionMsg(e));
  end;
 until game.terminated;
end;

initialization
 InitCritSect(cSect,'engineTools',120);
 jpegImageHash.Init(false);
end.
