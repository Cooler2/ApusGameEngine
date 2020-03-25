program SimpleDemo;
 uses
  SimpleDemoApp in 'SimpleDemoApp.pas';

begin
 application:=TSimpleDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
