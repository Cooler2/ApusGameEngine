program Networking;
{$APPTYPE GUI}
  uses
    {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  Apus.Engine.GameApp,
  NetCommon in 'NetCommon.pas',
  NetServerScene in 'NetServerScene.pas',
  NetClientScene in 'NetClientScene.pas',
  NetworkingApp in 'NetworkingApp.pas';

begin
  logFileName:=GetNetworkingLogFileName;
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
