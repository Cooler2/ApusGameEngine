// THIS UNIT IS DEPRECATED AND SHOULD NOT BE USED ANYMORE!
// USE FastGFX for similar functionality

// This unit is intended for blitting/conversion operations using MMX
// Only low-level operations with strings of pixels, inner loops
// No clipping, no scaling
// Copyright (C) Apus Software
// apussoftware@games4win.com
// Ivan Polyacov, ivan@apus-software.com
{$IFDEF FPC}{$PIC OFF}{$ENDIF}

unit blitter;
interface

 // Blit count pixels form 32bit 8-8-8 to 16bit 5-6-5
 procedure Blt32to16(var sour;var dest;count:integer); pascal;

 // Blit count pixels form 32bit 8-8-8 to 15bit 5-5-5
 procedure Blt32to15(var sour;var dest;count:integer); pascal;

 // Blit count pixels from 32bit RGBA to 32bit RGB
 procedure Blt32Alpha(var sour;var dest;count:integer); pascal;

 // Blit count pixels from 8-bit paletted (with alpha) to 32bit RGB
 procedure Blt8to32Alpha(var palette;var sour;var dest;count:integer); pascal;

 // Blit count pixels from 8-bit paletted (with alpha) to 32bit RGB
 // Index 0 is transparent
 procedure Blt8to32AlphaTransp(var palette;var sour;var dest;count:integer); pascal;

 // Blit count pixels from 8-bit paletted (without alpha) to 32bit RGB
 // Index 0 is transparent
 procedure Blt8to32Transp(var palette;var sour;var dest;count:integer); pascal;

 // Blit count pixels from 8-bit paletted (without alpha) to 32bit RGB
 // Index 0 is transparent
 procedure Blt8to32TranspAdd(var palette;var sour;var dest;count:integer); pascal;

 // Blit count pixels into dest using alpha from sour and given color
 // Use GlobalAlpha as alpha scale (0 - 128)
 procedure BltColorTo32Alpha(var sour;var dest;count,color:integer;GlobalAlpha:byte); pascal;

 // paddusb for count pixels (dest:=dest+sour)
 procedure SaturatedAdd32(var sour;var dest;count:integer); pascal;

 // subtract set of bytes (dest:=dest-sour)
 procedure Subtract8(var sour;var dest;count:integer); pascal;

 // Multiply count pixels by value
 procedure Mult32(var sour;count:integer;value:cardinal); pascal;

 procedure Add32(var sour;count:integer;value:cardinal); pascal;

implementation
 const
  mask16Red:array[0..1] of cardinal=($F80000,$F80000);
  mask16Green:array[0..1] of cardinal=($FC00,$FC00);
  mask16Blue:array[0..1] of cardinal=($F8,$F8);

  mask15Red:array[0..1] of cardinal=($F80000,$F80000);
  mask15Green:array[0..1] of cardinal=($F800,$F800);
  mask15Blue:array[0..1] of cardinal=($F8,$F8);

 procedure Blt32to16;
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   or ecx,ecx
   jz @exit
   test edi,3
   jz @NoStarting
   // Convert first pixel
   mov eax,[esi]
   shr eax,3
   shl al,2
   add esi,4
   shl ax,3
   dec ecx
   shr eax,5
   mov [edi],ax
   add edi,2

@NoStarting:
   push ecx
   shr ecx,1 // Nubber of pixel pairs
   jz @Last
   db $0F,$EF,$FF           /// pxor mm7,mm7
   test cl,1
//   jz @FastLoop

@inner:
   movq mm0,[esi]
   movq mm1,mm0
   movq mm2,mm0
   {
   db $0F,$6F,$06           /// movq mm0,[esi]
   db $0F,$6F,$C8           /// movq mm1,mm0
   db $0F,$6F,$D0           /// movq mm2,mm0}
   add esi,8

   pand mm1,mask16Red
{   db $0F,$DB,$0D
   dd offset mask16Red}
   psrld mm1,8
//   db $0F,$72,$D1,$08
   pand mm2,mask16Green
{   db $0F,$DB,$15
   dd offset mask16Green}

   db $0F,$72,$D2,$05       /// psrld mm2,5
   db $0F,$EB,$CA           /// por mm1,mm2
   pand mm0,mask16Blue
{   db $0F,$DB,$05
   dd offset mask16Blue}

   db $0F,$72,$D0,$03       /// psrld mm0,3
   db $0F,$EB,$C8           /// por mm1,mm0
   db $0F,$6F,$D1           /// movq mm2,mm1
   db $0F,$73,$D2,$10       /// psrlq mm2,16
   db $0F,$EB,$CA           /// por mm1,mm2
   db $0F,$7E,$0F           /// movd [edi],mm1
   add edi,4
   dec ecx
   jnz @inner
   jmp @last

@Last:
   pop ecx
   test cl,1
   jz @exit
   // Convert last pixel
   mov eax,[esi]
   shr eax,3
   shl al,2
   shl ax,3
   shr eax,5
   mov [edi],ax

@exit:
   popad
   db $0F,$77               /// emms
  end;

 { TODO 2 -oCooler : Test 15-bit blt }
 procedure Blt32to15;
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   or ecx,ecx
   jz @exit
   test edi,3
   jz @NoStarting
   // Convert first pixel
   mov eax,[esi]
   shr eax,3
   shl al,3
   add esi,4
   shl ax,3
   dec ecx
   shr eax,6
   mov [edi],ax
   add edi,2

@NoStarting:
   push ecx
   shr ecx,1 // Nubber of pixel pairs
   jz @Last

   db $0F,$EF,$FF           /// pxor mm7,mm7
@inner:
   db $0F,$6F,$06           /// movq mm0,[esi]
   db $0F,$6F,$C8           /// movq mm1,mm0
   db $0F,$6F,$D0           /// movq mm2,mm0
   add esi,8
   pand mm1,mask16Red
{   db $0F,$DB,$0D
   dd offset mask15Red}
   db $0F,$72,$D1,$09       /// psrld mm1,9
   pand mm2,mask16Green
{   db $0F,$DB,$15
   dd offset mask15Green}

   db $0F,$72,$D2,$06       /// psrld mm2,6
   db $0F,$EB,$CA           /// por mm1,mm2
   pand mm0,mask16Blue
{   db $0F,$DB,$05
   dd offset mask15Blue}

   db $0F,$72,$D0,$03       /// psrld mm0,3
   db $0F,$EB,$C8           /// por mm1,mm0
   db $0F,$6B,$CF           /// packssdw mm1,mm7
   db $0F,$7E,$0F           /// movd [edi],mm1
   add edi,4
   dec ecx
   jnz @inner

@Last:
   pop ecx
   test cl,1
   jz @exit
   // Convert last pixel
   mov eax,[esi]
   shr eax,3
   shl al,3
   shl ax,3
   shr eax,6
   mov [edi],ax

@exit:
   popad
   db $0F,$77               /// emms
  end;

 procedure Blt32Alpha;
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   mov eax,ecx
   shl eax,2
   add esi,eax
   add edi,eax
   neg ecx
   db $0F,$EF,$FF           /// pxor mm7,mm7

@inner:
   db $0F,$6E,$04,$8E       /// movd mm0,[esi+ecx*4] // pixel
   db $0F,$6E,$14,$8F       /// movd mm2,[edi+ecx*4] // background
   db $0F,$60,$C7           /// punpcklbw mm0,mm7 // pixel
   db $0F,$60,$D7           /// punpcklbw mm2,mm7 // background
   db $0F,$6F,$C8           /// movq mm1,mm0      // save color
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step1
   db $0F,$F9,$CA           /// psubw mm1,mm2     // mm1 - difference
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step2
   db $0F,$D5,$C8           /// pmullw mm1,mm0    // Calculate difference
   db $0F,$71,$D1,$08       /// psrlw mm1,8       // -> to 8 bit
   db $0F,$FC,$D1           /// paddb mm2,mm1     // Add it with overflow
   db $0F,$67,$D7           /// packuswb mm2,mm7  // pack pixel
   db $0F,$7E,$14,$8F       /// movd [edi+ecx*4],mm2
   inc ecx
   jnz @inner

@exit:
   popad
   db $0F,$77               /// emms
  end;

 procedure Blt8to32Alpha(var palette;var sour;var dest;count:integer);
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ebx,palette
   mov ecx,count
   mov eax,ecx
   add esi,ecx
   shl eax,2
   add edi,eax
   neg ecx
   db $0F,$EF,$FF           /// pxor mm7,mm7

@inner:
   movzx eax,byte ptr [esi+ecx]
   db $0F,$6E,$04,$83       /// movd mm0,[ebx+eax*4] // pixel from palette
   db $0F,$7E,$C0           /// movd eax,mm0
   db $0F,$6E,$14,$8F       /// movd mm2,[edi+ecx*4] // background
   shr eax,24
   db $0F,$60,$C7           /// punpcklbw mm0,mm7 // pixel
   or al,al
   jz @skip
   db $0F,$60,$D7           /// punpcklbw mm2,mm7 // background
   inc al
   jnz @alpha
   db $0F,$7E,$04,$8F       /// movd [edi+ecx*4],mm0
   jmp @skip
@alpha:
   db $0F,$6F,$C8           /// movq mm1,mm0      // save color
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step1
   db $0F,$F9,$CA           /// psubw mm1,mm2     // mm1 - difference
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step2
   db $0F,$D5,$C8           /// pmullw mm1,mm0    // Calculate difference
   db $0F,$71,$D1,$08       /// psrlw mm1,8       // -> to 8 bit
   db $0F,$FC,$D1           /// paddb mm2,mm1     // Add it with overflow
   db $0F,$67,$D7           /// packuswb mm2,mm7  // pack pixel
   db $0F,$7E,$14,$8F       /// movd [edi+ecx*4],mm2
@skip:
   inc ecx
   jnz @inner

@exit:
   popad
   db $0F,$77               /// emms
  end;

 procedure Blt8to32AlphaTransp(var palette;var sour;var dest;count:integer);
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ebx,palette
   mov ecx,count
   mov eax,ecx
   add esi,ecx
   shl eax,2
   add edi,eax
   neg ecx
   db $0F,$EF,$FF           /// pxor mm7,mm7

@inner:
   movzx eax,byte ptr [esi+ecx]
   or eax,eax
   jz @skip
   db $0F,$6E,$04,$83       /// movd mm0,[ebx+eax*4] // pixel from palette
   db $0F,$6E,$14,$8F       /// movd mm2,[edi+ecx*4] // background
   db $0F,$60,$C7           /// punpcklbw mm0,mm7 // pixel
   db $0F,$60,$D7           /// punpcklbw mm2,mm7 // background
   db $0F,$6F,$C8           /// movq mm1,mm0      // save color
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step1
   db $0F,$F9,$CA           /// psubw mm1,mm2     // mm1 - difference
   db $0F,$69,$C0           /// punpckhwd mm0,mm0 // unpack alpha, step2
   db $0F,$D5,$C8           /// pmullw mm1,mm0    // Calculate difference
   db $0F,$71,$D1,$08       /// psrlw mm1,8       // -> to 8 bit
   db $0F,$FC,$D1           /// paddb mm2,mm1     // Add it with overflow
   db $0F,$67,$D7           /// packuswb mm2,mm7  // pack pixel
   db $0F,$7E,$14,$8F       /// movd [edi+ecx*4],mm2
@skip:
   inc ecx
   jnz @inner

@exit:
   popad
   db $0F,$77               /// emms
  end;

 procedure Blt8to32Transp(var palette;var sour;var dest;count:integer);
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ebx,palette
   mov ecx,count
   mov eax,ecx
   add esi,ecx
   shl eax,2
   add edi,eax
   neg ecx

@inner:
   movzx eax,byte ptr [esi+ecx]
   or eax,eax
   jz @skip
   mov edx,[ebx+eax*4] // pixel from palette
   mov [edi+ecx*4],edx
@skip:
   inc ecx
   jnz @inner

@exit:
   popad
  end;

 procedure Blt8to32TranspAdd(var palette;var sour;var dest;count:integer);
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ebx,palette
   mov ecx,count
   mov eax,ecx
   add esi,ecx
   shl eax,2
   add edi,eax
   neg ecx

@inner:
   movzx eax,byte ptr [esi+ecx]
   or eax,eax
   jz @skip
   db $0F,$6E,$04,$83       /// movd mm0,[ebx+eax*4]
   db $0F,$6E,$0C,$8F       /// movd mm1,[edi+ecx*4]
   db $0F,$DC,$C1           /// paddusb mm0,mm1
   db $0F,$7E,$04,$8F       /// movd [edi+ecx*4],mm0
@skip:
   inc ecx
   jnz @inner

@exit:
   popad
   db $0F,$77               /// emms
  end;

 { TODO 1 -oCooler : Unfinished procedure }
 procedure BltColorTo32Alpha;
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   mov eax,color
   db $0F,$6E,$C0           /// movd mm0,eax // color
   db $0F,$EF,$FF           /// pxor mm7,mm7
   db $0F,$60,$C7           /// punpcklbw mm0,mm7 // unpack color
@1: db $0F,$6E,$0F           /// movd mm1,[edi]

   add edi,4
   dec ecx
   jnz @1
   popad
   db $0F,$77               /// emms
  end;

 procedure SaturatedAdd32;
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   test esi,4
   jz @noFirst
   db $0F,$6E,$06           /// movd mm0,[esi]
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$DC,$C1           /// paddusb mm0,mm1
   add esi,4
   db $0F,$7E,$07           /// movd [edi],mm0
   add edi,4
   dec ecx
@noFirst:
   push ecx
   mov ebx,ecx
   shr ecx,1
   and bl,0FEh
   shl ebx,2
   add esi,ebx
   add edi,ebx
   neg ecx
@inner:
   db $0F,$6F,$04,$CE       /// movq mm0,[esi+ecx*8]
   db $0F,$6F,$0C,$CF       /// movq mm1,[edi+ecx*8]
   db $0F,$DC,$C1           /// paddusb mm0,mm1
   db $0F,$7F,$04,$CF       /// movq [edi+ecx*8],mm0
   inc ecx
   jnz @inner

   pop ecx
   test ecx,1
   jz @exit
   db $0F,$6E,$06           /// movd mm0,[esi]
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$DC,$C1           /// paddusb mm0,mm1
   db $0F,$7E,$07           /// movd [edi],mm0
@exit:
   popad
   db $0F,$77               /// emms
  end;

 procedure Mult32;
  asm
   pushad
   mov esi,sour
   mov eax,value
   db $0F,$6E,$C0           /// movd mm0,eax
   db $0F,$EF,$FF           /// pxor mm7,mm7
   db $0F,$60,$C7           /// punpcklbw mm0,mm7
   mov ecx,count
@inner:
   db $0F,$6E,$0E           /// movd mm1,[esi]
   db $0F,$60,$CF           /// punpcklbw mm1,mm7
   db $0F,$D5,$C8           /// pmullw mm1,mm0
   db $0F,$71,$D1,$08       /// psrlw mm1,8
   db $0F,$67,$CF           /// packuswb mm1,mm7
   db $0F,$7E,$0E           /// movd [esi],mm1
   add esi,4
   dec ecx
   jnz @inner
   popad
   db $0F,$77               /// emms
  end;

         { TODO 1 -oCooler : Optimize it! }
 procedure Add32;
  asm
   pushad
   mov esi,sour
   mov eax,value
   db $0F,$6E,$C0           /// movd mm0,eax
   mov ecx,count
@inner:
   db $0F,$6E,$0E           /// movd mm1,[esi]
   db $0F,$DC,$C8           /// paddusb mm1,mm0
   db $0F,$7E,$0E           /// movd [esi],mm1
   add esi,4
   dec ecx
   jnz @inner
   popad
   db $0F,$77               /// emms
  end;

 procedure subtract8;
  asm
   pushad
   mov ecx,count
   mov esi,sour
   mov edi,dest
@01:test esi,7
   jz @02
   mov al,[esi]
   sub [edi],al
   inc esi
   inc edi
   dec ecx
   jmp @01
@02:
   push ecx
   shr ecx,3
   jz @none
@inner:
   db $0F,$6F,$06           /// movq mm0,[esi]
   db $0F,$6F,$0F           /// movq mm1,[edi]
   db $0F,$F8,$C8           /// psubb mm1,mm0
   db $0F,$7F,$0F           /// movq [edi],mm1
   add esi,8
   add edi,8
   dec ecx
   jnz @inner
@none:
   pop ecx
   and ecx,0FFFFF8h
@03: jz @exit
   mov al,[esi]
   sub [edi],al
   inc esi
   inc edi
   dec ecx
   jmp @03
@exit:
   popad
   db $0F,$77               /// emms
  end;

end.

