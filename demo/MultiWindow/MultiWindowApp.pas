// Multi-window demo for Apus Game Engine (engine5)
//
// Purpose: testbed for multi-window support (R-02).
// Main window has buttons to spawn tool windows and exit.
// Each tool window has its own scene and title ("Tool 1", "Tool 2", ...).
//
// The demo exercises shared GL context startup and per-window render threads.
//
// It doubles as the text scale testbed (see Work/text_scale_design.md). Every window
// reports its own DPI numbers and draws three samples of the SAME nominal font size:
//   A - a handle resolved once, when the scene was built (control thread)
//   B - a handle resolved every frame, here in the window thread
//   C - a label whose font-size comes from the style (window thread, UI scale applied)
// All three must agree. Drag a window onto a monitor with another DPI and watch which
// of them moves. "Large fonts" is the program-wide font size knob (txt.SetScale): it
// is supposed to affect every window and to leave the debug overlays alone.

unit MultiWindowApp;
interface
 uses Apus.Engine.GameApp, Apus.Engine.API;

 type
  TMultiWindowApp=class(TGameApplication)
   constructor Create;
   procedure SetupApplication; override;
   procedure SetupGameSettings(var settings:TGameSettings); override;
   procedure CreateScenes; override;
  end;

 var
  application:TMultiWindowApp;

implementation
 uses SysUtils, Apus.Core, Apus.EventMan, Apus.Colors, Apus.Strings, Apus.Log,
   Apus.Threads, Apus.Engine.Types, Apus.Engine.SceneEffects,
   Apus.Engine.UI, Apus.Engine.UIWidgets;

 const
  SAMPLE_SIZE = 10; // nominal size of every probe font (see the header comment)

 type
  // Common base for both windows: draws the scale probe
  TProbeScene=class(TUIScene)
   ctorFont:TFontHandle; // sample A: resolved where the scene was built
   procedure ResolveCtorFont; // control thread only - that is what sample A is about
   procedure DrawProbe(const title:String8); // window thread
  end;

  // Primary window scene
  TMainScene=class(TProbeScene)
   procedure CreateUI;
   procedure Render; override;
  end;

  // Tool window scene (one per tool window)
  TToolScene=class(TProbeScene)
   toolIndex:integer;
   constructor Create(index:integer;wnd:TWindow);
   procedure CreateUI;
   procedure Render; override;
  end;

 var
  mainScene:TMainScene;
  toolCount:integer=0;
  newWindowSignalPath:String8='Demo\Cmd\NewWindow';
  reselectSignalPath:String8='Demo\Cmd\ReselectFonts';
  largeFontsSignalPath:String8='Demo\Cmd\LargeFonts';
  probes:array of TProbeScene; // every scene that draws the probe
  largeFonts:boolean=false;
  fontScale:single=1.0; // what we last asked txt.SetScale for

 procedure NewWindowClick; forward;
 procedure OnNewWindowCmd(event:TEventStr;tag:TTag); forward;
 procedure OnReselectCmd(event:TEventStr;tag:TTag); forward;
 procedure OnLargeFontsCmd(event:TEventStr;tag:TTag); forward;
 procedure AddProbe(scene:TProbeScene); forward;

{ TMultiWindowApp }

constructor TMultiWindowApp.Create;
var
 st:string;
begin
 inherited;
 st:=ExtractFileDir(ParamStr(0));
 SetCurrentDir(st);
 if DirectoryExists('../demo/MultiWindow') then
  SetCurrentDir('../demo/MultiWindow');
end;

procedure TMultiWindowApp.SetupApplication;
begin
 inherited;
 {$IFDEF SDL}
 requestBackend.platform:=spSDL;
 {$ENDIF}
 appSetup.title:='Main';
 requestBackend.graphicsAPI:=gaOpenGL2;
 windowSetup.size:=MakeSize(640,480);
end;

procedure TMultiWindowApp.SetupGameSettings(var settings:TGameSettings);
begin
 inherited;
 settings.mode:=dmWindow;
end;

procedure TMultiWindowApp.CreateScenes;
begin
 inherited;
 SetEventHandler(newWindowSignalPath,OnNewWindowCmd,emQueued);
 SetEventHandler(reselectSignalPath,OnReselectCmd,emQueued);
 SetEventHandler(largeFontsSignalPath,OnLargeFontsCmd,emQueued);
 mainScene:=TMainScene.Create;
 mainScene.CreateUI;
 AddProbe(mainScene);
 TTransitionEffect.Create(mainScene,250);
end;

{ TMainScene }

procedure TMainScene.CreateUI;
var
 panel:TUIElement;
 btn:TUIButton;
 toggle:TUIToggleButton;
 lbl:TUILabel;
begin
 panel:=TUIElement.Create(300,300,UI,'Main\Panel');
 panel.Center;
 panel.styleinfo:='E0283848';
 panel.SetAnchors(0.5,0.5,0.5,0.5);

 lbl:=TUILabel.Create(280,28,panel,'Main\Title').Centered('Multi-Window Demo');
 lbl.SetPos(150,24,pivotCenter);

 btn:=TUIButton.Create(220,40,panel,'Main\NewWindow').Setup('New Tool Window');
 btn.SetPos(150,70,pivotCenter);
 Link('UI\Main\NewWindow\OnClick',newWindowSignalPath);

 // The knob itself: a program-wide setting, so it is applied the way a settings
 // screen would apply one - queued, from the control thread, like SetupHighDPI.
 // It is supposed to reach every window; see Work/text_scale_design.md.
 toggle:=TUIToggleButton.Create(220,36,panel,'Main\LargeFonts').Setup('Large fonts (125%)',largeFonts);
 toggle.SetPos(150,118,pivotCenter);
 Link('UI\Main\LargeFonts\OnClick',largeFontsSignalPath);

 // Queued on purpose: sample A must be re-resolved by the thread that built the scene
 btn:=TUIButton.Create(220,36,panel,'Main\Reselect').Setup('Re-select sample A');
 btn.SetPos(150,162,pivotCenter);
 Link('UI\Main\Reselect\OnClick',reselectSignalPath);

 btn:=TUIButton.Create(220,40,panel,'Main\Exit').Setup('Exit');
 btn.SetPos(150,210,pivotCenter);
 Link('UI\Main\Exit\OnClick','Engine\Cmd\Exit');

 // sample C: the size comes from the style, the UI scale is applied by the widget
 lbl:=TUILabel.Create(280,22,panel,'Main\SampleC').Centered('C style   Sample Ag');
 lbl.style.Assign('font-size:10;');
 lbl.SetPos(150,252,pivotCenter);

 // status feedback line
 lbl:=TUILabel.Create(280,20,panel,'Main\Status').Centered('');
 lbl.SetPos(150,280,pivotCenter);
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
 AddProbe(scene);
 scene.SetStatus(TSceneStatus.ssActive);
 Log.Force('NewWindowClick: created Tool '+IntToStr(toolCount));
 UILabel('Main\Status').caption:='Created Tool '+IntToStr(toolCount);
end;

procedure OnNewWindowCmd(event:TEventStr;tag:TTag);
begin
 NewWindowClick;
end;

{ Scale probe }

// Sample A: resolved once, by whichever thread built the scene (the control thread).
procedure TProbeScene.ResolveCtorFont;
begin
 ctorFont:=txt.GetFont('Default',SAMPLE_SIZE);
end;

procedure TProbeScene.DrawProbe(const title:String8);
var
 frameFont:TFontHandle;
 thName:String8;
 x,y,prevH:single;

 // lines make room for themselves: the samples change size, that's the point
 procedure Line(font:TFontHandle;color:cardinal;const st:String8);
  var h:single;
  begin
   h:=txt.Height(font);
   y:=y+(prevH+h)*0.8;
   prevH:=h;
   txt.Write(font,x,y,color,st);
  end;

begin
 // Sample B: the same request, issued here and now - in the window thread
 frameFont:=txt.GetFont('Default',SAMPLE_SIZE);
 thName:=CurrentThread.Name;
 if thName='' then thName:='(unnamed)';
 x:=Dp(6); y:=0; prevH:=0;
 // the status lines use a built-in font: they must not move when the knob moves
 Line(game.smallFont,$FFC8D8E8,title+'   render thread: '+thName);
 Line(game.smallFont,$FFC8D8E8,
   UTF8.Format('dpi %.0f   canvasDPI %.0f   screenScale %.2f   fontScale asked %.2f',
     [window.surface.dpi,window.canvasDPI,game.screenScale,fontScale]));
 Line(ctorFont,$FFFFE080,UTF8.Format('A ctor    h=%d   Sample Ag',[txt.Height(ctorFont)]));
 Line(frameFont,$FF90FFA0,UTF8.Format('B frame   h=%d   Sample Ag',[txt.Height(frameFont)]));
end;

procedure AddProbe(scene:TProbeScene);
begin
 scene.ResolveCtorFont;
 SetLength(probes,length(probes)+1);
 probes[high(probes)]:=scene;
end;

// The program-wide font size knob: one value for the whole application, not a
// property of the window whose button was clicked. Queued, so it is applied from
// the control thread - exactly where a real settings screen would apply it.
procedure OnLargeFontsCmd(event:TEventStr;tag:TTag);
begin
 largeFonts:=not largeFonts;
 if largeFonts then fontScale:=1.25
  else fontScale:=1.0;
 txt.SetScale(fontScale);
 Log.Force(UTF8.Format('Large fonts: %.2f',[fontScale]));
end;

// Re-resolve sample A. Queued, so it runs in the control thread - the one that built
// the scenes; resolving it anywhere else would change what sample A means.
procedure OnReselectCmd(event:TEventStr;tag:TTag);
var
 i:integer;
begin
 for i:=0 to high(probes) do probes[i].ResolveCtorFont;
 UILabel('Main\Status').caption:='Sample A re-resolved';
end;

procedure TMainScene.Render;
var
 maxX,maxY,i:integer;
begin
 gfx.target.Clear($FF1A1A2E);
 maxX:=window.canvasWidth-1;
 maxY:=window.canvasHeight-1;

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

 DrawProbe('Main');
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

 // sample C, same as in the main window: font-size from the style
 lbl:=TUILabel.Create(280,22,UI,'Tool'+IntToStr(toolIndex)+'\SampleC').
  Centered('C style   Sample Ag');
 lbl.style.Assign('font-size:10;');
 lbl.SetPos(UI.size.x/2,UI.size.y-24,pivotCenter);
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
 maxX:=window.canvasWidth-1;
 maxY:=window.canvasHeight-1;
 draw.Rect(0,0,maxX,maxY,$FFC08040);
 DrawProbe('Tool '+IntToStr(toolIndex));
 inherited;
end;

end.
