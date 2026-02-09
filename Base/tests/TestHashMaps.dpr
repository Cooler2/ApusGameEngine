{$APPTYPE CONSOLE}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
program TestHashMaps;
uses
  SysUtils,
  Apus.Core,
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
begin
  StartTest('GenHash.Resize');
  m.Init(4);
  for i:=0 to 999 do
    m.Put('key'+IntToStr(i), i);
  Check(m.count=1000, 'count=1000');
  allOk:=true;
  for i:=0 to 999 do
    if not (m.Get('key'+IntToStr(i),v) and (v=i)) then begin
      Check(false, 'get key'+IntToStr(i)+' failed');
      allOk:=false;
      break;
    end;
  if allOk then
    Check(true, 'all 1000 values correct');
  EndTest;
end;

procedure TestRemoveChain;
var
  m:TStrIntMap;
  v,i:integer;
begin
  StartTest('GenHash.RemoveChain');
  m.Init(4);
  for i:=0 to 49 do
    m.Put('item'+IntToStr(i), i);
  Check(m.count=50, 'count=50');
  for i:=0 to 24 do
    m.Remove('item'+IntToStr(i*2));
  Check(m.count=25, 'count=25 after remove');
  for i:=0 to 24 do
    Check(m.Get('item'+IntToStr(i*2+1),v) and (v=i*2+1),
      'odd item '+IntToStr(i*2+1));
  for i:=0 to 24 do
    Check(not m.HasKey('item'+IntToStr(i*2)),
      'even item '+IntToStr(i*2)+' removed');
  for i:=0 to 24 do
    m.Put('item'+IntToStr(i*2), i*200);
  Check(m.count=50, 'count=50 after reinsert');
  for i:=0 to 24 do begin
    Check(m.Get('item'+IntToStr(i*2),v) and (v=i*200),
      'reinserted even '+IntToStr(i*2));
    Check(m.Get('item'+IntToStr(i*2+1),v) and (v=i*2+1),
      'still odd '+IntToStr(i*2+1));
  end;
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
