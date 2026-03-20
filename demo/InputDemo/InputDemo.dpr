program InputDemo;
  uses
    SceneInputDemo in 'SceneInputDemo.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.

