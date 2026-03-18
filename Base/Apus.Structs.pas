// This is universal unit containing implementation
// of basic structures on common types: trees, hashes etc...

// Copyright (C) 2002-2015 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

{$M-,H+,R-,Q-}
unit Apus.Structs;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface
uses Apus.Core, Apus.Types, Apus.HashMaps, Classes;

type
 TErrorState=Apus.HashMaps.TErrorState;


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

 // --------------------------------------
 // Hash structures (moved to Apus.HashMaps)
 // --------------------------------------
 THashItem=Apus.HashMaps.THashItem;
 TCell=Apus.HashMaps.TCell;
 TStrHash=Apus.HashMaps.TStrHash;
 THash=Apus.HashMaps.THash;
 TSimpleHash=Apus.HashMaps.TSimpleHash;
 TSimpleHashS=Apus.HashMaps.TSimpleHashS;
 TSimpleHashAS=Apus.HashMaps.TSimpleHashAS;
 TSimpleHash8=Apus.HashMaps.TSimpleHash8;
 PObjectHash=Apus.HashMaps.PObjectHash;
 TObjectHash=Apus.HashMaps.TObjectHash;
 PVarHash=Apus.HashMaps.PVarHash;
 TVarHash=Apus.HashMaps.TVarHash;

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

 // Bit array
 TBitStream=record
  data:array of cardinal;
  size:integer; // number of bits stored
  procedure Init(estimatedSize:integer); // size in bits
  procedure SetBit(index:integer;value:integer);
  function GetBit(index:integer):integer;
  procedure Put(data:cardinal;count:integer); overload;
  procedure Put(var buf;count:integer); overload; // append count bits to the stream
  procedure Get(var buf;count:integer); // read count bits from the stream (from readPos position)
  function SizeInBytes:integer; // return size of stream in bytes
 private
  capacity,readPos:integer;
  procedure Allocate(count:integer); // ensure there is space for count bits
 end;

 // Simple list of variants
{ TSimpleList=record
  values:array of variant;
  procedure Add(v:variant);
 end;}

 // Sort array of records by an integer/float/double field at given byte offset
 procedure SortRecordsByInt(var items;itemSize,itemCount,offset:integer;asc:boolean=true);
 procedure SortRecordsByFloat(var items;itemSize,itemCount,offset:integer;asc:boolean=true);
 procedure SortRecordsByDouble(var items;itemSize,itemCount,offset:integer;asc:boolean=true);

implementation
 uses SysUtils, Variants,
   Apus.Strings  // FastHash, StrHash
   {$IFDEF DELPHI},windows{$ENDIF}; // FPC has built-in support (RTL) for atomic operations

 const
  _INITIALIZED_:string='INITIALIZED'; // marker string used to check whether a structure was initialized

{  constructor TVarHash.Init;
   begin
    KeyCount:=0;
    SetLength(keys,100);
    SetLength(values,100);
   end;

  procedure TVarHash.Add;
   begin
   end;

  procedure TVarHash.Replace(key:variant;value:variant);
   begin
   end;

  function TVarHash.Get(key:variant;index:integer=0):variant;
   begin
   end;

  function TVarHash.Count(key:variant):integer;
   begin
   end;

  function TVarHash.GetKey(index:integer):variant;
   begin
   end;

  procedure TVarHash.SortKeys;
   begin
   end;  }


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
   children.Insert(index,item);
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

procedure TGenericTree.Traverse(mode: TraverseMode;
  iterator: TTreeiterator);

 // Depth-search: children, then root
 procedure DepthSearch(depth:integer;iterator:TTreeIterator;RootFirst:boolean);
  var
   i:integer;
 begin
   if RootFirst then
    iterator(depth,self);
   for i:=0 to children.count-1 do
    DepthSearch(depth+1,iterator,RootFirst);
   if not RootFirst then
    iterator(depth,self);
 end;
 // Width-search
 procedure WidthSearch;
  var
   queue:TList;
   index,i:integer;
   item:TGenericTree;
 begin
  queue:=TList.Create;
  queue.add(self);
  index:=0;
  while index<queue.Count do begin
   item:=queue[index];
   inc(index);
   iterator(0,item);
   for i:=0 to item.children.Count-1 do
    queue.Add(item.children[i]);
  end;
 end;

begin
 case mode of
  ChildrenFirst:DepthSearch(0,iterator,false);
  RootFirst:DepthSearch(0,iterator,true);
  ByLevels:WidthSearch;
 end;
end;

// -------------------------------------------------------
// TBitStream
// -------------------------------------------------------

 procedure TBitStream.Init;
  begin
   size:=0; readPos:=0;
   SetLength(data,(estimatedSize+31) div 32);
   capacity:=length(data)*32;
   FillChar(data[0],length(data),0);
  end;

 procedure TBitStream.SetBit(index:integer;value:integer);
  var
   i:integer;
  begin
   i:=index shr 5;
   if value=0 then
    data[i]:=data[i] and not (1 shl (index and 31))
   else
    data[i]:=data[i] or (1 shl (index and 31))
  end;

 function TBitStream.GetBit(index:integer):integer;
  begin
   result:=(data[index shr 5] shr (index and 31)) and 1;
  end;

 procedure TBitStream.Allocate(count:Integer);
  begin
   if size+count>capacity then begin
    capacity:=round((capacity+1024)*1.5);
    SetLength(data,capacity div 32);
   end;
  end;

 // Simple non-effective version
 procedure TBitStream.Put(data:cardinal;count:integer);
  var
   i:integer;
  begin
   Allocate(count);
   for i:=0 to count-1 do begin
    SetBit(size,data and 1);
    inc(size);
    data:=data shr 1;
   end;
  end;

 procedure TBitStream.Put(var buf;count:integer); // write count bits to the stream (from curPos position)
  var
   pb:PByte;
   i:integer;
   b:byte;
  begin
   Allocate(count);
   pb:=@buf; b:=pb^;
   // простая, неэффективная версия
   for i:=0 to count-1 do begin
    if b and 1>0 then
     data[size shr 3]:=data[size shr 3] or (1 shl (i and 7));
    b:=b shr 1;
    inc(size);
    if i and 7=7 then begin
     inc(pb); b:=pb^;
    end;
   end;
  end;

 procedure TBitStream.Get(var buf;count:integer); // read count bits from the stream (from curPos position)
  var
   i:integer;
   pb:PByte;
  begin
   // простая, неэффективная версия
   //pb:=@buf;
   for i:=0 to count-1 do begin
    GetBit(readPos);
    inc(readPos);
   end;
  end;

 function TBitStream.SizeInBytes:integer; // return size of stream in bytes
  begin
   result:=(size+7) div 8;
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
  list.GetAll;
  for obj in items do Add(obj);
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

// -------------------------------------------
// Sort records by field
// -------------------------------------------
procedure QuickSortRecords(data:pointer;itemSize,offset,a,b,valueType:integer;asc:boolean);
 function Compare(p1,p2:pointer):boolean; {$IFDEF FPC} inline; {$ENDIF}
  begin
   case valueType of
    1:result:=(PInteger(p1)^>PInteger(p2)^);
    2:result:=(PSingle(p1)^>PSingle(p2)^);
    3:result:=(PDouble(p1)^>PDouble(p2)^);
    else result:=false;
   end;
  end;
 var
  lo,hi,mid:integer;
  loVal,hiVal:PByte;
  midVal:int64; // 8 bytes - fits int, float and double
  valSize:integer;
 begin
  lo:=a; hi:=b;
  mid:=(a+b) div 2;
  loVal:=PByte(UIntPtr(data)+lo*itemSize+offset);
  hiVal:=PByte(UIntPtr(data)+hi*itemSize+offset);
  if valueType=3 then valSize:=8 else valSize:=4;
  move(PByte(UIntPtr(data)+mid*itemSize+offset)^,midval,valSize);
  repeat
   if asc then begin
    while Compare(@midVal,loVal) do begin inc(lo); inc(loVal,itemSize) end;
    while Compare(hiVal,@midVal) do begin dec(hi); dec(hiVal,itemSize) end;
   end else begin
    while Compare(loVal,@midVal) do begin inc(lo); inc(loVal,itemSize) end;
    while Compare(@midVal,hiVal) do begin dec(hi); dec(hiVal,itemSize) end;
   end;
   if lo<=hi then begin
    Swap(pointer(UIntPtr(data)+lo*itemSize)^,pointer(UIntPtr(data)+hi*itemSize)^,itemSize);
    inc(lo); inc(loVal,itemSize);
    dec(hi); dec(hiVal,itemSize);
   end;
  until lo>hi;
  if hi>a then QuickSortRecords(data,itemSize,offset,a,hi,valueType,asc);
  if lo<b then QuickSortRecords(data,itemSize,offset,lo,b,valueType,asc);
 end;

procedure SortRecordsByInt(var items;itemSize,itemCount,offset:integer;asc:boolean);
 begin
  if itemCount<2 then exit;
  QuickSortRecords(@items,itemSize,offset,0,itemCount-1,1,asc);
 end;

procedure SortRecordsByFloat(var items;itemSize,itemCount,offset:integer;asc:boolean);
 begin
  if itemCount<2 then exit;
  QuickSortRecords(@items,itemSize,offset,0,itemCount-1,2,asc);
 end;

procedure SortRecordsByDouble(var items;itemSize,itemCount,offset:integer;asc:boolean);
 begin
  if itemCount<2 then exit;
  QuickSortRecords(@items,itemSize,offset,0,itemCount-1,3,asc);
 end;

end.

