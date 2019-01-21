// Implementation of common drawing interface (system-independent)
//
// Copyright (C) 2011 Apus Software (www.spectromancer.com, www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by)
{$R-}
unit BasicPainter;
interface
 uses EngineCls,Types,geom2D,geom3D;
 const
  MAGIC_TEXTCACHE = $01FF;
  DEFAULT_FONT_DOWNSCALE = 0.93;
  DEFAULT_FONT_UPSCALE = 1.1;

  // FT-шрифты не имеют "базового" размера, поэтому scale задается относительно произвольно зафиксированного размера 
  FTF_DEFAULT_LINE_HEIGHT = 24; // Высота строки, соответствующей scale=100

  // States
  STATE_TEXTURED2X = 1;  // single textured: use TexMode[0] (default: color=texture*diffuse*2, alpha=texture*diffuse)
  STATE_COLORED    = 2;  // no texture: color=diffuse, alpha=diffuse
  STATE_MULTITEX   = 3;  // multitextured: use TexMode[n] for each enabled stage
  STATE_COLORED2X  = 4;  // textured: alpha=texture*diffuse, color=diffuse*2
 type
  // Функция вычисления цвета в точке
  TColorFunc=function(x,y:single;color:cardinal):cardinal;
  // Процедура модификации стиля отрисовки ссылок
  TTextLinkStyleProc=procedure(link:cardinal;var sUnderline:boolean;var color:cardinal);

  ScrPointNoTex=record
   x,y,z,rhw:single;
   diffuse,specular:cardinal;
  end;
  Point3Lit=record
   x,y,z:single;
   color:cardinal;
   u,v:single;
  end;
  Point3Unlit=record
   x,y,z:single;
   nx,ny,nz:single;
   color,specular:cardinal;
   u,v:single;
  end;

 // Таблица перекодировки:
 // если число >=32 - индекс символа
 // <32 - ширина спецсимвола в пикселях
 PCharMap=^TCharMap;
 TCharMap=array[0..255] of byte;

 // Вставка картинок в текст (8 байт)
 TInlineImage=packed record
  width:byte; // ширина картинки
  padTop,padBottom:byte; // относительно средней линии
  group:byte;
  ind:word; // числовое имя: INLINE\group\ind
 end;

 // For internal use only - стандартные буферы
 TPainterBuffer=(noBuf,
                 vertBuf,       // буфер вершин для отрисовки партиклов
                 partIndBuf,    // буфер индексов для отрисовки прямоугольников (партиклов, символов текста и т.п)
                 bandIndBuf,    // буфер индексов для отрисовки полос/колец
                 textVertBuf);  // буфер вершин для вывода текста

 TBasicPainter=class(TPainter)
  PFTexWidth:integer; // width of texture for PrepareFont
//  constructor Create;
  constructor Create(textureMan:TTextureMan);

  // Начать рисование (использовать указанную текстуру либо основной буфер если она не указана)
  procedure BeginPaint(target:TTexture); override;
  // Завершить рисование
  procedure EndPaint; override;
  // Mostly for internal use or tricks, use Begin/EndPaint instead
  procedure PushRenderTarget; override;
  procedure PopRenderTarget; override;

  // 3D management
  procedure SetupCamera(origin,target,up:TPoint3;turnCW:double=0); override;

  // State manipulation
  function GetClipping: TRect; override;
  procedure NoClipping; override;
  procedure OverrideClipping; override;
  procedure ResetClipping; override;
  procedure SetClipping(r: TRect); override;

  procedure UseCustomShader; override;


//  procedure ScreenOffset(x, y: integer); override;

  // Drawing methods
  procedure DrawLine(x1,y1,x2,y2:single;color:cardinal); override;
  procedure DrawPolygon(points:PPoint2;cnt:integer;color:cardinal); override;
  procedure Rect(x1,y1,x2,y2:integer;color:cardinal); override;
  procedure RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2); override;
  procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); override;
  procedure FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal); override;  
  procedure ShadedRect(x1,y1,x2,y2,depth:integer;light,dark:cardinal); override;
  procedure TexturedRect(x1,y1,x2,y2:integer;texture:TTexture;u1,v1,u2,v2,u3,v3:single;color:cardinal); override;
  procedure FillGradrect(x1,y1,x2,y2:integer;color1,color2:cardinal;vertical:boolean); override;
  procedure DrawImage(x_,y_:integer;tex:TTexture;color:cardinal=$FF808080); override;
  procedure DrawImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080); override;
  procedure DrawCentered(x,y:integer;tex:TTexture;color:cardinal=$FF808080); override;
  procedure DrawImagePart(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect); override;
  // Рисовать часть картинки с поворотом ang раз на 90 град по часовой стрелке
  procedure DrawImagePart90(x_,y_:integer;tex:TTexture;color:cardinal;r:TRect;ang:integer); override;
  procedure DrawScaled(x1,y1,x2,y2:single;image:TTexture;color:cardinal=$FF808080); override;
  procedure DrawRotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080); override; // x,y - центр
  // Рисует два изображения за один проход (путем мультитекстурирования)
  procedure DrawDouble(x_,y_:integer;image1,image2:TTexture;color:cardinal=$FF808080); override;
  procedure DrawDoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
      image1,image2:TTexture;color:cardinal=$FF808080); override;
  // State'ы не устанавливаются - нужно все заранее подготовить самостоятельно
  procedure DrawMultiTex(x1,y1,x2,y2:integer;layers:PMultiTexLayer;color:cardinal=$FF808080); override;
  procedure DrawTrgListTex(pnts:PScrPoint;trgcount:integer;tex:TTexture); override;
  procedure DrawIndexedMesh(vertices:PScrPoint;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); override;

  // отрисовка набора партиклов (не рекомендуется использовать более 500 частиц!)
  procedure DrawParticles(x,y:integer;data:PParticle;count:integer;tex:TTexture;size:integer;zDist:single=0); override;
//  procedure DrawLineParticles(x,y:integer;old,cur:PParticle;count:integer;zDist:single=0); override;
  procedure DrawBand(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect); override;

  // Новые текстовые функции (protocol 2011)
  function LoadFont(fName:string;asName:string=''):string; override; // загрузка из файла, возвращает имя шрифта
  function LoadFont(font:array of byte;asName:string=''):string; override; // загрузка из памяти, возвращает имя шрифта
  function GetFont(name:string;size:single=0.0;flags:integer=0;effects:byte=0):cardinal; override; // возвращает хэндл шрифта
  function TextWidth(font:cardinal;st:AnsiString):integer; override;
  function TextWidthW(font:cardinal;st:wideString):integer; override;
  function FontHeight(font:cardinal):integer; override;
  procedure TextOut(font:cardinal;x,y:integer;color:cardinal;st:AnsiString;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0); override;
  procedure TextOutW(font:cardinal;x,y:integer;color:cardinal;st:widestring;align:TTextAlignment=taLeft;
     options:integer=0;targetWidth:integer=0;query:cardinal=0); override;
//  procedure TextOutEx(x,y:integer;st:widestring;attribs:PCharAttr;align:TTextAlignment=taLeft;options:integer=0); override;
  procedure MatchFont(legacyfont,newfont:cardinal;addY:integer=0); override; // какой новый шрифт использовать вместо старого
  procedure SetFontOption(font:cardinal;option:cardinal;value:single); override;
  procedure SetTextTarget(buf:pointer;pitch:integer); override;

  procedure BeginTextBlock; override; // включает кэширование вывода текста
  procedure EndTextBlock;  override; // выводит кэш и выключает кэширование

  procedure UseTexture(tex:TTexture;stage:integer=0); virtual; abstract;

  procedure DebugScreen1; // инфа о выводе текста
 protected
  texman:TTextureMan;

  canPaint:integer;
  CurFont:cardinal;

  saveClip:array[1..15] of TRect;
  sCnt:byte;

  curTarget:TTexture; // current render target

  // Texture interpolation settings
//  texIntMode:array[0..3] of TTexInterpolateMode; // current interpolation mode for each texture unit
  texIntFactor:array[0..3] of single; // current interpolation factor constant for each texture unit 

  targetstack:array[1..10] of TTexture;  // stack of render targets
  clipStack:array[1..10] of TRect; // Смена RT сбрасывает область отсечения
  stackcnt:integer;

  textCaching:boolean;  // cache draw operations
  vertBufUsage:integer; // number of vertices stored in vertBuf
  textBufUsage:integer; // number of vertices stored in textBuf
  softScaleOn:boolean deprecated; // current state of SoftScale mode (depends on render target)

  charmap:PCharMap;
  chardrawer:integer;
  supportARGB:boolean;
  // Text effect
  efftex:TTextureImage;
  // last used legacy font texture
  lastFontTexture:TTexture;
  textCache:TTextureImage; // texture with cached glyphs (textCacheWidth x 512, or another for new glyph cache structure)

  // Buffer for alternate text rendering
  textBufferBitmap:pointer;
  textBufferPitch:integer;

  // FOR INTERNAL USE
  // Рисует набор примитивов по вершинам из указанной памяти (формат вершин - ScrPoint)
  procedure DrawPrimitives(primType,primCount:integer;vertices:pointer;stride:integer); virtual; abstract;
  // Рисует набор примитивов с мультитекстурированием (формат вершин - ScrPoint3) stages = 2 или 3
  procedure DrawPrimitivesMulti(primType,primCount:integer;vertices:pointer;stride:integer;stages:integer); virtual; abstract;
  // Рисует набор примитивов по вершинам из стандартного буфера Painter'а
  procedure DrawPrimitivesFromBuf(primType,primCount,vrtStart:integer;
      vertBuf:TPainterBuffer;stride:integer); virtual; abstract;
  // Рисует набор примитивов по вершинам из стандартного буфера Painter'а И индексам из стандартного буфера
  procedure DrawIndexedPrimitives(primType:integer;vertBuf,indBuf:TPainterBuffer;
      stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); virtual; abstract;
  // Рисует набор примитивов по вершинам из указанной памяти и индексам из указанной памяти
  procedure DrawIndexedPrimitivesDirectly(primType:integer;vertexBuf:PScrPoint;indBuf:PWord;
    stride:integer;vrtStart,vrtCount:integer; indStart,primCount:integer); virtual; abstract;

  // Common modes:
  // 0 - undefined state (must be configured by outer code)
  // 1 - 1 stage, Modulate2X
  // 2 - no texturing stages
  // 3 - 3 stages, 1st - Modulate2X, other - undefined
  // 4 - 1 stage, result=diffuse*2
  function SetStates(state:byte;primRect:TRect;tex:TTexture=nil):boolean; virtual; abstract; // возвращает false если примитив полностью отсекается
  procedure FlushTextCache; virtual;

  // Открывает доступ к указанному буферу, возвращает указатель на данные
  // offset is measured in buffer units, not bytes! size - in bytes!
  function LockBuffer(buf:TPainterBuffer;offset,size:cardinal):pointer; virtual; abstract;
  procedure UnlockBuffer(buf:TPainterBuffer); virtual; abstract;
 end;

var
 MaxParticleCount:integer=5000;
 MaxGlyphBufferCount:integer=1000; // MUST NOT BE LARGER THAN MaxParticleCount!
 textColorFunc:TColorFunc=nil; // not thread-safe!
 textLinkStyleProc:TTextLinkStyleProc=nil; // not thread-safe!
 // Если при отрисовке текста передан запрос с координатами точки, и эта точка приходится на рисуемую ссылку -
 // то сюда записывается номер этой ссылки. Обнулять нужно самостоятельно.
 curTextLink:cardinal;
 curTextLinkRect:TRect; 

 colorFormat:byte; // 1 = ABGR, 0 = ARGB
 // Default width (or height) for modern text cache (must be 512, 1024 or 2048)
 textCacheWidth:integer=512;
 textCacheHeight:integer=512;

implementation
uses SysUtils,MyServis,images,ImageMan,UDict,UnicodeFont,EngineTools,
     colors,glyphCaches{$IFDEF FREETYPE},FreeTypeFont{$ENDIF};

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

 // Флаги применимы как к отдельным символам, так и к шрифту в целом
 // Старые шрифты (для совместимости)
 TCharData=packed record
  baseline,width,height,flags:byte;
  kernleftmask,kernrightmask:word; // (по 2 бита на зону)
  x1,y1,x2,y2:word; // 0 если символа нет
 end;
 TFont=class
  chars:array[char] of TCharData;
  height,baseAdd,charspacing:integer;
  texture:TTextureImage;
  scale:single; // 1/N
 end;

 // For WriteEx output
 TTextExCacheItem=record
  tex:TTextureImage; // nil = empty item
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
 crSect:TMyCriticalSection; // нахрена!?? Почти нигде не используется

 fonts:array[1..32] of TFont;
 lastFontTex:TTextureImage; // 256x1024
 FontTexUsage:integer; // y-coord of last used pixel in lastFontTex
 newFonts:array[1..32] of TObject;
 fontMatch:array[1..32] of cardinal; // замена старых шрифтов новыми
 fontMatchAddY:array[1..32] of integer;

 glyphCache,altGlyphCache:TGlyphCache;
// glyphTex:TTextureImage;

 textExCache:array[1..24] of TTextExCacheItem;
 textExRecent:integer; // index of the most recent cache item

 // Adjust color format if needed
 procedure ConvertColor(var color:cardinal); inline;
  begin
   if colorFormat=1 then
    color:=color and $FF00FF00+(color and $FF) shl 16+(color and $FF0000) shr 16
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

procedure TBasicPainter.BeginPaint(target: TTexture);
begin
 if (canPaint>0) and (target=curtarget) then
   raise EWarning.Create('BP: target already set');
 PushRenderTarget;
 if target<>curtarget then begin
  if target<>nil then SetTargetToTexture(target)
   else ResetTarget;
 end else begin
  RestoreClipping;
 end;

 inc(canPaint);
end;

procedure TBasicPainter.EndPaint;
begin
 if canpaint=0 then exit;
// LogMessage('EP: '+inttohex(integer(curtarget),8));
 PopRenderTarget;
 dec(canPaint);
end;

procedure TBasicPainter.PopRenderTarget;
begin
 ASSERT(stackCnt>0);
 if targetStack[stackCnt]=nil then ResetTarget
  else SetTargetToTexture(targetStack[stackcnt]);
 clipRect:=clipStack[stackcnt];
 dec(stackCnt);
end;

procedure TBasicPainter.PushRenderTarget;
begin
 ASSERT(stackCnt<10);
 inc(stackCnt);
 targetStack[stackcnt]:=curtarget;
 clipStack[stackcnt]:=clipRect;
end;


constructor TBasicPainter.Create;
begin
 ForceLogMessage('Creating '+self.ClassName);
 Assert(textureman<>nil);
 texman:=TextureMan;

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

function TBasicPainter.GetClipping: TRect;
begin
 result:=clipRect;
end;

procedure TBasicPainter.NoClipping;
begin
 cliprect:=screenRect;
 scnt:=0;
end;

procedure TBasicPainter.OverrideClipping;
begin
 if scnt>=15 then exit;
 inc(scnt);
 saveclip[scnt]:=cliprect;
 ClipRect:=screenRect;
end;

procedure TBasicPainter.DrawCentered(x,y:integer;tex:TTexture;color:cardinal=$FF808080);
begin
 DrawImage(x-tex.width div 2,y-tex.height div 2,tex,color);
end;

procedure TBasicPainter.DrawImage(x_, y_: integer; tex: TTexture; color: cardinal);
var
 vrt:array[0..3] of TScrPoint;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+tex.width-1,y_+tex.height-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;
 with vrt[0] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1; v:=tex.v1;
 end;
 with vrt[1] do begin
  x:=x_+dx-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u2; v:=tex.v1;
 end;
 with vrt[2] do begin
  x:=x_+dx-0.5; y:=y_+dy-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u2; v:=tex.v2;
 end;
 with vrt[3] do begin
  x:=x_-0.5; y:=y_+dy-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1; v:=tex.v2{-tex.stepV};
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawImageFlipped(x_,y_:integer;tex:TTexture;flipHorizontal,flipVertical:boolean;color:cardinal=$FF808080);
var
 vrt:array[0..3] of TScrPoint;
 dx,dy:single;
begin
 ASSERT(tex<>nil);
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+tex.width-1,y_+tex.height-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 dx:=tex.width;
 dy:=tex.height;
 with vrt[0] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1; v:=tex.v1;
 end;
 with vrt[1] do begin
  x:=x_+dx-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u2; v:=tex.v1;
 end;
 with vrt[2] do begin
  x:=x_+dx-0.5; y:=y_+dy-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u2; v:=tex.v2;
 end;
 with vrt[3] do begin
  x:=x_-0.5; y:=y_+dy-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1; v:=tex.v2{-tex.stepV};
 end;
 if flipHorizontal then begin
  Swap(vrt[0].u,vrt[1].u);
  Swap(vrt[2].u,vrt[3].u);
 end;
 if flipVertical then begin
  Swap(vrt[0].v,vrt[3].v);
  Swap(vrt[1].v,vrt[2].v);
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawImagePart(x_, y_: integer; tex: TTexture;
  color: cardinal; r: TRect);
var
 vrt:array[0..3] of TScrPoint;
 w,h:integer;
begin
 w:=abs(r.Right-r.Left)-1;
 h:=abs(r.Bottom-r.top)-1;
 if tex.caps and tfScaled>0 then begin
  w:=round(w+1)-1;
  h:=round(h+1)-1;
 end;
 if not SetStates(STATE_TEXTURED2X,types.Rect(x_,y_,x_+w-1,y_+h-1),tex) then exit; // Textured, normal viewport
 ConvertColor(color);
 UseTexture(tex);
 with vrt[0] do begin
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1+tex.stepU*2*r.left; v:=tex.v1+tex.stepV*2*r.Top;
 end;
 with vrt[1] do begin
  x:=x_+w+0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.top*2;
 end;
 with vrt[2] do begin
  x:=x_+w+0.5; y:=y_+h+0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 with vrt[3] do begin
  x:=x_-0.5; y:=y_+h+0.5; z:=zPlane; rhw:=1;
  diffuse:=color; u:=tex.u1+tex.stepU*r.left*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawImagePart90(x_, y_: integer; tex: TTexture;
  color: cardinal; r: TRect; ang: integer);
var
 vrt:array[0..3] of TScrPoint;
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
  x:=x_-0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
 end;
 with vrt[0] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*2*r.left; v:=tex.v1+tex.stepV*2*r.Top;
 end;
 with vrt[(1-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_-0.5; z:=zPlane; rhw:=1;
 end;
 with vrt[1] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.top*2;
 end;
 with vrt[(2-ang) and 3] do begin
  x:=x_+w+0.5; y:=y_+h+0.5; z:=zPlane; rhw:=1;
 end;
 with vrt[2] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.Right*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 with vrt[(3-ang) and 3] do begin
  x:=x_-0.5; y:=y_+h+0.5; z:=zPlane; rhw:=1;
 end;
 with vrt[3] do begin
  diffuse:=color; u:=tex.u1+tex.stepU*r.left*2; v:=tex.v1+tex.stepV*r.Bottom*2;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawLine(x1, y1, x2, y2: single; color: cardinal);
var
 vrt:array[0..1] of ScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(trunc(x1),trunc(y1),trunc(x2)+1,trunc(y2)+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 with vrt[0] do begin
  x:=x1; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[1] do begin
  x:=x2; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 DrawPrimitives(LINE_LIST,1,@vrt,sizeof(ScrPointNoTex));
end;

procedure TBasicPainter.DrawDouble(x_, y_: integer; image1, image2: TTexture;color: cardinal);
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

procedure TBasicPainter.DrawDoubleRotScaled(x_,y_:single;scale1X,scale1Y,scale2X,scale2Y,angle:single;
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

 // Тут надо что-то придумать умное, чтобы не было заблуренности
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

// Эта версия работает только в DX, а у OGL - своя (неуниверсальная) версия, которая не использует эту
procedure TBasicPainter.DrawMultiTex(x1, y1, x2, y2: integer; layers:PMultiTexLayer; color: cardinal);
var
 vrt:array[0..3] of TScrPoint3;
 lr:array[0..9] of TMultiTexLayer;
 i,lMax:integer;
 // перевести матрицу из полного масштаба к масштабу изображения в метатекстуре
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

 // Подготовка 2-й стадии
 if l2<>nil then begin
  move(l2^,ll2,sizeof(ll2));
  if l2.texture.caps and tfTexture=0 then AdjustMatrix(ll2);
  geom2d.MultPnts(ll2.matrix,PPoint2s(@vrt[0].u2),4,sizeof(TScrPoint3));
  UseTexture(l2.texture,1);
 end;
 // Подготовка 3-й стадии
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

procedure TBasicPainter.DrawPolygon(points: PPoint2; cnt: integer; color: cardinal);
type
 ta=array[0..5] of TPoint2;
var
 vrt:array of ScrPointNoTex;
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
 for i:=0 to n*3-1 do with pnts^[trgIndices[i]] do begin
  vrt[i].x:=x;
  vrt[i].y:=y;
  vrt[i].z:=zPlane;
  vrt[i].rhw:=1;
  vrt[i].diffuse:=color;
 end;
 if not SetStates(STATE_COLORED,types.Rect(trunc(minx),trunc(miny),trunc(maxx)+1,trunc(maxy)+1)) then exit; // Colored, normal viewport
 DrawPrimitives(TRG_LIST,n,@vrt[0],sizeof(ScrPointNoTex));
end;


procedure TBasicPainter.DrawRotScaled(x0,y0,scaleX,scaleY,angle:double;image:TTexture;color:cardinal=$FF808080);
var
 vrt:array[0..3] of TScrPoint;
 u1,v1,u2,v2,w,h,c,s:single;
begin
 ASSERT(image<>nil);
 w:=(image.width)/2*scaleX;
 h:=(image.height)/2*scaleY;
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
 with vrt[0] do begin
  x:=x0-w*c-h*s; y:=y0+h*c-w*s; z:=zPlane; rhw:=1;
  diffuse:=color; u:=u1; v:=v1;
 end;
 with vrt[1] do begin
  x:=x0+w*c-h*s; y:=y0+h*c+w*s;  z:=zPlane; rhw:=1;
  diffuse:=color; u:=u2; v:=v1;
 end;
 with vrt[2] do begin
  x:=x0+w*c+h*s; y:=y0-h*c+w*s;  z:=zPlane; rhw:=1;
  diffuse:=color; u:=u2; v:=v2;
 end;
 with vrt[3] do begin
  x:=x0-w*c+h*s; y:=y0-h*c-w*s;  z:=zPlane; rhw:=1;
  diffuse:=color; u:=u1; v:=v2;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawScaled(x1, y1, x2, y2: single; image: TTexture;
  color: cardinal);
var
 vrt:array[0..3] of TScrPoint;
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
 with vrt[0] do begin
  x:=x1; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color; u:=u1; v:=v1;
 end;
 with vrt[1] do begin
  x:=x2; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color; u:=u2; v:=v1;
 end;
 with vrt[2] do begin
  x:=x2; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color; u:=u2; v:=v2;
 end;
 with vrt[3] do begin
  x:=x1; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color; u:=u1; v:=v2;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawTrgListTex(pnts: PScrPoint; trgcount: integer;
  tex: TTexture);
var
 i:integer;
 p:PScrPoint;
begin
 if not SetStates(STATE_TEXTURED2X,types.Rect(0,0,4096,2048),tex) then exit; // Textured, normal viewport
 UseTexture(tex);
 DrawPrimitives(TRG_LIST,trgcount,pnts,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawIndexedMesh(vertices:PScrPoint;indices:PWord;trgCount,vrtCount:integer;tex:TTexture); 
var
 i:integer;
 p:PScrPoint;
 mode:byte;
begin
 if tex<>nil then mode:=STATE_TEXTURED2X else mode:=STATE_COLORED;
 if not SetStates(mode,types.Rect(0,0,4096,2048),tex) then exit; // Textured, normal viewport
 if tex<>nil then UseTexture(tex);
 DrawIndexedPrimitivesDirectly(TRG_LIST,vertices,indices,sizeof(TScrPoint),0,vrtCount,0,trgCount);
end;

procedure TBasicPainter.Rect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..4] of ScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 with vrt[0] do begin
  x:=x1; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[1] do begin
  x:=x2; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[2] do begin
  x:=x2; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[3] do begin
  x:=x1; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 vrt[4]:=vrt[0];
 DrawPrimitives(LINE_STRIP,4,@vrt,sizeof(ScrPointNoTex));
end;

procedure TBasicPainter.RRect(x1,y1,x2,y2:integer;color:cardinal;r:integer=2);
var
 vrt:array[0..8] of ScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 with vrt[0] do begin
  x:=x1+r; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[1] do begin
  x:=x2-r; y:=y1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[2] do begin
  x:=x2; y:=y1+r; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[3] do begin
  x:=x2; y:=y2-r; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[4] do begin
  x:=x2-r; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[5] do begin
  x:=x1+r; y:=y2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[6] do begin
  x:=x1; y:=y2-r; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[7] do begin
  x:=x1; y:=y1+r; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 vrt[8]:=vrt[0];
 DrawPrimitives(LINE_STRIP,8,@vrt,sizeof(ScrPointNoTex));
end;

procedure TBasicPainter.FillGradrect(x1, y1, x2, y2: integer; color1,
  color2: cardinal; vertical: boolean);
var
 vrt:array[0..3] of ScrPointNoTex;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color1);
 ConvertColor(color2);
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color1;
 end;
 with vrt[1] do begin
  x:=x2+0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  if vertical then diffuse:=color1 else diffuse:=color2;
 end;
 with vrt[2] do begin
  x:=x2+0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  diffuse:=color2;
 end;
 with vrt[3] do begin
  x:=x1-0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  if vertical then diffuse:=color2 else diffuse:=color1;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(ScrPointNoTex));
end;

procedure TBasicPainter.FillTriangle(x1,y1,x2,y2,x3,y3:single;color1,color2,color3:cardinal);
var
 vrt:array[0..2] of ScrPointNoTex;
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
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color1;
 end;
 with vrt[1] do begin
  x:=x2-0.5; y:=y2-0.5; z:=zPlane; rhw:=1;
  diffuse:=color2;
 end;
 with vrt[2] do begin
  x:=x3-0.5; y:=y3-0.5; z:=zPlane; rhw:=1;
  diffuse:=color3;
 end;
 DrawPrimitives(TRG_LIST,1,@vrt,sizeof(ScrPointNoTex));
end;


procedure TBasicPainter.FillRect(x1, y1, x2, y2: integer; color: cardinal);
var
 vrt:array[0..3] of ScrPointNoTex;
 sx1,sy1,sx2,sy2:single;
begin
 if not SetStates(STATE_COLORED,types.Rect(x1,y1,x2+1,y2+1)) then exit; // Colored, normal viewport
 ConvertColor(color);
 sx1:=x1-0.5; sx2:=x2+0.5;
 sy1:=y1-0.5; sy2:=y2+0.5;

 with vrt[0] do begin
  x:=sx1; y:=sy1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[1] do begin
  x:=sx2; y:=sy1; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[2] do begin
  x:=sx2; y:=sy2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[3] do begin
  x:=sx1; y:=sy2; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(ScrPointNoTex));
end;

procedure TBasicPainter.ShadedRect(x1, y1, x2, y2, depth: integer; light,
  dark: cardinal);
var
 vrt:array[0..23] of ScrPointNoTex;
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
  with vrt[i*8+0] do begin x:=x1; y:=y1+1; z:=zPlane; rhw:=1; diffuse:=light; end;
  with vrt[i*8+1] do begin x:=x1; y:=y2; z:=zPlane; rhw:=1; diffuse:=light; end;
  with vrt[i*8+2] do begin x:=x1; y:=y1; z:=zPlane; rhw:=1; diffuse:=light; end;
  with vrt[i*8+3] do begin x:=x2; y:=y1; z:=zPlane; rhw:=1; diffuse:=light; end;

  with vrt[i*8+4] do begin x:=x2; y:=y2; z:=zPlane; rhw:=1; diffuse:=dark; end;
  with vrt[i*8+5] do begin x:=x2; y:=y1; z:=zPlane; rhw:=1; diffuse:=dark; end;
  with vrt[i*8+6] do begin x:=x2-1; y:=y2; z:=zPlane; rhw:=1; diffuse:=dark; end;
  with vrt[i*8+7] do begin x:=x1; y:=y2; z:=zPlane; rhw:=1; diffuse:=dark; end;
  b1^:=b1^ div 2+32; b2^:=(b2^*3+255) shr 2;
  dec(x1); dec(y1); inc(x2); inc(y2);
 end;
 DrawPrimitives(LINE_LIST,depth*4,@vrt,sizeof(ScrPointNoTex));
end;


procedure TBasicPainter.TexturedRect(x1, y1, x2, y2: integer; texture: TTexture; u1,
  v1, u2, v2, u3, v3: single; color: cardinal);
var
 vrt:array[0..3] of TScrPoint;
 sx,dx,sy,dy:single;
begin
 if not SetStates(STATE_TEXTURED2X,types.Rect(x1,y1,x2+1,y2+1),texture) then exit;
 ConvertColor(color);
 with vrt[0] do begin
  x:=x1-0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[1] do begin
  x:=x2+0.5; y:=y1-0.5; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[2] do begin
  x:=x2+0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
 with vrt[3] do begin
  x:=x1-0.5; y:=y2+0.5; z:=zPlane; rhw:=1;
  diffuse:=color;
 end;
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
 DrawPrimitives(TRG_FAN,2,@vrt,sizeof(TScrPoint));
end;

procedure TBasicPainter.DrawParticles(x, y: integer; data: PParticle;
  count: integer; tex: TTexture; size: integer; zDist: single);
type
 PartArr=array[0..100] of TParticle;
 VertexArray=array[0..100] of TScrPoint;
var
 vrt:^VertexArray;
 idx:array of integer;  // массив индексов партиклов (сортировка по z)
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
 if NeedSort then // сортировка (в будущем заменить на quicksort)
  for i:=0 to count-2 do begin
   n:=i; minZ:=part[idx[n]].z;
   for j:=i+1 to count-1 do
    if part[idx[j]].z<minZ then begin n:=j; minZ:=part[idx[n]].z; end;
   j:=idx[i];
   idx[i]:=idx[n];
   idx[n]:=j;
  end;
 // заполним вершинный буфер
 vrt:=LockBuffer(VertBuf,0,4*count*sizeof(TScrPoint));
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
  ConvertColor(color);
  // первая вершина
  with vrt[i*4] do begin
   x:=sx-rx+qx;
   y:=sy-ry+qy;
   z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
   u:=uStart; v:=vStart;
  end;
  // вторая вершина
  with vrt[i*4+1] do begin
   x:=sx+rx+qx;
   y:=sy+ry+qy;
   z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
   u:=uStart+uSize; v:=vStart;
  end;
  // третья вершина
  with vrt[i*4+2] do begin
   x:=sx+rx-qx;
   y:=sy+ry-qy;
   z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
   u:=uStart+uSize; v:=vStart+vSize;
  end;
  // четвертая вершина
  with vrt[i*4+3] do begin
   x:=sx-rx-qx;
   y:=sy-ry-qy;
   z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
   u:=uStart; v:=vStart+vSize;
  end;
 end;
 UnlockBuffer(VertBuf);
 DrawIndexedPrimitives(TRG_LIST,VertBuf,partIndBuf,sizeof(TScrPoint),0,count*4,0,count*2);
end;

procedure TBasicPainter.DebugScreen1;
begin
 TextOut(MAGIC_TEXTCACHE,100,0,0,'');
end;

procedure TBasicPainter.DrawBand(x,y:integer;data:PParticle;count:integer;tex:TTexture;r:TRect);
type
 PartArr=array[0..100] of TParticle;
 VertexArray=array[0..100] of TScrPoint;
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
 vrt:=LockBuffer(VertBuf,0,2*count*sizeof(TScrPoint));
 idx:=LockBuffer(bandIndBuf,0,6*count*2);
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
   ConvertColor(color);
   // первая вершина
   with vrt[i*2] do begin
     x:=sx-rx;
     y:=sy-ry;
     z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
     u:=u1; v:=v1+vStep*(part[i].index and $FF);
   end;
   // вторая вершина
   with vrt[i*2+1] do begin
     x:=sx+rx;
     y:=sy+ry;
     z:=zPlane; rhw:=1; diffuse:=color; specular:=0;
     u:=u2; v:=v1+vStep*(part[i].index and $FF);
   end;
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
   idx^:=i*2; inc(idx);
   idx^:=i*2+1; inc(idx);
   idx^:=next*2; inc(idx);
   // первый треугольник - (2,1,3)
   idx^:=next*2; inc(idx);
   idx^:=i*2+1; inc(idx);
   idx^:=next*2+1; inc(idx);
   inc(primcount,2);
 end;

 UnlockBuffer(BandIndBuf);
 UnlockBuffer(VertBuf);
 DrawIndexedPrimitives(TRG_LIST,VertBuf,bandIndBuf,sizeof(TScrPoint),0,count*2,0,primCount);
end;

{procedure TBasicPainter.ScreenOffset(x, y: integer);
begin
 permOfsX:=x; curOfsX:=x;
 permOfsY:=y; curOfsY:=y;
end;}

procedure TBasicPainter.SetClipping(r: TRect);
begin
 if scnt>=15 then exit;
 inc(scnt);
 saveclip[scnt]:=cliprect;
 if IntersectRects(cliprect,r,cliprect)=0 then begin // no intersection
  cliprect:=types.Rect(-1,-1,-1,-1);
 end;
end;

procedure TBasicPainter.ResetClipping;
begin
 if scnt<=0 then exit;
 cliprect:=saveclip[scnt];
 dec(scnt);
end;


procedure TBasicPainter.FlushTextCache;
begin
 if (vertBufUsage=0) and (textBufUsage=0) then exit;
    
 UseTexture(textCache);
 if vertBufUsage>0 then begin
   DrawPrimitivesFromBuf(TRG_LIST,vertBufUsage div 3,0,VertBuf,sizeof(TScrPoint));
   vertBufUsage:=0;
 end;
 if textBufUsage>0 then begin
   DrawIndexedPrimitives(TRG_LIST,textVertBuf,partIndBuf,sizeof(TScrPoint),0,textBufUsage,0,textBufUsage div 2);
   textBufUsage:=0;
 end;
end;

function TBasicPainter.LoadFont(fName:string;asName:string=''):string;
var
 font:ByteArray;
 {$IFDEF FREETYPE}
 ftf:TFreeTypeFont;
 i:integer;
 {$ENDIF}
begin
 if pos('.fnt',fname)>0 then begin
  font:=LoadFileAsBytes(FileName(fname));
  result:=LoadFont(font,asName);
 end else begin
  {$IFDEF FREETYPE}
  ftf:=TFreeTypeFont.LoadFromFile(FileName(fname));
  for i:=1 to 32 do
   if newFonts[i]=nil then begin
    newFonts[i]:=ftf;
    if asName<>'' then ftf.faceName:=asName;
    result:=ftf.faceName;
    exit;
   end;
  {$ENDIF}
 end;
end;

function TBasicPainter.LoadFont(font:array of byte;asName:string=''):string;
var
 i:integer;
begin
 for i:=1 to 32 do
  if newFonts[i]=nil then begin
   newFonts[i]:=TUnicodeFontEx.LoadFromMemory(font,true);
   if asName<>'' then TUnicodeFontEx(newFonts[i]).header.fontName:=asName;
   result:=TUnicodeFontEx(newFonts[i]).header.FontName;
   exit;
  end;
end;

function TBasicPainter.GetFont(name:string;size:single=0.0;flags:integer=0;effects:byte=0):cardinal;
var
 i,best,rate,bestRate,matchRate:integer;
 realsize:single;
begin
 best:=0; bestRate:=0;
 realsize:=size;
 matchRate:=800;
 name:=lowercase(name);
 if flags and fsStrictMatch>0 then matchRate:=10000;
 // Browse
 for i:=1 to 32 do
  if newFonts[i]<>nil then begin
   rate:=0;
   if newFonts[i] is TUnicodeFont then
    with newFonts[i] as TUnicodeFont do begin
     if lowercase(header.FontName)=name then rate:=matchRate;
     rate:=rate+round(3000-1000*(0.1*header.width/realsize+realsize/(0.1*header.width)));
     if rate>bestRate then begin
      bestRate:=rate;
      best:=i;
     end;
    end;
   {$IFDEF FREETYPE}
   if newFonts[i] is TFreeTypeFont then
    with newFonts[i] as TFreeTypeFont do begin
     if lowercase(faceName)=name then rate:=matchRate*2;
     if rate>best then begin
       bestRate:=rate;
       best:=i;
     end;
    end;
   {$ENDIF}
  end;
 // Fill the result
 if best>0 then begin
  if newFonts[best] is TUnicodeFont then begin
   if realsize>0 then
    result:=best+round(100*realsize/(0.1*TUnicodeFont(newFonts[best]).header.width)) shl 16
   else
    result:=best+100 shl 16;
  end else
  if newFonts[best] is TFreeTypeFont then begin
   result:=best+round(100*size/20) shl 16; // Масштаб - в процентах относительно размера 20 (макс размер - 51)
   if flags and fsNoHinting>0 then result:=result or fhNoHinting;
   if flags and fsAutoHinting>0 then result:=result or fhAutoHinting;
  end
  else
   result:=0;

  if flags and fsDontTranslate>0 then result:=result or fhDontTranslate;
  if flags and fsItalic>0 then result:=result or fhItalic;
 end
  else result:=0;
end;

procedure TBasicPainter.MatchFont(legacyfont, newfont: cardinal;addY:integer=0);
begin
 if not (legacyFont in [1..32]) then exit;
 fontMatch[legacyFont]:=newFont;
 fontMatchAddY[legacyFont]:=addY;
end;

procedure TBasicPainter.SetFontOption(font:cardinal;option:cardinal;value:single);
begin
 font:=font and $FF;
 ASSERT(font>0,'Invalid font handle');
 if newfonts[font] is TUnicodeFontEx then
  case option of
   foDownscaleFactor:TUnicodeFontEx(newfonts[font]).downscaleFactor:=value;
   foUpscaleFactor:TUnicodeFontEx(newfonts[font]).upscaleFactor:=value;
   else raise EWarning.Create('SFO: invalid option');
  end;
 {$IFDEF FREETYPE}
 if newfonts[font] is TFreeTypeFont then
  case option of
   foGlobalScale:TFreeTypeFont(newFonts[font]).globalScale:=value;
  end;
 {$ENDIF}
end;


procedure TBasicPainter.SetTextTarget(buf:pointer;pitch:integer);
begin
 TextBufferBitmap:=buf;
 TextBufferPitch:=pitch;
end;

procedure TBasicPainter.SetupCamera(origin, target, up: TPoint3;
  turnCW: double);
var
 mat:TMatrix4;
 v1,v2,v3:TVector3;
begin
 v1:=Vector3(origin,target);
 Normalize3(v1);
 v2:=Vector3(origin,up);
 v3:=CrossProduct3(v2,v1);
 Normalize3(v3); // Right vector
 v2:=CrossProduct3(v3,v1); // Down vector
 mat[0,0]:=v3.x; mat[0,1]:=v3.y; mat[0,2]:=v3.z; mat[0,3]:=0;
 mat[1,0]:=v2.x; mat[1,1]:=v2.y; mat[1,2]:=v2.z; mat[1,3]:=0;
 mat[2,0]:=v1.x; mat[2,1]:=v1.y; mat[2,2]:=v1.z; mat[2,3]:=0;
 mat[3,0]:=origin.x; mat[3,1]:=origin.y; mat[3,2]:=origin.z; mat[3,3]:=1;
 Set3DView(mat);
end;


procedure TBasicPainter.BeginTextBlock;
begin
 if not textCaching then begin
  textCaching:=true;
 end;
end;

procedure TBasicPainter.EndTextBlock;
begin
 FlushTextCache;
 textCaching:=false;
end;

function TBasicPainter.TextWidth(font:cardinal;st:AnsiString):integer;
begin
 result:=TextWidthW(font,DecodeUTF8(st));
end;

function TBasicPainter.TextWidthW(font:cardinal;st:wideString):integer;
var
 width:integer;
 obj:TObject;
 uniFont:TUnicodeFontEx;
 ftFont:TFreeTypeFont;
 scale:byte;
begin
 if length(st)=0 then begin       
  result:=0; exit;
 end;
 scale:=(font shr 16) and $FF;
 if scale=0 then scale:=100;
 obj:=newFonts[font and $1F];
 if obj is TUnicodeFont then begin
  unifont:=obj as TUnicodeFontEx;
  width:=uniFont.GetTextWidth(st);
  if (scale>=unifont.downscaleFactor*100) and
     (scale<=unifont.upscaleFactor*100) then scale:=100;
  result:=round(0.01*width*scale);
  exit;
 end else
 {$IFDEF FREETYPE}
 if obj is TFreeTypeFont then begin
  ftFont:=obj as TFreeTypeFont;
  result:=ftFont.GetTextWidth(st,20*scale/100);
  exit;
 end else
 {$ENDIF}
  raise EWarning.Create('GTW 1');
end;

procedure TBasicPainter.UseCustomShader;
begin
end;

function TBasicPainter.FontHeight(font:cardinal):integer;
var
 uniFont:TUnicodeFontEx;
 ftFont:TFreeTypeFont;
 scale:byte;
 obj:TObject;
begin
 ASSERT(font<>0);
 obj:=newFonts[font and $FF];
 scale:=(font shr 16) and $FF;
 if scale=0 then scale:=100;
 if obj is TUnicodeFont then begin
  unifont:=obj as TUnicodeFontEx;
  if (scale>=unifont.downscaleFactor*100) and
     (scale<=unifont.upscaleFactor*100) then scale:=100;
  result:=round(uniFont.GetHeight*scale/100);
  exit;
 end else
 {$IFDEF FREETYPE}
 if obj is TFreeTypeFont then begin
  ftFont:=obj as TFreeTypeFont;
  result:=ftFont.GetHeight(20*scale/100);
 end else
 {$ENDIF}
  raise EWarning.Create('FH 1');
end;

type
 // what should be updated on the glyph cache
 TGlyphUpdateRecord=record
  pnt:TPoint; // target location
  width,height:integer; // glyph size
  data:pointer; // glyph bitmap data
 end;

procedure TBasicPainter.TextOut(font:cardinal;x,y:integer;color:cardinal;st:AnsiString;
   align:TTextAlignment=taLeft;options:integer=0;targetWidth:integer=0;query:cardinal=0);
begin
 TextOutW(font,x,y,color,DecodeUTF8(st),align,options,targetWidth,query);
end;   


procedure TBasicPainter.TextOutW(font:cardinal;x,y:integer;color:cardinal;st:widestring;
   align:TTextAlignment=taLeft;options:integer=0;targetWidth:integer=0;query:cardinal=0);
var
 width:integer; //text width in pixels
 uniFont:TUnicodeFontEx;
 ftFont:TFreeTypeFont;
 ftHintMode:integer;
 scale,size,spacing,charScaleX,charScaleY,charSpacing,spaceSpacing:single;
 stepU,stepV:single;
 chardata:cardinal;
 updList:array[1..20] of TRect;
 updCount:integer;
 drawToBitmap:boolean;
 italicStyle,underlineStyle,boldStyle:boolean;
 link:cardinal;
 linkStart,linkEnd:integer; // x position for link rect
 queryX,queryY:integer;

 // For complex text
 stack:array[0..7,0..31] of cardinal; // стек текущих атрибутов (0 - дефолтное значение)
 stackPos:array[0..7] of integer; // указатель на свободный элемент в стеке
 cmdList:array[0..127] of cardinal; // bits 0..7 - what to change, bits 8..9= 0 - clear, 1 - set, 2 - pop    
 cmdIndex:array of byte; // total number of commands that must be executed before i-th character
 // Underlined
 linePoints:array[0..63] of TPoint2; // x,y
 lineColors:array[0..31] of cardinal;
 lpCount:integer;

 // Fills cmdList and cmdIndex arrays
 procedure ParseSML;
  var
   i,len,cnt,cmdPos,prefix:integer;
   res:WideString;
   tagMode:boolean;
   v:cardinal;
   vst:string[8];
  begin
   lpCount:=0;
   len:=length(st);
   SetLength(res,len);
   Setlength(cmdIndex,len+1);
   i:=1; cnt:=0; tagMode:=false;
   cmdPos:=0;
   while i<=len do begin
    if tagmode then begin
     // inside {}
     case st[i] of
      '}':tagmode:=false;
      'B','b','I','i','U','u':begin
       case st[i] of
        'B','b':v:=0;
        'I','i':v:=1;
        'U','u':v:=2;
       end;
       cmdList[cmdPos]:=prefix shl 8+v; inc(cmdPos);
      end;
      'C','c','L','l','F','f':begin
       case st[i] of
        'C','c':v:=4;
        'F','f':v:=5;
        'L','l':v:=6;
       end;
       cmdList[cmdPos]:=prefix shl 8+v; inc(cmdPos);
       if (i+2<=len) and (st[i+1]='=') then begin
        inc(i,2); vst:='';
        while (i<=len) and (st[i] in ['0'..'9','a'..'f','A'..'F']) do begin
         vst:=vst+st[i];
         inc(i);
        end;
        v:=HexToInt(vst);
        dec(i);
       end else
        v:=0;
       cmdList[cmdPos]:=v; inc(cmdPos); 
      end;
      '!':prefix:=0;
      '/':prefix:=2;
     end;
    end else begin
     // outside {}
     if (st[i]='{') and (i<len-1) and
        (st[i+1] in ['!','/','B','b','I','i','U','u','C','c','G','g','L','l','F','f']) then begin
      tagmode:=true;
      prefix:=1;
     end else begin
      inc(cnt);
      res[cnt]:=st[i];
      cmdIndex[cnt]:=cmdPos;
      // double '{{'
      if (st[i]='{') and (i<len) and (st[i+1]='{') then inc(i);
     end;
    end;
    inc(i);
   end;
   SetLength(res,cnt);
   st:=res;
  end;

 procedure Initialize;
  var
   i,numSpaces:integer;
   obj:TObject;
  begin
   // Object initialization
   uniFont:=nil; ftFont:=nil;
   obj:=newFonts[font and $3F];
   scale:=1; charScaleX:=1; charScaleY:=1;

   boldStyle:=(options and toBold>0) or (font and fsBold>0);
   italicStyle:=(options and toItalic>0) or (font and fsItalic>0);
   underlineStyle:=(options and toUnderline>0) or (font and fsUnderline>0);

   if options and toComplexText>0 then begin
    fillchar(stackPos,sizeof(stackPos),0);
    ParseSML;
    link:=0; linkStart:=-1;
   end;

   if options and toMeasure>0 then begin
    SetLength(textMetrics,length(st)+1);
    queryX:=query and $FFFF;
    queryY:=query shr 16;
   end;

   {$IFDEF FREETYPE}
   if obj is TFreeTypeFont then begin
     ftFont:=obj as TFreeTypeFont;
     size:=20/100*((font shr 16) and $FF);
     ftHintMode:=0;
     if (options and toNoHinting>0) or (font and fhNoHinting>0) then begin
       ftHintMode:=ftHintMode or FTF_NO_HINTING;
       font:=font or fhNoHinting;
     end;
     if (options and toAutoHinting>0) or (font and fhAutoHinting>0) then begin
       ftHintMode:=ftHintMode or FTF_AUTO_HINTING;
       font:=font or fhAutoHinting;
     end;
   end else
   {$ENDIF}
   if obj is TUnicodeFont then begin
     unifont:=obj as TUnicodeFontEx;
     scale:=((font shr 16) and $FF)/100;
     if scale=0 then scale:=1;
     charScaleX:=1; charScaleY:=1;
     if (scale<unifont.downscaleFactor) or
        (scale>unifont.upscaleFactor) then begin
       charScaleX:=scale; charScaleY:=scale;
     end;
   end;

   width:=0;
   charSpacing:=0; // доп интервал между обычными символами
   spaceSpacing:=0; // доп ширина пробелов
   {$IFDEF FREETYPE}
   if (options and toLetterSpacing>0) or (font and fsLetterSpacing>0) then
    if ftFont<>nil then charSpacing:=round(ftFont.GetHeight(size)*0.1);
   {$ENDIF}

   drawToBitmap:=(options and toDrawToBitmap>0);

   // Adjust color
   if textCache.PixelFormat<>ipfA8 then begin
     if not textcolorx2 and not drawToBitmap then // Convert color to FF808080 range
       color:=(color and $FF000000)+((color and $FEFEFE shr 1));
   end;
   if not DrawToBitmap then
     ConvertColor(color);

   // Alignment
   if options and toAddBaseline>0 then begin
     if uniFont<>nil then inc(y,round(uniFont.header.baseline*scale));
     {$IFDEF FREETYPE}
     if ftFont<>nil then inc(y,round(1.25+ftFont.GetHeight(size)));
     {$ENDIF}
   end;
   spacing:=0;
   numSpaces:=0;
   for i:=1 to length(st) do
     if st[i]=' ' then inc(numSpaces);

   width:=TextWidthW(font,st); // ширина надписи в реальных пикселях
   case align of
    taRight:begin
     if targetWidth>0 then x:=x+targetWidth;
     dec(x,width);
    end;
    taCenter:x:=x+(targetWidth-width) div 2;
    taJustify:if not (st[length(st)] in [#10,#13]) then begin
     i:=width;
     if i<round(targetWidth*0.95-10) then SpaceSpacing:=0
      else SpaceSpacing:=targetWidth-i;
     if numSpaces>0 then SpaceSpacing:=SpaceSpacing/numSpaces;
    end;
   end;
   {$IFDEF FREETYPE}
   if (align=taCenter) and (obj is TFreeTypeFont) then begin // при центрировании отступ игнорируется
    dec(x,ftFont.CharPadding(st[1],size));
   end;
   {$ENDIF}
  end;

 // Fills specified area in textCache with glyph image
 // Don't forget about 1px padding BEFORE glyph (mode: true=4bpp, false - 8bpp)
 procedure UnpackGlyph(x,y,width,height:integer;glyphData:PByte;mode:boolean);
  var
   tX,tY,bpp:integer;
   pixelData,pLine:PByte;
   v:byte;
  begin
   pLine:=textCache.data;
   bpp:=PixelSize[textCache.pixelFormat] div 8;
   inc(pLine,X*bpp+Y*textCache.pitch);
   fillchar(pLine^,(width+1)*bpp,0);
   for tY:=0 to Height-1 do begin
    inc(pLine,textCache.pitch);
    pixelData:=pLine;
    fillchar(pixelData^,bpp,0);
    for tX:=0 to Width-1 do begin
     inc(pixelData,bpp);
     if mode then begin
      if tX and 1=1 then begin
       v:=glyphData^ shr 4;
       inc(glyphData);
      end else
       v:=glyphData^ and $F;
      v:=v*17;
     end else begin
      v:=glyphData^;
      inc(glyphData);
     end;

     if bpp=1 then
      PByte(pixelData)^:=v
     else
     if bpp=2 then
      PWord(pixelData)^:=(v and $F0) shl 8+$FFF
     else
      PCardinal(pixelData)^:=v shl 24+$FFFFFF;
    end;
    inc(pixelData,bpp);
    fillchar(pixelData^,bpp,0);

    if mode and (width and 1=1) then inc(glyphData);
    // transparent padding (1 px)
   end;
   inc(pLine,textCache.pitch);
   fillchar(pLine^,(width+1)*bpp,0);
  end;

 // Applies bold effect to given area in textCache
 procedure MakeItBold(x,y,width,height:integer);
  var
   pLine,pixelData:PByte;
   tx,ty,bpp:integer;
   v,r,prev:integer;
  begin
   pLine:=textCache.data;
   bpp:=PixelSize[textCache.pixelFormat] div 8;
   inc(pLine,X*bpp+Y*textCache.pitch);
   for ty:=0 to height-1 do begin
    inc(pLine,textCache.pitch);
    pixelData:=pLine; prev:=0;
    inc(pixelData,bpp-1);
    for tX:=0 to Width do begin // make it 1 pixel wider
     inc(pixelData,bpp);
     v:=pixelData^;
     r:=v+prev;
     if r>255 then r:=255;
     prev:=v;
     pixelData^:=r;
    end;
   end;
  end;

 // Allocate cache space and copy glyph image to the cache texture
 // chardata - glyph image hash
 // imageWidth,imageHeight - glyph dimension
 // dX,dY - glyph relative position (for FT)
 // glyphType - 1 = 4bpp, 2 = 8bpp
 // data - pointer to glyph data
 // pitch - glyph image pitch (for 8bpp images only)
 function AllocGlyph(chardata:cardinal;imageWidth,imageHeight,dX,dY:integer;
     glyphType:integer;data:pointer;pitch:integer):TPoint;
  var
   i:integer;
   fl:boolean;
   r:TRect;
  begin
   // 1 transparent pixel in padding
   result:=glyphCache.Alloc(imageWidth+2+byte(boldStyle),imageHeight+2,dX,dY,chardata);
   if textCache.locked=0 then textCache.Lock(0,lmCustomUpdate);
   UnpackGlyph(result.x,result.Y,imageWidth,imageHeight,data,glyphType=1);
   if boldStyle then MakeItBold(result.x,result.Y,imageWidth,imageHeight);
   fl:=true;
   r:=types.Rect(result.X,result.y,result.x+imageWidth+1,result.y+imageHeight+1);
   for i:=1 to updCount do
    if updList[i].Top=result.y then begin
     UnionRect(updList[i],updList[i],r);
     fl:=false;
     break;
    end;
   if fl then begin
    inc(updCount);
    updList[updCount]:=r;
   end;
   if updCount>=High(updList) then raise EWarning.Create('Too many glyphs at once');
   inc(result.X); inc(result.Y); // padding
  end;

 // chardata - хэш для кэширования глифа (сам символ, шрифт, размер, стиль)
 // pnt - положение глифа в текстурном кэше
 // x,y - экранные координаты точки курсора
 // imageX, imageY - позиция глифа относительно точки курсора
 // imageWIdth, imageHeight - размеры глифа
 procedure AddVertices(chardata:cardinal;pnt:TPoint;x,y:integer;imageX,imageY,imageWidth,imageHeight:integer;
   var data:PScrPoint;var counter:integer);
  var
   u1,u2,v1,v2:single;
   x1,y1,x2,y2,dx1,dx2:single;
  procedure AddVertex(var data:PScrPoint;vx,vy,u,v:single;color:cardinal); inline;
   begin
    data.x:=vx;
    data.y:=vy;
    data.z:=0; data.rhw:=1;
    if @textColorFunc<>nil then
     data.diffuse:=TextColorFunc(data.x,data.y,color)
    else
     data.diffuse:=color;
    data.u:=u; data.v:=v;
    inc(data);
   end;
  begin
    u1:=pnt.X*stepU;
    u2:=(pnt.X+imageWidth)*stepU;
    v1:=pnt.Y*stepV;
    v2:=(pnt.Y+imageHeight)*stepV;

    x1:=x+imageX*charScaleX-0.5;
    x2:=x+(imageX+imageWidth)*charScaleX-0.5;
    y1:=y-imageY*charScaleY-0.5;
    y2:=y-(imageY-imageHeight)*charScaleY-0.5;
    if not italicStyle then begin
     AddVertex(data,x1,y1,u1,v1,color);
     AddVertex(data,x2,y1,u2,v1,color);
     AddVertex(data,x2,y2,u2,v2,color);
     AddVertex(data,x1,y2,u1,v2,color);
    end else begin
     // Наклон символов (faux italics)
     dx1:=(y-y1)*0.25;
     dx2:=(y-y2)*0.25;
     AddVertex(data,x1+dx1,y1,u1,v1,color);
     AddVertex(data,x2+dx1,y1,u2,v1,color);
     AddVertex(data,x2+dx2,y2,u2,v2,color);
     AddVertex(data,x1+dx2,y2,u1,v2,color);
    end;
    inc(counter);
  end;

 procedure ExecuteCmd(var cmdPos:integer);
  var
   v,cmd,idx:cardinal;
  begin
   v:=cmdList[cmdPos];
   idx:=v and 15;
   cmd:=v shr 8;
   if cmd<2 then begin
    // push and set new value
    case idx of
     0:v:=byte(boldStyle);
     1:v:=byte(italicStyle);
     2:v:=byte(underlineStyle);
     4:v:=color;
     6:v:=link;
    end;
    stack[idx,stackPos[idx]]:=v;
    inc(stackPos[idx]);
    if idx>=4 then begin
     inc(cmdPos);
     v:=cmdList[cmdPos];
    end;
    case idx of
     0:boldStyle:=(cmd=1);
     1:italicStyle:=(cmd=1);
     2:underlineStyle:=(cmd=1);
     4:begin color:=v; ConvertColor(color); end;
     6:begin
        link:=v;
        stack[2,stackpos[2]]:=byte(underlineStyle);
        inc(stackpos[2]);
        stack[4,stackpos[4]]:=color;
        inc(stackpos[4]);
        if @textLinkStyleProc<>nil then begin
         if colorFormat=1 then ConvertColor(color);
         textLinkStyleProc(link,underlineStyle,color);
         if colorFormat=1 then ConvertColor(color);
        end;
       end;
    end;
   end else begin
    // pop value
    if stackPos[idx]>0 then dec(stackPos[idx]);
    v:=stack[idx,stackpos[idx]];
    case idx of
     0:boldStyle:=(v<>0);
     1:italicStyle:=(v<>0);
     2:underlineStyle:=(v<>0);
     4:color:=v;
     6:begin link:=v;
        if stackpos[4]>0 then dec(stackpos[4]);
        color:=stack[4,stackPos[4]];
        if stackpos[2]>0 then dec(stackpos[2]);
        underlineStyle:=stack[2,stackPos[2]]<>0;
       end;
    end;
   end;
   inc(cmdPos);
  end;

 procedure BuildVertexData;
  var
   i,cnt,idx:integer;
   dx,dy,imgW,imgH,pitch,line:integer;
   px,advance:single;
   data:PScrPoint;
   chardata:cardinal; //
   gl:TGlyphInfoRec;
   pnt:TPoint;
   pb:PByte;
   fl,oldUL:boolean;
   oldColor,oldLink:cardinal;
   cmdPos:integer;
   fHeight:integer;
//   v:cardinal;
  begin
   px:=x; // координата в реальных экранных пикселях
   if options and toMeasure>0 then begin
    fHeight:=round(FontHeight(font)*1.1);
    textMetrics[0]:=types.Rect(x,y-fHeight,x+1,y);
   end;
   cnt:=0;
   updCount:=0;
   cmdPos:=0;
   lpCount:=0;
   dx:=0; dy:=0;
   data:=LockBuffer(TextVertBuf,textBufUsage,length(st)*4*sizeof(TScrPoint));
   try
   {$IFDEF FREETYPE}
   if ftFont<>nil then ftFont.Lock;
   {$ENDIF}
   glyphCache.Keep;
   stepU:=textCache.stepU*2;
   stepV:=textCache.stepV*2;
   oldUL:=false; oldColor:=color;
   for i:=1 to length(st) do begin
    if st[i]=#$FEFF then continue; // Skip BOM
    // Complex text
    if options and toComplexText>0 then begin
     oldLink:=link;
     while cmdPos<cmdIndex[i] do ExecuteCmd(cmdPos);
    end;
    if (oldLink=0) and (link<>0) then linkStart:=round(px);
    // Go to next character
    if i>1 then begin
     if unifont<>nil then
      advance:=unifont.Interval(st[i-1],st[i])*charScaleX
     {$IFDEF FREETYPE}
     else
     if ftFont<>nil then
      advance:=ftFont.Interval(st[i-1],st[i],size)
     {$ENDIF} ;
     px:=px+advance+charSpacing;
     if st[i-1]=' ' then px:=px+spaceSpacing;
     // Metrics
     if options and toMeasure>0 then begin
      textMetrics[i-1]:=types.Rect(round(px),y-fHeight,round(px)+1,y);
      if i>1 then textMetrics[i-2].Right:=round(px)-1;
      if (oldLink<>0) and
         (queryX>=textMetrics[i-2].left) and (queryX<px) and
         (queryY<y+fHeight shr 1) and (queryY>=y-fHeight) then begin
       curTextLink:=oldLink;
       curTextLinkRect.Left:=linkStart;
       curTextLinkRect.Right:=-1;
       curTextLinkRect.Top:=y-fHeight;
       curTextLinkRect.Bottom:=y+fHeight shr 1;
      end;
     end;
    end;
    if (oldLink<>0) and (link=0) and
       (curTextLinkRect.left>=0) and (curTextLinkRect.Right<0) then curTextLinkRect.Right:=round(px);
    // Underline support
    if (underlineStyle<>oldUL) or (underlineStyle and (oldColor<>color)) then begin
     linePoints[lpCount].x:=round(px);
     linePoints[lpCount].y:=y+2;
     if underlineStyle then
      lineColors[lpCount shr 1]:=color;
     inc(lpCount);
     if oldUL and underlineStyle then begin
      linePoints[lpCount].x:=round(px);
      linePoints[lpCount].y:=y+2;
      if underlineStyle then lineColors[lpCount shr 1]:=color;
      inc(lpCount);
     end else
      oldUL:=underlineStyle;
     oldColor:=color;
     if lpCount>=high(linePoints) then dec(lpCount,2);
    end;

    if (st[i]=#32) or (options and toDontDraw>0) then continue; // space -> no glyph => skip drawing

    if uniFont<>nil then begin // Unicode raster font
     idx:=unifont.IndexOfChar(st[i]);
     with unifont.chars[idx] do
      if imageWidth>0 then begin // char has glyph image
       chardata:=word(st[i])+font shl 16;
       gl:=glyphCache.Find(chardata);
       inc(gl.x); inc(gl.y); // padding
       if gl.x=0 then
        pnt:=AllocGlyph(charData,imageWidth,imageHeight,0,0,1,@unifont.glyphs[offset],0)
       else
        pnt:=Point(gl.x,gl.y);
       AddVertices(chardata,pnt,round(px),y,imageX,imageY,imageWidth,imageHeight,data,cnt);
      end;
    end
    {$IFDEF FREETYPE}
    else
    if ftFont<>nil then begin     // FreeType font
     fl:=false; // does glyph exist for this symbol?
     // find glyph image location in cache
     chardata:=word(st[i])+(font and $3F) shl 16+(font and $FF0F00) shl 8+byte(boldStyle) shl 23;
     gl:=glyphCache.Find(chardata);
     inc(gl.x); inc(gl.y); // padding
     if gl.x=0 then begin // glyph is not cached
      pb:=ftFont.RenderGlyph(st[i],size,ftHintMode,dx,dy,imgW,imgH,pitch);
      if pb<>nil then begin
       pnt:=AllocGlyph(charData,imgW,imgH,dx,dy,2,pb,pitch);
       fl:=true;
      end;
     end else begin
      // glyph is cached
      pnt:=Point(gl.x,gl.y);
      imgW:=gl.width-2;
      imgH:=gl.height-2;
      dx:=gl.dx;
      dy:=gl.dy;
      fl:=true;
     end;
     if i=1 then px:=px-dx; // remove any x-padding for the 1-st character
     if fl then
      AddVertices(chardata,pnt,round(px),y,dX,dY,imgW,imgH,data,cnt);
    end
    {$ENDIF};
   end; // FOR

   // Metrics
   if options and toMeasure>0 then begin
    i:=round(px)+dx+imgW;
    textMetrics[length(st)]:=types.rect(i,y-fHeight,i,y);
    if (link>0) and
       (queryX>=textMetrics[length(st)-1].left) and (queryX<px+dx+imgW) and
       (queryY<y+fHeight shr 1) and (queryY>=y-fHeight) then begin
      curTextLink:=oldLink;
      curTextLinkRect.Left:=linkStart;
      curTextLinkRect.Right:=round(px+dx+imgW-1);
      curTextLinkRect.Top:=y-fHeight;
      curTextLinkRect.Bottom:=y+fHeight shr 1;
    end;
   end;

   if (curTextLinkRect.Left>=0) and (curTextLinkRect.Right<0) then curTextLinkRect.Right:=round(px+dx+imgW); 

   // last underline
   if lpCount and 1=1 then begin
    linePoints[lpCount].x:=round(px+dx+imgW);
    linePoints[lpCount].y:=y+2;
    inc(lpCount);
   end;

   for i:=1 to updCount do
    textCache.AddDirtyRect(updList[i]);

   finally
    glyphCache.Release;
    UnlockBuffer(textVertBuf);
    if textCache.locked>0 then textCache.Unlock;
    {$IFDEF FREETYPE}
    if ftFont<>nil then ftFont.Unlock;
    {$ENDIF}
   end;
   inc(textBufUsage,4*cnt);
  end;

 function DefineRectAndSetState:boolean;
  var
   r:TRect;
//   mode:byte;
   height:integer;
  begin
   if unifont<>nil then
    r:=types.Rect(x, y-unifont.header.baseline,x+width+1,y+unifont.header.baseline div 2)
   {$IFDEF FREETYPE}
   else
   if ftFont<>nil then begin
    ftFont.Lock;
    height:=ftFont.GetHeight(size);
    ftFont.Unlock;
    r:=types.Rect(x, y-height-height div 2,x+width+1,y+height div 2);
   end
   {$ENDIF} ;
   result:=SetStates(STATE_TEXTURED2X,r,textCache);
  end;

 procedure DrawUnderlines;
  var
   i:integer;
  begin
   i:=0;
   while i<lpCount do begin
    ConvertColor(lineColors[i shr 1]);
    painter.DrawLine(linePoints[i].x,linePoints[i].y,
      linePoints[i+1].x,linePoints[i+1].y,lineColors[i shr 1]);
    inc(i,2);
   end;
  end;

 procedure DrawMultiline;
  var
   i,j,lineHeight:integer;
  begin
   i:=1;
   j:=1;
   lineHeight:=round(FontHeight(font)*1.65);
   while j<length(st) do
    if (st[j]=#13) and (st[j+1]=#10) then begin
     TextOutW(font,x,y,color,copy(st,i,j-i),align,options or toDontTranslate,targetWidth,query);
     inc(y,lineHeight);
     inc(j,2);
     i:=j;
    end else
     inc(j);
   TextOutW(font,x,y,color,copy(st,i,j-i+1),align,options or toDontTranslate,targetWidth,query);
  end;

begin // -----------------------------------------------------------
  // Special value to display font cache texture
 if font=MAGIC_TEXTCACHE then begin
  FillRect(x,y,x+textCache.width,y+textCache.height,$FF000000);
  DrawImage(x,y,textCache,$FFFFFFFF); exit;
 end;
 // Empty or too long string
 if (length(st)=0) or (length(st)>1000) then exit;

 // Translation
 if (font and fhDontTranslate=0) and (options and toDontTranslate=0) then st:=translate(st);

 // Multiline?
 if pos(WideString(#13#10),st)>0 then begin
  DrawMultiline;
  exit;
 end;

 // Special option: draw twice with offset
 if options and toWithShadow>0 then begin
  options:=options xor toWithShadow;
  TextOutW(font,x+1,y+1,color and $FE000000 shr 1,st,align,options,targetWidth);
  TextOutW(font,x,y,color,st,align,options,targetWidth);
  exit;
 end;

 crSect.Enter;
 try
 // Установка переменных, коррекция параметров, выравнивание
 Initialize;

 // RENDER TO BITMAP?
 if drawToBitmap then begin
  if unifont<>nil then begin
   unifont.RenderText(textBufferBitmap,textBufferPitch,x,y,st,color,charScaleX);
   exit;
  end;
  {$IFDEF FREETYPE}
  if ftFont<>nil then begin
   ftFont.RenderText(textBufferBitmap,textBufferPitch,x,y,st,color,size,
     ftHintMode+FTF_ITALIC*byte(italicStyle));
   exit;
  end;
  {$ENDIF}
  exit;
 end;

 // NORMAL TEXT RENDERING
 if (options and toDontDraw=0) then begin
  if not DefineRectAndSetState then exit;  // Clipping (тут косяк с многострочностью)
  
  // Prevent text cache overflow
  if textBufUsage+length(st)*4>=4*MaxGlyphBufferCount then FlushTextCache;
 end;

 // Fill vertex buffer and update glyphs in cache when needed
 BuildVertexData;

 // DRAW IF NEEDED
 if not textCaching or (lpCount>0) then FlushTextCache;
 finally
  crSect.Leave;
 end;
 // Underlines
 if (lpCount>0) and (options and toDontDraw=0) then DrawUnderlines;
end;


initialization
 InitCritSect(crSect,'Painter',95);
 textLinkStyleProc:=DefaultTextLinkStyle;
finalization
 DeleteCritSect(crSect);
end.
