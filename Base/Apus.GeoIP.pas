
// Copyright (C) Apus Software, Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$R-}
unit Apus.GeoIP;
interface

 // Load GeoIP database (if path=nil then try current dir or use ENV{GeoIP})
 procedure InitGeoIP(path:string='');

 // Not thread-safe! Either use from the same thread or use own protection
 function GetCountryByIP(ip:cardinal):string;

implementation
 uses WinSock,Apus.MyServis,SysUtils;
 type
  TRange=record
   ip,mask:cardinal;
   countryCode:integer;
  end;
  TCountry=record
   id:integer;
   short:string[3];
   full:string[50];
  end;
 var
  initialized:TDatetime;
  crSect:TMyCriticalSection;
  lastPath:string;
  ranges:array of TRange;
  countries:array of TCountry;
  lastError:string;

 procedure LoadMaxMindDB(path:string);
  var
   st:string;
   fm:byte;
   f:text;
   sa:StringArr;
   cnt,i,j:integer;
  begin
   initialized:=0;
   try
    fm:=filemode;
    fileMode:=fmOpenRead;
    // Load countries
    assign(f,path+'GeoLite2-Country-Locations-en.csv');
    reset(f);
    readln(f);
    cnt:=0;
    SetLength(countries,1000);
    while not eof(f) do begin
     readln(f,st);
     sa:=StringArr(split(',',st,'"'));
     countries[cnt].id:=StrToIntDef(sa[0],0);
     countries[cnt].short:=sa[4];
     countries[cnt].full:=sa[5];
     inc(cnt);
    end;
    close(f);
    SetLength(countries,cnt);
    // Load ranges
    assign(f,path+'GeoLite2-Country-Blocks-IPv4.csv');
    reset(f);
    readln(f);
    cnt:=0;
    SetLength(ranges,1000000);
    while not eof(f) do begin
     readln(f,st);
     sa:=split(',',st);
     st:=sa[0];
     i:=pos('/',st);
     if i>0 then begin
      j:=StrToInt(copy(st,i+1,2));
      SetLength(st,i-1);
     end;
     ranges[cnt].ip:=ntohl(StrToIp(st));
     ranges[cnt].mask:=$FFFFFFFF shl (32-j);
     if sa[1]<>'' then
      ranges[cnt].countryCode:=StrToIntDef(sa[1],0)
     else
      ranges[cnt].countryCode:=StrToIntDef(sa[2],0);
     inc(cnt);
    end;
    close(f);
    SetLength(ranges,cnt);
    fileMode:=fm;
    initialized:=now;
    lastPath:=path;
   except
    on e:exception do lastError:='Load error 1: '+intToStr(cnt)+' '+st+' msg: '+e.message;
   end;
  end;

 procedure TryLoadDB(path:string);
  begin
   if path='' then exit;
   if path[length(path)-1]<>'\' then path:=path+'\';
   if FileExists(path+'GeoLite2-Country-Blocks-IPv4.csv') then LoadMaxMindDB(path);
  end;

 procedure InitGeoIP(path:string);
  begin
   if initialized>0 then exit;
   EnterCriticalSection(crSect);
   try
    if path='' then path:=GetCurrentDir;
    TryLoadDB(path);
    if initialized=0 then begin
     path:=GetEnvironmentVariable('GeoIP');
     if path<>'' then TryLoadDB(path);
    end;
   finally
    LeaveCriticalSection(crSect);
   end;
  end;

 function GetCountryByIP(ip:cardinal):string;
  var
   a,b,c,code:integer;
  begin
   result:='??';
   if initialized=0 then exit;
   // too old -> reload?
   if now>initialized+1 then InitGeoIP(lastPath);
   ip:=ntohl(ip);
   crSect.Enter;
   try
   // Find range
   a:=0; b:=length(ranges)-1;
   while a<b do begin
    c:=(a+b) div 2+1;
    if ip<ranges[c].ip then b:=c-1
     else a:=c;
   end;
   if ranges[a].ip<>ip and ranges[a].mask then exit;
   // Find country
   code:=ranges[a].countryCode;
   a:=0; b:=length(countries)-1;
   while a<b do begin
    c:=(a+b) div 2+1;
    if code<countries[c].id then b:=c-1
     else a:=c;
   end;
   if countries[a].id=code then result:=countries[a].short;
   finally
    crSect.Leave;
   end;
  end;

initialization
 initialized:=0;
 InitCritSect(crSect,'GeoIP',300);
finalization
 DeleteCritSect(crSect);
end.
