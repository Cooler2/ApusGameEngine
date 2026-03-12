# R-07 Geometry Test Coverage Matrix

Updated: 2026-03-12 18:26:42

Method:
- API names parsed from unit interface sections (`function`/`procedure`).
- Coverage means function name appears in `TestGeom2D/TestGeom3D/TestSpatial` sources.
- This is a conservative textual baseline and must be validated by targeted tests.

## Geom2D
- Total API names: 74
- Covered names: 27
- Missing names: 47

### Missing (Geom2D)
- AboutEqual
- Bezier2D
- CrossProduct
- DotProduct
- GetIntRect
- GetLength
- GetRound
- GetSqrLength
- InitWH
- IntersectRects
- Invert
- Invert2
- IsValid
- LexCompare
- MultPnts
- OrderRect
- Point2s
- PointAdd
- PointBlend
- PointDev2
- PointOnSegment
- RandomPointInCircle
- RotationMat
- RotationMat2
- Round
- RoundRect
- ScaleMat
- SegmAboutZero
- ToSingle32
- TransformRect
- TranslationMat
- Transp
- Transp2
- Triangulate
- Turn90L
- Turn90Left
- Turn90R
- Turn90Right
- VectAdd
- VectAngleClockwise
- VectDiv
- VectInv
- VectMult
- Vector2
- Vector2s
- VectSub
- VectTurn

## Geom3D
- Total API names: 98
- Covered names: 32
- Missing names: 66

### Missing (Geom3D)
- BBoxInclude
- BBoxIncludeBox
- BBoxIncludePnt
- BBoxIntersect
- CompareDouble
- CompareSingle
- CrossProduct
- DecomposeMartix
- Det
- DotProd
- DotProduct
- GetLength
- GetPlaneOffset
- GetSqrLength
- IncludeBox
- InitPlane
- IntersectTrgLine
- Invert
- IsIdentity
- IsNear
- IsNearS
- IsValid
- IsZero
- MatCol
- Matrix3
- Matrix3s
- Matrix4
- Matrix4s
- MatrixFromQuaternion
- MatrixFromYawRollPitch
- MatRow
- Middle
- Multiply
- MultNormal
- Point3
- PointAdd
- PointBetween
- QInterpolate
- QInvert
- QLength
- QMult
- QNormalize
- QScale
- RotationXMat
- RotationXMat3s
- RotationXMat4s
- RotationYMat
- RotationYMat3s
- RotationYMat4s
- RotationZMat
- RotationZMat3s
- RotationZMat4s
- ScaleMat
- ToSingle43
- TransformPoint
- TranslationMat
- TranslationMat4
- Transpose
- VecMult
- VectAdd
- VectMult
- Vector3
- Vector4
- Vector4s
- VectSub
- YawRollPitchFromMatrix

## Next Actions
- Add targeted tests for every missing API name and overload-specific edge-cases.
- Track zero-vector normalization behavior explicitly (currently raises exception).
- Re-run matrix after each test expansion until missing list is empty.
