// -----------------------------------------------------
// Spatial primitives and intersection helpers
// Author: Apus Engine contributors
// ------------------------------------------------------
unit Apus.Spatial;

interface

uses
  Math,
  Apus.Core,
  Apus.Geom3D;

type
  TBBox3 = packed record
    minX,minY,minZ:single;
    maxX,maxY,maxZ:single;
    class function Init(const pMin,pMax:TVec3):TBBox3; overload; static;
    procedure Clear;
    function IsEmpty:boolean;
    procedure IncludePoint(const p:TVec3);
    procedure IncludeBox(const box:TBBox3);
    function Center:TVec3;
    function Extents:TVec3;
    function ContainsPoint(const p:TVec3):boolean;
    function IntersectsBox(const other:TBBox3):boolean;
    function IntersectsSphere(const sphereCenter:TVec3;sphereRadius:single):boolean;
  end;

  TSphere = record
    center: TVec3;
    radius: single;
    constructor Init(const aCenter: TVec3; aRadius: single);
    function ContainsPoint(const p: TVec3): boolean;
    function IntersectsSphere(const other: TSphere): boolean;
    function IntersectsBox(const box: TBBox3): boolean;
  end;

  TRay = record
    origin: TVec3;
    dir: TVec3; // expected normalized
    constructor Init(const aOrigin, aDir: TVec3);
    function IntersectsSphere(const sphere: TSphere; out t: single): boolean;
    function IntersectsBox(const box: TBBox3; out tMin, tMax: single): boolean;
    function IntersectsTriangle(const a, b, c: TVec3; out t, u, v: single): boolean;
    function IntersectsPlane(const plane: TPlane; out t: single): boolean;
  end;

  TFrustum = record
    planes: array[0..5] of TVec4; // near, far, left, right, top, bottom
    planeCount: byte; // 4 or 6
    procedure InitFromMVP(const mvp: TMat4; includeNearFar: boolean = true);
    function IntersectsSphere(const sphere: TSphere): boolean;
    function IntersectsBox(const box: TBBox3): boolean;
  end;

  TSpatial = record
    class function DistanceToPlane(const plane: TVec4; const p: TVec3): single; static;
  end;

implementation

const
  SpatialEpsilon = 1E-5;

procedure NormalizePlane(var p: TVec4); inline;
var
  invLen: single;
begin
  invLen:=Sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
  if invLen > SpatialEpsilon then begin
    invLen:=1.0 / invLen;
    p.x:=p.x * invLen;
    p.y:=p.y * invLen;
    p.z:=p.z * invLen;
    p.w:=p.w * invLen;
  end;
end;

function SelectPositiveVertex(const box:TBBox3;nx,ny,nz:single):TVec3; inline;
begin
  if nx>=0 then begin
    result.x:=box.maxX
  end else begin
    result.x:=box.minX;
  end;
  if ny>=0 then begin
    result.y:=box.maxY
  end else begin
    result.y:=box.minY;
  end;
  if nz>=0 then begin
    result.z:=box.maxZ
  end else begin
    result.z:=box.minZ;
  end;
end;

{ TBBox3 }

class function TBBox3.Init(const pMin,pMax:TVec3):TBBox3;
begin
  result.minX:=pMin.x; result.minY:=pMin.y; result.minZ:=pMin.z;
  result.maxX:=pMax.x; result.maxY:=pMax.y; result.maxZ:=pMax.z;
end;

procedure TBBox3.Clear;
begin
  minX:=NaN; minY:=NaN; minZ:=NaN;
  maxX:=NaN; maxY:=NaN; maxZ:=NaN;
end;

function TBBox3.IsEmpty:boolean;
begin
  result:=Apus.Core.IsNaN(minX);
end;

procedure TBBox3.IncludePoint(const p:TVec3);
begin
  if IsEmpty then begin
    minX:=p.x; minY:=p.y; minZ:=p.z;
    maxX:=p.x; maxY:=p.y; maxZ:=p.z;
    exit;
  end;
  if p.x<minX then begin
    minX:=p.x;
  end;
  if p.x>maxX then begin
    maxX:=p.x;
  end;
  if p.y<minY then begin
    minY:=p.y;
  end;
  if p.y>maxY then begin
    maxY:=p.y;
  end;
  if p.z<minZ then begin
    minZ:=p.z;
  end;
  if p.z>maxZ then begin
    maxZ:=p.z;
  end;
end;

procedure TBBox3.IncludeBox(const box:TBBox3);
begin
  if box.IsEmpty then begin
    exit;
  end;
  if IsEmpty then begin
    self:=box;
    exit;
  end;
  if box.minX<minX then begin
    minX:=box.minX;
  end;
  if box.minY<minY then begin
    minY:=box.minY;
  end;
  if box.minZ<minZ then begin
    minZ:=box.minZ;
  end;
  if box.maxX>maxX then begin
    maxX:=box.maxX;
  end;
  if box.maxY>maxY then begin
    maxY:=box.maxY;
  end;
  if box.maxZ>maxZ then begin
    maxZ:=box.maxZ;
  end;
end;

function TBBox3.Center:TVec3;
begin
  if IsEmpty then begin
    exit(NullPointS);
  end;
  result:=TVec3.Init((minX+maxX)*0.5,(minY+maxY)*0.5,(minZ+maxZ)*0.5);
end;

function TBBox3.Extents:TVec3;
begin
  if IsEmpty then begin
    exit(NullPointS);
  end;
  result:=TVec3.Init((maxX-minX)*0.5,(maxY-minY)*0.5,(maxZ-minZ)*0.5);
end;

function TBBox3.ContainsPoint(const p:TVec3):boolean;
begin
  if IsEmpty then begin
    exit(false);
  end;
  result:=(p.x>=minX) and (p.x<=maxX) and
          (p.y>=minY) and (p.y<=maxY) and
          (p.z>=minZ) and (p.z<=maxZ);
end;

function TBBox3.IntersectsBox(const other:TBBox3):boolean;
begin
  if IsEmpty or other.IsEmpty then begin
    exit(false);
  end;
  result:=(minX<=other.maxX) and (maxX>=other.minX) and
          (minY<=other.maxY) and (maxY>=other.minY) and
          (minZ<=other.maxZ) and (maxZ>=other.minZ);
end;

function TBBox3.IntersectsSphere(const sphereCenter:TVec3;sphereRadius:single):boolean;
var
  x,y,z,dx,dy,dz:single;
begin
  if IsEmpty then begin
    exit(false);
  end;
  x:=sphereCenter.x;
  y:=sphereCenter.y;
  z:=sphereCenter.z;
  if x<minX then begin
    x:=minX;
  end else begin
    if x>maxX then begin
      x:=maxX;
    end;
  end;
  if y<minY then begin
    y:=minY;
  end else begin
    if y>maxY then begin
      y:=maxY;
    end;
  end;
  if z<minZ then begin
    z:=minZ;
  end else begin
    if z>maxZ then begin
      z:=maxZ;
    end;
  end;
  dx:=sphereCenter.x-x;
  dy:=sphereCenter.y-y;
  dz:=sphereCenter.z-z;
  result:=dx*dx+dy*dy+dz*dz<=sphereRadius*sphereRadius;
end;

{ TSphere }

constructor TSphere.Init(const aCenter: TVec3; aRadius: single);
begin
  center:=aCenter;
  radius:=aRadius;
end;

function TSphere.ContainsPoint(const p: TVec3): boolean;
begin
  result:=center.Distance2(p) <= radius * radius;
end;

function TSphere.IntersectsSphere(const other: TSphere): boolean;
var
  rr: single;
begin
  rr:=radius + other.radius;
  result:=center.Distance2(other.center) <= rr * rr;
end;

function TSphere.IntersectsBox(const box:TBBox3):boolean;
begin
  result:=box.IntersectsSphere(center,radius);
end;

{ TRay }

constructor TRay.Init(const aOrigin, aDir: TVec3);
begin
  origin:=aOrigin;
  dir:=aDir;
end;

function TRay.IntersectsSphere(const sphere: TSphere; out t: single): boolean;
var
  m: TVec3;
  b, c, disc: double;
begin
  t:=0;
  m:=origin.Sub(sphere.center);
  b:=m.Dot(dir);
  c:=m.Dot(m) - sphere.radius * sphere.radius;

  if (c > 0) and (b > 0) then begin
    exit(false);
  end;

  disc:=b * b - c;
  if disc < 0 then begin
    exit(false);
  end;

  t:=-b - Sqrt(disc);
  if t < 0 then begin
    t:=0;
  end;
  result:=true;
end;

function TRay.IntersectsBox(const box:TBBox3;out tMin,tMax:single):boolean;
var
  tx1, tx2, ty1, ty2, tz1, tz2, invD, tmp: single;
begin
  tMin:=-MaxSingle;
  tMax:=MaxSingle;

  if Abs(dir.x) <= SpatialEpsilon then begin
    if (origin.x < box.minX) or (origin.x > box.maxX) then begin
      exit(false);
    end;
  end
  else
  begin
    invD:=1.0 / dir.x;
    tx1:=(box.minX - origin.x) * invD;
    tx2:=(box.maxX - origin.x) * invD;
    if tx1 > tx2 then begin
      tmp:=tx1;
      tx1:=tx2;
      tx2:=tmp;
    end;
    tMin:=Max(tMin, tx1);
    tMax:=Min(tMax, tx2);
  end;

  if Abs(dir.y) <= SpatialEpsilon then begin
    if (origin.y < box.minY) or (origin.y > box.maxY) then begin
      exit(false);
    end;
  end
  else
  begin
    invD:=1.0 / dir.y;
    ty1:=(box.minY - origin.y) * invD;
    ty2:=(box.maxY - origin.y) * invD;
    if ty1 > ty2 then begin
      tmp:=ty1;
      ty1:=ty2;
      ty2:=tmp;
    end;
    tMin:=Max(tMin, ty1);
    tMax:=Min(tMax, ty2);
  end;

  if Abs(dir.z) <= SpatialEpsilon then begin
    if (origin.z < box.minZ) or (origin.z > box.maxZ) then begin
      exit(false);
    end;
  end
  else
  begin
    invD:=1.0 / dir.z;
    tz1:=(box.minZ - origin.z) * invD;
    tz2:=(box.maxZ - origin.z) * invD;
    if tz1 > tz2 then begin
      tmp:=tz1;
      tz1:=tz2;
      tz2:=tmp;
    end;
    tMin:=Max(tMin, tz1);
    tMax:=Min(tMax, tz2);
  end;

  result:=(tMax >= Max(0.0, tMin));
end;

function TRay.IntersectsTriangle(const a, b, c: TVec3; out t, u, v: single): boolean;
var
  edge1, edge2, pvec, tvec, qvec: TVec3;
  det, invDet: double;
begin
  t:=0;
  u:=0;
  v:=0;

  edge1:=b.Sub(a);
  edge2:=c.Sub(a);
  pvec:=dir.Cross(edge2);
  det:=edge1.Dot(pvec);

  if Abs(det) <= SpatialEpsilon then begin
    exit(false);
  end;

  invDet:=1.0 / det;
  tvec:=origin.Sub(a);
  u:=tvec.Dot(pvec) * invDet;
  if (u < 0) or (u > 1) then begin
    exit(false);
  end;

  qvec:=tvec.Cross(edge1);
  v:=dir.Dot(qvec) * invDet;
  if (v < 0) or (u + v > 1) then begin
    exit(false);
  end;

  t:=edge2.Dot(qvec) * invDet;
  result:=t >= 0;
end;

function TRay.IntersectsPlane(const plane: TPlane; out t: single): boolean;
var
  dirDot, originDist: double;
begin
  dirDot:=plane.a * dir.x + plane.b * dir.y + plane.c * dir.z;
  originDist:=plane.a * origin.x + plane.b * origin.y + plane.c * origin.z + plane.d;

  if Abs(dirDot) <= SpatialEpsilon then begin
    t:=0;
    result:=Abs(originDist) <= SpatialEpsilon;
    exit;
  end;

  t:=-originDist / dirDot;
  result:=t >= 0;
end;

{ TFrustum }

procedure TFrustum.InitFromMVP(const mvp: TMat4; includeNearFar: boolean = true);
begin
  planeCount:=4;
  if includeNearFar then begin
    planeCount:=6;
  end;

  // near/far
  planes[0]:=QuaternionS(mvp[3, 0] + mvp[2, 0], mvp[3, 1] + mvp[2, 1], mvp[3, 2] + mvp[2, 2], mvp[3, 3] + mvp[2, 3]);
  planes[1]:=QuaternionS(mvp[3, 0] - mvp[2, 0], mvp[3, 1] - mvp[2, 1], mvp[3, 2] - mvp[2, 2], mvp[3, 3] - mvp[2, 3]);
  // left/right
  planes[2]:=QuaternionS(mvp[3, 0] + mvp[0, 0], mvp[3, 1] + mvp[0, 1], mvp[3, 2] + mvp[0, 2], mvp[3, 3] + mvp[0, 3]);
  planes[3]:=QuaternionS(mvp[3, 0] - mvp[0, 0], mvp[3, 1] - mvp[0, 1], mvp[3, 2] - mvp[0, 2], mvp[3, 3] - mvp[0, 3]);
  // top/bottom
  planes[4]:=QuaternionS(mvp[3, 0] - mvp[1, 0], mvp[3, 1] - mvp[1, 1], mvp[3, 2] - mvp[1, 2], mvp[3, 3] - mvp[1, 3]);
  planes[5]:=QuaternionS(mvp[3, 0] + mvp[1, 0], mvp[3, 1] + mvp[1, 1], mvp[3, 2] + mvp[1, 2], mvp[3, 3] + mvp[1, 3]);

  NormalizePlane(planes[0]);
  NormalizePlane(planes[1]);
  NormalizePlane(planes[2]);
  NormalizePlane(planes[3]);
  NormalizePlane(planes[4]);
  NormalizePlane(planes[5]);
end;

function TFrustum.IntersectsSphere(const sphere: TSphere): boolean;
var
  i: integer;
  d: single;
begin
  for i:=0 to planeCount - 1 do
  begin
    d:=TSpatial.DistanceToPlane(planes[i], sphere.center);
    if d < -sphere.radius then begin
      exit(false);
    end;
  end;
  result:=true;
end;

function TFrustum.IntersectsBox(const box:TBBox3):boolean;
var
  i: integer;
  p: TVec3;
begin
  if box.IsEmpty then begin
    exit(false);
  end;

  for i:=0 to planeCount - 1 do
  begin
    p:=SelectPositiveVertex(box, planes[i].x, planes[i].y, planes[i].z);
    if TSpatial.DistanceToPlane(planes[i], p) < 0 then begin
      exit(false);
    end;
  end;
  result:=true;
end;

{ TSpatial }

class function TSpatial.DistanceToPlane(const plane: TVec4; const p: TVec3): single;
begin
  result:=plane.x * p.x + plane.y * p.y + plane.z * p.z + plane.w;
end;

end.

