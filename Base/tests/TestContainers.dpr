{$APPTYPE CONSOLE}
{$R+}
program TestContainers;
uses
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Containers;

{$INCLUDE Test.inc}

type
  PInteger=^integer;

  TRefObj=class
    class var destroyedCount:integer;
    destructor Destroy; override;
  end;

var
  traverseValues:array of integer;

procedure CollectTreeValue(depth:integer;item:TObject);
var
  node:TGenericTree;
  v:integer;
begin
  node:=TGenericTree(item);
  if node.data=nil then
    v:=0
  else
    v:=PInteger(node.data)^;
  SetLength(traverseValues,length(traverseValues)+1);
  traverseValues[high(traverseValues)]:=v;
end;

function PrioritizeByData(const item:TDataItem):single;
begin
  result:=item.data;
end;

destructor TRefObj.Destroy;
begin
  inc(destroyedCount);
  inherited;
end;

procedure TestGenericTree;
var
  root:TGenericTree;
  a,b,c,gc:integer;
begin
  StartTest('Containers.GenericTree');
  a:=1; b:=2; c:=3;
  root:=TGenericTree.Create(false,true);
  try
    Check(root.GetChildrenCount=0,'empty tree');
    root.AddChild(@a);
    root.AddChild(@b);
    root.InsertChild(@c,1);

    Check(root.GetChildrenCount=3,'children count');
    Check(PInteger(root.GetChild(0).data)^=1,'child[0]');
    Check(PInteger(root.GetChild(1).data)^=3,'child[1]');
    Check(PInteger(root.GetChild(2).data)^=2,'child[2]');
    Check(root.GetChild(1).GetIndex=1,'index');
    Check(root.GetChild(1).GetParent=root,'parent');

    SetLength(traverseValues,0);
    root.Traverse(RootFirst,@CollectTreeValue);
    Check(length(traverseValues)=4,'rootfirst count');
    Check((traverseValues[0]=0) and (traverseValues[1]=1) and (traverseValues[2]=3) and (traverseValues[3]=2),
      'rootfirst order');

    SetLength(traverseValues,0);
    root.Traverse(ChildrenFirst,@CollectTreeValue);
    Check(length(traverseValues)=4,'childrenfirst count');
    Check((traverseValues[0]=1) and (traverseValues[1]=3) and (traverseValues[2]=2) and (traverseValues[3]=0),
      'childrenfirst order');

    SetLength(traverseValues,0);
    root.Traverse(ByLevels,@CollectTreeValue);
    Check(length(traverseValues)=4,'bylevels count');
    Check((traverseValues[0]=0) and (traverseValues[1]=1) and (traverseValues[2]=3) and (traverseValues[3]=2),
      'bylevels order');

    // Deep tree: add grandchild to child[1] (data=3) → root(0)→[1, 3→[99], 2]
    gc:=99;
    root.GetChild(1).AddChild(@gc);

    SetLength(traverseValues,0);
    root.Traverse(RootFirst,@CollectTreeValue);
    Check(length(traverseValues)=5,'deep rootfirst count');
    Check((traverseValues[0]=0) and (traverseValues[1]=1) and
      (traverseValues[2]=3) and (traverseValues[3]=99) and
      (traverseValues[4]=2),'deep rootfirst order');

    SetLength(traverseValues,0);
    root.Traverse(ByLevels,@CollectTreeValue);
    Check(length(traverseValues)=5,'deep bylevels count');
    Check((traverseValues[0]=0) and (traverseValues[1]=1) and
      (traverseValues[2]=3) and (traverseValues[3]=2) and
      (traverseValues[4]=99),'deep bylevels order');
  finally
    root.Free;
  end;
  EndTest;
end;

procedure TestHeap;
var
  h:THeap;
  item:TIntItem;
begin
  StartTest('Containers.Heap');
  h:=THeap.Create(8);
  try
    h.Put(TIntItem.Create(5,nil));
    h.Put(TIntItem.Create(1,nil));
    h.Put(TIntItem.Create(3,nil));

    item:=TIntItem(h.Get);
    Check(item.value=1,'min #1');
    item.Free;
    item:=TIntItem(h.Get);
    Check(item.value=3,'min #2');
    item.Free;
    item:=TIntItem(h.Get);
    Check(item.value=5,'min #3');
    item.Free;

    Check(h.Get=nil,'empty get=nil');
    Check(h.lastError=esEmpty,'empty error state');
  finally
    h.Free;
  end;
  EndTest;
end;

procedure TestObjectQueue;
var
  q:TGenQueue<TObject>;
  o1,o2,o3:TObject;
  outObj:TObject;
begin
  StartTest('Containers.ObjectQueue');
  q.Init(3);
  o1:=TObject.Create;
  o2:=TObject.Create;
  o3:=TObject.Create;
  try
    Check(q.Add(o1),'add o1');
    Check(q.Add(o2),'add o2');
    Check(q.Get(outObj) and (outObj=o1),'get o1');
    Check(q.Get(outObj) and (outObj=o2),'get o2');
    Check(not q.Get(outObj),'get false when empty');

    q.Clear;
    Check(q.Add(o1),'add #1');
    Check(q.Add(o2),'add #2');
    Check(not q.Add(o3),'add full=false');
  finally
    o1.Free;
    o2.Free;
    o3.Free;
  end;
  EndTest;
end;

procedure TestDataQueue;
var
  q:TQueue;
  it,outIt:TDataItem;
begin
  StartTest('Containers.DataQueue');
  q.Init(3);
  it.data:=10; it.value:=1.0; it.ptr:=nil;
  Check(q.Add(it),'add #1');
  it.data:=20;
  Check(q.Add(it),'add #2');
  it.data:=30;
  Check(not q.Add(it),'add full=false');
  Check(q.Count=2,'count=2');

  Check(q.Get(outIt) and (outIt.data=10),'get #1');
  Check(q.Get(outIt) and (outIt.data=20),'get #2');
  Check(not q.Get(outIt),'empty get=false');
  Check(q.Empty,'empty=true');

  it.data:=1;
  Check(q.Add(it),'add after drain');
  q.Clear;
  Check(q.Empty,'empty after clear');
  Check(q.Count=0,'count=0 after clear');
  EndTest;
end;

procedure TestGenQueue;
var
  q:TGenQueue<integer>;
  v:integer;
  emptyCaught:boolean;
begin
  StartTest('Containers.GenQueue');
  q.Init(3);
  Check(q.Add(1),'add #1');
  Check(q.Add(2),'add #2');
  Check(not q.Add(3),'add full=false');
  Check(q.Count=2,'count=2');

  Check(q.Get(v) and (v=1),'get(out) #1');
  Check(q.Get(v) and (v=2),'get(out) #2');
  Check(not q.Get(v),'get(out) empty=false');

  emptyCaught:=false;
  try
    q.Get;
  except
    on EWarning do emptyCaught:=true;
  end;
  Check(emptyCaught,'Get raises on empty');
  EndTest;
end;

procedure TestPriorityQueue;
var
  q:TPriorityQueue;
  it,outIt:TDataItem;
begin
  StartTest('Containers.PriorityQueue');
  q.Init(3);
  it.data:=1; it.value:=10; it.ptr:=nil;
  Check(q.Add(it),'add #1');
  it.data:=2; it.value:=5;
  Check(q.Add(it),'add #2');
  it.data:=3; it.value:=20;
  Check(q.Add(it),'add #3');
  it.data:=4; it.value:=15;
  Check(not q.Add(it),'add full=false');

  Check(q.Get(outIt) and (outIt.data=3),'max #1');
  Check(q.Get(outIt) and (outIt.data=1),'max #2');
  Check(q.Get(outIt) and (outIt.data=2),'max #3');
  Check(not q.Get(outIt),'empty get=false');

  it.data:=4; it.value:=0;
  q.Add(it);
  it.data:=1; it.value:=0;
  q.Add(it);
  q.UpdatePriorities(@PrioritizeByData);
  Check(q.Get(outIt) and (outIt.data=4),'reprioritized #1');
  Check(q.Get(outIt) and (outIt.data=1),'reprioritized #2');

  Check(not q.WaitFor(outIt,2),'waitfor timeout on empty');
  EndTest;
end;

procedure TestObjectList;
var
  list,list2:TObjectList;
  o1,o2,o3:TRefObj;
  items:TObjectArray;
begin
  StartTest('Containers.ObjectList');
  TRefObj.destroyedCount:=0;
  o1:=TRefObj.Create;
  o2:=TRefObj.Create;
  o3:=TRefObj.Create;

  Check(list.Add(o1),'add o1');
  Check(list.Add(o2),'add o2');
  Check(list.count=2,'count=2');
  Check(not list.Add(o1,true),'uniqueOnly rejects duplicate');
  Check(list.Get(0)=o1,'get #0');
  Check(list.Get(1)=o2,'get #1');
  Check(list.Get(100)=nil,'get out of range');

  Check(list.Remove(o1,true),'remove keepOrder');
  Check(list.count=1,'count=1');
  Check(list.Get(0)=o2,'o2 shifted');
  Check(list.RemoveFirst=o2,'removefirst');
  Check(list.Remove=nil,'remove empty=nil');

  list.Add(o1);
  list.Add(o2);
  list2.Add(o3);
  Check(list.Add(list2),'add(list)');
  items:=list.GetAll;
  Check(length(items)=3,'getall length=3');
  Check(items[2]=o3,'added from list2');

  // swap remove: remove o2 from [o1,o2,o3] without keepOrder → o3 fills the gap
  list.Remove(o2,false);
  Check(list.count=2,'swap remove count');
  Check(list.Get(0)=o1,'swap remove: o1 at pos 0');
  Check(list.Get(1)=o3,'swap remove: o3 swapped to pos 1');
  list.Add(o2); // restore so FreeAll covers all three

  list.FreeAll;
  Check(TRefObj.destroyedCount=3,'freeall destroyed all');
  list2.Clear(false);
  EndTest;
end;

// TGrowArray<T>: Count vs Capacity, amortized growth, memory reuse, managed items
type
  TTracked=class(TInterfacedObject)
    destructor Destroy; override;
  end;
var
  trackedAlive:integer;

destructor TTracked.Destroy;
begin
  dec(trackedAlive);
  inherited;
end;

function NewTracked:IInterface;
begin
  inc(trackedAlive);
  result:=TTracked.Create;
end;

procedure TestGrowArray;
var
  a:TGrowArray<integer>;
  objs:TGrowArray<IInterface>;
  strs:TGrowArray<String8>;
  obj:IInterface;
  i,bad,growths,cap:integer;
begin
  StartTest('TGrowArray');
  Check((a.Count=0) and (a.Capacity=0) and a.IsEmpty,'fresh local variable is empty');
  // 1000 appends: count growths of the storage
  growths:=0; cap:=a.Capacity;
  for i:=0 to 999 do begin
    a.Add(i);
    if a.Capacity<>cap then begin inc(growths); cap:=a.Capacity; end;
  end;
  Check((a.Count=1000) and (a.Capacity>=1000),'1000 items added');
  Check(growths<=7,'amortized growth: at most 7 reallocations for 1000 items');
  bad:=0;
  for i:=0 to 999 do
    if a.items[i]<>i then inc(bad);
  Check(bad=0,'items keep their order');
  Check(PInteger(UIntPtr(a.ItemPtr(0))+5*SizeOf(integer))^=5,'storage is contiguous');
  Check((a.Last=999) and (a.Pop=999) and (a.Count=999),'Last/Pop');
  // Clear keeps the memory: refill without reallocation
  cap:=a.Capacity;
  a.Clear;
  Check((a.Count=0) and (a.Capacity=cap),'Clear keeps capacity');
  for i:=0 to 999 do a.Add(i);
  Check(a.Capacity=cap,'refill reuses the memory');
  a.Clear(true);
  Check(a.Capacity=0,'Clear(true) frees the memory');
  a.Reserve(5000);
  cap:=a.Capacity;
  for i:=1 to 5000 do a.Add(i);
  Check((cap=5000) and (a.Capacity=5000),'Reserve: no growth up to the reserved size');
  // SetCount: new items are default even over stale reserve slots
  a.Clear;
  a.Add(1); a.Add(2); a.Add(3);
  a.SetCount(1);
  a.SetCount(3);
  Check((a.Count=3) and (a.items[1]=0) and (a.items[2]=0),'SetCount growth gives default items');
  // managed items are released while the memory is kept
  trackedAlive:=0;
  for i:=1 to 10 do begin
    obj:=NewTracked; // explicit variable: a compiler temp would keep the last item alive
    objs.Add(obj);
  end;
  obj:=nil;
  objs.SetCount(4);
  Check(trackedAlive=4,'SetCount releases dropped items');
  obj:=objs.Pop; // the popped item is returned to the caller...
  obj:=nil;       // ...and released here
  Check(trackedAlive=3,'Pop releases the item');
  objs.Clear;
  Check((trackedAlive=0) and (objs.Capacity>0),'Clear releases items, keeps capacity');
  for i:=1 to 100 do strs.Add(String8('item')+String8(IntToStr(i)));
  Check((strs.Count=100) and (strs.items[41]='item42'),'strings');
  strs.Clear(true);
  EndTest;
end;

begin
  try
    TestGenericTree;
    TestHeap;
    TestObjectQueue;
    TestDataQueue;
    TestGenQueue;
    TestPriorityQueue;
    TestObjectList;
    TestGrowArray;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln;
      writeln('TEST FAILED! Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
