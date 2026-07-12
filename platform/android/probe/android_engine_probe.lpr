library apus_android_engine_probe;

{$mode delphi}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  jni,
  sdl2,
  Apus.Android,
  Apus.Engine.API,
  Apus.Engine.GameApp,
  TouchDemoApp;

type
  TAndroidTouchDemoApp=class(TTouchDemoApp)
    procedure InitSound; override;
  end;

procedure TAndroidTouchDemoApp.InitSound;
begin
  // Audio activation is a later R-24 slice; first pixels must not depend on it.
end;

function JNI_OnLoad(vm:PJavaVM; reserved:pointer):jint; cdecl;
begin
  curVM:=vm;
  JNI_OnLoad:=JNI_VERSION_1_6;
end;

function SDL_main(argc:longint; argv:PPChar):longint; cdecl;
var
  application:TAndroidTouchDemoApp;
  env:PJNIEnv;
  activity:jobject;
begin
  env:=PJNIEnv(SDL_AndroidGetJNIEnv());
  activity:=jobject(SDL_AndroidGetActivity());
  if (env=nil) or (activity=nil) then begin
    SDL_main:=1;
    exit;
  end;
  InitAndroid(env,activity,nil);

  application:=TAndroidTouchDemoApp.Create;
  configFileName:=''; // packaged demo uses defaults for the first runtime gate
  useConsoleScene:=false;
  useTweakerScene:=false;
  useSystemCursor:=false;
  try
    CopyAssetFile('sprite.png');
    SetCurrentDir(Apus.Android.appDataDir);
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
