{$APPTYPE CONSOLE}
program TestGfxFilters;
// Tests for Apus.GfxFilters — currently the HeightToNormalMap operation.
uses
  SysUtils,
  Apus.Core, Apus.Geom3D, Apus.Colors, Apus.GfxFilters;

{$INCLUDE Test.inc}

const
  W = 16;
  H = 16;

type
  TImg = array[0..W*H-1] of cardinal;

// decode an RGB-encoded tangent-space normal back to a vector in [-1,1]
function DecodeN(c:cardinal):TVec3;
begin
  result.x:=((c shr 16 and $FF)/127.5)-1;
  result.y:=((c shr 8 and $FF)/127.5)-1;
  result.z:=((c and $FF)/127.5)-1;
end;

// fill src with a constant gray and check every output normal points straight up
function FlatGivesUpNormals:boolean;
var
  src,dst:TImg;
  i:integer;
begin
  for i:=0 to W*H-1 do src[i]:=Color.RGB(100,100,100);
  HeightToNormalMap(@src[0],W*4, @dst[0],W*4, W,H, 2.0,true);
  result:=true;
  for i:=0 to W*H-1 do
    if (abs(integer(dst[i] shr 16 and $FF)-128)>1) or // x ~ 0
       (abs(integer(dst[i] shr 8 and $FF)-128)>1) or  // y ~ 0
       ((dst[i] and $FF)<254) then                    // z ~ +1
      result:=false;
end;

// height ramp along +X: interior normals tilt toward -X (R<128), unchanged in Y (G=128)
function XRampTiltsNegativeX:boolean;
var
  src,dst:TImg;
  x,y:integer;
begin
  for y:=0 to H-1 do
   for x:=0 to W-1 do
    src[y*W+x]:=Color.RGB(x*16,x*16,x*16);
  HeightToNormalMap(@src[0],W*4, @dst[0],W*4, W,H, 2.0,false);
  result:=true;
  for y:=0 to H-1 do
   for x:=1 to W-2 do begin // skip edge columns
    if (dst[y*W+x] shr 16 and $FF)>=128 then result:=false; // x<0
    if abs(integer(dst[y*W+x] shr 8 and $FF)-128)>1 then result:=false; // y~0
   end;
end;

// height ramp along +Y: interior normals tilt toward -Y (G<128), unchanged in X (R=128)
function YRampTiltsNegativeY:boolean;
var
  src,dst:TImg;
  x,y:integer;
begin
  for y:=0 to H-1 do
   for x:=0 to W-1 do
    src[y*W+x]:=Color.RGB(y*16,y*16,y*16);
  HeightToNormalMap(@src[0],W*4, @dst[0],W*4, W,H, 2.0,false);
  result:=true;
  for y:=1 to H-2 do // skip edge rows
   for x:=0 to W-1 do begin
    if (dst[y*W+x] shr 8 and $FF)>=128 then result:=false; // y<0
    if abs(integer(dst[y*W+x] shr 16 and $FF)-128)>1 then result:=false; // x~0
   end;
end;

// wrap=true samples the opposite edge toroidally, so a top/bottom step yields a
// different normal at the seam row than edge-clamping does
function WrapDiffersFromClamp:boolean;
var
  src,wrapped,clamped:TImg;
  x,y:integer;
begin
  for y:=0 to H-1 do
   for x:=0 to W-1 do
    if y<H div 2 then src[y*W+x]:=Color.RGB(220,220,220)
     else src[y*W+x]:=Color.RGB(30,30,30);
  HeightToNormalMap(@src[0],W*4, @wrapped[0],W*4, W,H, 2.0,true);
  HeightToNormalMap(@src[0],W*4, @clamped[0],W*4, W,H, 2.0,false);
  result:=false;
  // row 0: wrap pulls the dark bottom row in, clamp repeats the bright top row
  for x:=0 to W-1 do
   if (wrapped[x] shr 8 and $FF)<>(clamped[x] shr 8 and $FF) then result:=true;
end;

// every output texel is opaque and decodes to a (near) unit-length vector
function AllOpaqueUnitNormals:boolean;
var
  src,dst:TImg;
  x,y:integer;
  n:TVec3;
begin
  for y:=0 to H-1 do
   for x:=0 to W-1 do
    src[y*W+x]:=Color.RGB(x*16,y*8,(x+y)*4); // arbitrary varying height
  HeightToNormalMap(@src[0],W*4, @dst[0],W*4, W,H, 4.0,true);
  result:=true;
  for x:=0 to W*H-1 do begin
    if (dst[x] shr 24)<>$FF then result:=false; // opaque
    n:=DecodeN(dst[x]);
    if abs(n.Length-1)>0.03 then result:=false; // quantization tolerance
  end;
end;

// Compare cropped blur against a scalar reference, including bottom-up images.
procedure TestDraftBlurPointers;
const
  BW=5;
  BH=4;
var
  src,expected:ByteArray;
  mode,sign,x,y,k,xx,yy,bpp,pitch,ofs,sum,v:integer;
  origin:PByte;
  ok:boolean;
begin
  StartTest('Draft blur pointer arithmetic');
  for mode:=0 to 3 do
    for sign:=0 to 1 do begin
      if mode<2 then bpp:=4 else bpp:=1;
      pitch:=BW*bpp+4;
      SetLength(src,pitch*BH);
      FillChar(src[0],length(src),$AA);
      origin:=@src[0];
      if sign=1 then begin
        inc(origin,pitch*(BH-1));
        pitch:=-pitch;
      end;
      for y:=0 to BH-1 do
        for x:=0 to BW-1 do begin
          v:=y*10+x+1;
          if bpp=4 then PCardinal(origin+y*pitch+x*bpp)^:=cardinal(v*$10101)
            else (origin+y*pitch+x)^:=v;
        end;
      expected:=Copy(src);
      for y:=1 to 2 do
        for x:=1 to 3 do begin
          sum:=0;
          for k:=-1 to 1 do begin
            xx:=x; yy:=y;
            if mode in [0,2] then xx:=Clamp(x+k,1,3)
              else yy:=Clamp(y+k,1,2);
            inc(sum,yy*10+xx+1);
          end;
          v:=(sum*(65536 div 3)) shr 16;
          ofs:=y*pitch+x*bpp;
          if sign=1 then inc(ofs,(-pitch)*(BH-1));
          if bpp=4 then PCardinal(@expected[ofs])^:=cardinal(v*$10101)
            else expected[ofs]:=v;
        end;
      case mode of
        0:DraftBlur32X(origin,1,1,3,2,pitch,1);
        1:DraftBlur32Y(origin,1,1,3,2,pitch,1);
        2:DraftBlur8X(origin,1,1,3,2,pitch,1);
        3:DraftBlur8Y(origin,1,1,3,2,pitch,1);
      end;
      ok:=true;
      for k:=0 to high(src) do
        if src[k]<>expected[k] then ok:=false;
      Check(ok,'mode '+IntToStr(mode)+', pitch sign '+IntToStr(sign));
    end;
  EndTest;
end;

procedure TestHeightToNormalMap;
begin
  StartTest('HeightToNormalMap');
  Check(FlatGivesUpNormals,'flat height -> normals point up (+Z)');
  Check(XRampTiltsNegativeX,'+X height ramp -> normals tilt toward -X');
  Check(YRampTiltsNegativeY,'+Y height ramp -> normals tilt toward -Y');
  Check(WrapDiffersFromClamp,'wrap=true samples opposite edge (differs from clamp)');
  Check(AllOpaqueUnitNormals,'all texels opaque and near unit length');
  EndTest;
end;

begin
  try
    writeln('Testing [GfxFilters] module');
    writeln;

    TestDraftBlurPointers;
    TestHeightToNormalMap;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
