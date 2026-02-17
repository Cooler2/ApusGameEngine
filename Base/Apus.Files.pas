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
uses Apus.Core;

type
  TFileInfo = record
    size:int64;
    timestamp:TDateTime;
    isDirectory:boolean;
  end;

  TBuffer = pointer; // TEMPORARY STUB!

  TFileHandle = pointer; // opaque type
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
    class function LoadAsBuffer(const fname:String8):TBuffer; static;
    class procedure Save(const fname:String8; buf:pointer; size:integer); overload; static;
    class procedure Save(const fname:String8; const data:ByteArray); overload; static;
    class procedure Save(const fname:String8; const data:String8); overload; static;
    class procedure Save(const fname:String8; const data:TBuffer); overload; static;

    // --- Block I/O: one-shot open+seek+read/write+close ---
    // Old names: ReadFile, WriteFile
    class procedure ReadBlock(const fname:String8; buf:pointer; size:integer; offset:int64=0); static;
    class procedure WriteBlock(const fname:String8; buf:pointer; size:integer; offset:int64=0); static;

    // --- Handle-based I/O ---
    class function Open(const fname:String8; readOnly:boolean):TFileHandle; static;
    class procedure Close(f:TFileHandle); static;
    class function Read(f:TFileHandle; buf:pointer; size:integer):integer; static;
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
    class function SafeFileName(const fname:String8):String8; static;     // replace unsafe chars with '_'
    class function FileName(const fname:String8):String8; static;         // fix separators + apply case rules
    class procedure AddFileNameRule(const rule:String8); static;
    class function IsPathRelative(const fname:String8):boolean; static;
    // Poll until file appears (exists=true) or disappears (exists=false), return false on timeout
    class function WaitFor(const fname:String8; delayLimit:integer; exists:boolean=true):boolean; static;

    // --- Provider chain management ---
    // Register a new provider (becomes head of chain)
    class procedure SetProvider(provider:IFileProvider); static;
    class function GetProvider:IFileProvider; static;
  end;

  // --- Directory operations (OS-level, don't use provider chain) ---
  Folder = record
    class function Exists(const path:String8):boolean; static;
    class function Create(const path:String8):boolean; static; // create directory (with parents)
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
    function Open(const fname:String8; readOnly:boolean):TFileHandle;
    procedure Close(f:TFileHandle);
    function Read(f:TFileHandle; buf:pointer; size:integer):integer;
    function Seek(f:TFileHandle; offset:int64; origin:integer):int64;
    function Position(f:TFileHandle):int64;
    function FileSize(f:TFileHandle):int64;
    function Write(f:TFileHandle; buf:pointer; size:integer):integer;
    procedure SetSize(f:TFileHandle; newSize:int64);
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
    function Open(const fname:String8; readOnly:boolean):TFileHandle;
    procedure Close(f:TFileHandle);
    function Read(f:TFileHandle; buf:pointer; size:integer):integer;
    function Seek(f:TFileHandle; offset:int64; origin:integer):int64;
    function Position(f:TFileHandle):int64;
    function FileSize(f:TFileHandle):int64;
    function Write(f:TFileHandle; buf:pointer; size:integer):integer;
    procedure SetSize(f:TFileHandle; newSize:int64);
  end;

{ Helpers }

function HandleToFile(h:THandle):TFileHandle; inline;
begin
  result:=TFileHandle(h);
end;

function FileToHandle(f:TFileHandle):THandle; inline;
begin
  result:=THandle(f);
end;

{ TOSFileProvider }

function TOSFileProvider.FileExists(const fname:String8):boolean;
begin
  result:=SysUtils.FileExists(string(fname));
end;

function TOSFileProvider.GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
var
  sr:TSearchRec;
begin
  result:=SysUtils.FindFirst(string(fname),faAnyFile,sr)=0;
  if result then begin
    info.size:=sr.Size;
    info.timestamp:=sr.TimeStamp;
    info.isDirectory:=sr.Attr and faDirectory<>0;
    SysUtils.FindClose(sr);
  end;
end;

procedure TOSFileProvider.Delete(const fname:String8);
begin
  SysUtils.DeleteFile(string(fname));
end;

procedure TOSFileProvider.Rename(const curName,newName:String8);
begin
  SysUtils.RenameFile(string(curName),string(newName));
end;

function TOSFileProvider.ListFiles(const path:String8; const mask:String8):Strings8;
var
  sr:TSearchRec;
  cnt:integer;
  dir:string;
begin
  result:=nil; cnt:=0;
  dir:=string(path);
  if (dir<>'') and (dir[length(dir)]=PathDelim) then
    System.Delete(dir,length(dir),1);
  if SysUtils.FindFirst(dir+PathDelim+string(mask),faAnyFile,sr)=0 then begin
    repeat
      if (sr.Attr and faDirectory=0) and (sr.Name<>'.') and (sr.Name<>'..') then begin
        if cnt>=length(result) then
          SetLength(result,(cnt+16)*2);
        result[cnt]:=String8(dir+PathDelim+sr.Name);
        inc(cnt);
      end;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
  SetLength(result,cnt);
end;

function TOSFileProvider.Map(const fname:String8; readOnly:boolean):TBuffer;
begin
  // TODO: memory-mapped files
  result:=nil;
end;

procedure TOSFileProvider.UnMap(fileData:TBuffer);
begin
  // TODO: memory-mapped files
end;

function TOSFileProvider.Open(const fname:String8; readOnly:boolean):TFileHandle;
var
  h:THandle;
begin
  if readOnly then
    h:=SysUtils.FileOpen(string(fname),fmOpenRead or fmShareDenyNone)
  else begin
    if SysUtils.FileExists(string(fname)) then
      h:=SysUtils.FileOpen(string(fname),fmOpenReadWrite or fmShareDenyWrite)
    else
      h:=SysUtils.FileCreate(string(fname));
  end;
  if h=-1 then
    raise EError.Create('Cannot open file: '+string(fname));
  result:=HandleToFile(h);
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

class function Files.Open(const fname:String8; readOnly:boolean):TFileHandle;
begin
  result:=fileSystem.Open(fname,readOnly);
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
  f:=fileSystem.Open(fname,true);
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
end;

class function Files.LoadAsBuffer(const fname:String8):TBuffer;
begin
  // TODO: needs real TBuffer
  result:=nil;
end;

class procedure Files.Save(const fname:String8; buf:pointer; size:integer);
var
  f:TFileHandle;
begin
  f:=fileSystem.Open(fname,false);
  try
    if (buf<>nil) and (size>0) then
      fileSystem.Write(f,buf,size);
    fileSystem.SetSize(f,size);
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

class procedure Files.Save(const fname:String8; const data:String8);
begin
  if length(data)>0 then
    Save(fname,@data[1],length(data))
  else
    Save(fname,nil,0);
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
  f:=fileSystem.Open(fname,true);
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
  f:=fileSystem.Open(fname,false);
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
    src:=fileSystem.Open(sour,true);
    try
      dst:=fileSystem.Open(dest,false);
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
  bakName:string;
begin
  bakName:=SysUtils.ChangeFileExt(string(fname),'.bak');
  if SysUtils.FileExists(bakName) then
    SysUtils.DeleteFile(bakName);
  if SysUtils.FileExists(string(fname)) then
    SysUtils.RenameFile(string(fname),bakName);
end;

{ Folder record }

class function Folder.Exists(const path:String8):boolean;
begin
  result:=SysUtils.DirectoryExists(string(path));
end;

class function Folder.Create(const path:String8):boolean;
begin
  result:=SysUtils.ForceDirectories(string(path));
end;

class function Folder.ListFiles(const path:String8; const mask:String8; recursive:boolean):Strings8;
var
  masks:array of String8;
  mCnt,cnt,i,j,start:integer;
  sr:TSearchRec;
  dir:string;
  sub:Strings8;
begin
  result:=nil; cnt:=0;
  dir:=string(path);
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
    sub:=fileSystem.ListFiles(String8(dir),masks[i]);
    for j:=0 to length(sub)-1 do begin
      if cnt>=length(result) then
        SetLength(result,(cnt+16)*2);
      result[cnt]:=sub[j];
      inc(cnt);
    end;
  end;

  // recurse into subdirectories (OS-level enumeration)
  if recursive then begin
    if SysUtils.FindFirst(dir+PathDelim+'*',faAnyFile,sr)=0 then begin
      repeat
        if (sr.Attr and faDirectory<>0) and (sr.Name<>'.') and (sr.Name<>'..') then begin
          sub:=ListFiles(String8(dir+PathDelim+sr.Name),mask,true);
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
  sr:TSearchRec;
  dir:string;
  isDir:boolean;
begin
  result:='';
  dir:=string(path);
  if SysUtils.FindFirst(dir+PathDelim+'*',faAnyFile,sr)=0 then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      isDir:=sr.Attr and faDirectory<>0;
      if isDir then begin
        if findDir and SysUtils.SameText(sr.Name,string(name)) then begin
          result:=String8(dir+PathDelim+sr.Name);
          SysUtils.FindClose(sr);
          exit;
        end;
        result:=Find(name,String8(dir+PathDelim+sr.Name),findDir); // recurse
        if result<>'' then begin
          SysUtils.FindClose(sr);
          exit;
        end;
      end else begin
        if not findDir and SysUtils.SameText(sr.Name,string(name)) then begin
          result:=String8(dir+PathDelim+sr.Name);
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
  sr:TSearchRec;
  sSour,sDest:string;
begin
  result:=true;
  sSour:=string(sour);
  sDest:=string(dest);
  SysUtils.ForceDirectories(sDest);
  if SysUtils.FindFirst(sSour+PathDelim+'*',faAnyFile,sr)=0 then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      if sr.Attr and faDirectory<>0 then
        result:=Copy(String8(sSour+PathDelim+sr.Name),String8(sDest+PathDelim+sr.Name)) and result
      else
        result:=Files.CopyFile(String8(sSour+PathDelim+sr.Name),String8(sDest+PathDelim+sr.Name)) and result;
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
  sr:TSearchRec;
  dir:string;
begin
  result:=true;
  dir:=string(path);
  if SysUtils.FindFirst(dir+PathDelim+'*',faAnyFile,sr)=0 then begin
    repeat
      if (sr.Name='.') or (sr.Name='..') then continue;
      if sr.Attr and faDirectory<>0 then
        result:=Delete(String8(dir+PathDelim+sr.Name)) and result
      else
        result:=SysUtils.DeleteFile(dir+PathDelim+sr.Name) and result;
    until SysUtils.FindNext(sr)<>0;
    SysUtils.FindClose(sr);
  end;
  result:=SysUtils.RemoveDir(dir) and result;
end;

{ Files record — path utilities }

class function Files.SafeFileName(const fname:String8):String8;
var
  i:integer;
begin
  result:=String8(StringReplace(string(fname),'..','.',[rfReplaceAll]));
  for i:=1 to length(result) do
    if not (result[i] in ['A'..'Z','a'..'z','0'..'9','-','_','.']) then
      result[i]:='_';
end;

class function Files.FileName(const fname:String8):String8;
var
  i:integer;
  s:string;
begin
  s:=string(fname);
  for i:=0 to length(fileNameRules)-1 do
    s:=StringReplace(s,string(fileNameRules[i]),string(fileNameRules[i]),[rfIgnoreCase]);
  {$IFDEF MSWINDOWS}
  s:=StringReplace(s,'/','\',[rfReplaceAll]);
  {$ELSE}
  s:=StringReplace(s,'\','/',[rfReplaceAll]);
  {$ENDIF}
  result:=String8(s);
end;

class procedure Files.AddFileNameRule(const rule:String8);
begin
  fileNameRules:=fileNameRules+[rule];
end;

class function Files.IsPathRelative(const fname:String8):boolean;
begin
  result:=true;
  if (length(fname)>0) and (fname[1]='/') then exit(false);
  if Pos(':',string(fname))>0 then exit(false);
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
