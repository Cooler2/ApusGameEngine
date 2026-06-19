// Toast notifications — transient, non-modal pop-up messages drawn as an overlay
// on top of all scenes (a sibling of the debug overlays, but product-facing).
//
// Entry point: ShowToast / IGame.FireMessage. Appearance is themed via the R-05
// style catalog (style blocks named toast.<kind>). Text may carry SML markup.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// -----------------------------------------------------
unit Apus.Engine.Notifications;
interface
 uses Types, Apus.Core, Apus.Engine.API;

 {$SCOPEDENUMS ON}
 type
  // Theme-aware severity: each maps to a named style block (see toastConfig.stylePrefix)
  TToastKind=(Info,Success,Warning,Error);
  // Screen anchor for a toast stack (all bottom + window center)
  TToastAnchor=(BottomRight,BottomCenter,BottomLeft,Center);

  // Per-toast options. Default-valued fields fall back to toastConfig.
  // Build via ForKind to inherit config defaults, then tweak.
  TToastOptions=record
   kind:TToastKind;        // severity / color set
   anchor:TToastAnchor;    // placement
   duration:single;        // seconds; 0 => auto from text length; <0 => sticky (until click)
   style:String8;          // explicit style-block name, overrides kind (optional)
   class function ForKind(k:TToastKind):TToastOptions; static;
  end;

 var
  toastConfig:record
   anchor:TToastAnchor;              // default placement
   minDuration,maxDuration:single;   // auto-timing clamp, seconds (hard upper cap)
   readingSpeed:single;              // chars/sec used for auto duration
   fadeIn,fadeOut:single;            // entry / exit animation, seconds
   maxVisible:integer;               // per-anchor visible cap; overflow queues
   gap:integer;                      // px between stacked toasts
   margin:TPoint;                    // px inset from screen edge
   maxWidth:integer;                 // px wrap/box cap
   font:TFontHandle;                 // 0 => default UI font
   stylePrefix:String8;              // e.g. 'toast.' => 'toast.info'
  end;

 // Register default styles and config. Called once by GameApp after InitStyles.
 procedure InitNotifications;

 // Show a toast. Text may contain SML markup ({B}bold{/B}, {C=..}color, ...).
 procedure ShowToast(text:String8); overload;
 procedure ShowToast(text:String8;kind:TToastKind); overload;
 procedure ShowToast(text:String8;const opt:TToastOptions); overload;

 // Dismiss all currently shown toasts (with fade-out).
 procedure ClearToasts;

 // Advance + draw all toasts. Called every frame from the overlay slot
 // (TGame.DrawOverlays), on the render thread.
 procedure DrawNotifications;

implementation
 uses Apus.Strings, Apus.Threads, Apus.Engine.Window, Apus.Engine.Style;

 type
  TToastPhase=(Entering,Visible,Leaving);

  TToast=record
   text:String8;          // original SML text
   lines:Strings8;        // text split into display lines
   kind:TToastKind;
   anchor:TToastAnchor;
   styleName:String8;
   duration:single;       // seconds to stay Visible; <0 => sticky
   age:single;            // seconds spent Visible (frozen while hovered)
   phase:TToastPhase;
   anim:single;           // 0..1 dissolve progress (alpha)
   width,height:single;   // box size, px
   y:single;              // current stack offset from anchor edge (lerped)
   targetY:single;        // desired stack offset
   placed:boolean;        // false until first laid out (snap, don't animate, on entry)
   rect:TRect;            // last drawn screen rect (for hit-test)
  end;
  TToasts=array of TToast;

  TPendingToast=record
   text:String8;
   opt:TToastOptions;
  end;
  TPendingToasts=array of TPendingToast;

 var
  toasts:TToasts;                  // active list, render-thread only
  pending:TPendingToasts;          // ingest buffer, guarded by lock
  lock:TLock;
  lastTick:int64;
  defFont:TFontHandle;
  prevLeftDown:boolean;
  initialized:boolean;

 const
  padX=14;       // horizontal text inset
  padTop=9;      // top text inset
  padBottom=11;  // bottom text inset

{ TToastOptions }

class function TToastOptions.ForKind(k:TToastKind):TToastOptions;
 begin
  result.kind:=k;
  result.anchor:=toastConfig.anchor;
  result.duration:=0;  // auto
  result.style:='';
 end;

{ Helpers }

function KindName(k:TToastKind):String8;
 begin
  case k of
   TToastKind.Success:result:='success';
   TToastKind.Warning:result:='warning';
   TToastKind.Error:result:='error';
   else result:='info';
  end;
 end;

// Scale the alpha (high byte) of an $AARRGGBB color by a in [0..1].
function ScaleAlpha(color:cardinal;a:single):cardinal;
 var
  al:integer;
 begin
  al:=round(((color shr 24) and $FF)*a);
  if al<0 then al:=0;
  if al>255 then al:=255;
  result:=(color and $00FFFFFF) or (cardinal(al) shl 24);
 end;

// Strip SML markup ({tag}, {tag=val}) for measurement. Approximate: good enough
// for auto-duration timing and box-width estimation, not for exact layout.
function StripSML(const text:String8):String8;
 var
  i,len:integer;
 begin
  result:='';
  i:=1; len:=length(text);
  while i<=len do begin
   if text[i]='{' then begin
    if (i<len) and (text[i+1]='{') then begin
     result:=result+'{'; inc(i,2); continue; // {{ => literal brace
    end;
    while (i<=len) and (text[i]<>'}') do inc(i); // skip tag body
    inc(i);                                      // skip closing }
   end else begin
    result:=result+text[i]; inc(i);
   end;
  end;
 end;

// Plain-text length of an SML string (markup stripped), used for auto duration.
function PlainLen(const text:String8):integer;
 begin
  if Pos('{',text)>0 then result:=length(StripSML(text))
   else result:=length(text);
 end;

{ Public API }

procedure InitNotifications;
 procedure DefStyle(const name,def:String8);
  begin // only set if the app hasn't already themed it
   if Styles[name]='' then Styles[name]:=def;
  end;
 begin
  if initialized then exit; // idempotent: GameApp + lazy ShowToast both may call
  with toastConfig do begin
   anchor:=TToastAnchor.BottomRight;
   minDuration:=2.0;
   maxDuration:=5.0;
   readingSpeed:=25;
   fadeIn:=0.2;
   fadeOut:=0.3;
   maxVisible:=5;
   gap:=8;
   margin:=Point(16,16);
   maxWidth:=360;
   font:=0;
   stylePrefix:='toast.';
  end;
  // Default themed look (fill:AARRGGBB; border; color=text; radius)
  // Translucent background + slightly translucent border; text stays opaque.
  DefStyle('toast.info',   'fill:A0303840; border:C05878A0; color:FFE8F0FF; radius:8');
  DefStyle('toast.success','fill:A0204028; border:C040A860; color:FFE0FFE8; radius:8');
  DefStyle('toast.warning','fill:A0403018; border:C0C89030; color:FFFFF0D0; radius:8');
  DefStyle('toast.error',  'fill:A0401820; border:C0C04040; color:FFFFE0E0; radius:8');
  lock.Init('Notifications');
  initialized:=true;
 end;

procedure ShowToast(text:String8);
 begin
  ShowToast(text,TToastOptions.ForKind(TToastKind.Info));
 end;

procedure ShowToast(text:String8;kind:TToastKind);
 begin
  ShowToast(text,TToastOptions.ForKind(kind));
 end;

procedure ShowToast(text:String8;const opt:TToastOptions);
 var
  n:integer;
 begin
  if not initialized then InitNotifications;
  lock.Enter;
  try
   n:=length(pending);
   SetLength(pending,n+1);
   pending[n].text:=text;
   pending[n].opt:=opt;
  finally
   lock.Leave;
  end;
 end;

procedure ClearToasts;
 var
  i:integer;
 begin
  for i:=0 to high(toasts) do
   if toasts[i].phase<>TToastPhase.Leaving then
    toasts[i].phase:=TToastPhase.Leaving;  // anim keeps current value, fades from there
 end;

{ Layout / construction (render thread) }

// Resolve the font used for toast text.
function ResolveFont:TFontHandle;
 begin
  result:=toastConfig.font;
  if result=0 then begin
   if defFont=0 then defFont:=txt.GetFont('Default',7);
   result:=defFont;
  end;
 end;

// Measure a single (possibly SML) line width in pixels.
function LineWidth(font:TFontHandle;const line:String8):integer;
 begin
  if Pos('{',line)>0 then result:=txt.Width(font,StripSML(line)) // approx (ignores bold widen)
   else result:=txt.Width(font,line);
 end;

// Word-wrap a plain line to maxTextWidth. SML lines are kept intact (tag-safe).
procedure WrapLine(font:TFontHandle;const line:String8;maxTextWidth:integer;var dst:Strings8);
 var
  words:Strings8;
  cur,probe:String8;
  w:String8;
 begin
  if (Pos('{',line)>0) or (LineWidth(font,line)<=maxTextWidth) then begin
   dst.Add(line);
   exit;
  end;
  words:=line.Split(' ');
  cur:='';
  for w in words do begin
   if cur='' then probe:=w
    else probe:=cur+' '+w;
   if (cur<>'') and (txt.Width(font,probe)>maxTextWidth) then begin
    dst.Add(cur);
    cur:=w;
   end else
    cur:=probe;
  end;
  if cur<>'' then dst.Add(cur);
 end;

// Build a TToast from raw text+options: resolve style/duration, split+wrap, measure.
function BuildToast(const text:String8;const opt:TToastOptions):TToast;
 var
  font:TFontHandle;
  paras:Strings8;
  para,line:String8;
  maxTextWidth,lw,maxLW,lh:integer;
 begin
  result:=Default(TToast); // zero-init (age/y/placed/rect), managed fields cleared
  result.text:=text;
  result.kind:=opt.kind;
  result.anchor:=opt.anchor;
  if opt.style<>'' then result.styleName:=opt.style
   else result.styleName:=toastConfig.stylePrefix+KindName(opt.kind);
  // Duration
  if opt.duration<>0 then result.duration:=opt.duration
  else
   result.duration:=Clamp(PlainLen(text)/toastConfig.readingSpeed,
                          toastConfig.minDuration,toastConfig.maxDuration);
  result.phase:=TToastPhase.Entering;
  result.anim:=0;

  font:=ResolveFont;
  maxTextWidth:=toastConfig.maxWidth-2*padX;
  // Honor author line breaks ('~', CR, LF), then word-wrap plain lines.
  result.lines:=nil;
  para:=text.ReplaceAll(#13#10,#10).ReplaceAll(#13,#10).ReplaceAll('~',#10);
  paras:=para.Split(#10);
  for line in paras do
   WrapLine(font,line,maxTextWidth,result.lines);
  if length(result.lines)=0 then result.lines.Add('');

  // Measure box
  maxLW:=0;
  for line in result.lines do begin
   lw:=LineWidth(font,line);
   if lw>maxLW then maxLW:=lw;
  end;
  if maxLW>maxTextWidth then maxLW:=maxTextWidth;
  lh:=round(txt.Height(font)*1.7);
  result.width:=maxLW+2*padX;
  result.height:=padTop+padBottom+length(result.lines)*lh;
 end;

// Count active (non-leaving) toasts at an anchor.
function AnchorLoad(anchor:TToastAnchor):integer;
 var
  i:integer;
 begin
  result:=0;
  for i:=0 to high(toasts) do
   if (toasts[i].anchor=anchor) and (toasts[i].phase<>TToastPhase.Leaving) then inc(result);
 end;

// Move pending toasts into the active list, respecting per-anchor maxVisible.
procedure DrainPending;
 var
  i,n:integer;
  kept:TPendingToasts;
  item:TPendingToast;
  t:TToast;
 begin
  lock.Enter;
  try
   if length(pending)=0 then exit;
   kept:=nil;
   for i:=0 to high(pending) do begin
    item:=pending[i];
    if AnchorLoad(item.opt.anchor)>=toastConfig.maxVisible then begin
     n:=length(kept); SetLength(kept,n+1); kept[n]:=item; // overflow stays queued
     continue;
    end;
    t:=BuildToast(item.text,item.opt);
    n:=length(toasts); SetLength(toasts,n+1); toasts[n]:=t;
   end;
   pending:=kept;
  finally
   lock.Leave;
  end;
 end;

{ Per-frame update + draw }

// Compute the on-screen rect of a toast given its current stack offset.
// Position is purely by stack offset y; the animation is a dissolve (alpha only).
function ToastRect(const t:TToast):TRect;
 var
  rw,rh,bx,by:integer;
  left,top:integer;
 begin
  rw:=window.renderWidth;
  rh:=window.renderHeight;
  case t.anchor of
   TToastAnchor.BottomLeft:   left:=toastConfig.margin.x;
   TToastAnchor.BottomCenter: left:=(rw-round(t.width)) div 2;
   TToastAnchor.Center:       left:=(rw-round(t.width)) div 2;
   else {BottomRight}         left:=rw-toastConfig.margin.x-round(t.width);
  end;
  if t.anchor=TToastAnchor.Center then begin
   by:=rh div 2;                    // stack downward from center
   top:=by+round(t.y);
  end else begin
   by:=rh-toastConfig.margin.y;     // bottom edge
   top:=by-round(t.y)-round(t.height);
  end;
  bx:=left;
  result:=Rect(bx,top,bx+round(t.width),top+round(t.height));
 end;

// Recompute target stack offsets and animate y toward them.
procedure Layout(dt:single);
 var
  a:TToastAnchor;
  i:integer;
  off:single;
 begin
  for a:=Low(TToastAnchor) to High(TToastAnchor) do begin
   off:=0;
   // newest (end of list) sits nearest the anchor edge
   for i:=high(toasts) downto 0 do
    if toasts[i].anchor=a then begin
     toasts[i].targetY:=off;
     off:=off+toasts[i].height+toastConfig.gap;
    end;
  end;
  for i:=0 to high(toasts) do
   with toasts[i] do begin
    if not placed then begin
     y:=targetY; placed:=true; // first placement: snap to slot, then animate reflow
    end else
     y:=y+(targetY-y)*Clamp(dt*12,0.0,1.0);
   end;
 end;

procedure DrawToast(var t:TToast); // var: writes back t.rect for next-frame hit-test
 var
  block:TStyleBlock;
  fill,border,textCol:cardinal;
  radius:single;
  font:TFontHandle;
  r:TRect;
  i,lh,baseLine:integer;
 begin
  block:=Styles.Block(t.styleName);
  fill:=ResolveBlockColor(block,'fill',$E0303840);
  border:=ResolveBlockColor(block,'border',$FF5878A0);
  textCol:=ResolveBlockColor(block,'color',$FFFFFFFF);
  radius:=ResolveBlockNumber(block,'radius',8);
  font:=ResolveFont;

  r:=ToastRect(t);
  t.rect:=r;
  // Background + border (alpha follows fade)
  draw.RoundRect(r.Left,r.Top,r.Right,r.Bottom,radius,1.5,
                 ScaleAlpha(border,t.anim),ScaleAlpha(fill,t.anim));
  // Text lines
  lh:=round(txt.Height(font)*1.7);
  textCol:=ScaleAlpha(textCol,t.anim);
  baseLine:=r.Top+padTop+txt.Height(font);
  for i:=0 to high(t.lines) do begin
   txt.Write(font,r.Left+padX,baseLine,textCol,t.lines[i],TTextAlignment.taLeft,toComplexText);
   inc(baseLine,lh);
  end;
 end;

procedure DrawNotifications;
 var
  now:int64;
  dt:single;
  i:integer;
  leftDown,clicked,hovered:boolean;
 begin
  if not initialized then exit;
  now:=CoreTime.Ticks;
  if lastTick=0 then lastTick:=now;
  dt:=(now-lastTick)/1000;
  lastTick:=now;
  if dt>0.1 then dt:=0.1;  // clamp after a stall

  DrainPending;
  if length(toasts)=0 then begin
   prevLeftDown:=(window.mouseButtons and 1)<>0;
   exit;
  end;

  leftDown:=(window.mouseButtons and 1)<>0;
  clicked:=leftDown and not prevLeftDown;  // left-button press edge

  // Update lifecycle
  for i:=0 to high(toasts) do
   with toasts[i] do begin
    hovered:=window.MouseInRect(rect);
    case phase of
     TToastPhase.Entering:begin
      anim:=anim+dt/Max(toastConfig.fadeIn,0.001);
      if anim>=1 then begin anim:=1; phase:=TToastPhase.Visible; end;
     end;
     TToastPhase.Visible:begin
      if hovered and clicked then phase:=TToastPhase.Leaving  // click-to-dismiss
      else
      if not hovered and (duration>=0) then begin  // hover freezes the countdown
       age:=age+dt;
       if age>=duration then phase:=TToastPhase.Leaving;
      end;
     end;
     TToastPhase.Leaving:begin
      anim:=anim-dt/Max(toastConfig.fadeOut,0.001);
      if anim<=0 then anim:=0;
     end;
    end;
   end;

  // Reap fully-faded toasts (Delete finalizes managed fields — no manual free)
  i:=0;
  while i<=high(toasts) do
   if (toasts[i].phase=TToastPhase.Leaving) and (toasts[i].anim<=0) then
    Delete(toasts,i,1)
   else inc(i);

  Layout(dt);
  for i:=0 to high(toasts) do DrawToast(toasts[i]);

  prevLeftDown:=leftDown;
 end;

end.
