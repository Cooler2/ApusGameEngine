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
    keys:=h.GetKeys;
    values:=h.GetValues;
    Check(length(keys)=1, 'keys length=1');
    Check(length(values)=1, 'values length=1');
  finally
    h.Free;
  end;
  EndTest;
end;

procedure TestLegacyTHashSingle;
var
  h:THash;
  v:variant;
  keys:Strings8;
begin
  StartTest('Legacy.THash.Single');
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

procedure TestLegacyTHashMulti;
var
  h:THash;
  all:VariantArray;
begin
  StartTest('Legacy.THash.Multi');
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

procedure TestLegacySimpleHash;
var
  h:TSimpleHash;
begin
  StartTest('Legacy.TSimpleHash');
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
  h.RemoveValue(1); // legacy API, ensure callable
  Check(true, 'removevalue callable');
  h.Clear;
  Check(not h.HasValue(2), 'clear removed key=2');
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

procedure TestLegacyObjectHash;
var
  h:TObjectHash;
  a,b:TTestNamedObject;
  keys:Strings8;
  objs:TNamedObjects;
begin
  StartTest('Legacy.TObjectHash');
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
  Check(length(keys)>=2, 'listkeys has 2+ items');

  h.Remove('a');
  Check(not h.HasKey('a'), 'removed a');
  Check(VarIsEmpty(h.Get('a')), 'removed get=Unassigned');
  h.Remove('missing');
  h.Clear;
  Check(not h.HasKey('b'), 'clear removed b');
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

    TestLegacyStrHash;
    TestLegacyTHashSingle;
    TestLegacyTHashMulti;
    TestLegacySimpleHash;
    TestLegacySimpleHashS;
    TestLegacySimpleHashAS;
    TestLegacyObjectHash;
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
