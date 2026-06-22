program Borderless;
 uses
  BorderlessApp in 'BorderlessApp.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
