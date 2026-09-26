program TreeGen;
 uses
  MainScene in 'MainScene.pas',
  Trees in 'Trees.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
