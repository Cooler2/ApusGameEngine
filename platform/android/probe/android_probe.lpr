library apus_android_probe;

{$mode delphi}
{$packrecords c}

const
  JNI_VERSION_1_6=$00010006;

function JNI_OnLoad(vm:pointer; reserved:pointer):longint; cdecl;
begin
  JNI_OnLoad:=JNI_VERSION_1_6;
end;

exports
  JNI_OnLoad name 'JNI_OnLoad';

begin
end.
