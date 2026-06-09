program ProjectTemplate;
{$APPTYPE GUI}
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  MainScene in 'MainScene.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
