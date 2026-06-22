program NinePatch;
 uses
  NinePatchApp in 'NinePatchApp.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
