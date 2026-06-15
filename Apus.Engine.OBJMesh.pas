// Wavefront OBJ -> SoA TMesh geometry loader (R-19, geometry level).
//
// Loads GEOMETRY ONLY into a new Apus.Engine.Mesh3D.TMesh: positions, normals
// (if the file has any 'vn'), uv0 (if any 'vt'), and one geometric section per
// material/group ('usemtl'/'g'/'o'). Materials are NOT resolved here — the
// section name carries the group/material name; bind textures manually at the
// draw site (loop sections, bind, gpuMesh.DrawSection/DrawRange). This is the
// new-world counterpart of the legacy TModel3D / interleaved-mesh OBJ loaders;
// it depends only on Base + the SoA mesh (no gfx), so it is headless-testable.
//
// Face polygons are triangulated as a fan; identical v/vt/vn corners are shared
// (vertex dedup). The engine OBJ convention is preserved: position/normal are
// remapped to (-X,-Z,Y) and texture V is flipped (U, 1-V).
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.OBJMesh;
interface
uses Apus.Core, Apus.Geom2D, Apus.Geom3D, Apus.Engine.Mesh3D;

// Parse OBJ text held in a String8 into a new TMesh (the caller owns it).
function ParseMeshOBJ(const data:String8;const name:String8=''):TMesh;
// Load an OBJ file into a new TMesh (the caller owns it).
function LoadMeshOBJ(const fname:String8):TMesh;

implementation
uses Apus.Strings, Apus.Files, Apus.HashMaps;

function ParseMeshOBJ(const data:String8;const name:String8=''):TMesh;
 var
  m:TMesh;
  lines,tok:Strings8;
  // raw OBJ arrays (as defined in the file)
  vP,vN:TVec3Array;
  vT:TVec2Array;
  pCnt,nCnt,tCnt:integer;
  // deduplicated output arrays (named types match the TMesh fields they fill)
  oP,oN:TVec3Array;
  oT:TVec2Array;
  oI:IntArray;
  vCnt,iCnt:integer;
  hasN,hasT:boolean;
  vHash:TSimpleHash;
  // section tracking
  pendingName,line:String8;
  secStart:integer;
  secOpen:boolean;
  i,j,c0:integer;

  procedure Compact(var a:Strings8); // drop empty tokens (collapse runs of spaces)
   var k,w:integer;
   begin
    w:=0;
    for k:=0 to high(a) do if a[k]<>'' then begin a[w]:=a[k]; inc(w); end;
    SetLength(a,w);
   end;

  function CornerIdx(const t:String8):integer; // resolve one 'p[/t[/n]]' corner -> output vertex
   var
    parts:Strings8;
    pi,ti,ni:integer;
    key:int64;
   begin
    parts:=t.Split('/');
    pi:=parts[0].ToInteger;
    if pi<0 then inc(pi,pCnt) else dec(pi); // OBJ indices are 1-based; negatives are relative
    ti:=-1; ni:=-1;
    if (length(parts)>=2) and (parts[1]<>'') then begin
     ti:=parts[1].ToInteger; if ti<0 then inc(ti,tCnt) else dec(ti);
    end;
    if (length(parts)>=3) and (parts[2]<>'') then begin
     ni:=parts[2].ToInteger; if ni<0 then inc(ni,nCnt) else dec(ni);
    end;
    key:=(int64(pi+1) shl 42) or (int64(ti+1) shl 21) or int64(ni+1);
    result:=vHash.Get(key);
    if result>=0 then exit; // shared corner already emitted
    result:=vCnt;
    vHash.Put(key,vCnt);
    if vCnt>=length(oP) then begin
     SetLength(oP,vCnt*2+64);
     if hasN then SetLength(oN,length(oP));
     if hasT then SetLength(oT,length(oP));
    end;
    oP[vCnt]:=vP[pi];
    if hasN then
     if ni>=0 then oN[vCnt]:=vN[ni] else oN[vCnt]:=Vec3(0,0,0);
    if hasT then
     if ti>=0 then oT[vCnt]:=vT[ti] else oT[vCnt]:=Vec2(0,0);
    inc(vCnt);
   end;

  procedure PushIndex(idx:integer);
   begin
    if iCnt>=length(oI) then SetLength(oI,iCnt*2+64);
    oI[iCnt]:=idx; inc(iCnt);
   end;

  procedure CloseSection;
   begin
    if secOpen and (iCnt>secStart) then m.AddSection(pendingName,secStart,iCnt-secStart);
    secOpen:=false;
   end;

  procedure EnsureSection; // open a section lazily when the first face of a group arrives
   begin
    if not secOpen then begin secStart:=iCnt; secOpen:=true; end;
   end;

 begin
  m:=TMesh.Create(name);
  vP:=nil; vN:=nil; vT:=nil;
  oP:=nil; oN:=nil; oT:=nil; oI:=nil;
  pCnt:=0; nCnt:=0; tCnt:=0;
  vCnt:=0; iCnt:=0;
  hasN:=false; hasT:=false;
  pendingName:=''; secOpen:=false; secStart:=0;
  vHash.Init(1+length(data) div 16);

  lines:=data.Split(#10);
  for i:=0 to high(lines) do begin
   line:=lines[i].Trim; // also strips a trailing #13 (CRLF)
   if line='' then continue;
   if line[1]='#' then continue;
   tok:=line.Split(' ');
   Compact(tok);
   if length(tok)=0 then continue;

   if tok[0]='v' then begin
    if high(tok)<3 then continue;
    if pCnt>=length(vP) then SetLength(vP,pCnt*2+64);
    vP[pCnt]:=Vec3(-tok[1].ToDouble,-tok[3].ToDouble,tok[2].ToDouble); // engine OBJ convention
    inc(pCnt);
   end else
   if tok[0]='vn' then begin
    if high(tok)<3 then continue;
    hasN:=true;
    if nCnt>=length(vN) then SetLength(vN,nCnt*2+64);
    vN[nCnt]:=Vec3(-tok[1].ToDouble,-tok[3].ToDouble,tok[2].ToDouble);
    inc(nCnt);
   end else
   if tok[0]='vt' then begin
    if high(tok)<2 then continue;
    hasT:=true;
    if tCnt>=length(vT) then SetLength(vT,tCnt*2+64);
    vT[tCnt]:=Vec2(tok[1].ToDouble,1-tok[2].ToDouble); // lower-left origin -> flip V
    inc(tCnt);
   end else
   if tok[0]='f' then begin
    if high(tok)<3 then continue; // need at least 3 corners
    EnsureSection;
    c0:=CornerIdx(tok[1]);
    for j:=2 to high(tok)-1 do begin // triangulate as a fan
     PushIndex(c0);
     PushIndex(CornerIdx(tok[j]));
     PushIndex(CornerIdx(tok[j+1]));
    end;
   end else
   if (tok[0]='usemtl') or (tok[0]='g') or (tok[0]='o') then begin
    CloseSection; // a new group/material starts a new section
    if high(tok)>=1 then pendingName:=tok[1] else pendingName:='';
   end;
  end;
  CloseSection;

  // hand the finished arrays to the mesh (bulk-producer pattern: fill local, assign)
  SetLength(oP,vCnt); m.positions:=oP;
  if hasN then begin SetLength(oN,vCnt); m.normals:=oN; end;
  if hasT then begin SetLength(oT,vCnt); m.uv0:=oT; end;
  SetLength(oI,iCnt); m.indices:=oI;
  m.Finish;
  result:=m;
 end;

function LoadMeshOBJ(const fname:String8):TMesh;
 begin
  result:=ParseMeshOBJ(Files.LoadAsString(fname),fname);
 end;

end.
