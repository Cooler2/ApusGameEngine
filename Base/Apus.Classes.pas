// This unit containing some base classes

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Classes;
interface
uses SysUtils, Apus.Types;

type
 TObjectEx=class
  function Hash:cardinal; virtual;
  class procedure SetClassAttribute(attrName:String8;value:variant); // Assign arbitrary named attribute for the given class
  class function GetClassAttribute(attrName:String8):variant; overload; // Get named attribute for this class (can be inherited from base class)
  class function GetClassAttribute(attrName:String8;defaultValue:variant):variant; overload;
 end;

 TNamedObject=class(TObjectEx)
 protected
  fName:String8;
  procedure SetName(name:String8); virtual;
  function GetName:String8;
  class function ClassHash:pointer; virtual; // override this to provide a separate hash for object instances
  class function UniqueName(name:string8):boolean; inline;
 public
  destructor Destroy; override;
  function Hash:cardinal; override;
  property name:String8 read GetName write SetName;
  // Find object of given class by its name (case insensitive)
  class function FindByName(name:String8):TNamedObject; virtual;
 end;
 TNamedObjectClass=class of TNamedObject;
 TNamedObjects=array of TNamedObject;

  // Base exception with stack trace support
  TBaseException=class(Exception)
   private
    FAddress:cardinal;
   public
    constructor Create(const msg:string); overload;
    constructor Create(const msg:string; fields:array of const); overload;
    property Address:cardinal read FAddress;
  end;

  // Предупреждения следует вызывать в ситуациях, когда нужно
  // привлечь внимание к ненормальной ситуации, которая впрочем не
  // мешает продолжать нормальную работу, никаких дополнительных действий от
  // верхнего уровня не требуется
  // (например: процедура не смогла отработать, но это не нарушает работу верхнего уровня)
  EWarning=class(TBaseException);

  // Обычная ошибка - ситуация, когда выполнение программы явно нарушено
  // и продолжение работы возможно только если верхний уровень обработает ошибку и примет меры
  // (например: функция не смогла выполнить требуемые действия и не вернула результат. Очевидно,
  // что нормальное продолжение возможно только если верхний уровень откажется от использования результата)
  EError=class(TBaseException);

  // Фатальная ошибка - продолжение работы невозможно, верхний уровень обязан инициировать
  // завершение выполнения программы. Это исключение следует использовать тогда, когда
  // ошибка не может быть исправлена верхним уровнем
  // (например: обнаружено что-то, чего быть никак не может, т.е. результат повреждения
  // данных или ошибки в алгоритме, ведущей к принципиально неправильной работе. Чтобы
  // избежать возможной порчи данных при последующих вызовах, следует немедленно прекратить работу)
  EFatalError=class(TBaseException);

implementation
uses Apus.Common, Apus.Structs;

var
 classAttributes:TVarHash;

{ TNamedObject }

class function TNamedObject.FindByName(name:String8):TNamedObject;
 var
  hash:PObjectHash;
 begin
  hash:=ClassHash;
  if hash<>nil then
   result:=hash.Get(name)
  else
   raise EWarning.Create('Can''t find object "%s": class "%s" is not tracked',[name,className]);
 end;

function TNamedObject.GetName:String8;
 begin
  if self=nil then result:='empty'
   else result:=fName;
 end;

function TNamedObject.Hash: cardinal;
 begin
  result:=FastHash(name);
 end;

procedure TNamedObject.SetName(name:String8);
 var
  hash:PObjectHash;
  un:boolean;
 begin
  hash:=ClassHash;
  if hash<>nil then begin
    if UniqueName(fName) then hash.Remove(self);
    un:=UniqueName(name);
    if un and (hash.Get(name)<>nil) then
     raise EWarning.Create(Format('Duplicate object name %s(%s)',[ClassName,name]));
    fName:=name;
    if un then hash.Put(self);
   end
  else
   fName:=name;
 end;

class function TNamedObject.UniqueName(name:string8):boolean;
 begin
   result:=(name<>'') and not (name[1]='_');
 end;

class function TNamedObject.ClassHash:pointer;
 begin
  result:=nil;
 end;

destructor TNamedObject.Destroy;
 var
  hash:PObjectHash;
 begin
  if name<>'' then begin
   hash:=ClassHash;
   if hash<>nil then hash.Remove(self);
  end;
 end;


{ TObjectEx }

function TObjectEx.Hash:cardinal;
 begin
  result:=cardinal(pointer(self));
 end;

class procedure TObjectEx.SetClassAttribute(attrName:String8;value:variant);
 begin
  classAttributes.Put(className+'.'+attrName,value);
 end;

class function TObjectEx.GetClassAttribute(attrName:String8):variant;
 var
  cls:TClass;
 begin
  cls:=self;
  repeat
   result:=classAttributes.Get(cls.className+'.'+attrName);
   if HasValue(result) then exit;
   cls:=cls.ClassParent;
  until cls=nil;
 end;

class function TObjectEx.GetClassAttribute(attrName:String8;defaultValue:variant):variant;
 begin
  result:=GetClassAttribute(attrName);
  if not HasValue(result) then result:=defaultValue;
 end;

{ TBaseException }
constructor TBaseException.Create(const msg: string);
var
 stack:string;
 n,i:integer;
 adrs:array[1..6] of cardinal;
begin
 {$IFDEF CPU386}
 asm
  pushad
  mov edx,ebp
  mov ecx,ebp
  add ecx,$100000 // не трогать стек выше EBP+1Mb
  mov n,0
  lea edi,adrs
@01:
  mov eax,[edx+4]
  stosd
  mov edx,[edx]
  cmp edx,ebp
  jb @02
  cmp edx,ecx
  ja @02
  inc n
  cmp n,3
  jne @01
@02:
  popad
 end;
 stack:='[';
 for i:=n downto 1 do begin
  stack:=stack+inttohex(adrs[i],8);
  if i>1 then stack:=stack+'->';
 end;
 inherited Create(stack+'] '+msg);
 asm
  mov edx,[ebp+4]
  mov eax,self
  mov [eax].FAddress,edx
 end;
 {$ELSE}
  {$IFDEF FPC}
  inherited Create(msg+' caller: '+PtrToStr(get_caller_addr(get_frame)));
  {$ELSE}
  inherited Create(msg);
  {$ENDIF}
 {$ENDIF}
end;

constructor TBaseException.Create(const msg:String; fields:array of const);
begin
 Create(Format(msg,fields));
end;


initialization
 classAttributes.Init(100);
end.
