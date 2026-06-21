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
{$I defines.inc}
unit Apus.Tweenings;
interface
uses Apus.Utils;

type
 TTweening=record
   type
     // Visible here only because `effect` field type must be known at the declaration site.
     // Treat as internal: access only via TTweening methods.
     TEffect=record
       startTime,endTime:int64;
       duration:cardinal;
       spline:TSplineFunc;
       startValue:array[0..3] of single;
       endValue:array[0..3] of single;
       compensation:array[0..3] of single; // deltaSpeed*duration per component
     end;
   // Set value immediately (cancel any animation)
   procedure Assign(value:single); overload;
   procedure Assign(const v;count:integer); overload;
   // Animate to new value over duration (ms), optional spline and delay
   procedure Animate(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0);
   // Animate 2..4 packed components (point/vector/color) synchronously.
   // Separate name (not an overload): an untyped const overload is ambiguous
   // with the scalar version under Delphi and silently captures scalar calls.
   procedure AnimateVec(const newValues; duration:cardinal; spline:TSplineFunc=nil;
      delay:integer=0);
   // Get current value(s)
   function Value:single;
   function IntValue:integer; inline;
   procedure GetValue(out v; time:int64=0);
   function FinalValue:single;
   function IsAnimating(time:int64=0):boolean;
   procedure Free; // release effect (also called automatically when going out of scope)
 private
   lock:integer;
   count:integer; // number of components (1..4)
   curValues:array[0..3] of single;
   // length=0: idle; length=1: animating.
   // Dynamic array: ref-counted in both Delphi and FPC — no custom Initialize/Finalize needed.
   effect:array of TEffect;
   procedure AnimateInternal(const newValues; duration:cardinal;
     spline:TSplineFunc; delay:integer);
   function CalcValue(index:integer; time:int64):single;
   function CalcValueFromEffect(const eff:TEffect; index:integer; time:int64):single;
   procedure FinalizeEffect(time:int64);
 end;

implementation
uses SysUtils, Apus.Core;

{ TTweening }


procedure TTweening.Free;
begin
 SpinLock(lock);
 try
  SetLength(effect,0);
 finally lock:=0; end;
end;

procedure TTweening.Assign(value:single);
begin
 SpinLock(lock);
 try
  count:=1;
  curValues[0]:=value;
  SetLength(effect,0);
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
  SetLength(effect,0);
 finally lock:=0; end;
end;

function TTweening.CalcValueFromEffect(const eff:TEffect; index:integer; time:int64):single;
var
 u,s,comp:single;
begin
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

function TTweening.CalcValue(index:integer; time:int64):single;
begin
 if length(effect)=0 then exit(curValues[index]);
 result:=CalcValueFromEffect(effect[0],index,time);
end;

procedure TTweening.FinalizeEffect(time:int64);
var i:integer;
begin
 if length(effect)=0 then exit;
 if time>=effect[0].endTime then begin
  for i:=0 to count-1 do
   curValues[i]:=effect[0].endValue[i];
  SetLength(effect,0);
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
begin
 SpinLock(lock);
 try
  if length(effect)>0 then
   result:=effect[0].endValue[0]
  else
   result:=curValues[0];
 finally lock:=0; end;
end;

function TTweening.IsAnimating(time:int64):boolean;
begin
 SpinLock(lock);
 try
  if length(effect)>0 then begin
   if time<=0 then time:=CoreTime.Ticks;
   result:=time<effect[0].endTime;
  end else
   result:=false;
 finally lock:=0; end;
end;

procedure TTweening.AnimateInternal(const newValues; duration:cardinal;
  spline:TSplineFunc; delay:integer);
var
 i:integer;
 saved:TEffect; // snapshot of old effect; plain record — safe to copy
 hasOldEff:boolean;
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
  hasOldEff:=length(effect)>0;
  hasSpeed:=false;
  if hasOldEff then begin
   saved:=effect[0]; // snapshot before any modification
   hasSpeed:=(time>saved.startTime) and (time<saved.endTime);
  end;
  if (duration=0) and (delay=0) then begin
   // instant assignment
   src:=@newValues;
   for i:=0 to count-1 do begin
    curValues[i]:=src^;
    inc(src);
   end;
   SetLength(effect,0);
   exit;
  end;
  // sample current position from old effect into curValues
  if hasOldEff then
   for i:=0 to count-1 do
    curValues[i]:=CalcValueFromEffect(saved,i,time);
  // write new effect directly into effect[0] — no intermediate array needed.
  // SetLength triggers COW if the array is shared, so copies are unaffected.
  SetLength(effect,1);
  effect[0].startTime:=time+delay;
  effect[0].duration:=duration;
  effect[0].endTime:=effect[0].startTime+duration;
  effect[0].spline:=spline;
  src:=@newValues;
  for i:=0 to count-1 do begin
   effect[0].startValue[i]:=curValues[i];
   effect[0].endValue[i]:=src^;
   // compute compensation = deltaSpeed * duration
   if hasSpeed and (duration>0) then begin
    // current speed (value/ms) via finite difference — reads saved (old snapshot)
    curSpeed:=CalcValueFromEffect(saved,i,time)-CalcValueFromEffect(saved,i,time-1);
    // spline's own initial speed (value/ms): evaluate at u=1/duration
    splineSpeed:=spline(1.0/duration,0,1,
      effect[0].startValue[i],effect[0].endValue[i])-effect[0].startValue[i];
    effect[0].compensation[i]:=(curSpeed-splineSpeed)*duration;
   end else
    effect[0].compensation[i]:=0;
   inc(src);
  end;
 finally lock:=0; end;
end;

procedure TTweening.AnimateVec(const newValues; duration:cardinal;
  spline:TSplineFunc; delay:integer);
begin
 AnimateInternal(newValues,duration,spline,delay);
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
 AnimateInternal(val,duration,spline,delay);
end;

end.
