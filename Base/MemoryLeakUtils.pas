unit MemoryLeakUtils;
interface

 // Процедуры для выслеживания утечек памяти (Delphi-only)
 {$IFDEF DELPHI} {$IFDEF CPU386}
 procedure BeginMemoryCheck(id:string);
 procedure EndMemoryCheck;

 procedure StartMemoryLeaksTracking;
 procedure StopMemoryLeaksTracking;
 {$ENDIF}{$ENDIF}

implementation
 uses MyServis,SysUtils;
 type
  TMemLeak=record
   value:cardinal;
   name:string;
  end;
 var
  memleaks:array[1..40] of TMemLeak;
  memleakcnt:integer=0;

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

{$IFDEF DELPHI}
{$IFDEF CPU386}
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
function DebugGetMem(size:NativeInt):pointer;
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
function DebugReallocMem(p:pointer;size:NativeInt):pointer;
 begin
  result:=memMgr.ReallocMem(p,size);
  ChangeBlock(p,result,size);
 end;
function DebugAllocMem(size:NativeInt):pointer;
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
{$ENDIF}


end.
