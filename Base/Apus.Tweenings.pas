// Lightweight tweening (animated value interpolation) with smooth interruptions
//
// Key difference from AnimatedValues: instead of complex overlap blending,
// uses a compensating function to smoothly blend initial speed mismatch.
// This works correctly with any spline type including bounce.
//
// Compensating function: g(u) = deltaSpeed * duration * u * (1-u)^2
// where u = (t - startTime) / duration
// This cubic naturally decays the speed difference while preserving
// boundary conditions: g(0)=0, g(1)=0, g'(0)=deltaSpeed, g'(1)=0
//
// Copyright (C) 2021 Apus Software
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Tweenings;
interface
uses Apus.Utils;

type
 TTweening=record
   // Set value immediately (cancel any animation)
   procedure Assign(value:single); overload;
   procedure Assign(const v;count:integer); overload;
   // Animate to new value over duration (ms), optional spline and delay
   procedure Animate(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0); overload;
   procedure Animate(const newValues; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0); overload;
   // Get current value(s)
   function Value:single;
   function IntValue:integer; inline;
   procedure GetValue(out v; time:int64=0);
   function FinalValue:single;
   function IsAnimating(time:int64=0):boolean;
   procedure Free; // release effect object
   {$IFDEF DELPHI}
   class operator Initialize(out dest:TTweening);
   class operator Finalize(var dest:TTweening);
   {$ENDIF}
 private
   lock:integer;
   count:integer; // number of components (1..4)
   curValues:array[0..3] of single;
   effect:pointer; // TTweeningEffect
   function CalcValue(index:integer; time:int64):single;
   procedure FinalizeEffect(time:int64);
 end;

implementation
uses SysUtils, Apus.Core;

type
 TTweeningEffect=class
  startTime,endTime:int64;
  duration:cardinal;
  spline:TSplineFunc;
  startValue:array[0..3] of single;
  endValue:array[0..3] of single;
  compensation:array[0..3] of single; // deltaSpeed * duration for each component
 end;

{ TTweening }

{$IFDEF DELPHI}
class operator TTweening.Initialize(out dest:TTweening);
begin
 dest.lock:=0;
 dest.count:=0;
 dest.effect:=nil;
end;

class operator TTweening.Finalize(var dest:TTweening);
begin
 ASSERT(dest.lock=0);
 if dest.effect<>nil then begin
  TTweeningEffect(dest.effect).Free;
  dest.effect:=nil;
 end;
end;
{$ENDIF}

procedure TTweening.Free;
begin
 SpinLock(lock);
 try
  if effect<>nil then begin
   TTweeningEffect(effect).Free;
   effect:=nil;
  end;
 finally lock:=0; end;
end;

procedure TTweening.Assign(value:single);
begin
 SpinLock(lock);
 try
  count:=1;
  curValues[0]:=value;
  if effect<>nil then begin
   TTweeningEffect(effect).Free;
   effect:=nil;
  end;
 finally lock:=0; end;
end;

procedure TTweening.Assign(const v;count:integer);
var
 i:integer;
 src:PSingle;
begin
 ASSERT((count>=1) and (count<=4));
 SpinLock(lock);
 try
  self.count:=count;
  src:=@v;
  for i:=0 to count-1 do begin
   curValues[i]:=src^;
   inc(src);
  end;
  if effect<>nil then begin
   TTweeningEffect(effect).Free;
   effect:=nil;
  end;
 finally lock:=0; end;
end;

function TTweening.CalcValue(index:integer; time:int64):single;
var
 eff:TTweeningEffect;
 u,s,comp:single;
begin
 eff:=TTweeningEffect(effect);
 if eff=nil then exit(curValues[index]);
 if time<=eff.startTime then exit(eff.startValue[index]);
 if time>=eff.endTime then exit(eff.endValue[index]);
 // normalize time to [0,1] using int64 arithmetic to avoid single precision loss
 u:=(time-eff.startTime)/eff.duration;
 // spline value (pass normalized u instead of absolute timestamps)
 s:=eff.spline(u,0,1,eff.startValue[index],eff.endValue[index]);
 // compensating function: g(u) = compensation[i] * u * (1-u)^2
 comp:=eff.compensation[index]*u*(1-u)*(1-u);
 result:=s+comp;
end;

procedure TTweening.FinalizeEffect(time:int64);
var
 eff:TTweeningEffect;
 i:integer;
begin
 eff:=TTweeningEffect(effect);
 if eff=nil then exit;
 if time>=eff.endTime then begin
  for i:=0 to count-1 do
   curValues[i]:=eff.endValue[i];
  eff.Free;
  effect:=nil;
 end;
end;

function TTweening.Value:single;
var
 time:int64;
begin
 SpinLock(lock);
 try
  time:=CoreTime.Ticks;
  result:=CalcValue(0,time);
  FinalizeEffect(time);
 finally lock:=0; end;
end;

function TTweening.IntValue:integer;
begin
 result:=round(Value);
end;

procedure TTweening.GetValue(out v; time:int64);
var
 i:integer;
 dst:PSingle;
begin
 SpinLock(lock);
 try
  if time<=0 then time:=CoreTime.Ticks;
  dst:=@v;
  for i:=0 to count-1 do begin
   dst^:=CalcValue(i,time);
   inc(dst);
  end;
  FinalizeEffect(time);
 finally lock:=0; end;
end;

function TTweening.FinalValue:single;
var
 eff:TTweeningEffect;
begin
 SpinLock(lock);
 try
  eff:=TTweeningEffect(effect);
  if eff<>nil then
   result:=eff.endValue[0]
  else
   result:=curValues[0];
 finally lock:=0; end;
end;

function TTweening.IsAnimating(time:int64):boolean;
var
 eff:TTweeningEffect;
begin
 SpinLock(lock);
 try
  eff:=TTweeningEffect(effect);
  if eff<>nil then begin
   if time<=0 then time:=CoreTime.Ticks;
   result:=time<eff.endTime;
  end else
   result:=false;
 finally lock:=0; end;
end;

procedure TTweening.Animate(const newValues; duration:cardinal;
  spline:TSplineFunc; delay:integer);
var
 i:integer;
 eff,oldEff:TTweeningEffect;
 time:int64;
 curSpeed,splineSpeed:single;
 src:PSingle;
 hasSpeed:boolean;
begin
 ASSERT(count>=1,'TTweening not initialized');
 if @spline=nil then spline:=splines.linear;
 SpinLock(lock);
 try
  time:=CoreTime.Ticks;
  // capture current values and speed from running animation
  hasSpeed:=false;
  oldEff:=TTweeningEffect(effect);
  if oldEff<>nil then begin
   hasSpeed:=(time>oldEff.startTime) and (time<oldEff.endTime);
   oldEff:=TTweeningEffect(effect); // save ref before clearing
  end;
  if (duration=0) and (delay=0) then begin
   // instant assignment
   src:=@newValues;
   for i:=0 to count-1 do begin
    curValues[i]:=src^;
    inc(src);
   end;
   if oldEff<>nil then begin oldEff.Free; effect:=nil; end;
   exit;
  end;
  // sample current state from old effect
  if oldEff<>nil then begin
   for i:=0 to count-1 do
    curValues[i]:=CalcValue(i,time);
  end;
  // create new effect
  eff:=TTweeningEffect.Create;
  eff.startTime:=time+delay;
  eff.duration:=duration;
  eff.endTime:=eff.startTime+duration;
  eff.spline:=spline;
  src:=@newValues;
  for i:=0 to count-1 do begin
   eff.startValue[i]:=curValues[i];
   eff.endValue[i]:=src^;
   // compute compensation = deltaSpeed * duration
   if hasSpeed then begin
    // current speed (value/ms) via finite difference
    curSpeed:=CalcValue(i,time)-CalcValue(i,time-1);
    // spline's own initial speed (value/ms): evaluate at u=1/duration
    splineSpeed:=spline(1.0/duration,0,1,
      eff.startValue[i],eff.endValue[i])-eff.startValue[i];
    eff.compensation[i]:=(curSpeed-splineSpeed)*duration;
   end else
    eff.compensation[i]:=0;
   inc(src);
  end;
  // release old effect after we're done reading from it
  if oldEff<>nil then oldEff.Free;
  effect:=eff;
 finally lock:=0; end;
end;

procedure TTweening.Animate(newValue:single; duration:cardinal;
  spline:TSplineFunc; delay:integer);
var
 val:single;
begin
 if count=0 then begin
  count:=1;
  curValues[0]:=0;
 end;
 val:=newValue;
 Animate(val,duration,spline,delay);
end;

end.
