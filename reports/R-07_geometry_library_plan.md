# R-07: Geometry Library Overhaul - Plan
Created: 2026-03-11
Updated: 2026-03-12

## 1. Motivation

Current state of `Apus.Geom2D` and `Apus.Geom3D`:
- Primary public names in many places are still double-oriented legacy types.
- Single-precision math is the practical default in engine runtime code.
- Spatial queries are scattered and not represented as a coherent API.

Goals:
1. Introduce a clean single-precision geometry API (`TVec2/3/4`, `TMat*`) for engine5.
2. Keep binary layout safe for runtime data paths (`TVec3` is fixed to 12 bytes).
3. Add a dedicated spatial module with practical intersection-first API for games.

## 2. Core Decisions

### 2.1 Vector and matrix types

| Type | Fields | Size | Notes |
|------|--------|------|-------|
| `TVec2` | x,y:single | 8B | 2D vector/point |
| `TVec3` | x,y,z:single | 12B | fixed decision, no padding |
| `TVec4` | x,y,z,w:single | 16B | vec4/quaternion/plane |
| `TMat2` | 2x2 single | 16B | 2D transform basis |
| `TMat3` | 3x3 single | 36B | 3D basis |
| `TMat34` | 3x4 single | 48B | affine transform |
| `TMat4` | 4x4 single | 64B | homogeneous transform |

Mandatory checks in tests:
- `SizeOf(TVec2)=8`
- `SizeOf(TVec3)=12`
- `SizeOf(TVec4)=16`
- `SizeOf(TMat4)=64`

### 2.2 Compatibility policy

- Compatibility aliases are not required.
- This is engine5 API work, so we keep new names as first-class API.
- Migration from old names is explicit where needed.

### 2.3 API style policy

- Minimum standalone global functions.
- Prefer methods on records (`TRay.IntersectsSphere`, `TSphere.IntersectsBox`, etc.).
- If shared utility is needed, use a scope record (namespace-style), for example:
  - `TSpatial = record ... class function ... static; end;`

## 3. SSE / Optimization Strategy

Initial implementation focus is correctness and API shape.

- Stage 1 and Stage 2: pure Pascal implementations.
- SSE pass is separate and profile-driven.
- `TVec3` remains 12-byte storage type; any SIMD path must handle this explicitly.

Potential SSE targets (later pass):
- `TVec4` arithmetic and dot/normalize
- `TMat4 * TVec4`
- `TMat4 * TMat4`
- Hot frustum-vs-box loops

## 4. New Module: Apus.Spatial

Rationale:
- Keep `Geom3D` from further growth.
- Put spatial primitives + intersection logic in one clear module.

### 4.1 Spatial primitives

```pascal
type
  TRay = record
    origin:TVec3;
    dir:TVec3; // expected normalized
    constructor Init(const aOrigin,aDir:TVec3);
    function IntersectsSphere(const sphere:TSphere; out t:single):boolean;
    function IntersectsBox(const box:TBBox3; out tMin,tMax:single):boolean;
    function IntersectsTriangle(const a,b,c:TVec3; out t,u,v:single):boolean;
  end;

  TSphere = record
    center:TVec3;
    radius:single;
    constructor Init(const aCenter:TVec3; aRadius:single);
    function ContainsPoint(const p:TVec3):boolean;
    function IntersectsSphere(const other:TSphere):boolean;
    function IntersectsBox(const box:TBBox3):boolean;
  end;

  TFrustum = record
    planes:array[0..5] of TVec4; // near, far, left, right, top, bottom
    planeCount:byte; // 4 for ortho/parallel culling, 6 for full frustum
    procedure InitFromMVP(const mvp:TMat4; includeNearFar:boolean=true);
    function IntersectsSphere(const sphere:TSphere):boolean;
    function IntersectsBox(const box:TBBox3):boolean;
  end;
```

### 4.2 Box policy (`TBBox3`)

- Do not introduce `TAABB` as a parallel entity.
- Extend existing `TBBox3` API with missing operations:
  - `IncludePoint`
  - `IncludeBox`
  - `Center`
  - `Extents`
  - `IsEmpty`
  - `ContainsPoint`
  - `IntersectsBox`
  - `IntersectsSphere`

### 4.3 Function organization

- Preferred: methods on `TRay`, `TSphere`, `TFrustum`, `TBBox3`.
- Shared math helpers that do not belong to a single primitive go to `TSpatial` static methods.
- Keep only truly universal math (`Dot`, `Cross`, etc.) in geometry core modules.

## 5. Frustum Semantics (Practical)

For gameplay and rendering, the primary question is:
- "intersects or not?"

Therefore:
- Public frustum API in `Apus.Spatial` is boolean intersection-oriented.
- Full classification (`inside/intersect/outside`) is optional internal helper, not required for v1 API.
- For parallel/orthographic projection, support 4-plane culling mode (`includeNearFar=false`) to reduce per-object plane tests.

## 6. Execution Plan

### Stage 1: Geometry type foundation

1. Define/normalize `TVec2/TVec3/TVec4/TMat*` API in `Geom2D/Geom3D`.
2. Ensure `TVec3` layout is exactly 12 bytes.
3. Add core operators/methods needed by spatial module.
4. Add size/layout tests.

### Stage 2: `Apus.Spatial` module

1. Create `Base/Apus.Spatial.pas`.
2. Add `TRay`, `TSphere`, `TFrustum` and extend `TBBox3` usage.
3. Implement intersection methods (ray/sphere/box/frustum focus).
4. Add `TSpatial` static helpers only where methods are not natural.

### Stage 3: Engine adoption

1. Replace local frustum math in render paths with `TFrustum.Intersects*`.
2. Use extended `TBBox3` API in model/mesh culling paths.
3. Validate on representative scenes/demos.

### Stage 4: Optimization pass (optional after profiling)

1. Profile culling/intersection hot paths.
2. Add SIMD where it gives measurable win.
3. Keep pure Pascal fallback for Delphi/FPC compatibility.

## 7. Test Plan

| Test suite | Covers | Key cases |
|------------|--------|-----------|
| TestGeom2D | `TVec2` operations and layout | arithmetic, normalize, zero vector |
| TestGeom3D | `TVec3/TVec4/TMat*` and layout | size checks, matrix/vector correctness |
| TestSpatial | intersections and degenerate inputs | hit, miss, tangent, parallel, zero-size |

Each intersection API must include:
- clear hit case
- clear miss case
- tangent/boundary case
- degenerate input case

## 8. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `TVec3` SIMD expectations vs 12B layout | treat `TVec3` as storage type; explicit load/store in optimized code |
| API sprawl via many global functions | methods-first policy + optional `TSpatial` scope record |
| Duplicate box abstractions | extend existing `TBBox3`; do not add `TAABB` |
| Premature optimization complexity | SIMD only after profiling and stable baseline |

## 9. Progress Log

### 2026-03-12 - Step 1 completed

Status:
- Added engine5 single-precision aliases:
  - `TVec2` and `TMat2` in `Apus.Geom2D`
  - `TVec3`, `TVec4`, `TMat3`, `TMat34`, `TMat4` in `Apus.Geom3D`
- Added mandatory layout checks in `Base/tests/TestMath.dpr`:
  - `SizeOf(TVec2)=8`
  - `SizeOf(TVec3)=12`
  - `SizeOf(TVec4)=16`
  - `SizeOf(TMat4)=64`

Proposed next step:
- Stage 2 / Step 1: create `Base/Apus.Spatial.pas` scaffold with `TRay`, `TSphere`, `TFrustum` declarations and baseline constructors, then compile-check.

### 2026-03-12 - Step 2 completed

Status:
- Created `Base/Apus.Spatial.pas` with initial API and implementations:
  - `TSphere` (`Init`, `ContainsPoint`, `IntersectsSphere`, `IntersectsBox`)
  - `TRay` (`Init`, `IntersectsSphere`, `IntersectsBox`, `IntersectsTriangle`)
  - `TFrustum` (`InitFromMVP`, `IntersectsSphere`, `IntersectsBox`)
  - `TSpatial.DistanceToPlane` helper
- Compile-check passed with FPC for the new unit:
  - `fpc -MDelphi -Sd -RIntel -FuBase -FuBase\extra -Fuextra -Fuextra\sdl2 -FUBase\units\spatial-check Base\Apus.Spatial.pas`

Proposed next step:
- Stage 2 / Step 2: add dedicated `Base/tests/TestSpatial.dpr` with hit/miss/tangent/degenerate cases for ray-sphere, ray-box, ray-triangle, sphere-box, frustum-sphere, and frustum-box.

### 2026-03-12 - Step 3 completed

Status:
- Added `Base/tests/TestSpatial.dpr` with 26 checks:
  - ray-sphere: hit/miss/tangent/degenerate
  - ray-box: hit/miss/inside-start
  - ray-triangle: hit/miss/degenerate triangle
  - sphere-box: hit/miss/tangent
  - frustum-sphere and frustum-box: hit/miss + 4-plane/6-plane mode checks
- Aligned formatting in edited files with tighter spacing (`:=` style).
- Test run passed for both architectures via wrapper:
  - `Base/tests/test.bat Spatial`
  - result: `TOTAL: 26 checks, FAILED: 0` on 64-bit and 32-bit.

Proposed next step:
- Stage 2 / Step 3: add `Apus.Spatial` into `Base/tests/BuildTest.dpr`/`buildtest.ps1` module lists and start extending `TBBox3s` methods (`Center`, `Extents`, `ContainsPoint`, `IntersectsBox`, `IntersectsSphere`) in `Apus.Geom3D`.

### 2026-03-12 - Step 4 completed

Status:
- Added `Apus.Spatial` to Base build validation lists:
  - `Base/tests/BuildTest.dpr`
  - `Base/tests/buildtest.ps1`
- Extended `TBBox3s` in `Apus.Geom3D` with methods:
  - `IncludePoint`, `IncludeBox`
  - `Center`, `Extents`
  - `ContainsPoint`, `IntersectsBox`, `IntersectsSphere`
- Updated `TSphere.IntersectsBox` in `Apus.Spatial` to use `TBBox3s.IntersectsSphere`, consolidating box/sphere logic in one place.
- Re-ran `Base/tests/test.bat Spatial` after changes:
  - `TOTAL: 26 checks, FAILED: 0` (64-bit and 32-bit).

Proposed next step:
- Stage 3 / Step 1: identify one concrete frustum-culling call site in engine runtime and replace local checks with `TFrustum.IntersectsSphere/IntersectsBox` behind a minimal, low-risk adapter.

### 2026-03-12 - Step 5 completed

Status:
- Switched spatial box API to a dedicated type in `Apus.Spatial`:
  - added `TBox3s` with methods `Init`, `FromBBox`, `ToBBox`, `Clear`, `IsEmpty`, `IncludePoint`, `IncludeBox`, `Center`, `Extents`, `ContainsPoint`, `IntersectsBox`, `IntersectsSphere`.
- Updated spatial primitive API to support `TBox3s` natively:
  - `TSphere.IntersectsBox`
  - `TRay.IntersectsBox`
  - `TFrustum.IntersectsBox`
- Kept compatibility overloads with old `TBBox3s` in place, routing through converters.
- `Base/tests/TestSpatial.dpr` migrated to `TBox3s`.
- Validation:
  - `Base/tests/test.bat Spatial` passes on 64-bit and 32-bit (`26 checks, 0 failed`).

Proposed next step:
- Stage 2 / Step 4: continue methods-first migration by adding vector methods to `TVec2/TVec3` and rewriting `Apus.Spatial` internals to use record methods instead of standalone `DotProduct/CrossProduct/Vector3s` where natural.

### 2026-03-12 - Step 6 completed

Status:
- Added methods-first vector API pieces:
  - `TPoint2s` (`TVec2`): `Dot`, `Cross`, `Length`, `Length2`, `Sub`
  - `TPoint3s` (`TVec3`): `Dot`, `Cross`, `Sub`, `Distance2`
- Reworked core `Apus.Spatial` internals to use these methods in critical paths (ray-sphere and ray-triangle), reducing reliance on standalone helpers.
- Normalized style in touched code to explicit `if ... then begin ... end;` form.
- Validation:
  - `Base/tests/test.bat Spatial` passes on 64-bit and 32-bit (`26 checks, 0 failed`).
- Note:
  - In-test benchmark code was removed; performance checks should be done via dedicated benchmark projects/scripts (`bench xxx`) as requested.

Proposed next step:
- Stage 2 / Step 5: create dedicated `BenchSpatial` project integrated with existing benchmark flow (`bench xxx`) to track ray/box/triangle/frustum throughput and provide baseline numbers for future optimization.

## 10. Implementation Gates (added 2026-03-12)

These gates are mandatory before migration to engine modules.

### Gate A: Type naming consistency

- Enforce rule for all public signatures:
  - single-precision type name: no suffix (`TVec3`)
  - double-precision type name: `d` suffix (`TVec3d`)
- Remove old non-conforming names from signatures.
- Legacy aliases are allowed only as compatibility layer and should be deprecated.

### Gate B: Standalone vs record scope audit

- Verify which standalone functions are still present in `Geom2D/Geom3D/Spatial`.
- Move functions into record scope where natural (`TVec*`, `TPlane`, `TRay`, `TSphere`, `TFrustum`, `TBBox3`).
- Produce a complete list of remaining standalone functions with rationale for each:
  - kept for backward compatibility
  - low-level utility not tied to a single record
  - performance/ABI constraints

### Gate C: Full naming review

- Review names of all public functions for ambiguity/redundancy.
- Unify names where overlapping semantics exist (for example method-vs-free-function duplicates).
- Keep wrappers for compatibility where rename is breaking.

### Gate D: Test coverage completion

- Confirm every public function has tests, including edge/degenerate cases.
- Maintain separate suites (`TestGeom2D`, `TestGeom3D`, `TestSpatial`) and keep all green on 32/64-bit.

### Gate E: Benchmark pass

- If all tests are green, run benchmarks for all covered function groups.
- Use dedicated benchmark projects/scripts (`bench xxx`), not test projects.
- Analyze results and flag suspiciously slow functions.

### Gate F: x64 SSE optimization pass

- Optimize most critical hot paths with SSE on x64 only.
- Do not optimize x86 paths in this stage.
- Carefully account for platform/compiler nuances:
  - Win/Linux calling conventions
  - FPC/Delphi stack alignment differences
- Use existing ASM examples in codebase as reference patterns.

### Gate G: Engine migration and compile validation

- Mandatory pause before migration:
  - when library work is complete, stop for dedicated code review before any engine integration/migration.
- After gates A-F are done and stable, start migration of engine modules to new API.
- Replace old types/functions in module callsites.
- Run compile validation on a representative target (preferred: `SimpleDemo`).

### 2026-03-12 - Gate A / Step 1 completed

Status:
- Completed Gate A inventory of public type names in:
  - `Base/Apus.Geom2D.pas`
  - `Base/Apus.Geom3D.pas`
  - `Base/Apus.Spatial.pas`
- Added detailed report:
  - `reports/R-07_gateA_type_naming_inventory.md`
- Identified non-conforming public double-precision names remaining in signatures:
  - `TPoint2/TVector2`, `TMatrix2/TMatrix32`
  - `TPoint3/TVector3`, `TMatrix3/TMatrix4/TMatrix43`, `TQuaternion`
- Prepared target rename map to `*d` convention and staged migration order.

Proposed next step:
- Gate A / Step 2: introduce canonical `*d` type names (`TVec2d/TVec3d`, `TMat*d`, `TQuatd`) and switch public signatures to them, keeping old names as deprecated compatibility aliases.

### 2026-03-12 - Gate A / Step 2 completed

Status:
- Switched public Geom signatures to canonical `*d` names:
  - `TVec2d` in `Apus.Geom2D`
  - `TVec3d` in `Apus.Geom3D`
  - `TMat3d/TMat34d/TMat4d` and `TQuatd` in `Apus.Geom3D`
- Kept old names only as deprecated compatibility aliases.
- Removed `TBBox3s` from `Geom3D` and `Spatial` public API in favor of `TBBox3`.
- Validation:
  - `Base/tests/test.bat Geom2D` passed (32/64)
  - `Base/tests/test.bat Geom3D` passed (32/64)
  - `Base/tests/test.bat Spatial` passed (32/64)

Proposed next step:
- Gate A / Step 3: migrate tests and remaining internal helper aliases to canonical names to eliminate deprecated-type usage in active code paths.

### 2026-03-12 - Gate A / Step 3 completed

Status:
- Migrated tests to canonical names:
  - `TestGeom2D`: `TPoint2/TMatrix2/TMatrix32` -> `TVec2d/TMat2d/TMat32d`
  - `TestGeom3D`: `TMatrix43/TMatrix4` -> `TMat34d/TMat4d`
- Updated internal helper aliases/constants in geometry units to canonical types:
  - `TVec2` instead of `TPoint2s/TVector2s` in active helper declarations
  - `TVec3` instead of `TPoint3s/TVector3s` in active helper declarations
  - `sizeof(TVec3)` in place of `sizeof(TPoint3s)` for point-array stride fallback
- Validation:
  - `Base/tests/test.bat Geom2D` passed (32/64)
  - `Base/tests/test.bat Geom3D` passed (32/64)
  - `Base/tests/test.bat Spatial` passed (32/64)

Proposed next step:
- Gate B / Step 1: produce full standalone-function inventory for `Geom2D/Geom3D/Spatial`, classify each function (move-to-record / keep-standalone with rationale), then execute the first safe migration batch.

### 2026-03-12 - Gate B / Step 1 completed

Status:
- Produced standalone-function inventory and classification report:
  - `reports/R-07_gateB_standalone_inventory.md`
- Confirmed `Apus.Spatial` public API is records-first; helper routines there are implementation-local.
- Grouped remaining standalone functions in `Geom2D/Geom3D` by rationale:
  - compatibility wrappers
  - factory/conversion helpers
  - matrix algebra procedures (deferred refactor)
  - multi-entity algorithmic helpers

Proposed next step:
- Gate B / Step 2: perform first safe migration batch by replacing compatibility-wrapper usage in tests/new code with record methods wherever equivalent behavior exists, keeping wrappers for backward compatibility.

### 2026-03-12 - Gate B / Step 2 completed

Status:
- Migrated `Base/tests/TestGeom3D.dpr` utility checks to methods-first flow:
  - `TPlane.Init` + `TPlane.Offset` as primary assertions
  - `TBBox3.IncludePoint/IncludeBox/ContainsPoint/IntersectsBox` as primary assertions
- Kept legacy wrappers (`GetPlaneOffset`, `InitPlane`, `BBoxInclude*`, `BBoxIntersect`) as explicit compatibility checks.
- Validation:
  - `Base/tests/test.bat Geom3D` passed (32/64, `TOTAL: 49 checks, FAILED: 0`)

Proposed next step:
- Gate C / Step 1: start full public function naming review and create a concrete rename list for ambiguous/redundant API names (with backward-compatibility mapping).

### 2026-03-12 - Gate C / Step 1 completed

Status:
- Completed public naming review for `Geom2D/Geom3D/Spatial`.
- Added report with rename/deprecation map:
  - `reports/R-07_gateC_naming_review.md`
- Identified high-value canonical rename candidates (typo/abbreviation cleanup), while keeping compatibility wrappers for migration.

Proposed next step:
- Gate C / Step 2: implement first low-risk canonical alias batch (starting with `DecomposeMatrix` alias for `DecomposeMartix`), migrate tests/new code to canonical names, and mark old names deprecated.

### 2026-03-12 - Gate C / Step 2 completed

Status:
- Implemented canonical typo fix in `Apus.Geom3D`:
  - added `DecomposeMatrix` (single/double overloads) as canonical API
  - kept `DecomposeMartix` as deprecated compatibility wrapper (`Use DecomposeMatrix`)
- Migrated tests to canonical call:
  - `Base/tests/TestGeom3D.dpr` now validates `DecomposeMatrix` translation/scale extraction.
- Validation:
  - `Base/tests/test.bat Geom3D` passed (32/64, `TOTAL: 51 checks, FAILED: 0`)

Proposed next step:
- Gate D / Step 1: create function-to-test coverage matrix for `Geom2D/Geom3D/Spatial` and identify exact uncovered functions/edge-cases before adding the missing tests.

### 2026-03-12 - Gate D / Step 1 completed

Status:
- Added coverage matrix with explicit covered/missing areas:
  - `reports/R-07_gateD_coverage_matrix.md`
- Confirmed:
  - `Spatial` is near-complete for current public API.
  - `Geom2D/Geom3D` still have uncovered legacy/edge paths.
- Declared that 100% function+edge coverage is not reached yet and listed concrete gaps.

Proposed next step:
- Gate D / Step 2: implement targeted missing tests, starting with Geom2D (`Triangulate`, `TMat32d` transform chain, `TransformRect`/`RoundRect` edge cases).

### 2026-03-12 - Gate D / Step 2 completed

Status:
- Extended `Base/tests/TestGeom2D.dpr` with targeted coverage additions:
  - `Triangulate`:
    - explicit triangle output length check (`=3`)
    - quad triangulation check (`=6`) with index-range validation
  - `TMat32d` transform chain:
    - `TranslationMat` + `ScaleMat` + `MultMat` + `Invert` + `ToSingle32` + `MultPnts`
    - roundtrip point transform validation through matrix and inverse
  - `TransformRect`/`RoundRect` edge case:
    - negative-scale transform path with orientation flip assertion
- Validation:
  - `Base/tests/test.bat Geom2D` passed (32/64, `TOTAL: 50 checks, FAILED: 0`)

Proposed next step:
- Gate D / Step 3: add targeted Geom3D missing tests (`RotationX/Y/Z*`, `MatrixFromYawRollPitch` + `YawRollPitchFromMatrix` roundtrip, and direct `IntersectTrgLine` edge cases).

### 2026-03-12 - Gate D / Step 3 completed

Status:
- Extended `Base/tests/TestGeom3D.dpr` with targeted edge coverage:
  - `MatrixFromYawRollPitch` + `YawRollPitchFromMatrix` roundtrip validated via matrix reconstruction.
  - `RotationXMat3s/RotationYMat3s/RotationZMat3s` consistency checks against double-precision rotation builders.
  - direct `IntersectTrgLine` cases: hit, miss, and parallel line.
- Validation:
  - `Base/tests/test.bat Geom3D` passed (32/64, `TOTAL: 58 checks, FAILED: 0`)

Proposed next step:
- Gate D / Step 4: add Spatial numeric stress/epsilon tests (near-parallel rays, barycentric edge hits, and frustum tolerance edge cases) to close remaining coverage gaps.

### 2026-03-12 - Gate D / Step 4 completed

Status:
- Extended `Base/tests/TestSpatial.dpr` with numeric stress/epsilon coverage:
  - ray-box near-parallel slab behavior (`SpatialEpsilon` boundary cases)
  - ray-triangle vertex hit and near-edge outside case
  - ray-plane near-parallel miss case
  - frustum tangent vs beyond-tangent checks for sphere and box
- Validation:
  - `Base/tests/test.bat Spatial` passed (32/64, `TOTAL: 43 checks, FAILED: 0`)

Proposed next step:
- Gate D / Step 5: refresh coverage matrix and close remaining Geom2D/Geom3D long-tail gaps (if any), then explicitly declare Gate D complete.

### 2026-03-12 - Gate D / Step 5 completed

Status:
- Added additional long-tail tests:
  - `TestGeom2D`: `AboutEqual`, `LexCompare`, `TVec2/TVec2d.Wrap`
  - `TestGeom3D`: negative cases for `CompareSingle`/`CompareDouble`
- Refreshed Gate D matrix:
  - `reports/R-07_gateD_coverage_matrix.md`
- Validation:
  - `Base/tests/test.bat Geom2D` passed (32/64, `TOTAL: 55 checks, FAILED: 0`)
  - `Base/tests/test.bat Geom3D` passed (32/64, `TOTAL: 60 checks, FAILED: 0`)
  - `Base/tests/test.bat Spatial` previously green after Step 4 (`TOTAL: 43 checks, FAILED: 0`)

Proposed next step:
- Gate D / Step 6: add one focused degenerate-frustum matrix test block in `TestSpatial`, then re-run all three suites and decide Gate D completion status.

### 2026-03-12 - Gate D / Step 6 completed

Status:
- Added degenerate-MVP robustness checks in `Base/tests/TestSpatial.dpr`:
  - zero-matrix frustum init path
  - fallback intersection behavior for sphere/box under degenerate planes
- Validation (sequential, no shared-log contention):
  - `Base/tests/test.bat Geom2D` passed (32/64, `TOTAL: 55 checks, FAILED: 0`)
  - `Base/tests/test.bat Geom3D` passed (32/64, `TOTAL: 60 checks, FAILED: 0`)
  - `Base/tests/test.bat Spatial` passed (32/64, `TOTAL: 45 checks, FAILED: 0`)

Gate D status:
- Major public API and requested edge-cases are now covered by dedicated tests.
- For strict "every legacy compatibility wrapper path" 100% claim, a final symbol-by-symbol trace matrix is still needed.

Proposed next step:
- Gate D / Step 7: produce strict per-symbol coverage checklist from unit interfaces and close any remaining untested compatibility wrappers; then formally mark Gate D complete.
