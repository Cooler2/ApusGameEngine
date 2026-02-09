// String helper types for String8 and String32
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
//
// Modeled after Delphi's TStringHelper but uses 1-based indexing for Pascal compatibility
{$I defines.inc}
unit Apus.Strings;
interface
uses Apus.Core;

type
  // Helper for String8 (UTF-8 strings)
  String8Helper = record helper for String8
    // === Properties ===
    function Length:integer; inline;
    function IsEmpty:boolean; inline;

    // === Character access ===
    function AnsiCharAt(index:integer):AnsiChar; inline;  // 1-based, returns #0 if out of bounds
    function LastAnsiChar:AnsiChar; inline;

    // === Substring ===
    function Substr(startIndex:integer;len:integer=MAXINT):String8; overload;       // 1-based
    function Left(count:integer):String8;
    function Right(count:integer):String8;

    // === Search ===
    function IndexOf(const substr:String8):integer; overload;                    // returns 0 if not found
    function IndexOf(const substr:String8;startPos:integer):integer; overload;   // 1-based startPos
    function IndexOf(ch:AnsiChar):integer; overload;
    function IndexOf(ch:AnsiChar;startPos:integer):integer; overload;
    function LastIndexOf(const substr:String8):integer; overload;
    function LastIndexOf(ch:AnsiChar):integer; overload;
    function Contains(const substr:String8):boolean; overload;
    function Contains(ch:AnsiChar):boolean; overload;
    function StartsWith(const prefix:String8):boolean;
    function EndsWith(const suffix:String8):boolean;

    // === Comparison ===
    function CompareTo(const other:String8):integer;       // case-sensitive
    function CompareText(const other:String8):integer;     // case-insensitive
    function Equals(const other:String8):boolean;          // case-sensitive
    function EqualsText(const other:String8):boolean;      // case-insensitive

    // === Case conversion ===
    function ToUpper:String8;
    function ToLower:String8;

    // === Trimming ===
    function Trim:String8;
    function TrimLeft:String8;
    function TrimRight:String8;

    // === Padding ===
    function PadLeft(totalWidth:integer;paddingChar:AnsiChar=' '):String8;
    function PadRight(totalWidth:integer;paddingChar:AnsiChar=' '):String8;

    // === Modification ===
    function Insert(const substr:String8;index:integer):String8;  // 1-based
    function Remove(startIndex:integer):String8; overload;        // 1-based, remove to end
    function Remove(startIndex,count:integer):String8; overload;  // 1-based
    function Replace(const oldStr,newStr:String8):String8;
    function ReplaceAll(const oldStr,newStr:String8):String8;

    // === Split/Join ===
    function Split(delimiter:AnsiChar;quoteChar:AnsiChar=#0):Strings8; overload;
    function Split(const delimiters:String8;quoteChar:AnsiChar=#0):Strings8; overload;
    class function Join(const arr:Strings8;const delimiter:String8):String8; static;

    // === Quoting ===
    function Quote(quoteChar:AnsiChar='"'):String8;
    function Unquote:String8;

    // === Escaping ===
    function Escape:String8;    // escape \n \t \\ etc
    function Unescape:String8;  // unescape \n \t \\ etc

    // === URL encoding ===
    function UrlEncode:String8;
    function UrlDecode:String8;

    // === HTML ===
    function HtmlEscape:String8;   // escape & < > " '
    function HtmlUnescape:String8;

    // === Utility ===
    function CountChar(ch:AnsiChar):integer;
    function Reverse:String8;
    function Duplicate(count:integer):String8;
    function Printable:String8;  // replace control chars with '.'
    function Extract(const startMarker,endMarker:String8):String8;  // extract between markers

    // === Conversion ===
    function ToInteger:integer;
    function ToInt64:int64;
    function ToDouble:double;
    function ToBoolean:boolean;
  end;

  // Helper for String32 (UCS-4 strings)
  String32Helper = record helper for String32
    // === Properties ===
    function Length:integer; inline;
    function IsEmpty:boolean; inline;

    // === Character access ===
    function CharAt(index:integer):UCS4Char; inline;
    function LastChar:UCS4Char; inline;
    function FirstChar:UCS4Char; inline; // alias for CharAt(1)

    // === Substring ===
    function Substring(startIndex:integer):String32; overload;
    function Substring(startIndex,len:integer):String32; overload;
    function Left(count:integer):String32;
    function Right(count:integer):String32;

    // === Search ===
    function IndexOf(const substr:String32):integer; overload;
    function IndexOf(const substr:String32;startPos:integer):integer; overload;
    function IndexOf(ch:UCS4Char):integer; overload;
    function IndexOf(ch:UCS4Char;startPos:integer):integer; overload;
    function LastIndexOf(const substr:String32):integer; overload;
    function LastIndexOf(ch:UCS4Char):integer; overload;
    function Contains(const substr:String32):boolean; overload;
    function Contains(ch:UCS4Char):boolean; overload;
    function StartsWith(const prefix:String32):boolean;
    function EndsWith(const suffix:String32):boolean;

    // === Comparison ===
    function CompareTo(const other:String32):integer;
    function CompareText(const other:String32):integer;     // case-insensitive
    function Equals(const other:String32):boolean;
    function EqualsText(const other:String32):boolean;     // case-insensitive

    // === Case conversion ===
    function ToUpper:String32;
    function ToLower:String32;

    // === Trimming ===
    function Trim:String32;
    function TrimLeft:String32;
    function TrimRight:String32;

    // === Padding ===
    function PadLeft(totalWidth:integer;paddingChar:UCS4Char=32):String32;
    function PadRight(totalWidth:integer;paddingChar:UCS4Char=32):String32;

    // === Modification ===
    function Insert(const substr:String32;index:integer):String32;
    function Remove(startIndex:integer):String32; overload;
    function Remove(startIndex,count:integer):String32; overload;
    function Replace(const oldStr,newStr:String32):String32;
    function ReplaceAll(const oldStr,newStr:String32):String32;

    // === Split/Join ===
    function Split(delimiter:UCS4Char):Strings32; overload;
    class function Join(const arr:Strings32;const delimiter:String32):String32; static;

    // === Utility ===
    function CountChar(ch:UCS4Char):integer;
    function Reverse:String32;
    function Duplicate(count:integer):String32;
  end;

  // Helper for array of String8
  Strings8Helper = record helper for Strings8
    function Length:integer; inline;
    function IsEmpty:boolean; inline;
    function IndexOf(const s:String8):integer;
    function Contains(const s:String8):boolean;
    procedure Add(const s:String8);
    procedure Insert(index:integer;const s:String8);
    procedure Delete(index:integer);
    function Remove(const s:String8):boolean;  // returns true if found and removed
    procedure Clear;
    function Join(const delimiter:String8):String8;
    procedure Sort;
  end;

  // Helper for array of String32
  Strings32Helper = record helper for Strings32
    function Length:integer; inline;
    function IsEmpty:boolean; inline;
    function IndexOf(const s:String32):integer;
    function Contains(const s:String32):boolean;
    procedure Add(const s:String32);
    procedure Insert(index:integer;const s:String32);
    procedure Delete(index:integer);
    function Remove(const s:String32):boolean;
    procedure Clear;
    function Join(const delimiter:String32):String32;
  end;

  // UTF-8 specific utilities
  UTF8 = record
    // Validate UTF-8 string
    class function IsValid(const s:String8):boolean; static;
    // Get character count (not byte count)
    class function CharCount(const s:String8):integer; static;
    // Convert UTF-8 <-> String32 (UCS-4)
    class function Decode(const s:String8):String32; static;
    class function Encode(const s:String32):String8; static;
    // Convert UTF-8 <-> WideString (UTF-16)
    class function ToWide(const s:String8):WideString; static;
    class function FromWide(const s:WideString):String8; static;
    // Upper/Lower case for UTF-8 (Unicode-aware)
    class function ToUpper(const s:String8):String8; static;
    class function ToLower(const s:String8):String8; static;
  end;

implementation
uses SysUtils;

// ============================================================================
// String8Helper
// ============================================================================

function String8Helper.Length:integer;
begin result:=System.Length(self); end;

function String8Helper.IsEmpty:boolean;
begin result:=System.Length(self)=0; end;

function String8Helper.AnsiCharAt(index:integer):AnsiChar;
begin
  if (index>=1) and (index<=System.Length(self)) then result:=self[index]
  else result:=#0;
end;

function String8Helper.LastAnsiChar:AnsiChar;
begin
  if System.Length(self)>0 then result:=self[System.Length(self)]
  else result:=#0;
end;

function String8Helper.Substr(startIndex:integer;len:integer):String8;
begin result:=System.Copy(self,startIndex,len); end;

function String8Helper.Left(count:integer):String8;
begin result:=System.Copy(self,1,count); end;

function String8Helper.Right(count:integer):String8;
begin result:=System.Copy(self,System.Length(self)-count+1,count); end;

function String8Helper.IndexOf(const substr:String8):integer;
begin result:=System.Pos(substr,self); end;

function String8Helper.IndexOf(const substr:String8;startPos:integer):integer;
begin result:=System.Pos(substr,self,startPos); end;

function String8Helper.IndexOf(ch:AnsiChar):integer;
var i:integer;
begin
  for i:=1 to System.Length(self) do
    if self[i]=ch then exit(i);
  result:=0;
end;

function String8Helper.IndexOf(ch:AnsiChar;startPos:integer):integer;
var i:integer;
begin
  for i:=startPos to System.Length(self) do
    if self[i]=ch then exit(i);
  result:=0;
end;

function String8Helper.LastIndexOf(const substr:String8):integer;
var p:integer;
begin
  result:=0; p:=1;
  repeat
    p:=System.Pos(substr,self,p);
    if p>0 then begin result:=p; inc(p); end;
  until p=0;
end;

function String8Helper.LastIndexOf(ch:AnsiChar):integer;
var i:integer;
begin
  for i:=System.Length(self) downto 1 do
    if self[i]=ch then exit(i);
  result:=0;
end;

function String8Helper.Contains(const substr:String8):boolean;
begin result:=System.Pos(substr,self)>0; end;

function String8Helper.Contains(ch:AnsiChar):boolean;
begin result:=IndexOf(ch)>0; end;

function String8Helper.StartsWith(const prefix:String8):boolean;
begin result:=System.Copy(self,1,System.Length(prefix))=prefix; end;

function String8Helper.EndsWith(const suffix:String8):boolean;
var len:integer;
begin
  len:=System.Length(suffix);
  result:=System.Copy(self,System.Length(self)-len+1,len)=suffix;
end;

function String8Helper.CompareTo(const other:String8):integer;
begin result:=SysUtils.CompareStr(self,other); end;

function String8Helper.CompareText(const other:String8):integer;
begin result:=SysUtils.CompareText(self,other); end;

function String8Helper.Equals(const other:String8):boolean;
begin result:=self=other; end;

function String8Helper.EqualsText(const other:String8):boolean;
begin result:=SysUtils.SameText(self,other); end;

function String8Helper.ToUpper:String8;
begin result:=SysUtils.UpperCase(self); end;

function String8Helper.ToLower:String8;
begin result:=SysUtils.LowerCase(self); end;

function String8Helper.Trim:String8;
begin result:=SysUtils.Trim(self); end;

function String8Helper.TrimLeft:String8;
begin result:=SysUtils.TrimLeft(self); end;

function String8Helper.TrimRight:String8;
begin result:=SysUtils.TrimRight(self); end;

function String8Helper.PadLeft(totalWidth:integer;paddingChar:AnsiChar):String8;
var pad:integer;
begin
  pad:=totalWidth-System.Length(self);
  if pad<=0 then result:=self
  else begin
    SetLength(result,totalWidth);
    FillChar(result[1],pad,paddingChar);
    if System.Length(self)>0 then
      Move(self[1],result[pad+1],System.Length(self));
  end;
end;

function String8Helper.PadRight(totalWidth:integer;paddingChar:AnsiChar):String8;
var oldLen:integer;
begin
  oldLen:=System.Length(self);
  if totalWidth<=oldLen then result:=self
  else begin
    SetLength(result,totalWidth);
    if oldLen>0 then Move(self[1],result[1],oldLen);
    FillChar(result[oldLen+1],totalWidth-oldLen,paddingChar);
  end;
end;

function String8Helper.Insert(const substr:String8;index:integer):String8;
begin
  result:=self;
  System.Insert(substr,result,index);
end;

function String8Helper.Remove(startIndex:integer):String8;
begin result:=System.Copy(self,1,startIndex-1); end;

function String8Helper.Remove(startIndex,count:integer):String8;
begin
  result:=self;
  System.Delete(result,startIndex,count);
end;

function String8Helper.Replace(const oldStr,newStr:String8):String8;
begin result:=SysUtils.StringReplace(self,oldStr,newStr,[]); end;

function String8Helper.ReplaceAll(const oldStr,newStr:String8):String8;
begin result:=SysUtils.StringReplace(self,oldStr,newStr,[rfReplaceAll]); end;

function String8Helper.Split(delimiter:AnsiChar;quoteChar:AnsiChar):Strings8;
var i,start,cnt:integer; inQuote:boolean;
begin
  SetLength(result,16); cnt:=0; start:=1; inQuote:=false;
  for i:=1 to System.Length(self) do begin
    if (quoteChar<>#0) and (self[i]=quoteChar) then
      inQuote:=not inQuote
    else if (not inQuote) and (self[i]=delimiter) then begin
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      result[cnt]:=System.Copy(self,start,i-start);
      inc(cnt); start:=i+1;
    end;
  end;
  if cnt>=System.Length(result) then SetLength(result,cnt+1);
  result[cnt]:=System.Copy(self,start,System.Length(self)-start+1);
  SetLength(result,cnt+1);
end;

function String8Helper.Split(const delimiters:String8;quoteChar:AnsiChar):Strings8;
var i,start,cnt:integer; inQuote:boolean;
begin
  SetLength(result,16); cnt:=0; start:=1; inQuote:=false;
  for i:=1 to System.Length(self) do begin
    if (quoteChar<>#0) and (self[i]=quoteChar) then
      inQuote:=not inQuote
    else if (not inQuote) and (System.Pos(self[i],delimiters)>0) then begin
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      result[cnt]:=System.Copy(self,start,i-start);
      inc(cnt); start:=i+1;
    end;
  end;
  if cnt>=System.Length(result) then SetLength(result,cnt+1);
  result[cnt]:=System.Copy(self,start,System.Length(self)-start+1);
  SetLength(result,cnt+1);
end;

class function String8Helper.Join(const arr:Strings8;const delimiter:String8):String8;
var i:integer;
begin
  result:='';
  for i:=0 to high(arr) do begin
    if i>0 then result:=result+delimiter;
    result:=result+arr[i];
  end;
end;

function String8Helper.Quote(quoteChar:AnsiChar):String8;
begin result:=quoteChar+self+quoteChar; end;

function String8Helper.Unquote:String8;
var len:integer;
begin
  len:=System.Length(self);
  if (len>=2) and (self[1]=self[len]) and (self[1] in ['"','''']) then
    result:=System.Copy(self,2,len-2)
  else result:=self;
end;

function String8Helper.Escape:String8;
var i:integer;
begin
  result:='';
  for i:=1 to System.Length(self) do
    case self[i] of
      #10: result:=result+'\n';
      #13: result:=result+'\r';
      #9:  result:=result+'\t';
      '\': result:=result+'\\';
      else result:=result+self[i];
    end;
end;

function String8Helper.Unescape:String8;
var i:integer; escaped:boolean;
begin
  result:=''; escaped:=false;
  for i:=1 to System.Length(self) do begin
    if escaped then begin
      case self[i] of
        'n': result:=result+#10;
        'r': result:=result+#13;
        't': result:=result+#9;
        '\': result:=result+'\';
        else result:=result+self[i];
      end;
      escaped:=false;
    end else if self[i]='\' then
      escaped:=true
    else
      result:=result+self[i];
  end;
end;

function String8Helper.UrlEncode:String8;
const HexChars:String8='0123456789ABCDEF';
var i:integer; b:byte;
begin
  result:='';
  for i:=1 to System.Length(self) do begin
    b:=byte(self[i]);
    if (self[i] in ['A'..'Z','a'..'z','0'..'9','-','_','.','~']) then
      result:=result+self[i]
    else
      result:=result+'%'+HexChars[1+b shr 4]+HexChars[1+b and $F];
  end;
end;

function String8Helper.UrlDecode:String8;
var i:integer;
  function HexVal(c:AnsiChar):integer;
  begin
    if c in ['0'..'9'] then result:=ord(c)-ord('0')
    else if c in ['A'..'F'] then result:=ord(c)-ord('A')+10
    else if c in ['a'..'f'] then result:=ord(c)-ord('a')+10
    else result:=0;
  end;
begin
  result:=''; i:=1;
  while i<=System.Length(self) do begin
    if (self[i]='%') and (i+2<=System.Length(self)) then begin
      result:=result+AnsiChar(HexVal(self[i+1])*16+HexVal(self[i+2]));
      inc(i,3);
    end else if self[i]='+' then begin
      result:=result+' '; inc(i);
    end else begin
      result:=result+self[i]; inc(i);
    end;
  end;
end;

function String8Helper.HtmlEscape:String8;
var i:integer;
begin
  result:='';
  for i:=1 to System.Length(self) do
    case self[i] of
      '&': result:=result+'&amp;';
      '<': result:=result+'&lt;';
      '>': result:=result+'&gt;';
      '"': result:=result+'&quot;';
      '''':result:=result+'&#39;';
      else result:=result+self[i];
    end;
end;

function String8Helper.HtmlUnescape:String8;
begin
  result:=self;
  result:=result.ReplaceAll('&amp;','&');
  result:=result.ReplaceAll('&lt;','<');
  result:=result.ReplaceAll('&gt;','>');
  result:=result.ReplaceAll('&quot;','"');
  result:=result.ReplaceAll('&#39;','''');
  result:=result.ReplaceAll('&apos;','''');
end;

function String8Helper.CountChar(ch:AnsiChar):integer;
var i:integer;
begin
  result:=0;
  for i:=1 to System.Length(self) do
    if self[i]=ch then inc(result);
end;

function String8Helper.Reverse:String8;
var i,len:integer;
begin
  len:=System.Length(self);
  SetLength(result,len);
  for i:=1 to len do result[len-i+1]:=self[i];
end;

function String8Helper.Duplicate(count:integer):String8;
var i,len:integer;
begin
  len:=System.Length(self);
  SetLength(result,len*count);
  for i:=0 to count-1 do
    if len>0 then Move(self[1],result[i*len+1],len);
end;

function String8Helper.Printable:String8;
var i:integer;
begin
  result:=self;
  for i:=1 to System.Length(result) do
    if result[i]<' ' then result[i]:='.';
end;

function String8Helper.Extract(const startMarker,endMarker:String8):String8;
var p1,p2:integer;
begin
  result:='';
  p1:=System.Pos(startMarker,self);
  if p1=0 then exit;
  p1:=p1+System.Length(startMarker);
  p2:=System.Pos(endMarker,self,p1);
  if p2=0 then exit;
  result:=System.Copy(self,p1,p2-p1);
end;

function String8Helper.ToInteger:integer;
begin result:=StrToIntDef(self,0); end;

function String8Helper.ToInt64:int64;
begin result:=StrToInt64Def(self,0); end;

function String8Helper.ToDouble:double;
begin result:=StrToFloatDef(self,0); end;

function String8Helper.ToBoolean:boolean;
begin result:=(System.Length(self)>0) and (self[1] in ['T','t','Y','y','1','+']); end;

// ============================================================================
// String32Helper (0-based indexing - String32 is array of UCS4Char)
// ============================================================================

function String32Helper.Length:integer;
begin result:=System.Length(self); end;

function String32Helper.IsEmpty:boolean;
begin result:=System.Length(self)=0; end;

function String32Helper.CharAt(index:integer):UCS4Char;
begin
  if (index>=0) and (index<System.Length(self)) then result:=self[index]
  else result:=0;
end;

function String32Helper.FirstChar:UCS4Char;
begin
  if System.Length(self)>0 then result:=self[0]
  else result:=0;
end;

function String32Helper.LastChar:UCS4Char;
begin
  if System.Length(self)>0 then result:=self[high(self)]
  else result:=0;
end;

function String32Helper.Substring(startIndex:integer):String32;
begin result:=System.Copy(self,startIndex,MaxInt); end;

function String32Helper.Substring(startIndex,len:integer):String32;
begin result:=System.Copy(self,startIndex,len); end;

function String32Helper.Left(count:integer):String32;
begin result:=System.Copy(self,0,count); end;

function String32Helper.Right(count:integer):String32;
begin result:=System.Copy(self,System.Length(self)-count,count); end;

function String32Helper.IndexOf(const substr:String32):integer;
var i,j:integer; found:boolean;
begin
  for i:=0 to System.Length(self)-System.Length(substr) do begin
    found:=true;
    for j:=0 to high(substr) do
      if self[i+j]<>substr[j] then begin found:=false; break; end;
    if found then exit(i);
  end;
  result:=-1;
end;

function String32Helper.IndexOf(const substr:String32;startPos:integer):integer;
var i,j:integer; found:boolean;
begin
  for i:=startPos to System.Length(self)-System.Length(substr) do begin
    found:=true;
    for j:=0 to high(substr) do
      if self[i+j]<>substr[j] then begin found:=false; break; end;
    if found then exit(i);
  end;
  result:=-1;
end;

function String32Helper.IndexOf(ch:UCS4Char):integer;
var i:integer;
begin
  for i:=0 to high(self) do
    if self[i]=ch then exit(i);
  result:=-1;
end;

function String32Helper.IndexOf(ch:UCS4Char;startPos:integer):integer;
var i:integer;
begin
  for i:=startPos to high(self) do
    if self[i]=ch then exit(i);
  result:=-1;
end;

function String32Helper.LastIndexOf(const substr:String32):integer;
var p:integer;
begin
  result:=-1; p:=0;
  repeat
    p:=IndexOf(substr,p);
    if p>=0 then begin result:=p; inc(p); end;
  until p<0;
end;

function String32Helper.LastIndexOf(ch:UCS4Char):integer;
var i:integer;
begin
  for i:=high(self) downto 0 do
    if self[i]=ch then exit(i);
  result:=-1;
end;

function String32Helper.Contains(const substr:String32):boolean;
begin result:=IndexOf(substr)>=0; end;

function String32Helper.Contains(ch:UCS4Char):boolean;
begin result:=IndexOf(ch)>=0; end;

function String32Helper.StartsWith(const prefix:String32):boolean;
var i:integer;
begin
  if System.Length(prefix)>System.Length(self) then exit(false);
  for i:=0 to high(prefix) do
    if self[i]<>prefix[i] then exit(false);
  result:=true;
end;

function String32Helper.EndsWith(const suffix:String32):boolean;
var i,offset:integer;
begin
  if System.Length(suffix)>System.Length(self) then exit(false);
  offset:=System.Length(self)-System.Length(suffix);
  for i:=0 to high(suffix) do
    if self[offset+i]<>suffix[i] then exit(false);
  result:=true;
end;

function String32Helper.CompareTo(const other:String32):integer;
var i,minLen:integer;
begin
  minLen:=System.Length(self);
  if System.Length(other)<minLen then minLen:=System.Length(other);
  for i:=0 to minLen-1 do begin
    result:=integer(self[i])-integer(other[i]);
    if result<>0 then exit;
  end;
  result:=System.Length(self)-System.Length(other);
end;

function String32Helper.CompareText(const other:String32):integer;
var i,minLen:integer; c1,c2:UCS4Char;
begin
  minLen:=System.Length(self);
  if System.Length(other)<minLen then minLen:=System.Length(other);
  for i:=0 to minLen-1 do begin
    c1:=self[i]; c2:=other[i];
    if (c1>=ord('A')) and (c1<=ord('Z')) then c1:=c1+32;
    if (c2>=ord('A')) and (c2<=ord('Z')) then c2:=c2+32;
    result:=integer(c1)-integer(c2);
    if result<>0 then exit;
  end;
  result:=System.Length(self)-System.Length(other);
end;

function String32Helper.Equals(const other:String32):boolean;
begin result:=CompareTo(other)=0; end;

function String32Helper.EqualsText(const other:String32):boolean;
begin result:=CompareText(other)=0; end;

function String32Helper.ToUpper:String32;
var i:integer;
begin
  SetLength(result,System.Length(self));
  for i:=0 to high(self) do
    if (self[i]>=ord('a')) and (self[i]<=ord('z')) then
      result[i]:=self[i]-32
    else
      result[i]:=self[i];
end;

function String32Helper.ToLower:String32;
var i:integer;
begin
  SetLength(result,System.Length(self));
  for i:=0 to high(self) do
    if (self[i]>=ord('A')) and (self[i]<=ord('Z')) then
      result[i]:=self[i]+32
    else
      result[i]:=self[i];
end;

function String32Helper.Trim:String32;
var i,j:integer;
begin
  i:=0;
  while (i<System.Length(self)) and (self[i]<=32) do inc(i);
  j:=high(self);
  while (j>=i) and (self[j]<=32) do dec(j);
  result:=System.Copy(self,i,j-i+1);
end;

function String32Helper.TrimLeft:String32;
var i:integer;
begin
  i:=0;
  while (i<System.Length(self)) and (self[i]<=32) do inc(i);
  result:=System.Copy(self,i,MaxInt);
end;

function String32Helper.TrimRight:String32;
var i:integer;
begin
  i:=high(self);
  while (i>=0) and (self[i]<=32) do dec(i);
  result:=System.Copy(self,0,i+1);
end;

function String32Helper.PadLeft(totalWidth:integer;paddingChar:UCS4Char):String32;
var i,pad:integer;
begin
  pad:=totalWidth-System.Length(self);
  if pad<=0 then result:=self
  else begin
    SetLength(result,totalWidth);
    for i:=0 to pad-1 do result[i]:=paddingChar;
    for i:=0 to high(self) do result[pad+i]:=self[i];
  end;
end;

function String32Helper.PadRight(totalWidth:integer;paddingChar:UCS4Char):String32;
var i,oldLen:integer;
begin
  oldLen:=System.Length(self);
  if totalWidth<=oldLen then result:=self
  else begin
    SetLength(result,totalWidth);
    for i:=0 to oldLen-1 do result[i]:=self[i];
    for i:=oldLen to totalWidth-1 do result[i]:=paddingChar;
  end;
end;

function String32Helper.Insert(const substr:String32;index:integer):String32;
var i,len1,len2:integer;
begin
  len1:=System.Length(self);
  len2:=System.Length(substr);
  SetLength(result,len1+len2);
  for i:=0 to index-1 do result[i]:=self[i];
  for i:=0 to len2-1 do result[index+i]:=substr[i];
  for i:=index to len1-1 do result[len2+i]:=self[i];
end;

function String32Helper.Remove(startIndex:integer):String32;
begin result:=System.Copy(self,0,startIndex); end;

function String32Helper.Remove(startIndex,count:integer):String32;
var i,tailLen:integer;
begin
  tailLen:=System.Length(self)-startIndex-count;
  SetLength(result,startIndex+tailLen);
  for i:=0 to startIndex-1 do result[i]:=self[i];
  for i:=0 to tailLen-1 do result[startIndex+i]:=self[startIndex+count+i];
end;

function String32Helper.Replace(const oldStr,newStr:String32):String32;
var p:integer;
begin
  result:=self;
  p:=result.IndexOf(oldStr);
  if p>=0 then
    result:=result.Left(p)+newStr+result.Substring(p+oldStr.Length);
end;

function String32Helper.ReplaceAll(const oldStr,newStr:String32):String32;
var p:integer;
begin
  result:=self;
  p:=0;
  repeat
    p:=result.IndexOf(oldStr,p);
    if p>=0 then begin
      result:=result.Left(p)+newStr+result.Substring(p+oldStr.Length);
      p:=p+newStr.Length;
    end;
  until p<0;
end;

function String32Helper.Split(delimiter:UCS4Char):Strings32;
var i,start,cnt:integer;
begin
  SetLength(result,16); cnt:=0; start:=0;
  for i:=0 to high(self) do
    if self[i]=delimiter then begin
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      result[cnt]:=System.Copy(self,start,i-start);
      inc(cnt); start:=i+1;
    end;
  if cnt>=System.Length(result) then SetLength(result,cnt+1);
  result[cnt]:=System.Copy(self,start,System.Length(self)-start);
  SetLength(result,cnt+1);
end;

class function String32Helper.Join(const arr:Strings32;const delimiter:String32):String32;
var i,j,pos,totalLen,delimLen:integer;
begin
  if System.Length(arr)=0 then begin SetLength(result,0); exit; end;
  delimLen:=System.Length(delimiter);
  totalLen:=0;
  for i:=0 to high(arr) do inc(totalLen,System.Length(arr[i]));
  inc(totalLen,delimLen*(System.Length(arr)-1));
  SetLength(result,totalLen);
  pos:=0;
  for i:=0 to high(arr) do begin
    if (i>0) and (delimLen>0) then
      for j:=0 to delimLen-1 do begin result[pos]:=delimiter[j]; inc(pos); end;
    for j:=0 to System.Length(arr[i])-1 do begin result[pos]:=arr[i][j]; inc(pos); end;
  end;
end;

function String32Helper.CountChar(ch:UCS4Char):integer;
var i:integer;
begin
  result:=0;
  for i:=0 to high(self) do
    if self[i]=ch then inc(result);
end;

function String32Helper.Reverse:String32;
var i,len:integer;
begin
  len:=System.Length(self);
  SetLength(result,len);
  for i:=0 to len-1 do result[len-1-i]:=self[i];
end;

function String32Helper.Duplicate(count:integer):String32;
var i,j,len,pos:integer;
begin
  len:=System.Length(self);
  SetLength(result,len*count);
  pos:=0;
  for i:=1 to count do
    for j:=0 to len-1 do begin result[pos]:=self[j]; inc(pos); end;
end;

// ============================================================================
// Strings8Helper
// ============================================================================

function Strings8Helper.Length:integer;
begin result:=System.Length(self); end;

function Strings8Helper.IsEmpty:boolean;
begin result:=System.Length(self)=0; end;

function Strings8Helper.IndexOf(const s:String8):integer;
var i:integer;
begin
  for i:=0 to high(self) do
    if self[i]=s then exit(i);
  result:=-1;
end;

function Strings8Helper.Contains(const s:String8):boolean;
begin result:=IndexOf(s)>=0; end;

procedure Strings8Helper.Add(const s:String8);
begin SetLength(self,System.Length(self)+1); self[high(self)]:=s; end;

procedure Strings8Helper.Insert(index:integer;const s:String8);
var i:integer;
begin
  SetLength(self,System.Length(self)+1);
  for i:=high(self) downto index+1 do self[i]:=self[i-1];
  self[index]:=s;
end;

procedure Strings8Helper.Delete(index:integer);
var i:integer;
begin
  for i:=index to high(self)-1 do self[i]:=self[i+1];
  SetLength(self,System.Length(self)-1);
end;

function Strings8Helper.Remove(const s:String8):boolean;
var idx:integer;
begin
  idx:=IndexOf(s);
  if idx<0 then exit(false);
  Delete(idx);
  result:=true;
end;

procedure Strings8Helper.Clear;
begin SetLength(self,0); end;

function Strings8Helper.Join(const delimiter:String8):String8;
var i:integer;
begin
  result:='';
  for i:=0 to high(self) do begin
    if i>0 then result:=result+delimiter;
    result:=result+self[i];
  end;
end;

procedure Strings8Helper.Sort;
var i,j:integer; tmp:String8;
begin
  // simple bubble sort
  for i:=0 to high(self)-1 do
    for j:=i+1 to high(self) do
      if self[j]<self[i] then begin
        tmp:=self[i]; self[i]:=self[j]; self[j]:=tmp;
      end;
end;

// ============================================================================
// Strings32Helper
// ============================================================================

function Strings32Helper.Length:integer;
begin result:=System.Length(self); end;

function Strings32Helper.IsEmpty:boolean;
begin result:=System.Length(self)=0; end;

function Strings32Helper.IndexOf(const s:String32):integer;
var i:integer;
begin
  for i:=0 to high(self) do
    if s.Equals(self[i]) then exit(i);
  result:=-1;
end;

function Strings32Helper.Contains(const s:String32):boolean;
begin result:=IndexOf(s)>=0; end;

procedure Strings32Helper.Add(const s:String32);
begin SetLength(self,System.Length(self)+1); self[high(self)]:=s; end;

procedure Strings32Helper.Insert(index:integer;const s:String32);
var i:integer;
begin
  SetLength(self,System.Length(self)+1);
  for i:=high(self) downto index+1 do self[i]:=self[i-1];
  self[index]:=s;
end;

procedure Strings32Helper.Delete(index:integer);
var i:integer;
begin
  for i:=index to high(self)-1 do self[i]:=self[i+1];
  SetLength(self,System.Length(self)-1);
end;

function Strings32Helper.Remove(const s:String32):boolean;
var idx:integer;
begin
  idx:=IndexOf(s);
  if idx<0 then exit(false);
  Delete(idx);
  result:=true;
end;

procedure Strings32Helper.Clear;
begin SetLength(self,0); end;

function Strings32Helper.Join(const delimiter:String32):String32;
var i,j,pos,totalLen,delimLen:integer;
begin
  if System.Length(self)=0 then begin SetLength(result,0); exit; end;
  delimLen:=System.Length(delimiter);
  totalLen:=0;
  for i:=0 to high(self) do inc(totalLen,System.Length(self[i]));
  inc(totalLen,delimLen*(System.Length(self)-1));
  SetLength(result,totalLen);
  pos:=0;
  for i:=0 to high(self) do begin
    if (i>0) and (delimLen>0) then
      for j:=0 to delimLen-1 do begin result[pos]:=delimiter[j]; inc(pos); end;
    for j:=0 to System.Length(self[i])-1 do begin result[pos]:=self[i][j]; inc(pos); end;
  end;
end;

// ============================================================================
// UTF8
// ============================================================================

class function UTF8.IsValid(const s:String8):boolean;
var i:integer; b:byte; cp:cardinal;
begin
  result:=true;
  i:=1;
  while i<=System.Length(s) do begin
    b:=byte(s[i]);
    if b<$80 then inc(i)
    else if (b and $E0)=$C0 then begin
      // 2-byte sequence
      if (i+1>System.Length(s)) or ((byte(s[i+1]) and $C0)<>$80) then exit(false);
      cp:=(b and $1F) shl 6 or (byte(s[i+1]) and $3F);
      // Check for overlong encoding (should be >= $80)
      if cp<$80 then exit(false);
      inc(i,2);
    end
    else if (b and $F0)=$E0 then begin
      // 3-byte sequence
      if (i+2>System.Length(s)) or ((byte(s[i+1]) and $C0)<>$80) or ((byte(s[i+2]) and $C0)<>$80) then exit(false);
      cp:=(b and $0F) shl 12 or ((byte(s[i+1]) and $3F) shl 6) or (byte(s[i+2]) and $3F);
      // Check for overlong encoding (should be >= $800)
      if cp<$800 then exit(false);
      inc(i,3);
    end
    else if (b and $F8)=$F0 then begin
      // 4-byte sequence
      if (i+3>System.Length(s)) or ((byte(s[i+1]) and $C0)<>$80) or ((byte(s[i+2]) and $C0)<>$80) or ((byte(s[i+3]) and $C0)<>$80) then exit(false);
      cp:=(b and $07) shl 18 or ((byte(s[i+1]) and $3F) shl 12) or ((byte(s[i+2]) and $3F) shl 6) or (byte(s[i+3]) and $3F);
      // Check for overlong encoding (should be >= $10000)
      if cp<$10000 then exit(false);
      // Check for codepoints beyond Unicode maximum (U+10FFFF)
      if cp>$10FFFF then exit(false);
      inc(i,4);
    end
    else exit(false);
  end;
end;

class function UTF8.CharCount(const s:String8):integer;
var i:integer; b:byte;
begin
  result:=0;
  i:=1;
  while i<=System.Length(s) do begin
    inc(result);
    b:=byte(s[i]);
    if b<$80 then inc(i)
    else if (b and $E0)=$C0 then inc(i,2)
    else if (b and $F0)=$E0 then inc(i,3)
    else if (b and $F8)=$F0 then inc(i,4)
    else inc(i); // invalid byte, skip it
  end;
end;

class function UTF8.Decode(const s:String8):String32;
var i,len:integer; b:byte; cp:cardinal;
begin
  SetLength(result,System.Length(s)); // max possible length
  len:=0;
  i:=1;
  while i<=System.Length(s) do begin
    b:=byte(s[i]);
    if b<$80 then begin
      result[len]:=b; inc(len); inc(i);
    end else if (b and $E0)=$C0 then begin
      // 2-byte sequence
      if i+1>System.Length(s) then break;
      cp:=((b and $1F) shl 6) or (byte(s[i+1]) and $3F);
      result[len]:=cp; inc(len); inc(i,2);
    end else if (b and $F0)=$E0 then begin
      // 3-byte sequence
      if i+2>System.Length(s) then break;
      cp:=((b and $0F) shl 12) or ((byte(s[i+1]) and $3F) shl 6) or (byte(s[i+2]) and $3F);
      result[len]:=cp; inc(len); inc(i,3);
    end else if (b and $F8)=$F0 then begin
      // 4-byte sequence
      if i+3>System.Length(s) then break;
      cp:=((b and $07) shl 18) or ((byte(s[i+1]) and $3F) shl 12) or ((byte(s[i+2]) and $3F) shl 6) or (byte(s[i+3]) and $3F);
      result[len]:=cp; inc(len); inc(i,4);
    end else begin
      // invalid byte, skip it
      inc(i);
    end;
  end;
  SetLength(result,len);
end;

class function UTF8.Encode(const s:String32):String8;
var i,len:integer; cp:cardinal;
begin
  SetLength(result,System.Length(s)*4); // max possible length
  len:=0;
  for i:=0 to high(s) do begin
    cp:=s[i];
    if cp<$80 then begin
      inc(len); result[len]:=AnsiChar(cp);
    end else if cp<$800 then begin
      inc(len); result[len]:=AnsiChar($C0 or (cp shr 6));
      inc(len); result[len]:=AnsiChar($80 or (cp and $3F));
    end else if cp<$10000 then begin
      inc(len); result[len]:=AnsiChar($E0 or (cp shr 12));
      inc(len); result[len]:=AnsiChar($80 or ((cp shr 6) and $3F));
      inc(len); result[len]:=AnsiChar($80 or (cp and $3F));
    end else begin
      inc(len); result[len]:=AnsiChar($F0 or (cp shr 18));
      inc(len); result[len]:=AnsiChar($80 or ((cp shr 12) and $3F));
      inc(len); result[len]:=AnsiChar($80 or ((cp shr 6) and $3F));
      inc(len); result[len]:=AnsiChar($80 or (cp and $3F));
    end;
  end;
  SetLength(result,len);
end;

class function UTF8.ToWide(const s:String8):WideString;
var s32:String32;
begin
  s32:=Decode(s);
  // TODO: proper UTF-16 encoding for codepoints > $FFFF
  SetLength(result,System.Length(s32));
  // simplified conversion (only BMP)
end;

class function UTF8.FromWide(const s:WideString):String8;
begin
  result:=''; // TODO
end;

class function UTF8.ToUpper(const s:String8):String8;
begin result:=s; {TODO: proper Unicode uppercase} end;

class function UTF8.ToLower(const s:String8):String8;
begin result:=s; {TODO: proper Unicode lowercase} end;

end.
