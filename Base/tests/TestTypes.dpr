{$APPTYPE CONSOLE}
{$R+}
{$Q+}
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
begin
  StartTest('Types.IntRange');
  r.Init(-3,7);
  Check(r.min=-3,'min set');
  Check(r.max=7,'max set');
  Check(r.Width=10,'width');
  for i:=1 to 500 do begin
    v:=r.Rand;
    Check((v>=-3) and (v<=7),'rand bounds');
  end;
  EndTest;
end;

procedure TestFloatRange;
var
  r:TFloatRange;
  i:integer;
  v:single;
begin
  StartTest('Types.FloatRange');
  r.Init(single(-1.5),single(2.25));
  Check(AlmostEqual(r.min,-1.5),'min set');
  Check(AlmostEqual(r.max,2.25),'max set');
  Check(AlmostEqual(r.Width,3.75),'width');
  for i:=1 to 500 do begin
    v:=r.Rand;
    Check((v>=-1.5) and (v<=2.25),'rand bounds');
  end;
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
  Check(nv.GetBool,'bool parse');

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
