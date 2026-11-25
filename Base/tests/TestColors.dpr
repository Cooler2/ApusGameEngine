{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestColors;
// Tests for Apus.Colors: bilinear mix (SSE on x64, Pascal elsewhere), HSV, adjustments, sRGB/linear.
uses
  SysUtils,
  Apus.Core, Apus.Geom3D, Apus.Colors;

{$INCLUDE Test.inc}

procedure TestBilinearMixF;
var
  values:array[0..3] of single;
  ref:single;
begin
  StartTest('BilinearMixF(PSingle)');
  values[0]:=1; values[1]:=2; values[2]:=4; values[3]:=8;
  Check(Abs(BilinearMixF(@values,0,0)-1)<0.0001,'u=0,v=0 -> values[0]');
  Check(Abs(BilinearMixF(@values,1,0)-2)<0.0001,'u=1,v=0 -> values[1]');
  Check(Abs(BilinearMixF(@values,0,1)-4)<0.0001,'u=0,v=1 -> values[2]');
  Check(Abs(BilinearMixF(@values,1,1)-8)<0.0001,'u=1,v=1 -> values[3]');
  ref:=BilinearMixF(1,2,4,8,0.3,0.7);
  Check(Abs(BilinearMixF(@values,0.3,0.7)-ref)<0.0001,'matches scalar overload');
  EndTest;
end;

procedure TestHSV;
var
  h,s,v:single;
begin
  StartTest('Color.FromHSV and ToHSV');
  Check(Color.FromHSV(0,1,1)=$FFFF0000,'red');
  Check(Color.FromHSV(-0.5,1,1)=$FF00FFFF,'hue wraps');
  h:=0;
  Color.ToHSV($0000FF00,h,s,v);
  Check((abs(h-1/3)<0.00001) and (s=1) and (v=1),'green, ignore alpha');
  h:=0.5;
  Color.ToHSV($FF999999,h,s,v);
  Check((h=0.5) and (s=0) and (abs(v-0.6)<0.00001),'gray keeps hue');
  Color.ToHSV($FF000000,h,s,v);
  Check((h=0.5) and (s=0) and (v=0),'black keeps hue');
  EndTest;
end;

procedure TestBilinearMixColor;
var
  buf:array[0..7] of cardinal;
  values:PCardinal;
  c0,c1,c2,c3:cardinal;
begin
  StartTest('BilinearMix(PCardinal)');
  // 16-byte aligned + 4: the colors are not required to be aligned
  values:=PCardinal(((UIntPtr(@buf[0])+15) and not UIntPtr(15))+4);
  c0:=$FF000000; c1:=$80FF0000; c2:=$4000FF00; c3:=$000000FF;
  PCardinal(UIntPtr(values)+0)^:=c0;
  PCardinal(UIntPtr(values)+4)^:=c1;
  PCardinal(UIntPtr(values)+8)^:=c2;
  PCardinal(UIntPtr(values)+12)^:=c3;
  Check(BilinearMix(values,0,0)=c0,'u=0,v=0 -> values[0]');
  Check(BilinearMix(values,1,0)=c1,'u=1,v=0 -> values[1]');
  Check(BilinearMix(values,0,1)=c2,'u=0,v=1 -> values[2]');
  Check(BilinearMix(values,1,1)=c3,'u=1,v=1 -> values[3]');
  Check(Color.SimpleDiff(BilinearMix(values,0.5,0.5),$70404040)<=1,'center = channel average');
  Check(Color.SimpleDiff(BilinearMix(values,0.3,0.7),Color.BilinearMix(c0,c1,c2,c3,0.3,0.7))<=1,
    'matches Color.BilinearMix');
  EndTest;
end;

// RGB adjustments keep alpha and clamp channels
procedure TestAdjustments;
begin
  StartTest('Brighten/ScaleRGB/Contrast');
  Check(Color.Brighten($80102030,20)=$80243444,'Brighten adds to RGB, alpha kept');
  Check(Color.Brighten($80102030,300)=$80FFFFFF,'Brighten clamps at 255');
  Check(Color.Brighten($FF102030,-50)=$FF000000,'negative Brighten clamps at 0');
  Check(Color.Brighten($FF102030,MaxInt)=$FFFFFFFF,'extreme value does not overflow');
  Check(Color.ScaleRGB($FF6496C8,0.8)=$FF5078A0,'ScaleRGB 0.8: 20% darker, alpha kept');
  Check(Color.ScaleRGB($406496C8,2)=$40C8FFFF,'ScaleRGB clamps at 255');
  Check(Color.ScaleRGB($7F6496C8,0)=$7F000000,'ScaleRGB 0: black, alpha kept');
  Check(Color.Contrast($C0907060,256)=$C0907060,'Contrast 256: no change');
  Check(Color.Contrast($C0907060,0)=$C0808080,'Contrast 0: flat gray');
  Check(Color.Contrast($C0907060,512)=$C0A06040,'Contrast 512: doubled around 128');
  EndTest;
end;

procedure TestLinear;
var
  i:integer;
  c:cardinal;
  v:TVec4;
  roundTrip:boolean;
begin
  StartTest('Color.SRGBToLinear and LinearToSRGB');
  Check(Color.SRGBToLinear(0)=0,'0 -> 0');
  Check(abs(Color.SRGBToLinear(1)-1)<1E-6,'1 -> 1');
  Check(abs(Color.SRGBToLinear(0.5)-0.214041)<1E-5,'0.5 -> 0.214');
  Check(abs(Color.SRGBToLinear(0.02)-0.02/12.92)<1E-7,'linear segment');
  Check(abs(Color.LinearToSRGB(0.214041)-0.5)<1E-5,'0.214 -> 0.5');
  Check(abs(Color.LinearToSRGB(0.001)-0.01292)<1E-7,'linear segment back');
  roundTrip:=true;
  for i:=0 to 100 do
    if abs(Color.LinearToSRGB(Color.SRGBToLinear(i/100))-i/100)>2E-6 then roundTrip:=false;
  Check(roundTrip,'component round trip');
  EndTest;

  StartTest('Color.ToLinear and FromLinear (cardinal)');
  v:=Color.ToLinear($808CE678); // Blender shows sRGB 140,230,120 as linear 0.262,0.791,0.188
  Check((abs(v.x-0.2623)<1E-4) and (abs(v.y-0.7913)<1E-4) and (abs(v.z-0.1878)<1E-4),'RGB decoded');
  Check(abs(v.w-128/255)<1E-6,'alpha stays linear');
  roundTrip:=true;
  for i:=0 to 255 do begin
    c:=cardinal(i) shl 24+cardinal(i) shl 16+cardinal(255-i) shl 8+cardinal((i*7) and 255);
    if Color.FromLinear(Color.ToLinear(c))<>c then roundTrip:=false;
    if Color.ToLinear(c).x<>Color.SRGBToLinear(i/255) then roundTrip:=false;
  end;
  Check(roundTrip,'every byte value round-trips');
  Check(Color.FromLinear(TVec4.Init(-1,2,0.5,1.5))=$FF00FFBC,'clamped and rounded');
  Check(Color.FromLinear(TVec3.Init(1,0,0))=$FFFF0000,'TVec3 with default alpha');
  Check(Color.FromLinear(TVec3.Init(0,0,1),0)=$000000FF,'TVec3 with alpha');
  EndTest;
end;

begin
  try
    writeln('Testing [Colors] module');
    writeln;

    TestBilinearMixF;
    TestBilinearMixColor;
    TestHSV;
    TestAdjustments;
    TestLinear;

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
