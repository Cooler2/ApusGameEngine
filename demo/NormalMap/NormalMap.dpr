program NormalMap;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  NormalMapApp in 'NormalMapApp.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
