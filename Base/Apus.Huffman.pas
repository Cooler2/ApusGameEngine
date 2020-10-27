
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

// Huffman compression - under construction!
//
unit Apus.Huffman;
interface
uses Apus.MyServis;

type
 THuffmanAlphabet = class(TObject);

 // Given the source data array, it builds list of all characters with their
 // occurance rate: low word - character, high word - counter (limited at $FFFF)
 function CreateAlphabetB(data:PByte;size:integer):UIntArray;
 function CreateAlphabetForBytes(data:ByteArray):UIntArray;
 function CreateAlphabetForWords(data:WordArray):UIntArray;

 // Creates Huffman tree for the given alphabet
 function PrepareAlphabet(alphabet:UIntArray):THuffmanAlphabet;

 // Compress data using Huffman tree
 function CompressBytes(context:THuffmanAlphabet;data:ByteArray;out sizeInBits:integer):ByteArray;
 function CompressWords(context:THuffmanAlphabet;data:WordArray;out sizeInBits:integer):ByteArray;
 // Decompress data using Huffman tree
 function DecompressBytes(context:THuffmanAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):ByteArray;
 function DecompressWords(context:THuffmanAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):WordArray;

implementation
 type
  THuffmanAlphabetImpl=class(THuffmanAlphabet)

  end;

 function Compress(context:THuffmanAlphabetImpl;data:PByte;length,elementSize:integer;out sizeInBits:integer):ByteArray;
  begin

  end;

 function CompressBytes(context:THuffmanAlphabet;data:ByteArray;out sizeInBits:integer):ByteArray;
  begin
   result:=Compress(THuffmanAlphabetImpl(context),@data[0],length(data),1,sizeInBits);
  end;

 function CompressWords(context:THuffmanAlphabet;data:WordArray;out sizeInBits:integer):ByteArray;
  begin
   result:=Compress(THuffmanAlphabetImpl(context),@data[0],length(data),2,sizeInBits);
  end;

 function DecompressBytes(context:THuffmanAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):ByteArray;
  begin

  end;

 function DecompressWords(context:THuffmanAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):WordArray;
  begin

  end;

 function PrepareAlphabet(alphabet:UIntArray):THuffmanAlphabet;
  begin

  end;

 procedure Swap(var a,b:cardinal); inline;
  var
   c:cardinal;
  begin
   c:=a; a:=b; b:=c;
  end;

 procedure QuickSortUInt(var data:UIntArray;a,b:integer);
  var
   lo,hi,mid:integer;
   midval:cardinal;
  begin
   if b=a+1 then begin
    if data[b]<data[a] then Swap(data[a],data[b]);
    exit;
   end;
   lo:=a; hi:=b;
   mid:=(a+b) div 2;
   midval:=data[mid];
   repeat
    while data[lo]>midval do inc(lo);
    while data[hi]<midval do dec(hi);
    if lo<=hi then begin
     Swap(data[lo],data[hi]);
     inc(lo);
     dec(hi);
    end;
   until lo>hi;
   if hi>a then QuickSortUInt(data,a,hi);
   if lo<b then QuickSortUInt(data,lo,b);
  end;

 function CreateAlphabetB(data:PByte;size:integer):UIntArray;
  var
   i,key:integer;
  begin
   SetLength(result,256);
   for i:=0 to size-1 do begin
    key:=data^;
    inc(data);
    inc(result[key]);
   end;
   for i:=0 to 255 do begin
    if result[i]>$FFFF then result[i]:=$FFFF0000+i
      else result[i]:=result[i] shl 16+i;
   end;
   QuickSortUInt(result,0,255);
   for i:=255 downto 0 do
    if result[i]>=$10000 then begin
     SetLength(result,i);
     exit;
    end;
  end;

 function CreateAlphabetForBytes(data:ByteArray):UIntArray;
  begin
   result:=CreateAlphabetB(@data[0],length(data));
  end;

 function CreateAlphabetForWords(data:WordArray):UIntArray;
  begin
   //result:=CreateAlphabet(@data[0],length(data),2);
  end;

end.
