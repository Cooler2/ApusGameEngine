// Configuration documents: the CTL3 syntax; CTL2 files and a JSON subset are read as well.
// The reference for the behaviour is manual/config_files.md.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Config;
interface
uses Apus.Core, Apus.Threads;

type
  EConfigError=class(EError);

  TCfgKind=(ckNone,     // the node does not exist
            ckNull,     // JSON null: present, reads give the default
            ckScalar,
            ckSection,
            ckArray);

  // Encryption of whole document files (manual, section 8)
  IConfigProtector=interface
    ['{6E0A3C2B-4F71-4C1D-9B8E-2D5A7F1C3E90}']
    // Must give different output for the same input on every call (a random nonce)
    function Protect(const data:ByteArray):ByteArray;
    // Raises on damaged or foreign data
    function Unprotect(const data:ByteArray):ByteArray;
  end;

  TConfig=class;
  TCfgEnumerator=class;

  // One step of a node path: a key or an array index
  TCfgSegment=record
    name:String8;
    index:integer; // -1 for a key
  end;
  TCfgSegments=array of TCfgSegment;

  // Position in a document, not an object: it never dangles and sees the current content.
  // Obtain handles from TConfig.Root/Node only.
  TCfgNode=record
  private
    doc:TConfig;
    segs:TCfgSegments;
    function Extended(const path:String8):TCfgNode;
  public
    function Exists:boolean;
    function Kind:TCfgKind;
    function Name:String8;
    function Path:String8;
    function Location:String8; // 'file:line' of the definition, '' if missing or new
    // Navigation
    function Node(const path:String8):TCfgNode;
    function Child(const name:String8):TCfgNode; // exact key, no path parsing
    function Count:integer;
    function Item(index:integer):TCfgNode;
    function GetEnumerator:TCfgEnumerator;
    // Lenient reads: the default for a missing, null or not convertible value
    function Int(const path:String8;default:int64=0):int64;
    function Float(const path:String8;default:double=0.0):double;
    function Bool(const path:String8;default:boolean=false):boolean;
    function Str(const path:String8;const default:String8=''):String8;
    function Enum(const path:String8;const names:array of String8;default:integer=0):integer;
    function Strs(const path:String8):Strings8;
    // Reads of the node itself
    function AsInt(default:int64=0):int64;
    function AsFloat(default:double=0.0):double;
    function AsBool(default:boolean=false):boolean;
    function AsStr(const default:String8=''):String8;
    // Strict reads: raise EConfigError
    function ReqInt(const path:String8):int64;
    function ReqFloat(const path:String8):double;
    function ReqBool(const path:String8):boolean;
    function ReqStr(const path:String8):String8;
    // Writes create the missing sections; a write the content doesn't allow (through a value,
    // a value over a section) is reported and skipped
    procedure SetInt(const path:String8;value:int64);
    // digits: significant digits; 0 - the shortest form that reads back exactly
    procedure SetFloat(const path:String8;value:double;digits:integer=5);
    procedure SetBool(const path:String8;value:boolean);
    procedure SetStr(const path:String8;const value:String8);
    procedure SetStrs(const path:String8;const values:Strings8);
    function AddSection(const path:String8):TCfgNode;
    procedure Delete(const path:String8);
  end;

  // Children of a section or items of an array: for child in node do ...
  TCfgEnumerator=class
  private
    node:TCfgNode;
    index,count:integer;
    function GetCurrent:TCfgNode;
  public
    function MoveNext:boolean;
    property Current:TCfgNode read GetCurrent;
  end;

  TConfig=class
  private
    lock:TLock;
    fileName:String8;
    optional:boolean;
    protector:IConfigProtector;
    data:TObject; // TCfgData
    modifiedFlag:boolean;
    failedState:String8; // file states of the last failed load
    fLoadError:String8;
    placeholder:boolean; // the content is empty because the load failed
    function FileStates:String8;
    procedure ApplyReload(newData:TObject);
    function TryLoad(out newData:TObject):boolean;
  public
    // Never raises on the file content: a file that fails to load gives an empty document,
    // the problem is reported (see onConfigProblem) and kept in LoadError.
    // optional: a missing file is not a problem, the first Save creates it
    constructor Create(const fname:String8;optional:boolean=false;protector:IConfigProtector=nil);
    destructor Destroy; override;
    function Changed:boolean;
    // Both keep the current content when the new one fails to load; true if reloaded
    function Reload:boolean;
    function ReloadIfChanged:boolean;
    function Root:TCfgNode;
    function Node(const path:String8):TCfgNode; // Root.Node(path)
    function Modified:boolean;
    // Why the last load or reload failed, '' if it succeeded. While it is set, Save doesn't
    // write: the file is kept for the user to fix
    function LoadError:String8;
    // False if the document could not be written (the problem is reported)
    function Save:boolean;
  end;

  // Receives a problem found in a config: a failed load, reload or save, a value that does not
  // convert, a write that conflicts with the file content
  TConfigProblemProc=procedure(const msg:String8);

var
  // Called for every problem after it is logged, from the thread that found it.
  // The engine shows the problems as toasts: noticeable, while the program goes on with defaults
  onConfigProblem:TConfigProblemProc=nil;

// Logs a problem of a config and passes it to onConfigProblem: for code that interprets
// config values itself
procedure ReportConfigProblem(const msg:String8);

implementation
uses SysUtils, Apus.Strings, Apus.Files, Apus.Log, Apus.EventMan;

type
  TDialect=(dlCTL3,dlCTL2,dlJSON);

  // A file of a document as it was read
  TSrcFile=class
    name:String8;
    text:String8;        // without the BOM
    lines:Strings8;      // without line ends
    lineBreak:String8;
    endsWithBreak:boolean;
    hasBOM:boolean;
    dialect:TDialect;
    convert:boolean;     // saved as a whole in the canonical form, not line by line
    exists:boolean;
    size:int64;
    time:TDateTime;
    procedure ReadInfo;
  end;

  // A place where a section is defined
  TSectionDef=record
    fileIdx:integer;
    header,close:integer; // lines of "name {" and "}"; -1: the whole file
    oneLine:boolean;      // an inline definition
    fileRoot:boolean;     // the content of a whole file (plain, or a root object)
  end;

  TItem=class;
  TItems=array of TItem;

  TItem=class
    kind:TCfgKind;
    isInclude:boolean;   // a hidden @include marker: value holds the file name as written
    name:String8;
    parent:TItem;
    children:TItems;     // section children (markers and deleted items included) or array items
    value:String8;       // scalar text after unquoting
    lexeme:String8;      // scalar source text (quotes included)
    fileIdx:integer;     // -1: created in memory
    line1,line2:integer; // source lines of the statement
    valLine,valCol1,valCol2:integer; // the lexeme in the source: line, first column, column after it
    oneLine:boolean;     // inline section, single-line array
    defs:array of TSectionDef;
    deleted,valueDirty,structDirty,replaced:boolean;
    warned:byte;         // read kinds already reported as not convertible
    constructor Create(aKind:TCfgKind);
    destructor Destroy; override;
  end;

  TCfgData=class
    root:TItem;
    files:array of TSrcFile;
    constructor Create;
    destructor Destroy; override;
    function Loc(it:TItem):String8;
  end;

const
  wInt=1; wFloat=2; wBool=4; wStr=8; wEnum=16; wStrs=32;

{ Problems }

procedure Problem(const msg:String8;error:boolean);
begin
  if error then Log.Error(msg) else Log.Warn(msg);
  if Assigned(onConfigProblem) then
    try
      onConfigProblem(msg);
    except
      on e:Exception do Log.Error('Config: problem handler failed: '+String8(e.Message));
    end;
end;

procedure ReportConfigProblem(const msg:String8);
begin
  Problem(msg,false);
end;

// The message of an exception without the call stack prefix of EBaseException
function PlainMessage(e:Exception):String8;
var
  i:integer;
begin
  result:=String8(e.Message);
  if (e is EBaseException) and (result<>'') and (result[1]='[') then begin
    i:=Pos(String8('] '),result);
    if i>0 then result:=copy(result,i+2,length(result));
  end;
end;

{ Helpers }

function UpCaseA(c:AnsiChar):AnsiChar; inline;
begin
  if (c>='a') and (c<='z') then result:=AnsiChar(ord(c)-32) else result:=c;
end;

function LowerA(const s:String8):String8;
var i:integer;
begin
  result:=s;
  for i:=1 to length(result) do
    if (result[i]>='A') and (result[i]<='Z') then result[i]:=AnsiChar(ord(result[i])+32);
end;

function UpperA(const s:String8):String8;
var i:integer;
begin
  result:=s;
  for i:=1 to length(result) do result[i]:=UpCaseA(result[i]);
end;

// Keys are compared with ASCII letters folded
function SameKey(const a,b:String8):boolean;
var i:integer;
begin
  result:=false;
  if length(a)<>length(b) then exit;
  for i:=1 to length(a) do
    if UpCaseA(a[i])<>UpCaseA(b[i]) then exit;
  result:=true;
end;

function IsKeyChar(c:AnsiChar):boolean; inline;
begin
  result:=(c in ['A'..'Z','a'..'z','0'..'9','_','-']) or (ord(c)>=$80);
end;

function IsBareKey(const s:String8):boolean;
var i:integer;
begin
  result:=false;
  if s='' then exit;
  for i:=1 to length(s) do
    if not IsKeyChar(s[i]) then exit;
  result:=true;
end;

function IsBlank(c:AnsiChar):boolean; inline;
begin
  result:=(c=' ') or (c=#9);
end;

function LeadingBlanks(const s:String8):String8;
var i:integer;
begin
  i:=1;
  while (i<=length(s)) and IsBlank(s[i]) do inc(i);
  result:=copy(s,1,i-1);
end;

function EncodeUTF8(code:cardinal):String8;
begin
  if code<$80 then begin
    SetLength(result,1);
    result[1]:=AnsiChar(code);
  end else
  if code<$800 then begin
    SetLength(result,2);
    result[1]:=AnsiChar($C0 or (code shr 6));
    result[2]:=AnsiChar($80 or (code and $3F));
  end else
  if code<$10000 then begin
    SetLength(result,3);
    result[1]:=AnsiChar($E0 or (code shr 12));
    result[2]:=AnsiChar($80 or ((code shr 6) and $3F));
    result[3]:=AnsiChar($80 or (code and $3F));
  end else begin
    SetLength(result,4);
    result[1]:=AnsiChar($F0 or (code shr 18));
    result[2]:=AnsiChar($80 or ((code shr 12) and $3F));
    result[3]:=AnsiChar($80 or ((code shr 6) and $3F));
    result[4]:=AnsiChar($80 or (code and $3F));
  end;
end;

// A string in double quotes with escapes; also valid JSON
function QuoteStr(const s:String8):String8;
const
  HEX:String8='0123456789ABCDEF';
var
  i,run:integer;
  esc:String8;
begin
  result:='"';
  run:=1;
  for i:=1 to length(s) do begin
    case s[i] of
      '"':esc:='\"';
      '\':esc:='\\';
      #10:esc:='\n';
      #13:esc:='\r';
      #9:esc:='\t';
      #0..#8,#11,#12,#14..#31:esc:='\u00'+HEX[ord(s[i]) shr 4+1]+HEX[ord(s[i]) and 15+1];
      else continue;
    end;
    result:=result+copy(s,run,i-run)+esc;
    run:=i+1;
  end;
  result:=result+copy(s,run,length(s)-run+1)+'"';
end;

function KeyText(const name:String8;json:boolean):String8;
begin
  if json or not IsBareKey(name) then result:=QuoteStr(name)
    else result:=name;
end;

// A value that can be written without quotes in any context
function IsSafeBare(const s:String8):boolean;
var i:integer;
begin
  result:=false;
  if (s='') or (s='null') then exit;
  for i:=1 to length(s) do
    if not (s[i] in ['A'..'Z','a'..'z','0'..'9','_','-','+','.','$',':','/','\']) then exit;
  result:=true;
end;

function SafeLexeme(const s:String8):String8;
begin
  if IsSafeBare(s) then result:=s else result:=QuoteStr(s);
end;

// [sign]digits
function IsIntLiteral(const s:String8):boolean;
var i:integer;
begin
  result:=false;
  i:=1;
  if (i<=length(s)) and (s[i] in ['-','+']) then inc(i);
  if i>length(s) then exit;
  while i<=length(s) do begin
    if not (s[i] in ['0'..'9']) then exit;
    inc(i);
  end;
  result:=true;
end;

// Skip decimal digits starting at position i, return their count
function SkipDigits(const s:String8;var i:integer):integer;
begin
  result:=0;
  while (i<=length(s)) and (s[i] in ['0'..'9']) do begin
    inc(i); inc(result);
  end;
end;

// [sign]digits[.digits][e[sign]digits]
function IsFloatLiteral(const s:String8):boolean;
var
  i:integer;
begin
  result:=false;
  i:=1;
  if (i<=length(s)) and (s[i] in ['-','+']) then inc(i);
  if SkipDigits(s,i)=0 then exit;
  if (i<=length(s)) and (s[i]='.') then begin
    inc(i);
    if SkipDigits(s,i)=0 then exit;
  end;
  if (i<=length(s)) and (s[i] in ['e','E']) then begin
    inc(i);
    if (i<=length(s)) and (s[i] in ['-','+']) then inc(i);
    if SkipDigits(s,i)=0 then exit;
  end;
  result:=i>length(s);
end;

// A float literal (validated by IsFloatLiteral) to the nearest double
function LiteralToFloat(const s:String8):double;
var
  code:integer;
begin
  Val(string(s),result,code);
  if code<>0 then result:=0;
end;

function HexDigit(c:AnsiChar):integer;
begin
  case c of
    '0'..'9':result:=ord(c)-ord('0');
    'A'..'F':result:=ord(c)-ord('A')+10;
    'a'..'f':result:=ord(c)-ord('a')+10;
    else result:=-1;
  end;
end;

// Decimal, $hex, 0xhex with an optional sign; floats with no fractional part
function TryInt(const s:String8;out v:int64):boolean;
var
  i,d,n:integer;
  neg:boolean;
  u:uint64;
  f:double;
begin
  result:=false;
  v:=0;
  if s='' then exit;
  i:=1;
  neg:=false;
  if s[1] in ['-','+'] then begin
    neg:=s[1]='-';
    inc(i);
  end;
  u:=0;
  if (i<=length(s)) and ((s[i]='$') or ((s[i]='0') and (i<length(s)) and (s[i+1] in ['x','X']))) then begin
    if s[i]='$' then inc(i) else inc(i,2);
    n:=0;
    while i<=length(s) do begin
      d:=HexDigit(s[i]);
      if (d<0) or (n=16) then exit;
      u:=(u shl 4) or uint64(d);
      inc(n); inc(i);
    end;
    if n=0 then exit;
    v:=int64(u);
    if neg then v:=-v;
    exit(true);
  end;
  if IsIntLiteral(s) then begin
    while i<=length(s) do begin
      d:=ord(s[i])-ord('0');
      if u>(uint64(9223372036854775807)+1-uint64(d)) div 10 then exit;
      u:=u*10+uint64(d);
      inc(i);
    end;
    if neg then begin
      if u>uint64(9223372036854775807)+1 then exit;
      v:=-int64(u-1)-1;
    end else begin
      if u>uint64(9223372036854775807) then exit;
      v:=int64(u);
    end;
    exit(true);
  end;
  if IsFloatLiteral(s) then begin
    f:=LiteralToFloat(s);
    if (Frac(f)=0) and (abs(f)<9.2e18) then begin
      v:=Trunc(f);
      result:=true;
    end;
  end;
end;

function TryFloat(const s:String8;out v:double):boolean;
var
  i:int64;
begin
  result:=true;
  if IsFloatLiteral(s) then begin
    v:=LiteralToFloat(s);
    exit;
  end;
  result:=TryInt(s,i);
  if result then v:=i else v:=0;
end;

function TryBool(const s:String8;out v:boolean):boolean;
var
  l:String8;
begin
  l:=LowerA(s);
  result:=true;
  if (l='on') or (l='true') or (l='yes') or (l='1') then v:=true else
  if (l='off') or (l='false') or (l='no') or (l='0') then v:=false else begin
    v:=false;
    result:=false;
  end;
end;

// Where there is no extended (FPC on Win64) FloatToStrF stops at 15 digits; Str(v:width) gives
// more: digits+7 is the width of "-d.dddE+ddd". The result has the form of ffGeneral
function StrLexeme(v:double;digits:integer):String8;
const
  ZEROS:String8='0000000000000000';
var
  s:ShortString;
  t,m:String8;
  p,e,code:integer;
  neg:boolean;
begin
  Str(v:digits+7,s);
  t:=String8(Trim(string(s)));
  result:=t;
  p:=Pos(String8('E'),t);
  if p=0 then exit;
  Val(string(copy(t,p+1,length(t))),e,code);
  if code<>0 then exit;
  m:=copy(t,1,p-1);
  neg:=(m<>'') and (m[1]='-');
  if neg then System.Delete(m,1,1);
  if (length(m)<2) or (m[2]<>'.') then exit;
  System.Delete(m,2,1); // the digits only
  while (length(m)>1) and (m[length(m)]='0') do SetLength(m,length(m)-1);
  if (e>=-4) and (e<digits) then begin
    if e<0 then result:='0.'+copy(ZEROS,1,-e-1)+m
    else
    if e+1>=length(m) then result:=m+copy(ZEROS,1,e+1-length(m))
    else result:=copy(m,1,e+1)+'.'+copy(m,e+2,length(m));
  end else begin
    result:=copy(m,1,1);
    if length(m)>1 then result:=result+'.'+copy(m,2,length(m));
    result:=result+'E'+String8(IntToStr(e));
  end;
  if neg then result:='-'+result;
end;

// A float with the given number of significant digits, trailing zeros dropped; precision<=0 or
// above 15: the shortest form that reads back to the same double. Integral values get '.0'
// to look like floats
function FloatLexeme(v:double;precision:integer):String8;
var
  fs:TFormatSettings;
  digits:integer;
  exact:boolean;
  s:String8;
begin
  {$IFDEF FPC}fs:=DefaultFormatSettings;{$ELSE}fs:=TFormatSettings.Create;{$ENDIF}
  fs.DecimalSeparator:='.';
  if (precision>0) and (precision<=15) then begin
    result:=String8(FloatToStrF(v,ffGeneral,precision,0,fs));
    if IsIntLiteral(result) then result:=result+'.0';
    exit;
  end;
  for digits:=15 to 17 do begin
    result:=String8(FloatToStrF(v,ffGeneral,digits,0,fs));
    exact:=IsFloatLiteral(result) and (LiteralToFloat(result)=v);
    if exact then break;
  end;
  if not exact then
    for digits:=16 to 17 do begin
      s:=StrLexeme(v,digits);
      if IsFloatLiteral(s) and (LiteralToFloat(s)=v) then begin
        result:=s;
        break;
      end;
    end;
  if IsIntLiteral(result) then result:=result+'.0';
end;

// The boolean in the style of the previous lexeme
function BoolLexeme(v:boolean;const old:String8;json:boolean):String8;
var
  l:String8;
begin
  l:=LowerA(old);
  if (l='true') or (l='false') then begin
    if v then result:='true' else result:='false';
  end else
  if (l='yes') or (l='no') then begin
    if v then result:='yes' else result:='no';
  end else
  if (l='1') or (l='0') then begin
    if v then result:='1' else result:='0';
  end else
  if (l='on') or (l='off') or not json then begin
    if v then result:='on' else result:='off';
  end else begin
    if v then result:='true' else result:='false';
  end;
  if (l<>'') and (old<>l) then begin
    if old=UpperA(old) then result:=UpperA(result)
      else result[1]:=UpCaseA(result[1]);
  end;
end;

function IsJsonNumber(const s:String8):boolean;
var
  i:integer;
begin
  result:=false;
  i:=1;
  if (i<=length(s)) and (s[i]='-') then inc(i);
  if SkipDigits(s,i)=0 then exit;
  if (i<=length(s)) and (s[i]='.') then begin
    inc(i);
    if SkipDigits(s,i)=0 then exit;
  end;
  if (i<=length(s)) and (s[i] in ['e','E']) then begin
    inc(i);
    if (i<=length(s)) and (s[i] in ['-','+']) then inc(i);
    if SkipDigits(s,i)=0 then exit;
  end;
  result:=i>length(s);
end;

// The UTF-8 BOM, built from bytes: a char literal above 127 is not a byte in a Unicode compiler
function UTF8BOM:String8;
begin
  SetLength(result,3);
  result[1]:=AnsiChar($EF);
  result[2]:=AnsiChar($BB);
  result[3]:=AnsiChar($BF);
end;

function BytesToStr(const data:ByteArray):String8;
begin
  SetLength(result,length(data));
  if length(data)>0 then move(data[0],result[1],length(data));
end;

function StrToBytes(const s:String8):ByteArray;
begin
  result:=nil;
  SetLength(result,length(s));
  if length(s)>0 then move(s[1],result[0],length(s));
end;

// A bare include name refers to the directory of the including file
function IncludeName(const fromFile,incl:String8):String8;
begin
  if (Pos('\',incl)=0) and (Pos('/',incl)=0) then
    result:=String8(ExtractFilePath(string(fromFile)))+incl
  else
    result:=incl;
end;

{ TSrcFile }

procedure TSrcFile.ReadInfo;
var
  info:TFileInfo;
begin
  exists:=Files.GetFileInfo(name,info);
  if exists then begin
    size:=info.size;
    time:=info.timestamp;
  end else begin
    size:=0;
    time:=0;
  end;
end;

{ TItem }

constructor TItem.Create(aKind:TCfgKind);
begin
  kind:=aKind;
  fileIdx:=-1;
  line1:=-1;
  line2:=-1;
  valLine:=-1;
end;

destructor TItem.Destroy;
var
  c:TItem;
begin
  for c in children do c.Free;
  inherited;
end;

function VisibleCount(it:TItem):integer;
var
  c:TItem;
begin
  result:=0;
  for c in it.children do
    if not c.isInclude and not c.deleted then inc(result);
end;

function VisibleChild(it:TItem;index:integer):TItem;
var
  c:TItem;
begin
  result:=nil;
  if index<0 then exit;
  for c in it.children do
    if not c.isInclude and not c.deleted then begin
      if index=0 then exit(c);
      dec(index);
    end;
end;

function FindChild(it:TItem;const name:String8):TItem;
var
  c:TItem;
begin
  result:=nil;
  for c in it.children do
    if not c.isInclude and not c.deleted and SameKey(c.name,name) then exit(c);
end;

procedure AppendChild(parent,c:TItem);
var
  n:integer;
begin
  n:=length(parent.children);
  SetLength(parent.children,n+1);
  parent.children[n]:=c;
  c.parent:=parent;
end;

{ TCfgData }

constructor TCfgData.Create;
begin
  root:=TItem.Create(ckSection);
end;

destructor TCfgData.Destroy;
var
  f:TSrcFile;
begin
  root.Free;
  for f in files do f.Free;
  inherited;
end;

function TCfgData.Loc(it:TItem):String8;
var
  f,l:integer;
begin
  result:='';
  if it=nil then exit;
  f:=it.fileIdx;
  l:=it.line1;
  if (it.kind=ckSection) and (length(it.defs)>0) then begin
    f:=it.defs[0].fileIdx;
    l:=it.defs[0].header;
  end;
  if (f<0) or (f>=length(files)) then exit;
  result:=files[f].name;
  if l>=0 then result:=result+':'+String8(IntToStr(l+1));
end;

{ Loading }

type
  TLoader=class;

  TParseMode=(pmRoot,pmBlock,pmInline);

  // Parser of one file (CTL3 with JSON, or CTL2)
  TFileParser=class
    loader:TLoader;
    data:TCfgData;
    src:TSrcFile;
    fIdx:integer;
    ln,ps:integer; // cursor: line (0-based), column (1-based)
    constructor Create(aLoader:TLoader;aFileIdx:integer);
    procedure Fail(const msg:String8); overload;
    procedure FailAt(line:integer;const msg:String8);
    function Ch:AnsiChar;
    function PeekNext:AnsiChar;
    procedure Next;
    procedure NextLine;
    procedure SkipBlanks;
    function AtLineStart:boolean;
    function SkipTrivia:boolean;
    procedure ParseFile(into:TItem);
    procedure ParseItems(sec:TItem;mode:TParseMode;out closeLine:integer);
    procedure AfterBlockValue;
    procedure ParseItem(sec:TItem;mode:TParseMode);
    function ParseKey:String8;
    function ParseValue(blockCtx:boolean;const key:String8):TItem;
    procedure ParseArray(arr:TItem;closer:AnsiChar);
    function ParseQuoted:String8;
    function ParseRaw:String8;
    procedure ParseDirective(sec:TItem);
    procedure ParseCTL2(into:TItem);
    function ParseCTL2Section(sec:TItem;isRoot:boolean):integer;
    function NewItem(kind:TCfgKind):TItem;
    function NewScalarAt(const text,lex:String8;line,c1,c2:integer):TItem;
  end;

  TLoader=class
    data:TCfgData;
    protector:IConfigProtector;
    overNames,overTexts:Strings8; // texts that replace the files (rebuild after a save)
    stack:Strings8;               // the include chain
    function LoadFile(const fname:String8;into:TItem;optional:boolean;const where:String8):integer;
    procedure AddChild(sec,item:TItem);
    function AddDef(sec:TItem;fileIdx,header,close:integer;oneLine:boolean):integer;
  end;

function TLoader.AddDef(sec:TItem;fileIdx,header,close:integer;oneLine:boolean):integer;
var
  i:integer;
  mixed:boolean;
begin
  result:=length(sec.defs);
  SetLength(sec.defs,result+1);
  sec.defs[result].fileIdx:=fileIdx;
  sec.defs[result].header:=header;
  sec.defs[result].close:=close;
  sec.defs[result].oneLine:=oneLine;
  sec.defs[result].fileRoot:=false;
  // An inline definition merged with another one can't be updated line by line
  mixed:=false;
  if length(sec.defs)>1 then
    for i:=0 to high(sec.defs) do
      if sec.defs[i].oneLine then mixed:=true;
  if mixed then
    for i:=0 to high(sec.defs) do
      if sec.defs[i].fileIdx>=0 then data.files[sec.defs[i].fileIdx].convert:=true;
end;

// Adds an item to a section by the duplicate rules: sections merge, anything else is an error
procedure TLoader.AddChild(sec,item:TItem);
var
  ex:TItem;
  kids:TItems;
  d:TSectionDef;
  msg:String8;
  i:integer;
begin
  if item.isInclude then begin
    AppendChild(sec,item);
    exit;
  end;
  ex:=FindChild(sec,item.name);
  if ex=nil then begin
    AppendChild(sec,item);
    exit;
  end;
  if (ex.kind=ckSection) and (item.kind=ckSection) then begin
    for d in item.defs do AddDef(ex,d.fileIdx,d.header,d.close,d.oneLine);
    kids:=item.children;
    item.children:=nil;
    item.Free;
    try
      for i:=0 to high(kids) do begin
        item:=kids[i];
        kids[i]:=nil;
        AddChild(ex,item); // frees the item on an error
      end;
    finally
      for i:=0 to high(kids) do kids[i].Free;
    end;
    exit;
  end;
  msg:=data.Loc(item)+': duplicate key "'+item.name+'", first defined at '+data.Loc(ex);
  item.Free;
  raise EConfigError.Create(string(msg));
end;

function TLoader.LoadFile(const fname:String8;into:TItem;optional:boolean;const where:String8):integer;
var
  name,text:String8;
  i,n,p:integer;
  src:TSrcFile;
  parser:TFileParser;
  found:boolean;
  cmd:String8;
begin
  name:=Files.FixName(fname);
  for i:=0 to high(stack) do
    if SameText(string(stack[i]),string(name)) then
      raise EConfigError.Create(string(where+': include cycle: '+name));
  src:=TSrcFile.Create;
  src.name:=name;
  src.lineBreak:=sLineBreak;
  result:=length(data.files);
  SetLength(data.files,result+1);
  data.files[result]:=src;
  found:=false;
  for i:=0 to high(overNames) do
    if overNames[i]=name then begin
      text:=overTexts[i];
      found:=true;
      src.exists:=true;
    end;
  if not found then begin
    src.ReadInfo;
    if not src.exists then begin
      if not optional then begin
        if where<>'' then raise EConfigError.Create(string(where+': included file not found: '+name))
          else raise EConfigError.Create(string('Config file not found: '+name));
      end;
      text:='';
    end else begin
      if protector<>nil then text:=BytesToStr(protector.Unprotect(Files.LoadAsBytes(name)))
        else text:=BytesToStr(Files.LoadAsBytes(name));
    end;
  end;
  // BOM, lines and line ends
  if (length(text)>=3) and (ord(text[1])=$EF) and (ord(text[2])=$BB) and (ord(text[3])=$BF) then begin
    src.hasBOM:=true;
    System.Delete(text,1,3);
  end;
  src.text:=text;
  n:=0;
  p:=1;
  for i:=1 to length(text) do
    if text[i]=#10 then begin
      SetLength(src.lines,n+1);
      if (i>p) and (text[i-1]=#13) then begin
        src.lines[n]:=copy(text,p,i-1-p);
        src.lineBreak:=#13#10;
      end else begin
        src.lines[n]:=copy(text,p,i-p);
        if n=0 then src.lineBreak:=#10;
      end;
      inc(n);
      p:=i+1;
    end;
  if p<=length(text) then begin
    SetLength(src.lines,n+1);
    src.lines[n]:=copy(text,p,length(text)-p+1);
  end;
  src.endsWithBreak:=(text<>'') and (text[length(text)]=#10);
  // Dialect
  if SameText(ExtractFileExt(string(name)),'.json') then src.dialect:=dlJSON
  else begin
    src.dialect:=dlCTL3;
    for i:=0 to high(src.lines) do begin
      cmd:=src.lines[i].TrimLeft;
      p:=1;
      while (p<=length(cmd)) and not IsBlank(cmd[p]) do inc(p);
      cmd:=UpperA(copy(cmd,1,p-1));
      if (cmd='$SECTION') or (cmd='$ENDOFSECTION') or (cmd='$INCLUDE') then begin
        src.dialect:=dlCTL2;
        src.convert:=true;
        break;
      end;
    end;
  end;
  n:=length(stack);
  SetLength(stack,n+1);
  stack[n]:=name;
  parser:=TFileParser.Create(self,result);
  try
    if src.dialect=dlCTL2 then parser.ParseCTL2(into)
      else parser.ParseFile(into);
  finally
    parser.Free;
    SetLength(stack,n);
  end;
end;

{ TFileParser }

constructor TFileParser.Create(aLoader:TLoader;aFileIdx:integer);
begin
  loader:=aLoader;
  data:=loader.data;
  fIdx:=aFileIdx;
  src:=data.files[fIdx];
  ln:=0;
  ps:=1;
end;

procedure TFileParser.FailAt(line:integer;const msg:String8);
begin
  raise EConfigError.Create(string(src.name+':'+String8(IntToStr(line+1))+': '+msg));
end;

procedure TFileParser.Fail(const msg:String8);
begin
  raise EConfigError.Create(string(src.name+':'+String8(IntToStr(ln+1))+':'+String8(IntToStr(ps))+': '+msg));
end;

// The current character: #10 at a line end, #0 at the end of the file
function TFileParser.Ch:AnsiChar;
begin
  if ln>=length(src.lines) then exit(#0);
  if ps>length(src.lines[ln]) then
    if ln=high(src.lines) then result:=#0 else result:=#10
  else
    result:=src.lines[ln][ps];
end;

function TFileParser.PeekNext:AnsiChar;
begin
  result:=#10;
  if (ln<length(src.lines)) and (ps+1<=length(src.lines[ln])) then result:=src.lines[ln][ps+1];
end;

procedure TFileParser.Next;
begin
  if ln>=length(src.lines) then exit;
  if ps>length(src.lines[ln]) then NextLine else inc(ps);
end;

procedure TFileParser.NextLine;
begin
  inc(ln);
  ps:=1;
end;

procedure TFileParser.SkipBlanks;
begin
  while IsBlank(Ch) do inc(ps);
end;

function TFileParser.AtLineStart:boolean;
var
  i:integer;
begin
  result:=false;
  for i:=1 to ps-1 do
    if not IsBlank(src.lines[ln][i]) then exit;
  result:=true;
end;

// Skips blanks, comments and line ends; returns true if a line end was crossed
function TFileParser.SkipTrivia:boolean;
var
  c:AnsiChar;
begin
  result:=false;
  repeat
    SkipBlanks;
    c:=Ch;
    if (c='#') or (((c=';') or ((c='/') and (PeekNext='/'))) and AtLineStart) then
      ps:=length(src.lines[ln])+1
    else
    if c=#10 then begin
      NextLine;
      result:=true;
    end else
      break;
  until false;
end;

function TFileParser.NewItem(kind:TCfgKind):TItem;
begin
  result:=TItem.Create(kind);
  result.fileIdx:=fIdx;
  result.line1:=ln;
  result.line2:=ln;
end;

function TFileParser.NewScalarAt(const text,lex:String8;line,c1,c2:integer):TItem;
begin
  result:=NewItem(ckScalar);
  result.value:=text;
  result.lexeme:=lex;
  result.valLine:=line;
  result.valCol1:=c1;
  result.valCol2:=c2;
end;

procedure TFileParser.ParseFile(into:TItem);
var
  h,d,close:integer;
begin
  SkipTrivia;
  if Ch='{' then begin
    // a JSON-style root object
    h:=ln;
    Next;
    SkipBlanks;
    if Ch='#' then ps:=length(src.lines[ln])+1;
    if Ch=#10 then begin
      NextLine;
      d:=loader.AddDef(into,fIdx,h,-1,false);
      into.defs[d].fileRoot:=true;
      ParseItems(into,pmBlock,close);
    end else begin
      d:=loader.AddDef(into,fIdx,h,-1,true);
      into.defs[d].fileRoot:=true;
      ParseItems(into,pmInline,close);
      src.convert:=true;
    end;
    into.defs[d].close:=close;
    SkipTrivia;
    if Ch<>#0 then Fail('unexpected text after the root object');
  end else begin
    d:=loader.AddDef(into,fIdx,-1,-1,false);
    into.defs[d].fileRoot:=true;
    ParseItems(into,pmRoot,close);
  end;
end;

procedure TFileParser.ParseItems(sec:TItem;mode:TParseMode;out closeLine:integer);
var
  c:AnsiChar;
  crossed,needSep:boolean;
begin
  closeLine:=-1;
  needSep:=false;
  repeat
    crossed:=SkipTrivia;
    c:=Ch;
    if c=#0 then begin
      if mode=pmRoot then exit;
      Fail('"}" expected');
    end;
    if c='}' then begin
      if mode=pmRoot then Fail('unexpected "}"');
      if (mode=pmBlock) and not AtLineStart then
        Fail('the closing brace of a block must start a line');
      closeLine:=ln;
      Next;
      exit;
    end;
    if c=',' then begin
      Next;
      needSep:=false;
      continue;
    end;
    if needSep and not crossed then Fail('"," or "}" expected');
    if c='@' then ParseDirective(sec)
      else ParseItem(sec,mode);
    if mode=pmInline then needSep:=true
      else AfterBlockValue;
  until false;
end;

// The rest of the line after an item of a block: a comma and a comment at most
procedure TFileParser.AfterBlockValue;
begin
  SkipBlanks;
  if Ch=',' then begin
    Next;
    SkipBlanks;
  end;
  if Ch='#' then ps:=length(src.lines[ln])+1;
  if Ch='}' then Fail('the closing brace of a block must start a line');
  if not (Ch in [#10,#0]) then Fail('unexpected text after the value');
end;

procedure TFileParser.ParseItem(sec:TItem;mode:TParseMode);
var
  l0:integer;
  key:String8;
  item:TItem;
begin
  l0:=ln;
  key:=ParseKey;
  SkipBlanks;
  if Ch in ['=',':'] then begin
    Next;
    SkipBlanks;
  end;
  item:=ParseValue(mode<>pmInline,key);
  item.name:=key;
  item.line1:=l0;
  loader.AddChild(sec,item);
end;

function TFileParser.ParseKey:String8;
var
  start:integer;
begin
  case Ch of
    '"':result:=ParseQuoted;
    '''':result:=ParseRaw;
    else begin
      start:=ps;
      while IsKeyChar(Ch) do inc(ps);
      if ps=start then Fail('key expected');
      result:=copy(src.lines[ln],start,ps-start);
    end;
  end;
end;

function TFileParser.ParseValue(blockCtx:boolean;const key:String8):TItem;
var
  c,closer:AnsiChar;
  line:String8;
  l0,c0,i,e,close,d:integer;
  text:String8;
begin
  c:=Ch;
  l0:=ln;
  case c of
    '{':begin
      result:=NewItem(ckSection);
      try
        Next;
        SkipBlanks;
        if Ch='#' then ps:=length(src.lines[ln])+1;
        if Ch=#10 then begin
          NextLine;
          d:=loader.AddDef(result,fIdx,l0,-1,false);
          ParseItems(result,pmBlock,close);
        end else begin
          d:=loader.AddDef(result,fIdx,l0,-1,true);
          result.oneLine:=true;
          ParseItems(result,pmInline,close);
        end;
        result.defs[d].close:=close;
        result.line2:=close;
      except
        result.Free;
        raise;
      end;
    end;
    '[','(':begin
      if c='[' then closer:=']' else closer:=')';
      result:=NewItem(ckArray);
      try
        Next;
        ParseArray(result,closer);
        result.oneLine:=ln=l0;
        result.line2:=ln;
      except
        result.Free;
        raise;
      end;
    end;
    '"','''':begin
      c0:=ps;
      if c='"' then text:=ParseQuoted else text:=ParseRaw;
      result:=NewScalarAt(text,copy(src.lines[ln],c0,ps-c0),ln,c0,ps);
    end;
    #10,#0:begin
      if key<>'' then Fail('value expected for key "'+key+'"');
      Fail('value expected');
      result:=nil;
    end;
    ',','}',']',')':begin
      Fail('value expected');
      result:=nil;
    end;
    else begin
      // a bare value
      line:=src.lines[ln];
      c0:=ps;
      i:=ps;
      while i<=length(line) do begin
        if (line[i]='#') and (i>c0) and IsBlank(line[i-1]) then break;
        // in an inline container a value ends at a blank too, so a missing comma is an error
        if not blockCtx and ((line[i] in [',','}',']',')']) or IsBlank(line[i])) then break;
        inc(i);
      end;
      e:=i;
      while (e>c0) and IsBlank(line[e-1]) do dec(e);
      if blockCtx and (e>c0) and (line[e-1]=',') then begin
        dec(e);
        while (e>c0) and IsBlank(line[e-1]) do dec(e);
      end;
      if e=c0 then Fail('value expected');
      text:=copy(line,c0,e-c0);
      ps:=e;
      result:=NewScalarAt(text,text,ln,c0,e);
      if text='null' then begin
        result.kind:=ckNull;
        result.value:='';
      end;
    end;
  end;
end;

procedure TFileParser.ParseArray(arr:TItem;closer:AnsiChar);
var
  c:AnsiChar;
  crossed,needSep:boolean;
  l0:integer;
  item:TItem;
begin
  needSep:=false;
  repeat
    crossed:=SkipTrivia;
    c:=Ch;
    if c=#0 then Fail('"'+closer+'" expected');
    if c=closer then begin
      Next;
      exit;
    end;
    if c=',' then begin
      Next;
      needSep:=false;
      continue;
    end;
    if needSep and not crossed then Fail('"," or "'+closer+'" expected');
    if c in [']',')','}'] then Fail('unexpected "'+c+'"');
    l0:=ln;
    item:=ParseValue(false,'');
    item.line1:=l0;
    AppendChild(arr,item);
    needSep:=true;
  until false;
end;

function TFileParser.ParseQuoted:String8;
var
  c:AnsiChar;
  run,code,code2,i,d:integer;
  line:String8;

  function ReadHex4:integer;
  var j:integer;
  begin
    result:=0;
    for j:=1 to 4 do begin
      d:=HexDigit(Ch);
      if d<0 then Fail('bad \u escape');
      result:=result*16+d;
      inc(ps);
    end;
  end;

begin
  result:='';
  line:=src.lines[ln];
  inc(ps);
  run:=ps;
  repeat
    c:=Ch;
    if c in [#10,#0] then Fail('unterminated string');
    if c='"' then begin
      result:=result+copy(line,run,ps-run);
      inc(ps);
      exit;
    end;
    if c='\' then begin
      result:=result+copy(line,run,ps-run);
      inc(ps);
      c:=Ch;
      case c of
        '"','\','/':begin result:=result+copy(line,ps,1); inc(ps); end;
        'n':begin result:=result+#10; inc(ps); end;
        'r':begin result:=result+#13; inc(ps); end;
        't':begin result:=result+#9; inc(ps); end;
        'b':begin result:=result+#8; inc(ps); end;
        'f':begin result:=result+#12; inc(ps); end;
        'u':begin
          inc(ps);
          code:=ReadHex4;
          // a surrogate pair is one character
          if (code>=$D800) and (code<$DC00) and (Ch='\') and (PeekNext='u') then begin
            i:=ps;
            inc(ps,2);
            code2:=ReadHex4;
            if (code2>=$DC00) and (code2<$E000) then
              code:=$10000+(code-$D800) shl 10+(code2-$DC00)
            else
              ps:=i;
          end;
          result:=result+EncodeUTF8(code);
        end;
        #10,#0:Fail('unterminated string');
        else result:=result+'\'; // unknown escapes are kept as they are
      end;
      run:=ps;
      continue;
    end;
    inc(ps);
  until false;
end;

function TFileParser.ParseRaw:String8;
var
  run:integer;
  line:String8;
begin
  result:='';
  line:=src.lines[ln];
  inc(ps);
  run:=ps;
  repeat
    case Ch of
      #10,#0:Fail('unterminated string');
      '''':begin
        result:=result+copy(line,run,ps-run);
        inc(ps);
        if Ch<>'''' then exit;
        run:=ps; // a doubled quote is a quote
        inc(ps);
      end;
      else inc(ps);
    end;
  until false;
end;

procedure TFileParser.ParseDirective(sec:TItem);
var
  start,l0:integer;
  word,fname:String8;
  marker:TItem;
begin
  l0:=ln;
  inc(ps);
  start:=ps;
  while Ch in ['A'..'Z','a'..'z'] do inc(ps);
  word:=copy(src.lines[ln],start,ps-start);
  if not SameKey(word,'include') then Fail('unknown directive "@'+word+'"');
  SkipBlanks;
  case Ch of
    '"':fname:=ParseQuoted;
    '''':fname:=ParseRaw;
    else Fail('file name expected');
  end;
  marker:=NewItem(ckNone);
  marker.isInclude:=true;
  marker.value:=fname;
  marker.line1:=l0;
  loader.AddChild(sec,marker);
  loader.LoadFile(IncludeName(src.name,fname),sec,false,src.name+':'+String8(IntToStr(l0+1)));
end;

// CTL2: line based, read as Apus.ControlFiles reads it
procedure TFileParser.ParseCTL2(into:TItem);
var
  d:integer;
begin
  d:=loader.AddDef(into,fIdx,-1,-1,false);
  into.defs[d].fileRoot:=true;
  ParseCTL2Section(into,true);
end;

function TFileParser.ParseCTL2Section(sec:TItem;isRoot:boolean):integer;
var
  st,cmd,arg,u,body:String8;
  i,l0,d,close:integer;
  item,s,marker:TItem;
  parts:Strings8;
begin
  while ln<length(src.lines) do begin
    st:=src.lines[ln].Trim;
    l0:=ln;
    inc(ln);
    if (st='') or (st[1] in ['#',';']) then continue;
    cmd:=st;
    arg:='';
    for i:=1 to length(st) do
      if IsBlank(st[i]) then begin
        cmd:=copy(st,1,i-1);
        arg:=copy(st,i+1,length(st)-i).TrimLeft;
        break;
      end;
    if cmd[1]='$' then begin
      u:=UpperA(cmd);
      if u='$ENDOFSECTION' then begin
        if isRoot then FailAt(l0,'unexpected $EndOfSection');
        exit(l0);
      end;
      if u='$SECTION' then begin
        if arg='' then FailAt(l0,'unnamed section');
        s:=TItem.Create(ckSection);
        s.fileIdx:=fIdx;
        s.name:=arg;
        s.line1:=l0;
        try
          d:=loader.AddDef(s,fIdx,l0,-1,false);
          close:=ParseCTL2Section(s,false);
          if close<0 then close:=length(src.lines); // a missing $EndOfSection ends at the file end
          s.defs[d].close:=close;
          s.line2:=close;
        except
          s.Free;
          raise;
        end;
        loader.AddChild(sec,s);
        continue;
      end;
      if u='$INCLUDE' then begin
        marker:=TItem.Create(ckNone);
        marker.isInclude:=true;
        marker.fileIdx:=fIdx;
        marker.value:=arg;
        marker.line1:=l0;
        marker.line2:=l0;
        loader.AddChild(sec,marker);
        loader.LoadFile(IncludeName(src.name,arg),sec,false,src.name+':'+String8(IntToStr(l0+1)));
        continue;
      end;
    end;
    if arg='' then FailAt(l0,'no value for key '+cmd);
    if arg[1]='(' then begin
      // a list of strings, may span lines
      while (arg[length(arg)]<>')') and (ln<length(src.lines)) do begin
        arg:=arg+src.lines[ln].Trim;
        inc(ln);
      end;
      if arg[length(arg)]<>')' then FailAt(l0,'unterminated list for key '+cmd);
      body:=copy(arg,2,length(arg)-2);
      item:=TItem.Create(ckArray);
      item.fileIdx:=fIdx;
      item.line1:=l0;
      item.line2:=ln-1;
      if body.Trim<>'' then begin
        parts:=body.Split(',','"');
        for i:=0 to high(parts) do begin
          s:=TItem.Create(ckScalar);
          s.fileIdx:=fIdx;
          s.line1:=l0;
          s.line2:=l0;
          s.value:=parts[i].Trim.Unquote;
          s.lexeme:=SafeLexeme(s.value);
          AppendChild(item,s);
        end;
      end;
    end else begin
      item:=TItem.Create(ckScalar);
      item.fileIdx:=fIdx;
      item.line1:=l0;
      item.line2:=l0;
      item.value:=arg.Unquote;
      item.lexeme:=SafeLexeme(item.value);
    end;
    item.name:=cmd;
    loader.AddChild(sec,item);
  end;
  result:=-1;
end;

// Reads a document: the main file and its includes. On an error visited gets the names of the
// files read so far, the failed one included
function LoadData(const fname:String8;optional:boolean;protector:IConfigProtector;
  const overNames,overTexts:Strings8;out visited:Strings8):TCfgData;
var
  loader:TLoader;
  i:integer;
begin
  visited:=nil;
  result:=TCfgData.Create;
  loader:=TLoader.Create;
  try
    loader.data:=result;
    loader.protector:=protector;
    loader.overNames:=overNames;
    loader.overTexts:=overTexts;
    try
      loader.LoadFile(fname,result.root,optional,'');
    except
      SetLength(visited,length(result.files));
      for i:=0 to high(result.files) do visited[i]:=result.files[i].name;
      FreeAndNil(result);
      raise;
    end;
  finally
    loader.Free;
  end;
end;

{ Writing }

type
  TEntryKind=(ekStmt,ekSecDef,ekInclude,ekSkip);

  // A changed value in the source text
  TPatch=record
    line,c1,c2:integer;
    lex:String8;
  end;
  TEntry=record
    line,lineEnd:integer;
    kind:TEntryKind;
    item:TItem;
    def:integer;
  end;

  // Builds the text of one file
  TEmitter=class
    data:TCfgData;
    f:integer;
    src:TSrcFile;
    preserve:boolean; // unchanged lines are copied byte for byte
    touched:boolean;  // the file content changed
    lines:Strings8;
    count:integer;
    constructor Create(aData:TCfgData;aFile:integer;aPreserve:boolean);
    procedure Add(const s:String8);
    procedure Trivia(a,b:integer;const indent:String8);
    procedure EmitRange(sec:TItem;first,last:integer;const indent:String8;insertHere:boolean);
    procedure EmitPatched(c:TItem);
    procedure Canonical(c:TItem;const indent:String8;withKey:boolean);
    function InlineText(c:TItem;withKey:boolean):String8;
    function Simple(c:TItem):boolean;
    function OwnChild(c:TItem):boolean;
    procedure Emit;
    function Text:String8;
    // JSON
    procedure JsonValue(c:TItem;const indent,prefix:String8;last:boolean);
    procedure EmitJson;
  end;

// 0: unchanged, 1: only scalar values changed, 2: structure changed
function ChangeState(c:TItem):integer;
var
  ch:TItem;
  s:integer;
begin
  if c.isInclude then exit(0);
  if (c.fileIdx<0) or c.replaced or c.structDirty then exit(2);
  if c.valueDirty then result:=1 else result:=0;
  for ch in c.children do begin
    if ch.deleted then exit(2);
    s:=ChangeState(ch);
    if s>result then result:=s;
    if result=2 then exit;
  end;
end;

function Lexeme(c:TItem):String8;
begin
  if c.kind=ckNull then result:='null' else result:=c.lexeme;
end;

constructor TEmitter.Create(aData:TCfgData;aFile:integer;aPreserve:boolean);
begin
  data:=aData;
  f:=aFile;
  src:=data.files[f];
  preserve:=aPreserve;
end;

procedure TEmitter.Add(const s:String8);
begin
  if count>=length(lines) then SetLength(lines,count*2+16);
  lines[count]:=s;
  inc(count);
end;

function TEmitter.Text:String8;
var
  i:integer;
begin
  result:='';
  for i:=0 to count-1 do begin
    result:=result+lines[i];
    if (i<count-1) or src.endsWithBreak or not preserve or not src.exists then
      result:=result+src.lineBreak;
  end;
end;

// Comment and blank lines between items
procedure TEmitter.Trivia(a,b:integer;const indent:String8);
var
  l:integer;
  s:String8;
begin
  for l:=a to b do begin
    if (l<0) or (l>=length(src.lines)) then continue;
    if preserve then Add(src.lines[l])
    else begin
      s:=src.lines[l].Trim;
      if s='' then Add('')
      else begin
        if s[1]=';' then s:='#'+copy(s,2,length(s)-1);
        Add(indent+s);
      end;
    end;
  end;
end;

// Children of a section that belong to this file: from it, or new ones (not from another file)
function TEmitter.OwnChild(c:TItem):boolean;
begin
  result:=(c.fileIdx<0) or (c.fileIdx=f);
  if (c.kind=ckSection) and (length(c.defs)>0) and (c.defs[0].fileIdx>=0) then
    result:=c.defs[0].fileIdx=f;
end;

function TEmitter.Simple(c:TItem):boolean;
var
  ch:TItem;
begin
  result:=true;
  case c.kind of
    ckScalar,ckNull:exit;
    ckArray:for ch in c.children do
      if not ch.deleted and not (ch.kind in [ckScalar,ckNull]) then exit(false);
    ckSection:begin
      if not c.oneLine then exit(false);
      for ch in c.children do
        if not ch.deleted and (ch.isInclude or not Simple(ch)) then exit(false);
    end;
  end;
end;

// A simple item on one line
function TEmitter.InlineText(c:TItem;withKey:boolean):String8;
var
  ch:TItem;
  first:boolean;
begin
  if withKey then begin
    result:=KeyText(c.name,false);
    if c.kind=ckSection then result:=result+' ' else result:=result+' = ';
  end else
    result:='';
  case c.kind of
    ckScalar,ckNull:result:=result+Lexeme(c);
    ckArray:begin
      result:=result+'[';
      first:=true;
      for ch in c.children do
        if not ch.deleted then begin
          if not first then result:=result+', ';
          result:=result+Lexeme(ch);
          first:=false;
        end;
      result:=result+']';
    end;
    ckSection:begin
      result:=result+'{';
      first:=true;
      for ch in c.children do
        if not ch.deleted and not ch.isInclude then begin
          if first then result:=result+' ' else result:=result+', ';
          result:=result+InlineText(ch,true);
          first:=false;
        end;
      result:=result+' }';
    end;
  end;
end;

procedure TEmitter.Canonical(c:TItem;const indent:String8;withKey:boolean);
var
  ch:TItem;
  kv:String8;
begin
  if Simple(c) and ((c.kind<>ckSection) or c.oneLine) then begin
    Add(indent+InlineText(c,withKey));
    exit;
  end;
  kv:='';
  case c.kind of
    ckArray:begin
      if withKey then kv:=KeyText(c.name,false)+' = ';
      Add(indent+kv+'[');
      for ch in c.children do
        if not ch.deleted then Canonical(ch,indent+'  ',false);
      Add(indent+']');
    end;
    ckSection:begin
      if withKey then kv:=KeyText(c.name,false)+' ';
      Add(indent+kv+'{');
      for ch in c.children do begin
        if ch.deleted then continue;
        if ch.isInclude then begin
          if ch.fileIdx=f then Add(indent+'  @include '+QuoteStr(ch.value));
          continue;
        end;
        if OwnChild(ch) then Canonical(ch,indent+'  ',true);
      end;
      Add(indent+'}');
    end;
  end;
end;

// The original lines of an item with the changed values replaced
procedure TEmitter.EmitPatched(c:TItem);
var
  buf:Strings8;
  patches:array of TPatch;
  i,j:integer;
  p:TPatch;

  procedure Collect(it:TItem);
  var
    ch:TItem;
    n:integer;
  begin
    if it.deleted then exit;
    if it.valueDirty and (it.valLine>=c.line1) and (it.valLine<=c.line2) then begin
      n:=length(patches);
      SetLength(patches,n+1);
      patches[n].line:=it.valLine-c.line1;
      patches[n].c1:=it.valCol1;
      patches[n].c2:=it.valCol2;
      patches[n].lex:=it.lexeme;
    end;
    for ch in it.children do Collect(ch);
  end;

begin
  SetLength(buf,c.line2-c.line1+1);
  for i:=0 to high(buf) do buf[i]:=src.lines[c.line1+i];
  patches:=nil;
  Collect(c);
  // right to left within a line, so the columns of the others stay valid
  for i:=1 to high(patches) do begin
    p:=patches[i];
    j:=i-1;
    while (j>=0) and ((patches[j].line>p.line) or (patches[j].line=p.line) and (patches[j].c1<p.c1)) do begin
      patches[j+1]:=patches[j];
      dec(j);
    end;
    patches[j+1]:=p;
  end;
  for p in patches do
    buf[p.line]:=copy(buf[p.line],1,p.c1-1)+p.lex+copy(buf[p.line],p.c2,length(buf[p.line]));
  for i:=0 to high(buf) do Add(buf[i]);
end;

procedure TEmitter.EmitRange(sec:TItem;first,last:integer;const indent:String8;insertHere:boolean);
var
  entries:array of TEntry;
  news:TItems;
  n,i,j,cursor:integer;
  c:TItem;
  d:TSectionDef;
  e:TEntry;
  st:integer;
  ind:String8;

  procedure AddEntry(line,lineEnd:integer;kind:TEntryKind;item:TItem;def:integer);
  begin
    SetLength(entries,n+1);
    entries[n].line:=line;
    entries[n].lineEnd:=lineEnd;
    entries[n].kind:=kind;
    entries[n].item:=item;
    entries[n].def:=def;
    inc(n);
  end;

  function InRange(l:integer):boolean;
  begin
    result:=(l>=first) and (l<=last);
  end;

  // A section is written by its definitions, not as one statement (a single inline
  // definition is a statement)
  function ByDefs(c:TItem):boolean;
  begin
    result:=(c.kind=ckSection) and (length(c.defs)>0) and (c.fileIdx>=0) and
      not ((length(c.defs)=1) and c.defs[0].oneLine);
  end;

begin
  n:=0;
  news:=nil;
  for c in sec.children do begin
    if c.isInclude then begin
      if (c.fileIdx=f) and InRange(c.line1) then AddEntry(c.line1,c.line1,ekInclude,c,0);
      continue;
    end;
    if c.deleted then begin
      // the lines of a deleted item are dropped
      if (c.kind=ckSection) and (length(c.defs)>0) and (c.fileIdx>=0) then begin
        for d in c.defs do
          if (d.fileIdx=f) and InRange(d.header) then begin
            if d.close>=d.header then AddEntry(d.header,d.close,ekSkip,c,0)
              else AddEntry(d.header,d.header,ekSkip,c,0);
            touched:=true;
          end;
      end else
      if (c.fileIdx=f) and InRange(c.line1) then begin
        AddEntry(c.line1,c.line2,ekSkip,c,0);
        touched:=true;
      end;
      continue;
    end;
    if (c.fileIdx<0) and not c.replaced then begin
      if insertHere then begin
        SetLength(news,length(news)+1);
        news[high(news)]:=c;
      end;
      continue;
    end;
    if ByDefs(c) then begin
      for i:=0 to high(c.defs) do begin
        d:=c.defs[i];
        if (d.fileIdx=f) and InRange(d.header) then
          if d.close>=d.header then AddEntry(d.header,d.close,ekSecDef,c,i)
            else AddEntry(d.header,d.header,ekSecDef,c,i);
      end;
      continue;
    end;
    if (c.fileIdx=f) and InRange(c.line1) then AddEntry(c.line1,c.line2,ekStmt,c,0);
  end;
  // source order
  for i:=1 to n-1 do begin
    e:=entries[i];
    j:=i-1;
    while (j>=0) and (entries[j].line>e.line) do begin
      entries[j+1]:=entries[j];
      dec(j);
    end;
    entries[j+1]:=e;
  end;
  cursor:=first;
  for i:=0 to n-1 do begin
    e:=entries[i];
    if e.line>cursor then Trivia(cursor,e.line-1,indent);
    case e.kind of
      ekSkip:;
      ekInclude:
        if preserve then Add(src.lines[e.line])
          else Add(indent+'@include '+QuoteStr(e.item.value));
      ekSecDef:begin
        c:=e.item;
        d:=c.defs[e.def];
        if preserve then begin
          Add(src.lines[d.header]);
          EmitRange(c,d.header+1,d.close-1,LeadingBlanks(src.lines[d.header])+'  ',e.def=0);
          Add(src.lines[d.close]);
        end else begin
          Add(indent+KeyText(c.name,false)+' {');
          if d.oneLine then EmitRange(c,d.header,d.close,indent+'  ',e.def=0)
            else EmitRange(c,d.header+1,d.close-1,indent+'  ',e.def=0);
          Add(indent+'}');
        end;
      end;
      ekStmt:begin
        c:=e.item;
        st:=ChangeState(c);
        if st>0 then touched:=true;
        if preserve and (st=0) then
          for j:=c.line1 to c.line2 do Add(src.lines[j])
        else
        if preserve and (st=1) then
          EmitPatched(c)
        else begin
          if preserve then ind:=LeadingBlanks(src.lines[c.line1]) else ind:=indent;
          Canonical(c,ind,true);
        end;
      end;
    end;
    if e.lineEnd+1>cursor then cursor:=e.lineEnd+1;
  end;
  Trivia(cursor,last,indent);
  for c in news do begin
    touched:=true;
    Canonical(c,indent,true);
  end;
end;

// Finds the section the whole file defines
function FindFileDef(it:TItem;f:integer;out sec:TItem;out def:integer):boolean;
var
  i:integer;
  c:TItem;
begin
  for i:=0 to high(it.defs) do
    if (it.defs[i].fileIdx=f) and it.defs[i].fileRoot then begin
      sec:=it;
      def:=i;
      exit(true);
    end;
  for c in it.children do
    if (c.kind=ckSection) and FindFileDef(c,f,sec,def) then exit(true);
  result:=false;
end;

procedure TEmitter.Emit;
var
  sec:TItem;
  di:integer;
  d:TSectionDef;
begin
  if not FindFileDef(data.root,f,sec,di) then exit;
  d:=sec.defs[di];
  if d.header<0 then
    EmitRange(sec,0,high(src.lines),'',di=0)
  else
  if preserve then begin
    // a root object: keep the braces
    Trivia(0,d.header-1,'');
    Add(src.lines[d.header]);
    EmitRange(sec,d.header+1,d.close-1,LeadingBlanks(src.lines[d.header])+'  ',di=0);
    Add(src.lines[d.close]);
    Trivia(d.close+1,high(src.lines),'');
  end else
    EmitRange(sec,d.header,d.close,'',di=0);
end;

function JsonLexeme(c:TItem):String8;
var
  l:String8;
  b:boolean;
begin
  if c.kind=ckNull then exit('null');
  l:=c.lexeme;
  if (l<>'') and not (l[1] in ['"','''']) then begin
    if IsJsonNumber(l) or (l='true') or (l='false') then exit(l);
    if (LowerA(l)<>'1') and (LowerA(l)<>'0') and TryBool(l,b) then begin
      if b then exit('true') else exit('false');
    end;
  end;
  result:=QuoteStr(c.value);
end;

procedure TEmitter.JsonValue(c:TItem;const indent,prefix:String8;last:boolean);
var
  comma,s:String8;
  ch:TItem;
  items:TItems;
  i:integer;
  simple:boolean;
begin
  if last then comma:='' else comma:=',';
  case c.kind of
    ckScalar,ckNull:Add(indent+prefix+JsonLexeme(c)+comma);
    ckArray,ckSection:begin
      items:=nil;
      simple:=true;
      for ch in c.children do
        if not ch.deleted and not ch.isInclude and ((c.kind=ckArray) or OwnChild(ch)) then begin
          SetLength(items,length(items)+1);
          items[high(items)]:=ch;
          if not (ch.kind in [ckScalar,ckNull]) then simple:=false;
        end;
      if c.kind=ckArray then begin
        if simple then begin
          s:='';
          for i:=0 to high(items) do begin
            if i>0 then s:=s+', ';
            s:=s+JsonLexeme(items[i]);
          end;
          Add(indent+prefix+'['+s+']'+comma);
        end else begin
          Add(indent+prefix+'[');
          for i:=0 to high(items) do JsonValue(items[i],indent+'  ','',i=high(items));
          Add(indent+']'+comma);
        end;
      end else begin
        if length(items)=0 then
          Add(indent+prefix+'{}'+comma)
        else begin
          Add(indent+prefix+'{');
          for i:=0 to high(items) do
            JsonValue(items[i],indent+'  ',QuoteStr(items[i].name)+': ',i=high(items));
          Add(indent+'}'+comma);
        end;
      end;
    end;
  end;
end;

procedure TEmitter.EmitJson;
var
  sec:TItem;
  di:integer;
begin
  if FindFileDef(data.root,f,sec,di) then JsonValue(sec,'','',true);
end;

{ TConfig }

constructor TConfig.Create(const fname:String8;optional:boolean=false;protector:IConfigProtector=nil);
begin
  lock.Init('Config',600);
  fileName:=fname;
  self.optional:=optional;
  self.protector:=protector;
  if not TryLoad(data) then begin
    placeholder:=true;
    failedState:=FileStates;
    Problem('Config: '+fLoadError+'; defaults are used',true);
  end;
end;

destructor TConfig.Destroy;
begin
  FreeAndNil(data);
  lock.Cleanup;
  inherited;
end;

// Reads the document into newData. On an error newData is an empty document that remembers
// the states of the files it tried, and LoadError is set
function TConfig.TryLoad(out newData:TObject):boolean;
var
  visited:Strings8;
  d:TCfgData;
  src:TSrcFile;
  i:integer;
begin
  try
    newData:=LoadData(fileName,optional,protector,nil,nil,visited);
    for src in TCfgData(newData).files do src.ReadInfo;
    fLoadError:='';
    result:=true;
  except
    on e:Exception do begin
      fLoadError:=PlainMessage(e);
      if not (e is EConfigError) then fLoadError:=fileName+': '+fLoadError;
      if length(visited)=0 then begin
        SetLength(visited,1);
        visited[0]:=Files.FixName(fileName);
      end;
      d:=TCfgData.Create;
      SetLength(d.files,length(visited));
      for i:=0 to high(visited) do begin
        src:=TSrcFile.Create;
        src.name:=visited[i];
        src.lineBreak:=sLineBreak;
        src.ReadInfo;
        d.files[i]:=src;
      end;
      newData:=d;
      result:=false;
    end;
  end;
end;

function TConfig.Root:TCfgNode;
begin
  result.doc:=self;
  result.segs:=nil;
end;

function TConfig.Node(const path:String8):TCfgNode;
begin
  result:=Root.Node(path);
end;

function TConfig.Modified:boolean;
begin
  lock.Enter;
  try
    result:=modifiedFlag;
  finally lock.Leave; end;
end;

function TConfig.LoadError:String8;
begin
  lock.Enter;
  try
    result:=fLoadError;
  finally lock.Leave; end;
end;

function TConfig.FileStates:String8;
var
  f:TSrcFile;
  info:TFileInfo;
begin
  result:='';
  for f in TCfgData(data).files do
    if Files.GetFileInfo(f.name,info) then
      result:=result+f.name+'|'+String8(IntToStr(info.size))+'|'+String8(FloatToStr(info.timestamp))+#10
    else
      result:=result+f.name+'|-'#10;
end;

function TConfig.Changed:boolean;
var
  f:TSrcFile;
  info:TFileInfo;
  e:boolean;
begin
  lock.Enter;
  try
    result:=false;
    for f in TCfgData(data).files do begin
      e:=Files.GetFileInfo(f.name,info);
      if (e<>f.exists) or (e and ((info.size<>f.size) or (info.timestamp<>f.time))) then exit(true);
    end;
  finally lock.Leave; end;
end;

procedure TConfig.ApplyReload(newData:TObject);
begin
  data.Free;
  data:=newData;
  modifiedFlag:=false;
end;

function TConfig.Reload:boolean;
var
  newData:TObject;
begin
  result:=false;
  lock.Enter;
  try
    // unsaved changes can't be saved over a file that failed to load, so they don't hold a reload
    if modifiedFlag and (fLoadError='') then begin
      Log.Warn('Config: %s has unsaved changes, not reloaded',[fileName]);
      exit;
    end;
    if TryLoad(newData) then begin
      ApplyReload(newData);
      placeholder:=false;
      failedState:='';
      result:=true;
    end else begin
      if placeholder then begin
        // there is no content of the file to keep: the new empty document knows the files tried now
        ApplyReload(newData);
        Problem('Config: '+fLoadError+'; defaults are used',true);
      end else begin
        newData.Free;
        Problem('Config: '+fLoadError+'; the previous content is kept',true);
      end;
      failedState:=FileStates;
    end;
  finally lock.Leave; end;
  if result then Signal('Config\Reloaded',TTag(UIntPtr(self)));
end;

function TConfig.ReloadIfChanged:boolean;
begin
  result:=false;
  if not Changed then exit;
  lock.Enter;
  try
    if FileStates=failedState then exit; // the same broken files are not tried again
  finally lock.Leave; end;
  result:=Reload;
end;

function TConfig.Save:boolean;
var
  d,newData:TCfgData;
  i,n:integer;
  em:TEmitter;
  src:TSrcFile;
  names,texts,visited:Strings8;
  written:array of boolean;
  text:String8;
  bytes:ByteArray;
  allNames,allTexts:Strings8;
begin
  result:=true;
  lock.Enter;
  try
    if not modifiedFlag then exit;
    if fLoadError<>'' then begin
      Log.Warn('Config: %s is not saved: it failed to load, the file is kept as it is',[fileName]);
      exit(false);
    end;
    d:=TCfgData(data);
    try
      // Build all the texts first
      names:=nil;
      texts:=nil;
      SetLength(written,length(d.files));
      for i:=0 to high(d.files) do begin
        src:=d.files[i];
        em:=TEmitter.Create(d,i,(src.dialect=dlCTL3) and not src.convert);
        try
          em.Emit;
          if em.touched and (src.dialect=dlJSON) then begin
            em.count:=0;
            em.EmitJson;
          end;
          if em.touched then begin
            n:=length(names);
            SetLength(names,n+1);
            SetLength(texts,n+1);
            names[n]:=src.name;
            texts[n]:=em.Text;
            written[i]:=true;
          end;
        finally
          em.Free;
        end;
      end;
      // Write them
      for i:=0 to high(names) do begin
        text:=texts[i];
        for n:=0 to high(d.files) do
          if (d.files[n].name=names[i]) and d.files[n].hasBOM then text:=UTF8BOM+text;
        bytes:=StrToBytes(text);
        if protector<>nil then bytes:=protector.Protect(bytes);
        Files.Save(names[i],bytes);
      end;
      // Rebuild the tree from the new texts: source positions become valid again
      SetLength(allNames,length(d.files));
      SetLength(allTexts,length(d.files));
      for i:=0 to high(d.files) do begin
        allNames[i]:=d.files[i].name;
        allTexts[i]:=d.files[i].text;
        if d.files[i].hasBOM then allTexts[i]:=UTF8BOM+allTexts[i];
        for n:=0 to high(names) do
          if names[n]=allNames[i] then begin
            allTexts[i]:=texts[n];
            if d.files[i].hasBOM then allTexts[i]:=UTF8BOM+allTexts[i];
          end;
      end;
      newData:=LoadData(fileName,optional,nil,allNames,allTexts,visited);
      for i:=0 to high(newData.files) do begin
        src:=newData.files[i];
        src.ReadInfo;
        for n:=0 to high(d.files) do
          if (d.files[n].name=src.name) and not written[n] then begin
            src.exists:=d.files[n].exists;
            src.size:=d.files[n].size;
            src.time:=d.files[n].time;
          end;
      end;
      data.Free;
      data:=newData;
      modifiedFlag:=false;
    except
      on e:Exception do begin
        Problem('Config: can''t save '+fileName+': '+PlainMessage(e),true);
        result:=false;
      end;
    end;
  finally lock.Leave; end;
end;

{ Paths }

function ParsePath(const path:String8):TCfgSegments;
var
  i,start,n,v:integer;

  procedure AddSeg(const name:String8;index:integer);
  begin
    SetLength(result,n+1);
    result[n].name:=name;
    result[n].index:=index;
    inc(n);
  end;

begin
  result:=nil;
  n:=0;
  i:=1;
  start:=1;
  while i<=length(path) do begin
    case path[i] of
      '.','\','/':begin
        if i>start then AddSeg(copy(path,start,i-start),-1);
        start:=i+1;
      end;
      '[':begin
        if i>start then AddSeg(copy(path,start,i-start),-1);
        inc(i);
        v:=0;
        if (i>length(path)) or not (path[i] in ['0'..'9']) then
          raise EConfigError.Create('Config: bad index in path "'+string(path)+'"');
        while (i<=length(path)) and (path[i] in ['0'..'9']) do begin
          v:=v*10+ord(path[i])-ord('0');
          inc(i);
        end;
        if (i>length(path)) or (path[i]<>']') then
          raise EConfigError.Create('Config: "]" expected in path "'+string(path)+'"');
        AddSeg('',v);
        start:=i+1;
      end;
    end;
    inc(i);
  end;
  if length(path)>=start then AddSeg(copy(path,start,length(path)-start+1),-1);
end;

function PathText(const segs:TCfgSegments):String8;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(segs) do
    if segs[i].index>=0 then result:=result+'['+String8(IntToStr(segs[i].index))+']'
    else begin
      if result<>'' then result:=result+'.';
      result:=result+segs[i].name;
    end;
end;

function JoinSegs(const a,b:TCfgSegments):TCfgSegments;
var
  i:integer;
begin
  result:=nil;
  SetLength(result,length(a)+length(b));
  for i:=0 to high(a) do result[i]:=a[i];
  for i:=0 to high(b) do result[length(a)+i]:=b[i];
end;

function FindItem(data:TCfgData;const segs:TCfgSegments):TItem;
var
  i:integer;
begin
  result:=data.root;
  for i:=0 to high(segs) do begin
    if segs[i].index>=0 then begin
      if result.kind<>ckArray then exit(nil);
      result:=VisibleChild(result,segs[i].index);
    end else begin
      if result.kind<>ckSection then exit(nil);
      result:=FindChild(result,segs[i].name);
    end;
    if result=nil then exit;
  end;
end;

{ Reading }

procedure WarnValue(data:TCfgData;it:TItem;flag:byte;const what:String8);
begin
  if it.warned and flag<>0 then exit;
  it.warned:=it.warned or flag;
  Problem('Config: '+data.Loc(it)+': "'+it.value+'" is not '+what+', the default is used',false);
end;

function KindName(k:TCfgKind):String8;
begin
  case k of
    ckSection:result:='a section';
    ckArray:result:='an array';
    else result:='a value';
  end;
end;

// The scalar at the path; false when it is missing, null or not a scalar (reported)
function ScalarAt(doc:TConfig;const segs:TCfgSegments;flag:byte;const what:String8;out it:TItem):boolean;
begin
  it:=FindItem(TCfgData(doc.data),segs);
  result:=false;
  if (it=nil) or (it.kind=ckNull) then exit;
  if it.kind<>ckScalar then begin
    if it.warned and flag=0 then begin
      it.warned:=it.warned or flag;
      Problem('Config: '+TCfgData(doc.data).Loc(it)+': '+PathText(segs)+' is '+KindName(it.kind)+', not '+what+', the default is used',false);
    end;
    exit;
  end;
  result:=true;
end;

procedure StrictFail(doc:TConfig;const segs:TCfgSegments;it:TItem;const what:String8);
begin
  if it=nil then
    raise EConfigError.Create(string('Config: '+doc.fileName+': "'+PathText(segs)+'" is missing'))
  else
    raise EConfigError.Create(string('Config: '+TCfgData(doc.data).Loc(it)+': "'+PathText(segs)+'" is not '+what));
end;

{ TCfgNode }

function TCfgNode.Extended(const path:String8):TCfgNode;
begin
  result.doc:=doc;
  if path='' then result.segs:=JoinSegs(segs,nil)
    else result.segs:=JoinSegs(segs,ParsePath(path));
end;

function TCfgNode.Node(const path:String8):TCfgNode;
begin
  result:=Extended(path);
end;

function TCfgNode.Child(const name:String8):TCfgNode;
var
  s:TCfgSegments;
begin
  SetLength(s,1);
  s[0].name:=name;
  s[0].index:=-1;
  result.doc:=doc;
  result.segs:=JoinSegs(segs,s);
end;

function TCfgNode.Exists:boolean;
begin
  result:=Kind<>ckNone;
end;

function TCfgNode.Kind:TCfgKind;
var
  it:TItem;
begin
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),segs);
    if it=nil then result:=ckNone else result:=it.kind;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Name:String8;
var
  it:TItem;
begin
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),segs);
    if it<>nil then result:=it.name
    else
    if length(segs)>0 then result:=segs[high(segs)].name
    else result:='';
  finally doc.lock.Leave; end;
end;

function TCfgNode.Path:String8;
begin
  result:=PathText(segs);
end;

function TCfgNode.Location:String8;
begin
  doc.lock.Enter;
  try
    result:=TCfgData(doc.data).Loc(FindItem(TCfgData(doc.data),segs));
  finally doc.lock.Leave; end;
end;

function TCfgNode.Count:integer;
var
  it:TItem;
begin
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),segs);
    if (it<>nil) and (it.kind in [ckSection,ckArray]) then result:=VisibleCount(it)
      else result:=0;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Item(index:integer):TCfgNode;
var
  it,c:TItem;
  s:TCfgSegments;
begin
  SetLength(s,1);
  s[0].name:='';
  s[0].index:=index;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),segs);
    if (it<>nil) and (it.kind=ckSection) then begin
      c:=VisibleChild(it,index);
      if c<>nil then begin
        s[0].name:=c.name;
        s[0].index:=-1;
      end;
    end;
  finally doc.lock.Leave; end;
  result.doc:=doc;
  result.segs:=JoinSegs(segs,s);
end;

function TCfgNode.GetEnumerator:TCfgEnumerator;
begin
  result:=TCfgEnumerator.Create;
  result.node:=self;
  result.index:=-1;
  result.count:=Count;
end;

function TCfgNode.Int(const path:String8;default:int64):int64;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    result:=default;
    if ScalarAt(doc,s,wInt,'an integer',it) then
      if not TryInt(it.value,result) then begin
        result:=default;
        WarnValue(TCfgData(doc.data),it,wInt,'an integer');
      end;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Float(const path:String8;default:double):double;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    result:=default;
    if ScalarAt(doc,s,wFloat,'a number',it) then
      if not TryFloat(it.value,result) then begin
        result:=default;
        WarnValue(TCfgData(doc.data),it,wFloat,'a number');
      end;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Bool(const path:String8;default:boolean):boolean;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    result:=default;
    if ScalarAt(doc,s,wBool,'a boolean',it) then
      if not TryBool(it.value,result) then begin
        result:=default;
        WarnValue(TCfgData(doc.data),it,wBool,'a boolean');
      end;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Str(const path:String8;const default:String8):String8;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    if ScalarAt(doc,s,wStr,'a string',it) then result:=it.value
      else result:=default;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Enum(const path:String8;const names:array of String8;default:integer):integer;
var
  it:TItem;
  s:TCfgSegments;
  i:integer;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    result:=default;
    if ScalarAt(doc,s,wEnum,'one of the names',it) then begin
      for i:=0 to high(names) do
        if SameKey(names[i],it.value) then exit(i);
      WarnValue(TCfgData(doc.data),it,wEnum,'one of the expected names');
    end;
  finally doc.lock.Leave; end;
end;

function TCfgNode.Strs(const path:String8):Strings8;
var
  it,c:TItem;
  s:TCfgSegments;
  n:integer;
begin
  s:=Extended(path).segs;
  result:=nil;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if (it=nil) or (it.kind=ckNull) then exit;
    case it.kind of
      ckScalar:begin
        SetLength(result,1);
        result[0]:=it.value;
      end;
      ckArray:begin
        n:=0;
        SetLength(result,VisibleCount(it));
        for c in it.children do begin
          if c.deleted then continue;
          if c.kind in [ckScalar,ckNull] then begin
            result[n]:=c.value;
            inc(n);
          end else
            WarnValue(TCfgData(doc.data),c,wStrs,'a string');
        end;
        SetLength(result,n);
      end;
      ckSection:if it.warned and wStrs=0 then begin
        it.warned:=it.warned or wStrs;
        Problem('Config: '+TCfgData(doc.data).Loc(it)+': '+PathText(s)+' is a section, not a list of strings',false);
      end;
    end;
  finally doc.lock.Leave; end;
end;

function TCfgNode.AsInt(default:int64):int64;
begin
  result:=Int('',default);
end;

function TCfgNode.AsFloat(default:double):double;
begin
  result:=Float('',default);
end;

function TCfgNode.AsBool(default:boolean):boolean;
begin
  result:=Bool('',default);
end;

function TCfgNode.AsStr(const default:String8):String8;
begin
  result:=Str('',default);
end;

function TCfgNode.ReqInt(const path:String8):int64;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if (it=nil) or (it.kind<>ckScalar) or not TryInt(it.value,result) then StrictFail(doc,s,it,'an integer');
  finally doc.lock.Leave; end;
end;

function TCfgNode.ReqFloat(const path:String8):double;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if (it=nil) or (it.kind<>ckScalar) or not TryFloat(it.value,result) then StrictFail(doc,s,it,'a number');
  finally doc.lock.Leave; end;
end;

function TCfgNode.ReqBool(const path:String8):boolean;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if (it=nil) or (it.kind<>ckScalar) or not TryBool(it.value,result) then StrictFail(doc,s,it,'a boolean');
  finally doc.lock.Leave; end;
end;

function TCfgNode.ReqStr(const path:String8):String8;
var
  it:TItem;
  s:TCfgSegments;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if (it=nil) or (it.kind<>ckScalar) then StrictFail(doc,s,it,'a string');
    result:=it.value;
  finally doc.lock.Leave; end;
end;

{ Writing values }

// The file a new child of the item goes to
function TargetFile(data:TCfgData;it:TItem):integer;
begin
  while it<>nil do begin
    if (length(it.defs)>0) and (it.defs[0].fileIdx>=0) then exit(it.defs[0].fileIdx);
    if it.fileIdx>=0 then exit(it.fileIdx);
    it:=it.parent;
  end;
  result:=0;
end;

// A write that the file content doesn't allow: reported, the document is left as it is
procedure WriteConflict(doc:TConfig;const segs:TCfgSegments;const why:String8);
begin
  Problem('Config: '+doc.fileName+': "'+PathText(segs)+'" is not written: '+why,false);
end;

// Walks the path creating missing sections; returns the container of the last step and the
// item there (nil if missing). An empty path gives the root as the item. False (reported) if
// the content of the document doesn't allow the path
function PrepareWrite(doc:TConfig;const segs:TCfgSegments;out parent,item:TItem):boolean;
var
  i:integer;
  cur,next:TItem;
begin
  result:=false;
  cur:=TCfgData(doc.data).root;
  parent:=nil;
  item:=cur;
  for i:=0 to high(segs) do begin
    if segs[i].index>=0 then begin
      if cur.kind<>ckArray then begin
        WriteConflict(doc,segs,'"'+PathText(Copy(segs,0,i))+'" is '+KindName(cur.kind)+', not an array');
        exit;
      end;
      next:=VisibleChild(cur,segs[i].index);
      if next=nil then begin
        WriteConflict(doc,segs,'no such item');
        exit;
      end;
    end else begin
      if cur.kind<>ckSection then begin
        WriteConflict(doc,segs,'"'+PathText(Copy(segs,0,i))+'" is '+KindName(cur.kind)+', not a section');
        exit;
      end;
      next:=FindChild(cur,segs[i].name);
      if (next=nil) and (i<high(segs)) then begin
        next:=TItem.Create(ckSection);
        next.name:=segs[i].name;
        AppendChild(cur,next);
        cur.structDirty:=true;
      end;
    end;
    parent:=cur;
    item:=next;
    cur:=next;
  end;
  result:=true;
end;

procedure ReplaceItem(parent,old,new:TItem);
var
  i:integer;
begin
  new.name:=old.name;
  new.parent:=parent;
  if old.fileIdx>=0 then begin
    new.fileIdx:=old.fileIdx;
    new.line1:=old.line1;
    new.line2:=old.line2;
    new.replaced:=true;
  end;
  for i:=0 to high(parent.children) do
    if parent.children[i]=old then parent.children[i]:=new;
  old.Free;
  parent.structDirty:=true;
end;

// Stores a value item (scalar or array) at the path
procedure StoreValue(doc:TConfig;const segs:TCfgSegments;value:TItem);
var
  parent,item:TItem;
begin
  try
    if length(segs)=0 then raise EConfigError.Create('Config: can''t write a value to the root');
    if not PrepareWrite(doc,segs,parent,item) then begin
      value.Free;
      exit;
    end;
    if item=nil then begin
      value.name:=segs[high(segs)].name;
      AppendChild(parent,value);
      parent.structDirty:=true;
    end else begin
      if item.kind=ckSection then begin
        WriteConflict(doc,segs,'it is a section at '+TCfgData(doc.data).Loc(item));
        value.Free;
        exit;
      end;
      if (value.kind=ckScalar) and (item.kind in [ckScalar,ckNull]) then begin
        item.kind:=ckScalar;
        item.value:=value.value;
        item.lexeme:=value.lexeme;
        item.valueDirty:=true;
        value.Free;
      end else
        ReplaceItem(parent,item,value);
    end;
    doc.modifiedFlag:=true;
  except
    if value.parent=nil then value.Free;
    raise;
  end;
end;

function NewScalar(const value,lexeme:String8):TItem;
begin
  result:=TItem.Create(ckScalar);
  result.value:=value;
  result.lexeme:=lexeme;
end;

procedure TCfgNode.SetInt(const path:String8;value:int64);
var
  s:String8;
begin
  s:=String8(IntToStr(value));
  doc.lock.Enter;
  try
    StoreValue(doc,Extended(path).segs,NewScalar(s,s));
  finally doc.lock.Leave; end;
end;

procedure TCfgNode.SetFloat(const path:String8;value:double;digits:integer);
var
  s:String8;
begin
  s:=FloatLexeme(value,digits);
  doc.lock.Enter;
  try
    StoreValue(doc,Extended(path).segs,NewScalar(s,s));
  finally doc.lock.Leave; end;
end;

procedure TCfgNode.SetBool(const path:String8;value:boolean);
var
  s:TCfgSegments;
  it:TItem;
  old,lex:String8;
  d:TCfgData;
  json:boolean;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    d:=TCfgData(doc.data);
    it:=FindItem(d,s);
    old:='';
    if (it<>nil) and (it.kind=ckScalar) then old:=it.lexeme;
    if it<>nil then json:=d.files[TargetFile(d,it)].dialect=dlJSON
    else begin
      it:=FindItem(d,Copy(s,0,length(s)-1));
      json:=d.files[TargetFile(d,it)].dialect=dlJSON;
    end;
    lex:=BoolLexeme(value,old,json);
    StoreValue(doc,s,NewScalar(lex,lex));
  finally doc.lock.Leave; end;
end;

procedure TCfgNode.SetStr(const path:String8;const value:String8);
begin
  doc.lock.Enter;
  try
    StoreValue(doc,Extended(path).segs,NewScalar(value,QuoteStr(value)));
  finally doc.lock.Leave; end;
end;

procedure TCfgNode.SetStrs(const path:String8;const values:Strings8);
var
  arr:TItem;
  i:integer;
begin
  arr:=TItem.Create(ckArray);
  arr.oneLine:=true;
  for i:=0 to high(values) do AppendChild(arr,NewScalar(values[i],QuoteStr(values[i])));
  doc.lock.Enter;
  try
    StoreValue(doc,Extended(path).segs,arr);
  finally doc.lock.Leave; end;
end;

function TCfgNode.AddSection(const path:String8):TCfgNode;
var
  s:TCfgSegments;
  parent,item:TItem;
begin
  s:=Extended(path).segs;
  result.doc:=doc;
  result.segs:=s;
  doc.lock.Enter;
  try
    if not PrepareWrite(doc,s,parent,item) then exit;
    if item=nil then begin
      item:=TItem.Create(ckSection);
      item.name:=s[high(s)].name;
      AppendChild(parent,item);
      parent.structDirty:=true;
      doc.modifiedFlag:=true;
    end else
    if item.kind<>ckSection then
      WriteConflict(doc,s,'it is '+KindName(item.kind)+' at '+TCfgData(doc.data).Loc(item));
  finally doc.lock.Leave; end;
end;

procedure TCfgNode.Delete(const path:String8);
var
  s:TCfgSegments;
  it:TItem;
begin
  s:=Extended(path).segs;
  doc.lock.Enter;
  try
    it:=FindItem(TCfgData(doc.data),s);
    if it=nil then exit;
    if it.parent=nil then raise EConfigError.Create('Config: can''t delete the root');
    it.deleted:=true;
    it.parent.structDirty:=true;
    doc.modifiedFlag:=true;
  finally doc.lock.Leave; end;
end;

{ TCfgEnumerator }

function TCfgEnumerator.MoveNext:boolean;
begin
  inc(index);
  result:=index<count;
end;

function TCfgEnumerator.GetCurrent:TCfgNode;
begin
  result:=node.Item(index);
end;

end.
