// Debug overlay rendering: FPS, timing panel, scene list, magnifier
//
// Copyright (C) 2026 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
unit Apus.Engine.DebugOverlays;
interface
uses Apus.Engine.Types, Apus.Engine.Resources, Apus.Engine.API;

type
 TDebugState=record
  overlay:integer; // debug overlay index (0=none, 1=help, 2=glyphs, 3=scenes)
  features:set of TDebugFeature;
  magnifierTex:TTexture;
 end;

procedure DrawDebugOverlays(var state:TDebugState);
procedure DrawDebugMagnifier(var state:TDebugState);

implementation
uses SysUtils, Apus.Core, Apus.Lib, Apus.Strings, Apus.Colors,
  Apus.Images, Apus.FastGFX,
  Apus.Engine.Window, Apus.Engine.Scene, Apus.Engine.UIScene,
  Apus.Engine.ImageTools, Apus.Engine.TextDraw
  {$IFDEF MSWINDOWS}
  ,Windows
  {$ENDIF}
  ;

(* CPU overlay sampling code is intentionally disabled for now.

Disabled CPU sampling code (kept for quick restore):
var
 cpuSampleLastTick:uint64=0;
 cpuSampleLastProc:uint64=0;
 cpuSampleLastThread:uint64=0;
 cpuSampleProcPct:single=0;
 cpuSampleThreadPct:single=0;
 cpuSampleReady:boolean=false;
 cpuLogicalCount:integer=0;

function FileTimeToUInt64(const ft:TFileTime):uint64; inline;
 begin
  result:=(uint64(ft.dwHighDateTime) shl 32) or ft.dwLowDateTime;
 end;

procedure UpdateCpuOverlaySamples;
const
 SAMPLE_INTERVAL_MS=400;
var
 nowTick,dtMs:uint64;
 ct,et,pk,pu,tk,tu:TFileTime;
 procTotal,threadTotal:uint64;
 dProc,dThread:uint64;
 sysInfo:TSystemInfo;
 begin
  nowTick:=GetTickCount64;
  if (cpuSampleReady) and (nowTick<cpuSampleLastTick+SAMPLE_INTERVAL_MS) then exit;
  if cpuLogicalCount<=0 then begin
   GetSystemInfo(sysInfo);
   cpuLogicalCount:=sysInfo.dwNumberOfProcessors;
   if cpuLogicalCount<=0 then cpuLogicalCount:=1;
  end;
  if not GetProcessTimes(GetCurrentProcess,ct,et,pk,pu) then exit;
  if not GetThreadTimes(GetCurrentThread,ct,et,tk,tu) then exit;
  procTotal:=FileTimeToUInt64(pk)+FileTimeToUInt64(pu);
  threadTotal:=FileTimeToUInt64(tk)+FileTimeToUInt64(tu);
  if cpuSampleReady and (nowTick>cpuSampleLastTick) then begin
   dtMs:=nowTick-cpuSampleLastTick;
   dProc:=procTotal-cpuSampleLastProc;
   dThread:=threadTotal-cpuSampleLastThread;
   cpuSampleProcPct:=100.0*dProc/(dtMs*10000.0);
   cpuSampleThreadPct:=100.0*dThread/(dtMs*10000.0);
   if cpuSampleProcPct<0 then cpuSampleProcPct:=0;
   if cpuSampleThreadPct<0 then cpuSampleThreadPct:=0;
   if cpuSampleThreadPct>100 then cpuSampleThreadPct:=100;
  end;
  cpuSampleLastTick:=nowTick;
  cpuSampleLastProc:=procTotal;
  cpuSampleLastThread:=threadTotal;
  cpuSampleReady:=true;
 end;

Disabled overlay output snippet (dfShowFPS):
 UpdateCpuOverlaySamples;
 procCpuText:='P:'+Conv.ToStr(cpuSampleProcPct,1,0)+'%';
 threadCpuText:='T:'+Conv.ToStr(cpuSampleThreadPct,1,0)+'%';
 txt.WriteC(game.smallFont,x+w*0.27,y+h*0.95,$FF80C8FF,procCpuText);
 txt.WriteC(game.smallFont,x+w*0.75,y+h*0.95,$FFFFC060,threadCpuText);
*)

procedure DrawDebugMagnifier(var state:TDebugState);
var
 width,height,left:integer;
 u,v,du,dv:single;
 cx,cy,zoom,ox,oy:integer;
 text:string;
 color:cardinal;
 rawImage:TRawImage;
 scrScale:single;
 mSize:integer;
begin
 if state.magnifierTex=nil then begin
  state.magnifierTex:=AllocImage(128,128,ipfARGB,aiTexture,'Magnifier');
 end;
 cx:=window.mousePos.x-64;
 cy:=window.mousePos.y+64;
 EditImage(state.magnifierTex);
 Apus.FastGFX.FillRect(0,0,127,127,$FF000000);
 rawImage:=state.magnifierTex.GetRawImage;
 gfx.CopyFromBackbuffer(cx,window.renderHeight-cy,rawImage);
 rawImage.Free;
 color:=Apus.FastGFX.GetPixel(64,63);
 state.magnifierTex.Unlock;
 state.magnifierTex.SetFilter(TTexFilter.fltNearest);
 gfx.shader.UseTexture(state.magnifierTex);
 scrScale:=window.screenDPI/96;
 mSize:=round(512*scrScale);
 mSize:=mSize and $FFFFFFF0;
 width:=Min(mSize,round(window.renderWidth*0.4));
 height:=Min(mSize,window.renderHeight);
 if window.mousePos.x<window.renderWidth div 2 then left:=window.renderWidth-width
  else left:=0;
 zoom:=round(4*scrScale);
 if (window.shiftstate and sscShift)>0 then zoom:=zoom*2;
 du:=width/(256*zoom); dv:=-height/(256*zoom);
 u:=0.5; v:=0.5;
 draw.TexturedRect(left,0,left+width,height,state.magnifierTex,u-du,v-dv,u+du,v-dv,u+du,v+dv,$FF808080);
 draw.Rect(left,0,left+width,height,clWhite);
 // Color picker
 if zoom>6*scrScale then begin
  ox:=left+(width div 2);
  oy:=(height div 2);
  draw.Rect(ox,oy,ox+zoom,oy+zoom,$80FFFFFF);
  draw.Rect(ox-1,oy-1,ox+zoom+1,oy+zoom+1,$80000000);
  // Pixel color value (hex)
  draw.FillRect(ox-50*scrScale,height-30*scrScale,ox+50*scrScale,height-2*scrScale,$80000000);
  text:=Format('%2x %2x %2x',[(color shr 16) and $FF,(color shr 8) and $FF,color and $FF]);
  txt.WriteW(game.defaultFont,ox,height-17*scrScale,$FFFFFFFF,Str32(text),taCenter);
  // Pixel coordinates
  text:=Format('x: %d y: %d',[window.mousePos.x,window.mousePos.y]);
  txt.WriteW(game.smallFont,ox,height-5*scrScale,$FFFFFFFF,Str32(text),taCenter);
 end;
end;

procedure DrawDebugOverlays(var state:TDebugState);
var
 i,x,y,w,h:integer;
 j,n,idx,row,rowH,rowCount,labelW,valueW,graphX,graphW,detailW,detailH,detX,detY,gridMs,scaleMaxMs:integer;
 usValue,maxRowUs:integer;
 fade:single;
 vx:integer;
 rowColor,maxColor:cardinal;
 rowMaxUsArr:array[0..4] of integer;
 dCurUs:integer;
 dCurMs:integer;
 dMaxUs:integer;
 dMaxMs:integer;
 vsyncColor:cardinal;
 showHelp:boolean;
 feature:TDebugFeature;
 settings:TGameSettings;
 const
  timingLabels:array[0..4] of String8=('msgs','frame','rend','pres','total');

 procedure DrawHelp;
  const
   lines:array[1..13] of String8=(
    'Hotkeys:',
    '[Alt+F1] - show/hide debug overlays',
    '  [Alt+1] this help page (hold modifier)',
    '  [Alt+2] glyphs cache',
    '  [Alt+3] scenes',
    '  [Alt+5] render stats',
    '',
    '[Shift+Alt+F1] - dump debug logs',
    '[Alt+F3] - toggle magnifier',
    '[Win+~] - show console',
    '[Alt+F11] - toggle VSync',
    '[F12] - take a screenshot (JPEG)',
    '[Alt+F12] - take a screenshot (PNG)');
  var
   i,y:integer;
  begin
   draw.FillRect(0,0,320*game.screenScale,(length(lines)+0.4)*18*game.screenScale,$80000000);
   txt.BeginBlock;
   y:=0;
   for i:=1 to high(lines) do begin
    inc(y,round(18*game.screenScale));
    txt.Write(game.defaultFont,5,y,$FFFFFFFF,lines[i],taLeft,toDontTranslate);
   end;
   txt.EndBlock;
  end;

 procedure ListScenes;
 var
   i,n,y:integer;
   c:cardinal;
   sList:array of TGameScene;
   s:TGameScene;
 begin
   game.Lock;
   try
    n:=length(window.scenes);
    SetLength(sList,n);
    for i:=0 to high(window.scenes) do sList[i]:=window.scenes[i];
   finally
    window.Unlock;
   end;
   y:=0;
   draw.FillRect(0,0,game.screenScale*360,(n+0.4)*game.screenScale*16,$80000000);
   txt.BeginBlock(toDontTranslate);
   for s in sList do begin
    inc(y,round(16*game.screenScale));
    c:=$FFA0A0A0;
    if s.IsActive then begin
     c:=$FFFFFFC0;
     txt.WriteW(game.smallFont,50*game.screenScale,y,c,Str32(IntToStr(s.zOrder)),taRight);
    end else
    if s.status=TSceneStatus.ssBackground then
     c:=$FFC0D0E0;
    txt.WriteW(game.smallFont,60*game.screenScale,y,c,Str32(s.name));
    txt.WriteW(game.smallFont,200*game.screenScale,y,c,Str32(s.ClassName));
    if s.effect<>nil then
     txt.WriteW(game.smallFont,360*game.screenScale,y,c,Str32(s.effect.ClassName));
   end;
   txt.EndBlock;
 end;

 procedure ListUI;
  begin
  end;

 procedure ListRenderStats;
  const
   labels:array[0..4] of String8=('Draw calls','Shader changes','Tex changes','Clip changes','Vertices drawn');
  var
   values:array[0..4] of integer;
   k,ly:integer;
  begin
   values[0]:=window.stats.drawCalls;
   values[1]:=window.stats.shaderChanges;
   values[2]:=window.stats.texChanges;
   values[3]:=window.stats.clipChanges;
   values[4]:=window.stats.verticesDrawn;
   draw.FillRect(0,0,SRound(220*game.screenScale),SRound((length(labels)+0.4)*18*game.screenScale),$80000000);
   txt.BeginBlock(toDontTranslate);
   ly:=0;
   for k:=0 to high(labels) do begin
    inc(ly,SRound(18*game.screenScale));
    txt.Write(game.defaultFont,5,ly,$FFFFFFC0,labels[k]+': '+IntToStr(values[k]),taLeft,toDontTranslate);
   end;
   txt.EndBlock;
  end;

 function RingIndexByOffset(offset:integer):integer;
  begin
   result:=window.timings.frameTimeRingPos-1-offset;
   while result<0 do inc(result,FRAME_TIME_RING_SIZE);
  end;

 function PhaseSampleUs(row,offset:integer):integer;
  begin
   idx:=RingIndexByOffset(offset);
   case row of
    0:result:=window.timings.phaseMsgRing[idx];
    1:result:=window.timings.phaseOnFrameRing[idx];
    2:result:=window.timings.phaseRenderRing[idx];
    3:result:=window.timings.phasePresentRing[idx];
    else
     result:=window.timings.frameTimeRing[idx];
   end;
  end;

 function MapMsToX(ms:single):integer;
 var
  t:single;
 begin
  if scaleMaxMs<=0 then exit(graphX);
  t:=Sat(ms/scaleMaxMs);
  result:=graphX+round(sqrt(t)*graphW); // nonlinear scale: stretch low values, compress high
 end;

 function IsDebugHotkeyModifierHeld:boolean;
  begin
   result:=(game.debugHotkey<>0) and Bits.HasAll(window.shiftState,game.debugHotkey);
  end;

 begin
  settings:=game.GetSettings;
  game.Lock;
  try
  showHelp:=(window=mainWindow) and IsDebugHotkeyModifierHeld;
  case state.overlay of
   1:if showHelp then DrawHelp;
   2:txt.WriteW(MAGIC_TEXTCACHE,1,1,$FFFFFFFF,Str32(''));
   3:ListScenes;
   4:ListUI;
   5:ListRenderStats;
  end;

  for feature in state.features do
   case feature of
    dfShowFPS:begin
      w:=SRound(80*game.screenScale);
      h:=SRound(30*game.screenScale);
      x:=window.renderWidth-w; y:=1;
      draw.FillRect(x,y,x+w-2,y+h,$80000000);
      dCurUs:=window.timings.lastFrameTimeUs;
      dCurMs:=dCurUs div 1000;
      dMaxUs:=window.timings.MaxRecentFrameUs(10);
      dMaxMs:=dMaxUs div 1000;
      if settings.VSync>0 then
       vsyncColor:=$FF70FF70
      else
       vsyncColor:=$FFFFB060;
      txt.BeginBlock;
      txt.WriteC(game.defaultFont,x+w*0.74,y+h*0.39,vsyncColor,Conv.ToStr(window.FPS,1,1));
      txt.WriteC(game.defaultFont,x+w*0.74,y+h*0.87,vsyncColor,Conv.ToStr(window.smoothFPS,1,1));
      txt.WriteC(game.defaultFont,x+w*0.24,y+h*0.39,vsyncColor,Conv.ToStr(dCurMs));
      txt.WriteC(game.defaultFont,x+w*0.24,y+h*0.87,vsyncColor,Conv.ToStr(dMaxMs));
      txt.EndBlock;

      // Detailed frame timings
      if Bits.HasAll(window.shiftState,sscShift) and (window.timings.frameTimeRingCount>0) then begin
       rowCount:=5;
       rowH:=SRound(14*game.screenScale);
       if rowH<12 then rowH:=12;
       detailW:=SRound(160*game.screenScale);
       detailH:=rowCount*rowH+SRound(8*game.screenScale);
       detX:=window.renderWidth-detailW;
       detY:=y+h+2;
       labelW:=SRound(42*game.screenScale);
       valueW:=SRound(20*game.screenScale);
       graphX:=detX+labelW+valueW;
       graphW:=detailW-labelW-valueW-SRound(8*game.screenScale);
       draw.FillRect(detX,detY,detX+detailW-2,detY+detailH,$68000000);

       n:=window.timings.frameTimeRingCount;
       if n>10 then n:=10;

       for row:=0 to rowCount-1 do begin
        maxRowUs:=0;
        for j:=0 to n-1 do begin
         usValue:=PhaseSampleUs(row,j);
         if usValue>maxRowUs then maxRowUs:=usValue;
        end;
        rowMaxUsArr[row]:=maxRowUs;
       end;

       scaleMaxMs:=40; // fixed scale to keep visualization stable
       gridMs:=5;
       draw.BeginLines;
       i:=0;
       while i<=scaleMaxMs do begin
        vx:=MapMsToX(i);
        draw.Line(vx,detY+2,vx,detY+detailH-3,$22FFFFFF);
        inc(i,gridMs);
       end;
       for row:=0 to rowCount-1 do begin
        case row of
         0:rowColor:=$FF60D0FF;
         1:rowColor:=$FFF8E070;
         2:rowColor:=$FF80FF80;
         3:rowColor:=$FFFF9080;
         else rowColor:=$FFC8B0FF;
        end;
        maxColor:=Color.Blend(rowColor,$A0FFFFFF);
        y:=detY+SRound(3*game.screenScale)+row*rowH;
        draw.Line(detX+2,y+rowH-1,detX+detailW-4,y+rowH-1,$18FFFFFF);

        vx:=MapMsToX(rowMaxUsArr[row]*0.001);
        draw.Line(vx,y+1,vx,y+rowH-2,maxColor);

        for j:=n-1 downto 0 do begin
         usValue:=PhaseSampleUs(row,j);
         vx:=MapMsToX(usValue*0.001);
         fade:=0.7*(n-j)/n;
         draw.Line(vx,y+1,vx,y+rowH-2,Color.SetAlpha(rowColor,fade));
        end;
       end;
       draw.EndLines;

       txt.BeginBlock;
       for row:=0 to rowCount-1 do begin
        case row of
         0:rowColor:=$FF60D0FF;
         1:rowColor:=$FFF8E070;
         2:rowColor:=$FF80FF80;
         3:rowColor:=$FFFF9080;
         else rowColor:=$FFC8B0FF;
        end;
        y:=detY+SRound(3*game.screenScale)+row*rowH;
        txt.Write(game.smallFont,detX+2,y+rowH-4,Color.SetAlpha(rowColor,220/255),timingLabels[row],taLeft,toDontTranslate);
        txt.WriteC(game.smallFont,detX+labelW+valueW div 2-4,y+rowH-4,rowColor,Conv.ToStr(rowMaxUsArr[row]*0.001,1,1));
       end;
       txt.EndBlock;
      end;
    end;

    dfShowMagnifier:DrawDebugMagnifier(state);

    dfShowNavigationPoints:; // rendered in Game.pas (needs protected field)
   end;

  // Screenshot confirmation is now a toast (see Window screenshot path -> ShowToast).

 finally
  game.Unlock;
 end;
end;

end.
