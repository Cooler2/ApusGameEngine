# R-07 Gate A: Type Naming Inventory
Created: 2026-03-12

## Rule to enforce
- single-precision: no suffix (`TVec3`, `TMat4`, ...)
- double-precision: `d` suffix (`TVec3d`, `TMat4d`, ...)
- old non-conforming types must not remain in public signatures

## Current state summary (public signatures)

### Already aligned
- `TVec2`, `TVec3`, `TVec4`
- `TMat2`, `TMat3`, `TMat34`, `TMat4`
- `TBBox3`, `TRay`, `TSphere`, `TFrustum`, `TSpatial`

### Legacy aliases kept for compatibility (deprecated)

Geom2D:
- `TPoint2`, `TVector2`
- `TMatrix2`, `TMatrix32`

Geom3D:
- `TPoint3`, `TVector3`
- `TMatrix3`, `TMatrix4`, `TMatrix43`
- `TQuaternion` (double quaternion record)

## Target rename map for Gate A

- `TPoint2`/`TVector2` -> `TVec2d`
- `TMatrix2` -> `TMat2d`
- `TMatrix32` -> `TMat32d`

- `TPoint3`/`TVector3` -> `TVec3d`
- `TMatrix3` -> `TMat3d`
- `TMatrix4` -> `TMat4d`
- `TMatrix43` -> `TMat34d`
- `TQuaternion` -> `TQuatd` (or `TVec4d`; choose one canonical public name)

## Notes
- `Apus.Spatial` is already mostly clean in type naming and uses single-precision API.
- Main Gate A work in signatures is completed in `Apus.Geom2D.pas` and `Apus.Geom3D.pas`.
- Compatibility aliases are still present but marked deprecated.
- `TBBox3s` is removed from `Geom3D`/`Spatial` public signatures; canonical type is `TBBox3`.

## Status (2026-03-12)
1. Introduced canonical `*d` type names in `Geom2D/Geom3D` with compatibility aliases from old names.
2. Updated public function signatures to canonical names (`TVec*d`, `TMat*d`, `TQuatd`).
3. Kept old names only as deprecated aliases (not primary signature names).
4. Updated tests to use canonical names (`TestGeom2D`, `TestGeom3D`).
