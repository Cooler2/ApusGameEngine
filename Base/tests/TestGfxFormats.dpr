{$APPTYPE CONSOLE}
program TestGfxFormats;
// Tests for Apus.GfxFormats - image file header parsing (CheckImageFormat) and the DDS data layout.
// Headers are built in memory, so no image files and no LodePNG library are needed.
uses
  SysUtils,
  Apus.Core, Apus.Images, Apus.GfxFormats;

{$INCLUDE Test.inc}

// store a 32-bit big-endian value (PNG byte order)
procedure PutBE(var data:ByteArray;offset:integer;value:cardinal);
begin
  data[offset]:=(value shr 24) and $FF;
  data[offset+1]:=(value shr 16) and $FF;
  data[offset+2]:=(value shr 8) and $FF;
  data[offset+3]:=value and $FF;
end;

// store a 32-bit little-endian value (DDS byte order)
procedure PutLE(var data:ByteArray;offset:integer;value:cardinal);
begin
  data[offset]:=value and $FF;
  data[offset+1]:=(value shr 8) and $FF;
  data[offset+2]:=(value shr 16) and $FF;
  data[offset+3]:=(value shr 24) and $FF;
end;

// build a minimal PNG: 8-byte signature + IHDR chunk (image data is never needed)
function MakePNG(width,height:cardinal;bitDepth,colorType:byte):ByteArray;
begin
  SetLength(result,33);
  FillChar(result[0],33,0);
  result[0]:=$89; result[1]:=$50; result[2]:=$4E; result[3]:=$47; // signature
  result[4]:=$0D; result[5]:=$0A; result[6]:=$1A; result[7]:=$0A;
  PutBE(result,8,13); // IHDR chunk length
  result[12]:=$49; result[13]:=$48; result[14]:=$44; result[15]:=$52; // 'IHDR'
  PutBE(result,16,width);
  PutBE(result,20,height);
  result[24]:=bitDepth;
  result[25]:=colorType;
  // 26..28: compression, filter, interlace; 29..32: CRC - all left zero
end;

// Build a WebP extended header. The test checks only signature and dimensions.
function MakeWebP(width,height:cardinal;animated:boolean=false):ByteArray;
begin
  SetLength(result,30);
  FillChar(result[0],length(result),0);
  result[0]:=82; result[1]:=73; result[2]:=70; result[3]:=70; // RIFF
  PutLE(result,4,22);
  result[8]:=87; result[9]:=69; result[10]:=66; result[11]:=80; // WEBP
  result[12]:=86; result[13]:=80; result[14]:=56; result[15]:=88; // VP8X
  PutLE(result,16,10);
  if animated then result[20]:=2;
  dec(width); dec(height);
  result[24]:=width and $FF;
  result[25]:=(width shr 8) and $FF;
  result[26]:=(width shr 16) and $FF;
  result[27]:=height and $FF;
  result[28]:=(height shr 8) and $FF;
  result[29]:=(height shr 16) and $FF;
end;

// build a DDS file: 'DDS ' + 124-byte DDSURFACEDESC2 + pixel data filled with a pattern
function MakeDDS(width,height:cardinal;const fourCC:string;mipLevels:cardinal;dataSize:integer):ByteArray;
var
  i:integer;
begin
  SetLength(result,128+dataSize);
  FillChar(result[0],length(result),0);
  result[0]:=byte('D'); result[1]:=byte('D'); result[2]:=byte('S'); result[3]:=byte(' ');
  PutLE(result,4,124);      // dwSize
  PutLE(result,8,$0081007); // dwFlags: caps+height+width+pixelformat+linearsize+mipmapcount
  PutLE(result,12,height);
  PutLE(result,16,width);
  PutLE(result,20,dataSize); // dwLinearSize
  PutLE(result,28,mipLevels);
  PutLE(result,76,32); // ddpfPixelFormat.dwSize
  PutLE(result,80,4);  // ddpfPixelFormat.dwFlags: DDPF_FOURCC
  for i:=1 to 4 do
    result[83+i]:=byte(fourCC[i]); // dwFourCC at offset 84
  for i:=0 to dataSize-1 do
    result[128+i]:=(i*7+1) and $FF; // recognizable pixel data
end;

function PNGFormat(width,height:cardinal;bitDepth,colorType:byte):TImagePixelFormat;
begin
  CheckImageFormat(MakePNG(width,height,bitDepth,colorType));
  result:=imgInfo.format;
end;

// CheckImageFormat must report the format LoadPNG will produce, not the stored one
procedure TestPNGHeader;
begin
  StartTest('PNG header');
  Check(CheckImageFormat(MakePNG(16,8,8,6))=ifPNG,'PNG signature is recognized');
  CheckImageFormat(MakePNG(16,8,8,6));
  Check((imgInfo.width=16) and (imgInfo.height=8),'IHDR dimensions');
  CheckImageFormat(MakePNG(70000,100000,8,6));
  Check((imgInfo.width=70000) and (imgInfo.height=100000),'dimensions above 65535 (full 32 bit fields)');
  Check(PNGFormat(4,4,8,0)=ipfMono8,'8 bit grayscale -> Mono8');
  Check(PNGFormat(4,4,4,0)=ipfMono8,'4 bit grayscale -> Mono8');
  Check(PNGFormat(4,4,16,0)=ipfMono8,'16 bit grayscale -> Mono8 (no 16 bit support)');
  Check(PNGFormat(4,4,8,2)=ipfXRGB,'8 bit truecolor -> XRGB');
  Check(PNGFormat(4,4,16,2)=ipfXRGB,'16 bit truecolor -> XRGB');
  Check(PNGFormat(4,4,8,3)=ipfARGB,'8 bit palette -> ARGB');
  Check(PNGFormat(4,4,4,3)=ipfARGB,'4 bit palette -> ARGB');
  Check(PNGFormat(4,4,1,3)=ipfARGB,'1 bit palette -> ARGB');
  Check(PNGFormat(4,4,8,4)=ipfARGB,'8 bit grayscale+alpha -> ARGB');
  Check(PNGFormat(4,4,16,4)=ipfARGB,'16 bit grayscale+alpha -> ARGB');
  Check(PNGFormat(4,4,8,6)=ipfARGB,'8 bit truecolor+alpha -> ARGB');
  Check(PNGFormat(4,4,16,6)=ipfARGB,'16 bit truecolor+alpha -> ARGB');
  EndTest;
end;

// Two grayscale pixels (0 and 255) exercise the FPC reader's target stride.
procedure TestPNGGrayDecode;
const
  png:array[0..67] of byte=(
    $89,$50,$4E,$47,$0D,$0A,$1A,$0A,$00,$00,$00,$0D,$49,$48,$44,$52,
    $00,$00,$00,$02,$00,$00,$00,$01,$08,$00,$00,$00,$00,$D1,$49,$20,
    $56,$00,$00,$00,$0B,$49,$44,$41,$54,$78,$9C,$63,$60,$F8,$0F,$00,
    $01,$02,$01,$00,$42,$BE,$BC,$68,$00,$00,$00,$00,$49,$45,$4E,$44,
    $AE,$42,$60,$82);
var
  data:ByteArray;
  image:TRawImage;
  pixels:PByte;
begin
  StartTest('PNG grayscale decode');
  SetLength(data,SizeOf(png));
  Move(png[0],data[0],SizeOf(png));
  image:=TBitmapImage.Create(2,1,ipfMono8);
  try
    LoadPNG(data,image);
    pixels:=image.data;
    Check(pixels[0]=0,'black grayscale pixel');
    Check(pixels[1]=255,'white grayscale pixel');
  finally
    image.Free;
  end;
  EndTest;
end;

function MakeWebPPixel:ByteArray;
const
  webp:array[0..37] of byte=(
    $52,$49,$46,$46,$1E,$00,$00,$00,$57,$45,$42,$50,$56,$50,$38,$4C,
    $11,$00,$00,$00,$2F,$00,$00,$00,$10,$07,$50,$91,$46,$74,$A6,$44,
    $81,$88,$E8,$7F,$00,$00);
begin
  SetLength(result,SizeOf(webp));
  Move(webp[0],result[0],SizeOf(webp));
end;

function MakeWebPLossyAlpha:ByteArray;
const
  webp:array[0..123] of byte=(
    $52,$49,$46,$46,$74,$00,$00,$00,$57,$45,$42,$50,$56,$50,$38,$58,
    $0A,$00,$00,$00,$10,$00,$00,$00,$01,$00,$00,$01,$00,$00,$41,$4C,
    $50,$48,$05,$00,$00,$00,$00,$FF,$00,$80,$FF,$00,$56,$50,$38,$20,
    $48,$00,$00,$00,$70,$02,$00,$9D,$01,$2A,$02,$00,$02,$00,$00,$80,
    $08,$25,$A0,$02,$74,$BA,$01,$F8,$01,$FA,$00,$03,$32,$95,$DF,$00,
    $00,$FE,$FF,$7C,$0F,$FC,$A6,$7F,$D5,$33,$FF,$51,$7F,$F9,$B8,$FF,
    $FB,$8A,$FF,$FD,$C1,$2F,$BE,$3F,$FF,$5E,$71,$78,$B5,$83,$BF,$FA,
    $F3,$9F,$FF,$4B,$7B,$77,$EE,$E9,$FF,$4A,$40,$00);
begin
  SetLength(result,SizeOf(webp));
  Move(webp[0],result[0],SizeOf(webp));
end;

procedure TestWebPHeader;
var
  data:ByteArray;
begin
  StartTest('WebP header');
  Check(CheckImageFormat(MakeWebP(1024,768))=ifWebP,'VP8X signature');
  Check((imgInfo.width=1024) and (imgInfo.height=768),'VP8X dimensions');
  Check(imgInfo.format=ipfARGB,'WebP output is RGBA');
  Check(CheckImageFormat(MakeWebPPixel)=ifWebP,'lossless VP8L signature');
  Check((imgInfo.width=1) and (imgInfo.height=1),'VP8L dimensions');
  Check(CheckImageFormat(MakeWebPLossyAlpha)=ifWebP,'VP8X lossy+alpha signature');
  Check((imgInfo.width=2) and (imgInfo.height=2),'VP8X lossy+alpha dimensions');
  Check(CheckImageFormat(MakeWebP(100000,1000))=ifWebP,'24-bit dimensions');
  Check((imgInfo.width=100000) and (imgInfo.height=1000),'large dimensions');
  Check(CheckImageFormat(MakeWebP(16,16,true))=ifUnknown,'animation rejected');
  data:=MakeWebP(16,16);
  SetLength(data,24);
  Check(CheckImageFormat(data)=ifUnknown,'truncated header rejected');
  data:=MakeWebP(16,16);
  data[8]:=0;
  Check(CheckImageFormat(data)=ifUnknown,'RIFF without WEBP rejected');
  EndTest;
end;

{$IFDEF WEBP}
procedure TestWebPDecode;
var
  image:TRawImage;
begin
  StartTest('WebP decode');
  image:=nil;
  try
    LoadWebP(MakeWebPPixel,image);
    Check((image<>nil) and (image.width=1) and (image.height=1),
      'image allocated');
    Check(PCardinal(image.data)^=$44112233,'RGBA pixel converted to ARGB');
  finally
    image.Free;
  end;
  image:=nil;
  try
    LoadWebP(MakeWebPLossyAlpha,image);
    Check((image.width=2) and (image.height=2),'lossy+alpha image allocated');
    Check(PByte(image.scanline(0))[7]=0,'transparent lossy pixel');
    Check(PByte(image.scanline(1))[3]=128,'partial alpha lossy pixel');
  finally
    image.Free;
  end;
  image:=TBitmapImage.Create(1,1,ipfMono8);
  try
    LoadWebP(MakeWebPPixel,image);
    Check(PByte(image.data)^=30,'RGBA pixel converted to Mono8');
  finally
    image.Free;
  end;
  image:=TBitmapImage.Create(1,1,ipfA8);
  try
    LoadWebP(MakeWebPPixel,image);
    Check(PByte(image.data)^=68,'alpha extracted to A8');
  finally
    image.Free;
  end;
  EndTest;
end;
{$ENDIF}

// DDSHeader must be exactly 124 bytes, otherwise every field starting from
// the pixel format is read from a wrong offset (used to break on x64)
procedure TestDDSHeader;
begin
  StartTest('DDS header');
  Check(CheckImageFormat(MakeDDS(64,32,'DXT5',3,2048))=ifDDS,'DDS signature is recognized');
  Check(imgInfo.format=ipfDXT5,'DXT5 FourCC is read from offset 84');
  Check((imgInfo.width=64) and (imgInfo.height=32),'surface dimensions');
  Check(imgInfo.miplevels=3,'mip level count');
  CheckImageFormat(MakeDDS(8,8,'DXT1',1,32));
  Check(imgInfo.format=ipfDXT1,'DXT1 FourCC');
  CheckImageFormat(MakeDDS(8,8,'DXT3',1,64));
  Check(imgInfo.format=ipfDXT3,'DXT3 FourCC');
  EndTest;
end;

// pixel data starts right after the 128-byte prefix (4-byte magic + 124-byte header)
procedure TestDDSData;
var
  data:ByteArray;
  image:TRawImage;
  pb:PByte;
begin
  StartTest('DDS data');
  data:=MakeDDS(8,8,'DXT5',1,64); // 2x2 blocks, 16 bytes each
  image:=nil;
  LoadDDS(data,image,true);
  Check(image<>nil,'image is allocated');
  Check((image.width=2) and (image.height=2),'DXT5 image size is measured in blocks');
  pb:=image.data;
  Check(pb^=data[128],'first byte of the pixel data');
  inc(pb,63);
  Check(pb^=data[191],'last byte of the pixel data');
  image.Free;
  EndTest;
end;

begin
  try
    writeln('Testing [GfxFormats] module');
    writeln;

    TestPNGHeader;
    TestPNGGrayDecode;
    TestWebPHeader;
    {$IFDEF WEBP}TestWebPDecode;{$ENDIF}
    TestDDSHeader;
    TestDDSData;

    writeln;
    if testsFailed=0 then
      writeln('All ',testsTotal,' tests passed!')
    else begin
      writeln(testsFailed,' of ',testsTotal,' tests FAILED');
      ExitCode:=1;
    end;
  except
    on e:Exception do begin
      writeln('Error: ',ExceptionMsg(e));
      ExitCode:=255;
    end;
  end;
  if IsDebuggerPresent then readln;
end.
