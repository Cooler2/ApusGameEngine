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
  b,g,r,a:byte;
 end;
 PARGBColor=^TARGBColor;

 function MyColor(r,g,b:cardinal):cardinal; overload;
 function MyColor(a,r,g,b:cardinal):cardinal; overload;
 function GrayColor(gray:integer):cardinal; // FFxxxxxx
 function GrayAlpha(alpha:single):cardinal; // aa808080
 function SwapColor(color:cardinal):cardinal; // swap red<->blue bytes
 function GetAlpha(color:cardinal):single;

 function ColorAdd(c1,c2:cardinal):cardinal;
 function ColorSub(c1,c2:cardinal):cardinal;
 function ColorMult2(c1,c2:cardinal):cardinal;
 // Multiply color by (alpha,1,1,1)
 function ColorAlpha(color:cardinal;alpha:single):cardinal;
 function ReplaceAlpha(color:cardinal;alpha:single):cardinal;
 // value=0 -> c2, value=256 -> c1
 function ColorMix(c1,c2:cardinal;value:integer):cardinal; register; // Линейная интерполяция
 function ColorBlend(c1,c2:cardinal;value:integer):cardinal; // Качественный квази-линейный бленд (гораздо медленнее!)
 function BilinearMix(c0,c1,c2,c3:cardinal;u,v:single):cardinal; // Билинейная интерполяция
 function BilinearBlend(c0,c1,c2,c3:cardinal;v1,v2:single):cardinal; // Качественный квази-билинейный бленд (гораздо медленнее!)
 function Blend(background,foreground:cardinal):cardinal; // Качественный альфа-блендинг

 function Lightness(color:cardinal):byte; // яркость цвета (0..255)

 // value - -120..120
 function Brightness(c:cardinal;value:integer):cardinal;
 // Value - 0..500, 256 - neutral
 function Contrast(c:cardinal;value:integer):cardinal;

implementation
 uses Apus.MyServis;
 {$R-,Q-}

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

 function GetAlpha(color:cardinal):single;
  begin
   result:=(color shr 24)/255;
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
{  var
   val2:integer;
   a,r,g,b:byte;
   col1:TARGBColor absolute c1;
   col2:TARGBColor absolute c2;
  begin
   val2:=256-value;
   a:=(col1.a*value+col2.a*val2) shr 8;
   r:=(col1.r*value+col2.r*val2) shr 8;
   g:=(col1.g*value+col2.g*val2) shr 8;
   b:=(col1.b*value+col2.b*val2) shr 8;
   result:=a shl 24+r shl 16+g shl 8+b;
  end; }

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
{  var
   val2,m:integer;
   a,r,g,b:byte;
   col1:TARGBColor absolute c1;
   col2:TARGBColor absolute c2;
  begin
   val2:=256-value;
   a:=(col1.a*value+col2.a*val2) shr 8;
   m:=16842752 div (col1.a*value+col2.a*val2+1);
   value:=m*(value*col1.a) shr 16;
   val2:=m*(val2*col2.a) shr 16;
   r:=(col1.r*value+col2.r*val2) shr 8;
   g:=(col1.g*value+col2.g*val2) shr 8;
   b:=(col1.b*value+col2.b*val2) shr 8;
   result:=a shl 24+r shl 16+g shl 8+b;
  end;}

 function BilinearMix(c0,c1,c2,c3:cardinal;u,v:single):cardinal; // Билинейная интерполяция
  // Integer version
  var
   v0,v1,v2,v3:integer;
//   v0,v1,v2,v3:single;
  begin
   v3:=round(256*(u)*(v));
   v1:=round(256*(u)*(1-v));
   v0:=round(256*(1-u)*(1-v));
   v2:=round(256*(1-u)*(v));
{   v0:=(1-u)*(1-v);
   v1:=u*(1-v);
   v2:=(1-u)*v;
   v3:=u*v;
   result:=round(byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3); // blue part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result+round(byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) shl 8; // green part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result+round((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3)) shl 16; // red part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result+round((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3)) shl 24; // alpha part  }
   result:=(byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) shr 8; // blue part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) and $FF00); // green part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal(((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) shl 8) and $FF0000); // red part
   c0:=c0 shr 8; c1:=c1 shr 8; c2:=c2 shr 8; c3:=c3 shr 8;
   result:=result or cardinal(((byte(c0)*v0+byte(c1)*v1+byte(c2)*v2+byte(c3)*v3) and $FF00) shl 16); // alpha part
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

end.
