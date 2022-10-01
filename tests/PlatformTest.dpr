{$APPTYPE CONSOLE}
program PlatformTest;
uses
  Apus.Common, Apus.CrossPlatform, SysUtils,
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
 sn:integer;

procedure EventHandler(event:TEventStr;tag:TTag);
begin
 inc(sn);
 writeln(sn:4,' ',event,' ',IntToHex(tag));
end;

begin
  UseLogFile('platformTest.log');
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
  plat.CreateWindow('Platform Test: '+plat.GetPlatformName);
  plat.SetupWindow(params);

  repeat
   plat.ProcessSystemMessages;
   sleep(1);
  until plat.isTerminated;

  plat.DestroyWindow;
end.
