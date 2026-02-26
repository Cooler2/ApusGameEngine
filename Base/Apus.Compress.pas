// Compression and patching utilities
//
// Copyright (C) 2020 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Compress;
{$R-} // range checks off — low-level byte manipulation
{$Q-} // overflow checks off
interface
uses Apus.Core;

type
  // Simple RLE compression
  // Format: 1 byte tag, if high bits = $C0 then (tag xor $C0)+1 raw bytes follow,
  // otherwise tag+2 bytes of repeated value (next byte)
  RLE=record
    class function Pack(buf:pointer;size:integer;addHeader:boolean=true):ByteArray; static;
    class function Unpack(buf:pointer;size:integer):ByteArray; static;
    class function CheckHeader(buf:pointer;size:integer):integer; static; // returns unpacked size, -1 if no header
  end;

  // Simple LZ-like compression (good for text-like data)
  LZ=record
    class function Compress(const data:String8):String8; static;
    class function Decompress(const data:String8):String8; static;
  end;

  // Memory diff patches
  // Stream format: if first byte > $80 then 7 bits = count of following data bytes,
  // otherwise 7 bits + 8 bits of next byte = 15-bit offset to next block
  Patch=record
    class function Create(original,modified:pointer;size:integer):ByteArray; static;
    class procedure Apply(data:pointer;size:integer;patchBuf:pointer;patchSize:integer); static;
  end;

implementation

// ============================================================================
// RLE
// ============================================================================

class function RLE.Pack(buf:pointer;size:integer;addHeader:boolean=true):ByteArray;
var
  p,cur:integer;
  pb:PByte; // current byte being scanned
  start:PByte; // first unpacked byte
  cnt:integer; // how many last bytes match
  len:integer; // how far we've advanced (len=pb-start)
begin
  SetLength(result,10+size+size div 8);
  if addHeader then begin
    result[0]:=byte('!');
    result[1]:=byte('R');
    result[2]:=byte('L');
    result[3]:=byte('E');
    move(size,result[4],4); // data size
    p:=8;
  end else
    p:=0;
  pb:=buf;
  cur:=-1; cnt:=1;
  start:=pb; len:=0;
  while true do begin
    if (size>0) and (pb^=cur) then begin
      inc(cnt);
      if cnt>193 then begin
        if len>=cnt then begin
          inc(len);
          result[p]:=$C0+len-cnt-1; inc(p);
          move(start^,result[p],len-cnt); inc(p,len-cnt);
        end;
        result[p]:=cnt-3; inc(p);
        result[p]:=cur; inc(p);
        start:=pb; len:=0; cnt:=1;
      end;
    end else begin
      if (cnt>=3) or (len>=64) or (size<=0) then begin
        if cnt<2 then cnt:=0;
        if len>cnt then begin
          result[p]:=$C0+len-cnt-1; inc(p);
          move(start^,result[p],len-cnt); inc(p,len-cnt);
        end;
        if cnt>=2 then begin
          result[p]:=cnt-2; inc(p);
          result[p]:=cur; inc(p);
        end;
        if size<=0 then break;
        start:=pb; len:=0;
      end;
      cnt:=1;
      cur:=pb^;
    end;
    inc(pb); inc(len);
    dec(size);
  end;
  SetLength(result,p);
end;

class function RLE.CheckHeader(buf:pointer;size:integer):integer;
var
  pb:PByte;
begin
  result:=-1;
  if size<8 then exit;
  pb:=buf;
  if pb^<>byte('!') then exit; inc(pb);
  if pb^<>byte('R') then exit; inc(pb);
  if pb^<>byte('L') then exit; inc(pb);
  if pb^<>byte('E') then exit; inc(pb);
  move(pb^,result,4);
end;

class function RLE.Unpack(buf:pointer;size:integer):ByteArray;
var
  pb:PByte;
  s,p:integer;
  c:byte;
begin
  pb:=buf;
  s:=CheckHeader(buf,size);
  if s<0 then begin
    // no header — calculate output size
    s:=0; p:=size;
    while p>0 do begin
      c:=pb^;
      if pb^ and $C0=$C0 then begin
        c:=(c xor $C0)+1; inc(s,c);
        inc(c); inc(pb,c); dec(p,c);
      end else begin
        inc(s,c+2); inc(pb,2); dec(p,2);
      end;
    end;
    pb:=buf;
  end else begin
    inc(pb,8);
    dec(size,8);
  end;
  SetLength(result,s);

  // unpack data
  p:=0;
  while size>0 do begin
    c:=pb^;
    inc(pb); dec(size);
    if c and $C0=$C0 then begin
      c:=(c xor $C0)+1;
      move(pb^,result[p],c);
      inc(p,c);
      inc(pb,c); dec(size,c);
    end else begin
      inc(c,2);
      fillchar(result[p],c,pb^);
      inc(p,c);
      inc(pb); dec(size);
    end;
  end;
end;

// ============================================================================
// LZ
// ============================================================================

class function LZ.Compress(const data:String8):String8;
var
  i,j,curpos,outpos,foundStart,foundLength,ofs,max:integer;
  res:String8;
  prev:array of integer; // backreferences: index of previous byte with same value
  last:array[0..255] of integer; // index of last byte of given value
  b:byte;
  procedure Output(v:cardinal;count:integer); // output count bits from v
  var
    i,o:integer;
  begin
    for i:=count-1 downto 0 do begin
      if v and (1 shl i)>0 then begin
        o:=1+outpos shr 3;
        res[o]:=AnsiChar(byte(res[o]) or (1 shl (7-(outpos and 7))));
      end;
      inc(outpos);
    end
  end;
begin
  outpos:=0; // output bit position
  SetLength(res,round(length(data)*1.25+1)); // 1.25 is the worst case
  fillchar(res[1],length(res),0);
  fillchar(last,sizeof(last),0);
  SetLength(prev,length(data)+1);
  fillchar(prev[1],length(data)*4,0);
  curpos:=1;
  while curpos<=length(data) do begin
    // 1. Find the longest matching chain
    foundStart:=0; foundLength:=0;
    b:=byte(data[curpos]);
    i:=last[b];
    while (i>0) and (i>curPos-4096) do begin
      max:=length(data)-curPos+1; // how much data remains
      if max>20 then max:=20; // max 20 bytes at a time
      if max>curPos-i then max:=curPos-i; // how much known data
      j:=0;
      while (j<max) and (data[i+j]=data[curpos+j]) do inc(j);
      ofs:=curpos-i;
      if (j>foundStart) and (
         (j=1) and (ofs<17) or
         (j=2) and (ofs<66) or
         (j=3) and (ofs<259) or
         (j=4) and (ofs<1028) or
         (j>4) and (ofs<4100)) then begin
        foundStart:=i;
        foundlength:=j;
      end;
      i:=prev[i];
    end;

    // 2. Output code
    if foundLength>0 then begin // chain found
      ofs:=curPos-foundStart-foundLength;
      if foundLength=1 then
        Output($10+ofs,6)
      else begin
        Output($FFFFFFE,foundLength);
        max:=foundLength*2+2;
        if max>12 then max:=12; // max 12 bits for offset
        Output(ofs,max);
      end;
    end else begin // not found
      Output(b,10);
      foundLength:=1;
    end;

    // 3. Update working data
    while foundLength>0 do begin
      prev[curpos]:=last[b];
      last[b]:=curPos;
      inc(curPos);
      b:=byte(data[curpos]);
      dec(foundLength);
    end;
  end;
  SetLength(res,(outpos+7) shr 3);
  result:=res;
end;

class function LZ.Decompress(const data:String8):String8;
var
  i,curpos,outpos,rsize,bCount,ofs,L,M:integer;
  res:String8;
  function GetBits(cnt:integer):cardinal;
  var
    i:integer;
  begin
    result:=0;
    for i:=0 to cnt-1 do begin
      result:=result shl 1;
      if byte(data[1+curpos shr 3]) and (1 shl (7-(curpos and 7)))>0 then
        result:=result or 1;
      inc(curpos);
    end;
  end;
  procedure Output(v:byte);
  begin
    res[outpos]:=AnsiChar(v);
    inc(outpos);
    if outpos>=rsize then begin
      rsize:=rsize*2;
      SetLength(res,rsize);
    end;
  end;
begin
  curpos:=0; outpos:=1;
  bCount:=length(data)*8;
  rsize:=length(data)*2;
  SetLength(res,rsize);
  repeat
    if curpos+6>bCount then break;
    if GetBits(1)=0 then begin
      if GetBits(1)=0 then begin
        // immediate value
        if curPos+8>bCount then break;
        Output(GetBits(8));
      end else begin
        // L=1
        ofs:=GetBits(4);
        Output(byte(res[outpos-ofs-1]));
      end;
    end else begin
      // L>1
      L:=2;
      while GetBits(1)=1 do inc(L);
      M:=L*2+2;
      if M>12 then M:=12;
      ofs:=GetBits(M);
      for i:=0 to L-1 do
        Output(byte(res[outpos-ofs-L]));
    end;
  until false;
  SetLength(res,outPos-1);
  result:=res;
end;

// ============================================================================
// Patch
// ============================================================================

class function Patch.Create(original,modified:pointer;size:integer):ByteArray;
var
  i,cnt,sameCnt,diffCnt:integer;
  sp,dp:PByte;
  mode:integer;
begin
  sp:=original; dp:=modified;
  SetLength(result,size+4+size div 16);
  cnt:=0; // output byte counter
  sameCnt:=0; mode:=0; // scanning for matching run
  for i:=0 to size-1 do begin
    if mode=0 then begin
      if sp^<>dp^ then begin
        if sameCnt>=4 then begin
          // long enough chain — save and switch to mode 1
          result[cnt]:=sameCnt shr 8;
          result[cnt+1]:=sameCnt and $FF;
          inc(cnt,2);
          sameCnt:=0;
          mode:=1; diffCnt:=1;
        end else begin
          // too short — switch to mode 1 without saving
          diffCnt:=sameCnt+1; sameCnt:=0;
          mode:=1;
        end;
      end else begin
        // bytes match — continue
        inc(sameCnt);
        if sameCnt=32767 then begin
          // max length reached
          result[cnt]:=$7F;
          result[cnt+1]:=$FF;
          inc(cnt,2);
          sameCnt:=0;
        end;
      end;
    end else begin
      // mode 1: scanning differing data
      inc(diffCnt);
      if diffCnt=127 then begin
        // max length reached — save and switch to mode 0
        result[cnt]:=$80+diffCnt;
        dec(sp,diffCnt-1);
        move(sp^,result[cnt+1],diffCnt);
        inc(sp,diffCnt-1);
        inc(cnt,128);
        mode:=0;
        diffCnt:=0;
        sameCnt:=0;
      end else begin
        if sp^<>dp^ then begin
          sameCnt:=0;
        end else begin
          // bytes match
          inc(sameCnt);
          if sameCnt>5 then begin
            // enough matching bytes — save and switch to mode 0
            result[cnt]:=$80+diffCnt-sameCnt;
            dec(sp,diffCnt-1);
            move(sp^,result[cnt+1],diffCnt-sameCnt);
            inc(sp,diffCnt-1);
            inc(cnt,1+diffCnt-sameCnt);
            diffCnt:=0;
            mode:=0;
          end;
        end;
      end;
    end;
    inc(sp); inc(dp);
  end;
  // finalize
  if mode=0 then begin
    result[cnt]:=sameCnt shr 8;
    result[cnt+1]:=sameCnt and $FF;
    inc(cnt,2);
  end else begin
    result[cnt]:=$80+diffCnt;
    dec(sp,diffCnt);
    move(sp^,result[cnt+1],diffCnt);
    inc(cnt,1+diffCnt);
  end;
  SetLength(result,cnt);
end;

class procedure Patch.Apply(data:pointer;size:integer;patchBuf:pointer;patchSize:integer);
var
  pb,dp:PByte;
  ofs:integer;
begin
  pb:=patchBuf;
  dp:=data;
  while patchSize>0 do begin
    ofs:=pb^;
    if ofs and $80>0 then begin
      ofs:=ofs and $7F;
      inc(pb);
      dec(size,ofs);
      ASSERT(size>=0,'Patch.Apply: out of bounds');
      move(pb^,dp^,ofs);
      inc(pb,ofs);
      inc(dp,ofs);
      dec(patchSize,1+ofs);
    end else begin
      inc(pb);
      ofs:=ofs shl 8+pb^;
      inc(dp,ofs);
      dec(size,ofs);
      inc(pb);
      dec(patchSize,2);
      ASSERT(size>=0,'Patch.Apply: out of bounds');
    end;
  end;
end;

end.
