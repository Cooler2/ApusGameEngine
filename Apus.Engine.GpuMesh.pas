// GPU mesh resource — retained upload of a CPU TMesh (R-19, stage B4).
//
// TGpuMesh takes a CPU SoA mesh (Apus.Engine.Mesh3D.TMesh), gathers its per-attribute
// arrays into one interleaved vertex stream according to a TGpuLayout, encodes the
// formats and uploads them into a GPU vertex buffer. The index buffer width
// (uint16/uint32) is chosen here from the mesh's max index. Drawing goes through the
// table-driven binding path (renderDevice.DrawMesh + shader.ApplyMeshLayout), which
// coexists with the legacy TVertexLayout painter path.
//
// Stage B4 scope: single interleaved stream, native attribute formats (no compression
// encoders yet), no skinning/instancing streams, no muDiscardCPUCopy reload handling.
// Multi-stream, format compression and instance streams arrive in stage C.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.GpuMesh;
interface
uses Apus.Core, Apus.Classes, Apus.Geom2D, Apus.Geom3D,
  Apus.Engine.GpuLayout, Apus.Engine.API, Apus.Engine.Graphics,
  // listed last so the unqualified TMesh resolves to the new SoA mesh, not the
  // legacy Apus.Engine.Mesh.TMesh that Apus.Engine.API re-exports (until C2 rename)
  Apus.Engine.Mesh3D;

type
 // Upload behaviour flags.
 TUploadFlag=(muDiscardCPUCopy); // free the CPU mesh copy after upload (static assets only)
 TUploadFlags=set of TUploadFlag;

 TGpuMesh=class(TNamedObject)
  source:TMesh;                          // CPU mesh (may be nil after muDiscardCPUCopy)
  layout:TGpuLayout;                     // GPU packing descriptor (interned)
  vertexBuffers:array of TVertexBuffer;  // one VBO per stream (B4: a single stream)
  indexBuffer:TIndexBuffer;              // uint16 or uint32, chosen at upload
  vertexCount:integer;
  indexCount:integer;
  indexBytes:integer;                    // 0 = non-indexed, 2 = uint16, 4 = uint32

  // auto-layout from the present attribute arrays
  constructor Create(mesh:TMesh); overload;
  // explicit layout (stream-split / compression / instance — future use)
  constructor Create(mesh:TMesh;aLayout:TGpuLayout); overload;
  destructor Destroy; override;

  procedure Upload(flags:TUploadFlags=[]);
  procedure DrawRange(firstIndex,rangeCount:integer;tex:TTexture=nil);
  procedure Draw(tex:TTexture=nil); // draw the whole mesh
 private
  cpuDiscarded:boolean;
  procedure EncodeStream(streamIdx:byte;var buf:ByteArray);
 end;

// Build an interleaved single-stream layout from a mesh's present arrays, using
// native (uncompressed) formats. Finalized (interned) on return.
function BuildAutoLayout(mesh:TMesh):TGpuLayout;

implementation
uses Apus.Engine.Resources;

function BuildAutoLayout(mesh:TMesh):TGpuLayout;
 begin
  result:=TGpuLayout.Create;
  result.BeginBuild;
  result.Add(TMeshSemantic.Position,TVertexFormat.Float3);
  if length(mesh.normals)>0 then result.Add(TMeshSemantic.Normal,TVertexFormat.Float3);
  if length(mesh.colors)>0 then result.Add(TMeshSemantic.Color,TVertexFormat.UByte4Norm);
  if length(mesh.uv0)>0 then result.Add(TMeshSemantic.TexCoord,TVertexFormat.Float2,0,0);
  if length(mesh.uv1)>0 then result.Add(TMeshSemantic.TexCoord,TVertexFormat.Float2,0,1);
  if length(mesh.tangents)>0 then result.Add(TMeshSemantic.Tangent,TVertexFormat.Float4);
  // joints/weights are deferred to stage C3 (need UByte4/UByte4Norm encoders)
  result.Finalize;
 end;

{ TGpuMesh }

constructor TGpuMesh.Create(mesh:TMesh);
 begin
  Create(mesh,BuildAutoLayout(mesh));
 end;

constructor TGpuMesh.Create(mesh:TMesh;aLayout:TGpuLayout);
 begin
  inherited Create;
  source:=mesh;
  layout:=aLayout;
  if mesh.name<>'' then name:=mesh.name;
 end;

destructor TGpuMesh.Destroy;
 var
  i:integer;
 begin
  for i:=0 to high(vertexBuffers) do vertexBuffers[i].Free;
  SetLength(vertexBuffers,0);
  indexBuffer.Free;
  // layout is interned and owned by the global registry — never freed here
  inherited;
 end;

// Gather the SoA arrays of one stream into interleaved bytes (native formats).
procedure TGpuMesh.EncodeStream(streamIdx:byte;var buf:ByteArray);
 var
  v,a,stride:integer;
  base,dst:PByte;
 begin
  stride:=layout.StreamStride(streamIdx);
  SetLength(buf,vertexCount*stride);
  if vertexCount=0 then exit;
  base:=@buf[0];
  for v:=0 to vertexCount-1 do begin
   for a:=0 to high(layout.attributes) do with layout.attributes[a] do begin
    if stream<>streamIdx then continue; // attribute belongs to another stream
    dst:=base; inc(dst,offset);
    case semantic of
     TMeshSemantic.Position: PVec3(dst)^:=source.positions[v];
     TMeshSemantic.Normal:   PVec3(dst)^:=source.normals[v];
     TMeshSemantic.Color:    PCardinal(dst)^:=source.colors[v]; // bytes B,G,R,A — matches stock shader vColor.bgr
     TMeshSemantic.Tangent:  PVec4(dst)^:=source.tangents[v];
     TMeshSemantic.TexCoord:
       if semanticIndex=0 then PVec2(dst)^:=source.uv0[v]
        else PVec2(dst)^:=source.uv1[v];
     else
      raise EError.Create('TGpuMesh: unsupported semantic in auto-encode (stage B4 native formats only)');
    end;
   end;
   inc(base,stride);
  end;
 end;

procedure TGpuMesh.Upload(flags:TUploadFlags=[]);
 var
  vbuf:ByteArray;
  idx16:array of word;
  i:integer;
 begin
  ASSERT(not cpuDiscarded,'TGpuMesh.Upload: CPU copy was discarded');
  ASSERT(source<>nil);
  vertexCount:=source.VertexCount;
  indexCount:=source.IndexCount;
  // --- vertex stream (B4: single stream 0) ---
  EncodeStream(0,vbuf);
  if length(vertexBuffers)=0 then begin
   SetLength(vertexBuffers,1);
   vertexBuffers[0]:=gfx.resMan.AllocRawVertexBuffer(layout.StreamStride(0),vertexCount);
   vertexBuffers[0].debugName:='gpuMeshVB';
  end;
  if vertexCount>0 then vertexBuffers[0].Upload(0,vertexCount,@vbuf[0]);
  // --- index buffer: width chosen from max index ---
  if indexCount>0 then begin
   if source.MaxIndex<=high(word) then indexBytes:=2 else indexBytes:=4;
   if indexBuffer=nil then begin
    indexBuffer:=gfx.resMan.AllocIndexBuffer(indexCount,indexBytes);
    indexBuffer.debugName:='gpuMeshIB';
   end;
   if indexBytes=2 then begin
    SetLength(idx16,indexCount);
    for i:=0 to indexCount-1 do idx16[i]:=word(source.indices[i]);
    indexBuffer.Upload(0,indexCount,@idx16[0]);
   end else
    indexBuffer.Upload(0,indexCount,@source.indices[0]); // int32 == uint32 bit pattern
  end else
   indexBytes:=0;
  if muDiscardCPUCopy in flags then begin
   source.Free;
   source:=nil;
   cpuDiscarded:=true;
  end;
 end;

procedure TGpuMesh.DrawRange(firstIndex,rangeCount:integer;tex:TTexture=nil);
 begin
  if (length(vertexBuffers)=0) or (vertexBuffers[0]=nil) then exit; // not uploaded
  clippingAPI.Prepare;
  if tex<>nil then shader.UseTexture(tex);
  shader.ApplyMeshLayout(layout);
  gfx.resMan.UseVertexBuffer(vertexBuffers[0]);
  if indexBytes>0 then gfx.resMan.UseIndexBuffer(indexBuffer);
  renderDevice.DrawMesh(layout,firstIndex,rangeCount,indexBytes);
  gfx.resMan.UseVertexBuffer(nil);
  if indexBytes>0 then gfx.resMan.UseIndexBuffer(nil);
 end;

procedure TGpuMesh.Draw(tex:TTexture=nil);
 begin
  if indexBytes>0 then DrawRange(0,indexCount,tex)
   else DrawRange(0,vertexCount,tex);
 end;

end.
