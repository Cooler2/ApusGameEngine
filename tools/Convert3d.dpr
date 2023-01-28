{$APPTYPE CONSOLE}
program Convert3d;
uses Apus.Types, Apus.Common, SysUtils, Assimp, Apus.Structs, Apus.Geom2d, Apus.Geom3D, Apus.Engine.AEM;

type
 TPrecision=(prFull,
             prHalf,
             prMedium,
             prLower,
             prLow,
             prUltraLow);
var
 exeName:string;
 inputFile:string;
 scene:PAIScene;
 // Vertex attributes
 position:TPoints3s;
 normal:TVectors3s;
 uv:TPoints3s;
 // output
 stream:TWriteBuffer;
 startTime:int64;

procedure ReadParameters;
 var
  i:integer;
  st:string;
 begin
  for i:=1 to paramCount do begin
   st:=ParamStr(i);
   if st.StartsWith('-') then begin

   end else
    inputFile:=st;
  end;
 end;

procedure ImportMesh(id:integer);
 var
  mesh:PaiMesh;
  i,numVrt:integer;
  vec3d:PaiVector3D;
  positions:TPoints3s;
  normals:TVectors3s;
  UVs:TPoints3s;
 begin
  mesh:=scene.mMeshes^;
  inc(mesh,id);
  ASSERT(mesh.mPrimitiveTypes=aiPrimitiveType_TRIANGLE,'Mesh should contain triangles only');
  numVrt:=mesh.mNumVertices;
  // positions
  SetLength(positions,numVrt);
  vec3d:=mesh.mVertices;
  for i:=0 to numVrt-1 do begin
   positions[i].Init(vec3d.x,vec3d.y,vec3d.z);
   inc(vec3d);
  end;
  position:=position+positions;
  // Normals
  vec3d:=mesh.mNormals;
  if vec3d<>nil then begin
   SetLength(normals,numVrt);
   for i:=0 to numVrt-1 do begin
    normals[i].Init(vec3d.x,vec3d.y,vec3d.z);
    inc(vec3d);
   end;
   normal:=normal+normals;
  end;
  // UV
  vec3d:=mesh.mTextureCoords[0];
  if vec3d<>nil then begin
   SetLength(UVs,numVrt);
   for i:=0 to numVrt-1 do begin
    UVs[i].Init(vec3d.x,vec3d.y,vec3d.z);
    inc(vec3d);
   end;
   uv:=uv+UVs;
  end;
 end;

procedure ImportModel;
 var
  error:PAnsiChar;
  i:integer;
  fName:PAnsiChar;
 begin
  writeln('Loading ',inputFile);
  fName:=PAnsiChar(String8(inputFile));
  scene:=aiImportFile(fName,0);
  if scene=nil then raise EError.Create(aiGetErrorString);
  for i:=0 to scene.mNumMeshes-1 do
   ImportMesh(i);
  aiReleaseImport(scene);
 end;

procedure WriteChunk(chunkType,dataType:integer;chunkData:TWriteBuffer);
 var
  b:byte;
  buf:TBuffer;
 begin
  b:=(chunkType shl 3)+dataType and 7;
  stream.WriteByte(b);
  buf:=chunkData.AsBuffer;
  stream.WriteFlex(buf.size);
  stream.Write(buf);
 end;

function PackPoints(points:TPoints3s;precision:TPrecision;out is2D:boolean):TWriteBuffer;
 var
  i:integer;
  range:TBBox3s;
  xx,yy,zz:single;
  halfRange:array[0..5] of half;
 begin
  result.Init(65536);
  if length(points)=0 then exit;
  range.Init;
  range.Add(@points[0],length(points));
  is2D:=range.maxZ-range.minZ=0;
  // Convert range to half precision
  halfRange[0]:=range.minX;
  halfRange[1]:=range.maxX;
  halfRange[2]:=range.minY;
  halfRange[3]:=range.maxY;
  halfRange[4]:=range.minZ;
  halfRange[5]:=range.maxZ;
  if is2D then
   result.Write(halfRange,sizeof(halfRange))
  else
   result.Write(halfRange,8);
  // Precalc range coefficients
  range.minX:=halfRange[0];
  range.minY:=halfRange[0];
  range.minZ:=halfRange[0];
  xx:=single(halfRange[1])-range.minX;
  if xx>0 then xx:=65535/xx else xx:=0;
  yy:=single(halfRange[3])-range.minY;
  if yy>0 then yy:=65535/yy else yy:=0;
  zz:=single(halfRange[5])-range.minZ;
  if zz>0 then zz:=65535/zz else zz:=0;
  // Convert
  for i:=0 to high(points) do begin
   result.WriteWord(round(xx*(points[i].x-range.minX)));
   result.WriteWord(round(yy*(points[i].y-range.minY)));
   if is2D then continue;
   result.WriteWord(round(zz*(points[i].z-range.minZ)));
  end;
 end;

function PackNormalToWord(vec:TVector3s):word;
 var
  ax,ay,az:single;
  axis:integer;
 begin
  // determine largest axis
  ax:=abs(vec.x);
  ay:=abs(vec.y);
  az:=abs(vec.z);
  if (ax>=ay) and (ax>=az) then axis:=0
   else
    if (ay>=ax) and (ay>=az) then axis:=1
     else axis:=2;
  ax:=vec.v[(axis+1) mod 3];
  ay:=vec.v[(axis+2) mod 3];
  if vec.v[axis]<0 then inc(axis,3);
  result:=(round(51*ax/0.707)+51)+(round(51*ax/0.707)+51)*103 + 103*103*axis;
 end;

function PackUnitVec3D(vec:TVectors3s;precision:TPrecision):TWriteBuffer;
 var
  i:integer;
  w:word;
 begin
  result.Init(65536);
  // Check if all vectors are unit
  for i:=0 to high(vec) do begin
   w:=PackNormalToWord(vec[i]);
   result.WriteWord(w);
  end;
 end;

procedure ExportVertices;
 var
  data:TWriteBuffer;
  is2D:boolean;
 begin
  // Positions
  data:=PackPoints(position,prMedium,is2D);
  if is2D then
   WriteChunk(0,3,data)
  else
   WriteChunk(1,3,data);
  // Normals
  if length(normal)>0 then begin
   data:=PackUnitVec3D(normal,prMedium);
   WriteChunk(2,7,data);
  end;
  // UV
  if length(uv)>0 then begin
   data:=PackPoints(uv,prMedium,is2D);
   ASSERT(is2D,'3D UV not supported');
   WriteChunk(4,3,data);
  end;
 end;

procedure ExportModel;
 var
  fName:string;
 begin
  writeln('Converting...');
  stream.Init(100000);
  stream.WriteUInt(AEM.MAGIC_VALUE);
  ExportVertices;
  fName:=ChangeFileExt(inputFile,'.aem');
  writeln('Saving to ',fName);
  SaveFile(fName,stream.AsBuffer);
  writeln('Done! Time=',MyTickCount-startTime);
 end;

begin
 try
  startTime:=MyTickCount;
  if paramCount=0 then begin
   exeName:=ExtractFileName(paramstr(0));
   writeln('Usage: ',exeName,' [options] SrcFileName');
   exit;
  end;
  ReadParameters;
  ImportModel;
  ExportModel;
 except
  on e:Exception do begin
   writeln('Error: '+e.Message);
   writeln('Press [Enter] to continue...');
   readln;
  end;
 end;
end.
