// R-39 bench: the cost of UI shape fills drawn in different ways (Work/R-39_ui_gradients.md).
// Throwaway prototypes of the candidate backends, not engine code. Desktop GL only.
// Build: build.cmd tests\BenchUIShapes.dpr -O2
// Run:   bin64\BenchUIShapes.exe              - all scenarios, table to stdout
//        bin64\BenchUIShapes.exe <S> <V>      - endless render of one scenario/variant (NSight)
//        S: S1 S2 S3 S3x4K S4alt S4grp ; V: FillRect RoundRect A B C D Dquad Text
//        bin64\BenchUIShapes.exe <S> <V> nodebuggl - the same with debugGL=false
{$APPTYPE CONSOLE}
program BenchUIShapes;
{$I ..\defines.inc}
uses
 {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
 SysUtils,Types,Apus.Core,Apus.Types,Apus.Colors,Apus.Images,Apus.Files,Apus.GfxFormats,
 Apus.EventMan,Apus.Geom2D,
 Apus.Engine.API,Apus.Engine.Types,Apus.Engine.GameApp,Apus.Engine.Scene,Apus.Engine.Window,
 Apus.Engine.NinePatch,Apus.Engine.ShadersGL,Apus.Engine.Graphics,Apus.Engine.OpenGL
 {$IFDEF GLDESKTOP},dglOpenGL{$ENDIF};

type
 TBenchApp=class(TGameApplication)
  procedure SetupApplication;override;
  procedure CreateScenes;override;
 end;
 TBenchScene=class(TGameScene)
  frame:integer;
  procedure Render;override;
  function GetArea:TRect;override;
 end;
 TVariant=(vFillRect,vRoundRect,vA,vB,vC,vD,vDquad,vText);
 TScenario=(sButtons,sButtonsText,sFrames,sFrames4K,sSwitchAlt,sSwitchGrp);

const
 VARIANT_NAMES:array[TVariant] of String8=('FillRect','RoundRect','A','B','C','D','Dquad','Text');
 SCENARIO_NAMES:array[TScenario] of String8=('S1','S2','S3','S3x4K','S4alt','S4grp');
 // buttons: 16x32 grid in 1920x1080
 BTN_COLS=16; BTN_ROWS=32; BTN_W=112; BTN_H=28; BTN_STEP_X=120; BTN_STEP_Y=33;
 BTN_RADIUS=6; BTN_BORDER=1;
 FILL_TOP=$FF6F7F98; FILL_BOTTOM=$FF435166;
 BORDER_TOP=$FFC8D4E8; BORDER_BOTTOM=$FF808CA0;
 TEXT_COLOR=$FFF0F4FA;
 // frames: nested window frames, border only
 FRAME_COUNT=20; FRAME_RADIUS=12; FRAME_BORDER=4;
 // switch cost: small quads
 SWITCH_COUNT=1000;
 MAX_ARC=16;

var
 rtHD,rt4K:TTexture;
 whiteTex,rampTex:TTexture;
 patchBtn,patchFrame:TNinePatch;
 dShader:TShader;
 dLoc:integer;
 font:TFontHandle;
 captions:array of String8;
 loopMode:boolean;
 loopScenario:TScenario;
 loopVariant:TVariant;
 loopFrames:integer;
 loopTime:int64;
 outDir:String8;

{ ---------- helpers ---------- }

function ColorToVec(c:cardinal;var v:array of single;ofs:integer):integer;
begin
 v[ofs]:=((c shr 16) and $FF)/255;
 v[ofs+1]:=((c shr 8) and $FF)/255;
 v[ofs+2]:=(c and $FF)/255;
 v[ofs+3]:=(c shr 24)/255;
 result:=ofs+4;
end;

function WithAlpha(c:cardinal;a:single):cardinal;
begin
 result:=(c and $FFFFFF) or (cardinal(round(Clamp((c shr 24)*a,0,255))) shl 24);
end;

function SDRoundRect(px,py,hw,hh,r:single):single;
var
 qx,qy:single;
begin
 qx:=abs(px)-hw+r; qy:=abs(py)-hh+r;
 result:=sqrt(sqr(Max(qx,0))+sqr(Max(qy,0)))+Min(Max(qx,qy),0)-r;
end;

{ ---------- A: tessellated rounded rect with vertex colors ---------- }

var
 mv:array[0..1023] of TVertex;
 mi:array[0..4095] of word;
 nv,ni:integer;
 arcCos,arcSin:array[0..MAX_ARC] of single;
 arcSteps:integer=-1;

procedure PrepareArc(steps:integer);
var
 i:integer;
begin
 if steps=arcSteps then exit;
 for i:=0 to steps do begin
  arcCos[i]:=cos(0.5*Pi*i/steps);
  arcSin[i]:=sin(0.5*Pi*i/steps);
 end;
 arcSteps:=steps;
end;

// contour of the rounded rect inset by d (negative - outwards), vertical gradient colors
function AddContour(x1,y1,x2,y2,r,d:single;steps:integer;cTop,cBottom:cardinal;alpha:single):integer;
var
 k,i:integer;
 cx,cy,rad,px,py,c,s,h:single;
 col:cardinal;
begin
 result:=nv;
 rad:=Max(r-d,0);
 h:=y2-y1;
 for k:=0 to 3 do
  for i:=0 to steps do begin
   // quarter arcs clockwise (y down): TL, TR, BR, BL
   c:=arcCos[i]; s:=arcSin[i];
   case k of
    0:begin cx:=x1+Max(r,d); cy:=y1+Max(r,d); px:=cx-rad*c; py:=cy-rad*s; end;
    1:begin cx:=x2-Max(r,d); cy:=y1+Max(r,d); px:=cx+rad*s; py:=cy-rad*c; end;
    2:begin cx:=x2-Max(r,d); cy:=y2-Max(r,d); px:=cx+rad*c; py:=cy+rad*s; end;
    else begin cx:=x1+Max(r,d); cy:=y2-Max(r,d); px:=cx-rad*s; py:=cy+rad*c; end;
   end;
   col:=Color.Mix(cTop,cBottom,Clamp((py-y1)/h,0,1));
   if alpha<1 then col:=WithAlpha(col,alpha);
   mv[nv].Init(px,py,0,col);
   inc(nv);
  end;
end;

procedure AddRing(a,b,n:integer);
var
 j,k:integer;
begin
 for j:=0 to n-1 do begin
  k:=(j+1) mod n;
  mi[ni]:=a+j; mi[ni+1]:=a+k; mi[ni+2]:=b+k;
  mi[ni+3]:=a+j; mi[ni+4]:=b+k; mi[ni+5]:=b+j;
  inc(ni,6);
 end;
end;

procedure AddFan(a,n:integer);
var
 j:integer;
begin
 for j:=1 to n-2 do begin
  mi[ni]:=a; mi[ni+1]:=a+j; mi[ni+2]:=a+j+1;
  inc(ni,3);
 end;
end;

// x1..x2, y1..y2 - outer edges of the shape (not pixel centers)
procedure DrawA(x1,y1,x2,y2,r,bw:single;fTop,fBottom,bTop,bBottom:cardinal;hasFill:boolean);
var
 steps,n,c0,c1,c2,c3:integer;
begin
 if not clippingAPI.Prepare(x1,y1,x2,y2) then exit;
 steps:=Clamp(round(r*0.6),1,MAX_ARC);
 PrepareArc(steps);
 n:=(steps+1)*4;
 nv:=0; ni:=0;
 c0:=AddContour(x1,y1,x2,y2,r,-0.5,steps,bTop,bBottom,0); // outer AA fringe
 c1:=AddContour(x1,y1,x2,y2,r,0.5,steps,bTop,bBottom,1);
 AddRing(c0,c1,n);
 if bw>1 then begin
  c2:=AddContour(x1,y1,x2,y2,r,bw-0.5,steps,bTop,bBottom,1);
  AddRing(c1,c2,n);
 end else
  c2:=c1;
 if hasFill then
  c3:=AddContour(x1,y1,x2,y2,r,bw+0.5,steps,fTop,fBottom,1)
 else
  c3:=AddContour(x1,y1,x2,y2,r,bw+0.5,steps,bTop,bBottom,0); // inner AA fringe of a frame
 AddRing(c2,c3,n);
 if hasFill then AddFan(c3,n);
 draw.IndexedMesh(@mv[0],TVertex.layoutTex,@mi[0],ni div 3,nv,nil);
end;

{ ---------- D: dedicated SDF shader, all parameters in one vec4 array ---------- }

const
 D_VERT=
  '#version 330'#13#10+
  'uniform mat4 MVP;'#13#10+
  'layout (location=0) in vec3 position;'#13#10+
  'layout (location=1) in vec4 color;'#13#10+
  'layout (location=2) in vec2 texCoord;'#13#10+
  'out vec2 vLocal;'#13#10+
  'void main(void) {'#13#10+
  ' gl_Position = MVP*vec4(position,1.0);'#13#10+
  ' vLocal = texCoord;'#13#10+
  '}';
 D_FRAG=
  '#version 330'#13#10+
  'uniform vec4 p[5];'#13#10+ // halfSize.xy,radius,border; fill top/bottom; border top/bottom
  'in vec2 vLocal;'#13#10+
  'out vec4 fragColor;'#13#10+
  'void main(void) {'#13#10+
  ' vec2 q = abs(vLocal)-p[0].xy+p[0].z;'#13#10+
  ' float d = length(max(q,0.0))+min(max(q.x,q.y),0.0)-p[0].z;'#13#10+
  ' float aa = max(fwidth(d),0.0001);'#13#10+
  ' float t = clamp(vLocal.y/(2.0*p[0].y)+0.5,0.0,1.0);'#13#10+
  ' vec4 fill = mix(p[1],p[2],t);'#13#10+
  ' vec4 brd = mix(p[3],p[4],t);'#13#10+
  ' vec4 c = mix(brd,fill,clamp(0.5-(d+p[0].w)/aa,0.0,1.0));'#13#10+
  ' c.a *= clamp(0.5-d/aa,0.0,1.0);'#13#10+
  ' if (c.a<0.004) discard;'#13#10+
  ' fragColor = c;'#13#10+
  '}';

procedure DrawD(x1,y1,x2,y2,r,bw:single;fTop,fBottom,bTop,bBottom:cardinal;ring:boolean);
var
 prm:array[0..19] of single;
 vrt:array[0..23] of TVertex;
 n,i:integer;
 cx,cy,hw,hh,ins:single;
 procedure Quad(ax1,ay1,ax2,ay2:single);
  begin
   vrt[n].Init(ax1,ay1,0,ax1-cx,ay1-cy,$FFFFFFFF);
   vrt[n+1].Init(ax2,ay1,0,ax2-cx,ay1-cy,$FFFFFFFF);
   vrt[n+2].Init(ax2,ay2,0,ax2-cx,ay2-cy,$FFFFFFFF);
   vrt[n+3]:=vrt[n];
   vrt[n+4]:=vrt[n+2];
   vrt[n+5].Init(ax1,ay2,0,ax1-cx,ay2-cy,$FFFFFFFF);
   inc(n,6);
  end;
begin
 if not clippingAPI.Prepare(x1,y1,x2,y2) then exit;
 cx:=(x1+x2)/2; cy:=(y1+y2)/2;
 hw:=(x2-x1)/2; hh:=(y2-y1)/2;
 prm[0]:=hw; prm[1]:=hh; prm[2]:=r; prm[3]:=bw;
 i:=ColorToVec(fTop,prm,4);
 i:=ColorToVec(fBottom,prm,i);
 i:=ColorToVec(bTop,prm,i);
 ColorToVec(bBottom,prm,i);
 shader.UseCustom(dShader);
 {$IFDEF GLDESKTOP}
 glUniform4fv(dLoc,5,@prm[0]);
 {$ENDIF}
 n:=0;
 if ring then begin
  // tight coverage: 4 bands along the edge, the empty middle is not rasterized
  ins:=Max(r,bw)+1;
  Quad(x1,y1,x2,y1+ins);
  Quad(x1,y2-ins,x2,y2);
  Quad(x1,y1+ins,x1+ins,y2-ins);
  Quad(x2-ins,y1+ins,x2,y2-ins);
 end else
  Quad(x1,y1,x2,y2);
 renderDevice.Draw(TRG_LIST,n div 3,@vrt[0],TVertex.layoutTex);
 shader.Reset;
end;

{ ---------- engine RoundRect: the R-39 shape shader (D in the engine) ---------- }

procedure DrawRoundRect(x1,y1,x2,y2,r,bw:single;fTop,fBottom,bColor:cardinal;hasFill:boolean);
var
 fill:TFill;
begin
 if hasFill then fill:=TFill.Linear(180,fTop,fBottom)
  else fill:=TFill.None;
 draw.RoundRect(x1,y1,x2-1,y2-1,r,bw,TFill.Solid(bColor),fill);
end;

{ ---------- B: multitexture, rect only (cost estimate) ---------- }

procedure DrawB(x1,y1,x2,y2:integer);
var
 uv2:TMat32;
begin
 uv2[0,0]:=0; uv2[0,1]:=0;
 uv2[1,0]:=1; uv2[1,1]:=0;
 uv2[2,0]:=0; uv2[2,1]:=0.5;
 shader.TexMode(1,tblModulate,tblModulate);
 draw.DoubleTexturedRect(x1,y1,x2,y2,whiteTex,IdentMat32,rampTex,uv2,$FF808080);
 shader.DefaultTexMode;
end;

{ ---------- resources ---------- }

// software-rendered rounded rect (for 9-patches): AA by distance, vertical gradient
function MakeShapeTexture(size:integer;r,bw:single;hasFill:boolean;const name:String8):TTexture;
var
 x,y:integer;
 row:PCardinalRow;
 d,t,cov,inner:single;
 fc,bc,col:cardinal;
begin
 result:=AllocImage(size,size,ipfARGB,aiTexture,name);
 result.Lock;
 for y:=0 to size-1 do begin
  row:=PCardinalRow(result.ScanLine(y));
  t:=(y+0.5)/size;
  fc:=Color.Mix(FILL_TOP,FILL_BOTTOM,t);
  bc:=Color.Mix(BORDER_TOP,BORDER_BOTTOM,t);
  for x:=0 to size-1 do begin
   d:=SDRoundRect(x+0.5-size/2,y+0.5-size/2,size/2,size/2,r);
   cov:=Clamp(0.5-d,0,1);
   inner:=Clamp(0.5-(d+bw),0,1);
   if hasFill then col:=Color.Mix(bc,fc,inner)
    else col:=WithAlpha(bc,1-inner);
   row^[x]:=WithAlpha(col,cov);
  end;
 end;
 result.Unlock;
end;

procedure PrepareResources;
var
 i,margin:integer;
 row:PCardinalRow;
begin
 rtHD:=AllocImage(1920,1080,pfRenderTarget,aiTexture+aiRenderTarget,'BenchRT_HD');
 rt4K:=AllocImage(3840,2160,pfRenderTarget,aiTexture+aiRenderTarget,'BenchRT_4K');
 whiteTex:=AllocImage(4,4,ipfARGB,aiTexture,'BenchWhite');
 whiteTex.Clear($FFFFFFFF);
 rampTex:=AllocImage(256,1,ipfARGB,aiTexture+aiClampUV,'BenchRamp');
 rampTex.Lock;
 row:=PCardinalRow(rampTex.ScanLine(0));
 for i:=0 to 255 do row^[i]:=Color.Mix(FILL_TOP,FILL_BOTTOM,i/255);
 rampTex.Unlock;
 // 9-patches: fixed corners one pixel wider than the radius (see Draw2D BuildPatch)
 margin:=BTN_RADIUS+2;
 patchBtn:=TCustomNinePatch.CreateMargins(MakeShapeTexture(32,BTN_RADIUS,BTN_BORDER,true,'BenchPatchBtn'),
   margin,margin,margin,margin,false);
 margin:=FRAME_RADIUS+2;
 patchFrame:=TCustomNinePatch.CreateMargins(MakeShapeTexture(64,FRAME_RADIUS,FRAME_BORDER,false,'BenchPatchFrame'),
   margin,margin,margin,margin,false);
 dShader:=shader.Build(D_VERT,D_FRAG);
 dShader.name:='BenchShapeD';
 {$IFDEF GLDESKTOP}
 dLoc:=glGetUniformLocation(TGLShader(dShader).handle,'p');
 {$ENDIF}
 font:=txt.GetFont('Default',9);
 SetLength(captions,BTN_COLS*BTN_ROWS);
 for i:=0 to high(captions) do captions[i]:='Button '+IntToStr(i);
end;

{ ---------- scenarios ---------- }

procedure DrawButton(v:TVariant;x,y:integer);
begin
 case v of
  vFillRect:draw.FillRect(x,y,x+BTN_W-1,y+BTN_H-1,FILL_TOP);
  vRoundRect:DrawRoundRect(x,y,x+BTN_W,y+BTN_H,BTN_RADIUS,BTN_BORDER,FILL_TOP,FILL_BOTTOM,BORDER_TOP,true);
  vA:DrawA(x,y,x+BTN_W,y+BTN_H,BTN_RADIUS,BTN_BORDER,FILL_TOP,FILL_BOTTOM,BORDER_TOP,BORDER_BOTTOM,true);
  vB:DrawB(x,y,x+BTN_W-1,y+BTN_H-1);
  vC:patchBtn.Draw(x,y,BTN_W,BTN_H);
  vD,vDquad:DrawD(x,y,x+BTN_W,y+BTN_H,BTN_RADIUS,BTN_BORDER,FILL_TOP,FILL_BOTTOM,BORDER_TOP,BORDER_BOTTOM,false);
  vText:; // caption only
 end;
end;

procedure DrawFrame(v:TVariant;x1,y1,x2,y2:integer);
begin
 case v of
  vFillRect:draw.Rect(x1,y1,x2-1,y2-1,BORDER_TOP);
  vRoundRect:DrawRoundRect(x1,y1,x2,y2,FRAME_RADIUS,FRAME_BORDER,0,0,BORDER_TOP,false);
  vA:DrawA(x1,y1,x2,y2,FRAME_RADIUS,FRAME_BORDER,0,0,BORDER_TOP,BORDER_BOTTOM,false);
  vC:patchFrame.Draw(x1,y1,x2-x1,y2-y1);
  vD:DrawD(x1,y1,x2,y2,FRAME_RADIUS,FRAME_BORDER,0,0,BORDER_TOP,BORDER_BOTTOM,true);
  vDquad:DrawD(x1,y1,x2,y2,FRAME_RADIUS,FRAME_BORDER,0,0,BORDER_TOP,BORDER_BOTTOM,false);
 end;
end;

function Applicable(s:TScenario;v:TVariant):boolean;
begin
 case s of
  sButtons:result:=v<>vText;
  sButtonsText:result:=true;
  sFrames,sFrames4K:result:=not (v in [vB,vText]);
  else result:=v in [vRoundRect,vD]; // switch cost: FillRect interleaved with a shader shape
 end;
 if (v=vDquad) and (s in [sButtons,sButtonsText]) then result:=false; // same as D there
end;

procedure RunScenario(s:TScenario;v:TVariant);
var
 i,j,k,w,h,step:integer;
begin
 case s of
  sButtons,sButtonsText:begin
   k:=0;
   for j:=0 to BTN_ROWS-1 do
    for i:=0 to BTN_COLS-1 do begin
     DrawButton(v,i*BTN_STEP_X+4,j*BTN_STEP_Y+4);
     if s=sButtonsText then
      txt.Write(font,i*BTN_STEP_X+14,j*BTN_STEP_Y+23,TEXT_COLOR,captions[k]);
     inc(k);
    end;
  end;
  sFrames,sFrames4K:begin
   if s=sFrames4K then begin w:=3840; h:=2160; step:=20; end
    else begin w:=1920; h:=1080; step:=10; end;
   for i:=0 to FRAME_COUNT-1 do
    DrawFrame(v,i*step,i*step,w-i*step,h-i*step);
  end;
  sSwitchAlt:
   for i:=0 to SWITCH_COUNT-1 do begin
    draw.FillRect((i mod 100)*16,(i div 100)*16,(i mod 100)*16+7,(i div 100)*16+7,FILL_TOP);
    if v=vD then DrawD((i mod 100)*16+8,(i div 100)*16,(i mod 100)*16+16,(i div 100)*16+8,2,1,
       FILL_TOP,FILL_BOTTOM,BORDER_TOP,BORDER_BOTTOM,false)
    else DrawRoundRect((i mod 100)*16+8,(i div 100)*16,(i mod 100)*16+16,(i div 100)*16+8,2,1,
       FILL_TOP,FILL_BOTTOM,BORDER_TOP,true);
   end;
  sSwitchGrp:begin
   for i:=0 to SWITCH_COUNT-1 do
    draw.FillRect((i mod 100)*16,(i div 100)*16,(i mod 100)*16+7,(i div 100)*16+7,FILL_TOP);
   for i:=0 to SWITCH_COUNT-1 do
    if v=vD then DrawD((i mod 100)*16+8,(i div 100)*16,(i mod 100)*16+16,(i div 100)*16+8,2,1,
       FILL_TOP,FILL_BOTTOM,BORDER_TOP,BORDER_BOTTOM,false)
    else DrawRoundRect((i mod 100)*16+8,(i div 100)*16,(i mod 100)*16+16,(i div 100)*16+8,2,1,
       FILL_TOP,FILL_BOTTOM,BORDER_TOP,true);
  end;
 end;
end;

function TargetFor(s:TScenario):TTexture;
begin
 if s=sFrames4K then result:=rt4K else result:=rtHD;
end;

{ ---------- measurement ---------- }

const
 BLOCKS=7; // a value is the median of BLOCKS measured blocks of reps repetitions

function Median(var v:array of double):double;
var
 i,j:integer;
 t:double;
begin
 for i:=0 to high(v)-1 do
  for j:=i+1 to high(v) do
   if v[j]<v[i] then begin t:=v[i]; v[i]:=v[j]; v[j]:=t; end;
 result:=v[length(v) div 2];
end;

procedure Measure(s:TScenario;v:TVariant;reps:integer);
var
 t0,t1,t2:int64;
 draws,switches,i,blk:integer;
 cpu,total,gpu:array[0..BLOCKS-1] of double;
 gpuNs:{$IFDEF GLDESKTOP}GLuint64{$ELSE}int64{$ENDIF};
 {$IFDEF GLDESKTOP}
 q:GLuint;
 {$ENDIF}
begin
 draws:=0; switches:=0;
 gfx.BeginPaint(TargetFor(s));
 try
  gfx.target.Clear($FF202428,-1,-1);
  RunScenario(s,v); RunScenario(s,v); // warm up: caches, buffers, shader builds
  {$IFDEF GLDESKTOP}
  glGenQueries(1,@q);
  {$ENDIF}
  for blk:=0 to BLOCKS-1 do begin
   {$IFDEF GLDESKTOP}
   glFinish;
   {$ENDIF}
   draws:=window.stats.drawCalls;
   switches:=window.stats.shaderChanges;
   t0:=Time.TicksUs;
   {$IFDEF GLDESKTOP}
   glBeginQuery(GL_TIME_ELAPSED,q);
   {$ENDIF}
   for i:=1 to reps do RunScenario(s,v);
   t1:=Time.TicksUs;
   gpuNs:=0;
   {$IFDEF GLDESKTOP}
   glEndQuery(GL_TIME_ELAPSED);
   glFinish;
   t2:=Time.TicksUs;
   glGetQueryObjectui64v(q,GL_QUERY_RESULT,@gpuNs);
   {$ELSE}
   t2:=t1;
   {$ENDIF}
   draws:=window.stats.drawCalls-draws;
   switches:=window.stats.shaderChanges-switches;
   cpu[blk]:=(t1-t0)/1000/reps;
   total[blk]:=(t2-t0)/1000/reps;
   gpu[blk]:=gpuNs/1e6/reps;
  end;
  {$IFDEF GLDESKTOP}
  glDeleteQueries(1,@q);
  {$ENDIF}
  writeln(Format('%-6s %-9s  cpu %8.3f ms   total %8.3f ms   gpu %8.3f ms   draws %6d   switches %6d',
    [SCENARIO_NAMES[s],VARIANT_NAMES[v],Median(cpu),Median(total),Median(gpu),
     draws div reps,switches div reps]));
 finally
  gfx.EndPaint;
 end;
end;

// quality: each variant as a button and a frame corner, zoomed 4x with nearest neighbour
procedure SaveQuality;
const
 W=640; H=200; ZK=4;
var
 rt:TTexture;
 img,zoomImg:TBitmapImage;
 v:TVariant;
 x,y,col:integer;
begin
 rt:=AllocImage(W,H,pfRenderTarget,aiTexture+aiRenderTarget,'BenchQuality');
 img:=TBitmapImage.Create(W,H,ipfARGB);
 zoomImg:=TBitmapImage.Create(W*ZK,H*ZK,ipfARGB);
 try
  gfx.BeginPaint(rt);
  try
   gfx.target.Clear($FF202428,-1,-1);
   col:=0;
   for v:=vRoundRect to vD do begin
    DrawButton(v,10+col*120,10);
    DrawFrame(v,10+col*120,60,10+col*120+110,190);
    txt.Write(font,10+col*120,56,TEXT_COLOR,VARIANT_NAMES[v]);
    inc(col);
   end;
   gfx.CopyFromBackbuffer(0,0,img);
  finally
   gfx.EndPaint;
  end;
  for y:=0 to H*ZK-1 do
   for x:=0 to W*ZK-1 do
    PCardinal(UIntPtr(zoomImg.ScanLine(y))+UIntPtr(x*4))^:=
      PCardinal(UIntPtr(img.ScanLine(y div ZK))+UIntPtr((x div ZK)*4))^;
  Files.Save(outDir+'quality.png',SavePNG(img));
  Files.Save(outDir+'quality_x4.png',SavePNG(zoomImg));
  writeln('Quality images: '+outDir+'quality.png, quality_x4.png');
 finally
  img.Free; zoomImg.Free;
  FreeImage(rt);
 end;
end;

procedure RunAll;
var
 s:TScenario;
 v:TVariant;
 reps,pass:integer;
begin
 writeln('R-39 UI shapes bench, per scenario repetition, median of ',BLOCKS,' blocks (cpu: submit time; total: until glFinish)');
 for pass:=0 to 1 do begin
  debugGL:=pass=0;
  writeln;
  writeln('=== debugGL=',debugGL,' ===');
  for s:=low(TScenario) to high(TScenario) do begin
   case s of
    sFrames,sFrames4K:reps:=50;
    else reps:=20;
   end;
   for v:=low(TVariant) to high(TVariant) do
    if Applicable(s,v) then Measure(s,v,reps);
   writeln;
  end;
 end;
 debugGL:=true;
 SaveQuality;
end;

{ ---------- app ---------- }

procedure TBenchApp.SetupApplication;
begin
 inherited;
 appSetup.title:='BenchUIShapes';
 requestBackend.graphicsAPI:=gaOpenGL2;
 windowSetup.size:=MakeSize(960,540);
end;

procedure TBenchApp.CreateScenes;
begin
 inherited;
 TBenchScene.Create('Bench',true,window);
 game.SwitchToScene('Bench');
end;

function TBenchScene.GetArea:TRect;
begin
 result:=Rect(0,0,window.canvasWidth,window.canvasHeight);
end;

procedure TBenchScene.Render;
var
 t:int64;
 rt:TTexture;
begin
 gfx.target.Clear($FF202020,-1,-1);
 inc(frame);
 if frame<3 then exit;
 if frame=3 then begin
  outDir:=String8(ExtractFilePath(ParamStr(0)))+'BenchUIShapes/';
  ForceDirectories(string(outDir));
  PrepareResources;
  if not loopMode then begin
   try
    RunAll;
   except on e:Exception do begin writeln('EXCEPTION: ',e.Message);ExitCode:=1;end;end;
   Signal('Engine\Cmd\Exit');
   exit;
  end;
 end;
 // endless mode for NSight: one scenario/variant per frame, shown scaled in the window
 rt:=TargetFor(loopScenario);
 t:=Time.TicksUs;
 gfx.BeginPaint(rt);
 try
  gfx.target.Clear($FF202428,-1,-1);
  RunScenario(loopScenario,loopVariant);
 finally
  gfx.EndPaint;
 end;
 inc(loopTime,Time.TicksUs-t);
 inc(loopFrames);
 if loopFrames=120 then begin
  writeln(Format('%s %s: cpu %.3f ms/frame',[SCENARIO_NAMES[loopScenario],VARIANT_NAMES[loopVariant],loopTime/1000/loopFrames]));
  loopFrames:=0; loopTime:=0;
 end;
 draw.Scaled(0,0,window.canvasWidth,window.canvasHeight,rt);
end;

function ParseArgs:boolean;
var
 s:TScenario;
 v:TVariant;
 found:integer;
begin
 result:=true;
 if ParamCount<2 then exit;
 found:=0;
 for s:=low(TScenario) to high(TScenario) do
  if SameText(ParamStr(1),string(SCENARIO_NAMES[s])) then begin loopScenario:=s; inc(found); end;
 for v:=low(TVariant) to high(TVariant) do
  if SameText(ParamStr(2),string(VARIANT_NAMES[v])) then begin loopVariant:=v; inc(found); end;
 if (found<>2) or not Applicable(loopScenario,loopVariant) then begin
  writeln('Unknown or inapplicable scenario/variant: ',ParamStr(1),' ',ParamStr(2));
  exit(false);
 end;
 loopMode:=true;
 if (ParamCount>=3) and SameText(ParamStr(3),'nodebuggl') then debugGL:=false;
end;

var app:TBenchApp;
begin
 if not ParseArgs then begin ExitCode:=2; exit; end;
 app:=TBenchApp.Create;
 try app.Prepare;app.Run;finally app.Free;end;
end.
