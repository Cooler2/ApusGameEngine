// Normal mapping demo for R-06 — uses the stock engine GPU-mesh pipeline.
// Mesh builders produce TMesh with positions/normals/uv0/tangents (w=handedness);
// TGpuMesh uploads them and draws via shader.NormalMap / shader.NormalMapOff.

unit NormalMapMain;
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
  SysUtils,
  Apus.Core, Apus.Colors, Apus.Geom2D, Apus.Geom3D,
  Apus.EventMan, Apus.Engine.Keys, Apus.Engine.UI, Apus.Engine.UIScene,
  Apus.Engine.Mesh, Apus.Engine.GpuMesh, Apus.Engine.MeshShapes,
  Apus.Engine.DebugDraw;

const
  TEX_SIZE = 256;
  OBJ_CUBE = 0;
  OBJ_TORUS = 1;
  OBJECT_COUNT = 2;
  MATERIAL_COUNT = 3;

type
  TDemoMaterial=record
    name:String8;
    colorMap,normalMap:TTexture;
  end;

  TMainScene=class(TUIScene)
    meshes:array[0..OBJECT_COUNT-1] of TGpuMesh;
    materials:array[0..MATERIAL_COUNT-1] of TDemoMaterial;
    cameraYaw,cameraPitch,cameraDist:single;
    lightYaw,lightPitch:single;
    objectID,materialID:integer;
    normalEnabled:boolean;
    computedNT:boolean; // true = MeshOps normals+tangents, false = analytic
    constructor Create;
    destructor Destroy; override;
    procedure InitGfx; override;
    procedure Render; override;
    procedure onMouseMove(x,y:integer); override;
    procedure onMouseWheel(delta:integer); override;
    procedure HandleKey(keyCode:integer);
  private
    function LightDir:TVec3;
    procedure RebuildMesh(id:integer);
    procedure DrawGrid;
    procedure DrawObject;
    procedure DrawOverlay;
  end;

var
  sceneMain:TMainScene;

function NormalColor(nx,ny,nz:single):cardinal;
var
  n:TVec3;
begin
  n:=Vec3(nx,ny,nz);
  n.Normalize;
  result:=Color.RGB(round(127.5+n.x*127.5),round(127.5+n.y*127.5),round(127.5+n.z*127.5));
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

function BuildCube(computed:boolean):TMesh;
begin
  result:=MeshShapes.Box(1.0);
  if computed then begin
    MeshOps.ComputeNormals(result);
    MeshOps.ComputeTangents(result);
  end;
end;

// computed=true: let MeshOps derive normals+tangents; false: analytic per-vertex values.
function BuildTorus(computed:boolean):TMesh;
const
  U_SEG = 64;
  V_SEG = 24;
var
  i,j,idx:integer;
  u,v,cu,su,cv,sv,tw:single;
  p,n,t:TVec3;
  r0,r1:single;
  attrs:TMeshAttributes;
  function VIdx(a,b:integer):integer; inline;
  begin
    result:=a*(V_SEG+1)+b;
  end;
begin
  result:=TMesh.Create('Torus');
  r0:=1.25;
  r1:=0.38;
  if computed then
    attrs:=[TMeshAttribute.Color,TMeshAttribute.UV0]
  else
    attrs:=[TMeshAttribute.Normal,TMeshAttribute.Color,TMeshAttribute.UV0,TMeshAttribute.Tangent];
  result.SetVertexCount((U_SEG+1)*(V_SEG+1),attrs);
  idx:=0;
  for i:=0 to U_SEG do begin
    u:=2*Pi*i/U_SEG;
    cu:=cos(u); su:=sin(u);
    for j:=0 to V_SEG do begin
      v:=2*Pi*j/V_SEG;
      cv:=cos(v); sv:=sin(v);
      p:=Vec3((r0+r1*cv)*cu,(r0+r1*cv)*su,r1*sv);
      result.positions[idx]:=p;
      result.colors[idx]:=$FFFFFFFF;
      result.uv0[idx]:=Vec2(i*4/U_SEG,j*2/V_SEG);
      if not computed then begin
        n:=Vec3(cv*cu,cv*su,sv);
        n.Normalize;
        t:=Vec3(su,-cu,0); // dP/du direction (ensures cross(T,N)=dP/dv)
        t.Normalize;
        result.normals[idx]:=n;
        result.tangents[idx]:=Vec4(t,1.0);
      end;
      inc(idx);
    end;
  end;
  SetLength(result.indices,U_SEG*V_SEG*6);
  idx:=0;
  for i:=0 to U_SEG-1 do
    for j:=0 to V_SEG-1 do begin
      result.indices[idx]  :=VIdx(i,j);
      result.indices[idx+1]:=VIdx(i+1,j);
      result.indices[idx+2]:=VIdx(i+1,j+1);
      result.indices[idx+3]:=VIdx(i,j);
      result.indices[idx+4]:=VIdx(i+1,j+1);
      result.indices[idx+5]:=VIdx(i,j+1);
      inc(idx,6);
    end;
  if computed then begin
    MeshOps.ComputeNormals(result);
    MeshOps.ComputeTangents(result);
    // weld periodic u-seam: VIdx(0,j) and VIdx(U_SEG,j) share the same position
    for j:=0 to V_SEG do begin
      n:=result.normals[VIdx(0,j)]+result.normals[VIdx(U_SEG,j)]; n.Normalize;
      result.normals[VIdx(0,j)]:=n; result.normals[VIdx(U_SEG,j)]:=n;
      t:=result.tangents[VIdx(0,j)].ToVec3+result.tangents[VIdx(U_SEG,j)].ToVec3; t.Normalize;
      tw:=result.tangents[VIdx(0,j)].w;
      result.tangents[VIdx(0,j)]:=Vec4(t,tw); result.tangents[VIdx(U_SEG,j)]:=Vec4(t,tw);
    end;
    // weld periodic v-seam: VIdx(i,0) and VIdx(i,V_SEG) share the same position
    for i:=0 to U_SEG do begin
      n:=result.normals[VIdx(i,0)]+result.normals[VIdx(i,V_SEG)]; n.Normalize;
      result.normals[VIdx(i,0)]:=n; result.normals[VIdx(i,V_SEG)]:=n;
      t:=result.tangents[VIdx(i,0)].ToVec3+result.tangents[VIdx(i,V_SEG)].ToVec3; t.Normalize;
      tw:=result.tangents[VIdx(i,0)].w;
      result.tangents[VIdx(i,0)]:=Vec4(t,tw); result.tangents[VIdx(i,V_SEG)]:=Vec4(t,tw);
    end;
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
  colorRow,normalRow:PCardinalRow;
  h,dx,dy:single;
  c:cardinal;
begin
  mat.name:=name;
  mat.colorMap:=AllocImage(TEX_SIZE,TEX_SIZE,TImagePixelFormat.ipfARGB,aiTexture,'NM_'+name+'_color');
  mat.normalMap:=AllocImage(TEX_SIZE,TEX_SIZE,TImagePixelFormat.ipfARGB,aiTexture,'NM_'+name+'_normal');
  mat.colorMap.Lock;
  mat.normalMap.Lock;
  for y:=0 to TEX_SIZE-1 do begin
    colorRow:=PCardinalRow(mat.colorMap.ScanLine(y));
    normalRow:=PCardinalRow(mat.normalMap.ScanLine(y));
    for x:=0 to TEX_SIZE-1 do begin
      h:=HeightAt(kind,x,y);
      case kind of
        0:if h<0.2 then c:=Color.RGB(58,55,52)
          else c:=Color.RGB(135+round(35*Noise2(x div 5,y div 5)),55+round(18*h),42);
        1:c:=Color.RGB(82+round(80*h),88+round(75*h),84+round(70*h));
      else
        c:=Color.RGB(48+round(50*h),96+round(110*h),135+round(80*h));
      end;
      colorRow^[x]:=c;
      // central difference gradient; negate because slope toward +X tilts normal toward -X
      dx:=HeightAt(kind,(x+1) mod TEX_SIZE,y)-HeightAt(kind,(x+TEX_SIZE-1) mod TEX_SIZE,y);
      dy:=HeightAt(kind,x,(y+1) mod TEX_SIZE)-HeightAt(kind,x,(y+TEX_SIZE-1) mod TEX_SIZE);
      normalRow^[x]:=NormalColor(-dx*3.0,-dy*3.0,1.0); // tangent-space normal encoded as RGB
    end;
  end;
  mat.colorMap.Unlock;
  mat.normalMap.Unlock;
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
  gameTitle:='Apus Engine: Normal Mapping (R-06)';
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
  computedNT:=false;
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
  inherited;
end;

procedure TMainScene.RebuildMesh(id:integer);
var
  m:TMesh;
begin
  meshes[id].Free;
  if id=OBJ_CUBE then m:=BuildCube(computedNT)
   else m:=BuildTorus(computedNT);
  meshes[id]:=TGpuMesh.Create(m);
  meshes[id].Upload;
  m.Free;
end;

procedure TMainScene.InitGfx;
var
  m:TMesh;
begin
  m:=BuildCube(computedNT);
  meshes[OBJ_CUBE]:=TGpuMesh.Create(m);
  meshes[OBJ_CUBE].Upload;
  m.Free;
  m:=BuildTorus(computedNT);
  meshes[OBJ_TORUS]:=TGpuMesh.Create(m);
  meshes[OBJ_TORUS].Upload;
  m.Free;
  FillMaterial(materials[0],0,'Bricks');
  FillMaterial(materials[1],1,'StoneNoise');
  FillMaterial(materials[2],2,'Waves');
  SetEventHandler('SCENE\MAIN\KEYDOWN',NormalMapKeyHandler,emInstant);
end;

function TMainScene.LightDir:TVec3;
begin
  // spherical → Cartesian; lightPitch=0 is horizontal, Pi/2 is straight up
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
    lightYaw:=lightYaw+dx*0.008;
    lightPitch:=Clamp(lightPitch-dy*0.006,0.08,1.45);
  end else
  if (window.mouseButtons and mbLeft)>0 then begin
    cameraYaw:=cameraYaw-dx*0.008;
    cameraPitch:=Clamp(cameraPitch+dy*0.01, -1.0, 1.0);
  end;
end;

procedure TMainScene.onMouseWheel(delta:integer);
begin
  inherited;
  if delta>0 then cameraDist:=cameraDist/1.12;
  if delta<0 then cameraDist:=cameraDist*1.12;
  cameraDist:=Clamp(cameraDist,3.2,18);
end;

procedure TMainScene.HandleKey(keyCode:integer);
var
  i:integer;
begin
  case keyCode of
    ord(TKey.D1),ord(TKey.Num1):objectID:=(objectID+1) mod OBJECT_COUNT;
    ord(TKey.D2),ord(TKey.Num2):materialID:=(materialID+1) mod MATERIAL_COUNT;
    ord(TKey.D3),ord(TKey.Num3),ord(TKey.N):normalEnabled:=not normalEnabled;
    ord(TKey.C): begin
      computedNT:=not computedNT;
      for i:=0 to OBJECT_COUNT-1 do RebuildMesh(i);
    end;
  end;
end;

procedure TMainScene.DrawGrid;
const
  OBJ_Z = 1.45; // object center height
var
  ld,tip,proj:TVec3;
  scale:single;
  lightDragging:boolean;
begin
  DebugDraw.SetupRender(true);
  DebugDraw.Grid(20,20,$FF2D3440,TGridPlane.XY);
  DebugDraw.Arrow2D(Vec3(0,0,0),Vec3(4,0,0),$FF3030E0); // X - blue
  DebugDraw.Arrow2D(Vec3(0,0,0),Vec3(0,4,0),$FF30C050); // Y - green
  // light direction arrow from object center toward the light source
  ld:=LightDir;
  scale:=4.5;
  tip:=Vec3(ld.x*scale,ld.y*scale,OBJ_Z+ld.z*scale);
  DebugDraw.Arrow2D(Vec3(0,0,OBJ_Z),tip,$FFFFCC00);
  lightDragging:=((window.mouseButtons and mbRight)>0) or
                 (((window.mouseButtons and mbLeft)>0) and ((window.shiftState and sscCtrl)>0));
  if lightDragging then begin
    proj:=Vec3(tip.x,tip.y,OBJ_Z);
    draw.Triangle(Vec3(0,0,OBJ_Z),proj,tip,$28FFEE88);
  end;
  DebugDraw.Flush;
  draw.SetZ(0);
end;

procedure TMainScene.DrawObject;
begin
  shader.DirectLight(LightDir,1.15,$FFF4E2); // warm white, slightly overbright
  shader.AmbientLight($292B33);
  if normalEnabled then
    shader.NormalMap(materials[materialID].normalMap,1.0)
  else
    shader.NormalMapOff;
  transform.SetObj(0,0,1.45,1.35,0,0,0);
  meshes[objectID].Draw(materials[materialID].colorMap);
  shader.NormalMapOff;
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
  txt.Write(0,18,22,$FFE8EDF5,'R-06 NormalMap (stock shader)');
  txt.Write(0,18,44,$FFC8D2DF,'LMB rotate camera  RMB/Ctrl+LMB rotate light  wheel zoom');
  txt.Write(0,18,66,$FFC8D2DF,'1 object: '+objName+'   2 material: '+materials[materialID].name+'   3/N normal map: '+nmState);
  if computedNT then
    txt.Write(0,18,88,$FFFFCC55,'C normals/tangents: MeshOps.Compute*  (C to switch)')
  else
    txt.Write(0,18,88,$FF88CCFF,'C normals/tangents: analytic/manual  (C to switch)');
end;

procedure TMainScene.Render;
var
  target,eye:TVec3;
begin
  gfx.target.Clear($111820,1);
  target:=Vec3(0,0,1.35);
  // spherical coords: XY shrink with pitch, Z rises with pitch
  eye:=Vec3(cameraDist*cos(cameraPitch)*cos(cameraYaw),
            cameraDist*cos(cameraPitch)*sin(cameraYaw),
            cameraDist*sin(cameraPitch));
  transform.Perspective(0.95,0.2,100);
  transform.SetCamera(eye,target,Vec3(0,0,1000));
  gfx.SetCullMode(cullCCW);
  gfx.clip.Nothing;
  DrawGrid;
  gfx.target.UseDepthBuffer(dbPassLess);
  DrawObject;
  gfx.clip.Restore;
  DrawOverlay;
  inherited;
end;

end.
