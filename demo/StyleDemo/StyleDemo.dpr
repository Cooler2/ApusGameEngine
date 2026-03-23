program StyleDemo;
 uses
  StyleDemoApp in 'StyleDemoApp.pas';

begin
 application:=TStyleDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
