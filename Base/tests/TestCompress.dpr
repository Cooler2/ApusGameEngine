{$APPTYPE CONSOLE}
{$R+}  // Range checking
{$Q+}  // Overflow checking
program TestCompress;
uses
  SysUtils,
  Apus.Core,
  Apus.Compress;

{$INCLUDE Test.inc}

function ByteArraysEqual(const a,b:ByteArray):boolean;
var
  i:integer;
begin
  result:=false;
  if length(a)<>length(b) then exit;
  for i:=0 to length(a)-1 do
    if a[i]<>b[i] then exit;
  result:=true;
end;


// ============================================================================
// RLE tests
// ============================================================================

procedure TestRLEBasic;
var
  src,pk,unpacked:ByteArray;
  i:integer;
begin
  StartTest('RLE.Basic');

  // empty buffer
  SetLength(src,0);
  pk:=RLE.Pack(@src,0,true);
  Check(RLE.CheckHeader(@pk[0],length(pk))=0,'empty header size=0');
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=0,'empty roundtrip');

  // single byte
  SetLength(src,1);
  src[0]:=$AB;
  pk:=RLE.Pack(@src[0],1,true);
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=1,'single len');
  Check(unpacked[0]=$AB,'single value');

  // repeating bytes (short run)
  SetLength(src,10);
  for i:=0 to 9 do src[i]:=$55;
  pk:=RLE.Pack(@src[0],10,true);
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=10,'repeat10 len');
  Check(ByteArraysEqual(unpacked,src),'repeat10 data');

  // random-ish data
  SetLength(src,256);
  for i:=0 to 255 do src[i]:=byte((i*37+13) and $FF);
  pk:=RLE.Pack(@src[0],256,true);
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=256,'random256 len');
  Check(ByteArraysEqual(unpacked,src),'random256 data');

  EndTest;
end;

procedure TestRLENoHeader;
var
  src,pk,unpacked:ByteArray;
  i:integer;
begin
  StartTest('RLE.NoHeader');

  // pack without header
  SetLength(src,20);
  for i:=0 to 19 do src[i]:=byte(i mod 5);
  pk:=RLE.Pack(@src[0],20,false);
  Check(RLE.CheckHeader(@pk[0],length(pk))=-1,'no header detected');
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=20,'noheader len');
  Check(ByteArraysEqual(unpacked,src),'noheader data');

  EndTest;
end;

procedure TestRLECheckHeader;
var
  buf:array[0..7] of byte;
  size:integer;
begin
  StartTest('RLE.CheckHeader');

  // valid header
  buf[0]:=byte('!');
  buf[1]:=byte('R');
  buf[2]:=byte('L');
  buf[3]:=byte('E');
  size:=12345;
  move(size,buf[4],4);
  Check(RLE.CheckHeader(@buf[0],8)=12345,'valid header');

  // invalid — too short
  Check(RLE.CheckHeader(@buf[0],7)=-1,'too short');

  // invalid — wrong magic
  buf[0]:=byte('X');
  Check(RLE.CheckHeader(@buf[0],8)=-1,'wrong magic');

  EndTest;
end;

procedure TestRLELongRun;
var
  src,pk,unpacked:ByteArray;
  i:integer;
begin
  StartTest('RLE.LongRun');

  // long run of repeating bytes (>193)
  SetLength(src,500);
  for i:=0 to 499 do src[i]:=$AA;
  pk:=RLE.Pack(@src[0],500,true);
  Check(length(pk)<500,'long run compressed');
  unpacked:=RLE.Unpack(@pk[0],length(pk));
  Check(length(unpacked)=500,'long run len');
  Check(ByteArraysEqual(unpacked,src),'long run data');

  EndTest;
end;

// ============================================================================
// LZ tests
// ============================================================================

procedure TestLZBasic;
var
  compressed,decompressed:String8;
begin
  StartTest('LZ.Basic');

  // empty string
  compressed:=LZ.Compress('');
  decompressed:=LZ.Decompress(compressed);
  Check(decompressed='','empty roundtrip');

  // short string
  compressed:=LZ.Compress('Hello');
  decompressed:=LZ.Decompress(compressed);
  Check(decompressed='Hello','short roundtrip');

  EndTest;
end;

procedure TestLZRepetitive;
var
  src,compressed,decompressed:String8;
  i:integer;
begin
  StartTest('LZ.Repetitive');

  // text with repeats — should actually compress
  src:='';
  for i:=1 to 50 do
    src:=src+'ABCDEF';
  compressed:=LZ.Compress(src);
  Check(length(compressed)<length(src),'repetitive compressed');
  decompressed:=LZ.Decompress(compressed);
  Check(decompressed=src,'repetitive roundtrip');

  EndTest;
end;

procedure TestLZRandom;
var
  src:String8;
  compressed,decompressed:String8;
  i:integer;
begin
  StartTest('LZ.Random');

  // pseudo-random data — roundtrip without loss
  SetLength(src,200);
  for i:=1 to 200 do
    src[i]:=AnsiChar((i*71+17) and $FF);
  compressed:=LZ.Compress(src);
  decompressed:=LZ.Decompress(compressed);
  Check(length(decompressed)=200,'random len');
  Check(decompressed=src,'random roundtrip');

  EndTest;
end;

// ============================================================================
// Patch tests
// ============================================================================

procedure TestPatchBasic;
var
  original,modified,restored:array[0..99] of byte;
  patchData:ByteArray;
  i:integer;
begin
  StartTest('Patch.Basic');

  // create original and slightly modified data
  for i:=0 to 99 do begin
    original[i]:=byte(i);
    modified[i]:=byte(i);
  end;
  modified[10]:=$FF;
  modified[50]:=$EE;
  modified[99]:=$DD;

  patchData:=Patch.Create(@original[0],@modified[0],100);
  Check(length(patchData)>0,'patch created');

  // apply patch to revert modified back to original
  move(modified[0],restored[0],100);
  Patch.Apply(@restored[0],100,@patchData[0],length(patchData));
  Check(Mem.Equal(restored[0],original[0],100),'patch roundtrip');

  EndTest;
end;

procedure TestPatchIdentical;
var
  data:array[0..63] of byte;
  patchData:ByteArray;
  i:integer;
begin
  StartTest('Patch.Identical');

  // identical blocks — patch should be minimal (just skip offsets)
  for i:=0 to 63 do data[i]:=byte(i*3);
  patchData:=Patch.Create(@data[0],@data[0],64);
  Check(length(patchData)<=4,'identical patch small: '+IntToStr(length(patchData)));

  EndTest;
end;

procedure TestPatchFullDiff;
var
  original,modified,restored:array[0..63] of byte;
  patchData:ByteArray;
  i:integer;
begin
  StartTest('Patch.FullDiff');

  // completely different data
  for i:=0 to 63 do begin
    original[i]:=byte(i);
    modified[i]:=byte(255-i);
  end;
  patchData:=Patch.Create(@original[0],@modified[0],64);
  Check(length(patchData)>=64,'full diff patch large enough');

  // apply patch to revert modified back to original
  move(modified[0],restored[0],64);
  Patch.Apply(@restored[0],64,@patchData[0],length(patchData));
  Check(Mem.Equal(restored[0],original[0],64),'fulldiff roundtrip');

  EndTest;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    TestRLEBasic;
    TestRLENoHeader;
    TestRLECheckHeader;
    TestRLELongRun;
    TestLZBasic;
    TestLZRepetitive;
    TestLZRandom;
    TestPatchBasic;
    TestPatchIdentical;
    TestPatchFullDiff;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' checks passed.')
    else
      writeln(testsFailed,' of ',testsTotal,' checks FAILED!');
  except
    on e:Exception do begin
      writeln('EXCEPTION: ',e.Message);
      inc(testsFailed);
    end;
  end;
  if testsFailed>0 then ExitCode:=1;

  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
