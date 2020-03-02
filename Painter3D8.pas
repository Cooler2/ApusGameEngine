// 3D drawing library (deprecated)
// Provides drawing of 3D-sprites, billboards, meshes etc.
//
// Copyright (C) 2003 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Painter3D8;
interface
 uses DirectXGraphics,Geom3D,camera,EngineCls;

type
 T3DPainter8=class(T3DPainter)
  constructor Create;
  procedure Invalidate; override;
  procedure SetCamera(c:TCamera); override;
  procedure SetViewport(x1,y1,x2,y2:integer); override;
  procedure DrawSprite(location:TMatrix43s;sprite:TTexture;
                       doubleSide:boolean=false); override;
  procedure GlobalTransp(alpha:single); virtual;
 protected
  camera:TCamera;
  tex1,tex2:IDirect3dTexture8; // текущие текстуры на 1 и 2 стадиях
  AlphaBlending,zWrite,zTest,lightning:boolean;
  worldMat:boolean; // true если установлена не единичная матрица local->world
  globalAlpha:cardinal;
  cullmode:integer;
 end;

implementation
 uses MyServis,d3d8,DxImages8;

type
 // Вершина в пространстве модели
 MdlPoint=record
  x,y,z:single;
  nx,ny,nz:single;
  color,specular:cardinal;
  u,v:single;
  u2,v2:single;
 end;

 // Вершина в пространстве камеры
 ScrPoint=record
  x,y,z,rhw:single;
  color,specular:cardinal;
  u,v:single;
  u2,v2:single;
 end;

 // textured lit vertex
 TVertexLT=record
  x,y,z:single;
  color,specular:cardinal;
  u,v:single;
 end;

const
 ShaderLT   = D3DFVF_XYZ+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1;
 ShaderTLT  = D3DFVF_XYZRHW+D3DFVF_DIFFUSE+D3DFVF_SPECULAR+D3DFVF_TEX1;

{ T3DPainter8 }

constructor T3DPainter8.Create;
begin
 valid:=false;
 ownTransform:=false;
 globalAlpha:=$FF000000;
 cullmode:=D3DCULL_CCW;
end;

procedure T3DPainter8.DrawSprite(location: TMatrix43s;
  sprite: TTexture; doubleSide: boolean);
var
 vrts:array[0..3] of TVertexLT;
begin
 if not valid then Invalidate;

 if OwnTransform then begin
  // Using manual transformations
  raise EWarning.Create('3DPainter: Not yet implemented');

 end else begin
  // Using D3D transformations
{  with vrts[0] do begin
   x:=0; y:=-1; z:=-1; color:=$FFFFFF+GlobalAlpha;
   u:=spr.texsizeu*(0.5+spr.Startx);
   v:=spr.texsizev*(0.5+spr.Starty+sprite.height);
  end;
  with vrts[1] do begin
   x:=0; y:=-1; z:=1; color:=$FFFFFF+GlobalAlpha;
   u:=spr.texsizeu*(0.5+spr.Startx);
   v:=spr.texsizev*(0.5+spr.Starty);
  end;
  with vrts[2] do begin
   x:=0; y:=1; z:=1; color:=$FFFFFF+GlobalAlpha;
   u:=spr.texsizeu*(0.5+spr.Startx+spr.width);
   v:=spr.texsizev*(0.5+spr.Starty);
  end;
  with vrts[3] do begin
   x:=0; y:=1; z:=-1; color:=$FFFFFF+globalAlpha;
   u:=spr.texsizeu*(0.5+spr.Startx+spr.width);
   v:=spr.texsizev*(0.5+spr.Starty+spr.height);
  end;
  MultPnts(location,PPoint3s(@vrts),4,sizeof(TVertexLT));
  if worldMat then begin
   device.SetTransform(D3DTS_WORLD,D3DIdentMat);
   worldMat:=false;
  end;
  device.SetVertexShader(ShaderLT);
  if tex1<>spr.tex then begin
   tex1:=spr.tex;
   device.SetTexture(0,tex1);
  end;
  if lightning then begin
   device.SetRenderState(D3DRS_LIGHTING,0);
   lightning:=false;
  end;
  if DoubleSide then
   device.SetRenderState(D3DRS_CULLMODE, D3DCULL_NONE)
  else
   if CullMode<>D3DCULL_CCW then
    device.SetRenderState(D3DRS_CULLMODE, D3DCULL_CCW);
  device.DrawPrimitiveUP(D3DPT_TRIANGLEFAN,2,@vrts,sizeof(TVertexLT));}
 end;
end;

procedure T3DPainter8.GlobalTransp(alpha: single);
begin
 globalAlpha:=round(255*alpha) shl 24;
end;

procedure T3DPainter8.Invalidate;
var
 bt:IDirect3DBaseTexture8;
begin
 worldMat:=true;
 device.GetTexture(0,bt);
 if (bt<>nil) and (bt.GetType=D3DRTYPE_TEXTURE) then
  tex1:=IDirect3DTexture8(bt) else tex1:=nil;
 device.GetTexture(1,bt);
 if (bt<>nil) and (bt.GetType=D3DRTYPE_TEXTURE) then
  tex2:=IDirect3DTexture8(bt) else tex2:=nil;
end;

procedure T3DPainter8.SetCamera(c: TCamera);
var
 m:TD3DMatrix;
 cmv:TMatrix43v;
 lu,lv,ln:double;
begin
 camera:=c;
 move(c.trans,cmv,sizeof(cmv));
 lu:=GetLength3(cmv[0]);
 lv:=GetLength3(cmv[1]);
 ln:=GetLength3(cmv[2]);
 Normalize3(cmv[0]);
 Normalize3(cmv[1]);
 Normalize3(cmv[2]);
 // Right direction
 m.m[0,0]:=cmv[0].x;
 m.m[1,0]:=cmv[0].y;
 m.m[2,0]:=cmv[0].z;
 // Up direction
 m.m[0,1]:=-cmv[1].x;
 m.m[1,1]:=-cmv[1].y;
 m.m[2,1]:=-cmv[1].z;
 // View direction
 m.m[0,2]:=cmv[2].x;
 m.m[1,2]:=cmv[2].y;
 m.m[2,2]:=cmv[2].z;
 // Position
 m.m[3,0]:=-DotProduct3(cmv[0],cmv[3]);
 m.m[3,1]:=DotProduct3(cmv[1],cmv[3]);
 m.m[3,2]:=-DotProduct3(cmv[2],cmv[3]);
 // Other
 m.m[0,3]:=0;  m.m[1,3]:=0;  m.m[2,3]:=0;  m.m[3,3]:=1;
 device.SetTransform(D3DTS_VIEW,m);

 fillchar(m,sizeof(m),0);
 m.m[0,0]:=ln/lu;
 m.m[1,1]:=ln/lv;
 m.m[2,2]:=c.FarDist/(c.fardist-c.neardist);
 m.m[2,3]:=1;
 m.m[3,2]:=-m.m[2,2]*c.neardist;
 device.SetTransform(D3DTS_PROJECTION,m);
end;

procedure T3DPainter8.SetViewport(x1, y1, x2, y2: integer);
var
 vp:TD3DViewport8;
begin
 vp.X:=x1; vp.Y:=x1;
 vp.Width:=x2-x1+1;
 vp.Height:=y2-y1+1;
 vp.MinZ:=0; vp.MaxZ:=1;
 device.SetViewport(vp);
end;

end.
