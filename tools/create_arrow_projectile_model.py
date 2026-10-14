import sys
from pathlib import Path

import bpy


ROOT = Path("/Users/caronap/Desktop/luanti_wasteland_game")
MODEL_PATH = ROOT / "mods/wasteland_core/models/wasteland_arrow_projectile.b3d"
BLEND_PATH = ROOT / "mods/wasteland_core/models/wasteland_arrow_projectile.blend"
TEXTURE_PATH = ROOT / "mods/wasteland_core/textures/wasteland_arrow_projectile.png"
EXPORTER_PARENT = Path("/tmp/luanti_tools")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def load_texture():
    image = bpy.data.images.load(str(TEXTURE_PATH))
    image.name = "wasteland_arrow_projectile"
    return image


def add_vertex(vertices, x, y, z):
    # The B3D exporter maps Blender's Y axis to the runtime Z axis.
    # Author the arrow length in the input z parameter, then store it on
    # Blender Y so Luanti sees local +Z as the arrow forward axis.
    vertices.append((x, z, y))
    return len(vertices) - 1


def create_arrow_mesh():
    vertices = []
    faces = []
    uv_faces = []

    length = 1.45
    width = 0.44

    def add_card(axis):
        if axis == "x":
            coords = [
                (0, 0, -length / 2),
                (width / 2, 0, 0),
                (0, 0, length / 2),
                (-width / 2, 0, 0),
            ]
        else:
            coords = [
                (0, 0, -length / 2),
                (0, width / 2, 0),
                (0, 0, length / 2),
                (0, -width / 2, 0),
            ]
        base = [add_vertex(vertices, *coord) for coord in coords]
        uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        faces.append(tuple(base))
        uv_faces.append(uvs)
        faces.append(tuple(reversed(base)))
        uv_faces.append(list(reversed(uvs)))

    add_card("x")
    add_card("y")

    mesh = bpy.data.meshes.new("wasteland_arrow_projectile_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, uvs in zip(mesh.polygons, uv_faces):
        for loop_index, uv in zip(polygon.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv

    obj = bpy.data.objects.new("wasteland_arrow_projectile", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj


def assign_material(obj, image):
    material = bpy.data.materials.new("wasteland_arrow_projectile_material")
    material.use_nodes = True
    material.blend_method = "BLEND"
    material.show_transparent_back = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    tex = material.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    material.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    obj.data.materials.append(material)


def export_b3d():
    sys.path.insert(0, str(EXPORTER_PARENT))
    import io_scene_b3d

    io_scene_b3d.register()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.b3d(
        filepath=str(MODEL_PATH),
        use_selection=False,
        object_mesh=True,
        object_armature=False,
        export_texcoords=True,
        export_materials=True,
        export_normals=True,
    )


def main():
    clear_scene()
    image = load_texture()
    obj = create_arrow_mesh()
    assign_material(obj, image)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_b3d()


if __name__ == "__main__":
    main()
