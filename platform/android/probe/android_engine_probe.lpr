library apus_android_engine_probe;

{$mode delphi}

uses
  Apus.Engine.GameApp;

function JNI_OnLoad(vm:pointer; reserved:pointer):longint; cdecl;
begin
  JNI_OnLoad:=$00010006;
end;

exports
  JNI_OnLoad name 'JNI_OnLoad';

begin
end.
