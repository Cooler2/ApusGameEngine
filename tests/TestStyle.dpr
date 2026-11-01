{$APPTYPE CONSOLE}
program TestStyle;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
  Apus.Engine.Types,
  Apus.Engine.Style;

{$I ..\Base\tests\Test.inc}

// --- Test procedures ---

procedure TestBasicParsing;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock basic parsing');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FFFF0000; font: Arial; font-size: 14;');
  Check(b.GetValue('color')='$FFFF0000','color value');
  Check(b.GetValue('font')='Arial','font value');
  Check(b.GetValue('font-size')='14','font-size value');
  Check(b.GetValue('missing','default')='default','missing key default');
  b.Free;
  EndTest;
end;

procedure TestGetColor;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock GetColor');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FFFF0000; bg: $FF0000FF;');
  Check(b.GetColor('color')=$FFFF0000,'color red');
  Check(b.GetColor('bg')=$FF0000FF,'color blue');
  Check(b.GetColor('missing',$FF808080)=$FF808080,'missing color default');
  b.Free;
  EndTest;
end;

procedure TestStateBlocks;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock state blocks');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FF808080; :hover { color: $FFFFFFFF; } :pressed { color: $FF404040; }');
  // without active state
  Check(b.GetValue('color')='$FF808080','base color');
  // activate hover
  b.SetState('hover',true);
  Check(b.HasState('hover'),'hover active');
  Check(b.GetValue('color')='$FFFFFFFF','hover color override');
  // switch to pressed
  b.SetState('hover',false);
  b.SetState('pressed',true);
  Check(not b.HasState('hover'),'hover inactive');
  Check(b.HasState('pressed'),'pressed active');
  Check(b.GetValue('color')='$FF404040','pressed color override');
  // deactivate all
  b.SetState('pressed',false);
  Check(b.GetValue('color')='$FF808080','restored base color');
  b.Free;
  EndTest;
end;

procedure TestPatchText;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock PatchText');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FF808080; font-size: 12;');
  b.PatchText('+color: $FFFF0000; +border-width: 2;');
  Check(b.GetValue('color')='$FFFF0000','patched color');
  Check(b.GetValue('border-width')='2','new attribute');
  Check(b.GetValue('font-size')='12','unchanged attribute');
  b.Free;
  EndTest;
end;

procedure TestNamedRefs;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock @refs');
  // register a named style via catalog
  Styles['myBtn']:='color: $FF0000FF; border-width: 1;';
  // element references it
  b:=TStyleBlock.Create;
  b.ParseText('@myBtn; font-size: 14;');
  Check(ResolveBlockAttr(b,'color','')='$FF0000FF','ref color');
  Check(ResolveBlockAttr(b,'border-width','')='1','ref border-width');
  Check(ResolveBlockAttr(b,'font-size','')='14','local font-size');
  b.Free;
  Styles.Clear;
  EndTest;
end;

procedure TestLocalOverridesRef;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock local overrides @ref');
  Styles['base']:='color: $FF0000FF; font-size: 10;';
  b:=TStyleBlock.Create;
  b.ParseText('@base; color: $FFFF0000;'); // local color overrides ref
  Check(ResolveBlockAttr(b,'color','')='$FFFF0000','local wins over ref');
  Check(ResolveBlockAttr(b,'font-size','')='10','ref value used when no local');
  b.Free;
  Styles.Clear;
  EndTest;
end;

procedure TestParseStyleColor;
begin
  StartTest('ParseStyleColor');
  Check(ParseStyleColor('$FFFF0000')=$FFFF0000,'$AARRGGBB');
  Check(ParseStyleColor('$FF0000FF')=$FF0000FF,'$AABBGGRR blue');
  Check(ParseStyleColor('#FFFF0000')=$FFFF0000,'# prefix AARRGGBB');
  // 6-char (no alpha) → FF prefix applied
  Check(ParseStyleColor('$FF0000')=$FFFF0000,'6-char $RRGGBB');
  // 3-char shorthand #RGB → each digit doubled, FF alpha
  Check(ParseStyleColor('#F00')=$FFFF0000,'#RGB shorthand');
  // invalid → 0
  Check(ParseStyleColor('')=0,'empty string');
  // 'xyz' is 3 chars so it hits the #RGB expansion path — not a reliable error case
  // use a string with non-hex length (e.g. 5 chars) which hits the else/exit branch
  Check(ParseStyleColor('12345')=0,'5-char string');
  EndTest;
end;

procedure TestResolveBlockAttr;
var
  b:TStyleBlock;
begin
  StartTest('ResolveBlockAttr');
  b:=TStyleBlock.Create;
  b.ParseText('fill: $FF204060;');
  Check(ResolveBlockAttr(b,'fill','')='$FF204060','local attr resolved');
  Check(ResolveBlockAttr(b,'missing','fallback')='fallback','missing returns defVal');
  b.Free;
  EndTest;
end;

procedure TestPatchRemove;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock PatchText remove');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FFFF0000; border: 2;');
  b.PatchText('-color;');
  Check(b.GetValue('color','')='','attr removed');
  Check(b.GetValue('border','')='2','other attr intact');
  b.Free;
  EndTest;
end;

procedure TestGetNumber;
var
  b:TStyleBlock;
begin
  StartTest('StyleBlock GetNumber/GetInt');
  b:=TStyleBlock.Create;
  b.ParseText('size: 16; opacity: 50%;');
  Check(b.GetInt('size')=16,'GetInt');
  // 50% → 0.5 as scaled number
  Check(abs(b.GetNumber('opacity')-0.5)<0.001,'GetNumber 50%');
  Check(b.GetInt('missing',99)=99,'GetInt missing default');
  b.Free;
  EndTest;
end;

procedure TestGetText;
var
  b:TStyleBlock;
  t:String8;
begin
  StartTest('StyleBlock GetText round-trip');
  b:=TStyleBlock.Create;
  b.ParseText('color: $FFFF0000; font-size: 14;');
  t:=b.GetText;
  // verify both keys appear in the serialized text
  Check(t.IndexOf('color',1)>0,'GetText contains color');
  Check(t.IndexOf('font-size',1)>0,'GetText contains font-size');
  b.Free;
  EndTest;
end;

procedure TestTokenStore;
begin
  StartTest('Token store round-trip');
  ClearTokens;
  SetToken('accent','$FF112233');
  Check(GetToken('accent')='$FF112233','SetToken/GetToken round-trip');
  Check(HasToken('Accent'),'HasToken case-insensitive');
  SetToken('accent','$FF445566'); // overwrite
  Check(GetToken('accent')='$FF445566','overwrite value');
  RemoveToken('accent');
  Check(not HasToken('accent'),'RemoveToken');
  SetToken('x','1'); SetToken('y','2');
  ClearTokens;
  Check((not HasToken('x')) and (not HasToken('y')),'ClearTokens');
  Check(GetToken('absent','def')='def','GetToken defVal');
  EndTest;
end;

procedure TestSetTokenColor;
begin
  StartTest('SetTokenColor format');
  ClearTokens;
  SetTokenColor('c',$FF12ABCD);
  Check(GetToken('c')='$FF12ABCD','formats as $AARRGGBB');
  Check(ParseStyleColor(GetToken('c'))=$FF12ABCD,'parses back to same cardinal');
  EndTest;
end;

procedure TestTokenSubstitution;
var
  b:TStyleBlock;
begin
  StartTest('Token substitution in resolve');
  ClearTokens;
  SetToken('accent','$FF112233');
  b:=TStyleBlock.Create;
  b.ParseText('fill:&accent;');
  Check(ResolveBlockColor(b,'fill',0)=$FF112233,'local attr token expands');
  b.Free;
  EndTest;
end;

procedure TestTokenInStateAndRef;
var
  b:TStyleBlock;
begin
  StartTest('Token substitution from state and @ref');
  ClearTokens;
  SetToken('accent','$FF112233');
  // state-block path
  b:=TStyleBlock.Create;
  b.ParseText('color:$FF000000; :hover { color:&accent; }');
  b.SetState('hover',true);
  Check(ResolveBlockColor(b,'color',0)=$FF112233,'token from active state');
  b.Free;
  // @ref path
  Styles['ref']:='color:&accent;';
  b:=TStyleBlock.Create;
  b.ParseText('@ref;');
  Check(ResolveBlockColor(b,'color',0)=$FF112233,'token from @ref');
  b.Free;
  Styles.Clear;
  EndTest;
end;

procedure TestTokenChainAndCycle;
var
  b:TStyleBlock;
begin
  StartTest('Token chain and cycle guard');
  ClearTokens;
  SetToken('a','&b'); SetToken('b','$FF010203');
  b:=TStyleBlock.Create;
  b.ParseText('x:&a;');
  Check(ResolveBlockColor(b,'x',0)=$FF010203,'chain &a->&b->literal');
  b.Free;
  // cycle must not hang and must fall back to default
  ClearTokens;
  SetToken('c','&d'); SetToken('d','&c');
  b:=TStyleBlock.Create;
  b.ParseText('x:&c;');
  Check(ResolveBlockColor(b,'x',$FF00FF00)=$FF00FF00,'cycle returns default, no hang');
  b.Free;
  EndTest;
end;

procedure TestUnknownToken;
var
  b:TStyleBlock;
begin
  StartTest('Unknown token falls back');
  ClearTokens;
  b:=TStyleBlock.Create;
  b.ParseText('x:&nope;');
  Check(ResolveBlockColor(b,'x',$FF00FF00)=$FF00FF00,'unknown token -> defVal');
  b.Free;
  EndTest;
end;

procedure TestTokenInNumbers;
var
  b:TStyleBlock;
begin
  StartTest('Token expands before number parse');
  ClearTokens;
  SetToken('size','24'); SetToken('pct','50%');
  b:=TStyleBlock.Create;
  b.ParseText('gap:&size; w:&pct;');
  Check(round(ResolveBlockNumber(b,'gap',0))=24,'number token');
  Check(abs(ResolveBlockNumber(b,'w',0)-0.5)<0.001,'percent token');
  b.Free;
  EndTest;
end;

procedure TestThemeSwap;
var
  b:TStyleBlock;
  r0,r1:cardinal;
begin
  StartTest('Theme swap and revision');
  b:=TStyleBlock.Create;
  b.ParseText('color:&surface;');
  ApplyTheme('dark');
  Check(ResolveBlockColor(b,'color',0)=$FF303038,'dark surface');
  ApplyTheme('light');
  Check(ResolveBlockColor(b,'color',0)=$FFB0B0C0,'light surface');
  b.Free;
  r0:=stylesRevision;
  SetToken('z','1');
  Check(stylesRevision>r0,'SetToken bumps revision');
  r1:=stylesRevision;
  ApplyTheme('dark');
  Check(stylesRevision>r1,'ApplyTheme bumps revision');
  ApplyTheme('light'); // restore default
  EndTest;
end;

procedure TestInheritedKeys;
begin
  StartTest('Inherited style keys');
  Check(IsInheritedStyleKey('color') and IsInheritedStyleKey('font') and
        IsInheritedStyleKey('font-size') and IsInheritedStyleKey('text-align'),'typography/content keys inherit');
  Check(not (IsInheritedStyleKey('fill') or IsInheritedStyleKey('border-color') or
        IsInheritedStyleKey('radius') or IsInheritedStyleKey('tint')),'box chrome does not inherit');
  Check(IsInheritedStyleKey('Color'),'key match is case-insensitive');
  Check(not IsInheritedStyleKey('col'),'partial key does not match');
  EndTest;
end;

// State blocks declared inside a named style must apply to elements referencing it,
// both when the state is active (resolve path) and when asked for explicitly (blending).
procedure TestStateFromRef;
var
  b:TStyleBlock;
begin
  StartTest('State blocks inside @refs');
  Styles['btn']:='fill: $FF303030; :hover { fill: $FF808080; } :pressed { fill: $FF101010; }';
  b:=TStyleBlock.Create;
  b.ParseText('@btn;');
  Check(ResolveBlockColor(b,'fill',0)=$FF303030,'base fill from ref');
  Check(ResolveBlockStateColor(b,'hover','fill',0)=$FF808080,'ref hover value for blending');
  Check(ResolveBlockStateColor(b,'missing','fill',$FF010101)=$FF010101,'unknown state falls back');
  b.SetState('hover',true);
  Check(ResolveBlockColor(b,'fill',0)=$FF808080,'ref hover applied when active');
  b.SetState('hover',false);
  Check(ResolveBlockColor(b,'fill',0)=$FF303030,'base fill restored');
  // a local state block wins over the ref one
  b.ParseText('@btn; :hover { fill: $FF00FF00; }');
  Check(ResolveBlockStateColor(b,'hover','fill',0)=$FF00FF00,'local state beats ref state');
  // a state (from any level) wins over a plain local value
  b.ParseText('@btn; fill: $FF0000FF;');
  Check(ResolveBlockColor(b,'fill',0)=$FF0000FF,'local plain fill');
  b.SetState('hover',true);
  Check(ResolveBlockColor(b,'fill',0)=$FF808080,'ref state beats local plain value');
  // the state priority goes first: a later active state from a ref beats an earlier local one
  Styles['btn2']:=':disabled { fill: $FF222222; }';
  b.ParseText('@btn2; :hover { fill: $FF111111; }');
  b.SetState('hover',true);
  b.SetState('disabled',true);
  Check(ResolveBlockColor(b,'fill',0)=$FF222222,'later ref state beats earlier local state');
  b.SetState('disabled',false);
  Check(ResolveBlockColor(b,'fill',0)=$FF111111,'local hover alone');
  Styles.Remove('btn2');
  b.Free;
  Styles.Remove('btn');
  EndTest;
end;

// Parts: 'name { ... }' blocks with their own keys, states and refs
procedure TestParts;
var
  b,b2:TStyleBlock;
begin
  StartTest('Parts');
  b:=TStyleBlock.Create;
  b.ParseText('fill: #111111; header { fill: #222222; :hover { fill: #333333 } } row { color: #444444; } border-width: 2;');
  Check(ResolveBlockAttr(b,'fill')='#111111','element key');
  Check(ResolveBlockAttr(b,'border-width')='2','key after the parts');
  Check((b.Part('header')<>nil) and (b.Part('ROW')<>nil) and (b.Part('body')=nil),'part blocks');
  Check(ResolvePartAttr(b,'header','','fill')='#222222','part key');
  Check(ResolvePartAttr(b,'header','hover','fill')='#333333','part state');
  Check(ResolvePartAttr(b,'header','pressed','fill')='','undeclared part state');
  Check(ResolvePartAttr(b,'row','','fill')='','part box keys do not come from the element');
  // round trip
  b2:=TStyleBlock.Create;
  b2.ParseText(b.GetText);
  Check(ResolvePartAttr(b2,'header','hover','fill')='#333333','round trip');
  b2.Free;
  // a ref carries parts; the element's part wins by keys
  Styles['test-window']:='header { fill: #AAAAAA; line-color: #BBBBBB; }';
  b.ParseText('@test-window; header { fill: #CCCCCC; }');
  Check(ResolvePartAttr(b,'header','','fill')='#CCCCCC','own part over the ref part');
  Check(ResolvePartAttr(b,'header','','line-color')='#BBBBBB','ref part key');
  // the old prefixed keys are aliases
  b.ParseText('header-fill: #DDDDDD; row-hover-fill: #EEEEEE;');
  Check(ResolvePartAttr(b,'header','','fill')='#DDDDDD','alias');
  Check(ResolvePartAttr(b,'row','hover','fill')='#EEEEEE','state alias');
  // tokens
  SetToken('test-part','#123456');
  b.ParseText('header { fill: &test-part; }');
  Check(ResolvePartAttr(b,'header','','fill')='#123456','token');
  RemoveToken('test-part');
  b.Free;
  Styles.Remove('test-window');
  EndTest;
end;

// Token layers: the defaults survive a theme swap, the theme and the application override them
procedure TestTokenLayers;
begin
  StartTest('Token layers');
  SetDefaultToken('test-layer','#010101');
  Check(GetToken('test-layer')='#010101','default');
  Check(HasToken('test-layer'),'HasToken sees the default');
  SetToken('test-layer','#020202');
  Check(GetToken('test-layer')='#020202','application over default');
  ApplyTheme('dark');
  Check(GetToken('test-layer')='#010101','theme swap keeps the default, drops the application value');
  ClearTokens;
  Check(GetToken('test-layer')='#010101','ClearTokens keeps the default');
  Check(ExpandToken('&test-layer')='#010101','expansion');
  ApplyTheme('light'); // restore
  EndTest;
end;

// Tokens must be expanded in state values too, not only in plain ones
procedure TestTokenInRefState;
var
  b:TStyleBlock;
begin
  StartTest('Token in a ref state block');
  SetToken('accent','$FF3366CC');
  Styles['tokbtn']:='fill: $FF303030; :hover { fill: &accent; }';
  b:=TStyleBlock.Create;
  b.ParseText('@tokbtn;');
  Check(ResolveBlockStateColor(b,'hover','fill',0)=$FF3366CC,'token expanded in ref state');
  b.SetState('hover',true);
  Check(ResolveBlockColor(b,'fill',0)=$FF3366CC,'token expanded when state is active');
  b.Free;
  Styles.Remove('tokbtn');
  RemoveToken('accent');
  EndTest;
end;

// --- Fills (R-39) ---

var
  rampTex:TObject; // a stand-in for a ramp texture

function TestImageResolver(const src:String8):TObject;
begin
  if src='file:ramp.png' then result:=rampTex else result:=nil;
end;

function Near(a,b:single):boolean;
begin
  result:=abs(a-b)<1E-4;
end;

procedure TestFillPlain;
var
  f:TFill;
begin
  StartTest('Fill: plain values');
  Check(ParseStyleFill('$FF102030',f) and (f.kind=fkSolid) and (f.stops[0].color=$FF102030),'color');
  Check(ParseStyleFill('#ABC',f) and (f.stops[0].color=$FFAABBCC),'short color');
  Check(ParseStyleFill('none',f) and (f.kind=fkNone),'none');
  Check(ParseStyleFill('0',f) and (f.kind=fkSolid) and (f.stops[0].color=0),'zero color');
  Check(ParseStyleFill('$00000000',f) and (f.stops[0].color=0),'transparent black');
  Check(not ParseStyleFill('',f),'empty');
  Check(not ParseStyleFill('junk',f),'invalid color');
  EndTest;
end;

procedure TestFillLinear;
var
  f:TFill;
begin
  StartTest('Fill: linear');
  Check(ParseStyleFill('linear(180deg, #FF0000, #0000FF)',f),'parsed');
  Check((f.kind=fkLinear) and (f.units=fuAngle) and Near(f.p0.x,180),'angle');
  Check((f.stopCount=2) and (f.stops[0].color=$FFFF0000) and (f.stops[1].color=$FF0000FF),'colors');
  Check(Near(f.stops[0].pos,0) and Near(f.stops[1].pos,1),'default positions');
  Check(f.spread=fsPad,'pad by default');
  Check(ParseStyleFill('linear(to right, #000, #FFF)',f) and Near(f.p0.x,90),'to right');
  Check(ParseStyleFill('LINEAR( 45 ,#000,#FFF )',f) and Near(f.p0.x,45),'case, spaces, no deg');
  Check(ParseStyleFill('linear(90deg, #000, #F00, #0F0 75%, #FFF)',f) and (f.stopCount=4),'4 stops');
  Check(Near(f.stops[1].pos,0.375) and Near(f.stops[2].pos,0.75),'missing positions spread evenly');
  Check(ParseStyleFill('linear(90deg, #000 60%, #FFF 20%)',f) and Near(f.stops[1].pos,0.6),'a position never goes back');
  Check(ParseStyleFill('linear(90deg, #000, #FFF 50%, reflect)',f) and (f.spread=fsReflect) and
    Near(f.stops[1].pos,0.5),'reflect');
  Check(ParseStyleFill('linear(90deg, #000, #FFF, repeat)',f) and (f.spread=fsRepeat),'repeat');
  Check(not ParseStyleFill('linear(90deg, #000, #111, #222, #333, #444)',f),'5 stops');
  Check(not ParseStyleFill('linear(90deg, #000)',f),'1 stop');
  Check(not ParseStyleFill('linear(abc, #000, #FFF)',f),'bad angle');
  Check(not ParseStyleFill('linear(90deg, #000, nocolor)',f),'bad stop');
  Check(not ParseStyleFill('radial(#000, #FFF)',f),'unknown function');
  EndTest;
end;

procedure TestFillEdgeAndRamp;
var
  f:TFill;
begin
  StartTest('Fill: edge and ramp');
  Check(ParseStyleFill('edge(4, #FF5A6270, #FFC8D0DC 40%, #FF3A4250)',f) and (f.kind=fkEdge),'edge');
  Check(Near(f.p0.x,4) and (f.stopCount=3) and Near(f.stops[1].pos,0.4),'width and stops');
  Check(not ParseStyleFill('edge(0, #000, #FFF)',f),'zero width');
  rampTex:=TObject.Create;
  StyleImageResolver:=nil;
  Check(not ParseStyleFill('linear(0deg, url(file:ramp.png))',f),'no resolver');
  StyleImageResolver:=TestImageResolver;
  inc(stylesRevision); // the failed result above is cached
  Check(ParseStyleFill('linear(0deg, url(file:ramp.png))',f) and (f.ramp=rampTex) and (f.kind=fkLinear),'ramp');
  Check(ParseStyleFill('edge(3, url(file:ramp.png))',f) and (f.ramp=rampTex) and (f.kind=fkEdge),'edge ramp');
  Check(not ParseStyleFill('linear(0deg, url(file:other.png))',f),'unresolved image');
  StyleImageResolver:=nil;
  inc(stylesRevision);
  rampTex.Free;
  EndTest;
end;

procedure TestFillTokens;
var
  f:TFill;
  b:TStyleBlock;
begin
  StartTest('Fill: tokens, cache, blocks');
  SetToken('fill-a','$FF00FF00');
  SetToken('fill-stop','#FFFFFF 30%');
  SetToken('fill-shade','linear(180deg, #30FFFFFF, #30000000)');
  Check(ParseStyleFill('linear(0deg, &fill-a, &fill-stop, #000)',f) and (f.stops[0].color=$FF00FF00),'token color');
  Check((f.stops[1].color=$FFFFFFFF) and Near(f.stops[1].pos,0.3),'token stop with a position');
  Check(ParseStyleFill('&fill-shade',f) and (f.kind=fkLinear) and (f.stops[0].color=$30FFFFFF),'whole token');
  // a token change invalidates cached results
  SetToken('fill-a','$FFFF0000');
  Check(ParseStyleFill('linear(0deg, &fill-a, &fill-stop, #000)',f) and (f.stops[0].color=$FFFF0000),'cache follows tokens');
  // through the style text and the resolvers
  b:=TStyleBlock.Create;
  b.ParseText('fill: linear(180deg, #6F7F98, #435166); border-color: #C8D4E8; :hover { fill: &fill-a; }');
  f:=ResolveBlockFill(b,'fill',TFill.None);
  Check((f.kind=fkLinear) and (f.stops[1].color=$FF435166),'gradient survives style parsing');
  Check(ResolveBlockFill(b,'border-color',TFill.None).stops[0].color=$FFC8D4E8,'color as a fill');
  Check(ResolveBlockFill(b,'missing',TFill.Solid($FF123456)).stops[0].color=$FF123456,'default');
  b.SetState('hover',true);
  f:=ResolveBlockFill(b,'fill',TFill.None);
  Check((f.kind=fkSolid) and (f.stops[0].color=$FFFF0000),'state fill');
  b.Free;
  RemoveToken('fill-a');
  RemoveToken('fill-stop');
  RemoveToken('fill-shade');
  EndTest;
end;

procedure TestRadii;
var
  r:TCornerRadii;
begin
  StartTest('Corner radii');
  Check(ParseStyleRadii('6',r) and Near(r.topLeft,6) and Near(r.bottomLeft,6),'one value');
  Check(ParseStyleRadii('6 0',r) and Near(r.topLeft,6) and Near(r.topRight,0) and
    Near(r.bottomRight,6) and Near(r.bottomLeft,0),'two values');
  Check(ParseStyleRadii('1 2 3',r) and Near(r.topRight,2) and Near(r.bottomRight,3) and Near(r.bottomLeft,2),'three values');
  Check(ParseStyleRadii(' 1  2 3 4 ',r) and Near(r.topLeft,1) and Near(r.bottomLeft,4),'four values');
  Check(not ParseStyleRadii('',r),'empty');
  Check(not ParseStyleRadii('1 2 3 4 5',r),'five values');
  EndTest;
end;

// --- Main ---
begin
  writeln('=== TestStyle ===');
  TestBasicParsing;
  TestGetColor;
  TestStateBlocks;
  TestPatchText;
  TestNamedRefs;
  TestLocalOverridesRef;
  TestParseStyleColor;
  TestResolveBlockAttr;
  TestPatchRemove;
  TestGetNumber;
  TestGetText;
  TestTokenStore;
  TestSetTokenColor;
  TestTokenSubstitution;
  TestTokenInStateAndRef;
  TestTokenChainAndCycle;
  TestUnknownToken;
  TestTokenInNumbers;
  TestThemeSwap;
  TestInheritedKeys;
  TestStateFromRef;
  TestTokenInRefState;
  TestFillPlain;
  TestFillLinear;
  TestFillEdgeAndRamp;
  TestFillTokens;
  TestRadii;
  TestParts;
  TestTokenLayers;
  writeln;
  if testsFailed=0 then
    writeln('All tests passed ('+IntToStr(testsTotal)+')')
  else begin
    writeln('FAILED: '+IntToStr(testsFailed)+' of '+IntToStr(testsTotal));
    ExitCode:=1;
  end;
  if IsDebuggerPresent then begin
    writeln('Press [ENTER] to exit');
    readln;
  end;
end.
