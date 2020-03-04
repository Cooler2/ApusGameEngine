unit keyboard;
interface
 uses DirectInput;

type
 DirectKbd=class
  keys:array[0..255] of shortint; // ќтрицательное число указывает на нажатие клавиши
  constructor Create(wnd:cardinal;background:boolean=true);
  destructor Destroy; override;
  function GetKeys:boolean; // ѕолучить сведени€ о клавишах
 private
  DI:IDirectInput7;
  ID:IDirectInputDevice7;
 end;

implementation
 uses MyServis;

{ DirectKbd }

constructor DirectKbd.Create(wnd:cardinal;background:boolean=true);
begin
 DirectInputCreateEx(hInstance,$0700,IDirectInput7,DI,nil);
 DI.CreateDeviceEx(GUID_SysKeyboard,IDirectInputDevice7,pointer(id),nil);
 if id=nil then raise EError.Create('Kbd: can''t create device!');
 if ID.SetCooperativeLevel(wnd,DISCL_BACKGROUND*byte(background)+DISCL_FOREGROUND*(1-byte(background))
  +DISCL_NONEXCLUSIVE)<0 then
  raise EError.Create('Kbd: can''t set coop. level!');
 ID.SetDataFormat(c_dfDIKeyboard);
end;

destructor DirectKbd.Destroy;
begin
 ID.Unacquire;
 ID:=nil;
 DI:=nil;
end;

function DirectKbd.GetKeys;
begin
 result:=false;
 if ID=nil then exit;
 if ID.Acquire<0 then exit;
 if ID.GetDeviceState(256,@keys)<0 then exit;
// ID.Unacquire;
 result:=true;
end;

end.
