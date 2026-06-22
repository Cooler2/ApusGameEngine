program ShadowMap;
 uses
  ShadowMapApp in 'ShadowMapApp.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
