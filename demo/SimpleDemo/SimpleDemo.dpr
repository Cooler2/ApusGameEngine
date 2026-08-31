program SimpleDemo;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SimpleDemoApp in 'SimpleDemoApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TSimpleDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
