program UIScaleDPI;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  UIScaleDPIApp in 'UIScaleDPIApp.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
