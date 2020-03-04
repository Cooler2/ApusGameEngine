program UStructs;
uses structs,
     classes,Windows,SysUtils,hashes;

procedure TestTree;
var
 t:TGenericTree;
begin
 t:=TGenericTree.Create(true,false);
 t.data:=TList.Create;
 t.AddChild(TList.Create);
 t.AddChild(TStrings.Create);
 t.Destroy;
end;

procedure TestHash;
 var
  i,j,t:integer;
  h:TStrHash;
  h2:TIntegerHash;
  v:^integer;
  st:string;
  a:array[1..16384] of integer;
  keys:array[1..16384] of string;
 begin
  h:=TStrHash.CreateSize(256);
  h2:=TIntegerHash.Create;
  for i:=1 to 10000 do begin
   a[i]:=random(1000000);
   keys[i]:=inttostr(a[i]);
   h.Put(keys[i],addr(a[i]));
   h2.Items[keys[i]]:=a[i];
  end;
  readln;
  t:=GetTickCount;
  for i:=1 to 100000 do begin
   j:=i*2738 mod 10000;
   //v:=h.Get(keys[j+1]);
   if h2.Items[keys[j+1]]<>a[j+1] then write('Error');
   //if v^<>a[j+1] then writeln('Error');
  end;
  writeln('Time is: '+inttostr(GetTickCount-t));
  readln;
 end;

begin
 //TestHash;
end.
