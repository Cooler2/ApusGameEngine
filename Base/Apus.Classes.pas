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
 end;

implementation

{ TNamedObject }

procedure TNamedObject.SetName(name: String8);
 begin
  fName:=name;
 end;

{ TObjectEx }

function TObjectEx.Hash:cardinal;
 begin
  result:=cardinal(pointer(self));
 end;

end.
