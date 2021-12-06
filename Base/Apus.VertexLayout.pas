unit Apus.VertexLayout;
interface
uses Apus.Geom2D,Apus.Geom3D;

type
 // Packed description of the vertex layout
 // [0:3] - position (vec3s) (if offset=15 then position is vec2s at offset=0)
 // [4:7] - normal (vec3s)
 // [8:11]  - color (vec4b)
 // [12:15] - uv1 (vec2s)
 // [16:19] - uv2 (vec2s)
 TVertexLayout=record
  layout:cardinal;
  stride:integer;
  procedure Init(position,normal,color,uv1,uv2:integer);
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


implementation
 uses Apus.Colors, SysUtils;

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

procedure TVertexLayout.GetField(var vertex; offset, size: integer; var target);
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

function TVertexLayout.GetUV(var vertex; idx:cardinal):TPoint2s;
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

procedure TVertexLayout.Init(position, normal, color, uv1, uv2: integer);
 begin
  self:=BuildVertexLayout(position,normal,color,uv1,uv2);
 end;

end.
