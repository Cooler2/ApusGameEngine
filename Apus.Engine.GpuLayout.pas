// GPU vertex layout descriptor (R-19, stage B1).
//
// A TGpuLayout describes HOW a mesh's per-attribute SoA arrays are packed into
// GPU vertex buffer(s): which semantic goes to which stream, at which offset,
// encoded in which format. It is purely a GPU-side concept — the CPU mesh has
// no layout, only a set of typed arrays.
//
// Layouts are immutable after Finalize and interned by deterministic
// content-hash: two layouts with identical content share the same canonical
// "id", so the hot per-draw path compares layouts by a single integer.
//
// The semantic->location mapping is a single stable table (MeshSemanticLocation)
// used by BOTH the GL attribute binder and the shader generator — there is no
// per-layout sequential location assignment.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.GpuLayout;
interface
uses Apus.Core, Apus.Threads;

{$SCOPEDENUMS ON}
type
 // What an attribute means (drives the stable shader location, see table below)
 TMeshSemantic=(Position,Normal,Color,TexCoord,Tangent,Joint,Weight,Custom);

 // GPU encoding target for an attribute. This is the packed type in the VBO,
 // NOT the CPU storage type: CPU normals are float TVec3, a layout may request
 // UByte4Norm and the uploader encodes accordingly.
 TVertexFormat=(Float1,Float2,Float3,Float4,
                UByte4Norm,UByte4,UInt16x4,UInt32);

 // How a stream is fetched per primitive. Drives the attribute divisor:
 // Static/Dynamic => divisor 0 (per-vertex), Instance => divisor 1.
 TStreamUsage=(Static,Dynamic,Instance);
{$SCOPEDENUMS OFF}

type
 TVertexAttribute=record
  semantic:TMeshSemantic;
  semanticIndex:byte;   // uv0/uv1, custom0/custom1, instance rows
  format:TVertexFormat; // encoding target on GPU (not CPU storage type)
  stream:byte;          // which vertex stream this attribute lives in
  offset:word;          // byte offset within the stream's stride
 end;

 TVertexStreamLayout=record
  stride:word;          // bytes per vertex in this stream
  usage:TStreamUsage;   // -> attribute divisor
 end;

 // Immutable interned GPU layout descriptor. Build with BeginBuild/Add[/SetStreamUsage]
 // then Finalize (computes hash, interns, assigns canonical id). After Finalize the
 // instance must not be mutated. Interned instances are owned by the global registry
 // and live for the program lifetime (do not free them individually).
 TGpuLayout=class
  attributes:array of TVertexAttribute;
  streams:array of TVertexStreamLayout;
  hash:uint64;          // deterministic, content-based
  id:integer;           // canonical, assigned by interning (-1 until Finalize)
  constructor Create;
  // build
  procedure BeginBuild;
  procedure Add(semantic:TMeshSemantic;format:TVertexFormat;
    stream:byte=0;semanticIndex:byte=0);
  procedure SetStreamUsage(stream:byte;usage:TStreamUsage);
  procedure Finalize;
  // query
  function Find(semantic:TMeshSemantic;semanticIndex:byte=0):integer; // attribute index, or -1
  function StreamStride(stream:byte):integer;
  function Describe:String8;
  // content equality (ignores hash/id, compares the actual layout)
  function ContentEqual(other:TGpuLayout):boolean;
 end;

const
 // Stable semantic->location table — the single source of truth for both the GL
 // attribute binder and the shader generator. Sparse locations are legal in the
 // core profile (R-01); GL_MAX_VERTEX_ATTRIBS guarantees >=16.
 // 0..7 standard vertex attributes
 LOC_POSITION =0;
 LOC_NORMAL   =1;
 LOC_COLOR0   =2;
 LOC_TEXCOORD0=3;
 LOC_TEXCOORD1=4;
 LOC_TANGENT  =5;
 LOC_JOINTS0  =6;
 LOC_WEIGHTS0 =7;
 // 8..13 standard instance attributes (wired in stage C3)
 LOC_INSTANCE_TRANSFORM=8;  // occupies 8,9,10 (3x vec4 = affine 4x3)
 LOC_INSTANCE_COLOR    =11; // 12,13 reserved
 // 14..15 custom/debug
 LOC_CUSTOM0  =14;

// Map a semantic+index to its stable shader attribute location, or -1 if unknown.
// Only the standard set (table above) is guaranteed collision-free.
function MeshSemanticLocation(semantic:TMeshSemantic;semanticIndex:byte=0):integer;
// Byte size of a packed attribute format.
function VertexFormatSize(format:TVertexFormat):integer;
// Number of scalar components in a format (e.g. Float3 -> 3, UByte4Norm -> 4).
function VertexFormatComponents(format:TVertexFormat):integer;

implementation
uses Apus.Strings, Apus.Conv; // String8 helpers, ToStr

const
 FNV_OFFSET=uint64(14695981039346656037);
 FNV_PRIME =uint64(1099511628211);

var
 internLock:TLock;
 internList:array of TGpuLayout; // canonical interned layouts
 internCount:integer;

function MeshSemanticLocation(semantic:TMeshSemantic;semanticIndex:byte):integer;
 begin
  case semantic of
   TMeshSemantic.Position:result:=LOC_POSITION;
   TMeshSemantic.Normal:  result:=LOC_NORMAL;
   TMeshSemantic.Color:   result:=LOC_COLOR0+semanticIndex;
   TMeshSemantic.TexCoord:result:=LOC_TEXCOORD0+semanticIndex; // 0->3, 1->4
   TMeshSemantic.Tangent: result:=LOC_TANGENT;
   TMeshSemantic.Joint:   result:=LOC_JOINTS0;
   TMeshSemantic.Weight:  result:=LOC_WEIGHTS0;
   TMeshSemantic.Custom:  result:=LOC_CUSTOM0+semanticIndex;
   else result:=-1;
  end;
 end;

function VertexFormatSize(format:TVertexFormat):integer;
 begin
  case format of
   TVertexFormat.Float1:    result:=4;
   TVertexFormat.Float2:    result:=8;
   TVertexFormat.Float3:    result:=12;
   TVertexFormat.Float4:    result:=16;
   TVertexFormat.UByte4Norm:result:=4;
   TVertexFormat.UByte4:    result:=4;
   TVertexFormat.UInt16x4:  result:=8;
   TVertexFormat.UInt32:    result:=4;
   else result:=0;
  end;
 end;

function VertexFormatComponents(format:TVertexFormat):integer;
 begin
  case format of
   TVertexFormat.Float1:  result:=1;
   TVertexFormat.Float2:  result:=2;
   TVertexFormat.Float3:  result:=3;
   TVertexFormat.UInt32:  result:=1;
   else result:=4; // Float4, UByte4Norm, UByte4, UInt16x4
  end;
 end;

procedure HashByte(var h:uint64;b:byte); inline;
 begin
  h:=h xor b;
  h:=h*FNV_PRIME;
 end;

procedure HashWord(var h:uint64;w:word); inline;
 begin
  HashByte(h,w and $FF);
  HashByte(h,w shr 8);
 end;

{ TGpuLayout }

constructor TGpuLayout.Create;
 begin
  BeginBuild;
 end;

procedure TGpuLayout.BeginBuild;
 begin
  SetLength(attributes,0);
  SetLength(streams,0);
  hash:=0;
  id:=-1;
 end;

procedure TGpuLayout.Add(semantic:TMeshSemantic;format:TVertexFormat;
   stream:byte=0;semanticIndex:byte=0);
 var
  n:integer;
 begin
  ASSERT(id<0,'Cannot mutate a finalized layout');
  // ensure the target stream exists (new streams default to Static, stride 0)
  if stream>high(streams) then begin
   n:=length(streams);
   SetLength(streams,stream+1);
   while n<=stream do begin
    streams[n].stride:=0;
    streams[n].usage:=TStreamUsage.Static;
    inc(n);
   end;
  end;
  n:=length(attributes);
  SetLength(attributes,n+1);
  attributes[n].semantic:=semantic;
  attributes[n].semanticIndex:=semanticIndex;
  attributes[n].format:=format;
  attributes[n].stream:=stream;
  attributes[n].offset:=streams[stream].stride; // append at end of stream
  inc(streams[stream].stride,VertexFormatSize(format));
 end;

procedure TGpuLayout.SetStreamUsage(stream:byte;usage:TStreamUsage);
 var
  n:integer;
 begin
  ASSERT(id<0,'Cannot mutate a finalized layout');
  if stream>high(streams) then begin
   n:=length(streams);
   SetLength(streams,stream+1);
   while n<=stream do begin
    streams[n].stride:=0;
    streams[n].usage:=TStreamUsage.Static;
    inc(n);
   end;
  end;
  streams[stream].usage:=usage;
 end;

function TGpuLayout.ContentEqual(other:TGpuLayout):boolean;
 var
  i:integer;
 begin
  result:=false;
  if other=nil then exit;
  if (length(attributes)<>length(other.attributes)) or
     (length(streams)<>length(other.streams)) then exit;
  for i:=0 to high(attributes) do
   if (attributes[i].semantic<>other.attributes[i].semantic) or
      (attributes[i].semanticIndex<>other.attributes[i].semanticIndex) or
      (attributes[i].format<>other.attributes[i].format) or
      (attributes[i].stream<>other.attributes[i].stream) or
      (attributes[i].offset<>other.attributes[i].offset) then exit;
  for i:=0 to high(streams) do
   if (streams[i].stride<>other.streams[i].stride) or
      (streams[i].usage<>other.streams[i].usage) then exit;
  result:=true;
 end;

procedure TGpuLayout.Finalize;
 var
  i:integer;
  h:uint64;
 begin
  // deterministic content hash (order of attributes/streams is part of identity)
  h:=FNV_OFFSET;
  HashByte(h,length(attributes));
  for i:=0 to high(attributes) do with attributes[i] do begin
   HashByte(h,ord(semantic));
   HashByte(h,semanticIndex);
   HashByte(h,ord(format));
   HashByte(h,stream);
   HashWord(h,offset);
  end;
  HashByte(h,length(streams));
  for i:=0 to high(streams) do with streams[i] do begin
   HashWord(h,stride);
   HashByte(h,ord(usage));
  end;
  hash:=h;
  // intern: lookup-or-insert canonical instance, assign id
  internLock.Enter;
  try
   for i:=0 to internCount-1 do
    if (internList[i].hash=hash) and ContentEqual(internList[i]) then begin
     id:=internList[i].id; // share existing canonical id
     exit;
    end;
   id:=internCount; // new canonical layout
   if internCount>=length(internList) then SetLength(internList,internCount*2+16);
   internList[internCount]:=self;
   inc(internCount);
  finally
   internLock.Leave;
  end;
 end;

function TGpuLayout.Find(semantic:TMeshSemantic;semanticIndex:byte=0):integer;
 var
  i:integer;
 begin
  for i:=0 to high(attributes) do
   if (attributes[i].semantic=semantic) and (attributes[i].semanticIndex=semanticIndex) then
    exit(i);
  result:=-1;
 end;

function TGpuLayout.StreamStride(stream:byte):integer;
 begin
  if stream>high(streams) then exit(0);
  result:=streams[stream].stride;
 end;

function TGpuLayout.Describe:String8;
 const
  semNames:array[TMeshSemantic] of String8=
   ('pos','norm','color','uv','tangent','joint','weight','custom');
  fmtNames:array[TVertexFormat] of String8=
   ('f1','f2','f3','f4','ub4n','ub4','u16x4','u32');
 var
  i:integer;
 begin
  result:='layout#'+Conv.ToStr(id)+' [';
  for i:=0 to high(attributes) do with attributes[i] do begin
   if i>0 then result:=result+', ';
   result:=result+semNames[semantic];
   if semanticIndex>0 then result:=result+Conv.ToStr(semanticIndex);
   result:=result+':'+fmtNames[format]+'@s'+Conv.ToStr(stream)+'+'+Conv.ToStr(offset);
  end;
  result:=result+']';
 end;

initialization
 internLock.Init('GpuLayoutIntern');
end.
