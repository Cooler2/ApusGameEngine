{$APPTYPE CONSOLE}
program PlatformTest;
uses
  Apus.MyServis, Apus.CrossPlatform, System.SysUtils, dglOpenGL,
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.Game,
  Apus.Engine.SDLplatform,
  Apus.Engine.WindowsPlatform,
  Apus.Engine.OpenGL;

var
 plat:ISystemPlatform;
 params:TGameSettings;
 game:TGameBase;

procedure EventHandler(event:TEventStr;tag:TTag);
begin
 writeln(event,' ',IntToHex(tag));
end;

begin
  UseLogFile('PlatformTest');
  SetEventHandler('Engine,Mouse,Kbd,Joystick',EventHandler);
  plat:=TWindowsPlatform.Create;
  //plat:=TSdlPlatform.Create;
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
