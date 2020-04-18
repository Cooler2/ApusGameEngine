// Collection of auxiliary functions and types (like SysUtils)
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)


{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
{$IFDEF IOS}{$modeswitch objectivec1}{$ENDIF}
{$IFNDEF FPC}{$IFNDEF DELPHI}
For Delphi - please define global symbol "DELPHI"!
{$ENDIF}{$ENDIF}
{$IFDEF CPUX64} {$DEFINE CPU64} {$ENDIF}
{$IFDEF UNICODE} {$DEFINE ADDANSI} {$ENDIF} // Make separate implementations for String and AnsiString types

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
  // 8-bit string type (assuming UTF-8 encoding)
  String8=UTF8String;
  // 16-bit string type (can be UTF-16 or UCS-2)
  {$IFDEF UNICODE}
  String16=UnicodeString;
  {$ELSE}
  String16=WideString;
  {$ENDIF}

  // String arrays
  AStringArr=array of String8;
  WStringArr=array of String16;
  StringArr=array of string; // depends on UNICODE mode

  {$IF DEclared(TBytes)}
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

  // 8-bit strings encodings
  TTextEncoding=(teUnknown,teANSI,teWin1251,teUTF8);

  // Critical section wrapper: provides better debug info
  PCriticalSection=^TMyCriticalSection;
  TMyCriticalSection=packed record
   crs:TRTLCriticalSection;
   name:string;      // имя секции
   caller:cardinal;  // точка, из которой была попытка завладеть секцией
   owner:cardinal;   // точка, из которой произошел удачный захват секции
   thread:cardinal;  // нить, пытающаяся захватить секцию
   time:int64;       // время наступления таймаута захвата
   lockCount:integer; // how many times locked (recursion)
   level:integer;     // it's not allowed to enter section with lower level from section with higher level
   prevSection:PCriticalSection;
   procedure Enter; inline; // for compatibility
   procedure Leave; inline; // for compatibility
  end;

  {$IF Declared(SRWLOCK)}
  TSRWLock=packed record
   lock:SRWLock;
   name:string;
   procedure Init(name:string);
   procedure StartRead;
   procedure FinishRead;
   procedure StartWrite;
   procedure FinishWrite;
  end;
  {$ENDIF}

  // Base exception with stack trace support
  TBaseException=class(Exception)
   private
    FAddress:cardinal;
   public
    constructor Create(const msg:string);
    property Address:cardinal read FAddress;
  end;

  // Предупреждения следует вызывать в ситуациях, когда нужно
  // привлечь внимание к ненормальной ситуации, которая впрочем не
  // мешает продолжать нормальную работу, никаких дополнительных действий от
  // верхнего уровня не требуется
  // (например: процедура не смогла отработать, но это не нарушает работу верхнего уровня)
  EWarning=class(TBaseException);

  // Обычная ошибка - ситуация, когда выполнение программы явно нарушено
  // и продолжение работы возможно только если верхний уровень обработает ошибку и примет меры
  // (например: функция не смогла выполнить требуемые действия и не вернула результат. Очевидно,
  // что нормальное продолжение возможно только если верхний уровень откажется от использования результата)
  EError=class(TBaseException);

  // Фатальная ошибка - продолжение работы невозможно, верхний уровень обязан инициировать
  // завершение выполнения программы. Это исключение следует использовать тогда, когда
  // ошибка не может быть исправлена верхним уровнем
  // (например: обнаружено что-то, чего быть никак не может, т.е. результат повреждения
  // данных или ошибки в алгоритме, ведущей к принципиально неправильной работе. Чтобы
  // избежать возможной порчи данных при последующих вызовах, следует немедленно прекратить работу)
  EFatalError=class(TBaseException);

  // Spline function: f(x0)=y0, f(x1)=y1, f(x)=?
  TSplineFunc=function(x,x0,x1,y0,y1:single):single;

  TSortableObject=class
   function Compare(obj:TSortableObject):integer; virtual; // Stub
  end;

  PSortableObject=^TSortableObject;
  TSortableObjects=array of TSortableObject;
  PSortableObjects=^TSortableObjects;

  // Режимы работы с лог-файлом
  TLogModes=(lmSilent,   // никакие сообщения не выводятся в лог
             lmForced,   // выводятся только forced-собщения
             lmNormal,   // выводятся только forced-собщения и сообщения без групп (default)
             lmVerbose); // выводятся все сообщения
 var
  fileSysError:integer=0;  // last error
  windowHandle:cardinal=0; // handle for messages, can be 0
  logGroups:array[1..30] of boolean;
  logStartDate:TDateTime;
  logErrorCount:integer;

  performance:integer; // производительности системы

  // проверяет уровни вложенного захвата критсекций на корректность
  // this slows down critical sectiond - so use carefuly
  debugCriticalSections:boolean=false;

 // Возвращает e.message вместе с адресом ошибки
 function ExceptionMsg(const e:Exception):string;
 // Raise exception with "Not implemented" message
 procedure NotImplemented(msg:string='');
 function GetCallStack:string;
 function GetCaller:pointer;

 // Проверяет наличие параметра (non case-sensitive) в командной строке
 function HasParam(name:string):boolean;
 // Возвращает значение параметра из командной строки (формат name=value),
 // если параметр отсутствует - пустая строка
 function GetParam(name:string):string;

 // Функции, показывающие сообщения (Windows)
 // -------------------------------
 function ShowMessage(text,caption:string):integer;
 function AskYesNo(text,caption:string):boolean;
 procedure ErrorMessage(text:string);

 // Поцедуры для работы с лог-файлом
 // --------------------------------
 procedure UseLogFile(name:string;keepOpened:boolean=false); // Specify log name
 procedure SetLogMode(mode:TLogModes;groups:string=''); //
 procedure LogPhrase(text:string); // without CR
 procedure LogMessage(text:string;group:byte=0); overload; // with CR
 procedure LogMessage(text:string;params:array of const;group:byte=0); overload;
 procedure LogError(text:string);
 procedure ForceLogMessage(text:string); // то же самое, но с более высоким приоритетом
 procedure DebugMessage(text:string); // альтернативное имя для ForceLogMessage (для удобства поиска по коду)
 procedure LogCacheMode(enable:boolean;enforceCache:boolean=false;runThread:boolean=false);
 procedure FlushLog; // сбросить накопенное в кэше содержимое в лог
 procedure StopLogThread; // Завершение потока сброса лога
 procedure SystemLogMessage(text:string); // Post message to OS log

 // Полезные высокоуровневые функции для работы с файловой системой
 // ---------------------------------------------------------------
 function FindFile(name,path:string):string; // Найти файл начиная с указанного пути
 function FindDir(name,path:string):string;  // То же самое, но ищется каталог
 function CopyDir(sour,dest:string):boolean; // Скопировать каталог со всем содержимым
 function MoveDir(sour,dest:string):boolean; // перенести каталог со всем содержимым
 function DeleteDir(path:string):boolean;    // Удалить каталог со всем содержимым
 procedure DumpDir(path:string);             // Log directory content (file names)

 // Файловые функции
 // -------------------------------
 function SafeFileName(fname:string):string; // Replace all unsafe characters with '_'
 function FileName(const fname:string):string; // исправление разделителей пути и применение case-правил
 procedure AddFileNameRule(const rule:string); // Добавить case-правило (например, правило "MyFile" превращает строки myFiLe или myfile в "MyFile")
 function GetFileSize(fname:String8):int64;
 function WaitForFile(fname:String;delayLimit:integer;exists:boolean=true):boolean; // Подождать (не дольше delayLimit) до появления (или удаления) файла, возвращает false если не дождались
 function MyFileExists(fname:String):boolean; // Cross-platform version
 procedure MakeBakFile(fname:string); // Rename xxx.yyy to xxx.bak, delete old xxx.bak if any
 function LoadFileAsString(fname:String):String8; // Load file content into string
 function LoadFileAsBytes(fname:String):ByteArray; // Load file content into byte array
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

 // Высокоточное измерение производительности участков кода (в мс)
 // -------------------------------------------------------
 // Измеряемый код нужно заключить в скобки
 // StartMeasure(n) ... EndMeasure(n);
 // Это может исполняться как один раз, так и много раз
 // GetTaskPerformance - среднее время выполнения участка (в мс.)
 procedure StartMeasure(n:integer);
 function EndMeasure(n:integer):double;
 // аналогично, но результат не усредняется за весь период, а просто сглаживается
 function EndMeasure2(n:integer):double;
 function  GetTaskPerformance(n:integer):double;
 procedure RunTimer(n:integer);
 function GetTimer(n:integer):double;

 function GetUTCTime:TSystemTime;
 function MyTickCount:int64; // Аналог GetTickCount, но без переполнения (больше не использует GetTickCount из-за недостаточной точности)

 // Функции для работы с массивами
 // ------------------------------
 // Shift array/data pointed by ptr by shiftValue bytes (positive - right, negative - left)
 procedure ShiftArray(const arr;sizeInBytes,shiftValue:integer);

 // Возвращает строку с описанием распределения памяти
 function GetMemoryState:string;

 // Возвращает объем выделенной памяти
 function GetMemoryAllocated:int64;


 // Функции для работы с массивами
 // ------------------------------
 // Add (insert) string into array, returns its index
 function AddString(var sa:StringArr;const st:string;index:integer=-1):integer; overload;
 function AddString(var sa:WStringArr;const st:WideString;index:integer=-1):integer; overload;
 // Delete string from array
 procedure RemoveString(var sa:StringArr;index:integer); overload;
 procedure RemoveString(var sa:WStringArr;index:integer); overload;
 // Ищет строку в массиве, возвращает её индекс либо -1
 function FindString(var sa:StringArr;st:string;ignoreCase:boolean=false):integer;
 // Ищет число в массиве, возвращает его индекс либо -1
 function FindInteger(var a:IntArray;v:integer):integer;
 // Вставляет (добавляет) число в массив чисел
 function AddInteger(var a:IntArray;v:integer;index:integer=-1):integer;
 // Удаляет элемент из массива
 procedure RemoveInteger(var a:IntArray;index:integer;keepOrder:boolean=false);
 // Вставляет (добавляет) число в массив чисел
 function AddFloat(var a:FloatArray;v:double;index:integer=-1):integer;
 // Удаляет элемент из массива
 procedure RemoveFloat(var a:FloatArray;index:integer;keepOrder:boolean=false);

 // Возвращает список чисел массива (через запятую)
 function ArrayToStr(a:array of integer;divider:char=','):string;
 // Формирует массив из строки чисел (через запятую)
 function StrToArray(st:string;divider:char=','):IntArray;

 // Функции для работы со строками
 // ------------------------------
 // Выделить из строки все подстроки, разделенные данным разделителем
 // Двойное включение двойных кавычечных символов влечет включение символа в строку.
 function Split(divider,st:string;quotes:char):StringArr; overload;
 // Разделяет строку на подстроки без каких-либо потерь
 function Split(divider,st:string):StringArr; overload;
 function SplitA(divider,st:String8):AStringArr;
 function SplitW(divider,st:WideString):WStringArr;
 // Search for a substring from specified point
 function PosFrom(substr,str:string;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
 function PosFrom(substr,str:WideString;minIndex:integer=1;ignoreCase:boolean=false):integer; overload;
 function LastPos(substr,str:String8;ignoreCase:boolean=false):integer; overload;
 // Extract substring "prefix|xxx|suffix"
 function ExtractStr(str,prefix,suffix:string;out prefIndex:integer):string;
 // Basic uppercase
 function UpperCaseA(st:String8):String8;
 // Ignore case
 function SameChar(a,b:AnsiChar):boolean;

 // Склеивает подстроки в одну строку с использованием разделителя divider
 // Если разделитель присутствует в подстроках, то они берутся в кавычки с
 // выполнением соответствующей подстановки
 function Combine(strings:stringarr;divider:string;quotes:char):string;

 // Соединяет подстроки в одну строку используя символ-разделитель divider
 // Если разделитель встречается в строках, то он удваивается
 function Join(strings:StringArr;divider:string):string; overload;

 // Соединяет подстроки в одну строку используя символ-разделитель divider
 // Если разделитель встречается в строках, то он удваивается
 function Join(strings:AStringArr;divider:String8):String8; overload;

 // Соединяет значения (преобразованные из исходных типов в строковый вид) указанным разделителем
 function Join(items:array of const;divider:string):string; overload;

 // Проверяет, начинается ли строка st с подстроки
 function HasPrefix(st,prefix:string):boolean; overload;
 function HasPrefix(st,prefix:String8;ignoreCase:boolean=false):boolean; overload;

 // Возвращает строку из массива с проверкой корректности индекса (иначе - пустую строку)
 function SafeStrItem(sa:StringArr;idx:integer):string;

 // Заключить строку в кавычки (используя удваивание), если
 // force = false, то не заключать если в строке нет пробельных символов
 function QuoteStr(const st:string;force:boolean=false;quotes:char='"'):string;

 // Раскодировать строку, заключенную в кавычки
 function UnQuoteStr(const st:string;quotes:char='"'):string; overload;
 {$IFDEF ADDANSI}
 function UnQuoteStr(const st:String8;quotes:AnsiChar='"'):String8; overload; {$ENDIF}

 // Заменяет \n \t и т.д. на соответствующие символы (а также \\ на \)
 function Unescape(st:String8):String8;
 // Escape all characters #0/#1/CR/LF/TAB/'\'
 function Escape(st:String8):String8;

 // Убрать пробельные символы в начале и в конце
 function Chop(st:string):string; overload;
 {$IFDEF ADDANSI}
 function Chop(st:String8):String8; overload; {$ENDIF}

 // Возвращает последний символ строки (#0 если строка пустая)
 function LastChar(st:string):char; overload;
 {$IFDEF ADDANSI}
 function LastChar(st:String8):AnsiChar; overload; {$ENDIF}

 // Safe string indexing
 function CharAt(st:string;index:integer):char;
 function WCharAt(st:WideString;index:integer):WideChar;

 // заменяет служебные символы в строке таким образом, чтобы её можно было вставить в HTML
 function HTMLString(st:string):string; overload;
 {$IFDEF ADDANSI}
 function HTMLString(st:String8):String8; overload; {$ENDIF}

 // Закодировать URL согласно требованиям HTTP
 function UrlEncode(st:String8):String8;
 // Раскодировать URL согласно требованиям HTTP
 function UrlDecode(st:String8):String8;
 // Кодирует url из UTF8 в нормальный ASCII вид !!! WARNING! ОЧЕНЬ странная ф-ция - ХЗ начем она вообще нужна!
 function URLEncodeUTF8(st:String8):String8;

 // Закодировать двоичные данные в строку (this is NOT Base64!)
 function EncodeB64(data:pointer;size:integer):String8;
 // Раскодировать данные из строки
 procedure DecodeB64(st:String8;buf:pointer;var size:integer);
 // Переводит строку к печатаемому варианту (заменяет спецсимволы), операция необратима!
 function PrintableStr(st:String8):String8;
 // Закодировать строку в виде HEX
 function EncodeHex(st:String8):String8; overload;
 // Закодировать в HEX произвольные бинарные данные
 function EncodeHex(data:pointer;size:integer):String8; overload;
 function DecodeHex(hexStr:String8):String8; overload;
 procedure DecodeHex(st:String8;buf:pointer); overload;

 function IsZeroMem(buf:pointer;size:integer):boolean;

 // Простейшее шифрование/дешифрование (simple XOR)
 procedure SimpleEncrypt(var data;size,code:integer);
 procedure SimpleEncrypt2(var data;size,code:integer);

 // Простое сжатие (simplified LZ method, works good only for texts or similar strings)
 function SimpleCompress(data:String8):String8;
 function SimpleDecompress(data:String8):String8;

 // Простое сжатие методом RLE
 function PackRLE(buf:pointer;size:integer;addHeader:boolean=true):ByteArray;
 function UnpackRLE(buf:pointer;size:integer):ByteArray;
 function CheckRLEHeader(buf:pointer;size:integer):integer; // -1 - no header

 // Сравнить два куска памяти и создать патч с набором изменений в sour по сравнению с dest
 function CreateDiffPatch(sour,dest:pointer;size:integer):ByteArray;

 // Применить патч. После применения dest приводится к состоянию sour
 procedure ApplyDiffPatch(data:pointer;size:integer;patch:pointer;patchSize:integer);

 // Преобразует дату из строки в формате DD.MM.YYYY HH:MM:SS (другие форматы тоже понимает и распознаёт)
 function ParseDate(st:String8;default:TDateTime=0):TDateTime;
 function GetDateFromStr(st:String8;default:TDateTime=0):TDateTime; // alias for compatibility
 function ParseTime(st:String8;default:TDateTime=0):TDateTime;
 // Возвращает строку с разницей между указанным временем и текущим моментом (сколько времени прошло с указанного момента)
 // Если указанный момент ещё не наступил, то первым символом будет +
 function HowLong(time:TDateTime):string;

 // UTF8 routines
 function IsUTF8(st:String8):boolean; inline; // Check if string starts with BOM
 function EncodeUTF8(st:String16;addBOM:boolean=false):String8; overload;
 procedure EncodeUTF8(st:String16;var dest:string); overload;
 procedure EncodeUTF8(st:String16;var dest:String8); overload;
 function UStr(st:String16):string; // Convert 16-bit string to the default string type (utf8 or utf16)
 function WStr(st:string):string16; // Convert default string to the 16-bit string

 function DecodeUTF8(st:String8):String16; overload;
 function DecodeUTF8(st:String16):String16; overload; // Does nothing
 function DecodeUTF8A(sa:AStringArr):WStringArr; overload;
 function DecodeUTF8A(sa:StringArr):WStringArr; overload;
 function UTF8toWin1251(st:String8):String8;
 function Win1251toUTF8(st:String8):String8;
 function UpperCaseUtf8(st:String8):String8;
 function LowerCaseUtf8(st:String8):String8;
 // UTF-16 routines (Unicode)
 function UnicodeTo(st:WideString;encoding:TTextEncoding):String8;
 function UnicodeFrom(st:String8;encoding:TTextEncoding):WideString;

// function CopyUTF8(S:string; Index:Integer; Count:Integer):string; // analog of Copy which works with UTF8

 // Функции для вычисления полезных "ломаных" и сплайновых функций
 // -----------------------------------------------------------------
 // Вернуть "насыщенное" значение, т.е. привести b внутрь допустимого диапазона [min..max]
 function Sat(b,min,max:integer):integer; deprecated;
 function SatD(b,min,max:double):double; deprecated;
 function Clamp(b,min,max:integer):integer; overload; // alias
 function Clamp(b,min,max:double):double; overload; // alias

 // Вычислить ломаную функцию, определенную на отрезке [0..256] имеющую пик (экстремум)
 // в точке arg и принимающую значения a, b и c (a и c - на концах отрезка, b - в экстремуме)
 function Pike(x,arg,a,b,c:integer):integer;
 function PikeD(x,arg,a,b,c:double):double; // [0..1] range

 // Квадратичный сплайн на отрезке [0..1] принимающий значения a,b,c в точках 0, 0.5, 1 и ограниченный диапазоном байта
 function SatSpline(x:single;a,b,c:integer):byte;
 // Кубический сплайн на отрезке [0..1] принимающий значения a,b,c,d в точках 0, 0.33, 0.66, 1 и ограниченный диапазоном байта
 function SatSpline3(x:single;a,b,c,d:integer):byte;

 // Вычислить сплайн (аргумент - от 0 до 1, v0,v1 - значения на концах,
 //   k0,k1 - касательные на концах (0 - горизонталь), v - вес деления (0..1, 0.5 - среднее)
 function Spline(x:double;v0,k0,v1,k1:double;v:double=0.5):double;
 // некоторые полезные сплайны
 // линейная функция
 function Spline0(x,x0,x1,y0,y1:single):single;
 // ускорение, прямолинейное движение, замедление
 function Spline1(x,x0,x1,y0,y1:single):single;  // 25% - 50% - 25%
 function Spline1a(x,x0,x1,y0,y1:single):single; // 10% - 80% - 10%
 // движение с постоянным замедлением (парабола)
 function Spline2(x,x0,x1,y0,y1:single):single;
 function Spline2rev(x,x0,x1,y0,y1:single):single; // то же, но с постоянным ускорением
 // движение с ускорением и одинарным отскоком на 10% от начальной высоты
 function Spline3(x,x0,x1,y0,y1:single):single;
 // движение с "перелётом" на 15%
 function Spline4(x,x0,x1,y0,y1:single):single;
 // движение с "перелётом" на 30%
 function Spline4a(x,x0,x1,y0,y1:single):single;

 // Получить ближайшую степень двойки, не меньшую данного числа
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
 procedure Swap(var a,b:pointer); overload; inline;
 procedure Swap(var a,b:byte); overload; inline;
 procedure Swap(var a,b:single); overload; inline;
 procedure Swap(var a,b:string); overload; inline;
 {$IFDEF UNICODE}
 procedure Swap(var a,b:String8); overload; inline;
 {$ELSE}
 procedure Swap(var a,b:String16); overload; inline;
 {$ENDIF}
 procedure Swap(var a,b;size:integer); overload; inline;

 // Псевдослучайное число от arg в диапазоне 0..module-1
 function PseudoRand(arg,module:cardinal):cardinal;
 // возвращает случайное целое число из диапазона [v-1,v+1] так, что его матожидание равно v
 function RandomInt(v:single):integer;
 // Возвращает случайную строку заданной длины из алфаситно-цифровых символов
 function RandomStr(l:integer):string;

 // Функции для хранения двоичных данных в строковом виде
 //------------------------------------------------------
 function BinToStr(var buf;size:byte):string;
 function StrToBin(var buf;size:byte;st:string):integer;

 // Преобразование кодировок
 //---------------
 // Преобразование Windows-1251 <=> DOS 866
 function ConvertToWindows(ch:AnsiChar):AnsiChar;
 function ConvertFromWindows(ch:AnsiChar):AnsiChar;
 // Преобразование Windows-1251 <=> Unicode-16 (UTF-16)
 function ConvertWindowsToUnicode(ch:AnsiChar):widechar;
 function ConvertUnicodeToWindows(ch:WideChar):AnsiChar;

 // Преобразование типов данных
 // ---------------------------
 function HexToInt(st:string):int64; overload;  // Распознать шестнадцатиричное число
 {$IFDEF ADDANSI}
 function HexToInt(st:String8):int64; overload; {$ENDIF}
 function HexToAStr(v:int64;digits:integer=0):String8;
 function SizeToStr(size:int64):string; // строка с короткой записью размера, типа 15.3M
 function FormatTime(time:int64):string; // строка с временным интервалом (time - в ms)
 function FormatInt(int:int64):string; // строка с числом (пробел разделяет группы цифр)
 function FormatMoney(v:double;digits:integer=2):string; // строка с суммой денег (digits знаков после запятой)
 function PtrToStr(p:pointer):string; // Pointer to string
 function IpToStr(ip:cardinal):string; // IP-адрес в строку (младший байт - первый)
 function StrToIp(ip:string):cardinal; // Строка в IP-адрес (младший байт - первый)
 function VarToStr(v:TVarRec):UnicodeString;  // Variant -> String
 function VarToAStr(v:TVarRec):String8;
 function ParseInt(st:string):int64; inline; overload; // wrong characters ignored
 {$IFDEF ADDANSI}
 function ParseInt(st:String8):int64; inline; overload; {$ENDIF}
 function ParseFloat(st:string):double; inline; // always use '.' as separator - replacement for SysUtils version
 function ParseIntList(st:string):IntArray; // '123 4,-12;3/5' -> [1234,-12,3,5]
 function ParseBool(st:string):boolean; overload;
 {$IFDEF ADDANSI}
 function ParseBool(st:String8):boolean; overload; {$ENDIF}
 function BoolToAStr(b:boolean;short:boolean=true):String8;

 function ListIntegers(a:array of integer;separator:char=','):string; overload; // array of integer => 'a[1],a[2],...,a[n]'
 function ListIntegers(a:system.PInteger;count:integer;separator:char=','):string; overload;

 // Сортировки
 procedure SortObjects(obj:PSortableObjects;count:integer);
// procedure SortObjects(var obj:array of TObject;comparator:TObjComparator); overload;
 procedure SortStrings(var sa:StringArr); overload;
 procedure SortStrings(var sa:AStringArr); overload;
 procedure SortStrings(var sa:WStringArr); overload;
// function SelectUnique(const sa:WStringArr):WStringArr;

 // Data Dump
 // ---------
 // строка с шестнадцатиричным дампом буфера
 function HexDump(buf:pointer;size:integer):String8;
 // строка с десятичным дампом буфера
 function DecDump(buf:pointer;size:integer):String8;

 procedure TestSystemPerformance;

 // Вычисление контрольной суммы
 function CalcCheckSum(adr:pointer;size:integer):cardinal;
 function CheckSum64(adr:pointer;size:integer):int64; pascal;
 procedure FillRandom(var buf;size:integer);
 function StrHash(const st:string):cardinal; overload;
 {$IFDEF ADDANSI}
 function StrHash(const st:String8):cardinal; overload; {$ENDIF}

 // Текущее время и дата (GMT)
 function NowGMT:TDateTime;
 function TimeStamp:string;

 // Синхронизация и многопоточность
 // --------------------------------
 // level - используется только в отладочном режиме для проверки отсутствия циклов в графе захвата секций (чтобы гарантировать отсутствие блокировок)
 // Допускается входить в секцию с бОльшим уровнем будучи уже в секции с меньшим уровнем, но не наоборот.
 // Т.о. чем ниже уровень кода, тем ВЫШЕ должно быть значение level в секции, которой этот код оперирует
 procedure InitCritSect(var cr:TMyCriticalSection;name:string;level:integer=100); // Создать и зарегить критсекцию
 procedure DeleteCritSect(var cr:TMyCriticalSection);
 procedure EnterCriticalSection(var cr:TMyCriticalSection;caller:pointer=nil);
 procedure LeaveCriticalSection(var cr:TMyCriticalSection);
// procedure SafeEnterCriticalSection(var cr:TMyCriticalSection); // Осторожно войти в критсекцию
 procedure DumpCritSects; // Вывести в лог состояние всех критсекций
 procedure RegisterThread(name:string); // зарегистрировать поток
 procedure UnregisterThread; // удалить поток (нужно вызывать перед завершением потока)
// procedure DumpThreads; // Выдать
 procedure PingThread; // сообщить о "живучести" потока
 function GetThreadName(threadID:cardinal=0):string; // вернуть имя (0=текущего) потока

 procedure CheckCritSections; // проверить критические секции на таймаут

 // Disable Data Execution Prevention (Windows)
 procedure DisableDEP;

implementation
 uses Classes,math,CrossPlatform,StackTrace
    {$IFDEF MSWINDOWS},mmsystem{$ENDIF}
    {$IFDEF IOS},iphoneAll{$ENDIF}
    {$IFDEF ANDROID},dateutils,Android{$ENDIF};

 {$IFOPT R+}{$DEFINE RANGECHECK}{$ENDIF} // Used to disable range check when needed and restore it back
 const
  hexchar:shortstring='0123456789ABCDEF';
 type
  {$IFDEF MSWINDOWS}
  TThreadID=cardinal;
  {$ENDIF}
  TThreadInfo=record
   ID:TThreadID;
   name:string;
   counter:integer; // сколько раз отзывался
   first:integer;   // время первого отклика
   last:integer;    // время последнего отклика
   lastreport:integer; // время последнего сообщения о задержке
   at:integer;       // сглаженное примерное время между интервалами
   handle:THandle;
   lastCS:PCriticalSection; // последняя критсекция, захваченная в этом потоке
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
  cacheenabled,forceCacheUsage:boolean;  // forceCacheUsage - писать в кэш даже

  crSection:TRTLCriticalSection; // используется для доступа к глобальным переменным
  startTime,startTimeMS:int64;

  crSections:array[1..100] of PCriticalSection;
  crSectCount:integer=0;

  threads:array[0..100] of TThreadInfo;
//  buffer2:array[0..16384] of cardinal;
  trCount:integer; // записи могут быть не только в начале массива!!!

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
  perfKoef:double; // длительность одного тика в мс
  timers:array[1..16] of int64;

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
 procedure Swap(var a,b:pointer); overload; inline;
  var
   c:pointer;
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
 procedure Swap(var a,b:String8); overload; inline;
  var
   c:String8;
  begin
   c:=a; a:=b; b:=c;
  end;
 {$IFNDEF UNICODE}
 procedure Swap(var a,b:String16); overload; inline;
  var
   c:String16;
  begin
   c:=a; a:=b; b:=c;
  end;
 {$ENDIF}
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
    result[i]:=Char(c[1+random(62)]);
  end;

 function RealDump(buf:pointer;size:integer;hex:boolean):String8;
  var
   i:integer;
   pb:PByte;
   ascii:string[18];
  begin
   result:=''; pb:=buf; ascii:='';
   for i:=1 to size do begin
    if hex then
     result:=result+IntToHex(pb^,2)+' '
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


 function HexDump(buf:pointer;size:integer):String8;
  begin
   result:=RealDump(buf,size,true);
  end;

 function DecDump(buf:pointer;size:integer):String8;
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

 {$IFDEF ADDANSI}
 function StrHash(const st:String8):cardinal; overload;
  var
   i:integer;
  begin
   result:=0;
   for i:=1 to length(st) do
    result:=result*$20844 xor byte(st[i]);
  end;
 {$ENDIF}

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
 function Spline1(x,x0,x1,y0,y1:single):single; // 25-50-25 ускорение, движение, замедление
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   if x<0.25 then result:=2.666666*sqr(x) else
    if x>0.75 then result:=1-2.666666*sqr(1-x) else
     result:=1.333333*x-0.16666666;
   result:=y0+(y1-y0)*result;
  end;
 function Spline1a(x,x0,x1,y0,y1:single):single; // 10-80-10 ускорение, движение, замедление
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   if x<0.1 then result:=5.555556*sqr(x) else
    if x>0.9 then result:=1-5.555556*sqr(1-x) else
     result:=1.111111*x-0.0555556;
   result:=y0+(y1-y0)*result;
  end;
 function Spline2(x,x0,x1,y0,y1:single):single; // равномерное замедление
  begin
   x:=(x-x0)/(x1-x0);
   if x<0 then x:=0;
   if x>1 then x:=1;
   result:=1-sqr(1-x);
   result:=y0+(y1-y0)*result;
  end;
 function Spline2rev(x,x0,x1,y0,y1:single):single; // равномерное ускорение
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

 function HexCharToInt(ch:AnsiChar):integer; inline;
  begin
   result:=0;
   if ch in ['0'..'9'] then result:=ord(ch)-ord('0') else
   if ch in ['A'..'F'] then result:=ord(ch)-ord('A')+10 else
   if ch in ['a'..'f'] then result:=ord(ch)-ord('a')+10;
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
    result:=result+HexCharToInt(AnsiChar(st[i]))*v;
    v:=v*16;
   end;
  end;

 {$IFDEF ADDANSI}
 function HexToInt(st:String8):int64;
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
    result:=result+HexCharToInt(st[i])*v;
    v:=v*16;
   end;
  end;
 {$ENDIF}

function HexToAStr(v:int64;digits:integer=0):String8;
 var
  l:integer;
  vv:int64;
 begin
  vv:=v;
  if vv=0 then exit('0');
  l:=0;
  while vv<>0 do begin
   inc(l);
   vv:=vv shr 4;
  end;
  if l<digits then l:=digits;
  SetLength(result,l);
  while l>0 do begin
   result[l]:=hexchar[1+v and $F];
   v:=v shr 4;
   dec(l);
  end;
 end;

 function SizeToStr;
  var
   v:single;
  begin
   if size<1000 then exit(inttostr(size)+'b');
   v:=size/1024;
   if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'K');
   if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'K');
   if v<1000 then exit(inttostr(round(v))+'K');
   v:=v/1024;
   if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'M');
   if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'M');
   if v<1000 then exit(inttostr(round(v))+'M');
   v:=v/1024;
   if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'G');
   if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'G');
   if v<1000 then exit(inttostr(round(v))+'G');
   v:=v/1024;
   if v<10 then exit(FloatToStrF(v,ffFixed,4,2)+'T');
   if v<100 then exit(FloatToStrF(v,ffFixed,4,1)+'T');
   result:=inttostr(round(v))+'T';
  end;

 function FormatTime(time:int64):string; // строка с временным интервалом (time - в ms)
  begin
   if time<120000 then
    exit(IntToStr(time div 1000)+'.'+IntToStr(time mod 1000)+'s');
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
   result:=IntToHex(UIntPtr(p),12);
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

 function StrToIp(ip:string):cardinal; // Строка в IP-адрес
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

 function VarToStr(v:TVarRec):UnicodeString;
  begin
   case v.VType of
    vtInteger:result:=IntToStr(v.VInteger);
    vtBoolean:result:=BoolToStr(v.VBoolean,true);
    vtChar:result:=v.VChar;
    vtString:result:=ShortString(v.VString^);
    vtAnsiString:result:=DecodeUTF8(String8(v.VAnsiString));
    vtExtended:result:=FloatToStrF(v.vExtended^,ffGeneral,12,0);
    vtVariant:result:=v.VVariant^;
    vtWideChar:result:=v.VWideChar;
    vtWideString:result:=WideString(v.vWideString);
    vtInt64:result:=IntToStr(v.vInt64^);
    vtUnicodeString:result:=UnicodeString(v.VUnicodeString);
    else raise EWarning.Create('Incorrect variable type: '+inttostr(v.vtype));
   end;
  end;

 function VarToAStr(v:TVarRec):String8;
  begin
   case v.VType of
    vtInteger:result:=IntToStr(v.VInteger);
    vtBoolean:result:=BoolToAStr(v.VBoolean);
    vtChar:result:=v.VChar;
    vtString:result:=ShortString(v.VString^);
    vtAnsiString:result:=String8(v.VAnsiString);
    vtExtended:result:=FloatToStrF(v.vExtended^,ffGeneral,12,0);
    vtVariant:result:=v.VVariant^;
    vtWideChar:result:=v.VWideChar;
    vtWideString:result:=EncodeUTF8(WideString(v.vWideString));
    vtInt64:result:=IntToStr(v.vInt64^);
    vtUnicodeString:result:=EncodeUTF8(UnicodeString(v.VUnicodeString));
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

 {$IFDEF ADDANSI}
 function ParseInt(st:String8):int64;  // wrong characters ignored
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
 {$ENDIF}

 function ParseIntList(st:string):IntArray; // '123 4,-12;3/5' -> [1234,-12,3,5]
  var
   i,cnt:integer;
   neg:boolean;
  begin
   SetLength(result,length(st));
   cnt:=0;
   neg:=false;
   for i:=1 to length(st) do begin
    if (st[i]='-') and (result[cnt]=0) then begin
     neg:=true; continue;
    end;
    if st[i] in ['0'..'9'] then result[cnt]:=result[cnt]*10+(ord(st[i])-ord('0'))
    else
    if st[i]<=' ' then continue
    else begin
     if neg then result[cnt]:=-result[cnt];
     inc(cnt);
     neg:=false;
    end;
   end;
   if neg then result[cnt]:=-result[cnt];
   inc(cnt);
   SetLength(result,cnt);
  end;

 function ParseBool(st:string):boolean; overload;
  begin
   st:=UpperCase(st);
   result:=(st='Y') or (st='TRUE') or (st='1') or (st='-1') or (st='+');
  end;

 {$IFDEF ADDANSI}
 function ParseBool(st:String8):boolean; overload;
  begin
   st:=UpperCase(st);
   result:=(st='Y') or (st='TRUE') or (st='1') or (st='-1') or (st='+');
  end;
 {$ENDIF}

 function BoolToAStr(b:boolean;short:boolean=true):String8;
  begin
   if short then begin
    if b then result:='Y' else result:='N';
   end else begin
    if b then result:='TRUE' else result:='FALSE';
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

function SimpleCompress(data:String8):String8;
 var
  i,j,curpos,outpos,foundStart,foundLength,ofs,max:integer;
  res:String8;
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
     res[o]:=AnsiChar(byte(res[o]) or (1 shl (7-(outpos and 7))));
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
   // 1. Найти самую длинную подходящую цепочку
   foundStart:=0; foundLength:=0;
   b:=byte(data[curpos]);
   i:=last[b];
   while (i>0) and (i>curPos-4096) do begin
    // максимально возможная длина цепочки
    max:=length(data)-curPos+1; // сколько вообще осталось данных
    if max>20 then max:=20; // не более 20 байт за раз!
    if max>curPos-i then max:=curPos-i; // сколько известно данных
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

   // 2. Сохранить код
   if foundLength>0 then begin // цепочка найдена (смещение должно быть правильным)
    ofs:=curPos-foundStart-foundLength;
    if foundLength=1 then
     Output($10+ofs,6)
    else begin
     Output($FFFFFFE,foundLength);
     max:=foundLength*2+2;
     if max>12 then max:=12; // не более 12 бит на смещение
     Output(ofs,max);
    end;
   end else begin // не найдена
    Output(b,10);
    foundLength:=1;
   end;

   // 3. Обновить рабочие данные
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

function SimpleDecompress(data:String8):String8;
 var
  i,curpos,outpos,rsize,bCount,ofs,L,M:integer;
  res:String8;
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
   res[outpos]:=AnsiChar(v);
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

// Формат упакованных данных: 1b - длина (старший бит =0 - байты повторяющиеся, младшие 7 бит - длина цепочки)
// Имеет смысл упаковка цепочек из 3 и более повторяющихся байтов
function PackRLE(buf:pointer;size:integer;addHeader:boolean=true):ByteArray;
 var
  p,cur:integer;
  pb:PByte; // текущий просматриваемый байт
  start:PByte; // первый неупакованный байт
  cnt:integer; // сколько последних байт совпадают
  len:integer; // на сколько байт продвинулись вперед (len=pb-start)
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
   // ситуации, в которых необходимо что-то сделать:
   // - достигнут конец данных
   // - просмотрено много неупакованных байтов
   // - байт изменился, причем совпадающих байтов было не менее 3-х
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

// Формат потока:
// - если 1-й байт >$80, то 7 бит - кол-во следующих за ним байтов данных
// - иначе 7 бит + 8 бит следующего байта - это 15 бит смещение до начала следующего блока
function CreateDiffPatch(sour,dest:pointer;size:integer):ByteArray;
 var
  i,cnt,pos,sameCnt,diffCnt:integer;
  sp,dp:PByte;
  mode:integer;
 begin
  sp:=sour; dp:=dest;
  SetLength(result,size+4+size div 16);
  cnt:=0; // счётчик байт в выходном потоке
  pos:=0;
  sameCnt:=0; mode:=0; // поиск повторяющейся строки
  for i:=0 to size-1 do begin
   if mode=0 then begin
    if sp^<>dp^ then begin
     if sameCnt>=4 then begin
      // достаточно длинная цепочка для сохранения - сохраняем и переходим в режим 1
      result[cnt]:=sameCnt shr 8;
      result[cnt+1]:=sameCnt and $FF;
      inc(cnt,2);
      sameCnt:=0;
      mode:=1; diffCnt:=1;
     end else begin
      // недостаточно длинная цепочка для сохранения - переходим в режим 1 без сохранения
      diffCnt:=sameCnt+1; sameCnt:=0;
      mode:=1;
     end;
    end else begin
     // Байты совпадают - продолжаем
     inc(sameCnt);
     if sameCnt=32767 then begin
      // достигнут предел по длине
      result[cnt]:=$7F;
      result[cnt+1]:=$FF;
      inc(cnt,2);
      sameCnt:=0;
     end;
    end;
   end else begin
    // Режим 1: сканирование отличающихся данных
    inc(diffCnt);
    if diffCnt=127 then begin
     // достигнут предел по длине - сохраняем и переключаемся в режим 0
     result[cnt]:=$80+diffCnt;
     dec(sp,diffCnt-1);
     move(sp^,result[cnt+1],diffCnt);
     inc(sp,diffCnt-1);
     inc(cnt,128);
     mode:=0;
     diffCnt:=0;
     sameCnt:=0;
    end else begin
     if sp^<>dp^ then begin
      sameCnt:=0;
     end else begin
      // байты совпадают
      inc(sameCnt);
      if sameCnt>5 then begin
       // Много байт совпадает - пора сохранить и переключиться в режим 0
       result[cnt]:=$80+diffCnt-sameCnt;
       dec(sp,diffCnt-1);
       move(sp^,result[cnt+1],diffCnt-sameCnt);
       inc(sp,diffCnt-1);
       inc(cnt,1+diffCnt-sameCnt);
       diffCnt:=0;
       mode:=0;
      end;
     end;
    end;
   end;
   inc(sp); inc(dp);
  end;
  // финализация результата
  if mode=0 then begin
   result[cnt]:=sameCnt shr 8;
   result[cnt+1]:=sameCnt and $FF;
   inc(cnt,2);
  end else begin
   result[cnt]:=$80+diffCnt;
   dec(sp,diffCnt);
   move(sp^,result[cnt+1],diffCnt);
   inc(cnt,1+diffCnt);
  end;

  SetLength(result,cnt);
 end;

procedure ApplyDiffPatch(data:pointer;size:integer;patch:pointer;patchSize:integer);
 var
  pb,dp:PByte;
  ofs:integer;
 begin
  pb:=patch;
  dp:=data;
  while patchSize>0 do begin
   ofs:=pb^;
   if ofs and $80>0 then begin
    ofs:=ofs and $7F;
    inc(pb);
    dec(size,ofs);
    ASSERT(size>=0,'ADP: out of bounds');
    move(pb^,dp^,ofs);
    inc(pb,ofs);
    inc(dp,ofs);
    dec(patchSize,1+ofs);
   end else begin
    inc(pb);
    ofs:=ofs shl 8+pb^;
    inc(dp,ofs);
    dec(size,ofs);
    inc(pb);
    dec(patchSize,2);
    ASSERT(size>=0,'ADP: out of bounds');
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

 function PrintableStr(st:String8):String8;
  var
   i,max,p:integer;
  begin
   max:=length(st)*3;
   SetLength(result,max);
   p:=0;
   for i:=1 to length(st) do
    if st[i]<' ' then begin
     inc(p); result[p]:='#';
     inc(p); result[p]:=AnsiChar(hexchar[1+ord(st[i]) div 16]);
     inc(p); result[p]:=AnsiChar(hexchar[1+ord(st[i]) mod 16]);
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
     result:=result+AnsiChar(64+dest);
     dest:=0;
    end;
   end;
   if (size*8-1) mod 6<>5 then begin
    offset:=(length(result)+1)*6-size*8;
    result:=result+AnsiChar(64+dest shl offset);
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

 function EncodeHex(st:String8):String8;
  var
   i:integer;
   b:byte;
  begin
   SetLength(result,length(st)*2);
   for i:=1 to length(st) do begin
    b:=byte(st[i]);
    result[i*2-1]:=AnsiChar(hexchar[1+b shr 4]);
    result[i*2]:=AnsiChar(hexchar[1+b and 15]);
   end;
  end;

 function EncodeHex(data:pointer;size:integer):String8; overload;
  var
   i:integer;
   pb:PByte;
  begin
   SetLength(result,size*2);
   pb:=data;
   for i:=1 to size do begin
    result[i*2-1]:=AnsiChar(hexchar[1+pb^ shr 4]);
    result[i*2]:=AnsiChar(hexchar[1+pb^ and 15]);
    inc(pb);
   end;
  end;

 function DecodeHex(hexStr:String8):String8;
  var
   i,j:integer;
   b:byte;
  begin
   SetLength(result,length(hexStr) div 2);
   j:=1;
   for i:=1 to length(result) do begin
    b:=HexCharToInt(hexStr[j]) shl 4+HexCharToInt(hexStr[j+1]);
    result[i]:=AnsiChar(b);
    inc(j,2);
   end;
  end;

 procedure DecodeHex(st:String8;buf:pointer); overload;
  var
   pb:PByte;
   i:integer;
   b:byte;
  begin
   pb:=buf;
   ASSERT(length(st) mod 2=0,'Odd hex length');
   i:=1;
   while i<length(st) do begin
    b:=HexCharToInt(st[i]) shl 4;
    inc(i);
    inc(b,HexCharToInt(st[i]));
    inc(i);
    pb^:=b;
    inc(pb);
   end;
  end;

 function IsZeroMem(buf:pointer;size:integer):boolean;
  var
   i:integer;
   pc:^NativeUInt;
   pb:PByte;
  begin
   result:=false;
   pb:=buf;
   if size<=8 then begin
    // Unaligned version
    while size>0 do begin
     if pb^<>0 then exit;
     inc(pb); dec(size);
    end;
   end else begin
    // Aligned version
    while UIntPtr(pb) and 8<>0 do begin
     if pb^<>0 then exit;
     inc(pb); dec(size);
    end;
    i:=size div sizeof(NativeUInt);
    pc:=pointer(pb);
    while i>0 do begin
     if pc^<>0 then exit;
     inc(pc);
     dec(i); dec(size,sizeof(NativeUInt));
    end;
    pb:=pointer(pc);
    while size>0 do begin
     if pb^<>0 then exit;
     inc(pb); dec(size);
    end;
   end;
   result:=true;
  end;

 function IsUTF8(st:String8):boolean; inline;
  begin
   if (length(st)>=3) and (st[1]=#$EF) and (st[2]=#$BB) and (st[3]=#$BF) then result:=true
    else result:=false;
  end;

 function UStr(st:String16):string; // Convert to UTF8 if string is 8-bit
  begin
   {$IFDEF UNICODE}
   result:=st;
   {$ELSE}
   EncodeUTF8(st,result);
   {$ENDIF}
  end;

 function WStr(st:string):string16; // Convert default string to the 16-bit string
  begin
   {$IFDEF UNICODE}
   result:=st;
   {$ELSE}
   result:=DecodeUTF8(st);
   {$ENDIF}
  end;

 procedure EncodeUTF8(st:String16;var dest:string);
  begin
   {$IFDEF UNICODE}
   dest:=st;
   {$ELSE}
   dest:=EncodeUTF8(st);
   {$ENDIF}
  end;

 procedure EncodeUTF8(st:String16;var dest:String8); overload;
  begin
   dest:=EncodeUTF8(st);
  end;

 function EncodeUTF8(st:String16;addBOM:boolean=false):String8;
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
     inc(l); result[l]:=AnsiChar(w);
    end else
    if w<$800 then begin
     inc(l); result[l]:=AnsiChar($C0+w shr 6);
     inc(l); result[l]:=AnsiChar($80+w and $3F);
    end else begin
     inc(l); result[l]:=AnsiChar($E0+w shr 12);
     inc(l); result[l]:=AnsiChar($80+(w shr 6) and $3F);
     inc(l); result[l]:=AnsiChar($80+w and $3F);
    end;
   end;
   setLength(result,l);
  end;

 function DecodeUTF8(st:String16):String16;
  begin
   result:=st;
  end;

 function DecodeUTF8(st:String8):String16;
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

 function DecodeUTF8A(sa:AStringArr):WStringArr; overload;
  var
   i:integer;
  begin
   SetLength(result,length(sa));
   for i:=0 to high(sa) do
    result[i]:=DecodeUTF8(sa[i]);
  end;

 function DecodeUTF8A(sa:StringArr):WStringArr; overload;
  var
   i:integer;
  begin
   SetLength(result,length(sa));
   for i:=0 to high(sa) do
   {$IFDEF UNICODE}
    result[i]:=sa[i];
   {$ELSE}
    result[i]:=DecodeUTF8(sa[i]);
   {$ENDIF}
  end;

 function UTF8toWin1251(st:String8):String8;
  var
   ws:widestring;
   i:integer;
  begin
   ws:=DecodeUTF8(st);
   SetLength(result,length(ws));
   for i:=1 to length(ws) do
    result[i]:=ConvertUnicodeToWindows(ws[i]);
  end;

 function Win1251toUTF8(st:String8):String8;
  var
   ws:widestring;
   i:integer;
  begin
   SetLength(ws,length(st));
   for i:=1 to length(ws) do
    ws[i]:=ConvertWindowstoUnicode(st[i]);
   result:=EncodeUTF8(ws);
  end;

 function UpperCaseUtf8(st:String8):String8;
  var
   wst:WideString;
  begin
   wst:=DecodeUTF8(st);
   wst:=WideUpperCase(wst);
   result:=EncodeUTF8(wst);
  end;

 function LowerCaseUtf8(st:String8):String8;
  var
   wst:WideString;
  begin
   wst:=DecodeUTF8(st);
   wst:=WideLowerCase(wst);
   result:=EncodeUTF8(wst);
  end;

 function UnicodeTo(st:WideString;encoding:TTextEncoding):String8;
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
      if word(st[i])<256 then result[i]:=AnsiChar(word(st[i]))
       else result[i]:='?';
    end;
    else raise EWarning.Create('Encoding not supported 1');
   end;
  end;

 function UnicodeFrom(st:String8;encoding:TTextEncoding):WideString;
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

 {$IFDEF ADDANSI}
 function HTMLString(st:String8):String8;
  begin
   st:=StringReplace(st,'&','&amp;',[rfReplaceAll]);
   st:=StringReplace(st,'<','&lt;',[rfReplaceAll]);
   st:=StringReplace(st,'>','&gt;',[rfReplaceAll]);
   result:=st;
  end;
 {$ENDIF}

 function UrlEncode;
  var
   i:integer;
   ch:AnsiChar;
  begin
   result:='';
   for i:=1 to length(st) do begin
    ch:=st[i];
    if ch in ['A'..'Z','a'..'z','0'..'9','-','_','.','~'] then result:=result+ch
     else result:=result+'%'+hexchar[ord(ch) div 16+1]+hexchar[ord(ch) mod 16+1];
   end;
  end;

 function URLEncodeUTF8(st:String8):String8;
  var
   i:integer;
   ch:ansichar;
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
     result:=result+AnsiChar(b);
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
   // А нужно ли вообще заключать в кавычки?
   if not force then begin
    fl:=false;
    if (length(st)=0) or (st[1]=quotes) then fl:=true;
    for i:=1 to length(st) do
     if st[i] in [' ',#9] then begin
      fl:=true; break;
     end;
    if not fl then exit; // Если не нужно - выходим
   end;
   result:=quotes+StringReplace(st,quotes,quotes+quotes,[rfReplaceAll])+quotes;
  end;

 {$IFDEF ADDANSI}
 function UnQuoteStr(const st:String8;quotes:AnsiChar='"'):String8; overload;
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
 {$ENDIF}
 function UnQuoteStr(const st:String;quotes:Char='"'):String; overload;
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

 function Unescape(st:String8):String8;
  var
   i,c,l,v:integer;
   tmp:String8;
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
      if (i<length(st)) and (st[i+1] in ['n','r','t','0','1','u','/']) then begin
       inc(l); c:=0;
       case st[i+1] of
        'n':begin
             result[l]:=#13;
             inc(l);
             result[l]:=#10;
            end;
        'r':result[l]:=#13;
        't':result[l]:=#9;
        '0':result[l]:=#0;
        '1':result[l]:=#1;
        '/':result[l]:='/';
        'u':begin
             if i+5>length(st) then continue;
             v:=HexToInt(copy(st,i+2,4));
             tmp:=EncodeUTF8(WideChar(v));
             result[l]:=tmp[1];
             if length(tmp)>1 then begin
              inc(l);
              result[l]:=tmp[2];
             end;
             inc(i,4);
            end;
       end;
       inc(i);
      end;
    end else begin
     inc(l);
     result[l]:=st[i];
    end;
    inc(i);
   end;
   SetLength(result,l);
  end;

 function Escape(st:String8):String8;
  var
   i,l:integer;
  begin
   l:=length(st);
   for i:=1 to length(st) do
    if st[i] in [#0,#1,#9,#10,#13,'\'] then inc(l);
   SetLength(result,l);
   l:=1;
   for i:=1 to length(st) do begin
    if st[i] in [#0,#1,#9,#10,#13,'\'] then begin
     result[l]:='\'; inc(l);
     case st[i] of
      #0:result[l]:='0';
      #1:result[l]:='1';
      #9:result[l]:='t';
      #10:result[l]:='n';
      #13:result[l]:='r';
      '\':result[l]:='\';
     end;
    end else
     result[l]:=st[i];
    inc(l);
   end;
  end;

 function ParseDate(st:String8;default:TDateTime=0):TDateTime;
  var
   s1,s2:AStringArr;
   year,month,day,hour,min,sec:integer;
   splitter:String8;
  begin
   result:=default;
   try
    st:=chop(st);
    if st='' then exit;
    s1:=splitA(' ',st);
    splitter:='';
    if pos('.',s1[0])>0 then splitter:='.';
    if pos('-',s1[0])>0 then splitter:='-';
    if pos('/',s1[0])>0 then splitter:='/';
    if splitter='' then exit;
    s2:=splitA(splitter,s1[0]);
    if length(s2)<>3 then exit;
    if length(s2[0])=4 then Swap(s2[2],s2[0]);
    year:=strtoint(s2[2]);
    if year<100 then begin
     if year>70 then year:=1900+year
      else year:=2000+year;
    end;
    month:=Clamp(ParseInt(s2[1]),1,12);
    day:=Clamp(ParseInt(s2[0]),1,31);
    result:=EncodeDate(year,month,day);
    if length(s1)>1 then begin
     s2:=splitA(':',s1[1]);
     if length(s2)>0 then hour:=strtoint(s2[0]) else hour:=0;
     if length(s2)>1 then min:=strtoint(s2[1]) else min:=0;
     if length(s2)>2 then sec:=strtoint(s2[2]) else sec:=0;
     result:=result+EncodeTime(hour,min,sec,0);
    end;
   except
    result:=default;
   end;
  end;

 function ParseTime(st:String8;default:TDateTime=0):TDateTime;
  var
   sa:AStringArr;
   hour,min,sec,msec:integer;
  begin
   try
    st:=chop(st);
    sa:=splitA(':',st);
    msec:=0;
    if length(sa)>0 then hour:=ParseInt(sa[0]) else hour:=0;
    if length(sa)>1 then min:=ParseInt(sa[1]) else min:=0;
    if length(sa)>2 then begin
     if pos('.',sa[2])>0 then begin
      sa:=splitA('.',sa[2]);
      sec:=ParseInt(sa[0]);
      msec:=ParseInt(sa[1]);
     end else
      sec:=ParseInt(sa[2]);
    end;
    result:=hour/24+min/1440+sec/86400+msec/86400000;
   except
    result:=default;
   end;
  end;

 function GetDateFromStr(st:String8;default:TDateTime):TDateTime;
  begin
   result:=ParseDate(st);
  end;

 function HowLong(time:TDateTime):string;
  var
   t:int64;
   neg:boolean;
  begin
   if time=0 then exit('-');
   t:=round((Now-time)*86400);
   if t<0 then begin
    t:=-t; neg:=true;
   end else begin
    neg:=false;
   end;
   result:=IntToStr(t mod 60)+'s';
   if t<60 then exit;
   t:=t div 60; // перевели в минуты
   result:=IntToStr(t mod 60)+'m'+result;
   if t<60 then exit;
   t:=t div 60; // перевели в часы
   result:=IntToStr(t mod 24)+'h'+result;
   if t<24 then exit;
   t:=t div 24; // перевели в дни
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

 // Возвращает строку с описанием распределения памяти
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

 function ConvertToWindows(ch:AnsiChar):AnsiChar;
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
   result:=AnsiChar(b);
  end;

 function ConvertFromWindows(ch:AnsiChar):AnsiChar;
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
   result:=AnsiChar(b);
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


 function ConvertWindowsToUnicode(ch:AnsiChar):WideChar;
  var
   b:byte;
  begin
   b:=byte(ch);
   if b<$80 then result:=WideChar(byte(b))
    else result:=WideChar(win1251cp[b]);
  end;

 function ConvertUnicodeToWindows(ch:WideChar):AnsiChar;
  var
   i:integer;
   w:word;
  begin
   w:=word(ch);
   if w<$80 then result:=AnsiChar(w)
    else begin
     if (w>=$410) and (w<=$44F) then exit(AnsiChar(192+w-$410));
     result:=' ';
     for i:=$80 to $BF do
      if win1251cp[i]=w then exit(AnsiChar(i));
    end;
  end;

 {$IFDEF RANGECHECK}{$R-}{$ENDIF}
 procedure SortObjects(obj:PSortableObjects;count:integer);
  procedure QuickSort(var obj:TSortableObjects;a,b:integer);
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
   if count<2 then exit;
   QuickSort(obj^,0,count-1);
  end;
  {$IFDEF RANGECHECK}{$R+}{$ENDIF}

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

 procedure SortStrings(var sa:AStringArr); overload;
  procedure QuickSort(a,b:integer);
   var
    lo,hi,mid:integer;
    midval:String8;
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
    midval:String16;
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

 function Clamp(b,min,max:integer):integer;
  begin
   result:=b;
   if b>max then result:=max;
   if b<min then result:=min;
  end;

 function Clamp(b,min,max:double):double;
  begin
   result:=b;
   if b>max then result:=max;
   if b<min then result:=min;
  end;

 // Return value of pike function
 function Pike(x,arg,a,b,c:integer):integer;
  begin
   if x<0 then exit(a);
   if x>255 then exit(c);
   if x<arg then result:=a+(b-a)*x div arg
    else result:=b+(c-b)*(x-arg) div (256-arg);
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
     if lowercase(sa[i])=st then exit(i);
   end else
    for i:=0 to high(sa) do
     if sa[i]=st then exit(i);
  end;

 function FindInteger(var a:IntArray;v:integer):integer;
  var
   i:integer;
  begin
   for i:=0 to high(a) do
    if a[i]=v then exit(i);
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
    if i=n then exit(minIndex);
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
    if i=n then exit(minIndex);
    inc(minIndex);
   end;
  end;

 function LastPos(substr,str:String8;ignoreCase:boolean=false):integer; overload;
  var
   i,p,l:integer;
  begin
   result:=0;
   if ignoreCase then begin
    substr:=lowercase(substr);
    str:=lowercase(str);
   end;
   p:=length(str)-length(substr)+1;
   l:=length(substr);
   while p>0 do begin
    i:=0;
    while (i<l) and (str[p+i]=substr[i+1]) do inc(i);
    if i=l then exit(p);
    dec(p);
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

 function UpperCaseA(st:String8):String8;
  var
   i:integer;
   pb:PByte;
  begin
   result:=st;
   pb:=@result[1];
   for i:=1 to length(result) do begin
    if (pb^>=byte('a')) and (pb^<=byte('z')) then dec(pb^,byte('a')-byte('A'));
    inc(pb);
   end;
  end;

 function SameChar(a,b:AnsiChar):boolean;
  begin
   if (byte(a)>=byte('a')) and (byte(a)<=byte('z')) then dec(byte(a),byte('a')-byte('A'));
   if (byte(b)>=byte('a')) and (byte(b)<=byte('z')) then dec(byte(b),byte('a')-byte('A'));
   result:=a=b;
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
   ch:char;
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
   ch:=divider[1];
   while i<=maxIdx do begin
    if st[i]<>ch then
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
    j:=idx[i+1]-divLen-idx[i];
    SetLength(result[i],j);
    if j>0 then result[i]:=copy(st,idx[i],j);
   end;
  end;

 function SplitA(divider,st:String8):AStringArr;
  var
   i,j,n,divLen,maxIdx:integer;
   fl:boolean;
   idx:array of integer;
   ch:AnsiChar;
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
   ch:=divider[1];
   while i<=maxIdx do begin
    if st[i]<>ch then
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
    j:=idx[i+1]-divLen-idx[i];
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
  // Если какая-то из строк начинается и заканчивается кавычками, то необходимо также выполнить для неё замену
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
   dl:=length(divider)*sizeof(char);
   while i<length(strings) do begin
    if i>0 then begin
     move(divider[1],result[n],dl);
     inc(n,length(divider));
    end;
    j:=1;
    l:=length(strings[i]);
    src:=@strings[i][1];
    while j<=l do begin
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

 function Join(strings:AStringArr;divider:String8):String8; overload;
  var
   i,j,l,s,n,dl:integer;
   src:PAnsiChar;
  begin
   i:=0;
   s:=1000; SetLength(result,s);
   n:=1;
   dl:=length(divider)*sizeof(AnsiChar);
   while i<length(strings) do begin
    if i>0 then begin
     move(divider[1],result[n],dl);
     inc(n,dl);
    end;
    j:=1;
    l:=length(strings[i]);
    src:=@strings[i][1];
    while j<=l do begin
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

 function HasPrefix(st,prefix:String8;ignoreCase:boolean=false):boolean; overload;
  var
   i:integer;
  begin
   result:=false;
   if length(st)<length(prefix) then exit;
   for i:=1 to length(prefix) do
    if ignoreCase then begin
     if st[i]<>prefix[i] then exit;
    end else
     if not SameChar(st[i],prefix[i]) then exit;
   result:=true;
  end;

 function SafeStrItem(sa:StringArr;idx:integer):string;
  begin
   result:='';
   if (idx<0) or (idx>high(sa)) then exit;
   result:=sa[idx];
  end;

 {$IFDEF ADDANSI}
 function Chop(st:String8):String8; overload;
  var
   i:integer;
  begin
   result:=st;
   while (length(result)>0) and (result[1]<=' ') do delete(result,1,1);
   i:=length(result);
   while (length(result)>0) and (result[i]<=' ') do dec(i);
   setlength(result,i);
  end;
 {$ENDIF}
 function Chop(st:String):String; overload;
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
 {$IFDEF ADDANSI}
 function LastChar(st:String8):AnsiChar;
  begin
   if st='' then result:=#0
    else result:=st[length(st)];
  end;
 {$ENDIF}

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
   time:=GetUTCTime;
   result:=chr(48+time.wHour div 10)+chr(48+time.wHour mod 10)+':'+
           chr(48+time.wMinute div 10)+chr(48+time.wMinute mod 10)+':'+
           chr(48+time.wSecond div 10)+chr(48+time.wSecond mod 10)+'.'+
           chr(48+time.wMilliseconds div 100)+chr(48+(time.wMilliseconds div 10) mod 10)+chr(48+time.wMilliseconds mod 10)+
           '  '+text;
   {$ELSE}
   result:=FormatDateTime('hh:nn:ss.z',Now)+'  '+text;
   {$ENDIF}
  end;

 procedure LogMessage(text:string;group:byte=0);
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
     // кэш доступен и позволяет вместить сообщение
     cacheBuf:=cacheBuf+text+#13#10;
    end else begin
     // кэш отключен либо его размер недостаточен
     if not forceCacheUsage then begin
      // запись в кэш необязательна, поэтому записать кэш а затем само сообщение напрямую
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
      // режим "писать только в кэш", а кэш переполнен
      if length(cacheBuf)<65500 then begin
       cacheBuf:=cacheBuf+'Cache overflow!'#13#10; // сообщение заменяется на это
      end;
     end;
    end;

   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure LogMessage(text:string;params:array of const;group:byte=0);
  begin
   text:=Format(text,params);
   LogMessage(text,group);
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
     // Режим "писать только в кэш"
     if (length(cacheBuf)+length(text)<65000) then begin
      cacheBuf:=cacheBuf+text+#13#10;
     end else begin
      // режим "писать только в кэш", а кэш переполнен
      if length(cacheBuf)<65500 then begin
       cacheBuf:=cacheBuf+'Cache overflow!'#13#10;
      end;
     end;
    end else begin
     // Обычный режим (форсированные сообщения пишутся напрямую, без кэша)
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
    except
     on e:exception do ForceLogMessage('Error flushing Log: '+e.message);
    end;
   finally
    MyLeaveCriticalSection(crSection);
   end;
  end;

 procedure LogCacheMode(enable:boolean;enforceCache:boolean=false;runThread:boolean=false);
  begin
   cacheenabled:=enable;
   if enable then forceCacheUsage:=enforceCache;
   if not enable and (cacheBuf<>'') then flushLog;
   if runThread then begin
    if logThread=nil then logThread:=TLogThread.Create(false);
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
   ForceLogMessage(text);
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
  result:='['+PtrToStr(ExceptAddr)+'] '+e.Message+' '+GetStackTrace;
 end;
 {$ENDIF}

 procedure NotImplemented(msg:string='');
  begin
   raise EError.Create('Not implemented: '+msg);
  end;

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
    if UpperCase(sr.name)=UpperCase(name) then
     exit(path+PathSeparator+sr.name)
    else begin
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

 procedure MakeBakFile(fname:string);
  var
   bakName:string;
  begin
   if FileExists(fname) then begin
    bakName:=ChangeFileExt(fname,'.bak');
    if FileExists(bakName) then DeleteFile(bakName);
    RenameFile(fname,bakName);
   end;
  end;

 function GetFileSize(fname:String8):int64;
  {$IFDEF MSWINDOWS}
  var
   openbuff:TOFSTRUCT;
   h:HFile;
   data:array[0..1] of cardinal;
  begin
   result:=-1;
   try
    h:=FileOpen(fName,fmOpenRead);
    if h=INVALID_HANDLE_VALUE then exit;
    data[0]:=windows.GetFileSize(h,@data[1]);
    move(data,result,8);
    FileClose(h);
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

 function LoadFileAsString(fname:string):String8;
  var
   buf:ByteArray;
  begin
   buf:=LoadFileAsBytes(fname);
   SetLength(result,length(buf));
   move(buf[0],result[1],length(buf));
  end;

 function LoadFileAsBytes(fname:string):ByteArray;
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
    blockread(f,result[0],filesize(f));
    closefile(f);
   except
    on e:exception do
     raise EError.Create('Failed to load file '+fname+': '+ExceptionMsg(e));
   end;
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

 function MyTickCount:int64;
  var
   t:cardinal;
  begin
   MyEnterCriticalSection(crSection); // иначе может быть косяк с глобальной LastTickCount
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

 function TryLoadFunction(libName,funcName:string):pointer;
  var
   lib:HModule;
  begin
   result:=nil;
   lib:=LoadLibrary(PChar(libName));
   if lib=0 then exit;
   result:=GetProcAddress(lib,PChar(funcName));
  end;

 var
  preciseTimeSupport:integer=0;
  GetSystemTimePreciseAsFileTime:procedure(out time:TFileTime); stdcall;

 function GetUTCTime:TSystemTime;
  var
   p:pointer;
   ft:TFileTime;
  begin
   if preciseTimeSupport=0 then begin
    p:=TryLoadFunction('kernel32.dll','GetSystemTimePreciseAsFileTime');
    if p<>nil then begin
     preciseTimeSupport:=1;
     GetSystemTimePreciseAsFileTime:=p;
    end else
     preciseTimeSupport:=-1;
   end;

   if preciseTimeSupport>0 then begin
    GetSystemTimePreciseAsFileTime(ft);
    FileTimeToSystemTime(ft,result);
   end else
    GetSystemTime(result);
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
  add ecx,$100000 // не трогать стек выше EBP+1Mb
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
  add ecx,$100000 // не трогать стек выше EBP+1Mb
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
  {$IFDEF FPC}
  inherited create(msg+' caller: '+inttohex(cardinal(get_caller_addr(get_frame)),8));
  {$ELSE}
  inherited create(msg);
  {$ENDIF}
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

procedure SafeEnterCriticalSection(var cr:TMyCriticalSection); // Осторожно войти в критсекцию
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

procedure DumpCritSects; // Вывести в лог состояние всех критсекций
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

procedure CheckCritSections; // проверить критические секции на таймаут
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

procedure RegisterThread(name:string); // зарегистрировать поток
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

procedure UnregisterThread; // удалить поток (нужно вызывать перед завершением потока)
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

procedure PingThread; // сообщить о "живучести" потока
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

function GetThreadName(threadID:cardinal=0):string; // вернуть имя (0=текущего) потока
 begin
  if threadID=0 then threadID:=GetCurrentThreadID;
  result:=GetNameOfThread(threadID);
 end;

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
  logThread.WaitFor;
  logThread:=nil;
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

procedure TMyCriticalSection.Enter;  // for compatibility
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
   if CompareText(name,paramStr(i))=0 then exit(true);
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
   exit(copy(st,p+1,length(st)));
  end;
 end;

{$IF Declared(SRWLOCK)}
{ TSRWLock }
procedure TSRWLock.Init(name: string);
begin
 self.name:=name;
 InitializeSrwLock(lock);
end;

procedure TSRWLock.StartRead;
begin
 AcquireSRWLockShared(lock);
end;

procedure TSRWLock.FinishRead;
begin
 ReleaseSRWLockShared(lock);
end;

procedure TSRWLock.StartWrite;
begin
 AcquireSRWLockExclusive(lock);
end;

procedure TSRWLock.FinishWrite;
begin
 ReleaseSRWLockExclusive(lock);
end;
{$ENDIF}

var
 v:Int64;

initialization
 SetDecimalSeparator('.');
 QueryPerformanceFrequency(v);
 if v<>0 then
  PerfKoef:=1000/v
 else PerfKoef:=0;
 QueryPerformanceCounter(StartTime);
 {$IFDEF MSWINDOWS}
 InitializeCriticalSection(crSection);
 startTimeMS:=timeGetTime;
 {$ELSE}
 InitCriticalSection(crSection);
 startTimeMS:=CrossPlatform.GetTickCount;
 {$ENDIF}
 startTime:=MyTickCount;

finalization
 if logThread<>nil then StopLogThread;
 {$IFDEF MSWINDOWS}
 DeleteCriticalSection(crSection);
 {$ELSE}
 DoneCriticalSection(crSection);
 {$ENDIF}
end.

