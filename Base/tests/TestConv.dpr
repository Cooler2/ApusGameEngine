{$APPTYPE CONSOLE}
program TestConv;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv;

{$INCLUDE Test.inc}

procedure TestToInt;
begin
  StartTest('Conv.ToInt');
  // decimal
  Check(Conv.ToInt('0')=0,'ToInt(0)');
  Check(Conv.ToInt('123')=123,'ToInt(123)');
  Check(Conv.ToInt('-456')=-456,'ToInt(-456)');
  Check(Conv.ToInt('  789')=789,'ToInt with spaces');
  Check(Conv.ToInt('12abc34')=1234,'ToInt ignores non-digits');
  // hex with $ prefix
  Check(Conv.ToInt('$FF')=255,'ToInt($FF)');
  Check(Conv.ToInt('$100')=256,'ToInt($100)');
  Check(Conv.ToInt('$DEADBEEF')=$DEADBEEF,'ToInt($DEADBEEF)');
  // large values
  Check(Conv.ToInt('9223372036854775807')=9223372036854775807,'ToInt max int64');
  EndTest;
end;

procedure TestHexToInt;
begin
  StartTest('Conv.HexToInt');
  Check(Conv.HexToInt('0')=0,'HexToInt(0)');
  Check(Conv.HexToInt('FF')=255,'HexToInt(FF)');
  Check(Conv.HexToInt('ff')=255,'HexToInt(ff) lowercase');
  Check(Conv.HexToInt('100')=256,'HexToInt(100)');
  Check(Conv.HexToInt('DEADBEEF')=$DEADBEEF,'HexToInt(DEADBEEF)');
  Check(Conv.HexToInt('-FF')=-255,'HexToInt(-FF)');
  Check(Conv.HexToInt('12 AB')=$12AB,'HexToInt with space');
  EndTest;
end;

procedure TestToFloat;
begin
  StartTest('Conv.ToFloat');
  Check(Abs(Conv.ToFloat('0')-0.0)<0.001,'ToFloat(0)');
  Check(Abs(Conv.ToFloat('123')-123.0)<0.001,'ToFloat(123)');
  Check(Abs(Conv.ToFloat('3.14')-3.14)<0.001,'ToFloat(3.14)');
  Check(Abs(Conv.ToFloat('3,14')-3.14)<0.001,'ToFloat(3,14) comma');
  Check(Abs(Conv.ToFloat('-2.5')-(-2.5))<0.001,'ToFloat(-2.5)');
  Check(Abs(Conv.ToFloat('+1.5')-1.5)<0.001,'ToFloat(+1.5)');
  Check(Abs(Conv.ToFloat('  42.0')-42.0)<0.001,'ToFloat with spaces');
  // exponent
  Check(Abs(Conv.ToFloat('1e3')-1000.0)<0.001,'ToFloat(1e3)');
  Check(Abs(Conv.ToFloat('2.5e2')-250.0)<0.001,'ToFloat(2.5e2)');
  Check(Abs(Conv.ToFloat('1e-3')-0.001)<0.0001,'ToFloat(1e-3)');
  Check(Abs(Conv.ToFloat('1E+2')-100.0)<0.001,'ToFloat(1E+2)');
  EndTest;
end;

procedure TestToBool;
begin
  StartTest('Conv.ToBool');
  Check(Conv.ToBool('true')=true,'ToBool(true)');
  Check(Conv.ToBool('True')=true,'ToBool(True)');
  Check(Conv.ToBool('yes')=true,'ToBool(yes)');
  Check(Conv.ToBool('Yes')=true,'ToBool(Yes)');
  Check(Conv.ToBool('1')=true,'ToBool(1)');
  Check(Conv.ToBool('+')=true,'ToBool(+)');
  Check(Conv.ToBool('false')=false,'ToBool(false)');
  Check(Conv.ToBool('no')=false,'ToBool(no)');
  Check(Conv.ToBool('0')=false,'ToBool(0)');
  Check(Conv.ToBool('')=false,'ToBool empty');
  EndTest;
end;

procedure TestToIp;
begin
  StartTest('Conv.ToIp');
  Check(Conv.ToIp('0.0.0.0')=0,'ToIp(0.0.0.0)');
  Check(Conv.ToIp('127.0.0.1')=$0100007F,'ToIp(127.0.0.1)');
  Check(Conv.ToIp('192.168.1.100')=$6401A8C0,'ToIp(192.168.1.100)');
  Check(Conv.ToIp('255.255.255.255')=$FFFFFFFF,'ToIp(255.255.255.255)');
  EndTest;
end;

procedure TestToHex;
begin
  StartTest('Conv.ToHex');
  Check(Conv.ToHex(0)='0','ToHex(0)');
  Check(Conv.ToHex(255)='FF','ToHex(255)');
  Check(Conv.ToHex(256)='100','ToHex(256)');
  Check(Conv.ToHex($DEADBEEF)='DEADBEEF','ToHex($DEADBEEF)');
  // with digits parameter
  Check(Conv.ToHex(15,2)='0F','ToHex(15,2)');
  Check(Conv.ToHex(255,4)='00FF','ToHex(255,4)');
  Check(Conv.ToHex(0,4)='0000','ToHex(0,4)');
  EndTest;
end;

procedure TestToStrPointer;
var
  p:pointer;
begin
  StartTest('Conv.ToStr(pointer)');
  p:=pointer($12345678);
  if CPU_BIT=64 then Check(Conv.ToStr(p)='000012345678','ToStr(pointer) 64-bit');
  if CPU_BIT=32 then Check(Conv.ToStr(p)='12345678','ToStr(pointer) 32-bit');
  p:=nil;
  if CPU_BIT=64 then Check(Conv.ToStr(p)='000000000000','ToStr(nil) 64-bit');
  if CPU_BIT=32 then Check(Conv.ToStr(p)='00000000','ToStr(nil) 32-bit');
  EndTest;
end;

procedure TestToIpFormat;
begin
  StartTest('Conv.ToIp(cardinal)');
  Check(Conv.ToIp(cardinal(0))='0.0.0.0','ToIp(0)');
  Check(Conv.ToIp(cardinal($0100007F))='127.0.0.1','ToIp localhost');
  Check(Conv.ToIp(cardinal($6401A8C0))='192.168.1.100','ToIp 192.168.1.100');
  Check(Conv.ToIp(cardinal($FFFFFFFF))='255.255.255.255','ToIp broadcast');
  EndTest;
end;

procedure TestToStrInt;
begin
  StartTest('Conv.ToStr(int)');
  // integer
  Check(Conv.ToStr(integer(0))='0','ToStr(0)');
  Check(Conv.ToStr(integer(123))='123','ToStr(123)');
  Check(Conv.ToStr(integer(-456))='-456','ToStr(-456)');
  Check(Conv.ToStr(integer(2147483647))='2147483647','ToStr(MaxInt)');
  Check(Conv.ToStr(integer(-2147483648))='-2147483648','ToStr(MinInt)');
  // cardinal
  Check(Conv.ToStr(cardinal(0))='0','ToStr cardinal(0)');
  Check(Conv.ToStr(cardinal(4294967295))='4294967295','ToStr(MaxCardinal)');
  // int64
  Check(Conv.ToStr(int64(0))='0','ToStr int64(0)');
  Check(Conv.ToStr(int64(9223372036854775807))='9223372036854775807','ToStr(MaxInt64)');
  Check(Conv.ToStr(int64(-9223372036854775808))='-9223372036854775808','ToStr(MinInt64)');
  // uint64
  Check(Conv.ToStr(uint64(0))='0','ToStr uint64(0)');
  Check(Conv.ToStr(uint64(18446744073709551615))='18446744073709551615','ToStr(MaxUInt64)');
  EndTest;
end;

procedure TestToStrBool;
begin
  StartTest('Conv.ToStr(bool)');
  Check(Conv.ToStr(true)='1','ToStr(true) short');
  Check(Conv.ToStr(false)='0','ToStr(false) short');
  Check(Conv.ToStr(true,false)='true','ToStr(true) long');
  Check(Conv.ToStr(false,false)='false','ToStr(false) long');
  EndTest;
end;

procedure TestFormatInt;
begin
  StartTest('Conv.FormatInt');
  Check(Conv.FormatInt(0)='0','FormatInt(0)');
  Check(Conv.FormatInt(123)='123','FormatInt(123)');
  Check(Conv.FormatInt(1234)='1 234','FormatInt(1234)');
  Check(Conv.FormatInt(1234567)='1 234 567','FormatInt(1234567)');
  Check(Conv.FormatInt(-1234567)='-1 234 567','FormatInt(-1234567)');
  EndTest;
end;

procedure TestFormatMoney;
begin
  StartTest('Conv.FormatMoney');
  Check(Conv.FormatMoney(0)='0.00','FormatMoney(0)');
  Check(Conv.FormatMoney(123.45)='123.45','FormatMoney(123.45)');
  Check(Conv.FormatMoney(1234.56)='1 234.56','FormatMoney(1234.56)');
  Check(Conv.FormatMoney(1234567.89)='1 234 567.89','FormatMoney(1234567.89)');
  Check(Conv.FormatMoney(99.9,1)='99.9','FormatMoney 1 digit');
  EndTest;
end;

procedure TestFormatSize;
begin
  StartTest('Conv.FormatSize');
  Check(Conv.FormatSize(0)='0b','FormatSize(0)');
  Check(Conv.FormatSize(500)='500b','FormatSize(500)');
  Check(Conv.FormatSize(1024)='1.00K','FormatSize(1024)');
  Check(Conv.FormatSize(10240)='10.0K','FormatSize(10240)');
  Check(Conv.FormatSize(102400)='100K','FormatSize(102400)');
  Check(Conv.FormatSize(1048576)='1.00M','FormatSize(1M)');
  Check(Conv.FormatSize(1073741824)='1.00G','FormatSize(1G)');
  Check(Conv.FormatSize(1099511627776)='1.00T','FormatSize(1T)');
  EndTest;
end;

procedure TestTimeToStr;
begin
  StartTest('Conv.TimeToStr');
  Check(Conv.TimeToStr(0)='0.0s','TimeToStr(0)');
  Check(Conv.TimeToStr(1500)='1.500s','TimeToStr(1500)');
  Check(Conv.TimeToStr(60000)='60.0s','TimeToStr(60000)');
  Check(Conv.TimeToStr(120000)='00:02:00','TimeToStr(2min)');
  Check(Conv.TimeToStr(3661000)='01:01:01','TimeToStr(1h1m1s)');
  Check(Conv.TimeToStr(86400000)='00:00:00','TimeToStr(exactly 1day)');
  Check(Pos('d',Conv.TimeToStr(86401000))>0,'TimeToStr(>1day) contains d');
  EndTest;
end;

procedure TestHexEncoding;
var
  buf:array[0..3] of byte;
  s:String8;
begin
  StartTest('Conv.EncodeHex/DecodeHex');
  // EncodeHex from pointer
  buf[0]:=$DE; buf[1]:=$AD; buf[2]:=$BE; buf[3]:=$EF;
  Check(Conv.EncodeHex(@buf,4)='DEADBEEF','EncodeHex buffer');
  // EncodeHex from string
  Check(Conv.EncodeHex('ABC')='414243','EncodeHex string');
  // DecodeHex to string
  s:=Conv.DecodeHex('414243');
  Check(s='ABC','DecodeHex to string');
  // DecodeHex to buffer
  Conv.DecodeHex('DEADBEEF',@buf);
  Check((buf[0]=$DE) and (buf[1]=$AD) and (buf[2]=$BE) and (buf[3]=$EF),'DecodeHex to buffer');
  // round-trip
  Check(Conv.DecodeHex(Conv.EncodeHex('Hello'))='Hello','Hex round-trip');
  EndTest;
end;

procedure TestDump;
var
  buf:array[0..2] of byte;
begin
  StartTest('Conv.HexDump/DecDump');
  buf[0]:=$12; buf[1]:=$AB; buf[2]:=$FF;
  Check(Conv.HexDump(@buf,3)='12 AB FF','HexDump');
  buf[0]:=1; buf[1]:=23; buf[2]:=255;
  Check(Conv.DecDump(@buf,3)='  1  23 255','DecDump');
  EndTest;
end;

procedure TestBase64;
var
  buf:array[0..15] of byte;
  size:integer;
  s:String8;
begin
  StartTest('Conv.ToBase64/FromBase64');
  // encode
  buf[0]:=0; buf[1]:=1; buf[2]:=2;
  s:=Conv.ToBase64(@buf,3);
  Check(length(s)=4,'ToBase64 length');
  // decode back
  size:=0;
  Conv.FromBase64(s,@buf,size);
  Check(size=3,'FromBase64 size');
  Check((buf[0]=0) and (buf[1]=1) and (buf[2]=2),'FromBase64 content');
  // round-trip various sizes
  buf[0]:=$AA; buf[1]:=$BB;
  s:=Conv.ToBase64(@buf,2);
  Conv.FromBase64(s,@buf,size);
  Check((size=2) and (buf[0]=$AA) and (buf[1]=$BB),'Base64 round-trip 2 bytes');
  buf[0]:=$CC;
  s:=Conv.ToBase64(@buf,1);
  Conv.FromBase64(s,@buf,size);
  Check((size=1) and (buf[0]=$CC),'Base64 round-trip 1 byte');
  EndTest;
end;

begin
  try
    TestToInt;
    TestHexToInt;
    TestToFloat;
    TestToBool;
    TestToIp;
    TestToHex;
    TestToStrPointer;
    TestToIpFormat;
    TestToStrInt;
    TestToStrBool;
    TestFormatInt;
    TestFormatMoney;
    TestFormatSize;
    TestTimeToStr;
    TestHexEncoding;
    TestDump;
    TestBase64;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Exception: ',e.Message);
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
