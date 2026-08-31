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
// Cascade priority (lowest to highest):
//   1. @refs (earlier listed = lower priority)
//   2. Local attributes
//   3. Active state overrides
//
// Canonical attribute vocabulary (kebab-case; CSS names where CSS has the concept).
// Drawers read ONLY these keys. Keys marked [inh] are inherited from the parent chain
// (see IsInheritedStyleKey); box chrome never inherits.
//
//  Box (chrome):
//   fill                 background color (0 = none)
//   border-color         border color; border-width; radius
//   border-light         bevel highlight (button); border-dark  bevel shadow (button, frame)
//   inner-fill, inner-border-color, inner-radius, inner-border-width  (client-area block)
//   background-image     file:<name> | tex:<name>  (B-16: read by the box path)
//   background-tint      tint for background-image (neutral by default)
//   background-size      auto | stretch;  background-offset-x/y
//  Content:
//   font [inh]           font name;  font-size [inh]
//   color [inh]          content (text/glyph) color — NEVER a box color
//   text-align [inh]     left | center | right | justify
//   text-shadow [inh]    shadow color [dx dy];  text-decoration [inh]  underline
//   text-offset-x/y      caption shift (state-able: ':pressed { text-offset-y:1 }')
//   tint                 TUIImage image tint (content image, not inherited)
//   tick-color           checkbox/radio mark
//  Scrollbar:
//   color (slider), track-color, active-color, track-width, slider-width, min-size,
//   radius, variant (flat)
//  Transitions (ms):
//   hover-time, hover-time-in, hover-time-out, press-time, release-time,
//   disable-time, enable-time;  hover-target: parent  (hover follows the parent)
//
// Author: Apus Engine R-05 refactoring
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Style;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
interface
uses Apus.Core;

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

// Resolve base value — local attrs+refs only, ignores active state overrides
// Useful for transition blending: base = no-state value, state = SetState override
function ResolveBlockAttrBase(block:TStyleBlock; const key:String8; const defVal:String8=''):String8;
function ResolveBlockColorBase(block:TStyleBlock; const key:String8; defVal:cardinal=0):cardinal;

// Parse color string: $AARRGGBB, $RRGGBB, #RRGGBB, #RGB, #ARGB formats
// Returns 0 on failure
function ParseStyleColor(const s:String8):cardinal;

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
uses Apus.Conv, Apus.Strings, Apus.Log, Apus.Types;

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
    states[found]:=states[high(states)];
    SetLength(states,high(states));
    activeStates:='';
    for i:=0 to high(states) do begin
     if states[i].Trim='' then continue;
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

function TStyleBlock.GetActiveStateValue(const key:String8):String8;
 var
  states:Strings8;
  i:integer;
  v:String8;
 begin
  result:='';
  if activeStates='' then exit;
  states:=activeStates.Split(',');
  // later-listed states have higher priority → iterate in forward order, last wins
  for i:=0 to high(states) do begin
   v:=GetStateValue(states[i],key,'');
   if v<>'' then result:=v;
  end;
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
function ResolveBlockAttrRaw(block:TStyleBlock; const key:String8; const defVal:String8):String8;
 var
  i:integer;
  refBlock:TStyleBlock;
  refVal:String8;
 begin
  // local + active states (highest priority)
  result:=block.GetValue(key,'');
  if result<>'' then exit;
  // @refs in reverse order: later listed = higher priority among refs
  for i:=high(block.refs) downto 0 do begin
   refBlock:=FindStyleBlock(block.refs[i]);
   if refBlock=nil then continue;
   refVal:=ResolveBlockAttrRaw(refBlock,key,'');
   if refVal<>'' then exit(refVal);
  end;
  result:=defVal;
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
   'focus=$80FFFF80']);
  DefineTheme('dark',[
   'surface=$FF303038', 'surface-alt=$FF383840', 'overlay=$FF404048',
   'text=$FFE0E0E0', 'text-muted=$FF909090', 'text-on-accent=$FFFFFFFF',
   'border=$FF101010', 'border-light=$FF606068', 'border-dark=$FF101014',
   'control=$FF505060',
   'accent=$FF5080E0', 'accent-text=$FFFFFFFF',
   'danger=$FFD05050', 'danger-text=$FFFFFFFF',
   'success=$FF50B050', 'success-text=$FFFFFFFF',
   'warning=$FFE0B040', 'warning-text=$FF202020',
   'focus=$80FFFF80']);
 end;

initialization
 Styles:=TStyleCatalog.Create;
 RegisterBuiltinThemes;
 ApplyTheme('light'); // sensible default; no existing UI references tokens yet

finalization
 Styles.Free;

end.
