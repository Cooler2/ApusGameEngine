program SimpleDemo;
 uses
  SimpleDemoApp in 'SimpleDemoApp.pas';

{$R *.res}

begin
 application:=TSimpleDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
