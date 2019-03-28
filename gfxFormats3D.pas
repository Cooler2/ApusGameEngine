// Support for common 3D model file formats
//
// Copyright (C) 2019 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
unit gfxFormats3D;
interface
 uses EngineAPI;

 function LoadOBJ(fname:string):TMesh;

implementation
 uses SysUtils,MyServis,Geom2D,Geom3D,Structs;

 function LoadOBJ(fname:string):TMesh;
  var
   f:text;
   line:string;
   sa:StringArr;
   points:array of TPoint3s;
   uv:array of TPoint2s;
   pCnt,uvCnt:integer;
   vertices:TVertices;
   vCnt:integer;
   indices:TIndices;
   iCnt:integer;
   vHash:TSimpleHashS;

  procedure AddPoint;
   var
    x,y,z:single;
   begin
    x:=0; y:=0; z:=0;
    if high(sa)>=1 then x:=ParseFloat(sa[1]);
    if high(sa)>=2 then y:=ParseFloat(sa[2]);
    if high(sa)>=3 then z:=ParseFloat(sa[3]);
    points[pCnt].x:=x;
    points[pCnt].y:=y;
    points[pCnt].z:=z;
    inc(pCnt);
   end;
  procedure AddUV;
   var
    u,v:single;
   begin
    u:=0; v:=0;
    if high(sa)>=1 then u:=ParseFloat(sa[1]);
    if high(sa)>=2 then v:=ParseFloat(sa[2]);
    uv[uvCnt].x:=u;
    uv[uvCnt].y:=v;
    inc(uvCnt);
   end;
  function GetVertexIdx(st:string):integer;
   var
    sa:StringArr;
    idx:integer;
   begin
    result:=vHash.Get(st);
    if result>=0 then exit;
    sa:=Split('/',st);
    idx:=StrToIntDef(sa[0],1)-1;
    result:=vCnt;
    vertices[vCnt].x:=points[idx].x;
    vertices[vCnt].y:=points[idx].y;
    vertices[vCnt].z:=points[idx].z;
    if high(sa)>=1 then begin
     idx:=StrToIntDef(sa[1],1)-1;
     vertices[vCnt].u:=uv[idx].x;
     vertices[vCnt].v:=uv[idx].y;
    end;
    inc(vCnt);
   end;
  procedure AddFace;
   var
    v3:integer;
   begin
    if high(sa)<3 then exit;
    indices[iCnt]:=GetVertexIdx(sa[1]); inc(icnt);
    indices[iCnt]:=GetVertexIdx(sa[2]); inc(icnt);
    indices[iCnt]:=GetVertexIdx(sa[3]); inc(icnt);
   end;

  begin
   pCnt:=0; uvCnt:=0; vCnt:=0; iCnt:=0;
   setLength(points,10000);
   setLength(uv,10000);
   setLength(vertices,10000);
   setLength(indices,10000);
   vHash.Init(2000);
   assign(f,fname);
   reset(f);
   while not eof(f) do begin
    readln(f,line);
    if line='' then continue;
    line:=chop(line);
    if length(line)<5 then continue;
    sa:=split(' ',line);
    // Vertex
    if sa[0]='v' then AddPoint;
    // Texture coordinates
    if sa[0]='vt' then AddUV;
    // Faces
    if sa[0]='f' then AddFace;
   end;
   close(f);
   // Trim arrays
   SetLength(vertices,vCnt);
   SetLength(indices,iCnt);
   result:=TMesh.Create;
   result.vertices:=vertices;
   result.indices:=indices;
  end;

end.
