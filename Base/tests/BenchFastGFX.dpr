{$APPTYPE CONSOLE}
program BenchFastGFX;
uses
 {$IFDEF MSWINDOWS}
  Windows,
 {$ENDIF}
  SysUtils,
  Apus.Core,
  Apus.FastGFX,
  Apus.Colors,
  Apus.Types;

{$I test.inc}

const
  N_FAST = 10000000;
  N_DEF  = 1000000;
  N_SLOW = 100000;
  
  // Реалистичные размеры буферов
  WIDTH = 1024;
  HEIGHT = 768;
  SMALL_WIDTH = 256;
  SMALL_HEIGHT = 256;

// Глобальные буферы для тестирования
var
  // Основные буферы 1024x768 (3 МБ каждый для 32-битных пикселей)
  buf32_1:array[0..HEIGHT-1,0..WIDTH-1] of cardinal;
  buf32_2:array[0..HEIGHT-1,0..WIDTH-1] of cardinal;
  
  // Меньшие буферы для некоторых тестов
  smallBuf32_1:array[0..SMALL_HEIGHT-1,0..SMALL_WIDTH-1] of cardinal;
  smallBuf32_2:array[0..SMALL_HEIGHT-1,0..SMALL_WIDTH-1] of cardinal;
  
  // 8-битные буферы
  buf8_1:array[0..HEIGHT-1,0..WIDTH-1] of byte;
  buf8_2:array[0..HEIGHT-1,0..WIDTH-1] of byte;

// ============================================================================
// Color conversion
// ============================================================================

procedure BenchColor_To16;
var i:integer; color,r:cardinal;
begin
  StartBench('ColorTo16',N_FAST);
  color:=$FFAABBCC;
  for i:=1 to N_FAST do
    r:=ColorTo16(color);
  EndBench;
end;

procedure BenchColor_From16;
var i:integer; color,r:cardinal;
begin
  StartBench('ColorFrom16',N_FAST);
  color:=$7BDE; // Пример 16-битного цвета
  for i:=1 to N_FAST do
    r:=ColorFrom16(color);
  EndBench;
end;

procedure BenchColor_To32;
var i:integer; color,r:cardinal;
begin
  StartBench('ColorTo32',N_FAST);
  color:=$FFAABBCC;
  for i:=1 to N_FAST do
    r:=ColorTo32(color);
  EndBench;
end;

procedure BenchColor_From32;
var i:integer; color,r:cardinal;
begin
  StartBench('ColorFrom32',N_FAST);
  color:=$FFAABBCC;
  for i:=1 to N_FAST do
    r:=ColorFrom32(color);
  EndBench;
end;

// ============================================================================
// Blending operations
// ============================================================================

procedure BenchBlend_Simple;
var i:integer; bg,fg,r:cardinal;
begin
  StartBench('Blend (simple)',N_FAST);
  bg:=$FF112233;
  fg:=$80445566;
  for i:=1 to N_FAST do
    r:=Color.Blend(bg,fg);
  EndBench;
end;

procedure BenchBlend_BilinearMix;
var i:integer; c1,c2,c3,c4,r:cardinal;
begin
  StartBench('BilinearMix',N_FAST);
  c1:=$FF000000;
  c2:=$FF0000FF;
  c3:=$FF00FF00;
  c4:=$FFFF0000;
  for i:=1 to N_FAST do
    r:=Color.BilinearMix(c1,c2,c3,c4,0.3,0.7);
  EndBench;
end;

procedure BenchBlend_BilinearBlend;
var i:integer; c1,c2,c3,c4,r:cardinal;
begin
  StartBench('BilinearBlend',N_FAST);
  c1:=$FF000000;
  c2:=$FF0000FF;
  c3:=$FF00FF00;
  c4:=$FFFF0000;
  for i:=1 to N_FAST do
    r:=Color.BilinearBlend(c1,c2,c3,c4,0.3,0.7);
  EndBench;
end;

// ============================================================================
// Pixel operations
// ============================================================================

procedure BenchPixel_GetAddr32;
var i:integer; p:pointer;
begin
  StartBench('GetPixelAddr (32-bit)',N_FAST);
  for i:=1 to N_FAST do
    p:=GetPixelAddr(@buf32_1,WIDTH*4,512,384); // Центр изображения
  EndBench;
end;

procedure BenchPixel_GetAddr8;
var i:integer; p:pointer;
begin
  StartBench('GetPixelAddr8 (8-bit)',N_FAST);
  for i:=1 to N_FAST do
    p:=GetPixelAddr8(@buf8_1,WIDTH,512,384); // Центр изображения
  EndBench;
end;

// ============================================================================
// Rectangle operations
// ============================================================================

procedure BenchRect_FillLarge;
var i:integer;
begin
  StartBench('FillRect 1024x768',N_SLOW div 100);
  for i:=1 to N_SLOW div 100 do
    FillRect(@buf32_1,WIDTH*4,100,100,923,667,$FFAABBCC); // Большой прямоугольник
  EndBench;
end;

procedure BenchRect_FillBlendLarge;
var i:integer;
begin
  StartBench('FillRect+Blend 1024x768',N_SLOW div 100);
  for i:=1 to N_SLOW div 100 do
    FillRect(@buf32_1,WIDTH*4,100,100,923,667,$80AABBCC,blBlend); // semi-transparent
  EndBench;
end;

procedure BenchRect_CopyLarge;
var i:integer;
begin
  StartBench('CopyRect 1024x768',N_SLOW div 100);
  for i:=1 to N_SLOW div 100 do
    CopyRect(@buf32_1,WIDTH*4,@buf32_2,WIDTH*4,0,0,WIDTH,HEIGHT,0,0);
  EndBench;
end;

procedure BenchRect_Copy8Large;
var i:integer;
begin
  StartBench('CopyRect8 1024x768',N_SLOW div 100);
  for i:=1 to N_SLOW div 100 do
    CopyRect8(@buf8_1,WIDTH,@buf8_2,WIDTH,0,0,WIDTH,HEIGHT,0,0);
  EndBench;
end;

// ============================================================================
// Drawing operations
// ============================================================================

procedure BenchDraw_SimpleDraw;
var i:integer;
begin
  StartBench('SimpleDraw 256x256',N_SLOW div 10);
  for i:=1 to N_SLOW div 10 do
    SimpleDraw(@smallBuf32_1,SMALL_WIDTH*4,@smallBuf32_2,SMALL_WIDTH*4,
               0,0,SMALL_WIDTH,SMALL_HEIGHT,blBlend);
  EndBench;
end;

procedure BenchDraw_HLine32;
var i:integer;
begin
  StartBench('HLine32 1024px',N_DEF);
  for i:=1 to N_DEF do
    HLine32(@buf32_1,WIDTH*4,0,WIDTH-1,384,$FFAABBCC); // Горизонтальная линия по центру
  EndBench;
end;

procedure BenchDraw_VLine32;
var i:integer;
begin
  StartBench('VLine32 768px',N_DEF);
  for i:=1 to N_DEF do
    VLine32(@buf32_1,WIDTH*4,512,0,HEIGHT-1,$FFAABBCC); // Вертикальная линия по центру
  EndBench;
end;

// ============================================================================
// Image processing
// ============================================================================

procedure BenchImage_Crop;
var i:integer; r:TRect;
begin
  StartBench('CropImage 1024x768',N_SLOW div 100);
  // Заполним буфер прозрачными пикселями с непрозрачным прямоугольником в центре
  FillRect(@buf32_1,WIDTH*4,0,0,WIDTH-1,HEIGHT-1,0);
  FillRect(@buf32_1,WIDTH*4,300,200,723,567,$FFAABBCC);
  for i:=1 to N_SLOW div 100 do
    r:=CropImage(@buf32_1,WIDTH*4,WIDTH,HEIGHT);
  EndBench;
end;

procedure BenchImage_DownSample2X;
var i:integer;
begin
  StartBench('DownSample2X 1024x768->512x384',N_SLOW div 100);
  for i:=1 to N_SLOW div 100 do
    DownSample2X(@buf32_1,WIDTH*4,@buf32_2,(WIDTH div 2)*4,WIDTH,HEIGHT);
  EndBench;
end;

// ============================================================================
// Main
// ============================================================================

begin
  try
    OpenBenchLog('fastgfx',N_DEF);
    BenchWriteln;

    BenchWriteln('--- Color Conversion ---');
    BenchColor_To16;
    BenchColor_From16;
    BenchColor_To32;
    BenchColor_From32;
    BenchWriteln;

    BenchWriteln('--- Blending Operations ---');
    BenchBlend_Simple;
    BenchBlend_BilinearMix;
    BenchBlend_BilinearBlend;
    BenchWriteln;

    BenchWriteln('--- Pixel Operations ---');
    BenchPixel_GetAddr32;
    BenchPixel_GetAddr8;
    BenchWriteln;

    BenchWriteln('--- Rectangle Operations ---');
    BenchRect_FillLarge;
    BenchRect_FillBlendLarge;
    BenchRect_CopyLarge;
    BenchRect_Copy8Large;
    BenchWriteln;

    BenchWriteln('--- Drawing Operations ---');
    BenchDraw_SimpleDraw;
    BenchDraw_HLine32;
    BenchDraw_VLine32;
    BenchWriteln;

    BenchWriteln('--- Image Processing ---');
    BenchImage_Crop;
    BenchImage_DownSample2X;
    BenchWriteln;

    CloseBenchLog;
    writeln('=== BENCHMARK DONE ===');
  except
    on e:Exception do begin
      writeln;
      writeln('BENCHMARK FAILED: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press ENTER to exit');
    readln;
  end;
end.