program ShadowMap;
 uses
  ShadowMapMain in 'ShadowMapMain.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
