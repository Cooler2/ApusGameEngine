// Common purpose routines for engine
// Utility functions
//
// Copyright (C) 2003-2004 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)

unit Apus.Engine.Tools;
{$IFDEF IOS} {$DEFINE GLES} {$DEFINE OPENGL} {$ENDIF}
{$IFDEF ANDROID} {$DEFINE GLES} {$DEFINE OPENGL} {$ENDIF}
interface
 uses Apus.Engine.API, Apus.Images,
    Apus.Engine.UIClasses, Apus.Regions, Apus.MyServis,
    Apus.UnicodeFont, Apus.CrossPlatform, Apus.Engine.Game;

var
 rootDir:string='';

type
 // Большое изображение, состоящее из нескольких текстур
 TTiledImage=class
  tiles:array[0..15,0..15] of TTexture; // первый индекс - по X, второй - по Y
  width,height:integer;
  stepx,stepy:integer;
  cntX,cntY:integer;

  // Загрузить большое изображение в набор текстур
  // указывается размер ячеек для разбиения, размер ячеек, куда будут складываться неполные куски
  // и доля для закачки в видеопамять (от 0 до 1)
  constructor Create(fname:string;ForceFormat:TImagePixelFormat;
                cellsize:integer;flags:integer=0;precache:single=0);
  destructor Destroy; override;
  procedure Draw(x,y:integer;color:cardinal); virtual;
  procedure Precache(part:single); virtual;
  // получить регион, определяющий непрозрачную часть (прозрачность <50%)
  function GetRegion:TRegion; virtual;
 end;

 // Изображение, состоящее из нескольких кусков цельной текстуры
 TPatchedImage=class(TTiledImage)
  points:array[1..8] of TPoint;
  rects:array[1..8] of TRect;
  xMin,xMax,yMin,yMax:integer;
  count:integer;
  tex:TTexture;
  constructor Create(fname:string);
  destructor Destroy; override;
  procedure AddRect(xStart,yStart,Rwidth,Rheight:integer;posX,posY:integer); virtual;
  procedure Draw(x,y:integer;color:cardinal); override;
  procedure Precache(part:single); override;
  function GetRegion:TRegion; override;
 end;

 TVertexHandler=procedure(var vertex:TVertex);

 // Common purpose routines

 procedure MainLoop; // Infinite loop with event handling


 // установить заданное изображение в качестве фона данного окна
 procedure SetupSkinnedWindow(wnd:TUISkinnedWindow;img:TTexture); overload;

 // Рисует текст с эффектом glow/shadow в заданную текстуру
 // x,y - точка, где будет центр надписи (насколько возможно)
 procedure DrawTextWithGlow(img:TTexture;font:cardinal;x,y:integer;st:WideString;
     textColor,glowColor,glowDepth,glowBlur:cardinal;glowOfsX,glowOfsY:integer);

 // Создает текстуру с заданной надписью на прозрачном фоне, текст с эффектом glow/shadow
 function BuildTextWithGlow(font:cardinal;st:WideString;
    textColor,glowColor,glowDepth,glowBlur:cardinal;
    glowOfsX,glowOfsY:integer):TTexture;

 // Возвращает хэндл шрифта с измененным размером
 // Например, если scale = 1.2, то вернет шрифт такой же, но на 20% крупнее
 function ScaleFont(fontHandle:cardinal;scale:single):cardinal;

 // Camera transformations
 // ----------------------------------
 // Set new coordinate space with given center and scale factors
 procedure Set2DTransform(originX,originY,scaleX,scaleY:double);
 // Transform space so new image will be scaled and rotated around given point
 procedure Transform2DTurnAround(centerX,centerY,scale,angle:double);
 procedure Transform2DScaleAround(centerX,centerY,scaleX,scaleY:double);
 procedure Reset2DTransform;

 // Meshes
 function LoadMesh(fname:string):TMesh;
 function BuildMeshForImage(img:TTexture;splitX,splitY:integer):TMesh;
 function TransformVertices(vertices:TVertices;shader:TVertexHandler):TVertices;
 procedure DrawIndexedMesh(vertices:TVertices3D;indices:TIndices;tex:TTexture);
 procedure DrawMesh(vertices:TVertices3D;tex:TTexture);
 procedure AddVertex(var vertices:TVertices;x,y,z,u,v:single;color:cardinal);

// procedure BuildNPatchMesh(img:TTexture;splitU,splitV,weightU,weightW:SingleArray;var vertices:TVertices;var indices:TIndices);

 // Shapes
 // Draw circle using band particles (
 procedure DrawCircle(x,y,r,width:single;n:integer;color:cardinal;tex:TTexture;rec:TRect;idx:integer);

 // Draw waiting spinner
 procedure DrawSpinner(x,y,size:integer;color:cardinal;count:integer=12);
 procedure DrawSolidSpinner(x,y,size,width:integer;color:cardinal);

 // Формирует значение, содержащее координаты курсора для передачи в draw.TextOut
 function EncodeMousePos:cardinal;


 // FOR INTERNAL USE ----------------------------------------------------------

implementation
 uses SysUtils,{$IFDEF DIRECTX}DirectXGraphics,d3d8,Apus.Engine.DxImages8,{$ENDIF}
    {$IFDEF ANDROID}Apus.Android,{$ENDIF}
    Apus.GfxFormats,Classes,Apus.Structs,Apus.Geom3D,Apus.FastGFX,Apus.GfxFilters,
    Apus.Engine.ImgLoadQueue,Apus.Engine.ImageTools,Apus.Engine.GfxFormats3D;

var
  serial:cardinal;

function EncodeMousePos:cardinal;
begin
  result:=word(game.mouseX) and $FFFF+word(game.mouseY) shl 16;
end;

function StrHash(st:string):cardinal; inline;
var
 i:integer;
begin
 result:=0;
 for i:=1 to length(st) do inc(result,byte(st[i]) shl (i and 20));
end;

function ScaleFont(fontHandle:cardinal;scale:single):cardinal;
var
 v:cardinal;
begin
 v:=(fontHandle shr 16) and $FF;
 v:=round(v*scale);
 if v>255 then v:=255;
 result:=fontHandle and $FF00FFFF+v shl 16;
end;

{type
 TLaunchThread=class(TThread)
  url:string;
  constructor Create(LaunchUrl:string);
  procedure Execute; override;
 end;

constructor TLaunchThread.Create(launchUrl:string);
 begin
  url:=LaunchUrl;
  inherited Create(false);
 end;

procedure TLaunchThread.Execute;
begin
 ShellExecute(0,'open',PChar(url),'','',0);
end;}

{ TLargeImage }
constructor TTiledImage.Create(fname: string;
  ForceFormat: TImagePixelFormat; cellsize, flags: integer; precache: single);
 var
  i,j,x,y,w,h:integer;
  tex:TTexture;
  tname:string[40];
 begin
  tex:=LoadImageFromFile(fname,liffSysMem,forceFormat) as TTexture;
  width:=tex.width;
  height:=tex.height;
  tname:=fname;
  if length(tname)>12 then
   delete(tname,1,length(tname)-12);
  try
   cntX:=(tex.width-1) div cellsize +1;
   cntY:=(tex.height-1) div cellsize +1;
   stepx:=cellSize;
   stepy:=cellsize;
   for j:=0 to cntY-1 do
    for i:=0 to cntX-1 do begin
     x:=i*cellsize;
     y:=j*cellsize;
     if x+cellsize>tex.width then w:=tex.width-x else w:=cellsize;
     if y+cellsize>tex.height then h:=tex.height-y else h:=cellsize;
     if (w<cellsize) or (h<cellsize) then
      tiles[i,j]:=CreateSubImage(tex,x,y,w,h,flags)
     else
      tiles[i,j]:=CreateSubImage(tex,x,y,cellsize,cellsize,aiTexture);
     tiles[i,j].name:=inttohex(i,1)+inttohex(j,1)+'_'+tname;
    end;
  finally
   if tex<>nil then FreeImage(TTexture(tex));
  end;
  self.Precache(precache);
 end;

destructor TTiledImage.Destroy;
 var
  i,j:integer;
 begin
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do
    FreeImage(TTexture(tiles[i,j]));
  inherited;
 end;

procedure TTiledImage.Draw(x, y: integer; color: cardinal);
 var
  i,j:integer;
 begin
  ASSERT(gfx.draw<>nil);
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do
    gfx.draw.Image(x+i*stepX,y+j*stepY,tiles[i,j],color);
 end;

function TTiledImage.GetRegion: TRegion;
{var
 r:TRegion;
 rs:array[0..7,0..7] of TRegion;
 i,j,size,pos:integer;
 img:TRawImage;
 color,mask:cardinal;}
begin
 result:=nil;
{ if images[0,0]=nil then exit;
 case images[0,0].PixelFormat of
  ipf1555,ipf4444:begin color:=$8000; mask:=$8000; end;
  ipfARGB:begin color:=$80000000; mask:=$80000000; end;
  else raise EError.Create('GetRegion: pixel format is not supported');
 end;
 r:=TRegion.Create(0,0);
 for i:=0 to cntx-1 do
  for j:=0 to cnty-1 do begin
   images[i,j].Lock;
   img:=images[i,j].GetRawImage;
   rs[i,j]:=TRegion.CreateFrom(img,color,mask);
   img.free;
   images[i,j].Unlock;
  end;

 result:=r;}
end;

procedure TTiledImage.Precache(part: single);
 var
  i,j,n:integer;
 begin
  n:=round(cntX*cntY*part);
  if n<=0 then exit;
  for i:=0 to cntX-1 do
   for j:=0 to cntY-1 do begin
    gfx.resman.MakeOnline(tiles[i,j]);
    dec(n);
    if n=0 then exit;
   end;
 end;

procedure SetupWindow(wnd:TUISkinnedWindow;img:TTiledImage);
 begin
  wnd.background:=img;
  wnd.size.x:=img.width;
  wnd.size.y:=img.height;
  wnd.color:=$FF808080;
  wnd.visible:=false;
//  wnd.transpmode:=tmCustom;
//  wnd.region:=TRegion.CreateFrom(img);
 end;

procedure SetupSkinnedWindow(wnd:TUISkinnedWindow;img:TTexture);
 begin
  wnd.background:=img;
  wnd.size.x:=img.width;
  wnd.size.y:=img.height;
  wnd.color:=$FF808080;
  wnd.visible:=false;
 end;


{ TPatchedImage }

procedure TPatchedImage.AddRect(xStart, yStart, rwidth, rheight, posX,
  posY: integer);
begin
 if count=8 then exit;
 inc(count);
 rects[count].Left:=xStart;
 rects[count].Top:=yStart;
 rects[count].Right:=xStart+rwidth;
 rects[count].Bottom:=yStart+rheight;
 points[count].X:=posX;
 points[count].Y:=posY;
 if posX<xMin then xMin:=posX;
 if posX+rwidth>xMax then xMax:=posX+rwidth;
 if posY<yMin then yMin:=posY;
 if posY+rheight>yMax then yMax:=posY+rheight;
 width:=xMax-xMin;
 height:=yMax-yMin;
end;

constructor TPatchedImage.Create(fname: string);
begin
 count:=0; width:=0; height:=0;
 tex:=LoadImageFromFile(fname,liffTexture) as TTexture;
end;

destructor TPatchedImage.Destroy;
begin
 FreeImage(TTexture(tex));
 inherited;
end;

procedure TPatchedImage.Draw(x, y: integer; color: cardinal);
var
 i:integer;
begin
 for i:=1 to count do
  gfx.draw.ImagePart(x+points[i].x,y+points[i].Y,tex,color,rects[i]);
end;

function TPatchedImage.GetRegion: TRegion;
begin

end;

procedure TPatchedImage.Precache(part: single);
begin
end;


 procedure DrawTextWithGlow(img:TTexture;font:cardinal;x,y:integer;st:WideString;
     textColor,glowColor,glowDepth,glowBlur:cardinal;glowOfsX,glowOfsY:integer);
  var
   w,h,d,i:integer;
   alpha:pointer;
   pb:PByte;
   tmp:PByte;
  begin
   img.Lock;
   try
   st:=Translate(st);
   d:=GlowDepth+glowBlur;
   w:=txt.WidthW(font,st)+4+2*d; h:=round(3*d+txt.Height(font)*1.5);
   GetMem(tmp,w*h*4);
   fillchar(tmp^,w*h*4,0);
   txt.SetTarget(tmp,w*4);
   txt.WriteW(font,w div 2,round(h*0.77)-d,textColor,st,Apus.Engine.API.taCenter,toDrawToBitmap);
   dec(x,round(w/2));
   dec(y,round(h/2));
   if glowColor>$FFFFFF then begin
    alpha:=ExtractAlpha(tmp,w*4,w,h);
    Maximum8(alpha,0,0,w-1,h-1,w,glowDepth,glowDepth);
//   for i:=1 to glowBlur do
    while glowBlur>1 do begin
     Blur8(alpha,w,w,h);
     dec(glowBlur,2);
    end;
    if glowBlur>0 then
     LightBlur8(alpha,w,w,h);
    pb:=GetPixelAddr(img.data,img.pitch,x+glowOfsX,y+glowOfsY);
    BlendUsingAlpha(pb,img.pitch,alpha,w,w,h,glowColor,blBlend);
    FreeMem(alpha);
   end;
   SimpleDraw(tmp,w*4,img.data,img.pitch,x,y,w,h,blBlend);
   FreeMem(tmp);
   finally
    img.Unlock;
   end;
  end;

 function BuildTextWithGlow(font:cardinal;st:WideString;
    textColor,glowColor,glowDepth,glowBlur:cardinal;
    glowOfsX,glowOfsY:integer):TTexture;
  var
   img:TTexture;
   w,h,d:integer;
  begin
   d:=GlowDepth+glowBlur;
   st:=Translate(st);
   w:=txt.WidthW(font,st)+6+2*d; h:=round(3*d+txt.Height(font)*1.5);
//   if w mod 2=0 then inc(w);
   img:=AllocImage(w,h,pfTrueColorAlpha,aiClampUV,'BTWG'+inttostr(serial)) as TTexture;
   inc(serial);
   img.Lock;
   FillRect(img.data,img.pitch,0,0,w-1,h-1,$00808080);
//   FillRect(img.data,img.pitch,0,0,w-1,h-1,$501010C0);
   DrawTextWithGlow(img,font,round(w*0.5),round(h*0.5),st,textColor,
     glowColor,glowDepth,glowBlur,glowOfsX,glowOfsY);
   img.Unlock;
   result:=img;
  end;

 procedure Set2DTransform(originX,originY,scaleX,scaleY:double);
  var
   mat:TMatrix4;
  begin
   fillchar(mat,sizeof(mat),0);
   mat[0,0]:=scaleX;
   mat[1,1]:=scaleY;
   mat[2,2]:=1;
   mat[3,0]:=originX;
   mat[3,1]:=originY;
   mat[3,3]:=1;
   gfx.transform.SetObj(mat);
  end;

 procedure Transform2DTurnAround(centerX,centerY,scale,angle:double);
  var
   mat:TMatrix4;
   ca,sa:double;
  begin
   fillchar(mat,sizeof(mat),0);
   ca:=cos(angle);
   sa:=sin(angle);
   mat[0,0]:=ca*scale;
   mat[0,1]:=sa*scale;
   mat[1,0]:=-sa*scale;
   mat[1,1]:=ca*scale;
   mat[2,2]:=1;
   mat[3,0]:=centerX-scale*(ca*centerX-sa*centerY);
   mat[3,1]:=centerY-scale*(sa*centerX+ca*centerY);
   mat[3,3]:=1;
   gfx.transform.SetObj(mat);
  end;

 procedure Transform2DScaleAround(centerX,centerY,scaleX,scaleY:double);
  var
   mat:TMatrix4;
  begin
   fillchar(mat,sizeof(mat),0);
   mat[0,0]:=scaleX;
   mat[1,1]:=scaleY;
   mat[2,2]:=1;
   mat[3,0]:=centerX*(1-scaleX);
   mat[3,1]:=centerY*(1-scaleY);
   mat[3,3]:=1;
   gfx.transform.SetObj(mat);
  end;

 procedure Reset2DTransform;
  begin
   Set2DTransform(0,0,1,1);
  end;

 function LoadMesh(fname:string):TMesh;
  var
   ext:string;
  begin
   fname:=FileName(fName);
   ext:=lowerCase(ExtractFileExt(fname));
   if ext='.obj' then result:=LoadOBJ(fName);
  end;

 function BuildMeshForImage(img:TTexture;splitX,splitY:integer):TMesh;
  var
   i,j,n,v:integer;
   du,dv,dx,dy:single;
  begin
   result:=TMesh.Create;
   gfx.resman.MakeOnline(img);
   // Fill vertices
   with result do begin
   SetLength(vertices,(splitX+1)*(splitY+1));
   du:=(img.u2-img.u1)/splitX;
   dv:=(img.v2-img.v1)/splitY;
   dx:=img.width/splitX;
   dy:=img.height/splitY;
   n:=0;
   for i:=0 to splitY do
    for j:=0 to splitX do begin
     with vertices[n] do begin
      x:=j*dx-0.5; y:=i*dy-0.5; z:=0; {$IFDEF DIRECTX} rhw:=1; {$ENDIF}
      color:=$FF808080;
      u:=img.u1+du*j;
      v:=img.v1+dv*i;
     end;
     inc(n);
    end;
   // Fill indices
   SetLength(indices,splitX*splitY*2*3);
   n:=0;
   for i:=0 to splitY-1 do
    for j:=0 to splitX-1 do begin
     v:=i*(splitX+1)+j;
     indices[n]:=v; inc(v);
     indices[n+1]:=v; inc(v,splitX+1);
     indices[n+2]:=v;
     inc(n,3);
     indices[n]:=v; dec(v);
     indices[n+1]:=v; dec(v,splitX+1);
     indices[n+2]:=v;
     inc(n,3);
    end;
   end;
  end;

 procedure DrawIndexedMesh(vertices:TVertices3D;indices:TIndices;tex:TTexture);
  begin
   draw.IndexedMesh(@vertices[0],@indices[0],length(indices) div 3,length(vertices),tex);
  end;

 procedure DrawMesh(vertices:TVertices3D;tex:TTexture);
  begin
   draw.TrgList(@vertices[0],length(vertices) div 3,tex);
  end;

 procedure AddVertex(var vertices:TVertices;x,y,z,u,v:single;color:cardinal);
  var
   n:integer;
  begin
   n:=length(vertices);
   SetLength(vertices,n+1);
   vertices[n].x:=x;
   vertices[n].y:=y;
   vertices[n].z:=z;
   vertices[n].u:=u;
   vertices[n].v:=v;
   vertices[n].color:=color;
  end;

 function TransformVertices(vertices:TVertices;shader:TVertexHandler):TVertices;
  var
   i:integer;
  begin
   SetLength(result,length(vertices));
   for i:=0 to length(vertices)-1 do begin
    result[i]:=vertices[i];
    Shader(result[i]);
   end;
  end;

 procedure DrawCircle(x,y,r,width:single;n:integer;color:cardinal;tex:TTexture;rec:TRect;idx:integer);
  var
   i:integer;
   parts:array of TParticle;
   a,step:single;
  begin
   SetLength(parts,n);
   a:=0; step:=2*pi/n;
   for i:=0 to n-1 do begin
    parts[i].x:=x+cos(a)*r;
    parts[i].y:=y-sin(a)*r;
    parts[i].z:=0;
    parts[i].color:=color;
    parts[i].scale:=width;
    parts[i].index:=idx;
    a:=a+step;
   end;
   inc(parts[n-1].index,partLoop);
   draw.Band(0,0,@parts[0],n,tex,rec);
  end;

 procedure DrawSpinner(x,y,size:integer;color:cardinal;count:integer=12);
  var
   i:integer;
   a,r,s,srcAlpha:single;
   data:array[0..47] of TParticle;
   c,alpha:cardinal;
  begin
   if count>24 then count:=24;
   r:=size/2;
   s:=size/(12+count*1.2);
   srcAlpha:=(color shr 24)/255;
   for i:=0 to count-1 do begin
    a:=2*Pi*i/count;
    alpha:=(round(256*i/count)-game.frameStartTime div 3) and $FF;
    c:=color and $FFFFFF+round(alpha*srcAlpha) shl 24;
    data[i*2].x:=0.55*r*sin(a);
    data[i*2].y:=-0.55*r*cos(a);
    data[i*2].z:=0;
    data[i*2].color:=c;
    data[i*2].scale:=s;
    data[i*2].index:=0;

    data[i*2+1].x:=r*sin(a);
    data[i*2+1].y:=-r*cos(a);
    data[i*2+1].z:=0;
    data[i*2+1].color:=c;
    data[i*2+1].scale:=s;
    data[i*2+1].index:=partEndpoint;
   end;
   draw.Band(x,y,@data[0],count*2,nil,Rect(x-size,y-size,x+size,y+size));
  end;

 procedure DrawSolidSpinner(x,y,size,width:integer;color:cardinal);
  var
   i,count:integer;
   a,r,srcAlpha:single;
   data:array[0..47] of TParticle;
   c,alpha:cardinal;
  begin
   count:=24;
   r:=size/2;
   srcAlpha:=(color shr 24)/255;
   for i:=0 to count-1 do begin
    a:=2*Pi*i/count;
    alpha:=(round(256*i/count)-game.frameStartTime div 3) and $FF;
    c:=color and $FFFFFF+round(alpha*srcAlpha) shl 24;
    data[i].x:=r*sin(a);
    data[i].y:=-r*cos(a);
    data[i].z:=0;
    data[i].color:=c;
    data[i].scale:=width/2;
    data[i].index:=0;
    if i=count-1 then data[i].index:=partLoop;
   end;
   draw.Band(x,y,@data[0],count,nil,Rect(x-size,y-size,x+size,y+size));
  end;

procedure MainLoop;
begin
 repeat
  try
   PingThread;
   CheckCritSections;
   Delay(5); // Handling signals is inside
   systemPlatform.ProcessSystemMessages;
  except
   on e:exception do ForceLogMessage('Error in MainLoop: '+ExceptionMsg(e));
  end;
 until game.terminated;
end;

end.


