# R-07 Gate B: Standalone Function Inventory
Created: 2026-03-12

## Scope
- `Base/Apus.Geom2D.pas`
- `Base/Apus.Geom3D.pas`
- `Base/Apus.Spatial.pas`

## Summary
- `Apus.Spatial`: public standalone functions are effectively removed; API is records-first (`TBBox3`, `TRay`, `TSphere`, `TFrustum`, `TSpatial`).
- `Apus.Geom2D` and `Apus.Geom3D`: many standalone functions remain for compatibility and mature math API surface.

## Remaining standalone groups and rationale

1. Legacy compatibility wrappers (keep for now)
- Geom2D examples: `DotProduct`, `CrossProduct`, `Distance`, `Distance2`, `Normalize`, `PointAdd`.
- Geom3D examples: `DotProduct`, `CrossProduct`, `Distance`, `Distance2`, `Q*` quaternion helpers.
- Rationale: widely used by existing engine code/tests; immediate removal is high-risk API break.

2. Factory/conversion helpers (keep for now)
- Geom2D: `Point2`, `Point2s`, `Vector2`, `Direction`.
- Geom3D: `Point3`, `Point3s`, `Vector3`, `Vector4`, `Matrix3/4/4s`.
- Rationale: concise constructors/converters are practical at callsites and map cleanly to old code.

3. Matrix algebra procedures (candidate for later scoped migration)
- Geom2D: `MultMat`, `Transpose`, `Invert`.
- Geom3D: `MultMat`, `Transpose`, `Invert`, `InvertFull`, `Det`, `MultPnt`.
- Rationale: these operate on raw matrix arrays; moving to record methods requires larger structural refactor (`TMat*` as records), best done after Gate C naming review.

4. Algorithmic geometry helpers (keep standalone)
- Geom2D: `IntersectLines`, `IntersectSegm`, `PointInTrg`, `Triangulate`.
- Geom3D: `IntersectTrgLine`, `MatrixFromYawRollPitch`, `YawRollPitchFromMatrix`.
- Rationale: multi-entity algorithms not naturally owned by a single record.

5. BBox/Plane wrappers in Geom3D (compatibility layer)
- `BBoxInclude`, `BBoxIncludePnt`, `BBoxIncludeBox`, `BBoxIntersect`, `InitPlane`, `GetPlaneOffset`.
- Rationale: compatibility wrappers over record methods (`TBBox3`, `TPlane`); safe to keep deprecated until engine migration completes.

## Notes on Spatial internals
- `NormalizePlane` and `SelectPositiveVertex` are implementation-local helpers in `Apus.Spatial` (not public API).

## Proposed Gate B execution order
1. Keep compatibility wrappers in `Geom2D/Geom3D`, mark/retain as deprecated where applicable.
2. Migrate low-risk callsites in tests and new code to record methods first.
3. Defer large matrix-record refactor (`TMat*` methodization) to dedicated step after Gate C.
