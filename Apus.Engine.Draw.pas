// Implementation of common drawing interface (system-independent)
//
// Copyright (C) 2011 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
{$R-}
unit Apus.Engine.Draw;
interface
 uses Types,Apus.Geom3D,Apus.Engine.API;
 const
  // States
  STATE_TEXTURED2X = 1;  // single textured: use TexMode[0] (default: color=texture*diffuse*2, alpha=texture*diffuse)
  STATE_COLORED    = 2;  // no texture: color=diffuse, alpha=diffuse
  STATE_MULTITEX   = 3;  // multitextured: use TexMode[n] for each enabled stage
  STATE_COLORED2X  = 4;  // textured: alpha=texture*diffuse, color=diffuse*2
 type
  // Функция вычисления цвета в точке (для раскраски текста)
  TColorFunc=function(x,y:single;color:cardinal):cardinal;
  // Процедура модификации стиля отрисовки ссылок
  TTextLinkStyleProc=procedure(link:cardinal;var sUnderline:boolean;var color:cardinal);

 // Вставка картинок в текст (8 байт)
 TInlineImage=packed record
  width:byte;
  padTop,padBottom:byte;
  group:byte;
  ind:word; // INLINE\group\ind
 end;

 // For internal use only - стандартные буферы
 TPainterBuffer=(noBuf,
                 vertBuf,       // буфер вершин для отрисовки партиклов
                 partIndBuf,    // буфер индексов для отрисовки прямоугольников (партиклов, символов текста и т.п)
                 bandIndBuf,    // буфер индексов для отрисовки полос/колец
                 textVertBuf);  // буфер вершин для вывода текста

 TDrawer=class(TInterfacedObject,IDrawer)
  PFTexWidth:integer; // width of texture for PrepareFont
  constructor Create;

  procedure BeginPaint(target:TTexture); override;
  procedure EndPaint; override;
  // Mostly for internal use or tricks, use Begin/EndPaint instead
  procedure PushRenderTarget; override;
  procedure PopRenderTarget; override;


  // State manipulation
  function GetClipping: TRect; override;
  procedure NoClipping; override;
  procedure OverrideClipping; override;
  procedure ResetClipping; override;
  procedure SetClipping(r: TRect); override;


//  procedure ScreenOffset(x, y: integer); override;

  // Drawing methods
  procedure Line(x1,y1,x2,y2:single;color:cardinal); override;
  procedure Polyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false); override;
  procedure Polygon(points:PPoint2;cnt:integer;color:cardinal); override;
  procedure Rect(x1,y1,x2,y2:integer;color:cardinal); override;
  procedure RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2); override;
  procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); override;
  procedure FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal); override;
  procedure ShadedRect(x1,y1,x2,y2,depth:integer;light,dark:cardinal); override;
  procedure TexturedRect(x1,y1,x2,y2:integer;texture:TTexture;u1,v1,u2,v2,u3,v3:single;color:cardinal); override;
  procedure FillGradrect(x1,y1,x2,y2:integer;color1,color2:cardinal;vertical:boolean); override;
  procedure Image(x_,y_:integer;tex:TTexture;color:cardinal=$FF808080); override;
  procedure ImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080); override;
  procedure Centered(x,y:integer;tex:TTexture;color:cardinal=$FF808080); override;
  procedure ImagePart(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect); override;
  // �������� ����� �������� � ��������� ang ��� �� 90 ���� �� ������� �������
  procedure ImagePart90(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect;ang:integer); override;
  procedure Scaled(x1,y1,x2,y2:single;image:TTexture;color:cardinal=$FF808080); override;
  procedure RotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5); override; // x,y - �����
  function Cover(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single; override;
  function Inside(x1,y1,x2,y2:integer;texture:TTexture;color:cardinal=$FF808080):single; override;

  // ������ ��� ����������� �� ���� ������ (����� ���������������������)
  procedure DoubleTex(x_,y_:integer;image1,image2:TTexture;color:cardinal=$FF808080); override;
  procedure DoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
      image1,image2:TTexture;color:cardinal=$FF808080); override;
  // State'� �� ��������������� - ����� ��� ������� ����������� ��������������
  procedure MultiTex(x1,y1,x2,y2:integer;layers:PMultiTexLayer;color:cardinal=$FF808080); override;
  procedure TrgList(pnts:PVertex;trgcount:integer;tex:TTexture); override;
  procedure IndexedMesh(vertices:PVertex;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); override;

  // ��������� ������ ��������� (�� ������������� ������������ ����� 500 ������!)
  procedure Particles(x,y:integer;data:PParticle;count:integer;tex:TTexture;size:integer;zDist:single=0); override;
//  procedure DrawLineParticles(x,y:integer;old,cur:PParticle;count:integer;zDist:single=0); override;
  procedure Band(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect); override;

  // ����� ��������� ������� (protocol 2011)

  procedure DebugScreen1; // ���� � ������ ������
 protected
  canPaint:integer;
  CurFont:cardinal;

  saveClip:array[1..15] of TRect;
  sCnt:byte;

  curTarget:TTexture; // current render target
  renderWidth,renderHeight:integer; // size of render area for default target

  // Texture interpolation settings
//  texIntMode:array[0..3] of TTexInterpolateMode; // current interpolation mode for each texture unit
  texIntFactor:array[0..3] of single; // current interpolation factor constant for each texture unit

  targetstack:array[1..10] of TTexture;  // stack of render targets
  clipStack:array[1..10] of TRect; // ����� RT ���������� ������� ���������
  stackcnt:integer;

  softScaleOn:boolean deprecated; // current state of SoftScale mode (depends on render target)

  chardrawer:integer;
  supportARGB:boolean;
  // Text effect
  efftex:TTexture;
  // last used legacy font texture
  lastFontTexture:TTexture;

  // FOR INTERNAL USE
  // ������ ����� ���������� �� �������� �� ��������� ������ (������ ������ - ScrPoint)
  procedure DrawPrimitives(primType,primCount:integer;vertices:pointer;stride:integer); virtual; abstract;
  // ������ ����� ���������� � ���������������������� (������ ������ - ScrPoint3) stages = 2 ��� 3
  procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); virtual; abstract;
  // ������ ����� ���������� �� �������� �� ������������ ������ Painter'�
  procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
      vertBuf:TPainterBuffer;stride:integer); virtual; abstract;
  // ������ ����� ���������� �� �������� �� ������������ ������ Painter'� � �������� �� ������������ ������
  procedure DrawIndexedPrimitives(primType:integer;vertBuf,indBuf:TPainterBuffer;
      stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); virtual; abstract;
  // ������ ����� ���������� �� �������� �� ��������� ������ � �������� �� ��������� ������
  procedure DrawIndexedPrimitivesDirectly(primType:integer;vertexBuf:PVertex;indBuf:PWord;
    stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); virtual; abstract;

  // Common modes:
  // 0 - undefined state (must be configured by outer code)
  // 1 - 1 stage, Modulate2X
  // 2 - no texturing stages
  // 3 - 3 stages, 1st - Modulate2X, other - undefined
  // 4 - 1 stage, result=diffuse*2
  function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; virtual; abstract; // ���������� false ���� �������� ��������� ����������
  procedure FlushTextCache; virtual;

  // ��������� ������ � ���������� ������, ���������� ��������� �� ������
  // offset is measured in buffer units, not bytes! size - in bytes!
  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer; virtual; abstract;
  procedure UnlockBuffer(buf:TPainterBuffer); virtual; abstract;
 end;

var
 MaxParticleCount:integer=5000;
 MaxGlyphBufferCount:integer=1000; // MUST NOT BE LARGER THAN MaxParticleCount!
 textColorFunc:TColorFunc=nil; // not thread-safe!
 textLinkStyleProc:TTextLinkStyleProc=nil; // not thread-safe!
 // ���� ��� ��������� ������ ������� ������ � ������������ �����, � ��� ����� ���������� �� �������� ������ -
 // �� ���� ������������ ����� ���� ������. ���������� ����� ���������� �����
 curTextLink:cardinal;
 curTextLinkRect:TRect;

 colorFormat:byte; // 1 = ABGR, 0 = ARGB
 // Default width (or height) for modern text cache (must be 512, 1024 or 2048)
 textCacheWidth:integer=512;
 textCacheHeight:integer=512;

implementation
uses SysUtils,Apus.MyServis,Apus.Images,Apus.Geom2D,Math,Apus.Colors;

const
 // Font handle flags (not affecting rendered glyphs)
 fhDontTranslate = $1000000;
 fhItalic        = $2000000;
 fhUnderline     = $4000000;
 // Font handle flags (affecting rendered glyphs)
 fhNoHinting     = $200;
 fhAutoHinting   = $400;
type
 {$IFNDEF FREETYPE}
 TFreeTypeFont=class
 end;
 {$ENDIF}

 // For WriteEx output
 TTextExCacheItem=record
  tex:TTexture; // nil = empty item
  text:string;
  font:cardinal;
  effHash:cardinal;
  alignment:TTextAlignment;
  dx,dy,width_,height_:integer;
  next:integer; // index of next item in queue
 end;

 TUnicodeFontEx=class(TUnicodeFont)
  spareFont:integer; // use this font for missed characters
  spareScale:single; // scale difference: 2.0 means that spare font is 2 times smaller than this
  downscaleFactor:single; // scale glyphs down if scale is less than this value
  upscaleFactor:single; // scale glyphs up if scale is larger than this value
  procedure InitDefaults; override;
 end;

var
 lastFontTex:TTexture; // 256x1024
 FontTexUsage:integer; // y-coord of last used pixel in lastFontTex
 newFonts:array[1..32] of TObject;
 fontMatch:array[1..32] of cardinal; // ������ ������ ������� ������
 fontMatchAddY:array[1..32] of integer;

 glyphCache,altGlyphCache:TGlyphCache;

 textExCache:array[1..24] of TTextExCacheItem;
 textExRecent:integer; // index of the most recent cache item

 // Adjust color format if needed
 procedure ConvertColor(var color:cardinal); inline;
  begin
   if colorFormat=1 then
    color:=color and $FF00FF00+(color and $FF) shl 16+(color and $FF0000) shr 16
  end;

 // Adjust color format if needed
 procedure ConvertColors(color:PCardinal;count,stride:integer);
  begin
   while count>0 do begin
    color^:=color^ and $FF00FF00+(color^ and $FF) shl 16+(color^ and $FF0000) shr 16;
    inc(color,stride shr 2);
    dec(count);
   end;
  end;


procedure TUnicodeFontEx.InitDefaults;
 begin
  inherited;
  downscaleFactor:=DEFAULT_FONT_DOWNSCALE;
  upscaleFactor:=DEFAULT_FONT_UPSCALE;
 end;

procedure DefaultTextLinkStyle(link:cardinal;var sUnderline:boolean;var color:cardinal);
 begin
  sUnderline:=true;
  if link=curTextLink then begin
   color:=ColorAdd(color,$604030);
  end;
 end;

{ TBasicPainter }


constructor TDrawer.Create;
begin
 ForceLogMessage('Creating '+self.ClassName);
 scnt:=0; zPlane:=0;
 stackcnt:=0;
 curtarget:=nil;
 canPaint:=0;
 textcolorx2:=false;
 PFTexWidth:=256;
 vertBufusage:=0;
 textCaching:=false;
 textExRecent:=0;
// if glyphCache=nil then glyphCache:=TFixedGlyphCache.Create(textCacheWidth);
 if glyphCache=nil then glyphCache:=TDynamicGlyphCache.Create(textCacheWidth-96,textCacheHeight);
 if altGlyphCache=nil then begin
  altGlyphCache:=TDynamicGlyphCache.Create(96,textCacheHeight);
  altGlyphCache.relX:=textCacheWidth-96;
 end;
end;

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
end;

procedure TDrawer.Centered(x,y:integer;tex:TTexture;color:cardinal=$FF808080);
begin
 Image(x-tex.width div 2,y-tex.height div 2,tex,color);
end;

procedure SetVertexT(var vrt:TVertex;x,y,z:single;color:cardinal;u,v:single); inline;
begin
 vrt.x:=x;
 vrt.y:=y;
 vrt.z:=z;
 {$IFDEF DIRECTX}
 vrt.rhw:=1;
 {$ENDIF}
 vrt.diffuse:=color;
 vrt.u:=u;
 vrt.v:=v;
end;

procedure SetVertex(var vrt:TVertex;x,y,z:single;color:cardinal); inline;
begin
 vrt.x:=x;
 vrt.y:=y;
 vrt.z:=z;
 {$IFDEF DIRECTX}
 vrt.rhw:=1;
 {$ENDIF}
 vrt.diffuse:=color;
end;

procedure SetVertexC(var vrt:TScrPointNoTex;x,y,z:single;color:cardinal); inline;
begin
 vrt.x:=x;
 vrt.y:=y;
 vrt.z:=z;
 {$IFDEF DIRECTX}
 vrt.rhw:=1;
 {$ENDIF}
 vrt.diffuse:=color;
end;


procedure TDrawer.Image(x_, y_: integer; tex: TTexture; color: cardinal);
var
 vrt:array[0..3] of TVertex;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+tex.width-1,y_+tex.height-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;

 SetVertexT(vrt[0], x_-0.5,y_-0.5,      zPlane,color,tex.u1,tex.v1);
 SetVertexT(vrt[1], x_+dx-0.5,y_-0.5,   zPlane,color,tex.u2,tex.v1);
 SetVertexT(vrt[2], x_+dx-0.5,y_+dy-0.5,zPlane,color,tex.u2,tex.v2);
 SetVertexT(vrt[3], x_-0.5,y_+dy-0.5,   zPlane,color,tex.u1,tex.v2);
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.ImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080);
var
 vrt:array[0..3] of TVertex;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+tex.width-1,y_+tex.height-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;

 SetVertexT(vrt[0], x_-0.5,y_-0.5,      zPlane,color, tex.u1,tex.v1);
 SetVertexT(vrt[1], x_+dx-0.5,y_-0.5,   zPlane,color, tex.u2,tex.v1);
 SetVertexT(vrt[2], x_+dx-0.5,y_+dy-0.5,zPlane,color, tex.u2,tex.v2);
 SetVertexT(vrt[3], x_-0.5,y_+dy-0.5,   zPlane,color, tex.u1,tex.v2);

 if flipHorizontal then begin
  Swap(vrt[0].u,vrt[1].u);
  Swap(vrt[2].u,vrt[3].u);
 end;
 if flipVertical then begin
  Swap(vrt[0].v,vrt[3].v);
  Swap(vrt[1].v,vrt[2].v);
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
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
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+w-1,y_+h-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 SetVertexT(vrt[0], x_-0.5,y_-0.5,     zPlane,color, tex.u1+tex.stepU*2*r.left,tex.v1+tex.stepV*2*r.Top);
 SetVertexT(vrt[1], x_+w+0.5,y_-0.5,   zPlane,color, tex.u1+tex.stepU*r.Right*2,tex.v1+tex.stepV*r.top*2);
 SetVertexT(vrt[2], x_+w+0.5,y_+h+0.5, zPlane,color, tex.u1+tex.stepU*r.Right*2,tex.v1+tex.stepV*r.Bottom*2);
 SetVertexT(vrt[3], x_-0.5,y_+h+0.5,   zPlane,color, tex.u1+tex.stepU*r.left*2,tex.v1+tex.stepV*r.Bottom*2);
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.ImagePart90(x_, y_: integer; tex: TTexture;
  color: cardinal; r: TRect; ang: integer);
var
 vrt:array[0..3] of TVertex;
 w,h:integer;
begin
 if ang and 1=1 then begin
  h:=r.Right-r.Left-1;
  w:=r.Bottom-r.top-1;
 end else begin
  w:=r.Right-r.Left-1;
  h:=r.Bottom-r.top-1;
 end;
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+w-1,y_+h-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);

 with vrt[(0-ang) and 3] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
 end;
 with vrt[0] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*2*r.left; v:=tex.v1+tex.stepV*2*r.Top;
 end;
 with vrt[(1-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_-0.5; z:=zPlane; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
 end;
 with vrt[1] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.top*2;
 end;
 with vrt[(2-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_+h+0.5; z:=zPlane; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
 end;
 with vrt[2] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 with vrt[(3-ang) and 3] do begin
  x:=x_-0.5; y:=y_+h+0.5; z:=zPlane; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
 end;
 with vrt[3] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.left*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.Line(x1, y1, x2, y2: single; color: cardinal);
var
 vrt:array[0..1] of TScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,
   types.Rect(trunc(min2d(x1,x2)),trunc(min2d(y1,y2)),trunc(max2d(x1,x2))+1,trunc(max2d(y1,y2))+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 SetVertexC(vrt[0],x1,y1,zPlane,color);
 SetVertexC(vrt[1],x2,y2,zPlane,color);
 DrawPrimitives(LINE_LIST,1,@vrt,sizeof(TScrPointNoTex));
end;

procedure TDrawer.Polyline(points:PPoint2;cnt:integer;color:cardinal;closed:boolean=false);
var
 vrt:array of TScrPointNoTex;
 i:integer;
 pnt:PPoint2;
 minX,minY,maxX,maxY:integer;
begin
 pnt:=points;
 minX:=10000; minY:=10000; maxX:=-10000; maxY:=-10000;
 SetLength(vrt,cnt+1);
 pnt:=points;
 for i:=0 to cnt-1 do begin
  SetVertexC(vrt[i], pnt.x,pnt.y,zPlane,color);
  if pnt.x<minX then minX:=trunc(pnt.x);
  if pnt.y<minY then minY:=trunc(pnt.y);
  if pnt.x>maxX then maxX:=trunc(pnt.x)+1;
  if pnt.y>maxY then maxY:=trunc(pnt.y)+1;
  inc(pnt);
 end;
 if not SetStates(STATE_COLORED,types.Rect(minX,minY,maxX,maxY)) then exit; // Colored, normal viewport
 ConvertColor(color);
 if closed then vrt[cnt]:=vrt[0];
// DrawPrimitives(LINE_LIST,cnt div 2,@vrt[0],sizeof(ScrPointNoTex));
 DrawPrimitives(LINE_STRIP,cnt-1+byte(closed),@vrt[0],sizeof(TScrPointNoTex));
end;

procedure TDrawer.DoubleTex(x_, y_: integer; image1, image2: TTexture;color: cardinal);
var
 w,h:integer;
 vrt:array[0..3] of TScrPoint3;
 au1,au2,bu1,bu2,av1,av2,bv1,bv2:single;
begin
 ASSERT((image1<>nil) and (image2<>nil));
 w:=min2(image1.width,image2.width);
 h:=min2(image1.height,image2.height);
 if not SetStates(STATE_MULTITEX,types.Rect(x_,y_,x_+w,y_+h),nil) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(image1,0);
 UseTexture(image2,1);
 au1:=image1.u1; au2:=image1.u1+w*image1.stepU*2;
 av1:=image1.v1; av2:=image1.v1+h*image1.stepV*2;
 bu1:=image2.u1; bu2:=image2.u1+w*image2.stepU*2;
 bv1:=image2.v1; bv2:=image2.v1+h*image2.stepV*2;
 with vrt[0] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; rhw:=1; diffuse:=color;
  u:=au1; v:=av1;
  u2:=bu1; v2:=bv1;
 end;
 with vrt[1] do begin
  x:=x_+w-0.5; y:=y_-0.5; z:=zPlane; rhw:=1; diffuse:=color;
  u:=au2; v:=av1;
  u2:=bu2; v2:=bv1;
 end;
 with vrt[2] do begin
  x:=x_+w-0.5; y:=y_+h-0.5; z:=zPlane; rhw:=1; diffuse:=color;
  u:=au2; v:=av2;
  u2:=bu2; v2:=bv2;
 end;
 with vrt[3] do begin
  x:=x_-0.5; y:=y_+h-0.5; z:=zPlane; rhw:=1; diffuse:=color;
  u:=au1; v:=av2;
  u2:=bu1; v2:=bv2;
 end;
 DrawPrimitivesMulti(TRG_FAN,2,@vrt,sizeof(TScrPoint3),2);
// UseTexture(nil,1);
end;

procedure TDrawer.DoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
  image1,image2:TTexture;color:cardinal=$FF808080);
var
 w,h,w2,h2:single;
 vrt:array[0..3] of TScrPoint3;
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
 if not SetStates(STATE_MULTITEX,types.Rect(trunc(x_-h-w),trunc(y_-h-w),trunc(x_+h+w),trunc(y_+h+w)),nil) then exit; // Textured, normal viewport
 x_:=x_-0.5; y_:=y_-0.5;

 // ��� ���� ���-�� ��������� �����, ����� �� ���� �������������
{ if abs(round(w)-w)>0.1 then begin
  x_:=x_+0.5*cos(angle);
  y_:=y_+0.5*sin(angle);
 end;
 if abs(round(h)-h)>0.1 then begin
  x_:=x_+0.5*sin(angle);
  y_:=y_+0.5*cos(angle);
 end;}

 ConvertColor(color);
 UseTexture(image1,0);
 UseTexture(image2,1);

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
 with vrt[0] do begin
  x:=x_-w*c-h*s; y:=y_+h*c-w*s; z:=zPlane; rhw:=1; diffuse:=color;
  u:=au1; v:=av1;
  u2:=bu1; v2:=bv1;
 end;
 with vrt[1] do begin
  x:=x_+w*c-h*s; y:=y_+h*c+w*s;  z:=zPlane; rhw:=1; diffuse:=color;
  u:=au2; v:=av1;
  u2:=bu2; v2:=bv1;
 end;
 with vrt[2] do begin
  x:=x_+w*c+h*s; y:=y_-h*c+w*s;  z:=zPlane; rhw:=1; diffuse:=color;
  u:=au2; v:=av2;
  u2:=bu2; v2:=bv2;
 end;
 with vrt[3] do begin
  x:=x_-w*c+h*s; y:=y_-h*c-w*s;  z:=zPlane; rhw:=1; diffuse:=color;
  u:=au1; v:=av2;
  u2:=bu1; v2:=bv2;
 end;

 DrawPrimitivesMulti(TRG_FAN,2,@vrt,sizeof(TScrPoint3),2);
end;

// ��� ������ �������� ������ � DX, � � OGL - ���� (���������������) ������, ������� �� ���������� ���
procedure TDrawer.MultiTex(x1, y1, x2, y2: integer; layers:PMultiTexLayer; color: cardinal);
var
 vrt:array[0..3] of TScrPoint3;
 lr:array[0..9] of TMultiTexLayer;
 i,lMax:integer;
 // ��������� ������� �� ������� �������� � �������� ����������� � ������������
 procedure AdjustMatrix(var l:TMultitexLayer);
  var
   sx,sy,dx,dy:single;
   i:integer;
  begin
   with l.texture do begin
    sx:=u2-u1; sy:=v2-v1;
    dx:=u1; dy:=v1;
   end;
   for i:=0 to 2 do begin
    l.matrix[i,0]:=l.matrix[i,0]*sx;
    l.matrix[i,1]:=l.matrix[i,1]*sy;
   end;
   l.matrix[2,0]:=l.matrix[2,0]+dx;
   l.matrix[2,1]:=l.matrix[2,1]+dy;
  end;
begin
 if not SetStates(STATE_MULTITEX,types.Rect(x1,y1,x2+1,y2+1)) then exit;
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=0; v:=0; u2:=0; v2:=0; u3:=0; v3:=0;
 end;
 with vrt[1] do begin
  x:=x2+0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=1; v:=0; u2:=1; v2:=0; u3:=1; v3:=0;
 end;
 with vrt[2] do begin
  x:=x2+0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=1; v:=1; u2:=1; v2:=1; u3:=1; v3:=1;
 end;
 with vrt[3] do begin
  x:=x1-0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=0; v:=1; u2:=0; v2:=1; u3:=0; v3:=1;
 end;

 // Copy layers
{ for i:=0 to lMax do lr[i]:=layers[i];

 UseTexture(l1.texture);
 if l1.texture.caps and tfTexture=0 then AdjustMatrix(ll1);
 geom2d.MultPnts(ll1.matrix,PPoint2s(@vrt[0].u),4,sizeof(TScrPoint3));

 // ���������� 2-� ������
 if l2<>nil then begin
  move(l2^,ll2,sizeof(ll2));
  if l2.texture.caps and tfTexture=0 then AdjustMatrix(ll2);
  geom2d.MultPnts(ll2.matrix,PPoint2s(@vrt[0].u2),4,sizeof(TScrPoint3));
  UseTexture(l2.texture,1);
 end;
 // ���������� 3-� ������
 if l3<>nil then begin
  move(l3^,ll3,sizeof(ll3));
  if l3.texture.caps and tfTexture=0 then AdjustMatrix(ll3);
  geom2d.MultPnts(ll3.matrix,PPoint2s(@vrt[0].u3),4,sizeof(TScrPoint3));
  UseTexture(l3.texture,2);
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint3));
 UseTexture(nil,1);
 if l3<>nil then UseTexture(nil,2);    }
end;

procedure TDrawer.Polygon(points: PPoint2; cnt: integer; color: cardinal);
type
 ta=array[0..5] of TPoint2;
var
 vrt:array of TScrPointNoTex;
 i,n:integer;
 pnts:^ta;
 minx,miny,maxx,maxy:single;
begin
 n:=cnt-2;
 if n<1 then exit;
 ConvertColor(color);
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
   SetVertexC(vrt[i],x,y,zPlane,color);

 if not SetStates(STATE_COLORED,types.Rect(trunc(minx),trunc(miny),trunc(maxx)+1,trunc(maxy)+1)) then exit; // Colored, normal viewport
 DrawPrimitives(TRG_LIST,n,@vrt[0],sizeof(TScrPointNoTex));
end;


procedure TDrawer.RotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080;pivotX:single=0.5;pivotY:single=0.5);
var
 vrt:array[0..3] of TVertex;
 u1,v1,u2,v2,w,h,c,s:single;
 wc1,hs1,hc1,ws1,wc2,hs2,hc2,ws2:single;
begin
 ASSERT(image<>nil);
 w:=(image.width)*scaleX;
 h:=(image.height)*scaleY;
 if not SetStates(STATE_TEXTURED2X,types.Rect(trunc(x0-h-w),trunc(y0-h-w),trunc(x0+h+w),trunc(y0+h+w)),image) then exit; // Textured, normal viewport

 ConvertColor(color);
 x0:=x0-0.5; y0:=Y0-0.5;
 if image.width and 1=1 then begin
  x0:=x0+0.5*cos(angle);
  y0:=y0+0.5*sin(angle);
 end;
 if image.height and 1=1 then begin
  x0:=x0+0.5*sin(angle);
  y0:=y0+0.5*cos(angle);
 end;
 UseTexture(image);
 u1:=image.u1; u2:=image.u2;
 v1:=image.v1; v2:=image.v2;
 c:=cos(angle); s:=sin(angle);

 h:=-h;
 wc2:=w*c; wc1:=wc2*pivotX; wc2:=wc2-wc1;
 ws2:=w*s; ws1:=ws2*pivotX; ws2:=ws2-ws1;
 hc2:=h*c; hc1:=hc2*pivotY; hc2:=hc2-hc1;
 hs2:=h*s; hs1:=hs2*pivotY; hs2:=hs2-hs1;

 SetVertexT(vrt[0], x0-wc1-hs1, y0+hc1-ws1, zPlane, color, u1, v1);
 SetVertexT(vrt[1], x0+wc2-hs1, y0+hc1+ws2, zPlane, color, u2, v1);
 SetVertexT(vrt[2], x0+wc2+hs2, y0-hc2+ws2, zPlane, color, u2, v2);
 SetVertexT(vrt[3], x0-wc1+hs2, y0-hc2-ws1, zPlane, color, u1, v2);
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.Scaled(x1, y1, x2, y2: single; image: TTexture;
  color: cardinal);
var
 vrt:array[0..3] of TVertex;
 v,u1,v1,u2,v2:single;
begin
 if not SetStates(STATE_TEXTURED2X,types.Rect(trunc(x1),trunc(y1),trunc(x2+0.999),trunc(y2+0.999)),image) then exit; // Textured, normal viewport
 ConvertColor(color);
 x1:=x1-0.01; y1:=y1-0.01;
 x2:=x2-0.01; y2:=y2-0.01;
 UseTexture(image);
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
 SetVertexT(vrt[0], x1,y1, zPlane, color, u1, v1);
 SetVertexT(vrt[1], x2,y1, zPlane, color, u2, v1);
 SetVertexT(vrt[2], x2,y2, zPlane, color, u2, v2);
 SetVertexT(vrt[3], x1,y2, zPlane, color, u1, v2);

 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.TrgList(pnts: PVertex; trgcount: integer;
  tex: TTexture);
begin
 if tex<>nil then begin
  if not SetStates(STATE_TEXTURED2X,types.Rect(0,0,4096,2048),tex) then exit; // Textured, normal viewport
  UseTexture(tex);
 end else
  if not SetStates(STATE_COLORED,types.Rect(0,0,4096,2048),nil) then exit; // Colored, normal viewport
 if colorFormat>0 then
  ConvertColors(@(pnts^.diffuse),trgCount*3,sizeof(TVertex));
 DrawPrimitives(TRG_LIST,trgcount,pnts,sizeof(TVertex));
end;

procedure TDrawer.IndexedMesh(vertices:PVertex;indices:PWord;trgCount,vrtCount:integer;tex:TTexture);
var
 mode:byte;
begin
 if tex<>nil then mode:=STATE_TEXTURED2X else mode:=STATE_COLORED;
 if not SetStates(mode,types.Rect(0,0,4096,2048),tex) then exit; // Textured, normal viewport
 if tex<>nil then UseTexture(tex);
 if colorFormat>0 then
  ConvertColors(@(vertices^.diffuse),vrtCount,sizeof(TVertex));
 DrawIndexedPrimitivesDirectly(TRG_LIST,vertices,indices,sizeof(TVertex),0,vrtCount,0,trgCount);
end;

procedure TDrawer.Rect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..4] of TScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 SetVertexC(vrt[0], x1,y1,zPlane,color);
 SetVertexC(vrt[1], x2,y1,zPlane,color);
 SetVertexC(vrt[2], x2,y2,zPlane,color);
 SetVertexC(vrt[3], x1,y2,zPlane,color);
 vrt[4]:=vrt[0];
 DrawPrimitives(LINE_STRIP,4,@vrt,sizeof(TScrPointNoTex));
end;

procedure TDrawer.RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2);
var
 vrt:array[0..8] of TScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 SetVertexC(vrt[0],x1+r,y1,zPlane,color);
 SetVertexC(vrt[1],x2-r,y1,zPlane,color);
 SetVertexC(vrt[2],x2,y1+r,zPlane,color);
 SetVertexC(vrt[3],x2,y2-r,zPlane,color);
 SetVertexC(vrt[4],x2-r,y2,zPlane,color);
 SetVertexC(vrt[5],x1+r,y2,zPlane,color);
 SetVertexC(vrt[6],x1,y2-r,zPlane,color);
 SetVertexC(vrt[7],x1,y1+r,zPlane,color);
 vrt[8]:=vrt[0];
 DrawPrimitives(LINE_STRIP,8,@vrt,sizeof(TScrPointNoTex));
end;

procedure TDrawer.FillGradrect(x1, y1, x2, y2: integer; color1,
  color2: cardinal; vertical: boolean);
var
 vrt:array[0..3] of TScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color1);
 ConvertColor(color2);
 SetVertexC(vrt[0], x1-0.5,y1-0.5,zPlane,color1);
 SetVertexC(vrt[1], x2+0.5,y1-0.5,zPlane,color1);
 SetVertexC(vrt[2], x2+0.5,y2+0.5,zPlane,color2);
 SetVertexC(vrt[3], x1-0.5,y2+0.5,zPlane,color1);
 if vertical then vrt[3].diffuse:=color2
  else vrt[1].diffuse:=color2;

 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPointNoTex));
end;

procedure TDrawer.FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal);
var
 vrt:array[0..2] of TScrPointNoTex;
 minX,minY,maxX,maxY:integer;
begin
 minX:=trunc(Min3d(x1,x2,x3));
 maxX:=trunc(Max3d(x1,x2,x3))+1;
 minY:=trunc(Min3d(y1,y2,y3));
 maxY:=trunc(Max3d(y1,y2,y3))+1;
 if not SetStates(STATE_COLORED,types.Rect(minX,minY,maxX,maxY)) then exit; // Colored, normal viewport
 ConvertColor(color1);
 ConvertColor(color2);
 ConvertColor(color3);
 SetVertexC(vrt[0], x1-0.5,y1-0.5,zPlane,color1);
 SetVertexC(vrt[1], x2-0.5,y2-0.5,zPlane,color2);
 SetVertexC(vrt[2], x3-0.5,y3-0.5,zPlane,color3);
 DrawPrimitives(TRG_LIST,1,@vrt,sizeof(TScrPointNoTex));
end;


procedure TDrawer.FillRect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..3] of TScrPointNoTex;
 sx1,sy1,sx2,sy2:single;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 sx1:=x1-0.5; sx2:=x2+0.5;
 sy1:=y1-0.5; sy2:=y2+0.5;
 SetVertexC(vrt[0], sx1,sy1,zPlane,color);
 SetVertexC(vrt[1], sx2,sy1,zPlane,color);
 SetVertexC(vrt[2], sx2,sy2,zPlane,color);
 SetVertexC(vrt[3], sx1,sy2,zPlane,color);
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPointNoTex));
end;

procedure TDrawer.ShadedRect(x1, y1, x2, y2, depth: integer; light,
  dark: cardinal);
var
 vrt:array[0..23] of TScrPointNoTex;
 i:integer;
 b1,b2:PByte;
begin
 ASSERT((depth>=1) and (depth<=3));
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 inc(x1,depth-1); inc(y1,depth-1);
 dec(x2,depth-1); dec(y2,depth-1);
 ConvertColor(light);
 ConvertColor(dark);
 b1:=@light; b2:=@dark;
 inc(b1,3); inc(b2,3);
 for i:=0 to depth-1 do begin
  SetVertexC(vrt[i*8+0], x1,y1+1,zPlane,light);
  SetVertexC(vrt[i*8+1], x1,y2,zPlane,light);
  SetVertexC(vrt[i*8+2], x1,y1,zPlane,light);
  SetVertexC(vrt[i*8+3], x2,y1,zPlane,light);

  SetVertexC(vrt[i*8+4], x2,y2,  zPlane,dark);
  SetVertexC(vrt[i*8+5], x2,y1,  zPlane,dark);
  SetVertexC(vrt[i*8+6], x2-1,y2,zPlane,dark);
  SetVertexC(vrt[i*8+7], x1,y2,  zPlane,dark);

  b1^:=b1^ div 2+32; b2^:=(b2^*3+255) shr 2;
  dec(x1); dec(y1); inc(x2); inc(y2);
 end;
 DrawPrimitives(LINE_LIST,depth*4,@vrt,sizeof(TScrPointNoTex));
end;


procedure TDrawer.TexturedRect(x1, y1, x2, y2: integer; texture: TTexture; u1,
  v1, u2, v2, u3, v3: single; color: cardinal);
var
 vrt:array[0..3] of TVertex;
 sx,dx,sy,dy:single;
begin
 if not SetStates(STATE_TEXTURED2X,types.Rect(x1,y1,x2+1,y2+1),texture) then exit;
 ConvertColor(color);
 SetVertex(vrt[0], x1-0.5, y1-0.5, zPlane,color);
 SetVertex(vrt[1], x2+0.5, y1-0.5, zPlane,color);
 SetVertex(vrt[2], x2+0.5, y2+0.5, zPlane,color);
 SetVertex(vrt[3], x1-0.5, y2+0.5, zPlane,color);
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
 UseTexture(texture);
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TVertex));
end;

procedure TDrawer.Particles(x, y: integer; data: PParticle;
  count: integer; tex: TTexture; size: integer; zDist: single);
type
 PartArr=array[0..100] of TParticle;
 VertexArray=array[0..100] of TVertex;
var
 vrt:^VertexArray;
 idx:array of integer;  // ������ �������� ��������� (���������� �� z)
 i,j,n:integer;
 part:^PartArr;
 needSort:boolean;
 minZ,size2,uStart,vStart,uSize,vSize,rx,ry,qx,qy:single;
 sx,sy:single;
 startU,startV,sizeU,sizeV:integer;
 color:cardinal;
begin
 if not SetStates(STATE_TEXTURED2X,ClipRect,tex) then exit; // Textured, normal viewport
 UseTexture(tex);

 part:=pointer(data);
 if count>MaxParticleCount then count:=MaxParticleCount;
 SetLength(idx,count);
 needSort:=false;
 for i:=0 to count-1 do begin
  if part[i].z<>0 then needSort:=true;
  idx[i]:=i;
 end;
 if needSort then // ���������� (� ������� �������� �� quicksort)
  for i:=0 to count-2 do begin
   n:=i; minZ:=part[idx[n]].z;
   for j:=i+1 to count-1 do
    if part[idx[j]].z<minZ then begin n:=j; minZ:=part[idx[n]].z; end;
   j:=idx[i];
   idx[i]:=idx[n];
   idx[n]:=j;
  end;
 // �������� ��������� �����
 vrt:=LockBuffer(VertBuf,0,4*count*sizeof(TVertex));
 for i:=0 to count-1 do begin
  n:=idx[i];
  startU:=part[n].index and $FF;
  startV:=part[n].index shr 8 and $FF;
  sizeU:=part[n].index shr 16 and $F;
  sizeV:=part[n].index shr 20 and $F;
  if sizeU=0 then sizeU:=1;
  if sizeV=0 then sizeV:=1;
  if part[n].z<-ZDist+0.01 then part[n].z:=-ZDist+0.01; // ����������� �������� ������, ���������!
  // ������ ���������� �������� �-�� �������
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
  ConvertColor(color);
  // ������ �������
  SetVertexT(vrt[i*4],   sx-rx+qx, sy-ry+qy, zPlane,color, uStart,      vStart);
  SetVertexT(vrt[i*4+1], sx+rx+qx, sy+ry+qy, zPlane,color, uStart+uSize,vStart);
  SetVertexT(vrt[i*4+2], sx+rx-qx, sy+ry-qy, zPlane,color, uStart+uSize,vStart+vSize);
  SetVertexT(vrt[i*4+3], sx-rx-qx, sy-ry-qy, zPlane,color, uStart,      vStart+vSize);
 end;
 UnlockBuffer(VertBuf);
 DrawIndexedPrimitives(TRG_LIST,VertBuf,partIndBuf,sizeof(TVertex),0,count*4,0,count*2);
end;

procedure TDrawer.DebugScreen1;
begin
 TextOutW(MAGIC_TEXTCACHE,100,0,0,'');
end;

procedure TDrawer.Band(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect);
type
 PartArr=array[0..100] of TParticle;
 VertexArray=array[0..100] of TVertex;
var
 vrt:^VertexArray;
 i,j,n,loopStart,next,primcount:integer;
 part:^PartArr;
 u1,u2,v1,rx,ry,qx,qy,l,vstep:single;
 sx,sy:single;
 noPrv:boolean;
 idx:^word;
 color:cardinal;
begin
 if tex=nil then i:=STATE_COLORED
  else i:=STATE_TEXTURED2X;

 if not SetStates(i,ClipRect,tex) then exit; // Proper mode
 if tex<>nil then UseTexture(tex);
 part:=pointer(data);
 if count>MaxParticleCount then count:=MaxParticleCount;
{ if part[count-1].index and (partEndpoint+partLoop)=0 then   // ����������� �������� ������ �����������!
  part[count-1].index:=part[count-1].index or partEndpoint; }

 if tex<>nil then begin
  u1:=tex.u1+tex.stepU*(2*r.Left+1);
  u2:=tex.u1+tex.stepU*(2*r.Right-1);
  v1:=tex.v1+tex.stepV*(2*r.top+1);
  vstep:=tex.stepV*2;
 end else begin
  u1:=0; u2:=0; v1:=0; vstep:=0;
 end;

 // �������� ��������� �����
 noPrv:=true;
 loopstart:=0;
 primcount:=0;
 vrt:=LockBuffer(VertBuf,0,2*count*sizeof(TVertex));
 idx:=LockBuffer(bandIndBuf,0,6*count*2);
 for i:=0 to count-1 do begin
   // ������ ���������� �������� �-�� �������
   sx:=x+part[i].x;
   sy:=y+part[i].y;

   if noPrv or
     (part[i].index and partEndpoint>0) or
     ((i=count-1) and (part[i].index and partLoop=0)) then begin
     // ��������� ���� �������� �������
     if noPrv then begin
       if part[i].index and partLoop>0 then begin // ������ ������� �����
        j:=i+1;
        while (j<count) and (part[j].index and partLoop=0) do inc(j);
        part[i].index:=part[i].index and (not partLoop);
       end else
        j:=i; // ������ ������� �����
       qx:=part[i+1].x-part[j].x;
       qy:=part[i+1].y-part[j].y;
     end else begin
       // ��������� ������� �����
       qx:=part[i].x-part[i-1].x;
       qy:=part[i].y-part[i-1].y;
     end;
   end else begin
     if part[i].index and partLoop>0 then begin
      // ��������� ������� �����
      qx:=part[loopStart].x-part[i-1].x;
      qy:=part[loopStart].y-part[i-1].y;
     end else begin
      // ������������� �������
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
   ConvertColor(color);
   // ������ �������
   SetVertexT(vrt[i*2],   sx-rx,sy-ry, zPlane,color, u1,v1+vStep*(part[i].index and $FF));
   SetVertexT(vrt[i*2+1], sx+rx,sy+ry, zPlane,color, u2,v1+vStep*(part[i].index and $FF));
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
   // ������ ����������� - (0,1,2)
   idx^:=i*2; inc(idx);
   idx^:=i*2+1; inc(idx);
   idx^:=next*2; inc(idx);
   // ������ ����������� - (2,1,3)
   idx^:=next*2; inc(idx);
   idx^:=i*2+1; inc(idx);
   idx^:=next*2+1; inc(idx);
   inc(primcount,2);
 end;

 UnlockBuffer(BandIndBuf);
 UnlockBuffer(VertBuf);
 DrawIndexedPrimitives(TRG_LIST,VertBuf,bandIndBuf,sizeof(TVertex),0,count*2,0,primCount);
end;

{procedure TDrawer.ScreenOffset(x, y: integer);
begin
 permOfsX:=x; curOfsX:=x;
 permOfsY:=y; curOfsY:=y;
end;}


procedure TDrawer.SetClipping(r: TRect);
begin
 if scnt>=15 then exit;
 inc(scnt);
 saveclip[scnt]:=cliprect;
 if IntersectRects(cliprect,r,cliprect)=0 then begin // no intersection
  cliprect:=types.Rect(-1,-1,-1,-1);
 end;
end;

procedure TDrawer.ResetClipping;
begin
 if scnt<=0 then exit;
 cliprect:=saveclip[scnt];
 dec(scnt);
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

initialization
 textLinkStyleProc:=DefaultTextLinkStyle;
end.
