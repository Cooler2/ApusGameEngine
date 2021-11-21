unit Apus.Types;
interface

type
  // 8-bit string type (assuming UTF-8 encoding)
  Char8=UTF8Char;
  String8=UTF8String;
  PString8=^String8;
  // 16-bit string type (can be UTF-16 or UCS-2)
  {$IFDEF UNICODE}
  Char16=Char;
  String16=UnicodeString;
  {$ELSE}
  char16=WideChar;
  String16=WideString;
  {$ENDIF}
  PString16=^String16;

  // String arrays
  StringArray8=array of String8;
  StringArray16=array of String16;
  StringArray=array of string; // depends on UNICODE mode

  {$IF Declared(TBytes)}
  ByteArray=TBytes;
  {$ELSE}
  ByteArray=array of byte;
  {$ENDIF}
  WordArray=array of word;
  IntArray=array of integer;
  UIntArray=array of cardinal;
  SingleArray=array of single;
  FloatArray=array of double;
  ShortStr=string[31];
  PointerArray=array of pointer;
  VariantArray=array of variant;

  TProcedure=procedure;

implementation

end.
