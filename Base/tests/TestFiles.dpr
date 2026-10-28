{$APPTYPE CONSOLE}
program TestFiles;
uses
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Threads,
  Apus.Log,
  Apus.Strings,
  Apus.Files,
  Apus.ControlFiles,
  Apus.Translation;

{$INCLUDE Test.inc}

const
  TestDir = '_test_files_tmp';

procedure Cleanup;
begin
  if Folder.Exists(TestDir) then
    Folder.Delete(TestDir);
end;

procedure TestSaveLoad;
var
  bytes:ByteArray;
  s:String8;
begin
  StartTest('Save/Load');
  Folder.Create(TestDir);

  // Save and load as bytes
  SetLength(bytes,4);
  bytes[0]:=$DE; bytes[1]:=$AD; bytes[2]:=$BE; bytes[3]:=$EF;
  Files.Save(TestDir+'/test.bin',bytes);
  Check(Files.Exists(TestDir+'/test.bin'),'file exists after save');

  bytes:=Files.LoadAsBytes(TestDir+'/test.bin');
  Check(length(bytes)=4,'loaded 4 bytes');
  Check((bytes[0]=$DE) and (bytes[3]=$EF),'bytes content');

  // Save and load as string
  Files.Save(TestDir+'/test.txt','Hello, Files!');
  s:=Files.LoadAsString(TestDir+'/test.txt');
  Check(s='Hello, Files!','string content');
  bytes:=Files.LoadAsBytes(TestDir+'/test.txt');
  Check((length(bytes)>=3) and (bytes[0]=$EF) and (bytes[1]=$BB) and (bytes[2]=$BF),'string save adds UTF-8 BOM by default');

  // Save pointer+size
  s:='raw data';
  Files.Save(TestDir+'/raw.bin',@s[1],length(s));
  Check(Files.LoadAsString(TestDir+'/raw.bin')='raw data','pointer save');

  EndTest;
end;

procedure TestPartialRead;
var
  bytes:ByteArray;
  s:String8;
begin
  StartTest('Partial read');
  Files.Save(TestDir+'/partial.txt','ABCDEFGHIJ',false);

  // read from offset
  s:=Files.LoadAsString(TestDir+'/partial.txt',0,3);
  Check(s='DEFGHIJ','startFrom=3');

  // read N bytes
  s:=Files.LoadAsString(TestDir+'/partial.txt',4);
  Check(s='ABCD','numBytes=4');

  // read N bytes from offset
  s:=Files.LoadAsString(TestDir+'/partial.txt',3,2);
  Check(s='CDE','numBytes=3, startFrom=2');

  // read beyond EOF - should clamp
  bytes:=Files.LoadAsBytes(TestDir+'/partial.txt',100,8);
  Check(length(bytes)=2,'clamp to EOF');

  EndTest;
end;

procedure TestBlockIO;
var
  buf:array[0..7] of byte;
begin
  StartTest('Block I/O');
  Files.Save(TestDir+'/block.bin','ABCDEFGH',false);

  // ReadBlock at offset
  Files.ReadBlock(TestDir+'/block.bin',@buf,4,4);
  Check((buf[0]=ord('E')) and (buf[3]=ord('H')),'ReadBlock offset=4');

  // WriteBlock at offset
  buf[0]:=ord('X'); buf[1]:=ord('Y');
  Files.WriteBlock(TestDir+'/block.bin',@buf,2,2);
  Check(Files.LoadAsString(TestDir+'/block.bin')='ABXYEFGH','WriteBlock offset=2');

  EndTest;
end;

procedure TestHandleIO;
var
  f:TFileHandle;
  buf:array[0..3] of byte;
  ptrIn,ptrOut:pointer;
  n:integer;
begin
  StartTest('Handle I/O');
  // write
  f:=Files.OpenNew(TestDir+'/handle.bin');
  buf[0]:=$11; buf[1]:=$22; buf[2]:=$33; buf[3]:=$44;
  f.Write(buf,4);
  Check(Files.Position(f)=4,'position after write');
  Check(Files.FileSize(f)=4,'filesize');
  f.Close;

  // read
  f:=Files.OpenRead(TestDir+'/handle.bin');
  Mem.Clear(buf,4);
  n:=f.Read(buf,4);
  Check(n=4,'read 4 bytes');
  Check((buf[0]=$11) and (buf[3]=$44),'read content');

  // seek
  f.Seek(1,0);
  Check(Files.Position(f)=1,'seek to 1');
  f.Read(buf,1);
  Check(buf[0]=$22,'read after seek');
  f.Close;

  // write/read pointer value itself (not pointed data)
  ptrIn:=pointer(UIntPtr($12345678));
  f:=Files.OpenNew(TestDir+'/handle_ptr.bin');
  f.Write(ptrIn,sizeof(ptrIn));
  f.Close;
  ptrOut:=nil;
  f:=Files.OpenRead(TestDir+'/handle_ptr.bin');
  n:=f.Read(ptrOut,sizeof(ptrOut));
  f.Close;
  Check(n=sizeof(ptrOut),'read pointer-sized bytes');
  Check(ptrOut=ptrIn,'pointer value roundtrip');

  EndTest;
end;

// Writing a file must leave nothing of what was there before
procedure TestOverwrite;
var
  f:TFileHandle;
  b:byte;
begin
  StartTest('Overwrite');
  // Save(String8) with the default BOM
  Files.Save(TestDir+'/ovr1.txt','a very long line of text');
  Files.Save(TestDir+'/ovr1.txt','short');
  Check(Files.LoadAsString(TestDir+'/ovr1.txt')='short','Save(String8) with BOM truncates');

  // Save(String8) without BOM
  Files.Save(TestDir+'/ovr2.txt','a very long line of text',false);
  Files.Save(TestDir+'/ovr2.txt','short',false);
  Check(Files.LoadAsString(TestDir+'/ovr2.txt')='short','Save(String8) raw truncates');

  // CopyFile over a longer file
  Files.Save(TestDir+'/ovr_src.txt','tiny',false);
  Files.Save(TestDir+'/ovr_dst.txt','a very long line of text',false);
  Files.CopyFile(TestDir+'/ovr_src.txt',TestDir+'/ovr_dst.txt');
  Check(Files.LoadAsString(TestDir+'/ovr_dst.txt')='tiny','CopyFile truncates');

  // OpenNew discards the old content
  Files.Save(TestDir+'/ovr3.txt','a very long line of text',false);
  f:=Files.OpenNew(TestDir+'/ovr3.txt');
  Check(Files.FileSize(f)=0,'OpenNew starts empty');
  f.Close;

  // ...while Open keeps it and writes from the start
  Files.Save(TestDir+'/ovr4.txt','ABCDEFGH',false);
  f:=Files.Open(TestDir+'/ovr4.txt');
  b:=ord('X');
  f.Write(b,1);
  f.Close;
  Check(Files.LoadAsString(TestDir+'/ovr4.txt')='XBCDEFGH','Open writes from position 0');

  // WriteBlock at an offset must not truncate either
  Files.Save(TestDir+'/ovr5.txt','ABCDEFGH',false);
  b:=ord('Z');
  Files.WriteBlock(TestDir+'/ovr5.txt',@b,1,2);
  Check(Files.LoadAsString(TestDir+'/ovr5.txt')='ABZDEFGH','WriteBlock keeps the rest');
  EndTest;
end;

procedure TestOpenModes;
var
  f:TFileHandle;
  failed:boolean;
begin
  StartTest('Open modes');
  // OpenAppend: position at the end, file created when missing
  Files.Save(TestDir+'/app.txt','AB',false);
  f:=Files.OpenAppend(TestDir+'/app.txt');
  Check(Files.Position(f)=2,'OpenAppend starts at the end');
  f.WriteMem(pointer(PAnsiChar('CD')),2);
  f.Close;
  Check(Files.LoadAsString(TestDir+'/app.txt')='ABCD','OpenAppend adds to the end');

  Files.Delete(TestDir+'/app_new.txt');
  f:=Files.OpenAppend(TestDir+'/app_new.txt');
  f.Close;
  Check(Files.Exists(TestDir+'/app_new.txt'),'OpenAppend creates a missing file');

  // Open creates a missing file too
  Files.Delete(TestDir+'/open_new.txt');
  f:=Files.Open(TestDir+'/open_new.txt');
  f.Close;
  Check(Files.Exists(TestDir+'/open_new.txt'),'Open creates a missing file');

  // OpenRead requires an existing one
  failed:=false;
  try
    f:=Files.OpenRead(TestDir+'/no_such_file.txt');
    f.Close;
  except
    failed:=true;
  end;
  Check(failed,'OpenRead fails on a missing file');
  EndTest;
end;

procedure TestFileOps;
begin
  StartTest('File operations');
  Files.Save(TestDir+'/orig.txt','content');

  // Rename
  Files.Rename(TestDir+'/orig.txt',TestDir+'/renamed.txt');
  Check(not Files.Exists(TestDir+'/orig.txt'),'orig gone');
  Check(Files.Exists(TestDir+'/renamed.txt'),'renamed exists');

  // CopyFile
  Check(Files.CopyFile(TestDir+'/renamed.txt',TestDir+'/copy.txt'),'CopyFile ok');
  Check(Files.Exists(TestDir+'/copy.txt'),'copy exists');
  if Files.Exists(TestDir+'/copy.txt') then
    Check(Files.LoadAsString(TestDir+'/copy.txt')='content','copy content');

  // Delete
  Files.Delete(TestDir+'/copy.txt');
  Check(not Files.Exists(TestDir+'/copy.txt'),'deleted');

  // MakeBakFile
  Files.Save(TestDir+'/backup.dat','data');
  Files.MakeBakFile(TestDir+'/backup.dat');
  Check(not Files.Exists(TestDir+'/backup.dat'),'original removed');
  Check(Files.Exists(TestDir+'/backup.bak'),'bak created');
  Check(Files.LoadAsString(TestDir+'/backup.bak')='data','bak content');

  EndTest;
end;

procedure TestGetFileInfo;
var
  info:TFileInfo;
begin
  StartTest('GetFileInfo');
  Files.Save(TestDir+'/info.txt','12345',false);
  Check(Files.GetFileInfo(TestDir+'/info.txt',info),'GetFileInfo ok');
  Check(info.size=5,'size=5');
  Check(not info.isDirectory,'not directory');
  Check(not Files.GetFileInfo(TestDir+'/nonexistent.txt',info),'nonexistent returns false');
  EndTest;
end;

procedure TestFolderOps;
begin
  StartTest('Folder operations');

  // Create + Exists
  Check(Folder.Create(TestDir+'/sub/nested'),'create nested');
  Check(Folder.Exists(TestDir+'/sub/nested'),'nested exists');
  Check(Folder.Exists(TestDir+'/sub'),'parent exists');

  // Copy
  Files.Save(TestDir+'/sub/file1.txt','one');
  Files.Save(TestDir+'/sub/nested/file2.txt','two');
  Check(Folder.Copy(TestDir+'/sub',TestDir+'/sub_copy'),'Folder.Copy');
  Check(Files.LoadAsString(TestDir+'/sub_copy/file1.txt')='one','copy file1');
  Check(Files.LoadAsString(TestDir+'/sub_copy/nested/file2.txt')='two','copy nested file2');

  // Move
  Check(Folder.Move(TestDir+'/sub_copy',TestDir+'/sub_moved'),'Folder.Move');
  Check(Folder.Exists(TestDir+'/sub_moved'),'moved exists');
  Check(not Folder.Exists(TestDir+'/sub_copy'),'source removed');

  // Delete
  Check(Folder.Delete(TestDir+'/sub_moved'),'Folder.Delete');
  Check(not Folder.Exists(TestDir+'/sub_moved'),'deleted');

  EndTest;
end;

// A write creates the directory it writes into: the caller can't do it itself, since
// a relative name is resolved by the provider chain and only its end knows where the
// file lands (see CreateFileWithFolder in Apus.Files).
procedure TestWriteCreatesFolder;
var
  f:TFileHandle;
begin
  StartTest('Write creates missing folder');

  Files.Save(TestDir+'/made/up/path/file.txt','content');
  Check(Files.LoadAsString(TestDir+'/made/up/path/file.txt')='content','Files.Save into a missing directory');

  f:=Files.Open(TestDir+'/made/another/file.bin');
  Files.Close(f);
  Check(Files.Exists(TestDir+'/made/another/file.bin'),'Files.Open into a missing directory');

  EndTest;
end;

procedure TestListFiles;
var
  list:Strings8;
begin
  StartTest('ListFiles');
  Folder.Create(TestDir+'/list');
  Files.Save(TestDir+'/list/a.txt','');
  Files.Save(TestDir+'/list/b.txt','');
  Files.Save(TestDir+'/list/c.png','');

  // single mask
  list:=Folder.ListFiles(TestDir+'/list','*.txt');
  Check(length(list)=2,'*.txt = 2 files');

  // multi mask with ;
  list:=Folder.ListFiles(TestDir+'/list','*.txt;*.png');
  Check(length(list)=3,'*.txt;*.png = 3 files');

  // wildcard
  list:=Folder.ListFiles(TestDir+'/list');
  Check(length(list)=3,'* = 3 files');

  // recursive
  Folder.Create(TestDir+'/list/sub');
  Files.Save(TestDir+'/list/sub/d.txt','');
  list:=Folder.ListFiles(TestDir+'/list','*.txt',true);
  Check(length(list)=3,'recursive *.txt = 3 files');

  EndTest;
end;

procedure TestFind;
begin
  StartTest('Folder.Find');
  Folder.Create(TestDir+'/find/deep/dir');
  Files.Save(TestDir+'/find/deep/target.txt','found');
  Folder.Create(TestDir+'/find/deep/targetdir');

  // find file
  Check(Folder.Find('target.txt',TestDir+'/find')<>'','find file');
  Check(Folder.Find('nonexistent.txt',TestDir+'/find')='','not found');

  // find directory
  Check(Folder.Find('targetdir',TestDir+'/find',true)<>'','find dir');
  Check(Folder.Find('targetdir',TestDir+'/find',false)='','file search skips dir');

  EndTest;
end;

// Names with characters outside the ANSI code page (Ω, ů, 日本) next to Cyrillic: under FPC
// on Windows a name passed or returned through the ANSI string API loses them. String8
// comparisons below are byte-exact: both sides are UTF-8.
// Non-ASCII literals are only assigned to String8 variables or passed as String8 arguments:
// FPC converts those at compile time, while a literal inside an expression is converted at
// run time by the widestring manager - without cwstring (Linux) it gives '?'.
procedure TestUnicodeNames;
var
  folderName,dir,name,renamed,bakName,upName,copyDir,logName,logMsg,path,fixed,expected:String8;
  list:Strings8;
  info:TFileInfo;
begin
  StartTest('Non-ANSI file names');
  folderName:='Юникод Ω 日本';
  name:='файл Ω 日本.txt';
  renamed:='другое ů 日本.txt';
  bakName:='другое ů 日本.bak';
  upName:='ДРУГОЕ Ů 日本.TXT';
  copyDir:=' копия';
  logName:='журнал Ω.log';
  logMsg:='запись Ω';
  dir:=TestDir+'/'+folderName;
  copyDir:=dir+copyDir;
  path:=dir+'/'+name;
  Files.Save(path,'unicode',false);
  Check(Files.Exists(path),'Save + Exists');
  Check(Files.LoadAsString(path)='unicode','LoadAsString');
  Check(Files.GetFileInfo(path,info) and (info.size=7),'GetFileInfo');
  Files.Rename(path,dir+'/'+renamed);
  Check(Files.Exists(dir+'/'+renamed) and not Files.Exists(path),'Rename');
  list:=Folder.ListFiles(dir,'*.txt');
  Check((length(list)=1) and (list[0]=dir+PathDelim+renamed),'ListFiles returns the name in UTF-8');
  list:=Folder.ListFiles(TestDir,'*.txt',true); // the recursion joins with PathDelim
  Check(list.IndexOf(TestDir+PathDelim+folderName+PathDelim+renamed)>=0,'recursive ListFiles enters the folder');
  Check(Folder.Find(upName,dir)=dir+PathDelim+renamed,'Find ignores Unicode case');
  Files.MakeBakFile(dir+'/'+renamed);
  Check(Files.LoadAsString(dir+'/'+bakName)='unicode','MakeBakFile');
  Check(Folder.Copy(dir,copyDir),'Folder.Copy');
  Check(Files.LoadAsString(copyDir+'/'+bakName)='unicode','copied file');
  Check(Folder.Delete(copyDir) and not Folder.Exists(copyDir),'Folder.Delete');
  fixed:='Ω/日本.txt';
  {$IFDEF MSWINDOWS}expected:='Ω\日本.txt';{$ELSE}expected:='Ω/日本.txt';{$ENDIF}
  Check(Files.FixName(fixed)=expected,'FixName keeps the characters');
  Logger.UseLogFile(dir+'/'+logName);
  Log.Force(logMsg);
  Logger.Flush;
  Check(Files.LoadAsString(dir+'/'+logName).IndexOf('exe: '+Env.ExeName)>0,'log header');
  Check(Files.LoadAsString(dir+'/'+logName).IndexOf(logMsg)>0,'log message');
  EndTest;
end;

procedure TestNameParts;
var
  uname,udir:String8;
begin
  StartTest('Name parts');
  Check(Files.GetPath('dir/sub/file.txt')='dir/sub/','GetPath');
  Check(Files.GetPath('a\b/file.txt')='a\b/','GetPath takes both delimiters');
  Check(Files.GetPath('file.txt')='','GetPath without a folder');
  Check(Files.GetDir('dir/sub/file.txt')='dir/sub','GetDir');
  Check(Files.GetDir('/file.txt')='/','GetDir keeps the root');
  Check(Files.GetDir('file.txt')='','GetDir without a folder');
  Check(Files.GetName('dir/sub/file.txt')='file.txt','GetName');
  Check(Files.GetName('dir/sub/')='','GetName of a folder');
  Check(Files.GetExt('dir/file.tar.gz')='.gz','GetExt takes the last dot');
  Check(Files.GetExt('dir.v2/file')='','GetExt ignores a dot in the folder');
  Check(Files.GetExt('dir/.gitignore')='','GetExt: a leading dot is not an extension');
  Check(Files.ChangeExt('dir/file.txt','.bak')='dir/file.bak','ChangeExt');
  Check(Files.ChangeExt('dir.v2/file','.bak')='dir.v2/file.bak','ChangeExt adds an extension');
  Check(Files.ChangeExt('dir/file.txt','')='dir/file','ChangeExt removes an extension');
  Check(Files.ChangeExt('dir/.gitignore','.bak')='dir/.gitignore.bak','ChangeExt keeps a leading dot');
  {$IFDEF MSWINDOWS}
  Check(Files.GetName('C:file.txt')='file.txt','GetName after a drive');
  Check(Files.GetDir('C:\file.txt')='C:\','GetDir keeps a drive root');
  {$ENDIF}
  // literals in variables: see TestUnicodeNames
  uname:='日本 Ω.данные';
  udir:='Юникод Ω/';
  Check(Files.GetName(udir+uname)=uname,'GetName keeps UTF-8');
  Check(Files.GetPath(udir+uname)=udir,'GetPath keeps UTF-8');
  uname:='.данные';
  Check(Files.GetExt(udir+'x'+uname)=uname,'GetExt keeps UTF-8');
  EndTest;
end;

procedure TestPathUtils;
begin
  StartTest('Path utilities');

  // SafeName
  Check(Files.SafeName('hello world!')='hello_world_','SafeName spaces+punct');
  Check(Files.SafeName('file..name')='file.name','SafeName double dots');
  Check(Files.SafeName('valid-file_01.txt')='valid-file_01.txt','SafeName clean');

  // IsPathRelative
  Check(Files.IsPathRelative('some/path'),'relative');
  Check(not Files.IsPathRelative('/absolute/path'),'absolute /');
  Check(not Files.IsPathRelative('C:\windows'),'absolute C:');

  // FixName + AddFixNameRule
  {$IFDEF MSWINDOWS}
  Check(Files.FixName('path/to/file')='path\to\file','FixName fix separators');
  {$ELSE}
  Check(Files.FixName('path\to\file')='path/to/file','FixName fix separators');
  {$ENDIF}
  Files.AddFixNameRule('MyFile');
  Check(Files.FixName('myfile')='MyFile','FixName case rule');

  EndTest;
end;

type
  // A file opened in TMemFileProvider
  TMemOpenFile=class
    index:integer; // in TMemFileProvider.names
    data:ByteArray;
    pos:integer;
    writable:boolean;
  end;

  // Keeps files under "vfs/" in memory and passes everything else to the previous provider.
  // Code that bypasses Files can't see these files at all.
  TMemFileProvider=class(TInterfacedObject,IFileProvider)
    fallback:IFileProvider;
    names:Strings8;
    contents:array of ByteArray;
    constructor Create(prev:IFileProvider);
    function Key(const fname:String8):String8;
    function IsMine(const fname:String8):boolean;
    function IndexOf(const fname:String8):integer;
    function OpenMem(const fname:String8;writable,truncate:boolean):TFileHandle;
    function Mine(f:TFileHandle):TMemOpenFile;
    // IFileProvider
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

var
  memOpened:array of TMemOpenFile;

constructor TMemFileProvider.Create(prev:IFileProvider);
begin
  fallback:=prev;
end;

function TMemFileProvider.Key(const fname:String8):String8;
begin
  result:=fname.ReplaceAll('\','/').ToLower;
end;

function TMemFileProvider.IsMine(const fname:String8):boolean;
begin
  result:=Key(fname).StartsWith('vfs/');
end;

function TMemFileProvider.IndexOf(const fname:String8):integer;
var
  i:integer;
begin
  for i:=0 to high(names) do
    if names[i]=Key(fname) then exit(i);
  result:=-1;
end;

function TMemFileProvider.OpenMem(const fname:String8;writable,truncate:boolean):TFileHandle;
var
  mf:TMemOpenFile;
  i:integer;
begin
  i:=IndexOf(fname);
  if i<0 then begin
    if not writable then raise EError.Create('VFS: file not found '+fname);
    i:=length(names);
    SetLength(names,i+1);
    SetLength(contents,i+1);
    names[i]:=Key(fname);
  end;
  if truncate then contents[i]:=nil;
  mf:=TMemOpenFile.Create;
  mf.index:=i;
  mf.data:=Copy(contents[i]);
  mf.writable:=writable;
  SetLength(memOpened,length(memOpened)+1);
  memOpened[high(memOpened)]:=mf;
  result:=TFileHandle.Init(mf);
end;

function TMemFileProvider.Mine(f:TFileHandle):TMemOpenFile;
var
  i:integer;
begin
  for i:=0 to high(memOpened) do
    if pointer(memOpened[i])=f.Raw then exit(memOpened[i]);
  result:=nil;
end;

function TMemFileProvider.FileExists(const fname:String8):boolean;
begin
  if IsMine(fname) then result:=IndexOf(fname)>=0
    else result:=fallback.FileExists(fname);
end;

function TMemFileProvider.GetFileInfo(const fname:String8; out info:TFileInfo):boolean;
var
  i:integer;
begin
  if not IsMine(fname) then exit(fallback.GetFileInfo(fname,info));
  i:=IndexOf(fname);
  result:=i>=0;
  if not result then exit;
  info.size:=length(contents[i]);
  info.timestamp:=0;
  info.isDirectory:=false;
end;

procedure TMemFileProvider.Delete(const fname:String8);
begin
  if IsMine(fname) then raise EError.Create('VFS: not supported');
  fallback.Delete(fname);
end;

procedure TMemFileProvider.Rename(const curName,newName:String8);
begin
  if IsMine(curName) then raise EError.Create('VFS: not supported');
  fallback.Rename(curName,newName);
end;

function TMemFileProvider.ListFiles(const path:String8; const mask:String8):Strings8;
begin
  result:=fallback.ListFiles(path,mask);
end;

function TMemFileProvider.Map(const fname:String8; readOnly:boolean):TBuffer;
begin
  if IsMine(fname) then raise EError.Create('VFS: not supported');
  result:=fallback.Map(fname,readOnly);
end;

procedure TMemFileProvider.UnMap(fileData:TBuffer);
begin
  fallback.UnMap(fileData);
end;

function TMemFileProvider.OpenRead(const fname:String8):TFileHandle;
begin
  if IsMine(fname) then result:=OpenMem(fname,false,false)
    else result:=fallback.OpenRead(fname);
end;

function TMemFileProvider.Open(const fname:String8):TFileHandle;
begin
  if IsMine(fname) then result:=OpenMem(fname,true,false)
    else result:=fallback.Open(fname);
end;

function TMemFileProvider.OpenNew(const fname:String8):TFileHandle;
begin
  if IsMine(fname) then result:=OpenMem(fname,true,true)
    else result:=fallback.OpenNew(fname);
end;

procedure TMemFileProvider.Close(f:TFileHandle);
var
  mf:TMemOpenFile;
  i:integer;
begin
  mf:=Mine(f);
  if mf=nil then begin
    fallback.Close(f); exit;
  end;
  if mf.writable then contents[mf.index]:=mf.data;
  for i:=0 to high(memOpened) do
    if memOpened[i]=mf then begin
      memOpened[i]:=memOpened[high(memOpened)];
      SetLength(memOpened,high(memOpened));
      break;
    end;
  mf.Free;
end;

function TMemFileProvider.Read(f:TFileHandle; buf:pointer; size:integer):integer;
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then exit(fallback.Read(f,buf,size));
  result:=length(mf.data)-mf.pos;
  if result>size then result:=size;
  if result<0 then result:=0;
  if result>0 then move(mf.data[mf.pos],buf^,result);
  inc(mf.pos,result);
end;

function TMemFileProvider.Seek(f:TFileHandle; offset:int64; origin:integer):int64;
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then exit(fallback.Seek(f,offset,origin));
  case origin of
    1:mf.pos:=mf.pos+offset;
    2:mf.pos:=length(mf.data)+offset;
    else mf.pos:=offset;
  end;
  result:=mf.pos;
end;

function TMemFileProvider.Position(f:TFileHandle):int64;
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then exit(fallback.Position(f));
  result:=mf.pos;
end;

function TMemFileProvider.FileSize(f:TFileHandle):int64;
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then exit(fallback.FileSize(f));
  result:=length(mf.data);
end;

function TMemFileProvider.Write(f:TFileHandle; buf:pointer; size:integer):integer;
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then exit(fallback.Write(f,buf,size));
  if mf.pos+size>length(mf.data) then SetLength(mf.data,mf.pos+size);
  if size>0 then move(buf^,mf.data[mf.pos],size);
  inc(mf.pos,size);
  result:=size;
end;

procedure TMemFileProvider.SetSize(f:TFileHandle; newSize:int64);
var
  mf:TMemOpenFile;
begin
  mf:=Mine(f);
  if mf=nil then begin
    fallback.SetSize(f,newSize); exit;
  end;
  SetLength(mf.data,newSize);
end;

// Base units that read data files must go through the provider chain: these files exist only in memory
procedure TestProviderChain;
const
  MAIN_CTL=
    '# test config'#13#10+
    'Width   800'#13#10+
    'Name    "Apus"'#13#10+
    '$Section Sub'#13#10+
    '  Flag  ON'#13#10+
    '$EndOfSection'#13#10+
    'List    ("a","b",'#13#10+
    '         "c")'#13#10+
    '$Include sub.ctl'#13#10;
var
  prev:IFileProvider;
  h:integer;
  size1,size2:integer;
  data:ByteArray;
begin
  StartTest('Provider chain');
  prev:=Files.GetProvider;
  Files.SetProvider(TMemFileProvider.Create(prev));
  try
    Files.Save('vfs/main.ctl',MAIN_CTL,false);
    Files.Save('vfs/sub.ctl','Depth 3'#13#10,true);
    Check(Files.Exists('vfs/main.ctl') and not Folder.Exists('vfs'),'memory file is visible only through Files');

    // Textual control file with a section, a multiline list and an include
    h:=UseControlFile('vfs/main.ctl');
    Check(ctlGetInt('main.ctl:\Width')=800,'ctl: int value');
    Check(ctlGetStr('main.ctl:\Name')='Apus','ctl: string value');
    Check(ctlGetBool('main.ctl:\Sub\Flag'),'ctl: value in a section');
    Check((ctlGetStrCnt('main.ctl:\List')=3) and (ctlGetStrInd('main.ctl:\List',2)='c'),'ctl: multiline list');
    Check(ctlGetInt('sub.ctl:\Depth')=3,'ctl: included file');

    // Save twice: the file must not grow (no extra empty line per round trip)
    ctlSetInt('main.ctl:\Width',1024);
    SaveControlFile(h,fmText);
    size1:=length(Files.LoadAsBytes('vfs/main.ctl'));
    FreeControlFile(h);
    h:=UseControlFile('vfs/main.ctl');
    Check(ctlGetInt('main.ctl:\Width')=1024,'ctl: textual save and reload');
    SaveControlFile(h,fmText);
    size2:=length(Files.LoadAsBytes('vfs/main.ctl'));
    Check(size1=size2,'ctl: textual round trip is stable');

    // Binary format
    SaveControlFile(h,fmBinary);
    FreeControlFile(h);
    data:=Files.LoadAsBytes('vfs/main.ctl');
    Check((length(data)>0) and (data[0]<>ord('#')),'ctl: binary save');
    h:=UseControlFile('vfs/main.ctl');
    Check((ctlGetInt('main.ctl:\Width')=1024) and ctlGetBool('main.ctl:\Sub\Flag'),'ctl: binary reload');
    FreeControlFile(h);

    // Translation dictionary (UTF-8 with BOM)
    Files.Save('vfs/dict.txt','LanguageID: fr'#13#10'; comment'#13#10'Hello'#13#10'Bonjour'#13#10);
    LoadDictionary('vfs/dict.txt');
    Check(Translate('Hello')='Bonjour','dictionary loaded');
    Check(languageID='fr','dictionary language');
  finally
    Files.SetProvider(prev);
  end;
  Check(not Folder.Exists('vfs'),'nothing written to disk');
  EndTest;
end;

// Load a control file expected to be malformed, return the error message ('' - loaded)
function CtlLoadError(const fname:String8):string;
begin
  result:='';
  try
    FreeControlFile(UseControlFile(fname));
  except
    on e:Exception do result:=e.Message;
  end;
end;

// Malformed textual control files give a parse error with the file and line, never an out-of-bounds read
procedure TestControlFileErrors;
var
  prev:IFileProvider;
  msg:string;
begin
  StartTest('Control file errors');
  prev:=Files.GetProvider;
  Files.SetProvider(TMemFileProvider.Create(prev));
  try
    Files.Save('vfs/nokey.ctl','Development ON'#13#10'BrokenKey',false);
    msg:=CtlLoadError('vfs/nokey.ctl');
    Check((Pos('no value for key BrokenKey',msg)>0) and (Pos('nokey.ctl line: 2',msg)>0),'ctl: key without a value: '+msg);
    Check(CtlLoadError('vfs/nokey.ctl')<>'','ctl: failed file is not kept loaded');
    Check(not IsKeyExists('nokey.ctl:\Development'),'ctl: keys of a failed file are dropped');

    Files.Save('vfs/openlist.ctl','Width 1'#13#10'List ("a",'#13#10'  "b"'#13#10,false);
    msg:=CtlLoadError('vfs/openlist.ctl');
    Check((Pos('unterminated list for key List',msg)>0) and (Pos('openlist.ctl line: 2',msg)>0),'ctl: unterminated list: '+msg);

    Files.Save('vfs/empty.ctl','',false);
    Check(CtlLoadError('vfs/empty.ctl')='','ctl: empty file loads');
  finally
    Files.SetProvider(prev);
  end;
  EndTest;
end;

// The value type of a textual key is detected from its literal
procedure TestControlFileTypes;
const
  TYPES_CTL=
    'I1 42'#13#10'I2 -7'#13#10'I3 +5'#13#10'I4 2147483647'#13#10'I5 -2147483648'#13#10+
    'F1 0.5'#13#10'F2 1e3'#13#10'F3 -2.5E-2'#13#10'F4 2147483648'#13#10'F5 1.10'#13#10+
    'S1 1.'#13#10'S2 .5'#13#10'S3 $FF'#13#10'S4 12abc'#13#10'S5 1e'#13#10'S6 "42"'#13#10+
    'B1 on'#13#10;
var
  prev:IFileProvider;
  h:integer;
  // Check the detected type of a key
  procedure CheckType(const key:String8;kt:ctlKeyTypes);
  begin
    Check(ctlGetKeyType('types.ctl:\'+key)=kt,'ctl: type of '+key);
  end;
begin
  StartTest('Control file value types');
  prev:=Files.GetProvider;
  Files.SetProvider(TMemFileProvider.Create(prev));
  try
    Files.Save('vfs/types.ctl',TYPES_CTL,false);
    h:=UseControlFile('vfs/types.ctl');
    CheckType('I1',cktInteger); CheckType('I2',cktInteger); CheckType('I3',cktInteger);
    CheckType('I4',cktInteger); CheckType('I5',cktInteger);
    CheckType('F1',cktReal); CheckType('F2',cktReal); CheckType('F3',cktReal);
    CheckType('F4',cktReal); CheckType('F5',cktReal);
    CheckType('S1',cktString); CheckType('S2',cktString); CheckType('S3',cktString);
    CheckType('S4',cktString); CheckType('S5',cktString); CheckType('S6',cktString);
    CheckType('B1',cktBool);
    Check((ctlGetInt('types.ctl:\I3')=5) and (ctlGetInt('types.ctl:\I5')=Low(integer)),'ctl: integer values');
    Check((abs(ctlGetReal('types.ctl:\F3')+0.025)<1e-12) and (ctlGetReal('types.ctl:\F4')=2147483648.0),'ctl: float values');
    Check(ctlGetStr('types.ctl:\S6')='42','ctl: quoted number is a string');
    FreeControlFile(h);
  finally
    Files.SetProvider(prev);
  end;
  EndTest;
end;

// Fixes of the stage 1 of the config redesign: each block failed on the previous code
procedure TestControlFileFixes;
const
  FIX_CTL='# head'#13#10'Width 800'#13#10'$Section Sub'#13#10'  ; comment first'#13#10+
    '  A 1'#13#10'  B 2'#13#10'$EndOfSection'#13#10;
  // typed: a bare float literal is extended on some targets and never equals a double
  F1:double=1e-7;
  F2:double=0.3;
  F3:double=1/3;
  F5:double=1e20;
var
  prev:IFileProvider;
  h:integer;
  ctl:TControlFile;
  sep:char;
  ok:boolean;
  msg:string;
  before,after:String8;
begin
  StartTest('Control file fixes');
  prev:=Files.GetProvider;
  Files.SetProvider(TMemFileProvider.Create(prev));
  sep:={$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator;
  {$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator:=',';
  try
    Files.Save('vfs/fix.ctl',FIX_CTL,false);
    // Loading doesn't touch the global random generator
    RandSeed:=12345;
    h:=UseControlFile('vfs/fix.ctl');
    Check(RandSeed=12345,'ctl: load keeps RandSeed');

    // Key list of a section that starts with a comment
    Check(ctlGetKeys('fix.ctl:\Sub')='A B','ctl: GetKeys has no leading space: "'+ctlGetKeys('fix.ctl:\Sub')+'"');

    // TControlFile: absolute key and relative delete
    ctl:=TControlFile.Create('vfs/fix.ctl');
    try
      ok:=false;
      try ok:=ctl.GetInt('fix.ctl:\Width')=800; except end;
      Check(ok,'ctl: TControlFile accepts an absolute key');
      ok:=false;
      try ctl.DeleteKey('Sub\B'); ok:=not IsKeyExists('fix.ctl:\Sub\B'); except end;
      Check(ok,'ctl: TControlFile.DeleteKey takes a relative key');
    finally
      ctl.Free;
    end;

    // A key and a section created in the file root survive save and reload
    ctlSetInt('fix.ctl:\NewKey',5);
    ctlCreateSection('fix.ctl:\New\Deep');
    // Floats are saved exactly, keep their type and don't depend on the decimal separator
    ctlSetReal('fix.ctl:\F1',F1);
    ctlSetReal('fix.ctl:\F2',F2);
    ctlSetReal('fix.ctl:\F3',F3);
    ctlSetReal('fix.ctl:\F4',1.0);
    ctlSetReal('fix.ctl:\F5',F5);
    ctlSetReal('fix.ctl:\F6',-2.5);
    ctlSetStr('fix.ctl:\Quoted','say "hi"');
    SaveControlFile(h,fmText);
    FreeControlFile(h);
    Check(Pos('0,',String(Files.LoadAsString('vfs/fix.ctl')))=0,'ctl: float saved with a dot');
    ok:=false;
    try h:=UseControlFile('vfs/fix.ctl'); ok:=true; except end;
    Check(ok,'ctl: file with keys created in the root reloads');
    if ok then begin
      Check(ctlGetInt('fix.ctl:\NewKey',0)=5,'ctl: root key value');
      Check(ctlGetKeyType('fix.ctl:\New\Deep')=cktSection,'ctl: created section');
      Check(ctlGetReal('fix.ctl:\F1',0)=F1,'ctl: float 1e-7');
      Check(ctlGetReal('fix.ctl:\F2',0)=F2,'ctl: float 0.3');
      Check(ctlGetReal('fix.ctl:\F3',0)=F3,'ctl: float 1/3');
      Check(ctlGetKeyType('fix.ctl:\F4')=cktReal,'ctl: float 1.0 stays float');
      Check(ctlGetReal('fix.ctl:\F5',0)=F5,'ctl: float 1e20');
      Check(ctlGetReal('fix.ctl:\F6',0)=-2.5,'ctl: float -2.5');
      Check(ctlGetStr('fix.ctl:\Quoted','')='say "hi"','ctl: string with quotes');

      // A line break can't be saved in the textual format: error, file untouched
      before:=Files.LoadAsString('vfs/fix.ctl');
      ctlSetStr('fix.ctl:\Bad','a'#10'b');
      msg:='';
      try SaveControlFile(h,fmText); except on e:Exception do msg:=e.Message; end;
      after:=Files.LoadAsString('vfs/fix.ctl');
      Check((Pos(Files.FixName('vfs/fix.ctl'),msg)>0) and (Pos('Bad',msg)>0),'ctl: save error names the file and the key: '+msg);
      Check(before=after,'ctl: failed save leaves the file intact');
      ctlDeleteKey('fix.ctl:\Bad');

      // Another file with the same name is a conflict, the loaded one stays intact
      Files.Save('vfs/other/fix.ctl','Width 1'#13#10,false);
      msg:='';
      try UseControlFile('vfs/other/fix.ctl'); except on e:Exception do msg:=e.Message; end;
      Check(Pos(Files.FixName('vfs/fix.ctl'),msg)>0,'ctl: name conflict is an error: '+msg);
      Check(ctlGetInt('fix.ctl:\Width',0)=800,'ctl: loaded file is not shadowed');

      // Saving doesn't touch the global random generator either
      RandSeed:=12345;
      SaveControlFile(h,fmBinary);
      Check(RandSeed=12345,'ctl: save keeps RandSeed');
      FreeControlFile(h);
    end;
    Check({$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator=',','ctl: decimal separator is not changed');
  finally
    {$IFDEF FPC}DefaultFormatSettings.{$ELSE}FormatSettings.{$ENDIF}DecimalSeparator:=sep;
    Files.SetProvider(prev);
  end;
  EndTest;
end;

begin
  try
    Cleanup;

    TestSaveLoad;
    TestPartialRead;
    TestBlockIO;
    TestHandleIO;
    TestOverwrite;
    TestOpenModes;
    TestFileOps;
    TestGetFileInfo;
    TestFolderOps;
    TestWriteCreatesFolder;
    TestListFiles;
    TestFind;
    TestUnicodeNames;
    TestPathUtils;
    TestNameParts;
    TestProviderChain;
    TestControlFileErrors;
    TestControlFileTypes;
    TestControlFileFixes;

    Cleanup;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',e.Message);
      ExitCode:=255;
    end;
  end;
  Cleanup;
  if IsDebuggerPresent then readln;
end.
