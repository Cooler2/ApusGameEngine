// GPU regression checks for optional TextFX UI captions. Needs a GL window.
{$APPTYPE CONSOLE}
program TestTextFXStyle;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils, Types, Apus.Core, Apus.Images, Apus.EventMan,
  Apus.Engine.Types, Apus.Engine.API, Apus.Engine.GameApp, Apus.Engine.Scene,
  Apus.Engine.UITypes, Apus.Engine.UIWidgets, Apus.Engine.UIShapes, Apus.Engine.UIRender,
  Apus.Engine.DefaultStyle, Apus.Engine.TextFXStyle, Apus.Engine.TextEffects,
  Apus.Engine.Style;

{$I ..\Base\tests\Test.inc}

const W=512; H=128;
  BUTTON_STYLE='font-size:12; color:#E0F0FF; press-time:0; release-time:0;'+
    'hover-time:0; disable-time:0; enable-time:0;'+
    ':hover { color:#FFD080; } :disabled { color:$80808080; }';
type
  TPixels=array of cardinal;
  TTestApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure CreateScenes; override;
    procedure LoadFonts; override;
  end;
  TTestScene=class(TGameScene)
    frame:integer;
    procedure Render; override;
    function GetArea:TRect; override;
  end;
var
  rt:TTexture;
  img:TBitmapImage;
  root:TUIElement;

// Draw the same real element through either drawer; compare all pixels.
function Capture(element:TUIElement;fx:boolean):TPixels;
var y:integer;
begin
  result:=nil;
  gfx.BeginPaint(rt);
  try
    gfx.target.Clear($FF203040,-1,-1);
    gfx.target.BlendMode(blAlpha);
    element.globalRect:=element.GetPosOnScreen;
    if fx then DrawTextFXStyle(element) else DrawDefaultUI(element);
    gfx.CopyFromBackbuffer(0,0,img);
    SetLength(result,W*H);
    for y:=0 to H-1 do Move(img.ScanLine(y)^,result[y*W],W*4);
  finally
    gfx.EndPaint;
  end;
end;

function EqualPixels(const a,b:TPixels):boolean;
var i:integer;
begin
  result:=length(a)=length(b);
  if not result then exit;
  for i:=0 to high(a) do if a[i]<>b[i] then exit(false);
end;

procedure TestPlainWrapper;
const scales:array[0..3] of single=(1.0,1.25,1.5,2.0);
var b:TUIButton; i,state:integer; plain,fx:TPixels;
begin
  StartTest('No-effect wrapper preserves default rendering at four scales/states');
  b:=TUIButton.Create(180,32,root).Setup('Same caption');
  try
    b.SetPos(12.25,12.25,pivotTopLeft);
    b.style.Assign(BUTTON_STYLE);
    for i:=0 to high(scales) do begin
      root.scale:=scales[i];
      for state:=0 to 3 do begin
        b.pressed:=state=2;
        b.flags.enabled:=state<>3;
        underMouse:=nil;
        if state=1 then underMouse:=b;
        plain:=Capture(b,false);
        fx:=Capture(b,true);
        Check(EqualPixels(plain,fx),'wrapper differs at scale/state '+IntToStr(i)+'/'+IntToStr(state));
      end;
    end;
  finally
    underMouse:=nil;
    root.scale:=1;
    b.Free;
  end;
  EndTest;
end;

procedure TestCaptionSuppression;
var b:TUIButton; withCaption,emptyCaption:TPixels; mode:integer;
begin
  StartTest('Caption hiding retains semantics in both drawers');
  b:=TUIButton.Create(180,32,root).Setup('Retained caption');
  try
    b.style.Assign(BUTTON_STYLE+'caption-display:none; text-glow-blur:3;');
    for mode:=0 to 1 do begin
      b.caption:='Retained caption';
      withCaption:=Capture(b,mode=1);
      Check(b.caption='Retained caption','drawer mutated caption');
      b.caption:='';
      emptyCaption:=Capture(b,mode=1);
      Check(EqualPixels(withCaption,emptyCaption),'hidden caption still draws');
    end;
  finally b.Free; end;
  EndTest;
end;

procedure TestContentShift;
const scales:array[0..3] of single=(1.0,1.25,1.5,2.0);
var b:TUIButton; icon,caption:TUIImage; checkBox:TUICheckBox;
  toggle:TUIToggleButton; i:integer; r0,r1,c0,c1:TRect;
begin
  StartTest('Whole content shift, repeated draw, release and checkbox exclusion');
  b:=TUIButton.Create(180,32,root).Setup('Container');
  icon:=TUIImage.Create(20,32,b);
  caption:=TUIImage.Create(130,32,b);
  caption.SetPos(30,0,pivotTopLeft);
  try
    b.SetPos(12.25,12.25,pivotTopLeft);
    b.style.Assign(BUTTON_STYLE+'caption-display:none;');
    Check(icon.shape=shapeEmpty,'image intercepts button input');
    Check(caption.shape=shapeEmpty,'caption intercepts button input');
    for i:=0 to high(scales) do begin
      root.scale:=scales[i];
      b.pressed:=false;
      Capture(b,false);
      r0:=icon.GetPosOnScreen; c0:=caption.GetPosOnScreen;
      b.pressed:=true;
      Capture(b,false);
      r1:=icon.GetPosOnScreen; c1:=caption.GetPosOnScreen;
      Check(abs(b.scroll.Y+1)<0.001,'pressed scroll is not absolute');
      Check((r1.Top-r0.Top=c1.Top-c0.Top) and (r1.Top>r0.Top),
        'icon and caption shift differently at scale '+IntToStr(i));
      Capture(b,false);
      Check(EqualRect(r1,icon.GetPosOnScreen),'repeated draw accumulates shift');
      b.pressed:=false;
      Capture(b,false);
      Check(EqualRect(r0,icon.GetPosOnScreen),'release does not restore content');
    end;
    root.scale:=1;
    b.style.SetAttr('content-press-offset','0');
    b.pressed:=true;
    Capture(b,false);
    Check(b.scroll.Y=0,'zero content offset ignored');
  finally root.scale:=1; b.Free; end;
  checkBox:=TUICheckBox.Create(180,32,root).Setup('Check',true);
  try
    checkBox.style.Assign(BUTTON_STYLE);
    Capture(checkBox,false);
    Check(checkBox.scroll.Y=0,'checked checkbox shifts children');
  finally checkBox.Free; end;
  toggle:=TUIToggleButton.Create(180,32,root).Setup('Toggle',true);
  try
    toggle.style.Assign(BUTTON_STYLE);
    Capture(toggle,true);
    Check(toggle.scroll.Y=-1,'toggled button fails to shift children');
    toggle.toggled:=false;
    Capture(toggle,true);
    Check(toggle.scroll.Y=0,'untoggled button leaves a shift');
  finally toggle.Free; end;
  EndTest;
end;

procedure TestCaptionChild;
var b:TUIButton; child:TUIImage; first,second,expected:TPixels;
  labelView:TUILabel; privateContext:TObject; r:TRect; x,y:integer; outsideClear:boolean;
begin
  StartTest('Caption child follows parent text/state and label alignment');
  b:=TUIButton.Create(180,32,root).Setup('First');
  try
    b.style.Assign(BUTTON_STYLE+'caption-display:none;');
    child:=TUIImage.Create(180,32,b);
    child.style.Assign('caption-source:parent; text-glow-blur:3;');
    Capture(b,false); // resolve parent state before drawing its child
    first:=Capture(child,true);
    b.caption:='Second';
    second:=Capture(child,true);
    Check(not EqualPixels(first,second),'child cached a stale parent caption');
    b.flags.enabled:=false;
    Capture(b,false);
    first:=Capture(child,true);
    Check(not EqualPixels(first,second),'child ignored disabled parent state');
    // Compare parent-sourced and own text through the same standalone image view.
    b.flags.enabled:=true;
    Capture(b,false);
    first:=Capture(child,true);
    child.caption:=b.caption;
    child.style.Assign(BUTTON_STYLE+'text-glow-blur:3;');
    second:=Capture(child,true);
    Check(EqualPixels(first,second),'parent typography differs from an equivalent own caption');
    // A caption view must preserve another drawer's private parent context.
    b.styleContext.Free;
    privateContext:=TObject.Create;
    b.styleContext:=privateContext;
    child.style.Assign('caption-source:parent; text-glow-blur:3;');
    Capture(child,true);
    Check(b.styleContext=privateContext,'caption child replaced the parent private context');
    child.style.SetAttr('font-size','6');
    second:=Capture(child,true);
    Check(not EqualPixels(first,second),'child font override ignored');
    // Long effect text must not spill into an adjacent icon's area.
    b.caption:='A caption much wider than its own view';
    child.size.x:=60;
    child.style.Assign('caption-source:parent; text-glow-blur:4;');
    FlushTextFXCache;
    first:=Capture(child,true);
    second:=Capture(child,true);
    Check(EqualPixels(first,second),'first bake and cached draw use different clipping');
    r:=child.GetClientPosOnScreen;
    outsideClear:=true;
    for y:=0 to H-1 do for x:=0 to W-1 do
      if not PtInRect(r,Types.Point(x,y)) and (first[y*W+x]<>$FF203040) then outsideClear:=false;
    Check(outsideClear,'caption effects escape their view rectangle');
  finally b.Free; end;
  labelView:=TUILabel.Create(180,32,root).Setup('Alignment');
  try
    labelView.align:=taLeft;
    labelView.style.Assign('text-align:right;');
    first:=Capture(labelView,true);
    labelView.align:=taRight;
    labelView.style.Assign('');
    expected:=Capture(labelView,true);
    Check(EqualPixels(first,expected),'label.align overrides explicit text-align');
    labelView.verticalOffset:=5;
    first:=Capture(labelView,true);
    expected:=Capture(labelView,false);
    Check(EqualPixels(first,expected),'label vertical offset differs from the base drawer');
    labelView.caption:='Justified label text';
    labelView.align:=taJustify;
    labelView.style.Assign('font:TestTextFXVector; font-size:12; text-glow-blur:3;');
    labelView.size.x:=txt.Width(txt.GetFont('TestTextFXVector',12),labelView.caption)+8;
    first:=Capture(labelView,true);
    expected:=Capture(labelView,false);
    Check(EqualPixels(first,expected),'justified label fallback differs from the base drawer');
    labelView.align:=taLeft;
    second:=Capture(labelView,false);
    Check(not EqualPixels(expected,second),'justification fixture must differ from ordinary left alignment');
  finally labelView.Free; end;
  EndTest;
end;

procedure TestChildStateOverrides;
const
  stateNames:array[0..2] of String8=('hover','pressed','disabled');
  overrides:array[0..2] of String8=(
    'text-glow-color:#FF3020; text-glow-blur:4; text-glow-spread:1; font-size:18;',
    'text-glow-color:#20FF30; text-glow-blur:2; text-glow-spread:2; font-size:16;',
    'text-glow-color:#3020FF; text-glow-blur:3; text-glow-spread:3; font-size:14;');
  base='caption-source:parent; font-size:12; text-glow-color:#FFFFFF; text-glow-blur:1;';
var b:TUIButton; child:TUILabel; i:integer;
  actual,expected,basePixels:TPixels; ownStates:String8;
begin
  StartTest('Child effect and font state blocks use the caption source states');
  b:=TUIButton.Create(220,50,root).Setup('State caption');
  try
    b.style.Assign(BUTTON_STYLE+'caption-display:none;');
    child:=TUILabel.Create(220,50,b);
    child.shape:=shapeEmpty;
    // Named references must use the same source states as local state blocks.
    for i:=0 to 2 do begin
      Styles['test-textfx-child']:=':hover { '+overrides[0]+' }';
      b.pressed:=i=1;
      b.flags.enabled:=i<>2;
      underMouse:=nil;
      if i=0 then underMouse:=b;
      Capture(b,false);
      child.style.Assign(base);
      basePixels:=Capture(child,true);
      // A child's independently active hover must not select its hover override
      // while the caption source is pressed or disabled.
      child.style.Assign(base+'@test-textfx-child;'+
        ':pressed { '+overrides[1]+' } :disabled { '+overrides[2]+' }');
      child.SetState('hover',true);
      ownStates:=child.style.activeStates;
      actual:=Capture(child,true);
      Check(child.style.activeStates=ownStates,'drawing mutates child states');
      child.style.Assign(base+overrides[i]);
      expected:=Capture(child,true);
      Check(not EqualPixels(basePixels,expected),'state fixture must change rendered pixels');
      Check(EqualPixels(actual,expected),'child state override ignored for '+stateNames[i]);
      // Give the reference a conflicting value to verify local state priority.
      Styles['test-textfx-child']:=':'+stateNames[i]+
        ' { text-glow-color:#804080; font-size:6; }';
      child.style.Assign(base+'@test-textfx-child; :'+stateNames[i]+' { '+overrides[i]+' }');
      actual:=Capture(child,true);
      Check(EqualPixels(actual,expected),'local state override ignored for '+stateNames[i]);
      // Isolate typography from effects so a correct glow cannot hide font errors.
      child.style.Assign(base+':'+stateNames[i]+' { font:TestTextFXVector; font-size:20; }');
      actual:=Capture(child,true);
      child.style.Assign(base+'font:TestTextFXVector; font-size:20;');
      expected:=Capture(child,true);
      Check(not EqualPixels(basePixels,expected),'font state fixture must change rendered pixels');
      Check(EqualPixels(actual,expected),'child font state override ignored for '+stateNames[i]);
    end;
    b.pressed:=false;
    b.flags.enabled:=true;
    underMouse:=nil;
    Capture(b,false);
    child.style.Assign(base);
    expected:=Capture(child,true);
    child.style.Assign(base+':hover { '+overrides[0]+' }');
    child.SetState('hover',true);
    actual:=Capture(child,true);
    Check(EqualPixels(actual,expected),'own hover overrides an idle caption source');
  finally
    underMouse:=nil;
    Styles.Remove('test-textfx-child');
    b.Free;
  end;
  EndTest;
end;

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestTextFXStyle';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,200);
end;
procedure TTestApp.LoadFonts;
begin
  inherited;
  // Reuse the vector font fixture used by TextDemo; raster fallback can hide
  // justification differences, so this check explicitly selects a vector font.
  txt.LoadFont(ExtractFilePath(ParamStr(0))+'../demo/legacy/EngineTest/res/arial.ttf','TestTextFXVector');
end;
procedure TTestApp.CreateScenes;
begin
  inherited;
  TTestScene.Create('Test',true,window);
  game.SwitchToScene('Test');
end;
function TTestScene.GetArea:TRect;
begin result:=Rect(0,0,window.canvasWidth,window.canvasHeight); end;
procedure TTestScene.Render;
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(frame);
  if frame<>3 then exit;
  try
    rt:=AllocImage(W,H,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestTextFXStyle');
    img:=TBitmapImage.Create(W,H,ipfARGB);
    root:=TUIElement.Create(W,H,nil);
    try
      TestPlainWrapper;
      TestCaptionSuppression;
      TestContentShift;
      TestCaptionChild;
      TestChildStateOverrides;
    finally
      underMouse:=nil;
      root.Free;
      img.Free;
      FlushTextFXCache;
      FreeImage(rt);
    end;
  except on e:Exception do begin writeln('EXCEPTION: ',e.Message); inc(testsFailed); end; end;
  Signal('Engine\Cmd\Exit');
end;
var app:TTestApp;
begin
  app:=TTestApp.Create;
  app.Prepare;
  app.Run;
  app.Free;
  if testsFailed=0 then writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal)); ExitCode:=1; end;
  if IsDebuggerPresent then readln;
end.
