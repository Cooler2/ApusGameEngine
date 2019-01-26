// Copyright (C) Apus Software, 2012-2014. Ivan Polyacov (ivan@apus-software.com)
// 2D-cache methods for font glyph caching
unit glyphCaches;
interface
 uses types,structs;

type
 // Item of text cache area
 TGlyphCacheBlock=record
  x,y:smallint;
  hNext:smallint; // ссылка на следующий блок с тем же значением хэша
  hashAndKind:word;
  chardata:cardinal;
  timestamp:cardinal;
 end;

 TGlyphInfoRec=record
  x,y:integer;  // glyph position
  width,height:integer; // glyph dimension
  dx,dy:integer; // glyph position relative to output (cursor) point
 end;

 // Абстрактный интерфейс для кэширования глифов или других мелких картинок в одной большой текстуре
 TGlyphCache=class
  lastTimeStamp:cardinal;
  relX,relY:integer; // положение, относительно которого возвращаются результаты
  // находит положение в текстуре, соответствующее символу, либо -1,-1 - если его нет
  function Find(chardata:cardinal):TGlyphInfoRec; virtual; abstract;
  // выделяет блок заданного размера для заданного символа, возвращает его положение
  function Alloc(width,height,dx,dy:integer;chardata:cardinal):TPoint; virtual; abstract;
  // Keep all blocks found from this moment from deletion
  procedure Keep; virtual; abstract;
  // Allow further deletion of any blocks
  procedure Release; virtual; abstract;
 end;

 // ПРИНЦИП РАБОТЫ: весь кэш (размером 512x512, 1024x512 либо 2048x512) заранее разбит на полосы, где каждая полоса
 // состоит из блоков заранее фиксированного размера (например 24x16). Работа кэша заключается в выделении блоков
 // подходящего размера или поиске уже выделенных блоков
 // ЭТА СТРУКТУРА НЕЭФФЕКТИВНА ДЛЯ FT-ШРИФТОВ И ПОЭТОМУ БОЛЬШЕ НЕ ИСПОЛЬЗУЕТСЯ
 TFixedGlyphCache=class(TGlyphCache)
  constructor Create(width:integer); 
  destructor Destroy; override;
  // находит положение в текстуре, соответствующее символу, либо -1,-1 - если его нет
  function Find(chardata:cardinal):TGlyphInfoRec; override;
  // выделяет блок заданного размера для заданного символа, возвращает его положение
  function Alloc(width,height,dx,dy:integer;chardata:cardinal):TPoint; override;
  // Keep all blocks found from this moment from deletion
  procedure Keep; override;
  // Allow further deletion of any blocks
  procedure Release; override;
 private
  keepTimeStamp:cardinal;
  blocks:array[0..3999] of TGlyphCacheBlock; // данные о всех блоках
  // списки свободных блоков каждого типа
  freeList:array[0..3999] of smallint;
  freeCount:array[1..15] of integer;
  hash:array[0..4095] of smallint; // указатель на начало списка блоков с заданным хэшем
  function GetBestKind(w,h:integer):integer; // возвращает ближайший "совместимый" тип блока
  procedure FreeBlock(block,kind:integer);
  procedure FreeSpace(kind:integer); // освобождает блоки заданного типа
  function GetBlockPos(block:cardinal):TPoint;
  procedure DecrementTimes; // уменьшает все timestampы (для ооочень долгой работы)
 end;

 TBandData=record
  y,height:integer; // положение полосы (height=0 - free)
  next:integer; // номер следующей полосы
  freeSpace:integer; // сколько свободно
 end;

 // ПРИНЦИП РАБОТЫ: все пространство (размером от 512x512 до 1024x1024) представляет собой кэш из кэшей т.е. набор полос,
 // где каждая полоса работает как отдельный кэш. Ключевая особенность: элементы добавляются только в конец полосы,
 // если места не хватает - выделяется новая полоса, удаление происходит только целыми полосами.
 // Поэтому Keep() гарантирует, что значительная часть кэша свободна, чтобы не пришлось удалять полосы с нужными элементами.
 // Максимальный размер элемента - 63x63
 TDynamicGlyphCache=class(TGlyphCache)
  constructor Create(width,height:integer);
  destructor Destroy; override;
  // находит положение в текстуре, соответствующее символу, либо -1,-1 - если его нет
  function Find(chardata:cardinal):TGlyphInfoRec; override;
  // выделяет блок заданного размера для заданного символа, возвращает его положение
  function Alloc(width,height,dx,dy:integer;chardata:cardinal):TPoint; override;
  // Keep all blocks found from this moment from deletion
  procedure Keep; override;
  // Allow further deletion of any blocks
  procedure Release; override;
  // How efficient space is used (0..1)
  function Usage:single;
 private
  aWidth,aHeight:integer; // Общий размер пространства кэша
  freeMin,freeMax:integer; // границы свободной области (freeMax может ыть больше aHeight, что означает разрывную область) 
  // Полосы (список)
  bands:array[0..99] of TBandData;
  bCount:integer;
  firstBand,lastBand:integer;
  // Блоки
  hash1,hash2:TSimpleHash;
  function CanCreateBand(height:integer):boolean;
  function CreateNewBand(height:integer):integer;
  procedure FreeOldBand;
 end;

implementation
 uses SysUtils,MyServis;

 const
  // стартовый номер блоков каждого типа
  cacheItemTypes:array[1..15] of integer=
   (0,2560,512,1024,3328,1536,2048,3584,2304,2816,3712,3072,3456,3776,3840);

  // начало полосы блоков каждого типа
  cacheItemY:array[1..15] of integer=
   (0,16,24,48,72,84,116,148,164,212,260,284,348,412,444);

  // кол-во элементов каждого типа: начальные значения из расчета, что ширина текстуры - 2048
  cacheItemCount:array[1..15] of integer=
   (512,168,512,340,128,340,256,85,256,168,64,168,128,42,64);

  cacheItemSizes:array[1..15,0..1] of byte=
   ((8,8),(12,8),(8,12),(12,12),
    (16,12),(12,16),(16,16),(24,16),
    (16,24),(24,24),(32,24),(24,32),
    (32,32),(48,32),(32,48));

{ TGlyphCache }
// хэш - 0..4095
function GlyphHash(chardata: cardinal): cardinal; inline;
begin
 result:=(charData xor (chardata shr 8)) and $FFF;
end;

function TFixedGlyphCache.Alloc(width, height,dx,dy: integer; chardata: cardinal): TPoint;
var
 i,j,kind,block,h:integer;
begin
 // Определить тип блока
 kind:=0;
 if height<=16 then begin
  if height<=12 then begin
   if height<=8 then begin
    // W x 8
    if width<=8 then kind:=1 else
    if width<=12 then kind:=2 else
    if width<=16 then kind:=5 else
    if width<=24 then kind:=8 else
    if width<=32 then kind:=11 else kind:=14;
   end else begin
    // W x 12
    if width<=8 then kind:=3 else
    if width<=12 then kind:=4 else
    if width<=16 then kind:=5 else
    if width<=24 then kind:=8 else
    if width<=32 then kind:=11 else kind:=14;
   end;
  end else begin
   // W x 16
   if width<=12 then kind:=6 else
   if width<=16 then kind:=7 else
   if width<=24 then kind:=8 else
   if width<=32 then kind:=11 else kind:=14;
  end;
 end else begin
  // height>16
  if height<=24 then begin
   if width<=16 then kind:=9 else
   if width<=24 then kind:=10 else
   if width<=32 then kind:=11 else kind:=14;
  end else
  if height<=32 then begin
   if width<=24 then kind:=12 else
   if width<=32 then kind:=13 else kind:=14;
  end else kind:=15;
 end;
 if (width>cacheItemSizes[kind,0]) or
    (height>cacheItemSizes[kind,1]) then
   raise EWarning.Create('Cache block is too large: '+IntToStr(width)+','+IntToSTr(height));
 if kind=0 then
  raise EError.Create('Invalid block type '+inttostr(width)+'x'+inttostr(height));
 if freeCount[kind]=0 then begin
  FreeSpace(kind);
  if freeCount[kind]=0 then begin // освобождение не помогло?
   kind:=GetBestKind(width,height);
   if kind<0 then raise EWarning.Create('Block cache overflow');
  end;
 end;

 dec(freeCount[kind]);
 block:=freeList[cacheItemTypes[kind]+freeCount[kind]];
 if blocks[block].chardata<>0 then
  Assert(false);
 h:=GlyphHash(chardata);
 if hash[h]=block then
  Assert(false);
 blocks[block].hNext:=hash[h];
 hash[h]:=block;
 blocks[block].hashAndKind:=h+kind shl 12;
 blocks[block].chardata:=chardata;
 blocks[block].timestamp:=lastTimeStamp;
 inc(lastTimeStamp);
 result:=GetBlockPos(block);
end;

constructor TFixedGlyphCache.Create(width:integer);
var
 i,j,cnt:integer;
 p:TPoint;
begin
 LastTimeStamp:=1;
 keepTimeStamp:=0;
 relX:=0; relY:=0;
 for i:=1 to 15 do begin
  if Width=1024 then cacheItemCount[i]:=cacheItemCount[i] div 2;
  if Width=512 then cacheItemCount[i]:=cacheItemCount[i] div 4;
  cnt:=cacheItemCount[i];
  freeCount[i]:=cnt;
  // инициализация блоков типа i
  for j:=cacheItemTypes[i] to cacheItemTypes[i]+cnt-1 do begin
   p:=GetBlockPos(j);
   blocks[j].x:=p.x;
   blocks[j].y:=p.y;
   blocks[j].hNext:=-1;
   blocks[j].timestamp:=0;
   blocks[j].chardata:=0; // free block
   freeList[j]:=j;
  end;
 end;

 // hash
 for i:=0 to 4095 do hash[i]:=-1;
end;

procedure TFixedGlyphCache.DecrementTimes;
var
 i,j,start,cnt:integer;
begin
 // деление на 2 не нарушает целостность данных
 lastTimeStamp:=lastTimeStamp div 2;
 keepTimeStamp:=keepTimeStamp div 2;
 for i:=1 to 15 do begin
  start:=cacheItemTypes[i];
  cnt:=cacheItemCount[i];
  for j:=start to start+cnt-1 do
   blocks[j].timestamp:=blocks[j].timestamp div 2;
 end;
end;

destructor TFixedGlyphCache.Destroy;
begin
end;

function TFixedGlyphCache.Find(chardata: cardinal): TGlyphInfoRec;
var
 h,hsh:integer;
 cnt:integer;
begin
 hsh:=GlyphHash(charData);
 h:=hash[hsh]; // номер первого блока с искомым хэшем
 cnt:=0;
 while (h>=0) and (blocks[h].chardata<>charData) do begin
  h:=blocks[h].hNext;
  inc(cnt);
  if cnt>100 then
   Assert(false);
 end;
 if h>=0 then begin
  result.x:=relX+blocks[h].x;
  result.y:=relY+blocks[h].y;
  blocks[h].timestamp:=lastTimeStamp;
  inc(lastTimeStamp);  
  if lastTimeStamp>$70000000 then DecrementTimes;
 end else begin
  result.x:=-1;
  result.y:=-1;
 end;
end;

procedure TFixedGlyphCache.FreeBlock(block,kind: integer);
var
 h,prv:integer;
begin
 ASSERT(blocks[block].chardata<>0); // Don't free block which is already free
 h:=GlyphHash(blocks[block].chardata);
 if blocks[block].hashAndKind<>kind shl 12+h then
  Assert(false);
 if hash[h]=block then
  hash[h]:=blocks[block].hNext // удаление первого эл-та списка
 else begin
  // удаление из односвязного списка не первого эл-та
  prv:=hash[h];
  h:=blocks[prv].hNext;
  while (h>=0) and (h<>block) do begin
   prv:=h; h:=blocks[h].hNext;
  end;
  if h<0 then raise EError.Create('Block is not in hash! '+inttostr(block));
  assert(blocks[h].hNext<>prv);
  blocks[prv].hNext:=blocks[h].hNext;
 end;
 blocks[block].chardata:=0;
 blocks[block].hNext:=-1;
 freeList[cacheItemTypes[kind]+freeCount[kind]]:=block;
 inc(freeCount[kind]);
end;

procedure TFixedGlyphCache.FreeSpace(kind: integer);
var
 i,cnt,start,c:integer;
 min,max,threshold,step:cardinal;
begin
 start:=cacheItemTypes[kind];
 cnt:=cacheItemCount[kind];
 min:=$FFFFFFFF; max:=0; c:=0;
 for i:=start to start+cnt-1 do begin
  if blocks[i].timestamp<min then min:=blocks[i].timestamp;
  if blocks[i].timestamp>max then max:=blocks[i].timestamp;
  if blocks[i].timestamp<keepTimeStamp then inc(c); // сколько блоков доступно для удаления
 end;
 step:=(max-min) div 4;
 threshold:=min+step;
 if threshold>keepTimeStamp then threshold:=keepTimeStamp;
 repeat
  for i:=start to start+cnt-1 do
   if (blocks[i].chardata<>0) and
      (blocks[i].timestamp<=threshold) then FreeBlock(i,kind);
  inc(threshold,step);
 until (freeCount[kind]>=cnt div 4) or (threshold>keepTimeStamp);
end;

function TFixedGlyphCache.GetBlockPos(block: cardinal): TPoint;
begin
 result.x:=-1;
 result.y:=-1;
 case block shr 7 of
  0,1,2,3:begin
    // type 1: 8x8
    result.x:=(block and $FFFE) shl 2;
    result.y:=(block and 1) shl 3;
  end;
  4,5,6,7:begin
    // type 3: 8x12
    dec(block,512);
    result.x:=(block and $FFFE) shl 2;
    result.y:=24+12*(block and 1);
  end;
  8,9,10:begin
    // type 4: 12x12
    dec(block,1024);
    result.x:=12*(block shr 1);
    result.y:=48+12*(block and 1);
  end;
  12,13,14:begin
    // type 6: 12x16
    dec(block,1536);
    result.x:=12*(block shr 1);
    result.y:=84+(block and 1) shl 4;
  end;
  16,17:begin
    // type 7: 16x16
    dec(block,2048);
    result.x:=16*(block shr 1);
    result.y:=116+(block and 1) shl 4;
  end;
  18,19:begin
    // type 9: 16x24
    dec(block,128*18);
    result.x:=16*(block shr 1);
    result.y:=164+24*(block and 1);
  end;
  20,21:begin
    // type 2: 12x8
    dec(block,128*20);
    result.x:=12*block;
    result.y:=16;
  end;
  22,23:begin // 2816
    // type 10: 24x24
    dec(block,128*22);
    result.x:=24*(block shr 1);
    result.y:=212+24*(block and 1);
  end;
  24,25:begin // 3072
    // type 12: 24x32
    dec(block,128*24);
    result.x:=24*(block shr 1);
    result.y:=284+(block and 1) shl 5;
  end;
  26:begin // 3328
    // type 5: 16x12
    dec(block,128*26);
    result.x:=16*block;
    result.y:=72;
  end;
  27:begin // 3456
    // type 13: 32x32
    dec(block,128*27);
    result.x:=32*(block shr 1);
    result.y:=348+(block and 1) shl 5;;
  end;
  28:begin // 3584
    // type 8: 24x16
    dec(block,128*28);
    result.x:=24*block;
    result.y:=148;
  end;
  29:begin // 3712
    if block<3776 then begin
     // type 11: 32x24
     dec(block,128*29);
     result.x:=32*block;
     result.y:=260;
    end else begin
     // type 14: 48x32
     dec(block,128*29+64);
     result.x:=48*block;
     result.y:=412;
    end;
  end;
  30:begin // 3840
    // type 8: 32x48
    dec(block,128*30);
    result.x:=32*block;
    result.y:=444;
  end;
 end;
end;

function TFixedGlyphCache.GetBestKind(w,h:integer): integer;
var
 i,max:integer;
begin
 result:=-1; max:=0;
 for i:=15 downto 1 do
  if (cacheItemSizes[i,0]>=w) and (cacheItemSizes[i,1]>=h) then
   if freeCount[i]>max then begin
    result:=i; max:=freeCount[i];
   end;
end;

procedure TFixedGlyphCache.Keep;
begin
 keepTimeStamp:=lastTimeStamp;
end;

procedure TFixedGlyphCache.Release;
begin
 keepTimeStamp:=0;
end;

{ TDynamicGlyphCache }

function TDynamicGlyphCache.Alloc(width, height,dx,dy: integer;
  chardata: cardinal): TPoint;
var
 i,best,bandHeight:integer;
 r:cardinal;
begin
 // 1. Find the most suitable band
 i:=firstBand; best:=-1; r:=1000; bandHeight:=0;
 while i>=0 do begin
  if (bands[i].height>=height) and
     (bands[i].freeSpace>=width) and
     (bands[i].height-height<r) then begin
   best:=i; r:=bands[i].height-height;
  end;
  if (bands[i].freeSpace>32+width*2) and
     (bands[i].height<height) and
     (bands[i].height>bandHeight) then bandHeight:=bands[i].height;
  i:=bands[i].next;
 end;
 // 2 случая, когда нужно создать новую полосу:
 // а) подходящей полосы, где можно разместить элемент - нет
 if best<0 then begin
  // Полоса должна быть хотя бы на 25% толще, чем существующая более-менее свободная полоса 
  bandHeight:=bandHeight+1+bandHeight div 4;
  if height>bandHeight then bandHeight:=height;
 end;
 // б) подходящая полоса есть, но она намного выше элемента, а свободного места еще много. Создаем более тонкую полосу
 if (best>=0) and
    (r>1+bands[best].height shr 2) and
    CanCreateBand(height*3) then begin
  best:=-1; // Вот тут стоит избегать создания полос, которые "чуть-чуть" больше имеющихся свободных
  bandHeight:=bandHeight+1+bandHeight div 4;
  if height>bandHeight then bandHeight:=height;
//  bandHeight:=height;
 end;
 // New band required?
 if best<0 then
   best:=CreateNewBand(bandHeight);
 // Add item
 result.y:=bands[best].y;
 result.x:=aWidth-bands[best].freeSpace;
 dec(bands[best].freeSpace,width);
 r:=byte(width)+byte(height) shl 8+byte(dx+128) shl 16+byte(dy+128) shl 24;
 hash1.Put(chardata,r);
 r:=result.Y shl 16+result.x;
 hash2.Put(chardata,r);
end;

constructor TDynamicGlyphCache.Create(width, height: integer);
begin
 aWidth:=width;
 aHeight:=height;
 freeMin:=0;
 freeMax:=height-1;
 hash1.Init(4000);
 hash2.Init(4000);
 bCount:=0;
 firstBand:=-1; lastBand:=-1;
 relX:=0; relY:=0;
end;

destructor TDynamicGlyphCache.Destroy;
begin
 inherited;
end;

function TDynamicGlyphCache.Find(chardata: cardinal): TGlyphInfoRec;
var
 r:int64;
begin
 r:=hash1.Get(charData);
 if r<>-1 then begin
  result.width:=r and $FF;
  result.height:=(r shr 8) and $FF;
  result.dx:=(r shr 16) and $FF-128;
  result.dy:=(r shr 24) and $FF-128;
  r:=hash2.Get(charData);
  result.x:=relX+r and $3FF;
  result.y:=relY+(r shr 16) and $3FF;
 end else begin
  result.x:=-1;
  result.y:=-1;
 end; 
end;

procedure TDynamicGlyphCache.Keep;
begin
 // Ensure that at least 20% of cache is free
 while (freeMax-freeMin<aHeight div 4) do FreeOldBand;
end;

procedure TDynamicGlyphCache.Release;
begin
 // Do nothing
end;

procedure TDynamicGlyphCache.FreeOldBand;
var
 y,i,key:integer;
begin
 ASSERT(firstBand>=0);
 // Clear hash items
 y:=bands[firstBand].y;
 for i:=0 to hash2.count-1 do
  if hash2.values[i] shr 16=y then begin
   key:=hash2.keys[i];
   hash2.Remove(key); // Удаление никак не влияет на порядок элементов, поэтому так делать можно
   hash1.Remove(key);
  end;
 // Delete band
 bands[firstBand].height:=0;
 firstBand:=bands[firstBand].next;
 // Update free space range
 if firstBand=-1 then begin
  // everything is deleted
  freeMin:=0; freeMax:=aHeight;
 end else begin
  freeMax:=bands[firstband].y-1;
  if freeMax<freeMin then inc(freeMax,aHeight);
 end;
end;

function TDynamicGlyphCache.CreateNewBand(height:integer):integer;
var
 i,y,b:integer;
begin
 // get new band position
 if (freeMin+height<=aHeight) then y:=freeMin else
  if (aHeight+height-1<=freeMax) then y:=aHeight else
   raise EWarning.Create('DGC: cache overflow 1');
 if freeMin+height>freeMax then
  raise EWarning.Create('DGC: cache overflow 3');
 // Find free band record
 b:=-1;
 for i:=0 to bCount-1 do
  if bands[i].height=0 then begin
   b:=i; break;
  end;
 // Add band record if needed
 if b=-1 then begin
  if bCount>=99 then
   raise EWarning.Create('DGC: cache overflow 2');
  b:=bCount;
  inc(bCount);
 end;
 result:=b;
 // Adjust free space range
 freeMin:=y+height;
 if freeMin>=aHeight then begin
  dec(freeMin,aHeight);
  dec(freeMax,aHeight);
  if y>=aHeight then dec(y,aHeight);
 end;
 // Fill band data
 bands[b].y:=y;
 bands[b].height:=height;
 bands[b].next:=-1;
 bands[b].freeSpace:=aWidth;
 // Links
 if lastBand=-1 then begin
  firstBand:=b; lastBand:=b;
 end else begin
  bands[lastBand].next:=b;
  lastBand:=b;
 end;
end;

function TDynamicGlyphCache.CanCreateBand(height:integer):boolean;
begin
 if freeMax<aHeight then
  result:=(freeMax-freeMin>=height)
 else begin
  result:=false;
  if freeMin+height<=aHeight then result:=true;
  if aHeight+height-1<=freeMax then result:=true;
 end;
end;

function TDynamicGlyphCache.Usage:single;
var
 b,s,h:integer;
begin
{ b:=0;
 for s:=0 to hash.count-1 do
  if hash.keys[s]<>-1 then inc(b);
 result:=round(b);
 exit;}
 b:=firstBand; s:=0; h:=0;
 while b<>-1 do begin
  inc(s,bands[b].height*(aWidth-bands[b].freeSpace));
  inc(h,bands[b].height);
  b:=bands[b].next;
 end;
 if h>0 then result:=s/(h*aWidth)
  else result:=1;
end;

end.
