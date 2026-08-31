program UIScaleDPI;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  UIScaleDPIApp in 'UIScaleDPIApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
