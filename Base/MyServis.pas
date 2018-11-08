{$A+,B-,C+,D+,H+,I+,J+,K-,M-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
{$IFDEF IOS}{$modeswitch objectivec1}{$ENDIF}

// ������, ���������� ����� �������� ������� ������ ����������
// Copyright (C) Ivan Polyacov, ivan@apus-software.com, cooler@tut.by
unit MyServis;
interface
 uses {$IFDEF MSWINDOWS}windows,{$ENDIF}
    SysUtils;
 const
  {$IFDEF MSWINDOWS}
  PathSeparator='\';
  {$ELSE}
  PathSeparator='/';
  {$ENDIF}
 type
  StringArr=array of string;
  WStringArr=array of WideString;
  ByteArray=array of byte;
  WordArray=array of word;
  IntArray=array of integer;
  FloatArray=array of double;
  ShortStr=string[31];

  // 8-bit strings encodings
  TTextEncoding=(teUnknown,teANSI,teWin1251,teUTF8);

  // Critical section wrapper: provides better debug info
  PCriticalSection=^TMyCriticalSection;
  TMyCriticalSection=packed record
   crs:TRTLCriticalSection;
   name:string;      // ��� ������
   caller:cardinal;  // �����, �� ������� ���� ������� ��������� �������
   owner:cardinal;   // �����, �� ������� ��������� ������� ������ ������
   thread:cardinal;  // ����, ���������� ��������� ������
   time:int64;       // ����� ����������� �������� �������
   lockCount:integer; // how many times locked (recursion)
   level:integer;     // it's not allowed to enter section with lower level from section with higher level
   prevSection:PCriticalSection;
   procedure Enter; // for compatibility
   procedure Leave; // for compatibility
  end;

  // Base exception with stack trace support
  TBaseException=class(Exception)
   private
    FAddress:cardinal;
   public
    constructor Create(const msg:string);
    property Address:cardinal read FAddress;
  end;

  // �������������� ������� �������� � ���������, ����� �����
  // �������� �������� � ������������ ��������, ������� ������� ��
  // ������ ���������� ���������� ������, ������� �������������� �������� ��
  // �������� ������ �� ���������
  // (��������: ��������� �� ������ ����������, �� ��� �� �������� ������ �������� ������)
  EWarning=class(TBaseException);

  // ������� ������ - ��������, ����� ���������� ��������� ���� ��������
  // � ����������� ������ �������� ������ ���� ������� ������� ���������� ������ � ������ ����
  // (��������: ������� �� ������ ��������� ��������� �������� � �� ������� ���������. ��������,
  // ��� ���������� ����������� �������� ������ ���� ������� ������� ��������� �� ������������� ����������)
  EError=class(TBaseException);

  // ��������� ������ - ����������� ������ ����������, ������� ������� ������ ������������
  // ���������� ���������� ���������. ��� ���������� ������� ������������ �����, �����
  // ������ �� ����� ���� ���������� ������� �������
  // (��������: ���������� ���-��, ���� ���� ����� �� �����, �.�. ��������� �����������
  // ������ ��� ������ � ���������, ������� � ������������� ������������ ������. �����
  // �������� ��������� ����� ������ ��� ����������� �������, ������� ���������� ���������� ������)
  EFatalError=class(TBaseException);

  // Spline function: f(x0)=y0, f(x1)=y1, f(x)=?
  TSplineFunc=function(x,x0,x1,y0,y1:single):single;

  // ��������� �������� ��������
  TSingleAnimation=record
   startTime,endTime:int64;
   value1,value2:single;
   spline:TSplineFunc;
  end;

  // ������������ �������� �������� (20 bytes per instance) 
  TAnimatedValue=object
   logName:string; // ���� ������ �� ������ - ��� �������� ����� ������������
   constructor Init(initValue:single=0); // Init object with given value (�� ��� ������������!)
   constructor Clone(var v:TAnimatedValue); // Init object by copying another object
   constructor Assign(initValue:single); // ������������ ������������ ������ �������� (������������ Animate � duration=0)
   procedure Free; // no need to call this if value is not animating now 
   // ������ ����� ��������: � ���������� �������� � ������� ���������� �������
   // ���� ������� �������� �������� � ���� �� �������� - ����� �� ��������
   // ���� �������� �������� ��������� � ��������� - �������� �� ��������
   procedure Animate(newValue:single;duration:cardinal;spline:TSplineFunc;delay:integer=0);
   // �� �� �����, ��� animate, �� ��������� ������ ���� finalvalue<>newValue
   procedure AnimateIf(newValue:single;duration:cardinal;spline:TSplineFunc;delay:integer=0);
   // ���������� �������� ����������� �������� � ������� ������ �������
   function Value:single;
   function IntValue:integer; inline;
   // ���������� �������� �������� � ��������� ������ (0 - ������� ������)
   function ValueAt(time:int64):single;
   function FinalValue:single; // What the value will be when animation finished?
   function IsAnimating:boolean; // Is value animating now?
   // ����������� (�������� ���������) � ������� (���������) ������ �������
   // ���� �������� ��� - �� 0 
   function Derivative:double;
   function DerivativeAt(time:int64):double;
  private
   initialValue:single;
   animations:array of TSingleAnimation;
   // ���������� ��������� �������� ����� �� ��������� ��������
   lastValue:single;
   lastTime:cardinal;
   // For multithread use
   lock:integer;
   function InternalValueAt(time:int64):single;
  end;

  TSortableObject=class
   function Compare(obj:TSortableObject):integer; virtual; // Stub
  end;
  TSortableObjects=array[0..1] of TSortableObject;
  PSortableObjects=^TSortableObjects;

  // ������ ������ � ���-������
  TLogModes=(lmSilent,   // ������� ��������� �� ��������� � ���
             lmForced,   // ��������� ������ forced-��������
             lmNormal,   // ��������� ������ forced-�������� � ��������� ��� ����� (default)
             lmVerbose); // ��������� ��� ���������
 var
  fileSysError:integer=0;  // last error
  windowHandle:cardinal=0; // handle for messages, can be 0
  logGroups:array[1..30] of boolean;
  logStartDate:TDateTime;
  logErrorCount:integer;

  performance:integer; // ������������������ �������

  // ��������� ������ ���������� ������� ���������� �� ������������
  // this slows down critical sectiond - so use carefuly
  debugCriticalSections:boolean=false;

 // ���������� e.message ������ � ������� ������
 function ExceptionMsg(const e:Exception):string;
 function GetCallStack:string;
 function GetCaller:pointer;

 // ��������� ������� ��������� (non case-sensitive) � ��������� ������
 function HasParam(name:string):boolean;
 // ���������� �������� ��������� �� ��������� ������ (������ name=value),
 // ���� �������� ����������� - ������ ������
 function GetParam(name:string):string;

 // �������, ������������ ��������� (Windows)
 // -------------------------------
 function ShowMessage(text,caption:string):integer;
 function AskYesNo(text,caption:string):boolean;
 procedure ErrorMessage(text:string);

 // �������� ��� ������ � ���-������
 // --------------------------------
 procedure UseLogFile(name:string;keepOpened:boolean=false); // Specify log name
 procedure SetLogMode(mode:TLogModes;groups:string=''); //
 procedure LogPhrase(text:string); // without CR
 procedure LogMessage(text:string;group:byte=0); // with CR
 procedure LogError(text:string); 
 procedure ForceLogMessage(text:string); // �� �� �����, �� � ����� ������� �����������
 procedure DebugMessage(text:string); // �������������� ��� ��� ForceLogMessage (��� �������� ������ �� ����)
 procedure LogCacheMode(enable:boolean;enforceCache:boolean=false;runThread:boolean=false);
 procedure FlushLog; // �������� ���������� � ���� ���������� � ���
 procedure StopLogThread; // ���������� ������ ������ ����
 procedure SystemLogMessage(text:string); // Post message to OS log

 // �������� ��������������� ������� ��� ������ � �������� ��������
 // ---------------------------------------------------------------
 function FindFile(name,path:string):string; // ����� ���� ������� � ���������� ����
 function FindDir(name,path:string):string;  // �� �� �����, �� ������ �������
 function CopyDir(sour,dest:string):boolean; // ����������� ������� �� ���� ����������
 function MoveDir(sour,dest:string):boolean; // ��������� ������� �� ���� ����������
 function DeleteDir(path:string):boolean;    // ������� ������� �� ���� ����������
 procedure DumpDir(path:string);             // Log directory content (file names)

 // �������� �������
 // -------------------------------
 function SafeFileName(fname:string):string; // Replace all unsafe characters with '_'
 function FileName(const fname:string):string; // ����������� ������������ ���� � ���������� case-������
 procedure AddFileNameRule(const rule:string); // �������� case-������� (��������, ������� "MyFile" ���������� ������ myFiLe ��� myfile � "MyFile")
 function GetFileSize(fname:string):int64;
 function WaitForFile(fname:string;delayLimit:integer;exists:boolean=true):boolean; // ��������� (�� ������ delayLimit) �� ��������� (��� ��������) �����, ���������� false ���� �� ���������
 function MyFileExists(fname:string):boolean; // Cross-platform version
 function LoadFile(fname:string):string; // Load file content into string
 function LoadFile2(fname:string):ByteArray; // Load file content into byte array
 procedure SaveFile(fname:string;buf:pointer;size:integer); overload; // rewrite file with given data
 procedure SaveFile(fname:string;buf:ByteArray); overload; // rewrite file with given data
 procedure ReadFile(fname:string;buf:pointer;posit,size:integer); // Read data block from file
 procedure WriteFile(fname:string;buf:pointer;posit,size:integer); // Write data block to file
 {$IFDEF IOS}
{ // Return path to a file in a bundle
 function GetResourcePath(fname:string):string;
 // Load the specified resource file from main bundle, returns pointer to allocated buffer or nil
 function LoadResourceFile(fname:string):pointer;}
 {$ENDIF}

 // ������������ ��������� ������������������ �������� ���� (� ��)
 // -------------------------------------------------------
 // ���������� ��� ����� ��������� � ������
 // StartMeasure(n) ... EndMeasure(n);
 // ��� ����� ����������� ��� ���� ���, ��� � ����� ���
 // GetTaskPerformance - ������� ����� ���������� ������� (� ��.)
 procedure StartMeasure(n:integer);
 function EndMeasure(n:integer):double;
 // ����������, �� ��������� �� ����������� �� ���� ������, � ������ ������������
 function EndMeasure2(n:integer):double;
 function  GetTaskPerformance(n:integer):double;
 procedure RunTimer(n:integer);
 function GetTimer(n:integer):double;

 function MyGetTime:double; // ����� � �������� �� ������ ���������
 function MyGetTime2:cardinal; // ����� � ������������� �� ������ ���������
 function GetCurTime:cardinal;  // just an alias for backward compatibility
 function MyTickCount:int64; // ������ GetTickCount, �� ��� ������������ (������ �� ���������� GetTickCount ��-�� ������������� ��������)

 // ������� ��� ������ � ���������
 // ------------------------------
 // Shift array/data pointed by ptr by shiftValue bytes (positive - right, negative - left)
 procedure ShiftArray(const arr;sizeInBytes,shiftValue:integer);
 // ����� � ������� arr �������� item
// procedure Find(const arr;const item;itemSize,itemsCount:integer);


 // ��������� ��� ������������ ������ ������ (Delphi-only)
 {$IFDEF DELPHI}
 procedure BeginMemoryCheck(id:string);
 procedure EndMemoryCheck;

 procedure StartMemoryLeaksTracking;
 procedure StopMemoryLeaksTracking;
 {$ENDIF}

 // ���������� ������ � ��������� ������������� ������
 function GetMemoryState:string;

 // ���������� ����� ���������� ������
 function GetMemoryAllocated:int64;

 // ��������� ������ � ������������� �� ���������
// function MyGetMem(size:integer):pointer;
// procedure MyFreeMem(p:pointer);

 // ������� ��� ������ � ���������
 // ------------------------------
 // Add (insert) string into array, returns its index
 function AddString(var sa:StringArr;const st:string;index:integer=-1):integer; overload;
 function AddString(var sa:WStringArr;const st:WideString;index:integer=-1):integer; overload;
 // Delete string from array
 procedure RemoveString(var sa:StringArr;index:integer); overload;
 procedure RemoveString(var sa:WStringArr;index:integer); overload;
 // ���� ������ � �������, ���������� � ������ ���� -1
 function FindString(var sa:StringArr;st:string;ignoreCase:boolean=false):integer;
 // ���� ����� � �������, ���������� ��� ������ ���� -1
 function FindInteger(var a:IntArray;v:integer):integer;
 // ��������� (���������) ����� � ������ �����
 function AddInteger(var a:IntArray;v:integer;index:integer=-1):integer;
 // ������� ������� �� �������
 procedure RemoveInteger(var a:IntArray;index:integer;keepOrder:boolean=false);
 // ��������� (���������) ����� � ������ �����
 function AddFloat(var a:FloatArray;v:double;index:integer=-1):integer;
 // ������� ������� �� �������
 procedure RemoveFloat(var a:FloatArray;index:integer;keepOrder:boolean=false);

 // ���������� ������ ����� ������� (����� �������)
 function ArrayToStr(a:array of integer;divider:char=','):string;
 // ��������� ������ �� ������ ����� (����� �������)
 function StrToArray(st:string;divider:char=','):IntArray;

 // ������� ��� ������ �� ��������
 // ------------------------------
 // �������� �� ������ ��� ���������, ����������� ������ ������������
 // ������� ��������� ������� ���������� �������� ������ ��������� ������� � ������.
 function Split(divider,st:string;quotes:char):StringArr; overload;
 // ��������� ������ �� ��������� ��� �����-���� ������
 function Split(divider,st:string):StringArr; overload;
 function SplitW(divider,st:WideString):WStringArr;
 // Search for a substring from specified point
 function PosFrom(substr,str:string;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
 function PosFrom(substr,str:WideString;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
 // Extract substring "prefix|xxx|suffix"
 function ExtractStr(str,prefix,suffix:string;out prefIndex:integer):string;

 // ��������� ��������� � ���� ������ � �������������� ����������� divider
 // ���� ����������� ������������ � ����������, �� ��� ������� � ������� �
 // ����������� ��������������� �����������
 function Combine(strings:stringarr;divider:string;quotes:char):string;

 // ��������� ��������� � ���� ������ ��������� ������-����������� divider
 // ���� ����������� ����������� � �������, �� �� �����������
 function Join(strings:stringarr;divider:string):string; overload;

 // ��������� �������� (��������������� �� �������� ����� � ��������� ���) ��������� ������������
 function Join(items:array of const;divider:string):string; overload;

 // ���������, ���������� �� ������ st � ���������
 function HasPrefix(st,prefix:string):boolean;

 // ���������� ������ �� ������� � ��������� ������������ ������� (����� - ������ ������)
 function SafeStrItem(sa:StringArr;idx:integer):string;

 // ��������� ������ � ������� (��������� ����������), ����
 // force = false, �� �� ��������� ���� � ������ ��� ���������� ��������
 function QuoteStr(const st:string;force:boolean=false;quotes:char='"'):string;

 // ������������� ������, ����������� � �������
 function UnQuoteStr(const st:string;quotes:char='"'):string;

 // �������� \n \t � �.�. �� ��������������� ������� (� ����� \\ �� \)
 function Unescape(st:string):string;

 // ������ ���������� ������� � ������ � � �����
 function Chop(st:string):string;

 // ���������� ��������� ������ ������ (#0 ���� ������ ������)
 function LastChar(st:string):char;

 // Safe string indexing
 function CharAt(st:string;index:integer):char;
 function WCharAt(st:WideString;index:integer):WideChar;

 // �������� ��������� ������� � ������ ����� �������, ����� � ����� ���� �������� � HTML
 function HTMLString(st:string):string;

 // ������������ URL �������� ����������� HTTP
 function UrlEncode(st:string):string;
 // ������������� URL �������� ����������� HTTP
 function UrlDecode(st:string):string;
 // �������� url �� UTF8 � ���������� ASCII ��� !!! WARNING! ����� �������� �-��� - �� ����� ��� ������ �����! 
 function URLEncodeUTF8(st:string):string;

 // ������������ �������� ������ � ������ (this is NOT Base64!)
 function EncodeB64(data:pointer;size:integer):string;
 // ������������� ������ �� ������
 procedure DecodeB64(st:string;buf:pointer;var size:integer);
 // ��������� ������ � ����������� �������� (�������� �����������), �������� ����������!
 function PrintableStr(st:string):string;
 // ������������ ������ � ���� HEX
 function EncodeHex(st:string):string; overload;
 function EncodeHex(data:pointer;size:integer):string; overload;
 function DecodeHex(st:string):string;

 // ���������� ����������/������������ (simple XOR)
 procedure SimpleEncrypt(var data;size,code:integer);
 procedure SimpleEncrypt2(var data;size,code:integer);

 // ������� ������ (simplified LZ method, works good only for texts or similar strings)
 function SimpleCompress(data:string):string;
 function SimpleDecompress(data:string):string;

 // ������� ������ ������� RLE
 function PackRLE(buf:pointer;size:integer;addHeader:boolean=true):ByteArray;
 function UnpackRLE(buf:pointer;size:integer):ByteArray;
 function CheckRLEHeader(buf:pointer;size:integer):integer; // -1 - no header

 // ����������� ���� �� ������ � ������� DD.MM.YYYY HH:MM:SS (������ ������� ���� �������� � ���������)
 function GetDateFromStr(st:string;default:TDateTime=0):TDateTime;
 // ���������� ������ � �������� ����� ��������� �������� � ������� �������� (������� ������� ������ � ���������� �������)
 // ���� ��������� ������ ��� �� ��������, �� ������ �������� ����� +
 function HowLong(time:TDateTime):string;

 // UTF8 routines
 function IsUTF8(st:string):boolean; inline; // Check if string starts with BOM
 function EncodeUTF8(st:widestring;addBOM:boolean=false):string;
 function DecodeUTF8(st:string):widestring;
 function DecodeUTF8A(sa:StringArr):WStringArr;
 function UTF8toWin1251(st:string):string;
 function Win1251toUTF8(st:string):string;
 function UpperCaseUtf8(st:string):string;
 function LowerCaseUtf8(st:string):string;
 // UTF-16 routines (Unicode)
 function UnicodeTo(st:WideString;encoding:TTextEncoding):string;
 function UnicodeFrom(st:string;encoding:TTextEncoding):WideString;

// function CopyUTF8(S:string; Index:Integer; Count:Integer):string; // analog of Copy which works with UTF8

 // ������� ��� ���������� �������� "�������" � ���������� �������
 // -----------------------------------------------------------------
 // ������� "����������" ��������, �.�. �������� b ������ ����������� ��������� [min..max]
 function Sat(b,min,max:integer):integer;
 function SatD(b,min,max:double):double;

 // ��������� ������� �������, ������������ �� ������� [0..256] ������� ��� (���������)
 // � ����� arg � ����������� �������� a, b � c (a � c - �� ������ �������, b - � ����������)
 function Pike(x,arg,a,b,c:integer):integer;
 function PikeD(x,arg,a,b,c:double):double; // [0..1] range

 // ������������ ������ �� ������� [0..1] ����������� �������� a,b,c � ������ 0, 0.5, 1 � ������������ ���������� �����
 function SatSpline(x:single;a,b,c:integer):byte;
 // ���������� ������ �� ������� [0..1] ����������� �������� a,b,c,d � ������ 0, 0.33, 0.66, 1 � ������������ ���������� �����
 function SatSpline3(x:single;a,b,c,d:integer):byte;

 // ��������� ������ (�������� - �� 0 �� 1, v0,v1 - �������� �� ������,
 //   k0,k1 - ����������� �� ������ (0 - �����������), v - ��� ������� (0..1, 0.5 - �������)
 function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;
 // ��������� �������� �������
 // �������� �������
 function Spline0(x,x0,x1,y0,y1:single):single;
 // ���������, ������������� ��������, ����������
 function Spline1(x,x0,x1,y0,y1:single):single;  // 25% - 50% - 25%
 function Spline1a(x,x0,x1,y0,y1:single):single; // 10% - 80% - 10%
 // �������� � ���������� ����������� (��������)
 function Spline2(x,x0,x1,y0,y1:single):single;
 function Spline2rev(x,x0,x1,y0,y1:single):single; // �� ��, �� � ���������� ����������
 // �������� � ���������� � ��������� �������� �� 10% �� ��������� ������
 function Spline3(x,x0,x1,y0,y1:single):single;
 // �������� � "��������" �� 15%
 function Spline4(x,x0,x1,y0,y1:single):single;
 // �������� � "��������" �� 30%
 function Spline4a(x,x0,x1,y0,y1:single):single;

 // �������� ��������� ������� ������, �� ������� ������� �����
 function GetPow2(v:integer):integer;
 // Get power of 2
 function Pow2(e:integer):int64;

 // Minimum / Maximum
 function Min2(a,b:integer):integer; inline;
 function Max2(a,b:integer):integer; inline;
 function Min2d(a,b:double):double; inline;
 function Max2d(a,b:double):double; inline;
 function Min3d(a,b,c:double):double; inline;
 function Max3d(a,b,c:double):double; inline;

 // Exchange 2 items
 procedure Swap(var a,b:integer); overload; inline;
 procedure Swap(var a,b:byte); overload; inline;
 procedure Swap(var a,b:single); overload; inline;
 procedure Swap(var a,b:string); overload; inline;
 procedure Swap(var a,b:WideString); overload; inline;
 procedure Swap(var a,b;size:integer); overload; inline;

 // ��������������� ����� �� arg � ��������� 0..module-1
 function PseudoRand(arg,module:cardinal):cardinal;
 // ���������� �������� ����� ����� ������� � v ���, ��� ��� ����������� ����� v
 function RandomInt(v:single):integer;
 // ���������� ��������� ������ �������� ����� �� ���������-�������� ��������
 function RandomStr(l:integer):string;

 // ������� ��� �������� �������� ������ � ��������� ����
 //------------------------------------------------------
 function BinToStr(var buf;size:byte):string;
 function StrToBin(var buf;size:byte;st:string):integer;

 // �������������� ���������
 //---------------
 // �������������� Windows-1251 <=> DOS 866
 function ConvertToWindows(ch:char):char;
 function ConvertFromWindows(ch:char):char;
 // �������������� Windows-1251 <=> Unicode-16 (UTF-16)
 function ConvertWindowsToUnicode(ch:char):widechar;
 function ConvertUnicodeToWindows(ch:widechar):char;

 // �������������� ����� ������
 // ---------------------------
 function HexToInt(st:string):int64;  // ���������� ����������������� �����
 function SizeToStr(size:int64):string; // ������ � �������� ������� �������, ���� 15.3M
 function FormatTime(time:int64):string; // ������ � ��������� ���������� (time - � ms)
 function FormatInt(int:int64):string; // ������ � ������ (������ ��������� ������ ����)
 function FormatMoney(v:double;digits:integer=2):string; // ������ � ������ ����� (digits ������ ����� �������)
 function IpToStr(ip:cardinal):string; // IP-����� � ������ (������� ���� - ������)
 function PtrToStr(p:pointer):string; // Pointer to string
 function StrToIp(ip:string):cardinal; // ������ � IP-����� (������� ���� - ������)
 function VarToStr(v:TVarRec):string; // Variant -> String
 function ParseInt(st:string):int64; inline; // wrong characters ignored
 function ParseFloat(st:string):double; inline; // always use '.' as separator - replacement for SysUtils version

 function ListIntegers(a:array of integer;separator:char=','):string; overload; // array of integer => 'a[1],a[2],...,a[n]'
 function ListIntegers(a:system.PInteger;count:integer;separator:char=','):string; overload;


 // ��������� ��������� ��� (����)
 function RandomName(minlen,maxlen:byte):string;

 // ����������
 procedure SortObjects(var obj:array of TSortableObject);
// procedure SortObjects(var obj:array of TObject;comparator:TObjComparator); overload;
 procedure SortStrings(var sa:StringArr); overload;
 procedure SortStrings(var sa:WStringArr); overload;
// function SelectUnique(const sa:WStringArr):WStringArr;

 // Data Dump
 // ---------
 // ������ � ����������������� ������ ������
 function HexDump(buf:pointer;size:integer):string;
 // ������ � ���������� ������ ������
 function DecDump(buf:pointer;size:integer):string;

 procedure TestSystemPerformance;

 // ���������� ����������� �����
 function CalcCheckSum(adr:pointer;size:integer):cardinal;
 function CheckSum64(adr:pointer;size:integer):int64; pascal;
 procedure FillRandom(var buf;size:integer);
 function StrHash(const st:string):cardinal; 

 // ������� ����� � ���� (GMT)
 function NowGMT:TDateTime;
 function TimeStamp:string;

 // ������������� � ���������������
 // --------------------------------
 // level - ������������ � ���������� ������ ��� �������� ���������� ������ � ����� ������� ������ (����� ������������� ���������� ����������)
 // ����������� ������� � ������ � ������� ������� ������ ��� � ������ � ������� �������, �� �� ��������.
 // �.�. ��� ���� ������� ����, ��� ���� ������ ���� �������� level � ������, ������� ���� ��� ���������  
 procedure InitCritSect(var cr:TMyCriticalSection;name:string;level:integer=100); // ������� � �������� ����������
 procedure DeleteCritSect(var cr:TMyCriticalSection);
 procedure EnterCriticalSection(var cr:TMyCriticalSection;caller:pointer=nil);
 procedure LeaveCriticalSection(var cr:TMyCriticalSection);
// procedure SafeEnterCriticalSection(var cr:TMyCriticalSection); // ��������� ����� � ����������
 procedure DumpCritSects; // ������� � ��� ��������� ���� ����������
 procedure RegisterThread(name:string); // ���������������� �����
 procedure UnregisterThread; // ������� ����� (����� �������� ����� ����������� ������)
// procedure DumpThreads; // ������
 procedure PingThread; // �������� � "���������" ������
 function GetThreadName(threadID:cardinal=0):string; // ������� ��� (0=��������) ������

 procedure CheckCritSections; // ��������� ����������� ������ �� �������

 // Disable Data Execution Prevention (Windows)
 procedure DisableDEP;

implementation
 uses Classes,math,CrossPlatform
    {$IFDEF MSWINDOWS},mmsystem{$ENDIF}
    {$IFDEF IOS},iphoneAll{$ENDIF}
    {$IFDEF ANDROID},dateutils,Android{$ENDIF};
 const
  hexchar='0123456789ABCDEF';
 type
  TMemLeak=record
   value:cardinal;
   name:string;
  end;
  {$IFDEF MSWINDOWS}
  TThreadID=cardinal;
  {$ENDIF}
  TThreadInfo=record
   ID:TThreadID;
   name:string;
   counter:integer; // ������� ��� ���������
   first:integer;   // ����� ������� �������
   last:integer;    // ����� ���������� �������
   lastreport:integer; // ����� ���������� ��������� � ��������
   at:integer;       // ���������� ��������� ����� ����� �����������
   handle:cardinal;
   lastCS:PCriticalSection; // ��������� ����������, ����������� � ���� ������
  end;

  TLogThread=class(TThread)
   procedure Execute; override;
  end;

 var
  LogFileName:string='';
  LogMode:TLogModes=lmNormal;
  LogStart,logTime:int64;
  logThread:TLogThread;
  cachebuf:string;
  //cachesize:integer;
  cacheenabled,forceCacheUsage:boolean;  // forceCacheUsage - ������ � ��� ����

  memleaks:array[1..40] of TMemLeak;
  memleakcnt:integer=0;
  crSection:TRTLCriticalSection; // ������������ ��� ������� � ���������� ����������
  startTime,startTimeMS:int64;

  crSections:array[1..100] of PCriticalSection;
  crSectCount:integer=0;

  threads:array[0..100] of TThreadInfo;
//  buffer2:array[0..16384] of cardinal;
  trCount:integer; // ������ ����� ���� �� ������ � ������ �������!!!

  memcheck:array[0..127] of int64;
  lastTickCount:int64;

//  buffer:array[0..16384] of cardinal;

  // Character case replacements
  fileNameRules:StringArr;

  logAlwaysOpened:boolean;
  logFile:TextFile;

  performanceMeasures:array[1..16] of double;
  values:array[1..16] of int64;
  measures:array[1..16] of integer;
  perfKoef:double; // ������������ ������ ���� � ��
  timers:array[1..16] of int64;

 procedure SpinLock(var lock:integer); inline;
  begin
   // LOCK CMPXCHG is very slow (~20-50 cycles) so no need for additional spin rounds for quick operations
   while InterlockedCompareExchange(lock,1,0)<>0 do sleep(0);
  end;

 {$IFDEF IOS}
{ function GetResourcePath(fname:string):string;
  var
   name:string[40];
   ext:string[10];
  begin
   ExtractFileName(
   NSBundle.mainBundle
  end;

 function LoadResourceFile(fname:string):pointer;
  var
   bundle:NSBundle;
  begin
   bundle:=NSBundle.mainBundle;
   if bundle=nil then raise EError.Create('Can''t open main bundle');

   result:=nil;
  end;}
 {$ENDIF}

 function TSortableObject.Compare(obj:TSortableObject):integer;
  begin
   result:=0;
  end;

 // TAnimatedValue - numeric interpolation class
 constructor TAnimatedValue.Init(initValue:single=0);
  begin
   SetLength(animations,0);
   initialValue:=initValue;
   logName:='';
   lastTime:=0; lastValue:=0;
  end;

 constructor TAnimatedValue.Assign(initValue:single);
  begin
   SpinLock(lock);
   try
   SetLength(animations,0);
   initialValue:=initValue;
   if logName<>'' then LogMessage(logName+' := '+floatToStrF(initialValue,ffGeneral,5,0));
   lastTime:=0; lastValue:=0;
   finally lock:=0;
   end;
  end;

 constructor TAnimatedValue.Clone(var v: TAnimatedValue);
  var
   i:integer;
  begin
   SpinLock(lock);
   try
   initialValue:=v.initialValue;
   SetLength(animations,length(v.animations));
   for i:=0 to high(animations) do
    animations[i]:=v.animations[i];
   logName:=v.logName;
   lastTime:=0; lastValue:=0;
   finally lock:=0;
   end;
  end;

 procedure TAnimatedValue.Free;
  begin
   SpinLock(lock);
   try
   SetLength(animations,0);
   finally lock:=0;
   end;
  end;

 function TAnimatedValue.Derivative:double;
  begin
   result:=DerivativeAt(MyTickCount);
  end;

 function TAnimatedValue.DerivativeAt(time:int64):double;
  begin
   SpinLock(lock);
   try
   result:=(InternalValueAt(time+1)-InternalValueAt(time))*1000;
   finally lock:=0;
   end;
  end;

 function TAnimatedValue.FinalValue:single;
  begin
   SpinLock(lock);
   try
   if length(animations)>0 then
    result:=animations[length(animations)-1].value2
   else
    result:=initialValue;
   finally lock:=0;
   end;
  end;

function TAnimatedValue.ValueAt(time:int64):single;
 begin
   SpinLock(lock);
   try
    result:=InternalValueAt(time);
   finally lock:=0;
   end;
 end;

function TAnimatedValue.InternalValueAt(time:int64):single;
  var
   i:integer;
   v,r,k:double;
   t:int64;
  begin
   result:=initialValue;
   i:=length(animations)-1;
   if i<0 then exit;
   if time=0 then t:=MyTickCount
    else t:=time;

   if (t>=animations[i].endTime) then
    if time=0 then begin // ��� �������� ��� � �������
     initialValue:=animations[i].value2;
     if logName<>'' then LogMessage(IntToStr(MyTickCount mod 1000)+'>'+IntToStr(animations[i].endTime mod 1000)+
      ' '+logName+' finish at '+floatToStrF(initialValue,ffGeneral,5,0));
     SetLength(animations,0);
     result:=initialValue;
     exit;
    end else begin
     result:=animations[i].value2; exit;
    end;
   if cardinal(t)=lastTime then begin
    result:=lastValue; exit;
   end;
   // ���������� �������� �� ������� ��������
   for i:=0 to length(animations)-1 do
    with animations[i] do begin
     if t>=endTime then v:=value2
      else if t<=startTime then v:=value1
       else begin
        v:=Spline(t-startTime,0,endTime-StartTime,value1,value2);
//        if LogName<>'' then LogMessage(' '+logName+' '+Format('%f %d %d %f',[t,startTime,endTime,v]));
       end;
     // Overlap?
     if (i>0) and (animations[i-1].endTime>startTime) and (t<animations[i-1].endTime) then begin
      r:=animations[i-1].endTime;
      if endTime<r then r:=endTime;
      if (r-animations[i-1].startTime)<>0 then // ������ ���?
       k:=(startTime-animations[i-1].startTime)/(r-animations[i-1].startTime)
      else k:=0;
      if k>1 then k:=1;
      if r-StartTime=0 then k:=1 // zero overlap size (never occurs)
//       else k:=k*(r-t)/(r-startTime);
       else k:=Spline1((r-t)/(r-startTime),0,1,0,k);
      if k>1 then k:=1;
      result:=result*k+v*(1-k);
//      result:=v;
     end else
      if t>=startTime then result:=v;
    end;
   lastTime:=cardinal(t);
   lastValue:=result;
   if logName<>'' then LogMessage(IntToStr(t mod 1000)+' '+logName+' '+Format('%f',[result]));
  end;

function TAnimatedValue.IntValue: integer;
 begin
  result:=round(ValueAt(0));
 end;

function TAnimatedValue.Value:single;
 begin
  result:=ValueAt(0);
 end;

function TAnimatedValue.IsAnimating: boolean;
 begin
  SpinLock(lock);
  try
  if length(animations)>0 then begin
   result:=MyTickCount<animations[length(animations)-1].endTime;
  end else
   result:=false;
  finally lock:=0;
  end;
 end;

procedure TAnimatedValue.AnimateIf(newValue:single;duration:cardinal;spline:TSplineFunc;delay:integer=0);
 begin
  if finalValue<>newValue then
   Animate(newValue,duration,spline,delay);
 end;


procedure TAnimatedValue.Animate(newValue:Single; duration:cardinal; spline:TSplineFunc; delay:integer=0);
 var
  n:integer;
  v:single;
  t:int64;
 begin
  if PtrUInt(@Self)<4096 then raise EError.Create('Animating invalid object');
  SpinLock(lock);
  try
  try
  if (duration=0) and (delay=0) then begin
   if logName<>'' then LogMessage(logName+' := '+floattostrF(newvalue,ffGeneral,5,0));
   initialValue:=newValue;
   SetLength(animations,0);
   exit;
  end;
  lastTime:=0; lastValue:=0;
  n:=length(animations);
  if (n=0) and (initialValue=newValue) then exit; // no change
  if (n>0) and (animations[n-1].value2=newValue) then exit; // animation to the same value
  t:=MyTickCount+delay;
  if n=0 then v:=initialValue else
  if delay=0 then v:=InternalValueAt(0) else
   v:=InternalValueAt(t); // ������ ������ - �������� ����� ������ ������ ��������, �.�. �� � �������� ��������

  SetLength(animations,n+1);
  animations[n].startTime:=t;
  animations[n].endTime:=t+duration;
  animations[n].value1:=v;
  animations[n].value2:=newValue;
  animations[n].spline:=spline;
  if logName<>'' then LogMessage(logname+'['+IntToStr(n)+'] '+floattostrF(v,ffGeneral,5,0)+
   ' --> '+floattostrF(newvalue,ffGeneral,5,0)+' '+inttostr(delay)+'+'+inttostr(duration)+
    Format(' %d %d',[animations[n].startTime mod 1000,animations[n].endTime mod 1000]));
  except
   on e:Exception do raise EError.Create('Animate '+inttohex(PtrUInt(@self),8)+' error: '+e.message);
  end;
  finally lock:=0;
  end;
 end;

 procedure MyEnterCriticalSection(var cr:TRTLCriticalSection); inline;
  begin
   {$IFDEF MSWINDOWS}
    windows.EnterCriticalSection(cr);
   {$ELSE}
    system.EnterCriticalSection(cr);
   {$ENDIF}
  end;
 procedure MyLeaveCriticalSection(var cr:TRTLCriticalSection); inline;
  begin
   {$IFDEF MSWINDOWS}
    windows.LeaveCriticalSection(cr);
   {$ELSE}
    system.LeaveCriticalSection(cr);
   {$ENDIF}
  end;

 function TimeStamp;
  var
   t:integer;
  begin
   t:=MyTickCount;
   result:=inttostr(t div 60000)+':'+inttostr((t div 1000) mod 60)+'.'+inttostr(t mod 1000);
  end;

 function min2(a,b:integer):integer; inline;
  begin
   if a>b then result:=b else result:=a;
  end;
 function max2(a,b:integer):integer; inline;
  begin
   if a>b then result:=a else result:=b;
  end;
 function min2d(a,b:double):double; inline;
  begin
   if a>b then result:=b else result:=a;
  end;
 function max2d(a,b:double):double; inline;
  begin
   if a>b then result:=a else result:=b;
  end;

 function Min3d(a,b,c:double):double; inline;
  begin
   if a>b then result:=b else result:=a;
   if c<result then result:=c;
  end;
 function Max3d(a,b,c:double):double; inline;
  begin
   if a>b then result:=a else result:=b;
   if c>result then result:=c;
  end;

 procedure Swap(var a,b:integer); overload; inline;
  var
   c:integer;
  begin
   c:=a; a:=b; b:=c;
  end;
 procedure Swap(var a,b:byte); overload; inline;
  var
   c:byte;
  begin
   c:=a; a:=b; b:=c;
  end;
 procedure Swap(var a,b:string); overload; inline;
  var
   c:string;
  begin
   c:=a; a:=b; b:=c;
  end;
 procedure Swap(var a,b:WideString); overload; inline;
  var
   c:WideString;
  begin
   c:=a; a:=b; b:=c;
  end;
 procedure Swap(var a,b:single); overload; inline;
  var
   c:single;
  begin
   c:=a; a:=b; b:=c;
  end;
 procedure Swap(var a,b;size:integer); overload; inline;
  var
   buf:array[0..255] of byte;
  begin
   ASSERT(size<256);
   move(a,buf,size);
   move(b,a,size);
   move(buf,b,size);
  end;


 function PseudoRand(arg,module:cardinal):cardinal;
  const
   bitval:array[0..17] of cardinal=
    (542467762,529177086,805032378,
     697033747,193457524,073877172,
     963156594,680657113,599785059,
     706252805,529181168,880250764,
     581375626,409408405,321394076,
     144327531,223151488,239519949);
  var
   i:integer;
  begin
   result:=0;
   for i:=0 to 17 do begin
    if arg and 1>0 then result:=result+bitval[i];
    arg:=arg shr 1;
    if arg=0 then break;
   end;
   result:=result mod module;
  end;

 function RandomInt(v:single):integer;
  var
   v_:integer;
  begin
   v_:=trunc(v);
   v:=frac(v);
   if random<v then result:=v_+1
    else result:=v_;
  end;

 function RandomStr(l:integer):string;
  const
   c:string[62]='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  var
   i:integer;
  begin
   SetLength(result,l);
   for i:=1 to l do
    result[i]:=c[1+random(62)];
  end;

 function RealDump(buf:pointer;size:integer;hex:boolean):string;
  var
   i:integer;
   pb:PByte;
   ascii:string[18];
  begin
   result:=''; pb:=buf; ascii:='';
   for i:=1 to size do begin
    if hex then
     result:=result+intToHex(pb^,2)+' '
    else
     result:=result+
      chr($30+pb^ div 100)+
      chr($30+(pb^ mod 100) div 10)+
      chr($30+pb^ mod 10)+' ';
    if pb^>=32 then ascii:=ascii+chr(pb^)
     else ascii:=ascii+'.';
    if i mod 16=8 then begin
     result:=result+' ';
     ascii:=ascii+' ';
    end;
    if i mod 16=0 then begin
     result:=result+'   '+ascii+#13#10;
     ascii:='';
    end;
    inc(pb);
   end;
  end;


 function HexDump(buf:pointer;size:integer):string;
  begin
   result:=RealDump(buf,size,true);
  end;

 function DecDump(buf:pointer;size:integer):string;
  begin
   result:=RealDump(buf,size,false);
  end;

 function GetPow2(v:integer):integer;
  begin
   if v<256 then result:=1
    else result:=256;
   while result<v do result:=result*2;
  end;

 function pow2(e:integer):int64;
  begin
   result:=0;
   if (e>=0) and (e<64) then
    result:=1 shl e;
  end;

 function CalcCheckSum(adr:pointer;size:integer):cardinal;
  var
   pb:PByte;
   i:integer;
  begin
   result:=0;
   pb:=adr;
   for i:=1 to size do begin
    inc(result,pb^*(i and 255));
    inc(pb);
   end;
  end;

 function CheckSum64(adr:pointer;size:integer):int64;
  var
   pb:PByte;
   i:integer;
   d:int64;
  begin
   result:=size;
   pb:=adr;
   for i:=1 to size do begin
    d:=pb^;
    result:=result xor (d shl (i*i mod 56)) xor (d shl (i*11 mod 56));
    inc(pb);
   end;
  end;

 function StrHash(const st:string):cardinal; 
  var
   i:integer;
  begin
   result:=0;
   for i:=1 to length(st) do
    result:=result*$20844 xor byte(st[i]);
  end;

 procedure FillRandom(var buf;size:integer);
  var
   pb:^byte;
   i,r:integer;
  begin
   pb:=@buf;
   r:=size*size mod 91;
   for i:=1 to size do begin
    pb^:=r and $FF;
    r:=r*13+9;
    inc(pb);
   end;
  end;

 function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;
  var
   a,b:double;
  begin
   if x<0 then x:=0;
   if x>1 then x:=1;
   x:=(2-4*v)*x*x+(4*v-1)*x;
   a:=k0-(v1-v0);
   b:=-k1+(v1-v0);
   result:=(1-x)*v0+x*v1+x*(1-x)*(a*(1-x)+b*x);
  end;

(*
 function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;
  var
   a,b:double;
  begin
   if x<0 then x:=0;
   if x>1 then x:=1;
   x:=(2-4*v)*x*x+(4*v-1)*x;
{   a:=k1-k0-2*v1+2*v0;
   b:=v1-v0-k0-a;
   result:=v0+k0*x+b*x*x+a*x*x*x;}
   {$IFDEF CPUARM}
   // Internal FPC bug requires to rewrite code
   a:=k0-(v1-v0);
   b:=(v1-v0);
   b:=b-k1;
//   result:=(1-x)*v0+x*v1+x*(1-x)*(a*(1-x)+b*x);
   {$ELSE}
   a:=k0-(v1-v0);
   b:=-k1+(v1-v0);
   result:=(1-x)*v0+x*v1+x*(1-x)*(a*(1-x)+b*x);
   {$ENDIF}
  end;        *)

 function Spline0(x,x0,x1,y0,y1:single):single;
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   result:=y0+(y1-y0)*x;
  end;
 function Spline1(x,x0,x1,y0,y1:single):single; // 25-50-25 ���������, ��������, ����������
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   if x<0.25 then result:=2.666666*sqr(x) else
    if x>0.75 then result:=1-2.666666*sqr(1-x) else
     result:=1.333333*x-0.16666666;
   result:=y0+(y1-y0)*result;
  end;
 function Spline1a(x,x0,x1,y0,y1:single):single; // 10-80-10 ���������, ��������, ����������
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   if x<0.1 then result:=5.555556*sqr(x) else
    if x>0.9 then result:=1-5.555556*sqr(1-x) else
     result:=1.111111*x-0.0555556;
   result:=y0+(y1-y0)*result;
  end;
 function Spline2(x,x0,x1,y0,y1:single):single; // ����������� ����������
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   result:=1-sqr(1-x);
   result:=y0+(y1-y0)*result;
  end;
 function Spline2rev(x,x0,x1,y0,y1:single):single; // ����������� ���������
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   result:=x*x;
   result:=y0+(y1-y0)*result;
  end;
 function Spline3(x,x0,x1,y0,y1:single):single;
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   if x<=0.8 then result:=x*0.5+sqr(x)/1.066667
    else result:=0.9+sqr(x-0.9)*10;
   result:=y0+(y1-y0)*result;
  end;
 function Spline4(x,x0,x1,y0,y1:single):single;
  var
   yMax:single;
  begin
   x:=(x-x0)/(x1-x0);
   yMax:=y1*1.15-y0*0.15;
   if x<0.7 then result:=Spline2(x,0,0.7,y0,yMax)
    else result:=Spline1(x,0.7,1,yMax,y1);
  end;
 function Spline4a(x,x0,x1,y0,y1:single):single;
  var
   yMax:single;
  begin
   x:=(x-x0)/(x1-x0);
   yMax:=y1*1.3-y0*0.3;
   if x<0.7 then result:=Spline2(x,0,0.7,y0,yMax)
    else result:=Spline1(x,0.7,1,yMax,y1);
  end;

 function HexToInt(st:string):int64;
  var
   i:integer;
   v:int64;
  begin
   result:=0;
   v:=1;
   for i:=length(st) downto 1 do begin
    if st[i]='-' then begin
     result:=-result;
     break;
    end;
    if not (st[i] in ['0'..'9','A'..'F','a'..'f']) then continue;
    if st[i] in ['0'..'9'] then result:=result+(ord(st[i])-ord('0'))*v else
    if st[i] in ['A'..'F'] then result:=result+(ord(st[i])-ord('A')+10)*v else
    if st[i] in ['a'..'f'] then result:=result+(ord(st[i])-ord('a')+10)*v;
    v:=v*16;
   end;
  end;

 function SizeToStr;
  var
   v:single;
  begin
   if size<1000 then begin result:=inttostr(size)+'b'; exit end;
   v:=size/1024;
   if v<10 then begin result:=FloatToStrF(v,ffFixed,4,2)+'K'; exit end;
   if v<100 then begin result:=FloatToStrF(v,ffFixed,4,1)+'K'; exit end;
   if v<1000 then begin result:=inttostr(round(v))+'K'; exit end;
   v:=v/1024;
   if v<10 then begin result:=FloatToStrF(v,ffFixed,4,2)+'M'; exit end;
   if v<100 then begin result:=FloatToStrF(v,ffFixed,4,1)+'M'; exit end;
   if v<1000 then begin result:=inttostr(round(v))+'M'; exit end;
   v:=v/1024;
   if v<10 then begin result:=FloatToStrF(v,ffFixed,4,2)+'G'; exit end;
   if v<100 then begin result:=FloatToStrF(v,ffFixed,4,1)+'G'; exit end;
   if v<1000 then begin result:=inttostr(round(v))+'G'; exit; end;
   v:=v/1024;
   if v<10 then begin result:=FloatToStrF(v,ffFixed,4,2)+'T'; exit end;
   if v<100 then begin result:=FloatToStrF(v,ffFixed,4,1)+'T'; exit end;
   result:=inttostr(round(v))+'T';
  end;

 function FormatTime(time:int64):string; // ������ � ��������� ���������� (time - � ms)
  begin
   if time<120000 then begin
    result:=IntToStr(time div 1000)+'.'+IntToStr(time mod 1000)+'s';
    exit;
   end;
   result:=FormatDateTime('hh:nn:ss',time/86400000);
   if time>86400000 then
    result:=IntToStr(trunc(time/86400000))+'d '+result;
  end;

 function FormatInt(int:int64):string;
  var
   i:integer;
  begin
   result:=IntToStr(int);
   i:=length(result)-2;
   while i>1 do begin
    Insert(' ',result,i);
    i:=i-3;
   end;
  end;

 function FormatMoney(v:double;digits:integer=2):string;
  var
   i:integer;
  begin
   result:=FloatToStrF(v,ffFixed,20,digits);
   i:=length(result)-2-digits;
   if digits>0 then dec(i);
   while i>1 do begin
    Insert(' ',result,i);
    i:=i-3;
   end;
  end;

 function PtrToStr(p:pointer):string; // Pointer to string
  begin
   {$IFDEF CPU64}
   result:=IntToHex(cardinal(p),12);
   {$ELSE}
   result:=IntToHex(cardinal(p),8);
   {$ENDIF}
  end;

 function IpToStr(ip:cardinal):string;
  begin
   result:=inttostr(ip and $FF)+'.'+
           inttostr((ip shr 8) and $FF)+'.'+
           inttostr((ip shr 16) and $FF)+'.'+
           inttostr((ip shr 24) and $FF);
  end;

 function StrToIp(ip:string):cardinal; // ������ � IP-�����
  var
   i,v:integer;
  begin
   result:=0;
   v:=0;
   for i:=1 to length(ip) do begin
    if ip[i] in ['0'..'9'] then
     v:=v*10+(byte(ip[i])-$30)
    else
    if ip[i]='.' then begin
     result:=result shr 8+v shl 24;
     v:=0;
    end;
   end;
   result:=result shr 8+v shl 24;
  end;

 function VarToStr(v:TVarRec):string;
  begin
   case v.VType of
    vtInteger:result:=IntToStr(v.VInteger);
    vtBoolean:result:=BoolToStr(v.VBoolean,true);
    vtChar:result:=v.VChar;
    vtString:result:=ShortString(v.VString^);
    vtAnsiString:result:=AnsiString(v.VAnsiString);
    vtExtended:result:=FloatToStrF(v.vExtended^,ffGeneral,12,0);
    vtVariant:result:=v.VVariant^;
    vtWideChar:result:=v.VWideChar;
    vtWideString:result:=UTF8Encode(WideString(v.vWideString));
    vtInt64:result:=IntToStr(v.vInt64^);
    else raise EWarning.Create('Incorrect variable type: '+inttostr(v.vtype));
   end;
  end;

 function ParseFloat(st:string):double; inline; // always use '.' as separator - replacement for SysUtils version
  var
   i,code:integer;
   st2:string[20];
  begin
   st2:='';
   for i:=1 to length(st) do
    if st[i] in ['0'..'9','-','.',','] then st2:=st2+st[i];
   if (pos('.',st2)=0) and (pos(',',st2)>0) then st2[pos(',',st2)]:='.';
   Val(st2,result,code);
   if code<>0 then
    raise EConvertError.Create(st+' is not a valid floating point number');
  end;

 function ParseInt(st:string):int64; inline; // wrong characters ignored
  var
   i:integer;
  begin
   result:=0;
   for i:=1 to length(st) do
    if st[i] in ['0'..'9'] then result:=result*10+(byte(st[i])-$30);
   for i:=1 to length(st) do begin
    if st[i]='-' then result:=-result;
    if st[i] in ['0'..'9'] then break;
   end;
  end;

 function ListIntegers(a:system.PInteger;count:integer;separator:char=','):string;
  begin
   result:='';
   while count>0 do begin
    result:=result+IntToStr(a^);
    inc(a); dec(count);
    if count>0 then result:=result+separator;
   end;
  end;

function ListIntegers(a:array of integer;separator:char=','):string;
 var
  i:integer;
 begin
  result:='';
  for i:=low(a) to high(a) do begin
   result:=result+IntToStr(a[i]);
   if i<high(a) then result:=result+separator;
  end;
 end;

function SimpleCompress(data:string):string;
 var
  i,j,curpos,outpos,foundStart,foundLength,ofs,max:integer;
  res:string;
  prev:array of integer; // array of backreferences: index of previous byte with the same value
  last:array[0..255] of integer; // index of last byte of given value
  b:byte;
 procedure Output(v:cardinal;count:integer); // output count bits from v
  var
   i,o:integer;
  begin
   for i:=count-1 downto 0 do begin
    if v and (1 shl i)>0 then begin
     o:=1+outpos shr 3;
     res[o]:=char(byte(res[o]) or (1 shl (7-(outpos and 7))));
    end;
    inc(outpos);
   end
  end;
 begin
  outpos:=0; // output bit position
  SetLength(res,round(length(data)*1.25+1)); // 1.25 is the worst case
  fillchar(res[1],length(res),0);
  fillchar(last,sizeof(last),0);
  SetLength(prev,length(data)+1);
  fillchar(prev[1],length(data)*4,0);
  curpos:=1;
  while curpos<=length(data) do begin // pack
   // 1. ����� ����� ������� ���������� �������
   foundStart:=0; foundLength:=0;
   b:=byte(data[curpos]);
   i:=last[b];
   while (i>0) and (i>curPos-4096) do begin
    // ����������� ��������� ����� �������
    max:=length(data)-curPos+1; // ������� ������ �������� ������
    if max>20 then max:=20; // �� ����� 20 ���� �� ���!
    if max>curPos-i then max:=curPos-i; // ������� �������� ������
    j:=0;
    while (j<max) and (data[i+j]=data[curpos+j]) do inc(j);
    ofs:=curpos-i;
    if (j>foundStart) and (
       (j=1) and (ofs<17) or
       (j=2) and (ofs<66) or
       (j=3) and (ofs<259) or
       (j=4) and (ofs<1028) or
       (j>4) and (ofs<4100)) then begin
     foundStart:=i;
     foundlength:=j;
    end;
    i:=prev[i];
   end;

   // 2. ��������� ���
   if foundLength>0 then begin // ������� ������� (�������� ������ ���� ����������)
    ofs:=curPos-foundStart-foundLength;
    if foundLength=1 then
     Output($10+ofs,6)
    else begin
     Output($FFFFFFE,foundLength);
     max:=foundLength*2+2;
     if max>12 then max:=12; // �� ����� 12 ��� �� ��������
     Output(ofs,max);
    end;
   end else begin // �� �������
    Output(b,10);
    foundLength:=1;
   end;

   // 3. �������� ������� ������
   while foundLength>0 do begin
    prev[curpos]:=last[b];
    last[b]:=curPos;
    inc(curPos);
    b:=byte(data[curpos]);
    dec(foundLength);
   end;
  end;
  SetLength(res,(outpos+7) shr 3);
  result:=res;
 end;

function SimpleDecompress(data:string):string;
 var
  i,curpos,outpos,rsize,bCount,ofs,L,M:integer;
  res:string;
 function GetBits(cnt:integer):cardinal;
  var
   i:integer;
  begin
   result:=0;
   for i:=0 to cnt-1 do begin
    result:=result shl 1;
    if byte(data[1+curpos shr 3]) and (1 shl (7-(curpos and 7)))>0 then
     result:=result or 1;
    inc(curpos);
   end;
  end;
 procedure Output(v:byte);
  begin
   res[outpos]:=char(v);
   inc(outpos);
   if outpos>=rsize then begin
    rsize:=rsize*2;
    SetLength(res,rsize);
   end;
  end;
 begin
  curpos:=0; outpos:=1;
  bCount:=length(data)*8;
  rsize:=length(data)*2;
  SetLength(res,rsize);
  repeat
   if curpos+6>bCount then break;

   if GetBits(1)=0 then begin
    if GetBits(1)=0 then begin
     // immediate value
     if curPos+8>bCount then break;
     Output(GetBits(8));
    end else begin
     // L=1
     ofs:=GetBits(4);
     Output(byte(res[outpos-ofs-1]));
    end;
   end else begin
    // L>1
    L:=2;
    while GetBits(1)=1 do inc(L);
    M:=L*2+2;
    if M>12 then M:=12;
    ofs:=GetBits(M);
    for i:=0 to L-1 do
     Output(byte(res[outpos-ofs-L]));
   end;
  until false;
  SetLength(res,outPos-1);
  result:=res;
 end;

// ������ ����������� ������: 1b - ����� (������� ��� =0 - ����� �������������, ������� 7 ��� - ����� �������)
// ����� ����� �������� ������� �� 3 � ����� ������������� ������
function PackRLE(buf:pointer;size:integer;addHeader:boolean=true):ByteArray;
 var
  p,cur:integer;
  pb:PByte; // ������� ��������������� ����
  start:PByte; // ������ ������������� ����
  cnt:integer; // ������� ��������� ���� ���������
  len:integer; // �� ������� ���� ������������ ������ (len=pb-start)
 begin
  SetLength(result,8+size+size div 8);
  if addHeader then begin
   result[0]:=byte('!');
   result[1]:=byte('R');
   result[2]:=byte('L');
   result[3]:=byte('E');
   move(size,result[4],4); // data size
   p:=8;
  end else
   p:=0;
  pb:=buf;
  cur:=-1; cnt:=1;
  start:=pb; len:=0;
  while true do begin
   // ��������, � ������� ���������� ���-�� �������:
   // - ��������� ����� ������
   // - ����������� ����� ������������� ������
   // - ���� ���������, ������ ����������� ������ ���� �� ����� 3-�
   if (size>0) and (pb^=cur) then begin
    inc(cnt);
    if cnt>193 then begin
     if len>=cnt then begin
      inc(len);
      result[p]:=$C0+len-cnt-1; inc(p);
      move(start^,result[p],len-cnt); inc(p,len-cnt);
     end;
     result[p]:=cnt-3; inc(p);
     result[p]:=cur; inc(p);
     start:=pb; len:=0; cnt:=1;
    end;
   end else begin
    if (cnt>=3) or (len>=64) or (size<=0) then begin
     if cnt<2 then cnt:=0;
     if len>cnt then begin
      result[p]:=$C0+len-cnt-1; inc(p);
      move(start^,result[p],len-cnt); inc(p,len-cnt);
     end;
     if cnt>=2 then begin
      result[p]:=cnt-2; inc(p);
      result[p]:=cur; inc(p);
     end;
     if size<=0 then break;
     start:=pb; len:=0;
    end;
    cnt:=1;
    cur:=pb^;
   end;

   inc(pb); inc(len);
   dec(size);
  end;

  SetLength(result,p);
 end;

function CheckRLEHeader(buf:pointer;size:integer):integer; // -1 - no header
 var
  pb:PByte;
 begin
  result:=-1;
  if size<8 then exit;
  pb:=buf;
  if pb^<>byte('!') then exit; inc(pb);
  if pb^<>byte('R') then exit; inc(pb);
  if pb^<>byte('L') then exit; inc(pb);
  if pb^<>byte('E') then exit; inc(pb);
  move(pb^,result,4);
 end;

function UnpackRLE(buf:pointer;size:integer):ByteArray;
 var
  pb:PByte;
  s,p:integer;
  c:byte;
 begin
  pb:=buf;
  // Check source data format
  pb:=buf;
  s:=CheckRLEHeader(buf,size);
  if s<0 then begin
   // no header
   s:=0; p:=size;
   while p>0 do begin
    c:=pb^;
    if pb^ and $C0=$C0 then begin
     c:=(c xor $C0)+1; inc(s,c);
     inc(c); inc(pb,c); dec(p,c);
    end else begin
     inc(s,c+2); inc(pb,2); dec(p,2);
    end;
   end;
   pb:=buf;
  end else
   inc(pb,8);
  SetLength(result,s);

  // Unpack data
  p:=0;
  while size>0 do begin
   c:=pb^;
   inc(pb); dec(size);
   if c and $C0=$C0 then begin
    c:=(c xor $C0)+1;
    move(pb^,result[p],c);
    inc(p,c);
    inc(pb,c); dec(size,c);
   end else begin
    inc(c,2);
    fillchar(result[p],c,pb^);
    inc(p,c);
    inc(pb); dec(size);
   end;
  end;
 end;

procedure SimpleEncrypt;
 var
  p:PByte;
  i:integer;
 begin
  p:=addr(data);
  for i:=1 to size do begin
   p^:=p^ xor code;
   code:=(code+91) xor 39;
   inc(p);
  end;
 end;

procedure SimpleEncrypt2;
 var
  p:PByte;
  i:integer;
 begin
  p:=addr(data);
  for i:=1 to size do begin
   p^:=p^ xor code;
   code:=(code+i) xor (code shr (7+code and 3));
   inc(p);
  end;
 end;

 function PrintableStr(st:string):string;
  const
   hex:string[16]='0123456789ABCDEF';
  var
   i,max,p:integer;
  begin
   max:=length(st)*3;
   SetLength(result,max);
   p:=0;
   for i:=1 to length(st) do
    if st[i]<' ' then begin
     inc(p); result[p]:='#';
     inc(p); result[p]:=hex[1+ord(st[i]) div 16];
     inc(p); result[p]:=hex[1+ord(st[i]) mod 16];
    end else begin
     inc(p); result[p]:=st[i];
    end;
   SetLength(result,p);
  end; 

 function EncodeB64;
  var
   i:integer;
   sour,dest,offset:byte;
   pb:PByte;
  begin
   pb:=data;
   dest:=0;
   result:='';
   for i:=0 to size*8-1 do begin
    if i mod 8=0 then begin
     sour:=pb^;
     inc(pb);
    end;
    dest:=byte(dest shl 1) or byte(sour and 1);
    sour:=sour shr 1;
    if i mod 6=5 then begin
     result:=result+chr(64+dest);
     dest:=0;
    end;
   end;
   if (size*8-1) mod 6<>5 then begin
    offset:=(length(result)+1)*6-size*8;
    result:=result+chr(64+dest shl offset);
   end;
  end;

 procedure DecodeB64;
  var
   i,p:integer;
   sour,dest:byte;
   pb:PByte;
  begin
   pb:=buf;
   dest:=0;
   p:=0;
   size:=length(st)*6 div 8;
   for i:=0 to size*8-1 do begin
    if i mod 6=0 then begin               
     inc(p);
     sour:=ord(st[p])-64;
    end;
    dest:=dest shr 1+(sour shl 2) and $80;
    sour:=sour shl 1;
    if i mod 8=7 then begin
     pb^:=dest;
     dest:=0;
     inc(pb);
    end;
   end;
  end;

 function EncodeHex(st:string):string;
  const
   hex:string[16]='0123456789ABCDEF';
  var
   i:integer;
   b:byte;
  begin
   SetLength(result,length(st)*2);
   for i:=1 to length(st) do begin
    b:=byte(st[i]);
    result[i*2-1]:=hex[1+b shr 4];
    result[i*2]:=hex[1+b and 15];
   end;
  end;

 function EncodeHex(data:pointer;size:integer):string; overload;
  const
   hex:string[16]='0123456789ABCDEF';
  var
   i:integer;
   pb:PByte;
  begin
   SetLength(result,size*2);
   pb:=data;
   for i:=1 to size do begin
    result[i*2-1]:=hex[1+pb^ shr 4];
    result[i*2]:=hex[1+pb^ and 15];
    inc(pb);
   end;
  end;

 function DecodeHex(st:string):string;
  var
   i:integer;
   b:byte;
  begin
   SetLength(result,length(st) div 2);
   for i:=1 to length(result) do begin
    b:=HexToInt(copy(st,i*2-1,2));
    result[i]:=char(b);
   end;
  end;

 function IsUTF8(st:string):boolean; inline;
  begin
   if (length(st)>=3) and (st[1]=#$EF) and (st[2]=#$BB) and (st[3]=#$BF) then result:=true
    else result:=false;
  end;

 function EncodeUTF8(st:widestring;addBOM:boolean=false):string;
  var
   l,i:integer;
   w:word;
  begin
   setLength(result,3+length(st)*3);
   if addBOM then begin
    l:=3;
    result[1]:=#$EF;
    result[2]:=#$BB;
    result[3]:=#$BF;
   end else
    l:=0;
   for i:=1 to length(st) do begin
    w:=word(st[i]);
    if w<$80 then begin
     inc(l); result[l]:=chr(w);
    end else
    if w<$800 then begin
     inc(l); result[l]:=chr($C0+w shr 6);
     inc(l); result[l]:=chr($80+w and $3F);
    end else begin
     inc(l); result[l]:=chr($E0+w shr 12);
     inc(l); result[l]:=chr($80+(w shr 6) and $3F);
     inc(l); result[l]:=chr($80+w and $3F);
    end;
   end;
   setLength(result,l);
  end;

 function DecodeUTF8(st:string):widestring;
  var
   i,l:integer;
   w:word;
  begin
   if (length(st)>=3) and (st[1]=#$EF) and
      (st[2]=#$BB) and (st[3]=#$BF) then delete(st,1,3); // remove BOM
   SetLength(result,length(st));
   w:=0; l:=0;
   i:=1;
   while i<=length(st) do begin
    w:=0;
    if byte(st[i]) and $80=0 then begin
     // 1-byte character
     w:=byte(st[i]) and $7F;
     inc(i);
    end else
    if byte(st[i]) and $E0=$C0 then begin
     // 2-byte character
     w:=byte(st[i]) and $1F;
     inc(i);
     if i<=length(st) then
      w:=w shl 6+byte(st[i]) and $3F;
     inc(i);
    end else
    if byte(st[i]) and $F0=$E0 then begin
     // 3-byte character
     w:=byte(st[i]) and $0F;
     inc(i);
     if i<=length(st) then
      w:=w shl 6+byte(st[i]) and $3F;
     inc(i);
     if i<=length(st) then
      w:=w shl 6+byte(st[i]) and $3F;
     inc(i);
    end else
     inc(i);
    inc(l);
    result[l]:=WChar(w);
   end;
   setLength(result,l);
  end;

 function DecodeUTF8A(sa:StringArr):WStringArr;
  var
   i:integer;
  begin
   SetLength(result,length(sa));
   for i:=0 to high(sa) do
    result[i]:=DecodeUTF8(sa[i]);
  end;

 function UTF8toWin1251(st:string):string;
  var
   ws:widestring;
   i:integer;
  begin
   ws:=DecodeUTF8(st);
   SetLength(result,length(ws));
   for i:=1 to length(ws) do
    result[i]:=ConvertUnicodeToWindows(ws[i]);
  end;

 function Win1251toUTF8(st:string):string;
  var
   ws:widestring;
   i:integer;
  begin
   SetLength(ws,length(st));
   for i:=1 to length(ws) do
    ws[i]:=ConvertWindowstoUnicode(st[i]);
   result:=EncodeUTF8(ws);
  end;

 function UpperCaseUtf8(st:string):string;
  var
   wst:WideString;
  begin
   wst:=DecodeUTF8(st);
   wst:=WideUpperCase(wst);
   result:=EncodeUTF8(wst);
  end;

 function LowerCaseUtf8(st:string):string;
  var
   wst:WideString;
  begin
   wst:=DecodeUTF8(st);
   wst:=WideLowerCase(wst);
   result:=EncodeUTF8(wst);
  end;

 function UnicodeTo(st:WideString;encoding:TTextEncoding):string;
  var
   i:integer;
  begin
   case encoding of
    // UTF-8
    teUTF8:result:=EncodeUTF8(st);
    // Windows-1251
    teWin1251:begin
     setLength(result,length(st));
     for i:=1 to length(st) do
      result[i]:=ConvertUnicodeToWindows(st[i]);
    end;
    // ANSI (just low byte)
    teANSI:begin
     setLength(result,length(st));
     for i:=1 to length(st) do
      if word(st[i])<256 then result[i]:=chr(word(st[i]))
       else result[i]:='?';
    end;
    else raise EWarning.Create('Encoding not supported 1');
   end;
  end;

 function UnicodeFrom(st:string;encoding:TTextEncoding):WideString;
  var
   i:integer;
  begin
   case encoding of
    teUTF8:result:=DecodeUTF8(st);
    // Windows-1251
    teWin1251:begin
     setLength(result,length(st));
     for i:=1 to length(st) do
      result[i]:=ConvertWindowsToUnicode(st[i]);
    end;
    // ANSI (just low byte)
    teANSI:begin
     setLength(result,length(st));
     for i:=1 to length(st) do
      result[i]:=WideChar(byte(st[i]));
    end;
    else raise EWarning.Create('Encoding not supported 2');
   end;
  end;

 function HTMLString(st:string):string;
  begin
   st:=StringReplace(st,'&','&amp;',[rfReplaceAll]);
   st:=StringReplace(st,'<','&lt;',[rfReplaceAll]);
   st:=StringReplace(st,'>','&gt;',[rfReplaceAll]);
   result:=st;
  end;

 function UrlEncode;
  var
   i:integer;
   ch:char;
  begin
   result:='';
   for i:=1 to length(st) do begin
    ch:=st[i];
    if ch in ['A'..'Z','a'..'z','0'..'9','-','_','.','~'] then result:=result+ch
     else result:=result+'%'+hexchar[ord(ch) div 16+1]+hexchar[ord(ch) mod 16+1];
   end;
  end;

 function URLEncodeUTF8(st:string):string;
  var
   i:integer;
   ch:char;
  begin
   result:='';
   for i:=1 to length(st) do begin
    ch:=st[i];
    if ch<#128 then result:=result+ch
     else result:=result+'%'+hexchar[ord(ch) div 16+1]+hexchar[ord(ch) mod 16+1];
   end;
  end;

 function UrlDecode;
  var
   i:integer;
   b:byte;
  begin
   result:='';
   i:=1;
   while i<=length(st) do begin
    if (st[i]='%') and (i+2<=length(st)) then begin
     inc(i); b:=0;
     if st[i] in ['0'..'9'] then b:=ord(st[i])-ord('0');
     if st[i] in ['A'..'F'] then b:=ord(st[i])-ord('A')+10;
     b:=b*16; inc(i);
     if st[i] in ['0'..'9'] then b:=b+ord(st[i])-ord('0');
     if st[i] in ['A'..'F'] then b:=b+ord(st[i])-ord('A')+10;
     result:=result+chr(b);
    end else
    if st[i]='+' then result:=result+' '
    else
      result:=result+st[i];
    inc(i);
   end;
  end;

 function QuoteStr;
  var
   i:integer;
   fl:boolean;
  begin
   result:=st;
   // � ����� �� ������ ��������� � �������?
   if not force then begin
    fl:=false;
    if (length(st)=0) or (st[1]=quotes) then fl:=true;
    for i:=1 to length(st) do
     if st[i] in [' ',#9] then begin
      fl:=true; break;
     end;
    if not fl then exit; // ���� �� ����� - �������
   end;
   result:=quotes+StringReplace(st,quotes,quotes+quotes,[rfReplaceAll])+quotes;
  end;

 function UnQuoteStr;
  begin
   if (length(st)=0) or (st[1]<>quotes) then begin
    result:=st;
    exit;
   end;
   result:=st;
   delete(result,1,1);
   if result[length(result)]=quotes then SetLength(result,length(result)-1);
   result:=StringReplace(result,quotes+quotes,quotes,[rfReplaceAll]);
  end;

 function Unescape(st:string):string;
  var
   i,c,l:integer;
  begin
   SetLength(result,length(st));
   l:=0; i:=1; c:=0;
   while i<=length(st) do begin
    if st[i]='\' then begin
     inc(c);
     if c=2 then begin
      inc(l);
      result[l]:='\';
      c:=0;
     end else
      if (i<length(st)) and (st[i+1] in ['n','r','t','0','1']) then begin
       inc(l); c:=0;
       case st[i+1] of
        'n':begin
             result[l]:=#13;
             inc(l);
             result[l]:=#10;
             inc(i);
            end;
        'r':result[l]:=#13;
        't':result[l]:=#9;
        '0':result[l]:=#0;
        '1':result[l]:=#1;
       end;
      end;
    end else begin
     inc(l);
     result[l]:=st[i];
    end;
    inc(i);
   end;
   SetLength(result,l);
  end;

 function GetDateFromStr(st:string;default:TDateTime=0):TDateTime;
  var
   s1,s2:StringArr;
   year,hour,min,sec:integer;
   splitter:string;
  begin
   result:=default;
   try
    st:=chop(st);
    if st='' then exit;
    s1:=split(' ',st);
    splitter:='';
    if pos('.',s1[0])>0 then splitter:='.';
    if pos('-',s1[0])>0 then splitter:='-';
    if pos('/',s1[0])>0 then splitter:='/';
    if splitter='' then exit;
    s2:=split(splitter,s1[0]);
    if length(s2)<>3 then exit;
    if length(s2[0])=4 then Swap(s2[2],s2[0]);
    year:=strtoint(s2[2]);
    if year<100 then begin
     if year>70 then year:=1900+year
      else year:=2000+year;
    end;
    result:=EncodeDate(year,strtoint(s2[1]),strtoint(s2[0]));
    if length(s1)>1 then begin
     s2:=split(':',s1[1]);
     if length(s2)>0 then hour:=strtoint(s2[0]) else hour:=0;
     if length(s2)>1 then min:=strtoint(s2[1]) else min:=0;
     if length(s2)>2 then sec:=strtoint(s2[2]) else sec:=0;
     result:=result+EncodeTime(hour,min,sec,0);
    end;
   except
    result:=default;
   end;
  end;

 function HowLong(time:TDateTime):string;
  var
   t:int64;
   neg:boolean;
  begin
   if time=0 then begin
    result:='-'; exit;
   end;
   t:=round((Now-time)*86400);
   if t<0 then begin
    t:=-t; neg:=true;
   end else begin
    neg:=false;
   end;
   result:=IntToStr(t mod 60)+'s';
   if t<60 then exit;
   t:=t div 60; // �������� � ������
   result:=IntToStr(t mod 60)+'m'+result;
   if t<60 then exit;
   t:=t div 60; // �������� � ����
   result:=IntToStr(t mod 24)+'h'+result;
   if t<24 then exit;
   t:=t div 24; // �������� � ���
   result:=IntToStr(t)+'d '+result;
   if neg then result:='+'+result;
  end;

 {$IFDEF MSWINDOWS}
 function NowGMT;
  var
   stime:TSystemTime;
  begin
   GetSystemTime(stime);
   result:=SystemTimeToDateTime(stime);
  end;
 {$ENDIF} 
 {$IFDEF IOS}
 function NowGMT;
  begin
   //millisecondsFromGMT = 1000 * [[NSTimeZone localTimeZone] secondsFromGMT];
   result:=Now+(NSTimeZone.localTimeZone.secondsFromGMT)/86400;
  end;
 {$ENDIF}
 {$IFDEF ANDROID}
 function NowGMT;
  begin
   result:=LocalTimeToUniversal(Now);
  end;
 {$ENDIF}

 // ���������� ������ � ��������� ������������� ������
 function GetMemoryState:string;
{$IFDEF DELPHI}
  var
   state:TMemoryManagerState;
   i:integer;
   c,s:integer;
  begin
   GetMemoryManagerState(state);
   c:=0; s:=0;
   for i:=0 to High(state.SmallBlockTypeStates) do begin
    inc(c,state.smallBlockTypeStates[i].AllocatedBlockCount);
    inc(s,state.smallBlockTypeStates[i].AllocatedBlockCount*
     state.smallBlockTypeStates[i].UseableBlockSize);
   end;
   result:=IntToStr(s)+' in '+inttostr(c)+' / '+
    inttostr(state.TotalAllocatedMediumBlockSize)+' in '+
    inttostr(state.AllocatedMediumBlockCount)+' / '+
    inttostr(state.TotalAllocatedLargeBlockSize)+' in '+
    inttostr(state.AllocatedLargeBlockCount);
  end;
{$ELSE}
  begin
   result:='GetMemoryState: not yet implemented!';
  end;
{$ENDIF}

 function GetMemoryAllocated:int64;
 {$IFDEF DELPHI}
  var
   state:TMemoryManagerState;
   i:integer;
  begin
   result:=0;
   GetMemoryManagerState(state);
   for i:=0 to High(state.SmallBlockTypeStates) do begin
    inc(result,state.smallBlockTypeStates[i].AllocatedBlockCount*
     state.smallBlockTypeStates[i].UseableBlockSize);
   end;
   result:=result+state.TotalAllocatedMediumBlockSize+state.TotalAllocatedLargeBlockSize;
  end;
{$ELSE}
  begin
   result:=0;
  end;
{$ENDIF}

{ type
  BlockInfo=record
   magic:cardinal; // must be $C78A35D2
   blockSize:integer; // ������ ������� ����������� �����
   offset:integer; // ������ ������� ����� ������������ ����� ������ ������
   reserved:integer;
  end;

 function MyGetMem;
  var
   bi:^BlockInfo;
   s:integer;
   p:pointer;
   c,c2:cardinal;
  begin
   s:=size+32;
   GetMem(p,s);
   c:=cardinal(p);
   c2:=(c-1) and $FFFFFFF0+16; // ������������ �� ������� ���������
   bi:=pointer(c2);
   bi^.magic:=$C78A35D2;
   bi^.blockSize:=s;
   bi^.offset:=c2-c+16;
   c2:=c2+16;
   result:=pointer(c2);
  end;

 procedure MyFreeMem;
  var
   bi:^BlockInfo;
   c:cardinal;
  begin
   c:=cardinal(p)-16;
   bi:=pointer(c);
   if bi^.magic<>$C78A35D2 then
    raise EWarning.Create('Cannot release memory block: invalid pointer');
   c:=cardinal(p)-bi^.offset;
   FreeMem(pointer(c));
  end;  }

{$IFDEF DELPHI}
 procedure BeginMemoryCheck(id:string);
  begin
   if memleakcnt=40 then
    raise EError.Create('Stack of memory leaks is overflow!');
   inc(memleakcnt);
   with memleaks[memleakcnt] do begin
    name:=id;
    value:=AllocMemSize;
   end;
  end;

 procedure EndMemoryCheck;
  begin
   if memleakcnt=0 then
    raise EError.Create('Stack of memory leaks is empty!');
   if AllocMemSize<>MemLeaks[memleakcnt].value then
    raise EError.Create('Memory leak found - '+MemLeaks[memleakcnt].name+
     ': was - '+inttostr(MemLeaks[memleakcnt].value)+' bytes, now - '+
     inttostr(AllocMemSize)+' bytes allocated.');
   memleaks[memleakcnt].name:='';
   dec(memleakcnt);
  end;
{$ENDIF}

 function ConvertToWindows(ch:char):char;
  var
   b:byte;
  begin
   b:=byte(ch);
   if (b>=128) and (b<=175) then b:=b+64
   else
   if (b>=224) and (b<=239) then b:=b+16
   else
   if b=240 then b:=168
   else
   if b=241 then b:=184;
   result:=chr(b);
  end;

 function ConvertFromWindows(ch:char):char;
  var
   b:byte;
  begin
   b:=byte(ch);
   if (b>=192) and (b<=239) then b:=b-64
   else
   if (b>=240) then b:=b-16
   else
   if b=168 then b:=240
   else
   if b=184 then b:=241;
   result:=chr(b);
  end;

const
 win1251cp:array[$80..$FF] of word=
   ($0402,$0403,$201A,$0453,$201E,$2026,$2020,$2021,$20AC,$2030,$0409,$2039,$040A,
    $040C,$040B,$040F,$0452,$2018,$2019,$201C,$201D,$2022,$2013,$2014,$FFFF,$2122,$0459,
    $203A,$045A,$045C,$045B,$045F,$00A0,$040E,$045E,$0408,$00A4,$0490,$00A6,$00A7,
    $0401,$00A9,$0404,$00AB,$00AC,$00AD,$00AE,$0407,$00B0,$00B1,$0406,$0456,$0491,
    $00B5,$00B6,$00B7,$0451,$2116,$0454,$00BB,$0458,$0405,$0455,$0457,$0410,$0411,
    $0412,$0413,$0414,$0415,$0416,$0417,$0418,$0419,$041A,$041B,$041C,$041D,$041E,
    $041F,$0420,$0421,$0422,$0423,$0424,$0425,$0426,$0427,$0428,$0429,$042A,$042B,
    $042C,$042D,$042E,$042F,$0430,$0431,$0432,$0433,$0434,$0435,$0436,$0437,$0438,
    $0439,$043A,$043B,$043C,$043D,$043E,$043F,$0440,$0441,$0442,$0443,$0444,$0445,
    $0446,$0447,$0448,$0449,$044A,$044B,$044C,$044D,$044E,$044F);


 function ConvertWindowsToUnicode(ch:char):widechar;
  var
   b:byte;
  begin
   b:=byte(ch);
   if b<$80 then result:=WideChar(byte(b))
    else result:=WideChar(win1251cp[b]);
  end;

 function ConvertUnicodeToWindows(ch:widechar):char;
  var
   i:integer;
   w:word;
  begin
   w:=word(ch);
   if w<$80 then result:=chr(w)
    else begin
     if (w>=$410) and (w<=$44F) then begin
      result:=chr(192+w-$410); exit;
     end;
     result:=' ';
     for i:=$80 to $BF do
      if win1251cp[i]=w then begin
       result:=chr(i); exit;
      end;
    end;
  end;

 const
  namedata:string='john steve peter mark mary steve smith dennis alice alex jane joan baker albert henry jim helen charles diana white brown williams emily anny robert margaret victor thomas george richard';
 function RandomName(minlen,maxlen:byte):string;
  var
   i,j,l,c:integer;
   ch:char;
  begin
   result:='';
   l:=minlen+random(maxlen-minlen+1);
   ch:=' ';
   for i:=1 to l do begin
    j:=1+random(length(namedata));
    c:=0;
    while (namedata[j]<>ch) or (namedata[j+1]=' ') do begin
     inc(j);
     if j>=length(namedata) then j:=1;
     inc(c);
     if (c>300) and (namedata[j+1]<>' ') then
      break;
    end;
    ch:=namedata[j+1];
    result:=result+ch;
   end;
   result[1]:=UpCase(result[1]);
  end;

 procedure SortObjects(var obj:array of TSortableObject);
  procedure QuickSort(var obj:array of TSortableObject;a,b:integer);
   var
    lo,hi,mid:integer;
    o,midobj:TSortableObject;
   begin
    lo:=a; hi:=b;
    mid:=(a+b) div 2;
    midobj:=obj[mid];
    repeat
     while midobj.Compare(obj[lo])>0 do inc(lo);
     while midobj.Compare(obj[hi])<0 do dec(hi);
     if lo<=hi then begin
      o:=obj[lo];
      obj[lo]:=obj[hi];
      obj[hi]:=o;
      inc(lo);
      dec(hi);
     end;
    until lo>hi;
    if hi>a then QuickSort(obj,a,hi);
    if lo<b then QuickSort(obj,lo,b);
   end;
  begin
   if length(obj)<2 then exit;
   QuickSort(obj,low(obj),high(obj));
  end;

 procedure SortStrings(var sa:StringArr); overload;
  procedure QuickSort(a,b:integer);
   var
    lo,hi,mid:integer;
    midval:string;
   begin
    lo:=a; hi:=b;
    mid:=(a+b) div 2;
    midval:=sa[mid];
    repeat
     while sa[lo]<midval do inc(lo);
     while sa[hi]>midval do dec(hi);
     if lo<=hi then begin
      Swap(sa[lo],sa[hi]);
      inc(lo);
      dec(hi);
     end;
    until lo>hi;
    if hi>a then QuickSort(a,hi);
    if lo<b then QuickSort(lo,b);
   end;
  begin
   if length(sa)<2 then exit;
   QuickSort(0,high(sa));
  end;

 procedure SortStrings(var sa:WStringArr); overload;
  procedure QuickSort(a,b:integer);
   var
    lo,hi,mid:integer;
    midval:WideString;
   begin
    lo:=a; hi:=b;
    mid:=(a+b) div 2;
    midval:=sa[mid];
    repeat
     while sa[lo]<midval do inc(lo);
     while sa[hi]>midval do dec(hi);
     if lo<=hi then begin
      Swap(WideString(sa[lo]),WideString(sa[hi]));
      inc(lo);
      dec(hi);
     end;
    until lo>hi;
    if hi>a then QuickSort(a,hi);
    if lo<b then QuickSort(lo,b);
   end;
  begin
   if length(sa)<2 then exit;
   QuickSort(0,high(sa));
  end;

 function LongDiv(var data:ByteArray;divider:byte):integer;
  var
   i,c,v:integer;
  begin
   c:=0;
   for i:=length(data)-1 downto 0 do begin
    v:=c shl 8+data[i];
    c:=v mod divider;
    data[i]:=v div divider;
   end;
   result:=c;
   for i:=length(data)-1 downto 0 do
    if data[i]<>0 then break;
   SetLength(data,i+1);
  end;

 const
  table48:array[0..47] of char=('0','1','2','3','4','5','6','7','8','9',
                                'A','B','C','D','E','F','G','H','I','J',
                                'K','L','M','N','O','P','Q','R','S','T',
                                'U','V','W','X','Y','Z','-','+','=',':',
                                '<','>','/','\','&','@','#','$');

 procedure LongMult(var buf:ByteArray;mult:byte);
  var
   i,c,v:integer;
  begin
   c:=0;
   for i:=0 to length(buf)-1 do begin
    v:=buf[i]*mult+c;
    buf[i]:=v and $FF;
    c:=v shr 8;
   end;
  end;

function BinToStr;
 var
  st:string;
  data:ByteArray;
 begin
  SetLength(data,size);
  move(buf,data[0],size);
  st:='';
  repeat
   st:=st+table48[LongDiv(data,48)];
  until length(data)=0;
  result:=st;
 end;

 function StrToBin;
  var
   i,v,j:integer;
   data:ByteArray;
  function GetOrd(ch:char):byte;
   var
    i:integer;
   begin
    result:=0;
    for i:=0 to 47 do
     if ch=table48[i] then result:=i;
   end;
  begin
   SetLength(data,size);
   fillchar(data[0],size,0);
   data[0]:=GetOrd(st[Length(st)]);
   for i:=length(st)-1 downto 1 do begin
    LongMult(data,48);
    v:=GetOrd(st[i]);
    for j:=0 to size-1 do begin
     v:=v+data[j];
     data[j]:=v and $FF;
     v:=v shr 8;
     if v=0 then break;
    end;
   end;
   move(data[0],buf,size);
  end;

 // Saturated value of b
 function Sat(b,min,max:integer):integer;
  begin
   Sat:=b;
   if b>max then Sat:=max;
   if b<min then Sat:=min;
  end;

 function SatD(b,min,max:double):double;
  begin
   result:=b;
   if b>max then result:=max;
   if b<min then result:=min;
  end;  

 // Return value of pike function
 function Pike(x,arg,a,b,c:integer):integer;
  begin
   if x<0 then begin Pike:=a; exit; end;
   if x>255 then begin Pike:=c; exit; end;
   if x<arg then Pike:=a+(b-a)*x div arg
    else Pike:=b+(c-b)*(x-arg) div (256-arg);
  end;

 function PikeD(x,arg,a,b,c:double):double; // [0..1] range
  begin
   if x<=0 then begin result:=a; exit; end;
   if x>=1 then begin result:=c; exit; end;
   if x<arg then result:=a+(b-a)*x/arg
    else result:=b+(c-b)*(x-arg)/(1-arg);
  end;

 function SatSpline(x:single;a,b,c:integer):byte;
  var
   u,v,w:single;
   r:integer;
  begin
   if x<0 then x:=0;
   if x>1 then x:=1;
   w:=a;
   v:=4*b-3*a-c;
   u:=c-a-v;
   r:=round(x*x*u+x*v+w);
   if r>255 then r:=255;
   if r<0 then r:=0;
   result:=r;
  end;

 function SatSpline3(x:single;a,b,c,d:integer):byte;
  var
   u,v,w,t:single;
   r:integer;
  begin
   if x<0 then x:=0;
   if x>1 then x:=1;
   t:=a;
   w:=-(27*c+33*a-54*b-6*d)/6;
   v:=(27*b-26*a-d-8*w)/2;
   u:=d-a-v-w;
   r:=round(t+x*w+x*x*v+x*x*x*u);
   if r>255 then r:=255;
   if r<0 then r:=0;
   result:=r;
  end;

 function AddString(var sa:StringArr;const st:string;index:integer=-1):integer; overload;
  var
   n:integer;
  begin
   n:=length(sa);
   SetLength(sa,n+1);
   if index<0 then index:=n;
   while n>index do begin
    sa[n]:=sa[n-1]; dec(n);
   end;
   sa[n]:=st;
   result:=n;
  end;

 function AddString(var sa:WStringArr;const st:WideString;index:integer=-1):integer; overload;
  var
   n:integer;
  begin
   n:=length(sa);
   SetLength(sa,n+1);
   if index<0 then index:=n;
   while n>index do begin
    sa[n]:=sa[n-1]; dec(n);
   end;
   sa[n]:=st;
   result:=n;
  end;


 function AddInteger(var a:IntArray;v:integer;index:integer=-1):integer;
  var
   n:integer;
  begin
   n:=length(a);
   SetLength(a,n+1);
   if index<0 then index:=n;
   while n>index do begin
    a[n]:=a[n-1]; dec(n);
   end;
   a[n]:=v;
   result:=n;
  end;

 procedure RemoveInteger(var a:IntArray;index:integer;keepOrder:boolean=false);
  var
   i:integer;
  begin
   if keepOrder then begin
    for i:=index to high(a)-1 do
     a[i]:=a[i+1];
   end else
    a[index]:=a[high(a)];
   SetLength(a,length(a)-1);
  end;

 function AddFloat(var a:FloatArray;v:double;index:integer=-1):integer;
  var
   n:integer;
  begin
   n:=length(a);
   SetLength(a,n+1);
   if index<0 then index:=n;
   while n>index do begin
    a[n]:=a[n-1]; dec(n);
   end;
   a[n]:=v;
   result:=n;
  end;

 procedure RemoveFloat(var a:FloatArray;index:integer;keepOrder:boolean=false);
  var
   i:integer;
  begin
   if keepOrder then begin
    for i:=index to high(a)-1 do
     a[i]:=a[i+1];
   end else
    a[index]:=a[high(a)];
   SetLength(a,length(a)-1);
  end;

 function ArrayToStr(a:array of integer;divider:char=','):string;
  var
   v:integer;
  begin
   result:='';
   for v in a do begin
    if result<>'' then result:=result+divider;
    result:=result+IntToStr(v);
   end;
  end;

 function StrToArray(st:string;divider:char=','):IntArray;
  var
   sa:StringArr;
   i:integer;
  begin
   sa:=split(divider,st);
   SetLength(result,length(sa));
   for i:=0 to high(sa) do
    result[i]:=StrToIntDef(sa[i],0);
  end;

 procedure RemoveString(var sa:StringArr;index:integer); overload;
  var
   n:integer;
  begin
   if (index<0) or (index>high(sa)) then exit;
   n:=length(sa)-1;
   while index<n do begin
    sa[index]:=sa[index+1];
    inc(index);
   end;
   SetLength(sa,n);
  end;

 procedure RemoveString(var sa:WStringArr;index:integer); overload;
  var
   n:integer;
  begin
   if (index<0) or (index>high(sa)) then exit;
   n:=length(sa)-1;
   while index<n do begin
    sa[index]:=sa[index+1];
    inc(index);
   end;
   SetLength(sa,n);
  end;

 function FindString(var sa:StringArr;st:string;ignoreCase:boolean=false):integer;
  var
   i:integer;
  begin
   result:=-1;
   if ignoreCase then begin
    st:=lowercase(st);
    for i:=0 to high(sa) do
     if lowercase(sa[i])=st then begin
      result:=i; exit;
     end;
   end else
    for i:=0 to high(sa) do
     if sa[i]=st then begin
      result:=i; exit;
     end;
  end;

 function FindInteger(var a:IntArray;v:integer):integer;
  var
   i:integer;
  begin
   for i:=0 to high(a) do
    if a[i]=v then begin
     result:=i; exit;
    end;
   result:=-1;
  end;

 function CopyArray(a:StringArr):StringArr; overload;
  var
   i:integer;
  begin
   SetLength(result,length(a));
   for i:=0 to high(a) do
    result[i]:=a[i];
  end;
 function CopyArray(a:WStringArr):WStringArr; overload;
  var
   i:integer;
  begin
   SetLength(result,length(a));
   for i:=0 to high(a) do
    result[i]:=a[i];
  end;
 function CopyArray(a:ByteArray):ByteArray; overload;
  var
   i:integer;
  begin
   SetLength(result,length(a));
   for i:=0 to high(a) do
    result[i]:=a[i];
  end;
 function CopyArray(a:IntArray):IntArray; overload;
  var
   i:integer;
  begin
   SetLength(result,length(a));
   for i:=0 to high(a) do
    result[i]:=a[i];
  end;
 function CopyArray(a:FloatArray):FloatArray; overload;
  var
   i:integer;
  begin
   SetLength(result,length(a));
   for i:=0 to high(a) do
    result[i]:=a[i];
  end;

 function PosFrom(substr,str:WideString;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
  var
   m,n,i:integer;
  begin
   result:=0;
   if ignoreCase then begin
    substr:=WideLowercase(substr);
    str:=WideLowercase(str);
   end;   
   n:=length(substr);
   m:=length(str)-n+1;
   while minIndex<=m do begin                       
    i:=0;
    while (i<n) and (str[minIndex+i]=substr[i+1]) do inc(i);
    if i=n then begin
     result:=minIndex; exit;
    end;
    inc(minIndex);
   end;
  end;

 function PosFrom(substr,str:string;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
  var
   m,n,i:integer;
  begin
   result:=0;
   if ignoreCase then begin
    substr:=lowercase(substr);
    str:=lowercase(str);
   end;
   n:=length(substr);
   m:=length(str)-n+1;
   while minIndex<=m do begin
    i:=0;
    while (i<n) and (str[minIndex+i]=substr[i+1]) do inc(i);
    if i=n then begin
     result:=minIndex; exit;
    end;
    inc(minIndex);
   end;
  end;

 function ExtractStr(str,prefix,suffix:string;out prefIndex:integer):string;
  var
   p1,p2:integer;
  begin
   p1:=pos(prefix,str);
   p2:=PosFrom(suffix,str,p1+length(prefix));
   if (p1>0) and (p2>0) then begin
    prefIndex:=p1;
    inc(p1,length(prefix));
    result:=copy(str,p1,p2-p1);
   end else begin
    result:=''; prefIndex:=0;
   end;
  end;

 function Split(divider,st:string;quotes:char):StringArr; overload;
  var
   i,j,n:integer;
  // Resize strings array
  procedure Resize(var arr:StringArr;newsize:integer);
   begin
    if newsize>length(arr) then
     SetLength(arr,length(arr)+256);
   end;
  // Main function body
  begin
   if st='' then begin
    SetLength(result,0); exit;
   end;
   n:=0;
   repeat
    // delete spaces at the beginning
    while (length(st)>0) and (st[1] in [#9,' ']) do delete(st,1,1);
    i:=pos(divider,st);

    if length(st)=0 then break; // empty string

    if (length(st)>1) and (st[1]=quotes) then begin
     // string is quoted
     // So find enclosing quotes
     j:=2;
     repeat
      if st[j]=quotes then begin
       if (j<length(st)) and (st[j+1]=quotes) then begin
        // paired quotes: replace and skip
        delete(st,j,1);
       end else break;
      end;
      inc(j);
     until j>length(st);
     if j>length(st) then begin
      LogMessage('Warning! Unterminated string: '+st);
     end;
     Resize(result,n+1);
     result[n]:=copy(st,2,j-2);
     delete(st,1,j+length(divider));
     inc(n);
    end else begin
     // simply get first divider
     Resize(result,n+2);
     if i=0 then begin // No divider found - all string is last substr
      result[n]:=st;
      inc(n);
      break;
     end else begin // divider found
      result[n]:=copy(st,1,i-1);
      delete(st,1,i+length(divider)-1);
      inc(n);
     end;
     i:=length(result[n]);
     while (i>0) and (result[n][i]<=' ') do dec(i);
     if i<length(result[n]) then SetLength(result[n],i);
     if length(st)=0 then inc(n); // for last empty substring
    end;
   until false;
   SetLength(result,n);
  end;

 function Split(divider,st:string):StringArr;
  var
   i,j,n,divLen,maxIdx:integer;
   fl:boolean;
   idx:array of integer;
  begin
   if st='' then begin
    SetLength(result,0); exit;
   end;
   setLength(idx,15);
   idx[0]:=1;
   // count dividers
   n:=0;
   i:=1;
   divLen:=length(divider);
   maxIdx:=length(st)-divLen+1;
   while i<=maxIdx do begin
    if st[i]<>divider[1] then
     inc(i)
    else begin
     fl:=true;
     for j:=2 to divLen do
      if st[i+j-1]<>divider[j] then begin
       fl:=false; break;
      end;
     if fl then begin
      inc(n);
      if n>=length(idx)-1 then SetLength(idx,length(idx)*4);
      idx[n]:=i+divLen;
      inc(i,divLen);
     end else inc(i);
    end;
   end;
   inc(n);
   idx[n]:=length(st)+length(divider)+1;
   SetLength(result,n);
   for i:=0 to n-1 do begin
    j:=idx[i+1]-length(divider)-idx[i];
    SetLength(result[i],j);
    if j>0 then move(st[idx[i]],result[i][1],j);
   end;    
  end;

 function SplitW(divider,st:WideString):WStringArr;
  var
   i,j,n:integer;
   fl:boolean;
   idx:array of integer;
  begin
   setLength(idx,100);
   idx[0]:=1;
   // count dividers
   n:=0;
   i:=1;
   while i<=length(st)-length(divider)+1 do begin
    fl:=true;
    for j:=1 to length(divider) do
     if st[i+j-1]<>divider[j] then begin
      fl:=false; break;
     end;
    if fl then begin
     j:=length(divider);
     inc(n);
     if n>=length(idx) then setLength(idx,length(idx)*4);
     idx[n]:=i+j;
     inc(i,j);
    end else inc(i);
   end;
   inc(n);
   idx[n]:=length(st)+length(divider)+1;
   SetLength(result,n);
   for i:=0 to n-1 do begin
    j:=idx[i+1]-length(divider)-idx[i];
    SetLength(result[i],j);
    if j>0 then move(st[idx[i]],result[i][1],j*2);
   end;
  end;


 function Combine;
  var
   st:string;
   i:integer;
  // ���� �����-�� �� ����� ���������� � ������������� ���������, �� ���������� ����� ��������� ��� �� ������
  procedure PrepareString(var s:string;divider:string;quotes:char);
   var
    i:integer;
   begin
    if (pos(divider,s)>0) or
       ((length(s)>=1) and (s[1]=quotes){ and (s[length(s)]=quotes)}) then begin
     i:=1;
     while i<=length(st) do
      if s[i]=quotes then begin
       insert(quotes,s,i);
       inc(i,2);
      end else
       inc(i);
     s:=quotes+s+quotes;
    end;
   end;
  begin
   result:='';
   if Length(strings)=0 then exit;
   st:=strings[0];
   PrepareString(st,divider,quotes);
   result:=st;
   for i:=1 to length(strings)-1 do begin
    st:=strings[i];
    PrepareString(st,divider,quotes);
    result:=result+divider+st;
   end;
  end;

 function Join(items:array of const;divider:string):string; overload;
  var
   i:integer;
  begin
   result:='';
   for i:=low(items) to high(items) do begin
    if i>low(items) then result:=result+divider;
    result:=result+VarToStr(items[i]);
   end;
  end;

 function Join(strings:stringarr;divider:string):string; overload;
  var
   i,j,l,s,n,dl:integer;
   src:PChar;
  begin
   i:=0;
   s:=1000; SetLength(result,s);
   n:=1;
   dl:=length(divider);
   while i<length(strings) do begin
    if i>0 then begin
     move(divider[1],result[n],dl);
     inc(n,dl);
    end;
    j:=1;
    l:=length(strings[i]);
    src:=@strings[i][1];
    while j<=l do begin
{     if src^=divider then begin
      result[n]:=divider; inc(n);
     end;}
     result[n]:=src^; inc(n);
     if n+1+dl>=s then begin
      s:=s*2; SetLength(result,s);
     end;
     inc(j);
     inc(src);
    end;
    inc(i);
   end;
   SetLength(result,n-1);
  end;

 function HasPrefix(st,prefix:string):boolean;
  var
   i:integer;
  begin
   result:=false;
   if length(st)<length(prefix) then exit;
   for i:=1 to length(prefix) do
    if st[i]<>prefix[i] then exit;
   result:=true; 
  end;

 function SafeStrItem(sa:StringArr;idx:integer):string;
  begin
   result:='';
   if (idx<0) or (idx>high(sa)) then exit;
   result:=sa[idx];
  end;

 function chop;
  var
   i:integer;
  begin
   result:=st;
   while (length(result)>0) and (result[1]<=' ') do delete(result,1,1);
   i:=length(result);
   while (length(result)>0) and (result[i]<=' ') do dec(i);
   setlength(result,i);
  end;

 function LastChar(st:string):char;
  begin
   if st='' then result:=#0
    else result:=st[length(st)];
  end;

 function CharAt(st:string;index:integer):char;
  begin
   if (index<1) or (index>length(st)) then result:=#0
    else result:=st[index];
  end;

 function WCharAt(st:WideString;index:integer):WideChar;
  begin
   if (index<1) or (index>length(st)) then result:=#0
    else result:=st[index];
  end;

 procedure UseLogFile(name:string;keepOpened:boolean=false);
  var
   f:TextFile;
   dt:TDateTime;
   age:integer;
  begin
   FlushLog;
   MyEnterCriticalSection(crSection);
   try
   LogFileName:=name;
   age:=FileAge(ParamStr(0));
   dt:=FileDateToDateTime(age);
   try
    assign(f,name);
    rewrite(f);
    writeln(f,FormatDateTime('ddddd t',dt));
    close(f);
    LogStart:=MyTickCount;
    LogStartDate:=Now;
    LogTime:=round(Frac(Now)*86400) mod 3600;
    if keepOpened then begin
     assign(logFile,name);
     append(logFile);
     logAlwaysOpened:=true;
    end;
   except
    LogFileName:='';
   end;
   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure SetLogMode;
  const
   st='123456789ABCDEF';
  var
   i:integer;
  begin
   LogMode:=mode;
   ForceLogMessage('LogMode: '+inttostr(ord(mode))+' '+groups);
   if pos('*',groups)>0 then
    fillchar(logGroups,sizeof(logGroups),1)
   else
   for i:=1 to 15 do
    loggroups[i]:=pos(st[i],groups)>0;
  end;

 procedure IntFlushLog;
  var
   f:text;
  begin
   if logmode=lmSilent then exit;
   if LogFileName='' then exit;
   try
    if logAlwaysOpened then begin
     write(logFile,cacheBuf);
     flush(logFile);
    end else begin
     assign(f,LogFileName);
     append(f);
     try
      write(f,cachebuf);
     finally
      close(f);
     end;
    end;
    cacheBuf:='';
   except
   end;
  end;

 procedure LogPhrase;
  var
   f:TextFile;
  begin
   if LogMode<lmNormal then exit;
   if LogFileName='' then exit;
   MyEnterCriticalSection(crSection);
   try
    if cacheenabled and (length(cacheBuf)+length(text)<65000) then begin
     cacheBuf:=cacheBuf+text+#13#10;
    end else begin
     if cacheBuf<>'' then IntFlushLog;
     if logAlwaysOpened then begin
      write(logFile,text);
     end else begin
      assign(f,LogFileName);
      append(f);
      try
       write(f,text);
      finally
       close(f);
      end;
     end;
    end;
   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

{$IFDEF ANDROID}
 function AndroidLog(prio:longint;tag,text:pchar):longint; cdecl; varargs; external 'liblog.so' name '__android_log_print';
{$ENDIF}

 function FormatLogText(const text:string):string;
 {$IFDEF MSWINDOWS}
  var
   mm,ss,ms:integer;
   time:TSystemTime;
  {$ENDIF}
  begin
   {$IFDEF MSWINDOWS}
   getSystemTime(time);
   result:=chr(48+time.wHour div 10)+chr(48+time.wHour mod 10)+':'+
           chr(48+time.wMinute div 10)+chr(48+time.wMinute mod 10)+':'+
           chr(48+time.wSecond div 10)+chr(48+time.wSecond mod 10)+'.'+
           chr(48+time.wMilliseconds div 100)+chr(48+(time.wMilliseconds div 10) mod 10)+chr(48+time.wMilliseconds mod 10)+
           '  '+text;
   {$ELSE}
   result:=FormatDateTime('hh:nn:ss.z',Now)+'  '+text;
   {$ENDIF}
  end;

 procedure LogMessage;
  var
   f:TextFile;
  begin
   if LogMode<lmNormal then exit;
   if (group>0) and not loggroups[group] then exit;
   {$IFDEF ANDROID} {$IFDEF DEBUGLOG}
   AndroidLog(3,'ApusLib',PChar(text));
   {$ENDIF} {$ENDIF}
   if LogFileName='' then exit;

   if group>0 then text:='['+inttostr(group)+'] '+text;
   text:=FormatLogText(text);
   MyEnterCriticalSection(crSection);
   try
    if cacheenabled and (length(cacheBuf)+length(text)<65000) then begin
     // ��� �������� � ��������� �������� ���������
     cacheBuf:=cacheBuf+text+#13#10;
    end else begin
     // ��� �������� ���� ��� ������ ������������
     if not forceCacheUsage then begin
      // ������ � ��� �������������, ������� �������� ��� � ����� ���� ��������� ��������
      if cacheBuf<>'' then IntFlushLog;
      if logAlwaysOpened then begin
       writeln(logFile,text);
       flush(logFile);
      end else begin
       assign(f,LogFileName);
       try
        append(f);
        try
         writeln(f,text);
        finally
         close(f);
        end;
       except
        on e:exception do ErrorMessage('Failed to write to the log:'#13#10+e.Message+#13#10+text);
       end;
      end;
     end else begin
      // ����� "������ ������ � ���", � ��� ����������
      if length(cacheBuf)<65500 then begin
       cacheBuf:=cacheBuf+'Cache overflow!'#13#10; // ��������� ���������� �� ���
{       move(msg[1],cachebuf[cachesize+1],length(msg));
       inc(cachesize,length(msg));}
      end;
     end;
    end;

   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure LogError(text:string);
  begin
   ForceLogMessage(text);
   InterlockedIncrement(logErrorCount);
   Sleep(10);
  end;

 procedure DebugMessage;
  begin
   {$IFDEF DEBUGLOG}
   ForceLogMessage(text);
   {$ENDIF}
  end;

 procedure ForceLogMessage;
  var
   f:TextFile;
  begin
   if logmode=lmSilent then exit;
   {$IFDEF IOS}
   NSLog(NSStr(PChar(text)));
   {$ENDIF}
   {$IFDEF ANDROID} {$IFDEF DEBUGLOG}
   AndroidLog(4,'ApusLib',PChar(text));
   {$ENDIF} {$ENDIF}
   if LogFileName='' then exit;

   text:=FormatLogText(text);
   MyEnterCriticalSection(crSection);
   try
    if forceCacheUsage then begin
     // ����� "������ ������ � ���"
     if (length(cacheBuf)+length(text)<65000) then begin
      cacheBuf:=cacheBuf+text+#13#10;
     end else begin
      // ����� "������ ������ � ���", � ��� ����������
      if length(cacheBuf)<65500 then begin
       cacheBuf:=cacheBuf+'Cache overflow!'#13#10;
       {move(msg[1],cachebuf[cachesize+1],length(msg));
       inc(cachesize,length(msg));}
      end;
     end;
    end else begin
     // ������� ����� (������������� ��������� ������� ��������, ��� ����)
     if cacheBuf<>'' then
      IntFlushLog;
     if logAlwaysOpened then begin
      try
       writeln(logFile,text);
       flush(logFile);
      except
       on e:Exception do ErrorMessage('Failed to write to the log:'#13#10+e.Message+#13#10+text);
      end;
     end else begin
      assign(f,LogFileName);
      append(f);
      try
       try
        writeln(f,text);
       except
        on e:Exception do ErrorMessage('Failed to write to the log:'#13#10+e.Message+#13#10+text);
       end;
      finally
       close(f);
      end;
     end;
    end;
   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure FlushLog;
  var
   f:File;
   data:array of char;
  begin
   if LogFileName='' then exit;
   if cacheBuf='' then exit;
   MyEnterCriticalSection(crSection);
   try
    try
     IntFlushLog;

{     if not forceCacheUsage then
      IntFlushLog
     else begin
      setLength(data,cachesize);
      move(cachebuf[1],data[0],cachesize);
     end;}
    except
     on e:exception do ForceLogMessage('Error flushing Log: '+e.message);
    end;
   finally
    MyLeaveCriticalSection(crSection);
   end;
{   if forceCacheUsage and (logfilename<>'') then try
    assign(f,LogFileName);
    reset(f,1);
    seek(f,filesize(f));
    blockwrite(f,data[0],cachesize);
    close(f);
    cachesize:=0;
   except
    on e:exception do ErrorMessage('Can''t flush log: '+e.message);
   end;}
  end;

 procedure LogCacheMode(enable:boolean;enforceCache:boolean=false;runThread:boolean=false);
  begin
   cacheenabled:=enable;
   if enable then forceCacheUsage:=enforceCache;
   if not enable and (cacheBuf<>'') then flushLog;
   if runThread then begin
    if logThread=nil then
     logThread:=TLogThread.Create(false);
   end;
  end;

 procedure SystemLogMessage(text:string); // Post message to OS log
  begin
   {$IFDEF MSWINDOWS}
   
   {$ENDIF}
  end;  

 function ShowMessageEx(text,caption:string;flags:cardinal):integer;
  var
   s1,s2:PChar;
  begin
   {$IFDEF MSWINDOWS}
   s1:=StrAlloc(length(text)+1);
   s2:=StrAlloc(length(caption)+1);
   StrPCopy(s1,text);
   StrPCopy(s2,caption);
   result:=MessageBox(WindowHandle,s1,s2,flags);
   StrDispose(s1);
   StrDispose(s2);
   {$ENDIF}
  end;

 function ShowMessage;
  begin
   {$IFDEF MSWINDOWS}
   result:=ShowMessageEx(text,caption,MB_ICONINFORMATION);
   {$ELSE}
   Exception.Create(caption+': '+text);
   {$ENDIF}
  end;

 function AskYesNo;
  begin
   {$IFDEF MSWINDOWS}
   result:=ShowMessageEx(text,caption,MB_YESNO+MB_ICONQUESTION)=IDYES;
   {$ELSE}
   Exception.Create(caption+': '+text);
   {$ENDIF}
  end;

 procedure ErrorMessage;
  begin
   {$IFDEF MSWINDOWS}
   ShowMessageEx(text,'Error',MB_ICONERROR);
   {$ELSE}
   Exception.Create('ErrorMessage: '+text);
   {$ENDIF}
  end;

 function ExceptionMsg(const e:Exception):string;
 {$IFDEF CPUARM}
  var
   relAdr:int64;
  begin
   result:=e.Message;
   relAdr:=UIntPtr(ExceptAddr)-UIntPtr(@ExceptionMsg);
   result:='['+PtrToStr(ExceptAddr)+'('+inttostr(relAdr)+')] '+result;
  end;
 {$ELSE}
 begin
  result:=e.Message;
  result:='['+PtrToStr(ExceptAddr)+'] '+result;
 end;
 {$ENDIF}

 function FindFile;
  var
   sr:TSearchRec;
  begin
   result:='';
   FindFirst(path+PathSeparator+'*.*',faAnyFile,sr);
   while FindNext(sr)=0 do begin
    if (sr.name[1]='.') or (sr.Attr and faVolumeID>0) then continue;
    if sr.Attr and faDirectory>0 then begin
     result:=FindFile(name,path+PathSeparator+sr.name);
     if result<>'' then exit;
    end else
    if UpperCase(sr.name)=UpperCase(name) then begin
     result:=path+PathSeparator+sr.name;
     exit;
    end;
   end;
  end;

 function FindDir;
  var
   sr:TSearchRec;
  begin
   result:='';
   FindFirst(path+PathSeparator+'*.*',faDirectory,sr);
   while FindNext(sr)=0 do begin
    if (sr.name[1]='.') or (sr.Attr and faDirectory=0) then continue;
    if UpperCase(sr.name)=UpperCase(name) then begin
     result:=path+PathSeparator+sr.name;
     exit;
    end else begin
     result:=FindDir(name,path+PathSeparator+sr.name);
     if result<>'' then exit;
    end;
   end;
  end;

 function CopyDir;
  var
   sr:TSearchRec;
   buf:pointer;
   f,f2:file;
   size:integer;
  begin
   result:=true;
   CreateDir(dest);
   FindFirst(sour+PathSeparator+'*.*',faAnyFile,sr);
   while FindNext(sr)=0 do begin
    if (sr.name[1]='.') or
       (sr.Attr and faVolumeID>0) then continue;
    if sr.Attr and faDirectory>0 then
     result:=result and CopyDir(sour+PathSeparator+sr.name,dest+PathSeparator+sr.name)
    else begin
     assign(f,sour+PathSeparator+sr.name);
     reset(f,1);
     assign(f2,dest+PathSeparator+sr.name);
     rewrite(f2,1);
     getmem(buf,1024*256);
     repeat
      blockread(f,buf^,1024*256,size);
      blockwrite(f2,buf^,size);
     until size<1024*256;
     close(f);
     close(f2);
     freemem(buf,size);
     result:=result and (IOresult=0);
    end;
   end;
   FindClose(sr);
  end;

 function DeleteDir;
  var
   sr:TSearchRec;
  begin
   result:=true;
   FindFirst(path+PathSeparator+'*.*',faDirectory,sr);
   while FindNext(sr)=0 do begin
    if sr.Name[1]='.' then continue;
    if sr.Attr=faDirectory then
      result:=result and DeleteDir(path+PathSeparator+sr.Name)
     else result:=result and DeleteFile(path+PathSeparator+sr.name);
   end;
   FindClose(sr);
   result:=result and RemoveDir(path);
  end;

 function MoveDir;
  begin
   result:=CopyDir(sour,dest);
   result:=result and DeleteDir(sour);
  end;

procedure DumpDir(path:string);
 var
  sr:TSearchRec;
 begin
  ForceLogMessage('Directory dump: '+path);
  FindFirst(path+PathSeparator+'*.*',faAnyFile,sr);
  while FindNext(sr)=0 do begin
   ForceLogMessage(sr.name+' '+IntToHex(sr.attr,2)+' '+IntToStr(sr.size));
  end;
  FindClose(sr);
 end;

 function SafeFileName(fname:string):string;
  var
   i:integer;
  begin
   fname:=StringReplace(fname,'..','.',[rfReplaceAll]);
   for i:=1 to length(fname) do
    if not (fname[i] in ['A'..'Z','a'..'z','0'..'9','-','_','.']) then fname[i]:='_';
   result:=fname; 
  end;

 function FileName(const fname:string):string;
  var
    i:integer;
  begin
   result:=fname;
   for i:=0 to high(fileNameRules) do
    result:=StringReplace(result,FileNameRules[i],FileNameRules[i],[rfIgnoreCase]);
   {$IFDEF MSWINDOWS}
   result:=StringReplace(result,'/','\',[rfReplaceAll]);
   {$ELSE}
   result:=StringReplace(result,'\','/',[rfReplaceAll]);
   {$ENDIF}
  end;

 procedure AddFileNameRule(const rule:string);
  begin
   AddString(fileNameRules,rule);
  end;

 function WaitForFile(fname:string;delayLimit:integer;exists:boolean=true):boolean;
  var
   t:int64;
  begin
   result:=true;
   t:=MyTickCount+delayLimit;
   repeat
    if FileExists(fname)=exists then exit;
    sleep(1);
   until MyTickCount>t;
   result:=false;
  end;

 function GetFileSize(fname:string):int64;
  {$IFDEF MSWINDOWS}
  var
   openbuff:TOFSTRUCT;
   h:HFile;
   data:array[0..1] of cardinal;
  begin
   result:=-1;
   try
    h:=OpenFile(PChar(fname),openBuff,0);
    if h=HFILE_ERROR then exit;
    data[0]:=windows.GetFileSize(h,@data[1]);
    move(data,result,8);
    CloseHandle(h);
   except
   end;
  end;
  {$ELSE}
  var
   f:file;
   fmode:integer;
  begin
   result:=-1;
   try
   assign(f,fname);
   fmode:=filemode;
   filemode:=1;
   reset(f,1);
   filemode:=fmode;
   result:=filesize(f);
   close(f);
   except
   end;
  end;
  {$ENDIF}

 function MyFileExists(fname:string):boolean; // Cross-platform version
  begin
   {$IFDEF ANDROID}
   result:=AndroidFileExists(fname);
   if not result then result:=result or FileExists(fname);
   {$ELSE}
   result:=FileExists(fname);
   {$ENDIF}
  end;

 function LoadFile(fname:string):string;
  var
   f:file;
  begin
   try
    {$IFDEF ANDROID}
    result:=AndroidLoadFile(fname);
    if result<>'' then exit;
    {$ENDIF}
    assignFile(f,fname);
    reset(f,1);
    SetLength(result,filesize(f));
    blockread(f,result[1],filesize(f));
    closefile(f);
   except
    on e:exception do
     raise EError.Create('Failed to load file '+fname+': '+ExceptionMsg(e));
   end;
  end;

 function LoadFile2(fname:string):ByteArray;
  var
    st:string;
  begin
   st:=LoadFile(fname);
   SetLength(result,length(st));
   move(st[1],result[0],length(st));
  end;

 procedure ReadFile;
  var
   f:file;
  begin
   assignFile(f,fname);
   reset(f,1);
   seek(f,posit);
   blockread(f,buf^,size);
   closefile(f);
  end;

 procedure WriteFile;
  var
   f:file;
   fm:integer;
  begin
   fm:=filemode;
   try
    filemode:=2;
   assignFile(f,fname);
   if FileExists(fname) then
    reset(f,1)
   else
    rewrite(f,1);
   seek(f,posit);
   blockwrite(f,buf^,size);
   closefile(f);
   finally
    filemode:=fm;
   end;
  end;

 procedure SaveFile(fname:string;buf:pointer;size:integer);
  var
   f:file;
   fm:integer;
  begin
   fm:=filemode;
   try
    filemode:=2;
   assignFile(f,fname);
   rewrite(f,1);
   if buf<>nil then blockwrite(f,buf^,size);
   closefile(f);
   finally
    filemode:=fm;
   end;
  end;

 procedure SaveFile(fname:string;buf:ByteArray); overload; // rewrite file with given data
  begin
   if length(buf)>0 then SaveFile(fname,@buf[0],length(buf));
  end;  

 procedure ShiftArray(const arr;sizeInBytes,shiftValue:integer);
  var
   sour,dest:PByte;
  begin
   sour:=@arr; dest:=@arr;
   if shiftValue>0 then begin
    inc(dest,shiftValue);
    move(sour^,dest^,sizeInBytes-shiftValue);
   end else begin
    inc(sour,shiftValue);
    move(sour^,dest^,sizeInBytes-shiftValue);
   end;
  end;  

 procedure StartMeasure;
  begin
   if (n<1) or (n>16) then exit;
   QueryPerformanceCounter(values[n]);
  end;

 function EndMeasure;
  var
   v:Int64;
  begin
   if (n<1) or (n>16) then exit;
   QueryPerformanceCounter(v);
   v:=v-values[n];
   result:=v*Perfkoef;
   if measures[n]=0 then
    PerformanceMeasures[n]:=v*Perfkoef
   else
    PerformanceMeasures[n]:=(PerformanceMeasures[n]*measures[n]+v*Perfkoef)/
       (measures[n]+1);
   inc(measures[n]);
  end;

 function EndMeasure2(n:integer):double;
  var
   v:Int64;
  begin
   if (n<1) or (n>16) then exit;
   QueryPerformanceCounter(v);
   v:=v-values[n];
   result:=v*Perfkoef;
   PerformanceMeasures[n]:=PerformanceMeasures[n]*0.9+result*0.1;
  end;

 function GetTaskPerformance;
  begin
   if (n<1) or (n>16) then exit;
   result:=PerformanceMeasures[n];
  end;

 procedure RunTimer;
  begin
   if (n<1) or (n>16) then exit;
   QueryPerformanceCounter(timers[n]);
  end;

 function GetTimer;
  var
   v:int64;
  begin
   result:=0;
   if (n<1) or (n>16) then exit;
   QueryPerformanceCounter(v);
   v:=v-timers[n];
   result:=(v*PerfKoef*10);
  end;

 function MyGetTime;
  var
   v:int64;
  begin
   QueryPerformanceCounter(v);
   result:=(v-StartTime)*PerfKoef*0.001;
  end;

 function MyGetTime2;
  var
   v:int64;
  begin
   QueryPerformanceCounter(v);
   result:=round((v-StartTime)*PerfKoef);
  end;

 function getcurtime;
 begin
  result:=cardinal(MyTickCount);
 end;

 function MyTickCount:int64;
  var
   t:cardinal;
  begin
   MyEnterCriticalSection(crSection); // ����� ����� ���� ����� � ���������� LastTickCount
   try
    {$IFDEF MSWINDOWS}
    t:=timeGetTime;
    {$ELSE}
    t:=CrossPlatform.GetTickCount;
    {$ENDIF}
    if t<lastTickCount and $FFFFFFFF then
     lastTickCount:=(lastTickCount and $0FFFFFFF00000000)+t+$100000000
    else
     lastTickCount:=(lastTickCount and $0FFFFFFF00000000)+t;
    result:=lastTickCount-startTimeMS+300000;
   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure TestSystemPerformance;
  type
   buf=array[0..255,0..255] of cardinal;
  var
   buffer:^buf;
   buf2:array[0..15] of double;
   t,i,j:integer;
   old:integer;
  begin
   {$IFDEF MSWINDOWS}
   new(buffer);
   old:=GetThreadPriority(GetCurrentThread);
   SetThreadPriority(GetCurrentThread,THREAD_PRIORITY_TIME_CRITICAL);
   t:=getTickCount+100;
   repeat
    for i:=0 to 255 do begin
     fillchar(buffer[i],1024,random(256));
     buf2[0]:=sqrt(random(10000)/(random(100)+1));
     buf2[1]:=sqrt(random(10000)/(random(100)+1));
     buf2[2]:=sqrt(random(10000)/(random(100)+1));
     buf2[3]:=sqrt(random(10000)/(random(100)+1));
    end;
    inc(Performance);
   until GetTickCount>t;
   SetThreadPriority(GetCurrentThread,old);
   dispose(buffer);
   {$ENDIF}
  end;

function GetCallStack:string;
var
 n,i:integer;
 adrs:array[1..4] of cardinal;
begin
 result:='';
 for i:=1 to 4 do adrs[i]:=0;
 {$IFDEF WIN32}
 asm
  pushad
  mov edx,ebp
  mov ecx,ebp
  add ecx,$100000 // �� ������� ���� ���� EBP+1Mb
  mov n,0
  lea edi,adrs
@01:
  mov eax,[edx+4]
  stosd
  mov edx,[edx]
  cmp edx,ebp
  jb @02
  cmp edx,ecx
  ja @02
  inc n
  cmp n,4
  jne @01
@02:
  popad
 end;
 for i:=n downto 1 do begin
  if adrs[i]=0 then continue;
  result:=result+inttohex(adrs[i],8);
  if i>1 then result:=result+'->';
 end;
{$ENDIF}
end;

function GetCaller:pointer;
{$IFDEF CPU386}
asm
 mov eax,[ebp+4]
end;
{$ELSE}
begin
 result:=pointer($FFFFFFFF);
end;
{$ENDIF}

{ TBaseException }
constructor TBaseException.Create(const msg: string);
var
 stack:string;
 n,i:integer;
 adrs:array[1..6] of cardinal;
begin
 {$IFDEF WIN32}
 asm
  pushad
  mov edx,ebp
  mov ecx,ebp
  add ecx,$100000 // �� ������� ���� ���� EBP+1Mb
  mov n,0
  lea edi,adrs
@01:
  mov eax,[edx+4]
  stosd
  mov edx,[edx]
  cmp edx,ebp
  jb @02
  cmp edx,ecx
  ja @02
  inc n
  cmp n,3
  jne @01
@02:
  popad
 end;
 stack:='[';
 for i:=n downto 1 do begin
  stack:=stack+inttohex(adrs[i],8);
  if i>1 then stack:=stack+'->';
 end;
 inherited create(stack+'] '+msg);
 asm
  mov edx,[ebp+4]
  mov eax,self
  mov [eax].FAddress,edx
 end;
 {$ELSE}
 inherited create(msg+' caller: '+inttohex(cardinal(get_caller_addr(get_frame)),8));
 {$ENDIF}
end;

procedure InitCritSect(var cr:TMyCriticalSection;name:string;level:integer=100); //
 begin
  MyEnterCriticalSection(crSection);
  try
  {$IFDEF MSWINDOWS}
   InitializeCriticalSection(cr.crs);
  {$ELSE}
   InitCriticalSection(cr.crs);
  {$ENDIF}
   cr.name:=name;
   cr.caller:=0;
   cr.time:=0;
   cr.lockCount:=0;
   cr.level:=level;
   if crSectCount<length(crSections) then begin
    crSections[crSectCount+1]:=@cr;
    inc(crSectCount);
   end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure DeleteCritSect(var cr:TMyCriticalSection);
 var
  i:integer;
 begin
  MyEnterCriticalSection(crSection);
  try
   for i:=1 to crSectCount do
    if crSections[i]=@cr then begin
     crSections[i]:=crSections[crSectCount];
     dec(crSectCount);
    end;
   {$IFDEF MSWINDOWS}
   DeleteCriticalSection(cr.crs);
   {$ELSE}
   DoneCriticalSection(cr.crs);
   {$ENDIF}
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure EnterCriticalSection(var cr:TMyCriticalSection;caller:pointer=nil);
 var
  threadID:cardinal;
  i,lastLevel,trIdx:integer;
  prevSection:PCriticalSection;
 begin
  {$IFDEF MSWINDOWS}
  {$IFDEF CPU386}
  if cr.caller=0 then
   if caller=nil then caller:=GetCaller;
  {$ENDIF}
  if cr.lockCount>0 then begin
   threadID:=GetCurrentThreadID;
   trIdx:=-1;
   if threadID<>cr.crs.OwningThread then begin // from different thread?
    cr.thread:=threadID;
    cr.caller:=PtrUInt(caller);
   end;
   if cr.time=0 then cr.time:=MyTickCount+5000;
  end else // first attempt
  if debugCriticalSections then begin
   MyEnterCriticalSection(crSection);
   threadID:=GetCurrentThreadID;
   trIdx:=0; prevSection:=nil;
   for i:=1 to high(threads) do
    if threads[i].ID=threadID then begin
     trIdx:=i;
     prevSection:=threads[i].lastCS;
     if prevSection<>nil then lastLevel:=prevSection.level
      else lastLevel:=0;
     break;
    end;
   MyLeaveCriticalSection(crSection);
   if trIdx=0 then raise EFatalError.Create('Trying to enter CS '+cr.name+' from unregistered thread');
   if cr.level<=lastLevel then
    raise EFatalError.Create(Format('Trying to enter CS %s with level %d within section %s with level %d',
      [cr.name,cr.level,prevSection.name,lastLevel]));
  end;

  windows.EnterCriticalSection(cr.crs);
  cr.caller:=0;
  cr.thread:=0;
  cr.time:=0;
  inc(cr.lockCount);
  if caller=nil then caller:=GetCaller;
  cr.owner:=cardinal(caller);
  if debugCriticalSections and (cr.lockCount=1) then begin
   MyEnterCriticalSection(crSection);
   for i:=1 to high(threads) do
    if threads[i].ID=threadID then begin
     cr.prevSection:=threads[i].lastCS;
     threads[i].lastCS:=@cr;
     break;
    end;
   MyLeaveCriticalSection(crSection);
  end;
  {$ELSE}
{  if cr.caller=0 then cr.caller:=cardinal(get_caller_addr(get_frame));
  cr.thread:=cardinal(GetCurrentThreadID);}
  system.EnterCriticalSection(cr.crs);
  inc(cr.lockCount);
{  cr.thread:=0;
  cr.caller:=0;
  cr.owner:=cardinal(get_caller_addr(get_frame));}
  {$ENDIF}
 end;

procedure LeaveCriticalSection(var cr:TMyCriticalSection);
 var
  i:integer;
  threadID:cardinal;
 begin
  ASSERT(cr.LockCount>0);
  cr.caller:=0;
  cr.owner:=0;
  dec(cr.lockCount);
  if debugCriticalSections and (cr.lockCount=0) then begin
   MyEnterCriticalSection(crSection);
   threadID:=GetCurrentThreadID;
   for i:=1 to high(threads) do
    if threads[i].ID=threadID then begin
     if threads[i].lastCS=nil then
      raise EError.Create('Leaving wrong CS: '+cr.name);
     if threads[i].lastCS<>@cr then
      raise EError.Create('Leaving wrong CS: '+cr.name+', should be '+threads[i].lastCS.name);
     threads[i].lastCS:=cr.prevSection;
     break;
    end;
   MyLeaveCriticalSection(crSection);
  end;
  {$IFDEF MSWINDOWS}
  windows.LeaveCriticalSection(cr.crs);
  {$ELSE}
  system.LeaveCriticalSection(cr.crs);
  {$ENDIF}
 end;

function GetNameOfThread(id:TThreadID):string;
 var
  i,c:integer;
 begin
  c:=trCount;
  for i:=1 to high(threads) do
   if cardinal(threads[i].ID)<>0 then
    if threads[i].ID=id then begin
     result:=threads[i].name;
     exit;
    end else begin
     dec(c);
     if c=0 then break;
    end;
  result:='unknown('+inttostr(cardinal(id))+')';
 end;

procedure SafeEnterCriticalSection(var cr:TMyCriticalSection); // ��������� ����� � ����������
 var
  i:integer;
  id,adr:cardinal;
 begin
  {$IFDEF MSWINDOWS}
  id:=GetCurrentThreadID;
  i:=0;
  {$IFDEF CPU386}
  asm
   mov edx,[ebp+offset cr]
   mov eax,[ebp+4]
   mov adr,eax
  end;
  {$ENDIF}
  cr.thread:=GetCurrentThreadID;
  cr.time:=MyTickCount+500;
  while (cr.crs.LockCount>=0) and (cr.crs.OwningThread<>id) do begin
   inc(i);
   if i=2 then ForceLogMessage('WARN! CRS '+cr.name+
    ' is owned by '+GetNameOfThread(cr.crs.owningThread)+' from '+inttohex(cr.caller,8)+
    ' acquiring from '+inttohex(adr,8)+' of '+GetNameOfThread(id));
   if i>30 then begin
    DumpCritSects;
    raise EFatalError.Create('Can''t enter critical section in time!');
   end;
   if i<10 then sleep(0) else sleep(1);
  end;
  if cr.caller=0 then cr.caller:=adr;
  windows.EnterCriticalSection(cr.crs);
  cr.caller:=0;
  cr.thread:=0;
  cr.time:=0;
  {$IFDEF CPU386}
  asm
   mov edx,[ebp+offset cr]
   mov eax,[ebp+4]
   mov TMyCriticalSection[edx].owner,eax
  end;
  {$ENDIF}
  {$ELSE}
  system.EnterCriticalSection(cr.crs);
  {$ENDIF}
 end;

procedure DumpCritSects; // ������� � ��� ��������� ���� ����������
 var
  i,j:integer;
  st:string;
 begin
  MyEnterCriticalSection(crSection);
  try
  st:='CRITICAL SECTIONS:';
  {$IFDEF MSWINDOWS}
  for i:=1 to crSectCount do begin
   st:=st+#13#10#32+inttostr(i)+') '+crSections[i].name+' ';
   if crSections[i].lockCount=0 then st:=st+'FREE' else begin
    st:=st+'LOCKED '+inttostr(crSections[i].crs.RecursionCount)+' AT: '+
     inttohex(crSections[i].owner,8)+' OWNED BY '+
     GetNameOfThread(crSections[i].crs.OwningThread);
    if crSections[i].caller<>0 then
     st:=st+' PENDING FROM '+GetNameOfThread(crSections[i].thread)+
      ' AT:'+inttohex(crSections[i].caller,8)+' time '+
      inttostr(MyTickCount-crSections[i].time);
   end;
  end;
  {$ENDIF}
  {$IFDEF IOS}
  for i:=1 to crSectCount do begin
   st:=st+#13#32+inttostr(i)+') '+crSections[i].name+' '+inttohex(crSections[i].status,4);
  end;
  {$ENDIF}
  finally
   MyLeaveCriticalSection(crSection);
  end;
  ForceLogMessage(st);
 end;

{$IFDEF MSWINDOWS}
function IsDebuggerPresent:Boolean; stdcall; external 'kernel32.dll';
{$ENDIF}

procedure CheckCritSections; // ��������� ����������� ������ �� �������
 var
  i,t:integer;
 begin
  {$IFDEF MSWINDOWS}
  if IsDebuggerPresent then exit; // prevent termination because of timeout during debug
  {$ENDIF}
  t:=MyTickCount;
  for i:=1 to crSectCount do begin
   if (crSections[i].time>0) and (crSections[i].time<t) and (crSections[i].time>t-1000000) then begin
    ForceLogMessage('Timeout for: '+crSections[i].name+' thread: '+GetThreadName);
    DumpCritSects;
    sleep(100);
    raise EFatalError.Create('Critical section timeout occured, see log');
   end;
  end;
 end;

procedure RegisterThread(name:string); // ���������������� �����
 var
  i:integer;
  threadID:cardinal;
 begin
  if trCount>=length(threads) then raise EError.Create('Threads array overflow');
  MyEnterCriticalSection(crSection);
  try
   threadID:=GetCurrentThreadId;
   for i:=1 to high(threads) do
    if cardinal(threads[i].ID)=threadID then exit; // already registered
   for i:=1 to high(threads) do
    if cardinal(threads[i].ID)=0 then begin
     fillchar(threads[i],sizeof(TThreadInfo),0);
     threads[i].ID:=threadID;
     threads[i].name:=name;
     threads[i].handle:={$IFDEF MSWINDOWS}GetCurrentThread{$ELSE}0{$ENDIF};
     threads[i].lastCS:=nil;
     inc(trCount);
     LogMessage('Thread ID:'+inttostr(cardinal(threads[i].ID))+' named '+name);
     {$IFDEF ANDROID}
     AndroidInitThread;
     {$ENDIF}
     break;
    end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure UnregisterThread; // ������� ����� (����� �������� ����� ����������� ������)
 var
  i:integer;
  id:TThreadID;
 begin
  if trCount=0 then raise EError.Create('No threads to unreg');
  id:=GetCurrentThreadID;
  MyEnterCriticalSection(crSection);
  try
   for i:=1 to high(threads) do
    if threads[i].ID=id then begin
     threads[i].ID:=0;
     dec(trCount);
     LogMessage('Thread '+threads[i].name+' unregistered');
     {$IFDEF ANDROID}
     AndroidDoneThread;
     {$ENDIF}
     break;
    end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

procedure PingThread; // �������� � "���������" ������
 var
  i,t:integer;
  id:TThreadID;
 begin
  t:=MyTickCount;
  id:=GetCurrentThreadID;
  MyEnterCriticalSection(crSection);
  try
   for i:=1 to high(threads) do
    if cardinal(threads[i].ID)<>0 then begin
     if threads[i].id=id then with threads[i] do begin
      inc(counter);
      if counter=1 then first:=t else at:=(at*7+(t-last)) div 8;
      last:=t;
     end else
      with threads[i] do begin
       if counter>10 then begin
//       avg:=(last-first) div (counter-1);
        if (t-last>at*2+300) and (t>lastreport+800) then begin
         ForceLogMessage('Thread '+name+' does not respond for '+inttostr(t-last));
         if (t-last>1500) then DumpCritSects;
         lastreport:=t;
        end;
       end;
      end;
    end;
  finally
   MyLeaveCriticalSection(crSection);
  end;
 end;

function GetThreadName(threadID:cardinal=0):string; // ������� ��� (0=��������) ������
 begin
  if threadID=0 then threadID:=GetCurrentThreadID;
  result:=GetNameOfThread(threadID);
 end;

{$IFDEF DELPHI}
type
 memBlock=record
  subcaller,caller,data:pointer;
  size:integer;
 end;
var
  memmgr:TMemoryManagerEx;
  blocks:array[0..4095] of memblock;

procedure RegisterBlock(d:pointer;size:integer);
 var
  i:integer;
  adrs:array[0..3] of pointer;
 begin
  asm
    mov edx,ebp
    lea ecx,adrs
    mov eax,[edx+4]
    mov [ecx],eax
    mov edx,[edx]
    add ecx,4
    mov eax,[edx+4]
    mov [ecx],eax
    mov edx,[edx]
    add ecx,4
    mov eax,[edx+4]
    mov [ecx],eax
  end;
  for i:=0 to 4095 do
   if blocks[i].data=nil then begin
    blocks[i].data:=d;
    blocks[i].caller:=adrs[1];
    blocks[i].subcaller:=adrs[2];
    blocks[i].size:=size;
    exit;
   end;
 end;
procedure UnregisterBlock(d:pointer);
 var
  i:integer;
 begin
   for i:=0 to 4095 do
     if blocks[i].data=d then begin
       blocks[i].data:=nil;
       exit;
     end;
 end;
procedure ChangeBlock(old,new:pointer;newsize:integer);
 var
  i:integer;
 begin
  for i:=0 to 4095 do
   if blocks[i].data=old then begin
    blocks[i].data:=new;
    blocks[i].size:=newsize;
    exit;
   end;
 end;
function DebugGetMem(size:integer):pointer;
 var
  c:pointer;
 begin
  result:=memmgr.GetMem(size);
  RegisterBlock(result,size);
 end;
function DebugFreeMem(p:pointer):integer;
 begin
  UnregisterBlock(p);
  result:=memmgr.FreeMem(p);
 end;
function DebugReallocMem(p:pointer;size:integer):pointer;
 begin
  result:=memMgr.ReallocMem(p,size);
  ChangeBlock(p,result,size);
 end;
function DebugAllocMem(size:cardinal):pointer;
 var
  c:pointer;
 begin
  result:=memmgr.AllocMem(size);
  registerBlock(result,size);
 end;

procedure StartMemoryLeaksTracking;
 var
  newmgr:TMemoryManagerEx;
 begin
  GetMemoryManager(memmgr);
  newmgr:=memmgr;
  newmgr.GetMem:=debugGetMem;
  newmgr.FreeMem:=debugFreeMem;
  newmgr.AllocMem:=debugAllocMem;
  newmgr.ReallocMem:=DebugReallocMem;
  SetMemoryManager(newmgr);
 end;
procedure StopMemoryLeaksTracking;
 var
  f:text;
  i:integer;
 begin
  SetMemoryManager(memmgr);
  assign(f,'mem.txt');
  rewrite(f);
  for i:=0 to 4095 do
    if blocks[i].data<>nil then
      writeln(f,inttoHex(cardinal(blocks[i].subcaller),8)+'->'+
         inttoHex(cardinal(blocks[i].caller),8)+': '+
         inttoHex(cardinal(blocks[i].data),8),
         blocks[i].size:9);
  close(f);
 end;
{$ENDIF}

var
 v:Int64;

{ TLogThread }

procedure TLogThread.Execute;
var
 tick:cardinal;
begin
 tick:=0;
 repeat
  inc(tick);
  sleep(10);
  if (length(cacheBuf)>20000) or (tick mod 50=0) then
   FlushLog;
 until terminated;
end;

procedure StopLogThread;
 begin
  logThread.terminate;
 end;

procedure DisableDEP;
{$IFDEF MSWINDOWS}
 var
  lib:HModule;
  func:function(flags:word):boolean; stdcall;
 begin
  lib:=LoadLibrary('kernel32.dll');
  func:=GetProcAddress(lib,'SetProcessDEPPolicy');
  if @func<>nil then
   func(0);
 end;
{$ELSE}
 begin

 end;
{$ENDIF}

procedure TMyCriticalSection.Enter; // for compatibility
 begin
  EnterCriticalSection(self);
 end;

procedure TMyCriticalSection.Leave; // for compatibility
 begin
  LeaveCriticalSection(self);
 end;

function HasParam(name:string):boolean;
 var
  i:integer;
 begin
  result:=false;
  for i:=1 to ParamCount do
   if CompareText(name,paramStr(i))=0 then begin
    result:=true; exit;
   end;
 end;

function GetParam(name:string):string;
 var
  i,p:integer;
  st:string;
 begin
  result:='';
  for i:=1 to ParamCount do begin
   st:=ParamStr(i);
   p:=pos('=',st);
   if p=0 then continue;
   if CompareText(name,copy(st,1,p-1))<>0 then continue;
   result:=copy(st,p+1,length(st));
   exit;
  end;
 end;

initialization
 QueryPerformanceFrequency(v);
 if v<>0 then
  PerfKoef:=1000/v
 else PerfKoef:=0;
 QueryPerformanceCounter(StartTime);
 {$IFDEF MSWINDOWS}
 InitializeCriticalSection(crSection);
 startTimeMS:=timeGetTime;
// timeBeginPeriod(1);
 {$ELSE}
 InitCriticalSection(crSection);
 startTimeMS:=CrossPlatform.GetTickCount;
 {$ENDIF}
 startTime:=MyTickCount;
finalization
 {$IFDEF MSWINDOWS}
 DeleteCriticalSection(crSection);
// timeEndPeriod(1);
 {$ELSE}
 DoneCriticalSection(crSection);
 {$ENDIF}

{$IFNDEF FPC}
{$IFNDEF DELPHI}
For Delphi - define global symbol "DELPHI"!
{$ENDIF}
{$ENDIF}
end.

