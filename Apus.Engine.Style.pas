// R-05: CSS-like style system for UI elements
//
// Style text format:
//   key: value;                         -- attribute
//   @refname;                           -- named style reference (lower priority than local)
//   :state { key: value; key: value; }  -- state override block
//
// Patch syntax (for PatchText):
//   +key:value  -- add/overwrite attribute
//   -key        -- remove attribute
//   +@name      -- add named style ref
//   -@name      -- remove named style ref
//   !state:name   -- activate state
//   !state:-name  -- deactivate state
//   Multiple patches separated by ; or newline
//
// Cascade priority (lowest to highest), states beat plain values at every level:
//   1. @ref plain attributes (earlier listed = lower priority)
//   2. Local plain attributes
//   3. @ref ':state' blocks for the element's active states
//   4. Local ':state' blocks
// So a ':hover' block inside a named style applies to every element referencing it,
// even when that element sets the same key locally without a state.
//
// Canonical attribute vocabulary (kebab-case; CSS names where CSS has the concept).
// Drawers read ONLY these keys. Keys marked [inh] are inherited from the parent chain
// (see IsInheritedStyleKey); box chrome never inherits.
//
//  Box (chrome):
//   fill                 background <fill> (0 or none = no fill)
//   fill-shade           <fill> layer over the fill, inside the border (procedural buttons
//                        have a light-to-dark shade by default; 'none' removes it)
//   border-color         border <fill>; border-width;
//   radius               '<r>' or '<tl> <tr> <br> <bl>' (2 or 3 values as in CSS)
//   border-light         bevel highlight (button); border-dark  bevel shadow (button, frame)
//   inner-fill, inner-border-color, inner-radius, inner-border-width  (client-area block)
//   background-image     file:<name> | tex:<name> | none; drawn by the box path between fill and
//                        border; state blocks cross-fade images (':hover { background-image }')
//   background-tint      tint for background-image (neutral by default)
//   background-size      auto (native size in logical units, centered) | stretch (fills the box)
//   background-position  center (default) | top-left (native-size images only)
//   background-offset-x/y  image shift in logical units (state-able: ':pressed { ...-y:1 }')
//  Content:
//   font [inh]           font name;  font-size [inh]
//   color [inh]          content (text/glyph) color — NEVER a box color
//   text-align [inh]     left | center | right | justify
//   text-shadow [inh]    '<color> [dx dy]' | none — a second text layer under the first
//                        (dx,dy in logical units, 1 1 by default); replaces toWithShadow
//   text-decoration [inh]  underline | none
//   caption-display      none disables the button's own caption (text remains available)
//   content-press-offset button caption/children shift down while pressed, logical units (default 1)
//   text-offset-x/y      caption shift, logical units (state-able: ':pressed { text-offset-y:1 }')
//   tint                 TUIImage image tint (content image, not inherited)
//   tick-color           checkbox/radio mark
//  Scrollbar:
//   color (slider), track-color, active-color, track-width, slider-width, min-size,
//   radius, variant (flat)
//   slider-align: center | end (a narrow slider and track at the far edge); track-width,
//   slider-width and track-color follow ':hover' smoothly, dragging keeps the hover values
//  Transitions (ms):
//   hover-time, hover-time-in, hover-time-out, press-time, release-time,
//   disable-time, enable-time;  hover-target: parent  (hover follows the parent)
//
// <fill> values (R-39):
//   <color> | none
//   linear(<angle>, <stop>, <stop> [, <stop>...] [, repeat | reflect])
//   linear(<angle>, url(<image>))          -- a ramp texture: 'url(file:ramp.png)'
//   edge(<width>, <stop>, <stop> [, ...])  -- from the shape edge inwards, width in logical units
//   <angle> := <deg>deg | <deg> | to top | to right | to bottom | to left   (0deg = to top)
//   <stop>  := <color> [<pos>%]   -- up to 4 stops; ones without a position are spread evenly
//   Example: fill: linear(180deg, #6F7F98, #435166); fill-shade: &shade-raised
//
// Author: Apus Engine R-05 refactoring
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)

unit Apus.Engine.Style;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
interface
uses Apus.Core, Apus.Engine.Types;

type
  // A single key-value attribute pair (both stored as strings)
  TStyleAttr=record
   key:String8;
   value:String8;
  end;
  TStyleAttrs=array of TStyleAttr;

  // State-specific attribute block
  TStateBlock=record
   stateName:String8;
   attrs:TStyleAttrs;
  end;

  // Parsed style block: refs + local attrs + state overrides + active states
  TStyleBlock=class
  public
   refs:Strings8;                   // @ref names in declaration order
   attrs:TStyleAttrs;               // local key-value pairs
   stateAttrs:array of TStateBlock; // :state { ... } override blocks
   activeStates:String8;            // comma-separated currently active state names
   dirty:boolean;                   // true when style data has changed

   destructor Destroy; override;
   procedure Clear;

   // Parse full style text (replaces all existing data)
   procedure ParseText(const text:String8);
   // Apply patch operations (modifies existing data)
   procedure PatchText(const patch:String8);

   // Fluent API: Assign = full replace, Add = patch (both return Self for chaining)
   function Assign(const text:String8):TStyleBlock;
   function Add(const patch:String8):TStyleBlock;
   // Reconstruct style text (alias for GetText)
   function Text:String8;

   // Individual attribute manipulation
   procedure SetAttr(const key,value:String8);
   procedure RemoveAttr(const key:String8);
   procedure AddRef(const refName:String8);
   procedure RemoveRef(const refName:String8);

   // State management
   function HasState(const name:String8):boolean;
   procedure SetState(const name:String8; active:boolean);

   // Value access (local + active states, no parent cascade, no refs)
   function HasAttr(const key:String8):boolean;
   function GetValue(const key:String8; const defVal:String8=''):String8;
   function GetStateValue(const stateName,key:String8; const defVal:String8=''):String8;
   // Value for a comma-separated state list (later listed state wins); '' if none has the key
   function GetStatesValue(const states,key:String8):String8;

   // Type-specific value getters
   function GetColor(const key:String8; defVal:cardinal=0):cardinal;
   function GetNumber(const key:String8; defVal:single=0):single;
   function GetScaledNumber(const key:String8; scale,defVal:single):single;
   function GetInt(const key:String8; defVal:integer=0):integer;

   // State-specific typed getters (for transition blending)
   function GetStateColor(const stateName,key:String8; defVal:cardinal=0):cardinal;
   function GetStateNumber(const stateName,key:String8; defVal:single=0):single;

   // Reconstruct style text (for debug/serialization); use Text for fluent access
   function GetText:String8;

  private
   procedure ParseKV(const text:String8; from,last:integer; const stateCtx:String8);
   procedure ParseStateBlock(const stateName,text:String8; from,last:integer);
   function GetLocalValue(const key:String8):String8;
   function GetActiveStateValue(const key:String8):String8;
   function FindOrAddStateBlock(const stateName:String8):integer;
  end;

// Global named style catalog
// name comparison is case-insensitive
// Items[name] read/write style text; Block(name) returns the TStyleBlock
TStyleCatalog=class
private
 function GetText(const name:String8):String8;
 procedure SetText(const name,text:String8);
public
 // Read style text by name ('' if not registered)
 // Write style text: creates or replaces the named style
 property Items[const name:String8]:String8 read GetText write SetText; default;
 // Direct block reference for resolvers/drawers (nil if not found)
 function Block(const name:String8):TStyleBlock;
 procedure Remove(const name:String8);
 procedure Clear;
end;

var
 Styles:TStyleCatalog; // global named style catalog

// Resolve value from block (local+states+refs) — no parent cascade
// refs are resolved recursively from the named style registry
function ResolveBlockAttr(block:TStyleBlock; const key:String8; const defVal:String8=''):String8;
function ResolveBlockColor(block:TStyleBlock; const key:String8; defVal:cardinal=0):cardinal;
function ResolveBlockNumber(block:TStyleBlock; const key:String8; defVal:single=0):single;

// Resolve a value declared for one specific state, through local ':state' blocks and
// then @refs (later listed ref = higher priority). Tokens are expanded; the parent chain
// is not consulted (a state belongs to the element that owns it).
// Used by drawers to blend transitions: base value + per-state value + progress.
function ResolveBlockStateAttr(block:TStyleBlock; const stateName,key:String8; const defVal:String8=''):String8;
function ResolveBlockStateColor(block:TStyleBlock; const stateName,key:String8; defVal:cardinal=0):cardinal;
function ResolveBlockStateNumber(block:TStyleBlock; const stateName,key:String8; defVal:single=0):single;

// Resolve base value — local attrs+refs only, ignores active state overrides
// Useful for transition blending: base = no-state value, state = SetState override
function ResolveBlockAttrBase(block:TStyleBlock; const key:String8; const defVal:String8=''):String8;
function ResolveBlockColorBase(block:TStyleBlock; const key:String8; defVal:cardinal=0):cardinal;

// Parse color string: $AARRGGBB, $RRGGBB, #RRGGBB, #RGB, #ARGB formats
// Returns 0 on failure
function ParseStyleColor(const s:String8):cardinal;

// Parse numeric string: plain number or percentage ('50%' -> 0.5)
function ParseStyleNumber(const s:String8):single;

// Parse a <fill> value (see the header); tokens are expanded, also inside its parts.
// False for '' or an invalid value. Results are cached by the text until stylesRevision changes.
// edge() width stays in logical units: the drawer scales it.
function ParseStyleFill(const s:String8; out fill:TFill):boolean;
// '<r>' or '<tl> <tr> <br> <bl>'; 2 values: tl+br, tr+bl; 3 values: tl, tr+bl, br. False for ''
function ParseStyleRadii(const s:String8; out radii:TCornerRadii):boolean;
function ResolveBlockFill(block:TStyleBlock; const key:String8; const defVal:TFill):TFill;

var
 // Turns an image reference of 'url(...)' into a texture (TTexture) that stays alive while
 // fills use it. Installed by the drawer (DefaultStyle); without it url() fills are invalid.
 StyleImageResolver:function(const src:String8):TObject;

// True for attributes that cascade down the element tree when not set locally
// (typography and content color). Box chrome (fill, border*, radius...) never inherits.
function IsInheritedStyleKey(const key:String8):boolean;

// --- R-05 token foundation (palette tokens + themes) ---
// A value of the form '&name' in any style attribute is replaced by the token's
// value before color/number parsing. Tokens are the theme swap point.

// SetToken is the SOLE mutation entry — writes the value and bumps stylesRevision.
procedure SetToken(const name,value:String8);
// Convenience for the editor: stores color as '$AARRGGBB'.
procedure SetTokenColor(const name:String8; color:cardinal);
// Raw token value (NO &-expansion); defVal if not defined.
function GetToken(const name:String8; const defVal:String8=''):String8;
function HasToken(const name:String8):boolean;
// '&name' -> the token's value (recursively), other values as is; '' for an unknown token.
// Resolvers expand whole values; a compound value ('&shadow 2 3') passes as is, and the
// drawer expands its parts.
function ExpandToken(const value:String8; depth:integer=0):String8;
procedure RemoveToken(const name:String8);
procedure ClearTokens;

// Themes are named, complete token sets. Each pair is a 'name=value' string.
procedure DefineTheme(const name:String8; const pairs:array of String8);
// Swap the active palette: clears tokens, applies the theme, bumps stylesRevision.
procedure ApplyTheme(const name:String8);
function ActiveTheme:String8;

var
 // Monotonic dirty counter, bumped on any token/theme mutation. A hook for future
 // resolve caches and baked-state rebuilds; resolve itself is per-call (no cache yet).
 stylesRevision:cardinal=0;

implementation
uses Apus.Conv, Apus.Strings, Apus.Log, Apus.Types, Apus.Threads;

const
 MAX_NAMED_STYLES = 128;

type
 TNamedStyle=record
  name:String8;
  block:TStyleBlock;
 end;

var
 namedStyles:array[0..MAX_NAMED_STYLES-1] of TNamedStyle;
 namedStyleCount:integer;

const
 MAX_TOKENS = 128;
 MAX_THEMES = 16;
 MAX_TOKEN_DEPTH = 8; // &a -> &b -> ... cycle/depth guard

type
 TToken=record
  name:String8;  // without '&' prefix, lowercase
  value:String8; // literal ($AARRGGBB / number / any string) OR reference '&other'
 end;
 TTheme=record
  name:String8;        // lowercase
  pairs:TNameValueList; // token name→value palette
 end;

var
 tokens:array[0..MAX_TOKENS-1] of TToken;
 tokenCount:integer;
 themes:array[0..MAX_THEMES-1] of TTheme;
 themeCount:integer;
 activeThemeName:String8;
 warnedTokens:String8; // ';name;name;' — to warn about each unknown token once

{ Utility }

const
 // ';'-delimited for a cheap substring test; keys are lowercase (ParseKV normalizes)
 INHERITED_KEYS=';font;font-size;color;text-align;text-shadow;text-decoration;';

function IsInheritedStyleKey(const key:String8):boolean;
 begin
  result:=Pos(';'+key.ToLower+';',INHERITED_KEYS)>0;
 end;

function ParseStyleColor(const s:String8):cardinal;
 var
  t:String8;
  n:integer;
 begin
  result:=0;
  t:=s.Trim;
  n:=length(t);
  if n<2 then exit;
  if (t[1]='#') or (t[1]='$') then
   Delete(t,1,1);
  n:=length(t);
  case n of
   3:begin // #RGB → $FFRRGGBB
    t:='FF'+t[1]+t[1]+t[2]+t[2]+t[3]+t[3];
   end;
   4:begin // #ARGB → $AARRGGBB
    t:=t[1]+t[1]+t[2]+t[2]+t[3]+t[3]+t[4]+t[4];
   end;
   6:begin // #RRGGBB → $FFRRGGBB
    t:='FF'+t;
   end;
   8:; // $AARRGGBB — already correct
   else exit;
  end;
  result:=Conv.HexToInt(t);
 end;

function ParseStyleNumber(const s:String8):single;
 var
  t:String8;
 begin
  t:=s.Trim;
  if (t<>'') and (t[length(t)]='%') then begin
   t:=Copy(t,1,length(t)-1);
   result:=Conv.ToFloat(t)*0.01;
  end else
   result:=Conv.ToFloat(t);
 end;

{ TStyleBlock }

destructor TStyleBlock.Destroy;
 begin
  Clear;
  inherited;
 end;

procedure TStyleBlock.Clear;
 begin
  refs:=nil;
  attrs:=nil;
  stateAttrs:=nil;
  activeStates:='';
  dirty:=true;
 end;

procedure TStyleBlock.SetAttr(const key,value:String8);
 var
  i:integer;
  k:String8;
 begin
  k:=key.ToLower;
  for i:=0 to high(attrs) do
   if attrs[i].key=k then begin
    attrs[i].value:=value;
    dirty:=true;
    exit;
   end;
  i:=length(attrs);
  SetLength(attrs,i+1);
  attrs[i].key:=k;
  attrs[i].value:=value;
  dirty:=true;
 end;

procedure TStyleBlock.RemoveAttr(const key:String8);
 var
  i,n:integer;
  k:String8;
 begin
  k:=key.ToLower;
  n:=length(attrs);
  for i:=0 to n-1 do
   if attrs[i].key=k then begin
    attrs[i]:=attrs[n-1];
    SetLength(attrs,n-1);
    dirty:=true;
    exit;
   end;
 end;

procedure TStyleBlock.AddRef(const refName:String8);
 var
  i,n:integer;
  r:String8;
 begin
  r:=refName.Trim.ToLower;
  if r='' then exit;
  for i:=0 to high(refs) do
   if refs[i]=r then exit; // already present
  n:=length(refs);
  SetLength(refs,n+1);
  refs[n]:=r;
  dirty:=true;
 end;

procedure TStyleBlock.RemoveRef(const refName:String8);
 var
  i,n:integer;
  r:String8;
 begin
  r:=refName.Trim.ToLower;
  n:=length(refs);
  for i:=0 to n-1 do
   if refs[i]=r then begin
    refs[i]:=refs[n-1];
    SetLength(refs,n-1);
    dirty:=true;
    exit;
   end;
 end;

function TStyleBlock.HasState(const name:String8):boolean;
 var
  n,st:String8;
 begin
  n:=';'+name.Trim.ToLower+';';
  st:=';'+activeStates+';';
  result:=st.IndexOf(n,1)>0;
 end;

procedure TStyleBlock.SetState(const name:String8; active:boolean);
 var
  n:String8;
  states:Strings8;
  i,found:integer;
 begin
  n:=name.Trim.ToLower;
  if n='' then exit;
  states:=activeStates.Split(',');
  found:=-1;
  for i:=0 to high(states) do
   if states[i].Trim=n then begin found:=i; break; end;
  if active then begin
   if found<0 then begin
    if activeStates='' then activeStates:=n
     else activeStates:=activeStates+','+n;
    dirty:=true;
   end;
  end else begin
   if found>=0 then begin
    // keep the order: a later state has a higher priority
    activeStates:='';
    for i:=0 to high(states) do begin
     if (i=found) or (states[i].Trim='') then continue;
     if activeStates='' then activeStates:=states[i].Trim
      else activeStates:=activeStates+','+states[i].Trim;
    end;
    dirty:=true;
   end;
  end;
 end;

function TStyleBlock.HasAttr(const key:String8):boolean;
 var
  i:integer;
  k:String8;
 begin
  k:=key.ToLower;
  for i:=0 to high(attrs) do
   if attrs[i].key=k then exit(true);
  result:=false;
 end;

function TStyleBlock.GetLocalValue(const key:String8):String8;
 var
  i:integer;
  k:String8;
 begin
  k:=key.ToLower;
  for i:=0 to high(attrs) do
   if attrs[i].key=k then exit(attrs[i].value);
  result:='';
 end;

function TStyleBlock.GetStateValue(const stateName,key:String8; const defVal:String8):String8;
 var
  i,j:integer;
  sn,k:String8;
 begin
  sn:=stateName.Trim.ToLower;
  k:=key.ToLower;
  for i:=0 to high(stateAttrs) do
   if stateAttrs[i].stateName=sn then begin
    for j:=0 to high(stateAttrs[i].attrs) do
     if stateAttrs[i].attrs[j].key=k then exit(stateAttrs[i].attrs[j].value);
    exit(defVal);
   end;
  result:=defVal;
 end;

function TStyleBlock.GetStatesValue(const states,key:String8):String8;
 var
  list:Strings8;
  i:integer;
  v:String8;
 begin
  result:='';
  if states='' then exit;
  list:=states.Split(',');
  // later-listed states have higher priority → iterate in forward order, last wins
  for i:=0 to high(list) do begin
   v:=GetStateValue(list[i],key,'');
   if v<>'' then result:=v;
  end;
 end;

function TStyleBlock.GetActiveStateValue(const key:String8):String8;
 begin
  result:=GetStatesValue(activeStates,key);
 end;

function TStyleBlock.GetValue(const key:String8; const defVal:String8):String8;
 var
  sv:String8;
 begin
  // Active state overrides have highest priority
  if activeStates<>'' then begin
   sv:=GetActiveStateValue(key);
   if sv<>'' then exit(sv);
  end;
  // Local attributes
  result:=GetLocalValue(key);
  if result<>'' then exit;
  result:=defVal;
 end;

function TStyleBlock.GetColor(const key:String8; defVal:cardinal):cardinal;
 var
  s:String8;
 begin
  s:=GetValue(key,'');
  if s='' then exit(defVal);
  result:=ParseStyleColor(s);
  if (result=0) and (s<>'0') then result:=defVal; // parse error
 end;

function TStyleBlock.GetNumber(const key:String8; defVal:single):single;
 var
  s:String8;
 begin
  s:=GetValue(key,'');
  if s='' then exit(defVal);
  result:=ParseStyleNumber(s);
 end;

function TStyleBlock.GetScaledNumber(const key:String8; scale,defVal:single):single;
 var
  s:String8;
 begin
  s:=GetValue(key,'');
  if s='' then exit(defVal);
  result:=ParseStyleNumber(s)*scale;
 end;

function TStyleBlock.GetInt(const key:String8; defVal:integer):integer;
 begin
  result:=round(GetNumber(key,defVal));
 end;

function TStyleBlock.GetStateColor(const stateName,key:String8; defVal:cardinal):cardinal;
 var
  s:String8;
 begin
  s:=GetStateValue(stateName,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleColor(s);
  if (result=0) and (s<>'0') then result:=defVal;
 end;

function TStyleBlock.GetStateNumber(const stateName,key:String8; defVal:single):single;
 var
  s:String8;
 begin
  s:=GetStateValue(stateName,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleNumber(s);
 end;

function TStyleBlock.GetText:String8;
 var
  i,j:integer;
 begin
  result:='';
  for i:=0 to high(refs) do
   result:=result+'@'+refs[i]+'; ';
  for i:=0 to high(attrs) do
   result:=result+attrs[i].key+': '+attrs[i].value+'; ';
  for i:=0 to high(stateAttrs) do begin
   result:=result+':'+stateAttrs[i].stateName+' { ';
   for j:=0 to high(stateAttrs[i].attrs) do
    result:=result+stateAttrs[i].attrs[j].key+': '+stateAttrs[i].attrs[j].value+'; ';
   result:=result+'} ';
  end;
  result:=result.TrimRight;
 end;

function TStyleBlock.Assign(const text:String8):TStyleBlock;
 begin
  ParseText(text);
  result:=self;
 end;

function TStyleBlock.Add(const patch:String8):TStyleBlock;
 begin
  PatchText(patch);
  result:=self;
 end;

function TStyleBlock.Text:String8;
 begin
  result:=GetText;
 end;

function TStyleBlock.FindOrAddStateBlock(const stateName:String8):integer;
 var
  i,n:integer;
  sn:String8;
 begin
  sn:=stateName.Trim.ToLower;
  for i:=0 to high(stateAttrs) do
   if stateAttrs[i].stateName=sn then exit(i);
  n:=length(stateAttrs);
  SetLength(stateAttrs,n+1);
  stateAttrs[n].stateName:=sn;
  stateAttrs[n].attrs:=nil;
  result:=n;
 end;

procedure TStyleBlock.ParseKV(const text:String8; from,last:integer; const stateCtx:String8);
 var
  p:integer;
  key,value:String8;
  sbIdx,n:integer;
 begin
  if from>last then exit;
  // find ':' or '=' separating key from value (= supported for backward compat)
  p:=from;
  while (p<=last) and (text[p]<>':') and (text[p]<>'=') do inc(p);
  if p>last then begin
   // no colon: valueless attribute (boolean = true)
   key:=Copy(text,from,last-from+1).Trim.ToLower;
   value:='true';
  end else begin
   key:=Copy(text,from,p-from).Trim.ToLower;
   value:=Copy(text,p+1,last-p).Trim;
  end;
  if key='' then exit;
  if stateCtx='' then begin
   // set as local attribute
   SetAttr(key,value); // SetAttr handles lowercase
  end else begin
   // add to state block
   sbIdx:=FindOrAddStateBlock(stateCtx);
   n:=length(stateAttrs[sbIdx].attrs);
   SetLength(stateAttrs[sbIdx].attrs,n+1);
   stateAttrs[sbIdx].attrs[n].key:=key;
   stateAttrs[sbIdx].attrs[n].value:=value;
  end;
 end;

procedure TStyleBlock.ParseStateBlock(const stateName,text:String8; from,last:integer);
 var
  i,start:integer;
 begin
  start:=from;
  i:=from;
  while i<=last do begin
   while (i<=start) and (i<=last) and (text[i]<=' ') do begin inc(start); inc(i); end;
   if text[i]=';' then begin
    ParseKV(text,start,i-1,stateName);
    start:=i+1;
    i:=start;
   end else
    inc(i);
  end;
  if start<=last then
   ParseKV(text,start,last,stateName);
 end;

procedure TStyleBlock.ParseText(const text:String8);
 var
  i,n,start,braceStart,depth:integer;
  ch:AnsiChar;
  stateName:String8;
 begin
  Clear;
  n:=length(text);
  if n=0 then exit;
  i:=1;
  while i<=n do begin
   // skip leading whitespace
   while (i<=n) and (text[i]<=' ') do inc(i);
   if i>n then break;
   ch:=text[i];

   // @ref entry: @refname;
   if ch='@' then begin
    start:=i+1;
    inc(i);
    while (i<=n) and (text[i]<>';') and (text[i]<>' ') do inc(i);
    AddRef(Copy(text,start,i-start));
    while (i<=n) and (text[i]<>';') do inc(i);
    if i<=n then inc(i); // skip ';'
    continue;
   end;

   // State block: :statename { ... }
   if ch=':' then begin
    inc(i);
    start:=i;
    while (i<=n) and (text[i]<>'{') and (text[i]<>';') do inc(i);
    stateName:=Copy(text,start,i-start).Trim.ToLower;
    if (i<=n) and (text[i]='{') then begin
     inc(i); // skip '{'
     braceStart:=i;
     depth:=1;
     while (i<=n) and (depth>0) do begin
      if text[i]='{' then inc(depth)
       else if text[i]='}' then dec(depth);
      inc(i);
     end;
     // content: braceStart..i-2 (before closing '}')
     if braceStart<=i-2 then
      ParseStateBlock(stateName,text,braceStart,i-2);
    end;
    // else: just ignore ':statename' without body
    continue;
   end;

   // Regular key:value;
   start:=i;
   while (i<=n) and (text[i]<>';') do inc(i);
   ParseKV(text,start,i-1,'');
   if i<=n then inc(i);
  end;
 end;

procedure TStyleBlock.PatchText(const patch:String8);
 var
  i,n,start:integer;

 procedure ApplyOp(const s:String8);
  var
   t,k,v:String8;
   pp:integer;
  begin
   t:=s.Trim;
   if t='' then exit;
   // !state:name or !state:-name
   if t[1]='!' then begin
    t:=Copy(t,2,length(t)-1).Trim;
    if t.ToLower.StartsWith('state:') then begin
     t:=Copy(t,7,length(t)-6).Trim;
     if (t<>'') and (t[1]='-') then
      SetState(Copy(t,2,length(t)-1),false)
     else
      SetState(t,true);
    end;
    exit;
   end;
   // +@ref or -@ref
   if (length(t)>=2) and (t[2]='@') then begin
    if t[1]='+' then AddRef(Copy(t,3,length(t)-2))
     else if t[1]='-' then RemoveRef(Copy(t,3,length(t)-2));
    exit;
   end;
   // +key:value or -key
   if t[1]='+' then begin
    t:=Copy(t,2,length(t)-1);
    pp:=t.IndexOf(':',1);
    if pp>0 then begin
     k:=Copy(t,1,pp-1).Trim.ToLower;
     v:=Copy(t,pp+1,length(t)-pp).Trim;
     SetAttr(k,v);
    end else
     SetAttr(t.Trim.ToLower,'true');
   end else if t[1]='-' then begin
    t:=Copy(t,2,length(t)-1).Trim;
    RemoveAttr(t);
   end;
  end;

 begin
  n:=length(patch);
  if n=0 then exit;
  i:=1; start:=1;
  while i<=n do begin
   if patch[i]=';' then begin
    ApplyOp(Copy(patch,start,i-start));
    start:=i+1;
   end;
   inc(i);
  end;
  if start<=n then
   ApplyOp(Copy(patch,start,n-start+1));
 end;

{ Named style registry — internal storage }

function FindStyleBlock(const name:String8):TStyleBlock;
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  for i:=0 to namedStyleCount-1 do
   if namedStyles[i].name=n then exit(namedStyles[i].block);
  result:=nil;
 end;

procedure PutStyleBlock(const name:String8; block:TStyleBlock);
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  for i:=0 to namedStyleCount-1 do
   if namedStyles[i].name=n then begin
    if namedStyles[i].block<>block then
     namedStyles[i].block.Free;
    namedStyles[i].block:=block;
    exit;
   end;
  if namedStyleCount>=MAX_NAMED_STYLES then exit; // catalog full
  namedStyles[namedStyleCount].name:=n;
  namedStyles[namedStyleCount].block:=block;
  inc(namedStyleCount);
 end;

procedure DeleteStyleBlock(const name:String8);
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  for i:=0 to namedStyleCount-1 do
   if namedStyles[i].name=n then begin
    namedStyles[i].block.Free;
    namedStyles[i]:=namedStyles[namedStyleCount-1];
    dec(namedStyleCount);
    exit;
   end;
 end;

{ TStyleCatalog }

function TStyleCatalog.Block(const name:String8):TStyleBlock;
 begin
  result:=FindStyleBlock(name);
 end;

function TStyleCatalog.GetText(const name:String8):String8;
 var
  b:TStyleBlock;
 begin
  b:=FindStyleBlock(name);
  if b<>nil then result:=b.GetText
   else result:='';
 end;

procedure TStyleCatalog.SetText(const name,text:String8);
 var
  b:TStyleBlock;
 begin
  b:=FindStyleBlock(name);
  if b=nil then begin
   b:=TStyleBlock.Create;
   PutStyleBlock(name,b);
  end;
  b.ParseText(text);
 end;

procedure TStyleCatalog.Remove(const name:String8);
 begin
  DeleteStyleBlock(name);
 end;

procedure TStyleCatalog.Clear;
 var
  i:integer;
 begin
  for i:=0 to namedStyleCount-1 do
   namedStyles[i].block.Free;
  namedStyleCount:=0;
 end;

{ Token store }

function FindTokenIndex(const name:String8):integer;
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  for i:=0 to tokenCount-1 do
   if tokens[i].name=n then exit(i);
  result:=-1;
 end;

procedure SetToken(const name,value:String8);
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  if n='' then exit;
  inc(stylesRevision); // sole mutation point — any change bumps the dirty counter
  i:=FindTokenIndex(n);
  if i>=0 then begin
   tokens[i].value:=value;
   exit;
  end;
  if tokenCount>=MAX_TOKENS then begin
   Log.Warn('Style: token table full, ignoring &%s',[n]);
   exit;
  end;
  tokens[tokenCount].name:=n;
  tokens[tokenCount].value:=value;
  inc(tokenCount);
 end;

procedure SetTokenColor(const name:String8; color:cardinal);
 begin
  SetToken(name,'$'+Conv.ToHex(color,8)); // store as $AARRGGBB
 end;

function GetToken(const name:String8; const defVal:String8):String8;
 var
  i:integer;
 begin
  i:=FindTokenIndex(name);
  if i>=0 then result:=tokens[i].value
   else result:=defVal;
 end;

function HasToken(const name:String8):boolean;
 begin
  result:=FindTokenIndex(name)>=0;
 end;

procedure RemoveToken(const name:String8);
 var
  i:integer;
 begin
  i:=FindTokenIndex(name);
  if i<0 then exit;
  tokens[i]:=tokens[tokenCount-1];
  dec(tokenCount);
  inc(stylesRevision);
 end;

procedure ClearTokens;
 begin
  tokenCount:=0;
  inc(stylesRevision);
 end;

// Expand a value: if it is exactly '&name', substitute the token recursively.
// Otherwise return as-is. Unknown token -> '' (caller falls back to defVal).
function ExpandToken(const value:String8; depth:integer=0):String8;
 var
  s,n,v:String8;
 begin
  s:=value.Trim;
  if (s='') or (s[1]<>'&') then exit(value); // not a token reference
  if s.IndexOf(' ',1)>0 then exit(value); // a compound value: the drawer expands its parts
  if depth>=MAX_TOKEN_DEPTH then begin
   Log.Warn('Style: token cycle at %s',[s]);
   exit('');
  end;
  n:=Copy(s,2,length(s)-1).ToLower; // whole value is one token name (v1: no inline)
  v:=GetToken(n,'');
  if v='' then begin
   if warnedTokens.IndexOf(';'+n+';',1)<=0 then begin
    warnedTokens:=warnedTokens+';'+n+';';
    Log.Warn('Style: unknown token &%s',[n]);
   end;
   exit('');
  end;
  result:=ExpandToken(v,depth+1); // value may itself be another '&ref'
 end;

{ Themes }

function FindThemeIndex(const name:String8):integer;
 var
  i:integer;
  n:String8;
 begin
  n:=name.Trim.ToLower;
  for i:=0 to themeCount-1 do
   if themes[i].name=n then exit(i);
  result:=-1;
 end;

procedure DefineTheme(const name:String8; const pairs:array of String8);
 var
  i,idx:integer;
  n:String8;
  list:Strings8;
 begin
  n:=name.Trim.ToLower;
  if n='' then exit;
  idx:=FindThemeIndex(n);
  if idx<0 then begin
   if themeCount>=MAX_THEMES then begin
    Log.Warn('Style: theme table full, ignoring "%s"',[n]);
    exit;
   end;
   idx:=themeCount;
   inc(themeCount);
   themes[idx].name:=n;
  end;
  SetLength(list,length(pairs));
  for i:=0 to high(pairs) do list[i]:=pairs[i];
  themes[idx].pairs:=TNameValueList.Init(list); // splits each 'name=value'
 end;

procedure ApplyTheme(const name:String8);
 var
  idx,i:integer;
 begin
  idx:=FindThemeIndex(name);
  if idx<0 then begin
   Log.Warn('Style: unknown theme "%s"',[name]);
   exit;
  end;
  ClearTokens; // v1 themes are complete sets — start clean
  for i:=0 to themes[idx].pairs.Count-1 do
   SetToken(themes[idx].pairs.items[i].name,themes[idx].pairs.items[i].value);
  activeThemeName:=themes[idx].name;
  inc(stylesRevision); // explicit bump in case the theme was empty
 end;

function ActiveTheme:String8;
 begin
  result:=activeThemeName;
 end;

{ Resolver with @refs }

// Raw resolve: local + active states + @refs, no token expansion (recursion stays raw).
function ResolveBlockAttrBaseRaw(block:TStyleBlock; const key:String8; const defVal:String8):String8; forward;

// State phase: ':state' blocks of this block, then of its @refs (later ref wins).
// 'states' is the element's active state list, applied at every level of the cascade.
function ResolveStatePhase(block:TStyleBlock; const states,key:String8):String8;
 var
  i:integer;
  refBlock:TStyleBlock;
 begin
  result:='';
  if (block=nil) or (states='') then exit;
  result:=block.GetStatesValue(states,key);
  if result<>'' then exit;
  for i:=high(block.refs) downto 0 do begin
   refBlock:=FindStyleBlock(block.refs[i]);
   if refBlock=nil then continue;
   result:=ResolveStatePhase(refBlock,states,key);
   if result<>'' then exit;
  end;
 end;

function ResolveBlockAttrRaw(block:TStyleBlock; const key:String8; const defVal:String8):String8;
 var
  list:Strings8;
  i:integer;
 begin
  // active states first, the later listed (higher priority) one wins; each state is looked up
  // in the local block, then in refs (as the blending drawers do); then plain values
  result:='';
  if block.activeStates<>'' then begin
   list:=block.activeStates.Split(',');
   for i:=high(list) downto 0 do begin
    result:=ResolveStatePhase(block,list[i].Trim,key);
    if result<>'' then break;
   end;
  end;
  if result='' then result:=ResolveBlockAttrBaseRaw(block,key,'');
  if result='' then result:=defVal;
 end;

function ResolveBlockAttr(block:TStyleBlock; const key:String8; const defVal:String8):String8;
 begin
  // expand token exactly once, after the raw value is fully resolved
  result:=ExpandToken(ResolveBlockAttrRaw(block,key,defVal));
  if result='' then result:=defVal; // unknown/empty token -> fall back
 end;

function ResolveBlockColor(block:TStyleBlock; const key:String8; defVal:cardinal):cardinal;
 var
  s:String8;
 begin
  s:=ResolveBlockAttr(block,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleColor(s);
  if (result=0) and (s<>'0') then result:=defVal;
 end;

function ResolveBlockNumber(block:TStyleBlock; const key:String8; defVal:single):single;
 var
  s:String8;
 begin
  s:=ResolveBlockAttr(block,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleNumber(s);
 end;

{ Base resolvers: local attrs+refs only, state overrides ignored }

// Raw base resolve: local attrs + @refs only, no state overrides, no token expansion.
function ResolveBlockAttrBaseRaw(block:TStyleBlock; const key:String8; const defVal:String8):String8;
 var
  i:integer;
  refBlock:TStyleBlock;
  refVal:String8;
 begin
  // local attrs only (no state overrides)
  result:=block.GetLocalValue(key);
  if result<>'' then exit;
  // @refs in reverse order
  for i:=high(block.refs) downto 0 do begin
   refBlock:=FindStyleBlock(block.refs[i]);
   if refBlock=nil then continue;
   refVal:=ResolveBlockAttrBaseRaw(refBlock,key,'');
   if refVal<>'' then exit(refVal);
  end;
  result:=defVal;
 end;

function ResolveBlockAttrBase(block:TStyleBlock; const key:String8; const defVal:String8):String8;
 begin
  result:=ExpandToken(ResolveBlockAttrBaseRaw(block,key,defVal));
  if result='' then result:=defVal;
 end;

function ResolveBlockColorBase(block:TStyleBlock; const key:String8; defVal:cardinal):cardinal;
 var
  s:String8;
 begin
  s:=ResolveBlockAttrBase(block,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleColor(s);
  if (result=0) and (s<>'0') then result:=defVal;
 end;

function ResolveBlockStateAttr(block:TStyleBlock; const stateName,key:String8; const defVal:String8):String8;
 begin
  result:=ExpandToken(ResolveStatePhase(block,stateName,key));
  if result='' then result:=defVal;
 end;

function ResolveBlockStateColor(block:TStyleBlock; const stateName,key:String8; defVal:cardinal):cardinal;
 var
  s:String8;
 begin
  s:=ResolveBlockStateAttr(block,stateName,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleColor(s);
  if (result=0) and (s<>'0') then result:=defVal;
 end;

function ResolveBlockStateNumber(block:TStyleBlock; const stateName,key:String8; defVal:single):single;
 var
  s:String8;
 begin
  s:=ResolveBlockStateAttr(block,stateName,key,'');
  if s='' then exit(defVal);
  result:=ParseStyleNumber(s);
 end;

{ Fills (R-39) }

const
 FILL_CACHE_SIZE=128; // direct-mapped, a power of 2

type
 TFillCacheEntry=record
  key:String8;
  revision:cardinal;
  used:boolean; // the entry holds a parse result
  ok:boolean;
  fill:TFill;
 end;

var
 // shared by the render threads of all windows: guarded by fillLock (a leaf lock, the parse
 // itself runs outside it)
 fillLock:TLock;
 fillCache:array[0..FILL_CACHE_SIZE-1] of TFillCacheEntry;
 warnedFills:String8; // ';value;' - to warn about each invalid fill once

// Split by top-level commas: commas inside nested parentheses stay, as in 'url(a,b)'
function SplitFillArgs(const s:String8):Strings8;
 var
  i,depth,start,n:integer;
 begin
  result:=nil;
  n:=0; depth:=0; start:=1;
  for i:=1 to length(s)+1 do
   if (i>length(s)) or ((s[i]=',') and (depth=0)) then begin
    SetLength(result,n+1);
    result[n]:=Copy(s,start,i-start).Trim;
    inc(n);
    start:=i+1;
   end else
   if s[i]='(' then inc(depth)
   else if s[i]=')' then dec(depth);
 end;

function IsNumberText(const s:String8):boolean;
 begin
  result:=(s<>'') and (s[1] in ['0'..'9','-','+','.']);
 end;

// A color part: tokens expanded; zero colors ('0', '$00000000') are valid
function ParseFillColor(const s:String8; out c:cardinal):boolean;
 var
  t:String8;
  i:integer;
 begin
  t:=ExpandToken(s).Trim;
  c:=ParseStyleColor(t);
  if c<>0 then exit(true);
  if (t<>'') and ((t[1]='#') or (t[1]='$')) then Delete(t,1,1);
  result:=t<>'';
  for i:=1 to length(t) do
   if t[i]<>'0' then exit(false);
 end;

function ParseFillAngle(const s:String8; out angle:single):boolean;
 var
  t:String8;
 begin
  t:=ExpandToken(s).Trim.ToLower;
  result:=true;
  if t='to top' then angle:=0 else
  if t='to right' then angle:=90 else
  if t='to bottom' then angle:=180 else
  if t='to left' then angle:=270 else begin
   if t.EndsWith('deg') then t:=Copy(t,1,length(t)-3).Trim;
   result:=IsNumberText(t);
   if result then angle:=Conv.ToFloat(t);
  end;
 end;

// '<color> [<pos>]', the whole stop may be a token
function ParseFillStop(const s:String8; out c:cardinal; out pos:single; out hasPos:boolean):boolean;
 var
  parts:Strings8;
  i,n:integer;
 begin
  parts:=ExpandToken(s).Trim.Split(' ');
  n:=0;
  for i:=0 to high(parts) do
   if parts[i]<>'' then begin
    parts[n]:=parts[i]; inc(n);
   end;
  result:=(n in [1,2]) and ParseFillColor(parts[0],c);
  hasPos:=n=2;
  pos:=0;
  if hasPos then begin
   result:=result and IsNumberText(parts[1]);
   pos:=ParseStyleNumber(parts[1]);
  end;
 end;

function DoParseStyleFill(const s:String8; out fill:TFill):boolean;
 var
  t,head:String8;
  args:Strings8;
  i,j,k,n,p:integer;
  isEdge:boolean;
  lead:single; // the angle or the edge band width
  spread:TFillSpread;
  colors:array[0..MAX_FILL_STOPS-1] of cardinal;
  pos:array[0..MAX_FILL_STOPS-1] of single;
  hasPos:array[0..MAX_FILL_STOPS-1] of boolean;
  tex:TObject;
 begin
  result:=false;
  fill:=TFill.None;
  t:=ExpandToken(s).Trim;
  if t='' then exit;
  if t.ToLower='none' then exit(true);
  p:=t.IndexOf('(');
  if p<=0 then begin // a plain color
   result:=ParseFillColor(t,colors[0]);
   if result then fill:=TFill.Solid(colors[0]);
   exit;
  end;
  if t[length(t)]<>')' then exit;
  head:=Copy(t,1,p-1).Trim.ToLower;
  if head='linear' then isEdge:=false
  else if head='edge' then isEdge:=true
  else exit;
  args:=SplitFillArgs(Copy(t,p+1,length(t)-p-1));
  n:=length(args);
  if n<2 then exit;
  if isEdge then begin
   head:=ExpandToken(args[0]).Trim;
   if not IsNumberText(head) then exit;
   lead:=ParseStyleNumber(head);
   if lead<=0 then exit;
  end else
   if not ParseFillAngle(args[0],lead) then exit;
  // spread mode
  spread:=fsPad;
  head:=args[n-1].ToLower;
  if head='repeat' then spread:=fsRepeat else
  if head='reflect' then spread:=fsReflect;
  if (head='repeat') or (head='reflect') or (head='pad') then dec(n);
  // a ramp texture
  if (n=2) and args[1].StartsWith('url(',true) and (args[1][length(args[1])]=')') then begin
   if not Assigned(StyleImageResolver) then exit;
   tex:=StyleImageResolver(Copy(args[1],5,length(args[1])-5).Trim);
   if tex=nil then exit;
   if isEdge then fill:=TFill.Edge(lead,0,0)
    else fill:=TFill.Linear(lead,0,0);
   fill:=fill.WithRamp(tex).WithSpread(spread);
   exit(true);
  end;
  // color stops: args[1..n-1]
  dec(n);
  if (n<2) or (n>MAX_FILL_STOPS) then exit;
  for i:=0 to n-1 do
   if not ParseFillStop(args[i+1],colors[i],pos[i],hasPos[i]) then exit;
  // positions as in CSS: the ends default to 0 and 1, missing inner ones are spread
  // evenly between their known neighbours, and a position never goes back
  if not hasPos[0] then pos[0]:=0;
  if not hasPos[n-1] then pos[n-1]:=1;
  hasPos[0]:=true; hasPos[n-1]:=true;
  i:=1;
  while i<n-1 do begin
   if hasPos[i] then begin
    inc(i); continue;
   end;
   j:=i;
   while not hasPos[j] do inc(j);
   for k:=i to j-1 do
    pos[k]:=pos[i-1]+(pos[j]-pos[i-1])*(k-i+1)/(j-i+1);
   i:=j;
  end;
  for i:=1 to n-1 do
   if pos[i]<pos[i-1] then pos[i]:=pos[i-1];
  if isEdge then fill:=TFill.Edge(lead,colors[0],colors[n-1])
   else fill:=TFill.Linear(lead,colors[0],colors[n-1]);
  fill.stopCount:=n;
  for i:=0 to n-1 do begin
   fill.stops[i].pos:=pos[i];
   fill.stops[i].color:=colors[i];
  end;
  fill:=fill.WithSpread(spread);
  result:=true;
 end;

function ParseStyleFill(const s:String8; out fill:TFill):boolean;
 var
  h:cardinal;
  i:integer;
  entry:^TFillCacheEntry;
  warn:boolean;
 begin
  if s='' then begin
   fill:=TFill.None;
   exit(false);
  end;
  // FNV-1a over the text
  h:=2166136261;
  for i:=1 to length(s) do
   h:=cardinal((uint64(h xor byte(s[i]))*16777619) and $FFFFFFFF);
  entry:=@fillCache[h and (FILL_CACHE_SIZE-1)];
  fillLock.Enter;
  try
   if entry.used and (entry.revision=stylesRevision) and (entry.key=s) then begin
    fill:=entry.fill;
    exit(entry.ok);
   end;
  finally
   fillLock.Leave;
  end;
  result:=DoParseStyleFill(s,fill); // may resolve an image: not under the lock
  warn:=false;
  fillLock.Enter;
  try
   if not result and (warnedFills.IndexOf(';'+s+';',1)<=0) then begin
    warnedFills:=warnedFills+';'+s+';';
    warn:=true;
   end;
   entry.key:=s;
   entry.revision:=stylesRevision;
   entry.used:=true;
   entry.ok:=result;
   entry.fill:=fill;
  finally
   fillLock.Leave;
  end;
  if warn then Log.Warn('Style: invalid fill "%s"',[s]);
 end;

function ParseStyleRadii(const s:String8; out radii:TCornerRadii):boolean;
 var
  parts:Strings8;
  v:array[0..3] of single;
  i,n:integer;
 begin
  radii:=TCornerRadii.All(0);
  parts:=ExpandToken(s).Trim.Split(' ');
  n:=0;
  for i:=0 to high(parts) do
   if parts[i]<>'' then begin
    if n>3 then exit(false);
    v[n]:=ParseStyleNumber(ExpandToken(parts[i]));
    inc(n);
   end;
  result:=n>0;
  case n of
   1:radii:=TCornerRadii.All(v[0]);
   2:radii:=TCornerRadii.Init(v[0],v[1],v[0],v[1]);
   3:radii:=TCornerRadii.Init(v[0],v[1],v[2],v[1]);
   4:radii:=TCornerRadii.Init(v[0],v[1],v[2],v[3]);
  end;
 end;

function ResolveBlockFill(block:TStyleBlock; const key:String8; const defVal:TFill):TFill;
 begin
  if not ParseStyleFill(ResolveBlockAttr(block,key,''),result) then result:=defVal;
 end;

{ Built-in themes — draft palettes from design doc §3.
  Both themes are complete sets; they differ only in the palette values.
  The precise literal-by-literal mapping is a later design step. }

procedure RegisterBuiltinThemes;
 begin
  DefineTheme('light',[
   'surface=$FFB0B0C0', 'surface-alt=$FFC8C8D0', 'overlay=$FFE0E0DC',
   'text=$FF202020', 'text-muted=$FF808080', 'text-on-accent=$FFFFFFFF',
   'border=$FF000000', 'border-light=$FFE8E8E8', 'border-dark=$FF606060',
   'control=$FFB0A0C0',
   'accent=$FF3060C0', 'accent-text=$FFFFFFFF',
   'danger=$FFC04040', 'danger-text=$FFFFFFFF',
   'success=$FF40A040', 'success-text=$FFFFFFFF',
   'warning=$FFD0A030', 'warning-text=$FF202020',
   'focus=$80FFFF80', 'shadow=$50000000']);
  DefineTheme('dark',[
   'surface=$FF303038', 'surface-alt=$FF383840', 'overlay=$FF404048',
   'text=$FFE0E0E0', 'text-muted=$FF909090', 'text-on-accent=$FFFFFFFF',
   'border=$FF101010', 'border-light=$FF606068', 'border-dark=$FF101014',
   'control=$FF505060',
   'accent=$FF5080E0', 'accent-text=$FFFFFFFF',
   'danger=$FFD05050', 'danger-text=$FFFFFFFF',
   'success=$FF50B050', 'success-text=$FFFFFFFF',
   'warning=$FFE0B040', 'warning-text=$FF202020',
   'focus=$80FFFF80', 'shadow=$A0000000']);
 end;

initialization
 fillLock.Init('StyleFills',820);
 Styles:=TStyleCatalog.Create;
 RegisterBuiltinThemes;
 ApplyTheme('light'); // sensible default; no existing UI references tokens yet

finalization
 Styles.Free;

end.
