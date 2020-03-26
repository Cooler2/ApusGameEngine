// Copyright (C) Apus Software, 2014. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

// Wrapper for FreeType Library
{$R-}
unit FreeTypeFont;
interface
 uses MyServis,Structs,freetypeh;

const
 FTF_NO_HINTING = FT_LOAD_NO_HINTING;
 FTF_AUTO_HINTING = FT_LOAD_FORCE_AUTOHINT;
 FTF_ITALIC = $1000000;
type
 TIntervalRec=record
  ch1,ch2:WideChar;
  size,interval:smallint;
 end;
 TGlyphMetricRec=record
  ch:WideChar;
  size,value,padding:shortint;
 end;

 TFreeTypeFont=class
  face:PFT_Face;
  faceName:string;
  globalScale:single;
  constructor LoadFromMemory(data:ByteArray;index:integer=0);
  constructor LoadFromFile(fname:string;index:integer=0);
  // Flags -
  procedure RenderText(buf:pointer;pitch:integer;x,y:integer;st:WideString;color:cardinal;size:single;flags:cardinal=0);
  // The following functions MUST be wrapped in Lock/Unlock in multithreaded environment
  function Interval(ch1,ch2:WideChar;size:single):integer; // интервал между точкой начала символа ch1 и следующего за ним ch2
  function GetTextWidth(st:WideString;size:single):integer;
  function GetHeight(size:single):integer; // Height of characters like '0' or 'A'
  function CharPadding(ch:WideChar;size:single):integer; // интервал в пикселях между точкой курсора и началом фактического изображения символа
  // Text/Glyph rendering  (no any clipping!)
//  procedure DrawGlyph(buf:pointer;pitch:integer;x,y:integer;
//      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
  // производит рендер глифа, возвращает указатель на 8-бит битмапку, заполняет её размеры и положение относительно курсора в пикселах
  // изображение валидно до очередного вызова любой ф-ции отрисовки/рендера глифа
  function RenderGlyph(ch:WideChar;size:single;flags:integer;
     out dx,dy:integer;out width,height:integer;out pitch:integer):pointer;
  // Must be called in multithreaded environment to lock global font object!
  procedure Lock;
  procedure Unlock;
 private
  curSize,fontSize:single;
  intervalHash:array[0..4095] of TIntervalRec;
  glyphWidthHash:array[0..1023] of TGlyphMetricRec;
  procedure SetSize(size:single); inline;
  procedure FillGlyphMetrics(wch:WideChar;hash,size:integer);
 end;

var
 ftVersion:string;
 intervalHashMiss:cardinal;
 glyphWidthHashMiss:cardinal;


implementation
 uses SysUtils,FastGFX;

 var
  initialized:boolean=false;
  FTLibrary:PFT_Library;
  cSect:TMyCriticalSection;

{ TFreeTypeFont }

{procedure TFreeTypeFont.DrawGlyph(buf: pointer; pitch, x, y: integer;
  glyphData: pointer; glWidth, glHeight: integer; color: cardinal);
begin

end;}

function TFreeTypeFont.GetHeight(size:single): integer;
var
 s,res:integer;
begin
  if fontSize>0 then begin
   result:=round(size*fontSize+0.5);
   exit;
  end;
  Lock;
  try
  SetSize(100);
  res:=FT_Load_Char(face,$30,FT_LOAD_DEFAULT);
  if res<>0 then raise EWarning.Create('FTF: GTH: '+IntToSTr(res));
  fontSize:=((face.glyph.metrics.height+31) shr 6)/100;
  result:=round(size*fontSize+0.5);
  finally
   Unlock;
  end;
end;

procedure TFreeTypeFont.FillGlyphMetrics(wch:WideChar;hash,size:integer);
 var
  res,v:integer;
 begin
  inc(glyphWidthHashMiss);
  Lock;
  try
   res:=FT_Load_Char(face,word(wch),FT_LOAD_DEFAULT);
   if res<>0 then raise EWarning.Create('FTF: GTW 1: '+IntToSTr(res));
   with face.glyph^ do
    if wch=' ' then
     v:=(advance.x+31) shr 6
    else
     v:=(metrics.horiBearingX+metrics.width+31) shr 6;
   glyphWidthHash[hash].ch:=wch;
   glyphWidthHash[hash].size:=size;
   glyphWidthHash[hash].value:=v;
   glyphWidthHash[hash].padding:=face.glyph.metrics.horiBearingX shr 6;
  finally
   Unlock;
  end;
 end;

function TFreeTypeFont.GetTextWidth(st: WideString;size:single): integer;
var
 i,s:integer;
 wch:WideChar;
 h:integer;
 maxLineWidth,lastCharW:integer;
begin
 result:=0;
 if length(st)=0 then exit;

 maxLineWidth:=0;
 SetSize(size);
 // last char width
 wch:=st[length(st)];
 // Hashed?
 s:=round(size*4);
 h:=(word(wch)+s*47) and $3FF;
 if (glyphWidthHash[h].ch<>wch) or
    (glyphWidthHash[h].size<>s) then FillGlyphMetrics(wch,h,s);
 lastCharW:=glyphWidthHash[h].value;
 // first char padding
 wch:=st[1];
 h:=(word(wch)+s*47) and $3FF;
 if (glyphWidthHash[h].ch<>wch) or
    (glyphWidthHash[h].size<>s) then FillGlyphMetrics(wch,h,s);
 dec(result,glyphWidthHash[h].padding);

 for i:=1 to length(st)-1 do begin
  if (st[i] in [#13,#10]) then begin
   maxLineWidth:=max2(maxLineWidth,result);
   result:=0; continue;
  end;
  result:=result+Interval(st[i],st[i+1],size);
 end;
 result:=max2(maxLineWidth,result+lastCharW)-1;
end;

function TFreeTypeFont.Interval(ch1, ch2: WideChar;size:single): integer;
var
 res,gl1,gl2:integer;
 v:FT_Vector;
 h,s:integer;
begin
 // Lookup hash
 s:=round(size*4*47);
 // Как-то не особо эффективно это по памяти - хэш весьма разрежен. Но тут надо хорошенько подумать как сделать лучше
 h:=((word(ch1)*61)+word(ch2)+s) and $FFF;
 if (intervalHash[h].ch1=ch1) and
    (intervalHash[h].ch2=ch2) and
    (intervalHash[h].size=s) then begin
  result:=intervalHash[h].interval;
  exit;
 end;

 // Calculate
 Inc(intervalHashMiss);
 Lock;
 try
 SetSize(size);

 gl1:=FT_Load_Char(Face,word(ch1),0);
// if res<>0 then raise EWarning.Create('FTF: LoadChar error 2: '+IntToStr(res));
 result:=face.glyph.advance.x;
 gl2:=FT_Load_Char(face,word(ch2),0);
 res:=FT_Get_Kerning(face,gl1,gl2,0,v);
 if res<>0 then raise EWarning.Create('FTF: error 2: '+IntToStr(res));
 result:=(result+v.x+31) shr 6;

 intervalHash[h].ch1:=ch1;
 intervalHash[h].ch2:=ch2;
 intervalHash[h].size:=s;
 intervalHash[h].interval:=result;
 finally
  Unlock;
 end;
end;

function TFreeTypeFont.CharPadding(ch:WideChar;size:single):integer;
var
 h,s:integer;
begin
 SetSize(size);
 // first char padding
 s:=round(size*4);
 h:=(word(ch)+s*47) and $3FF;
 if (glyphWidthHash[h].ch<>ch) or
    (glyphWidthHash[h].size<>s) then FillGlyphMetrics(ch,h,s);
 result:=glyphWidthHash[h].padding;
end;

constructor TFreeTypeFont.LoadFromFile(fname: string;index:integer=0);
 var
  data:ByteArray;
  buf:pointer;
  err,v1,v2,v3:integer;
 begin
  Lock;
  try
  if not initialized then begin
   err:=FT_Init_FreeType(FTLibrary);
   if err<>0 then raise EWarning.Create('Failed to initialize FreeType Library, code='+IntToStr(err));
   FT_Library_Version(FTLibrary,v1,v2,v3);
   ftVersion:=IntToStr(v1)+'.'+IntToStr(v2)+'.'+IntToStr(v3);
   initialized:=true;
  end;
  LogMessage('Loading Freetype font from '+fname);
  data:=LoadFileAsBytes(fname);
  GetMem(buf,length(data));
  move(data[0],buf^,length(data));
  err:=FT_New_Memory_Face(FTLibrary,buf,length(data),index,Face);
//  err:=FT_New_Face(FTLibrary,PChar(fname),index,Face);
  if err<>0 then raise EWarning.Create('Failed to load font face, code='+IntToStr(err));
  faceName:=Face.family_name;
  fillchar(intervalHash,sizeof(intervalHash),0);
  fillchar(glyphWidthHash,sizeof(glyphWidthHash),0);
  fontSize:=0;
  globalScale:=1;
  finally
   Unlock;
  end;
{  data:=LoadFile2(fname);
  LoadFromMemory(data,index);}
 end;

constructor TFreeTypeFont.LoadFromMemory(data: ByteArray;index:integer=0);
 begin
  raise EWarning.Create('Can''t load font from memory due to libFT bugs...');
 end;

procedure TFreeTypeFont.Lock;
begin
 EnterCriticalSection(cSect);
end;

procedure TFreeTypeFont.Unlock;
begin
 LeaveCriticalSection(cSect);
end;


function TFreeTypeFont.RenderGlyph(ch: WideChar; size: single; flags:integer; out dx, dy,
  width, height: integer;out pitch:integer): pointer;
var
 err:integer;
 bitmap:^FT_Bitmap;
begin
 Lock;
 try
 SetSize(size);

 err:=FT_Load_Char(face,word(ch),FT_LOAD_RENDER+flags);
 if err<>0 then raise EWarning.Create('Failed to render char, '+IntToStr(err));
 bitmap:=@face.glyph.bitmap;
 pitch:=bitmap.pitch;
 width:=bitmap.width;
 height:=bitmap.rows;
 dx:=face.glyph.bitmap_left;
 dy:=face.glyph.bitmap_top;
 result:=bitmap.buffer;
 finally
  Unlock;
 end;
end;

procedure TFreeTypeFont.RenderText(buf: pointer; pitch, x, y: integer;
  st: WideString; color: cardinal; size: single; flags:cardinal=0);
 var
  px,py:single;
  i,err,glInd,lastGlyph:integer;
  bitmap:^FT_Bitmap;
  a:pointer;
  kerning:FT_Vector;
  mat:FT_Matrix;
 begin
  Lock;
  try
   px:=x; py:=y;
   SetSize(size);
   if flags and FTF_ITALIC>0 then begin
    mat.xx:=65536; mat.xy:=round(65536*0.2);
    mat.yx:=0; mat.yy:=65536;
    FT_Set_Transform(Face,@mat,nil);
   end;
   glInd:=-1;
   for i:=1 to length(st) do begin
    lastGlyph:=glInd;
{    err:=FT_Load_Char(Face,Word(st[i]),FT_LOAD_RENDER);
    if err<>0 then raise EWarning.Create('Failed to load glyph: '+IntToStr(err));}
    glInd:=FT_Get_Char_Index(Face,Word(st[i]));

    // Next character?
    if lastGlyph>=0 then begin
     err:=FT_Get_Kerning(Face,lastGlyph,glInd,FT_KERNING_DEFAULT,kerning);
     if err<>0 then raise EWarning.Create('FTGK error: '+IntToStr(err));
//     px:=px+(face.glyph.advance.x/64);
     px:=px+kerning.x/64;
    end;

    // Load glyph
    err:=FT_Load_Glyph(Face,glInd,flags and $FFFF);
    if err<>0 then raise EWarning.Create('Failed to load glyph: '+IntToStr(err));
    // Render glyph to 8bpp grayscale bitmap
    err:=FT_Render_Glyph(face.glyph,FT_RENDER_MODE_NORMAL);
    if err<>0 then raise EWarning.Create('Failed to render glyph: '+IntToStr(err));
    // Draw
    bitmap:=@face.glyph.bitmap;
    if (i=1) and (face.glyph.bitmap_left>0) then px:=px-face.glyph.bitmap_left;
    a:=GetPixelAddr(buf,pitch,round(px)+face.glyph.bitmap_left,round(py)-face.glyph.bitmap_top);
    BlendUsingAlpha(a,pitch,bitmap.buffer,bitmap.pitch,bitmap.width,bitmap.rows,color,blBlend);
    px:=px+(face.glyph.advance.x/64);
   end;
   FT_Set_Transform(Face,nil,nil);
  finally
   Unlock;
  end;
 end;

procedure TFreeTypeFont.SetSize(size: single);
var
 err:integer;
begin
 if (curSize<>size) and (size>0) then begin
  Lock;
  try
  err:=FT_Set_Char_Size(Face,round(size*64*globalScale),0,96,0);
  finally
   Unlock;
  end;
  if err<>0 then raise EWarning.Create('Failed to set char size: '+IntToStr(err));
  curSize:=size;
 end;
end;

initialization
 InitCritSect(cSect,'FreeType',150);
finalization
 DeleteCritSect(cSect);
end.
