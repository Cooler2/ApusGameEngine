// Implementation of common drawing interface (system-independent)
//
// Copyright (C) 2011 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$R-}
unit Apus.Engine.Draw;
interface
 uses Types,Apus.Geom3D,Apus.Engine.API;

 type
 TDrawer=class(TInterfacedObject,IDrawer)
  zPlane:double; // default Z value for all primitives

  constructor Create;

  // Drawing methods
  procedure Line(x1,y1,x2,y2:single;color:cardinal);
  procedure Polyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false);
  procedure Polygon(points:PPoint2;cnt:integer;color:cardinal);
  procedure Rect(x1,y1,x2,y2:integer;color:cardinal);
  procedure RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2);
  procedure FillRect(x1,y1,x2,y2:integer;color:cardinal);
  procedure FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal);
  procedure ShadedRect(x1,y1,x2,y2,depth:integer;light,dark:cardinal);
  procedure TexturedRect(x1,y1,x2,y2:integer;texture:TTexture;u1,v1,u2,v2,u3,v3:single;color:cardinal);
  procedure FillGradrect(x1,y1,x2,y2:integer;color1,color2:cardinal;vertical:boolean);
  procedure Image(x_,y_:integer;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure Image(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080;pivotX:single=0;pivotY:single=0); overload;
  procedure ImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080);
  procedure Centered(x,y:integer;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure Centered(x,y,scale:single;tex:TTexture;color:cardinal=$FF808080); overload;
  procedure ImagePart(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect);
  procedure ImagePart90(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect;ang:integer);
  procedure Scaled(x1,y1,x2,y2:single;image:TTexture;color:cardinal=$FF808080);
  procedure RotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5);  // x,y - �����
  function Cover(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;
  function Inside(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;

  procedure DoubleTex(x_,y_:integer;image1,image2:TTexture;color:cardinal=$FF808080);
  procedure DoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
      image1,image2:TTexture;color:cardinal=$FF808080);
  //procedure MultiTex(x1,y1,x2,y2:integer;layers:PMultiTexLayer;color:cardinal=$FF808080);
  procedure TrgList(pnts:PVertex;trgcount:integer;tex:TTexture);
  procedure IndexedMesh(vertices:PVertex;indices:PWord;trgCount,vrtCount:integer;tex:TTexture);

  procedure Particles(x,y:integer;data:PParticle;count:integer;tex:TTexture;size:integer;zDist:single=0);
  procedure Band(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect);

  procedure DebugScreen1;
  procedure Reset; // notification about shader change
 protected
  // buffers
  partBuf:array of TVertex; // particles (vertices)
  partInd:array of word; // quad indices (0,1,2, 0,2,3) ... persistent buffer (can only grow)
  bandInd:array of word; // indices for bands drawing

  // Render modes:
  // 0 - undefined state (must be configured by outer code)
  // 1 - 1 stage, Modulate2X
  // 2 - no texturing stages
  // 3 - 2 stages, 1st - Modulate2X, 2-nd - undefined
  // 4 - 1 stage, result=diffuse*2
  renderMode:integer;

  procedure SetRenderMode(mode:byte;tex:TTexture=nil);
 end;

var
 MaxParticleCount:integer=5000;

 // Singleton object
 drawer:TDrawer;

implementation
uses SysUtils,Math,
  Apus.MyServis, Apus.Images, Apus.Geom2D, Apus.Colors,
  Apus.Engine.Graphics;

 const
  // Blending modes
  MODE_TEXTURED2X = 1;  // single textured: use TexMode[0] (default: color=texture*diffuse*2, alpha=texture*diffuse)
  MODE_COLORED    = 2;  // no texture: color=diffuse, alpha=diffuse
  MODE_MULTITEX   = 3;  // multitextured: use TexMode[n] for each enabled stage
  MODE_COLORED2X  = 4;  // textured: color=diffuse*2, alpha=texture*diffuse

{ TBasicPainter }

constructor TDrawer.Create;
begin
 ForceLogMessage('Creating '+self.ClassName);
 zPlane:=0;
 drawer:=self;
 setLength(partBuf,4*MaxParticleCount);
 setLength(partInd,6*MaxParticleCount);
end;

{
function TDrawer.GetClipping: TRect;
begin
 result:=clipRect;
end;

procedure TDrawer.NoClipping;
begin
 cliprect:=screenRect;
 scnt:=0;
end;

procedure TDrawer.OverrideClipping;
begin
 if scnt>=15 then exit;
 inc(scnt);
 saveclip[scnt]:=cliprect;
 ClipRect:=screenRect;
end;   }

procedure TDrawer.Centered(x, y, scale: single; tex: TTexture;
  color: cardinal);
begin
  RotScaled(x,y,scale,scale,0,tex,color);
end;

procedure TDrawer.Image(x, y, scale: single; tex: TTexture;
  color: cardinal; pivotX, pivotY: single);
begin
  if scale=1.0 then
   Image(round(x-tex.width*pivotX),round(y-tex.height*pivotY),tex,color)
  else
   RotScaled(x,y,scale,scale,0,tex,color,pivotX,pivotY);
end;


procedure TDrawer.Centered(x,y:integer;tex:TTexture;color:cardinal=$FF808080);
begin
 Image(x-tex.width div 2,y-tex.height div 2,tex,color);
end;

procedure TDrawer.Image(x_, y_: integer; tex: TTexture; color: cardinal);
var
 vrt:array[0..3] of TVertex;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not clippingAPI.Prepare(x_,y_,x_+tex.width-1,y_+tex.height-1) then exit;
 SetRenderMode(MODE_TEXTURED2X,tex);
 gfx.shader.UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;

 vrt[0].Init(x_-0.5,y_-0.5,      zPlane,tex.u1,tex.v1,color);
 vrt[1].Init(x_+dx-0.5,y_-0.5,   zPlane,tex.u2,tex.v1,color);
 vrt[2].Init(x_+dx-0.5,y_+dy-0.5,zPlane,tex.u2,tex.v2,color);
 vrt[3].Init(x_-0.5,y_+dy-0.5,   zPlane,tex.u1,tex.v2,color);
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.LayoutTex,sizeof(TVertex));
end;

procedure TDrawer.ImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080);
var
 vrt:array[0..3] of TVertex;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not clippingAPI.Prepare(x_,y_,x_+tex.width-1,y_+tex.height-1) then exit;
 SetRenderMode(MODE_TEXTURED2X,tex);
 gfx.shader.UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;

 vrt[0].Init(x_-0.5,y_-0.5,      zPlane, tex.u1,tex.v1,color);
 vrt[1].Init(x_+dx-0.5,y_-0.5,   zPlane, tex.u2,tex.v1,color);
 vrt[2].Init(x_+dx-0.5,y_+dy-0.5,zPlane, tex.u2,tex.v2,color);
 vrt[3].Init(x_-0.5,y_+dy-0.5,   zPlane, tex.u1,tex.v2,color);

 if flipHorizontal then begin
  Swap(vrt[0].u,vrt[1].u);
  Swap(vrt[2].u,vrt[3].u);
 end;
 if flipVertical then begin
  Swap(vrt[0].v,vrt[3].v);
  Swap(vrt[1].v,vrt[2].v);
 end;
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.LayoutTex,sizeof(TVertex));
end;

procedure TDrawer.ImagePart(x_, y_: integer; tex: TTexture;
  color: cardinal; r: TRect);
var
 vrt:array[0..3] of TVertex;
 w,h:integer;
begin
 w:=abs(r.width)-1;
 h:=abs(r.height)-1;
 if tex.caps and tfScaled>0 then begin
  w:=round(w+1)-1;
  h:=round(h+1)-1;
 end;
 if not clippingAPI.Prepare(x_,y_,x_+w-1,y_+h-1) then exit;
 SetRenderMode(MODE_TEXTURED2X,tex);
 gfx.shader.UseTexture(tex);
 vrt[0].Init(x_-0.5,y_-0.5,     zPlane, tex.u1+tex.stepU*2*r.left,tex.v1+tex.stepV*2*r.Top,color);
 vrt[1].Init(x_+w+0.5,y_-0.5,   zPlane, tex.u1+tex.stepU*r.Right*2,tex.v1+tex.stepV*r.top*2,color);
 vrt[2].Init(x_+w+0.5,y_+h+0.5, zPlane, tex.u1+tex.stepU*r.Right*2,tex.v1+tex.stepV*r.Bottom*2,color);
 vrt[3].Init(x_-0.5,y_+h+0.5,   zPlane, tex.u1+tex.stepU*r.left*2,tex.v1+tex.stepV*r.Bottom*2,color);
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.LayoutTex,sizeof(TVertex));
end;

procedure TDrawer.ImagePart90(x_, y_: integer; tex: TTexture;
  color: cardinal; r: TRect; ang: integer);
var
 vrt:array[0..3] of TVertex;
 i,w,h:integer;
begin
 if ang and 1=1 then begin
  h:=r.Right-r.Left-1;
  w:=r.Bottom-r.top-1;
 end else begin
  w:=r.Right-r.Left-1;
  h:=r.Bottom-r.top-1;
 end;
 if not clippingAPI.Prepare(x_,y_,x_+w-1,y_+h-1) then exit;
 SetRenderMode(MODE_TEXTURED2X,tex); // Textured, normal viewport
 gfx.shader.UseTexture(tex);

 with vrt[(0-ang) and 3] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane;
 end;
 with vrt[0] do begin
  u:=tex.u1+tex.stepU*2*r.left; v:=tex.v1+tex.stepV*2*r.Top;
 end;
 with vrt[(1-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_-0.5; z:=zPlane;
 end;
 with vrt[1] do begin
  u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.top*2;
 end;
 with vrt[(2-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_+h+0.5; z:=zPlane;
 end;
 with vrt[2] do begin
  u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 with vrt[(3-ang) and 3] do begin
  x:=x_-0.5; y:=y_+h+0.5; z:=zPlane;
 end;
 with vrt[3] do begin
  u:=tex.u1+tex.stepU*r.left*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 for i:=0 to 3 do vrt[i].color:=color;
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.LayoutTex,sizeof(TVertex));
end;

procedure TDrawer.Line(x1, y1, x2, y2: single; color: cardinal);
var
 vrt:array[0..1] of TVertex;
begin
 if not clippingAPI.Prepare(min2s(x1,x2),min2s(y1,y2),max2s(x1,x2),max2s(y1,y2)) then exit;
 SetRenderMode(MODE_COLORED); // Colored, normal viewport
 vrt[0].Init(x1,y1,zPlane,color);
 vrt[1].Init(x2,y2,zPlane,color);
 renderDevice.Draw(LINE_LIST,1,@vrt,TVertex.LayoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.Polyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false);
var
 vrt:array of TVertex;
 i:integer;
 pnt:PPoint2;
 minX,minY,maxX,maxY:integer;
begin
 minX:=10000; minY:=10000; maxX:=-10000; maxY:=-10000;
 SetLength(vrt,cnt+1);
 pnt:=points;
 for i:=0 to cnt-1 do begin
  vrt[i].Init(pnt.x,pnt.y,zPlane,color);
  if pnt.x<minX then minX:=trunc(pnt.x);
  if pnt.y<minY then minY:=trunc(pnt.y);
  if pnt.x>maxX then maxX:=trunc(pnt.x)+1;
  if pnt.y>maxY then maxY:=trunc(pnt.y)+1;
  inc(pnt);
 end;
 if not clippingAPI.Prepare(minX,minY,maxX,maxY) then exit;
 SetRenderMode(MODE_COLORED); // Colored, normal viewport
 if closed then vrt[cnt]:=vrt[0];
 renderDevice.Draw(LINE_STRIP,cnt-1+byte(closed),@vrt[0],TVertex.LayoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.DoubleTex(x_, y_: integer; image1, image2: TTexture;color: cardinal);
var
 w,h:integer;
 vrt:array[0..3] of TVertex2t;
 au1,au2,bu1,bu2,av1,av2,bv1,bv2:single;
begin
 ASSERT((image1<>nil) and (image2<>nil));
 w:=min2(image1.width,image2.width);
 h:=min2(image1.height,image2.height);
 if not clippingAPI.Prepare(x_,y_,x_+w,y_+h) then exit;
 SetRenderMode(MODE_MULTITEX);
 gfx.shader.UseTexture(image1,0);
 gfx.shader.UseTexture(image2,1);
 au1:=image1.u1; au2:=image1.u1+w*image1.stepU*2;
 av1:=image1.v1; av2:=image1.v1+h*image1.stepV*2;
 bu1:=image2.u1; bu2:=image2.u1+w*image2.stepU*2;
 bv1:=image2.v1; bv2:=image2.v1+h*image2.stepV*2;
 vrt[0].Init(
  x_-0.5,y_-0.5,zPlane,
  au1,av1, bu1,bv1,
  color);
 vrt[1].Init(
  x_+w-0.5,y_-0.5,zPlane,
  au2,av1, bu2,bv1,
  color);
 vrt[2].Init(
  x_+w-0.5,y_+h-0.5,zPlane,
  au2,av2, bu2,bv2,
  color);
 vrt[3].Init(
  x_-0.5,y_+h-0.5,zPlane,
  au1,av2, bu1,bv2,
  color);
 renderDevice.Draw(TRG_FAN,2,@vrt,sizeof(TVertex2t),2);
end;

procedure TDrawer.DoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
  image1,image2:TTexture;color:cardinal=$FF808080);
var
 w,h,w2,h2:single;
 vrt:array[0..3] of TVertex2t;
 c,s:single;
 au1,au2,bu1,bu2,av1,av2,bv1,bv2,u,v:single;
begin
 ASSERT((image1<>nil) and (image2<>nil));
 w:=(image1.width)/2*scale1X;
 h:=(image1.height)/2*scale1Y;
 w2:=(image2.width)/2*scale2X;
 h2:=(image2.height)/2*scale2Y;
 if w2<w then w:=w2;
 if h2<h then h:=h2;
 if not clippingAPI.Prepare(x_-h-w,y_-h-w,x_+h+w,y_+h+w) then exit;
 SetRenderMode(MODE_MULTITEX); // Textured, normal viewport
 x_:=x_-0.5; y_:=y_-0.5;

 // Тут надо что-то придумать умное, чтобы не было заблуренности
{ if abs(round(w)-w)>0.1 then begin
  x_:=x_+0.5*cos(angle);
  y_:=y_+0.5*sin(angle);
 end;
 if abs(round(h)-h)>0.1 then begin
  x_:=x_+0.5*sin(angle);
  y_:=y_+0.5*cos(angle);
 end;}

 gfx.shader.UseTexture(image1,0);
 gfx.shader.UseTexture(image2,1);

 au1:=image1.u1; au2:=image1.u2;
 av1:=image1.v1; av2:=image1.v2;
 bu1:=image2.u1; bu2:=image2.u2;
 bv1:=image2.v1; bv2:=image2.v2;

 scale1X:=w/(scale1X*(image1.width)/2);
 u:=0.5*(au2-au1)*(1-scale1X);
 au1:=image1.u1+image1.stepU*u;
 au2:=image1.u2-image1.stepU*u;
 scale1Y:=h/(scale1Y*(image1.height)/2);
 v:=0.5*(av2-av1)*(1-scale1Y);
 av1:=image1.v1+image1.stepV+v;
 av2:=image1.v2-image1.stepV-v;

 scale2X:=w/(scale2X*(image2.width)/2);
 u:=0.5*(bu2-bu1)*(1-scale2X);
 bu1:=image2.u1+image2.stepU+u;
 bu2:=image2.u2-image2.stepU-u;
 scale2Y:=h/(scale2Y*(image2.height)/2);
 v:=0.5*(bv2-bv1)*(1-scale2Y);
 bv1:=image2.v1+image2.stepV+v;
 bv2:=image2.v2-image2.stepV-v;

 c:=cos(angle); s:=sin(angle);
 h:=-h;
 vrt[0].Init(
  x_-w*c-h*s,y_+h*c-w*s,zPlane,
  au1,av1, bu1,bv1,
  color);
 vrt[1].Init(
  x_+w*c-h*s,y_+h*c+w*s,zPlane,
  au2,av1, bu2,bv1,
  color);
 vrt[2].Init(
  x_+w*c+h*s,y_-h*c+w*s,zPlane,
  au2,av2, bu2,bv2,
  color);
 vrt[3].Init(
  x_-w*c+h*s,y_-h*c-w*s,zPlane,
  au1,av2,bu1,bv2,
  color);

 renderDevice.Draw(TRG_FAN,2,@vrt,sizeof(TVertex2t),2);
end;

(* Obsolete, probably should not be used

procedure TDrawer.MultiTex(x1, y1, x2, y2: integer;  layers:PMultiTexLayer; color: cardinal);
var
 vrt:array[0..3] of TScrPoint8;
 lr:array[0..7] of TMultiTexLayer;
 i,lMax:integer;
// cnt:integer;
 // ïåðåâåñòè ìàòðèöó èç ïîëíîãî ìàñøòàáà ê ìàñøòàáó èçîáðàæåíèÿ â ìåòàòåêñòóðå
 procedure AdjustMatrix(const texture:TTexture;var matrix:TMatrix32s);
  var
   sx,sy,dx,dy:single;
   i:integer;
  begin
   with texture do begin
    sx:=u2-u1; sy:=v2-v1;
    dx:=u1; dy:=v1;
   end;
   for i:=0 to 2 do begin
    matrix[i,0]:=matrix[i,0]*sx;
    matrix[i,1]:=matrix[i,1]*sy;
   end;
   matrix[2,0]:=matrix[2,0]+dx;
   matrix[2,1]:=matrix[2,1]+dy;
  end;
begin
 if not SetStates(1,types.Rect(x1,y1,x2+1,y2+1)) then exit;

 // Copy layers data to modify later
 for i:=0 to High(lr) do begin
  lMax:=i;
  lr[i]:=layers^;
  layers:=layers.next;
  if layers=nil then break;
 end;

// fillchar(vrt,sizeof(vrt),0);
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=0; uv[i,1]:=0;
  end;
 end;
 with vrt[1] do begin
  x:=x2+0.5; y:=y1-0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=1; uv[i,1]:=0;
  end;
 end;
 with vrt[2] do begin
  x:=x2+0.5; y:=y2+0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=1; uv[i,1]:=1;
  end;
 end;
 with vrt[3] do begin
  x:=x1-0.5; y:=y2+0.5; z:=0; rhw:=1; diffuse:=color;
  for i:=0 to lMax do begin
   uv[i,0]:=0; uv[i,1]:=1;
  end;
 end;

 for i:=0 to lMax do
  with lr[i] do begin
   if texture=nil then break;
   UseTexture(texture,i);
   if texture.caps and tfTexture=0 then AdjustMatrix(texture,matrix);
   MultPnts(matrix,PPoint2s(@vrt[0].uv[i,0]),4,sizeof(TScrPoint8));
   MultPnts(matrix,PPoint2s(@vrt[0].uv[i,1]),4,sizeof(TScrPoint8));
   if i>0 then begin
    glClientActiveTexture(GL_TEXTURE0+i);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   end;
   glTexCoordPointer(2,GL_FLOAT,sizeof(TScrPoint8),@vrt[0].uv[i]);
  end;

 glClientActiveTexture(GL_TEXTURE0);

 glVertexPointer(3,GL_FLOAT,sizeof(TScrPoint3),@vrt);
 glColorPointer(4,GL_UNSIGNED_BYTE,sizeof(TScrPoint3),@vrt[0].color);
// glTexCoordPointer(2,GL_FLOAT,sizeof(TScrPoint3),@vrt[0].u);
 glDrawArrays(GL_TRIANGLE_FAN,0,4);

 for i:=1 to lMax do begin
  glClientActiveTexture(GL_TEXTURE0+i);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
 end;

 // Вообще-то это должен делать вызывающий код
 glActiveTexture(GL_TEXTURE1);
 glDisable(GL_TEXTURE_2D);
 glActiveTexture(GL_TEXTURE0);
 glClientActiveTexture(GL_TEXTURE0);
end; *)

procedure TDrawer.Polygon(points: PPoint2; cnt: integer; color: cardinal);
type
 ta=array[0..5] of TPoint2;
var
 vrt:array of TVertex;
 i,n:integer;
 pnts:^ta;
 minx,miny,maxx,maxy:single;
begin
 n:=cnt-2;
 if n<1 then exit;
 SetLength(vrt,n*3);
 Triangulate(points,cnt);
 pnts:=pointer(points);
 minx:=1000; miny:=1000; maxx:=0; maxy:=0;
 for i:=0 to cnt-1 do begin
  if pnts[i].x<minx then minx:=pnts[i].x;
  if pnts[i].x>maxx then maxx:=pnts[i].x;
  if pnts[i].y<miny then miny:=pnts[i].y;
  if pnts[i].y>maxy then maxy:=pnts[i].y;
 end;
 for i:=0 to n*3-1 do
  with pnts^[trgIndices[i]] do
   vrt[i].Init(x,y,zPlane,color);

 if not clippingAPI.Prepare(minX,minY,maxX,maxY) then exit;
 SetRenderMode(MODE_COLORED);
 renderDevice.Draw(TRG_LIST,n,@vrt[0],TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.RotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;
  color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5);
var
 vrt:array[0..3] of TVertex;
 u1,v1,u2,v2,w,h,c,s:single;
 wc1,hs1,hc1,ws1,wc2,hs2,hc2,ws2:single;
begin
 ASSERT(image<>nil);
 w:=(image.width)*scaleX;
 h:=(image.height)*scaleY;
 if not clippingAPI.Prepare(x0-h-w,y0-h-w,x0+h+w,y0+h+w) then exit;
 SetRenderMode(MODE_TEXTURED2X,image);

 x0:=x0-0.5; y0:=Y0-0.5;
 if image.width and 1=1 then begin
  x0:=x0+0.5*cos(angle);
  y0:=y0+0.5*sin(angle);
 end;
 if image.height and 1=1 then begin
  x0:=x0+0.5*sin(angle);
  y0:=y0+0.5*cos(angle);
 end;
 gfx.shader.UseTexture(image);
 u1:=image.u1; u2:=image.u2;
 v1:=image.v1; v2:=image.v2;
 c:=cos(angle); s:=sin(angle);

 h:=-h;
 wc2:=w*c; wc1:=wc2*pivotX; wc2:=wc2-wc1;
 ws2:=w*s; ws1:=ws2*pivotX; ws2:=ws2-ws1;
 hc2:=h*c; hc1:=hc2*pivotY; hc2:=hc2-hc1;
 hs2:=h*s; hs1:=hs2*pivotY; hs2:=hs2-hs1;

 vrt[0].Init(x0-wc1-hs1, y0+hc1-ws1, zPlane, u1, v1, color);
 vrt[1].Init(x0+wc2-hs1, y0+hc1+ws2, zPlane, u2, v1, color);
 vrt[2].Init(x0+wc2+hs2, y0-hc2+ws2, zPlane, u2, v2, color);
 vrt[3].Init(x0-wc1+hs2, y0-hc2-ws1, zPlane, u1, v2, color);
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutTex,sizeof(TVertex));
end;

procedure TDrawer.Scaled(x1, y1, x2, y2: single; image: TTexture;
  color: cardinal);
var
 vrt:array[0..3] of TVertex;
 v,u1,v1,u2,v2:single;
begin
 if not clippingAPI.Prepare(x1,y1,x2,y2) then exit;
 SetRenderMode(MODE_TEXTURED2X,image);
 x1:=x1-0.01; y1:=y1-0.01;
 x2:=x2-0.01; y2:=y2-0.01;
 gfx.shader.UseTexture(image);
 u1:=image.u1+image.StepU; u2:=image.u2-image.stepU;
 v1:=image.v1+image.StepV; v2:=image.v2-image.stepV;

 if x1>x2 then begin
  v:=x1; x1:=x2; x2:=v;
  v:=u1; u1:=u2; u2:=v;
 end;
 if y1>y2 then begin
  v:=y1; y1:=y2; y2:=v;
  v:=v1; v1:=v2; v2:=v;
 end;
 vrt[0].Init(x1,y1, zPlane, u1, v1, color);
 vrt[1].Init(x2,y1, zPlane, u2, v1, color);
 vrt[2].Init(x2,y2, zPlane, u2, v2, color);
 vrt[3].Init(x1,y2, zPlane, u1, v2, color);

 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutTex,sizeof(TVertex));
end;

procedure TDrawer.TrgList(pnts: PVertex; trgcount: integer;
  tex: TTexture);
begin
 clippingAPI.Prepare;
 if tex<>nil then begin
  SetRenderMode(MODE_TEXTURED2X,tex);
  gfx.shader.UseTexture(tex);
  renderDevice.Draw(TRG_LIST,trgcount,pnts,TVertex.layoutTex,sizeof(TVertex));
 end else begin
  SetRenderMode(MODE_COLORED);
  renderDevice.Draw(TRG_LIST,trgcount,pnts,TVertex.layoutNoTex,sizeof(TVertex));
 end;
end;

procedure TDrawer.IndexedMesh(vertices:PVertex;indices:PWord;trgCount,vrtCount:integer;tex:TTexture);
begin
 clippingAPI.Prepare;
 if tex<>nil then begin
  SetRenderMode(MODE_TEXTURED2X,tex);
  gfx.shader.UseTexture(tex);
{{  renderDevice.DrawIndexed(TRG_LIST,vertices,indices,sizeof(TVertex),TVertex.layoutTex,
    0,vrtCount,0,trgCount);}
 end else begin
  SetRenderMode(MODE_COLORED,tex);
{{  renderDevice.DrawIndexed(TRG_LIST,vertices,indices,sizeof(TVertex),TVertex.layoutNoTex,
    0,vrtCount,0,trgCount);}
 end;
end;

procedure TDrawer.Rect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..4] of TVertex;
begin
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_COLORED);
 vrt[0].Init(x1,y1,zPlane,color);
 vrt[1].Init(x2,y1,zPlane,color);
 vrt[2].Init(x2,y2,zPlane,color);
 vrt[3].Init(x1,y2,zPlane,color);
 vrt[4]:=vrt[0];
 renderDevice.Draw(LINE_STRIP,4,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.Reset;
begin
 renderMode:=0;
end;

procedure TDrawer.RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2);
var
 vrt:array[0..8] of TVertex;
begin
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_COLORED);
 vrt[0].Init(x1+r,y1,zPlane,color);
 vrt[1].Init(x2-r,y1,zPlane,color);
 vrt[2].Init(x2,y1+r,zPlane,color);
 vrt[3].Init(x2,y2-r,zPlane,color);
 vrt[4].Init(x2-r,y2,zPlane,color);
 vrt[5].Init(x1+r,y2,zPlane,color);
 vrt[6].Init(x1,y2-r,zPlane,color);
 vrt[7].Init(x1,y1+r,zPlane,color);
 vrt[8]:=vrt[0];
 renderDevice.Draw(LINE_STRIP,8,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.FillGradrect(x1, y1, x2, y2: integer; color1,
  color2: cardinal; vertical: boolean);
var
 vrt:array[0..3] of TVertex;
begin
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_COLORED);
 vrt[0].Init(x1-0.5,y1-0.5,zPlane,color1);
 vrt[1].Init(x2+0.5,y1-0.5,zPlane,color1);
 vrt[2].Init(x2+0.5,y2+0.5,zPlane,color2);
 vrt[3].Init(x1-0.5,y2+0.5,zPlane,color1);
 if vertical then vrt[3].color:=color2
  else vrt[1].color:=color2;

 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal);
var
 vrt:array[0..2] of TVertex;
 minX,minY,maxX,maxY:integer;
begin
 minX:=trunc(Min3d(x1,x2,x3));
 maxX:=trunc(Max3d(x1,x2,x3))+1;
 minY:=trunc(Min3d(y1,y2,y3));
 maxY:=trunc(Max3d(y1,y2,y3))+1;
 if not clippingAPI.Prepare(minX,minY,maxX,maxY) then exit;
 SetRenderMode(MODE_COLORED);
 vrt[0].Init(x1-0.5,y1-0.5,zPlane,color1);
 vrt[1].Init(x2-0.5,y2-0.5,zPlane,color2);
 vrt[2].Init(x3-0.5,y3-0.5,zPlane,color3);
 renderDevice.Draw(TRG_LIST,1,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.FillRect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..3] of TVertex;
 sx1,sy1,sx2,sy2:single;
begin
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_COLORED);
 sx1:=x1-0.5; sx2:=x2+0.5;
 sy1:=y1-0.5; sy2:=y2+0.5;
 vrt[0].Init(sx1,sy1,zPlane,color);
 vrt[1].Init(sx2,sy1,zPlane,color);
 vrt[2].Init(sx2,sy2,zPlane,color);
 vrt[3].Init(sx1,sy2,zPlane,color);
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.ShadedRect(x1, y1, x2, y2, depth: integer; light,
  dark: cardinal);
var
 vrt:array[0..23] of TVertex;
 i:integer;
 b1,b2:PByte;
begin
 ASSERT((depth>=1) and (depth<=3));
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_COLORED);
 inc(x1,depth-1); inc(y1,depth-1);
 dec(x2,depth-1); dec(y2,depth-1);
 b1:=@light; b2:=@dark;
 inc(b1,3); inc(b2,3);
 for i:=0 to depth-1 do begin
  vrt[i*8+0].Init(x1,y1+1,zPlane,light);
  vrt[i*8+1].Init(x1,y2,zPlane,light);
  vrt[i*8+2].Init(x1,y1,zPlane,light);
  vrt[i*8+3].Init(x2,y1,zPlane,light);

  vrt[i*8+4].Init(x2,y2,  zPlane,dark);
  vrt[i*8+5].Init(x2,y1,  zPlane,dark);
  vrt[i*8+6].Init(x2-1,y2,zPlane,dark);
  vrt[i*8+7].Init(x1,y2,  zPlane,dark);

  b1^:=b1^ div 2+32; b2^:=(b2^*3+255) shr 2;
  dec(x1); dec(y1); inc(x2); inc(y2);
 end;
 renderDevice.Draw(LINE_LIST,depth*4,@vrt,TVertex.layoutNoTex,sizeof(TVertex));
end;

procedure TDrawer.TexturedRect(x1, y1, x2, y2: integer; texture: TTexture; u1,
  v1, u2, v2, u3, v3: single; color: cardinal);
var
 vrt:array[0..3] of TVertex;
 sx,dx,sy,dy:single;
begin
 if not clippingAPI.Prepare(x1,y1,x2+1,y2+1) then exit;
 SetRenderMode(MODE_TEXTURED2X,texture);
 vrt[0].Init(x1-0.5, y1-0.5, zPlane,color);
 vrt[1].Init(x2+0.5, y1-0.5, zPlane,color);
 vrt[2].Init(x2+0.5, y2+0.5, zPlane,color);
 vrt[3].Init(x1-0.5, y2+0.5, zPlane,color);
 if texture.caps and tfTexture=0 then begin
  dx:=texture.u1; dy:=texture.v1;
  sx:=texture.u2-texture.u1; sy:=texture.v2-texture.v1;
  u1:=u1*sx+dx; v1:=v1*sy+dy;
  u2:=u2*sx+dx; v2:=v2*sy+dy;
  u3:=u3*sx+dx; v3:=v3*sy+dy;
 end;
 vrt[0].u:=u1;  vrt[0].v:=v1;
 vrt[1].u:=u2;  vrt[1].v:=v2;
 vrt[2].u:=u3;  vrt[2].v:=v3;
 vrt[3].u:=(u1+u3)-u2;
 vrt[3].v:=(v1+v3)-v2;
 gfx.shader.UseTexture(texture);
 renderDevice.Draw(TRG_FAN,2,@vrt,TVertex.layoutTex,sizeof(TVertex));
end;

procedure TDrawer.Particles(x, y: integer; data: PParticle;
  count: integer; tex: TTexture; size: integer; zDist: single);
type
 PartArr=array[0..10000] of TParticle;
var
 idx:array of integer;  // массив индексов партиклов (сортировка по z)
 i,j,n:integer;
 part:^PartArr;
 needSort:boolean;
 minZ,size2,uStart,vStart,uSize,vSize,rx,ry,qx,qy:single;
 sx,sy:single;
 startU,startV,sizeU,sizeV:integer;
 color:cardinal;
begin
 part:=pointer(data);
 if count>MaxParticleCount then count:=MaxParticleCount;
 SetLength(idx,count);
 needSort:=false;
 for i:=0 to count-1 do begin
  if part[i].z<>0 then needSort:=true;
  idx[i]:=i;
 end;
 if needSort then // сортировка (в будущем заменить на quicksort)
  for i:=0 to count-2 do begin
   n:=i; minZ:=part[idx[n]].z;
   for j:=i+1 to count-1 do
    if part[idx[j]].z<minZ then begin n:=j; minZ:=part[idx[n]].z; end;
   j:=idx[i];
   idx[i]:=idx[n];
   idx[n]:=j;
  end;
 // заполним вершинный буфер
 for i:=0 to count-1 do begin
  n:=idx[i];
  startU:=part[n].index and $FF;
  startV:=part[n].index shr 8 and $FF;
  sizeU:=part[n].index shr 16 and $F;
  sizeV:=part[n].index shr 20 and $F;
  if sizeU=0 then sizeU:=1;
  if sizeV=0 then sizeV:=1;
  if part[n].z<-ZDist+0.01 then part[n].z:=-ZDist+0.01; // модификация исходных данных, осторожно!
  // сперва рассчитаем экранные к-ты частицы
  sx:=x+ZDist*part[n].x/(part[n].z+ZDist);
  sy:=y+ZDist*part[n].y/(part[n].z+ZDist);
  uStart:=tex.u1+tex.stepU*(1+2*size*startU);
  vStart:=tex.v1+tex.stepV*(1+2*size*startV);
  uSize:=2*tex.stepU*(size*sizeU-1);
  vSize:=2*tex.stepV*(size*sizeV-1);
  if part[n].index and partFlip>0 then begin
   uStart:=uStart+uSize;
   usize:=-uSize;
  end;
  size2:=0.70711*0.5*size*part[n].scale*zDist/(part[n].z+ZDist);
  rx:=size2*sizeU*cos(-part[n].angle); ry:=-size2*sizeU*sin(-part[n].angle);
  qx:=size2*sizeV*cos(-part[n].angle+1.5708); qy:=-size2*sizeV*sin(-part[n].angle+1.5708);
  color:=part[n].color;
  j:=i*4;
  partBuf[j].  Init(sx-rx+qx, sy-ry+qy, zPlane, uStart,      vStart, color);
  partBuf[j+1].Init(sx+rx+qx, sy+ry+qy, zPlane, uStart+uSize,vStart, color);
  partBuf[j+2].Init(sx+rx-qx, sy+ry-qy, zPlane, uStart+uSize,vStart+vSize, color);
  partBuf[j+3].Init(sx-rx-qx, sy-ry-qy, zPlane, uStart,      vStart+vSize, color);
 end;

 clippingAPI.Prepare;
 SetRenderMode(MODE_TEXTURED2X,tex);
 gfx.shader.UseTexture(tex);
 renderDevice.DrawIndexed(TRG_LIST,@partBuf[0],@partInd[0],TVertex.layoutTex,sizeof(TVertex),
  0,count*4, 0,count*2);
end;

procedure TDrawer.DebugScreen1;
begin
/// TODO: move to txt and check
// txt.WriteW(MAGIC_TEXTCACHE,100,0,0,'');
end;

procedure TDrawer.Band(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect);
type
 PartArr=array[0..100] of TParticle;
 VertexArray=array[0..100] of TVertex;
var
 //vrt:^VertexArray;
 i,j,n,loopStart,next,primcount:integer;
 part:^PartArr;
 u1,u2,v1,rx,ry,qx,qy,l,vstep:single;
 sx,sy:single;
 noPrv:boolean;
 idx:integer;
 color:cardinal;
begin
 if tex=nil then i:=MODE_COLORED
  else i:=MODE_TEXTURED2X;
 SetRenderMode(i,tex);
 if tex<>nil then gfx.shader.UseTexture(tex);
 part:=pointer(data);
 if count>MaxParticleCount then count:=MaxParticleCount;
{ if part[count-1].index and (partEndpoint+partLoop)=0 then   // Модификация исходных данных недопустима!
  part[count-1].index:=part[count-1].index or partEndpoint; }

 if tex<>nil then begin
  u1:=tex.u1+tex.stepU*(2*r.Left+1);
  u2:=tex.u1+tex.stepU*(2*r.Right-1);
  v1:=tex.v1+tex.stepV*(2*r.top+1);
  vstep:=tex.stepV*2;
 end else begin
  u1:=0; u2:=0; v1:=0; vstep:=0;
 end;

 // заполним вершинный буфер
 noPrv:=true;
 loopstart:=0;
 primcount:=0;
 idx:=0;
 for i:=0 to count-1 do begin
   // сперва рассчитаем экранные к-ты частицы
   sx:=x+part[i].x;
   sy:=y+part[i].y;

   if noPrv or
     (part[i].index and partEndpoint>0) or
     ((i=count-1) and (part[i].index and partLoop=0)) then begin
     // начальная либо конечная вершина
     if noPrv then begin
       if part[i].index and partLoop>0 then begin // первая вершина цикла
        j:=i+1;
        while (j<count) and (part[j].index and partLoop=0) do inc(j);
        part[i].index:=part[i].index and (not partLoop);
       end else
        j:=i; // первая вершина линии
       qx:=part[i+1].x-part[j].x;
       qy:=part[i+1].y-part[j].y;
     end else begin
       // последняя вершина линии
       qx:=part[i].x-part[i-1].x;
       qy:=part[i].y-part[i-1].y;
     end;
   end else begin
     if part[i].index and partLoop>0 then begin
      // последняя вершина цикла
      qx:=part[loopStart].x-part[i-1].x;
      qy:=part[loopStart].y-part[i-1].y;
     end else begin
      // промежуточная вершина
      qx:=part[i+1].x-part[i-1].x;
      qy:=part[i+1].y-part[i-1].y;
     end;
   end;
   l:=sqrt(qx*qx+qy*qy);
   if (l>0.001) then begin
     rx:=part[i].scale*qy/l; ry:=-part[i].scale*qx/l;
   end else begin
     rx:=0; ry:=0;
   end;

   color:=part[i].color;
   // первая вершина
   partBuf[i*2].  Init(sx-rx,sy-ry, zPlane, u1,v1+vStep*(part[i].index and $FF),color);
   partBuf[i*2+1].Init(sx+rx,sy+ry, zPlane, u2,v1+vStep*(part[i].index and $FF),color);
   noPrv:=false;
   if (part[i].index and partEndpoint>0) or
      ((i=count-1) and (part[i].index and partLoop=0)) then begin
     noPrv:=true; loopstart:=i+1; continue;
   end;
   if part[i].index and partLoop>0 then begin
     next:=loopstart;
     loopstart:=i+1;
     noprv:=true;
   end else
     next:=i+1;
   // первый треугольник - (0,1,2)
   bandInd[idx]:=i*2; inc(idx);
   bandInd[idx]:=i*2+1; inc(idx);
   bandInd[idx]:=next*2; inc(idx);
   // второй треугольник - (2,1,3)
   bandInd[idx]:=next*2; inc(idx);
   bandInd[idx]:=i*2+1; inc(idx);
   bandInd[idx]:=next*2+1; inc(idx);
   inc(primcount,2);
 end;
 renderDevice.DrawIndexed(TRG_LIST,@partBuf[0],@bandInd[0],TVertex.layoutTex,
  sizeof(TVertex), 0,count*2, 0,primCount);
end;

function TDrawer.Cover(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;
var
 w,h:integer;
 u,v,r1,r2:single;
begin
 u:=0; v:=0;
 if (x2=x1) or (y2=y1) then exit;
 r1:=texture.width/texture.height;
 r2:=(x2-x1)/(y2-y1);
 if r1>r2 then begin // texture is wider
  u:=0.5*(1-r2/r1);
 end else begin // texture is taller
  v:=0.5*(1-r1/r2);
 end;
 TexturedRect(x1,y1,x2-1,y2-1,texture,u,v,1-u,v,1-u,1-v,color);
 result:=Max2d((x2-x1)/texture.width,(y2-y1)/texture.height);
end;

function TDrawer.Inside(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single;
begin
 result:=Min2d((x2-x1)/texture.width,(y2-y1)/texture.height);
 RotScaled(x1+x2/2,y1+y2/2,result,result,0,texture,color);
end;

procedure TDrawer.SetRenderMode(mode: byte; tex: TTexture);
begin
 if mode=renderMode then exit;
 with gfx.shader do begin
  case mode of
   MODE_TEXTURED2X:begin
    TexMode(0,tblModulate2X,tblModulate);
   end;
   MODE_COLORED:begin
    TexMode(0,tblKeep,tblKeep);
   end;
   MODE_MULTITEX:begin
    TexMode(0,tblModulate2X,tblModulate);
   end;
  end;
  if renderMode=MODE_MULTITEX then // disable the 2-nd texture if it was enabled
   TexMode(1,tblDisable,tblDisable);
  Apply; // activate shader and its settings
 end;
 renderMode:=mode;
end;



end.
