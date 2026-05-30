// Multi-window demo for Apus Game Engine (engine5)
//
// Purpose: testbed for multi-window support (R-02).
// Main window has buttons to spawn tool windows and exit.
// Each tool window has its own scene and title ("Tool 1", "Tool 2", ...).
//
// The demo exercises shared GL context startup and per-window render threads.

unit MultiWindowApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;

 type
  TMultiWindowApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TMultiWindowApp;

implementation
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Colors, Apus.Strings, Apus.Log,
   Apus.Engine.Types, Apus.Engine.SceneEffects,
   Apus.Engine.UI, Apus.Engine.UIWidgets;

 type
  // Primary window scene
  TMainScene=class(TUIScene)
   procedure CreateUI;
   procedure Render; override;
  end;

  // Tool window scene (one per tool window)
  TToolScene=class(TUIScene)
   toolIndex:integer;
   constructor Create(index:integer;wnd:TWindow);
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;
  toolCount:integer=0;
  newWindowSignalPath:String8='Demo\Cmd\NewWindow';

 procedure NewWindowClick; forward;
 procedure OnNewWindowCmd(event:TEventStr;tag:TTag); forward;

{ TMultiWindowApp }

constructor TMultiWindowApp.Create;
var
 st:string;
begin
 {$IFDEF SDL}
 usedPlatform:=spSDL;
 {$ELSE}
 usedPlatform:=spDefault;
 {$ENDIF}
 inherited;
 st:=ExtractFileDir(ParamStr(0));
 SetCurrentDir(st);
 if DirectoryExists('../demo/MultiWindow') then
  SetCurrentDir('../demo/MultiWindow');

 gameTitle:='Main';
 usedAPI:=gaOpenGL2;
 windowWidth:=640;
 windowHeight:=480;
end;

procedure TMultiWindowApp.SetupGameSettings(var settings:TGameSettings);
begin
 inherited;
 settings.mode.displayMode:=dmWindow;
 settings.mode.displayFitMode:=dfmFullSize;
 settings.mode.displayScaleMode:=dsmDontScale;
end;

procedure TMultiWindowApp.CreateScenes;
begin
 inherited;
 SetEventHandler(newWindowSignalPath,OnNewWindowCmd,emQueued);
 mainScene:=TMainScene.Create;
 mainScene.CreateUI;
 TTransitionEffect.Create(mainScene,250);
end;

{ TMainScene }

procedure TMainScene.CreateUI;
var
 panel:TUIElement;
 btn:TUIButton;
 lbl:TUILabel;
begin
 panel:=TUIElement.Create(300,220,UI,'Main\Panel');
 panel.Center;
 panel.styleinfo:='E0283848';
 panel.SetAnchors(0.5,0.5,0.5,0.5);

 lbl:=TUILabel.Create(280,28,panel,'Main\Title').Centered('Multi-Window Demo');
 lbl.SetPos(150,24,pivotCenter);

 btn:=TUIButton.Create(220,40,panel,'Main\NewWindow').Setup('New Tool Window');
 btn.SetPos(150,80,pivotCenter);
 Link('UI\Main\NewWindow\OnClick',newWindowSignalPath);

 btn:=TUIButton.Create(220,40,panel,'Main\Exit').Setup('Exit');
 btn.SetPos(150,140,pivotCenter);
 Link('UI\Main\Exit\OnClick','Engine\Cmd\Exit');

 // status feedback line
 lbl:=TUILabel.Create(280,20,panel,'Main\Status').Centered('');
 lbl.SetPos(150,195,pivotCenter);
end;

procedure NewWindowClick;
var
 wnd:TWindow;
 scene:TToolScene;
begin
 inc(toolCount);
 wnd:=game.AddWindow('Tool '+IntToStr(toolCount),400,300);
 scene:=TToolScene.Create(toolCount,wnd);
 scene.CreateUI;
 scene.SetStatus(TSceneStatus.ssActive);
 Log.Force('NewWindowClick: created Tool '+IntToStr(toolCount));
 UILabel('Main\Status').caption:='Created Tool '+IntToStr(toolCount);
end;

procedure OnNewWindowCmd(event:TEventStr;tag:TTag);
begin
 NewWindowClick;
end;

procedure TMainScene.Render;
var
 maxX,maxY,i:integer;
begin
 gfx.target.Clear($FF1A1A2E);
 maxX:=window.renderWidth-1;
 maxY:=window.renderHeight-1;

 // subtle animated grid
 for i:=0 to 7 do begin
  draw.Line(0,maxY*i/8,maxX,maxY*i/8,$18FFFFFF);
  draw.Line(maxX*i/8,0,maxX*i/8,maxY,$18FFFFFF);
 end;

 // border
 draw.Rect(0,0,maxX,maxY,$FF4080C0);

 // status bar
 txt.Write(0,8,maxY-16,$60FFFFFF,
  'FPS:'+IntToStr(round(window.FPS))+
  '  tools:'+IntToStr(toolCount));

 inherited; // draw UI
end;

{ TToolScene }

constructor TToolScene.Create(index:integer;wnd:TWindow);
begin
 toolIndex:=index;
 inherited Create('Tool'+IntToStr(index),true,wnd);
end;

procedure TToolScene.CreateUI;
var
 lbl:TUILabel;
begin
 lbl:=TUILabel.Create(280,28,UI,'Tool'+IntToStr(toolIndex)+'\Title').
  Centered('Tool Window #'+IntToStr(toolIndex));
 lbl.SetPos(UI.size.x/2,20,pivotCenter);
end;

procedure TToolScene.Render;
var
 maxX,maxY:integer;
 hue:cardinal;
begin
 // each tool window gets a unique tint
 hue:=$FF000000 or cardinal((toolIndex*73) and $FF) shl 16
                 or cardinal((toolIndex*137) and $FF) shl 8
                 or cardinal((toolIndex*41) and $FF);
 gfx.target.Clear(hue);
 maxX:=window.renderWidth-1;
 maxY:=window.renderHeight-1;
 draw.Rect(0,0,maxX,maxY,$FFC08040);
 inherited;
end;

end.
