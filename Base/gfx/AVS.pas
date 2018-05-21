unit AVS;
interface
 uses MyServis,Images,types;

 const
  MAGIC_DWORD = $20535641;

  // P-Frame packing methods
  AVS_DOWNSAMPLE2X_RAW = 1; //  адр уменьшаетс€ в 2 раза
  AVS_INTERPOLATED     = 2; //
  AVS_RAW18            = 3; // RAW 18bpp (6-6-6)

  // Frame types
  AVS_PFRAME    = $100;
  AVS_DFRAME    = $200;

 type
  // AVS состоит из последовательности кадров, прив€занных к определЄнным временным точкам
  //  аждый кадр содержит 1 или более чанков различных типов.
  // „анки могут описывать изображение кадра или его части, звук, различную вспомогательную информацию

  // AVS frame header
  TFrameHeader=packed record
   magic:cardinal; // 'AVS '
   timestamp:cardinal;
   frameType:word;
   frameNum:word;
   frameSize:cardinal;
  end;

  // “ип чанков:
  // 0XXX - пр€моугольник изображени€, закодированный методом XXX
  // 1XXX - аудиоданные, закодированные методом XXX
  // 200X - информаци€ о потоке (включаетс€ в 1-й кадр):
  //   2000 - размеры и т.п.
  //   2001 - текстова€ информаци€
  //   2002 - каталог P-кадров

  // Frame chunk
  TChunkHeader=packed record
   cSize:integer;  // size in bytes including this header
   cType:cardinal; // data type and options
   x,y,width,height:word; // frame area
  end;

  // Chunk type=2000
  TAVSInfo=packed record
   duration:cardinal;
   numFrames:cardinal;
   flags:cardinal;
  end;

 // —равнивает 2 кадра и возвращает true если кадры похожи и лучше использовать D-Frame дл€ сжати€
 function CompareFrames(oldFrame,newFrame:TRAWImage;options:cardinal=0):boolean;

 procedure PackPFrame(frame:TRAWImage;r:TRect;var buf:ByteArray;options:cardinal);
 procedure PackDFrame(frame,oldFrame:TRAwImage;r:TRect;var buf:ByteArray;options:cardinal);

implementation
 uses FastGfx,AVSUtils;

 function CompareFrames(oldFrame,newFrame:TRAWImage;options:cardinal=0):boolean;
  var
   i,j,w,h:integer;
   d1,d2:PByte;
   cnt:integer;
  begin
   cnt:=0;
   w:=oldFrame.width div 16;
   h:=oldFrame.height div 10;
   for i:=0 to 15 do begin
    d1:=oldframe.data;
    inc(d1,oldFrame.pitch*w*i);
    d2:=newFrame.data;
    inc(d2,newFrame.pitch*w*i);
    asm
     push esi
     push edi
     mov esi,d1
     mov edi,d2
     mov eax,w
     shl eax,2
     mov ecx,16
@01: mov edx,[esi]
     cmp edx,[edi]
     jne @ne
     mov edx,[esi+4]
     cmp edx,[edi+4]
     jne @ne
     inc cnt
@ne:
     add esi,eax
     add edi,eax
     dec ecx
     jnz @01
     pop edi
     pop esi
    end;
   end;
   result:=cnt<80;
  end;

 procedure InitHeader(var header:TChunkHeader;r:TRect;cSize:integer;cType:cardinal);
  begin
   header.cSize:=cSize;
   header.cType:=cType;
   header.x:=r.Left;
   header.y:=r.Top;
   header.width:=r.right-r.left;
   header.height:=r.Bottom-r.Top;
  end;

 procedure PackDownsampled2X(frame:TRAWImage;r:TRect;var buf:ByteArray);
  var
   width,height,size:integer;
   header:TChunkHeader;
  begin
   width:=r.right-r.left;
   height:=r.Bottom-r.Top;
   size:=((width div 2)*(height div 2)*18+7) div 8;
   SetLength(buf,size+16);

//   Downsample2X_Encode(frame,r,@buf[16],size);

   InitHeader(header,r,length(buf),AVS_PFRAME+AVS_DOWNSAMPLE2X_RAW);
   move(header,buf[0],16);
  end;

 procedure PackRAW18(frame:TRAWImage;r:TRect;var buf:ByteArray);
  var
   width,height,size:integer;
   header:TChunkHeader;
  begin
   width:=r.right-r.left;
   height:=r.Bottom-r.Top;
   size:=(width*height*18+31) div 8;
   SetLength(buf,size+16);

   Pack666_Encode(GetPixelAddr(frame.data,frame.pitch,r.left,r.top),frame.pitch,width,height,@buf[16],size);

   InitHeader(header,r,length(buf),AVS_PFRAME+AVS_RAW18);
   move(header,buf[0],16);
  end;

 procedure PackPFrame(frame:TRAwImage;r:TRect;var buf:ByteArray;options:cardinal);
  var
   method:byte;
  begin
   method:=options and $FF;
   case method of
    AVS_DOWNSAMPLE2X_RAW:PackDownsampled2X(frame,r,buf);
    AVS_RAW18:PackRAW18(frame,r,buf);
   end;
  end;

 procedure PackDFrame(frame,oldFrame:TRAWImage;r:TRect;var buf:ByteArray;options:cardinal);
  begin

  end;

end.
