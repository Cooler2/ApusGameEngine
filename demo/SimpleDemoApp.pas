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
 uses windows,EngineTools,stdEffects,UIClasses,UIScene;

 type
  TMainScene=class(TUIScene)
   procedure CreateUI;
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
  mainScene.CreateUI;
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

procedure TMainScene.CreateUI;
var
 c:TUIControl;
 b:TUIButton;
 font:cardinal;
begin
 c:=TUIControl.Create(400,300,UI,'MainScene\MainMenu');
 //c.SetPos(1024,0,pivotTopRight);
 c.SetPos(300,300,pivotCenter);
 c.Center;
 c.styleinfo:='E0C0C8D0';
 font:=painter.GetFont('Default',9);
 b:=TUIButton.Create(100,35,'MainScene\Close','Exit',font,c);
 b.SetPos(200,250,pivotCenter);
end;

procedure TMainScene.Render;
 var
  i,w,h,n:integer;
  x1,y1,x2,y2,x3,y3,x4,y4:integer;
  font:cardinal;
begin
  painter.Clear(0);
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

  font:=painter.GetFont('Default',7);
  painter.TextOut(font,300,200,$FFFFFFFF,'Id-1');
  inherited;
end;

end.
