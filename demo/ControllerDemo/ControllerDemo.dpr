program ControllerDemo;
 uses
  ControllerDemoApp in 'ControllerDemoApp.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
