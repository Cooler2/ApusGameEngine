// Common scene effects
//
// Copyright (C) 2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R-}
{$I defines.inc}
unit Apus.Engine.SceneEffects;
interface
 uses Apus.Core, Types, Apus.Engine.API, Apus.EventMan, Apus.Engine.UIScene, Apus.AnimatedValues;

type
 // Base scene switcher
 TBaseSceneSwitcher=class(TSceneSwitcher)
  procedure SwitchToScene(name:string8); override; // switch to a fullscreen scene
  procedure ShowWindowScene(name:string8;modal:boolean=true); override; // show a windowed scene
  procedure HideWindowScene(name:string8); override; // hide a windowed scene
 end;

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
  procedure UpdateBuffer; // keep the buffer as the owner window renders
 end;

 // Simple fade effect
 TTransitionEffect=class(TSwitchScreenEffect)
  procedure DrawScene; override;
 end;

 // Fade effect with rotation and scaling
 // the scene starts approaching and rotating while losing transparency
 TRotScaleEffect=class(TSwitchScreenEffect)
  newscene:TGameScene;
  constructor Create(scene,nextScene:TGameScene;TotalTime:integer);
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure Initialize; override;
 private
  buffer,prevbuf:TTexture;
  initialized,DontPlay:boolean;
  procedure UpdateBuffers; // keep both buffers as the owner window renders
 end;

 // Show mode of a window scene (the scene must be a UI scene)
 TShowMode=(sweShow,       // just show
            sweShowModal,  // show and make the window modal
            sweHide);      // hide
 TShowWindowEffect=class(TSceneEffect)
  // show or hide the scene
  constructor Create(scene:TUIScene;duration:integer;effMode:TShowMode;effect:integer);
  procedure Initialize;
  procedure DrawScene; override;
  destructor Destroy; override;
  procedure onDone;
 protected
  procedure Replace; override;
 private
  buffer:TTexture;
  mode:TShowMode;
  x,y,w,h:integer;
  eff:integer;
  initialized,dontPlay:boolean;
  shadow:cardinal;
  savedSceneStatus:TSceneStatus;
  restored:boolean; // scene state handed back
  procedure RestoreScene;
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
  buffer:TTexture; // the scene
  levels:array[1..3] of TTexture; // the scene downsampled 2x, 4x, 8x
  numLevels:integer; // levels in use: more on a higher DPI
  initialized,dontPlay:boolean;
  procedure UpdateBuffers; // keep the buffers as the owner window renders
  procedure Downsample; // fill the levels from the scene buffer
 end;
 {$ENDIF}

 var
  disableEffects:boolean=false; // true - disable all effects

implementation
 uses Apus.Images, Apus.Geom2D, Apus.Geom3D,
      {$IFDEF GLDESKTOP}dglOpenGL, {$ENDIF}
      {$IFDEF GLES}dglOpenGLES, {$ENDIF}
      Apus.Colors,Apus.Engine.UI,Apus.Engine.UITypes,Apus.Engine.UIRender,
      Apus.Engine.Window,
      Apus.Lib, Apus.Utils;

{ Scene buffers }

// Effects that capture a whole scene render it the way its window does: at the
// surface render size, in the window's canvas coordinates. The requested window
// size (game.GetSettings) is not the surface: fullscreen and resize change it.

function OwnerWindow(scene:TGameScene):TWindow;
begin
 result:=TWindow(scene.ownerWindow);
 ASSERT(result<>nil,'Scene '+scene.name+' has no owner window');
end;

// Keep buf at the window render size divided by divider; reallocated when the surface changes.
// Every effect instance owns its buffers and effects may overlap (a transition starts while
// another one plays, or in another window), so the name gets the '_' prefix: not unique,
// stays out of the global name registry
procedure EnsureSceneBuffer(var buf:TTexture;wnd:TWindow;flags:cardinal;const name:String8;divider:integer=1);
var
 w,h:integer;
begin
 w:=Max(1,wnd.surface.renderSize.cx div divider);
 h:=Max(1,wnd.surface.renderSize.cy div divider);
 if (buf<>nil) and (buf.width=w) and (buf.height=h) then exit;
 if buf<>nil then FreeImage(buf);
 buf:=AllocImage(w,h,pfRenderTarget,flags,'_'+name);
end;

// Start drawing into buf with the canvas of wnd stretched over it
procedure BeginSceneBuffer(buf:TTexture;wnd:TWindow);
begin
 gfx.BeginPaint(buf);
 gfx.target.Viewport(0,0,buf.width,buf.height,wnd.canvasWidth,wnd.canvasHeight);
end;

// Draw buf over the whole canvas of wnd
procedure DrawSceneBuffer(buf:TTexture;wnd:TWindow;color:cardinal);
begin
 draw.TexturedRect(0,0,wnd.canvasWidth-1,wnd.canvasHeight-1,buf,0,0,1,0,1,1,color);
end;

{ TFullScreenEffect }

constructor TSwitchScreenEffect.Create(scene: TGameScene; totalTime: integer);
var
 wnd:TWindow;
begin
 wnd:=TWindow(scene.ownerWindow);
 ASSERT(wnd<>nil,'Can''t resolve owner window for scene '+scene.name);
 wnd.LockState({$IFDEF FPC}get_caller_addr(get_frame){$ELSE}System.ReturnAddress{$ENDIF});
 try
 if scene.effect<>nil then begin
  Log.Force('Scene '+scene.name+' already has an effect!');
 end;
 initialized:=false;
 prevScene:=game.TopmostVisibleScene(true);
 ASSERT(scene<>prevScene);
 if scene is TUIScene then Log.Msg('Effect %s on scene %s',[ClassName,TUIScene(scene).name]);
 if prevScene is TUIScene then Log.Msg('Prev scene: '+TUIScene(prevScene).name);
 inherited Create(scene,totaltime);

 // both scenes get no input until the effect is freed; lock before the activation,
 // so the new scene never accepts input in between
 LockSceneInput(target);
 LockSceneInput(prevScene);
 if prevScene is TUIScene then
  with TUIScene(prevScene).UI do
   if HasFocus then ClearFocus(GetWindow);
 target.SetStatus(TSceneStatus.ssActive);

 if scene.zOrder=prevScene.zOrder then begin
  inc(scene.zOrder);
  Log.Msg('zOrder incremented: %s=%d, %s=%d',[scene.name,scene.zOrder,prevScene.name,prevScene.zOrder]);
 end;
 if scene.zorder<prevScene.zorder then begin
  Swap(scene.zOrder,prevScene.zOrder);
  Log.Msg('zOrder swap: %s=%d, %s=%d',[scene.name,scene.zOrder,prevScene.name,prevScene.zOrder]);
 end;
 prevTimer:=0;
 dontPlay:=disableEffects;
 if pfRenderTarget=ipfNone then dontPlay:=true;
 finally
  wnd.UnlockState;
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
  exit;
 end;
 if not initialized then Initialize;
end;

procedure TSwitchScreenEffect.UpdateBuffer;
var
 flags:cardinal;
begin
 flags:=aiRenderTarget+aiTexture;
 if game.GetSettings.zbuffer>0 then Bits.SetFlag(flags,aiDepthBuffer);
 EnsureSceneBuffer(buffer,OwnerWindow(target),flags,'SceneEffect');
end;

procedure TSwitchScreenEffect.Initialize;
begin
 try
  UpdateBuffer;
 except
  on e:exception do begin
   Log.Msg('ERROR: eff allocation - '+ExceptionMsg(e));
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
 if DontPlay then begin
  target.Render; // no effect: show the scene as is
  exit;
 end;
 try
  UpdateBuffer; // the surface may change while the effect runs
  BeginSceneBuffer(buffer,OwnerWindow(target));
  target.Render;
  gfx.EndPaint;
  color:=round(255*timer/duration);
  {Log.Force('EffStage: '+Conv.ToStr(color));}
  if color>255 then begin
   color:=255;
   done:=true;
   prevscene.SetStatus(TSceneStatus.ssFrozen);
  end;
  color:=color shl 24+$808080;
  if buffer<>nil then
   DrawSceneBuffer(buffer,OwnerWindow(target),color);
 except
  on E:Exception do begin
   Log.Force('TransEff error: '+ExceptionMsg(e));
   DontPlay:=true;
  end;
 end;
 // last line
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
 newscene:=nextScene;
 LockSceneInput(newscene); // before the activation below; the scene itself is locked by inherited
 buffer:=nil;
 DontPlay:=DisableEffects;
 if pfRenderTarget=ipfNone then DontPlay:=true;
 newScene.SetStatus(TSceneStatus.ssActive);
end;

destructor TRotScaleEffect.Destroy;
begin
 FreeImage(buffer);
 FreeImage(prevbuf);
 inherited;
end;

procedure TRotScaleEffect.UpdateBuffers;
var
 wnd:TWindow;
begin
 wnd:=OwnerWindow(target);
 EnsureSceneBuffer(buffer,wnd,aiRenderTarget+aiTexture,'TransEffect');
 EnsureSceneBuffer(prevbuf,wnd,aiRenderTarget+aiTexture,'TransEffect2');
end;

procedure TRotScaleEffect.Initialize;
begin
 try
  UpdateBuffers;
  BeginSceneBuffer(prevbuf,OwnerWindow(target));
  target.Render;
  gfx.EndPaint;
 except
  on e:exception do begin
   Log.Msg('ERROR: RSE initialization - '+ExceptionMsg(e));
   dontPlay:=true;
   duration:=1;
  end;
 end;
 initialized:=true;
end;

procedure TRotScaleEffect.DrawScene;
var
 t:integer;
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
  end;
  // buffers keep their Initialize size: prevbuf holds the only capture of the scene
  gfx.BeginPaint(buffer);
  try

  // TODO: restore the original transition draw pass with an explicit render
  // rect once this effect is covered by a visual regression check.
  gfx.target.BlendMode(blMove);
  //draw.MultiTex(0,0,w,h,@l1,$FF808080);
  finally
   gfx.EndPaint;
  end;
  gfx.target.BlendMode(blAlpha);

  DrawSceneBuffer(buffer,OwnerWindow(target),$FF808080);

  tex:=buffer;
  buffer:=prevbuf;
  prevbuf:=tex;

 except
  on E:Exception do begin
   Log.Force('RotScalEff error: '+ExceptionMsg(e));
   DontPlay:=true;
  end;
 end;
end;

{ TShowWindowEffect }
constructor TShowWindowEffect.Create(scene: TUIScene; duration: integer;
  effMode: TShowMode;effect:integer);
var
 wnd:TWindow; // window that owns the modal state for this scene
begin
 try
 if (effMode in [sweSHow,sweShowModal]) and scene.IsActive then begin
  Log.Msg('SWE for active scene IGNORED! '+scene.name+' : '+scene.UI.name);
  exit;
 end;
 if (effMode=sweHide) and (not scene.activated) then begin
  Log.Msg('sweHide for inactive scene IGNORED! '+scene.name+' : '+scene.UI.name);
  exit;
 end;
 initialized:=false;
 buffer:=nil;
 // Show a modal window
 wnd:=scene.UI.GetWindow;
 wnd.LockState;
 try
  // RenderFrame and effect replacement must use the same owning-window lock.
  Log.Msg('WndEffStart(%s,%d,%d,%d)',[scene.UI.name,duration,ord(effMode),effect]);
  inherited Create(scene,duration);
  dontPlay:=DisableEffects or (duration<=0);
  if pfRenderTargetAlpha=ipfNone then DontPlay:=true;
  mode:=effMode; buffer:=nil;
  shadow:=scene.shadowColor;
  if effMode<>sweHide then scene.shadowColor:=0;

{ if (mode=sweShowModal) or (mode=sweShow) then
  scene.UI.visible:=true;}

 LockSceneInput(scene); // no input while the window moves: the hit-test uses its final layout
 if (mode<>sweHide) and not target.IsActive then begin
  savedSceneStatus:=target.status;
  target.SetStatus(TSceneStatus.ssActive);
 end;
 wnd:=scene.UI.GetWindow; // modal state lives on the owning window

 if mode=sweShowModal then begin
  scene.shadowColor:=0;
  ClearFocus(wnd); // simulate mouse buttons release
  // Push handles order layering and stack insertion. It must run before the
  // zorder/order sync below, which reads the possibly bumped scene.UI.order.
  if not wnd.modal.Push(scene.UI) then begin
   Log.Error('Modal stack overflow in TShowWindowEffect.Create for scene %s',[scene.name]);
   dontPlay:=true;
   duration:=1;
  end;
  if scene.zorder<scene.UI.order then scene.zorder:=scene.ui.order
   else scene.UI.order:=scene.zorder;
  Log.Msg('ModalStack: %s',[wnd.modal.Info]);
 end;
 // scene is being closed
 if (mode=sweHide) then begin
  if scene.UI.HasFocus then ClearFocus(wnd);
  scene.activated:=false;
  wnd.modal.Pop(scene.UI); // remove from the modal stack, reactivate previous (if any)
  Log.Msg('ModalStack: %s',[wnd.modal.Info]);
 end;

 eff:=effect;
 if duration=0 then onDone; // Immediate action

 finally
  wnd.UnlockState;
 end;
 except
  on e:exception do Log.Force('Failed to create SWE effect: '+ExceptionMsg(e));
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
 if w=0 then begin
  r:=TUIScene(target).GetArea;
  w:=r.right-r.left;
  h:=r.Bottom-r.top;
  x:=r.Left;
  y:=r.Top;
 end;
 try
  Log.Msg('WndEffect: allocating %d x %d buffer',[w,h]);
  buffer:=AllocImage(w,h,pfRenderTargetAlpha,aiRenderTarget+aiTexture,'_WndEffect');
  if buffer=nil then raise EError.Create('WndEffect: buffer not allocated!');
 except
   on e:exception do begin
    Log.Error('ERROR: eff allocation - '+ExceptionMsg(e));
    dontPlay:=true;
    duration:=1;
   end;
 end;
 initialized:=true;
end;

// Finish the show/hide and restore the scene shadow (once)
procedure TShowWindowEffect.RestoreScene;
begin
 if restored then exit;
 restored:=true;
 if not done then onDone;
 if target<>nil then target.shadowColor:=shadow;
end;

// The scene state is handed back at once: the new effect starts from it even if
// this object lives until its DrawScene returns
procedure TShowWindowEffect.Replace;
begin
 RestoreScene;
 inherited;
end;

destructor TShowWindowEffect.Destroy;
begin
 try
  RestoreScene;
  if initialized and (buffer<>nil) then FreeImage(buffer);
  inherited;
 except
  on e:exception do Log.Force('Failed to delete SWE effect: '+ExceptionMsg(e));
 end;
end;

procedure TShowWindowEffect.DrawScene;
var
 stage:integer;
 col:cardinal;
 cx,cy,dx,dy:integer;
 scaleX,scaleY,centerX,centerY:double;
 savePos:TVec2;
begin
 if DontPlay then begin
  onDone; exit;
 end;
 if not initialized then Initialize;
 with target as TUIScene do begin
  savePos:=ui.position;
  ui.position.Add(Vec2(-x,-y));  // offset scene so it's visible part starts at 0,0
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
   Log.Force('Error: SWE:D '+ExceptionMsg(e));
  end;
 end;
 if replaced then exit; // a new effect took the scene from inside Process/Render

 stage:=round(255*timer/duration);
 if stage<0 then stage:=0;
 if stage>255 then begin
  stage:=255;
  onDone;
 end;
 if mode=sweHide then stage:=255-stage;
 if shadow<>0 then
  target.shadowColor:=Color.Mix(shadow,shadow and $FFFFFF,stage);

 try
 if eff=1 then begin
  // Opacity change effect
  col:=cardinal(stage) shl 24+$808080;
  draw.Image(x,y,buffer,col);
 end;
 if eff=2 then begin
  // "TV" effect
//  col:=round(300-10000/(stage+34));
  col:=stage;
  if col>255 then col:=255;
  col:=col shl 24+$808080;
  cx:=x+w div 2; cy:=y+h div 2;
  dx:=round(w*sqrt(sin(pi*stage/512))/2);
  dy:=round((h-4)*(1-sqrt(cos(pi*stage/512)))/2)+2;
  draw.Scaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,col);
 end;
 if eff=3 then begin
  // reverse TV (turning off)
  stage:=255-stage;
  col:=round(stage*0.9);
  col:=Color.Add($FF808080,col+col shl 8+col shl 16);
  col:=Color.Sub(col,Clamp(stage*2-250,0,255) shl 24);
  cx:=x+w div 2; cy:=y+h div 2;
  dy:=round(h*exp(-stage/70)/2);
  dx:=round(w/2+exp(2+stage/60)-7);
  draw.Scaled(cx-dx,cy-dy,cx+dx,cy+dy,buffer,col);
 end;
 if eff in [4,8] then begin
  // appear from the bottom
  col:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
//  dy:=round(h*spline(stage/256,0,1.2,1,0,0.6));
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x,y+h-dy-cy,x+w,y+h-cy,buffer,col);
 end;
 if eff in [5,9] then begin
  // appear from the top
  col:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dy:=round(h*spline(stage/256,0,0,1,0,0.7));
  cy:=round(36-sqr(stage-160)/256);
  if eff>7 then cy:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x,y+cy,x+w,y+cy+dy,buffer,col);
 end;
 if eff in [6,10] then begin
  // appear from the left
  col:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x+cx,y,x+cx+dx,y+h,buffer,col);
 end;
 if eff in [7,11] then begin
  // appear from the right
  col:=Clamp(round(stage*1.2),0,255) shl 24+$808080;
  dx:=round(w*spline(stage/256,0,0,1,0,0.7));
  cx:=round(36-sqr(stage-160)/256);
  if eff>7 then cx:=round((36-sqr(stage-160)/256)/3);
  draw.Scaled(x-cx+w-dx,y,x+w-cx,y+h,buffer,col);
 end;
 if eff=22 then begin
  // Scaling effect (not quite linear)
  col:=stage;
  if col>255 then col:=255;
  col:=col shl 24+$808080;
  centerX:=x+w div 2; centerY:=y+h div 2;
  scaleX:=Spline(stage/255,0.6,0.3,1,0,0.5);
  scaleY:=scaleX;
  draw.Scaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
    centerX+scaleX*w/2,centerY+scaleY*h/2,buffer,col);
 end;
 if eff=23 then begin
  // Scaling effect (not quite linear)
  col:=stage;
  if col>255 then col:=255;
  col:=col shl 24+$808080;
  centerX:=x+w div 2; centerY:=y+h div 2;
  scaleX:=Spline(stage/255,0.6,0.3,1,0.05,0.5);
  scaleY:=Spline(stage/255,0.3,0.4,1,0.05,0.5);
  draw.Scaled(centerX-scaleX*w/2,centerY-scaleY*h/2,
    centerX+scaleX*w/2,centerY+scaleY*h/2,buffer,col);
 end;

 except
  on e:exception do Log.Force('WndEff error: '+ExceptionMsg(e));
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
  {$IFDEF GLES}
  '#version 300 es '#13#10+
  {$ELSE}
  '#version 330 '#13#10+
  {$ENDIF}
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
  {$IFDEF GLES}
  '#version 300 es '#13#10+
  'precision highp float; '#13#10+
  {$ELSE}
  '#version 330 '#13#10+
  {$ENDIF}
  // texN is bound to texture stage N by the engine
  'uniform sampler2D tex0; '#13#10+
  'uniform sampler2D tex1; '#13#10+
  'uniform float offsetX; '#13#10+
  'uniform float offsetY; '#13#10+
  'uniform float v1; '#13#10+
  'uniform float v2; '#13#10+
  'uniform vec4 colorAdd; '#13#10+
  'uniform vec4 colorMult; '#13#10+
  'in vec2 vTexcoord;'#13#10+
  'out vec4 fragColor;'#13#10+
  'void main(void)   '#13#10+
  '{   '#13#10+
  '   vec4 value = v1 * texture(tex0, vTexcoord);  '#13#10+
  '   value += v2 * texture(tex1, vTexcoord+vec2(offsetX,offsetY));  '#13#10+
  '   value += v2 * texture(tex1, vTexcoord+vec2(-offsetX,offsetY));  '#13#10+
  '   value += v2 * texture(tex1, vTexcoord+vec2(offsetX,-offsetY));  '#13#10+
  '   value += v2 * texture(tex1, vTexcoord+vec2(-offsetX,-offsetY));  '#13#10+
  '   fragColor = colorAdd + value*colorMult;  '#13#10+
  '}';

const
 BLUR_RADIUS = 1.5; // sample offset in pixels at 96 DPI and full strength 1.0

var
 blurShader:TShader;

destructor TBlurEffect.Destroy;
var
 i:integer;
begin
 inherited;
 FreeImage(buffer);
 for i:=low(levels) to high(levels) do
  if levels[i]<>nil then FreeImage(levels[i]);
end;

constructor TBlurEffect.Create(scene: TGameScene; strength: single;time:integer;colorAdd,colorMult:cardinal);
begin
 if scene.effect<>nil then begin
  Log.Msg('WARN! BlurEff skipped - scene already has effect: '+scene.name);
  exit;
 end;
 Log.Msg('BlurEff for '+scene.name);
 initialized:=false;

 power.Init(0);
 power.Animate(1.0,time,spline0);
 factor:=strength;
 dontPlay:=disableEffects;
 mainColorAdd:=colorAdd;
 mainColorMult:=colorMult;
 inherited Create(scene,1000000);
end;

procedure TBlurEffect.UpdateBuffers;
var
 wnd:TWindow;
 offset:single;
 i:integer;
begin
 wnd:=OwnerWindow(target);
 EnsureSceneBuffer(buffer,wnd,aiRenderTarget+aiClampUV,'BlurBuf');
 // The samples of the last level must stay about a texel apart, or their bilinear footprints
 // don't overlap and the blur turns into shifted copies. A larger radius (strength, DPI) needs
 // a smaller level; the level is chosen for the full strength so it doesn't switch while
 // the effect fades in. The texel of level N spans 2^N render pixels.
 offset:=BLUR_RADIUS*sqrt(factor)*wnd.canvasDPI/96*
   wnd.surface.renderSize.cx/Max(1,wnd.canvasWidth); // in render pixels
 numLevels:=1;
 while (numLevels<high(levels)) and ((2 shl numLevels)<=offset*sqrt(2.0)) do inc(numLevels);
 for i:=low(levels) to high(levels) do
  if i<=numLevels then
   EnsureSceneBuffer(levels[i],wnd,aiRenderTarget+aiClampUV,'BlurLevel'+Conv.ToStr(i),1 shl i)
  else
  if levels[i]<>nil then FreeImage(levels[i]);
end;

procedure TBlurEffect.Downsample;
var
 i:integer;
 src,dst:TTexture;
begin
 src:=buffer;
 for i:=1 to numLevels do begin
  // each texel of dst gets the average of 2x2 texels of src
  dst:=levels[i];
  gfx.BeginPaint(dst);
  try
   gfx.target.BlendMode(blMove);
   draw.TexturedRect(0,0,dst.width-1,dst.height-1,src,0,0,1,0,1,1,$FF808080);
  finally
   gfx.target.BlendMode(blAlpha);
   gfx.EndPaint;
  end;
  src:=dst;
 end;
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

 UpdateBuffers;
 initialized:=true;
 except
  on e:exception do begin
   dontPlay:=true;
   Log.Msg('Erorr in BlurEff init: '+ExceptionMsg(e));
  end;
 end;
end;

procedure TBlurEffect.DrawScene;
var
 u,v,phase:single;
 i:integer;
 wnd:TWindow;
 cb:array[0..3] of byte;
 cf:TQuat;
begin
 try
  if not initialized then Initialize;
  if dontPlay or ((power.value=0) and (power.finalValue=0)) then begin
   done:=true;
   target.Render;
   exit;
  end;
  // Render source scene
  UpdateBuffers;
  BeginSceneBuffer(buffer,OwnerWindow(target));
  try
   target.Render;
  finally
   gfx.EndPaint;
  end;

  Downsample;

  shader.UseCustom(blurShader);
  shader.UseTexture(buffer,0);
  shader.UseTexture(levels[numLevels],1);
  phase:=power.Value;
  v:=sqrt(phase*factor);

  // the radius grows with the DPI: canvas units carry it
  wnd:=OwnerWindow(target);
  u:=BLUR_RADIUS*v*wnd.canvasDPI/96;
  blurShader.SetUniform('offsetX',u/wnd.canvasWidth);
  blurShader.SetUniform('offsetY',u/wnd.canvasHeight);
  blurShader.SetUniform('v1',2/6);
  blurShader.SetUniform('v2',1/6);
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
   Log.Force('Error in BlurEff: '+ExceptionMsg(e));
   dontPlay:=true;
  end;
 end;
end;

procedure TBlurEffect.Remove(time: Integer);
begin
 if not done then power.Animate(0,time,spline2);
end;
{$ENDIF}

{ TSceneSwitcher }

procedure TBaseSceneSwitcher.HideWindowScene(name:string8);
 begin
  TShowWindowEffect.Create(game.GetScene(name) as TUIScene,250,sweHide,0);
 end;

procedure TBaseSceneSwitcher.ShowWindowScene(name:string8;modal:boolean=true);
 var
  mode:TShowMode;
 begin
  if modal then mode:=sweShowModal
   else mode:=sweShow;
  TShowWindowEffect.Create(game.GetScene(name) as TUIScene,250,mode,0);
 end;

procedure TBaseSceneSwitcher.SwitchToScene(name:string8);
 begin
  TTransitionEffect.Create(game.GetScene(name),250);
 end;


initialization
 TSceneSwitcher.defaultSwitcher:=TBaseSceneSwitcher.Create;
end.
