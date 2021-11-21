unit Apus.Classes;
interface
uses Apus.Types;

type
 TObjectEx=class
  function Hash:cardinal;
 end;

 TNamedObject=class(TObjectEx)
 protected
  fName:String8;
  procedure SetName(name:String8); virtual;
 public
  property name:String8 read fName write SetName;
  // Maintain list of objects of this class so they can be found by name
  class procedure TrackObjectNames; virtual;
  // Find object of given class by its name (case insensitive)
  class function FindByName(name:String8):TNamedObject; virtual;
 private
  class var trackRecordID:integer; // for this class
  // find trackRecordID of this class or its parents
  class function FindClassTrackRecord:integer; // -1 - not found (untracked)
 end;
 TNamedObjectClass=class of TNamedObject;

implementation
uses Apus.MyServis,Apus.Structs;

type
 TTrackedClass=record
  objClass:TClass;
  hash:TSimpleHashAS;
 end;

var
 trackedClasses:array of TTrackedClass;
 lock:integer;

{ TNamedObject }

class function TNamedObject.FindByName(name:String8):TNamedObject;
 var
  n:integer;
  val:int64;
 begin
  n:=FindClassTrackRecord;
  if n<0 then
    raise EWarning.Create('Can''t find object "%s": class "%s" is not tracked',[name,className]);
  val:=trackedClasses[n].hash.Get(name);
  result:=TNamedObject(pointer(val));
 end;

class procedure TNamedObject.TrackObjectNames;
 var
  n:integer;
 begin
  SpinLock(lock);
  try
   n:=length(trackedClasses);
   SetLength(trackedClasses,n+1);
   trackedClasses[n].objClass:=self;
   trackedClasses[n].hash.Init(256);
   trackRecordID:=$10000+n;
  finally
   lock:=0;
  end;
 end;

class function TNamedObject.FindClassTrackRecord:integer;
 var
  cls:TNamedObjectClass;
 begin
  cls:=self;
  while cls.trackRecordID=0 do
   if cls<>TNamedObject then
    cls:=TNamedObjectClass(cls.ClassParent)
   else
    break;
  if cls.trackRecordID=0 then exit(-1); // object of an untracked class
  result:=cls.trackRecordID and $FFFF;
  ASSERT(cls=trackedClasses[result].objClass);
 end;

procedure TNamedObject.SetName(name:String8);
 var
  n:integer;
 begin
  n:=FindClassTrackRecord;
  if n>0 then
   with trackedClasses[n] do begin
    if fName<>'' then
     hash.Remove(fName);
    if name<>'' then begin
     if hash.HasValue(name) then
       LogMessage('Duplicated object name: "%d" of class "%s"',[name,className]);
     hash.Put(name,UIntPtr(self));
    end;
   end;
  fName:=name;
 end;

{ TObjectEx }

function TObjectEx.Hash:cardinal;
 begin
  result:=cardinal(pointer(self));
 end;

end.
