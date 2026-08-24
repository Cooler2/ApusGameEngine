// Headless unit test for the working-surface resolver (R-31, stage A).
// Covers: ValidateSurfaceConfig rules, ResolveSurface for every mode of
// Work/surface_size_design.md §6 (table in Work/R-31_api_design.md §10),
// client<->canvas transforms incl. round-trip on display rect edges,
// safe area mapping, renderScale, FitToBudget and change masks.
{$APPTYPE CONSOLE}
program TestSurface;
uses
  SysUtils,
  Types,
  Apus.Core,
  Apus.Engine.Types;

{$I ..\Base\tests\Test.inc}

function Cfg(canvasW,canvasH,renderW,renderH:integer;fit:TSurfaceFit;
  distortion:boolean=false):TSurfaceConfig;
 begin
  result.Init;
  result.canvasSize:=MakeSize(canvasW,canvasH);
  result.renderSize:=MakeSize(renderW,renderH);
  result.fit:=fit;
  result.allowAspectDistortion:=distortion;
 end;

function Inp(w,h:integer):TSurfaceInput;
 begin
  result.Init(w,h);
 end;

function Resolve(const input:TSurfaceInput;const config:TSurfaceConfig):TSurfaceState;
 begin
  ValidateSurfaceConfig(config);
  ResolveSurface(input,config,result);
 end;

function ValidationFails(const config:TSurfaceConfig):boolean;
 begin
  result:=false;
  try
   ValidateSurfaceConfig(config);
  except
   on EError do result:=true;
  end;
 end;

function ResolveFails(const input:TSurfaceInput;const config:TSurfaceConfig):boolean;
 var
  st:TSurfaceState;
 begin
  result:=false;
  try
   ResolveSurface(input,config,st);
  except
   on EError do result:=true;
  end;
 end;

function IsSize(const s:TSize;w,h:integer):boolean;
 begin
  result:=(s.cx=w) and (s.cy=h);
 end;

function IsRect(const r:TRect;l,t,rt,b:integer):boolean;
 begin
  result:=(r.Left=l) and (r.Top=t) and (r.Right=rt) and (r.Bottom=b);
 end;

procedure TestValidation;
 begin
  StartTest('Validation');
  Check(not ValidationFails(Cfg(0,0,0,0,TSurfaceFit.fill)),'default config valid');
  Check(ValidationFails(Cfg(0,0,320,0,TSurfaceFit.fill)),'half-fixed render rejected');
  Check(ValidationFails(Cfg(-1,0,0,0,TSurfaceFit.fill)),'negative size rejected');
  Check(ValidationFails(Cfg(0,0,0,0,TSurfaceFit.center)),'center requires fixed render');
  Check(ValidationFails(Cfg(320,180,0,0,TSurfaceFit.integerScale)),'integerScale requires fixed render');
  Check(ValidationFails(Cfg(1280,800,0,0,TSurfaceFit.fill)),'fixed canvas + fill rejected');
  Check(not ValidationFails(Cfg(1280,800,0,0,TSurfaceFit.fill,true)),'fixed canvas + fill allowed with distortion flag');
  Check(not ValidationFails(Cfg(1280,800,0,0,TSurfaceFit.keepAspect)),'fixed canvas + keepAspect valid');
  Check(ValidationFails(Cfg(1280,800,1920,1080,TSurfaceFit.keepAspect)),'canvas/render aspect conflict rejected');
  Check(not ValidationFails(Cfg(1280,800,1920,1200,TSurfaceFit.keepAspect)),'canvas/render same aspect valid');
  Check(not ValidationFails(Cfg(720,0,0,0,TSurfaceFit.fill)),'half-fixed canvas + fill valid');
  EndTest;
 end;

// §6.1 / mode A: adaptive desktop
procedure TestAdaptive;
 var
  st:TSurfaceState;
 begin
  StartTest('Adaptive (6.1)');
  st:=Resolve(Inp(1600,900),Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(IsRect(st.displayRect,0,0,1600,900),'displayRect = client');
  Check(IsSize(st.canvasSize,1600,900),'canvas = client');
  Check(IsSize(st.renderSize,1600,900),'render = client');
  Check(st.mechanism=TSurfaceMechanism.direct,'mechanism direct');
  Check(not st.needRT,'no RT');
  Check(IsRect(st.safeAreaRect,0,0,1600,900),'safe area = whole canvas');
  Check(st.dpi=96,'dpi passed through');
  st:=Resolve(Inp(1280,1024),Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(IsSize(st.canvasSize,1280,1024),'resize follows client');
  EndTest;
 end;

// §6.2 sharp / mode B: fixed canvas, native render, keepAspect (matrix)
procedure TestFixedSharp;
 var
  st:TSurfaceState;
 begin
  StartTest('Fixed canvas sharp (6.2)');
  st:=Resolve(Inp(1920,1200),Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  Check(IsRect(st.displayRect,0,0,1920,1200),'same aspect: whole client');
  Check(IsSize(st.renderSize,1920,1200),'render native = display');
  Check(IsSize(st.canvasSize,1280,800),'canvas fixed');
  Check(st.mechanism=TSurfaceMechanism.matrix,'mechanism matrix');
  Check(not st.needRT,'no RT');
  st:=Resolve(Inp(3440,1440),Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  Check(IsRect(st.displayRect,568,0,2872,1440),'ultrawide: 2304x1440 centered');
  Check(IsSize(st.renderSize,2304,1440),'render = display rect');
  Check(IsSize(st.canvasSize,1280,800),'canvas fixed');
  st:=Resolve(Inp(1600,1200),Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  Check(IsRect(st.displayRect,0,100,1600,1100),'4:3 client: bars top/bottom');
  EndTest;
 end;

// §6.2 cheap / mode C / §6.10.5: fixed canvas + fixed render (blit)
procedure TestFixedCheap;
 var
  st:TSurfaceState;
 begin
  StartTest('Fixed canvas cheap (6.2)');
  st:=Resolve(Inp(1920,1200),Cfg(1280,800,1280,800,TSurfaceFit.keepAspect));
  Check(IsRect(st.displayRect,0,0,1920,1200),'whole client');
  Check(IsSize(st.renderSize,1280,800),'render fixed');
  Check(IsSize(st.canvasSize,1280,800),'canvas fixed');
  Check(st.mechanism=TSurfaceMechanism.blit,'mechanism blit');
  Check(st.needRT,'RT needed');
  st:=Resolve(Inp(2560,1440),Cfg(1366,768,1366,768,TSurfaceFit.keepAspect));
  Check(IsRect(st.displayRect,0,0,2560,1440),'16:9 -> 16:9 whole client (6.10.5)');
  Check(IsSize(st.renderSize,1366,768),'render fixed 1366x768');
  EndTest;
 end;

// §6.3 pixel art + mode E (center)
procedure TestPixelArt;
 var
  st:TSurfaceState;
 begin
  StartTest('Pixel art (6.3)');
  st:=Resolve(Inp(1920,1080),Cfg(320,180,320,180,TSurfaceFit.integerScale));
  Check(IsRect(st.displayRect,0,0,1920,1080),'1080p: x6 exact');
  st:=Resolve(Inp(1600,900),Cfg(320,180,320,180,TSurfaceFit.integerScale));
  Check(IsRect(st.displayRect,0,0,1600,900),'900p: x5 exact');
  st:=Resolve(Inp(1680,1050),Cfg(320,180,320,180,TSurfaceFit.integerScale));
  Check(IsRect(st.displayRect,40,75,1640,975),'1680x1050: x5 centered with frame');
  Check(IsSize(st.renderSize,320,180),'render stays 320x180');
  Check(IsSize(st.canvasSize,320,180),'canvas 320x180');
  Check(st.needRT,'RT needed');
  st:=Resolve(Inp(300,170),Cfg(320,180,320,180,TSurfaceFit.integerScale));
  Check(IsRect(st.displayRect,-10,-5,310,175),'client smaller: k=1, cropped');
  st:=Resolve(Inp(1920,1080),Cfg(320,180,320,180,TSurfaceFit.center));
  Check(IsRect(st.displayRect,800,450,1120,630),'center: 1:1 centered (mode E)');
  EndTest;
 end;

// §6.4 pixel budget via hook (FitToBudget) + renderScale
procedure TestBudget;
 var
  st:TSurfaceState;
  config:TSurfaceConfig;
  surfIn:TSurfaceInput;
 begin
  StartTest('Pixel budget (6.4)');
  Check(IsSize(FitToBudget(MakeSize(1920,1080),1920,1080),0,0),'fits exactly -> native');
  Check(IsSize(FitToBudget(MakeSize(1280,720),1920,1080),0,0),'smaller -> native');
  Check(IsSize(FitToBudget(MakeSize(3840,2160),1920,1080),1920,1080),'4K -> FullHD');
  Check(IsSize(FitToBudget(MakeSize(3440,1440),1920,1080),1920,804),'ultrawide: width-limited, aspect kept');
  Check(IsSize(FitToBudget(MakeSize(1080,2400),1920,1080),486,1080),'portrait: height-limited');
  // hook result applied: canvas flexible, render fixed, fill
  config:=Cfg(0,0,0,0,TSurfaceFit.fill);
  config.renderSize:=FitToBudget(MakeSize(3840,2160),1920,1080);
  st:=Resolve(Inp(3840,2160),config);
  Check(IsRect(st.displayRect,0,0,3840,2160),'fill: whole client');
  Check(IsSize(st.renderSize,1920,1080),'render 1920x1080');
  Check(IsSize(st.canvasSize,3840,2160),'canvas stays native');
  Check(st.mechanism=TSurfaceMechanism.blit,'blit');
  // fixed-design variant
  config:=Cfg(1920,1080,1920,1080,TSurfaceFit.keepAspect);
  st:=Resolve(Inp(3840,2160),config);
  Check(IsSize(st.canvasSize,1920,1080),'fixed design canvas');
  // hook picking a foreign aspect with fill -> resolver rejects
  config:=Cfg(0,0,1920,1080,TSurfaceFit.fill);
  Check(ResolveFails(Inp(3440,1440),config),'fill + foreign render aspect rejected at resolve');
  config.fit:=TSurfaceFit.keepAspect;
  st:=Resolve(Inp(3440,1440),config);
  Check(IsRect(st.displayRect,440,0,3000,1440),'keepAspect: 2560x1440 centered');
  Check(IsSize(st.canvasSize,2560,1440),'flexible canvas = display rect');
  config:=Cfg(0,0,1920,1080,TSurfaceFit.fill,true);
  st:=Resolve(Inp(3440,1440),config);
  Check(IsRect(st.displayRect,0,0,3440,1440),'distortion allowed: fill');
  // renderScale (supersampling / dynamic resolution)
  surfIn:=Inp(1280,720);
  surfIn.renderScale:=2.0;
  st:=Resolve(surfIn,Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(IsSize(st.renderSize,2560,1440),'renderScale x2');
  Check(IsSize(st.canvasSize,1280,720),'canvas unaffected by renderScale');
  Check(st.needRT,'renderScale forces RT');
  surfIn.renderScale:=0.5;
  st:=Resolve(surfIn,Cfg(320,180,320,180,TSurfaceFit.integerScale));
  Check(IsRect(st.displayRect,0,0,1280,720),'renderScale does not affect display rect');
  Check(IsSize(st.renderSize,160,90),'renderScale x0.5 on fixed render');
  // presentation shader forces RT
  surfIn:=Inp(1280,720);
  surfIn.forceRT:=true;
  st:=Resolve(surfIn,Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(st.needRT and (st.mechanism=TSurfaceMechanism.blit),'forceRT -> blit');
  Check(IsSize(st.renderSize,1280,720),'forceRT keeps native render size');
  EndTest;
 end;

// §6.5 / §6.6 mobile: one canvas axis fixed
procedure TestMobile;
 var
  st:TSurfaceState;
  config:TSurfaceConfig;
 begin
  StartTest('Mobile (6.5/6.6)');
  st:=Resolve(Inp(1080,2400),Cfg(720,0,0,0,TSurfaceFit.fill));
  Check(IsRect(st.displayRect,0,0,1080,2400),'portrait: whole surface');
  Check(IsSize(st.canvasSize,720,1600),'portrait canvas 720x1600');
  Check(IsSize(st.renderSize,1080,2400),'portrait render native');
  Check(st.mechanism=TSurfaceMechanism.matrix,'matrix (canvas<>render)');
  st:=Resolve(Inp(450,1000),Cfg(720,0,0,0,TSurfaceFit.fill));
  Check(IsSize(st.canvasSize,720,1600),'desktop preview: same canvas');
  Check(IsSize(st.renderSize,450,1000),'desktop preview: render = window');
  config:=Cfg(720,0,810,1800,TSurfaceFit.fill);
  st:=Resolve(Inp(1080,2400),config);
  Check(IsSize(st.renderSize,810,1800),'perf option: fixed render');
  Check(IsSize(st.canvasSize,720,1600),'perf option: canvas untouched');
  Check(st.needRT,'perf option: RT');
  st:=Resolve(Inp(2400,1080),Cfg(0,540,0,0,TSurfaceFit.fill));
  Check(IsSize(st.canvasSize,1200,540),'landscape 2400x1080 -> 1200x540');
  st:=Resolve(Inp(1920,1080),Cfg(0,540,0,0,TSurfaceFit.fill));
  Check(IsSize(st.canvasSize,960,540),'landscape 1920x1080 -> 960x540');
  EndTest;
 end;

procedure TestTransforms;
 var
  st:TSurfaceState;
  p,q:TPoint;
  inside:boolean;
 begin
  StartTest('Transforms');
  // letterboxed matrix mode: display 568..2872 x 0..1440, canvas 1280x800
  st:=Resolve(Inp(3440,1440),Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  p:=st.ClientToCanvas(Point(568,0));
  Check((p.x=0) and (p.y=0),'display top-left -> canvas origin');
  p:=st.ClientToCanvas(Point(2872,1440));
  Check((p.x=1280) and (p.y=800),'display bottom-right -> canvas size');
  q:=st.CanvasToClient(Point(0,0));
  Check((q.x=568) and (q.y=0),'canvas origin -> display top-left');
  q:=st.CanvasToClient(Point(1280,800));
  Check((q.x=2872) and (q.y=1440),'canvas size -> display bottom-right');
  q:=st.CanvasToClient(st.ClientToCanvas(Point(1720,720)));
  Check((abs(q.x-1720)<=1) and (abs(q.y-720)<=1),'round-trip center within 1px');
  q:=st.CanvasToClient(st.ClientToCanvas(Point(2871,1439)));
  Check((abs(q.x-2871)<=1) and (abs(q.y-1439)<=1),'round-trip last pixel within 1px');
  inside:=st.TryClientToCanvas(Point(100,700),p);
  Check(not inside,'left bar: outside');
  Check(p.x<0,'raw transform not clamped');
  inside:=st.TryClientToCanvas(Point(568,0),p);
  Check(inside,'top-left edge: inside');
  inside:=st.TryClientToCanvas(Point(2872,1439),p);
  Check(not inside,'right edge (exclusive): outside');
  inside:=st.TryClientToCanvas(Point(2871,1439),p);
  Check(inside,'last pixel: inside');
  // 1:1 mode: identity
  st:=Resolve(Inp(1600,900),Cfg(0,0,0,0,TSurfaceFit.fill));
  p:=st.ClientToCanvas(Point(123,456));
  Check((p.x=123) and (p.y=456),'direct mode: identity');
  // downscaled preview: canvas larger than client
  st:=Resolve(Inp(450,1000),Cfg(720,0,0,0,TSurfaceFit.fill));
  p:=st.ClientToCanvas(Point(450,1000));
  Check((p.x=720) and (p.y=1600),'preview: client corner -> canvas corner');
  EndTest;
 end;

procedure TestSafeArea;
 var
  st:TSurfaceState;
  surfIn:TSurfaceInput;
 begin
  StartTest('Safe area');
  surfIn:=Inp(1080,2400);
  surfIn.safeInsets:=Rect(0,120,0,60);
  st:=Resolve(surfIn,Cfg(720,0,0,0,TSurfaceFit.fill));
  Check(IsRect(st.safeAreaRect,0,80,720,1560),'portrait insets -> canvas (x2/3)');
  surfIn.safeInsets:=Rect(0,100,0,0); // 100/1.5=66.67 -> ceil 67
  st:=Resolve(surfIn,Cfg(720,0,0,0,TSurfaceFit.fill));
  Check(st.safeAreaRect.Top=67,'inward rounding: top ceil');
  surfIn:=Inp(3440,1440);
  surfIn.safeInsets:=Rect(100,0,100,0); // inside the bars: no effect
  st:=Resolve(surfIn,Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  Check(IsRect(st.safeAreaRect,0,0,1280,800),'insets inside letterbox bars: whole canvas');
  surfIn.safeInsets:=Rect(668,0,0,0); // 100px into the display rect (568+100); 100*1280/2304=55.56 -> 56
  st:=Resolve(surfIn,Cfg(1280,800,0,0,TSurfaceFit.keepAspect));
  Check(st.safeAreaRect.Left=56,'inset crossing the display rect edge');
  EndTest;
 end;

procedure TestChanges;
 var
  a,b:TSurfaceState;
  surfIn:TSurfaceInput;
 begin
  StartTest('Change mask');
  a:=Resolve(Inp(1600,900),Cfg(0,0,0,0,TSurfaceFit.fill));
  b:=Resolve(Inp(1600,900),Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(b.Diff(a)=[],'same input: no changes');
  b:=Resolve(Inp(1280,1024),Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(b.Diff(a)=[TSurfaceChange.client,TSurfaceChange.canvas,TSurfaceChange.render,
    TSurfaceChange.placement,TSurfaceChange.safeArea],'resize: everything but dpi');
  surfIn:=Inp(1600,900);
  surfIn.renderScale:=0.75;
  b:=Resolve(surfIn,Cfg(0,0,0,0,TSurfaceFit.fill));
  Check(b.Diff(a)=[TSurfaceChange.render],'dynamic resolution: only render');
  b:=Resolve(Inp(1600,900),Cfg(0,0,0,0,TSurfaceFit.fill));
  b.dpi:=144;
  Check(b.Diff(a)=[TSurfaceChange.dpi],'dpi only');
  Check(b.ToString<>'','ToString produces text');
  EndTest;
 end;

begin
  writeln('=== TestSurface ===');
  TestValidation;
  TestAdaptive;
  TestFixedSharp;
  TestFixedCheap;
  TestPixelArt;
  TestBudget;
  TestMobile;
  TestTransforms;
  TestSafeArea;
  TestChanges;
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
