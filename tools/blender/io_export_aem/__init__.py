"""Export static Apus Engine assets from Blender."""
bl_info = {
    "name": "Apus Engine Mesh (.aem)",
    "author": "Apus Software",
    "version": (0, 1, 0),
    "blender": (4, 5, 0),
    "location": "File > Export > Apus Engine Mesh (.aem)",
    "category": "Import-Export",
}

import re

import bpy
from bpy_extras.io_utils import ExportHelper

from .export_mesh import export_aem


class AEM_OT_export(bpy.types.Operator, ExportHelper):
    """Export static meshes for the experimental AEM 0.1 runtime."""

    bl_idname = "export_scene.aem"
    bl_label = "Export AEM"
    filename_ext = ".aem"

    filter_glob: bpy.props.StringProperty(default="*.aem", options={"HIDDEN"})
    use_lod_collections: bpy.props.BoolProperty(
        name="LOD Collections",
        description="Export scene-root collections named LOD0, LOD1, and so on",
        default=False,
    )
    units_per_meter: bpy.props.FloatProperty(
        name="Game Units per Metre",
        description="Convert metres to world units while keeping the Blender scene origin",
        default=1.0,
        min=0.000001,
    )
    export_colors: bpy.props.BoolProperty(
        name="Vertex Colors",
        description="Export the color attribute. Materials that use it tint by it; "
                    "otherwise it is data for custom shaders",
        default=True,
    )
    use_double_sided: bpy.props.BoolProperty(
        name="Respect Double-Sided Surfaces",
        description="Mark materials with Backface Culling off as double-sided. "
                    "Otherwise every surface is exported as single-sided",
        default=False,
    )

    def invoke(self, context, event):
        # Default to exporting colors only when a mesh that can be exported has them.
        objects = set(context.selected_objects)
        for collection in context.scene.collection.children:
            if re.fullmatch(r"LOD[0-9]+", collection.name):
                objects.update(collection.all_objects)
        self.export_colors = any(obj.type == "MESH" and len(obj.data.color_attributes) > 0 for obj in objects)
        return ExportHelper.invoke(self, context, event)

    def execute(self, context):
        try:
            warnings = export_aem(
                context, self.filepath, self.use_lod_collections, self.units_per_meter, self.export_colors,
                self.use_double_sided)
        except (ValueError, RuntimeError, OSError, OverflowError) as exc:
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}
        for warning in warnings:
            self.report({"WARNING"}, warning)
        return {"FINISHED"}


def export_menu(self, _context):
    self.layout.operator(AEM_OT_export.bl_idname, text="Apus Engine Mesh (.aem)")


def register():
    bpy.utils.register_class(AEM_OT_export)
    bpy.types.TOPBAR_MT_file_export.append(export_menu)


def unregister():
    bpy.types.TOPBAR_MT_file_export.remove(export_menu)
    bpy.utils.unregister_class(AEM_OT_export)
