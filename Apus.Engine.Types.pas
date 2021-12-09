// This is the lowest level unit of the Apus Game Engine.
// It should not use any other Engine's units.
//
unit Apus.Engine.Types;
interface
 uses Apus.CrossPlatform, Apus.MyServis, Apus.Images, Apus.Geom2D, Apus.Geom3D,
   Apus.Colors, Apus.EventMan, Apus.VertexLayout;

type
 // Strings
 String8 = Apus.MyServis.String8;
 String16 = Apus.MyServis.String16;

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

 TVertexLayout=Apus.VertexLayout.TVertexLayout;

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


implementation

end.
