// Experimental static AEM 0.0 and 0.1 decoder. The wire layout is described in aem_format.md.
// Copyright (C) 2026 Apus Software. Distributed under the BSD-3 license.
unit Apus.Engine.AEMLoader;
interface
uses Apus.Core, Apus.Geom3D, Apus.Engine.Mesh;

type
  {$SCOPEDENUMS ON}
  // How the stock shader treats coverage: base color alpha x color map alpha x vertex alpha.
  TModelAlphaMode=(
    Opaque, // coverage is ignored
    Cutout, // fragments with coverage below alphaCutoff are discarded
    Blend); // the part is blended by coverage
  {$SCOPEDENUMS OFF}

  // Material colors and parameters as authored. Colors are scene-linear, not sRGB-encoded.
  TModelMaterial=record
    baseColor:TVec4; // linear RGB and alpha
    emissionColor:TVec3; // linear RGB
    emissionStrength:single;
    specular:single; // specular level, 0.5 for common dielectrics
    roughness:single;
    metallic:single;
    alphaCutoff:single; // stored for every alpha mode
    alphaMode:TModelAlphaMode;
    vertexColor:boolean; // mesh colors tint this part
    doubleSided:boolean; // hint: the part is meant to be seen from both sides
    function Emission:TVec3; // emissionColor*emissionStrength
  end;

  TAemTextureHint=record
    role,path:String8;
  end;

  TAemBinding=record
    slotIndex:integer;
    hints:array of TAemTextureHint;
    material:TModelMaterial; // defaults for AEM 0.0
  end;

  TAemMesh=record
    geometry:TMesh;
    bindings:IntArray; // one binding index per TMesh section
  end;

  TAemNode=record
    name:String8;
    meshIndex:integer; // -1 for a transform-only node
    meshToAsset:TMat4d;
  end;

  TAemLOD=record
    minScreenHeight:single;
    nodes:IntArray;
  end;

  // Intermediate CPU data owned by the caller of LoadStaticAEM.
  TAemStaticData=class
    slots:Strings8;
    bindings:array of TAemBinding;
    meshes:array of TAemMesh;
    nodes:array of TAemNode;
    levels:array of TAemLOD;
    bounds:TBox3;
    destructor Destroy; override;
  end;

  function LoadStaticAEM(const fileName:String8):TAemStaticData;

implementation
uses SysUtils, Apus.Types, Apus.Files, Apus.Strings, Apus.Geom2D;

const
  HEADER_SIZE=20;
  DIRECTORY_ENTRY_SIZE=16;
  AEM_MAGIC=$004D4541;
  AEM_MESH=$4853454D;
  AEM_MTRL=$4C52544D;
  AEM_NODE=$45444F4E;
  AEM_BBOX=$584F4242;
  AEM_LOD0=$30444F4C;
  HAS_LOD=$0008;
  REQUIRED_CHUNK=$00000001;
  MATERIAL_PARAMS_SIZE=52;
  MATERIAL_VERTEX_COLOR=1;
  MATERIAL_DOUBLE_SIDED=2;
  MAX_POSITION:single=1e30; // TBox3 uses this magnitude for empty bounds
  MAX_SINGLE=3.4028234663852886e38; // largest finite single (Math.MaxSingle)

type
  TChunk=record
    id,offset,size,flags:cardinal;
  end;
  PChunk=^TChunk;

  TChunkReader=record
    buffer:TBuffer;
    fileOffset:integer;
    section:string;
    procedure Invalid(const reason:string; fieldSize:integer=0);
    procedure Finish;
    function U16:word;
    function U32:cardinal;
    function F32:single;
    function V3:TVec3;
    function Count(minBytes:integer):integer;
    function Text:String8;
  end;

procedure TChunkReader.Invalid(const reason:string; fieldSize:integer);
begin
  raise EError.Create('%s: %s at byte %d',[section,reason,fileOffset+buffer.CurrentPos-fieldSize]);
end;

procedure TChunkReader.Finish;
begin
  if buffer.BytesLeft<>0 then Invalid('trailing bytes in chunk');
end;

function TChunkReader.U16:word;
begin
  // Chunk fields are packed. Copy them without a typed pointer dereference.
  buffer.Read(result,SizeOf(result));
end;

function TChunkReader.U32:cardinal;
begin
  buffer.Read(result,SizeOf(result));
end;

function TChunkReader.F32:single;
var bits:cardinal;
begin
  bits:=U32;
  if bits and $7F800000=$7F800000 then Invalid('non-finite float');
  Move(bits,result,SizeOf(result));
end;

function TChunkReader.V3:TVec3;
begin
  result.x:=F32;
  result.y:=F32;
  result.z:=F32;
end;

function TChunkReader.Count(minBytes:integer):integer;
var n:cardinal;
begin
  n:=U32;
  buffer.Need(int64(n)*minBytes);
  result:=integer(n);
end;

function TChunkReader.Text:String8;
var len,i:integer;
begin
  len:=Count(1);
  SetLength(result,len);
  if len=0 then exit;
  buffer.Read(result[1],len);
  if UTF8.HasBOM(result) or not UTF8.IsValid(result) then Invalid('invalid UTF-8 string',len);
  for i:=1 to len do
    if result[i]=#0 then Invalid('NUL in string',len);
end;

function RelativeTexturePath(const path:String8):boolean;
var i,start:integer;
    segment:String8;
begin
  start:=1;
  for i:=1 to length(path) do
    case path[i] of
      ':','\':exit(false);
      '/':begin
        segment:=copy(path,start,i-start);
        if (segment='') or (segment='.') or (segment='..') then exit(false);
        start:=i+1;
      end;
    end;
  segment:=copy(path,start,maxInt);
  result:=(segment<>'') and (segment<>'.') and (segment<>'..');
end;

function TModelMaterial.Emission:TVec3;
begin
  result:=emissionColor*emissionStrength;
end;

// Values a version 0.0 binding implies, as listed in aem_format.md.
function DefaultMaterial:TModelMaterial;
begin
  result.baseColor:=Vec4(1,1,1,1);
  result.emissionColor:=Vec3(0,0,0);
  result.emissionStrength:=0;
  result.specular:=0.5;
  result.roughness:=0.5;
  result.metallic:=0;
  result.alphaCutoff:=0.5;
  result.alphaMode:=TModelAlphaMode.Opaque;
  result.vertexColor:=true;
  result.doubleSided:=false;
end;

procedure ReadMaterialParams(var r:TChunkReader; bindingIndex:integer; out m:TModelMaterial);

  procedure Fail(const field,reason:string; fieldSize:integer);
  begin
    r.Invalid(Format('%s %s in binding %d',[field,reason,bindingIndex]),fieldSize);
  end;

  function NonNegative(const field:string):single;
  var bits:cardinal;
  begin
    bits:=r.U32;
    if bits and $7F800000=$7F800000 then Fail(field,'is not finite',4);
    Move(bits,result,SizeOf(result));
    if result<0 then Fail(field,'is negative',4);
  end;

  function Fraction(const field:string):single;
  begin
    result:=NonNegative(field);
    if result>1 then Fail(field,'is above 1',4);
  end;

var
  mode,flags:integer;
begin
  m.baseColor.x:=Fraction('baseColor.r');
  m.baseColor.y:=Fraction('baseColor.g');
  m.baseColor.z:=Fraction('baseColor.b');
  m.baseColor.w:=Fraction('baseColor.a');
  m.emissionColor.x:=NonNegative('emissionColor.r');
  m.emissionColor.y:=NonNegative('emissionColor.g');
  m.emissionColor.z:=NonNegative('emissionColor.b');
  m.emissionStrength:=NonNegative('emissionStrength');
  m.specular:=NonNegative('specular');
  m.roughness:=Fraction('roughness');
  m.metallic:=Fraction('metallic');
  m.alphaCutoff:=Fraction('alphaCutoff');
  mode:=r.buffer.ReadByte;
  if mode>ord(High(TModelAlphaMode)) then Fail('alphaMode','is unknown',1);
  m.alphaMode:=TModelAlphaMode(mode);
  flags:=r.buffer.ReadByte;
  if flags and not (MATERIAL_VERTEX_COLOR or MATERIAL_DOUBLE_SIDED)<>0 then Fail('flags','has unknown bits',1);
  m.vertexColor:=flags and MATERIAL_VERTEX_COLOR<>0;
  m.doubleSided:=flags and MATERIAL_DOUBLE_SIDED<>0;
  if r.U16<>0 then Fail('reserved','must be zero',2);
end;

procedure ReadMaterials(var r:TChunkReader; model:TAemStaticData; minorVersion:integer);
var i,j,k,slotIndex,paramsSize:integer;
begin
  SetLength(model.slots,r.Count(4));
  for i:=0 to high(model.slots) do begin
    model.slots[i]:=r.Text;
    if model.slots[i]='' then r.Invalid('empty material slot');
    for j:=0 to i-1 do
      if model.slots[j]=model.slots[i] then r.Invalid('duplicate material slot');
  end;
  if minorVersion>=1 then paramsSize:=MATERIAL_PARAMS_SIZE else paramsSize:=0;
  SetLength(model.bindings,r.Count(8+paramsSize));
  for i:=0 to high(model.bindings) do begin
    slotIndex:=integer(r.U32);
    if (slotIndex<0) or (slotIndex>=length(model.slots)) then r.Invalid('invalid material slot index');
    model.bindings[i].slotIndex:=slotIndex;
    SetLength(model.bindings[i].hints,r.Count(8));
    for j:=0 to high(model.bindings[i].hints) do
      with model.bindings[i].hints[j] do begin
        role:=r.Text;
        path:=r.Text;
        if (role='') or not RelativeTexturePath(path) then r.Invalid('invalid texture hint');
        for k:=0 to j-1 do
          if model.bindings[i].hints[k].role=role then r.Invalid('duplicate texture role');
      end;
    if paramsSize>0 then ReadMaterialParams(r,i,model.bindings[i].material)
      else model.bindings[i].material:=DefaultMaterial;
  end;
  r.Finish;
end;

procedure ReadMesh(var r:TChunkReader; var dst:TAemMesh; model:TAemStaticData);
const
  MASK_NORMAL=1;
  MASK_UV0=2;
  MASK_UV1=4;
  MASK_TANGENT=8;
  MASK_COLOR=16;
var
  mesh:TMesh;
  attrs:TMeshAttributes;
  vertexCount,indexCount,partCount,mask,indexWidth,stride,customCount:integer;
  i,j,first,count,binding,covered,components:integer;
  index,color:cardinal;
  p:TVec3;
  names:Strings8;
begin
  mesh:=TMesh.Create;
  dst.geometry:=mesh;
  mesh.name:=r.Text;
  vertexCount:=r.Count(12);
  indexCount:=r.Count(2);
  partCount:=r.Count(12);
  mask:=r.U16;
  indexWidth:=r.buffer.ReadByte;
  if r.buffer.ReadByte<>0 then r.Invalid('reserved mesh byte must be zero');
  customCount:=r.Count(8);
  if (vertexCount=0) or (indexCount=0) or (partCount=0) or (indexCount mod 3<>0) then
    r.Invalid('expected indexed triangle mesh');
  if (mask and not 31<>0) or ((indexWidth<>2) and (indexWidth<>4)) then
    r.Invalid('unsupported vertex or index format');
  attrs:=[];
  stride:=12;
  if mask and MASK_NORMAL<>0 then begin Include(attrs,TMeshAttribute.Normal); inc(stride,12); end;
  if mask and MASK_UV0<>0 then begin Include(attrs,TMeshAttribute.UV0); inc(stride,8); end;
  if mask and MASK_UV1<>0 then begin Include(attrs,TMeshAttribute.UV1); inc(stride,8); end;
  if mask and MASK_TANGENT<>0 then begin
    if not ([TMeshAttribute.Normal,TMeshAttribute.UV0]<=attrs) then
      r.Invalid('tangents require normals and UV0');
    Include(attrs,TMeshAttribute.Tangent);
    inc(stride,16);
  end;
  if mask and MASK_COLOR<>0 then begin Include(attrs,TMeshAttribute.Color); inc(stride,4); end;
  r.buffer.Need(int64(vertexCount)*stride+int64(indexCount)*indexWidth+
    int64(partCount)*12+int64(customCount)*8);
  if indexCount>MaxInt div SizeOf(integer) then r.Invalid('expanded index buffer too large');

  mesh.SetVertexCount(vertexCount,attrs);
  for i:=0 to high(mesh.positions) do begin
    p:=r.V3;
    if (abs(p.x)>MAX_POSITION) or (abs(p.y)>MAX_POSITION) or (abs(p.z)>MAX_POSITION) then
      r.Invalid('vertex position out of range');
    mesh.positions[i]:=p;
  end;
  for i:=0 to high(mesh.normals) do mesh.normals[i]:=r.V3;
  for i:=0 to high(mesh.uv0) do begin mesh.uv0[i].x:=r.F32; mesh.uv0[i].y:=r.F32; end;
  for i:=0 to high(mesh.uv1) do begin mesh.uv1[i].x:=r.F32; mesh.uv1[i].y:=r.F32; end;
  for i:=0 to high(mesh.tangents) do
    with mesh.tangents[i] do begin
      x:=r.F32; y:=r.F32; z:=r.F32; w:=r.F32;
      if (w<>1) and (w<>-1) then r.Invalid('invalid tangent handedness');
    end;
  for i:=0 to high(mesh.colors) do begin
    color:=r.U32; // wire bytes R,G,B,A to engine ARGB
    mesh.colors[i]:=(color and $FF00FF00) or ((color and $FF) shl 16) or ((color shr 16) and $FF);
  end;
  SetLength(mesh.indices,indexCount);
  for i:=0 to high(mesh.indices) do begin
    if indexWidth=2 then index:=r.U16 else index:=r.U32;
    if index>=cardinal(vertexCount) then r.Invalid('vertex index out of range');
    mesh.indices[i]:=integer(index);
  end;

  covered:=0;
  SetLength(dst.bindings,partCount);
  SetLength(mesh.sections,partCount);
  for i:=0 to partCount-1 do begin
    first:=integer(r.U32);
    count:=integer(r.U32);
    binding:=integer(r.U32);
    if (first<>covered) or (count<=0) or (count mod 3<>0) or (count>indexCount-covered) then
      r.Invalid('invalid mesh part range');
    if (binding<0) or (binding>=length(model.bindings)) then r.Invalid('invalid material binding');
    dst.bindings[i]:=binding;
    mesh.sections[i].firstIndex:=first;
    mesh.sections[i].indexCount:=count;
    mesh.sections[i].name:=model.slots[model.bindings[binding].slotIndex];
    inc(covered,count);
  end;
  if covered<>indexCount then r.Invalid('uncovered triangle indices');

  SetLength(names,customCount);
  for i:=0 to customCount-1 do begin
    names[i]:=r.Text;
    components:=integer(r.U32);
    if (names[i]='') or (components<1) or (components>4) then r.Invalid('invalid custom stream');
    for j:=0 to i-1 do
      if names[j]=names[i] then r.Invalid('duplicate custom stream');
    r.buffer.Need(int64(vertexCount)*components*4);
    for j:=1 to vertexCount*components do r.F32;
  end;
  mesh.Finish;
end;

procedure ReadMeshes(var r:TChunkReader; model:TAemStaticData);
var i:integer;
begin
  SetLength(model.meshes,r.Count(24));
  if length(model.meshes)=0 then r.Invalid('expected a mesh');
  for i:=0 to high(model.meshes) do ReadMesh(r,model.meshes[i],model);
  r.Finish;
end;

procedure ReadNodes(var r:TChunkReader; model:TAemStaticData);
var
  i,j,k,parent,visibleNodes:integer;
  m:TMat4d;
  det:double;
begin
  SetLength(model.nodes,r.Count(60));
  visibleNodes:=0;
  for i:=0 to high(model.nodes) do
    with model.nodes[i] do begin
      name:=r.Text;
      parent:=integer(r.U32);
      meshIndex:=integer(r.U32);
      if (parent<-1) or (parent>=i) then r.Invalid('invalid node parent');
      if (meshIndex<-1) or (meshIndex>=length(model.meshes)) then r.Invalid('invalid node mesh');
      if meshIndex>=0 then inc(visibleNodes);
      m:=identMat4d;
      for j:=0 to 3 do
        for k:=0 to 2 do m.v[j,k]:=r.F32;
      if m.ToMat3.Determinant<=0 then r.Invalid('invalid node orientation or scale');
      if parent>=0 then m:=m*model.nodes[parent].meshToAsset;
      for j:=0 to 3 do
        for k:=0 to 2 do
          if not (abs(m.v[j,k])<=MAX_SINGLE) then r.Invalid('invalid composed node transform');
      det:=m.ToMat3.Determinant;
      if not (det>0) then r.Invalid('invalid composed node orientation or scale');
      meshToAsset:=m;
    end;
  if visibleNodes=0 then r.Invalid('expected a mesh node');
  r.Finish;
end;

procedure ReadLevels(var r:TChunkReader; model:TAemStaticData);
var
  seen:IntArray;
  level,i,node:integer;
  previous:single;
begin
  SetLength(model.levels,r.Count(8));
  if length(model.levels)<2 then r.Invalid('expected multiple LOD levels');
  SetLength(seen,length(model.nodes));
  previous:=2;
  for level:=0 to high(model.levels) do
    with model.levels[level] do begin
      minScreenHeight:=r.F32;
      if (minScreenHeight<0) or (minScreenHeight>1) or (minScreenHeight>=previous) then
        r.Invalid('invalid LOD threshold');
      previous:=minScreenHeight;
      SetLength(nodes,r.Count(4));
      if length(nodes)=0 then r.Invalid('empty LOD level');
      for i:=0 to high(nodes) do begin
        node:=integer(r.U32);
        if (node<0) or (node>=length(model.nodes)) then r.Invalid('invalid LOD node index');
        if (model.nodes[node].meshIndex<0) or (seen[node]=level+1) then
          r.Invalid('invalid or duplicate LOD mesh node');
        seen[node]:=level+1;
        nodes[i]:=node;
      end;
    end;
  if previous<>0 then r.Invalid('last LOD threshold must be zero');
  for node:=0 to high(seen) do
    if (seen[node]=0) and (model.nodes[node].meshIndex>=0) then r.Invalid('mesh node outside LOD levels');
  r.Finish;
end;

procedure ImplicitLevel(model:TAemStaticData);
var node,count:integer;
begin
  SetLength(model.levels,1);
  SetLength(model.levels[0].nodes,length(model.nodes));
  count:=0;
  for node:=0 to high(model.nodes) do
    if model.nodes[node].meshIndex>=0 then begin
      model.levels[0].nodes[count]:=node;
      inc(count);
    end;
  SetLength(model.levels[0].nodes,count);
end;

procedure ReadAndCheckBounds(var r:TChunkReader; const actual:TBox3);
var
  claimed:TBox3;
  function Fails(claimedMin,claimedMax,realMin,realMax:double):boolean;
  var tolerance:double;
  begin
    tolerance:=1e-5*Max(1,Max(Max(abs(realMin),abs(realMax)),realMax-realMin));
    result:=(claimedMin>claimedMax) or (claimedMin-realMin>tolerance) or (realMax-claimedMax>tolerance);
  end;
begin
  claimed.min:=r.V3;
  claimed.max:=r.V3;
  if Fails(claimed.min.x,claimed.max.x,actual.min.x,actual.max.x) or
     Fails(claimed.min.y,claimed.max.y,actual.min.y,actual.max.y) or
     Fails(claimed.min.z,claimed.max.z,actual.min.z,actual.max.z) then
    r.Invalid('bounds do not enclose geometry');
end;

procedure ReadBounds(var r:TChunkReader; model:TAemStaticData);
var
  i,corner:integer;
  meshBounds:TBox3;
  p:TVec3d;
begin
  model.bounds.Reset;
  for i:=0 to high(model.nodes) do
    with model.nodes[i] do begin
      if meshIndex<0 then continue;
      meshBounds:=model.meshes[meshIndex].geometry.bounds;
      for corner:=0 to 7 do begin
        p:=Vec3d(meshBounds.min.x,meshBounds.min.y,meshBounds.min.z);
        if corner and 1<>0 then p.x:=meshBounds.max.x;
        if corner and 2<>0 then p.y:=meshBounds.max.y;
        if corner and 4<>0 then p.z:=meshBounds.max.z;
        p:=meshToAsset.TransformPoint(p);
        if not ((abs(p.x)<=MAX_POSITION) and (abs(p.y)<=MAX_POSITION) and (abs(p.z)<=MAX_POSITION)) then
          r.Invalid('transformed mesh bounds out of range');
        model.bounds.Include(Vec3(p.x,p.y,p.z));
      end;
    end;
  ReadAndCheckBounds(r,model.bounds);
  for i:=0 to high(model.meshes) do ReadAndCheckBounds(r,model.meshes[i].geometry.bounds);
  r.Finish;
end;

function KnownChunk(id:cardinal):boolean;
begin
  result:=(id=AEM_MESH) or (id=AEM_MTRL) or (id=AEM_NODE) or (id=AEM_BBOX) or (id=AEM_LOD0);
end;

procedure Decode(const data:ByteArray; model:TAemStaticData);
var
  directory:array of TChunk;
  fileBuffer:TBuffer;
  r:TChunkReader;
  features,minorVersion:word;
  dirOffset,dirCount:cardinal;
  dirEnd,entryEnd,prevEnd:uint64;
  i,j:integer;
  c:PChunk;
  ch:byte;

  function FindChunk(id:cardinal):integer;
  var entry:integer;
  begin
    for entry:=0 to high(directory) do
      if directory[entry].id=id then exit(entry);
    result:=-1;
  end;

  procedure EnterChunk(id:cardinal;const name:string);
  var entry:integer;
  begin
    r.section:=name;
    entry:=FindChunk(id);
    if entry<0 then r.Invalid('missing mandatory chunk');
    r.fileOffset:=integer(directory[entry].offset);
    r.buffer:=fileBuffer.Slice(r.fileOffset,integer(directory[entry].size));
  end;

begin
  fileBuffer:=TBuffer.CreateFrom(data);
  r.buffer:=fileBuffer;
  r.fileOffset:=0;
  r.section:='header';
  try
    if r.U32<>AEM_MAGIC then r.Invalid('unexpected AEM signature');
    if r.U16<>0 then r.Invalid('unsupported major version (expected AEM 0.x)');
    minorVersion:=r.U16;
    if minorVersion>1 then r.Invalid('unsupported minor version (expected AEM 0.0 or 0.1)');
    features:=r.U16;
    if features and not HAS_LOD<>0 then r.Invalid('unsupported AEM feature flags');
    if r.U16<>0 then r.Invalid('reserved file flags must be zero');
    dirOffset:=r.U32;
    dirCount:=r.U32;
    dirEnd:=uint64(dirOffset)+uint64(dirCount)*DIRECTORY_ENTRY_SIZE;
    if (dirOffset<HEADER_SIZE) or (dirEnd>uint64(fileBuffer.size)) or (dirCount<4) then
      r.Invalid('invalid chunk directory range');

    r.section:='directory';
    r.fileOffset:=integer(dirOffset);
    r.buffer:=fileBuffer.Slice(r.fileOffset,integer(dirEnd-dirOffset));
    SetLength(directory,dirCount);
    for i:=0 to high(directory) do begin
      c:=@directory[i];
      c^.id:=r.U32;
      for j:=0 to 3 do begin
        ch:=byte(c^.id shr (j*8) and $FF);
        if not (((ch>=ord('A')) and (ch<=ord('Z'))) or ((ch>=ord('0')) and (ch<=ord('9')))) then
          r.Invalid('invalid chunk ID');
      end;
      c^.offset:=r.U32;
      c^.size:=r.U32;
      c^.flags:=r.U32;
      entryEnd:=uint64(c^.offset)+c^.size;
      if (c^.offset<HEADER_SIZE) or (c^.size=0) or (entryEnd>uint64(fileBuffer.size)) or
         ((uint64(c^.offset)<dirEnd) and (entryEnd>dirOffset)) then r.Invalid('invalid chunk range');
      if KnownChunk(c^.id) then begin
        if c^.flags<>REQUIRED_CHUNK then r.Invalid('unsupported flags on static chunk');
      end else
        if c^.flags and REQUIRED_CHUNK<>0 then r.Invalid('unknown mandatory chunk');
    end;
    // Known and optional chunks are subject to the same directory checks.
    Sort.ByInt(directory[0],SizeOf(TChunk),length(directory),0);
    for i:=1 to high(directory) do
      if directory[i-1].id=directory[i].id then r.Invalid('duplicate chunk');
    Sort.ByInt(directory[0],SizeOf(TChunk),length(directory),SizeOf(cardinal));
    prevEnd:=HEADER_SIZE;
    for i:=0 to high(directory) do begin
      c:=@directory[i];
      if c^.offset<prevEnd then r.Invalid('overlapping chunks');
      prevEnd:=uint64(c^.offset)+c^.size;
    end;

    EnterChunk(AEM_MTRL,'MTRL');
    ReadMaterials(r,model,minorVersion);
    EnterChunk(AEM_MESH,'MESH');
    ReadMeshes(r,model);
    EnterChunk(AEM_NODE,'NODE');
    ReadNodes(r,model);
    EnterChunk(AEM_BBOX,'BBOX');
    ReadBounds(r,model);
    if (FindChunk(AEM_LOD0)>=0)<>(features and HAS_LOD<>0) then r.Invalid('inconsistent LOD flag or chunk');
    if features and HAS_LOD<>0 then begin
      EnterChunk(AEM_LOD0,'LOD0');
      ReadLevels(r,model);
    end else
      ImplicitLevel(model);
  except
    on EBufferOverrun do r.Invalid('truncated payload');
  end;
end;

function ReadFileBytes(const fileName:String8):ByteArray;
var
  f:TFileHandle;
  size:int64;
begin
  f:=Files.OpenRead(fileName);
  try
    size:=Files.FileSize(f);
    if (size<HEADER_SIZE) or (size>MaxInt) then raise EError.Create('unsupported AEM file size');
    result:=Files.ReadBytes(f,integer(size));
  finally
    f.Close;
  end;
end;

function LoadStaticAEM(const fileName:String8):TAemStaticData;
var model:TAemStaticData;
begin
  model:=TAemStaticData.Create;
  try
    try
      Decode(ReadFileBytes(fileName),model);
    except
      on e:Exception do raise EError.Create('AEM "%s": %s',[fileName,e.Message]);
    end;
    result:=model;
    model:=nil;
  finally
    model.Free;
  end;
end;

destructor TAemStaticData.Destroy;
var i:integer;
begin
  for i:=0 to high(meshes) do meshes[i].geometry.Free;
  inherited;
end;

end.
