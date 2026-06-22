// UIScaleDPI demo - demonstrates UI scaling and DPI awareness
//
// TODO: glyph browser mode — render A-Z glyphs into card textures via draw/FreeTypeFont,
//  stretch to card size using integer scale. Add font size selector. This will show:
//  - visual difference between bitmap and FreeType fonts
//  - how DPI and zoom affect text rendering quality
//
// Scale model:
//   actualScale = dpiScale * userZoom
//   - dpiScale = screenDPI / 96 — compensates monitor pixel density, changes dynamically
//   - userZoom = user preference (combobox), always starts at 100%, does not depend on DPI
//   So userZoom=100% means "normal size" on any monitor regardless of DPI.
//
// Copyright (C) 2021-2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit UIScaleDPIApp;
interface
 uses Apus.Engine.GameApp,Apus.Engine.API;
 type
  TMainApp=class(TGameApplication)
   constructor Create;
   procedure CreateScenes; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
  end;

 var
  application:TMainApp;

implementation
 uses
   Apus.Core,
   Apus.EventMan,
   Apus.Conv,
   Apus.Engine.Types,
   Apus.Engine.UITypes,
   Apus.Engine.UI,
   Apus.Engine.UILayout;

 type
  TMainScene=class(TUIScene)
   procedure Load; override;
   procedure Render; override;
  end;

 const
  CARD_WIDTH=140;
  CARD_HEIGHT=120;
  CARD_COUNT=24;

 var
  sceneMain:TMainScene;
  statusLabel:TUILabel;
  cardGrid:TUIElement;
  userZoom:single=1.0;

 function DPIScale:single;
  begin
   result:=window.screenDPI/96;
  end;

 // Palette for card thumbnails
 function CardColor(index:integer):cardinal;
  const
   palette:array[0..7] of cardinal=(
    $FF4A90D9,$FF50B878,$FFD4A04A,$FFD95050,
    $FF9B59B6,$FF1ABC9C,$FFE67E22,$FF3498DB);
  begin
   result:=palette[index mod length(palette)];
  end;

 procedure ApplyScale;
  var
   s:single;
  begin
   s:=DPIScale*userZoom;
   sceneMain.UI.SetScale(s);
   // TODO: txt.SetScale only affects GetFont, not rendering of existing font handles.
   //  Text inside labels does not scale with UI zoom — needs engine-level support
   //  (e.g. applying globalScale in WriteW or scaling font handles in labels).
  end;

 procedure OnScaleSelect(event:TEventStr;tag:TTag);
  const
   zoomValues:array[0..6] of single=(0.75,0.85,1.0,1.15,1.25,1.5,1.75);
  begin
   userZoom:=zoomValues[Clamp(UIComboBox('ScaleCombo').curItem,0,high(zoomValues))];
   ApplyScale;
  end;

 procedure OnDPIChanged(event:TEventStr;tag:TTag);
  begin
   ApplyScale; // recalculate actualScale with new DPIScale
  end;

 procedure OnTestDialog(event:TEventStr;tag:TTag);
  begin
   application.Confirm('Does this dialog scale correctly?','','');
  end;

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: UI Scale && DPI Demo';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=true;
  windowSizeable:=true;
end;

procedure TMainApp.SetupGameSettings(var settings:TGameSettings);
begin
  inherited;
  settings.mode.displayMode:=dmWindow;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  sceneMain:=TMainScene.Create('Main');
  game.SwitchToScene('Main');
end;

{ TMainScene }
procedure TMainScene.Load;
 var
  toolbar,content,statusBar:TUIElement;
  combo:TUIComboBox;
  scroll:TUIScrollBar;
  card:TUIElement;
  lab:TUILabel;
  i:integer;
  zoomItems:Strings8;
  names:array[0..CARD_COUNT-1] of String8;
  sizes:array[0..CARD_COUNT-1] of String8;
 begin
  // card metadata
  names[0]:='sunset.jpg';      sizes[0]:='3840x2160';
  names[1]:='portrait.png';    sizes[1]:='2048x2048';
  names[2]:='landscape.jpg';   sizes[2]:='5120x2880';
  names[3]:='macro.jpg';       sizes[3]:='4032x3024';
  names[4]:='cityscape.png';   sizes[4]:='3840x2160';
  names[5]:='forest.jpg';      sizes[5]:='6000x4000';
  names[6]:='ocean.jpg';       sizes[6]:='5472x3648';
  names[7]:='mountain.png';    sizes[7]:='4288x2848';
  names[8]:='flower.jpg';      sizes[8]:='3024x4032';
  names[9]:='bridge.png';      sizes[9]:='3840x2560';
  names[10]:='cat.jpg';        sizes[10]:='2400x1600';
  names[11]:='night_sky.jpg';  sizes[11]:='6016x4016';
  names[12]:='autumn.png';     sizes[12]:='4000x3000';
  names[13]:='waterfall.jpg';  sizes[13]:='3648x5472';
  names[14]:='desert.jpg';     sizes[14]:='5120x3413';
  names[15]:='snow.png';       sizes[15]:='4928x3264';
  names[16]:='garden.jpg';     sizes[16]:='3840x2560';
  names[17]:='abstract.png';   sizes[17]:='2048x2048';
  names[18]:='bird.jpg';       sizes[18]:='4288x2848';
  names[19]:='river.jpg';      sizes[19]:='5472x3648';
  names[20]:='clouds.png';     sizes[20]:='3840x2160';
  names[21]:='beach.jpg';      sizes[21]:='4032x3024';
  names[22]:='aurora.png';     sizes[22]:='6000x4000';
  names[23]:='fireworks.jpg';  sizes[23]:='3024x4032';

  // === Toolbar ===
  toolbar:=TUIElement.Create(-1,36,UI,'Toolbar');
  toolbar.SetAnchors(0,0,1,0);
  toolbar.styleInfo:='fill:FF484848';
  toolbar.SetPaddings(8,4,8,4);

  TUILabel.Create(200,28,toolbar).Setup('Image Viewer');

  TUIButton.Create(90,24,toolbar,'TestDlgBtn').Setup('Test Dialog');

  SetLength(zoomItems,7);
  zoomItems[0]:='75%';  zoomItems[1]:='85%';  zoomItems[2]:='100%';
  zoomItems[3]:='115%'; zoomItems[4]:='125%'; zoomItems[5]:='150%'; zoomItems[6]:='175%';
  combo:=TUIComboBox.Create(80,24,toolbar,'ScaleCombo',zoomItems);
  combo.SetPos(toolbar.clientWidth-8,4,pivotTopRight);
  combo.SetAnchors(1,0,1,0);
  combo.curItem:=2; // 100%

  TUILabel.Create(50,24,toolbar).Setup('Zoom:').
   SetPos(toolbar.clientWidth-96,4,pivotTopRight).
   SetAnchors(1,0,1,0);

  // === Status bar ===
  statusBar:=TUIElement.Create(-1,24,UI,'StatusBar');
  statusBar.Snap(smBottom);
  statusBar.SetAnchors(0,1,1,1);
  statusBar.styleInfo:='fill:FF1A1A1A';
  statusBar.SetPaddings(10,3,10,3);

  statusLabel:=TUILabel.Create(-1,18,statusBar,'StatusText').Setup('');

  // === Content area with scroll ===
  content:=TUIElement.Create(-1,-1,UI,'Content');
  content.SetPos(0,36);
  content.SetAnchors(0,0,1,1);
  content.Resize(UI.clientWidth,UI.clientHeight-36-24);
  content.flags.dontClipChildren:=false;
  content.styleInfo:='fill:FF2E2E2E';

  // scrollable card container
  cardGrid:=TUIElement.Create(content.clientWidth-14,-1,content,'CardGrid');
  cardGrid.layout:=TGridLayout.Create(8,8,12,12,true);
  cardGrid.SetAnchors(0,0,1,0);

  // scroll bar
  scroll:=TUIScrollBar.CreateV(12,-1,content,'ContentScroll');
  scroll.autoHide:=true;
  scroll.Snap(smRight);
  scroll.Link(cardGrid);
  scroll.styleInfo:='style:flat; radius:30%; trackWidth:20%';

  // === Create cards ===
  for i:=0 to CARD_COUNT-1 do begin
   card:=TUIElement.Create(CARD_WIDTH,CARD_HEIGHT,cardGrid,'Card'+Conv.ToStr(i));
   card.styleInfo:='fill:'+Conv.ToHex(CardColor(i))+'; radius:6; hover.borderWidth:2; hover.borderColor:FFEE; hoverTime:0';
   card.SetPaddings(6,6,6,6);

   // filename label at bottom
   lab:=TUILabel.Create(-1,16,card).Setup('  '+names[i]);
   lab.SetPos(0,card.clientHeight,pivotBottomLeft,true);

   // dimensions label
   lab:=TUILabel.Create(-1,14,card).Setup('  '+sizes[i]);
   lab.SetPos(0,card.clientHeight-16,pivotBottomLeft,true);
  end;

  // === Connect signals ===
  SetEventHandler('UI\ScaleCombo\ONSELECT',OnScaleSelect,emInstant);
  SetEventHandler('UI\TestDlgBtn\ONCLICK',OnTestDialog,emQueued);
  SetEventHandler('ENGINE\DPICHANGED\DONE',OnDPIChanged,emQueued); // after engine-level scale update

  // apply initial scale: dpiScale * userZoom(100%)
  ApplyScale;
 end;

procedure TMainScene.Render;
 var
  ds:single;
begin
  gfx.target.Clear($FF2E2E2E);
  // update status bar
  if statusLabel<>nil then begin
   ds:=DPIScale;
   statusLabel.caption:=
    'DPI: '+Conv.ToStr(window.screenDPI)+
    '  |  DPI Scale: '+Conv.ToStr(round(ds*100))+'%'+
    '  |  Zoom: '+Conv.ToStr(round(userZoom*100))+'%'+
    '  |  Effective: '+Conv.ToStr(round(ds*userZoom*100))+'%'+
    '  |  Render: '+Conv.ToStr(window.renderWidth)+'x'+Conv.ToStr(window.renderHeight);
  end;
  inherited;
end;

end.
