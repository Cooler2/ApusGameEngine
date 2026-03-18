// This unit containing some base classes
//
// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Classes;
interface
uses Apus.Core, Apus.Types;

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

  // Exception classes are now in Apus.Core:
  // TBaseException, EWarning, EError, EFatalError

implementation
uses SysUtils,    // Format
     Apus.Strings, // FastHash
     Apus.Conv,    // ToStr, HasValue
     Apus.HashMaps;

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
  result:=ClassName+'('+fName+','+Conv.ToStr(pointer(self))+')';
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



initialization
  classAttributes.Init(100);

finalization
  classAttributes.Clear;

end.
