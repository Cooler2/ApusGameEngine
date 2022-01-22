unit Apus.Types;
interface

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

  TProcedure = procedure;

  // "name = value" string pair
  TNameValue=record
   name,value:string;
   procedure Init(st:string;splitter:string='='); // split and trim
   function Named(st:string):boolean;
   function GetInt:integer;
   function GetFloat:double;
   function GetDate:TDateTime;
   function Join(separator:string='='):string; // convert back to "name=value"
  end;

  // Helper object represents in-memory binary buffer, doesn't own data
  // Useful to pass arbitrary data instead of pointer:size pair
  TBuffer=record
   data:PByte;
   readPos:PByte;
   size:integer;
   constructor Create(sour:pointer;sizeInBytes:integer);
   constructor CreateFrom(sour:pointer;sizeInBytes:integer); overload;
   constructor CreateFrom(var sour;sizeInBytes:integer); overload;
   constructor CreateFrom(bytes:ByteArray); overload;
   constructor CreateFrom(st:String8); overload;
   function Slice(length:integer;advance:boolean=false):TBuffer; overload;
   function Slice(from,length:integer):TBuffer; overload;
   function ReadByte:byte;
   function ReadWord:word;
   function ReadInt:integer;
   function ReadUInt:cardinal;
   function ReadFloat:single;
   function ReadDouble:double;
   procedure Skip(numBytes:integer); // advance read pos by
   procedure Seek(pos:integer);
   procedure Read(var dest;numBytes:integer);
   function BytesLeft:integer; inline;
   function CurrentPos:integer; inline;
  end;

implementation
 uses Apus.MyServis, SysUtils;

{ TBuffer }

constructor TBuffer.Create(sour:pointer; sizeInBytes:integer);
 begin
  data:=sour;
  size:=sizeInBytes;
  readPos:=sour;
 end;

constructor TBuffer.CreateFrom(sour:pointer; sizeInBytes:integer);
 begin
  Create(sour,sizeInBytes);
 end;

constructor TBuffer.CreateFrom(var sour; sizeInBytes:integer);
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
  result:=(UIntPtr(readPos)+size-UIntPtr(data));
 end;

procedure TBuffer.Read(var dest; numBytes:integer);
 begin
  ASSERT(BytesLeft>=numBytes);
  move(readPos^,dest,numBytes);
  inc(readPos,numBytes);
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

function TNameValue.GetDate: TDateTime;
 begin
  result:=ParseDate(value);
 end;

function TNameValue.GetFloat: double;
 begin
  result:=ParseFloat(value);
 end;

function TNameValue.GetInt: integer;
 begin
  result:=ParseInt(value);
 end;

procedure TNameValue.Init(st,splitter:string);
 var
  p:integer;
 begin
  p:=pos(splitter,st);
  if p=0 then begin
   name:=st; value:='';
  end else begin
   name:=copy(st,1,p-1);
   value:=copy(st,p+length(splitter),length(st));
  end;
  name:=name.Trim;
  value:=value.Trim;
 end;

function TNameValue.Join(separator: string): string;
 begin
  result:=name+separator+value;
 end;

function TNameValue.Named(st: string): boolean;
 begin
  result:=SameText(name,st);
 end;

end.
