# R-07 Gate D: Coverage Matrix (Geom2D/Geom3D/Spatial)
Created: 2026-03-12

## Current test suites
- `Base/tests/TestGeom2D.dpr`
- `Base/tests/TestGeom3D.dpr`
- `Base/tests/TestSpatial.dpr`

## Coverage status by area

### Geom2D
- Covered:
  - `TVec2` core math (`Dot`, `Cross`, `Length`, `Length2`, `Sub`)
  - distance/angle helpers (`Distance`, `Distance2`, `VectAngle`, `AngleDiff`)
  - line/segment intersection basics (`SetLine`, `IntersectLines`, `IntersectSegm`)
  - comparison/wrapping helpers (`AboutEqual`, `LexCompare`, `TVec2/TVec2d.Wrap`)
  - polygon/basic helpers (`PointInTrg`, `Bezier2D`, `PointOnSegment`)
  - matrix basics (`RotationMat2`, `Transp2`, `Invert2`)
  - `TRect2s` core behavior
- Missing / weak:
  - boundary/NaN behavior for `IsValid` in malformed numeric states

### Geom3D
- Covered:
  - `TVec3` core and normalize path
  - matrix multiply/inversion baseline (`MultMat`, `InvertFull`)
  - quaternion conversion baseline (`MatrixToQuaternion`, `QuaternionToMatrix`)
  - `TBBox3` methods (`IncludePoint`, `Center`, `Extents`, `ContainsPoint`, intersections)
  - plane basics (`TPlane.Init`, `TPlane.Offset`) and compatibility wrappers
  - canonical naming check path (`DecomposeMatrix`)
  - `MatrixFromYawRollPitch` / `YawRollPitchFromMatrix` roundtrip via matrix reconstruction
  - `RotationX/Y/ZMat3s` consistency with double builders
  - `IntersectTrgLine` direct hit/miss/parallel cases
  - `CompareSingle/CompareDouble` positive and negative cases
- Missing / weak:
  - precision-threshold boundary values for `CompareSingle/CompareDouble`
  - deeper `RotationAroundVector` numerical edge-cases (very small/very large angles)

### Spatial
- Covered:
  - `TRay` intersections: sphere/box/triangle/plane
  - epsilon-sensitive ray behavior (near-parallel slab/plane checks)
  - triangle barycentric boundaries (edge/vertex/near-edge outside)
  - `TSphere` intersections: sphere/box
  - `TFrustum` init/intersections with 4-plane and 6-plane modes
  - tangent and near-tangent frustum culling boundaries for sphere and box
  - `TBBox3` spatial methods
- Missing / weak:
  - degenerate frustum matrix behavior (non-invertible/extreme scales)

## Conclusion
- Spatial suite is close to feature-complete for current API.
- Geom2D/Geom3D still have untested legacy and edge paths.
- 100% function+edge coverage is not reached yet; next steps should focus on explicit missing list above.

## Proposed execution order
1. Add targeted Geom2D tests for `Triangulate`, `TMat32d`, and rect transforms.
2. Add targeted Geom3D tests for yaw/roll/pitch and rotation-matrix builders.
3. Add numeric stress tests for Spatial epsilon-sensitive paths.
