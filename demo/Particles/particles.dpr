program particles;
 uses
  ParticlesMain in 'ParticlesMain.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
