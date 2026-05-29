{$APPTYPE CONSOLE}
program BenchStrings;
uses
  SysUtils,
  Apus.Core,
  Apus.Strings;

{$I test.inc}

const
  N_FAST = 10000000; // <5 ns/op: need 10M for precision
  N_DEF  = 1000000;  // 5-500 ns/op: default
  N_SLOW = 100000;   // >1 us/op: keep short

// ============================================================================
// String8 benchmarks
// ============================================================================

procedure BenchString8_Length;
var i:integer; s:String8; len:integer;
begin
  StartBench('String8.Length',N_FAST);
  s:='Hello World';
  for i:=1 to N_FAST do
    len:=s.Length;
  EndBench;
end;

procedure BenchString8_CharAt;
var i:integer; s:String8; ch:AnsiChar;
begin
  StartBench('String8.CharAt',N_FAST);
  s:='Hello World';
  for i:=1 to N_FAST do
    ch:=s.AnsiCharAt(5);
  EndBench;
end;

procedure BenchString8_IndexOf;
var i:integer; s:String8; idx:integer;
begin
  StartBench('String8.IndexOf(string)',N_DEF);
  s:='Hello World Hello';
  for i:=1 to N_DEF do
    idx:=s.IndexOf('World');
  EndBench;
end;

procedure BenchString8_Contains;
var i:integer; s:String8; found:boolean;
begin
  StartBench('String8.Contains',N_DEF);
  s:='Hello World Hello';
  for i:=1 to N_DEF do
    found:=s.Contains('World');
  EndBench;
end;

procedure BenchString8_Substr;
var i:integer; s:String8; sub:String8;
begin
  StartBench('String8.Substr',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    sub:=s.Substr(7);
  EndBench;
end;

procedure BenchString8_Left;
var i:integer; s:String8; sub:String8;
begin
  StartBench('String8.Left',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    sub:=s.Left(5);
  EndBench;
end;

procedure BenchString8_ToUpper;
var i:integer; s:String8; upper:String8;
begin
  StartBench('String8.ToUpper',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    upper:=s.ToUpper;
  EndBench;
end;

procedure BenchString8_ToLower;
var i:integer; s:String8; lower:String8;
begin
  StartBench('String8.ToLower',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    lower:=s.ToLower;
  EndBench;
end;

procedure BenchString8_Trim;
var i:integer; s:String8; trimmed:String8;
begin
  StartBench('String8.Trim',N_DEF);
  s:='  Hello World  ';
  for i:=1 to N_DEF do
    trimmed:=s.Trim;
  EndBench;
end;

procedure BenchString8_Trim_Long;
var i:integer; s:String8; trimmed:String8;
begin
  StartBench('String8.Trim(long ASCII)',N_SLOW);
  s:=String8(StringOfChar(' ',256)+StringOfChar('a',4096)+StringOfChar(' ',256));
  for i:=1 to N_SLOW do
    trimmed:=s.Trim;
  EndBench;
end;

procedure BenchString8_Compare_Long;
var i,cmp:integer; s1,s2:String8;
begin
  StartBench('String8.Compare(long,ignoreCase)',N_SLOW);
  s1:=String8(StringOfChar('a',4096)+'X');
  s2:=String8(StringOfChar('A',4096)+'y');
  for i:=1 to N_SLOW do
    cmp:=s1.Compare(s2,true);
  EndBench;
end;

procedure BenchString8_Same_Long;
var i:integer; s1,s2:String8; same:boolean;
begin
  StartBench('String8.Same(long)',N_SLOW);
  s1:=String8(StringOfChar('a',4096)+'X');
  s2:=String8(StringOfChar('A',4096)+'x');
  for i:=1 to N_SLOW do
    same:=s1.Same(s2);
  EndBench;
end;

procedure BenchString8_PadLeft;
var i:integer; s:String8; padded:String8;
begin
  StartBench('String8.PadLeft',N_DEF);
  s:='Hi';
  for i:=1 to N_DEF do
    padded:=s.PadLeft(10);
  EndBench;
end;

procedure BenchString8_Insert;
var i:integer; s:String8; result:String8;
begin
  StartBench('String8.Insert',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    result:=s.Insert('Beautiful ',7);
  EndBench;
end;

procedure BenchString8_Remove;
var i:integer; s:String8; result:String8;
begin
  StartBench('String8.Remove',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    result:=s.Remove(6);
  EndBench;
end;

procedure BenchString8_Replace;
var i:integer; s:String8; result:String8;
begin
  StartBench('String8.Replace',N_DEF);
  s:='Hello World';
  for i:=1 to N_DEF do
    result:=s.Replace('World','Pascal');
  EndBench;
end;

procedure BenchString8_ReplaceAll;
var i:integer; s:String8; result:String8;
begin
  StartBench('String8.ReplaceAll',N_DEF);
  s:='one two one two';
  for i:=1 to N_DEF do
    result:=s.ReplaceAll('one','1');
  EndBench;
end;

procedure BenchString8_ReplaceAll_Many;
var i,j:integer; s,result:String8;
begin
  StartBench('String8.ReplaceAll(many)',N_SLOW);
  s:='';
  for j:=1 to 512 do
    s:=s+'one two ';
  for i:=1 to N_SLOW do
    result:=s.ReplaceAll('one','1');
  EndBench;
end;

procedure BenchString8_Split;
var i:integer; s:String8; arr:Strings8;
begin
  StartBench('String8.Split',N_DEF);
  s:='a,b,c,d,e';
  for i:=1 to N_DEF do
    arr:=s.Split(',');
  EndBench;
end;

procedure BenchString8_Join;
var i:integer; arr:Strings8; result:String8;
begin
  StartBench('String8.Join',N_DEF);
  SetLength(arr,5);
  arr[0]:='a'; arr[1]:='b'; arr[2]:='c'; arr[3]:='d'; arr[4]:='e';
  for i:=1 to N_DEF do
    result:=String8.Join(arr,',');
  EndBench;
end;

procedure BenchString8_Quote;
var i:integer; s:String8; quoted:String8;
begin
  StartBench('String8.Quote',N_DEF);
  s:='Hello';
  for i:=1 to N_DEF do
    quoted:=s.Quote;
  EndBench;
end;

procedure BenchString8_Escape;
var i:integer; s:String8; escaped:String8;
begin
  StartBench('String8.Escape',N_SLOW);
  s:='Line1'#10'Line2'#9'Tab';
  for i:=1 to N_SLOW do
    escaped:=s.Escape;
  EndBench;
end;

procedure BenchString8_UrlEncode;
var i:integer; s:String8; encoded:String8;
begin
  StartBench('String8.UrlEncode',N_SLOW);
  s:='Hello World & Co.';
  for i:=1 to N_SLOW do
    encoded:=s.UrlEncode;
  EndBench;
end;

procedure BenchString8_HtmlEscape;
var i:integer; s:String8; escaped:String8;
begin
  StartBench('String8.HtmlEscape',N_SLOW);
  s:='<div class="test">&</div>';
  for i:=1 to N_SLOW do
    escaped:=s.HtmlEscape;
  EndBench;
end;

procedure BenchUTF8_Format_Simple;
var i:integer; s:String8;
begin
  StartBench('UTF8.Format(%d+%d=%d)',N_SLOW);
  for i:=1 to N_SLOW do
    s:=UTF8.Format('%d + %d = %d',[1,2,3]);
  EndBench;
end;

procedure BenchUTF8_Format_Mixed;
var i:integer; s:String8;
begin
  StartBench('UTF8.Format(mixed)',N_SLOW);
  for i:=1 to N_SLOW do
    s:=UTF8.Format('Hello %s, age %d, pi=%.2f',['World',42,3.14159]);
  EndBench;
end;

procedure BenchSysUtils_Format_Simple;
var i:integer; s:string;
begin
  StartBench('SysUtils.Format(%d+%d=%d)',N_SLOW);
  for i:=1 to N_SLOW do
    s:=SysUtils.Format('%d + %d = %d',[1,2,3]);
  EndBench;
end;

procedure BenchSysUtils_Format_Mixed;
var i:integer; s:string;
begin
  StartBench('SysUtils.Format(mixed)',N_SLOW);
  for i:=1 to N_SLOW do
    s:=SysUtils.Format('Hello %s, age %d, pi=%.2f',['World',42,3.14159]);
  EndBench;
end;

// ============================================================================
// String32 benchmarks
// ============================================================================

procedure BenchString32_Length;
var i:integer; s:String32; len:integer;
begin
  StartBench('String32.Length',N_FAST);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_FAST do
    len:=s.Length;
  EndBench;
end;

procedure BenchString32_CharAt;
var i:integer; s:String32; ch:cardinal;
begin
  StartBench('String32.CharAt',N_FAST);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_FAST do
    ch:=s.CharAt(5);
  EndBench;
end;

procedure BenchString32_IndexOf;
var i:integer; s,sub:String32; idx:integer;
begin
  StartBench('String32.IndexOf',N_DEF);
  s:=UTF8.Decode('Hello World Hello');
  sub:=UTF8.Decode('World');
  for i:=1 to N_DEF do
    idx:=s.IndexOf(sub);
  EndBench;
end;

procedure BenchString32_Contains;
var i:integer; s,sub:String32; found:boolean;
begin
  StartBench('String32.Contains',N_DEF);
  s:=UTF8.Decode('Hello World Hello');
  sub:=UTF8.Decode('World');
  for i:=1 to N_DEF do
    found:=s.Contains(sub);
  EndBench;
end;

procedure BenchString32_Substring;
var i:integer; s,sub:String32;
begin
  StartBench('String32.Substring',N_DEF);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_DEF do
    sub:=s.Substring(6);
  EndBench;
end;

procedure BenchString32_Left;
var i:integer; s,sub:String32;
begin
  StartBench('String32.Left',N_DEF);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_DEF do
    sub:=s.Left(5);
  EndBench;
end;

procedure BenchString32_ToUpper;
var i:integer; s,upper:String32;
begin
  StartBench('String32.ToUpper',N_DEF);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_DEF do
    upper:=s.ToUpper;
  EndBench;
end;

procedure BenchString32_ToLower;
var i:integer; s,lower:String32;
begin
  StartBench('String32.ToLower',N_DEF);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_DEF do
    lower:=s.ToLower;
  EndBench;
end;

procedure BenchString32_Trim;
var i:integer; s,trimmed:String32;
begin
  StartBench('String32.Trim',N_DEF);
  s:=UTF8.Decode('  Hello World  ');
  for i:=1 to N_DEF do
    trimmed:=s.Trim;
  EndBench;
end;

procedure BenchString32_PadLeft;
var i:integer; s,padded:String32;
begin
  StartBench('String32.PadLeft',N_DEF);
  s:=UTF8.Decode('Hi');
  for i:=1 to N_DEF do
    padded:=s.PadLeft(10);
  EndBench;
end;

procedure BenchString32_Insert;
var i:integer; s,ins,result:String32;
begin
  StartBench('String32.Insert',N_DEF);
  s:=UTF8.Decode('Hello World');
  ins:=UTF8.Decode('Beautiful ');
  for i:=1 to N_DEF do
    result:=s.Insert(ins,6);
  EndBench;
end;

procedure BenchString32_Remove;
var i:integer; s,result:String32;
begin
  StartBench('String32.Remove',N_DEF);
  s:=UTF8.Decode('Hello World');
  for i:=1 to N_DEF do
    result:=s.Remove(5);
  EndBench;
end;

procedure BenchString32_Replace;
var i:integer; s,sub,repl,result:String32;
begin
  StartBench('String32.Replace',N_DEF);
  s:=UTF8.Decode('Hello World');
  sub:=UTF8.Decode('World');
  repl:=UTF8.Decode('Pascal');
  for i:=1 to N_DEF do
    result:=s.Replace(sub,repl);
  EndBench;
end;

procedure BenchString32_ReplaceAll;
var i:integer; s,sub,repl,result:String32;
begin
  StartBench('String32.ReplaceAll',N_DEF);
  s:=UTF8.Decode('one two one two');
  sub:=UTF8.Decode('one');
  repl:=UTF8.Decode('1');
  for i:=1 to N_DEF do
    result:=s.ReplaceAll(sub,repl);
  EndBench;
end;

procedure BenchString32_Split;
var i:integer; s:String32; arr:Strings32;
begin
  StartBench('String32.Split',N_DEF);
  s:=UTF8.Decode('a,b,c,d,e');
  for i:=1 to N_DEF do
    arr:=s.Split(ord(','));
  EndBench;
end;

procedure BenchString32_Join;
var i:integer; arr:Strings32; delim,result:String32;
begin
  StartBench('String32.Join',N_DEF);
  SetLength(arr,5);
  arr[0]:=UTF8.Decode('a');
  arr[1]:=UTF8.Decode('b');
  arr[2]:=UTF8.Decode('c');
  arr[3]:=UTF8.Decode('d');
  arr[4]:=UTF8.Decode('e');
  delim:=UTF8.Decode(',');
  for i:=1 to N_DEF do
    result:=String32.Join(arr,delim);
  EndBench;
end;

// ============================================================================
// UTF8 benchmarks
// ============================================================================

procedure BenchUTF8_Decode;
var i:integer; s8:String8; s32:String32;
begin
  StartBench('UTF8.Decode',N_DEF);
  s8:='Hello World Привет 日本語';
  for i:=1 to N_DEF do
    s32:=UTF8.Decode(s8);
  EndBench;
end;

procedure BenchUTF8_Encode;
var i:integer; s32:String32; s8:String8;
begin
  StartBench('UTF8.Encode',N_DEF);
  s32:=UTF8.Decode('Hello World Привет 日本語');
  for i:=1 to N_DEF do
    s8:=UTF8.Encode(s32);
  EndBench;
end;

procedure BenchUTF8_CharCount;
var i:integer; s8:String8; count:integer;
begin
  StartBench('UTF8.CharCount',N_DEF);
  s8:='Hello World Привет 日本語';
  for i:=1 to N_DEF do
    count:=UTF8.CharCount(s8);
  EndBench;
end;

procedure BenchUTF8_IsValid;
var i:integer; s8:String8; valid:boolean;
begin
  StartBench('UTF8.IsValid',N_DEF);
  s8:='Hello World Привет 日本語';
  for i:=1 to N_DEF do
    valid:=UTF8.IsValid(s8);
  EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('strings',N_DEF);
    BenchWriteln;

  BenchWriteln('--- String8Helper ---');
  BenchString8_Length;
  BenchString8_CharAt;
  BenchString8_IndexOf;
  BenchString8_Contains;
  BenchString8_Substr;
  BenchString8_Left;
  BenchString8_ToUpper;
  BenchString8_ToLower;
  BenchString8_Trim;
  BenchString8_Trim_Long;
  BenchString8_Compare_Long;
  BenchString8_Same_Long;
  BenchString8_PadLeft;
  BenchString8_Insert;
  BenchString8_Remove;
  BenchString8_Replace;
  BenchString8_ReplaceAll;
  BenchString8_ReplaceAll_Many;
  BenchString8_Split;
  BenchString8_Join;
  BenchString8_Quote;
  BenchString8_Escape;
  BenchString8_UrlEncode;
  BenchString8_HtmlEscape;
  BenchWriteln;

  BenchWriteln('--- Format ---');
  BenchUTF8_Format_Simple;
  BenchUTF8_Format_Mixed;
  BenchSysUtils_Format_Simple;
  BenchSysUtils_Format_Mixed;
  BenchWriteln;

  BenchWriteln('--- String32Helper ---');
  BenchString32_Length;
  BenchString32_CharAt;
  BenchString32_IndexOf;
  BenchString32_Contains;
  BenchString32_Substring;
  BenchString32_Left;
  BenchString32_ToUpper;
  BenchString32_ToLower;
  BenchString32_Trim;
  BenchString32_PadLeft;
  BenchString32_Insert;
  BenchString32_Remove;
  BenchString32_Replace;
  BenchString32_ReplaceAll;
  BenchString32_Split;
  BenchString32_Join;
  BenchWriteln;

  BenchWriteln('--- UTF8 ---');
  BenchUTF8_Decode;
  BenchUTF8_Encode;
  BenchUTF8_CharCount;
  BenchUTF8_IsValid;
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
