# R-07 naming/API audit

## Completed
- `TBBox3` is the primary 3D bounding box type in `Apus.Spatial`.
- `TBox3s` is kept only as compatibility alias (`deprecated 'Use TBBox3'`).
- `TVec2`/`TVec3` are primary vector types in `Geom2D/Geom3D`.
- `TPlane` now has methods-first API:
  - `TPlane.Init(const point,normal:TVector3):TPlane`
  - `TPlane.Offset(const pnt:TPoint3):double`
- Legacy wrappers `InitPlane/GetPlaneOffset` remain for compatibility and call the new methods.

## Remaining compatibility aliases (expected)
- `TPoint2s`, `TVector2s` -> `TVec2`
- `TPoint3s`, `TVector3s` -> `TVec3`
- `TBox3s` -> `TBBox3`

## Remaining standalone candidates for method migration
- `Geom2D`: free functions like `DotProduct/CrossProduct/Distance/Distance2` still coexist with `TVec2` methods.
- `Geom3D`: free functions like `DotProduct/CrossProduct/Distance/Distance2` still coexist with `TVec3` methods.
- `Geom3D`: `IntersectTrgLine` remains standalone (legacy pointer-based API).

## Suggested next migration step
1. Keep wrappers for backward compatibility.
2. Prefer method calls (`TVec2/TVec3/TPlane`) in new code and tests.
3. Mark selected standalone helpers as deprecated after callsites are moved.
