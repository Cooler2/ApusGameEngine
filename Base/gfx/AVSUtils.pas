unit AVSUtils;
interface
 uses MyServis,types,Images;

 function Pack666_Encode(pixels:pointer;pitch:integer;width,height:integer;buf:pointer;size:integer):integer;

 // Build stream for downsampled image, returns stream size in bytes
 // Caller must allocate enough space
 function Downsample2X_Encode(pixels:pointer;pitch:integer;width,height:integer;buf:pointer;size:integer):integer;

implementation

 function Pack666_Encode(pixels:pointer;pitch:integer;width,height:integer;buf:pointer;size:integer):integer;
  var
   pc:PByte;
   pb:PByte;
   x,y,bits:integer;
   v,w:cardinal;
  begin
   y:=0;
   pb:=buf;
   bits:=0;
   for y:=0 to height-1 do begin
    pc:=pixels; inc(pc,y*pitch);
    for x:=0 to width-1 do begin
     v:=(PCardinal(pc)^ shr 2) and $3F3F3F;
     w:=v and $3F; // blue
     w:=w shl 6;
     v:=v shr 6;
     w:=w or (v and $3F); // green
     w:=w shl 6;
     v:=v shr 6;
     w:=w or v; // red
     inc(pc,4);
     w:=w shl bits;
     PCardinal(pb)^:=(PCardinal(pb)^ and ((1 shl bits)-1)) or w;
     inc(bits,18);
     while bits>8 do begin
      inc(pb);
      dec(bits,8);
     end;
    end;
   end;
  end;

 function Downsample2X_Encode(pixels:pointer;pitch:integer;width,height:integer;buf:pointer;size:integer):integer;
  var
   pc:PByte;
   pb:PByte;
   x,y,bits:integer;
  begin
   y:=0;
   pb:=buf;
   bits:=0;
   repeat
    pc:=pixels;
    inc(pc,pitch*y);
    asm
     push esi
     mov esi,pc
     mov ecx,width
@01: mov eax,[esi] // source pixel
     // pack to 6-6-6
     xor edx,edx
     shr eax,2
     mov edx,eax
     and edx,63

     add pc,8
     dec ecx
     jnz @01
     pop esi
    end;
    inc(y,2);
   until y>=height;
  end;

end.
