// This unit contains definition of basic types and helper types.
// The structures defined here are not thread-safe

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Types;
interface
uses Types {$IFDEF MSWINDOWS},windows{$ENDIF};
type
  // 8-bit string type (assuming UTF-8 encoding)
  Char8 = UTF8Char;
  String8 = UTF8String;
  PString8 = ^String8;
  // 16-bit string type (can be UTF-16 or UCS-2)
  {$IFDEF UNICODE}
  Char16 = Char;
  String16 = UnicodeString;
  {$ELSE}
  char16 = WideChar;
  String16 = WideString;
  {$ENDIF}
  PString16 = ^String16;

  String32 = UCS4String;

  DWORD = cardinal;
  QWORD = uint64;

  TPoint = Types.TPoint;
  TRect = Types.TRect;

  {$IF not Declared(UIntPtr)}
  UIntPtr=NativeUInt;
  {$ENDIF}
  PtrUInt=UIntPtr;

  // String arrays
  StringArray8 = array of String8;
  StringArray16 = array of String16;
  StringArray = array of string; // depends on UNICODE mode

  {$IF Declared(TBytes)}
  ByteArray = TBytes;
  {$ELSE}
  ByteArray = array of byte;
  {$ENDIF}
  WordArray = array of word;
  IntArray = array of integer;
  UIntArray = array of cardinal;
  SingleArray = array of single;
  FloatArray = array of double;
  ShortStr = string[31];
  PointerArray = array of pointer;
  VariantArray = array of variant;
  TObjectArray = array of TObject;

  TProcedure = procedure;
  TObjProcedure=procedure of object;

  // Spline function: f(x0)=y0, f(x1)=y1, f(x)=?
  TSplineFunc=function(x,x0,x1,y0,y1:single):single;


  // 128bit vector data
  m128=record
   case byte of
   0:(x,y,z,t:single );
   1:(b:array[0..15] of byte );
   2:(w:array[0..7] of word );
   3:(dw:array[0..3] of dword );
   4:(qw:array[0..1] of qword );
   5:(f:array[0..3] of single );
   6:(d:array[0..1] of double );
  end;

  // 16 bit floating point value (half-precision)
  half=record
   value:word;
   class operator Implicit(const f:single):half;
   class operator Implicit(const h:half):single;
  end;

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
   constructor Init(list:StringArray8;valueSeparator:string8='='); overload;
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

  // Critical section wrapper: provides better debug info
  PCriticalSection=^TMyCriticalSection;
  TMyCriticalSection=packed record
   crs:TRTLCriticalSection;
   name:String8;      // имя секции
   caller:UIntPtr;  // точка, из которой была попытка завладеть секцией
   owner:UIntPtr;   // точка, из которой произошел удачный захват секции
   {$IFNDEF MSWINDOWS}
   owningThread:TThreadID;
   {$ENDIF}
   tryingThread:TThreadID;  // нить, пытающаяся захватить секцию
   time:int64;       // время наступления таймаута захвата
   lockCount:integer; // how many times locked (recursion)
   level:integer;     // it's not allowed to enter section with lower level from section with higher level
   prevSection:PCriticalSection;
   procedure Enter; inline; // for compatibility
   procedure Leave; inline; // for compatibility
   function GetSysLockCount:integer; inline;
   function GetSysOwner:TThreadID; inline;
   function GetOwningThread:TThreadID; inline;
  end;

  {$IF Declared(SRWLOCK)}
  TSRWLock=packed record
   lock:SRWLock;
   name:string;
   // Debug facilities
   lockedEx:boolean;
   lastLockedEx:pointer;
   lockRead:integer;
   lastLockedRead:pointer;
   procedure Init(name:string);
   procedure StartRead(caller:pointer=nil);
   procedure FinishRead;
   procedure StartWrite(caller:pointer=nil);
   procedure FinishWrite;
  end;
  {$ENDIF}


implementation
 uses Apus.Common, SysUtils, Generics.Defaults;

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

{ TNameValue }

function TNameValue.GetBool:boolean;
 begin
  result:=ParseBool(value);
 end;

function TNameValue.GetDate:TDateTime;
 begin
  result:=ParseDate(value);
 end;

function TNameValue.GetFloat:double;
 begin
  result:=ParseFloat(value);
 end;

function TNameValue.GetInt:int64;
 begin
  result:=ParseInt(value);
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
  p:=PosFrom(splitter,st);
  if p=0 then begin
   name:=st; value:='';
  end else begin
   name:=copy(st,1,p-1);
   value:=copy(st,p+length(splitter),length(st));
  end;
  name:=Chop(name);
  value:=Chop(value);
 end;

function TNameValue.Join(separator:string8):string8;
 begin
  result:=name+separator+value;
 end;

function TNameValue.Named(st:string8):boolean;
 begin
  result:=SameText8(name,st);
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

{ half }

// Convert float to half
// This is a simplified algorithm which doesn't handle all the specific cases
class operator half.Implicit(const f:single):half;
 var
  bits:cardinal absolute f;
  mant:cardinal;
  exp:integer;
 begin
  exp:=(bits shr 23) and $FF; // source exponent
  exp:=Clamp(exp-127,-15,14); // clamped exponent
  mant:=bits and $7FFFFF;
  mant:=Min2((mant+1) shr 13,1023); // new rounded mantissa
  result.value:=(exp+15) shl 10+mant;
  if integer(bits)<0 then result.value:=result.value or $8000; // sign
 end;

// Convert half to float
// This is a simplified algorithm which doesn't handle all the specific cases
class operator half.Implicit(const h:half):single;
 var
  res:cardinal;
  exp:integer;
 begin
  if h.value=0 then exit(0);
  exp:=(h.value shr 10) and $1F;
  exp:=(exp-15)+127; // new exponent
  res:=(h.value and $3FF) shl 13; // new mantissa
  res:=res+(exp shl 23);
  if h.value and $8000>0 then res:=res or $80000000;
  move(res,result,4);
 end;

procedure TMyCriticalSection.Enter;  // for compatibility
 begin
  EnterCriticalSection(self);
 end;

procedure TMyCriticalSection.Leave; // for compatibility
 begin
  LeaveCriticalSection(self);
 end;

function TMyCriticalSection.GetSysLockCount:integer;
 begin
 end;

function TMyCriticalSection.GetSysOwner:TThreadID;
 begin
 end;

function TMyCriticalSection.GetOwningThread:TThreadID;
 begin
  {$IFDEF MSWINDOWS}
  result:=crs.OwningThread;
  {$ELSE}
  result:=owningThread;
  {$ENDIF}
 end;

{$IF Declared(SRWLOCK)}
{ TSRWLock }
procedure TSRWLock.Init(name: string);
begin
 self.name:=name;
 lockedEx:=false;
 lockRead:=0;
 InitializeSrwLock(lock);
end;

procedure TSRWLock.StartRead(caller:pointer);
begin
 AcquireSRWLockShared(lock);
 InterlockedIncrement(lockRead);
 if caller=nil then
  lastLockedRead:=GetCaller
 else
  lastLockedRead:=caller;
end;

procedure TSRWLock.FinishRead;
begin
 InterlockedDecrement(lockRead);
 ReleaseSRWLockShared(lock);
end;

procedure TSRWLock.StartWrite(caller:pointer);
begin
 AcquireSRWLockExclusive(lock);
 lockedEx:=true;
 if caller=nil then
  lastLockedEx:=GetCaller
 else
  lastLockedEx:=caller;
end;

procedure TSRWLock.FinishWrite;
begin
 lockedEx:=false;
 ReleaseSRWLockExclusive(lock);
end;
{$ENDIF}


{ TNameValueList }

constructor TNameValueList.Init(list:StringArray8;valueSeparator:string8);
var
 i:integer;
begin
 SetLength(items,length(list));
 for i:=0 to high(list) do
  items[i].InitFrom(list[i],valueSeparator);
end;

constructor TNameValueList.Init(st:string8;itemSeparator,valueSeparator:string8);
begin
 Init(SplitA(itemSeparator,st),valueSeparator);
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
var
 n:integer;
begin
 n:=length(items);
 SetLength(items,n+1);
 items[n+1]:=item;
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
