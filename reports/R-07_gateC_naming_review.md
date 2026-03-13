# R-07 Gate C: Public Function Naming Review
Created: 2026-03-12

## Goal
Review public function names in `Geom2D/Geom3D/Spatial` for ambiguity, redundancy, and consistency with records-first API.

## Result summary
- `Apus.Spatial`: naming is already consistent and clear (`Intersects*`, `Contains*`, `InitFromMVP`).
- `Apus.Geom2D` / `Apus.Geom3D`: most issues are legacy compatibility names and abbreviations.

## Recommended rename/deprecation map

1. Keep as compatibility wrappers (deprecated, no immediate break)
- `VectAdd`, `VectSub`, `VectMult`, `VectDiv`, `VectInv`
- `BBoxInclude`, `BBoxIncludePnt`, `BBoxIncludeBox`, `BBoxIntersect`
- `InitPlane`, `GetPlaneOffset`

2. Rename candidates (add canonical aliases first, migrate callsites, then deprecate old)
- `DecomposeMartix` -> `DecomposeMatrix` (typo fix)
- `MultPnt` -> `TransformPoints`
- `QLength` -> `QuatLength`
- `QScale` -> `QuatScale`
- `QNormalize` -> `QuatNormalize`
- `QInvert` -> `QuatInvert`
- `QMult` -> `QuatMultiply`
- `QInterpolate` -> `QuatLerp` (or `QuatSlerp` if behavior changed later)

3. Keep standalone by design
- Multi-entity algorithms:
  - `IntersectLines`, `IntersectSegm`, `PointInTrg`, `Triangulate`, `IntersectTrgLine`
- Matrix algebra namespace-level functions:
  - `MultMat`, `Transpose`, `Invert`, `InvertFull`, `Det`

## Naming style recommendations
- New public APIs: verb-first and explicit (`TransformPoint`, `IntersectsSphere`, `ContainsPoint`).
- Avoid short ambiguous prefixes in new names (`Q*`, `Pnt`, `Vect*`) except legacy wrappers.
- Use compatibility wrappers only as migration bridge; new code should prefer record methods.

## Proposed execution
1. Add canonical aliases for typo/abbreviation names.
2. Migrate tests and new code to canonical names.
3. Mark old names deprecated with migration hints in messages.
