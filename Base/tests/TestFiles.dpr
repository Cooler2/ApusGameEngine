{$APPTYPE CONSOLE}
program TestFiles;
uses
  SysUtils,
  Apus.Core,
  Apus.Threads,
  Apus.Files;

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
    TestListFiles;
    TestFind;
    TestPathUtils;

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
