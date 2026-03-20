program Draw2D;
  uses
    SceneDraw2D in 'SceneDraw2D.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
