program particles;
 uses
  ParticlesApp in 'ParticlesApp.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
