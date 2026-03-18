// Utility functions - miscellaneous helpers that don't fit other modules' scope
//
// SCOPE: Functions that don't belong in core/conv/strings/files - date/time parsing,
// array helpers, command-line args, simple encoding.
//
// ADD HERE: Date parsing (ParseDate/ParseTime), array helpers (AddString/RemoveString),
// cmdline (HasParam/GetParam), encoding (EncodeUTF8/DecodeUTF8), simple crypto/compression.
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
  // command line helpers
  function HasParam(const name:string):boolean;
  function GetParam(const name:string):string;

type
  // Text encoding types
  TTextEncoding = (teUnknown, teANSI, teWin1251, teUTF8);

  // Convert WideString to 8-bit string with given encoding
  function UnicodeTo(const st:WideString;encoding:TTextEncoding):String8;
  // Convert 8-bit string to WideString with given encoding
  function UnicodeFrom(const st:String8;encoding:TTextEncoding):WideString;
  // Get enum name by typeinfo/value, fallback to "ENUM_<value>" when typeinfo is nil
  function GetEnumNameSafe(typeInfo:pointer;value:integer):string;


  // =============================================================================
  // Spline interpolation functions
  // =============================================================================
  // All splines: f(x0)=y0, f(x1)=y1, x clamped to [x0,x1]
  function Spline0(x,x0,x1,y0,y1:single):single; // linear
  function Spline1(x,x0,x1,y0,y1:single):single; // ease-in-out: 25%-50%-25%
  function Spline2(x,x0,x1,y0,y1:single):single; // ease-out (decelerate)
  function Spline2rev(x,x0,x1,y0,y1:single):single; // ease-in (accelerate)

  // Arbitrary spline: 0->v0, 1.0->v1
  //   k0,k1 - касательные на концах (0 - горизонталь), v - вес деления (0..1, 0.5 - среднее)
  function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;

type
  // Spline function: f(x0)=y0, f(x1)=y1, f(x)=?
  TSplineFunc=function(x,x0,x1,y0,y1:single):single;

  TSplines=record
    linear:TSplineFunc;
    easeIn:TSplineFunc;
    easeOut:TSplineFunc;
    easeInOut:TSplineFunc;
    easierIn:TSplineFunc;
    easierOut:TSplineFunc;
    easierInOut:TSplineFunc;
    bounce:TSplineFunc;
  end;

var
  splines:TSplines; // common spline functions


implementation
uses SysUtils, TypInfo, Apus.Conv, Apus.Strings, Apus.Log;

function HasParam(const name:string):boolean;
 var
  i:integer;
 begin
  result:=false;
  for i:=1 to ParamCount do
   if SameText(name,ParamStr(i)) then exit(true);
 end;

function GetParam(const name:string):string;
 var
  i,p:integer;
  st:string;
 begin
  result:='';
  for i:=1 to ParamCount do begin
   st:=ParamStr(i);
   p:=pos('=',st);
   if p=0 then continue;
   if SameText(name,copy(st,1,p-1)) then exit(copy(st,p+1,length(st)));
  end;
 end;

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
    s1:=st.Split(' ');
    splitter:='';
    if pos('.',string(s1[0]))>0 then splitter:='.';
    if pos('-',string(s1[0]))>0 then splitter:='-';
    if pos('/',string(s1[0]))>0 then splitter:='/';
    if splitter='' then exit;
    s2:=s1[0].Split(splitter[1]);
    if length(s2)<>3 then exit;
    if length(s2[0])=4 then Swap(s2[2],s2[0]);
    year:=Conv.ToInt(s2[2]);
    if year<100 then begin
      if year>70 then year:=1900+year
      else year:=2000+year;
    end;
    month:=Clamp(Conv.ToInt(s2[1]),1,12);
    day:=Clamp(Conv.ToInt(s2[0]),1,31);
    result:=EncodeDate(year,month,day);
    if length(s1)>1 then begin
      s2:=s1[1].Split(':');
      msec:=0;
      if length(s2)>0 then hour:=Conv.ToInt(s2[0]) else hour:=0;
      if length(s2)>1 then min:=Conv.ToInt(s2[1]) else min:=0;
      if length(s2)>2 then begin
        p:=pos('.',string(s2[2]));
        if p>0 then begin
          msec:=Conv.ToInt(copy(s2[2],p+1,3));
          SetLength(s2[2],p-1);
        end;
        sec:=Conv.ToInt(s2[2]);
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
    sa:=st.Split(':');
    sec:=0;
    msec:=0;
    if length(sa)>0 then hour:=Conv.ToInt(sa[0]) else hour:=0;
    if length(sa)>1 then min:=Conv.ToInt(sa[1]) else min:=0;
    if length(sa)>2 then begin
      if pos('.',string(sa[2]))>0 then begin
        sa:=sa[2].Split('.');
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

function GetEnumNameSafe(typeInfo:pointer;value:integer):string;
begin
  if typeInfo<>nil then
    result:=GetEnumName(PTypeInfo(typeInfo),value)
  else
    result:='ENUM_'+IntToStr(value);
end;

// =============================================================================
// Spline implementations
// =============================================================================
{$R-}
function Spline0(x,x0,x1,y0,y1:single):single;
begin
 x:=(x-x0)/(x1-x0);
 if x<0 then x:=0;
 if x>1 then x:=1;
 result:=y0+(y1-y0)*x;
end;

function Spline1(x,x0,x1,y0,y1:single):single; // ease-in-out 25-50-25
begin
 x:=(x-x0)/(x1-x0);
 if x<0 then x:=0;
 if x>1 then x:=1;
 if x<0.25 then result:=2.666666*sqr(x) else
  if x>0.75 then result:=1-2.666666*sqr(1-x) else
   result:=1.333333*x-0.16666666;
 result:=y0+(y1-y0)*result;
end;

function Spline2(x,x0,x1,y0,y1:single):single; // ease-out (decelerate)
begin
 x:=(x-x0)/(x1-x0);
 if x<0 then x:=0;
 if x>1 then x:=1;
 result:=1-sqr(1-x);
 result:=y0+(y1-y0)*result;
end;

function Spline2rev(x,x0,x1,y0,y1:single):single; // ease-in (accelerate)
begin
 x:=(x-x0)/(x1-x0);
 if x<0 then x:=0;
 if x>1 then x:=1;
 result:=x*x;
 result:=y0+(y1-y0)*result;
end;

function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;
var
  a,b:double;
begin
  if x<0 then x:=0;
  if x>1 then x:=1;
  x:=(2-4*v)*x*x+(4*v-1)*x;
  a:=k0-(v1-v0);
  b:=-k1+(v1-v0);
  result:=(1-x)*v0+x*v1+x*(1-x)*(a*(1-x)+b*x);
 end;
{$IFDEF RANGECHECKS_ON}{$R+}{$ENDIF}

// Win1251 -> Unicode mapping table (code points $80..$FF)
const
 win1251cp:array[$80..$FF] of word=(
  $0402,$0403,$201A,$0453,$201E,$2026,$2020,$2021,$20AC,$2030,$0409,$2039,$040A,
  $040C,$040B,$040F,$0452,$2018,$2019,$201C,$201D,$2022,$2013,$2014,$FFFF,$2122,$0459,
  $203A,$045A,$045C,$045B,$045F,$00A0,$040E,$045E,$0408,$00A4,$0490,$00A6,$00A7,
  $0401,$00A9,$0404,$00AB,$00AC,$00AD,$00AE,$0407,$00B0,$00B1,$0406,$0456,$0491,
  $00B5,$00B6,$00B7,$0451,$2116,$0454,$00BB,$0458,$0405,$0455,$0457,$0410,$0411,
  $0412,$0413,$0414,$0415,$0416,$0417,$0418,$0419,$041A,$041B,$041C,$041D,$041E,
  $041F,$0420,$0421,$0422,$0423,$0424,$0425,$0426,$0427,$0428,$0429,$042A,$042B,
  $042C,$042D,$042E,$042F,$0430,$0431,$0432,$0433,$0434,$0435,$0436,$0437,$0438,
  $0439,$043A,$043B,$043C,$043D,$043E,$043F,$0440,$0441,$0442,$0443,$0444,$0445,
  $0446,$0447,$0448,$0449,$044A,$044B,$044C,$044D,$044E,$044F);

function Win1251FromUnicode(w:word):AnsiChar;
var
 j:integer;
begin
 if w<$80 then exit(AnsiChar(w));
 if (w>=$410) and (w<=$44F) then exit(AnsiChar(192+w-$410));
 result:=' ';
 for j:=$80 to $BF do
  if win1251cp[j]=w then begin result:=AnsiChar(j); exit; end;
end;

function UnicodeTo(const st:WideString;encoding:TTextEncoding):String8;
var
 i:integer;
 w:word;
begin
 case encoding of
  TTextEncoding.teUTF8:result:=UTF8.Encode(st);
  TTextEncoding.teWin1251:begin
   SetLength(result,length(st));
   for i:=1 to length(st) do
    result[i]:=Win1251FromUnicode(word(st[i]));
  end;
  TTextEncoding.teANSI:begin
   SetLength(result,length(st));
   for i:=1 to length(st) do begin
    w:=word(st[i]);
    if w<256 then result[i]:=AnsiChar(w) else result[i]:='?';
   end;
  end;
  else raise EError.Create('UnicodeTo: encoding not supported');
 end;
end;

function UnicodeFrom(const st:String8;encoding:TTextEncoding):WideString;
var
 i:integer;
 b:byte;
begin
 case encoding of
  TTextEncoding.teUTF8:result:=UTF8.ToWide(st);
  TTextEncoding.teWin1251:begin
   SetLength(result,length(st));
   for i:=1 to length(st) do begin
    b:=byte(st[i]);
    if b<$80 then result[i]:=WideChar(b)
    else result[i]:=WideChar(win1251cp[b]);
   end;
  end;
  TTextEncoding.teANSI:begin
   SetLength(result,length(st));
   for i:=1 to length(st) do result[i]:=WideChar(byte(st[i]));
  end;
  else raise EError.Create('UnicodeFrom: encoding not supported');
 end;
end;



initialization
  with splines do begin
    linear:=Spline0;
    easeIn:=Spline2rev;
    easeOut:=Spline2;
    easeInOut:=Spline1;
    easierIn:=Spline2rev;
    easierOut:=Spline2;
    easierInOut:=Spline1;
    bounce:=nil; // not migrated from Common yet
  end;
end.
