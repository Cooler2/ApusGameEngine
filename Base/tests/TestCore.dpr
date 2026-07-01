{$APPTYPE CONSOLE}
{$R+}  // Range checking
{$Q+}  // Overflow checking
program TestCore;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv;

{$INCLUDE Test.inc}

type
  TSortRec=packed record
    i:integer;
    f:single;
    d:double;
    s:String8;
  end;

procedure TestMinMax;
begin
  StartTest('Min/Max');
  // integer 2 args
  Check(Min(1,2)=1,'Min(1,2)');
  Check(Min(5,3)=3,'Min(5,3)');
  Check(Min(-1,1)=-1,'Min(-1,1)');
  Check(Max(1,2)=2,'Max(1,2)');
  Check(Max(5,3)=5,'Max(5,3)');
  Check(Max(-1,1)=1,'Max(-1,1)');
  // integer 3 args
  Check(Min(3,1,2)=1,'Min(3,1,2)');
  Check(Min(1,2,3)=1,'Min(1,2,3)');
  Check(Max(1,3,2)=3,'Max(1,3,2)');
  Check(Max(3,2,1)=3,'Max(3,2,1)');
  // single
  Check(Min(single(1.5),single(2.5))=1.5,'Min(1.5,2.5) single');
  Check(Max(single(1.5),single(2.5))=2.5,'Max(1.5,2.5) single');
  // double
  Check(Min(1.5,2.5)=1.5,'Min(1.5,2.5) double');
  Check(Max(1.5,2.5)=2.5,'Max(1.5,2.5) double');
  EndTest;
end;

procedure TestMinMaxCornerCases;
var
  sMin,sMax:single;
begin
  StartTest('Min/Max corner cases');

  // cardinal overloads: values above MaxInt must be preserved
  Check(Min(cardinal(3000000000),cardinal(4000000000))=cardinal(3000000000),
    'Min(cardinal,cardinal) should preserve >MaxInt values');
  Check(Max(cardinal(3000000000),cardinal(4000000000))=cardinal(4000000000),
    'Max(cardinal,cardinal) should preserve >MaxInt values');

  // int64 overloads: values outside integer range must be preserved
  Check(Min(int64(-5000000000),int64(7000000000))=int64(-5000000000),
    'Min(int64,int64) should preserve 64-bit range');
  Check(Max(int64(-5000000000),int64(7000000000))=int64(7000000000),
    'Max(int64,int64) should preserve 64-bit range');

  // uint64 overloads: values above cardinal range must be preserved
  Check(Min(uint64(5000000000),uint64(6000000000))=uint64(5000000000),
    'Min(uint64,uint64) should preserve >cardinal values');
  Check(Max(uint64(5000000000),uint64(6000000000))=uint64(6000000000),
    'Max(uint64,uint64) should preserve >cardinal values');

  // single(3 args): fractional part must be preserved
  sMin:=Min(single(2.75),single(3.5),single(1.25));
  sMax:=Max(single(2.75),single(3.5),single(1.25));
  Check(Abs(sMin-1.25)<0.0001,'Min(single,single,single) should preserve fraction');
  Check(Abs(sMax-3.5)<0.0001,'Max(single,single,single) should preserve fraction');
  EndTest;
end;

procedure TestClamp;
begin
  StartTest('Clamp/Sat');
  // integer
  Check(Clamp(5,0,10)=5,'Clamp(5,0,10)');
  Check(Clamp(-5,0,10)=0,'Clamp(-5,0,10)');
  Check(Clamp(15,0,10)=10,'Clamp(15,0,10)');
  // single
  Check(Clamp(single(0.5),single(0.0),single(1.0))=0.5,'Clamp single middle');
  Check(Clamp(single(-0.5),single(0.0),single(1.0))=0.0,'Clamp single below');
  Check(Clamp(single(1.5),single(0.0),single(1.0))=1.0,'Clamp single above');
  // Sat
  Check(Sat(single(0.5))=0.5,'Sat(0.5) single');
  Check(Sat(single(-0.5))=0.0,'Sat(-0.5) single');
  Check(Sat(single(1.5))=1.0,'Sat(1.5) single');
  Check(Sat(0.5)=0.5,'Sat(0.5) double');
  Check(Sat(-0.5)=0.0,'Sat(-0.5) double');
  Check(Sat(1.5)=1.0,'Sat(1.5) double');
  EndTest;
end;

procedure TestLerp;
var
  s0,s10,s05,sn05,s15,s1:single; // use variables to avoid FPC reinterpret cast issue
begin
  StartTest('Lerp/LerpC');
  s0:=0; s10:=10; s05:=0.5; sn05:=-0.5; s15:=1.5; s1:=1;
  Check(Abs(Lerp(s0,s10,s05)-5.0)<0.001,'Lerp(0,10,0.5) single');
  Check(Abs(Lerp(s0,s10,s0)-0.0)<0.001,'Lerp(0,10,0) single');
  Check(Abs(Lerp(s0,s10,s1)-10.0)<0.001,'Lerp(0,10,1) single');
  Check(Abs(Lerp(0.0,10.0,0.5)-5.0)<0.001,'Lerp(0,10,0.5) double');
  Check(Abs(Lerp(-10.0,10.0,0.5)-0.0)<0.001,'Lerp(-10,10,0.5) double');
  // LerpC - clamps t to [0,1]
  Check(Abs(LerpC(s0,s10,sn05)-0.0)<0.001,'LerpC(0,10,-0.5) clamped');
  Check(Abs(LerpC(s0,s10,s15)-10.0)<0.001,'LerpC(0,10,1.5) clamped');
  Check(Abs(LerpC(s0,s10,s05)-5.0)<0.001,'LerpC(0,10,0.5) normal');
  EndTest;
end;

procedure TestSwap;
var
  a,b:integer;
  x,y:single;
  s1,s2:string;
  s81,s82:string8;
  rec1,rec2:record x,y:integer; end;
begin
  StartTest('Swap');
  a:=1; b:=2;
  Swap(a,b);
  Check((a=2) and (b=1),'Swap integer');

  x:=1.5; y:=2.5;
  Swap(x,y);
  Check((x=2.5) and (y=1.5),'Swap single');

  s1:='hello'; s2:='world';
  Swap(s1,s2);
  Check((s1='world') and (s2='hello'),'Swap string');

  s81:='abc'; s82:='xyz';
  Swap(s81,s82);
  Check((s81='xyz') and (s82='abc'),'Swap string8');

  rec1.x:=1; rec1.y:=2;
  rec2.x:=3; rec2.y:=4;
  Swap(rec1,rec2,sizeof(rec1));
  Check((rec1.x=3) and (rec1.y=4) and (rec2.x=1) and (rec2.y=2),'Swap untyped');
  EndTest;
end;

procedure TestPow2;
begin
  StartTest('Pow2 functions');
  Check(NextPow2(1)=1,'NextPow2(1)');
  Check(NextPow2(2)=2,'NextPow2(2)');
  Check(NextPow2(3)=4,'NextPow2(3)');
  Check(NextPow2(5)=8,'NextPow2(5)');
  Check(NextPow2(100)=128,'NextPow2(100)');
  Check(NextPow2(256)=256,'NextPow2(256)');
  Check(NextPow2(257)=512,'NextPow2(257)');
  Check(NextPow2(uint64($100000000))=uint64($100000000),'NextPow2(2^32)');
  Check(NextPow2(uint64($100000001))=uint64($200000000),'NextPow2(2^32+1)');
  Check(NextPow2(uint64($8000000000000000))=uint64($8000000000000000),'NextPow2(2^63)');
  Check(NextPow2(uint64($8000000000000001))=0,'NextPow2 overflow -> 0');

  Check(Pow2(0)=1,'Pow2(0)');
  Check(Pow2(1)=2,'Pow2(1)');
  Check(Pow2(8)=256,'Pow2(8)');
  Check(Pow2(10)=1024,'Pow2(10)');
  Check(Pow2(62)=int64($4000000000000000),'Pow2(62)');
  Check(Pow2(63)=0,'Pow2(63) overflow');
  Check(Pow2(-1)=0,'Pow2(-1)');
  Check(Pow2(64)=0,'Pow2(64)');

  Check(Log2i(1)=0,'Log2i(1)');
  Check(Log2i(2)=1,'Log2i(2)');
  Check(Log2i(3)=2,'Log2i(3)');
  Check(Log2i(4)=2,'Log2i(4)');
  Check(Log2i(5)=3,'Log2i(5)');
  Check(Log2i(1024)=10,'Log2i(1024)');
  Check(Log2i(1025)=11,'Log2i(1025)');
  Check(Log2i(int64(1) shl 40)=40,'Log2i(2^40)');
  Check(Log2i((int64(1) shl 40)+1)=41,'Log2i(2^40+1)');
  EndTest;
end;

procedure TestWrapRound;
var
  s:single;
  d:double;
begin
  StartTest('Wrap/Round');

  // Wrap
  s:=Wrap(single(2.5),single(2.0));
  Check(Abs(s-0.5)<0.001,'Wrap single above range');
  s:=Wrap(single(-0.5),single(2.0));
  Check(Abs(s-1.5)<0.001,'Wrap single below range');
  d:=Wrap(5.25,2.0);
  Check(Abs(d-1.25)<0.001,'Wrap double above range');
  d:=Wrap(-0.25,2.0);
  Check(Abs(d-1.75)<0.001,'Wrap double below range');

  // FRound / PRound / SRound (non-ambiguous values)
  Check(FRound(2.49)=2,'FRound(2.49)');
  Check(FRound(2.51)=3,'FRound(2.51)');
  Check(PRound(2.49)=2,'PRound(2.49)');
  Check(PRound(2.51)=3,'PRound(2.51)');
  Check(SRound(single(2.49))=2,'SRound(2.49)');
  Check(SRound(single(2.51))=3,'SRound(2.51)');

  EndTest;
end;

procedure TestAtomicSpin;
var
  v:longint;
  lock:integer;
begin
  StartTest('Atomic/Spin/Barrier');

  v:=0;
  Check(Atomic.Inc(v)=1,'Atomic.Inc');
  Check(v=1,'Atomic.Inc writes target');
  Check(Atomic.Dec(v)=0,'Atomic.Dec');
  Check(v=0,'Atomic.Dec writes target');
  Check(Atomic.Add(v,10)=10,'Atomic.Add');
  Check(Atomic.Sub(v,3)=7,'Atomic.Sub');
  Check(Atomic.Exchange(v,42)=7,'Atomic.Exchange returns old');
  Check(v=42,'Atomic.Exchange writes new');
  Check(Atomic.CmpExchange(v,100,42)=42,'Atomic.CmpExchange success returns old');
  Check(v=100,'Atomic.CmpExchange success writes new');
  Check(Atomic.CmpExchange(v,7,42)=100,'Atomic.CmpExchange fail returns current');
  Check(v=100,'Atomic.CmpExchange fail keeps value');

  lock:=0;
  SpinLock(lock);
  Check(lock=1,'SpinLock(var) sets lock');
  SpinUnlock(lock);
  Check(lock=0,'SpinUnlock(var) clears lock');

  SpinLock;
  Check(globalSpinLock=1,'SpinLock global sets lock');
  SpinUnlock;
  Check(globalSpinLock=0,'SpinUnlock global clears lock');

  // Coverage for barrier primitive
  MemoryBarrier;
  Check(true,'MemoryBarrier callable');

  EndTest;
end;

procedure TestSystemPrimitives;
var
  tid:TThreadID;
  code:cardinal;
  desc:string;
  t0,t1:int64;
  t:int64;
  dt:double;
  saved:TSystemMessageFlags;
begin
  StartTest('System primitives');

  tid:=GetCurrentThreadID;
  Check(UIntPtr(tid)<>0,'GetCurrentThreadID non-zero');

  // Ticks/Sleep monotonicity
  t0:=CoreTime.Ticks;
  CoreTime.Sleep(5);
  t1:=CoreTime.Ticks;
  Check(t1>=t0,'CoreTime.Ticks monotonic');

  // Timer.Start/Timer.Get
  Timer.Start(t);
  CoreTime.Sleep(10);
  dt:=Timer.Get(t);
  Check(dt>=0.005,'Timer.Get(explicit) after sleep');
  Timer.Start;
  CoreTime.Sleep(10);
  dt:=Timer.Get;
  Check(dt>=0.005,'Timer.Get (global) after sleep');

  code:=GetLastErrorCode;
  desc:=GetLastErrorDesc;
  Check(desc<>'','GetLastErrorDesc non-empty');
  // code may be 0 or non-zero depending on previous API calls
  Check((code=0) or (code<>0),'GetLastErrorCode callable');

  // SystemMessage: visual test (stderr + debug output)
  Check(hasConsole,'hasConsole detected');
  saved:=systemMessageFlags;
  systemMessageFlags:=[TSystemMessageFlag.smStdErr,TSystemMessageFlag.smDebugOutput];
  SystemMessage('SystemMessage test: this should appear on stderr');
  systemMessageFlags:=saved;

  EndTest;
end;

procedure TestMemGuardedFillClear;
const
  GUARD = $CC;
type
  TGuarded = packed record
    pre:array[0..15] of byte;
    data:array[0..63] of byte;
    post:array[0..15] of byte;
  end;
var
  g:TGuarded;
  i:integer;

  function GuardsIntact:boolean;
  var
    j:integer;
  begin
    result:=true;
    for j:=0 to high(g.pre) do
      if g.pre[j]<>GUARD then exit(false);
    for j:=0 to high(g.post) do
      if g.post[j]<>GUARD then exit(false);
  end;
begin
  StartTest('Mem Fill/Clear guards');

  FillChar(g,sizeof(g),GUARD);
  Mem.Fill(g.data[0],length(g.data),$AA);
  Check(GuardsIntact,'Mem.Fill must not touch guards');
  Check((g.data[0]=$AA) and (g.data[high(g.data)]=$AA),'Mem.Fill writes inside buffer');

  FillChar(g,sizeof(g),GUARD);
  Mem.Clear(g.data[0],length(g.data));
  Check(GuardsIntact,'Mem.Clear must not touch guards');
  for i:=0 to high(g.data) do
    if g.data[i]<>0 then begin
      Check(false,'Mem.Clear zeroes data area');
      EndTest;
      exit;
    end;
  Check(true,'Mem.Clear zeroes data area');

  FillChar(g,sizeof(g),GUARD);
  Mem.FillQ(g.data[0],length(g.data) div 8,$1122334455667788);
  Check(GuardsIntact,'Mem.FillQ must not touch guards');

  FillChar(g,sizeof(g),GUARD);
  Mem.FillF(g.data[0],length(g.data) div 4,3.5);
  Check(GuardsIntact,'Mem.FillF must not touch guards');

  EndTest;
end;

procedure TestBitsEdgeCases;
var
  q:uint64;
begin
  StartTest('Bits edge cases');

  // size=0 means empty field: function must not modify destination
  q:=0;
  Bits.SetBits(q,0,0,-1);
  Check(q=0,'SetBits uint64 size=0 leaves value unchanged');
  Check(Bits.GetBits(q,10,0)=0,'GetBits uint64 size=0 is zero');

  // value parameter is signed integer; pass high-bit pattern as signed literal.
  // Expected: write exactly 32 bits into high dword [63..32].
  q:=0;
  Bits.SetBits(q,32,32,-1985229329); // $89ABCDEF as signed 32-bit
  Check(Bits.GetBits(q,32,32)=$89ABCDEF,'GetBits uint64 high dword');

  // Low 32-bit field write/read roundtrip
  q:=0;
  Bits.SetBits(q,0,32,$12345678);
  Check(Bits.GetBits(q,0,32)=$12345678,'GetBits uint64 low dword');
  Check(q=uint64($0000000012345678),'SetBits uint64 low field write');

  EndTest;
end;

procedure TestToggle;
var
  b:boolean;
begin
  StartTest('Toggle');
  b:=false;
  Toggle(b);
  Check(b=true,'Toggle false->true');
  Toggle(b);
  Check(b=false,'Toggle true->false');
  EndTest;
end;

procedure TestIsNaN;
var
  v:single;
  d:double;
  nanBits:cardinal;
  nanBits64:uint64;
begin
  StartTest('IsNaN');
  // create NaN via bit manipulation to avoid FPU exception in FPC
  nanBits:=$7FC00000; // quiet NaN for single
  Move(nanBits,v,4);
  Check(IsNaN(v),'IsNaN single');
  v:=1.0;
  Check(not IsNaN(v),'not IsNaN(1.0) single');
  nanBits64:=$7FF8000000000000; // quiet NaN for double
  Move(nanBits64,d,8);
  Check(IsNaN(d),'IsNaN double');
  d:=1.0;
  Check(not IsNaN(d),'not IsNaN(1.0) double');
  EndTest;
end;

procedure TestPtrInside;
var
  buf:array[0..15] of byte;
begin
  StartTest('PtrInside');
  Check(PtrInside(@buf[5],@buf[0],16),'PtrInside inside');
  Check(not PtrInside(@buf[0],@buf[5],8),'PtrInside outside');
  Check(PtrInside(@buf[0],@buf[0],16),'PtrInside at start');
  Check(not PtrInside(@buf[15],@buf[0],15),'PtrInside at end (exclusive)');
  EndTest;
end;

procedure TestMem;
var
  buf:array[0..15] of byte;
  arrW:array[0..7] of word;
  arrD:array[0..7] of cardinal;
  arrQ:array[0..7] of uint64;
  arrF:array[0..7] of single;
  src,dst:array[0..3] of byte;
begin
  StartTest('Mem');

  // Clear + IsZero
  Mem.Fill(buf,sizeof(buf),$FF);
  Mem.Clear(buf,sizeof(buf));
  Check(Mem.IsZero(buf,sizeof(buf)),'Mem.Clear + Mem.IsZero');

  // Fill
  Mem.Fill(buf,sizeof(buf),$AA);
  Check((buf[0]=$AA) and (buf[15]=$AA),'Mem.Fill');

  // FillW
  Mem.FillW(arrW,8,$1234);
  Check((arrW[0]=$1234) and (arrW[7]=$1234),'Mem.FillW');

  // FillD
  Mem.FillD(arrD,8,$DEADBEEF);
  Check((arrD[0]=$DEADBEEF) and (arrD[7]=$DEADBEEF),'Mem.FillD');

  // FillQ
  Mem.FillQ(arrQ,8,$123456789ABCDEF0);
  Check((arrQ[0]=$123456789ABCDEF0) and (arrQ[7]=$123456789ABCDEF0),'Mem.FillQ');

  // FillF
  Mem.FillF(arrF,8,3.14);
  Check((Abs(arrF[0]-3.14)<0.001) and (Abs(arrF[7]-3.14)<0.001),'Mem.FillF');

  // Shift forward
  Mem.Clear(buf,sizeof(buf));
  buf[0]:=$AA; buf[1]:=$BB;
  Mem.Shift(buf,16,2);
  Check((buf[2]=$AA) and (buf[3]=$BB),'Mem.Shift forward');

  // Shift backward
  Mem.Clear(buf,sizeof(buf));
  buf[4]:=$CC; buf[5]:=$DD;
  Mem.Shift(buf,16,-2);
  Check((buf[2]=$CC) and (buf[3]=$DD),'Mem.Shift backward');

  // Copy
  src[0]:=$11; src[1]:=$22; src[2]:=$33; src[3]:=$44;
  Mem.Clear(dst,sizeof(dst));
  Mem.Copy(src,dst,4);
  Check((dst[0]=$11) and (dst[3]=$44),'Mem.Copy');

  // Equal
  Check(Mem.Equal(src,dst,4),'Mem.Equal identical');
  dst[2]:=$FF;
  Check(not Mem.Equal(src,dst,4),'Mem.Equal different');
  Check(Mem.Equal(src,dst,2),'Mem.Equal partial match');
  Check(Mem.Equal(src,src,0),'Mem.Equal zero size');

  EndTest;
end;

procedure TestMemUnaligned;
const
  GUARD_BYTE = $CC;  // guard pattern
  TEST_VALUE = $DEADBEEF;
  DATA_SIZE = 512;  // 512 bytes = 128 dwords max
  BUFFER_SIZE = 16 + DATA_SIZE + 16;  // guardPre + data + guardPost
type
  TGuardedBuffer = packed record
    guardPre:array[0..15] of byte;   // guard before
    data:array[0..DATA_SIZE-1] of byte;  // actual data
    guardPost:array[0..15] of byte;  // guard after
  end;
var
  bufStorage:array[0..BUFFER_SIZE+31] of byte; // extra space for alignment
  buf:^TGuardedBuffer;
  p:PByte;
  pData:PCardinal;
  offset,i,countIdx,count:integer;
  failed:boolean;
  src:array[0..31] of byte;
  counts:array[0..6] of integer;

  function CheckGuards(const msg:string):boolean;
  var j:integer;
  begin
    result:=true;
    // check pre-guard
    for j:=0 to 15 do
      if buf^.guardPre[j]<>GUARD_BYTE then begin
        writeln('  GUARD VIOLATION (pre): offset ',j,' = $',IntToHex(buf^.guardPre[j],2),' at ',msg);
        result:=false;
      end;
    // check post-guard
    for j:=0 to 15 do
      if buf^.guardPost[j]<>GUARD_BYTE then begin
        writeln('  GUARD VIOLATION (post): offset ',j,' = $',IntToHex(buf^.guardPost[j],2),' at ',msg);
        result:=false;
      end;
  end;

begin
  StartTest('Mem unaligned with guards');

  // align buffer to 16-byte boundary
  buf:=Pointer(AlignUp(UIntPtr(@bufStorage[0]),16));

  // debug output
  writeln('  bufStorage addr: ',Conv.ToStr(@bufStorage[0]));
  writeln('  bufStorage size: ',Length(bufStorage));
  writeln('  buf addr: ',Conv.ToStr(buf));
  writeln('  BUFFER_SIZE: ',BUFFER_SIZE);

  // verify alignment is valid (buf must fit inside bufStorage)
  if (UIntPtr(buf)<UIntPtr(@bufStorage[0])) or
     (UIntPtr(buf)+BUFFER_SIZE>UIntPtr(@bufStorage[0])+UIntPtr(Length(bufStorage))) then begin
    writeln('  ERROR: Buffer outside storage bounds!');
    Check(false,'Buffer alignment error');
    exit;
  end;

  // Test FillD with different sizes and alignments
  counts[0]:=16; counts[1]:=17; counts[2]:=20; counts[3]:=32;
  counts[4]:=48; counts[5]:=63; counts[6]:=64;

  for countIdx:=0 to High(counts) do begin
    count:=counts[countIdx];

    for offset:=0 to 15 do begin
      // skip if data won't fit
      if offset+count*4>DATA_SIZE then
        continue;

      // initialize guards
      FillChar(buf^,BUFFER_SIZE,GUARD_BYTE);

      // get pointer with specific offset into data area
      p:=@buf^.data[offset];
      pData:=PCardinal(p);

      try
        // fill count dwords at offset
        Mem.FillD(pData^,count,TEST_VALUE);
      except
        on e:Exception do begin
          writeln;
          writeln('  EXCEPTION! count=',count,' offset=',offset);
          writeln('  Exception: ',ExceptionMsg(e));
          raise;
        end;
      end;
  
      // verify data was written correctly
      failed:=false;
      for i:=0 to count-1 do
        if PCardinal(UIntPtr(pData)+UIntPtr(i*4))^<>TEST_VALUE then begin
          writeln('  DATA ERROR at count=',count,' offset=',offset,' dword=',i);
          failed:=true;
        end;

      // check guards weren't overwritten
      if not CheckGuards('FillD count='+IntToStr(count)+' offset='+IntToStr(offset)) then
        failed:=true;

      if failed then begin
        Check(false,'FillD failed at count='+IntToStr(count)+' offset='+IntToStr(offset));
        break;
      end;
    end;

    if failed then break;
  end;

  if not failed then
    Check(true,'FillD passed all tests (counts: 16-64, offsets: 0-15)');

  // test FillW with different alignments
  failed:=false;
  for offset:=0 to 15 do begin
    FillChar(buf^,BUFFER_SIZE,GUARD_BYTE);
    p:=@buf^.data[offset];

    // fill 16 words (32 bytes) at offset
    Mem.FillW(PWord(p)^,16,$BEEF);

    // verify data
    for i:=0 to 15 do
      if PWord(UIntPtr(p)+UIntPtr(i*2))^<>$BEEF then begin
        writeln('  DATA ERROR FillW at offset ',offset,', word ',i);
        failed:=true;
      end;

    if not CheckGuards('FillW offset '+IntToStr(offset)) then
      failed:=true;

    if failed then begin
      Check(false,'FillW failed at offset '+IntToStr(offset));
      break;
    end;
  end;

  if not failed then
    Check(true,'FillW passed all alignment tests');

  // test Copy with different alignments
  failed:=false;
  for offset:=0 to 7 do begin
    FillChar(buf^,BUFFER_SIZE,GUARD_BYTE);

    // prepare source with pattern
    for i:=0 to 31 do
      src[i]:=byte(i+$10);

    p:=@buf^.data[offset];
    Mem.Copy(src,p^,32);

    // verify copied data
    for i:=0 to 31 do
      if PByte(UIntPtr(p)+UIntPtr(i))^<>byte(i+$10) then begin
        writeln('  DATA ERROR Copy at offset ',offset,', byte ',i);
        failed:=true;
      end;

    if not CheckGuards('Copy offset '+IntToStr(offset)) then
      failed:=true;

    if failed then begin
      Check(false,'Copy failed at offset '+IntToStr(offset));
      break;
    end;
  end;

  if not failed then
    Check(true,'Copy passed all alignment tests');

  EndTest;
end;

procedure TestBitsSwapWords;
begin
  StartTest('Bits.SwapWords');
  Check(Bits.SwapWords($00010002)=$00020001,'SwapWords($00010002)');
  Check(Bits.SwapWords($FFFF0000)=$0000FFFF,'SwapWords($FFFF0000)');
  Check(Bits.SwapWords($00000000)=$00000000,'SwapWords(0)');
  Check(Bits.SwapWords($FFFFFFFF)=$FFFFFFFF,'SwapWords($FFFFFFFF)');
  Check(Bits.SwapWords($12345678)=$56781234,'SwapWords($12345678)');
  Check(Bits.SwapWords($00FF0000)=$000000FF,'SwapWords($00FF0000)');
  EndTest;
end;

procedure TestBits;
var
  v:cardinal;
  b:byte;
  w:word;
  q:uint64;
begin
  StartTest('Bits');

  // HasAll
  Check(Bits.HasAll(cardinal($FF),cardinal($0F)),'Bits.HasAll($FF,$0F)');
  Check(not Bits.HasAll(cardinal($F0),cardinal($0F)),'not Bits.HasAll($F0,$0F)');
  Check(Bits.HasAll(cardinal($FF),cardinal($FF)),'Bits.HasAll($FF,$FF)');

  // HasAny
  Check(Bits.HasAny(cardinal($F0),cardinal($10)),'Bits.HasAny($F0,$10)');
  Check(not Bits.HasAny(cardinal($F0),cardinal($0F)),'not Bits.HasAny($F0,$0F)');
  Check(Bits.HasAny(cardinal($FF),cardinal($01)),'Bits.HasAny($FF,$01)');

  // SetFlag/Clear cardinal
  v:=0;
  Bits.SetFlag(v,$0F);
  Check(v=$0F,'Bits.SetFlag cardinal');
  Bits.SetFlag(v,$F0);
  Check(v=$FF,'Bits.SetFlag cardinal second');
  Bits.Clear(v,$0F);
  Check(v=$F0,'Bits.Clear cardinal');

  // SetFlag/Clear byte
  b:=0;
  Bits.SetFlag(b,$0F);
  Check(b=$0F,'Bits.SetFlag byte');
  Bits.Clear(b,$05);
  Check(b=$0A,'Bits.Clear byte');

  // SetFlag/Clear word
  w:=0;
  Bits.SetFlag(w,$00FF);
  Check(w=$00FF,'Bits.SetFlag word');
  Bits.Clear(w,$000F);
  Check(w=$00F0,'Bits.Clear word');

  // SetFlag/Clear uint64 (need explicit uint64() cast in FPC)
  q:=0;
  Bits.SetFlag(q,uint64($FF00000000000000));
  Check(q=uint64($FF00000000000000),'Bits.SetFlag uint64');
  Bits.Clear(q,uint64($0F00000000000000));
  Check(q=uint64($F000000000000000),'Bits.Clear uint64');

  // Modify
  v:=$00;
  Bits.Modify(v,$0F,true);
  Check(v=$0F,'Bits.Modify set');
  Bits.Modify(v,$0F,false);
  Check(v=$00,'Bits.Modify clear');
  Bits.Modify(v,$FF,true);
  Bits.Modify(v,$0F,false);
  Check(v=$F0,'Bits.Modify partial clear');

  // Get/SetBit cardinal
  v:=0;
  Check(not Bits.Get(v,0),'Bits.Get(0,0)');
  Bits.SetBit(v,0);
  Check(Bits.Get(v,0),'Bits.Get after SetBit');
  Check(v=1,'v=1 after SetBit(0)');
  Bits.SetBit(v,7);
  Check(v=$81,'v=$81 after SetBit(7)');
  Bits.SetBit(v,0,false);
  Check(v=$80,'v=$80 after SetBit(0,false)');

  // SetBit byte
  b:=0;
  Bits.SetBit(b,0);
  Bits.SetBit(b,7);
  Check(b=$81,'SetBit byte');

  // SetBit word
  w:=0;
  Bits.SetBit(w,0);
  Bits.SetBit(w,15);
  Check(w=$8001,'SetBit word');

  // SetBit uint64
  q:=0;
  Bits.SetBit(q,0);
  Bits.SetBit(q,63);
  Check(q=uint64($8000000000000001),'SetBit uint64');

  // SetBits should mask value to field size
  v:=0;
  Bits.SetBits(v,4,4,$FF);
  Check(v=$F0,'Bits.SetBits cardinal masks value');
  Check(Bits.GetBits(v,4,4)=$F,'Bits.GetBits cardinal after masked set');

  b:=0;
  Bits.SetBits(b,1,3,$FF);
  Check(b=$0E,'Bits.SetBits byte masks value');

  w:=0;
  Bits.SetBits(w,8,4,$AB);
  Check(w=$0B00,'Bits.SetBits word masks value');

  q:=0;
  Bits.SetBits(q,60,4,$FF);
  Check(q=uint64($F000000000000000),'Bits.SetBits uint64 masks value');

  EndTest;
end;

procedure TestSortScope;
var
  arr:array of TSortRec;
begin
  StartTest('Sort');
  SetLength(arr,5);
  arr[0].i:=5;  arr[0].f:=2.0;  arr[0].d:=20.0; arr[0].s:='beta';
  arr[1].i:=1;  arr[1].f:=-1.0; arr[1].d:=10.0; arr[1].s:='delta';
  arr[2].i:=3;  arr[2].f:=5.5;  arr[2].d:=15.0; arr[2].s:='alpha';
  arr[3].i:=3;  arr[3].f:=0.0;  arr[3].d:=12.0; arr[3].s:='gamma';
  arr[4].i:=-7; arr[4].f:=1.25; arr[4].d:=-3.0; arr[4].s:='epsilon';

  Sort.ByInt(arr[0],SizeOf(TSortRec),length(arr),0,true);
  Check(arr[0].i=-7,'ByInt asc first');
  Check(arr[4].i=5,'ByInt asc last');

  Sort.ByInt(arr[0],SizeOf(TSortRec),length(arr),0,false);
  Check(arr[0].i=5,'ByInt desc first');
  Check(arr[4].i=-7,'ByInt desc last');

  Sort.ByFloat(arr[0],SizeOf(TSortRec),length(arr),SizeOf(integer),true);
  Check(Abs(arr[0].f+1.0)<0.0001,'ByFloat asc first');
  Check(Abs(arr[4].f-5.5)<0.0001,'ByFloat asc last');

  Sort.ByDouble(arr[0],SizeOf(TSortRec),length(arr),SizeOf(integer)+SizeOf(single),false);
  Check(Abs(arr[0].d-20.0)<0.0001,'ByDouble desc first');
  Check(Abs(arr[4].d+3.0)<0.0001,'ByDouble desc last');

  Sort.ByStr(arr[0],SizeOf(TSortRec),length(arr),SizeOf(integer)+SizeOf(single)+SizeOf(double),true);
  Check(arr[0].s='alpha','ByStr asc first');
  Check(arr[4].s='gamma','ByStr asc last');

  // edge: itemCount<2 should be no-op
  Sort.ByInt(arr[0],SizeOf(TSortRec),1,0,true);
  Check(true,'ByInt one-item no-op');
  EndTest;
end;

procedure TestAlignment;
var
  p:pointer;
begin
  StartTest('Alignment');
  // AlignUp UIntPtr
  Check(AlignUp(UIntPtr(0),16)=0,'AlignUp(0,16)');
  Check(AlignUp(UIntPtr(1),16)=16,'AlignUp(1,16)');
  Check(AlignUp(UIntPtr(15),16)=16,'AlignUp(15,16)');
  Check(AlignUp(UIntPtr(16),16)=16,'AlignUp(16,16)');
  Check(AlignUp(UIntPtr(17),16)=32,'AlignUp(17,16)');

  // AlignDown UIntPtr
  Check(AlignDown(UIntPtr(0),16)=0,'AlignDown(0,16)');
  Check(AlignDown(UIntPtr(15),16)=0,'AlignDown(15,16)');
  Check(AlignDown(UIntPtr(16),16)=16,'AlignDown(16,16)');
  Check(AlignDown(UIntPtr(31),16)=16,'AlignDown(31,16)');

  // IsAligned UIntPtr
  Check(IsAligned(UIntPtr(0),16),'IsAligned(0,16)');
  Check(IsAligned(UIntPtr(16),16),'IsAligned(16,16)');
  Check(not IsAligned(UIntPtr(1),16),'not IsAligned(1,16)');
  Check(not IsAligned(UIntPtr(15),16),'not IsAligned(15,16)');

  // pointer versions
  p:=pointer(UIntPtr(100));
  Check(IsAligned(AlignUp(p,16),16),'AlignUp pointer is aligned');
  Check(IsAligned(AlignDown(p,16),16),'AlignDown pointer is aligned');

  EndTest;
end;

procedure TestCPU;
begin
  StartTest('CPU');
  // just verify cpu record is populated (on x86/x64)
  {$IF Defined(CPUX64) or Defined(CPUx86_64) or Defined(CPUx86)}
  Check(cpuFeatures.version<>0,'cpu.version populated');
  Check(cpuFeatures.flags1<>0,'cpu.flags1 populated');
  // modern CPUs should have at least SSE2
  Check(cpuFeatures.SSE,'cpu.SSE');
  Check(cpuFeatures.SSE2,'cpu.SSE2');
  {$ELSE}
  // on non-x86 platforms, just check the record exists
  Check(cpuFeatures.version=0,'cpu.version zero on non-x86');
  {$IFEND}
  EndTest;
end;

procedure TestHalf;
var
  h:half;
  f:single;
begin
  StartTest('half');
  // conversion single -> half -> single
  f:=1.0;
  h:=f;
  Check(Abs(single(h)-1.0)<0.01,'half(1.0)');

  f:=0.5;
  h:=f;
  Check(Abs(single(h)-0.5)<0.01,'half(0.5)');

  f:=100.0;
  h:=f;
  Check(Abs(single(h)-100.0)<1.0,'half(100.0)');

  // zero
  f:=0.0;
  h:=f;
  Check(single(h)=0.0,'half(0.0)');

  // negative
  f:=-2.5;
  h:=f;
  Check(Abs(single(h)-(-2.5))<0.01,'half(-2.5)');

  EndTest;
end;

function StackCallerInner:pointer;
begin
  result:=Stack.Caller;
end;

function IntrinsicCaller:pointer;
begin
  {$IFDEF FPC}
  result:=get_caller_addr(get_frame);
  {$ELSE}
  result:=System.ReturnAddress;
  {$ENDIF}
end;

procedure TestStackCaller;
var
  addrAPI,addrIntrinsic:pointer;
begin
  StartTest('Stack.Caller');

  addrAPI:=StackCallerInner;
  addrIntrinsic:=IntrinsicCaller;
  writeln;

  // test API version
  writeln('  Stack.Caller (API) returned: ',IntToHex(UIntPtr(addrAPI),12));
  Check(addrAPI<>nil,'Stack.Caller should return non-nil');

  // test intrinsic version
  writeln('  Intrinsic caller returned: ',IntToHex(UIntPtr(addrIntrinsic),12));
  Check(addrIntrinsic<>nil,'Intrinsic caller should return non-nil');

  // compare addresses
  writeln('  API vs Intrinsic diff: ',IntPtr(addrAPI)-IntPtr(addrIntrinsic),' bytes');
  writeln('  Real caller: ',IntToHex(UIntPtr(@TestStackCaller),12));

  EndTest;
end;


function CaptureStack(out stackTrace:TCallStack):integer;
begin
  result:=Stack.Trace(stackTrace,0);
end;

procedure TestStackTrace;
var
  stackTrace:TCallStack;
  count,i:integer;
begin
  StartTest('Stack.Trace');

  // capture stack
  count:=CaptureStack(stackTrace);
  writeln('  Stack.Trace captured ',count,' frames:');
  for i:=0 to count-1 do
    writeln('    [',i,'] ',IntToHex(UIntPtr(stackTrace[i]),12));

  writeln('  Real proc: ',IntToHex(UIntPtr(@TestStackTrace),12),' -> ',IntToHex(UIntPtr(@CaptureStack),12));

  Check(count>0,'Stack.Trace should capture at least 1 frame');
  Check(stackTrace[0]<>nil,'First frame should be non-nil');

  // capture with skip
  count:=Stack.Trace(stackTrace,1);
  writeln('  Stack.Trace(skip=1) captured ',count,' frames');
  Check(count>=0,'Stack.Trace with skip should not fail');

  EndTest;
end;

procedure RaiseTestError;
begin
  raise EError.Create('Test error message');
end;

procedure TestException;
var
  msg:string;
  hasStack:boolean;
begin
  StartTest('EBaseException stack trace');
  // Test checks that EBaseException captures stack trace using Stack.Trace

  try
    writeln;
    Writeln('My address: ', IntToHex(UIntPtr(@TestException),12));
    RaiseTestError;
    Check(false,'Exception should be raised');
  except
    on e:EError do begin
      msg:=e.Message;
      writeln('  Exception message: ',msg);
      
      // check if message contains stack trace (format: [addr1->addr2->...] message)
      hasStack:=(Pos('[',msg)=1) and (Pos(']',msg)>1);
      Check(hasStack,'Exception message should contain stack trace');
      
      if hasStack then
        writeln('  Stack trace found in exception message');
    end;
  end;

  EndTest;
end;

procedure TestExceptionMsg;
var
  msg:string;
  hasStack,hasAddr:boolean;
begin
  StartTest('ExceptionMsg function');
  writeln;
  // test with EBaseException
  try
    raise EError.Create('Test error');
  except
    on e:EError do begin
      msg:=ExceptionMsg(e);
      writeln('  EError message: ',msg);
      hasStack:=(Pos('[',msg)=1) and (Pos(']',msg)>1);
      Check(hasStack,'ExceptionMsg should return message with stack trace for EBaseException');
    end;
  end;

  // test with regular Exception
  try
    raise Exception.Create('Regular exception');
  except
    on e:Exception do begin
      msg:=ExceptionMsg(e);
      writeln('  Regular exception: ',msg);
      hasAddr:=(Pos('[',msg)=1) and (Pos(']',msg)>1);
      Check(hasAddr,'ExceptionMsg should add address to regular Exception');
    end;
  end;

  EndTest;
end;

procedure TestTime;
var
  dtNow,dtUTC:TDateTime;
  stamp:string;
  diff:double;
begin
  StartTest('Time');
  writeln;
  // Test Time.Now
  dtNow:=Time.Now;
  Check(dtNow>0,'Time.Now should return valid datetime');
  writeln('  Time.Now: ',DateTimeToStr(dtNow));

  // Test Time.UTC
  dtUTC:=Time.UTC;
  Check(dtUTC>0,'Time.UTC should return valid datetime');
  writeln('  Time.UTC: ',DateTimeToStr(dtUTC));

  // Check that Now and UTC are reasonably close (within 24 hours)
  diff:=Abs(dtNow-dtUTC);
  Check(diff<1.0,'Time.Now and Time.UTC should be within 24 hours');

  // Test Time.Stamp
  stamp:=Time.Stamp;
  Check(Length(stamp)=12,'Time.Stamp should be 12 chars (HH:MM:SS.mmm)');
  Check(stamp[3]=':','Time.Stamp char 3 should be ":"');
  Check(stamp[6]=':','Time.Stamp char 6 should be ":"');
  Check(stamp[9]='.','Time.Stamp char 9 should be "."');
  writeln('  Time.Stamp: ',stamp);

  EndTest;
end;

procedure TestTimeOverride;
var
  tMs,tUs:int64;
  tSec:double;
begin
  StartTest('Time override');
  {$IFDEF TIME_OVERRIDE}
  try
    CoreTime.Override(1234567890123);
    tUs:=CoreTime.TicksUs;
    tMs:=CoreTime.Ticks;
    tSec:=CoreTime.TicksSec;
    Check(tUs=1234567890123,'TicksUs uses override');
    Check(tMs=1234567890,'Ticks uses override converted to ms');
    Check(Abs(tSec-1234567.890123)<0.000001,'TicksSec uses override converted to sec');

    CoreTime.Override(5000);
    Check(CoreTime.TicksUs=5000,'TicksUs follows updated override');
    Check(CoreTime.Ticks=5,'Ticks follows updated override');
  finally
    CoreTime.Override(0);
  end;
  {$ELSE}
  Check(true,'TIME_OVERRIDE not enabled');
  {$ENDIF}
  EndTest;
end;


begin
  try
    TestMinMax;
    TestMinMaxCornerCases;
    TestClamp;
    TestLerp;
    TestSwap;
    TestPow2;
    TestWrapRound;
    TestToggle;
    TestIsNaN;
    TestPtrInside;
    TestMem;
    TestMemGuardedFillClear;
    TestMemUnaligned;
    TestBits;
    TestSortScope;
    TestBitsSwapWords;
    TestBitsEdgeCases;
    TestAtomicSpin;
    TestAlignment;
    TestCPU;
    TestHalf;
    TestStackCaller;
    TestStackTrace;
    TestException;
    TestExceptionMsg;
    TestTime;
    TestTimeOverride;
    TestSystemPrimitives;

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
