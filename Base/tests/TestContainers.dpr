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

procedure TestStringQueue;
var
  q:TStringQueue;
  overflowCaught:boolean;
begin
  StartTest('Containers.StringQueue');
  q.Init(3);
  Check(q.Empty,'empty after init');
  q.Add('a');
  q.Add('b');
  Check(not q.Empty,'not empty');
  Check(q.Get='a','get a');
  Check(q.Get='b','get b');
  Check(q.Get='','get empty string');
  Check(q.Empty,'empty after reads');

  overflowCaught:=false;
  q.Clear;
  q.Add('1');
  q.Add('2');
  try
    q.Add('3');
  except
    on EWarning do overflowCaught:=true;
  end;
  Check(overflowCaught,'overflow raises EWarning');
  EndTest;
end;

procedure TestObjectQueue;
var
  q:TObjectQueue;
  o1,o2:TObject;
  overflowCaught:boolean;
  leakObj:TObject;
begin
  StartTest('Containers.ObjectQueue');
  q.Init(3);
  o1:=TObject.Create;
  o2:=TObject.Create;
  try
    q.Add(o1);
    q.Add(o2);
    Check(q.Get=o1,'get o1');
    Check(q.Get=o2,'get o2');
    Check(q.Get=nil,'get nil when empty');

    overflowCaught:=false;
    q.Clear;
    q.Add(o1);
    q.Add(o2);
    leakObj:=TObject.Create;
    try
      q.Add(leakObj);
    except
      on EWarning do overflowCaught:=true;
    end;
    leakObj.Free;
    Check(overflowCaught,'overflow raises EWarning');
  finally
    o1.Free;
    o2.Free;
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

begin
  try
    TestGenericTree;
    TestHeap;
    TestStringQueue;
    TestObjectQueue;
    TestDataQueue;
    TestGenQueue;
    TestPriorityQueue;
    TestObjectList;

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
