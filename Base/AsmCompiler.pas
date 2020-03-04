// Simplified assembler compiler
//
// Copyright (C) 2003 Apus Software, Ivan Polyacov: ivan@games4win.com

unit AsmCompiler;
interface
 uses AsmDefines;

const
 R_EAX = 0;
 R_ECX = 1;
 R_EDX = 2;
 R_EBX = 3;
 R_ESP = 4;
 R_EBP = 5;
 R_ESI = 6;
 R_EDI = 7;

 R_AL = 0;
 R_CL = 1;
 R_DL = 2;
 R_BL = 3;
 R_AH = 4;
 R_CH = 5;
 R_DH = 6;
 R_BH = 7;

 RM_EAX = $10;
 RM_ECX = $11;
 RM_EDX = $12;
 RM_EBX = $13;
 RM_ESP = $14;
 RM_EBP = $15;
 RM_ESI = $16;
 RM_EDI = $17;
 IND_EAX  = $2000;
 IND_ECX  = $2100;
 IND_EDX  = $2200;
 IND_EBX  = $2300;
 IND_ESP  = $2400;
 IND_EBP  = $2500;
 IND_ESI  = $2600;
 IND_EDI  = $2700;
 IND_EAX2 = $3000;
 IND_ECX2 = $3100;
 IND_EDX2 = $3200;
 IND_EBX2 = $3300;
 IND_ESP2 = $3400;
 IND_EBP2 = $3500;
 IND_ESI2 = $3600;
 IND_EDI2 = $3700;
 IND_EAX4 = $4000;
 IND_ECX4 = $4100;
 IND_EDX4 = $4200;
 IND_EBX4 = $4300;
 IND_ESP4 = $4400;
 IND_EBP4 = $4500;
 IND_ESI4 = $4600;
 IND_EDI4 = $4700;
 IND_EAX8 = $5000;
 IND_ECX8 = $5100;
 IND_EDX8 = $5200;
 IND_EBX8 = $5300;
 IND_ESP8 = $5400;
 IND_EBP8 = $5500;
 IND_ESI8 = $5600;
 IND_EDI8 = $5700;
 RM_OFS   = $20000;
 RM_LABEL = $10000;

type
 TAsmCompiler=class
  constructor Create;
  destructor Destroy; override;
  // Build executable code to buffer
  // buf, size - buffer and its size
  // base - base address, can be 0 - in this case buffer address
  // will be used (use this parameter to move code to another placement)
  procedure Build(var buf;var size:integer;base:cardinal=0);

  // Labels
  function DeclareLabel:integer; overload; // forward declaration
  function DeclareLabel(lab:integer):integer; overload; // explicit declaration
  function DefineLabel(address:cardinal=0):integer;

  // Variables

  // Code
  procedure JMP(lab:integer);
  procedure MOV_RM8_R(dest,offset,lab:integer;src:integer);
  procedure RET(n_params:byte=0);

  // Alignment and prefixes
  procedure ALIGN(n:byte);

 private
  // —писок команд
  code:array of TStatement;
  cmdCount:integer;
  // —писок меток
  labels:array of TLabel;
  labCount:integer;

  curAlign:byte; // “екущее выравнивание (дл€ очередной команды)
  prefcnt:byte;  //  ол-во префиксов дл€ очередной команды
  prefixes:array[0..3] of byte; // —ами префиксы
  curOffset:integer;  // јдрес очередной команды (относительно нул€)

  // ѕредобработка команды (заполнение основных полей)
  procedure Preprocess(var cmd:TStatement);
  // ќбработка адреса (заполнение Mod/RM, SIB, Offset по заданным флагам)
  procedure HandleRM(var cmd:TStatement;dest,offset,lab:integer);
  // ƒобавить команду в список
  procedure AddCmd(cmd:TStatement);
  // ƒобавить метку
  procedure AddLabel(l:TLabel);
 end;

var
 SupportMMX:boolean=false;
 Support3DNow:boolean=false;
 SupportSSE:boolean=false;

implementation

{ TAsmCompiler }

procedure TAsmCompiler.AddCmd(cmd: TStatement);
var
 s:integer;
begin
 if cmdCount>=length(code) then begin
  s:=length(code);
  s:=s+25+s div 2;
  setLength(code,s);
 end;
 code[cmdcount]:=cmd;
 inc(cmdCount);
 curalign:=0;
 prefcnt:=0;
 if cmd.kind=0 then
  inc(CurOffset,cmd.size)
 else
  inc(CurOffset,cmd.fullsize);
end;

procedure TAsmCompiler.AddLabel(l: TLabel);
var
 s:integer;
begin
 if labCount>=length(labels) then begin
  s:=length(labels);
  s:=s+10+s div 2;
  setLength(labels,s);
 end;
 labels[labCount]:=l;
 inc(labcount);
end;

procedure TAsmCompiler.Build(var buf; var size: integer; base: cardinal);
var
 i,o,s,n:integer;
 p:PByte;
begin
 if base=0 then base:=integer(addr(buf));
 // Ётап 1: корректировка адресов команд (выравнивание)
 o:=base;
 for i:=0 to cmdCount-1 do with code[i] do begin
  if alignment>0 then begin
   if o mod alignment>0 then begin
    // корректируем адрес
    o:=(o+alignment-1) and (not (alignment-1));
   end;
  end;
  offset:=o;
  inc(o,size); // переход к адресу следующей команды
 end;

 // Ётап 2: ”плотнение
 o:=base;
 for i:=0 to cmdCount-1 do with code[i] do begin
  if alignment>0 then begin
   if o mod alignment>0 then begin
    // корректируем адрес
    o:=(o+alignment-1) and (not (alignment-1));
   end;
  end;
  offset:=o;
  if (flags and (hasModRM+hasOffset32)=(hasModRM+hasOffset32)) and
     (modRM and $80=$80) then begin
   s:=OffsetValue;
   // попытка уплотнени€ за счет смещени€
   if (lab>0) and (labfor=1) then begin // нужно применить метку
    if labels[lab-1].relative then
     inc(s,code[labels[lab-1].value].offset+size)
    else
     inc(s,labels[lab-1].value);
   end;
   if (s<95) and (s>-95) then begin
    flags:=flags-hasOffset32+hasOffset8;
    dec(size,3);
    dec(ModRM,64);
   end;
  end;
  if code[i].flags and (CanPack+hasValue32)=(CanPack+hasValue32) then begin
   s:=Value;
   // попытка уплотнени€ команды за счет значени€
   if (lab>0) and (labfor=2) then begin // нужно применить метку
    if labels[lab-1].relative then
     inc(s,code[labels[lab-1].value].offset-offset-(size-3))
    else
     inc(s,labels[lab-1].value);
   end;
   if (s<95) and (s>-95) then begin
    flags:=flags-hasValue32+hasValue8;
    opcode:=labcode; // «амена опкода на альтернативный
    dec(size,3);
   end;
  end;
  inc(o,size);
 end;

 // Ётап 3: заполнение буфера, линковка
 // Ќа данный момент все адреса уже окончательно определены
 p:=@buf; o:=base;
 for i:=0 to cmdCount do with code[i] do begin
  if o<offset then begin // «аполнение дл€ выравнивани€
   move(fillers[offset-o],p^,offset-o);
   inc(p,offset-o);
   o:=offset;
  end;
  if prefCnt>0 then begin
   move(prefixes,p^,PrefCnt);
   inc(p,prefcnt);
  end;
  p^:=opcode; inc(p);
  if flags and hasModRM>0 then begin
   p^:=modRM; inc(p);
  end;
  if flags and hasSIB>0 then begin
   p^:=SIB; inc(p);
  end;
  if lab>0 then begin // используетс€ метка, нужно определить реальный адрес
   if labels[lab-1].relative then
    s:=code[labels[lab-1].value].offset-(offset+size) // смещение от следующей команды
   else
    s:=labels[lab-1].value; // абсолютный адрес
   if LabFor=1 then
    inc(OffsetValue,s)
   else
    inc(value,s);
  end;
  if flags and hasValueOffset>0 then begin
   // есть смещение либо значение
   if flags and hasValue8>0 then begin
    p^:=byte(value); inc(p);
   end else
   if flags and hasValue32>0 then begin
    move(value,p^,4); inc(p,4);
   end else
   if flags and hasOffset8>0 then begin
    p^:=byte(OffsetValue); inc(p);
   end else
   if flags and hasOffset32>0 then begin
    move(OffsetValue,p^,4); inc(p,4);
   end else
   if flags and hasValue16>0 then begin
    p^:=value and 255; inc(p);
    p^:=(value shr 8) and 255; inc(p);
   end;
  end;
  inc(o,size);
 end;

end;

constructor TAsmCompiler.Create;
begin
 cmdcount:=0;
 SetLength(code,50);
 labCount:=0;
 SetLength(labels,10);
 curAlign:=0;
 prefcnt:=0;
 curOffset:=0;
end;

function TAsmCompiler.DeclareLabel: integer;
var
 l:TLabel;
begin
 l.defined:=false;
 AddLabel(l);
 result:=labCount;
end;

function TAsmCompiler.DeclareLabel(lab:integer):integer;
begin
 if lab=0 then lab:=DeclareLabel;
 with labels[lab-1] do begin
  defined:=true;
  relative:=true;
  value:=cmdcount-1;
 end;
 result:=lab;
end;

function TAsmCompiler.DefineLabel(address: cardinal): integer;
var
 l:TLabel;
begin
 l.defined:=true;
 l.relative:=address=0;
 if address=0 then
  l.value:=cmdCount
 else
  l.value:=address;
 AddLabel(l);
 result:=labcount;
end;

destructor TAsmCompiler.Destroy;
begin

end;

procedure TAsmCompiler.Preprocess(var cmd: TStatement);
var
 i:integer;
begin
 cmd.kind:=0;
 cmd.alignment:=curAlign;
 cmd.flags:=0;
 cmd.offset:=CurOffset;
 cmd.prefCount:=PrefCnt;
 for i:=1 to PrefCnt do
  cmd.prefixes[i-1]:=prefixes[i-1];
 cmd.size:=prefcnt+1;
 cmd.lab:=-1;
end;

procedure TAsmCompiler.HandleRM(var cmd:TStatement;dest,offset,lab:integer);
var
 base,index,scale:shortint;
 fl:boolean;
begin
 if offset<>0 then dest:=dest or RM_OFS;
 if lab>0 then begin
  if dest and RM_OFS=0 then begin
   offset:=0; inc(dest,RM_OFS);
  end;
  dest:=dest or RM_LABEL;
 end;
 cmd.modRM:=0;
 cmd.lab:=-1;
 cmd.flags:=hasModRM;
 inc(cmd.size);
 if dest<8 then begin // destination is register
  cmd.modRM:=$C0+dest;
  exit;
 end;

 // ќпределим регистр базы
 if dest and $10>0 then
  base:=dest and $0F
 else base:=-1;

 // ќпределим индекс и масштаб индекса
 if dest and $F000>0 then begin
  scale:=(dest shr 12) and $0f - 2;
  index:=(dest shr 8) and $0f;
 end else begin
  scale:=0; index:=4;
 end;

 // ѕроверим, можно ли обойтись без SIB
 fl:=(index<>4) or
     (index=4) and (base=R_ESP);
 if fl then begin // SIB
  inc(cmd.flags,hasSIB);
  inc(cmd.size);
  cmd.modRM:=4;
  cmd.sib:=base+index shl 3+scale shl 6;
 end else begin
  // можно обойтись без SIB
  if base>=0 then
   cmd.modRM:=base
  else
   cmd.modRM:=5;
  if (base=R_EBP) and (dest and RM_OFS=0) then begin
   // если смещени€ не было, искусственно создадим нулевое
   inc(dest,RM_OFS); offset:=0;
  end;
 end;

 if dest and (RM_OFS+RM_LABEL)>0 then begin
  cmd.offsetValue:=offset;
  if base>=0 then
   inc(cmd.modRM,$80); // 32-bit offset
  inc(cmd.flags,hasOffset32);
  inc(cmd.size,4);
  if dest and RM_LABEL>0 then begin
   cmd.lab:=lab;
   cmd.labFor:=1;
  end;
 end;
end;

procedure TAsmCompiler.ALIGN(n: byte);
begin
 case n of
  2,4,8,16:curalign:=n;
 end;
end;

procedure TAsmCompiler.MOV_RM8_R(dest,offset,lab:integer;src:integer);
var
 s:TStatement;
begin
 preprocess(s);
 s.opcode:=$88;
 HandleRM(s,dest,offset,lab);
 inc(s.modRM,src shl 3); // source register
 AddCmd(s);
end;

procedure TAsmCompiler.RET(n_params: byte=0);
var
 s:TStatement;
begin
 preprocess(s);
 s.opcode:=$C3;
 inc(s.size);
 if n_params<>0 then begin
  s.opcode:=$C2;
  s.value:=n_params*4;
  inc(s.flags,hasValue16);
  inc(s.size,2);
 end;
 AddCmd(s);
end;

procedure TAsmCompiler.JMP(lab: integer);
var
 s:TStatement;
begin
 preprocess(s);
 s.opcode:=$E9;
 s.labcode:=$EB;
 s.lab:=lab;
 s.labFor:=2;
 s.size:=5;
 s.value:=0;
 s.flags:=s.flags or (canPack+hasValue32);
 AddCmd(s);
end;

initialization

end.
