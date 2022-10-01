// This is the lowest level unit of the Apus Game Engine.
// It should not use any other Engine's units.
//
unit Apus.Engine.Types;
interface
 uses Apus.CrossPlatform, Apus.Types, Apus.Images, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.EventMan, Apus.VertexLayout;

type
 // Strings
 String8 = Apus.Types.String8;
 String16 = Apus.Types.String16;

 // 2D points
 TPoint2 = Apus.Geom2D.TPoint2;
 PPoint2 = Apus.Geom2D.PPoint2;
 TPoint2s = Apus.Geom2D.TPoint2s;
 TVector2s = Apus.Geom2D.TVector2s;
 PPoint2s = ^TPoint2s;
 // 3D Points
 TPoint3 = Apus.Geom3D.TPoint3;
 TVector3 = TPoint3;
 PPoint3 = ^TPoint3;
 TPoint3s = Apus.Geom3D.TPoint3s;
 PPoint3s = ^TPoint3s;
 TVector3s = Apus.Geom3D.TVector3s;
 TVector4 = TQuaternion;
 TVector4s = TQuaternionS;
 // Matrices
 T3DMatrix = TMatrix4;
 T3DMatrixS = TMatrix4s;
 T2DMatrix = TMatrix32s;

 TRect2s = Apus.Geom2D.TRect2s;

 TAsyncProc = function(param:UIntPtr):integer;

 TVertexComponent = Apus.VertexLayout.TVertexComponent;
 TVertexLayout = Apus.VertexLayout.TVertexLayout;

 TIndices=WordArray;

 // Packed ARGB color
 TARGBColor=Apus.Colors.TARGBColor;
 PARGBColor=Apus.Colors.PARGBColor;

 // Primitive types
 TPrimitiveType=(
   LINE_LIST,
   LINE_STRIP,
   TRG_FAN,
   TRG_STRIP,
   TRG_LIST);

 TFontHandle=cardinal;

 TMonoGradient=record
  base,dx,dy:single;
  procedure Init(v1,v2,angle,scale:single);
  function ValueAt(x,y:single):single; inline;
 end;
 // Linear gradient
 TColorGradient=record
  red,green,blue,alpha:TMonoGradient;
  procedure Init(color1,color2:cardinal;angle,scale:single);
  function ColorAt(x,y:single):cardinal;
 end;

implementation
 uses Apus.Common;
 {$EXCESSPRECISION OFF}

{ TGradient }
 const
  k255 = 1/255;

 function TColorGradient.ColorAt(x,y:single):cardinal;
  begin
   result:=MyColorF(alpha.ValueAt(x,y),red.valueAt(x,y),green.ValueAt(x,y),blue.ValueAt(x,y));
  end;

 procedure TColorGradient.Init(color1,color2:cardinal;angle,scale:single);
  begin
   alpha.Init(PARGBColor(@color1).a*k255,PARGBColor(@color2).a*k255,angle,scale);
   red.Init(PARGBColor(@color1).r*k255,PARGBColor(@color2).r*k255,angle,scale);
   green.Init(PARGBColor(@color1).g*k255,PARGBColor(@color2).g*k255,angle,scale);
   blue.Init(PARGBColor(@color1).b*k255,PARGBColor(@color2).b*k255,angle,scale);
  end;

{ TMonoGradient }
 procedure TMonoGradient.Init(v1,v2,angle,scale:single);
  begin
   base:=(v1+v2)/2;
   dx:=(v2-v1)*cos(angle)/scale;
   dy:=(v2-v1)*sin(angle)/scale;
  end;

 function TMonoGradient.ValueAt(x,y:single):single;
  begin
   result:=Clamp(base+(x*2-1)*dx+(y*2-1)*dy,0,1);
  end;

end.
