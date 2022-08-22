// Text rendering
//
// Copyright (C) 2011-2021 Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.TextDraw;
interface
 uses Types, Apus.Types, Apus.Engine.API;

 const
  MAGIC_TEXTCACHE = $01FF;
  DEFAULT_FONT_DOWNSCALE = 0.93;
  DEFAULT_FONT_UPSCALE = 1.1;
  TXT_TEXTURE_8BIT = false;

  // FT-шрифты не имеют "базового" размера, поэтому scale задается относительно произвольно зафиксированного размера
  FTF_DEFAULT_LINE_HEIGHT = 24; // Высота строки, соответствующей scale=100

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

  TTextDrawer=class(TInterfacedObject,ITextDrawer)
   textMetrics:array of TRect; // results of text measurement (if requested)

   constructor Create;
   destructor Destroy; virtual;

   function LoadFont(fname:string;asName:string=''):string; overload; // возвращает имя шрифта
   function LoadFont(const font:TBuffer;asName:string=''):string; overload; // возвращает имя шрифта
   procedure SetScale(scale:single);
   function GetFont(name:string;size:single;flags:cardinal=0;effects:byte=0):TFontHandle; // возвращает хэндл шрифта
   function ScaleFont(const font:TFontHandle;scale:single):TFontHandle;
   procedure SetFontOption(handle:TFontHandle;option:cardinal;value:single);
   // Text output
   procedure Write(font:TFontHandle;x,y:single;color:cardinal;st:String8;align:TTextAlignment=taLeft;
      options:integer=0;targetWidth:integer=0;query:cardinal=0);
   procedure WriteW(font:TFontHandle;xx,yy:single;color:cardinal;st:String16;align:TTextAlignment=taLeft;
      options:integer=0;targetWidth:integer=0;query:cardinal=0);
   // Measure text dimensions
   function Width(font:TFontHandle;st:String8):integer; // text width in pixels
   function WidthW(font:TFontHandle;st:String16):integer; // text width in pixels
   function Height(font:TFontHandle):integer; // Height of capital letters (like 'A'..'Z','0'..'9') in pixels
   function MeasuredCnt:integer;
   function MeasuredRect(idx:integer):TRect;
   // Hyperlinks
   procedure ClearLink; // Clear current link (call before text render)
   function Link:integer; // get hyperlink under mouse (filled during text render)
   function LinkRect:TRect; // get active hyperlink rect
   // Cache / misc
   procedure BeginBlock(addOptions:cardinal=0); // optimize performance when drawing multiple text entries
   procedure EndBlock;   // finish buffering and perform actual render
   // Text render target
   procedure SetTarget(buf:pointer;pitch:integer); // set system memory target for text rendering (no clipping!)
  private
   fonts:array[1..32] of TObject;

   textCaching:boolean;  // cache draw operations
   textBlockOptions:cardinal; // block-level options to add

   txtBuf:array of TVertex;
   txtInd:array of word;
   txtVertCount:integer; // number of vertices stored in textBuf

   textCache:TTexture; // texture with cached glyphs (textCacheWidth x 512, or another for new glyph cache structure)

   // Buffer for alternate text rendering
   textBufferBitmap:pointer;
   textBufferPitch:integer;
   globalScale:single;

   procedure CreateTextCache;
   procedure FlushTextCache;
  end;

 var
  maxGlyphBufferCount:integer=1000;
  // Default width (or height) for modern text cache (must be 512, 1024 or 2048)
  textCacheWidth:integer=512;
  textCacheHeight:integer=512;

  textColorFunc:TColorFunc=nil; // not thread-safe!
  textLinkStyleProc:TTextLinkStyleProc=nil; // not thread-safe!
  // Если при отрисовке текста передан запрос с координатами точки, и эта точка приходится на рисуемую ссылку -
  // то сюда записывается номер этой ссылки. Обнуляется перед отрисовкой кадра
  curTextLink:cardinal;
  curTextLinkRect:TRect;

  textDrawer:TTextDrawer;
  defaultFontHandle:cardinal; // first loaded font (unless overriden), used to substitute 0-handle

implementation
 uses Apus.MyServis,
   SysUtils,
   Apus.Colors,
   Apus.Images,
   Apus.UnicodeFont,
   Apus.GlyphCaches,
   Apus.Engine.Types,
   Apus.Engine.Graphics
   {$IFDEF FREETYPE},Apus.FreeTypeFont{$ENDIF};

const
 // Font handle flags (not affecting rendered glyphs)
 fhDontTranslate = $1000000;
 fhItalic        = $2000000;
 fhUnderline     = $4000000;
 fhBold          = $8000000;
 // Font handle flags (affecting rendered glyphs)
 fhNoHinting     = $200;
 fhAutoHinting   = $400;

type
 {$IFNDEF FREETYPE}
 TFreeTypeFont=class // stub class
 end;
 {$ENDIF}

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

  glyphCache,altGlyphCache:TGlyphCache;

procedure DefaultTextLinkStyle(link:cardinal;var sUnderline:boolean;var color:cardinal);
 begin
  sUnderline:=true;
  if link=curTextLink then begin
   color:=ColorAdd(color,$604030);
  end;
 end;

function ScaleFromHandle(font:TFontHandle):single;
 var
  b:byte;
 begin
  b:=(font shr 16) and $FF;
  if b=0 then exit(1.0);
  result:=sqr((b+30)/100);
 end;

procedure EncodeScale(scale:single;var font:TFontHandle);
 var
  b:byte;
 begin
  scale:=Clamp(sqrt(scale),0.31,2.85);
  b:=round(scale*100)-30;
  font:=(font and $FF00FFFF)+b shl 16;
 end;

{ TTextDrawer }

procedure TTextDrawer.FlushTextCache;
 begin
  if txtVertCount=0 then exit;
  shader.UseTexture(textCache);
  if txtVertCount>0 then begin
    renderDevice.DrawIndexed(TRG_LIST,txtBuf,txtInd,TVertex.layoutTex,
      0,txtVertCount, 0,txtVertCount div 2);
    txtVertCount:=0;
  end;
 end;

function TTextDrawer.LoadFont(fName:string;asName:string=''):string;
 var
  font:ByteArray;
  {$IFDEF FREETYPE}
  ftf:TFreeTypeFont;
  i:integer;
  {$ENDIF}
 begin
  if pos('.fnt',fname)>0 then begin
   font:=LoadFileAsBytes(FileName(fname));
   result:=LoadFont(TBuffer.CreateFrom(font),asName);
   exit;
  end else begin
   {$IFDEF FREETYPE}
   ftf:=TFreeTypeFont.LoadFromFile(FileName(fname));
   for i:=1 to high(fonts) do
    if fonts[i]=nil then begin
     fonts[i]:=ftf;
     if asName<>'' then ftf.faceName:=asName;
     result:=ftf.faceName;
     exit;
    end;
   {$ENDIF}
  end;
  raise EError.Create('Failed to load font: '+fname);
 end;

function TTextDrawer.Link: integer;
 begin
  result:=curTextLink;
 end;

function TTextDrawer.LinkRect: TRect;
 begin
  result:=curTextLinkRect;
 end;

function TTextDrawer.LoadFont(const font:TBuffer;asName:string=''):string;
 var
  i:integer;
 begin
  for i:=1 to high(fonts) do
   if fonts[i]=nil then begin
    fonts[i]:=TUnicodeFontEx.LoadFromMemory(font,true);
    if asName<>'' then TUnicodeFontEx(fonts[i]).header.fontName:=asName;
    result:=TUnicodeFontEx(fonts[i]).header.FontName;
    if defaultFontHandle=0 then
     defaultFontHandle:=100 shl 16+i;
    exit;
   end;
 end;

procedure TTextDrawer.SetScale(scale:single);
 begin
  globalScale:=scale;
 end;

function TTextDrawer.GetFont(name:string;size:single;flags:cardinal=0;effects:byte=0):cardinal;
 var
  i,best,rate,bestRate,matchRate:integer;
  realsize,scale:single;
 begin
  ASSERT(size>0);
  best:=0; bestRate:=0;
  realsize:=size;
  matchRate:=800;
  name:=LowerCase(name);
  if HasFlag(flags,fsStrictMatch) then matchRate:=10000;
  if (globalScale<>1) and not HasFlag(flags,fsIgnoreScale) then size:=size*globalScale;
  // Browse
  for i:=1 to high(fonts) do
   if fonts[i]<>nil then begin
    rate:=0;
    if fonts[i] is TUnicodeFont then
     with fonts[i] as TUnicodeFont do begin
      if lowercase(header.FontName)=name then rate:=matchRate;
      rate:=rate+round(3000-1000*(0.1*header.width/realsize+realsize/(0.1*header.width)));
      if rate>bestRate then begin
       bestRate:=rate;
       best:=i;
      end;
     end;
    {$IFDEF FREETYPE}
    if fonts[i] is TFreeTypeFont then
     with fonts[i] as TFreeTypeFont do begin
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
   if fonts[best] is TUnicodeFont then begin
    if realsize>0 then
     scale:=Clamp(realsize/(0.1*TUnicodeFont(fonts[best]).header.width),0,6.5)
    else
     scale:=1;
    result:=best;
    EncodeScale(scale,result);
   end else
   if fonts[best] is TFreeTypeFont then begin
    result:=best;
    EncodeScale(size/20,result); // Масштаб - в процентах относительно размера 20 (макс размер - 51)
    if flags and fsNoHinting>0 then result:=result or fhNoHinting;
    if flags and fsAutoHinting>0 then result:=result or fhAutoHinting;
   end
   else
    result:=0;

   if flags and fsDontTranslate>0 then result:=result or fhDontTranslate;
   if flags and fsItalic>0 then result:=result or fhItalic;
   if flags and fsBold>0 then result:=result or fhBold;
  end
   else result:=0;
 end;

procedure TTextDrawer.SetFontOption(handle:TFontHandle;option:cardinal;value:single);
 begin
  handle:=handle and $FF;
  ASSERT(handle>0,'Invalid font handle');
  if fonts[handle] is TUnicodeFontEx then
   case option of
    foDownscaleFactor:TUnicodeFontEx(fonts[handle]).downscaleFactor:=value;
    foUpscaleFactor:TUnicodeFontEx(fonts[handle]).upscaleFactor:=value;
    else raise EWarning.Create('SFO: invalid option');
   end;
  {$IFDEF FREETYPE}
  if fonts[handle] is TFreeTypeFont then
   case option of
    foGlobalScale:TFreeTypeFont(fonts[handle]).globalScale:=value;
   end;
  {$ENDIF}
 end;

function TTextDrawer.ScaleFont(const font:TFontHandle;scale:single):TFontHandle;
 var
  s,size:single;
  obj:TObject;
 begin
  s:=ScaleFromHandle(font);
  obj:=fonts[font and $FF];
  if obj is TFreeTypeFont then begin
   result:=font;
   EncodeScale(s*scale,result);
  end else
  if obj is TUnicodeFont then begin
   size:=s*TUnicodeFont(obj).header.width/10;
   result:=GetFont(TUnicodeFont(obj).header.FontName,size*scale);
  end else
   raise EWarning.Create('Not implemented for '+obj.ClassName);
 end;

procedure TTextDrawer.SetTarget(buf:pointer;pitch:integer);
 begin
  TextBufferBitmap:=buf;
  TextBufferPitch:=pitch;
 end;

procedure TTextDrawer.BeginBlock(addOptions:cardinal=0);
 begin
  if not textCaching then begin
   textCaching:=true;
   textBlockOptions:=addOptions;
  end;
 end;

procedure TTextDrawer.ClearLink;
 begin
  curTextLink:=0;
 end;

constructor TTextDrawer.Create;
 var
  i:integer;
  pw:^word;
 begin
  globalScale:=1.0;
  textDrawer:=self;
  textCache:=nil;
  txt:=self;

  SetLength(txtBuf,4*MaxGlyphBufferCount);
  SetLength(txtInd,6*MaxGlyphBufferCount);
  pw:=@txtInd[0];
  for i:=0 to MaxGlyphBufferCount-1 do begin
   pw^:=i*4; inc(pw);
   pw^:=i*4+1; inc(pw);
   pw^:=i*4+2; inc(pw);
   pw^:=i*4; inc(pw);
   pw^:=i*4+2; inc(pw);
   pw^:=i*4+3; inc(pw);
  end;

  txtVertCount:=0;
  textCaching:=false;
 end;

destructor TTextDrawer.Destroy;
 begin

 end;

procedure TTextDrawer.CreateTextCache;
 var
  i,w:integer;
  format:TImagePixelFormat;
 begin
  // Adjust text cache texture size
  i:=gfx.target.width*gfx.target.height; // screen pixels
  if i>2500000 then textCacheHeight:=max2(textCacheHeight,1024);
  if i>3500000 then textCacheWidth:=max2(textCacheWidth,1024);
  //if i>5500000 then textCacheHeight:=max2(textCacheHeight,2048);
  if TXT_TEXTURE_8BIT then format:=ipfA8
   else format:=ipfARGB;
  textCache:=AllocImage(textCacheWidth,textCacheHeight,format,aiTexture,'textCache');
  if format=ipfARGB then textCache.Clear($808080);
  LogMessage('TextCache: %d x %d, %s',[textCacheWidth,textCacheHeight,PixFmt2Str(format)]);

  w:=textCacheWidth div 8+textCacheWidth div 16;
  if glyphCache=nil then glyphCache:=TDynamicGlyphCache.Create(textCacheWidth-w,textCacheHeight);
  if altGlyphCache=nil then begin
   altGlyphCache:=TDynamicGlyphCache.Create(w,textCacheHeight);
   altGlyphCache.relX:=textCacheWidth-w;
  end;
 end;

procedure TTextDrawer.EndBlock;
 begin
  FlushTextCache;
  textCaching:=false;
 end;

function TTextDrawer.MeasuredCnt:integer;
 begin
  result:=length(textMetrics);
 end;

function TTextDrawer.MeasuredRect(idx:integer):TRect;
 begin
  result:=textMetrics[clamp(idx,0,high(textMetrics))];
 end;

function TTextDrawer.Width(font:cardinal;st:string8):integer;
 begin
  result:=WidthW(font,DecodeUTF8(st));
 end;

function TTextDrawer.WidthW(font:cardinal;st:string16):integer;
 var
  width:integer;
  obj:TObject;
  uniFont:TUnicodeFontEx;
  ftFont:TFreeTypeFont;
  scale:single;
 begin
  if length(st)=0 then begin
   result:=0; exit;
  end;
  if font=0 then font:=defaultFontHandle;
  scale:=ScaleFromHandle(font);
  obj:=fonts[font and $1F];
  if obj is TUnicodeFont then begin
   unifont:=obj as TUnicodeFontEx;
   width:=uniFont.GetTextWidth(st);
   if (scale>=unifont.downscaleFactor) and
      (scale<=unifont.upscaleFactor) then scale:=1;
   result:=round(width*scale);
   exit;
  end else
  {$IFDEF FREETYPE}
  if obj is TFreeTypeFont then begin
   ftFont:=obj as TFreeTypeFont;
   result:=ftFont.GetTextWidth(st,20*scale);
   exit;
  end else
  {$ENDIF}
   raise EWarning.Create('GTW 1');
 end;

function TTextDrawer.Height(font:cardinal):integer;
 var
  uniFont:TUnicodeFontEx;
  ftFont:TFreeTypeFont;
  scale:single;
  obj:TObject;
 begin
  if font=0 then font:=defaultFontHandle;
  obj:=fonts[font and $FF];
  scale:=ScaleFromHandle(font);
  if obj is TUnicodeFont then begin
   unifont:=obj as TUnicodeFontEx;
   if (scale>=unifont.downscaleFactor) and
      (scale<=unifont.upscaleFactor) then scale:=1;
    result:=round(uniFont.GetHeight*scale);
   exit;
  end else
  {$IFDEF FREETYPE}
  if obj is TFreeTypeFont then begin
   ftFont:=obj as TFreeTypeFont;
   result:=ftFont.GetHeight(20*scale);
  end else
  {$ENDIF}
  raise EWarning.Create('FH 1');
 end;

procedure TTextDrawer.Write(font:cardinal;x,y:single;color:cardinal;st:string8;
   align:TTextAlignment=taLeft;options:integer=0;targetWidth:integer=0;query:cardinal=0);
 begin
  WriteW(font,x,y,color,Str16(st),align,options,targetWidth,query);
 end;


procedure TTextDrawer.WriteW(font:cardinal;xx,yy:single;color:cardinal;st:string16;
   align:TTextAlignment=taLeft;options:integer=0;targetWidth:integer=0;query:cardinal=0);
var
 x,y,ofs:integer;
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
   isColor:boolean;
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
       isColor:=v=4;
       cmdList[cmdPos]:=prefix shl 8+v; inc(cmdPos);
       if (i+2<=len) and (st[i+1]='=') then begin
        inc(i,2); vst:='';
        while (i<=len) and (st[i] in ['0'..'9','a'..'f','A'..'F']) do begin
         vst:=vst+st[i];
         inc(i);
        end;
        v:=HexToInt(vst);
        if isColor then begin
         if length(vst)=3 then begin                  // 'rgb' -> FFrrggbb
          v:=v and $F+(v and $F0) shl 4+(v and $F00) shl 8;
          v:=v or v shl 4 or $FF000000;
         end else
         if length(vst)=6 then v:=$FF000000 or v; // 'rrggbb' -> FFrrggbb, '00rrggbb' -> 00rrggbb
        end;
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
   obj:=fonts[font and $3F];
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
     size:=20*ScaleFromHandle(font);
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
     scale:=ScaleFromHandle(font);
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
{   if textCache.PixelFormat<>ipfA8 then begin
     if not drawToBitmap then // Convert color to FF808080 range
       color:=(color and $FF000000)+((color and $FEFEFE shr 1));
   end;}

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

   width:=WidthW(font,st); // ширина надписи в реальных пикселях
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
   bpp:=PixelSize[textCache.pixelFormat] div 8; // 1,2 or 4 bytes per pixel in target texture
   inc(pLine,X*bpp+Y*textCache.pitch);
   if bpp<4 then
    Fillchar(pLine^,(width+1)*bpp,0)
   else
    FillDWord(pLine^,width+1,$808080);

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
      PByte(pixelData)^:=v // 8-bit alpha only texture
     else
     if bpp=2 then
      PWord(pixelData)^:=(v and $F0) shl 8+$888 // 4-4-4-4 texture
     else
      PCardinal(pixelData)^:=v shl 24+$808080; // ARGB with neutral color
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
   if not textCache.IsLocked then textCache.Lock(0,TLockMode.lmCustomUpdate);
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
   var data:PVertex;var counter:integer);
  var
   u1,u2,v1,v2:single;
   x1,y1,x2,y2,dx1,dx2:single;
  procedure AddVertex(var data:PVertex;vx,vy,u,v:single;color:cardinal); inline;
   begin
    data.x:=vx;
    data.y:=vy;
    data.z:=0; {$IFDEF DIRECTX} data.rhw:=1; {$ENDIF}
    if @textColorFunc<>nil then
     data.color:=TextColorFunc(data.x,data.y,color)
    else
     data.color:=color;
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
     4:color:=v;
     6:begin
        link:=v;
        stack[2,stackpos[2]]:=byte(underlineStyle);
        inc(stackpos[2]);
        stack[4,stackpos[4]]:=color;
        inc(stackpos[4]);
        if @textLinkStyleProc<>nil then begin
         textLinkStyleProc(link,underlineStyle,color);
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
   chardata:cardinal;
   outVertex:PVertex;
   gl:TGlyphInfoRec;
   pnt:TPoint;
   pb:PByte;
   fl,oldUL:boolean;
   oldColor,oldLink:cardinal;
   cmdPos:integer;
   fHeight:integer;
  begin
   px:=x; // координата в реальных экранных пикселях
   if options and toMeasure>0 then begin
    fHeight:=round(Height(font)*1.1);
    textMetrics[0]:=types.Rect(x,y-fHeight,x+1,y);
   end;
   cnt:=0;
   updCount:=0;
   cmdPos:=0;
   lpCount:=0;
   dx:=0; dy:=0;
   try
   {$IFDEF FREETYPE}
   if ftFont<>nil then ftFont.Lock;
   {$ENDIF}
   glyphCache.Keep;
   stepU:=textCache.stepU*2;
   stepV:=textCache.stepV*2;
   oldUL:=false; oldColor:=color;
   outVertex:=@txtBuf[txtVertCount];
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
       AddVertices(chardata,pnt,round(px),y,imageX,imageY,imageWidth,imageHeight,outVertex,cnt);
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
      AddVertices(chardata,pnt,round(px),y,dX,dY,imgW,imgH,outVertex,cnt);
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
      curTextLink:=link;
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
    if textCache.IsLocked then textCache.Unlock;
    {$IFDEF FREETYPE}
    if ftFont<>nil then ftFont.Unlock;
    {$ENDIF}
   end;
   inc(txtVertCount,4*cnt);
  end;

 function DefineRectAndSetState:boolean;
  var
   r:TRect;
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
   {$ENDIF};
   if not clippingAPI.Prepare(r) then exit(false);

   if TXT_TEXTURE_8BIT then
    shader.TexMode(0,tblKeep,tblReplace)
   else
    shader.TexMode(0,tblModulate2x,tblModulate);
   result:=true;
  end;

 procedure DrawUnderlines;
  var
   i:integer;
  begin
   i:=0;
   while i<lpCount do begin
    draw.Line(linePoints[i].x,linePoints[i].y,
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
   lineHeight:=round(Height(font)*1.65);
   while j<length(st) do
    if (st[j]=#13) and (st[j+1]=#10) then begin
     WriteW(font,x,y,color,copy(st,i,j-i),align,options or toDontTranslate,targetWidth,query);
     inc(y,lineHeight);
     inc(j,2);
     i:=j;
    end else
     inc(j);
   WriteW(font,x,y,color,copy(st,i,j-i+1),align,options or toDontTranslate,targetWidth,query);
  end;

begin // -----------------------------------------------------------
 if textCache=nil then CreateTextCache;
 x:=SRound(xx); y:=SRound(yy);
 // Special value to display font cache texture
 if font=MAGIC_TEXTCACHE then begin
  draw.FillRect(x,y,x+textCache.width,y+textCache.height,$FF000000);
  draw.Image(x,y,textCache,$FFFFFFFF);
  exit;
 end;

 if textCaching then options:=options or textBlockOptions;

 if font=0 then font:=game.defaultFont;
 // Empty or too long string
 if (length(st)=0) or (length(st)>1000) then exit;

 // Translation
 if (font and fhDontTranslate=0) and (options and toDontTranslate=0) then st:=translate(String16(st));

 // Multiline?
 if pos(String16(#13#10),st)>0 then begin
  DrawMultiline;
  exit;
 end;

 // Special option: draw twice with offset
 if options and toWithShadow>0 then begin
  options:=options xor toWithShadow;
  ofs:=Max2(1,round(Height(font)/12));
  WriteW(font,x+ofs,y+ofs,color and $FE000000 shr 1,st,align,options,targetWidth);
  WriteW(font,x,y,color,st,align,options,targetWidth);
  exit;
 end;

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
  if txtVertCount+length(st)*4>=4*MaxGlyphBufferCount then FlushTextCache;
 end;

 // Fill vertex buffer and update glyphs in cache when needed
 BuildVertexData;

 // DRAW IF NEEDED
 if not textCaching or (lpCount>0) then FlushTextCache;

 // Underlines
 if (lpCount>0) and (options and toDontDraw=0) then DrawUnderlines;
end;

{ TUnicodeFontEx }
procedure TUnicodeFontEx.InitDefaults;
 begin
  inherited;
  downscaleFactor:=DEFAULT_FONT_DOWNSCALE;
  upscaleFactor:=DEFAULT_FONT_UPSCALE;
 end;

initialization
 textLinkStyleProc:=DefaultTextLinkStyle;
end.
