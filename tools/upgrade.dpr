program upgrade;
{$APPTYPE CONSOLE}

{$R *.res}

uses
  Apus.Common, System.SysUtils;

var
 items:array[1..1000,0..1] of String;
 iCount:integer;

procedure LoadConfig;
 var
  launchPath,name:string;
  config:string;
  lines,line:StringArr;
  i:integer;
 begin
  launchPath:=ExtractFilePath(ParamStr(0));
  name:='engine4';
  if ParamStr(1)<>'' then name:=ParamStr(1);
  name:=launchPath+name+'.upgrade';
  config:=LoadFileAsString(name);
  iCount:=0;
  lines:=split(#13#10,config);
  for i:=0 to high(lines) do begin
   line:=split('->',lines[i]);
   if length(line)<>2 then continue;
   inc(iCount);
   items[iCount,0]:=Chop(line[0]);
   items[iCount,1]:=Chop(line[1]);
  end;
  Writeln('Config loaded: ',iCount,' items from '+name);
 end;

procedure ProcessFile(fName:string);
 var
  data,bakName:string8;
  i,p,start,pSelf:integer;
  oldStr,newStr:string8;
 begin
  data:=LoadFileAsString(fName);
  for i:=1 to iCount do begin
   start:=1;
   oldStr:=items[i,0];
   newStr:=items[i,1];
   pSelf:=pos(oldStr,newStr);
   repeat
    p:=PosFrom(oldStr,data,start,true);
    if p<=0 then break;
    // substring found
    start:=p+1;
    if data[p-1] in ['A'..'Z','a'..'z'] then continue; // part of another identifier?
    if pSelf>0 then
     if SameText(Copy(data,p-pSelf+1,length(newStr)),newStr) then continue;
    Delete(data,p,length(oldStr));
    Insert(newStr,data,p);
    inc(start,length(newStr)-1);
   until false;
  end;
  bakName:=ChangeFileExt(fName,'.bak');
  RenameFile(fName,bakName);
  SaveFile(fName,data);
 end;

procedure ProcessFiles;
 var
  files:StringArr;
  fName:string;
  cnt:integer;
 begin
  cnt:=0;
  files:=ListFiles(GetCurrentDir,'*.pas',true);
  for fName in files do begin
   write('Processing file: ',fName);
   inc(cnt);
   ProcessFile(fName);
   writeln(' done!');
  end;
  writeln(cnt,' files processed');
 end;

begin
 try
  LoadConfig;
  ProcessFiles;
 except
   on E: Exception do
     Writeln(E.ClassName, ': ', E.Message);
 end;
end.
