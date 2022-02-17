// Class for 3D model with skeletal (rigged) animation
//
// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Model3D;
interface
uses Apus.MyServis, Apus.Geom2D, Apus.Geom3D, Apus.Structs, Apus.AnimatedValues, Apus.Engine.API;
const
 // Bone flags
 bfDefaultPos = 1; // default matrix updated (model->bone)
 bfCurrentPos = 2; // current matrix updated (bone->model)

type
(* // Vertex for a typical 3D mesh
 T3DModelVertex=record
  x,y,z:single;
  color:cardinal;
  nX,nY,nZ:single;
  attr:cardinal;
  u,v:single;
 end; *)

 // Part of mesh surface
 TModelPart=record
  partName,materialName:AnsiString;
  firstTrg,trgCount:integer;  // triangles of the part
  firstVrt,vrtCount:integer;  // vertices used in the part (may also conatain other vertices)
 end;

 {$MinEnumSize 1}
 TBoneProperty=(bpPosition,bpRotation,bpScale);

 // Definition of bone
 TBone=packed record
  boneName:string;
  parent:integer; // index of the parent bone
  // default values
  position:TPoint3s;
  scale:TVector3s;
  {$IFDEF CPUx64} padding:array[0..2] of cardinal;  {$ENDIF} // align by 16
  rotation:TQuaternionS;
  matrix:TMatrix4s; // model space -> bone space (in reference position)
 end;
 TBonesArray=array of TBone;

 // Animation timeline is a big table [bone_property,frame]
 // This record (20 bytes) stores one cell of this table
 // Sorted by frame,boneIdx
 TKeyFrame=packed record
  frame:word;   // time marker
  boneIdx:byte; // bone index
  prop:TBoneProperty;    // which bone property is affected (position, rotation or scale)
  value:TQuaternionS;
 end;
 TAnimationKeyFrames=array of TKeyFrame;

 // Single bone state
 TBoneState=record
  position:TVector4s;
  rotation:TQuaternionS;
  scale:TVector4s;
 end;

 // Per-frame bone states
 TTimeline=record
  positions:array of TVector4s;
  rotations:array of TQuaternionS;
  scales:array of TVector4s;
 end;

 TModel3D=class;
 TModelInstance=class;

 // Single animation timeline
 TAnimation=record
  name:string;
  numFrames:integer; // duration in frames
  fps:single;  // frames per second
  keyFrames:TAnimationKeyFrames; // individual keyframes (source)
  loopFrom,loopTo:integer; // loop frame range (0 - don't loop)
  smooth:boolean; // play smoothly - interpolate between animation frames
  procedure SetLoop(loop:boolean=true); overload;
  procedure SetLoop(fromFrame,toFrame:integer); overload;
  procedure BuildTimeline(model:TModel3D);
  // Get timeline values
  function GetBonePosition(bone:integer;frame:single):TVector4s;
  function GetBoneRotation(bone:integer;frame:single):TQuaternionS;
  function GetBoneScale(bone:integer;frame:single):TVector4s;
 private
  timeline:array of TTimeline; // timeline for each bone (can contain empty arrays)
  defaultBoneState:array of TBoneState; // state of bones with no timeline
  procedure UpdateBonesForFrame(const bones:TBonesArray;frame:single);
 end;

 // Vertex bindings
 TVertexBinding=packed record
  bone1,bone2:byte;
  weight1,weight2:byte; // 0..255 range
 end;

 // 3D model with rigged animation support
 TModel3D=class
  name,src:string; // Model name and source file name (if available)
  // Vertex data (no more than 64K vertices!)
  vp:array of TPoint3s;  // vertex positions
  vn:array of TVector3s; // vertex normals (optional)
  vt,vt2:array of TPoint2s; // texture coords (up to 2 sets, optional)
  vc:array of cardinal;     // vertex colors (optional)
  vb:array of TVertexBinding;  // Weights and indices (max 2 bones supported per vertex)
  // Surface data
  trgList:array of word;    // List of triangles
  parts:array of TModelPart;  // Model may contain multiple parts
  // Bones
  bones:TBonesArray;
  // Animation sequences
  animations:array of TAnimation;

  // External references
  shaderName,texName,texName2:string;

  fps:single;

  constructor Create(name:string;src:string='');
  procedure Prepare; // precalculate bone matrices, build animation timelines etc...
  // Instantiate a model
  function CreateInstance:TModelInstance;

  procedure FlipX; // Flip model along X axis (right\left CS conversion)
  function FindBone(bName:string):integer;

  // Build vertex data buffer. Transformed=true - apply bone matrices and weights to vertex positions and normals
  // Negative offset -> don't fill data
  procedure FillVertexBuffer(data:pointer;vrtCount,stride:integer; useBones:boolean;
    vpOffset,vtOffset,vt2Offset,vnOffset,vcOffset:integer);

  // Update bones: values and matrices
  procedure AnimateBones;
 private
  bonesHash:TSimpleHashS;
  procedure CalcBoneMatrix(bone:integer);
 end;

 // An animated instance of a 3D model
 TModelInstance=class
  model:TModel3D;
  constructor Create(model:TModel3D);
  procedure PlayAnimation(name:string='';easeTimeMS:integer=0);
  procedure StopAnimation(name:string='';easeTimeMS:integer=0);
  procedure PauseAnimation(name:string='');
  procedure ResumeAnimation(name:string='');
  procedure SetAnimationPos(name:string;frame:integer);

  procedure Update; // update animations and calculate bones
  procedure Draw(tex:TTexture);
 protected
 type
  TBoneMatrices=record
   toModel:TMatrix4s; // transform to the model space
   combined:TMatrix4s; // combined transformation from default pos to animated pos
  end;

  // For each underlying model's animation there is a state object
  TInstanceAnimation=record
   weight:TAnimatedValue;
   playing:boolean; // is it playing now?
   paused:boolean;
   stopping:boolean; // don't loop if stopping
   curFrame:single; // current playback position (in frames)
   startTime:int64; // when animation playback was started
  end;
 var
  lastUpdated:int64; // when state was last updated
  animations:array of TInstanceAnimation;
  bones:array of TBoneState;
  boneMatrices:array of TBoneMatrices; // "default pos -> animated pos" transformation matrix
  vertices:array of TVertex3D;
  dirty:boolean;
  function AdvanceAnimations(time:integer):boolean;
  procedure UpdateBones;
  procedure UpdateBoneMatrices;
  procedure FillVertexBuffer;
  function FindAnimation(name:string):integer;
 end;

implementation
 uses Apus.CrossPlatform, SysUtils;

 const
  defaultColor:cardinal=$FF808080;


{ TAnimation }
procedure TAnimation.BuildTimeline(model:TModel3D);
 var
  numBones:integer;
  i,j,n,bone,frame,lastKeyFrame,firstKeyFrame:integer;
  nn,step:single;
  dwNN:cardinal absolute nn;
  vec:TVector4s;
 begin
  numBones:=length(model.bones);
  SetLength(timeline,numBones);
  SetLength(defaultBoneState,numBones);
  for i:=0 to numBones-1 do begin // default values
   defaultBoneState[i].position:=Vector4s(model.bones[i].position);
   defaultBoneState[i].rotation:=model.bones[i].rotation;
   defaultBoneState[i].scale:=Vector4s(model.bones[i].scale);
  end;

  // Store keyframes in the timeline
  nn:=NAN;
  for i:=0 to high(keyFrames) do begin
   bone:=keyFrames[i].boneIdx;
   frame:=keyFrames[i].frame;
   ASSERT(frame<numFrames);
   case keyFrames[i].prop of
    bpPosition:begin
      if timeline[bone].positions=nil then begin
       SetLength(timeline[bone].positions,numFrames);
       FillDword(timeline[bone].positions[0],numFrames*3,dwNN);
      end;
      timeline[bone].positions[frame]:=keyFrames[i].value;
    end;
    bpRotation:begin
      if timeline[bone].rotations=nil then begin
       SetLength(timeline[bone].rotations,numFrames);
       FillDword(timeline[bone].rotations[0],numFrames*4,dwNN);
      end;
      timeline[bone].rotations[frame]:=keyFrames[i].value;
    end;
    bpScale:begin
      if timeline[bone].scales=nil then begin
       SetLength(timeline[bone].scales,numFrames);
       FillDword(timeline[bone].scales[0],numFrames*3,dwNN);
      end;
      timeline[bone].scales[frame]:=keyFrames[i].value;
    end;
   end;
  end;

  // Fill the gaps - interpolate keyframe values, and reduce arrays with just single value
  for i:=0 to high(timeline) do
   with timeline[i] do begin
    // Process position
    if length(positions)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if positions[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do begin
         positions[j]:=positions[lastKeyFrame];
         positions[j].Middle(positions[frame],(j-lastKeyFrame)*step);
        end;
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].position:=positions[firstKeyFrame];
      SetLength(positions,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       positions[frame]:=positions[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       positions[frame]:=positions[lastKeyframe];
     end;
    end;
    // Process rotation
    if length(rotations)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if rotations[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do
         rotations[j]:=QInterpolate(rotations[lastKeyFrame],rotations[frame],(j-lastKeyFrame)*step); // with normalization
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].rotation:=rotations[firstKeyFrame];
      SetLength(rotations,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       rotations[frame]:=rotations[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       rotations[frame]:=rotations[lastKeyframe];
     end;
    end;
    // Process scale
    if length(scales)=numFrames then begin
     lastKeyFrame:=-1; firstKeyFrame:=-1;
     // 1-st pass: fill the gaps between keyframes
     for frame:=0 to numFrames-1 do
      if scales[frame].IsValid then begin
       if (lastKeyFrame>=0) and (frame-lastKeyFrame>1) then begin
        step:=1/(frame-lastKeyFrame);
        for j:=lastKeyFrame+1 to frame-1 do begin
         scales[j]:=scales[lastKeyFrame];
         scales[j].Middle(scales[frame],(j-lastKeyFrame)*step);
        end;
       end;
       lastKeyFrame:=frame;
       if firstKeyFrame<0 then firstKeyFrame:=frame;
      end;
     if firstKeyFrame=lastKeyFrame then begin // only one keyframe -> constant value among whole timeline
      defaultBoneState[i].scale:=scales[firstKeyFrame];
      SetLength(scales,0);
     end else begin
      // Fill leading and trailing values
      for frame:=0 to firstKeyFrame-1 do
       scales[frame]:=scales[firstKeyframe];
      for frame:=lastKeyFrame+1 to numFrames-1 do
       scales[frame]:=scales[lastKeyframe];
     end;
    end;
   end;
 end;

function TAnimation.GetBonePosition(bone:integer;frame:single):TVector4s;
 begin
  if timeline[bone].positions<>nil then
   result:=timeline[bone].positions[round(frame)]
  else
   result:=defaultBoneState[bone].position;
 end;

function TAnimation.GetBoneRotation(bone:integer;frame:single):TQuaternionS;
 begin
  if timeline[bone].rotations<>nil then
   result:=timeline[bone].rotations[round(frame)]
  else
   result:=defaultBoneState[bone].rotation;
 end;

function TAnimation.GetBoneScale(bone:integer;frame:single):TVector4s;
 begin
  if timeline[bone].scales<>nil then
   result:=timeline[bone].positions[round(frame)]
  else
   result:=defaultBoneState[bone].scale;
 end;

procedure TAnimation.SetLoop(fromFrame,toFrame:integer);
 begin
  loopFrom:=fromFrame;
  loopTo:=toFrame;
 end;

procedure TAnimation.SetLoop(loop:boolean=true);
 begin
  if loop then
   SetLoop(0,numFrames-1)
  else
   SetLoop(0,0);
 end;

procedure TAnimation.UpdateBonesForFrame(const bones:TBonesArray; frame:single);
var
 a,b,i:integer;
 intFrame:integer;
 fracFrame:single;
begin
{ if keyFrames=nil then exit;
 if not smooth then begin
  intFrame:=Clamp(round(frame),0,numFrames-1);
  fracFrame:=0;
 end else begin
  intFrame:=Clamp(trunc(frame),0,numFrames-1);
  fracFrame:=frac(frame);
 end;
 // Seek frame 1
 a:=0; b:=high(keyFrames);
 repeat
  i:=(a+b+1) div 2;
  if keyFrames[i].frame<intFrame then a:=i else b:=i;
 until a>=b-1;
 while (a<high(keyFrames)) and (keyFrames[a].frame<intFrame) do inc(a);
 while (a<=high(keyFrames)) and (keyFrames[a].frame=intFrame) do
  with keyFrames[a] do begin
   b:=boneIdx;
   case prop of
    bpPosition:bones[b].pos:=value.xyz;
    bpRotation:bones[b].rot:=value;
    bpScale:bones[b].scale:=value.xyz;
   end;
   bones[b].flags:=bones[b].flags and (not bfCurrentPos);
   inc(a);
  end;

 // Smooth?
 if fracFrame>0 then begin
  inc(intFrame);
  if intFrame>=numFrames then
   if loop then begin
    intFrame:=0;
    a:=0;
   end else
    intFrame:=numFrames-1;
  while (a<=high(keyFrames)) and (keyFrames[a].frame=intFrame) do
   with keyFrames[a] do begin
    b:=boneIdx;
    if bones[b].flags and bfCurrentPos=0 then // bone has values
     case prop of
      bpPosition:begin
       VectMult(bones[b].pos,1-fracFrame);
       VectAdd(bones[b].pos,VecMult(value.xyz,fracFrame));
      end;
      bpRotation:begin
       bones[b].rot:=QInterpolate(bones[b].rot,value,fracFrame);
      end;
      bpScale:begin
       VectMult(bones[b].scale,1-fracFrame);
       VectAdd(bones[b].scale,VecMult(value.xyz,fracFrame));
      end;
     end;
    inc(a);
   end;
 end;
 curFrame:=frame;}
end;

procedure TModel3D.AnimateBones;
 var
  time:int64;
  i:integer;
  frame:single;
 begin
{  time:=MyTickCount;
  for i:=0 to high(animations) do
   if animations[i].playing then begin
    frame:=fps*(time-animations[i].startTime)/1000;
    if not animations[i].smooth then frame:=round(frame);
    if animations[i].loop then
     frame:=frac(frame)+(trunc(frame) mod animations[i].numFrames)
    else
     if frame>=animations[i].numFrames then animations[i].playing:=false;
    if animations[i].curFrame<>frame then
     animations[i].UpdateBonesForFrame(bones,frame);
   end;
  UpdateBoneMatrices(true);  }
 end;

{ TModel3D }

procedure TModel3D.CalcBoneMatrix(bone:integer);
 var
  mat,mScale,mTemp:TMatrix4s;
  parent:integer;
 begin
   if not IsNAN(bones[bone].matrix[0,0]) then exit; // already calculated
   parent:=bones[bone].parent;
   // recursion
   if parent>=0 then begin
    if IsNaN(bones[parent].matrix[0,0]) then
     CalcBoneMatrix(parent);
   end;
   MatrixFromQuaternion(bones[bone].rotation,mat);
   if not IsIdentity(bones[bone].scale) then
    with bones[bone] do begin
     mScale:=IdentMatrix4s;
     mScale[0,0]:=scale.x;
     mScale[1,1]:=scale.y;
     mScale[2,2]:=scale.z;
     mTemp:=mat;
     MultMat(mScale,mTemp,mat);
    end;
   move(bones[bone].position,mat[3],sizeof(TPoint3s));
   // Combine with parent bone
   if parent>=0 then
    MultMat(mat,bones[parent].matrix,bones[bone].matrix)
   else
    bones[bone].matrix:=mat;
 end;

constructor TModel3D.Create(name:string;src:string='');
 begin
  inherited Create;
  self.name:=name;
  self.src:=src;
 end;

function TModel3D.CreateInstance:TModelInstance;
 begin
  result:=TModelInstance.Create(self);
 end;

procedure TModel3D.FillVertexBuffer(data: pointer; vrtCount, stride:integer; useBones:boolean;
  vpOffset,vtOffset,vt2Offset,vnOffset,vcOffset: integer);
 var
  i:integer;
  vpp,vtp,vcp,vnp:PByte;
 procedure StorePos(index:integer;dest:PByte;transform:boolean);
  var
   p1,p2:TPoint3s;
  begin
(*   if transform then begin // ����� ��������������
    p1:=vp[i];
    if vb[i].weight1>0 then begin
     MultPnt(bones[vb[i].bone1].combined,@p1,1,0);
     VectMult(p1,vb[i].weight1/255);
    end;
    if vb[i].weight2>0 then begin
     p2:=vp[i];
     MultPnt(bones[vb[i].bone2].combined,@p2,1,0);
     VectMult(p2,vb[i].weight2/255);
     VectAdd(p1,p2);
    end;
    move(p1,dest^,sizeof(TPoint3s))
   end else
    move(vp[i],dest^,sizeof(TPoint3s))   *)
  end;

 begin
  if vpOffset>=0 then vpp:=PByte(PtrUInt(data)+vpOffset)
   else vpp:=nil;
  if vtOffset>=0 then vtp:=PByte(PtrUInt(data)+vtOffset)
   else vtp:=nil;
  if vcOffset>=0 then vcp:=PByte(PtrUInt(data)+vcOffset)
   else vcp:=nil;
  if vnOffset>=0 then vnp:=PByte(PtrUInt(data)+vnOffset)
   else vnp:=nil;

  if vpp<>nil then
   for i:=0 to vrtCount-1 do begin
    // Position
    if vp<>nil then StorePos(i,vpp,useBones)
     else fillchar(vpp^,sizeof(TPoint3s),0);
    inc(vpp,stride);
   end;

  // Normal
  if vnp<>nil then
   for i:=0 to vrtCount-1 do begin
    if vn<>nil then move(vn[i],vnp^,sizeof(TPoint3s))
     else fillchar(vnp^,sizeof(TPoint3s),0);
    inc(vnp,stride);
   end;

  // Texture coords
  if vtp<>nil then
   for i:=0 to vrtCount-1 do begin
    if vt<>nil then move(vt[i],vtp^,sizeof(TPoint2s))
     else fillchar(vtp^,sizeof(TPoint2s),0);
    inc(vtp,stride);
   end;

  // Color
  if vcp<>nil then
   for i:=0 to vrtCount-1 do begin
    if vc<>nil then move(vc[i],vcp^,4)
     else move(defaultColor,vcp^,4);
    inc(vcp,stride);
   end;

  ASSERT((vt2Offset<0),'Not yet implemented');
 end;

function TModel3D.FindBone(bName:string):integer;
 var
  i:integer;
 begin
  if bonesHash.count<>length(bones) then begin
   bonesHash.Init(length(bones));
   for i:=0 to high(bones) do
    bonesHash.Put(bones[i].boneName,i);
  end;
  result:=bonesHash.Get(bName);
 end;

procedure TModel3D.FlipX;
 var
  i,j:integer;
 begin
  // vertices
  for i:=0 to high(vp) do vp[i].x:=-vp[i].x;
  for i:=0 to high(vn) do vn[i].x:=-vn[i].x;
  // bones
  for i:=0 to high(bones) do begin
   bones[i].position.x:=-bones[i].position.x;
   bones[i].rotation.x:=-bones[i].rotation.x;
  end;
  // animations
  for i:=0 to high(animations) do
   for j:=0 to high(animations[i].keyFrames) do
    with animations[i].keyFrames[j] do
     if prop in [bpPosition,bpRotation] then value.x:=-value.x;
 end;


procedure TModel3D.Prepare;
 var
  mTemp:TMatrix4s;
  i:integer;
 begin
  for i:=0 to high(bones) do
   bones[i].matrix[0,0]:=NaN;
  // Calculate "bone->world" matrices
  for i:=0 to high(bones) do
   CalcBoneMatrix(i);
  // Invert bone matrices to get "world->bone" matrix
  for i:=0 to high(bones) do begin
   mTemp:=bones[i].matrix;
   InvertFull(mTemp,bones[i].matrix);
  end;

  // Build animation timelines
  for i:=0 to high(animations) do
   animations[i].BuildTimeline(self);
 end;

{ TModelInstance }

constructor TModelInstance.Create(model:TModel3D);
 var
  i:integer;
 begin
  self.model:=model;
  SetLength(animations,length(model.animations));
  for i:=0 to high(animations) do begin
   animations[i].weight.Init;
  end;
 end;

procedure TModelInstance.Draw(tex:TTexture);
 begin
  FillVertexBuffer;
  gfx.draw.IndexedMesh(@vertices[0],@model.trgList[0],length(model.trgList),length(vertices),tex);
 end;

function BlendVec(const vec:TVector3s;const m1,m2:TMatrix4s;weight1,weight2:byte):TVector3s;
 var
  tmp,src:TVector4s;
 begin
  if weight1+weight2>0 then begin
   ZeroMem(tmp,sizeof(tmp));
   src:=Vector4s(vec);
   if weight1>0 then begin
    MultPnt(m1,@src,1,0);
    tmp.Add(src,weight1/255);
   end;
   if weight2>0 then begin
    src:=Vector4s(vec);
    MultPnt(m2,@src,1,0);
    tmp.Add(src,weight2/255);
   end;
   move(tmp,result,sizeof(result));
  end else
   result:=vec;
 end;

procedure TModelInstance.FillVertexBuffer;
 var
  v1,v2:TVector4s;
  i,vCount:integer;
  rigged:boolean;
  binding:TVertexBinding;
 begin
  vCount:=length(model.vp);
  if length(vertices)<>vCount then begin
   SetLength(vertices,vCount);
   dirty:=true;
   // Texture coordinates
   if length(model.vt)=vCount then
    for i:=0 to vCount-1 do
     vertices[i].SetUV(model.vt[i]);
   // Vertex colors
   if length(model.vc)=vCount then
    for i:=0 to vCount-1 do
     vertices[i].color:=model.vc[i]
   else
    for i:=0 to vCount-1 do
     vertices[i].color:=$FFFFFFFF;
  end;
  if not dirty then exit;

  rigged:=(length(model.vb)=vCount) and
          (length(model.bones)=length(boneMatrices));
  for i:=0 to vCount-1 do begin
   if rigged then begin
    binding:=model.vb[i];
    with binding do begin
     vertices[i].SetPos(BlendVec(model.vp[i],
      boneMatrices[bone1].combined,
      boneMatrices[bone2].combined,
      weight1,weight2));

     vertices[i].SetNormal(BlendVec(model.vn[i],
      boneMatrices[bone1].combined,
      boneMatrices[bone2].combined,
      weight1,weight2));
    end;
   end else begin
    vertices[i].SetPos(model.vp[i]);
    vertices[i].SetNormal(model.vn[i]);
   end;
  end;
  dirty:=false;
 end;

function TModelInstance.FindAnimation(name:string):integer;
 var
  i:integer;
 begin
  for i:=0 to high(model.animations) do
   if (name='') or SameText(name,model.animations[i].name) then
    exit(i);
  raise EWarning.Create('Animation "%s" not found in model "%s"',[name,model.name]);
 end;

procedure TModelInstance.PlayAnimation(name:string;easeTimeMS:integer);
 begin
  with animations[FindAnimation(name)] do begin
    playing:=true;
    stopping:=false;
    paused:=false;
    curFrame:=0;
    startTime:=MyTickCount;
    weight.Animate(1,easeTimeMS);
   end;
 end;

procedure TModelInstance.PauseAnimation(name:string);
 begin
  animations[FindAnimation(name)].paused:=true;
 end;

procedure TModelInstance.ResumeAnimation(name:string);
 begin
  animations[FindAnimation(name)].paused:=false;
 end;

procedure TModelInstance.SetAnimationPos(name:string;frame:integer);
 var
  i,max:integer;
 begin
  i:=FindAnimation(name);
  with animations[i] do begin
   playing:=true;
   stopping:=false;
   weight.Assign(1);
   paused:=true;
   max:=model.animations[i].numFrames-1;
   if frame>=0 then
    curFrame:=Clamp(frame,0,max)
   else
    curFrame:=Clamp(max-frame,0,max);
  end;
 end;

procedure TModelInstance.StopAnimation(name:string;easeTimeMS:integer);
 begin
  with animations[FindAnimation(name)] do begin
   stopping:=true;
   weight.Animate(0,easeTimeMS);
  end;
 end;

procedure TModelInstance.Update;
 var
  time:integer;
 begin
  if lastUpdated>0 then
   time:=game.frameStartTime-lastUpdated
  else
   time:=-1;
  lastUpdated:=game.frameStartTime;

  dirty:=AdvanceAnimations(time);
  UpdateBones;
  UpdateBoneMatrices;
 end;

function TModelInstance.AdvanceAnimations(time:integer):boolean;
 var
  i,t,loop:integer;
  oldFrame:integer;
 begin
  result:=false;
  for i:=0 to high(animations) do
   with animations[i] do
    if playing and not paused then begin
     t:=time;
     if t<0 then t:=game.frameStartTime-startTime;
     oldFrame:=round(curFrame);
     curFrame:=curFrame+t*model.animations[i].fps/1000;
     loop:=model.animations[i].loopTo;
     if (loop>0) and not stopping then
      while curFrame>loop do
       curFrame:=curFrame-(loop-model.animations[i].loopFrom+1);
     if curFrame>model.animations[i].numFrames-1 then begin
      playing:=false;
      curFrame:=model.animations[i].numFrames-1;
     end;
     if model.animations[i].smooth or
        (round(curFrame)<>oldFrame) then result:=true;
    end;
 end;

//
procedure TModelInstance.UpdateBones;
 var
  i,j,bCount,anim:integer;
  fullWeight,frame:single;
  aCount:integer; // number of active animations
  aIdx:array[0..5] of integer;
  weights:array[0..5] of single; // max 6 active animations
  vec:TVector4s;
 begin
  // Find active animations and calculate weights
  fullWeight:=0;
  aCount:=0;
  for i:=0 to high(animations) do begin
   if animations[i].playing then begin
    aIdx[aCount]:=i;
    weights[aCount]:=animations[i].weight.ValueAt(game.frameStartTime);
    fullWeight:=fullWeight+weights[aCount];
    inc(aCount);
    if aCount>=length(aIdx) then break;
   end
  end;
  if aCount=0 then exit; // no active animations
  // Normalize weights
  for i:=0 to aCount-1 do
   weights[i]:=weights[i]/fullWeight;
  // Prepare bones array
  bCount:=length(model.bones);
  if length(bones)<>bCount then
   SetLength(bones,bCount);
  ZeroMem(bones[0],sizeof(bones[0])*bCount);
  // Calculate bones
  for i:=0 to bCount-1 do begin
   for j:=0 to aCount-1 do begin
    anim:=aIdx[j];
    frame:=animations[anim].curFrame;
    // position
    vec:=model.animations[anim].GetBonePosition(i,frame);
    bones[i].position.Add(vec,weights[j]);
    // rotation
    vec:=model.animations[anim].GetBoneRotation(i,frame);
    bones[i].rotation.Add(vec,weights[j]);
    // scale
    vec:=model.animations[anim].GetBoneScale(i,frame);
    bones[i].scale.Add(vec,weights[j]);
   end;
   if aCount>1 then bones[i].rotation.Normalize; // sum of multiple rotations
  end;
 end;

procedure TModelInstance.UpdateBoneMatrices;
 procedure CalculateBoneMatrix(bone:integer);
  var
   mat,mScale,mTemp:TMatrix4s;
   parent:integer;
  begin
   if not IsNAN(boneMatrices[bone].toModel[0,0]) then exit; // already calculated
   parent:=model.bones[bone].parent;
   // recursion
   if parent>=0 then begin
    if IsNaN(boneMatrices[parent].toModel[0,0]) then
     CalculateBoneMatrix(parent);
   end;
   MatrixFromQuaternion(bones[bone].rotation,mat);
   if not IsIdentity(bones[bone].scale.xyz) then
    with bones[bone] do begin
     mScale:=IdentMatrix4s;
     mScale[0,0]:=scale.x;
     mScale[1,1]:=scale.y;
     mScale[2,2]:=scale.z;
     mTemp:=mat;
     MultMat(mScale,mTemp,mat); // TODO: !проверить порядок!
    end;
   move(bones[bone].position.xyz,mat[3],sizeof(TPoint3s));
   // Искомая матрица получается как цепочка преобразований:
   // из дефолтной позиции (1)-> в пространство кости (2)-> в пространство кости-предка (3)-> в мировые к-ты
   // матрица (1) постоянна и вычислена заранее - это model.bones[bone].matrix
   // матрица (2) вычислена здесь - это mat
   // матрица (3) вычислена в процессе рекурсии
   // Combine with parent bone
   if parent>=0 then
    MultMat(mat,boneMatrices[parent].toModel,boneMatrices[bone].toModel)
   else
    boneMatrices[bone].toModel:=mat;
   // Combine with
   with bones[bone] do begin
    MultMat(model.bones[bone].matrix,boneMatrices[bone].toModel,boneMatrices[bone].combined);
   end;
  end;

 var
  i,n:integer;
 begin
  n:=length(bones);
  if n=0 then exit;
  if length(boneMatrices)<>n then SetLength(boneMatrices,n);
  for i:=0 to n-1 do
   boneMatrices[i].toModel[0,0]:=NaN;
  for i:=0 to n-1 do
   CalculateBoneMatrix(i);
 end;


end.
