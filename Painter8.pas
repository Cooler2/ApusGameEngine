// Class for painting routines, using DirectXGraphics
// Assumes that all drawing methods are called inside BeginScene/EndScene
// and D3D8 unit has been properly initialized
//
// Copyright (C) 2003 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Painter8;
interface
 uses types,geom2d,Images,EngineAPI,DxImages8,BasicPainter,DirectXGraphics;

type

 TDXPainter8=class(TBasicPainter)
  constructor Create(textureMan:TTextureMan);
  destructor Destroy; override;

  procedure Restore; override;
  procedure Reset; // нужно вызывать после потери девайса, переключения режима и т.п.
  // Установить параметры отсечения по текущему viewport'у
  procedure RestoreClipping; override;

  procedure BeginPaint(target:TTexture); override;
  procedure EndPaint; override;

  // Установка RenderTarget'а (потомки класса могут иметь дополнительные методы,характерные для конкретного 3D API, например D3D)
  procedure ResetTarget; override; // Установить target в backbuffer
  procedure SetTargetToTexture(tex:TTexture); override; // Установить target в указанную текстуру

  procedure Clear(color:cardinal;zbuf:single=0;stencil:integer=-1); override;

  // Режим работы
  procedure SetMode(blend:TBlendingMode); override;
  procedure SetTexMode(stage:byte;colorMode,alphaMode:TTexBlendingMode;filter:TTexFilter;intFactor:single=0.0); override; // Режим текстурирования

  procedure SetMask(rgb:boolean;alpha:boolean); override;
  procedure ResetMask; override; // вернуть маску на ту, которая была до предыдущего SetMask

  procedure Set3DView(view:T3DMatrix); override;
  procedure SetDefaultView; override;
  procedure SetCullMode(mode:TCullMode); override;

  procedure DrawIndexedMesh(vertices:PScrPoint;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); override;

 protected
  StateTextured,StateColored:cardinal;
  curstate:byte; // Текущий режим (0 - не установлен, 1 - StateTExtured и т.д.)

  curblend:TBlendingMode;
  curFilter:TTexFilter;
  curTexture1:pointer;
  curmask:integer;
  oldmask:array[0..15] of integer;
  oldmaskpos:byte;

  actualClip:TRect; // реальные границы отсечения на данный момент (в рабочем пространстве)
  partbuf,txtbuf:IDirect3DVertexBuffer8;
  partind,bandInd:IDirect3DIndexBuffer8;

  function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; override; // возвращает false если примитив полностью отсекается
  procedure UseTexture(tex:TTexture; stage:integer=0); override;
  procedure Initialize; virtual; // инициализация (после потери девайса)
  procedure DrawPrimitives(primType,primCount:integer;vertices:pointer;stride:integer); override;
  procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); override;
  procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
    vertexBuf:TPainterBuffer;stride:integer); override;
  procedure DrawIndexedPrimitives(primType:integer;vertexBuf,indBuf:TPainterBuffer;
    stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); override;
  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer; override;
  procedure UnlockBuffer(buf:TPainterBuffer); override;
 end;

implementation
 uses windows,MyServis,d3d8,DirectText,SysUtils,
   eventman,UDict,colors;

const
 TexVertFmt3=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX3+D3DFVF_TEXTUREFORMAT2;
 TexVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1+D3DFVF_TEXTUREFORMAT2;
 ColVertFmt=D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR;

constructor TDXPainter8.Create;
var
 pf:ImagePixelFormat;
begin
 inherited;
 Assert(device<>nil);
 curmask:=$F;
 partbuf:=nil; partind:=nil; bandInd:=nil;
 Initialize;
 efftex:=nil;
// txtTex:=nil;
 if d3d8.supportARGB then begin
  efftex:=texman.AllocImage(256,32,ipfARGB,aiTexture,'effectTex') as TDxtexture;
//  txttex:=texman.AllocImage(1024,32,0,0,ipfARGB,aiTexture,'txtTex') as TDxtexture;
 end;
 if d3d8.supportA8 then
  pf:=ipfA8 else
 if d3d8.support4444 then
  pf:=ipf4444
 else
  pf:=ipfARGB;
 textCache:=texman.AllocImage(textCacheWidth,textCacheHeight,pf,aiTexture,'textCache');
end;

destructor TDXPainter8.Destroy;
begin
 if device=nil then exit;
 // Здесь надо бы освободить шрифты
 device.DeleteStateBlock(StateTextured);
 device.DeleteStateBlock(StateColored);
 LogMessage('Painter deleted');
 Inherited;
end;

procedure TDXPainter8.SetMode;
begin
 if blend=curblend then exit;
 case blend of
  blNone:begin
   if curblend<>blNone then
     device.SetRenderState(D3DRS_ALPHABLENDENABLE,0);
  end;
  blAlpha:begin
//   if curblend=blNone then
   device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
   device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD);
   device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_SRCALPHA);
   device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_INVSRCALPHA);
  end;
  blAdd:begin
   if curblend=blNone then
     device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
   device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD);
   device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_SRCALPHA);
   device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_ONE);
  end;
  blSub:begin
   if curblend=blNone then
     device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
   device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_SUBTRACT);
   device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_SRCALPHA);
   device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_ONE);
  end;
  blMove:begin
   if curblend=blNone then
     device.SetRenderState(D3DRS_ALPHABLENDENABLE,1);
   device.SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD);
   device.SetRenderState(D3DRS_SRCBLEND,D3DBLEND_ONE);
   device.SetRenderState(D3DRS_DESTBLEND,D3DBLEND_ZERO);
  end
 else
  raise EWarning.Create('Blending mode not supported');
 end;
 curblend:=blend;
end;

procedure TDXPainter8.SetTexMode;
var
 v:integer;
begin
 case filter of
  fltNearest:begin
   device.SetTextureStageState(stage,D3DTSS_MINFILTER,D3DTEXF_POINT);
   device.SetTextureStageState(stage,D3DTSS_MAGFILTER,D3DTEXF_POINT);
   device.SetTextureStageState(stage,D3DTSS_MIPFILTER,D3DTEXF_POINT);
  end;
  fltBilinear:begin
   device.SetTextureStageState(stage,D3DTSS_MINFILTER,D3DTEXF_LINEAR);
   device.SetTextureStageState(stage,D3DTSS_MAGFILTER,D3DTEXF_LINEAR);
   device.SetTextureStageState(stage,D3DTSS_MIPFILTER,D3DTEXF_POINT);
  end;
  fltTrilinear:begin
   device.SetTextureStageState(stage,D3DTSS_MINFILTER,D3DTEXF_LINEAR);
   device.SetTextureStageState(stage,D3DTSS_MAGFILTER,D3DTEXF_LINEAR);
   device.SetTextureStageState(stage,D3DTSS_MIPFILTER,D3DTEXF_LINEAR);
  end;
  fltAnisotropic:begin
   device.SetTextureStageState(stage,D3DTSS_MINFILTER,D3DTEXF_ANISOTROPIC);
   device.SetTextureStageState(stage,D3DTSS_MAGFILTER,D3DTEXF_LINEAR);
   device.SetTextureStageState(stage,D3DTSS_MIPFILTER,D3DTEXF_LINEAR);
  end;
 end;
 curfilter:=filter;

 case colorMode of
  tblDisable:
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_DISABLE);
  tblModulate:begin
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_MODULATE);
   device.SetTextureStageState(stage,D3DTSS_COLORARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_COLORARG2,D3DTA_TEXTURE);
  end;
  tblModulate2X:begin
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_MODULATE2X);
   device.SetTextureStageState(stage,D3DTSS_COLORARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_COLORARG2,D3DTA_TEXTURE);
  end;
  tblKeep:begin
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_SELECTARG1);
   device.SetTextureStageState(stage,D3DTSS_COLORARG1,D3DTA_CURRENT);
  end;
  tblReplace:begin
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_SELECTARG1);
   device.SetTextureStageState(stage,D3DTSS_COLORARG1,D3DTA_TEXTURE);
  end;
  tblAdd:begin
   device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_ADD);
   device.SetTextureStageState(stage,D3DTSS_COLORARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_COLORARG2,D3DTA_TEXTURE);
  end;
  tblInterpolate:begin
{   case texIntMode[stage] of
    tintFactor:begin}
     device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_BLENDFACTORALPHA);
     v:=round(intFactor*255);
     device.SetRenderState(D3DRS_TEXTUREFACTOR,MyColor(v,v,v,v));
//    end;
    // these modes are no longer supported for OpenGL compatibility
{    tintDiffuse:device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_BLENDDIFFUSEALPHA);
    tintTexture:device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_BLENDTEXTUREALPHA);
    tintCurrent:device.SetTextureStageState(stage,D3DTSS_COLOROP,D3DTOP_BLENDCURRENTALPHA);
   end;}
  end;
 end;

 case alphaMode of
  tblModulate:begin
   device.SetTextureStageState(stage,D3DTSS_ALPHAOP,D3DTOP_MODULATE);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG2,D3DTA_TEXTURE);
  end;
  tblModulate2X:begin
   device.SetTextureStageState(stage,D3DTSS_ALPHAOP,D3DTOP_MODULATE2X);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG2,D3DTA_TEXTURE);
  end;
  tblKeep:begin
   device.SetTextureStageState(stage,D3DTSS_ALPHAOP,D3DTOP_SELECTARG1);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG1,D3DTA_CURRENT);
  end;
  tblReplace:begin
   device.SetTextureStageState(stage,D3DTSS_ALPHAOP,D3DTOP_SELECTARG1);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG1,D3DTA_TEXTURE);
  end;
  tblAdd:begin
   device.SetTextureStageState(stage,D3DTSS_ALPHAOP,D3DTOP_ADD);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG1,D3DTA_CURRENT);
   device.SetTextureStageState(stage,D3DTSS_ALPHAARG2,D3DTA_TEXTURE);
  end;
 end;
end;

procedure TDXPainter8.Set3DView(view:T3DMatrix);
var
 m:TD3DMatrix;
begin
{ if lightning then begin
  device.SetRenderState(D3DRS_LIGHTING,1);
  mode3D:=2;
 end else begin
  device.SetRenderState(D3DRS_LIGHTING,0);
  mode3D:=1;
 end;}
 // View (camera) matrix
 m._11:=view[0,0];
 m._12:=view[1,0];
 m._13:=view[2,0];
 m._14:=0;
 m._21:=view[0,1];
 m._22:=view[1,1];
 m._23:=view[2,1];
 m._24:=0;
 m._31:=view[0,2];
 m._32:=view[1,2];
 m._33:=view[2,2];
 m._34:=0;
 m._41:=-view[0,0]*view[3,0]-view[0,1]*view[3,1]-view[0,2]*view[3,2];
 m._42:=-view[1,0]*view[3,0]-view[1,1]*view[3,1]-view[1,2]*view[3,2];
 m._43:=-view[2,0]*view[3,0]-view[2,1]*view[3,1]-view[2,2]*view[3,2];
 m._44:=1;
 device.SetTransform(D3DTS_VIEW,m);
{ m._11:=view[0,0];
 m._12:=view[0,1];
 m._13:=view[0,2];
 m._14:=0;
 m._21:=view[1,0];
 m._22:=view[1,1];
 m._23:=view[1,2];
 m._24:=0;
 m._31:=view[2,0];
 m._32:=view[2,1];
 m._33:=view[2,2];
 m._34:=0;
 m._41:=view[3,0];
 m._42:=view[3,1];
 m._43:=view[3,2];
 m._44:=1;
 device.SetTransform(D3DTS_PROJECTION,m);}
end;

procedure TDXPainter8.SetCullMode(mode: TCullMode);
begin
 case mode of
  cullCW:device.SetRenderState(D3DRS_CULLMODE,D3DCULL_CW);
  cullCCW:device.SetRenderState(D3DRS_CULLMODE,D3DCULL_CCW);
  cullNone:device.SetRenderState(D3DRS_CULLMODE,D3DCULL_NONE);
 end;
end;

procedure TDXPainter8.SetDefaultView;
var
 mat:TD3DMatrix;
begin
 fillchar(mat,sizeof(mat),0);
 mat._11:=1; mat._22:=1; mat._33:=1; mat._44:=1;
 device.SetTransform(D3DTS_VIEW,mat);
 device.SetTransform(D3DTS_PROJECTION,mat);
 device.SetRenderState(D3DRS_LIGHTING,0);
end;

procedure TDXPainter8.SetMask(rgb:boolean;alpha:boolean);
var
 mask:integer;
begin
 ASSERT(oldmaskpos<15);
 mask:=0;
 oldmask[oldmaskpos]:=curmask;
 oldmaskpos:=(oldmaskpos+1) and 15;
 if rgb then mask:=mask+D3DCOLORWRITEENABLE_RED+D3DCOLORWRITEENABLE_GREEN+D3DCOLORWRITEENABLE_BLUE;
 if alpha then mask:=mask+D3DCOLORWRITEENABLE_ALPHA;
 if curmask<>mask then begin
  device.SetRenderState(D3DRS_COLORWRITEENABLE,mask);
  curmask:=mask;
 end;
end;

procedure TDXPainter8.ResetMask;
 var
  mask:integer;
 begin
  ASSERT(oldmaskpos>0);
  oldmaskpos:=(oldmaskpos-1) and 15;
  mask:=oldmask[oldmaskpos];
  if curmask<>mask then begin
   device.SetRenderState(D3DRS_COLORWRITEENABLE,mask);
   curmask:=mask;
  end;
 end;

procedure TDXPainter8.Restore;
var
 bl:TBlendingMode;
begin
 bl:=curblend;
 inc(curblend);
 SetMode(bl);
 SetTexMode(0,tblNone,tblNone,curfilter);
 device.SetTextureStageState(1,D3DTSS_COLOROP,D3DTOP_DISABLE);
 curmask:=-1;
 curTexture1:=nil;
 curstate:=0;
 RestoreClipping;
end;

procedure TDXPainter8.ResetTarget;
var
 backbuf,zbuf:IDirect3DSurface8;
begin
 FlushTextCache;
 DxCall(device.GetBackBuffer(0,D3DBACKBUFFER_TYPE_MONO,backbuf));
 if zbuffer then device.GetDepthStencilSurface(zbuf)
  else zbuf:=nil;
 DxCall(device.SetRenderTarget(backbuf,zbuf));
 RestoreClipping;
 clipRect:=screenrect;
 curtarget:=nil;
end;

procedure TDXPainter8.SetTargetToTexture(tex: TTexture);
begin
 ASSERT(((tex as TDxTexture).caps and tfRenderTarget)>0);
 FlushTextCache;
 softScaleOn:=tex.caps and tfScaled>0;
 texman.MakeOnline(tex);
 (tex as TDxTexture).SetAsRenderTarget;
 RestoreClipping;
 clipRect:=actualClip;
{ ScreenRect.Left:=0;
 ScreenRect.Top:=0;
 ScreenRect.right:=tex.width;
 ScreenRect.bottom:=tex.height;}
 curtarget:=tex;
end;


procedure TDXPainter8.DrawPrimitives(primType, primCount: integer;
  vertices: pointer; stride: integer);
begin
 case primType of
  LINE_LIST:DXCall(device.DrawPrimitiveUP(D3DPT_LINELIST,primCount,vertices,stride));
  LINE_STRIP:DXCall(device.DrawPrimitiveUP(D3DPT_LINESTRIP,primCount,vertices,stride));
  TRG_LIST:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLELIST,primCount,vertices,stride));
  TRG_FAN:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLEFAN,primCount,vertices,stride));
  TRG_STRIP:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,primCount,vertices,stride));
 end;
end;

procedure TDXPainter8.DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer);
begin
 case primType of
  LINE_LIST:DXCall(device.DrawPrimitiveUP(D3DPT_LINELIST,primCount,vertices,stride));
  LINE_STRIP:DXCall(device.DrawPrimitiveUP(D3DPT_LINESTRIP,primCount,vertices,stride));
  TRG_LIST:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLELIST,primCount,vertices,stride));
  TRG_FAN:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLEFAN,primCount,vertices,stride));
  TRG_STRIP:DXCall(device.DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,primCount,vertices,stride));
 end;
end;

procedure TDXPainter8.DrawPrimitivesFromBuf(primType, primCount, vrtStart: integer;
  vertexBuf:TPainterBuffer; stride:integer);
begin
 case vertexBuf of
  VertBuf:DxCall(device.SetStreamSource(0,partbuf,stride));
  TextVertBuf:DxCall(device.SetStreamSource(0,txtbuf,stride));
 end;
 case primType of
  LINE_LIST:DxCall(device.DrawPrimitive(D3DPT_LINELIST,vrtStart,primCount));
  TRG_LIST:DxCall(device.DrawPrimitive(D3DPT_TRIANGLELIST,vrtStart,primCount));
 end;
end;

procedure TDXPainter8.DrawIndexedMesh;
begin
{ device.SetVertexShader(VertexLitFmt2);
 device.SetStreamSource(0,vertices,sizeof(VertexLit2));
 device.SetIndices(indices,0);
 UseTexture(tex);
 device.DrawIndexedPrimitive(D3DPT_TRIANGLELIST,0,vrtCount,0,trgCount);}
end;

procedure TDXPainter8.DrawIndexedPrimitives(primType: integer; vertexBuf,
  indBuf: TPainterBuffer; stride:integer; vrtStart, vrtCount, indStart, primCount: integer);
begin
 case vertexBuf of
  VertBuf:DxCall(device.SetStreamSource(0,partbuf,stride));
  TextVertBuf:DxCall(device.SetStreamSource(0,txtbuf,stride));
 end;
 case indBuf of
  partIndBuf:DxCall(device.SetIndices(partind,0));
  bandIndBuf:DxCall(device.SetIndices(bandind,0));
 end;
 case primType of
  TRG_LIST:DxCall(device.DrawIndexedPrimitive(D3DPT_TRIANGLELIST,vrtStart,vrtCount,indStart,primCount));
 end;
end;

function TDXPainter8.LockBuffer(buf:TPainterBuffer; offset, size: cardinal): pointer;
begin
 case buf of
  VertBuf:DxCall(partbuf.Lock(offset*sizeof(TScrPoint),size,PByte(result),0),'Lock vertbuf');
  TextVertBuf:DxCall(txtbuf.Lock(offset*sizeof(TScrPoint),size,PByte(result),0),'Lock textbuf');
  bandIndBuf:DxCall(bandInd.Lock(offset*2,size,PByte(result),D3DLOCK_NOSYSLOCK));
 end;
end;

procedure TDxPainter8.UnlockBuffer(buf:TPainterBuffer);
begin
 case buf of
  VertBuf:DxCall(partbuf.Unlock);
  TextVertBuf:DxCall(txtbuf.Unlock);
  bandIndBuf:DxCall(bandInd.Unlock);
 end;
end;

function TDXPainter8.SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean;
var
 vp:TD3DViewport8;
 f1,f2:byte;
 r:TRect;
begin
 ASSERT(device<>nil);
 f1:=geom2d.IntersectRects(primRect,clipRect,r);
 if f1=0 then begin
  result:=false;
  exit;
 end else result:=true;

 if tex<>nil then begin
  if (state=1) and (tex.PixelFormat in [ipfA8,ipfA4]) then state:=4; // override color blending mode for alpha only textures
 end;
 if curstate<>state then begin
  ASSERT(state in [0..4]);
  case state of
   1:begin
      if curstate=4 then begin // simplified switch from 4 to 1
       device.SetTextureStageState(0,D3DTSS_COLOROP,D3DTOP_MODULATE2X);
       device.SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_TEXTURE);
      end else begin
       DxCall(device.ApplyStateBlock(StateTextured));
       DxCall(device.SetVertexShader(texVertFmt));
      end;
     end;
   2:begin
      DxCall(device.ApplyStateBlock(StateColored));
      DxCall(device.SetVertexShader(ColVertFmt));
      curtexture1:=nil;
     end;
   3:begin
      DxCall(device.ApplyStateBlock(StateTextured));
      DxCall(device.SetVertexShader(texVertFmt3));
     end;
   4:begin // 4 is similar to 1, but color=diffuse instead of diffuse*texture*2
      if curstate<>1 then begin
       DxCall(device.ApplyStateBlock(StateTextured));
       DxCall(device.SetVertexShader(texVertFmt));
      end;
      device.SetTextureStageState(0,D3DTSS_COLOROP,D3DTOP_SELECTARG1);
      device.SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_DIFFUSE);
     end;
  end;
  curstate:=state;
 end;
 if not EqualRect(clipRect,actualClip) then begin
  f2:=geom2d.IntersectRects(primRect,actualClip,r);
  if (f1<>f2) or (f1>1) then begin
   vp.X:=clipRect.Left;
   vp.Y:=clipRect.top;
   vp.Width:=clipRect.Right-clipRect.left;
   vp.Height:=clipRect.Bottom-clipRect.Top;
   vp.MinZ:=0;
   vp.maxz:=1;
   try
    DxCall(device.SetViewport(vp));
   except
    on e:Exception do LogMessage('VP failed: '+inttostr(vp.X)+','+inttostr(vp.Y)+','+
      inttostr(vp.Width)+','+inttostr(vp.Height));
   end;
   actualClip:=ClipRect;
  end;
 end;
end;

procedure TDXPainter8.UseTexture(tex: TTexture; stage:integer=0);
var
 tx:TDxManagedTexture;
begin
 if tex<>nil then begin
  tx:=tex as TDxManagedTexture;
  if stage=0 then begin
   if not (tx.online and (curTexture1=pointer(tx.texture))) then begin
    texman.MakeOnline(tex);
    DxCall(device.SetTexture(0,tx.texture));
    curtexture1:=pointer(tx.texture);
   end;
  end else begin  // stage>0
   texman.MakeOnline(tx);
   DxCall(device.SetTexture(stage,tx.texture));
  end;
 end else
  DxCall(device.SetTexture(stage,nil))
end;

procedure TDXPainter8.RestoreClipping;
var
 vp:TD3DViewport8;
begin
 device.GetViewport(vp);
 actualClip.Left:=integer(vp.X);
 actualClip.Top:=integer(vp.Y);
 actualClip.Right:=actualClip.Left+integer(vp.Width);
 actualClip.Bottom:=actualClip.Top+integer(vp.Height);
end;

procedure TDXPainter8.Initialize;
var
 i:integer;
 pw:^word;
begin
 // Record useful render states
 // 1. Текстурирование одной текстурой, масштабированной цветом (2x)
 DxCall(device.BeginStateBlock);
 device.SetRenderState(D3DRS_LIGHTING,0);
 device.SetTextureStageState(0,D3DTSS_COLOROP,D3DTOP_MODULATE2X);
 device.SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_DIFFUSE);
 device.SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_TEXTURE);
 device.SetTextureStageState(0,D3DTSS_ALPHAOP,D3DTOP_MODULATE);
 device.SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_DIFFUSE);
 device.SetTextureStageState(0,D3DTSS_ALPHAARG2,D3DTA_TEXTURE);
 device.SetTexture(1,nil);
 DxCall(device.EndStateBlock(StateTextured));

 // 2. Только интерполированный цвет, без текстуры
 DxCall(device.BeginStateBlock);
 device.SetRenderState(D3DRS_LIGHTING,0);
 device.SetTextureStageState(0,D3DTSS_COLOROP,D3DTOP_DISABLE);
 device.SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_DIFFUSE);
 device.SetTextureStageState(0,D3DTSS_ALPHAOP,D3DTOP_SELECTARG1);
 device.SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_DIFFUSE);
 device.SetTexture(0,nil);
 DxCall(device.EndStateBlock(StateColored));

 curblend:=blNone;
 SetMode(blAlpha);
 SetTexMode(0,tblModulate2X,tblModulate,fltBilinear);
 DxCall(device.SetRenderState(D3DRS_COLORWRITEENABLE,15));

 if txtbuf=nil then
  DxCall(device.CreateVertexBuffer(4*MaxGlyphBufferCount*sizeof(TScrPoint),
    D3DUSAGE_WRITEONLY,TexVertFmt,D3DPOOL_MANAGED,txtbuf),'Create VB txtbuf');
 if partbuf=nil then
  DxCall(device.CreateVertexBuffer(4*MaxParticleCount*sizeof(TScrPoint),
    D3DUSAGE_WRITEONLY,TexVertFmt,D3DPOOL_MANAGED,partbuf),'Create VB partbuf');
{ if Lpartbuf=nil then
  DxCall(device.CreateVertexBuffer(2*MaxParticleCount*sizeof(scrPointNoTex),
    D3DUSAGE_WRITEONLY,ColVertFmt,D3DPOOL_MANAGED,Lpartbuf),'Create VB line partbuf');}
 if partind=nil then begin
  DxCall(device.CreateIndexBuffer(6*MaxParticleCount*2,D3DUSAGE_WRITEONLY,
    D3DFMT_INDEX16,D3DPOOL_MANAGED,partind),'Create IB partind');
  partind.Lock(0,6*MaxParticleCount*2,PByte(pw),D3DLOCK_NOSYSLOCK);
  for i:=0 to MaxParticleCount-1 do begin
   pw^:=i*4; inc(pw);
   pw^:=i*4+1; inc(pw);
   pw^:=i*4+2; inc(pw);
   pw^:=i*4; inc(pw);
   pw^:=i*4+2; inc(pw);
   pw^:=i*4+3; inc(pw);
  end;
  partind.Unlock;
 end;
 if bandind=nil then begin
  DxCall(device.CreateIndexBuffer(4*MaxParticleCount*2,D3DUSAGE_WRITEONLY,
    D3DFMT_INDEX16,D3DPOOL_MANAGED,bandind),'Create IB bandind');
 end;

 RestoreClipping;
 ScreenRect:=ActualClip;
 ClipRect:=ActualCLip;

 curState:=0;
 curTexture1:=nil;
 curTarget:=nil;
 stackcnt:=0;
 vertBufUsage:=0;
 textBufUsage:=0;
 textCaching:=false;
 supportARGB:=d3d8.supportARGB;
end;

procedure TDXPainter8.Reset;
begin
  Initialize;
  LogMessage('Debug\painter\reset');
end;

procedure TDXPainter8.Clear(color: cardinal; zbuf: single=0;
  stencil: integer=-1);
begin
 ClearViewPort(color,zbuf,stencil);
end;

procedure TDXPainter8.BeginPaint(target: TTexture);
begin
 ASSERT(device<>nil);
 if canpaint>0 then
  device.EndScene;
 inherited BeginPaint(target);
 DxCall(device.BeginScene);
end;

procedure TDXPainter8.EndPaint;
begin
 DxCall(device.EndScene);
 inherited EndPaint;
 if canPaint>0 then
  device.BeginScene;
end;


end.
