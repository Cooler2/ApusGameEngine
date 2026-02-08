// This unit containing some base classes
//
// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Classes;
interface
uses SysUtils,Apus.Types;

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
    function ObjInfo:string; virtual;
  end;
  TNamedObjectClass=class of TNamedObject;
  TNamedObjects=array of TNamedObject;

  // Base exception with stack trace support
  TBaseException=class(Exception)
  private
    FAddress:NativeUInt;
  public
    constructor Create(const msg:string); overload;
    constructor Create(const msg:string;fields:array of const); overload;
    property Address:NativeUInt read FAddress;
  end;

  // Warning should be raised in situations when attention needs to be drawn
  // to an abnormal situation which nevertheless doesn't prevent normal operation.
  // No additional actions from upper level required.
  // (e.g.: procedure couldn't complete but this doesn't break upper level operation)
  EWarning=class(TBaseException);

  // Regular error - situation when program execution is clearly violated
  // and continuation is possible only if upper level handles the error and takes measures.
  // (e.g.: function couldn't perform required actions and didn't return result. Obviously,
  // normal continuation is possible only if upper level refuses to use the result)
  EError=class(TBaseException);

  // Fatal error - continuation is impossible, upper level must initiate
  // program termination. This exception should be used when
  // error cannot be fixed by upper level.
  // (e.g.: something detected that shouldn't be possible, i.e. result of data corruption
  // or algorithm error leading to fundamentally incorrect operation. To avoid
  // possible data corruption on subsequent calls, should terminate immediately)
  EFatalError=class(TBaseException);

implementation
uses Apus.Common,Apus.Structs;

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

function TNamedObject.Hash:cardinal;
begin
  result:=FastHash(name);
end;

function TNamedObject.ObjInfo:string;
begin
  if self=nil then exit('[NIL]');
  result:=ClassName+'('+fName+','+PtrToStr(self)+')';
end;

procedure TNamedObject.SetName(name:String8);
var
  hash:PObjectHash;
  un,newUn:boolean;
  existing:TObject;
begin
  hash:=ClassHash;
  if hash<>nil then begin
    un:=UniqueName(fName);
    newUn:=UniqueName(name);
    // Remove old name from hash if it was unique
    if un then hash.Remove(self);
    // Check for duplicate before inserting
    if newUn then begin
      existing:=hash.Get(name);
      if (existing<>nil) and (existing<>self) then
        raise EWarning.Create(Format('Duplicate object name %s(%s)',[ClassName,name]));
    end;
    fName:=name;
    // Add new name to hash if it's unique
    if newUn then hash.Put(self);
  end else
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
  inherited;
end;


{ TObjectEx }

function TObjectEx.Hash:cardinal;
begin
  result:=cardinal(NativeUInt(pointer(self)));
end;

class procedure TObjectEx.SetClassAttribute(attrName:String8;value:variant);
begin
  classAttributes.Put(className+'.'+attrName,value);
end;

class function TObjectEx.GetClassAttribute(attrName:String8):variant;
var
  cls:TClass;
  key:String8;
begin
  cls:=self;
  repeat
    key:=cls.className+'.'+attrName;
    result:=classAttributes.Get(key);
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
constructor TBaseException.Create(const msg:string);
{$IFDEF CPU386}
var
  stack:string;
  n,i:integer;
  adrs:array[1..6] of cardinal;
{$ENDIF}
begin
  {$IFDEF CPU386}
  asm
    pushad
    mov edx,ebp
    mov ecx,ebp
    add ecx,$100000 // don't touch stack above EBP+1Mb
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
    FAddress:=NativeUInt(get_caller_addr(get_frame));
    inherited Create(msg+' caller: '+PtrToStr(pointer(FAddress)));
    {$ELSE}
    FAddress:=0;
    inherited Create(msg);
    {$ENDIF}
  {$ENDIF}
end;

constructor TBaseException.Create(const msg:String;fields:array of const);
begin
  Create(Format(msg,fields));
end;


initialization
  classAttributes.Init(100);

finalization
  classAttributes.Clear;

end.
