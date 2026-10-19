// -----------------------------------------------------
// Apus.Engine.Keys - crossplatform keyboard abstraction
// -----------------------------------------------------
// Provides platform-independent key codes and modifier flags.
//
// Two codes come with every key event:
//  - TKey - what the key means: values match Windows VK_ codes, letters (and on
//    Windows other keys) follow the keyboard layout;
//  - scancode - where the key is: USB HID usage ids (= SDL_Scancode), the same on
//    every platform and layout, named in the Scan namespace. Key state polling
//    (IsKeyDown...) uses them: WASD stays WASD on AZERTY.
//
// TKeyMods is a bitmask of modifier keys with L/R distinction:
//   LShift/RShift/Shift, LCtrl/RCtrl/Ctrl, LAlt/RAlt/Alt, LWin/RWin/Win
// Combined values (Shift, Ctrl, Alt, Win) match when ANY side is pressed.
//
// Legacy interop: ToLegacy/FromLegacy convert to/from the old
// sscShift=1, sscCtrl=2, sscAlt=4, sscWin=8 bitmask format.
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// -----------------------------------------------------
unit Apus.Engine.Keys;
interface
{$SCOPEDENUMS ON}

type
  // Platform-independent key codes (values = Windows VK_ codes)
  TKey=(
    None=0,
    Backspace=8, Tab=9, Enter=13,
    Pause=19, CapsLock=20,
    Escape=27, Space=32,
    PageUp=33, PageDown=34, EndKey=35, Home=36,
    Left=37, Up=38, Right=39, Down=40,
    PrintScreen=44, Insert=45, Delete=46,
    // digit row
    D0=48, D1=49, D2=50, D3=51, D4=52,
    D5=53, D6=54, D7=55, D8=56, D9=57,
    // letters
    A=65, B=66, C=67, D=68, E=69, F=70, G=71, H=72, I=73,
    J=74, K=75, L=76, M=77, N=78, O=79, P=80, Q=81, R=82,
    S=83, T=84, U=85, V=86, W=87, X=88, Y=89, Z=90,
    LWin=91, RWin=92, Menu=93,
    // numpad
    Num0=96, Num1=97, Num2=98, Num3=99, Num4=100,
    Num5=101, Num6=102, Num7=103, Num8=104, Num9=105,
    NumMul=106, NumAdd=107, NumSub=109, NumDot=110, NumDiv=111,
    // function keys
    F1=112, F2=113, F3=114, F4=115, F5=116, F6=117,
    F7=118, F8=119, F9=120, F10=121, F11=122, F12=123,
    // locks
    NumLock=144, ScrollLock=145,
    // modifiers: a key event names the side
    LShift=160, RShift=161, LCtrl=162, RCtrl=163, LAlt=164, RAlt=165,
    // browser/media keys
    BrowserBack=166, BrowserForward=167,
    VolumeMute=173, VolumeDown=174, VolumeUp=175,
    MediaNext=176, MediaPrev=177, MediaStop=178, MediaPlayPause=179,
    // OEM keys (US layout VK_ codes)
    Semicolon=186, Equal=187, Comma=188, Minus=189,
    Period=190, Slash=191, Tilde=192,
    BracketL=219, Backslash=220, BracketR=221, Quote=222
  );

  // Modifier key flags with left/right distinction.
  // Combined values (Shift, Ctrl, Alt, Win) are OR of both sides,
  // so Has(TKeyMod.Shift) is true when either LShift or RShift is pressed.
  TKeyMod=(
    LShift=$01, RShift=$02, Shift=$03,
    LCtrl=$04,  RCtrl=$08,  Ctrl=$0C,
    LAlt=$10,   RAlt=$20,   Alt=$30,
    LWin=$40,   RWin=$80,   Win=$C0
  );

  // Bitmask of active modifier keys
  TKeyMods=type byte;

  TKeyHelper=record helper for TKey
    // Return numeric key code (= ord value = Windows VK_ code)
    function Code:byte; inline;
    // Return human-readable key name: 'Enter', 'A', 'F1', 'Num5', ';', etc.
    function Name:string;
    // Convert numeric code to TKey (unchecked cast)
    class function From(code:byte):TKey; static;
    // Convert Windows VK_xxx constant to TKey (masks to byte)
    class function FromWindowsVK(vk:cardinal):TKey; static;
  end;

  // Physical key positions: USB HID usage ids (= SDL_Scancode), the scancodes of the key
  // events and of IsKeyDown/IsKeyPressed/IsKeyReleased on every platform. A key is named
  // after the US layout: Scan.Z is the left key of the bottom letter row, whatever its
  // label is (W on AZERTY). Codes without a name here are valid too (see SDL_Scancode).
  Scan=record
   const
    None=0;
    A=4; B=5; C=6; D=7; E=8; F=9; G=10; H=11; I=12; J=13; K=14; L=15; M=16;
    N=17; O=18; P=19; Q=20; R=21; S=22; T=23; U=24; V=25; W=26; X=27; Y=28; Z=29;
    D1=30; D2=31; D3=32; D4=33; D5=34; D6=35; D7=36; D8=37; D9=38; D0=39;
    Enter=40; Escape=41; Backspace=42; Tab=43; Space=44;
    Minus=45; Equal=46; BracketL=47; BracketR=48; Backslash=49;
    Semicolon=51; Quote=52; Tilde=53; Comma=54; Period=55; Slash=56;
    CapsLock=57;
    F1=58; F2=59; F3=60; F4=61; F5=62; F6=63; F7=64; F8=65; F9=66; F10=67; F11=68; F12=69;
    PrintScreen=70; ScrollLock=71; Pause=72;
    Insert=73; Home=74; PageUp=75; Delete=76; EndKey=77; PageDown=78;
    Right=79; Left=80; Down=81; Up=82;
    NumLock=83; NumDiv=84; NumMul=85; NumSub=86; NumAdd=87; NumEnter=88;
    Num1=89; Num2=90; Num3=91; Num4=92; Num5=93; Num6=94; Num7=95; Num8=96; Num9=97;
    Num0=98; NumDot=99;
    NonUSBackslash=100; // the extra key next to the left Shift (ISO keyboards)
    Menu=101;
    VolumeMute=127; VolumeUp=128; VolumeDown=129;
    LCtrl=224; LShift=225; LAlt=226; LWin=227; RCtrl=228; RShift=229; RAlt=230; RWin=231;
    MediaNext=258; MediaPrev=259; MediaStop=260; MediaPlayPause=261;
    BrowserBack=270; BrowserForward=271;
    Count=512; // every scancode is below
   // The key at this position on the US layout (TKey.None if TKey has no such key)
   class function ToKey(code:integer):TKey; static;
   // Position of the key on the US layout (None if no key gives it)
   class function FromKey(key:TKey):integer; static;
   // Name of the key at this position on the US layout: 'A', 'NumEnter', 'Scan104'...
   class function Name(code:integer):string; static;
  end;

  TKeyModsHelper=record helper for TKeyMods
    // Check if modifier m is active. For combined modifiers (Shift, Ctrl, Alt, Win)
    // returns true when ANY matching side is pressed.
    function Has(m:TKeyMod):boolean; inline;
    // Convert to legacy sscXxx bitmask (sscShift=1, sscCtrl=2, sscAlt=4, sscWin=8)
    function ToLegacy:byte;
    // Convert from legacy sscXxx bitmask to TKeyMods
    class function FromLegacy(ssc:byte):TKeyMods; static;
  end;

// Check if numeric key code matches any key in the array
function KeyIn(code:byte; const keys:array of TKey):boolean;

implementation

{ TKeyHelper }

function TKeyHelper.Code:byte;
begin
  result:=ord(self);
end;

function TKeyHelper.Name:string;
begin
  case self of
    TKey.None:result:='None';
    TKey.Backspace:result:='Backspace';
    TKey.Tab:result:='Tab';
    TKey.Enter:result:='Enter';
    TKey.Escape:result:='Escape';
    TKey.Space:result:='Space';
    TKey.CapsLock:result:='CapsLock';
    TKey.PageUp:result:='PageUp';
    TKey.PageDown:result:='PageDown';
    TKey.EndKey:result:='End';
    TKey.Home:result:='Home';
    TKey.Left:result:='Left';
    TKey.Up:result:='Up';
    TKey.Right:result:='Right';
    TKey.Down:result:='Down';
    TKey.PrintScreen:result:='PrintScreen';
    TKey.Insert:result:='Insert';
    TKey.Delete:result:='Delete';
    TKey.Pause:result:='Pause';
    TKey.LWin:result:='LWin';
    TKey.RWin:result:='RWin';
    TKey.Menu:result:='Menu';
    TKey.LShift:result:='LShift';
    TKey.RShift:result:='RShift';
    TKey.LCtrl:result:='LCtrl';
    TKey.RCtrl:result:='RCtrl';
    TKey.LAlt:result:='LAlt';
    TKey.RAlt:result:='RAlt';
    TKey.D0..TKey.D9:result:=chr(ord('0')+ord(self)-48);
    TKey.A..TKey.Z:result:=chr(ord('A')+ord(self)-65);
    TKey.Num0..TKey.Num9:result:='Num'+chr(ord('0')+ord(self)-96);
    TKey.NumMul:result:='Num*';
    TKey.NumAdd:result:='Num+';
    TKey.NumSub:result:='Num-';
    TKey.NumDot:result:='Num.';
    TKey.NumDiv:result:='Num/';
    TKey.F1..TKey.F12:begin
      str(ord(self)-111,result);
      result:='F'+result;
    end;
    TKey.NumLock:result:='NumLock';
    TKey.ScrollLock:result:='ScrollLock';
    TKey.BrowserBack:result:='BrowserBack';
    TKey.BrowserForward:result:='BrowserForward';
    TKey.VolumeMute:result:='VolumeMute';
    TKey.VolumeDown:result:='VolumeDown';
    TKey.VolumeUp:result:='VolumeUp';
    TKey.MediaNext:result:='MediaNext';
    TKey.MediaPrev:result:='MediaPrev';
    TKey.MediaStop:result:='MediaStop';
    TKey.MediaPlayPause:result:='MediaPlayPause';
    TKey.Semicolon:result:=';';
    TKey.Equal:result:='=';
    TKey.Comma:result:=',';
    TKey.Minus:result:='-';
    TKey.Period:result:='.';
    TKey.Slash:result:='/';
    TKey.Tilde:result:='~';
    TKey.BracketL:result:='[';
    TKey.Backslash:result:='\';
    TKey.BracketR:result:=']';
    TKey.Quote:result:='''';
  else
    str(ord(self),result);
    result:='Key'+result;
  end;
end;

class function TKeyHelper.From(code:byte):TKey;
begin
  result:=TKey(code);
end;

class function TKeyHelper.FromWindowsVK(vk:cardinal):TKey;
begin
  result:=TKey(vk and $FF);
end;

{ Scan }

class function Scan.ToKey(code:integer):TKey;
begin
  case code of
    A..Z:result:=TKey(ord(TKey.A)+code-A);
    D1..D9:result:=TKey(ord(TKey.D1)+code-D1);
    D0:result:=TKey.D0;
    Enter,NumEnter:result:=TKey.Enter; // Windows reports both as VK_RETURN
    Escape:result:=TKey.Escape;
    Backspace:result:=TKey.Backspace;
    Tab:result:=TKey.Tab;
    Space:result:=TKey.Space;
    Minus:result:=TKey.Minus;
    Equal:result:=TKey.Equal;
    BracketL:result:=TKey.BracketL;
    BracketR:result:=TKey.BracketR;
    Backslash:result:=TKey.Backslash;
    Semicolon:result:=TKey.Semicolon;
    Quote:result:=TKey.Quote;
    Tilde:result:=TKey.Tilde;
    Comma:result:=TKey.Comma;
    Period:result:=TKey.Period;
    Slash:result:=TKey.Slash;
    CapsLock:result:=TKey.CapsLock;
    F1..F12:result:=TKey(ord(TKey.F1)+code-F1);
    PrintScreen:result:=TKey.PrintScreen;
    ScrollLock:result:=TKey.ScrollLock;
    Pause:result:=TKey.Pause;
    Insert:result:=TKey.Insert;
    Home:result:=TKey.Home;
    PageUp:result:=TKey.PageUp;
    Delete:result:=TKey.Delete;
    EndKey:result:=TKey.EndKey;
    PageDown:result:=TKey.PageDown;
    Right:result:=TKey.Right;
    Left:result:=TKey.Left;
    Down:result:=TKey.Down;
    Up:result:=TKey.Up;
    NumLock:result:=TKey.NumLock;
    NumDiv:result:=TKey.NumDiv;
    NumMul:result:=TKey.NumMul;
    NumSub:result:=TKey.NumSub;
    NumAdd:result:=TKey.NumAdd;
    Num1..Num9:result:=TKey(ord(TKey.Num1)+code-Num1);
    Num0:result:=TKey.Num0;
    NumDot:result:=TKey.NumDot;
    Menu:result:=TKey.Menu;
    VolumeMute,262:result:=TKey.VolumeMute; // 262 - SDL "audio mute" (X11)
    VolumeUp:result:=TKey.VolumeUp;
    VolumeDown:result:=TKey.VolumeDown;
    LCtrl:result:=TKey.LCtrl;
    LShift:result:=TKey.LShift;
    LAlt:result:=TKey.LAlt;
    LWin:result:=TKey.LWin;
    RCtrl:result:=TKey.RCtrl;
    RShift:result:=TKey.RShift;
    RAlt:result:=TKey.RAlt;
    RWin:result:=TKey.RWin;
    MediaNext:result:=TKey.MediaNext;
    MediaPrev:result:=TKey.MediaPrev;
    MediaStop:result:=TKey.MediaStop;
    MediaPlayPause:result:=TKey.MediaPlayPause;
    BrowserBack:result:=TKey.BrowserBack;
    BrowserForward:result:=TKey.BrowserForward;
  else
    result:=TKey.None;
  end;
end;

class function Scan.FromKey(key:TKey):integer;
var
  code:integer;
begin
  result:=None;
  if key=TKey.None then exit;
  // the main block comes first: Enter, not NumEnter
  for code:=1 to Count-1 do
    if ToKey(code)=key then exit(code);
end;

class function Scan.Name(code:integer):string;
var
  key:TKey;
begin
  if code=NumEnter then exit('NumEnter');
  key:=ToKey(code);
  if key<>TKey.None then exit(key.Name);
  str(code,result);
  result:='Scan'+result;
end;

{ TKeyModsHelper }

function TKeyModsHelper.Has(m:TKeyMod):boolean;
begin
  result:=(self and ord(m))<>0;
end;

function TKeyModsHelper.ToLegacy:byte;
begin
  result:=0;
  if self and ord(TKeyMod.Shift)<>0 then result:=result or 1;
  if self and ord(TKeyMod.Ctrl)<>0 then result:=result or 2;
  if self and ord(TKeyMod.Alt)<>0 then result:=result or 4;
  if self and ord(TKeyMod.Win)<>0 then result:=result or 8;
end;

class function TKeyModsHelper.FromLegacy(ssc:byte):TKeyMods;
begin
  result:=0;
  if ssc and 1<>0 then result:=result or ord(TKeyMod.Shift);
  if ssc and 2<>0 then result:=result or ord(TKeyMod.Ctrl);
  if ssc and 4<>0 then result:=result or ord(TKeyMod.Alt);
  if ssc and 8<>0 then result:=result or ord(TKeyMod.Win);
end;

{ Standalone }

function KeyIn(code:byte; const keys:array of TKey):boolean;
var
  key:TKey;
begin
  for key in keys do
    if code=ord(key) then exit(true);
  result:=false;
end;

end.
