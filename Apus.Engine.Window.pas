unit Apus.Engine.Window;
interface
uses Apus.Core, Apus.Engine.Types, Apus.Engine.Scene;

const
 FRAME_TIME_RING_SIZE=512;

type
 TSceneArray=array of TGameScene;

 TFrameCapture=record
  singleFrame:boolean; // request frame capture
  // 0 - keep in data, 2 - save as JPEG, 3 - save as PNG
  target:integer;
  data:TObject;
  videoMode:boolean;
  videoPath:string;
  capturedName:string;
  capturedTime:int64;
  procedure Reset;
 end;

 TFrameTiming=record
  // Robot diagnostics toggle.
  phaseMetrics:boolean;
  // Per-frame phase timings (microseconds).
  pendingMsgUs:integer;
  lastMsgUs:integer;
  lastOnFrameUs:integer;
  lastRenderUs:integer;
  lastPresentUs:integer;
  lastSleepUs:integer;
  // Frame duration ring and per-phase history.
  frameTimeRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseMsgRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseOnFrameRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseRenderRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phasePresentRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  phaseSleepRing:array[0..FRAME_TIME_RING_SIZE-1] of integer;
  frameTimeRingPos:integer;
  frameTimeRingCount:integer;
  lastFrameTimeUs:integer;
  // High-precision frame timer used by render loop.
  frameTimer:int64;
  frameTimerReady:boolean;
  // Cached update moments for throttled FPS refresh.
  lastFpsUpdate:int64;
  lastSmoothFpsUpdate:int64;

  procedure Reset;
  procedure PushSample(deltaUs,msgUs,onFrameUs,renderUs,presentUs,sleepUs:integer);
  function CalcTrimmedFrameMs(windowUs,minFrames,trimPermille:integer; out avgMs:double):boolean;
  procedure UpdateFps(out fps,smoothFps:single);
 end;

 // Base class for engine windows.
 // Platform-specific subclasses implement abstract methods.
 // Created via ISystemPlatform.CreateWindow.
 TWindow=class
  timings:TFrameTiming;
  capture:TFrameCapture;
  scenes:TSceneArray;
  topmostScene:TGameScene; // last topmost active scene for this window
  procedure ResetSceneData;
  procedure AddScene(scene:TGameScene);
  function RemoveScene(scene:TGameScene):boolean;
  function TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
  procedure NotifyScenesModeChanged;
  procedure NotifyScenesMouseMove(mouseX,mouseY:integer);
  procedure NotifyScenesMouseBtn(c:byte;pressed:boolean);
  procedure NotifyScenesMouseWheel(value:integer);
  procedure NotifyScenesResize;
  function ProcessScenes(deltaTime:integer):boolean;

  procedure Close; virtual; abstract;
  // Apply display/window settings (mode, size, style, position) to an existing native window.
  // Called on startup and on runtime display-mode changes (Alt+Enter etc). Should also trigger resize flow so engine can recompute render/display areas.
  procedure Configure(params:TGameSettings); virtual; abstract;
  procedure Show(show:boolean); virtual; abstract;
  function GetHandle:THandle; virtual; abstract;
  procedure GetSize(out width,height:integer); virtual; abstract;
  procedure MoveTo(x,y:integer;width:integer=0;height:integer=0); virtual; abstract;
  procedure SetCaption(text:string); virtual; abstract;
  procedure Minimize; virtual; abstract;
  procedure FlashWindow(count:integer); virtual; abstract;
  procedure ProcessMessages; virtual; abstract;
  // True when native close/quit was requested for this window (used to stop main loop gracefully).
  function IsTerminated:boolean; virtual; abstract;
  procedure ScreenToClient(var p:TPoint); virtual; abstract;
  procedure ClientToScreen(var p:TPoint); virtual; abstract;
  // Graphics backend lifecycle for this window
  // Create/activate graphics context and initialize backend-facing window surface state.
  procedure InitGraph; virtual; abstract;
  // Release graphics context and backend-facing window surface resources.
  procedure DoneGraph; virtual; abstract;
  procedure PresentFrame; virtual; abstract;
  function SetVSync(divider:integer):boolean; virtual; abstract;
 end;

implementation

procedure TFrameCapture.Reset;
begin
 singleFrame:=false;
 target:=0;
 data:=nil;
 videoMode:=false;
 videoPath:='';
 capturedName:='';
 capturedTime:=0;
end;

procedure TFrameTiming.Reset;
begin
 frameTimeRingPos:=0;
 frameTimeRingCount:=0;
 lastFrameTimeUs:=0;
 StartTimer(frameTimer);
 frameTimerReady:=false;
 lastFpsUpdate:=0;
 lastSmoothFpsUpdate:=0;
 phaseMetrics:=false;
 pendingMsgUs:=0;
 lastMsgUs:=0;
 lastOnFrameUs:=0;
 lastRenderUs:=0;
 lastPresentUs:=0;
 lastSleepUs:=0;
end;

procedure TFrameTiming.PushSample(deltaUs,msgUs,onFrameUs,renderUs,presentUs,sleepUs:integer);
begin
 if deltaUs<0 then deltaUs:=0;
 if msgUs<0 then msgUs:=0;
 if onFrameUs<0 then onFrameUs:=0;
 if renderUs<0 then renderUs:=0;
 if presentUs<0 then presentUs:=0;
 if sleepUs<0 then sleepUs:=0;
 lastFrameTimeUs:=deltaUs;
 lastMsgUs:=msgUs;
 lastOnFrameUs:=onFrameUs;
 lastRenderUs:=renderUs;
 lastPresentUs:=presentUs;
 lastSleepUs:=sleepUs;
 frameTimeRing[frameTimeRingPos]:=deltaUs;
 phaseMsgRing[frameTimeRingPos]:=msgUs;
 phaseOnFrameRing[frameTimeRingPos]:=onFrameUs;
 phaseRenderRing[frameTimeRingPos]:=renderUs;
 phasePresentRing[frameTimeRingPos]:=presentUs;
 phaseSleepRing[frameTimeRingPos]:=sleepUs;
 inc(frameTimeRingPos);
 if frameTimeRingPos>=FRAME_TIME_RING_SIZE then frameTimeRingPos:=0;
 if frameTimeRingCount<FRAME_TIME_RING_SIZE then inc(frameTimeRingCount);
end;

function TFrameTiming.CalcTrimmedFrameMs(windowUs,minFrames,trimPermille:integer; out avgMs:double):boolean;
var
 i,j,idx,count,trim,n:integer;
 totalUs:int64;
 sample,tmp:integer;
 values:array[0..FRAME_TIME_RING_SIZE-1] of integer;
begin
 result:=false;
 avgMs:=0;
 if frameTimeRingCount<=0 then exit;
 if minFrames<1 then minFrames:=1;
 if trimPermille<0 then trimPermille:=0;
 if trimPermille>450 then trimPermille:=450;

 idx:=frameTimeRingPos-1;
 if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 count:=0;
 totalUs:=0;
 while count<frameTimeRingCount do begin
  sample:=frameTimeRing[idx];
  values[count]:=sample;
  inc(totalUs,sample);
  inc(count);
  if (totalUs>=windowUs) and (count>=minFrames) then break;
  dec(idx);
  if idx<0 then idx:=FRAME_TIME_RING_SIZE-1;
 end;
 if count<=0 then exit;

 // Insertion sort is enough here because sample count is small.
 for i:=1 to count-1 do begin
  tmp:=values[i];
  j:=i-1;
  while (j>=0) and (values[j]>tmp) do begin
   values[j+1]:=values[j];
   dec(j);
  end;
  values[j+1]:=tmp;
 end;

 trim:=(count*trimPermille) div 1000;
 if trim*2>=count then trim:=0;
 totalUs:=0;
 n:=0;
 for i:=trim to count-trim-1 do begin
  inc(totalUs,values[i]);
  inc(n);
 end;
 if n<=0 then exit;
 avgMs:=totalUs/n/1000.0;
 result:=true;
end;

procedure TFrameTiming.UpdateFps(out fps,smoothFps:single);
const
 FPS_WINDOW_US=200000;
 FPS_MIN_FRAMES=20;
 FPS_TRIM_PERMILLE=100;
 SMOOTH_WINDOW_US=3000000;
 SMOOTH_MIN_FRAMES=60;
 SMOOTH_TRIM_PERMILLE=100;
 FPS_UPDATE_INTERVAL_MS=100; // <=10 updates/sec
 SMOOTH_UPDATE_INTERVAL_MS=500; // <=2 updates/sec
var
 avgMs:double;
 nowTicks:int64;
begin
 nowTicks:=CoreTime.Ticks;
 if nowTicks>=lastFpsUpdate+FPS_UPDATE_INTERVAL_MS then begin
  if CalcTrimmedFrameMs(FPS_WINDOW_US,FPS_MIN_FRAMES,FPS_TRIM_PERMILLE,avgMs) then begin
   if avgMs>0.001 then fps:=1000.0/avgMs else fps:=0;
  end;
  lastFpsUpdate:=nowTicks;
 end;
 if nowTicks>=lastSmoothFpsUpdate+SMOOTH_UPDATE_INTERVAL_MS then begin
  if CalcTrimmedFrameMs(SMOOTH_WINDOW_US,SMOOTH_MIN_FRAMES,SMOOTH_TRIM_PERMILLE,avgMs) then begin
   if avgMs>0.001 then smoothFps:=1000.0/avgMs else smoothFps:=0;
  end else
   smoothFps:=fps;
  lastSmoothFpsUpdate:=nowTicks;
 end;
end;

procedure TWindow.ResetSceneData;
 begin
  SetLength(scenes,0);
  topmostScene:=nil;
 end;

procedure TWindow.AddScene(scene:TGameScene);
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i]=scene then
    raise EWarning.Create('Scene already added: '+scene.name);
  i:=length(scenes);
  SetLength(scenes,i+1);
  scenes[i]:=scene;
 end;

function TWindow.RemoveScene(scene:TGameScene):boolean;
 var
  i,n:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i]=scene then begin
    n:=length(scenes)-1;
    scenes[i]:=scenes[n];
    SetLength(scenes,n);
    exit(true);
   end;
  result:=false;
 end;

function TWindow.TopmostVisibleScene(fullScreenOnly:boolean=false):TGameScene;
 var
  i:integer;
 begin
  result:=nil;
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then begin
    if fullScreenOnly and not scenes[i].fullscreen then continue;
    if result=nil then
     result:=scenes[i]
    else
     if scenes[i].zorder>result.zorder then result:=scenes[i];
   end;
 end;

procedure TWindow.NotifyScenesModeChanged;
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   scenes[i].ModeChanged;
 end;

procedure TWindow.NotifyScenesMouseMove(mouseX,mouseY:integer);
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then
    scenes[i].onMouseMove(mouseX,mouseY);
 end;

procedure TWindow.NotifyScenesMouseBtn(c:byte;pressed:boolean);
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then
    scenes[i].onMouseBtn(c,pressed);
 end;

procedure TWindow.NotifyScenesMouseWheel(value:integer);
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   if scenes[i].IsActive then
    scenes[i].onMouseWheel(value);
 end;

procedure TWindow.NotifyScenesResize;
 var
  i:integer;
 begin
  for i:=low(scenes) to high(scenes) do
   scenes[i].onResize;
 end;

function TWindow.ProcessScenes(deltaTime:integer):boolean;
 var
  i,time,n:integer;
 begin
  result:=false;
  for i:=low(scenes) to high(scenes) do
   if scenes[i].status<>TSceneStatus.ssFrozen then begin
    if scenes[i].frequency>0 then begin
     time:=1000 div scenes[i].frequency;
     inc(scenes[i].accumTime,deltaTime);
     n:=0;
     while scenes[i].accumTime>0 do begin
      result:=scenes[i].Process or result;
      dec(scenes[i].accumTime,time);
      inc(n);
      if n>5 then begin
       scenes[i].accumTime:=0;
       break;
      end;
     end;
    end else
     result:=scenes[i].Process or result;
   end;
 end;

end.
