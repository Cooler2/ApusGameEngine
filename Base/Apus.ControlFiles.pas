// Author: Ivan Polyacov (ivan@apus-software.com)
// Copyright (C) Apus Software, 2002-2003, All rights reserved. https://github.com/Cooler2/ApusGameEngine
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (https://github.com/Cooler2/ApusGameEngine)
{
 There are 2 interfaces there: procedural and class-based. First does not
 aware about multithreading issues. Use it only if you are sure that you
 have no concurrent access to ControlFiles from different threads (or you
 have your own thread-safe shell interface).

 Class interfae is thread-safe, use one class instance per thread.

 IMPORTANT: all data is stored as global for this unit. Multiple instances
 of unit (for example, in plugins or DLL) can lead to dual data representation
 and thus - data loss. Do not use
}
{$H+,R-}
{$I defines.inc}
unit Apus.ControlFiles;
interface
uses Apus.Core;
type
 TFileMode=(fmBinary,   // Binary files
            fmText,     // Textual files
            fmDefault); // As-is

  ctlKeyTypes=(cktNone,
               cktBool,
               cktInteger,
               cktReal,
               cktString,
               cktArray,
               cktSection);

 // Interface class for working with ControlFiles2 unit
 TControlFile=class
  path:String8; // Key names can be relative

  constructor Create(fname:String8;password:String8=''); // Create object and load specified file
  procedure Save; // Save control file
  destructor Destroy; override; // Free object
  // Query methods
  function KeyExists(key:String8):Boolean;
  function GetKeyType(key:String8):ctlKeyTypes;
  // Read methods
  function GetBool(key:String8):boolean; overload;
  function GetInt(key:String8):integer; overload;
  function GetReal(key:String8):double; overload;
  function GetStr(key:String8):String8; overload;
  function GetStrInd(key:String8;index:Integer):String8;
  function GetStrCnt(key:String8):Integer;
  function GetKeys(key:String8):String8;
  function GetBool(key:String8;default:boolean):boolean; overload;
  function GetInt(key:String8;default:integer):integer; overload;
  function GetReal(key:String8;default:double):double; overload;
  function GetStr(key:String8;default:String8):String8; overload;
  // Write methods
  procedure CreateSection(key:String8); // Create section with given path
  procedure SetBool(key:String8;value:boolean);
  procedure SetInt(key:String8;value:integer);
  procedure SetReal(key:String8;value:double);
  procedure SetStr(key:String8;value:String8);
  procedure SetStrInd(key:String8;index:Integer;value:String8);
  procedure SetStrCnt(key:String8;count:integer);
  procedure AddStr(key:String8;newvalue:String8);
  // Delete
  procedure DeleteKey(key:String8);
 private
  handle:integer;
  function GetAbsPath(key:String8):String8;
 end;

// Load specified control file (and all linked files), return its handle
function UseControlFile(filename:String8;password:String8=''):integer;
// Save control file (and all linked files), specified by its handle
procedure SaveControlFile(handle:integer;mode:TFileMode=fmDefault);
// Save all (modified) control files
procedure SaveAllControlFiles;
// Free control file (release it's memory)
procedure FreeControlFile(handle:integer);

// Query functions
function IsKeyExists(key:String8):Boolean;
function ctlGetKeyType(key:String8):ctlKeyTypes;

// Read functions
function ctlGetBool(key:String8):boolean; overload;
function ctlGetBool(key:String8;default:boolean):boolean; overload;
function ctlGetInt(key:String8):integer; overload;
function ctlGetInt(key:String8;default:integer):integer; overload;
function ctlGetReal(key:String8):double; overload;
function ctlGetReal(key:String8;default:double):double; overload;
function ctlGetStr(key:String8):String8; overload;
function ctlGetStr(key:String8;default:String8):String8; overload;
function ctlGetStrInd(key:String8;index:Integer):String8;
function ctlGetStrCnt(key:String8):Integer;
function ctlGetKeys(key:String8):String8; // returns space-separated lisk of keys

// Write functions
procedure ctlCreateSection(key:String8); // Create section with given path
procedure ctlSetBool(key:String8;value:boolean);
procedure ctlSetInt(key:String8;value:integer);
procedure ctlSetReal(key:String8;value:double);
procedure ctlSetStr(key:String8;value:String8);
procedure ctlSetStrInd(key:String8;index:Integer;value:String8);
procedure ctlSetStrCnt(key:String8;count:integer);
procedure ctlAddStr(key:String8;newvalue:String8);

procedure ctlDeleteKey(key:String8);


implementation
 uses SysUtils, StrUtils, Classes, Apus.Containers, Apus.HashMaps, Apus.Crypto, Apus.Threads,
  Apus.Strings, Apus.Conv, Apus.Files;

// Hash key of an item name or path. Every key goes through here, so stored and looked up
// keys agree: String8.ToUpper is Unicode, SysUtils.UpperCase changes only ASCII
function KeyOf(const name:String8):string;
 begin
  result:=string(name.ToUpper);
 end;

type
 // comment
 TCommentLine=class
  line:String8;
 end;

 TInclude=class
  handle:integer;
  include:String8;
  destructor Destroy; override;
 end;

 // Base class for named elements
 TNamedValue=class
  name:String8; // item's name
  fullname:string; // full item name (including path), uppercase (for hash)
  constructor Create; virtual;
  destructor Destroy; override;
  procedure MarkFileAsChanged; virtual;
 end;

 TIntValue=class(TNamedValue)
  private
   v,v2,c:integer;
   function GetIntValue:integer;
   procedure SetIntValue(data:integer);
  public
   constructor Create; override;
   property value:integer read GetIntValue write SetIntValue;
 end;

 TFloatValue=class(TNamedValue)
  private
   v:double;
   c:integer;
   function GetFloatValue:double;
   procedure SetFloatValue(data:double);
  public
   constructor Create; override;
   property value:double read GetFloatValue write SetFloatValue;
 end;

 TBoolValue=class(TNamedValue)
  private
   v,v2,c:boolean;
   function GetBoolValue:boolean;
   procedure SetBoolValue(data:boolean);
  public
   constructor Create; override;
   property value:boolean read GetBoolValue write SetBoolValue;
 end;

 TStringValue=class(TNamedValue)
  private
   st:String8;
   key:integer;
   function GetStrValue:String8;
   procedure SetStrValue(data:String8);
  public
   constructor Create; override;
   property value:String8 read GetStrValue write SetStrValue;
 end;

 TStringListValue=class(TNamedValue)
  private
   strings:array of String8;
   key:integer;
   function GetStrValue(index:integer):String8;
   procedure SetStrValue(index:integer;data:String8);
   function GetCount:integer;
  public
   constructor Create; override;
   procedure Allocate(count:integer);
   property count:integer read GetCount write Allocate;
   property value[index:integer]:String8 read GetStrValue write SetStrValue;
 end;

 TSection=class(TNamedValue)
 end;

 TCtlFile=class(TSection)
  fname:String8;
  modified:boolean;
  curmode:TFileMode;
  handle:integer;
  RefCounter:integer;
  code:cardinal; // encryption code
  constructor Create(filename:String8;filemode:TFileMode);
//  procedure Free;
 end;

 TNamedValueClass=class of TNamedValue;

 TBinaryHeader=packed record
  sign1,sign2:cardinal;
  data:array[0..23] of byte;
 end;

const
 itComment  = 1;
 itInclude  = 2;
 itSection  = 3;
 itBool     = 10;
 itInt      = 11;
 itFloat    = 12;
 itStr      = 13;
 itStrList  = 14;

var
 // All loaded data is stored in a single tree
 // 1st-level elements are files
 items:TGenericTree;
 // Hash for fast access to named tree elements (except files)
 hash:TStrHash;
 lasthandle:integer=0;

 critSect:TLock; // synchronization for multithreaded access
 rndState:cardinal; // state of the own random generator: the global one (RandSeed) is not touched

// Random number in [0..range-1] from the own xorshift generator
function CtlRandom(range:cardinal):cardinal;
begin
 rndState:=rndState xor (rndState shl 13);
 rndState:=rndState xor (rndState shr 17);
 rndState:=rndState xor (rndState shl 5);
 result:=rndState mod range;
end;

// Skip decimal digits starting at position i, return their count
function SkipDigits(const s:String8;var i:integer):integer;
begin
 result:=0;
 while (i<=length(s)) and (s[i] in ['0'..'9']) do begin
  inc(i); inc(result);
 end;
end;

// Decimal integer in the 32-bit range: [sign]digits
function IsInteger(const s:String8):boolean;
var
 i,n:integer;
 v:int64;
begin
 result:=false;
 i:=1;
 if (i<=length(s)) and (s[i] in ['-','+']) then inc(i);
 n:=SkipDigits(s,i);
 if (n=0) or (n>10) or (i<=length(s)) then exit;
 v:=Conv.ToInt(s);
 result:=(v>=Low(integer)) and (v<=High(integer));
end;

// Decimal float: [sign]digits[.digits][e[sign]digits]
function IsFloat(const s:String8):boolean;
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

// Float literal (already validated by IsFloat) to its exact value
function CtlToFloat(const s:String8):double;
var
 code:integer;
begin
 Val(string(s),result,code);
end;

// Where there is no extended (FPC on Win64) FloatToStrF stops at 15 digits; Str(v:width) gives
// more: digits+7 is the width of "-d.dddE+ddd". The result has the form of ffGeneral
function StrFloat(v:double;digits:integer):String8;
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

// Float as a literal that reads back to the same value and is detected as a float again
function CtlFloatToStr(v:double):String8;
var
 fs:TFormatSettings;
 digits:integer;
 exact:boolean;
 s:String8;
begin
 {$IFDEF FPC}fs:=DefaultFormatSettings;{$ELSE}fs:=TFormatSettings.Create;{$ENDIF}
 fs.DecimalSeparator:='.';
 // the shortest of the forms: 15 digits are exact for most values, 17 - for any
 for digits:=15 to 17 do begin
  result:=String8(FloatToStrF(v,ffGeneral,digits,0,fs));
  exact:=IsFloat(result) and (CtlToFloat(result)=v);
  if exact then break;
 end;
 if not exact then
  for digits:=16 to 17 do begin
   s:=StrFloat(v,digits);
   if IsFloat(s) and (CtlToFloat(s)=v) then begin
    result:=s;
    break;
   end;
  end;
 if IsInteger(result) then result:=result+'.0';
end;

constructor TNamedValue.Create;
begin
end;

// Delete a named element
destructor TNamedValue.Destroy;
begin
 // Try to remove it from the hash:
 hash.Remove(fullname);
 inherited;
end;

procedure TNamedValue.MarkFileAsChanged;
var
 fname,iName:string;
 i,p:integer;
 item:TNamedValue;
begin
 p:=pos(':',fullname);
 if p>0 then begin
  fname:=copy(fullname,1,p-1);
  for i:=0 to items.GetChildrenCount-1 do begin
   item:=items.GetChild(i).data;
   iName:=KeyOf(item.name);
   if (item is TCtlFile) and (iName=fname) then begin
    TCtlFile(item).modified:=true;
    exit;
   end;
  end;
 end;
end;

destructor TInclude.Destroy;
begin
 FreeControlFile(handle);
 inherited;
end;

{ TIntValue }
constructor TIntValue.Create;
begin
 c:=CtlRandom($10000000);
 v:=1028349272;
 v2:=v xor $28402850;
end;

function TIntValue.GetIntValue: integer;
begin
 result:=(v xor $93749127) xor c;
end;

procedure TIntValue.SetIntValue(data: integer);
begin
 if v2 xor v<>$28402850 then
  raise EFatalError.Create('CF2: fatal error #1');
 v:=(data xor c) xor $93749127;
 v2:=v xor $28402850;
 MarkFileAsChanged;
end;

{ TFloatValue }
constructor TFloatValue.Create;
begin
 c:=CtlRandom($10000000);
end;

function TFloatValue.GetFloatValue: double;
begin
 result:=v;
 EncryptFast(result,sizeof(result),c);
end;

procedure TFloatValue.SetFloatValue(data: double);
begin
 EncryptFast(data,sizeof(data),c);
 v:=data;
 MarkFileAsChanged;
end;


{ TBoolValue }
constructor TBoolValue.Create;
begin
 c:=CtlRandom(2)=0;
end;

function TBoolValue.GetBoolValue: boolean;
begin
 if c then result:=v else result:=v2;
end;

procedure TBoolValue.SetBoolValue(data: boolean);
begin
 v:=data;
 v2:=data;
 MarkFileAsChanged;
end;

{ TStringValue }
constructor TStringValue.Create;
begin
 key:=CtlRandom(100000000);
end;

function TStringValue.GetStrValue: String8;
begin
 result:=st;
 if length(st)>0 then
  EncryptFast(result[1],length(st),key);
end;

procedure TStringValue.SetStrValue(data: String8);
begin
 if length(data)>0 then
  EncryptFast(data[1],length(data),key);
 st:=data;
 MarkFileAsChanged;
end;

{ TStringListValue }
procedure TStringListValue.Allocate(count: integer);
begin
 SetLength(strings,count);
end;

constructor TStringListValue.Create;
begin
 key:=CtlRandom(100000000);
end;

function TStringListValue.GetCount: integer;
begin
 result:=length(strings);
end;

function TStringListValue.GetStrValue(index: integer): String8;
begin
 result:='';
 if (index<0) or (index>=Length(strings)) then
  raise EWarning.Create('CTL2: String8 index out of bounds');
 result:=strings[index];
 if length(result)<>0 then
  EncryptFast(result[1],length(result),key);
end;

procedure TStringListValue.SetStrValue(index: integer; data: String8);
begin
 if (index<0) or (index>=Length(strings)) then
  raise EWarning.Create('CTL2: String8 index out of bounds');
 if length(data)<>0 then
  EncryptFast(data[1],length(data),key);
 strings[index]:=data;
 MarkFileAsChanged;
end;


{ TCtlFile }
constructor TCtlFile.Create(filename: String8; filemode:TFileMode);
begin
 fname:=filename;
 curmode:=filemode;
 inc(lastHandle);
 handle:=LastHandle;
 RefCounter:=1;
 modified:=false;
end;

{procedure TCtlFile.Free;
begin
 if self<>nil then begin
  dec(RefCounter);
  if refCounter<=0 then inherited;
 end;
end;}

function FileByHandle(handle:integer):TGenericTree;
var
 i:integer;
 item:TObject;
begin
 result:=nil;
 for i:=0 to items.GetChildrenCount-1 do begin
  item:=items.GetChild(i).data;
  if (item is TCtlFile) and ((item as TCtlFile).handle=handle) then begin
   result:=items.GetChild(i);
   exit;
  end;
 end;
end;


{ Main interface }

// A bare include name refers to the including file's directory
function IncludeName(const ctlName,incl:String8):String8;
 begin
  if (pos('\',incl)=0) and (pos('/',incl)=0) then
   result:=Files.GetPath(ctlName)+incl
  else
   result:=incl;
 end;

function UseControlFile;
 var
  code:cardinal;
  i:integer;
  ctl:TCtlFile;

 // Load the specified file, return its handle
 function Load(filename:String8;code:cardinal):integer;
  var
   data:ByteArray;
   h:TBinaryHeader;

   i:integer;
   mode:TFileMode;

  // Load a text-format file into the specified object
  procedure LoadTextual(filename:String8;item:TGenericTree);
   var
    st:String8;
    lines:Strings8;
    ln:integer; // lines read so far

   // Load a section into the given object, path - object path (without trailing slash)
   procedure LoadSection(item:TGenericTree;path:String8);
    var
     st,arg,uArg:String8;
     sa:Strings8;
     comment:TCommentLine;
     incl:TInclude;
     sect:TSection;
     value:TNamedValue;
     i,n:integer;

    begin
     // Process the file line by line
     while ln<length(lines) do begin
      st:=lines[ln].Trim;
      inc(ln);
      // Comment line
      if (length(st)=0) or (st[1] in ['#',';']) then begin
       comment:=TCommentLine.Create;
       comment.line:=st;
       item.AddChild(comment);
       continue;
      end;
      // Split the command and the argument
      arg:='';
      for i:=1 to length(st) do
       if st[i] in [' ',#9] then begin
        arg:=System.Copy(st,i+1,System.Length(st)-i).TrimLeft;
        SetLength(st,i-1);
        break;
       end;

      // Directive
      if st[1]='$' then begin
       // End of section
       if st.ToUpper='$ENDOFSECTION' then break; // end of section
       // Section
       if (System.Length(st)>=8) and (System.Copy(st,1,8).ToUpper='$SECTION') then begin
        sect:=TSection.Create;
        sect.name:=arg;
        if arg='' then
         raise EWarning.Create('CTL2: unnamed section in '+filename+' line: '+Conv.ToStr(ln));
        i:=item.AddChild(sect);
         sect.fullname:=KeyOf(path+'\'+arg);
        hash.Put(sect.fullname,item.GetChild(i));
        LoadSection(item.GetChild(i),sect.fullname);
        continue;
       end;
       // Include command
       if (System.Length(st)>=8) and (System.Copy(st,1,8).ToUpper='$INCLUDE') then begin
        incl:=TInclude.Create;
        incl.include:=arg;
        n:=useControlFile(IncludeName(filename,arg),'');
        incl.handle:=n;
        if n=-1 then raise EWarning.Create('CTL2: include command failed - '+arg);
        item.AddChild(incl);
        continue;
       end;
      end;

      // Otherwise it's a value: check its type
      if arg='' then
       raise EWarning.Create('CTL2: no value for key '+st+' in '+filename+' line: '+Conv.ToStr(ln));
      uArg:=arg.ToUpper;
      if (uArg='ON') or (uArg='OFF') or (uArg='YES') or (uArg='NO') then begin
       // boolean
       value:=TBoolValue.Create;
       (value as TBoolValue).value:=(uArg='ON') or (uArg='YES');
      end else
      if IsInteger(arg) then begin
       // Integer
       value:=TIntValue.Create;
       (value as TIntValue).value:=Conv.ToInt(arg);
      end else
      if IsFloat(arg) then begin
       // Float
       value:=TFloatValue.Create;
       (value as TFloatValue).value:=CtlToFloat(arg);
      end else begin
       // String8 or String8 list
       if arg[1]='(' then begin
        // String8 list
        // Multiline record
        n:=ln; // line where the list starts
        while (arg[length(arg)]<>')') and (ln<length(lines)) do begin
         arg:=arg+lines[ln].Trim;
         inc(ln);
        end;
        if arg[length(arg)]<>')' then
         raise EWarning.Create('CTL2: unterminated list for key '+st+' in '+filename+' line: '+Conv.ToStr(n));
        // Delete '(' and ')'
        delete(arg,1,1);
        SetLength(arg,length(arg)-1);
        sa:=arg.Split(',','"');
        // Create and fill object
        value:=TStringlistValue.Create;
        with value as TStringListValue do begin
         Allocate(Length(sa));
         for i:=0 to length(sa)-1 do
          value[i]:=sa[i].Trim.Unquote;
        end;
       end else begin
        arg:=arg.Unquote;
        value:=TStringValue.Create;
        (value as TStringValue).value:=arg;
       end;
      end;

      // Add the element to the structures
      value.name:=st;
      value.fullname:=KeyOf(path+'\'+st);
      i:=item.AddChild(value);
      hash.Put(value.fullname,item.GetChild(i));
     end;
    end;

   begin // LoadTextual
    // Load the whole file as a section
    SetLength(st,length(data));
    if length(data)>0 then move(data[0],st[1],length(data));
    if UTF8.HasBOM(st) then delete(st,1,3);
    lines:=st.SplitLines;
    // a line break at the end doesn't start one more line
    if (length(lines)>0) and (lines[high(lines)]='') then SetLength(lines,high(lines));
    ln:=0;
    LoadSection(item,Files.GetName(filename).ToUpper+':');
   end;

  procedure LoadBinary(filename:String8;item:TGenericTree;code:cardinal);
   var
    h:TBinaryHeader;
    ms:TMemoryStream;
    mat:TMatrix32;
    p:byte;
    c:cardinal;
    size:integer;

   // Read the section content from a binary file
   procedure ReadSection(item:TGenericTree;path:String8);
    var
     cnt,i,j,n:integer;
     b:byte;
     o:TObject;
     valB:boolean;
     valI:integer;
     valF:double;

    function ReadString:String8;
     var
      w:word;
     begin
      ms.read(w,2);
      SetLength(result,w);
      ms.Read(result[1],w);
     end;

    begin
     ms.Read(cnt,4);
     for i:=1 to cnt do begin
      ms.Read(b,1);
      o:=nil;
      case b of
       itComment:begin
         o:=TCommentLine.Create;
         (o as TCommentLine).line:=ReadString;
         item.AddChild(o);
       end;
       itInclude:begin
         o:=TInclude.Create;
         with o as TInclude do begin
          include:=ReadString;
          handle:=UseControlFile(IncludeName(filename,include),'');
         end;
         item.AddChild(o);
       end;
       itSection:begin
         o:=TSection.Create;
         (o as TSection).name:=ReadString;
         n:=item.AddChild(o);
         ReadSection(item.GetChild(n),path+'\'+(o as TSection).name.ToUpper);
       end;
       itBool:begin
        o:=TBoolValue.Create;
        (o as TBoolValue).name:=ReadString;
        ms.Read(valB,1);
        (o as TBoolValue).value:=valB;
        item.AddChild(o);
       end;
       itInt:begin
        o:=TIntValue.Create;
        (o as TIntValue).name:=ReadString;
        ms.Read(valI,4);
        (o as TIntValue).value:=valI;
        item.AddChild(o);
       end;
       itFloat:begin
        o:=TFloatValue.Create;
        (o as TFloatValue).name:=ReadString;
        ms.Read(valF,8);
        (o as TFloatValue).value:=valF;
        item.AddChild(o);
       end;
       itStr:begin
        o:=TStringValue.Create;
        (o as TStringValue).name:=ReadString;
        (o as TStringValue).value:=ReadString;
        item.AddChild(o);
       end;
       itStrList:begin
        o:=TStringListValue.Create;
        (o as TStringListValue).name:=ReadString;
        ms.Read(n,4);
        (o as TStringListValue).Allocate(n);
        for j:=0 to n-1 do
         (o as TStringListValue).value[j]:=ReadString;
        item.AddChild(o);
       end;
       else
        raise EWarning.Create('Unknown chunk type - new version?');
      end;
      // set item's full name and add to hash
      if (o<>nil) and (o is TNamedValue) then with o as TNamedValue do begin
        fullname:=KeyOf(path+'\'+name);
        hash.Put(fullname,item.GetChild(i-1));
      end;
     end;
    end;

   begin
    if length(data)<sizeof(h) then
     raise EError.Create('Invalid file header');
    move(data[0],h,sizeof(h));
    p:=(h.sign2 xor h.sign1)-28301740;
    if p>=20 then
     raise EError.Create('Invalid file header');
    move(h.data[p],c,4);
    c:=c+code; // Actual encryption code
    // Generate matrix for decryption
    GenMatrix32(mat,Conv.ToStr(c));
    mat:=InvertMatrix32(mat);
    // Read rest of the file and decrypt it
    size:=length(data)-sizeof(h);
    ms:=TMemoryStream.Create;
    ms.SetSize(size);
    if size>0 then move(data[sizeof(h)],ms.memory^,size);
    Decrypt32A(ms.memory^,size,mat);

    ReadSection(item,Files.GetName(filename).ToUpper+':');
    ms.Destroy;
   end;

  begin // Load
   result:=-1;
   // Check the file format
   data:=Files.LoadAsBytes(filename);
   mode:=fmText;
   if length(data)>=8 then begin
    move(data[0],h,8);
    if (h.sign1<=100000000) and (abs((h.sign2 xor h.sign1)-28301740)<=100) then mode:=fmBinary;
   end;

   // Create the object and add it to the structures
   ctl:=TCtlFile.Create(filename,mode);
   ctl.fname:=filename;
   ctl.name:=Files.GetName(filename);
   ctl.fullname:=KeyOf(ctl.name+':');
   i:=items.AddChild(ctl);
   hash.Put(ctl.fullname,items.GetChild(i));
   ctl.curmode:=mode;
   ctl.code:=code;

   try
    if ctl.curmode=fmText then
      LoadTextual(filename,items.GetChild(i))
    else
      LoadBinary(filename,items.GetChild(i),code);
   except
    items.GetChild(i).Free; // a partially loaded file must not be returned by the next UseControlFile
    raise;
   end;

   result:=ctl.handle;
  end;

begin
 critSect.Enter;
 try
  try
   // Was the file already loaded? The key is the VFS name: the file doesn't have to exist on disk
   filename:=Files.FixName(filename);
   for i:=0 to items.GetChildrenCount-1 do begin
    ctl:=items.GetChild(i).data;
    if ctl.fname=filename then begin
     result:=ctl.handle;
     inc(ctl.RefCounter);
     exit;
    end;
    // keys are addressed by the bare file name, so it must be unique
    if KeyOf(ctl.name)=KeyOf(Files.GetName(filename)) then
     raise EError.Create('a file with this name is already loaded: '+ctl.fname);
   end;
   if password<>'' then
    code:=CheckSumSlow(password[1],length(password),1)
   else code:=0;
   result:=Load(filename,code);
  except
   on e:Exception do
    raise EError.Create('CTL2: Can''t load control file: '+filename+', exception: '+e.Message);
  end;
 finally critSect.Leave; end;
end;

procedure SaveControlFile;
var
 name:String8;
 item:TGenericTree;
 ctl:TCtlFile;

 procedure SaveTextual(item:TGenericTree;filename:String8);
  var
   content:String8;

  procedure WriteLine(const line:String8);
   begin
    content:=content+line+sLineBreak;
   end;

  // A value of the textual format can't contain a line break
  procedure CheckTextual(const value:String8;o:TNamedValue);
   begin
    if (Pos(#10,value)>0) or (Pos(#13,value)>0) then
     raise EWarning.Create('line break in the value of '+o.name);
   end;

  // Save the section content to a file (with the specified indent)
  procedure SaveSection(item:TGenericTree;indent:integer);
   var
    i,j:integer;
    o:TObject;
    pad,st:String8;
   begin
    for i:=0 to item.GetChildrenCount-1 do begin
     o:=item.GetChild(i).data;
     SetLength(pad,indent);
     for j:=1 to indent do
      pad[j]:=' ';
     // Save comment line
     if o is TCommentLine then begin
      WriteLine(pad+(o as TCommentLine).line);
      continue;
     end;
     // Directives
     if o is TInclude then begin
      WriteLine(pad+'$Include '+(o as TInclude).include);
      SaveControlFile((o as TInclude).handle);
      continue;
     end;
     if o is TSection then begin
      WriteLine(pad+'$Section '+(o as TSection).name);
      SaveSection(item.GetChild(i),indent+2);
      WriteLine(pad+'$EndOfSection');
      continue;
     end;
     // Format String8 for named value
     // All other cases must be handled above!
     if o is TNamedValue then begin
      st:=pad+(o as TNamedValue).name+'    ';
      while length(st) mod 8<>0 do st:=st+' ';
     end;
     // Save boolean value
     if o is TBoolValue then begin
      if (o as TBoolValue).Value then st:=st+'ON'
       else st:=st+'OFF';
      WriteLine(st);
      continue;
     end;
     // Save integer value
     if o is TIntValue then begin
      st:=st+Conv.ToStr((o as TIntValue).Value);
      WriteLine(st);
      continue;
     end;
     // Save float value
     if o is TFloatValue then begin
      st:=st+CtlFloatToStr((o as TFloatValue).Value);
      WriteLine(st);
      continue;
     end;
     // Save String8 value
     if o is TStringValue then begin
      //st:=st+QuoteStr((o as TStringValue).value);
      // Force quoting to avoid a conflict with numbers
      CheckTextual((o as TStringValue).value,o as TNamedValue);
      st:=st+'"'+(o as TStringValue).value+'"';
      WriteLine(st);
      continue;
     end;
     // Save String8 array value
     if o is TStringListValue then with o as TStringListValue do begin
      st:=st+'(';
      if count=0 then st:=st+')';
      j:=length(st);
      setLength(pad,j);
      for j:=1 to length(pad) do pad[j]:=' ';
      for j:=1 to count do begin
       while length(st) mod 8<>1 do st:=st+' ';
       CheckTextual(value[j-1],o as TNamedValue);
       st:=st+value[j-1].Quote;
       if j<count then st:=st+',' else st:=st+')';
       if length(st)>75 then begin
        WriteLine(st);
        st:=pad;
       end;
      end;
      // if an unwritten line remains
      if (length(st)<=75) and (st<>pad) then WriteLine(st);
      continue;
     end;
    end;
   end;

  begin
   content:='';
   SaveSection(item,0);
   Files.Save(filename,content,false);
  end;

 procedure SaveBinary(item:TGenericTree;filename:String8);
  var
   data:ByteArray;
   h:TBinaryHeader;
   p:byte;
   i:integer;
   code:cardinal;
   ms:TMemoryStream;
   o:TObject;
   mat:TMatrix32;
  // Save section to binary stream
  procedure SaveSection(item:TGenericTree);
    var
     b:byte;
     i,j,n:integer;
     o:TObject;
     valB:boolean;
     valI:integer;
     valF:double;
    procedure WriteString(st:String8);
     var
      w:word;
     begin
      w:=length(st);
      ms.Write(w,2);
      ms.Write(st[1],w);
     end;
    begin
     n:=item.GetChildrenCount;
     ms.Write(n,4);
     for i:=0 to n-1 do begin
      o:=item.GetChild(i).data;
      // Save comment line
      if o is TCommentLine then begin
       b:=itComment;
       ms.Write(b,1);
       WriteString((o as TCommentLine).line);
       continue;
      end;
      // Directives
      if o is TInclude then begin
       b:=itInclude;
       ms.Write(b,1);
       WriteString((o as TInclude).include);
       SaveControlFile((o as TInclude).handle);
       continue;
      end;
      if o is TSection then begin
       b:=itSection;
       ms.Write(b,1);
       WriteString((o as TSection).name);
       SaveSection(item.GetChild(i));
       continue;
      end;
      // Save boolean value
      if o is TBoolValue then begin
       b:=itBool;
       ms.Write(b,1);
       WriteString((o as TBoolValue).name);
       valB:=(o as TBoolValue).value;
       ms.Write(valB,1);
       continue;
      end;
      // Save integer value
      if o is TIntValue then begin
       b:=itInt;
       ms.Write(b,1);
       WriteString((o as TIntValue).name);
       valI:=(o as TIntValue).value;
       ms.Write(valI,4);
       continue;
      end;
      // Save float value
      if o is TFloatValue then begin
       b:=itFloat;
       ms.Write(b,1);
       WriteString((o as TFloatValue).name);
       valF:=(o as TFloatValue).value;
       ms.Write(valF,8);
       continue;
      end;
      // Save String8 value
      if o is TStringValue then begin
       b:=itStr;
       ms.Write(b,1);
       WriteString((o as TStringValue).name);
       WriteString((o as TStringValue).value);
       continue;
      end;
      // Save String8 array value
      if o is TStringListValue then with o as TStringListValue do begin
       b:=itStrList;
       ms.Write(b,1);
       WriteString((o as TStringListValue).name);
       n:=count;
       ms.Write(n,4);
       for j:=0 to n-1 do
        WriteString(value[j]);
       continue;
      end;
     end;
    end;
  begin
   p:=CtlRandom(20);
   h.sign1:=CtlRandom(100000000);
   h.sign2:=h.sign1 xor (28301740+p);
   code:=CtlRandom(1000000);
   for i:=0 to 23 do h.data[i]:=CtlRandom(256);
   move(code,h.data[p],4);
   o:=item.data;
   inc(code,(o as TCtlFile).code); // Actual encryption code
   ms:=TMemoryStream.Create;
   GenMatrix32(mat,Conv.ToStr(code));
   SaveSection(item);
   Encrypt32A(ms.memory^,ms.size,mat);
   SetLength(data,sizeof(h)+ms.size);
   move(h,data[0],sizeof(h));
   if ms.size>0 then move(ms.memory^,data[sizeof(h)],ms.size);
   ms.Destroy;
   Files.Save(filename,data);
  end;

begin
 name:='unknown';
 critSect.Enter;
 try
  try
   item:=FileByHandle(handle);
   if item=nil then
    raise EWarning.Create('invalid handle passed');
   ctl:=item.data;
   name:=ctl.fname;
   if mode=fmDefault then mode:=ctl.CurMode;
   if mode=fmText then SaveTextual(item,ctl.fname)
    else SaveBinary(item,ctl.fname);
   ctl.modified:=false;
  except
   on e:Exception do
    raise EWarning.Create('CTL2: Can''t save control file: '+name+', exception: '+e.Message);
  end;
 finally critSect.Leave; end;
end;

procedure SaveAllControlFiles;
var
 i:integer;
 item:TNamedValue;
begin
 critSect.Enter;
 try
 for i:=0 to items.GetChildrenCount-1 do begin
  item:=items.GetChild(i).data;
  if (item is TCtlFile) and ((item as TCtlFile).modified) then
   SaveControlFile(TCtlFile(item).handle);
 end;
 finally critSect.Leave; end;
end;

procedure FreeControlFile;
var
 ctl:TCtlFile;
 item:TGenericTree;
begin
 critSect.Enter;
 try
 item:=FileByHandle(handle);
 if item<>nil then begin
  ctl:=item.data;
  dec(ctl.RefCounter);
  if ctl.RefCounter<=0 then
   item.Free;
 end;
 finally critSect.Leave; end;
end;

function IsKeyExists(key:String8):Boolean;
 begin
  result:=(hash.Get(KeyOf(key))<>nil);
 end;

function FindItem(key:String8):TObject;
 var
  item:TGenericTree;
 begin
  result:=nil;
  item:=hash.Get(KeyOf(key));
  if item=nil then exit;
  result:=item.data;
 end;

function ctlGetKeyType(key:String8):ctlKeyTypes;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  result:=cktNone;
  o:=FindItem(key);
  if o=nil then exit;
  if o is TIntValue then result:=cktInteger;
  if o is TBoolValue then result:=cktBool;
  if o is TFloatValue then result:=cktReal;
  if o is TStringValue then result:=cktString;
  if o is TStringListValue then result:=cktArray;
  if o is TSection then result:=cktSection;
  finally critSect.Leave; end;
 end;

const
 MessageKeyIncorrect='CTL2: key does not exists or has inproper type - ';
 MessageWrongType='CTL2: operation requires another type of key - ';
 MessageCannotCreateKey='CTL2: cannot create key - ';

function ctlGetBool(key:String8):boolean;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TBoolValue) then
   result:=(o as TBoolValue).value
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetInt(key:String8):integer;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TIntValue) then
   result:=(o as TIntValue).value
  else
  if (o<>nil) and (o is TStringValue) then
   result:=StrToIntDef((o as TStringValue).value,0)
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetReal(key:String8):double;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TFloatValue) then
   result:=(o as TFloatValue).value
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetStr(key:String8):String8;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and ((o is TStringValue) or (o is TIntValue)) then begin
   if (o is TStringValue) then result:=(o as TStringValue).value else
   if (o is TIntValue) then result:=Conv.ToStr((o as TIntValue).value);
  end else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetBool(key:String8;default:boolean):boolean;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TBoolValue) then
   result:=(o as TBoolValue).value
  else
   result:=default;
  finally critSect.Leave; end;
 end;

function ctlGetInt(key:String8;default:integer):integer;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TIntValue) then
   result:=(o as TIntValue).value
  else
   result:=default;
  finally critSect.Leave; end;
 end;

function ctlGetReal(key:String8;default:double):double;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TFloatValue) then
   result:=(o as TFloatValue).value
  else
   result:=default;
  finally critSect.Leave; end;
 end;

function ctlGetStr(key:String8;default:String8):String8;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TStringValue) then
   result:=(o as TStringValue).value
  else
   result:=default;
  finally critSect.Leave; end;
 end;

function ctlGetStrInd(key:String8;index:Integer):String8;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TStringListValue) then
   result:=(o as TStringListValue).value[index]
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetStrCnt(key:String8):Integer;
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TStringListValue) then
   result:=(o as TStringListValue).count
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
  finally critSect.Leave; end;
 end;

function ctlGetKeys(key:String8):String8;
 var
  item:TGenericTree;
  o:TObject;
  i:integer;
 begin
  critSect.Enter;
  try
  item:=hash.Get(KeyOf(key));
  if item=nil then
   raise EWarning.Create(MessageKeyIncorrect+key);
  o:=item.data;
  if not (o is TSection) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  result:='';
  for i:=0 to item.GetChildrenCount-1 do begin
   o:=item.GetChild(i).data;
   if o is TNamedValue then begin
    if result<>'' then result:=result+' ';
    result:=result+(o as TNamedValue).name;
   end;
  end;
  finally critSect.Leave; end;
 end;

// Write functions
procedure ctlCreateSection(key:String8);
 var
  o:TObject;
  s,curS:TSection;
  f:TCtlFile;
  item:TGenericTree;
  i:integer;
  fname,sname:String8;
  fl:boolean;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o<>nil) and (o is TSection) then exit; // Section already exists
  if (o<>nil) and not (o is TSection) then
   raise EWarning.Create('CTL2: Cannot create section - key already exists: '+key);
  fname:=copy(key,1,pos(':',key)-1); // filename part of path
  delete(key,1,pos(':',key)+1);
  key:=key+'\';
  // Need to find the file in which to create the section
  item:=nil;
  for i:=0 to items.GetChildrenCount-1 do begin
   f:=items.GetChild(i).data;
   if KeyOf(f.name)=KeyOf(fname) then item:=items.GetChild(i);
  end;
  if item=nil then
   raise EWarning.Create('CTL2: Cannot create section - file '+fname+' was not loaded.');
  if key='' then exit;
  repeat
   sname:=copy(key,1,pos('\',key)-1);
   delete(key,1,pos('\',key));
   fl:=false;
   for i:=0 to item.GetChildrenCount-1 do begin
    o:=item.GetChild(i).data;
    if (o is TSection) and
       (KeyOf((o as TSection).name)=KeyOf(sname)) then begin
     item:=item.GetChild(i);
     fl:=true;
     break;
    end;
   end;
   if not fl then begin // Subsection not found => create it
    curS:=item.data;
    s:=TSection.Create;
    s.name:=sname;
    s.fullname:=curS.fullname+'\'+KeyOf(sname);
    i:=item.AddChild(s);
    item:=item.GetChild(i);
    hash.Put(s.fullname,item);
   end
  until length(key)=0;
  finally critSect.Leave; end;
 end;

// Creates an element of the given type, returns the object (but not the tree leaf!)
function CreateKey(key:String8;KeyType:TNamedValueClass):TObject;
 var
  i,n:integer;
  s:String8;
  o:TNamedValue;
  item:TGenericTree;
 begin
  critSect.Enter;
  try
  result:=nil;
  for i:=length(key) downto 1 do
   if key[i]='\' then begin
    s:=copy(key,1,i-1);
    ctlCreateSection(s);
    item:=hash.Get(KeyOf(s));
    o:=item.data;
    if o is TCtlFile then TCtlFile(o).modified:=true;
    o:=KeyType.Create;
    o.name:=Copy(key,i+1,length(key)-i);
    o.fullname:=KeyOf(key);
    n:=item.AddChild(o);
    hash.Put(o.fullname,item.GetChild(n));
    result:=o;
    exit;
   end;
  finally critSect.Leave; end;
 end;

procedure ctlSetBool(key:String8;value:boolean);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TBoolValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TBoolValue then
   (o as TBoolValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
  finally critSect.Leave; end;
 end;

procedure ctlSetInt(key:String8;value:integer);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TIntValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TIntValue then
   (o as TIntValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
  finally critSect.Leave; end;
 end;

procedure ctlSetReal(key:String8;value:double);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TFloatValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TFloatValue then
   (o as TFloatValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
  finally critSect.Leave; end;
 end;

procedure ctlSetStr(key:String8;value:String8);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TStringValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TStringValue then
   (o as TStringValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
  finally critSect.Leave; end;
 end;

procedure ctlSetStrInd(key:String8;index:Integer;value:String8);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o=nil) or not (o is TStringListValue) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  (o as TStringListValue).value[index]:=value;
  finally critSect.Leave; end;
 end;

procedure ctlSetStrCnt(key:String8;count:integer);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TStringListValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if not (o is TStringListValue) then
   raise EWarning.Create(MessageWrongType+key);
  (o as TStringListValue).Allocate(count);
  finally critSect.Leave; end;
 end;

procedure ctlAddStr(key:String8;newvalue:String8);
 var
  o:TObject;
 begin
  critSect.Enter;
  try
  o:=FindItem(key);
  if (o=nil) or not (o is TStringListValue) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  with o as TStringListValue do begin
   Allocate(count+1);
   value[count-1]:=newvalue;
  end;
  finally critSect.Leave; end;
 end;

procedure ctlDeleteKey(key:String8);
 var
  item:TGenericTree;
 begin
  critSect.Enter;
  try
  item:=hash.Get(KeyOf(key));
  if item=nil then
   raise EWarning.Create(MessageKeyIncorrect+key);
  if item.GetParent=nil then
   raise EWarning.Create('Can''t delete root section!');
  item.Free;
  finally critSect.Leave; end;
 end;

{ TControlFile }

procedure TControlFile.AddStr(key, newvalue: String8);
begin
 ctlAddStr(GetAbsPath(key),newvalue);
end;

constructor TControlFile.Create(fname:String8;password:String8='');
begin
 handle:=-1;
 handle:=UseControlFile(fname,password);
 path:=Files.GetName(fname)+':';
end;

procedure TControlFile.CreateSection(key: String8);
begin
 ctlCreateSection(GetAbsPath(key));
end;

destructor TControlFile.Destroy;
begin
 if handle=-1 then exit;
//  SaveControlFile(handle);
 FreeControlFile(handle);
end;

function TControlFile.GetBool(key: String8): boolean;
begin
 result:=ctlGetBool(GetAbsPath(key));
end;

function TControlFile.GetInt(key: String8): integer;
begin
 result:=ctlGetInt(GetAbsPath(key));
end;

function TControlFile.GetKeyType(key: String8): ctlKeyTypes;
begin
 result:=ctlGetKeyType(GetAbsPath(key));
end;

function TControlFile.GetReal(key: String8): double;
begin
 result:=ctlGetReal(GetAbsPath(key));
end;

function TControlFile.GetStr(key: String8): String8;
begin
 result:=ctlGetStr(GetAbsPath(key));
end;

function TControlFile.GetStrCnt(key: String8): Integer;
begin
 result:=ctlGetStrCnt(GetAbsPath(key));
end;

function TControlFile.GetStrInd(key: String8; index: Integer): String8;
begin
 result:=ctlGetStrInd(GetAbsPath(key),index);
end;

function TControlFile.KeyExists(key: String8): Boolean;
begin
 result:=IsKeyExists(GetAbsPath(key));
end;

function TControlFile.GetAbsPath(key:String8):String8;
var
 i:integer;
begin
 if pos(':',key)>0 then begin
  result:=key; exit;
 end;
 result:=path;
 if (result<>'') and (result[length(result)]='\') then delete(result,length(result),1);
 while pos('..\',key)=1 do begin
  delete(key,1,3);
  for i:=length(result) downto 1 do
   if result[i]='\' then begin
    delete(result,i,length(result)-i+1);
    break;
   end;
 end;
 result:=result+'\'+key;
end;

procedure TControlFile.Save;
begin
 SaveControlFile(handle);
end;

procedure TControlFile.SetBool(key: String8; value: boolean);
begin
 ctlSetBool(GetAbsPath(key),value);
end;

procedure TControlFile.SetInt(key: String8; value: integer);
begin
 ctlSetInt(GetAbsPath(key),value);
end;

procedure TControlFile.SetReal(key: String8; value: double);
begin
 ctlSetReal(GetAbsPath(key),value);
end;

procedure TControlFile.SetStr(key, value: String8);
begin
 ctlSetStr(GetAbsPath(key),value);
end;

procedure TControlFile.SetStrCnt(key: String8; count: integer);
begin
 ctlSetStrCnt(GetAbsPath(key),count);
end;

procedure TControlFile.SetStrInd(key: String8; index: Integer;
  value: String8);
begin
 ctlSetStrInd(GetAbsPath(key),index,value);
end;

function TControlFile.GetKeys(key: String8): String8;
begin
 result:=ctlGetKeys(GetAbsPath(key));
end;

procedure TControlFile.DeleteKey(key: String8);
begin
 ctlDeleteKey(GetAbsPath(key));
end;

function TControlFile.GetBool(key: String8; default: boolean): boolean;
begin
 result:=CtlGetBool(GetAbsPath(key),default);
end;

function TControlFile.GetInt(key: String8; default: integer): integer;
begin
 result:=CtlGetInt(GetAbsPath(key),default);
end;

function TControlFile.GetReal(key: String8; default: double): double;
begin
 result:=CtlGetReal(GetAbsPath(key),default);
end;

function TControlFile.GetStr(key, default: String8): String8;
begin
 result:=CtlGetStr(GetAbsPath(key),default);
end;

initialization
 items:=TGenericTree.Create(true,true);
 hash:=TStrHash.Create;
 critSect.Init('CtlFiles2',300);
 rndState:=cardinal(CoreTime.Ticks) xor $9E3779B9;
 if rndState=0 then rndState:=1;

finalization
// There is no point in deleting own objects - the program is terminating anyway
// and running into bugs is undesirable...
 critSect.Cleanup;
end.
