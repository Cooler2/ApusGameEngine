program ControllerDemo;
 uses
  ControllerDemoMain in 'ControllerDemoMain.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
