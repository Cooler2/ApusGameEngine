// Huffman compression
unit myHuffman;
interface
uses MyServis;

type
 TAlphabet = class(TObject);

 function CompressBytes(context:TAlphabet;data:ByteArray;out sizeInBits:integer):ByteArray;
 function CompressWords(context:TAlphabet;data:WordArray;out sizeInBits:integer):ByteArray;
 function DecompressBytes(context:TAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):ByteArray;
 function DecompressWords(context:TAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):WordArray;

 function CreateAlphabetForBytes(data:ByteArray):IntArray;
 function CreateAlphabetForWords(data:WordArray):IntArray;

 function PrepareAlphabet(alphabet:IntArray):TAlphabet;

implementation

 type
  THuffmanAlphabet=class

  end;

 function Compress(context:THuffmanAlphabet;data:PByte;length,elementSize:integer;out sizeInBits:integer):ByteArray;
  begin

  end;

 function CompressBytes(context:TAlphabet;data:ByteArray;out sizeInBits:integer):ByteArray;
  begin                                                                    
   result:=Compress(THuffmanAlphabet(context),@data[0],length(data),1,sizeInBits);
  end;

 function CompressWords(context:TAlphabet;data:WordArray;out sizeInBits:integer):ByteArray;
  begin
   result:=Compress(THuffmanAlphabet(context),@data[0],length(data),2,sizeInBits);
  end;

 function DecompressBytes(context:TAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):ByteArray;
  begin

  end;

 function DecompressWords(context:TAlphabet;packedData:ByteArray;sizeInBits:integer;estimatedSize:integer=0):WordArray;
  begin

  end;

 function PrepareAlphabet(alphabet:IntArray):TAlphabet;
  begin

  end;

 function CreateAlphabet(data:PByte;size:integer;elemSize:integer):IntArray;
  begin
  
  end; 

 function CreateAlphabetForBytes(data:ByteArray):IntArray;
  begin
   result:=CreateAlphabet(@data[0],length(data),1);
  end;

 function CreateAlphabetForWords(data:WordArray):IntArray;
  begin
   result:=CreateAlphabet(@data[0],length(data),2);
  end;

end.
