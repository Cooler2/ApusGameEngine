// Database class for use with SQLite3 DLL
unit SQLiteDB;
interface
 uses MyServis,database;

 type
  // SQLite interface
  TSQLiteDatabase=class(TDatabase)
   constructor Create;
   procedure Connect; override;
   function Query(DBquery:string):StringArr; override;
   procedure Disconnect; override;
   destructor Destroy; override;
  end;

implementation
 uses SQLite;

{ TSQLiteDatabase }

procedure TSQLiteDatabase.Connect;
begin
  inherited;

end;

constructor TSQLiteDatabase.Create;
begin

end;

destructor TSQLiteDatabase.Destroy;
begin

  inherited;
end;

procedure TSQLiteDatabase.Disconnect;
begin
  inherited;

end;

function TSQLiteDatabase.Query(DBquery: string): StringArr;
begin

end;

end.
