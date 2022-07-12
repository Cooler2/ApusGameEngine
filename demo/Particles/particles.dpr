program particles;
 uses
  MainScene in 'MainScene.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
