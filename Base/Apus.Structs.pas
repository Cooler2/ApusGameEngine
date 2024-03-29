﻿// This is universal unit containing implementation
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
uses Apus.Types, Apus.Common, Classes;

type
 TErrorState=(
  esNoError       =  0,
  esEmpty         =  1,
  esNotFound      =  2,
  esNoMoreItems   =  3,
  esOverflow      =  4);


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
 // Hash structures
 // --------------------------------------
 THashItem=record
  key:^string;
  value:pointer;
 end;
 TCell=record
  items:array of THashItem;
  count,size:integer;
 end;
 // Hash String->Pointer (1:1) store references, DOESNT copy key strings, so this is good as auxiliary
 // structure to make an existing data storage faster
 // WARNING! THIS IS QUITE OLD CLASS AND NOT COVERED BY TESTS => MAY BE BUGGY
 TStrHash=class
  Hcount,Hsize:integer; // number of cells
  cells:array of TCell;
  LastError:TErrorState;
  constructor Create;
  constructor CreateSize(newsize:integer);
  procedure Put(var key:string;data:pointer);
  function Get(key:string):pointer;
  procedure Remove(key:string);
  function FirstKey:string;   // Start key enumeration (no hash operation allowed)
  function NextKey:string;    // Fetch next key (any operation will reset enumeration)
  function GetKeys:StringArr; // return all keys
  function GetValues:PointerArray; // return all pointer values
  destructor Destroy; override;
 private
  CurCell,CurItem:integer;
  mask:cardinal;
  function HashValue(str:string):integer;
 end;

 // Another hash: string->variant(s) (1:1 or 1:n)
 // Intended to STORE data, not just reference as TStrHash
 // Структура не отличается офигенной скоростью, но хорошо работает в не особо критичных местах
 // Допускает возможность хранения нескольких значений для каждого ключа,
 // в таком режиме структуру можно рассматривать как индексированную таблицу
 THash=object
  keys:array of String8;
  count:integer; // number of keys (can be less than length of keys array!)
  values:VariantArray;
  vcount:integer; // number of values (can be less than length of values array!)
  constructor Init(allowMultiple:boolean=false); // not thread-safe!
  // Добавить значение, соответствующее ключу
  // replace - только для режима multi: добавляет новое значение к ключу, либо перезаписывает существующее
  procedure Put(const key:String8;value:variant;replace:boolean=false);
  // Получить значение, соответствующее ключу. Если разрешено множество значений на ключ, то можно выбрать элемент с номером item (начиная с 0)
  function Get(const key:String8;item:integer=0):variant; // get value associated with the key, or Unassigned if none
  function GetAll(const key:String8):VariantArray; // get array of values (not thread-safe!)
  function GetNext:variant; // get next value associated with the key, or Unassigned if none (not thread-safe!!!)
  function AllKeys:AStringArr;
  procedure SortKeys; // ключи без значений удаляются
  function HasKey(const key:String8):boolean;
  procedure Remove(const key:String8);
 private
  lock:integer;
  multi:boolean; // допускается несколько значений для любого ключа
  links:array of integer; // ссылки на ключи по значению хэша (голова списка)
  next:array of integer; // для каждого ключа - ссылка на ключ с тем же хэшем (односвязный список)
  // used in multi mode (both simple and advanced)
  vlinks:array of integer; // для каждого ключа - ссылка на первое значение
  vNext:array of integer; // для каждого значения - ссылка на следующее значение, принадлежащее тому же ключу
  lastIndex:integer; // индекс последнего взятого значения (в режиме multi)
  hMask:integer;
  function HashValue(const v:String8):integer;
  function Find(const key:String8):integer;
  procedure AddValue(const v:variant);
  procedure RemoveKey(index:integer);
  procedure BuildHash; // Заполняет массивы next и links
 end;

 // Simple storage of "Key->Value" pairs: both keys and values are 64bit integers (or compatible)
 // Returns -1 if there is no value for given key
 TSimpleHash=object
  keys,values:array of int64;
  count:integer; // how many items in keys/values/links are occupied - must be used instead of Length!!!
  procedure Init(estimatedCount:integer);
  procedure Clear;
  procedure Put(key,value:int64);
  function Get(key:int64):int64;  // returns -1 if no value
  function Increment(key:int64;v:int64=1):int64; // add v to given value (put 0 if absent) and return result
  function HasValue(key:int64):boolean;
  procedure Remove(key:int64);
  procedure RemoveValue(value:int64); // remove all keys with given value
 private
  lock:integer;
  links:array of integer; // hash->firstItem: начало списка для каждого возможного значения хэша
  next:array of integer; // itemN->itemN+1: номер следующей пары с таким же хэшем ключа
  hMask:integer;
  fFree:integer; // начало списка свободных элементов (если они вообще есть, иначе -1)
  function HashValue(const k:int64):integer; inline;
 end;

 // string -> int64
 TSimpleHashS=object
  keys:StringArr;
  values:array of int64;
  count:integer; // how many items in keys/values/links are occupied - must be used instead of Length!!!
  procedure Init(estimatedCount:integer=256);
  procedure Clear;
  procedure Put(key:string;value:int64);
  function Get(key:string):int64;  // returns -1 if no value
  function Increment(key:string;v:int64=1):int64; // add v to given value (put 0 if absent) and return result
  function HasValue(key:string):boolean;
  procedure Remove(key:string);
 private
  lock:integer;
  links:array of integer; // hash->firstItem: начало списка для каждого возможного значения хэша
  next:array of integer; // itemN->itemN+1: номер следующей пары с таким же хэшем ключа
  hMask:integer;
  fFree:integer; // начало списка свободных элементов (если они вообще есть, иначе -1)
 end;

 // String8 -> int64
 TSimpleHashAS=object
  keys:AStringArr;
  values:array of int64;
  count:integer; // how many items in keys/values/links are occupied - must be used instead of Length!!!
  procedure Init(estimatedCount:integer=256);
  procedure Clear;
  procedure Put(key:String8;value:int64);
  function Get(key:String8):int64;  // returns -1 if no value
  function Increment(key:String8;v:int64=1):int64; // add v to given value (put 0 if absent) and return result
  function HasValue(key:String8):boolean;
  procedure Remove(key:String8);
 private
  lock:integer;
  links:array of integer; // hash->firstItem: начало списка для каждого возможного значения хэша
  next:array of integer; // itemN->itemN+1: номер следующей пары с таким же хэшем ключа
  hMask:integer;
  fFree:integer; // начало списка свободных элементов (если они вообще есть, иначе -1)
 end;
 TSimpleHash8=TSimpleHashAS; // type alias

 // Open-address hash for quick access to named objects (case-insensitive)
 // Objects with empty name are legit, but won't be added and can't be found
 // If multiple objects with the same name were added, only one of them can be found
 PObjectHash=^TObjectHash;
 TObjectHash=object
  count:integer; // all the keys
  procedure Init(estimatedCount:integer=256); // automatically called upon 1-st Put() call
  procedure Clear;
  procedure Put(value:TNamedObject);
  function Get(key:String8):TNamedObject;
  procedure Remove(value:TNamedObject);
  function ListKeys:StringArray8; // List all object names
  function ListObjects:TNamedObjects; // List all objects
 private
  lock:integer;
  mask:cardinal;
  hashMiss:integer; // for performance test
  values:array of TNamedObject; // zero length == not initialized
  procedure Resize; // Increase capasity *2. Resizing is quite slow so
  function InternalListKeys:StringArray8;
  function InternalListObjects:TNamedObjects; // List all objects
  procedure InternalPut(value:TNamedObject); //inline;
 end;

 // Open-address hash (case-insensitive) string8 -> variant
 PVarHash=^TVarHash;
 TVarHash=object
  count:integer; // all the keys
  procedure Init(estimatedCount:integer=256); // automatically called upon 1-st Put() call
  procedure Clear;
  procedure Put(key:String8;value:variant); // unassigned value is not allowed, use Remove() to clear key
  function HasKey(key:String8):boolean;
  function Get(key:String8):variant;
  procedure Remove(key:String8);
  function ListKeys:StringArray8;
 private
  initialized:string;
  lock:integer;
  mask:cardinal;
  hashMiss:integer; // for performance test
  keys:array of string8;
  values:array of variant;
  procedure Resize; // Increase capasity *2. Resizing is quite slow so
  function InternalListKeys:StringArray8;
  function InternalListValues:VariantArray;
  procedure InternalPut(key:string8;value:variant);
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

implementation
 uses SysUtils, Variants{, Apus.CrossPlatform}
   {$IFDEF DELPHI},windows{$ENDIF}; // FPC has built-in support (RTL) for atomic operations

 const
  _INITIALIZED_:string='INITIALIZED'; // marker string used to check whether a structure was initialized
  DELETED_PTR:pointer=pointer(1);     // special pointer value used to mark deleted items

  function IsValid(p:pointer):boolean; inline;
   begin
    result:=UIntPtr(p)>=16;
   end;

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

 constructor TStrHash.Create;
  begin
   CreateSize(256);
  end;

 constructor TStrHash.CreateSize;
  var
   i:integer;
  begin
   Hsize:=GetPow2(newsize);
   mask:=hSize-1;
   SetLength(cells,Hsize);
   Hcount:=0;
   LastError:=esNoError;
   for i:=0 to Hsize-1 do begin
    cells[i].count:=0;
    cells[i].size:=1;
    SetLength(cells[i].items,1);
   end;
  end;

 function TStrHash.HashValue;
  var
   i,s:cardinal;
  begin
   s:=0;
   for i:=1 to length(str) do
    s:=s*$20844 xor byte(str[i]);
   result:=s and mask;
  end;

 procedure TStrHash.Put;
  var
   h,i:integer;
  begin
   h:=HashValue(key);
   with cells[h] do begin
    for i:=0 to count-1 do
     if items[i].key^=key then begin
      items[i].value:=data;
      LastError:=esNoError;
      exit;
     end;
    if count=size then begin
     inc(size,3+size div 2);
     SetLength(items,size);
    end;
    items[count].key:=addr(key);
    items[count].value:=data;
    inc(count);
    inc(HCount);
   end;
   LastError:=esNoError;
  end;

 function TStrHash.Get;
  var
   h,i:integer;
  begin
   h:=HashValue(key);
   with cells[h] do begin
    for i:=0 to count-1 do
     if items[i].key^=key then begin
      LastError:=esNoError;
      result:=items[i].value;
      exit;
     end;
   end;
   result:=nil;
   LastError:=esNotFound;
  end;

 procedure TStrHash.Remove;
  var
   h,i:integer;
  begin
   h:=HashValue(key);
   with cells[h] do begin
    for i:=0 to count-1 do
     if items[i].key^=key then begin
      LastError:=esNoError;
      if count>i then
       items[i]:=items[count-1];
      dec(count);
      if size-count>8 then begin
       dec(size,8);
       SetLength(items,size);
      end;
      exit;
     end;
   end;
   LastError:=esNotFound;
  end;

 function TStrHash.FirstKey;
  begin
   CurCell:=0; CurItem:=0;
   result:='';
   while (curCell<HSize) and (cells[curCell].count=0) do inc(curCell);
   if curCell>=HSize then begin
    LastError:=esEmpty;
   end else begin
    result:=cells[CurCell].items[0].key^;
    lastError:=esNoError;
    curItem:=1;
   end;
  end;

 function TStrHash.NextKey;
  var
   found:boolean;
  begin
   result:='';
   found:=false;
   if (CurCell<HSize) and (curItem<cells[curCell].count) then begin
    result:=cells[CurCell].items[CurItem].key^;
    found:=true;
   end;
   inc(CurItem);
   if CurItem>=cells[curCell].count then
    repeat
     inc(CurCell);
     if curCell>=hSize then break;
     CurItem:=0;
     if cells[CurCell].count>0 then begin
      if not found then begin
       result:=cells[curCell].items[0].key^;
       inc(curItem);
      end;
      exit;
     end;
    until false;
   if not found then
    LastError:=esNoMoreItems;
  end;

 function TStrHash.GetKeys:StringArr;
  var
   i,j,s,cnt:integer;
  begin
   s:=hSize;
   cnt:=0;
   SetLength(result,s);
   for i:=0 to hCount-1 do
    for j:=0 to cells[i].count-1 do begin
     if cnt>=s then begin
      s:=s*2;
      SetLength(result,s);
     end;
     result[cnt]:=cells[i].items[j].key^;
     inc(cnt);
    end;
   SetLength(result,cnt);
  end;

 function TStrHash.GetValues:PointerArray;
  var
   i,j,s,cnt:integer;
  begin
   s:=hSize;
   cnt:=0;
   SetLength(result,s);
   for i:=0 to hCount-1 do
    for j:=0 to cells[i].count-1 do begin
     if cnt>=s then begin
      s:=s*2;
      SetLength(result,s);
     end;
     result[cnt]:=cells[i].items[j].value;
     inc(cnt);
    end;
   SetLength(result,cnt);

  end;

 destructor TStrHash.Destroy;
  var
   i:integer;
  begin
   for i:=0 to Hsize-1 do begin
    SetLength(cells[i].items,0);
    cells[i].size:=0;
    cells[i].count:=0;
   end;
   SetLength(cells,0);
   Hcount:=0;
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

{ THash }
constructor THash.Init(allowMultiple:boolean=false);
 var
  i:integer;
 begin
  lock:=0;
  SpinLock(lock);
  count:=0; vCount:=0;
  lastIndex:=-1;
  multi:=allowMultiple;
  SetLength(keys,count);
  if multi then begin
   SetLength(vLinks,32);
   for i:=0 to high(vLinks) do vLinks[i]:=-1;
   SetLength(values,64);
   SetLength(vNext,64);
   for i:=0 to high(vNext) do vNext[i]:=-1;
  end else
   SetLength(values,32);

  SetLength(next,length(keys));
  SetLength(links,64);
  hMask:=$3F;
  BuildHash;
  lock:=0;
 end;

function THash.Find(const key: String8): integer;
 begin
  result:=links[HashValue(key)];
  while (result>=0) and (keys[result]<>key) do result:=next[result];
 end;

function THash.HashValue(const v: String8): integer;
 var
  i:integer;
 begin
  result:=0;
  for i:=1 to length(v) do begin
//   inc(result,byte(v[i]));
   inc(result,byte(v[i]) shl (i and 3)); // 3 почему-то работает лучше всего...
  end;
  result:=result and hMask;
 end;

function THash.HasKey(const key:String8):boolean;
 begin
  SpinLock(lock);
  try
  // 1. Find key index
   result:=Find(key)>=0;
  finally lock:=0;
  end;
 end;

 procedure THash.Remove(const key:String8);
  var
   idx:integer;
  begin
  SpinLock(lock);
  try
   idx:=Find(key);
   if idx>=0 then RemoveKey(idx);
  finally lock:=0;
  end;
  end;


function THash.Get(const key: String8;item:integer=0): variant;
 var
  index:integer;
 begin
  SpinLock(lock);
  try
  // 1. Find key index
  index:=Find(key);
  // 2. Get value
  if (index>=0) and (index<count) then begin
   if multi then begin
    lastIndex:=vlinks[index];
    result:=values[lastIndex];
    lastIndex:=vNext[lastIndex];
    while (item>0) and (lastIndex>=0) do begin
     dec(item);
     result:=values[lastIndex];
     lastIndex:=vNext[lastIndex];
    end;
    if item>0 then result:=Unassigned;
   end else
    result:=values[index];
  end else
   result:=Unassigned;
  finally lock:=0;
  end;
 end;

function THash.GetNext:variant; // get next value associated with the key, or Unassigned if none
 begin
  SpinLock(lock);
  try
  if (lastIndex>=0) and (lastIndex<vCount) then begin
   result:=values[lastIndex];
   lastIndex:=vNext[lastIndex];
  end else
   result:=Unassigned;
  finally lock:=0;
  end;
 end;

function THash.GetAll(const key:String8):VariantArray; // get array of values
 var
  c:integer;
  v:variant;
 begin
  SetLength(result,10);
  c:=0;
  v:=Get(key);
  while not VarIsEmpty(v) do begin
   result[c]:=v;
   v:=getNext;
   inc(c);
   if c>=length(result) then
    SetLength(result,c*2);
  end;
  SetLength(result,c);
 end;

procedure THash.AddValue(const v:variant);
 var
  i:integer;
 begin
  if vCount>=length(values) then begin
   SetLength(values,vCount*2);
   SetLength(vNext,vCount*2);
   for i:=vCount to vCount*2-1 do
    vNext[i]:=-1;
  end;
  values[vCount]:=v;
 end;

procedure THash.RemoveKey(index:integer);
 var
  h,p:integer;
 begin
  // Сперва скорректируем ссылки
  h:=HashValue(keys[index]);
  p:=links[h];
  if p=index then // удаление из начала списка
   links[h]:=next[p]
  else begin // есть предыдущий элемент
   while next[p]<>index do p:=next[p];
   next[p]:=next[index];
  end;
  // теперь нужно перенести последний элемент
  keys[index]:=keys[count-1];
  if multi then vlinks[index]:=vlinks[count-1];
  for p:=0 to count-2 do
   if next[p]=count-1 then begin
    next[p]:=index; break;
   end;

  dec(count);
  if multi then begin
   // удалить все значения
  end else begin
   values[index]:=values[vCount-1];
   dec(vCount);
  end;
 end;

procedure THash.Put(const key:String8; value:variant; replace:boolean=false);
 var
  h,index,size,vIdx:integer;
 begin
  SpinLock(lock);
  try
  // Find key index
  index:=Find(key);
  if index<0 then index:=count;

  // Add new key?
  if index=count then begin
    // Advanced (indexed) mode
    if count>=length(keys) then begin
//     size:=length(keys)*2+32; // 32 -> 96 ->224 -> 480 -> 992 -> ...
     size:=count+1;
     SetLength(keys,size);
     SetLength(next,size);
     if multi then SetLength(vLinks,size);
     if count>length(links)+32 then begin
      hMask:=(hMask shl 2) or $F;
      SetLength(links,length(links)*4);
      BuildHash;
     end;
    end;
    h:=HashValue(key);
    next[count]:=links[h];
    links[h]:=count;
    keys[count]:=key;
    if multi then vLinks[count]:=-1; // пока пусто
    index:=count;
    inc(count);
  end;
  // Add value
  if multi then begin
   // add new value
   AddValue(value);
   if replace then begin
    vNext[vCount]:=-1;
    vLinks[index]:=vCount;
   end else begin
    vIdx:=vLinks[index];
    if vLinks[index]=-1 then vLinks[index]:=vCount; // первый элемент в списке
    if vIdx>=0 then begin
     // Дойти до конца списка и сделать ссылку на новый элемент
     while vNext[vIdx]>=0 do vIdx:=vNext[vIdx];
     vNext[vIdx]:=vCount;
    end;
   end;
   inc(vCount);
  end else begin
   if vCount>=length(values) then SetLength(values,vCount*2);
   values[index]:=value; // fixed index
   vCount:=count;
  end;
  finally lock:=0;
  end;
 end;

procedure THash.BuildHash;
 var
  i,h:integer;
 begin
  for i:=0 to High(links) do links[i]:=-1;
  for i:=0 to count-1 do next[i]:=-1;
  for i:=0 to count-1 do begin
   h:=HashValue(keys[i]);
   next[i]:=links[h];
   links[h]:=i;
  end;
 end;

function THash.AllKeys:AStringArr;
 var
  i:integer;
 begin
  SpinLock(lock);
  try
  SetLength(result,count);
  for i:=0 to count-1 do
   result[i]:=keys[i];
  finally lock:=0;
  end;
 end;

procedure THash.SortKeys;
 procedure QuickSort(a,b:integer);
  var
   lo,hi,v:integer;
   mid,key:string8;
   vr:variant;
  begin
   lo:=a; hi:=b;
   mid:=keys[(a+b) div 2];
   repeat
    while keys[lo]<mid do inc(lo);
    while keys[hi]>mid do dec(hi);
    if lo<=hi then begin
     key:=keys[lo];
     keys[lo]:=keys[hi];
     keys[hi]:=key;
     if multi then begin
      v:=vLinks[lo];
      vLinks[lo]:=vLinks[hi];
      vLinks[hi]:=v;
     end else begin
      vr:=values[lo];
      values[lo]:=values[hi];
      values[hi]:=vr;
     end;
     inc(lo);
     dec(hi);
    end;
   until lo>hi;
   if hi>a then QuickSort(a,hi);
   if lo<b then QuickSort(lo,b);
  end;
 begin
  SpinLock(lock);
  try
  if count<2 then exit;
  // 1. Sort keys
  QuickSort(0,count-1);
  // 2. Restore hashes
  BuildHash;
  finally lock:=0;
  end;
 end;

 // -------------------------------------------
 // TSimpleHash
 // -------------------------------------------
 procedure TSimpleHash.Init(estimatedCount:integer);
  var
   i:integer;
  begin
   SetLength(keys,estimatedCount);
   SetLength(values,estimatedCount);
   SetLength(next,estimatedCount);
   count:=0; fFree:=-1;
   hMask:=$FFFF;
   while (hMask>estimatedCount) and (hMask>$1F) do hMask:=hMask shr 1;
   SetLength(links,hMask+1);
   for i:=0 to hMask do links[i]:=-1;
   lock:=0;
  end;

 procedure TSimpleHash.Clear;
  var
   i:integer;
  begin
   SpinLock(lock);
   try
    count:=0; fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
   finally lock:=0; end;
  end;

 // Integer version
 procedure TSimpleHash.Put(key,value:int64);
  var
   h,i,n:integer;
  begin
   SpinLock(lock);
   try
   // Проверим нет ли уже такого ключа
   h:=HashValue(key);
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    // replace existing value
    values[i]:=value;
    exit;
   end;

   // Need new key
   if fFree>=0 then begin
    // берем элемент из списка свободных
    i:=fFree; fFree:=next[fFree];
   end else begin
    // добавляем новый элемент
    i:=count; inc(count);
    if count>length(keys) then begin
     n:=length(keys)*2+64;
     SetLength(keys,n);
     SetLength(values,n);
     SetLength(next,n);
    end;
   end;
   // Store data
   keys[i]:=key;
   values[i]:=value;
   // Add to hash
   next[i]:=links[h];
   links[h]:=i;
   finally lock:=0; end;
  end;

 function TSimpleHash.Get(key:int64):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=HashValue(key);
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=values[i] else result:=-1;
   finally lock:=0; end;
  end;

 function TSimpleHash.HasValue(key:int64):boolean;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=HashValue(key);
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=true else result:=false;
   finally lock:=0; end;
  end;

 function TSimpleHash.Increment(key:int64;v:int64):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=HashValue(key);
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    values[i]:=values[i]+v;
    result:=values[i];
    exit;
   end;
   finally lock:=0; end;
   // New element
   Put(key,v);
   result:=v;
  end;

 procedure TSimpleHash.Remove(key:int64);
  var
   h,i,prev:integer;
  begin
   SpinLock(lock);
   try
   h:=HashValue(key);
   // Поиск по списку
   i:=links[h]; prev:=-1;
   while (i>=0) and (keys[i]<>key) do begin
    prev:=i;
    i:=next[i];
   end;
   if i>=0 then begin
    // Удаление из односвязного списка
    if prev>=0 then next[prev]:=next[i]
     else links[h]:=next[i];
    keys[i]:=-1; values[i]:=-1;
    next[i]:=fFree;
    fFree:=i;
   end;
   finally lock:=0; end;
  end;

 procedure TSimpleHash.RemoveValue(value:int64);
  var
   h,i,prev:integer;
  begin
   SpinLock(lock);
   try
   /// TODO: not yet implemented
{   for h:=0 to high(links) do begin
    i:=links[h];
   end;}
   finally lock:=0; end;
  end;

function TSimpleHash.HashValue(const k:int64):integer;
  begin
   result:=(k+(k shr 11)+(k shr 23)) and hMask;
  end;

 // -------------------------------------------
 // TSimpleHashS
 // -------------------------------------------

 procedure TSimpleHashS.Init(estimatedCount:integer);
  var
   i:integer;
  begin
   SetLength(keys,estimatedCount);
   SetLength(values,estimatedCount);
   SetLength(next,estimatedCount);
   count:=0; fFree:=-1;
   hMask:=$FFFF;
   while (hMask>estimatedCount) and (hMask>$1F) do hMask:=hMask shr 1;
   SetLength(links,hMask+1);
   for i:=0 to hMask do links[i]:=-1;
   lock:=0;
  end;

 procedure TSimpleHashS.Clear;
  var
   i:integer;
  begin
   SpinLock(lock);
   try
    count:=0; fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
   finally lock:=0; end;
  end;

 // Integer version
 procedure TSimpleHashS.Put(key:string;value:int64);
  var
   h,i,n:integer;
  begin
   SpinLock(lock);
   try
   // Проверим нет ли уже такого ключа
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    // replace existing value
    values[i]:=value;
    exit;
   end;

   // Need new key
   if fFree>=0 then begin
    // берем элемент из списка дырок
    i:=fFree; fFree:=next[fFree];
   end else begin
    // добавляем новый элемент
    i:=count; inc(count);
    if count>length(keys) then begin
     n:=length(keys)*2+64;
     SetLength(keys,n);
     SetLength(values,n);
     SetLength(next,n);
    end;
   end;
   // Store data
   keys[i]:=key;
   values[i]:=value;
   // Add to hash
   next[i]:=links[h];
   links[h]:=i;
   finally lock:=0; end;
  end;

 function TSimpleHashS.Get(key:string):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=values[i] else result:=-1;
   finally lock:=0; end;
  end;

 function TSimpleHashS.Increment(key:string;v:int64):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    values[i]:=values[i]+v;
    result:=values[i];
    exit;
   end;
   finally lock:=0; end;
   // New element
   Put(key,v);
   result:=v;
  end;

 function TSimpleHashS.HasValue(key:string):boolean;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=true else result:=false;
   finally lock:=0; end;
  end;

 procedure TSimpleHashS.Remove(key:string);
  var
   h,i,prev:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   // Поиск по списку
   i:=links[h]; prev:=-1;
   while (i>=0) and (keys[i]<>key) do begin
    prev:=i;
    i:=next[i];
   end;
   if i>=0 then begin
    // Удаление из односвязного списка
    if prev>=0 then next[prev]:=next[i]
     else links[h]:=next[i];
    keys[i]:=''; values[i]:=-1;
    next[i]:=fFree;
    fFree:=i;
   end;
   finally lock:=0; end;
  end;

 // -------------------------------------------
 // TSimpleHashAS
 // -------------------------------------------

 procedure TSimpleHashAS.Init(estimatedCount:integer);
  var
   i:integer;
  begin
   SetLength(keys,estimatedCount);
   SetLength(values,estimatedCount);
   SetLength(next,estimatedCount);
   count:=0; fFree:=-1;
   hMask:=$FFFF;
   while (hMask>estimatedCount) and (hMask>$1F) do hMask:=hMask shr 1;
   SetLength(links,hMask+1);
   for i:=0 to hMask do links[i]:=-1;
   lock:=0;
  end;

 procedure TSimpleHashAS.Clear;
  var
   i:integer;
  begin
   SpinLock(lock);
   try
    count:=0; fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
   finally lock:=0; end;
  end;

 // Integer version
 procedure TSimpleHashAS.Put(key:String8;value:int64);
  var
   h,i,n:integer;
  begin
   SpinLock(lock);
   try
   // Проверим нет ли уже такого ключа
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    // replace existing value
    values[i]:=value;
    exit;
   end;

   // Need new key
   if fFree>=0 then begin
    // берем элемент из списка дырок
    i:=fFree; fFree:=next[fFree];
   end else begin
    // добавляем новый элемент
    i:=count; inc(count);
    if count>length(keys) then begin
     n:=length(keys)*2+64;
     SetLength(keys,n);
     SetLength(values,n);
     SetLength(next,n);
    end;
   end;
   // Store data
   keys[i]:=key;
   values[i]:=value;
   // Add to hash
   next[i]:=links[h];
   links[h]:=i;
   finally lock:=0; end;
  end;

 function TSimpleHashAS.Get(key:String8):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=values[i] else result:=-1;
   finally lock:=0; end;
  end;

 function TSimpleHashAS.Increment(key:String8;v:int64):int64;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then begin
    values[i]:=values[i]+v;
    result:=values[i];
    exit;
   end;
   finally lock:=0; end;
   // New element
   Put(key,v);
   result:=v;
  end;

 function TSimpleHashAS.HasValue(key:String8):boolean;
  var
   h,i:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   i:=links[h];
   while (i>=0) and (keys[i]<>key) do i:=next[i];
   if i>=0 then result:=true else result:=false;
   finally lock:=0; end;
  end;

 procedure TSimpleHashAS.Remove(key:String8);
  var
   h,i,prev:integer;
  begin
   SpinLock(lock);
   try
   h:=StrHash(key) and hMask;
   // Поиск по списку
   i:=links[h]; prev:=-1;
   while (i>=0) and (keys[i]<>key) do begin
    prev:=i;
    i:=next[i];
   end;
   if i>=0 then begin
    // Удаление из односвязного списка
    if prev>=0 then next[prev]:=next[i]
     else links[h]:=next[i];
    keys[i]:=''; values[i]:=-1;
    next[i]:=fFree;
    fFree:=i;
   end;
   finally lock:=0; end;
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
  ASSERT(length(data)>0);
  if length(data)=0 then exit;
  SpinLock(lock);
  try
   if used<>free then begin
    result:=data[used];
    inc(used);
    if used>high(data) then used:=0;
   end else
    result:=nil;
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
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then exit(false);
   data[free]:=item;
   free:=f;
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
  ASSERT(length(data)>0);
  SpinLock(lock);
  try
   f:=free;
   inc(f);
   if f>high(data) then f:=0;
   if f=used then exit(false);
   data[free]:=item;
   free:=f;
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


{ TObjectHash }
procedure TObjectHash.Init(estimatedCount:integer);
 begin
  count:=0;
  lock:=0;
  mask:=GetPow2(estimatedCount*2);
  SetLength(values,mask);
  dec(mask);
  hashMiss:=0;
 end;

procedure TObjectHash.Clear;
 begin
  SpinLock(lock);
  try
   count:=0;
   ZeroMem(values[0],length(values)*sizeof(pointer));
   hashMiss:=0;
  finally
   lock:=0;
  end;
 end;

function TObjectHash.ListKeys:StringArray8;
 begin
  SpinLock(lock);
  try
   result:=InternalListKeys;
  finally
   lock:=0;
  end;
 end;

function TObjectHash.InternalListKeys:StringArray8;
 var
  i,n:integer;
 begin
   SetLength(result,count);
   n:=0;
   for i:=0 to high(values) do
    if IsValid(values[i]) then begin
     result[n]:=values[i].name;
     inc(n);
    end;
 end;

function TObjectHash.InternalListObjects:TNamedObjects;
 var
  i,n:integer;
 begin
  SetLength(result,count);
  n:=0;
  for i:=0 to high(values) do
   if IsValid(values[i]) then begin
    result[n]:=values[i];
    inc(n);
   end;
 end;

function TObjectHash.ListObjects:TNamedObjects;
 begin
  SpinLock(lock);
  try
   result:=InternalListObjects;
  finally
   lock:=0;
  end;
 end;

procedure TObjectHash.Put(value:TNamedObject);
 begin
  if values=nil then Init;
  if (value=nil) or (value.name='') then exit;
  SpinLock(lock);
  try
   InternalPut(value);
   if count*2>mask then Resize;
  finally
   lock:=0;
  end;
 end;

procedure TObjectHash.InternalPut(value:TNamedObject);
 var
  h:cardinal;
 begin
  h:=FastHash(value.name) and mask;
  // find the closest unused cell
  while UIntPtr(values[h])>1 do begin
   if values[h]=value then exit; // already exist
   h:=(h+1) and mask;
  end;
  values[h]:=value;
  inc(count);
 end;

function TObjectHash.Get(key:String8):TNamedObject;
 var
  h:cardinal;
 begin
  h:=FastHash(key);
  SpinLock(lock);
  try
   if values=nil then Init;
   h:=h and mask;
   while values[h]<>nil do begin
    if IsValid(values[h]) and SameText8(key,values[h].name) then exit(values[h]);
    inc(hashMiss);
    h:=(h+1) and mask;
   end;
   result:=nil;
  finally
   lock:=0;
  end;
 end;

procedure TObjectHash.Remove(value:TNamedObject);
 var
  h:cardinal;
 begin
  if (value=nil) or (value.name='') then exit;
  h:=FastHash(value.name);
  SpinLock(lock);
  try
   // 1. Find object
   h:=h and mask;
   while values[h]<>value do begin
    if values[h]=nil then exit; // not found
    h:=(h+1) and mask;
   end;
   // 2. Delete
   values[h]:=DELETED_PTR; // deleted
   dec(count);
  finally
   lock:=0;
  end;
 end;

procedure TObjectHash.Resize;
 var
  list:TNamedObjects;
  i:integer;
 begin
  // No need to lock as it's called safely (internally)
  list:=InternalListObjects;
  count:=0;
  SetLength(values,0);
  mask:=(mask+1)*2-1;
  SetLength(values,mask+1); // cleared
  for i:=0 to high(list) do
   InternalPut(list[i]);
 end;

{ TVarHash }
procedure TVarHash.Init(estimatedCount:integer);
 begin
  count:=0;
  lock:=0;
  mask:=GetPow2(estimatedCount*2);
  SetLength(keys,mask);
  SetLength(values,mask);
  dec(mask);
  initialized:=_INITIALIZED_;
  hashMiss:=0;
 end;

procedure TVarHash.Clear;
 var
  i:integer;
 begin
  SpinLock(lock);
  try
   count:=0;
   for i:=0 to high(keys) do begin
    keys[i]:='';
    values[i]:=Unassigned;
   end;
   hashMiss:=0;
  finally
   lock:=0;
  end;
 end;

function TVarHash.ListKeys:StringArray8;
 begin
  SpinLock(lock);
  try
   result:=InternalListKeys;
  finally
   lock:=0;
  end;
 end;

function TVarHash.InternalListKeys:StringArray8;
 var
  i,n:integer;
 begin
   SetLength(result,count);
   n:=0;
   for i:=0 to high(keys) do
    if values[i]<>unassigned then begin
     result[n]:=keys[i];
     inc(n);
    end;
 end;

function TVarHash.InternalListValues:VariantArray;
 var
  i,n:integer;
 begin
   SetLength(result,count);
   n:=0;
   for i:=0 to high(values) do
    if values[i]<>unassigned then begin
     result[n]:=values[i];
     inc(n);
    end;
 end;

procedure TVarHash.Put(key:string8;value:variant);
 begin
  if initialized='' then Init;
  if (key='') or (value=unassigned) then exit;
  SpinLock(lock);
  try
   InternalPut(key,value);
   if count*2>mask then Resize;
  finally
   lock:=0;
  end;
 end;

procedure TVarHash.InternalPut(key:string8;value:variant);
 var
  h:cardinal;
 begin
  h:=FastHash(key) and mask;
  // find the closest unused cell
  while values[h]<>unassigned do begin
   if SameText8(key,keys[h]) then break; // replace value
   h:=(h+1) and mask;
  end;
  keys[h]:=key;
  values[h]:=value;
  inc(count);
 end;

function TVarHash.Get(key:String8):variant;
 var
  h:cardinal;
 begin
  h:=FastHash(key);
  SpinLock(lock);
  try
   h:=h and mask;
   while keys[h]<>'' do begin
    if SameText8(key,keys[h]) and (values[h]<>unassigned) then exit(values[h]);
    inc(hashMiss);
    h:=(h+1) and mask;
   end;
   result:=unassigned;
  finally
   lock:=0;
  end;
 end;

function TVarHash.HasKey(key:String8):boolean;
 var
  h:cardinal;
 begin
  h:=FastHash(key);
  SpinLock(lock);
  try
   h:=h and mask;
   while keys[h]<>'' do begin
    if SameText8(key,keys[h]) and (values[h]<>unassigned) then exit(true);
    inc(hashMiss);
    h:=(h+1) and mask;
   end;
   result:=false;
  finally
   lock:=0;
  end;
 end;

procedure TVarHash.Remove(key:String8);
 var
  h:cardinal;
 begin
  if (key='') then exit;
  h:=FastHash(key);
  SpinLock(lock);
  try
   // 1. Find item
   h:=h and mask;
   while keys[h]<>key do begin
    if keys[h]='' then exit; // not found
    h:=(h+1) and mask;
   end;
   // 2. Delete
   values[h]:=unassigned; // value cleared, but key remains
   dec(count);
  finally
   lock:=0;
  end;
 end;

procedure TVarHash.Resize;
 var
  allKeys:StringArray8;
  allValues:VariantArray;
  i:integer;
 begin
  // No need to lock as it's called safely (internally)
  allKeys:=InternalListKeys;
  allValues:=InternalListValues;
  count:=0;
  SetLength(keys,0);
  SetLength(values,0);
  mask:=(mask+1)*2-1;
  SetLength(keys,mask+1); // cleared
  SetLength(values,mask+1); // cleared
  for i:=0 to high(allKeys) do
   InternalPut(allKeys[i],allValues[i]);
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
  time:int64;
 begin
  if Get(item) then exit(true);
  time:=MyTickCount+timeMS;
  repeat
   sleep(1);
   if Get(item) then exit(true);
  until MyTickCount>=time;
  result:=false;
 end;

{ TObjectList }

function TObjectList.Add(obj:TObject;uniqueOnly:boolean=false):boolean;
 var
  i:integer;
 begin
  ASSERT(obj<>nil);
  if initialized='' then Init;
  SpinLock(lock);
  try
   if uniqueOnly then
    for i:=0 to count-1 do
     if data[i]=obj then exit(false);
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

end.
