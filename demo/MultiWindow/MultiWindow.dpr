program MultiWindow;
 uses
  MultiWindowApp in 'MultiWindowApp.pas';

{$R *.res}

begin
 application:=TMultiWindowApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
