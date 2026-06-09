program HelloEngine;
{$APPTYPE GUI}
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  HelloEngineApp in 'HelloEngineApp.pas';

begin
  application:=THelloEngineApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
