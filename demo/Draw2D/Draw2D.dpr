program Draw2D;
  uses
    {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
    Draw2DApp in 'Draw2DApp.pas';

begin
  application:=TMainApp.Create;
  application.Prepare;
  application.Run;
  application.Free;
end.
