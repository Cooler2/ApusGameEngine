// Author: Ivan Polyacov (ivan@games4win.com)
// Copyright (C) Apus Software, 2002-2003, All rights reserved. www.apus-software.com
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
unit ControlFiles2;
interface
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
  path:string; // Key names can be relative

  constructor Create(fname,password:string); // Create object and load specified file
  procedure Save; // Save control file
  destructor Destroy; override; // Free object
  // Query methods
  function KeyExists(key:String):Boolean;
  function GetKeyType(key:String):ctlKeyTypes;
  // Read methods
  function GetBool(key:string):boolean; overload;
  function GetInt(key:string):integer; overload;
  function GetReal(key:string):double; overload;
  function GetStr(key:string):string; overload;
  function GetStrInd(key:String;index:Integer):String;
  function GetStrCnt(key:String):Integer;
  function GetKeys(key:string):String;
  function GetBool(key:string;default:boolean):boolean; overload;
  function GetInt(key:string;default:integer):integer; overload;
  function GetReal(key:string;default:double):double; overload;
  function GetStr(key:string;default:string):string; overload;
  // Write methods
  procedure CreateSection(key:string); // Create section with given path
  procedure SetBool(key:string;value:boolean);
  procedure SetInt(key:string;value:integer);
  procedure SetReal(key:string;value:double);
  procedure SetStr(key:string;value:string);
  procedure SetStrInd(key:String;index:Integer;value:string);
  procedure SetStrCnt(key:String;count:integer);
  procedure AddStr(key:String;newvalue:string);
  // Delete
  procedure DeleteKey(key:string);
 private
  handle:integer;                                 
  function GetAbsPath(key:string):string;
 end;

// Load specified control file (and all linked files), return its handle
function UseControlFile(filename:string;password:string=''):integer;
// Save control file (and all linked files), specified by its handle
procedure SaveControlFile(handle:integer;mode:TFileMode=fmDefault);
// Save all (modified) control files
procedure SaveAllControlFiles;
// Free control file (release it's memory)
procedure FreeControlFile(handle:integer);

// Query functions
function IsKeyExists(key:String):Boolean;
function ctlGetKeyType(key:String):ctlKeyTypes;

// Read functions
function ctlGetBool(key:string):boolean; overload;
function ctlGetBool(key:string;default:boolean):boolean; overload;
function ctlGetInt(key:string):integer; overload;
function ctlGetInt(key:string;default:integer):integer; overload;
function ctlGetReal(key:string):double; overload;
function ctlGetReal(key:string;default:double):double; overload;
function ctlGetStr(key:string):string; overload;
function ctlGetStr(key:string;default:string):string; overload;
function ctlGetStrInd(key:String;index:Integer):String;
function ctlGetStrCnt(key:String):Integer;
function ctlGetKeys(key:string):String;

// Write functions
procedure ctlCreateSection(key:string); // Create section with given path
procedure ctlSetBool(key:string;value:boolean);
procedure ctlSetInt(key:string;value:integer);
procedure ctlSetReal(key:string;value:double);
procedure ctlSetStr(key:string;value:string);
procedure ctlSetStrInd(key:String;index:Integer;value:string);
procedure ctlSetStrCnt(key:String;count:integer);
procedure ctlAddStr(key:String;newvalue:string);

procedure ctlDeleteKey(key:string);


implementation
 uses CrossPlatform,MyServis,classes,SysUtils,StrUtils,structs,crypto;

type
 // комментарий
 TCommentLine=class
  line:string;
 end;

 TInclude=class
  handle:integer;
  include:string;
  destructor Destroy; override;
 end;

 // Базовый класс для именованых элементов
 TNamedValue=class
  name:string; // item's name
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
   st:string;
   key:integer;
   function GetStrValue:string;
   procedure SetStrValue(data:string);
  public
   constructor Create; override;
   property value:string read GetStrValue write SetStrValue;
 end;

 TStringListValue=class(TNamedValue)
  private
   strings:array of string;
   key:integer;
   function GetStrValue(index:integer):string;
   procedure SetStrValue(index:integer;data:string);
   function GetCount:integer;
  public
   constructor Create; override;
   procedure Allocate(count:integer);
   property count:integer read GetCount write Allocate;
   property value[index:integer]:string read GetStrValue write SetStrValue;
 end;

 TSection=class(TNamedValue)
 end;

 TCtlFile=class(TSection)
  fname:string;
  modified:boolean;
  curmode:TFileMode;
  handle:integer;
  RefCounter:integer;
  code:cardinal; // encryption code
  constructor Create(filename:string;filemode:TFileMode);
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
 // Все загруженные данные хранятся в одном дереве
 // Элементы 1-го уровня - файлы
 items:TGenericTree;
 // Хэш для быстрого доступа к именованным элементам дерева (кроме файлов)
 hash:TStrHash;
 lasthandle:integer=0;

 CritSect:TMyCriticalSection; // синхронизация для многопоточного доступа

//----------------- Copypasted from QStrings.pas since it can't be compiled by FPC
type
  PLong = ^LongWord;

{ Функции для работы с символьной записью чисел. }
function Q_StrToInt64(const S: string; var V: Int64): Boolean;
type
  PArr64 = ^TArr64;
  TArr64 = array[0..7] of Byte;
var
  P: PChar;
  C: LongWord;
  Sign: LongBool;
begin
  V := 0;
  P := Pointer(S);
  if not Assigned(P) then
  begin
    Result := False;
    Exit;
  end;
  while P^ = ' ' do
    Inc(P);
  if P^ = '-' then
  begin
    Sign := True;
    Inc(P);
  end else
  begin
    Sign := False;
    if P^ = '+' then
      Inc(P);
  end;
  if P^ <> '$' then
  begin
    if P^ = #0 then
    begin
      Result := False;
      Exit;
    end;
    repeat
      C := Byte(P^);
      if Char(C) in ['0'..'9'] then
        Dec(C,48)
      else
        Break;
      if (V<0) or (V>$CCCCCCCCCCCCCCC) then
      begin
        Result := False;
        Exit;
      end;
      V := V*10 + C;
      Inc(P);
    until False;
    if V < 0 then
    begin
      Result := (V=$8000000000000000) and Sign and (C=0);
      Exit;
    end;
  end else
  begin
    Inc(P);
    repeat
      C := Byte(P^);
      case Char(C) of
      '0'..'9': Dec(C,48);
      'A'..'F': Dec(C,55);
      'a'..'f': Dec(C,87);
      else
        Break;
      end;
      if PArr64(@V)^[7] >= $10 then
      begin
        Result := False;
        Exit;
      end;
      V := V shl 4;
      PLong(@V)^ := PLong(@V)^ or C;
      Inc(P);
    until False;
    if Sign and (V=$8000000000000000) then
    begin
      Result := False;
      Exit;
    end;
  end;
  if Sign then
    V := -V;
  Result := C=0;
end;

function Q_BetweenInt64(const S: string; LowBound, HighBound: Int64): Boolean;
var
  N: Int64;
begin
  Result := Q_StrToInt64(S,N) and (N>=LowBound) and (N<=HighBound);
end;

function Q_IsInteger(const S: string): Boolean;
var
  L,I: Integer;
  P: PChar;
  C: Char;
begin
  P := Pointer(S);
  L := Length(S);
  Result := False;
  while (L>0) and (P^=' ') do
  begin
    Dec(L);
    Inc(P);
  end;
  if L > 0 then
  begin
    C := P^;
    Inc(P);
    if C in ['-','+'] then
    begin
      C := P^;
      Dec(L);
      Inc(P);
      if L = 0 then
        Exit;
    end;
    if ((L<10) and (C in ['0'..'9'])) or ((L=10) and (C in ['0'..'1'])) then
    begin
      for I := 1 to L-1 do
      begin
        if not (P^ in ['0'..'9']) then
          Exit;
        Inc(P);
      end;
      Result := True;
    end
    else if (L=10) and (C='2') then
      Result := Q_BetweenInt64(S,-2147483647-1,2147483647);
  end;
end;
function Q_IsFloat(const S: string): Boolean;
var
  L: Integer;
  P: PChar;
begin
  P := Pointer(S);
  L := Length(S);
  Result := False;
  while (L>0) and (P^=' ') do
  begin
    Dec(L);
    Inc(P);
  end;
  if L > 0 then
  begin
    if P^ in ['-','+'] then
    begin
      Dec(L);
      Inc(P);
      if L = 0 then
        Exit;
    end;
    if not (P^ in ['0'..'9']) then
      Exit;
    repeat
      Dec(L);
      Inc(P);
    until (L=0) or not (P^ in ['0'..'9']);
    if L = 0 then
    begin
      Result := True;
      Exit;
    end;
    if P^ = GetDecimalSeparator then
    begin
      Dec(L);
      Inc(P);
      if (L=0) or not (P^ in ['0'..'9']) then
        Exit;
      repeat
        Dec(L);
        Inc(P);
      until (L=0) or not (P^ in ['0'..'9']);
      if L = 0 then
      begin
        Result := True;
        Exit;
      end;
    end;
    if P^ in ['E','e'] then
    begin
      Dec(L);
      Inc(P);
      if (L<>0) and (P^ in ['-','+']) then
      begin
        Dec(L);
        Inc(P);
      end;
      if (L=0) or not (P^ in ['0'..'9']) then
        Exit;
      repeat
        Dec(L);
        Inc(P);
      until (L=0) or not (P^ in ['0'..'9']);
      Result := L = 0;
    end;
  end;
end;

// ------------------------------- End of QStrings

constructor TNamedValue.Create;
begin
end;

// Удаление именованного эл-та
destructor TNamedValue.Destroy;
begin
 // Попаытаемся удалить из хэша:
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
   iName:=Uppercase(item.name);    
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
 c:=random($10000000);
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
 c:=random($10000000);
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
 c:=random(2)=0;
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
 key:=random(100000000);
end;

function TStringValue.GetStrValue: string;
begin
 result:=st;
 if length(st)>0 then
  EncryptFast(result[1],length(st),key);
end;

procedure TStringValue.SetStrValue(data: string);
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
 key:=random(100000000);
end;

function TStringListValue.GetCount: integer;
begin
 result:=length(strings);
end;

function TStringListValue.GetStrValue(index: integer): string;
begin
 result:='';
 if (index<0) or (index>=Length(strings)) then
  raise EWarning.Create('CTL2: string index out of bounds');
 result:=strings[index];
 if length(result)<>0 then
  EncryptFast(result[1],length(result),key);
end;

procedure TStringListValue.SetStrValue(index: integer; data: string);
begin
 if (index<0) or (index>=Length(strings)) then
  raise EWarning.Create('CTL2: string index out of bounds');
 if length(data)<>0 then
  EncryptFast(data[1],length(data),key);
 strings[index]:=data;
 MarkFileAsChanged;
end;


{ TCtlFile }
constructor TCtlFile.Create(filename: string; filemode:TFileMode);
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

function UseControlFile;
 var
  code:cardinal;
  i:integer;             
  ctl:TCtlFile;

 // Загрузить указанный файл, вернуть его handle
 function Load(filename:string;code:cardinal):integer;
  var
   f:file;
   h:TBinaryHeader;

   i:integer;
   mode:TFileMode;

  // Загрузить файл текстового формата в указанный объект
  procedure LoadTextual(filename:string;item:TGenericTree);
   var
    f:TextFile;

   // Загрузить секцию в указанный объект, path - путь объекта (без слэша в конце)
   procedure LoadSection(var f:TextFile;item:TGenericTree;path:string);
    var
     st,arg,uArg,st2:string;
     sa:StringArr;
     comment:TCommentLine;
     incl:TInclude;
     sect:TSection;
     value:TNamedValue;
     i,n,ln:integer;

    begin
     ln:=0;
     // Последовательно обрабатываем все строки файла
     while not eof(f) do begin
      inc(ln);
      readln(f,st);
      st:=trim(st);
      // Comment line
      if (length(st)=0) or (st[1] in ['#',';']) then begin
       comment:=TCommentLine.Create;
       comment.line:=st;
       item.AddChild(comment);
       continue;
      end;
      // Разделим команду и аргумент
      arg:='';
      for i:=1 to length(st) do
       if st[i] in [' ',#9] then begin
        arg:=TrimLeft(copy(st,i+1,length(st)-i));
        SetLength(st,i-1);
        break;
       end;

      // Директива
      if st[1]='$' then begin
       // End of section
       if UpperCase(st)='$ENDOFSECTION' then break; // конец секции
       // Section
       if UpperCase(LeftStr(st,8))='$SECTION' then begin
        sect:=TSection.Create;
        sect.name:=arg;
        if arg='' then
         raise EWarning.Create('CTL2: unnamed section in '+filename+' line: '+inttostr(ln));
        i:=item.AddChild(sect);
        sect.fullname:=UpperCase(path+'\'+arg);
        hash.Put(sect.fullname,item.GetChild(i));
        LoadSection(f,item.GetChild(i),sect.fullname);
        continue;
       end;
       // Include command
       if UpperCase(LeftStr(st,8))='$INCLUDE' then begin
        incl:=TInclude.Create;
        incl.include:=arg;
        // Correct path so file is in the same directory
        if pos('\',arg)=0 then begin
         arg:=ExtractFilePath(filename)+arg;
        end;
        n:=useControlFile(arg,'');
        incl.handle:=n;
        if n=-1 then raise EWarning.Create('CTL2: include command failed - '+arg);
        item.AddChild(incl);
        continue;
       end;
      end;

      // Иначе - данные, нужно проверить тип
      SetDecimalSeparator('.');
      uArg:=UpperCase(arg);
      if (uArg='ON') or (uArg='OFF') or (uArg='YES') or (uArg='NO') then begin
       // boolean
       value:=TBoolValue.Create;
       (value as TBoolValue).value:=(uArg='ON') or (uArg='YES');
      end else
      if Q_IsInteger(arg) then begin
       // Integer
       value:=TIntValue.Create;
       (value as TIntValue).value:=StrToInt(arg);
      end else
      if Q_IsFloat(arg) then begin
       // Float
       value:=TFloatValue.Create;
       (value as TFloatValue).value:=ParseFloat(arg);
      end else begin
       // String or string list
       if arg[1]='(' then begin
        // string list
        if arg[length(arg)]<>')' then begin
         // Multiline record
         repeat
          readln(f,st2);
          st2:=trim(st2);
          arg:=arg+st2;
         until eof(f) or (st2[length(st2)]=')');
        end;
        // Delete '(' and ')'
        delete(arg,1,1);
        SetLength(arg,length(arg)-1);
        sa:=Split(',',arg,'"');
        // Create and fill object
        value:=TStringlistValue.Create;
        with value as TStringListValue do begin
         Allocate(Length(sa));
         for i:=0 to length(sa)-1 do
          value[i]:=UnQuoteStr(chop(sa[i]));
        end;
       end else begin
        arg:=UnQuoteStr(arg);
        value:=TStringValue.Create;
        (value as TStringValue).value:=arg;
       end;
      end;

      // Добавим элемент в структуры
      value.name:=st;
      value.fullname:=path+'\'+uppercase(st);
      i:=item.AddChild(value);
      hash.Put(value.fullname,item.GetChild(i));
     end;
    end;

   begin // LoadTextual
    // Открыть файл и загрузить его как секцию
    assignfile(f,filename);
    reset(f);
    LoadSection(f,item,UpperCase(ExtractFileName(filename))+':');
    closefile(f);
   end;

  procedure LoadBinary(filename:string;item:TGenericTree;code:cardinal);
   var
    f:file;
    h:TBinaryHeader;
    ms:TMemoryStream;
    mat:TMatrix32;
    p:byte;
    c:cardinal;
    size:integer;

   // Прочитать содержимое секции из двоичного файла
   procedure ReadSection(item:TGenericTree;path:string);
    var
     cnt,i,j,n:integer;
     b:byte;
     o:TObject;
     valB:boolean;
     valI:integer;
     valF:double;

    function ReadString:string;
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
          handle:=UseControlFile(include,'');
         end;
         item.AddChild(o);
       end;
       itSection:begin
         o:=TSection.Create;
         (o as TSection).name:=ReadString;
         n:=item.AddChild(o);
         ReadSection(item.GetChild(n),path+'\'+UpperCase((o as TSection).name));
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
        fullname:=path+'\'+UpperCase(name);
        hash.Put(fullname,item.GetChild(i-1));
      end;
     end;
    end;

   begin
    assignfile(f,filename);
    reset(f,1);
    blockread(f,h,sizeof(h));
    p:=(h.sign2 xor h.sign1)-28301740;
    if p>=20 then
     raise EError.Create('Invalid file header');
    move(h.data[p],c,4);
    c:=c+code; // Actual encryption code
    // Generate matrix for decryption
    GenMatrix32(mat,inttostr(c));
    mat:=InvertMatrix32(mat);
    // Read rest of the file and decrypt it
    size:=filesize(f)-sizeof(h);
    ms:=TMemoryStream.Create;
    ms.SetSize(size);
    blockread(f,ms.memory^,size);
    Decrypt32A(ms.memory^,size,mat);

    ReadSection(item,UpperCase(ExtractFileName(filename))+':');
    ms.Destroy;
    closefile(f);
   end;

  begin // Load
   result:=-1;
   // Проверка формата файла
   assignfile(f,filename);
   reset(f,1);
   if filesize(f)>=8 then begin
    blockread(f,h,8);
    if (h.sign1<=100000000) and (abs((h.sign2 xor h.sign1)-28301740)<=100) then mode:=fmBinary
     else mode:=fmText;
   end else
    mode:=fmText;
   closefile(f);

   // Создаем объект и добавляем его в структуры
   ctl:=TCtlFile.Create(filename,mode);
   ctl.fname:=filename;
   ctl.name:=ExtractFileName(filename);
   ctl.fullname:=UpperCase(ctl.name)+':';
   i:=items.AddChild(ctl);
   hash.Put(ctl.fullname,items.GetChild(i));
   ctl.curmode:=mode;
   ctl.code:=code;

   if ctl.curmode=fmText then
     LoadTextual(filename,items.GetChild(i))
   else
     LoadBinary(filename,items.GetChild(i),code);

   result:=ctl.handle;
  end;

begin
 try
  // Проверим, не был ли файл уже загружен ранее
  filename:=ExpandFileName(filename);
  for i:=0 to items.GetChildrenCount-1 do begin
   ctl:=items.GetChild(i).data;
   if ctl.fname=filename then begin
    result:=ctl.handle;
    inc(ctl.RefCounter);
    exit;
   end;
  end;
  if password<>'' then
   code:=CheckSumSlow(password[1],length(password),1)
  else code:=0;
  result:=Load(filename,code);
  
 except
  on e:Exception do
   raise EError.Create('CTL2: Can''t load control file: '+filename+', exception: '+e.Message);
 end;
end;

procedure SaveControlFile;
var
 name:string;
 item:TGenericTree;
 ctl:TCtlFile;

 procedure SaveTextual(item:TGenericTree;filename:string);
  var
   f:TextFile;

  // Сохранить в файл содержимое секции (с указанным отступом)
  procedure SaveSection(item:TGenericTree;indent:integer);
   var
    i,j:integer;
    o:TObject;
    pad,st:string;
   begin
    SetDecimalSeparator('.');
    for i:=0 to item.GetChildrenCount-1 do begin
     o:=item.GetChild(i).data;
     SetLength(pad,indent);
     for j:=1 to indent do
      pad[j]:=' ';
     // Save comment line
     if o is TCommentLine then begin
      writeln(f,pad,(o as TCommentLine).line);
      continue;
     end;
     // Директивы
     if o is TInclude then begin
      writeln(f,pad,'$Include ',(o as TInclude).include);
      SaveControlFile((o as TInclude).handle);
      continue;
     end;
     if o is TSection then begin
      writeln(f,pad,'$Section ',(o as TSection).name);
      SaveSection(item.GetChild(i),indent+2);
      writeln(f,pad,'$EndOfSection');
      continue;
     end;
     // Format string for named value
     // Все прочие варианты должны быть обработаны выше!
     if o is TNamedValue then begin
      st:=pad+(o as TNamedValue).name+'    ';
      while length(st) mod 8<>0 do st:=st+' ';
     end;
     // Save boolean value
     if o is TBoolValue then begin
      if (o as TBoolValue).Value then st:=st+'ON'
       else st:=st+'OFF';
      writeln(f,st);
      continue;
     end;
     // Save integer value
     if o is TIntValue then begin
      st:=st+inttostr((o as TIntValue).Value);
      writeln(f,st);
      continue;
     end;
     // Save float value
     if o is TFloatValue then begin
      st:=st+floattostrf((o as TFloatValue).Value,ffFixed,9,6);
      writeln(f,st);
      continue;
     end;
     // Save string value
     if o is TStringValue then begin
      //st:=st+QuoteStr((o as TStringValue).value);
      // Принудительное заключение в кавычки чтобы избежать конфликта с числами
      st:=st+'"'+(o as TStringValue).value+'"';
      writeln(f,st);
      continue;
     end;
     // Save string array value
     if o is TStringListValue then with o as TStringListValue do begin
      st:=st+'(';
      if count=0 then st:=st+')';
      j:=length(st);
      setLength(pad,j);
      for j:=1 to length(pad) do pad[j]:=' ';
      for j:=1 to count do begin
       while length(st) mod 8<>1 do st:=st+' ';
       st:=st+QuoteStr(value[j-1]);
       if j<count then st:=st+',' else st:=st+')';
       if length(st)>75 then begin
        writeln(f,st);
        st:=pad;
       end;
      end;
      // если осталась незаписанная строка
      if (length(st)<=75) and (st<>pad) then writeln(f,st);
      continue;
     end;
    end;
   end;

  begin
   assignfile(f,filename);
   rewrite(f);
   SaveSection(item,0);
   closefile(f);
  end;

 procedure SaveBinary(item:TGenericTree;filename:string);
  var
   f:file;
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
    procedure WriteString(st:string);
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
      // Директивы
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
      // Save string value
      if o is TStringValue then begin
       b:=itStr;
       ms.Write(b,1);
       WriteString((o as TStringValue).name);
       WriteString((o as TStringValue).value);
       continue;
      end;
      // Save string array value
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
   assignfile(f,filename);
   rewrite(f,1);
   p:=random(20);
   h.sign1:=random(100000000);
   h.sign2:=h.sign1 xor (28301740+p);
   code:=random(1000000);
   for i:=0 to 23 do h.data[i]:=random(256);
   move(code,h.data[p],4);
   o:=item.data;
   inc(code,(o as TCtlFile).code); // Actual encryption code
   ms:=TMemoryStream.Create;
   GenMatrix32(mat,inttostr(code));
   SaveSection(item);
   Encrypt32A(ms.memory^,ms.size,mat);
   blockwrite(f,h,sizeof(h));
   blockwrite(f,ms.memory^,ms.size);
   closefile(f);
   ms.Destroy;
  end;

begin
 name:='unknown';
 try
  item:=FileByHandle(handle);
  if item=nil then
   raise EWarning.Create('invalid handle passed');
  ctl:=item.data;
  if mode=fmDefault then mode:=ctl.CurMode;
  if mode=fmText then SaveTextual(item,ctl.fname)
   else SaveBinary(item,ctl.fname);
  ctl.modified:=false;

 except
  on e:Exception do
   raise EWarning.Create('CTL2: Can''t save control file: '+name+', exception: '+e.Message);
 end;
end;

procedure SaveAllControlFiles;
var
 i:integer;
 item:TNamedValue;
begin
 for i:=0 to items.GetChildrenCount-1 do begin
  item:=items.GetChild(i).data;
  if (item is TCtlFile) and ((item as TCtlFile).modified) then
   SaveControlFile(TCtlFile(item).handle);
 end;
end;

procedure FreeControlFile;
var
 ctl:TCtlFile;
 item:TGenericTree;
begin
 item:=FileByHandle(handle);
 if item<>nil then begin
  ctl:=item.data;
  dec(ctl.RefCounter);
  if ctl.RefCounter<=0 then
   item.Free;
 end;
end;

function IsKeyExists(key:String):Boolean;
 begin
  result:=(hash.Get(UpperCase(key))<>nil);
 end;

function FindItem(key:string):TObject;
 var
  item:TGenericTree;
 begin
  result:=nil;
  item:=hash.Get(UpperCase(key));
  if item=nil then exit;
  result:=item.data;
 end;

function ctlGetKeyType(key:String):ctlKeyTypes;
 var
  o:TObject;
 begin
  result:=cktNone;
  o:=FindItem(key);
  if o=nil then exit;
  if o is TIntValue then result:=cktInteger;
  if o is TBoolValue then result:=cktBool;
  if o is TFloatValue then result:=cktReal;
  if o is TStringValue then result:=cktString;
  if o is TStringListValue then result:=cktArray;
  if o is TSection then result:=cktSection;
 end;

const
 MessageKeyIncorrect='CTL2: key does not exists or has inproper type - ';
 MessageWrongType='CTL2: operation requires another type of key - ';
 MessageCannotCreateKey='CTL2: cannot create key - ';

function ctlGetBool(key:string):boolean;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TBoolValue) then
   result:=(o as TBoolValue).value
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetInt(key:string):integer;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TIntValue) then
   result:=(o as TIntValue).value
  else
  if (o<>nil) and (o is TStringValue) then
   result:=StrToIntDef((o as TStringValue).value,0)
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetReal(key:string):double;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TFloatValue) then
   result:=(o as TFloatValue).value
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetStr(key:string):string;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and ((o is TStringValue) or (o is TIntValue)) then begin
   if (o is TStringValue) then result:=(o as TStringValue).value else
   if (o is TIntValue) then result:=inttostr((o as TIntValue).value);
  end else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetBool(key:string;default:boolean):boolean;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TBoolValue) then
   result:=(o as TBoolValue).value
  else
   result:=default;
 end;
function ctlGetInt(key:string;default:integer):integer;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TIntValue) then
   result:=(o as TIntValue).value
  else
   result:=default;
 end;
function ctlGetReal(key:string;default:double):double;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TFloatValue) then
   result:=(o as TFloatValue).value
  else
   result:=default;
 end;
function ctlGetStr(key:string;default:string):string;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TStringValue) then
   result:=(o as TStringValue).value
  else
   result:=default;
 end;
function ctlGetStrInd(key:String;index:Integer):String;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TStringListValue) then
   result:=(o as TStringListValue).value[index]
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetStrCnt(key:String):Integer;
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TStringListValue) then
   result:=(o as TStringListValue).count
  else
   raise EWarning.Create(MessageKeyIncorrect+key);
 end;
function ctlGetKeys(key:string):String;
 var
  item:TGenericTree;
  o:TObject;
  i:integer;
 begin
  item:=hash.get(UpperCase(key));
  if item=nil then
   raise EWarning.Create(MessageKeyIncorrect+key);
  o:=item.data;
  if not (o is TSection) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  result:='';
  for i:=0 to item.GetChildrenCount-1 do begin
   o:=item.GetChild(i).data;
   if o is TNamedValue then begin
    if i>0 then result:=result+' ';
    result:=result+(o as TNamedValue).name;
   end;
  end;
 end;

// Write functions
procedure ctlCreateSection(key:string);
 var
  o:TObject;
  s,curS:TSection;
  f:TCtlFile;
  item:TGenericTree;
  i:integer;
  fname,sname:string;
  fl:boolean;
 begin
  o:=FindItem(key);
  if (o<>nil) and (o is TSection) then exit; // Section already exists
  if (o<>nil) and not (o is TSection) then
   raise EWarning.Create('CTL2: Cannot create section - key already exists: '+key);
  fname:=copy(key,1,pos(':',key)-1); // filename part of path
  delete(key,1,pos(':',key)+1);
  key:=key+'\';
  // Нужно найти файл в котором нужно создать секцию
  item:=nil;
  for i:=0 to items.GetChildrenCount-1 do begin
   f:=items.GetChild(i).data;
   if UpperCase(f.name)=UpperCase(fname) then item:=items.GetChild(i);
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
       (UpperCase((o as TSection).name)=UpperCase(sname)) then begin
     item:=item.GetChild(i);
     fl:=true;
     break;
    end;
   end;
   if not fl then begin // Subsection not found => create it
    curS:=item.data;
    s:=TSection.Create;
    s.name:=sname;
    if curs is TCtlFile then
     s.fullname:=curS.fullname+'\'+uppercase(sname)
    else
     s.fullname:=curS.fullname+'\'+uppercase(sname);
    i:=item.AddChild(s);
    item:=item.GetChild(i);
    hash.Put(s.fullname,item);
   end
  until length(key)=0;
 end;

// Создает элемент заданного типа, возвращает объект (но не лист дерева!)
function CreateKey(key:string;KeyType:TNamedValueClass):TObject;
 var
  i,n:integer;
  s:string;
  o:TNamedValue;
  item:TGenericTree;
 begin
  result:=nil;
  for i:=length(key) downto 1 do
   if key[i]='\' then begin
    s:=copy(key,1,i-1);
    ctlCreateSection(s);
    item:=hash.Get(UpperCase(s));
    o:=item.data;                         
    if o is TCtlFile then TCtlFile(o).modified:=true;
    o:=KeyType.Create;
    o.name:=Copy(key,i+1,length(key)-i);
    o.fullname:=UpperCase(key);
    n:=item.AddChild(o);
    hash.Put(o.fullname,item.GetChild(n));
    result:=o;
    exit;
   end;
 end;

procedure ctlSetBool(key:string;value:boolean);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TBoolValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TBoolValue then
   (o as TBoolValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
 end;

procedure ctlSetInt(key:string;value:integer);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TIntValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TIntValue then
   (o as TIntValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
 end;
procedure ctlSetReal(key:string;value:double);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TFloatValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TFloatValue then
   (o as TFloatValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
 end;
procedure ctlSetStr(key:string;value:string);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TStringValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if o is TStringValue then
   (o as TStringValue).value:=value
  else
   raise EWarning.Create(MessageWrongType+key);
 end;
procedure ctlSetStrInd(key:String;index:Integer;value:string);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o=nil) or not (o is TStringListValue) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  (o as TStringListValue).value[index]:=value;
 end;
procedure ctlSetStrCnt(key:String;count:integer);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if o=nil then begin // Create key
   o:=CreateKey(key,TStringListValue);
   if o=nil then raise EWarning.Create(MessageCannotCreateKey+key);
  end;
  if not (o is TStringListValue) then
   raise EWarning.Create(MessageWrongType+key);
  (o as TStringListValue).Allocate(count);
 end;
procedure ctlAddStr(key:String;newvalue:string);
 var
  o:TObject;
 begin
  o:=FindItem(key);
  if (o=nil) or not (o is TStringListValue) then
   raise EWarning.Create(MessageKeyIncorrect+key);
  with o as TStringListValue do begin
   Allocate(count+1);
   value[count-1]:=newvalue;
  end;
 end;

procedure ctlDeleteKey(key:string);
 var
  item:TGenericTree;
 begin
  item:=hash.Get(uppercase(key));
  if item=nil then
   raise EWarning.Create(MessageKeyIncorrect+key);
  if item.GetParent=nil then
   raise EWarning.Create('Can''t delete root section!');
  item.Free;
 end;

{ TControlFile }

procedure TControlFile.AddStr(key, newvalue: string);
begin
 EnterCriticalSection(critSect);
 try
  ctlAddStr(GetAbsPath(key),newvalue);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

constructor TControlFile.Create(fname,password:string);
begin
 handle:=-1;
 EnterCriticalSection(critSect);
 try
  handle:=UseControlFile(fname,password);
  path:=ExtractFileName(fname)+':';
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.CreateSection(key: string);
begin
 EnterCriticalSection(critSect);
 try
  ctlCreateSection(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

destructor TControlFile.Destroy;
begin
 if handle=-1 then exit;
 EnterCriticalSection(critSect);
 try
//  SaveControlFile(handle);
  FreeControlFile(handle);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetBool(key: string): boolean;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetBool(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetInt(key: string): integer;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetInt(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetKeyType(key: String): ctlKeyTypes;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetKeyType(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetReal(key: string): double;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetReal(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetStr(key: string): string;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetStr(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetStrCnt(key: String): Integer;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetStrCnt(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetStrInd(key: String; index: Integer): String;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetStrInd(GetAbsPath(key),index);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.KeyExists(key: String): Boolean;
begin
 EnterCriticalSection(critSect);
 try
  result:=IsKeyExists(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetAbsPath(key:string):string;
var
 i:integer;
begin
 if pos(':',key)>0 then begin
  result:=path; exit;
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
 EnterCriticalSection(critSect);
 SaveControlFile(handle);
 LeaveCriticalSection(CritSect);
end;

procedure TControlFile.SetBool(key: string; value: boolean);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetBool(GetAbsPath(key),value);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.SetInt(key: string; value: integer);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetInt(GetAbsPath(key),value);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.SetReal(key: string; value: double);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetReal(GetAbsPath(key),value);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.SetStr(key, value: string);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetStr(GetAbsPath(key),value);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.SetStrCnt(key: String; count: integer);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetStrCnt(GetAbsPath(key),count);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.SetStrInd(key: String; index: Integer;
  value: string);
begin
 EnterCriticalSection(critSect);
 try
  ctlSetStrInd(GetAbsPath(key),index,value);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetKeys(key: string): String;
begin
 EnterCriticalSection(critSect);
 try
  result:=ctlGetKeys(GetAbsPath(key));
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

procedure TControlFile.DeleteKey(key: string);
begin
 EnterCriticalSection(critSect);
 try
  ctlDeleteKey(key);
 finally
  LeaveCriticalSection(CritSect);
 end;
end;

function TControlFile.GetBool(key: string; default: boolean): boolean;
begin
 try
  result:=GetBool(key);
 except
  result:=default;
 end;
end;

function TControlFile.GetInt(key: string; default: integer): integer;
begin
 try
  result:=GetInt(key);
 except
  result:=default;
 end;
end;

function TControlFile.GetReal(key: string; default: double): double;
begin
 try
  result:=GetReal(key);
 except
  result:=default;
 end;
end;

function TControlFile.GetStr(key, default: string): string;
begin
 try
  result:=GetStr(key);
 except
  result:=default;
 end;

end;

initialization
 items:=TGenericTree.Create(true,true);
 hash:=TStrHash.Create;
 InitCritSect(critSect,'CtlFiles2',300);

finalization
// Удалять свои объекты не стоит - толку никакого, программа все-равно завершает работу
// а вот на баги нарываться не хочется...
 DeleteCritSect(critSect);
end.
