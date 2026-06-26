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
  // Case-insensitive search should find mixed-case fragment without manual lowercasing.
  Check(s.IndexOf('world',1,true)=7,'IndexOf(world,1,true)');
  // IndexOf char
  Check(s.IndexOf('o')=5,'IndexOf(o)');
  Check(s.IndexOf('o',6)=8,'IndexOf(o,6)');
  Check(s.IndexOf('z')=0,'IndexOf(z) not found');
  // LastIndexOf
  Check(s.LastIndexOf('Hello')=13,'LastIndexOf(Hello)');
  // Case-insensitive LastIndexOf should return the latest match regardless of case.
  Check(s.LastIndexOf('hello',true)=13,'LastIndexOf(hello,true)');
  Check(s.LastIndexOf('o')=17,'LastIndexOf(o)');
  // Contains
  Check(s.Contains('World'),'Contains(World)');
  Check(s.Contains('world',true),'Contains(world,true)');
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

procedure TestString8StartsWith;
var s:String8;
begin
  StartTest('String8.StartsWith');
  s:='Hello World';
  Check(s.StartsWith('Hello'),'basic match');
  s:='Hello';
  Check(not s.StartsWith('hello'),'case mismatch no ignoreCase');
  Check(s.StartsWith('hello',true),'case mismatch with ignoreCase');
  Check(s.StartsWith(''),'empty prefix');
  s:='Hi';
  Check(not s.StartsWith('Hello'),'prefix longer than string');
  s:='Hello';
  Check(s.StartsWith('Hello'),'exact match');
  Check(not s.StartsWith('World'),'no match');
  EndTest;
end;

procedure TestString8EndsWith;
var s:String8;
begin
  StartTest('String8.EndsWith');
  s:='Hello World';
  Check(s.EndsWith('World'),'basic match');
  s:='Hello';
  Check(not s.EndsWith('HELLO'),'case mismatch no ignoreCase');
  Check(s.EndsWith('HELLO',true),'case mismatch with ignoreCase');
  Check(s.EndsWith(''),'empty suffix');
  s:='Hi';
  Check(not s.EndsWith('Hello'),'suffix longer than string');
  s:='Hello';
  Check(s.EndsWith('Hello'),'exact match');
  Check(not s.EndsWith('World'),'no match');
  EndTest;
end;

procedure TestString8Compare;
var s:String8;
begin
  StartTest('String8.Compare');
  s:='Hello';
  Check(s.Compare('Hello',false)=0,'Compare case-sensitive equal');
  Check(s.Compare('Hallo',false)<>0,'Compare case-sensitive different');
  Check(s.Compare('Apple',false)>0,'Compare case-sensitive greater');
  Check(s.Compare('World',false)<0,'Compare case-sensitive less');
  Check(s.Compare('hello')=0,'Compare case-insensitive');
  Check(s.Compare('HELLO')=0,'Compare case-insensitive upper');
  Check(s.Compare('hellp')<0,'Compare case-insensitive less');
  Check(s.Compare('helln')>0,'Compare case-insensitive greater');
  Check(s.Compare('Hello!')<0,'Compare length less');
  Check(s='Hello','= equal');
  Check(not (s='hello'),'= case-sensitive');
  Check(s.Same('hello'),'Same');
  Check(s.Same('HELLO'),'Same upper');
  Check(not s.Same('Hello!'),'Same different length');
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
  s:=#9#13'Hello'#10#32;
  Check(s.Trim='Hello','Trim control whitespace');
  Check(s.TrimLeft='Hello'#10#32,'TrimLeft control whitespace');
  Check(s.TrimRight=#9#13'Hello','TrimRight control whitespace');
  s:='   ';
  Check(s.Trim='','Trim only spaces');
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
  Check(s.Replace('xxx','Pascal')='Hello World','Replace no match');
  Check(s.Replace('','Pascal')='Hello World','Replace empty pattern');
  s:='one two one two';
  Check(s.Replace('one','1')='1 two one two','Replace first');
  Check(s.ReplaceAll('one','1')='1 two 1 two','ReplaceAll');
  Check(s.ReplaceAll('one','')=' two  two','ReplaceAll delete');
  Check(s.ReplaceAll('','1')=s,'ReplaceAll empty pattern');
  s:='aaaa';
  Check(s.ReplaceAll('aa','b')='bb','ReplaceAll non-overlap');
  EndTest;
end;

// Returns true when arr has exactly the expected elements in order
function SL(const arr:Strings8; const expected:array of String8):boolean;
var i:integer;
begin
  if length(arr)<>length(expected) then exit(false);
  for i:=0 to high(arr) do
    if arr[i]<>expected[i] then exit(false);
  result:=true;
end;

procedure TestString8SplitLines;
var s:String8; arr:Strings8;
begin
  StartTest('String8.SplitLines');
  // Unix LF
  s:='line1'#10'line2'#10'line3';
  arr:=s.SplitLines;
  Check(SL(arr,['line1','line2','line3']),'LF: 3 lines');
  // Windows CRLF
  s:='line1'#13#10'line2'#13#10'line3';
  arr:=s.SplitLines;
  Check(SL(arr,['line1','line2','line3']),'CRLF: 3 lines');
  // Old Mac CR
  s:='line1'#13'line2'#13'line3';
  arr:=s.SplitLines;
  Check(SL(arr,['line1','line2','line3']),'CR: 3 lines');
  // mixed: LF then CRLF then CR
  s:='a'#10'b'#13#10'c'#13'd';
  arr:=s.SplitLines;
  Check(SL(arr,['a','b','c','d']),'mixed endings: 4 lines');
  // empty string — one empty element
  s:='';
  arr:=s.SplitLines;
  Check(SL(arr,['']),'empty string: 1 element');
  // no line endings — single element
  s:='hello';
  arr:=s.SplitLines;
  Check(SL(arr,['hello']),'no newline: 1 element');
  // trailing LF — last element is empty string
  s:='line1'#10'line2'#10;
  arr:=s.SplitLines;
  Check(SL(arr,['line1','line2','']),'trailing LF: last empty');
  // trailing CRLF — last element is empty string
  s:='line1'#13#10'line2'#13#10;
  arr:=s.SplitLines;
  Check(SL(arr,['line1','line2','']),'trailing CRLF: last empty');
  // single newline — two empty elements
  s:=#10;
  arr:=s.SplitLines;
  Check(SL(arr,['','']),'single LF: two empty');
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
  // with quote char: outer quotes stripped, embedded delimiter preserved
  s:='a,"b,c",d';
  arr:=s.Split(',','"');
  Check(length(arr)=3,'Split quoted length');
  Check(arr[0]='a','Split quoted[0]');
  Check(arr[1]='b,c','Split quoted[1]');
  Check(arr[2]='d','Split quoted[2]');
  // doubled quote collapses to one literal quote inside a quoted token
  s:='"a""b",c';
  arr:=s.Split(',','"');
  Check(SL(arr,['a"b','c']),'Split doubled quote');
  // quote is only special when it opens a token (mid-token quote is literal)
  s:='a"b,c';
  arr:=s.Split(',','"');
  Check(SL(arr,['a"b','c']),'Split mid-token quote literal');
  // trailing quoted token, terminated exactly at the closing quote
  s:='a,"b,c"';
  arr:=s.Split(',','"');
  Check(SL(arr,['a','b,c']),'Split trailing quoted');
  // unterminated quoted token takes the rest of the string
  s:='a,"b,c';
  arr:=s.Split(',','"');
  Check(SL(arr,['a','b,c']),'Split unterminated quote');
  // Join
  SetLength(arr,3);
  arr[0]:='x'; arr[1]:='y'; arr[2]:='z';
  Check(String8.Join(arr,'-')='x-y-z','Join');
  EndTest;
end;

procedure TestString8SplitEscaped;
var
  s:String8;
  arr:Strings8;
begin
  StartTest('String8.SplitEscaped');
  s:='a~bc~~d_~e__f~'; // no redundant escapes, so the encoding round-trips exactly
  arr:=s.SplitEscaped('~','_');
  Check(SL(arr,['a','bc','','d~e_f','']),'escaped split');
  Check(arr.JoinEscaped('~','_')=s,'escaped join round-trip');
  arr:=String8('plain').SplitEscaped('~','_');
  Check(SL(arr,['plain']),'no delimiter');
  arr:=String8('').SplitEscaped('~','_');
  Check(SL(arr,['']),'empty string');
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

procedure TestUTF8Format;
begin
  StartTest('UTF8.Format');
  // basic specifiers
  Check(UTF8.Format('Hello %s!',['World'])='Hello World!','%s');
  Check(UTF8.Format('%d',[42])='42','%d positive');
  Check(UTF8.Format('%d',[-7])='-7','%d negative');
  Check(UTF8.Format('%u',[255])='255','%u');
  Check(UTF8.Format('%x',[255])='ff','%x lowercase');
  Check(UTF8.Format('%X',[255])='FF','%X uppercase');
  Check(UTF8.Format('%x',[0])='0','%x zero');
  // percent literal
  Check(UTF8.Format('100%%',[])='100%','%%');
  // float
  Check(UTF8.Format('%.2f',[3.14159])='3.14','%.2f');
  Check(UTF8.Format('%f',[0.0])='0.000000','%f default precision');
  // width
  Check(UTF8.Format('%5d',[42])='   42','%5d right-align');
  Check(UTF8.Format('%-5d',[42])='42   ','%-5d left-align');
  Check(UTF8.Format('%05d',[42])='00042','%05d zero-pad');
  // sign
  Check(UTF8.Format('%+d',[42])='+42','%+d positive sign');
  Check(UTF8.Format('%+d',[-5])='-5','%+d negative sign');
  // multiple args
  Check(UTF8.Format('%d + %d = %d',[1,2,3])='1 + 2 = 3','multiple %d');
  Check(UTF8.Format('%s=%d',['x',10])='x=10','%s + %d');
  // hex with width
  Check(UTF8.Format('%04x',[$AB])='00ab','%04x');
  Check(UTF8.Format('%04X',[$AB])='00AB','%04X');
  // %g format
  Check(UTF8.Format('%g',[100.0])='100','%g integer');
  Check(UTF8.Format('%g',[3.14])='3.14','%g decimal');
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
  // Case-insensitive mode keeps 0-based indexing and should still find "World".
  Check(s.IndexOf(UTF8.Decode('world'),0,true)=6,'IndexOf(world,0,true)=6');
  sub:=UTF8.Decode('NotFound');
  Check(s.IndexOf(sub)=-1,'IndexOf not found=-1');
  // char search
  Check(s.IndexOf(ord('o'))=4,'IndexOf(o)=4');
  Check(s.IndexOf(ord('o'),5)=7,'IndexOf(o,5)=7');
  Check(s.IndexOf(ord('z'))=-1,'IndexOf(z)=-1');
  // LastIndexOf
  sub:=UTF8.Decode('Hello');
  Check(s.LastIndexOf(sub)=12,'LastIndexOf(Hello)=12');
  Check(s.LastIndexOf(UTF8.Decode('hello'),true)=12,'LastIndexOf(hello,true)=12');
  Check(s.LastIndexOf(ord('o'))=16,'LastIndexOf(o)=16');
  // Contains
  sub:=UTF8.Decode('World');
  Check(s.Contains(sub),'Contains(World)');
  Check(s.Contains(UTF8.Decode('world'),true),'Contains(world,true)');
  sub:=UTF8.Decode('Foo');
  Check(not s.Contains(sub),'not Contains(Foo)');
  EndTest;
end;

procedure TestString32IndexingContract;
var
  s,sub:String32;
begin
  StartTest('String32 indexing contract');
  // String32 helper is intentionally 0-based and uses -1 as "not found"
  s:=UTF8.Decode('Hello');
  sub:=UTF8.Decode('H');
  Check(s.CharAt(0)=ord('H'),'CharAt(0) should return first char');
  Check(s.FirstChar=s.CharAt(0),'FirstChar should be alias of CharAt(0)');
  Check(s.IndexOf(sub)=0,'IndexOf first element should be 0');
  sub:=UTF8.Decode('Z');
  Check(s.IndexOf(sub)=-1,'IndexOf not found should be -1');
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
  Check(s.Compare(other,false)=0,'Compare case-sensitive equal');
  Check(s.Equals(other),'Equals');
  other:=UTF8.Decode('hello');
  Check(not s.Equals(other),'Equals case-sensitive');
  Check(s.Same(other),'Same');
  Check(s.Compare(other)=0,'Compare case-insensitive');
  other:=UTF8.Decode('HELLO');
  Check(s.Same(other),'Same upper');
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
var s,sub,repl,result:String32;
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

  // Replace - debug output
  s:=UTF8.Decode('Hello World');
  sub:=UTF8.Decode('World');
  repl:=UTF8.Decode('Pascal');
  //writeln('Source: "',UTF8.Encode(s),'" (len=',length(s),')');
  //writeln('Search: "',UTF8.Encode(sub),'" (len=',length(sub),')');
  //writeln('Replace with: "',UTF8.Encode(repl),'" (len=',length(repl),')');
  result:=s.Replace(sub,repl);
  //writeln('Result: "',UTF8.Encode(result),'" (len=',length(result),')');
  //writeln('Expected: "Hello Pascal"');
  Check(UTF8.Encode(result)='Hello Pascal','Replace');

  s:=UTF8.Decode('Hello World');
  sub:=UTF8.Decode('Hello');
  repl:=UTF8.Decode('Pascal');
  result:=s.Replace(sub,repl);
  Check(UTF8.Encode(result)='Pascal World','Replace');

  // ReplaceAll - debug output
  s:=UTF8.Decode('one two one');
  sub:=UTF8.Decode('one');
  repl:=UTF8.Decode('1');
  //writeln('Source: "',UTF8.Encode(s),'" (len=',length(s),')');
  //writeln('Search: "',UTF8.Encode(sub),'" (len=',length(sub),')');
  //writeln('Replace with: "',UTF8.Encode(repl),'" (len=',length(repl),')');
  result:=s.ReplaceAll(sub,repl);
  //writeln('Result: "',UTF8.Encode(result),'" (len=',length(result),')');
  //writeln('Expected: "1 two 1"');
  Check(UTF8.Encode(result)='1 two 1','ReplaceAll');

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
  // with delimiters string
  s:=UTF8.Decode('a;b,c');
  arr:=s.Split(UTF8.Decode(',;'));
  Check(length(arr)=3,'Split multi delim');
  Check(UTF8.Encode(arr[0])='a','Split multi delim[0]');
  Check(UTF8.Encode(arr[1])='b','Split multi delim[1]');
  Check(UTF8.Encode(arr[2])='c','Split multi delim[2]');
  // with quote char: outer quotes stripped, embedded delimiter preserved
  s:=UTF8.Decode('a,"b,c",d');
  arr:=s.Split(UTF8.Decode(','),UCS4Char('"'));
  Check(length(arr)=3,'Split quoted length');
  Check(UTF8.Encode(arr[0])='a','Split quoted[0]');
  Check(UTF8.Encode(arr[1])='b,c','Split quoted[1]');
  Check(UTF8.Encode(arr[2])='d','Split quoted[2]');
  // doubled quote collapses to one literal quote inside a quoted token
  s:=UTF8.Decode('"a""b",c');
  arr:=s.Split(UTF8.Decode(','),UCS4Char('"'));
  Check((length(arr)=2) and (UTF8.Encode(arr[0])='a"b') and (UTF8.Encode(arr[1])='c'),'Split doubled quote');
  // mid-token quote is literal
  s:=UTF8.Decode('a"b,c');
  arr:=s.Split(UTF8.Decode(','),UCS4Char('"'));
  Check((length(arr)=2) and (UTF8.Encode(arr[0])='a"b') and (UTF8.Encode(arr[1])='c'),'Split mid-token quote literal');
  // Join
  arr:=UTF8.Decode('a,b,c').Split(UCS4Char(','));
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

procedure TestStringsReader;
var
  reader:TStringsReader;
begin
  StartTest('TStringsReader');
  SetLength(reader.values,0);
  reader.index:=0;
  Check(reader.Empty,'Empty with no values');
  Check(reader.NextStr='','NextStr past end');
  Check(reader.NextInt=-1,'NextInt past end');
  Check(reader.Int(0)=0,'Int(0) past end');

  SetLength(reader.values,0);
  reader.values.Add('10');
  reader.values.Add('abc');
  reader.values.Add('-5');
  reader.index:=0;
  Check(not reader.Empty,'not Empty with values');
  Check(reader.Int(0)=10,'Int(0)');
  Check(reader.Int(1)=0,'Int(1) non-numeric');
  Check(reader.Int(2)=-5,'Int(2)');
  Check(reader.Int(3)=0,'Int(3) out of range');
  Check(reader.Int(-1)=0,'Int(-1) out of range');
  Check(reader.NextInt=10,'NextInt first');
  Check(reader.index=1,'index after NextInt');
  Check(reader.NextStr='abc','NextStr second');
  Check(reader.index=2,'index after NextStr');
  Check(not reader.Empty,'not Empty before last item');
  Check(reader.NextInt=-5,'NextInt third');
  Check(reader.Empty,'Empty after last item');
  Check(reader.NextStr='','NextStr after exhausted');
  Check(reader.index=4,'index keeps advancing');
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
  Check(UTF8.IsValid(RawByteString(#$C0#$80))=false,'overlong');
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
  Check(UTF8.CharCount(RawByteString(#$F0#$9F#$98#$80))=1,'emoji 1 char');
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
  s32:=UTF8.Decode(RawByteString(#$C3#$A9)); // é = U+00E9
  Check(length(s32)=1,'2-byte length');
  Check(s32[0]=$E9,'2-byte value');
  // 3-byte
  s32:=UTF8.Decode(RawByteString(#$E4#$B8#$AD)); // 中 = U+4E2D
  Check(length(s32)=1,'3-byte length');
  Check(s32[0]=$4E2D,'3-byte value');
  // 4-byte
  s32:=UTF8.Decode(RawByteString(#$F0#$9F#$98#$80)); // 😀 = U+1F600
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
  Check(s8=RawByteString(#$C3#$A9),'2-byte value');
  // 3-byte
  s32[0]:=$4E2D; // 中
  s8:=UTF8.Encode(s32);
  Check(length(s8)=3,'3-byte length');
  Check(s8=RawByteString(#$E4#$B8#$AD),'3-byte value');
  // 4-byte
  s32[0]:=$1F600; // 😀
  s8:=UTF8.Encode(s32);
  Check(length(s8)=4,'4-byte length');
  Check(s8=RawByteString(#$F0#$9F#$98#$80),'4-byte value');
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

// ============================================================================
// Str8/Str16/Str32 and encoding conversion tests
// ============================================================================

procedure TestStr8;
var s8:String8; ws:WideString;
begin
  StartTest('Str8');
  ws:='Hello';
  s8:=Str8(ws);
  Check(s8='Hello','from WideString');
  s8:=Str8(UTF8String('Привет'));
  Check(s8=String8('Привет'),'from UTF8String');
  {$IFDEF UNICODE}
  s8:=Str8(AnsiString('test'));
  Check(s8=String8('test'),'from AnsiString');
  {$ENDIF}
  EndTest;
end;

procedure TestStr16;
var s16:String16;
begin
  StartTest('Str16');
  s16:=Str16(UTF8String('Hello'));
  Check(s16='Hello','from UTF8String');
  s16:=Str16(WideString('World'));
  Check(s16='World','from WideString');
  EndTest;
end;

procedure TestStr32Conv;
var s32:String32; s8:String8;
begin
  StartTest('Str32');
  s8:='ABC';
  s32:=Str32(s8);
  Check(length(s32)=3,'length from String8');
  Check(s32[0]=ord('A'),'char 0');
  Check(s32[2]=ord('C'),'char 2');
  s32:=Str32(WideString('XY'));
  Check(length(s32)=2,'length from WideString');
  Check(s32[0]=ord('X'),'wide char 0');
  Check(s32[1]=ord('Y'),'wide char 1');
  EndTest;
end;

procedure TestUTF8WideConversion;
var ws:WideString; s8:String8;
begin
  StartTest('UTF8.Encode/ToWide');
  ws:='Hello';
  s8:=UTF8.Encode(ws);
  Check(s8='Hello','encode ascii');
  Check(UTF8.ToWide(s8)='Hello','decode ascii');
  // with BOM
  s8:=UTF8.Encode(ws,true);
  Check(s8[1]=#$EF,'BOM byte 1');
  Check(s8[2]=#$BB,'BOM byte 2');
  Check(s8[3]=#$BF,'BOM byte 3');
  Check(UTF8.ToWide(s8)='Hello','decode with BOM');
  // Cyrillic
  ws:=WideChar($041F)+WideChar($0440)+WideChar($0438); // При
  s8:=UTF8.Encode(ws);
  Check(UTF8.ToWide(s8)=ws,'cyrillic roundtrip');
  EndTest;
end;

procedure TestUTF8HasBOM;
begin
  StartTest('UTF8.HasBOM');
  Check(UTF8.HasBOM(#$EF#$BB#$BF'test'),'with BOM');
  Check(not UTF8.HasBOM('test'),'without BOM');
  Check(not UTF8.HasBOM(''),'empty');
  EndTest;
end;

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
    TestString8StartsWith;
    TestString8EndsWith;
    TestString8Compare;
    TestString8Case;
    TestString8Trim;
    TestString8Pad;
    TestString8Modify;
    TestString8SplitLines;
    TestString8Split;
    TestString8SplitEscaped;
    TestString8Quote;
    TestString8Escape;
    TestString8Url;
    TestString8Html;
    TestString8Utility;
    TestString8Convert;

    // UTF8.Format
    TestUTF8Format;

    // String32Helper
    TestString32Basic;
    TestString32CharAccess;
    TestString32Substring;
    TestString32Search;
    TestString32IndexingContract;
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
    TestStringsReader;
    TestStrings32Helper;

    // UTF8
    TestUTF8Validation;
    TestUTF8CharCount;
    TestUTF8Decode;
    TestUTF8Encode;
    TestUTF8RoundTrip;

    // Str8/Str16/Str32 and UTF8 wide conversion
    TestStr8;
    TestStr16;
    TestStr32Conv;
    TestUTF8WideConversion;
    TestUTF8HasBOM;

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
