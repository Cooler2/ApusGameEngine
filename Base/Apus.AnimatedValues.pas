// Object for a numeric value with smooth animation over time
//
// Copyright (C) 2018 Apus Software
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.AnimatedValues;

interface
  uses Apus.Types;

  type
    // Одиночная анимация значения
    TSingleAnimation=record
      startTime,endTime:int64;
      value1,value2:single;
      spline:TSplineFunc;
    end;

    // Произвольная анимация значения
    PAnimatedValue=^TAnimatedValue;
    TAnimatedValue=object
      logName:string; // Если строка не пустая - все операции будут логироваться
      // Init object with given value (not for assignment!)
      constructor Init(initValue:single=0);
      // Init object by copying another object
      constructor Clone(var v:TAnimatedValue);
      // Assign new value (removes any current animations)
      constructor Assign(initValue:single);
      procedure Free; // no need to call this if value is not animating now
      // Начать новую анимацию: к указанному значению в течение указанного времени
      // Если текущая анимация приводит к тому же значению - новая не создаётся
      // Если конечное значение совпадает с начальным - анимация не создаётся
      procedure Animate(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
        delay:integer=0);
      // То же самое, что animate, но сработает только если finalvalue<>newValue
      procedure AnimateIf(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
        delay:integer=0);
      // Возвращает значение анимируемой величины в текущий момент времени
      function Value:single;
      function IntValue:integer; inline;
      // Возвращает значение величины в указанный момент (0 - текущий момент)
      function ValueAt(time:int64):single;
      function FinalValue:single; // What the value will be when animation finished?
      function IsAnimating(time:int64=0):boolean; // Is value animating now?
      // Производная (скорость изменения) в текущий (указанный) момент времени
      // Если анимации нет - то 0
      function Derivative:double;
      function DerivativeAt(time:int64):double;
    private
      lock:integer;
      initialValue:single;
      animations: array of TSingleAnimation;
      // Запоминает последние значения чтобы не вычислять повторно
      lastValue:single;
      lastTime:cardinal;
      function InternalValueAt(time:int64):single; // No lock!
    end;

  var
   sfLinear:TSplineFunc;
   sfEaseOut:TSplineFunc;
   sfEaseIn:TSplineFunc;
   sfEaseInOut:TSplineFunc;


implementation
  uses
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
    Apus.Common, Apus.CrossPlatform, SysUtils;

  procedure SpinLock(var lock:integer); inline;
    begin
      // LOCK CMPXCHG is very slow (~20-50 cycles) so no need for additional spin rounds for quick operations
      while InterlockedCompareExchange(lock,1,0)<>0 do sleep(0);
    end;

  // TAnimatedValue - numeric interpolation class
  constructor TAnimatedValue.Init(initValue:single=0);
    begin
      SetLength(animations,0);
      initialValue:=initValue;
      logName:='';
      lastTime:=0;
      lastValue:=0;
      lock:=0;
    end;

  constructor TAnimatedValue.Assign(initValue:single);
    begin
      SpinLock(lock);
      try
        SetLength(animations,0);
        initialValue:=initValue;
        if logName<>'' then
            LogMessage(logName+' := '+floatToStrF(initialValue,ffGeneral,5,0));
        lastTime:=0;
        lastValue:=0;
      finally
        lock:=0;
      end;
    end;

  constructor TAnimatedValue.Clone(var v:TAnimatedValue);
    var
      i:integer;
    begin
      SpinLock(lock);
      try
        initialValue:=v.initialValue;
        SetLength(animations,length(v.animations));
        for i:=0 to high(animations) do
            animations[i]:=v.animations[i];
        logName:=v.logName;
        lastTime:=0;
        lastValue:=0;
      finally
        lock:=0;
      end;
    end;

  procedure TAnimatedValue.Free;
    begin
      SpinLock(lock);
      try
          SetLength(animations,0);
      finally
        lock:=0;
      end;
    end;

  function TAnimatedValue.Derivative:double;
    begin
      result:=DerivativeAt(MyTickCount);
    end;

  function TAnimatedValue.DerivativeAt(time:int64):double;
    begin
      SpinLock(lock);
      try
          result:=(InternalValueAt(time+1)-InternalValueAt(time))*1000;
      finally
        lock:=0;
      end;
    end;

  function TAnimatedValue.FinalValue:single;
    begin
      SpinLock(lock);
      try
        if length(animations)>0 then
            result:=animations[length(animations)-1].value2
        else
            result:=initialValue;
      finally
        lock:=0;
      end;
    end;

  function TAnimatedValue.ValueAt(time:int64):single;
    begin
      SpinLock(lock);
      try
          result:=InternalValueAt(time);
      finally
        lock:=0;
      end;
    end;

  function TAnimatedValue.InternalValueAt(time:int64):single;
    var
      i:integer;
      v,r,k:double;
      t:int64;
    begin
      result:=initialValue;
      i:=length(animations)-1;
      if i<0 then exit;
      if time=0 then t:=MyTickCount
      else t:=time;

      if (t>=animations[i].endTime) then
        if time=0 then begin // все анимации уже в прошлом
            initialValue:=animations[i].value2;
            if logName<>'' then
                LogMessage(IntToStr(MyTickCount mod 1000)+'>'+
                IntToStr(animations[i].endTime mod 1000)+
                ' '+logName+' finish at '+floatToStrF(initialValue,ffGeneral,5,0));
            SetLength(animations,0);
            result:=initialValue;
            exit;
          end
        else begin
            result:=animations[i].value2;
            exit;
          end;
      if cardinal(t)=lastTime then begin
          result:=lastValue;
          exit;
        end;
      // Вычисление значения из текущих анимаций
      for i:=0 to length(animations)-1 do
        with animations[i] do begin
            if t>=endTime then v:=value2
            else
            if t<=startTime then v:=value1
            else begin
                v:=spline(t-startTime,0,endTime-startTime,value1,value2);
                // if LogName<>'' then LogMessage(' '+logName+' '+Format('%f %d %d %f',[t,startTime,endTime,v]));
              end;
            // Overlap?
            if (i>0) and (animations[i-1].endTime>startTime) and (t<animations[i-1].endTime) then begin
                r:=animations[i-1].endTime;
                if endTime<r then r:=endTime;
                if (r-animations[i-1].startTime)<>0 then // почему так?
                    k:=(startTime-animations[i-1].startTime)/(r-animations[i-1].startTime)
                else k:=0;
                if k>1 then k:=1;
                if r-startTime=0 then k:=1 // zero overlap size (never occurs)
                  // else k:=k*(r-t)/(r-startTime);
                else k:=Spline1((r-t)/(r-startTime),0,1,0,k);
                if k>1 then k:=1;
                result:=result*k+v*(1-k);
                // result:=v;
              end
            else
              if t>=startTime then result:=v;
          end;
      lastTime:=cardinal(t);
      lastValue:=result;
      if logName<>'' then
          LogMessage(IntToStr(t mod 1000)+' '+logName+' '+Format('%f',[result]));
    end;

  function TAnimatedValue.IntValue:integer;
    begin
      result:=round(ValueAt(0));
    end;

  function TAnimatedValue.Value:single;
    begin
      result:=ValueAt(0);
    end;

  function TAnimatedValue.IsAnimating(time:int64):boolean;
    begin
      SpinLock(lock);
      try
        if length(animations)>0 then begin
           if time<=0 then time:=MyTickCount;
           result:=time<animations[length(animations)-1].endTime;
          end
        else
            result:=false;
      finally
        lock:=0;
      end;
    end;

  procedure TAnimatedValue.AnimateIf(newValue:single; duration:cardinal;
    spline:TSplineFunc=nil; delay:integer=0);
    begin
      if FinalValue<>newValue then
          Animate(newValue,duration,spline,delay);
    end;

  procedure TAnimatedValue.Animate(newValue:single; duration:cardinal; spline:TSplineFunc=nil;
    delay:integer=0);
    var
      n:integer;
      v:single;
      t:int64;
    begin
      if PtrUInt(@Self)<4096 then raise EError.Create('Animating invalid object');
      if @spline=nil then spline:=splines.linear;
      SpinLock(lock);
      try
        try
          if (duration=0)and(delay=0) then begin
              if logName<>'' then
                  LogMessage(logName+' := '+floatToStrF(newValue,ffGeneral,5,0));
              initialValue:=newValue;
              SetLength(animations,0);
              exit;
            end;
          lastTime:=0;
          lastValue:=0;
          n:=length(animations);
          if (n=0)and(initialValue=newValue) then exit; // no change
          if (n>0)and(animations[n-1].value2=newValue) then exit;
          // animation to the same value
          t:=MyTickCount+delay;
          if n=0 then v:=initialValue
          else
            if delay=0 then v:=InternalValueAt(0)
          else
              v:=InternalValueAt(t);
          // особый случай - анимация после начала других анимаций, т.е. не с текущего значения

          SetLength(animations,n+1);
          animations[n].startTime:=t;
          animations[n].endTime:=t+duration;
          animations[n].value1:=v;
          animations[n].value2:=newValue;
          animations[n].spline:=spline;
          if logName<>'' then
              LogMessage(logName+'['+IntToStr(n)+'] '+floatToStrF(v,ffGeneral,5,0)+
              ' --> '+floatToStrF(newValue,ffGeneral,5,0)+' '+IntToStr(delay)+'+'+
              IntToStr(duration)+
              Format(' %d %d',[animations[n].startTime mod 1000,
              animations[n].endTime mod 1000]));
        except
          on e:Exception do
              raise EError.Create('Animate '+inttohex(PtrUInt(@Self),8)+' error: '+
              e.message);
        end;
      finally
        lock:=0;
      end;
    end;

initialization
  sfLinear:=Spline0;
  sfEaseOut:=Spline2;
  sfEaseIn:=Spline2rev;
  sfEaseInOut:=Spline1;
end.
