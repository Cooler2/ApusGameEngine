// This unit containing some base classes

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

unit Apus.Classes;
interface
uses Apus.Types;

type
 TObjectEx=class
  function Hash:cardinal; virtual;
  class procedure SetClassAttribute(attrName:String8;value:variant); // Assign arbitrary named attribute for the given class
  class function GetClassAttribute(attrName:String8):variant; // Get named attribute for this class (can be inherited from base class)
 end;

 TNamedObject=class(TObjectEx)
 protected
  fName:String8;
  procedure SetName(name:String8); virtual;
  function GetName:String8;
  class function ClassHash:pointer; virtual; // override this to provide a separate hash for object instances
 public
  destructor Destroy; override;
  function Hash:cardinal; override;
  property name:String8 read GetName write SetName;
  // Find object of given class by its name (case insensitive)
  class function FindByName(name:String8):TNamedObject; virtual;
 end;
 TNamedObjectClass=class of TNamedObject;
 TNamedObjects=array of TNamedObject;

implementation
uses Apus.MyServis, Apus.Structs;

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
 begin
  hash:=ClassHash;
  if hash<>nil then begin
    if fName<>'' then hash.Remove(self);
    fName:=name;
    if name<>'' then hash.Put(self);
   end
  else
   fName:=name;
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

initialization
 classAttributes.Init(100);
end.
