// GPU test for face culling: a TCullMode keeps the same faces whether the frame goes
// to the backbuffer or to a texture target (the projection flips Y only for the
// backbuffer, which mirrors the winding; the backend must compensate).
// Needs a real GL context (a window is shown), so CI only compiles it.
{$APPTYPE CONSOLE}
program TestCulling;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Apus.Core,
  Apus.Images,
  Apus.EventMan,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.GameApp,
  Apus.Engine.Scene;

{$I ..\Base\tests\Test.inc}

const
  W=64;
  H=64;
  GRAY=$FF808080; // background
  RED=$FFC02020;
  PROBE_X=20; // a pixel inside the triangle
  PROBE_Y=20;

type
  TTestApp=class(TGameApplication)
    procedure SetupApplication; override;
    procedure CreateScenes; override;
  end;

  TTestScene=class(TGameScene)
    frame:integer;
    procedure Render; override;
    function GetArea:TRect; override;
  end;

var
  rt:TTexture;
  img:TBitmapImage;

// Draw a triangle that is clockwise on the canvas (y goes down) with the given mode
// into the current target and tell whether it was drawn
function DrawnWith(mode:TCullMode):boolean;
begin
  gfx.target.Clear(GRAY,-1,-1);
  transform.DefaultView;
  gfx.SetCullMode(mode);
  draw.FillTriangle(10,10,50,10,10,50,RED,RED,RED);
  gfx.SetCullMode(TCullMode.DrawAll);
  if img=nil then img:=TBitmapImage.Create(W,H,ipfARGB);
  gfx.CopyFromBackbuffer(0,0,img);
  result:=PCardinal(UIntPtr(img.ScanLine(PROBE_Y))+UIntPtr(PROBE_X*4))^=RED;
end;

procedure TestTexture;
var
  cw,ccw:boolean;
begin
  StartTest('Culling in a texture target');
  gfx.BeginPaint(rt);
  try
    cw:=DrawnWith(TCullMode.DrawCW);
    ccw:=DrawnWith(TCullMode.DrawCCW);
  finally
    gfx.EndPaint;
  end;
  Check(cw,'DrawCW: a clockwise triangle is culled');
  Check(not ccw,'DrawCCW: a clockwise triangle is drawn');
  EndTest;
end;

procedure TestBackbuffer;
var
  cw,ccw:boolean;
begin
  StartTest('Culling in the backbuffer');
  cw:=DrawnWith(TCullMode.DrawCW);
  ccw:=DrawnWith(TCullMode.DrawCCW);
  Check(cw,'DrawCW: a clockwise triangle is culled');
  Check(not ccw,'DrawCCW: a clockwise triangle is drawn');
  EndTest;
end;

{ TTestApp }

procedure TTestApp.SetupApplication;
begin
  inherited;
  appSetup.title:='TestCulling';
  requestBackend.graphicsAPI:=gaOpenGL2;
  windowSetup.size:=MakeSize(320,200);
end;

procedure TTestApp.CreateScenes;
begin
  inherited;
  TTestScene.Create('Test',true,window);
  game.SwitchToScene('Test');
end;

{ TTestScene }

function TTestScene.GetArea:TRect;
begin
  result:=Rect(0,0,window.canvasWidth,window.canvasHeight);
end;

procedure TTestScene.Render;
begin
  gfx.target.Clear($FF202020,-1,-1);
  inc(frame);
  if frame<>3 then exit; // let the engine settle first
  try
    rt:=AllocImage(W,H,pfRenderTargetAlpha,aiTexture+aiRenderTarget+aiClampUV,'TestCullingRT');
    try
      TestTexture;
      TestBackbuffer;
    finally
      FreeAndNil(img);
      FreeImage(rt);
    end;
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
  app.Prepare;
  app.Run;
  app.Free;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
