// Text metrics and layout without a GL window: Advance, PenPositions, tabular digits,
// WrapText, FitText on the engine's built-in raster font and, with FREETYPE, the vector
// one (Open Sans). The smoke scripts build without FREETYPE: there only the raster font
{$APPTYPE CONSOLE}
program TestTextMetrics;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.Types,
  Apus.Strings,
  Apus.Engine.Types,
  Apus.Engine.API,
  Apus.Engine.TextDraw,
  TextFitNoBom;

{$I ..\Base\tests\Test.inc}

{$IFDEF FREETYPE}
const
 {$I ..\defaultFont.inc}
{$ENDIF}
{$I ..\defaultFont10.inc}

var
  td:TTextDrawer;
  txtIntf:ITextDrawer; // keeps td alive
  fonts:array of TFontHandle; // raster, then vector 10 and 24
  vectorFont:TFontHandle; // 0 without FREETYPE

// '…' (U+2026) in UTF-8, built from bytes: a literal would depend on the source codepage
function Ellipsis:String8;
begin
  SetLength(result,3);
  result[1]:=AnsiChar($E2); result[2]:=AnsiChar($80); result[3]:=AnsiChar($A6);
end;

function S32(const st:String8):String32;
begin
  result:=UTF8.Decode(st);
end;

function Same(a,b:single):boolean;
begin
  result:=abs(a-b)<0.01;
end;

procedure LoadFonts;
var
  name:string;
begin
  // the raster font first: a first vector font asks the game for the default size
  name:=td.LoadRasterFont(TBuffer.CreateFrom(@defaultFont10,length(defaultFont10)),'TestRaster');
  fonts:=[td.GetFont(name,7,fsIgnoreScale+fsStrictMatch)]; // native size: no glyph scaling
  vectorFont:=0;
  {$IFDEF FREETYPE}
  name:=td.LoadVectorFont(TBuffer.CreateFrom(@OpenSans_Regular,OpenSans_Regular_Size),'TestVector');
  vectorFont:=td.GetFont(name,10,fsIgnoreScale+fsStrictMatch);
  fonts:=fonts+[vectorFont,td.GetFont(name,24,fsIgnoreScale+fsStrictMatch)];
  {$ENDIF}
end;

procedure TestAdvance;
var
  f,i:integer;
  font:TFontHandle;
  pos:SingleArray;
  okEnd,okSuffix,okGrow,okEmpty,okLines:boolean;
  a,b:String8;
begin
  StartTest('Advance and pen positions');
  okEnd:=true; okSuffix:=true; okGrow:=true; okEmpty:=true; okLines:=true;
  a:='Hello, '; b:='World 42';
  for f:=0 to high(fonts) do begin
   font:=fonts[f];
   td.PenPositions(font,S32(a+b),pos);
   // the last position is the advance of the whole line
   if not Same(pos[length(a+b)]-pos[0],td.Advance(font,a+b)) then okEnd:=false;
   // the advance is additive: the part after a starts where the pen stands after a
   if not Same(pos[length(a+b)]-pos[length(a)],td.Advance(font,b)) then okSuffix:=false;
   for i:=1 to length(a+b) do
    if pos[i]<=pos[i-1] then okGrow:=false;
   td.PenPositions(font,nil,pos);
   if (length(pos)<>1) or (pos[0]<>0) or (td.Advance(font,'')<>0) then okEmpty:=false;
   if not Same(td.Advance(font,'abc'#10'Hello world'#13#10'x'),td.Advance(font,'Hello world')) then okLines:=false;
  end;
  Check(okEnd,'pos[length]-pos[0] = Advance');
  Check(okSuffix,'Advance of a suffix = its span in the whole line');
  Check(okGrow,'pen positions grow');
  Check(okEmpty,'empty text: one position 0, advance 0');
  Check(okLines,'multi-line advance = the widest line');
  td.PenPositions(fonts[high(fonts)],S32('W'),pos);
  Check(pos[0]<=0,'pos[0] is minus the bearing of the first glyph');
  EndTest;
end;

procedure TestTabularDigits;
var
  f:integer;
  font,tab:TFontHandle;
  p1,p2:SingleArray;
  okAdv,okPos,okWidth,okCell,okText:boolean;
  i:integer;
  cell:single;
begin
  StartTest('Tabular digits');
  okAdv:=true; okPos:=true; okWidth:=true; okCell:=true; okText:=true;
  for f:=0 to high(fonts) do begin
   font:=fonts[f];
   tab:=font or fsTabularDigits;
   cell:=td.Advance(tab,'0');
   for i:=1 to 9 do
    if not Same(td.Advance(tab,AnsiChar(ord('0')+i)),cell) then okCell:=false;
   if not Same(td.Advance(tab,'1111'),td.Advance(tab,'8888')) then okAdv:=false;
   td.PenPositions(tab,S32('-12:34.5'),p1);
   td.PenPositions(tab,S32('-98:70.6'),p2);
   for i:=0 to high(p1) do
    if not Same(p1[i],p2[i]) then okPos:=false;
   if td.Width(tab,'1:11.1')<>td.Width(tab,'8:08.4') then okWidth:=false;
   // letters keep their own advance
   if not Same(td.Advance(tab,'Lap'),td.Advance(font,'Lap')) then okText:=false;
  end;
  Check(okCell,'every digit takes the same cell');
  Check(okAdv,'Advance of digit strings of one length is equal');
  Check(okPos,'positions of ":" and "." do not depend on the digits');
  Check(okWidth,'Width of a time does not depend on the digits');
  Check(okText,'letters are not affected');
  // the reason for the flag even in a font with equal digit advances: Width (and so the
  // right and center alignment of Write) follows the ink of the edge digits
  if vectorFont<>0 then
   Check(td.Width(vectorFont,'1:11')<>td.Width(vectorFont,'8:88'),'without the flag Width follows the edge digits');
  EndTest;
end;

// lines joined by single spaces (for texts with single spaces only)
function JoinLines(const lines:Strings8;const sep:String8):String8;
var
  i:integer;
begin
  result:='';
  for i:=0 to high(lines) do begin
   if i>0 then result:=result+sep;
   result:=result+lines[i];
  end;
end;

procedure TestWrap;
const
  TEXT='The quick brown fox jumps over the lazy dog and keeps running along the river bank';
  WORD='Supercalifragilisticexpialidocious';
  CYR:String8='Съешь же ещё этих мягких французских булок, да выпей чаю';
  CYR_LINE:String8='Съешь же ещё';
var
  f,i:integer;
  font:TFontHandle;
  lines:Strings8;
  widths:SingleArray;
  w:single;
  okFit,okJoin,okGreedy,okSpaces,okWidths,okWord,okWordJoin,okCyr,okCyrJoin,okMarks:boolean;
begin
  StartTest('WrapText');
  okFit:=true; okJoin:=true; okGreedy:=true; okSpaces:=true; okWidths:=true;
  okWord:=true; okWordJoin:=true; okCyr:=true; okCyrJoin:=true; okMarks:=true;
  for f:=0 to high(fonts) do begin
   font:=fonts[f];
   w:=td.Width(font,'The quick brown fox');
   lines:=td.WrapText(font,TEXT,w,widths);
   for i:=0 to high(lines) do begin
    if td.Width(font,lines[i])>w then okFit:=false;
    if not Same(widths[i],td.Width(font,lines[i])) then okWidths:=false;
    if (lines[i]='') or (lines[i][1]=' ') or (lines[i][length(lines[i])]=' ') then okSpaces:=false;
    // greedy: the next word would not fit
    if (i<high(lines)) and (td.Width(font,lines[i]+' '+Copy(lines[i+1],1,Pos(' ',lines[i+1]+' ')-1))<=w) then
     okGreedy:=false;
   end;
   if JoinLines(lines,' ')<>TEXT then okJoin:=false;
   // a word longer than the line is broken between characters
   w:=td.Width(font,'Supercal');
   lines:=td.WrapText(font,WORD,w);
   for i:=0 to high(lines) do
    if td.Width(font,lines[i])>w then okWord:=false;
   if (length(lines)<2) or (JoinLines(lines,'')<>WORD) then okWordJoin:=false;
   // UTF-8 stays whole (the raster font may lack Cyrillic: metrics still work)
   w:=td.Width(font,CYR_LINE);
   lines:=td.WrapText(font,CYR,w);
   for i:=0 to high(lines) do
    if td.Width(font,lines[i])>w then okCyr:=false;
   if JoinLines(lines,' ')<>CYR then okCyrJoin:=false;
   // punctuation after a word doesn't fit: a letter goes with it to the next line
   w:=td.Width(font,'word');
   lines:=td.WrapText(font,'word. word?! (word),',w);
   for i:=0 to high(lines) do
    if (lines[i]<>'') and (lines[i][1] in ['.',',','?','!',')']) then okMarks:=false;
  end;
  Check(okFit,'lines fit the width');
  Check(okWidths,'widths = Width of the lines');
  Check(okSpaces,'no spaces at the ends of lines');
  Check(okGreedy,'each line takes all the words that fit');
  Check(okJoin,'the words are kept in order');
  Check(okWord,'a long word is broken to fit');
  Check(okWordJoin,'a broken word keeps all its characters');
  Check(okCyr,'UTF-8 lines fit the width');
  Check(okCyrJoin,'UTF-8 text is kept whole');
  Check(okMarks,'no line starts with punctuation torn off its word');

  font:=fonts[high(fonts)];
  lines:=td.WrapText(font,'a'#13#10'b'#13'c'#10#10'd',1000);
  Check(JoinLines(lines,'|')='a|b|c||d','explicit line breaks, empty line kept');
  lines:=td.WrapText(font,'',100);
  Check((length(lines)=1) and (lines[0]=''),'empty text: one empty line');
  lines:=td.WrapText(font,'one two three'#10'four',0);
  Check(JoinLines(lines,'|')='one two three|four','width 0: explicit breaks only');
  lines:=td.WrapText(font,'W W',1);
  Check(JoinLines(lines,'|')='W|W','a character wider than the line takes a line alone');
  lines:=td.WrapText(font,'  indented text',1000);
  Check(JoinLines(lines,'|')='  indented text','leading spaces of a paragraph are kept');
  EndTest;
end;

procedure TestFit;
const
  TEXT='Championship results: season 2026';
  CYR:String8='Результаты чемпионата сезона';
var
  f:integer;
  font:TFontHandle;
  r,e:String8;
  w:single;
  okFit,okEnd,okMax,okStart,okMiddle,okNone,okTiny,okCyr,okSpace,okNoBom,okExplicit:boolean;
begin
  StartTest('FitText');
  okFit:=true; okEnd:=true; okMax:=true; okStart:=true; okMiddle:=true; okNone:=true;
  okTiny:=true; okCyr:=true; okSpace:=true; okNoBom:=true; okExplicit:=true;
  for f:=0 to high(fonts) do begin
   font:=fonts[f];
   if td.FitText(font,TEXT,td.Width(font,TEXT))<>TEXT then okFit:=false;
   if td.HasGlyph(font,$2026) then e:=Ellipsis else e:='...';
   w:=td.Width(font,TEXT)*0.6;
   r:=td.FitText(font,TEXT,w);
   if FitDefault(txtIntf,font,TEXT,w)<>r then okNoBom:=false;
   if td.FitText(font,TEXT,w,TTextCut.atEnd,Ellipsis)<>r then okExplicit:=false;
   if (td.Width(font,r)>w) or (Copy(r,length(r)-length(e)+1,length(e))<>e) or
      (Copy(TEXT,1,length(r)-length(e))<>Copy(r,1,length(r)-length(e))) then okEnd:=false;
   // the most that fits: one more character doesn't
   if td.Width(font,Copy(TEXT,1,length(r)-length(e)+1)+e)<=w then okMax:=false;
   r:=td.FitText(font,TEXT,w,TTextCut.atStart);
   if (td.Width(font,r)>w) or (Copy(r,1,length(e))<>e) or
      (Copy(TEXT,length(TEXT)-(length(r)-length(e))+1,MaxInt)<>Copy(r,length(e)+1,MaxInt)) then okStart:=false;
   r:=td.FitText(font,TEXT,w,TTextCut.atMiddle);
   if (td.Width(font,r)>w) or (Pos(e,r)<2) or (Copy(r,1,3)<>'Cha') or (Copy(r,length(r)-1,2)<>'26') then okMiddle:=false;
   r:=td.FitText(font,TEXT,w,TTextCut.atStart,'');
   if (td.Width(font,r)>w) or (Copy(TEXT,length(TEXT)-length(r)+1,MaxInt)<>r) then okNone:=false;
   if (td.FitText(font,TEXT,td.Width(font,e)-1)<>'') or (td.FitText(font,TEXT,0)<>'') then okTiny:=false;
   r:=td.FitText(font,CYR,td.Width(font,CYR)*0.5);
   if UTF8.Encode(UTF8.Decode(r))<>r then okCyr:=false;
   // no space before the ellipsis: cut right after "Championship results:"
   r:=td.FitText(font,TEXT,td.Width(font,'Championship results: s'+e)-1);
   if Pos(' '+e,r)>0 then okSpace:=false;
  end;
  Check(okFit,'a text that fits is returned as is');
  Check(okEnd,'atEnd: the start of the text with the ellipsis, fits');
  Check(okMax,'atEnd keeps as much as fits');
  Check(okStart,'atStart: the ellipsis with the end of the text, fits');
  Check(okMiddle,'atMiddle: both ends kept, fits');
  Check(okNone,'no ellipsis: the tail that fits');
  Check(okTiny,'narrower than the ellipsis: empty');
  Check(okCyr,'UTF-8 cut at a character boundary');
  Check(okSpace,'no space before the ellipsis');
  Check(okNoBom,'the default ellipsis is the same for a caller unit without a BOM');
  Check(okExplicit,'an explicit ''…'' is the default one (''...'' without the glyph)');
  EndTest;
end;

begin
  td:=TTextDrawer.Create;
  txtIntf:=td;
  LoadFonts;
  TestAdvance;
  TestTabularDigits;
  TestWrap;
  TestFit;
  if IsDebuggerPresent then readln;
end.
