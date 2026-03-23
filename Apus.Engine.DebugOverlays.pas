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
  Apus.Engine.ImageTools, Apus.Engine.TextDraw;

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
   lines:array[1..12] of String8=(
    'Hotkeys:',
    '[Alt+F1] - show/hide debug overlays',
    '  [Alt+1] this help page (hold modifier)',
    '  [Alt+2] glyphs cache',
    '  [Alt+3] scenes',
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
   for i:=0 to high(sList) do begin
    inc(y,round(16*game.screenScale));
    c:=$FFA0A0A0;
    if sList[i].IsActive then begin
     c:=$FFFFFFC0;
     txt.WriteW(game.smallFont,50*game.screenScale,y,c,Str32(IntToStr(sList[i].zOrder)),taRight);
    end else
    if sList[i].status=TSceneStatus.ssBackground then
     c:=$FFC0D0E0;
    txt.WriteW(game.smallFont,60*game.screenScale,y,c,Str32(sList[i].name));
    txt.WriteW(game.smallFont,200*game.screenScale,y,c,Str32(sList[i].ClassName));
    if sList[i].effect<>nil then
     txt.WriteW(game.smallFont,360*game.screenScale,y,c,Str32(sList[i].effect.ClassName));
   end;
   txt.EndBlock;
 end;

 procedure ListUI;
  begin
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
        maxColor:=Blend(rowColor,$A0FFFFFF);
        y:=detY+SRound(3*game.screenScale)+row*rowH;
        draw.Line(detX+2,y+rowH-1,detX+detailW-4,y+rowH-1,$18FFFFFF);

        vx:=MapMsToX(rowMaxUsArr[row]*0.001);
        draw.Line(vx,y+1,vx,y+rowH-2,maxColor);

        for j:=n-1 downto 0 do begin
         usValue:=PhaseSampleUs(row,j);
         vx:=MapMsToX(usValue*0.001);
         fade:=0.7*(n-j)/n;
         draw.Line(vx,y+1,vx,y+rowH-2,ReplaceAlpha(rowColor,fade));
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
        txt.Write(game.smallFont,detX+2,y+rowH-4,ReplaceAlpha(rowColor,220/255),timingLabels[row],taLeft,toDontTranslate);
        txt.WriteC(game.smallFont,detX+labelW+valueW div 2-4,y+rowH-4,rowColor,Conv.ToStr(rowMaxUsArr[row]*0.001,1,1));
       end;
       txt.EndBlock;
      end;
    end;

    dfShowMagnifier:DrawDebugMagnifier(state);

    dfShowNavigationPoints:; // rendered in Game.pas (needs protected field)
   end;

  // Capture screenshot notification
  if (window.capture.capturedTime>0) and (CoreTime.Ticks<window.capture.capturedTime+3000) and (gfx<>nil) then begin
    x:=settings.width div 2;
    y:=settings.height div 2;
    draw.FillRect(x-200*game.screenScale,y-40*game.screenScale,x+200*game.screenScale,y+40*game.screenScale,$60000000);
    draw.Rect(x-200*game.screenScale,y-40*game.screenScale,x+200*game.screenScale,y+40*game.screenScale,$A0FFFFFF);
    txt.Write(game.largerFont,x,y-16*game.screenScale,$FFFFFFFF,'Screen captured to:',taCenter);
    txt.Write(game.defaultFont,x,y+8*game.screenScale,$FFFFFFFF,window.capture.capturedName,taCenter);
  end;

 finally
  game.Unlock;
 end;
end;

end.
