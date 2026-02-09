{$APPTYPE CONSOLE}
program TestStrings;
uses
  SysUtils,
  Apus.Core,
  Apus.Strings;
  
{$INCLUDE Test.inc}

// ============================================================================
// String8Helper tests
// ============================================================================

procedure TestString8Basic;
var s:String8;
begin
  StartTest('String8.Basic');
  s:='Hello';
  Check(s.Length=5,'Length');
  Check(not s.IsEmpty,'not IsEmpty');
  s:='';
  Check(s.Length=0,'empty Length');
  Check(s.IsEmpty,'IsEmpty');
  EndTest;
end;

procedure TestString8CharAccess;
var s:String8;
begin
  StartTest('String8.CharAccess');
  s:='ABCDE';
  Check(s.AnsiCharAt(1)='A','AnsiCharAt(1)');
  Check(s.AnsiCharAt(3)='C','AnsiCharAt(3)');
  Check(s.AnsiCharAt(5)='E','AnsiCharAt(5)');
  Check(s.AnsiCharAt(0)=#0,'AnsiCharAt(0) out of bounds');
  Check(s.AnsiCharAt(6)=#0,'AnsiCharAt(6) out of bounds');
  Check(s.LastAnsiChar='E','LastAnsiChar');
  s:='';
  Check(s.LastAnsiChar=#0,'empty LastAnsiChar');
  EndTest;
end;

procedure TestString8Substring;
var s:String8;
begin
  StartTest('String8.Substring');
  s:='Hello World';
  Check(s.Substr(1,5)='Hello','Substr(1,5)');
  Check(s.Substr(7)='World','Substr(7)');
  Check(s.Left(5)='Hello','Left(5)');
  Check(s.Right(5)='World','Right(5)');
  Check(s.Left(0)='','Left(0)');
  Check(s.Right(0)='','Right(0)');
  EndTest;
end;

procedure TestString8Search;
var s:String8;
begin
  StartTest('String8.Search');
  s:='Hello World Hello';
  // IndexOf string
  Check(s.IndexOf('Hello')=1,'IndexOf(Hello)');
  Check(s.IndexOf('World')=7,'IndexOf(World)');
  Check(s.IndexOf('NotFound')=0,'IndexOf not found');
  Check(s.IndexOf('Hello',2)=13,'IndexOf(Hello,2)');
  // IndexOf char
  Check(s.IndexOf('o')=5,'IndexOf(o)');
  Check(s.IndexOf('o',6)=8,'IndexOf(o,6)');
  Check(s.IndexOf('z')=0,'IndexOf(z) not found');
  // LastIndexOf
  Check(s.LastIndexOf('Hello')=13,'LastIndexOf(Hello)');
  Check(s.LastIndexOf('o')=17,'LastIndexOf(o)');
  // Contains
  Check(s.Contains('World'),'Contains(World)');
  Check(not s.Contains('Foo'),'not Contains(Foo)');
  Check(s.Contains('o'),'Contains(o)');
  EndTest;
end;

procedure TestString8StartEnd;
var s:String8;
begin
  StartTest('String8.StartsWith/EndsWith');
  s:='Hello World';
  Check(s.StartsWith('Hello'),'StartsWith(Hello)');
  Check(s.StartsWith('H'),'StartsWith(H)');
  Check(not s.StartsWith('World'),'not StartsWith(World)');
  Check(s.EndsWith('World'),'EndsWith(World)');
  Check(s.EndsWith('d'),'EndsWith(d)');
  Check(not s.EndsWith('Hello'),'not EndsWith(Hello)');
  Check(s.StartsWith(''),'StartsWith empty');
  Check(s.EndsWith(''),'EndsWith empty');
  EndTest;
end;

procedure TestString8Compare;
var s:String8;
begin
  StartTest('String8.Compare');
  s:='Hello';
  Check(s.CompareTo('Hello')=0,'CompareTo equal');
  Check(s.CompareTo('Hallo')<>0,'CompareTo different');
  Check(s.CompareTo('Apple')>0,'CompareTo greater');
  Check(s.CompareTo('World')<0,'CompareTo less');
  Check(s.Equals('Hello'),'Equals');
  Check(not s.Equals('hello'),'not Equals case');
  Check(s.EqualsText('hello'),'EqualsText');
  Check(s.EqualsText('HELLO'),'EqualsText upper');
  Check(s.CompareText('HELLO')=0,'CompareText');
  EndTest;
end;

procedure TestString8Case;
var s:String8;
begin
  StartTest('String8.Case');
  s:='Hello World';
  Check(s.ToUpper='HELLO WORLD','ToUpper');
  Check(s.ToLower='hello world','ToLower');
  s:='ABC123xyz';
  Check(s.ToUpper='ABC123XYZ','ToUpper mixed');
  Check(s.ToLower='abc123xyz','ToLower mixed');
  EndTest;
end;

procedure TestString8Trim;
var s:String8;
begin
  StartTest('String8.Trim');
  s:='  Hello  ';
  Check(s.Trim='Hello','Trim');
  Check(s.TrimLeft='Hello  ','TrimLeft');
  Check(s.TrimRight='  Hello','TrimRight');
  s:='NoSpaces';
  Check(s.Trim='NoSpaces','Trim no change');
  s:='';
  Check(s.Trim='','Trim empty');
  EndTest;
end;

procedure TestString8Pad;
var s:String8;
begin
  StartTest('String8.Pad');
  s:='Hi';
  Check(s.PadLeft(5)='   Hi','PadLeft(5)');
  Check(s.PadRight(5)='Hi   ','PadRight(5)');
  Check(s.PadLeft(5,'0')='000Hi','PadLeft(5,0)');
  Check(s.PadRight(5,'0')='Hi000','PadRight(5,0)');
  Check(s.PadLeft(2)='Hi','PadLeft no change');
  Check(s.PadLeft(1)='Hi','PadLeft smaller');
  EndTest;
end;

procedure TestString8Modify;
var s:String8;
begin
  StartTest('String8.Modify');
  s:='Hello World';
  Check(s.Insert('Beautiful ',7)='Hello Beautiful World','Insert');
  Check(s.Remove(6)='Hello','Remove(6)');
  Check(s.Remove(7,5)='Hello ','Remove(7,5)');
  Check(s.Replace('World','Pascal')='Hello Pascal','Replace');
  s:='one two one two';
  Check(s.Replace('one','1')='1 two one two','Replace first');
  Check(s.ReplaceAll('one','1')='1 two 1 two','ReplaceAll');
  EndTest;
end;

procedure TestString8Split;
var s:String8; arr:Strings8;
begin
  StartTest('String8.Split');
  s:='a,b,c';
  arr:=s.Split(',');
  Check(length(arr)=3,'Split length');
  Check(arr[0]='a','Split[0]');
  Check(arr[1]='b','Split[1]');
  Check(arr[2]='c','Split[2]');
  // with delimiters string
  s:='a;b,c';
  arr:=s.Split(',;');
  Check(length(arr)=3,'Split multi delim');
  // with quote char
  s:='a,"b,c",d';
  arr:=s.Split(',','"');
  Check(length(arr)=3,'Split quoted length');
  Check(arr[1]='"b,c"','Split quoted[1]');
  // Join
  SetLength(arr,3);
  arr[0]:='x'; arr[1]:='y'; arr[2]:='z';
  Check(String8.Join(arr,'-')='x-y-z','Join');
  EndTest;
end;

procedure TestString8Quote;
var s:String8;
begin
  StartTest('String8.Quote');
  s:='Hello';
  Check(s.Quote='"Hello"','Quote default');
  Check(s.Quote('''')='''Hello''','Quote single');
  s:='"Quoted"';
  Check(s.Unquote='Quoted','Unquote');
  s:='''Single''';
  Check(s.Unquote='Single','Unquote single');
  s:='NoQuotes';
  Check(s.Unquote='NoQuotes','Unquote none');
  EndTest;
end;

procedure TestString8Escape;
var s:String8;
begin
  StartTest('String8.Escape');
  s:='Line1'#10'Line2'#9'Tab';
  Check(s.Escape='Line1\nLine2\tTab','Escape');
  s:='Path\\File';
  Check(s.Escape='Path\\\\File','Escape backslash');
  s:='Line1\nLine2\tTab';
  Check(s.Unescape='Line1'#10'Line2'#9'Tab','Unescape');
  s:='Path\\File';
  Check(s.Unescape='Path\File','Unescape backslash');
  EndTest;
end;

procedure TestString8Url;
var s:String8;
begin
  StartTest('String8.Url');
  s:='Hello World';
  Check(s.UrlEncode='Hello%20World','UrlEncode space');
  s:='a=1&b=2';
  Check(s.UrlEncode='a%3D1%26b%3D2','UrlEncode special');
  s:='Hello%20World';
  Check(s.UrlDecode='Hello World','UrlDecode');
  s:='a+b';
  Check(s.UrlDecode='a b','UrlDecode plus');
  // round-trip
  s:='Test/Path?query=value&x=1';
  Check(s.UrlEncode.UrlDecode=s,'Url round-trip');
  EndTest;
end;

procedure TestString8Html;
var s:String8;
begin
  StartTest('String8.Html');
  s:='<div class="test">&</div>';
  Check(s.HtmlEscape='&lt;div class=&quot;test&quot;&gt;&amp;&lt;/div&gt;','HtmlEscape');
  s:='&lt;tag&gt;';
  Check(s.HtmlUnescape='<tag>','HtmlUnescape');
  s:='&amp;&quot;&#39;';
  Check(s.HtmlUnescape='&"''','HtmlUnescape entities');
  EndTest;
end;

procedure TestString8Utility;
var s:String8;
begin
  StartTest('String8.Utility');
  s:='abracadabra';
  Check(s.CountChar('a')=5,'CountChar');
  Check(s.CountChar('z')=0,'CountChar zero');
  s:='Hello';
  Check(s.Reverse='olleH','Reverse');
  Check(s.Duplicate(3)='HelloHelloHello','Duplicate');
  s:='A'#0'B'#10'C';
  Check(s.Printable='A.B.C','Printable');
  s:='[start]content[end]';
  Check(s.Extract('[start]','[end]')='content','Extract');
  Check(s.Extract('[x]','[y]')='','Extract not found');
  EndTest;
end;

procedure TestString8Convert;
var s:String8;
begin
  StartTest('String8.Convert');
  s:='123';
  Check(s.ToInteger=123,'ToInteger');
  s:='-456';
  Check(s.ToInteger=-456,'ToInteger negative');
  s:='abc';
  Check(s.ToInteger=0,'ToInteger invalid');
  s:='9223372036854775807';
  Check(s.ToInt64=9223372036854775807,'ToInt64');
  s:='3.14';
  Check(Abs(s.ToDouble-3.14)<0.001,'ToDouble');
  s:='true';
  Check(s.ToBoolean=true,'ToBoolean true');
  s:='yes';
  Check(s.ToBoolean=true,'ToBoolean yes');
  s:='0';
  Check(s.ToBoolean=false,'ToBoolean 0');
  s:='';
  Check(s.ToBoolean=false,'ToBoolean empty');
  EndTest;
end;

// ============================================================================
// String32Helper tests (0-based indexing!)
// ============================================================================

procedure TestString32Basic;
var s:String32;
begin
  StartTest('String32.Basic');
  s:=UTF8.Decode('Hello');
  Check(s.Length=5,'Length');
  Check(not s.IsEmpty,'not IsEmpty');
  SetLength(s,0);
  Check(s.Length=0,'empty Length');
  Check(s.IsEmpty,'IsEmpty');
  EndTest;
end;

procedure TestString32CharAccess;
var s:String32;
begin
  StartTest('String32.CharAccess');
  s:=UTF8.Decode('ABCDE');
  // 0-based indexing!
  Check(s.CharAt(0)=ord('A'),'CharAt(0)');
  Check(s.CharAt(2)=ord('C'),'CharAt(2)');
  Check(s.CharAt(4)=ord('E'),'CharAt(4)');
  Check(s.CharAt(-1)=0,'CharAt(-1) out of bounds');
  Check(s.CharAt(5)=0,'CharAt(5) out of bounds');
  Check(s.FirstChar=ord('A'),'FirstChar');
  Check(s.LastChar=ord('E'),'LastChar');
  SetLength(s,0);
  Check(s.FirstChar=0,'empty FirstChar');
  Check(s.LastChar=0,'empty LastChar');
  EndTest;
end;

procedure TestString32Substring;
var s:String32;
begin
  StartTest('String32.Substring');
  s:=UTF8.Decode('Hello World');
  // 0-based: 'Hello'=0..4, ' '=5, 'World'=6..10
  Check(UTF8.Encode(s.Substring(0,5))='Hello','Substring(0,5)');
  Check(UTF8.Encode(s.Substring(6))='World','Substring(6)');
  Check(UTF8.Encode(s.Left(5))='Hello','Left(5)');
  Check(UTF8.Encode(s.Right(5))='World','Right(5)');
  EndTest;
end;

procedure TestString32Search;
var s,sub:String32;
begin
  StartTest('String32.Search');
  s:=UTF8.Decode('Hello World Hello');
  sub:=UTF8.Decode('Hello');
  // 0-based: returns -1 if not found
  Check(s.IndexOf(sub)=0,'IndexOf(Hello)=0');
  Check(s.IndexOf(sub,1)=12,'IndexOf(Hello,1)=12');
  sub:=UTF8.Decode('World');
  Check(s.IndexOf(sub)=6,'IndexOf(World)=6');
  sub:=UTF8.Decode('NotFound');
  Check(s.IndexOf(sub)=-1,'IndexOf not found=-1');
  // char search
  Check(s.IndexOf(ord('o'))=4,'IndexOf(o)=4');
  Check(s.IndexOf(ord('o'),5)=7,'IndexOf(o,5)=7');
  Check(s.IndexOf(ord('z'))=-1,'IndexOf(z)=-1');
  // LastIndexOf
  sub:=UTF8.Decode('Hello');
  Check(s.LastIndexOf(sub)=12,'LastIndexOf(Hello)=12');
  Check(s.LastIndexOf(ord('o'))=16,'LastIndexOf(o)=16');
  // Contains
  sub:=UTF8.Decode('World');
  Check(s.Contains(sub),'Contains(World)');
  sub:=UTF8.Decode('Foo');
  Check(not s.Contains(sub),'not Contains(Foo)');
  EndTest;
end;

procedure TestString32StartEnd;
var s,pre,suf:String32;
begin
  StartTest('String32.StartsWith/EndsWith');
  s:=UTF8.Decode('Hello World');
  pre:=UTF8.Decode('Hello');
  suf:=UTF8.Decode('World');
  Check(s.StartsWith(pre),'StartsWith(Hello)');
  Check(not s.StartsWith(suf),'not StartsWith(World)');
  Check(s.EndsWith(suf),'EndsWith(World)');
  Check(not s.EndsWith(pre),'not EndsWith(Hello)');
  EndTest;
end;

procedure TestString32Compare;
var s,other:String32;
begin
  StartTest('String32.Compare');
  s:=UTF8.Decode('Hello');
  other:=UTF8.Decode('Hello');
  Check(s.CompareTo(other)=0,'CompareTo equal');
  Check(s.Equals(other),'Equals');
  other:=UTF8.Decode('hello');
  Check(not s.Equals(other),'not Equals case');
  Check(s.EqualsText(other),'EqualsText');
  Check(s.CompareText(other)=0,'CompareText');
  other:=UTF8.Decode('HELLO');
  Check(s.EqualsText(other),'EqualsText upper');
  EndTest;
end;

procedure TestString32Case;
var s:String32;
begin
  StartTest('String32.Case');
  s:=UTF8.Decode('Hello World');
  Check(UTF8.Encode(s.ToUpper)='HELLO WORLD','ToUpper');
  Check(UTF8.Encode(s.ToLower)='hello world','ToLower');
  EndTest;
end;

procedure TestString32Trim;
var s:String32;
begin
  StartTest('String32.Trim');
  s:=UTF8.Decode('  Hello  ');
  Check(UTF8.Encode(s.Trim)='Hello','Trim');
  Check(UTF8.Encode(s.TrimLeft)='Hello  ','TrimLeft');
  Check(UTF8.Encode(s.TrimRight)='  Hello','TrimRight');
  EndTest;
end;

procedure TestString32Pad;
var s:String32;
begin
  StartTest('String32.Pad');
  s:=UTF8.Decode('Hi');
  Check(UTF8.Encode(s.PadLeft(5))='   Hi','PadLeft(5)');
  Check(UTF8.Encode(s.PadRight(5))='Hi   ','PadRight(5)');
  Check(UTF8.Encode(s.PadLeft(5,ord('0')))='000Hi','PadLeft(5,0)');
  EndTest;
end;

procedure TestString32Modify;
var s,sub,repl:String32;
begin
  StartTest('String32.Modify');
  s:=UTF8.Decode('Hello World');
  sub:=UTF8.Decode('Beautiful ');
  // Insert at index 6 (0-based, after 'Hello ')
  Check(UTF8.Encode(s.Insert(sub,6))='Hello Beautiful World','Insert');
  // Remove from index 5 (0-based)
  Check(UTF8.Encode(s.Remove(5))='Hello','Remove(5)');
  // Remove 5 chars starting at index 6
  Check(UTF8.Encode(s.Remove(6,5))='Hello ','Remove(6,5)');
  // Replace
  sub:=UTF8.Decode('World');
  repl:=UTF8.Decode('Pascal');
  Check(UTF8.Encode(s.Replace(sub,repl))='Hello Pascal','Replace');
  // ReplaceAll
  s:=UTF8.Decode('one two one');
  sub:=UTF8.Decode('one');
  repl:=UTF8.Decode('1');
  Check(UTF8.Encode(s.ReplaceAll(sub,repl))='1 two 1','ReplaceAll');
  EndTest;
end;

procedure TestString32Split;
var s:String32; arr:Strings32; delim:String32;
begin
  StartTest('String32.Split');
  s:=UTF8.Decode('a,b,c');
  arr:=s.Split(ord(','));
  Check(length(arr)=3,'Split length');
  Check(UTF8.Encode(arr[0])='a','Split[0]');
  Check(UTF8.Encode(arr[1])='b','Split[1]');
  Check(UTF8.Encode(arr[2])='c','Split[2]');
  // Join
  delim:=UTF8.Decode('-');
  Check(UTF8.Encode(String32.Join(arr,delim))='a-b-c','Join');
  EndTest;
end;

procedure TestString32Utility;
var s:String32;
begin
  StartTest('String32.Utility');
  s:=UTF8.Decode('abracadabra');
  Check(s.CountChar(ord('a'))=5,'CountChar');
  s:=UTF8.Decode('Hello');
  Check(UTF8.Encode(s.Reverse)='olleH','Reverse');
  Check(UTF8.Encode(s.Duplicate(3))='HelloHelloHello','Duplicate');
  EndTest;
end;

// ============================================================================
// Strings8Helper tests
// ============================================================================

procedure TestStrings8Helper;
var arr:Strings8;
begin
  StartTest('Strings8Helper');
  SetLength(arr,0);
  Check(arr.IsEmpty,'IsEmpty');
  arr.Add('a');
  arr.Add('b');
  arr.Add('c');
  Check(arr.Length=3,'Length after Add');
  Check(not arr.IsEmpty,'not IsEmpty');
  Check(arr.IndexOf('b')=1,'IndexOf');
  Check(arr.IndexOf('z')=-1,'IndexOf not found');
  Check(arr.Contains('a'),'Contains');
  Check(not arr.Contains('z'),'not Contains');
  // Insert
  arr.Insert(1,'x');
  Check(arr[1]='x','Insert');
  Check(arr.Length=4,'Length after Insert');
  // Delete
  arr.Delete(1);
  Check(arr[1]='b','Delete');
  Check(arr.Length=3,'Length after Delete');
  // Remove
  Check(arr.Remove('b'),'Remove found');
  Check(arr.Length=2,'Length after Remove');
  Check(not arr.Remove('z'),'Remove not found');
  // Join
  arr.Clear;
  arr.Add('x'); arr.Add('y'); arr.Add('z');
  Check(arr.Join(',')='x,y,z','Join');
  // Sort
  arr.Clear;
  arr.Add('c'); arr.Add('a'); arr.Add('b');
  arr.Sort;
  Check(arr[0]='a','Sort[0]');
  Check(arr[1]='b','Sort[1]');
  Check(arr[2]='c','Sort[2]');
  // Clear
  arr.Clear;
  Check(arr.IsEmpty,'Clear');
  EndTest;
end;

// ============================================================================
// Strings32Helper tests
// ============================================================================

procedure TestStrings32Helper;
var arr:Strings32; delim:String32;
begin
  StartTest('Strings32Helper');
  SetLength(arr,0);
  Check(arr.IsEmpty,'IsEmpty');
  arr.Add(UTF8.Decode('a'));
  arr.Add(UTF8.Decode('b'));
  arr.Add(UTF8.Decode('c'));
  Check(arr.Length=3,'Length');
  Check(arr.IndexOf(UTF8.Decode('b'))=1,'IndexOf');
  Check(arr.IndexOf(UTF8.Decode('z'))=-1,'IndexOf not found');
  Check(arr.Contains(UTF8.Decode('a')),'Contains');
  // Join
  delim:=UTF8.Decode(',');
  Check(UTF8.Encode(arr.Join(delim))='a,b,c','Join');
  // Clear
  arr.Clear;
  Check(arr.IsEmpty,'Clear');
  EndTest;
end;

// ============================================================================
// UTF8 tests
// ============================================================================

procedure TestUTF8Validation;
begin
  StartTest('UTF8.IsValid');
  Check(UTF8.IsValid('Hello'),'ASCII');
  Check(UTF8.IsValid(''),'empty');
  Check(UTF8.IsValid('Привет'),'Russian');
  Check(UTF8.IsValid('日本語'),'Japanese');
  Check(UTF8.IsValid(#$C0#$80)=false,'overlong');
  Check(UTF8.IsValid(#$FF)=false,'invalid byte');
  EndTest;
end;

procedure TestUTF8CharCount;
begin
  StartTest('UTF8.CharCount');
  Check(UTF8.CharCount('Hello')=5,'ASCII');
  Check(UTF8.CharCount('')=0,'empty');
  Check(UTF8.CharCount('Привет')=6,'Russian 6 chars');
  Check(UTF8.CharCount('日本語')=3,'Japanese 3 chars');
  // emoji (4-byte)
  Check(UTF8.CharCount(#$F0#$9F#$98#$80)=1,'emoji 1 char');
  EndTest;
end;

procedure TestUTF8Decode;
var s32:String32;
begin
  StartTest('UTF8.Decode');
  // ASCII
  s32:=UTF8.Decode('ABC');
  Check(length(s32)=3,'ASCII length');
  Check(s32[0]=ord('A'),'ASCII[0]');
  Check(s32[1]=ord('B'),'ASCII[1]');
  Check(s32[2]=ord('C'),'ASCII[2]');
  // 2-byte
  s32:=UTF8.Decode(#$C3#$A9); // é = U+00E9
  Check(length(s32)=1,'2-byte length');
  Check(s32[0]=$E9,'2-byte value');
  // 3-byte
  s32:=UTF8.Decode(#$E4#$B8#$AD); // 中 = U+4E2D
  Check(length(s32)=1,'3-byte length');
  Check(s32[0]=$4E2D,'3-byte value');
  // 4-byte
  s32:=UTF8.Decode(#$F0#$9F#$98#$80); // 😀 = U+1F600
  Check(length(s32)=1,'4-byte length');
  Check(s32[0]=$1F600,'4-byte value');
  EndTest;
end;

procedure TestUTF8Encode;
var s32:String32; s8:String8;
begin
  StartTest('UTF8.Encode');
  // ASCII
  SetLength(s32,3);
  s32[0]:=ord('A'); s32[1]:=ord('B'); s32[2]:=ord('C');
  Check(UTF8.Encode(s32)='ABC','ASCII');
  // 2-byte
  SetLength(s32,1);
  s32[0]:=$E9; // é
  s8:=UTF8.Encode(s32);
  Check(length(s8)=2,'2-byte length');
  Check(s8=#$C3#$A9,'2-byte value');
  // 3-byte
  s32[0]:=$4E2D; // 中
  s8:=UTF8.Encode(s32);
  Check(length(s8)=3,'3-byte length');
  Check(s8=#$E4#$B8#$AD,'3-byte value');
  // 4-byte
  s32[0]:=$1F600; // 😀
  s8:=UTF8.Encode(s32);
  Check(length(s8)=4,'4-byte length');
  Check(s8=#$F0#$9F#$98#$80,'4-byte value');
  EndTest;
end;

procedure TestUTF8RoundTrip;
var original:String8;
begin
  StartTest('UTF8.RoundTrip');
  original:='Hello, мир! 日本語 😀';
  Check(UTF8.Encode(UTF8.Decode(original))=original,'round-trip');
  EndTest;
end;

// TODO: Add tests for UTF8.ToWide, UTF8.FromWide, UTF8.ToUpper, UTF8.ToLower
//       when these methods are fully implemented

// ============================================================================
// Main
// ============================================================================

begin
  try
    // String8Helper
    TestString8Basic;
    TestString8CharAccess;
    TestString8Substring;
    TestString8Search;
    TestString8StartEnd;
    TestString8Compare;
    TestString8Case;
    TestString8Trim;
    TestString8Pad;
    TestString8Modify;
    TestString8Split;
    TestString8Quote;
    TestString8Escape;
    TestString8Url;
    TestString8Html;
    TestString8Utility;
    TestString8Convert;

    // String32Helper
    TestString32Basic;
    TestString32CharAccess;
    TestString32Substring;
    TestString32Search;
    TestString32StartEnd;
    TestString32Compare;
    TestString32Case;
    TestString32Trim;
    TestString32Pad;
    TestString32Modify;
    TestString32Split;
    TestString32Utility;

    // Array helpers
    TestStrings8Helper;
    TestStrings32Helper;

    // UTF8
    TestUTF8Validation;
    TestUTF8CharCount;
    TestUTF8Decode;
    TestUTF8Encode;
    TestUTF8RoundTrip;

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
