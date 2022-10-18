// Some useful operations with color (for ARGB-mode, D3D compatible)
//
// Copyright (C) 2004 Apus Software
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Colors;
interface

const
 InvalidColor = $0000007F;
type
 // Packed ARGB color
 TARGBColor=packed record
  case integer of
  0:(b,g,r,a:byte);
  1:(color:cardinal);
  2:(m:array[0..3] of byte);
 end;
 PARGBColor=^TARGBColor;

 function MyColor(r,g,b:cardinal):cardinal; overload;
 function MyColor(a,r,g,b:cardinal):cardinal; overload;
 function MyColorF(a,r,g,b:single):cardinal; overload;
 function GrayColor(gray:integer):cardinal; // FFxxxxxx
 function GrayAlpha(alpha:single):cardinal; // aa808080
 function SwapColor(color:cardinal):cardinal; // swap red<->blue bytes
 function GetAlpha(color:cardinal):single;
 function IsSemiTransparent(color:cardinal):boolean;

 function ColorAdd(c1,c2:cardinal):cardinal;
 function ColorSub(c1,c2:cardinal):cardinal;
 function ColorMult2(c1,c2:cardinal):cardinal;
 // Multiply color by (alpha,1,1,1)
 function ColorAlpha(color:cardinal;alpha:single):cardinal;
 function ReplaceAlpha(color:cardinal;alpha:single):cardinal;
 // value=0 -> c2, value=256 -> c1
 function ColorMix(c1,c2:cardinal;value:integer):cardinal; // Линейная интерполяция
 function ColorMixF(c1,c2:cardinal;t:single):cardinal; // Линейная интерполяция
 function ColorBlend(c1,c2:cardinal;value:integer):cardinal; // Качественный квази-линейный бленд (гораздо медленнее!)
 function BilinearMixF(v0,v1,v2,v3:single;u,v:single):single; overload; inline;  // Билинейная интерполяция
 function BilinearMixF(values:PSingle;u,v:single):single; overload;  // Билинейная интерполяция
 function BilinearMix(c0,c1,c2,c3:cardinal;u,v:single):cardinal; overload; // Билинейная интерполяция
 function BilinearMix(values:PCardinal;u,v:single):cardinal; overload; // Bilinear interpolation (SSE)
 function BilinearBlend(c0,c1,c2,c3:cardinal;v1,v2:single):cardinal; // Качественный квази-билинейный бленд (гораздо медленнее!)
 function Blend(background,foreground:cardinal):cardinal; // Качественный альфа-блендинг

 function Lightness(color:cardinal):byte; // яркость цвета (0..255)

 // value - -120..120
 function Brightness(c:cardinal;value:integer):cardinal;
 // Value - 0..500, 256 - neutral
 function Contrast(c:cardinal;value:integer):cardinal;

 function SimpleColorDiff(c1,c2:cardinal):integer; // Simple color difference (fast)
 function ColorDiff(c1,c2:cardinal):single;  // Relative visual color difference (0..1+)

implementation
 uses Apus.Common;
 {$R-,Q-}
 {$EXCESSPRECISION OFF}

 type
  TVector4=array[0..3] of single;
  TSSEConst=record
    ONE:TVector4;
    MINUS_ONE:TVector4;
  end;
 const
  ONE:single = 1.0;
  MINUS_ONE:single = -1.0;
  ONE_PACKED:TVector4=(1,1,1,1);
  MINUS_ONE_PACKED:TVector4=(-1,-1,-1,-1);

 var
  SSE_CONST:^TSSEConst;

 function SwapColor(color:cardinal):cardinal; // swap red<->blue bytes
  begin
   result:=color and $FF00FF00+(color shr 16) and $FF+(color and $FF) shl 16;
  end;

 function MyColor(r,g,b:cardinal):cardinal; {$IFDEF CPU386} assembler;
  asm
   shl eax,16
   shl edx,8
   or eax,$FF000000
   or eax,edx
   or eax,ecx
  end;
  {$ELSE} inline;
  begin
   result:=$FF000000 or (r shl 16) or (g shl 8) or b;
  end;
  {$ENDIF}

 function MyColor(a,r,g,b:cardinal):cardinal; {$IFDEF CPU386} assembler;
  asm
   shl eax,24
   shl edx,16
   shl ecx,8
   or eax,edx
   or eax,ecx
   or eax,b
  end;
  {$ELSE} inline;
  begin
   result:=a shl 24+r shl 16+g shl 8+b;
  end;
  {$ENDIF}

 function MyColorF(a,r,g,b:single):cardinal;
  begin
   result:=SRound(a*255) shl 24+
     SRound(r*255) shl 16+
     SRound(g*255) shl 8+
     SRound(b*255);
  end;


 function GetAlpha(color:cardinal):single;
  begin
   result:=(color shr 24)/255;
  end;

 function IsSemiTransparent(color:cardinal):boolean;
  begin
   color:=color shr 24;
   result:=(color>0) and (color<255);
  end;

 function GrayColor(gray:integer):cardinal;
  begin
   gray:=Clamp(gray,0,255);
   result:=MyColor(255,gray,gray,gray);
  end;

 function GrayAlpha(alpha:single):cardinal;
  begin
   result:=round(Clamp(alpha,0,1)*255) shl 24+$808080;
  end;

 function Lightness(color:cardinal):byte; // яркость цвета (0..255)
  begin
   result:=round(
      0.2*(color and $FF)+
      0.5*((color shr 8) and $FF)+
      0.3*((color shr 16) and $FF));
  end;

 function ColorAdd(c1,c2:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   movd mm0,c1
   movd mm1,c2
   paddusb mm0,mm1
   movd eax,mm0
   emms
  end;
  {$ELSE}
  type
   mm=array[0..3] of byte;
  var
   mm1:mm absolute c1;
   mm2:mm absolute c2;
   i:integer;
  begin
   for i:=0 to 3 do
    if integer(mm1[i])+integer(mm2[i])>255 then mm1[i]:=255
     else mm1[i]:=mm1[i]+mm2[i];
   result:=c1;
  end;
  {$ENDIF}

 function ColorSub(c1,c2:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   movd mm0,c1
   movd mm1,c2
   psubusb mm0,mm1
   movd eax,mm0
   emms
  end;
  {$ELSE}
  type
   mm=array[0..3] of byte;
  var
   mm1:mm absolute c1;
   mm2:mm absolute c2;
   i:integer;
  begin
   for i:=0 to 3 do
    if mm2[i]>mm1[i] then mm1[i]:=0
     else mm1[i]:=mm1[i]-mm2[i];
   result:=c1;
  end;
  {$ENDIF}

 function ColorMult2(c1,c2:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   movd mm0,c1
   movd mm1,c2
   pxor mm7,mm7
   punpcklbw mm0,mm7
   punpcklbw mm1,mm7
   pmullw mm0,mm1
   psrlw mm0,7
   packuswb mm0,mm7
   movd eax,mm0
   emms
  end;
  {$ELSE}
  type
   mm=array[0..3] of byte;
  var
   mm1:mm absolute c1;
   mm2:mm absolute c2;
   i:integer;
  begin
   for i:=0 to 3 do
    if mm2[i]*mm1[i]>$8000 then mm1[i]:=255
     else mm1[i]:=mm2[i]*mm1[i] shr 7;
   result:=c1;
  end;
  {$ENDIF}

 function ColorAlpha(color:cardinal;alpha:single):cardinal;
  begin
   alpha:=Clamp(alpha,0,1);
   result:=color and $FFFFFF+round(alpha*(color and $FF000000)) and $FF000000;
  end;

 function ReplaceAlpha(color:cardinal;alpha:single):cardinal;
  begin
   alpha:=Clamp(alpha,0,1);
   result:=color and $FFFFFF+round(alpha*255) shl 24;
  end;

 function ColorMix(c1,c2:cardinal;value:integer):cardinal;
  var
   val2:integer;
  begin
   val2:=256-value;
   result:=(byte(c1)*value+byte(c2)*val2) shr 8; // blue part
   c1:=c1 shr 8; c2:=c2 shr 8;
   result:=result+cardinal((byte(c1)*value+byte(c2)*val2) and $FF00); // green part
   c1:=c1 shr 8; c2:=c2 shr 8;
   result:=result+cardinal(((byte(c1)*value+byte(c2)*val2) shl 8) and $FF0000); // red part
   c1:=c1 shr 8; c2:=c2 shr 8;
   result:=result+cardinal(((byte(c1)*value+byte(c2)*val2) and $FF00) shl 16); // alpha part
  end;

 function ColorMixF(c1,c2:cardinal;t:single):cardinal;
  var
   a,r,g,b:single;
  begin
   a:=(c1 shr 24)*t+(c2 shr 24)*(1-t);
   r:=byte(c1 shr 16)*t+byte(c2 shr 16)*(1-t);
   g:=byte(c1 shr 8)*t+byte(c2 shr 8)*(1-t);
   b:=byte(c1)*t+byte(c2)*(1-t);
   result:=round(a) shl 24+round(r) shl 16+round(g) shl 8+round(b);
  end;

 function ColorBlend(c1,c2:cardinal;value:integer):cardinal; // Качественный линейный бленд
  var
   val2,m:integer;
   a1,a2:byte;
{   col1:TARGBColor absolute c1;
   col2:TARGBColor absolute c2;}
  begin
   val2:=256-value;
   a1:=c1 shr 24;
   a2:=c2 shr 24;
   result:=((a1*value+a2*val2) and $FF00) shl 16;
//   m:=256;
   m:=16842752 div (a1*value+a2*val2+1);
   value:=m*(value*a1) shr 16;
   val2:=m*(val2*a2) shr 16;

   result:=result or cardinal((byte(c1)*value+byte(c2)*val2) shr 8); // blue part
   c1:=c1 shr 8; c2:=c2 shr 8;
   result:=result or cardinal((byte(c1)*value+byte(c2)*val2) and $FF00); // green part
   c1:=c1 shr 8; c2:=c2 shr 8;
   result:=result or cardinal(((byte(c1)*value+byte(c2)*val2) shl 8) and $FF0000); // red part
   //c1:=c1 shr 8; c2:=c2 shr 8;
  end;

 function BilinearMixF(v0,v1,v2,v3:single;u,v:single):single; // Билинейная интерполяция
  begin
   //result:=v0*(1-u)*(1-v)+v1*u*(1-v)+v2*(1-u)*v+v3*u*v;
   result:=v0+u*(v1-v0)+v*(v2-v0)+u*v*(v0+v3-v1-v2); // faster when u/v aren'c constant
  end;

 function BilinearMixF(values:PSingle;u,v:single):single; overload;  // Билинейная интерполяция
  asm
  {$IFDEF CPUx64}
   {$IFDEF MSWINDOWS}
   // rcx=@values, xmm1=u,xmm2=v
   movups xmm0,[rcx]
   shufps xmm1,xmm1,0
   shufps xmm2,xmm2,0
   mulss xmm1,[rip+MINUS_ONE]
   mulss xmm2,[rip+MINUS_ONE]
   addss xmm1,[rip+ONE]
   addss xmm2,[rip+ONE]
   shufps xmm1,xmm1,$44 // (u, 1-u, u, 1-u)
   shufps xmm2,xmm2,$50 // (v, v, 1-v, 1-v)
   mulps xmm0,xmm1
   mulps xmm0,xmm2
   haddps xmm0,xmm0
   haddps xmm0,xmm0
   {$ENDIF}
   {$IFDEF UNIX}
   // rdi=@values, xmm0=u,xmm1=v
   movups xmm2,[rdi]
   shufps xmm0,xmm0,0
   shufps xmm1,xmm1,0
   mulss xmm0,[rip+MINUS_ONE]
   mulss xmm1,[rip+MINUS_ONE]
   addss xmm0,[rip+ONE]
   addss xmm1,[rip+ONE]
   shufps xmm0,xmm0,$44 // (u, 1-u, u, 1-u)
   shufps xmm1,xmm1,$50 // (v, v, 1-v, 1-v)
   mulps xmm0,xmm1
   mulps xmm0,xmm2
   haddps xmm0,xmm0
   haddps xmm0,xmm0
   {$ENDIF}
  {$ENDIF}
  end;

 function BilinearMix(c0,c1,c2,c3:cardinal;u,v:single):cardinal; // Билинейная интерполяция
  // Integer version
  var
   v0,v1,v2,v3:integer;
  begin
   v3:=round(256*(u)*(v));
   v1:=round(256*(u)*(1-v));
   v0:=round(256*(1-u)*(1-v));
   v2:=round(256*(1-u)*(v));
   result:=(byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) shr 8; // blue part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) and $FF00); // green part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal(((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) shl 8) and $FF0000); // red part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal(((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) and $FF00) shl 16); // alpha part
  end;

  // Bilinear interpolation (SSE)
  // 6x faster than reference version
 function BilinearMix(values:PCardinal;u,v:single):cardinal; overload;
  asm
  {$IFDEF CPUx64}
   {$IFDEF MSWINDOWS}
   // rcx=values, xmm1=u, xmm2=v
   mov rax,[rip+SSE_CONST]
   pmovzxbd xmm0,[rcx+12]
   cvtdq2ps xmm3,xmm0  // values[3]
   shufps xmm1,xmm1,0
   mulps xmm3,xmm1  // *u
   shufps xmm2,xmm2,0
   mulps xmm3,xmm2  // xmm3=values[3]*u*v
   // next value
   pmovzxbd xmm0,[rcx+8]
   cvtdq2ps xmm0,xmm0  // values[2]
   movaps xmm4,xmm1
   mulps xmm4,[rax+16] // -u
   addps xmm4,[rax] // xmm4=1-u
   mulps xmm0,xmm2 // *v
   mulps xmm0,xmm4 // xmm0=values[2]*(1-u)*v
   addps xmm3,xmm0
   // next value
   pmovzxbd xmm0,[rcx+4]
   cvtdq2ps xmm0,xmm0  // values[1]
   movaps xmm5,xmm2
   mulps xmm5,[rax+16] // -v
   addps xmm5,[rax] // xmm5=1-v
   mulps xmm0,xmm1 // *u
   mulps xmm0,xmm5 // xmm0=values[1]*u*(1-v)
   addps xmm3,xmm0
   // final value
   pmovzxbd xmm0,[rcx]
   cvtdq2ps xmm0,xmm0  // values[0]
   mulps xmm0,xmm4 // *(1-u)
   mulps xmm0,xmm5 // xmm0=values[0]*(1-u)*(1-v)
   addps xmm3,xmm0
   // pack result color
   cvtps2dq xmm0,xmm3
   packusdw xmm0,xmm0
   packuswb xmm0,xmm0
   movd eax,xmm0
   {$ENDIF}
   {$IFDEF UNIX}
   // rdi=values, xmm0=u, xmm1=v
   mov rax,[rip+SSE_CONST]
   pmovzxbd xmm2,[rdi+12]
   cvtdq2ps xmm3,xmm2  // values[3]
   shufps xmm0,xmm0,0
   mulps xmm3,xmm0  // *u
   shufps xmm1,xmm1,0
   mulps xmm3,xmm1  // xmm3=values[3]*u*v
   // next value
   pmovzxbd xmm2,[rdi+8]
   cvtdq2ps xmm2,xmm2  // values[2]
   movaps xmm4,xmm0
   mulps xmm4,[rax+16] // -u
   addps xmm4,[rax] // xmm4=1-u
   mulps xmm2,xmm1 // *v
   mulps xmm2,xmm4 // xmm2=values[2]*(1-u)*v
   addps xmm3,xmm2
   // next value
   pmovzxbd xmm2,[rdi+4]
   cvtdq2ps xmm2,xmm2  // values[1]
   movaps xmm5,xmm1
   mulps xmm5,[rax+16] // -v
   addps xmm5,[rax] // xmm5=1-v
   mulps xmm2,xmm0 // *u
   mulps xmm2,xmm5 // xmm2=values[1]*u*(1-v)
   addps xmm3,xmm2
   // final value
   pmovzxbd xmm2,[rdi]
   cvtdq2ps xmm2,xmm2  // values[0]
   mulps xmm2,xmm4 // *(1-u)
   mulps xmm2,xmm5 // xmm2=values[0]*(1-u)*(1-v)
   addps xmm3,xmm2
   // pack result color
   cvtps2dq xmm2,xmm3
   packusdw xmm2,xmm2
   packuswb xmm2,xmm2
   movd eax,xmm2
   {$ENDIF}
  {$ENDIF}
  end;

 function BilinearBlend(c0,c1,c2,c3:cardinal;v1,v2:single):cardinal; // Качественный билинейный бленд
  begin
   result:=BilinearMix(c0,c1,c2,c3,v1,v2); // temp stub
  end;

 function Blend(background,foreground:cardinal):cardinal; // Alpha blending
  var
   v1:byte;
   c1:TARGBColor absolute background;
   c2:TARGBColor absolute foreground;
   v:cardinal;
  begin
   if c2.a=0 then
    result:=background
   else
   if c2.a=255 then
    result:=foreground
   else begin
    if c1.a=255 then begin
     // Opaque background
     v1:=255-c2.a;
     result:=((c1.b*v1+c2.b*c2.a)*258 and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*258 and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*258 and $FF0000)+
             $FF000000;
    end else begin
     // Transparent background (more complex)
     v1:=258*c1.a*(255-c2.a) shr 16;
     v:=65792 div (v1+c2.a);
     result:=((c1.b*v1+c2.b*c2.a)*v and $FF0000) shr 16+
             ((c1.g*v1+c2.g*c2.a)*v and $FF0000) shr 8+
             ((c1.r*v1+c2.r*c2.a)*v and $FF0000)+
             ($FF000000-(255-c1.a)*(255-c2.a)*66051 and $FF000000);
    end;
   end;
  end;

 function Brightness(c:cardinal;value:integer):cardinal;
  begin

  end;

{  asm
   movd mm0,c
   mov dh,dl
   mov cx,dx
   shl edx,16
   mov dx,cx
   movd mm1,edx
   paddsb mm0,mm1
   movd eax,mm0
   emms
  end; }

 function Contrast(c:cardinal;value:integer):cardinal;
  asm
  end;

 function SimpleColorDiff(c1,c2:cardinal):integer; // Simple color difference (fast)
  var
   col1:TARGBColor absolute c1;
   col2:TARGBColor absolute c2;
  begin
   result:=max2(max2(abs(col1.r-col2.r),abs(col1.g-col2.g)), max2(abs(col1.b-col2.b),abs(col1.a-col2.a)));
  end;

 function ColorDiff(c1,c2:cardinal):single; // relative color difference (0..1+)
  var
   col1:TARGBColor absolute c1;
   col2:TARGBColor absolute c2;
  begin
   result:=0.002*sqr(col1.r-col2.r)+0.003*sqr(col1.g-col2.g)+0.001*sqr(col1.b-col2.b)+0.001*sqr(col1.a-col2.a);
  end;

initialization
 new(SSE_CONST);
 SSE_CONST.ONE:=ONE_PACKED;
 SSE_CONST.MINUS_ONE:=MINUS_ONE_PACKED;
end.
