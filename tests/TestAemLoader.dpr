// Headless test for AEM material parameters: version 0.0 defaults, the exported
// samples in demo/ModelMaterials (AEM 0.1) and rejection of invalid parameters.
{$APPTYPE CONSOLE}
program TestAemLoader;
uses
  SysUtils,
  Apus.Core,
  Apus.Files,
  Apus.Geom3D,
  Apus.Colors,
  Apus.Engine.Model;

{$I ..\Base\tests\Test.inc}

const
  SAMPLES='demo/ModelMaterials/res/models/';
  CUBE_V0='tests/fixtures/cube_static.aem';

var
  root,tempDir:String8;

// The repository root: the current folder in CI, or a parent of the executable.
function FindRoot:String8;
var
  candidates:array[0..1] of String8;
  i,level:integer;
  dir:String8;
begin
  candidates[0]:=String8(IncludeTrailingPathDelimiter(GetCurrentDir));
  candidates[1]:=String8(ExtractFilePath(ParamStr(0)));
  for i:=0 to high(candidates) do begin
    dir:=candidates[i];
    for level:=0 to 4 do begin
      if Files.Exists(dir+CUBE_V0) then exit(dir);
      dir:=dir+'../';
    end;
  end;
  result:='';
end;

function Near(a,b:single;tolerance:single=1e-5):boolean;
begin
  result:=abs(a-b)<=tolerance;
end;

function NearVec(const a:TVec4;x,y,z,w:single):boolean;
begin
  result:=Near(a.x,x) and Near(a.y,y) and Near(a.z,z) and Near(a.w,w);
end;

function LoadSample(const name:String8):TModelAsset;
begin
  result:=TModelAsset.LoadAEM(root+SAMPLES+name+'.aem');
end;

// Linear color of an 8-bit sRGB triple, as the sample generator picks colors.
function SRGB(r,g,b:byte):TVec4;
begin
  result:=Color.ToLinear($FF000000 or (r shl 16) or (g shl 8) or b);
end;

procedure TestVersion0Defaults;
var
  asset:TModelAsset;
  m:TModelMaterial;
begin
  StartTest('AEM 0.0 defaults');
  asset:=TModelAsset.LoadAEM(root+CUBE_V0);
  try
    Check(asset.MaterialBindingCount=1,'one binding');
    m:=asset.Material(0);
    Check(NearVec(m.baseColor,1,1,1,1),'white base color, alpha 1');
    Check(Near(m.emissionColor.x,0) and Near(m.emissionColor.y,0) and Near(m.emissionColor.z,0) and
      (m.emissionStrength=0),'no emission');
    Check((m.specular=0.5) and (m.roughness=0.5) and (m.metallic=0) and (m.alphaCutoff=0.5),'scalar defaults');
    Check(m.alphaMode=TModelAlphaMode.Opaque,'opaque');
    Check(m.vertexColor and not m.doubleSided,'vertex color flag set, single-sided');
  finally
    asset.Free;
  end;
  EndTest;
end;

procedure TestSamples;
var
  asset:TModelAsset;
  m:TModelMaterial;
  c:TVec4;
  e:TVec3;
begin
  StartTest('AEM 0.1 samples');
  asset:=LoadSample('GlossyGreen');
  try
    m:=asset.Material(0);
    c:=SRGB(140,230,120);
    Check(NearVec(m.baseColor,c.x,c.y,c.z,1),'GlossyGreen: linear base color');
    Check(Near(m.roughness,0.2) and (m.metallic=0) and Near(m.specular,0.5),'GlossyGreen: roughness 0.2');
    Check((m.alphaMode=TModelAlphaMode.Opaque) and not m.vertexColor and not m.doubleSided,'GlossyGreen: plain opaque');
    Check(asset.TextureHint(0,'color')='','GlossyGreen: no color map');
  finally
    asset.Free;
  end;

  asset:=LoadSample('Gold');
  try
    m:=asset.Material(0);
    Check((m.metallic=1) and Near(m.roughness,0.3),'Gold: metallic 1, roughness 0.3');
  finally
    asset.Free;
  end;

  asset:=LoadSample('RedCorner');
  try
    m:=asset.Material(0);
    Check(m.vertexColor and NearVec(m.baseColor,1,1,1,1),'RedCorner: white base tinted by vertex colors');
  finally
    asset.Free;
  end;

  asset:=LoadSample('TintedVertexColors');
  try
    m:=asset.Material(0);
    c:=SRGB(255,220,160);
    Check(m.vertexColor and NearVec(m.baseColor,c.x,c.y,c.z,1),'TintedVertexColors: tint and vertex colors');
  finally
    asset.Free;
  end;

  asset:=LoadSample('UnusedVertexColors');
  try
    m:=asset.Material(0);
    Check(not m.vertexColor,'UnusedVertexColors: colors do not tint the part');
  finally
    asset.Free;
  end;

  asset:=LoadSample('Checker');
  try
    m:=asset.Material(0);
    Check(asset.TextureHint(0,'color')='textures/checker.png','Checker: color map path');
    Check(NearVec(m.baseColor,1,1,1,1) and (m.alphaMode=TModelAlphaMode.Opaque),'Checker: white, opaque');
  finally
    asset.Free;
  end;

  asset:=LoadSample('Cutout');
  try
    m:=asset.Material(0);
    Check(asset.TextureHint(0,'color')='textures/grid.png','Cutout: color map path');
    Check((m.alphaMode=TModelAlphaMode.Cutout) and (m.alphaCutoff=0.5),'Cutout: cutout at 0.5');
    Check(m.doubleSided,'Cutout: double-sided hint');
  finally
    asset.Free;
  end;

  asset:=LoadSample('Emissive');
  try
    m:=asset.Material(0);
    c:=SRGB(255,150,40);
    e:=m.Emission;
    Check(Near(e.x,c.x) and Near(e.y,c.y) and Near(e.z,c.z),'Emissive: emission color x strength');
    c:=SRGB(40,40,40);
    Check(NearVec(m.baseColor,c.x,c.y,c.z,1),'Emissive: dark base color');
  finally
    asset.Free;
  end;

  asset:=LoadSample('NoMaterial');
  try
    m:=asset.Material(0);
    Check(NearVec(m.baseColor,0.8,0.8,0.8,1) and (asset.MaterialSlotName(0)='Default'),'NoMaterial: light grey default');
  finally
    asset.Free;
  end;
  EndTest;
end;

function GetU32(const data:ByteArray;offset:integer):cardinal;
begin
  Move(data[offset],result,4);
end;

procedure PutU32(var data:ByteArray;offset:integer;value:cardinal);
begin
  Move(value,data[offset],4);
end;

procedure PutF32(var data:ByteArray;offset:integer;value:single);
begin
  Move(value,data[offset],4);
end;

// File offset of the parameters of binding 0 in an AEM 0.1 file.
function FirstParamsOffset(const data:ByteArray):integer;
var
  dirOffset,dirCount,i,slots,hints,pos:integer;
  function SkipText(at:integer):integer;
  begin
    result:=at+4+integer(GetU32(data,at));
  end;
begin
  dirOffset:=integer(GetU32(data,12));
  dirCount:=integer(GetU32(data,16));
  pos:=-1;
  for i:=0 to dirCount-1 do
    if GetU32(data,dirOffset+i*16)=$4C52544D then pos:=integer(GetU32(data,dirOffset+i*16+4)); // MTRL
  Assert(pos>=0,'no MTRL chunk');
  slots:=integer(GetU32(data,pos));
  inc(pos,4);
  for i:=1 to slots do pos:=SkipText(pos);
  inc(pos,8); // binding count, slot index
  hints:=integer(GetU32(data,pos));
  inc(pos,4);
  for i:=1 to hints*2 do pos:=SkipText(pos);
  result:=pos;
end;

// Loads a modified copy and expects an error containing every fragment of expected.
procedure ExpectError(const data:ByteArray;const name:String8;const expected:array of String8);
var
  fileName,msg:String8;
  i:integer;
  ok:boolean;
begin
  fileName:=tempDir+'TestAemLoader_'+name+'.aem';
  Files.Save(fileName,data);
  msg:='';
  try
    TModelAsset.LoadAEM(fileName).Free;
  except
    on e:Exception do msg:=String8(e.Message);
  end;
  ok:=msg<>'';
  for i:=0 to high(expected) do
    ok:=ok and (Pos(expected[i],msg)>0);
  if not ok then writeln('  ',name,': "',msg,'"');
  Check(ok,string(name));
  Files.Delete(fileName);
end;

procedure TestInvalidParams;
var
  source,data:ByteArray;
  p:integer;
  nan:cardinal;
begin
  StartTest('Invalid material parameters');
  source:=Files.LoadAsBytes(root+SAMPLES+'GlossyGreen.aem');
  p:=FirstParamsOffset(source);
  data:=Copy(source);
  Check(Near(PSingle(@data[p+36])^,0.2),'parameters located');

  data:=Copy(source); PutF32(data,p,1.5);
  ExpectError(data,'base_above_1',['MTRL','baseColor.r is above 1 in binding 0',String8('at byte '+IntToStr(p))]);
  data:=Copy(source); PutF32(data,p+12,-0.25);
  ExpectError(data,'alpha_negative',['baseColor.a is negative in binding 0']);
  data:=Copy(source); PutF32(data,p+20,-1);
  ExpectError(data,'emission_negative',['emissionColor.g is negative']);
  data:=Copy(source); PutF32(data,p+32,-0.5);
  ExpectError(data,'specular_negative',['specular is negative']);
  nan:=$7FC00000;
  data:=Copy(source); PutU32(data,p+36,nan);
  ExpectError(data,'roughness_nan',['roughness is not finite',String8('at byte '+IntToStr(p+36))]);
  data:=Copy(source); PutF32(data,p+40,1.01);
  ExpectError(data,'metallic_above_1',['metallic is above 1']);
  data:=Copy(source); PutU32(data,p+44,$7F800000);
  ExpectError(data,'cutoff_infinite',['alphaCutoff is not finite']);
  data:=Copy(source); data[p+48]:=3;
  ExpectError(data,'alpha_mode_unknown',['alphaMode is unknown',String8('at byte '+IntToStr(p+48))]);
  data:=Copy(source); data[p+49]:=4;
  ExpectError(data,'flags_unknown',['flags has unknown bits']);
  data:=Copy(source); data[p+51]:=1;
  ExpectError(data,'reserved_nonzero',['reserved must be zero']);

  // emission strength above 1 and specular above 1 are valid
  data:=Copy(source); PutF32(data,p+28,5); PutF32(data,p+32,2);
  Files.Save(tempDir+'TestAemLoader_strong.aem',data);
  try
    with TModelAsset.LoadAEM(tempDir+'TestAemLoader_strong.aem') do
      try
        Check((Material(0).emissionStrength=5) and (Material(0).specular=2),'emission strength and specular above 1');
      finally
        Free;
      end;
  except
    on e:Exception do Check(false,'emission strength and specular above 1: '+e.Message);
  end;
  Files.Delete(tempDir+'TestAemLoader_strong.aem');
  EndTest;
end;

procedure TestVersions;
var
  data:ByteArray;
begin
  StartTest('Versions');
  data:=Files.LoadAsBytes(root+SAMPLES+'GlossyGreen.aem');
  Check((data[4]=0) and (data[6]=1),'exporter writes 0.1');
  data[6]:=2;
  ExpectError(data,'minor_2',['unsupported minor version']);
  data[6]:=0;
  ExpectError(data,'v01_as_v00',['MTRL']);
  data[6]:=1; data[4]:=1;
  ExpectError(data,'major_1',['unsupported major version']);

  data:=Files.LoadAsBytes(root+CUBE_V0);
  data[6]:=1;
  ExpectError(data,'v00_as_v01',['MTRL']);
  EndTest;
end;

begin
  writeln('=== TestAemLoader ===');
  root:=FindRoot;
  if root='' then begin
    writeln('Repository files not found: run from the repository root');
    ExitCode:=1;
    exit;
  end;
  tempDir:=String8(ExtractFilePath(ParamStr(0))); // modified copies are written next to the executable
  TestVersion0Defaults;
  TestSamples;
  TestInvalidParams;
  TestVersions;
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
