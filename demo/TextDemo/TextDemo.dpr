program TextDemo;
{$APPTYPE GUI}
  uses
    SceneTextDemo in 'SceneTextDemo.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
