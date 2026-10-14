import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler


ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "mods/wasteland_core/models/wasteland_mc_archer.b3d"
BLEND_PATH = ROOT / "mods/wasteland_core/models/wasteland_mc_archer.blend"
TEXTURE_PATH = ROOT / "mods/wasteland_core/textures/wasteland_mc_archer.png"
EXPORTER_CANDIDATES = [
    Path("/tmp/luanti_tools"),
    Path.home() / "Library/Caches/com.apple.python/tmp/luanti_tools",
]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_atlas():
    image = bpy.data.images.new("wasteland_mc_archer", width=64, height=64, alpha=True)
    pixels = [(0.0, 0.0, 0.0, 0.0)] * (64 * 64)
    colors = {
        "skin": (0.78, 0.48, 0.28, 1.0),
        "shirt": (0.23, 0.30, 0.28, 1.0),
        "pants": (0.18, 0.22, 0.24, 1.0),
        "bow": (0.42, 0.23, 0.10, 1.0),
        "string": (0.82, 0.78, 0.55, 1.0),
    }
    rects = {
        "skin": (0, 0, 15, 15),
        "shirt": (16, 0, 31, 15),
        "pants": (32, 0, 47, 15),
        "bow": (48, 0, 63, 15),
        "string": (0, 16, 15, 31),
    }
    for key, (x1, y1, x2, y2) in rects.items():
        color = colors[key]
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                pixels[y * 64 + x] = color
    flat = []
    for p in pixels:
        flat.extend(p)
    image.pixels[:] = flat
    image.filepath_raw = str(TEXTURE_PATH)
    image.file_format = "PNG"
    image.save()
    return image, rects


def uv_for_rect(rect):
    x1, y1, x2, y2 = rect
    pad = 0.5
    return [
        ((x1 + pad) / 64, (y1 + pad) / 64),
        ((x2 - pad) / 64, (y1 + pad) / 64),
        ((x2 - pad) / 64, (y2 - pad) / 64),
        ((x1 + pad) / 64, (y2 - pad) / 64),
    ]


def add_box(verts, faces, face_tags, bone_verts, name, center, size, material):
    cx, cy, cz = center
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    start = len(verts)
    box_verts = [
        (cx - sx, cy - sy, cz - sz),
        (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz),
        (cx - sx, cy + sy, cz - sz),
        (cx - sx, cy - sy, cz + sz),
        (cx + sx, cy - sy, cz + sz),
        (cx + sx, cy + sy, cz + sz),
        (cx - sx, cy + sy, cz + sz),
    ]
    verts.extend(box_verts)
    part_faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ]
    for face in part_faces:
        faces.append(tuple(start + i for i in face))
        face_tags.append(material)
    bone_verts.setdefault(name, []).extend(range(start, start + 8))


def create_mesh(rects):
    verts, faces, face_tags, bone_verts = [], [], [], {}
    add_box(verts, faces, face_tags, bone_verts, "Torso", (0, 0, 1.05), (0.55, 0.28, 0.75), "shirt")
    add_box(verts, faces, face_tags, bone_verts, "Head", (0, 0, 1.62), (0.45, 0.45, 0.45), "skin")
    add_box(verts, faces, face_tags, bone_verts, "LeftUpperArm", (-0.42, -0.05, 1.28), (0.22, 0.22, 0.48), "shirt")
    add_box(verts, faces, face_tags, bone_verts, "LeftForeArm", (-0.42, -0.45, 1.28), (0.20, 0.55, 0.20), "skin")
    add_box(verts, faces, face_tags, bone_verts, "RightUpperArm", (0.42, -0.05, 1.28), (0.22, 0.22, 0.48), "shirt")
    add_box(verts, faces, face_tags, bone_verts, "RightForeArm", (0.42, 0.28, 1.24), (0.20, 0.55, 0.20), "skin")
    add_box(verts, faces, face_tags, bone_verts, "LeftLeg", (-0.16, 0, 0.45), (0.22, 0.22, 0.85), "pants")
    add_box(verts, faces, face_tags, bone_verts, "RightLeg", (0.16, 0, 0.45), (0.22, 0.22, 0.85), "pants")
    add_box(verts, faces, face_tags, bone_verts, "Bow", (-0.56, -0.72, 1.62), (0.07, 0.08, 0.34), "bow")
    add_box(verts, faces, face_tags, bone_verts, "Bow", (-0.66, -0.72, 1.34), (0.07, 0.08, 0.34), "bow")
    add_box(verts, faces, face_tags, bone_verts, "Bow", (-0.56, -0.72, 1.06), (0.07, 0.08, 0.34), "bow")
    add_box(verts, faces, face_tags, bone_verts, "Bow", (-0.46, -0.72, 1.34), (0.035, 0.035, 1.02), "string")
    add_box(verts, faces, face_tags, bone_verts, "RightForeArm", (-0.08, -0.72, 1.34), (0.64, 0.035, 0.035), "string")

    mesh = bpy.data.meshes.new("wasteland_mc_archer_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("wasteland_mc_archer", mesh)
    bpy.context.collection.objects.link(obj)

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        uvs = uv_for_rect(rects[face_tags[poly.index]])
        for i, loop_index in enumerate(poly.loop_indices):
            uv_layer.data[loop_index].uv = uvs[i % 4]

    return obj, bone_verts


def create_armature():
    arm_data = bpy.data.armatures.new("wasteland_mc_archer_armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, head, tail, parent=None):
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = False
        return b

    bone("Root", (0, 0, 0.0), (0, 0, 0.2))
    bone("Torso", (0, 0, 0.65), (0, 0, 1.35), "Root")
    bone("Head", (0, 0, 1.38), (0, 0, 1.82), "Torso")
    bone("LeftUpperArm", (-0.32, 0, 1.35), (-0.45, -0.32, 1.30), "Torso")
    bone("LeftForeArm", (-0.45, -0.32, 1.30), (-0.52, -0.74, 1.30), "LeftUpperArm")
    bone("RightUpperArm", (0.32, 0, 1.35), (0.45, 0.20, 1.25), "Torso")
    bone("RightForeArm", (0.45, 0.20, 1.25), (0.22, -0.28, 1.28), "RightUpperArm")
    bone("LeftLeg", (-0.16, 0, 0.82), (-0.16, 0, 0.05), "Root")
    bone("RightLeg", (0.16, 0, 0.82), (0.16, 0, 0.05), "Root")
    bone("Bow", (-0.52, -0.45, 1.32), (-0.55, -0.78, 1.32), "LeftForeArm")

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind_mesh(obj, arm, bone_verts):
    for bone_name, vertices in bone_verts.items():
        group = obj.vertex_groups.new(name=bone_name)
        group.add(vertices, 1.0, "ADD")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm


def set_pose(arm, frame, pose):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bone_name, rot in pose.items():
        arm.pose.bones[bone_name].rotation_euler = Euler(tuple(math.radians(v) for v in rot), "XYZ")
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("location", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")


def create_animation(arm):
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 80
    poses = {
        1: {},
        10: {},
        11: {
            "LeftUpperArm": (-25, 0, -12),
            "LeftForeArm": (-5, 0, 0),
            "RightUpperArm": (-35, 20, 25),
            "RightForeArm": (-50, 0, 20),
            "Bow": (0, 0, -8),
        },
        20: {
            "LeftUpperArm": (-25, 0, -12),
            "LeftForeArm": (-5, 0, 0),
            "RightUpperArm": (-35, 20, 25),
            "RightForeArm": (-50, 0, 20),
            "Bow": (0, 0, -8),
        },
        21: {
            "LeftUpperArm": (-35, 0, -18),
            "LeftForeArm": (-8, 0, 0),
            "RightUpperArm": (-50, 34, 38),
            "RightForeArm": (-70, 0, 35),
            "Bow": (0, 0, -14),
        },
        30: {
            "LeftUpperArm": (-35, 0, -18),
            "LeftForeArm": (-8, 0, 0),
            "RightUpperArm": (-50, 34, 38),
            "RightForeArm": (-70, 0, 35),
            "Bow": (0, 0, -14),
        },
        31: {
            "LeftUpperArm": (-44, 0, -22),
            "LeftForeArm": (-10, 0, 0),
            "RightUpperArm": (-62, 48, 50),
            "RightForeArm": (-88, 0, 48),
            "Head": (-4, 0, -8),
            "Bow": (0, 0, -20),
        },
        40: {
            "LeftUpperArm": (-44, 0, -22),
            "LeftForeArm": (-10, 0, 0),
            "RightUpperArm": (-62, 48, 50),
            "RightForeArm": (-88, 0, 48),
            "Head": (-4, 0, -8),
            "Bow": (0, 0, -20),
        },
        41: {
            "LeftUpperArm": (-20, 0, -10),
            "RightUpperArm": (-18, 12, 15),
            "RightForeArm": (-20, 0, 12),
            "Bow": (0, 0, 5),
        },
        50: {},
        51: {
            "Torso": (0, 0, 8),
            "RightUpperArm": (-55, 28, 55),
            "RightForeArm": (-72, 0, 32),
            "LeftUpperArm": (-10, 0, -10),
        },
        60: {
            "Torso": (0, 0, 8),
            "RightUpperArm": (-55, 28, 55),
            "RightForeArm": (-72, 0, 32),
            "LeftUpperArm": (-10, 0, -10),
        },
        61: {
            "Torso": (0, 0, 14),
            "RightUpperArm": (-85, 42, 72),
            "RightForeArm": (-95, 0, 42),
            "Head": (-3, 0, 8),
            "LeftUpperArm": (-16, 0, -18),
        },
        70: {
            "Torso": (0, 0, 14),
            "RightUpperArm": (-85, 42, 72),
            "RightForeArm": (-95, 0, 42),
            "Head": (-3, 0, 8),
            "LeftUpperArm": (-16, 0, -18),
        },
        71: {
            "Torso": (0, 0, -18),
            "RightUpperArm": (-20, -10, -62),
            "RightForeArm": (-18, 0, -42),
            "Head": (-5, 0, -10),
            "LeftUpperArm": (-25, 0, -22),
        },
        80: {},
    }
    for frame, pose in poses.items():
        set_pose(arm, frame, pose)
    if arm.animation_data and arm.animation_data.action:
        for fc in arm.animation_data.action.fcurves:
            for key in fc.keyframe_points:
                key.interpolation = "BEZIER"


def export_b3d():
    exporter_parent = next((path for path in EXPORTER_CANDIDATES if (path / "io_scene_b3d").exists()), None)
    if not exporter_parent:
        raise RuntimeError("Could not find io_scene_b3d exporter.")
    sys.path.insert(0, str(exporter_parent))
    import io_scene_b3d

    if hasattr(io_scene_b3d, "register"):
        try:
            io_scene_b3d.register()
        except ValueError as exc:
            if "already registered" not in str(exc):
                raise
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.b3d(
        filepath=str(MODEL_PATH),
        use_selection=False,
        object_mesh=True,
        object_armature=True,
        export_texcoords=True,
        export_materials=True,
        export_normals=True,
    )


def main():
    clear_scene()
    image, rects = make_atlas()
    obj, bone_verts = create_mesh(rects)
    mat = bpy.data.materials.new("wasteland_mc_archer_material")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.append(mat)
    arm = create_armature()
    bind_mesh(obj, arm, bone_verts)
    create_animation(arm)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_b3d()


if __name__ == "__main__":
    main()
