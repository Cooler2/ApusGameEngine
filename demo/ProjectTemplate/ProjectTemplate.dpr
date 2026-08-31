program ProjectTemplate;
{$APPTYPE GUI}
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  ProjectTemplateApp in 'ProjectTemplateApp.pas';

begin
 application:=TMainApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
