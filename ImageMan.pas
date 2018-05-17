// Images manager
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit ImageMan;
interface
type
 ImageStr=string[63]; // имя изображения - имеет вид class\subclass\...\subclass\name

 TReason=(rPrepare,rFree);
 TImgDescriptor=class;
 TLoader=procedure(reason:TReason;var image:TImgDescriptor);
 TDrawer=procedure(image:TImgDescriptor;x,y:integer;color:cardinal;p1,p2,p3,p4:single);

 TImgDescriptor=class
  FullName:string; // полное имя
  name:ImageStr; // имя за вычетом класса (в uppercase)
  handle:THandle;
  drawer:TDrawer;
  loader:TLoader;
  tag,tag2:integer;    // Далее идут данные обработчиков
  value:single;
  data:pointer;
 end;

 // Вернуть хэндл изображения (если такое уже было подготовлено - просто найдет хэндл по
 //  имени, если нет - подготовит и вернет)
 function GetImageHandle(image:ImageStr):THandle;

 // Готовит изображение к отрисовке, возвращает хэндл
 // Возвращаемый хэндл - полный синоним имени
 function PrepareImage(image:ImageStr):THandle;

 // Нарисовать указанное изображение. Смысл параметров полностью определяется отрисовщиками
 procedure DrawImage(image:THandle;x,y:integer;color:cardinal;p1,p2,p3,p4:single);

 // Сообщает что изображение больше не нужно и можно освободить необходимые ресурсы
 procedure FreeImage(image:THandle);

 // Для указанного класса изображений установить процедуры загрузки и отрисовки
 // Каждый класс может иметь только один обработчик
 procedure SetDrawer(images:ImageStr;loader:TLoader;drawer:TDrawer);
 // Отменить процедуры загрузки/отрисовки для класса
 // (если какие-то изображения были созданы с этим loader'ом, то они освобождаются)
 procedure RemoveDrawer(images:ImageStr);

implementation
 uses myservis,math,SysUtils,EventMan,structs;

type
 TDrawerInfo=class
  drawer:TDrawer;
  loader:TLoader;
  clsname:ImageStr;
 end;

var
 drawers:array[0..255] of TDrawerInfo;
 drcnt:integer;

 descriptors:array[1..4096] of TImgDescriptor;
 freedesc:array[0..4095] of integer;
 freedesccnt:integer;

 hash:TStrHash; // хэш для поиска дескрипторов по имени

function GetImageHandle(image:ImageStr):THandle;
 var
  desc:^TImgDescriptor;
 begin
  desc:=hash.Get(image);
  if desc=nil then
   result:=PrepareImage(image) else
   result:=desc.handle;
 end;

// Сравнивает два имени, возвращает кол-во совпадающих секций
function Compare(name1,name2:ImageStr):integer;
 var
  i:integer;
  sa1,sa2:StringArr;
 begin
  result:=0;
  sa1:=split('\',name1,#0);
  sa2:=split('\',name2,#0);
  for i:=0 to min(length(sa1),length(sa2))-1 do
   if sa1[i]=sa2[i] then inc(result)
    else break;
 end;

function PrepareImage(image:ImageStr):THandle;
 var
  i,best,bestn:integer;
  img:ImageStr;
 begin
  if freedesccnt<=0 then raise EError.Create('ImageMan: out of handles!');
  img:=UpperCase(image);
  // find drawer for image
  best:=0; bestn:=-1;
  for i:=0 to drcnt-1 do
   if Compare(img,drawers[i].clsname)>best then begin
    best:=Compare(img,drawers[i].clsname);
    bestn:=i;
   end;
  if bestn<0 then raise EError.Create('ImageMan: no drawer for image '+image);

  dec(FreeDescCnt);
  result:=freedesc[FreeDescCnt];
  descriptors[result]:=TImgDescriptor.Create;
  with descriptors[result] do begin
   fullname:=image;
   name:=copy(img,length(drawers[bestn].clsname)+2,length(img)-length(drawers[bestn].clsname));
   handle:=result;
   drawer:=drawers[bestn].drawer;
   loader:=drawers[bestn].loader;
  end;
  // Call prepare handler
  if @drawers[bestn].loader<>nil then
   drawers[bestn].loader(rPrepare,descriptors[result]);
  hash.Put(descriptors[result].fullname,@descriptors[result]);
 end;

procedure DrawImage(image:THandle;x,y:integer;color:cardinal;p1,p2,p3,p4:single);
 begin
  ASSERT((image>0) and (image<=4096));
  descriptors[image].drawer(descriptors[image],x,y,color,p1,p2,p3,p4);
 end;

procedure FreeImage(image:THandle);
 begin
  ASSERT((image>0) and (image<=4096));
  hash.Remove(descriptors[image].FullName);
  descriptors[image].loader(rFree,descriptors[image]);
  descriptors[image].Free;
  FreeDesc[FreeDescCnt]:=image;
  inc(FreeDescCnt);
 end;

procedure SetDrawer(images:ImageStr;loader:TLoader;drawer:TDrawer);
 begin
  if drcnt=255 then exit;
//  if images[length(images)]<>'\' then images:=images+'\';
  drawers[drcnt]:=TDrawerInfo.Create;
  drawers[drcnt].drawer:=drawer;
  drawers[drcnt].loader:=loader;
  drawers[drcnt].clsname:=UpperCase(images);
  inc(drcnt);
 end;

procedure RemoveDrawer(images:ImageStr);
 var
  i:integer;
 begin
  if drcnt=0 then exit;
  images:=Uppercase(images);
  for i:=0 to drcnt-1 do
   if drawers[i].clsname=images then begin
    dec(drcnt);
    drawers[i].Free;
    drawers[i]:=drawers[drcnt];
    exit;
   end;
 end;

var
 i:integer;
initialization
 freedesccnt:=4096;
 for i:=0 to 4095 do
  freedesc[i]:=4096-i;

 hash:=TStrHash.Create;
end.
