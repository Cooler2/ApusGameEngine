program Billboards;
 uses
  BillboardsApp in 'BillboardsApp.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
