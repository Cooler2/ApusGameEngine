unit Apus.Tweenings;
interface
uses Apus.Types;

type
 TTweening=record
   procedure Assign(value:single); overload;
   procedure Assign(values:PSingle;count:integer); overload;
   procedure Animate(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0); overload;
   procedure Animate(newValues:PSingle; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0); overload;

{   // То же самое, что animate, но сработает только если finalvalue<>newValue
   procedure AnimateIf(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0);
   // Возвращает значение анимируемой величины в текущий момент времени
   function Value:single;
   function IntValue:integer; inline;
   // Возвращает значение величины в указанный момент (0 - текущий момент)
   function ValueAt(time:int64):single;
   function FinalValue:single; // What the value will be when animation finished?
   function IsAnimating(time:int64=0):boolean; // Is value animating now?}

   class operator Initialize (out Dest:TTweening);
   class operator Finalize (var Dest:TTweening);
 private
   lock:integer;
   values:array of single;
   effect:TObject;
   lastTime:cardinal;
   //function InternalValueAt(time:int64):single; // No lock!
 end;


implementation
uses SysUtils, Apus.Common;

type
 // Full options set for ongoing tweening
 TTweeningEffect=class
  startTime,endTime:int64;
  spline:TSplineFunc;
  startValue,endValue:array[0..3] of single;
  startSpeed:array[0..3] of single; // derivative at start
  nextEffect:TTweeningEffect; // upcoming effect
  //constructor Create(const value:single;count:integer=1);
 end;

{ TTweening }
class operator TTweening.Initialize(out dest:TTweening);
begin
 dest.lock:=0;
end;

class operator TTweening.Finalize(var dest:TTweening);
var
 i:integer;
begin
 ASSERT(dest.lock=0);
 FreeAndNil(dest.effect);
end;

procedure TTweening.Assign(value:single);
begin
 SpinLock(lock);
 try
  SetLength(values,1);
  values[0]:=value;
 finally lock:=0; end;
end;

procedure TTweening.Animate(newValues:PSingle;duration:cardinal;spline:TSplineFunc;delay:integer);
var
 i,n:integer;
 eff:TTweeningEffect;
 time:int64;
begin
 SpinLock(lock);
 try
  n:=length(values);
  if effect=nil then begin
   // There is no ongoing tweening
   eff:=TTweeningEffect.Create;
   effect:=eff;
   for i:=0 to n-1 do begin
    eff.startValue[i]:=values[i];
    eff.startSpeed[i]:=0;
   end;
  end else begin
   // There is ongoing tweening: calc current values and speed
   for i:=0 to n-1 do begin
     values[i]:=Value(
   end;
   eff:=TTweeningEffect(effect);
   FreeAndNil(eff.nextEffect); // Discard upcoming effect
   if delay>0 then begin
    eff.nextEffect:=TTweeningEffect.Create;
    eff:=eff.nextEffect;
   end;
  end;
  for i:=0 to n-1 do begin
   eff.endValue[i]:=newValues^;
   inc(newValues);
  end;
  eff.startTime:=MyTickCount+delay;
  eff.endTime:=eff.startTime+duration;

 finally lock:=0; end;
end;

procedure TTweening.Animate(newValue:single;duration:cardinal;spline:TSplineFunc;delay:integer);
begin
 Animate(@newValue,duration,spline,delay);
end;

procedure TTweening.Assign(values:PSingle;count:integer);
var
 i:integer;
begin
 SpinLock(lock);
 try
  SetLength(self.values,count);
  for i:=0 to count-1 do begin
   self.values[i]:=values^; inc(values);
  end;
 finally lock:=0; end;
end;

end.
