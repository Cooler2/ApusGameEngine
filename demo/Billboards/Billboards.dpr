program Billboards;
 uses
  ScBillboards in 'ScBillboards.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
