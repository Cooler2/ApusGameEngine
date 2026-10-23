{$APPTYPE CONSOLE}
program TestConfig;
uses
  SysUtils,
  Apus.Core,
  Apus.Files,
  Apus.EventMan,
  Apus.Config;

{$INCLUDE Test.inc}

const
  TMPDIR='_test_config_tmp';
  DIR=TMPDIR+'/';
  // typed: a bare float literal is extended on some targets and never equals a double
  F03:double=0.3;
  F1E7:double=1e-7;
  F13:double=1/3;

type
  // XOR with a random nonce: the output differs on every call
  TTestProtector=class(TInterfacedObject,IConfigProtector)
    function Protect(const data:ByteArray):ByteArray;
    function Unprotect(const data:ByteArray):ByteArray;
  end;

var
  reloadSignals:integer=0;

function TTestProtector.Protect(const data:ByteArray):ByteArray;
var
  i:integer;
begin
  SetLength(result,length(data)+1);
  result[0]:=1+random(254);
  for i:=0 to high(data) do result[i+1]:=data[i] xor byte(result[0]+i);
end;

function TTestProtector.Unprotect(const data:ByteArray):ByteArray;
var
  i:integer;
begin
  if length(data)=0 then raise EError.Create('protected data expected');
  SetLength(result,length(data)-1);
  for i:=0 to high(result) do result[i]:=data[i+1] xor byte(data[0]+i);
end;

procedure OnReloaded(event:TEventStr;tag:TTag);
begin
  inc(reloadSignals);
end;

// A string from bytes: a char literal above 127 is not a byte in a Unicode compiler
function Bytes8(const b:array of byte):String8;
var
  i:integer;
begin
  SetLength(result,length(b));
  for i:=0 to high(b) do result[i+1]:=AnsiChar(b[i]);
end;

function NormLF(const s:String8):String8;
begin
  result:=String8(StringReplace(string(s),#13#10,#10,[rfReplaceAll]));
end;

procedure Put(const name,text:String8);
begin
  Files.Save(DIR+name,text,false);
end;

function GetRaw(const name:String8):String8;
var
  data:ByteArray;
begin
  data:=Files.LoadAsBytes(DIR+name);
  SetLength(result,length(data));
  if length(data)>0 then move(data[0],result[1],length(data));
end;

function Get(const name:String8):String8;
begin
  result:=NormLF(GetRaw(name));
end;

// The message of the error a document load raises ('' - loaded)
function LoadError(const name:String8):string;
var
  cfg:TConfig;
begin
  result:='';
  try
    cfg:=TConfig.Create(DIR+name);
    cfg.Free;
  except
    on e:Exception do result:=e.Message;
  end;
end;

procedure Cleanup;
begin
  if Folder.Exists(TMPDIR) then Folder.Delete(TMPDIR);
end;

procedure TestSyntax;
const
  T='# comment'#10+
    'instanceID = 35672194'#10+
    'options {'#10+
    '  fullScreen   = off'#10+
    '  windowWidth  = 1024'#10+
    '  title        = "My game"         # inline comment'#10+
    '  path = ''C:\Games\new'''#10+
    '  esc = "a\"b\\c\nd\u0041\u00e9\uD83D\uDE00"'#10+
    '  color #FF8000'#10+
    '  url = http://a/#top'#10+
    '  hello = Hello, world'#10+
    '}'#10+
    'music {'#10+
    '  intro { file = "intro.ogg", volume = 50, loop = on }'#10+
    '}'#10+
    'spawn = ['#10+
    '  { x = 10, y = 20 }'#10+
    '  {'#10+
    '    x = 30'#10+
    '    y = 5'#10+
    '  }'#10+
    ']'#10+
    'preload = ["click.ogg", "hit.ogg"]'#10+
    'list2 = ( a, b, c )'#10+
    'nothing = null'#10+
    'colon: 5'#10+
    '// slash comment'#10+
    '; semicolon comment'#10+
    '"quoted key" = 7'#10+
    'raw = ''it''''s'''#10+
    'trailing = 1,'#10;
var
  cfg:TConfig;
  r:TCfgNode;
  sa:Strings8;
begin
  StartTest('CTL3 syntax');
  Put('syntax.ctl',T);
  cfg:=TConfig.Create(DIR+'syntax.ctl');
  try
    r:=cfg.Root;
    Check(r.Int('instanceID')=35672194,'int');
    Check(not r.Bool('options.fullScreen',true),'bool off');
    Check(r.Int('options.windowWidth')=1024,'int in a section');
    Check(r.Str('options.title')='My game','quoted string with an inline comment');
    Check(r.Str('options.path')='C:\Games\new','raw string');
    Check(r.Str('options.esc')='a"b\c'#10'dA'+Bytes8([$C3,$A9,$F0,$9F,$98,$80]),'escapes: '+string(r.Str('options.esc')));
    Check(r.Str('options.color')='#FF8000','a value may start with #');
    Check(r.Str('options.url')='http://a/#top','# inside a value');
    Check(r.Str('options.hello')='Hello, world','bare value with a comma');
    Check(r.Node('options').Count=8,'section size');
    Check(r.Int('music.intro.volume')=50,'inline section');
    Check(r.Bool('music.intro.loop'),'inline section bool');
    Check(r.Node('spawn').Count=2,'array of sections');
    Check((r.Int('spawn[0].y')=20) and (r.Int('spawn[1].x')=30),'items of an array');
    sa:=r.Strs('preload');
    Check((length(sa)=2) and (sa[1]='hit.ogg'),'array of strings');
    sa:=r.Strs('list2');
    Check((length(sa)=3) and (sa[0]='a') and (sa[2]='c'),'list in parentheses');
    Check(r.Node('nothing').Kind=ckNull,'null kind');
    Check(r.Int('nothing',77)=77,'null reads give the default');
    Check(r.Int('colon')=5,'colon separator');
    Check(r.Child('quoted key').AsInt=7,'quoted key');
    Check(r.Str('raw')='it''s','doubled quote in a raw string');
    Check(r.Int('trailing')=1,'trailing comma');
    Check(r.Node('options').Kind=ckSection,'section kind');
    Check(r.Node('preload').Kind=ckArray,'array kind');
    Check(r.Node('instanceID').Kind=ckScalar,'scalar kind');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestJson;
const
  J='{'#10+
    '  "name": "test",'#10+
    '  "size": 12.5,'#10+
    '  "flags": [true, false],'#10+
    '  "nested": {"a": 1, "b": {"c": "x\/y"}},'#10+
    '  "empty": null,'#10+
    '  "list": ['#10+
    '    {"id": 1},'#10+
    '    {"id": 2}'#10+
    '  ]'#10+
    '}'#10;
var
  cfg:TConfig;
  r:TCfgNode;
begin
  StartTest('JSON subset');
  Put('data.json',J);
  Put('compact.ctl','{"a":1,"b":[1,2],"c":{"d":"e"}}');
  cfg:=TConfig.Create(DIR+'data.json');
  try
    r:=cfg.Root;
    Check(r.Str('name')='test','string');
    Check(r.Float('size')=12.5,'number');
    Check(r.Bool('flags[0]') and not r.Bool('flags[1]',true),'booleans');
    Check(r.Int('nested.a')=1,'nested object');
    Check(r.Str('nested.b.c')='x/y','escaped slash');
    Check(r.Node('empty').Kind=ckNull,'null');
    Check((r.Node('list').Count=2) and (r.Int('list[1].id')=2),'array of objects');
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'compact.ctl');
  try
    r:=cfg.Root;
    Check((r.Int('a')=1) and (r.Int('b[1]')=2) and (r.Str('c.d')='e'),'compact root object');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestTyping;
const
  T='i1 42'#10'i2 -7'#10'i3 +5'#10'h1 $2A'#10'h2 0x2A'#10'f0 2.0'#10'f1 2.5'#10+
    'big 99999999999999999999'#10's1 abc'#10'q "42"'#10+
    'b1 on'#10'b2 OFF'#10'b3 yes'#10'b4 No'#10'b5 1'#10'b6 0'#10'b7 true'#10'b8 maybe'#10+
    'e1 Medium'#10'ver 1.10'#10'lang no'#10'loop1 1'#10'dot1 1.'#10'dot2 .5'#10'e3 1e3'#10+
    'neg -9223372036854775808'#10'third 0.3'#10+
    'sec {'#10'  a 1'#10'}'#10;
var
  cfg:TConfig;
  r:TCfgNode;
  sa:Strings8;
  failed:boolean;
begin
  StartTest('Typing');
  Put('types.ctl',T);
  cfg:=TConfig.Create(DIR+'types.ctl');
  try
    r:=cfg.Root;
    Check(r.Int('i1')=42,'Int decimal');
    Check(r.Int('i2')=-7,'Int negative');
    Check(r.Int('i3')=5,'Int with plus');
    Check((r.Int('h1')=42) and (r.Int('h2')=42),'Int hex');
    Check(r.Int('f0')=2,'Int from an integral float');
    Check(r.Int('f1',99)=99,'Int from a fraction gives the default');
    Check(r.Int('big',99)=99,'Int overflow gives the default');
    Check(r.Int('neg')=Low(int64),'Int minimum');
    Check(r.Int('s1',99)=99,'Int from text gives the default');
    Check(r.Int('q')=42,'quotes don''t change the type');
    Check(r.Float('f1')=2.5,'Float');
    Check((r.Float('i1')=42) and (r.Float('h1')=42),'Float from integers');
    Check((r.Float('dot1',-1)=-1) and (r.Float('dot2',-1)=-1),'Float needs digits on both sides of the dot');
    Check((r.Float('e3')=1000) and (r.Int('e3')=1000),'exponent');
    Check(r.Float('third')=F03,'Float is exact');
    Check(r.Float('loop1')=1,'Float from 1');
    Check(r.Bool('b1') and not r.Bool('b2',true) and r.Bool('b3') and not r.Bool('b4',true),'Bool words');
    Check(r.Bool('b5') and not r.Bool('b6',true) and r.Bool('b7'),'Bool digits and true');
    Check(r.Bool('b8',true) and not r.Bool('b8',false),'Bool of other text gives the default');
    Check(r.Enum('e1',['low','medium','high'])=1,'Enum');
    Check(r.Enum('s1',['low','medium'],-1)=-1,'Enum of an unknown name');
    Check(r.Str('ver')='1.10','Str keeps the text');
    Check((r.Str('lang')='no') and not r.Bool('lang',true),'Str and Bool of the same value');
    Check(r.Int('missing',5)=5,'missing key');
    Check(r.Int('sec',5)=5,'Int of a section');
    Check(r.Str('sec','d')='d','Str of a section');
    sa:=r.Strs('s1');
    Check((length(sa)=1) and (sa[0]='abc'),'Strs of a scalar');
    Check(length(r.Strs('sec'))=0,'Strs of a section');
    Check(r.Node('i1').AsInt=42,'AsInt');
    Check(r.ReqInt('i1')=42,'ReqInt');
    Check(r.ReqStr('ver')='1.10','ReqStr');
    failed:=false;
    try r.ReqInt('missing'); except on e:EConfigError do failed:=true; end;
    Check(failed,'ReqInt of a missing key raises');
    failed:=false;
    try r.ReqInt('s1'); except on e:EConfigError do failed:=Pos('types.ctl:9',e.Message)>0; end;
    Check(failed,'ReqInt of text raises with the location');
    failed:=false;
    try r.ReqBool('b8'); except on e:EConfigError do failed:=true; end;
    Check(failed,'ReqBool raises');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestNavigation;
const
  T='a {'#10'  B {'#10'    c = 1'#10'  }'#10'}'#10'arr = [{ x = 1 }, { x = 2 }]'#10'k1 = 1'#10'k2 = 2'#10;
var
  cfg:TConfig;
  r,n,child:TCfgNode;
  names:String8;
begin
  StartTest('Paths and navigation');
  Put('nav.ctl',T);
  cfg:=TConfig.Create(DIR+'nav.ctl');
  try
    r:=cfg.Root;
    Check(r.Int('a.b.c')=1,'dots, case-insensitive');
    Check((r.Int('A\B\C')=1) and (r.Int('a/b/c')=1),'backslashes and slashes');
    Check(r.Node('a').Node('b').Int('c')=1,'chained nodes');
    Check(r.Int('arr[1].x')=2,'index in a path');
    Check(r.Node('arr').Item(0).Int('x')=1,'Item of an array');
    Check(r.Node('a.b').Name='B','Name keeps the spelling');
    Check(r.Node('a.b.c').Path='a.b.c','Path');
    Check(r.Node('arr[1]').Path='arr[1]','Path with an index');
    Check(r.Node('a.b.c').Location=Files.FixName(DIR+'nav.ctl')+':3','Location: '+string(r.Node('a.b.c').Location));
    Check(r.Node('a.b').Location=Files.FixName(DIR+'nav.ctl')+':2','Location of a section');
    Check(not r.Node('x').Node('y').Exists,'missing chain');
    Check(r.Node('x').Node('y').Int('z',3)=3,'reads of a missing chain');
    Check(r.Node('x').Location='','Location of a missing node');
    Check(r.Count=4,'root size');
    names:='';
    for child in r do names:=names+child.Name+' ';
    Check(names='a arr k1 k2 ','iteration: '+string(names));
    n:=r.Node('arr');
    names:='';
    for child in n do names:=names+String8(IntToStr(child.Int('x')));
    Check(names='12','iteration over an array');
    Check(r.Item(2).AsInt=1,'Item of a section');
    Check(not r.Item(10).Exists,'Item out of range');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestCTL2;
const
  T='# ---- #'#13#10+
    '$Section Settings'#13#10+
    '  ; comment'#13#10+
    '  PreloadSamples        "sample.ogg"'#13#10+
    '  Path   "C:\new"'#13#10+
    '$EndOfSection'#13#10+
    '$Section Music'#13#10+
    '  $Section TestOGG'#13#10+
    '    File     "music.ogg"'#13#10+
    '    volume   50'#13#10+
    '    loop     ON'#13#10+
    '    loopTime 0.5'#13#10+
    '  $EndOfSection'#13#10+
    '$EndOfSection'#13#10+
    'List    ("a", "b",'#13#10+
    '         "c")'#13#10+
    'Title My cool game'#13#10+
    '$Section Sub'#13#10+
    '$Include sub2.ctl'#13#10+
    '$EndOfSection'#13#10;
var
  cfg:TConfig;
  r:TCfgNode;
  sa:Strings8;
begin
  StartTest('CTL2 dialect');
  Put('old.ctl',T);
  Put('sub2.ctl','Depth 3'#13#10'Name "deep"'#13#10);
  cfg:=TConfig.Create(DIR+'old.ctl');
  try
    r:=cfg.Root;
    Check(r.Str('Settings.PreloadSamples')='sample.ogg','quoted value');
    Check(r.Str('settings.path')='C:\new','no escapes in CTL2');
    Check(r.Int('Music.TestOGG.volume')=50,'nested section');
    Check(r.Bool('music.testogg.loop'),'ON');
    Check(r.Float('music.testogg.looptime')=0.5,'float');
    sa:=r.Strs('List');
    Check((length(sa)=3) and (sa[2]='c'),'multiline list');
    Check(r.Str('Title')='My cool game','rest of the line');
    Check((r.Int('Sub.Depth')=3) and (r.Str('Sub.Name')='deep'),'$Include merges into the section');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestIncludes;
var
  cfg:TConfig;
  r:TCfgNode;
  msg:string;
begin
  StartTest('Include and duplicates');
  Put('main.ctl','sec {'#10'  x = 1'#10'  @include "inc.ctl"'#10'}'#10'@include "root.ctl"'#10);
  Put('inc.ctl','y = 2'#10);
  Put('root.ctl','sec {'#10'  z = 3'#10'}'#10'b = 2'#10);
  cfg:=TConfig.Create(DIR+'main.ctl');
  try
    r:=cfg.Root;
    Check((r.Int('sec.x')=1) and (r.Int('sec.y')=2) and (r.Int('sec.z')=3),'sections merge across files');
    Check(r.Node('sec').Count=3,'merged section size');
    Check(r.Int('b')=2,'root include');
    Check(r.Node('sec.y').Location=Files.FixName(DIR+'inc.ctl')+':1','location in an included file');
  finally
    cfg.Free;
  end;
  Put('dup.ctl','a = 1'#10'a = 2'#10);
  msg:=LoadError('dup.ctl');
  Check((Pos('dup.ctl:2',msg)>0) and (Pos('dup.ctl:1',msg)>0) and (Pos('duplicate',msg)>0),'duplicate key: '+msg);
  Put('dup2.ctl','a = 1'#10'a {'#10'}'#10);
  msg:=LoadError('dup2.ctl');
  Check(Pos('duplicate',msg)>0,'a key and a section: '+msg);
  Put('c1.ctl','@include "c2.ctl"'#10);
  Put('c2.ctl','@include "c1.ctl"'#10);
  msg:=LoadError('c1.ctl');
  Check(Pos('cycle',msg)>0,'include cycle: '+msg);
  Put('noinc.ctl','a = 1'#10'@include "nothere.ctl"'#10);
  msg:=LoadError('noinc.ctl');
  Check((Pos('not found',msg)>0) and (Pos('noinc.ctl:2',msg)>0),'missing include: '+msg);
  msg:=LoadError('nofile.ctl');
  Check(Pos('not found',msg)>0,'missing file: '+msg);
  EndTest;
end;

procedure TestErrors;

  procedure Expect(const text,part,where:String8);
  var
    msg:string;
  begin
    Put('err.ctl',text);
    msg:=LoadError('err.ctl');
    Check((Pos(string(part),msg)>0) and (Pos(string('err.ctl:'+where),msg)>0),'"'+string(part)+'": '+msg);
  end;

begin
  StartTest('Parse errors');
  Expect('a = "open'#10,'unterminated string','1:');
  Expect('sec {'#10'  a = 1'#10,'"}" expected','');
  Expect('a = "x" y'#10,'unexpected text','1:');
  Expect('= 5'#10,'key expected','1:1');
  Expect('ok = 1'#10'a'#10,'value expected for key "a"','2:');
  Expect('@foo "x"'#10,'unknown directive','1:');
  Expect('{ "a": 1 } x'#10,'after the root object','1:');
  Expect('a = [1 2]'#10,'"," or "]" expected','1:');
  Expect('s {'#10'  a = "1" }'#10,'must start a line','2:');
  Expect('a = {b = 1 c = 2}'#10,'"," or "}" expected','1:');
  Expect('}'#10,'unexpected "}"','1:');
  Expect('$EndOfSection'#10,'unexpected $EndOfSection','1');
  Expect('$Section'#10'$EndOfSection'#10,'unnamed section','1');
  Expect('$Section A'#10'Key'#10'$EndOfSection'#10,'no value for key Key','2');
  EndTest;
end;

procedure TestSavePreserves;
const
  ORIG='# Settings'#10+
    'options {'#10+
    '  fullScreen   = OFF'#10+
    '  windowWidth  = 1024     # pixels'#10+
    '  title        = "Game"'#10+
    '  removeMe     = 1'#10+
    '  speed        = 1'#10+
    '}'#10+
    #10+
    'music {'#10+
    '  intro { file = "intro.ogg", volume = 50, loop = on }'#10+
    '}'#10+
    'last = 1'#10;
  EXP1='# Settings'#10+
    'options {'#10+
    '  fullScreen   = ON'#10+
    '  windowWidth  = 1280     # pixels'#10+
    '  title        = "New"'#10+
    '  speed        = 0.5'#10+
    '  newKey = 5'#10+
    '}'#10+
    #10+
    'music {'#10+
    '  intro { file = "intro.ogg", volume = 60, loop = on }'#10+
    '}'#10+
    'last = 1'#10+
    'added = 1'#10;
  EXP2='# Settings'#10+
    'options {'#10+
    '  fullScreen   = ON'#10+
    '  windowWidth  = 1280     # pixels'#10+
    '  title        = "New"'#10+
    '  speed        = 0.5'#10+
    '  newKey = 5'#10+
    '}'#10+
    #10+
    'music {'#10+
    '  intro { file = "intro.ogg", volume = 60, loop = on, pan = 1 }'#10+
    '}'#10+
    'last = 1'#10+
    'added = 1'#10;
  EXP3='# Settings'#10+
    'options {'#10+
    '  fullScreen   = ON'#10+
    '  windowWidth  = 1280     # pixels'#10+
    '  title        = "New"'#10+
    '  speed        = 0.5'#10+
    '  newKey = 5'#10+
    '}'#10+
    #10+
    'last = 1'#10+
    'added = 1'#10;
var
  cfg:TConfig;
  r,h:TCfgNode;
begin
  StartTest('Save keeps unchanged lines');
  Put('keep.ctl',ORIG);
  cfg:=TConfig.Create(DIR+'keep.ctl');
  try
    // an unmodified document is not written
    Files.Delete(DIR+'keep.ctl');
    cfg.Save;
    Check(not Files.Exists(DIR+'keep.ctl'),'unmodified document is not saved');
    Put('keep.ctl',ORIG);
    r:=cfg.Root;
    h:=r.Node('options.windowWidth');
    r.SetInt('options.windowWidth',1280);
    r.SetStr('options.title','New');
    r.SetInt('options.newKey',5);
    r.SetInt('added',1);
    r.Delete('options.removeMe');
    r.SetBool('options.fullScreen',true);
    r.SetFloat('options.speed',0.5);
    r.SetInt('music.intro.volume',60);
    Check(cfg.Modified,'modified');
    cfg.Save;
    Check(not cfg.Modified,'saved');
    Check(GetRaw('keep.ctl')=EXP1,'changed values only:'#10+string(GetRaw('keep.ctl')));
    Check(h.AsInt=1280,'a handle survives the save');
    Check(not r.Node('options.removeMe').Exists,'deleted key');
    r.SetInt('music.intro.pan',1);
    cfg.Save;
    Check(GetRaw('keep.ctl')=EXP2,'inline section rewritten:'#10+string(GetRaw('keep.ctl')));
    r.Delete('music');
    cfg.Save;
    Check(GetRaw('keep.ctl')=EXP3,'section deleted:'#10+string(GetRaw('keep.ctl')));
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'keep.ctl');
  try
    r:=cfg.Root;
    Check((r.Int('options.windowWidth')=1280) and (r.Str('options.title')='New') and
      r.Bool('options.fullScreen') and (r.Float('options.speed')=0.5) and (r.Int('added')=1),'reloaded values');
  finally
    cfg.Free;
  end;
  // CRLF and a BOM are kept
  Put('crlf.ctl',Bytes8([$EF,$BB,$BF])+'a = 1'#13#10'b = 2'#13#10);
  cfg:=TConfig.Create(DIR+'crlf.ctl');
  try
    cfg.Root.SetInt('b',3);
    cfg.Save;
  finally
    cfg.Free;
  end;
  Check(GetRaw('crlf.ctl')=Bytes8([$EF,$BB,$BF])+'a = 1'#13#10'b = 3'#13#10,'CRLF and BOM kept');
  EndTest;
end;

procedure TestSaveValues;
const
  EXP='list = ["x", "y"]'#10+
    'a = 1'#10+
    'f1 = 0.3'#10+
    'f2 = 1E-7'#10+
    'f3 = 0.3333333333333333'#10+
    'f4 = 2.0'#10+
    's = "line1\nline2 \"q\" back\\slash"'#10+
    'b = on'#10+
    'new {'#10+
    '  sub {'#10+
    '    k = 1'#10+
    '  }'#10+
    '}'#10;
var
  cfg:TConfig;
  r:TCfgNode;
  failed:boolean;
  sa:Strings8;
begin
  StartTest('Saving values');
  Put('vals.ctl','list = "x"'#10'a = 1'#10'gone = 2'#10);
  cfg:=TConfig.Create(DIR+'vals.ctl');
  try
    r:=cfg.Root;
    r.SetStrs('list',['x','y']);
    r.Delete('gone');
    r.SetFloat('f1',F03);
    r.SetFloat('f2',F1E7);
    r.SetFloat('f3',F13);
    r.SetFloat('f4',2);
    r.SetStr('s','line1'#10'line2 "q" back\slash');
    r.SetBool('b',true);
    r.AddSection('new.sub');
    r.SetInt('new.sub.k',1);
    failed:=false;
    try r.SetInt('a.b',1); except on e:EConfigError do failed:=true; end;
    Check(failed,'write through a value raises');
    failed:=false;
    try r.SetInt('new',1); except on e:EConfigError do failed:=true; end;
    Check(failed,'a value over a section raises');
    failed:=false;
    try r.Delete(''); except on e:EConfigError do failed:=true; end;
    Check(failed,'the root can''t be deleted');
    cfg.Save;
    Check(GetRaw('vals.ctl')=EXP,'canonical values:'#10+string(GetRaw('vals.ctl')));
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'vals.ctl');
  try
    r:=cfg.Root;
    sa:=r.Strs('list');
    Check((length(sa)=2) and (sa[1]='y'),'array reloaded');
    Check((r.Float('f1')=F03) and (r.Float('f2')=F1E7) and (r.Float('f3')=F13),'floats reload exactly');
    Check(r.Node('f4').Kind=ckScalar,'integral float');
    Check(r.Str('s')='line1'#10'line2 "q" back\slash','string with escapes reloads');
    Check(r.Bool('b'),'bool');
    Check(r.Int('new.sub.k')=1,'new sections');
    // an array item
    r.Delete('list[0]');
    Check((r.Node('list').Count=1) and (r.Str('list[0]')='y'),'array item deleted');
    // a deleted key can be created again
    r.Delete('a');
    Check(not r.Node('a').Exists,'deleted');
    r.SetInt('a',5);
    Check(r.Int('a')=5,'created again');
    cfg.Save;
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'vals.ctl');
  try
    Check((cfg.Root.Int('a')=5) and (cfg.Root.Node('list').Count=1),'array item and recreated key saved');
  finally
    cfg.Free;
  end;
  EndTest;
end;

// Several values on one line, a key that needs quotes, a section with mixed definitions
procedure TestSaveDetails;
const
  ORIG='p { a = 1, b = 22, c = 333 }'#10;
  EXP='p { a = 1000, b = 2, c = 30 }'#10'"my key" = 5'#10;
  MIXED='p { a = 1 }'#10+
    'm { x = 1 }'#10+
    'm {'#10+
    '  # kept'#10+
    '  y = 2'#10+
    '}'#10;
  EXP_MIXED='p { a = 1 }'#10+
    'm {'#10+
    '  x = 10'#10+
    '}'#10+
    'm {'#10+
    '  # kept'#10+
    '  y = 2'#10+
    '}'#10;
var
  cfg:TConfig;
  r:TCfgNode;
begin
  StartTest('Saving details');
  Put('line.ctl',ORIG);
  cfg:=TConfig.Create(DIR+'line.ctl');
  try
    r:=cfg.Root;
    r.SetInt('p.a',1000);
    r.SetInt('p.b',2);
    r.SetInt('p.c',30);
    r.Child('my key').SetInt('',5);
    cfg.Save;
    Check(Get('line.ctl')=EXP,'patched right to left, a key with a blank quoted:'#10+string(Get('line.ctl')));
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'line.ctl');
  try
    Check(cfg.Root.Child('my key').AsInt=5,'quoted key reads back');
  finally
    cfg.Free;
  end;
  Put('mixed.ctl',MIXED);
  cfg:=TConfig.Create(DIR+'mixed.ctl');
  try
    r:=cfg.Root;
    Check((r.Int('m.x')=1) and (r.Int('m.y')=2),'inline and block definitions merge');
    r.SetInt('m.x',10);
    cfg.Save;
    Check(Get('mixed.ctl')=EXP_MIXED,'mixed definitions saved as a whole:'#10+string(Get('mixed.ctl')));
  finally
    cfg.Free;
  end;
  cfg:=TConfig.Create(DIR+'mixed.ctl');
  try
    Check((cfg.Root.Int('m.x')=10) and (cfg.Root.Int('m.y')=2) and (cfg.Root.Int('p.a')=1),'mixed file reads back');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestSaveCTL2;
const
  ORIG='# Header comment'#10+
    '$Section Options'#10+
    '  ; comment inside'#10+
    '  FullScreen    OFF'#10+
    '  Width         800'#10+
    '  Name          "C:\new"'#10+
    '  List          ("a", "b",'#10+
    '                 "c")'#10+
    '$EndOfSection'#10+
    'InstanceID      42'#10;
  EXP='# Header comment'#10+
    'Options {'#10+
    '  # comment inside'#10+
    '  FullScreen = OFF'#10+
    '  Width = 1024'#10+
    '  Name = C:\new'#10+
    '  List = [a, b, c]'#10+
    '}'#10+
    'InstanceID = 42'#10;
var
  cfg:TConfig;
begin
  StartTest('Saving a CTL2 file');
  Put('conv.ctl',ORIG);
  cfg:=TConfig.Create(DIR+'conv.ctl');
  try
    cfg.Root.SetInt('Options.Width',1024);
    cfg.Save;
  finally
    cfg.Free;
  end;
  Check(Get('conv.ctl')=EXP,'converted to CTL3:'#10+string(Get('conv.ctl')));
  cfg:=TConfig.Create(DIR+'conv.ctl');
  try
    Check((cfg.Root.Int('options.width')=1024) and (cfg.Root.Str('options.name')='C:\new') and
      (length(cfg.Root.Strs('options.list'))=3),'values after the conversion');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestSaveJson;
const
  ORIG='{'#10+
    '  "name": "test",'#10+
    '  "size": 12.5,'#10+
    '  "flags": [true, false],'#10+
    '  "nested": {"a": 1}'#10+
    '}'#10;
  EXP='{'#10+
    '  "name": "new \"x\"",'#10+
    '  "size": 12.5,'#10+
    '  "flags": [true, false],'#10+
    '  "nested": {'#10+
    '    "a": 1,'#10+
    '    "b": 2,'#10+
    '    "on": true'#10+
    '  }'#10+
    '}'#10;
var
  cfg:TConfig;
begin
  StartTest('Saving JSON');
  Put('save.json',ORIG);
  cfg:=TConfig.Create(DIR+'save.json');
  try
    cfg.Root.SetStr('name','new "x"');
    cfg.Root.SetInt('nested.b',2);
    cfg.Root.SetBool('nested.on',true);
    cfg.Save;
  finally
    cfg.Free;
  end;
  Check(Get('save.json')=EXP,'JSON written:'#10+string(Get('save.json')));
  cfg:=TConfig.Create(DIR+'save.json');
  try
    Check((cfg.Root.Str('name')='new "x"') and (cfg.Root.Int('nested.b')=2) and cfg.Root.Bool('nested.on'),'JSON reloaded');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestSaveIncludes;
const
  MAIN='sec {'#10'  x = 1'#10'  @include "sinc.ctl"'#10'}'#10'@include "sroot.ctl"'#10;
  EXPMAIN='sec {'#10'  x = 1'#10'  @include "sinc.ctl"'#10'  w = 5'#10'}'#10'@include "sroot.ctl"'#10;
var
  cfg:TConfig;
begin
  StartTest('Saving included files');
  Put('smain.ctl',MAIN);
  Put('sinc.ctl','y = 2'#10);
  Put('sroot.ctl','sec {'#10'  z = 3'#10'}'#10'b = 2'#10);
  cfg:=TConfig.Create(DIR+'smain.ctl');
  try
    cfg.Root.SetInt('sec.y',20);
    cfg.Save;
    Check(Get('sinc.ctl')='y = 20'#10,'value written to its own file');
    Check(Get('smain.ctl')=MAIN,'the main file is not touched');
    cfg.Root.SetInt('sec.w',5);
    cfg.Root.SetInt('b',7);
    cfg.Save;
    Check(Get('smain.ctl')=EXPMAIN,'new key goes to the first definition:'#10+string(Get('smain.ctl')));
    Check(Get('sroot.ctl')='sec {'#10'  z = 3'#10'}'#10'b = 7'#10,'root include updated');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestOptional;
var
  cfg:TConfig;
  failed:boolean;
begin
  StartTest('Optional file');
  failed:=false;
  try TConfig.Create(DIR+'opt.ctl').Free; except on e:EConfigError do failed:=true; end;
  Check(failed,'a missing file raises');
  cfg:=TConfig.Create(DIR+'opt.ctl',true);
  try
    Check(cfg.Root.Count=0,'empty document');
    cfg.Root.SetInt('a',1);
    cfg.Root.SetStr('s.t','x');
    cfg.Save;
  finally
    cfg.Free;
  end;
  Check(Get('opt.ctl')='a = 1'#10's {'#10'  t = "x"'#10'}'#10,'created:'#10+string(Get('opt.ctl')));
  cfg:=TConfig.Create(DIR+'opt.ctl',true);
  try
    Check(cfg.Root.Str('s.t')='x','created file reads back');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestProtected;
var
  cfg:TConfig;
  first:String8;
begin
  StartTest('Protected document');
  cfg:=TConfig.Create(DIR+'secret.dat',true,TTestProtector.Create);
  try
    cfg.Root.SetStr('token','abc123');
    cfg.Save;
    first:=GetRaw('secret.dat');
    cfg.Root.SetStr('token','abc123');
    cfg.Save;
  finally
    cfg.Free;
  end;
  Check(Pos('abc123',GetRaw('secret.dat'))=0,'file is protected');
  Check(first<>GetRaw('secret.dat'),'file changes on every save');
  cfg:=TConfig.Create(DIR+'secret.dat',false,TTestProtector.Create);
  try
    Check(cfg.Root.Str('token')='abc123','protected document reads back');
  finally
    cfg.Free;
  end;
  EndTest;
end;

procedure TestReload;
var
  cfg:TConfig;
  h:TCfgNode;
  failed:boolean;
begin
  StartTest('Reloading');
  SetEventHandler('Config\Reloaded',OnReloaded);
  Put('rel.ctl','a = 1'#10);
  cfg:=TConfig.Create(DIR+'rel.ctl');
  try
    h:=cfg.Node('a');
    Check(not cfg.Changed,'not changed');
    Check(not cfg.ReloadIfChanged,'nothing to reload');
    Put('rel.ctl','a = 22'#10);
    Check(cfg.Changed,'changed');
    reloadSignals:=0;
    Check(cfg.ReloadIfChanged,'reloaded');
    Check(h.AsInt=22,'a handle sees the new content');
    Check(reloadSignals=1,'signal sent');
    Check(not cfg.Changed,'not changed after the reload');
    Put('rel.ctl','a = "broken'#10);
    Check(not cfg.ReloadIfChanged,'a broken file is not reloaded');
    Check(h.AsInt=22,'previous content kept');
    Check(not cfg.ReloadIfChanged,'the same broken file is not tried again');
    failed:=false;
    try cfg.Reload; except on e:EConfigError do failed:=true; end;
    Check(failed and (h.AsInt=22),'Reload raises on a broken file');
    Put('rel.ctl','a = 333'#10);
    Check(cfg.ReloadIfChanged and (h.AsInt=333),'fixed file reloaded');
    cfg.Root.SetInt('b',1);
    Put('rel.ctl','a = 4444'#10);
    Check(not cfg.ReloadIfChanged and (h.AsInt=333) and (cfg.Root.Int('b')=1),'unsaved changes are not lost');
    cfg.Save;
    Check(not cfg.Changed,'own save is not an external change');
  finally
    cfg.Free;
  end;
  EndTest;
end;

begin
  try
    writeln('Testing Apus.Config');
    writeln;
    Cleanup;
    Folder.Create(TMPDIR);

    TestSyntax;
    TestJson;
    TestTyping;
    TestNavigation;
    TestCTL2;
    TestIncludes;
    TestErrors;
    TestSavePreserves;
    TestSaveValues;
    TestSaveDetails;
    TestSaveCTL2;
    TestSaveJson;
    TestSaveIncludes;
    TestOptional;
    TestProtected;
    TestReload;

    Cleanup;
    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
