{$APPTYPE CONSOLE}
program PlatformTest;
uses
  Apus.Core, Apus.Log, SysUtils,
  dglOpenGL,
  {$IFDEF MSWINDOWS}
  Apus.Engine.WindowsPlatform,
  {$ENDIF}
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Game,
  Apus.Engine.SDLplatform,
  Apus.Engine.OpenGL;

var
 plat:ISystemPlatform;
 params:TGameSettings;
 game:TGameBase;
 wnd:TWindow;
 sn:integer;

procedure EventHandler(event:TEventStr;tag:TTag);
begin
 inc(sn);
 writeln(sn:4,' ',event,' ',IntToHex(tag));
end;

begin
  Logger.UseLogFile('platformTest.log');
  SetEventHandler('Engine,Mouse,Kbd,Joystick',EventHandler);
  {$IFDEF MSWINDOWS}
  //plat:=TWindowsPlatform.Create;
  plat:=TSdlPlatform.Create;
  {$ELSE}
  plat:=TSdlPlatform.Create;
  {$ENDIF}
  game:=TGame.Create(plat,TOpenGL.Create);

  with params do begin
   width:=800;
   height:=600;
   colorDepth:=32;
   mode.displayMode:=dmWindow;
   mode.displayFitMode:=dfmFullSize;
   mode.displayScaleMode:=dsmDontScale;
  end;
  wnd:=plat.CreateWindow('Platform Test: '+plat.GetPlatformName);
  wnd.Configure(params);

  repeat
   wnd.ProcessMessages;
   sleep(1);
  until wnd.isTerminated;

  wnd.Close;
end.
