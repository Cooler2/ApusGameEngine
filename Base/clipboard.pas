// -----------------------------------------------------
// Cross-platform access to system clipboard
// Author: Ivan Polyacov (C) 2011, Apus Software
// ivan@apus-software.com or cooler@tut.by
// ------------------------------------------------------
unit clipboard;
interface
 procedure CopyStrToClipboard(st:string); overload;
 procedure CopyStrToClipboard(wst:Widestring); overload;
 function PasteStrFromClipboard:string;
 function PasteStrFromClipboardW:WideString;

implementation
{$IFDEF DELPHI} // Windows, Delphi
 uses windows,clipbrd;
 type
  TMyClipboard=class(TClipboard)
   procedure SetTextBufW(st:WideString);
   function GetTextBufW:WideString;
  end;

 procedure TMyClipboard.SetTextBufW(st: WideString);
  begin
   SetBuffer(CF_UNICODETEXT, (@st[1])^, 2*length(st)+2);
  end;

function TMyClipboard.GetTextBufW:WideString;
var
  Data: THandle;
  p:pointer;
  size:integer;
begin
  Open;
  Data := GetClipboardData(CF_UNICODETEXT);
  if Data = 0 then Result := '' else
  begin
    p:=GlobalLock(Data);
    size:=GlobalSize(Data);
    SetLength(result,size div 2);
    move(p^,result[1],size);
    GlobalUnlock(Data);
  end;
  Close;
  // “екст заканчиваетс€ на #0 - надо его удалить
  if (length(result)>0) and (result[length(result)]=#0) then
   SetLength(result,length(result)-1);
end;


 procedure CopyStrToClipboard(st:string);
  begin
   clipbrd.clipboard.Open;
   clipbrd.clipboard.SetTextBuf(PChar(st));
   clipbrd.clipboard.Close;
  end;
 procedure CopyStrToClipboard(wst:Widestring);
  begin
   clipbrd.clipboard.Open;
   TMyClipboard(clipbrd.clipboard).SetTextBufW(wst);
   clipbrd.clipboard.Close;
  end;

 function PasteStrFromClipboard:string;
  var
   size:integer;
   buf:array[0..250] of char;
  begin
   clipbrd.clipboard.Open;
   size:=clipbrd.clipboard.GetTextBuf(PChar(@buf),250);
   result:='';
   if size>0 then
    result:=PChar(@buf);
   clipbrd.clipboard.Close;
  end;
 function PasteStrFromClipboardW:WideString;
  begin
   clipbrd.clipboard.Open;
   result:=TMyClipboard(clipbrd.clipboard).GetTextBufW;
   clipbrd.clipboard.Close;
  end;
{$ENDIF}
{$IFDEF FPC}
 procedure CopyStrToClipboard(st:string);
  begin
  end;

 function PasteStrFromClipboard:string;
  begin
   result:='';
  end;

 procedure CopyStrToClipboard(wst:Widestring);
  begin

  end;

 function PasteStrFromClipboardW:WideString;
  begin
   result:='';
  end;

{$ENDIF}

end.

