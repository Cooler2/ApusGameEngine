// Conversion functions: parsing and formatting
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
{$IFDEF CPUX64}{$DEFINE CPU64}{$ENDIF}

unit Apus.Conv;
interface
uses Apus.Core;

type
  Conv = record
    // === Parse string to value ===

    // Parse integer from string (decimal or hex with $ prefix)
    class function ToInt(const st:String8):int64; overload; static;
    {$IFDEF UNICODE}
    class function ToInt(const st:UnicodeString):int64; overload; static;
    {$ENDIF}
    // Parse hex string to integer
    class function HexToInt(const st:String8):int64; overload; static;
    {$IFDEF UNICODE}
    class function HexToInt(const st:UnicodeString):int64; overload; static;
    {$ENDIF}
    // Parse float from string
    class function ToFloat(const st:String8):double; overload; static;
    {$IFDEF UNICODE}
    class function ToFloat(const st:UnicodeString):double; overload; static;
    {$ENDIF}
    // Parse boolean from string ('true','yes','1','+' -> true)
    class function ToBool(const st:String8):boolean; overload; static;
    {$IFDEF UNICODE}
    class function ToBool(const st:UnicodeString):boolean; overload; static;
    {$ENDIF}
    // Parse IP address string to cardinal
    class function ToIp(const st:String8):cardinal; overload; static;
    // IP cardinal to string
    class function ToIp(ip:cardinal):string8; overload; static;

    // === Format value to string ===

    // Integer to hex string
    class function ToHex(v:int64;digits:integer=0):String8; static;
    // Pointer to hex string
    class function ToStr(p:pointer):string8; overload; static;

    class function ToStr(v:integer):string8; overload; static;
    class function ToStr(v:cardinal):string8; overload; static;
    class function ToStr(v:int64):string8; overload; static;
    class function ToStr(v:uint64):string8; overload; static;
    // Boolean to string
    class function ToStr(b:boolean;short:boolean=true):String8; overload; static;
    // Integer with space separators (1 234 567)
    class function FormatInt(v:int64):string; static;
    // Money format with space separators
    class function FormatMoney(v:double;digits:integer=2):string; static;
    // Size to short string (15.3M, 2.1G, etc)
    class function FormatSize(size:int64):string; static;
    // Time interval in ms to string (1.234s, 0d 01:23:45)
    class function TimeToStr(timeMs:int64):string; static;

    // === Hex encoding (binary data) ===

    // Encode binary data to hex string
    class function EncodeHex(data:pointer;size:integer):String8; overload; static;
    class function EncodeHex(const st:String8):String8; overload; static;
    // Decode hex string to binary
    class function DecodeHex(const hexStr:String8):String8; overload; static;
    class procedure DecodeHex(const st:String8;buf:pointer); overload; static;

    // === Binary dump ===

    // Hex dump of buffer (space-separated bytes)
    class function HexDump(buf:pointer;size:integer):String8; static;
    // Decimal dump of buffer
    class function DecDump(buf:pointer;size:integer):String8; static;

    // === Base64 ===
    // Note: this is NOT standard Base64!
    class function ToBase64(data:pointer;size:integer):String8; static;
    class procedure FromBase64(const st:String8;buf:pointer;var size:integer); static;

  private
    class function HexCharToInt(ch:AnsiChar):integer; static; inline;
  end;

implementation
uses SysUtils;

const
  HexChars:String8 = '0123456789ABCDEF';

// === Parse functions ===

class function Conv.HexCharToInt(ch:AnsiChar):integer;
begin
  result:=0;
  if ch in ['0'..'9'] then result:=ord(ch)-ord('0') else
  if ch in ['A'..'F'] then result:=ord(ch)-ord('A')+10 else
  if ch in ['a'..'f'] then result:=ord(ch)-ord('a')+10;
end;

class function Conv.HexToInt(const st:String8):int64;
var
  i:integer;
  v:int64;
begin
  result:=0;
  v:=1;
  for i:=length(st) downto 1 do begin
    if st[i]='-' then begin
      result:=-result;
      break;
    end;
    if not (st[i] in ['0'..'9','A'..'F','a'..'f']) then continue;
    result:=result+HexCharToInt(st[i])*v;
    v:=v*16;
  end;
end;

{$IFDEF UNICODE}
class function Conv.HexToInt(const st:UnicodeString):int64;
var
  i:integer;
  v:int64;
begin
  result:=0;
  v:=1;
  for i:=length(st) downto 1 do begin
    if st[i]='-' then begin
      result:=-result;
      break;
    end;
    if not CharInSet(st[i],['0'..'9','A'..'F','a'..'f']) then continue;
    result:=result+HexCharToInt(AnsiChar(st[i]))*v;
    v:=v*16;
  end;
end;
{$ENDIF}

class function Conv.ToInt(const st:String8):int64;
var
  i,state:integer;
begin
  result:=0;
  state:=0;
  i:=1;
  while i<=length(st) do begin
    if (st[i]>='0') and (st[i]<='9') then begin state:=1; break; end else
    if st[i]='-' then begin state:=2; break; end else
    if st[i]='$' then begin state:=3; break; end;
    inc(i);
  end;
  if state=3 then // hex
    while i<=length(st) do begin
      if st[i] in ['0'..'9','A'..'F','a'..'f'] then
        result:=result shl 4+HexCharToInt(st[i]);
      inc(i);
    end
  else
    while i<=length(st) do begin
      if st[i] in ['0'..'9'] then
        result:=result*10+(ord(st[i])-ord('0'));
      inc(i);
    end;
  if state=2 then result:=-result;
end;

{$IFDEF UNICODE}
class function Conv.ToInt(const st:UnicodeString):int64;
var
  i,state:integer;
begin
  result:=0;
  state:=0;
  i:=1;
  while i<=length(st) do begin
    if (st[i]>='0') and (st[i]<='9') then begin state:=1; break; end else
    if st[i]='-' then begin state:=2; break; end else
    if st[i]='$' then begin state:=3; break; end;
    inc(i);
  end;
  if state=3 then // hex
    while i<=length(st) do begin
      if CharInSet(st[i],['0'..'9','A'..'F','a'..'f']) then
        result:=result shl 4+HexCharToInt(AnsiChar(st[i]));
      inc(i);
    end
  else
    while i<=length(st) do begin
      if CharInSet(st[i],['0'..'9']) then
        result:=result*10+(ord(st[i])-ord('0'));
      inc(i);
    end;
  if state=2 then result:=-result;
end;
{$ENDIF}

class function Conv.ToFloat(const st:String8):double;
var
  i,j:integer;
  minus:boolean;
  divider:double;
  expPart:integer;
begin
  result:=0;
  i:=1;
  // skip leading spaces
  while (i<=length(st)) and (st[i]=' ') do inc(i);
  // sign
  minus:=false;
  if i<=length(st) then begin
    if st[i]='-' then begin minus:=true; inc(i); end
    else if st[i]='+' then inc(i);
  end;
  // integer part
  while (i<=length(st)) and (st[i] in ['0'..'9']) do begin
    result:=result*10+(ord(st[i])-ord('0'));
    inc(i);
  end;
  // fractional part
  if (i<=length(st)) and (st[i] in [',','.']) then begin
    inc(i);
    divider:=0.1;
    while (i<=length(st)) and (st[i] in ['0'..'9']) do begin
      result:=result+(ord(st[i])-ord('0'))*divider;
      divider:=divider*0.1;
      inc(i);
    end;
  end;
  // exponent part
  if (i<=length(st)) and (st[i] in ['e','E']) then begin
    inc(i);
    expPart:=0;
    j:=1;
    if (i<=length(st)) and (st[i]='-') then begin j:=-1; inc(i); end
    else if (i<=length(st)) and (st[i]='+') then inc(i);
    while (i<=length(st)) and (st[i] in ['0'..'9']) do begin
      expPart:=expPart*10+(ord(st[i])-ord('0'));
      inc(i);
    end;
    if j<0 then
      while expPart>0 do begin result:=result*0.1; dec(expPart); end
    else
      while expPart>0 do begin result:=result*10; dec(expPart); end;
  end;
  if minus then result:=-result;
end;

{$IFDEF UNICODE}
class function Conv.ToFloat(const st:UnicodeString):double;
var
  i,j:integer;
  minus:boolean;
  divider:double;
  expPart:integer;
begin
  result:=0;
  i:=1;
  while (i<=length(st)) and (st[i]=' ') do inc(i);
  minus:=false;
  if i<=length(st) then begin
    if st[i]='-' then begin minus:=true; inc(i); end
    else if st[i]='+' then inc(i);
  end;
  while (i<=length(st)) and CharInSet(st[i],['0'..'9']) do begin
    result:=result*10+(ord(st[i])-ord('0'));
    inc(i);
  end;
  if (i<=length(st)) and CharInSet(st[i],[',','.']) then begin
    inc(i);
    divider:=0.1;
    while (i<=length(st)) and CharInSet(st[i],['0'..'9']) do begin
      result:=result+(ord(st[i])-ord('0'))*divider;
      divider:=divider*0.1;
      inc(i);
    end;
  end;
  if (i<=length(st)) and CharInSet(st[i],['e','E']) then begin
    inc(i);
    expPart:=0;
    j:=1;
    if (i<=length(st)) and (st[i]='-') then begin j:=-1; inc(i); end
    else if (i<=length(st)) and (st[i]='+') then inc(i);
    while (i<=length(st)) and CharInSet(st[i],['0'..'9']) do begin
      expPart:=expPart*10+(ord(st[i])-ord('0'));
      inc(i);
    end;
    if j<0 then
      while expPart>0 do begin result:=result*0.1; dec(expPart); end
    else
      while expPart>0 do begin result:=result*10; dec(expPart); end;
  end;
  if minus then result:=-result;
end;
{$ENDIF}

class function Conv.ToBool(const st:String8):boolean;
begin
  result:=false;
  if length(st)=0 then exit;
  if st[1] in ['T','t','Y','y','1','+'] then result:=true;
end;

{$IFDEF UNICODE}
class function Conv.ToBool(const st:UnicodeString):boolean;
begin
  result:=false;
  if length(st)=0 then exit;
  if CharInSet(st[1],['T','t','Y','y','1','+']) then result:=true;
end;
{$ENDIF}

class function Conv.ToIp(const st:String8):cardinal;
var
  i,v:integer;
begin
  result:=0;
  v:=0;
  for i:=1 to length(st) do begin
    if st[i] in ['0'..'9'] then
      v:=v*10+(byte(st[i])-$30)
    else
    if st[i]='.' then begin
      result:=result shr 8+cardinal(v) shl 24;
      v:=0;
    end;
  end;
  result:=result shr 8+cardinal(v) shl 24;
end;

// === Format functions ===

class function Conv.ToHex(v:int64;digits:integer=0):String8;
var
  l:integer;
  vv:int64;
begin
  vv:=v;
  l:=0;
  while vv<>0 do begin
    inc(l);
    vv:=vv shr 4;
  end;
  if l<digits then l:=digits;
  if l=0 then l:=1;
  SetLength(result,l);
  while l>0 do begin
    result[l]:=HexChars[1+v and $F];
    v:=v shr 4;
    dec(l);
  end;
end;

class function Conv.ToStr(p:pointer):string8;
begin
  {$IFDEF CPU64}
  result:=ToHex(UIntPtr(p),12);
  {$ELSE}
  result:=ToHex(cardinal(p),8);
  {$ENDIF}
end;

class function Conv.ToIp(ip:cardinal):string8;
begin
  result:=ToStr(ip and $FF)+'.'+
          ToStr((ip shr 8) and $FF)+'.'+
          ToStr((ip shr 16) and $FF)+'.'+
          ToStr((ip shr 24) and $FF);
end;

class function Conv.ToStr(b:boolean;short:boolean=true):String8;
begin
  if short then begin
    if b then result:='1' else result:='0';
  end else begin
    if b then result:='true' else result:='false';
  end;
end;

class function Conv.ToStr(v:integer):string8;
var
  neg:boolean;
  i:integer;
  u:cardinal;
  buf:array[0..15] of AnsiChar;
begin
  neg:=v<0;
  if neg then u:=cardinal(-int64(v)) // avoid overflow for MinInt
  else u:=cardinal(v);
  i:=15;
  repeat
    buf[i]:=AnsiChar(ord('0')+u mod 10);
    u:=u div 10;
    dec(i);
  until u=0;
  if neg then begin buf[i]:='-'; dec(i); end;
  SetLength(result,15-i);
  Move(buf[i+1],result[1],15-i);
end;

class function Conv.ToStr(v:cardinal):string8;
var
  i:integer;
  buf:array[0..15] of AnsiChar;
begin
  i:=15;
  repeat
    buf[i]:=AnsiChar(ord('0')+v mod 10);
    v:=v div 10;
    dec(i);
  until v=0;
  SetLength(result,15-i);
  Move(buf[i+1],result[1],15-i);
end;

class function Conv.ToStr(v:int64):string8;
var
  neg:boolean;
  i:integer;
  u:uint64;
  buf:array[0..23] of AnsiChar;
begin
  neg:=v<0;
  if neg then u:=uint64(-v) // works for MinInt64 due to two's complement
  else u:=uint64(v);
  i:=23;
  repeat
    buf[i]:=AnsiChar(ord('0')+u mod 10);
    u:=u div 10;
    dec(i);
  until u=0;
  if neg then begin buf[i]:='-'; dec(i); end;
  SetLength(result,23-i);
  Move(buf[i+1],result[1],23-i);
end;

class function Conv.ToStr(v:uint64):string8;
var
  i:integer;
  buf:array[0..23] of AnsiChar;
begin
  i:=23;
  repeat
    buf[i]:=AnsiChar(ord('0')+v mod 10);
    v:=v div 10;
    dec(i);
  until v=0;
  SetLength(result,23-i);
  Move(buf[i+1],result[1],23-i);
end;

class function Conv.FormatInt(v:int64):string;
var
  i:integer;
begin
  result:=SysUtils.IntToStr(v);
  i:=length(result)-2;
  while i>1 do begin
    Insert(' ',result,i);
    dec(i,3);
  end;
end;

class function Conv.FormatMoney(v:double;digits:integer=2):string;
var
  i:integer;
begin
  result:=FloatToStrF(v,ffFixed,20,digits);
  i:=length(result)-2-digits;
  if digits>0 then dec(i);
  while i>1 do begin
    Insert(' ',result,i);
    dec(i,3);
  end;
end;

class function Conv.FormatSize(size:int64):string;
var
  v:single;
begin
  if size<1000 then exit(SysUtils.IntToStr(size)+'b');
  v:=size/1024;
  if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'K');
  if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'K');
  if v<1000 then exit(SysUtils.IntToStr(round(v))+'K');
  v:=v/1024;
  if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'M');
  if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'M');
  if v<1000 then exit(SysUtils.IntToStr(round(v))+'M');
  v:=v/1024;
  if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'G');
  if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'G');
  if v<1000 then exit(SysUtils.IntToStr(round(v))+'G');
  v:=v/1024;
  if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'T');
  if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'T');
  result:=SysUtils.IntToStr(round(v))+'T';
end;

class function Conv.TimeToStr(timeMs:int64):string;
begin
  if timeMs<120000 then
    exit(SysUtils.IntToStr(timeMs div 1000)+'.'+SysUtils.IntToStr(timeMs mod 1000)+'s');
  result:=FormatDateTime('hh:nn:ss',timeMs/86400000);
  if timeMs>86400000 then
    result:=SysUtils.IntToStr(trunc(timeMs/86400000))+'d '+result;
end;

// === Hex encoding (binary data) ===

class function Conv.EncodeHex(data:pointer;size:integer):String8;
var
  pb:PByte;
  i:integer;
begin
  SetLength(result,size*2);
  pb:=data;
  for i:=1 to size do begin
    result[i*2-1]:=HexChars[1+pb^ shr 4];
    result[i*2]:=HexChars[1+pb^ and $F];
    inc(pb);
  end;
end;

class function Conv.EncodeHex(const st:String8):String8;
begin
  if length(st)=0 then exit('');
  result:=EncodeHex(@st[1],length(st));
end;

class function Conv.DecodeHex(const hexStr:String8):String8;
var
  i:integer;
begin
  SetLength(result,length(hexStr) div 2);
  for i:=1 to length(result) do
    result[i]:=AnsiChar(HexCharToInt(hexStr[i*2-1])*16+HexCharToInt(hexStr[i*2]));
end;

class procedure Conv.DecodeHex(const st:String8;buf:pointer);
var
  i:integer;
  pb:PByte;
begin
  pb:=buf;
  for i:=1 to length(st) div 2 do begin
    pb^:=HexCharToInt(st[i*2-1])*16+HexCharToInt(st[i*2]);
    inc(pb);
  end;
end;

// === Dump ===

class function Conv.HexDump(buf:pointer;size:integer):String8;
var
  pb:PByte;
  i:integer;
begin
  if size=0 then exit('');
  SetLength(result,size*3-1);
  pb:=buf;
  for i:=0 to size-1 do begin
    if i>0 then result[i*3]:=' ';
    result[i*3+1]:=HexChars[1+pb^ shr 4];
    result[i*3+2]:=HexChars[1+pb^ and $F];
    inc(pb);
  end;
end;

class function Conv.DecDump(buf:pointer;size:integer):String8;
var
  pb:PByte;
  i:integer;
  s:String8;
begin
  result:='';
  pb:=buf;
  for i:=0 to size-1 do begin
    Str(pb^:3,s);
    if i>0 then result:=result+' ';
    result:=result+s;
    inc(pb);
  end;
end;

// === Base64 (non-standard) ===

const
  Base64Chars:String8 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

class function Conv.ToBase64(data:pointer;size:integer):String8;
var
  pb:PByte;
  i,v:integer;
begin
  SetLength(result,(size*4+2) div 3);
  pb:=data;
  i:=1;
  while size>=3 do begin
    v:=pb^; inc(pb);
    v:=v shl 8+pb^; inc(pb);
    v:=v shl 8+pb^; inc(pb);
    result[i]:=Base64Chars[1+v shr 18];
    result[i+1]:=Base64Chars[1+(v shr 12) and $3F];
    result[i+2]:=Base64Chars[1+(v shr 6) and $3F];
    result[i+3]:=Base64Chars[1+v and $3F];
    inc(i,4);
    dec(size,3);
  end;
  if size=2 then begin
    v:=pb^; inc(pb);
    v:=v shl 8+pb^;
    v:=v shl 2;
    result[i]:=Base64Chars[1+v shr 12];
    result[i+1]:=Base64Chars[1+(v shr 6) and $3F];
    result[i+2]:=Base64Chars[1+v and $3F];
  end else
  if size=1 then begin
    v:=pb^ shl 4;
    result[i]:=Base64Chars[1+v shr 6];
    result[i+1]:=Base64Chars[1+v and $3F];
  end;
end;

class procedure Conv.FromBase64(const st:String8;buf:pointer;var size:integer);
var
  i,v,cnt:integer;
  pb:PByte;
  function CharValue(ch:AnsiChar):integer;
  begin
    if ch in ['A'..'Z'] then result:=ord(ch)-ord('A')
    else if ch in ['a'..'z'] then result:=ord(ch)-ord('a')+26
    else if ch in ['0'..'9'] then result:=ord(ch)-ord('0')+52
    else if ch='+' then result:=62
    else if ch='/' then result:=63
    else result:=0;
  end;
begin
  pb:=buf;
  cnt:=0;
  i:=1;
  while i<=length(st)-3 do begin
    v:=CharValue(st[i]) shl 18 + CharValue(st[i+1]) shl 12 +
       CharValue(st[i+2]) shl 6 + CharValue(st[i+3]);
    pb^:=v shr 16; inc(pb); inc(cnt);
    pb^:=(v shr 8) and $FF; inc(pb); inc(cnt);
    pb^:=v and $FF; inc(pb); inc(cnt);
    inc(i,4);
  end;
  if i<=length(st)-2 then begin
    v:=CharValue(st[i]) shl 12 + CharValue(st[i+1]) shl 6 + CharValue(st[i+2]);
    v:=v shr 2;
    pb^:=v shr 8; inc(pb); inc(cnt);
    pb^:=v and $FF; inc(pb); inc(cnt);
  end else
  if i<=length(st)-1 then begin
    v:=CharValue(st[i]) shl 6 + CharValue(st[i+1]);
    v:=v shr 4;
    pb^:=v; inc(cnt);
  end;
  size:=cnt;
end;

end.
