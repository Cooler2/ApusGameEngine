// Hint lifetime: TUIHint.Current / UI.CurrentHint must not dangle when the hint
// is destroyed through its parent (screen transitions destroy whole UI trees)
{$APPTYPE CONSOLE}
program TestUIHint;
uses
  SysUtils,
  Apus.Core,
  Apus.Engine.UITypes,
  Apus.Engine.UIWidgets,
  Apus.Engine.UI;

{$I ..\Base\tests\Test.inc}

procedure TestShowHint;
 var
  root:TUIElement;
 begin
  StartTest('ShowSimpleHint');
  root:=TUIElement.Create(800,600,nil,'root');
  ShowSimpleHint('first',root,10,10,1000);
  Check(CurrentHint<>nil,'hint is current');
  Check(CurrentHint.parent=root,'hint is attached to the parent');
  ShowSimpleHint('second',root,20,20,1000);
  Check(length(root.children)=1,'previous hint is freed');
  Check(CurrentHint.simpleText='second','new hint is current');
  root.Free;
  EndTest;
 end;

procedure TestParentDestroyed;
 var
  root:TUIElement;
 begin
  StartTest('Hint parent destroyed');
  root:=TUIElement.Create(800,600,nil,'root');
  ShowSimpleHint('hint',root,10,10,1000);
  root.Free; // frees the hint as a child
  Check(CurrentHint=nil,'no dangling current hint');
  root:=TUIElement.Create(800,600,nil,'root2');
  ShowSimpleHint('next',root,10,10,1000); // used to Free the dangling hint
  Check(CurrentHint.parent=root,'next hint works');
  root.Free;
  EndTest;
 end;

procedure TestHintFreed;
 var
  root:TUIElement;
 begin
  StartTest('Hint freed directly');
  root:=TUIElement.Create(800,600,nil,'root');
  ShowSimpleHint('hint',root,10,10,1000);
  CurrentHint.Free;
  Check(CurrentHint=nil,'current hint is reset');
  Check(length(root.children)=0,'hint is detached');
  root.Free;
  EndTest;
 end;

begin
  TestShowHint;
  TestParentDestroyed;
  TestHintFreed;
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
