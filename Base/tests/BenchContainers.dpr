{$APPTYPE CONSOLE}
program BenchContainers;
uses
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Containers;

{$I test.inc}

const
  N_DEF  = 1000000;
  N_MED  = 200000;
  N_SLOW = 100000;

procedure NullIterator(depth:integer; item:TObject);
begin
end;

// ============================================================================
// THeap
// ============================================================================

procedure BenchHeap_PutGet_10;
var
  i,j:integer;
  h:THeap;
begin
  StartBench('Heap Put+Get 10',N_MED);
  for i:=1 to N_MED do begin
    h:=THeap.Create(16);
    for j:=1 to 10 do
      h.Put(TIntItem.Create(10-j,nil));
    for j:=1 to 10 do
      h.Get.Free;
    h.Free;
  end;
  EndBench;
end;

procedure BenchHeap_PutGet_100;
var
  i,j:integer;
  h:THeap;
begin
  StartBench('Heap Put+Get 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    h:=THeap.Create(128);
    for j:=1 to 100 do
      h.Put(TIntItem.Create(100-j,nil));
    for j:=1 to 100 do
      h.Get.Free;
    h.Free;
  end;
  EndBench;
end;

procedure BenchHeap_PutGet_1K;
var
  i,j:integer;
  h:THeap;
begin
  StartBench('Heap Put+Get 1K',N_SLOW div 10);
  for i:=1 to N_SLOW div 10 do begin
    h:=THeap.Create(1024);
    for j:=1 to 1000 do
      h.Put(TIntItem.Create(1000-j,nil));
    for j:=1 to 1000 do
      h.Get.Free;
    h.Free;
  end;
  EndBench;
end;

// ============================================================================
// TDataQueue (TQueue)
// ============================================================================

procedure BenchDataQueue_Throughput_4;
var
  i:integer;
  q:TQueue;
  it:TDataItem;
begin
  q.Init(8);
  it.ptr:=nil; it.value:=0;
  StartBench('DataQueue Add+Get x4 batch',N_DEF);
  for i:=1 to N_DEF do begin
    it.data:=1; q.Add(it);
    it.data:=2; q.Add(it);
    it.data:=3; q.Add(it);
    it.data:=4; q.Add(it);
    q.Get(it); q.Get(it); q.Get(it); q.Get(it);
  end;
  EndBench;
end;

procedure BenchDataQueue_Throughput_1;
var
  i:integer;
  q:TQueue;
  it:TDataItem;
begin
  q.Init(4);
  it.ptr:=nil; it.value:=0; it.data:=1;
  StartBench('DataQueue Add+Get x1',N_DEF);
  for i:=1 to N_DEF do begin
    q.Add(it);
    q.Get(it);
  end;
  EndBench;
end;

// ============================================================================
// TGenQueue<integer>
// ============================================================================

procedure BenchGenQueue_Throughput_4;
var
  i:integer;
  q:TGenQueue<integer>;
  v:integer;
begin
  q.Init(8);
  StartBench('GenQueue<int> Add+Get x4',N_DEF);
  for i:=1 to N_DEF do begin
    q.Add(1); q.Add(2); q.Add(3); q.Add(4);
    q.Get(v); q.Get(v); q.Get(v); q.Get(v);
  end;
  EndBench;
end;

procedure BenchGenQueue_Throughput_1;
var
  i:integer;
  q:TGenQueue<integer>;
  v:integer;
begin
  q.Init(4);
  StartBench('GenQueue<int> Add+Get x1',N_DEF);
  for i:=1 to N_DEF do begin
    q.Add(i);
    q.Get(v);
  end;
  EndBench;
end;

// ============================================================================
// TPriorityQueue
// ============================================================================

procedure BenchPriorityQueue_10;
var
  i,j:integer;
  q:TPriorityQueue;
  it:TDataItem;
begin
  it.ptr:=nil;
  StartBench('PriorityQueue Add+Get 10',N_MED);
  for i:=1 to N_MED do begin
    q.Init(16);
    for j:=1 to 10 do begin
      it.data:=j; it.value:=10-j;
      q.Add(it);
    end;
    for j:=1 to 10 do
      q.Get(it);
  end;
  EndBench;
end;

procedure BenchPriorityQueue_100;
var
  i,j:integer;
  q:TPriorityQueue;
  it:TDataItem;
begin
  it.ptr:=nil;
  StartBench('PriorityQueue Add+Get 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    q.Init(128);
    for j:=1 to 100 do begin
      it.data:=j; it.value:=100-j;
      q.Add(it);
    end;
    for j:=1 to 100 do
      q.Get(it);
  end;
  EndBench;
end;

// ============================================================================
// TObjectList
// ============================================================================

var
  benchObjs:array[0..99] of TObject; // reused across benchmarks

procedure BenchObjectList_Add_100;
var
  i,j:integer;
  list:TObjectList;
begin
  StartBench('ObjectList Add 100',N_SLOW);
  for i:=1 to N_SLOW do begin
    for j:=0 to 99 do
      list.Add(benchObjs[j]);
    list.Clear(false);
  end;
  EndBench;
end;

procedure BenchObjectList_Get_100;
var
  i,j:integer;
  list:TObjectList;
  o:TObject;
begin
  for j:=0 to 99 do
    list.Add(benchObjs[j]);
  StartBench('ObjectList Get idx (100)',N_DEF);
  for i:=1 to N_DEF do
    o:=list.Get(i mod 100);
  EndBench;
  list.Clear(false);
end;

procedure BenchObjectList_Remove_KeepOrder;
var
  i,j:integer;
  list:TObjectList;
begin
  StartBench('ObjectList Remove keepOrder 50',N_SLOW div 5);
  for i:=1 to N_SLOW div 5 do begin
    for j:=0 to 49 do list.Add(benchObjs[j]);
    for j:=0 to 49 do list.Remove(benchObjs[j],true);
  end;
  EndBench;
end;

procedure BenchObjectList_Remove_Swap;
var
  i,j:integer;
  list:TObjectList;
begin
  StartBench('ObjectList Remove swap 50',N_SLOW div 5);
  for i:=1 to N_SLOW div 5 do begin
    for j:=0 to 49 do list.Add(benchObjs[j]);
    for j:=0 to 49 do list.Remove(benchObjs[j],false);
  end;
  EndBench;
end;

// ============================================================================
// TGenQueue<String8>
// ============================================================================

procedure BenchStringQueue_Throughput;
var
  i:integer;
  q:TGenQueue<String8>;
begin
  q.Init(8);
  StartBench('GenQueue<String8> Add+Get x4',N_DEF);
  for i:=1 to N_DEF do begin
    q.Add('alpha'); q.Add('beta'); q.Add('gamma'); q.Add('delta');
    q.Get; q.Get; q.Get; q.Get;
  end;
  EndBench;
end;

// ============================================================================
// TGenericTree: Traverse
// ============================================================================

procedure BenchTree_Traverse_100_RootFirst;
var
  i,j:integer;
  root:TGenericTree;
  v:array[0..99] of integer;
begin
  root:=TGenericTree.Create(false,false);
  for j:=0 to 99 do begin
    v[j]:=j;
    root.AddChild(@v[j]);
  end;
  StartBench('Tree Traverse 100 RootFirst',N_SLOW);
  for i:=1 to N_SLOW do
    root.Traverse(RootFirst,@NullIterator);
  EndBench;
  root.Free;
end;

procedure BenchTree_Traverse_100_ByLevels;
var
  i,j:integer;
  root:TGenericTree;
  v:array[0..99] of integer;
begin
  root:=TGenericTree.Create(false,false);
  for j:=0 to 99 do begin
    v[j]:=j;
    root.AddChild(@v[j]);
  end;
  StartBench('Tree Traverse 100 ByLevels',N_SLOW);
  for i:=1 to N_SLOW do
    root.Traverse(ByLevels,@NullIterator);
  EndBench;
  root.Free;
end;

// ============================================================================
// Main
// ============================================================================

var
  j:integer;

begin
  try
    for j:=0 to 99 do
      benchObjs[j]:=TObject.Create;

    OpenBenchLog('containers',N_DEF);
    BenchWriteln;

    BenchWriteln('--- THeap ---');
    BenchHeap_PutGet_10;
    BenchHeap_PutGet_100;
    BenchHeap_PutGet_1K;
    BenchWriteln;

    BenchWriteln('--- TDataQueue ---');
    BenchDataQueue_Throughput_1;
    BenchDataQueue_Throughput_4;
    BenchWriteln;

    BenchWriteln('--- TGenQueue<integer> ---');
    BenchGenQueue_Throughput_1;
    BenchGenQueue_Throughput_4;
    BenchWriteln;

    BenchWriteln('--- TPriorityQueue ---');
    BenchPriorityQueue_10;
    BenchPriorityQueue_100;
    BenchWriteln;

    BenchWriteln('--- TObjectList ---');
    BenchObjectList_Add_100;
    BenchObjectList_Get_100;
    BenchObjectList_Remove_KeepOrder;
    BenchObjectList_Remove_Swap;
    BenchWriteln;

    BenchWriteln('--- TGenQueue<String8> ---');
    BenchStringQueue_Throughput;
    BenchWriteln;

    BenchWriteln('--- TGenericTree ---');
    BenchTree_Traverse_100_RootFirst;
    BenchTree_Traverse_100_ByLevels;
    BenchWriteln;

    CloseBenchLog;

    for j:=0 to 99 do
      benchObjs[j].Free;

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
