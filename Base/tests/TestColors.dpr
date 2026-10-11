{$APPTYPE CONSOLE}
{$EXCESSPRECISION OFF}
program TestColors;
// Tests for Apus.Colors — currently the pointer-based bilinear mix (SSE on x64, Pascal elsewhere).
uses
  SysUtils,
  Apus.Core, Apus.Colors;

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

begin
  try
    writeln('Testing [Colors] module');
    writeln;

    TestBilinearMixF;
    TestBilinearMixColor;

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
