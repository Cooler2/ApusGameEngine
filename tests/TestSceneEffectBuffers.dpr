// Two simultaneous full-screen transitions must keep independent GPU buffers (Spectro B-55:
// a transition started while another one plays). Requires a GL window: the smoke suites only
// compile it, run it locally.
{$APPTYPE CONSOLE}
program TestSceneEffectBuffers;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,Types,Apus.Core,Apus.Images,Apus.EventMan,
  Apus.Engine.API,Apus.Engine.Types,Apus.Engine.GameApp,Apus.Engine.Scene,
  Apus.Engine.SceneEffects;

{$I ..\Base\tests\Test.inc}

const
  FIRST_COLOR=$FFCC2244;
  SECOND_COLOR=$FF2266CC;

type
  TProbeEffect=class(TTransitionEffect)
    function Texture:TTexture;
    function Fallback:boolean;
  end;

  TTestScene=class(TGameScene)
    color:cardinal;
    driver:boolean;
    frame:integer;
    procedure Render; override;
    function GetArea:TRect; override;
  end;

  TTestApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure CreateScenes; override;
  end;

var
  baseScene,firstScene,secondScene:TTestScene;

function TProbeEffect.Texture:TTexture;
begin
  result:=buffer;
end;

function TProbeEffect.Fallback:boolean;
begin
  result:=dontPlay;
end;

function Pixel(texture:TTexture):cardinal;
var
  image:TBitmapImage;
begin
  image:=TBitmapImage.Create(1,1,ipfARGB);
  try
    gfx.BeginPaint(texture);
    try
      gfx.CopyFromBackbuffer(0,0,image);
      result:=PCardinal(image.ScanLine(0))^;
    finally
      gfx.EndPaint;
    end;
  finally
    image.Free;
  end;
end;

function SameColor(a,b:cardinal):boolean;
var
  i:integer;
begin
  for i:=0 to 3 do
    if abs(integer((a shr (i*8)) and $FF)-integer((b shr (i*8)) and $FF))>1 then exit(false);
  result:=true;
end;

procedure DisposeEffect(scene:TGameScene;var effect:TProbeEffect);
begin
  // Test owns these effects and disposes them outside their own Paint calls.
  scene.effect:=nil;
  FreeAndNil(effect);
end;

procedure TestOverlappingBuffers;
var
  first,second:TProbeEffect;
  survivor:TTexture;
  i:integer;
  recreatedOk,survivorOk:boolean;
begin
  first:=nil;
  second:=nil;
  StartTest('Overlapping full-screen buffers, pixels and lifetime');
  try
    first:=TProbeEffect.Create(firstScene,10000);
    first.Initialize;
    first.timer:=500;
    first.DrawScene;
    Check(not first.Fallback,'first effect fell back instead of playing');
    Check(first.Texture<>nil,'first effect has no render buffer');
    if first.Texture=nil then exit;
    Check(SameColor(Pixel(first.Texture),FIRST_COLOR),'first effect did not capture its scene');

    second:=TProbeEffect.Create(secondScene,10000);
    second.Initialize;
    Check(not second.Fallback,'second effect fell back instead of playing');
    Check(second.Texture<>nil,'second effect has no render buffer');
    if second.Texture=nil then exit;
    second.timer:=500;
    second.DrawScene;
    Check(first.Texture<>second.Texture,'two effects share one buffer object');
    Check((first.Texture.width=window.surface.renderSize.cx) and
      (first.Texture.height=window.surface.renderSize.cy),'first buffer has the wrong owner-window size');
    Check((second.Texture.width=window.surface.renderSize.cx) and
      (second.Texture.height=window.surface.renderSize.cy),'second buffer has the wrong owner-window size');
    Check(SameColor(Pixel(first.Texture),FIRST_COLOR),'second capture overwrote the first buffer');
    Check(SameColor(Pixel(second.Texture),SECOND_COLOR),'second effect did not capture its scene');
    Check((baseScene.inputLocks=1) and (firstScene.inputLocks=2) and
      (secondScene.inputLocks=1),'overlapping input locks do not belong to both effects');

    survivor:=second.Texture;
    DisposeEffect(firstScene,first);
    Check((baseScene.inputLocks=0) and (firstScene.inputLocks=1) and
      (secondScene.inputLocks=1),'freeing the first effect released another effect''s lock');
    Check(SameColor(Pixel(survivor),SECOND_COLOR),'freeing the first effect damaged the second buffer');

    // Repeated allocation also covers allocator reuse of the old effect address.
    recreatedOk:=true;
    survivorOk:=true;
    for i:=1 to 8 do begin
      firstScene.SetStatus(ssFrozen);
      firstScene.zOrder:=10;
      secondScene.zOrder:=20;
      first:=TProbeEffect.Create(firstScene,10000);
      first.Initialize;
      if first.Fallback or (first.Texture=nil) then recreatedOk:=false
      else begin
        first.DrawScene;
        if not SameColor(Pixel(first.Texture),FIRST_COLOR) then recreatedOk:=false;
      end;
      if (second.Texture<>survivor) or not SameColor(Pixel(survivor),SECOND_COLOR) then
        survivorOk:=false;
      DisposeEffect(firstScene,first);
    end;
    Check(recreatedOk,'recreated effects have no working buffer or did not capture their scene');
    Check(survivorOk,'recreating another effect replaced or overwrote the survivor');
    DisposeEffect(secondScene,second);
    Check((baseScene.inputLocks=0) and (firstScene.inputLocks=0) and
      (secondScene.inputLocks=0),'effect destruction left scene input locked');
  finally
    DisposeEffect(firstScene,first);
    DisposeEffect(secondScene,second);
    firstScene.SetStatus(ssFrozen);
    secondScene.SetStatus(ssFrozen);
    EndTest;
  end;
end;

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestSceneEffectBuffers';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,200);
end;

procedure TTestApp.CreateScenes;
begin
  inherited;
  baseScene:=TTestScene.Create('BufferTestBase',true,window);
  baseScene.driver:=true;
  baseScene.color:=$FF202020;
  firstScene:=TTestScene.Create('BufferTestFirst',true,window);
  firstScene.color:=FIRST_COLOR;
  firstScene.zOrder:=10;
  secondScene:=TTestScene.Create('BufferTestSecond',true,window);
  secondScene.color:=SECOND_COLOR;
  secondScene.zOrder:=20;
  baseScene.SetStatus(ssActive);
end;

function TTestScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.canvasWidth,window.canvasHeight);
end;

procedure TTestScene.Render;
begin
  gfx.target.Clear(color,-1,-1);
  if not driver then exit;
  inc(frame);
  if frame<>3 then exit;
  try
    TestOverlappingBuffers;
  except
    on e:Exception do begin
      writeln('EXCEPTION: ',e.Message);
      inc(testsFailed);
    end;
  end;
  Signal('Engine\Cmd\Exit');
end;

var
  app:TTestApp;
begin
  app:=TTestApp.Create;
  try app.Prepare;app.Run;finally app.Free;end;
  if testsFailed=0 then writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
