program Scenes;
 uses SysUtils,EventMan,EngineAPI,EngineTools,GameApp,UIScene,UIClasses,StdEffects;

 type
  TSceneA=class(TUIScene)
   constructor Create;
   procedure Render; override;
  end;

  TSceneB=class(TUIScene)
   constructor Create;
   procedure Render; override;
  end;


 var
  application:TGameApplication;
  mainFont:cardinal;

procedure CreateScenes;
 begin
  mainFont:=painter.GetFont('Default',9);
  TSceneA.Create;
  TSceneB.Create;
  TTransitionEffect.Create(game.GetScene('SceneA'),0);
 end;

procedure EventHandler(event:EventStr;tag:TTag);
 var
  e:EventStr;
 begin
  if EventOfClass(event,'GameApp',e) then begin
   // event is 'GameApp\xxx' and e is now 'xxx'
   if e='CreateScenes' then CreateScenes;
  end else
  if EventOfClass(event,'Logic',e) then begin
   // event is 'Logic\xxx' and e is now 'xxx'
   if SameText(e,'SwitchToSceneA') then
    TTransitionEffect.Create(game.GetScene('SceneA'),500)
   else
   if SameText(e,'SwitchToSceneB') then
    TTransitionEffect.Create(game.GetScene('SceneB'),500);
  end;
 end;

{ SceneA }

constructor TSceneA.Create;
 begin
  inherited Create('SceneA');
  TUIButton.Create(250,50,'SceneA\Btn1','Switch to the SceneB',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.4, pivotCenter);
  // This signal is emited when button is clicked (pressed and released)
  Link('UI\SceneA\Btn1\Click','Logic\SwitchToSceneB');
 end;

procedure TSceneA.Render;
 begin
  painter.Clear($FF306030);
  painter.TextOut(mainFont,10,game.renderHeight-10,$FFC0C0C0,'Press [Win]+[~] to toggle the console window');
  inherited;
 end;

{ TSceneB }
constructor TSceneB.Create;
 begin
  inherited Create('SceneB');
  TUIButton.Create(250,50,'SceneB\Btn1','Switch to the SceneA',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.6, pivotCenter);
  // Alternate signal emited when a button is pressed
  Link('UI\onButtonClick\SceneB\Btn1','Logic\SwitchToSceneA');
 end;

procedure TSceneB.Render;
 begin
  painter.Clear($FF303060);
  inherited;
 end;

begin
 SetEventHandler('GAMEAPP',EventHandler);
 SetEventHandler('Logic',EventHandler);
 application:=TGameApplication.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
