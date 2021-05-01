{$APPTYPE CONSOLE}
program OpenGL;

uses
  Apus.MyServis, Apus.CrossPlatform, SysUtils,
  dglOpenGL,
  {$IFDEF MSWINDOWS}
  Apus.Engine.WindowsPlatform,
  {$ENDIF}
  Apus.EventMan,
  Apus.Engine.API,
  Apus.Engine.SDLplatform,
  Apus.Engine.OpenGL;

var
 params:TGameSettings;
 sn:integer;

procedure EventHandler(event:TEventStr;tag:TTag);
begin
 {inc(sn);
 writeln(sn:4,' ',event,' ',IntToHex(tag));}
end;

procedure Prepare;
 begin

 end;

procedure DrawFrame;
 begin
  // Clear backbuffer
  glClearColor(0.1,0.2,0.3,1.0);
  glClearDepth(1.0);
  glClear(GL_COLOR_BUFFER_BIT+GL_DEPTH_BUFFER_BIT);

  // Draw
 end;

begin
  UseLogFile('OpenGL.log');
  SetEventHandler('Engine,Mouse,Kbd,Joystick',EventHandler);
  {$IFDEF MSWINDOWS}
  systemPlatform:=TWindowsPlatform.Create;
  {$ELSE}
  systemPlatform:=TSdlPlatform.Create;
  {$ENDIF}
  gfx:=TOpenGL.Create;
  //game:=TGame.Create(plat,gfx);

  with params do begin
   width:=800;
   height:=600;
   colorDepth:=32;
   mode.displayMode:=dmWindow;
   mode.displayFitMode:=dfmFullSize;
   mode.displayScaleMode:=dsmDontScale;
  end;
  systemPlatform.CreateWindow('Platform Test: '+systemPlatform.GetPlatformName);
  systemPlatform.SetupWindow(params);

  gfx.Init(systemPlatform);

  Prepare;
  repeat
   systemPlatform.ProcessSystemMessages;
   DrawFrame;
   gfx.PresentFrame;
   sleep(1);
  until systemPlatform.isTerminated;

  gfx.Done;
  systemPlatform.DestroyWindow;
end.
