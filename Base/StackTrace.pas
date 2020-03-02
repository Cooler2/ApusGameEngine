// Stack tracing utility - under construction
// Author: Ivan Polyacov - ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit StackTrace;
interface

 procedure EnableStackTrace;
 procedure DisableStackTrace;
 function GetStackTrace:string;

implementation
 uses CrossPlatform,MyServis,Windows;
 var
  saveExceptionProc:pointer;
  stack:array[0..15] of pointer;

{$IFDEF WIN64}
 function RtlCaptureStackBackTrace(framesSkip,framesCapture:longint;const trace:pointer;const hash:pointer):shortint; external 'kernel32.dll';
{$ENDIF}

 procedure MyExceptProc;
 {$IFDEF WIN32}
 asm
  pushad
  mov esi,ebp
  mov ecx,ebp
  add ecx,$100000 // Upper stack limit: EBP+1Mb
  mov edx,6
  lea edi,stack
@01:
  mov eax,[esi+4]
  stosd
  mov esi,[esi]
  cmp esi,ebp
  jb @02
  cmp esi,ecx
  ja @02
  dec edx
  jnz @01
@02:
  popad
  jmp saveExceptionProc
 end;
{$ENDIF}
{$IFDEF WIN64}
 asm
{  xor rcx,rcx
  mov edx,5
  lea r8,stack
  xor r9,r9
  add rsp,$20
  call RTLCaptureStackBackTrace}
{  mov rsi,rbp
  sub rsi,16
  mov rcx,rbp
  add rcx,$100000 // Upper stack limit: EBP+1Mb
  mov rdx,6
  lea rdi,stack
@01:
  mov rax,[rsi+8]
  stosq
  mov rsi,[rsi]
  cmp rsi,rbp
  jb @02
  cmp rsi,rcx
  ja @02
  dec rdx
  jnz @01
@02:
  pop rdi
  pop rsi
  pop rdx
  pop rcx}
  jmp [saveExceptionProc]
 end;
{$ENDIF}
{  asm
   push eax
   mov eax,[esp+16]
   push edx
   push ecx
   push ebx
   lea edx,stack
   mov ecx,16
@01:
   sub eax,4
   mov ebx,[eax]
   mov [edx],ebx
   add edx,4
   dec ecx
   jnz @01
   pop ebx
   pop ecx
   pop edx
   pop eax
   jmp saveExceptionProc
  end;    }

 procedure EnableStackTrace;
  begin
   {$IFDEF MSWINDOWS}
   //RtlCaptureStackBackTrace(0,5,@stack,nil);
   if saveExceptionProc<>nil then exit;
   saveExceptionProc:=ExceptClsProc;
   ExceptClsProc:=@myExceptProc;
   {$ENDIF}
  end;

 procedure DisableStackTrace;
  begin
   {$IFDEF MSWINDOWS}
   ASSERT(saveExceptionProc<>nil);
   exceptClsProc:=saveExceptionProc;
   saveExceptionProc:=nil;
   {$ENDIF}
  end;

 function GetStackTrace:string;
  var
   i:integer;
   v:PtrUInt;
  begin
   result:='';
   {$IFDEF MSWINDOWS}
   if saveExceptionProc=nil then exit;
   for i:=0 to high(stack) do begin
    v:=PtrUInt(stack[i]) shr 20;
    //if v and $F00=$700 then break;
    if (v>=4) and (v<8) then result:=result+':'+PtrToStr(stack[i]);
   end;
   fillchar(stack,sizeof(stack),0);
   {$ENDIF}
  end;

{$IFDEF STACKTRACE}
initialization
 EnableStackTrace;
{$ENDIF}
end.
