// Fast hash maps - generic key-value dictionaries with case-insensitive string support
//
// SCOPE: High-performance hash tables for fast lookups (configs, caches, symbol tables).
// Used by applications needing O(1) key-value storage. Thread-safe for concurrent access.
//
// ADD HERE: Hash map variants (different key types, collision strategies), hash functions.
// DON'T ADD: Sorted maps (> use trees), specialized caches with eviction policies,
// persistent storage (> Apus.Database).
//
// Contains: THashMap<TValue> (String8 keys, case-insensitive), THashMapInt (integer values),
// THashMapStr (String8 values). Open-addressing with linear probing, thread-safe via SpinLock.
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.HashMaps;
interface
uses Apus.Core, Apus.Classes;

type
  // Generic hash map: String8 key -> T value
  // Open-addressing with linear probing, backward-shift deletion.
  // Case-insensitive keys. Empty keys ('') are not supported.
  // Thread-safe: all public methods use SpinLock.
  // Auto-initializes on first Put if Init was not called.
  THashMap<T> = record
  private
    fLock:integer;
    fMask:cardinal;
    fKeys:array of String8;
    fValues:array of T;
    procedure DoResize;
    function FindSlot(const key:String8):integer; // returns index or -1, no locking
    class function HashKey(const key:String8):cardinal; static;
    class function EqualKeys(const a,b:String8):boolean; static;
  public
    count:integer;
    procedure Init(estimatedCount:integer=16);
    procedure Clear;
    procedure Put(const key:String8; const value:T);
    function Get(const key:String8; out value:T):boolean;
    function GetDef(const key:String8; const defValue:T):T;
    function HasKey(const key:String8):boolean;
    procedure Remove(const key:String8);
  end;

  // Legacy status enum kept for backward compatibility with old hash APIs
  TErrorState=(
    esNoError       =  0,
    esEmpty         =  1,
    esNotFound      =  2,
    esNoMoreItems   =  3,
    esOverflow      =  4);
  THashItem=record
    key:^string;
    value:pointer;
  end;
  TCell=record
    items:array of THashItem;
    count,size:integer;
  end;
  // Hash String->Pointer (1:1), keeps references to external string keys.
  // Legacy API: prefer THashMap<T> for new code.
  TStrHash=class
    Hcount,Hsize:integer;
    cells:array of TCell;
    LastError:TErrorState;
    constructor Create;
    constructor CreateSize(newsize:integer);
    procedure Put(var key:string;data:pointer);
    function Get(key:string):pointer;
    procedure Remove(key:string);
    function FirstKey:string;
    function NextKey:string;
    function GetKeys:Strings;
    function GetValues:PointerArray;
    destructor Destroy; override;
  private
    CurCell,CurItem:integer;
    mask:cardinal;
    function HashValue(str:string):integer;
  end deprecated;
  // Specialized hash for DB-like scenarios: String8 -> variant(s)
  // Supports multi-value mode via Init(allowMultiple=true).
  // Supported specialized API (not deprecated).
  THash=object
    keys:array of String8;
    count:integer;
    values:VariantArray;
    vcount:integer;
    constructor Init(allowMultiple:boolean=false);
    procedure Put(const key:String8;value:variant;replace:boolean=false);
    function Get(const key:String8;item:integer=0):variant;
    function GetAll(const key:String8):VariantArray;
    function GetNext:variant;
    function AllKeys:Strings8;
    procedure SortKeys;
    function HasKey(const key:String8):boolean;
    procedure Remove(const key:String8);
  private
    lock:integer;
    multi:boolean;
    links:array of integer;
    next:array of integer;
    vlinks:array of integer;
    vNext:array of integer;
    lastIndex:integer;
    hMask:integer;
    function HashValue(const v:String8):integer;
    function Find(const key:String8):integer;
    procedure AddValue(const v:variant);
    procedure RemoveKey(index:integer);
    procedure BuildHash;
  end;
  // Specialized compact numeric hash (int64 -> int64), supported API.
  TSimpleHash=object
    keys,values:array of int64;
    count:integer;
    procedure Init(estimatedCount:integer);
    procedure Clear;
    procedure Put(key,value:int64);
    function Get(key:int64):int64;
    function Increment(key:int64;v:int64=1):int64;
    function HasValue(key:int64):boolean;
    procedure Remove(key:int64);
    procedure RemoveValue(value:int64);
  private
    lock:integer;
    links:array of integer;
    next:array of integer;
    hMask:integer;
    fFree:integer;
    function HashValue(const k:int64):integer; inline;
  end;
  // Legacy simple key-value hash families
  TSimpleHashS=object
    keys:Strings;
    values:array of int64;
    count:integer;
    procedure Init(estimatedCount:integer=256);
    procedure Clear;
    procedure Put(key:string;value:int64);
    function Get(key:string):int64;
    function Increment(key:string;v:int64=1):int64;
    function HasValue(key:string):boolean;
    procedure Remove(key:string);
  private
    lock:integer;
    links:array of integer;
    next:array of integer;
    hMask:integer;
    fFree:integer;
  end deprecated;
  TSimpleHashAS=object
    keys:Strings8;
    values:array of int64;
    count:integer;
    procedure Init(estimatedCount:integer=256);
    procedure Clear;
    procedure Put(key:String8;value:int64);
    function Get(key:String8):int64;
    function Increment(key:String8;v:int64=1):int64;
    function HasValue(key:String8):boolean;
    procedure Remove(key:String8);
  private
    lock:integer;
    links:array of integer;
    next:array of integer;
    hMask:integer;
    fFree:integer;
  end deprecated;
  TSimpleHash8=TSimpleHashAS deprecated;
  PObjectHash=^TObjectHash;
  TObjectHash=object
    count:integer;
    procedure Init(estimatedCount:integer=256);
    procedure Clear;
    procedure Put(value:TNamedObject);
    function Get(key:String8):TNamedObject;
    procedure Remove(value:TNamedObject);
    function ListKeys:Strings8;
    function ListObjects:TNamedObjects;
  private
    lock:integer;
    mask:cardinal;
    hashMiss:integer;
    values:array of TNamedObject;
    procedure Resize;
    function InternalListKeys:Strings8;
    function InternalListObjects:TNamedObjects;
    procedure InternalPut(value:TNamedObject);
  end;
  PVarHash=^TVarHash;
  // Transitional type: String8 -> variant.
  // Deprecated: prefer THashMap<T> for typed values or THash for multi-value scenarios.
  TVarHash=object
    count:integer;
    procedure Init(estimatedCount:integer=256);
    procedure Clear;
    procedure Put(key:String8;value:variant);
    function HasKey(key:String8):boolean;
    function Get(key:String8):variant;
    procedure Remove(key:String8);
    function ListKeys:Strings8;
  private
    initialized:string;
    lock:integer;
    mask:cardinal;
    hashMiss:integer;
    keys:array of string8;
    values:array of variant;
    procedure Resize;
    function InternalListKeys:Strings8;
    function InternalListValues:VariantArray;
    procedure InternalPut(key:string8;value:variant);
  end deprecated;


implementation
uses SysUtils, Variants, Apus.Strings;

{ THashMap<T> }

class function THashMap<T>.HashKey(const key:String8):cardinal;
var
  i:integer;
  c:byte;
  v:QWord;
begin
  result:=2166136261; // FNV-1a
  for i:=1 to length(key) do begin
    c:=byte(key[i]);
    if (c>=byte('a')) and (c<=byte('z')) then dec(c,32);
    v:=(QWord(result xor c)*QWord(16777619)) and QWord($FFFFFFFF);
    result:=cardinal(v);
  end;
end;

class function THashMap<T>.EqualKeys(const a,b:String8):boolean;
var
  i:integer;
begin
  if length(a)<>length(b) then exit(false);
  for i:=1 to length(a) do
    if UpCase(a[i])<>UpCase(b[i]) then exit(false);
  result:=true;
end;

function THashMap<T>.FindSlot(const key:String8):integer;
var
  h,cap:cardinal;
begin
  cap:=cardinal(length(fKeys));
  if cap=0 then exit(-1);
  h:=HashKey(key) mod cap;
  while fKeys[h]<>'' do begin
    if EqualKeys(fKeys[h],key) then exit(integer(h));
    h:=(h+1) mod cap;
  end;
  result:=-1;
end;

procedure THashMap<T>.Init(estimatedCount:integer=16);
var
  cap:integer;
begin
  count:=0;
  fLock:=0;
  cap:=16;
  while cap<estimatedCount*2 do cap:=cap*2;
  fMask:=cardinal(cap-1);
  fKeys:=nil; fValues:=nil;
  SetLength(fKeys,cap);
  SetLength(fValues,cap);
end;

procedure THashMap<T>.Clear;
var
  cap:integer;
begin
  if fKeys=nil then exit;
  SpinLock(fLock);
  try
    cap:=length(fKeys);
    fKeys:=nil; fValues:=nil;
    SetLength(fKeys,cap);
    SetLength(fValues,cap);
    count:=0;
  finally
    fLock:=0;
  end;
end;

procedure THashMap<T>.Put(const key:String8; const value:T);
var
  h,cap:cardinal;
begin
  if key='' then exit;
  if fKeys=nil then Init;
  SpinLock(fLock);
  try
    cap:=cardinal(length(fKeys));
    if cap=0 then exit;
    h:=HashKey(key) mod cap;
    while fKeys[h]<>'' do begin
      if EqualKeys(fKeys[h],key) then begin
        fValues[h]:=value;
        exit;
      end;
      h:=(h+1) mod cap;
    end;
    fKeys[h]:=key;
    fValues[h]:=value;
    inc(count);
    if count*2>integer(fMask) then DoResize;
  finally
    fLock:=0;
  end;
end;

function THashMap<T>.Get(const key:String8; out value:T):boolean;
var
  idx:integer;
begin
  if (fKeys=nil) or (key='') then begin
    value:=Default(T);
    exit(false);
  end;
  SpinLock(fLock);
  try
    idx:=FindSlot(key);
    if idx>=0 then begin
      value:=fValues[idx];
      result:=true;
    end else begin
      value:=Default(T);
      result:=false;
    end;
  finally
    fLock:=0;
  end;
end;

function THashMap<T>.GetDef(const key:String8; const defValue:T):T;
var
  idx:integer;
begin
  if (fKeys=nil) or (key='') then exit(defValue);
  SpinLock(fLock);
  try
    idx:=FindSlot(key);
    if idx>=0 then
      result:=fValues[idx]
    else
      result:=defValue;
  finally
    fLock:=0;
  end;
end;

function THashMap<T>.HasKey(const key:String8):boolean;
begin
  if (fKeys=nil) or (key='') then exit(false);
  SpinLock(fLock);
  try
    result:=FindSlot(key)>=0;
  finally
    fLock:=0;
  end;
end;

procedure THashMap<T>.Remove(const key:String8);
var
  i,j,k,cap:cardinal;
begin
  if (fKeys=nil) or (key='') then exit;
  SpinLock(fLock);
  try
    cap:=cardinal(length(fKeys));
    if cap=0 then exit;
    i:=HashKey(key) mod cap;
    while fKeys[i]<>'' do begin
      if EqualKeys(fKeys[i],key) then begin
        dec(count);
        // backward-shift deletion
        j:=i;
        while true do begin
          j:=(j+1) mod cap;
          if fKeys[j]='' then break;
          k:=HashKey(fKeys[j]) mod cap;
          if i<=j then begin
            if (i<k) and (k<=j) then continue;
          end else begin // wrapped around
            if (i<k) or (k<=j) then continue;
          end;
          fKeys[i]:=fKeys[j];
          fValues[i]:=fValues[j];
          i:=j;
        end;
        fKeys[i]:='';
        fValues[i]:=Default(T);
        exit;
      end;
      i:=(i+1) mod cap;
    end;
  finally
    fLock:=0;
  end;
end;

procedure THashMap<T>.DoResize;
var
  oldKeys:array of String8;
  oldValues:array of T;
  i,newCap:integer;
  h:cardinal;
begin
  oldKeys:=fKeys;
  oldValues:=fValues;
  newCap:=(integer(fMask)+1)*2;
  fMask:=cardinal(newCap-1);
  count:=0;
  fKeys:=nil; fValues:=nil;
  SetLength(fKeys,newCap);
  SetLength(fValues,newCap);
  for i:=0 to high(oldKeys) do
    if oldKeys[i]<>'' then begin
      h:=HashKey(oldKeys[i]) mod cardinal(length(fKeys));
      while fKeys[h]<>'' do
        h:=(h+1) mod cardinal(length(fKeys));
      fKeys[h]:=oldKeys[i];
      fValues[h]:=oldValues[i];
      inc(count);
    end;
end;

const
  _INITIALIZED_:string='INITIALIZED';
  DELETED_PTR:pointer=pointer(1);
function IsValid(p:pointer):boolean; inline;
begin
  result:=UIntPtr(p)>=16;
end;
{ TStrHash }
constructor TStrHash.Create;
begin
  CreateSize(256);
end;
constructor TStrHash.CreateSize;
var
  i:integer;
begin
  Hsize:=NextPow2(newsize);
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
function TStrHash.HashValue(str:string):integer;
var
  i,s:cardinal;
  v:QWord;
begin
  s:=0;
  for i:=1 to length(str) do begin
    v:=(QWord(s)*QWord($20844)) and QWord($FFFFFFFF);
    s:=cardinal(v) xor byte(str[i]);
  end;
  result:=s and mask;
end;
procedure TStrHash.Put(var key:string;data:pointer);
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
function TStrHash.Get(key:string):pointer;
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
procedure TStrHash.Remove(key:string);
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
        dec(Hcount);
        exit;
      end;
  end;
  LastError:=esNotFound;
end;
function TStrHash.FirstKey:string;
begin
  CurCell:=0;
  CurItem:=0;
  result:='';
  while (curCell<HSize) and (cells[curCell].count=0) do inc(curCell);
  if curCell>=HSize then begin
    LastError:=esEmpty;
  end else begin
    result:=cells[CurCell].items[0].key^;
    LastError:=esNoError;
    curItem:=1;
  end;
end;
function TStrHash.NextKey:string;
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
function TStrHash.GetKeys:Strings;
var
  i,j,s,cnt:integer;
begin
  s:=hSize;
  cnt:=0;
  SetLength(result,s);
  for i:=0 to Hsize-1 do
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
  for i:=0 to Hsize-1 do
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
{ THash }
constructor THash.Init(allowMultiple:boolean=false);
var
  i:integer;
begin
  lock:=0;
  SpinLock(lock);
  count:=0;
  vCount:=0;
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
function THash.Find(const key:String8):integer;
begin
  result:=links[HashValue(key)];
  while (result>=0) and (keys[result]<>key) do result:=next[result];
end;
function THash.HashValue(const v:String8):integer;
var
  i:integer;
begin
  result:=0;
  for i:=1 to length(v) do
    inc(result,byte(v[i]) shl (i and 3));
  result:=result and hMask;
end;
function THash.HasKey(const key:String8):boolean;
begin
  SpinLock(lock);
  try
    result:=Find(key)>=0;
  finally
    lock:=0;
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
  finally
    lock:=0;
  end;
end;
function THash.Get(const key:String8;item:integer=0):variant;
var
  index:integer;
begin
  SpinLock(lock);
  try
    index:=Find(key);
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
  finally
    lock:=0;
  end;
end;
function THash.GetNext:variant;
begin
  SpinLock(lock);
  try
    if (lastIndex>=0) and (lastIndex<vCount) then begin
      result:=values[lastIndex];
      lastIndex:=vNext[lastIndex];
    end else
      result:=Unassigned;
  finally
    lock:=0;
  end;
end;
function THash.GetAll(const key:String8):VariantArray;
var
  c:integer;
  v:variant;
begin
  SetLength(result,10);
  c:=0;
  v:=Get(key);
  while not VarIsEmpty(v) do begin
    result[c]:=v;
    v:=GetNext;
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
  h:=HashValue(keys[index]);
  p:=links[h];
  if p=index then
    links[h]:=next[p]
  else begin
    while next[p]<>index do p:=next[p];
    next[p]:=next[index];
  end;
  keys[index]:=keys[count-1];
  if multi then vlinks[index]:=vlinks[count-1];
  for p:=0 to count-2 do
    if next[p]=count-1 then begin
      next[p]:=index;
      break;
    end;
  dec(count);
  if multi then begin
  end else begin
    values[index]:=values[vCount-1];
    dec(vCount);
  end;
end;
procedure THash.Put(const key:String8;value:variant;replace:boolean=false);
var
  h,index,size,vIdx:integer;
begin
  SpinLock(lock);
  try
    index:=Find(key);
    if index<0 then index:=count;
    if index=count then begin
      size:=count+1;
      if count>=length(keys) then begin
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
      if multi then vLinks[count]:=-1;
      index:=count;
      inc(count);
    end;
    if multi then begin
      AddValue(value);
      if replace then begin
        vNext[vCount]:=-1;
        vLinks[index]:=vCount;
      end else begin
        vIdx:=vLinks[index];
        if vLinks[index]=-1 then vLinks[index]:=vCount;
        if vIdx>=0 then begin
          while vNext[vIdx]>=0 do vIdx:=vNext[vIdx];
          vNext[vIdx]:=vCount;
        end;
      end;
      inc(vCount);
    end else begin
      if vCount>=length(values) then SetLength(values,vCount*2);
      values[index]:=value;
      vCount:=count;
    end;
  finally
    lock:=0;
  end;
end;
procedure THash.BuildHash;
var
  i,h:integer;
begin
  for i:=0 to high(links) do links[i]:=-1;
  for i:=0 to count-1 do next[i]:=-1;
  for i:=0 to count-1 do begin
    h:=HashValue(keys[i]);
    next[i]:=links[h];
    links[h]:=i;
  end;
end;
function THash.AllKeys:Strings8;
var
  i:integer;
begin
  SpinLock(lock);
  try
    SetLength(result,count);
    for i:=0 to count-1 do
      result[i]:=keys[i];
  finally
    lock:=0;
  end;
end;
procedure THash.SortKeys;
  procedure QuickSort(a,b:integer);
  var
    lo,hi,v:integer;
    mid,key:string8;
    vr:variant;
  begin
    lo:=a;
    hi:=b;
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
    QuickSort(0,count-1);
    BuildHash;
  finally
    lock:=0;
  end;
end;
{ TSimpleHash }
procedure TSimpleHash.Init(estimatedCount:integer);
var
  i:integer;
begin
  SetLength(keys,estimatedCount);
  SetLength(values,estimatedCount);
  SetLength(next,estimatedCount);
  count:=0;
  fFree:=-1;
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
    count:=0;
    fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHash.Put(key,value:int64);
var
  h,i,n:integer;
begin
  SpinLock(lock);
  try
    h:=HashValue(key);
    i:=links[h];
    while (i>=0) and (keys[i]<>key) do i:=next[i];
    if i>=0 then begin
      values[i]:=value;
      exit;
    end;
    if fFree>=0 then begin
      i:=fFree;
      fFree:=next[fFree];
    end else begin
      i:=count;
      inc(count);
      if count>length(keys) then begin
        n:=length(keys)*2+64;
        SetLength(keys,n);
        SetLength(values,n);
        SetLength(next,n);
      end;
    end;
    keys[i]:=key;
    values[i]:=value;
    next[i]:=links[h];
    links[h]:=i;
  finally
    lock:=0;
  end;
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
  finally
    lock:=0;
  end;
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
    result:=i>=0;
  finally
    lock:=0;
  end;
end;
function TSimpleHash.Increment(key:int64;v:int64=1):int64;
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
  finally
    lock:=0;
  end;
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
    i:=links[h];
    prev:=-1;
    while (i>=0) and (keys[i]<>key) do begin
      prev:=i;
      i:=next[i];
    end;
    if i>=0 then begin
      if prev>=0 then next[prev]:=next[i]
      else links[h]:=next[i];
      keys[i]:=-1;
      values[i]:=-1;
      next[i]:=fFree;
      fFree:=i;
    end;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHash.RemoveValue(value:int64);
begin
  SpinLock(lock);
  lock:=0;
end;
function TSimpleHash.HashValue(const k:int64):integer;
begin
  result:=(k+(k shr 11)+(k shr 23)) and hMask;
end;
{ TSimpleHashS }
procedure TSimpleHashS.Init(estimatedCount:integer=256);
var
  i:integer;
begin
  SetLength(keys,estimatedCount);
  SetLength(values,estimatedCount);
  SetLength(next,estimatedCount);
  count:=0;
  fFree:=-1;
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
    count:=0;
    fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHashS.Put(key:string;value:int64);
var
  h,i,n:integer;
begin
  SpinLock(lock);
  try
    h:=StrHash(key) and hMask;
    i:=links[h];
    while (i>=0) and (keys[i]<>key) do i:=next[i];
    if i>=0 then begin
      values[i]:=value;
      exit;
    end;
    if fFree>=0 then begin
      i:=fFree;
      fFree:=next[fFree];
    end else begin
      i:=count;
      inc(count);
      if count>length(keys) then begin
        n:=length(keys)*2+64;
        SetLength(keys,n);
        SetLength(values,n);
        SetLength(next,n);
      end;
    end;
    keys[i]:=key;
    values[i]:=value;
    next[i]:=links[h];
    links[h]:=i;
  finally
    lock:=0;
  end;
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
  finally
    lock:=0;
  end;
end;
function TSimpleHashS.Increment(key:string;v:int64=1):int64;
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
  finally
    lock:=0;
  end;
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
    result:=i>=0;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHashS.Remove(key:string);
var
  h,i,prev:integer;
begin
  SpinLock(lock);
  try
    h:=StrHash(key) and hMask;
    i:=links[h];
    prev:=-1;
    while (i>=0) and (keys[i]<>key) do begin
      prev:=i;
      i:=next[i];
    end;
    if i>=0 then begin
      if prev>=0 then next[prev]:=next[i]
      else links[h]:=next[i];
      keys[i]:='';
      values[i]:=-1;
      next[i]:=fFree;
      fFree:=i;
    end;
  finally
    lock:=0;
  end;
end;
{ TSimpleHashAS }
procedure TSimpleHashAS.Init(estimatedCount:integer=256);
var
  i:integer;
begin
  SetLength(keys,estimatedCount);
  SetLength(values,estimatedCount);
  SetLength(next,estimatedCount);
  count:=0;
  fFree:=-1;
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
    count:=0;
    fFree:=-1;
    for i:=0 to hMask do links[i]:=-1;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHashAS.Put(key:String8;value:int64);
var
  h,i,n:integer;
begin
  SpinLock(lock);
  try
    h:=StrHash(key) and hMask;
    i:=links[h];
    while (i>=0) and (keys[i]<>key) do i:=next[i];
    if i>=0 then begin
      values[i]:=value;
      exit;
    end;
    if fFree>=0 then begin
      i:=fFree;
      fFree:=next[fFree];
    end else begin
      i:=count;
      inc(count);
      if count>length(keys) then begin
        n:=length(keys)*2+64;
        SetLength(keys,n);
        SetLength(values,n);
        SetLength(next,n);
      end;
    end;
    keys[i]:=key;
    values[i]:=value;
    next[i]:=links[h];
    links[h]:=i;
  finally
    lock:=0;
  end;
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
  finally
    lock:=0;
  end;
end;
function TSimpleHashAS.Increment(key:String8;v:int64=1):int64;
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
  finally
    lock:=0;
  end;
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
    result:=i>=0;
  finally
    lock:=0;
  end;
end;
procedure TSimpleHashAS.Remove(key:String8);
var
  h,i,prev:integer;
begin
  SpinLock(lock);
  try
    h:=StrHash(key) and hMask;
    i:=links[h];
    prev:=-1;
    while (i>=0) and (keys[i]<>key) do begin
      prev:=i;
      i:=next[i];
    end;
    if i>=0 then begin
      if prev>=0 then next[prev]:=next[i]
      else links[h]:=next[i];
      keys[i]:='';
      values[i]:=-1;
      next[i]:=fFree;
      fFree:=i;
    end;
  finally
    lock:=0;
  end;
end;
{ TObjectHash }
procedure TObjectHash.Init(estimatedCount:integer=256);
begin
  count:=0;
  lock:=0;
  mask:=NextPow2(estimatedCount*2);
  SetLength(values,mask);
  dec(mask);
  hashMiss:=0;
end;
procedure TObjectHash.Clear;
begin
  SpinLock(lock);
  try
    count:=0;
    Mem.Clear(values[0],length(values)*sizeof(pointer));
    hashMiss:=0;
  finally
    lock:=0;
  end;
end;
function TObjectHash.ListKeys:Strings8;
begin
  SpinLock(lock);
  try
    result:=InternalListKeys;
  finally
    lock:=0;
  end;
end;
function TObjectHash.InternalListKeys:Strings8;
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
  while UIntPtr(values[h])>1 do begin
    if values[h]=value then exit;
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
      if IsValid(values[h]) and key.Same(values[h].name) then exit(values[h]);
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
    h:=h and mask;
    while values[h]<>value do begin
      if values[h]=nil then exit;
      h:=(h+1) and mask;
    end;
    values[h]:=DELETED_PTR;
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
  list:=InternalListObjects;
  count:=0;
  SetLength(values,0);
  mask:=(mask+1)*2-1;
  SetLength(values,mask+1);
  for i:=0 to high(list) do
    InternalPut(list[i]);
end;
{ TVarHash }
procedure TVarHash.Init(estimatedCount:integer=256);
begin
  count:=0;
  lock:=0;
  mask:=NextPow2(estimatedCount*2);
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
function TVarHash.ListKeys:Strings8;
begin
  SpinLock(lock);
  try
    result:=InternalListKeys;
  finally
    lock:=0;
  end;
end;
function TVarHash.InternalListKeys:Strings8;
var
  i,n:integer;
begin
  SetLength(result,count);
  n:=0;
  for i:=0 to high(keys) do
    if values[i]<>Unassigned then begin
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
    if values[i]<>Unassigned then begin
      result[n]:=values[i];
      inc(n);
    end;
end;
procedure TVarHash.Put(key:String8;value:variant);
begin
  if initialized='' then Init;
  if (key='') or (value=Unassigned) then exit;
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
  while values[h]<>Unassigned do begin
    if key.Same(keys[h]) then break;
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
      if key.Same(keys[h]) and (values[h]<>Unassigned) then exit(values[h]);
      inc(hashMiss);
      h:=(h+1) and mask;
    end;
    result:=Unassigned;
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
      if key.Same(keys[h]) and (values[h]<>Unassigned) then exit(true);
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
  if key='' then exit;
  h:=FastHash(key);
  SpinLock(lock);
  try
    h:=h and mask;
    while keys[h]<>key do begin
      if keys[h]='' then exit;
      h:=(h+1) and mask;
    end;
    values[h]:=Unassigned;
    dec(count);
  finally
    lock:=0;
  end;
end;
procedure TVarHash.Resize;
var
  allKeys:Strings8;
  allValues:VariantArray;
  i:integer;
begin
  allKeys:=InternalListKeys;
  allValues:=InternalListValues;
  count:=0;
  SetLength(keys,0);
  SetLength(values,0);
  mask:=(mask+1)*2-1;
  SetLength(keys,mask+1);
  SetLength(values,mask+1);
  for i:=0 to high(allKeys) do
    InternalPut(allKeys[i],allValues[i]);
end;
end.

