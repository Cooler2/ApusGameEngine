// Support for common 3D model file formats
//
// Copyright (C) 2019 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.GfxFormats3D;
interface
 uses Apus.Engine.API;

 function LoadOBJ(fname:string):TMesh;

implementation
 uses SysUtils, Apus.MyServis, Apus.Geom2D, Apus.Geom3D, Apus.Structs;

 function LoadOBJ(fname:string):TMesh;
  var
   f:text;
   line:string;
   sa:StringArr;
   points:array of TPoint3s;
   normals:array of TVector3s;
   uv:TTexCoords;
   pCnt,uvCnt,nCnt:integer;
   vertices:TVertices3D;
   vCnt:integer;
   indices:TIndices;
   iCnt:integer;
   vHash:TSimpleHashS;
   layout:TVertexLayout;

  procedure AddPoint;
   var
    x,y,z:single;
   begin
    x:=0; y:=0; z:=0;
    if high(sa)>=1 then x:=ParseFloat(sa[1]);
    if high(sa)>=2 then y:=ParseFloat(sa[2]);
    if high(sa)>=3 then z:=ParseFloat(sa[3]);
    points[pCnt].x:=x;
    points[pCnt].y:=-z;
    points[pCnt].z:=y;
    inc(pCnt);
    if pCnt>=high(points) then
     SetLength(points,pcnt*2);
   end;
  procedure AddNormal;
   var
    x,y,z:single;
   begin
    x:=0; y:=0; z:=0;
    if high(sa)>=1 then x:=ParseFloat(sa[1]);
    if high(sa)>=2 then y:=ParseFloat(sa[2]);
    if high(sa)>=3 then z:=ParseFloat(sa[3]);
    normals[nCnt].x:=x;
    normals[nCnt].y:=-z;
    normals[nCnt].z:=y;
    inc(nCnt);
    if nCnt>=high(normals) then
     SetLength(normals,nCnt*2);
   end;
  procedure AddUV;
   var
    u,v:single;
   begin
    u:=0; v:=0;
    if high(sa)>=1 then u:=ParseFloat(sa[1]);
    if high(sa)>=2 then v:=1-ParseFloat(sa[2]);
    uv[uvCnt].x:=u;
    uv[uvCnt].y:=v;
    inc(uvCnt);
    if uvCnt>=high(uv) then
     SetLength(uv,uvCnt*2);
   end;
  function GetVertexIdx(st:string):integer;
   var
    sa:StringArr;
    idx:integer;
   begin
    result:=vHash.Get(st);
    if result>=0 then exit;
    sa:=Split('/',st); // vertex format is: pos_idx/tex_idx/normal_idx
    idx:=StrToIntDef(sa[0],1)-1;
    result:=vCnt;
    vHash.Put(st,result);
    vertices[vCnt].color:=$FF808080;
    vertices[vCnt].x:=points[idx].x;
    vertices[vCnt].y:=points[idx].y;
    vertices[vCnt].z:=points[idx].z;
    if high(sa)>=1 then begin
     if sa[1]<>'' then begin
      idx:=StrToIntDef(sa[1],1)-1;
      vertices[vCnt].u:=uv[idx].x;
      vertices[vCnt].v:=uv[idx].y;
     end else begin
      vertices[vCnt].u:=0;
      vertices[vCnt].v:=0;
     end;
    end;
    if high(sa)>=2 then begin
     idx:=StrToIntDef(sa[2],1)-1;
     vertices[vCnt].nx:=normals[idx].x;
     vertices[vCnt].ny:=normals[idx].y;
     vertices[vCnt].nz:=normals[idx].z;
    end;
    inc(vCnt);
   end;
  procedure AddFace;
   var
    v3:integer;
   begin
    if high(sa)<3 then exit;
    if iCnt+6>length(indices) then
     SetLength(indices,iCnt*2);
    indices[iCnt]:=GetVertexIdx(sa[1]); inc(icnt);
    indices[iCnt]:=GetVertexIdx(sa[2]); inc(icnt);
    indices[iCnt]:=GetVertexIdx(sa[3]); inc(icnt);
    if high(sa)=4 then begin
     // quad -> add 2-nd triangle
     indices[iCnt]:=GetVertexIdx(sa[1]); inc(icnt);
     indices[iCnt]:=GetVertexIdx(sa[3]); inc(icnt);
     indices[iCnt]:=GetVertexIdx(sa[4]); inc(icnt);
    end;
   end;

  begin
   pCnt:=0; uvCnt:=0; vCnt:=0; iCnt:=0; nCnt:=0;
   SetLength(points,10000);
   SetLength(uv,10000);
   SetLength(vertices,10000);
   SetLength(indices,10000);
   SetLength(normals,10000);
   vHash.Init(2000);
   Assign(f,fname);
   SetTextCodePage(f,CP_UTF8);
   Reset(f);
   while not eof(f) do begin
    readln(f,line);
    if line='' then continue;
    line:=chop(line);
    if length(line)<5 then continue;
    sa:=split(' ',line);
    // Vertex
    if sa[0]='v' then AddPoint;
    // Vertex
    if sa[0]='vn' then AddNormal;
    // Texture coordinates
    if sa[0]='vt' then AddUV;
    // Faces
    if sa[0]='f' then AddFace;
   end;
   Close(f);
   // Trim arrays
   SetLength(indices,iCnt);
   result:=TMesh.Create(TVertex3D.Layout,vCnt,iCnt);
   move(vertices[0],result.vertices^,vCnt*sizeof(TVertex3D));
   result.indices:=indices;
  end;

end.
