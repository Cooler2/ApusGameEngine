// Common scene effects
//
// Copyright (C) 2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
unit Apus.Engine.SceneEffects;
interface
 uses Types, Apus.Engine.API, Apus.EventMan, Apus.Engine.UIScene, Apus.MyServis, Apus.AnimatedValues;

type
 // Base class for effects used to switch fullscreen scenes from the current topmost visible scene to a chosen one
 TSwitchScreenEffect=class(TSceneEffect)
  prevScene:TGameScene;
  prevTimer:integer;
  constructor Create(scene:TGameScene;totalTime:integer);
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure Initialize; virtual;
 protected
  initialized,dontPlay:boolean;
  buffer:TTexture;
 end;

 // Simple fade effect
 TTransitionEffect=class(TSwitchScreenEffect)
  procedure DrawScene; override;
 end;

 // Fade effect with rotation and scaling
 // сцена начинает приближаться и поворачиваться теряя при этом прозрачность
 TRotScaleEffect=class(TSwitchScreenEffect)
  newscene:TGameScene;
  constructor Create(scene,nextScene:TGameScene;TotalTime:integer);
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure Initialize; override;
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
   constructor Create(scene:TGameScene;strength:single;time:integer;colorAdd,colorMult:cardinal);
   procedure Remove(time:integer);
   destructor Destroy; override;
   procedure DrawScene; override;
   procedure Initialize;
 private
  power:TAnimatedValue; // 0..1
  factor:single; // strength
  mainColorAdd,mainColorMult:cardinal;
  width,height:integer;
  buffer,buffer2:TTexture;
  initialized,dontPlay:boolean;
 end;
 {$ENDIF}

 var
   disableEffects:boolean=false; // true - disable all effects

implementation
 uses Math,SysUtils, Apus.Images, Apus.Geom2D,
      {$IFDEF OPENGL}dglOpenGL, {$ENDIF}
      {$IFDEF ANDROID}gles20, Apus.Engine.PainterGL, {$ENDIF}
      Apus.Colors,Apus.Engine.UI,Apus.Engine.Console,Apus.Engine.UIRender;

 var
  ModalStack:array[1..8] of TUIElement;
  modalStackSize:integer;

  blurLog:string;

{ TFullScreenEffect }

constructor TSwitchScreenEffect.Create(scene: TGameScene; totalTime: integer);
begin
 LockUI(GetCaller);
 try
 if scene.effect<>nil then begin
  ForceLogMessage('Scene '+scene.name+' already has an effect!');
 end;
 initialized:=false;
 prevScene:=game.TopmostVisibleScene(true);
 ASSERT(scene<>prevScene);
 if scene is TUIScene then LogMessage('Effect %s on scene %s',[ClassName,TUIScene(scene).name]);
 if prevScene is TUIScene then LogMessage('Prev scene: '+TUIScene(prevScene).name);
 inherited Create(scene,totaltime);
 finally
  UnlockUI;
 end;

 target.SetStatus(TSceneStatus.ssActive);

 LockUI(GetCaller);
 try
 if target is TUIScene then (target as TUIScene).UI.enabled:=false;

 if scene.zOrder=prevScene.zOrder then begin
  inc(scene.zOrder);
  LogMessage('zOrder incremented: %s=%d, %s=%d',[scene.name,scene.zOrder,prevScene.name,prevScene.zOrder]);
 end;
 if scene.zorder<prevScene.zorder then begin
  Swap(scene.zOrder,prevScene.zOrder);
  LogMessage('zOrder swap: %s=%d, %s=%d',[scene.name,scene.zOrder,prevScene.name,prevScene.zOrder]);
 end;
 prevTimer:=0;
 dontPlay:=disableEffects;
 if pfRenderTarget=ipfNone then dontPlay:=true;
 finally
  UnlockUI;
 end;
end;

destructor TSwitchScreenEffect.Destroy;
begin
 if buffer<>nil then FreeImage(buffer);
 inherited;
end;

procedure TSwitchScreenEffect.DrawScene;
begin
 if DontPlay then begin
  done:=true; prevscene.SetStatus(TSceneStatus.ssFrozen);
  if target is TUIScene then
   TUIScene(target).UI.enabled:=true;
  exit;
 end;
 if not initialized then Initialize;
end;

procedure TSwitchScreenEffect.Initialize;
var
 width,height:integer;
begin
 if prevscene is TUIScene then begin
  if FocusedElement.GetRoot=(prevscene as TUIscene).UI then
   SetFocusTo(nil);
  (prevscene as TUIscene).UI.enabled:=false;
 end;
 width:=game.GetSettings.width;
 height:=game.GetSettings.height;
 try
  buffer:=AllocImage(width,height,pfRenderTarget,aiRenderTarget+aiTexture,'SceneEffect');
 except
  on e:exception do begin
   LogMessage('ERROR: eff allocation - '+ExceptionMsg(e));
   dontPlay:=true;
   duration:=1;
  end;
 end;
 initialized:=true;
end;

{ TTransitionEffect }

procedure TTransitionEffect.DrawScene;
var
 color:cardinal;
begin
 inherited;
 try
  gfx.BeginPaint(buffer);
  target.Render;
  gfx.EndPaint;
  color:=round(255*timer/duration);
  DebugMessage('EffStage: '+inttostr(color));
  if color>255 then begin
   color:=255;
   done:=true;
   prevscene.SetStatus(TSceneStatus.ssFrozen);
   if target is TUIScene then (target as TUIScene).UI.enabled:=true;
  end;
  color:=color shl 24+$808080;
  if buffer<>nil then begin
   draw.Image(0,0,buffer,color);
  end;
 except
  on E:Exception do begin
   ForceLogMessage('TransEff error: '+ExceptionMsg(e));
   DontPlay:=true;
  end;
 end;
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
 if pfRenderTarget=ipfNone then DontPlay:=true;
 newScene.SetStatus(TSceneStatus.ssActive);
end;

destructor TRotScaleEffect.Destroy;
begin
 FreeImage(buffer);
 inherited;
end;

procedure TRotScaleEffect.Initialize;
var
 width,height:integer;
begin
 width:=game.GetSettings.width;
 height:=game.GetSettings.height;
 try
  buffer:=AllocImage(width,height,pfRenderTarget,aiRenderTarget+aiTexture,'TransEffect');
  prevbuf:=AllocImage(width,height,pfRenderTarget,aiRenderTarget+aiTexture,'TransEffect2');
  gfx.BeginPaint(prevbuf);
  target.Render;
  gfx.EndPaint;
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
  done:=true;
  target.SetStatus(TSceneStatus.ssFrozen);
  exit;
 end;
 try
  if not initialized then begin
   Initialize;
  end;
  t:=round(255*timer/duration);
  if t>=255 then begin
   done:=true;
   target.SetStatus(TSceneStatus.ssFrozen);
   if newscene is TUIScene then (target as TUIScene).UI.enabled:=true;
  end;
  gfx.BeginPaint(buffer);
  try

  /// TODO: replace with proper value (probably renderRect)
  w:=game.GetSettings.width-1;
  h:=game.GetSettings.height-1;
  l1.texture:=prevbuf;
  l1.matrix[0,0]:=1; l1.matrix[0,1]:=0;
  l1.matrix[1,0]:=0; l1.matrix[1,1]:=1;
  l1.matrix[2,0]:=0; l1.matrix[2,1]:=0;
  l1.next:=nil;
  gfx.target.BlendMode(blMove);
  //draw.MultiTex(0,0,w,h,@l1,$FF808080);
  finally
   gfx.EndPaint;
  end;
  gfx.target.BlendMode(blAlpha);

  draw.Image(0,0,buffer,$FF808080);

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
 st:=st+'('+modalElement.GetName+')';
 LogMessage('ModalStack: '+st+' #'+inttostr(modalStackSize));
end;


{ TShowWindowEffect }
constructor TShowWindowEffect.Create(scene: TUIScene; duration: integer;
  effMode: TShowMode;effect:integer);
var
 c:TUIElement;
 i:integer;
begin
 try
 if (effMode in [sweSHow,sweShowModal]) and scene.IsActive then begin
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
 game.EnterCritSect;
 try
  PutMsg(Format('WndEffStart(%s,%d,%d,%d)',[scene.UI.name,duration,ord(effMode),effect]));
  inherited Create(scene,duration);
  dontPlay:=DisableEffects or (duration<=0);
  if pfRenderTargetAlpha=ipfNone then DontPlay:=true;
  mode:=effMode; buffer:=nil;
  shadow:=scene.shadowColor;
  if effMode<>sweHide then scene.shadowColor:=0;

{ if (mode=sweShowModal) or (mode=sweShow) then
  scene.UI.visible:=true;}

 if (mode<>sweHide) and not target.IsActive then begin
  savedSceneStatus:=target.status;
  target.SetStatus(TSceneStatus.ssActive);
 end;
 scene.UI.enabled:=(mode<>sweHide);

 if mode=sweShowModal then begin
  scene.shadowColor:=0;
  // симуляция отпускания кнопок мыши
  SetFocusTo(nil);
  if modalElement<>nil then begin
   // поищем, какой сцене принадлежит текущий модальный элемент и если
   // новое окно находится в том же слое - поместим его поверху. В противном случае
   // вставим новую сцену в нужное место в стэке
   c:=modalElement;
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
  modalStack[i]:=modalElement;
  if i=modalStackSize then begin
   SetModalElement((target as TUIScene).UI);
   modalElement.SetFocus;
  end;
  LogModalStack;
 end;
 // сцена закрывается
 if (mode=sweHide) then begin
  if focusedElement.GetRoot=scene.UI then
    SetFocusTo(nil);
  scene.activated:=false;
  // проверим, есть ли данная сцена в стеке модальности
  if modalStackSize>0 then begin
   i:=1;
   while (i<=modalStackSize) and (modalStack[i]<>scene.UI) do inc(i);
   if (i>modalStackSize) and (modalElement=scene.UI) then begin // сцена на вершине стека
    SetModalElement(modalStack[modalStackSize]);
    if modalElement<>nil then modalElement.SetFocus;
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
  if modalElement=nil then
    Signal('UI\SetGlobalShadow',duration shl 8);
 end;

 eff:=effect;
 if duration=0 then onDone; // Immediate action

 finally
  game.LeaveCritSect;
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
 Signal('UI\onEffect\'+GetModeName(mode)+'\'+(target as TUIScene).name);
 with target as TUIScene do begin
  r:=GetArea;
  w:=r.right-r.left;
  h:=r.Bottom-r.top;
  x:=r.Left;
  y:=r.Top;
 end;
 if w=0 then
  r:=TUIScene(target).GetArea;

 try
  LogMessage(Format('WndEffect: allocating %d x %d buffer',[w,h]));
  buffer:=AllocImage(w,h,pfRenderTargetAlpha,aiRenderTarget+aiTexture,'WndEffect');
  if buffer=nil then raise EError.Create('WndEffect: buffer not allocated!');
 except
   on e:exception do begin
    LogMessage('ERROR: eff allocation - '+ExceptionMsg(e));
    dontPlay:=true;
    duration:=1;
   end;
 end;

 initialized:=true;
end;

destructor TShowWindowEffect.Destroy;
begin
 try
  if not done then onDone;
  if initialized and (buffer<>nil) then FreeImage(buffer);
  if target<>nil then begin
   PutMsg('WndEffDone('+(target as TUISCene).UI.name+')');
   target.shadowColor:=shadow;
  end;
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
 with target as TUIScene do begin
  savePos:=ui.position;
  VectAdd(ui.position,Point2s(-x,-y));  // offset scene so it's visible part starts at 0,0
 end;
 try
  if buffer=nil then  raise EError.Create('WndEffect failure: buffer not allocated!');
  gfx.BeginPaint(buffer);
  try
   // Background is set to opaque for debug purpose: in transpBgnd mode scene MUST overwrite
   // alpha channel, not blend into it! If the background is transparent it's very easy to miss this mistake
   gfx.target.Clear($FF808080,-1,-1);
   target.Process;
   transpBgnd:=true;
   target.Render;
   transpBgnd:=false;
  finally
   gfx.EndPaint;
   TUIScene(target).ui.position:=savePos;
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
  target.shadowColor:=ColorMix(shadow,shadow and $FFFFFF,stage);

 try
 if eff=1 then begin
  // Эффект изменения прозрачности
  color:=cardinal(stage) shl 24+$808080;
  draw.Image(x,y,buffer,color);
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
  draw.Scaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,color);
 end;
 if eff=3 then begin
  // обратный телевизор (выключение)
  stage:=255-stage;
  color:=round(stage*0.9);
  color:=ColorAdd($FF808080,color+color shl 8+color shl 16);
  color:=colorSub(color,Clamp(stage*2-250,0,255) shl 24);
  cx:=x+w div 2; cy:=y+h div 2;
  dy:=round(h*exp(-stage/70)/2);
  dx:=round(w/2+exp(2+stage/60)-7);
  draw.Scaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,color);
 end;
 if eff in [4,8] then begin
  // появление снизу
  color:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
//  dy:=round(h*spline(stage/256,0,1.2,1,0,0.6));
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x,y+h-dy-cy,x+w,y+h-cy,buffer,color);
 end;
 if eff in [5,9] then begin
  // появление сверху
  color:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x,y+cy,x+w,y+cy+dy,buffer,color);
 end;
 if eff in [6,10] then begin
  // появление слева
  color:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x+cx,y,x+cx+dx,y+h,buffer,color);
 end;
 if eff in [7,11] then begin
  // появление справа
  color:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x-cx+w-dx,y,x+w-cx,y+h,buffer,color);
 end;
 if eff=22 then begin
  // Эффект масштабирования (не особо линейного)
  color:=stage;
  if color>255 then color:=255;
  color:=color shl 24+$808080;
  centerX:=x+w div 2; centerY:=y+h div 2;
  scaleX:=Spline(stage/255,0.6,0.3,1,0,0.5);
  scaleY:=scaleX;
  draw.Scaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
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
  draw.Scaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
    centerX+scaleX*w/2,centerY+scaleY*h/2,buffer,color);
 end;

 except
  on e:exception do ForcelogMessage('WndEff error: '+ExceptionMsg(e));
 end;
end;

procedure TShowWindowEffect.onDone;
var
 needStatus:TSceneStatus;
begin
 needStatus:=savedSceneStatus;
 if needStatus=TSceneStatus.ssActive then needStatus:=TSceneStatus.ssFrozen;
 if (mode=sweHide) and (target.status<>needStatus) then target.SetStatus(needStatus);
 done:=true;
end;

{$IFDEF OPENGL}
const
 // version for GLPainter2
 vBlurShader2=
  '#version 330 '#13#10+
  'layout (location=0) in vec3 aPosition;    '#13#10+
  'layout (location=1) in vec4 color;      '#13#10+
  'layout (location=2) in vec2 texCoord; '#13#10+
  'uniform float yFactor; '#13#10+
  'out vec2 vTexcoord;'#13#10+
  ''#13#10+
  'void main(void) '#13#10+
  '{ '#13#10+
  '  vTexcoord = vec2(0.5+aPosition.x/200,0.5+aPosition.y*yFactor/200);    '#13#10+
  '  gl_Position = vec4(0.01 * aPosition, 1.0);   '#13#10+
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
  'in vec2 vTexcoord;'#13#10+
  'void main(void)   '#13#10+
  '{   '#13#10+
  '   vec4 value = v1 * texture2D(tex1, vTexcoord);  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(offsetX,offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(-offsetX,offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(offsetX,-offsetY));  '#13#10+
  '   value += v2 * texture2D(tex2, vTexcoord+vec2(-offsetX,-offsetY));  '#13#10+
  '   gl_FragColor = colorAdd + value*colorMult;  '#13#10+
  '}';

var
 blurShader:TShader;

destructor TBlurEffect.Destroy;
begin
 inherited;
 blurLog:=blurLog+'F';
 FreeImage(buffer);
 FreeImage(buffer2);
// texman.FreeImage(buffer3);
end;

constructor TBlurEffect.Create(scene: TGameScene; strength: single;time:integer;colorAdd,colorMult:cardinal);
var
 rect:TRect;
begin
 if scene.effect<>nil then begin
  LogMessage('WARN! BlurEff skipped - scene already has effect: '+scene.name);
  exit;
 end;
 LogMessage('BlurEff for '+scene.name);
 initialized:=false;
 rect:=scene.GetArea;
 width:=min2(rect.width,game.GetSettings.width);
 height:=min2(rect.height,game.GetSettings.height);

 power.Init(0);
 power.Animate(1.0,time,spline0);
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
 if blurShader=nil then begin
  vsh:=vBlurShader2;
  fsh:=fBlurShader2;
  attrib:='aPosition,aColor,aTexcoord';
  blurShader:=gfx.shader.Build(vsh,fsh,attrib);
  if blurShader=nil then begin
   dontPlay:=true; exit;
  end;
 end;

 buffer:=AllocImage(width,height,pfRenderTarget,aiRenderTarget+aiClampUV,'BlurBuf1');
 buffer2:=AllocImage(width div 2,height div 2,pfRenderTarget,aiRenderTarget+aiClampUV,'BlurBuf2');
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
 u,v,f,phase:single;
 i:integer;
 cb:array[0..3] of byte;
 cf:TVector4s;
begin
 try
  if not initialized then Initialize;
  if dontPlay or ((power.value=0) and (power.finalValue=0)) then begin
   done:=true;
   target.Render;
   exit;
  end;
  blurLog:=blurLog+'D';
  // Render source scene
  gfx.BeginPaint(buffer);
  try
   target.Render;
   inc(debug);
  finally
   gfx.EndPaint;
  end;

  // Downsample
{  gfx.BeginPaint(buffer2);
  try
  u:=1+buffer.stepU*4;
  v:=1+buffer.stepV*4;
  draw.TexturedRect(0,0,buffer2.width,buffer2.height,buffer,0,0,u,0,u,v,$FF808080);
  finally
   gfx.EndPaint;
  end;}

{  f:=factor*power.value;
  if f>1 then begin
   gfx.BeginPaint(buffer3);
   u:=1+buffer2.stepU*4;
   v:=1+buffer2.stepV*4;
   draw.TexturedRect(0,0,buffer3.width,buffer3.height,buffer2,0,0,u,0,u,v,$FF808080);
   gfx.EndPaint;
  end;}

  shader.UseCustom(blurShader);
  shader.UseTexture(buffer,0);
  shader.UseTexture(buffer2,1);
  phase:=power.Value;
  v:=sqrt(phase*factor);

  blurShader.SetUniform('offsetX',1.5*buffer2.stepU*v);
  blurShader.SetUniform('offsetY',1.5*buffer2.stepV*v);
  blurShader.SetUniform('v1',2/6);
  blurShader.SetUniform('v2',1/6);
  blurShader.SetUniform('tex1',0);
  blurShader.SetUniform('tex2',0);
  // Since we don't use engine's transformation, we should manually flip Y-coordinate when needed
  blurShader.SetUniform('yFactor',IfThen(gfx.transform.ProjMatrix[1,1]>0,1.0,-1.0));

  v:=phase;
  move(mainColorAdd,cb,4);
  cf.Init(cb[2]*v/255,cb[1]*v/255,cb[0]*v/255,0);
  blurShader.SetUniform('colorAdd',cf);

  move(mainColorMult,cb,4);
  for i:=0 to 2 do cf.v[i]:=(1-v)+cb[i]*v*2/255;
  cf.v[3]:=1.0;
  blurShader.SetUniform('colorMult',cf);

  u:=200*(1/buffer.width);
  v:=200*(1/buffer.height);
  draw.Scaled(-100-u,-100-v,100+u,100+v,buffer);

  shader.Reset;

  //draw.FillRect(0,0,1000,500,$FF009000);

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
