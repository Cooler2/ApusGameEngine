unit Apus.Engine.WindowRuntime;
interface
uses Apus.Core;

const
  FRAME_TIME_RING_SIZE = 512;

type
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

implementation

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

end.
