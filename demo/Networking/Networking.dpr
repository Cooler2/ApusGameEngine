program Networking;
{$APPTYPE GUI}
  uses
    {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  NetworkingApp in 'NetworkingApp.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
