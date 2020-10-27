{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit ApusBase;

{$warn 5023 off : no warning about unused units}
interface

uses
  Apus.ADPCM, Apus.Android, Apus.AnimatedValues, Apus.Clipboard, Apus.Colors, 
  Apus.ControlFiles, Apus.CrossPlatform, Apus.Crypto, Apus.Database, 
  Apus.EventMan, Apus.FastGFX, Apus.FreeTypeFont, Apus.GeoIP, Apus.Geom2D, 
  Apus.Geom3D, Apus.GfxFilters, Apus.GfxFormats, Apus.GlyphCaches, 
  Apus.HttpRequests, Apus.Huffman, Apus.Images, Apus.Logging, Apus.LongMath, 
  Apus.MemoryLeakUtils, Apus.MyServis, Apus.Network, Apus.Profiling, 
  Apus.Publics, Apus.RegExpr, Apus.Regions, Apus.RSA, Apus.SCGI, 
  Apus.StackTrace, Apus.Structs, Apus.TextUtils, Apus.Translation, 
  Apus.UnicodeFont, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('ApusBase', @Register);
end.
