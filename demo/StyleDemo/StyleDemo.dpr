program StyleDemo;
 uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  StyleDemoApp in 'StyleDemoApp.pas',
  StyleThemeEditorScene in 'StyleThemeEditorScene.pas';

begin
 application:=TStyleDemoApp.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
