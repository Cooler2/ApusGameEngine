// Copyright (C) Apus Software, 2014. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

// Wrapper for FreeType Library
{$R-}
unit Apus.FreeTypeFont;
interface
uses Apus.Core, Apus.Types, Apus.Structs, freetypeh;

const
  FTF_NO_HINTING = FT_LOAD_NO_HINTING;
  FTF_AUTO_HINTING = FT_LOAD_FORCE_AUTOHINT;
  FTF_ITALIC = $1000000;
type
  TIntervalRec=record
    ch1,ch2:Char32;
    size,interval:integer;
  end;
  TGlyphMetricRec=record
    ch:Char32;
    size,value,padding:integer;
  end;

  TFreeTypeFont=class
    face:PFT_Face;
    faceName:string;
    globalScale:single;
    constructor LoadFromMemory(const data:TBuffer;faceIndex:integer=0);
    constructor LoadFromFile(fname:string;faceIndex:integer=0);
    destructor Destroy; override;
    // Flags -
    procedure RenderText(buf:pointer;pitch:integer;x,y:integer;st:String32;color:cardinal;size:single;flags:cardinal=0);
    // TODO: document or redesign the synchronization contract; the class currently
    // relies on a global lock and RenderGlyph still returns borrowed bitmap data.
    function Interval(ch1,ch2:Char32;size:single):integer; // spacing between start point of ch1 and the next ch2
    function GetTextWidth(st:String32;size:single):integer;
    function GetHeight(size:single):integer; // Height of characters like '0' or 'A'
    function CharPadding(ch:Char32;size:single):integer; // spacing in pixels between cursor point and actual glyph image start
    // Text/Glyph rendering  (no any clipping!)
    //  procedure DrawGlyph(buf:pointer;pitch:integer;x,y:integer;
    //      glyphData:pointer;glWidth,glHeight:integer;color:cardinal);
    // Render glyph and return pointer to 8-bit bitmap; fills its size and glyph
    // position relative to cursor in pixels. The image remains valid only until
    // the next glyph render/draw call on the same shared FreeType state.
    function RenderGlyph(ch:Char32;size:single;flags:integer;
       out dx,dy:integer;out width,height:integer;out pitch:integer):pointer;
   private
    fontData:ByteArray;
    curSize,fontSize:single;
    intervalHash:array[0..4095] of TIntervalRec;
    glyphWidthHash:array[0..1023] of TGlyphMetricRec;
    procedure SetSize(size:single);
    procedure FillGlyphMetrics(wch:Char32;hash,size:integer);
  end;

var
  freetypeVersion:string;
  intervalHashMiss:cardinal;
  glyphWidthHashMiss:cardinal;


implementation
 uses SysUtils, Apus.Conv, Apus.Log, Apus.FastGFX, Apus.Threads, Apus.Files;

 var
  initialized:boolean=false;
  FTLibrary:PFT_Library;
  cSect:TLock;

procedure InitFT;
var
  err,v1,v2,v3:integer;
begin
  if initialized then exit;
  err:=FT_Init_FreeType(FTLibrary);
  if err<>0 then
    raise EWarning.Create('Failed to initialize FreeType Library, code=%d', [err]);
  FT_Library_Version(FTLibrary,v1,v2,v3);
  freetypeVersion:=Conv.ToStr(v1)+'.'+Conv.ToStr(v2)+'.'+Conv.ToStr(v3);
  Log.Msg('Freetype initialized, version '+freetypeVersion);
  initialized:=true;
end;


{ TFreeTypeFont }

{procedure TFreeTypeFont.DrawGlyph(buf: pointer; pitch, x, y: integer;
  glyphData: pointer; glWidth, glHeight: integer; color: cardinal);
begin

end;}

function TFreeTypeFont.GetHeight(size:single): integer;
var
 res:integer;
begin
  if fontSize>0 then begin
   result:=round(size*fontSize+0.5);
   exit;
  end;
  cSect.Enter;
  try
    SetSize(100);
    res:=FT_Load_Char(face,$30,FT_LOAD_DEFAULT);
    if res<>0 then
      raise EWarning.Create('FTF: GTH: '+Conv.ToStr(res));
    fontSize:=((face.glyph.metrics.height+31) shr 6)/100;
    result:=round(size*fontSize+0.5);
  finally
    cSect.Leave;
  end;
end;

procedure TFreeTypeFont.FillGlyphMetrics(wch:Char32;hash,size:integer);
var
  res,v:integer;
begin
  inc(glyphWidthHashMiss);
  cSect.Enter;
  try
    res:=FT_Load_Char(face,cardinal(wch),FT_LOAD_DEFAULT);
    if res<>0 then
      raise EWarning.Create('FTF: GTW 1: '+Conv.ToStr(res));
    with face.glyph^ do
      if wch=ord(' ') then
        v:=(advance.x+31) shr 6
      else
        v:=(metrics.horiBearingX+metrics.width+31) shr 6;
    glyphWidthHash[hash].ch:=wch;
    glyphWidthHash[hash].size:=size;
    glyphWidthHash[hash].value:=v;
    glyphWidthHash[hash].padding:=face.glyph.metrics.horiBearingX shr 6;
  finally
    cSect.Leave;
  end;
end;

function TFreeTypeFont.GetTextWidth(st:String32;size:single):integer;
var
 i,s:integer;
 wch:Char32;
 h:integer;
 maxLineWidth,lastCharW:integer;
begin
 result:=0;
 if length(st)=0 then exit;

 maxLineWidth:=0;
 SetSize(size);
 // last char width
 wch:=st[length(st)-1];
  // Hashed?
  s:=round(size*4);
  h:=(integer(wch)+s*47) and $3FF;
  if (glyphWidthHash[h].ch<>wch) or
     (glyphWidthHash[h].size<>s) then FillGlyphMetrics(wch,h,s);
  lastCharW:=glyphWidthHash[h].value;
  // first char padding
  wch:=st[0];
  h:=(integer(wch)+s*47) and $3FF;
  if (glyphWidthHash[h].ch<>wch) or
     (glyphWidthHash[h].size<>s) then FillGlyphMetrics(wch,h,s);
  dec(result,glyphWidthHash[h].padding);

  for i:=0 to length(st)-2 do begin
   if (st[i]=10) or (st[i]=13) then begin
    maxLineWidth:=max(maxLineWidth,result);
    result:=0; continue;
   end;
   result:=result+Interval(st[i],st[i+1],size);
  end;
  result:=max(maxLineWidth,result+lastCharW)-1;
end;

function TFreeTypeFont.Interval(ch1,ch2:Char32;size:single):integer;
var
 res,gl1,gl2:integer;
 v:FT_Vector;
 h,s:integer;
begin
 // Lookup hash
 s:=round(size*4*47);
 // Как-то не особо эффективно это по памяти - хэш весьма разрежен. Но тут надо хорошенько подумать как сделать лучше
 h:=((integer(ch1)*61)+integer(ch2)+s) and $FFF;
 if (intervalHash[h].ch1=ch1) and
    (intervalHash[h].ch2=ch2) and
    (intervalHash[h].size=s) then begin
  result:=intervalHash[h].interval;
  exit;
 end;

 // Calculate
 Inc(intervalHashMiss);
 cSect.Enter;
 try
   SetSize(size);

   gl1:=FT_Get_Char_Index(Face,cardinal(ch1));
   res:=FT_Load_Char(Face,cardinal(ch1),0);
   if res<>0 then
    raise EWarning.Create('FTF: LoadChar error 1: '+Conv.ToStr(res));
// if res<>0 then raise EWarning.Create('FTF: LoadChar error 2: '+Conv.ToStr(res));
   result:=face.glyph.advance.x;
   gl2:=FT_Get_Char_Index(Face,cardinal(ch2));
   if gl2=0 then begin
    res:=FT_Load_Char(face,cardinal(ch2),0);
    if res<>0 then
     raise EWarning.Create('FTF: LoadChar error 2: '+Conv.ToStr(res));
   end;
   res:=FT_Get_Kerning(face,gl1,gl2,0,v);
   if res<>0 then
     raise EWarning.Create('FTF: error 2: '+Conv.ToStr(res));
   result:=(result+v.x+31) shr 6;

   intervalHash[h].ch1:=ch1;
   intervalHash[h].ch2:=ch2;
   intervalHash[h].size:=s;
   intervalHash[h].interval:=result;
 finally
  cSect.Leave;
 end;
end;

function TFreeTypeFont.CharPadding(ch:Char32;size:single):integer;
var
 h,s:integer;
begin
 SetSize(size);
 // first char padding
 s:=round(size*4);
 h:=(integer(ch)+s*47) and $3FF;
 if (glyphWidthHash[h].ch<>ch) or
    (glyphWidthHash[h].size<>s) then FillGlyphMetrics(ch,h,s);
 result:=glyphWidthHash[h].padding;
end;

constructor TFreeTypeFont.LoadFromFile(fname:string;faceIndex:integer=0);
 var
  data:ByteArray;
 begin
   Log.Msg('Loading Freetype font from '+fname);
   data:=Files.LoadAsBytes(fname);
   LoadFromMemory(TBuffer.CreateFrom(data),faceIndex);
 end;

constructor TFreeTypeFont.LoadFromMemory(const data:TBuffer;faceIndex:integer);
 var
  err:integer;
 begin
  cSect.Enter;
  try
   if not initialized then InitFT;
   Log.Msg('Loading Freetype font from memory');
   if data.size<=0 then
    raise EWarning.Create('Failed to load font face: empty font buffer');
    SetLength(fontData,data.size);
    data.Read(fontData[0],data.size); // Copy data to keep it permanent
   err:=FT_New_Memory_Face(FTLibrary,@fontData[0],length(fontData),faceIndex,Face);
   if err<>0 then raise EWarning.Create('Failed to load font face, code='+Conv.ToStr(err));
   faceName:=Face.family_name;
   fillchar(intervalHash,sizeof(intervalHash),0);
   fillchar(glyphWidthHash,sizeof(glyphWidthHash),0);
   curSize:=0;
   fontSize:=0;
   globalScale:=1;
  finally
   cSect.Leave;
  end;
 end;

destructor TFreeTypeFont.Destroy;
begin
 cSect.Enter;
 try
  if face<>nil then begin
   FT_Done_Face(face);
   face:=nil;
  end;
 finally
  cSect.Leave;
 end;
 inherited;
end;

function TFreeTypeFont.RenderGlyph(ch:Char32;size:single;flags:integer;out dx,dy,
  width,height:integer;out pitch:integer): pointer;
var
 err:integer;
 bitmap:^FT_Bitmap;
begin
 cSect.Enter;
 try
  SetSize(size);

  err:=FT_Load_Char(face,cardinal(ch),FT_LOAD_RENDER+flags);
  if err<>0 then raise EWarning.Create('Failed to render char, '+Conv.ToStr(err));
  bitmap:=@face.glyph.bitmap;
  pitch:=bitmap.pitch;
  width:=bitmap.width;
  height:=bitmap.rows;
  dx:=face.glyph.bitmap_left;
  dy:=face.glyph.bitmap_top;
  result:=bitmap.buffer;
 finally
  cSect.Leave;
 end;
end;

procedure TFreeTypeFont.RenderText(buf: pointer; pitch, x, y: integer;
  st:String32;color:cardinal;size:single;flags:cardinal=0);
 var
   px,py:single;
   i,err,glInd,lastGlyph:integer;
  bitmap:^FT_Bitmap;
  a:pointer;
  kerning:FT_Vector;
  mat:FT_Matrix;
 begin
  cSect.Enter;
  try
   px:=x; py:=y;
   SetSize(size);
   if flags and FTF_ITALIC>0 then begin
    mat.xx:=65536; mat.xy:=round(65536*0.2);
    mat.yx:=0; mat.yy:=65536;
    FT_Set_Transform(Face,@mat,nil);
   end;
   try
    glInd:=-1;
    for i:=0 to length(st)-1 do begin
      lastGlyph:=glInd;
{    err:=FT_Load_Char(Face,cardinal(st[i]),FT_LOAD_RENDER);
     if err<>0 then raise EWarning.Create('Failed to load glyph: '+Conv.ToStr(err));}
     glInd:=FT_Get_Char_Index(Face,cardinal(st[i]));

     // Next character?
     if lastGlyph>=0 then begin
      err:=FT_Get_Kerning(Face,lastGlyph,glInd,FT_KERNING_DEFAULT,kerning);
      if err<>0 then raise EWarning.Create('FTGK error: '+Conv.ToStr(err));
//     px:=px+(face.glyph.advance.x/64);
      px:=px+kerning.x/64;
     end;

     // Load glyph
     err:=FT_Load_Glyph(Face,glInd,flags and $FFFF);
     if err<>0 then raise EWarning.Create('Failed to load glyph: '+Conv.ToStr(err));
     // Render glyph to 8bpp grayscale bitmap
     err:=FT_Render_Glyph(face.glyph,FT_RENDER_MODE_NORMAL);
     if err<>0 then raise EWarning.Create('Failed to render glyph: '+Conv.ToStr(err));
     // Draw
     bitmap:=@face.glyph.bitmap;
     if (i=0) and (face.glyph.bitmap_left>0) then px:=px-face.glyph.bitmap_left;
     a:=GetPixelAddr(buf,pitch,round(px)+face.glyph.bitmap_left,round(py)-face.glyph.bitmap_top);
     BlendUsingAlpha(a,pitch,bitmap.buffer,bitmap.pitch,bitmap.width,bitmap.rows,color,blBlend);
     px:=px+(face.glyph.advance.x/64);
    end;
   finally
    FT_Set_Transform(Face,nil,nil);
   end;
  finally
   cSect.Leave;
  end;
 end;

procedure TFreeTypeFont.SetSize(size:single);
var
 err:integer;
begin
 cSect.Enter;
 try
   if (curSize<>size) and (size>0) then begin
     err:=FT_Set_Char_Size(Face,round(size*64*globalScale),0,96,0);
     if err<>0 then
       raise EWarning.Create('Failed to set char size: '+Conv.ToStr(err));
     curSize:=size;
   end;
 finally
   cSect.Leave;
 end;
end;

initialization
  cSect.Init('FreeType',150);
finalization
  if initialized then
    FT_Done_FreeType(FTLibrary);
  cSect.Cleanup;
end.
