// Headless unit test for the R-19 GPU layout descriptor (stage B1).
// Covers: packed format sizes/components, the stable semantic->location table,
// build offset/stride computation, Find, content-hash determinism and interning.
{$APPTYPE CONSOLE}
program TestGpuLayout;
uses
  SysUtils,
  Apus.Core,
  Apus.Engine.GpuLayout;

{$I ..\Base\tests\Test.inc}

// Verify all packed format sizes in one assertion.
function FormatSizesOk:boolean;
begin
  result:=
    (VertexFormatSize(TVertexFormat.Float1)=4) and
    (VertexFormatSize(TVertexFormat.Float2)=8) and
    (VertexFormatSize(TVertexFormat.Float3)=12) and
    (VertexFormatSize(TVertexFormat.Float4)=16) and
    (VertexFormatSize(TVertexFormat.UByte4Norm)=4) and
    (VertexFormatSize(TVertexFormat.UByte4)=4) and
    (VertexFormatSize(TVertexFormat.UInt16x4)=8) and
    (VertexFormatSize(TVertexFormat.UInt32)=4);
end;

function FormatComponentsOk:boolean;
begin
  result:=
    (VertexFormatComponents(TVertexFormat.Float1)=1) and
    (VertexFormatComponents(TVertexFormat.Float2)=2) and
    (VertexFormatComponents(TVertexFormat.Float3)=3) and
    (VertexFormatComponents(TVertexFormat.Float4)=4) and
    (VertexFormatComponents(TVertexFormat.UByte4Norm)=4) and
    (VertexFormatComponents(TVertexFormat.UByte4)=4) and
    (VertexFormatComponents(TVertexFormat.UInt16x4)=4) and
    (VertexFormatComponents(TVertexFormat.UInt32)=1);
end;

// Verify the stable semantic->location table.
function LocationTableOk:boolean;
begin
  result:=
    (MeshSemanticLocation(TMeshSemantic.Position)=0) and
    (MeshSemanticLocation(TMeshSemantic.Normal)=1) and
    (MeshSemanticLocation(TMeshSemantic.Color,0)=2) and
    (MeshSemanticLocation(TMeshSemantic.TexCoord,0)=3) and
    (MeshSemanticLocation(TMeshSemantic.TexCoord,1)=4) and
    (MeshSemanticLocation(TMeshSemantic.Tangent)=5) and
    (MeshSemanticLocation(TMeshSemantic.Joint)=6) and
    (MeshSemanticLocation(TMeshSemantic.Weight)=7) and
    (MeshSemanticLocation(TMeshSemantic.Custom,0)=14);
end;

// Build a standard interleaved layout: pos(f3)+normal(f3)+uv(f2)+color(ub4n).
function MakeStdLayout:TGpuLayout;
begin
  result:=TGpuLayout.Create;
  result.Add(TMeshSemantic.Position,TVertexFormat.Float3);
  result.Add(TMeshSemantic.Normal,TVertexFormat.Float3);
  result.Add(TMeshSemantic.TexCoord,TVertexFormat.Float2);
  result.Add(TMeshSemantic.Color,TVertexFormat.UByte4Norm);
  result.Finalize;
end;

procedure TestFormats;
begin
  StartTest('format sizes/components');
  Check(FormatSizesOk,'packed format sizes');
  Check(FormatComponentsOk,'component counts');
  EndTest;
end;

procedure TestLocationTable;
begin
  StartTest('semantic->location table');
  Check(LocationTableOk,'stable semantic->location mapping');
  EndTest;
end;

procedure TestBuild;
var
  l:TGpuLayout;
begin
  StartTest('layout build offset/stride');
  l:=MakeStdLayout;
  Check(l.attributes[0].offset=0,'position offset');
  Check(l.attributes[1].offset=12,'normal offset');
  Check(l.attributes[2].offset=24,'uv offset');
  Check(l.attributes[3].offset=32,'color offset');
  Check(l.StreamStride(0)=36,'stream0 stride = 36');
  Check(length(l.streams)=1,'single stream');
  Check(l.streams[0].usage=TStreamUsage.Static,'default usage Static');
  EndTest;
end;

procedure TestFind;
var
  l:TGpuLayout;
begin
  StartTest('layout Find');
  l:=MakeStdLayout;
  Check(l.Find(TMeshSemantic.Position)=0,'find position');
  Check(l.Find(TMeshSemantic.TexCoord)=2,'find texcoord');
  Check(l.Find(TMeshSemantic.Color)=3,'find color');
  Check(l.Find(TMeshSemantic.Tangent)=-1,'absent attribute -> -1');
  EndTest;
end;

procedure TestInterning;
var
  l,l2,l3:TGpuLayout;
begin
  StartTest('layout interning');
  l:=MakeStdLayout;
  l2:=MakeStdLayout; // identical content, built separately
  Check(l.hash=l2.hash,'identical content -> equal hash');
  Check(l.id=l2.id,'identical content -> shared canonical id');
  Check(l.ContentEqual(l2),'content equal');
  // a different layout must get a distinct id
  l3:=TGpuLayout.Create;
  l3.Add(TMeshSemantic.Position,TVertexFormat.Float3);
  l3.Finalize;
  Check(l3.id<>l.id,'different content -> different id');
  Check(l3.hash<>l.hash,'different content -> different hash');
  Check(not l3.ContentEqual(l),'content not equal');
  EndTest;
end;

procedure TestMultiStream;
var
  l:TGpuLayout;
begin
  StartTest('multi-stream usage');
  l:=TGpuLayout.Create;
  l.Add(TMeshSemantic.Position,TVertexFormat.Float3,0);
  l.Add(TMeshSemantic.Normal,TVertexFormat.Float3,0);
  // a vec4 attribute on its own per-instance stream
  l.Add(TMeshSemantic.Custom,TVertexFormat.Float4,1,0);
  l.SetStreamUsage(1,TStreamUsage.Instance);
  l.Finalize;
  Check(l.StreamStride(0)=24,'stream0 stride (pos+normal)');
  Check(l.StreamStride(1)=16,'stream1 stride (vec4)');
  Check(l.streams[0].usage=TStreamUsage.Static,'stream0 Static');
  Check(l.streams[1].usage=TStreamUsage.Instance,'stream1 Instance');
  Check(l.attributes[2].stream=1,'custom attr on stream1');
  Check(l.attributes[2].offset=0,'custom attr offset within its stream');
  EndTest;
end;

begin
  writeln('=== TestGpuLayout ===');
  TestFormats;
  TestLocationTable;
  TestBuild;
  TestFind;
  TestInterning;
  TestMultiStream;
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
