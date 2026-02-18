// Compile all Base modules in Delphi to check for errors and dependencies.
program BuildTestDelphi;
{$APPTYPE CONSOLE}

uses
  // Level 0: no Apus dependencies
  Apus.Types,
  Apus.CPU,
  Apus.Crypto,
  Apus.ADPCM,
  Apus.LongMath,
  Apus.RegExpr,

  // Level 1: Core API
  Apus.Core,
  Apus.Colors,
  Apus.Conv,
  Apus.Strings,
  Apus.Log,

  // Level 2: Utils and platform
  Apus.Utils,
  Apus.Files,
  Apus.Threads,
  Apus.HashMaps,
  Apus.Geom2D,
  Apus.Geom3D,

  // Level 3: Higher-level data structures
  Apus.Classes,
  Apus.EventMan,
  Apus.Lib,
  Apus.Tweenings,
  Apus.AnimatedValues,

  // Level 4: Structs and graphics primitives
  Apus.Structs,
  Apus.FastGFX,
  Apus.VertexLayout,
  Apus.Socket,

  // Level 5: Images and collections
  Apus.Images,
  Apus.GfxFilters,
  Apus.Regions,
  Apus.ProdCons,
  Apus.Huffman,

  // Level 6: Network and files
  Apus.ControlFiles,
  Apus.TCP,

  // Level 7: High-level network
  Apus.HttpRequests,
  Apus.GfxFormats,

  // Level 8: Text and data
  Apus.TextUtils,
  Apus.UnicodeFont,
  Apus.Translation,
  Apus.Database,

  // Level 9: Specialized
  Apus.HtmlTree,
  Apus.FreeTypeFont,
  Apus.GlyphCaches,
  Apus.GeoIP,

  // Level 10: Diagnostics and extras
  Apus.Logging,
  Apus.Profiling,
  Apus.StackTrace,
  Apus.Clipboard,
  Apus.MemoryLeakUtils,
  Apus.Publics,
  Apus.RSA,
  Apus.SCGI;

begin
end.
