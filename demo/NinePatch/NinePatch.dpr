program NinePatch;
 uses
  MainScene in 'MainScene.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
