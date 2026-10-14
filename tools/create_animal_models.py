import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler


ROOT = Path("/Users/caronap/Desktop/luanti_wasteland_game")
MODEL_DIR = ROOT / "mods/wasteland_core/models"
TEXTURE_DIR = ROOT / "mods/wasteland_core/textures"
EXPORTER_PARENT = Path("/tmp/luanti_tools")


ANIMALS = {
    "dog": {
        "scale": 2.4,
        "colors": {
            "body": (0.46, 0.32, 0.19, 1.0),
            "belly": (0.67, 0.52, 0.36, 1.0),
            "dark": (0.20, 0.14, 0.10, 1.0),
        },
        "parts": {
            "Body": {"center": (0, 0, 0.46), "size": (0.44, 0.90, 0.36), "mat": "body"},
            "Head": {"center": (0, -0.58, 0.62), "size": (0.34, 0.32, 0.30), "mat": "body"},
            "Snout": {"center": (0, -0.78, 0.56), "size": (0.22, 0.18, 0.16), "mat": "belly"},
            "EarL": {"center": (-0.16, -0.59, 0.82), "size": (0.10, 0.08, 0.22), "mat": "dark"},
            "EarR": {"center": (0.16, -0.59, 0.82), "size": (0.10, 0.08, 0.22), "mat": "dark"},
            "LegFL": {"center": (-0.16, -0.28, 0.18), "size": (0.12, 0.12, 0.36), "mat": "dark"},
            "LegFR": {"center": (0.16, -0.28, 0.18), "size": (0.12, 0.12, 0.36), "mat": "dark"},
            "LegBL": {"center": (-0.16, 0.30, 0.18), "size": (0.12, 0.12, 0.36), "mat": "dark"},
            "LegBR": {"center": (0.16, 0.30, 0.18), "size": (0.12, 0.12, 0.36), "mat": "dark"},
            "Tail": {"center": (0, 0.58, 0.62), "size": (0.10, 0.34, 0.10), "mat": "dark"},
        },
    },
    "rabbit": {
        "scale": 2.4,
        "colors": {
            "body": (0.72, 0.66, 0.54, 1.0),
            "belly": (0.92, 0.86, 0.74, 1.0),
            "dark": (0.46, 0.41, 0.34, 1.0),
        },
        "parts": {
            "Body": {"center": (0, 0, 0.32), "size": (0.34, 0.58, 0.30), "mat": "body"},
            "Head": {"center": (0, -0.40, 0.46), "size": (0.28, 0.24, 0.24), "mat": "body"},
            "Snout": {"center": (0, -0.54, 0.42), "size": (0.16, 0.10, 0.10), "mat": "belly"},
            "EarL": {"center": (-0.09, -0.42, 0.76), "size": (0.07, 0.08, 0.46), "mat": "body"},
            "EarR": {"center": (0.09, -0.42, 0.76), "size": (0.07, 0.08, 0.46), "mat": "body"},
            "LegFL": {"center": (-0.12, -0.18, 0.12), "size": (0.08, 0.10, 0.24), "mat": "dark"},
            "LegFR": {"center": (0.12, -0.18, 0.12), "size": (0.08, 0.10, 0.24), "mat": "dark"},
            "LegBL": {"center": (-0.12, 0.22, 0.12), "size": (0.10, 0.18, 0.24), "mat": "dark"},
            "LegBR": {"center": (0.12, 0.22, 0.12), "size": (0.10, 0.18, 0.24), "mat": "dark"},
            "Tail": {"center": (0, 0.36, 0.38), "size": (0.16, 0.12, 0.16), "mat": "belly"},
        },
    },
    "bear": {
        "scale": 2.8,
        "axis_scale": (5.0, 5.0, 5.0),
        "colors": {
            "body": (0.25, 0.16, 0.10, 1.0),
            "belly": (0.39, 0.27, 0.18, 1.0),
            "dark": (0.10, 0.07, 0.05, 1.0),
        },
        "parts": {
            "Body": {"center": (0, 0, 0.52), "size": (0.64, 1.08, 0.46), "mat": "body"},
            "Head": {"center": (0, -0.72, 0.72), "size": (0.46, 0.38, 0.36), "mat": "body"},
            "Snout": {"center": (0, -0.96, 0.64), "size": (0.30, 0.22, 0.18), "mat": "belly"},
            "EarL": {"center": (-0.20, -0.76, 0.96), "size": (0.14, 0.10, 0.16), "mat": "dark"},
            "EarR": {"center": (0.20, -0.76, 0.96), "size": (0.14, 0.10, 0.16), "mat": "dark"},
            "LegFL": {"center": (-0.24, -0.32, 0.20), "size": (0.18, 0.16, 0.40), "mat": "dark"},
            "LegFR": {"center": (0.24, -0.32, 0.20), "size": (0.18, 0.16, 0.40), "mat": "dark"},
            "LegBL": {"center": (-0.24, 0.36, 0.20), "size": (0.20, 0.18, 0.40), "mat": "dark"},
            "LegBR": {"center": (0.24, 0.36, 0.20), "size": (0.20, 0.18, 0.40), "mat": "dark"},
            "Tail": {"center": (0, 0.68, 0.58), "size": (0.14, 0.12, 0.14), "mat": "dark"},
        },
    },
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_atlas(name, colors):
    image = bpy.data.images.new(f"wasteland_{name}", width=32, height=32, alpha=True)
    pixels = [(0.0, 0.0, 0.0, 0.0)] * (32 * 32)
    rects = {
        "body": (0, 0, 9, 31),
        "belly": (10, 0, 19, 31),
        "dark": (20, 0, 31, 31),
    }
    for key, (x1, y1, x2, y2) in rects.items():
        color = colors[key]
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                pixels[y * 32 + x] = color
    image.pixels[:] = [component for pixel in pixels for component in pixel]
    image.filepath_raw = str(TEXTURE_DIR / f"wasteland_{name}.png")
    image.file_format = "PNG"
    image.save()
    return image, rects


def uv_for_rect(rect):
    x1, y1, x2, y2 = rect
    pad = 0.5
    return [
        ((x1 + pad) / 32, (y1 + pad) / 32),
        ((x2 - pad) / 32, (y1 + pad) / 32),
        ((x2 - pad) / 32, (y2 - pad) / 32),
        ((x1 + pad) / 32, (y2 - pad) / 32),
    ]


def add_box(verts, faces, face_tags, bone_verts, part_name, part, scale):
    sx_scale, sy_scale, sz_scale = scale
    cx, cy, cz = (
        part["center"][0] * sx_scale,
        part["center"][1] * sy_scale,
        part["center"][2] * sz_scale,
    )
    sx, sy, sz = (
        part["size"][0] * sx_scale / 2,
        part["size"][1] * sy_scale / 2,
        part["size"][2] * sz_scale / 2,
    )
    start = len(verts)
    verts.extend([
        (cx - sx, cy - sy, cz - sz),
        (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz),
        (cx - sx, cy + sy, cz - sz),
        (cx - sx, cy - sy, cz + sz),
        (cx + sx, cy - sy, cz + sz),
        (cx + sx, cy + sy, cz + sz),
        (cx - sx, cy + sy, cz + sz),
    ])
    for face in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        faces.append(tuple(start + i for i in face))
        face_tags.append(part["mat"])
    bone_verts.setdefault(part_name, []).extend(range(start, start + 8))


def create_mesh(name, config, rects):
    verts, faces, face_tags, bone_verts = [], [], [], {}
    base_scale = config.get("scale", 1)
    axis_scale = config.get("axis_scale", (1, 1, 1))
    scale = tuple(base_scale * value for value in axis_scale)
    for part_name, part in config["parts"].items():
        add_box(verts, faces, face_tags, bone_verts, part_name, part, scale)
    mesh = bpy.data.meshes.new(f"wasteland_{name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    obj = bpy.data.objects.new(f"wasteland_{name}", mesh)
    bpy.context.collection.objects.link(obj)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        uvs = uv_for_rect(rects[face_tags[poly.index]])
        for i, loop_index in enumerate(poly.loop_indices):
            uv_layer.data[loop_index].uv = uvs[i % 4]
    return obj, bone_verts


def create_armature(name, config):
    base_scale = config.get("scale", 1)
    axis_scale = config.get("axis_scale", (1, 1, 1))
    scale = tuple(base_scale * value for value in axis_scale)
    arm_data = bpy.data.armatures.new(f"wasteland_{name}_armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(bone_name, head, tail, parent=None):
        b = arm_data.edit_bones.new(bone_name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = False

    body_center = config["parts"]["Body"]["center"]
    body_center = (body_center[0] * scale[0], body_center[1] * scale[1], body_center[2] * scale[2])
    body_height = config["parts"]["Body"]["size"][2] * scale[2]
    bone("Root", (0, 0, 0), (0, 0, 0.2))
    bone("Body", (0, 0, max(0.12, body_center[2] - body_height / 2)), (0, 0, body_center[2] + body_height / 2), "Root")
    for part_name, part in config["parts"].items():
        if part_name == "Body":
            continue
        cx, cy, cz = (part["center"][0] * scale[0], part["center"][1] * scale[1], part["center"][2] * scale[2])
        sx, sy, sz = (part["size"][0] * scale[0], part["size"][1] * scale[1], part["size"][2] * scale[2])
        parent = "Body"
        if part_name.startswith("Leg"):
            bone(part_name, (cx, cy, cz + sz / 2), (cx, cy, max(0.02, cz - sz / 2)), "Root")
        elif part_name.startswith("Ear"):
            bone(part_name, (cx, cy, cz - sz / 2), (cx, cy, cz + sz / 2), "Head")
        elif part_name == "Snout":
            bone(part_name, (cx, cy + sy / 2, cz), (cx, cy - sy / 2, cz), "Head")
        else:
            bone(part_name, (cx, cy + sy / 2, cz), (cx, cy - sy / 2, cz), parent)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind_mesh(obj, arm, bone_verts):
    for bone_name, vertices in bone_verts.items():
        group = obj.vertex_groups.new(name=bone_name)
        group.add(vertices, 1.0, "ADD")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm


def set_pose(arm, frame, rotations=None, locations=None):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    rotations = rotations or {}
    locations = locations or {}
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bone_name, rot in rotations.items():
        arm.pose.bones[bone_name].rotation_euler = Euler(tuple(math.radians(v) for v in rot), "XYZ")
    for bone_name, loc in locations.items():
        arm.pose.bones[bone_name].location = loc
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("location", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")


def create_animation(arm, scale):
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 40
    set_pose(arm, 1, {"Head": (0, 0, -5)}, {"Body": (0, 0, 0)})
    set_pose(arm, 10, {"Head": (0, 0, 5), "Tail": (0, 8, 0)}, {"Body": (0, 0, 0.025 * scale)})
    set_pose(arm, 20, {"Head": (0, 0, -5)}, {"Body": (0, 0, 0)})
    set_pose(arm, 21, {
        "LegFL": (24, 0, 0),
        "LegBR": (24, 0, 0),
        "LegFR": (-24, 0, 0),
        "LegBL": (-24, 0, 0),
        "Head": (-3, 0, 0),
        "Tail": (0, -10, 0),
    }, {"Body": (0, 0, 0.015 * scale)})
    set_pose(arm, 30, {
        "LegFL": (-24, 0, 0),
        "LegBR": (-24, 0, 0),
        "LegFR": (24, 0, 0),
        "LegBL": (24, 0, 0),
        "Head": (3, 0, 0),
        "Tail": (0, 10, 0),
    }, {"Body": (0, 0, 0.045 * scale)})
    set_pose(arm, 40, {
        "LegFL": (24, 0, 0),
        "LegBR": (24, 0, 0),
        "LegFR": (-24, 0, 0),
        "LegBL": (-24, 0, 0),
        "Head": (-3, 0, 0),
        "Tail": (0, -10, 0),
    }, {"Body": (0, 0, 0.015 * scale)})
    if arm.animation_data and arm.animation_data.action:
        for fc in arm.animation_data.action.fcurves:
            for key in fc.keyframe_points:
                key.interpolation = "BEZIER"


def assign_material(obj, image):
    material = bpy.data.materials.new(f"{obj.name}_material")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    tex = material.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.append(material)


def export_b3d(name):
    sys.path.insert(0, str(EXPORTER_PARENT))
    import io_scene_b3d

    try:
        io_scene_b3d.register()
    except ValueError as exc:
        if "already registered" not in str(exc):
            raise
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.b3d(
        filepath=str(MODEL_DIR / f"wasteland_{name}.b3d"),
        use_selection=False,
        object_mesh=True,
        object_armature=True,
        export_texcoords=True,
        export_materials=True,
        export_normals=True,
    )


def create_animal(name, config):
    clear_scene()
    image, rects = make_atlas(name, config["colors"])
    obj, bone_verts = create_mesh(name, config, rects)
    assign_material(obj, image)
    arm = create_armature(name, config)
    bind_mesh(obj, arm, bone_verts)
    create_animation(arm, config.get("scale", 1))
    bpy.ops.wm.save_as_mainfile(filepath=str(MODEL_DIR / f"wasteland_{name}.blend"))
    export_b3d(name)


def main():
    for name, config in ANIMALS.items():
        create_animal(name, config)


if __name__ == "__main__":
    main()
