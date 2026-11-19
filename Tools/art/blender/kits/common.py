"""Scene, camera, light, material and mesh helpers shared by all render kits."""

from __future__ import annotations

import math
from contextlib import suppress

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

TILE = 2.0
HALF = TILE / 2
# Warm afternoon sun from the viewer's upper left, as in the original FreeCol sprites.
SUN_FROM = Vector((-0.45, -1.0, 1.35))


def lin(color) -> tuple[float, float, float]:
    """Palette colours are written as sRGB; Blender colour sockets expect scene-linear values."""
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color[:3])


def reset() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for blocks in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.lights,
        bpy.data.cameras,
        bpy.data.curves,
        bpy.data.node_groups,
        bpy.data.images,
    ):
        for block in list(blocks):
            blocks.remove(block)


def configure(samples: int) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    preferences = bpy.context.preferences.addons["cycles"].preferences
    try:
        preferences.compute_device_type = "METAL"
        preferences.get_devices()
        for device in preferences.devices:
            device.use = device.type == "METAL"
        scene.cycles.device = "GPU"
    except (TypeError, AttributeError):
        scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 12
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    settings = scene.render.image_settings
    settings.file_format = "PNG"
    settings.color_mode = "RGBA"
    settings.color_depth = "8"
    view = scene.view_settings
    for transform in ("AgX", "Filmic", "Standard"):
        try:
            view.view_transform = transform
            break
        except TypeError:
            continue
    for look in ("AgX - Punchy", "Punchy", "AgX - Medium High Contrast", "Medium High Contrast"):
        try:
            view.look = look
            break
        except TypeError:
            continue
    view.exposure = 0.1


def world(color=(0.56, 0.66, 0.82), strength: float = 0.9) -> None:
    scene = bpy.context.scene
    sky = scene.world or bpy.data.worlds.new("World")
    scene.world = sky
    with suppress(AttributeError):
        sky.use_nodes = True
    nodes = sky.node_tree.nodes
    background = next((node for node in nodes if node.type == "BACKGROUND"), None)
    if background is None:
        background = nodes.new("ShaderNodeBackground")
        output = next(node for node in nodes if node.type == "OUTPUT_WORLD")
        sky.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    background.inputs["Color"].default_value = (*color, 1.0)
    background.inputs["Strength"].default_value = strength


def sun(strength: float = 3.4, angle: float = 3.5, color=(1.0, 0.92, 0.80), direction: Vector = SUN_FROM):
    light = bpy.data.lights.new("Sun", "SUN")
    light.energy = strength
    light.angle = math.radians(angle)
    light.color = color
    obj = bpy.data.objects.new("Sun", light)
    bpy.context.scene.collection.objects.link(obj)
    obj.rotation_euler = (-direction.normalized()).to_track_quat("-Z", "Y").to_euler()
    return obj


class View:
    """Orthographic view at a given elevation; azimuth 45° turns map squares into 2:1 diamonds."""

    def __init__(self, elevation: float, azimuth: float = 45.0) -> None:
        self.elevation = elevation
        self.rotation = Euler((math.radians(90.0 - elevation), 0.0, math.radians(azimuth)))
        matrix = self.rotation.to_matrix()
        self.right = matrix @ Vector((1.0, 0.0, 0.0))
        self.up = matrix @ Vector((0.0, 1.0, 0.0))
        self.forward = matrix @ Vector((0.0, 0.0, -1.0))

    def screen(self, point: Vector) -> tuple[float, float]:
        return point.dot(self.right), point.dot(self.up)

    def facing(self, local_forward=(0.0, -1.0), turn_left: float = 0.45) -> float:
        """Z rotation that turns a model's forward axis toward the viewer's front left."""
        toward = Vector((-self.forward.x, -self.forward.y, 0.0)).normalized()
        left = Vector((-self.right.x, -self.right.y, 0.0)).normalized()
        wanted = (toward + left * turn_left).normalized()
        return math.atan2(wanted.y, wanted.x) - math.atan2(local_forward[1], local_forward[0])


def camera(view: View, target: Vector, ortho_scale: float, resolution) -> None:
    data = bpy.data.cameras.new("Camera")
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    data.clip_start = 0.01
    data.clip_end = 300.0
    obj = bpy.data.objects.new("Camera", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.rotation_euler = view.rotation
    obj.location = target - view.forward * 80.0
    scene = bpy.context.scene
    scene.camera = obj
    scene.render.resolution_x, scene.render.resolution_y = int(resolution[0]), int(resolution[1])


def tile_metrics(canvas) -> tuple[float, float]:
    """World width of the canvas and the upward shift that keeps the tile diamond at its bottom."""
    width = TILE * math.sqrt(2.0)
    pixel = width / canvas[0]
    return width, (canvas[1] / 2.0 - canvas[0] / 4.0) * pixel


def frame_tile(view: View, canvas, raw) -> None:
    width, shift = tile_metrics(canvas)
    camera(view, view.up * shift, width, raw)


def fit_tile_contents(view: View, canvas, margin: int = 3) -> None:
    """Keep the ground anchor and camera fixed while fitting all forest crowns into the canvas."""
    bpy.context.view_layer.update()
    width, shift = tile_metrics(canvas)
    pixel = width / canvas[0]
    limits = (width / 2 - margin * pixel, canvas[1] / 2 * pixel - margin * pixel)
    factor = 1.0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.is_shadow_catcher or obj.hide_render:
            continue
        for corner in obj.bound_box:
            x, y = view.screen(obj.matrix_world @ Vector(corner))
            if x:
                factor = min(factor, limits[0] / abs(x))
            if y:
                factor = min(factor, (limits[1] + (shift if y > 0 else -shift)) / abs(y))
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and not obj.is_shadow_catcher:
            obj.matrix_world = Matrix.Scale(factor, 4) @ obj.matrix_world


def frame_sprite(view: View, longest: int, margin: float = 0.05) -> None:
    bpy.context.view_layer.update()
    travel = -SUN_FROM.normalized()
    points: list[Vector] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.is_shadow_catcher or obj.hide_render:
            continue
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            points.append(point)
            if point.z > 0.0:
                points.append(point + travel * (-point.z / travel.z))
    xs = [point.dot(view.right) for point in points]
    ys = [point.dot(view.up) for point in points]
    width, height = max(xs) - min(xs), max(ys) - min(ys)
    center = view.right * ((max(xs) + min(xs)) / 2) + view.up * ((max(ys) + min(ys)) / 2)
    scale = max(width, height) * (1.0 + 2.0 * margin)
    if width >= height:
        resolution = (longest, max(16, round(longest * height / width)))
    else:
        resolution = (max(16, round(longest * width / height)), longest)
    camera(view, center, scale, resolution)


def render(path: str) -> None:
    scene = bpy.context.scene
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# --- materials -------------------------------------------------------------------------------


def _socket(sockets, key):
    for socket in sockets:
        if socket.identifier == key:
            return socket
    return sockets[key]


def math_node(tree, operation: str, first, second=None, third=None):
    node = tree.nodes.new("ShaderNodeMath")
    node.operation = operation
    for index, value in enumerate((first, second, third)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[index].default_value = float(value)
        else:
            tree.links.new(value, node.inputs[index])
    return node.outputs[0]


def mix_color(tree, factor, first, second, blend: str = "MIX"):
    node = tree.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = blend
    for key, value in (("Factor_Float", factor), ("A_Color", first), ("B_Color", second)):
        socket = _socket(node.inputs, key)
        if isinstance(value, (int, float)):
            socket.default_value = float(value)
        elif isinstance(value, tuple):
            socket.default_value = (*lin(value), 1.0)
        else:
            tree.links.new(value, socket)
    return _socket(node.outputs, "Result_Color")


def map_range(tree, value, from_min: float, from_max: float, to_min: float, to_max: float):
    node = tree.nodes.new("ShaderNodeMapRange")
    node.clamp = True
    for key, number in (
        ("From Min", from_min),
        ("From Max", from_max),
        ("To Min", to_min),
        ("To Max", to_max),
    ):
        node.inputs[key].default_value = number
    tree.links.new(value, node.inputs["Value"])
    return node.outputs["Result"]


def ramp(tree, factor, stops):
    node = tree.nodes.new("ShaderNodeValToRGB")
    elements = node.color_ramp.elements
    while len(elements) > 1:
        elements.remove(elements[-1])
    elements[0].position = stops[0][0]
    elements[0].color = (*lin(stops[0][1]), 1.0)
    for position, color in stops[1:]:
        element = elements.new(position)
        element.color = (*lin(color), 1.0)
    tree.links.new(factor, node.inputs["Factor"] if "Factor" in node.inputs else node.inputs[0])
    return node.outputs["Color"]


def noise_texture(tree, vector, scale: float, detail: float = 4.0, roughness: float = 0.55, w=None):
    node = tree.nodes.new("ShaderNodeTexNoise")
    if w is not None:
        node.noise_dimensions = "4D"
        if isinstance(w, (int, float)):
            node.inputs["W"].default_value = float(w)
        else:
            tree.links.new(w, node.inputs["W"])
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Roughness"].default_value = roughness
    if vector is not None:
        tree.links.new(vector, node.inputs["Vector"])
    return node.outputs["Factor"]


def object_coordinates(tree):
    return tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]


def new_material(name: str):
    material = bpy.data.materials.new(name)
    with suppress(AttributeError):
        material.use_nodes = True
    tree = material.node_tree
    bsdf = next(node for node in tree.nodes if node.type == "BSDF_PRINCIPLED")
    output = next(node for node in tree.nodes if node.type == "OUTPUT_MATERIAL")
    return material, tree, bsdf, output


def material(
    name: str,
    color,
    roughness: float = 0.75,
    metallic: float = 0.0,
    specular: float = 0.5,
    variation: float = 0.0,
    scale: float = 25.0,
    bump: float = 0.0,
    bump_scale: float = 60.0,
    random_tint: float = 0.0,
    translucency: float = 0.0,
    bands: float = 0.0,
    emission: float = 0.0,
):
    """Principled material with optional noise variation, bump, per-object tint and wood bands."""
    mat, tree, bsdf, output = new_material(name)
    base = (*lin(color), 1.0)
    color_socket = None
    if variation or random_tint or bands:
        hsv = tree.nodes.new("ShaderNodeHueSaturation")
        hsv.inputs["Color"].default_value = base
        value = 1.0
        if variation:
            field = noise_texture(tree, object_coordinates(tree), scale, 4.0, 0.6)
            value = math_node(tree, "MULTIPLY_ADD", field, 2.0 * variation, 1.0 - variation)
        if bands:
            wave = tree.nodes.new("ShaderNodeTexWave")
            wave.wave_type = "BANDS"
            wave.bands_direction = "Z"
            wave.inputs["Scale"].default_value = bands
            wave.inputs["Distortion"].default_value = 2.0
            tree.links.new(object_coordinates(tree), wave.inputs["Vector"])
            stripe = math_node(
                tree,
                "MULTIPLY_ADD",
                wave.outputs["Factor"] if "Factor" in wave.outputs else wave.outputs[1],
                0.25,
                0.85,
            )
            value = stripe if isinstance(value, float) else math_node(tree, "MULTIPLY", value, stripe)
        if random_tint:
            info = tree.nodes.new("ShaderNodeObjectInfo")
            hue = math_node(
                tree, "MULTIPLY_ADD", info.outputs["Random"], 0.08 * random_tint, 0.5 - 0.04 * random_tint
            )
            tree.links.new(hue, hsv.inputs["Hue"])
            shade = math_node(
                tree, "MULTIPLY_ADD", info.outputs["Random"], 0.5 * random_tint, 1.0 - 0.25 * random_tint
            )
            value = shade if isinstance(value, float) else math_node(tree, "MULTIPLY", value, shade)
        if isinstance(value, float):
            hsv.inputs["Value"].default_value = value
        else:
            tree.links.new(value, hsv.inputs["Value"])
        color_socket = hsv.outputs["Color"]
    if color_socket is not None:
        tree.links.new(color_socket, bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = specular
    if emission:
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = emission
    if bump:
        relief = tree.nodes.new("ShaderNodeBump")
        relief.inputs["Strength"].default_value = bump
        relief.inputs["Distance"].default_value = 0.02
        tree.links.new(
            noise_texture(tree, object_coordinates(tree), bump_scale, 6.0, 0.6), relief.inputs["Height"]
        )
        tree.links.new(relief.outputs["Normal"], bsdf.inputs["Normal"])
    if translucency:
        glow = tree.nodes.new("ShaderNodeBsdfTranslucent")
        glow.inputs["Color"].default_value = base
        if color_socket is not None:
            tree.links.new(color_socket, glow.inputs["Color"])
        mixer = tree.nodes.new("ShaderNodeMixShader")
        mixer.inputs["Fac"].default_value = translucency
        tree.links.new(bsdf.outputs["BSDF"], mixer.inputs[1])
        tree.links.new(glow.outputs["BSDF"], mixer.inputs[2])
        tree.links.new(mixer.outputs["Shader"], output.inputs["Surface"])
    return mat


# --- meshes ----------------------------------------------------------------------------------


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def from_bmesh(name: str, bm, mat=None, smooth: bool = True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mat is not None:
        mesh.materials.append(mat)
    if smooth:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return link(bpy.data.objects.new(name, mesh))


def displace(bm, amplitude: float, frequency: float, seed: int) -> None:
    bm.normal_update()
    offset = Vector(((seed * 0.731) % 97.0, (seed * 0.377) % 89.0, (seed * 0.129) % 83.0))
    for vertex in bm.verts:
        vertex.co += vertex.normal * amplitude * noise.noise(vertex.co * frequency + offset)


def box(name, size, location, mat, rotation=(0.0, 0.0, 0.0), bevel: float = 0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    obj = from_bmesh(name, bm, mat, smooth=False)
    obj.location = location
    obj.rotation_euler = rotation
    if bevel:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    return obj


def cylinder(
    name,
    radius,
    depth,
    location,
    mat,
    radius2=None,
    segments: int = 20,
    rotation=(0.0, 0.0, 0.0),
    caps: bool = True,
    smooth: bool = True,
):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=caps,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius if radius2 is None else radius2,
        depth=depth,
    )
    obj = from_bmesh(name, bm, mat, smooth)
    obj.location = location
    obj.rotation_euler = rotation
    return obj


def sphere(
    name,
    radius,
    location,
    mat,
    scale=(1.0, 1.0, 1.0),
    subdivisions: int = 3,
    jitter: float = 0.0,
    seed: int = 0,
    frequency: float = 6.0,
):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    if jitter:
        displace(bm, jitter, frequency / radius, seed)
    obj = from_bmesh(name, bm, mat)
    obj.location = location
    obj.scale = scale
    return obj


def _orient(start: Vector, end: Vector) -> Matrix:
    direction = end - start
    rotation = direction.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    return Matrix.Translation((start + end) / 2) @ rotation


def limb(name, start, end, r0: float, r1: float, mat, segments: int = 16, rounded: bool = True):
    """Tapered capsule between two points; the basic building block for bodies, poles and ropes."""
    start, end = Vector(start), Vector(end)
    length = max((end - start).length, 1e-4)
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=not rounded,
        cap_tris=False,
        segments=segments,
        radius1=r0,
        radius2=r1,
        depth=length,
        matrix=_orient(start, end),
    )
    if rounded:
        for center, radius in ((start, r0), (end, r1)):
            bmesh.ops.create_uvsphere(
                bm,
                u_segments=segments,
                v_segments=max(6, segments // 2),
                radius=radius,
                matrix=Matrix.Translation(center),
            )
    return from_bmesh(name, bm, mat)


def subsurf(obj, levels: int = 2):
    modifier = obj.modifiers.new("Subdivision", "SUBSURF")
    modifier.levels = levels
    modifier.render_levels = levels
    return obj


def group(name: str, objects, location=(0.0, 0.0, 0.0), rotation_z: float = 0.0, scale: float = 1.0):
    empty = link(bpy.data.objects.new(name, None))
    for obj in objects:
        obj.parent = empty
    empty.location = location
    empty.rotation_euler = (0.0, 0.0, rotation_z)
    empty.scale = (scale, scale, scale)
    return empty


def shadow_catcher(size: float = 60.0, z: float = 0.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    obj = from_bmesh("ShadowCatcher", bm, smooth=False)
    obj.location.z = z
    obj.is_shadow_catcher = True
    return obj
