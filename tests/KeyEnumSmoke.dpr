program KeyEnumSmoke;
{$mode delphi}

uses
  SysUtils,
  Apus.Engine.Keys;

procedure AssertTrue(cond:boolean; const msg:string);
begin
  if not cond then raise Exception.Create(msg);
end;

var
  mods:TKeyMods;
begin
  // enum values match VK codes
  AssertTrue(ord(TKey.Enter)=13,'Enter must be 13');
  AssertTrue(ord(TKey.Space)=32,'Space must be 32');
  AssertTrue(ord(TKey.Escape)=27,'Escape must be 27');
  AssertTrue(ord(TKey.F1)=112,'F1 must be 112');
  AssertTrue(ord(TKey.CapsLock)=20,'CapsLock must be 20');
  AssertTrue(ord(TKey.NumMul)=106,'NumMul must be 106');
  AssertTrue(ord(TKey.Semicolon)=186,'Semicolon must be 186');

  // TKey.Code helper
  AssertTrue(TKey.Enter.Code=13,'Code helper failed');
  AssertTrue(TKey.A.Code=65,'Code helper for A failed');

  // TKey.Name helper
  AssertTrue(TKey.Enter.Name='Enter','Name for Enter');
  AssertTrue(TKey.A.Name='A','Name for A');
  AssertTrue(TKey.F1.Name='F1','Name for F1');
  AssertTrue(TKey.D0.Name='0','Name for D0');
  AssertTrue(TKey.Num5.Name='Num5','Name for Num5');
  AssertTrue(TKey.Tilde.Name='~','Name for Tilde');

  // TKey.From
  AssertTrue(TKey.From(13)=TKey.Enter,'From(13) failed');
  AssertTrue(TKey.From(65)=TKey.A,'From(65) failed');

  // KeyIn
  AssertTrue(KeyIn(13,[TKey.Enter,TKey.Space]),'KeyIn positive failed');
  AssertTrue(not KeyIn(9,[TKey.Enter,TKey.Space]),'KeyIn negative failed');

  // FromWindowsVK
  AssertTrue(TKey.FromWindowsVK(13)=TKey.Enter,'VK->Key Enter failed');
  AssertTrue(TKey.FromWindowsVK(32)=TKey.Space,'VK->Key Space failed');

  // FromSDL
  AssertTrue(TKey.FromSDL(ord('a'))=TKey.A,'SDL letter mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 58)=TKey.F1,'SDL F1 mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 80)=TKey.Left,'SDL Left mapping failed');
  AssertTrue(TKey.FromSDL(13)=TKey.Enter,'SDL Enter mapping failed');
  AssertTrue(TKey.FromSDL(96)=TKey.Tilde,'SDL backquote mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 83)=TKey.NumLock,'SDL NumLock mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 89)=TKey.Num1,'SDL KP_1 mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 97)=TKey.Num9,'SDL KP_9 mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 98)=TKey.Num0,'SDL KP_0 mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 99)=TKey.NumDot,'SDL KP_PERIOD mapping failed');
  AssertTrue(TKey.FromSDL(1 shl 30 or 88)=TKey.Enter,'SDL KP_ENTER mapping failed');

  // TKeyMods
  mods:=ord(TKeyMod.LShift) or ord(TKeyMod.LCtrl);
  AssertTrue(mods.Has(TKeyMod.LShift),'Has LShift failed');
  AssertTrue(mods.Has(TKeyMod.Shift),'Has Shift failed');
  AssertTrue(mods.Has(TKeyMod.LCtrl),'Has LCtrl failed');
  AssertTrue(not mods.Has(TKeyMod.Alt),'Has Alt should be false');

  // ToLegacy / FromLegacy
  mods:=ord(TKeyMod.Shift) or ord(TKeyMod.Alt);
  AssertTrue(mods.ToLegacy=1 or 4,'ToLegacy failed');
  mods:=TKeyMods.FromLegacy(1 or 2 or 8); // shift+ctrl+win
  AssertTrue(mods.Has(TKeyMod.Shift),'FromLegacy Shift');
  AssertTrue(mods.Has(TKeyMod.Ctrl),'FromLegacy Ctrl');
  AssertTrue(mods.Has(TKeyMod.Win),'FromLegacy Win');
  AssertTrue(not mods.Has(TKeyMod.Alt),'FromLegacy no Alt');

  writeln('KeyEnumSmoke: OK');
end.
