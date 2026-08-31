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
