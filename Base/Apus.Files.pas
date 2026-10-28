// File I/O and virtual file system - unified interface for file operations with provider chain
//
// SCOPE: High-level file operations (read/write/exists/list) with abstraction layer supporting
// multiple storage backends (OS files, archives, memory, network). Used by applications and
// engines that need flexible file access (games loading from ZIPs, tools with virtual mounts).
//
// ADD HERE: File operations, path utilities, VFS providers (ZIP, memory, HTTP).
// DON'T ADD: Format-specific parsers (images, configs), compression algorithms (→ separate modules),
// low-level stream operations without VFS context.
//
// Contains: IFileProvider interface, VFS provider chain (each provider captures previous as fallback),
// LoadFile/SaveFile, FileExists, ListFiles. Read operations search the chain; writes go to OS provider.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Files;
interface
uses Apus.Core, Apus.Types;

type
  TFileInfo = record
    size:int64;
    timestamp:TDateTime;
    isDirectory:boolean;
  end;

  TFileHandle = record
  private
    value:pointer;
  public
    class function Init(raw:pointer):TFileHandle; static; inline;
    function Raw:pointer; inline; // what the provider passed to Init
    function Read(var buf; size:integer):integer; overload; inline;
    function Write(const buf; size:integer):integer; overload; inline;
    function ReadMem(buf:pointer; size:integer):integer; inline;
    function WriteMem(buf:pointer; size:integer):integer; inline;
    function Seek(offset:int64; origin:integer):int64; inline;
    procedure Close; inline;
  end;
  IFileProvider = interface;

  Files = record
    // --- File existence and info ---
    class function Exists(const fname:String8):boolean; static;  // old name: MyFileExists
    class function GetFileInfo(const fname:String8; out info:TFileInfo):boolean; static;

    // --- Whole-file I/O ---
    // Old names: LoadFileAsBytes, LoadFileAsString, SaveFile
    // numBytes=0 means read whole file; startFrom = byte offset from beginning
    class function LoadAsBytes(const fname:String8; numBytes:int64=0; startFrom:int64=0):ByteArray; static;
    class function LoadAsString(const fname:String8; numBytes:int64=0; startFrom:int64=0):String8; static;
    class procedure Save(const fname:String8; buf:pointer; size:integer); overload; static;
    class procedure Save(const fname:String8; const data:ByteArray); overload; static;
    // Text save/load policy:
    // - LoadAsString removes UTF-8 BOM when reading from file start.
    // - Save(String8) writes UTF-8 BOM by default; pass addBOM=false for raw text.
    class procedure Save(const fname:String8; const data:String8; addBOM:boolean=true); overload; static;
    class procedure Save(const fname:String8; const data:TBuffer); overload; static;

    // --- Block I/O: one-shot open+seek+read/write+close ---
    // Old names: ReadFile, WriteFile
    class procedure ReadBlock(const fname:String8; buf:pointer; size:integer; offset:int64=0); static;
    class procedure WriteBlock(const fname:String8; buf:pointer; size:integer; offset:int64=0); static;

    // --- Handle-based I/O ---
    // How the file is opened is part of the function name, so a call site can't
    // silently mean something else:
    class function OpenRead(const fname:String8):TFileHandle; static;   // read-only, must exist
    class function Open(const fname:String8):TFileHandle; static;       // read+write from position 0, created if missing
    class function OpenNew(const fname:String8):TFileHandle; static;    // read+write, previous content discarded
    class function OpenAppend(const fname:String8):TFileHandle; static; // read+write at the end, created if missing
    class function Read(f:TFileHandle; buf:pointer; size:integer):integer; static;
    class procedure Close(f:TFileHandle); static;
    class function Write(f:TFileHandle; buf:pointer; size:integer):integer; static;
    class function Seek(f:TFileHandle; offset:int64; origin:integer):int64; static;
    class function Position(f:TFileHandle):int64; static;
    class function FileSize(f:TFileHandle):int64; static;
    class procedure SetSize(f:TFileHandle; newSize:int64); static;

    // --- Memory-mapped files ---
    class function Map(const fname:String8; readOnly:boolean):TBuffer; static;
    class procedure UnMap(fileData:TBuffer); static;

    // --- File operations ---
    class procedure Delete(const fname:String8); static;
    class procedure Rename(const curName,newName:String8); static;
    class function CopyFile(const sour,dest:String8):boolean; static;
    class procedure MakeBakFile(const fname:String8); static; // rename xxx.yyy -> xxx.bak

    // --- Path utilities (pure string operations, don't use provider chain) ---
    class function SafeName(const fname:String8):String8; static;     // replace unsafe chars with '_'
    class function FixName(const fname:String8):String8; static;         // fix separators + apply case rules
    class procedure AddFixNameRule(const rule:String8); static;
    class function IsPathRelative(const fname:String8):boolean; static;
    // Parts of a name. Separators are '/' and '\' on every platform, plus ':' (drive) on
    // Windows. Byte operations on UTF-8: unlike ExtractFilePath & co. of the RTL, nothing
    // goes through the ANSI code page under FPC, and Delphi takes '/' too
    class function GetPath(const fname:String8):String8; static; // folder with the trailing delimiter, '' if none
    class function GetDir(const fname:String8):String8; static;  // folder without the trailing delimiter (a root keeps it)
    class function GetName(const fname:String8):String8; static; // name with the extension
    class function GetExt(const fname:String8):String8; static;  // '.ext', '' if none; a leading dot ('.gitignore') is not one
    class function ChangeExt(const fname,ext:String8):String8; static; // ext with the dot, '' removes the extension
    // Poll until file appears (exists=true) or disappears (exists=false), return false on timeout
    class function WaitFor(const fname:String8; delayLimit:integer; exists:boolean=true):boolean; static;

    // --- Choosing among alternatives ---
    // Index of the file to use among names that stand for the same resource (an image
    // without extension: x.png, x.jpg...), -1 if none of them exists. The provider
    // (default: the chain head) decides if it implements IFileSelector, otherwise
    // SelectNewest. Names are passed as they are, like to GetFileInfo
    class function SelectFile(const names:array of String8; provider:IFileProvider=nil):integer; static;
    // The default rule: the newest existing file (directories don't count); on equal
    // timestamps, or with a provider that has none, the earlier name
    class function SelectNewest(const names:array of String8; provider:IFileProvider=nil):integer; static;

    // --- Provider chain management ---
    // Register a new provider (becomes head of chain)
    class procedure SetProvider(provider:IFileProvider); static;
    class function GetProvider:IFileProvider; static;
  end;

  // --- Directory operations (OS-level, don't use provider chain) ---
  Folder = record
    class function Exists(const path:String8):boolean; static;
    class function Create(const path:String8):boolean; static; // create directory (with parents)
    class function Writable(const path:String8):boolean; static; // can we create files here? (write-probe)
    class function Delete(const path:String8):boolean; static; // delete directory recursively
    class function Copy(const sour,dest:String8):boolean; static;
    class function Move(const sour,dest:String8):boolean; static;
    class function Find(const name,path:String8; findDir:boolean=false):String8; static; // recursive file/directory search
    // mask supports ';'-separated patterns, e.g. '*.png;*.jpg'
    class function ListFiles(const path:String8; const mask:String8='*'; recursive:boolean=false):Strings8; static;
  end;

  // Interface for the filesystem API. Default OS provider is the chain tail.
  IFileProvider = interface ['{AD96A87E-BEF9-424A-8705-A0047260DDDF}']
    function FileExists(const fname:String8):boolean;
    function GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
    procedure Delete(const fname:String8);
    procedure Rename(const curName,newName:String8);
    function ListFiles(const path:String8; const mask:String8='*'):Strings8;
    function Map(const fname:String8; readOnly:boolean):TBuffer;
    procedure UnMap(fileData:TBuffer);
    // See the Files.OpenXXX comments. A read-only provider (a pack file, say) only has
    // to serve OpenRead and can delegate the writing ones to the fallback provider.
    function OpenRead(const fname:String8):TFileHandle;
    function Open(const fname:String8):TFileHandle;
    function OpenNew(const fname:String8):TFileHandle;
    procedure Close(f:TFileHandle);
    function Read(f:TFileHandle; buf:pointer; size:integer):integer;
    function Seek(f:TFileHandle; offset:int64; origin:integer):int64;
    function Position(f:TFileHandle):int64;
    function FileSize(f:TFileHandle):int64;
    function Write(f:TFileHandle; buf:pointer; size:integer):integer;
    procedure SetSize(f:TFileHandle; newSize:int64);
  end;

  // Optional provider capability: choose among names that stand for the same resource
  // (see Files.SelectFile). A layered provider answers by layer priority: a file in a
  // higher layer wins whatever its extension or age. Only the chain head is asked, so
  // a provider that wraps another one forwards what it has no opinion about:
  // Files.SelectFile(names,next).
  IFileSelector = interface ['{6F0C2B7E-5D3A-4E1F-9B8C-2A7D4E6F1C35}']
    // Index in names of the file to use, -1 if none of them exists (final: the
    // caller doesn't look further)
    function SelectFile(const names:array of String8):integer;
  end;

implementation
uses SysUtils, Apus.Strings
  {$IFDEF MSWINDOWS},Windows{$ENDIF};

var
  fileSystem:IFileProvider;
  fileNameRules:array of String8;

type
  // Default OS filesystem provider (chain tail)
  TOSFileProvider = class(TInterfacedObject, IFileProvider)
  public
    function FileExists(const fname:String8):boolean;
    function GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
    procedure Delete(const fname:String8);
    procedure Rename(const curName,newName:String8);
    function ListFiles(const path:String8; const mask:String8='*'):Strings8;
    function Map(const fname:String8; readOnly:boolean):TBuffer;
    procedure UnMap(fileData:TBuffer);
    function OpenRead(const fname:String8):TFileHandle;
    function Open(const fname:String8):TFileHandle;
    function OpenNew(const fname:String8):TFileHandle;
    procedure Close(f:TFileHandle);
    function Read(f:TFileHandle; buf:pointer; size:integer):integer;
    function Seek(f:TFileHandle; offset:int64; origin:integer):int64;
    function Position(f:TFileHandle):int64;
    function FileSize(f:TFileHandle):int64;
    function Write(f:TFileHandle; buf:pointer; size:integer):integer;
    procedure SetSize(f:TFileHandle; newSize:int64);
  end;

{ TFileHandle }

class function TFileHandle.Init(raw:pointer):TFileHandle;
begin
  result.value:=raw;
end;

function TFileHandle.Raw:pointer;
begin
  result:=value;
end;

{ Helpers }

function HandleToFile(h:THandle):TFileHandle; inline;
begin
  result:=TFileHandle.Init(pointer(h));
end;

function FileToHandle(f:TFileHandle):THandle; inline;
begin
  result:=THandle(f.value);
end;

function TFileHandle.Read(var buf; size:integer):integer;
begin
  result:=Files.Read(self,@buf,size);
end;

function TFileHandle.ReadMem(buf:pointer; size:integer):integer;
begin
  result:=Files.Read(self,buf,size);
end;

function TFileHandle.Write(const buf; size:integer):integer;
begin
  result:=Files.Write(self,@buf,size);
end;

function TFileHandle.WriteMem(buf:pointer; size:integer):integer;
begin
  result:=Files.Write(self,buf,size);
end;

function TFileHandle.Seek(offset:int64; origin:integer):int64;
begin
  result:=Files.Seek(self,offset,origin);
end;

procedure TFileHandle.Close;
begin
  Files.Close(self);
end;

{ TOSFileProvider }

// --- File names for the OS functions of SysUtils ---
// FPC takes String8 as is: it converts to the file system code page by itself, while
// string(...) would go through the ANSI code page under Windows and lose the characters
// it can't encode (Ω, 日本). Delphi takes UTF-16 string. FPC's path helpers that return
// a name (ExpandFileName, ChangeFileExt) give it in the ANSI code page too - not used here.
{$IFDEF FPC}
type
  TSysName=RawByteString;
{$ELSE}
type
  TSysName=string;
{$ENDIF}
// FindFirst of FPC on Windows returns the names in the ANSI code page: search in UTF-16 there
{$IF defined(FPC) and defined(MSWINDOWS)}
  TSysSearchRec=TUnicodeSearchRec;
{$ELSE}
  TSysSearchRec=TSearchRec;
{$IFEND}

function SysName(const name:String8):TSysName; inline;
begin
  result:=TSysName(name);
end;

function SysFindFirst(const pattern:String8; attr:integer; out sr:TSysSearchRec):boolean;
begin
  {$IF defined(FPC) and defined(MSWINDOWS)}
  result:=SysUtils.FindFirst(UnicodeString(pattern),attr,sr)=0;
  {$ELSE}
  result:=SysUtils.FindFirst(SysName(pattern),attr,sr)=0;
  {$IFEND}
end;

function FoundName(const sr:TSysSearchRec):String8; inline;
begin
  {$IF defined(FPC) and defined(MSWINDOWS)}
  result:=UTF8Encode(sr.Name);
  {$ELSE}
  result:=String8(sr.Name);
  {$IFEND}
end;

function TOSFileProvider.FileExists(const fname:String8):boolean;
begin
  result:=SysUtils.FileExists(SysName(fname));
end;

function TOSFileProvider.GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
var
  sr:TSysSearchRec;
begin
  result:=SysFindFirst(fname,faAnyFile,sr);
  if result then begin
    info.size:=sr.Size;
    info.timestamp:=sr.TimeStamp;
    info.isDirectory:=sr.Attr and faDirectory<>0;
    SysUtils.FindClose(sr);
  end;
end;

procedure TOSFileProvider.Delete(const fname:String8);
begin
  SysUtils.DeleteFile(SysName(fname));
end;

procedure TOSFileProvider.Rename(const curName,newName:String8);
begin
  SysUtils.RenameFile(SysName(curName),SysName(newName));
end;

function TOSFileProvider.ListFiles(const path:String8; const mask:String8):Strings8;
var
  sr:TSysSearchRec;
  cnt:integer;
  dir:String8;
begin
  result:=nil; cnt:=0;
  dir:=path;
  if (dir<>'') and (dir[length(dir)]=PathDelim) then
    System.Delete(dir,length(dir),1);
  if SysFindFirst(dir+PathDelim+mask,faAnyFile,sr) then begin
    repeat
      if (sr.Attr and faDirectory=0) and (sr.Name<>'.') and (sr.Name<>'..') then begin
        if cnt>=length(result) then
          SetLength(result,(cnt+16)*2);
        result[cnt]:=dir+PathDelim+FoundName(sr);
        inc(cnt);
      end;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
  SetLength(result,cnt);
end;

function TOSFileProvider.Map(const fname:String8; readOnly:boolean):TBuffer;
begin
  NotImplemented;
  // TODO: memory-mapped files
  //result:=nil;
end;

procedure TOSFileProvider.UnMap(fileData:TBuffer);
begin
  NotImplemented;
  // TODO: memory-mapped files
end;

function CheckHandle(h:THandle; const fname:String8):TFileHandle;
begin
  if h=THandle(-1) then
    raise EError.Create('Cannot open file: '+string(fname));
  result:=HandleToFile(h);
end;

function TOSFileProvider.OpenRead(const fname:String8):TFileHandle;
begin
  result:=CheckHandle(SysUtils.FileOpen(SysName(fname),fmOpenRead or fmShareDenyNone),fname);
end;

// A missing parent directory is the usual reason a file cannot be created, and the
// caller is in no position to create it: a relative name is resolved by the provider
// chain, so only this end of the chain knows where the file actually lands. Creating
// it from the caller's side means guessing - and guessing by the current directory,
// which is not where the write goes.
function CreateFileWithFolder(const fname:String8):THandle;
var
  dir:String8;
begin
  result:=SysUtils.FileCreate(SysName(fname));
  if result<>THandle(-1) then exit;
  dir:=Files.GetPath(fname);
  if (dir='') or SysUtils.DirectoryExists(SysName(dir)) then exit; // the failure is something else
  if Folder.Create(dir) then
    result:=SysUtils.FileCreate(SysName(fname));
end;

function TOSFileProvider.Open(const fname:String8):TFileHandle;
var
  h:THandle;
begin
  if SysUtils.FileExists(SysName(fname)) then
    h:=SysUtils.FileOpen(SysName(fname),fmOpenReadWrite or fmShareDenyWrite)
  else
    h:=CreateFileWithFolder(fname);
  result:=CheckHandle(h,fname);
end;

function TOSFileProvider.OpenNew(const fname:String8):TFileHandle;
begin
  // FileCreate truncates an existing file, so nothing of the old content survives
  result:=CheckHandle(CreateFileWithFolder(fname),fname);
end;

procedure TOSFileProvider.Close(f:TFileHandle);
begin
  SysUtils.FileClose(FileToHandle(f));
end;

function TOSFileProvider.Read(f:TFileHandle; buf:pointer; size:integer):integer;
begin
  result:=SysUtils.FileRead(FileToHandle(f),buf^,size);
end;

function TOSFileProvider.Seek(f:TFileHandle; offset:int64; origin:integer):int64;
begin
  result:=SysUtils.FileSeek(FileToHandle(f),offset,origin);
end;

function TOSFileProvider.Position(f:TFileHandle):int64;
begin
  result:=SysUtils.FileSeek(FileToHandle(f),int64(0),1);
end;

function TOSFileProvider.FileSize(f:TFileHandle):int64;
var
  pos:int64;
begin
  pos:=SysUtils.FileSeek(FileToHandle(f),int64(0),1); // save position
  result:=SysUtils.FileSeek(FileToHandle(f),int64(0),2); // seek to end
  SysUtils.FileSeek(FileToHandle(f),pos,0); // restore position
end;

function TOSFileProvider.Write(f:TFileHandle; buf:pointer; size:integer):integer;
begin
  result:=SysUtils.FileWrite(FileToHandle(f),buf^,size);
end;

procedure TOSFileProvider.SetSize(f:TFileHandle; newSize:int64);
begin
  {$IFDEF MSWINDOWS}
  SysUtils.FileSeek(FileToHandle(f),newSize,0);
  SetEndOfFile(FileToHandle(f));
  {$ELSE}
  SysUtils.FileTruncate(FileToHandle(f),newSize);
  {$ENDIF}
end;

{ Files record — provider delegates }

class function Files.Exists(const fname:String8):boolean;
begin
  result:=fileSystem.FileExists(fname);
end;

class function Files.GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
begin
  result:=fileSystem.GetFileInfo(fname,info);
end;

class function Files.OpenRead(const fname:String8):TFileHandle;
begin
  result:=fileSystem.OpenRead(fname);
end;

class function Files.Open(const fname:String8):TFileHandle;
begin
  result:=fileSystem.Open(fname);
end;

class function Files.OpenNew(const fname:String8):TFileHandle;
begin
  result:=fileSystem.OpenNew(fname);
end;

class function Files.OpenAppend(const fname:String8):TFileHandle;
begin
  // Position only: this is not the atomic O_APPEND mode, concurrent writers can still overlap
  result:=fileSystem.Open(fname);
  fileSystem.Seek(result,0,2); // 2 = from the end
end;

class procedure Files.Close(f:TFileHandle);
begin
  fileSystem.Close(f);
end;

class function Files.Read(f:TFileHandle; buf:pointer; size:integer):integer;
begin
  result:=fileSystem.Read(f,buf,size);
end;

class function Files.Write(f:TFileHandle; buf:pointer; size:integer):integer;
begin
  result:=fileSystem.Write(f,buf,size);
end;

class function Files.Seek(f:TFileHandle; offset:int64; origin:integer):int64;
begin
  result:=fileSystem.Seek(f,offset,origin);
end;

class function Files.Position(f:TFileHandle):int64;
begin
  result:=fileSystem.Position(f);
end;

class function Files.FileSize(f:TFileHandle):int64;
begin
  result:=fileSystem.FileSize(f);
end;

class procedure Files.SetSize(f:TFileHandle; newSize:int64);
begin
  fileSystem.SetSize(f,newSize);
end;

class function Files.Map(const fname:String8; readOnly:boolean):TBuffer;
begin
  result:=fileSystem.Map(fname,readOnly);
end;

class procedure Files.UnMap(fileData:TBuffer);
begin
  fileSystem.UnMap(fileData);
end;

class procedure Files.Delete(const fname:String8);
begin
  fileSystem.Delete(fname);
end;

class procedure Files.Rename(const curName,newName:String8);
begin
  fileSystem.Rename(curName,newName);
end;

{ Files record — whole-file I/O }

class function Files.LoadAsBytes(const fname:String8; numBytes:int64; startFrom:int64):ByteArray;
var
  f:TFileHandle;
  size,toRead:int64;
begin
  f:=fileSystem.OpenRead(fname);
  try
    size:=fileSystem.FileSize(f);
    if startFrom>size then startFrom:=size;
    if numBytes=0 then
      toRead:=size-startFrom // read whole file
    else begin
      toRead:=numBytes;
      if startFrom+toRead>size then toRead:=size-startFrom;
    end;
    if toRead<0 then toRead:=0;
    SetLength(result,toRead);
    if toRead>0 then begin
      if startFrom>0 then
        fileSystem.Seek(f,startFrom,0);
      fileSystem.Read(f,@result[0],toRead);
    end;
  finally
    fileSystem.Close(f);
  end;
end;

class function Files.LoadAsString(const fname:String8; numBytes:int64; startFrom:int64):String8;
var
  buf:ByteArray;
begin
  buf:=LoadAsBytes(fname,numBytes,startFrom);
  SetLength(result,length(buf));
  if length(buf)>0 then
    Move(buf[0],result[1],length(buf));
  if (startFrom=0) and UTF8.HasBOM(result) then
    System.Delete(result,1,3);
end;

class procedure Files.Save(const fname:String8; buf:pointer; size:integer);
var
  f:TFileHandle;
begin
  f:=fileSystem.OpenNew(fname);
  try
    if (buf<>nil) and (size>0) then
      fileSystem.Write(f,buf,size);
  finally
    fileSystem.Close(f);
  end;
end;

class procedure Files.Save(const fname:String8; const data:ByteArray);
begin
  if length(data)>0 then
    Save(fname,@data[0],length(data))
  else
    Save(fname,nil,0);
end;

class procedure Files.Save(const fname:String8; const data:String8; addBOM:boolean);
const
  BOM:array[0..2] of byte=($EF,$BB,$BF);
var
  f:TFileHandle;
begin
  if length(data)=0 then begin
    Save(fname,nil,0);
    exit;
  end;
  if addBOM and not UTF8.HasBOM(data) then begin
    f:=OpenNew(fname);
    try
      f.WriteMem(@BOM,3);
      f.WriteMem(@data[1],length(data));
    finally
      f.Close;
    end;
  end else
    Save(fname,@data[1],length(data));
end;

class procedure Files.Save(const fname:String8; const data:TBuffer);
begin
  // TODO: needs real TBuffer
end;

{ Files record — block I/O }

class procedure Files.ReadBlock(const fname:String8; buf:pointer; size:integer; offset:int64);
var
  f:TFileHandle;
begin
  f:=fileSystem.OpenRead(fname);
  try
    if offset>0 then
      fileSystem.Seek(f,offset,0);
    if fileSystem.Read(f,buf,size)<>size then
      raise EError.Create('ReadBlock failed: '+string(fname));
  finally
    fileSystem.Close(f);
  end;
end;

class procedure Files.WriteBlock(const fname:String8; buf:pointer; size:integer; offset:int64);
var
  f:TFileHandle;
begin
  f:=fileSystem.Open(fname);
  try
    if offset>0 then
      fileSystem.Seek(f,offset,0);
    if fileSystem.Write(f,buf,size)<>size then
      raise EError.Create('WriteBlock failed: '+string(fname));
  finally
    fileSystem.Close(f);
  end;
end;

{ Files record — file operations }

class function Files.CopyFile(const sour,dest:String8):boolean;
var
  src,dst:TFileHandle;
  buf:array[0..65535] of byte; // 64KB buffer
  n:integer;
begin
  result:=true;
  try
    src:=fileSystem.OpenRead(sour);
    try
      dst:=fileSystem.OpenNew(dest);
      try
        repeat
          n:=fileSystem.Read(src,@buf[0],sizeof(buf));
          if n>0 then
            fileSystem.Write(dst,@buf[0],n);
        until n<sizeof(buf);
      finally
        fileSystem.Close(dst);
      end;
    finally
      fileSystem.Close(src);
    end;
  except
    result:=false;
  end;
end;

class procedure Files.MakeBakFile(const fname:String8);
var
  bakName:String8;
begin
  bakName:=Files.ChangeExt(fname,'.bak');
  if SysUtils.FileExists(SysName(bakName)) then
    SysUtils.DeleteFile(SysName(bakName));
  if SysUtils.FileExists(SysName(fname)) then
    SysUtils.RenameFile(SysName(fname),SysName(bakName));
end;

{ Folder record }

class function Folder.Exists(const path:String8):boolean;
begin
  result:=SysUtils.DirectoryExists(SysName(path));
end;

class function Folder.Create(const path:String8):boolean;
begin
  {$IFDEF FPC}
  result:=SysUtils.ForceDirectories(SysName(path)); // ExpandFileName of FPC returns an ANSI name
  {$ELSE}
  // Delphi's ForceDirectories rejects a bare relative name (empty parent), so expand first
  result:=SysUtils.ForceDirectories(SysUtils.ExpandFileName(string(path)));
  {$ENDIF}
end;

class function Folder.Writable(const path:String8):boolean;
var
  probe:String8;
  f:file;
begin
  result:=false;
  if not SysUtils.DirectoryExists(SysName(path)) then exit;
  // Probe by creating and deleting a throwaway file: the read-only case we care
  // about (a signed macOS .app's Contents/Resources) can't be told from perms
  // alone, so ask the filesystem directly.
  probe:=path;
  if (probe<>'') and not (probe[length(probe)] in ['/','\']) then probe:=probe+PathDelim;
  probe:=probe+'.apus_write_test.tmp';
  AssignFile(f,SysName(probe));
  {$UNDEF APUS_FILES_IOCHECK_ON}
  {$IFOPT I+}{$DEFINE APUS_FILES_IOCHECK_ON}{$ENDIF}
  {$I-}
  Rewrite(f,1);
  result:=IOResult=0;
  if result then CloseFile(f);
  {$IFDEF APUS_FILES_IOCHECK_ON}{$I+}{$ENDIF}
  {$UNDEF APUS_FILES_IOCHECK_ON}
  if result then SysUtils.DeleteFile(SysName(probe));
end;

class function Folder.ListFiles(const path:String8; const mask:String8; recursive:boolean):Strings8;
var
  masks:array of String8;
  mCnt,cnt,i,j,start:integer;
  sr:TSysSearchRec;
  dir:String8;
  sub:Strings8;
begin
  result:=nil; cnt:=0;
  dir:=path;
  if (length(dir)>0) and (dir[length(dir)]=PathDelim) then
    SetLength(dir,length(dir)-1);

  // split mask by ';'
  mCnt:=0;
  start:=1;
  for i:=1 to length(mask)+1 do begin
    if (i>length(mask)) or (mask[i] in [';',',']) then begin
      if i>start then begin
        SetLength(masks,mCnt+1);
        masks[mCnt]:=mask.Substr(start,i-start);
        inc(mCnt);
      end;
      start:=i+1;
    end;
  end;
  if mCnt=0 then begin
    SetLength(masks,1);
    masks[0]:='*';
    mCnt:=1;
  end;

  // list files for each mask via provider
  for i:=0 to mCnt-1 do begin
    sub:=fileSystem.ListFiles(dir,masks[i]);
    for j:=0 to length(sub)-1 do begin
      if cnt>=length(result) then
        SetLength(result,(cnt+16)*2);
      result[cnt]:=sub[j];
      inc(cnt);
    end;
  end;

  // recurse into subdirectories (OS-level enumeration)
  if recursive then begin
    if SysFindFirst(dir+PathDelim+'*',faAnyFile,sr) then begin
      repeat
        if (sr.Attr and faDirectory<>0) and (sr.Name<>'.') and (sr.Name<>'..') then begin
          sub:=ListFiles(dir+PathDelim+FoundName(sr),mask,true);
          for j:=0 to length(sub)-1 do begin
            if cnt>=length(result) then
              SetLength(result,(cnt+16)*2);
            result[cnt]:=sub[j];
            inc(cnt);
          end;
        end;
      until SysUtils.FindNext(sr)<>0;
      SysUtils.FindClose(sr);
    end;
  end;

  SetLength(result,cnt);
end;

class function Folder.Find(const name,path:String8; findDir:boolean):String8;
var
  sr:TSysSearchRec;
  lowName,found:String8;
  isDir:boolean;
begin
  result:='';
  lowName:=name.ToLower; // Unicode case folding: SameText folds ASCII only
  if SysFindFirst(path+PathDelim+'*',faAnyFile,sr) then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      isDir:=sr.Attr and faDirectory<>0;
      found:=FoundName(sr);
      if isDir then begin
        if findDir and (found.ToLower=lowName) then begin
          result:=path+PathDelim+found;
          SysUtils.FindClose(sr);
          exit;
        end;
        result:=Find(name,path+PathDelim+found,findDir); // recurse
        if result<>'' then begin
          SysUtils.FindClose(sr);
          exit;
        end;
      end else begin
        if not findDir and (found.ToLower=lowName) then begin
          result:=path+PathDelim+found;
          SysUtils.FindClose(sr);
          exit;
        end;
      end;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
end;

class function Folder.Copy(const sour,dest:String8):boolean;
var
  sr:TSysSearchRec;
  found:String8;
begin
  result:=true;
  Folder.Create(dest); // not ForceDirectories directly: it needs an expanded path under Delphi
  if SysFindFirst(sour+PathDelim+'*',faAnyFile,sr) then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      found:=FoundName(sr);
      if sr.Attr and faDirectory<>0 then
        result:=Copy(sour+PathDelim+found,dest+PathDelim+found) and result
      else
        result:=Files.CopyFile(sour+PathDelim+found,dest+PathDelim+found) and result;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
end;

class function Folder.Move(const sour,dest:String8):boolean;
begin
  result:=Copy(sour,dest);
  if result then
    result:=Delete(sour);
end;

class function Folder.Delete(const path:String8):boolean;
var
  sr:TSysSearchRec;
  found:String8;
begin
  result:=true;
  if SysFindFirst(path+PathDelim+'*',faAnyFile,sr) then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      found:=FoundName(sr);
      if sr.Attr and faDirectory<>0 then
        result:=Delete(path+PathDelim+found) and result
      else
        result:=SysUtils.DeleteFile(SysName(path+PathDelim+found)) and result;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
  result:=SysUtils.RemoveDir(SysName(path)) and result;
end;

{ Files record — path utilities }

class function Files.SafeName(const fname:String8):String8;
var
  i:integer;
begin
  result:=fname.ReplaceAll('..','.');
  for i:=1 to length(result) do
    if not (result[i] in ['A'..'Z','a'..'z','0'..'9','-','_','.']) then
      result[i]:='_';
end;

class function Files.FixName(const fname:String8):String8;
var
  i,p:integer;
begin
  // String8 throughout: a round trip through string loses non-ANSI characters under FPC
  result:=fname;
  for i:=0 to length(fileNameRules)-1 do begin
    p:=result.IndexOf(fileNameRules[i],1,true);
    if p>0 then
      result:=Copy(result,1,p-1)+fileNameRules[i]+Copy(result,p+length(fileNameRules[i]),length(result));
  end;
  for i:=1 to length(result) do
    {$IFDEF MSWINDOWS}
    if result[i]='/' then result[i]:='\';
    {$ELSE}
    if result[i]='\' then result[i]:='/';
    {$ENDIF}
end;

class procedure Files.AddFixNameRule(const rule:String8);
begin
  fileNameRules:=fileNameRules+[rule];
end;

class function Files.IsPathRelative(const fname:String8):boolean;
begin
  result:=true;
  if (length(fname)>0) and (fname[1]='/') then exit(false);
  if fname.IndexOf(':')>0 then exit(false);
end;

const
  NAME_DELIMS=['/','\'{$IFDEF MSWINDOWS},':'{$ENDIF}];

// Index of the first character of the name part (after the last delimiter)
function NameStart(const fname:String8):integer;
begin
  result:=length(fname);
  while (result>0) and not (fname[result] in NAME_DELIMS) do dec(result);
  inc(result);
end;

// Index of the dot that starts the extension, 0 if there is none
function ExtStart(const fname:String8):integer;
var
  first:integer;
begin
  first:=NameStart(fname);
  result:=length(fname);
  while (result>first) and (fname[result]<>'.') do dec(result);
  if result<=first then result:=0; // no dot, or a leading one
end;

class function Files.GetPath(const fname:String8):String8;
begin
  result:=Copy(fname,1,NameStart(fname)-1);
end;

class function Files.GetDir(const fname:String8):String8;
var
  len:integer;
begin
  result:=GetPath(fname);
  len:=length(result);
  // drop trailing delimiters, but keep the one of a root: '/', 'C:\'
  while (len>1) and (result[len] in ['/','\']) and (result[len-1]<>':') do dec(len);
  SetLength(result,len);
end;

class function Files.GetName(const fname:String8):String8;
var
  first:integer;
begin
  first:=NameStart(fname);
  result:=Copy(fname,first,length(fname)-first+1);
end;

class function Files.GetExt(const fname:String8):String8;
var
  dot:integer;
begin
  dot:=ExtStart(fname);
  if dot>0 then result:=Copy(fname,dot,length(fname)-dot+1)
    else result:='';
end;

class function Files.ChangeExt(const fname,ext:String8):String8;
var
  dot:integer;
begin
  dot:=ExtStart(fname);
  if dot>0 then result:=Copy(fname,1,dot-1)+ext
    else result:=fname+ext;
end;

class function Files.WaitFor(const fname:String8; delayLimit:integer; exists:boolean):boolean;
var
  elapsed:integer;
begin
  elapsed:=0;
  while elapsed<delayLimit do begin
    if Files.Exists(fname)=exists then exit(true);
    Sleep(10);
    inc(elapsed,10);
  end;
  result:=false;
end;

class function Files.SelectFile(const names:array of String8; provider:IFileProvider=nil):integer;
var
  selector:IFileSelector;
begin
  if provider=nil then provider:=fileSystem;
  if Supports(provider,IFileSelector,selector) then
    result:=selector.SelectFile(names)
  else
    result:=SelectNewest(names,provider);
  ASSERT((result>=-1) and (result<=high(names)));
end;

class function Files.SelectNewest(const names:array of String8; provider:IFileProvider=nil):integer;
var
  i:integer;
  info:TFileInfo;
  newest:TDateTime;
begin
  if provider=nil then provider:=fileSystem;
  result:=-1; newest:=0;
  for i:=0 to high(names) do begin
    if not provider.GetFileInfo(names[i],info) or info.isDirectory then continue;
    if (result<0) or (info.timestamp>newest) then begin
      result:=i;
      newest:=info.timestamp;
    end;
  end;
end;

{ Files record — provider chain }

class procedure Files.SetProvider(provider:IFileProvider);
begin
  fileSystem:=provider;
end;

class function Files.GetProvider:IFileProvider;
begin
  result:=fileSystem;
end;

initialization
  fileSystem:=TOSFileProvider.Create;
end.
