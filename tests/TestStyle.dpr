{$APPTYPE CONSOLE}
program TestStyle;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
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
