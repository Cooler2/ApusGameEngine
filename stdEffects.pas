// Common scene effects
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by)unit stdEffects;
{$R-}
unit stdEffects;
interface
 uses types,EngineAPI,EventMan,UIScene,MyServis,AnimatedValues;

type
 // Эффект простой прозрачности: сцена набирает прозрачность
 TTransitionEffect=class(TSceneEffect)
  prevscene:TGameScene;
  prevtimer:integer;
  constructor Create(scene,oldscene:TGameScene;TotalTime:integer);
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure Initialize; virtual;
 private
  buffer:TTexture;
  initialized,DontPlay:boolean;
 end;

 // Эффект поворота с масштабированием
 // сцена начинает приближаться и поворачиваться теряя при этом прозрачность
 TRotScaleEffect=class(TSceneEffect)
  newscene:TGameScene;
  constructor Create(scene,nextScene:TGameScene;TotalTime:integer);
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure Initialize; virtual;
 private
  buffer,prevbuf:TTexture;
  initialized,DontPlay:boolean;
 end;

 // Режим показа окнонной сцены (сцена должна быть UI-шной)
 TShowMode=(sweShow,       // просто показать
            sweShowModal,  // показать и сделать окно модальным
            sweHide);      // спрятать
 TShowWindowEffect=class(TSceneEffect)
  // показать или спрятать сцену
  constructor Create(scene:TUIScene;duration:integer;effMode:TShowMode;effect:integer);
  procedure Initialize;
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure onDone;
 private
  buffer:TTexture;
  mode:TShowMode;
  x,y,w,h:integer;
  eff:integer;
  initialized,dontPlay:boolean;
  shadow:cardinal;
  savedSceneStatus:TSceneStatus;
 end;

 {$IFDEF OPENGL}
 TBlurEffect=class(TSceneEffect)
   constructor Create(scene:TUIScene;strength:single;time:integer;colorAdd,colorMult:cardinal);
   procedure Remove(time:integer);
   destructor Destroy; override;
   procedure DrawScene; override;
   procedure Initialize;
 private
  power:TAnimatedValue; // 0..1
  factor:single;
  mainColorAdd,mainColorMult:cardinal;
  width,height:integer;
  buffer,buffer2:TTexture;
  initialized,dontPlay:boolean;
 end;
 {$ENDIF}

 var
   disableEffects:boolean=false;

implementation
 uses {$IFDEF DIRECTX}{d3d8,directXGraphics,}{$ENDIF}
      SysUtils,images,Geom2d,
      {$IFDEF OPENGL}dglOpenGL,PainterGL, {$ENDIF}
      {$IFDEF ANDROID}gles20,PainterGL, {$ENDIF}
      EngineTools,colors,UIClasses,console,UIRender;

 var
  ModalStack:array[1..8] of TUIControl;
  modalStackSize:integer;

  blurLog:string; 

{ TTransitionEffect }
constructor TTransitionEffect.Create(scene,oldscene:TGameScene;TotalTime: integer);
var
 o:integer;
begin
 EnterCriticalSection(UICritSect);
 try
 if scene.effect<>nil then begin
  ForceLogMessage('Scene '+scene.name+' already has an effect!');
 end;
 initialized:=false;
 if scene is TUIScene then ForceLogMessage('TransEff on scene: '+TUIScene(scene).name);
 if oldscene is TUIScene then ForceLogMessage('Prev scene: '+TUIScene(oldscene).name);
 inherited Create(scene,totaltime);
 finally
  LeaveCriticalSection(UICritSect);
 end;
 
 forScene.SetStatus(ssActive);

 EnterCriticalSection(UICritSect);
 try
 if forScene is TUIScene then (forScene as TUIScene).UI.enabled:=false;

 if scene.zorder<=oldscene.zorder then begin
  o:=scene.zorder; scene.zorder:=oldscene.zorder;
  oldscene.zorder:=o;
 end;
 prevscene:=oldscene;
 prevtimer:=0;
 buffer:=nil;
 DontPlay:=DisableEffects;
 if pfRTnorm=ipfNone then DontPlay:=true;
 finally
  LeaveCriticalSection(UICritSect);
 end;
end;

procedure TTransitionEffect.Initialize;
var
 width,height:integer;
begin
 if prevscene is TUIScene then begin
  if FocusedControl.GetRoot=(prevscene as TUIscene).UI then
   SetFocusTo(nil);
  (prevscene as TUIscene).UI.enabled:=false;
 end;
 width:=game.Settings.width;
 height:=game.Settings.height;
 try
  buffer:=texman.AllocImage(width,height,pfRTnorm,aiRenderTarget+aiTexture,'TransEffect');
 except
  on e:exception do begin
   LogMessage('ERROR: eff allocation - '+ExceptionMsg(e));
   dontPlay:=true;
   duration:=1;
  end;
 end;
 initialized:=true;
end;

destructor TTransitionEffect.Destroy;
begin
 if buffer<>nil then texman.FreeImage(buffer);
 inherited;
end;

procedure TTransitionEffect.DrawScene;
var
 color:cardinal;
begin
 if DontPlay then begin
  done:=true; prevscene.SetStatus(ssFrozen);
  if forScene is TUIScene then
   TUIScene(forScene).UI.enabled:=true;
  exit;
 end;
 try
  if not initialized then begin
   Initialize; exit;
  end;
  painter.BeginPaint(buffer);
  forscene.Render;
  painter.EndPaint;
  color:=round(255*timer/duration);
  DebugMessage('EffStage: '+inttostr(color));
  if color>255 then begin
   color:=255;
   done:=true;
   prevscene.SetStatus(ssFrozen);
   if forscene is TUIScene then (forScene as TUIScene).UI.enabled:=true;
  end;
  color:=color shl 24+$808080;
  if buffer<>nil then begin
   painter.BeginPaint(nil);
   painter.DrawImage(0,0,buffer,color);
   painter.EndPaint;
  end;
 except
  on E:Exception do begin
   ForceLogMessage('TransEff error: '+ExceptionMsg(e));
   DontPlay:=true;
  end;
 end;
{ if (timer>time div 2) and (prevtimer<=time div 2) then begin
  forscene.SetStatus(ssActive);
 end;}
 // последняя строчка
 prevtimer:=timer;
end;

{ TRotScaleEffect }

constructor TRotScaleEffect.Create(scene,nextScene: TGameScene; TotalTime: integer);
var
 o:integer;
begin
 initialized:=false;
 inherited Create(scene,totaltime);
 if scene.zorder<=nextscene.zorder then begin
  o:=scene.zorder; scene.zorder:=nextscene.zorder;
  nextscene.zorder:=o;
 end;
 if scene is TUIScene then
  (scene as TUIscene).UI.enabled:=false;
 newscene:=nextScene;
 buffer:=nil;
 DontPlay:=DisableEffects;
 if pfRTnorm=ipfNone then DontPlay:=true;
 newScene.SetStatus(ssActive);
end;

destructor TRotScaleEffect.Destroy;
begin
 texman.FreeImage(buffer);
 inherited;
end;

procedure TRotScaleEffect.Initialize;
var
 width,height:integer;
begin
 width:=game.settings.width;
 height:=game.settings.height;
 try
  buffer:=texman.AllocImage(width,height,pfRTAlphaNorm,aiRenderTarget+aiTexture,'TransEffect');
  prevbuf:=texman.AllocImage(width,height,pfRTAlphaNorm,aiRenderTarget+aiTexture,'TransEffect2');
  painter.BeginPaint(prevbuf);
  forscene.Render;
  painter.EndPaint;
 except
  on e:exception do begin
   LogMessage('ERROR: RSE initialization - '+ExceptionMsg(e));
   dontPlay:=true;
   duration:=1;
  end;
 end;
 initialized:=true;
end;

procedure TRotScaleEffect.DrawScene;
var
 w,h,t:integer;
 l1:TMultiTexLayer;
 tex:TTexture;
begin
 if DontPlay then begin
  done:=true; forscene.SetStatus(ssFrozen);
  exit;
 end;
 try
  if not initialized then begin
   Initialize;
  end;
  t:=round(255*timer/duration);
  if t>=255 then begin
   done:=true;
   forscene.SetStatus(ssFrozen);
   if newscene is TUIScene then (forScene as TUIScene).UI.enabled:=true;
  end;
  painter.BeginPaint(buffer);
  try

{  device.SetTextureStageState(0,D3DTSS_ALPHAOP,D3DTOP_SELECTARG1);
  device.SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_DIFFUSE);
  device.SetTextureStageState(0,D3DTSS_COLOROP,D3DTOP_SELECTARG1);
  device.SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_TEXTURE);}

  w:=game.settings.width-1;
  h:=game.settings.height-1;
  l1.texture:=prevbuf as TTextureImage;
  l1.matrix[0,0]:=1; l1.matrix[0,1]:=0;
  l1.matrix[1,0]:=0; l1.matrix[1,1]:=1;
  l1.matrix[2,0]:=0; l1.matrix[2,1]:=0;
  l1.next:=nil;
  painter.SetMode(blMove);
  painter.DrawMultiTex(0,0,w,h,@l1,$FF808080);
  finally
   painter.EndPaint;
  end;
  painter.SetMode(blAlpha);

  painter.BeginPaint(nil);
  try
   painter.DrawImage(0,0,buffer,$FF808080);
  finally
   painter.EndPaint;
  end;

  tex:=buffer;
  buffer:=prevbuf;
  prevbuf:=tex;

 except
  on E:Exception do begin
   ForceLogMessage('RotScalEff error: '+ExceptionMsg(e));
   DontPlay:=true;
  end;
 end;
end;

procedure LogModalStack;
var
 st:string;
 i:integer;
begin
 st:='';
 for i:=1 to modalstacksize do
  st:=st+modalstack[i].GetName+' > ';
 st:=st+'('+modalcontrol.GetName+')';
 LogMessage('ModalStack: '+st+' #'+inttostr(modalStackSize));
end;


{ TShowWindowEffect }
constructor TShowWindowEffect.Create(scene: TUIScene; duration: integer;
  effMode: TShowMode;effect:integer);
var
 c:TUIControl;
 i:integer;
begin
 try
 if (effMode in [sweSHow,sweShowModal]) and (scene.status=ssActive) then begin
  LogMessage('SWE for active scene IGNORED! '+scene.name+' : '+scene.UI.name);
  exit;
 end;
 if (effMode=sweHide) and (not scene.activated) then begin
  LogMessage('sweHide for inactive scene IGNORED! '+scene.name+' : '+scene.UI.name);
  exit;
 end;
 initialized:=false;
 buffer:=nil;
 // Показ модального окна
 EnterCriticalSection(UICritSect);
 try
  PutMsg(Format('WndEffStart(%s,%d,%d,%d)',[scene.UI.name,duration,ord(effMode),effect]));
  inherited Create(scene,duration);
  DontPlay:=DisableEffects or (duration<=0);
  if pfRTAlphaNorm=ipfNone then DontPlay:=true;
  mode:=effMode; buffer:=nil;
  shadow:=scene.shadowColor;

{ if (mode=sweShowModal) or (mode=sweShow) then
  scene.UI.visible:=true;}

 if (mode<>sweHide) and (forScene.status<>ssActive) then begin
  savedSceneStatus:=forScene.status;
  forScene.SetStatus(ssActive);
 end;
 scene.UI.enabled:=(mode<>sweHide);

 if mode=sweShowModal then begin
  scene.shadowColor:=0;
  // симуляция отпускания кнопок мыши
  SetFocusTo(nil);
//  в этом больше нет необходимости, т.к. потеря фокуса обрабатывается на общем уровне
//  Signal('Mouse\BtnUp\Left',1);
//  Signal('Mouse\BtnUp\Right',1);
  if modalcontrol<>nil then begin
   // поищем, какой сцене принадлежит текущий модельный элемент и если
   // новое окно находится в том же слое - поместим его поверху. В противном случае
   // вставим новую сцену в нужное место в стэке
   c:=modalControl;
   while c.parent<>nil do c:=c.parent;
   if (c.order and $FF0000=scene.UI.order and $FF0000) and
      (c.order>scene.UI.order) then scene.UI.order:=c.order+1;
  end else
   Signal('UI\SetGlobalShadow',$FF+duration shl 8);

  if scene.zorder<scene.UI.order then scene.zorder:=scene.ui.order
   else scene.UI.order:=scene.zorder;

  inc(modalStackSize);
  i:=ModalStackSize;
  while (i>1) and (modalstack[i-1]<>nil) and (modalStack[i-1].order>c.order) do begin
   modalStack[i]:=modalStack[i-1];
   dec(i);
   LogMessage('ModalStack: insert');
  end;
  modalStack[i]:=modalControl;
  if i=modalStackSize then begin
   modalControl:=(forScene as TUIScene).UI;
   modalControl.SetFocus;
  end;
  LogModalStack;
 end;
 // сцена закрывается
 if (mode=sweHide) then begin
  if focusedControl.GetRoot=scene.UI then
    SetFocusTo(nil);
  scene.activated:=false;
  // проверим, есть ли данная сцена в стеке модальности
  if modalStackSize>0 then begin
   i:=1;
   while (i<=modalStackSize) and (modalStack[i]<>scene.UI) do inc(i);
   if (i>modalStackSize) and (modalControl=scene.UI) then begin // сцена на вершине стека
    modalControl:=modalStack[modalStackSize];
    if modalControl<>nil then modalControl.SetFocus;
    dec(modalStackSize);
   end;
   if (i>1) and (i<=modalStackSize) then begin // Сцена где-то внутре
    LogMessage('ModalStack: unshift '+inttostr(i));
    while i<modalStackSize do begin
     modalStack[i]:=modalStack[i+1];
     inc(i);
    end;
    dec(modalStackSize);
   end;
  end;
  LogModalStack;
  if modalControl=nil then
    Signal('UI\SetGlobalShadow',duration shl 8);
 end;

 eff:=effect;

 if duration=0 then onDone; // Immediate action

 finally
  LeaveCriticalSection(UICritSect);
 end;
 except
  on e:exception do ForceLogMessage('Failed to create SWE effect: '+ExceptionMsg(e));
 end;
end;

function GetModeName(m:TShowMode):string;
begin
 case m of
  sweShow:result:='Show';
  sweHide:result:='Hide';
  sweShowModal:result:='ShowModal';
 end;
end;

procedure TShowWindowEffect.Initialize;
var
 r:TRect;
begin
 Signal('UI\onEffect\'+GetModeName(mode)+'\'+(forscene as TUIScene).name);
 with forscene as TUIScene do begin
  r:=GetArea;
  w:=r.right-r.left;
  h:=r.Bottom-r.top;
  x:=r.Left;
  y:=r.Top;
{  dec(UI.x,x);
  dec(UI.y,y);}
 end;
 if w=0 then
  r:=TUIScene(forScene).GetArea;

 try
  LogMessage(Format('WndEffect: allocating %d x %d buffer',[w,h]));
  buffer:=texman.AllocImage(w,h,pfRTAlphaNorm,aiRenderTarget+aiTexture,'WndEffect');
  if buffer=nil then raise EError.Create('WndEffect: buffer not allocated!');
 except
   on e:exception do begin
    LogMessage('ERROR: eff allocation - '+ExceptionMsg(e));
    dontPlay:=true;
    duration:=1;
   end;
 end;
// painter.SetTargetToTexture(buffer);
{ with forscene as TUIScene do begin
  UI.x:=x; UI.y:=y;
 end;}

 initialized:=true;
end;

destructor TShowWindowEffect.Destroy;
begin
 try
  if not done then onDone;
  if initialized and (buffer<>nil) then texman.FreeImage(buffer);
  if forscene<>nil then PutMsg('WndEffDone('+(forscene as TUISCene).UI.name+')');
  inherited;
 except
  on e:exception do ForceLogMessage('Failed to delete SWE effect: '+ExceptionMsg(e));
 end;
end;

procedure TShowWindowEffect.DrawScene;
var
 stage:integer;
 color:cardinal;
 cx,cy,dx,dy:integer;
 scaleX,scaleY,centerX,centerY:double;
 savePos:TPoint2s;
begin
 if DontPlay then begin
  onDone; exit;
 end;
 if not initialized then Initialize;
 with forscene as TUIScene do begin
  savePos:=ui.position;
  VectAdd(ui.position,Point2s(-x,-y));  // offset scene so it's visible part starts at 0,0
 end;
 try
  if buffer=nil then  raise EError.Create('WndEffect failure: buffer not allocated!');
  painter.BeginPaint(buffer);
  try
   // Background is set to opaque for debug purpose: in transpBgnd mode scene MUST overwrite
   // alpha channel, not blend into it! If the background is transparent it's very easy to miss this mistake
   painter.Clear($FF808080,-1,-1);
   forscene.Process;
   transpBgnd:=true;
   forscene.Render;
   transpBgnd:=false;
  finally
   painter.EndPaint;
   TUIScene(forscene).ui.position:=savePos;
  end;
 except
  on e:exception do begin
   dontPlay:=true;
   ForceLogMessage('Error: SWE:D '+ExceptionMsg(e));
  end;
 end;

 stage:=round(255*timer/duration);
 if stage<0 then stage:=0;
 if stage>255 then begin
  stage:=255;
  onDone;
 end;
 if mode=sweHide then stage:=255-stage;
 if shadow<>0 then
  forscene.shadowColor:=ColorMix(shadow,shadow and $FFFFFF,stage);

 painter.BeginPaint(nil);
 try
 if eff=1 then begin
  // Эффект изменения прозрачности
  color:=cardinal(stage) shl 24+$808080;
  painter.DrawImage(x,y,buffer,color);
 end;
 if eff=2 then begin
  // Эффект "телевизора"
//  color:=round(300-10000/(stage+34));
  color:=stage;
  if color>255 then color:=255;
  color:=color shl 24+$808080;
  cx:=x+w div 2; cy:=y+h div 2;
  dx:=round(w*sqrt(sin(pi*stage/512))/2);
  dy:=round((h-4)*(1-sqrt(cos(pi*stage/512)))/2)+2;
  painter.DrawScaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,color);
 end;
 if eff=3 then begin
  // обратный телевизор (выключение)
  stage:=255-stage;
  color:=round(stage*0.9);
  color:=ColorAdd($FF808080,color+color shl 8+color shl 16);
  color:=colorSub(color,Sat(stage*2-250,0,255) shl 24);
  cx:=x+w div 2; cy:=y+h div 2;
  dy:=round(h*exp(-stage/70)/2);
  dx:=round(w/2+exp(2+stage/60)-7);
  painter.DrawScaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,color);
 end;
 if eff in [4,8] then begin
  // появление снизу
  color:=Sat(round(stage*1.2),0,255) shl 24+$808080;
//  dy:=round(h*spline(stage/256,0,1.2,1,0,0.6));
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  painter.DrawScaled(x,y+h-dy-cy,x+w,y+h-cy,buffer,color);
 end;
 if eff in [5,9] then begin
  // появление сверху
  color:=Sat(round(stage*1.2),0,255) shl 24+$808080;
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  painter.DrawScaled(x,y+cy,x+w,y+cy+dy,buffer,color);
 end;
 if eff in [6,10] then begin
  // появление слева
  color:=Sat(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  painter.DrawScaled(x+cx,y,x+cx+dx,y+h,buffer,color);
 end;
 if eff in [7,11] then begin
  // появление справа
  color:=Sat(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  painter.DrawScaled(x-cx+w-dx,y,x+w-cx,y+h,buffer,color);
 end;
 if eff=22 then begin
  // Эффект масштабирования (не особо линейного)
  color:=stage;
  if color>255 then color:=255;
  color:=color shl 24+$808080;
  centerX:=x+w div 2; centerY:=y+h div 2;
  scaleX:=Spline(stage/255,0.6,0.3,1,0,0.5);
  scaleY:=scaleX;
  painter.DrawScaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
    centerX+scaleX*w/2,centerY+scaleY*h/2,buffer,color);
 end;
 if eff=23 then begin
  // Эффект масштабирования (не особо линейного)
  color:=stage;
  if color>255 then color:=255;
  color:=color shl 24+$808080;
  centerX:=x+w div 2; centerY:=y+h div 2;
  scaleX:=Spline(stage/255,0.6,0.3,1,0.05,0.5);
  scaleY:=Spline(stage/255,0.3,0.4,1,0.05,0.5);
  painter.DrawScaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
    centerX+scaleX*w/2,centerY+scaleY*h/2,buffer,color);
 end;

 except
  on e:exception do ForcelogMessage('WndEff error: '+ExceptionMsg(e));
 end;
 painter.EndPaint;
end;

procedure TShowWindowEffect.onDone;
var
 needStatus:TSceneStatus;
begin
 needStatus:=savedSceneStatus;
 if needStatus=ssActive then needStatus:=ssFrozen;
 if (mode=sweHide) and (forScene.status<>needStatus) then forScene.SetStatus(needStatus);
 done:=true;
end;

{$IFDEF OPENGL}
const
 // version for GLPainter
 vBlurShader=
  'uniform float offsetX;'+
  'uniform float offsetY;'+
  'void main(void)'+
  '{'+
  '        gl_TexCoord[0] = gl_MultiTexCoord0;                           '+
  '        gl_TexCoord[1] = gl_MultiTexCoord0+vec4(offsetX,offsetY,0,0);   '+
  '        gl_TexCoord[2] = gl_MultiTexCoord0+vec4(-offsetX,offsetY,0,0);  '+
  '        gl_TexCoord[3] = gl_MultiTexCoord0+vec4(offsetX,-offsetY,0,0);  '+
  '        gl_TexCoord[4] = gl_MultiTexCoord0+vec4(-offsetX,-offsetY,0,0); '+
  '      '+
  '        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;       '+
  '}';

 fBlurShader=
  'uniform sampler2D tex1;                                       '+
  'uniform sampler2D tex2; '+
  'uniform float v1; '+
  'uniform float v2; '+
  'uniform vec4 colorAdd; '+
  'uniform vec4 colorMult; '+
  'void main(void)                                                       '+
  '{                                                                     '+
  '        vec4 value0 = texture2D(tex1, vec2(gl_TexCoord[0]));  '+
  '        vec4 value1 = texture2D(tex2, vec2(gl_TexCoord[1]));  '+
  '        vec4 value2 = texture2D(tex2, vec2(gl_TexCoord[2]));  '+
  '        vec4 value3 = texture2D(tex2, vec2(gl_TexCoord[3]));  '+
  '        vec4 value4 = texture2D(tex2, vec2(gl_TexCoord[4]));  '+
  '                                                                      '+
  '        gl_FragColor = colorAdd + (value0*v1 + value1*v2 + value2*v2 + value3*v2 + value4*v2)*colorMult;  '+
  '}';

 // version for GLPainter2
 vBlurShader2=
  'attribute vec3 aPosition;   '#13#10+
  'attribute vec4 aColor;      '#13#10+
  'attribute vec2 aTexcoord;   '#13#10+
  'varying vec2 vTexcoord;'#13#10+
  'varying vec2 vPos;'#13#10+
  'void main(void) '#13#10+
  '{ '#13#10+
//  '  vTexcoord = aTexcoord;      '#13#10+
  '  vTexcoord = vec2(0.5+aPosition.x/200,0.5-aPosition.y/200);    '#13#10+
  '  gl_Position = vec4(0.01 * aPosition, 1.0);   '#13#10+
  '  vPos = gl_Position; '#13#10+
  '}';

 fBlurShader2=
  'uniform sampler2D tex1; '#13#10+
  'uniform sampler2D tex2; '#13#10+
  'uniform float offsetX; '#13#10+
  'uniform float offsetY; '#13#10+
  'uniform float v1; '#13#10+
  'uniform float v2; '#13#10+
  'uniform vec4 colorAdd; '#13#10+
  'uniform vec4 colorMult; '#13#10+
  'varying vec2 vTexcoord;'#13#10+
  'varying vec2 vPos;'#13#10+
  'void main(void)   '#13#10+
  '{   '#13#10+
  '   vec4 value = v1 * texture2D(tex1, vTexcoord);  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(offsetX,offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(-offsetX,offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(offsetX,-offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(-offsetX,-offsetY));  '#13#10+
  '   gl_FragColor = colorAdd + value*colorMult;  '#13#10+
//  '   gl_FragColor = vec4(fract(vPos.x), fract(vPos.y), 0.5, 1.0);  '#13#10+
  '}';

var
 blurShader:integer=0;  
 loc1,loc2,loc3,loc4,locCA,locCM,locTex1,locTex2:integer;

destructor TBlurEffect.Destroy;
begin
 inherited;
 blurLog:=blurLog+'F';
 texman.FreeImage(buffer);
 texman.FreeImage(buffer2);
// texman.FreeImage(buffer3);
end;

constructor TBlurEffect.Create(scene: TUIScene; strength: single;time:integer;colorAdd,colorMult:cardinal);
begin
 if scene.effect<>nil then begin
  LogMessage('WARN! BlurEff skipped - scene already has effect: '+scene.name);
  exit;
 end;
 LogMessage('BlurEff for '+scene.name);
 initialized:=false;
 width:=min2(round(scene.UI.size.x),game.settings.width);
 height:=min2(round(scene.UI.size.y),game.settings.height);

 power.Init(0);
 power.Animate(strength,time,spline0);
 factor:=strength;
 dontPlay:=disableEffects;
 mainColorAdd:=colorAdd;
 mainColorMult:=colorMult;
 inherited Create(scene,1000000);
 blurLog:=blurLog+'C';
end;

procedure TBlurEffect.Initialize;
var
 vsh,fsh,attrib:string;
begin
 try
 if blurShader=0 then begin
  if painter.classname='TGLPainter2' then begin
   vsh:=vBlurShader2;
   fsh:=fBlurShader2;
   attrib:='aPosition,aColor,aTexcoord';
  end else begin
   vsh:=vBlurShader;
   fsh:=fBlurShader;
   attrib:='';
  end;
  blurShader:=TGLPainter(painter).BuildShaderProgram(vsh,fsh,attrib);
  if blurShader=0 then begin
   dontPlay:=true; exit;
  end;
  loc1:=glGetUniformLocation(blurShader,'offsetX');
  loc2:=glGetUniformLocation(blurShader,'offsetY');
  loc3:=glGetUniformLocation(blurShader,'v1');
  loc4:=glGetUniformLocation(blurShader,'v2');
  locCA:=glGetUniformLocation(blurShader,'colorAdd');
  locCM:=glGetUniformLocation(blurShader,'colorMult');
  locTex1:=glGetUniformLocation(blurShader,'tex1');
  locTex2:=glGetUniformLocation(blurShader,'tex2');
 end;
 
 buffer:=texman.AllocImage(width,height,pfRTNorm,aiRenderTarget+aiClampUV,'BlurBuf1');
 buffer2:=texman.AllocImage(width div 2,height div 2,pfRTNorm,aiRenderTarget+aiClampUV,'BlurBuf2');
 initialized:=true;
 blurLog:=blurLog+'I';
 except
  on e:exception do begin
   dontPlay:=true;
   LogMessage('Erorr in BlurEff init: '+ExceptionMsg(e));
  end;
 end;
end;

var
 debug:integer=0;

procedure TBlurEffect.DrawScene;
var
 u,v,f:single;
 i:integer;
 cb:array[0..3] of byte;
 cf:array[0..3] of single;
begin
 try
  if not initialized then Initialize;
  if dontPlay or ((power.value=0) and (power.finalValue=0)) then begin
   done:=true;
   painter.BeginPaint(nil);
   try
    forScene.Render;
   finally
    painter.EndPaint;
   end;
   exit;
  end;
  blurLog:=blurLog+'D';
  // Render source scene
  painter.BeginPaint(buffer);
  try
   forscene.Render;
   inc(debug);
//   if debug=15 then glActiveTexture(100);
   {ainter.Clear($50);
   for i:=1 to 22 do begin
    painter.Rect(i*23,i*15,screenWidth-i*23,screenHeight-i*15,$FFFFFF00);
    painter.Rect(i*23+1,i*15+1,screenWidth-i*23-1,screenHeight-i*15-1,$FFFFFF00);
   end;}
  finally
   painter.EndPaint;
  end;

  // Downsample
{  painter.BeginPaint(buffer2);
  try
  u:=1+buffer.stepU*4;
  v:=1+buffer.stepV*4;
  painter.TexturedRect(0,0,buffer2.width,buffer2.height,buffer,0,0,u,0,u,v,$FF808080);
  finally
   painter.EndPaint;
  end;}

{  f:=factor*power.value;
  if f>1 then begin
   painter.BeginPaint(buffer3);
   u:=1+buffer2.stepU*4;
   v:=1+buffer2.stepV*4;
   painter.TexturedRect(0,0,buffer3.width,buffer3.height,buffer2,0,0,u,0,u,v,$FF808080);
   painter.EndPaint;
  end;}

  painter.BeginPaint(nil);
  try
  painter.UseCustomShader;
  glUseProgram(blurShader);
  TGLPainter(painter).UseTexture(buffer2,1);
//  v:=0.5+0.5*sin(MyTickCount/300);
  v:=sqrt(power.Value);

  glUniform1f(loc1,1.5*buffer2.stepU*v);
  glUniform1f(loc2,1.5*buffer2.stepV*v);
  glUniform1f(loc3,2/6 {1-v}); // amount of 1-sampled texture
  glUniform1f(loc4,1/6 {v/4}); // amount of 4-sampled texture
  glUniform1i(locTex1,0); // 1-sampled texture - reduced
  glUniform1i(locTex2,0); // 4-sampled texture - original image

  v:=power.Value;
  move(mainColorAdd,cb,4);
  for i:=0 to 2 do cf[i]:=cb[i]*v/255;
  glUniform4f(locCA,cf[2],cf[1],cf[0],0);

  move(mainColorMult,cb,4);
  for i:=0 to 2 do cf[i]:=(1-v)+cb[i]*v*2/255;
  glUniform4f(locCM,cf[2],cf[1],cf[0],1); 

  if painter.ClassName='TGLPainter2' then begin
   u:=200*(1/buffer.width);
   v:=200*(1/buffer.height);
   painter.DrawScaled(-100-u,-100-v,100+u,100+v,buffer);
//   painter.DrawScaled(-20,-20,70,50,buffer);
  end else
   painter.DrawImage(0,0,buffer);

  painter.ResetTexMode;
  finally
   painter.EndPaint;
  end;
 except
  on e:exception do begin
   ForceLogMessage('Error in BlurEff: '+ExceptionMsg(e));
   dontPlay:=true;
  end;
 end;
end;

procedure TBlurEffect.Remove(time: Integer);
begin
 if not done then power.Animate(0,time,spline2);
end;
{$ENDIF}

end.
