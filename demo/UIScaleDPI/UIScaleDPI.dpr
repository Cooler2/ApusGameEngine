program UIScaleDPI;
 uses
  SceneDPIScale in 'SceneDPIScale.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
