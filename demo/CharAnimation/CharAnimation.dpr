program CharAnimation;
 uses
  CharAnimationMain in 'CharAnimationMain.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
