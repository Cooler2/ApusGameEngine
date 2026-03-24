{$APPTYPE CONSOLE}
program TestStyle;
uses
  SysUtils,
  Apus.Core,
  Apus.Conv,
  Apus.Strings,
  Apus.Engine.Style;

{$I ..\Base\tests\test.inc}

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
