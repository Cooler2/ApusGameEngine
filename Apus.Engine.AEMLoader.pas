// Load 3D model from AEM (Apus Engine Mesh) files

// Copyright (C) 2022 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R+}
unit Apus.Engine.AEMLoader;
interface
uses Apus.Types, Apus.Engine.Model3D;

type
 AEM=record
  const
   MAGIC_VALUE = $004d4541;
   // Vertex attribute flags
   VERTEX_POSITION_2D = 1; // indicate that position is 2D instead of 3D
   VERTEX_NORMAL      = 2;
   VERTEX_TANGENT     = 4;
   VERTEX_UV          = 8;
   VERTEX_WEIGHT      = 16;
   VERTEX_COLOR       = 32;
   VERTEX_CUSTOM      = 64;
 end;
 AEM_MODEL_INFO=packed record
  numVertices:integer; // full size of vertex buffer
  vertexFields:cardinal; //
  numBones:byte;
  res:array[1..3] of byte;
 end;

 function Load3DModel(fname:string):TModel3D; overload;
 function Load3DModel(data:ByteArray):TModel3D; overload;
 function Load3DModel(data:TBuffer):TModel3D; overload;


implementation
uses Apus.Common, SysUtils, Apus.Geom3D, Apus.Geom2D;

const
 chunkDataTypes:array[0..11,0..7] of byte=(
  (1,2,3,4,5,0,18,0),    // 0 - Pos2D
  (1,2,3,4,5,6,18,0),    // 1 - Pos3D
  (1,2,7,8,18,0,0,0),    // 2 - Normal
  (1,2,7,8,18,0,0,0),    // 3 - Tangent
  (1,2,3,4,5,0,18,0),    // 4 - UV (2D)
  (13,14,18,0,0,0,0,0),  // 5 - Bone weight
  (9,10,11,12,18,0,0,0), // 6 - Color
  (1,2,3,18,0,0,0,0),    // 7 - Custom 1D
  (1,2,3,4,5,0,18,0),    // 8 - Custom 2D
  (1,2,3,5,5,6,18,0),    // 9 - Custom 3D
  (9,10,11,12,18,0,0,0), // 10 - Custom color
  (0,0,0,0,0,0,0,0));

type
 TLoadContext=record
  model:TModel3D;
 end;

 procedure LoadSpecialChunk(var m:TLoadContext;dataType:byte;chunk:TBuffer);
  var
   modelInfo:AEM_MODEL_INFO;
  begin
   case dataType of
    0:begin
       chunk.Read(modelInfo,sizeof(modelInfo));
{       SetLength(m.model.vp,modelInfo.numVertices);
       if HasFlag(modelInfo.vertexFields,AEM.VERTEX_NORMAL) then
        SetLength(}
    end;
    1:m.model.name:=chunk.ReadString;
   end;
  end;

 function LoadPoints(is3D:boolean;dataType:integer;buf:TBuffer):TPoints3s;
  begin

  end;

 procedure ReadChunk(var m:TLoadContext;chunkType:byte;chunk:TBuffer);
  var
   dataType:byte;
  begin
   dataType:=chunkType and 3;
   chunkType:=chunkType shr 3;
   if dataType<=high(chunkDataTypes) then begin
    dataType:=chunkDataTypes[chunkType,dataType];
    ASSERT(dataType>0,'Unallowed chunk data encoding');
   end;
   case chunkType of
    31:LoadSpecialChunk(m,dataType,chunk);
    0,1:m.model.vp:=m.model.vp+LoadPoints(chunkType=1,dataType,chunk);
   end;

  end;

 function Load3DModel(data:TBuffer):TModel3D; overload;
  var
   magic:cardinal;
   chunkType:byte;
   chunkSize:cardinal;
   m:TLoadContext;
  begin
   magic:=data.ReadUInt;
   if magic<>AEM.MAGIC_VALUE then raise EError.Create('Not a valid AEM data');
   m.model:=TModel3D.Create('');
   while data.BytesLeft>0 do begin
    // Read chunk
    chunkType:=data.ReadByte;
    chunkSize:=data.ReadFlex;
    ReadChunk(m,chunkType,data.Slice(chunkSize,true));
   end;
  end;

 function Load3DModel(fname:string):TModel3D;
  var
   name:string;
   data:ByteArray;
  begin
   try
    name:=FileName(fname);
    data:=LoadFileAsBytes(name);
    result:=Load3DModel(TBuffer.CreateFrom(data));
    result.name:=ChangeFileExt(ExtractFileName(name),'');
    result.src:=name;
   except
    on e:Exception do raise EError.Create('Error in 3DModel Load('+fname+'): '+ExceptionMsg(e));
   end;
  end;

 function Load3DModel(data:ByteArray):TModel3D;
  begin
   try
    result:=Load3DModel(TBuffer.CreateFrom(data));
   except
    on e:Exception do raise EError.Create('Error in 3D Model Load: '+ExceptionMsg(e));
   end;
  end;

end.
