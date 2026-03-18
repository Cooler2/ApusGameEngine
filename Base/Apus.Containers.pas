// Algorithmic containers: trees, heaps, queues and object lists
//
// SCOPE: In-memory generic/container primitives for fast insert/search/pop operations.
// Used by modules that need lightweight data structures without domain logic.
//
// ADD HERE: New container types (queues, heaps, trees, sets), container helpers.
// DON'T ADD: Hash maps (use Apus.HashMaps), binary streams (use Apus.Types),
// record sorting helpers (use Apus.Types), domain-specific caches/storage.

// Copyright (C) 2002-2026 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

{$M-,H+,R-,Q-}
unit Apus.Containers;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface
uses Apus.Core, Apus.Types, Classes;

type
 TErrorState=(
  esNoError       =  0,
  esEmpty         =  1,
  esNotFound      =  2,
  esNoMoreItems   =  3,
  esOverflow      =  4);



 // --------------------------------------
 // Structures of comparable items
 // --------------------------------------
 // Base class for custom structures items
 TBaseItem=class
  value:integer;
  function Compare(item:TBaseItem):integer; virtual;
 end;
 // Container with integer key
 TIntItem=class(TBaseItem)
  data:pointer;
  constructor Create(key:integer;content:pointer);
 end;
 // Container with floating-point key
 TFloatItem=class(TBaseItem)
  value:double;
  data:pointer;
  constructor Create(key:double;content:pointer);
  function Compare(item:TBaseItem):integer; override;
 end;
 // Container with string key
 PString=^string;
 TStrItem=class(TBaseItem)
  value:PString;
  data:pointer;
  constructor Create(var key:string;content:pointer);
  function Compare(item:TBaseItem):integer; override;
 end;

 THeap=class
  items:array of TBaseItem;
  hSize,count:integer;  // can be readed: size of heap and count of elements
  lastError:TErrorState;    // status of the last operation
  constructor Create(HeapSize:integer); // Create a new heap with given capacity
  procedure Put(item:TBaseItem); // Put new item into heap
  function Get:TBaseItem; // Get item from the top of the heap
  destructor Destroy; override; // Destroy the heap (but not its elements if any!)
  procedure ClearAndDestroy; virtual; // Destroy heap and all its elements
 end;

 // Queue of strings
 TStringQueue=object
  procedure Init(size:integer); // can be called only once
  procedure Clear;
  procedure Add(st:String8);
  function Get:String8;
  function Empty:boolean;
 private
  lock:integer;
  data:array of String8;
  used:integer; // first used element (if not equal to last)
  free:integer; // first free element
 end;

 // Queue of objects
 TObjectQueue=object
  procedure Init(size:integer);
  procedure Clear;
  procedure Add(obj:TObject);
  function Get:TObject;
  function Empty:boolean;
 private
  lock:integer;
  data:TObjectArray;
  used:integer; // first used element (if not equal to last)
  free:integer; // first free element
 end;

 // Data item for FIFO or priorited queues
 TDataItem=record
  data:integer;
  value:single; // used as priority for priorited queue
  ptr:pointer;
 end;
 TDataItems=array of TDataItem;

 // Generic data queue
 TQueue=object
  procedure Init(size:integer);
  procedure Clear;
  function Add(const item:TDataItem):boolean;
  function Get(out item:TDataItem):boolean;
  function Empty:boolean;
  function Count:integer;
 private
  data:array of TDataItem;
  lock:integer;
  used:integer; // first used element (if not equal to last)
  free:integer; // first free element
 end;

 // Generic queue
 TGenQueue<T>=record
  procedure Init(size:integer);
  procedure Clear;
  function Add(const item:T):boolean;
  function Get(out item:T):boolean; overload;
  function Get:T; overload; // This is not very thread-safe
  function Empty:boolean;
  function Count:integer;
 private
  data:array of T;
  lock:integer;
  used:integer; // first used element (if not equal to last)
  free:integer; // first free element
 end;

 TPriorityFunc=function(const item:TDataItem):single;

 // Priotity queue
 TPriorityQueue=object
  count:integer;
  procedure Init(size:integer);
  function Add(const item:TDataItem):boolean; // returns true if added, false - queue is full
  function Get(out item:TDataItem):boolean;
  function WaitFor(out item:TDataItem;timeMS:integer=100):boolean;
  function IsEmpty:boolean; // just for name
  procedure UpdatePriorities(priorityFunc:TPriorityFunc);
 private
  lock:integer;
  data:TDataItems;
 end;

 // Simple list of objects
 TObjectList=object
  count:integer;
  procedure Clear(freeObjects:boolean=false);
  function Add(obj:TObject;uniqueOnly:boolean=false):boolean; overload;
  function Add(list:TObjectList):boolean; overload;
  function Remove(obj:TObject;keepOrder:boolean=false):boolean; overload; // removes only the 1-st found reference, returns false if not found
  function Remove:TObject; overload; // get the last object
  function RemoveFirst:TObject; overload; // get the first object
  procedure FreeAll; // Free all objects and clear the list
  function Get(index:cardinal):TObject;
  function GetAll:TObjectArray;
 private
  initialized:string;
  lock:integer;
  data:TObjectArray;
  procedure Init;
 end;

 // Simple list of variants
{ TSimpleList=record
  values:array of variant;
  procedure Add(v:variant);
 end;}

 // --------------------------------------
 // Structures of arbitrary items
 // --------------------------------------

 // Traversing modes
 TraverseMode=(ChildrenFirst, // Handle children, then root (depth-search)
               RootFirst,     // Handle root, then children (depth-search)
               byLevels);     // width-search (by levels)
 // Iterator for tree traverse
 // depth - item's depth (distance from root, for depth-search only)
 // item - TGenericTree object
 TTreeIterator=procedure(depth:integer;item:TObject);

 // Generic tree
 TGenericTree=class
  private
   parent:TGenericTree;
   selfIndex:integer; // index in parent's children list
   children:TList;
  public
   data:pointer;
   freeObjects:boolean; // treat data as objects and free them
   preserveOrder:boolean; // true if order of children must be preserved
   constructor Create(useObjects:boolean=false;useOrder:boolean=false);
   destructor Destroy; override;
   function GetParent:TGenericTree;
   function GetIndex:integer; // return index in parent's children list
   function GetChildrenCount:integer;
   function GetChild(index:integer):TGenericTree;
   // Add child to the end of the children list, return it's index
   function AddChild(item:pointer):integer;
   // Insert child item to specified position
   procedure InsertChild(item:pointer;index:integer);
   // Traverse this tree
   procedure Traverse(mode:TraverseMode;iterator:TTreeiterator);
 end;

 // INCOMPLETED CODE
 TTreeItem=class
  weight:integer;
  key:integer;
  data:pointer;
  left,right,parent:TTreeItem;
  function Compare(item:TTreeItem):integer;
 end;
 TTree=class
  root:TTreeItem;
  constructor Create;
  destructor Destroy; override;
 end;
 // END OF INCOMPLETED CODE


implementation
 uses SysUtils, Variants,
   Apus.Strings  // FastHash, StrHash
   {$IFDEF DELPHI},windows{$ENDIF}; // FPC has built-in support (RTL) for atomic operations

 const
  _INITIALIZED_:string='INITIALIZED'; // marker string used to check whether a structure was initialized


 function TBaseItem.Compare;
  begin
   if value>item.value then result:=1 else
    if value<item.value then result:=-1 else
     result:=0;
  end;

 constructor TIntItem.Create;
  begin
   value:=key;
   data:=content;
  end;

 constructor TFloatItem.Create;
  begin
   value:=key;
   data:=content;
  end;

 function TFloatItem.Compare;
  begin
   if not (item is TFloatItem) then exit(0);
   if value>(item as TFloatItem).value then result:=1 else
    if value<(item as TFloatItem).value then result:=-1 else
     result:=0;
  end;

 function TTreeItem.Compare;
  begin
    if key>item.key then result:=1 else
    if key<item.key then result:=-1 else
     result:=0;
  end;


 constructor TStrItem.Create;
  begin
   value:=addr(key);
   data:=content;
  end;

 function TStrItem.Compare;
  begin
   if not (item is TStrItem) then exit(0);
   if value^>(item as TStrItem).value^ then result:=1 else
    if value^<(item as TStrItem).value^ then result:=-1 else
     result:=0;
  end;

 constructor THeap.Create;
  begin
   hSize:=HeapSize+1;
   SetLength(items,hSize);
   count:=0; LastError:=esNoError;
  end;

 procedure THeap.Put;
  var
   p:integer;
  begin
   if count>hSize then begin
    LastError:=esOverflow;
    exit;
   end;
   inc(count);
   p:=count;
   while (p>1) and (item.compare(items[p div 2])<0) do begin
    items[p]:=items[p div 2];
    p:=p div 2;
   end;
   items[p]:=item;
   LastError:=esNoError;
  end;

 function THeap.Get;
  var
   p,p1,p2:integer;
  begin
   if count=0 then begin
    result:=nil;
    LastError:=esEmpty;
    exit;
   end;
   result:=items[1];
   dec(count);
   p:=1;
   repeat
    p1:=p*2;
    if p1>count then break;
    p2:=p1+1;
    if (p2<=count) and (items[p2].compare(items[p1])<0) then
      p1:=p2;
    if items[p1].compare(items[count+1])<0 then begin
     items[p]:=items[p1];
     p:=p1;
    end else break;
   until false;
   items[p]:=items[count+1];
   LastError:=esNoError;
  end;

 destructor THeap.Destroy;
  begin
   SetLength(items,0);
   count:=0;
  end;

 procedure THeap.ClearAndDestroy;
  var
   i:integer;
  begin
   for i:=1 to count do
    items[i].destroy;
   count:=0;
   SetLength(items,0);
   Free;
  end;

 constructor TTree.Create;
  begin
   root:=nil;
  end;

 destructor TTree.Destroy;
  begin
  end;

{ TGenericTree }

function TGenericTree.AddChild(item: pointer): integer;
 var
  t:TGenericTree;
begin
  t:=TGenerictree.Create(FreeObjects,PreserveOrder);
  t.data:=item;
  t.parent:=self;
  t.SelfIndex:=children.Count;
  result:=children.Add(t);
end;

constructor TGenericTree.Create;
begin
  parent:=nil;
  data:=nil;
  children:=TList.Create;
  FreeObjects:=UseObjects;
  PreserveOrder:=useOrder;
end;

destructor TGenericTree.Destroy;
 var
  o:TObject;
  item:TGenericTree;
  i:integer;
begin
  // Destroy children
  while children.count>0 do begin
   item:=children[children.count-1];
   item.destroy;
  end;
  children.destroy;
  // Free object
  if FreeObjects then begin
   o:=data;
   o.Free;
  end;
  // Remove from parent's children
  if parent<>nil then begin
   if PreserveOrder then begin
    parent.children.Delete(SelfIndex);
    // Откорректировать SelfIndex для смещенных эл-тов
    for i:=SelfIndex to parent.children.Count-1 do begin
     item:=parent.children[i];
     item.SelfIndex:=i;
    end;
   end else begin
    // Удалить элемент заменив его последним
    parent.children.Move(parent.children.Count-1,SelfIndex);
    item:=parent.children[SelfIndex];
    item.SelfIndex:=SelfIndex;
   end;
  end;
  inherited;
end;

function TGenericTree.GetChild(index: integer): TGenericTree;
begin
 result:=children[index];
end;

function TGenericTree.GetChildrenCount: integer;
begin
 result:=children.count;
end;

function TGenericTree.GetIndex: integer;
begin
 result:=SelfIndex;
end;

function TGenericTree.GetParent: TGenericTree;
begin
 result:=parent;
end;

procedure TGenericTree.InsertChild(item: pointer; index: integer);
 var
  t,t2:TGenericTree;
  i:integer;
begin
  if index<0 then
   raise EError.Create('GenericTree: invalid index');
  if index>children.count then index:=children.count;
  t:=TGenerictree.Create(FreeObjects,PreserveOrder);
  t.data:=item;
  t.parent:=self;
  t.SelfIndex:=index;
  if PreserveOrder then begin
   children.Insert(index,t);
   for i:=index to children.count-1 do begin
    t:=children[i];
    t.selfIndex:=i;
   end;
  end else begin
   children.Add(nil);
   t2:=children[index];
   children[children.count-1]:=t2;
   t2.SelfIndex:=children.count-1;
   children[index]:=t;
  end;
end;

procedure TGenericTree.Traverse(mode:TraverseMode;iterator:TTreeIterator);
  // Depth-search: children, then root
  procedure DepthSearch(node:TGenericTree;depth:integer;rootFirst:boolean);
  var
    i:integer;
  begin
    if rootFirst then
      iterator(depth,node);
    for i:=0 to node.children.count-1 do
      DepthSearch(node.children[i],depth+1,rootFirst);
    if not rootFirst then
      iterator(depth,node);
  end;
  // Width-search
  procedure WidthSearch;
  var
    queue:TList;
    index,i:integer;
    item:TGenericTree;
  begin
    queue:=TList.Create;
    try
      queue.Add(self);
      index:=0;
      while index<queue.Count do begin
        item:=queue[index];
        inc(index);
        iterator(0,item);
        for i:=0 to item.children.Count-1 do
          queue.Add(item.children[i]);
      end;
    finally
      queue.Free;
    end;
  end;
begin
  case mode of
    ChildrenFirst:DepthSearch(self,0,false);
    RootFirst:DepthSearch(self,0,true);
    ByLevels:WidthSearch;
  end;
end;

{ TStringQueue }
procedure TStringQueue.Add(st:String8);
 var
  f:integer;
 begin
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then raise EWarning.Create('StringQueue overflow');
   data[free]:=st;
   free:=f;
  finally
   lock:=0;
  end;
 end;

procedure TStringQueue.Clear;
 var
  i:integer;
 begin
  SpinLock(lock);
  for i:=0 to high(data) do data[i]:='';
  used:=0; free:=0;
  lock:=0;
 end;

function TStringQueue.Empty:boolean;
 begin
  SpinLock(lock);
  result:=used=free;
  lock:=0;
 end;

function TStringQueue.Get:String8;
 begin
  if length(data)=0 then exit('');
  SpinLock(lock);
  try
   if used<>free then begin
    result:=data[used];
    inc(used);
    if used>high(data) then used:=0;
   end else
    result:='';
  finally
   lock:=0;
  end;
 end;

procedure TStringQueue.Init(size:integer);
 begin
  ASSERT(data=nil);
  SetLength(data,size);
  used:=0; free:=0;
  lock:=0;
 end;

{ TObjectQueue }

procedure TObjectQueue.Add(obj:TObject);
 var
  f:integer;
 begin
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then raise EWarning.Create('ObjectQueue overflow');
   data[free]:=obj;
   free:=f;
  finally
   lock:=0;
  end;
 end;

procedure TObjectQueue.Clear;
 var
  i:integer;
 begin
  SpinLock(lock);
  for i:=0 to high(data) do data[i]:=nil;
  used:=0; free:=0;
  lock:=0;
 end;

function TObjectQueue.Empty: boolean;
 begin
  SpinLock(lock);
  result:=used=free;
  lock:=0;
 end;

function TObjectQueue.Get:TObject;
 begin
  result:=nil;
  ASSERT(length(data)>0);
  if length(data)=0 then exit;
  SpinLock(lock);
  try
   if used<>free then begin
    result:=data[used];
    inc(used);
    if used>high(data) then used:=0;
   end;
  finally
   lock:=0;
  end;
 end;

procedure TObjectQueue.Init(size: integer);
 begin
  ASSERT(data=nil);
  SetLength(data,size);
  used:=0; free:=0;
  lock:=0;
 end;

{ TQueue }

function TQueue.Add(const item:TDataItem):boolean;
 var
  f:integer;
 begin
  result:=false;
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then exit;
   data[free]:=item;
   free:=f;
   result:=true;
  finally
   lock:=0;
  end;
 end;

procedure TQueue.Clear;
 var
  i:integer;
 begin
  SpinLock(lock);
  used:=0; free:=0;
  lock:=0;
 end;

function TQueue.Count:integer;
 begin
  SpinLock(lock);
  result:=free-used;
  if result<0 then inc(result,length(data));
  lock:=0;
 end;

function TQueue.Empty:boolean;
 begin
  SpinLock(lock);
  result:=used=free;
  lock:=0;
 end;

function TQueue.Get(out item:TDataItem):boolean;
 begin
  ASSERT(length(data)>0);
  if length(data)=0 then exit;
  SpinLock(lock);
  try
   if used<>free then begin
    result:=true;
    item:=data[used];
    inc(used);
    if used>high(data) then used:=0;
   end else
    result:=false;
  finally
   lock:=0;
  end;
 end;

procedure TQueue.Init(size:integer);
 begin
  ASSERT(data=nil);
  SetLength(data,size);
  used:=0; free:=0;
  lock:=0;
 end;

 { TGenQueue }

function TGenQueue<T>.Add(const item:T):boolean;
 var
  f:integer;
 begin
  result:=false;
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then exit;
   data[free]:=item;
   free:=f;
   result:=true;
  finally
   lock:=0;
  end;
 end;

procedure TGenQueue<T>.Clear;
 var
  i:integer;
 begin
  SpinLock(lock);
  used:=0; free:=0;
  lock:=0;
 end;

function TGenQueue<T>.Count:integer;
 begin
  SpinLock(lock);
  result:=free-used;
  if result<0 then inc(result,length(data));
  lock:=0;
 end;

function TGenQueue<T>.Empty:boolean;
 begin
  SpinLock(lock);
  result:=used=free;
  lock:=0;
 end;

function TGenQueue<T>.Get:T;
 begin
  if not Get(result) then
   raise EWarning.Create('Queue is empty');
 end;

function TGenQueue<T>.Get(out item:T):boolean;
 begin
  result:=false;
  ASSERT(length(data)>0);
  if length(data)=0 then exit;
  SpinLock(lock);
  try
   if used<>free then begin
    result:=true;
    item:=data[used];
    inc(used);
    if used>high(data) then used:=0;
   end else
    result:=false;
  finally
   lock:=0;
  end;
 end;

procedure TGenQueue<T>.Init(size:integer);
 begin
  ASSERT(data=nil);
  SetLength(data,size);
  used:=0; free:=0;
  lock:=0;
 end;


{ TPriorityQueue }

function TPriorityQueue.Add(const item:TDataItem):boolean;
 var
  p:integer;
 begin
  SpinLock(lock);
  try
   if count>=high(data) then exit(false);
   result:=true;
   inc(count);
   p:=count;
   while (p>1) and (item.value>data[p div 2].value) do begin
    data[p]:=data[p div 2];
    p:=p div 2;
   end;
   data[p]:=item;
  finally
   lock:=0;
  end;
 end;

function TPriorityQueue.IsEmpty:boolean;
 begin
  result:=count=0;
 end;

function TPriorityQueue.Get(out item:TDataItem):boolean;
 var
  p,p1,p2:integer;
 begin
  SpinLock(lock);
  try
   if count=0 then exit(false);
   item:=data[1];
   dec(count);
   p:=1;
   repeat
    p1:=p*2;
    if p1>count then break;
    p2:=p1+1;
    if (p2<=count) and (data[p2].value>data[p1].value) then
      p1:=p2;
    if data[p1].value>data[count+1].value then begin
     data[p]:=data[p1];
     p:=p1;
    end else break;
   until false;
   data[p]:=data[count+1];
   data[count+1].value:=0.0/0.0;
   result:=true;
  finally
   lock:=0;
  end;
 end;

procedure TPriorityQueue.UpdatePriorities(priorityFunc:TPriorityFunc);
 var
  tmp:TDataItems;
  i,cnt,p:integer;
 begin
  if count=0 then exit;
  SpinLock(lock);
  try
   tmp:=Copy(data,1,count);
   cnt:=count;
   count:=0;
   for i:=0 to high(tmp) do begin
    tmp[i].value:=PriorityFunc(tmp[i]);
    inc(count);
    p:=count;
    while (p>1) and (tmp[i].value>data[p div 2].value) do begin
     data[p]:=data[p div 2];
     p:=p div 2;
    end;
    data[p]:=tmp[i];
   end;
  finally
   lock:=0;
  end;
 end;

procedure TPriorityQueue.Init(size:integer);
 begin
  lock:=0;
  count:=0;
  SetLength(data,size+1);
  data[0].value:=1.0e38;
 end;

function TPriorityQueue.WaitFor(out item:TDataItem;timeMS:integer):boolean;
 var
  deadline:int64;
 begin
  if Get(item) then exit(true);
  deadline:=CoreTime.Ticks+timeMS;
  repeat
   sleep(1);
   if Get(item) then exit(true);
  until CoreTime.Ticks>=deadline;
  result:=false;
 end;

{ TObjectList }

function TObjectList.Add(obj:TObject;uniqueOnly:boolean=false):boolean;
 var
  i:integer;
 begin
  result:=false;
  ASSERT(obj<>nil);
  if initialized='' then Init;
  SpinLock(lock);
  try
   if uniqueOnly then
    for i:=0 to count-1 do
     if data[i]=obj then exit;
   result:=true;
   if count>high(data) then
    SetLength(data,count+count div 2);
   data[count]:=obj;
   inc(count);
  finally
   lock:=0;
  end;
 end;

function TObjectList.Remove:TObject;
 begin
  if initialized='' then Init;
  SpinLock(lock);
  try
   if count>0 then begin
    dec(count);
    result:=data[count];
   end else
    result:=nil;
  finally
   lock:=0;
  end;
 end;

function TObjectList.RemoveFirst:TObject;
 begin
  if initialized='' then Init;
  SpinLock(lock);
  try
   if count>0 then begin
    result:=data[0];
    dec(count);
    if count>0 then
     move(data[1],data[0],count*sizeof(pointer));
   end else
    result:=nil;
  finally
   lock:=0;
  end;
 end;

function TObjectList.Remove(obj:TObject;keepOrder:boolean=false):boolean;
 var
  i:integer;
 begin
  if initialized='' then Init;
  result:=false;
  SpinLock(lock);
  try
   for i:=0 to count-1 do
    if data[i]=obj then begin
     dec(count);
     if keepOrder then
      move(data[i+1],data[i],(count-i)*sizeof(pointer))
     else
      data[i]:=data[count];
     result:=true;
     break;
    end;
  finally
   lock:=0;
  end;
 end;

function TObjectList.Add(list:TObjectList):boolean;
var
  items:TObjectArray;
  obj:TObject;
begin
  result:=true;
  items:=list.GetAll;
  for obj in items do
    if not Add(obj) then
      result:=false;
end;

procedure TObjectList.Clear(freeObjects:boolean=false);
 var
  i:integer;
  list:TObjectArray;
  obj:TObject;
 begin
  if initialized='' then Init;
  if freeObjects then begin
   list:=GetAll;
   for obj in list do obj.Free;
  end;
  SpinLock(lock);
  try
   count:=0;
   SetLength(data,32);
  finally
   lock:=0;
  end;
 end;

procedure TObjectList.FreeAll;
 var
  list:TObjectArray;
  obj:TObject;
 begin
  if initialized='' then exit;
  SpinLock(lock);
  try
   list:=copy(data,0,count);
   count:=0;
   SetLength(data,32);
  finally
   lock:=0;
  end;
  for obj in list do
   obj.Free;
 end;

function TObjectList.Get(index:cardinal):TObject;
 begin
  SpinLock(lock);
  try
   if index<length(data) then result:=data[index]
    else result:=nil;
  finally
   lock:=0;
  end;
 end;

function TObjectList.GetAll:TObjectArray;
 begin
  SpinLock(lock);
  try
   result:=data;
   SetLength(result,count);
  finally
   lock:=0;
  end;
 end;

procedure TObjectList.Init;
 begin
  lock:=0;
  count:=0;
  SetLength(data,32);
  initialized:=_INITIALIZED_;
 end;

end.

