{$APPTYPE CONSOLE}
program TestCore;
uses
  SysUtils,
  Apus.Core;
  
{$INCLUDE Test.inc}

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
  Check(GetPow2(1)=1,'GetPow2(1)');
  Check(GetPow2(2)=2,'GetPow2(2)');
  Check(GetPow2(3)=4,'GetPow2(3)');
  Check(GetPow2(5)=8,'GetPow2(5)');
  Check(GetPow2(100)=128,'GetPow2(100)');
  Check(GetPow2(256)=256,'GetPow2(256)');
  Check(GetPow2(257)=512,'GetPow2(257)');

  Check(Pow2(0)=1,'Pow2(0)');
  Check(Pow2(1)=2,'Pow2(1)');
  Check(Pow2(8)=256,'Pow2(8)');
  Check(Pow2(10)=1024,'Pow2(10)');
  Check(Pow2(-1)=0,'Pow2(-1)');
  Check(Pow2(64)=0,'Pow2(64)');

  Check(Log2i(1)=0,'Log2i(1)');
  Check(Log2i(2)=1,'Log2i(2)');
  Check(Log2i(3)=2,'Log2i(3)');
  Check(Log2i(4)=2,'Log2i(4)');
  Check(Log2i(5)=3,'Log2i(5)');
  Check(Log2i(1024)=10,'Log2i(1024)');
  Check(Log2i(1025)=11,'Log2i(1025)');
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

begin
  try
    TestMinMax;
    TestClamp;
    TestLerp;
    TestSwap;
    TestPow2;
    TestToggle;
    TestIsNaN;
    TestPtrInside;
    TestMem;
    TestBits;
    TestAlignment;
    TestCPU;
    TestHalf;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
