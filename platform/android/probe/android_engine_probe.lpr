library apus_android_engine_probe;

{$mode delphi}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Apus.Engine.API,
  Apus.Engine.GameApp;

type
  TAndroidProbeApplication=class(TGameApplication)
    procedure InitSound; override;
  end;

procedure TAndroidProbeApplication.InitSound;
begin
  // Audio activation is a later R-24 slice; first pixels must not depend on it.
end;

function JNI_OnLoad(vm:pointer; reserved:pointer):longint; cdecl;
begin
  JNI_OnLoad:=$00010006;
end;

function SDL_main(argc:longint; argv:PPChar):longint; cdecl;
var
  application:TAndroidProbeApplication;
begin
  usedPlatform:=spSDL;
  usedAPI:=gaOpenGL2;
  gameTitle:='Apus Engine Android Probe';
  configFileName:='';
  useConsoleScene:=false;
  useTweakerScene:=false;
  useSystemCursor:=false;

  application:=TAndroidProbeApplication.Create;
  try
    application.Prepare;
    application.Run;
    SDL_main:=0;
  finally
    application.Free;
  end;
end;

exports
  JNI_OnLoad name 'JNI_OnLoad',
  SDL_main name 'SDL_main';

begin
end.
