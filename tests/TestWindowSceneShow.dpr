// Show and hide of a window scene (TShowWindowEffect): a show requested while the scene still
// hides starts when the hide ends, a hide then calls it off; a window that is not drawn ends
// the effects at once; an extra window plays them too. onBeforeShow comes before the
// activation, onShow when the state is complete (active, shown, on the modal stack). Requires a GL window: the smoke suites only compile it, run it locally
// (-ROBOT=VIRTUAL keeps the window under the active one).
{$APPTYPE CONSOLE}
program TestWindowSceneShow;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,Types,Apus.Core,Apus.EventMan,
  Apus.Engine.API,Apus.Engine.Types,Apus.Engine.GameApp,Apus.Engine.Scene,
  Apus.Engine.UIScene,Apus.Engine.UITypes,Apus.Engine.UIWidgets,Apus.Engine.SceneEffects;

{$I ..\Base\tests\Test.inc}

const
  FRAME_LIMIT=300; // a stage that waits longer fails

type
  TDriverScene=class(TGameScene)
    function Process:boolean; override;
    procedure Render; override;
  end;

  TTestDialog=class(TUIScene)
    beforeShows,shows:integer;
    beforeActive:boolean; // the scene was active at onBeforeShow
    shownActive,shownVisible,shownModal:boolean; // at the last onShow
    procedure onBeforeShow; override;
    procedure onShow; override;
  end;

  TTestApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure CreateScenes; override;
  end;

  TStage=(stStart,stShowWait,stPendingWait,stCancelWait,stFinish,stExtra,stExtraWait,stDone);

var
  driver:TDriverScene;
  dlg:TTestDialog;
  extraDlg:TUIScene; // in an extra window
  stage:TStage;
  stageFrames:integer;
  signalled:boolean;       // ENGINE\EffectDone came for dlg
  effectAtSignal:TObject;  // dlg.effect when the signal came

function IsModal:boolean;
begin
  result:=window.modal.element=dlg.UI;
end;

function Settled:boolean;
begin
  result:=dlg.effect=nil;
end;

procedure TTestDialog.onBeforeShow;
begin
  inc(beforeShows);
  beforeActive:=IsActive or UI.flags.visible;
end;

procedure TTestDialog.onShow;
begin
  inc(shows);
  shownActive:=IsActive;
  shownVisible:=UI.flags.visible;
  shownModal:=IsModal;
end;

procedure EffectDone(event:TEventStr;tag:TTag);
begin
  if TGameScene(tag)<>dlg then exit;
  signalled:=true;
  effectAtSignal:=dlg.effect;
end;

procedure Next(st:TStage);
begin
  stage:=st;
  stageFrames:=0;
end;

// Wait for the effects of dlg to end, false - the stage failed by time
function Waiting(const name:string):boolean;
begin
  result:=not Settled;
  if result and (stageFrames>FRAME_LIMIT) then begin
    Check(false,name+': the effects did not end in '+IntToStr(FRAME_LIMIT)+' frames');
    result:=false;
  end;
end;

procedure TestFinish;
begin
  StartTest('A window that is not drawn ends the effects at once');
  TShowWindowEffect.Create(dlg,100000,sweShowModal,1);
  window.ProcessEffects(0,true);
  Check(Settled and dlg.IsActive and IsModal,'the show did not end at once');

  TShowWindowEffect.Create(dlg,100000,sweHide,1);
  TShowWindowEffect.Create(dlg,100000,sweShowModal,1); // waits for the hide
  window.ProcessEffects(0,true);
  Check((dlg.effect is TShowWindowEffect) and dlg.activated and IsModal,
    'the end of the hide did not start the requested show');
  window.ProcessEffects(0,true);
  Check(Settled and dlg.IsActive,'the requested show did not end at once');

  TShowWindowEffect.Create(dlg,100000,sweHide,1);
  window.ProcessEffects(0,true);
  Check(Settled and not dlg.IsActive and not IsModal,'the hide did not end at once');
  EndTest;

  StartTest('SetStatus: onShow after the scene class applied the status');
  dlg.shows:=0;
  dlg.SetStatus(ssActive);
  Check((dlg.shows=1) and dlg.shownActive and dlg.shownVisible and not dlg.shownModal,
    'onShow did not come after the UI was shown');
  dlg.SetStatus(ssActive);
  Check(dlg.shows=1,'onShow came again without a change');
  dlg.SetStatus(ssFrozen);
  EndTest;
end;

procedure TDriverScene.Render;
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(stageFrames);
  try
    case stage of
      stStart:if stageFrames>=3 then begin
        StartTest('Show, then hide and show again while the hide plays');
        TShowWindowEffect.Create(dlg,100,sweShowModal,1);
        Check(dlg.activated and IsModal and (dlg.effect<>nil),'the show did not take the scene state at once');
        Check((dlg.beforeShows=1) and not dlg.beforeActive,'onBeforeShow did not come before the activation');
        Check((dlg.shows=1) and dlg.shownActive and dlg.shownVisible and dlg.shownModal,
          'onShow did not come once with the state complete');
        Next(stShowWait);
      end;
      stShowWait:if not Waiting('show') then begin
        Check(dlg.IsActive and IsModal,'the scene is not shown after the show');
        signalled:=false;
        TShowWindowEffect.Create(dlg,150,sweHide,1);
        Check(not dlg.activated and not IsModal,'the hide did not take the scene state at once');
        TShowWindowEffect.Create(dlg,100,sweShowModal,1);
        Check(dlg.IsActive and not dlg.activated and not IsModal,'the show did not wait for the hide');
        Check(dlg.shows=1,'onShow came before the hide ended');
        Next(stPendingWait);
      end;
      stPendingWait:if not Waiting('show after hide') then begin
        Check(dlg.IsActive and dlg.activated and IsModal,'the show requested while hiding was lost');
        Check((dlg.shows=2) and dlg.shownModal,'onShow of the waiting show did not come with the state complete');
        Check(signalled and (effectAtSignal=nil),'ENGINE\EffectDone came while the scene still had the effect');
        EndTest;

        StartTest('A hide calls off the show requested while hiding');
        TShowWindowEffect.Create(dlg,150,sweHide,1);
        TShowWindowEffect.Create(dlg,100,sweShowModal,1);
        TShowWindowEffect.Create(dlg,100,sweHide,1);
        Next(stCancelWait);
      end;
      stCancelWait:if not Waiting('called off show') then begin
        Check(not dlg.IsActive and not IsModal,'the called off show was played');
        EndTest;
        Next(stFinish);
      end;
      stFinish:begin
        TestFinish;
        Next(stExtra);
      end;
      stExtraWait:if extraDlg.effect=nil then begin
        Check(extraDlg.IsActive,'the scene of the extra window is not shown');
        EndTest;
        Next(stDone);
      end else
      if stageFrames>FRAME_LIMIT then begin
        Check(false,'the effect in the extra window did not end in '+IntToStr(FRAME_LIMIT)+' frames');
        EndTest;
        Next(stDone);
      end;
      stDone:if stageFrames=2 then Signal('Engine\Cmd\Exit');
    end;
  except
    on e:Exception do begin
      writeln('EXCEPTION: ',e.Message);
      inc(testsFailed);
      Next(stDone);
    end;
  end;
end;

// The extra window is created outside the drawing of the main one
function TDriverScene.Process:boolean;
var
  wnd:TWindow;
begin
  result:=inherited;
  if stage<>stExtra then exit;
  StartTest('An extra window plays the effects');
  wnd:=game.AddWindow('Extra',240,160,'ShowTestExtra');
  extraDlg:=TUIScene.Create('ShowTestExtraDialog',false,wnd);
  TUIWindow.Create(120,80,false,extraDlg.UI,'ShowTestExtraDialog\Frame','Dialog');
  TShowWindowEffect.Create(extraDlg,100,sweShow,1);
  Check(extraDlg.effect<>nil,'the show in the extra window did not start');
  Next(stExtraWait);
end;

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestWindowSceneShow';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,200);
end;

procedure TTestApp.CreateScenes;
begin
  inherited;
  driver:=TDriverScene.Create('ShowTestDriver',true,window);
  driver.SetStatus(ssActive);
  dlg:=TTestDialog.Create('ShowTestDialog',false,window);
  TUIWindow.Create(120,80,false,dlg.UI,'ShowTestDialog\Frame','Dialog');
  SetEventHandler('ENGINE\EffectDone',EffectDone,emInstant);
end;

var
  app:TTestApp;
begin
  app:=TTestApp.Create;
  try app.Prepare;app.Run;finally app.Free;end;
  if testsFailed=0 then writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
