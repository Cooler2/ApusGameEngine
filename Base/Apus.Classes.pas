unit Apus.Classes;
interface
uses Apus.Types;

type
 TObjectEx=class
  function Hash:cardinal; virtual;
 end;

 TNamedObject=class(TObjectEx)
 protected
  fName:String8;
  procedure SetName(name:String8); virtual;
  class function ClassHash:pointer; virtual; // override this to provide hash for object instances
 public
  destructor Destroy; override;
  function Hash:cardinal; override;
  property name:String8 read fName write SetName;
  // Find object of given class by its name (case insensitive)
  class function FindByName(name:String8):TNamedObject; virtual;
 end;
 TNamedObjectClass=class of TNamedObject;
 TNamedObjects=array of TNamedObject;

implementation
uses Apus.MyServis, Apus.Structs;

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

function TNamedObject.Hash: cardinal;
 begin
  result:=FastHash(name);
 end;

procedure TNamedObject.SetName(name:String8);
 var
  n:integer;
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

end.
