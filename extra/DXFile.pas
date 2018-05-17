(*==========================================================================;
 *
 *  Copyright (C) 1999 Microsoft Corporation.  All Rights Reserved.
 *
 *  File:       dxfile.h
 *  Content:    Interfaces to access Rendermorthics eXtensible file format
 *
 *  Direct3DX 8.0 Delphi adaptation by Alexey Barkovoy
 *  E-Mail: clootie@reactor.ru
 *
 *  completely revised by Tim Baumgarten
 *
 *  Modified: 20-Dec-2000
 *
 *  Partly based upon :
 *    DirectX 7.0 Delphi adaptation by
 *      Erik Unger, e-Mail: DelphiDirectX@next-reality.com
 *
 *  Lastest version can be downloaded from:
 *     http://www.delphi-jedi.org/DelphiGraphics/
 *
 ***************************************************************************)

{$MINENUMSIZE 4}
{$ALIGN ON}

unit DXFile;

interface

uses Windows;

(***************************************************************************
 *
 *  Copyright (C) 1998-1999 Microsoft Corporation.  All Rights Reserved.
 *
 *  File:       dxfile.h
 *
 *  Content:    DirectX File public header file
 *
 ***************************************************************************)

type
  TDXFileFormat = Cardinal;

const
  DXFILEFORMAT_BINARY     = 0;
  DXFILEFORMAT_TEXT       = 1;
  DXFILEFORMAT_COMPRESSED = 2;

type
  TDXFileLoadOptions = Cardinal;

const
  DXFILELOAD_FROMFILE           = $00;
  DXFILELOAD_FROMRESOURCE       = $01;
  DXFILELOAD_FROMMEMORY         = $02;
  DXFILELOAD_FROMSTREAM         = $04;
  DXFILELOAD_FROMURL            = $08;

type
  PDXFileLoadResource = ^TDXFileLoadResource;
  TDXFileLoadResource = packed record
    hModule : HModule;
    lpName  : PChar;
    lpType  : PChar;
  end;

  PDXFileLoadMemory = ^TDXFileLoadMemory;
  TDXFileLoadMemory = packed record
    lpMemory : Pointer;
    dSize    : Cardinal;
  end;

(*
 * DirectX File object types.
 *)

type
  IDirectXFile = interface;
  IDirectXFileEnumObject = interface;
  IDirectXFileSaveObject = interface;
  IDirectXFileObject = interface;
  IDirectXFileData = interface;
  IDirectXFileDataReference = interface;
  IDirectXFileBinary = interface;

(*
 * DirectX File interfaces.
 *)

  IDirectXFile = interface(IUnknown)
    ['{3d82ab40-62da-11cf-ab39-0020af71e433}']
    function CreateEnumObject(const pvSource: Pointer; const dwLoadOptions : TDXFileLoadOptions; out ppEnumObj : IDirectXFileEnumObject) : HResult; stdcall;
    function CreateSaveObject(const szFileName: PChar; const dwFileFormat: TDXFileFormat; out ppSaveObj : IDirectXFileSaveObject) : HResult; stdcall;
    function RegisterTemplates(const pvData : Pointer; const cbSize : Cardinal) : HResult; stdcall;
  end;

  IDirectXFileEnumObject = interface (IUnknown)
    ['{3d82ab41-62da-11cf-ab39-0020af71e433}']
    function GetNextDataObject(out ppDataObj : IDirectXFileData) : HResult; stdcall;
    function GetDataObjectById(const rguid : TGUID; out ppDataObj : IDirectXFileData) : HResult; stdcall;
    function GetDataObjectByName(const szName : PChar; out ppDataObj : IDirectXFileData) : HResult; stdcall;
  end;

  IDirectXFileSaveObject = interface (IUnknown)
    ['{3d82ab42-62da-11cf-ab39-0020af71e433}']
    function SaveTemplates(const cTemplates : Cardinal; var ppguidTemplates : PGUID) : HResult; stdcall;
    function CreateDataObject(const rguidTemplate : TGUID; const szName : PChar; const pguid : PGUID; const cbSize : Cardinal; pvData: Pointer; out ppDataObj : IDirectXFileData) : HResult; stdcall;
    function SaveData(pDataObj : IDirectXFileData) : HResult; stdcall;
  end;

  IDirectXFileObject = interface (IUnknown)
    ['{3d82ab43-62da-11cf-ab39-0020af71e433}']
    function GetName(const pstrNameBuf : PChar; dwBufLen : PDWord) : HResult; stdcall;
    function GetId (out pGuidBuf : TGUID) : HResult; stdcall;
  end;

  IDirectXFileData = interface (IDirectXFileObject)
    ['{3d82ab44-62da-11cf-ab39-0020af71e433}']
    function GetData(const szMember: PChar; var pcbSize : Cardinal; out ppvData : Pointer) : HResult; stdcall;
    function GetType(out ppguid : PGUID) : HResult; stdcall;
    function GetNextObject(out ppChildObj : IDirectXFileObject) : HResult; stdcall;
    function AddDataObject(const pDataObj : IDirectXFileData) : HResult; stdcall;
    function AddDataReference(const szRef : PChar; const pguidRef : PGUID) : HResult; stdcall;
    function AddBinaryObject(const szName : PChar; const pguid: PGUID; const szMimeType: PChar; const pvData: Pointer; const cbSize: Cardinal) : HResult; stdcall;
  end;

  IDirectXFileDataReference = interface (IDirectXFileObject)
    ['{3d82ab45-62da-11cf-ab39-0020af71e433}']
    function Resolve(out ppDataObj : IDirectXFileData) : HResult; stdcall;
  end;

  IDirectXFileBinary = interface (IDirectXFileObject)
    ['{3d82ab46-62da-11cf-ab39-0020af71e433}']
    function GetSize(out pcbSize : Cardinal) : HResult; stdcall;
    function GetMimeType(out pszMimeType : PChar) : HResult; stdcall;
    function Read(pvData : Pointer; const cbSize : Cardinal; out pcbRead : Cardinal) : HResult; stdcall;
  end;

  
(*
 * DirectXFile Object Class Id (for CoCreateInstance())
 *)

const
  CLSID_CDirectXFile: TGUID =
       (D1:$4516ec43;D2:$8f20;D3:$11d0;D4:($9b,$6d,$00,$00,$c0,$78,$1b,$c3));

(*
 * DirectX File Interface GUIDs.
 *)

type
  IID_IDirectXFile               = IDirectXFile;
  IID_IDirectXFileEnumObject     = IDirectXFileEnumObject;
  IID_IDirectXFileSaveObject     = IDirectXFileSaveObject;
  IID_IDirectXFileObject         = IDirectXFileObject;
  IID_IDirectXFileData           = IDirectXFileData;
  IID_IDirectXFileDataReference  = IDirectXFileDataReference;
  IID_IDirectXFileBinary         = IDirectXFileBinary;

(*
 * DirectX File Header template's GUID.
 *)

const
  TID_DXFILEHeader: TGUID =
      (D1:$3d82ab43;D2:$62da;D3:$11cf;D4:($ab,$39,$00,$20,$af,$71,$e4,$33));

(*
 * DirectX File errors.
 *)

const
  _FACD3D = $876;

//#define MAKE_DDHRESULT( code )  MAKE_HRESULT( 1, _FACD3D, code )
function MAKE_DDHRESULT(Code: DWord): DWord;

const
  MAKE_DDHRESULT_D     = (1 shl 31) or (_FACD3D shl 16);

  DXFILE_OK                           = 0;

  DXFILEERR_BADOBJECT                 = HResult(MAKE_DDHRESULT_D or 850);
  DXFILEERR_BADVALUE                  = HResult(MAKE_DDHRESULT_D or 851);
  DXFILEERR_BADTYPE                   = HResult(MAKE_DDHRESULT_D or 852);
  DXFILEERR_BADSTREAMHANDLE           = HResult(MAKE_DDHRESULT_D or 853);
  DXFILEERR_BADALLOC                  = HResult(MAKE_DDHRESULT_D or 854);
  DXFILEERR_NOTFOUND                  = HResult(MAKE_DDHRESULT_D or 855);
  DXFILEERR_NOTDONEYET                = HResult(MAKE_DDHRESULT_D or 856);
  DXFILEERR_FILENOTFOUND              = HResult(MAKE_DDHRESULT_D or 857);
  DXFILEERR_RESOURCENOTFOUND          = HResult(MAKE_DDHRESULT_D or 858);
  DXFILEERR_URLNOTFOUND               = HResult(MAKE_DDHRESULT_D or 859);
  DXFILEERR_BADRESOURCE               = HResult(MAKE_DDHRESULT_D or 860);
  DXFILEERR_BADFILETYPE               = HResult(MAKE_DDHRESULT_D or 861);
  DXFILEERR_BADFILEVERSION            = HResult(MAKE_DDHRESULT_D or 862);
  DXFILEERR_BADFILEFLOATSIZE          = HResult(MAKE_DDHRESULT_D or 863);
  DXFILEERR_BADFILECOMPRESSIONTYPE    = HResult(MAKE_DDHRESULT_D or 864);
  DXFILEERR_BADFILE                   = HResult(MAKE_DDHRESULT_D or 865);
  DXFILEERR_PARSEERROR                = HResult(MAKE_DDHRESULT_D or 866);
  DXFILEERR_NOTEMPLATE                = HResult(MAKE_DDHRESULT_D or 867);
  DXFILEERR_BADARRAYSIZE              = HResult(MAKE_DDHRESULT_D or 868);
  DXFILEERR_BADDATAREFERENCE          = HResult(MAKE_DDHRESULT_D or 869);
  DXFILEERR_INTERNALERROR             = HResult(MAKE_DDHRESULT_D or 870);
  DXFILEERR_NOMOREOBJECTS             = HResult(MAKE_DDHRESULT_D or 871);
  DXFILEERR_BADINTRINSICS             = HResult(MAKE_DDHRESULT_D or 872);
  DXFILEERR_NOMORESTREAMHANDLES       = HResult(MAKE_DDHRESULT_D or 873);
  DXFILEERR_NOMOREDATA                = HResult(MAKE_DDHRESULT_D or 874);
  DXFILEERR_BADCACHEFILE              = HResult(MAKE_DDHRESULT_D or 875);
  DXFILEERR_NOINTERNET                = HResult(MAKE_DDHRESULT_D or 876);

(*
 * API for creating IDirectXFile interface.
 *)

function DirectXFileCreate(out lplpDirectXFile : IDirectXFile) : HResult; stdcall;

implementation

//#define MAKE_D3DHRESULT( code )  MAKE_HRESULT( 1, _FACD3D, code )
function MAKE_DDHRESULT(Code: DWord): DWord;
begin
  Result:= DWord((1 shl 31) or (_FACD3D shl 16)) or Code;
end;

(*
 * API for creating IDirectXFile interface.
 *)

const
  DXFileDLL = 'D3DXOF.DLL';

function DirectXFileCreate; external DXFileDLL;

end.
