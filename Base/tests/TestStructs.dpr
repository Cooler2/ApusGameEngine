{$APPTYPE CONSOLE}
program TestStructs;
uses
  Apus.MyServis in '..\Apus.MyServis.pas',
  Apus.Structs in '..\Apus.Structs.pas',
  System.SysUtils;

procedure TestObjHash;
 var
  i,j,n:integer;
  objects:array[0..2000] of TNamedObject;
  time:int64;
  name:String8;
  hash:TObjectHash;
  obj:TNamedObject;
  keys:StringArray8;
  simpleHash:TSimpleHashAS;
 begin
{  hash.Init(10);
  for i:=0 to 30 do begin
   objects[i]:=TNamedObject.Create;
   objects[i].name:='Object_'+inttostr(i);
   hash.Put(objects[i]);
  end;
  for i:=0 to 20 do
   hash.Remove(objects[i]);}
  // -----
  for i:=0 to high(objects) do begin
   objects[i]:=TNamedObject.Create;
   objects[i].name:='Object #'+inttostr(i);
   hash.Put(objects[i]);
  end;
  // Remove some objects
  for i:=1 to 1000 do begin
   n:=random(2000);
   hash.Remove(objects[n]);
   FreeAndNil(objects[n]);
  end;
  // Add some more... and remove some
  for i:=1 to 1000 do begin
   n:=random(2000);
   if objects[n]=nil then begin // add
    objects[n]:=TNamedObject.Create;
    objects[n].name:='New Object '+inttostr(n);
    hash.Put(objects[n]);
   end;
   if i mod 5=0 then begin
    n:=random(2000); // delete
    hash.Remove(objects[n]);
    FreeAndNil(objects[n]);
   end;
  end;
  // Now check
  n:=0;
  for i:=0 to high(objects) do begin
   if objects[i]<>nil then begin
    inc(n);
    name:=Lowercase(objects[i].name);
    obj:=hash.Get(name);
    ASSERT(obj=objects[i],String(name));
   end;
  end;
  ASSERT(hash.count=n);
  // Check if no other objects
  keys:=hash.ListKeys;
  for name in keys do begin
   n:=ParseInt(name);
   ASSERT((n>=0) and (n<length(objects)));
   ASSERT(objects[n]<>nil);
   ASSERT(objects[n].name=name);
  end;
  // Test speed
  time:=MyTickCount;
  for i:=1 to 500 do begin
   hash.Clear;
   for j:=0 to high(objects) do
    if objects[j]<>nil then
     hash.Put(objects[j]);
  end;
  write(' add: ',MyTickCount-time);

  keys:=hash.ListKeys;
  for i:=0 to high(keys) do
   keys[i]:=UpperCase(keys[i]);

  time:=MyTickCount;
  for i:=1 to 500 do begin
   for j:=0 to high(keys) do
    hash.Get(keys[j]);
  end;
  write(' get: ',MyTickCount-time);
  // Compare with SimpleHash
  simpleHash.Init(2048);
  time:=MyTickCount;
  for i:=1 to 500 do begin
   simpleHash.Clear;
   for j:=0 to high(objects) do
    if objects[j]<>nil then
     simpleHash.Put(objects[j].name,UIntPtr(objects[j]));
  end;
  write(' simple.add: ',MyTickCount-time);
  time:=MyTickCount;
  for i:=1 to 500 do begin
   for j:=0 to high(objects) do
    if objects[j]<>nil then
     simpleHash.Get(objects[j].name);
  end;
  write(' simple.get: ',MyTickCount-time);
  writeln('ObjHash - OK');
 end;

procedure TestNamedObjects;
 begin
  TNamedObject.TrackObjectNames;

 end;

begin
 TestObjHash;
 TestNamedObjects;
end.
