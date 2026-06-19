// Procedural primitive mesh generators (R-20).
//
// Each generator is a pure fresh producer: it returns a new TMesh through the
// public fill-API (Apus.Engine.Mesh) with a sensible default attribute set.
// Generators do NOT take a target/transform - composition and merging is done
// via TMesh.Append. See Work/reports/R-20_meshshapes_design.md for the design.
//
// Conventions (apply to every generator):
//  - shapes are centered at origin (Box/sphere/cylinder centered; Plane on XY)
//  - up axis = +Z (engine world convention); cylinder/cone axis = Z; Plane
//    lies in XY, facing +Z (= up)
//  - winding: CCW = front face (outward-facing)
//  - size params are full extents, not half
//  - tangent stored along +U; the stock mesh shader reconstructs the bitangent
//    as B=cross(T,N)*w and expects it to point along +V (= the uv.y gradient),
//    so handedness w is chosen to satisfy that (see MeshOps.ComputeTangents)
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.MeshShapes;
interface
uses Apus.Core, Apus.Geom2D, Apus.Geom3D, Apus.Engine.Mesh;

{$SCOPEDENUMS ON}
type
 // Octant-subset selection for partial Octasphere generation.
 TSpherePortion=(Full,Hemisphere,Quarter,Eighth);
 // Axis the Hemisphere/Quarter/Eighth cut aligns to (default Z).
 TAxis=(X,Y,Z);
{$SCOPEDENUMS OFF}

type
 // Height displacement callback for MeshShapes.Plane: z = heightFn(x,y).
 THeightFn=function(x,y:single):single;

 // Namespace record - all generators are static class functions.
 MeshShapes=record
  // Axis-aligned box centered at origin. 24 verts (4/face), 12 tris.
  // pos+normal+uv+tangent; per-face UV in [0,1], tangent along the face's +U.
  class function Box(const size:TVec3):TMesh; overload; static;
  // Cube variant: Box(Vec3(s,s,s)).
  class function Box(s:single):TMesh; overload; static;

  // Cylinder / cone / truncated cone / tube, axis = Z, centered at origin.
  // r1 = bottom radius, r2 = top radius (r2=0 -> cone; r1<>r2 -> truncated
  // cone), height = full extent along Z, segments = radial subdivisions.
  // caps adds flat end discs (normal +-Z). pos+normal+uv+tangent; side
  // normals smooth around the circumference (cone apex = ring of distinct
  // per-segment vertices, NOT a single shared apex); cap normals flat.
  class function Cylinder(r1,r2,height:single;segments:integer;caps:boolean=true):TMesh; static;

  // Grid in the XY plane, centered, depth (Z) optionally displaced by
  // heightFn(x,y). (segX+1)x(segY+1) verts, segX*segY*2 tris. pos+normal+uv+
  // tangent; tangent along +X, normal/tangent computed numerically via
  // central differences (one-sided at the grid border) so any heightFn works
  // without an analytic gradient. heightFn=nil + segX=segY=1 = a flat
  // tangent-bearing quad facing +Z (e.g. for normal-map test surfaces).
  class function Plane(w,h:single;segX,segY:integer;heightFn:THeightFn=nil):TMesh; static;

  // Octahedron-based sphere: recursive midpoint subdivision (level=0 -> the
  // octahedron itself, 8 tris; each level x4), shared edge-midpoint vertices.
  // pos+normal only (no UV/tangent). portion selects an octant subset
  // (Full=8/Hemisphere=4/Quarter=2/Eighth=1 octants) aligned to `axis`
  // (default +Z): Hemisphere keeps octants with +axis sign, Quarter also
  // requires +sign on the next axis (cyclic axis->axis+1->axis+2), Eighth on
  // all three. Partial spheres are surface-only with an open boundary (no
  // cap disc).
  class function Octasphere(level:integer;portion:TSpherePortion=TSpherePortion.Full;
    radius:single=1;axis:TAxis=TAxis.Z):TMesh; static;

  // Lat-long sphere: segments = longitude divisions, rings = latitude
  // divisions. pos+normal+uv+tangent; normal = position/radius (unit
  // direction); u=lon/2pi, v=lat/pi where lat=0 at the +Z pole and lat=pi at
  // the -Z pole; tangent = dPos/dlon direction (+U), analytic and well-defined
  // at the poles, w=+1 (bitangent parallel to dPos/dlat, the +V direction).
  // Poles use per-segment duplicate vertices (same position, distinct u) for
  // a clean UV fan.
  class function UVSphere(segments,rings:integer;radius:single=1):TMesh; overload; static;

  // Spherical patch: lon in [lonFrom,lonTo], lat in [latFrom,latTo] (same
  // convention as the full sphere). (rings+1)x(segments+1) grid; boundary
  // open (no cap). UV = the corresponding slice of the full-sphere lat-long
  // unwrap (u=lon/2pi, v=lat/pi); if normalizeUV, remapped to [0,1] over the
  // patch range instead. A row exactly at a pole (sin(lat)=0) collapses to a
  // single point - the band touching it emits one fan triangle per segment
  // instead of two.
  class function UVSphere(segments,rings:integer;lonFrom,lonTo,latFrom,latTo:single;
    radius:single=1;normalizeUV:boolean=false):TMesh; overload; static;

  // Torus in the XY plane (hole along Z), centered at origin. majorR = ring
  // radius (origin to tube center), minorR = tube radius. segments = steps
  // around the ring (major, +U), sides = steps around the tube (minor, +V).
  // Seam columns are duplicated (u=0/u=1, v=0/v=1) for clean UV wrap, so per-
  // vertex analytic normals/tangents are seam-consistent. (segments+1)*(sides+1)
  // verts, segments*sides*2 tris. pos+normal+uv(0,1 each way)+tangent.
  class function Torus(majorR,minorR:single;segments,sides:integer):TMesh; static;
 end;

implementation

{ MeshShapes }

class function MeshShapes.Box(s:single):TMesh;
 begin
  result:=Box(Vec3(s,s,s));
 end;

class function MeshShapes.Box(const size:TVec3):TMesh;
 const
  // Per-face axes: N (outward normal), U (+U tangent direction), V (+V direction).
  // N=Cross(U,V) for every face -> the (0,0),(1,0),(1,1),(0,1) winding is
  // outward-facing CCW. With this right-handed (U,V,N) frame cross(T,N)=-V, so
  // the shader's B=cross(T,N)*w points along +V only when w=-1 (set below).
  // The four side faces (+-X,+-Y) use V=+Z so the texture stands upright in the
  // Z-up world (e.g. brick courses stack along Z); top/bottom use V=+Y.
  faceN:array[0..5] of TVec3=(
   (x:1; y:0; z:0),(x:-1;y:0; z:0),
   (x:0; y:1; z:0),(x:0; y:-1;z:0),
   (x:0; y:0; z:1),(x:0; y:0; z:-1));
  faceU:array[0..5] of TVec3=(
   (x:0; y:1; z:0), (x:0; y:-1;z:0),
   (x:-1;y:0; z:0), (x:1; y:0; z:0),
   (x:1; y:0; z:0), (x:-1;y:0; z:0));
  faceV:array[0..5] of TVec3=(
   (x:0; y:0; z:1),(x:0;y:0; z:1),
   (x:0; y:0; z:1),(x:0;y:0; z:1),
   (x:0; y:1; z:0),(x:0;y:1; z:0));
  cornerUV:array[0..3] of TVec2=((x:0;y:0),(x:1;y:0),(x:1;y:1),(x:0;y:1));
 var
  half:TVec3;
  f,i,vi:integer;
  n,u,v:TVec3;
  sizeU,sizeV,halfN:single;
 begin
  result:=TMesh.Create('box');
  result.SetVertexCount(24,[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  half:=size*0.5;
  for f:=0 to 5 do begin
   n:=faceN[f]; u:=faceU[f]; v:=faceV[f];
   sizeU:=abs(u.x)*size.x+abs(u.y)*size.y+abs(u.z)*size.z;
   sizeV:=abs(v.x)*size.x+abs(v.y)*size.y+abs(v.z)*size.z;
   halfN:=abs(n.x)*half.x+abs(n.y)*half.y+abs(n.z)*half.z;
   for i:=0 to 3 do begin
    vi:=f*4+i;
    result.positions[vi]:=n*halfN+u*((cornerUV[i].x-0.5)*sizeU)+v*((cornerUV[i].y-0.5)*sizeV);
    result.normals[vi]:=n;
    result.uv0[vi]:=cornerUV[i];
    result.tangents[vi]:=Vec4(u,-1); // w=-1: shader B=cross(T,N)*w must point along +V (here cross(U,N)=-V)
   end;
   result.AddTriangle(f*4+0,f*4+1,f*4+2);
   result.AddTriangle(f*4+0,f*4+2,f*4+3);
  end;
  result.Finish;
 end;

class function MeshShapes.Cylinder(r1,r2,height:single;segments:integer;caps:boolean=true):TMesh;
 var
  vcSide,vc,i,vi,bi0,ti0,bi1,ti1,capCenter,capRing:integer;
  halfH,angle,dAngle,cosA,sinA:single;
  nDir:TVec3;
 begin
  ASSERT(segments>=3,'Cylinder: segments must be >=3');
  halfH:=height*0.5;
  dAngle:=2*PI/segments;
  vcSide:=2*(segments+1);
  vc:=vcSide;
  if caps then inc(vc,2*(segments+1));
  result:=TMesh.Create('cylinder');
  result.SetVertexCount(vc,[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  // side: segments+1 columns (seam duplicated for UV wrap) x 2 rows (bottom,top)
  for i:=0 to segments do begin
   angle:=i*dAngle;
   cosA:=cos(angle); sinA:=sin(angle);
   nDir:=Vec3(height*cosA,-height*sinA,r1-r2);
   nDir.Normalize;
   vi:=2*i;
   result.positions[vi]:=Vec3(r1*cosA,-r1*sinA,-halfH);
   result.normals[vi]:=nDir;
   result.uv0[vi]:=Vec2(i/segments,0);
   result.tangents[vi]:=Vec4(-sinA,-cosA,0,1); // w=+1: left-handed (U,V,N) here, cross(T,N)=+V (=+Z)
   vi:=2*i+1;
   result.positions[vi]:=Vec3(r2*cosA,-r2*sinA,halfH);
   result.normals[vi]:=nDir;
   result.uv0[vi]:=Vec2(i/segments,1);
   result.tangents[vi]:=Vec4(-sinA,-cosA,0,1);
  end;
  for i:=0 to segments-1 do begin
   bi0:=2*i; ti0:=2*i+1; bi1:=2*(i+1); ti1:=2*(i+1)+1;
   result.AddTriangle(bi0,ti0,bi1);
   result.AddTriangle(bi1,ti0,ti1);
  end;
  if caps then begin
   // bottom cap (normal -Z): fan (center,ring_i,ring_i+1) is outward-CCW
   capCenter:=vcSide;
   capRing:=vcSide+1;
   result.positions[capCenter]:=Vec3(0,0,-halfH);
   result.normals[capCenter]:=Vec3(0,0,-1);
   result.uv0[capCenter]:=Vec2(0.5,0.5);
   result.tangents[capCenter]:=Vec4(1,0,0,-1); // bottom cap N=-Z: cross(T,N)=+Y, +V=-Y -> w=-1
   for i:=0 to segments-1 do begin
    angle:=i*dAngle;
    cosA:=cos(angle); sinA:=sin(angle);
    vi:=capRing+i;
    result.positions[vi]:=Vec3(r1*cosA,-r1*sinA,-halfH);
    result.normals[vi]:=Vec3(0,0,-1);
    result.uv0[vi]:=Vec2(0.5+0.5*cosA,0.5+0.5*sinA);
    result.tangents[vi]:=Vec4(1,0,0,-1);
   end;
   for i:=0 to segments-1 do
    result.AddTriangle(capCenter,capRing+i,capRing+((i+1) mod segments));
   // top cap (normal +Z): fan (center,ring_i+1,ring_i) is outward-CCW
   capCenter:=vcSide+segments+1;
   capRing:=capCenter+1;
   result.positions[capCenter]:=Vec3(0,0,halfH);
   result.normals[capCenter]:=Vec3(0,0,1);
   result.uv0[capCenter]:=Vec2(0.5,0.5);
   result.tangents[capCenter]:=Vec4(1,0,0,1); // top cap N=+Z: cross(T,N)=-Y, +V=-Y -> w=+1
   for i:=0 to segments-1 do begin
    angle:=i*dAngle;
    cosA:=cos(angle); sinA:=sin(angle);
    vi:=capRing+i;
    result.positions[vi]:=Vec3(r2*cosA,-r2*sinA,halfH);
    result.normals[vi]:=Vec3(0,0,1);
    result.uv0[vi]:=Vec2(0.5+0.5*cosA,0.5+0.5*sinA);
    result.tangents[vi]:=Vec4(1,0,0,1);
   end;
   for i:=0 to segments-1 do
    result.AddTriangle(capCenter,capRing+((i+1) mod segments),capRing+i);
  end;
  result.Finish;
 end;

class function MeshShapes.Plane(w,h:single;segX,segY:integer;heightFn:THeightFn=nil):TMesh;
 var
  i,j,idx,idx00,idx10,idx01,idx11:integer;
  x,y,dx,dy:single;
  p:TVec3;
  dPdx,dPdy,nrm,tng:TVec3;
 begin
  ASSERT((segX>=1) and (segY>=1),'Plane: segX/segY must be >=1');
  result:=TMesh.Create('plane');
  result.SetVertexCount((segX+1)*(segY+1),[TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  dx:=w/segX; dy:=h/segY;
  // pass 1: positions + uv
  for j:=0 to segY do
   for i:=0 to segX do begin
    x:=-w*0.5+i*dx;
    y:=-h*0.5+j*dy;
    idx:=j*(segX+1)+i;
    p.x:=x; p.y:=y;
    if Assigned(heightFn) then p.z:=heightFn(x,y) else p.z:=0;
    result.positions[idx]:=p;
    result.uv0[idx]:=Vec2(i/segX,j/segY);
   end;
  // pass 2: normal/tangent via central differences over the (already filled) grid
  for j:=0 to segY do
   for i:=0 to segX do begin
    idx:=j*(segX+1)+i;
    if i=0 then dPdx:=result.positions[idx+1]-result.positions[idx]
    else if i=segX then dPdx:=result.positions[idx]-result.positions[idx-1]
    else dPdx:=result.positions[idx+1]-result.positions[idx-1];
    if j=0 then dPdy:=result.positions[idx+(segX+1)]-result.positions[idx]
    else if j=segY then dPdy:=result.positions[idx]-result.positions[idx-(segX+1)]
    else dPdy:=result.positions[idx+(segX+1)]-result.positions[idx-(segX+1)];
    nrm:=dPdx.Cross(dPdy); // = +Z for the flat (heightFn=nil) case
    nrm.Normalize;
    tng:=dPdx;
    tng.Normalize;
    result.normals[idx]:=nrm;
    // shader B=cross(T,N)*w must align dPdy (+V); cross(T,N)=-dPdy here -> w=-1
    result.tangents[idx]:=Vec4(tng,-1);
   end;
  // triangles: (i,j),(i+1,j),(i+1,j+1) and (i,j),(i+1,j+1),(i,j+1) -> +Z outward
  for j:=0 to segY-1 do
   for i:=0 to segX-1 do begin
    idx00:=j*(segX+1)+i;
    idx10:=idx00+1;
    idx01:=idx00+(segX+1);
    idx11:=idx01+1;
    result.AddTriangle(idx00,idx10,idx11);
    result.AddTriangle(idx00,idx11,idx01);
   end;
  result.Finish;
 end;

class function MeshShapes.Octasphere(level:integer;portion:TSpherePortion=TSpherePortion.Full;
   radius:single=1;axis:TAxis=TAxis.Z):TMesh;
 const
  // octahedron base vertices: 0:+X 1:-X 2:+Y 3:-Y 4:+Z 5:-Z
  baseVerts:array[0..5] of TVec3=(
   (x:1;y:0;z:0),(x:-1;y:0;z:0),
   (x:0;y:1;z:0),(x:0;y:-1;z:0),
   (x:0;y:0;z:1),(x:0;y:0;z:-1));
 type
  TTri=array[0..2] of integer;
 var
  positions:array of TVec3;
  triangles:array of TTri;
  triCount:integer;
  edgeA,edgeB,edgeMid:array of integer;
  edgeCount:integer;
  baseIdx:array[0..5] of integer;
  pAxis,sAxis,uAxis:integer;
  sx,sy,sz,negCount,i:integer;
  ord0,ord1,ord2:integer;
  s,vfor:array[0..2] of integer;
  incl:boolean;

  function AddPoint(const p:TVec3):integer;
   var n:TVec3;
   begin
    n:=p; n.Normalize;
    result:=length(positions);
    SetLength(positions,result+1);
    positions[result]:=n;
   end;

  function GetBaseVertex(k:integer):integer;
   begin
    if baseIdx[k]<0 then baseIdx[k]:=AddPoint(baseVerts[k]);
    result:=baseIdx[k];
   end;

  // Edge-midpoint cache (linear search; edge counts stay small for the
  // subdivision levels this generator is meant for).
  function Midpoint(i0,i1:integer):integer;
   var j,a,b:integer;
   begin
    a:=i0; b:=i1;
    if a>b then begin j:=a; a:=b; b:=j; end;
    for j:=0 to edgeCount-1 do
     if (edgeA[j]=a) and (edgeB[j]=b) then exit(edgeMid[j]);
    result:=AddPoint((positions[i0]+positions[i1])*0.5);
    if edgeCount>=length(edgeA) then begin
     SetLength(edgeA,edgeCount+64);
     SetLength(edgeB,edgeCount+64);
     SetLength(edgeMid,edgeCount+64);
    end;
    edgeA[edgeCount]:=a; edgeB[edgeCount]:=b; edgeMid[edgeCount]:=result;
    inc(edgeCount);
   end;

  procedure AddTri(a,b,c:integer);
   begin
    if triCount>=length(triangles) then SetLength(triangles,triCount+64);
    triangles[triCount][0]:=a;
    triangles[triCount][1]:=b;
    triangles[triCount][2]:=c;
    inc(triCount);
   end;

  procedure Subdivide(a,b,c,lvl:integer);
   var ab,bc,ca:integer;
   begin
    if lvl=0 then begin AddTri(a,b,c); exit; end;
    ab:=Midpoint(a,b);
    bc:=Midpoint(b,c);
    ca:=Midpoint(c,a);
    Subdivide(a,ab,ca,lvl-1);
    Subdivide(ab,b,bc,lvl-1);
    Subdivide(ca,bc,c,lvl-1);
    Subdivide(ab,bc,ca,lvl-1);
   end;

 begin
  ASSERT(level>=0,'Octasphere: level must be >=0');
  for i:=0 to 5 do baseIdx[i]:=-1;
  triCount:=0;
  edgeCount:=0;
  case axis of
   TAxis.X:begin pAxis:=0; sAxis:=1; uAxis:=2; end;
   TAxis.Y:begin pAxis:=1; sAxis:=2; uAxis:=0; end;
   else begin pAxis:=2; sAxis:=0; uAxis:=1; end; // TAxis.Z
  end;
  // 8 octants = all (sx,sy,sz) in {-1,+1}^3
  for sx:=-1 to 1 do begin
   if sx=0 then continue;
   for sy:=-1 to 1 do begin
    if sy=0 then continue;
    for sz:=-1 to 1 do begin
     if sz=0 then continue;
     s[0]:=sx; s[1]:=sy; s[2]:=sz;
     case portion of
      TSpherePortion.Full:incl:=true;
      TSpherePortion.Hemisphere:incl:=s[pAxis]=1;
      TSpherePortion.Quarter:incl:=(s[pAxis]=1) and (s[sAxis]=1);
      else incl:=(s[pAxis]=1) and (s[sAxis]=1) and (s[uAxis]=1); // TSpherePortion.Eighth
     end;
     if not incl then continue;
     // winding: base order (X,Y,Z) for an even number of negative signs,
     // (X,Z,Y) for odd - keeps every octant face outward-CCW.
     negCount:=0;
     if sx=-1 then inc(negCount);
     if sy=-1 then inc(negCount);
     if sz=-1 then inc(negCount);
     if negCount mod 2=0 then begin ord0:=0; ord1:=1; ord2:=2; end
     else begin ord0:=0; ord1:=2; ord2:=1; end;
     if s[0]=1 then vfor[0]:=GetBaseVertex(0) else vfor[0]:=GetBaseVertex(1);
     if s[1]=1 then vfor[1]:=GetBaseVertex(2) else vfor[1]:=GetBaseVertex(3);
     if s[2]=1 then vfor[2]:=GetBaseVertex(4) else vfor[2]:=GetBaseVertex(5);
     Subdivide(vfor[ord0],vfor[ord1],vfor[ord2],level);
    end;
   end;
  end;
  SetLength(triangles,triCount);
  result:=TMesh.Create('octasphere');
  result.SetVertexCount(length(positions),[TMeshAttribute.Normal]);
  for i:=0 to high(positions) do begin
   result.normals[i]:=positions[i];
   result.positions[i]:=positions[i]*radius;
  end;
  SetLength(result.indices,triCount*3);
  for i:=0 to triCount-1 do begin
   result.indices[i*3]:=triangles[i][0];
   result.indices[i*3+1]:=triangles[i][1];
   result.indices[i*3+2]:=triangles[i][2];
  end;
  result.Finish;
 end;

class function MeshShapes.UVSphere(segments,rings:integer;radius:single=1):TMesh;
 begin
  result:=UVSphere(segments,rings,0,2*Pi,0,Pi,radius,false);
 end;

class function MeshShapes.UVSphere(segments,rings:integer;lonFrom,lonTo,latFrom,latTo:single;
   radius:single=1;normalizeUV:boolean=false):TMesh;
 const
  eps=1e-5;
 var
  i,j,idx,a,b,c,d:integer;
  lon,lat,rh,u,v:single;
  p,n,t:TVec3;
 begin
  ASSERT(segments>=3,'UVSphere: segments must be >=3');
  ASSERT(rings>=1,'UVSphere: rings must be >=1');
  result:=TMesh.Create('uvsphere');
  result.SetVertexCount((rings+1)*(segments+1),
    [TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  for j:=0 to rings do begin
   lat:=latFrom+(latTo-latFrom)*j/rings;
   for i:=0 to segments do begin
    lon:=lonFrom+(lonTo-lonFrom)*i/segments;
    rh:=sin(lat);
    // n is already a unit vector: |n|^2 = rh^2*(cos^2+sin^2)+cos(lat)^2 = 1
    n:=Vec3(rh*cos(lon),-rh*sin(lon),cos(lat));
    p:=n*radius;
    // dPos/dlon direction, unit length regardless of rh (well-defined at poles)
    t:=Vec3(-sin(lon),-cos(lon),0);
    u:=lon/(2*Pi); v:=lat/Pi;
    if normalizeUV then begin
     if lonTo<>lonFrom then u:=(lon-lonFrom)/(lonTo-lonFrom);
     if latTo<>latFrom then v:=(lat-latFrom)/(latTo-latFrom);
    end;
    idx:=j*(segments+1)+i;
    result.positions[idx]:=p;
    result.normals[idx]:=n;
    result.uv0[idx]:=Vec2(u,v);
    result.tangents[idx]:=Vec4(t,-1); // shader B=cross(T,N)*w aligns +V (dlat) only with w=-1
   end;
  end;
  // quad grid split into 2 triangles each, both outward-CCW: (a,b,c) and
  // (b,d,c). A row collapsed to a pole point degenerates one of the two -
  // (a,b,c) when row j is a pole, (b,d,c) when row j+1 is a pole.
  for j:=0 to rings-1 do
   for i:=0 to segments-1 do begin
    a:=j*(segments+1)+i;
    b:=a+1;
    c:=a+(segments+1);
    d:=c+1;
    if abs(sin(latFrom+(latTo-latFrom)*j/rings))>eps then result.AddTriangle(a,b,c);
    if abs(sin(latFrom+(latTo-latFrom)*(j+1)/rings))>eps then result.AddTriangle(b,d,c);
   end;
  result.Finish;
 end;

class function MeshShapes.Torus(majorR,minorR:single;segments,sides:integer):TMesh;
 var
  i,j,idx,a,b,c,d:integer;
  u,v,cu,su,cv,sv:single;
  p,n,t:TVec3;
 begin
  ASSERT(segments>=3,'Torus: segments must be >=3');
  ASSERT(sides>=3,'Torus: sides must be >=3');
  result:=TMesh.Create('torus');
  result.SetVertexCount((segments+1)*(sides+1),
    [TMeshAttribute.Normal,TMeshAttribute.UV0,TMeshAttribute.Tangent]);
  idx:=0;
  for i:=0 to segments do begin
   u:=2*Pi*i/segments;
   cu:=cos(u); su:=sin(u);
   for j:=0 to sides do begin
    v:=2*Pi*j/sides;
    cv:=cos(v); sv:=sin(v);
    p:=Vec3((majorR+minorR*cv)*cu,(majorR+minorR*cv)*su,minorR*sv);
    n:=Vec3(cv*cu,cv*su,sv); // outward, already unit
    t:=Vec3(-su,cu,0);       // +dP/du direction (tangent along +U)
    result.positions[idx]:=p;
    result.normals[idx]:=n;
    result.uv0[idx]:=Vec2(i/segments,j/sides);
    result.tangents[idx]:=Vec4(t,-1); // cross(T,N)=-dP/dv -> w=-1 so shader B=cross(T,N)*w aligns +V
    inc(idx);
   end;
  end;
  for i:=0 to segments-1 do
   for j:=0 to sides-1 do begin
    a:=i*(sides+1)+j;
    b:=a+1;
    c:=a+(sides+1);
    d:=c+1;
    result.AddTriangle(a,c,d); // outward-CCW
    result.AddTriangle(a,d,b);
   end;
  result.Finish;
 end;

end.
