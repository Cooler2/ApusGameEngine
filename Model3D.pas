// Class for 3D model with skeletal (rigged) animation
//
// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Model3D;
interface
uses MyServis,geom2D,geom3D;
const
 // 3D properties
 propPosition = 1;
 propRotation = 2; // Normalized quaternion
 propScale    = 3;

 // Bone flags
 bfDefaultPos = 1; // default matrix updated (model->bone)
 bfCurrentPos = 2; // current matrix updated (bone->model)

type
 // Vertex for a typical 3D mesh
 T3DModelVertex=record
  x,y,z:single;
  color:cardinal;
  nX,nY,nZ:single;
  attr:cardinal;
  u,v:single;
 end;

 // Part of mesh surface
 TModelPart=record
  partName,materialName:AnsiString;
  firstTrg,trgCount:integer;  // triangles of the part
  firstVrt,vrtCount:integer;  // vertices used in the part (may also conatain other vertices)
 end;

 // Definition of bone
 TBone=record
  boneName:string;
  parent:integer; // index of the parent bone
  pos:TPoint3s;
  scale:Tvector3s;
  rot:TQuaternionS;
  flags:cardinal;        // bfXXX
  defaultPos:TMatrix43s; // model space -> bone space (in reference position)
  currentPos:TMatrix43s; // bone space (in current position) -> model space
  combined:TMatrix43s;  // Combined transform: defaultPos * currentPos
 end;
 TBonesArray=array of TBone;

 // Animation timeline is a big table [bone_property,frame]
 // This record (20 bytes) stores one cell of this table
 // Sorted by frame,boneIdx
 TAnimationValue=packed record
  frame:word;
  boneIdx:byte; // bone index
  prop:byte;    // which bone property is affected (position, rotation or scale)
  w,x,y,z:single;
 end;
 TAnimationValues=array of TAnimationValue;

 TAnimation=record
  animationName:string;
  values:TAnimationValues;
  numFrames:integer;
  loop:boolean; // play infinitely
  smooth:boolean; // play smoothly - interpolate between animation frames (only when key data exists for neighboring frames)
  playing:boolean; // is it playing now?
  curFrame:single; // current playback position
  startTime:int64; // when animation playback was started
  procedure UpdateBonesForFrame(const bones:TBonesArray;frame:single);
 end;

 TBoneWeight=packed record
  bone1,bone2:byte;
  weight1,weight2:byte;
 end;

 // 3D model with rigged animation support
 TModel3D=class
  // Vertex data (no more than 64K vertices!)
  vp:array of TPoint3s;  // vertex positions
  vn:array of TVector3s; // vertex normals (optional)
  vt,vt2:array of TPoint2s; // texture coords (up to 2 sets, optional)
  vc:array of cardinal;     // vertex colors (optional)
  vb:array of TBoneWeight;  // Weights and indices (max 2 bones supported per vertex)
  // Surface data
  trgList:array of word;    // List of triangles
  parts:array of TModelPart;  // Model may contain multiple parts
  // Bones
  bones:TBonesArray;
  // Animation clips
  animations:array of TAnimation;

  // External references
  shaderName,texName,texName2:string;

  fps:single;

  // Flip model along X axis (right\left CS conversion)
  procedure FlipX;

  // Build vertex data buffer. Transformed=true - apply bone matrices and weights to vertex positions and normals
  // Negative offset -> don't fill data
  procedure FillVertexBuffer(data:pointer;vrtCount,stride:integer; useBones:boolean;
    vpOffset,vtOffset,vt2Offset,vnOffset,vcOffset:integer);

  // Calculate bone matrices: forwardOnly - don't calc inverse matrices (Model->Bone), just only Bone->Model
  procedure UpdateBoneMatrices(forwardOnly:boolean=false);

  //
  procedure PlayAnimation(name:string='');
  procedure StopAnimation(name:string='');
  // Update bones: values and matrices
  procedure AnimateBones;
 end;

implementation
 uses CrossPlatform,SysUtils;

 const
  defaultColor:cardinal=$FF808080;


{ TModel3D }
procedure TModel3D.UpdateBoneMatrices(forwardOnly:boolean=false);
 var
  i:integer;
 procedure CalculateBoneMatrices(index,newFlags:integer);
  var
   p:integer;
   mat,mScale,mTmp:TMatrix43s;
   m3:TMatrix3s absolute mat;
  begin
   if bones[index].flags and newFlags=newFlags then exit; // nothing to do
   p:=bones[index].parent;
   // recursion
   if p>=0 then begin
    if bones[p].flags and newFlags<>newFlags then
     CalculateBoneMatrices(p,newFlags);
   end;
   MatrixFromQuaternion(bones[index].rot,m3);
   if not IsIdentity(bones[index].scale) then
    with bones[index].scale do begin
     mScale:=IdentMatrix43s;
     mScale[0,0]:=x;
     mScale[1,1]:=y;
     mScale[2,2]:=z;
     mTmp:=mat;
     MultMat4(mTmp,mScale,mat);
    end;
   move(bones[index].pos,mat[3],sizeof(TPoint3s));
   if p>=0 then
    MultMat4(mat,bones[p].currentPos,bones[index].currentPos)
   else
    bones[index].currentPos:=mat;
   if newFlags and bfDefaultPos>0 then begin
    Invert4(bones[index].currentPos,bones[index].defaultPos);
    {$IFDEF DEBUG}
    // verify
    MultMat4(bones[index].currentPos,bones[index].defaultPos,mat);
    //ASSERT(IsIdentity(mat));
    {$ENDIF}
   end;
   with bones[index] do begin
    MultMat4(defaultPos,currentPos,combined);
    //combined:=currentPos;
    flags:=flags or newFlags;
   end;
  end;
 begin
  // Clear flags
{  for i:=0 to high(bones) do
   bones[i].flags:=bones[i].flags and ($FFFFFFFF-bfDefaultPos-bfCurrentPos);}

  for i:=0 to high(bones) do
   CalculateBoneMatrices(i,bfCurrentPos+bfDefaultPos*byte(not forwardOnly));
 end;

{ TAnimation }

procedure TAnimation.UpdateBonesForFrame(const bones: TBonesArray; frame: single);
var
 a,b,i:integer;
 intFrame:integer;
 blend:single;
begin
 if values=nil then exit;
 if not smooth then begin
  intFrame:=Sat(round(frame),0,numFrames-1);
  blend:=0;
 end else begin
  intFrame:=Sat(trunc(frame),0,numFrames-1);
  blend:=frac(frame);
 end;
 // seek frame 1
 a:=0; b:=high(values);
 repeat
  i:=(a+b+1) div 2;
  if values[i].frame<intFrame then a:=i else b:=i;
 until a>=b-1;
 while (a<high(values)) and (values[a].frame<intFrame) do inc(a);
 while (a<=high(values)) and (values[a].frame=intFrame) do
  with values[a] do begin
   b:=boneIdx;
   case prop of
    propPosition:bones[b].pos:=Point3s(x,y,z);
    propRotation:bones[b].rot:=Quaternion(x,y,z,w);
    propScale:bones[b].scale:=Point3s(x,y,z);
   end;
   bones[b].flags:=bones[b].flags and (not bfCurrentPos);
   inc(a);
  end;

 // Smooth?
 if blend>0 then begin
  inc(intFrame);
  if intFrame>=numFrames then
   if loop then begin
    intFrame:=0;
    a:=0;
   end else
    intFrame:=numFrames-1;
  while (a<=high(values)) and (values[a].frame=intFrame) do
   with values[a] do begin
    b:=boneIdx;
    if bones[b].flags and bfCurrentPos=0 then // bone has values
     case prop of
      propPosition:begin
       VectMult(bones[b].pos,1-blend);
       VectAdd3(bones[b].pos,Vect3Mult(Point3s(x,y,z),blend));
      end;
      propRotation:begin
       bones[b].rot:=QInterpolate(bones[b].rot,Quaternion(x,y,z,w),blend);
      end;
      propScale:begin
       VectMult(bones[b].scale,1-blend);
       VectAdd3(bones[b].scale,Vect3Mult(Point3s(x,y,z),blend));
      end;
     end;
    inc(a);
   end;
 end;
 curFrame:=frame;
end;

procedure TModel3D.AnimateBones;
 var
  time:int64;
  i:integer;
  frame:single;
 begin
  time:=MyTickCount;
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
  UpdateBoneMatrices(true);
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
   if transform then begin // Можно оптимизировать
    p1:=vp[i];
    if vb[i].weight1>0 then begin
     MultPnt4(bones[vb[i].bone1].combined,@p1,1,0);
     VectMult(p1,vb[i].weight1/255);
    end;
    if vb[i].weight2>0 then begin
     p2:=vp[i];
     MultPnt4(bones[vb[i].bone2].combined,@p2,1,0);
     VectMult(p2,vb[i].weight2/255);
     VectAdd3(p1,p2);
    end;
    move(p1,dest^,sizeof(TPoint3s))
   end else
    move(vp[i],dest^,sizeof(TPoint3s))
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

procedure TModel3D.FlipX;
 var
  i,j:integer;
 begin
  // vertices
  for i:=0 to high(vp) do vp[i].x:=-vp[i].x;
  for i:=0 to high(vn) do vn[i].x:=-vn[i].x;
  // bones
  for i:=0 to high(bones) do begin
   bones[i].pos.x:=-bones[i].pos.x;
   bones[i].rot.x:=-bones[i].rot.x;
  end;
  // animations
  for i:=0 to high(animations) do
   for j:=0 to high(animations[i].values) do
    with animations[i].values[j] do
     if prop in [propPosition,propRotation] then x:=-x;

  // TODO: flip bones and animations
 end;

procedure TModel3D.PlayAnimation(name: string);
var
 i:integer;
begin
 for i:=0 to high(animations) do
  if (name='') or (SameText(name,animations[i].animationName)) then begin
   animations[i].playing:=true;
   animations[i].startTime:=MyTickCount;
   animations[i].curFrame:=-1;
   exit;
  end;
end;

procedure TModel3D.StopAnimation(name: string);
var
 i:integer;
begin
 for i:=0 to high(animations) do
  if (name='') or (SameText(name,animations[i].animationName)) then begin
   animations[i].playing:=false;
   exit;
  end;
end;

end.
