program NinePatch;
 uses
  NinePatchMain in 'NinePatchMain.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
