// R-05 Style System demo for the Apus Game Engine

// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit StyleDemoApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;
 type
  TStyleDemoApp=class(TGameApplication)
   constructor Create;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TStyleDemoApp;

implementation
 uses SysUtils, Apus.EventMan, Apus.Colors,
   Apus.Engine.Types, Apus.Engine.SceneEffects, Apus.Engine.UI,
   Apus.Engine.Style;

 type
  TStyleDemoScene=class(TUIScene)
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  mainScene:TStyleDemoScene;
  styleRefToggle:boolean; // for the @ref update button demo

{ TStyleDemoApp }

constructor TStyleDemoApp.Create;
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
  if DirectoryExists('../demo/StyleDemo') then
    SetCurrentDir('../demo/StyleDemo');

  gameTitle:='R-05 Style System Demo';
  usedAPI:=gaOpenGL2;
 end;

procedure TStyleDemoApp.SetupGameSettings(var settings:TGameSettings);
 begin
  inherited;
  settings.mode.displayMode:=dmWindow;
  settings.mode.displayFitMode:=dfmFullSize;
  settings.mode.displayScaleMode:=dsmDontScale;
 end;

procedure TStyleDemoApp.CreateScenes;
 begin
  inherited;
  mainScene:=TStyleDemoScene.Create('StyleDemo');
  mainScene.CreateUI;
  Sleep(500);
  TTransitionEffect.Create(mainScene, 250);
 end;

{ TStyleDemoScene }

// Toggle @demo-btn named style between warm red and cool blue → Btn3 updates too
procedure StyleDemoUpdateRef;
 var
  named:TStyleBlock;
 begin
  styleRefToggle:=not styleRefToggle;
  named:=FindNamedStyle('demo-btn');
  if named=nil then exit;
  if styleRefToggle then
   named.ParseText('color: $FF6E1E1E; text-color: $FFFFD0CC;')  // warm red
  else
   named.ParseText('color: $FF1E3D6E; text-color: $FFCCE0FF;'); // cool blue
 end;

// Panel layout (top-left at 10,10, size 280×330):
// Row spacing 38px, first button at y=50.
// For Robot API visual tests:
//   'ui.element name=StyleDemo\BtnN' → screen coords
//   'pixel cx cy' → sample background color at center
// Expected idle colors (button background center):
//   Btn1: ~$FFB0A0C0 (defaultBtnColor, default gradient)
//   Btn2: ~$FF1E3D6E (custom color, gradient center)
//   Btn3: ~$FF1E3D6E (same via @demo-btn ref)
//   Btn4: ~$FF1E3D6E idle; ~$FF2E5DA0 hover; ~$FF0E1E3A pressed
//   Btn5: ~$FF1E3D6E (disabled; only text-color changes)
//   Btn6: click toggles Btn3 and @demo-btn color
procedure TStyleDemoScene.CreateUI;
 var
  panel:TUIElement;
  btn:TUIButton;
  font:cardinal;
  named:TStyleBlock;
 begin
  font:=txt.GetFont('Default', 8);

  // Register named style reused by Btn3 and the @ref toggle demo
  named:=TStyleBlock.Create;
  named.ParseText('color: $FF1E3D6E; text-color: $FFCCE0FF;');
  RegisterNamedStyle('demo-btn', named);

  // Panel: 280×330 at (10,10)
  panel:=TUIElement.Create(280, 330, UI, 'StyleDemo\Panel');
  panel.SetPos(10, 10, pivotTopLeft);
  panel.styleinfo:='fill: $BF102030; border-width: 1; border-color: $FF3060A0;';
  TUILabel.Create(260, 20, panel, 'StyleDemo\Title').Centered('R-05 Style System Demo', font, $FF80C8FF).
    SetPos(140, 18, pivotCenter);

  // Btn1: no custom style — uses default drawer (baseline)
  TUIButton.Create(250, 30, panel, 'StyleDemo\Btn1').Setup('Default style', font).
    SetPos(140, 55, pivotCenter);

  // Btn2: explicit color + text-color via SetStyleText
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn2').Setup('Custom color', font);
  btn.SetPos(140, 93, pivotCenter);
  btn.SetStyleText('color: $FF1E3D6E; text-color: $FFCCE0FF;');

  // Btn3: @ref to named style (same result as Btn2, but via indirection)
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn3').Setup('@ref style', font);
  btn.SetPos(140, 131, pivotCenter);
  btn.SetStyleText('@demo-btn;');

  // Btn4: CSS state blocks — :hover and :pressed override color
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn4').Setup('State: hover/pressed', font);
  btn.SetPos(140, 169, pivotCenter);
  btn.SetStyleText(
    'color: $FF1E3D6E; text-color: $FFCCE0FF;'+
    ':hover { color: $FF2E5DA0; text-color: $FFFFFFFF; }'+
    ':pressed { color: $FF0E1E3A; text-color: $FF8090A0; }');

  // Btn5: disabled — :disabled overrides text-color; button color unchanged
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn5').Setup('Disabled button', font);
  btn.SetPos(140, 207, pivotCenter);
  btn.SetStyleText(
    'color: $FF1E3D6E; text-color: $FFCCE0FF;'+
    ':disabled { text-color: $FF707070; }');
  btn.flags.enabled:=false;

  // Btn6: click to toggle @demo-btn → Btn3 updates (cascade demo)
  btn:=TUIButton.Create(250, 30, panel, 'StyleDemo\Btn6').Setup('Toggle @ref (Btn3 updates)', font);
  btn.SetPos(140, 245, pivotCenter);
  btn.onClickAsync:=@StyleDemoUpdateRef;

  // Exit button outside the panel
  btn:=TUIButton.Create(120, 30, UI, 'StyleDemo\Exit').Setup('Exit', font);
  btn.SetPos(10, 355, pivotTopLeft);
  Link('UI\StyleDemo\Exit\OnClick', 'Engine\Cmd\Exit');
 end;

procedure TStyleDemoScene.Render;
 var
  font:cardinal;
 begin
  gfx.target.Clear(0);
  font:=txt.GetFont('Default', 7);
  txt.Write(font, 300, 20, $FFFFFFFF, 'R-05 Style System Demo');
  txt.Write(font, 300, 40, $FFD0D0D0, 'Btn4: hover/press for state colors');
  txt.Write(font, 300, 60, $FFD0D0D0, 'Btn5: disabled (text-color from :disabled)');
  txt.Write(font, 300, 80, $FFD0D0D0, 'Btn6: toggles @demo-btn → Btn3 updates');
  inherited;
 end;

end.
