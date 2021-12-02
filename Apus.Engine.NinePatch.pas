// Nine Patch library - compatible with Android 9-patches, but supports extended features such as overlapping
//
// Copyright (C) 2021 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.NinePatch;
interface
uses Apus.Engine.API;

type
 // 9-Patches can be created from marked images as well as from raw images
 // Marked images contain color codes on the 1px border:
 // * Transparent - fixed part
 // * Red - fixed part (overlapped)
 // * Black - resizeable part (stretched)
 // * Green - resizeable part (tiled)
 TCustomNinePatch=class(TNinePatch)
  constructor Create(fromImage:TTexture); // create a 9-patch from a marked image
  procedure Draw(x,y,width,height:single;scale:single=1.0); override;
 protected
  meshWidth,meshHeight:single;
  mesh:TMesh;
  tex:TTexture;
  procedure BuildMeshForSize(width,height:single);
 private
 type
  TRangeType=(
    rtFixed, // fixed part (may overlap) - draw above others
    rtStretched,
    rtTiled);
  TPatchRange=record
    pFrom,pTo:integer;
    overlap1,overlap2:byte;
    rType:TRangeType;
  end;
  TGridArray=array[0..9] of single;
  TIntGridArray=array[0..9] of integer;
 var
  overlapped,tiled:boolean;
  hRanges,vRanges:array of TPatchRange;
  hWeights,vWeights:array of single;
  padLeft,padTop,padRight,padBottom:integer;
  usedCells:array of cardinal; // bitmap of cell status (1 - cell is empty)
  numCells:integer; // total number of non-empty cells

  procedure BuildRanges(tex:TTexture);
  procedure CheckCells;
  procedure CalcWeights;
  procedure ClearBorder(tex:TTexture);
  procedure CalcSizes;
  procedure ResizeGrid(reqWidth,reqHeight:single;var xx,yy:TGridArray);
  function CreateSimpleMesh(nH,nW:integer;du,dv:single):TMesh;
  function CreateOverlappedMesh(nH,nW:integer;du,dv:single):TMesh;
  function CreateTiledMesh(nH,nW:integer;du,dv:single;var xx,yy:TGridArray):TMesh;
  procedure AdjustSimpleMesh(nW,nH:Integer;var xx,yy:TGridArray);
  procedure AdjustOverlappedMesh(nW,nH:Integer;var xx,yy:TGridArray);
  procedure BuildTiledGrid(var xx,yy:TGridArray;var x1,y1,x2,y2:TGridArray;var gridW,gridH:TIntGridArray);
  function PassForCell(row,col:integer):integer; // returns 0..2
 end;

implementation
uses SysUtils, Apus.MyServis, Apus.FastGFX, Apus.Colors, Apus.Engine.ImageTools;

type
 TPatchRange=TCustomNinePatch.TPatchRange;

// Returns:
// 0 - transparent
// 1 - red
// 2 - black
// 3 - green
function ColorKey(color:cardinal):byte;
 var
  cVal:cardinal;
  c:TARGBColor absolute cVal;
 begin
  cVal:=color;
  if c.a<128 then result:=0
  else
  if c.r>128 then result:=1
  else
  if c.g>128 then result:=3
  else
   result:=2;
 end;

// Returns true if overlapped
function MakeRange(img:TTexture; x,y,dx,dy:integer; var range:TPatchRange):boolean;
 var
  key:byte;
  overlap:byte;
 begin
  key:=ColorKey(GetPixel(x,y));
  case key of
   2:range.rType:=rtStretched;
   3:range.rType:=rtTiled;
   else
    range.rType:=rtFixed;
  end;
  range.overlap1:=0;
  range.overlap2:=0;
  if key=1 then begin
   range.overlap1:=1;
   overlap:=1;
  end else
   overlap:=2;
  if dx=1 then range.pFrom:=x
   else range.pFrom:=y;
  range.pTo:=range.pFrom;
  while (x<img.width-2) and (y<img.height-2) do begin
   x:=x+dx; y:=y+dy;
   key:=ColorKey(GetPixel(x,y));
   case range.rType of
    rtTiled:if key<>3 then break;
    rtStretched:if key<>2 then break;
    rtFixed:begin
      case key of
       0:overlap:=2;
       1:if overlap=1 then inc(range.overlap1)
          else inc(range.overlap2);
       2,3:break;
      end;
    end;
   end;
   inc(range.pTo);
  end;
  result:=range.overlap1+range.overlap2>0;
 end;

{ TPatchInfo }

procedure TCustomNinePatch.BuildRanges(tex:TTexture);
 var
  x,y,i,n:integer;
 begin
   // Top line
   x:=1; y:=0;
   while x<tex.width-1 do begin
    n:=length(hRanges);
    SetLength(hRanges,n+1);
    MakeRange(tex,x,y,1,0,hRanges[n]);
    with hRanges[n] do begin
     if rType=rtTiled then tiled:=true;
     if overlap1+overlap2>0 then overlapped:=true;
     x:=pTo+1;
    end;
   end;
   // Left line
   x:=0; y:=1;
   while y<tex.height-1 do begin
    n:=length(vRanges);
    SetLength(vRanges,n+1);
    MakeRange(tex,x,y,0,1,vRanges[n]);
    with vRanges[n] do begin
     if rType=rtTiled then tiled:=true;
     if overlap1+overlap2>0 then overlapped:=true;
     y:=pTo+1;
    end;
   end;
  // Too many cells?
  ASSERT((length(hRanges)<8) and (length(vRanges)<8));
 end;

// Check cells content and mark non-transparent cells to draw (so full transparent cells will be skipped)
procedure TCustomNinePatch.CheckCells;
 var
  i,j,x,y:integer;
 begin
   // Mark empty cells
   SetLength(usedCells,length(vRanges));
   numCells:=0;
   for i:=0 to high(usedCells) do begin
    for j:=0 to high(hRanges) do begin
     // try to find non-transparent pixels (every 4-th pixel is checked)
     y:=vRanges[i].pFrom;
     while y<=vRanges[i].pTo do begin
      x:=hRanges[j].pFrom+(y and 1);
      while x<=hRanges[j].pTo do begin
       if GetPixel(x,y) shr 24>4 then begin // pixels with alpha below 4 are considered transparent
        SetBit(usedCells[i],j);
        inc(numCells);
        inc(y,10000);
        break;
       end;
       inc(x,2);
      end;
      inc(y,2);
     end;
    end;
   end;
 end;

procedure TCustomNinePatch.CalcWeights;
 var
  i,n:integer;
 begin
   SetLength(hWeights,length(hRanges));
   n:=0;
   for i:=0 to high(hRanges) do
    with hRanges[i] do
     if rType<>rtFixed then begin
      inc(n,1+pTo-pFrom);
      hWeights[i]:=1+pTo-pFrom;
     end;

   ASSERT(n>0);
   for i:=0 to high(hWeights) do
    hWeights[i]:=hWeights[i]/n;

   SetLength(vWeights,length(vRanges));
   n:=0;
   for i:=0 to high(vRanges) do
    with vRanges[i] do
     if rType<>rtFixed then begin
      inc(n,1+pTo-pFrom);
      vWeights[i]:=1+pTo-pFrom;
     end;

   ASSERT(n>0);
   for i:=0 to high(vWeights) do
    vWeights[i]:=vWeights[i]/n;
 end;

procedure TCustomNinePatch.ClearBorder;
 var
  x,y:integer;
  c:cardinal;
 begin
   y:=tex.height-1;
   for x:=1 to tex.width-2 do begin
    // top line
    c:=GetPixel(x,1);
    c:=ReplaceAlpha(c,0);
    PutPixel(x,0,c);
    // bottom line
    c:=GetPixel(x,y-1);
    c:=ReplaceAlpha(c,0);
    PutPixel(x,y,c);
   end;
   x:=tex.width-1;
   for y:=1 to tex.height-2 do begin
    // left line
    c:=GetPixel(1,y);
    c:=ReplaceAlpha(c,0);
    PutPixel(0,y,c);
    // right line
    c:=GetPixel(x-1,y);
    c:=ReplaceAlpha(c,0);
    PutPixel(x,y,c);
   end;
   // Corner pixels
   x:=tex.width-1;
   y:=tex.height-1;
   c:=ColorMix(GetPixel(0,1),GetPixel(1,0),128);
   PutPixel(0,0,c);
   c:=ColorMix(GetPixel(x,1),GetPixel(x-1,0),128);
   PutPixel(x,0,c);
   c:=ColorMix(GetPixel(y,1),GetPixel(y-1,0),128);
   PutPixel(0,y,c);
   c:=ColorMix(GetPixel(x,y-1),GetPixel(x-1,y),128);
   PutPixel(x,y,c);
 end;

procedure TCustomNinePatch.CalcSizes;
 var
  i,v:integer;
 begin
  // Base dimensions
  baseWidth:=0;
  for i:=0 to high(hRanges) do begin
   with hRanges[i] do
    v:=pTo-pFrom+1-overlap1-overlap2;
   inc(baseWidth,v);
  end;
  baseHeight:=0;
  for i:=0 to high(vRanges) do begin
   with vRanges[i] do
    v:=pTo-pFrom+1-overlap1-overlap2;
   inc(baseHeight,v);
  end;
  // Min dimensions
  minWidth:=0;
  for i:=0 to high(hRanges) do
   with hRanges[i] do
    if rType=rtFixed then
     inc(minWidth,1+pTo-pFrom);
  minHeight:=0;
  for i:=0 to high(vRanges) do
   with vRanges[i] do
    if rType=rtFixed then
     inc(minHeight,1+pTo-pFrom);
 end;

procedure TCustomNinePatch.ResizeGrid(reqWidth,reqHeight:single;var xx,yy:TGridArray);
 var
  i:integer;
  addW,addH:single;
 begin
  addW:=reqWidth-baseWidth;
  addH:=reqHeight-baseHeight;
  xx[0]:=0;
  for i:=0 to high(hRanges) do
   with hRanges[i] do begin
    xx[i+1]:=xx[i]+(1+pTo-pFrom);
    if rType<>rtFixed then begin
     xx[i+1]:=xx[i+1]+addW*hWeights[i];
     // overlap?
     if i>0 then
      xx[i+1]:=xx[i+1]-hRanges[i-1].overlap2;
     if i<high(hRanges) then
      xx[i+1]:=xx[i+1]-hRanges[i+1].overlap1;
    end;
   end;

  yy[0]:=0;
  for i:=0 to high(vRanges) do
   with vRanges[i] do begin
    yy[i+1]:=yy[i]+(1+pTo-pFrom);
    if rType<>rtFixed then begin
     yy[i+1]:=yy[i+1]+addH*vWeights[i];
     // Overlap?
     if i>0 then
      yy[i+1]:=yy[i+1]-vRanges[i-1].overlap2;
     if i<high(vRanges) then
      yy[i+1]:=yy[i+1]-vRanges[i+1].overlap1;
    end;
   end;
 end;

function TCustomNinePatch.CreateSimpleMesh(nH,nW:integer;du,dv:single):TMesh;
 var
  i,j,base:integer;
  vrt:TVertex;
  u,v:single;
 begin
   result:=TMesh.Create(TVertex.layoutTex,(nW+1)*(nH+1),numCells*6);
   // Fill vertices
   for i:=0 to nH do begin
     if i<nH then v:=vRanges[i].pFrom*dv
             else v:=1-dv;
     for j:=0 to nW do begin
      if j<nW then u:=hRanges[j].pFrom*du
              else u:=1-du;
      vrt.Init(0,0,0,u,v,$FF808080); // position will be filled later
      result.AddVertex(vrt);
     end;
   end;
   // Fill indices
   for i:=0 to nH-1 do
    for j:=0 to nW-1 do
     if GetBit(usedCells[i],j) then begin
      base:=i*(nW+1)+j; // base index
      result.AddTrg(base,base+1,base+2+nW);
      result.AddTrg(base,base+2+nW,base+1+nW);
     end;
 end;

function TCustomNinePatch.CreateOverlappedMesh(nH,nW:integer;du,dv:single):TMesh;
 var
  i,j,base,pass:integer;
  vrt:TVertex;
  u1,v1,u2,v2:single;
 begin
   result:=TMesh.Create(TVertex.layoutTex,numCells*4,numCells*6);
   base:=0;
   // Fill vertices
   for pass:=0 to 2 do
    for i:=0 to nH-1 do begin
     v1:=vRanges[i].pFrom*dv;
     v2:=vRanges[i].pTo*dv+dv;
     for j:=0 to nW-1 do
      if GetBit(usedCells[i],j) then begin
       if pass<>PassForCell(i,j) then continue;
       u1:=hRanges[j].pFrom*du;
       u2:=hRanges[j].pTo*du+du;
       // Define 4 vertices for a quad
       vrt.Init(0,0,0,u1,v1,$FF808080); // position will be filled later
       result.AddVertex(vrt);
       vrt.Init(0,0,0,u2,v1,$FF808080);
       result.AddVertex(vrt);
       vrt.Init(0,0,0,u2,v2,$FF808080);
       result.AddVertex(vrt);
       vrt.Init(0,0,0,u1,v2,$FF808080);
       result.AddVertex(vrt);
       // 1-st triangle
       result.AddTrg(base,base+1,base+2);
       // 2-nd triangle
       result.AddTrg(base,base+2,base+3);
       inc(base,4);
      end;
    end;
 end;

function CalcGridSize(size,tileSize:single):integer;
 begin
  size:=size-1.01;
  result:=1+2*trunc(0.5+size/(tileSize*2));
 end;

procedure FillCellMesh(mesh:TMesh; x1,y1,x2,y2, u1,v1,u2,v2, tileWidth,tileHeight:single);
 var
  vrt:TVertex;
  i,j,w,h,base:integer;
  x,y,xx,yy,x0,y0,k:single;
  tu1,tu2,tv1,tv2:single;
 begin
  // Base corner of the central tile
  x0:=(x1+x2-tileWidth)/2;
  y0:=(y1+y2-tileHeight)/2;
  // Amount of tiles
  w:=CalcGridSize(x2-x1,tileWidth);
  h:=CalcGridSize(y2-y1,tileHeight);
  x0:=x0-(w div 2)*tileWidth;
  y0:=y0-(h div 2)*tileHeight;
  for i:=0 to h-1 do
   for j:=0 to w-1 do begin
     // temp values
     x:=x0+j*tileWidth;
     y:=y0+i*tileHeight;
     xx:=x+tileWidth;
     yy:=y+tileHeight;
     tu1:=u1; tv1:=v1;
     tu2:=u2; tv2:=v2;
     if x<x1 then begin
      k:=(x1-x+0.5)/tileWidth;
      tu1:=u1+(u2-u1)*k;
      x:=x1;
     end;
     if xx>x2 then begin
      k:=(xx-x2-0.5)/tileWidth;
      tu2:=u2-(u2-u1)*k;
      xx:=x2;
     end;
     if y<y1 then begin
      k:=(y1-y+0.5)/tileHeight;
      tv1:=v1+(v2-v1)*k;
      y:=y1;
     end;
     if yy>y2 then begin
      k:=(yy-y2-0.5)/tileHeight;
      tv2:=v2-(v2-v1)*k;
      yy:=y2;
     end;
     // Add quad
     base:=mesh.vPos;
     vrt.Init(x,y,0,tu1,tv1,$FF808080);
     mesh.AddVertex(vrt);
     vrt.Init(xx,y,0,tu2,tv1,$FF808080);
     mesh.AddVertex(vrt);
     vrt.Init(xx,yy,0,tu2,tv2,$FF808080);
     mesh.AddVertex(vrt);
     vrt.Init(x,yy,0,tu1,tv2,$FF808080);
     mesh.AddVertex(vrt);
     // Add triangles
     mesh.AddTrg(base,base+1,base+2);
     mesh.AddTrg(base,base+2,base+3);
   end;
 end;

function TCustomNinePatch.CreateTiledMesh(nH,nW:integer;du,dv:single;var xx,yy:TGridArray):TMesh;
 var
  i,j,pass,tileCount:integer;
  gridW,gridH:TIntGridArray;
  x1,y1,x2,y2:TGridArray;
  u1,v1,u2,v2:single;
  tileWidth,tileHeight:single;
 begin
  BuildTiledGrid(xx,yy, x1,y1,x2,y2,gridW,gridH);
  // Calculate mesh size
  tileCount:=0;
  for i:=0 to nH-1 do
   for j:=0 to nW-1 do
    if GetBit(usedCells[i],j) then begin
     inc(tileCount,gridW[j]*gridH[i]);
    end;
  // Create mesh
  result:=TMesh.Create(DEFAULT_VERTEX_LAYOUT,tileCount*4,tileCount*6);
  // Fill mesh
  for pass:=0 to 2 do
   for i:=0 to nH-1 do begin
     v1:=vRanges[i].pFrom*dv+dv/2;
     v2:=vRanges[i].pTo*dv+dv/2;
     tileHeight:=vRanges[i].pTo-vRanges[i].pFrom;
     for j:=0 to nW-1 do
      if GetBit(usedCells[i],j) then begin
       if pass<>PassForCell(i,j) then continue;
       u1:=hRanges[j].pFrom*du+du/2;
       u2:=hRanges[j].pTo*du+du/2;
       tileWidth:=hRanges[j].pTo-hRanges[j].pFrom;
       FillCellMesh(result, x1[j],y1[i],x2[j],y2[i], u1,v1,u2,v2, tileWidth,tileHeight);
     end;
   end;
 end;

function TCustomNinePatch.PassForCell(row,col:integer):integer;
 begin
  result:=0;
  if vRanges[row].rType=rtFixed then inc(result);
  if hRanges[col].rType=rtFixed then inc(result);
 end;

// Simple 9-patch mesh
procedure TCustomNinePatch.AdjustSimpleMesh(nW,nH:Integer;var xx,yy:TGridArray);
 var
  i,j:Integer;
  pVrt:PVertex;
 begin
  pVrt:=mesh.vertices;
  for i:=0 to nH do
    for j:=0 to nW do
    begin
      pVrt.x:=xx[j];
      pVrt.y:=yy[i];
      inc(pVrt);
    end;
 end;

// Overlapped 9-patch
procedure TCustomNinePatch.AdjustOverlappedMesh(nW,nH:Integer;var xx,yy:TGridArray);
 var
  i,j,pass:integer;
  pVrt:PVertex;
  x1,y1,x2,y2:single;
 begin
  pVrt:=mesh.vertices;
  for pass:=0 to 2 do
   for i:=0 to nH-1 do
    for j:=0 to nW-1 do
     if GetBit(usedCells[i],j) then
      if pass=PassForCell(i,j) then begin
       // Calculate cell position
       x1:=xx[j];
       if j>0 then x1:=x1-hRanges[j-1].overlap2;
       x2:=xx[j+1];
       if j<nW-1 then x2:=x2+hRanges[j+1].overlap1;
       y1:=yy[i];
       if i>0 then y1:=y1-vRanges[i-1].overlap2;
       y2:=yy[i+1];
       if i<nH-1 then y2:=y2+vRanges[i+1].overlap1;
       // Update vertices
       pVrt.x:=x1;
       pVrt.y:=y1;
       inc(pVrt);
       pVrt.x:=x2;
       pVrt.y:=y1;
       inc(pVrt);
       pVrt.x:=x2;
       pVrt.y:=y2;
       inc(pVrt);
       pVrt.x:=x1;
       pVrt.y:=y2;
       inc(pVrt);
     end;
 end;

procedure TCustomNinePatch.BuildTiledGrid(var xx,yy:TGridArray;var x1,y1,x2,y2:TGridArray;var gridW,gridH:TIntGridArray);
var
  i,nW,nH:Integer;
begin
  nW:=length(hRanges);
  nH:=length(vRanges);
  // Build overlapped grid for tiled patch
  for i:=0 to nW-1 do
  begin
    x1[i]:=xx[i];
    x2[i]:=xx[i+1];
    if hRanges[i].rType<>rtFixed then begin
      if i>0 then
       x1[i]:=x1[i]-hRanges[i-1].overlap2;
      if i<nW then
       x2[i]:=x2[i]+hRanges[i+1].overlap1;
      gridW[i]:=CalcGridSize(x2[i]-x1[i],hRanges[i].pTo-hRanges[i].pFrom);
    end else
     gridW[i]:=1;
  end;
  for i:=0 to nH-1 do
  begin
    y1[i]:=yy[i];
    y2[i]:=yy[i+1];
    if vRanges[i].rType<>rtFixed then
    begin
      if i>0 then
       y1[i]:=y1[i]-vRanges[i-1].overlap2;
      if i<nW then
       y2[i]:=y2[i]+vRanges[i+1].overlap1;
      gridH[i]:=CalcGridSize(y2[i]-y1[i],vRanges[i].pTo-vRanges[i].pFrom);
    end
    else
     gridH[i]:=1;
  end;
end;

{ TNinePatch }
procedure TCustomNinePatch.BuildMeshForSize(width,height:single);
 var
  i,j,nH,nW:integer;
  du,dv:single;
  xx,yy:TGridArray;
 begin
  if tiled and (mesh<>nil) then FreeAndNil(mesh); // Always rebuild mesh for a complex tiled patch
  nW:=length(hRanges);
  nH:=length(vRanges);
  if mesh=nil then begin
   du:=1/tex.width;
   dv:=1/tex.height;
   if not (overlapped or tiled) then begin
     // Indexed mesh for a regular 9-patch (simple case)
     mesh:=CreateSimpleMesh(nH,nW,du,dv);
   end else
   if not tiled then begin
     // Non-indexed mesh for an overlapped 9-patch
     mesh:=CreateOverlappedMesh(nH,nW,du,dv);
   end else begin
     // Tiled patch - complex case
     // Such mesh is always created for specific size and not adjusted later
     ResizeGrid(width,height,xx,yy);
     mesh:=CreateTiledMesh(nH,nW,du,dv,xx,yy);
   end;
  end;
  // Adjust previously created mesh
  if not tiled then begin
   // Adjust patch grid
   ResizeGrid(width,height,xx,yy);
   // Adjust vertices
   if not overlapped then
    AdjustSimpleMesh(nW,nH,xx,yy)
   else
    AdjustOverlappedMesh(nW,nH,xx,yy);
  end;
  // Remember new mesh dimensions for reuse
  meshWidth:=width; meshHeight:=height;
 end;

constructor TCustomNinePatch.Create(fromImage: TTexture);
 var
  x,y,n:integer;
 begin
  ASSERT((fromImage.width>=3) and (fromImage.height>=3));
  scaleFactor:=1;
  tex:=fromImage;
  name:=tex.name;
  overlapped:=false;
  tiled:=false;
  EditImage(tex);
  try
   BuildRanges(tex); // determine range areas
   // TODO: bottom-right lines
   CheckCells;
   CalcWeights;
   ClearBorder(tex);   // Clear border pixels
  finally
   tex.Unlock;
  end;
  CalcSizes;
 end;

procedure TCustomNinePatch.Draw(x,y,width,height:single;scale:single);
 var
  rWidth,rHeight:single;
 begin
  scale:=scale*scaleFactor;
  rWidth:=width/scale;
  rHeight:=height/scale;
  if (meshWidth<>rWidth) or (meshHeight<>rHeight) then
   BuildMeshForSize(rWidth,rHeight);
  transform.SetObj(x-0.5,y-0.5,0,scale);
  mesh.DumpVertex(0);
  mesh.Draw(tex);
  transform.ResetObj;
 end;

end.
