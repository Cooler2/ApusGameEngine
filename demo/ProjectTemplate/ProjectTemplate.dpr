program ProjectTemplate;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  ProjectTemplateApp in 'ProjectTemplateApp.pas';

{$R *.res}

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
