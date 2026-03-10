// Multi-window demo for Apus Game Engine (engine5)
//
// Purpose: testbed for multi-window support (R-02).
// Main window has buttons to spawn tool windows and exit.
// Each tool window has its own scene and title ("Tool 1", "Tool 2", ...).
//
// Current state: scaffold — second window creation is not yet supported
// by the engine. This demo will evolve together with the engine.

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

 procedure NewWindowClick; forward;

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
 font:TFontHandle;
begin
 font:=txt.GetFont('Default',9);

 panel:=TUIElement.Create(300,220,UI,'Main\Panel');
 panel.Center;
 panel.styleinfo:='E0283848';
 panel.SetAnchors(0.5,0.5,0.5,0.5);

 lbl:=TUILabel.Create(280,28,'Main\Title','Multi-Window Demo',panel,font);
 lbl.SetPos(150,24,pivotCenter);
 lbl.align:=taCenter;

 btn:=TUIButton.Create(220,40,'Main\NewWindow','New Tool Window',font,panel);
 btn.SetPos(150,80,pivotCenter);
 btn.onClick:=@NewWindowClick;

 btn:=TUIButton.Create(220,40,'Main\Exit','Exit',font,panel);
 btn.SetPos(150,140,pivotCenter);
 Link('UI\Main\Exit\Click','Engine\Cmd\Exit');

 // status feedback line
 lbl:=TUILabel.Create(280,20,'Main\Status','',panel,txt.GetFont('Default',7));
 lbl.SetPos(150,195,pivotCenter);
 lbl.align:=taCenter;
end;

procedure NewWindowClick;
begin
 inc(toolCount);
 // TODO: when engine supports additional windows, create one here:
 // var wnd:=systemPlatform.CreateWindow('Tool '+IntToStr(toolCount));
 // wnd.Configure(...);
 // var scene:=TToolScene.Create(toolCount,wnd);
 // scene.CreateUI;
 // scene.SetStatus(TSceneStatus.ssActive);
 Log.Force('NewWindowClick: would create Tool '+IntToStr(toolCount)+' (not yet supported)');
 UILabel('Main\Status').caption:='Would create Tool '+IntToStr(toolCount)+' (not yet supported)';
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
 font:TFontHandle;
begin
 font:=txt.GetFont('Default',8);
 lbl:=TUILabel.Create(280,28,'Tool'+IntToStr(toolIndex)+'\Title',
  'Tool Window #'+IntToStr(toolIndex),UI,font);
 lbl.SetPos(UI.size.x/2,20,pivotCenter);
 lbl.align:=taCenter;
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
