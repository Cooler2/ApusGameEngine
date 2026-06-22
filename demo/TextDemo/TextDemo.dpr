program TextDemo;
{$APPTYPE GUI}
  uses
    {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  TextDemoApp in 'TextDemoApp.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
