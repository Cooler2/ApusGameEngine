// Shared assets and placements for experimental static AEM models.
// Copyright (C) 2026 Apus Software. Distributed under the BSD-3 license.
unit Apus.Engine.Model;
interface
uses Apus.Core, Apus.Geom3D, Apus.Engine.AEMLoader, Apus.Engine.GpuMesh;

type
  // Indices identify a section, its texture hints and its logical material slot.
  TModelDrawPart=record
    nodeIndex:integer;
    meshIndex:integer;
    sectionIndex:integer;
    bindingIndex:integer;
    slotIndex:integer;
  end;

  // Set the shader, textures and render state for this section. Return false to skip it.
  TModelPartBinder=function(const part:TModelDrawPart):boolean of object;

  // Owns the immutable model data and the GPU meshes shared by its placements.
  TModelAsset=class
  private
    fSourcePath:String8;
    fData:TAemStaticData;
    fGpuMeshes:array of TGpuMesh;
    constructor Create(const fileName:String8);
    procedure FreeGpuMeshes;
  public
    destructor Destroy; override;

    // Loads through the VFS and returns a new caller-owned asset. No GL context is needed.
    class function LoadAEM(const fileName:String8):TModelAsset; overload; static;
    {$IFDEF UNICODE}
    {$DEFINE APUS_MODEL_UNICODE_OVERLOAD}
    class function LoadAEM(const fileName:UnicodeString):TModelAsset; overload; static;
    {$ENDIF}

    function SourcePath:String8;
    function Bounds:TBox3; // asset-space bounds for all levels
    function LODCount:integer;
    function SelectLOD(screenHeightFraction:single):integer;
    function MaterialSlotName(slotIndex:integer):String8;
    // A path relative to the logical directory of SourcePath, or an empty string.
    function TextureHint(bindingIndex:integer;const role:String8):String8;

    // Upload once on the graphics thread with an active context. Free the asset
    // on that thread before the graphics resources are torn down.
    procedure Upload;
  end;

  // One placement of a borrowed asset. Free instances before freeing their asset.
  TModelInstance=class
  private
    fAsset:TModelAsset;
    fTransform:TMat4;
    fLOD:integer;
  public
    constructor Create(aAsset:TModelAsset);
    function GetTransform:TMat4;
    procedure SetTransform(const value:TMat4);
    function GetLOD:integer;
    procedure SetLOD(value:integer);

    property Transform:TMat4 read GetTransform write SetTransform;
    property LOD:integer read GetLOD write SetLOD;

    // Draw with the current view and base. A nil binder uses the caller's material.
    procedure Draw(const bindPart:TModelPartBinder);
  end;

implementation
uses Math, Apus.Strings, Apus.Engine.API, Apus.Engine.Graphics;

constructor TModelAsset.Create(const fileName:String8);
begin
  inherited Create;
  fSourcePath:=fileName;
  fData:=LoadStaticAEM(fileName);
end;

destructor TModelAsset.Destroy;
begin
  FreeGpuMeshes;
  fData.Free;
  inherited;
end;

class function TModelAsset.LoadAEM(const fileName:String8):TModelAsset;
begin
  result:=TModelAsset.Create(fileName);
end;

// Keep the overload declared in the interface if an FPC dependency changes Unicode mode.
{$IFDEF APUS_MODEL_UNICODE_OVERLOAD}
class function TModelAsset.LoadAEM(const fileName:UnicodeString):TModelAsset;
begin
  result:=LoadAEM(UTF8.FromWide(fileName));
end;
{$ENDIF}

function TModelAsset.SourcePath:String8;
begin
  result:=fSourcePath;
end;

function TModelAsset.Bounds:TBox3;
begin
  result:=fData.bounds;
end;

function TModelAsset.LODCount:integer;
begin
  result:=length(fData.levels);
end;

function TModelAsset.SelectLOD(screenHeightFraction:single):integer;
var
  i:integer;
begin
  if Math.IsNan(screenHeightFraction) or Math.IsInfinite(screenHeightFraction) then
    raise EError.Create('Model LOD screen height must be finite');
  // The thresholds already cover the clamped range, including a final zero.
  for i:=0 to high(fData.levels)-1 do
    if screenHeightFraction>=fData.levels[i].minScreenHeight then exit(i);
  result:=high(fData.levels);
end;

function TModelAsset.MaterialSlotName(slotIndex:integer):String8;
begin
  if (slotIndex<0) or (slotIndex>=length(fData.slots)) then
    raise EError.Create('Model material slot index out of range: %d',[slotIndex]);
  result:=fData.slots[slotIndex];
end;

function TModelAsset.TextureHint(bindingIndex:integer;const role:String8):String8;
var
  i:integer;
begin
  if (bindingIndex<0) or (bindingIndex>=length(fData.bindings)) then
    raise EError.Create('Model material binding index out of range: %d',[bindingIndex]);
  with fData.bindings[bindingIndex] do
    for i:=0 to high(hints) do
      if hints[i].role=role then exit(hints[i].path);
  result:='';
end;

procedure TModelAsset.FreeGpuMeshes;
var
  i:integer;
begin
  for i:=0 to high(fGpuMeshes) do
    fGpuMeshes[i].Free;
  fGpuMeshes:=nil;
end;

procedure TModelAsset.Upload;
var
  i:integer;
begin
  if length(fGpuMeshes)>0 then exit;
  if (gfx=nil) or (renderDevice=nil) then
    raise EError.Create('Model upload requires initialized graphics');
  SetLength(fGpuMeshes,length(fData.meshes));
  try
    for i:=0 to high(fGpuMeshes) do begin
      fGpuMeshes[i]:=TGpuMesh.Create(fData.meshes[i].geometry);
      fGpuMeshes[i].Upload;
    end;
  except
    FreeGpuMeshes;
    raise;
  end;
end;

constructor TModelInstance.Create(aAsset:TModelAsset);
begin
  inherited Create;
  if aAsset=nil then raise EError.Create('Model instance requires an asset');
  fAsset:=aAsset;
  fTransform:=identMat4;
end;

function TModelInstance.GetTransform:TMat4;
begin
  result:=fTransform;
end;

procedure TModelInstance.SetTransform(const value:TMat4);
var
  row,col:integer;
begin
  for row:=0 to 3 do
    for col:=0 to 3 do
      if Math.IsNan(value.v[row,col]) or Math.IsInfinite(value.v[row,col]) then
        raise EError.Create('Model transform must be finite');
  if (value.v[0,3]<>0) or (value.v[1,3]<>0) or (value.v[2,3]<>0) or
     (value.v[3,3]<>1) or (value.ToMat4d.ToMat3.Determinant<=0) then
    raise EError.Create('Model transform must be affine with positive determinant');
  fTransform:=value;
end;

function TModelInstance.GetLOD:integer;
begin
  result:=fLOD;
end;

procedure TModelInstance.SetLOD(value:integer);
begin
  if (value<0) or (value>=fAsset.LODCount) then
    raise EError.Create('Model LOD index out of range: %d',[value]);
  fLOD:=value;
end;

procedure TModelInstance.Draw(const bindPart:TModelPartBinder);
var
  part:TModelDrawPart;
  state:TTransformState;
  placement:TMat4d;
  nodeIndex,sectionIndex:integer;
  data:TAemStaticData;
  gpuMesh:TGpuMesh;
begin
  if length(fAsset.fGpuMeshes)=0 then raise EError.Create('Upload the model asset before drawing');
  if (gfx=nil) or (renderDevice=nil) or (transformationAPI=nil) then
    raise EError.Create('Model draw requires initialized graphics');

  data:=fAsset.fData;
  placement:=fTransform.ToMat4d;
  state:=transformationAPI.SaveState;
  try
    for nodeIndex in data.levels[fLOD].nodes do begin
      part.nodeIndex:=nodeIndex;
      part.meshIndex:=data.nodes[nodeIndex].meshIndex;
      gpuMesh:=fAsset.fGpuMeshes[part.meshIndex];
      transformationAPI.SetObj(data.nodes[nodeIndex].meshToAsset*placement);
      for sectionIndex:=0 to high(data.meshes[part.meshIndex].bindings) do begin
        part.sectionIndex:=sectionIndex;
        part.bindingIndex:=data.meshes[part.meshIndex].bindings[sectionIndex];
        part.slotIndex:=data.bindings[part.bindingIndex].slotIndex;
        if not Assigned(bindPart) or bindPart(part) then
          gpuMesh.DrawSection(sectionIndex);
      end;
    end;
  finally
    transformationAPI.RestoreState(state);
  end;
end;

end.
