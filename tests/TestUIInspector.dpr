// Tests of the UI inspector core (Apus.Engine.UIInspector) on elements outside any
// window: the element tree, the field rows, writing fields, the selection
{$APPTYPE CONSOLE}
program TestUIInspector;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Strings,
  Apus.Conv,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UIInspector;

{$I ..\Base\tests\Test.inc}

var
  root:TUIElement;
  panel:TUIElement;
  btn:TUIButton;
  lbl:TUILabel;

function RowsText(const rows:TTreeRows):String8;
 var
  i:integer;
 begin
  result:='';
  for i:=0 to high(rows) do begin
   if result<>'' then result:=result+'|';
   result:=result+Conv.ToStr(rows[i].depth)+':'+rows[i].text;
  end;
 end;

function FindRow(const rows:TFieldRows;const name:String8):integer;
 begin
  for result:=0 to high(rows) do
   if rows[result].name=name then exit;
  result:=-1;
 end;

procedure TestTree;
 var
  rows:TTreeRows;
 begin
  StartTest('Element tree');
  rows:=BuildTree([root]);
  Check(RowsText(rows)='0:TUIElement ''Root''','collapsed root: '+RowsText(rows));
  Check(rows[0].hasChildren and not rows[0].expanded,'root has children, collapsed');
  SetExpanded(root,true);
  rows:=BuildTree([root]);
  Check(RowsText(rows)='0:TUIElement ''Root''|1:TUIElement ''Panel''|1:TUILabel ''Label'' [hidden]',
    'expanded root: '+RowsText(rows));
  SetExpanded(panel,true);
  rows:=BuildTree([root]);
  Check(RowsText(rows)='0:TUIElement ''Root''|1:TUIElement ''Panel''|2:TUIButton ''Btn'' [disabled]|1:TUILabel ''Label'' [hidden]',
    'expanded panel: '+RowsText(rows));
  SetExpanded(panel,false);
  Check(length(BuildTree([root]))=3,'collapsed again');
  Check(FindInTree([root],btn) and not FindInTree([panel],lbl),'element is found in its tree only');
  EndTest;
 end;

procedure TestFields;
 var
  rows:TFieldRows;
  i:integer;
 begin
  StartTest('Field rows');
  rows:=ReadFields(btn);
  i:=FindRow(rows,'caption');
  Check((i>=0) and (rows[i].value='OK') and (rows[i].edit=TFieldEdit.Text),'caption: text');
  i:=FindRow(rows,'enabled');
  Check((i>=0) and (rows[i].value='false') and (rows[i].edit=TFieldEdit.Bool),'enabled: bool');
  i:=FindRow(rows,'parentclip');
  Check((i>=0) and (rows[i].edit=TFieldEdit.Bool),'inverted flag is a bool too');
  i:=FindRow(rows,'parent');
  Check((i>=0) and (rows[i].edit=TFieldEdit.Ref) and (rows[i].ref=panel),'parent: reference to the panel');
  i:=FindRow(rows,'children');
  Check((i>=0) and (rows[i].edit=TFieldEdit.ReadOnly),'children: read-only');
  i:=FindRow(rows,'signals');
  Check((i>=0) and (rows[i].edit=TFieldEdit.Enum),'signals: enum');
  Check(FindRow(rows,'pressed')>=0,'button fields are listed');
  Check(FindRow(ReadFields(lbl),'pressed')<0,'label has no button fields');
  i:=FindRow(ReadFields(lbl),'align');
  Check(i>=0,'label has align');
  EndTest;
 end;

procedure TestWrite;
 var
  failed:boolean;
 begin
  StartTest('Writing fields');
  WriteField(btn,'caption','Cancel');
  Check(btn.caption='Cancel','caption written');
  WriteField(btn,'enabled','true');
  Check(btn.flags.enabled,'bool written');
  failed:=false;
  try
   WriteField(btn,'nosuchfield','1');
  except
   on EWarning do failed:=true;
  end;
  Check(failed,'unknown field: EWarning');
  failed:=false;
  try
   WriteField(btn,'visible','maybe');
  except
   on EWarning do failed:=true;
  end;
  Check(failed,'bad value: EWarning');
  EndTest;
 end;

procedure TestSelection;
 var
  e:TUIElement;
 begin
  StartTest('Selection');
  Check(SelectedElement=nil,'nothing selected at start');
  SetSelected(btn);
  Check(SelectedElement=btn,'selected');
  e:=HoldSelected;
  Check(e=btn,'held for another thread');
  if e<>nil then e.Release;
  SetSelected(lbl);
  Check(SelectedElement=lbl,'another element selected');
  lbl.Remove;
  Check(SelectedElement=nil,'removed element is not selected');
  Check(HoldSelected=nil,'removed element is not held');
  SetSelected(nil);
  Check(SelectedElement=nil,'selection cleared');
  EndTest;
 end;

begin
  root:=TUIElement.Create(200,200,nil,'Root');
  panel:=TUIElement.Create(100,100,root,'Panel');
  btn:=TUIButton.Create(50,20,panel,'Btn');
  btn.caption:='OK';
  btn.flags.enabled:=false;
  lbl:=TUILabel.Create(50,20,root,'Label');
  lbl.flags.visible:=false;
  TestTree;
  TestFields;
  TestWrite;
  TestSelection;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
