"""Read Blender materials into AEM material parameters and texture hints.

The supported setup is a Principled BSDF connected to the active Material Output.
Its Base Color can be a constant, an Image Texture, a Color Attribute, or a Mix node
in Multiply mode combining two of them. Anything else exports with a warning.
"""

from dataclasses import dataclass
from math import isfinite
import os

import bpy

# Override properties: VFS paths relative to the exported AEM, by texture role.
MAP_PROPERTIES = (("color", "aem_color_map"), ("normal", "aem_normal_map"), ("opacity", "aem_opacity_map"))
RENAMED_PROPERTIES = {"aem_basecolor": "aem_color_map", "aem_normal": "aem_normal_map", "aem_opacity": "aem_opacity_map"}

ALPHA_OPAQUE = 0
ALPHA_CUTOUT = 1
ALPHA_BLEND = 2
FLAG_VERTEX_COLOR = 1
FLAG_DOUBLE_SIDED = 2

# Principled BSDF inputs outside the stock material model, with their neutral values.
UNSUPPORTED_INPUTS = (
    ("Subsurface Weight", 0.0), ("Transmission Weight", 0.0), ("Coat Weight", 0.0),
    ("Sheen Weight", 0.0), ("Anisotropic", 0.0), ("Thin Film Thickness", 0.0),
)
HANDLED_INPUTS = {
    "Base Color", "Alpha", "Metallic", "Roughness", "Specular IOR Level", "Normal",
    "Emission Color", "Emission Strength",
}


@dataclass(frozen=True)
class MaterialParams:
    base_color: tuple = (1.0, 1.0, 1.0, 1.0)
    emission_color: tuple = (0.0, 0.0, 0.0)
    emission_strength: float = 0.0
    specular: float = 0.5
    roughness: float = 0.5
    metallic: float = 0.0
    alpha_cutoff: float = 0.5
    alpha_mode: int = ALPHA_OPAQUE
    flags: int = 0


@dataclass(frozen=True)
class MaterialInfo:
    slot: str
    hints: tuple            # ((role, path), ...)
    params: MaterialParams
    color_attribute: str    # attribute tinting Base Color: "" for the mesh default, None if unused


# Blender shows a material-less object with this surface.
DEFAULT_MATERIAL = MaterialInfo("Default", (), MaterialParams(base_color=(0.8, 0.8, 0.8, 1.0)), None)


def clamp01(value):
    return min(1.0, max(0.0, float(value)))


def nonnegative(value):
    return max(0.0, float(value))


class MaterialReader:
    """Collects the parameters of one material and the warnings about it."""

    def __init__(self, material, export_dir, warn, double_sided):
        self.material = material
        self.export_dir = export_dir
        self.warn_callback = warn
        self.double_sided = double_sided  # take the double-sided hint from Backface Culling
        self.overrides = {}  # role -> path from an aem_*_map property

    def warn(self, text):
        self.warn_callback(f"{self.material.name}: {text}")

    def error(self, text):
        return ValueError(f"{self.material.name}: {text}")

    # --- node graph helpers ---

    @staticmethod
    def source(socket):
        """Return (node, output socket) linked to an input, skipping reroutes, or None."""
        while socket.is_linked:
            link = socket.links[0]
            if not link.is_valid or link.is_muted:
                return None
            node = link.from_node
            if node.type == "REROUTE":
                socket = node.inputs[0]
                continue
            return node, link.from_socket
        return None

    @staticmethod
    def input_by_id(node, identifier):
        return next(socket for socket in node.inputs if socket.identifier == identifier)

    def image_path(self, node, role):
        """Return the hint path for an image used as role. An override property wins."""
        if role in self.overrides:
            return self.overrides[role]
        image = node.image
        if image is None:
            raise self.error(f"the Image Texture for {role} has no image")
        if image.source == "TILED":
            raise self.error(f"image {image.name} uses UDIM tiles, which AEM does not support")
        if image.source != "FILE" or not image.filepath:
            raise self.error(f"image {image.name} has no file; save it or set aem_{role}_map")
        path = os.path.normpath(bpy.path.abspath(image.filepath, library=image.library))
        if image.packed_file is not None and not os.path.isfile(path):
            raise self.error(f"image {image.name} is packed; unpack it next to the AEM or set aem_{role}_map")
        try:
            relative = os.path.relpath(path, self.export_dir)
        except ValueError:
            relative = ".."
        if relative == ".." or relative.startswith(".." + os.sep) or os.path.isabs(relative):
            raise self.error(
                f"image {path} is outside the export folder {self.export_dir}; "
                f"copy it under that folder or set aem_{role}_map")
        expected = "Non-Color" if role == "normal" else "sRGB"
        actual = image.colorspace_settings.name
        if role != "opacity" and actual != expected:
            self.warn(f"image {image.name} uses color space {actual}; the engine reads {role} maps as {expected}")
        vector = self.source(node.inputs["Vector"])
        if vector is not None and not (vector[0].type == "UVMAP" and vector[0].uv_map == ""):
            self.warn(f"the {role} map uses custom texture coordinates; the engine uses the active UV map")
        return relative.replace(os.sep, "/")

    # --- inputs ---

    def color_terms(self, socket, terms):
        """Split a Base Color input into multiplied terms: constants, one image, one attribute."""
        linked = self.source(socket)
        if linked is None:
            terms["constant"] = [a * b for a, b in zip(terms["constant"], socket.default_value[:3])]
            return
        node, output = linked
        if node.type == "TEX_IMAGE" and output.name == "Color":
            if "image" in terms:
                self.warn("Base Color multiplies several images; only the first one is exported")
                return
            terms["image"] = node
        elif node.type == "VERTEX_COLOR" and output.name == "Color":
            terms["attribute"] = node.layer_name
        elif node.type == "ATTRIBUTE" and node.attribute_type == "GEOMETRY" and output.name == "Color":
            terms["attribute"] = node.attribute_name
        elif node.type in ("MIX", "MIX_RGB") and self.is_multiply(node):
            if node.type == "MIX":
                parts = self.input_by_id(node, "A_Color"), self.input_by_id(node, "B_Color")
            else:
                parts = node.inputs["Color1"], node.inputs["Color2"]
            for part in parts:
                self.color_terms(part, terms)
        else:
            self.warn(f"Base Color comes from an unsupported {node.bl_label} node; bake it into a color map")

    def is_multiply(self, node):
        if node.type == "MIX" and node.data_type != "RGBA":
            return False
        if node.blend_type != "MULTIPLY":
            return False
        factor = self.input_by_id(node, "Factor_Float") if node.type == "MIX" else node.inputs["Fac"]
        if factor.is_linked or abs(factor.default_value - 1.0) > 1e-6:
            self.warn("a Multiply node in Base Color has a factor other than 1; it exports as a full multiply")
        return True

    def value(self, bsdf, name):
        socket = bsdf.inputs[name]
        if self.source(socket) is not None:
            self.warn(f"{name} is connected to nodes; the engine uses its unconnected value {socket.default_value:g}")
        return socket.default_value

    def alpha(self, bsdf, color_image, attribute, hints):
        """Return (constant alpha, coverage varies per pixel or vertex, cutoff or None)."""
        socket = bsdf.inputs["Alpha"]
        linked = self.source(socket)
        if linked is None:
            return socket.default_value, False, None
        node, output = linked
        cutoff = None
        if node.type == "MATH" and node.operation == "GREATER_THAN":
            threshold = node.inputs[1]
            if threshold.is_linked:
                self.warn("the alpha threshold is connected to nodes; the engine uses 0.5")
            else:
                cutoff = threshold.default_value
            linked = self.source(node.inputs[0])
            if linked is None:
                above = node.inputs[0].default_value > (cutoff if cutoff is not None else 0.5)
                return 1.0 if above else 0.0, False, cutoff
            node, output = linked
        if node.type == "TEX_IMAGE":
            if node == color_image and output.name == "Alpha":
                return 1.0, True, cutoff
            hints["opacity"] = self.image_path(node, "opacity")
            self.warn("Alpha comes from a separate image; the stock shader reads alpha from the color map only")
            return 1.0, True, cutoff
        if node.type == "VERTEX_COLOR" and output.name == "Alpha":
            if attribute is None or node.layer_name != attribute:
                self.warn("Alpha uses a color attribute that does not tint Base Color; the engine ignores it")
                return 1.0, False, cutoff
            return 1.0, True, cutoff
        self.warn(f"Alpha comes from an unsupported {node.bl_label} node; the engine uses alpha 1")
        return 1.0, False, None

    def normal_map(self, bsdf, hints):
        linked = self.source(bsdf.inputs["Normal"])
        if linked is None:
            return
        node, _ = linked
        if node.type != "NORMAL_MAP" or node.space != "TANGENT":
            self.warn("Normal is connected to something other than a tangent-space Normal Map node; it is ignored")
            return
        if node.uv_map not in ("",):
            self.warn("the Normal Map node selects a UV map; the engine uses the active UV map")
        strength = node.inputs["Strength"]
        if strength.is_linked or abs(strength.default_value - 1.0) > 1e-6:
            self.warn("Normal Map strength other than 1 is not exported")
        image = self.source(node.inputs["Color"])
        if image is None or image[0].type != "TEX_IMAGE":
            self.warn("the Normal Map node has no Image Texture; it is ignored")
            return
        hints["normal"] = self.image_path(image[0], "normal")

    def emission(self, bsdf):
        color_socket = bsdf.inputs["Emission Color"]
        if self.source(color_socket) is not None:
            self.warn("Emission Color is connected to nodes; the engine uses its unconnected value")
        strength = nonnegative(self.value(bsdf, "Emission Strength"))
        color = tuple(nonnegative(c) for c in color_socket.default_value[:3])
        if strength == 0 or not any(color):
            return (0.0, 0.0, 0.0), 0.0
        return color, strength

    # --- whole material ---

    def principled(self, bsdf):
        for name, neutral in UNSUPPORTED_INPUTS:
            socket = bsdf.inputs[name]
            if socket.is_linked or abs(socket.default_value - neutral) > 1e-6:
                self.warn(f"{name} is not supported by the engine and is ignored")
        for socket in bsdf.inputs:
            if socket.name not in HANDLED_INPUTS and socket.is_linked and socket.enabled:
                self.warn(f"{socket.name} is connected to nodes, which the engine ignores")

        terms = {"constant": [1.0, 1.0, 1.0]}
        self.color_terms(bsdf.inputs["Base Color"], terms)
        hints = {}
        color_image = terms.get("image")
        if color_image is not None:
            hints["color"] = self.image_path(color_image, "color")
        attribute = terms.get("attribute")
        alpha, varying, cutoff = self.alpha(bsdf, color_image, attribute, hints)
        self.normal_map(bsdf, hints)
        emission_color, emission_strength = self.emission(bsdf)
        params = dict(
            base_color=(*(clamp01(c) for c in terms["constant"]), clamp01(alpha)),
            emission_color=emission_color,
            emission_strength=emission_strength,
            specular=nonnegative(self.value(bsdf, "Specular IOR Level")),
            roughness=clamp01(self.value(bsdf, "Roughness")),
            metallic=clamp01(self.value(bsdf, "Metallic")),
        )
        return params, hints, attribute, varying, cutoff

    def viewport_display(self):
        material = self.material
        params = dict(
            base_color=tuple(clamp01(c) for c in material.diffuse_color),
            specular=nonnegative(material.specular_intensity),
            roughness=clamp01(material.roughness),
            metallic=clamp01(material.metallic),
        )
        return params, {}, None, False, None

    def surface(self):
        material = self.material
        if not material.use_nodes or material.node_tree is None:
            return self.viewport_display()
        outputs = [node for node in material.node_tree.nodes
                   if node.type == "OUTPUT_MATERIAL" and node.is_active_output and node.target in ("ALL", "EEVEE")]
        linked = self.source(outputs[0].inputs["Surface"]) if outputs else None
        if linked is None:
            self.warn("no surface shader is connected; the Viewport Display settings are exported")
            return self.viewport_display()
        node, _ = linked
        if node.type != "BSDF_PRINCIPLED":
            self.warn(f"the surface shader is {node.bl_label}, not Principled BSDF; "
                      "the Viewport Display settings are exported")
            return self.viewport_display()
        return self.principled(node)

    def read(self):
        material = self.material
        for old, new in RENAMED_PROPERTIES.items():
            if old in material:
                raise self.error(f"property {old} was renamed to {new}")
        slot = material.get("aem_slot", material.name)
        if not isinstance(slot, str) or not slot:
            raise self.error("aem_slot must be a nonempty string")

        for role, key in MAP_PROPERTIES:
            path = material.get(key, "")
            if not isinstance(path, str):
                raise self.error(f"{key} must be a string")
            if not path:
                continue
            if "\\" in path or ":" in path or any(part in ("", ".", "..") for part in path.split("/")):
                raise self.error(f"{key} must be relative to the exported AEM and use /")
            self.overrides[role] = path
        params, hints, attribute, varying_alpha, cutoff = self.surface()
        hints.update(self.overrides)

        alpha_mode = ALPHA_OPAQUE
        constant_alpha = params["base_color"][3]
        if varying_alpha or constant_alpha < 1 or cutoff is not None:
            alpha_mode = ALPHA_BLEND if material.surface_render_method == "BLENDED" else ALPHA_CUTOUT
        if cutoff is not None and alpha_mode == ALPHA_BLEND:
            self.warn("an alpha threshold with the Blended render method exports as blending")
        if alpha_mode == ALPHA_CUTOUT and cutoff is None and 0 < constant_alpha < 1:
            self.warn(f"alpha {constant_alpha:g} with the Dithered render method looks partly transparent "
                      "in Blender; the engine cutout shows or hides each pixel completely")
        flags = FLAG_DOUBLE_SIDED if self.double_sided and not material.use_backface_culling else 0
        if attribute is not None:
            flags |= FLAG_VERTEX_COLOR
        params = MaterialParams(
            alpha_cutoff=clamp01(cutoff if cutoff is not None else 0.5),
            alpha_mode=alpha_mode, flags=flags, **params)
        for value in (*params.base_color, *params.emission_color, params.emission_strength,
                      params.specular, params.roughness, params.metallic, params.alpha_cutoff):
            if not isfinite(value):
                raise self.error("material values must be finite")
        order = {role: index for index, (role, _) in enumerate(MAP_PROPERTIES)}
        return MaterialInfo(slot, tuple(sorted(hints.items(), key=lambda item: order[item[0]])), params, attribute)


def read_material(material, export_dir, warn, double_sided=False):
    """double_sided: mark materials with Backface Culling off as double-sided."""
    if material is None:
        return DEFAULT_MATERIAL
    # Read authored settings from the datablock, including edits made after evaluation.
    return MaterialReader(material.original, export_dir, warn, double_sided).read()
