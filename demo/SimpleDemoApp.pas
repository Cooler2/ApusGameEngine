unit SimpleDemoApp;
interface
 uses GameApp,EngineAPI;
 type
  TSimpleDemoApp=class(TGameApplication)
   constructor Create;
   procedure SetGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;
 var
  application:TSimpleDemoApp;

implementation
 uses windows,EngineTools,stdEffects;

 type
  TMainScene=class(TGameScene)
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;
{ TSimpleDemoApp }

constructor TSimpleDemoApp.Create;
 begin
  inherited;
  gameTitle:='Simple Engine Demo';
  configFileName:='game.ctl';
  usedAPI:=gaOpenGL2;
 end;

procedure TSimpleDemoApp.CreateScenes;
begin
  inherited;
  sleep(500);
  mainScene:=TMainScene.Create;
  game.AddScene(mainScene);
  TTransitionEffect.Create(mainScene,game.TopmostVisibleScene(true),0);
end;

procedure TSimpleDemoApp.SetGameSettings(var settings: TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmStretch;
  settings.mode.displayScaleMode:=dsmDontScale;

  settings.altMode.displayMode:=dmFullScreen;
  settings.altMode.displayFitMode:=dfmKeepAspectRatio;
  settings.altMode.displayScaleMode:=dsmDontScale;
end;

{ TMainScene }

procedure TMainScene.Render;
 var
  i,w,h,n:integer;
  x1,y1,x2,y2,x3,y3,x4,y4:integer;
begin
  painter.Clear(0);
  inherited;
  w:=game.renderWidth-1;
  h:=game.renderHeight-1;
  n:=24;
  for i:=0 to n-1 do begin
    x1:=round(w*i/n); y1:=0;
    x2:=w; y2:=round(h*i/n);
    x3:=round(w-w*i/n); y3:=h;
    x4:=0; y4:=round(h-h*i/n);
    painter.DrawLine(x1,y1,x2,y2,$8020C0F0);
    painter.DrawLine(x2,y2,x3,y3,$8020C0F0);
    painter.DrawLine(x3,y3,x4,y4,$8020C0F0);
    painter.DrawLine(x4,y4,x1,y1,$8020C0F0);
  end;
  painter.Rect(0,0,w,h, $FFFFC020);
  painter.Rect(10,10,w-10,h-10, $FFC00000);
end;

end.
