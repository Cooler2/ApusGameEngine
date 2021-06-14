// Advanced texturing features demo:
// - Texture Array
// - Manual Mip-Map levels
program AdvTex;
 uses Apus.MyServis, SysUtils, Types, Apus.EventMan, Apus.Engine.API,
   Apus.Engine.GameApp, Apus.Engine.UIScene, Apus.Engine.UIClasses,
   Apus.Engine.SceneEffects, Apus.Engine.UIRender;

 type
  TMainScene=class(TUIScene)
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
  TMainScene.Create;
 end;

constructor TMainScene.Create;
 begin
  inherited Create('MainScene');
 end;

procedure TMainScene.Render;
 var
  i:integer;
 begin
  gfx.target.Clear($FF000000);
  txt.Write(mainFont,20,game.renderHeight-20,$FFC0C0C0,'Press [Win]+[~] to toggle the console window');
  inherited;
 end;

begin
 SetEventHandler('GAMEAPP',EventHandler);
 SetEventHandler('Logic',EventHandler);
 usedAPI:=gaOpenGL2; // needed just for the Blur effect
 //usedPlatform:=spSDL;
 //directRenderOnly:=false;
 LinkProc('GameApp\CreateScenes',CreateScenes);
 application:=TGameApplication.Create;
 application.Prepare;
 application.Run;
 application.Free;
end.
