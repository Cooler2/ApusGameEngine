unit database;
interface
 uses MyServis,structs;
 var
  // Credentials and options
  DB_HOST:AnsiString='127.0.0.1';
  DB_DATABASE:AnsiString='';
  DB_LOGIN:AnsiString='';
  DB_PASSWORD:AnsiString='';
  DB_CHARSET:AnsiString='utf8';

 const
  // Error codes
  dbeNoError         = 0;
  dbeNotConnected    = 1;
  dbePingFailed      = 2;
  dbeServerError     = 3;
  dbeQueryFailed     = 4;


 type
  TLogProc = procedure(msg:AnsiString;level:byte;msgtype:byte);

  // Basic abstract class
  TDatabase=class
   connected:boolean;
   rowCount,colCount:integer;
   insertID:int64; // value for auto incremented field
   lastError:AnsiString;
   lastErrorCode:integer;
   constructor Create;
   procedure Connect; virtual; abstract;
   // ��������� ������, ���������� ������ ����� �������� rowCount * colCount
   // � ������ ������ ���������� ������ �� ����� ������: ERROR: <����� ������>, ������ rowCount=0
   // ���� ������ �� ������������� ������� ������ � ����������� ������� - ����������
   // ������ ������ (0 �����)
   function Query(DBquery:AnsiString):AStringArr; overload; virtual; abstract;
   // Sugar: Query(Format(DBQuery,params)) - all string items pass through SQLsafe()
   function Query(DBquery:AnsiString;params:array of const):AStringArr; overload; virtual;
   // ����������� ������ (���� � fields) �� �������, ��������������� ��������� �������, � ������� �� � ���
   // ������� ����� ����� ��������� ���������� � �.�.
   // ��� ��������������������, �.�. ���� � �� ��� ���� ���������� - ��� ��������
   procedure QueryHash(var h:THash;table,keyField,fields,condition:AnsiString); virtual;
   // ��� ������� ����� ���� H, ���������������� ���� keyField � ������� table
   // ����������� �������� ���� valueField (����� ����������� ��������� ����� ����� �������, ����� ����� ������� ���)
   // quoteKeys ������������ ����� ��������� �������� ������ � " " (���������� ���� ����� - ���������� ����)
   // condition - �������������� ������� ��� WHERE clause
   // ���� �������� ��� ����� �� �������, ���� � ���� ������� � ������ ���������
   procedure QueryValues(var h:THash;table,keyField,valueField:AnsiString;quoteKeys:boolean=false;condition:AnsiString=''); virtual;

   procedure Disconnect; virtual; abstract;
   destructor Destroy; virtual;
  private
    crSect:TMyCriticalSection;
    name:AnsiString;
  end;

  // MySQL interface
  TMySQLDatabase=class(TDatabase)
   logSelects,logChanges:boolean;
   time1,time2,time3:integer; // ����� ���������� real_query � ����� ��������� �����������
   constructor Create;
   procedure Connect; override;
   function Query(DBquery:AnsiString):AStringArr; override;
   procedure Disconnect; override;
   destructor Destroy; override;
  private
   ms:pointer;
   reserve:array[0..255] of integer; // ������ ��� ��������� ms
  end;

  TMySQLDatabaseWithLogging=class(TMySQLDatabase)
   constructor Create(customLogProc:TLogProc;minLogLevel_,selectLogLevel_,updatelogLevel_,logGroup_:integer);
   function Query(DBquery:AnsiString):AStringArr; override;
  protected
   logProc:TLogProc;
   minLogLevel,selectLogLevel,updatelogLevel,logGroup:integer;
  end;

  // Escape special characters (so string can be used in query)
  procedure SQLString(var st:AnsiString);
  function SQLSafe(st:AnsiString):AnsiString;

implementation
 uses SysUtils,mysql,Variants;
 var
  counter:integer=0; // MySQL library usage counter
  lock:TMyCriticalSection;

procedure SQLString(var st:AnsiString);
 var
  i:integer;
 begin
  st:=StringReplace(st,'\','\\',[rfReplaceAll]);
  st:=StringReplace(st,'"','\"',[rfReplaceAll]);
  st:=StringReplace(st,#13,'\r',[rfReplaceAll]);
  st:=StringReplace(st,#10,'\n',[rfReplaceAll]);
  st:=StringReplace(st,#9,'\t',[rfReplaceAll]);
  st:=StringReplace(st,#0,'\0',[rfReplaceAll]);
  i:=1;
  while i<length(st) do
   if st[i]<' ' then delete(st,i,1) else inc(i);
 end;


function SQLSafe(st:AnsiString):AnsiString;
 begin
  SQLString(st);
  result:=st;
 end;

{ TDatabase }

constructor TDatabase.Create;
 begin
  InitCritSect(crSect,name,100);
  rowCount:=0; colCount:=0;
 end;

destructor TDatabase.Destroy;
 begin
  if connected then Disconnect;
  DeleteCritSect(crSect);
 end;

procedure TDatabase.QueryValues(var h: THash; table, keyField,
  valueField: AnsiString; quoteKeys: boolean=false;condition:AnsiString='');
var
 i,j:integer;
 keys:AStringArr;
 sa:AStringArr;
 list:AnsiString;
begin
 if h.count=0 then exit;
 keys:=h.AllKeys;
 if quoteKeys then begin
  list:='';
  for i:=0 to high(keys) do begin
   if i>0 then list:=list+',';
   list:=list+'"'+keys[i]+'"'
  end;
 end else
  list:=Join(keys,',');
 if condition<>'' then condition:=' AND '+condition;
 sa:=Query(Format('SELECT %s,%s FROM %s WHERE %s IN (%s)%s',[keyField,valueField,table,keyField,list,condition]));
 for i:=0 to rowCount-1 do
  for j:=1 to colCount-1 do
   h.Put(sa[i*colCount],sa[i*colCount+j],j=1);
end;

procedure TDatabase.QueryHash(var h:THash;table,keyField,fields,condition:AnsiString);
var
 sa:AStringArr;
 i,j:integer;
 key:AnsiString;
begin
 sa:=Query(Format('SELECT %s,%s FROM %s WHERE %s',[keyField,fields,table,condition]));
 h.Init(true);
 for i:=0 to rowCount-1 do begin
  key:=sa[i*colCount];
  if not VarIsEmpty(h.Get(key)) then h.Put(key,Unassigned,true);
  for j:=1 to colCount-1 do begin
   h.Put(sa[i*colCount],sa[i*colCount+j]);
  end;
 end;
end;

function TDatabase.Query(DBquery:AnsiString;params:array of const):AStringArr;
var
 i:integer;
 p:pointer;
 astr:^AnsiString;
begin
 for i:=0 to high(params) do
  case params[i].VType of
   vtAnsiString: begin
    AnsiString(params[i].VAnsiString):=SqlSafe(AnsiString(params[i].VAnsiString));
   end;
   vtWideString: begin
    New(aStr);
    aStr^:=SqlSafe(EncodeUTF8(WideString(params[i].VWideString)));
    params[i].VAnsiString:=pointer(aStr^);
    params[i].VType:=vtAnsiString;
   end;
   vtUnicodeString: begin
    New(aStr);
    aStr^:=SqlSafe(EncodeUTF8(UnicodeString(params[i].VUnicodeString)));
    params[i].VAnsiString:=pointer(aStr^);
    params[i].VType:=vtAnsiString;
   end;
  end;
 DBQuery:=Format(DBQuery, params);
 result:=Query(DBQuery);
end;

{ TMySQLDatabase }

procedure TMySQLDatabase.Connect;
 var
  bool:longbool;
  i:integer;
 begin
  try
  sleep(50);
  try
   ms:=mysql_init(nil);
  except
   on e:Exception do ForceLogMessage('SQL: error in mysql_init: '+e.message);
  end;
  if ms=nil then begin
   sleep(100);
   ForceLogMessage('SQL: ms=nil');
   ms:=mysql_init(nil);
  end;
  bool:=true;
  try
   mysql_options(ms,MYSQL_OPT_RECONNECT,@bool);
   mysql_options(ms,MYSQL_SET_CHARSET_NAME,PChar(DB_CHARSET));
  except
   on e:exception do ForceLogMessage('SQL: error during option set: '+e.message);
  end;
  i:=1;
  ForceLogMessage('Connecting to MySQL server');
  while (mysql_real_connect(ms,PAnsiChar(DB_HOST),PAnsiChar(DB_LOGIN),PAnsiChar(DB_PASSWORD),
           PAnsiChar(DB_DATABASE),0,'',CLIENT_COMPRESS)<>ms) and
        (i<4) do begin
   ForceLogMessage(name+': Error connecting to MySQL server ('+mysql_error(ms)+'), retry in 3 sec');
   sleep(3000); inc(i);
  end;
  if i=4 then raise EError.Create(name+': Failed to connect to MySQL server');
  bool:=true;
  mysql_options(ms,MYSQL_OPT_RECONNECT,@bool);
  connected:=true;
  ForceLogMessage(name+': MySQL connection established');
  except
   on e:exception do ForceLogMessage(name+': error during MySQL Connect: '+e.message);
  end;
 end;

constructor TMySQLDatabase.Create;
begin
 inherited;
 if counter=0 then try
  lock.Enter;
  libmysql_load(nil);
 finally
  lock.Leave;
 end;
 inc(counter);
 name:='DB-'+inttostr(counter);
 logSelects:=false;
 logChanges:=false;
end;

destructor TMySQLDatabase.Destroy;
begin
 inherited;
 dec(counter);
 if counter>0 then exit;
 libmysql_free;
end;

procedure TMySQLDatabase.Disconnect;
begin
 if ms<>nil then begin
  LogMessage('Closing MySQL connection');
  mysql_close(ms);
 end;
end;

function TMySQLDatabase.Query(DBquery: AnsiString): AStringArr;
var
 r,flds,rows,i,j:integer;
 st:AnsiString;
 res:PMYSQL_RES;
 myrow:PMYSQL_ROW;
 t:int64;
begin
  rowCount:=0; colCount:=0; insertID:=0;
  lastError:='';
  lastErrorCode:=0;  
  if not connected then begin
   SetLength(result,1);
   lastError:='ERROR: Not connected';
   lastErrorCode:=dbeNotConnected;
   result[0]:=lastError;
   exit;
  end;
  EnterCriticalSection(crSect);
  try
   if DBquery='' then begin
    // ������ ������ ��� ����������� ����� � ��
    SetLength(result,0);
    r:=mysql_ping(ms);
    if r<>0 then begin
     st:=mysql_error(ms);
     lastError:=st;
     lastErrorCode:=dbePingFailed;
     LogMessage('ERROR! Failed to ping MySQL: '+st);
    end;
    exit;
   end;
   // �������� ������
   time1:=0; time2:=0; time3:=0;
   t:=MyTickCount;
   r:=mysql_real_query(ms,@DBquery[1],length(DBquery));
   time1:=MyTickCount-t;
   if r<>0 then begin // failure
    st:=mysql_error(ms);
    lastError:=st;
    lastErrorCode:=dbeServerError;
    LogMessage('SQL_ERROR: '+st);
    setLength(result,1);
    result[0]:='ERROR: '+st;
    exit;
   end;
   insertID:=mysql_insert_id(ms);
   t:=MyTickCount;
//   res:=mysql_use_result(ms);
   res:=mysql_store_result(ms);
   time2:=MyTickCount-t;
   if res=nil then begin
    st:=mysql_error(ms);
    if st<>'' then begin
     lastError:=st;
     lastErrorCode:=dbeQueryFailed;
     LogMessage('SQL_ERROR: '+st);
     setLength(result,1);
     result[0]:='ERROR: '+st;
    end else
     setLength(result,0);
    exit;
   end;
   flds:=mysql_num_fields(res); // ���-�� ����� � ����������
   rows:=mysql_num_rows(res);
   colCount:=flds;
   rowCount:=rows;
   t:=MyTickCount;
   if ((rowCount=0) and logChanges) or ((rowCount>0) and logSelects) then LogMessage('SQL: '+DBquery);
   try
    j:=0;
    setLength(result,flds*rows);
    while true do begin
     // ������� ������ � ���������� ������ � ������ row
     myrow:=mysql_fetch_row(res);
     if myrow<>nil then begin
      for i:=0 to flds-1 do begin
       if j>=length(result) then
        setLength(result,j*2+flds*16); // re-allocate
       result[j]:=myrow[i];
       inc(j);
      end;
     end else break;
    end;
    if j<>length(result) then setLength(result,j);
   finally
    mysql_free_result(res);
   end;
   time3:=MyTickCount-t;
  finally
   LeaveCriticalSection(crSect);
  end;
end;

constructor TMySQLDatabaseWithLogging.Create;
 begin
  logProc:=customLogProc;
  try
   inherited Create;
   minLogLevel:=minLogLevel_;
   selectLogLevel:=selectLogLevel_;
   updateLogLevel:=updateLogLevel_;
   logGroup:=logGroup_;
  except
   on e:exception do logProc('SQL create error: '+e.message,4,logGroup_);
  end;
 end;

function TMySQLDatabaseWithLogging.Query(DBquery: AnsiString): AStringArr;
 var
  t:int64;
 begin
  if UpperCase(copy(DBquery,1,6))='SELECT' then begin
    if minLogLevel>=selectLogLevel then LogProc(DBquery,selectLogLevel,logGroup)
  end else
   LogProc(DBquery,updateLogLevel,logGroup);
  lastError:='';
  t:=MyTickCount;
  result:=inherited Query(DBquery);
  t:=MyTickCount-t;
  if lastError<>'' then LogProc('SQL Error: '+lastError,updateLogLevel+1,logGroup);
  if t>100 then LogProc(Format('SQL: query time=%d (real_query: %d, use: %d, fetch: %d)',[t,time1,time2,time3]),
    max2(selectLogLevel,updateLogLevel)+1,logGroup);
 end;

initialization
 InitCritSect(lock,'DB_LOCK',150);
end.
