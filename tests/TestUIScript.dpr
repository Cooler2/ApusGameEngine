// Tests of the UI element fields published for the console (Apus.Engine.UIScript):
// each field is written by a console command and read back from the element itself
{$APPTYPE CONSOLE}
program TestUIScript;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Strings,
  Apus.Publics,
  Apus.Engine.CmdProc,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UIScript;

{$I ..\Base\tests\Test.inc}

var
  box:TUIElement;
  btn:TUIButton;
  edit:TUIEditBox;
  img:TUIImage;
  list:TUIListBox;
  bar:TUIScrollBar;

// Value of a published variable as the console shows it ('?' operator)
function Ask(const name:String8):String8;
 var
  v:pointer;
  vc:TVarClass;
 begin
  v:=FindVar(name,vc);
  if (v=nil) or (vc=nil) then exit('<undefined>');
  result:=vc.GetValue(v);
 end;

function Near(a,b:single):boolean;
 begin
  result:=abs(a-b)<0.001;
 end;

procedure TestStrings;
 begin
  StartTest('String fields');
  ExecCmd('TBtn.caption="Hello"');
  Check(btn.caption='Hello','caption: '+btn.caption);
  ExecCmd('TBtn.hint="Привет"');
  Check(btn.hint='Привет','hint keeps UTF-8: '+btn.hint);
  ExecCmd('TImg.src="res/pic"');
  Check(img.src='res/pic','image src: '+img.src);
  ExecCmd('TEdit.text="Текст"');
  Check(UTF8.Encode(edit.realText)='Текст','edit box text'); // String32 is an array: = compares pointers
  Check(Ask('TEdit.text')='Текст','edit box text reads back: '+Ask('TEdit.text'));
  EndTest;
 end;

procedure TestNumbers;
 begin
  StartTest('Numeric fields');
  btn.cursor:=-1; // all bits set: a write of the low half only would leave the high half
  ExecCmd('TBtn.cursor=5');
  Check(btn.cursor=5,'cursor is written whole');
  ExecCmd('TBox.width=12.5');
  Check(Near(box.size.x,12.5),'width takes a fraction (decimal separator ","): '+Ask('TBox.width'));
  ExecCmd('TList.lineheight=17');
  Check(Near(list.lineHeight,17),'list line height');
  ExecCmd('TBar.min=2');
  Check(Near(bar.min,2),'scroll bar min');
  ExecCmd('TBar.max=50');
  Check(Near(bar.max,50),'scroll bar max');
  ExecCmd('TBar.pagesize=10');
  Check(Near(bar.pagesize,10),'scroll bar page size');
  ExecCmd('TBox.anchors.x2=0.5');
  Check(Near(box.anchors.x2,0.5),'anchors field');
  EndTest;
 end;

procedure TestComputed;
 begin
  StartTest('Computed and flag fields');
  box.Resize(100,40);
  Check(Ask('TBox.clientheight')='40','client height: '+Ask('TBox.clientheight'));
  ExecCmd('TBox.clipchildren=false');
  Check(box.flags.dontClipChildren,'clipchildren=false: children are not clipped');
  ExecCmd('TBox.parentclip=false');
  Check(box.flags.noParentClip,'parentclip=false: not clipped by the parent');
  ExecCmd('TBox.color=$FF112233');
  Check(box.style.GetValue('color')='$FF112233','color: '+box.style.GetValue('color'));
  ExecCmd('TBox.font=Arial');
  Check(box.style.GetValue('font')='Arial','font goes to the style');
  Check(Ask('TBox.children')='[0:TUIButton(''TBtn'')]','children: '+Ask('TBox.children'));
  EndTest;
 end;

begin
  FormatSettings.DecimalSeparator:=','; // as on a Russian Windows
  box:=TUIElement.Create(100,40,nil,'TBox');
  btn:=TUIButton.Create(50,20,box,'TBtn');
  edit:=TUIEditBox.Create(100,20,nil,'TEdit');
  img:=TUIImage.Create(10,10,nil,'TImg','');
  list:=TUIListBox.Create(100,100,nil,'TList',20);
  bar:=TUIScrollBar.Create(10,100,nil,'TBar');
  TestStrings;
  TestNumbers;
  TestComputed;
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
