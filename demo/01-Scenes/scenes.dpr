program Scenes;
 uses Apus.MyServis, SysUtils, Types, Apus.EventMan, Apus.Engine.API,
   Apus.Engine.GameApp, Apus.Engine.UIScene, Apus.Engine.UIClasses,
   Apus.Engine.SceneEffects, Apus.Engine.UIRender;

 type
  TSceneA=class(TUIScene)
   constructor Create;
   procedure Render; override;
  end;

  TSceneB=class(TUIScene)
   constructor Create;
   procedure Render; override;
  end;

  // Windowed scene
  TSceneW=class(TUIScene)
   constructor Create;
   procedure Render; override;
  end;


 var
  application:TGameApplication;
  mainFont:cardinal;
  blurEffect:TBlurEffect;

procedure CreateScenes;
 begin
  mainFont:=txt.GetFont('Default',9);
  TSceneA.Create;
  TSceneB.Create;
  TSceneW.Create;
  TTransitionEffect.Create(game.GetScene('SceneA'),0);
 end;

procedure EventHandler(event:TEventStr;tag:TTag);
 var
  e:TEventStr;
  scene:TUIScene;
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
    TTransitionEffect.Create(game.GetScene('SceneB'),500)
   else
   if SameText(e,'ShowWindowWithShadow') then begin
    scene:=TUIScene(game.GetScene('SceneW'));
    scene.shadowColor:=$80202020;
    TShowWindowEffect.Create(scene,400,sweShow,1);
   end
   else
   if SameText(e,'ShowWindowWithBlur') then begin
    scene:=TUIScene(game.GetScene('SceneW'));
    if scene.status=ssActive then exit;
    scene.shadowColor:=0;
    blurEffect:=TBlurEffect.Create(game.TopmostVisibleScene, 0.3, 400, $202020, $404040);
    TShowWindowEffect.Create(scene,400,sweShow,4);
   end
   else
   if SameText(e,'CloseWindow') then begin
    TShowWindowEffect.Create(TUIScene(game.GetScene('SceneW')),400,sweHide,2);
    if blurEffect<>nil then blurEffect.Remove(400);
    blurEffect:=nil;
   end
   else
   if SameText(e,'AskExit') then begin
    application.Ask('[Confirmation]~Do you really want to~exit this great demo?','Engine\Cmd\Exit','');
   end;
  end;
 end;

{ SceneA }

constructor TSceneA.Create;
 begin
  inherited Create('SceneA');
  // Create a button
  TUIButton.Create(250,50,'SceneA\Btn1','Switch to the SceneB',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.3, pivotCenter);
  // This signal is emited when button is clicked (pressed and released)
  Link('UI\SceneA\Btn1\Click','Logic\SwitchToSceneB');

  // Few more buttons
  TUIButton.Create(250,50,'SceneA\BtnShow1','Show Window (shadow)',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.4, pivotCenter);
  Link('UI\SceneA\BtnShow1\Click','Logic\ShowWindowWithShadow');

  TUIButton.Create(250,50,'SceneA\BtnShow2','Show Window (blur)',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.5, pivotCenter);
  Link('UI\SceneA\BtnShow2\Click','Logic\ShowWindowWithBlur');

  TUIButton.Create(250,50,'SceneA\BtnAsk','Exit?',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.6, pivotCenter);
  Link('UI\SceneA\BtnAsk\Click','Logic\AskExit');
 end;

procedure TSceneA.Render;
 var
  i:integer;
 begin
//  painter.Clear($FF306030);
  gfx.target.Clear($FF000000);
  for i:=1 to 3 do
   draw.Rect(i*3,i*3,game.renderWidth-i*3-1,game.renderHeight-i*3-1,$FFF0F000);
  txt.Write(mainFont,20,game.renderHeight-20,$FFC0C0C0,'Press [Win]+[~] to toggle the console window');
  inherited;
 end;

{ TSceneB }
constructor TSceneB.Create;
 begin
  inherited Create('SceneB');
  TUIButton.Create(250,50,'SceneB\Btn1','Switch to the SceneA',mainFont,ui).
   SetPos(ui.width/2, ui.height*0.45, pivotCenter);
  // Alternate signal emited when a button is pressed
  Link('UI\onButtonClick\SceneB\Btn1','Logic\SwitchToSceneA');
 end;

procedure TSceneB.Render;
 begin
  gfx.target.Clear($FF303060);
  inherited;
 end;

{ TSceneW }
constructor TSceneW.Create;
 var
  c:TUIElement;
 begin
  inherited Create('SceneW',false);
  zOrder:=100; // Important: it should be above other scenes
  c:=TUIElement.Create(300,140,ui,'SceneW\Frame');
  c.SetPos(ui.width/2,ui.height*0.6, pivotCenter);
  c.shape:=shapeFull; // Important! Opaque elements define the scene area used for effects, it should not be void
  TUIButton.Create(100,40,'SceneW\Btn1','Close',mainFont,c).
   SetPos(c.width/2, c.height*0.5, pivotCenter);
  Link('UI\onButtonClick\SceneW\Btn1','Logic\CloseWindow');
 end;

procedure TSceneW.Render;
 var
  r:TRect;
 begin
  r:=FindControl('SceneW\Frame').GetPosOnScreen; // don't use globalRect for items in a windowed scene!
  BackgroundRenderBegin; // needed ONLY because background drawn below has semi-transparent parts
  draw.FillRect(r.left,r.top,r.right-1,r.bottom-1,$A0B0D0D0); // <-- semi-transparent color used
  draw.Rect(r.left,r.top,r.right-1,r.bottom-1,$FF000000);
  BackgroundRenderEnd;
  inherited;
 end;

begin
 SetEventHandler('GAMEAPP',EventHandler);
 SetEventHandler('Logic',EventHandler);
 usedAPI:=gaOpenGL2; // needed just for the Blur effect
 //usedPlatform:=spSDL;
 //directRenderOnly:=false;
 application:=TGameApplication.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
