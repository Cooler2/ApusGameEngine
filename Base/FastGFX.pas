// Optimized drawing routines
//
// Copyright (C) 2004-2014 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
{$IFDEF FPC}
{$PIC OFF}
{$ENDIF}
{$R-}
unit FastGFX;
interface
 uses Geom2d,types;
type
 // Процедура рисования простой горизонтальной линии (без отсечения, x2>=x1)
 THLine=procedure(buf:pointer;pitch:integer;x1,x2,y:integer;color:cardinal); pascal;
 // Процедура рисования простой вертикальной линии (без отсечения, y2>=y1)
 TVLine=procedure(buf:pointer;pitch:integer;x,y1,y2:integer;color:cardinal); pascal;

 // Процедура рисования простой линии (без отсечения)
 TSimpleLine=procedure(buf:pointer;pitch:integer;x1,y1,x2,y2:integer;color:cardinal); pascal;

 TColorConv=function(color:cardinal):cardinal;

 // Функция смешения цвета слоя с цветом подложки
 TBlenderFunc=function(background,foreground:cardinal):cardinal;

var
 blBlend,blCopy:TBlenderFunc;
 blender:TBlenderFunc;

 // Горизонтальная линия - цвет задается в формате приемника!
 procedure HLine32(buf:pointer;pitch:integer;x1,x2,y:integer;color:cardinal); pascal;
 procedure HLine16(buf:pointer;pitch:integer;x1,x2,y:integer;color:cardinal); pascal;

 // Вертикальная линия - цвет задается в формате приемника!
 procedure VLine32(buf:pointer;pitch:integer;x,y1,y2:integer;color:cardinal); pascal;
 procedure VLine16(buf:pointer;pitch:integer;x,y1,y2:integer;color:cardinal); pascal;

 // Линия рисуется прямым копированием цвета (цвет задается в формате приемника!)
 procedure SimpleLine32(buf:pointer;pitch:integer;x1,y1,x2,y2:integer;color:cardinal); pascal;
 procedure SimpleLine16(buf:pointer;pitch:integer;x1,y1,x2,y2:integer;color:cardinal); pascal;

 // Линия рисуется с учетом прозрачности цвета (цвет задается в режиме RGBA!)
 procedure SimpleLine32A(buf:pointer;pitch:integer;x1,y1,x2,y2:integer;color:cardinal); pascal;
 procedure SimpleLine16A(buf:pointer;pitch:integer;x1,y1,x2,y2:integer;color:cardinal); pascal;


 // Преобразование 32-битного ARGB-цвета в заданный формат
 function ColorTo32(color:cardinal):cardinal;
 function ColorTo24(color:cardinal):cardinal;
 function ColorTo16(color:cardinal):cardinal;
 function ColorTo15A(color:cardinal):cardinal;
 function ColorTo15(color:cardinal):cardinal;
 function ColorTo12(color:cardinal):cardinal;

 // Получение 32-битного ARGB-цвета из заданного формата
 function ColorFrom32(color:cardinal):cardinal;
 function ColorFrom24(color:cardinal):cardinal;
 function ColorFrom16(color:cardinal):cardinal;
 function ColorFrom15A(color:cardinal):cardinal;
 function ColorFrom15(color:cardinal):cardinal;
 function ColorFrom12(color:cardinal):cardinal;

 // Преобразование строки 32-битных ARGB-пикселей в строку заданного формата
 procedure PixelsTo24(var sour,dest;count:integer); pascal;
 procedure PixelsTo16(var sour,dest;count:integer); pascal;
 procedure PixelsTo15A(var sour,dest;count:integer); pascal;
 procedure PixelsTo15(var sour,dest;count:integer); pascal;
 procedure PixelsTo12(var sour,dest;count:integer); pascal;

 // Преобразование строки заданного формата в строку 32-битных ARGB-пикселей
 procedure PixelsFrom24(var sour,dest;count:integer); pascal;
 procedure PixelsFrom16(var sour,dest;count:integer); pascal;
 procedure PixelsFrom15A(var sour,dest;count:integer); pascal;
 procedure PixelsFrom15(var sour,dest;count:integer); pascal;
 procedure PixelsFrom12(var sour,dest;count:integer); pascal;
 procedure PixelsFrom8P(var sour,dest,palette;count:integer); pascal; // Палитра 32-битная!
 procedure PixelsFrom8P24(var sour,dest,palette;count:integer); pascal; // Палитра 24-битная (медленно!)

 // Calculates address of 32-bit pixel
 function GetPixelAddr(buf:pointer;pitch,x,y:integer):pointer;
 // Calculates address of 8-bit pixel
 function GetPixelAddr8(buf:pointer;pitch,x,y:integer):pointer;

 // Calculate cropping rect for an image
 function CropImage(sour:pointer;sPitch:integer;width,height:integer):TRect;

 // Copy rectangular area of 32bpp pixels from one surface to another surface
 // (аналогично SimpleDraw с blMove)
 procedure CopyRect(sour:pointer;sPitch:integer;
                    dest:pointer;dPitch:integer;
                    x,y,width,height:integer;
                    targetX,targetY:integer);

 // Аналогично, но позволяет делать поворот на 90 и flip за счет указания смещения пикселя в источнике
 procedure CopyRectEx(sour:pointer;sNext,sPitch:integer;
                      dest:pointer;dPitch:integer;
                      x,y,width,height:integer;
                      targetX,targetY:integer);


 // Copy rectangular area of 8bpp pixels from one surface to another surface
 procedure CopyRect8(sour:pointer;sPitch:integer;
                     dest:pointer;dPitch:integer;
                     x,y,width,height:integer;
                     targetX,targetY:integer);

 // Аналогично, но позволяет делать поворот на 90 и flip за счет указания смещения пикселя в источнике
 procedure CopyRect8Ex(sour:pointer;sNext,sPitch:integer;
                       dest:pointer;dPitch:integer;
                       x,y,width,height:integer;
                       targetX,targetY:integer);


 // Заполнение прямоугольника заданным цветом (буфер любой 32-битный)
 // Fills all pixel in range [x1..x2, y1..y2]
 procedure FillRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal); overload;

 // То же с использованием функции блендинга
 procedure FillRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc); overload;

 // То же - в текущий render target, с проверками координат (отсечение) и альфа-блендингом 
 procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); overload;
 procedure FillRect(x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc); overload;

 // Отрисовка периметра
 procedure DrawRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc);

 // Заполнение цветом используя заданный альфаканал (замена фона)
 procedure FillUsingAlpha(buf:pointer;pitch:integer;
                          alpha:pointer;aPitch:integer;
                          width,height:integer;
                          color:cardinal);

 // Заполнение цветом используя заданный альфаканал (блендинг цвета на фон)
 procedure BlendUsingAlpha(buf:pointer;pitch:integer;
                          alpha:pointer;aPitch:integer;
                          width,height:integer;
                          color:cardinal;
                          blender:TBlenderFunc);

 // Заполняет область width*height в dest смешанным изображением, таким что
 // вероятность пикселей из sour1 линейно убывает, а вероятность пикселей из sour2 - возрастает
 procedure TransitionRect(sour1:pointer;sPitch1:integer;
                          sour2:pointer;sPitch2:integer;
                          dest:pointer;dPitch:integer;
                          width,height:integer;
                          horizontal:boolean;
                          blender:TBlenderFunc);

 // Отрисовка в ARGB (без клиппинга!)
 procedure SimpleDraw(sour:pointer;sPitch:integer;
                      dest:pointer;dPitch:integer;
                      x,y, // точка вывода в dest
                      width,height:integer; // размер рисуемого изображения
                      blender:TBlenderFunc);

 // Аналогично, но позволяет делать поворот на 90 и flip за счет указания смещения адреса след. пикселя в источнике
 procedure SimpleDrawEx(sour:pointer;sNext,sPitch:integer;
                        dest:pointer;dPitch:integer;
                        x,y, // точка вывода в dest
                        width,height:integer; // размер рисуемого изображения
                        blender:TBlenderFunc);


 // Отрисовка с билинейной интерполяцией (ОСТОРОЖНО С ТЕКСТУРНЫМИ К-МИ ПРИ РАСТЯЖЕНИИ!)
 procedure StretchDraw(sour:pointer;sPitch:integer; // текстура
                       dest:pointer;dPitch:integer;
                       x1,y1,x2,y2:integer; // область вывода в dest (целочисленная!)
                       u1,v1,u2,v2:single;  // текстурные к-ты, соответствующие краям области вывода
                       blender:TBlenderFunc);   // (в текселях! т.е. [0.5,0.5] - центр углового текселя)

 // Вариант для целочисленного растяжения: параметры таковы, что 1-й пиксел строго совпадает с 1-м текселом
 // а последний пиксел - с последним текселом. Степень растяжения при этом нарушается.
 procedure StretchDraw1(sour:pointer;sPitch:integer; // текстура
                        dest:pointer;dPitch:integer;
                        x1,y1,x2,y2:integer;   // область вывода в dest (в целых пикселях)
                        u1,v1,u2,v2:integer;   // область текстуры (в целых текселях)
                        blender:TBlenderFunc);

 // Более привычная форма, соответствующая отрисовке прямоугольника из текстуры на произвольный прямоугольник
 procedure StretchDraw2(sour:pointer;sPitch:integer; // текстура
                        dest:pointer;dPitch:integer;
                        x1,y1,x2,y2:single;   // область вывода в dest
                        u1,v1,u2,v2:integer;  // текстурные к-ты, соответствующие краям области вывода
                        blender:TBlenderFunc);

 // Производит уменьшение в 2 раза (ARGB)
 procedure DownSample2X(sour:pointer;sPitch:integer;
                        dest:pointer;dPitch:integer;
                        width,height:integer); // размеры исходного изображения

 // Производит уменьшение в 2 раза (8bit)
 procedure DownSample2X8(sour:pointer;sPitch:integer;
                         dest:pointer;dPitch:integer;
                         width,height:integer); // размеры исходного изображения

 procedure SetRenderTarget(buf:pointer;pitch:integer;width,height:integer);

 procedure DrawPixel(x,y:integer;color:cardinal);
 procedure DrawPixelAA(x,y:single;color:cardinal);
 procedure SmoothLine(x1,y1,x2,y2:single;color:cardinal;width:single=1.0); // width = 0.5-1.5
 procedure Arc(x,y,r,fromA,toA:single;color:cardinal;width:single=1.0);
 procedure Circle(x,y,r:single;color:cardinal;width:single=1.0);
 procedure FillCircle(x,y,r:single;color:cardinal);
 procedure PieSlice(x,y,r,a1,a2:single;color:cardinal); // angles are clockwise from 0hr (Y direction)
 procedure DrawPolyline(points:PPoint2s;count:integer;closed:boolean;color:cardinal;width:single=1.0);
 procedure FillPolygon(points:PPoint2s;count:integer;color:cardinal); // not yet implemented

implementation
 uses CrossPlatform,{$IFDEF ANDROID}MyServis,SysUtils,{$ENDIF}colors,math;

threadvar
 // Место для отрисовки по умолчанию
 rBuf:pointer;
 rPitch:integer; // в пикселях!
 rWidth,rHeight:integer;


{$IFDEF CPU386}
const
 Alpha1:int64=$0100010001000100; // 4 слова по 100h
 MaskW0:int64=$000000000000FFFF;
 MaskW1:int64=$00000000FFFF0000;
 MaskW2:int64=$0000FFFF00000000;
 MaskW3:int64=$FFFF000000000000;
 HighByte:cardinal=$1000000;
{$ENDIF}

 procedure SetRenderTarget(buf:pointer;pitch:integer;width,height:integer);
  begin
   rBuf:=buf;
   rPitch:=pitch div 4;
   rWidth:=width;
   rHeight:=height;
   blender:=blBlend;
  end;

 procedure HLine32;
  {$IFDEF CPU386}
  asm
   pushad
   // Адрес начала
   mov eax,y
   imul pitch
   mov edi,x2
   inc edi
   shl edi,2
   add edi,eax
   add edi,buf
   mov ecx,x2
   sub ecx,x1
   not ecx
   mov eax,color
@inner:
   mov [edi+ecx*4],eax
   inc ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure HLine16;
  {$IFDEF CPU386}
  asm
   pushad
   // Адрес начала
   mov eax,y
   imul pitch
   mov edi,x2
   inc edi
   shl edi,1
   add edi,eax
   add edi,buf
   mov ecx,x2
   sub ecx,x1
   not ecx
   mov eax,color
@inner:
   mov [edi+ecx*2],ax
   inc ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure VLine32;
  {$IFDEF CPU386}
  asm
   pushad
   // Адрес начала
   mov eax,y1
   imul pitch
   mov edi,x
   shl edi,2
   add edi,eax
   add edi,buf
   mov ecx,y2
   sub ecx,y1
   mov eax,color
   inc ecx
@inner:
   mov [edi],eax
   add edi,pitch
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure VLine16;
  {$IFDEF CPU386}
  asm
   pushad
   // Адрес начала
   mov eax,y1
   imul pitch
   mov edi,x
   shl edi,1
   add edi,eax
   add edi,buf
   mov ecx,y2
   sub ecx,y1
   mov eax,color
   inc ecx
@inner:
   mov [edi],ax
   add edi,pitch
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  begin
  end;
  {$ENDIF}

 procedure SimpleLine32A; {$IFDEF CPU386}
  var
   l,d,dir,NextPix,NextLine:integer;
  begin
    asm
     pushad
     // Определить направления и углы
     mov edi,pitch
     mov esi,4
     mov eax,x2
     sub eax,x1
     mov ebx,y2
     sub ebx,y1
     mov ecx,eax
     or ecx,ecx
     jge @n1
     neg ecx
     neg esi
@n1: mov edx,ebx
     or edx,edx
     jge @n2
     neg edx
     neg edi
@n2:
     cmp ecx,edx // горизонтальность участка
     jae @n3
     xchg edx,ecx
     xchg edi,esi
@n3: mov l,ecx
     mov d,edx
     mov NextPix,esi
     mov NextLine,edi

     inc ecx
     // Calculate address of the first pixel
     mov eax,y1
     imul pitch
     mov edi,x1
     shl edi,2
     add edi,eax
     add edi,buf

     mov edx,l
     shr edx,1
     // загрузить альфаканал
     pxor mm7,mm7 // константа 0
     movd mm6,HighByte

     xor ebx,ebx
     mov bl,byte ptr color+3
     mov bh,bl
     shl ebx,8
     mov bl,bh
     movd mm1,ebx // 0AAA
     punpcklbw mm1,mm6 // mm1 - альфа фона (100 0AA 0AA 0AA)
     movq mm2,Alpha1
     psubw mm2,mm1 // альфа цвета (старшее слово - 00 1-A 1-A 1-A)

     // Загрузить цвет
     movd mm0,color
     punpcklbw mm0,mm7
     pmullw mm0,mm2 // Сколько нужно прибавить к цвету фона
@inner:
     movd mm3,[edi]
     // Вычислить цвет точки
     punpcklbw mm3,mm7 // mm1 - цвет фона
     pmullw mm3,mm1   // Доля цвета фона
     paddw mm3,mm0   // pre-multiplied цвет точки
     psrlw mm3,8
     packuswb mm3,mm7
     movd [edi],mm3

     // Go to next pixel
     add edx,d
     cmp edx,l // Should we go to next scanline
     jl @01
     add edi,NextLine
     sub edx,l
@01: add edi,NextPix
     dec ecx
     jnz @inner
     popad
     emms
    end;
  end;
{$ELSE}
  begin

  end;
{$ENDIF}

 procedure SimpleLine16A;
  {$IFDEF CPU386}
  var
   i,l,d,dir,NextPix,NextLine:integer;
  begin

    asm
     pushad
     // Определить направления и углы
     mov edi,pitch
     mov esi,2
     mov eax,x2
     sub eax,x1
     mov ebx,y2
     sub ebx,y1
     mov ecx,eax
     or ecx,ecx
     jge @n1
     neg ecx
     neg esi
@n1: mov edx,ebx
     or edx,edx
     jge @n2
     neg edx
     neg edi
@n2:
     cmp ecx,edx // горизонтальность участка
     jae @n3
     xchg edx,ecx
     xchg edi,esi
@n3: mov l,ecx
     mov d,edx
     mov NextPix,esi
     mov NextLine,edi

     inc ecx
     // Calculate address of the first pixel
     mov eax,y1
     imul pitch
     mov edi,x1
     shl edi,2
     add edi,eax
     add edi,buf

     mov edx,l
     shr edx,1
     // загрузить альфаканал
     pxor mm7,mm7 // константа 0
     movd mm6,HighByte

     xor ebx,ebx
     mov bl,byte ptr color+3
     mov bh,bl
     shl ebx,8
     mov bl,bh
     movd mm1,ebx // 0AAA
     punpcklbw mm1,mm6 // mm1 - альфа фона (100 0AA 0AA 0AA)
     movq mm2,Alpha1
     psubw mm2,mm1 // альфа цвета (старшее слово - 00 1-A 1-A 1-A)

     // Загрузить цвет
     movd mm0,color
     punpcklbw mm0,mm7
     pmullw mm0,mm2 // Сколько нужно прибавить к цвету фона
@inner:
     push edx
     push ecx
     movzx eax,word ptr [edi]
     // Распаковать цвет
     call ColorFrom16
     movd mm3,eax
     // Вычислить цвет точки
     pmullw mm3,mm1   // Доля цвета фона
     paddw mm3,mm0   // pre-multiplied цвет точки

     psrlw mm3,8
     packuswb mm3,mm7
     movd eax,mm3
     call ColorTo16
     mov [edi],ax
     pop ecx
     pop edx

     // Go to next pixel
     add edx,d
     cmp edx,l // Should we go to next scanline
     jl @01
     add edi,NextLine
     sub edx,l
@01: add edi,NextPix
     dec ecx
     jnz @inner
     popad
     emms
    end;
  end;
{$ELSE}
  begin

  end;
{$ENDIF}

 procedure SimpleLine32;
 {$IFDEF CPU386}
  var
   i,l,d,NextPix,NextLine:integer;
  begin
    asm
     pushad
     // Определить направления и углы
     mov edi,pitch
     mov esi,4
     mov eax,x2
     sub eax,x1
     mov ebx,y2
     sub ebx,y1
     mov ecx,eax
     or ecx,ecx
     jge @n1
     neg ecx
     neg esi
@n1: mov edx,ebx
     or edx,edx
     jge @n2
     neg edx
     neg edi
@n2:
     cmp ecx,edx // горизонтальность участка
     jae @n3
     xchg edx,ecx
     xchg edi,esi
@n3: mov l,ecx
     mov d,edx
     mov NextPix,esi
     mov NextLine,edi

     mov ebx,color
     inc ecx // на одну точку больше
     // Calculate address of the first pixel
     mov eax,y1
     imul pitch
     mov edi,x1
     shl edi,2
     add edi,eax
     add edi,buf

     mov edx,l
     shr edx,1
@inner:
     mov [edi],ebx // Draw pixel
     // Go to next pixel
     add edx,d
     cmp edx,l // Should we go to next scanline
     jl @01
     add edi,NextLine
     sub edx,l
@01: add edi,NextPix
     dec ecx
     jnz @inner
     popad
    end;
  end;
{$ELSE}
  begin

  end;
{$ENDIF}

 procedure SimpleLine16;
  {$IFDEF CPU386}
  var
   i,l,d,NextLine,NextPix:integer;
  begin
    asm
     pushad
     // Определить направления и углы
     mov edi,pitch
     mov esi,2
     mov eax,x2
     sub eax,x1
     mov ebx,y2
     sub ebx,y1
     mov ecx,eax
     or ecx,ecx
     jge @n1
     neg ecx
     neg esi
@n1: mov edx,ebx
     or edx,edx
     jge @n2
     neg edx
     neg edi
@n2:
     cmp ecx,edx // горизонтальность участка
     jae @n3
     xchg edx,ecx
     xchg edi,esi
@n3: mov l,ecx
     mov d,edx
     mov NextPix,esi
     mov NextLine,edi

     mov ebx,color
     inc ecx // на одну точку больше
     // Calculate address of the first pixel
     mov eax,y1
     imul pitch
     mov edi,x1
     shl edi,1
     add edi,eax
     add edi,buf

     mov edx,l
     shr edx,1
@inner:
     mov [edi],bx // Draw pixel
     // Go to next pixel
     add edx,d
     cmp edx,l // Should we go to next scanline
     jl @01
     add edi,NextLine
     sub edx,l
@01: add edi,NextPix
     dec ecx
     jnz @inner
     popad
    end;
  end;
{$ELSE}
 begin

 end;
{$ENDIF}


 function ColorTo32(color:cardinal):cardinal;
  begin
   result:=color;
  end;
 function ColorTo24(color:cardinal):cardinal;
  begin
   result:=color and $FFFFFF;
  end;
 function ColorTo16(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   mov edx,eax
   mov ecx,eax
   shr eax,3
   shr ecx,8+2-5
   shr edx,16+3-11
   and eax,$1F
   and ecx,$7E0
   and edx,$F800
   or eax,ecx
   or eax,edx
  end;
  {$ELSE}
  begin
    result:=((color shr 3) and $1F)+((color shr 5) and $7E0)+((color shr 8) and $F800);
  end;
  {$ENDIF}
 function ColorTo15A(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   push ebx
   mov edx,eax
   mov ecx,eax
   xor ebx,ebx
   cmp eax,$80000000
   jb @01
   mov ebx,$8000
@01:
   shr eax,3
   shr ecx,8+3-5
   shr edx,16+3-10
   and eax,$1F
   and ecx,$3E0
   and edx,$7C00
   or eax,ecx
   or eax,edx
   or eax,ebx
   pop ebx
  end;
  {$ELSE}
  begin
    if color>=$80000000 then
     result:=((color shr 3) and $1F)+((color shr 6) and $3E0)+((color shr 9) and $7C00)+$8000
    else result:=0;
  end;
  {$ENDIF}
 function ColorTo15(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   mov edx,eax
   mov ecx,eax
   shr eax,3
   shr ecx,8+3-5
   shr edx,16+3-10
   and eax,$1F
   and ecx,$3E0
   and edx,$7C00
   or eax,ecx
   or eax,edx
  end;
  {$ELSE}
  begin
    result:=((color shr 3) and $1F)+((color shr 6) and $3E0)+((color shr 9) and $7C00);
  end;
  {$ENDIF}
 function ColorTo12(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   push ebx
   mov edx,eax
   mov ecx,eax
   mov ebx,eax
   shr eax,4
   shr ecx,8+4-4
   shr edx,16+4-8
   shr ebx,24+4-12
   and eax,$F
   and ecx,$F0
   and edx,$F00
   and ebx,$F000
   or eax,ecx
   or eax,edx
   or eax,ebx
   pop ebx
  end;
  {$ELSE}
  begin
    result:=((color shr 4) and $F)+((color shr 8) and $F0)+((color shr 12) and $F00)+((color shr 16) and $F000);
  end;
  {$ENDIF}

 function ColorFrom32(color:cardinal):cardinal;
  begin
   result:=color;
  end;
 function ColorFrom24(color:cardinal):cardinal;
  begin
   result:=color and $FFFFFF;
  end;
 function ColorFrom16(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   mov edx,eax
   mov ecx,eax
   shl eax,3
   shl edx,5
   shl ecx,8
   and eax,$F8
   and edx,$FC00
   and ecx,$F80000
   or eax,edx
   or eax,ecx
  end;
  {$ELSE}
  begin
    result:=(color shl 3) and $F8+(color shl 5) and $FC00+(color shl 8) and $F80000;
  end;
  {$ENDIF}
 function ColorFrom15A(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   push ebx
   mov edx,eax
   mov ecx,eax
   mov ebx,eax
   shl eax,3
   shl edx,6
   shl ecx,9
   shl ebx,16
   and eax,$F8
   and edx,$F800
   and ecx,$F80000
   and ebx,$80000000
   or eax,edx
   or eax,ecx
   or eax,ebx
   pop ebx
  end;
  {$ELSE}
  begin
    result:=(color shl 3) and $F8+(color shl 5) and $FC00+(color shl 8) and $F80000;
    if color and $8000>0 then color:=color+$FF000000;
  end;
  {$ENDIF}
 function ColorFrom15(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   mov edx,eax
   mov ecx,eax
   shl eax,3
   shl edx,6
   shl ecx,9
   and eax,$F8
   and edx,$F800
   and ecx,$F80000
   or eax,edx
   or eax,ecx
  end;
  {$ELSE}
  begin
    result:=(color shl 3) and $F8+(color shl 5) and $FC00+
            (color shl 8) and $F80000+$FF000000;
  end;
  {$ENDIF}
 function ColorFrom12(color:cardinal):cardinal;
  {$IFDEF CPU386}
  asm
   mov ecx,eax
   mov edx,eax
   shl ecx,12
   shl edx,8
   and ecx,$F000;
   and edx,$F00000;
   or edx,ecx
   mov ecx,eax
   shl ecx,16
   shl eax,4
   and ecx,$F0000000;
   or edx,ecx
   and eax,$F0
   or eax,edx
  end;
  {$ELSE}
  begin
    result:=(color and $F)*$11+(color and $F0)*$110+(color and $F00)*$1100+
            (color and $F000)*$11000;
  end;
  {$ENDIF}

 procedure PixelsTo24(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
{@inner1:
   cmp ecx,4
   jb @theRest
   movq mm0,[esi]
   movq mm1,[esi+8]

   add esi,16
   add edi,12
   sub ecx,4
@theRest:}

@inner:
   mov eax,[esi]
   add esi,4
   mov [edi],ax
   shr eax,16
   mov [edi+2],al
   add edi,3
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp,dp:PByte;
   i:integer;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count*4 do begin
    if i and 3<>0 then begin
     dp^:=sp^; inc(dp);
    end;
    inc(sp);
   end;
  end;
  {$ENDIF}

 procedure PixelsTo16(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   mov eax,[esi]
   add esi,4
   mov edx,eax
   mov ebx,eax
   shr eax,3
   shr ebx,8+2-5
   shr edx,16+3-11
   and eax,$1F
   and ebx,$7E0
   and edx,$F800
   or eax,ebx
   or eax,edx
   mov [edi],ax
   add edi,2
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PCardinal;
   dp:Pword;
   i:integer;
  begin
   sp:=@sour;
   dp:=@dest;
   for i:=1 to count do begin
    dp^:=((sp^ shr 3) and $1F)+
         ((sp^ shr 5) and $7E0)+
         ((sp^ shr 8) and $F800);
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsTo15A(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   mov eax,[esi]
   push ecx
   add esi,4
   mov edx,eax
   mov ecx,eax
   mov ebx,eax
   shr eax,3
   shr ecx,6
   shr edx,9
   shr ebx,16
   and eax,$1F
   and ecx,$3E0
   and edx,$7C00
   and ebx,$8000
   or eax,ecx
   or eax,edx
   or eax,ebx
   mov [edi],ax
   pop ecx
   add edi,2
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PCardinal;
   dp:Pword;
   i:integer;
  begin
   sp:=@sour;
   dp:=@dest;
   for i:=1 to count do begin
    dp^:=((sp^ shr 3) and $1F)+
         ((sp^ shr 6) and $3E0)+
         ((sp^ shr 9) and $7C00)+
         ((sp^ shr 16) and $8000);
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsTo15(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   mov eax,[esi]
   add esi,4
   mov edx,eax
   mov ebx,eax
   shr eax,3
   shr ebx,6
   shr edx,9
   and eax,$1F
   and ebx,$3E0
   and edx,$7C00
   or eax,ebx
   or eax,edx
   mov [edi],ax
   add edi,2
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PCardinal;
   dp:Pword;
   i:integer;
  begin
   sp:=@sour;
   dp:=@dest;
   for i:=1 to count do begin
    dp^:=((sp^ shr 3) and $1F)+
         ((sp^ shr 6) and $3E0)+
         ((sp^ shr 9) and $7C00);
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsTo12(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   mov eax,[esi]
   push ecx
   add esi,4
   mov edx,eax
   mov ecx,eax
   mov ebx,eax
   shr eax,4
   shr ecx,8
   shr edx,12
   shr ebx,16
   and eax,$0F
   and ecx,$F0
   and edx,$0F00
   and ebx,$F000
   or eax,ecx
   or eax,edx
   or eax,ebx
   mov [edi],ax
   add edi,2
   pop ecx
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PCardinal;
   dp:Pword;
   i:integer;
  begin
   sp:=@sour;
   dp:=@dest;
   for i:=1 to count do begin
    dp^:=((sp^ shr 4) and $F)+
         ((sp^ shr 8) and $F0)+
         ((sp^ shr 12) and $F00)+
         ((sp^ shr 16) and $F000);
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}

 procedure PixelsFrom24(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   movzx eax, word ptr [esi]
   movzx ebx, byte ptr [esi+2]
   or eax,0FF000000h
   add esi,3
   shl ebx,16
   or eax,ebx
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PByte;
   dp:PCardinal;
   i:integer;
   c:cardinal;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count do begin
    c:=sp^; inc(sp);
    c:=c+sp^ shl 8; inc(sp);
    c:=c+sp^ shl 16; inc(sp);
    dp^:=c+$FF000000;
    inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsFrom16(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   movzx eax,word ptr[esi]
   add esi,2
   mov edx,eax
   mov ebx,eax
   shl eax,3
   shl edx,5
   shl ebx,8
   and eax,$F8
   and edx,$FC00
   or eax,0FF000000h
   and ebx,$F80000
   or eax,edx
   or eax,ebx
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PWord;
   dp:PCardinal;
   i:integer;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count do begin
    dp^:=(sp^ and $F800) shl 8+
         (sp^ and $7E0) shl 5+
         (sp^ and $1F) shl 3+$FF000000;
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsFrom15A(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   movsx eax,word ptr[esi]
   add esi,2
   mov edx,eax
   mov ebx,eax
   shl eax,3
   shl edx,5
   shl ebx,8
   and eax,$FF0000F8
   and edx,$FC00
   and ebx,$F80000
   or eax,edx
   or eax,ebx
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PWord;
   dp:PCardinal;
   i:integer;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count do begin
    dp^:=(sp^ and $7C00) shl 9+
         (sp^ and $3E0) shl 6+
         (sp^ and $1F) shl 3+
         $FF000000*byte(sp^ and $8000<>0);
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}

 procedure PixelsFrom15(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   movzx eax,word ptr[esi]
   add esi,2
   mov edx,eax
   mov ebx,eax
   shl eax,3
   shl edx,5
   shl ebx,8
   and eax,$F8
   and edx,$FC00
   or eax,0FF000000h
   and ebx,$F80000
   or eax,edx
   or eax,ebx
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PWord;
   dp:PCardinal;
   i:integer;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count do begin
    dp^:=(sp^ and $7C00) shl 9+
         (sp^ and $3E0) shl 6+
         (sp^ and $1F) shl 3+$FF000000;
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsFrom12(var sour,dest;count:integer);
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
@inner:
   movzx eax,word ptr[esi]
   push ecx
   add esi,2
   mov edx,eax
   mov ebx,eax
   mov ecx,eax
   shl edx,4
   shl ebx,8
   shl ecx,12
   and eax,$F
   and edx,$F00
   and ebx,$F0000
   and ecx,$F000000
   or eax,edx
   or eax,ebx
   or eax,ecx
   mov ebx,eax
   shl ebx,4
   or eax,ebx
   mov [edi],eax
   add edi,4
   pop ecx
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   sp:PWord;
   dp:PCardinal;
   i:integer;
   c:cardinal;
  begin
   sp:=@sour; dp:=@dest;
   for i:=1 to count do begin
    c:=(sp^ and $F)+
       (sp^ and $F0) shl 4+
       (sp^ and $F00) shl 8+
       (sp^ and $F000) shl 12;
    dp^:=c+c shl 4;
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}

 procedure PixelsFrom8P(var sour,dest,palette;count:integer); // Палитра 32-битная!
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   mov ebx,palette
@inner:
   movzx eax,byte ptr [esi]
   inc esi
   mov eax,[ebx+eax*4]
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  type
   TPal=array[0..255] of cardinal;
  var
   i:integer;
   sp:PByte;
   dp:PCardinal;
   pal:^TPal;
  begin
   sp:=@sour; dp:=@dest; pal:=@palette;
   for i:=1 to count do begin
    dp^:=pal[sp^];
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}
 procedure PixelsFrom8P24(var sour,dest,palette;count:integer); // Палитра 24-битная (медленно!)
  {$IFDEF CPU386}
  asm
   pushad
   mov esi,sour
   mov edi,dest
   mov ecx,count
   mov ebx,palette
@inner:
   movzx eax,byte ptr [esi]
   inc esi
   mov edx,eax
   shl edx,1
   add edx,eax
   mov al,[ebx+edx+2]
   shl eax,16
   mov ax,[ebx+edx]
   or eax,$FF000000
   mov [edi],eax
   add edi,4
   dec ecx
   jnz @inner
   popad
  end;
  {$ELSE}
  var
   i:integer;
   sp:PByte;
   dp:PCardinal;
   pal:PByte;
   c:cardinal;
  begin
   sp:=@sour; dp:=@dest; pal:=@palette;
   for i:=1 to count do begin
    pal:=@palette; inc(pal,sp^*3);
    c:=$FF000000+pal^; inc(pal);
    c:=c+pal^ shl 8; inc(pal);
    c:=c+pal^ shl 16;
    inc(sp); inc(dp);
   end;
  end;
  {$ENDIF}

 function CropImage(sour:pointer;sPitch:integer;width,height:integer):TRect;
  var
   x,y,minX,maxX,minY,maxY:integer;
   pc:PCardinal;
  begin
   minX:=width; minY:=height; maxX:=0; maxY:=0;
   for y:=0 to height-1 do begin
    pc:=sour; inc(pc,y*sPitch div 4);
    for x:=0 to width-1 do begin
     if pc^ and $FF000000<>0 then begin
      if x<minX then minX:=x;
      if y<minY then minY:=y;
      if x>maxX then maxX:=x;
      if y>maxY then maxY:=y;
     end;
     inc(pc);
    end;
   end;
   if minX>maxX then begin // empry image -> crop to 1x1 px from center
    minX:=width div 2; maxX:=minX;
    minY:=height div 2; maxY:=minY+1;
   end;
   result:=Rect(minX,minY,maxX+1,maxY+1);
  end;

 function GetPixelAddr(buf:pointer;pitch,x,y:integer):pointer;
  begin
   result:=pointer(PtrUInt(buf)+pitch*y+x*4);
  end;

 function GetPixelAddr8(buf:pointer;pitch,x,y:integer):pointer;
  begin
   result:=pointer(PtrUInt(buf)+pitch*y+x);
  end;

 procedure CopyRect8(sour:pointer;sPitch:integer;
                     dest:pointer;dPitch:integer;
                     x,y,width,height:integer;
                     targetX,targetY:integer);
  var
   sp,dp:PByte;
   i:integer;
  begin
   sp:=sour; inc(sp,y*sPitch+x);
   dp:=dest; inc(dp,targetY*dPitch+targetX);
   for i:=1 to height do begin
    move(sp^,dp^,width);
    inc(sp,sPitch); inc(dp,dPitch);
   end;
  end;

 procedure CopyRect(sour:pointer;sPitch:integer;
                    dest:pointer;dPitch:integer;
                    x,y,width,height:integer;
                    targetX,targetY:integer);
  var
   sp,dp:PByte;
   i:integer;
  begin
   sp:=sour; inc(sp,y*sPitch+x*4);
   dp:=dest; inc(dp,targetY*dPitch+targetX*4);
   for i:=1 to height do begin
    move(sp^,dp^,width*4);
    inc(sp,sPitch); inc(dp,dPitch);
   end;
  end;

 procedure CopyRectEx(sour:pointer;sNext,sPitch:integer;
                      dest:pointer;dPitch:integer;
                      x,y,width,height:integer;
                      targetX,targetY:integer);
  var
   sp,spp,dp:PByte;
   i,j:integer;
  begin
   sp:=sour; inc(sp,y*sPitch+x*sNext);
   dp:=dest; inc(dp,targetY*dPitch+targetX*4);
   for i:=1 to height do begin
    spp:=sp;
    for j:=1 to width do begin
     PCardinal(dp)^:=PCardinal(spp)^;
     inc(spp,sNext); inc(dp,4);
    end;
    inc(sp,sPitch); inc(dp,dPitch-4*width);
   end;
  end;

 procedure CopyRect8Ex(sour:pointer;sNext,sPitch:integer;
                       dest:pointer;dPitch:integer;
                       x,y,width,height:integer;
                       targetX,targetY:integer);
  var
   sp,spp,dp:PByte;
   i,j:integer;
  begin
   sp:=sour; inc(sp,y*sPitch+x*sNext);
   dp:=dest; inc(dp,targetY*dPitch+targetX);
   for i:=1 to height do begin
    spp:=sp;
    for j:=1 to width do begin
     dp^:=spp^;
     inc(spp,sNext); inc(dp);
    end;
    inc(sp,sPitch); inc(dp,dPitch-width);
   end;
  end;


 procedure FillRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal);
  var
   x,y:integer;
   p1,p2:PCardinal;
  begin
   p1:=buf;
   pitch:=pitch shr 2;
   inc(p1,x1+pitch*y1);
   for y:=y1 to y2 do begin
    p2:=p1;
    for x:=x1 to x2 do begin
     p2^:=color; inc(p2);
    end;
    inc(p1,pitch);
   end;
  end;

 procedure FillRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc);
  var
   x,y:integer;
   p1,p2:PCardinal;
  begin
   p1:=buf;
   pitch:=pitch shr 2;
   inc(p1,x1+pitch*y1);
   for y:=y1 to y2 do begin
    p2:=p1;
    for x:=x1 to x2 do begin
     p2^:=blender(p2^,color); inc(p2);
    end;
    inc(p1,pitch);
   end;
  end;

 procedure FillRect(x1,y1,x2,y2:integer;color:cardinal); overload;
  begin
   if rBuf=nil then exit;
   if x1<0 then x1:=0;
   if y1<0 then y1:=0;
   if x2>=rWidth then x2:=rWidth-1;
   if y2>=rHeight then y2:=rHeight-1;             
   if (x2<x1) or (y2<y1) then exit;
   FillRect(rBuf,rPitch shl 2,x1,y1,x2,y2,color,blBlend);
  end;

 procedure FillRect(x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc); overload;
  begin
   if rBuf=nil then exit;
   if x1<0 then x1:=0;
   if y1<0 then y1:=0;
   if x2>=rWidth then x2:=rWidth-1;
   if y2>=rHeight then y2:=rHeight-1;
   if (x2<x1) or (y2<y1) then exit;
   FillRect(rBuf,rPitch shl 2,x1,y1,x2,y2,color,blender);
  end;

 procedure DrawRect(buf:pointer;pitch:integer; x1,y1,x2,y2:integer;color:cardinal;blender:TBlenderFunc);
  var
   x,y:integer;
   p:PCardinal;
  begin
   pitch:=pitch shr 2;
   p:=buf; inc(p,x1+pitch*y1);
   for x:=x1 to x2 do begin
    p^:=blender(p^,color); inc(p);
   end;
   p:=buf; inc(p,x1+pitch*y2);
   for x:=x1 to x2 do begin
    p^:=blender(p^,color); inc(p);
   end;
   p:=buf; inc(p,x1+pitch*(y1+1));
   for y:=y1+1 to y2-1 do begin
    p^:=blender(p^,color); inc(p,pitch);
   end;
   p:=buf; inc(p,x2+pitch*(y1+1));
   for y:=y1+1 to y2-1 do begin
    p^:=blender(p^,color); inc(p,pitch);
   end;
  end;

 procedure FillUsingAlpha(buf:pointer;pitch:integer;
                          alpha:pointer;aPitch:integer;
                          width,height:integer;
                          color:cardinal);

  var
   sp,dp,ap:PByte;
   p:PCardinal;
   i,j:integer;
   am:cardinal;
  begin
   sp:=alpha;
   dp:=buf;
   am:=(color shr 24)*$10100;
   color:=color and $FFFFFF;
   for i:=1 to height do begin
    p:=pointer(dp); ap:=sp;
    for j:=1 to width do begin
     p^:=color or (ap^*am) and $FF000000;
     inc(ap); inc(p);
    end;
    inc(sp,aPitch);
    inc(dp,pitch);
   end;
  end;

 procedure BlendUsingAlpha(buf:pointer;pitch:integer;
                          alpha:pointer;aPitch:integer;
                          width,height:integer;
                          color:cardinal;
                          blender:TBlenderFunc);

  var
   sp,dp,ap:PByte;
   p:PCardinal;
   i,j:integer;
   am:cardinal;
  begin
   sp:=alpha;
   dp:=buf;
   am:=(color shr 24)*$10100;
   color:=color and $FFFFFF;
   for i:=1 to height do begin
    p:=pointer(dp); ap:=sp;
    for j:=1 to width do begin
     if ap^>0 then
      p^:=Blender(p^,color or (ap^*am) and $FF000000);
     inc(ap); inc(p);
    end;
    inc(sp,aPitch);
    inc(dp,pitch);
   end;
  end;

 procedure TransitionRect(sour1:pointer;sPitch1:integer;
                          sour2:pointer;sPitch2:integer;
                          dest:pointer;dPitch:integer;
                          width,height:integer;
                          horizontal:boolean;
                          blender:TBlenderFunc);
  var
   s1,s2:PCardinal;
   i,j:integer;
  begin
   for i:=1 to height do begin
    for j:=1 to width do begin
     inc(s1); inc(s2);
    end;
   end;
  end;

 procedure SimpleDraw(sour:pointer;sPitch:integer;
                      dest:pointer;dPitch:integer;
                      x,y,width,height:integer;
                      blender:TBlenderFunc);
  var
   sp,dp,s,p:PCardinal;
   i,j:integer;
  begin
   sPitch:=sPitch div 4;
   dPitch:=dPitch div 4;
   sp:=sour;
   dp:=dest; inc(dp,y*dPitch+x);
   for i:=1 to height do begin
    s:=sp; p:=dp;
    for j:=1 to width do begin
     dp^:=Blender(dp^,sp^);
     inc(sp); inc(dp);
    end;
    sp:=s; inc(sp,sPitch);
    dp:=p; inc(dp,dPitch);
   end;
  end;

 procedure SimpleDrawEx(sour:pointer;sNext,sPitch:integer;
                        dest:pointer;dPitch:integer;
                        x,y, // точка вывода в dest
                        width,height:integer; // размер рисуемого изображения
                        blender:TBlenderFunc);
  var
   sp,dp,s,p:PCardinal;
   i,j:integer;
  begin
   sNext:=sNext div 4;
   sPitch:=sPitch div 4;
   dPitch:=dPitch div 4;
   sp:=sour;
   dp:=dest; inc(dp,y*dPitch+x);
   for i:=1 to height do begin
    s:=sp; p:=dp;
    for j:=1 to width do begin
     dp^:=Blender(dp^,sp^);
     inc(sp,sNext); inc(dp);
    end;
    sp:=s; inc(sp,sPitch);
    dp:=p; inc(dp,dPitch);
   end;
  end;


 procedure StretchDraw(sour:pointer;sPitch:integer;
                       dest:pointer;dPitch:integer;
                       x1,y1,x2,y2:integer; // область вывода в dest
                       u1,v1,u2,v2:single;  // текстурные к-ты
                       blender:TBlenderFunc);
  var
   sp,dp,p:PCardinal;
   i,j,w,h,o:integer;
   u,u0,v,du,dv:single;
   color,c0,c1,c2,c3:cardinal;
  begin
   {$IFDEF ANDROID}
//   DebugMessage(Format('StretchDraw(%x,%d, %x,%d, %d,%d,%d,%d, %f,%f,%f,%f)',
//     [PtrUInt(sour),sPitch,PtrUInt(dest),dPitch, x1,y1,x2,y2 ,u1,v1,u2,v2]));
   {$ENDIF}
   w:=x2-x1+1;
   h:=y2-y1+1;
   du:=(u2-u1)/w;
   dv:=(v2-v1)/h;
   u0:=u1+du*0.5+0.5001; v:=v1+dv*0.5+0.5001;
   sPitch:=sPitch div 4;
   dPitch:=dPitch div 4;
   p:=dest; inc(p,y1*dPitch+x1); // output point
   for i:=y1 to y2 do begin
    dp:=p; u:=u0;
    for j:=x1 to x2 do begin
     sp:=sour;
     o:=trunc(u)-1+(trunc(v)-1)*sPitch;
     inc(sp,o); c0:=sp^;
     inc(sp); c1:=sp^;
     inc(sp,sPitch); c3:=sp^;
     dec(sp); c2:=sp^;
     if (c0 or c1 or c2 or c3>$FFFFFF) then begin
      color:=BilinearMix(c0,c1,c2,c3,frac(u),frac(v));
      dp^:=Blender(dp^,color);
     end;
     inc(sp); inc(dp);
     u:=u+du;
    end;
    inc(p,dPitch);
    v:=v+dv;
   end;
  end;

 procedure StretchDraw1(sour:pointer;sPitch:integer; // текстура
                        dest:pointer;dPitch:integer;
                        x1,y1,x2,y2:integer;   // область вывода в dest (в целых пикселях
                        u1,v1,u2,v2:integer;   // область текстуры (в целых текселях)
                        blender:TBlenderFunc);
  var
   scaleX,scaleY,bX,bY:single;                      
  begin
   scaleX:=(u2-u1)/(x2-x1);
   scaleY:=(v2-v1)/(y2-y1);                             
   bX:=(u1+0.5)-(x1+0.5)*scaleX;
   bY:=(v1+0.5)-(y1+0.5)*scaleY;
   StretchDraw(sour,sPitch,dest,dPitch,
    x1,y1,x2,y2,
    scaleX*x1+bX+0.001,scaleY*y1+bY+0.001,
    scaleX*(x2+1)+bX-0.001,scaleY*(y2+1)+bY-0.001,
    blender);
  end;  

 procedure StretchDraw2(sour:pointer;sPitch:integer; // текстура
                        dest:pointer;dPitch:integer;
                        x1,y1,x2,y2:single;   // область вывода в dest
                        u1,v1,u2,v2:integer;  // текстурные к-ты, соответствующие краям области вывода
                        blender:TBlenderFunc);
  var
   scaleX,scaleY:single;
  begin
   scaleX:=(u2-u1)/(x2-x1);
   scaleY:=(v2-v1)/(y2-y1);
   StretchDraw(sour,sPitch,dest,dPitch,
     trunc(x1),trunc(y1),trunc(x2+0.999)-1,trunc(y2+0.999)-1,
     u1-frac(x1)*scaleX,v1-frac(y1)*scaleY,
     u2+(trunc(x2+0.999)-x2)*scaleX,v2+(trunc(y2+0.999)-y2)*scaleY,
     blender);
  end;

 procedure DownSample2X(sour:pointer;sPitch:integer;
                        dest:pointer;dPitch:integer;
                        width,height:integer);
  type
   TColorArray=array[0..100] of cardinal;
  var
   dp:PCardinal;
   x,y:integer;
   src:^TColorArray;
   a:cardinal;
  begin
   height:=height div 2;
   width:=width div 2;
   sPitch:=sPitch div 4;
   dPitch:=dPitch div 4;
   src:=sour;
   for y:=0 to height-1 do begin
    a:=y*sPitch*2;
    dp:=dest;
    inc(dp,dPitch*y);
    for x:=0 to width-1 do begin
     dp^:=BilinearBlend(src[a],src[a+1],src[a+sPitch],src[a+sPitch+1],0.5,0.5);
     inc(dp);
     inc(a,2);
    end;
   end;
  end;

 procedure DownSample2X8(sour:pointer;sPitch:integer;
                         dest:pointer;dPitch:integer;
                         width,height:integer);
  type
   TByteArray=array[0..100] of byte;
  var
   dp:PByte;
   x,y:integer;
   src:^TByteArray;
   a:cardinal;
  begin
   height:=height div 2;
   width:=width div 2;
   src:=sour;
   for y:=0 to height-1 do begin
    a:=y*sPitch*2;
    dp:=dest;
    inc(dp,dPitch*y);
    for x:=0 to width-1 do begin
     dp^:=(src[a]+src[a+1]+src[a+sPitch]+src[a+sPitch+1]) shr 2;
     inc(dp);
     inc(a,2);
    end;
   end;
  end;

 function ColorCopy(background,foreground:cardinal):cardinal;
  begin
   result:=foreground;
  end;

 procedure DrawPixel(x,y:integer;color:cardinal);
  var
   pc:PCardinal;
  begin
   if (x<0) or (y<0) or (x>=rWidth) or (y>=rHeight) then exit;
   pc:=rBuf; inc(pc,x+y*rPitch);
   pc^:=Blend(pc^,color);
  end;

 procedure DrawPixelAA(x,y:single;color:cardinal);
  var
   ix,iy,pitch,width,height:integer;
   f,fx,fy:single;
   pc,buf:PCardinal;
   a:integer;
  begin
   pitch:=rPitch; width:=rWidth; height:=rHeight; buf:=rBuf;
   if (x>=0) and (x<width-1) and (y>=0) and (y<height-1) then begin
    // No clipping
    a:=color shr 24;
    color:=color and $FFFFFF;
    ix:=trunc(x); iy:=trunc(y);
    fx:=frac(x); fy:=frac(y);
    pc:=Buf; inc(pc,Pitch*iy+ix);
    f:=(1-fx)*(1-fy);
    pc^:=Blend(pc^,color+round(a*f) shl 24);
    inc(pc);
    f:=fx*(1-fy);
    pc^:=Blend(pc^,color+round(a*f) shl 24);
    inc(pc,Pitch);
    f:=fx*fy;
    pc^:=Blend(pc^,color+round(a*f) shl 24);
    dec(pc);
    f:=(1-fx)*fy;
    pc^:=Blend(pc^,color+round(a*f) shl 24);
    exit;
   end;
   // Clipped version
   if (x<-1) or (x>Width) or (y<-1) or (y>Height) then exit;
   a:=color shr 24;
   color:=color and $FFFFFF;
   ix:=trunc(x); iy:=trunc(y);
   fx:=frac(x); fy:=frac(y);
   pc:=Buf; inc(pc,Pitch*iy+ix);
   if (ix>=0) and (iy>=0) then begin
    f:=(1-fx)*(1-fy);
    pc^:=Blend(pc^,color+round(a*f) shl 24);
   end;
   inc(pc);
   if (ix<Width-1) and (iy>=0) then begin
    f:=fx*(1-fy);
    pc^:=Blend(pc^,color+round(a*f) shl 24);
   end;
   inc(pc,Pitch);
   if (ix<Width-1) and (iy<Height-1) then begin
    f:=fx*fy;
    pc^:=Blend(pc^,color+round(a*f) shl 24);
   end;
   dec(pc);
   if (ix>=0) and (iy<Height-1) then begin
    f:=(1-fx)*fy;
    pc^:=Blend(pc^,color+round(a*f) shl 24);
   end;
  end;

 procedure SmoothLine(x1,y1,x2,y2:single;color:cardinal;width:single=1.0);
  var
   x,y,dx,dy:single;
   i,d:integer;
  begin
   if (x1<0) and (x2<0) or
      (y1<0) and (y2<0) or
      (x1>=rWidth) and (x2>=rWidth) or
      (y1>=rHeight) and (y2>=rHeight) then exit;
   if width<1 then begin
    if width<0.01 then width:=0.01;
    color:=color and $FFFFFF+round((color shr 24)*width) shl 24;
    width:=1;
   end else
    if width>1.5 then width:=1.5;
   d:=round(width*sqrt(sqr(x2-x1)+sqr(y2-y1)));
   if d=0 then d:=1;
   dx:=(x2-x1)/d;
   dy:=(y2-y1)/d;
   x:=x1+dx*0.5;
   y:=y1+dy*0.5;
   for i:=1 to d do begin
    DrawPixelAA(x,y,color);
    x:=x+dx; y:=y+dy;
   end;
  end;

 procedure Arc(x,y,r,fromA,toA:single;color:cardinal;width:single=1.0);
  var
   i,d:integer;
   a,da:single;
  begin
   if width<1 then begin
    if width<0.01 then width:=0.01;
    color:=color and $FFFFFF+round((color shr 24)*width) shl 24;
    width:=1;
   end else
    if width>1.5 then width:=1.5;

   if toA<fromA then begin
    a:=fromA; fromA:=toA; toA:=a;
   end;
   d:=round(r*width*(toA-fromA));
   if d<=0 then d:=1;
   da:=(toA-fromA)/d;
   a:=fromA+da*0.5;
   for i:=1 to d do begin
    DrawPixelAA(x+r*cos(a),y+r*sin(a),color);
    a:=a+da;
   end;
  end;

 procedure Circle(x,y,r:single;color:cardinal;width:single=1.0);
  begin
   Arc(x,y,r,0,2*Pi,color,width);
  end;

 procedure FillCircle(x,y,r:single;color:cardinal);
  var
   i,j,ix1,ix2:integer;
   r2a,r2b,d,d1,a:single;
   pc:PCardinal;
  begin
   r2a:=sqr(r-0.5); r2b:=sqr(r+0.5);
   ix1:=round(x-r-0.5); ix2:=round(x+r+0.5);
   if ix1<0 then ix1:=0;
   if ix2>=rWidth then ix2:=rWidth-1;
   for i:=round(y-r-0.5) to round(y+r+0.5) do begin
    if (i<0) or (i>=rHeight) then continue;
    d1:=sqr(i-y);
    pc:=rBuf; inc(pc,ix1+i*rPitch);
    for j:=ix1 to ix2 do begin
     d:=d1+sqr(j-x);
     if d<r2b then begin
       if d<r2a then
         pc^:=Blender(pc^,color)
       else begin
         a:=r+0.5-sqrt(d);
         pc^:=Blender(pc^,color and $FFFFFF+round((color shr 24)*a) shl 24);
       end;
     end;
     inc(pc);
    end;
   end;
  end;

 procedure PieSlice(x,y,r,a1,a2:single;color:cardinal); // angles are clockwise from 0hr (Y+ direction)
  var
   i,j,ix1,ix2:integer;
   r2a,r2b,d,d1,a:single;
   pc:PCardinal;
  begin
   // Normalize angles
   while a1<0 do a1:=a1+2*pi;
   while a1>2*pi do a1:=a1-2*pi;
   while a2<0 do a2:=a2+2*pi;
   while a2>2*pi do a2:=a2-2*pi;
   if a2<a1 then a2:=a2+2*pi;

   r2a:=sqr(r-0.5); r2b:=sqr(r+0.5);
   ix1:=round(x-r-0.5); ix2:=round(x+r+0.5);
   if ix1<0 then ix1:=0;
   if ix2>=rWidth then ix2:=rWidth-1;
   for i:=round(y-r-0.5) to round(y+r+0.5) do begin
    if (i<0) or (i>=rHeight) then continue;
    d1:=sqr(i-y);
    pc:=rBuf; inc(pc,ix1+i*rPitch);
    for j:=ix1 to ix2 do begin
     d:=d1+sqr(j-x);
     if d<r2b then begin
       if (i-y)<>0 then a:=ArcTan2(j-x,y-i)
        else if j>x then a:=Pi/2
         else a:=-Pi/2;
       if (a<0) then a:=a+2*Pi;
       if (a>=a1) and (a<=a2) or (a+2*Pi>=a1) and (a+2*Pi<=a2) then
        if d<r2a then
          pc^:=Blender(pc^,color)
        else begin
          a:=r+0.5-sqrt(d);
          pc^:=Blender(pc^,color and $FFFFFF+round((color shr 24)*a) shl 24);
        end;
     end;
     inc(pc);
    end;
   end;
  end;

 procedure DrawPolyline(points:PPoint2s;count:integer;closed:boolean;color:cardinal;width:single=1.0);
  var
   i:integer;
   firstPnt,lastPnt:TPoint2s;
  begin
   firstPnt:=points^;
   for i:=1 to count-1 do begin
    lastPnt:=points^;
    inc(points);
    SmoothLine(lastPnt.x,lastPnt.y,points.x,points.y,color,width);
   end;
   if closed then
    SmoothLine(points.x,points.y,firstPnt.x,firstPnt.y,color,width);
  end;

 procedure FillPolygon(points:PPoint2s;count:integer;color:cardinal);
  begin

  end;

initialization
 blBlend:=Blend;
 blCopy:=ColorCopy;
 blender:=blBlend;
end.

