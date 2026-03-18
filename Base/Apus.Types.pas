// This unit contains some useful types (except simple types and classes) and helpers
// The structures defined here are not thread-safe

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Types;
interface
uses Apus.Core;

type
  TIntRange=record
    min,max:integer;
    procedure Init(min,max:integer);
    function Width:integer; // max-min
    function Rand:integer;
  end;

  TFloatRange=record
    min,max:single;
    procedure Init(min,max:single);
    function Width:single; // max-min
    function Rand:single;
  end;

  // Helper type for custom arrays
  TArray<T>=record
    items:array of T;
    procedure Add(element:T);
    procedure Insert(element:T;index:integer);
    procedure Remove(element:T;keepOrder:boolean=true);
    function Find(element:T):integer;
    function Contains(element:T):boolean;
    function Last:T;
    function IsEmpty:boolean;
    function Count:integer;
    function Pop:T; // return the last element and remove it
  end;

  // "name = value" string pair
  TNameValue=record
    name,value:string8;
    procedure Init(name,value:string8);
    procedure InitFrom(st:string8;splitter:string8='='); // split and trim
    function Named(st:string8):boolean;
    function GetInt:int64;
    function GetFloat:double;
    function GetDate:TDateTime;
    function GetBool:boolean; // true if value is "y", "yes", "true", "on", "1"; false if "n", "no", "false", "off", "0"
    function Join(separator:string8='='):string8; // convert back to "name=value"
  end;

  // List of "name=value" pairs
  // If you have many items, consider using hash instead
  TNameValueList=record
    items:array of TNameValue;
    // Init from a string 'name1=value1;..;nameN=valueN'
    constructor Init(st:string8;itemSeparator:string8=';';valueSeparator:string8='='); overload;
    // Init from array of strings 'name=value'
    constructor Init(list:Strings8;valueSeparator:string8='='); overload;
    function Save(itemSeparator:string8=';';valueSeparator:string8='='):string8;
    function Count:integer;
    function HasName(name:string8):boolean; // check if there is an item with given name
    function Find(name:string8):integer;
    procedure Add(item:TNameValue); overload;
    procedure Add(list:TNameValueList); overload;
  private
    function GetItem(name:String8):string8;
    procedure SetItem(name:string8;value:string8);
  public
    property Item[name:string8]:string8 read GetItem write SetItem;
  end;

  // Helper object represents in-memory binary buffer, doesn't own data
  // Useful to pass arbitrary data instead of pointer:size pair
  TBuffer=record
    data:PByte;   // pointer to the whole buffer data
    readPos:PByte; // current reading position
    size:integer; // total data size
    constructor Create(sour:pointer;sizeInBytes:integer);
    constructor CreateFrom(sour:pointer;sizeInBytes:integer); overload;
    constructor CreateFrom(var sour;sizeInBytes:integer); overload;
    constructor CreateFrom(bytes:ByteArray); overload;
    constructor CreateFrom(st:String8); overload;
    function Slice(length:integer;advance:boolean=false):TBuffer; overload;
    function Slice(from,length:integer):TBuffer; overload;
    function ReadByte:byte;
    function ReadBool:boolean;
    function ReadWord:word;
    function ReadInt:integer;
    function ReadUInt:cardinal;
    function ReadFloat:single;
    function ReadDouble:double;
    function ReadString:String8;
    function ReadFlex:cardinal; // read flexible (multibyte) unsigned integer
    procedure Skip(numBytes:integer); // advance read pos by
    procedure Seek(pos:integer);
    procedure Read(var dest;numBytes:integer);
    function BytesLeft:integer; inline;
    function CurrentPos:integer; inline;
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

{  // In-memory binary buffer used to read bit fields
  TBitBuffer=record
    data:PByte;
    size:integer;
    constructor Create(sour:pointer;sizeInBytes:integer);
    constructor CreateFrom(buffer:TBuffer);
    function Read(numBits:integer):cardinal;
  private
    buf:cardinal;
  end;}

  TWriteBuffer=record
    position:integer;
    constructor Init(expectedSize:integer);
    procedure Reset(newSize:integer);
    procedure Write(var item;numBytes:integer); overload;
    procedure Write(var buf:TBuffer); overload;
    procedure WriteByte(b:byte); inline;
    procedure WriteBool(b:boolean); inline;
    procedure WriteWord(w:word); inline;
    procedure WriteInt(i:integer); inline;
    procedure WriteUInt(c:cardinal); inline;
    procedure WriteFloat(f:single); inline;
    procedure WriteDouble(d:double); inline;
    procedure WriteFlex(c:cardinal);
    procedure WriteStr(s:String8);
    procedure Seek(pos:integer);
    procedure Skip(bytes:integer);
    function AsBuffer:TBuffer;
  private
    data:ByteArray;
  end;

  // Sort array of records by an integer/float/double field at given byte offset
  procedure SortRecordsByInt(var items;itemSize,itemCount,offset:integer;asc:boolean=true);
  procedure SortRecordsByFloat(var items;itemSize,itemCount,offset:integer;asc:boolean=true);
  procedure SortRecordsByDouble(var items;itemSize,itemCount,offset:integer;asc:boolean=true);

implementation
 uses SysUtils, Generics.Defaults, Apus.Conv, Apus.Strings, Apus.Utils;

{ TBuffer }

constructor TBuffer.Create(sour:pointer;sizeInBytes:integer);
begin
  data:=sour;
  size:=sizeInBytes;
  readPos:=sour;
end;

constructor TBuffer.CreateFrom(sour:pointer;sizeInBytes:integer);
begin
  Create(sour,sizeInBytes);
end;

constructor TBuffer.CreateFrom(var sour;sizeInBytes:integer);
begin
  Create(@sour,sizeInBytes);
end;

constructor TBuffer.CreateFrom(bytes:ByteArray);
begin
  Create(@bytes[0],length(bytes));
end;

constructor TBuffer.CreateFrom(st:String8);
begin
  Create(@st[low(st)],length(st));
end;

function TBuffer.CurrentPos:integer;
begin
  result:=UIntPtr(readPos)-UIntPtr(data);
end;

function TBuffer.BytesLeft:integer;
begin
  result:=(UIntPtr(data)+size-UIntPtr(readPos));
end;

procedure TBuffer.Read(var dest;numBytes:integer);
begin
  ASSERT(BytesLeft>=numBytes);
  move(readPos^,dest,numBytes);
  inc(readPos,numBytes);
end;

function TBuffer.ReadBool:boolean;
begin
  result:=ReadByte<>0;
end;

function TBuffer.ReadByte:byte;
begin
  ASSERT(BytesLeft>0);
  result:=readPos^;
  inc(readPos);
end;

function TBuffer.ReadDouble:double;
begin
  ASSERT(BytesLeft>=8);
  result:=PDouble(readPos)^;
  inc(readPos,8);
end;

function TBuffer.ReadFlex:cardinal;
var
  b,shift:byte;
begin
  result:=0; shift:=0;
  while BytesLeft>0 do begin
    b:=readPos^;
    inc(readPos);
    inc(result,(b and $7F) shl shift);
    if b and $80=0 then break;
    inc(shift,7);
  end;
end;

function TBuffer.ReadFloat:single;
begin
  ASSERT(BytesLeft>=4);
  result:=PSingle(readPos)^;
  inc(readPos,4);
end;

function TBuffer.ReadInt:integer;
begin
  ASSERT(BytesLeft>=4);
  result:=PInteger(readPos)^;
  inc(readPos,4);
end;

function TBuffer.ReadString:String8;
var
  size:integer;
begin
  size:=ReadFlex;
  SetLength(result,size);
  if size>0 then
    Read(result[1],size);
end;

function TBuffer.ReadUInt:cardinal;
begin
  ASSERT(BytesLeft>=4);
  result:=PCardinal(readPos)^;
  inc(readPos,4);
end;

function TBuffer.ReadWord:word;
begin
  ASSERT(BytesLeft>=2);
  result:=PWord(readPos)^;
  inc(readPos,2);
end;

procedure TBuffer.Seek(pos:integer);
begin
  ASSERT((pos>=0) and (pos<size));
  readPos:=PByte(UIntPtr(data)+pos);
end;

procedure TBuffer.Skip(numBytes:integer);
begin
  ASSERT(BytesLeft>=numBytes);
  inc(readPos,numBytes);
  ASSERT(UIntPtr(readPos)>=UIntPtr(data));
end;

function TBuffer.Slice(from,length:integer):TBuffer;
begin
  ASSERT((from>=0) and (length>=0));
  ASSERT(from+length<=size);
  result.Create(pointer(UIntPtr(data)+from),length);
end;

function TBuffer.Slice(length:integer;advance:boolean=false):TBuffer;
begin
  result:=Slice(CurrentPos,length);
  if advance then Skip(length);
end;

// -------------------------------------------------------
// TBitStream
// -------------------------------------------------------

procedure TBitStream.Init(estimatedSize:integer);
begin
  size:=0; readPos:=0;
  SetLength(data,(estimatedSize+31) div 32);
  capacity:=length(data)*32;
  if length(data)>0 then
    FillChar(data[0],length(data)*SizeOf(cardinal),0);
end;

procedure TBitStream.SetBit(index:integer;value:integer);
var
  i:integer;
  mask:cardinal;
begin
  i:=index shr 5;
  mask:=cardinal(1) shl (index and 31);
  if value=0 then
    data[i]:=data[i] and not mask
  else
    data[i]:=data[i] or mask
end;

function TBitStream.GetBit(index:integer):integer;
begin
  result:=(data[index shr 5] shr (index and 31)) and 1;
end;

procedure TBitStream.Allocate(count:integer);
begin
  if size+count>capacity then begin
    capacity:=round((capacity+1024)*1.5);
    SetLength(data,(capacity+31) div 32);
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
  // simple, non-effective version
  for i:=0 to count-1 do begin
    SetBit(size,b and 1);
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
  // simple, non-effective version
  //pb:=@buf;
  pb:=@buf;
  FillChar(pb^,(count+7) div 8,0);
  for i:=0 to count-1 do begin
    if GetBit(readPos)>0 then
      pb[i shr 3]:=pb[i shr 3] or (1 shl (i and 7));
    inc(readPos);
  end;
end;

function TBitStream.SizeInBytes:integer; // return size of stream in bytes
begin
  result:=(size+7) div 8;
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

{ TNameValue }

function TNameValue.GetBool:boolean;
begin
  result:=Conv.ToBool(value);
end;

function TNameValue.GetDate:TDateTime;
begin
  result:=ParseDate(value);
end;

function TNameValue.GetFloat:double;
begin
  result:=Conv.ToFloat(value);
end;

function TNameValue.GetInt:int64;
begin
  result:=Conv.ToInt(value);
end;

procedure TNameValue.Init(name,value:string8);
begin
  self.name:=name;
  self.value:=value;
end;

procedure TNameValue.InitFrom(st,splitter:string8);
var
  p:integer;
begin
  p:=st.IndexOf(splitter);
  if p=0 then begin
    name:=st; value:='';
  end else begin
    name:=copy(st,1,p-1);
    value:=copy(st,p+length(splitter),length(st));
  end;
  name:=name.Trim;
  value:=value.Trim;
end;

function TNameValue.Join(separator:string8):string8;
begin
  result:=name+separator+value;
end;

function TNameValue.Named(st:string8):boolean;
begin
  result:=name.Same(st);
end;

{ TIntRange }

procedure TIntRange.Init(min,max:integer);
begin
  self.min:=min;
  self.max:=max;
end;

function TIntRange.Rand:integer;
begin
  result:=min+Random(max-min+1);
end;

function TIntRange.Width:integer;
begin
  result:=max-min;
end;

{ TFloatRange }

procedure TFloatRange.Init(min,max:single);
begin
  self.min:=min;
  self.max:=max;
end;

function TFloatRange.Rand:single;
begin
  result:=min+random*(max-min);
end;

function TFloatRange.Width:single;
begin
  result:=max-min;
end;

{ TWriteBuffer }

procedure TWriteBuffer.Reset(newSize:integer);
begin
  position:=0;
  SetLength(data,newSize);
end;

procedure TWriteBuffer.Seek(pos:integer);
begin
  position:=pos;
end;

procedure TWriteBuffer.Skip(bytes:integer);
begin
  inc(position,bytes);
end;

procedure TWriteBuffer.Write(var item;numBytes:integer);
begin
  while length(data)<position+numBytes do
    SetLength(data,(length(data)+1024)*2);
  move(item,data[position],numBytes);
  inc(position,numBytes);
end;

procedure TWriteBuffer.Write(var buf:TBuffer);
begin
  Write(buf.data^,buf.size);
end;

procedure TWriteBuffer.WriteBool(b:boolean);
begin
  write(b,1);
end;

procedure TWriteBuffer.WriteByte(b:byte);
begin
  Write(b,1);
end;

procedure TWriteBuffer.WriteDouble(d:double);
begin
  Write(d,8);
end;

procedure TWriteBuffer.WriteFloat(f:single);
begin
  Write(f,4);
end;

procedure TWriteBuffer.WriteInt(i:integer);
begin
  Write(i,4);
end;

procedure TWriteBuffer.WriteUInt(c:cardinal);
begin
  Write(c,4);
end;

procedure TWriteBuffer.WriteWord(w:word);
begin
  Write(w,2)
end;

procedure TWriteBuffer.WriteFlex(c:cardinal);
var
  b:byte;
begin
  repeat
    b:=c and $7F;
    c:=c shr 7;
    if c<>0 then b:=b or $80;
    Write(b,1);
  until c=0;
end;

procedure TWriteBuffer.WriteStr(s:String8);
var
  l:integer;
begin
  l:=length(s);
  WriteFlex(l);
  if l>0 then
    Write(s[1],l);
end;

function TWriteBuffer.AsBuffer:TBuffer;
begin
  result.Create(@data[0],position);
end;

constructor TWriteBuffer.Init(expectedSize:integer);
begin
  position:=0;
  if expectedSize<=0 then expectedSize:=16384;
  SetLength(data,expectedSize);
end;

// TMyCriticalSection and TSRWLock implementation moved to Apus.Threading in engine5


{ TNameValueList }

constructor TNameValueList.Init(list:Strings8;valueSeparator:string8);
var
  i:integer;
begin
  SetLength(items,length(list));
  for i:=0 to high(list) do
    items[i].InitFrom(list[i],valueSeparator);
end;

constructor TNameValueList.Init(st:string8;itemSeparator,valueSeparator:string8);
begin
  self:=TNameValueList.Init(st.Split(itemSeparator[1]),valueSeparator);
end;

procedure TNameValueList.Add(list:TNameValueList);
var
  i,n:integer;
begin
  n:=length(items);
  SetLength(items,n+length(list.items));
  for i:=0 to high(list.items) do
    items[n+i]:=list.items[i];
end;

procedure TNameValueList.Add(item:TNameValue);
begin
  items:=items+[item];
end;

function TNameValueList.Count: integer;
begin
  result:=length(items);
end;

function TNameValueList.Find(name:string8):integer;
var
  i:integer;
begin
  for i:=0 to high(items) do
    if items[i].Named(name) then exit(i);
  result:=-1;
end;

function TNameValueList.HasName(name:string8):boolean;
begin
  result:=Find(name)>=0;
end;

function TNameValueList.GetItem(name:String8):string8;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(items) do
    if items[i].named(name) then exit(items[i].value);
end;

function TNameValueList.Save(itemSeparator,valueSeparator:string8):string8;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(items) do begin
    if i>0 then result:=result+itemSeparator;
    result:=result+items[i].name;
    if items[i].value<>'' then result:=result+valueSeparator+items[i].value;
  end;
end;

procedure TNameValueList.SetItem(name,value:string8);
var
  i:integer;
begin
  for i:=0 to high(items) do
    if items[i].named(name) then begin
      items[i].value:=value;
      exit;
    end;
  i:=length(items);
  SetLength(items,i+1);
  items[i].Init(name,value);
end;

{ TList<T> }

procedure TArray<T>.Add(element:T);
var
  n:integer;
begin
  n:=length(items);
  SetLength(items,n+1);
  items[n]:=element;
end;

function TArray<T>.Contains(element:T):boolean;
begin
  result:=Find(element)>=0;
end;

function TArray<T>.Count:integer;
begin
  result:=length(items);
end;

function TArray<T>.Find(element:T):integer;
var
  i:integer;
  comparer:IEqualityComparer<T>;
begin
  comparer:=TEqualityComparer<T>.Default;
  for i:=0 to high(items) do
    if comparer.Equals(items[i],element) then exit(i);
  result:=-1;
end;

procedure TArray<T>.Insert(element:T;index:integer);
var
  i,n:integer;
begin
  n:=length(items);
  if index>n then index:=n;
  SetLength(items,n+1);
  for i:=n-1 downto index do
    items[i+1]:=items[i];
  items[index]:=element;
end;

function TArray<T>.IsEmpty:boolean;
begin
  result:=Length(items)=0;
end;

function TArray<T>.Last:T;
begin
  if high(items)>=0 then exit(items[high(items)]);
  result:=Default(T);
end;

function TArray<T>.Pop:T;
var
  n:integer;
begin
  result:=Last;
  n:=length(items);
  if n>0 then SetLength(items,n-1);
end;

procedure TArray<T>.Remove(element:T;keepOrder:boolean=true);
var
  i,n:integer;
begin
  i:=Find(element);
  if i<0 then exit; // not found
  n:=high(items);
  if keepOrder then begin
    while i<n do begin
      items[i]:=items[i+1];
      inc(i);
    end
  end else
    items[i]:=items[n];
  SetLength(items,n);
end;

end.
