// TestTextMetrics helper: calls FitText with its default ellipsis from a unit WITHOUT a UTF-8
// BOM - keep it so and ASCII-only. FPC converts a non-ASCII default parameter value in the
// caller's source codepage, so a default ellipsis literal reached such a caller as 6 mangled
// bytes (PaintRaw E-43).
unit TextFitNoBom;
interface
uses Apus.Core, Apus.Engine.Types, Apus.Engine.API;

function FitDefault(const td:ITextDrawer;font:TFontHandle;const st:String8;width:single):String8;

implementation

function FitDefault(const td:ITextDrawer;font:TFontHandle;const st:String8;width:single):String8;
begin
  result:=td.FitText(font,st,width);
end;

end.
