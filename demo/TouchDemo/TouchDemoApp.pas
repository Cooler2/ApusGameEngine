// Touch demo of the Apus Game Engine framework.
//
// A cross-platform sample oriented towards mobile / touchscreen use: a single
// sprite you drag around with a finger. On desktop the mouse stands in for
// touch, so the exact same code runs everywhere with no platform ifdefs.
//
// Milestone 1 (this file): drag a sprite that is loaded from a resource file,
// which also exercises PNG decoding and asset loading from the app bundle.
// Later milestones add an exit button, a text edit box and multitouch.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit TouchDemoApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  // Custom application class
  TTouchDemoApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TTouchDemoApp;

implementation
 uses SysUtils, Apus.Core, Apus.Engine.Types, Apus.Engine.SceneEffects, Apus.Engine.UIScene;

 type
  // Our single scene. TUIScene (not a bare TGameScene) so later milestones can
  // drop UI widgets straight in.
  TMainScene=class(TUIScene)
   sprite:TTexture;
   spriteX,spriteY:single; // sprite centre, in render coordinates
   placed:boolean;         // sprite position initialized to screen centre?
   dragging:boolean;
   prevPressed:boolean;    // pointer state last frame (own edge detection)
   grabDX,grabDY:single;   // sprite centre minus grab point, kept while dragging
   procedure LoadContent;
   function Process:boolean; override;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;

{ TTouchDemoApp }

constructor TTouchDemoApp.Create;
 begin
  // Platform must be selected before TGameApplication.Create chooses the backend.
  {$IFDEF SDL}
  usedPlatform:=spSDL;
  {$ELSE}
  usedPlatform:=spDefault;
  {$ENDIF}
  inherited;
  // Start from the engine-resolved resource base (exe dir, or the .app bundle's
  // Contents/Resources when launched from a macOS/iOS bundle - BaseDir handles it).
  SetCurrentDir(BaseDir);
  // When running straight from the repo, assets live in the source tree instead.
  if DirectoryExists('../demo/TouchDemo') then
    SetCurrentDir('../demo/TouchDemo');

  gameTitle:='Touch Demo';
  configFileName:='game.ctl';
  usedAPI:=gaOpenGL2; // OpenGL 2.0+ with shaders (GLES 3.0 on mobile)
 end;

procedure TTouchDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
 end;

procedure TTouchDemoApp.CreateScenes;
 begin
  inherited;
  mainScene:=TMainScene.Create;
  mainScene.LoadContent;
  // switch to the main scene using a fade transition
  TTransitionEffect.Create(mainScene,250);
 end;

{ TMainScene }

procedure TMainScene.LoadContent;
 begin
  // A real file on disk: exercises PNG decode + resource loading from the bundle.
  sprite:=LoadImageFromFile('sprite');
 end;

function TMainScene.Process:boolean;
 var
  pressed:boolean;
  hw,hh:single;
 begin
  result:=inherited;
  if sprite=nil then exit;

  // Place the sprite at the screen centre once the render size is known.
  if not placed then begin
   spriteX:=window.renderWidth/2;
   spriteY:=window.renderHeight/2;
   placed:=true;
  end;

  hw:=sprite.width/2;
  hh:=sprite.height/2;
  pressed:=(window.mouseButtons and 1)<>0; // left button / primary touch

  // Grab on the press edge, but only when the pointer is over the sprite.
  if pressed and not prevPressed and
     window.MouseInRect(spriteX-hw,spriteY-hh,sprite.width,sprite.height) then begin
   dragging:=true;
   grabDX:=spriteX-window.mousePos.x;
   grabDY:=spriteY-window.mousePos.y;
  end;
  if not pressed then dragging:=false;

  if dragging then begin
   spriteX:=window.mousePos.x+grabDX;
   spriteY:=window.mousePos.y+grabDY;
   result:=true; // sprite moved - request a redraw
  end;
  prevPressed:=pressed;
 end;

procedure TMainScene.Render;
 var
  i,n,maxX,maxY:integer;
  x1,y1,x2,y2,x3,y3,x4,y4:single;
  font:cardinal;
 begin
  gfx.target.Clear($FF203040); // dark slate background

  // Sparse diagonal pattern makes line aliasing and framebuffer scaling visible.
  maxX:=window.renderWidth-1;
  maxY:=window.renderHeight-1;
  n:=8;
  for i:=0 to n-1 do begin
   x1:=maxX*i/n; y1:=0;
   x2:=maxX; y2:=maxY*i/n;
   x3:=maxX-maxX*i/n; y3:=maxY;
   x4:=0; y4:=maxY-maxY*i/n;
   draw.Line(x1,y1,x2,y2,$6040C8F0);
   draw.Line(x2,y2,x3,y3,$6040C8F0);
   draw.Line(x3,y3,x4,y4,$6040C8F0);
   draw.Line(x4,y4,x1,y1,$6040C8F0);
  end;

  font:=txt.GetFont('Default',7);
  txt.Write(font,window.renderWidth div 2,40,$FFE0E0E0,
    'Drag the ball',taCenter);

  if sprite<>nil then
   draw.RotScaled(spriteX,spriteY,1,1,0,sprite); // centred (pivot defaults to 0.5,0.5)

  inherited; // UI on top (empty for now, ready for the exit button in M2)
 end;

end.
