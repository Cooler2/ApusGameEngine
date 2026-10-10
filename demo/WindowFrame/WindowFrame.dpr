program WindowFrame;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  WindowFrameApp in 'WindowFrameApp.pas';

begin
 application:=TWindowFrameApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
