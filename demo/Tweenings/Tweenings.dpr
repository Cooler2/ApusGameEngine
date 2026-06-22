program Tweenings;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  TweeningsApp in 'TweeningsApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
