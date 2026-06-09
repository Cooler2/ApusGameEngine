// Normal mapping prototype demo for R-06.
//
// This demo intentionally keeps tangent, shader and material code local.
// Once the visual path is stable, proven parts can be moved into engine APIs.

unit MainScene;
interface
uses Apus.Engine.GameApp, Apus.Engine.API;

type
  TMainApp=class(TGameApplication)
    constructor Create;
    procedure CreateScenes; override;
  end;

var
  application:TMainApp;

implementation
uses
  SysUtils, Math,
  Apus.Core, Apus.Geom3D, Apus.VertexLayout,
  Apus.EventMan, Apus.Engine.Keys, Apus.Engine.UI, Apus.Engine.UIScene;

const
  TEX_SIZE = 256;
  OBJ_CUBE = 0;
  OBJ_TORUS = 1;
  OBJECT_COUNT = 2;
  MATERIAL_COUNT = 3;

type
  TVertexNM=packed record
    x,y,z:single;
    nx,ny,nz:single;
    color:cardinal;
    u,v:single;
    tx,ty,tz:single;
  end;
  TVerticesNM=array of TVertexNM;

  TDemoMesh=class
    vertices:TVerticesNM;
    indices:array of word;
    layout:TVertexLayout;
    procedure Draw(tex:TTexture);
  end;

  TDemoMaterial=record
    name:String8;
    colorMap,normalMap:TTexture;
  end;

  TMainScene=class(TUIScene)
    meshes:array[0..OBJECT_COUNT-1] of TDemoMesh;
    materials:array[0..MATERIAL_COUNT-1] of TDemoMaterial;
    nmShader:TShader;
    cameraYaw,cameraPitch,cameraDist:single;
    lightYaw,lightPitch:single;
    objectID,materialID:integer;
    normalEnabled:boolean;
    constructor Create;
    destructor Destroy; override;
    procedure InitGfx; override;
    procedure Render; override;
    procedure onMouseMove(x,y:integer); override;
    procedure onMouseWheel(delta:integer); override;
    procedure HandleKey(keyCode:integer);
  private
    function LightDir:TVec3;
    procedure DrawGrid;
    procedure DrawObject;
    procedure DrawOverlay;
  end;

var
  sceneMain:TMainScene;

function ClampS(v,minV,maxV:single):single; inline;
begin
  if v<minV then result:=minV else
  if v>maxV then result:=maxV else
    result:=v;
end;

function ARGB(r,g,b:integer):cardinal; inline;
begin
  r:=EnsureRange(r,0,255);
  g:=EnsureRange(g,0,255);
  b:=EnsureRange(b,0,255);
  result:=$FF000000 or (cardinal(r) shl 16) or (cardinal(g) shl 8) or cardinal(b);
end;

function NormalColor(nx,ny,nz:single):cardinal;
var
  n:TVec3;
begin
  n:=Vec3(nx,ny,nz);
  n.Normalize;
  result:=ARGB(round(127.5+n.x*127.5),round(127.5+n.y*127.5),round(127.5+n.z*127.5));
end;

function Noise2(x,y:integer):single;
var
  n:cardinal;
begin
  n:=cardinal(x)*1973+cardinal(y)*9277+$68BC21EB;
  n:=n xor (n shr 13);
  n:=n*1274126177;
  result:=(n and $FFFF)/65535;
end;

procedure SetVertex(var v:TVertexNM;const p,n,t:TVec3;u,uv:single;color:cardinal);
begin
  v.x:=p.x; v.y:=p.y; v.z:=p.z;
  v.nx:=n.x; v.ny:=n.y; v.nz:=n.z;
  v.color:=color;
  v.u:=u; v.v:=uv;
  v.tx:=t.x; v.ty:=t.y; v.tz:=t.z;
end;

procedure AddVertex(var vertices:TVerticesNM;const p,n,t:TVec3;u,v:single;color:cardinal);
var
  idx:integer;
begin
  idx:=length(vertices);
  SetLength(vertices,idx+1);
  SetVertex(vertices[idx],p,n,t,u,v,color);
end;

procedure AddTrg(var indices:array of word;idx:integer;a,b,c:word);
begin
  indices[idx]:=a;
  indices[idx+1]:=b;
  indices[idx+2]:=c;
end;

procedure AddQuad(mesh:TDemoMesh;const p0,p1,p2,p3,n,t:TVec3);
var
  base,idx:integer;
begin
  base:=length(mesh.vertices);
  AddVertex(mesh.vertices,p0,n,t,0,0,$FFFFFFFF);
  AddVertex(mesh.vertices,p1,n,t,1,0,$FFFFFFFF);
  AddVertex(mesh.vertices,p2,n,t,1,1,$FFFFFFFF);
  AddVertex(mesh.vertices,p3,n,t,0,1,$FFFFFFFF);
  idx:=length(mesh.indices);
  SetLength(mesh.indices,idx+6);
  AddTrg(mesh.indices,idx,base,base+1,base+2);
  AddTrg(mesh.indices,idx+3,base,base+2,base+3);
end;

function BuildCube:TdemoMesh;
var
  s:single;
begin
  result:=TDemoMesh.Create;
  result.layout:=TVertexLayout.Create([vcPosition3d,vcNormal,vcColor,vcUV1,vcTangent]);
  s:=1.0;
  AddQuad(result,Vec3(-s,-s,-s),Vec3( s,-s,-s),Vec3( s, s,-s),Vec3(-s, s,-s),Vec3(0,0,-1),Vec3(1,0,0));
  AddQuad(result,Vec3(-s, s, s),Vec3( s, s, s),Vec3( s,-s, s),Vec3(-s,-s, s),Vec3(0,0, 1),Vec3(1,0,0));
  AddQuad(result,Vec3(-s,-s, s),Vec3( s,-s, s),Vec3( s,-s,-s),Vec3(-s,-s,-s),Vec3(0,-1,0),Vec3(1,0,0));
  AddQuad(result,Vec3( s, s, s),Vec3(-s, s, s),Vec3(-s, s,-s),Vec3( s, s,-s),Vec3(0, 1,0),Vec3(-1,0,0));
  AddQuad(result,Vec3( s,-s, s),Vec3( s, s, s),Vec3( s, s,-s),Vec3( s,-s,-s),Vec3(1,0,0),Vec3(0,1,0));
  AddQuad(result,Vec3(-s, s, s),Vec3(-s,-s, s),Vec3(-s,-s,-s),Vec3(-s, s,-s),Vec3(-1,0,0),Vec3(0,-1,0));
end;

function BuildTorus:TdemoMesh;
const
  U_SEG = 64;
  V_SEG = 24;
var
  i,j,idx:integer;
  u,v,cu,su,cv,sv:single;
  p,n,t:TVec3;
  r0,r1:single;
  function VIdx(a,b:integer):word; inline;
  begin
    result:=a*(V_SEG+1)+b;
  end;
begin
  result:=TDemoMesh.Create;
  result.layout:=TVertexLayout.Create([vcPosition3d,vcNormal,vcColor,vcUV1,vcTangent]);
  r0:=1.25;
  r1:=0.38;
  SetLength(result.vertices,(U_SEG+1)*(V_SEG+1));
  idx:=0;
  for i:=0 to U_SEG do begin
    u:=2*Pi*i/U_SEG;
    cu:=cos(u); su:=sin(u);
    for j:=0 to V_SEG do begin
      v:=2*Pi*j/V_SEG;
      cv:=cos(v); sv:=sin(v);
      p:=Vec3((r0+r1*cv)*cu,(r0+r1*cv)*su,r1*sv);
      n:=Vec3(cv*cu,cv*su,sv);
      n.Normalize;
      t:=Vec3(-su,cu,0);
      t.Normalize;
      SetVertex(result.vertices[idx],p,n,t,i/U_SEG,j/V_SEG,$FFFFFFFF);
      inc(idx);
    end;
  end;
  SetLength(result.indices,U_SEG*V_SEG*6);
  idx:=0;
  for i:=0 to U_SEG-1 do
    for j:=0 to V_SEG-1 do begin
      AddTrg(result.indices,idx,VIdx(i,j),VIdx(i+1,j),VIdx(i+1,j+1));
      AddTrg(result.indices,idx+3,VIdx(i,j),VIdx(i+1,j+1),VIdx(i,j+1));
      inc(idx,6);
    end;
end;

function HeightAt(kind,x,y:integer):single;
var
  bx,by,mortar:integer;
  fx,fy:single;
begin
  case kind of
    0:begin
      by:=y div 32;
      bx:=(x+(by and 1)*32) mod 64;
      mortar:=byte((bx<3) or (bx>60) or (y mod 32<3) or (y mod 32>29));
      if mortar>0 then
        result:=0.12
      else
        result:=0.72+0.10*sin((x+y)*0.17)+0.05*Noise2(x div 3,y div 3);
    end;
    1:begin
      result:=0.50+0.22*sin(x*0.11)+0.16*sin(y*0.07)+0.10*Noise2(x div 4,y div 4);
    end;
  else
    fx:=x/TEX_SIZE;
    fy:=y/TEX_SIZE;
    result:=0.5+0.35*sin((fx*8+0.4*sin(fy*20))*2*Pi)*sin(fy*12*Pi);
  end;
end;

procedure FillMaterial(var mat:TDemoMaterial;kind:integer;const name:String8);
var
  x,y:integer;
  colorRow,normalRow:PCardinal;
  h,dx,dy:single;
  c:cardinal;
begin
  mat.name:=name;
  mat.colorMap:=AllocImage(TEX_SIZE,TEX_SIZE,TImagePixelFormat.ipfARGB,aiTexture,'NM_'+name+'_color');
  mat.normalMap:=AllocImage(TEX_SIZE,TEX_SIZE,TImagePixelFormat.ipfARGB,aiTexture,'NM_'+name+'_normal');
  mat.colorMap.Lock;
  mat.normalMap.Lock;
  for y:=0 to TEX_SIZE-1 do begin
    colorRow:=PCardinal(UIntPtr(mat.colorMap.data)+UIntPtr(y*mat.colorMap.pitch));
    normalRow:=PCardinal(UIntPtr(mat.normalMap.data)+UIntPtr(y*mat.normalMap.pitch));
    for x:=0 to TEX_SIZE-1 do begin
      h:=HeightAt(kind,x,y);
      case kind of
        0:if h<0.2 then c:=ARGB(58,55,52)
          else c:=ARGB(135+round(35*Noise2(x div 5,y div 5)),55+round(18*h),42);
        1:c:=ARGB(82+round(80*h),88+round(75*h),84+round(70*h));
      else
        c:=ARGB(48+round(50*h),96+round(110*h),135+round(80*h));
      end;
      colorRow[x]:=c;
      dx:=HeightAt(kind,(x+1) mod TEX_SIZE,y)-HeightAt(kind,(x+TEX_SIZE-1) mod TEX_SIZE,y);
      dy:=HeightAt(kind,x,(y+1) mod TEX_SIZE)-HeightAt(kind,x,(y+TEX_SIZE-1) mod TEX_SIZE);
      normalRow[x]:=NormalColor(-dx*3.0,-dy*3.0,1.0);
    end;
  end;
  mat.colorMap.Unlock;
  mat.normalMap.Unlock;
end;

procedure TDemoMesh.Draw(tex:TTexture);
begin
  if (vertices=nil) or (indices=nil) then exit;
  Apus.Engine.API.draw.IndexedMesh(@vertices[0],layout,@indices[0],length(indices) div 3,length(vertices),tex);
end;

procedure NormalMapKeyHandler(event:TEventStr;tag:TTag);
var
  keyCode:integer;
begin
  if sceneMain=nil then exit;
  keyCode:=WordFromTag(tag,0);
  sceneMain.HandleKey(keyCode);
end;

constructor TMainApp.Create;
begin
  inherited;
  gameTitle:='Apus Engine: Normal Mapping Prototype';
  usedAPI:=gaOpenGL2;
  usedPlatform:=spDefault;
  useRealDPI:=false;
  windowWidth:=1440;
  windowHeight:=860;
  windowSizeable:=true;
  useTweakerScene:=false;
end;

procedure TMainApp.CreateScenes;
begin
  inherited;
  sceneMain:=TMainScene.Create;
  sceneMain.SetStatus(TSceneStatus.ssActive);
end;

constructor TMainScene.Create;
begin
  inherited Create('Main');
  cameraYaw:=0.7;
  cameraPitch:=0.4;
  cameraDist:=12;
  lightYaw:=0.65;
  lightPitch:=0.75;
  objectID:=OBJ_CUBE;
  materialID:=0;
  normalEnabled:=true;
end;

destructor TMainScene.Destroy;
var
  i:integer;
begin
  RemoveEventHandler(NormalMapKeyHandler);
  for i:=0 to high(meshes) do
    meshes[i].Free;
  for i:=0 to high(materials) do begin
    FreeImage(materials[i].colorMap);
    FreeImage(materials[i].normalMap);
  end;
  nmShader.Free;
  inherited;
end;

procedure TMainScene.InitGfx;
const
  VSH =
    '#version 330'#13#10+
    'uniform mat4 MVP;'#13#10+
    'uniform mat3 NormalMatrix;'#13#10+
    'layout (location=0) in vec3 position;'#13#10+
    'layout (location=1) in vec3 normal;'#13#10+
    'layout (location=2) in vec4 color;'#13#10+
    'layout (location=3) in vec2 texCoord;'#13#10+
    'layout (location=4) in vec3 tangent;'#13#10+
    'out vec3 vNormal;'#13#10+
    'out vec3 vTangent;'#13#10+
    'out vec2 vTexCoord;'#13#10+
    'void main(void)'#13#10+
    '{'#13#10+
    '  gl_Position = MVP*vec4(position,1.0);'#13#10+
    '  vNormal = normalize(NormalMatrix*normal);'#13#10+
    '  vTangent = normalize(NormalMatrix*tangent);'#13#10+
    '  vTexCoord = texCoord;'#13#10+
    '}';
  FSH =
    '#version 330'#13#10+
    'uniform sampler2D tex0;'#13#10+
    'uniform sampler2D tex1;'#13#10+
    'uniform vec3 lightDir;'#13#10+
    'uniform vec3 lightColor;'#13#10+
    'uniform vec3 ambientColor;'#13#10+
    'uniform int normalOn;'#13#10+
    'uniform float normalStrength;'#13#10+
    'in vec3 vNormal;'#13#10+
    'in vec3 vTangent;'#13#10+
    'in vec2 vTexCoord;'#13#10+
    'out vec4 fragColor;'#13#10+
    'void main(void)'#13#10+
    '{'#13#10+
    '  vec3 base = texture(tex0,vTexCoord).rgb;'#13#10+
    '  vec3 N = normalize(vNormal);'#13#10+
    '  vec3 T = normalize(vTangent - N*dot(N,vTangent));'#13#10+
    '  vec3 B = normalize(cross(N,T));'#13#10+
    '  if (normalOn!=0) {'#13#10+
    '    vec3 nm = texture(tex1,vTexCoord).rgb*2.0-1.0;'#13#10+
    '    nm.xy *= normalStrength;'#13#10+
    '    N = normalize(mat3(T,B,N)*nm);'#13#10+
    '  }'#13#10+
    '  float diff = max(dot(N,normalize(lightDir)),0.0);'#13#10+
    '  vec3 c = base*(ambientColor+lightColor*diff);'#13#10+
    '  fragColor = vec4(c,1.0);'#13#10+
    '}';
begin
  meshes[OBJ_CUBE]:=BuildCube;
  meshes[OBJ_TORUS]:=BuildTorus;
  FillMaterial(materials[0],0,'Bricks');
  FillMaterial(materials[1],1,'StoneNoise');
  FillMaterial(materials[2],2,'Waves');
  nmShader:=shader.Build(VSH,FSH);
  SetEventHandler('SCENE\MAIN\KEYDOWN',NormalMapKeyHandler,emInstant);
end;

function TMainScene.LightDir:TVec3;
begin
  result:=Vec3(cos(lightPitch)*cos(lightYaw),cos(lightPitch)*sin(lightYaw),sin(lightPitch));
  result.Normalize;
end;

procedure TMainScene.onMouseMove(x,y:integer);
var
  dx,dy:single;
begin
  inherited;
  dx:=x-window.oldMousePos.x;
  dy:=y-window.oldMousePos.y;
  if ((window.mouseButtons and mbRight)>0) or
     (((window.mouseButtons and mbLeft)>0) and ((window.shiftState and sscCtrl)>0)) then begin
    lightYaw:=lightYaw-dx*0.008;
    lightPitch:=ClampS(lightPitch-dy*0.006,0.08,1.45);
  end else
  if (window.mouseButtons and mbLeft)>0 then begin
    cameraYaw:=cameraYaw+dx*0.008;
  end;
end;

procedure TMainScene.onMouseWheel(delta:integer);
begin
  inherited;
  if delta>0 then cameraDist:=cameraDist/1.12;
  if delta<0 then cameraDist:=cameraDist*1.12;
  cameraDist:=ClampS(cameraDist,3.2,18);
end;

procedure TMainScene.HandleKey(keyCode:integer);
begin
  case keyCode of
    ord(TKey.D1),ord(TKey.Num1):objectID:=(objectID+1) mod OBJECT_COUNT;
    ord(TKey.D2),ord(TKey.Num2):materialID:=(materialID+1) mod MATERIAL_COUNT;
    ord(TKey.D3),ord(TKey.Num3),ord(TKey.N):normalEnabled:=not normalEnabled;
  end;
end;

procedure TMainScene.DrawGrid;
var
  i:integer;
  c:cardinal;
begin
  shader.Reset;
  shader.LightOff;
  shader.DefaultTexMode;
  transform.SetObj(0,0,0);
  draw.SetZ(0);
  gfx.target.UseDepthBuffer(dbPass);
  for i:=-10 to 10 do begin
    if i=0 then c:=$FF505866 else c:=$FF2D3440;
    draw.Line(-10,i,10,i,c);
    draw.Line(i,-10,i,10,c);
  end;
  draw.Line(0,0,4,0,$FF3030E0);
  draw.Line(4,0,3.55,0.20,$FF3030E0);
  draw.Line(4,0,3.55,-0.20,$FF3030E0);
  draw.Line(0,0,0,4,$FF30C050);
  draw.Line(0,4,0.20,3.55,$FF30C050);
  draw.Line(0,4,-0.20,3.55,$FF30C050);
  draw.SetZ(0);
end;

procedure TMainScene.DrawObject;
var
  ld:TVec3;
begin
  shader.UseCustom(nmShader);
  ld:=LightDir;
  shader.SetUniform('lightDir',ld);
  shader.SetUniform('lightColor',Vec3(1.15,1.10,1.02));
  shader.SetUniform('ambientColor',Vec3(0.16,0.17,0.20));
  shader.SetUniform('normalStrength',1.0);
  if normalEnabled then
    shader.SetUniform('normalOn',1)
  else
    shader.SetUniform('normalOn',0);
  shader.UseTexture(materials[materialID].normalMap,1);
  transform.SetObj(0,0,1.45,1.35,0,0,0);
  meshes[objectID].Draw(materials[materialID].colorMap);
  shader.Reset;
end;

procedure TMainScene.DrawOverlay;
var
  x,y,s:integer;
  objName,nmState:String8;
begin
  transform.DefaultView;
  gfx.target.UseDepthBuffer(dbDisabled);
  shader.Reset;
  shader.LightOff;
  shader.DefaultTexMode;
  x:=window.renderWidth-234;
  y:=28;
  s:=96;
  draw.FillRect(x-14,y-20,x+s+14,y+s*2+92,$A020242C);
  txt.Write(0,x,y-8,$FFE8EDF5,'Color map');
  draw.Scaled(x,y+8,x+s,y+8+s,materials[materialID].colorMap,$FFFFFFFF);
  txt.Write(0,x,y+s+22,$FFE8EDF5,'Normal map');
  draw.Scaled(x,y+s+38,x+s,y+s*2+38,materials[materialID].normalMap,$FFFFFFFF);
  if objectID=OBJ_CUBE then objName:='Cube' else objName:='Torus';
  if normalEnabled then nmState:='ON' else nmState:='OFF';
  txt.Write(0,18,22,$FFE8EDF5,'R-06 NormalMap prototype');
  txt.Write(0,18,44,$FFC8D2DF,'LMB rotate camera around vertical axis, RMB/Ctrl+LMB rotate light, wheel zoom');
  txt.Write(0,18,66,$FFC8D2DF,'1 object: '+objName+'   2 material: '+materials[materialID].name+'   3/N normal map: '+nmState);
end;

procedure TMainScene.Render;
var
  target,eye:TVec3;
begin
  gfx.target.Clear($111820,1);
  target:=Vec3(0,0,1.35);
  eye:=Vec3(cameraDist*cos(cameraYaw),cameraDist*sin(cameraYaw),cameraDist*cameraPitch);
  transform.Perspective(0.95,0.2,100);
  transform.SetCamera(eye,target,Vec3(0,0,1000));
  gfx.SetCullMode(cullNone);
  gfx.clip.Nothing;
  DrawGrid;
  gfx.target.UseDepthBuffer(dbPassLess);
  DrawObject;
  gfx.clip.Restore;
  DrawOverlay;
  inherited;
end;

end.
