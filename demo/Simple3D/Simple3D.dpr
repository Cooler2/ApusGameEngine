program Simple3D;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  Simple3DApp in 'Simple3DApp.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
