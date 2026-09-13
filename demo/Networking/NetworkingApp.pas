// Networking demo for Apus Engine: a multi-process chat over the R-27 stack.
//
//   Apus.Engine.HttpGameClient  <-- HTTP -->  Apus.Engine.HttpGameServer
//          (client process)                        (server process)
//
// The client keeps its session in unit globals, so it is one-client-per-process.
// To show a real multi-user chat we therefore run SEPARATE processes:
//   (no args)   server process; also auto-launches one client process
//   -server     server only (no auto client)
//   -client [N] client only (slot N); connects to the server on 127.0.0.1:<port>
// The server window has a "Launch client" button (or press C) that spawns more
// client processes, each in its own screen slot. Server is slot 0; clients tile
// into the next screen columns so the windows don't overlap.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit NetworkingApp;
interface
uses Apus.Engine.GameApp,Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure SetupGameSettings(var settings:TGameSettings); override;
    procedure CreateScenes; override;
  end;

var
  application:TMainApp;

implementation
uses Apus.Engine.Types,NetCommon,NetServerScene,NetClientScene;

procedure TMainApp.SetupApplication;
begin
  inherited;
  appSetup.logFile:=GetNetworkingLogFileName;
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(WIN_W,WIN_H); // base size; PlaceWindow rescales+repositions on the first frame
  if HasSwitch('client') then appSetup.title:='Apus Networking Demo - Client'
  else appSetup.title:='Apus Networking Demo - Server';
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode:=dmFixedWindow;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  if HasSwitch('client') then
    TClientScene.Create(window)
  else
    TServerScene.Create(not HasSwitch('server'),window);  // bare launch auto-starts one client
  game.SwitchToScene('Net');
end;

end.
