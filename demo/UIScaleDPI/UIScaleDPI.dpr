program UIScaleDPI;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SceneDPIScale in 'SceneDPIScale.pas';
begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
