// Generic hash map implementations (open-addressing with linear probing)
// Thread-safe via SpinLock. Case-insensitive String8 keys.
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.HashMaps;
interface
{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}
uses Apus.Core;

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

implementation

{ THashMap<T> }

class function THashMap<T>.HashKey(const key:String8):cardinal;
var
  i:integer;
  c:byte;
begin
  result:=2166136261; // FNV-1a
  for i:=1 to length(key) do begin
    c:=byte(key[i]);
    if (c>=byte('a')) and (c<=byte('z')) then dec(c,32);
    result:=(result xor c)*cardinal(16777619);
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
  h:cardinal;
begin
  h:=HashKey(key) and fMask;
  while fKeys[h]<>'' do begin
    if EqualKeys(fKeys[h],key) then exit(integer(h));
    h:=(h+1) and fMask;
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
  h:cardinal;
begin
  if key='' then exit;
  if fKeys=nil then Init;
  SpinLock(fLock);
  try
    h:=HashKey(key) and fMask;
    while fKeys[h]<>'' do begin
      if EqualKeys(fKeys[h],key) then begin
        fValues[h]:=value;
        exit;
      end;
      h:=(h+1) and fMask;
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
  i,j,k:cardinal;
begin
  if (fKeys=nil) or (key='') then exit;
  SpinLock(fLock);
  try
    i:=HashKey(key) and fMask;
    while fKeys[i]<>'' do begin
      if EqualKeys(fKeys[i],key) then begin
        dec(count);
        // backward-shift deletion
        j:=i;
        while true do begin
          j:=(j+1) and fMask;
          if fKeys[j]='' then break;
          k:=HashKey(fKeys[j]) and fMask;
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
      i:=(i+1) and fMask;
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
      h:=HashKey(oldKeys[i]) and fMask;
      while fKeys[h]<>'' do
        h:=(h+1) and fMask;
      fKeys[h]:=oldKeys[i];
      fValues[h]:=oldValues[i];
      inc(count);
    end;
end;

end.
