 {$I-,H-}
 unit data5;
  interface
   const
    on=true;
    off=false;
    NO_COMPRESS=0;
    LZW_COMPRESS=1;
    ADVANCED_COMPRESS=2;
    ADPCM_COMPRESS=20;
    WAV_ADPCM_COMPRESS=30;
    CAS_COMPRESS=50;

   type
    TProgressProc=procedure(a,b:longint);
   var
    size1,size2:longint;
    posled:array[0..64] of byte;
    datfile:file;
    LastDataError:integer=0;
    encrypted,loaded:boolean;

    function checksum(var p;size:longint):word; pascal;
    procedure encrypt(var p;size:longint;code:longint); pascal;
    // Caller must allocate buffer of enought size
    function lzwpack(var sour,dest;size1:longint):longint;
    function lzwunpack(var sour,dest):longint;
    // New advanced version of loseless compressor
    // Compress data and return size of compressed stream
    function AdvCompress(var sour,dest;size,bufsize:longint;progr:TProgressProc):longint;
    // Returns size of decompressed data
    function AdvDecompress(var sour,dest;size,bufsize:longint;progr:TProgressProc):longint;
    // 'bits' must be in [4,6,8]
    function ADPCMpack(var sour,dest;size1:longint;bits:byte;var SkipHeader:boolean):longint;
    { In: SkipHeader=true - skip WAV header if present
      Out: SkipHeader=(Header stored in dest) }
    function ADPCMunpack(var sour,dest;size1:longint;bits:byte;UseHeader:boolean):longint;
    procedure OpenDatFile(name:string;filecode:longint);
    procedure closedatfile;
    function GetData(n:byte;var p:pointer):longint;
    function findname(reqname:string):byte;
    function GetDataType(n:integer):byte;
    function GetDataCount:integer;
    function GetRecName(n:byte):string;

  implementation
   uses windows,SysUtils,MyServis;
   const
    idstr:string[12]='”€‰‹ „€›• ';

   type
    PByte=^byte;
    headertype=record
     id:array[1..10] of byte;
     count:byte;
     encrypted:boolean;
     size:longint;
    end;
    rectype=record
     start,size1,size2:longint;
     sum1,sum2:word;
     sort:byte;
     packmethod:byte;
     name:string[13];
    end;
   var
    header:headertype;
    count:byte;
    dir:array[1..256] of rectype;
    buf:pointer;
    code:longint;
    st:string[60];

   const
    cc=256;
    eoi=257;
   type
    rec=record
     ch:byte;
     len:byte;
     prev:smallint;
    end;
    mas=array[0..4099] of rec;
    PInt=^Longint;
    // Types for advanced compressor
    TreeNode=record
     prev:smallint;
     ch:byte;
     leaf:boolean;
    end;
   var
    tab:^mas;
    o,o2,ot:longint;

  function AdvCompress;
   type
    HashItem=record
     items:array of word;
     count:integer;
    end;
   var
    voc:array of TreeNode;
    b1,b2:PByte;
    ChainCount:integer;
    IndexToCode,CodeToIndex:array of word;
    top,bottom,prevChain:integer;
    i,j,k:integer;
    hash:array[0..255] of HashItem;
    CurHash:byte;
    b,ob:byte;
    code,index,outsize,curlength:integer;
    fl:boolean;
    deleted:array of word;
    DelCount,newPos:integer;
   procedure PutDigit(d:byte);
    begin
     if OutSize and 4>0 then begin // store major digit
      b2^:=b2^+d shl 4;
      inc(b2);
     end else // store minor digit
      b2^:=d;
     inc(outsize,4);
    end;
   procedure PutCode(code:integer);
    begin
     PutDigit(code and 15);
     if Code<128 then begin
      PutDigit(code shr 4);
      exit;
     end else
      PutDigit(((code and $70) shr 4) or 8);

     if code<1024 then begin
      PutDigit((code and $380) shr 7);
      exit;
     end else begin
      PutDigit(((code and $380) shr 7) or 8);
      PutDigit(code shr 10);
     end;
    end;
   begin
    SetLength(voc,16384);
    SetLength(IndexToCode,16384);
    SetLength(CodeToIndex,32768);
    SetLength(deleted,16384);
    delCount:=0;
    b1:=@sour;
    b2:=@dest;
    // Initialize hash
    for i:=0 to 255 do begin
     hash[i].count:=1;
     SetLength(hash[i].items,16);
     hash[i].items[0]:=i;
    end;
    // Initialize vocabulary with initial chains
    for i:=0 to 255 do begin
     voc[i].prev:=-1;
     voc[i].ch:=i;
     voc[i].leaf:=true;
     IndexToCode[i]:=i;
     CodeToIndex[i]:=i;
    end;
    top:=255; // index of topmost filled entry
    bottom:=0; // index of last used entry
    chaincount:=256; // number of allocated chains
    prevChain:=-1; CurHash:=0;
    outsize:=0; curlength:=0;
    for i:=1 to size do begin
     // Get byte from source stream
     b:=b1^; inc(b1);
     // Look if current chain can be extended
     inc(CurHash,b);
     fl:=false;
     if curLength<1024 then // maximal chain length limit
      for j:=0 to hash[curhash].count-1 do begin
       index:=hash[curhash].items[j];
       with voc[index] do
        if (prev=prevchain) and (ch=b) then begin
         // Chain can be extended => make it current and continue
         prevChain:=index;
         inc(curlength);
         fl:=true;
         break;
        end;
      end;
     if fl then continue;
     // Chain doesn't exists!
     // Put code to output
     code:=IndexToCode[prevChain];
     code:=(top-code) and $7FFF; // actual code
     if outsize>=bufsize*8-32 then begin
      result:=-1;
      exit;
     end;
     PutCode(code);

     // Check if we need to clean-up the vocabulary
     if Chaincount>=16383 then begin
      // Delete leaves from tree and all the structures
      // Stage 1: mark elements as deleted and correct links
      raise EError.Create('Too large vocabulary!');
     end; // End of vocabulary cleanup

     // Bring this chain to top
     code:=IndexToCode[prevChain]; // placement of PrevChain item in lookup array
     top:=(top+1) and $7FFF;
     IndexToCode[prevChain]:=top;
     CodeToIndex[top]:=PrevChain;
     CodeToIndex[code]:=CodeToIndex[bottom];
     IndexToCode[CodeToIndex[bottom]]:=code;
     bottom:=(bottom+1) and $7FFF;

     // Now extend chain and add it to hash
     inc(ChainCount);
     voc[ChainCount].prev:=prevChain;
     voc[chaincount].ch:=b;
     voc[chaincount].leaf:=true;
     voc[PrevChain].leaf:=false;

     if length(hash[curhash].items)=hash[curhash].count then
      SetLength(hash[curhash].items,hash[curhash].count+16);
     inc(hash[curhash].count);
     hash[curhash].items[hash[curhash].count-1]:=Chaincount;

     // Add newly created chain to top
     top:=(top+1) and $7FFF;
     CodeToIndex[top]:=ChainCount;
     IndexToCode[ChainCount]:=top;

     // Reset chain
     curhash:=b;
     // one-byte chains are never deleted thus their position can't change!
     prevChain:=b;
     curlength:=1;

    end; // foreach byte

    // Output code for last chain in order to finish
    code:=IndexToCode[prevChain];
    code:=top-code; // actual code
    PutCode(code);
    result:=outsize div 8+1;
   end;

  function AdvDecompress;
   var
    b1,b2:PByte;
    voc:array of TreeNode;
    CodeToIndex:array of word;
    top,bottom,i,j:integer;
    chain:array[0..1024] of byte;
    chSize,count,code,ind,LastChain,cnt:integer;
    b,parts:byte;
   function GetCode:integer;
    var
     fl:byte;
    begin
     result:=0;
     if parts=0 then begin
      b:=b1^; inc(b1);
      parts:=2; dec(cnt);
     end;
     code:=b and 15;
     b:=b shr 4;
     dec(parts);
     if parts=0 then begin
      b:=b1^; inc(b1);
      parts:=2; dec(cnt);
     end;
     code:=code+(b and 7) shl 4;
     fl:=b and 8;
     b:=b shr 4;
     dec(parts);
     if fl=0 then exit;

     if parts=0 then begin
      b:=b1^; inc(b1);
      parts:=2; dec(cnt);
     end;
     code:=code+(b and 7) shl 7;
     fl:=b and 8;
     b:=b shr 4;
     dec(parts);
     if fl=0 then exit;

     if parts=0 then begin
      b:=b1^; inc(b1);
      parts:=2; dec(cnt);
     end;
     code:=code+(b and 15) shl 10;
     b:=b shr 4;
     dec(parts);
    end;
   begin
    SetLength(voc,16384);
    for i:=0 to 255 do begin
     voc[i].prev:=-1;
     voc[i].ch:=i;
     voc[i].leaf:=true;
     CodeToIndex[i]:=i;
    end;
    top:=255; bottom:=0;
    b1:=@sour;
    b2:=@dest;
    parts:=0;
    b:=0;
    LastChain:=-1;
    cnt:=Size;
    repeat
     // Get code
     code:=GetCode;
     ind:=CodeToIndex[code];
     chSize:=1;
     chain[0]:=voc[ind].ch;
     // We should create new chain by adding this character to previous chain
     if (LastChain>=0) then begin

     end;
     LastChain:=ind;
     while voc[ind].prev>=0 do begin
      ind:=voc[ind].prev;
      chain[chsize]:=voc[ind].ch;
      inc(chsize);
     end;
     // Output chain
     for j:=chSize-1 downto 0 do begin
      b2^:=chain[j];
      inc(b2);
     end;
     dec(BufSize,chSize);
     if BufSize<=0 then
      raise EError.create('Out of buffer!');
    until cnt<=0;
   end;

  function ADPCMpack;
   var
    table:array[-130..130] of integer;
    i,j,k,n,min,max,curval,lastval,delta:integer;
    v:^SmallInt;
    v2:PByte;
    code:shortint;
    d,readybits,mask,pos:integer;
   begin
    case bits of
     4:begin min:=-8; max:=7; k:=100; n:=1; mask:=$F; end;
     6:begin min:=-32; max:=31; k:=30; n:=12; mask:=$3F; end;
     8:begin min:=-128; max:=127; k:=10; n:=300; mask:=$FF; end;
    end;
    table[min-1]:=-1000000;
    table[max+1]:=1000000;
    for i:=min to max do
     table[i]:=i*k+4*i*i*i div n;

    v:=@sour;  pos:=0; v2:=@dest;
    if (v^=$4952) then begin
     j:=integer(v);
     while PInt(j)^<>$61746164 do inc(j);
     inc(j,8);
     SkipHeader:=not SkipHeader;
     n:=j-integer(v);
     if SkipHeader then begin
       move(sour,dest,n);
       inc(v2,n); inc(pos,n);
     end;
     v:=pointer(j); 
    end else SkipHeader:=false;

    curval:=0; lastval:=0; readybits:=0; d:=0;
    for i:=1 to size1 div 2 do begin
     delta:=v^-lastval;
     delta:=delta+(lastval-curval) div 4;
     j:=min; k:=max;
     repeat
      if table[(j+k) div 2]<delta then j:=(j+k) div 2
       else k:=(j+k) div 2;
     until j>=k-1;
     if abs(delta-table[j])<abs(delta-table[k]) then
      code:=j else code:=k;
     d:=d+((code-min) and mask) shl readybits;
     inc(readybits,bits);
     if readybits>7 then begin
      v2^:=d and $ff;
      d:=d shr 8;
      dec(readybits,8);
      inc(v2); inc(pos);
     end;
     lastval:=v^; curval:=curval+table[code];
     inc(v);
    end;
    if readybits>0 then begin
     v2^:=d and $ff;
     inc(pos);
    end;
    result:=pos;
   end;

  function ADPCMunpack;
   var
    table:array[-130..130] of integer;
    i,k,n,min,max,curval:integer;
    v:^SmallInt;
    v2:PByte;
    code:integer;
    d,readybits,mask:integer;
   begin
    case bits of
     4:begin min:=-8; max:=7; k:=100; n:=1; mask:=$F; end;
     6:begin min:=-32; max:=31; k:=30; n:=12; mask:=$3F; end;
     8:begin min:=-128; max:=127; k:=10; n:=300; mask:=$FF; end;
    end;
    table[min-1]:=-1000000;
    table[max+1]:=1000000;
    for i:=min to max do
     table[i]:=i*k+4*i*i*i div n;

    v2:=@sour;  v:=@dest; curval:=0;
    if UseHeader and (v2^=$52) then begin
     i:=integer(v2);
     while PInt(i)^<>$61746164 do inc(i);
     n:=i-integer(v2);
     n:=n+8; i:=i+8;
     move(sour,dest,n);
     v2:=pointer(i);
     integer(v):=integer(v)+n;
     dec(size1,n);
    end;

    readybits:=8; d:=v2^; inc(v2);
    for i:=1 to size1 div 2 do begin
     code:=d and mask;
     dec(readybits,bits);
     d:=d shr bits;
     if readybits<=bits then begin
      d:=d+v2^ shl readybits;
      inc(v2);
      inc(readybits,8);
     end;
     curval:=curval+table[min+code];
     v^:=curval; inc(v);
    end;
    result:=size1;
   end;

  function lzwpack;
   label m;
   var
    curpos,maxcnt,curind,cntc,num:longint;
    bits,maxl,curlen,b:byte;
    fl:boolean;
    dat:rec;
    i:longint;
   procedure pushcode(code:word);
    const
     masks:array[9..12] of longint=(511,1023,2047,4095);
    var
     adr:longint;
     sof:byte;
     w,w2:longint;
    begin
     adr:=curpos shr 3;
     sof:=curpos and 7;
     w:=Longint(Ptr(o2+adr)^);
     w2:=not (masks[bits] shl sof);
     w:=w and w2;
     w2:=longint(code) shl sof;
     w:=w+w2;
     longint(ptr(o2+adr)^):=w;
     curpos:=curpos+bits;
    end;
   begin
    { initialize }
    maxl:=0; curind:=-1; bits:=9; maxcnt:=512;
    cntc:=257; curlen:=0;
    for i:=0 to 255 do begin
     tab^[i].ch:=i;
     tab^[i].len:=1;
     tab^[i].prev:=-1;
    end;
    size2:=0;
    curpos:=0;
    o:=longint(@sour); o2:=longint(@dest);
    ot:=longint(tab);
    { coding }
    repeat
     b:=PByte(o)^; inc(curlen); if maxl<curlen then maxl:=curlen;
     if curind<0 then begin fl:=true; num:=b end else begin
      fl:=off;
      asm
       pushad
       push word ptr curind
       mov al,b
       mov ah,curlen
       push ax
       pop eax
       mov edi,ot
       mov ebx,cntc
       mov ecx,ebx
       shl ebx,2
       add edi,ebx
       std
       repnz scasd
       jnz @001
       mov fl,1
       inc ecx
       mov num,ecx
@001:
       popad
       cld
      end;
     end;
     if curlen>61 then
      fl:=false;
     if fl then curind:=num else
     begin
      if cntc>=maxcnt-1 then begin
       if bits=12 then begin
{        if curind>256 then begin}
         pushcode(curind);
         curind:=b; curlen:=1;
{        end;                      }
        pushcode(cc);
        maxcnt:=512; bits:=9;
        cntc:=257; goto m;
       end else begin
        pushcode(cc);
        maxcnt:=maxcnt*2; inc(bits);
       end;
      end;
      with dat do begin
       prev:=curind;
       len:=curlen;
       ch:=b;
      end;
      inc(cntc); tab^[cntc]:=dat;

      pushcode(curind);
      curind:=b; curlen:=1;
     end;
m:   inc(o);
    until o>size1+longint(@sour);
    if fl then pushcode(curind);
    pushcode(eoi);
    size2:=curpos shr 3+1;
    lzwpack:=size2;
   end;
  function checksum;
   var
    sum:longint;
   begin
    asm
     pushad
     mov edi,p
     xor ebx,ebx
     xor eax,eax
     mov ecx,size
@01: mov al,[edi]
     xor al,cl
     add ebx,eax
     inc edi
     loop @01
     mov sum,ebx
     popad
    end;
    checksum:=sum;
   end;
  procedure encrypt;
   begin
    asm
     pushad
     mov edi,p
     mov ebx,code
     mov ecx,size
@01: mov eax,19
     mul ebx
     mov ebx,eax
     xor al,ah
     mov dl,[edi]
     xor dl,al
     mov [edi],dl
     inc edi
     loop @01
     popad
    end;
   end;

  function lzwunpack;
   const
    masks:array[9..12] of longint=(511,1023,2047,4095);
   var
    code,old,posit,adr,curpos,cntc:longint;
    st:array[0..64] of byte;
    bpos,bits,b:byte;
    i,j:longint;
   begin
    bits:=9;
    for i:=0 to 255 do
    with tab^[i] do begin
     prev:=-1;
     len:=i;
     ch:=i;
    end;
    cntc:=257;
    o:=longint(@sour);
    o2:=longint(@dest); size2:=0;
    code:=longint(Ptr(o)^) and masks[9]; posit:=o2;
    PByte(posit)^:=code; inc(posit);
    old:=code; curpos:=9;
    { get code }
     adr:=curpos shr 3;
     bpos:=curpos and 7;
     code:=(longint(Ptr(o+adr)^) shr bpos) and masks[bits];
     curpos:=curpos+bits;
    while code<>eoi do begin
     if code=cc then begin
      if bits<12 then inc(bits) else begin
       bits:=9; cntc:=257;
       adr:=curpos shr 3;
       bpos:=curpos and 7;
       code:=(longint(Ptr(o+adr)^) shr bpos) and masks[bits];
       curpos:=curpos+bits;
       Pbyte(posit)^:=code; inc(posit);
       old:=code;
      end;
      adr:=curpos shr 3;
      bpos:=curpos and 7;
      code:=(longint(Ptr(o+adr)^) shr bpos) and masks[bits];
      curpos:=curpos+bits;
     end;
     if code<=cntc then begin
      i:=0; j:=code;
      repeat
       inc(i); st[i]:=tab^[j].ch;
       j:=tab^[j].prev;
      until j<0;
      b:=st[i];
      for j:=i downto 1 do begin
       longint(Ptr(posit)^):=st[j];
       inc(posit);
      end;
      inc(cntc);
      with tab^[cntc] do begin
       ch:=b;
       prev:=old;
       len:=tab^[old].len;
      end;
     end else begin
      i:=1; j:=old;
      repeat
       inc(i); st[i]:=tab^[j].ch;
       j:=tab^[j].prev;
      until j<0;
      st[1]:=st[i];
      for j:=i downto 1 do begin
       PByte(posit)^:=st[j];
       inc(posit);
      end;
      inc(cntc);
      if code<>cntc then write('Error1 ');
      with tab^[cntc] do begin
       ch:=st[1];
       prev:=old;
       len:=tab^[old].len;
      end;
     end;
     old:=code;
     { get next code }
     adr:=curpos shr 3;
     bpos:=curpos and 7;
     code:=(longint(Ptr(o+adr)^) shr bpos) and masks[bits];
     curpos:=curpos+bits;
    end;
    size2:=posit-o2;
    lzwunpack:=size2;
   end;

  procedure opendatfile;
   begin
    Loaded:=false;
    st:=name;
    if pos('.',st)=0 then st:=st+'.dat';
    assignfile(datfile,st);
    reset(datfile,1);
    if (ioresult<>0) or (filesize(datfile)<16) then
     begin
{      MessageBox(hinstance,'','',0);
      exit;}
      LastDataError:=1;
      exit;
     end;
    blockread(datfile,header,16);
    with header do
     if (id[1]<>148) or (id[2]<>128) or (filesize(datfile)<>size) then
     begin
      LastDataError:=1;
      exit;
     end;
    count:=header.count;
    blockread(datfile,dir,count*32);
    encrypted:=header.encrypted;
    code:=filecode;
    loaded:=true;
   end;

  procedure closedatfile;
   begin
    if not loaded then exit;
    closefile(datfile);
    loaded:=off;
   end;

  function getdata;
   begin
    if n>header.count then begin
     buf:=nil;
     result:=0;
     exit;
    end;
    with dir[n] do begin
     getmem(p,size2+4);
     seek(datfile,start);
     getmem(buf,size1);
     blockread(datfile,buf^,size1);
     if encrypted then encrypt(buf^,size1,code);
     if checksum(buf^,size1) and $ffff<>sum1 then
     begin
      lastdataerror:=5;
      freemem(buf,size1); freemem(p,size2+4);
      buf:=nil; GetData:=0; exit;
     end;
     if (packmethod=0) then move(buf^,p^,size1);
     if (packmethod=1) then lzwunpack(buf^,p^);
     if (packmethod>20) and (packmethod<30) then
       ADPCMunpack(buf^,p^,size2,packmethod-20,false);
     if (packmethod>30) and (packmethod<40) then
       ADPCMunpack(buf^,p^,size2,packmethod-30,true);
     if (packmethod<10) and (checksum(p^,size2) and $ffff<>sum2) then begin
      lastdataerror:=6; freemem(buf,size1);
      getdata:=0; exit;
     end;
     freemem(buf,size1);
    end;
    getdata:=dir[n].size2;
   end;

  function findname;
   var
    i:longint;
    name:string[13];
   begin
    findname:=0;
    if not loaded then exit;
    name:=reqname;
    for i:=1 to count do
     if UpperCase(name)=UpperCase(dir[i].name) then begin
      findname:=i; exit; end;
    LastDataError:=2;
   end;

  function GetDataCount:integer;
   begin
    if not loaded then GetDataCount:=0
    else GetDataCount:=Header.count;
   end;

  function GetRecName;
   begin
    GetRecName:='';
    if (not loaded) or (n>header.count) then exit;
    GetRecName:=dir[n].name;
   end;

  function GetDataType;
   begin
    if (not loaded) or (n>header.count) then exit;
    GetDataType:=dir[n].sort;
   end;

 begin
{  errorproc:=nil;}
  new(tab);
 end.
