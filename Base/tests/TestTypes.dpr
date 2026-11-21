{$APPTYPE CONSOLE}
{$R+}
program TestTypes;
uses
  SysUtils,
  DateUtils,
  Apus.Core,
  Apus.Conv,
  Apus.Types;

{$INCLUDE Test.inc}

function AlmostEqual(a,b:double;eps:double=1e-6):boolean;
begin
  result:=Abs(a-b)<=eps;
end;

procedure TestIntRange;
var
  r:TIntRange;
  i,v:integer;
  randInBounds:boolean;
  badIndex,badValue:integer;
begin
  StartTest('Types.IntRange');
  r.Init(-3,7);
  Check(r.min=-3,'Types.IntRange min set');
  Check(r.max=7,'Types.IntRange max set');
  Check(r.Width=10,'Types.IntRange width');
  randInBounds:=true;
  badIndex:=-1;
  badValue:=0;
  for i:=1 to 500 do begin
    v:=r.Rand;
    if (v<-3) or (v>7) then begin
      randInBounds:=false;
      badIndex:=i;
      badValue:=v;
      break;
    end;
  end;
  Check(randInBounds,
    'Types.IntRange rand bounds [1..500], first bad sample #'+IntToStr(badIndex)+' value='+IntToStr(badValue));
  EndTest;
end;

procedure TestFloatRange;
var
  r:TFloatRange;
  i:integer;
  v:single;
  randInBounds:boolean;
  badIndex:integer;
  badValue:single;
begin
  StartTest('Types.FloatRange');
  r.Init(single(-1.5),single(2.25));
  Check(AlmostEqual(r.min,-1.5),'Types.FloatRange min set');
  Check(AlmostEqual(r.max,2.25),'Types.FloatRange max set');
  Check(AlmostEqual(r.Width,3.75),'Types.FloatRange width');
  randInBounds:=true;
  badIndex:=-1;
  badValue:=0;
  for i:=1 to 500 do begin
    v:=r.Rand;
    if (v<-1.5) or (v>2.25) then begin
      randInBounds:=false;
      badIndex:=i;
      badValue:=v;
      break;
    end;
  end;
  Check(randInBounds,
    'Types.FloatRange rand bounds [1..500], first bad sample #'+IntToStr(badIndex)+' value='+FloatToStr(badValue));
  EndTest;
end;

procedure TestArrayHelper;
var
  a:TArray<integer>;
begin
  StartTest('Types.TArray');
  Check(a.IsEmpty,'initial empty');
  Check(a.Count=0,'initial count=0');
  Check(a.Find(42)=-1,'find missing');
  Check(not a.Contains(42),'contains missing');
  Check(a.Last=0,'last default');
  Check(a.Pop=0,'pop empty default');

  a.Add(10);
  a.Add(20);
  a.Insert(5,0);
  a.Insert(15,2);
  a.Insert(99,100); // append on out-of-range index
  Check(a.Count=5,'count after add/insert');
  Check((a.items[0]=5) and (a.items[1]=10) and (a.items[2]=15) and (a.items[3]=20) and (a.items[4]=99),'order after insert');
  Check(a.Find(15)=2,'find existing');
  Check(a.Contains(20),'contains existing');
  Check(a.Last=99,'last');

  Check(a.Pop=99,'pop value');
  Check(a.Count=4,'count after pop');

  a.Remove(10,true); // keep order
  Check(a.Count=3,'remove keep order count');
  Check((a.items[0]=5) and (a.items[1]=15) and (a.items[2]=20),'remove keep order content');

  a.Remove(15,false); // allow swap remove
  Check(a.Count=2,'remove no order count');
  Check(not a.Contains(15),'removed value absent');

  a.Remove(777,true); // missing
  Check(a.Count=2,'remove missing no-op');
  EndTest;
end;

procedure TestNameValue;
var
  nv:TNameValue;
  dt:TDateTime;
begin
  StartTest('Types.NameValue');
  nv.Init('mode','on');
  Check(nv.Named('mode'),'named exact');
  Check(nv.Named('MODE'),'named case-insensitive');
  Check(nv.Join='mode=on','join default');
  Check(nv.Join(':')='mode:on','join custom');
  nv.value:='true';
  Check(nv.GetBool,'bool true');
  nv.value:='yes';
  Check(nv.GetBool,'bool yes');
  nv.value:='y';
  Check(nv.GetBool,'bool y');
  nv.value:='YES';
  Check(nv.GetBool,'bool YES');
  nv.value:='1';
  Check(nv.GetBool,'bool 1');
  nv.value:='false';
  Check(not nv.GetBool,'bool false');
  nv.value:='no';
  Check(not nv.GetBool,'bool no');
  nv.value:='0';
  Check(not nv.GetBool,'bool 0');
  nv.value:='';
  Check(not nv.GetBool,'bool empty');

  nv.InitFrom('  key  =  123  ','=');
  Check(nv.name='key','trimmed name');
  Check(nv.value='123','trimmed value');
  Check(nv.GetInt=123,'get int');

  nv.Init('x','12.5');
  Check(AlmostEqual(nv.GetFloat,12.5),'get float');

  nv.Init('d','2026-03-19');
  dt:=nv.GetDate;
  Check(YearOf(dt)=2026,'date year');
  Check(MonthOf(dt)=3,'date month');
  Check(DayOf(dt)=19,'date day');

  nv.InitFrom('flag','=' );
  Check((nv.name='flag') and (nv.value=''),'initfrom without separator');
  EndTest;
end;

procedure TestNameValueList;
var
  l,l2:TNameValueList;
  arr:Strings8;
  item:TNameValue;
  saved:String8;
begin
  StartTest('Types.NameValueList');
  l:=TNameValueList.Init('a=1;b=2;c=',';','=');
  Check(l.Count=3,'count from string');
  Check(l.HasName('a'),'has a');
  Check(l.Find('b')=1,'find b');
  Check(l.Item['a']='1','getitem existing');
  Check(l.Item['missing']='','getitem missing empty');

  l.Item['b']:='22';
  Check(l.Item['b']='22','setitem update');
  l.Item['d']:='4';
  Check(l.Count=4,'setitem add new');
  Check(l.Item['d']='4','new item value');

  item.Init('e','5');
  l.Add(item);
  Check(l.Count=5,'add item');

  SetLength(arr,2);
  arr[0]:='x=10';
  arr[1]:='y=20';
  l2:=TNameValueList.Init(arr,'=');
  Check(l2.Count=2,'init from array');
  l.Add(l2);
  Check(l.Count=7,'add list');
  Check(l.HasName('x') and l.HasName('y'),'added list names');

  saved:=l.Save(';','=');
  Check(Pos('a=1',string(saved))>0,'save contains a');
  Check(Pos('b=22',string(saved))>0,'save contains updated b');
  EndTest;
end;

procedure TestBufferReadWrite;
var
  wb:TWriteBuffer;
  b:TBuffer;
  i:integer;
  c:cardinal;
  w:word;
  by:byte;
  bl:boolean;
  f:single;
  d:double;
  s:string8;
begin
  StartTest('Types.Buffer+WriteBuffer');
  wb.Init(16);
  wb.WriteByte($AB);
  wb.WriteBool(true);
  wb.WriteWord($1234);
  wb.WriteInt(-77);
  wb.WriteUInt($89ABCDEF);
  wb.WriteFloat(single(3.5));
  wb.WriteDouble(12.25);
  wb.WriteFlex(0);
  wb.WriteFlex(127);
  wb.WriteFlex(128);
  wb.WriteFlex(16384);
  wb.WriteFlex(16383);   // 2-byte max (14-bit LEB128)
  wb.WriteFlex(2097151); // 3-byte max (21-bit LEB128)
  wb.WriteStr('hello');
  b:=wb.AsBuffer;

  by:=b.ReadByte;
  Check(by=$AB,'read byte');
  bl:=b.ReadBool;
  Check(bl,'read bool');
  w:=b.ReadWord;
  Check(w=$1234,'read word');
  i:=b.ReadInt;
  Check(i=-77,'read int');
  c:=b.ReadUInt;
  Check(c=$89ABCDEF,'read uint');
  f:=b.ReadFloat;
  Check(AlmostEqual(f,3.5,1e-5),'read float');
  d:=b.ReadDouble;
  Check(AlmostEqual(d,12.25,1e-9),'read double');
  Check(b.ReadFlex=0,'read flex 0');
  Check(b.ReadFlex=127,'read flex 127');
  Check(b.ReadFlex=128,'read flex 128');
  Check(b.ReadFlex=16384,'read flex 16384');
  Check(b.ReadFlex=16383,'read flex 16383');
  Check(b.ReadFlex=2097151,'read flex 2097151');
  s:=b.ReadString;
  Check(s='hello','read string');
  Check(b.BytesLeft=0,'bytes left 0');
  EndTest;
end;

procedure TestBufferSlicing;
var
  data:array[0..7] of byte;
  b,s1,s2:TBuffer;
  v:byte;
  ba:ByteArray;
  s8:String8;
begin
  StartTest('Types.BufferSlice');
  data[0]:=10; data[1]:=11; data[2]:=12; data[3]:=13;
  data[4]:=14; data[5]:=15; data[6]:=16; data[7]:=17;

  b.CreateFrom(data,8);
  Check(b.CurrentPos=0,'pos=0');
  Check(b.BytesLeft=8,'bytesleft=8');

  s1:=b.Slice(2,true);
  Check(s1.size=2,'slice size');
  Check(b.CurrentPos=2,'slice advance');
  Check(s1.ReadByte=10,'slice b0');
  Check(s1.ReadByte=11,'slice b1');

  b.Seek(4);
  Check(b.CurrentPos=4,'seek');
  b.Skip(2);
  Check(b.CurrentPos=6,'skip');
  v:=b.ReadByte;
  Check(v=16,'read after seek/skip');

  s2:=b.Slice(0,2);
  Check(s2.ReadByte=10,'slice from b0');
  Check(s2.ReadByte=11,'slice from b1');

  // CreateFrom(ByteArray)
  SetLength(ba,3);
  ba[0]:=$AA; ba[1]:=$BB; ba[2]:=$CC;
  b.CreateFrom(ba);
  Check(b.size=3,'createfrom(array) size');
  Check(b.ReadByte=$AA,'createfrom(array) b0');
  Check(b.ReadByte=$BB,'createfrom(array) b1');
  Check(b.ReadByte=$CC,'createfrom(array) b2');

  // CreateFrom(String8)
  s8:='AB';
  b.CreateFrom(s8);
  Check(b.size=2,'createfrom(str8) size');
  Check(b.ReadByte=ord('A'),'createfrom(str8) b0');
  Check(b.ReadByte=ord('B'),'createfrom(str8) b1');
  EndTest;
end;

type
  TBufferOp=(boByte,boWord,boInt,boUInt,boFloat,boDouble,boFlex,boString,boRead,
    boSkip,boSeek,boSlice,boSliceHere,boNeed);

// Run op on b, return true if it raised EBufferOverrun and left the position unchanged
function Overruns(var b:TBuffer;op:TBufferOp;arg:int64=0;arg2:integer=0):boolean;
var
  pos:integer;
  tmp:array[0..15] of byte;
begin
  pos:=b.CurrentPos;
  try
    case op of
      boByte:b.ReadByte;
      boWord:b.ReadWord;
      boInt:b.ReadInt;
      boUInt:b.ReadUInt;
      boFloat:b.ReadFloat;
      boDouble:b.ReadDouble;
      boFlex:b.ReadFlex;
      boString:b.ReadString;
      boRead:b.Read(tmp,integer(arg));
      boSkip:b.Skip(integer(arg));
      boSeek:b.Seek(integer(arg));
      boSlice:b.Slice(integer(arg),arg2);
      boSliceHere:b.Slice(integer(arg),true);
      boNeed:b.Need(arg);
    end;
    result:=false;
  except
    on EBufferOverrun do begin
      // ReadFlex/ReadString consume the prefix they could parse, other ops must not move
      result:=(op in [boFlex,boString]) or (b.CurrentPos=pos);
    end;
  end;
end;

procedure TestBufferBounds;
const
  sizes:array[boByte..boDouble] of integer=(1,2,4,4,4,8);
var
  data:array[0..15] of byte;
  b,s:TBuffer;
  op:TBufferOp;
  ba:ByteArray;
  s8:String8;
  i:integer;
begin
  StartTest('Types.BufferBounds');
  FillChar(data,sizeof(data),0);
  // every fixed-size read on one byte less than needed
  for op:=boByte to boDouble do begin
    b.CreateFrom(data,sizes[op]-1);
    Check(Overruns(b,op),'short read raises, op '+Conv.ToStr(ord(op)));
    b.CreateFrom(data,sizes[op]);
    Check(not Overruns(b,op) and (b.BytesLeft=0),'exact read passes, op '+Conv.ToStr(ord(op)));
  end;
  b.CreateFrom(data,3);
  b.Skip(1);
  Check(Overruns(b,boRead,3),'read block past the end');
  Check(Overruns(b,boRead,-1),'read negative size');
  Check(not Overruns(b,boRead,2) and (b.BytesLeft=0),'read block up to the end');

  // ReadFlex
  data[0]:=$80; data[1]:=$80;
  b.CreateFrom(data,2);
  Check(Overruns(b,boFlex),'flex truncated after continuation byte');
  for i:=0 to 5 do data[i]:=$80;
  b.CreateFrom(data,6);
  Check(Overruns(b,boFlex),'flex longer than 5 bytes');
  data[0]:=$FF; data[1]:=$FF; data[2]:=$FF; data[3]:=$FF; data[4]:=$10;
  b.CreateFrom(data,5);
  Check(Overruns(b,boFlex),'flex above 32 bits');
  data[4]:=$0F;
  b.CreateFrom(data,5);
  Check(b.ReadFlex=$FFFFFFFF,'flex max value');
  Check(b.BytesLeft=0,'flex max value consumed 5 bytes');
  b.CreateFrom(data,0);
  Check(Overruns(b,boFlex),'flex on empty buffer');

  // ReadString
  data[0]:=5; data[1]:=ord('a'); data[2]:=ord('b');
  b.CreateFrom(data,3);
  Check(Overruns(b,boString),'string longer than the data');
  data[0]:=$FF; data[1]:=$FF; data[2]:=$FF; data[3]:=$FF; data[4]:=$07;
  b.CreateFrom(data,5);
  Check(Overruns(b,boString),'huge string length rejected before allocation');
  data[0]:=0;
  b.CreateFrom(data,1);
  Check(b.ReadString='','empty string');
  Check(b.BytesLeft=0,'empty string consumed its length');

  // Seek and Skip
  b.CreateFrom(data,8);
  b.Seek(8);
  Check((b.CurrentPos=8) and (b.BytesLeft=0),'seek to the end');
  Check(Overruns(b,boByte),'read at the end');
  Check(Overruns(b,boSeek,9),'seek past the end');
  Check(Overruns(b,boSeek,-1),'seek before the start');
  b.Seek(3);
  b.Skip(-3);
  Check(b.CurrentPos=0,'skip back to the start');
  Check(Overruns(b,boSkip,-1),'skip before the start');
  Check(Overruns(b,boSkip,9),'skip past the end');
  b.Skip(8);
  Check(b.BytesLeft=0,'skip to the end');

  // Slice
  b.CreateFrom(data,8);
  Check(Overruns(b,boSlice,-1,2),'slice negative start');
  Check(Overruns(b,boSlice,9,0),'slice start past the end');
  Check(Overruns(b,boSlice,2,-1),'slice negative length');
  Check(Overruns(b,boSlice,6,3),'slice past the end');
  Check(Overruns(b,boSlice,1,MaxInt),'slice end overflow');
  s:=b.Slice(8,0);
  Check(s.size=0,'empty slice at the end');
  Check(Overruns(s,boByte),'read from empty slice');
  s:=b.Slice(2,4);
  Check(Overruns(s,boDouble),'slice limits reads');
  b.Seek(5);
  Check(Overruns(b,boSliceHere,4),'slice from position past the end');
  s:=b.Slice(3,true);
  Check((s.size=3) and (b.BytesLeft=0),'slice from position to the end');

  // Need
  b.CreateFrom(data,8);
  Check(not Overruns(b,boNeed,8),'need all bytes');
  Check(not Overruns(b,boNeed,0),'need zero bytes');
  Check(Overruns(b,boNeed,9),'need too many');
  Check(Overruns(b,boNeed,-1),'need negative');
  Check(Overruns(b,boNeed,int64(MaxInt)*16),'need count*size above 32 bits');

  // CreateFrom with empty data
  SetLength(ba,0);
  b.CreateFrom(ba);
  Check((b.size=0) and (b.BytesLeft=0),'createfrom(empty array)');
  Check(Overruns(b,boByte),'read from empty array');
  s8:='';
  b.CreateFrom(s8);
  Check((b.size=0) and (b.BytesLeft=0),'createfrom(empty string)');
  Check(Overruns(b,boByte),'read from empty string');
  EndTest;
end;

procedure TestBitStream;
var
  bs:TBitStream;
  outByte:byte;
  i:integer;
begin
  StartTest('Types.BitStream');
  bs.Init(1);
  Check(bs.size=0,'init size');
  bs.Put(cardinal($B),4); // 1011b LSB-first
  Check(bs.size=4,'size after put');
  Check(bs.GetBit(0)=1,'bit0');
  Check(bs.GetBit(1)=1,'bit1');
  Check(bs.GetBit(2)=0,'bit2');
  Check(bs.GetBit(3)=1,'bit3');
  Check(bs.SizeInBytes=1,'size bytes');

  outByte:=0;
  bs.Get(outByte,4);
  Check((outByte and $0F)=$0B,'read back nibble');

  bs.Init(2);
  for i:=0 to 127 do
    bs.Put(cardinal(i and 1),1);
  Check(bs.size=128,'size after many bits');
  Check(bs.SizeInBytes=16,'bytes after many bits');
  Check(bs.GetBit(0)=0,'many bit0');
  Check(bs.GetBit(1)=1,'many bit1');
  Check(bs.GetBit(126)=0,'many bit126');
  Check(bs.GetBit(127)=1,'many bit127');

  // SetBit: override individual bits
  bs.Init(4);
  bs.Put(cardinal(0),4); // 0000
  bs.SetBit(0,1);
  bs.SetBit(2,1);
  Check(bs.GetBit(0)=1,'setbit: bit0 set');
  Check(bs.GetBit(1)=0,'setbit: bit1 unchanged');
  Check(bs.GetBit(2)=1,'setbit: bit2 set');
  Check(bs.GetBit(3)=0,'setbit: bit3 unchanged');
  bs.SetBit(0,0);
  Check(bs.GetBit(0)=0,'setbit: clear bit0');
  EndTest;
end;

begin
  try
    TestIntRange;
    TestFloatRange;
    TestArrayHelper;
    TestNameValue;
    TestNameValueList;
    TestBufferReadWrite;
    TestBufferSlicing;
    TestBufferBounds;
    TestBitStream;

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
