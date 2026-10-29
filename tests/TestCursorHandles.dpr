// Native cursor handles are pointer-sized: SDL cursors are pointers, and a handle
// narrowed to the Unix THandle (32 bits) loses the high bits. The handle must survive
// the platform API, the cursor registry of TGame and DrawCursor across frames.
// Requires a real SDL display.
program TestCursorHandles;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  SDL2,
  Apus.Core,
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Types,
  Apus.Engine.GameApp,
  Apus.Engine.Game,
  Apus.Engine.Scene;

{$I ..\Base\tests\Test.inc}

type
  TProbeScene=class(TGameScene)
    frames:integer;
    procedure Render; override;
    function GetArea:TRect; override;
  end;

  TProbeApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure InitCursors; override;
    procedure CreateScenes; override;
  end;

var
  expected,original:TCursorHandle;
  ready:boolean;

procedure Initialized(event:TEventStr;tag:TTag);
begin
  ready:=true;
end;

procedure TProbeApp.SetupApplication;
begin
  inherited;
  appSetup.title:='SDL cursor handle test';
  requestBackend.platform:=spSDL;
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,240);
  windowSetup.systemCursor:=true;
  startupScenes.loader:=false;
  startupScenes.console:=false;
  startupScenes.tweaker:=false;
  startupScenes.message:=false;
  SetupFixedCanvas(320,240);
end;

procedure TProbeApp.InitCursors;
var
  sample:TCursorHandle;
begin
  inherited;
  Check(SizeOf(game.GetCursorForID(CursorID.Default))=SizeOf(pointer),'cursor API returns a pointer-sized handle');
  if SizeOf(game.GetCursorForID(CursorID.Default))<>SizeOf(pointer) then begin
    Signal('Engine\Cmd\Exit');
    exit;
  end;
  original:=game.GetCursorForID(CursorID.Default);
  expected:=TCursorHandle(SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND));
  Check(expected<>0,'SDL creates a real native cursor');
  if expected=0 then exit;
  if SizeOf(pointer)=8 then begin
    // high bits checked with a synthetic value: it never goes to SDL
    sample:=TCursorHandle($1234567887654321);
    game.RegisterCursor(9876,0,sample);
    Check(game.GetCursorForID(9876)=sample,'cursor registry preserves synthetic high pointer bits');
    game.RegisterCursor(9876,0,0);
  end;
  game.RegisterCursor(CursorID.Default,1,expected);
  game.ToggleCursor(CursorID.Default,true);
  Check(game.GetCursorForID(CursorID.Default)=expected,'cursor registry preserves the whole pointer');
  systemPlatform.SetCursor(expected);
  Check(TCursorHandle(SDL_GetCursor)=expected,'platform setter receives the whole pointer');
end;

procedure TProbeApp.CreateScenes;
var
  scene:TProbeScene;
begin
  SetEventHandler('GAMEAPP\Initialized',Initialized,emQueued);
  scene:=TProbeScene.Create('CursorProbe');
  scene.SetStatus(ssActive);
end;

procedure TProbeScene.Render;
begin
  if not ready then exit;
  inc(frames);
  if frames<>5 then exit;
  if expected<>0 then begin
    Check(game.GetCursorForID(CursorID.Default)=expected,'registry remains intact across rendered frames');
    Check(TCursorHandle(SDL_GetCursor)=expected,'DrawCursor preserves the pointer across frames');
    game.RegisterCursor(CursorID.Default,1,original);
    systemPlatform.SetCursor(original);
    systemPlatform.FreeCursor(expected);
    expected:=0;
  end;
  Signal('Engine\Cmd\Exit');
end;

function TProbeScene.GetArea:TRect;
begin
  result:=Types.Rect(0,0,320,240);
end;

var
  app:TProbeApp;
begin
  app:=TProbeApp.Create;
  try
    app.Prepare;
    app.Run;
  finally
    app.Free;
  end;
  if testsFailed=0 then writeln('All tests passed (',testsTotal,')')
    else begin
      writeln('FAILED: ',testsFailed,' of ',testsTotal);
      ExitCode:=1;
    end;
end.
