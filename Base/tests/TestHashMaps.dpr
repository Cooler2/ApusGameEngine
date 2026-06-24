{$APPTYPE CONSOLE}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
program TestHashMaps;
uses
  SysUtils,
  Variants,
  Apus.Core,
  Apus.Classes,
  Apus.HashMaps;

{$INCLUDE Test.inc}

type
  String8 = UTF8String; // local alias for generic specialization visibility

  TPoint = record
    x,y:integer;
  end;

  TStrIntMap = THashMap<integer>;
  TStrStrMap = THashMap<String8>;
  TStrDblMap = THashMap<double>;
  TStrPointMap = THashMap<TPoint>;

  TGlyphRec = record
    x,y:smallint;
    w,h:shortint;
    dx,dy:shortint;
  end;
  TNumIntMap = THashMapNum<integer>;
  TNumGlyphMap = THashMapNum<TGlyphRec>;

  TTestNamedObject=class(TNamedObject)
  end;

{ --- Tests --- }

procedure TestBasicOps;
var
  m:TStrIntMap;
  v:integer;
begin
  StartTest('GenHash.BasicOps');
  m.Init;
  Check(m.count=0, 'empty count');
  Check(not m.HasKey('x'), 'empty haskey');
  Check(not m.Get('x',v), 'empty get');
  m.Put('alpha',1);
  m.Put('beta',2);
  m.Put('gamma',3);
  Check(m.count=3, 'count=3');
  Check(m.Get('alpha',v) and (v=1), 'get alpha');
  Check(m.Get('beta',v) and (v=2), 'get beta');
  Check(m.Get('gamma',v) and (v=3), 'get gamma');
  m.Put('beta',20);
  Check(m.Get('beta',v) and (v=20), 'updated beta');
  Check(m.count=3, 'count still 3');
  m.Remove('beta');
  Check(not m.HasKey('beta'), 'beta removed');
  Check(m.count=2, 'count=2');
  Check(m.Get('alpha',v) and (v=1), 'alpha intact');
  Check(m.Get('gamma',v) and (v=3), 'gamma intact');
  m.Remove('delta');
  Check(m.count=2, 'count unchanged');
  Check(m.GetDef('alpha',-1)=1, 'getdef existing');
  Check(m.GetDef('missing',-1)=-1, 'getdef missing');
  EndTest;
end;

procedure TestAutoInit;
var
  m:TStrIntMap;
  v:integer;
begin
  StartTest('GenHash.AutoInit');
  FillChar(m,SizeOf(m),0);
  // Get/HasKey on uninitialized map — should not crash
  Check(not m.HasKey('x'), 'uninit haskey');
  Check(not m.Get('x',v), 'uninit get');
  // Put triggers auto-init
  m.Put('test',42);
  Check(m.Get('test',v) and (v=42), 'auto-init put/get');
  Check(m.count=1, 'count=1');
  EndTest;
end;

procedure TestCaseInsensitive;
var
  m:TStrIntMap;
  v:integer;
begin
  StartTest('GenHash.CaseInsensitive');
  m.Init;
  m.Put('Hello',1);
  Check(m.Get('hello',v) and (v=1), 'lowercase');
  Check(m.Get('HELLO',v) and (v=1), 'uppercase');
  Check(m.Get('HeLLo',v) and (v=1), 'mixed case');
  m.Put('HELLO',2);
  Check(m.count=1, 'count=1 after case update');
  Check(m.Get('hello',v) and (v=2), 'value updated');
  m.Remove('hElLo');
  Check(m.count=0, 'removed via different case');
  EndTest;
end;

procedure TestStringValues;
var
  m:TStrStrMap;
  v:String8;
begin
  StartTest('GenHash.StringValues');
  m.Init;
  m.Put('name','Alice');
  m.Put('city','Moscow');
  Check(m.Get('name',v) and (v='Alice'), 'get name');
  Check(m.Get('city',v) and (v='Moscow'), 'get city');
  m.Put('name','Bob');
  Check(m.Get('name',v) and (v='Bob'), 'updated name');
  m.Remove('city');
  Check(not m.HasKey('city'), 'city removed');
  Check(m.Get('name',v) and (v='Bob'), 'name intact');
  EndTest;
end;

procedure TestFloatValues;
var
  m:TStrDblMap;
  v:double;
begin
  StartTest('GenHash.FloatValues');
  m.Init;
  m.Put('pi',3.14159265);
  m.Put('e',2.71828182);
  m.Put('phi',1.61803398);
  Check(m.Get('pi',v) and (abs(v-3.14159265)<1e-8), 'pi');
  Check(m.Get('e',v) and (abs(v-2.71828182)<1e-8), 'e');
  Check(m.Get('phi',v) and (abs(v-1.61803398)<1e-8), 'phi');
  EndTest;
end;

procedure TestRecordValues;
var
  m:TStrPointMap;
  p:TPoint;
begin
  StartTest('GenHash.RecordValues');
  m.Init;
  p.x:=10; p.y:=20;
  m.Put('origin',p);
  p.x:=100; p.y:=200;
  m.Put('far',p);
  Check(m.Get('origin',p) and (p.x=10) and (p.y=20), 'origin point');
  Check(m.Get('far',p) and (p.x=100) and (p.y=200), 'far point');
  p.x:=0; p.y:=0;
  m.Put('origin',p);
  Check(m.Get('origin',p) and (p.x=0) and (p.y=0), 'updated origin');
  EndTest;
end;

procedure TestResize;
var
  m:TStrIntMap;
  v,i:integer;
  allOk:boolean;
  failMsg:String8;
begin
  StartTest('GenHash.Resize');
  m.Init(4);
  for i:=0 to 999 do
    m.Put('key'+IntToStr(i), i);
  Check(m.count=1000, 'count=1000');
  allOk:=true;
  failMsg:='';
  for i:=0 to 999 do
    if not (m.Get('key'+IntToStr(i),v) and (v=i)) then begin
      allOk:=false;
      failMsg:='GenHash.Resize key'+IntToStr(i)+' expected='+IntToStr(i)+' got='+IntToStr(v);
      break;
    end;
  Check(allOk,'GenHash.Resize all 1000 values correct; '+failMsg);
  EndTest;
end;

procedure TestRemoveChain;
var
  m:TStrIntMap;
  v,i:integer;
  oddOk,evenOk,reinsertOk:boolean;
  failMsg:String8;
begin
  StartTest('GenHash.RemoveChain');
  m.Init(4);
  for i:=0 to 49 do
    m.Put('item'+IntToStr(i), i);
  Check(m.count=50, 'count=50');
  for i:=0 to 24 do
    m.Remove('item'+IntToStr(i*2));
  Check(m.count=25, 'count=25 after remove');
  oddOk:=true;
  failMsg:='';
  for i:=0 to 24 do
    if not (m.Get('item'+IntToStr(i*2+1),v) and (v=i*2+1)) then begin
      oddOk:=false;
      failMsg:='odd item '+IntToStr(i*2+1)+' mismatch';
      break;
    end;
  Check(oddOk,'GenHash.RemoveChain odd items intact; '+failMsg);
  evenOk:=true;
  failMsg:='';
  for i:=0 to 24 do
    if m.HasKey('item'+IntToStr(i*2)) then begin
      evenOk:=false;
      failMsg:='even item '+IntToStr(i*2)+' was not removed';
      break;
    end;
  Check(evenOk,'GenHash.RemoveChain even items removed; '+failMsg);
  for i:=0 to 24 do
    m.Put('item'+IntToStr(i*2), i*200);
  Check(m.count=50, 'count=50 after reinsert');
  reinsertOk:=true;
  failMsg:='';
  for i:=0 to 24 do begin
    if not (m.Get('item'+IntToStr(i*2),v) and (v=i*200)) then begin
      reinsertOk:=false;
      failMsg:='reinserted even '+IntToStr(i*2)+' mismatch';
      break;
    end;
    if not (m.Get('item'+IntToStr(i*2+1),v) and (v=i*2+1)) then begin
      reinsertOk:=false;
      failMsg:='still odd '+IntToStr(i*2+1)+' mismatch';
      break;
    end;
  end;
  Check(reinsertOk,'GenHash.RemoveChain reinsert verification; '+failMsg);
  EndTest;
end;

procedure TestClear;
var
  m:TStrIntMap;
  v:integer;
begin
  StartTest('GenHash.Clear');
  m.Init;
  m.Put('a',1);
  m.Put('b',2);
  m.Put('c',3);
  m.Clear;
  Check(m.count=0, 'count=0 after clear');
  Check(not m.HasKey('a'), 'a gone');
  Check(not m.HasKey('b'), 'b gone');
  Check(not m.HasKey('c'), 'c gone');
  m.Put('d',4);
  Check(m.count=1, 'count=1 after reuse');
  Check(m.Get('d',v) and (v=4), 'get d');
  EndTest;
end;

procedure TestGenericEdgeCases;
var
  m:TStrIntMap;
  v:integer;
begin
  StartTest('GenHash.EdgeCases');
  FillChar(m,SizeOf(m),0);
  m.Put('',123);
  Check(m.count=0, 'empty key ignored');
  Check(not m.Get('',v), 'empty key get=false');
  Check(not m.HasKey(''), 'empty key haskey=false');
  m.Remove('');
  Check(m.count=0, 'empty key remove no-op');

  m.Init(1);
  m.Put('a',1);
  m.Put('b',2);
  m.Remove('missing');
  Check(m.count=2, 'remove missing keeps count');
  m.Clear;
  Check(not m.Get('a',v), 'clear removed a');
  Check(not m.Get('b',v), 'clear removed b');
  EndTest;
end;

procedure TestLegacyStrHash;
var
  h:TStrHash;
  k1,k2:string;
  v1,v2,v3:integer;
  p:pointer;
  keys:Strings;
  values:PointerArray;
begin
  StartTest('Legacy.TStrHash');
  h:=TStrHash.Create;
  try
    k1:='alpha';
    k2:='beta';
    v1:=11; v2:=22; v3:=33;

    h.Put(k1,@v1);
    h.Put(k2,@v2);
    Check(h.Hcount=2, 'hcount=2');

    p:=h.Get('alpha');
    Check(p=@v1, 'get alpha');
    p:=h.Get('beta');
    Check(p=@v2, 'get beta');
    p:=h.Get('missing');
    Check(p=nil, 'get missing=nil');

    h.Put(k1,@v3);
    p:=h.Get('alpha');
    Check(p=@v3, 'update alpha');

    h.Remove('missing');
    Check(h.Get('beta')=@v2, 'remove missing keeps beta');
    h.Remove('beta');
    Check(h.Get('beta')=nil, 'beta removed');

    Check(h.FirstKey<>'', 'firstkey not empty');
    Check(h.NextKey='','nextkey at end (single key)');
    keys:=h.GetKeys;
    values:=h.GetValues;
    Check(length(keys)=1, 'keys length=1');
    Check(length(values)=1, 'values length=1');
  finally
    h.Free;
  end;
  EndTest;
end;

procedure TestTHashSingle;
var
  h:THash;
  v:variant;
  keys:Strings8;
begin
  StartTest('THash.Single');
  h.Init(false);

  h.Put('a',10);
  h.Put('b',20);
  Check(h.HasKey('a'), 'has a');
  Check(h.Get('a')=10, 'get a=10');
  h.Put('a',15);
  Check(h.Get('a')=15, 'replace a=15');
  v:=h.Get('missing');
  Check(VarIsEmpty(v), 'missing is empty variant');

  keys:=h.AllKeys;
  Check(length(keys)=2, 'allkeys length=2');
  h.SortKeys;
  Check(h.Get('a')=15, 'sorted get a');
  Check(h.Get('b')=20, 'sorted get b');

  h.Remove('b');
  Check(not h.HasKey('b'), 'b removed');
  EndTest;
end;

procedure TestTHashMulti;
var
  h:THash;
  all:VariantArray;
begin
  StartTest('THash.Multi');
  h.Init(true);

  h.Put('k',1);
  h.Put('k',2);
  h.Put('k',3);
  all:=h.GetAll('k');
  Check(length(all)=3, '3 values added');
  Check(all[0]=1, 'all[0]=1');
  Check(all[1]=2, 'all[1]=2');
  Check(all[2]=3, 'all[2]=3');

  Check(h.Get('k')=1, 'get first');
  Check(h.GetNext=2, 'getnext second');
  Check(h.GetNext=3, 'getnext third');
  Check(VarIsEmpty(h.GetNext), 'getnext empty');

  h.Put('k',100,true);
  all:=h.GetAll('k');
  Check(length(all)=1, 'replace leaves one value');
  Check(all[0]=100, 'replace value=100');
  EndTest;
end;

procedure TestSimpleHash;
var
  h:TSimpleHash;
begin
  StartTest('TSimpleHash');
  h.Init(8);
  Check(h.Get(1)=-1, 'missing=-1');
  h.Put(1,10);
  h.Put(1,20);
  Check(h.Get(1)=20, 'update value');
  Check(h.Increment(1,5)=25, 'increment existing');
  Check(h.Increment(2)=1, 'increment new');
  Check(h.HasValue(1), 'has key=1');
  Check(h.HasValue(2), 'has key=2');
  h.Remove(1);
  Check(not h.HasValue(1), 'removed key=1');
  Check(h.Get(1)=-1, 'removed get=-1');
  // RemoveValue: remove all keys whose value matches
  h.Put(10,99);
  h.Put(11,99);
  h.Put(12,77);
  h.RemoveValue(99);
  Check(not h.HasValue(10),'removevalue: key=10 gone');
  Check(not h.HasValue(11),'removevalue: key=11 gone');
  Check(h.HasValue(12),'removevalue: key=12 intact');
  h.Clear;
  Check(not h.HasValue(2),'clear removed key=2');
  EndTest;
end;

procedure TestLegacySimpleHashS;
var
  h:TSimpleHashS;
begin
  StartTest('Legacy.TSimpleHashS');
  h.Init(8);
  Check(h.Get('a')=-1, 'missing=-1');
  h.Put('a',10);
  h.Put('a',20);
  Check(h.Get('a')=20, 'update value');
  Check(h.Increment('a',5)=25, 'increment existing');
  Check(h.Increment('b')=1, 'increment new');
  Check(h.HasValue('a'), 'has a');
  Check(h.HasValue('b'), 'has b');
  h.Remove('a');
  Check(not h.HasValue('a'), 'removed a');
  Check(h.Get('a')=-1, 'removed get=-1');
  h.Clear;
  Check(not h.HasValue('b'), 'clear removed b');
  EndTest;
end;

procedure TestLegacySimpleHashAS;
var
  h:TSimpleHashAS;
begin
  StartTest('Legacy.TSimpleHashAS');
  h.Init(8);
  Check(h.Get('a')=-1, 'missing=-1');
  h.Put('a',10);
  h.Put('a',20);
  Check(h.Get('a')=20, 'update value');
  Check(h.Increment('a',5)=25, 'increment existing');
  Check(h.Increment('b')=1, 'increment new');
  Check(h.HasValue('a'), 'has a');
  Check(h.HasValue('b'), 'has b');
  h.Remove('a');
  Check(not h.HasValue('a'), 'removed a');
  Check(h.Get('a')=-1, 'removed get=-1');
  h.Clear;
  Check(not h.HasValue('b'), 'clear removed b');
  EndTest;
end;

procedure TestObjectHash;
var
  h:TObjectHash;
  a,b:TTestNamedObject;
  keys:Strings8;
  objs:TNamedObjects;
begin
  StartTest('TObjectHash');
  h.Init(4);
  Check(h.Get('missing')=nil, 'missing=nil');

  a:=TTestNamedObject.Create;
  b:=TTestNamedObject.Create;
  try
    a.name:='Object A';
    b.name:='Object B';
    h.Put(a);
    h.Put(b);
    h.Put(nil); // ignored

    Check(h.count=2, 'count=2');
    Check(h.Get('object a')=a, 'get a case-insensitive');
    Check(h.Get('OBJECT B')=b, 'get b case-insensitive');

    keys:=h.ListKeys;
    objs:=h.ListObjects;
    Check(length(keys)=2, 'listkeys len=2');
    Check(length(objs)=2, 'listobjects len=2');

    h.Remove(a);
    Check(h.Get('object a')=nil, 'a removed');
    Check(h.Get('object b')=b, 'b still present');
    h.Clear;
    Check(h.count=0, 'count=0 after clear');
  finally
    a.Free;
    b.Free;
  end;
  EndTest;
end;

procedure TestTHashLargeTable;
var
  h:THash;
  i:integer;
  allOk:boolean;
  failMsg:String8;
begin
  StartTest('Legacy.THash.LargeTable');
  h.Init(false);
  for i:=0 to 9999 do
    h.Put('key_'+IntToStr(i), i);
  Check(h.count=10000, 'count=10000');
  allOk:=true;
  failMsg:='';
  for i:=0 to 9999 do
    if integer(h.Get('key_'+IntToStr(i)))<>i then begin
      allOk:=false;
      failMsg:='key_'+IntToStr(i)+' mismatch';
      break;
    end;
  Check(allOk, 'all 10K values correct; '+failMsg);
  Check(VarIsEmpty(h.Get('nosuchkey')), 'miss returns empty');
  EndTest;
end;

procedure TestLegacyVarHash;
var
  h:TVarHash;
  v:variant;
  keys:Strings8;
begin
  StartTest('Legacy.TVarHash');
  h.Init(4);
  Check(not h.HasKey('a'), 'empty haskey=false');
  Check(VarIsEmpty(h.Get('a')), 'empty get=Unassigned');

  h.Put('a',10);
  h.Put('b','text');
  h.Put('',123); // ignored
  Check(h.HasKey('a'), 'has a');
  Check(h.HasKey('b'), 'has b');
  v:=h.Get('a');
  Check(v=10, 'get a=10');
  v:=h.Get('b');
  Check(v='text', 'get b=text');

  h.Put('a',11); // replace
  Check(h.Get('a')=11, 'replace a=11');

  keys:=h.ListKeys;
  Check(length(keys)=2, 'listkeys has 2 items');

  h.Remove('a');
  Check(not h.HasKey('a'), 'removed a');
  Check(VarIsEmpty(h.Get('a')), 'removed get=Unassigned');
  h.Remove('missing');
  h.Clear;
  Check(not h.HasKey('b'), 'clear removed b');
  EndTest;
end;

{ --- THashMapNum<T> tests --- }

procedure TestNumBasicOps;
var
  m:TNumIntMap;
  v:integer;
begin
  StartTest('NumHash.BasicOps');
  m.Init;
  Check(m.count=0, 'empty count');
  Check(not m.HasKey(1), 'empty haskey');
  Check(not m.Get(1,v), 'empty get');
  m.Put(100,1);
  m.Put(200,2);
  m.Put(300,3);
  Check(m.count=3, 'count=3');
  Check(m.Get(100,v) and (v=1), 'get 100');
  Check(m.Get(200,v) and (v=2), 'get 200');
  Check(m.Get(300,v) and (v=3), 'get 300');
  m.Put(200,20);
  Check(m.Get(200,v) and (v=20), 'updated 200');
  Check(m.count=3, 'count still 3');
  m.Remove(200);
  Check(not m.HasKey(200), '200 removed');
  Check(m.count=2, 'count=2');
  Check(m.Get(100,v) and (v=1), '100 intact');
  Check(m.Get(300,v) and (v=3), '300 intact');
  m.Remove(999);
  Check(m.count=2, 'count unchanged');
  Check(m.GetDef(100,-1)=1, 'getdef existing');
  Check(m.GetDef(999,-1)=-1, 'getdef missing');
  EndTest;
end;

procedure TestNumZeroAndNegKeys;
var
  m:TNumIntMap;
  v:integer;
begin
  StartTest('NumHash.ZeroAndNegKeys');
  m.Init;
  // key 0 must be a valid, storable key (no sentinel reliance)
  m.Put(0,42);
  Check(m.HasKey(0), 'has key 0');
  Check(m.Get(0,v) and (v=42), 'get key 0');
  m.Put(-1,7);
  m.Put(int64($7FFFFFFFFFFFFFFF),9); // max int64
  Check(m.Get(-1,v) and (v=7), 'get negative key');
  Check(m.Get(int64($7FFFFFFFFFFFFFFF),v) and (v=9), 'get max int64 key');
  Check(m.count=3, 'count=3');
  m.Remove(0);
  Check(not m.HasKey(0), 'key 0 removed');
  Check(m.Get(-1,v) and (v=7), 'negative key intact after removing 0');
  EndTest;
end;

procedure TestNumAutoInit;
var
  m:TNumIntMap;
  v:integer;
begin
  StartTest('NumHash.AutoInit');
  FillChar(m,SizeOf(m),0);
  Check(not m.HasKey(5), 'uninit haskey');
  Check(not m.Get(5,v), 'uninit get');
  m.Remove(5); // no crash on uninit
  m.Put(5,42);
  Check(m.Get(5,v) and (v=42), 'auto-init put/get');
  Check(m.count=1, 'count=1');
  EndTest;
end;

procedure TestNumRecordValues;
var
  m:TNumGlyphMap;
  g:TGlyphRec;
begin
  StartTest('NumHash.RecordValues');
  Check(SizeOf(TGlyphRec)=8, 'TGlyphRec is 8 bytes');
  m.Init;
  g.x:=300; g.y:=200; g.w:=12; g.h:=16; g.dx:=-5; g.dy:=3;
  m.Put($410041,g); // chardata-like key
  g.x:=10; g.y:=20; g.w:=8; g.h:=8; g.dx:=0; g.dy:=-1;
  m.Put($420042,g);
  Check(m.Get($410041,g) and (g.x=300) and (g.y=200) and (g.w=12) and (g.h=16)
        and (g.dx=-5) and (g.dy=3), 'first glyph round-trip');
  Check(m.Get($420042,g) and (g.x=10) and (g.dy=-1), 'second glyph round-trip');
  g.x:=999; g.y:=888; g.w:=1; g.h:=1; g.dx:=1; g.dy:=1;
  m.Put($410041,g);
  Check(m.Get($410041,g) and (g.x=999) and (g.y=888), 'updated glyph');
  EndTest;
end;

procedure TestNumResize;
var
  m:TNumIntMap;
  v,i:integer;
  allOk:boolean;
  failMsg:String8;
begin
  StartTest('NumHash.Resize');
  m.Init(4);
  for i:=0 to 999 do
    m.Put(i*7+1, i);
  Check(m.count=1000, 'count=1000');
  allOk:=true;
  failMsg:='';
  for i:=0 to 999 do
    if not (m.Get(i*7+1,v) and (v=i)) then begin
      allOk:=false;
      failMsg:='key '+IntToStr(i*7+1)+' expected='+IntToStr(i)+' got='+IntToStr(v);
      break;
    end;
  Check(allOk,'NumHash.Resize all 1000 values correct; '+failMsg);
  EndTest;
end;

procedure TestNumRemoveChain;
var
  m:TNumIntMap;
  v,i:integer;
  oddOk,evenOk,reinsertOk:boolean;
  failMsg:String8;
begin
  StartTest('NumHash.RemoveChain');
  m.Init(4);
  for i:=0 to 49 do
    m.Put(i, i*10);
  Check(m.count=50, 'count=50');
  for i:=0 to 24 do
    m.Remove(i*2);
  Check(m.count=25, 'count=25 after remove');
  oddOk:=true; failMsg:='';
  for i:=0 to 24 do
    if not (m.Get(i*2+1,v) and (v=(i*2+1)*10)) then begin
      oddOk:=false; failMsg:='odd '+IntToStr(i*2+1)+' mismatch'; break;
    end;
  Check(oddOk,'NumHash.RemoveChain odd items intact; '+failMsg);
  evenOk:=true; failMsg:='';
  for i:=0 to 24 do
    if m.HasKey(i*2) then begin
      evenOk:=false; failMsg:='even '+IntToStr(i*2)+' not removed'; break;
    end;
  Check(evenOk,'NumHash.RemoveChain even items removed; '+failMsg);
  for i:=0 to 24 do
    m.Put(i*2, i*200);
  Check(m.count=50, 'count=50 after reinsert');
  reinsertOk:=true; failMsg:='';
  for i:=0 to 24 do begin
    if not (m.Get(i*2,v) and (v=i*200)) then begin
      reinsertOk:=false; failMsg:='reinserted even '+IntToStr(i*2)+' mismatch'; break;
    end;
    if not (m.Get(i*2+1,v) and (v=(i*2+1)*10)) then begin
      reinsertOk:=false; failMsg:='still odd '+IntToStr(i*2+1)+' mismatch'; break;
    end;
  end;
  Check(reinsertOk,'NumHash.RemoveChain reinsert verification; '+failMsg);
  EndTest;
end;

procedure TestNumClear;
var
  m:TNumIntMap;
  v:integer;
begin
  StartTest('NumHash.Clear');
  m.Init;
  m.Put(1,1); m.Put(2,2); m.Put(3,3);
  m.Clear;
  Check(m.count=0, 'count=0 after clear');
  Check(not m.HasKey(1), '1 gone');
  Check(not m.HasKey(2), '2 gone');
  m.Put(4,4);
  Check(m.count=1, 'count=1 after reuse');
  Check(m.Get(4,v) and (v=4), 'get 4');
  EndTest;
end;

begin
  try
    TestBasicOps;
    TestAutoInit;
    TestCaseInsensitive;
    TestStringValues;
    TestFloatValues;
    TestRecordValues;
    TestResize;
    TestRemoveChain;
    TestClear;
    TestGenericEdgeCases;

    TestNumBasicOps;
    TestNumZeroAndNegKeys;
    TestNumAutoInit;
    TestNumRecordValues;
    TestNumResize;
    TestNumRemoveChain;
    TestNumClear;

    TestLegacyStrHash;
    TestTHashSingle;
    TestTHashMulti;
    TestTHashLargeTable;
    TestSimpleHash;
    TestLegacySimpleHashS;
    TestLegacySimpleHashAS;
    TestObjectHash;
    TestLegacyVarHash;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Exception: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
