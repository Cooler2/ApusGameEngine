// DirectX8-based texture classes and texture manager
//
// Copyright (C) 2003 Apus Software (www.games4win.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
unit DxImages8;
interface
 uses EngineAPI,Images,DirectXGraphics,d3d8,windows,myservis;

type
 // Текстура DirectX
 TDxTexture=class(TTextureImage)
  texture:IDirect3DTexture8; // интерфейс для доступа к объекту текстуры (чтобы использовать его в обход Painter'ов)
  trueWidth,trueHeight:integer; // точные размеры выделенной текстуры в пикселях
//  PalIndex:integer; // индекс палитры (если есть)
  constructor Create;
//  procedure SetPalette(pal:TPalette); override;
  procedure SetAsRenderTarget; virtual;
  destructor Destroy; override;
 end;

 // Представляет собой managed-текстуру
 TDxManagedTexture=class(TDxTexture)
  constructor Create;
  procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;r:PRect=nil); override;
  procedure LockNext; override; // залочить следующий уровень mip-map
  procedure AddDirtyRect(rect:TRect); override;
  procedure Unlock; override;
  destructor Destroy; override;
  function GetRawImage:TRawImage; override;
  procedure GenerateMipMaps(count:byte); override;
  function GetSurface:IDirect3DSurface8;

 protected
  SysMemTex:IDirect3DTexture8; // постоянный экземпляр текстуры (если это текстура)
  SysMemImage:IDirect3DSurface8; // постоянный экземпляр изображения (одноуровневой текстуры)
  handle,tag:integer; // используется для внутренних целей менеджером
  MTWidth,MTheight:integer;
  level:byte; // номер залоченного mipmap'а
 public
  online:boolean;    // true - если в видеопамяти доступна копия изображения
  allocated:boolean; // true - если информация о размещении соответствует выделенному изображению в видеопамяти
 end;

 TDxTextureMan=class(TTextureMan)
  constructor Create(MemoryLimit:integer); // Лимит видеопамяти в килобайтах
  destructor Destroy; override;

  function AllocImage(width,height:integer;
                      PixFmt:ImagePixelFormat;Flags:integer;name:texnamestr):TTexture; override;
  procedure FreeImage(var image:TTexture); override;
  procedure FreeImage(var image:TTextureImage); override;
  procedure MakeOnline(img:TTexture); override;
  function QueryParams(width,height:integer;format:ImagePixelFormat;aiFlags:integer):boolean; override;

  procedure ReleaseAll; virtual;   // Уничтожить все созданные ресурсы в видеопамяти (чтобы можно было восстановить девайс - текстурные объекты и дескрипторы не удаляются!!!)
  procedure ReCreateAll; virtual;  // Пересоздать все необходимые ресурсы в видеопамяти (после того, как девайс восстановлен)

  // Вспомогательные функции (для отладки/получения инфы)
  function GetStatus(line:byte):string; override; // Формирует строки статуса

  // Создает дамп использования и распределения видеопамяти
  procedure Dump(st:string=''); override;

 protected
  procedure FreeVidMem; // Освободить некоторое кол-во видеопамяти
  procedure FreeMetaTexSpace(n:integer); // Освободить некоторое пространство в указанной метатекстуре

 protected
  CurTag:integer;
  data:TObject;
  crSect:TMyCriticalSection;
 end;

 // Load image from file (TGA or JPG), result is expected in given pixel format or source pixel format
// function LoadFromFile(filename:string;format:ImagePixelFormat=ipfNone):TDxManagedTexture;

implementation
 uses eventman,SysUtils,types,gfxFormats;

type
 TextureDescriptor=record
  tex:IDirect3DTexture8;
  width,height:integer;
  PixelFormat:TD3DFORMAT;
  caps:integer;
  mipmaps:integer;
  texture:TDxManagedTexture; // только для текстур целиком, не для метатекстур
  memsize:integer; // Объем в байтах
  weight:single; // Чем ближе вес к curtag'у - тем актуальнее содержимое текстуры
  used:boolean;
 end;

 TextureUsage=record   // описывает занятую часть текстуры
  rectCnt,texCnt:integer; // кол-во прямоугольников и кол-во текстур
  rects:array[0..15] of TRect; // свободные прямоугольники
  textures:array[0..31] of TDxManagedTexture;
 end;

 TextureManData=class
  pool:array[0..1023] of TextureDescriptor; // 1024 текстур в видеопамяти
  UsageMaps:array[0..63] of TextureUsage; // 64 метатекстуры, в которых возможно подразбиение
  // Индексы свободных текстур, доступных целиком
  FreeInd:array[1..1000] of integer;
  FreeIndCnt:integer; // кол-во индексов свободных текстур (остальные - занятые)
  // Индексы текстур с подразбиением (сперва занятые, затем - свободные)
  MetaInd:array[1..64] of integer;
  UsedMetaInd:integer;   // кол-во занятых индексов
  MemLimit,MemUsed:integer;
  function CreateTextureByDescriptor(var desc:TextureDescriptor):integer;
  procedure Dump(st:string='');
 end;

var
 dumpnum:integer;

function GetBPP(format:integer):integer;
begin
 if format in [D3DFMT_A8R8G8B8,D3DFMT_X8R8G8B8] then begin
  result:=4; exit;
 end;
 if format=D3DFMT_DXT1 then begin
  result:=8; exit;
 end;
 if (format=D3DFMT_DXT2) or (format=D3DFMT_DXT3) or (format=D3DFMT_DXT5) then begin
  result:=16; exit;
 end;
 if format in [D3DFMT_X1R5G5B5,D3DFMT_R5G6B5,D3DFMT_A1R5G5B5,D3DFMT_A4R4G4B4] then begin
  result:=2; exit;
 end;
 if format in [D3DFMT_P8,D3DFMT_A8] then begin
  result:=1; exit;
 end;
 if format in [D3DFMT_R8G8B8] then begin
  result:=3; exit;
 end;
 raise EWarning.Create('Unknown format - cannot determine BPP');
end;

// Создать D3D-текстуру, соответствующую дескриптору и сохранить ее интерфейс в нем
function TextureManData.CreateTextureByDescriptor(var desc:TextureDescriptor):integer;
var
 usage:integer;
begin
 with desc do begin
  memsize:=width*height*GetBPP(PixelFormat);
  if (PixelFormat=D3DFMT_DXT1) or
     (PixelFormat=D3DFMT_DXT2) or
     (PixelFormat=D3DFMT_DXT3) or
     (PixelFormat=D3DFMT_DXT5) then memsize:=memsize div 16;
  if memsize+MemUsed>MemLimit then begin
   result:=D3DERR_OUTOFVIDEOMEMORY; exit;
  end;
  if caps and tfRenderTarget>0 then usage:=D3DUSAGE_RENDERTARGET else usage:=0;
  result:=device.CreateTexture(width,height,mipmaps,
           usage,PixelFormat,D3DPOOL_DEFAULT,tex);
//  LogMessage('CreateTexture('+inttostr(width)+','+inttostr(height)+','++')');
  // Нет памяти: попытка повторного выделения
{  if (result=D3DERR_OUTOFVIDEOMEMORY) then begin
   sleep(500);
   result:=device.CreateTexture(width,height,mipmaps,
           usage,PixelFormat,D3DPOOL_DEFAULT,tex);
  end;}
  if (result<0) and (result<>D3DERR_OUTOFVIDEOMEMORY) then
   raise EError.Create('DxTexMan: cannot create texture - '+DXGErrorString(result));
  if result>=0 then begin
   if tex=nil then begin
    Dump('Nil texture');
    raise EFatalError.Create('CTD: nil returned');
   end;
   inc(MemUsed,memsize);
  end;
 end;
end;

{ TDxTextureMan }

function TDxTextureMan.AllocImage(width,height:integer;
  PixFmt: ImagePixelFormat; Flags: integer;name:texnamestr): TTexture;
var
 t:TDxManagedTexture;
 dtex:IDirect3DTexture8;
 surf:IDirect3DSurface8;
 levels:byte;
 format:cardinal;
 res,ind,i:integer;
 mtWidth,mtHeight:integer;
begin
 mtWidth:=0;
 mtHeight:=0;
 if flags and $FF0000>0 then begin
  mtWidth:=128 shl ((flags shr 16) and $7);
  mtHeight:=128 shl ((flags shr 20) and $7);
  if mtHeight=128 then mtHeight:=mtWidth;
 end;
 try
 EnterCriticalSection(crSect);
 try
 result:=nil;
 t:=TDxManagedTexture.Create;
 LogMessage('AllocImage('+inttostr(width)+','+inttostr(height)+','+
    inttostr(ord(pixfmt))+','+inttostr(flags)+','+name+')='+inttohex(cardinal(t) div 16 mod 65536,4)+
    ' thread: '+GetThreadName);
 t.handle:=0;
 t.name:=name;
 // Вычислим правильный размер метатекстуры
 if (mtWidth<width) or (mtHeight<64) then begin
  mtWidth:=64;
  while mtWidth<width do mtWidth:=mtWidth*2;
 end;
 if (mtHeight<height) or (mtHeight<64) then begin
  mtHeight:=64;
  while mtHeight<height do mtHeight:=mtHeight*2;
 end;
 t.MTWidth:=MTWidth;
 t.MTHeight:=MTHeight;
 if flags and aiMipMapping>0 then levels:=0 else levels:=1;
 if flags and aiPow2>0 then begin
  width:=Getpow2(width);
  height:=GetPow2(height);
 end;

 format:=GetD3DFormat(PixFmt);
 t.PixelFormat:=PixFmt;
 t.online:=false;
 t.allocated:=false;
 t.width:=width; t.height:=height;

 if pixFmt in [ipfDXT1..ipfDXT5] then begin
{  width:=(width+3) shr 2;
  height:=(height+3) shr 2;}
  if flags and aiRenderTarget>0 then
   raise EWarning.Create('Can''t create compressed RT texture');
 end;

 // создание RT-текстуры, т.е. ТОЛЬКО в видеопамяти
 if flags and aiRenderTarget>0 then with data as TextureManData do begin
  LogMessage('RT-texture',2);
  t.caps:=tfRenderTarget+tfVidmemOnly+tfCanBeLost+tfTexture;
  t.left:=0; t.top:=0;
  t.u1:=0;
  t.v1:=0;
  t.stepU:=0.5/width;
  t.stepV:=0.5/height;
  t.u2:=1;
  t.v2:=1;
  t.allocated:=true;
  t.online:=true;

  // Создать дескриптор для выделенной текстуры
  if FreeIndCnt<=0 then raise EError.Create('Out of texture descriptors');
  ind:=FreeInd[FreeIndCnt];
  with pool[ind] do begin
{   if flags and aiPow2>0 then begin
    width:=GetPow2(t.width);
    height:=GetPow2(t.height);
   end;}
   width:=t.width;
   height:=t.height;
   // корректировка параметров частично выделенной текстуры
   if (width<>t.width) or (height<>t.height) then begin
    t.stepU:=0.5/width;
    t.stepV:=0.5/height;
    t.u2:=t.stepU*(t.width*2);
    t.v2:=t.stepV*(t.height*2);
   end;
   if flags and aiDontScale=0 then begin
    width:=round(width*scaleX);
    height:=round(height*scaleY);
    t.caps:=t.caps or tfScaled;
{    t.scaleX:=scaleX;
    t.scaleY:=scaleY;}
   end;
   t.trueWidth:=width;
   t.trueHeight:=height;
   PixelFormat:=format;
   caps:=t.caps;
   mipmaps:=1;
   texture:=t;
   memsize:=width*height*GetBPP(format);
   weight:=-1;
   used:=true;
  end;
  for i:=1 to 5 do begin
   if i=5 then begin
    Dump('no memory for RT texture');
    raise EError.Create('Failed to allocate RT texture - no memory');
   end;
   LogMessage('Allocation stage '+inttostr(i),2);
   if CreateTextureByDescriptor(pool[ind])<0 then begin
    LogMessage('Free vidmem for '+name+' ('+inttohex(cardinal(t) div 16 mod 65536,4)+')');
    FreeVidMem;
   end else break;
  end;
  Dec(FreeIndCnt);
  LogMessage('Full texture index - '+inttostr(ind),2);
  t.texture:=pool[ind].tex;
  t.mipmaps:=t.texture.GetLevelCount;
  t.handle:=ind; // номер дескриптора
  t.tag:=CurTag; inc(CurTag);

  pool[ind].weight:=CurTag; // большее значение, чем у обычной текстуры
  result:=t;
  exit;
 end; // Render target

 t.texture:=nil;
 // Теперь создадим изображение в системной памяти
 if pixfmt in [ipfDXT1..ipfDXT5] then begin
  width:=getPow2(width);
  height:=getPow2(height);
  flags:=flags or aiTexture; 
 end;
 t.trueWidth:=width;
 t.trueHeight:=height;
 if flags and aiTexture>0 then begin
  // Текстура
  res:=device.CreateTexture(width,height,levels,0,format,D3DPOOL_SYSTEMMEM,dtex);
  if res<0 then begin
   sleep(250);
   res:=device.CreateTexture(width,height,levels,0,format,D3DPOOL_SYSTEMMEM,dtex);
  end;
  if res<0 then raise EError.Create('DxTexMan: cannot create sysmem texture - '+DXGErrorString(res));
  t.SysMemTex:=dtex;
  t.SysMemImage:=nil;
  t.mipmaps:=dtex.GetLevelCount;
  t.caps:=t.caps or tfTexture;
  t.u1:=0; t.v1:=0;
  t.u2:=1; t.v2:=1;
  t.stepU:=0.5/width;
  t.stepV:=0.5/height;
 end else begin
  // Однослойная поверхность
  res:=device.CreateImageSurface(width,height,format,surf);
  if res<0 then begin
   sleep(250);
   res:=device.CreateImageSurface(width,height,format,surf);
  end;
  if res<0 then raise EError.Create('DxTexMan: cannot create sysmem texture - '+DXGErrorString(res));
  t.SysMemTex:=nil;
  t.SysMemImage:=surf;
  t.mipmaps:=1;
 end;
 t.caps:=t.caps or tfDirectAccess;
 result:=t;
 finally
  LeaveCriticalSection(crSect);
 end;
 except
  on e:exception do raise EError.Create('texman.AI '+e.message);
 end;
end;

constructor TDxTextureMan.Create(MemoryLimit: integer);
var
 i:integer;
begin
 CurTag:=0;
 scaleX:=1; scaleY:=1;
 // Инициализация внутренних структур
 data:=TextureManData.Create;
 with data as TextureManData do begin
  MemLimit:=MemoryLimit*1024; memused:=0;
  FreeIndCnt:=960;
  for i:=1 to FreeIndCnt do FreeInd[i]:=i+63;
  UsedMetaInd:=0;
  for i:=1 to 64 do MetaInd[i]:=i-1;
  for i:=0 to 1023 do
   fillchar(pool[i],sizeof(pool[i]),0);
 end;
 maxTextureSize:=min2(d3d8.CAPS.MaxTextureWidth,d3d8.CAPS.MaxTextureHeight);

 InitCritSect(crSect,'TexMan');
end;

destructor TDxTextureMan.Destroy;
var
 i,j,ind:integer;
begin
 LogMessage('Deleting TexMan');
{ Dump;
 LogMessage('Dump created');}
 ReleaseAll; // Освободить все ресурсы в видеопамяти
 // Теперь освободим все прочие ресурсы
 with data as TextureManData do begin
  for i:=FreeIndCnt+1 to 960 do begin // Освободить дескриптор
   ind:=FreeInd[i];
   pool[ind].texture.Free;
   pool[ind].used:=false;
  end;
  for i:=1 to UsedMetaInd do begin // По всем метатекстурам
   ind:=MetaInd[i]; // индекс метатекстуры в pool'е
   for j:=1 to UsageMaps[ind].texCnt do // по всем текстурам в данной метатекстуре
    usageMaps[ind].textures[j-1].Free;
  end;
 end;
 data.Free;
 inherited;
 DeleteCritSect(crSect);
 LogMessage('TexMan deleted');
end;

procedure TDxTextureMan.Dump;
begin
 (data as TextureManData).Dump(st);
end;

procedure TextureManData.Dump;
var
 f:text;
 i,j:integer;
 tex:TTexture;
 r:TRect;
begin
 if dumpnum>8 then exit;
 inc(dumpnum);
 assign(f,'texman'+inttostr(dumpnum)+'.txt');
 rewrite(f);
 if st<>'' then writeln(f,'Dump reason: ',st);
// with data as TextureManData do begin
  writeln(f,'Memory limit: ',memlimit);
  writeln(f,'Memory used: ',memused);
  writeln(f,'D3D reports: ',device.GetAvailableTextureMem);
  writeln(f);
  writeln(f,'Texture indices:');
  if FreeIndCnt>0 then
   writeln(f,'Free');
  for i:=1 to 960 do begin
   write(f,i,' - ',FreeInd[i],' ',pool[FreeInd[i]].used);
   if pool[FreeInd[i]].used then begin
    tex:=pool[FreeInd[i]].texture;
    write(f,' tex ',inttohex(cardinal(tex) div 16 mod 65536,4));
    writeln(f,' (',pool[FreeInd[i]].width,'x',pool[FreeInd[i]].height,',',GetFormatName(pool[FreeInd[i]].pixelformat),',',tex.name,')');
   end else writeln(f);
   if i=FreeIndCnt then writeln(f,'Used');
  end;
  writeln(f);
  writeln(f,'Metatexture indices:');
  if UsedMetaInd>0 then
   writeln(f,'Used:');
  for i:=1 to 64 do begin
   write(f,i,' - ',metaind[i]);
   if i<=UsedMetaInd then begin
    write(f,' ( ');
    for j:=1 to UsageMaps[MetaInd[i]].texCnt do
     write(f,inttohex(cardinal(UsageMaps[MetaInd[i]].textures[j-1]) div 16 mod 65536,4),' ');
    writeln(f,')');
   end else writeln(f);
  end;
  writeln(f,'Metatextures details:');
  for i:=0 to 63 do
   if pool[i].used then begin
    writeln(f,i,': ',pool[i].width,'x',pool[i].height,',',GetFormatName(pool[i].pixelformat));
    for j:=1 to UsageMaps[i].texCnt do begin
     tex:=UsageMaps[i].textures[j-1];
     write(f,j:4,': ',inttohex(cardinal(tex) div 16 mod 65536,4),' - ',tex.width,'x',tex.height,' at ');
     writeln(f,tex.left,',',tex.top,' - ',tex.name);
    end;
    if UsageMaps[i].rectCnt>0 then
     writeln(f,'  Free rects:');
    for j:=0 to UsageMaps[i].rectCnt-1 do begin
     r:=UsageMaps[i].rects[j];
     writeln(f,j:4,': ',r.left,',',r.Top,' - ',r.Right,',',r.bottom);
    end;
   end;
// end;
 close(f);
 // Картинки текстур
{ for i:=0 to 63 do
  if pool[i].used then begin
   WriteTGA();
  end;}
end;

procedure TDxTextureMan.FreeImage(var image: TTexture);
var
 img:TDxManagedTexture;
 i,j,ind,v:integer;
 del:array[0..15] of boolean;
begin
 if image=nil then exit;
 EnterCriticalSection(crSect);
 try
 if image=nil then Dump('image=nil');
 ASSERT(image<>nil);
 LogMessage('FreeImage('+inttohex(cardinal(image) div 16 mod 65536,4)+')');
 img:=image as TDxManagedTexture;
 if img.allocated then with data as TextureManData do begin
  // deallocate image
  ind:=img.handle;
  if ind<64 then begin
   // удаление картинки в метатекстуре
   with UsageMaps[ind] do begin
    for i:=0 to texCnt-1 do // Найдем и уберем ссылку на текстурный объект
     if textures[i]=img then begin
      dec(texcnt);
      textures[i]:=textures[texcnt];
      break;
     end;
    if rectCnt<16 then with rects[rectCnt] do begin // Добавим свободный прямоугольник
     left:=img.left; top:=img.top;
     right:=left+img.width;
     bottom:=top+img.height;
     inc(RectCnt);
    end;
    // Склеивание прямоугольников
    if rectcnt>1 then
    repeat
     v:=0;
     fillchar(del,sizeof(del),0);
     for i:=0 to RectCnt-1 do
      for j:=0 to RectCnt-1 do
       if (i<>j) and not del[i] and not del[j] then begin
        if (rects[i].Left=rects[j].Left) and
           (rects[i].right=rects[j].right) and
           (rects[i].Bottom=rects[j].Top) then begin
          rects[i].Bottom:=rects[j].Bottom;
          del[j]:=true;
          v:=1;
         end;
        if (rects[i].top=rects[j].top) and
           (rects[i].bottom=rects[j].bottom) and
           (rects[i].right=rects[j].left) then begin
          rects[i].right:=rects[j].right;
          del[j]:=true;
          v:=1;
         end;
       end;
     i:=0; j:=rectcnt-1;  // теперь удалим все отмеченные прямоугольники
     while i<j do begin
      if del[j] then begin
       dec(j); dec(rectcnt);
       continue;
      end;
      if del[i] then begin
       rects[i]:=rects[j];
       dec(rectcnt); dec(j); inc(i);
      end;
      inc(i);
     end;
    until v=0;
{    if (texcnt=0) and (MemUsed>MemLimit div 2) then begin // Нет текстур
     // Удалить метатекстуру
     for i:=1 to UsedMetaInd do
      if MetaInd[i]=ind then break;
     pool[ind].tex:=nil;
     dec(MemUsed,pool[ind].memsize);
     dec(UsedMetaInd);
     v:=MetaInd[UsedMetaInd];
     MetaInd[UsedMetaInd]:=metaind[i];
     MetaInd[i]:=v;
    end;}
   end;
  end else begin
   // удаление целой текстуры
   for i:=FreeIndCnt+1 to 961 do
    if FreeInd[i]=ind then break;
   if i>=961 then begin
    ForceLogMessage('Index '+inttostr(ind)+' not found. See dump');
    Dump('no index');
   end;
   Assert(i<961,'Index not found!');
   pool[ind].tex:=nil;
   pool[ind].used:=false;
   dec(MemUsed,pool[ind].memsize);

   inc(FreeIndCnt);
   v:=FreeInd[FreeIndCnt];
   FreeInd[FreeIndCnt]:=ind;
   FreeInd[i]:=v;
  end;
 end;
 img.SysMemTex:=nil;
 img.SysMemImage:=nil;
 img.Free;
 image:=nil;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

procedure TDxTextureMan.FreeImage(var image: TTextureImage);
begin
 FreeImage(TTexture(image));
end;

procedure TDxTextureMan.FreeMetaTexSpace(n: integer);
begin

end;

procedure TDxTextureMan.FreeVidMem;
type
 TIndices=array[0..1023] of integer;
var
 list1,list2:TIndices;
 indcnt,ind,v:integer;
 i,j,volume,av:integer;
 procedure Sort(min,max:integer);
  var
   i,j,v,c:integer;
  begin
   with data as TextureManData do
   if max-min<10 then begin
    // квадратичная сортировка
    for i:=min to max-1 do
     for j:=max downto i+1 do
      if pool[list1[j]].weight>pool[list1[j-1]].weight then begin
       v:=list1[j]; list1[j]:=list1[j-1]; list1[j-1]:=v;
      end;
   end else begin
    // Сортировка частей и слияние
    v:=(min+max) div 2;
    Sort(min,v); Sort(v+1,max);
    for i:=min to max do list2[i]:=list1[i];
    i:=min; j:=v+1;
    for c:=min to max do begin
     if (i<=v) and (j<=max) then begin // есть выбор
      if pool[list2[i]].weight>pool[list2[j]].weight then begin
       list1[c]:=list2[i]; inc(i);
      end else begin
       list1[c]:=list2[j]; inc(j);
      end;
     end else // выбора нет
     if (i<=v) then begin
      list1[c]:=list2[i]; inc(i);
     end else begin
      list1[c]:=list2[j]; inc(j);
     end;
    end;
   end;
  end;

begin
 LogMessage('FreeVidMem called',2);
 try
 with data as TextureManData do begin
  if (FreeIndCnt=960) and (UsedMetaInd=0) then exit; // нечего удалять

  // ВАЖНО! При освобождении ресурса нужно выполнить циклическую замену в массиве свободных индексов
  // A - позиция, где лежит индекс свободного для использования элемента
  // B - позиция, где лежит индекс первого из занятых элементов (B всегда равен A+1)
  // C - позиция, где лежит индекс элемента, который нужно освободить
  // A -> B, B -> C, C -> A
  // Это необходимо для того, чтобы можно было легально изменить указатель кол-ва занятых эл-тов

  // Построим список индексов ресурсов
  indCnt:=0;
  for i:=FreeIndCnt+1 to 960 do begin
   list1[indcnt]:=FreeInd[i];
   inc(indcnt);
  end;
  for i:=1 to UsedMetaInd do begin
   list1[indcnt]:=MetaInd[i];
   inc(indcnt);
  end;
  if indCnt>1 then begin
   // Отсортируем выделенные ресурсы (по весу).
   Sort(0,indCnt-1);
  end;
  volume:=MemUsed div 4+MemLimit div 16+256*1024;
  if volume>memLimit div 6 then volume:=MemLimit div 6;
  // Теперь начнем освобождать текстуры пока не освободится заданный объем
  av:=0;
  for i:=indcnt-1 downto 0 do begin
   ind:=list1[i];
   if ind<64 then begin // Сначала освободим элементы в метатекстуре
    for j:=0 to UsageMaps[ind].texCnt-1 do with UsageMaps[ind].textures[j] do begin
     allocated:=false;
     online:=false;
     texture:=nil;
    end;
   end else with pool[ind].texture do begin
    allocated:=false;
    online:=false;
    texture:=nil;
   end;
   pool[ind].tex:=nil;
   dec(MemUsed,pool[ind].memsize);
   // Теперь выполним циклическую замену индексов...
   if ind<64 then begin
    // ...в массиве индексов метатекстур
    for j:=1 to UsedMetaInd+1 do
     if MetaInd[j]=ind then break;
    Assert(j<UsedMetaInd+1,'No meta index found!');
    v:=MetaInd[UsedMetaInd];
    MetaInd[UsedMetaInd]:=MetaInd[UsedMetaInd+1];
    MetaInd[UsedMetaInd+1]:=MetaInd[j];
    MetaInd[j]:=v;
    dec(usedMetaInd);
    pool[ind].used:=false;
    LogMessage('Deleting metatexture - '+inttostr(ind),2);
   end else begin
    // ...в массиве индексов полных текстур
    for j:=FreeIndCnt+1 to 961 do
     if FreeInd[j]=ind then break;
    if j>960 then begin
     ForceLogMessage('FreeTexMemSpace: index not found - '+inttostr(ind));
     Dump('FTMS - no index');
    end;
    Assert(j<961,'No index found!');
    v:=FreeInd[FreeIndCnt];
    FreeInd[FreeIndCnt]:=FreeInd[j];
    FreeInd[j]:=freeInd[FreeIndCnt+1];
    FreeInd[FreeIndCnt+1]:=v;
    inc(FreeIndCnt);
    pool[ind].used:=false;
   end;
   inc(av,pool[ind].memsize);
   if av>volume then break;
  end;
 end;
 except
  on e:exception do raise EError.Create('texman.FWM '+e.message);
 end;
end;

function TDxTextureMan.GetStatus(line: byte): string;
begin
 with data as TextureManData do
  case line of
   1:result:='MemUsage: '+IntToStr(MemUsed)+' of '+inttostr(MemLimit);
   2:result:='Used meta: '+IntToStr(UsedMetaInd)+', tex: '+inttostr(960-FreeIndCnt);
  end;
end;

procedure TDxTextureMan.MakeOnline(img: TTexture);
var
 desc:TD3DSurfaceDesc;
 i,j,ind,part:integer;
 p:TPoint;
 r:TRect;
 surf,dest:IDirect3DSurface8;
 tries,res:integer;
 format:cardinal;
 rating:array[1..64] of integer;
 bestVal,bestInd,BestPart,AbsBestPart,curVal,v,w,h:integer;
 bias_w,bias_h:single;
 lr,lr2:TD3DLockedRect;
 f:file;
 image:TDxManagedTexture;

 function NextStage:boolean;
  begin
   ForceLogMessage('Free vidmem for next stage');
   FreeVidMem;
   dec(tries);
   result:=tries<=0;
  end;

begin
 try
 EnterCriticalSection(crSect);
 try
 image:=img as TDXManagedTexture;
 if image.online then begin
  // Update weight
  image.tag:=CurTag; inc(CurTag);
  ind:=image.handle;
  with data as TextureManData do pool[Ind].weight:=Pool[Ind].width*0.9+0.1*CurTag;
  exit;
 end;
 if image.caps and (tfSysmemOnly)>0 then exit;

 format:=GetD3DFormat(image.PixelFormat);
 tries:=4;
 if not image.allocated then with data as TextureManData do repeat
  // Allocate image in VideoMem
  if image.caps and tfTexture>0 then begin // 1-st case - allocate whole texture
   if FreeIndCnt<=0 then continue;
   ind:=FreeInd[FreeIndCnt];
   with pool[ind] do begin
    width:=image.trueWidth;
    height:=image.trueHeight;
    PixelFormat:=format;
    caps:=image.caps;
    mipmaps:=image.mipmaps;
    texture:=image;
    weight:=-1;
    bias_w:=0.5/width;
    bias_h:=0.5/height;
   end;
   res:=CreateTextureByDescriptor(pool[ind]);
   if (res<0) and (res<>D3DERR_OUTOFVIDEOMEMORY) then
    raise EError.Create('DxTexMan: Cannot create texture - '+DXGErrorString(res));
   if res<0 then continue; // Освободить немного памяти
   dec(FreeIndCnt);
   image.handle:=ind; // Положение в pool'е
   image.allocated:=true;
   image.u1:=0; image.u2:=1;
   image.v1:=0; image.v2:=1;
   image.stepU:=bias_w;    image.stepV:=bias_h;
   image.texture:=pool[ind].tex;
   image.tag:=CurTag; inc(CurTag);
   pool[ind].weight:=CurTag;
   pool[ind].used:=true;
   break; // Все успешно завершилось
  end;
  // Теперь второй возможный случай - нужно оценить метатекстуры. Оценка метатекстуры -
  // это наивысшая оценка среди оценок ее прямоугольников
  bestval:=-1000000; bestind:=-1; AbsBestPart:=-1;
  for i:=1 to UsedMetaInd do begin
   ind:=MetaInd[i];
   if pool[ind].PixelFormat<>format then continue;  // Если формат не совпадает - облом
   curval:=-1000; BestPart:=-1;
   with usageMaps[ind] do
    if (RectCnt>=16) or (TexCnt>=32) then continue // Нельзя добавить текстуру
    else
    for part:=0 to rectCnt-1 do begin
     w:=rects[part].Right-rects[part].Left;
     h:=rects[part].bottom-rects[part].top;
     if (w=image.width) and (h=image.height) then begin
      curval:=10000; // заведомо оптимальный вариант
      BestPart:=part;
      break;
     end;
     if ((w=image.width) and (h>image.height)) or
         ((h=image.height) and (w>image.width)) then begin
      curval:=5000; // уменьшится не могло, т.к. больше - только идеал, а если бы он был найден - то сюда бы не попали
      BestPart:=part;
      continue;
     end;
     if curval>=5000 then continue;
     if (w>image.width) and (h>image.height) then begin
      v:=4999-(w-image.width)-(h-image.height)-round((CurTag-pool[ind].weight)*0.1);
      if v>CurVal then begin
       curval:=v; BestPart:=part;
      end;
     end;
    end;
   // Итак, посмотрим что получилось
   if curval>BestVal then begin
    bestind:=ind; BestVal:=curval;
    AbsBestPart:=BestPart;
   end;
  end; // конец цикла оценки метатекстур

  if BestVal<=0 then begin
   // Подходящей метатекстуры не нашлось -> попробуем создать новую
   if UsedMetaInd>=63 then continue; // все метатекстуры заняты
   ind:=MetaInd[UsedMetaInd+1];
   with pool[ind] do begin
    width:=image.MTWidth;
    height:=image.MTheight;
    PixelFormat:=format;
    caps:=image.caps;
    mipmaps:=image.mipmaps;
    texture:=nil;
    used:=true;
   end;
   res:=CreateTextureByDescriptor(pool[ind]);
   if (res<0) and (res<>D3DERR_OUTOFVIDEOMEMORY) then
    raise EError.Create('DxTexMan: Cannot create texture - '+DXGErrorString(res));
   if res<0 then continue; // Нет памяти -> на следующую итерацию
   with UsageMaps[ind] do begin
    rectCnt:=1;  TexCnt:=0;
    rects[0].Left:=0; rects[0].Top:=0;
    rects[0].Right:=image.MTWidth;
    rects[0].Bottom:=image.MTheight;
   end;
   inc(UsedMetaInd);
   LogMessage('MO: metatexture created - '+inttostr(ind)+' for '+inttohex(cardinal(img) div 16 mod 65536,4),2);
   BestVal:=1;
   if (image.width=image.MTWidth) or (image.height=image.mtHeight) then bestval:=5000;
   if (image.width=image.MTWidth) and (image.height=image.mtHeight) then bestval:=10000;
   BestInd:=ind;
   AbsBestPart:=0;
  end;

  if BestVal>0 then begin // Найдена подходящая метатекстура - юзаем ее
   with pool[bestind] do begin
    if tex=nil then begin // Текстура была освобождена
     CreateTextureByDescriptor(pool[bestind]);
    end;
    bias_w:=0.5/width;
    bias_h:=0.5/height;
   end;
   with UsageMaps[bestind] do begin
    case BestVal of
     10000:begin // Прямоугольник занимается целиком
            with rects[AbsBestPart] do begin
             image.left:=Left; image.top:=top;
            end;
            dec(RectCnt);
            rects[AbsBestPart]:=rects[rectCnt];
           end;
      5000:begin // Откусывается кусок либо слева либо сверху
            with rects[AbsBestPart] do begin
             w:=right-left; {h:=bottom-top;}
             image.left:=Left; image.top:=top;
             if w=image.width then inc(top,image.height)
              else inc(left,image.width);
            end;
           end;
      else begin // Откусывается угол слева сверху
            rects[rectcnt]:=rects[AbsBestPart];
            with rects[AbsBestPart] do begin
             image.left:=Left; image.top:=top;
             w:=right-left; h:=bottom-top;
             if (w-image.width)>=(h-image.height) then begin
              // малый прямоугольник справа плюс все остальное снизу
              inc(rects[rectcnt].top,image.height);
              inc(left,image.width); bottom:=top+image.height;
             end else begin
              // малый прямоугольник снизу плюс все остальное справа
              inc(rects[rectcnt].left,image.width);
              inc(top,image.height); right:=left+image.width;
             end;
            end;
            inc(RectCnt);
           end;
    end;
    textures[texcnt]:=image;
    inc(TexCnt);
   end;

   image.allocated:=true;
   image.u1:=image.left*2*bias_w;
   image.u2:=(image.left+image.width)*2*bias_w;
   image.v1:=(image.top*2)*bias_h;
   image.v2:=(image.top+image.height)*2*bias_h;
   image.stepU:=bias_w;    image.stepV:=bias_h;
   image.texture:=pool[bestind].tex;
   image.handle:=BestInd;
   image.tag:=CurTag; inc(CurTag);
   pool[BestInd].weight:=Pool[BestInd].width*0.7+0.3*CurTag;
   break;
  end;

 until NextStage;

 if not image.allocated then begin// Несмотря на все - не удалось выделить память
  Dump('Failed to allocate image in vidmem');
  raise EError.Create('DxTexMan: Failed to allocate image in VidMem');
 end;

 // Move image data to VidMem (if applicable)
 if image.caps and (tfVidMemOnly+tfSysMemOnly)=0 then with image do
  if SysMemTex<>nil then begin
//   sysmemtex.AddDirtyRect(nil);
   DxCall(device.UpdateTexture(SysMemTex,texture));
  end else begin
   image.texture.GetSurfaceLevel(0,dest);
   Assert(dest<>nil);
{   if image.PixelFormat in [ipfDXT1..ipfDXT3] then begin
    // сжатые форматы копируются вручную
    if image.PixelFormat=ipfDXT1 then j:=width*2
     else j:=width*4;
    r:=Rect(left,top,left+width,top+height);
    sysmemimage.LockRect(lr,nil,0);
    DxCall(dest.LockRect(lr2,@r,0));
    for i:=1 to height div 4 do begin
     move(lr.PBits^,lr2.pbits^,j);
     inc(cardinal(lr.PBits),lr.Pitch);
     inc(cardinal(lr2.pBits),lr2.Pitch);
    end;
    dest.UnlockRect;
    sysmemimage.UnlockRect;
   end else} begin
    // копирование данных средствами D3D
    p:=Point(left,top);
    r:=Rect(0,0,width,height);
    // Здесь можно было бы добавить поддержку DIRTY RECTS, но как-то лениво, ибо нигде не нужно
    DxCall(device.CopyRects(SysMemImage,@r,1,dest,@p));
   end;
  end;
 image.online:=true;
 finally
  LeaveCriticalSection(crSect);
 end;
 except
  on e:exception do
   raise EError.Create('MakeOnline of '+img.name+' ('+inttohex(cardinal(img) div 16 mod 65536,4)+
    '): '+e.Message);
 end;
end;

function TDxTextureMan.QueryParams(width,height:integer;format:ImagePixelFormat;
  aiFlags: integer): boolean;
var
 usage,resType:cardinal;
begin
 result:=false;
 usage:=0;
 if aiFlags and aiRenderTarget>0 then usage:=D3DUSAGE_RENDERTARGET;
 resType:=D3DRTYPE_TEXTURE;
 if aiFlags and aiSysMem>0 then resType:=D3DRTYPE_SURFACE;
 if d3d.CheckDeviceFormat(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,params.BackBufferFormat,usage,
    resType,GetD3DFormat(format))<>D3D_OK then exit;

 if (width<>GetPow2(width)) or (height<>GetPow2(height)) then begin
  if CAPS.TextureCaps and D3DPTEXTURECAPS_POW2>0 then exit;
  if format in [ipfDXT1,ipfDXT2,ipfDXT3,ipfDXT5] then exit;
 end;
 if (width<>height) and (CAPS.TextureCaps and D3DPTEXTURECAPS_SQUAREONLY>0) then exit;
 result:=true;
end;

procedure TDxTextureMan.ReCreateAll;
{var
 i,j,ind,res:integer;}
begin
{ with data as TextureManData do begin
  for i:=FreeIndCnt+1 to 960 do begin // Воссоздать цельную текстуру
   ind:=FreeInd[i];
   if pool[ind].tex<>nil then continue;
   res:=CreateTextureByDescriptor(pool[ind]);
   pool[ind].texture.texture:=pool[ind].tex;
   pool[ind].texture.allocated:=true;
  end;
  for i:=1 to UsedMetaInd do begin // По всем метатекстурам
   ind:=MetaInd[i]; // индекс метатекстуры в pool'е
   if pool[ind].tex<>nil then continue;
   res:=CreateTextureByDescriptor(pool[ind]);
   inc(memUsed,pool[ind].memsize);
   for j:=1 to UsageMaps[ind].texCnt do // по всем текстурам в данной метатекстуре
    with usageMaps[ind].textures[j] do begin
     texture:=pool[ind].tex;
     allocated:=true;
     online:=false;
    end;
  end;
 end;}
end;

procedure TDxTextureMan.ReleaseAll;
var
 i,j,ind:integer;
begin
 try
 LogMessage('ReleaseAll',2);
 with data as TextureManData do begin
  for i:=FreeIndCnt+1 to 960 do begin // Освободить текстуру (но не дескриптор!)
   ind:=FreeInd[i];
   pool[ind].tex:=nil;
   pool[ind].texture.texture:=nil;
   pool[ind].texture.allocated:=false;
   pool[ind].texture.online:=false;
  end;
  for i:=1 to UsedMetaInd do begin // По всем метатекстурам
   ind:=MetaInd[i]; // индекс метатекстуры в pool'е
   pool[ind].tex:=nil;
   for j:=0 to UsageMaps[ind].texCnt-1 do // по всем текстурам в данной метатекстуре
    with usageMaps[ind].textures[j] do begin
     texture:=nil;
     allocated:=false;
     online:=false;
    end;
  end;
  MemUsed:=0;
  FreeIndCnt:=960;
  for i:=1 to FreeIndCnt do FreeInd[i]:=i+63;
  UsedMetaInd:=0;
  for i:=1 to 64 do MetaInd[i]:=i-1;
  for i:=0 to 1023 do
   fillchar(pool[i],sizeof(pool[i]),0);
 end;
 except
  on e:exception do raise EError.Create('Texman RO: '+e.message);
 end;
end;

{ TDxManagedImage8 }

procedure TDxManagedTexture.AddDirtyRect(rect: TRect);
begin
 if sysMemTex<>nil then
  DxCall(SysMemTex.AddDirtyRect(@rect))
 else
  raise EWarning.Create('ADR not supported on custom managed textures');
 online:=false; 
end;

constructor TDxManagedTexture.Create;
begin
 inherited;
 online:=false; allocated:=false; locked:=0;
 SysMemTex:=nil; SysMemImage:=nil; texture:=nil;
end;

destructor TDxManagedTexture.Destroy;
begin
 SysMemImage:=nil;
 SysMemTex:=nil;
 texture:=nil;
 inherited;
end;

procedure TDxManagedTexture.GenerateMipMaps(count:byte);
begin

end;

function TDxManagedTexture.GetRawImage: TRawImage;
begin
 result:=nil;
 if locked=0 then raise EError.Create('Texture not locked!');
 result:=TRawImage.Create;
 result.PixelFormat:=PixelFormat;
 result.data:=data;
 result.pitch:=pitch;
 result.width:=width;
 result.height:=height;
 if PixelFormat in [ipfDXT1..ipfDXT5] then begin
  result.width:=(width+3) div 4;
  result.height:=(height+3) div 4;
 end;
 result.paletteFormat:=palNone;
 result.palSize:=0;
 result.palette:=nil;
end;

function TDxManagedTexture.GetSurface: IDirect3DSurface8;
begin
 if SysMemTex<>nil then sysMemTex.GetSurfaceLevel(0,result)
  else result:=sysMemImage;
end;

procedure TDxManagedTexture.Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;r:PRect=nil);
var
 lr:TD3DLockedRect;
 re:TRect;
 res:integer;
 flags:cardinal;
begin
 if locked=0 then begin
 ASSERT((SysMemTex<>nil) or (SysMemImage<>nil));
 if r=nil then
  re:=Rect(0,0,trueWidth shr mipLevel,trueHeight shr miplevel)
 else
  re:=r^;
 flags:=D3DLOCK_NOSYSLOCK+D3DLOCK_READONLY*byte(mode=lmReadOnly)+D3DLOCK_NO_DIRTY_UPDATE*byte(mode=lmCustomUpdate);
 if SysMemTex<>nil then
  res:=SysMemTex.LockRect(miplevel,lr,@re,flags)
 else
  res:=SysMemImage.LockRect(lr,@re,flags);
 if res<0 then
  raise EWarning.Create('Can''t lock surface');
 data:=lr.pBits;
 pitch:=lr.Pitch;
 end;
 inc(locked);
 level:=miplevel;
 if mode=lmReadWrite then online:=false;
end;

procedure TDxManagedTexture.LockNext;
begin
 ASSERT(locked>0);
 Unlock;
 Lock(level+1);
end;

procedure TDxManagedTexture.Unlock;
begin
 ASSERT(locked>0);
 if locked=1 then begin
  if SysMemTex<>nil then
   SysMemTex.UnlockRect(level)
  else
   SysMemImage.UnlockRect;
 end;
 dec(locked);
end;

{ TDxTexture }

constructor TDxTexture.Create;
begin
 texture:=nil;
end;

destructor TDxtexture.Destroy;
begin
 texture:=nil;
 Inherited;
end;

procedure TDxTexture.SetAsRenderTarget;
var
 surf,zbuf:IDirect3DSurface8;
 desc:TD3DSurface_Desc;
begin
 if device=nil then exit;
 if texture=nil then raise EError.Create('SART: Texture is nil!');
 DxCall(texture.GetSurfaceLevel(0,surf));
 surf.GetDesc(desc);
 if desc.Usage<>1 then exit;
 device.GetDepthStencilSurface(zbuf);
 DxCall(device.SetRenderTarget(surf,zbuf));
end;

begin
end.
