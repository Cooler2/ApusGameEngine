program Borderless;
 uses
  BorderlessMain in 'BorderlessMain.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
