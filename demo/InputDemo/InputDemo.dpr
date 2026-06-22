program InputDemo;
{$APPTYPE GUI}
  uses
    {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  InputDemoApp in 'InputDemoApp.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.

