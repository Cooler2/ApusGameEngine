// Class for 3D model with skeletal (rigged) animation
//
// Copyright (C) 2019 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
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
  partName,materialName:string;
  firstTrg,trgCount:integer;
  firstVrt,vrtCount:integer;
 end;

 // Definition of bone
 TBone=record
  boneName:string;
  parent:integer; // index of the parent bone
  pos:TPoint3s;
  scale:Tvector3s;
  rot:TQuaternionS;
  flags:cardinal;
  currentPos:TMatrix43s; // bone space -> model space
  defaultPos:TMatrix43s; // model space -> bone space
 end;

 // Animation timeline is a big table [bone_property,frame]
 // This record (20 bytes) stores one cell of this table
 // Sorted by frame,boneIdx
 TAnimationValue=packed record
  frame:word;
  boneIdx:byte; // bone index
  prop:byte;    // which bone property is affected (position, rotation or scale)
  w,x,y,z:single;
 end;

 TAnimation=record
  animationName:string;
  values:array of TAnimationValue;
 end;

 TBoneWeight=packed record
  bone1,bone2:byte;
  weight1,weight2:byte;
 end;

 // 3D model with rigged animation support
 TModel3D=class
  // Vertex data (no more than 64K vertices!)
  vp,vp2:array of TPoint3s; // vertex positions (up to 2 sets for 2 bones)
  vn,vn2:array of TVector3s;    // vertex normals (optional)
  vt,vt2:array of TPoint2s; // texture coords (up to 2 sets)
  vc:array of cardinal;     // vertex colors (optional)
  vb:array of TBoneWeight;  // Weights and indices (max 2 bones supported per vertex)
  // Surface data
  trgList:array of word;    // List of triangles
  parts:array of TModelPart;  // Model may contain multiple parts
  // Bones
  bones:array of TBone;
  // Animation clips
  animations:array of TAnimation;

  // External references
  shaderName,texName,texName2:string;

  // Flip model along X axis (right\left CS conversion)
  procedure FlipX;

  // Build vertex data buffer (non-animated data)
  // Negative offset -> don't fill data
  procedure FillVertexBuffer(data:pointer;vrtCount, stride:integer;
    vpOffset,vp2Offset,vtOffset,vt2Offset,vnOffset,vn2Offset,vcOffset:integer);

  // Calculate bone matrices: forwardOnly - don't calc inverse matrices (Model->Bone), just only Bone->Model
  procedure UpdateBoneMatrices(forwardOnly:boolean=false);
  // Transform vertex position coordinates from global CS to their bones CS
  procedure ConvertToBoneSpace;
  //procedure PrepareForAnimation;
 end;

implementation
 uses CrossPlatform;

 const
  defaultColor:cardinal=$FF808080;


{ TModel3D }
procedure TModel3D.UpdateBoneMatrices(forwardOnly:boolean=false);
 var
  i:integer;
 procedure CalculateBoneMatrices(index,flags:integer);
  var
   p:integer;
   mat,mScale,mTmp:TMatrix43s;
   m3:TMatrix3s absolute mat;
  begin
   p:=bones[index].parent;
   // recursion
   if p>=0 then begin
    if bones[p].flags and flags<>flags then
     CalculateBoneMatrices(p,flags);
   end;
   MatrixFromQuaternion(bones[index].rot,m3);
   if not IsIdentity(bones[index].scale) then
    with bones[index].scale do begin
     mScale:=IdentMatrix43s;
     mScale[0,0]:=x;
     mScale[1,1]:=y;
     mScale[2,2]:=z;
     mTmp:=mat;
     MultMat4(mScale,mTmp,mat);
    end;
   move(bones[index].pos,mat[3],sizeof(TPoint3s));
   if p>=0 then
    MultMat4(bones[p].currentPos,mat,bones[index].currentPos)
   else
    bones[index].currentPos:=mat;
   if flags and bfDefaultPos>0 then begin
    Invert4(bones[index].currentPos,bones[index].defaultPos);
    {$IFDEF DEBUG}
    // verify
    MultMat4(bones[index].currentPos,bones[index].defaultPos,mat);
    //ASSERT(IsIdentity(mat));
    {$ENDIF}
   end;
   bones[index].flags:=bones[index].flags or flags;
  end;
 begin
  // Clear flags
  for i:=0 to high(bones) do
   bones[i].flags:=bones[i].flags and ($FFFFFFFF-bfDefaultPos-bfCurrentPos);

  for i:=0 to high(bones) do
   CalculateBoneMatrices(i,bfCurrentPos+bfDefaultPos*byte(not forwardOnly));

 end;

procedure TModel3D.ConvertToBoneSpace;
 var
  i,bone:integer;
  p:TPoint3s;
 begin
  ASSERT(length(vb)=length(vp));
  for i:=0 to high(vp) do begin
   if vb[i].weight2>0 then begin
    if vp2=nil then SetLength(vp2,length(vp));
    vp2[i]:=vp[i];
    bone:=vb[i].bone2;
    MultPnt4(bones[bone].defaultPos,@vp2[i],1,0);
   end;
   bone:=vb[i].bone1;
   MultPnt4(bones[bone].defaultPos,@vp[i],1,0);
  end;

 end;


procedure TModel3D.FillVertexBuffer(data: pointer; vrtCount, stride, vpOffset,
  vp2Offset, vtOffset, vt2Offset, vnOffset, vn2Offset, vcOffset: integer);
 var
  i:integer;
  vpp,vtp,vcp,vnp:PByte;
 begin
  if vpOffset>=0 then vpp:=PByte(PtrUInt(data)+vpOffset)
   else vpp:=nil;
  if vtOffset>=0 then vtp:=PByte(PtrUInt(data)+vtOffset)
   else vtp:=nil;
  if vcOffset>=0 then vcp:=PByte(PtrUInt(data)+vcOffset)
   else vcp:=nil;
  if vnOffset>=0 then vnp:=PByte(PtrUInt(data)+vnOffset)
   else vnp:=nil;

  for i:=0 to vrtCount-1 do begin
   // Position
   if vpp<>nil then begin
    if vp<>nil then move(vp[i],vpp^,sizeof(TPoint3s))
     else fillchar(vpp^,sizeof(TPoint3s),0);
    inc(vpp,stride);
   end;
   // Texture coords
   if vtp<>nil then begin
    if vt<>nil then move(vt[i],vtp^,sizeof(TPoint2s))
     else fillchar(vtp^,sizeof(TPoint2s),0);
    inc(vtp,stride);
   end;
   // Color
   if vcp<>nil then begin
    if vc<>nil then move(vc[i],vcp^,4)
     else move(defaultColor,vcp^,4);
    inc(vcp,stride);
   end;
   // Normal
   if vnp<>nil then begin
    if vn<>nil then move(vn[i],vnp^,sizeof(TPoint3s))
     else fillchar(vnp^,sizeof(TPoint3s),0);
    inc(vnp,stride);
   end;
   ASSERT((vp2Offset<0) and (vt2Offset<0) and (vn2Offset<0),'Not yet implemented');
  end;

 end;

procedure TModel3D.FlipX;
 var
  i,j:integer;
 begin
  // vertices
  for i:=0 to high(vp) do vp[i].x:=-vp[i].x;
  for i:=0 to high(vp2) do vp2[i].x:=-vp2[i].x;
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
 end;

end.
