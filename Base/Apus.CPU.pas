// -----------------------------------------------------
// CPU features unit
// Author: Ivan Polyacov (C) 2021, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// ------------------------------------------------------
unit Apus.CPU;
interface
type
 // CPU Features flags
 TCPU=record
  version:cardinal;
  flags1,flags2:cardinal; // EDX and ECX flags
  MMX:boolean;
  SSE:boolean; // SSE instructions are available
  SSE2,SSE3,SSSE3,SSE4,SSE42:boolean;
  AVX,AVX2:boolean;
  AES,RDRAND:boolean;
  HYPERVISOR:boolean;
  BMI1,BMI2:boolean;
 end;
var
 cpu:TCPU;
 v:byte;

 //procedure SetSSERoundMode();

implementation
 procedure CheckCPU;
  {$IF Defined(CPUx64) or Defined(CPUX86_64) or Defined(CPUx86)}
  {$IFDEF CPUx86}
  const
   rip = 0;
  {$ENDIF}
  asm
   {$IFDEF CPUx86}
   push ebx
   {$ELSE}
   push rbx
   {$ENDIF}
   xor eax,eax
   cpuid
   cmp eax,7
   jb @01
   mov eax,7
   xor ecx,ecx
   cpuid
   // AVX2
   bt ebx,5
   adc [rip+cpu.avx2],0
   // BMI1
   bt ebx,3
   adc [rip+cpu.bmi1],0
   // BMI2
   bt ebx,8
   adc [rip+cpu.bmi2],0

@01:
   mov eax,1
   cpuid
   mov [rip+cpu.version],eax
   mov [rip+cpu.flags1],edx
   mov [rip+cpu.flags2],ecx
   // MMX
   bt edx,23
   adc [rip+cpu.mmx],0
   // SSE
   bt edx,25
   adc [rip+cpu.sse],0
   // SSE2
   bt edx,26
   adc [rip+cpu.sse2],0
   // SSE3
   bt ecx,0
   adc [rip+cpu.sse3],0
   // SSSE3
   bt ecx,9
   adc [rip+cpu.ssse3],0
   // SSE4
   bt ecx,19
   adc [rip+cpu.sse4],0
   // SSE42
   bt ecx,20
   adc [rip+cpu.sse42],0
   // AVX
   bt ecx,28
   adc [rip+cpu.avx],0
   // AES
   bt ecx,25
   adc [rip+cpu.aes],0
   // RDRAND
   bt ecx,30
   adc [rip+cpu.rdrand],0
   // HYPERVISOR
   bt ecx,31
   adc [rip+cpu.hypervisor],0

   {$IFDEF CPUx86}
   pop ebx
   {$ELSE}
   pop rbx
   {$ENDIF}
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

initialization
 CheckCPU;
end.
