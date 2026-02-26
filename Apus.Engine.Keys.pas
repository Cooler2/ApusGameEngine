// -----------------------------------------------------
// Apus.Engine.Keys - crossplatform keyboard abstraction
// -----------------------------------------------------
// Provides platform-independent key codes and modifier flags.
//
// TKey enum values match Windows VK_ codes, so no conversion
// is needed on Windows. For SDL, use TKey.FromSDL().
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
    CapsLock=20,
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
    // numpad
    Num0=96, Num1=97, Num2=98, Num3=99, Num4=100,
    Num5=101, Num6=102, Num7=103, Num8=104, Num9=105,
    NumMul=106, NumAdd=107, NumSub=109, NumDot=110, NumDiv=111,
    // function keys
    F1=112, F2=113, F3=114, F4=115, F5=116, F6=117,
    F7=118, F8=119, F9=120, F10=121, F11=122, F12=123,
    // locks
    NumLock=144, ScrollLock=145,
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
    // Convert SDL2 key code (SDLK_xxx) to TKey, handling scancodes and lowercase letters
    class function FromSDL(sdlKey:integer):TKey; static;
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

class function TKeyHelper.FromSDL(sdlKey:integer):TKey;
const
  SDLK_SCANCODE_MASK=1 shl 30;
  SDL_SCANCODE_CAPSLOCK=57;
  SDL_SCANCODE_F1=58;
  SDL_SCANCODE_PRINTSCREEN=70;
  SDL_SCANCODE_SCROLLLOCK=71;
  SDL_SCANCODE_INSERT=73;
  SDL_SCANCODE_HOME=74;
  SDL_SCANCODE_PAGEUP=75;
  SDL_SCANCODE_DELETE=76;
  SDL_SCANCODE_END=77;
  SDL_SCANCODE_PAGEDOWN=78;
  SDL_SCANCODE_RIGHT=79;
  SDL_SCANCODE_LEFT=80;
  SDL_SCANCODE_DOWN=81;
  SDL_SCANCODE_UP=82;
  SDL_SCANCODE_NUMLOCKCLEAR=83;
  SDL_SCANCODE_KP_DIVIDE=84;
  SDL_SCANCODE_KP_MULTIPLY=85;
  SDL_SCANCODE_KP_MINUS=86;
  SDL_SCANCODE_KP_PLUS=87;
  SDL_SCANCODE_KP_ENTER=88;
  SDL_SCANCODE_KP_1=89;
  SDL_SCANCODE_KP_PERIOD=99;
var
  scan:integer;
begin
  // try direct mapping first (works for ASCII-range keys)
  if (sdlKey>=0) and (sdlKey<=255) then
    result:=TKey(sdlKey)
  else
    result:=TKey.None;

  // handle special ASCII-range cases
  case sdlKey of
    ord('a')..ord('z'): // SDL sends lowercase, convert to uppercase key code
      result:=TKey(sdlKey-32);
    8:result:=TKey.Backspace;
    9:result:=TKey.Tab;
    13:result:=TKey.Enter;
    27:result:=TKey.Escape;
    32:result:=TKey.Space;
    96:result:=TKey.Tilde; // SDL backquote
  end;

  // scancode-based keys (high bit set = SDLK_SCANCODE_MASK)
  if sdlKey and SDLK_SCANCODE_MASK<>0 then begin
    scan:=sdlKey and $FFFF;
    case scan of
      SDL_SCANCODE_CAPSLOCK:result:=TKey.CapsLock;
      SDL_SCANCODE_F1..SDL_SCANCODE_F1+11:
        result:=TKey(ord(TKey.F1)+scan-SDL_SCANCODE_F1);
      SDL_SCANCODE_PRINTSCREEN:result:=TKey.PrintScreen;
      SDL_SCANCODE_SCROLLLOCK:result:=TKey.ScrollLock;
      SDL_SCANCODE_INSERT:result:=TKey.Insert;
      SDL_SCANCODE_HOME:result:=TKey.Home;
      SDL_SCANCODE_PAGEUP:result:=TKey.PageUp;
      SDL_SCANCODE_DELETE:result:=TKey.Delete;
      SDL_SCANCODE_END:result:=TKey.EndKey;
      SDL_SCANCODE_PAGEDOWN:result:=TKey.PageDown;
      SDL_SCANCODE_RIGHT:result:=TKey.Right;
      SDL_SCANCODE_LEFT:result:=TKey.Left;
      SDL_SCANCODE_DOWN:result:=TKey.Down;
      SDL_SCANCODE_UP:result:=TKey.Up;
      SDL_SCANCODE_NUMLOCKCLEAR:result:=TKey.NumLock;
      SDL_SCANCODE_KP_DIVIDE:result:=TKey.NumDiv;
      SDL_SCANCODE_KP_MULTIPLY:result:=TKey.NumMul;
      SDL_SCANCODE_KP_MINUS:result:=TKey.NumSub;
      SDL_SCANCODE_KP_PLUS:result:=TKey.NumAdd;
      SDL_SCANCODE_KP_ENTER:result:=TKey.Enter;
      SDL_SCANCODE_KP_1..SDL_SCANCODE_KP_1+9:
        result:=TKey(ord(TKey.Num1)+scan-SDL_SCANCODE_KP_1);
      SDL_SCANCODE_KP_PERIOD:result:=TKey.NumDot;
    else
      result:=TKey.None;
    end;
  end;
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
  i:integer;
begin
  for i:=0 to high(keys) do
    if code=ord(keys[i]) then exit(true);
  result:=false;
end;

end.
