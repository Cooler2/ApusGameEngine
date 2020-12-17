// Import module for InterQuakeModel format (IQM/IQE)

// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

{$R+}
unit Apus.Engine.IQMloader;
interface
uses Apus.Engine.Model3D;

 function Load3DModelIQM(fname:string):TModel3D;
 function Load3DModelIQE(fname:string):TModel3D;

implementation
 uses MyServis,SysUtils;

 type
  TMagicLine=array[0..15] of AnsiChar;
  TIQMHeader=packed record
   magic:TMagicLine;
   version:cardinal;
   filesize,flags:cardinal;
   num_text,ofs_text:cardinal;
   num_meshes,ofs_meshes:cardinal;
   num_vertexarrays, num_vertexes, ofs_vertexarrays:cardinal;
   num_triangles, ofs_triangles, ofs_adjacency:cardinal;
   num_joints, ofs_joints:cardinal;
   num_poses, ofs_poses:cardinal;
   num_anims, ofs_anims:cardinal;
   num_frames, num_framechannels, ofs_frames, ofs_bounds:cardinal;
   num_comment, ofs_comment:cardinal;
   num_extensions, ofs_extensions:cardinal; // these are stored as a linked list, not as a contiguous array
  end;

  TIQMMesh=record
   name:cardinal;     // unique name for the mesh, if desired
   material:cardinal; // set to a name of a non-unique material or texture
   first_vertex, num_vertexes:cardinal;
   first_triangle, num_triangles:cardinal;
  end;

  TIQMVertexArray=record
   vatype:cardinal;   // type or custom name
   flags:cardinal;
   format:cardinal; // component format
   size:cardinal;   // number of components
   offset:cardinal; // offset to array of tightly packed components, with num_vertexes * size total entries
                    // offset must be aligned to max(sizeof(format), 4)
  end;

  TIQMTriangle=record
   vertex:array[0..2] of cardinal;
  end;

  TIQMJoint=record
    name:cardinal;
    parent:integer; // parent < 0 means this is a root bone
    translate:array[0..2] of single;
    rotate:array[0..3] of single;
    scale:array[0..2] of single;
    // translate is translation <Tx, Ty, Tz>, and rotate is quaternion rotation <Qx, Qy, Qz, Qw>
    // rotation is in relative/parent local space
    // scale is pre-scaling <Sx, Sy, Sz>
    // output = (input*scale)*rotation + translation
  end;

 TIQMPose=record
    parent:integer; // parent < 0 means this is a root bone
    channelmask:cardinal; // mask of which 10 channels are present for this joint pose
    channeloffset,channelscale:array[0..9] of single;
    // channels 0..2 are translation <Tx, Ty, Tz> and channels 3..6 are quaternion rotation <Qx, Qy, Qz, Qw>
    // rotation is in relative/parent local space
    // channels 7..9 are scale <Sx, Sy, Sz>
    // output = (input*scale)*rotation + translation
 end;

 TIQMAnim=record
  name:cardinal;
  first_frame,num_frames:cardinal;
  framerate:single;
  flags:cardinal;
 end;


 const
  MAGIC:TMagicLine = ('I','N','T','E','R','Q','U','A','K','E','M','O','D','E','L',#0);

  // all vertex array entries must ordered as defined below, if present
  // i.e. position comes before normal comes before ... comes before custom
  // where a format and size is given, this means models intended for portable use should use these
  // an IQM implementation is not required to honor any other format/size than those recommended
  // however, it may support other format/size combinations for these types if it desires
  IQM_POSITION     = 0;  // float, 3
  IQM_TEXCOORD     = 1;  // float, 2
  IQM_NORMAL       = 2;  // float, 3
  IQM_TANGENT      = 3;  // float, 4
  IQM_BLENDINDEXES = 4;  // ubyte, 4
  IQM_BLENDWEIGHTS = 5;  // ubyte, 4
  IQM_COLOR        = 6;  // ubyte, 4
  // all values up to IQM_CUSTOM are reserved for future use
  // any value >= IQM_CUSTOM is interpreted as CUSTOM type
  // the value then defines an offset into the string table, where offset = value - IQM_CUSTOM
  // this must be a valid string naming the type
  IQM_CUSTOM       = $10;

  // vertex array format
  IQM_BYTE   = 0;
  IQM_UBYTE  = 1;
  IQM_SHORT  = 2;
  IQM_USHORT = 3;
  IQM_INT    = 4;
  IQM_UINT   = 5;
  IQM_HALF   = 6;
  IQM_FLOAT  = 7;
  IQM_DOUBLE = 8;

 function Load3DModelIQM(fname:string):TModel3D;
  var
   model:TModel3D;
   data:ByteArray;
   header:^TIQMHeader;
   text:PAnsiChar;
//   strings:AStringArr;
   mesh:^TIQMMesh;
   vertexArray:^TIQMVertexArray;
   joints:^TIQMJoint;
   animations:^TIQMAnim;
   poses:^TIQMPose;
   frames:^word;

  procedure ParseData;
   begin
    // String values
    if header.num_text>0 then begin
     text:=@data[header.ofs_text];
    end;
    // Meshes
    mesh:=nil;
    if header.num_meshes>0 then mesh:=@data[header.ofs_meshes];
    // Vertex arrays
    vertexArray:=nil;
    if header.num_vertexarrays>0 then vertexArray:=@data[header.ofs_vertexarrays];
    // Bones
    joints:=nil;
    if header.num_joints>0 then joints:=@data[header.ofs_joints];
    // Animations
    animations:=nil;
    if header.num_anims>0 then animations:=@data[header.ofs_anims];
    // Poses
    poses:=nil;
    if header.num_poses>0 then poses:=@data[header.ofs_poses];
    // Frames
    frames:=nil;
    if header.num_frames>0 then frames:=@data[header.ofs_frames];
   end;

  function GetString(index:integer):AnsiString;
   var
    st:PAnsiChar;
   begin
    if (index<0) or (index>=header.num_text) then begin
     LogMessage('String index out of bounds!');
     result:='';
     exit;
    end;
    st:=text;
    inc(st,index);
    result:=st;
   end;

  procedure ConvertArray(const va:TIQMVertexArray;dest:PByte;count:integer);
   var
    i:integer;
    sp:PCardinal;
    spf:PSingle;
   begin
    case va.format of
     IQM_BYTE,IQM_UBYTE:move(data[va.offset],dest^,count);
     IQM_INT,IQM_UINT:begin
      sp:=@data[va.offset];
      for i:=0 to count-1 do begin
       dest^:=sp^;
       inc(sp); inc(dest);
      end;
     end;
     IQM_FLOAT:begin
      spf:=@data[va.offset];
      for i:=0 to count-1 do begin
       dest^:=round(255*spf^);
       inc(spf); inc(dest);
      end;
     end;
    end;
   end;

  procedure BuildVertexData;
   var
    i,j,k,count,base:integer;
    bi,bw:array of byte;
    factor:single;
   begin
    for i:=0 to integer(header.num_vertexarrays)-1 do begin
     count:=vertexArray.size*header.num_vertexes; // number of values
     case vertexArray.vatype of
      IQM_POSITION:begin
       ASSERT((vertexArray.format=IQM_FLOAT) AND (vertexArray.size=3),'Invalid vertex array format: position');
       SetLength(model.vp,header.num_vertexes);
       move(data[vertexArray.offset],model.vp[0],count*4);
      end;
      IQM_TEXCOORD:begin
       ASSERT((vertexArray.format=IQM_FLOAT) AND (vertexArray.size=2),'Invalid vertex array format: texCoord');
       SetLength(model.vt,header.num_vertexes);
       move(data[vertexArray.offset],model.vt[0],count*4);
      end;
      IQM_NORMAL:begin
       ASSERT((vertexArray.format=IQM_FLOAT) AND (vertexArray.size=3),'Invalid vertex array format: normal');
       SetLength(model.vn,header.num_vertexes);
       move(data[vertexArray.offset],model.vn[0],count*4);
      end;
      IQM_COLOR:begin
       ASSERT((vertexArray.format=IQM_UBYTE) AND (vertexArray.size=4),'Invalid vertex array format: color');
       SetLength(model.vc,header.num_vertexes);
       move(data[vertexArray.offset],model.vc[0],count);
      end;
      IQM_BLENDINDEXES:begin
       ASSERT((vertexArray.size=4),'Invalid vertex array format: blendIndices');
       SetLength(bi,count);
       ConvertArray(vertexArray^,@bi[0],count);
      end;
      IQM_BLENDWEIGHTS:begin
       ASSERT((vertexArray.size=4),'Invalid vertex array format: blendWeights');
       SetLength(bw,count);
       if vertexArray.vatype=IQM_UINT then vertexArray.vatype:=IQM_FLOAT; // Noesis produces wrong array type, so fix it
       ConvertArray(vertexArray^,@bw[0],count);
      end;
     end;
     inc(vertexArray);
    end;
    // Weights
    if (bw<>nil) and (bi<>nil) then begin
     count:=header.num_vertexes;
     SetLength(model.vb,count);
     for i:=0 to count-1 do begin
      // sort bones by weight
      base:=i*4;
      for j:=0 to 2 do
       for k:=j+1 to 3 do
        if bw[base+k]>bw[base+j] then begin
         Swap(bw[base+k],bw[base+j]);
         Swap(bi[base+k],bi[base+j]);
        end;
      // normalize
      if bw[base]+bw[base+1]=0 then
       with model.vb[i] do begin
        bone1:=0; bone2:=0;
        weight1:=0; weight2:=0; // not affected by any bones
        continue;
       end;
      factor:=255/(bw[base]+bw[base+1]);
      // store
      with model.vb[i] do begin
       bone1:=bi[base];
       bone2:=bi[base+1];
       weight1:=round(bw[base]*factor);
       weight2:=255-weight1;
      end;
     end;
    end;
   end;

  procedure BuildMeshData;
   var
    i,count:integer;
    pc:PCardinal;
   begin
    count:=header.num_triangles;
    SetLength(model.trgList,count*3);
    // Copy trg indices (cardinal -> word)
    pc:=@data[header.ofs_triangles];
    for i:=0 to (count*3)-1 do begin
     model.trgList[i]:=pc^;
     inc(pc);
    end;
    // Create parts
    SetLength(model.parts,header.num_meshes);
    for i:=0 to integer(header.num_meshes)-1 do
     with model.parts[i] do begin
      partName:=GetString(mesh.name);
      materialName:=GetString(mesh.material);
      firstVrt:=mesh.first_vertex;
      vrtCount:=mesh.num_vertexes;
      firstTrg:=mesh.first_triangle;
      trgCount:=mesh.num_triangles;
      inc(mesh);
     end;
   end;

  procedure LoadBones;
   var
    i,count:integer;
   begin
    count:=header.num_joints;
    SetLength(model.bones,count);
    for i:=0 to count-1 do
     with model.bones[i] do begin
      boneName:=GetString(joints.name);
      parent:=joints.parent;
      flags:=0;
      move(joints.translate,pos,sizeof(pos));
      move(joints.rotate,rot,sizeof(rot));
      move(joints.scale,scale,sizeof(scale));
      inc(joints);
     end;
   end;

  procedure LoadAnimations;
   var
    i,j,n,count:integer;
    pose:^TIQMPose;
    frameData:TAnimationValues;
   function Unpack(channelID:integer):single;
    begin
     if pose.channelmask and (1 shl channelID)>0 then begin
      result:=frames^*pose.channelscale[channelID]+pose.channeloffset[channelID];
      inc(frames);
     end else begin
      if channelID<7 then result:=0
       else result:=1;
     end;
    end;
   begin
    // frame data
    count:=header.num_frames*header.num_framechannels;
    SetLength(frameData,count);
    n:=0;
    for i:=0 to integer(header.num_frames)-1 do begin
     pose:=pointer(poses);
     for j:=0 to header.num_poses-1 do begin
      if pose.channelmask and 7>0 then
       with framedata[n] do begin
        // read position
        frame:=i;
        boneIdx:=j;
        prop:=propPosition;
        x:=Unpack(0);
        y:=Unpack(1);
        z:=Unpack(2);
        inc(n);
       end;
      if pose.channelmask and $78>0 then
       with framedata[n] do begin
        // read rotation
        frame:=i;
        boneIdx:=j;
        prop:=propRotation;
        x:=Unpack(3);
        y:=Unpack(4);
        z:=Unpack(5);
        if pose.channelmask and $40>0 then
         w:=Unpack(6)
        else
         w:=-Sqrt(1-sqr(x)-sqr(y)-sqr(z));
        inc(n);
       end;
      if pose.channelmask and $380>0 then
       with framedata[n] do begin
        // read scale
        frame:=i;
        boneIdx:=j;
        prop:=propScale;
        x:=Unpack(7);
        y:=Unpack(8);
        z:=Unpack(9);
        inc(n);
       end;
      inc(pose);
     end;
    end;
    SetLength(frameData,n); // actual count

    count:=header.num_anims;
    SetLength(model.animations,count);
    for i:=0 to count-1 do
     with model.animations[i] do begin
      animationName:=GetString(animations.name);
      smooth:=true;
      curFrame:=-1;
      playing:=false;
      numFrames:=animations.num_frames;
      model.fps:=animations.framerate;
      values:=frameData;
     end;
   end;

  begin
   try
    data:=LoadFileAsBytes(fname);
    ASSERT(length(data)>=sizeof(header),'File is too short');
    header:=@data[0];
    ASSERT(header.magic=MAGIC,'Wrong file format');

    ParseData;
    model:=TModel3D.Create;
    model.fps:=30;
    BuildVertexData;
    BuildMeshData;
    LoadBones;
    LoadAnimations;

    model.UpdateBoneMatrices(false); // Calculate skeleton matrices
    result:=model;
   except
    on e:Exception do raise EError.Create('Error in LoadIQM('+fname+'): '+ExceptionMsg(e));
   end;
  end;

 function Load3DModelIQE(fname:string):TModel3D;
  var
   f:text;
   st:string;
   model:TModel3D;
  begin
   ASSERT(false,'LoadIQE not implemented!');
   try
    assign(f,fname);
    reset(f);
    readln(f,st);
    ASSERT(st='# Inter-Quake Export','Wrong file format '+fname);
    model:=TModel3D.Create;

    {ParseData;
    BuildVertexData;
    BuildMeshData;
    LoadBones;
    LoadAnimations;}

    result:=model;
   except
    on e:Exception do raise EError.Create('Error in LoadIQE('+fname+'): '+ExceptionMsg(e));
   end;
  end;

end.
