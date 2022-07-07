unit Apus.VertexLayout;
interface
uses Apus.Geom2D,Apus.Geom3D;

type
 // Components for TVertexLayout.Init()
 TVertexComponent=(
   vcPosition2d,
   vcPosition3d,
   vcNormal,
   vcColor,
   vcUV1,
   vcUV2,
   vcTangent,
   vcExtra4);
 // Packed description of the vertex layout
 // [0:3] - position (vec3s) (if offset=15 then position is vec2s at offset=0)
 // [4:7] - normal (vec3s)
 // [8:11]  - color (vec4b)
 // [12:15] - uv1 (vec2s)
 // [16:19] - uv2 (vec2s)
 // [20..23] - tangent (vec3s)
 // [24..27] - extra (vec4s)
 TVertexLayout=record
  layout:cardinal;
  stride:integer;
  procedure Init(position,normal,color,uv1,uv2:integer); overload;
  procedure Init(items:array of TVertexComponent); overload; // pass some TVertexComponent's
  function Equals(l:TVertexLayout):boolean; inline;
  // Field manipulation
  function GetPos(var vertex):TPoint3s;
  function GetColor(var vertex):cardinal;
  function GetNormal(var vertex):TVector3s;
  function GetUV(var vertex;idx:cardinal=0):TPoint2s;
  function DumpVertex(var vertex):string;
 private
  procedure GetField(var vertex;offset,size:integer;var target);
 end;

 // Basic vertex format for regular primitives
 PVertex=^TVertex;
 TVertex=packed record
  x,y,z:single;
  color:cardinal;
  u,v:single;
  procedure Init(x,y,z,u,v:single;color:cardinal=$FF808080); overload; inline;
  procedure Init(x,y,z:single;color:cardinal=$FF808080); overload;
  procedure Init(pos:TPoint3s;color:cardinal=$FF808080); overload;
  class var layoutTex,layoutNoTex:TVertexLayout;
 end;

 // Vertex format for double textured primitives
 PVertexDT=^TVertexDT;
 TVertexDT=packed record
  x,y,z:single;
  color:cardinal;
  u,v:single;
  u2,v2:single;
  procedure Init(x,y,z,u,v,u2,v2:single;color:cardinal); inline;
  class function Layout:TVertexLayout; static;
 end;

 // Vertex format for 3D objects with lighting
 PVertex3D=^TVertex3D;
 TVertex3D=packed record
  x,y,z:single;
  color:cardinal;
  nx,ny,nz:single;
  extra:single;
  u,v:single;
  procedure Init(x,y,z:single;color:cardinal=$FF808080); overload; inline;
  procedure Init(pos:TPoint3s;color:cardinal=$FF808080); overload;
  procedure SetPos(pos:TVector4s); overload; inline;
  procedure SetPos(pos:TVector3s); overload; inline;
  procedure SetNormal(nx,ny,nz:single); overload; inline;
  procedure SetNormal(n:TVector3s); overload;
  procedure SetUV(u,v:single); overload; inline;
  procedure SetUV(uv:TPoint2s); overload;
  class function Layout(hasUV:boolean=true):TVertexLayout; static;
 end;

implementation
 uses Apus.MyServis, Apus.Colors, SysUtils;

 function BuildVertexLayout(position,normal,color,uv1,uv2:integer):TVertexLayout;
  var
   size:integer;
  function Field(idx,value:integer):cardinal;
   begin
    ASSERT(value and 3=0);
    ASSERT(value<64);
    result:=(value shr 2) shl (idx*4);
    if value>0 then
     case idx of
      1:inc(size,3);
      2:inc(size,1);
      3:inc(size,2);
      4:inc(size,2);
     end;
   end;
  begin
   if position>=255 then begin
    position:=60;
    size:=2;
   end else
    size:=3;
   result.layout:=
     Field(0,position)+
     Field(1,normal)+
     Field(2,color)+
     Field(3,uv1)+
     Field(4,uv2);
   result.stride:=size*4;
  end;

{ TVertexLayout }

function TVertexLayout.DumpVertex(var vertex):string;
 var
  p:TPoint3s;
  p2:TPoint2s;
  c:cardinal;
 begin
  p:=GetPos(vertex);
  result:=Format('X=%f, Y=%f, Z=%f',[p.x,p.y,p.z]);
  p:=GetNormal(vertex);
  if p.IsValid then
   result:=result+Format(', nX=%f, nY=%f, nZ=%f',[p.x,p.y,p.z]);
  p2:=GetUV(vertex);
  if p2.IsValid then
   result:=result+Format(', u=%f, v=%f',[p2.x,p2.y]);
  c:=GetColor(vertex);
  if c<>InvalidColor then
   result:=result+Format(', c=%8x',[c]);
 end;

function TVertexLayout.Equals(l: TVertexLayout): boolean;
 begin
  result:=(l.layout=layout) and (l.stride=stride);
 end;

procedure TVertexLayout.GetField(var vertex;offset,size:integer;var target);
 var
  pb:PByte;
 begin
  pb:=@vertex;
  inc(pb,offset);
  move(pb^,target,size);
 end;

function TVertexLayout.GetColor(var vertex):cardinal;
 var
  p:integer;
 begin
  p:=(layout shr 8) and $F;
  if p>0 then GetField(vertex,(layout and $F00) shr 6,sizeof(result),result)
   else result:=InvalidColor;
 end;

function TVertexLayout.GetNormal(var vertex): TVector3s;
 var
  p:integer;
 begin
  p:=(layout shr 4) and $F;
  if p>0 then GetField(vertex,p*4,sizeof(result),result)
   else result:=InvalidPoint3s;
 end;

function TVertexLayout.GetPos(var vertex): TPoint3s;
 var
  v:cardinal;
 begin
  v:=layout and $F;
  if v=15 then begin
   GetField(vertex,0,8,result);
   result.z:=0;
  end else
   GetField(vertex,v*4,sizeof(result),result);
 end;

function TVertexLayout.GetUV(var vertex;idx:cardinal):TPoint2s;
 var
  p:integer;
 begin
  ASSERT(idx<2);
  case idx of
   0:p:=(layout shr 12) and $F;
   1:p:=(layout shr 16) and $F;
  end;
  if p>0 then GetField(vertex,p*4,sizeof(result),result)
   else result:=InvalidPoint2s;
 end;

procedure TVertexLayout.Init(items:array of TVertexComponent);
 var
  i,ofs:integer;
 begin
  layout:=0;
  ofs:=0;
  for i:=0 to high(items) do begin
   case items[i] of
    vcPosition2d:begin
     ASSERT(ofs=0,'Position2D must came first');
     SetBits(layout,0,4,15); inc(ofs,2);
    end;
    vcPosition3d:begin SetBits(layout,0,4,ofs); inc(ofs,3); end;
    vcNormal:    begin SetBits(layout,4,4,ofs); inc(ofs,3); end;
    vcColor:     begin SetBits(layout,8,4,ofs); inc(ofs,1); end;
    vcUV1:       begin SetBits(layout,12,4,ofs); inc(ofs,2); end;
    vcUV2:       begin SetBits(layout,16,4,ofs); inc(ofs,2); end;
    vcTangent:   begin SetBits(layout,20,4,ofs); inc(ofs,3); end;
    vcExtra4:    begin SetBits(layout,24,4,ofs); inc(ofs,4); end;
   end;
  end;
  stride:=ofs*4;
 end;

procedure TVertexLayout.Init(position,normal,color,uv1,uv2:integer);
 begin
  self:=BuildVertexLayout(position,normal,color,uv1,uv2);
 end;

{ TVertex }

procedure TVertex.Init(x,y,z,u,v:single;color:cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=u; self.v:=v;
 end;

procedure TVertex.Init(x,y,z:single;color:cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=0.5; self.v:=0.5;
 end;

procedure TVertex.Init(pos:TPoint3s;color:cardinal);
 begin
  Init(pos.x,pos.y,pos.z);
 end;

{ TVertexDT }

procedure TVertexDT.Init(x,y,z,u,v,u2,v2:single;color:cardinal);
 begin
  self.x:=x; self.y:=y; self.z:=z;
  self.color:=color;
  self.u:=u; self.v:=v;
  self.u2:=u2; self.v2:=v2;
 end;

class function TVertexDT.Layout:TVertexLayout;
 var
  v:PVertexDT;
 begin
  v:=nil;
  result.Init(0,0,integer(@v.color),integer(@v.u),integer(@v.u2));
  ASSERT(result.stride=sizeof(TVertexDT));
 end;

{ TVertex3D }

procedure TVertex3D.Init(x,y,z:single;color:cardinal);
 begin
  self.x:=x;
  self.y:=y;
  self.z:=z;
  self.color:=color;
 end;

procedure TVertex3D.Init(pos:TPoint3s;color:cardinal);
 begin
  Init(pos.x,pos.y,pos.z,color);
 end;

procedure TVertex3D.SetNormal(nx,ny,nz:single);
 begin
  self.nx:=nx;
  self.ny:=ny;
  self.nz:=nz;
 end;

procedure TVertex3D.SetNormal(n:TVector3s);
 begin
  SetNormal(n.x,n.y,n.z);
 end;

procedure TVertex3D.SetPos(pos:TVector4s);
 begin
  x:=pos.x;
  y:=pos.y;
  z:=pos.z;
 end;

procedure TVertex3D.SetPos(pos:TVector3s);
 begin
  x:=pos.x;
  y:=pos.y;
  z:=pos.z;
 end;

procedure TVertex3D.SetUV(uv:TPoint2s);
 begin
  SetUV(uv.x,uv.y);
 end;

procedure TVertex3D.SetUV(u,v:single);
 begin
  self.u:=u;
  self.v:=v;
 end;

class function TVertex3D.Layout(hasUV:boolean=true):TVertexLayout;
 var
  v:PVertex3D;
  uvPos:integer;
 begin
  v:=nil;
  if hasUV then
   uvPos:=integer(@v.u)
  else
   uvPos:=0;
  result.Init(0,integer(@v.nx),integer(@v.color),uvPos,0);
  result.stride:=Sizeof(TVertex3D);
 end;


end.
