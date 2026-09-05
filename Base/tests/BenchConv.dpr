{$APPTYPE CONSOLE}
program BenchConv;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv;

{$I test.inc}

const
  N_FAST = 10000000;
  N_DEF  = 1000000;

// ============================================================================
// Parsing
// ============================================================================

procedure BenchConv_ToInt;
var i:integer; r:int64;
begin
  StartBench('Conv.ToInt',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToInt('1234567');
  EndBench;
end;

procedure BenchConv_ToIntHex;
var i:integer; r:int64;
begin
  StartBench('Conv.ToInt hex',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToInt('$DEADBEEF');
  EndBench;
end;

procedure BenchConv_HexToInt;
var i:integer; r:int64;
begin
  StartBench('Conv.HexToInt',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.HexToInt('DEADBEEF');
  EndBench;
end;

procedure BenchConv_ToFloat;
var i:integer; r:double;
begin
  StartBench('Conv.ToFloat',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToFloat('3.14159');
  EndBench;
end;

procedure BenchConv_ToBool;
var i:integer; r:boolean;
begin
  StartBench('Conv.ToBool',N_FAST);
  for i:=1 to N_FAST do
    r:=Conv.ToBool('true');
  EndBench;
end;

procedure BenchConv_ToIp;
var i:integer; r:cardinal;
begin
  StartBench('Conv.ToIp (parse)',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToIp('192.168.1.100');
  EndBench;
end;

// ============================================================================
// Formatting
// ============================================================================

procedure BenchConv_ToStr_Int;
var i:integer; r:String8;
begin
  StartBench('Conv.ToStr(int)',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToStr(1234567);
  EndBench;
end;

procedure BenchConv_ToStr_Int64;
var i:integer; r:String8;
begin
  StartBench('Conv.ToStr(int64)',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToStr(int64(1234567890123));
  EndBench;
end;

procedure BenchConv_ToStr_Bool;
var i:integer; r:String8;
begin
  StartBench('Conv.ToStr(bool)',N_FAST);
  for i:=1 to N_FAST do
    r:=Conv.ToStr(true);
  EndBench;
end;

procedure BenchConv_ToHex;
var i:integer; r:String8;
begin
  StartBench('Conv.ToHex',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToHex($DEADBEEF,8);
  EndBench;
end;

procedure BenchConv_IpToStr;
var i:integer; r:String8;
begin
  StartBench('Conv.FormatIp',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.FormatIp($C0A80164);
  EndBench;
end;

procedure BenchConv_FormatInt;
var i:integer; r:string;
begin
  StartBench('Conv.FormatInt',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.FormatInt(1234567);
  EndBench;
end;

procedure BenchConv_FormatMoney;
var i:integer; r:string;
begin
  StartBench('Conv.FormatMoney',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.FormatMoney(1234567.89);
  EndBench;
end;

procedure BenchConv_FormatSize;
var i:integer; r:string;
begin
  StartBench('Conv.FormatSize',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.FormatSize(1234567890);
  EndBench;
end;

// ============================================================================
// Hex encoding
// ============================================================================

procedure BenchConv_EncodeHex;
var i:integer; data:String8; r:String8;
begin
  StartBench('Conv.EncodeHex 16B',N_DEF);
  data:='0123456789ABCDEF';
  for i:=1 to N_DEF do
    r:=Conv.EncodeHex(data);
  EndBench;
end;

procedure BenchConv_DecodeHex;
var i:integer; hex:String8; r:String8;
begin
  StartBench('Conv.DecodeHex 32ch',N_DEF);
  hex:='30313233343536373839414243444546';
  for i:=1 to N_DEF do
    r:=Conv.DecodeHex(hex);
  EndBench;
end;

procedure BenchConv_HexDump;
var i:integer; buf:array[0..15] of byte; r:String8;
begin
  StartBench('Conv.HexDump 16B',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.HexDump(@buf,16);
  EndBench;
end;

// ============================================================================
// Base64
// ============================================================================

procedure BenchConv_ToBase64;
var i:integer; buf:array[0..63] of byte; r:String8;
begin
  StartBench('Conv.ToBase64 64B',N_DEF);
  for i:=1 to N_DEF do
    r:=Conv.ToBase64(@buf,64);
  EndBench;
end;

procedure BenchConv_FromBase64;
var i:integer; b64:String8; buf:array[0..63] of byte; size:integer;
begin
  b64:=Conv.ToBase64(@buf,64);
  StartBench('Conv.FromBase64 64B',N_DEF);
  for i:=1 to N_DEF do begin
    size:=64;
    Conv.FromBase64(b64,@buf,size);
  end;
  EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('conv',N_DEF);
    BenchWriteln;

  BenchWriteln('--- Parsing ---');
  BenchConv_ToInt;
  BenchConv_ToIntHex;
  BenchConv_HexToInt;
  BenchConv_ToFloat;
  BenchConv_ToBool;
  BenchConv_ToIp;
  BenchWriteln;

  BenchWriteln('--- Formatting ---');
  BenchConv_ToStr_Int;
  BenchConv_ToStr_Int64;
  BenchConv_ToStr_Bool;
  BenchConv_ToHex;
  BenchConv_IpToStr;
  BenchConv_FormatInt;
  BenchConv_FormatMoney;
  BenchConv_FormatSize;
  BenchWriteln;

  BenchWriteln('--- Hex encoding ---');
  BenchConv_EncodeHex;
  BenchConv_DecodeHex;
  BenchConv_HexDump;
  BenchWriteln;

  BenchWriteln('--- Base64 ---');
  BenchConv_ToBase64;
  BenchConv_FromBase64;
  BenchWriteln;

  CloseBenchLog;
  writeln('=== BENCHMARK DONE ===');
  except
    on e:Exception do begin
      writeln;
      writeln('BENCHMARK FAILED: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press ENTER to exit');
    readln;
  end;
end.
