program TouchDemo;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  TouchDemoApp in 'TouchDemoApp.pas';

begin
 application:=TTouchDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
