// String manipulation helpers - modern API for working with String8 (UTF-8) and String32 (UCS-4)
//
// SCOPE: String operations beyond basic RTL - splitting, trimming, searching, replacing,
// case conversion, encoding conversion (UTF-8, UTF-16, UCS-4).
//
// ADD HERE: Generic string operations that work with String8/String32, encoding conversions.
// DON'T ADD: Conversion to/from non-string types (→ Apus.Conv), unicode-specific text rendering,
// regular expressions, template engines.
//
// Contains: TString8Helper and TString32Helper with methods like Split, Trim, Contains,
// StartsWith, EndsWith, Replace, ToUpper, ToLower, IndexOf, etc.
// Indexing contract:
// - String8Helper: 1-based API (Pascal-style string indexing), not-found = 0
// - String32Helper: 0-based API (UCS4 array semantics), not-found = -1
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Strings;
{$Q-} // overflow checks off: hash functions rely on unsigned wraparound
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
    function IndexOf(const substr:String8;startPos:integer=1;ignoreCase:boolean=false):integer; overload; // returns 0 if not found, 1-based startPos, ASCII case-folding
    function IndexOf(ch:AnsiChar;startPos:integer=1):integer; overload;
    function LastIndexOf(const substr:String8;ignoreCase:boolean=false):integer; overload; // ASCII case-folding
    function LastIndexOf(ch:AnsiChar):integer; overload;
    function Contains(const substr:String8;ignoreCase:boolean=false):boolean; overload; // ASCII case-folding
    function Contains(ch:AnsiChar):boolean; overload;
    function StartsWith(const prefix:String8;ignoreCase:boolean=false):boolean;
    function EndsWith(const suffix:String8;ignoreCase:boolean=false):boolean;

    // === Comparison ===
    function Compare(const other:String8;ignoreCase:boolean=true):integer;
    function Same(const other:String8):boolean; // case-insensitive equals

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
    // Split by a single delimiter / by any char from the delimiters set.
    // quoteChar (#0=off) enables CSV-style quoting: a quoteChar is special only when
    // it OPENS a token; such a token has its enclosing quotes stripped and doubled
    // quoteChar ("") collapsed to one literal. Whitespace is NOT trimmed.
    function Split(delimiter:AnsiChar;quoteChar:AnsiChar=#0):Strings8; overload;
    function Split(const delimiters:String8;quoteChar:AnsiChar=#0):Strings8; overload;
    // Split by a single delimiter, escapeChar-style: escapeChar protects the next
    // char (incl. delimiter or escapeChar itself) and is removed from the output.
    function SplitEscaped(delimiter:AnsiChar;escapeChar:AnsiChar='\'):Strings8;
    function SplitLines:Strings8; // split by #13, #10, or #13#10
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
  // NOTE: String32 helper is intentionally 0-based because String32 is UCS4String (array-like).
  String32Helper = record helper for String32
    // === Properties ===
    function Length:integer; inline;
    function IsEmpty:boolean; inline;

    // === Character access ===
    function CharAt(index:integer):UCS4Char; inline; // 0-based, returns 0 if out of bounds
    function TryAnsiChar(index:integer;out ch:System.AnsiChar):boolean; inline; // 0-based
    function AnsiChar(index:integer;defaultChar:System.AnsiChar=#0):System.AnsiChar; inline; // 0-based
    function LastChar:UCS4Char; inline;
    function FirstChar:UCS4Char; inline; // alias for CharAt(0)

    // === Substring ===
    function Substring(startIndex:integer):String32; overload; // 0-based
    function Substring(startIndex,len:integer):String32; overload; // 0-based
    function Left(count:integer):String32;
    function Right(count:integer):String32;

    // === Search ===
    function IndexOf(const substr:String32;startPos:integer=0;ignoreCase:boolean=false):integer; overload; // 0-based, returns -1 if not found, ASCII case-folding
    function IndexOf(ch:UCS4Char):integer; overload; // returns -1 if not found
    function IndexOf(ch:UCS4Char;startPos:integer):integer; overload; // 0-based, returns -1 if not found
    function LastIndexOf(const substr:String32;ignoreCase:boolean=false):integer; overload; // returns -1 if not found, ASCII case-folding
    function LastIndexOf(ch:UCS4Char):integer; overload; // returns -1 if not found
    function Contains(const substr:String32;ignoreCase:boolean=false):boolean; overload; // ASCII case-folding
    function Contains(ch:UCS4Char):boolean; overload;
    function StartsWith(const prefix:String32):boolean;
    function EndsWith(const suffix:String32):boolean;

    // === Comparison ===
    function Compare(const other:String32;ignoreCase:boolean=true):integer;
    function Equals(const other:String32):boolean; // case-sensitive (= not usable for dynamic arrays)
    function Same(const other:String32):boolean; // case-insensitive

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
    // Same semantics as String8.Split: quoteChar (0=off) enables CSV-style quoting
    // (special only when opening a token; outer quotes stripped, doubled quoteChar
    // collapsed to one literal; whitespace not trimmed).
    function Split(delimiter:UCS4Char):Strings32; overload;
    function Split(const delimiters:String32;quoteChar:UCS4Char=0):Strings32; overload;
    class function Join(const arr:Strings32;const delimiter:String32):String32; static;

    // === Utility ===
    function CountChar(ch:UCS4Char):integer;
    function Reverse:String32;
    function Duplicate(count:integer):String32;

    {$IFDEF DELPHI}
    class operator Implicit(const src:String32):string; inline;
    class operator Implicit(const src:string):String32; inline;
    {$ENDIF}
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
    function JoinEscaped(delimiter:AnsiChar;escapeChar:AnsiChar='\'):String8;
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
    // Check if string starts with UTF-8 BOM
    class function HasBOM(const s:RawByteString):boolean; static; inline;
    // Get character count (not byte count)
    class function CharCount(const s:String8):integer; static;
    // Convert UTF-8 <-> String32 (UCS-4)
    class function Decode(const s:String8):String32; overload; static;
    class function Encode(const s:String32):String8; overload; static;
    // Convert WideString (UTF-16) -> UTF-8
    class function Encode(const s:WideString;addBOM:boolean=false):String8; overload; static;
    // Convert UTF-8 <-> WideString (UTF-16)
    class function ToWide(const s:String8):WideString; static;
    class function FromWide(const s:WideString):String8; static; inline;
    // Upper/Lower case for UTF-8 (Unicode-aware)
    class function ToUpper(const s:String8):String8; static;
    class function ToLower(const s:String8):String8; static;
    // Format string: %d %u %x %X %f %g %s %p %% with flags - 0 + and width.precision
    class function Format(const fmt:String8; const args:array of const):String8; static;
  end;

  // Forward cursor over a list of String8 values with typed sequential reads.
  // A lightweight reader for decoded messages / field lists: fill `values`
  // (e.g. via SplitEscaped), reset `index` to 0, then pull fields with Next*.
  TStringsReader = record
    values:Strings8;
    index:integer;                     // read cursor for the Next* accessors
    function NextInt:integer;          // next value as int (-1 if past end), advances cursor
    function NextStr:String8;          // next value ('' if past end), advances cursor
    function Empty:boolean;            // cursor past the last value?
    function Int(idx:integer):integer; // value[idx] as int (0 if out of range), cursor unchanged
  end;

// === String type conversion ===
// Convert any string type to String8 (UTF-8)
function Str8(const st:UnicodeString):String8; overload; inline;
function Str8(const st:WideString):String8; overload; inline;
function Str8(const st:UTF8String):String8; overload; inline;
{$IFDEF UNICODE}
function Str8(const st:AnsiString):String8; overload; inline;
{$ENDIF}
// Convert any string type to String16 (WideString)
function Str16(const st:UnicodeString):String16; overload; inline;
function Str16(const st:WideString):String16; overload; inline;
function Str16(const st:UTF8String):String16; overload;
{$IFDEF UNICODE}
function Str16(const st:AnsiString):String16; overload;
{$ENDIF}
// Convert any string type to String32 (UCS-4)
function Str32(const st:String8):String32; overload;
function Str32(const st:WideString):String32; overload;
{$IFDEF UNICODE}
function Str32(const st:UnicodeString):String32; overload;
{$ENDIF}

// Simple fast hash function for strings (case-insensitive)
function FastHash(const st:String8):cardinal; overload;
function FastHash(const st:String16):cardinal; overload;

// Extract string representation from TVarRec argument
function VarRecToStr(const v:TVarRec):String8;

// String hash function (case-sensitive)
function StrHash(const st:String8):cardinal; overload;
function StrHash(const st:String16):cardinal; overload;
{$IFNDEF UNICODE}
function StrHash(const st:string):cardinal; overload;
{$ENDIF}

implementation
uses SysUtils, Apus.Conv;

function UpAscii(ch:AnsiChar):AnsiChar; inline;
begin
  if (ch>='a') and (ch<='z') then dec(ch,ord('a')-ord('A'));
  result:=ch;
end;

function CompareString8Bytes(const a,b:String8;ignoreCase:boolean):integer;
var
  i,lenA,lenB,minLen:integer;
  c1,c2:AnsiChar;
begin
  lenA:=System.Length(a);
  lenB:=System.Length(b);
  if lenA<lenB then minLen:=lenA
  else minLen:=lenB;
  for i:=1 to minLen do begin
    c1:=a[i]; c2:=b[i];
    if ignoreCase then begin
      c1:=UpAscii(c1);
      c2:=UpAscii(c2);
    end;
    if c1<>c2 then
      exit(ord(c1)-ord(c2));
  end;
  result:=lenA-lenB;
end;

function SameString8Bytes(const a,b:String8;ignoreCase:boolean):boolean;
begin
  result:=(System.Length(a)=System.Length(b)) and
    (CompareString8Bytes(a,b,ignoreCase)=0);
end;

function IsTrimByte(ch:AnsiChar):boolean; inline;
begin
  result:=ord(ch)<=32;
end;

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

function String8Helper.IndexOf(const substr:String8;startPos:integer;ignoreCase:boolean):integer;
var
  i,j,subLen,selfLen,lastStart:integer;
  found:boolean;
  c1,c2:AnsiChar;
begin
  if not ignoreCase then
    exit(System.Pos(substr,self,startPos));
  selfLen:=System.Length(self);
  subLen:=System.Length(substr);
  if startPos<1 then startPos:=1;
  if subLen=0 then begin
    if startPos<=selfLen+1 then result:=startPos
    else result:=0;
    exit;
  end;
  lastStart:=selfLen-subLen+1;
  if startPos>lastStart then exit(0);
  for i:=startPos to lastStart do begin
    found:=true;
    for j:=1 to subLen do begin
      c1:=self[i+j-1];
      c2:=substr[j];
      if (c1>='a') and (c1<='z') then dec(c1,ord('a')-ord('A'));
      if (c2>='a') and (c2<='z') then dec(c2,ord('a')-ord('A'));
      if c1<>c2 then begin
        found:=false;
        break;
      end;
    end;
    if found then exit(i);
  end;
  result:=0;
end;

function String8Helper.IndexOf(ch:AnsiChar;startPos:integer):integer;
var i:integer;
begin
  for i:=startPos to System.Length(self) do
    if self[i]=ch then exit(i);
  result:=0;
end;

function String8Helper.LastIndexOf(const substr:String8;ignoreCase:boolean):integer;
var p:integer;
begin
  result:=0; p:=1;
  repeat
    p:=IndexOf(substr,p,ignoreCase);
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

function String8Helper.Contains(const substr:String8;ignoreCase:boolean):boolean;
begin result:=IndexOf(substr,1,ignoreCase)>0; end;

function String8Helper.Contains(ch:AnsiChar):boolean;
begin result:=IndexOf(ch)>0; end;

function String8Helper.StartsWith(const prefix:String8;ignoreCase:boolean):boolean;
var i,len:integer; c1,c2:AnsiChar;
begin
  len:=System.Length(prefix);
  if len>System.Length(self) then exit(false);
  for i:=1 to len do begin
    c1:=self[i]; c2:=prefix[i];
    if ignoreCase then begin
      c1:=UpAscii(c1);
      c2:=UpAscii(c2);
    end;
    if c1<>c2 then exit(false);
  end;
  result:=true;
end;

function String8Helper.EndsWith(const suffix:String8;ignoreCase:boolean):boolean;
var i,len,ofs:integer; c1,c2:AnsiChar;
begin
  len:=System.Length(suffix);
  if len>System.Length(self) then exit(false);
  ofs:=System.Length(self)-len;
  for i:=1 to len do begin
    c1:=self[ofs+i]; c2:=suffix[i];
    if ignoreCase then begin
      c1:=UpAscii(c1);
      c2:=UpAscii(c2);
    end;
    if c1<>c2 then exit(false);
  end;
  result:=true;
end;

function String8Helper.Compare(const other:String8;ignoreCase:boolean):integer;
begin
  result:=CompareString8Bytes(self,other,ignoreCase);
end;

function String8Helper.Same(const other:String8):boolean;
begin result:=SameString8Bytes(self,other,true); end;

function String8Helper.ToUpper:String8;
begin result:=UTF8.ToUpper(self); end;

function String8Helper.ToLower:String8;
begin result:=UTF8.ToLower(self); end;

function String8Helper.Trim:String8;
var first,last:integer;
begin
  first:=1; last:=System.Length(self);
  while (first<=last) and IsTrimByte(self[first]) do inc(first);
  while (last>=first) and IsTrimByte(self[last]) do dec(last);
  if (first=1) and (last=System.Length(self)) then result:=self
  else result:=System.Copy(self,first,last-first+1);
end;

function String8Helper.TrimLeft:String8;
var first,last:integer;
begin
  first:=1; last:=System.Length(self);
  while (first<=last) and IsTrimByte(self[first]) do inc(first);
  if first=1 then result:=self
  else result:=System.Copy(self,first,last-first+1);
end;

function String8Helper.TrimRight:String8;
var last:integer;
begin
  last:=System.Length(self);
  while (last>=1) and IsTrimByte(self[last]) do dec(last);
  if last=System.Length(self) then result:=self
  else result:=System.Copy(self,1,last);
end;

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
var
  p,oldLen,newLen,selfLen:integer;
begin
  oldLen:=System.Length(oldStr);
  if oldLen=0 then exit(self);
  p:=IndexOf(oldStr);
  if p=0 then exit(self);
  newLen:=System.Length(newStr);
  selfLen:=System.Length(self);
  SetLength(result,selfLen-oldLen+newLen);
  if p>1 then Move(self[1],result[1],p-1);
  if newLen>0 then Move(newStr[1],result[p],newLen);
  if p+oldLen<=selfLen then
    Move(self[p+oldLen],result[p+newLen],selfLen-p-oldLen+1);
end;

function String8Helper.ReplaceAll(const oldStr,newStr:String8):String8;
var
  p,nextP,src,dst,cnt,oldLen,newLen,selfLen,resultLen,segLen:integer;
begin
  oldLen:=System.Length(oldStr);
  if oldLen=0 then exit(self);
  selfLen:=System.Length(self);
  newLen:=System.Length(newStr);
  cnt:=0; p:=1;
  repeat
    p:=IndexOf(oldStr,p);
    if p>0 then begin
      inc(cnt);
      inc(p,oldLen);
    end;
  until p=0;
  if cnt=0 then exit(self);
  resultLen:=selfLen+cnt*(newLen-oldLen);
  SetLength(result,resultLen);
  src:=1; dst:=1; p:=1;
  repeat
    nextP:=IndexOf(oldStr,p);
    if nextP=0 then break;
    segLen:=nextP-src;
    if segLen>0 then Move(self[src],result[dst],segLen);
    inc(dst,segLen);
    if newLen>0 then Move(newStr[1],result[dst],newLen);
    inc(dst,newLen);
    src:=nextP+oldLen;
    p:=src;
  until false;
  if src<=selfLen then Move(self[src],result[dst],selfLen-src+1);
end;

function String8Helper.Split(delimiter:AnsiChar;quoteChar:AnsiChar):Strings8;
var d:String8;
begin
  SetLength(d,1); d[1]:=delimiter;
  result:=Split(d,quoteChar);
end;

// A quoteChar is only special when it opens a token (sits right after a delimiter).
// A quoted token gets its enclosing quotes stripped and doubled quoteChar collapsed
// to a single literal one. Whitespace is never trimmed.
function String8Helper.Split(const delimiters:String8;quoteChar:AnsiChar):Strings8;
var
  i,k,len,start,cnt:integer;
  doubled:boolean;
  token:String8;
begin
  len:=System.Length(self);
  SetLength(result,16); cnt:=0; start:=1;
  while true do begin
    if (start<=len) and (quoteChar<>#0) and (self[start]=quoteChar) then begin
      // quoted token: locate closing quote (skipping doubled pairs), then build content
      doubled:=false;
      i:=start+1;
      while i<=len do begin
        if self[i]=quoteChar then begin
          if (i<len) and (self[i+1]=quoteChar) then begin
            doubled:=true; inc(i,2); // doubled quote
          end else break; // closing quote
        end else inc(i);
      end;
      // content is self[start+1 .. i-1], with enclosing quotes stripped
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      if not doubled then
        result[cnt]:=System.Copy(self,start+1,i-start-1) // fast path: contiguous content
      else begin
        token:='';
        k:=start+1;
        while k<i do begin
          token:=token+self[k]; // collapse each doubled quoteChar to one literal
          if (self[k]=quoteChar) and (k+1<i) and (self[k+1]=quoteChar) then inc(k,2)
            else inc(k);
        end;
        result[cnt]:=token;
      end;
      inc(cnt);
      if i>len then break; // unterminated, or string ends at closing quote
      inc(i); // skip closing quote
      while (i<=len) and (System.Pos(self[i],delimiters)=0) do inc(i); // discard up to next delimiter
      if i>len then break;
      start:=i+1;
    end else begin
      // unquoted token: copy verbatim up to next delimiter
      i:=start;
      while (i<=len) and (System.Pos(self[i],delimiters)=0) do inc(i);
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      if i>len then begin
        result[cnt]:=System.Copy(self,start,len-start+1); inc(cnt); break;
      end;
      result[cnt]:=System.Copy(self,start,i-start); inc(cnt);
      start:=i+1;
    end;
  end;
  SetLength(result,cnt);
end;

function String8Helper.SplitEscaped(delimiter:AnsiChar;escapeChar:AnsiChar):Strings8;
var
  i,cnt:integer;
  escaped:boolean;
begin
  result:=nil;
  SetLength(result,1);
  cnt:=0;
  escaped:=false;
  for i:=1 to System.Length(self) do begin
    if escaped then begin
      result[cnt]:=result[cnt]+self[i];
      escaped:=false;
    end else
    if self[i]=escapeChar then
      escaped:=true
    else
    if self[i]=delimiter then begin
      inc(cnt);
      SetLength(result,cnt+1);
    end else
      result[cnt]:=result[cnt]+self[i];
  end;
end;

function String8Helper.SplitLines:Strings8;
var i,start,cnt,len:integer;
begin
  len:=System.Length(self);
  SetLength(result,16); cnt:=0; start:=1;
  i:=1;
  while i<=len do begin
    if (self[i]=#13) or (self[i]=#10) then begin
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      result[cnt]:=System.Copy(self,start,i-start);
      inc(cnt);
      if (self[i]=#13) and (i<len) and (self[i+1]=#10) then inc(i); // skip \r\n
      start:=i+1;
    end;
    inc(i);
  end;
  if cnt>=System.Length(result) then SetLength(result,cnt+1);
  result[cnt]:=System.Copy(self,start,len-start+1);
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
var len:integer;
begin
  len:=System.Length(self);
  SetLength(result,len+2);
  result[1]:=quoteChar;
  if len>0 then Move(self[1],result[2],len);
  result[len+2]:=quoteChar;
end;

function String8Helper.Unquote:String8;
var len:integer;
begin
  len:=System.Length(self);
  if (len>=2) and (self[1]=self[len]) and (self[1] in ['"','''']) then
    result:=System.Copy(self,2,len-2)
  else result:=self;
end;

function String8Helper.Escape:String8;
const
  escN:String8='\n';
  escR:String8='\r';
  escT:String8='\t';
  escSlash:String8='\\';
var i:integer;
begin
  result:='';
  for i:=1 to System.Length(self) do
    case self[i] of
      #10: result:=result+escN;
      #13: result:=result+escR;
      #9:  result:=result+escT;
      '\': result:=result+escSlash;
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
const
  HexChars:String8='0123456789ABCDEF';
  percent:AnsiChar='%';
var i:integer; b:byte;
begin
  result:='';
  for i:=1 to System.Length(self) do begin
    b:=byte(self[i]);
    if (self[i] in ['A'..'Z','a'..'z','0'..'9','-','_','.','~']) then
      result:=result+self[i]
    else
      result:=result+percent+HexChars[1+b shr 4]+HexChars[1+b and $F];
  end;
end;

function String8Helper.UrlDecode:String8;
const space:AnsiChar=' ';
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
      result:=result+space; inc(i);
    end else begin
      result:=result+self[i]; inc(i);
    end;
  end;
end;

function String8Helper.HtmlEscape:String8;
const
  escAmp:String8='&amp;';
  escLt:String8='&lt;';
  escGt:String8='&gt;';
  escQuote:String8='&quot;';
  escApos:String8='&#39;';
var i:integer;
begin
  result:='';
  for i:=1 to System.Length(self) do
    case self[i] of
      '&': result:=result+escAmp;
      '<': result:=result+escLt;
      '>': result:=result+escGt;
      '"': result:=result+escQuote;
      '''':result:=result+escApos;
      else result:=result+self[i];
    end;
end;

function String8Helper.HtmlUnescape:String8;
const
  amp:String8='&amp;';
  lt:String8='&lt;';
  gt:String8='&gt;';
  quot:String8='&quot;';
  aposNum:String8='&#39;';
  aposName:String8='&apos;';
  ampCh:String8='&';
  ltCh:String8='<';
  gtCh:String8='>';
  quoteCh:String8='"';
  aposCh:String8='''';
begin
  result:=self;
  result:=result.ReplaceAll(amp,ampCh);
  result:=result.ReplaceAll(lt,ltCh);
  result:=result.ReplaceAll(gt,gtCh);
  result:=result.ReplaceAll(quot,quoteCh);
  result:=result.ReplaceAll(aposNum,aposCh);
  result:=result.ReplaceAll(aposName,aposCh);
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
begin result:=Conv.ToInt(self,0); end;

function String8Helper.ToInt64:int64;
begin result:=Conv.ToInt(self,0); end;

function String8Helper.ToDouble:double;
begin result:=Conv.ToFloat(self); end;

function String8Helper.ToBoolean:boolean;
begin result:=Conv.ToBool(self); end;

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

function String32Helper.TryAnsiChar(index:integer;out ch:System.AnsiChar):boolean;
var
  c:UCS4Char;
begin
  ch:=#0;
  if (index<0) or (index>=System.Length(self)) then exit(false);
  c:=self[index];
  if c>255 then exit(false);
  ch:=System.AnsiChar(byte(c));
  result:=true;
end;

function String32Helper.AnsiChar(index:integer;defaultChar:System.AnsiChar):System.AnsiChar;
var
  ch:System.AnsiChar;
begin
  if TryAnsiChar(index,ch) then result:=ch
  else result:=defaultChar;
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

function String32Helper.IndexOf(const substr:String32;startPos:integer;ignoreCase:boolean):integer;
var i,j,lastStart:integer; found:boolean;
    c1,c2:UCS4Char;
begin
  if startPos<0 then startPos:=0;
  lastStart:=System.Length(self)-System.Length(substr);
  for i:=startPos to lastStart do begin
    found:=true;
    for j:=0 to high(substr) do begin
      c1:=self[i+j];
      c2:=substr[j];
      if ignoreCase then begin
        if (c1>=ord('A')) and (c1<=ord('Z')) then c1:=c1+32;
        if (c2>=ord('A')) and (c2<=ord('Z')) then c2:=c2+32;
      end;
      if c1<>c2 then begin found:=false; break; end;
    end;
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

{$IFDEF DELPHI}
class operator String32Helper.Implicit(const src:string):String32;
begin
  result:=UTF8.Decode(src);
end;

class operator String32Helper.Implicit(const src:String32):string;
begin
  result:=UTF8.Encode(src);
end;
{$ENDIF}

function String32Helper.IndexOf(ch:UCS4Char;startPos:integer):integer;
var i:integer;
begin
  for i:=startPos to high(self) do
    if self[i]=ch then exit(i);
  result:=-1;
end;

function String32Helper.LastIndexOf(const substr:String32;ignoreCase:boolean):integer;
var p:integer;
begin
  result:=-1; p:=0;
  repeat
    p:=IndexOf(substr,p,ignoreCase);
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

function String32Helper.Contains(const substr:String32;ignoreCase:boolean):boolean;
begin result:=IndexOf(substr,0,ignoreCase)>=0; end;

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

function String32Helper.Compare(const other:String32;ignoreCase:boolean):integer;
var i,minLen:integer; c1,c2:UCS4Char;
begin
  minLen:=System.Length(self);
  if System.Length(other)<minLen then minLen:=System.Length(other);
  for i:=0 to minLen-1 do begin
    c1:=self[i]; c2:=other[i];
    if ignoreCase then begin
     if (c1>=ord('A')) and (c1<=ord('Z')) then c1:=c1+32;
     if (c2>=ord('A')) and (c2<=ord('Z')) then c2:=c2+32;
    end;
    result:=integer(c1)-integer(c2);
    if result<>0 then exit;
  end;
  result:=System.Length(self)-System.Length(other);
end;

function String32Helper.Equals(const other:String32):boolean;
begin result:=Compare(other,false)=0; end;

function String32Helper.Same(const other:String32):boolean;
begin result:=Compare(other)=0; end;

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
  s1,s2:String32;
begin
  result:=self;
  p:=result.IndexOf(oldStr);
  if p>=0 then
  begin
    // FPC fails to produce valid code for this, so need to manually use intermediate variables (Delphi works fine)
    //    result:=result.Left(p)+newStr+result.Substring(p+oldStr.Length);
    s1:=result.Left(p);
    s2:=result.Substring(p+oldStr.Length);
    result:=s1+newStr+s2;
  end;
end;

function String32Helper.ReplaceAll(const oldStr,newStr:String32):String32;
var p:integer;
  s1,s2:string32;
begin
  result:=self;
  p:=0;
  repeat
    p:=result.IndexOf(oldStr,p);
    if p>=0 then begin
      // FPC fails to produce valid code for simple expression, so need to manually use intermediate variables (Delphi works fine)
      s1:=result.Left(p);
      s2:=result.Substring(p+oldStr.Length);
      result:=s1+newStr+s2;
      p:=p+newStr.Length;
    end;
  until p<0;
end;

function String32Helper.Split(delimiter:UCS4Char):Strings32;
var
  delim:String32;
begin
  SetLength(delim,1);
  delim[0]:=delimiter;
  result:=Split(delim,0);
end;

// Mirrors String8.Split quote semantics: a quoteChar is only special when it opens
// a token; quoted tokens get outer quotes stripped and doubled quoteChar collapsed.
function String32Helper.Split(const delimiters:String32;quoteChar:UCS4Char):Strings32;
var
  i,j,k,m,len,start,cnt:integer;
  isDelim,doubled:boolean;
begin
  len:=System.Length(self);
  SetLength(result,16); cnt:=0; start:=0;
  while true do begin
    if (start<len) and (quoteChar<>0) and (self[start]=quoteChar) then begin
      // quoted token: locate closing quote (skipping doubled pairs), then build content
      doubled:=false;
      i:=start+1;
      while i<len do begin
        if self[i]=quoteChar then begin
          if (i<len-1) and (self[i+1]=quoteChar) then begin
            doubled:=true; inc(i,2); // doubled quote
          end else break; // closing quote
        end else inc(i);
      end;
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      if not doubled then
        result[cnt]:=System.Copy(self,start+1,i-start-1) // fast path: content is contiguous
      else begin
        SetLength(result[cnt],i-start-1); // upper bound, trimmed below
        m:=0; k:=start+1;
        while k<i do begin
          result[cnt][m]:=self[k];
          if (self[k]=quoteChar) and (k+1<i) and (self[k+1]=quoteChar) then inc(k,2)
            else inc(k);
          inc(m);
        end;
        SetLength(result[cnt],m);
      end;
      inc(cnt);
      if i>=len then break; // unterminated, or string ends at closing quote
      inc(i); // skip closing quote
      // discard chars between closing quote and the next delimiter
      while i<len do begin
        isDelim:=false;
        for j:=0 to high(delimiters) do
          if self[i]=delimiters[j] then begin isDelim:=true; break; end;
        if isDelim then break;
        inc(i);
      end;
      if i>=len then break;
      start:=i+1;
    end else begin
      // unquoted token: copy verbatim up to next delimiter
      i:=start;
      while i<len do begin
        isDelim:=false;
        for j:=0 to high(delimiters) do
          if self[i]=delimiters[j] then begin isDelim:=true; break; end;
        if isDelim then break;
        inc(i);
      end;
      if cnt>=System.Length(result) then SetLength(result,cnt*2);
      result[cnt]:=System.Copy(self,start,i-start); inc(cnt);
      if i>=len then break;
      start:=i+1;
    end;
  end;
  SetLength(result,cnt);
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

function Strings8Helper.JoinEscaped(delimiter:AnsiChar;escapeChar:AnsiChar):String8;
var
  i,j:integer;
  st:String8;
begin
  result:='';
  for i:=0 to high(self) do begin
    if i>0 then result:=result+delimiter;
    st:=self[i];
    for j:=1 to System.Length(st) do begin
      if (st[j]=delimiter) or (st[j]=escapeChar) then
        result:=result+escapeChar;
      result:=result+st[j];
    end;
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
// String type conversion (Str8, Str16, Str32)
// ============================================================================

function Str8(const st:UnicodeString):String8;
begin
  result:=UTF8.Encode(st);
end;

function Str8(const st:WideString):String8;
begin
  result:=UTF8.Encode(st);
end;

function Str8(const st:UTF8String):String8;
begin
  result:=st;
end;

{$IFDEF UNICODE}
function Str8(const st:AnsiString):String8;
begin
  result:=String8(st);
end;
{$ENDIF}

function Str16(const st:UnicodeString):String16;
begin
  result:=st;
end;

function Str16(const st:WideString):String16;
begin
  result:=st;
end;

function Str16(const st:UTF8String):String16;
begin
  result:=UTF8.ToWide(st);
end;

{$IFDEF UNICODE}
function Str16(const st:AnsiString):String16;
begin
  result:=UTF8.ToWide(st);
end;
{$ENDIF}

function Str32(const st:String8):String32;
begin
  result:=UTF8.Decode(st);
end;

function Str32(const st:WideString):String32;
var
  i:integer;
begin
  SetLength(result,length(st));
  for i:=1 to length(st) do
    result[i-1]:=UCS4Char(word(st[i]));
end;

{$IFDEF UNICODE}
function Str32(const st:UnicodeString):String32;
begin
  result:=Str32(WideString(st));
end;
{$ENDIF}

// ============================================================================
// UTF8
// ============================================================================

class function UTF8.HasBOM(const s:RawByteString):boolean;
begin
  result:=(length(s)>=3) and (s[1]=#$EF) and (s[2]=#$BB) and (s[3]=#$BF);
end;

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

class function UTF8.Encode(const s:WideString;addBOM:boolean):String8;
var
 i,l:integer;
 w:word;
begin
 SetLength(result,3+length(s)*3);
 l:=0;
 if addBOM then begin
  result[1]:=#$EF; result[2]:=#$BB; result[3]:=#$BF;
  l:=3;
 end;
 for i:=1 to length(s) do begin
  w:=word(s[i]);
  if w<$80 then begin
   inc(l); result[l]:=AnsiChar(w);
  end else
  if w<$800 then begin
   inc(l); result[l]:=AnsiChar($C0 or (w shr 6));
   inc(l); result[l]:=AnsiChar($80 or (w and $3F));
  end else begin
   inc(l); result[l]:=AnsiChar($E0 or (w shr 12));
   inc(l); result[l]:=AnsiChar($80 or ((w shr 6) and $3F));
   inc(l); result[l]:=AnsiChar($80 or (w and $3F));
  end;
 end;
 SetLength(result,l);
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
var
 i,l:integer;
 w:word;
 src:RawByteString;
begin
 src:=s;
 if (length(src)>=3) and (src[1]=#$EF) and (src[2]=#$BB) and (src[3]=#$BF) then
  delete(src,1,3); // remove BOM
 SetLength(result,length(src));
 l:=0;
 i:=1;
 while i<=length(src) do begin
  w:=0;
  if byte(src[i]) and $80=0 then begin
   w:=byte(src[i]) and $7F;
   inc(i);
  end else
  if byte(src[i]) and $E0=$C0 then begin
   w:=byte(src[i]) and $1F;
   inc(i);
   if i<=length(src) then w:=w shl 6+byte(src[i]) and $3F;
   inc(i);
  end else
  if byte(src[i]) and $F0=$E0 then begin
   w:=byte(src[i]) and $0F;
   inc(i);
   if i<=length(src) then w:=w shl 6+byte(src[i]) and $3F;
   inc(i);
   if i<=length(src) then w:=w shl 6+byte(src[i]) and $3F;
   inc(i);
  end else
   inc(i);
  inc(l);
  result[l]:=WideChar(w);
 end;
 SetLength(result,l);
end;

class function UTF8.FromWide(const s:WideString):String8;
begin
  result:=Encode(s);
end;

class function UTF8.ToUpper(const s:String8):String8;
var i:integer; ch:AnsiChar;
begin
  result:=s;
  for i:=1 to System.Length(result) do begin
    ch:=result[i];
    if (ch>='a') and (ch<='z') then dec(result[i],ord('a')-ord('A'));
  end;
end;

class function UTF8.ToLower(const s:String8):String8;
var i:integer; ch:AnsiChar;
begin
  result:=s;
  for i:=1 to System.Length(result) do begin
    ch:=result[i];
    if (ch>='A') and (ch<='Z') then inc(result[i],ord('a')-ord('A'));
  end;
end;

{$R-} // hash functions rely on unsigned overflow
function FastHash(const st:String8):cardinal; overload;
var
  l,i:integer;
begin
  l:=length(st);
  if l<4 then begin
    result:=0;
    for i:=1 to l do
      result:=result*$20844 xor (byte(st[i]) and $1F);
  end else begin
    result:=l*131+byte(st[1]) and $1F;
    for i:=l-3 to l do begin
      result:=result*$20844 xor (byte(st[i]) and $1F);
    end;
  end;
end;

function FastHash(const st:String16):cardinal; overload;
var
  l,i:integer;
begin
  l:=length(st);
  if l<4 then begin
    result:=0;
    for i:=1 to l do
      result:=result*$20844 xor (word(st[i]) and $1F);
  end else begin
    result:=l*131+word(st[1]) and $1F;
    for i:=l-3 to l do begin
      result:=result*$20844 xor (word(st[i]) and $1F);
    end;
  end;
end;

function StrHash(const st:String8):cardinal; overload;
var
  i:integer;
begin
  result:=0;
  for i:=1 to length(st) do
    result:=cardinal(result*$20844) xor byte(st[i]);
end;

function StrHash(const st:String16):cardinal; overload;
var
  i:integer;
begin
  result:=0;
  for i:=1 to length(st) do
    result:=cardinal(result*$20844) xor byte(st[i]);
end;

{$IFNDEF UNICODE}
function StrHash(const st:string):cardinal; overload;
var
  i:integer;
begin
  result:=0;
  for i:=1 to length(st) do
    result:=cardinal(result*$20844) xor byte(st[i]);
end;
{$ENDIF}
{$R+}

// ============================================================================
// Format helpers (used by String8Helper.Format)
// ============================================================================

// Extract string representation from TVarRec argument
function VarRecToStr(const v:TVarRec):String8;
begin
  case v.VType of
    vtInteger:    result:=Conv.ToStr(int64(v.VInteger));
    vtInt64:      result:=Conv.ToStr(v.VInt64^);
    vtBoolean:    if v.VBoolean then result:='true' else result:='false';
    vtChar:       result:=AnsiChar(v.VChar);
    vtPChar:      result:=String8(v.VPChar);
    vtString:     result:=String8(v.VString^);
    vtAnsiString: result:=String8(AnsiString(v.VAnsiString));
    vtPointer:    result:=Conv.ToStr(v.VPointer);
    vtExtended:   Str(v.VExtended^,result);
    {$IFDEF UNICODE}
    vtWideChar:      result:=UTF8Encode(UnicodeString(v.VWideChar));
    vtWideString:    result:=UTF8Encode(WideString(v.VWideString));
    vtUnicodeString: result:=UTF8Encode(UnicodeString(v.VUnicodeString));
    {$ENDIF}
    {$IFDEF FPC}
    vtQWord: result:=Conv.ToStr(int64(v.VQWord^));
    {$ENDIF}
    else result:='?';
  end;
end;

// Extract int64 from TVarRec argument
function VarRecToInt(const v:TVarRec):int64;
begin
  case v.VType of
    vtInteger: result:=v.VInteger;
    vtInt64:   result:=v.VInt64^;
    vtBoolean: result:=ord(v.VBoolean);
    vtChar:    result:=ord(v.VChar);
    {$IFDEF FPC}
    vtQWord: result:=int64(v.VQWord^);
    {$ENDIF}
    else result:=0;
  end;
end;

// Extract double from TVarRec argument
function VarRecToFloat(const v:TVarRec):double;
begin
  case v.VType of
    vtExtended:  result:=v.VExtended^;
    vtInteger:   result:=v.VInteger;
    vtInt64:     result:=v.VInt64^;
    vtCurrency:  result:=v.VCurrency^;
    {$IFDEF FPC}
    vtQWord: result:=double(v.VQWord^);
    {$ENDIF}
    else result:=0;
  end;
end;

// Format int64: base=10 or 16, uppercase hex, minimum digit count
function FormatInt8(v:int64;base:integer;upperCase:boolean;minDigits:integer;showSign:boolean):String8;
const
  HexU:String8='0123456789ABCDEF';
  HexL:String8='0123456789abcdef';
var
  uv:uint64;
  neg:boolean;
  hexChars:PString8;
begin
  result:='';
  if base=16 then begin
    if upperCase then hexChars:=@HexU else hexChars:=@HexL;
    uv:=uint64(v);
    repeat
      result:=hexChars^[(uv and 15)+1]+result;
      uv:=uv shr 4;
    until uv=0;
  end else begin
    neg:=v<0;
    if neg then uv:=uint64(-v) else uv:=uint64(v);
    if uv=0 then result:='0'
    else
      repeat
        result:=AnsiChar(ord('0')+(uv mod 10))+result;
        uv:=uv div 10;
      until uv=0;
    if neg then result:='-'+result
    else if showSign then result:='+'+result;
  end;
  while System.Length(result)<minDigits do result:='0'+result;
end;

// Format double: 'f'=fixed, 'g'/'G'=general (removes trailing zeros)
function FormatFloat8(v:double;spec:AnsiChar;prec:integer):String8;
var
  s:string;
  i:integer;
begin
  Str(v:0:prec,s);
  result:=String8(s);
  if spec in ['g','G'] then begin
    // trim trailing zeros after decimal point
    if System.Pos('.',s)>0 then begin
      i:=System.Length(result);
      while (i>0) and (result[i]='0') do dec(i);
      if (i>0) and (result[i]='.') then dec(i);
      SetLength(result,i);
    end;
  end;
end;

// ============================================================================
// UTF8.Format — native implementation (no Unicode roundtrip)
// ============================================================================

class function UTF8.Format(const fmt:String8; const args:array of const):String8;
var
  i,argIdx,w,prec,minD:integer;
  leftAlign,zeroPad,showSign,hasPrec:boolean;
  piece:String8;

  // Append piece to result, applying width and alignment
  procedure Emit(const s:String8);
  var pad:integer;
  begin
    pad:=w-System.Length(s);
    if leftAlign then begin
      result:=result+s;
      if pad>0 then result:=result+String8(StringOfChar(' ',pad));
    end else begin
      if pad>0 then
        if zeroPad then result:=result+String8(StringOfChar('0',pad))
        else result:=result+String8(StringOfChar(' ',pad));
      result:=result+s;
    end;
  end;

begin
  result:='';
  argIdx:=0;
  i:=1;
  while i<=System.Length(fmt) do begin
    if fmt[i]<>'%' then begin
      result:=result+fmt[i]; inc(i); continue;
    end;
    inc(i);
    if i>System.Length(fmt) then break;
    if fmt[i]='%' then begin result:=result+'%'; inc(i); continue; end;
    // flags
    leftAlign:=false; zeroPad:=false; showSign:=false;
    repeat
      if i>System.Length(fmt) then break;
      case fmt[i] of
        '-': begin leftAlign:=true; zeroPad:=false; end;
        '0': if not leftAlign then zeroPad:=true;
        '+': showSign:=true;
        else break;
      end;
      inc(i);
    until false;
    // width
    w:=0;
    while (i<=System.Length(fmt)) and (fmt[i]>='0') and (fmt[i]<='9') do begin
      w:=w*10+(ord(fmt[i])-ord('0')); inc(i);
    end;
    // precision
    prec:=6; hasPrec:=false;
    if (i<=System.Length(fmt)) and (fmt[i]='.') then begin
      inc(i); hasPrec:=true; prec:=0;
      while (i<=System.Length(fmt)) and (fmt[i]>='0') and (fmt[i]<='9') do begin
        prec:=prec*10+(ord(fmt[i])-ord('0')); inc(i);
      end;
    end;
    if (i>System.Length(fmt)) or (argIdx>High(args)) then break;
    case fmt[i] of
      'd','i': begin
        Emit(FormatInt8(VarRecToInt(args[argIdx]),10,false,1,showSign));
        inc(argIdx);
      end;
      'u': begin
        // treat as unsigned 32-bit
        Emit(FormatInt8(VarRecToInt(args[argIdx]) and $FFFFFFFF,10,false,1,false));
        inc(argIdx);
      end;
      'x': begin
        if hasPrec then minD:=prec else minD:=1;
        Emit(FormatInt8(VarRecToInt(args[argIdx]),16,false,minD,false));
        inc(argIdx);
      end;
      'X': begin
        if hasPrec then minD:=prec else minD:=1;
        Emit(FormatInt8(VarRecToInt(args[argIdx]),16,true,minD,false));
        inc(argIdx);
      end;
      'f': begin
        if not hasPrec then prec:=6;
        Emit(FormatFloat8(VarRecToFloat(args[argIdx]),'f',prec));
        inc(argIdx);
      end;
      'g','G': begin
        if not hasPrec then prec:=6;
        Emit(FormatFloat8(VarRecToFloat(args[argIdx]),fmt[i],prec));
        inc(argIdx);
      end;
      's': begin
        piece:=VarRecToStr(args[argIdx]);
        if hasPrec and (System.Length(piece)>prec) then SetLength(piece,prec);
        Emit(piece);
        inc(argIdx);
      end;
      'p': begin
        Emit(Conv.ToHex(VarRecToInt(args[argIdx]),2*sizeof(pointer)));
        inc(argIdx);
      end;
    end;
    inc(i);
  end;
end;

{ TStringsReader }

function TStringsReader.Int(idx:integer):integer;
begin
  if (idx>=0) and (idx<System.Length(values)) then
    result:=Conv.ToInt(values[idx],0)
  else
    result:=0;
end;

function TStringsReader.Empty:boolean;
begin
  result:=index>=System.Length(values);
end;

function TStringsReader.NextInt:integer;
begin
  if index<System.Length(values) then result:=Conv.ToInt(values[index],-1)
  else result:=-1;
  inc(index);
end;

function TStringsReader.NextStr:String8;
begin
  if index<System.Length(values) then result:=values[index]
  else result:='';
  inc(index);
end;

end.
