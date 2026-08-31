program MultiWindow;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  MultiWindowApp in 'MultiWindowApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TMultiWindowApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
