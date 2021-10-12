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
  destructor Destroy; override;
  procedure Draw(x,y,width,height:single;scale:single=1.0); override;
 protected
  patchInfo:TObject;
  meshWidth,meshHeight:single;
  mesh:TMesh;
  tex:TTexture;
  procedure BuildMeshForSize(w,h:single);
 end;

implementation
uses Apus.MyServis, Apus.FastGFX, Apus.Colors, Apus.Engine.ImageTools;

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

 TPatchInfo=class
  overlapped,tiled:boolean;
  hRanges,vRanges:array of TPatchRange;
  hWeights,vWeights:array of single;
  padLeft,padTop,padRight,padBottom:integer;
  usedCells:array of cardinal; // bitmap of cell status (1 - cell is empty)
  numCells:integer; // total number of non-empty cells
  constructor Create(tex:TTexture);
  procedure CalcSizes(patch:TNinePatch);
 private
  procedure BuildRanges(tex:TTexture);
  procedure CheckCells;
  procedure CalcWeights;
  procedure ClearBorder(tex:TTexture);
 end;

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

procedure TPatchInfo.BuildRanges(tex:TTexture);
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
  ASSERT((length(hRanges)<10) and (length(vRanges)<10));
 end;

// Check cells content and mark non-transparent cells to draw (so full transparent cells will be skipped)
procedure TPatchInfo.CheckCells;
 var
  i,j,x,y:integer;
 begin
   // Mark empty cells
   SetLength(usedCells,length(vRanges));
   numCells:=0;
   for i:=0 to high(usedCells) do begin
    for j:=0 to high(hRanges) do begin
     y:=vRanges[i].pFrom;
     // try to find non-transparent pixels
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

procedure TPatchInfo.CalcWeights;
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

procedure TPatchInfo.ClearBorder;
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

constructor TPatchInfo.Create(tex:TTexture);
 var
  x,y,n,i:integer;
 begin
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
 end;

procedure TPatchInfo.CalcSizes(patch:TNinePatch);
 var
  i,v:integer;
 begin
  // Base dimensions
  patch.baseWidth:=0;
  for i:=0 to high(hRanges) do begin
   with hRanges[i] do
    v:=pTo-pFrom+1-overlap1-overlap2;
   inc(patch.baseWidth,v);
  end;
  patch.baseHeight:=0;
  for i:=0 to high(vRanges) do begin
   with vRanges[i] do
    v:=pTo-pFrom+1-overlap1-overlap2;
   inc(patch.baseHeight,v);
  end;
  // Min dimensions
  patch.minWidth:=0;
  for i:=0 to high(hRanges) do
   with hRanges[i] do
    if rType=rtFixed then
     inc(patch.minWidth,1+pTo-pFrom);
  patch.minHeight:=0;
  for i:=0 to high(vRanges) do
   with vRanges[i] do
    if rType=rtFixed then
     inc(patch.minHeight,1+pTo-pFrom);
 end;

{ TNinePatch }
procedure TCustomNinePatch.BuildMeshForSize(w,h:single);
 var
  i,j,nW,nH,base:integer;
  data:TPatchInfo;
  vrt,vrt2,vrt3,vrt4:TVertex;
  pVrt:PVertex;
  u1,v1,u2,v2,du,dv:single;
  addW,addH:single;
  xx,yy:array[0..15] of single;
 begin
  if (meshWidth=w) and (meshHeight=w) then exit;
  data:=TPatchInfo(patchInfo);
  nW:=length(data.hRanges);
  nH:=length(data.vRanges);
  if mesh=nil then begin
   du:=1/tex.width;
   dv:=1/tex.height;
   if not (data.overlapped or data.tiled) then begin
     // Indexed mesh for a regular 9-patch (simple case)
     mesh:=TMesh.Create(TVertex.layoutTex,(nW+1)*(nH+1),data.numCells*6);
     // Fill vertices
     for i:=0 to nH do begin
       if i<nH then v1:=data.vRanges[i].pFrom*dv
         else v1:=1-dv;
       for j:=0 to nW do begin
        if j<nW then u1:=data.hRanges[j].pFrom*du
         else u1:=1-du;

        vrt.Init(0,0,0,u1,v1,$FF808080); // position will be filled later
        mesh.AddVertex(vrt);
       end;
     end;
     // Fill indices
     for i:=0 to nH-1 do
      for j:=0 to nW-1 do
       if GetBit(data.usedCells[i],j) then begin
        base:=i*(nW+1)+j; // base index
        mesh.AddTrg(base,base+1,base+2+nW);
        mesh.AddTrg(base,base+2+nW,base+1+nW);
       end;
   end else begin
     // Non-indexed mesh for an overlapped/tiles 9-patch (complex case)
     mesh:=TMesh.Create(DEFAULT_VERTEX_LAYOUT,nW*nH*6,0);
     // Fill vertices
     for i:=0 to nH-1 do begin
       v1:=data.vRanges[i].pFrom*dv;
       v2:=data.vRanges[i].pTo*dv+dv;
       for j:=0 to nW-1 do begin
        u1:=data.hRanges[j].pFrom*du;
        u2:=data.hRanges[j].pTo*du+du;
        // Define 4 vertices for a quad
        vrt. Init(0,0,0,u1,v1,$FF808080); // position will be filled later
        vrt2.Init(0,0,0,u2,v1,$FF808080);
        vrt3.Init(0,0,0,u2,v2,$FF808080);
        vrt4.Init(0,0,0,u1,v2,$FF808080);
        // 1-st triangle
        mesh.AddVertex(vrt);
        mesh.AddVertex(vrt2);
        mesh.AddVertex(vrt3);
        // 2-nd triangle
        mesh.AddVertex(vrt);
        mesh.AddVertex(vrt3);
        mesh.AddVertex(vrt4);
       end;
     end;
   end;
  end;
  // Resize grid
  addW:=w-baseWidth;
  addH:=h-baseHeight;
  xx[0]:=0;
  for i:=0 to nW-1 do
   with data.hRanges[i] do begin
    xx[i+1]:=xx[i]+(1+pTo-pFrom);
    if rType<>rtFixed then
     xx[i+1]:=xx[i+1]+addW*data.hWeights[i];
   end;

  yy[0]:=0;
  for i:=0 to nH-1 do
   with data.vRanges[i] do begin
    yy[i+1]:=yy[i]+(1+pTo-pFrom);
    if rType<>rtFixed then
     yy[i+1]:=yy[i+1]+addW*data.vWeights[i];
   end;

  // Adjust vertices
  if not (data.overlapped or data.tiled) then begin
    // Simple 9-patch
    pVrt:=mesh.vertices;
    for i:=0 to nH do
       for j:=0 to nW do begin
        pVrt.x:=xx[j];
        pVrt.y:=yy[i];
        inc(pVrt);
       end;
  end else begin
   // Complex 9-patch

  end;
  meshWidth:=w; meshHeight:=h;
 end;

constructor TCustomNinePatch.Create(fromImage: TTexture);
 var
  x,y,n:integer;
  info:TPatchInfo;
 begin
  ASSERT((fromImage.width>=3) and (fromImage.height>=3));
  scaleFactor:=1;
  tex:=fromImage;
  info:=TPatchInfo.Create(tex);
  info.CalcSizes(self);
  patchInfo:=info;
 end;

destructor TCustomNinePatch.Destroy;
 begin
  patchInfo.Free;
  inherited;
 end;

procedure TCustomNinePatch.Draw(x,y,width,height:single;scale:single);
 var
  rWidth,rHeight:single;
 begin
  //gfx.draw.Image(x,y,scale,tex);
  scale:=scale*scaleFactor;
  rWidth:=width/scale;
  rHeight:=height/scale;
  BuildMeshForSize(rWidth,rHeight);
  transform.SetObj(x,y,0,scale);
  mesh.Draw(tex);
  transform.ResetObj;
 end;

end.
