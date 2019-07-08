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
  vt,vt2:array of TPoint2s; // texture coords (up to 2 sets)
  vn:array of TVector3s;    // vertex normals (optional)
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

  // Negative offset -> don't fill data
  procedure FillVertexBuffer(data:pointer;vrtCount, stride:integer;
    vpOffset,vp2Offset,vtOffset,vt2Offset,vnOffset,vn2Offset,vcOffset:integer);

 end;

implementation
 uses CrossPlatform;

 const
  defaultColor:cardinal=$FF808080;


{ TModel3D }
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

end.
