// Basic types definition

// Copyright (C) 2021 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.Types;
interface

type
  // 8-bit string type (assuming UTF-8 encoding)
  Char8 = UTF8Char;
  String8 = UTF8String;
  PString8 = ^String8;
  // 16-bit string type (can be UTF-16 or UCS-2)
  {$IFDEF UNICODE}
  Char16 = Char;
  String16 = UnicodeString;
  {$ELSE}
  char16 = WideChar;
  String16 = WideString;
  {$ENDIF}
  PString16 = ^String16;

  String32 = UCS4String;

  // String arrays
  StringArray8 = array of String8;
  StringArray16 = array of String16;
  StringArray = array of string; // depends on UNICODE mode

  {$IF Declared(TBytes)}
  ByteArray = TBytes;
  {$ELSE}
  ByteArray = array of byte;
  {$ENDIF}
  WordArray = array of word;
  IntArray = array of integer;
  UIntArray = array of cardinal;
  SingleArray = array of single;
  FloatArray = array of double;
  ShortStr = string[31];
  PointerArray = array of pointer;
  VariantArray = array of variant;
  TObjectArray = array of TObject;

  TProcedure = procedure;

implementation

end.
