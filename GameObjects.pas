// Visual objects/sprites etc.
//
// Copyright (C) 2014 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit GameObjects;
interface
 uses MyServis,AnimatedValues,EngineAPI;
 const
  DONT_CHANGE = -9987; // magic value which means "keep previous value"
  LIVE_OBJECT = $2468; // magic value for live object
 type
  // Тип связи между объектами
  TObjectRelation=(
   orNone,      // Объект самостоятельный и независимый
   orAttached,  // Объект присоединен к другому объекту, его координаты относительны, при удалении связанного объекта удаляется и этот
   orMaster,    // Объект-хозяин, он обязан рисовать подчинённый объект, при удалении подчинённый объект становится свободным
   orSlave);    // Подчинённый объект (не рисуется, не проверяется)

  TSide=(sNone  = 0,
         sTop   = 1,
         sRight = 2,
         sBottom = 4,
         sLeft  = 8); // стороны

  {$ALIGN 4}
  // Базовый класс с общим функционалом
  TGameObjectClass=class of TGameObject;
  TGameObject=class(TSortableObject)
   private
    layerID:integer;
    function GetLayerName:string;
    procedure SetLayer(l:string);
    procedure AddToGlobalList;
   public
    name:string;
    objID:cardinal;
    tag:integer; // произвольное число (можно использовать как ссылку для внешних структур)
    x,y,z:TAnimatedValue; // текущее положение (z=0 - норма, z>0 - приподнята)
    alpha,scale:TAnimatedValue;
    width,height:single; // используется для поиска объекта в заданной точке (т.е. это размеры "непрозрачной" для мыши части объекта)
    timeToDelete:int64;
    realX,realY:single; // тут запоминается положение объекта в экранных координатах при последней отрисовке
    aliveMagic:word; // $DEAD - если удалён, $2468 - если жив (проверка на доступ к удалённому объекту)
    relation:TObjectRelation; // Тип связи между объектами
    related:TGameObject; // Связанный объект
    constructor Create(x_,y_,z_,alpha_,scale_:single;layer_:string='';name_:string='');
    constructor Clone(obj:TGameObject;toLayer:string='');
    destructor Destroy; override;
    function MoveTo(newX,newY,newZ:single;time:integer):TGameObject; virtual;
    procedure Draw(fromX,fromY,fromZ:single); virtual;
    procedure DeleteAfter(time:cardinal); // Удалить объект через time ms
    function Compare(obj:TSortableObject):integer; override;
    property layer:string read GetLayerName write SetLayer; // Текстовое имя слоя
    function Describe:string; // object description
    procedure AttachTo(obj:TGameObject); // attach this object to another
    function IsAlive:boolean;
  end;

  TGameObjects=array of TGameObject;

  // Объект - изображение
  TImageObject=class(TGameObject)
   protected
    image:TTexture;
    tR,tG,tB:TAnimatedValue; // 0..255+ - где 255 - белый
   public
    angle:TAnimatedValue;
    blendMode:TBlendingMode;
    autoFreeImage:boolean;
    constructor Create(x_,y_,alpha_,scale_:single;img:TTexture;color_:cardinal;layer_:string='';name_:string='');
    destructor Destroy; override;
    procedure Draw(fromX,fromY,fromZ:single); override;
    function SetColor(color:cardinal;time:integer;delay:integer=0):TImageObject;
  end;

  // Текстовая надпись с эффектом свечения/тени (врисованная в текстуру)
  TTextObject=class(TImageObject)
   protected
    text:WideString;
    font,textColor,glowColor:cardinal;
    spread,blur,dx,dy:integer;
    valid:boolean;
   public
    constructor Create(x_,y_,z_,alpha_,scale_:single;text_:string;font_,color_:cardinal;layer_:string='';name_:string='');
    destructor Destroy; override;
//    function MoveTo(newX,newY:single;time:integer):TTextObject; override;
    procedure Draw(fromX,fromY,fromZ:single); override;
    procedure SetText(st:WideString); virtual;
    function SetColor(color:cardinal;time:integer;delay:integer=0):TTextObject;
    function SetTextColor(color_:cardinal):TTextObject; virtual;
    function SetGlow(dx_,dy_:integer;color_:cardinal;spread_,blur_:integer):TTextObject; virtual;
  end;

  // Single particle item
  TMyParticle=record
   id:cardinal; // уникальный идентификатор партикла (>0) не меняется до удаления, содержит индекс в массиве (low word)
   x,y,z,angle,scale:single;
   speedX,speedY,speedA,speedS:single; // change for x, y, angle and scale (per second)
   param:single; // default: gravity acceleration (+dSpeedY)
   color:cardinal;
   age:single; // время жизни с момента создания (в сек), отрицательное - партикл удаляется
   life:single; // время жизни (при достижении которого партикл удаляется)
   kind:integer; // default: index in texture
  end;

  // Базовый класс для партикловых эффектов
  TParticleEffect=class(TGameObject)
   zDist:single; // default=1, override this value if needed
   constructor Create(x_,y_,z_:single;tex:TTexture;partSize:integer;layer_,name_:string);
   destructor Destroy; override;
   // Обновляет состояние эффекта за прошедшее время time (ms), totalTime - сколько времени прошло с создания эффекта
   procedure Update(time,totalTime:integer); virtual;
   // Обновляет каждый конкретный партикл, генерирует выходной партикл
   // time - время в секундах с предыдущей обработки (базовая версия применяет движение, гравитацию, время жизни)
   procedure HandleParticle(time:single;var sour:TMyParticle;var dest:TParticle); virtual;
   // Производит отрисовку. Дефолтная отрисовка просто рисует имеющиеся партиклы.
   // Можно переопределить втч для того, чтобы генерить набор каждый кадр, а не использовать Update
   procedure Draw(fromX,fromY,fromZ:single); override;
   // Добавляет новый партикл, возвращает его индекс в массиве
   function AddParticle:integer;
  protected
   created:int64; // когда эффект был создан
   lastDrawn:int64; // время последней отрисовки
   texture:TTexture; // базовая текстура
   size:integer; // базовый размер партиклов
   parts:array of TMyParticle; // массив исходных партиклов (может содержать "дырки")
//   count:integer; // общее кол-во партиклов
   renderParts:array of TParticle;
   renderCount:integer;
   lastID:integer;
   newIdx:integer; // индекс, начиная с которого идёт поиск места для добавления партикла (сбрасывается при удалении)
   zMin,zMax:single; // Z filter
   procedure InternalDraw(x,y:integer;zMin,zMax:single);
  end;

  // Вспомогательный объект-фильтр: "cлой" для разделения партикловых эффектов по Z
  TParticleEffectLayer=class(TGameObject)
   constructor Create(mainObj:TParticleEffect;z_,zMin_,zMax_:single);
   procedure Draw(fromX,fromY,fromZ:single); override;
  protected
   parentID:cardinal;
   zMin,zMax:single;
  end;

  // Текст в фигурной рамке (возможно со стрелкой)
{  THintObject=class(TGameObject)
    constructor Create(x_,y_,z_:single;text:string;font,color,background,border:cardinal;
       sideArrow:TSide;rounded,borderWidth:single;layer_:string='';name_:string='');
    destructor Destroy; override;
    procedure Draw(fromX,fromY,fromZ:single); override;
  protected
    lines:array of WideString;
    textColor,borderColor,backgroundColor:cardinal;
  end;}


 // Ф-ции, возвращающие объекты, и сами возвращаемые объекты использовать только при блокировке!
 function FindObjByName(name:string):TGameObject;
 function FindObjByID(ID:cardinal):TGameObject;
 function FindObjectAt(x,y:integer;layers:string=''):TGameObject;
 function GetLayerObjects(layers:string):TGameObjects;

 // Можно вызывать без блокировки
 procedure DeleteObject(ID:cardinal);
 procedure DeleteObjects(objNames:string); // list of object names (separated by comma, semicolon or space)
 procedure DeleteAllObjects(layers:string='All');

 procedure LockObjects;
 procedure UnlockObjects;

 // Есть 3 режима перемещения:
 //  1 - time>0, smoothness - mode: более-менее равномерное перемещение в будущем (конечная точка заранее известна)
 //  2 - time=0, smoothness=0..100: перемещение в реальном времени со сглаживанием
 //  3 - time<0, мгновенная установка положения камеры
 procedure SetViewpoint(x,y,z:single;time:integer;smoothness:integer=0);
 procedure GetViewpoint(out x,y,z:single);
 // Только объекты перечисленных слоев будут отображаться и находиться
 procedure EnableLayers(layers:string);
 // layers='All' - рисует все _включенные_ слои, онако можно перечислить и выключенные
 procedure DrawGameObjects(zMin,zMax:single;layers:string='');


implementation
 uses SysUtils,images,EngineTools,types;
 const
  indexMask = $3FFF; // 16384 объектов в списке
 var
  objList:array of TGameObject;
  objCount:integer;
  sorted:boolean; // объекты в списке отсортированы?
  objIndex:array[0..indexMask] of TGameObject; // индекс для быстрого поиска объектов по ID
  lastID:cardinal; // свободный индекс
  crSect:TMyCriticalSection;
  cameraX,cameraY,cameraZ:TAnimatedValue;

  layerNames:array[0..31] of string; // 0 - безымянный слой, 1..31 - именные слои
  lCount:integer;
  layersEnabled:cardinal=$FFFFFFFF; // маска включенных слоев

{ TGameObject }

procedure TGameObject.DeleteAfter(time: cardinal);
begin
 LockObjects;
 try
 ASSERT(self<>nil);
 ASSERT(self is TGameObject);
 ASSERT(IsAlive);
 timeToDelete:=MyTickCount+time;
 finally UnlockObjects;
 end;
end;

destructor TGameObject.Destroy;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
  aliveMagic:=$DEAD;
  // Удалить из индекса
  ASSERT(objIndex[objID and indexMask]=self,'Wrong object in index: '+inttostr(objID));
  objIndex[objID and indexMask]:=nil;

  // Удалить объект из списка
  for i:=0 to objCount-1 do
   if objList[i]=self then begin
    dec(objCount);
    objList[i]:=objList[objCount];
    objList[objCount]:=nil;
    break;
   end;

  // Удалить все ссылающиеся объекты (рекурсивно)
  i:=0;
  while i<objCount do
   if objList[i].related=self then objList[i].Free
    else inc(i);

 finally crSect.leave; end;
 inherited;
end;

procedure TGameObject.Draw(fromX,fromY,fromZ:single);
begin
 // Запоминаем позицию, в которой объект нарисован
 realX:=x.Value-fromX;
 realY:=y.Value-fromY;
end;

function TGameObject.GetLayerName: string;
begin
 result:='';
 if (layerID>=0) and (layerID<=31) then
  result:=layerNames[layerID];
end;

function TGameObject.IsAlive: boolean;
begin
 result:=aliveMagic=LIVE_OBJECT;
end;

function TGameObject.MoveTo(newX, newY, newZ:single; time: integer):TGameObject;
begin
 if newX<>DONT_CHANGE then x.Animate(newX,time,spline1);
 if newY<>DONT_CHANGE then y.Animate(newY,time,spline1);
 if newZ<>DONT_CHANGE then z.Animate(newZ,time,spline1);
 result:=self;
end;

// Возможно, какого-то из перечисленных слоев еще нет - нужно создать!
function GetLayersMask(layers:string):cardinal;
var
 i,j,k:integer;
 st:string;
 found:boolean;
begin
 result:=0;
 layers:=UpperCase(layers)+';';
 if layers='ALL;' then begin
  result:=layersEnabled; exit;
 end;
// if lCount=0 then exit;
 i:=1; j:=1;
 while i<=length(layers) do begin
  if layers[i] in [',',';',' '] then begin
   if i>j then begin
    st:=copy(layers,j,i-j);
    if st='ALL' then
     result:=result or layersEnabled
    else begin
     found:=false;
     for k:=1 to lCount do
      if layerNames[k]=st then begin
       result:=result or (1 shl k);
       found:=true;
      end;
     if not found then begin
      inc(lCount);
      layerNames[lCount]:=st;
      result:=result or (1 shl lCount);
     end;
    end;
   end;
   j:=i+1;
  end;
  inc(i);
 end;
end;

procedure TGameObject.SetLayer(l: string);
var
 i:integer;
begin
 l:=UpperCase(l);
 layerID:=0;
 if l='' then exit;
 for i:=1 to lCount do
  if layerNames[i]=l then begin
   layerID:=i; exit;
  end;
 ASSERT(lCount<31);
 inc(lCount);
 layerID:=lCount;
 layerNames[layerID]:=l;
end;

function TGameObject.Compare(obj: TSortableObject): integer;
var
 z1,z2:double;
begin
 result:=0;
 if obj=self then exit; // Сравнение объекта с собой
 try
  z1:=z.Value;
  z2:=TGameObject(obj).z.Value;
  if z1>z2+0.00001 then result:=1;
  if z2>z1+0.00001 then result:=-1;
 except
  on e:exception do
   raise EWarning.Create('Compare: '+Describe+' vs '+TGameObject(obj).Describe);
 end;
end;

function TGameObject.Describe:string;
begin
 try
  if self=nil then begin
   result:='NIL'; exit;
  end;
  result:=className+'('+name+')='+Format('[ID=%d,layer=%s]',[objID,layer]);
 except
  result:='Failure: '+IntToHex(cardinal(self),8);
 end;
end;

procedure TGameObject.AddToGlobalList;
begin
 EnterCriticalSection(crSect);
 try
  // Assign proper ID and register in index
  objID:=lastID;
  ASSERT(objIndex[objID and indexMask]=nil);
  objIndex[objID and indexMask]:=self;
  // Find next free index
  repeat inc(lastID);
  until objIndex[lastID and indexMask]=nil;
  // Add to global list
  inc(objCount);
  if objCount>length(objList) then
   SetLength(objList,objCount*2+20);
  objList[objCount-1]:=self;
  sorted:=false;
 finally
  LeaveCriticalSection(crSect);
 end;
end;

constructor TGameObject.Create(x_,y_,z_,alpha_,scale_:single;layer_:string='';name_:string='');
begin
 AddToGlobalList;
 realX:=-10000; realY:=-10000;
 x.Init(x_); y.Init(y_); z.Init(z_);
 alpha.Init(alpha_); scale.Init(scale_);
 name:=name_;
 if name='' then name:=layer_+'\'+IntToStr(objID);
 layerID:=0;
 layer:=layer_;
 width:=0; height:=0;
 related:=nil;
 relation:=orNone;
 timeToDelete:=0;
 aliveMagic:=LIVE_OBJECT;
end;

procedure TGameObject.AttachTo(obj:TGameObject);
begin
 relation:=orAttached;
 related:=obj;
end;

constructor TGameObject.Clone(obj: TGameObject;toLayer:string='');
begin
 AddToGlobalList;
// objID:=lastID; inc(lastID);
 name:=obj.name+'_';
 x.Clone(obj.x);
 y.Clone(obj.y);
 z.Clone(obj.z);
 scale.Clone(obj.Scale);
 alpha.Clone(obj.Alpha);
 layerID:=obj.layerID;
 if toLayer<>'' then layer:=toLayer;
 realX:=obj.RealX;
 realY:=obj.realY;
 width:=obj.width;
 height:=obj.height;
 timeToDelete:=0;
end;

function FindObjByName(name:string):TGameObject;
var
 i:integer;
begin
 result:=nil;
 EnterCriticalSection(crSect);
 try
 for i:=0 to objCount-1 do
  if objList[i].name=name then begin
   result:=objList[i]; exit;
  end;
 finally LeaveCriticalSection(crSect);
 end;
end;

function FindObjByID(ID:cardinal):TGameObject;
var
 i:integer;
begin
 EnterCriticalSection(crSect);
 try
 result:=objIndex[ID and indexMask];
 if result<>nil then begin
  ASSERT(result is TGameObject,'Object index damaged! '+inttostr(ID));
  ASSERT(result.objID=ID,'Access to wrong object: '+inttostr(ID)+' != '+inttostr(result.objID));
 end;
 finally LeaveCriticalSection(crSect);
 end;
end;

function FindObjectAt(x,y:integer;layers:string=''):TGameObject;
var
 i:integer;
 ox,oy,ow,oh,scale:single;
 lMask:cardinal;
begin
 result:=nil;
 if layers='' then lMask:=layersEnabled
  else lMask:=GetLayersMask(layers);
 for i:=0 to objCount-1 do begin
  if ((1 shl objList[i].layerID) and lMask)=0 then continue;
  ox:=objList[i].realX;
  oy:=objList[i].realY;
  scale:=objList[i].scale.Value;
  ow:=objList[i].width*scale/2;
  oh:=objList[i].height*scale/2;
  if (x>ox-ow) and (x<ox+ow) and
     (y>oy-oh) and (y<oy+oh) and
     (objList[i].alpha.Value>0.05) then begin
   result:=objList[i];
   exit;
  end;
 end;
end;

procedure LockObjects;
begin
 EnterCriticalSection(crSect,GetCaller);
end;

procedure UnlockObjects;
begin
 LeaveCriticalSection(crSect);
end;

function GetLayerObjects(layers:string):TGameObjects;
var
 i,c:integer;
 mask:cardinal;
begin
 mask:=GetLayersMask(layers);
 c:=0;
 SetLength(result,objCount);
 for i:=0 to objCount-1 do
  if mask and (1 shl objList[i].layerID)>0 then begin
   result[c]:=objList[i];
   inc(c);
  end;
 SetLength(result,c);
end;

procedure DeleteAllObjects(layers:string='All');
var
 i,n,c:integer;
 mask:cardinal;
begin
 mask:=GetLayersMask(layers);
 LockObjects;
 try
  n:=objCount-1;
  c:=0;
  objCount:=0; // делаем вид, что список объектов пуст, чтобы избежать удаления объектов из него в деструкторе
  i:=0;
  while i<=n do begin
   if mask and (1 shl objList[i].layerID)>0 then begin
    objList[i].Free;
    objList[i]:=objList[n];
    objList[n]:=nil;
    dec(n);
   end else begin
    inc(c);
    inc(i);
   end;
  end;
  objCount:=c;
 finally UnlockObjects;
 end;
end;

procedure DeleteObject(ID:cardinal);
var
 obj:TGameObject;
begin
 EnterCriticalSection(crSect);
 try
  obj:=FindObjByID(ID);
  if obj<>nil then obj.Free;
 finally LeaveCriticalSection(crSect);
 end;
end;

procedure DeleteObjects(objNames:string);
var
 i,j:integer;
begin
 objNames:=objNames+',';
 LockObjects;
 try
  j:=1;
  for i:=1 to length(objNames) do
   if (objNames[i] in [',',' ',';']) and (i>j) then begin
    FindObjByName(copy(objNames,j,i-j)).Free;
    j:=i+1;
   end;
 finally UnlockObjects;
 end;
end;

procedure SetViewpoint(x,y,z:single;time:integer;smoothness:integer=0);
var
 f1,f2:single;
begin
 if time<0 then begin
  cameraX.Init(x);
  cameraY.Init(y);
  cameraZ.Init(z);
 end else
 if time>0 then begin
  cameraX.Animate(x,time,spline0);
  cameraY.Animate(y,time,spline0);
  cameraZ.Animate(z,time,spline0);
 end else begin
  f1:=smoothness/100; f2:=1-f1;
  cameraX.Init(cameraX.Value*f1+x*f2);
  cameraY.Init(cameraY.value*f1+y*f2);
  cameraZ.Init(cameraZ.value*f1+z*f2);
 end;
end;

procedure GetViewpoint(out x,y,z:single);
begin
  x:=cameraX.Value;
  y:=cameraY.Value;
  z:=cameraZ.Value;
end;

procedure EnableLayers(layers:string);
begin
 layersEnabled:=GetLayersMask(layers);
end;

procedure DrawGameObjects(zMin,zMax:single;layers:string='');
var
 i,j:integer;
 obj:TGameObject;
 sorted:boolean;
 z,a,lastZ:single;
 fromX,fromY,fromZ:single;
 t:int64;
 del:array[1..50] of TGameObject;
 dCount:integer;
 mask:cardinal;
 stage:integer;
begin
 t:=MyTickCount;
 if layers='' then mask:=layersEnabled
  else mask:=GetLayersMask(layers);
 LockObjects;
 try
 try
 i:=0; dCount:=0; stage:=0;
 for i:=0 to objCount-1 do
  if (objList[i].timeToDelete>0) and (t>objList[i].timeToDelete) then begin
   inc(dCount); del[dCount]:=objList[i];
   if dCount>=50 then break;
  end;
 for i:=1 to dCount do begin
  stage:=100000+i;
  del[i].Free;
 end;
 if true or not sorted then begin
  stage:=200000;
  if objCount>1 then
   SortObjects(@objList,objCount);
  sorted:=true;
 end;
 // Draw
 fromX:=cameraX.value;
 fromY:=cameraY.value;
 fromZ:=cameraZ.value;
 i:=0;
 while i<objCount do begin
  stage:=300000+i;
  if mask and (1 shl objList[i].layerID)=0 then begin
   inc(i); continue;
  end;
  z:=objList[i].z.Value;
  a:=objList[i].alpha.Value;
  if (z>=zMin) and (z<=zMax) and (a>0.01) then
    objList[i].Draw(fromX,fromY,fromZ);
  inc(i);
 end;

 except
  on e:Exception do begin
   LogMessage('Error in DO ('+inttostr(stage)+'): '+ExceptionMsg(e));
   if stage>=300000 then begin
    LogMessage('Obj: '+IntToHex(cardinal(objList[i]),8));
    if objList[i]<>nil then
     LogMessage(' '+objList[i].ClassName+': '+objList[i].name);
   end else begin
    // List all objects
    LogMessage(Format('Objects: %d',[objCOunt]));
    for i:=0 to objCount-1 do
     LogMessage(Format(' %d %p %s',[i,objList[i],objList[i].Describe]));
    Sleep(1000);
   end;
  end;
 end;
 finally
  UnlockObjects;
 end;
end;

{ TFlyingText }

constructor TTextObject.Create(x_, y_, z_, alpha_, scale_: single;
  text_: string; font_,color_: cardinal;layer_:string='';name_:string='');
begin
 LockObjects;
 try
 if name_='' then name_:=layer_+'\'+copy(text_,1,6);
 inherited Create(x_,y_,alpha_,scale_,nil,color_,layer_,name_);
 z.Init(z_);
 font:=font_;
 SetColor(color_,0);
 blur:=0;
 spread:=0;
 glowcolor:=0;
 textColor:=$FFFFFFFF;
 SetText(text_);
 valid:=false;
 finally
  UnlockObjects;
 end;
end;

destructor TTextObject.Destroy;
begin
 if image<>nil then texman.FreeImage(image);
 inherited;
end;

procedure TTextObject.Draw(fromX, fromY, fromZ: single);
var
 globalcolor:cardinal;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 if not valid and (image<>nil) then begin
  texman.FreeImage(image);
  image:=nil;
 end;
 if image=nil then begin
  image:=BuildTextWithGlow(font,text,textColor,glowColor,spread,blur,dx,dy);
  width:=image.width;
  height:=image.height;
  valid:=true;
 end;
 inherited;
end;

function TTextObject.SetColor(color: cardinal; time: integer;delay:integer=0):TTextObject;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 tR.Animate((color shr 16) and $FF,time,spline0,delay);
 tG.Animate((color shr 8) and $FF,time,spline0,delay);
 tB.Animate(color and $FF,time,spline0,delay);
 result:=self;
end;

function TTextObject.SetTextColor(color_:cardinal):TTextObject;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 result:=self;
 textColor:=color_;
 valid:=false;
end;

function TTextObject.SetGlow(dx_, dy_: integer; color_: cardinal; spread_,blur_: integer):TTextObject;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 result:=self;
 if (dx=dx_) and (dy=dy_) and (spread=spread_) and (glowColor=color_) and (blur=blur_) then exit;
 dx:=dx_;
 dy:=dy_;
 spread:=spread_;
 glowColor:=color_;
 blur:=blur_;
 valid:=false;
end;

procedure TTextObject.SetText(st: WideString);
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 if text<>st then begin
  text:=st;
  valid:=false;
 end;
end;

{ TImageObject }

constructor TImageObject.Create(x_, y_, alpha_, scale_: single;
  img: TTexture;color_:cardinal;layer_:string='';name_:string='');
begin
 LockObjects;
 try
 inherited Create(x_,y_,0,alpha_,scale_,layer_,name_);
 blendMode:=blAlpha;
 if img<>nil then begin
  width:=img.width;
  height:=img.height;
 end;
 autoFreeImage:=false;
 image:=img;
 SetColor(color_,0);
 angle.Init(0);
 finally
  UnlockObjects;
 end;
end;

destructor TImageObject.Destroy;
begin
 if autoFreeImage then texman.FreeImage(image);
 inherited;
end;

procedure TImageObject.Draw(fromX, fromY, fromZ: single);
var
 globalColor:cardinal;
 r,g,b:integer;
 s,a:single;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 inherited;
 if image<>nil then begin
  r:=Sat(tR.IntValue,0,511) shr 1;
  g:=Sat(tG.IntValue,0,511) shr 1;
  b:=Sat(tB.IntValue,0,511) shr 1;

  globalColor:=round(alpha.value*255) shl 24+r shl 16+g shl 8+b;
  a:=angle.value;
  s:=scale.value;
  if blendMode<>blAlpha then
   painter.SetMode(blendMode);
  if (s=1) and (a=0) then
   painter.DrawImage(round(x.Value-width/2+0.4-fromX),
                     round(y.value-height/2+0.4-fromY),
                     image,globalColor)
  else
   painter.DrawRotScaled(round(x.Value-fromX),
                         round(y.value-fromY),s,s,a,
                         image,globalColor);
  if blendMode<>blAlpha then
   painter.SetMode(blAlpha);
 end;
end;

function TImageObject.SetColor(color: cardinal; time: integer; delay:integer=0): TImageObject;
begin
 ASSERT(aliveMagic=LIVE_OBJECT,'Object '+inttohex(cardinal(self),8)+' deleted '+inttohex(aliveMagic,4));
 tR.Animate(2*((color shr 16) and $FF),time,spline0,delay);
 tG.Animate(2*((color shr 8) and $FF),time,spline0,delay);
 tB.Animate(2*(color and $FF),time,spline0,delay);
 result:=self;
end;

{ TParticleEffect }

function TParticleEffect.AddParticle: integer;
var
 i:integer;
begin
 inc(lastID);
 while newIdx<length(parts) do
  if parts[newIdx].id=0 then break
   else inc(newIdx);
 result:=newIdx;
 if newIdx>=length(parts) then begin
  SetLength(parts,32+newIdx+newIdx div 2);
  for i:=newIdx to high(parts) do
   FillChar(parts[i],sizeof(parts[i]),0);
 end else
  fillchar(parts[result],sizeof(TMyParticle),0);
 parts[result].id:=lastID shl 16+result;
end;

constructor TParticleEffect.Create(x_, y_, z_:single;tex:TTexture;partSize:integer; layer_,
  name_: string);
begin
 LockObjects;
 try
  inherited Create(x_,y_,z_,1,1,layer_,name_);
  created:=MyTickCount;
  lastDrawn:=created;
  size:=partSize;
  texture:=tex;
//  count:=0;
  lastID:=0;
  SetLength(parts,200);
  zDist:=1;
  zMin:=-99999; zMax:=99999;
  newIdx:=0;
 finally
  UnlockObjects;
 end;
end;

destructor TParticleEffect.Destroy;
begin
 inherited;
 SetLength(parts,0);
end;

procedure TParticleEffect.InternalDraw;
var
 i,n:integer;
 p:array[0..1000] of TParticle; // limited amount
begin
 n:=0;
 for i:=0 to renderCount-1 do
  if (renderParts[i].z>=zMin) and (renderParts[i].z<zMax) then begin
   p[n]:=renderParts[i];
   inc(n);
  end;
 painter.DrawParticles(x,y,@p[0],n,texture,size,zDist);
end;

procedure TParticleEffect.Draw;
var
 i:integer;
 t:int64;
 time:single;
 isAlive:boolean;
begin
 inherited;
 if texture=nil then exit;
 try
 t:=MyTickCount;
 Update(t-lastDrawn,t-created);
 time:=(t-lastDrawn)/1000;
 lastDrawn:=t;
 // Build render list
 if length(renderParts)<length(parts) then SetLength(renderParts,length(parts));
 renderCount:=0;
 for i:=0 to high(parts) do
  if (parts[i].id>0) and (parts[i].age>=0) then begin
   HandleParticle(time,parts[i],renderParts[renderCount]);
   if (parts[i].age>=0) and // повторная проверка необходима, т.к. партикл мог измениться (быть удалён)
      (renderParts[renderCount].color and $FF000000>0) then inc(renderCount);
  end;
 // Draw
 InternalDraw(round(-fromX+x.value),round(-fromY+y.value),-99999,99999);
// painter.DrawParticles(round(-fromX+x.value),round(-fromY+y.value),@p[0],n,texture,size,zDist);
 // Delete dead particles
 for i:=0 to high(parts) do
  if (parts[i].age<0) or
     ((parts[i].life>0) and (parts[i].age>parts[i].life)) then parts[i].id:=0;
 except
  on e:exception do raise EWarning.Create('PE.Draw '+className+' error: '+ExceptionMsg(e));
 end;
 if (renderCount=0) and (t-created>1000) then timeToDelete:=1; // объект живет до последнего партикла, но не менее 1 сек
end;

procedure TParticleEffect.HandleParticle(time:single;var sour: TMyParticle;
  var dest: TParticle);
begin
 dest.x:=sour.x;
 dest.y:=sour.y;
 dest.z:=sour.z;
 if sour.life>0 then
  dest.color:=sour.color and $FFFFFF+round((sour.color shr 24)*(1-sour.age/sour.life)) shl 24
 else
  dest.color:=sour.color;
 dest.angle:=sour.angle;
 dest.scale:=sour.scale;
 dest.index:=sour.kind;
 // Movement
 sour.x:=sour.x+sour.speedX*time;
 sour.y:=sour.y+sour.speedY*time;
 sour.angle:=sour.angle+sour.speedA*time;
 sour.scale:=sour.scale+sour.speedS*time;
 // Gravity
 sour.speedY:=sour.speedY+sour.param*time;
 // Life
 sour.age:=sour.age+time;
end;

procedure TParticleEffect.Update(time,totalTime: integer);
begin
end;

{ TParticleEffectLayer }

constructor TParticleEffectLayer.Create(mainObj: TParticleEffect; z_,zMin_,zMax_: single);
begin
 inherited Create(mainObj.x.value,mainObj.y.Value,z_,1,1,mainObj.layer,mainObj.name+'_L');
 parentID:=mainObj.objID;
 zMin:=zMin_;
 zMax:=zMax_;
end;

procedure TParticleEffectLayer.Draw(fromX, fromY, fromZ: single);
var
 parentObj:TParticleEffect;
begin
 parentObj:=FindObjByID(parentID) as TParticleEffect;
 if parentObj<>nil then
  parentObj.InternalDraw(round(-fromX+x.value),round(-fromY+y.value),zMin,zMax)
 else
  timeToDelete:=1;
end;

initialization
 InitCritSect(crSect,'GameObjects',90);
 cameraX.Init(0);
 cameraY.Init(0);
 cameraZ.Init(100);
 layerNames[0]:='*';
 lCount:=0;
finalization
 DeleteCritSect(crSect);
end.
