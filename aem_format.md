# Experimental static AEM v0

AEM 0.0 is the first static prototype in R-03. It gives the Blender exporter and engine loader a common wire layout for trying the workflow on the Racing grandstand. Prototype assets may need to be re-exported when the format changes.

## File envelope

All integers and IEEE 754 binary32 floats are little-endian. Layouts below are byte-packed. There is no implicit alignment or padding inside a chunk. Indices and counts are unsigned 32-bit unless marked otherwise. A `str` is a uint32 byte count followed by that many strict UTF-8 bytes, without a BOM, embedded NUL or terminator. Empty strings are allowed where specified. Offsets start at byte 0.

| Header offset | Type | Value |
| --- | --- | --- |
| 0 | byte[4] | ASCII `AEM` followed by NUL |
| 4 | uint16 | Major version, 0 |
| 6 | uint16 | Minor version, 0 |
| 8 | uint16 | Feature bits, listed below |
| 10 | uint16 | Reserved, zero |
| 12 | uint32 | Directory offset |
| 16 | uint32 | Number of directory entries |

The header is 20 bytes. Bit 3 means `LOD0` is present. Bits 0, 1 and 2 are reserved for embedded animation, skeleton and morph respectively. The static reader rejects these three and unknown feature bits. A set feature bit denotes data needed to interpret the asset. Optional auxiliary data uses a directory entry without a feature bit.

Each directory entry is 16 bytes.

| Offset in entry | Type | Value |
| --- | --- | --- |
| 0 | byte[4] | Chunk ID, uppercase ASCII letters or digits |
| 4 | uint32 | Chunk offset |
| 8 | uint32 | Chunk size in bytes |
| 12 | uint32 | Flags. Bit 0 marks a chunk required for interpretation. Other bits are reserved. |

`MESH`, `MTRL`, `NODE` and `BBOX` are required. `LOD0` is required when bit 3 is set. Each of these chunks occurs at most once and is marked required when present. An older reader can skip unknown optional chunks, including ones with unknown encoding flags, after checking their ranges. Reject unknown required chunks, unsupported major versions, unsupported flags on understood chunks, and incompatible feature combinations. The decoder accepts version 0.0 only. The prototype version must change when a wire change makes existing files incompatible.

The header, directory and chunk ranges must fit in the file and must be disjoint. The v0 writer places the directory after the header and emits chunks in the order below. Readers find them by ID and may accept other offsets. Reject duplicate IDs and zero-sized chunks. Perform range and multiplication checks in uint64 before converting to runtime signed counts, taking pointers or allocating arrays. Any count must fit the actual remaining payload and the runtime allocation limits, including expanded indices and later interleaved buffers. Consume each understood chunk exactly. Parse CPU data into a temporary asset and publish it only after validating all references and bounds.

## MESH

```text
meshCount: u32
meshes[meshCount]:
    name: str                      # may be empty, diagnostics only
    vertexCount: u32
    indexCount: u32
    partCount: u32
    attributeMask: u16             # bit 0 normal, 1 UV0, 2 UV1, 3 tangent, 4 color
    indexWidth: u8                 # 2 or 4
    reserved: u8                   # zero
    customStreamCount: u32
    positions: f32[vertexCount][3]
    normals: f32[vertexCount][3]    # if present
    uv0: f32[vertexCount][2]        # if present
    uv1: f32[vertexCount][2]        # if present
    tangents: f32[vertexCount][4]   # if present
    colors: u8[vertexCount][4]      # if present, R G B A
    indices: u16[indexCount] or u32[indexCount]
    parts[partCount]:
        firstIndex: u32
        indexCount: u32
        bindingIndex: u32
    customStreams[customStreamCount]:
        name: str
        components: u32            # 1 to 4
        values: f32[vertexCount][components]
```

The mesh, vertex, index and part counts are positive. Triangles are indexed and counterclockwise from the outward side. Indices are less than vertexCount. Parts are nonempty consecutive ranges of complete triangles, ordered by firstIndex, disjoint and covering the whole index buffer. The writer uses 16-bit indices when the largest index fits in uint16. The CPU reader expands them to `TMesh.indices`. Attribute masks contain only the bits above. Tangents require normals and UV0. Split vertices where corner UVs, normals, colors or tangent handedness differ. Map the wire color channels to the engine color value explicitly. Custom stream names are nonempty and unique within a mesh. The first exporter may emit zero custom streams. The static API has no access to custom streams, and the reader may validate and skip them until a consumer needs them.

The exporter writes finite values, nonzero unit normals, and unit tangents orthogonal to the corresponding normals. Tangent W is exactly +1 or -1. The reader rejects nonfinite data, invalid W and invalid structure. Position components, including the transformed mesh bounds, are limited to ±1e30 by the engine bounds representation. The tangent contract matches `TMesh` and the stock shader. T points along +U and B = cross(T, N) × W points along +V. UV (0,0) is top-left, with V increasing down. Apply the V conversion to Blender UVs and derive handedness for the exported UV basis. Normal hints refer to textures whose green component encodes +B in that exported basis. If an input bake encodes +Y along Blender's original increasing V, then flipping V reverses B. Re-encode its green channel when preparing the engine texture. Keep the Blender source maps intact.

## MTRL

```text
slotCount: u32
slots[slotCount]:
    name: str
bindingCount: u32
bindings[bindingCount]:
    slotIndex: u32
    hintCount: u32
    hints[hintCount]:
        role: str
        path: str
```

Slots have nonempty, unique, case-sensitive names. Each mesh part chooses a binding. The binding references one existing slot and can carry zero or more texture hints. Roles are nonempty, unique and case-sensitive within each binding. The first convention is `basecolor` (sRGB color), `normal` (linear, tangent-space +Y) and `opacity` (linear mask, sample red). Additional roles can be exposed as hints without becoming format features.

A path is a nonempty VFS path relative to the AEM file's logical directory, using / as separator. Reject empty path components, . and .. components, absolute paths, backslashes and drive/scheme colons. Resolving hints uses the logical path passed to the loader. Missing image files are handled by the game when it binds materials. The loader only reads the model. The game owns shader selection, roughness, alpha cutoff, and texture objects. It may use a separate opacity texture or pack its mask into basecolor alpha for a shader that reads the latter. The same slot can have multiple bindings, so `Seat_atlas` can use one atlas in LOD1 and a different atlas in LOD2.

## NODE

```text
nodeCount: u32
nodes[nodeCount]:
    name: str                      # may be empty, diagnostics only
    parentIndex: i32               # -1 or an earlier node
    meshIndex: i32                 # -1 for a transform-only node
    basisX, basisY, basisZ, translation: f32[3] each
```

A model needs at least one mesh node. Several nodes may reference the same mesh. With local point p, the parent-space point is translation + p.x × basisX + p.y × basisY + p.z × basisZ. In `TMat4` these vectors are rows 0 through 3, with last column (0,0,0,1). The parent precedes the child so a single forward pass composes the transforms. Reject nonfinite or singular transforms and negative determinants in the static runtime. Validate composed transforms and transformed corners before storing bounds. The exporter bakes any mirror into geometry, fixes winding and tangent handedness, and writes positive-determinant node transforms. An authored transform hierarchy can be flattened as long as its rendered placement is preserved.

Engine samples export right-handed Z-up. Exporters convert to the project's world units and keep the authored asset origin. The Racing asset uses metres, with its origin at ground level at the center of the front edge. AEM stores the resulting coordinates and the reader applies them directly. The OBJ references are Y-up and serve as source or visual reference under their own axis convention.

## BBOX

```text
assetMin, assetMax: f32[3] each
meshBounds[meshCount]:             # MESH order, no second count
    min, max: f32[3] each
```

A mesh bound encloses all its positions in mesh space. The asset bounds enclose the transformed mesh bounds of all renderable nodes in all levels, in asset space. Use the eight AABB corners per referenced node when deriving the asset bounds. Coordinates must be finite and ordered. Exporter and loader comparisons allow roundoff: the loader computes its own bounds from geometry and transforms, rejects a claimed bound that under-reports a component by more than 1e-5 × max(1, absolute coordinate, bounds extent on that axis), and uses computed bounds for rendering and culling.

## LOD0

```text
lodCount: u32
levels[lodCount]:
    minScreenHeight: f32
    nodeCount: u32
    nodeIndices: u32[nodeCount]
```

If absent, the model has one level that draws all mesh nodes in file order. If present it has at least two levels. LOD0 is finest. Each node list is nonempty and contains distinct mesh node indices in draw order. Every mesh node belongs to at least one level and common geometry can be referenced by several levels. Transform-only ancestors apply independently of level membership. Each threshold is finite and in [0,1], thresholds strictly descend, and the last threshold is zero. The first level whose threshold is at most the fraction of viewport height covered by the asset is selected. The caller computes the fraction and can set an explicit LOD. Games can use their own distance, hysteresis or visibility rules. The grandstand's thresholds will be tuned in Racing.

## Grandstand acceptance data

Both baked OBJ references use nine slot names, including `Seat_atlas`. The geometry in LOD1 has 3,638 triangles (2,560 seat-atlas triangles) and LOD2 has 1,334 (256 seat-atlas triangles). Both have the same bounds in OBJ space. Color, normal and opacity images are 1024×1024 for LOD1 and 1024×2048 for LOD2. Use the same placement for all levels, compare the seat cutout and normal relief from the driver's view, and check the volumetric seats and their shadows in LOD0.

The binary sample in `tests/fixtures/cube_static.aem` is a one-mesh cube with one material slot, one node and one implicit LOD. Exporter output goes through the same reader as the fixture. The Blender-to-game guide will use the public workflow against the delivered implementation.
