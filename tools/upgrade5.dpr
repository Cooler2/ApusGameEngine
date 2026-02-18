// Engine4 -> Engine5 code upgrader
// Performs automated replacements, uses clause modifications, and TODO markers
//
// Usage: upgrade5 [options] file1.pas [file2.pas ...]
//   --config=name  - config name without extension (default: engine5)
//   --dry-run      - show changes without modifying files
//   --verbose      - show each replacement
//   file.pas       - files to process (supports wildcards: *.pas)
//
// Config format:
//   // comment
//   -uses UnitName                    - remove unit from uses
//   OldName -> NewName               - whole-word replacement
//   OldName -> NewName [UnitName]    - replacement + auto-add unit to uses
//   OldName() -> NewName [Unit]      - same, but only match function calls (require '(' after)
//   OldName -> ?TODO comment         - insert TODO marker
//   OldName -> ?comment [UnitName]   - TODO marker + auto-add unit
//   OldName ->                       - delete OldName
//
// Two-pass processing:
//   Pass 1: apply all -uses removals and text replacements
//   Pass 2: add required units based on which replacements actually fired
//           (interface or implementation, depending on where replacement occurred)
//
// Copyright (C) 2026 Apus Software (BSD-3)
program upgrade5;
{$APPTYPE CONSOLE}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  SysUtils, Classes;

const
  VERSION = '1.1';

type
  TActionKind = (akReplace, akTodo, akRemoveUses);

  TRule = record
    action:TActionKind;
    oldStr:string;
    newStr:string;
    reqUnit:string; // unit required for this replacement (empty = none)
    callOnly:boolean; // true = match only when followed by '(' (function call)
  end;

var
  rules:array of TRule;
  ruleCount:integer;
  dryRun:boolean;
  verbose:boolean;
  totalFiles:integer;
  changedFiles:integer;
  totalChanges:integer;

// --- Helpers ---

function IsWordChar(c:AnsiChar):boolean; inline;
begin
  result:=c in ['A'..'Z','a'..'z','0'..'9','_'];
end;

function IsWordBoundary(const data:AnsiString; pos,len:integer):boolean;
begin
  if (pos>1) and IsWordChar(data[pos-1]) then exit(false);
  if (pos+len<=length(data)) and IsWordChar(data[pos+len]) then exit(false);
  result:=true;
end;

function PosIFrom(const substr,str:AnsiString; start:integer):integer;
var
  i,j,subLen,strLen:integer;
begin
  subLen:=length(substr);
  strLen:=length(str);
  for i:=start to strLen-subLen+1 do begin
    j:=1;
    while (j<=subLen) and (UpCase(str[i+j-1])=UpCase(substr[j])) do
      inc(j);
    if j>subLen then exit(i);
  end;
  result:=0;
end;

function TrimStr(const s:string):string;
var
  i,j:integer;
begin
  i:=1;
  j:=length(s);
  while (i<=j) and (s[i]<=' ') do inc(i);
  while (j>=i) and (s[j]<=' ') do dec(j);
  result:=Copy(s,i,j-i+1);
end;

function SameTextA(const a,b:AnsiString):boolean;
var
  i:integer;
begin
  if length(a)<>length(b) then exit(false);
  for i:=1 to length(a) do
    if UpCase(a[i])<>UpCase(b[i]) then exit(false);
  result:=true;
end;

// --- File I/O (preserves BOM, line endings, encoding) ---

function LoadFile(const fileName:string):AnsiString;
var
  fs:TFileStream;
begin
  fs:=TFileStream.Create(fileName,fmOpenRead or fmShareDenyNone);
  try
    SetLength(result,fs.Size);
    if fs.Size>0 then
      fs.Read(result[1],fs.Size);
  finally
    fs.Free;
  end;
end;

procedure SaveFile(const fileName:string; const data:AnsiString);
var
  fs:TFileStream;
begin
  fs:=TFileStream.Create(fileName,fmCreate);
  try
    if length(data)>0 then
      fs.Write(data[1],length(data));
  finally
    fs.Free;
  end;
end;

// --- Config loading ---

procedure AddRule(action:TActionKind; const old,new_,req:string; call:boolean=false);
begin
  if ruleCount>=length(rules) then
    SetLength(rules,ruleCount+200);
  rules[ruleCount].action:=action;
  rules[ruleCount].oldStr:=old;
  rules[ruleCount].newStr:=new_;
  rules[ruleCount].reqUnit:=req;
  rules[ruleCount].callOnly:=call;
  inc(ruleCount);
end;

// Extract [UnitName] from the end of a string, return the remainder
function ExtractReqUnit(const s:string; out unitName:string):string;
var
  p1,p2:integer;
begin
  unitName:='';
  result:=s;
  p2:=length(s);
  if (p2>0) and (s[p2]=']') then begin
    p1:=p2-1;
    while (p1>0) and (s[p1]<>'[') do dec(p1);
    if p1>0 then begin
      unitName:=TrimStr(Copy(s,p1+1,p2-p1-1));
      result:=TrimStr(Copy(s,1,p1-1));
    end;
  end;
end;

procedure LoadConfig(const fileName:string);
var
  lines:TStringList;
  i,p:integer;
  line,left,right,reqUnit:string;
  isCall:boolean;
begin
  lines:=TStringList.Create;
  try
    lines.LoadFromFile(fileName);
    for i:=0 to lines.Count-1 do begin
      line:=TrimStr(lines[i]);
      if (line='') or (Copy(line,1,2)='//') then continue;
      // -uses UnitName
      if Copy(line,1,6)='-uses ' then begin
        AddRule(akRemoveUses,TrimStr(Copy(line,7,MaxInt)),'','');
        continue;
      end;
      // old() -> new  (call-only) or  old -> new  (any context)
      isCall:=false;
      p:=Pos('() -> ',line);
      if p>0 then
        isCall:=true
      else
        p:=Pos(' -> ',line);
      if p>0 then begin
        left:=TrimStr(Copy(line,1,p-1));
        if isCall then
          right:=TrimStr(Copy(line,p+6,MaxInt))
        else
          right:=TrimStr(Copy(line,p+4,MaxInt));
        if left='' then continue;
        right:=ExtractReqUnit(right,reqUnit);
        if (right<>'') and (right[1]='?') then
          AddRule(akTodo,left,Copy(right,2,MaxInt),reqUnit,isCall)
        else
          AddRule(akReplace,left,right,reqUnit,isCall);
        continue;
      end;
    end;
    WriteLn('Loaded ',ruleCount,' rules from ',fileName);
  finally
    lines.Free;
  end;
end;

// --- Uses clause manipulation ---

// Find a uses clause starting from `from`.
// Returns position of 'uses' keyword and the closing ';'
function FindUsesClause(const data:AnsiString; from:integer;
  out kwPos,semiPos:integer):boolean;
var
  p,len:integer;
begin
  result:=false;
  len:=length(data);
  p:=PosIFrom('uses',data,from);
  while p>0 do begin
    if IsWordBoundary(data,p,4) then begin
      kwPos:=p;
      p:=p+4;
      while p<=len do begin
        case data[p] of
          ';': begin
            semiPos:=p;
            exit(true);
          end;
          '''': begin
            inc(p);
            while (p<=len) and (data[p]<>'''') do inc(p);
          end;
          '{': begin
            inc(p);
            while (p<=len) and (data[p]<>'}') do inc(p);
          end;
          '/': if (p<len) and (data[p+1]='/') then begin
            inc(p);
            while (p<=len) and not (data[p] in [#10,#13]) do inc(p);
          end;
          '(': if (p<len) and (data[p+1]='*') then begin
            inc(p,2);
            while (p<len) and not ((data[p]='*') and (data[p+1]=')')) do inc(p);
            inc(p);
          end;
        end;
        inc(p);
      end;
    end;
    p:=PosIFrom('uses',data,p+1);
  end;
end;

// Check if unitName is already in any uses clause
function IsUnitInUses(const data:AnsiString; const unitName:AnsiString):boolean;
var
  kwPos,semiPos,uPos,searchFrom:integer;
  clause:AnsiString;
begin
  result:=false;
  searchFrom:=1;
  while FindUsesClause(data,searchFrom,kwPos,semiPos) do begin
    clause:=Copy(data,kwPos,semiPos-kwPos+1);
    uPos:=PosIFrom(unitName,clause,1);
    while uPos>0 do begin
      if IsWordBoundary(clause,uPos,length(unitName)) then
        exit(true);
      uPos:=PosIFrom(unitName,clause,uPos+1);
    end;
    searchFrom:=semiPos+1;
  end;
end;

function RemoveUnitFromUses(var data:AnsiString; const unitName:AnsiString):integer;
var
  kwPos,semiPos,uPos,commaLeft,commaRight,removeStart,removeEnd:integer;
  searchFrom:integer;
  clauseText:AnsiString;
begin
  result:=0;
  searchFrom:=1;
  while FindUsesClause(data,searchFrom,kwPos,semiPos) do begin
    clauseText:=Copy(data,kwPos,semiPos-kwPos+1);
    uPos:=PosIFrom(unitName,clauseText,1);
    while uPos>0 do begin
      if IsWordBoundary(clauseText,uPos,length(unitName)) then begin
        uPos:=kwPos+uPos-1; // absolute position
        commaLeft:=uPos-1;
        while (commaLeft>kwPos+3) and (data[commaLeft] in [' ',#9,#10,#13]) do
          dec(commaLeft);
        commaRight:=uPos+length(unitName);
        while (commaRight<semiPos) and (data[commaRight] in [' ',#9,#10,#13]) do
          inc(commaRight);

        if (commaLeft>kwPos+3) and (data[commaLeft]=',') then begin
          removeStart:=commaLeft;
          removeEnd:=uPos+length(unitName)-1;
        end else if (commaRight<semiPos) and (data[commaRight]=',') then begin
          removeStart:=uPos;
          removeEnd:=commaRight;
          while (removeEnd+1<semiPos) and (data[removeEnd+1] in [' ',#9]) do
            inc(removeEnd);
        end else begin
          removeStart:=kwPos;
          removeEnd:=semiPos;
          while (removeEnd+1<=length(data)) and (data[removeEnd+1] in [' ',#9,#10,#13]) do
            inc(removeEnd);
        end;

        Delete(data,removeStart,removeEnd-removeStart+1);
        semiPos:=semiPos-(removeEnd-removeStart+1);
        inc(result);
        break;
      end;
      uPos:=PosIFrom(unitName,clauseText,uPos+1);
    end;
    searchFrom:=semiPos+1;
    if searchFrom>length(data) then break;
  end;
end;

function AddUnitToUses(var data:AnsiString; const unitName:AnsiString;
  implSection:boolean):integer;
var
  kwPos,semiPos,searchFrom,implPos:integer;
begin
  result:=0;
  if IsUnitInUses(data,unitName) then exit;

  searchFrom:=1;
  if implSection then begin
    implPos:=PosIFrom('implementation',data,1);
    if implPos<=0 then exit;
    searchFrom:=implPos;
  end;

  if FindUsesClause(data,searchFrom,kwPos,semiPos) then begin
    Insert(','+#10+'  '+unitName,data,semiPos);
    inc(result);
  end;
end;

// --- Find implementation boundary ---

function FindImplPos(const data:AnsiString):integer;
var
  p:integer;
begin
  p:=PosIFrom('implementation',data,1);
  while p>0 do begin
    if IsWordBoundary(data,p,14) then exit(p);
    p:=PosIFrom('implementation',data,p+1);
  end;
  result:=MaxInt; // no implementation section (e.g. .dpr)
end;

// --- Text replacements ---

// Apply replacements for a single rule, tracking positions for uses resolution.
// implPos is the position of 'implementation' keyword (updated as text shifts).
// If rule has reqUnit, adds it to ifaceUnits or implUnits depending on where
// the replacement occurred.
function ApplyReplacements(var data:AnsiString; const rule:TRule;
  var implPos:integer; ifaceUnits,implUnits:TStringList):integer;
var
  p,k,start,pSelf,delta:integer;
  marker:AnsiString;
begin
  result:=0;
  start:=1;
  pSelf:=PosIFrom(rule.oldStr,rule.newStr,1);

  repeat
    p:=PosIFrom(rule.oldStr,data,start);
    if p<=0 then break;
    start:=p+1;
    if not IsWordBoundary(data,p,length(rule.oldStr)) then continue;
    // call-only rules: require '(' after identifier (skip whitespace)
    if rule.callOnly then begin
      k:=p+length(rule.oldStr);
      while (k<=length(data)) and (data[k] in [' ',#9]) do inc(k);
      if (k>length(data)) or (data[k]<>'(') then continue;
    end;
    if pSelf>0 then begin
      if (p>=pSelf) and
         SameTextA(Copy(data,p-pSelf+1,length(rule.newStr)),rule.newStr) then
        continue;
    end;

    delta:=0;
    case rule.action of
      akReplace: begin
        Delete(data,p,length(rule.oldStr));
        Insert(rule.newStr,data,p);
        delta:=length(rule.newStr)-length(rule.oldStr);
        inc(start,length(rule.newStr)-1);
        inc(result);
      end;
      akTodo: begin
        marker:=' {TODO: '+rule.newStr+'}';
        Insert(marker,data,p+length(rule.oldStr));
        delta:=length(marker);
        inc(start,length(rule.oldStr)+length(marker));
        inc(result);
      end;
    end;

    // track required unit
    if (rule.reqUnit<>'') and (delta<>0) then begin
      if p<implPos then
        ifaceUnits.Add(rule.reqUnit)
      else
        implUnits.Add(rule.reqUnit);
    end;
    // adjust implementation position
    if (delta<>0) and (p<implPos) then
      inc(implPos,delta);
  until false;
end;

// --- File processing ---

procedure ExpandWildcard(const pattern:string; list:TStringList);
var
  sr:TSearchRec;
  dir:string;
begin
  dir:=ExtractFilePath(pattern);
  if FindFirst(pattern,faAnyFile and not faDirectory,sr)=0 then begin
    repeat
      list.Add(dir+sr.Name);
    until FindNext(sr)<>0;
    FindClose(sr);
  end;
end;

procedure ProcessFile(const fileName:string);
var
  data:AnsiString;
  i,changes,fileChanges,implPos:integer;
  bakName:string;
  ifaceUnits,implUnits:TStringList;
begin
  data:=LoadFile(fileName);
  fileChanges:=0;
  implPos:=FindImplPos(data);

  ifaceUnits:=TStringList.Create;
  implUnits:=TStringList.Create;
  ifaceUnits.Sorted:=true;
  ifaceUnits.Duplicates:=dupIgnore;
  implUnits.Sorted:=true;
  implUnits.Duplicates:=dupIgnore;
  try
    // Pass 1a: remove units from uses
    for i:=0 to ruleCount-1 do
      if rules[i].action=akRemoveUses then begin
        changes:=RemoveUnitFromUses(data,rules[i].oldStr);
        if changes>0 then begin
          implPos:=FindImplPos(data); // recalculate after uses change
          if verbose then
            WriteLn('  -uses ',rules[i].oldStr);
          inc(fileChanges,changes);
        end;
      end;

    // Pass 1b: text replacements (track required units)
    for i:=0 to ruleCount-1 do
      if rules[i].action in [akReplace,akTodo] then begin
        changes:=ApplyReplacements(data,rules[i],implPos,ifaceUnits,implUnits);
        if (changes>0) and verbose then
          WriteLn('  ',rules[i].oldStr,' -> ',changes,' change(s)');
        inc(fileChanges,changes);
      end;

    // Pass 2: add required units to uses
    for i:=0 to ifaceUnits.Count-1 do begin
      changes:=AddUnitToUses(data,ifaceUnits[i],false);
      if changes>0 then begin
        if verbose then
          WriteLn('  +uses ',ifaceUnits[i],' (interface)');
        inc(fileChanges,changes);
      end;
    end;
    for i:=0 to implUnits.Count-1 do begin
      if IsUnitInUses(data,implUnits[i]) then continue; // already in interface
      changes:=AddUnitToUses(data,implUnits[i],true);
      if changes>0 then begin
        if verbose then
          WriteLn('  +uses ',implUnits[i],' (implementation)');
        inc(fileChanges,changes);
      end;
    end;

    if fileChanges>0 then begin
      inc(changedFiles);
      inc(totalChanges,fileChanges);
      WriteLn(fileName,': ',fileChanges,' change(s)');
      if not dryRun then begin
        bakName:=ChangeFileExt(fileName,'.bak');
        if FileExists(bakName) then
          DeleteFile(bakName);
        RenameFile(fileName,bakName);
        SaveFile(fileName,data);
      end;
    end;
  finally
    ifaceUnits.Free;
    implUnits.Free;
  end;
  inc(totalFiles);
end;

// --- Main ---

var
  configName,configFile,launchDir,arg:string;
  files:TStringList;
  i:integer;
begin
  try
    WriteLn('Engine Upgrade Tool v',VERSION);

    configName:='engine5';
    dryRun:=false;
    verbose:=false;
    files:=TStringList.Create;

    for i:=1 to ParamCount do begin
      arg:=ParamStr(i);
      if arg='--dry-run' then
        dryRun:=true
      else if arg='--verbose' then
        verbose:=true
      else if Copy(arg,1,9)='--config=' then
        configName:=Copy(arg,10,MaxInt)
      else if (length(arg)>0) and (arg[1]='-') then begin
        WriteLn('Unknown option: ',arg);
        halt(1);
      end else if (Pos('*',arg)>0) or (Pos('?',arg)>0) then
        ExpandWildcard(arg,files)
      else
        files.Add(arg);
    end;

    if files.Count=0 then begin
      WriteLn('Usage: upgrade5 [--config=name] [--dry-run] [--verbose] file.pas [...]');
      WriteLn('  Supports wildcards: upgrade5 *.pas');
      halt(0);
    end;

    launchDir:=ExtractFilePath(ParamStr(0));
    if FileExists(configName+'.upgrade') then
      configFile:=configName+'.upgrade'
    else if FileExists(launchDir+configName+'.upgrade') then
      configFile:=launchDir+configName+'.upgrade'
    else begin
      WriteLn('Config not found: ',configName,'.upgrade');
      halt(1);
    end;

    LoadConfig(configFile);
    if dryRun then
      WriteLn('[DRY RUN]');
    WriteLn;

    for i:=0 to files.Count-1 do begin
      if not FileExists(files[i]) then begin
        WriteLn('File not found: ',files[i]);
        continue;
      end;
      ProcessFile(files[i]);
    end;

    WriteLn;
    WriteLn('Done. Files: ',totalFiles,
      ', changed: ',changedFiles,
      ', replacements: ',totalChanges);
    files.Free;

  except
    on E:Exception do begin
      WriteLn('ERROR: ',E.ClassName,': ',E.Message);
      halt(1);
    end;
  end;
end.
