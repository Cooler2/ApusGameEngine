{$APPTYPE CONSOLE}
program BenchHashMaps;
uses
  SysUtils,
  Apus.Core,
  Apus.HashMaps;

{$IFDEF FPC}
type
  String8 = UTF8String;
{$ENDIF}

{$I test.inc}

const
  N_DEF  = 1000000;
  N_SLOW = 100000;

var
  keys:array of String8;

procedure PrepareKeys(count:integer);
var
  i:integer;
begin
  SetLength(keys,count);
  for i:=0 to count-1 do
    keys[i]:='key_'+IntToStr(i);
end;

// ============================================================================
// Put
// ============================================================================

procedure BenchPut_100;
var i,j:integer; map:THashMap<integer>;
begin
  StartBench('Put 100 items',N_SLOW);
  for i:=1 to N_SLOW do begin
    map.Init(128);
    for j:=0 to 99 do
      map.Put(keys[j],j);
    map.Clear;
  end;
  EndBench;
end;

procedure BenchPut_10K;
var i,j:integer; map:THashMap<integer>;
begin
  StartBench('Put 10K items',N_SLOW div 10);
  for i:=1 to N_SLOW div 10 do begin
    map.Init(16384);
    for j:=0 to 9999 do
      map.Put(keys[j],j);
    map.Clear;
  end;
  EndBench;
end;

// ============================================================================
// Get (hit)
// ============================================================================

procedure BenchGet_100;
var i,j:integer; map:THashMap<integer>; v:integer;
begin
  map.Init(128);
  for j:=0 to 99 do
    map.Put(keys[j],j);
  StartBench('Get hit (100 items)',N_DEF);
  for i:=1 to N_DEF do
    map.Get(keys[i mod 100],v);
  EndBench;
end;

procedure BenchGet_10K;
var i:integer; map:THashMap<integer>; v:integer; j:integer;
begin
  map.Init(16384);
  for j:=0 to 9999 do
    map.Put(keys[j],j);
  StartBench('Get hit (10K items)',N_DEF);
  for i:=1 to N_DEF do
    map.Get(keys[i mod 10000],v);
  EndBench;
end;

// ============================================================================
// Get (miss)
// ============================================================================

procedure BenchGetMiss;
var i:integer; map:THashMap<integer>; v:integer;
begin
  map.Init(128);
  for i:=0 to 99 do
    map.Put(keys[i],i);
  StartBench('Get miss (100 items)',N_DEF);
  for i:=1 to N_DEF do
    map.Get('nonexistent_key',v);
  EndBench;
end;

// ============================================================================
// HasKey
// ============================================================================

procedure BenchHasKey;
var i:integer; map:THashMap<integer>; b:boolean; j:integer;
begin
  map.Init(128);
  for j:=0 to 99 do
    map.Put(keys[j],j);
  StartBench('HasKey (100 items)',N_DEF);
  for i:=1 to N_DEF do
    b:=map.HasKey(keys[i mod 100]);
  EndBench;
end;

// ============================================================================
// GetDef
// ============================================================================

procedure BenchGetDef;
var i:integer; map:THashMap<integer>; v:integer; j:integer;
begin
  map.Init(128);
  for j:=0 to 99 do
    map.Put(keys[j],j);
  StartBench('GetDef (100 items)',N_DEF);
  for i:=1 to N_DEF do
    v:=map.GetDef(keys[i mod 100],-1);
  EndBench;
end;

// ============================================================================
// Remove
// ============================================================================

procedure BenchRemove;
var i,j:integer; map:THashMap<integer>;
begin
  StartBench('Remove 100 items',N_SLOW);
  for i:=1 to N_SLOW do begin
    map.Init(128);
    for j:=0 to 99 do
      map.Put(keys[j],j);
    for j:=0 to 99 do
      map.Remove(keys[j]);
    map.Clear;
  end;
  EndBench;
end;

// ============================================================================
// Overwrite
// ============================================================================

procedure BenchOverwrite;
var i:integer; map:THashMap<integer>; j:integer;
begin
  map.Init(128);
  for j:=0 to 99 do
    map.Put(keys[j],j);
  StartBench('Put overwrite (100)',N_DEF);
  for i:=1 to N_DEF do
    map.Put(keys[i mod 100],i);
  EndBench;
end;

// ============================================================================
// String values
// ============================================================================

procedure BenchPutGet_StringVal;
var i:integer; map:THashMap<String8>; v:String8; j:integer;
begin
  map.Init(128);
  for j:=0 to 99 do
    map.Put(keys[j],'value_'+IntToStr(j));
  StartBench('Get string val (100)',N_DEF);
  for i:=1 to N_DEF do
    map.Get(keys[i mod 100],v);
  EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    PrepareKeys(10000);
    OpenBenchLog('hashmaps',N_DEF);
  BenchWriteln;

  BenchWriteln('--- Put ---');
  BenchPut_100;
  BenchPut_10K;
  BenchOverwrite;
  BenchWriteln;

  BenchWriteln('--- Get ---');
  BenchGet_100;
  BenchGet_10K;
  BenchGetMiss;
  BenchGetDef;
  BenchPutGet_StringVal;
  BenchWriteln;

  BenchWriteln('--- HasKey / Remove ---');
  BenchHasKey;
  BenchRemove;
  BenchWriteln;

  CloseBenchLog;
  writeln('=== BENCHMARK DONE ===');
  except
    on e:Exception do begin
      writeln;
      writeln('BENCHMARK FAILED: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press ENTER to exit');
    readln;
  end;
end.
