
// Функции для более тщательной работы с текстом
// Copyright (C) Ivan Polyacov, ivan@apus-software.com, cooler@tut.by
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)

{$R-}
unit Apus.TextUtils;
interface
 uses Apus.Common, Apus.Structs;

 // Remove any HTML tags, return plain text
 function ExtractPlainText(const html:string):string;
 // Builds list of unique words
 function SplitToWords(const text:WideString):WStringArr;
 // Является ли символ "алфавитно-цифровым" (соединительная пунктуация тоже считается) или же какие-то другим
 function IsWordChar(const wch:WideChar):boolean;
 // Returns edit distance between 2 words
 function GetWordsDistance(const w1,w2:WideString):integer;
 // Find length of the longest common subsequence (returns char indexes in w1) !MAX LENGTH=63!
 function GetMaxSubsequence(const w1,w2:WideString):IntArray;

 // Convert string in JSON format into set of Key->Value pairs
 function ParseJSON(json:AnsiString):THash;

implementation
 uses SysUtils;
 var
  wordCharMap:array[0..2047] of cardinal;

 function ParseJSON(json:AnsiString):THash;
  var
   i,p:integer;
   sa:AStringArr;
   key,value:AnsiString;
  begin
   result.Init;
   json:=chop(json);
   if length(json)=0 then exit;
   if (json[1]='{') and (json[length(json)]='}') then json:=copy(json,2,length(json)-2);
   sa:=SplitA(',',json);
   for i:=0 to high(sa) do begin
    sa[i]:=chop(sa[i]);
    p:=pos(':',sa[i]);
    if p=0 then continue;
    key:=copy(sa[i],1,p-1);
    value:=copy(sa[i],p+1,length(sa[i]));
    key:=chop(key);
    if length(key)=0 then continue;
    if (key[1]='"') and (key[length(key)]='"') or
       (key[1]='''') and (key[length(key)]='''') then key:=copy(key,2,length(key)-2);
    if length(key)=0 then continue;
    key:=Unescape(key);
    if length(value)>=2 then
     if (value[1]='"') and (value[length(value)]='"') or
        (value[1]='''') and (value[length(value)]='''') then value:=copy(value,2,length(value)-2);
    value:=Unescape(value);
    result.Put(key,value,true);
   end;
  end;

 function GetMaxSubsequence(const w1,w2:WideString):IntArray;
  var
//   dd:array of array of byte; // slow version
   d:array[0..63,0..63] of byte; // fast version
   i,j,w,h,l:integer;
  begin
   w:=length(w1); // index j
   h:=length(w2); // index i
   ASSERT((w<64) and (h<64));
//   SetLength(d,h+1,w+1);
   for i:=0 to w do d[0,i]:=0;
   for i:=1 to h do d[i,0]:=0;
   for i:=1 to h do
    for j:=1 to w do
     if w1[j]=w2[i] then d[i,j]:=d[i-1,j-1]+1
      else d[i,j]:=max2(d[i-1,j],d[i,j-1]);
   l:=d[h,w]; i:=h; j:=w;
   SetLength(result,l);
   while d[i,j]>0 do
    if w1[j]=w2[i] then begin
     dec(l);
     result[l]:=j;
     dec(j); dec(i);
    end else begin
     if d[i,j-1]=d[i,j] then dec(j)
      else dec(i);
    end;
  end;

 // Levenstein distance
 function GetWordsDistance(const w1,w2:WideString):integer;
  var
//   dd:array of array of byte; // slow version
   d:array[0..63,0..63] of byte; // fast version
   i,j,w,h,l,m:integer;
  begin
   w:=length(w1); // index j
   h:=length(w2); // index i
   ASSERT((w<64) and (h<64));
   for i:=0 to w do d[0,i]:=i;
   for i:=1 to h do d[i,0]:=i;
   for i:=1 to h do
    for j:=1 to w do begin
     l:=1+min2(d[i-1,j],d[i,j-1]);
     if w1[j]=w2[i] then m:=d[i-1,j-1]
      else m:=d[i-1,j-1]+1;
     d[i,j]:=min2(l,m);
     if (i>1) and (j>1) and (w1[j-1]=w2[i]) and (w1[j]=w2[i-1]) then
       d[i,j]:=min2(d[i,j],d[i-2,j-2]+1);
    end;

   result:=d[h,w];
  end;

 function IsWordChar(const wch:WideChar):boolean;
  begin
   result:=wordCharMap[word(wch) shr 5] shr (word(wch) and 31) and 1>0;
  end;

 // Split string into words (tokenize), all non-word characters removed
 function SplitToWords(const text:WideString):WStringArr;
  var
   i,j,cnt:integer;
   mode:boolean;
  begin
   cnt:=0;
   SetLength(result,length(text) div 2+1);
   j:=0; mode:=false;
   for i:=1 to length(text) do
    if IsWordChar(text[i])<>mode then begin
     if mode then begin
      result[cnt]:=copy(text,j,i-j);
      inc(cnt);
     end else
      j:=i;
     mode:=not mode;
    end;
   if mode then begin
    result[cnt]:=copy(text,j,length(text)-j+1);
    inc(cnt);
   end;
   SetLength(result,cnt);
  end;

 function ExtractPlainText(const html:string):string;
  var
   i,j,n,m,l,prv:integer;
   st:string;
   wch:WideChar;
  begin
   l:=length(html);
   SetLength(result,l);
   n:=0; m:=0; prv:=0;
   for i:=1 to l do begin
    case m of
     // text
     0:begin
        if html[i]='<' then begin
         m:=1;
         if (i<l+4) and (html[i+1]='!') and (html[i+2]='-') and (html[i+3]='-') then m:=2;
        end;
        if html[i]='&' then m:=3;

        if m=0 then begin
         inc(n); result[n]:=html[i];
        end else
         prv:=i;
       end;

     // tag
     1:begin
        if html[i]='>' then m:=0;
       end;

     // comment
     2:begin
        if (i>prv+5) and (html[i]='>') and (html[i-1]='-') and (html[i-2]='-') then m:=0;
       end;

     // special character
     3:begin
        if (html[i]=';') or (html[i]<=' ') then begin
         st:=copy(html,prv+1,i-prv-1);
         wch:=#0;
         if (st='amp') then wch:='&';
         if (st='lt') then wch:='<';
         if (st='gt') then wch:='>';
         if (st='nbsp') then wch:=WideChar(160);
         if (st='euro') then wch:=WideChar(8364);
         if (st='copy') then wch:=WideChar(169);
         if (st='reg') then wch:=WideChar(174);
         if (length(st)>2) and (st[1]='#') then begin
          delete(st,1,1);
          if (st[1]='x') then begin
           delete(st,1,1);
           wch:=WideChar(HexToInt(st));
          end else
           wch:=WideChar(StrToIntDef(st,0));
         end;
         if wch<>#0 then begin
          st:=EncodeUTF8(wch);
          for j:=1 to length(st) do begin
           inc(n); result[n]:=st[j];
          end;
         end;
         m:=0;
        end;
       end;
    end;
   end;
   SetLength(result,n);
  end;

 const
  scriptRanges:string=
'2D;30-39;5F;B2-B3;B5;B9;BC-BE;2B9-2C1;2C6-2D1;2EC;2EE;374;640;1CE9-1CEC;1CEE-1CF1;1CF5-1CF6;2010-2015;203F-2040;2054;2070;2074-2079;2080-2089;2102;2107;210A-2113;2115;2119-211D;2124;2128;212C-212D;212F-2131;2133-2134;2135-2138;2139;213C-213F;2145-2149;'+
'2150-215F;2189;2460-249B;24EA-24FF;2776-2793;2E17;2E1A;2E2F;2E3A-2E3B;2E40;3006;301C;3030;3031-3035;303C;30A0;30FC;3192-3195;3220-3229;3248-324F;3251-325F;3280-3289;32B1-32BF;A717-A71F;A788;A830-A835;A9CF;FE31-FE32;FE33-FE34;FE4D-FE4F;FE58;FE63;FF0D;'+
'FF10-FF19;FF3F;FF70;FF9E-FF9F;41-5A;61-7A;AA;BA;C0-D6;D8-F6;F8-1BA;1BB;1BC-1BF;1C0-1C3;1C4-293;294;295-2AF;2B0-2B8;2E0-2E4;1D00-1D25;1D2C-1D5C;1D62-1D65;1D6B-1D77;1D79-1D9A;1D9B-1DBE;1E00-1EFF;2071;207F;2090-209C;212A-212B;2132;214E;2160-2182;2183-2184;'+
'2185-2188;2C60-2C7B;2C7C-2C7D;2C7E-2C7F;A722-A76F;A770;A771-A787;A78B-A78E;A78F;A790-A7AE;A7B0-A7B7;A7F7;A7F8-A7F9;A7FA;A7FB-A7FF;AB30-AB5A;AB5C-AB5F;AB60-AB64;FB00-FB06;FF21-FF3A;FF41-FF5A;370-373;376-377;37A;37B-37D;37F;386;388-38A;38C;38E-3A1;3A3-3E1;'+
'3F0-3F5;3F7-3FF;1D26-1D2A;1D5D-1D61;1D66-1D6A;1DBF;1F00-1F15;1F18-1F1D;1F20-1F45;1F48-1F4D;1F50-1F57;1F59;1F5B;1F5D;1F5F-1F7D;1F80-1FB4;1FB6-1FBC;1FBE;1FC2-1FC4;1FC6-1FCC;1FD0-1FD3;1FD6-1FDB;1FE0-1FEC;1FF2-1FF4;1FF6-1FFC;2126;AB65;400-481;48A-52F;'+
'1C80-1C88;1D2B;1D78;A640-A66D;A66E;A67F;A680-A69B;A69C-A69D;531-556;559;561-587;58A;FB13-FB17;5BE;5D0-5EA;5F0-5F2;FB1D;FB1F-FB28;FB2A-FB36;FB38-FB3C;FB3E;FB40-FB41;FB43-FB44;FB46-FB4F;620-63F;641-64A;660-669;66E-66F;671-6D3;6D5;6E5-6E6;6EE-6EF;6F0-6F9;'+
'6FA-6FC;6FF;750-77F;8A0-8B4;8B6-8BD;FB50-FBB1;FBD3-FD3D;FD50-FD8F;FD92-FDC7;FDF0-FDFB;FE70-FE74;FE76-FEFC;710;712-72F;74D-74F;780-7A5;7B1;904-939;93D;950;958-961;966-96F;971;972-97F;A8F2-A8F7;A8FB;A8FD;980;985-98C;98F-990;993-9A8;9AA-9B0;9B2;9B6-9B9;9BD;'+
'9CE;9DC-9DD;9DF-9E1;9E6-9EF;9F0-9F1;9F4-9F9;A05-A0A;A0F-A10;A13-A28;A2A-A30;A32-A33;A35-A36;A38-A39;A59-A5C;A5E;A66-A6F;A72-A74;A85-A8D;A8F-A91;A93-AA8;AAA-AB0;AB2-AB3;AB5-AB9;ABD;AD0;AE0-AE1;AE6-AEF;AF9;B05-B0C;B0F-B10;B13-B28;B2A-B30;B32-B33;B35-B39;'+
'B3D;B5C-B5D;B5F-B61;B66-B6F;B71;B72-B77;B83;B85-B8A;B8E-B90;B92-B95;B99-B9A;B9C;B9E-B9F;BA3-BA4;BA8-BAA;BAE-BB9;BD0;BE6-BEF;BF0-BF2;C05-C0C;C0E-C10;C12-C28;C2A-C39;C3D;C58-C5A;C60-C61;C66-C6F;C78-C7E;C80;C85-C8C;C8E-C90;C92-CA8;CAA-CB3;CB5-CB9;CBD;CDE;'+
'CE0-CE1;CE6-CEF;CF1-CF2;D05-D0C;D0E-D10;D12-D3A;D3D;D4E;D54-D56;D58-D5E;D5F-D61;D66-D6F;D70-D78;D7A-D7F;D85-D96;D9A-DB1;DB3-DBB;DBD;DC0-DC6;DE6-DEF;E01-E30;E32-E33;E40-E45;E46;E50-E59;E81-E82;E84;E87-E88;E8A;E8D;E94-E97;E99-E9F;EA1-EA3;EA5;EA7;EAA-EAB;'+
'EAD-EB0;EB2-EB3;EBD;EC0-EC4;EC6;ED0-ED9;EDC-EDF;F00;F20-F29;F2A-F33;F40-F47;F49-F6C;F88-F8C;1000-102A;103F;1040-1049;1050-1055;105A-105D;1061;1065-1066;106E-1070;1075-1081;108E;1090-1099;A9E0-A9E4;A9E6;A9E7-A9EF;A9F0-A9F9;A9FA-A9FE;AA60-AA6F;AA70;'+
'AA71-AA76;AA7A;AA7E-AA7F;10A0-10C5;10C7;10CD;10D0-10FA;10FC;10FD-10FF;2D00-2D25;2D27;2D2D;1100-11FF;3131-318E;A960-A97C;AC00-D7A3;D7B0-D7C6;D7CB-D7FB;FFA0-FFBE;FFC2-FFC7;FFCA-FFCF;FFD2-FFD7;FFDA-FFDC;1200-1248;124A-124D;1250-1256;1258;125A-125D;1260-1288;'+
'128A-128D;1290-12B0;12B2-12B5;12B8-12BE;12C0;12C2-12C5;12C8-12D6;12D8-1310;1312-1315;1318-135A;1369-137C;1380-138F;2D80-2D96;2DA0-2DA6;2DA8-2DAE;2DB0-2DB6;2DB8-2DBE;2DC0-2DC6;2DC8-2DCE;2DD0-2DD6;2DD8-2DDE;AB01-AB06;AB09-AB0E;AB11-AB16;AB20-AB26;AB28-AB2E;'+
'13A0-13F5;13F8-13FD;AB70-ABBF;1400;1401-166C;166F-167F;18B0-18F5;1681-169A;16A0-16EA;16EE-16F0;16F1-16F8;1780-17B3;17D7;17DC;17E0-17E9;17F0-17F9;1806;1810-1819;1820-1842;1843;1844-1877;1880-1884;1887-18A8;18AA;3041-3096;309D-309E;309F;30A1-30FA;30FD-30FE;'+
'30FF;31F0-31FF;FF66-FF6F;FF71-FF9D;3105-312D;31A0-31BA;3005;3007;3021-3029;3038-303A;303B;3400-4DB5;4E00-9FD5;F900-FA6D;FA70-FAD9;A000-A014;A015;A016-A48C;1700-170C;170E-1711;1720-1731;1740-1751;1760-176C;176E-1770;1900-191E;1946-194F;1950-196D;1970-1974;'+
'1A00-1A16;3E2-3EF;2C80-2CE4;2CEB-2CEE;2CF2-2CF3;2CFD;1980-19AB;19B0-19C9;19D0-19D9;19DA;2C00-2C2E;2C30-2C5E;2D30-2D67;2D6F;A800-A801;A803-A805;A807-A80A;A80C-A822;1B05-1B33;1B45-1B4B;1B50-1B59;A840-A873;7C0-7C9;7CA-7EA;7F4-7F5;7FA;1B83-1BA0;1BAE-1BAF;'+
'1BB0-1BB9;1BBA-1BBF;1C00-1C23;1C40-1C49;1C4D-1C4F;1C50-1C59;1C5A-1C77;1C78-1C7D;A500-A60B;A60C;A610-A61F;A620-A629;A62A-A62B;A882-A8B3;A8D0-A8D9;A900-A909;A90A-A925;A930-A946;AA00-AA28;AA40-AA42;AA44-AA4B;AA50-AA59;1A20-1A54;1A80-1A89;1A90-1A99;1AA7;'+
'AA80-AAAF;AAB1;AAB5-AAB6;AAB9-AABD;AAC0;AAC2;AADB-AADC;AADD;800-815;81A;824;828;A4D0-A4F7;A4F8-A4FD;A6A0-A6E5;A6E6-A6EF;A984-A9B2;A9D0-A9D9;AAE0-AAEA;AAF2;AAF3-AAF4;ABC0-ABE2;ABF0-ABF9;1BC0-1BE5;840-858';

var
 i,w1,w2,p:integer;
 sa:StringArr;
initialization
 try
  sa:=split(';',scriptRanges);
  for i:=0 to high(sa) do begin
   p:=pos('-',sa[i]);
   if p>0 then begin
    w1:=HexToInt(copy(sa[i],1,p-1));
    w2:=HexToInt(copy(sa[i],p+1,4));
   end else begin
    w1:=HexToInt(sa[i]);
    w2:=w1;
   end;
   while w1<=w2 do begin
    wordCharMap[w1 shr 5]:=wordCharMap[w1 shr 5] or (1 shl (w1 and 31));
    inc(w1);
   end;
  end;
  w1:=ord('''');
  wordCharMap[w1 shr 5]:=wordCharMap[w1 shr 5] or (1 shl (w1 and 31));
 except
 end;
end.
