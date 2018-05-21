unit DirectSprite;
interface
type
 GraphicsBuffer=record
  buffer:pointer;
  bpp:byte;
  width,height,pitch:integer;
  ClipX1,ClipY1,ClipX2,ClipY2:integer;
  UseClipping:boolean;
 end;

const
 DS_Copy                = 1;
 DS_ColorKey            = 2;
 DS_Alpha               = 3;
 DS_Add                 = 4;
 DS_Sub                 = 5;
 DS_Mult                = 6;
 DS_Overlay             = 7;

var
 DS_DestBuffer:GraphicsBuffer;  // Destination buffer (must be initialized before any blitting!)

// High level routines ///////////////////////////////////////////////
//---------------------

 // this draws sprite into (x,y), pass width=height=0 to get their
 // values from sprite
 procedure DrawSprite(x,y,s_width,s_height:integer;var sprite;operation:integer);

// Low level routines ////////////////////////////////////////////////
// ------------------

 // This copies 32bit RGB block from address "FROM", widht: w, height: h,
 // into position (x,y)
 procedure BltRGBto32(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;

 // This blits 32bit RGB block from address "FROM", widht: w, height: h,
 // into position (x,y) using saturated adding or subtraction
 procedure BltRGBto32Add(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;
 procedure BltRGBto32Sub(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;
 // The same but using multiply or overlay filtering
 procedure BltRGBto32Mult(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;
 procedure BltRGBto32Over(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;

 // This blits 32bit RGB block from address "FROM", widht: w, height: h,
 // into position (x,y) using color key (key=#000000)
 procedure BltRGBto32Key(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;

 // This blit 32bit RGBA block from address "FROM", widht: w, height: h,
 // into position (x,y) using MMX alpha blending
 procedure BltRGBAto32(x,y,w,h:integer;Sour_pitch:integer;from:pointer); pascal;

implementation
type
 PDW=^cardinal;
 PUInt=^SmallInt;

 procedure DrawSprite;
  var
   h,w,nx,ny:smallint;
   o:cardinal;
  begin
   with DS_DestBuffer do begin
    o:=cardinal(addr(sprite));
    h:=s_height; w:=s_width;
    if (h=0) and (w=0) then begin
     w:=PUInt(o)^; inc(o,2);
     h:=PUInt(o)^; inc(o,2);
    end;
    if not UseClipping then begin
     case operation of
      DS_Copy           : BltRGBto32(x,y,w,h,w*4,pointer(o));
      DS_ColorKey       : BltRGBto32Key(x,y,w,h,w*4,pointer(o));
      DS_Alpha          : BltRGBAto32(x,y,w,h,w*4,pointer(o));
      DS_Add            : BltRGBto32Add(x,y,w,h,w*4,pointer(o));
      DS_Sub            : BltRGBto32Sub(x,y,w,h,w*4,pointer(o));
      DS_Mult           : BltRGBto32Mult(x,y,w,h,w*4,pointer(o));
      DS_Overlay        : BltRGBto32Over(x,y,w,h,w*4,pointer(o));
     end;
     exit;
    end;
    if (x>=ClipX2) or (y>=ClipY2) or
     (x+w<=ClipX1) or (y+h<=ClipY1) then exit;
    nx:=w; ny:=h;
    if x+w>=ClipX2 then dec(nx,x+w-ClipX2+1);
    if y+h>=ClipY2 then dec(ny,y+h-ClipY2+1);
    if x<ClipX1 then begin dec(nx,ClipX1-x); inc(o,(Clipx1-x)*4); x:=ClipX1; end;
    if y<ClipY1 then begin dec(ny,ClipY1-y); inc(o,(ClipY1-y)*4*w); y:=CLipY1; end;
    case operation of
     DS_Copy           : BltRGBto32(x,y,nx,ny,w*4,pointer(o));
     DS_ColorKey       : BltRGBto32Key(x,y,nx,ny,w*4,pointer(o));
     DS_Alpha          : BltRGBAto32(x,y,nx,ny,w*4,pointer(o));
     DS_Add            : BltRGBto32Add(x,y,nx,ny,w*4,pointer(o));
     DS_Sub            : BltRGBto32Sub(x,y,nx,ny,w*4,pointer(o));
     DS_Mult           : BltRGBto32Mult(x,y,nx,ny,w*4,pointer(o));
     DS_Overlay        : BltRGBto32Over(x,y,nx,ny,w*4,pointer(o));
    end;
   end;
  end;

 procedure BltRGBto32;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
@outer:
   push esi
   push edi
   mov ecx,w
   rep movsd
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBto32Add;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   db $0F,$6E,$C0           /// movd mm0,eax
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$DC,$C1           /// paddusb mm0,mm1
   db $0F,$7E,$07           /// movd [edi],mm0
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBto32Sub;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   db $0F,$6E,$C0           /// movd mm0,eax
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$D8,$C8           /// psubusb mm1,mm0
   db $0F,$7E,$0F           /// movd [edi],mm1
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBto32Mult;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
   db $0F,$EF,$FF           /// pxor mm7,mm7
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   db $0F,$6E,$C0           /// movd mm0,eax
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$60,$C7           /// punpcklbw mm0,mm7
   db $0F,$60,$CF           /// punpcklbw mm1,mm7
   db $0F,$D5,$C1           /// pmullw mm0,mm1
   db $0F,$71,$D0,$08       /// psrlw mm0,8
   db $0F,$67,$C7           /// packuswb mm0,mm7
   db $0F,$7E,$07           /// movd [edi],mm0
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBto32Over;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
   mov eax,$808080
   db $0F,$6E,$F0           /// movd mm6,eax
   db $0F,$EF,$FF           /// pxor mm7,mm7
   db $0F,$60,$F7           /// punpcklbw mm6,mm7
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   db $0F,$6E,$C0           /// movd mm0,eax
   db $0F,$6E,$0F           /// movd mm1,[edi]
   db $0F,$60,$C7           /// punpcklbw mm0,mm7
   db $0F,$60,$CF           /// punpcklbw mm1,mm7
   db $0F,$F9,$C6           /// psubw mm0,mm6
   db $0F,$71,$F0,$01       /// psllw mm0,1
   db $0F,$FD,$C8           /// paddw mm1,mm0
   db $0F,$67,$CF           /// packuswb mm1,mm7
   db $0F,$7E,$0F           /// movd [edi],mm1
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBto32Key;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   or eax,eax
   jz @skip
   mov [edi],eax
@skip:
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

 procedure BltRGBAto32;
  asm
   pushad
   mov eax,y
   imul DS_DestBuffer.pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,DS_DestBuffer.buffer
   mov esi,from
   mov edx,h
   db $0F,$EF,$FF           /// pxor mm7,mm7
@outer:
   push esi
   push edi
   mov ecx,w
@inner:
   lodsd
   db $0F,$6E,$C0           /// movd mm0,eax
   shr eax,24
   or al,al
   jz @Skip
   cmp al,$ff
   je @copy
   // Transparency
   mov ah,al
   db $0F,$6E,$0F           /// movd mm1,[edi]
   shl eax,8
   db $0F,$60,$C7           /// punpcklbw mm0,mm7
   mov al,ah
   db $0F,$60,$CF           /// punpcklbw mm1,mm7
   db $0F,$6E,$D0           /// movd mm2,eax
   db $0F,$F9,$C1           /// psubw mm0,mm1
   db $0F,$60,$D7           /// punpcklbw mm2,mm7
   db $0F,$D5,$C2           /// pmullw mm0,mm2
   db $0F,$71,$D0,$08       /// psrlw mm0,8
   db $0F,$FC,$C1           /// paddb mm0,mm1
   db $0F,$67,$C7           /// packuswb mm0,mm7
@copy:
   db $0F,$7E,$07           /// movd [edi],mm0
@Skip:
   add edi,4
   dec ecx
   jnz @inner
   pop edi
   pop esi
   add edi,DS_DestBuffer.Pitch
   add esi,sour_pitch
   dec edx
   jnz @outer
   popad
   db $0F,$77               /// emms
  end;

end.
