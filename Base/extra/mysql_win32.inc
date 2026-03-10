{    *********************************************************************
     * The contents of this file are used with permission, subject to    *
     * the Mozilla Public License Version 1.1 (the "License"); you may   *
     * not use this file except in compliance with the License. You may  *
     * obtain a copy of the License at                                   *
     * http:  www.mozilla.org/MPL/MPL-1.1.html                           *
     *                                                                   *
     * Software distributed under the License is distributed on an       *
     * "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or    *
     * implied. See the License for the specific language governing      *
     * rights and limitations under the License.                         *
     *                                                                   *
     *  Contributor(s)                                                   *
     *  (so)  Samuel Soldat     <samuel.soldat@audio-data.de>            *
     *                                                                   *
     *********************************************************************}

{$IFNDEF EmbeddedCharacterConvert}
type
  TMySqlWindowsMapping=record
    CharacterSetName: String;
    CodePage: Word;
  end;

const
  UnKnownCodePage = $FFFF;
  {Server 4.0:
   latin1 big5 czech euc_kr gb2312 gbk latin1_de sjis tis620 ujis dec8 dos german1
   hp8 koi8_ru latin2 swe7 usa7 cp1251 danish hebrew win1251 estonia hungarian koi8_ukr
   win1251ukr greek win1250 croat cp1257 latin5}
  {Server 3.23
  latin1 big5 czech euc_kr gb2312 gbk sjis tis620 ujis dec8 dos german1 hp8 koi8_ru
  latin2 swe7 usa7 cp1251 danish hebrew win1251 estonia hungarian koi8_ukr win1251ukr
  greek win1250 croat cp1257 latin5}
  MySqlCharacterSetNames: array [0..43] of TMySqlWindowsMapping=(
           (CharacterSetName: 'big5'; CodePage: 950),                 //Big5 Traditional Chinese
           (CharacterSetName: 'dec8'; CodePage: UnKnownCodePage),     //DEC Multinational Character Set=>VT220?
           (CharacterSetName: 'cp850'; CodePage: 850),                //DOS West European
           (CharacterSetName: 'hp8'; CodePage: UnKnownCodePage),      //HP West European
           (CharacterSetName: 'koi8r'; CodePage: 20866),              //KOI8-R Relcom Russian
           (CharacterSetName: 'koi8_ru'; CodePage: 20866),            //KOI8-R Relcom Russian
           (CharacterSetName: 'latin1'; CodePage: 1252),              //cp1252 West European
           (CharacterSetName: 'german1'; CodePage: 1252),             //cp1252 West European
           (CharacterSetName: 'latin1_de'; CodePage: 1252),           //cp1252 West European
           (CharacterSetName: 'latin2'; CodePage: 28592),             //ISO 8859-2 Central European
           (CharacterSetName: 'swe7'; CodePage: 20107),               //7bit Swedish
           (CharacterSetName: 'ascii'; CodePage: 20127),              //US ASCII (#0..#127)
           (CharacterSetName: 'usa7'; CodePage: 20127),               //US ASCII (#0..#127)
           (CharacterSetName: 'dos'; CodePage: 437),                  //US ASCII (#0..#127)
           (CharacterSetName: 'ujis'; CodePage: 51932),               //EUC-JP Japanese
           (CharacterSetName: 'sjis'; CodePage: 932),                 //Shift-JIS Japanese
           (CharacterSetName: 'hebrew'; CodePage: 28598),             //ISO 8859-8 Hebrew
           (CharacterSetName: 'tis620'; CodePage: 874),               //ANSI/OEM Thai (same as 28605, ISO 8859-11); Thai (Windows)
           (CharacterSetName: 'euckr'; CodePage: 51949),              //EUC-KR Korean
           (CharacterSetName: 'euc_kr'; CodePage: 51949),             //EUC-KR Korean
           (CharacterSetName: 'koi8u'; CodePage: 21866),              //KOI8-U Ukrainian
           (CharacterSetName: 'koi8_ukr'; CodePage: 21866),           //KOI8-U Ukrainian
           (CharacterSetName: 'gb2312'; CodePage: 20936),             //GB2312 Simplified Chinese
           (CharacterSetName: 'greek'; CodePage: 28597),              //ISO 8859-7
           (CharacterSetName: 'cp1250'; CodePage: 1250),              //Windows Central European
           (CharacterSetName: 'win1250'; CodePage: 1250),             //Windows Central European
           (CharacterSetName: 'gbk'; CodePage: 936),                  //GBK Simplified Chinese
           (CharacterSetName: 'latin5'; CodePage: 28599),             //ISO 8859-9 Turkish
           (CharacterSetName: 'armscii8'; CodePage: UnKnownCodePage), //ARMSCII-8 Armenian
           (CharacterSetName: 'utf8'; CodePage: 65001),               //UTF-8 Unicode
           (CharacterSetName: 'cp866'; CodePage: 866),                //DOS Russian
           (CharacterSetName: 'keybcs2'; CodePage: UnKnownCodePage),  //DOS Kamenicky Czech-Slovak
           (CharacterSetName: 'macce'; CodePage: 10029),              //Mac Central European
           (CharacterSetName: 'macroman'; CodePage: 10000),           //Mac West European
           (CharacterSetName: 'cp852'; CodePage: 852),                //DOS Central European
           (CharacterSetName: 'latin7'; CodePage: 28603),             //ISO 8859-13 Baltic
           (CharacterSetName: 'cp1251'; CodePage: 1251),              //Windows Cyrillic
           (CharacterSetName: 'win1251'; CodePage: 1251),             //Windows Cyrillic
           (CharacterSetName: 'cp1256'; CodePage: 1256),              //Windows Arabic
           (CharacterSetName: 'cp1257'; CodePage: 1257),              //Windows Baltic
           (CharacterSetName: 'binary'; CodePage: $FFFF),             //RawByteString
           (CharacterSetName: 'geostd8'; CodePage: UnKnownCodePage),  //GEOSTD8 Georgian
           (CharacterSetName: 'cp932'; CodePage: 932),                //SJIS for Windows Japanese
           (CharacterSetName: 'eucjpms'; CodePage: 20932));           //UJIS for Windows Japanese

// -----------------------------------------------------------------------------------------------
// Get the MySql Character set name according to Codepage
// -----------------------------------------------------------------------------------------------

function CodePageToCharsetName(CodePage: Word; List: Boolean): String;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(MySqlCharacterSetNames) do
  begin
    if MySqlCharacterSetNames[i].CodePage=CodePage
    then begin
      Result := Result + MySqlCharacterSetNames[i].CharacterSetName + ',';
      if not List then break;
    end;
  end;
  if Result<>''
  then
    SetLength(Result, Length(Result)-1);
end;

// -----------------------------------------------------------------------------------------------
// Get the Codepage according to MySql Character set name
// -----------------------------------------------------------------------------------------------

function CharsetNameToCodePage(CharacterSetName: String): Word;
var
  i: Integer;
begin
  Result := UnKnownCodePage;
  for i := 0 to High(MySqlCharacterSetNames) do
  begin
    if AnsiSameText(MySqlCharacterSetNames[i].CharacterSetName, CharacterSetName)
    then begin
      Result := MySqlCharacterSetNames[i].CodePage;
      break;
    end;
  end;
end;

{$ENDIF}

function MySqlToUTF16(Source: PAnsiChar; Length: Integer; CodePage: Word): UnicodeString;
var
  DestLen: Integer;
begin
  if (Length<0)
  then
    Length := MySql_StrLen(Source);
  if Length>0
  then begin
    if CodePage=CP_ACP
    then
      CodePage := DefaultMySqlCodePage;
    DestLen := MultiByteToWideChar(CodePage, 0, Source, Length, nil, 0);
    if DestLen>0
    then begin
      SetLength(Result, DestLen);
      MultiByteToWideChar(CodePage, 0, Source, Length, Pointer(Result), DestLen);
    end
    else
      Result := '';
  end
  else
    Result := '';
end;

function UTF16ToMySql(const Source: UnicodeString; CodePage: Word): RawByteString;
var
  SourceLen: Integer;
  DestLen: Integer;
begin
  SourceLen := Length(Source);
  if SourceLen>0
  then begin
    if CodePage=CP_ACP
    then
      CodePage := DefaultMySqlCodePage;
    DestLen := WideCharToMultiByte(CodePage, 0, Pointer(Source), SourceLen, nil, 0, nil, nil);
    if DestLen>0
    then begin
      SetLength(Result, DestLen);
      WideCharToMultiByte(CodePage, 0, Pointer(Source), SourceLen, Pointer(Result), DestLen, nil, nil);
{$IFDEF CONDITIONALEXPRESSIONS}
  {$if defined(FPC)}
    {$IF defined(FPC_HAS_CPSTRING)}
      SetCodePage(Result, CodePage, False);
    {$IFEND}
  {$elseif (CompilerVersion>=20)} {Delphi 2009 and above}
      SetCodePage(Result, CodePage, False);
  {$IFEND}
{$ENDIF}
    end
    else
      Result := '';
  end
  else
    Result := '';
end;

// -----------------------------------------------------------------------------------------------

{ TMySqlEncoding }

constructor TMySqlEncoding.Create(Codepage: Word);
begin
  inherited Create;
  if Codepage=CP_ACP
  then
     FCodepage := GetACP
  else
    FCodepage := Codepage;
end;


function TMySqlEncoding.MySqlToUTF16(Source: PAnsiChar; Length: Integer): UnicodeString;
begin
  Result := mysql.MySqlToUTF16(Source, Length, FCodePage);
end;

function TMySqlEncoding.UTF16ToMySql(const Source: UnicodeString): RawByteString;
begin
  Result := mysql.UTF16ToMySql(Source, FCodePage);
end;
