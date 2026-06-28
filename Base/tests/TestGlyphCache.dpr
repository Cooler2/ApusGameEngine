{$APPTYPE CONSOLE}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
program TestGlyphCache;
uses
  SysUtils,
  types,
  Apus.Core,
  Apus.GlyphCache;

{$INCLUDE Test.inc}

// Basic alloc/find round-trip and metadata packing (TGlyphRec: byte w/h, shortint dx/dy)
procedure TestAllocFind;
var
  c:TDynamicGlyphCache;
  p:TPoint;
  g:TGlyphInfoRec;
begin
  StartTest('GlyphCache.AllocFind');
  c:=TDynamicGlyphCache.Create(256,128);
  try
    // width 200 is > 127: validates byte storage for w/h (would truncate with shortint)
    p:=c.Alloc(200,40,-100,120,$410041);
    Check((p.x>=0) and (p.y>=0),'alloc returns valid position');
    g:=c.Find($410041);
    Check((g.x=p.x) and (g.y=p.y),'find returns alloc position');
    Check((g.width=200) and (g.height=40),'find returns w/h (byte range)');
    Check((g.dx=-100) and (g.dy=120),'find returns dx/dy (shortint range)');
    g:=c.Find($999999);
    Check(g.x=-1,'missing glyph returns x=-1');
  finally
    c.Free;
  end;
  EndTest;
end;

// relX/relY must be applied identically by Alloc and Find (the side-cache offset)
procedure TestRelativeOffset;
var
  c:TDynamicGlyphCache;
  p:TPoint;
  g:TGlyphInfoRec;
begin
  StartTest('GlyphCache.RelativeOffset');
  c:=TDynamicGlyphCache.Create(64,128);
  try
    c.relX:=1000;
    c.relY:=500;
    p:=c.Alloc(10,12,0,0,$41);
    Check(p.x>=1000,'alloc x includes relX');
    Check(p.y>=500,'alloc y includes relY');
    g:=c.Find($41);
    Check((g.x=p.x) and (g.y=p.y),'find matches alloc with offset');
  finally
    c.Free;
  end;
  EndTest;
end;

// Keep+Alloc cycle (as TextDraw does per frame): old glyphs evicted, recent ones survive, no overflow
procedure TestEvictionCycle;
var
  c:TDynamicGlyphCache;
  i:integer;
  g:TGlyphInfoRec;
  recentOk:boolean;
  failMsg:String8;
begin
  StartTest('GlyphCache.EvictionCycle');
  // small cache: a handful of 16px bands -> forces eviction over the loop
  c:=TDynamicGlyphCache.Create(128,64);
  try
    recentOk:=true; failMsg:='';
    for i:=0 to 199 do begin
      c.Keep; // mimic per-frame call before drawing
      c.Alloc(16,16,0,0,cardinal(i+1));
      g:=c.Find(cardinal(i+1)); // just-allocated glyph must be present
      if g.x<0 then begin
        recentOk:=false; failMsg:='glyph '+IntToStr(i+1)+' missing right after alloc';
        break;
      end;
    end;
    Check(recentOk,'every glyph findable right after alloc (no overflow); '+failMsg);
    // the very first glyph was allocated ~200 iterations ago -> long evicted
    g:=c.Find(cardinal(1));
    Check(g.x=-1,'oldest glyph evicted by Keep');
    // the last one is still there
    g:=c.Find(cardinal(200));
    Check(g.x>=0,'newest glyph still cached');
  finally
    c.Free;
  end;
  EndTest;
end;

// Re-allocating the same key after its band was evicted must work (fresh entry)
procedure TestReallocAfterEvict;
var
  c:TDynamicGlyphCache;
  i:integer;
  g:TGlyphInfoRec;
begin
  StartTest('GlyphCache.ReallocAfterEvict');
  c:=TDynamicGlyphCache.Create(128,64);
  try
    c.Alloc(16,16,0,0,$1234);
    Check(c.Find($1234).x>=0,'key present after first alloc');
    // churn until $1234 is evicted
    for i:=0 to 199 do begin
      c.Keep;
      c.Alloc(16,16,0,0,cardinal(1000+i));
    end;
    Check(c.Find($1234).x=-1,'key evicted after churn');
    // re-allocate the same key
    c.Keep;
    c.Alloc(16,16,0,0,$1234);
    g:=c.Find($1234);
    Check(g.x>=0,'key findable after re-alloc');
  finally
    c.Free;
  end;
  EndTest;
end;

procedure TestCapacityErrors;
var
  c:TDynamicGlyphCache;
  msg:string;
begin
  StartTest('GlyphCache.CapacityErrors');
  c:=TDynamicGlyphCache.Create(64,64);
  try
    msg:='';
    try
      c.Alloc(65,10,0,0,$2001);
    except
      on e:Exception do msg:=e.Message;
    end;
    Check(Pos('does not fit the 64x64 atlas region',msg)>0,
      'oversized item rejected before packing: '+msg);

    c.Alloc(64,40,0,0,$2002);
    msg:='';
    try
      c.Alloc(64,40,0,0,$2003);
    except
      on e:Exception do msg:=e.Message;
    end;
    Check(Pos('GlyphCache atlas exhausted',msg)>0,
      'atlas exhaustion has a descriptive error: '+msg);
  finally
    c.Free;
  end;
  EndTest;
end;

begin
  try
    TestAllocFind;
    TestRelativeOffset;
    TestEvictionCycle;
    TestReallocAfterEvict;
    TestCapacityErrors;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Exception: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
