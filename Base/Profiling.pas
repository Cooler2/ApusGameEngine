// Built-in Sampling Profiler
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
unit Profiling;
interface

 procedure AddThreadForProfiling(threadHandle:cardinal;name:string);
 procedure StartProfiling(freq:integer=50;maxSamples:integer=1000000);
 procedure StopProfiling;
 procedure PauseProfiling;
 procedure ResumeProfiling;
 procedure SaveProfilingResults(filename:string);

implementation
 uses windows,SysUtils,MyServis,classes;

 type
  TSample=record
   thread:integer;
   {$IFDEF CPU386}
   eip,caller:cardinal;
   {$ENDIF}
   {$IFDEF CPUX64}
   rip,caller:UInt64;
   {$ENDIF}
   res:cardinal;
  end;
  TProfiler=class(TThread)
    procedure Execute; override;
  end;
  TThreadInfo=record
   name:string[15];
   handle:THandle;
   kernelTime,userTime:int64;
   reserved:array[0..15] of byte;
  end;

 var
  profiler:TProfiler;
  interval:integer;
  samples:array of TSample;
  sCnt:integer;

  threads:array of TThreadInfo;

 procedure AddThreadForProfiling(threadhandle:cardinal;name:string);
  var
   n:integer;
  begin
   if profiler<>nil then raise EWarning.Create('Not allowed during profiling');
   n:=length(threads);
   SetLength(threads,n+1);
   threads[n].name:=name;
   threads[n].handle:=threadHandle;
  end;

 procedure StartProfiling(freq:integer=50;maxSamples:integer=1000000);
  begin
   if profiler=nil then begin
    interval:=1000 div freq;
    SetLength(samples,maxSamples);
    sCnt:=0;
    profiler:=TProfiler.Create(false);
   end else
    raise EWarning.Create('Profiling is already running');
  end;

 procedure StopProfiling;
  begin
   if profiler<>nil then begin
    profiler.Terminate;
    profiler.WaitFor;
    FreeAndNil(profiler);
   end;
  end;

 procedure PauseProfiling;
  begin
   if profiler<>nil then profiler.Suspend;
  end;

 procedure ResumeProfiling;
  begin
   if profiler<>nil then profiler.Resume;
  end;

 procedure SaveProfilingResults(filename:string);
  var
   f:file;
   i,v:integer;
  begin
   if profiler<>nil then
    if not profiler.Suspended then
     raise EWarning.Create('Profiling is running, stop or suspend it first');
   assign(f,filename);
   rewrite(f,1);
   v:=length(threads);
   blockwrite(f,v,4);
   for i:=0 to v-1 do
    blockwrite(f,threads[i],sizeof(threads[i]));
   blockwrite(f,sCnt,4);
   blockwrite(f,samples[0],sCnt*sizeof(TSample));
   close(f);
  end;

{ TProfiler }

 procedure TProfiler.Execute;
  var
   i:integer;
   h:cardinal;
   context:TContext;
   t1,t2,t3,t4:TFileTime;
  begin
   priority:=tpHighest;
   for i:=0 to length(threads)-1 do begin
    GetThreadTimes(threads[i].handle,t1,t2,t3,t4);
    threads[i].kernelTime:=t3.dwHighDateTime shl 32+t3.dwLowDateTime;
    threads[i].userTime:=t4.dwHighDateTime shl 32+t4.dwLowDateTime;
   end;
   repeat
    sleep(interval);
    for i:=0 to length(threads)-1 do begin
     h:=threads[i].handle;
     SuspendThread(h);
     context.ContextFlags:=CONTEXT_CONTROL;
     if GetThreadContext(h,context) then
      try
       samples[sCnt].thread:=i;
       {$IFDEF CPU386}
       samples[sCnt].eip:=context.Eip;
       samples[sCnt].caller:=PCardinal(context.Ebp+4)^;
       {$ENDIF}
       {$IFDEF CPUX64}
       samples[sCnt].rip:=context.rip;
       samples[sCnt].caller:=PCardinal(context.rbp+4)^;
       {$ENDIF}
       inc(sCnt);
      except
      end;
     ResumeThread(h);
     if sCnt>=length(samples) then exit;
    end;
   until terminated;
   for i:=0 to length(threads)-1 do
    with threads[i] do begin
     GetThreadTimes(handle,t1,t2,t3,t4);
     kernelTime:=(t3.dwHighDateTime shl 32+t3.dwLowDateTime)-kernelTime;
     userTime:=(t4.dwHighDateTime shl 32+t4.dwLowDateTime)-userTime;
    end;
  end;

end.

