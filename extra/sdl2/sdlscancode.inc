//from "sdl_scancode.h"

  {**
   *  The SDL keyboard scancode representation.
   *
   *  Values of this type are used to represent keyboard keys, among other places
   *  in the SDL_Keysym.scancode key.keysym.scancode \endlink field of the
   *  SDL_Event structure.
   *
   *  The values in this enumeration are based on the USB usage page standard:
   *  https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
   *}
type
  PPSDL_ScanCode = ^PSDL_ScanCode;
  PSDL_ScanCode = ^TSDL_ScanCode;
  TSDL_ScanCode = type cint;

const
  SDL_SCANCODE_UNKNOWN = TSDL_ScanCode(0);

  {**
   *  Usage page $07
   *
   *  These values are from usage page $07 (USB keyboard page).
   *}

  SDL_SCANCODE_A = TSDL_ScanCode(4);
  SDL_SCANCODE_B = TSDL_ScanCode(5);
  SDL_SCANCODE_C = TSDL_ScanCode(6);
  SDL_SCANCODE_D = TSDL_ScanCode(7);
  SDL_SCANCODE_E = TSDL_ScanCode(8);
  SDL_SCANCODE_F = TSDL_ScanCode(9);
  SDL_SCANCODE_G = TSDL_ScanCode(10);
  SDL_SCANCODE_H = TSDL_ScanCode(11);
  SDL_SCANCODE_I = TSDL_ScanCode(12);
  SDL_SCANCODE_J = TSDL_ScanCode(13);
  SDL_SCANCODE_K = TSDL_ScanCode(14);
  SDL_SCANCODE_L = TSDL_ScanCode(15);
  SDL_SCANCODE_M = TSDL_ScanCode(16);
  SDL_SCANCODE_N = TSDL_ScanCode(17);
  SDL_SCANCODE_O = TSDL_ScanCode(18);
  SDL_SCANCODE_P = TSDL_ScanCode(19);
  SDL_SCANCODE_Q = TSDL_ScanCode(20);
  SDL_SCANCODE_R = TSDL_ScanCode(21);
  SDL_SCANCODE_S = TSDL_ScanCode(22);
  SDL_SCANCODE_T = TSDL_ScanCode(23);
  SDL_SCANCODE_U = TSDL_ScanCode(24);
  SDL_SCANCODE_V = TSDL_ScanCode(25);
  SDL_SCANCODE_W = TSDL_ScanCode(26);
  SDL_SCANCODE_X = TSDL_ScanCode(27);
  SDL_SCANCODE_Y = TSDL_ScanCode(28);
  SDL_SCANCODE_Z = TSDL_ScanCode(29);

  SDL_SCANCODE_1 = TSDL_ScanCode(30);
  SDL_SCANCODE_2 = TSDL_ScanCode(31);
  SDL_SCANCODE_3 = TSDL_ScanCode(32);
  SDL_SCANCODE_4 = TSDL_ScanCode(33);
  SDL_SCANCODE_5 = TSDL_ScanCode(34);
  SDL_SCANCODE_6 = TSDL_ScanCode(35);
  SDL_SCANCODE_7 = TSDL_ScanCode(36);
  SDL_SCANCODE_8 = TSDL_ScanCode(37);
  SDL_SCANCODE_9 = TSDL_ScanCode(38);
  SDL_SCANCODE_0 = TSDL_ScanCode(39);

  SDL_SCANCODE_RETURN = TSDL_ScanCode(40);
  SDL_SCANCODE_ESCAPE = TSDL_ScanCode(41);
  SDL_SCANCODE_BACKSPACE = TSDL_ScanCode(42);
  SDL_SCANCODE_TAB = TSDL_ScanCode(43);
  SDL_SCANCODE_SPACE = TSDL_ScanCode(44);

  SDL_SCANCODE_MINUS = TSDL_ScanCode(45);
  SDL_SCANCODE_EQUALS = TSDL_ScanCode(46);
  SDL_SCANCODE_LEFTBRACKET = TSDL_ScanCode(47);
  SDL_SCANCODE_RIGHTBRACKET = TSDL_ScanCode(48);
  SDL_SCANCODE_BACKSLASH = TSDL_ScanCode(49); {**< Located at the lower left of the return
                                *   key on ISO keyboards and at the right end
                                *   of the QWERTY row on ANSI keyboards.
                                *   Produces REVERSE SOLIDUS (backslash) and
                                *   VERTICAL LINE in a US layout; REVERSE 
                                *   SOLIDUS and VERTICAL LINE in a UK Mac
                                *   layout; NUMBER SIGN and TILDE in a UK 
                                *   Windows layout; DOLLAR SIGN and POUND SIGN
                                *   in a Swiss German layout; NUMBER SIGN and
                                *   APOSTROPHE in a German layout; GRAVE
                                *   ACCENT and POUND SIGN in a French Mac 
                                *   layout; and ASTERISK and MICRO SIGN in a
                                *   French Windows layout.
                                *}
  SDL_SCANCODE_NONUSHASH = TSDL_ScanCode(50); {**< ISO USB keyboards actually use this code
                                *   instead of 49 for the same key; but all
                                *   OSes I've seen treat the two codes 
                                *   identically. So; as an implementor; unless
                                *   your keyboard generates both of those 
                                *   codes and your OS treats them differently;
                                *   you should generate SDL_SCANCODE_BACKSLASH
                                *   instead of this code. As a user; you
                                *   should not rely on this code because SDL
                                *   will never generate it with most (all?)
                                *   keyboards.
                                *}
  SDL_SCANCODE_SEMICOLON = TSDL_ScanCode(51);
  SDL_SCANCODE_APOSTROPHE = TSDL_ScanCode(52);
  SDL_SCANCODE_GRAVE = TSDL_ScanCode(53);     {**< Located in the top left corner (on both ANSI
                                *   and ISO keyboards). Produces GRAVE ACCENT and
                                *   TILDE in a US Windows layout and in US and UK
                                *   Mac layouts on ANSI keyboards; GRAVE ACCENT
                                *   and NOT SIGN in a UK Windows layout; SECTION
                                *   SIGN and PLUS-MINUS SIGN in US and UK Mac
                                *   layouts on ISO keyboards; SECTION SIGN and
                                *   DEGREE SIGN in a Swiss German layout (Mac:
                                *   only on ISO keyboards); CIRCUMFLEX ACCENT and
                                *   DEGREE SIGN in a German layout (Mac: only on
                                *   ISO keyboards); SUPERSCRIPT TWO and TILDE in a
                                *   French Windows layout; COMMERCIAL AT and
                                *   NUMBER SIGN in a French Mac layout on ISO
                                *   keyboards; and LESS-THAN SIGN and GREATER-THAN
                                *   SIGN in a Swiss German; German; or French Mac
                                *   layout on ANSI keyboards.
                                *}
  SDL_SCANCODE_COMMA = TSDL_ScanCode(54);
  SDL_SCANCODE_PERIOD = TSDL_ScanCode(55);
  SDL_SCANCODE_SLASH = TSDL_ScanCode(56);

  SDL_SCANCODE_CAPSLOCK = TSDL_ScanCode(57);

  SDL_SCANCODE_F1 = TSDL_ScanCode(58);
  SDL_SCANCODE_F2 = TSDL_ScanCode(59);
  SDL_SCANCODE_F3 = TSDL_ScanCode(60);
  SDL_SCANCODE_F4 = TSDL_ScanCode(61);
  SDL_SCANCODE_F5 = TSDL_ScanCode(62);
  SDL_SCANCODE_F6 = TSDL_ScanCode(63);
  SDL_SCANCODE_F7 = TSDL_ScanCode(64);
  SDL_SCANCODE_F8 = TSDL_ScanCode(65);
  SDL_SCANCODE_F9 = TSDL_ScanCode(66);
  SDL_SCANCODE_F10 = TSDL_ScanCode(67);
  SDL_SCANCODE_F11 = TSDL_ScanCode(68);
  SDL_SCANCODE_F12 = TSDL_ScanCode(69);

  SDL_SCANCODE_PRINTSCREEN = TSDL_ScanCode(70);
  SDL_SCANCODE_SCROLLLOCK = TSDL_ScanCode(71);
  SDL_SCANCODE_PAUSE = TSDL_ScanCode(72);
  SDL_SCANCODE_INSERT = TSDL_ScanCode(73); {**< insert on PC; help on some Mac keyboards (but
                                 does send code 73; not 117) *}
  SDL_SCANCODE_HOME = TSDL_ScanCode(74);
  SDL_SCANCODE_PAGEUP = TSDL_ScanCode(75);
  SDL_SCANCODE_DELETE = TSDL_ScanCode(76);
  SDL_SCANCODE_END = TSDL_ScanCode(77);
  SDL_SCANCODE_PAGEDOWN = TSDL_ScanCode(78);
  SDL_SCANCODE_RIGHT = TSDL_ScanCode(79);
  SDL_SCANCODE_LEFT = TSDL_ScanCode(80);
  SDL_SCANCODE_DOWN = TSDL_ScanCode(81);
  SDL_SCANCODE_UP = TSDL_ScanCode(82);

  SDL_SCANCODE_NUMLOCKCLEAR = TSDL_ScanCode(83); {**< num lock on PC; clear on Mac keyboards
                                   *}
  SDL_SCANCODE_KP_DIVIDE = TSDL_ScanCode(84);
  SDL_SCANCODE_KP_MULTIPLY = TSDL_ScanCode(85);
  SDL_SCANCODE_KP_MINUS = TSDL_ScanCode(86);
  SDL_SCANCODE_KP_PLUS = TSDL_ScanCode(87);
  SDL_SCANCODE_KP_ENTER = TSDL_ScanCode(88);
  SDL_SCANCODE_KP_1 = TSDL_ScanCode(89);
  SDL_SCANCODE_KP_2 = TSDL_ScanCode(90);
  SDL_SCANCODE_KP_3 = TSDL_ScanCode(91);
  SDL_SCANCODE_KP_4 = TSDL_ScanCode(92);
  SDL_SCANCODE_KP_5 = TSDL_ScanCode(93);
  SDL_SCANCODE_KP_6 = TSDL_ScanCode(94);
  SDL_SCANCODE_KP_7 = TSDL_ScanCode(95);
  SDL_SCANCODE_KP_8 = TSDL_ScanCode(96);
  SDL_SCANCODE_KP_9 = TSDL_ScanCode(97);
  SDL_SCANCODE_KP_0 = TSDL_ScanCode(98);
  SDL_SCANCODE_KP_PERIOD = TSDL_ScanCode(99);

  SDL_SCANCODE_NONUSBACKSLASH = TSDL_ScanCode(100); {**< This is the additional key that ISO
                                      *   keyboards have over ANSI ones; 
                                      *   located between left shift and Y. 
                                      *   Produces GRAVE ACCENT and TILDE in a
                                      *   US or UK Mac layout; REVERSE SOLIDUS
                                      *   (backslash) and VERTICAL LINE in a 
                                      *   US or UK Windows layout; and 
                                      *   LESS-THAN SIGN and GREATER-THAN SIGN
                                      *   in a Swiss German; German; or French
                                      *   layout. *}
  SDL_SCANCODE_APPLICATION = TSDL_ScanCode(101);    {**< windows contextual menu; compose *}
  SDL_SCANCODE_POWER = TSDL_ScanCode(102);          {**< The USB document says this is a status flag;
                                       *  not a physical key - but some Mac keyboards
                                       *  do have a power key. *}
  SDL_SCANCODE_KP_EQUALS = TSDL_ScanCode(103);
  SDL_SCANCODE_F13 = TSDL_ScanCode(104);
  SDL_SCANCODE_F14 = TSDL_ScanCode(105);
  SDL_SCANCODE_F15 = TSDL_ScanCode(106);
  SDL_SCANCODE_F16 = TSDL_ScanCode(107);
  SDL_SCANCODE_F17 = TSDL_ScanCode(108);
  SDL_SCANCODE_F18 = TSDL_ScanCode(109);
  SDL_SCANCODE_F19 = TSDL_ScanCode(110);
  SDL_SCANCODE_F20 = TSDL_ScanCode(111);
  SDL_SCANCODE_F21 = TSDL_ScanCode(112);
  SDL_SCANCODE_F22 = TSDL_ScanCode(113);
  SDL_SCANCODE_F23 = TSDL_ScanCode(114);
  SDL_SCANCODE_F24 = TSDL_ScanCode(115);
  SDL_SCANCODE_EXECUTE = TSDL_ScanCode(116);
  SDL_SCANCODE_HELP = TSDL_ScanCode(117);    { AL Integrated Help Center }
  SDL_SCANCODE_MENU = TSDL_ScanCode(118);    { Menu (show menu) }
  SDL_SCANCODE_SELECT = TSDL_ScanCode(119);
  SDL_SCANCODE_STOP = TSDL_ScanCode(120);    { AC Stop }
  SDL_SCANCODE_AGAIN = TSDL_ScanCode(121);   { AC Redo/Repeat }
  SDL_SCANCODE_UNDO = TSDL_ScanCode(122);    { AC Undo }
  SDL_SCANCODE_CUT = TSDL_ScanCode(123);     { AC Cut }
  SDL_SCANCODE_COPY = TSDL_ScanCode(124);    { AC Copy }
  SDL_SCANCODE_PASTE = TSDL_ScanCode(125);   { AC Paste }
  SDL_SCANCODE_FIND = TSDL_ScanCode(126);    { AC Find }
  SDL_SCANCODE_MUTE = TSDL_ScanCode(127);
  SDL_SCANCODE_VOLUMEUP = TSDL_ScanCode(128);
  SDL_SCANCODE_VOLUMEDOWN = TSDL_ScanCode(129);
  {* not sure whether there's a reason to enable these *}
  {*     SDL_SCANCODE_LOCKINGCAPSLOCK = 130;  *}
  {*     SDL_SCANCODE_LOCKINGNUMLOCK = 131; *}
  {*     SDL_SCANCODE_LOCKINGSCROLLLOCK = 132; *}
  SDL_SCANCODE_KP_COMMA = TSDL_ScanCode(133);
  SDL_SCANCODE_KP_EQUALSAS400 = TSDL_ScanCode(134);

  SDL_SCANCODE_INTERNATIONAL1 = TSDL_ScanCode(135); {**< used on Asian keyboards; see
                                                         footnotes in USB doc *}
  SDL_SCANCODE_INTERNATIONAL2 = TSDL_ScanCode(136);
  SDL_SCANCODE_INTERNATIONAL3 = TSDL_ScanCode(137); {**< Yen *}
  SDL_SCANCODE_INTERNATIONAL4 = TSDL_ScanCode(138);
  SDL_SCANCODE_INTERNATIONAL5 = TSDL_ScanCode(139);
  SDL_SCANCODE_INTERNATIONAL6 = TSDL_ScanCode(140);
  SDL_SCANCODE_INTERNATIONAL7 = TSDL_ScanCode(141);
  SDL_SCANCODE_INTERNATIONAL8 = TSDL_ScanCode(142);
  SDL_SCANCODE_INTERNATIONAL9 = TSDL_ScanCode(143);
  SDL_SCANCODE_LANG1 = TSDL_ScanCode(144); {**< Hangul/English toggle *}
  SDL_SCANCODE_LANG2 = TSDL_ScanCode(145); {**< Hanja conversion *}
  SDL_SCANCODE_LANG3 = TSDL_ScanCode(146); {**< Katakana *}
  SDL_SCANCODE_LANG4 = TSDL_ScanCode(147); {**< Hiragana *}
  SDL_SCANCODE_LANG5 = TSDL_ScanCode(148); {**< Zenkaku/Hankaku *}
  SDL_SCANCODE_LANG6 = TSDL_ScanCode(149); {**< reserved *}
  SDL_SCANCODE_LANG7 = TSDL_ScanCode(150); {**< reserved *}
  SDL_SCANCODE_LANG8 = TSDL_ScanCode(151); {**< reserved *}
  SDL_SCANCODE_LANG9 = TSDL_ScanCode(152); {**< reserved *}

  SDL_SCANCODE_ALTERASE = TSDL_ScanCode(153); {**< Erase-Eaze *}
  SDL_SCANCODE_SYSREQ = TSDL_ScanCode(154);
  SDL_SCANCODE_CANCEL = TSDL_ScanCode(155);   { AC Cancel }
  SDL_SCANCODE_CLEAR = TSDL_ScanCode(156);
  SDL_SCANCODE_PRIOR = TSDL_ScanCode(157);
  SDL_SCANCODE_RETURN2 = TSDL_ScanCode(158);
  SDL_SCANCODE_SEPARATOR = TSDL_ScanCode(159);
  SDL_SCANCODE_OUT = TSDL_ScanCode(160);
  SDL_SCANCODE_OPER = TSDL_ScanCode(161);
  SDL_SCANCODE_CLEARAGAIN = TSDL_ScanCode(162);
  SDL_SCANCODE_CRSEL = TSDL_ScanCode(163);
  SDL_SCANCODE_EXSEL = TSDL_ScanCode(164);

  SDL_SCANCODE_KP_00 = TSDL_ScanCode(176);
  SDL_SCANCODE_KP_000 = TSDL_ScanCode(177);
  SDL_SCANCODE_THOUSANDSSEPARATOR = TSDL_ScanCode(178);
  SDL_SCANCODE_DECIMALSEPARATOR = TSDL_ScanCode(179);
  SDL_SCANCODE_CURRENCYUNIT = TSDL_ScanCode(180);
  SDL_SCANCODE_CURRENCYSUBUNIT = TSDL_ScanCode(181);
  SDL_SCANCODE_KP_LEFTPAREN = TSDL_ScanCode(182);
  SDL_SCANCODE_KP_RIGHTPAREN = TSDL_ScanCode(183);
  SDL_SCANCODE_KP_LEFTBRACE = TSDL_ScanCode(184);
  SDL_SCANCODE_KP_RIGHTBRACE = TSDL_ScanCode(185);
  SDL_SCANCODE_KP_TAB = TSDL_ScanCode(186);
  SDL_SCANCODE_KP_BACKSPACE = TSDL_ScanCode(187);
  SDL_SCANCODE_KP_A = TSDL_ScanCode(188);
  SDL_SCANCODE_KP_B = TSDL_ScanCode(189);
  SDL_SCANCODE_KP_C = TSDL_ScanCode(190);
  SDL_SCANCODE_KP_D = TSDL_ScanCode(191);
  SDL_SCANCODE_KP_E = TSDL_ScanCode(192);
  SDL_SCANCODE_KP_F = TSDL_ScanCode(193);
  SDL_SCANCODE_KP_XOR = TSDL_ScanCode(194);
  SDL_SCANCODE_KP_POWER = TSDL_ScanCode(195);
  SDL_SCANCODE_KP_PERCENT = TSDL_ScanCode(196);
  SDL_SCANCODE_KP_LESS = TSDL_ScanCode(197);
  SDL_SCANCODE_KP_GREATER = TSDL_ScanCode(198);
  SDL_SCANCODE_KP_AMPERSAND = TSDL_ScanCode(199);
  SDL_SCANCODE_KP_DBLAMPERSAND = TSDL_ScanCode(200);
  SDL_SCANCODE_KP_VERTICALBAR = TSDL_ScanCode(201);
  SDL_SCANCODE_KP_DBLVERTICALBAR = TSDL_ScanCode(202);
  SDL_SCANCODE_KP_COLON = TSDL_ScanCode(203);
  SDL_SCANCODE_KP_HASH = TSDL_ScanCode(204);
  SDL_SCANCODE_KP_SPACE = TSDL_ScanCode(205);
  SDL_SCANCODE_KP_AT = TSDL_ScanCode(206);
  SDL_SCANCODE_KP_EXCLAM = TSDL_ScanCode(207);
  SDL_SCANCODE_KP_MEMSTORE = TSDL_ScanCode(208);
  SDL_SCANCODE_KP_MEMRECALL = TSDL_ScanCode(209);
  SDL_SCANCODE_KP_MEMCLEAR = TSDL_ScanCode(210);
  SDL_SCANCODE_KP_MEMADD = TSDL_ScanCode(211);
  SDL_SCANCODE_KP_MEMSUBTRACT = TSDL_ScanCode(212);
  SDL_SCANCODE_KP_MEMMULTIPLY = TSDL_ScanCode(213);
  SDL_SCANCODE_KP_MEMDIVIDE = TSDL_ScanCode(214);
  SDL_SCANCODE_KP_PLUSMINUS = TSDL_ScanCode(215);
  SDL_SCANCODE_KP_CLEAR = TSDL_ScanCode(216);
  SDL_SCANCODE_KP_CLEARENTRY = TSDL_ScanCode(217);
  SDL_SCANCODE_KP_BINARY = TSDL_ScanCode(218);
  SDL_SCANCODE_KP_OCTAL = TSDL_ScanCode(219);
  SDL_SCANCODE_KP_DECIMAL = TSDL_ScanCode(220);
  SDL_SCANCODE_KP_HEXADECIMAL = TSDL_ScanCode(221);

  SDL_SCANCODE_LCTRL = TSDL_ScanCode(224);
  SDL_SCANCODE_LSHIFT = TSDL_ScanCode(225);
  SDL_SCANCODE_LALT = TSDL_ScanCode(226); {**< alt; option *}
  SDL_SCANCODE_LGUI = TSDL_ScanCode(227); {**< windows; command (apple); meta *}
  SDL_SCANCODE_RCTRL = TSDL_ScanCode(228);
  SDL_SCANCODE_RSHIFT = TSDL_ScanCode(229);
  SDL_SCANCODE_RALT = TSDL_ScanCode(230); {**< alt gr; option *}
  SDL_SCANCODE_RGUI = TSDL_ScanCode(231); {**< windows; command (apple); meta *}

  SDL_SCANCODE_MODE = TSDL_ScanCode(257);    {**< I'm not sure if this is really not covered 
                               *   by any of the above; but since there's a 
                               *   special KMOD_MODE for it I'm adding it here
                               *}

  {**
     *  \name Usage page 0x0C
     *
     *  These values are mapped from usage page 0x0C (USB consumer page).
     *  See https://usb.org/sites/default/files/hut1_2.pdf
     *
     *  There are way more keys in the spec than we can represent in the
     *  current scancode range, so pick the ones that commonly come up in
     *  real world usage.
     */  These values are mapped from usage page $0C (USB consumer page).
   *}

  SDL_SCANCODE_AUDIONEXT = TSDL_ScanCode(258);
  SDL_SCANCODE_AUDIOPREV = TSDL_ScanCode(259);
  SDL_SCANCODE_AUDIOSTOP = TSDL_ScanCode(260);
  SDL_SCANCODE_AUDIOPLAY = TSDL_ScanCode(261);
  SDL_SCANCODE_AUDIOMUTE = TSDL_ScanCode(262);
  SDL_SCANCODE_MEDIASELECT = TSDL_ScanCode(263);
  SDL_SCANCODE_WWW = TSDL_ScanCode(264);
  SDL_SCANCODE_MAIL = TSDL_ScanCode(265);
  SDL_SCANCODE_CALCULATOR = TSDL_ScanCode(266);
  SDL_SCANCODE_COMPUTER = TSDL_ScanCode(267);
  SDL_SCANCODE_AC_SEARCH = TSDL_ScanCode(268);
  SDL_SCANCODE_AC_HOME = TSDL_ScanCode(269);
  SDL_SCANCODE_AC_BACK = TSDL_ScanCode(270);
  SDL_SCANCODE_AC_FORWARD = TSDL_ScanCode(271);
  SDL_SCANCODE_AC_STOP = TSDL_ScanCode(272);
  SDL_SCANCODE_AC_REFRESH = TSDL_ScanCode(273);
  SDL_SCANCODE_AC_BOOKMARKS = TSDL_ScanCode(274);

  {**
   *  Walther keys
   *
   *  These are values that Christian Walther added (for mac keyboard?).
   *}

  SDL_SCANCODE_BRIGHTNESSDOWN = TSDL_ScanCode(275);
  SDL_SCANCODE_BRIGHTNESSUP = TSDL_ScanCode(276);
  SDL_SCANCODE_DISPLAYSWITCH = TSDL_ScanCode(277); {**< display mirroring/dual display
                                                        switch; video mode switch *}
  SDL_SCANCODE_KBDILLUMTOGGLE = TSDL_ScanCode(278);
  SDL_SCANCODE_KBDILLUMDOWN = TSDL_ScanCode(279);
  SDL_SCANCODE_KBDILLUMUP = TSDL_ScanCode(280);
  SDL_SCANCODE_EJECT = TSDL_ScanCode(281);
  SDL_SCANCODE_SLEEP = TSDL_ScanCode(282);  { SC System Sleep }

  SDL_SCANCODE_APP1 = TSDL_ScanCode(283);
  SDL_SCANCODE_APP2 = TSDL_ScanCode(284);

  {**
   *  \name Usage page 0x0C (additional media keys)
   *
   *  These values are mapped from usage page 0x0C (USB consumer page).
   *}

   SDL_SCANCODE_AUDIOREWIND = TSDL_ScanCode(285);
   SDL_SCANCODE_AUDIOFASTFORWARD = TSDL_ScanCode(286);

  {**
   *  \name Mobile keys
   *
   *  These are values that are often used on mobile phones.
   *}

  SDL_SCANCODE_SOFTLEFT = TSDL_ScanCode(287); {**< Usually situated below the display on phones and
                                      used as a multi-function feature key for selecting
                                      a software defined function shown on the bottom left
                                      of the display. *}
  SDL_SCANCODE_SOFTRIGHT = TSDL_ScanCode(288); {**< Usually situated below the display on phones and
                                     used as a multi-function feature key for selecting
                                     a software defined function shown on the bottom right
                                     of the display. *}
  SDL_SCANCODE_CALL = TSDL_ScanCode(289); {**< Used for accepting phone calls. *}
  SDL_SCANCODE_ENDCALL = TSDL_ScanCode(290); {**< Used for rejecting phone calls. *}

  {* Add any other keys here. *}

  SDL_NUM_SCANCODES = TSDL_ScanCode(512); {**< not a key, just marks the number of scancodes
                                               for array bounds *}

