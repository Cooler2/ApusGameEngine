// Copyright (C) Apus Software, 2012-2014. Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// -----------------------------------------
// 2D-cache methods for font glyph caching
// (realtime 2D-rect packing algorithms)

{$WRITEABLECONST ON}
unit Apus.GlyphCache;
interface
 uses types,Apus.HashMaps,Apus.Conv,Apus.Log;

type
 TGlyphInfoRec=record
  x,y:integer;  // glyph position
  width,height:integer; // glyph dimension
  dx,dy:integer; // glyph position relative to output (cursor) point
 end;

 // Compact (8-byte) cache record: one entry per glyph in the index
 TGlyphRec=record
  x,y:smallint;   // position in the atlas (local, relX/relY added on Find)
  w,h:byte;       // glyph size (Alloc permits up to 255)
  dx,dy:shortint; // offset relative to the cursor point (-128..127)
 end;

 // Abstract interface for caching glyphs or other small images inside one large texture
 TGlyphCache=class
  lastTimeStamp:cardinal;
  relX,relY:integer; // origin the returned positions are relative to
  // returns the texture position for the given char, or -1,-1 if absent
  function Find(chardata:cardinal):TGlyphInfoRec; virtual; abstract;
  // allocates a block of the given size for the char and returns its position
  function Alloc(width,height,dx,dy:integer;chardata:cardinal):TPoint; virtual; abstract;
  // Keep all blocks found from this moment from deletion
  procedure Keep; virtual; abstract;
  // Allow further deletion of any blocks
  procedure Release; virtual; abstract;
 end;

 TBandData=record
  y,height:integer; // band position (height=0 - free)
  next:integer; // index of the next band
  freeSpace:integer; // remaining free space
  keys:array of cardinal; // chardata of glyphs placed in this band (for eviction)
  keyCount:integer;
 end;

 // HOW IT WORKS: the whole space (512x512 to 2048x2048) is a cache of caches, i.e. a set of bands, where each band
 // works as a separate cache. Key property: items are only appended to the end of a band; if there is not enough room
 // a new band is allocated, and deletion happens only by whole bands.
 // That is why Keep() ensures a sizable part of the cache stays free, so that bands with needed items are not deleted.
 // Packed metadata permits items up to 255x255; an item must also fit the
 // dimensions of this cache region. Atlas exhaustion means that no contiguous
 // horizontal band remains for the requested item height.
 // KNOWN ISSUE: Keep() frees old bands eagerly by FIFO, so a glyph still needed this frame can be evicted while
 // new ones are added (only the 25% headroom guards against it - not a hard guarantee; harmless in practice).
 // FIX IDEA: track a per-band lastUsed timestamp (bump on Alloc/Find-hit) and free lazily from Alloc, never
 // touching bands used since the Keep() barrier.
 TDynamicGlyphCache=class(TGlyphCache)
  constructor Create(width,height:integer);
  destructor Destroy; override;
  // returns the texture position for the given char, or -1,-1 if absent
  function Find(chardata:cardinal):TGlyphInfoRec; override;
  // allocates a block of the given size for the char and returns its position
  function Alloc(width,height,dx,dy:integer;chardata:cardinal):TPoint; override;
  // Keep all blocks found from this moment from deletion
  procedure Keep; override;
  // Allow further deletion of any blocks
  procedure Release; override;
  // How efficient space is used (0..1)
  function Usage:single;
 private
  aWidth,aHeight:integer; // total cache space size
  freeMin,freeMax:integer; // free area bounds (freeMax may exceed aHeight, meaning a wrapped/discontiguous area)
  // Bands (list)
  bands:array[0..99] of TBandData;
  bCount:integer;
  firstBand,lastBand:integer;
  // Glyph index: chardata -> compact record
  index:THashMapNum<TGlyphRec>;
  function CanCreateBand(height:integer):boolean;
  function CreateNewBand(height:integer):integer;
  procedure FreeOldBand;
  function GetState:string;
 end;

implementation
 uses SysUtils, Apus.Core;

{ TDynamicGlyphCache }

function TDynamicGlyphCache.Alloc(width, height,dx,dy: integer;
  chardata: cardinal): TPoint;
var
 i,best,bandHeight,spareHeight:integer;
 rec:TGlyphRec;
begin
 try
 if (width<0) or (width>255) or (height<0) or (height>255) then
   raise EWarning.Create('GlyphCache metadata overflow: %dx%d is out of packed range',[width,height]);
  if (width>aWidth) or (height>aHeight) then
   raise EWarning.Create('GlyphCache item %dx%d does not fit the %dx%d atlas region',
     [width,height,aWidth,aHeight]);
 if (dx<-128) or (dx>127) or (dy<-128) or (dy>127) then
  raise EWarning.Create('GlyphCache offset overflow: dx=%d dy=%d is out of packed range',[dx,dy]);
 // 1. Find the most suitable band
 i:=firstBand; best:=-1; spareHeight:=100000; bandHeight:=0;
 while i>=0 do begin
  // Look for a band with minimal spare height
  if (bands[i].height>=height) and
     (bands[i].freeSpace>=width) and
     (bands[i].height-height<spareHeight) then begin
   best:=i; spareHeight:=bands[i].height-height;
  end;
  // Get max height of smaller but usable bands
  if (bands[i].freeSpace>32+width*2) and
     (bands[i].height<height) and
     (bands[i].height>bandHeight) then bandHeight:=bands[i].height;
  i:=bands[i].next;
 end;
 // 2 cases when we should create a new band:
 // a) there is no suitable band
 if best<0 then begin
  // a band should be at least 25% taller than an existing reasonably free band
  bandHeight:=Max(height, bandHeight+1+bandHeight div 4);
 end;
 // b) suitable band is too high and we have much free space -> create a more suitable band
 if (best>=0) and
    (spareHeight>1+bands[best].height shr 2) and
    CanCreateBand(height*3) then begin
  best:=-1; // here we should avoid creating bands that are only slightly taller than the existing ones
  bandHeight:=Max(height,bandHeight+1+bandHeight div 4);
 end;
 // New band required?
 if best<0 then
   best:=CreateNewBand(bandHeight);
 // Add item
 result.y:=bands[best].y;
 result.x:=aWidth-bands[best].freeSpace;
 dec(bands[best].freeSpace,width);
 rec.x:=result.x; rec.y:=result.y;
 rec.w:=width; rec.h:=height;
 rec.dx:=dx; rec.dy:=dy;
 index.Put(chardata,rec);
 // remember the key so the whole band can be evicted at once
 if bands[best].keyCount>=length(bands[best].keys) then
  SetLength(bands[best].keys,Max(16,length(bands[best].keys)*2));
 bands[best].keys[bands[best].keyCount]:=chardata;
 inc(bands[best].keyCount);
 inc(result.x,relX);
 inc(result.y,relY);
 except
   on e:Exception do
    raise EWarning.Create('GlyphCache.Alloc(%d,%d) failed: %s',
      [width,height,ExceptionMsg(e)]);
 end;
end;

constructor TDynamicGlyphCache.Create(width, height: integer);
begin
 aWidth:=width;
 aHeight:=height;
 freeMin:=0;
 freeMax:=height-1;
 index.Init(512); // seed only; the map auto-resizes as more glyphs are cached
 bCount:=0;
 firstBand:=-1; lastBand:=-1;
 relX:=0; relY:=0;
 Log.Msg('GlyphCache created %d,%d',[width,height]);
end;

destructor TDynamicGlyphCache.Destroy;
begin
 inherited;
end;

function TDynamicGlyphCache.Find(chardata: cardinal): TGlyphInfoRec;
var
 rec:TGlyphRec;
begin
 if index.Get(charData,rec) then begin
  result.width:=rec.w;
  result.height:=rec.h;
  result.dx:=rec.dx;
  result.dy:=rec.dy;
  result.x:=relX+rec.x;
  result.y:=relY+rec.y;
 end else begin
  result.x:=-1;
  result.y:=-1;
 end;
end;

procedure TDynamicGlyphCache.Keep;
begin
 // Ensure that at least 25% of cache is free
 while (freeMax-freeMin<aHeight div 4) do FreeOldBand;
end;

procedure TDynamicGlyphCache.Release;
begin
 // Do nothing
end;

procedure TDynamicGlyphCache.FreeOldBand;
var
 i:integer;
begin
 ASSERT(firstBand>=0);
 Log.Msg('GlyphCache: free band %d-%d',[freeMin,freeMax]);
 // Remove all glyphs that belong to this band
 for i:=0 to bands[firstBand].keyCount-1 do
  index.Remove(bands[firstBand].keys[i]);
 bands[firstBand].keyCount:=0;
 // Delete band
 bands[firstBand].height:=0;
 firstBand:=bands[firstBand].next;
 // Update free space range
 if firstBand=-1 then begin
  // everything is deleted
  freeMin:=0; freeMax:=aHeight;
 end else begin
  freeMax:=bands[firstband].y-1;
  if freeMax<freeMin then inc(freeMax,aHeight);
 end;
end;

function TDynamicGlyphCache.GetState: string;
var
 i:integer;
begin
 result:=Format('[%d] %d-%d;',[index.count,freeMin,freeMax]);
 for i:=0 to bCount-1 do
  result:=result+Format('%d_%d %d;',[bands[i].y,bands[i].height,bands[i].freeSpace]);
end;

function TDynamicGlyphCache.CreateNewBand(height:integer):integer;
var
 i,y,b:integer;
begin
 // get new band position
 if (freeMin+height<=aHeight) then y:=freeMin else
  if (aHeight+height-1<=freeMax) then y:=aHeight else
   raise EWarning.CreateFmt(
     'GlyphCache atlas exhausted: cannot place a %dpx band in a %dx%d atlas (free ring %d-%d). State: %s',
     [height,aWidth,aHeight,freeMin,freeMax,GetState]);
 if freeMin+height>freeMax then
  raise EWarning.CreateFmt(
    'GlyphCache atlas exhausted: no contiguous space for a %dpx band in a %dx%d atlas (free ring %d-%d). State: %s',
    [height,aWidth,aHeight,freeMin,freeMax,GetState]);
 // Find free band record
 b:=-1;
 for i:=0 to bCount-1 do
  if bands[i].height=0 then begin
   b:=i; break;
  end;
 // Add band record if needed
 if b=-1 then begin
  if bCount>=length(bands) then
   raise EWarning.CreateFmt(
     'GlyphCache band table exhausted (%d descriptors). State: %s',
     [length(bands),GetState]);
  b:=bCount;
  inc(bCount);
 end;
 result:=b;
 // Adjust free space range
 freeMin:=y+height;
 if freeMin>=aHeight then begin
  dec(freeMin,aHeight);
  dec(freeMax,aHeight);
  if y>=aHeight then dec(y,aHeight);
 end;
 // Fill band data
 bands[b].y:=y;
 bands[b].height:=height;
 bands[b].next:=-1;
 bands[b].freeSpace:=aWidth;
 bands[b].keyCount:=0; // band record may be reused after eviction
 // Links
 if lastBand=-1 then begin
  firstBand:=b; lastBand:=b;
 end else begin
  bands[lastBand].next:=b;
  lastBand:=b;
 end;
end;

function TDynamicGlyphCache.CanCreateBand(height:integer):boolean;
begin
 if freeMax<aHeight then
  result:=(freeMax-freeMin>=height)
 else begin
  result:=false;
  if freeMin+height<=aHeight then result:=true;
  if aHeight+height-1<=freeMax then result:=true;
 end;
end;

function TDynamicGlyphCache.Usage:single;
var
 b,s,h:integer;
begin
{ b:=0;
 for s:=0 to hash.count-1 do
  if hash.keys[s]<>-1 then inc(b);
 result:=round(b);
 exit;}
 b:=firstBand; s:=0; h:=0;
 while b<>-1 do begin
  inc(s,bands[b].height*(aWidth-bands[b].freeSpace));
  inc(h,bands[b].height);
  b:=bands[b].next;
 end;
 if h>0 then result:=s/(h*aWidth)
  else result:=1;
end;

end.
