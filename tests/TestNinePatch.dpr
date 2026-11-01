// 9-patch cells: a cell with any visible pixel is drawn, a fully transparent one is skipped;
// short tiles repeat with the minimal step. The image is an in-memory texture, so no GL window
// is needed.
{$APPTYPE CONSOLE}
program TestNinePatch;
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  Types,
  Apus.Core,
  Apus.Engine.Resources,
  Apus.Engine.NinePatch;

{$I ..\Base\tests\Test.inc}

const
  VISIBLE=$FF102030;
  MARK=$FF000000;  // black: a stretched range on the border of a marked image

type
  // Only what the 9-patch constructors use: pixels in memory
  TMemTexture=class(TTexture)
    pixels:array of cardinal;
    constructor Create(w,h:integer);
    procedure Lock(miplevel:byte=0;mode:TLockMode=lmReadWrite;rect:PRect=nil); override;
    procedure Unlock; override;
    procedure Put(x,y:integer;color:cardinal);
  end;

  TPatchProbe=class(TCustomNinePatch)
    function Cells(size:single=100):integer;
  end;

constructor TMemTexture.Create(w,h:integer);
 begin
  width:=w;
  height:=h;
  SetLength(pixels,w*h);
 end;

procedure TMemTexture.Lock(miplevel:byte;mode:TLockMode;rect:PRect);
 begin
  data:=@pixels[0];
  pitch:=width*4;
 end;

procedure TMemTexture.Unlock;
 begin
 end;

procedure TMemTexture.Put(x,y:integer;color:cardinal);
 begin
  pixels[x+y*width]:=color;
 end;

// Number of cells the mesh contains (2 triangles per cell)
function TPatchProbe.Cells(size:single):integer;
 begin
  BuildMeshForSize(size,size);
  result:=iCount div 6;
 end;

function NewTexture(w,h:integer):TMemTexture;
 begin
  {$IFDEF FPC}{$WARN 4046 OFF}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT OFF}{$ENDIF} // constructing a class with abstract methods: they are never called here
  result:=TMemTexture.Create(w,h);
  {$IFDEF FPC}{$WARN 4046 ON}{$ELSE}{$WARN CONSTRUCTING_ABSTRACT ON}{$ENDIF}
 end;

function MarginCells(tex:TTexture;margin:integer):integer;
 begin
  result:=TPatchProbe.CreateMargins(tex,margin,margin,margin,margin).Cells;
 end;

// A soft shadow: the margins size+1 around a transparent center 1x1, the middle cells are 1 px thick
function ShadowCells(size:integer):integer;
 var
  tex:TMemTexture;
  x,y,margin:integer;
 begin
  margin:=size+1;
  tex:=NewTexture(margin*2+1,margin*2+1);
  for y:=0 to tex.height-1 do
   for x:=0 to tex.width-1 do
    if (x<>margin) or (y<>margin) then tex.Put(x,y,$40000000);
  result:=MarginCells(tex,margin);
 end;

// The only visible pixel of the 9x9 image with margins 4
function PixelCells(x,y:integer;color:cardinal=VISIBLE):integer;
 var
  tex:TMemTexture;
 begin
  tex:=NewTexture(9,9);
  tex.Put(x,y,color);
  result:=MarginCells(tex,4);
 end;

procedure TestThinCells;
 begin
  StartTest('Thin cells');
  Check(ShadowCells(14)=8,'margin 15: the border is kept');
  Check(ShadowCells(21)=8,'margin 22: the thin bottom cell starts at an odd row');
  Check(ShadowCells(27)=8,'margin 28: the same');
  Check(ShadowCells(28)=8,'margin 29: the border is kept');
  EndTest;
 end;

procedure TestSinglePixels;
 begin
  StartTest('Single pixels');
  Check(PixelCells(4,4)=1,'the center cell of 1 pixel');
  Check(PixelCells(1,1)=1,'a pixel in an odd row and column');
  Check(PixelCells(0,1)=1,'a pixel in an odd row of an even column');
  Check(PixelCells(8,8)=1,'the last pixel of a cell');
  Check(PixelCells(4,5)=1,'a pixel in the cell 1 pixel wide');
  EndTest;
 end;

procedure TestTransparent;
 var
  tex:TMemTexture;
  i:integer;
 begin
  StartTest('Transparent cells');
  tex:=NewTexture(9,9);
  for i:=0 to high(tex.pixels) do tex.pixels[i]:=$04FFFFFF;
  Check(MarginCells(tex,4)=0,'alpha up to 4 is transparent');
  Check(PixelCells(2,2,$05000000)=1,'alpha 5 is visible');
  EndTest;
 end;

// Quads of a tiled patch 400x400: margins 4 around a tiled range of the given size
function TiledQuads(range:integer):integer;
 var
  tex:TMemTexture;
  i:integer;
 begin
  tex:=NewTexture(8+range,8+range);
  for i:=0 to high(tex.pixels) do tex.pixels[i]:=VISIBLE;
  result:=TPatchProbe.CreateMargins(tex,4,4,4,4,true).Cells(400);
 end;

// A tile below 16 px repeats with the step 16, the same as a tile of 17 px (its step is 16)
procedure TestTileStep;
 begin
  StartTest('Tile step');
  Check(TiledQuads(1)=TiledQuads(17),'a tile of 1 pixel');
  Check(TiledQuads(2)=TiledQuads(17),'a tile of 2 pixels');
  Check(TiledQuads(15)=TiledQuads(17),'a tile just below the limit');
  Check(TiledQuads(16)>TiledQuads(17),'a tile of 16 pixels keeps its own step');
  EndTest;
 end;

// The same check for a marked image: 3x3 ranges of 1 pixel inside the 1 px border
procedure TestMarkedImage;
 var
  tex:TMemTexture;
 begin
  StartTest('Marked image');
  tex:=NewTexture(5,5);
  tex.Put(2,0,MARK);
  tex.Put(0,2,MARK);
  tex.Put(2,3,VISIBLE);
  Check(TPatchProbe.Create(tex).Cells=1,'a thin cell in an odd row');
  EndTest;
 end;

begin
  TestThinCells;
  TestSinglePixels;
  TestTransparent;
  TestTileStep;
  TestMarkedImage;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
