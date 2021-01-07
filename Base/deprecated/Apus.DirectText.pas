{$H+,I-,O+}
{$I+}

{ Модуль для вывода текста растровыми шрифтами }
{ Предназначен для работы с любыми буферами }
{ в формате 8, 16, 32 bpp при линейной модели памяти }
{ Автор: Ivan Polyacov, cooler@tut.by }
{$IFDEF FPC}{$PIC OFF}{$ENDIF}
unit Apus.DirectText;
interface
  const
   clipx1:longint=0;
   clipx2:longint=800;
   clipy1:longint=0;
   clipy2:longint=600;
  type
   fonttype=record
     name:string[9];
     fsize:word;
     xchar,ychar:byte;
     t:byte;
     chsize:byte;
     prop:array[32..255] of byte;
     data:pointer;
   end;
   // Режимы отсечения (если строка не влазит в область вывода)
   TClipMode=(cmPixel, // Обрезать попиксельно
              cmChar,  // по границе символов
              cmWord); // по границе слов (либо с вставкой переноса)

   TClippingState=record
    x1,y1,x2,y2:integer;
    mode:TClipMode;
   end;
   Str15=string[15];
   PRasterFont=^RasterFontType;
   RasterFontType=packed record
    id:cardinal;
    FontName:str15;
    Height,Width:byte;
    flags:byte;
    res:byte;
    CharSize:integer;
    CharCount:integer;
    CharImages:array[32..255] of byte;
    CharWidths:array[32..255] of byte;
    data:array[0..0] of byte;
   end;
  var
   fonts:array[1..10] of fonttype;
   fontnum,fontcnt,fontmode:byte;
   UseKerning:boolean;
   color1,color2,color3:longint; // Цвета
   colorgrad:array[0..31] of integer; // цвета для каждой линии (сверху вниз)
   grad_mode:boolean=false; // Режим градиента
   LastError:integer;
   LinAddr:longint;
   hsize,vsize:longint;
   bpline:longint;
   PixelFormat,shlval:integer; // 1,2 or 4 bytes length
   Is15bit:boolean=false;
   ClipMode:TClipMode=cmPixel;
   ClippingStack:array[0..31] of TClippingState;
   ClippingStackPos:integer=0;

   // Antialiased fonts support
   RasterFonts:array[1..30] of PRasterFont;
   fastcolors:array[0..15] of integer;
   curfont,rfontcnt,color:integer;

   // Загрузить шрифт из памяти (память не освобождать!)
  procedure registerfont(p:pointer);

   // Загрузить шрифт из файла
   // posit - позиция внутри файла
  procedure loadfont(name:string;posit:longint);

   // Выбрать шрифт из загруженных
  procedure setfont(n:byte);

  {$IFDEF CPU386}
   // Установить буфер вывода:
   // buf: адрес буфера,
   // width,height - размеры в пикселях
   // lpitch - смещение до начала  следующей строки (должно быть отрицательно для BMP)
   // depth - глубина цвета (число байт на пиксель)
  procedure SetBuffer(buf:pointer;width,height,lPitch,depth:integer);
  
   // Вывести строку, возвращает кол-во реально выведенных символов с учетом отсечения
  function wrtstr(x,y:longint;st:string):integer;

   // Вывести строку с центрированием
  function wrtStrCenter(x,y:longint;st:string):integer;

   // Вывести строку с выравниванием
  function wrtStrAlign(x1,x2,y:longint;st:string):integer;
  {$ENDIF}

   // Установить межсимвольный интервал
  procedure setfontmode(m:byte);

   // Определить длину строки в пикселях (текущий шрифт)
  function getstrlen(st:string):integer;

  // Определить на сколько пикселей нужно сдвинуться после вывода c1 чтобы вывести c2
  function GetCharDist(c1,c2:char):integer;

  // То же самое для сглаженного шрифта
  function GetCharDist2(c1,c2:char):integer;

   // Выдать высоту текущего шрифта
  function fonth:Byte;

  // Установить сглаженный шрифт в памяти
  function RegisterRasterFont(font:pointer):integer;

  // Загрузить шрифт из файла
  function LoadRasterFont(fname:string):integer;

  {$IFDEF CPU386}
  // Вывести строку качественно (настоящий альфа-канал), только для 32,16,15bpp
  function WrtBest(x,y:integer;st:string):integer;

   // Вывести строку быстро
  function WrtFast(x,y:integer;st:string):integer;

  // Just copy char images (for 8-bit targets only!)
  function WrtCopy(x,y:integer;st:string):integer;
  {$ENDIF}

   // Определить длину строки в пикселях (текущий сглаженный шрифт)
  function getstrlen2(st:string):integer;

   // Выдать высоту текущего сглаженного шрифта
  function fonth2:Byte;

  // Сохранить текущие настройки отсечения и установить данные
  procedure SetClipping(cx1,cy1,cx2,cy2:integer;ClMode:TClipMode=cmPixel);

  // Восстановить предыдущие настройки отсечения
  procedure RestoreClipping;

  // Обрезать строку так, чтобы она влазила в границы отсечения
  // будучи выведенной с позиции x
  function WrapStr(x:integer;var st:string;FontType:byte):integer;

  // Удалить из строки недопустимые символы
  procedure ValidateString(var st:string);

implementation
 uses SysUtils, Apus.MyServis;
 var
  writechar:procedure(x,y:longint;ch:char);

  {$IFDEF CPU386}
  procedure writechar8(x,y:longint;ch:char); forward;
  procedure writechar16(x,y:longint;ch:char); forward;
  procedure writechar32(x,y:longint;ch:char); forward;

  procedure SetBuffer(buf:pointer;width,height,lPitch,depth:integer); export;
   begin
    LinAddr:=longint(buf);
    hsize:=width; vsize:=height;
    bpline:=lPitch;
    PixelFormat:=depth;
    if depth=1 then begin
     shlval:=0;
     writechar:=@writechar8;
    end;
    if depth=2 then begin
     shlval:=1;
     writechar:=@writechar16;
    end;
    if depth=4 then begin
     shlval:=2;
     writechar:=@writechar32;
    end;
    if ClipX2>width then ClipX2:=width;
    if ClipY2>height then ClipY2:=height;
    if ClipX1<0 then ClipX1:=0;
    if ClipY1<0 then ClipY1:=0;
   end;
  {$ENDIF}

  procedure registerfont(p:pointer); export;
   begin
    if fontcnt>=10 then begin
     LastError:=2; exit;
    end;
    inc(fontcnt);
    move(p^,fonts[fontcnt],240);
    fonts[fontcnt].data:=pointer(longint(p)+240);
    fontnum:=fontcnt;
   end;
  procedure loadfont(name:string;posit:longint); export;
   var
    f:file;
   begin
    if fontcnt>=10 then begin
     LastError:=2; exit;
    end;
    assign(f,name);
    reset(f,1);
    seek(f,posit);
    if ioresult<>0 then begin
     LastError:=1; exit;
    end;
    inc(fontcnt);
    blockread(f,fonts[fontcnt],240);
    with fonts[fontcnt] do begin
     getmem(data,chsize*224);
     blockread(f,data^,chsize*224);
    end;
    close(f);
    inc(fonts[fontcnt].prop[32],2);
    fontnum:=fontcnt;
   end;
  procedure setfont(n:byte); export;
   begin
    if (n>100) and (n-100<rfontcnt) then begin
     curfont:=n-100;
    end else
    if n<=fontcnt then fontnum:=n;
   end;
  procedure setfcol(c1,c2,c3:byte); export;
   begin
    color1:=c1;
    color2:=c2;
    color3:=c3;
   end;

  procedure SetClipping;
   begin
    // Store current clipping settings
    with ClippingStack[ClippingStackPos] do begin
     x1:=CLipX1; y1:=CLipY1;
     x2:=ClipX2; y2:=ClipY2;
     mode:=ClipMode;
    end;
    // Set new clipping settings
    Clipx1:=cx1; Clipy1:=cy1;
    Clipx2:=cx2; Clipy2:=cy2;
    ClipMode:=ClMode;
    if ClippingStackPos<31 then inc(ClippingStackPos);
   end;

  procedure RestoreClipping;
   begin
    if ClippingStackPos=0 then exit;
    dec(ClippingStackPos);
    with ClippingStack[ClippingStackPos] do begin
     ClipX1:=x1; Clipy1:=y1;
     ClipX2:=x2; ClipY2:=y2;
     ClipMode:=mode;
    end;
   end;

  function fontH:byte; export;
   begin
    fontH:=fonts[fontnum].ychar;
   end;

  function fontH2:byte; export;
   begin
    fontH2:=RasterFonts[curfont].Height;
   end;

  function CanKerned(c:char):boolean;
   begin
    result:=false;
    if (c>='A') and (c<='Z') then begin result:=true; exit; end;
    if (c>='a') and (c<='z') then begin result:=true; exit; end;
    if (c>='А') and (c<='Я') then begin result:=true; exit; end;
    if (c>='а') and (c<='я') then begin result:=true; exit; end;
    if (c in ['(',')','/','[',']','{','}','?','Ё','ё','@']) then
      begin result:=true; exit; end;
   end;

  function GetCharDist;
   type
    PCard=^Cardinal;
   var
    i,j,k,delta,max,sum,o1,o2,d:integer;
    w1,w2,mask:cardinal;
   begin
    if not UseKerning then begin
     result:=fonts[fontnum].prop[byte(c1)]+fontmode;
    end else with fonts[fontnum] do begin
     if CanKerned(c1) and CanKerned(c2) then begin
      // Try to kern
      delta:=0;
      if xchar>8 then max:=2 else max:=1;
      o1:=longint(data)+(byte(c1)-32)*chsize;
      o2:=longint(data)+(byte(c2)-32)*chsize;
      d:=xchar div 4;
      mask:=$FFFFFFFF shr (32-xchar*2);
      for i:=1 to max do begin
       // Try to move to i pixels
       sum:=0;
       for j:=0 to ychar-1 do begin
        w1:=PCard(o1+j*d)^ and mask;
        w2:=PCard(o2+j*d)^ and mask;
        w1:=w1 shr ((prop[byte(c1)]-i)*2);
        w2:=w2;
        for k:=1 to i do begin
         if (w1 and 3>0) and (w2 and 3>0) then
          inc(sum,4-w1 and 3+4-w2 and 3);
         w1:=w1 shr 2;
         w2:=w2 shr 2;
        end;
       end;
       if sum<16 then delta:=i else break;
      end;
      result:=prop[byte(c1)]-delta+fontmode;
     end else
      result:=prop[byte(c1)]+fontmode;
    end;
   end;

  function GetCharDist2;
   type
    PCard=^Cardinal;
   var
    i,j,k,delta,max,sum,o1,o2,d,ofs:integer;
    w1,w2:Cardinal;
   begin
    if not UseKerning then begin
     result:=RasterFonts[curfont]^.CharWidths[byte(c1)]+fontmode;
    end else with RasterFonts[curfont]^ do begin
     if CanKerned(c1) and CanKerned(c2) then begin
      // Try to kern
      delta:=0;
      max:=(width-3) div 5;
      o1:=longint(addr(data))+CharSize*CharImages[byte(c1)];
      o2:=longint(addr(data))+CharSize*CharImages[byte(c2)];
      d:=width div 2;
      for i:=1 to max do begin
       // Try to move to i pixels
       sum:=0;
       ofs:=(CharWidths[byte(c1)]-i);
       for j:=0 to height-1 do begin
        w1:=PCard(o1+j*d+ofs div 2)^;
        w2:=PCard(o2+j*d)^;
        w1:=w1 shr 4*(ofs and 1);
        w2:=w2;
        for k:=1 to i do begin
         if (w1 and 15>0) and (w2 and 15>0) then
          inc(sum,16-w1 and 15+16-w2 and 15);
         w1:=w1 shr 4;
         w2:=w2 shr 4;
        end;
       end;
       if sum<(15+height div 2) then delta:=i else break;
      end;

//      if delta>FontMode then
       result:=CharWidths[byte(c1)]-delta+fontmode+1
{      else
       result:=RasterFonts[curfont]^.CharWidths[byte(c1)];}
     end else
     result:=RasterFonts[curfont]^.CharWidths[byte(c1)]+fontmode;
    end;
   end;

  {$IFDEF CPU386}
  procedure writechar8(x,y:longint;ch:char);
   var
    c1,c2,c3:byte;
    colormas:pointer;
    n,s,ysize:byte;
    cnt,d:longint;
    o:longint;
   begin
    if byte(ch)<32 then exit;
    c1:=color1; c2:=color2; c3:=color3; n:=byte(ch);
    s:=0; colormas:=@colorgrad;
    with fonts[fontnum] do begin
     cnt:=prop[n]; ysize:=ychar;
     if x+prop[n]<=clipx1 then exit;
     if x>=clipx2 then exit;
     if x<clipx1 then begin s:=clipx1-x; cnt:=cnt-(clipx1-x);
       x:=clipx1;  end;
     s:=s*2;
     if x+prop[n]>=clipx2 then cnt:=clipx2-x;
     o:=longint(data)+(n-32)*chsize;
     d:=xchar div 4;
     asm
      pushad
      push es
      mov eax,y
      mov ebx,bpline
      imul ebx
      add eax,x
      mov edi,eax
      add edi,linAddr

      mov dl,ysize
      mov esi,o
@01:
      cmp grad_mode,0
      jz @11
      mov eax,colormas
      mov al,[eax]
      mov c1,al
      add colormas,4
@11:  lodsd
      mov cl,s
      shr eax,cl
      mov ecx,cnt
      push edi
@02:
      mov dh,al
      and dh,3
      jz @06
      cmp dh,1
      jne @05
      mov dh,c1
      mov es:[edi],dh
      jmp @06
@05:  cmp dh,2
      jne @07
      mov dh,c2
      mov es:[edi],dh
      jmp @06
@07:  mov dh,c3
      mov es:[edi],dh
@06:  inc edi
      shr eax,2
      loop @02
      pop edi
      add edi,bpline
      sub esi,4
      add esi,d
      dec dl
      jnz @01
      pop es
      popad
     end;
    end;
   end;

  procedure writechar16(x,y:longint;ch:char);
   var
    c1,c2,c3:longint;
    colormas:pointer;
    n,s,ysize:byte;
    cnt,d:longint;
    o:longint;
   begin
    if byte(ch)<32 then exit;
    c1:=color1; c2:=color2; c3:=color3; n:=byte(ch);
    s:=0; colormas:=@colorgrad;
    with fonts[fontnum] do begin
     cnt:=prop[n]; ysize:=ychar;
     if x+prop[n]<=clipx1 then exit;
     if x>=clipx2 then exit;
     if x<clipx1 then begin s:=clipx1-x; cnt:=cnt-(clipx1-x);
       x:=clipx1;  end;
     s:=s*2;
     if x+prop[n]>=clipx2 then cnt:=clipx2-x;
     o:=longint(data)+(n-32)*chsize;
     d:=xchar div 4;
     asm
      pushad
      push es
      mov eax,y
      mov ebx,bpline
      imul ebx
      shl x,1
      add eax,x
      mov edi,eax
      add edi,linAddr

      mov dl,ysize
      mov esi,o
@01:  cmp grad_mode,0
      jz @11
      mov eax,colormas
      mov eax,[eax]
      mov c1,eax
      add colormas,4
@11:  lodsd
      mov cl,s
      shr eax,cl
      mov ecx,cnt
      push edi
@02:
      push edx
      mov dh,al
      and dh,3
      jz @06
      cmp dh,1
      jne @05
      mov dx,word ptr c1
      mov [edi],dx
      jmp @06
@05:  cmp dh,2
      jne @07
      mov dx,word ptr c2
      mov [edi],dx
      jmp @06
@07:  mov dx,word ptr c3
      mov [edi],dx
@06:  inc edi
      shr eax,2
      inc edi
      pop edx
      loop @02
      pop edi
      add edi,bpline
      sub esi,4
      add esi,d
      dec dl
      jnz @01
      pop es
      popad
     end;
    end;
   end;

  procedure writechar32(x,y:longint;ch:char);
   var
    c1,c2,c3:longint;
    colormas:pointer;
    n,s,ysize:byte;
    cnt,d:longint;
    o:longint;
   begin
    if byte(ch)<32 then exit;
    c1:=color1; c2:=color2; c3:=color3; n:=byte(ch);
    s:=0; colormas:=@colorgrad;
    with fonts[fontnum] do begin
     cnt:=prop[n]; ysize:=ychar;
     if x+prop[n]<=clipx1 then exit;
     if x>=clipx2 then exit;
     if x<clipx1 then begin s:=clipx1-x; cnt:=cnt-(clipx1-x);
       x:=clipx1;  end;
     s:=s*2;
     if x+prop[n]>=clipx2 then cnt:=clipx2-x;
     o:=longint(data)+(n-32)*chsize;
     d:=xchar div 4;
     asm
      pushad
      push es
      mov eax,y
      mov ebx,bpline
      imul ebx
      shl x,2
      add eax,x
      mov edi,eax
      add edi,linAddr

      mov dl,ysize
      mov esi,o
@01:  cmp grad_mode,0
      jz @11
      mov eax,colormas
      mov eax,[eax]
      mov c1,eax
      add colormas,4
@11:  lodsd
      mov cl,s
      shr eax,cl
      mov ecx,cnt
      push edi
@02:
      push edx
      mov dh,al
      and dh,3
      jz @06
      cmp dh,1
      jne @05
      mov edx,c1
      mov es:[edi],edx
      jmp @06
@05:  cmp dh,2
      jne @07
      mov edx,c2
      mov es:[edi],edx
      jmp @06
@07:  mov edx,c3
      mov es:[edi],edx
@06:  add edi,4
      shr eax,2
      pop edx
      loop @02
      pop edi
      add edi,bpline
      sub esi,4
      add esi,d
      dec dl
      jnz @01
      pop es
      popad
     end;
    end;
   end;
  {$ENDIF}

  // Обрезать строку так, чтобы она влазила в границы отсечения
  // будучи выведенной с позиции x
  function WrapStr(x:integer;var st:string;FontType:byte):integer;
   var
    LastGood,i,dx:integer;
   begin
    i:=1;
    LastGood:=0;
    // Ищем значение LastGood - номер последнего символа, после которого разрешен разрыв
    while (i<=length(st)) and (x<ClipX2) do begin
     // Дано: начало i-го символа в допустимых пределах.
     case ClipMode of
      cmPixel:LastGood:=i;
      cmChar:if (i>1) and (st[i-1]>' ') then LastGood:=i-1;
      cmWord:if (i>1) and ((st[i]=' ') or (st[i-1] in ['-',',','.','!','+','='])) then
               LastGood:=i-1;
     end;
     case FontType of
      0:begin // 4-color fonts
         if i<length(st) then
          inc(x,GetCharDist(st[i],st[i+1]))
         else
          inc(x,GetStrLen(st[i]));
        end;
      1:begin // Antialiased fonts
         if i<length(st) then
          inc(x,GetCharDist2(st[i],st[i+1]))
         else
          inc(x,GetStrLen2(st[i]));
        end;
     end;
     inc(i);
    end;
    if x<ClipX2 then begin // Вся строка влезла!
     result:=length(st);
     exit;
    end;
    result:=LastGood;
    if (x<ClipX2) then begin
     LastGood:=length(st);
    end;
    if (ClipMode=cmWord) and ((LastGood=0) or (i-LastGood>8)) then begin
     dec(i);
     // Попытка принудительного переноса
     case FontType of
      0:dx:=GetCharDist(st[i],'-');
      1:dx:=GetCharDist2(st[i],'-');
     end;
     while (x+dx>=ClipX2) do begin
      case FontType of
      0:begin
         if i=length(st) then
          dec(x,GetStrLen(st[i]))
         else
          dec(x,GetCharDist(st[i],st[i+1]));
        end;
      1:begin
         if i=length(st) then
          dec(x,GetStrLen2(st[i]))
         else
          dec(x,GetCharDist2(st[i],st[i+1]));
        end;
      end;
      dec(i);
      case FontType of
       0:dx:=GetCharDist(st[i],'-');
       1:dx:=GetCharDist2(st[i],'-');
      end;
     end;
     st[i+1]:='-';
     LastGood:=i+1;
     result:=i;
    end;
    SetLength(st,LastGood);
   end;

  {$IFDEF CPU386}
  function wrtstr(x,y:longint;st:string):integer; export;
   var
    i:longint;
   begin
    result:=WrapStr(x,st,0);
    for i:=1 to length(st) do begin
     writechar(x,y,st[i]);
     if i<length(st) then
      x:=x+GetCharDist(st[i],st[i+1]);
    end;
   end;

  function wrtstrCenter(x,y:longint;st:string):integer; export;
   begin
    result:=WrtStr(x-GetStrLen(st) div 2,y,st);
   end;

  function wrtstrAlign(x1,x2,y:longint;st:string):integer; export;
   var
    i,len:longint;
    dx,ddx:single;
   begin
    if length(st)=0 then exit;
    WrapStr(x1,st,0);
    result:=Length(st);
    len:=GetStrLen(st);
    if (x2-x1<Len) or (x2-x1>Len+32) then
     WrtStr(x1,y,st) else
    begin
     dx:=0;
     ddx:=(x2-x1-len)/length(st);
     for i:=1 to length(st) do begin
      writechar(x1+round(dx),y,st[i]);
      x1:=x1+fonts[fontnum].prop[byte(st[i])]+fontmode;
      dx:=dx+ddx;
     end;
    end;
   end;
   {$ENDIF}

  procedure setfontmode(m:byte); export;
   begin
    fontmode:=m;
   end;

  function getstrlen(st:string):integer; export;
   var
    l,i:longint;
   begin
    if length(st)>0 then
     l:=fonts[fontnum].prop[byte(st[length(st)])]
    else l:=0;
    for i:=1 to length(st)-1 do
     l:=l+GetCharDist(st[i],st[i+1]);
    getstrlen:=l+1;
   end;

  function getstrlen2(st:string):integer; export;
   var
    l,i:longint;
   begin
    if length(st)>0 then
      l:=RasterFonts[curfont].CharWidths[byte(st[length(st)])]
    else l:=0;
    for i:=1 to length(st)-1 do
     l:=l+GetCharDist2(st[i],st[i+1]);
    getstrlen2:=l;
   end;

  function getfontnum(name:string):integer; export;
   var
    i:longint;
   begin
    for i:=1 to fontcnt do
     if fonts[i].name=name then begin
      getfontnum:=i; exit;
     end;
    getfontnum:=0;
   end;

 function RegisterRasterFont;
  begin
   if font=nil then
    raise EError.Create('Invalid font pointer');
   if rfontcnt<20 then begin
    inc(rfontcnt);
    RasterFonts[rfontcnt]:=font;
    result:=rfontcnt+100;
    curfont:=rFontCnt;
   end else result:=0;
  end;

function LoadRasterFont(fname:string):integer;
  var
   f:file;
   buffer:pointer;
   size:integer;
  begin
   fname:=FileName(fname);
   assign(f,fname);
   buffer:=nil;
   try
   reset(f,1);
   if IOResult<>0 then begin
    result:=0; exit;
   end;
   size:=filesize(f);
   getmem(buffer,size);
   blockread(f,buffer^,size);
   close(f);
   result:=RegisterRasterFont(buffer);
   except
    on e:exception do ErrorMessage('E1: '+e.message+' file '+fname);
   end;
  end;

 {$IFDEF CPU386}
 function WrtBest(x,y:integer;st:string):integer;
  var
   i:integer;

  procedure PrintChar32(x,y:integer;ch:char);
   var
    o,o2:cardinal;
    h,w,c:integer;
   begin
    if (x>=ClipX2) or (y>=ClipY2) then exit;
    if byte(ch)<32 then exit;
    o:=RasterFonts[curfont]^.CharImages[byte(ch)];
    o:=cardinal(addr(RasterFonts[curfont]^.data))+o*RasterFonts[curfont]^.CharSize;
    h:=RasterFonts[curfont]^.Height;
    w:=RasterFonts[curfont]^.width;
    if (x<ClipX1-w) or (y<ClipY1-h) then exit;
    c:=RasterFonts[curfont]^.CharWidths[byte(ch)];
    o2:=LinAddr+y*bpline+x*4;
    w:=w div 2;
    asm
     pushad
     db $0F,$EF,$FF           /// pxor mm7,mm7
     mov eax,color
     db $0F,$6E,$F0           /// movd mm6,eax
     db $0F,$60,$F7           /// punpcklbw mm6,mm7
     xor ecx,ecx
     mov cl,byte ptr h
     mov edi,o2
     mov esi,o
     mov ebx,y
@LoopY:
     cmp ebx,ClipY1
     jl @SkipLine
     cmp ebx,CLipY2
     jge @SkipLine
     push edi
     push esi
     push ecx
     push ebx
     // Draw a scanline
     xor ecx,ecx
     mov edx,x
@LoopX:
     test ecx,1
     jnz @DontLoad
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift
@DontLoad:
     shr al,4
@DontShift:
     test al,0Fh
     jz @SkipPixel
     cmp edx,ClipX1
     jl @SkipPixel
     cmp edx,ClipX2
     jge @SkipPixel

     push eax
     and al,0fh
     cmp al,0fh
     jne @Alpha
     mov ebx,color
     mov [edi],ebx
     pop eax
     jmp @SkipPixel
@Alpha:
     and al,$0F
     db $0F,$6E,$07           /// movd mm0,[edi]
     mov ah,al
     db $0F,$60,$C7           /// punpcklbw mm0,mm7
     shl eax,8
     db $0F,$6F,$EE           /// movq mm5,mm6
     mov al,ah
     db $0F,$F9,$E8           /// psubw mm5,mm0
     shl eax,8
     mov al,ah
     db $0F,$6E,$E0           /// movd mm4,eax
     db $0F,$60,$E7           /// punpcklbw mm4,mm7

     db $0F,$D5,$EC           /// pmullw mm5,mm4
     db $0F,$71,$E5,$04       /// psraw mm5,4
     db $0F,$FD,$C5           /// paddw mm0,mm5
     db $0F,$67,$C7           /// packuswb mm0,mm7
     db $0F,$7E,$07           /// movd [edi],mm0

     pop eax
@SkipPixel:
     add edi,4
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX

     pop ebx
     pop ecx
     pop esi
     pop edi
@SkipLine:
     inc ebx
     add edi,bpline
     add esi,w
     dec cl
     jnz @LoopY

     popad
     db $0F,$77               /// emms
    end;
   end;

  procedure PrintChar16(x,y:integer;ch:char);
   var
    o,o2:cardinal;
    h,w,c:integer;
    color2:word;
   begin
    if (x>=ClipX2) or (y>=ClipY2) then exit;
    if byte(ch)<32 then exit;
    o:=RasterFonts[curfont]^.CharImages[byte(ch)];
    o:=cardinal(addr(RasterFonts[curfont]^.data))+o*RasterFonts[curfont]^.CharSize;
    h:=RasterFonts[curfont]^.Height;
    w:=RasterFonts[curfont]^.width;
    if (x<ClipX1-w) or (y<ClipY1-h) then exit;
    c:=RasterFonts[curfont]^.CharWidths[byte(ch)];
    o2:=LinAddr+y*bpline+x*2;
    w:=w div 2;
    color2:=(color shr 3) and $1F+(color shr 5) and $7E0+(color shr 8) and $F800;
    asm
     pushad
     db $0F,$EF,$FF           /// pxor mm7,mm7
     mov eax,color
     db $0F,$6E,$F0           /// movd mm6,eax
     db $0F,$60,$F7           /// punpcklbw mm6,mm7
     xor ecx,ecx
     mov cl,byte ptr h
     mov edi,o2
     mov esi,o
     mov ebx,y
@LoopY:
     cmp ebx,ClipY1
     jl @SkipLine
     cmp ebx,CLipY2
     jge @SkipLine
     push edi
     push esi
     push ecx
     push ebx
     // Draw a scanline
     xor ecx,ecx
     mov edx,x
@LoopX:
     test ecx,1
     jnz @DontLoad
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift
@DontLoad:
     shr al,4
@DontShift:
     test al,0Fh
     jz @SkipPixel
     cmp edx,ClipX1
     jl @SkipPixel
     cmp edx,ClipX2
     jge @SkipPixel

     push eax
     and al,0Fh
     cmp al,0Fh
     jne @Alpha
     // Clean color
     mov bx,color2
     mov [edi],bx
     pop eax
     jmp @SkipPixel
     // Need alpha-blending
@Alpha:
     // al = alpha
     db $0F,$6E,$D3           /// movd mm2,ebx
     movzx ebx,word ptr [edi]
     shl ebx,5
     and al,0Fh
     shr bx,3
     mov ah,al
     shr bl,2
     shl eax,8
     and ebx,1F1F1Fh
     mov al,ah
     shl ebx,3
     db $0F,$6E,$E0           /// movd mm4,eax
     db $0F,$6E,$C3           /// movd mm0,ebx
     db $0F,$60,$C7           /// punpcklbw mm0,mm7
     db $0F,$6F,$EE           /// movq mm5,mm6
     db $0F,$60,$E7           /// punpcklbw mm4,mm7
     db $0F,$F9,$E8           /// psubw mm5,mm0
     db $0F,$D5,$EC           /// pmullw mm5,mm4
     db $0F,$71,$E5,$04       /// psraw mm5,4
     db $0F,$FD,$C5           /// paddw mm0,mm5

     db $0F,$67,$C7           /// packuswb mm0,mm7
     db $0F,$7E,$C3           /// movd ebx,mm0
     shr ebx,3
     shl bl,2
     shl bx,3
     shr ebx,5
     mov [edi],bx
     db $0F,$7E,$D3           /// movd ebx,mm2
     pop eax
@SkipPixel:
     add edi,2
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX

     pop ebx
     pop ecx
     pop esi
     pop edi
@SkipLine:
     inc ebx
     add edi,bpline
     add esi,w
     dec cl
     jnz @LoopY

     popad
     db $0F,$77               /// emms
    end;
   end;

  procedure PrintChar15(x,y:integer;ch:char);
   var
    o,o2:cardinal;
    h,w,c:integer;
    color2:word;
   begin
    if (x>=ClipX2) or (y>=ClipY2) then exit;
    if byte(ch)<32 then exit;
    o:=RasterFonts[curfont]^.CharImages[byte(ch)];
    o:=cardinal(addr(RasterFonts[curfont]^.data))+o*RasterFonts[curfont]^.CharSize;
    h:=RasterFonts[curfont]^.Height;
    w:=RasterFonts[curfont]^.width;
    if (x<ClipX1-w) or (y<ClipY1-h) then exit;
    c:=RasterFonts[curfont]^.CharWidths[byte(ch)];
    o2:=LinAddr+y*bpline+x*2;
    w:=w div 2;
    color2:=(color shr 3) and $1F+(color shr 6) and $3E0+(color shr 9) and $7C00;
    asm
     pushad
     db $0F,$EF,$FF           /// pxor mm7,mm7
     mov eax,color
     db $0F,$6E,$F0           /// movd mm6,eax
     db $0F,$60,$F7           /// punpcklbw mm6,mm7
     xor ecx,ecx
     mov cl,byte ptr h
     mov edi,o2
     mov esi,o
     mov ebx,y
@LoopY:
     cmp ebx,ClipY1
     jl @SkipLine
     cmp ebx,CLipY2
     jge @SkipLine
     push edi
     push esi
     push ecx
     push ebx
     // Draw a scanline
     xor ecx,ecx
     mov edx,x
@LoopX:
     test ecx,1
     jnz @DontLoad
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift
@DontLoad:
     shr al,4
@DontShift:
     test al,0Fh
     jz @SkipPixel
     cmp edx,ClipX1
     jl @SkipPixel
     cmp edx,ClipX2
     jge @SkipPixel

     push eax
     and al,0Fh
     cmp al,0Fh
     jne @Alpha
     // Clean color
     mov bx,color2
     mov [edi],bx
     pop eax
     jmp @SkipPixel
     // Need alpha-blending
@Alpha:
     // al = alpha
     db $0F,$6E,$D3           /// movd mm2,ebx
     movzx ebx,word ptr [edi]
     shl ebx,6
     and al,0Fh
     shr bx,3
     mov ah,al
     shr bl,3
     shl eax,8
     mov al,ah
     shl ebx,3
     db $0F,$6E,$E0           /// movd mm4,eax
     db $0F,$6E,$C3           /// movd mm0,ebx
     db $0F,$60,$C7           /// punpcklbw mm0,mm7
     db $0F,$6F,$EE           /// movq mm5,mm6
     db $0F,$60,$E7           /// punpcklbw mm4,mm7
     db $0F,$F9,$E8           /// psubw mm5,mm0
     db $0F,$D5,$EC           /// pmullw mm5,mm4
     db $0F,$71,$E5,$04       /// psraw mm5,4
     db $0F,$FD,$C5           /// paddw mm0,mm5

     db $0F,$67,$C7           /// packuswb mm0,mm7
     db $0F,$7E,$C3           /// movd ebx,mm0
     shr ebx,3
     shl bl,3
     shl bx,3
     shr ebx,6
     mov [edi],bx
     db $0F,$7E,$D3           /// movd ebx,mm2
     pop eax
@SkipPixel:
     add edi,2
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX

     pop ebx
     pop ecx
     pop esi
     pop edi
@SkipLine:
     inc ebx
     add edi,bpline
     add esi,w
     dec cl
     jnz @LoopY

     popad
     db $0F,$77               /// emms
    end;
   end;

  begin
   if st='' then exit;
   if (curfont<1) or (curfont>rfontcnt) then exit;
   result:=WrapStr(x,st,1);
   dec(y,RasterFonts[curfont].flags and 3);
   for i:=1 to length(st) do begin
    if PixelFormat=4 then PrintChar32(x,y,st[i]);
    if (PixelFormat=2) and (not Is15Bit) then PrintChar16(x,y,st[i]);
    if (PixelFormat=2) and (Is15Bit) then PrintChar15(x,y,st[i]);
    if i<length(st) then
     inc(x,GetCharDist2(st[i],st[i+1]));
   end;
  end;

 function WrtCopy(x,y:integer;st:string):integer;
  var
   i:integer;

  procedure PrintChar1(x,y:integer;ch:char);
   var
    o,o2:cardinal;
    h,w,c,yc:integer;
   begin
    if (x>=ClipX2) or (y>=ClipY2) then exit;
    if byte(ch)<32 then exit;
    o:=RasterFonts[curfont]^.CharImages[byte(ch)];
    o:=cardinal(addr(RasterFonts[curfont]^.data))+o*RasterFonts[curfont]^.CharSize;
    h:=RasterFonts[curfont]^.Height;
    w:=RasterFonts[curfont]^.Width;
    if (x<ClipX1-w) or (y<ClipY1-h) then exit;
    c:=RasterFonts[curfont]^.CharWidths[byte(ch)];
    o2:=LinAddr+y*bpline+x;
    w:=w div 2;
    asm
     pushad
     mov edx,h
     mov esi,o
     mov edi,o2
@01: xor ecx,ecx
     push esi
     push edi
@inner:
     test cl,1
     jnz @02
     lodsb
     jmp @03
@02: shr al,4
@03: mov bl,al
//     mov bh,bl
     shl bl,4
{     and bh,0Fh
     add bl,bh}
     mov [edi],bl
     inc edi
     inc ecx
     cmp ecx,c
     jne @inner
     pop edi
     pop esi
     add edi,bpline
     add esi,w
     dec edx
     jnz @01
     popad
    end;
   end;

  begin
   if st='' then exit;
   if (curfont<1) or (curfont>rfontcnt) then exit;
   result:=WrapStr(x,st,1);
   dec(y,RasterFonts[curfont].flags and 3);
   for i:=1 to length(st) do begin
    PrintChar1(x,y,st[i]);
    if i<length(st) then
     inc(x,GetCharDist2(st[i],st[i+1]));
//    inc(x,FontMode);
   end;
  end;

 function WrtFast(x,y:integer;st:string):integer;
  var
   i:integer;

  procedure PrintChar1(x,y:integer;ch:char);
   var
    o,o2:cardinal;
    h,w,c:integer;
   begin
    if (x>=ClipX2) or (y>=ClipY2) then exit;
    if byte(ch)<32 then exit;
    o:=RasterFonts[curfont]^.CharImages[byte(ch)];
    o:=cardinal(addr(RasterFonts[curfont]^.data))+o*RasterFonts[curfont]^.CharSize;
    h:=RasterFonts[curfont]^.Height;
    w:=RasterFonts[curfont]^.width;
    if (x<ClipX1-w) or (y<ClipY1-h) then exit;
    c:=RasterFonts[curfont]^.CharWidths[byte(ch)];
    o2:=LinAddr+y*bpline+x*PixelFormat;
    w:=w div 2;
    asm
     pushad
     xor ecx,ecx
     mov cl,byte ptr h
     mov edi,o2
     mov esi,o
     mov ebx,y
@LoopY:
     cmp ebx,ClipY1
     jl @SkipLine
     cmp ebx,CLipY2
     jge @SkipLine
     push edi
     push esi
     push ecx
     push ebx
     // Draw a scanline
     xor ecx,ecx
     xor eax,eax
     mov edx,x
     cmp PixelFormat,4
     jne @Not32bpp

     // 32bpp version
@LoopX:
     test ecx,1
     jnz @DontLoad
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift
@DontLoad:
     shr al,4
@DontShift:
     push eax
     and al,0fh
     cmp al,2
     jbe @SkipPixel
     cmp edx,ClipX1
     jl @SkipPixel
     cmp edx,ClipX2
     jge @SkipPixel

     // Write pixel
     mov ebx,eax
     and ebx,0Fh
     mov ebx,dword ptr [FastColors+ebx*4]
     mov [edi],ebx

@SkipPixel:
     pop eax
     add edi,4
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX
     jmp @EndOfInner

@Not32bpp:
     cmp PixelFormat,2
     jne @Not16bpp

     // 16bpp version
@LoopX2:
     test ecx,1
     jnz @DontLoad2
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift2
@DontLoad2:
     shr al,4
@DontShift2:
     cmp al,2
     jbe @SkipPixel2
     cmp edx,ClipX1
     jl @SkipPixel2
     cmp edx,ClipX2
     jge @SkipPixel2

     // Write pixel
     mov ebx,eax
     and ebx,0Fh
     mov ebx,dword ptr [FastColors+ebx*4]
     mov word ptr [edi],bx

@SkipPixel2:
     add edi,2
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX2
     jmp @EndOfInner

@Not16bpp:
     // 8bpp version
@LoopX3:
     test ecx,1
     jnz @DontLoad3
     mov al,[esi] // now al is $BA
     inc esi
     jmp @DontShift3
@DontLoad3:
     shr al,4
@DontShift3:
     cmp al,2
     jbe @SkipPixel3
     cmp edx,ClipX1
     jl @SkipPixel3
     cmp edx,ClipX2
     jge @SkipPixel3

     // Write pixel
     mov ebx,eax
     and ebx,0Fh
     mov bl,byte ptr [FastColors+ebx*4]
     mov byte ptr [edi],bl

@SkipPixel3:
     inc edi
     inc edx
     inc ecx
     cmp ecx,c
     jne @LoopX3
@EndOfInner:

     pop ebx
     pop ecx
     pop esi
     pop edi
@SkipLine:
     inc ebx
     add edi,bpline
     add esi,w
     dec cl
     jnz @LoopY
     popad
    end;
   end;

  begin
   if st='' then exit;
   if (curfont<1) or (curfont>rfontcnt) then exit;
   result:=WrapStr(x,st,1);
   dec(y,RasterFonts[curfont].flags and 3);
   for i:=1 to length(st) do begin
    PrintChar1(x,y,st[i]);
    if i<length(st) then
     inc(x,GetCharDist2(st[i],st[i+1]));
   end;
  end;
  {$ENDIF}

 procedure ValidateString;
  var
   i:integer;
  begin
   i:=1;
   while i<length(st) do
    if byte(st[i])<32 then
     delete(st,i,1)
    else inc(i);
  end;

 begin
  fontcnt:=0;
  fontmode:=1;
  LastError:=0;
  curfont:=0;
  rfontcnt:=0;
  useKerning:=false;
end.

