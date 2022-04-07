{$APPTYPE CONSOLE}
program TestStructs;
uses
  Apus.MyServis in '..\Apus.MyServis.pas',
  Apus.Structs in '..\Apus.Structs.pas', Apus.Types, Apus.Classes,
  SysUtils;

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
  writeln('Test ObjHash');
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
  writeln;
  writeln('ObjHash - OK');
 end;

procedure TestVarHash;
 var
  i,j,n:integer;
  keys:array[0..2000] of String8;
  values:array[0..2000] of variant;
  time:int64;
  name:String8;
  hash:TVarHash;
  value:variant;
  allKeys:StringArray8;
 begin
  writeln('Test VarHash');
  // -----
  for i:=0 to high(keys) do begin
   keys[i]:='Item #'+inttostr(i);
   values[i]:=i;
   hash.Put(keys[i],values[i]);
  end;
  // Remove some values
  for i:=1 to 1000 do begin
   n:=random(2000);
   hash.Remove(keys[n]);
   keys[n]:=''; values[n]:='';
  end;

  // Add some more... and remove some
  for i:=1 to 1000 do begin
   n:=random(2000);
   if keys[n]='' then begin // add
    keys[n]:='New item '+inttostr(n);
    values[n]:='Value '+inttostr(n);
    hash.Put(keys[n],values[n]);
   end;
   if i mod 5=0 then begin
    n:=random(2000); // delete
    hash.Remove(keys[n]);
    keys[n]:=''; values[n]:='';
   end;
  end;
  // Now check
  n:=0;
  for i:=0 to high(keys) do begin
   if keys[i]<>'' then begin
    inc(n);
    name:=Lowercase(keys[i]);
    value:=hash.Get(name);
    ASSERT(value=values[i],String(name));
   end;
  end;
  ASSERT(hash.count=n);
  // Check if no other objects
  allKeys:=hash.ListKeys;
  for name in allKeys do begin
   n:=ParseInt(name);
   ASSERT((n>=0) and (n<length(keys)));
   ASSERT(keys[n]=name);
   ASSERT(ParseInt(values[n])=n);
  end;
  writeln('VarHash - OK');
 end;


 type
  TChild=class(TNamedObject)
   class function ClassHash:pointer; override;
  end;

  TChild2=class(TChild)
  end;
 var
  childHash:TObjectHash;

procedure TestNamedObjects;
 var
  i:integer;
  a,b,c,obj:TNamedObject;
 begin
  a:=TNamedObject.Create;
  a.name:='Object A';
  b:=TChild.Create;
  b.name:='Object B';
  c:=TChild2.Create;
  c.name:='Object C';
  ASSERT(TChild.FindByName('object b')=b);
  ASSERT(TChild.FindByName('object c')=c);
  c.name:='Renamed C';
  ASSERT(b.FindByName('object b')=b);
  ASSERT(b.FindByName('renamed c')=c);
  ASSERT(b.FindByName('object c')=nil);
  b.Free;
  ASSERT(TChild.FindByName('object b')=nil);
  writeln('NamedObjects - OK');
 end;

{ TChild }

class function TChild.ClassHash: pointer;
 begin
  result:=@childHash;
 end;

procedure TestPriorityQueue;
 var
  i,size,cnt:integer;
  q:TPriorityQueue;
  buf:array[1..100] of byte;
  item:TDataItem;
  lastPrior:single;
 begin
  for size:=1 to 100 do begin
   for cnt:=1 to size do begin
    q.Init(size);
    zeromem(buf,sizeof(buf));
    // put items
    for i:=1 to cnt do begin
     item.value:=random(100);
     item.data:=i;
     buf[i]:=1;
     q.Add(item);
    end;
    // get items
    lastPrior:=100000;
    for i:=1 to cnt do begin
     ASSERT(q.Get(item));
     ASSERT(item.value<=lastPrior);
     lastPrior:=item.value;
     buf[item.data]:=0;
    end;
    ASSERT(q.IsEmpty);
    ASSERT(q.Get(item)=false);
    ASSERT(IsZeroMem(buf,sizeof(buf)));
   end;
  end;
  writeln('PriorityQueue - OK');
 end;

begin
 TestVarHash;
 TestObjHash;
 TestPriorityQueue;
 TestNamedObjects;
 if IsDebuggerPresent then Readln;
end.
