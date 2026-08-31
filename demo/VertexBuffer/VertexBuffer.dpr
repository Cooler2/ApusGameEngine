program VertexBuffer;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  VertexBufferApp in 'VertexBufferApp.pas';

{$IFDEF DELPHI}{$R *.res}{$ENDIF}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
