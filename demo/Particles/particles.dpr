program particles;
 uses
  ParticlesApp in 'ParticlesApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
