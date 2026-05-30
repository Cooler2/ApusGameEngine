program MultiWindow;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  MultiWindowApp in 'MultiWindowApp.pas';

{$R *.res}

begin
 application:=TMultiWindowApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
