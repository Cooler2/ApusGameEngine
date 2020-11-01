// Complex text is a text string where characters has different attributes, such as
// font (including size and style), color, fill (background color) and link attribute
// Complex text can be stored in different forms including HTML-style simplified markup language (SML)
// This unit contains wide set of routines for manipulation with complex text strings
//
// Copyright (C) 2015 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
unit Apus.Engine.ComplexText;
interface
 uses Apus.MyServis;

 // SML routines
 // ------------

 // Returns number of plain text characters in SML string
 function SMLLength(st:WideString):integer;
 // Returns plain text from the SML string
 function SMLExtract(st:WideString):WideString;
 function SMLExtractUTF8(st:AnsiString):AnsiString; // UTF-8 version
 // Build index for the string ([plain text character index] -> SML character index)
 function SMLIndex(st:WideString):IntArray;

 function SMLGetLinkAt(st:WideString;index:integer):cardinal;


implementation

 function SMLLength(st:WideString):integer;
  var
   index:IntArray;
  begin
   index:=SMLIndex(st);
   result:=high(index);
  end;

 function SMLGetLinkAt(st:WideString;index:integer):cardinal;
  var
   tagMode:boolean;
   i,n,len:integer;
   vst:string[8];
   stack:array[0..9] of cardinal;
   stackPos:integer;
   v:cardinal;
  begin
   result:=0;
   tagMode:=false;
   i:=1; n:=1;
   stackpos:=0;
   v:=0;
   len:=length(st);
   while i<=len do begin
    if not tagmode then begin
     if n=index then result:=v;
     if (st[i]='{') and (i<len) then begin
      if st[i+1] in ['!','/','B','b','I','i','U','u','C','c','G','g','L','l','F','f'] then tagMode:=true
       else inc(n);
      if st[i+1]='{' then inc(i);
     end else
      inc(n);
    end else begin
     if st[i]='}' then tagmode:=false;
     if (st[i]='/') and (i<len) and (st[i+1] in ['l','L']) then begin
      if stackpos>0 then begin
       dec(stackPos); v:=stack[stackPos];
      end else v:=0;
     end;
     if (st[i] in ['L','l']) and (i<len+2) and (st[i+1]='=') then begin
      vst:=''; inc(i,2);
      while (i<=len) and (st[i] in ['0'..'9','a'..'f','A'..'F']) do begin
       vst:=vst+st[i]; inc(i);
      end;
      dec(i);
      stack[stackPos]:=v; inc(stackPos);
      v:=HexToInt(vst);
     end;
    end;
    inc(i);
   end;
  end;

 function SMLIndex(st:WideString):IntArray;
  var
   i,len,cnt:integer;
   tagmode:boolean;
  begin
   tagmode:=false;
   len:=length(st);
   SetLength(result,len+1);
   i:=1; cnt:=0;
   while i<=len do begin
    if tagmode then begin
     // inside {}
     case st[i] of
      '}':tagmode:=false;
     end;
    end else begin
     // outside {}
     if (st[i]='{') and (i<len-1) and
        (st[i+1] in ['!','/','B','b','I','i','U','u','C','c','G','g','L','l','F','f']) then begin
      tagmode:=true;
     end else begin
      inc(cnt);
      result[cnt]:=i;
      if (st[i]='{') and (i<len) and (st[i+1]='{') then inc(i);
     end;
    end;
    inc(i);
   end;
   result[0]:=cnt;
   SetLength(result,cnt+1);
  end;

 function SMLExtract(st:WideString):WideString;
  var
   i,len,cnt:integer;
   tagmode:boolean;
   index:IntArray;
  begin
   index:=SMLIndex(st);
   SetLength(result,high(index));
   for i:=1 to high(index) do
    result[i]:=st[index[i]];
  end;

 function SMLExtractUTF8(st:AnsiString):AnsiString;
  begin
   result:=EncodeUTF8(SMLExtract(DecodeUTF8(st)),false);
  end;

end.
