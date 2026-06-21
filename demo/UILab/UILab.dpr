program UILab;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  UILabMain in 'UILabMain.pas';

begin
 application:=TUILabApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
