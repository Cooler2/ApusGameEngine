"""Write the experimental static AEM 0.0 layout in aem_format.md."""

from dataclasses import dataclass, field
from pathlib import Path
from struct import Struct, pack
from tempfile import NamedTemporaryFile
import os

HEADER = Struct("<4sHHHHII")
DIRECTORY_ENTRY = Struct("<4sIII")
# AEM 0.0 limits and flags in aem_format.md and Apus.Engine.AEMLoader.
HAS_LOD = 0x0008
REQUIRED_CHUNK = 0x00000001
MAX_POSITION = 1e30
IDENTITY_AFFINE = (1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)


@dataclass
class Mesh:
    name: str
    positions: list = field(default_factory=list)
    normals: list = field(default_factory=list)
    uv0: list = field(default_factory=list)
    uv1: list = field(default_factory=list)
    tangents: list = field(default_factory=list)
    colors: list = field(default_factory=list)
    indices: list = field(default_factory=list)
    parts: list = field(default_factory=list)


def text(value):
    if value.startswith("\ufeff") or "\0" in value:
        raise ValueError("AEM names and paths cannot contain a leading BOM or a NUL")
    encoded = value.encode("utf-8")
    return pack("<I", len(encoded)) + encoded


def bounds(positions):
    return tuple(min(p[axis] for p in positions) for axis in range(3)) + tuple(
        max(p[axis] for p in positions) for axis in range(3)
    )


def mesh_chunk(meshes):
    data = bytearray(pack("<I", len(meshes)))
    for mesh in meshes:
        mask = 0
        for bit, stream in enumerate((mesh.normals, mesh.uv0, mesh.uv1, mesh.tangents, mesh.colors)):
            if stream:
                mask |= 1 << bit
        width = 2 if max(mesh.indices) <= 65535 else 4
        data += text(mesh.name)
        data += pack("<IIIHBBI", len(mesh.positions), len(mesh.indices), len(mesh.parts), mask, width, 0, 0)
        for elements, fmt in (
            (mesh.positions, "<3f"), (mesh.normals, "<3f"), (mesh.uv0, "<2f"), (mesh.uv1, "<2f"),
            (mesh.tangents, "<4f"), (mesh.colors, "<4B"),
        ):
            encode = Struct(fmt).pack
            for element in elements:
                data += encode(*element)
        index_type = "H" if width == 2 else "I"
        data += pack(f"<{len(mesh.indices)}{index_type}", *mesh.indices)
        for part in mesh.parts:
            data += pack("<III", *part)
    return data


def material_chunk(slots, bindings):
    data = bytearray(pack("<I", len(slots)))
    for slot in slots:
        data += text(slot)
    data += pack("<I", len(bindings))
    for slot_index, hints in bindings:
        data += pack("<II", slot_index, len(hints))
        for role, path in hints:
            data += text(role) + text(path)
    return data


def node_chunk(meshes):
    data = bytearray(pack("<I", len(meshes)))
    for mesh_index, mesh in enumerate(meshes):
        data += text(mesh.name) + pack("<ii12f", -1, mesh_index, *IDENTITY_AFFINE)
    return data


def lod_chunk(levels):
    data = bytearray(pack("<I", len(levels)))
    for threshold, nodes in levels:
        data += pack("<fI", threshold, len(nodes))
        data += pack(f"<{len(nodes)}I", *nodes)
    return data


def write_aem(path, meshes, slots, bindings, levels):
    boxes = [bounds(mesh.positions) for mesh in meshes]
    asset_bounds = tuple(min(box[i] for box in boxes) for i in range(3)) + tuple(
        max(box[i] for box in boxes) for i in range(3, 6)
    )
    chunks = [
        (b"MESH", mesh_chunk(meshes)),
        (b"MTRL", material_chunk(slots, bindings)),
        (b"NODE", node_chunk(meshes)),
        (b"BBOX", b"".join(pack("<6f", *box) for box in (asset_bounds, *boxes))),
    ]
    has_lods = len(levels) > 1
    if has_lods:
        chunks.append((b"LOD0", lod_chunk(levels)))

    offset = HEADER.size + len(chunks) * DIRECTORY_ENTRY.size
    if offset + sum(len(data) for _, data in chunks) > 0x7fffffff:
        raise ValueError("AEM file exceeds the engine's signed file size limit")

    path = Path(path)
    temp_path = None
    try:
        with NamedTemporaryFile(dir=path.parent, prefix=path.name + ".", suffix=".tmp", delete=False) as stream:
            temp_path = Path(stream.name)
            stream.write(HEADER.pack(b"AEM\0", 0, 0, HAS_LOD if has_lods else 0, 0, HEADER.size, len(chunks)))
            for kind, data in chunks:
                stream.write(DIRECTORY_ENTRY.pack(kind, offset, len(data), REQUIRED_CHUNK))
                offset += len(data)
            for _, data in chunks:
                stream.write(data)
        os.replace(temp_path, path)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
