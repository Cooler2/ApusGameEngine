// Utility functions - miscellaneous helpers that don't fit other modules' scope
//
// SCOPE: Functions that don't belong in core/conv/strings/files - date/time parsing,
// string splitting with quotes, array helpers, command-line args, simple encoding.
//
// ADD HERE: Date parsing (ParseDate/ParseTime), string splitting (SplitA), array helpers
// (AddString/RemoveString), cmdline (HasParam/GetParam), encoding (EncodeUTF8/DecodeUTF8),
// simple crypto/compression.
//
// DON'T ADD: Core math/memory (→ Core), type conversion (→ Conv), string operations (→ Strings),
// file I/O (→ Files), logging (→ Log), threading (→ Threads).
//
// Copyright (C) 2004-2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Utils;
interface
uses Apus.Core;

// parse date from string in format DD.MM.YYYY HH:MM:SS (recognizes other formats too)
function ParseDate(st:String8;default:TDateTime=0):TDateTime;
function GetDateFromStr(st:String8;default:TDateTime=0):TDateTime; // alias for compatibility
function ParseTime(st:String8;default:TDateTime=0):TDateTime;

// split string into array by divider
// version with quotes support: handles quoted substrings with paired quotes escaping
function SplitA(divider,st:String8;quotes:Char8):Strings8; overload;
// simple version without quotes
function SplitA(divider,st:String8):Strings8; overload;

// remove leading and trailing whitespace (same as String8.Trim but as standalone function)
function Chop(st:String8):String8; overload;
{$IFNDEF UNICODE}
function Chop(st:String):String; overload;
{$ENDIF}
function Chop(st:String16):String16; overload;

implementation
uses SysUtils, Apus.Conv, Apus.Strings, Apus.Log;

function ParseDate(st:String8;default:TDateTime=0):TDateTime;
var
  s1,s2:Strings8;
  year,month,day,hour,min,sec,msec,p:integer;
  splitter:String8;
begin
  result:=default;
  try
    st:=st.Trim;
    if st='' then exit;
    s1:=SplitA(' ',st);
    splitter:='';
    if pos('.',s1[0])>0 then splitter:='.';
    if pos('-',s1[0])>0 then splitter:='-';
    if pos('/',s1[0])>0 then splitter:='/';
    if splitter='' then exit;
    s2:=SplitA(splitter,s1[0]);
    if length(s2)<>3 then exit;
    if length(s2[0])=4 then Swap(s2[2],s2[0]);
    year:=strtoint(s2[2]);
    if year<100 then begin
      if year>70 then year:=1900+year
      else year:=2000+year;
    end;
    month:=Clamp(Conv.ToInt(s2[1]),1,12);
    day:=Clamp(Conv.ToInt(s2[0]),1,31);
    result:=EncodeDate(year,month,day);
    if length(s1)>1 then begin
      s2:=SplitA(':',s1[1]);
      msec:=0;
      if length(s2)>0 then hour:=strtoint(s2[0]) else hour:=0;
      if length(s2)>1 then min:=strtoint(s2[1]) else min:=0;
      if length(s2)>2 then begin
        p:=pos('.',s2[2]);
        if p>0 then begin
          msec:=strtoint(copy(s2[2],p+1,3));
          SetLength(s2[2],p-1);
        end;
        sec:=strtoint(s2[2]);
      end else sec:=0;
      result:=result+EncodeTime(hour,min,sec,msec);
    end;
  except
    result:=default;
  end;
end;

function ParseTime(st:String8;default:TDateTime=0):TDateTime;
var
  sa:Strings8;
  hour,min,sec,msec:integer;
begin
  try
    st:=st.Trim;
    sa:=SplitA(':',st);
    sec:=0;
    msec:=0;
    if length(sa)>0 then hour:=Conv.ToInt(sa[0]) else hour:=0;
    if length(sa)>1 then min:=Conv.ToInt(sa[1]) else min:=0;
    if length(sa)>2 then begin
      if pos('.',sa[2])>0 then begin
        sa:=SplitA('.',sa[2]);
        sec:=Conv.ToInt(sa[0]);
        msec:=Conv.ToInt(sa[1]);
      end else
        sec:=Conv.ToInt(sa[2]);
    end;
    result:=hour/24+min/1440+sec/86400+msec/86400000;
  except
    result:=default;
  end;
end;

function GetDateFromStr(st:String8;default:TDateTime):TDateTime;
begin
  result:=ParseDate(st,default);
end;

function SplitA(divider,st:String8;quotes:Char8):Strings8;
var
  i,j,n:integer;
  // resize strings array
  procedure Resize(var arr:Strings8;newsize:integer);
  begin
    if newsize>length(arr) then
      SetLength(arr,length(arr)+256);
  end;
  // main function body
begin
  if st='' then begin
    SetLength(result,0); exit;
  end;
  n:=0;
  repeat
    // delete spaces at the beginning
    while (length(st)>0) and (st[1] in [#9,' ']) do delete(st,1,1);
    i:=pos(divider,st);

    if length(st)=0 then break; // empty string

    if (length(st)>1) and (st[1]=quotes) then begin
      // string is quoted
      // so find enclosing quotes
      j:=2;
      repeat
        if st[j]=quotes then begin
          if (j<length(st)) and (st[j+1]=quotes) then begin
            // paired quotes: replace and skip
            delete(st,j,1);
          end else break;
        end;
        inc(j);
      until j>length(st);
      if j>length(st) then begin
        Log.Warn('Unterminated string: '+st);
      end;
      Resize(result,n+1);
      result[n]:=copy(st,2,j-2);
      delete(st,1,j+length(divider));
      inc(n);
    end else begin
      // simply get first divider
      Resize(result,n+2);
      if i=0 then begin // no divider found - all string is last substr
        result[n]:=st;
        inc(n);
        break;
      end else begin // divider found
        result[n]:=copy(st,1,i-1);
        delete(st,1,i+length(divider)-1);
        inc(n);
      end;
      i:=length(result[n]);
      while (i>0) and (result[n][i]<=' ') do dec(i);
      if i<length(result[n]) then SetLength(result[n],i);
      if length(st)=0 then inc(n); // for last empty substring
    end;
  until false;
  SetLength(result,n);
end;

function SplitA(divider,st:String8):Strings8;
var
  i,j,n,divLen,maxIdx:integer;
  fl:boolean;
  idx:array of integer;
  ch:Char8;
begin
  if st='' then begin
    SetLength(result,0); exit;
  end;
  setLength(idx,15);
  idx[0]:=1;
  // count dividers
  n:=0;
  i:=1;
  divLen:=length(divider);
  maxIdx:=length(st)-divLen+1;
  ch:=divider[1];
  while i<=maxIdx do begin
    if st[i]<>ch then
      inc(i)
    else begin
      fl:=true;
      for j:=2 to divLen do
        if st[i+j-1]<>divider[j] then begin
          fl:=false; break;
        end;
      if fl then begin
        inc(n);
        if n>=length(idx)-1 then SetLength(idx,length(idx)*4);
        idx[n]:=i+divLen;
        inc(i,divLen);
      end else inc(i);
    end;
  end;
  inc(n);
  idx[n]:=length(st)+length(divider)+1;
  SetLength(result,n);
  for i:=0 to n-1 do begin
    j:=idx[i+1]-divLen-idx[i];
    SetLength(result[i],j);
    if j>0 then result[i]:=copy(st,idx[i],j);
  end;
end;

function Chop(st:String8):String8;
var
  i:integer;
begin
  result:=st;
  while (length(result)>0) and (result[1]<=' ') do delete(result,1,1);
  i:=length(result);
  while (length(result)>0) and (result[i]<=' ') do dec(i);
  setlength(result,i);
end;

{$IFNDEF UNICODE}
function Chop(st:String):String;
var
  i:integer;
begin
  result:=st;
  while (length(result)>0) and (result[1]<=' ') do delete(result,1,1);
  i:=length(result);
  while (length(result)>0) and (result[i]<=' ') do dec(i);
  setlength(result,i);
end;
{$ENDIF}

function Chop(st:String16):String16;
var
  i:integer;
begin
  result:=st;
  while (length(result)>0) and (result[1]<=' ') do delete(result,1,1);
  i:=length(result);
  while (length(result)>0) and (result[i]<=' ') do dec(i);
  setlength(result,i);
end;

end.
