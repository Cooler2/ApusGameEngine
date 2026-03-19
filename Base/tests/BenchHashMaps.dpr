{$APPTYPE CONSOLE}
program BenchHashMaps;
uses
  SysUtils,
  Variants,
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
// Put 100 (fresh fill)
// ============================================================================

procedure BenchPut100_HashMap;
var i,j:integer; m:THashMap<integer>;
begin
  StartBench('HashMap<int>   Put 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    m.Init(128);
    for j:=0 to 99 do m.Put(keys[j],j);
    m.Clear;
  end;
  EndBench;
end;

procedure BenchPut100_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  StartBench('SimpleHashAS   Put 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init(128);
    for j:=0 to 99 do h.Put(keys[j],j);
    h.Clear;
  end;
  EndBench;
end;

procedure BenchPut100_THash;
var i,j:integer; h:THash;
begin
  StartBench('THash          Put 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init(false);
    for j:=0 to 99 do h.Put(keys[j],j);
  end;
  EndBench;
end;

procedure BenchPut100_TVarHash;
var i,j:integer; h:TVarHash;
begin
  StartBench('TVarHash       Put 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init;
    for j:=0 to 99 do h.Put(keys[j],j);
    h.Clear;
  end;
  EndBench;
end;

// ============================================================================
// Put 10K (fresh fill)
// ============================================================================

procedure BenchPut10K_HashMap;
var i,j:integer; m:THashMap<integer>;
begin
  StartBench('HashMap<int>   Put 10K',N_SLOW div 10);
  for i:=1 to N_SLOW div 10 do begin
    m.Init(16384);
    for j:=0 to 9999 do m.Put(keys[j],j);
    m.Clear;
  end;
  EndBench;
end;

procedure BenchPut10K_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  StartBench('SimpleHashAS   Put 10K',N_SLOW div 10);
  for i:=1 to N_SLOW div 10 do begin
    h.Init(16384);
    for j:=0 to 9999 do h.Put(keys[j],j);
    h.Clear;
  end;
  EndBench;
end;

// THash not benchmarked at 10K: O(n) per Put causes O(n^2) total allocs -> OOM

// ============================================================================
// Overwrite (update existing key, 100 items)
// ============================================================================

procedure BenchOverwrite_HashMap;
var i,j:integer; m:THashMap<integer>;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],j);
  StartBench('HashMap<int>   Overwrite 100',N_DEF);
  for i:=1 to N_DEF do m.Put(keys[i mod 100],i);
  EndBench;
end;

procedure BenchOverwrite_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('SimpleHashAS   Overwrite 100',N_DEF);
  for i:=1 to N_DEF do h.Put(keys[i mod 100],i);
  EndBench;
end;

procedure BenchOverwrite_THash;
var i,j:integer; h:THash;
begin
  h.Init(false);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('THash          Overwrite 100',N_DEF);
  for i:=1 to N_DEF do h.Put(keys[i mod 100],i);
  EndBench;
end;

procedure BenchOverwrite_TVarHash;
var i,j:integer; h:TVarHash;
begin
  h.Init;
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('TVarHash       Overwrite 100',N_DEF);
  for i:=1 to N_DEF do h.Put(keys[i mod 100],i);
  EndBench;
end;

// ============================================================================
// Get hit (100 items)
// ============================================================================

procedure BenchGetHit100_HashMap;
var i,j:integer; m:THashMap<integer>; v:integer;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],j);
  StartBench('HashMap<int>   Get hit 100',N_DEF);
  for i:=1 to N_DEF do m.Get(keys[i mod 100],v);
  EndBench;
end;

procedure BenchGetHit100_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('SimpleHashAS   Get hit 100',N_DEF);
  for i:=1 to N_DEF do h.Get(keys[i mod 100]);
  EndBench;
end;

procedure BenchGetHit100_THash;
var i,j:integer; h:THash;
begin
  h.Init(false);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('THash          Get hit 100',N_DEF);
  for i:=1 to N_DEF do h.Get(keys[i mod 100]);
  EndBench;
end;

procedure BenchGetHit100_TVarHash;
var i,j:integer; h:TVarHash;
begin
  h.Init;
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('TVarHash       Get hit 100',N_DEF);
  for i:=1 to N_DEF do h.Get(keys[i mod 100]);
  EndBench;
end;

// ============================================================================
// Get hit (10K items)
// ============================================================================

procedure BenchGetHit10K_HashMap;
var i,j:integer; m:THashMap<integer>; v:integer;
begin
  m.Init(16384);
  for j:=0 to 9999 do m.Put(keys[j],j);
  StartBench('HashMap<int>   Get hit 10K',N_DEF);
  for i:=1 to N_DEF do m.Get(keys[i mod 10000],v);
  EndBench;
end;

procedure BenchGetHit10K_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  h.Init(16384);
  for j:=0 to 9999 do h.Put(keys[j],j);
  StartBench('SimpleHashAS   Get hit 10K',N_DEF);
  for i:=1 to N_DEF do h.Get(keys[i mod 10000]);
  EndBench;
end;

procedure BenchGetHit10K_THash;
var i,j:integer; h:THash;
begin
  h.Init(false);
  for j:=0 to 9999 do h.Put(keys[j],j);
  StartBench('THash          Get hit 10K',N_DEF);
  for i:=1 to N_DEF do h.Get(keys[i mod 10000]);
  EndBench;
end;

// ============================================================================
// Get miss (key absent)
// ============================================================================

procedure BenchGetMiss_HashMap;
var i,j:integer; m:THashMap<integer>; v:integer;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],j);
  StartBench('HashMap<int>   Get miss',N_DEF);
  for i:=1 to N_DEF do m.Get('nonexistent_key',v);
  EndBench;
end;

procedure BenchGetMiss_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('SimpleHashAS   Get miss',N_DEF);
  for i:=1 to N_DEF do h.Get('nonexistent_key');
  EndBench;
end;

procedure BenchGetMiss_THash;
var i,j:integer; h:THash;
begin
  h.Init(false);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('THash          Get miss',N_DEF);
  for i:=1 to N_DEF do h.Get('nonexistent_key');
  EndBench;
end;

procedure BenchGetMiss_TVarHash;
var i,j:integer; h:TVarHash;
begin
  h.Init;
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('TVarHash       Get miss',N_DEF);
  for i:=1 to N_DEF do h.Get('nonexistent_key');
  EndBench;
end;

// ============================================================================
// HasKey / HasValue (100 items)
// ============================================================================

procedure BenchHasKey_HashMap;
var i,j:integer; m:THashMap<integer>; b:boolean;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],j);
  StartBench('HashMap<int>   HasKey 100',N_DEF);
  for i:=1 to N_DEF do b:=m.HasKey(keys[i mod 100]);
  EndBench;
end;

procedure BenchHasKey_HashAS;
var i,j:integer; h:TSimpleHashAS; b:boolean;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('SimpleHashAS   HasValue 100',N_DEF);
  for i:=1 to N_DEF do b:=h.HasValue(keys[i mod 100]);
  EndBench;
end;

procedure BenchHasKey_THash;
var i,j:integer; h:THash; b:boolean;
begin
  h.Init(false);
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('THash          HasKey 100',N_DEF);
  for i:=1 to N_DEF do b:=h.HasKey(keys[i mod 100]);
  EndBench;
end;

procedure BenchHasKey_TVarHash;
var i,j:integer; h:TVarHash; b:boolean;
begin
  h.Init;
  for j:=0 to 99 do h.Put(keys[j],j);
  StartBench('TVarHash       HasKey 100',N_DEF);
  for i:=1 to N_DEF do b:=h.HasKey(keys[i mod 100]);
  EndBench;
end;

// ============================================================================
// Remove (100 keys, full fill+remove cycle)
// ============================================================================

procedure BenchRemove_HashMap;
var i,j:integer; m:THashMap<integer>;
begin
  StartBench('HashMap<int>   Remove 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    m.Init(128);
    for j:=0 to 99 do m.Put(keys[j],j);
    for j:=0 to 99 do m.Remove(keys[j]);
    m.Clear;
  end;
  EndBench;
end;

procedure BenchRemove_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  StartBench('SimpleHashAS   Remove 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init(128);
    for j:=0 to 99 do h.Put(keys[j],j);
    for j:=0 to 99 do h.Remove(keys[j]);
    h.Clear;
  end;
  EndBench;
end;

procedure BenchRemove_THash;
var i,j:integer; h:THash;
begin
  StartBench('THash          Remove 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init(false);
    for j:=0 to 99 do h.Put(keys[j],j);
    for j:=0 to 99 do h.Remove(keys[j]);
  end;
  EndBench;
end;

procedure BenchRemove_TVarHash;
var i,j:integer; h:TVarHash;
begin
  StartBench('TVarHash       Remove 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init;
    for j:=0 to 99 do h.Put(keys[j],j);
    for j:=0 to 99 do h.Remove(keys[j]);
    h.Clear;
  end;
  EndBench;
end;

// ============================================================================
// THashMap value type overhead: int vs String8
// ============================================================================

procedure BenchGetDef_HashMap;
var i,j:integer; m:THashMap<integer>; v:integer;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],j);
  StartBench('HashMap<int>   GetDef 100',N_DEF);
  for i:=1 to N_DEF do v:=m.GetDef(keys[i mod 100],-1);
  EndBench;
end;

procedure BenchGetHit100_HashMapStr;
var i,j:integer; m:THashMap<String8>; v:String8;
begin
  m.Init(128);
  for j:=0 to 99 do m.Put(keys[j],'val_'+IntToStr(j));
  StartBench('HashMap<str8>  Get hit 100',N_DEF);
  for i:=1 to N_DEF do m.Get(keys[i mod 100],v);
  EndBench;
end;

// ============================================================================
// Increment (atomic counter pattern)
// ============================================================================

procedure BenchIncrement_HashAS;
var i,j:integer; h:TSimpleHashAS;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(keys[j],0);
  StartBench('SimpleHashAS   Increment 100',N_DEF);
  for i:=1 to N_DEF do h.Increment(keys[i mod 100]);
  EndBench;
end;

procedure BenchIncrement_SimpleHash;
var i,j:integer; h:TSimpleHash;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(j,0);
  StartBench('SimpleHash     Increment 100',N_DEF);
  for i:=1 to N_DEF do h.Increment(i mod 100);
  EndBench;
end;

// ============================================================================
// TSimpleHash: integer keys (int64 -> int64), shown for reference
// ============================================================================

procedure BenchIntKey_Put100;
var i,j:integer; h:TSimpleHash;
begin
  StartBench('SimpleHash     Put 100 (int key)',N_SLOW);
  for i:=1 to N_SLOW do begin
    h.Init(128);
    for j:=0 to 99 do h.Put(j,j*10);
    h.Clear;
  end;
  EndBench;
end;

procedure BenchIntKey_Get100;
var i,j:integer; h:TSimpleHash;
begin
  h.Init(128);
  for j:=0 to 99 do h.Put(j,j*10);
  StartBench('SimpleHash     Get 100 (int key)',N_DEF);
  for i:=1 to N_DEF do h.Get(i mod 100);
  EndBench;
end;

procedure BenchIntKey_Get10K;
var i,j:integer; h:TSimpleHash;
begin
  h.Init(16384);
  for j:=0 to 9999 do h.Put(j,j*10);
  StartBench('SimpleHash     Get 10K (int key)',N_DEF);
  for i:=1 to N_DEF do h.Get(i mod 10000);
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

    BenchWriteln('--- Put 100 (fresh fill) ---');
    BenchPut100_HashMap;
    BenchPut100_HashAS;
    BenchPut100_THash;
    BenchPut100_TVarHash;
    BenchWriteln;

    BenchWriteln('--- Put 10K (fresh fill) ---');
    BenchPut10K_HashMap;
    BenchPut10K_HashAS;
    BenchWriteln;

    BenchWriteln('--- Overwrite existing key (100 items) ---');
    BenchOverwrite_HashMap;
    BenchOverwrite_HashAS;
    BenchOverwrite_THash;
    BenchOverwrite_TVarHash;
    BenchWriteln;

    BenchWriteln('--- Get hit (100 items) ---');
    BenchGetHit100_HashMap;
    BenchGetHit100_HashAS;
    BenchGetHit100_THash;
    BenchGetHit100_TVarHash;
    BenchWriteln;

    BenchWriteln('--- Get hit (10K items) ---');
    BenchGetHit10K_HashMap;
    BenchGetHit10K_HashAS;
    BenchGetHit10K_THash;
    BenchWriteln;

    BenchWriteln('--- Get miss (key absent) ---');
    BenchGetMiss_HashMap;
    BenchGetMiss_HashAS;
    BenchGetMiss_THash;
    BenchGetMiss_TVarHash;
    BenchWriteln;

    BenchWriteln('--- HasKey / HasValue (100 items) ---');
    BenchHasKey_HashMap;
    BenchHasKey_HashAS;
    BenchHasKey_THash;
    BenchHasKey_TVarHash;
    BenchWriteln;

    BenchWriteln('--- Remove 100 (fill + remove cycle) ---');
    BenchRemove_HashMap;
    BenchRemove_HashAS;
    BenchRemove_THash;
    BenchRemove_TVarHash;
    BenchWriteln;

    BenchWriteln('--- HashMap value type (int vs String8) ---');
    BenchGetHit100_HashMap;
    BenchGetHit100_HashMapStr;
    BenchGetDef_HashMap;
    BenchWriteln;

    BenchWriteln('--- Increment (counter pattern) ---');
    BenchIncrement_SimpleHash;
    BenchIncrement_HashAS;
    BenchWriteln;

    BenchWriteln('--- TSimpleHash: integer keys (int64->int64) ---');
    BenchIntKey_Put100;
    BenchIntKey_Get100;
    BenchIntKey_Get10K;
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
