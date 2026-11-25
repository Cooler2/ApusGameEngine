"""Extract evaluated static geometry in right-handed Z-up game coordinates."""

from collections import defaultdict
from math import isfinite
from struct import pack, unpack
import os
import re

from .materials import read_material
from .writer import MAX_POSITION, Mesh, write_aem


def selected_levels(context, use_lod_collections):
    if not use_lod_collections:
        return [(0.0, mesh_objects(context.selected_objects))]

    numbered = {}
    for collection in context.scene.collection.children:
        match = re.fullmatch(r"LOD(0|[1-9][0-9]*)", collection.name)
        if match:
            numbered[int(match[1])] = collection
    if not numbered or sorted(numbered) != list(range(len(numbered))):
        raise ValueError("Create contiguous scene-root collections named LOD0, LOD1, and so on")
    levels = []
    previous = 2.0
    for index in range(len(numbered)):
        collection = numbered[index]
        default = 0.0 if index == len(numbered) - 1 else 0.5 ** (index + 1)
        threshold = collection.get("aem_min_screen_height", default)
        if not isinstance(threshold, (float, int)) or not 0 <= threshold <= 1:
            raise ValueError(f"{collection.name}: aem_min_screen_height must be a number in [0, 1]")
        threshold = unpack("<f", pack("<f", threshold))[0]
        if threshold >= previous or (index == len(numbered) - 1 and threshold != 0):
            raise ValueError("LOD thresholds must strictly descend to zero")
        objects = mesh_objects(collection.all_objects)
        if not objects:
            raise ValueError(f"{collection.name}: no mesh objects")
        levels.append((threshold, objects))
        previous = threshold
    return levels


def mesh_objects(objects):
    return sorted({obj for obj in objects if obj.type == "MESH"}, key=lambda obj: obj.name_full)


def finite(values, label):
    if not all(isfinite(value) for value in values):
        raise ValueError(f"Non-finite {label}")
    return tuple(values)


def unit_normal(value, label):
    normalized = value.normalized()
    if not isfinite(normalized.length_squared) or normalized.length_squared == 0:
        raise ValueError(f"Invalid {label}")
    return normalized


def quantize_rgba(value):
    return tuple(round(255 * min(1.0, max(0.0, component))) for component in finite(value, "color"))


def color_attribute(mesh, materials, export_colors, warn):
    """Choose the color attribute exported as vertex colors, or None."""
    used = {info.color_attribute for info in materials if info.color_attribute is not None}
    if not export_colors:
        if used:
            warn("a material uses vertex colors, but Vertex Colors is off in the export settings")
        return None
    attributes = mesh.color_attributes
    names = {name or attributes.default_color_name or attributes.active_color_name for name in used}
    if len(names) > 1:
        raise ValueError(f"materials use different color attributes {sorted(names)}; AEM stores one per mesh")
    name = names.pop() if names else attributes.default_color_name or attributes.active_color_name
    if not name:
        return None
    attribute = attributes.get(name)
    if attribute is None:
        if used:
            raise ValueError(f"a material uses missing color attribute {name}")
        return None
    return attribute


def mesh_attributes(mesh, material_by_face):
    active_uv = mesh.uv_layers.active
    uv0_name = active_uv.name if active_uv is not None else ""
    uv1_name = next((layer.name for layer in mesh.uv_layers if layer.name != uv0_name), "")
    needs_tangents = any(
        role == "normal" for info in material_by_face.values() for role, _ in info.hints
    )
    if needs_tangents and not uv0_name:
        raise ValueError("A normal map requires an active UV layer")
    has_ngons = any(len(polygon.vertices) > 4 for polygon in mesh.polygons)
    if needs_tangents and has_ngons:
        raise ValueError("Add a Triangulate modifier before exporting a normal-mapped mesh with n-gons")
    has_tangents = bool(uv0_name) and not has_ngons
    if has_tangents:
        mesh.calc_tangents(uvmap=uv0_name)
    # calc_tangents can reallocate the corner attributes, invalidating previous layer handles.
    return mesh.uv_layers.get(uv0_name), mesh.uv_layers.get(uv1_name), has_tangents


def export_geometry(obj, depsgraph, scale, add_binding, options):
    if depsgraph.objects.get(obj.name) is None:
        raise ValueError(f"{obj.name}: include the object in the active View Layer before exporting")
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
    try:
        return gather_geometry(evaluated, mesh, scale, add_binding, options)
    except (ValueError, RuntimeError, OverflowError) as exc:
        raise ValueError(f"{obj.name}: {exc}") from exc
    finally:
        evaluated.to_mesh_clear()


def gather_geometry(obj, mesh, scale, add_binding, options):
    matrix = obj.matrix_world
    linear = matrix.to_3x3()
    determinant = linear.determinant()
    if not isfinite(determinant) or determinant == 0:
        raise ValueError("Cannot export a non-finite or singular transform")
    mirrored = determinant < 0
    normal_matrix = linear.inverted().transposed()
    mesh.calc_loop_triangles()
    if not mesh.loop_triangles:
        raise ValueError("No triangles after evaluating modifiers")

    material_by_face = {}
    for mat_index in sorted({triangle.material_index for triangle in mesh.loop_triangles}):
        if mat_index < len(obj.material_slots):
            material = obj.material_slots[mat_index].material
        else:
            material = mesh.materials[mat_index] if mat_index < len(mesh.materials) else None
        material_by_face[mat_index] = read_material(
            material, options.export_dir, options.warn, options.double_sided)
    uv0, uv1, has_tangents = mesh_attributes(mesh, material_by_face)
    # Chosen after calc_tangents, which can reallocate the attribute handles.
    color = color_attribute(mesh, material_by_face.values(), options.export_colors,
                            lambda text: options.warn(f"{obj.name}: {text}"))
    binding_indices = {index: add_binding(info) for index, info in material_by_face.items()}

    result = Mesh(obj.name_full)
    pooled = {}
    groups = defaultdict(list)
    for triangle in mesh.loop_triangles:
        binding = binding_indices[triangle.material_index]
        loops = triangle.loops
        if mirrored:
            loops = (loops[0], loops[2], loops[1])
        for loop_index in loops:
            loop = mesh.loops[loop_index]
            position = finite((matrix @ mesh.vertices[loop.vertex_index].co) * scale, "position")
            if any(abs(component) > MAX_POSITION for component in position):
                raise ValueError("Position exceeds the AEM bounds limit")
            normal = unit_normal(normal_matrix @ mesh.corner_normals[loop_index].vector, "corner normal")
            uvs = []
            for layer in (uv0, uv1):
                if layer is not None:
                    u, v = layer.uv[loop_index].vector
                    uvs.append(finite((u, 1 - v), "UV"))
            tangent = ()
            if has_tangents:
                direction = linear @ loop.tangent
                direction -= normal * direction.dot(normal)
                if direction.length_squared == 0:
                    direction = normal.orthogonal()
                direction = unit_normal(direction, "corner tangent")
                # Blender uses cross(N,T). The engine uses cross(T,N)
                # with reversed V, so only a spatial mirror changes the sign.
                sign = -1 if loop.bitangent_sign < 0 else 1
                tangent = (*direction, -sign if mirrored else sign)
            rgba = ()
            if color is not None:
                index = loop.vertex_index if color.domain == "POINT" else loop_index
                # sRGB-encoded RGB with linear alpha, as Blender displays the attribute.
                rgba = quantize_rgba(color.data[index].color_srgb)
            key = (position, tuple(normal), tuple(uvs), tangent, rgba)
            index = pooled.get(key)
            if index is None:
                index = len(result.positions)
                pooled[key] = index
                result.positions.append(position)
                result.normals.append(tuple(normal))
                if uv0 is not None:
                    result.uv0.append(uvs[0])
                if uv1 is not None:
                    result.uv1.append(uvs[1])
                if has_tangents:
                    result.tangents.append(tangent)
                if color is not None:
                    result.colors.append(rgba)
            groups[binding].append(index)
    for binding, indices in sorted(groups.items()):
        result.parts.append((len(result.indices), len(indices), binding))
        result.indices.extend(indices)
    return result


class ExportOptions:
    def __init__(self, filepath, export_colors, double_sided):
        self.export_dir = os.path.dirname(os.path.abspath(filepath))
        self.export_colors = export_colors
        self.double_sided = double_sided
        self.warnings = []

    def warn(self, text):
        if text not in self.warnings:
            self.warnings.append(text)


def export_aem(context, filepath, use_lod_collections=False, units_per_meter=1.0, export_colors=True,
               double_sided=False):
    """Write the selected objects or LOD collections. Returns the list of warnings."""
    if context.mode != "OBJECT":
        raise ValueError("Switch to Object Mode before exporting")
    levels = selected_levels(context, use_lod_collections)
    if not levels[0][1]:
        raise ValueError("Select at least one mesh object")
    scale = units_per_meter * context.scene.unit_settings.scale_length
    if not isfinite(scale) or scale <= 0:
        raise ValueError("Game units per metre must be finite and positive")
    depsgraph = context.evaluated_depsgraph_get()
    options = ExportOptions(filepath, export_colors, double_sided)
    slots = {}
    bindings = {}

    def add_binding(info):
        slot_index = slots.setdefault(info.slot, len(slots))
        key = (slot_index, info.hints, info.params)
        return bindings.setdefault(key, len(bindings))

    meshes = []
    object_nodes = {}
    lods = []
    for threshold, objects in levels:
        nodes = []
        for obj in objects:
            index = object_nodes.get(obj)
            if index is None:
                index = len(meshes)
                meshes.append(export_geometry(obj, depsgraph, scale, add_binding, options))
                object_nodes[obj] = index
            nodes.append(index)
        lods.append((threshold, nodes))
    write_aem(filepath, meshes, slots, bindings, lods)
    return options.warnings
