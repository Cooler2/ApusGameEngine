// -----------------------------------------------------
// Cross-platform access to system clipboard
// Author: Ivan Polyacov (C) 2011, Apus Software, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
// ------------------------------------------------------
unit Apus.Clipboard;

interface

  procedure CopyStrToClipboard(st:UTF8String); overload;
  procedure CopyStrToClipboard(wst:Widestring); overload;
  function PasteStrFromClipboard:UTF8String;
  function PasteStrFromClipboardW:Widestring;

  // Supported images: TRAWImage
  procedure PutImageToClipboard(image:TObject);

implementation

{$IFDEF MSWINDOWS}

  uses Windows,Apus.MyServis,SysUtils,Apus.Images,VCL.Clipbrd;

  procedure Open;
    var
     counter:integer;
    begin
      for counter:=1 to 20 do
       if OpenClipboard(0) then exit
         else sleep(10);
      raise EWarning.Create('Failed to open Clipboard');
    end;

  procedure SetBuffer(Format:Word; var Buffer; Size:Integer);
    var
      DataPtr:Pointer;
      Data:THandle;
    begin
      Open;
      Data:=GlobalAlloc(GMEM_MOVEABLE,Size);
      try
        DataPtr:=GlobalLock(Data);
        try
          Move(Buffer,DataPtr^,Size);
          if SetClipboardData(Format,Data)=0 then
              raise EWarning.Create('Failed to set clipboard data');
        finally
            GlobalUnlock(Data);
        end;
      except
          GlobalFree(Data);
      end;
      CloseClipboard;
    end;

  function GetTextBufW:Widestring;
    var
      Data:THandle;
      p:Pointer;
      Size:Integer;
    begin
      Open;
      Data:=GetClipboardData(CF_UNICODETEXT);
      if Data=0 then
          Result:=''
      else
        begin
          p:=GlobalLock(Data);
          Size:=GlobalSize(Data);
          SetLength(Result,Size div 2);
          Move(p^,Result[1],Size);
          GlobalUnlock(Data);
        end;
      CloseClipboard;
      // Текст заканчивается на #0 - надо его удалить
      if (length(Result)>0)and(Result[length(Result)]=#0) then
          SetLength(Result,length(Result)-1);
    end;

  function GetTextBuf(buffer:Pointer; bufSize:Integer; Format:UINT):Integer;
    var
      data:THandle;
      p:pointer;
      size:integer;
    begin
      Open;
      try
        data:=GetClipboardData(Format);
        result:=0;
        if data<>0 then begin
          if format=CF_TEXT then begin
            result:=StrLen(StrLCopy(PAnsiChar(buffer),GlobalLock(Data),bufSize-1));
            GlobalUnlock(data);
          end;
          if format=CF_UNICODETEXT then begin
            p:=GlobalLock(Data);
            size:=GlobalSize(Data);
            if size>bufSize then size:=bufSize;
            move(p^,buffer^,size);
            result:=size;
            GlobalUnlock(data);
          end;
        end;
      finally
        CloseClipboard;
      end;
    end;

  procedure CopyStrToClipboard(st:UTF8String);
    begin
      SetBuffer(CF_TEXT,(@st[1])^,length(st)+1);
    end;

  procedure CopyStrToClipboard(wst:Widestring);
    begin
      SetBuffer(CF_UNICODETEXT,(@wst[1])^,2*length(wst)+2); // additional 2 bytes for #0 terminator
    end;

  function PasteStrFromClipboard:UTF8String;
    var
      size:Integer;
      buf:array [0..250] of AnsiChar;
    begin
      Open;
      size:=GetTextBuf(PChar(@buf),250,CF_TEXT);
      result:='';
      if size>0 then begin
       SetLength(result,size);
       move(buf,result[1],size);
      end;
      CloseClipboard;
    end;

  function PasteStrFromClipboardW:Widestring;
    var
      size:Integer;
      buf: array [0..250] of AnsiChar;
    begin
      Open;
      size:=GetTextBuf(PChar(@buf),250,CF_UNICODETEXT);
      Result:='';
      if size>0 then
          result:=PWideChar(@buf);
      if result[length(result)]=#0 then SetLength(result,length(result)-1);
      CloseClipboard;
    end;

  procedure PutImageToClipboard(image:TObject);
   const
    masks:array[0..2] of cardinal=($FF,$FF00,$FF0000);
   var
    header:TBitmapInfoHeader;
    cbData:ByteArray;
    size,i,pos:integer;
    pb:PByte;
   begin
    if image is TRawImage then
     with image as TRawImage do begin
      ZeroMemory(@header,sizeof(header));

      header.biSize:=sizeof(header);
      header.biWidth:=width;
      header.biHeight:=height;
      header.biPlanes:=1;
      header.biBitCount:=pixelSize[PixelFormat];
      header.biCompression:=BI_RGB; // BI_BITFIELDS; //
      size:=width*height*pixelSize[PixelFormat] div 8;
      //header.biSizeImage:=size;
      header.biXPelsPerMeter:=2835; // 72 DPI
      header.biYPelsPerMeter:=2835; // 72 DPI

      SetLength(cbData,sizeof(header)+size);
      move(header,cbData[0],sizeof(header));
      pb:=data;
      pos:=sizeof(header);
      if header.biCompression=BI_BITFIELDS then begin
       move(masks,cbData[pos],sizeof(masks));
       inc(pos,sizeof(masks));
      end;
      size:=size div height; // scanline size
      inc(pb,pitch*(height-1)); // flip vertical
      for i:=0 to height-1 do begin
       move(pb^,cbData[pos],size);
       dec(pb,pitch);
       inc(pos,size);
      end;
      SetBuffer(CF_DIB,cbData[0],Length(cbData));
      exit;
    end;
    raise EError.Create('Object of class %s not supported ',[image.ClassName]);
   end;

{$ELSE}
  procedure CopyStrToClipboard(st:UTF8String); overload;
    begin
    end;

  procedure CopyStrToClipboard(wst:Widestring); overload;
    begin
    end;

  function PasteStrFromClipboard:UTF8String;
    begin
    end;

  function PasteStrFromClipboardW:Widestring;
    begin
    end;

  procedure PutImageToClipboard(data:TObject);
   begin
   end;
{$ENDIF}

end.
